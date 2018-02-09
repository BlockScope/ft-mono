{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE QuasiQuotes #-}

module Flight.Ellipsoid.Cylinder.Double (circumSample) where

import Data.UnitsOfMeasure (u)
import Data.UnitsOfMeasure.Internal (Quantity(..))

import Flight.LatLng (LatLng(..))
import Flight.Zone
    ( Zone(..)
    , Radius(..)
    , Bearing(..)
    , center
    , radius
    , realToFracZone
    )
import Flight.Zone.Path (distancePointToPoint)
import Flight.Ellipsoid.PointToPoint.Double (distanceVincenty)
import Flight.Distance (TaskDistance(..), PathDistance(..))
import Flight.Zone.Cylinder
    ( TrueCourse(..)
    , ZonePoint(..)
    , Tolerance(..)
    , Samples(..)
    , SampleParams(..)
    , CircumSample
    , orbit
    , radial
    , point
    , sourceZone
    )
import Flight.Ellipsoid (wgs84)

directVincenty
    :: Real a
    => LatLng a [u| rad |]
    -> Radius a [u| m |]
    -> TrueCourse a
    -> LatLng Double [u| rad |]
directVincenty = undefined

-- | Using a method from the
-- <http://www.edwilliams.org/avform.htm#LL Aviation Formulary>
-- a point on a cylinder wall is found by going out to the distance of the
-- radius on the given radial true course 'rtc'.
circum :: Real a
       => LatLng a [u| rad |]
       -> Radius a [u| m |]
       -> TrueCourse a
       -> LatLng Double [u| rad |]
circum = directVincenty

-- | Generates a pair of lists, the lat/lng of each generated point
-- and its distance from the center. It will generate 'samples' number of such
-- points that should lie close to the circle. The difference between
-- the distance to the origin and the radius should be less han the 'tolerance'.
--
-- The points of the compass are divided by the number of samples requested.
circumSample :: CircumSample Double
circumSample SampleParams{..} (Bearing (MkQuantity bearing)) zp zone =
    ys
    where
        nNum = unSamples spSamples
        half = nNum `div` 2
        halfRange = pi / bearing

        zone' :: Zone Double
        zone' =
            case zp of
              Nothing -> zone
              Just ZonePoint{..} -> sourceZone

        xs :: [TrueCourse Double]
        xs =
            TrueCourse . MkQuantity <$>
            case zp of
                Nothing ->
                    [ 2.0 * fromInteger n / fromInteger nNum * pi
                    | n <- [0 .. nNum]
                    ]

                Just ZonePoint{..} ->
                    [b]
                    ++ 
                    [ b - fromInteger n / fromInteger half * halfRange
                    | n <- [1 .. half]
                    ]
                    ++
                    [ b + fromInteger n / fromInteger half * halfRange
                    | n <- [1 .. half]
                    ]
                    where
                        (Bearing (MkQuantity b)) = radial

        r :: Radius Double [u| m |]
        r@(Radius (MkQuantity limitRadius)) = radius zone'

        ptCenter = center zone'
        circumR = circum ptCenter

        getClose' = getClose zone' ptCenter limitRadius spTolerance

        ys :: ([ZonePoint Double], [TrueCourse Double])
        ys = unzip $ getClose' 10 (Radius (MkQuantity 0)) (circumR r) <$> xs

getClose :: Zone Double
         -> LatLng Double [u| rad |] -- ^ The center point.
         -> Double -- ^ The limit radius.
         -> Tolerance Double
         -> Int -- ^ How many tries.
         -> Radius Double [u| m |] -- ^ How far from the center.
         -> (TrueCourse Double -> LatLng Double [u| rad |]) -- ^ A point from the origin on this radial
         -> TrueCourse Double -- ^ The true course for this radial.
         -> (ZonePoint Double, TrueCourse Double)
getClose zone' ptCenter limitRadius spTolerance trys yr@(Radius (MkQuantity offset)) f x@(TrueCourse tc)
    | trys <= 0 = (zp', x)
    | unTolerance spTolerance <= 0 = (zp', x)
    | limitRadius <= unTolerance spTolerance = (zp', x)
    | otherwise =
        case d `compare` limitRadius of
             EQ ->
                 (zp', x)

             GT ->
                 let offset' =
                         offset - (d - limitRadius) * 105 / 100

                     f' =
                         circumR (Radius (MkQuantity $ limitRadius + offset'))

                 in
                     getClose
                         zone'
                         ptCenter
                         limitRadius
                         spTolerance
                         (trys - 1)
                         (Radius (MkQuantity offset'))
                         f'
                         x
                 
             LT ->
                 if d > (limitRadius - unTolerance spTolerance)
                 then (zp', x)
                 else
                     let offset' =
                             offset + (limitRadius - d) * 94 / 100

                         f' =
                             circumR (Radius (MkQuantity $ limitRadius + offset'))

                     in
                         getClose
                             zone'
                             ptCenter
                             limitRadius
                             spTolerance
                             (trys - 1)
                             (Radius (MkQuantity offset'))
                             f'
                             x
    where
        circumR = circum ptCenter

        y = f x
        zp' = ZonePoint { sourceZone = realToFracZone zone'
                        , point = y
                        , radial = Bearing tc
                        , orbit = yr
                        } :: ZonePoint Double
                       
        (TaskDistance (MkQuantity d)) =
            edgesSum
            $ distancePointToPoint
                (distanceVincenty wgs84)
                (realToFracZone <$> [Point ptCenter, Point y])
