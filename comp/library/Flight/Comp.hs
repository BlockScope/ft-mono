{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE ConstrainedClassMethods #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE MultiWayIf #-}

{-|
Module      : Data.Flight.Comp
Copyright   : (c) Block Scope Limited 2017
License     : BSD3
Maintainer  : phil.dejoux@blockscope.com
Stability   : experimental

Data for competitions, competitors and tasks.
-}
module Flight.Comp
    ( -- * Competition
      CompSettings(..)
    , Comp(..)
    , Nominal(..)
    , UtcOffset(..)
    , defaultNominal
    -- * Task
    , Task(..)
    , IxTask(..)
    , SpeedSection
    , StartGate(..)
    , OpenClose(..)
    , FirstLead(..)
    , FirstStart(..)
    , LastArrival(..)
    , StartEnd(..)
    , StartEndMark
    , RouteLookup(..)
    , showTask
    , openClose
    , speedSectionToLeg
    -- * Pilot and their track logs.
    , Pilot(..)
    , PilotTrackLogFile(..)
    , TrackLogFile(..)
    , TrackFileFail(..)
    , TaskFolder(..)
    , FlyingSection
    -- * Comp paths
    , module Flight.Path
    ) where

import Data.Ratio ((%))
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)
import Data.Aeson (ToJSON(..), FromJSON(..))
import Data.Maybe (listToMaybe)
import Data.List (intercalate)
import Data.String (IsString())
import Data.UnitsOfMeasure (u)
import Data.UnitsOfMeasure.Internal (Quantity(..))

import Flight.Zone.Raw (RawZone, showZone)
import Flight.Field (FieldOrdering(..))
import Flight.Pilot
import Flight.Path
import Flight.Distance (TaskDistance(..))
import Flight.Score
    ( Leg(..)
    , NominalLaunch(..)
    , NominalGoal(..)
    , NominalDistance(..)
    , MinimumDistance(..)
    , NominalTime(..)
    )

-- | The time of first lead into the speed section. This won't exist if no one
-- is able to cross the start of the speed section without bombing out.
newtype FirstLead = FirstLead UTCTime
    deriving (Eq, Ord, Show, Generic, ToJSON, FromJSON)

-- | The time of first start of the speed section. This won't exist if everyone
-- jumps the gun.
newtype FirstStart = FirstStart UTCTime
    deriving (Eq, Ord, Show, Generic, ToJSON, FromJSON)

-- | The time of last crossing of the end of the speed section. This won't
-- exist if no one makes goal and everyone lands out.
newtype LastArrival = LastArrival UTCTime
    deriving (Eq, Ord, Show, Generic, ToJSON, FromJSON)

-- | A race task can be started and not finished if no one makes goal.
data StartEnd a b =
    StartEnd
        { unStart :: a
        , unEnd :: Maybe b
        }

type StartEndMark = StartEnd UTCTime UTCTime

-- | 1-based indices of a task in a competition.
newtype IxTask = IxTask Int deriving (Eq, Show)

-- | A 1-based index into the list of control zones marking the speed section.
type SpeedSection = Maybe (Int, Int)

speedSectionToLeg :: SpeedSection -> Int -> Leg
speedSectionToLeg Nothing i = RaceLeg i
speedSectionToLeg (Just (s, e)) i =
    if | i < s -> PrologLeg i
       | i > e -> EpilogLeg i
       | True -> RaceLeg i

-- | A pair into the list of fixes marking those deemed logged while flying.
-- These could be indices, seconds offsets or UTC times.
type FlyingSection a = Maybe (a, a)

type RoutesLookup a = IxTask -> Maybe a

newtype RouteLookup = RouteLookup (Maybe (RoutesLookup (TaskDistance Double)))

newtype StartGate = StartGate UTCTime
    deriving (Eq, Ord, Show, Generic, ToJSON, FromJSON)

newtype UtcOffset = UtcOffset { timeZoneMinutes :: Int }
    deriving (Eq, Ord, Show, Generic, ToJSON, FromJSON)

data OpenClose =
    OpenClose
        { open :: UTCTime 
        , close :: UTCTime
        }
    deriving (Eq, Ord, Show, Generic, ToJSON, FromJSON)

-- | If all the zone open and close times are the same then we may only be
-- given a singleton list. This function retrieves the open close time
-- for the speed section whether we have a singleton list or a list with
-- elements for each zone.
openClose :: SpeedSection -> [OpenClose] -> Maybe OpenClose
openClose _ [] = Nothing
openClose Nothing (x : _) = Just x
openClose _ [x] = Just x
openClose (Just (_, e)) xs = listToMaybe . take 1 . drop (e - 1) $ xs

data CompSettings =
    CompSettings
        { comp :: Comp
        , nominal :: Nominal
        , tasks :: [Task]
        , taskFolders :: [TaskFolder]
        , pilots :: [[PilotTrackLogFile]]
        }
    deriving (Eq, Ord, Show, Generic, ToJSON, FromJSON)

data Comp =
    Comp
        { civilId :: String
        , compName :: String 
        , location :: String 
        , from :: String 
        , to :: String 
        , utcOffset :: UtcOffset
        }
     deriving (Eq, Ord, Show, Generic, ToJSON, FromJSON)

data Nominal =
    Nominal
        { launch :: NominalLaunch
        , goal :: NominalGoal
        , distance :: NominalDistance (Quantity Double [u| km |])
        , free :: MinimumDistance (Quantity Double [u| km |])
        -- ^ A mimimum distance awarded to pilots that bomb out for 'free'.
        , time :: NominalTime (Quantity Double [u| h |])
        }
    deriving (Eq, Ord, Show, Generic, ToJSON, FromJSON)

defaultNominal :: Nominal
defaultNominal =
    Nominal
        { launch = NominalLaunch $ 96 % 100
        , goal = NominalGoal $ 25 % 100
        , distance = NominalDistance . MkQuantity $ 70
        , free = MinimumDistance . MkQuantity $ 7
        , time = NominalTime . MkQuantity $ 1.5
        }

data Task =
    Task { taskName :: String
         , zones :: [RawZone]
         , speedSection :: SpeedSection
         , zoneTimes :: [OpenClose]
         , startGates :: [StartGate]
         , absent :: [Pilot]
         -- ^ Pilots absent from this task.
         }
    deriving (Eq, Ord, Show, Generic, ToJSON, FromJSON)

showTask :: Task -> String
showTask Task {taskName, zones, speedSection, zoneTimes, startGates} =
    unwords [ "Task '" ++ taskName ++ "'"
            , ", zones "
            , intercalate ", " $ showZone <$> zones
            , ", speed section "
            , show speedSection
            , ", zone times"
            , show zoneTimes 
            , ", start gates "
            , intercalate ", " $ show <$> startGates 
            ]

instance FieldOrdering CompSettings where
    fieldOrder _ = cmp

cmp :: (Ord a, IsString a) => a -> a -> Ordering
cmp a b =
    case (a, b) of
        -- CompSettings fields
        ("comp", _) -> LT
        ("nominal", "comp") -> GT
        ("nominal", _) -> LT
        ("tasks", "taskFolders") -> LT
        ("tasks", "pilots") -> LT
        ("tasks", _) -> GT
        ("taskFolders", "pilots") -> LT
        ("taskFolders", _) -> GT
        ("pilots", _) -> GT

        -- Nominal fields
        ("launch", _) -> LT

        ("goal", "launch") -> GT
        ("goal", "") -> LT

        ("distance", "launch") -> GT
        ("distance", "goal") -> GT
        ("distance", _) -> LT

        ("free", "launch") -> GT
        ("free", "goal") -> GT
        ("free", "distance") -> GT
        ("free", _) -> LT

        ("time", _) -> GT

        -- Comp fields
        ("compName", _) -> LT
        ("location", "compName") -> GT
        ("location", _) -> LT
        ("from", "to") -> LT
        ("civilId", "utcOffset") -> LT
        ("civilId", _) -> GT
        ("utcOffset", _) -> GT

        -- Task fields
        ("taskName", _) -> LT

        ("zones", "taskName") -> GT
        ("zones", _) -> LT

        ("speedSection", "zoneTimes") -> LT
        ("speedSection", "startGates") -> LT
        ("speedSection", "absent") -> LT
        ("speedSection", _) -> GT

        ("zoneTimes", "startGates") -> LT
        ("zoneTimes", "absent") -> LT
        ("zoneTimes", _) -> GT

        ("startGates", "absent") -> LT
        ("startGates", _) -> GT
        ("absent", _) -> GT

        -- StartGates fields
        ("open", _) -> LT
        ("close", _) -> GT

        -- Turnpoint fields
        ("zoneName", _) -> LT
        ("lat", "zoneName") -> GT
        ("lat", _) -> LT
        ("lng", "zoneName") -> GT
        ("lng", "lat") -> GT
        ("lng", _) -> LT
        ("radius", _) -> GT

        _ -> compare a b
