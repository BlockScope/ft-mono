{-|
Module: Flight.Igc
Copyright:
    © 2018 Phil de Joux
    © 2018 Block Scope Limited
License: MPL-2.0
Maintainer: Phil de Joux <phil.dejoux@blockscope.com>
Stability: experimental

Provides parsing the IGC format for waypoint fixes. The date header is also parsed
as it is needed for the fixes that have only a time and pickup the date in the file
header.
-}
module Flight.Igc
    (
    -- * Data
      IgcRecord(..)
    , HMS(..)
    , Lat(..)
    , Lng(..)
    , AltBaro(..)
    , AltGps(..)
    -- * Parsing
    , parse
    , parseFromFile
    -- * Types
    , Altitude(..)
    , Degree(..)
    , Hour(..)
    , Minute(..)
    , Second(..)
    , Year(..)
    , Month(..)
    , Day(..)
    , Nth(..)
    , addHoursIgc
    -- * Record classification
    , isMark
    , isFix
    ) where

import Flight.Igc.Record
import Flight.Igc.Parse
