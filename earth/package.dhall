./defaults.dhall //
{ name =
    "flight-earth"
, synopsis =
    "Distances on the WGS84 ellipsoid, the FAI sphere and the UTM projection."
, description =
    "Distances on the Earth for hang gliding and paragliding competitons."
, category =
    "Flight"
, github =
    "blockscope/flare-timing/earth"
, ghc-options =
    [ "-Wall", "-fplugin Data.UnitsOfMeasure.Plugin" ]
, library =
    { dependencies =
        [ "base >=4.5 && <5"
        , "numbers"
        , "fgl"
        , "uom-plugin"
        , "bifunctors"
        , "aeson"
        , "scientific"
        , "mtl"
        , "hcoord"
        , "hcoord-utm"
        , "aeson-via-sci"
        , "siggy-chardust"
        , "flight-units"
        , "flight-latlng"
        , "flight-zone"
        ]
    , source-dirs =
        "library"
    , exposed-modules =
        [ "Flight.Earth.Flat.Projected.Double"
        , "Flight.Earth.Flat.Projected.Rational"
        , "Flight.Earth.Flat.Separated"
        , "Flight.Earth.Flat"
        , "Flight.Earth.Sphere.Cylinder.Double"
        , "Flight.Earth.Sphere.Cylinder.Rational"
        , "Flight.Earth.Sphere.PointToPoint.Double"
        , "Flight.Earth.Sphere.PointToPoint.Rational"
        , "Flight.Earth.Sphere.Separated"
        , "Flight.Earth.Sphere"
        , "Flight.Earth.Ellipsoid.Cylinder.Double"
        , "Flight.Earth.Ellipsoid.Cylinder.Rational"
        , "Flight.Earth.Ellipsoid.PointToPoint.Double"
        , "Flight.Earth.Ellipsoid.PointToPoint.Rational"
        , "Flight.Earth.Ellipsoid.Separated"
        , "Flight.Earth.Ellipsoid"
        , "Flight.Earth.Geodesy"
        ]
    }
, tests =
    { hlint =
        { dependencies =
            [ "base"
            , "hlint"
            , "numbers"
            , "fgl"
            , "uom-plugin"
            , "bifunctors"
            , "aeson"
            , "scientific"
            , "mtl"
            , "hcoord"
            , "hcoord-utm"
            , "aeson-via-sci"
            , "siggy-chardust"
            , "tasty-compare"
            , "flight-units"
            , "flight-latlng"
            , "flight-zone"
            ]
        , ghc-options =
            [ "-rtsopts", "-threaded", "-with-rtsopts=-N" ]
        , main =
            "HLint.hs"
        , source-dirs =
            [ "library", "test-suite-hlint" ]
        }
    , earth =
        { dependencies =
            [ "base"
            , "hlint"
            , "numbers"
            , "fgl"
            , "uom-plugin"
            , "bifunctors"
            , "aeson"
            , "scientific"
            , "mtl"
            , "hcoord"
            , "aeson-via-sci"
            , "siggy-chardust"
            , "tasty"
            , "tasty-hunit"
            , "tasty-quickcheck"
            , "tasty-smallcheck"
            , "smallcheck"
            , "tasty-compare"
            , "flight-units"
            , "flight-latlng"
            , "flight-zone"
            ]
        , ghc-options =
            [ "-rtsopts", "-threaded", "-with-rtsopts=-N" ]
        , main =
            "Earth.hs"
        , source-dirs =
            [ "library", "test-suite-earth" ]
        }
    }
}
