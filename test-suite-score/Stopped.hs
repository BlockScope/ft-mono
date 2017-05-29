{-# LANGUAGE GADTs #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE StandaloneDeriving #-}
module Stopped
    ( stoppedTimeUnits
    , stoppedScoreUnits
    , stoppedValidityUnits
    , scoreTimeWindowUnits
    ) where

import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit as HU ((@?=), testCase)
import Data.Ratio((%))

import qualified Flight.Score as FS
import Flight.Score
    ( StopTime(..)
    , ScoreBackTime(..)
    , AnnouncedTime(..)
    , StartGateInterval(..)
    , TaskTime(..)
    , TaskStopTime(..)
    , CanScoreStopped(..)
    , NumberInGoalAtStop(..)
    , PilotsLaunched(..)
    , PilotsLandedBeforeStop(..)
    , DistanceLaunchToEss(..)
    , DistanceFlown(..)
    , StoppedValidity(..)
    , TaskType(..)
    , StartGates(..)
    , ScoreTimeWindow(..)
    )

stoppedTimeUnits :: TestTree
stoppedTimeUnits = testGroup "Effective task stop time"
    [ HU.testCase "Announced stop time minus score back time, Pg = task stop time" $
        FS.stopTaskTime (ScoreBackStop (ScoreBackTime 1) (AnnouncedTime 3)) @?= TaskStopTime 2

    , HU.testCase "Announced stop time minus time between start gates, Hg = task stop time" $
        FS.stopTaskTime (InterGateStop (StartGateInterval 1) (AnnouncedTime 3)) @?= TaskStopTime 2

    , HU.testCase "Announced stop time with a single start gate, Hg = task stop time is 15 min earlier" $
        FS.stopTaskTime (SingleGateStop (AnnouncedTime (17 * 60))) @?= TaskStopTime (2 * 60)
    ]

stoppedScoreUnits :: TestTree
stoppedScoreUnits = testGroup "Can score a stopped task?"
    [ HU.testCase "Not when noone made goal and the task ran less than an hour, Hg womens" $
        FS.canScoreStopped(Womens (NumberInGoalAtStop 0) (TaskStopTime $ 59 * 60)) @?= False

    , HU.testCase "When someone made goal, Hg womens" $
        FS.canScoreStopped(Womens (NumberInGoalAtStop 1) (TaskStopTime 0)) @?= True

    , HU.testCase "When the task ran for 1 hr, Hg womans" $
        FS.canScoreStopped(Womens (NumberInGoalAtStop 0) (TaskStopTime $ 60 * 60)) @?= True

    , HU.testCase "Not when noone made goal and the task ran less than 90 mins, Hg" $
        FS.canScoreStopped(GoalOrDuration (NumberInGoalAtStop 0) (TaskStopTime $ 89 * 60)) @?= False
    , HU.testCase "When someone made goal, Hg" $
        FS.canScoreStopped(GoalOrDuration (NumberInGoalAtStop 1) (TaskStopTime 0)) @?= True

    , HU.testCase "When the task ran for 90 mins, Hg" $
        FS.canScoreStopped(GoalOrDuration (NumberInGoalAtStop 0) (TaskStopTime $ 90 * 60)) @?= True

    , HU.testCase "When the task ran for 1 hr, Pg" $
        FS.canScoreStopped(FromGetGo (TaskStopTime $ 60 * 60)) @?= True

    , HU.testCase "Not when there are no starters, Pg" $
        FS.canScoreStopped(FromLastStart [] (TaskStopTime $ 120 * 60)) @?= False

    , HU.testCase "Not when the last start was less than an hour before stop, Pg" $
        FS.canScoreStopped(FromLastStart [TaskTime 0] (TaskStopTime $ 59 * 60)) @?= False

    , HU.testCase "When the last start was an hour before stop, Pg" $
        FS.canScoreStopped(FromLastStart [TaskTime 0] (TaskStopTime $ 60 * 60)) @?= True
    ]

stoppedValidityUnits :: TestTree
stoppedValidityUnits = testGroup "Is a stopped task valid?"
    [ HU.testCase "Not when noone launches" $
        FS.stoppedValidity
            (PilotsLaunched 0)
            (PilotsLandedBeforeStop 0)
            (DistanceLaunchToEss 100)
            []
            @?= StoppedValidity 0

    , HU.testCase "When everyone makes ESS, one pilot launched and is still flying = 0 validity" $
        FS.stoppedValidity
            (PilotsLaunched 1)
            (PilotsLandedBeforeStop 0)
            (DistanceLaunchToEss 1)
            [DistanceFlown 1]
            @?= StoppedValidity 0

    , HU.testCase "When everyone makes ESS, one pilot launched and has landed = 1 validity" $
        FS.stoppedValidity
            (PilotsLaunched 1)
            (PilotsLandedBeforeStop 1)
            (DistanceLaunchToEss 1)
            [DistanceFlown 1]
            @?= StoppedValidity 1

    , HU.testCase "When everyone makes ESS, two pilots launched, both still flying = 0 validity" $
        FS.stoppedValidity
            (PilotsLaunched 2)
            (PilotsLandedBeforeStop 0)
            (DistanceLaunchToEss 1)
            [(DistanceFlown 1), (DistanceFlown 1)]
            @?= StoppedValidity 0

    , HU.testCase "When everyone makes ESS, two pilots launched, noone still flying = 1 validity" $
        FS.stoppedValidity
            (PilotsLaunched 2)
            (PilotsLandedBeforeStop 2)
            (DistanceLaunchToEss 1)
            [(DistanceFlown 1), (DistanceFlown 1)]
            @?= StoppedValidity 1

    , HU.testCase "When everyone makes ESS, two pilots launched, one still flying = 0.5 validity" $
        FS.stoppedValidity
            (PilotsLaunched 2)
            (PilotsLandedBeforeStop 1)
            (DistanceLaunchToEss 1)
            [(DistanceFlown 1), (DistanceFlown 1)]
            @?= StoppedValidity (4503599627370497 % 9007199254740992)

    , HU.testCase "When one makes ESS, one still flying at launch point = 0.93 validity" $
        FS.stoppedValidity
            (PilotsLaunched 2)
            (PilotsLandedBeforeStop 1)
            (DistanceLaunchToEss 1)
            [(DistanceFlown 1), (DistanceFlown 0)]
            @?= StoppedValidity (2102335339236503 % 2251799813685248)

    , HU.testCase "When one makes ESS, one still flying on course halfway to ESS = 0.93 validity" $
        FS.stoppedValidity
            (PilotsLaunched 2)
            (PilotsLandedBeforeStop 1)
            (DistanceLaunchToEss 2)
            [(DistanceFlown 2), (DistanceFlown 1)]
            @?= StoppedValidity (2102335339236503 % 2251799813685248)
    ]

scoreTimeWindowUnits :: TestTree
scoreTimeWindowUnits = testGroup "Score time window"
    [ testGroup "Race to goal"
        [ HU.testCase "1 start gate, noone launches = start to stop" $
            FS.scoreTimeWindow
                RaceToGoal
                (StartGates 1)
                (TaskStopTime 1)
                []
                @?= ScoreTimeWindow 1

        , HU.testCase "1 start gate, 1 launches at start = start to stop" $
            FS.scoreTimeWindow
                RaceToGoal
                (StartGates 1)
                (TaskStopTime 1)
                [TaskTime 0]
                @?= ScoreTimeWindow 1

        , HU.testCase "1 start gate, 1 launches at stop = start to stop" $
            FS.scoreTimeWindow
                RaceToGoal
                (StartGates 1)
                (TaskStopTime 1)
                [TaskTime 1]
                @?= ScoreTimeWindow 1

        , HU.testCase "2 start gates, noone launches = 0" $
            FS.scoreTimeWindow
                RaceToGoal
                (StartGates 2)
                (TaskStopTime 1)
                []
                @?= ScoreTimeWindow 0

        , HU.testCase "2 start gates, 1 launches at start = start to stop" $
            FS.scoreTimeWindow
                RaceToGoal
                (StartGates 2)
                (TaskStopTime 1)
                [TaskTime 0]
                @?= ScoreTimeWindow 1

        , HU.testCase "2 start gates, 1 launches at stop = 0" $
            FS.scoreTimeWindow
                RaceToGoal
                (StartGates 2)
                (TaskStopTime 1)
                [TaskTime 1]
                @?= ScoreTimeWindow 0
        ]
    , testGroup "Elapsed time"
        [ HU.testCase "1 start gate, noone launches = 0" $
            FS.scoreTimeWindow
                ElapsedTime
                (StartGates 1)
                (TaskStopTime 1)
                []
                @?= ScoreTimeWindow 0

        , HU.testCase "1 start gate, 1 launches at start = start to stop" $
            FS.scoreTimeWindow
                ElapsedTime
                (StartGates 1)
                (TaskStopTime 1)
                [TaskTime 0]
                @?= ScoreTimeWindow 1

        , HU.testCase "1 start gate, 1 launches at stop = 0" $
            FS.scoreTimeWindow
                ElapsedTime
                (StartGates 1)
                (TaskStopTime 1)
                [TaskTime 1]
                @?= ScoreTimeWindow 0

        , HU.testCase "2 start gates, noone launches = 0" $
            FS.scoreTimeWindow
                ElapsedTime
                (StartGates 2)
                (TaskStopTime 1)
                []
                @?= ScoreTimeWindow 0

        , HU.testCase "2 start gates, 1 launches at start = start to stop" $
            FS.scoreTimeWindow
                ElapsedTime
                (StartGates 2)
                (TaskStopTime 1)
                [TaskTime 0]
                @?= ScoreTimeWindow 1

        , HU.testCase "2 start gates, 1 launches at stop = 0" $
            FS.scoreTimeWindow
                ElapsedTime
                (StartGates 2)
                (TaskStopTime 1)
                [TaskTime 1]
                @?= ScoreTimeWindow 0
        ]
    ]
