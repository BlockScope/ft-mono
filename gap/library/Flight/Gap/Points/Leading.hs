{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TemplateHaskell #-}

module Flight.Gap.Points.Leading (LeadingPoints(..)) where

import Control.Newtype (Newtype(..))
import Data.Aeson.Via.Scientific (deriveDefDec, deriveViaSci)

newtype LeadingPoints = LeadingPoints Rational
    deriving (Eq, Ord, Show)

instance Newtype LeadingPoints Rational where
    pack = LeadingPoints
    unpack (LeadingPoints a) = a

deriveDefDec 0 ''LeadingPoints
deriveViaSci ''LeadingPoints
