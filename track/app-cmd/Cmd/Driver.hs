{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Cmd.Driver (driverMain) where

import Data.Maybe (catMaybes)
import Control.Monad (mapM_)
import System.Directory (doesFileExist, doesDirectoryExist)
import System.FilePath.Find (FileType(..), (==?), (&&?), find, always, fileType, extension)
import System.FilePath
    ( FilePath
    , (</>)
    , takeFileName
    , takeDirectory
    , normalise
    , splitDirectories
    , joinPath
    )

import Cmd.Args (withCmdArgs)
import Cmd.Options (CmdOptions(..), Reckon(..))
import qualified Data.Flight.Kml as K (parse)
import Data.Flight.Pilot
    ( Pilot(..)
    , PilotTrackLogFile(..)
    , TrackLogFile(..)
    , TaskFolder(..)
    , parseTracks
    , parseTaskFolders
    )

type Task = Int

driverMain :: IO ()
driverMain = withCmdArgs drive

drive :: CmdOptions -> IO ()
drive CmdOptions{..} = do
    dfe <- doesFileExist file
    if dfe then
        go file
    else do
        dde <- doesDirectoryExist dir
        if dde then do
            files <- find always (fileType ==? RegularFile &&? extension ==? ".fsdb") dir
            mapM_ go files
        else
            putStrLn "Couldn't find any flight score competition database input files."
    where
        go path = do
            putStrLn $ takeFileName path
            contents <- readFile path
            let contents' = dropWhile (/= '<') contents

            case reckon of
                Goal ->
                    printMadeGoal
                        (takeDirectory path)
                        task
                        (Pilot <$> pilot)
                        contents'

                x ->
                    putStrLn $ "TODO: Handle other reckon of " ++ show x

data PilotTrackStatus
    = TaskFolderExistsNot String
    | TrackLogFileExistsNot String
    | TrackLogFileNotSet
    | TrackLogFileRead Int
    | TrackLogFileNotRead String

instance Show PilotTrackStatus where
    show (TaskFolderExistsNot x) = "Folder '" ++ x ++ "' not found"
    show (TrackLogFileExistsNot x) = "File '" ++ x ++ "' not found"
    show TrackLogFileNotSet = "File not set"
    show (TrackLogFileNotRead "") = "File not read"
    show (TrackLogFileNotRead x) = "File not read " ++ x
    show (TrackLogFileRead count) = "File read " ++ show count ++ " fixes"

goalPilotTrack :: PilotTrackLogFile -> IO (Pilot, PilotTrackStatus)
goalPilotTrack (PilotTrackLogFile p Nothing) = return (p, TrackLogFileNotSet)
goalPilotTrack (PilotTrackLogFile p (Just (TrackLogFile file))) = do
    let folder = takeDirectory file
    dde <- doesDirectoryExist folder
    if not dde then return (p, TaskFolderExistsNot folder) else do
        dfe <- doesFileExist file
        if not dfe then return (p, TrackLogFileExistsNot file) else do
            contents <- readFile file
            kml <- K.parse contents
            case kml of
                Left msg -> return (p, TrackLogFileNotRead msg)
                Right fixes -> return (p, TrackLogFileRead $ length fixes)

goalTaskPilotTracks :: [ (Int, [ PilotTrackLogFile ]) ] -> IO [ String ]
goalTaskPilotTracks [] = return [ "No tasks." ]
goalTaskPilotTracks xs = do
    zs <- sequence $ (\(i, pilotTracks) -> do
                ys <- sequence $ goalPilotTrack <$> pilotTracks
                return $ "Task #"
                         ++ show i
                         ++ " pilot tracks: "
                         ++ (unlines $ show <$> ys))
                <$> xs
    return $ zs

goalPilotTracks :: [[ PilotTrackLogFile ]] -> IO String
goalPilotTracks [] = return "No pilots."
goalPilotTracks tasks = do
    xs <- goalTaskPilotTracks (zip [ 1 .. ] tasks) 
    return $ unlines xs

filterPilots :: [ Pilot ]
             -> [[ PilotTrackLogFile ]]
             -> [[ PilotTrackLogFile ]]

filterPilots [] xs = xs
filterPilots pilots xs =
    f <$> xs
    where
        f :: [ PilotTrackLogFile ] -> [ PilotTrackLogFile ]
        f ys =
            catMaybes
            $ (\x@(PilotTrackLogFile pilot _) ->
                if pilot `elem` pilots then Just x else Nothing)
            <$> ys

filterTasks :: [ Task ]
            -> [[ PilotTrackLogFile ]]
            -> [[ PilotTrackLogFile ]]

filterTasks [] xs = xs
filterTasks tasks xs =
    zipWith (\i ys ->
        if i `elem` tasks then ys else []) [ 1 .. ] xs

makeAbsolute :: FilePath -> TaskFolder -> PilotTrackLogFile -> PilotTrackLogFile
makeAbsolute _ _ x@(PilotTrackLogFile _ Nothing) = x
makeAbsolute dir (TaskFolder pathParts) (PilotTrackLogFile p (Just (TrackLogFile file))) =
    PilotTrackLogFile p (Just (TrackLogFile path))
    where
        parts :: [ FilePath ]
        parts = splitDirectories dir ++ pathParts

        path :: FilePath
        path = normalise $ (joinPath parts) </> file

printMadeGoal :: FilePath -> [ Task ] -> [ Pilot ] -> String -> IO ()
printMadeGoal dir tasks pilots contents = do
    xs <- parseTracks contents
    folders <- parseTaskFolders contents
    case (xs, folders) of
         (Left msg, _) -> print msg
         (_, Left msg) -> print msg
         (Right xs', Right folders') -> do
             let ys = filterPilots pilots $ filterTasks tasks xs'
             let fs = (makeAbsolute dir) <$> folders'
             let zs = zipWith (\f y -> f <$> y) fs ys
             s <- goalPilotTracks zs
             putStr s
