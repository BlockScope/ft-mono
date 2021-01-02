module Flight.TaskLength (readRoute, writeRoute, readRoutes, writeRoutes) where

import Control.Exception.Safe (MonadThrow)
import Control.Monad.Except (MonadIO, liftIO)
import qualified Data.ByteString as BS
import Data.Yaml (decodeThrow)
import qualified Data.Yaml.Pretty as Y
import Control.Concurrent.ParallelIO (parallel, parallel_)

import Flight.Route (TaskTrack(..), cmpFields)
import Flight.Comp
    ( CompInputFile, TaskLengthFile(..)
    , taskToTaskLength, compFileToTaskFiles
    )

readRoute :: (MonadThrow m, MonadIO m) => TaskLengthFile -> m (Maybe TaskTrack)
readRoute (TaskLengthFile path) = liftIO $ BS.readFile path >>= decodeThrow

writeRoute :: TaskLengthFile -> Maybe TaskTrack -> IO ()
writeRoute (TaskLengthFile lenPath) route = do
    let cfg = Y.setConfCompare cmpFields Y.defConfig
    let yaml = Y.encodePretty cfg route
    BS.writeFile lenPath yaml

readRoutes :: CompInputFile -> IO [Maybe TaskTrack]
readRoutes compFile = do
    putStrLn "Reading task lengths from:"
    taskFiles <- compFileToTaskFiles compFile
    parallel
        [ do
            putStrLn $ "\t" ++ show routeFile
            readRoute routeFile
        | routeFile <- taskToTaskLength <$> taskFiles
        ]

writeRoutes :: CompInputFile -> [Maybe TaskTrack] -> IO ()
writeRoutes compFile routes = do
    putStrLn "Writing task lengths to:"
    taskFiles <- compFileToTaskFiles compFile
    parallel_
        [ do
            putStrLn $ "\t" ++ show routeFile
            writeRoute routeFile route

        | route <- routes
        | routeFile <- taskToTaskLength <$> taskFiles
        ]
