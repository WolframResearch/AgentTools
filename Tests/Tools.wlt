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
    TestID   -> "DefaultMCPTools-IsAssociation"
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
    TestID   -> "DefaultMCPTools-Keys"
]

VerificationTest[
    AllTrue[ Values @ $DefaultMCPTools, MatchQ[ _LLMTool ] ],
    True,
    SameTest -> SameQ,
    TestID   -> "DefaultMCPTools-AllLLMTools"
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
    TestID   -> "ReadNotebook-GetTool"
]

VerificationTest[
    $exampleNotebook = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources", "document.nb" },
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-FindExampleFile"
]

VerificationTest[
    $readNotebookResult = $readNotebookTool[ <| "notebook" -> $exampleNotebook |> ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-BasicRead"
]

VerificationTest[
    (* Check for the presence of a Wolfram Language code block *)
    StringContainsQ[ $readNotebookResult, "\n```wl\n" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ReadNotebook-ContainsExpectedContent"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Cases*)
VerificationTest[
    $readNotebookTool[ <| "notebook" -> "nonexistent_file_12345.nb" |> ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-NonexistentFile"
]

(* A missing file is reported as such rather than being parsed as a NotebookObject specification. *)
VerificationTest[
    $readNotebookTool[ <| "notebook" -> "nonexistent_file_12345.nb" |> ],
    "File does not exist: nonexistent_file_12345.nb",
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-NonexistentFile-Message"
]

VerificationTest[
    $readNotebookTool[ <| "notebook" -> "NotebookObject[oops]" |> ],
    _String? (StringStartsQ[ "Invalid notebook specification" ]),
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-InvalidNotebookObjectSpec"
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
    TestID   -> "ReadNotebook-URL-NotANotebook"
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
    TestID   -> "WriteNotebook-GetTool"
]

VerificationTest[
    $tempNotebookFile = FileNameJoin[ { $TemporaryDirectory, "AgentToolsTest_" <> CreateUUID[ ] <> ".nb" } ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-CreateTempPath"
]

VerificationTest[
    $writeNotebookResult = $writeNotebookTool[ <|
        "markdown" -> "# Test Notebook\n\nThis is a test paragraph.\n\n```wl\n1 + 1\n```",
        "file" -> $tempNotebookFile,
        "overwrite" -> False
    |> ],
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-BasicWrite"
]

VerificationTest[
    FileExistsQ @ $tempNotebookFile,
    True,
    SameTest -> SameQ,
    TestID   -> "WriteNotebook-FileExists"
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
    TestID   -> "WriteNotebook-NoOverwriteExisting"
]

VerificationTest[
    $writeNotebookTool[ <|
        "markdown" -> "# Overwritten Notebook",
        "file" -> $tempNotebookFile,
        "overwrite" -> True
    |> ],
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-OverwriteExisting"
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
    TestID   -> "WriteNotebook-MissingDirectory-Setup-GH#200"
]

VerificationTest[
    $writeNotebookTool[ <|
        "markdown"  -> "# Created In New Directory",
        "file"      -> $missingDirNotebookFile,
        "overwrite" -> False
    |> ],
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-MissingDirectory-CreatesPath-GH#200"
]

VerificationTest[
    FileExistsQ @ $missingDirNotebookFile,
    True,
    SameTest -> SameQ,
    TestID   -> "WriteNotebook-MissingDirectory-FileExists-GH#200"
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
    TestID   -> "WriteNotebook-Cleanup"
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
    TestID   -> "WriteNotebook-CloudOverride-Parameters"
]

VerificationTest[
    $cloudWriteNotebookTool[ "Description" ],
    _String? (StringContainsQ[ "cloud object" ]),
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-CloudOverride-Description"
]

(* The default tool is untouched by the override. *)
VerificationTest[
    $DefaultMCPTools[ "WriteNotebook" ][ "Parameters" ][[ All, 1 ]],
    { "file", "overwrite", "markdown" },
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-CloudOverride-DefaultUnchanged"
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
    TestID   -> "WriteNotebook-Cloud-BasicWrite"
]

$cloudNotebookTest @ VerificationTest[
    FileExistsQ @ CloudObject @ $cloudNotebookResult,
    True,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-Cloud-ObjectExists"
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
    TestID   -> "WriteNotebook-Cloud-DefaultPrivate"
]

(* ReadNotebook reads the cloud object back from its URL. *)
$cloudNotebookTest @ VerificationTest[
    $readNotebookTool[ <| "notebook" -> $cloudNotebookResult |> ],
    _String? (StringContainsQ[ "# Cloud Test Notebook" ]),
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-Cloud-URL"
]

$cloudNotebookTest @ VerificationTest[
    $cloudWriteNotebookTool[ <| "markdown" -> "# Another Test", "path" -> $cloudNotebookPath |> ],
    _String? (StringStartsQ[ "File already exists" ]),
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-Cloud-NoOverwriteExisting"
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
    TestID   -> "WriteNotebook-Cloud-OverwriteExisting"
]

$cloudNotebookTest @ VerificationTest[
    cloudNotebookPermissions[ $cloudNotebookResult, cloudNotebookPublicQ ],
    _? cloudNotebookPublicQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-Cloud-PublicPermissions"
]

(* Only markdown is required: the omitted parameters arrive as Missing["NoInput"] and a new anonymous
   cloud object is used. *)
$cloudNotebookTest @ VerificationTest[
    $cloudAnonymousNotebook = $cloudWriteNotebookTool[ <| "markdown" -> "# Anonymous Notebook" |> ],
    url_String /; StringStartsQ[ url, "http" ] && StringFreeQ[ url, "/Claude/" ],
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-Cloud-AnonymousObject"
]

$cloudNotebookTest @ VerificationTest[
    $readNotebookTool[ <| "notebook" -> $cloudAnonymousNotebook |> ],
    _String? (StringContainsQ[ "# Anonymous Notebook" ]),
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-Cloud-AnonymousURL"
]

$cloudNotebookTest @ VerificationTest[
    DeleteObject /@ { CloudObject @ $cloudNotebookResult, CloudObject @ $cloudAnonymousNotebook };
    FileExistsQ /@ { CloudObject @ $cloudNotebookResult, CloudObject @ $cloudAnonymousNotebook },
    { False, False },
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-Cloud-Cleanup"
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
    TestID   -> "WolframLanguageEvaluator-GetTool"
]

VerificationTest[
    $evalResult1 = $evaluatorTool[ <| "code" -> "1 + 1" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-BasicEval"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult1, "2" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-CorrectResult"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult1, "Out[" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-HasOutLabel"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Time Constraint*)
VerificationTest[
    $evalResult2 = $evaluatorTool[ <| "code" -> "Range[5]", "timeConstraint" -> 30 |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-WithTimeConstraint"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult2, "{1, 2, 3, 4, 5}" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-RangeResult"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Complex Expressions*)
VerificationTest[
    $evalResult3 = $evaluatorTool[ <| "code" -> "Table[n^2, {n, 1, 4}]" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-TableExpression"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult3, "{1, 4, 9, 16}" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-TableResult"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*String Output*)
VerificationTest[
    $evalResult4 = $evaluatorTool[ <| "code" -> "StringJoin[\"Hello\", \" \", \"World\"]" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-StringExpression"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult4, "Hello World" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-StringResult"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Print Output*)
VerificationTest[
    $evalResultPrint1 = $evaluatorTool[ <| "code" -> "Print[\"Hello from Print\"]; 42" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-PrintBasic"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResultPrint1, "Hello from Print" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-PrintOutputCaptured"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResultPrint1, "42" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-PrintResultIncluded"
]

VerificationTest[
    $evalResultPrint2 = $evaluatorTool[ <| "code" -> "Print[\"First\"]; Print[\"Second\"]; Print[\"Third\"]; \"Done\"" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-MultiplePrints"
]

VerificationTest[
    With[ { text = extractToolText @ $evalResultPrint2 },
        StringContainsQ[ text, "First" ] && StringContainsQ[ text, "Second" ] && StringContainsQ[ text, "Third" ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-MultiplePrintsCaptured"
]

VerificationTest[
    $evalResultPrint3 = $evaluatorTool[ <| "code" -> "Do[Print[i], {i, 3}]; \"Complete\"" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-PrintInLoop"
]

VerificationTest[
    With[ { text = extractToolText @ $evalResultPrint3 },
        StringContainsQ[ text, "1" ] && StringContainsQ[ text, "2" ] && StringContainsQ[ text, "3" ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-PrintInLoopCaptured"
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
    TestID   -> "WolframLanguageEvaluator-GenuineMessage"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResultMsg1, "First::nofirst" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-GenuineMessageCaptured"
]

(* Messages quieted by the evaluated code do not appear in the tool result: *)
VerificationTest[
    StringFreeQ[ extractToolText @ $evaluatorTool[ <| "code" -> "Quiet[First[{}]]" |> ], "First::nofirst" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-QuietedMessageNotReported"
]

(* Messages suppressed by kernel-internal mechanisms do not appear in the tool result: *)
VerificationTest[
    StringFreeQ[
        extractToolText @ $evaluatorTool[ <| "code" -> "Internal`DeactivateMessages[First[{}], First::nofirst]" |> ],
        "First::nofirst"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-DeactivatedMessageNotReported"
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
    TestID   -> "WolframLanguageEvaluator-InternallySuppressedMessages"
]

VerificationTest[
    StringFreeQ[ $evalResultMsg2, { "Message text not found", "::ivar", "General::messages" } ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-InternallySuppressedMessagesNotReported"
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
    TestID   -> "WolframLanguageEvaluator-UIPathVersionCheck"
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
    TestID   -> "WolframLanguageEvaluator-UIPathVersionCheckFailure"
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
    TestID   -> "WolframAlpha-GetTool"
]

VerificationTest[
    $waResult = $wolframAlphaTool[ <| "query" -> "population of France" |> ],
    _String? StringQ | KeyValuePattern[ "Content" -> { __Association } ],
    SameTest -> MatchQ,
    TestID   -> "WolframAlpha-BasicQuery"
]

VerificationTest[
    $waResultString =
        If[ StringQ @ $waResult,
            $waResult,
            StringJoin @ Select[ $waResult[[ "Content", All, "text" ]], StringQ ]
        ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "WolframAlpha-ResultString"
]

VerificationTest[
    StringLength @ $waResultString > 0,
    True,
    SameTest -> SameQ,
    TestID   -> "WolframAlpha-NonEmptyResult"
]

(* TODO: multiple queries aren't supported until the next Chatbook paclet update *)
(* VerificationTest[
    $waResult = $wolframAlphaTool[ <| "query" -> "population of France\tpopulation of Germany" |> ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "WolframAlpha-MultipleQueries"
]

VerificationTest[
    StringCount[ $waResult, "<result query=" ],
    2,
    SameTest -> SameQ,
    TestID   -> "WolframAlpha-MultipleQueriesResultCount"
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
    TestID   -> "WolframLanguageContext-GetTool"
]

skipIfGitHubActions @ VerificationTest[
    $wlContextResult = $wlContextTool[ <| "context" -> "How to create a list of prime numbers in Wolfram Language" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageContext-BasicQuery"
]

skipIfGitHubActions @ VerificationTest[
    StringLength[ extractToolText @ $wlContextResult ] > 0,
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageContext-NonEmptyResult"
]

skipIfGitHubActions @ VerificationTest[
    StringContainsQ[ extractToolText @ $wlContextResult, "Prime" | "prime" | "Table" | "Range", IgnoreCase -> True ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageContext-RelevantContent"
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
    TestID   -> "WolframAlphaContext-GetTool"
]

skipIfGitHubActions @ VerificationTest[
    $waContextResult = $waContextTool[ <| "context" -> "What is the distance from Earth to Mars" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframAlphaContext-BasicQuery"
]

skipIfGitHubActions @ VerificationTest[
    StringLength[ extractToolText @ $waContextResult ] > 0,
    True,
    SameTest -> SameQ,
    TestID   -> "WolframAlphaContext-NonEmptyResult"
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
    TestID   -> "WolframContext-GetTool"
]

skipIfGitHubActions @ VerificationTest[
    $wolframContextResult = $wolframContextTool[ <| "context" -> "How to compute derivatives symbolically" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframContext-BasicQuery"
]

skipIfGitHubActions @ VerificationTest[
    StringLength[ extractToolText @ $wolframContextResult ] > 0,
    True,
    SameTest -> SameQ,
    TestID   -> "WolframContext-NonEmptyResult"
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
    TestID   -> "RelatedWolframAlphaResults-UsageLimitMessage"
]

(* The service's own error message is surfaced to the agent. *)
VerificationTest[
    StringContainsQ[ $waUsageLimitResult, "credits-per-month-limit-exceeded" ],
    True,
    SameTest -> SameQ,
    TestID   -> "RelatedWolframAlphaResults-UsageLimitIncludesServiceMessage"
]

(* It is NOT a Failure, so the MCP layer will not flag it as an error or emit a bug report. *)
VerificationTest[
    FailureQ @ $waUsageLimitResult,
    False,
    SameTest -> SameQ,
    TestID   -> "RelatedWolframAlphaResults-UsageLimitNotFailure"
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
    TestID   -> "RelatedWolframAlphaResults-UsageLimitLevel"
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
    TestID   -> "RelatedWolframAlphaResults-NormalResultUnchanged"
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
    TestID   -> "RelatedDocumentation-UsageLimitMessage"
]

VerificationTest[
    FailureQ @ $docUsageLimitResult,
    False,
    SameTest -> SameQ,
    TestID   -> "RelatedDocumentation-UsageLimitNotFailure"
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
    TestID   -> "RelatedWolframContext-UsageLimitMessage"
]

VerificationTest[
    FailureQ @ $wcUsageLimitResult,
    False,
    SameTest -> SameQ,
    TestID   -> "RelatedWolframContext-UsageLimitNotFailure"
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
    TestID   -> "RelatedWolframContext-LLMKitDisabledNoWarning"
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
    TestID   -> "RelatedWolframContext-UnsubscribedStillWarns"
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
    TestID   -> "DocumentationProvidedAvailableQ-Supported"
]

(* An older Chatbook without the option is reported as unsupported: *)
VerificationTest[
    Options[ mockRelatedWAResultsOld ] = { "MaxItems" -> Automatic };
    Wolfram`AgentTools`Common`documentationProvidedAvailableQ @ mockRelatedWAResultsOld,
    False,
    SameTest -> SameQ,
    TestID   -> "DocumentationProvidedAvailableQ-Unsupported"
]

(* A Block-mocked RelatedWolframAlphaResults (as used elsewhere in this file) evaluates to a Function;
   the probe must safely report it as unsupported rather than leaking messages or errors: *)
VerificationTest[
    Wolfram`AgentTools`Common`documentationProvidedAvailableQ[ "mocked" & ],
    False,
    SameTest -> SameQ,
    TestID   -> "DocumentationProvidedAvailableQ-NonSymbol"
]

(* The zero-argument form probes the Chatbook in use and returns a definite boolean: *)
VerificationTest[
    BooleanQ @ Wolfram`AgentTools`Common`documentationProvidedAvailableQ[ ],
    True,
    SameTest -> SameQ,
    TestID   -> "DocumentationProvidedAvailableQ-Boolean"
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
    TestID   -> "DocumentationProvidedOptions-NotProvided"
]

(* From the combined tool with a supporting Chatbook, the option is included: *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`documentationProvidedAvailableQ = ( True & ) },
        Wolfram`AgentTools`Common`documentationProvidedOptions[ True ]
    ],
    { "DocumentationProvided" -> True },
    SameTest -> SameQ,
    TestID   -> "DocumentationProvidedOptions-Supported"
]

(* From the combined tool with an older Chatbook, the option is omitted: *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`documentationProvidedAvailableQ = ( False & ) },
        Wolfram`AgentTools`Common`documentationProvidedOptions[ True ]
    ],
    { },
    SameTest -> SameQ,
    TestID   -> "DocumentationProvidedOptions-Unsupported"
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
    TestID   -> "DocumentationProvided-StandaloneResultUnchanged"
]

VerificationTest[
    MemberQ[ $capturedWAArguments, "DocumentationProvided" -> _ ],
    False,
    SameTest -> SameQ,
    TestID   -> "DocumentationProvided-NotPassedStandalone"
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
    TestID   -> "DocumentationProvided-CombinedResult"
]

VerificationTest[
    MemberQ[ $capturedWAArguments, "DocumentationProvided" -> True ],
    True,
    SameTest -> SameQ,
    TestID   -> "DocumentationProvided-PassedFromCombined"
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
    TestID   -> "DocumentationProvided-NotPassedUnsupported"
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
    TestID   -> "TestReport-GetTool"
]

VerificationTest[
    $testResourceDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources" },
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "TestReport-TestResourceDirectory"
]

VerificationTest[
    $testReportResult = $testReportTool @ <|
        "paths" -> FileNameJoin @ { $testResourceDirectory, "TestFile1.wlt" },
        "newKernel" -> $allowExternal
    |>,
    _String? (StringContainsQ[ "# Test Results Summary"~~__~~"TestFile1.wlt" ]),
    SameTest -> MatchQ,
    TestID   -> "TestReport-SingleFile"
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
    TestID   -> "TestReport-MultipleFiles"
]

VerificationTest[
    $testReportResult = $testReportTool @ <|
        "paths" -> $testResourceDirectory,
        "newKernel" -> $allowExternal
    |>,
    _String? (StringContainsQ[ "# Test Results Summary"~~__~~"TestFile1.wlt"~~__~~"TestFile2.wlt" ]),
    SameTest -> MatchQ,
    TestID   -> "TestReport-Directory"
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
    TestID   -> "TestReport-McpRootRelativePath"
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
    TestID   -> "TestReport-NonexistentFile-GH#65"
]

VerificationTest[
    $testReportTool[ <| "paths" -> CreateUUID[] <> "/does/not/exist.wlt" |> ],
    _? (FreeQ[ "AgentTools::Internal" ]),
    { AgentTools::TestFileNotFound },
    SameTest -> MatchQ,
    TestID   -> "TestReport-NoInternalFailure-GH#65"
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
    TestID   -> "TestReport-MixedValidInvalidPaths-GH#65"
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
    TestID   -> "ToolProperties-AllHaveNames"
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
    TestID   -> "ToolProperties-AllHaveDescriptions"
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
    TestID   -> "ToolProperties-AllHaveParameters"
]
