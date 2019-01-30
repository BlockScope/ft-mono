{-# LANGUAGE DuplicateRecordFields #-}
{-# OPTIONS_GHC -fno-warn-partial-type-signatures #-}

module Flight.TaskTrack.Double (taskTracks) where

import Data.Either (partitionEithers)
import Data.List (nub)
import Data.UnitsOfMeasure ((/:), u)
import Data.UnitsOfMeasure.Internal (Quantity(..))

import Flight.Units ()
import Flight.LatLng (LatLng(..))
import Flight.LatLng.Raw (RawLatLng(..))
import Flight.Distance (QTaskDistance, PathDistance(..), SpanLatLng)
import Flight.Zone (Zone(..), Bearing(..), ArcSweep(..), center)
import Flight.Zone.Path (distancePointToPoint, costSegment)
import Flight.Zone.Raw (RawZone(..))
import Flight.Zone.Cylinder (CircumSample)
import Flight.Earth.Flat (zoneToProjectedEastNorth)
import Flight.Earth.Flat.Projected.Double (costEastNorth)
import Flight.Earth.Sphere.Cylinder.Double (circumSample)
import Flight.Earth.Sphere.PointToPoint.Double (distanceHaversine)
import Flight.Earth.Ellipsoid.PointToPoint.Double (distanceVincenty)
import Flight.Route
    ( TaskDistanceMeasure(..)
    , OptimalRoute(..)
    , TaskTrack(..)
    )
import Flight.TaskTrack.Internal
    ( mm30
    , roundEastNorth
    , fromUTMRefEastNorth
    , fromUTMRefZone
    , legDistances
    , addTaskDistance
    , convertLatLng
    , toPoint
    , toCylinder
    )
import Flight.Task (Zs(..), CostSegment, AngleCut(..) , fromZs, distanceEdgeToEdge)
import Flight.Route.TrackLine
    ( ToTrackLine(..), GeoLines(..)
    , TrackLine(..), ProjectedTrackLine(..), PlanarTrackLine(..)
    , speedSubset
    )
import Flight.Route.Optimal (emptyOptimal)
import Flight.Earth.Ellipsoid (wgs84)
import Flight.Zone.SpeedSection (SpeedSection, sliceZones)

trackLines :: Bool -> [Zone Double] -> GeoLines
trackLines excludeWaypoints zs =
    GeoLines
        { point = goByPoint excludeWaypoints zs
        , sphere =
            fromZs
            $ toTrackLine spanS excludeWaypoints
            <$> distanceEdgeSphere (costSegment spanS) zs
        , ellipse =
            fromZs
            $ toTrackLine spanE excludeWaypoints
            <$> distanceEdgeEllipsoid (costSegment spanE) zs
        , projected = goByProj excludeWaypoints zs
        }

taskTracks
    :: Bool
    -> (Int -> Bool) -- ^ Process the nth task?
    -> TaskDistanceMeasure
    -> [SpeedSection] -- ^ Speed section of each task.
    -> [[RawZone]] -- ^ Zones of each task.
    -> [Maybe TaskTrack]
taskTracks excludeWaypoints b tdm =
    zipWith3
        (\ i ss zs -> if b i then Just $ taskTrack excludeWaypoints tdm ss zs else Nothing)
        [1 .. ]

taskTrack
    :: Bool
    -> TaskDistanceMeasure
    -> SpeedSection
    -> [RawZone] -- ^ A single task is a sequence of control zones.
    -> TaskTrack
taskTrack excludeWaypoints tdm ss zsRaw =
    case tdm of
        TaskDistanceByAllMethods ->
            TaskTrack
                { ellipsoidPointToPoint =
                    OptimalRoute
                        { taskRoute = Just . point $ taskLines
                        , taskRouteSpeedSubset = Nothing
                        , speedRoute = Just . point $ ssLines
                        }
                , ellipsoidEdgeToEdge =
                    let x = ellipse taskLines in
                    OptimalRoute
                        { taskRoute = x
                        , taskRouteSpeedSubset = speedSubset ss <$> x
                        , speedRoute = ellipse ssLines
                        }
                , sphericalPointToPoint =
                    OptimalRoute
                        { taskRoute = Just . point $ taskLines
                        , taskRouteSpeedSubset = Nothing
                        , speedRoute = Just . point $ ssLines
                        }
                , sphericalEdgeToEdge =
                    let x = sphere taskLines in
                    OptimalRoute
                        { taskRoute = x
                        , taskRouteSpeedSubset = speedSubset ss <$> x
                        , speedRoute = sphere ssLines
                        }
                , projection =
                    OptimalRoute
                        { taskRoute = projected taskLines
                        , taskRouteSpeedSubset = Nothing
                        , speedRoute = projected ssLines
                        }
                }
        TaskDistanceByPoints ->
            TaskTrack
                { ellipsoidPointToPoint =
                    OptimalRoute
                        { taskRoute = Just . point $ taskLines
                        , taskRouteSpeedSubset = Nothing
                        , speedRoute = Just . point $ ssLines
                        }
                , ellipsoidEdgeToEdge = emptyOptimal
                , sphericalPointToPoint =
                    OptimalRoute
                        { taskRoute = Just . point $ taskLines
                        , taskRouteSpeedSubset = Nothing
                        , speedRoute = Just . point $ ssLines
                        }
                , sphericalEdgeToEdge = emptyOptimal
                , projection = emptyOptimal
                }
        TaskDistanceByEdges ->
            TaskTrack
                { ellipsoidPointToPoint = emptyOptimal
                , ellipsoidEdgeToEdge =
                    let x = ellipse taskLines in
                    OptimalRoute
                        { taskRoute = x
                        , taskRouteSpeedSubset = speedSubset ss <$> x
                        , speedRoute = ellipse ssLines
                        }
                , sphericalPointToPoint = emptyOptimal
                , sphericalEdgeToEdge =
                    let x = sphere taskLines in
                    OptimalRoute
                        { taskRoute = x
                        , taskRouteSpeedSubset = speedSubset ss <$> x
                        , speedRoute = sphere ssLines
                        }
                , projection = emptyOptimal
                }
        TaskDistanceByProjection ->
            TaskTrack
                { ellipsoidPointToPoint = emptyOptimal
                , ellipsoidEdgeToEdge = emptyOptimal
                , sphericalPointToPoint = emptyOptimal
                , sphericalEdgeToEdge = emptyOptimal
                , projection =
                    OptimalRoute
                        { taskRoute = projected taskLines
                        , taskRouteSpeedSubset = Nothing
                        , speedRoute = projected ssLines
                        }
                }
    where
        zsTask :: [Zone Double]
        zsTask = toCylinder <$> zsRaw

        zsSpeedSection :: [Zone Double]
        zsSpeedSection = sliceZones ss zsTask

        taskLines = trackLines excludeWaypoints zsTask
        ssLines = trackLines excludeWaypoints zsSpeedSection

-- NOTE: The projected distance is worked out from easting and northing, in the
-- projected plane but he distance for each leg is measured on the sphere.
goByProj :: Bool -> [Zone Double] -> Maybe ProjectedTrackLine
goByProj excludeWaypoints zs = do
    dEE <- fromZs $ distanceEdgeSphere costEastNorth zs

    let projected = toTrackLine spanF excludeWaypoints dEE
    let ps = toPoint <$> waypoints projected
    let (_, es) = partitionEithers $ zoneToProjectedEastNorth <$> ps

    -- NOTE: Workout the distance for each leg projected.
    let legs'' :: [Zs (QTaskDistance Double [u| m |])] =
            zipWith
                (\ a b ->
                    edgesSum
                    <$> distanceEdgeSphere costEastNorth [a, b])
                ps
                (tail ps)

    legs' :: [QTaskDistance Double [u| m |]] <- sequence $ fromZs <$> legs''

    let spherical =
            projected
                { distance =
                    edgesSum <$> distancePointToPoint spanS $ ps
                } :: TrackLine

    let planar =
            PlanarTrackLine
                { distance = distance (projected :: TrackLine)
                , mappedZones =
                    let us = fromUTMRefZone <$> es
                        us' = nub us
                    in if length us' == 1 then us' else us
                , mappedPoints =
                    -- NOTE: Round to millimetres when easting and
                    -- northing are in units of metres.
                    roundEastNorth 3 . fromUTMRefEastNorth <$> es
                , legs = legs'
                , legsSum = scanl1 addTaskDistance legs'
                } :: PlanarTrackLine

    return
        ProjectedTrackLine
            { planar = planar
            , spherical = spherical
            , ellipsoid = spherical
            }

goByPoint :: Bool -> [Zone Double] -> TrackLine
goByPoint excludeWaypoints zs =
    TrackLine
        { distance = d
        , waypoints = if excludeWaypoints then [] else xs
        , legs = ds
        , legsSum = dsSum
        }
    where
        d :: QTaskDistance Double [u| m |]
        d = edgesSum $ distancePointToPoint spanS zs

        -- NOTE: Concentric zones of different radii can be defined that
        -- share the same center. Remove duplicate edgesSum.
        edgesSum' :: [LatLng Double [u| rad |]]
        edgesSum' = nub $ center <$> zs

        xs :: [RawLatLng]
        xs = convertLatLng <$> edgesSum'

        ds :: [QTaskDistance Double [u| m |]]
        ds =
            legDistances
                distancePointToPoint
                spanS
                (Point <$> edgesSum' :: [Zone Double])

        dsSum :: [QTaskDistance Double [u| m |]]
        dsSum = scanl1 addTaskDistance ds

distanceEdgeSphere
    :: CostSegment Double
    -> [Zone Double]
    -> Zs (PathDistance Double)
distanceEdgeSphere segCost = 
    distanceEdgeToEdge spanS distancePointToPoint segCost cs cut mm30

distanceEdgeEllipsoid
    :: CostSegment Double
    -> [Zone Double]
    -> Zs (PathDistance Double)
distanceEdgeEllipsoid segCost = 
    distanceEdgeToEdge spanE distancePointToPoint segCost cs cut mm30

cs :: CircumSample Double
cs = circumSample

-- | Span on a flat projected plane.
spanF :: SpanLatLng Double
spanF = distanceHaversine

-- | Span on a sphere using haversines.
spanS :: SpanLatLng Double
spanS = distanceHaversine

-- | Span on the WGS 84 ellipsoid using Vincenty's solution to the inverse
-- problem.
spanE :: SpanLatLng Double
spanE = distanceVincenty wgs84

cut :: AngleCut Double
cut =
    AngleCut
        { sweep = ArcSweep . Bearing . MkQuantity $ 2 * pi
        , nextSweep = nextCut
        }

nextCut :: AngleCut Double -> AngleCut Double
nextCut x@AngleCut{sweep = ArcSweep (Bearing b)} =
    x{sweep = ArcSweep . Bearing $ b /: 2}
