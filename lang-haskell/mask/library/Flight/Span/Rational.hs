{-# OPTIONS_GHC -fno-warn-orphans #-}

module Flight.Span.Rational () where

import Data.UnitsOfMeasure ((/:))
import Data.UnitsOfMeasure.Internal (Quantity(..))
import qualified Data.Number.FixedFunctions as F

import Flight.LatLng.Rational (Epsilon(..), defEps)
import Flight.Zone (Bearing(..), ArcSweep(..))
import Flight.Zone.MkZones (Zones)
import Flight.Zone.Raw (Give)
import Flight.Geodesy.Solution (Trig, GeodesySolutions(..))
import Flight.Geodesy.Rational ()
import Flight.Task (AngleCut(..))
import Flight.ShortestPath (GeoPath(..))

import Flight.Span.Sliver (GeoSliver(..))
import Flight.Mask.Internal.Zone (TaskZone, zonesToTaskZones)

instance (Real a, Fractional a, GeoPath Rational a) => GeoSliver Rational a where
    angleCut :: Trig Rational a => Earth Rational -> AngleCut Rational
    angleCut _ =
        AngleCut
            { sweep =
                let (Epsilon e) = defEps in
                ArcSweep . Bearing . MkQuantity $ 2 * F.pi e
            , nextSweep =
                \x@AngleCut{sweep = ArcSweep (Bearing b)} ->
                    x{sweep = ArcSweep . Bearing $ b /: 2}
            }

    fromZones :: Trig Rational a => Earth Rational -> Maybe Give -> Zones -> [TaskZone Rational]
    fromZones e g = zonesToTaskZones g $ azimuthFwd @Rational @Rational e
