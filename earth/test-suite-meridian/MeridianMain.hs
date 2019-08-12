import Test.Tasty (TestTree, testGroup, defaultMain)

import qualified Sphere.Meridian as S
import qualified Ellipsoid.Vincenty.Meridian as V

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
    testGroup "Earth tests (with doubles)"
        [ testGroup "Haversines Math" [S.units]
        , testGroup "Vincenty Math" [V.units]
        ]
