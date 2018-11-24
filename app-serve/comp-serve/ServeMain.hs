import System.Environment (getProgName)
import System.Console.CmdArgs.Implicit (cmdArgs)
import Network.Wai (Application)
import Network.Wai.Middleware.Cors (simpleCors)
import Network.Wai.Handler.Warp
    (runSettings, defaultSettings, setPort, setBeforeMainLoop)
import Servant
    ( (:<|>)(..)
    , Get, JSON, Server, Handler(..), Proxy(..), ServantErr
    , (:>)
    , hoistServer, serve
    )
import System.IO (hPutStrLn, stderr)
import Control.Monad.IO.Class (MonadIO)
import Control.Monad.Reader (ReaderT, MonadReader, asks, runReaderT)
import Control.Monad.Except (ExceptT(..), MonadError, runExceptT)

import System.FilePath (takeFileName)
import Data.Yaml (prettyPrintParseException)

import Flight.Track.Cross (Crossing(..))
import Flight.Track.Point (Pointing(..))
import Flight.Scribe (readComp, readCrossing, readPointing)
import Flight.Cmd.Paths (LenientFile(..), checkPaths)
import Flight.Cmd.Options (ProgramName(..))
import Flight.Cmd.ServeOptions (CmdServeOptions(..), mkOptions)
import Flight.Comp
    ( FileType(CompInput)
    , CompSettings(..)
    , Comp
    , Task
    , Nominal(..)
    , PilotTrackLogFile(..)
    , Pilot(..)
    , CompInputFile(..)
    , CrossZoneFile(..)
    , GapPointFile(..)
    , findCompInput
    , compToCross
    , compToPoint
    , ensureExt
    )
import ServeOptions (description)

data Config k
    = Config
        { compSettings :: CompSettings k
        , crossing :: Crossing
        , pointing :: Pointing
        }

newtype AppT k m a =
    AppT
        { unApp :: ReaderT (Config k) (ExceptT ServantErr m) a
        }
    deriving newtype
        ( Functor
        , Applicative
        , Monad
        , MonadReader (Config k)
        , MonadError ServantErr
        , MonadIO
        )

type Api k =
    "comps" :> Get '[JSON] Comp
    :<|> "nominals" :> Get '[JSON] Nominal
    :<|> "tasks" :> Get '[JSON] [Task k]
    :<|> "pilots" :> Get '[JSON] [[Pilot]]
    :<|> "gap-points" :> Get '[JSON] Pointing

api :: Proxy (Api k)
api = Proxy

convertApp :: Config k -> AppT k IO a -> Handler a
convertApp cfg appt = Handler $ runReaderT (unApp appt) cfg

main :: IO ()
main = do
    name <- getProgName
    options <- cmdArgs $ mkOptions (ProgramName name) description Nothing

    let lf = LenientFile {coerceFile = ensureExt CompInput}
    err <- checkPaths lf options

    maybe (drive options) putStrLn err

drive :: CmdServeOptions -> IO ()
drive o = do
    files <- findCompInput o
    if null files then putStrLn "Couldn't find any input files."
                  else mapM_ (go o) files
go :: CmdServeOptions -> CompInputFile -> IO ()
go CmdServeOptions{..} compFile@(CompInputFile compPath) = do
    let crossFile@(CrossZoneFile crossPath) = compToCross compFile
    let pointFile@(GapPointFile pointPath) = compToPoint compFile
    putStrLn $ "Reading competition from '" ++ takeFileName compPath ++ "'"
    putStrLn $ "Reading pilots that did not fly from '" ++ takeFileName crossPath ++ "'"
    putStrLn $ "Reading scores from '" ++ takeFileName pointPath ++ "'"

    compSettings <- runExceptT $ readComp compFile
    crossing <- runExceptT $ readCrossing crossFile
    pointing <- runExceptT $ readPointing pointFile

    let ppr = putStrLn . prettyPrintParseException

    case (compSettings, crossing, pointing) of
        (Left e, _, _) -> ppr e
        (_, Left e, _) -> ppr e
        (_, _, Left e) -> ppr e
        (Right cs, Right cz, Right gp) ->
            runSettings settings =<< mkApp (Config cs cz gp)
    where
        port = 3000

        settings =
            setPort port $
            setBeforeMainLoop
                (hPutStrLn stderr ("listening on port " ++ show port))
                defaultSettings

-- SEE: https://stackoverflow.com/questions/42143155/acess-a-servant-server-with-a-reflex-dom-client
mkApp :: Config k -> IO Application
mkApp cfg = return . simpleCors . serve api $ serverApi cfg

serverApi :: Config k -> Server (Api k)
serverApi cfg =
    hoistServer
        api
        (convertApp cfg)
        ( (comp <$> asks compSettings)
        :<|> (nominal <$> asks compSettings)
        :<|> (tasks <$> asks compSettings)
        :<|> ((fmap . fmap) pilot . pilots <$> asks compSettings)
        :<|> (asks pointing)
        )
    where
        pilot (PilotTrackLogFile p _) = p
