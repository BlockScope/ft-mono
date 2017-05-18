module Main (main) where

import qualified Flight.Score as FS
import Flight.Score (NominalTime, NominalDistance, Seconds, Metres)

import Test.Tasty (TestTree, testGroup, defaultMain)
import Test.Tasty.SmallCheck as SC
import Test.SmallCheck.Series as SC
import Test.Tasty.QuickCheck as QC
import Test.Tasty.HUnit as HU ((@?=), testCase)
import Data.Ratio ((%))


main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "Tests" [properties, units]

properties :: TestTree
properties = testGroup "Properties" [scProps, qcProps]

units :: TestTree
units = testGroup "Units" [validityUnits]

validityUnits :: TestTree
validityUnits = testGroup "Validities" [launchValidityUnits, timeValidityUnits]

scProps :: TestTree
scProps = testGroup "(checked by SmallCheck)"
    [ SC.testProperty "Launch validity is in the range of [0, 1]" scLaunchValidity

    -- WARNING: Failing test.
    -- there exist 0 1 Nothing -1 such that
    --  condition is false
    , SC.testProperty "Time validity is in the range of [0, 1]" timeValidity
    ]

qcProps :: TestTree
qcProps = testGroup "(checked by QuickCheck)"
    [ QC.testProperty "Launch validity is in the range of [0, 1]" qcLaunchValidity

    -- WARNING: Failing test.
    -- *** Failed! Falsifiable (after 5 tests and 4 shrinks):
    -- 0
    -- 1
    -- Nothing
    -- -1
    -- Use --quickcheck-replay '4 TFGenR 0000000C08AF40A300000000000F4240000000000000E223000001FD51291300 0 62 6 0' to reproduce.
    , QC.testProperty "Time validity is in the range of [0, 1]" timeValidity
    ]

launchValidityUnits :: TestTree
launchValidityUnits = testGroup "Launch validity unit tests"
    [ HU.testCase "Launch validity 0 0 == 0, (nominal actual)" $
        FS.launchValidity (0 % 1) (0 % 1) @?= (0 % 1)

    , HU.testCase "Launch validity 1 0 == 0, (nominal actual)" $
        FS.launchValidity (1 % 1) (0 % 1) @?= (0 % 1)

    , HU.testCase "Launch validity 0 1 == 1, (nominal actual)" $
        FS.launchValidity (0 % 1) (1 % 1) @?= (1 % 1)

    , HU.testCase "Launch validity 1 1 == 1, (nominal actual)" $
        FS.launchValidity (1 % 1) (1 % 1) @?= (1 % 1)
    ]

timeValidityUnits :: TestTree
timeValidityUnits = testGroup "Time validity unit tests"
    [ HU.testCase "time validity 0 0 (Just 0) 0 == 0" $
        FS.timeValidity 0 0 (Just 0) 0 @?= (0 % 1)

    , HU.testCase "time validity 1 0 (Just 1) 0 == 1" $
        FS.timeValidity 1 0 (Just 1) 0 @?= (1 % 1)

    , HU.testCase "time validity 1 1 (Just 1) 1 == 1" $
        FS.timeValidity 1 1 (Just 1) 1 @?= (1 % 1)

    , HU.testCase "time validity 0 0 Nothing 0 == 0" $
        FS.timeValidity 0 0 Nothing 0 @?= (0 % 1)

    , HU.testCase "time validity 0 1 Nothing 1 == 1" $
        FS.timeValidity 0 1 Nothing 1 @?= (1 % 1)

    , HU.testCase "time validity 1 1 Nothing 1 == 1" $
        FS.timeValidity 1 1 Nothing 1 @?= (1 % 1)
    ]

launchValidity :: Integer -> Integer -> Integer -> Integer -> Bool
launchValidity nx dx ny dy =
    let nominalLaunch = nx % dx
        fractionLaunching = ny % dy
        lv = FS.launchValidity nominalLaunch fractionLaunching
    in lv >= (0 % 1) && lv <= (1 % 1)

scLaunchValidity
    :: Monad m => SC.NonNegative Integer
    -> SC.Positive Integer
    -> SC.NonNegative Integer
    -> SC.Positive Integer
    -> SC.Property m
scLaunchValidity
    (SC.NonNegative nx)
    (SC.Positive dx)
    (SC.NonNegative ny)
    (SC.Positive dy) =
    nx <= dx && ny <= dy SC.==> launchValidity nx dx ny dy

qcLaunchValidity
    :: QC.NonNegative Integer
    -> QC.Positive Integer
    -> QC.NonNegative Integer
    -> QC.Positive Integer
    -> QC.Property
qcLaunchValidity
    (QC.NonNegative nx)
    (QC.Positive dx)
    (QC.NonNegative ny)
    (QC.Positive dy) =
    nx <= dx && ny <= dy QC.==> launchValidity nx dx ny dy

timeValidity :: NominalTime -> NominalDistance -> Maybe Seconds -> Metres -> Bool
timeValidity nt nd t d =
    let tv = FS.timeValidity nt nd t d
    in tv >= (0 % 1) && tv <= (1 % 1)
