{-# OPTIONS_GHC -fno-warn-partial-type-signatures #-}

module Sphere.Published (units, unitsR) where

import Test.Tasty (TestTree, testGroup)
import Data.UnitsOfMeasure (u, convert)
import Data.UnitsOfMeasure.Internal (Quantity(..))

import Flight.Units ()
import Flight.Units.DegMinSec (DMS(..))
import qualified Published.GeoscienceAustralia as G
    ( directProblems, directSolutions
    , inverseProblems, inverseSolutions
    )
import qualified Published.Vincenty as V
    ( directProblems, directSolutions
    , inverseProblems, inverseSolutions
    )
import qualified Published.Bedford as B
    ( directProblems, directSolutions
    , inverseProblems, inverseSolutions
    )
import Tolerance (GetTolerance, AzTolerance)
import qualified Tolerance as T
    ( dblDirectChecks, ratDirectChecks
    , dblInverseChecks, ratInverseChecks
    )
import Flight.Geodesy (DProb, DSoln, IProb, ISoln)
import Sphere.Span (spanD, spanR, azFwdD, azRevD)

units :: TestTree
units =
    testGroup "With published data sets"
    [ geoSciAuUnits
    , vincentyUnits
    , bedfordUnits
    ]

unitsR :: TestTree
unitsR =
    testGroup "With published data sets"
    [ geoSciAuUnitsR
    , vincentyUnitsR
    , bedfordUnitsR
    ]

defaultAzTolerance :: AzTolerance
defaultAzTolerance = DMS (0, 0, 0.001)

geoSciAuAzTolerance :: AzTolerance
geoSciAuAzTolerance = defaultAzTolerance

vincentyAzTolerance :: AzTolerance
vincentyAzTolerance = defaultAzTolerance

bedfordAzTolerance :: AzTolerance
bedfordAzTolerance = defaultAzTolerance

geoSciAuTolerance :: Fractional a => GetTolerance a
geoSciAuTolerance = const . convert $ [u| 47 m |]

vincentyTolerance
    :: (Real a, Fractional a)
    => Quantity a [u| m |]
    -> Quantity a [u| km |]
vincentyTolerance d'
    | d < [u| 5000 km |] = convert [u| 6.7 km |]
    | d < [u| 10000 km |] = convert [u| 21 km |]
    | otherwise = convert [u| 24 km |]
    where
        d = convert d'

bedfordTolerance
    :: (Real a, Fractional a)
    => Quantity a [u| m |]
    -> Quantity a [u| km |]
bedfordTolerance d'
    | d < [u| 100 km |] = convert [u| 440 m |]
    | d < [u| 1000 km |] = convert [u| 4.2 km |]
    | otherwise = convert [u| 20 km |]
    where
        d = convert d'

dblDirectChecks
    :: GetTolerance Double
    -> [DSoln]
    -> [DProb]
    -> [TestTree]
dblDirectChecks tolerance =
    T.dblDirectChecks tolerance (repeat spanD)

ratDirectChecks
    :: GetTolerance Rational
    -> [DSoln]
    -> [DProb]
    -> [TestTree]
ratDirectChecks tolerance =
    T.ratDirectChecks tolerance (repeat spanR)

dblInverseChecks
    :: GetTolerance Double
    -> AzTolerance
    -> [ISoln]
    -> [IProb]
    -> [TestTree]
dblInverseChecks tolerance azTolerance =
    T.dblInverseChecks
        tolerance
        azTolerance
        (repeat spanD)
        (repeat azFwdD)
        (repeat azRevD)

ratInverseChecks
    :: GetTolerance Rational
    -> AzTolerance
    -> [ISoln]
    -> [IProb]
    -> [TestTree]
ratInverseChecks tolerance azTolerance =
    T.ratInverseChecks tolerance azTolerance (repeat spanR)

geoSciAuUnits :: TestTree
geoSciAuUnits =
    testGroup "Geoscience Australia distances between Flinders Peak and Buninyong"
    [ testGroup "Inverse Problem of Geodesy"
        [ testGroup "with doubles"
            $ dblInverseChecks
                geoSciAuTolerance
                geoSciAuAzTolerance
                G.inverseSolutions
                G.inverseProblems
        ]

    , testGroup "Direct Problem of Geodesy"
        [ testGroup "with doubles"
            $ dblDirectChecks
                geoSciAuTolerance
                G.directSolutions
                G.directProblems
        ]
    ]

geoSciAuUnitsR :: TestTree
geoSciAuUnitsR =
    testGroup "Geoscience Australia distances between Flinders Peak and Buninyong"
    [ testGroup "Inverse Problem of Geodesy"
        [ testGroup "with rationals"
            $ ratInverseChecks
                geoSciAuTolerance
                geoSciAuAzTolerance
                G.inverseSolutions
                G.inverseProblems
        ]

    , testGroup "Direct Problem of Geodesy"
        [ testGroup "with rationals"
            $ ratDirectChecks
                geoSciAuTolerance
                G.directSolutions
                G.directProblems
        ]
    ]

vincentyUnits :: TestTree
vincentyUnits =
    testGroup "Vincenty's distances, from Rainsford 1955"
    [ testGroup "Inverse Problem of Geodesy"
        [ testGroup "with doubles"
            $ dblInverseChecks
                vincentyTolerance
                vincentyAzTolerance
                V.inverseSolutions
                V.inverseProblems
        ]

    , testGroup "Direct Problem of Geodesy"
        [ testGroup "with doubles"
            $ dblDirectChecks
                vincentyTolerance
                V.directSolutions
                V.directProblems
        ]
    ]

vincentyUnitsR :: TestTree
vincentyUnitsR =
    testGroup "Vincenty's distances, from Rainsford 1955"
    [ testGroup "Inverse Problem of Geodesy"
        [ testGroup "with rationals"
            $ ratInverseChecks
                vincentyTolerance
                vincentyAzTolerance
                V.inverseSolutions
                V.inverseProblems
        ]

    , testGroup "Direct Problem of Geodesy"
        [ testGroup "with rationals"
            $ ratDirectChecks
                vincentyTolerance
                V.directSolutions
                V.directProblems
        ]
    ]

bedfordUnits :: TestTree
bedfordUnits =
    testGroup "Bedford Institute of Oceanography distances"
    [ testGroup "Inverse Problem of Geodesy"
        [ testGroup "with doubles"
            $ dblInverseChecks
                bedfordTolerance
                bedfordAzTolerance
                B.inverseSolutions
                B.inverseProblems
        ]

    , testGroup "Direct Problem of Geodesy"
        [ testGroup "with doubles"
            $ dblDirectChecks
                bedfordTolerance
                B.directSolutions
                B.directProblems
        ]
    ]

bedfordUnitsR :: TestTree
bedfordUnitsR =
    testGroup "Bedford Institute of Oceanography distances"
    [ testGroup "Inverse Problem of Geodesy"
        [ testGroup "with rationals"
            $ ratInverseChecks
                bedfordTolerance
                bedfordAzTolerance
                B.inverseSolutions
                B.inverseProblems
        ]

    , testGroup "Direct Problem of Geodesy"
        [ testGroup "with rationals"
            $ ratDirectChecks
                bedfordTolerance
                B.directSolutions
                B.directProblems
        ]
    ]