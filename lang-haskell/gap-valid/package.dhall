    let defs = ./../defaults.dhall

in  let testdeps =
          [ "base"
          , "containers"
          , "vector"
          , "statistics"
          , "aeson"
          , "newtype"
          , "scientific"
          , "uom-plugin"
          , "detour-via-sci"
          , "detour-via-uom"
          , "siggy-chardust"
          , "flight-units"
          , "tasty"
          , "tasty-hunit"
          , "tasty-quickcheck"
          , "tasty-smallcheck"
          , "smallcheck"
          , "QuickCheck"
          , "quickcheck-instances"
          ]

in  let testopts =
          [ "-rtsopts"
          , "-threaded"
          , "-with-rtsopts=-N"
          , "-fplugin Data.UnitsOfMeasure.Plugin"
          ]

in    defs
    ⫽ ./../default-extensions.dhall
    ⫽ { flags =
          { suppress-failing-tests = { manual = False, default = True } }
      , name =
          "flight-gap-valid"
      , synopsis =
          "GAP Scoring Validities"
      , description =
          "GAP scoring for hang gliding and paragliding competitons, the validity parts."
      , category =
          "Flight"
      , github =
          "blockscope/flare-timing/lang-haskell/gap-validity"
      , ghc-options =
          [ "-Wall"
          , "-fplugin Data.UnitsOfMeasure.Plugin"
          , "-fno-warn-partial-type-signatures"
          ]
      , dependencies =
            defs.dependencies
          # [ "aeson"
            , "cassava"
            , "containers"
            , "newtype"
            , "numbers"
            , "QuickCheck"
            , "scientific"
            , "template-haskell"
            , "text"
            , "uom-plugin"
            , "detour-via-sci"
            , "detour-via-uom"
            , "siggy-chardust"
            , "flight-units"
            , "flight-gap-base"
            ]
      , library =
          { source-dirs = "library", exposed-modules = [ "Flight.Score" ] }
      , tests =
            ./../default-tests.dhall
          ⫽ { valid =
                { dependencies =
                    testdeps # [ "flight-gap-valid" ]
                , ghc-options =
                    testopts
                , main =
                    "ValidityTestMain.hs"
                , source-dirs =
                    [ "test-suite/test", "test-suite/validity" ]
                }
            , doctest =
                { dependencies =
                      defs.dependencies
                    # [ "quickcheck-classes"
                      , "numbers"
                      , "doctest"
                      , "facts"
                      , "flight-units"
                      ]
                , ghc-options =
                    [ "-rtsopts", "-threaded", "-with-rtsopts=-N" ]
                , main =
                    "DocTest.hs"
                , source-dirs =
                    [ "library", "test-suite-doctest" ]
                , when =
                    { condition =
                        "flag(suppress-failing-tests)"
                    , buildable =
                        False
                    }
                }
            }
      }
