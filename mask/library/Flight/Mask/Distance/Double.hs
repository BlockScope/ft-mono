{-# OPTIONS_GHC -fno-warn-orphans #-}

module Flight.Mask.Distance.Double () where

import Prelude hiding (span)
import Data.Time.Clock (UTCTime)
import Data.List (inits)
import Data.UnitsOfMeasure ((-:), u)

import Flight.Units ()
import Flight.Clip (FlyCut(..), FlyClipping(..))
import Flight.Distance (PathDistance(..), QTaskDistance, TaskDistance(..))
import Flight.Kml (MarkedFixes(..))
import qualified Flight.Kml as Kml (Fix)
import Flight.Track.Time (ZoneIdx(..), TimeRow(..))
import Flight.Track.Cross (Fix(..))
import Flight.Comp (Task(..), Zones(..))
import Flight.Geodesy.Solution (Trig, GeodesySolutions(..), GeoZones(..))
import Flight.Task (Zs(..))
import qualified Flight.Task as T (fromZs)
import Flight.ShortestPath (GeoPath(..))

import Flight.Mask.Internal.Zone (fixFromFix, fixToPoint, rowToPoint)
import Flight.Mask.Internal.Race (Ticked, mm30)
import Flight.Mask.Internal.Dash (dashPathToGoalR, dashToGoalR)
import Flight.Span.Sliver (GeoSliver(..), Sliver(..))
import Flight.Mask.Distance (GeoDash(..), revindex, index)

import Flight.Geodesy.Double ()
import Flight.ShortestPath.Double ()
import Flight.Span.Double ()

instance GeoSliver Double a => GeoDash Double a where
    dashDistancesToGoal
        :: (Trig Double a, FlyClipping UTCTime MarkedFixes)
        => Earth Double
        -> Ticked
        -> Task k
        -> FlyCut UTCTime MarkedFixes
        -> Maybe [(Maybe Fix, Maybe (QTaskDistance Double [u| m |]))]
        -- ^ Nothing indicates no such task or a task with no zones.
    dashDistancesToGoal e ticked task@Task{zones} flyCut =
        -- NOTE: A ghci session using inits & tails.
        -- inits [1 .. 4]
        -- [[],[1],[1,2],[1,2,3],[1,2,3,4]]
        --
        -- tails [1 .. 4]
        -- [[1,2,3,4],[2,3,4],[3,4],[4],[]]
        --
        -- tails $ reverse [1 .. 4]
        -- [[4,3,2,1],[3,2,1],[2,1],[1],[]]
        --
        -- drop 1 $ inits [1 .. 4]
        -- [[1],[1,2],[1,2,3],[1,2,3,4]]
        if null (raw zones) then Nothing else Just
        $ lfg ticked task mark0
        <$> drop 1 (inits ixs)
        where
            lfg = lastFixToGoal @Double @Double e
            ixs = index fixes
            FlyCut{uncut = MarkedFixes{mark0, fixes}} = clipToCut flyCut

    dashDistanceToGoal
        :: (Trig Double a, FlyClipping UTCTime MarkedFixes)
        => Earth Double
        -> Ticked
        -> Task k
        -> FlyCut UTCTime MarkedFixes
        -> Maybe (QTaskDistance Double [u| m |])
    dashDistanceToGoal e ticked task flyCut =
        T.fromZs
        $ edgesSum
        <$> dashPathToGoalMarkedFixes @Double @Double e ticked task flyCut

    dashPathToGoalTimeRows
        :: (Trig Double a, FlyClipping UTCTime [TimeRow])
        => Earth Double
        -> Ticked
        -> Task k
        -> FlyCut UTCTime [TimeRow]
        -> Zs (PathDistance Double)
        -- ^ Nothing indicates no such task or a task with no zones.
    dashPathToGoalTimeRows e ticked Task{speedSection, zones} flyCut =

        if null (raw zones) then Z0 else
        dashPathToGoalR optZs sepZs ticked rowToPoint speedSection zs ixs
        where
            Sliver{..} = sliver @Double @Double e
            ac = angleCut @Double @Double e
            optZs = shortestPath @Double @Double e cseg cs ac mm30
            sepZs = separatedZones @Double @Double e
            fromZs = fromZones @Double @Double e
            zs = fromZs zones
            ixs = revindex fixes
            FlyCut{uncut = fixes} = clipToCut flyCut

    dashPathToGoalMarkedFixes
        :: (Trig Double a, FlyClipping UTCTime MarkedFixes)
        => Earth Double
        -> Ticked
        -> Task k
        -> FlyCut UTCTime MarkedFixes
        -> Zs (PathDistance Double)
        -- ^ Nothing indicates no such task or a task with no zones.
    dashPathToGoalMarkedFixes e ticked Task{speedSection, zones} flyCut =

        if null (raw zones) then Z0 else
        dashPathToGoalR optZs sepZs ticked fixToPoint speedSection zs ixs
        where
            Sliver{..} = sliver @Double @Double e
            ac = angleCut @Double @Double e
            optZs = shortestPath @Double @Double e cseg cs ac mm30
            sepZs = separatedZones @Double @Double e
            fromZs = fromZones @Double @Double e
            zs = fromZs zones
            ixs = revindex fixes
            FlyCut{uncut = MarkedFixes{fixes}} = clipToCut flyCut

    lastFixToGoal
        :: Trig Double a
        => Earth Double
        -> Ticked -- ^ The zones ticked
        -> Task k
        -> UTCTime
        -> [(ZoneIdx, Kml.Fix)]
        -> (Maybe Fix, Maybe (QTaskDistance Double [u| m |]))
    lastFixToGoal e ticked Task{speedSection, zones} mark0 ixs =
        case iys of
            [] -> (Nothing, Nothing)
            ((i, y) : _) -> (Just $ fixFromFix mark0 i y, d)
        where
            Sliver{..} = sliver @Double @Double e
            ac = angleCut @Double @Double e
            optZs = shortestPath @Double @Double e cseg cs ac mm30
            sepZs = separatedZones @Double @Double e
            fromZs = fromZones @Double @Double e
            zs = fromZs zones
            iys = reverse ixs
            d = dashToGoalR optZs sepZs ticked fixToPoint speedSection zs iys

    dashDistanceFlown
        :: (Trig Double a, FlyClipping UTCTime MarkedFixes)
        => Earth Double
        -> QTaskDistance Double [u| m |]
        -> Ticked
        -> Task k
        -> FlyCut UTCTime MarkedFixes
        -> Maybe (QTaskDistance Double [u| m |])
    dashDistanceFlown e (TaskDistance dTask) ticked Task{speedSection, zones} flyCut =
        if null zs then Nothing else do
            TaskDistance dPilot
                <- dashToGoalR optZs sepZs ticked fixToPoint speedSection zs ixs

            return . TaskDistance $ dTask -: dPilot
        where
            Sliver{..} = sliver @Double @Double e
            ac = angleCut @Double @Double e
            optZs = shortestPath @Double @Double e cseg cs ac mm30
            sepZs = separatedZones @Double @Double e
            fromZs = fromZones @Double @Double e
            zs = fromZs zones
            ixs = reverse . index $ fixes
            FlyCut{uncut = MarkedFixes{fixes}} = clipToCut flyCut

    togoAtLanding
        :: Trig Double a
        => Earth Double
        -> Ticked
        -> Task k
        -> FlyCut UTCTime MarkedFixes
        -> Maybe (QTaskDistance Double [u| m |])
    togoAtLanding e ticked task xs =
        dashDistanceToGoal @Double @Double
            e
            ticked
            task
            xs

    madeAtLanding
        :: Trig Double a
        => Earth Double
        -> QTaskDistance Double [u| m |]
        -> Ticked
        -> Task k
        -> FlyCut UTCTime MarkedFixes
        -> Maybe (QTaskDistance Double [u| m |])
    madeAtLanding e dTaskF ticked task xs =
        dashDistanceFlown @Double @Double
            e
            dTaskF
            ticked
            task
            xs