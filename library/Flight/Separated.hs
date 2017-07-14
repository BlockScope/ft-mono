module Flight.Separated (separatedZones) where

import Flight.Zone (Zone(..), Radius(..), radius)
import Flight.PointToPoint (TaskDistance(..), distancePointToPoint)

separated :: Zone -> Zone -> Bool

separated x@(Point _) y@(Point _) =
    x /= y

separated x@(Point _) y =
    d > ry
    where
        (Radius ry) = radius y
        (TaskDistance d) = distancePointToPoint [x, y]

separated x y@(Point _) =
    d > rx
    where
        (Radius rx) = radius x
        (TaskDistance d) = distancePointToPoint [x, y]

-- | Consider cylinders separated if one fits inside the other or if they don't
-- touch.
separated xc@(Cylinder (Radius xR) x) yc@(Cylinder (Radius yR) y)
    | x == y = xR /= yR
    | dxy + minR < maxR = True
    | otherwise = clearlySeparated xc yc
    where
        (TaskDistance dxy) = distancePointToPoint [Point x, Point y]
        minR = max xR yR
        maxR = min xR yR

separated x y =
    clearlySeparated x y

-- | Are the control zones separated? This a prerequisite to being able to work
-- out the distance between zones. The one exception is coincident cylinders
-- with different radii. Here the difference in radii is considered to be the
-- distance between them. This will be seen where the smaller concentric cylinder
-- marks the launch and the larger one, as an exit cylinder, marks the start of the
-- speed section.
separatedZones :: [Zone] -> Bool
separatedZones xs =
    and $ zipWith separated xs (tail xs)

clearlySeparated :: Zone -> Zone -> Bool
clearlySeparated x y =
    d > rxy
    where
        (Radius rx) = radius x
        (Radius ry) = radius y
        rxy = rx + ry
        (TaskDistance d) = distancePointToPoint [x, y]
