{-# LANGUAGE RecursiveDo #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE KindSignatures #-}

module FlareTiming.View (tasks) where

import Prelude hiding (map)
import Data.Maybe (isJust)
import Control.Monad
import Control.Applicative
import Data.Aeson
import GHC.Generics
import Reflex.Dom
import qualified Data.Text as T
import qualified Data.Map as Map
import Data.Map (Map, fromList, union)
import Data.Monoid((<>))
import Data.Scientific (Scientific, toRealFloat, fromRationalRepetend)

import FlareTiming.Task
    ( Task(..)
    , Turnpoint(..)
    , Latitude(..)
    , Longitude(..)
    , Name
    , Radius
    , SpeedSection
    , fromSci
    , toSci
    , showRadius
    )
import FlareTiming.Map (map)

loading :: MonadWidget t m => m ()
loading = do
    el "li" $ do
        text "Tasks will be shown here"

buttonDynAttr :: MonadWidget t m => Dynamic t (Map T.Text T.Text) -> T.Text -> m (Event t ())
buttonDynAttr attrs label = do
    (e, _) <-
        elDynAttr' "button" attrs $ do
            elClass "i" "fa fa-cloud-download" $ return ()
            (text $ (T.pack " ") <> label)

    return $ domEvent Click e

attribution :: MonadWidget t m => m () 
attribution = do
    el "p" $ do
        el "small" $ do
            text "Map data: (c) "
            elAttr "a" (union ("href" =: "http://www.openstreetmap.org/copyright")
                              ("target" =: "_blank")) $ do
                text "OpenStreetMap"

            text ", "
            elAttr "a" (union ("href" =: "http://viewfinderpanoramas.org")
                              ("target" =: "_blank")) $ do
                text "SRTM"

            text " | Map style: (c) "
            elAttr "a" (union ("href" =: "https://opentopomap.org")
                              ("target" =: "_blank")) $ do
                text "OpenTopoMap"

            text " ("
            elAttr "a" (union ("href" =: "https://creativecommons.org/licenses/by-sa/3.0/")
                              ("target" =: "_blank")) $ do
                text "CC-BY-SA"

            text ")"


navbar :: MonadWidget t m => m ()
navbar = elAttr "nav" (union ("class" =: "navbar navbar-light")
                             ("style" =: "background-color: #e3f2fd;")) $ do
    elClass "a" "navbar-brand" $ text "Flare Timing"

footer :: MonadWidget t m => m ()
footer = elClass "div" "container" $ do
    el "hr" $ return ()
    elClass "div" "text-center text-muted" $ do
        attribution

tasks :: MonadWidget t m => m ()
tasks = el "div" $ do
    navbar
    rec el "ul" $ do widgetHold loading $ fmap getTasks evGet
        evGet <- buttonDynAttr (constDyn ("class" =: "btn btn-primary")) "Get Tasks"
        footer

    return ()

turnpoint :: forall t (m :: * -> *).
             MonadWidget t m =>
             Dynamic t Turnpoint -> m ()
turnpoint x = do
    let dyTp :: Dynamic t T.Text =
            fmap (\(Turnpoint name _ _ radius) ->
                T.pack $ name ++ " " ++ showRadius radius) x

    el "li" $ do
        dynText dyTp

task :: forall t (m :: * -> *).
        MonadWidget t m =>
        Dynamic t Task -> m ()
task x = do
    let dyName :: Dynamic t T.Text =
            fmap (\(Task name _ _) -> T.pack name) x

    let dyTurnpoints :: Dynamic t [Turnpoint] =
            fmap (\(Task _ ss tps) -> speedSectionOnly ss tps) x

    y :: Task <- sample $ current x

    elClass "div" "card" $ do
        elClass "div" "card-img" $ do
            map y
        elAttr "div" (union ("class" =: "card-img-overlay")
                            ("style" =: "left: 1rem")) $ do
            elClass "h6" "card-title" $ dynText dyName

            elClass "p" "card-text" $ do
                el "ul" $ do
                    simpleList dyTurnpoints turnpoint
                    return ()
    where
        speedSectionOnly :: SpeedSection -> [Turnpoint] -> [Turnpoint]
        speedSectionOnly Nothing xs =
            xs
        speedSectionOnly (Just (start, end)) xs =
            take (end' - start' + 1) $ drop (start' - 1) xs
            where
                start' = fromInteger start
                end' = fromInteger end

getTasks :: MonadWidget t m => () -> m ()
getTasks () = do
    pb :: Event t () <- getPostBuild
    let defReq = "http://localhost:3000/tasks"
    let req md = XhrRequest "GET" (maybe defReq id md) def
    rsp <- performRequestAsync $ fmap req $ leftmost [ Nothing <$ pb ]
        
    let es :: Event t [Task] = fmapMaybe decodeXhrResponse rsp
    xs :: Dynamic t [Task] <- holdDyn [] es

    elClass "div" "card-group" $ do
        simpleList xs task

    return ()

