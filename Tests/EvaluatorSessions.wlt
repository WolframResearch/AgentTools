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
    TestID   -> "EnterSessionContextInKernel-RestoresSavedContextState@@Tests/EvaluatorSessions.wlt:326,1-348,2"
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
    TestID   -> "EnterSessionContextInKernel-FailsOnMissingOrForeignState@@Tests/EvaluatorSessions.wlt:352,1-372,2"
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
    TestID   -> "SaveSessionInKernel-ReturnsInfoWhenWriteFails@@Tests/EvaluatorSessions.wlt:380,1-391,2"
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
    TestID   -> "WriteSessionInfoFile-ResumeRoundTrip@@Tests/EvaluatorSessions.wlt:395,1-424,2"
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
    TestID   -> "WriteSessionInfoFile-FailureReportsFalseAndCleansUp@@Tests/EvaluatorSessions.wlt:430,1-446,2"
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
    TestID   -> "CloudSessionMXAvailableQ-VersionGate@@Tests/EvaluatorSessions.wlt:457,1-463,2"
]

VerificationTest[
    BooleanQ @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`cloudSessionMXAvailableQ[ ],
    True,
    TestID -> "CloudSessionMXAvailableQ-LoadedChatbook@@Tests/EvaluatorSessions.wlt:465,1-469,2"
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
    TestID   -> "CloudSessionQ-FollowsMethodOption@@Tests/EvaluatorSessions.wlt:471,1-483,2"
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
    TestID   -> "SessionContext-CloudUsesGlobal@@Tests/EvaluatorSessions.wlt:487,1-499,2"
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
    TestID   -> "StartSessionInKernel-CloudUsesGlobalAndClearsSessionMX@@Tests/EvaluatorSessions.wlt:502,1-523,2"
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
    TestID   -> "SaveSessionInKernel-CloudReturnsInfoWithSessionMX@@Tests/EvaluatorSessions.wlt:527,1-550,2"
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
    TestID   -> "MakeSessionInfo-SessionMXOnlyForSupportedCloudSessions@@Tests/EvaluatorSessions.wlt:553,1-570,2"
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
    TestID   -> "ResumeSessionInKernel-CloudRestoresSessionMXAndGlobalContext@@Tests/EvaluatorSessions.wlt:575,1-615,2"
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
    TestID   -> "EnterSessionContextInKernel-CloudRestoresSessionMX@@Tests/EvaluatorSessions.wlt:618,1-644,2"
]

(* The "Line" option never reaches the cloud evaluator kernel, so the session's line counter is also
   pushed into Chatbook's per-kernel cloud line counter for the duration of the call. *)
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
    TestID   -> "ChatbookToolEvaluate-SyncsCloudLineCounterWithSessionLine@@Tests/EvaluatorSessions.wlt:648,1-663,2"
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
    TestID   -> "SessionInfoStatusText-CloudNoticeOnEveryStatus@@Tests/EvaluatorSessions.wlt:666,1-680,2"
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
    TestID   -> "SessionInfoStatusText-CloudReplacesKernelChangedNotice@@Tests/EvaluatorSessions.wlt:683,1-696,2"
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
    TestID   -> "SessionInfoStatusText-CloudReusedKeepsNoSavedStateNotice@@Tests/EvaluatorSessions.wlt:699,1-712,2"
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
    TestID   -> "SessionInfoStatusText-CloudWithoutChatbookSupport@@Tests/EvaluatorSessions.wlt:715,1-731,2"
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
    TestID   -> "SessionInfoStatusText-InKernelHasNoCloudNotice@@Tests/EvaluatorSessions.wlt:734,1-744,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Local Parse Context*)
(* Under the "Local" method Chatbook parses the code in this kernel but evaluates it in the eval subkernel, so
   the parse is given the eval kernel's context state and the eval kernel's symbols for the code's names. *)

(* Only symbols count (not strings, comments, operators such as \[Equal], or slots), as written: qualified and
   relative names stay whole, and named-character letters are unescaped. Code with syntax errors works too. *)
VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`codeSymbolNames[
        "f[x_Integer] := \\[Alpha]1 + $v2 + ctx`g + a\\[Equal]b (* note *) + \"word\" + f[2x + `y] + #s & + h["
    ],
    { "f", "x", "Integer", "\[Alpha]1", "$v2", "ctx`g", "a", "b", "`y", "h" },
    SameTest -> MatchQ,
    TestID   -> "CodeSymbolNames-GH#249@@Tests/EvaluatorSessions.wlt:754,1-761,2"
]

(* The eval kernel reports its context state and the full name of the symbol each name refers to there: found on
   $ContextPath first, then in $Context, where names that do not exist yet are created (as the parser would);
   qualified and relative names are resolved too. Names that are not valid as written are left out. *)
VerificationTest[
    Module[ { result },
        result = Block[ { $Context = "ParseCtxTestA`", $ContextPath = { "ParseCtxTestB`", "System`" } },
            ParseCtxTestA`pctShared = 1;
            ParseCtxTestB`pctShared = 2;
            ParseCtxTestA`pctOnlyA  = 3;
            {
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`parseContextInKernel[
                    { "pctShared", "pctOnlyA", "pctNew", "Plus", "`pctRel", "ParseCtxTestB`pctOther", "\\:03b2" }
                ],
                NameQ[ "ParseCtxTestA`pctNew" ]
            }
        ];
        Quiet @ Remove[ "ParseCtxTestA`*", "ParseCtxTestB`*" ];
        result
    ],
    {
        <|
            "$Context"        -> "ParseCtxTestA`",
            "$ContextPath"    -> { "ParseCtxTestB`", "System`" },
            "$ContextAliases" -> _Association,
            "Symbols"         -> {
                "ParseCtxTestB`pctShared",
                "ParseCtxTestA`pctOnlyA",
                "ParseCtxTestA`pctNew",
                "System`Plus",
                "ParseCtxTestA`pctRel",
                "ParseCtxTestB`pctOther"
            }
        |>,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ParseContextInKernel-ResolvesNames-GH#249@@Tests/EvaluatorSessions.wlt:766,1-800,2"
]

(* With the eval kernel stubbed: the symbols it reports are created here although this kernel never loaded
   their package, and its context state is applied, so a following parse resolves short and aliased names to
   the eval kernel's symbols and creates new names in the session context. *)
VerificationTest[
    Module[ { result },
        result = Internal`InheritedBlock[ { $Context, $ContextPath, $ContextAliases },
            Block[
                {
                    Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |>,
                    Wolfram`AgentTools`Common`useEvaluatorKernel = Function[ eval, eval, HoldAllComplete ],
                    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`parseContextInKernel = <|
                        "$Context"        -> "Sessions`PctStubSess`",
                        "$ContextPath"    -> { "PctStubPkg`", "Sessions`PctStubSess`", "System`" },
                        "$ContextAliases" -> <| "pcs`" -> "PctStubPkg`" |>,
                        "Symbols"         -> { "PctStubPkg`pctStubFn" }
                    |> &
                },
                Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`syncParseContext[ "pctStubFn[1] + pctStubNew" ];
                { $Context, ToExpression[ #, InputForm, Context ] & /@ { "pctStubFn", "pcs`pctStubFn", "pctStubNew" } }
            ]
        ];
        Quiet @ Remove[ "PctStubPkg`*", "Sessions`PctStubSess`*" ];
        result
    ],
    { "Sessions`PctStubSess`", { "PctStubPkg`", "PctStubPkg`", "Sessions`PctStubSess`" } },
    SameTest -> MatchQ,
    TestID   -> "SyncParseContext-AppliesEvalKernelState-GH#249@@Tests/EvaluatorSessions.wlt:805,1-829,2"
]

(* In-process methods parse where they evaluate, so this kernel's context state is left alone. *)
VerificationTest[
    Internal`InheritedBlock[ { $Context, $ContextPath, $ContextAliases },
        Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`syncParseContext[ "x + 1" ];
            { $Context, $ContextPath, $ContextAliases }
        ]
    ] === { $Context, $ContextPath, $ContextAliases },
    True,
    SameTest -> MatchQ,
    TestID   -> "SyncParseContext-NoOpForInProcess-GH#249@@Tests/EvaluatorSessions.wlt:832,1-842,2"
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
    TestID -> "Integration-SessionIsolation@@Tests/EvaluatorSessions.wlt:851,1-870,2"
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
    TestID -> "Integration-ContinueSamePersistsAndAdvancesLine@@Tests/EvaluatorSessions.wlt:873,1-892,2"
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
    TestID -> "Integration-RestartResumeFromDisk@@Tests/EvaluatorSessions.wlt:895,1-916,2"
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
    TestID -> "Integration-AppendsSessionInfo@@Tests/EvaluatorSessions.wlt:919,1-936,2"
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
    TestID -> "Integration-FreshSessionStartsAtLineOne@@Tests/EvaluatorSessions.wlt:939,1-956,2"
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
    TestID -> "Integration-ResumeContinuesLineNumbering@@Tests/EvaluatorSessions.wlt:961,1-981,2"
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
    TestID -> "Integration-UnknownIdReusedFresh@@Tests/EvaluatorSessions.wlt:984,1-1001,2"
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
    TestID -> "Integration-ContinuePreservesContextPath@@Tests/EvaluatorSessions.wlt:1006,1-1025,2"
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
    TestID   -> "Integration-ResumeFromPreviousKernelWarns@@Tests/EvaluatorSessions.wlt:1030,1-1055,2"
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
    TestID   -> "Integration-SameKernelResumeHasNoWarning@@Tests/EvaluatorSessions.wlt:1059,1-1080,2"
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
    TestID   -> "Integration-ContinueFallsBackToFileWhenKernelStateLost@@Tests/EvaluatorSessions.wlt:1085,1-1111,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Integration: Local method*)
(* The real tool under the "Local" method, which evaluates in a Chatbook sandbox subkernel but parses the code
   in this kernel. Skipped when the sandbox kernel cannot be started. *)
$localMethodOptions = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |>;

$localSessionTest = conditionalTest @ MatchQ[
    Quiet @ Wolfram`Chatbook`WolframLanguageToolEvaluate[ "1 + 1", "Result", "Method" -> "Local" ],
    (HoldForm|HoldCompleteForm)[ 2 ]
];

withLocalSessions // Attributes = { HoldFirst };
withLocalSessions[ eval_ ] :=
    Module[ { root },
        root = FileNameJoin @ { $TemporaryDirectory, "AgentToolsLocalSession_" <> CreateUUID[ ] };
        WithCleanup[
            Block[
                {
                    Wolfram`AgentTools`Common`$rootPath         = root,
                    Wolfram`AgentTools`Common`$clientSupportsUI = False,
                    Wolfram`AgentTools`Common`$toolOptions      = $localMethodOptions,
                    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$currentSessionID = None
                },
                eval
            ],
            Quiet @ DeleteDirectory[ root, DeleteContents -> True ]
        ]
    ];

localToolText[ code_String, session_String ] :=
    extractToolText @ $DefaultMCPTools[ "WolframLanguageEvaluator" ][ <| "code" -> code, "session" -> session |> ];

(* Typed symbols are created in the session context, so another session does not see them, and names are not
   resolved against the packages loaded in this kernel. *)
$localSessionTest @ VerificationTest[
    withLocalSessions @ {
        localToolText[ "localIsoX = 1; {Context[localIsoX], Context[CellToString], Context[StartMCPServer]}", "LocalIsoA" ],
        localToolText[ "{localIsoX, Context[localIsoX]}", "LocalIsoB" ]
    },
    {
        _? (StringContainsQ[ "{\"Sessions`LocalIsoA`\", \"Sessions`LocalIsoA`\", \"Sessions`LocalIsoA`\"}" ]),
        _? (StringContainsQ[ "{localIsoX, \"Sessions`LocalIsoB`\"}" ])
    },
    SameTest -> MatchQ,
    TestID   -> "Integration-Local-TypedSymbolsInSessionContext-GH#249@@Tests/EvaluatorSessions.wlt:1148,21-1159,2"
]

(* Later calls resolve names through the contexts and aliases the session added: a package loaded only in the
   eval kernel and an alias given to Needs. *)
$localSessionTest @ VerificationTest[
    Module[ { pkg, text },
        pkg = FileNameJoin @ { $TemporaryDirectory, "LocalPkg249_" <> CreateUUID[ ] <> ".wl" };
        Export[
            pkg,
            "BeginPackage[\"LocalPkg249`\"];\nlocalPkgFn::usage = \"\";\nBegin[\"`Private`\"];\n" <>
                "localPkgFn[x_] := x + 1000;\nEnd[];\nEndPackage[];\n",
            "Text"
        ];
        text = Last @ withLocalSessions @ {
            localToolText[ "Get[" <> ToString[ pkg, InputForm ] <> "]; Needs[\"Developer`\" -> \"dv`\"]", "LocalPkgSess" ],
            localToolText[ "{localPkgFn[1], Context[localPkgFn], dv`PackedArrayQ[Range[3]]}", "LocalPkgSess" ]
        };
        Quiet @ DeleteFile @ pkg;
        { StringContainsQ[ text, "{1001, \"LocalPkg249`\", True}" ], StringFreeQ[ text, "::shdw" ] }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "Integration-Local-SessionContextPathAndAliases-GH#249@@Tests/EvaluatorSessions.wlt:1163,21-1182,2"
]

(* Symbols created at run time and typed symbols are the same symbols, and functions defined in an earlier call
   are not reported as undefined. *)
$localSessionTest @ VerificationTest[
    Module[ { t1, t2 },
        { t1, t2 } = withLocalSessions @ {
            localToolText[ "LocalUpperDef[x_] := x + 1; ToExpression[\"localGenSym = 5\"]; LocalUpperDef[1]", "LocalWarnSess" ],
            localToolText[ "{LocalUpperDef[2], localGenSym}", "LocalWarnSess" ]
        };
        { StringContainsQ[ t2, "{3, 5}" ], StringFreeQ[ t1 <> t2, "Symbol::undefined" ] }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "Integration-Local-NoUndefinedSymbolWarnings-GH#249@@Tests/EvaluatorSessions.wlt:1186,21-1197,2"
]

(* The session's context state is applied to this kernel only for the duration of the call. *)
$localSessionTest @ VerificationTest[
    Module[ { before },
        before = { $Context, $ContextPath, $ContextAliases };
        withLocalSessions @ {
            localToolText[ "Needs[\"Developer`\" -> \"dv`\"]; 1", "LocalLeakSess" ],
            localToolText[ "2", "LocalLeakSess" ] (* continued: the session state includes the alias *)
        };
        before === { $Context, $ContextPath, $ContextAliases }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Integration-Local-ParseContextScopedToCall-GH#249@@Tests/EvaluatorSessions.wlt:1200,21-1212,2"
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
    TestID   -> "Integration-CloudSessionDefinitionsSurviveRestart@@Tests/EvaluatorSessions.wlt:1226,21-1255,2"
]

(* :!CodeAnalysis::EndBlock:: *)
