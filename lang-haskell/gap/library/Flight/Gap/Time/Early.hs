module Flight.Gap.Time.Early
    ( JumpedTheGun(..)
    , SecondsPerPoint(..)
    , JumpTheGunLimit(..)
    ) where

import "newtype" Control.Newtype (Newtype(..))
import Data.Aeson (ToJSON(..), FromJSON(..))
import Data.UnitsOfMeasure (u)
import Data.UnitsOfMeasure.Internal (Quantity(..))

import Flight.Units ()
import Data.Via.Scientific (DefaultDecimalPlaces(..), DecimalPlaces(..))
import Data.Via.UnitsOfMeasure (ViaQ(..))

-- | Jumped the gun by this many seconds.
newtype JumpedTheGun a = JumpedTheGun a
    deriving (Eq, Ord, Show, Read)

instance
    (q ~ Quantity Double [u| s |])
    => DefaultDecimalPlaces (JumpedTheGun q) where
    defdp _ = DecimalPlaces 3

instance
    (q ~ Quantity Double [u| s |])
    => Newtype (JumpedTheGun q) q where
    pack = JumpedTheGun
    unpack (JumpedTheGun a) = a

instance (q ~ Quantity Double [u| s |]) => ToJSON (JumpedTheGun q) where
    toJSON x = toJSON $ ViaQ x

instance (q ~ Quantity Double [u| s |]) => FromJSON (JumpedTheGun q) where
    parseJSON o = do
        ViaQ x <- parseJSON o
        return x

-- | For this many seconds, loose 1 point.
newtype SecondsPerPoint a = SecondsPerPoint a
    deriving (Eq, Ord, Show, Read)

instance
    (q ~ Quantity Double [u| s |])
    => DefaultDecimalPlaces (SecondsPerPoint q) where
    defdp _ = DecimalPlaces 0

instance
    (q ~ Quantity Double [u| s |])
    => Newtype (SecondsPerPoint q) q where
    pack = SecondsPerPoint
    unpack (SecondsPerPoint a) = a

instance (q ~ Quantity Double [u| s |]) => ToJSON (SecondsPerPoint q) where
    toJSON x = toJSON $ ViaQ x

instance (q ~ Quantity Double [u| s |]) => FromJSON (SecondsPerPoint q) where
    parseJSON o = do
        ViaQ x <- parseJSON o
        return x

-- | A jump of this many seconds incurs the maximum penalty, the score for
-- minimum distance.
newtype JumpTheGunLimit a = JumpTheGunLimit a
    deriving (Eq, Ord, Show, Read)

instance
    (q ~ Quantity Double [u| s |])
    => DefaultDecimalPlaces (JumpTheGunLimit q) where
    defdp _ = DecimalPlaces 0

instance
    (q ~ Quantity Double [u| s |])
    => Newtype (JumpTheGunLimit q) q where
    pack = JumpTheGunLimit
    unpack (JumpTheGunLimit a) = a

instance (q ~ Quantity Double [u| s |]) => ToJSON (JumpTheGunLimit q) where
    toJSON x = toJSON $ ViaQ x

instance (q ~ Quantity Double [u| s |]) => FromJSON (JumpTheGunLimit q) where
    parseJSON o = do
        ViaQ x <- parseJSON o
        return x
