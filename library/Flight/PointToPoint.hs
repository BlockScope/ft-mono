{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

{-# OPTIONS_GHC -fplugin Data.UnitsOfMeasure.Plugin #-}

module Flight.PointToPoint
    ( TaskDistance(..)
    , distancePointToPoint
    , distanceHaversineF
    , distanceHaversine
    ) where

import Prelude hiding (sum)
import Data.Ratio((%))
import qualified Data.Number.FixedFunctions as F
import Data.UnitsOfMeasure (One, (+:), (-:), (*:), u, convert, abs', zero)
import Data.UnitsOfMeasure.Internal (Quantity(..), mk, fromRational')
import Data.Number.RoundingFunctions (dpRound)

import Flight.Geo
    ( Lat(..)
    , Lng(..)
    , LatLng(..)
    , Epsilon(..)
    , earthRadius
    , defEps
    , degToRadLL
    )
import Flight.Zone (Zone(..), Radius(..), center)
import Flight.Units (map')

newtype TaskDistance =
    TaskDistance (Quantity Rational [u| m |])
    deriving (Eq, Ord)

instance Show TaskDistance where
    show (TaskDistance d) = "d = " ++ show d'''
        where
            d' = convert d :: Quantity Rational [u| km |]
            d'' = map' (dpRound 2) d'
            d''' = fromRational' d'' :: Quantity Double [u| km |]

-- | Sperical distance using haversines and floating point numbers.
distanceHaversineF :: LatLng [u| deg |]
                   -> LatLng [u| deg |]
                   -> TaskDistance
distanceHaversineF xDegreeLL yDegreeLL =
    TaskDistance $ radDist *: earthRadius
    where
        -- NOTE: Use xLatF etc to avoid an hlint duplication warning.
        LatLng (Lat xLatF, Lng xLngF) = degToRadLL defEps xDegreeLL
        LatLng (Lat yLatF, Lng yLngF) = degToRadLL defEps yDegreeLL
        (dLatF, dLngF) = (yLatF -: xLatF, yLngF -: xLngF)

        haversine :: Quantity Rational [u| rad |]
                  -> Quantity Double [u| rad |]
        haversine (MkQuantity x) =
            MkQuantity $ y * y
            where
                y :: Double
                y = sin $ fromRational (x * (1 % 2))

        a :: Double
        a =
            hLatF
            + cos (fromRational xLatF')
            * cos (fromRational yLatF')
            * hLngF
            where
                (MkQuantity xLatF') = xLatF
                (MkQuantity yLatF') = yLatF
                (MkQuantity hLatF) = haversine dLatF
                (MkQuantity hLngF) = haversine dLngF

        radDist :: Quantity Rational One
        radDist = mk $ toRational $ 2 * asin (sqrt a)

-- | Sperical distance using haversines and rational numbers.
distanceHaversine :: Epsilon
                  -> LatLng [u| deg |]
                  -> LatLng [u| deg |]
                  -> TaskDistance
distanceHaversine (Epsilon eps) xDegreeLL yDegreeLL =
    TaskDistance $ radDist *: earthRadius
    where
        LatLng (Lat xLat, Lng xLng) = degToRadLL defEps xDegreeLL
        LatLng (Lat yLat, Lng yLng) = degToRadLL defEps yDegreeLL
        (dLat, dLng) = (yLat -: xLat, yLng -: xLng)

        haversine :: Quantity Rational [u| rad |]
                  -> Quantity Rational [u| rad |]
        haversine (MkQuantity x) =
            MkQuantity $ y * y
            where
                y :: Rational
                y = F.sin eps (x * (1 % 2))

        a :: Rational
        a =
            hLat
            + F.cos eps xLat'
            * F.cos eps yLat'
            * hLng
            where
                (MkQuantity xLat') = xLat
                (MkQuantity yLat') = yLat
                (MkQuantity hLat) = haversine dLat
                (MkQuantity hLng) = haversine dLng

        radDist :: Quantity Rational One
        radDist = mk $ 2 * F.asin eps (F.sqrt eps a)

-- | One way of measuring task distance is going point-to-point through each control
-- zone's center along the course from start to goal. This is not used by CIVL
-- but sometimes task distance will be reported this way.
--
-- The speed section  usually goes from start exit cylinder to goal cylinder
-- or to goal line. The optimal way to fly this in a zig-zagging course will
-- avoid zone centers for a shorter flown distance.
distancePointToPoint :: [ Zone [u| deg |] ] -> TaskDistance

distancePointToPoint [] = TaskDistance zero

distancePointToPoint [_] = TaskDistance zero

distancePointToPoint [Cylinder (Radius xR) x, Cylinder (Radius yR) y]
    | x == y && xR /= yR = TaskDistance dR
    | otherwise = distancePointToPoint [Point x, Point y]
    where
        dR :: Quantity Rational [u| m |]
        dR = abs' $ xR -: yR

distancePointToPoint xs@[a, b]
    | a == b = TaskDistance zero
    | otherwise = distance xs

distancePointToPoint xs = distance xs

sum :: [Quantity Rational [u| m |]] -> Quantity Rational [u| m |]
sum = foldr (+:) zero

distance :: [Zone [u| deg |] ] -> TaskDistance
distance xs =
    TaskDistance $ sum $ zipWith f ys (tail ys)
    where
        ys = center <$> xs
        unwrap (TaskDistance x) = x

        f :: LatLng [u| deg |]
          -> LatLng [u| deg |]
          -> Quantity Rational [u| m |]
        f = (unwrap .) . distanceHaversine defEps

