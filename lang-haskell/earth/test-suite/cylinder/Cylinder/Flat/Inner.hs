module Cylinder.Flat.Inner (innerUnits, innerUnitsR) where

import Prelude hiding (span)
import qualified Data.Number.FixedFunctions as F
import Test.Tasty (TestTree, testGroup)
import Data.UnitsOfMeasure (u, unQuantity)
import Data.UnitsOfMeasure.Internal (Quantity(..))

import Flight.Units ()
import Flight.Units.Angle (Angle(..))
import Flight.LatLng (Lat(..), Lng(..), LatLng(..))
import Flight.LatLng.Rational (Epsilon(..), defEps)
import Flight.Zone (QBearing, Bearing(..))
import Flight.Zone.Cylinder (Tolerance(..))
import Cylinder.Flat.Span
    ( spanD, csD, spD
    , spanR, csR, spR
    , zpFilter
    )
import Cylinder.Inner (ptsUTM, distances, searchRanges, tolerances, innerCheck)

innerUnits :: TestTree
innerUnits =
    testGroup "When points meant to be on the boundary are inside a cylinder"
        [ let f = zpFilter in innerCheck spanD csD spD bearingD t s f d p
        | p <- (\(x, y) -> (LatLng (Lat x, Lng $ plusMinusPi y))) <$> ptsUTM
        | d <- cycle distances
        | t <- Tolerance . unQuantity <$> cycle tolerances
        | s <- cycle searchRanges
        ]

innerUnitsR :: TestTree
innerUnitsR =
    testGroup "When points meant to be on the boundary are inside a cylinder"
        [ let f = zpFilter in innerCheck spanR csR spR bearingR t s f d p
        | p <- (\(x, y) -> (LatLng (Lat x, Lng $ plusMinusPi y))) <$> ptsUTM
        | d <- cycle distances
        | t <- Tolerance . unQuantity <$> cycle tolerances
        | s <- cycle searchRanges
        ]

bearingD :: QBearing Double [u| rad |]
bearingD =
    Bearing . MkQuantity $ pi

bearingR :: QBearing Rational [u| rad |]
bearingR =
    let (Epsilon e) = defEps in (Bearing . MkQuantity $ F.pi e)
