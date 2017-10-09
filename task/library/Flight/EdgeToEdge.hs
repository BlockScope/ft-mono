module Flight.EdgeToEdge (distanceEdgeToEdge) where

import Data.UnitsOfMeasure.Internal (Quantity(..))
import Control.Arrow (first)
import Data.Graph.Inductive.Graph (Graph(..), Node, LEdge, mkGraph)
import Data.Graph.Inductive.PatriciaTree (Gr)

import Flight.Zone (Zone(..), Bearing(..))
import Flight.PointToPoint (TaskDistance(..), distancePointToPoint)
import Flight.CylinderEdge
    ( Tolerance
    , SampleParams(..)
    , ZonePoint(..)
    , sample
    )
import Flight.Units ()
import Flight.ShortestPath
    (DistancePath(..), EdgeDistance(..), PathCost(..), shortestPath)

distanceEdgeToEdge :: DistancePath
                   -> Tolerance
                   -> [Zone]
                   -> EdgeDistance
distanceEdgeToEdge = shortestPath buildGraph

buildGraph :: SampleParams
           -> Bearing
           -> Maybe [ZonePoint]
           -> [Zone]
           -> Gr ZonePoint PathCost
buildGraph sp b zs xs =
    mkGraph flatNodes flatEdges
    where
        nodes' :: [[ZonePoint]]
        nodes' =
            case zs of
              Nothing ->
                  sample sp b Nothing <$> xs

              Just zs' ->
                  (\z -> sample sp b (Just z) (sourceZone z)) <$> zs'

        len :: Int
        len = sum $ map length nodes'

        iiNodes :: [[(Node, ZonePoint)]]
        iiNodes = zip [1 .. ] <$> nodes'

        iNodes :: [[(Node, ZonePoint)]]
        iNodes =
            zipWith
            (\i ys -> first (\y -> y + i * len) <$> ys)
            [1 .. ]
            iiNodes

        edges' :: [[LEdge PathCost]]
        edges' = zipWith connectNodes iNodes (tail iNodes)

        flatEdges :: [LEdge PathCost]
        flatEdges = concat edges'

        flatNodes :: [(Node, ZonePoint)]
        flatNodes = concat iNodes

-- | NOTE: The shortest path may traverse a cylinder so I include
-- edges within a cylinder as well as edges to the next cylinder.
connectNodes :: [(Node, ZonePoint)]
             -> [(Node, ZonePoint)]
             -> [LEdge PathCost]
connectNodes xs ys =
    [ f x1 x2 | x1 <- xs, x2 <- xs ]
    ++
    [ f x y | x <- xs, y <- ys ]
    where
        f :: (Node, ZonePoint) -> (Node, ZonePoint) -> LEdge PathCost
        f (i, x) (j, y) = (i, j, PathCost d)
            where
                (TaskDistance (MkQuantity d)) =
                    distancePointToPoint [Point $ point x, Point $ point y]
