{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Flight.Validity
    ( NominalLaunch(..)
    , NominalTime(..)
    , NominalDistance(..)
    , MinimumDistance(..)
    , NominalGoal(..)
    , LaunchValidity(..)
    , TimeValidity(..)
    , DistanceValidity(..)
    , TaskValidity(..)
    , Seconds
    , Metres
    , launchValidity
    , distanceValidity
    , timeValidity
    , taskValidity
    ) where

import Data.Ratio ((%))
import Flight.Ratio (pattern (:%))

newtype NominalLaunch = NominalLaunch Rational deriving (Eq, Show)
type SumOfDistance = Metres
newtype MinimumDistance a = MinimumDistance a deriving (Eq, Ord, Show)
newtype MaximumDistance = MaximumDistance Integer deriving (Eq, Show)
newtype NominalDistance = NominalDistance Integer deriving (Eq, Show)
newtype NominalTime = NominalTime Integer deriving (Eq, Show)
newtype NominalGoal = NominalGoal Rational deriving (Eq, Show)

newtype LaunchValidity = LaunchValidity Rational deriving (Eq, Show)
newtype TimeValidity = TimeValidity Rational deriving (Eq, Show)
newtype DistanceValidity = DistanceValidity Rational deriving (Eq, Show)

-- | Also called Day Quality.
newtype TaskValidity = TaskValidity Rational deriving (Eq, Show)

type Seconds = Integer
type Metres = Integer

launchValidity :: NominalLaunch -> Rational -> LaunchValidity
launchValidity (NominalLaunch (_ :% _)) (0 :% _) =
    LaunchValidity (0 % 1)
launchValidity (NominalLaunch (0 :% _)) (_ :% _) =
    LaunchValidity (1 % 1)
launchValidity (NominalLaunch (n :% d)) (flying :% present) =
    LaunchValidity $
    (27 % 1000) * lvr
    + (2917 % 1000) * lvr * lvr
    - (1944 % 1000) * lvr * lvr * lvr
    where
        lvr' = (flying * d) % (present * n)
        lvr = min lvr' (1 % 1)

tvrValidity :: Rational -> TimeValidity
tvrValidity (0 :% _) =
    TimeValidity 0
tvrValidity tvr =
    TimeValidity $ max 0 $ min 1 x
    where
        x =
            (- 271 % 1000)
            + (2912 % 1000) * tvr
            - (2098 % 1000) * tvr * tvr
            + (457 % 1000) * tvr * tvr * tvr

timeValidity :: NominalTime -> NominalDistance -> Maybe Seconds -> Metres -> TimeValidity
timeValidity (NominalTime 0) _ (Just 0) _ = tvrValidity (0 % 1)
timeValidity (NominalTime 0) _ (Just _) _ = tvrValidity (1 % 1)
timeValidity (NominalTime nt) _ (Just t) _ = tvrValidity $ min (t % nt) (1 % 1)
timeValidity _ (NominalDistance 0) Nothing 0 = tvrValidity (0 % 1)
timeValidity _ (NominalDistance 0) Nothing _ = tvrValidity (1 % 1)
timeValidity _ (NominalDistance nd) Nothing d = tvrValidity $ min (d % nd) (1 % 1)

dvr :: Rational -> Integer -> Metres -> Rational
dvr (0 :% _) _ _ = 1 % 1
dvr (n :% d) nFly dSum = (dSum % 1) * (d % (nFly * n))

distanceValidity :: NominalGoal
                 -> NominalDistance
                 -> Integer
                 -> MinimumDistance Integer
                 -> MaximumDistance
                 -> SumOfDistance
                 -> DistanceValidity
distanceValidity _ _ 0 _ _ _ =
    DistanceValidity 0
distanceValidity _ _ _ _ (MaximumDistance 0) _ =
    DistanceValidity 0
distanceValidity (NominalGoal (0 :% _)) (NominalDistance 0) nFly _ _ dSum =
    DistanceValidity $ min 1 $ dvr (0 % 1) nFly dSum
distanceValidity
    (NominalGoal (0 :% _))
    (NominalDistance nd)
    nFly
    (MinimumDistance dMin)
    _
    dSum
    | nd < dMin =
        DistanceValidity (1 % 1)
    | otherwise =
        DistanceValidity $ min 1 $ dvr area nFly dSum
        where
            area = num % (2 * den)
            (num :% den) = min 0 (nd - dMin) % 1
distanceValidity
    (NominalGoal ng)
    (NominalDistance nd)
    nFly
    (MinimumDistance dMin)
    (MaximumDistance dMax)
    dSum
    | nd < dMin =
        DistanceValidity (1 % 1)
    | otherwise =
        DistanceValidity $ min 1 $ dvr area nFly dSum
    where
        area = num % (2 * den)
        (num :% den) =
            (ng + (1 % 1) * ((nd - dMin) % 1)) + max 0 (ng * ((dMax - nd) % 1))

taskValidity :: LaunchValidity -> TimeValidity -> DistanceValidity -> TaskValidity
taskValidity (LaunchValidity l) (TimeValidity t) (DistanceValidity d) =
    TaskValidity $ l * t * d
