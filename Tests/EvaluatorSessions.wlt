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
        ToString[ Wolfram`AgentTools`StartMCPServer`Private`toolSchema @ $DefaultMCPTools[ "WolframLanguageEvaluator" ], InputForm ],
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
    TestID   -> "AppendSessionInfo-AppendsToContent@@Tests/EvaluatorSessions.wlt:238,1-253,2"
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
    TestID -> "AppendSessionInfo-PreservesMeta@@Tests/EvaluatorSessions.wlt:255,1-267,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$sessionStatus = "new" },
        MatchQ[
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`appendSessionInfo[ "plain text", "Abc123" ],
            _String? (StringContainsQ[ #, "plain text" ] && StringContainsQ[ #, "Abc123" ] &)
        ]
    ],
    True,
    TestID -> "AppendSessionInfo-String@@Tests/EvaluatorSessions.wlt:283,1-292,2"
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
    TestID -> "SyncEvalKernelLine-NoOpForInProcess@@Tests/EvaluatorSessions.wlt:299,1-305,2"
]

VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`syncEvalKernelLineSafe[ "not an integer" ],
    Null,
    TestID -> "SyncEvalKernelLineSafe-IgnoresNonInteger@@Tests/EvaluatorSessions.wlt:307,1-311,2"
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
    TestID -> "Integration-SessionIsolation@@Tests/EvaluatorSessions.wlt:320,1-339,2"
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
    TestID -> "Integration-ContinueSamePersistsAndAdvancesLine@@Tests/EvaluatorSessions.wlt:342,1-361,2"
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
    TestID -> "Integration-RestartResumeFromDisk@@Tests/EvaluatorSessions.wlt:364,1-385,2"
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
    TestID -> "Integration-AppendsSessionInfo@@Tests/EvaluatorSessions.wlt:388,1-405,2"
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
    TestID -> "Integration-FreshSessionStartsAtLineOne@@Tests/EvaluatorSessions.wlt:408,1-425,2"
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
    TestID -> "Integration-ResumeContinuesLineNumbering@@Tests/EvaluatorSessions.wlt:430,1-450,2"
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
    TestID -> "Integration-UnknownIdReusedFresh@@Tests/EvaluatorSessions.wlt:453,1-470,2"
]

(* :!CodeAnalysis::EndBlock:: *)
