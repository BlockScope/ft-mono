{-# LANGUAGE RecursiveDo #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module FlareTiming.Map (map) where

import Prelude hiding (map)
import Reflex.Dom
    ( MonadWidget
    , (=:)
    , elAttr'
    , getPostBuild
    , performEvent_
    , _element_raw
    , el
    , text
    )
import Reflex.Time (delay)
import Control.Monad (sequence)
import Control.Monad.IO.Class (liftIO)

import qualified FlareTiming.Map.Leaflet as L
    ( Marker(..)
    , Circle(..)
    , map
    , mapSetView
    , tileLayer
    , tileLayerAddToMap
    , marker
    , markerAddToMap
    , markerPopup
    , mapInvalidateSize
    , circle
    , circleAddToMap
    , polyline 
    , polylineAddToMap
    , polylineBounds
    , fitBounds
    )
import Data.Flight.Types
    ( Task(..)
    , Turnpoint(..)
    , Latitude(..)
    , Longitude(..)
    )

turnpoint :: Turnpoint -> IO (L.Marker, L.Circle)
turnpoint (Turnpoint _ (Latitude lat) (Longitude lng) radius) = do
    xMark <- L.marker latLng
    xCyl <- L.circle latLng $ fromInteger radius
    return (xMark, xCyl)
    where
        latLng = (fromRational lat, fromRational lng)

toLatLng :: Turnpoint -> (Double, Double)
toLatLng (Turnpoint _ (Latitude lat) (Longitude lng) _) =
    (fromRational lat, fromRational lng)

map :: MonadWidget t m => Task -> m ()

map (Task _ _ []) = do
    el "p" $ text "The task has no turnpoints."
    return ()

map (Task _ _ xs)= do
    let tpNames = fmap (\ (Turnpoint name _ _ _) -> name) xs
    postBuild <- delay 1 =<< getPostBuild
    (e, _) <- elAttr' "div" ("style" =: "height: 240px;width: 320px") $ return ()
    rec performEvent_ $ fmap
                            (\_ -> liftIO $ do
                                L.mapInvalidateSize lmap'
                                L.fitBounds lmap' bounds'
                                return ()
                            )
                            postBuild
        (lmap', bounds') <- liftIO $ do
            lmap <- L.map (_element_raw e)
            L.mapSetView lmap (toLatLng $ head xs) 11

            layer <-
                -- SEE: http://leaflet-extras.github.io/leaflet-providers/preview/
                L.tileLayer
                    "http://{s}.tile.opentopomap.org/{z}/{x}/{y}.png"
                    17

            L.tileLayerAddToMap layer lmap

            zs :: [(L.Marker, L.Circle)] <- sequence $ fmap turnpoint xs

            _ <- sequence $ fmap
                (\ (tpName, (xMark, xCyl)) -> do
                    L.markerAddToMap xMark lmap
                    L.markerPopup xMark tpName
                    L.circleAddToMap xCyl lmap
                    return ())
                (zip tpNames zs)

            let pts :: [(Double, Double)] = fmap toLatLng xs

            courseLine <- L.polyline pts
            L.polylineAddToMap courseLine lmap

            bounds <- L.polylineBounds courseLine

            return (lmap, bounds)

    return ()
