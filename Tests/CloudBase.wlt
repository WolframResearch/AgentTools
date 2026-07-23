(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/CloudBase.wlt:7,1-12,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/CloudBase.wlt:14,1-19,2"
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
    TestID   -> "SetCloudBaseFromEnvironment-Set@@Tests/CloudBase.wlt:28,1-38,2"
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
    TestID   -> "SetCloudBaseFromEnvironment-Trimmed@@Tests/CloudBase.wlt:43,1-53,2"
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
    TestID   -> "SetCloudBaseFromEnvironment-NotSet@@Tests/CloudBase.wlt:58,1-68,2"
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
    TestID   -> "SetCloudBaseFromEnvironment-Empty@@Tests/CloudBase.wlt:73,1-83,2"
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
    TestID   -> "CurrentCloudBase-Default@@Tests/CloudBase.wlt:92,1-97,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Trailing Slash Is Stripped*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`currentCloudBase[ "https://www.test.wolframcloud.com/" ],
    "https://www.test.wolframcloud.com",
    SameTest -> Equal,
    TestID   -> "CurrentCloudBase-TrailingSlash@@Tests/CloudBase.wlt:102,1-107,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Scheme Is Added When Missing*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`currentCloudBase[ "www.test.wolframcloud.com" ],
    "https://www.test.wolframcloud.com",
    SameTest -> Equal,
    TestID   -> "CurrentCloudBase-NoScheme@@Tests/CloudBase.wlt:112,1-117,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Non-String Falls Back To Default*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`currentCloudBase[ $Failed ],
    "https://www.wolframcloud.com",
    SameTest -> Equal,
    TestID   -> "CurrentCloudBase-NonString@@Tests/CloudBase.wlt:122,1-127,2"
]

VerificationTest[
    Wolfram`AgentTools`UIResources`Private`currentCloudBase[ "" ],
    "https://www.wolframcloud.com",
    SameTest -> Equal,
    TestID   -> "CurrentCloudBase-EmptyString@@Tests/CloudBase.wlt:129,1-134,2"
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
    TestID   -> "CurrentCloudBase-ReadsCloudBase@@Tests/CloudBase.wlt:139,1-146,2"
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
    TestID   -> "ApplyCloudBaseToHTML-Rewrites@@Tests/CloudBase.wlt:155,1-163,2"
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
    TestID   -> "ApplyCloudBaseToHTML-DefaultNoOp@@Tests/CloudBase.wlt:168,1-176,2"
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
    TestID   -> "ApplyCloudBaseToHTML-NoAssignment@@Tests/CloudBase.wlt:181,1-189,2"
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
    TestID   -> "ApplyCloudBaseToMeta-Prepends@@Tests/CloudBase.wlt:198,1-224,2"
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
    TestID   -> "ApplyCloudBaseToMeta-UnrelatedListUnchanged@@Tests/CloudBase.wlt:229,1-237,2"
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
    TestID   -> "ApplyCloudBaseToMeta-DefaultNoOp@@Tests/CloudBase.wlt:242,1-250,2"
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
    TestID   -> "ApplyCloudBaseToMeta-NoCSP@@Tests/CloudBase.wlt:255,1-263,2"
]

VerificationTest[
    Wolfram`AgentTools`UIResources`Private`applyCloudBaseToMeta[
        <| |>,
        "https://www.test.wolframcloud.com"
    ],
    <| |>,
    SameTest -> Equal,
    TestID   -> "ApplyCloudBaseToMeta-EmptyMeta@@Tests/CloudBase.wlt:265,1-273,2"
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
    TestID   -> "ApplyCloudBaseToMeta-Idempotent@@Tests/CloudBase.wlt:278,1-287,2"
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
    TestID   -> "CloudBaseIntegration-DefaultAssignmentPresent@@Tests/CloudBase.wlt:298,1-310,2"
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
    TestID   -> "CloudBaseIntegration-CustomBaseRewritesViewers@@Tests/CloudBase.wlt:315,1-328,2"
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
    TestID   -> "CloudBaseIntegration-CustomBaseConnectDomains@@Tests/CloudBase.wlt:333,1-343,2"
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
    TestID   -> "CloudBaseIntegration-CustomBaseFrameDomains@@Tests/CloudBase.wlt:345,1-355,2"
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
    TestID   -> "CloudBaseIntegration-DefaultBaseCSPUnchanged@@Tests/CloudBase.wlt:360,1-370,2"
]

(* :!CodeAnalysis::EndBlock:: *)
