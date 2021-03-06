﻿module Flight.LatLng.Rational
    ( Epsilon(..)
    , defEps
    , showAngle
    , degToRad
    , radToDeg
    ) where

import Data.Ratio ((%))
import Data.Text.Lazy (unpack)
import qualified Data.Number.FixedFunctions as F
import qualified Formatting as Fmt ((%), format)
import qualified Formatting.ShortFormatters as Fmt (sf)
import Data.UnitsOfMeasure (KnownUnit, Unpack, u)
import Data.UnitsOfMeasure.Show (showUnit, showQuantity)
import Data.UnitsOfMeasure.Internal (Quantity(..))
import Flight.Units ()

showAngle :: KnownUnit (Unpack u) => Quantity Rational u -> String
showAngle q@(MkQuantity x) =
    case showUnit q of
        "rad" -> unpack $ Fmt.format (Fmt.sf Fmt.% "rad") (fromRational x :: Double)
        "deg" -> unpack $ Fmt.format (Fmt.sf Fmt.% "°"  ) (fromRational x :: Double)
        _ -> showQuantity q

newtype Epsilon = Epsilon Rational deriving (Eq, Ord, Show)

-- | Conversion of degrees to radians.
degToRad :: Epsilon
         -> Quantity Rational [u| deg |]
         -> Quantity Rational [u| rad |]
degToRad (Epsilon eps) (MkQuantity x) =
    MkQuantity $ x * F.pi eps / (180 % 1)

-- | Conversion of radians to degrees.
radToDeg :: Epsilon
         -> Quantity Rational [u| rad |]
         -> Quantity Rational [u| deg |]
radToDeg (Epsilon eps) (MkQuantity x) =
    MkQuantity $ x * (180 % 1) / F.pi eps

defEps :: Epsilon
defEps = Epsilon $ 1 % 1000000000000
