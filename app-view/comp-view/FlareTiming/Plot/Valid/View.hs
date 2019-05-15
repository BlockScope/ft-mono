module FlareTiming.Plot.Valid.View
    ( launchValidityPlot
    , timeValidityPlot
    , reachValidityPlot
    ) where

import Reflex.Dom
import Reflex.Time (delay)

import Control.Monad.IO.Class (liftIO)
import WireTypes.Validity (Validity(..))
import WireTypes.ValidityWorking (ValidityWorking(..))
import qualified FlareTiming.Plot.Valid.Plot as P (launchPlot, timePlot, reachPlot)

launchValidityPlot
    :: MonadWidget t m
    => Validity
    -> ValidityWorking
    -> m ()
launchValidityPlot Validity{launch = vy} ValidityWorking{launch = vw} = do
    pb <- delay 1 =<< getPostBuild

    elClass "div" "tile is-ancestor" $ do
        elClass "div" "tile" $
            elClass "div" "tile is-parent" $
                elClass "div" "tile is-child" $ do
                    (elPlot, _) <- elAttr' "div" (("id" =: "hg-plot-valid-launch") <> ("style" =: "height: 360px;width: 360px")) $ return ()
                    rec performEvent_ $ leftmost
                            [ ffor pb (\_ -> liftIO $ do
                                _ <- P.launchPlot (_element_raw elPlot) vy vw
                                return ())
                            ]

                    return ()

    return ()

timeValidityPlot
    :: MonadWidget t m
    => Validity
    -> ValidityWorking
    -> m ()
timeValidityPlot Validity{time = vy} ValidityWorking{time = vw} = do
    pb <- delay 1 =<< getPostBuild

    elClass "div" "tile is-ancestor" $ do
        elClass "div" "tile" $
            elClass "div" "tile is-parent" $
                elClass "div" "tile is-child" $ do
                    (elPlot, _) <- elAttr' "div" (("id" =: "hg-plot-valid-time") <> ("style" =: "height: 360px;width: 360px")) $ return ()
                    rec performEvent_ $ leftmost
                            [ ffor pb (\_ -> liftIO $ do
                                _ <- P.timePlot (_element_raw elPlot) vy vw
                                return ())
                            ]

                    return ()

    return ()

reachValidityPlot
    :: MonadWidget t m
    => Validity
    -> ValidityWorking
    -> m ()
reachValidityPlot Validity{distance = vy} ValidityWorking{distance = vw} = do
    pb <- delay 1 =<< getPostBuild

    elClass "div" "tile is-ancestor" $ do
        elClass "div" "tile" $
            elClass "div" "tile is-parent" $
                elClass "div" "tile is-child" $ do
                    (elPlot, _) <- elAttr' "div" (("id" =: "hg-plot-valid-reach") <> ("style" =: "height: 360px;width: 360px")) $ return ()
                    rec performEvent_ $ leftmost
                            [ ffor pb (\_ -> liftIO $ do
                                _ <- P.reachPlot (_element_raw elPlot) vy vw
                                return ())
                            ]

                    return ()

    return ()
