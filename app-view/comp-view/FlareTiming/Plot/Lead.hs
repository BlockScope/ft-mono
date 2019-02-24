module FlareTiming.Plot.Lead (leadPlot) where

import Data.Maybe (fromMaybe)
import Reflex.Dom

import WireTypes.Lead (TrackLead(..))
import WireTypes.Comp (Discipline(..))
import FlareTiming.Plot.Lead.View as A (hgPlot)
import WireTypes.Pilot (Pilot(..))

leadPlot
    :: MonadWidget t m
    => Dynamic t Discipline
    -> Dynamic t (Maybe [(Pilot, TrackLead)])
    -> m ()
leadPlot hgOrPg ld = do
    elClass "div" "tile is-ancestor" $ do
        _ <- dyn $ ffor hgOrPg (\hgOrPg' ->
            if hgOrPg' /= HangGliding then return () else
                elClass "div" "tile is-12" $
                    elClass "div" "tile" $
                        elClass "div" "tile is-parent" $ do
                            _ <- dyn $ ffor ld (\case
                                    Nothing ->
                                        elClass "article" "tile is-child box" $ do
                                            elClass "p" "title" $ text "Leading"
                                            el "p" $ text "Loading arrivals ..."

                                    Just [] ->
                                        elClass "article" "tile is-child notification is-warning" $ do
                                            elClass "p" "title" $ text "Leading"
                                            el "p" $ text "No pilots made it to the end of the speed section. There are no arrivals"

                                    _ ->
                                        elClass "article" "tile is-child box" $
                                            A.hgPlot (fromMaybe [] <$> ld))

                            return ())

        return ()
