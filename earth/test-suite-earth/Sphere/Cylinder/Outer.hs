{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE QuasiQuotes #-}

{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE ParallelListComp #-}
{-# LANGUAGE PartialTypeSignatures #-}
{-# OPTIONS_GHC -fno-warn-partial-type-signatures #-}
{-# OPTIONS_GHC -fplugin Data.UnitsOfMeasure.Plugin #-}

module Sphere.Cylinder.Outer (outerCylinderUnits) where

import Prelude hiding (span)
import Data.Ratio((%))
import qualified Data.Number.FixedFunctions as F
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit as HU ((@?=), testCase)
import Data.UnitsOfMeasure
    ((*:), (-:), u, convert, unQuantity, fromRational', toRational')
import Data.UnitsOfMeasure.Internal (Quantity(..))

import Flight.Units ()
import Flight.LatLng (Lat(..), Lng(..), LatLng(..))
import Flight.LatLng.Rational (Epsilon(..), defEps)
import Flight.Distance (TaskDistance(..), PathDistance(..), SpanLatLng)
import Flight.Zone (Bearing(..), Radius(..), Zone(..))
import Flight.Zone.Path (distancePointToPoint)
import Flight.Zone.Cylinder
    (Samples(..), SampleParams(..), Tolerance(..), CircumSample, ZonePoint(..))
import qualified Flight.Earth.Sphere.PointToPoint.Rational as Rat (distanceHaversine)
import qualified Flight.Earth.Sphere.Cylinder.Rational as Rat (circumSample)
import Zone (QLL)

mm30 :: Fractional a => Tolerance a
mm30 = Tolerance . fromRational $ 30 % 1000

bearingR :: Bearing Rational
bearingR =
    let (Epsilon e) = defEps in (Bearing . MkQuantity $ F.pi e)

type ZonePointFilter a
    = SpanLatLng a
    -> (Quantity a [u| m |] -> Quantity a [u| m |] -> Bool)
    -> LatLng a [u| rad |]
    -> Quantity a [u| m |]
    -> [ZonePoint a]
    -> [ZonePoint a]

zpFilter
    :: Real a
    => SpanLatLng a
    -> (Quantity a [u| m |] -> Quantity a [u| m |] -> Bool)
    -> LatLng a [u| rad |]
    -> Quantity a [u| m |]
    -> [ZonePoint a]
    -> [ZonePoint a]
zpFilter span cmp origin d =
    filter (\x -> zpDistance span origin x `cmp` d)

zpDistance
    :: (Eq a, Real a)
    => SpanLatLng a
    -> LatLng a [u| rad |]
    -> ZonePoint a
    -> Quantity a [u| m |]
zpDistance span origin ZonePoint{point} =
    d
    where
        TaskDistance d =
            edgesSum $ distancePointToPoint span [Point origin, Point point]

spR :: SampleParams Rational
spR =
    SampleParams
        { spSamples = Samples 100
        , spTolerance = mm30
        }

spanR :: SpanLatLng Rational
spanR = Rat.distanceHaversine defEps

csR :: CircumSample Rational
csR = Rat.circumSample

pts :: (Enum a, Real a, Fractional a) => [QLL a]
pts =
    f
    <$> [ (x *: [u| 1 deg |], y *: [u| 1 deg |]) | x <- [5, 10 .. 90], y <- [0]]
    where
        f (x, y) =
            (convert x, convert y)

distances :: (Real a, Fractional a) => [Radius a [u| m |]]
distances =
    Radius . fromRational'
    <$>
    [ [u| 40 m |]
    , [u| 400 m |]
    , convert [u| 1 km |]
    , convert [u| 10 km |]
    , convert [u| 100 km |]
    ]

tolerancesR :: (Real a, Fractional a) => [Quantity a [u| mm |]]
tolerancesR =
    repeat $ fromRational' [u| 0 mm |]

searchRangesR :: (Real a, Fractional a) => [Quantity a [u| m |]]
searchRangesR =
    fromRational'
    <$>
    [ convert [u| 1 mm |]
    , convert [u| 1 mm |]
    , convert [u| 10 mm |]
    , convert [u| 100 mm |]
    , [u| 100 m |]
    ]

outerCylinderUnits :: TestTree
outerCylinderUnits =
    testGroup "When points meant to be on the boundary are outside a cylinder"
        [ let f = zpFilter in outerCheck spanR csR spR bearingR t s f d p
        | d <- distances
        | t <- Tolerance . unQuantity <$> tolerancesR
        | s <- searchRangesR
        | p <- (\(x, y) -> (LatLng (Lat x, Lng y))) <$> pts
        ]

outerCheck
    ::
        ( Eq a, Show a, Real a, Fractional a
        , Show (Lat a [u| rad |])
        , Show (Lng a [u| rad |])
        )
    => SpanLatLng a
    -> CircumSample a
    -> SampleParams a
    -> Bearing a
    -> Tolerance a
    -> Quantity a [u| m |]
    -> ZonePointFilter a
    -> Radius a [u| m |]
    -> LatLng a [u| rad |]
    -> TestTree
outerCheck
    span cs sampleParams br
    (Tolerance tolerance)
    sr@(MkQuantity searchRange)
    zpf r@(Radius radius) ll =
    HU.testCase
        msg
        $ zpf
            span
            (>)
            ll
            (convert radius -: (convert tolerance'))
            (fst $ cs sp br Nothing cyl)
        @?= []
    where
        msg =
            "No points > "
            ++ show tol
            ++ " outside a "
            ++ show r
            ++ " cylinder when searching within "
            ++ show sr'

        cyl = Cylinder r ll
        sp = sampleParams { spTolerance = Tolerance searchRange }

        tolerance' :: Quantity _ [u| mm |]
        tolerance' = MkQuantity tolerance

        tol :: Quantity Double [u| mm |]
        tol = MkQuantity . realToFrac $ tolerance

        sr' :: Quantity Double [u| m |]
        sr' = fromRational' . toRational' $ sr
