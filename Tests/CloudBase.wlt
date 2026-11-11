(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*setCloudBaseFromEnvironment*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Environment Variable Set*)
VerificationTest[
    environmentBlock[ "WOLFRAM_CLOUDBASE" -> "https://www.test.wolframcloud.com",
        Block[ { $CloudBase },
            Wolfram`AgentTools`Server`Local`Private`setCloudBaseFromEnvironment[ ];
            $CloudBase
        ]
    ],
    "https://www.test.wolframcloud.com",
    SameTest -> Equal,
    TestID   -> "SetCloudBaseFromEnvironment-Set"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Whitespace Is Trimmed*)
VerificationTest[
    environmentBlock[ "WOLFRAM_CLOUDBASE" -> "  https://www.test.wolframcloud.com  ",
        Block[ { $CloudBase },
            Wolfram`AgentTools`Server`Local`Private`setCloudBaseFromEnvironment[ ];
            $CloudBase
        ]
    ],
    "https://www.test.wolframcloud.com",
    SameTest -> Equal,
    TestID   -> "SetCloudBaseFromEnvironment-Trimmed"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Environment Variable Not Set*)
VerificationTest[
    environmentBlock[ "WOLFRAM_CLOUDBASE" -> None,
        Block[ { $CloudBase = "sentinel" },
            Wolfram`AgentTools`Server`Local`Private`setCloudBaseFromEnvironment[ ];
            $CloudBase
        ]
    ],
    "sentinel",
    SameTest -> Equal,
    TestID   -> "SetCloudBaseFromEnvironment-NotSet"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Empty Value Is Ignored*)
VerificationTest[
    environmentBlock[ "WOLFRAM_CLOUDBASE" -> "   ",
        Block[ { $CloudBase = "sentinel" },
            Wolfram`AgentTools`Server`Local`Private`setCloudBaseFromEnvironment[ ];
            $CloudBase
        ]
    ],
    "sentinel",
    SameTest -> Equal,
    TestID   -> "SetCloudBaseFromEnvironment-Empty"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*currentCloudBase*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Default Cloud Base*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`currentCloudBase[ "https://www.wolframcloud.com" ],
    "https://www.wolframcloud.com",
    SameTest -> Equal,
    TestID   -> "CurrentCloudBase-Default"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Trailing Slash Is Stripped*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`currentCloudBase[ "https://www.test.wolframcloud.com/" ],
    "https://www.test.wolframcloud.com",
    SameTest -> Equal,
    TestID   -> "CurrentCloudBase-TrailingSlash"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Scheme Is Added When Missing*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`currentCloudBase[ "www.test.wolframcloud.com" ],
    "https://www.test.wolframcloud.com",
    SameTest -> Equal,
    TestID   -> "CurrentCloudBase-NoScheme"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Non-String Falls Back To Default*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`currentCloudBase[ $Failed ],
    "https://www.wolframcloud.com",
    SameTest -> Equal,
    TestID   -> "CurrentCloudBase-NonString"
]

VerificationTest[
    Wolfram`AgentTools`UIResources`Private`currentCloudBase[ "" ],
    "https://www.wolframcloud.com",
    SameTest -> Equal,
    TestID   -> "CurrentCloudBase-EmptyString"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Reads $CloudBase*)
VerificationTest[
    Block[ { $CloudBase = "https://www.test.wolframcloud.com" },
        Wolfram`AgentTools`UIResources`Private`currentCloudBase[ ]
    ],
    "https://www.test.wolframcloud.com",
    SameTest -> Equal,
    TestID   -> "CurrentCloudBase-ReadsCloudBase"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*applyCloudBaseToHTML*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Rewrites the Assignment*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`applyCloudBaseToHTML[
        "<script>var WOLFRAM_CLOUDBASE = \"https://www.wolframcloud.com\";</script>",
        "https://www.test.wolframcloud.com"
    ],
    "<script>var WOLFRAM_CLOUDBASE = \"https://www.test.wolframcloud.com\";</script>",
    SameTest -> Equal,
    TestID   -> "ApplyCloudBaseToHTML-Rewrites"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*No-Op For Default Base*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`applyCloudBaseToHTML[
        "<script>var WOLFRAM_CLOUDBASE = \"https://www.wolframcloud.com\";</script>",
        "https://www.wolframcloud.com"
    ],
    "<script>var WOLFRAM_CLOUDBASE = \"https://www.wolframcloud.com\";</script>",
    SameTest -> Equal,
    TestID   -> "ApplyCloudBaseToHTML-DefaultNoOp"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*HTML Without the Assignment Is Unchanged*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`applyCloudBaseToHTML[
        "<html><body>Test</body></html>",
        "https://www.test.wolframcloud.com"
    ],
    "<html><body>Test</body></html>",
    SameTest -> Equal,
    TestID   -> "ApplyCloudBaseToHTML-NoAssignment"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*applyCloudBaseToMeta*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Prepends Custom Base To CSP Lists*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`applyCloudBaseToMeta[
        <|
            "ui" -> <|
                "csp" -> <|
                    "connectDomains"  -> { "https://www.wolframcloud.com", "data:" },
                    "resourceDomains" -> { "https://unpkg.com", "https://www.wolframcloud.com" },
                    "frameDomains"    -> { "https://www.wolframcloud.com", "https://wolfr.am" }
                |>,
                "prefersBorder" -> True
            |>
        |>,
        "https://www.test.wolframcloud.com"
    ],
    <|
        "ui" -> <|
            "csp" -> <|
                "connectDomains"  -> { "https://www.test.wolframcloud.com", "https://www.wolframcloud.com", "data:" },
                "resourceDomains" -> { "https://www.test.wolframcloud.com", "https://unpkg.com", "https://www.wolframcloud.com" },
                "frameDomains"    -> { "https://www.test.wolframcloud.com", "https://www.wolframcloud.com", "https://wolfr.am" }
            |>,
            "prefersBorder" -> True
        |>
    |>,
    SameTest -> Equal,
    TestID   -> "ApplyCloudBaseToMeta-Prepends"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Lists Without the Default Base Are Unchanged*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`applyCloudBaseToMeta[
        <| "ui" -> <| "csp" -> <| "resourceDomains" -> { "https://unpkg.com" } |> |> |>,
        "https://www.test.wolframcloud.com"
    ],
    <| "ui" -> <| "csp" -> <| "resourceDomains" -> { "https://unpkg.com" } |> |> |>,
    SameTest -> Equal,
    TestID   -> "ApplyCloudBaseToMeta-UnrelatedListUnchanged"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*No-Op For Default Base*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`applyCloudBaseToMeta[
        <| "ui" -> <| "csp" -> <| "connectDomains" -> { "https://www.wolframcloud.com", "data:" } |> |> |>,
        "https://www.wolframcloud.com"
    ],
    <| "ui" -> <| "csp" -> <| "connectDomains" -> { "https://www.wolframcloud.com", "data:" } |> |> |>,
    SameTest -> Equal,
    TestID   -> "ApplyCloudBaseToMeta-DefaultNoOp"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Meta Without CSP Is Unchanged*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`applyCloudBaseToMeta[
        <| "ui" -> <| "prefersBorder" -> True |> |>,
        "https://www.test.wolframcloud.com"
    ],
    <| "ui" -> <| "prefersBorder" -> True |> |>,
    SameTest -> Equal,
    TestID   -> "ApplyCloudBaseToMeta-NoCSP"
]

VerificationTest[
    Wolfram`AgentTools`UIResources`Private`applyCloudBaseToMeta[
        <| |>,
        "https://www.test.wolframcloud.com"
    ],
    <| |>,
    SameTest -> Equal,
    TestID   -> "ApplyCloudBaseToMeta-EmptyMeta"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Idempotent*)
VerificationTest[
    Module[ { meta, once },
        meta = <| "ui" -> <| "csp" -> <| "connectDomains" -> { "https://www.wolframcloud.com", "data:" } |> |> |>;
        once = Wolfram`AgentTools`UIResources`Private`applyCloudBaseToMeta[ meta, "https://www.test.wolframcloud.com" ];
        Wolfram`AgentTools`UIResources`Private`applyCloudBaseToMeta[ once, "https://www.test.wolframcloud.com" ] === once
    ],
    True,
    SameTest -> Equal,
    TestID   -> "ApplyCloudBaseToMeta-Idempotent"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Integration With Bundled App Assets*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Viewers Declare the Default Assignment*)
(* Guards against the `var WOLFRAM_CLOUDBASE = "..."` declaration drifting out of the viewer
   HTML files: the string replacement in applyCloudBaseToHTML would then silently stop working. *)
VerificationTest[
    Module[ { html }, Block[ { $CloudBase = "https://www.wolframcloud.com", Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        AllTrue[
            { "ui://wolfram/evaluator-viewer", "ui://wolfram/notebook-viewer", "ui://wolfram/wolframalpha-viewer" },
            ( html = Wolfram`AgentTools`Common`$uiResourceRegistry[ #, "html" ];
              StringContainsQ[ html, "var WOLFRAM_CLOUDBASE = \"https://www.wolframcloud.com\";" ] ) &
        ]
    ] ],
    True,
    SameTest -> Equal,
    TestID   -> "CloudBaseIntegration-DefaultAssignmentPresent"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Custom Base Rewrites All Viewers*)
VerificationTest[
    Module[ { html }, Block[ { $CloudBase = "https://www.test.wolframcloud.com", Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        AllTrue[
            { "ui://wolfram/evaluator-viewer", "ui://wolfram/notebook-viewer", "ui://wolfram/wolframalpha-viewer" },
            ( html = Wolfram`AgentTools`Common`$uiResourceRegistry[ #, "html" ];
              StringContainsQ[ html, "var WOLFRAM_CLOUDBASE = \"https://www.test.wolframcloud.com\";" ] &&
              StringFreeQ[ html, "var WOLFRAM_CLOUDBASE = \"https://www.wolframcloud.com\";" ] ) &
        ]
    ] ],
    True,
    SameTest -> Equal,
    TestID   -> "CloudBaseIntegration-CustomBaseRewritesViewers"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Custom Base Augments CSP Metadata*)
VerificationTest[
    Block[ { $CloudBase = "https://www.test.wolframcloud.com", Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`$uiResourceRegistry[
            "ui://wolfram/evaluator-viewer", "meta", "ui", "csp", "connectDomains"
        ]
    ],
    { "https://www.test.wolframcloud.com", "https://www.wolframcloud.com", "data:" },
    SameTest -> Equal,
    TestID   -> "CloudBaseIntegration-CustomBaseConnectDomains"
]

VerificationTest[
    Block[ { $CloudBase = "https://www.test.wolframcloud.com", Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`$uiResourceRegistry[
            "ui://wolfram/evaluator-viewer", "meta", "ui", "csp", "frameDomains"
        ]
    ],
    { "https://www.test.wolframcloud.com", "https://www.wolframcloud.com", "https://wolfr.am" },
    SameTest -> Equal,
    TestID   -> "CloudBaseIntegration-CustomBaseFrameDomains"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Default Base Leaves CSP Metadata Unchanged*)
VerificationTest[
    Block[ { $CloudBase = "https://www.wolframcloud.com", Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`$uiResourceRegistry[
            "ui://wolfram/evaluator-viewer", "meta", "ui", "csp", "connectDomains"
        ]
    ],
    { "https://www.wolframcloud.com", "data:" },
    SameTest -> Equal,
    TestID   -> "CloudBaseIntegration-DefaultBaseCSPUnchanged"
]

(* :!CodeAnalysis::EndBlock:: *)
