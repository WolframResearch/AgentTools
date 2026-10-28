(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Tools.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Tools.wlt:11,1-16,2"
]

(* Helper function to extract text from tool results (handles both string and structured content) *)
extractToolText[ str_String ] := str;
extractToolText[ as_Association ] /; KeyExistsQ[ as, "Content" ] :=
    StringJoin @ Cases[ as[ "Content" ], KeyValuePattern[ { "type" -> "text", "text" -> t_String } ] :> t ];
extractToolText[ _ ] := "";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$DefaultMCPTools*)
VerificationTest[
    $DefaultMCPTools,
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DefaultMCPTools-IsAssociation@@Tests/Tools.wlt:27,1-32,2"
]

VerificationTest[
    Keys @ $DefaultMCPTools,
    {
        OrderlessPatternSequence[
            "BuildPaclet",
            "CheckPaclet",
            "CodeInspector",
            "CreateSymbolDoc",
            "EditSymbolDoc",
            "EditSymbolDocExamples",
            "MCPAppsTest",
            "NotebookViewer",
            "ReadNotebook",
            "SubmitPaclet",
            "SymbolDefinition",
            "TestReport",
            "WolframAlpha",
            "WolframAlphaContext",
            "WolframContext",
            "WolframLanguageContext",
            "WolframLanguageEvaluator",
            "WolframLicenseStatus",
            "WriteNotebook"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "DefaultMCPTools-Keys@@Tests/Tools.wlt:34,1-61,2"
]

VerificationTest[
    AllTrue[ Values @ $DefaultMCPTools, MatchQ[ _LLMTool ] ],
    True,
    SameTest -> SameQ,
    TestID   -> "DefaultMCPTools-AllLLMTools@@Tests/Tools.wlt:63,1-68,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ReadNotebook*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $readNotebookTool = $DefaultMCPTools[ "ReadNotebook" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-GetTool@@Tests/Tools.wlt:77,1-82,2"
]

VerificationTest[
    $exampleNotebook = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources", "document.nb" },
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-FindExampleFile@@Tests/Tools.wlt:84,1-89,2"
]

VerificationTest[
    $readNotebookResult = $readNotebookTool[ <| "notebook" -> $exampleNotebook |> ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-BasicRead@@Tests/Tools.wlt:91,1-96,2"
]

VerificationTest[
    (* Check for the presence of a Wolfram Language code block *)
    StringContainsQ[ $readNotebookResult, "\n```wl\n" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ReadNotebook-ContainsExpectedContent@@Tests/Tools.wlt:98,1-104,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Cases*)
VerificationTest[
    $readNotebookTool[ <| "notebook" -> "nonexistent_file_12345.nb" |> ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-NonexistentFile@@Tests/Tools.wlt:109,1-114,2"
]

(* A missing file is reported as such rather than being parsed as a NotebookObject specification. *)
VerificationTest[
    $readNotebookTool[ <| "notebook" -> "nonexistent_file_12345.nb" |> ],
    "File does not exist: nonexistent_file_12345.nb",
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-NonexistentFile-Message@@Tests/Tools.wlt:117,1-122,2"
]

VerificationTest[
    $readNotebookTool[ <| "notebook" -> "NotebookObject[oops]" |> ],
    _String? (StringStartsQ[ "Invalid notebook specification" ]),
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-InvalidNotebookObjectSpec@@Tests/Tools.wlt:124,1-129,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*URLs (cloud-gated)*)

(* URL inputs are first tried as cloud objects, so these need a cloud session; skipped otherwise. *)
$cloudNotebookTest = conditionalTest @ TrueQ @ $CloudConnected;

$cloudNotebookTest @ VerificationTest[
    $readNotebookTool[ <| "notebook" -> "https://www.wolfram.com/" |> ],
    _String? (StringStartsQ[ "URL does not point to a valid Wolfram notebook" ]),
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-URL-NotANotebook@@Tests/Tools.wlt:138,22-143,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WriteNotebook*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $writeNotebookTool = $DefaultMCPTools[ "WriteNotebook" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-GetTool@@Tests/Tools.wlt:152,1-157,2"
]

VerificationTest[
    $tempNotebookFile = FileNameJoin[ { $TemporaryDirectory, "AgentToolsTest_" <> CreateUUID[ ] <> ".nb" } ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-CreateTempPath@@Tests/Tools.wlt:159,1-164,2"
]

VerificationTest[
    $writeNotebookResult = $writeNotebookTool[ <|
        "markdown" -> "# Test Notebook\n\nThis is a test paragraph.\n\n```wl\n1 + 1\n```",
        "file" -> $tempNotebookFile,
        "overwrite" -> False
    |> ],
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-BasicWrite@@Tests/Tools.wlt:166,1-175,2"
]

VerificationTest[
    FileExistsQ @ $tempNotebookFile,
    True,
    SameTest -> SameQ,
    TestID   -> "WriteNotebook-FileExists@@Tests/Tools.wlt:177,1-182,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Overwrite Behavior*)
VerificationTest[
    $writeNotebookTool[ <|
        "markdown" -> "# Another Test",
        "file" -> $tempNotebookFile,
        "overwrite" -> False
    |> ],
    _String? (StringStartsQ[ "File already exists" ]),
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-NoOverwriteExisting@@Tests/Tools.wlt:187,1-196,2"
]

VerificationTest[
    $writeNotebookTool[ <|
        "markdown" -> "# Overwritten Notebook",
        "file" -> $tempNotebookFile,
        "overwrite" -> True
    |> ],
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-OverwriteExisting@@Tests/Tools.wlt:198,1-207,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Missing Directories*)

(* Writing to a path whose parent directories do not exist should create the
   intermediate directories rather than failing with an internal error (GH#200). *)
VerificationTest[
    $missingDirRoot         = FileNameJoin @ { $TemporaryDirectory, "AgentToolsMissingDir_" <> CreateUUID[ ] };
    $missingDirNotebookFile = FileNameJoin @ { $missingDirRoot, "nested", "test.nb" };
    { DirectoryQ @ $missingDirRoot, StringQ @ $missingDirNotebookFile },
    { False, True },
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-MissingDirectory-Setup-GH#200@@Tests/Tools.wlt:215,1-222,2"
]

VerificationTest[
    $writeNotebookTool[ <|
        "markdown"  -> "# Created In New Directory",
        "file"      -> $missingDirNotebookFile,
        "overwrite" -> False
    |> ],
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-MissingDirectory-CreatesPath-GH#200@@Tests/Tools.wlt:224,1-233,2"
]

VerificationTest[
    FileExistsQ @ $missingDirNotebookFile,
    True,
    SameTest -> SameQ,
    TestID   -> "WriteNotebook-MissingDirectory-FileExists-GH#200@@Tests/Tools.wlt:235,1-240,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    If[ FileExistsQ @ $tempNotebookFile, DeleteFile @ $tempNotebookFile ];
    If[ DirectoryQ @ $missingDirRoot, DeleteDirectory[ $missingDirRoot, DeleteContents -> True ] ];
    { FileExistsQ @ $tempNotebookFile, DirectoryQ @ $missingDirRoot },
    { False, False },
    SameTest -> SameQ,
    TestID   -> "WriteNotebook-Cleanup@@Tests/Tools.wlt:245,1-252,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cloud Override*)

(* Under a cloud-deployed server ($MCPEvaluationEnvironment === "Cloud") WriteNotebook is overridden to
   write a cloud object instead of a local file (see applyToolOverrides in Kernel/Server/Shared.wl). The
   overridden tool is obtained the way initializeServerState builds it. *)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
$cloudWriteNotebookTool = Block[ { $MCPEvaluationEnvironment = "Cloud" },
    Wolfram`AgentTools`Server`Shared`Private`applyToolOverrides @ $DefaultMCPTools[ "WriteNotebook" ]
];
(* :!CodeAnalysis::EndBlock:: *)

VerificationTest[
    $cloudWriteNotebookTool[ "Parameters" ][[ All, 1 ]],
    { "path", "permissions", "overwrite", "markdown" },
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-CloudOverride-Parameters@@Tests/Tools.wlt:268,1-273,2"
]

VerificationTest[
    $cloudWriteNotebookTool[ "Description" ],
    _String? (StringContainsQ[ "cloud object" ]),
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-CloudOverride-Description@@Tests/Tools.wlt:275,1-280,2"
]

(* The default tool is untouched by the override. *)
VerificationTest[
    $DefaultMCPTools[ "WriteNotebook" ][ "Parameters" ][[ All, 1 ]],
    { "file", "overwrite", "markdown" },
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-CloudOverride-DefaultUnchanged@@Tests/Tools.wlt:283,1-288,2"
]

(* The remaining tests write to (and clean up from) the connected cloud account; skipped otherwise. *)
$cloudNotebookTest @ VerificationTest[
    $cloudNotebookPath   = "Claude/agenttools-test-" <> CreateUUID[ ] <> ".nb";
    $cloudNotebookResult = $cloudWriteNotebookTool[ <|
        "markdown" -> "# Cloud Test Notebook\n\nThis notebook was written by the WriteNotebook tool.\n\n```wl\n1 + 1\n```",
        "path"     -> $cloudNotebookPath
    |> ],
    _String? (StringStartsQ[ "http" ]),
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-Cloud-BasicWrite@@Tests/Tools.wlt:291,22-300,2"
]

$cloudNotebookTest @ VerificationTest[
    FileExistsQ @ CloudObject @ $cloudNotebookResult,
    True,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-Cloud-ObjectExists@@Tests/Tools.wlt:302,22-307,2"
]

(* Poll (a few seconds at most) for the expected permissions, since cloud metadata reads can be transiently
   unavailable right after a write; the last observed value is returned either way, so a failure shows
   what was actually seen. Permission names come back as symbols or strings depending on the session
   (All vs. "All"), so the predicates accept both. *)
cloudNotebookPermissions[ url_String, expectedQ_ ] := Catch[
    Module[ { permissions },
        Do[
            permissions = Quiet @ Options[ CloudObject @ url, Permissions ];
            If[ TrueQ @ expectedQ @ permissions, Throw[ permissions, cloudNotebookPermissions ] ];
            Pause[ 2.0 ],
            { 5 }
        ];
        permissions
    ],
    cloudNotebookPermissions
];

cloudNotebookPublicQ[ { Permissions -> permissions_List } ] := ! FreeQ[ permissions, All | "All" ];
cloudNotebookPublicQ[ _ ] := False;

cloudNotebookPrivateQ[ { Permissions -> permissions_List } ] := FreeQ[ permissions, All | "All" ];
cloudNotebookPrivateQ[ _ ] := False;

(* Permissions default to private. *)
$cloudNotebookTest @ VerificationTest[
    cloudNotebookPermissions[ $cloudNotebookResult, cloudNotebookPrivateQ ],
    _? cloudNotebookPrivateQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-Cloud-DefaultPrivate@@Tests/Tools.wlt:333,22-338,2"
]

(* ReadNotebook reads the cloud object back from its URL. *)
$cloudNotebookTest @ VerificationTest[
    $readNotebookTool[ <| "notebook" -> $cloudNotebookResult |> ],
    _String? (StringContainsQ[ "# Cloud Test Notebook" ]),
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-Cloud-URL@@Tests/Tools.wlt:341,22-346,2"
]

$cloudNotebookTest @ VerificationTest[
    $cloudWriteNotebookTool[ <| "markdown" -> "# Another Test", "path" -> $cloudNotebookPath |> ],
    _String? (StringStartsQ[ "File already exists" ]),
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-Cloud-NoOverwriteExisting@@Tests/Tools.wlt:348,22-353,2"
]

$cloudNotebookTest @ VerificationTest[
    $cloudWriteNotebookTool[ <|
        "markdown"    -> "# Overwritten Notebook",
        "path"        -> $cloudNotebookPath,
        "overwrite"   -> True,
        "permissions" -> "Public"
    |> ],
    $cloudNotebookResult,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-Cloud-OverwriteExisting@@Tests/Tools.wlt:355,22-365,2"
]

$cloudNotebookTest @ VerificationTest[
    cloudNotebookPermissions[ $cloudNotebookResult, cloudNotebookPublicQ ],
    _? cloudNotebookPublicQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-Cloud-PublicPermissions@@Tests/Tools.wlt:367,22-372,2"
]

(* Only markdown is required: the omitted parameters arrive as Missing["NoInput"] and a new anonymous
   cloud object is used. *)
$cloudNotebookTest @ VerificationTest[
    $cloudAnonymousNotebook = $cloudWriteNotebookTool[ <| "markdown" -> "# Anonymous Notebook" |> ],
    url_String /; StringStartsQ[ url, "http" ] && StringFreeQ[ url, "/Claude/" ],
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-Cloud-AnonymousObject@@Tests/Tools.wlt:376,22-381,2"
]

$cloudNotebookTest @ VerificationTest[
    $readNotebookTool[ <| "notebook" -> $cloudAnonymousNotebook |> ],
    _String? (StringContainsQ[ "# Anonymous Notebook" ]),
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-Cloud-AnonymousURL@@Tests/Tools.wlt:383,22-388,2"
]

$cloudNotebookTest @ VerificationTest[
    DeleteObject /@ { CloudObject @ $cloudNotebookResult, CloudObject @ $cloudAnonymousNotebook };
    FileExistsQ /@ { CloudObject @ $cloudNotebookResult, CloudObject @ $cloudAnonymousNotebook },
    { False, False },
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-Cloud-Cleanup@@Tests/Tools.wlt:390,22-396,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframLanguageEvaluator*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $evaluatorTool = $DefaultMCPTools[ "WolframLanguageEvaluator" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-GetTool@@Tests/Tools.wlt:405,1-410,2"
]

VerificationTest[
    $evalResult1 = $evaluatorTool[ <| "code" -> "1 + 1" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-BasicEval@@Tests/Tools.wlt:412,1-417,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult1, "2" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-CorrectResult@@Tests/Tools.wlt:419,1-424,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult1, "Out[" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-HasOutLabel@@Tests/Tools.wlt:426,1-431,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Time Constraint*)
VerificationTest[
    $evalResult2 = $evaluatorTool[ <| "code" -> "Range[5]", "timeConstraint" -> 30 |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-WithTimeConstraint@@Tests/Tools.wlt:436,1-441,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult2, "{1, 2, 3, 4, 5}" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-RangeResult@@Tests/Tools.wlt:443,1-448,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Complex Expressions*)
VerificationTest[
    $evalResult3 = $evaluatorTool[ <| "code" -> "Table[n^2, {n, 1, 4}]" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-TableExpression@@Tests/Tools.wlt:453,1-458,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult3, "{1, 4, 9, 16}" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-TableResult@@Tests/Tools.wlt:460,1-465,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*String Output*)
VerificationTest[
    $evalResult4 = $evaluatorTool[ <| "code" -> "StringJoin[\"Hello\", \" \", \"World\"]" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-StringExpression@@Tests/Tools.wlt:470,1-475,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult4, "Hello World" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-StringResult@@Tests/Tools.wlt:477,1-482,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Print Output*)
VerificationTest[
    $evalResultPrint1 = $evaluatorTool[ <| "code" -> "Print[\"Hello from Print\"]; 42" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-PrintBasic@@Tests/Tools.wlt:487,1-492,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResultPrint1, "Hello from Print" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-PrintOutputCaptured@@Tests/Tools.wlt:494,1-499,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResultPrint1, "42" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-PrintResultIncluded@@Tests/Tools.wlt:501,1-506,2"
]

VerificationTest[
    $evalResultPrint2 = $evaluatorTool[ <| "code" -> "Print[\"First\"]; Print[\"Second\"]; Print[\"Third\"]; \"Done\"" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-MultiplePrints@@Tests/Tools.wlt:508,1-513,2"
]

VerificationTest[
    With[ { text = extractToolText @ $evalResultPrint2 },
        StringContainsQ[ text, "First" ] && StringContainsQ[ text, "Second" ] && StringContainsQ[ text, "Third" ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-MultiplePrintsCaptured@@Tests/Tools.wlt:515,1-522,2"
]

VerificationTest[
    $evalResultPrint3 = $evaluatorTool[ <| "code" -> "Do[Print[i], {i, 3}]; \"Complete\"" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-PrintInLoop@@Tests/Tools.wlt:524,1-529,2"
]

VerificationTest[
    With[ { text = extractToolText @ $evalResultPrint3 },
        StringContainsQ[ text, "1" ] && StringContainsQ[ text, "2" ] && StringContainsQ[ text, "3" ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-PrintInLoopCaptured@@Tests/Tools.wlt:531,1-538,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Messages*)

(* Messages issued during evaluation are captured in the tool result text. With "PropagateMessages" -> True,
   they also fire normally at top level (where StartMCPServer handles them when running as a server), which
   is why this test declares First::nofirst as an expected message. *)
VerificationTest[
    $evalResultMsg1 = $evaluatorTool[ <| "code" -> "First[{}]" |> ],
    _String | _Association,
    { First::nofirst },
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-GenuineMessage@@Tests/Tools.wlt:547,1-553,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResultMsg1, "First::nofirst" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-GenuineMessageCaptured@@Tests/Tools.wlt:555,1-560,2"
]

(* Messages quieted by the evaluated code do not appear in the tool result: *)
VerificationTest[
    StringFreeQ[ extractToolText @ $evaluatorTool[ <| "code" -> "Quiet[First[{}]]" |> ], "First::nofirst" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-QuietedMessageNotReported@@Tests/Tools.wlt:563,1-568,2"
]

(* Messages suppressed by kernel-internal mechanisms do not appear in the tool result: *)
VerificationTest[
    StringFreeQ[
        extractToolText @ $evaluatorTool[ <| "code" -> "Internal`DeactivateMessages[First[{}], First::nofirst]" |> ],
        "First::nofirst"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-DeactivatedMessageNotReported@@Tests/Tools.wlt:571,1-579,2"
]

(* Messages that internal kernel code issues and suppresses during evaluation (e.g. inside FullSimplify)
   were previously misreported in tool results as false "-- Message text not found --" entries.
   "PropagateMessages" -> True makes the sandbox report only messages that actually surface: *)
VerificationTest[
    $evalResultMsg2 = extractToolText @ $evaluatorTool[
        <|
            "code"           -> "FullSimplify[Integrate[a + b Log[c Log[d x^n]^p], x], {d>0, x>0, n!=0}]",
            "timeConstraint" -> 120
        |>
    ],
    _String? (StringContainsQ[ "ExpIntegralEi" ]),
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-InternallySuppressedMessages@@Tests/Tools.wlt:584,1-594,2"
]

VerificationTest[
    StringFreeQ[ $evalResultMsg2, { "Message text not found", "::ivar", "General::messages" } ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-InternallySuppressedMessagesNotReported@@Tests/Tools.wlt:596,1-601,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UI Evaluation Path*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* The UI path passes WolframLanguageToolEvaluate options (e.g. "PropagateMessages") that require the
   minimum Chatbook version, and older Chatbook versions silently ignore unknown options, so it must run
   the same version check as the non-UI path. Downstream functions are mocked so no front end, cloud
   deployment, or sandbox evaluation is involved. *)
VerificationTest[
    Module[ { checked = False },
        Block[
            {
                Wolfram`AgentTools`Common`chatbookVersionCheck =
                    Function[ checked = True; True ],
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`evaluateWolframLanguageForUI =
                    Function[ <| "String" -> "Out[1]= 2", "Result" -> HoldForm[ 2 ] |> ],
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`makeEvaluatorUIResult =
                    Function[ <| "Content" -> { <| "type" -> "text", "text" -> "ok" |> } |> ],
                UsingFrontEnd = # &
            },
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`evaluateWolframLanguageUI[ "1 + 1", 10 ],
                checked
            }
        ]
    ],
    { KeyValuePattern[ "Content" -> { __Association } ], True },
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-UIPathVersionCheck@@Tests/Tools.wlt:614,1-635,2"
]

(* A failing version check aborts the UI path before any evaluation is attempted: *)
VerificationTest[
    Module[ { evaluated = False, result },
        result = Quiet @ Wolfram`AgentTools`Common`catchAlways @ Block[
            {
                Wolfram`AgentTools`Common`chatbookVersionCheck = Function[ $Failed ],
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`evaluateWolframLanguageForUI =
                    Function[ evaluated = True; <| "String" -> "Out[1]= 2", "Result" -> HoldForm[ 2 ] |> ]
            },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`evaluateWolframLanguageUI[ "1 + 1", 10 ]
        ];
        { FailureQ @ result, evaluated }
    ],
    { True, False },
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-UIPathVersionCheckFailure@@Tests/Tools.wlt:638,1-653,2"
]

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframAlpha*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $wolframAlphaTool = $DefaultMCPTools[ "WolframAlpha" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "WolframAlpha-GetTool@@Tests/Tools.wlt:664,1-669,2"
]

VerificationTest[
    $waResult = $wolframAlphaTool[ <| "query" -> "population of France" |> ],
    _String? StringQ | KeyValuePattern[ "Content" -> { __Association } ],
    SameTest -> MatchQ,
    TestID   -> "WolframAlpha-BasicQuery@@Tests/Tools.wlt:671,1-676,2"
]

VerificationTest[
    $waResultString =
        If[ StringQ @ $waResult,
            $waResult,
            StringJoin @ Select[ $waResult[[ "Content", All, "text" ]], StringQ ]
        ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "WolframAlpha-ResultString@@Tests/Tools.wlt:678,1-687,2"
]

VerificationTest[
    StringLength @ $waResultString > 0,
    True,
    SameTest -> SameQ,
    TestID   -> "WolframAlpha-NonEmptyResult@@Tests/Tools.wlt:689,1-694,2"
]

(* TODO: multiple queries aren't supported until the next Chatbook paclet update *)
(* VerificationTest[
    $waResult = $wolframAlphaTool[ <| "query" -> "population of France\tpopulation of Germany" |> ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "WolframAlpha-MultipleQueries@@Tests/Tools.wlt:279,1-284,2"
]

VerificationTest[
    StringCount[ $waResult, "<result query=" ],
    2,
    SameTest -> SameQ,
    TestID   -> "WolframAlpha-MultipleQueriesResultCount@@Tests/Tools.wlt:286,1-291,2"
] *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframLanguageContext*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $wlContextTool = $DefaultMCPTools[ "WolframLanguageContext" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageContext-GetTool@@Tests/Tools.wlt:718,1-723,2"
]

skipIfGitHubActions @ VerificationTest[
    $wlContextResult = $wlContextTool[ <| "context" -> "How to create a list of prime numbers in Wolfram Language" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageContext-BasicQuery@@Tests/Tools.wlt:725,23-730,2"
]

skipIfGitHubActions @ VerificationTest[
    StringLength[ extractToolText @ $wlContextResult ] > 0,
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageContext-NonEmptyResult@@Tests/Tools.wlt:732,23-737,2"
]

skipIfGitHubActions @ VerificationTest[
    StringContainsQ[ extractToolText @ $wlContextResult, "Prime" | "prime" | "Table" | "Range", IgnoreCase -> True ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageContext-RelevantContent@@Tests/Tools.wlt:739,23-744,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframAlphaContext*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $waContextTool = $DefaultMCPTools[ "WolframAlphaContext" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "WolframAlphaContext-GetTool@@Tests/Tools.wlt:753,1-758,2"
]

skipIfGitHubActions @ VerificationTest[
    $waContextResult = $waContextTool[ <| "context" -> "What is the distance from Earth to Mars" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframAlphaContext-BasicQuery@@Tests/Tools.wlt:760,23-765,2"
]

skipIfGitHubActions @ VerificationTest[
    StringLength[ extractToolText @ $waContextResult ] > 0,
    True,
    SameTest -> SameQ,
    TestID   -> "WolframAlphaContext-NonEmptyResult@@Tests/Tools.wlt:767,23-772,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframContext*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $wolframContextTool = $DefaultMCPTools[ "WolframContext" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "WolframContext-GetTool@@Tests/Tools.wlt:781,1-786,2"
]

skipIfGitHubActions @ VerificationTest[
    $wolframContextResult = $wolframContextTool[ <| "context" -> "How to compute derivatives symbolically" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframContext-BasicQuery@@Tests/Tools.wlt:788,23-793,2"
]

skipIfGitHubActions @ VerificationTest[
    StringLength[ extractToolText @ $wolframContextResult ] > 0,
    True,
    SameTest -> SameQ,
    TestID   -> "WolframContext-NonEmptyResult@@Tests/Tools.wlt:795,23-800,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*LLMKit Usage Limit Handling*)

(* These tests mock the Chatbook calls so they exercise the over-limit code path without a live service. *)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* The Failure that RelatedWolframAlphaResults / RelatedDocumentation return when the user has exceeded
   their monthly LLMKit credit allotment (HTTP 429). *)
$usageLimitFailure = Failure[ "APIError", <|
    "MessageTemplate"   -> "The service returned the following error message: `1`.",
    "MessageParameters" -> { "credits-per-month-limit-exceeded - User has exceeded credits limit." },
    "StatusCode"        -> 429,
    "Body"              -> <|
        "success" -> False,
        "error"   -> <|
            "code"    -> "credits-per-month-limit-exceeded",
            "message" -> "credits-per-month-limit-exceeded - User has exceeded credits limit."
        |>
    |>
|> ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*RelatedWolframAlphaResults*)

(* An over-limit Failure becomes a useful, actionable message instead of an opaque internal failure. *)
VerificationTest[
    $waUsageLimitResult = Block[
        {
            Wolfram`AgentTools`Common`chatbookVersionCheck      = ( True & ),
            Wolfram`Chatbook`RelatedWolframAlphaResults         = ( $usageLimitFailure & )
        },
        Wolfram`AgentTools`Common`relatedWolframAlphaResults[ "Print Hello in Wolfram Language", "Error" ]
    ],
    _String? (StringContainsQ[ "usage limit" ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-UsageLimitMessage@@Tests/Tools.wlt:831,1-842,2"
]

(* The service's own error message is surfaced to the agent. *)
VerificationTest[
    StringContainsQ[ $waUsageLimitResult, "credits-per-month-limit-exceeded" ],
    True,
    SameTest -> SameQ,
    TestID   -> "RelatedWolframAlphaResults-UsageLimitIncludesServiceMessage@@Tests/Tools.wlt:845,1-850,2"
]

(* It is NOT a Failure, so the MCP layer will not flag it as an error or emit a bug report. *)
VerificationTest[
    FailureQ @ $waUsageLimitResult,
    False,
    SameTest -> SameQ,
    TestID   -> "RelatedWolframAlphaResults-UsageLimitNotFailure@@Tests/Tools.wlt:853,1-858,2"
]

(* The caller's message level (e.g. "Warning" from the combined WolframContext tool) is honored. *)
VerificationTest[
    StringStartsQ[
        Block[
            {
                Wolfram`AgentTools`Common`chatbookVersionCheck = ( True & ),
                Wolfram`Chatbook`RelatedWolframAlphaResults    = ( $usageLimitFailure & )
            },
            Wolfram`AgentTools`Common`relatedWolframAlphaResults[ "Print Hello in Wolfram Language", "Warning" ]
        ],
        "Warning:"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "RelatedWolframAlphaResults-UsageLimitLevel@@Tests/Tools.wlt:861,1-875,2"
]

(* A genuine string result is still returned unchanged (regression guard). *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Common`chatbookVersionCheck = ( True & ),
            Wolfram`Chatbook`RelatedWolframAlphaResults    = ( "Some Wolfram|Alpha context." & )
        },
        Wolfram`AgentTools`Common`relatedWolframAlphaResults[ "population of France", "Error" ]
    ],
    "Some Wolfram|Alpha context.",
    SameTest -> SameQ,
    TestID   -> "RelatedWolframAlphaResults-NormalResultUnchanged@@Tests/Tools.wlt:878,1-889,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*RelatedDocumentation*)

VerificationTest[
    $docUsageLimitResult = Block[
        {
            Wolfram`AgentTools`Common`chatbookVersionCheck = ( True & ),
            Wolfram`AgentTools`Common`llmKitSubscribedQ    = ( False & ),
            Wolfram`Chatbook`RelatedDocumentation          = ( $usageLimitFailure & )
        },
        Wolfram`AgentTools`Common`relatedDocumentation[ "Print Hello in Wolfram Language" ]
    ],
    _String? (StringContainsQ[ "usage limit" ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-UsageLimitMessage@@Tests/Tools.wlt:895,1-907,2"
]

VerificationTest[
    FailureQ @ $docUsageLimitResult,
    False,
    SameTest -> SameQ,
    TestID   -> "RelatedDocumentation-UsageLimitNotFailure@@Tests/Tools.wlt:909,1-914,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WolframContext (combined)*)

(* The combined tool calls both sub-tools; a subscribed user who is over their limit still gets a useful
   message rather than an internal failure. *)
VerificationTest[
    $wcUsageLimitResult = Block[
        {
            Wolfram`AgentTools`Common`chatbookVersionCheck = ( True & ),
            Wolfram`AgentTools`Common`llmKitSubscribedQ    = ( True & ),
            Wolfram`Chatbook`RelatedWolframAlphaResults    = ( $usageLimitFailure & ),
            Wolfram`Chatbook`RelatedDocumentation          = ( $usageLimitFailure & )
        },
        Wolfram`AgentTools`Common`relatedWolframContext[ "Print Hello in Wolfram Language" ]
    ],
    _String? (StringContainsQ[ "usage limit" ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframContext-UsageLimitMessage@@Tests/Tools.wlt:922,1-935,2"
]

VerificationTest[
    FailureQ @ $wcUsageLimitResult,
    False,
    SameTest -> SameQ,
    TestID   -> "RelatedWolframContext-UsageLimitNotFailure@@Tests/Tools.wlt:937,1-942,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*EnableLLMKit -> False (LLMKIT_ENABLED)*)

(* With LLMKit disabled, the combined WolframContext tool behaves as if the user is unsubscribed --
   it returns the Wolfram Language documentation but suppresses the Wolfram|Alpha section entirely,
   with NO "subscribe to LLMKit" warning injected. *)
VerificationTest[
    Module[ { result },
        result = environmentBlock[ "LLMKIT_ENABLED" -> "false",
            Block[
                {
                    Wolfram`AgentTools`Common`chatbookVersionCheck = ( True & ),
                    Wolfram`Chatbook`RelatedDocumentation          = ( "Some documentation." & )
                },
                Wolfram`AgentTools`Common`relatedWolframContext[ "population of France" ]
            ]
        ];
        {
            StringQ @ result,
            StringContainsQ[ result, "subscri", IgnoreCase -> True ],
            StringContainsQ[ result, "Some documentation." ]
        }
    ],
    { True, False, True },
    SameTest -> SameQ,
    TestID   -> "RelatedWolframContext-LLMKitDisabledNoWarning@@Tests/Tools.wlt:951,1-971,2"
]

(* Regression guard: a genuinely unsubscribed user (LLMKit still enabled) DOES get the subscription
   warning with the buy-now URL, so disabling must not be conflated with lacking a subscription. *)
(* cspell: ignore subscri *)
VerificationTest[
    Module[ { result },
        result = environmentBlock[ "LLMKIT_ENABLED" -> None,
            Block[
                {
                    Wolfram`AgentTools`Common`chatbookVersionCheck = ( True & ),
                    Wolfram`Chatbook`RelatedDocumentation          = ( "Some documentation." & ),
                    Wolfram`AgentTools`Common`getLLMKitInfo        =
                        ( <| "connected" -> True, "userHasSubscription" -> False, "buyNowUrl" -> "https://example.com/buy" |> & )
                },
                Wolfram`AgentTools`Common`relatedWolframContext[ "population of France" ]
            ]
        ];
        {
            StringQ @ result,
            StringContainsQ[ result, "subscri", IgnoreCase -> True ],
            StringContainsQ[ result, "https://example.com/buy" ]
        }
    ],
    { True, True, True },
    SameTest -> SameQ,
    TestID   -> "RelatedWolframContext-UnsubscribedStillWarns@@Tests/Tools.wlt:976,1-998,2"
]

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DocumentationProvided Option*)

(* Chatbook 2.7.2+ supports a "DocumentationProvided" option for RelatedWolframAlphaResults indicating that
   RelatedDocumentation results are provided separately. AgentTools only requires Chatbook 2.7.0, so the
   option must only be passed when the loaded Chatbook actually supports it, and only from the combined
   WolframContext tool, where documentation results actually accompany the Wolfram|Alpha results. *)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*documentationProvidedAvailableQ*)

(* The probe reports support when the option is present in the function's Options: *)
VerificationTest[
    Options[ mockRelatedWAResultsNew ] = { "DocumentationProvided" -> False, "MaxItems" -> Automatic };
    Wolfram`AgentTools`Common`documentationProvidedAvailableQ @ mockRelatedWAResultsNew,
    True,
    SameTest -> SameQ,
    TestID   -> "DocumentationProvidedAvailableQ-Supported@@Tests/Tools.wlt:1019,1-1025,2"
]

(* An older Chatbook without the option is reported as unsupported: *)
VerificationTest[
    Options[ mockRelatedWAResultsOld ] = { "MaxItems" -> Automatic };
    Wolfram`AgentTools`Common`documentationProvidedAvailableQ @ mockRelatedWAResultsOld,
    False,
    SameTest -> SameQ,
    TestID   -> "DocumentationProvidedAvailableQ-Unsupported@@Tests/Tools.wlt:1028,1-1034,2"
]

(* A Block-mocked RelatedWolframAlphaResults (as used elsewhere in this file) evaluates to a Function;
   the probe must safely report it as unsupported rather than leaking messages or errors: *)
VerificationTest[
    Wolfram`AgentTools`Common`documentationProvidedAvailableQ[ "mocked" & ],
    False,
    SameTest -> SameQ,
    TestID   -> "DocumentationProvidedAvailableQ-NonSymbol@@Tests/Tools.wlt:1038,1-1043,2"
]

(* The zero-argument form probes the Chatbook in use and returns a definite boolean: *)
VerificationTest[
    BooleanQ @ Wolfram`AgentTools`Common`documentationProvidedAvailableQ[ ],
    True,
    SameTest -> SameQ,
    TestID   -> "DocumentationProvidedAvailableQ-Boolean@@Tests/Tools.wlt:1046,1-1051,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*documentationProvidedOptions*)

(* Outside the combined WolframContext tool, no option is passed regardless of Chatbook support: *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`documentationProvidedAvailableQ = ( True & ) },
        Wolfram`AgentTools`Common`documentationProvidedOptions[ False ]
    ],
    { },
    SameTest -> SameQ,
    TestID   -> "DocumentationProvidedOptions-NotProvided@@Tests/Tools.wlt:1058,1-1065,2"
]

(* From the combined tool with a supporting Chatbook, the option is included: *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`documentationProvidedAvailableQ = ( True & ) },
        Wolfram`AgentTools`Common`documentationProvidedOptions[ True ]
    ],
    { "DocumentationProvided" -> True },
    SameTest -> SameQ,
    TestID   -> "DocumentationProvidedOptions-Supported@@Tests/Tools.wlt:1068,1-1075,2"
]

(* From the combined tool with an older Chatbook, the option is omitted: *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`documentationProvidedAvailableQ = ( False & ) },
        Wolfram`AgentTools`Common`documentationProvidedOptions[ True ]
    ],
    { },
    SameTest -> SameQ,
    TestID   -> "DocumentationProvidedOptions-Unsupported@@Tests/Tools.wlt:1078,1-1085,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Option Passing*)

(* The standalone WolframAlphaContext path provides no documentation, so even a supporting Chatbook
   must not receive the option there: *)
VerificationTest[
    $capturedWAArguments = Missing[ "NotCalled" ];
    Block[
        {
            Wolfram`AgentTools`Common`chatbookVersionCheck            = ( True & ),
            Wolfram`AgentTools`Common`documentationProvidedAvailableQ = ( True & ),
            Wolfram`Chatbook`RelatedWolframAlphaResults               =
                Function[ $capturedWAArguments = { ## }; "Some Wolfram|Alpha context." ]
        },
        Wolfram`AgentTools`Common`relatedWolframAlphaResults[ "population of France", "Error" ]
    ],
    "Some Wolfram|Alpha context.",
    SameTest -> SameQ,
    TestID   -> "DocumentationProvided-StandaloneResultUnchanged@@Tests/Tools.wlt:1093,1-1107,2"
]

VerificationTest[
    MemberQ[ $capturedWAArguments, "DocumentationProvided" -> _ ],
    False,
    SameTest -> SameQ,
    TestID   -> "DocumentationProvided-NotPassedStandalone@@Tests/Tools.wlt:1109,1-1114,2"
]

(* The combined WolframContext tool passes the option when the loaded Chatbook supports it: *)
VerificationTest[
    $capturedWAArguments = Missing[ "NotCalled" ];
    Block[
        {
            Wolfram`AgentTools`Common`chatbookVersionCheck            = ( True & ),
            Wolfram`AgentTools`Common`llmKitSubscribedQ               = ( True & ),
            Wolfram`AgentTools`Common`documentationProvidedAvailableQ = ( True & ),
            Wolfram`Chatbook`RelatedDocumentation                     = ( "Some documentation." & ),
            Wolfram`Chatbook`RelatedWolframAlphaResults               =
                Function[ $capturedWAArguments = { ## }; "Some Wolfram|Alpha context." ]
        },
        Wolfram`AgentTools`Common`relatedWolframContext[ "population of France" ]
    ],
    _String? (StringContainsQ[ "Some Wolfram|Alpha context." ]),
    SameTest -> MatchQ,
    TestID   -> "DocumentationProvided-CombinedResult@@Tests/Tools.wlt:1117,1-1133,2"
]

VerificationTest[
    MemberQ[ $capturedWAArguments, "DocumentationProvided" -> True ],
    True,
    SameTest -> SameQ,
    TestID   -> "DocumentationProvided-PassedFromCombined@@Tests/Tools.wlt:1135,1-1140,2"
]

(* The combined tool must not pass the option to an older Chatbook that does not support it: *)
VerificationTest[
    $capturedWAArguments = Missing[ "NotCalled" ];
    Block[
        {
            Wolfram`AgentTools`Common`chatbookVersionCheck            = ( True & ),
            Wolfram`AgentTools`Common`llmKitSubscribedQ               = ( True & ),
            Wolfram`AgentTools`Common`documentationProvidedAvailableQ = ( False & ),
            Wolfram`Chatbook`RelatedDocumentation                     = ( "Some documentation." & ),
            Wolfram`Chatbook`RelatedWolframAlphaResults               =
                Function[ $capturedWAArguments = { ## }; "Some Wolfram|Alpha context." ]
        },
        Wolfram`AgentTools`Common`relatedWolframContext[ "population of France" ]
    ];
    MemberQ[ $capturedWAArguments, "DocumentationProvided" -> _ ],
    False,
    SameTest -> SameQ,
    TestID   -> "DocumentationProvided-NotPassedUnsupported@@Tests/Tools.wlt:1143,1-1160,2"
]

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*TestReport*)

$allowExternal = ! StringQ @ Environment[ "GITHUB_ACTIONS" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $testReportTool = $DefaultMCPTools[ "TestReport" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "TestReport-GetTool@@Tests/Tools.wlt:1173,1-1178,2"
]

VerificationTest[
    $testResourceDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources" },
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "TestReport-TestResourceDirectory@@Tests/Tools.wlt:1180,1-1185,2"
]

VerificationTest[
    $testReportResult = $testReportTool @ <|
        "paths" -> FileNameJoin @ { $testResourceDirectory, "TestFile1.wlt" },
        "newKernel" -> $allowExternal
    |>,
    _String? (StringContainsQ[ "# Test Results Summary"~~__~~"TestFile1.wlt" ]),
    SameTest -> MatchQ,
    TestID   -> "TestReport-SingleFile@@Tests/Tools.wlt:1187,1-1195,2"
]

VerificationTest[
    $testReportResult = $testReportTool @ <|
        "paths" -> StringJoin[
            FileNameJoin @ { $testResourceDirectory, "TestFile1.wlt" },
            ", ",
            FileNameJoin @ { $testResourceDirectory, "TestFile2.wlt" }
        ],
        "newKernel" -> $allowExternal
    |>,
    _String? (StringContainsQ[ "# Test Results Summary"~~__~~"TestFile1.wlt"~~__~~"TestFile2.wlt" ]),
    SameTest -> MatchQ,
    TestID   -> "TestReport-MultipleFiles@@Tests/Tools.wlt:1197,1-1209,2"
]

VerificationTest[
    $testReportResult = $testReportTool @ <|
        "paths" -> $testResourceDirectory,
        "newKernel" -> $allowExternal
    |>,
    _String? (StringContainsQ[ "# Test Results Summary"~~__~~"TestFile1.wlt"~~__~~"TestFile2.wlt" ]),
    SameTest -> MatchQ,
    TestID   -> "TestReport-Directory@@Tests/Tools.wlt:1211,1-1219,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$mcpRoot*)

(* The subprocess started by the external RunProcess path runs in $mcpRoot. The .wlt
   file uses a relative path (FileExistsQ["marker.txt"]) that only resolves when the
   subprocess's CWD is the temporary root, which exercises the ProcessDirectory plumbing. *)
skipIfGitHubActions @ VerificationTest[
    Module[ { tmpDir, savedRoot, testFile, result, ok },
        tmpDir    = CreateDirectory[ ];
        savedRoot = Wolfram`AgentTools`Common`$mcpRoot;
        testFile  = FileNameJoin @ { tmpDir, "MarkerTest.wlt" };
        WithCleanup[
            Export[ FileNameJoin @ { tmpDir, "marker.txt" }, "ok", "Text" ];
            Export[
                testFile,
                "VerificationTest[ FileExistsQ[ \"marker.txt\" ], True, TestID -> \"MarkerFound\" ]",
                "Text"
            ];
            Wolfram`AgentTools`Common`$mcpRoot = tmpDir;
            result = $testReportTool @ <|
                "paths"     -> testFile,
                "newKernel" -> True
            |>;
            ok = StringQ @ result &&
                 StringContainsQ[ result, "**Overall Result** | Success" ],
            Wolfram`AgentTools`Common`$mcpRoot = savedRoot;
            DeleteDirectory[ tmpDir, DeleteContents -> True ]
        ];
        ok
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "TestReport-McpRootRelativePath@@Tests/Tools.wlt:1228,23-1255,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Cases*)

(* GH#65: Nonexistent path should produce TestFileNotFound, not an internal failure *)
VerificationTest[
    $testReportTool[ <| "paths" -> CreateUUID[] <> "/does/not/exist.wlt" |> ],
    Failure[ "AgentTools::TestFileNotFound", _Association ],
    { AgentTools::TestFileNotFound },
    SameTest -> MatchQ,
    TestID   -> "TestReport-NonexistentFile-GH#65@@Tests/Tools.wlt:1262,1-1268,2"
]

VerificationTest[
    $testReportTool[ <| "paths" -> CreateUUID[] <> "/does/not/exist.wlt" |> ],
    _? (FreeQ[ "AgentTools::Internal" ]),
    { AgentTools::TestFileNotFound },
    SameTest -> MatchQ,
    TestID   -> "TestReport-NoInternalFailure-GH#65@@Tests/Tools.wlt:1270,1-1276,2"
]

VerificationTest[
    $testReportTool @ <|
        "paths" -> StringJoin[
            FileNameJoin @ { $testResourceDirectory, "TestFile1.wlt" },
            ", " <> CreateUUID[] <> "/does/not/exist.wlt"
        ]
    |>,
    _? (FreeQ[ "AgentTools::Internal" ]),
    { AgentTools::TestFileNotFound },
    SameTest -> MatchQ,
    TestID   -> "TestReport-MixedValidInvalidPaths-GH#65@@Tests/Tools.wlt:1278,1-1289,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Properties*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Names*)
VerificationTest[
    AllTrue[
        $DefaultMCPTools,
        Function[ tool, StringQ @ tool[ "Name" ] ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "ToolProperties-AllHaveNames@@Tests/Tools.wlt:1298,1-1306,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Descriptions*)
VerificationTest[
    AllTrue[
        $DefaultMCPTools,
        Function[ tool, StringQ @ tool[ "Description" ] ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "ToolProperties-AllHaveDescriptions@@Tests/Tools.wlt:1311,1-1319,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Parameters*)
VerificationTest[
    AllTrue[
        $DefaultMCPTools,
        Function[ tool, ListQ @ tool[ "Parameters" ] ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "ToolProperties-AllHaveParameters@@Tests/Tools.wlt:1324,1-1332,2"
]
