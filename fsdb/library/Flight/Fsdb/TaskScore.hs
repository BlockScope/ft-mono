{-# OPTIONS_GHC -fno-warn-partial-type-signatures #-}

module Flight.Fsdb.TaskScore (parseScores) where

import Prelude hiding (max)
import qualified Prelude as Stats (max)
import Data.Time.LocalTime (TimeOfDay, timeOfDayToTime)
import Data.Maybe (catMaybes)
import Data.List (unzip5)
import qualified Data.Vector as V (fromList)
import qualified Statistics.Sample as Stats (mean, stdDev)
import Data.UnitsOfMeasure (u, zero, convert, fromRational')
import Data.UnitsOfMeasure.Internal (Quantity(..))

import Text.XML.HXT.Arrow.Pickle
    ( PU(..)
    , unpickleDoc, unpickleDoc'
    , xpWrap, xpElem, xpAttr
    , xpFilterAttr, xpFilterCont
    , xpInt, xpPrim
    , xpPair, xpTriple, xp4Tuple, xp5Tuple, xp6Tuple, xp11Tuple
    , xpTextAttr, xpOption
    )
import Text.XML.HXT.DOM.TypeDefs (XmlTree)
import Text.XML.HXT.Core
    ( ArrowXml
    , (<+>)
    , (&&&)
    , (>>>)
    , runX
    , no, yes
    , withValidate, withWarnings, withRemoveWS
    , readString
    , hasName
    , getChildren
    , getAttrValue
    , constA
    , listA
    , arr
    , deep
    , containing
    , orElse
    , hasAttr
    , isAttr
    )

import Flight.Distance (TaskDistance(..), unTaskDistanceAsKm)
import Flight.Track.Distance (AwardedDistance(..))
import Flight.Track.Point (NormPointing(..), NormBreakdown(..))
import Flight.Comp (PilotId(..), Pilot(..), Nominal(..))
import Flight.Score
    ( TaskPoints(..), TaskPlacing(..)
    , DistancePoints(..)
    , LeadingPoints(..)
    , ArrivalPoints(..)
    , TimePoints(..)
    , PilotTime(..)
    , SpeedFraction(..)
    , ArrivalFraction(..)
    , LeadingArea(..), LeadingCoef(..), LeadingFraction(..)
    , Validity(..), TaskValidity(..), StopValidity(..)
    , LaunchValidity(..), LaunchValidityWorking(..)
    , DistanceValidity(..), DistanceValidityWorking(..)
    , TimeValidity(..), TimeValidityWorking(..)
    , ReachToggle(..), ReachStats(..), StopValidityWorking(..)
    , PilotsFlying(..), PilotsPresent(..), PilotsAtEss(..), PilotsLanded(..)
    , FlownMax(..), FlownMean(..), FlownStdDev(..)
    , LaunchToEss(..)
    , NominalGoal(..)
    , NominalLaunch(..)
    , NominalDistance(..)
    , MinimumDistance(..)
    , SumOfDistance(..), NominalDistanceArea(..)
    , NominalTime(..), BestTime(..)
    )
import Flight.Fsdb.Pilot (getCompPilot)
import Flight.Fsdb.KeyPilot (unKeyPilot, keyPilots, keyMap)
import Flight.Fsdb.Internal.Parse (parseUtcTime, parseHmsTime)
import Flight.Fsdb.Distance (asAwardReach, taskMetresToKm, taskKmToMetres)

dToR :: Double -> Rational
dToR = toRational

toPilotTime :: TimeOfDay -> PilotTime (Quantity Double [u| h |])
toPilotTime x =
    PilotTime $ convert secs
    where
        secs :: Quantity Double [u| s |]
        secs = fromRational' . MkQuantity . toRational $ timeOfDayToTime x

xpRankScore :: PU NormBreakdown
xpRankScore =
    xpElem "FsResult"
    $ xpFilterAttr
        ( hasName "rank"
        <+> hasName "points"
        <+> hasName "distance_points"
        <+> hasName "leading_points"
        <+> hasName "arrival_points"
        <+> hasName "time_points"
        <+> hasName "started_ss"
        <+> hasName "finished_ss"
        <+> hasName "ss_time"
        <+> hasName "real_distance"
        <+> hasName "distance"
        )
    $ xpWrap
        ( \(r, p, dp, l, a, t, dM, dE, ss, es, ssE) ->
            NormBreakdown
                { place = TaskPlacing . fromIntegral $ r
                , total = TaskPoints . toRational $ p
                , distance = DistancePoints . dToR $ dp
                , leading = LeadingPoints . dToR $ l
                , arrival = ArrivalPoints . dToR $ a
                , time = TimePoints . dToR $ t
                , reachExtra = taskKmToMetres . TaskDistance . MkQuantity $ dE
                , reachMade = taskKmToMetres . TaskDistance . MkQuantity $ dM
                , distanceFrac = 0
                , ss = parseUtcTime <$> ss
                , es = parseUtcTime <$> es
                , timeElapsed =
                    if ssE == Just "00:00:00" then Nothing else
                    toPilotTime . parseHmsTime <$> ssE
                , timeFrac = SpeedFraction 0
                , leadingArea = LeadingArea zero
                , leadingCoef = LeadingCoef zero
                , leadingFrac = LeadingFraction 0
                , arrivalFrac = ArrivalFraction 0
                }
        , \NormBreakdown
                { place = TaskPlacing r
                , total = TaskPoints p
                , distance = DistancePoints dp
                , leading = LeadingPoints l
                , arrival = ArrivalPoints a
                , time = TimePoints t
                , reachExtra = TaskDistance (MkQuantity dE)
                , reachMade = TaskDistance (MkQuantity dM)
                , ss
                , es
                , timeElapsed
                } ->
                    ( fromIntegral r
                    , round p
                    , fromRational dp
                    , fromRational l
                    , fromRational a
                    , fromRational t
                    , dE
                    , dM
                    , show <$> ss
                    , show <$> es
                    , show <$> timeElapsed
                    )
        )
    $ xp11Tuple
        (xpAttr "rank" xpInt)
        (xpAttr "points" xpInt)
        (xpAttr "distance_points" xpPrim)
        (xpAttr "leading_points" xpPrim)
        (xpAttr "arrival_points" xpPrim)
        (xpAttr "time_points" xpPrim)
        (xpAttr "real_distance" xpPrim)
        (xpAttr "distance" xpPrim)
        (xpOption $ xpTextAttr "started_ss")
        (xpOption $ xpTextAttr "finished_ss")
        (xpOption $ xpTextAttr "ss_time")

xpLeading :: PU (Int, Double)
xpLeading =
    xpElem "FsFlightData"
    $ xpFilterAttr (hasName "iv" <+> hasName "lc")
    $ xpPair
        (xpAttr "iv" xpInt)
        (xpAttr "lc" xpPrim)

xpValidity :: PU Validity
xpValidity =
    xpElem "FsTaskScoreParams"
    -- WARNING: Filter only attributes, ignoring child elements such as
    -- <FsTaskDistToTp tp_no="1" distance="0.000" />. If not then the pickling
    -- will fail with "xpCheckEmptyContents: unprocessed XML content detected".
    $ xpFilterCont(isAttr)
    $ xpFilterAttr
        ( hasName "day_quality"
        <+> hasName "launch_validity"
        <+> hasName "distance_validity"
        <+> hasName "time_validity"
        <+> hasName "stop_validity"
        )
    $ xpWrap
        ( \(dq, lv, dv, tv, sv) ->
            Validity
                { task = TaskValidity $ dToR dq
                , launch = LaunchValidity $ dToR lv
                , distance = DistanceValidity $ dToR dv
                , time = TimeValidity $ dToR tv
                , stop = StopValidity . dToR <$> sv
                }
        , \Validity
                { task = TaskValidity dq
                , launch = LaunchValidity lv
                , distance = DistanceValidity dv
                , time = TimeValidity tv
                , stop = sv
                } ->
                    ( fromRational dq
                    , fromRational lv
                    , fromRational dv
                    , fromRational tv
                    , (\(StopValidity v) -> fromRational v) <$> sv
                    )
        )
    $ xp5Tuple
        (xpAttr "day_quality" xpPrim)
        (xpAttr "launch_validity" xpPrim)
        (xpAttr "distance_validity" xpPrim)
        (xpAttr "time_validity" xpPrim)
        (xpOption $ xpAttr "stop_validity" xpPrim)

xpLaunchValidityWorking :: NominalLaunch -> PU LaunchValidityWorking
xpLaunchValidityWorking nl =
    xpElem "FsTaskScoreParams"
    $ xpFilterCont(isAttr)
    $ xpFilterAttr
        (hasName "no_of_pilots_flying" <+> hasName "no_of_pilots_present")
    $ xpWrap
        ( \(pf, pp) ->
            LaunchValidityWorking
                { flying = PilotsFlying $ fromIntegral pf
                , present = PilotsPresent $ fromIntegral pp
                , nominalLaunch = nl
                }
        , \LaunchValidityWorking
                { flying = PilotsFlying pf
                , present = PilotsPresent pp
                } ->
                    (fromIntegral pf, fromIntegral pp)
        )
    $ xpPair
        (xpAttr "no_of_pilots_flying" xpInt)
        (xpAttr "no_of_pilots_present" xpInt)

xpTimeValidityWorking
    :: NominalDistance (Quantity Double [u| km |])
    -> NominalTime (Quantity Double [u| h |])
    -> PU TimeValidityWorking
xpTimeValidityWorking nd nt =
    xpElem "FsTaskScoreParams"
    $ xpFilterCont(isAttr)
    $ xpFilterAttr
        (hasName "best_time"
        <+> hasName "best_dist"
        <+> hasName "best_real_dist"
        )
    $ xpWrap
        ( \(bt, bdE, bdF) ->
            TimeValidityWorking
                { ssBestTime = Nothing
                , gsBestTime =
                    if bt == 0 then Nothing else
                    Just . BestTime $ MkQuantity bt
                , nominalTime = nt
                , nominalDistance = nd
                , reachMax =
                    ReachToggle
                        { extra = FlownMax $ MkQuantity bdE
                        , flown = FlownMax $ MkQuantity bdF
                        }
                }
        , \TimeValidityWorking
                { gsBestTime = bt
                , reachMax =
                    ReachToggle
                        { extra = FlownMax (MkQuantity bdE)
                        , flown = FlownMax (MkQuantity bdF)
                        }
                } ->
                    let bt' = maybe 0 (\(BestTime (MkQuantity x)) -> x) bt
                    in (bt', bdE, bdF)
        )
    $ xpTriple
        (xpAttr "best_time" xpPrim)
        (xpAttr "best_dist" xpPrim)
        (xpAttr "best_real_dist" xpPrim)

xpDistanceValidityWorking
    :: NominalGoal
    -> NominalDistance (Quantity Double [u| km |])
    -> MinimumDistance (Quantity Double [u| km |])
    -> PU DistanceValidityWorking
xpDistanceValidityWorking
    ng'@(NominalGoal ngR)
    nd'@(NominalDistance (MkQuantity nd))
    md'@(MinimumDistance (MkQuantity md)) =
    xpElem "FsTaskScoreParams"
    $ xpFilterCont(isAttr)
    $ xpFilterAttr
        ( hasName "sum_real_dist_over_min"
        <+> hasName "no_of_pilots_flying"
        <+> hasName "best_dist"
        <+> hasName "best_real_dist"
        )
    $ xpWrap
        ( \(sd, pf, bdE, bdF) ->
            DistanceValidityWorking
                { sum = SumOfDistance $ MkQuantity sd
                , flying = PilotsFlying $ fromIntegral pf
                , area =
                    let a :: Double = (ng + 1) * (nd - md)
                        b :: Double = Stats.max 0 $ ng * (bdF - nd)
                    in NominalDistanceArea . toRational $ (a + b) / 2
                , nominalGoal = ng'
                , nominalDistance = nd'
                , minimumDistance = md'
                , reachMax =
                    ReachToggle
                        { extra = FlownMax $ MkQuantity bdE
                        , flown = FlownMax $ MkQuantity bdF
                        }
                }
        , \DistanceValidityWorking
                { sum = SumOfDistance (MkQuantity sd)
                , flying = PilotsFlying pf
                , reachMax =
                    ReachToggle
                        { extra = FlownMax (MkQuantity bdE)
                        , flown = FlownMax (MkQuantity bdF)
                        }
                } ->
                    (sd, fromIntegral pf, bdE, bdF)
        )
    $ xp4Tuple
        (xpAttr "sum_real_dist_over_min" xpPrim)
        (xpAttr "no_of_pilots_flying" xpInt)
        (xpAttr "best_dist" xpPrim)
        (xpAttr "best_real_dist" xpPrim)
    where
        ng = fromRational ngR

xpStopValidityWorking :: PU StopValidityWorking
xpStopValidityWorking =
    xpElem "FsTaskScoreParams"
    $ xpFilterCont(isAttr)
    $ xpFilterAttr
        ( hasName "no_of_pilots_reaching_es"
        <+> hasName "no_of_pilots_landed_before_stop"
        <+> hasName "no_of_pilots_flying"
        <+> hasName "best_dist"
        <+> hasName "best_real_dist"
        <+> hasName "launch_to_ess_distance"
        )
    $ xpWrap
        ( \(pe, pl, pf, eMax, fMax, ed) ->
            let qExtraMax :: Quantity _ [u| km |] = MkQuantity eMax
                qFlownMax :: Quantity _ [u| km |] = MkQuantity fMax
            in
                StopValidityWorking
                    { pilotsAtEss = PilotsAtEss $ fromIntegral pe
                    , landed = PilotsLanded $ fromIntegral pl
                    , stillFlying = PilotsFlying . fromIntegral $ pf - pl
                    , flying = PilotsFlying $ fromIntegral pf
                    , reachStats =
                        ReachToggle
                            { extra =
                                ReachStats
                                    { max = FlownMax $ convert qExtraMax
                                    , mean = FlownMean [u| 0 km |]
                                    , stdDev = FlownStdDev [u| 0 km |]
                                    }
                            , flown =
                                ReachStats
                                    { max = FlownMax $ convert qFlownMax
                                    , mean = FlownMean [u| 0 km |]
                                    , stdDev = FlownStdDev [u| 0 km |]
                                    }
                            }
                    , launchToEssDistance = LaunchToEss $ MkQuantity ed
                    }
        , \StopValidityWorking
                { pilotsAtEss = PilotsAtEss pe
                , landed = PilotsLanded pl
                , flying = PilotsFlying pf
                , reachStats =
                    ReachToggle
                        { extra = ReachStats{max = FlownMax qExtraMax}
                        , flown = ReachStats{max = FlownMax qFlownMax}
                        }
                , launchToEssDistance = LaunchToEss (MkQuantity ed)
                } ->
                    let (MkQuantity eMax) :: Quantity _ [u| km |] = convert qExtraMax
                        (MkQuantity fMax) :: Quantity _ [u| km |] = convert qFlownMax
                    in
                        ( fromIntegral pe
                        , fromIntegral pl
                        , fromIntegral pf
                        , eMax
                        , fMax
                        , ed
                        )
        )
    $ xp6Tuple
        (xpAttr "no_of_pilots_reaching_es" xpInt)
        (xpAttr "no_of_pilots_landed_before_stop" xpInt)
        (xpAttr "no_of_pilots_flying" xpInt)
        (xpAttr "best_dist" xpPrim)
        (xpAttr "best_real_dist" xpPrim)
        (xpAttr "launch_to_ess_distance" xpPrim)

getScore :: ArrowXml a => [Pilot] -> a XmlTree [(Pilot, Maybe NormBreakdown)]
getScore pilots =
    getChildren
    >>> deep (hasName "FsTask")
    >>> getTaskDistance
    &&& getPoint
    >>> arr (\(td, xs) ->
        [
            (,) p $ do
                n@NormBreakdown{reachMade = dm} <- x
                let dKm = taskMetresToKm dm
                AwardedDistance{awardedFrac = frac} <- asAwardReach td (Just dKm)
                return $ n{distanceFrac = frac}

        | (p, x) <- xs
        ])
    where
        kps = keyPilots pilots

        -- <FsParticipant id="28">
        --    <FsResult rank="49" points="56" />
        getPoint =
            ( getChildren
            >>> hasName "FsParticipants"
            >>> listA getDidScore
            )
            -- NOTE: If a task is created when there are no participants
            -- then the FsTask/FsParticipants element is omitted.
            `orElse` constA []
            where
                getDidScore =
                    getChildren
                    >>> hasName "FsParticipant"
                        `containing`
                        ( getChildren
                        >>> hasName "FsResult"
                        >>> hasAttr "rank"
                        >>> hasAttr "points"
                        >>> hasAttr "distance_points"
                        >>> hasAttr "leading_points"
                        >>> hasAttr "arrival_points"
                        >>> hasAttr "time_points"
                        >>> hasAttr "real_distance"
                        >>> hasAttr "distance"
                        )
                    >>> getAttrValue "id"
                    &&& getResultScore
                    &&& getLeading
                    >>> arr (\(pid, (x, ld)) ->
                        ( unKeyPilot (keyMap kps) . PilotId $ pid
                        , do
                            norm <- x
                            (a, c) <- ld
                            return $
                                norm
                                    { leadingArea = LeadingArea . MkQuantity . fromIntegral $ a
                                    , leadingCoef = LeadingCoef . MkQuantity $ c
                                    }
                        ))

                getResultScore =
                    getChildren
                    >>> hasName "FsResult"
                    >>> arr (unpickleDoc xpRankScore)

        getLeading =
            getChildren
            >>> hasName "FsFlightData"
            >>> arr (unpickleDoc xpLeading)

        getTaskDistance =
            getChildren
            >>> hasName "FsTaskScoreParams"
            >>> getAttrValue "task_distance"

getValidity
    :: ArrowXml a
    => NominalGoal
    -> NominalLaunch
    -> NominalDistance (Quantity Double [u| km |])
    -> MinimumDistance (Quantity Double [u| km |])
    -> NominalTime (Quantity Double [u| h |])
    -> a XmlTree
         ( Either
             String
             ( Validity
             , LaunchValidityWorking
             , TimeValidityWorking
             , DistanceValidityWorking
             , StopValidityWorking
             )
         )
getValidity ng nl nd md nt =
    getChildren
    >>> deep (hasName "FsTask")
    >>> getTaskValidity
    &&& getLaunchValidityWorking
    &&& getTimeValidityWorking
    &&& getDistanceValidityWorking
    &&& getStopValidityWorking
    >>> arr (\(tv, (lw, (tw, (dw, sw)))) -> do
            tv' <- tv
            lw' <- lw
            tw' <- tw
            dw' <- dw
            sw' <- sw
            return (tv', lw', tw', dw', sw'))
    where
        getTaskValidity =
            getChildren
            >>> hasName "FsTaskScoreParams"
            >>> arr (unpickleDoc' xpValidity)

        getLaunchValidityWorking =
            getChildren
            >>> hasName "FsTaskScoreParams"
            >>> arr (unpickleDoc' $ xpLaunchValidityWorking nl)

        getTimeValidityWorking =
            getChildren
            >>> hasName "FsTaskScoreParams"
            >>> arr (unpickleDoc' $ xpTimeValidityWorking nd nt)

        getDistanceValidityWorking =
            getChildren
            >>> hasName "FsTaskScoreParams"
            >>> arr (unpickleDoc' $ xpDistanceValidityWorking ng nd md)

        getStopValidityWorking =
            getChildren
            >>> hasName "FsTaskScoreParams"
            >>> arr (unpickleDoc' xpStopValidityWorking)

parseScores :: Nominal -> String -> IO (Either String NormPointing)
parseScores
    Nominal
        { goal = ng
        , launch = nl
        , distance = nd
        , time = nt
        , free = md
        }
    contents = do
    let doc =
            readString
                [ withValidate no
                , withWarnings no
                , withRemoveWS yes
                ]
                contents

    ps <- runX $ doc >>> getCompPilot
    xss <- runX $ doc >>> getScore ps

    let yss :: [[(Pilot, NormBreakdown)]] = [catMaybes $ sequence <$> xs| xs <- xss]
    let tss = const Nothing <$> yss

    let rss =
            [
                unzip
                [ (e, r)
                | NormBreakdown{reachExtra = e, reachMade = r} <- ys
                ]
            | ys <- (fmap . fmap) snd yss
            ]

    let es =
            [
                let ys = V.fromList $ unTaskDistanceAsKm <$> xs in
                ReachStats
                    { max = FlownMax . MkQuantity $ maximum ys
                    , mean = FlownMean . MkQuantity $ Stats.mean ys
                    , stdDev = FlownStdDev . MkQuantity $ Stats.stdDev ys
                    }
            | (xs, _) <- rss
            ]

    let rs =
            [
                let ys = V.fromList $ unTaskDistanceAsKm <$> xs in
                ReachStats
                    { max = FlownMax . MkQuantity $ maximum ys
                    , mean = FlownMean . MkQuantity $ Stats.mean ys
                    , stdDev = FlownStdDev . MkQuantity $ Stats.stdDev ys
                    }
            | (_, xs) <- rss
            ]

    gvs <- runX $ doc >>> getValidity ng nl nd md nt
    let vws =
            [
                (\(vs, lw, tw, dw, sw) ->
                    let sw' = sw{reachStats = ReachToggle{extra = e, flown = r}} in
                    (vs, lw, tw, dw, sw')
                )
                <$> gv
            | gv <- gvs
            | e <- es
            | r <- rs
            ]

    return $
        (\(vs, lw, tw, dw, sw) -> NormPointing
            { bestTime = tss
            , validityWorkingLaunch = Just <$> lw
            , validityWorkingTime = Just <$> tw
            , validityWorkingDistance = Just <$> dw
            , validityWorkingStop = Just <$> sw
            , validity = Just <$> vs
            , score = yss
            })
        . unzip5
        <$> sequence vws
