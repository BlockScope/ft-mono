    let defs = ./../defaults.dhall

in    defs
    ⫽ ./../default-extensions.dhall
    ⫽ { name =
          "app-serve"
      , synopsis =
          "A collection of apps and libraries for scoring hang gliding and paragliding competitions."
      , description =
          "Scoring and viewing hang gliding and paragliding competitions."
      , category =
          "Data, Parsing"
      , github =
          "blockscope/flare-timing/app-serve"
      , dependencies =
          defs.dependencies
      , ghc-options =
          [ "-Wall", "-fplugin Data.UnitsOfMeasure.Plugin" ]
      , executables =
          { comp-py =
              { dependencies =
                  [ "aeson"
                  , "bytestring"
                  , "cmdargs"
                  , "containers"
                  , "directory"
                  , "filepath"
                  , "filemanip"
                  , "lens"
                  , "mtl"
                  , "raw-strings-qq"
                  , "sampling"
                  , "safe-exceptions"
                  , "servant"
                  , "servant-server"
                  , "servant-swagger"
                  , "servant-swagger-ui"
                  , "swagger2"
                  , "statistics"
                  , "text"
                  , "time"
                  , "transformers"
                  , "vector"
                  , "wai"
                  , "wai-cors"
                  , "wai-extra"
                  , "warp"
                  , "yaml"
                  , "uom-plugin"
                  , "flight-cmd"
                  , "flight-clip"
                  , "flight-earth"
                  , "flight-comp"
                  , "flight-gap-allot"
                  , "flight-gap-effort"
                  , "flight-gap-lead"
                  , "flight-gap-math"
                  , "flight-gap-stop"
                  , "flight-gap-valid"
                  , "flight-gap-weight"
                  , "flight-kml"
                  , "flight-latlng"
                  , "flight-mask"
                  , "flight-route"
                  , "flight-scribe"
                  , "flight-units"
                  , "flight-zone"
                  , "detour-via-sci"
                  , "siggy-chardust"
                  , "servant-py"
                  ]
              , other-modules =
                  [ "ServeApi"
                  , "ServeArea"
                  , "ServeOptions"
                  , "ServeSwagger"
                  , "ServeTrack"
                  , "ServeValidity"
                  ]
              , main =
                  "GenPyClient.hs"
              , source-dirs =
                  "src"
              }
          , comp-serve =
              { dependencies =
                  [ "aeson"
                  , "bytestring"
                  , "cmdargs"
                  , "containers"
                  , "directory"
                  , "filepath"
                  , "filemanip"
                  , "lens"
                  , "mtl"
                  , "raw-strings-qq"
                  , "sampling"
                  , "safe-exceptions"
                  , "servant"
                  , "servant-server"
                  , "servant-swagger"
                  , "servant-swagger-ui"
                  , "swagger2"
                  , "statistics"
                  , "text"
                  , "time"
                  , "transformers"
                  , "vector"
                  , "wai"
                  , "wai-cors"
                  , "wai-extra"
                  , "warp"
                  , "yaml"
                  , "uom-plugin"
                  , "flight-cmd"
                  , "flight-clip"
                  , "flight-earth"
                  , "flight-comp"
                  , "flight-gap-allot"
                  , "flight-gap-effort"
                  , "flight-gap-lead"
                  , "flight-gap-math"
                  , "flight-gap-stop"
                  , "flight-gap-valid"
                  , "flight-gap-weight"
                  , "flight-kml"
                  , "flight-latlng"
                  , "flight-mask"
                  , "flight-route"
                  , "flight-scribe"
                  , "flight-units"
                  , "flight-zone"
                  , "detour-via-sci"
                  , "siggy-chardust"
                  ]
              , ghc-options =
                  [ "-rtsopts", "-threaded", "-with-rtsopts=-N" ]
              , other-modules =
                  [ "ServeApi"
                  , "ServeArea"
                  , "ServeOptions"
                  , "ServeSwagger"
                  , "ServeTrack"
                  , "ServeValidity"
                  ]
              , main =
                  "ServeMain.hs"
              , source-dirs =
                  "src"
              }
          }
      , tests =
          { hlint =
              { dependencies =
                  [ "base", "hlint", "flight-comp" ]
              , ghc-options =
                  [ "-rtsopts", "-threaded", "-with-rtsopts=-N" ]
              , main =
                  "HLint.hs"
              , source-dirs =
                  "test-suite-hlint"
              , when =
                  { condition =
                      "flag(suppress-failing-tests)"
                  , buildable =
                      False
                  }
              }
          }
      }
