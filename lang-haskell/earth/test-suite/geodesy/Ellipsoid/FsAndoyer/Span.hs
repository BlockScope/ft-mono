module Ellipsoid.FsAndoyer.Span (spanD, spanR, azFwdD, azRevD, sepD, sepR) where

import Data.Ratio ((%))

import Flight.Distance (SpanLatLng)
import Flight.LatLng (AzimuthFwd, AzimuthRev)
import Flight.LatLng.Rational (Epsilon(..))
import Flight.Zone (Zone(..))
import Flight.Earth.Ellipsoid (Ellipsoid)
import Flight.Geodesy (EarthModel(..), EarthMath(FsAndoyer))
import Flight.Geodesy.Solution (GeodesySolutions(..), GeoZones(..))
import Flight.Geodesy.Double ()
import Flight.Geodesy.Rational ()

eps :: Epsilon
eps = Epsilon $ 1 % 1000000000000000000

spanD :: Ellipsoid Double -> SpanLatLng Double
spanD e = arcLength @Double @Double (FsAndoyer, EarthAsEllipsoid e)

spanR :: Ellipsoid Rational -> SpanLatLng Rational
spanR e = arcLength @Rational @Rational (FsAndoyer, EarthAsEllipsoid e, eps)

azFwdD :: Ellipsoid Double -> AzimuthFwd Double
azFwdD e = azimuthFwd @Double @Double (FsAndoyer, EarthAsEllipsoid e)

azRevD :: Ellipsoid Double -> AzimuthRev Double
azRevD e = azimuthRev @Double @Double (FsAndoyer, EarthAsEllipsoid e)

sepD :: Ellipsoid Double -> [Zone Double] -> Bool
sepD e = separatedZones @Double @Double (FsAndoyer, EarthAsEllipsoid e)

sepR :: Ellipsoid Rational -> [Zone Rational] -> Bool
sepR e = separatedZones @Rational @Rational (FsAndoyer, EarthAsEllipsoid e, eps)
