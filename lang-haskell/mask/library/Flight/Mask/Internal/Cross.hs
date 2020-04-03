module Flight.Mask.Internal.Cross
    ( CrossingPredicate
    , isStartExit
    , crossingPredicates
    , crossingSelectors
    , tickedZones
    , enterExitSeq
    , exitEnterSeq
    , reindex
    ) where

import Prelude hiding (span)
import Data.Maybe (listToMaybe)
import Data.Either (isRight)
import Data.List (nub, sort, findIndex)
import Control.Lens ((^?), element)

import Flight.Comp (Task(..), Zones(..))
import Flight.Track.Time (ZoneIdx(..))
import Flight.Units ()
import Flight.Mask.Internal.Zone
    ( TaskZone(..)
    , TrackZone(..)
    , ZoneEntry(..)
    , ZoneExit(..)
    , Crossing
    , OrdCrossing(..)
    )
import Flight.Geodesy.Solution (SeparatedZones)

import Flight.Geodesy.Double ()

-- | A function that tests whether a flight track, represented as a series of point
-- zones crosses a zone.
type CrossingPredicate a b
    = TaskZone a
    -- ^ The task control zone.
    -> [TrackZone a]
    -- ^ The flight track represented as a series of point zones.
    -> [b]

insideZone
    :: (Real a, Fractional a)
    => SeparatedZones a
    -> TaskZone a
    -> [TrackZone a]
    -> Maybe ZoneIdx
insideZone sepZs (TaskZone z) =
    fmap ZoneIdx
    . findIndex (\(TrackZone x) -> not $ sepZs [x, z])

outsideZone
    :: (Real a, Fractional a)
    => SeparatedZones a
    -> TaskZone a
    -> [TrackZone a]
    -> Maybe ZoneIdx
outsideZone sepZs (TaskZone z) =
    fmap ZoneIdx
    . findIndex (\(TrackZone x) -> sepZs [x, z])

zoneSingle
    :: (sepZs -> zone -> [x] -> Maybe ZoneIdx)
    -> (sepZs -> zone -> [x] -> Maybe ZoneIdx)
    -> (ZoneIdx -> ZoneIdx -> crossing)
    -> sepZs
    -> zone
    -> [x]
    -> [crossing]
zoneSingle f g ctor sepZs z xs =
    case g sepZs z xs of
        Nothing -> []
        Just j@(ZoneIdx j') ->
            case f sepZs z . reverse $ ys of
                Just 0 -> [ctor (j - 1) j]
                _ -> []
            where
                ys = take j' xs

-- | Finds the first pair of points, one outside the zone and the next inside.
-- Searches the fixes in order.
entersSingle
    :: (Real a, Fractional a)
    => SeparatedZones a
    -> CrossingPredicate a ZoneEntry
entersSingle =
    zoneSingle outsideZone insideZone ZoneEntry

-- | Finds the first pair of points, one inside the zone and the next outside.
-- Searches the fixes in order.
exitsSingle
    :: (Real a, Fractional a)
    => SeparatedZones a
    -> CrossingPredicate a ZoneExit
exitsSingle  =
    zoneSingle insideZone outsideZone ZoneExit

reindex
    :: ZoneIdx -- ^ The length of the track, the number of fixes
    -> Either ZoneEntry ZoneExit
    -> Either ZoneEntry ZoneExit
reindex n (Right (ZoneExit i j)) =
    Right $ ZoneExit (i + n) (j + n)

reindex n (Left (ZoneEntry i j)) =
    Left $ ZoneEntry (i + n) (j + n)

crossSeq
    :: (Real a, Fractional a)
    => SeparatedZones a
    -> CrossingPredicate a Crossing
crossSeq sepZs z xs =
    unOrdCrossing <$> (nub . sort $ enterExits ++ exitEnters)
    where
        enterExits = OrdCrossing <$> enterExitSeq sepZs z xs
        exitEnters = OrdCrossing <$> exitEnterSeq sepZs z xs

-- | Find the sequence of @take _ [entry, exit, .., entry, exit]@ going forward.
enterExitSeq
    :: (Real a, Fractional a)
    => SeparatedZones a
    -> CrossingPredicate a Crossing
enterExitSeq sepZs z xs =
    case entersSingle sepZs z xs of
        [] ->
            []

        (hit@(ZoneEntry _ jIdx@(ZoneIdx j)) : _) ->
            Left hit : (reindex jIdx <$> exitEnterSeq sepZs z (drop j xs))

-- | Find the sequence of @take _ [exit, entry.., exit, entry]@ going forward.
exitEnterSeq
    :: (Real a, Fractional a)
    => SeparatedZones a
    -> CrossingPredicate a Crossing
exitEnterSeq sepZs z xs =
    case exitsSingle sepZs z xs of
        [] ->
            []

        (hit@(ZoneExit _ jIdx@(ZoneIdx j)) : _) ->
            Right hit : (reindex jIdx <$> enterExitSeq sepZs z (drop j xs))

-- | A start zone is either entry or exit when all other zones are entry.
-- If I must fly into the start cylinder to reach the next turnpoint then
-- the start zone is entry otherwise it is exit. In one case the start cylinder
-- contains the next turnpoint and in the other the start cylinder is
-- completely separate from the next turnpoint.
--
-- >>> isStartExit sepZs fromZs task
-- False
isStartExit
    :: (Real a, Fractional a)
    => SeparatedZones a
    -> (Zones -> [TaskZone a])
    -> Task k
    -> Bool
isStartExit sepZs fromZones Task{speedSection, zones} =
    case speedSection of
        Nothing ->
            False

        Just (i, _) ->
            let zs = fromZones zones in
            case (zs ^? element (i - 1), zs ^? element i) of
                (Just start, Just tp1) ->
                    sepZs
                    $ unTaskZone
                    <$> [start, tp1]

                _ ->
                    False

-- | Some pilots track logs will have initial values way off from the location
-- of the device. I suspect that the GPS logger is remembering the position it
-- had when last turned off, most likely at the end of yesterday's flight,
-- somewhere near where the pilot landed that day. Until the GPS receiver gets
-- a satellite fix and can compute the current position the stale, last known,
-- position gets logged. This means that a pilot may turn on their instrument
-- inside the start circle but their tracklog will start outside of it. For
-- this reason the crossing predicate is @crossSeq@ for all zones.
--
-- An example of a track log with this problem ...
--
-- 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 
-- 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 
-- 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 
-- 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 
-- 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 
-- 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 148.505133,-32.764317,0 
-- 148.505133,-32.764317,0 147.913967,-33.363200,448 147.913883,-33.363433,448 147.913817,-33.363633,448 147.913400,-33.364217,448 
crossingPredicates
    :: (Real a, Fractional a)
    => SeparatedZones a
    -> Bool -- ^ Is the start an exit cylinder?
    -> Task k
    -> [CrossingPredicate a Crossing]
crossingPredicates sepZs _ Task{zones} =
    const (crossSeq sepZs) <$> raw zones

-- | If the zone is an exit, then take the last crossing otherwise take the
-- first crossing.
crossingSelectors
    :: Bool -- ^ Is the start an exit cylinder?
    -> Task k
    -> [[Crossing] -> Maybe Crossing] -- ^ A crossing selector for each zone.
crossingSelectors startIsExit Task{speedSection, zones} =
    zipWith
        (\ i _ ->
            if i == start && startIsExit
               then selectLast . filter isRight
               else selectFirst)
        [1 .. ]
        (raw zones)
    where
        start =
            maybe 0 fst speedSection

selectFirst :: [a] -> Maybe a
selectFirst = listToMaybe . take 1

selectLast :: [a] -> Maybe a
selectLast xs = listToMaybe . take 1 $ reverse xs

tickedZones
    :: [CrossingPredicate a b]
    -> [TaskZone a] -- ^ The control zones of the task.
    -> [TrackZone a] -- ^ The flown track.
    -> [[b]]
tickedZones fs zones xs =
    zipWith (\f z -> f z xs) fs zones

-- $setup
-- >>> :set -XTemplateHaskell
-- >>> import Language.Haskell.TH
-- >>> import Language.Haskell.TH.Syntax (lift)
-- >>> import qualified Data.ByteString as BS
-- >>> import Data.ByteString.UTF8 as BSU
-- >>> import Data.Yaml
-- >>> import Flight.Geodesy
-- >>> import Flight.Geodesy.Double ()
-- >>> import Flight.Geodesy.Solution
-- >>> import Flight.Earth.Ellipsoid (wgs84)
-- >>> import Flight.Comp
-- >>> import Flight.ShortestPath (GeoPath(..))
-- >>> import Flight.ShortestPath.Double ()
-- >>> import Flight.Span.Sliver (GeoSliver(..))
-- >>> import Flight.Span.Double ()
-- :{
-- embedStr :: IO String -> ExpQ
-- embedStr readStr = lift =<< runIO readStr
-- :}
--
-- >>> fileComp  = "./test-suite-doctest/PWC2019-1.comp-input.yaml"
-- >>> yamlComp = $(embedStr (System.IO.readFile fileComp))
-- >>> Right CompSettings{tasks = task : _} = decodeEither' (BSU.fromString yamlComp) :: Either ParseException (CompSettings k)
-- >>> e = (Vincenty, EarthAsEllipsoid wgs84)
-- >>> fromZs = fromZones @Double @Double e Nothing
-- >>> sepZs = separatedZones @Double @Double e
