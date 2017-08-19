{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE QuasiQuotes #-}

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE LambdaCase #-}

{-# OPTIONS_GHC -fplugin Data.UnitsOfMeasure.Plugin #-}

module Cmd.Driver (driverMain) where

import Data.String (IsString)
import Control.Monad (mapM_)
import Control.Monad.Except (ExceptT(..), runExceptT)
import Data.UnitsOfMeasure.Internal (Quantity(..))
import System.Directory (doesFileExist, doesDirectoryExist)
import System.FilePath.Find (FileType(..), (==?), (&&?), find, always, fileType, extension)
import System.FilePath (FilePath, takeFileName, replaceExtension, dropExtension)
import Cmd.Args (withCmdArgs)
import Cmd.Options (CmdOptions(..), Reckon(..))
import qualified Data.Yaml.Pretty as Y
import qualified Data.ByteString as BS

import qualified Data.Flight.Comp as Cmp (CompSettings(..), Pilot(..))
import qualified Flight.Task as Tsk (TaskDistance(..))
import qualified Flight.Score as Gap (PilotDistance(..), PilotTime(..))
import Data.Flight.TrackLog (TrackFileFail(..), IxTask(..))
import Flight.Units ()
import Flight.Mask.Pilot
    ( checkTracks
    , madeZones
    , launched
    , madeGoal
    , distanceToGoal
    , distanceFlown
    , timeFlown
    )
import Flight.Mask.Task (taskTracks)
import qualified Data.Flight.TrackZone as TZ
    (TaskTrack(..), FlownTrack(..), PilotFlownTrack(..), TrackZoneIntersect(..))

driverMain :: IO ()
driverMain = withCmdArgs drive

cmp :: (Ord a, IsString a) => a -> a -> Ordering
cmp a b =
    case (a, b) of
        ("pointToPoint", _) -> LT
        ("edgeToEdge", _) -> GT
        ("lat", _) -> LT
        ("lng", _) -> GT
        ("distance", _) -> LT
        ("wayPoints", _) -> GT
        ("taskTracks", _) -> LT
        ("pilotTracks", _) -> GT
        ("launched", _) -> LT
        ("madeGoal", "launched") -> GT
        ("madeGoal", _) -> LT
        ("zonesMade", "launched") -> GT
        ("zonesMade", "madeGoal") -> GT
        ("zonesMade", _) -> LT
        ("zonesNotMade", "launched") -> GT
        ("zonesNotMade", "madeGoal") -> GT
        ("zonesNotMade", "zonesMade") -> GT
        ("zonesNotMade", _) -> LT
        ("timeToGoal", "launched") -> GT
        ("timeToGoal", "madeGoal") -> GT
        ("timeToGoal", "zonesMade") -> GT
        ("timeToGoal", "zonesNotMade") -> GT
        ("timeToGoal", _) -> LT
        ("distanceToGoal", "launched") -> GT
        ("distanceToGoal", "madeGoal") -> GT
        ("distanceToGoal", "zonesMade") -> GT
        ("distanceToGoal", "zonesNotMade") -> GT
        ("distanceToGoal", "timeToGoal") -> GT
        ("distanceToGoal", _) -> LT
        ("bestDistance", _) -> GT
        _ -> compare a b

drive :: CmdOptions -> IO ()
drive CmdOptions{..} = do
    dfe <- doesFileExist file
    if dfe then
        withFile file
    else do
        dde <- doesDirectoryExist dir
        if dde then do
            files <- find always (fileType ==? RegularFile &&? extension ==? ".comp.yaml") dir
            mapM_ withFile files
        else
            putStrLn "Couldn't find any flight score competition yaml input files."
    where
        withFile yamlCompPath = do
            putStrLn $ takeFileName yamlCompPath
            let yamlMaskPath =
                    flip replaceExtension ".mask.yaml"
                    $ dropExtension yamlCompPath
            ts <- runExceptT $ taskTracks yamlCompPath
            case ts of
                Left msg -> print msg
                Right ts' -> do

                    case reckon of
                        Zones ->
                            let go = writeMask ts' yamlMaskPath
                            in go checkZones (\zs ->
                                TZ.FlownTrack
                                    { launched = True
                                    , madeGoal = True
                                    , zonesMade = zs
                                    , timeToGoal = Nothing
                                    , distanceToGoal = Nothing
                                    , bestDistance = Nothing
                                    })

                        Launch ->
                            let go = writeMask ts' yamlMaskPath
                            in go checkLaunched (\x ->
                                TZ.FlownTrack
                                    { launched = x
                                    , madeGoal = True
                                    , zonesMade = []
                                    , timeToGoal = Nothing
                                    , distanceToGoal = Nothing
                                    , bestDistance = Nothing
                                    })

                        Goal ->
                            let go = writeMask ts' yamlMaskPath
                            in go checkMadeGoal (\x ->
                                TZ.FlownTrack
                                    { launched = True
                                    , madeGoal = x
                                    , zonesMade = [] 
                                    , timeToGoal = Nothing
                                    , distanceToGoal = Nothing
                                    , bestDistance = Nothing
                                    })

                        GoalDistance ->
                            let go = writeMask ts' yamlMaskPath
                            in go checkDistanceToGoal (\td ->
                                TZ.FlownTrack
                                    { launched = True
                                    , madeGoal = True
                                    , zonesMade = []
                                    , timeToGoal = Nothing
                                    , distanceToGoal =
                                        (\(Tsk.TaskDistance (MkQuantity d)) -> fromRational d) <$> td
                                    , bestDistance = Nothing 
                                    })

                        FlownDistance ->
                            let go = writeMask ts' yamlMaskPath
                            in go checkDistanceFlown (\fd ->
                                TZ.FlownTrack
                                    { launched = True
                                    , madeGoal = True
                                    , zonesMade = []
                                    , timeToGoal = Nothing
                                    , distanceToGoal = Nothing
                                    , bestDistance =
                                        (\(Gap.PilotDistance d) -> fromRational d) <$> fd
                                    })

                        Time ->
                            let go = writeMask ts' yamlMaskPath
                            in go checkTimeToGoal (\ttg ->
                                TZ.FlownTrack
                                    { launched = True
                                    , madeGoal = True
                                    , zonesMade = []
                                    , timeToGoal =
                                        (\(Gap.PilotTime t) -> fromRational t) <$> ttg
                                    , distanceToGoal = Nothing
                                    , bestDistance = Nothing
                                    })

                        x -> putStrLn $ "TODO: Handle other reckon of " ++ show x

            where
                writeMask :: forall a. [TZ.TaskTrack]
                          -> FilePath
                          -> (FilePath
                              -> [IxTask]
                              -> [Cmp.Pilot]
                              -> ExceptT
                                  String
                                  IO
                                  [[Either
                                      (Cmp.Pilot, TrackFileFail)
                                      (Cmp.Pilot, a)
                                  ]])
                          -> (a -> TZ.FlownTrack)
                          -> IO ()
                writeMask os yamlPath f g = do
                    checks <-
                        runExceptT $
                            f
                                yamlCompPath
                                (IxTask <$> task)
                                (Cmp.Pilot <$> pilot)

                    case checks of
                        Left msg -> print msg
                        Right xs -> do
                            let ps :: [[TZ.PilotFlownTrack]] =
                                    (fmap . fmap)
                                        (\case
                                            Left (p, _) ->
                                                TZ.PilotFlownTrack p Nothing

                                            Right (p, x) ->
                                                TZ.PilotFlownTrack p (Just $ g x))
                                        xs

                            let tzi =
                                    TZ.TrackZoneIntersect
                                        { taskTracks = os
                                        , pilotTracks = ps 
                                        }

                            let yaml =
                                    Y.encodePretty
                                        (Y.setConfCompare cmp Y.defConfig)
                                        tzi 

                            BS.writeFile yamlPath yaml

                checkZones =
                    checkTracks $ \Cmp.CompSettings{tasks} -> madeZones tasks

                checkLaunched =
                    checkTracks $ \Cmp.CompSettings{tasks} -> launched tasks

                checkMadeGoal =
                    checkTracks $ \Cmp.CompSettings{tasks} -> madeGoal tasks

                checkDistanceToGoal =
                    checkTracks $ \Cmp.CompSettings{tasks} -> distanceToGoal tasks

                checkDistanceFlown =
                    checkTracks $ \Cmp.CompSettings{tasks} -> distanceFlown tasks

                checkTimeToGoal =
                    checkTracks $ \Cmp.CompSettings{tasks} -> timeFlown tasks
