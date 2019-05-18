{-|
Module      : Flight.Track.Stop
Copyright   : (c) Block Scope Limited 2017
License     : MPL-2.0
Maintainer  : phil.dejoux@blockscope.com
Stability   : experimental

Tracks tagging task control zones for stopped tasks taking consideration of
a restricted time window for scoring.
-}
module Flight.Track.Stop
    ( StopTagging(..)
    , StopWindow(..)
    , RetroActive(..)
    , tardyElapsed
    , tardyGate
    ) where

import Data.List.NonEmpty (nonEmpty)
import Data.Maybe (listToMaybe)
import Data.List (sort)
import Data.String (IsString())
import Data.Time.Clock (UTCTime)
import Control.Monad (join)
import GHC.Generics (Generic)
import Data.Aeson (ToJSON(..), FromJSON(..))

import Flight.Zone.SpeedSection (SpeedSection)
import Flight.Clip (FlyingSection)
import Flight.Score (Pilot(..))
import Flight.Comp (LastStart(..), StartGate(..))
import Flight.Track.Cross (Seconds(..))
import Flight.Track.Tag (TrackTime(..), PilotTrackTag(..), ZonesLastTag(..))
import Flight.Track.Speed (startGateTaken)
import Flight.Field (FieldOrdering(..))

-- | For a stopped task, this is the time the task is scored until, the
-- announced stop time wound back by the score back time.
newtype RetroActive = RetroActive UTCTime
    deriving (Eq, Ord, Show, Generic)
    deriving anyclass (ToJSON, FromJSON)

data StopWindow =
    StopWindow
        { lastStarters :: [Pilot]
        -- ^ The pilot or pilots last to start in an elapsed time race or
        -- a race to goal task with multiple start gates. For race to goal
        -- tasks with a single start gate @lastStarters@ will be an empty list.
        , windowTimes :: FlyingSection UTCTime
        -- ^ The scored window as a time range. For an elapsed time race or
        -- a race to goal task with only one start gate this will be the range
        -- from the start until the retroactive stop time.  For race to goal
        -- task with multiple start gates this will be the time available
        -- racing for the last pilot or pilots to start.
        , windowSeconds :: Seconds
        -- ^ The width of the time window.
        }
    deriving (Eq, Ord, Show, Generic)
    deriving anyclass (ToJSON, FromJSON)

-- | For each task, the timing and tagging for that task.
data StopTagging =
    StopTagging
        { stopWindow :: [Maybe StopWindow]
        -- ^ The scored time window for a stopped task.
        , timing :: [TrackTime]
          -- ^ For each made zone, the first and last tag.
        , tagging :: [[PilotTrackTag]]
          -- ^ For each made zone, the tag.
        }
    deriving (Eq, Ord, Show, Generic)
    deriving anyclass (ToJSON, FromJSON)

-- | Find the last crossing of the start of an elapsed time task.
tardyElapsed :: SpeedSection -> ZonesLastTag -> Maybe LastStart
tardyElapsed _ (ZonesLastTag []) = Nothing
tardyElapsed Nothing (ZonesLastTag (t : _)) = LastStart <$> t
tardyElapsed (Just (firstRaceLeg, _)) (ZonesLastTag ts) =
    LastStart <$> (join . listToMaybe $ drop (firstRaceLeg - 1) ts)

-- | Find the last start of a race task with start gates.
tardyGate :: [StartGate] -> SpeedSection -> [[UTCTime]] -> [[Pilot]] -> Maybe StartGate
tardyGate _ _ [] _ = Nothing
tardyGate _ _ _ [] = Nothing
tardyGate [g] _ _ _ = Just g
tardyGate gs ss ts _ = do
    starts <- listToMaybe $ maybe ts (\(firstRaceLeg, _) -> drop (firstRaceLeg - 1) ts) ss
    gs' <- nonEmpty gs
    lastStart <- listToMaybe . reverse $ sort starts
    return . snd $ startGateTaken gs' lastStart

instance FieldOrdering StopTagging where
    fieldOrder _ = cmp

cmp :: (Ord a, IsString a) => a -> a -> Ordering
cmp a b =
    case (a, b) of

        ("lastStarters", _) -> LT

        ("windowTimes", "lastStarters") -> GT
        ("windowTimes", _) -> LT

        ("windowSeconds", "lastStarters") -> GT
        ("windowSeconds", "windowTimes") -> GT
        ("windowSeconds", _) -> LT

        ("inter", _) -> LT
        ("cross", _) -> GT

        ("fixFrac", _) -> LT
        (_, "fixFrac") -> GT

        ("timing", _) -> LT
        ("tagging", _) -> GT

        ("fix", _) -> LT
        ("time", "fix") -> GT
        ("time", _) -> LT
        ("lat", "fix") -> GT
        ("lat", "time") -> GT
        ("lat", _) -> LT
        ("lng", _) -> GT

        ("zonesSum", _) -> LT

        ("zonesFirst", "zonesSum") -> GT
        ("zonesFirst", _) -> LT

        ("zonesLast", "zonesSum") -> GT
        ("zonesLast", "zonesFirst") -> GT
        ("zonesLast", _) -> LT

        ("zonesRankTime", "zonesSum") -> GT
        ("zonesRankTime", "zonesFirst") -> GT
        ("zonesRankTime", "zonesLast") -> GT
        ("zonesRankTime", _) -> LT

        ("zonesRankPilot", "lastLanding") -> LT
        ("zonesRankPilot", _) -> GT

        ("lastLanding", _) -> GT

        _ -> compare a b

