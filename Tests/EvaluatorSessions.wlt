(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/EvaluatorSessions.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/EvaluatorSessions.wlt:11,1-16,2"
]

(* Helper to extract text from tool results (handles both string and structured content) *)
extractToolText[ str_String ] := str;
extractToolText[ as_Association ] /; KeyExistsQ[ as, "Content" ] :=
    StringJoin @ Cases[ as[ "Content" ], KeyValuePattern[ { "type" -> "text", "text" -> t_String } ] :> t ];
extractToolText[ _ ] := "";

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Options and Schema*)
VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions[ "WolframLanguageEvaluator" ],
    KeyValuePattern @ {
        "MaxSessionCount" -> 100,
        "MaxSessionBytes" -> _Integer,
        "MaxSessionAge"   -> _Quantity
    },
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-SessionLimits@@Tests/EvaluatorSessions.wlt:30,1-39,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        {
            Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "MaxSessionCount" ],
            Head @ Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "MaxSessionAge" ]
        }
    ],
    { 100, Quantity },
    SameTest -> MatchQ,
    TestID   -> "ToolOptionValue-SessionLimitDefaults@@Tests/EvaluatorSessions.wlt:41,1-51,2"
]

VerificationTest[
    StringContainsQ[
        ToString[ Wolfram`AgentTools`Server`Shared`Private`toolSchema @ $DefaultMCPTools[ "WolframLanguageEvaluator" ], InputForm ],
        "session"
    ],
    True,
    TestID -> "Schema-HasSessionParameter@@Tests/EvaluatorSessions.wlt:53,1-60,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Session ID Generation and Validation*)
VerificationTest[
    StringMatchQ[ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`createSessionID[ ], LetterCharacter ~~ WordCharacter.. ],
    True,
    TestID -> "CreateSessionID-ValidContextComponent@@Tests/EvaluatorSessions.wlt:65,1-69,2"
]

VerificationTest[
    StringLength @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`createSessionID[ ],
    8,
    TestID -> "CreateSessionID-Length@@Tests/EvaluatorSessions.wlt:71,1-75,2"
]

VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`validSessionIDQ /@ { "Abc123", "x", "Z9z9z9z9" },
    { True, True, True },
    TestID -> "ValidSessionIDQ-Accepts@@Tests/EvaluatorSessions.wlt:77,1-81,2"
]

VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`validSessionIDQ /@ { "1abc", "a b", "a`b", "", "has-dash", 123, StringJoin @ ConstantArray[ "a", 65 ] },
    { False, False, False, False, False, False, False },
    TestID -> "ValidSessionIDQ-Rejects@@Tests/EvaluatorSessions.wlt:83,1-87,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Session Paths*)
VerificationTest[
    StringEndsQ[ First @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionsPath[ ], "Sessions" ],
    True,
    TestID -> "SessionsPath-EndsWithSessions@@Tests/EvaluatorSessions.wlt:92,1-96,2"
]

VerificationTest[
    StringEndsQ[ First @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionFile[ "Abc123" ], "Sessions/Abc123.mx" ],
    True,
    TestID -> "SessionFile-Path@@Tests/EvaluatorSessions.wlt:98,1-102,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*toAgeCutoff*)
VerificationTest[
    Head @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`toAgeCutoff[ Quantity[ 1, "Months" ] ],
    DateObject,
    TestID -> "ToAgeCutoff-Quantity@@Tests/EvaluatorSessions.wlt:107,1-111,2"
]

VerificationTest[
    Head @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`toAgeCutoff[ 2592000 ],
    DateObject,
    TestID -> "ToAgeCutoff-Number@@Tests/EvaluatorSessions.wlt:113,1-117,2"
]

VerificationTest[
    {
        Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`toAgeCutoff[ None ],
        Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`toAgeCutoff[ Infinity ],
        Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`toAgeCutoff[ True ]
    },
    { None, None, None },
    TestID -> "ToAgeCutoff-DisabledAndCatchAll@@Tests/EvaluatorSessions.wlt:119,1-127,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*sessionsOverByteBudget*)
VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionsOverByteBudget[ { }, 100 ],
    { },
    TestID -> "SessionsOverByteBudget-Empty@@Tests/EvaluatorSessions.wlt:132,1-136,2"
]

VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionsOverByteBudget[ { "a", "b" }, "not an integer" ],
    { },
    TestID -> "SessionsOverByteBudget-NonIntegerBudgetDisabled@@Tests/EvaluatorSessions.wlt:138,1-142,2"
]

VerificationTest[
    Module[ { root, files, sz, result },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsBytes_" <> CreateUUID[ ] };
        CreateDirectory[ root, CreateIntermediateDirectories -> True ];
        files = Table[
            With[ { f = FileNameJoin @ { root, "b" <> ToString[ i ] <> ".mx" } },
                Export[ f, ConstantArray[ 0, 500 ], "MX" ]; f
            ],
            { i, 3 }
        ];
        sz     = FileByteCount @ First @ files;
        (* Budget ~1.5 files -> drop the 2 oldest, keep the newest *)
        result = Length @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionsOverByteBudget[ files, sz + Quotient[ sz, 2 ] ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        result
    ],
    2,
    TestID -> "SessionsOverByteBudget-DropsOldest@@Tests/EvaluatorSessions.wlt:144,1-162,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*cleanupSessions*)
VerificationTest[
    Module[ { root, sDir, result },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsCleanup_" <> CreateUUID[ ] };
        sDir = FileNameJoin @ { root, "Sessions" };
        CreateDirectory[ sDir, CreateIntermediateDirectories -> True ];
        Do[ Export[ FileNameJoin @ { sDir, "s" <> ToString[ i ] <> ".mx" }, i, "MX" ], { i, 5 } ];
        Block[
            {
                Wolfram`AgentTools`Common`$rootPath = root,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
            },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cleanupSessions[ 3, Infinity, None ]
        ];
        result = Length @ FileNames[ "*.mx", sDir ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        result
    ],
    3,
    TestID -> "CleanupSessions-CountLimitKeepsNewest@@Tests/EvaluatorSessions.wlt:167,1-186,2"
]

VerificationTest[
    Module[ { root, sDir, result },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsCleanup_" <> CreateUUID[ ] };
        sDir = FileNameJoin @ { root, "Sessions" };
        CreateDirectory[ sDir, CreateIntermediateDirectories -> True ];
        Do[ Export[ FileNameJoin @ { sDir, "keep" <> ToString[ i ] <> ".mx" }, i, "MX" ], { i, 3 } ];
        Block[
            {
                Wolfram`AgentTools`Common`$rootPath = root,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = "keep2"
            },
            (* maxCount 0 deletes every non-current file; the current session must survive *)
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cleanupSessions[ 0, Infinity, None ]
        ];
        result = FileBaseName /@ FileNames[ "*.mx", sDir ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        result
    ],
    { "keep2" },
    SameTest -> MatchQ,
    TestID   -> "CleanupSessions-CurrentSessionSurvives@@Tests/EvaluatorSessions.wlt:188,1-209,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*appendSessionInfo and sessionInfoText*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionStatus = "resumed" },
        StringContainsQ[ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionInfoText[ "Abc123" ], "session=\"Abc123\"" ]
    ],
    True,
    TestID -> "SessionInfoText-ContainsId@@Tests/EvaluatorSessions.wlt:214,1-220,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionStatus = "reused" },
        StringContainsQ[ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionInfoText[ "Abc123" ], "No saved state" ]
    ],
    True,
    TestID -> "SessionInfoText-ReusedNotice@@Tests/EvaluatorSessions.wlt:222,1-228,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionStatus = "new" },
        StringContainsQ[ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionInfoText[ "Abc123" ], "No saved state" ]
    ],
    False,
    TestID -> "SessionInfoText-NewHasNoReuseNotice@@Tests/EvaluatorSessions.wlt:230,1-236,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionStatus = "resumedNewKernel" },
        With[ { text = Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionInfoText[ "Abc123" ] },
            {
                StringContainsQ[ text, "kernel process for this session has changed" ],
                StringContainsQ[ text, "session=\"Abc123\"" ]
            }
        ]
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "SessionInfoText-ResumedNewKernelNotice@@Tests/EvaluatorSessions.wlt:238,1-250,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionStatus = "resumed" },
        StringContainsQ[ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionInfoText[ "Abc123" ], "kernel process" ]
    ],
    False,
    TestID -> "SessionInfoText-SameKernelResumeHasNoKernelNotice@@Tests/EvaluatorSessions.wlt:252,1-258,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionStatus = "new" },
        Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`appendSessionInfo[
            <| "Content" -> { <| "type" -> "text", "text" -> "hi" |> } |>,
            "Abc123"
        ]
    ],
    KeyValuePattern[
        "Content" -> {
            <| "type" -> "text", "text" -> "hi" |>,
            <| "type" -> "text", "text" -> _String? (StringContainsQ[ #, "Abc123" ] &) |>
        }
    ],
    SameTest -> MatchQ,
    TestID   -> "AppendSessionInfo-AppendsToContent@@Tests/EvaluatorSessions.wlt:260,1-275,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionStatus = "new" },
        KeyExistsQ[
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`appendSessionInfo[
                <| "Content" -> { <| "type" -> "text", "text" -> "x" |> }, "_meta" -> <| "notebookUrl" -> "u" |> |>,
                "Abc123"
            ],
            "_meta"
        ]
    ],
    True,
    TestID -> "AppendSessionInfo-PreservesMeta@@Tests/EvaluatorSessions.wlt:277,1-289,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionStatus = "new" },
        MatchQ[
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`appendSessionInfo[ "plain text", "Abc123" ],
            _String? (StringContainsQ[ #, "plain text" ] && StringContainsQ[ #, "Abc123" ] &)
        ]
    ],
    True,
    TestID -> "AppendSessionInfo-String@@Tests/EvaluatorSessions.wlt:291,1-300,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*syncEvalKernelLine*)
(* For in-process methods the "Line" option already drives the In/Out label, so syncEvalKernelLine is a
   no-op (it only does work for the "Local" method, which runs the user's code in a separate subkernel). *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> }, (* Method defaults to "Session" *)
        Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`syncEvalKernelLine[ 5 ]
    ],
    Null,
    TestID -> "SyncEvalKernelLine-NoOpForInProcess@@Tests/EvaluatorSessions.wlt:307,1-313,2"
]

VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`syncEvalKernelLineSafe[ "not an integer" ],
    Null,
    TestID -> "SyncEvalKernelLineSafe-IgnoresNonInteger@@Tests/EvaluatorSessions.wlt:315,1-319,2"
]

(* Chatbook 2.7.28+ applies the "Line" option in the "Local" eval kernel itself, so there is nothing to sync. *)
VerificationTest[
    Module[ { synced = False },
        Block[
            {
                Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |>,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`evaluateInLocalKernel0 =
                    Function[ Null, synced = True, HoldAllComplete ]
            },
            {
                Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookLinePropertyQ = True & },
                    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`syncEvalKernelLine[ 5 ];
                    synced
                ],
                Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookLinePropertyQ = False & },
                    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`syncEvalKernelLine[ 5 ];
                    synced
                ]
            }
        ]
    ],
    { False, True },
    SameTest -> MatchQ,
    TestID   -> "SyncEvalKernelLine-NoOpWithChatbookLineProperty@@Tests/EvaluatorSessions.wlt:322,1-345,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Line Numbers*)
(* Chatbook 2.7.28+ evaluates each top-level input of the code with its own line number and reports the line number
   for the next input as the "Line" property; see the Line Numbers section of Kernel/Tools/WolframLanguageEvaluator.wl.
   Chatbook is mocked here, so these don't depend on the installed version. *)
VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookLinePropertyQ /@
        { "2.7.27", "2.7.28", "2.7.29", "2.8.0", "3.0.0", $Failed, None },
    { False, True, True, True, True, False, False },
    SameTest -> MatchQ,
    TestID   -> "ChatbookLinePropertyQ-VersionGate@@Tests/EvaluatorSessions.wlt:353,1-359,2"
]

VerificationTest[
    BooleanQ @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookLinePropertyQ[ ],
    True,
    TestID -> "ChatbookLinePropertyQ-LoadedChatbook@@Tests/EvaluatorSessions.wlt:361,1-365,2"
]

(* The session's line counter numbers the first input and continues at the line number Chatbook reports, which
   is requested alongside the property the caller asked for and then dropped from the result. *)
VerificationTest[
    Module[ { calls = { } },
        Block[
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$line = 7,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookLinePropertyQ = True &,
                Wolfram`Chatbook`WolframLanguageToolEvaluate = Function[
                    AppendTo[ calls, { #2, Lookup[ { ##3 }, "Line" ] } ];
                    <| "String" -> "Out[7]= 2\n\nOut[8]= 4", "Line" -> 9 |>
                ]
            },
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookToolEvaluate[ "1+1\n2+2", "String", 10 ],
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$line,
                calls
            }
        ]
    ],
    { "Out[7]= 2\n\nOut[8]= 4", 9, { { { "String", "Line" }, 7 } } },
    SameTest -> MatchQ,
    TestID   -> "ChatbookToolEvaluate-ContinuesAtReportedLine@@Tests/EvaluatorSessions.wlt:369,1-390,2"
]

VerificationTest[
    Module[ { calls = { } },
        Block[
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$line = 2,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookLinePropertyQ = True &,
                Wolfram`Chatbook`WolframLanguageToolEvaluate = Function[
                    AppendTo[ calls, #2 ];
                    <| "String" -> "Out[2]= 4\n\nOut[3]= 6", "Result" -> HoldForm[ 6 ], "Line" -> 4 |>
                ]
            },
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookToolEvaluate[ "4\n6", { "String", "Result" }, 10 ],
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$line,
                calls
            }
        ]
    ],
    {
        <| "String" -> "Out[2]= 4\n\nOut[3]= 6", "Result" -> HoldForm[ 6 ] |>,
        4,
        { { "String", "Result", "Line" } }
    },
    SameTest -> MatchQ,
    TestID   -> "ChatbookToolEvaluate-ContinuesAtReportedLine-PropertyList@@Tests/EvaluatorSessions.wlt:392,1-417,2"
]

(* Without a reported line number (e.g. the eval kernel quit, or the evaluation failed), the counter advances by
   one as it did before. *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$line = 7,
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookLinePropertyQ = True &,
            Wolfram`Chatbook`WolframLanguageToolEvaluate =
                Function[ <| "String" -> "General::quit", "Line" -> Missing[ "NotAvailable" ] |> ]
        },
        {
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookToolEvaluate[ "Quit[]", "String", 10 ],
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$line,
            Block[ { Wolfram`Chatbook`WolframLanguageToolEvaluate = Function[ Failure[ "Test", <| |> ] ] },
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookToolEvaluate[ "1", "String", 10 ]
            ],
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$line
        }
    ],
    { "General::quit", 8, Failure[ "Test", <| |> ], 9 },
    SameTest -> MatchQ,
    TestID   -> "ChatbookToolEvaluate-NoReportedLine@@Tests/EvaluatorSessions.wlt:421,1-441,2"
]

(* Older Chatbook versions don't support the "Line" property, so it isn't requested. *)
VerificationTest[
    Module[ { calls = { } },
        Block[
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$line = 7,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookLinePropertyQ = False &,
                Wolfram`Chatbook`WolframLanguageToolEvaluate = Function[ AppendTo[ calls, #2 ]; "Out[7]= 4" ]
            },
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookToolEvaluate[ "2+2", "String", 10 ],
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$line,
                calls
            }
        ]
    ],
    { "Out[7]= 4", 8, { "String" } },
    SameTest -> MatchQ,
    TestID   -> "ChatbookToolEvaluate-WithoutLineProperty@@Tests/EvaluatorSessions.wlt:444,1-462,2"
]

(* Session bookkeeping in the "Local" eval kernel must not use up a line number: with Chatbook 2.7.28+ it is
   evaluated with "Line" -> None, which also keeps it out of the In/Out history, and before that the line number
   was rolled back afterward. *)
VerificationTest[
    {
        Block[
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookLinePropertyQ = True &,
                Wolfram`Chatbook`WolframLanguageToolEvaluate = HoldComplete
            },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`localKernelEvaluate[ 1 + 1 ]
        ],
        Block[
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookLinePropertyQ = False &,
                Wolfram`Chatbook`WolframLanguageToolEvaluate = HoldComplete
            },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`localKernelEvaluate[ 1 + 1 ]
        ]
    },
    {
        HoldComplete[ HoldComplete[ 1 + 1 ], "Result", "Line" -> None, "Method" -> "Local" ],
        HoldComplete[ HoldComplete[ WithCleanup[ 1 + 1, $Line-- ] ], "Result", "Method" -> "Local" ]
    },
    SameTest -> SameQ,
    TestID   -> "LocalKernelEvaluate-DoesNotUseLineNumber@@Tests/EvaluatorSessions.wlt:467,1-490,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*enterSessionContextInKernel*)
(* Continuing a session restores the context state captured by the last save instead of resetting it,
   so $ContextPath additions made by the session's own evaluations survive across calls. *)
VerificationTest[
    Internal`InheritedBlock[ { $Context, $ContextPath, $ContextAliases },
        Block[
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionInfo = <|
                    "SessionID"       -> "UnitCtxA",
                    "KernelSessionID" -> 0,
                    "$Context"        -> "Sessions`UnitCtxA`",
                    "$ContextPath"    -> { "UnitCtxExtra`", "Sessions`UnitCtxA`", "System`" },
                    "$ContextAliases" -> <| |>
                |>
            },
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`enterSessionContextInKernel[ "UnitCtxA" ],
                $Context,
                MemberQ[ $ContextPath, "UnitCtxExtra`" ]
            }
        ]
    ],
    { Null, "Sessions`UnitCtxA`", True },
    SameTest -> MatchQ,
    TestID   -> "EnterSessionContextInKernel-RestoresSavedContextState@@Tests/EvaluatorSessions.wlt:497,1-519,2"
]

(* Missing or foreign kernel-side state (e.g. the eval kernel restarted between calls) is reported as
   $Failed so the caller can fall back to resuming from the session file. *)
VerificationTest[
    {
        Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionInfo = $Failed },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`enterSessionContextInKernel[ "UnitCtxB" ]
        ],
        Block[
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionInfo = <|
                    "SessionID"       -> "SomeOtherSession",
                    "$Context"        -> "Sessions`SomeOtherSession`",
                    "$ContextPath"    -> { "Sessions`SomeOtherSession`", "System`" },
                    "$ContextAliases" -> <| |>
                |>
            },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`enterSessionContextInKernel[ "UnitCtxB" ]
        ]
    },
    { $Failed, $Failed },
    SameTest -> MatchQ,
    TestID   -> "EnterSessionContextInKernel-FailsOnMissingOrForeignState@@Tests/EvaluatorSessions.wlt:523,1-543,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Session save fallback*)
(* When the eval kernel cannot write the session file (e.g. the "Local" sandbox kernel blocks file
   writes), saveSessionInKernel reports the failure by returning the session info instead of True,
   with the injected line counter, so saveSession can persist it from the controlling kernel. *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionInfo = None },
        Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`saveSessionInKernel[
            "FbWriteSess",
            FileNameJoin @ { $TemporaryDirectory, "AgentToolsNoSuchDir_" <> CreateUUID[ ], "x.mx" },
            7
        ]
    ],
    _Association? (#[ "SessionID" ] === "FbWriteSess" && #[ "$line" ] === 7 &),
    SameTest -> MatchQ,
    TestID   -> "SaveSessionInKernel-ReturnsInfoWhenWriteFails@@Tests/EvaluatorSessions.wlt:551,1-562,2"
]

(* A fallback-written file (info only, no session-context definitions) must round-trip through
   resumeSessionInKernel: the line seed is recovered and a foreign KernelSessionID is reported. *)
VerificationTest[
    Module[ { dir, path, info, res },
        dir  = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, "AgentToolsFbWrite_" <> CreateUUID[ ] };
        path = FileNameJoin @ { dir, "FbRoundTrip.mx" };
        info = <|
            "SessionID"       -> "FbRoundTrip",
            "KernelSessionID" -> -42,
            "$Context"        -> "Sessions`FbRoundTrip`",
            "$ContextPath"    -> { "Sessions`FbRoundTrip`", "System`" },
            "$ContextAliases" -> <| |>,
            "$Line"           -> 5,
            "$line"           -> 5,
            "In"              -> { },
            "InString"        -> { },
            "Out"             -> { },
            "MessageList"     -> { }
        |>;
        Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`writeSessionInfoFile[ path, info ];
        res = Internal`InheritedBlock[ { $Context, $ContextPath, $ContextAliases },
            Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionInfo = None },
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`resumeSessionInKernel @ path
            ]
        ];
        Quiet @ DeleteDirectory[ dir, DeleteContents -> True ];
        res
    ],
    { 5, False },
    SameTest -> MatchQ,
    TestID   -> "WriteSessionInfoFile-ResumeRoundTrip@@Tests/EvaluatorSessions.wlt:566,1-595,2"
]

(* A failed fallback write must report False without emitting messages and must not leave orphaned
   temp files behind. The rename target here exists as a directory, so the write fails while
   FileExistsQ @ path stays True: trusting the destination instead of verifying the fresh write
   would misreport this as success. *)
VerificationTest[
    Module[ { dir, path, res, temps },
        dir  = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, "AgentToolsFbFail_" <> CreateUUID[ ] };
        path = FileNameJoin @ { dir, "FbWriteFail.mx" };
        CreateDirectory @ path;
        res = Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`writeSessionInfoFile[
            path,
            <| "SessionID" -> "FbWriteFail" |>
        ];
        temps = FileNames[ "*.tmp", dir ];
        Quiet @ DeleteDirectory[ dir, DeleteContents -> True ];
        { res, temps }
    ],
    { False, { } },
    SameTest -> MatchQ,
    TestID   -> "WriteSessionInfoFile-FailureReportsFalseAndCleansUp@@Tests/EvaluatorSessions.wlt:601,1-617,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cloud Sessions*)
(* Under the "Cloud" method a session's definitions travel in Chatbook's session byte array
   (Wolfram`Chatbook`$CloudSessionMX, Chatbook 2.7.11+) and the session parses into Global`; see the
   Cloud Sessions section of Kernel/Tools/WolframLanguageEvaluator.wl. These exercise the bookkeeping
   without a cloud: the Method tool option selects the cloud path and the Chatbook version gate is mocked. *)
$cloudMethodOptions = <| "WolframLanguageEvaluator" -> <| "Method" -> "Cloud" |> |>;

VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionMXAvailableQ /@
        { "2.7.10", "2.7.11", "2.7.12", "2.8.0", "3.0.0", $Failed, None },
    { False, True, True, True, True, False, False },
    SameTest -> MatchQ,
    TestID   -> "CloudSessionMXAvailableQ-VersionGate@@Tests/EvaluatorSessions.wlt:628,1-634,2"
]

VerificationTest[
    BooleanQ @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionMXAvailableQ[ ],
    True,
    TestID -> "CloudSessionMXAvailableQ-LoadedChatbook@@Tests/EvaluatorSessions.wlt:636,1-640,2"
]

VerificationTest[
    {
        Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionQ[ ]
        ],
        Block[ { Wolfram`AgentTools`Common`$toolOptions = $cloudMethodOptions },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionQ[ ]
        ]
    },
    { False, True },
    SameTest -> MatchQ,
    TestID   -> "CloudSessionQ-FollowsMethodOption@@Tests/EvaluatorSessions.wlt:642,1-654,2"
]

(* In-kernel methods isolate each session in its own context; a cloud session parses into Global`,
   which is the only context the cloud evaluator's session byte array captures. *)
VerificationTest[
    {
        Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionContext[ "Abc123" ]
        ],
        Block[ { Wolfram`AgentTools`Common`$toolOptions = $cloudMethodOptions },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionContext[ "Abc123" ]
        ]
    },
    { "Sessions`Abc123`", "Global`" },
    SameTest -> MatchQ,
    TestID   -> "SessionContext-CloudUsesGlobal@@Tests/EvaluatorSessions.wlt:658,1-670,2"
]

(* Starting a cloud session parses into Global` and clears the byte array so the evaluator starts empty. *)
VerificationTest[
    Internal`InheritedBlock[ { $Context, $ContextPath, $ContextAliases },
        Block[
            {
                Wolfram`AgentTools`Common`$toolOptions = $cloudMethodOptions,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionMXAvailableQ = True &,
                Wolfram`Chatbook`$CloudSessionMX = ByteArray[ { 1, 2, 3 } ],
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionInfo = None
            },
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`startSessionInKernel[ "CloudStartSess" ],
                $Context,
                $ContextPath,
                Wolfram`Chatbook`$CloudSessionMX,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionInfo[ "$Context" ]
            }
        ]
    ],
    { 1, "Global`", { "Global`", "System`" }, None, "Global`" },
    SameTest -> MatchQ,
    TestID   -> "StartSessionInKernel-CloudUsesGlobalAndClearsSessionMX@@Tests/EvaluatorSessions.wlt:673,1-694,2"
]

(* Saving a cloud session returns info-only state (nothing to dump from this kernel) that carries the
   byte array left by the last cloud evaluation, so saveSession writes it from the controlling kernel. *)
VerificationTest[
    Module[ { dir, path, res },
        dir  = FileNameJoin @ { $TemporaryDirectory, "AgentToolsCloudSave_" <> CreateUUID[ ] };
        path = FileNameJoin @ { dir, "CloudSaveSess.mx" };
        res  = Internal`InheritedBlock[ { $Context, $ContextPath, $ContextAliases },
            Block[
                {
                    Wolfram`AgentTools`Common`$toolOptions = $cloudMethodOptions,
                    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionMXAvailableQ = True &,
                    Wolfram`Chatbook`$CloudSessionMX = ByteArray[ { 4, 5, 6 } ],
                    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionInfo = None
                },
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`saveSessionInKernel[ "CloudSaveSess", path, 3 ]
            ]
        ];
        { res, DirectoryQ @ dir }
    ],
    {
        KeyValuePattern @ { "SessionID" -> "CloudSaveSess", "$line" -> 3, "SessionMX" -> ByteArray[ { 4, 5, 6 } ] },
        False
    },
    SameTest -> MatchQ,
    TestID   -> "SaveSessionInKernel-CloudReturnsInfoWithSessionMX@@Tests/EvaluatorSessions.wlt:698,1-721,2"
]

(* Without a new enough Chatbook there is no byte array to keep; in-kernel sessions never carry one. *)
VerificationTest[
    {
        Block[
            {
                Wolfram`AgentTools`Common`$toolOptions = $cloudMethodOptions,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionMXAvailableQ = False &,
                Wolfram`Chatbook`$CloudSessionMX = ByteArray[ { 4, 5, 6 } ]
            },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`makeSessionInfo[ "CloudNoMXSess", 2 ][ "SessionMX" ]
        ],
        Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
            KeyExistsQ[ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`makeSessionInfo[ "InKernelSess", 2 ], "SessionMX" ]
        ]
    },
    { None, False },
    SameTest -> MatchQ,
    TestID   -> "MakeSessionInfo-SessionMXOnlyForSupportedCloudSessions@@Tests/EvaluatorSessions.wlt:724,1-741,2"
]

(* An info-only cloud session file round-trips: resuming restores the byte array for the next cloud
   evaluation and always parses into Global`, even if the file recorded another context (e.g. one
   written under a different Method). *)
VerificationTest[
    Module[ { dir, path, info, res, mx, ctx },
        dir  = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, "AgentToolsCloudRT_" <> CreateUUID[ ] };
        path = FileNameJoin @ { dir, "CloudRoundTrip.mx" };
        info = <|
            "SessionID"       -> "CloudRoundTrip",
            "KernelSessionID" -> -42,
            "$Context"        -> "Sessions`CloudRoundTrip`",
            "$ContextPath"    -> { "Sessions`CloudRoundTrip`", "System`" },
            "$ContextAliases" -> <| |>,
            "$Line"           -> 4,
            "$line"           -> 4,
            "In"              -> { },
            "InString"        -> { },
            "Out"             -> { },
            "MessageList"     -> { },
            "SessionMX"       -> ByteArray[ { 7, 8, 9 } ]
        |>;
        Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`writeSessionInfoFile[ path, info ];
        { res, mx, ctx } = Internal`InheritedBlock[ { $Context, $ContextPath, $ContextAliases },
            Block[
                {
                    Wolfram`AgentTools`Common`$toolOptions = $cloudMethodOptions,
                    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionMXAvailableQ = True &,
                    Wolfram`Chatbook`$CloudSessionMX = None,
                    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionInfo = None
                },
                {
                    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`resumeSessionInKernel @ path,
                    Wolfram`Chatbook`$CloudSessionMX,
                    $Context
                }
            ]
        ];
        Quiet @ DeleteDirectory[ dir, DeleteContents -> True ];
        { res, mx, ctx }
    ],
    { { 4, False }, ByteArray[ { 7, 8, 9 } ], "Global`" },
    SameTest -> MatchQ,
    TestID   -> "ResumeSessionInKernel-CloudRestoresSessionMXAndGlobalContext@@Tests/EvaluatorSessions.wlt:746,1-786,2"
]

(* Continuing a live cloud session gets its byte array back from the last save's $sessionInfo. *)
VerificationTest[
    Internal`InheritedBlock[ { $Context, $ContextPath, $ContextAliases },
        Block[
            {
                Wolfram`AgentTools`Common`$toolOptions = $cloudMethodOptions,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionMXAvailableQ = True &,
                Wolfram`Chatbook`$CloudSessionMX = None,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionInfo = <|
                    "SessionID"       -> "CloudEnterSess",
                    "KernelSessionID" -> 0,
                    "$Context"        -> "Global`",
                    "$ContextPath"    -> { "Global`", "System`" },
                    "$ContextAliases" -> <| |>,
                    "SessionMX"       -> ByteArray[ { 1, 1, 2 } ]
                |>
            },
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`enterSessionContextInKernel[ "CloudEnterSess" ],
                Wolfram`Chatbook`$CloudSessionMX,
                $Context
            }
        ]
    ],
    { Null, ByteArray[ { 1, 1, 2 } ], "Global`" },
    SameTest -> MatchQ,
    TestID   -> "EnterSessionContextInKernel-CloudRestoresSessionMX@@Tests/EvaluatorSessions.wlt:789,1-815,2"
]

(* Before Chatbook 2.7.28 the "Line" option never reaches the cloud evaluator kernel, so the session's line
   counter is also pushed into Chatbook's per-kernel cloud line counter for the duration of the call. *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$line = 7,
            Wolfram`Chatbook`WolframLanguageToolEvaluate =
                { Wolfram`Chatbook`Sandbox`Private`$cloudLineNumber, Lookup[ { ##3 }, "Line" ] } &
        },
        {
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookToolEvaluate[ "1", "String", 10 ],
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$line
        }
    ],
    { { 7, 7 }, 8 },
    SameTest -> MatchQ,
    TestID   -> "ChatbookToolEvaluate-SyncsCloudLineCounterWithSessionLine@@Tests/EvaluatorSessions.wlt:819,1-834,2"
]

(* Cloud sessions remind the AI on every call that the kernel is non-persistent... *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Common`$toolOptions = $cloudMethodOptions,
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionMXAvailableQ = True &
        },
        StringContainsQ[
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionInfoStatusText[ # ],
            "non-persistent cloud kernel"
        ] & /@ { "new", "continued", "resumed", "resumedNewKernel", "reused" }
    ],
    { True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "SessionInfoStatusText-CloudNoticeOnEveryStatus@@Tests/EvaluatorSessions.wlt:837,1-851,2"
]

(* ...replacing (not appending to) the in-kernel "kernel process has changed" wording... *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Common`$toolOptions = $cloudMethodOptions,
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionMXAvailableQ = True &
        },
        With[ { text = Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionInfoStatusText[ "resumedNewKernel" ] },
            { StringContainsQ[ text, "kernel process for this session has changed" ], StringContainsQ[ text, "definitions were restored" ] }
        ]
    ],
    { False, True },
    SameTest -> MatchQ,
    TestID   -> "SessionInfoStatusText-CloudReplacesKernelChangedNotice@@Tests/EvaluatorSessions.wlt:854,1-867,2"
]

(* ...while an unknown ID still gets the "No saved state" notice ahead of the cloud one. *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Common`$toolOptions = $cloudMethodOptions,
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionMXAvailableQ = True &
        },
        With[ { text = Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionInfoStatusText[ "reused" ] },
            { StringContainsQ[ text, "No saved state" ], StringContainsQ[ text, "saved after each call" ] }
        ]
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "SessionInfoStatusText-CloudReusedKeepsNoSavedStateNotice@@Tests/EvaluatorSessions.wlt:870,1-883,2"
]

(* Without a new enough Chatbook the notice says definitions cannot be restored and names the version. *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Common`$toolOptions = $cloudMethodOptions,
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionMXAvailableQ = False &
        },
        With[ { text = Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionInfoStatusText[ "continued" ] },
            {
                StringContainsQ[ text, "cannot restore definitions" ],
                StringContainsQ[ text, Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$cloudSessionMXChatbookVersion ]
            }
        ]
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "SessionInfoStatusText-CloudWithoutChatbookSupport@@Tests/EvaluatorSessions.wlt:886,1-902,2"
]

(* In-kernel methods are unaffected. *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        StringContainsQ[
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`sessionInfoStatusText[ # ],
            "cloud kernel"
        ] & /@ { "new", "continued", "resumed", "resumedNewKernel", "reused" }
    ],
    { False, False, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "SessionInfoStatusText-InKernelHasNoCloudNotice@@Tests/EvaluatorSessions.wlt:905,1-915,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Integration: end-to-end session behavior*)
(* These invoke the real tool (non-UI path), redirecting session storage to a temporary root so the
   user's real Sessions directory is untouched. $currentSessionID is reset per test for determinism. *)

(* Definitions in one session do not leak into another; switching back resumes the right state. *)
VerificationTest[
    Module[ { root, tool, r3 },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsSession_" <> CreateUUID[ ] };
        tool = $DefaultMCPTools[ "WolframLanguageEvaluator" ];
        Block[
            {
                Wolfram`AgentTools`Common`$rootPath          = root,
                Wolfram`AgentTools`Common`$clientSupportsUI  = False,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
            },
            tool[ <| "code" -> "isoX = 42", "session" -> "IsoSessionA" |> ];
            tool[ <| "code" -> "isoX = 7",  "session" -> "IsoSessionB" |> ];
            r3 = tool[ <| "code" -> "isoX", "session" -> "IsoSessionA" |> ]
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        StringContainsQ[ extractToolText @ r3, "42" ]
    ],
    True,
    TestID -> "Integration-SessionIsolation@@Tests/EvaluatorSessions.wlt:924,1-943,2"
]

(* Re-passing the same session ID continues it: definitions persist and line numbers advance. *)
VerificationTest[
    Module[ { root, tool, r2, text },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsSession_" <> CreateUUID[ ] };
        tool = $DefaultMCPTools[ "WolframLanguageEvaluator" ];
        Block[
            {
                Wolfram`AgentTools`Common`$rootPath          = root,
                Wolfram`AgentTools`Common`$clientSupportsUI  = False,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
            },
            tool[ <| "code" -> "cy = 5", "session" -> "ContSession" |> ];
            r2 = tool[ <| "code" -> "cy + 1", "session" -> "ContSession" |> ]
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        text = extractToolText @ r2;
        StringContainsQ[ text, "6" ] && StringContainsQ[ text, "Out[2]" ]
    ],
    True,
    TestID -> "Integration-ContinueSamePersistsAndAdvancesLine@@Tests/EvaluatorSessions.wlt:946,1-965,2"
]

(* A session resumes from disk after its in-kernel symbols are gone (simulated server restart). *)
VerificationTest[
    Module[ { root, tool, r2 },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsSession_" <> CreateUUID[ ] };
        tool = $DefaultMCPTools[ "WolframLanguageEvaluator" ];
        Block[
            {
                Wolfram`AgentTools`Common`$rootPath          = root,
                Wolfram`AgentTools`Common`$clientSupportsUI  = False,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
            },
            tool[ <| "code" -> "restartY = 99", "session" -> "RestartSession" |> ];
            (* Simulate a server restart: drop the in-kernel session symbols and the live session pointer *)
            Quiet @ Remove[ "Sessions`RestartSession`*" ];
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None;
            r2 = tool[ <| "code" -> "restartY", "session" -> "RestartSession" |> ]
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        StringContainsQ[ extractToolText @ r2, "99" ]
    ],
    True,
    TestID -> "Integration-RestartResumeFromDisk@@Tests/EvaluatorSessions.wlt:968,1-989,2"
]

(* Every result echoes the session ID with resume instructions. *)
VerificationTest[
    Module[ { root, tool, r },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsSession_" <> CreateUUID[ ] };
        tool = $DefaultMCPTools[ "WolframLanguageEvaluator" ];
        Block[
            {
                Wolfram`AgentTools`Common`$rootPath          = root,
                Wolfram`AgentTools`Common`$clientSupportsUI  = False,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
            },
            r = tool[ <| "code" -> "1 + 1", "session" -> "AppendSession" |> ]
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        StringContainsQ[ extractToolText @ r, "session=\"AppendSession\"" ]
    ],
    True,
    TestID -> "Integration-AppendsSessionInfo@@Tests/EvaluatorSessions.wlt:992,1-1009,2"
]

(* A fresh session's first evaluation is labeled Out[1]. *)
VerificationTest[
    Module[ { root, tool, r },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsSession_" <> CreateUUID[ ] };
        tool = $DefaultMCPTools[ "WolframLanguageEvaluator" ];
        Block[
            {
                Wolfram`AgentTools`Common`$rootPath          = root,
                Wolfram`AgentTools`Common`$clientSupportsUI  = False,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
            },
            r = tool[ <| "code" -> "1 + 1", "session" -> "LineSession" |> ]
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        StringContainsQ[ extractToolText @ r, "Out[1]" ]
    ],
    True,
    TestID -> "Integration-FreshSessionStartsAtLineOne@@Tests/EvaluatorSessions.wlt:1012,1-1029,2"
]

(* Resuming a session continues its line numbering rather than resetting it: A reaches Out[2], B
   intervenes (so A is no longer the current session), then resuming A is labeled Out[3]. Regression
   test for the cross-session line-number bug. *)
VerificationTest[
    Module[ { root, tool, r },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsSession_" <> CreateUUID[ ] };
        tool = $DefaultMCPTools[ "WolframLanguageEvaluator" ];
        Block[
            {
                Wolfram`AgentTools`Common`$rootPath          = root,
                Wolfram`AgentTools`Common`$clientSupportsUI  = False,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
            },
            tool[ <| "code" -> "11", "session" -> "ResumeLineA" |> ]; (* Out[1] *)
            tool[ <| "code" -> "22", "session" -> "ResumeLineA" |> ]; (* Out[2] *)
            tool[ <| "code" -> "33", "session" -> "ResumeLineB" |> ]; (* B intervenes; A no longer current *)
            r = tool[ <| "code" -> "44", "session" -> "ResumeLineA" |> ] (* resume A -> Out[3] *)
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        StringContainsQ[ extractToolText @ r, "Out[3]" ]
    ],
    True,
    TestID -> "Integration-ResumeContinuesLineNumbering@@Tests/EvaluatorSessions.wlt:1034,1-1054,2"
]

(* An unknown / expired session ID starts a fresh session reusing that ID and says so. *)
VerificationTest[
    Module[ { root, tool, text },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsSession_" <> CreateUUID[ ] };
        tool = $DefaultMCPTools[ "WolframLanguageEvaluator" ];
        text = Block[
            {
                Wolfram`AgentTools`Common`$rootPath          = root,
                Wolfram`AgentTools`Common`$clientSupportsUI  = False,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
            },
            extractToolText @ tool[ <| "code" -> "1", "session" -> "NeverSavedXyz" |> ]
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        StringContainsQ[ text, "NeverSavedXyz" ] && StringContainsQ[ text, "No saved state" ]
    ],
    True,
    TestID -> "Integration-UnknownIdReusedFresh@@Tests/EvaluatorSessions.wlt:1057,1-1074,2"
]

(* Context-path changes made inside a session (e.g. by Get) survive continued calls: the continuing
   call restores the last save's $Context/$ContextPath instead of resetting them, so unqualified
   references to symbols from a prepended context keep working. *)
VerificationTest[
    Module[ { root, tool, r2 },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsSession_" <> CreateUUID[ ] };
        tool = $DefaultMCPTools[ "WolframLanguageEvaluator" ];
        Block[
            {
                Wolfram`AgentTools`Common`$rootPath          = root,
                Wolfram`AgentTools`Common`$clientSupportsUI  = False,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
            },
            tool[ <| "code" -> "CtxKeepTest`ctxKeepF[x_] := x + 100; PrependTo[$ContextPath, \"CtxKeepTest`\"];", "session" -> "CtxKeepSess" |> ];
            r2 = tool[ <| "code" -> "{ctxKeepF[1], MemberQ[$ContextPath, \"CtxKeepTest`\"]}", "session" -> "CtxKeepSess" |> ]
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        Quiet @ Remove[ "CtxKeepTest`*", "Sessions`CtxKeepSess`*" ];
        StringContainsQ[ extractToolText @ r2, "{101, True}" ]
    ],
    True,
    TestID -> "Integration-ContinuePreservesContextPath@@Tests/EvaluatorSessions.wlt:1079,1-1098,2"
]

(* Resuming a session saved by a different kernel process restores the saved state and warns that
   other kernel state (loaded packages, etc.) may be gone. The saving kernel is spoofed by Blocking
   $kernelSessionID during the save. *)
VerificationTest[
    Module[ { root, tool, text },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsSession_" <> CreateUUID[ ] };
        tool = $DefaultMCPTools[ "WolframLanguageEvaluator" ];
        Block[
            {
                Wolfram`AgentTools`Common`$rootPath          = root,
                Wolfram`AgentTools`Common`$clientSupportsUI  = False,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
            },
            Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$kernelSessionID = -1 },
                tool[ <| "code" -> "nkVar = 123", "session" -> "NkResumeSess" |> ]
            ];
            (* Simulate a server restart: the live session pointer is gone, but the file (saved by
               the spoofed "previous" kernel process) remains. *)
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None;
            text = extractToolText @ tool[ <| "code" -> "nkVar", "session" -> "NkResumeSess" |> ]
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        Quiet @ Remove[ "Sessions`NkResumeSess`*" ];
        { StringContainsQ[ text, "123" ], StringContainsQ[ text, "kernel process for this session has changed" ] }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "Integration-ResumeFromPreviousKernelWarns@@Tests/EvaluatorSessions.wlt:1103,1-1128,2"
]

(* Switching back to an earlier session within the same kernel process resumes silently: no
   new-kernel warning is appended. *)
VerificationTest[
    Module[ { root, tool, text },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsSession_" <> CreateUUID[ ] };
        tool = $DefaultMCPTools[ "WolframLanguageEvaluator" ];
        Block[
            {
                Wolfram`AgentTools`Common`$rootPath          = root,
                Wolfram`AgentTools`Common`$clientSupportsUI  = False,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
            },
            tool[ <| "code" -> "swVar = 1", "session" -> "SwCtrlA" |> ];
            tool[ <| "code" -> "0", "session" -> "SwCtrlB" |> ];
            text = extractToolText @ tool[ <| "code" -> "swVar", "session" -> "SwCtrlA" |> ]
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        Quiet @ Remove[ "Sessions`SwCtrlA`*", "Sessions`SwCtrlB`*" ];
        { StringContainsQ[ text, "session=\"SwCtrlA\"" ], StringContainsQ[ text, "kernel process" ] }
    ],
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "Integration-SameKernelResumeHasNoWarning@@Tests/EvaluatorSessions.wlt:1132,1-1153,2"
]

(* If the eval kernel loses its in-memory session state while the session is still current (e.g. the
   subkernel restarted under the "Local" method), a continued call falls back to restoring from the
   session file instead of silently resetting: state and line numbering both survive. *)
VerificationTest[
    Module[ { root, tool, text },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsSession_" <> CreateUUID[ ] };
        tool = $DefaultMCPTools[ "WolframLanguageEvaluator" ];
        Block[
            {
                Wolfram`AgentTools`Common`$rootPath          = root,
                Wolfram`AgentTools`Common`$clientSupportsUI  = False,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
            },
            tool[ <| "code" -> "fbVar = 55", "session" -> "FbSess" |> ];
            text = Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionInfo = $Failed },
                extractToolText @ tool[ <| "code" -> "fbVar", "session" -> "FbSess" |> ]
            ]
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        Quiet @ Remove[ "Sessions`FbSess`*" ];
        {
            StringContainsQ[ text, "55" ],
            StringContainsQ[ text, "Out[2]" ],
            StringContainsQ[ text, "No saved state" ]
        }
    ],
    { True, True, False },
    SameTest -> MatchQ,
    TestID   -> "Integration-ContinueFallsBackToFileWhenKernelStateLost@@Tests/EvaluatorSessions.wlt:1158,1-1184,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Integration: multiple inputs*)
(* With Chatbook 2.7.28+ each top-level input of the code gets its own line number, so one call can use up several
   lines, and the session's next call continues after the last one, also when it's resumed from its file. Skipped
   with older Chatbook versions, which evaluate the code as a single input. *)
$multipleInputsTest = conditionalTest[
    TrueQ @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookLinePropertyQ[ ]
];

(* The "Local" method also needs a sandbox kernel. *)
$localMultipleInputsTest = conditionalTest[
    TrueQ @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`chatbookLinePropertyQ[ ] &&
        MatchQ[
            Quiet @ Wolfram`Chatbook`WolframLanguageToolEvaluate[ "1 + 1", "Result", "Method" -> "Local" ],
            (HoldForm|HoldCompleteForm)[ 2 ]
        ]
];

(* Evaluates each { code, session } pair with the real tool under the given method and returns the result texts. *)
multipleInputsTexts[ method_String, calls: { { _String, _String }.. } ] :=
    Module[ { root, tool },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsSession_" <> CreateUUID[ ] };
        tool = $DefaultMCPTools[ "WolframLanguageEvaluator" ];
        WithCleanup[
            Block[
                {
                    Wolfram`AgentTools`Common`$rootPath         = root,
                    Wolfram`AgentTools`Common`$clientSupportsUI = False,
                    Wolfram`AgentTools`Common`$toolOptions      = <| "WolframLanguageEvaluator" -> <| "Method" -> method |> |>,
                    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
                },
                extractToolText @ tool[ <| "code" -> #1, "session" -> #2 |> ] & @@@ calls
            ],
            Quiet @ DeleteDirectory[ root, DeleteContents -> True ]
        ]
    ];

$multipleInputsTest @ VerificationTest[
    Module[ { t1, t2, t3, t4 },
        { t1, t2, t3, t4 } = multipleInputsTexts[
            "Session",
            {
                { "1 + 1\n2 + 2", "MultiInputA" },
                { "3 + 3", "MultiInputA" },
                { "7", "MultiInputB" },
                { "{%, Out[1], Out[2]}", "MultiInputA" } (* resumed from its file *)
            }
        ];
        Quiet @ Remove[ "Sessions`MultiInputA`*", "Sessions`MultiInputB`*" ];
        {
            StringContainsQ[ t1, "Out[1]= 2" ] && StringContainsQ[ t1, "Out[2]= 4" ],
            StringContainsQ[ t2, "Out[3]= 6" ],
            StringContainsQ[ t3, "Out[1]= 7" ],
            StringContainsQ[ t4, "Out[4]= {6, 2, 4}" ]
        }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Integration-MultipleInputsLineNumbers@@Tests/EvaluatorSessions.wlt:1224,23-1246,2"
]

(* Under the "Local" method the session bookkeeping in the eval kernel also leaves the In/Out history alone. *)
$localMultipleInputsTest @ VerificationTest[
    Module[ { t1, t2, t3 },
        { t1, t2, t3 } = multipleInputsTexts[
            "Local",
            {
                { "1 + 1\n2 + 2", "LocalMultiInputA" },
                { "7", "LocalMultiInputB" },
                { "{%, Out[1], InString[2]}", "LocalMultiInputA" }
            }
        ];
        {
            StringContainsQ[ t1, "Out[1]= 2" ] && StringContainsQ[ t1, "Out[2]= 4" ],
            StringContainsQ[ t2, "Out[1]= 7" ],
            StringContainsQ[ t3, "Out[3]= {4, 2, \"2 + 2\"}" ]
        }
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Integration-Local-MultipleInputsLineNumbers@@Tests/EvaluatorSessions.wlt:1249,28-1268,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Integration: cloud sessions*)
(* A real cloud round trip under the "Cloud" method. Needs a cloud connection and a Chatbook new enough
   to carry the session byte array (2.7.11+); skipped otherwise. Definitions made in one call must come
   back after a simulated server restart (the live session pointer is dropped, so the session resumes
   from its file with the saved byte array), while another session must not see them. *)
$cloudSessionTest = conditionalTest[
    TrueQ @ $CloudConnected &&
        TrueQ @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionMXAvailableQ[ ]
];

$cloudSessionTest @ VerificationTest[
    Module[ { root, tool, r1, r2, r3, t1, t2, t3 },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsCloudSession_" <> CreateUUID[ ] };
        tool = $DefaultMCPTools[ "WolframLanguageEvaluator" ];
        Block[
            {
                Wolfram`AgentTools`Common`$rootPath         = root,
                Wolfram`AgentTools`Common`$clientSupportsUI = False,
                Wolfram`AgentTools`Common`$toolOptions      = $cloudMethodOptions,
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
            },
            r1 = tool[ <| "code" -> "cloudSessX = 42; cloudSessF[n_] := n + cloudSessX; cloudSessX", "session" -> "CloudIntegA" |> ];
            r2 = tool[ <| "code" -> "cloudSessF[1]", "session" -> "CloudIntegB" |> ];
            (* Simulate a server restart: drop the live session pointer so A resumes from its file *)
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None;
            r3 = tool[ <| "code" -> "cloudSessF[1]", "session" -> "CloudIntegA" |> ]
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        { t1, t2, t3 } = extractToolText /@ { r1, r2, r3 };
        {
            StringContainsQ[ t1, "Out[1]= 42" ],
            StringContainsQ[ t2, "Out[1]= cloudSessF[1]" ], (* B never saw A's definitions *)
            StringContainsQ[ t3, "Out[2]= 43" ],
            StringContainsQ[ t3, "non-persistent cloud kernel" ]
        }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Integration-CloudSessionDefinitionsSurviveRestart@@Tests/EvaluatorSessions.wlt:1282,21-1311,2"
]

(* :!CodeAnalysis::EndBlock:: *)
