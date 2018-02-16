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
{-# LANGUAGE PartialTypeSignatures #-}
{-# OPTIONS_GHC -fplugin Data.UnitsOfMeasure.Plugin #-}
{-# OPTIONS_GHC -fno-warn-partial-type-signatures #-}

-- | Test data from ...
-- 
-- Bedford Institute of Oceanography
-- Evaluation Direct and Inverse Geodetic Algorithms
-- Paul Delorme, September 1978.
module Bedford (points, solutions, diff, showTolerance) where

import Prelude hiding (min)
import Data.UnitsOfMeasure ((-:), u, convert, fromRational', toRational', abs')
import Data.UnitsOfMeasure.Internal (Quantity(..))

import Flight.Units ()
import Flight.Distance (TaskDistance(..))
import DegMinSec (DMS(..))

showTolerance :: (Real a, Fractional a) => Quantity a [u| m |] -> String
showTolerance d
    | dmm < [u| 1000 mm |] = show dmm
    | dkm < [u| 1 km |] = show dm
    | otherwise = show (TaskDistance dm)
    where
        dm :: Quantity Double _
        dm = fromRational' . toRational' $ d
        
        dkm = convert dm
        dmm = convert dm

diff :: Num a => TaskDistance a -> TaskDistance a -> TaskDistance a
diff (TaskDistance a) (TaskDistance b) =
    TaskDistance . abs' $ a -: b

points :: [((DMS, DMS), (DMS, DMS))]
points =
    (\((xLat, xLng), (yLat, yLng)) -> ((DMS xLat, DMS xLng), (DMS yLat, DMS yLng)))
    <$>
    [ (((10,  0,  0.0), (-18,  0,  0.0)), ((10, 43, 39.078), (-18,  0,  0.0)))
    , (((40,  0,  0.0), (-18,  0,  0.0)), ((40, 43, 28.790), (-18,  0,  0.0)))
    , (((70,  0,  0.0), (-18,  0,  0.0)), ((70, 43, 16.379), (-18,  0,  0.0)))

    , (((10,  0,  0.0), (-18,  0,  0.0)), ((10, 30, 50.497), (-17, 28, 48.777)))
    , (((40,  0,  0.0), (-18,  0,  0.0)), ((40, 30, 37.757), (-17, 19, 43.280)))
    , (((70,  0,  0.0), (-18,  0,  0.0)), ((70, 30, 12.925), (-16, 28, 22.844)))

    , (((10,  0,  0.0), (-18,  0,  0.0)), (( 9, 59, 57.087), (-17, 15, 57.926)))
    , (((40,  0,  0.0), (-18,  0,  0.0)), ((39, 59, 46.211), (-17,  3, 27.942)))
    , (((70,  0,  0.0), (-18,  0,  0.0)), ((69, 59, 15.149), (-15, 53, 37.449)))

    , (((10,  0,  0.0), (-18,  0,  0.0)), (( 9, 38,  8.260), (-17, 21, 54.407)))
    , (((40,  0,  0.0), (-18,  0,  0.0)), ((39, 31, 54.913), (-18, 43,  1.027)))
    , (((70,  0,  0.0), (-18,  0,  0.0)), ((70, 42, 35.533), (-18, 22, 43.683)))

    , (((10,  0,  0.0), (-18,  0,  0.0)), ((14, 21, 52.456), (-18,  0,  0.0)))
    , (((40,  0,  0.0), (-18,  0,  0.0)), ((44, 20, 47.740), (-18,  0,  0.0)))
    , (((70,  0,  0.0), (-18,  0,  0.0)), ((74, 19, 35.289), (-18,  0,  0.0)))

    , (((10,  0,  0.0), (-18,  0,  0.0)), ((13,  4, 12.564), (-14, 51, 13.283)))
    , (((40,  0,  0.0), (-18,  0,  0.0)), ((43,  0,  0.556), (-13, 48, 49.111)))
    , (((70,  0,  0.0), (-18,  0,  0.0)), ((72, 47, 48.242), ( -7, 36, 58.487)))

    , (((10,  0,  0.0), (-18,  0,  0.0)), (( 9, 58, 15.192), (-13, 35, 48.467)))
    , (((40,  0,  0.0), (-18,  0,  0.0)), ((39, 51, 44.295), (-12, 21, 14.090)))
    , (((70,  0,  0.0), (-18,  0,  0.0)), ((69, 33, 22.562), ( -5, 32,  1.822)))

    , (((10,  0,  0.0), (-18,  0,  0.0)), ((17, 16, 24.286), (-18,  0,  0.0)))
    , (((40,  0,  0.0), (-18,  0,  0.0)), ((47, 14, 32.867), (-18,  0,  0.0)))
    , (((70,  0,  0.0), (-18,  0,  0.0)), ((77, 12, 35.253), (-18,  0,  0.0)))

    , (((10,  0,  0.0), (-18,  0,  0.0)), ((15,  5, 43.367), (-12, 42, 50.044)))
    , (((40,  0,  0.0), (-18,  0,  0.0)), ((44, 54, 28.506), (-10, 47, 43.884)))
    , (((70,  0,  0.0), (-18,  0,  0.0)), ((74, 17,  5.184), (  1,  6, 51.561)))

    , (((10,  0,  0.0), (-18,  0,  0.0)), (( 9, 55,  9.138), (-10, 39, 43.554)))
    , (((40,  0,  0.0), (-18,  0,  0.0)), ((39, 37,  6.613), ( -8, 36, 43.277)))
    , (((70,  0,  0.0), (-18,  0,  0.0)), ((68, 47, 25.009), (  2, 17, 23.583)))

    , (((10,  0,  0.0), (-18,  0,  0.0)), ((53, 32,  0.497), (-18,  0,  0.0)))
    , (((40,  0,  0.0), (-18,  0,  0.0)), ((83, 20,  1.540), (-18,  0,  0.0)))
    , (((70,  0,  0.0), (-18,  0,  0.0)), ((66, 45, 22.460), (162,  0,  0.0)))

    , (((10,  0,  0.0), (-18,  0,  0.0)), ((37, 18, 49.295), ( 19, 34,  7.117)))
    , (((40,  0,  0.0), (-18,  0,  0.0)), ((57,  6,  0.851), ( 45,  8, 40.841)))
    , (((70,  0,  0.0), (-18,  0,  0.0)), ((58, 13,  5.486), ( 95,  2, 29.439)))

    , (((10,  0,  0.0), (-18,  0,  0.0)), (( 7, 14,  5.521), ( 25, 48, 13.908)))
    , (((40,  0,  0.0), (-18,  0,  0.0)), ((27, 49, 42.130), ( 32, 54, 13.184)))
    , (((70,  0,  0.0), (-18,  0,  0.0)), ((43,  7, 36.475), ( 52,  1,  0.626)))
    ]

solutions :: [TaskDistance Double]
solutions =
    TaskDistance . convert
    <$>
    [ [u| 80.471341 km |]
    , [u| 80.467842 km |]
    , [u| 80.463616 km |]

    , [u| 80.468422 km |]
    , [u| 80.466106 km |]
    , [u| 80.463284 km |]

    , [u| 80.465497 km |]
    , [u| 80.464363 km |]
    , [u| 80.462951 km |]

    , [u| 80.466994 km |]
    , [u| 80.4659 km |]
    , [u| 80.463589 km |]

    , [u| 482.827311 km |]
    , [u| 482.805398 km |]
    , [u| 482.780699 km |]

    , [u| 482.810039 km |]
    , [u| 482.795399 km |]
    , [u| 482.778968 km |]

    , [u| 482.793074 km |]
    , [u| 482.786227 km |]
    , [u| 482.777777 km |]

    , [u| 804.711122 km |]
    , [u| 804.673374 km |]
    , [u| 804.633279 km |]

    , [u| 804.682723 km |]
    , [u| 804.657459 km |]
    , [u| 804.630834 km |]

    , [u| 804.655123 km |]
    , [u| 804.643847 km |]
    , [u| 804.629907 km |]

    , [u| 4828.136258 km |]
    , [u| 4827.891819 km |]
    , [u| 4827.781145 km |]

    , [u| 4828.022935 km |]
    , [u| 4827.861414 km |]
    , [u| 4827.797208 km |]

    , [u| 4827.933527 km |]
    , [u| 4827.899946 km |]
    , [u| 4827.858337 km |]
    ]
