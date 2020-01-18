# Flare Timing

**Flare Timing** is a reference implementation of [GAP](lang-haskell/GAP.md)
scoring for cross country hang gliding and paragliding racing.

Its command line console apps, one for each step in scoring, write down their
workings along with their outputs. With these workings we can trace how
a pilot's score has been calculated. There's no visual competition editor. The
one file that defines a competition can be generated from an FS database, the
`*.fsdb` file. It includes a web app that can be hosted locally for visual
checks and comparisons with expected or official results. It is possible to
publish the data alongside this web app standalone as done at [flaretiming, the
web site](https://flaretiming.com).

## Installation

Download the source, build and install with [stack](https://docs.haskellstack.org):

```
> git clone https://github.com/BlockScope/flare-timing.git --recursive
> cd flare-timing/lang-haskell
> stack install
```

There's more in the [building](lang-haskell/BUILDING.md) guide. There's a guide for
[testing](lang-haskell/TESTING.md) too.

## Usage

Let's get the inputs and outputs from FS, do the scoring and host the comp
locally.

Start by preparing the FS comp file, the `*.fsdb`. This will often contain
sensitive personal information such as birthdays, phone numbers and notes that
we'll want to avoid publishing. We'll also want some output data for making
comparisons between flare-timing and FS.

1. Clean out the sensitive stuff and trim away data we don't need with
[`fs-filter`](lang-haskell/flare-timing/prod-apps/fs-filter).  
2. Grab the optimal route around the tasks found by FS with
[`fs-route`](lang-haskell/flare-timing/prod-apps/fs-route).  
3. Grab the arrival times and positions from FS with
[`fs-arrival`](lang-haskell/flare-timing/prod-apps/fs-arrival).  
4. Grab the landouts from FS with
[`fs-effort`](lang-haskell/flare-timing/prod-apps/fs-effort).  
5. Grab the scores from FS with
[`fs-score`](lang-haskell/flare-timing/prod-apps/fs-score).  

That's the `*.fsdb` file done with. From here on, flare-timing deals with the
trimmed XML, the `*.trim-fsdb.xml`. If we have the track logs we can score the
tasks:

1. Extract the inputs with
[`extract-input`](lang-haskell/flare-timing/prod-apps/extract-input).  
2. Trace the shortest path to fly a task with
[`task-length`](lang-haskell/flare-timing/prod-apps/task-length).  
3. Find pairs of fixes crossing over zones with
[`cross-zone`](lang-haskell/flare-timing/prod-apps/cross-zone).  
4. Interpolate between crossing fixes for the time and place where a track tags
a zone with [`tag-zone`](lang-haskell/flare-timing/prod-apps/tag-zone).  
5. Unpack the `*.igc` or `*.kml` tracklogs with
[`unpack-track`](lang-haskell/flare-timing/prod-apps/unpack-track).  
6. Peg the timing window to a reference frame with
[`peg-frame`](lang-haskell/flare-timing/prod-apps/peg-frame).  
7. Index fixes from the time of first crossing with
[`align-time`](lang-haskell/flare-timing/prod-apps/align-time).  
8. Discard fixes that get further from goal and note leading area with
[`discard-further`](lang-haskell/flare-timing/prod-apps/discard-further).  
9. Mask a task over its tracklogs with
[`mask-track`](lang-haskell/flare-timing/prod-apps/mask-track).  
10. Group and count land outs with
[`land-out`](lang-haskell/flare-timing/prod-apps/land-out).  
11. Score the competition with [`gap-point`](lang-haskell/flare-timing/prod-apps/gap-point).  

To get the backend server for hosting the comp data running locally:

Start the server with
[`comp-serve`](lang-haskell/app-serve).  

To host the frontend web app for the comp locally:

1. Change directory:
    `> cd lang-haskell`
2. Open a try-reflex shell with:
    `> reflex-platform/try-reflex`
3. Build the frontend and start its webpack dev server with:
    `> ./stack-shake-build.sh view-start-ghcjs`
4. Open a browser at the hosted URL, usually http://localhost:9000/app.html.

Documentation is available online at
[flare-timing.readthedocs.io](http://flare-timing.readthedocs.io/) and there's
a [worked example](lang-haskell/EXAMPLE.md) too.

## What's Included

The GAP rules have changed over the years. Here are the features that
flare-timing includes or not.

* Scoring Method
    - [x] GAP
    - [ ] Linear distance
    - [ ] Time-based scoring (TBS)
* Earth Model
    - [x] FAI sphere
    - [x] WGS84 ellipsoid
* Distance Method
    - [x] Pythagorus on a UTM plane
    - [x] Haversines on the sphere
    - [x] Vincenty on the ellipsoid
    - [ ] Andoyer on the ellipsoid
* Type of Task
    - [x] Race
    - [x] Elapsed time
    - [ ] Open distance (can be declared but not yet scored)
* Shape of Zone
    - [x] Cylinder
    - [ ] Inverted cone (can be defined but treated as a cylinder)
* Shape of Goal
    - [x] Circle
    - [x] Line
* Final Glide Decelerator
    - [ ] Conical end of speed section (CESS)
    - [ ] Arrival altitude time bonus (AATB)
* Source of Altitude
    - [x] GPS
    - [ ] Pressure (QNH)
* Validities
    - [x] Task (day quality)
    - [x] Launch
    - [x] Distance
    - [x] Time
    - [x] Stop
* Points
    - [x] Linear distance (reach)
    - [x] Distance difficulty (effort)
    - [x] Arrival position
    - [x] Arrival time
    - [x] Time (speed)
    - [x] Leading
    - [ ] Departure
* Parameter Tweaks
    - [ ] Day quality override
    - [ ] 1000 points for winner if no pilot made goal
    - [ ] 1000 points for winner before day quality applied
    - [ ] Use distance squared for leading coefficient
    - [x] Double leading points weight
    - [ ] Proportional leading points weight if no pilot made goal
    - [ ] Adjustable stopped task bonus glide ratio (fixed at 4:1 for PG and 5:1 for HG)
    - [x] Jump-the-gun factor
    - [x] Jump-the-gun maximum
* Special Cases
    - [ ] End of the speed section but not goal
    - [x] Early start
    - [x] Stopped tasks
* Stopped Tasks
    - [x] Stopped task time as announcement minus score back
    - [ ] Requirements checking, goal or duration
    - [ ] Score time window
    - [ ] Time points for pilots at or after the end of the speed section
    - [x] Distance points with altitude bonus
* Penalties
    - [x] Absolute
    - [x] Fractional
* Task Ranking
    - [x] Overall
    - [ ] Female
    - [ ] Country
* Competition Ranking
    - [ ] Overall
    - [ ] Female
    - [ ] Country
    - [ ] Ties
    - [ ] Fixed Total Validity

## License

```
Copyright © Phil de Joux 2017-2019
Copyright © Block Scope Limited 2017-2019
```

This software is subject to the terms of the Mozilla Public License, v2.0. If
a copy of the MPL was not distributed with this file, you can obtain one at
http://mozilla.org/MPL/2.0/.
