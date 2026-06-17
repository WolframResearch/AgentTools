(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/StartMCPServer.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/StartMCPServer.wlt:11,1-16,2"
]

VerificationTest[
    Get[ FileNameJoin @ { DirectoryName @ $TestFileName, "MCPServerTestUtilities.wl" } ];
    (* Set the source directory so the test utilities can find Scripts/StartMCPServer.wls *)
    Wolfram`AgentToolsTests`MCPServerTestUtilities`$MCPTestSourceDirectory = DirectoryName[ $TestFileName, 2 ],
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "LoadTestUtilities@@Tests/StartMCPServer.wlt:18,1-25,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframLanguage Server Tests*)

(* Note: These integration tests spawn a subprocess to run the MCP server and communicate via JSON-RPC.
   They work reliably when run from the TestReport MCP tool or a notebook via TestReport["Tests/StartMCPServer.wlt"],
   but subprocess stdin/stdout handling behaves differently when run via wolframscript on Windows/CI environments.
   The skipIfScript wrapper skips these tests when running as a script while allowing notebook testing. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Lifecycle*)
skipIfScript @ VerificationTest[
    $process = StartMCPTestServer[ "ServerName" -> "WolframLanguage" ],
    _ProcessObject,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ServerStarts@@Tests/StartMCPServer.wlt:39,16-44,2"
]

skipIfScript @ VerificationTest[
    ProcessStatus @ $process,
    "Running",
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ServerRunning@@Tests/StartMCPServer.wlt:46,16-51,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Initialize Protocol*)
skipIfScript @ VerificationTest[
    $initResponse = MCPInitialize[ "ClientName" -> "test-client" ],
    KeyValuePattern[ "result" -> _Association ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-Initialize@@Tests/StartMCPServer.wlt:56,16-61,2"
]

skipIfScript @ VerificationTest[
    $initResponse[[ "result", "protocolVersion" ]],
    "2024-11-05",
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ProtocolVersion@@Tests/StartMCPServer.wlt:63,16-68,2"
]

skipIfScript @ VerificationTest[
    $initResponse[[ "result", "serverInfo", "name" ]],
    "WolframLanguage",
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ServerInfoName@@Tests/StartMCPServer.wlt:70,16-75,2"
]

skipIfScript @ VerificationTest[
    $initResponse[[ "result", "serverInfo", "version" ]],
    _String,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ServerInfoVersion@@Tests/StartMCPServer.wlt:77,16-82,2"
]

skipIfScript @ VerificationTest[
    KeyExistsQ[ $initResponse[[ "result", "capabilities" ]], "tools" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-CapabilitiesTools@@Tests/StartMCPServer.wlt:84,16-89,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Ping*)
skipIfScript @ VerificationTest[
    $pingResponse = SendMCPRequest[ "ping" ],
    KeyValuePattern[ "result" -> <| |> ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-Ping@@Tests/StartMCPServer.wlt:94,16-99,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tools Protocol*)
skipIfScript @ VerificationTest[
    $toolsResponse = SendMCPRequest[ "tools/list" ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "tools" -> { __Association } ] ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolsList@@Tests/StartMCPServer.wlt:104,16-109,2"
]

skipIfScript @ VerificationTest[
    MemberQ[ $toolsResponse[[ "result", "tools", All, "name" ]], "WolframLanguageEvaluator" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolsListContainsEvaluator@@Tests/StartMCPServer.wlt:111,16-116,2"
]

skipIfScript @ VerificationTest[
    $toolSchema = SelectFirst[ $toolsResponse[[ "result", "tools" ]], #name === "WolframLanguageEvaluator" & ];
    AllTrue[ { "name", "description", "inputSchema" }, KeyExistsQ[ $toolSchema, # ] & ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolSchemaComplete@@Tests/StartMCPServer.wlt:118,16-124,2"
]

skipIfScript @ VerificationTest[
    $evalResponse = SendMCPRequest[
        "tools/call",
        <| "name" -> "WolframLanguageEvaluator", "arguments" -> <| "code" -> "1+1" |> |>
    ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "isError" -> False ] ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolCallSimple@@Tests/StartMCPServer.wlt:126,16-134,2"
]

skipIfScript @ VerificationTest[
    StringContainsQ[ $evalResponse[[ "result", "content", 1, "text" ]], "2" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolCallResult@@Tests/StartMCPServer.wlt:136,16-141,2"
]

skipIfScript @ VerificationTest[
    $evalResponse2 = SendMCPRequest[
        "tools/call",
        <| "name" -> "WolframLanguageEvaluator", "arguments" -> <| "code" -> "Prime[100]" |> |>
    ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "isError" -> False ] ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolCallComplex@@Tests/StartMCPServer.wlt:143,16-151,2"
]

skipIfScript @ VerificationTest[
    StringContainsQ[ $evalResponse2[[ "result", "content", 1, "text" ]], "541" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolCallComplexResult@@Tests/StartMCPServer.wlt:153,16-158,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Prompts Protocol*)
skipIfScript @ VerificationTest[
    $promptsResponse = SendMCPRequest[ "prompts/list" ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "prompts" -> _List ] ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-PromptsList@@Tests/StartMCPServer.wlt:163,16-168,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Handling*)
skipIfScript @ VerificationTest[
    $unknownMethodResponse = SendMCPRequest[ "unknown/method" ],
    KeyValuePattern[ "error" -> KeyValuePattern[ "code" -> -32601 ] ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-UnknownMethod@@Tests/StartMCPServer.wlt:173,16-178,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Regression: Non-existent Tool Returns Error*)
skipIfScript @ VerificationTest[
    $nonExistentToolResponse = SendMCPRequest[
        "tools/call",
        <| "name" -> "DoesNotExist", "arguments" -> <| |> |>
    ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "isError" -> True ] ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-NonExistentToolReturnsError@@Tests/StartMCPServer.wlt:183,16-191,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Regression: Print Output Captured*)
skipIfScript @ VerificationTest[
    $printResponse = SendMCPRequest[
        "tools/call",
        <| "name" -> "WolframLanguageEvaluator", "arguments" -> <| "code" -> "Print[\"TestOutput123\"]; 42" |> |>
    ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "isError" -> False ] ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-PrintOutputEvaluates@@Tests/StartMCPServer.wlt:196,16-204,2"
]

skipIfScript @ VerificationTest[
    StringContainsQ[ $printResponse[[ "result", "content", 1, "text" ]], "TestOutput123" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-PrintOutputCaptured@@Tests/StartMCPServer.wlt:206,16-211,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Cleanup*)
skipIfScript @ VerificationTest[
    StopMCPTestServer[ ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ServerStopped@@Tests/StartMCPServer.wlt:216,16-221,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Wolfram Server Tests (Smoke Tests)*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Lifecycle*)
skipIfScript @ VerificationTest[
    $processWolfram = StartMCPTestServer[ "ServerName" -> "Wolfram" ],
    _ProcessObject,
    SameTest -> MatchQ,
    TestID   -> "Wolfram-ServerStarts@@Tests/StartMCPServer.wlt:230,16-235,2"
]

skipIfScript @ VerificationTest[
    ProcessStatus @ $processWolfram,
    "Running",
    SameTest -> MatchQ,
    TestID   -> "Wolfram-ServerRunning@@Tests/StartMCPServer.wlt:237,16-242,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Initialize*)
skipIfScript @ VerificationTest[
    $initWolfram = MCPInitialize[ ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "protocolVersion" -> "2024-11-05" ] ],
    SameTest -> MatchQ,
    TestID   -> "Wolfram-Initialize@@Tests/StartMCPServer.wlt:247,16-252,2"
]

skipIfScript @ VerificationTest[
    $initWolfram[[ "result", "serverInfo", "name" ]],
    "Wolfram",
    SameTest -> MatchQ,
    TestID   -> "Wolfram-ServerInfoName@@Tests/StartMCPServer.wlt:254,16-259,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tools List*)
skipIfScript @ VerificationTest[
    $toolsWolfram = SendMCPRequest[ "tools/list" ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "tools" -> { __Association } ] ],
    SameTest -> MatchQ,
    TestID   -> "Wolfram-ToolsList@@Tests/StartMCPServer.wlt:264,16-269,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Cleanup*)
skipIfScript @ VerificationTest[
    StopMCPTestServer[ ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "Wolfram-ServerStopped@@Tests/StartMCPServer.wlt:274,16-279,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Roots Handshake (With Roots Capability)*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Lifecycle*)
skipIfScript @ VerificationTest[
    $rootsProcess = StartMCPTestServer[ "ServerName" -> "WolframLanguage" ],
    _ProcessObject,
    SameTest -> MatchQ,
    TestID   -> "RootsHandshake-ServerStarts@@Tests/StartMCPServer.wlt:288,16-293,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Setup Temp Directories*)
skipIfScript @ VerificationTest[
    $rootsTmpDir1 = CreateDirectory[ ];
    $rootsTmpDir2 = CreateDirectory[ ];
    Export[ FileNameJoin @ { $rootsTmpDir1, "rootmarker1.txt" }, "marker1", "Text" ];
    Export[ FileNameJoin @ { $rootsTmpDir2, "rootmarker2.txt" }, "marker2", "Text" ];
    $rootsTmpURI1 = "file:///" <> StringReplace[ $rootsTmpDir1, "\\" -> "/" ];
    $rootsTmpURI2 = "file:///" <> StringReplace[ $rootsTmpDir2, "\\" -> "/" ];
    AllTrue[ { $rootsTmpDir1, $rootsTmpDir2 }, DirectoryQ ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RootsHandshake-CreateTempDirs@@Tests/StartMCPServer.wlt:298,16-309,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Initialize with Roots Capability*)
skipIfScript @ VerificationTest[
    $rootsInitResponse = MCPInitialize[
        "ClientName"   -> "test-client-with-roots",
        "Capabilities" -> <| "roots" -> <| "listChanged" -> True |> |>
    ],
    KeyValuePattern[ "result" -> _Association ],
    SameTest -> MatchQ,
    TestID   -> "RootsHandshake-Initialize@@Tests/StartMCPServer.wlt:314,16-322,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Emits roots/list After notifications/initialized*)
skipIfScript @ VerificationTest[
    $rootsListRequest = ReadMCPMessage[ ],
    KeyValuePattern[ {
        "jsonrpc" -> "2.0",
        "id"      -> _String,
        "method"  -> "roots/list"
    } ],
    SameTest -> MatchQ,
    TestID   -> "RootsHandshake-EmitsRootsList@@Tests/StartMCPServer.wlt:327,16-336,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Applies Root from Response*)
(* Send the roots/list response, then verify a relative-path FileExistsQ
   resolves against the new root in a subsequent WolframLanguageEvaluator call. *)
skipIfScript @ VerificationTest[
    SendMCPResponse[
        $rootsListRequest[ "id" ],
        <| "roots" -> { <| "uri" -> $rootsTmpURI1, "name" -> "TestRoot1" |> } |>
    ];
    $rootsDirCheck = SendMCPRequest[
        "tools/call",
        <| "name"      -> "WolframLanguageEvaluator",
           "arguments" -> <| "code" -> "FileExistsQ[\"rootmarker1.txt\"]" |> |>
    ];
    StringContainsQ[ $rootsDirCheck[[ "result", "content", 1, "text" ]], "True" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RootsHandshake-RootApplied@@Tests/StartMCPServer.wlt:343,16-357,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notifications/roots/list_changed Triggers Re-fetch*)
skipIfScript @ VerificationTest[
    SendMCPNotification[ "notifications/roots/list_changed" ];
    $rootsListRequest2 = ReadMCPMessage[ ],
    KeyValuePattern[ {
        "jsonrpc" -> "2.0",
        "id"      -> _String,
        "method"  -> "roots/list"
    } ],
    SameTest -> MatchQ,
    TestID   -> "RootsHandshake-ListChangedReFetch@@Tests/StartMCPServer.wlt:362,16-372,2"
]

(* The re-fetch must use a fresh UUID so client-side correlation does not collide. *)
skipIfScript @ VerificationTest[
    $rootsListRequest2[ "id" ] =!= $rootsListRequest[ "id" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RootsHandshake-ListChangedNewID@@Tests/StartMCPServer.wlt:375,16-380,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Second Root Replaces First*)
skipIfScript @ VerificationTest[
    SendMCPResponse[
        $rootsListRequest2[ "id" ],
        <| "roots" -> { <| "uri" -> $rootsTmpURI2, "name" -> "TestRoot2" |> } |>
    ];
    $rootsDirCheck2 = SendMCPRequest[
        "tools/call",
        <| "name"      -> "WolframLanguageEvaluator",
           "arguments" -> <| "code" -> "{ FileExistsQ[\"rootmarker1.txt\"], FileExistsQ[\"rootmarker2.txt\"] }" |> |>
    ];
    (* rootmarker1.txt is in the old root, rootmarker2.txt is in the new one;
       only the new one should resolve. *)
    StringContainsQ[ $rootsDirCheck2[[ "result", "content", 1, "text" ]], "{False, True}" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RootsHandshake-ListChangedApplied@@Tests/StartMCPServer.wlt:385,16-401,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Cleanup*)
skipIfScript @ VerificationTest[
    StopMCPTestServer[ ];
    Quiet @ DeleteDirectory[ $rootsTmpDir1, DeleteContents -> True ];
    Quiet @ DeleteDirectory[ $rootsTmpDir2, DeleteContents -> True ];
    True,
    True,
    SameTest -> MatchQ,
    TestID   -> "RootsHandshake-ServerStopped@@Tests/StartMCPServer.wlt:406,16-414,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Roots Handshake (Without Roots Capability)*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Lifecycle*)
skipIfScript @ VerificationTest[
    $noRootsProcess = StartMCPTestServer[ "ServerName" -> "WolframLanguage" ],
    _ProcessObject,
    SameTest -> MatchQ,
    TestID   -> "NoRootsCap-ServerStarts@@Tests/StartMCPServer.wlt:423,16-428,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Initialize Without Roots*)
skipIfScript @ VerificationTest[
    $noRootsInitResponse = MCPInitialize[ "ClientName" -> "test-client-no-roots" ],
    KeyValuePattern[ "result" -> _Association ],
    SameTest -> MatchQ,
    TestID   -> "NoRootsCap-Initialize@@Tests/StartMCPServer.wlt:433,16-438,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*No roots/list Emitted*)
(* Without the roots capability, the server must not send a roots/list request
   in response to notifications/initialized. ReadMCPMessage should time out. *)
skipIfScript @ VerificationTest[
    ReadMCPMessage[ "Timeout" -> 3 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "NoRootsCap-NoRootsListEmitted@@Tests/StartMCPServer.wlt:445,16-450,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Cleanup*)
skipIfScript @ VerificationTest[
    StopMCPTestServer[ ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "NoRootsCap-ServerStopped@@Tests/StartMCPServer.wlt:455,16-460,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paclet Resolution and Tool Initialization*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Setup Mock Paclet*)
VerificationTest[
    $testResourceDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources" };
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
    $mockPaclet = First @ PacletFind[ "MockMCPPacletTest" ];
    $mockPaclet[ "Name" ],
    "MockMCPPacletTest",
    SameTest -> MatchQ,
    TestID   -> "PacletInit-LoadMockPaclet@@Tests/StartMCPServer.wlt:472,1-480,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stdinShutdownQ*)

(* A closed stdin surfaces as the EndOfFile symbol from InputString and must trigger a
   clean exit; the "Quit" sentinel does too. Anything else (a real request line, an empty
   keep-alive line) must NOT be treated as shutdown. This guards the fix for the
   Antigravity CLI "failed to stop mcp instance: <name>: exit status 1" hang. *)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`stdinShutdownQ @ EndOfFile,
    True,
    SameTest -> Equal,
    TestID   -> "StdinShutdownQ-EndOfFile@@Tests/StartMCPServer.wlt:482,1-487,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`stdinShutdownQ @ "Quit",
    True,
    SameTest -> Equal,
    TestID   -> "StdinShutdownQ-Quit@@Tests/StartMCPServer.wlt:489,1-494,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`stdinShutdownQ @
        "{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"initialize\"}",
    False,
    SameTest -> Equal,
    TestID   -> "StdinShutdownQ-RequestLine@@Tests/StartMCPServer.wlt:496,1-502,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`stdinShutdownQ @ "",
    False,
    SameTest -> Equal,
    TestID   -> "StdinShutdownQ-EmptyLine@@Tests/StartMCPServer.wlt:504,1-509,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*runToolInitialization*)
VerificationTest[
    $initTestValue = 0;
    tool1 = LLMTool[ <|
        "Name" -> "InitTool1",
        "Description" -> "Tool with initialization",
        "Function" -> Identity,
        "Parameters" -> { },
        "Initialization" :> ($initTestValue += 1)
    |> ];
    tool2 = LLMTool[ <|
        "Name" -> "InitTool2",
        "Description" -> "Tool with initialization",
        "Function" -> Identity,
        "Parameters" -> { },
        "Initialization" :> ($initTestValue += 10)
    |> ];
    Wolfram`AgentTools`StartMCPServer`Private`runToolInitialization[ { tool1, tool2 } ];
    $initTestValue,
    11,
    SameTest -> MatchQ,
    TestID   -> "RunToolInitialization-RunsBothInits@@Tests/StartMCPServer.wlt:485,1-506,2"
]

VerificationTest[
    $initTestValue2 = 0;
    toolNoInit = LLMTool[ <|
        "Name" -> "NoInitTool",
        "Description" -> "Tool without initialization",
        "Function" -> Identity,
        "Parameters" -> { }
    |> ];
    Wolfram`AgentTools`StartMCPServer`Private`runToolInitialization[ { toolNoInit } ];
    $initTestValue2,
    0,
    SameTest -> MatchQ,
    TestID   -> "RunToolInitialization-NoInitIsNoOp@@Tests/StartMCPServer.wlt:508,1-521,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`runToolInitialization[ { } ],
    { },
    SameTest -> MatchQ,
    TestID   -> "RunToolInitialization-EmptyListIsNoOp@@Tests/StartMCPServer.wlt:523,1-528,2"
]

VerificationTest[
    $initTestValue3 = 0;
    mixedTool1 = LLMTool[ <|
        "Name" -> "MixedInit",
        "Description" -> "Has init",
        "Function" -> Identity,
        "Parameters" -> { },
        "Initialization" :> ($initTestValue3 = 42)
    |> ];
    mixedTool2 = LLMTool[ <|
        "Name" -> "MixedNoInit",
        "Description" -> "No init",
        "Function" -> Identity,
        "Parameters" -> { }
    |> ];
    Wolfram`AgentTools`StartMCPServer`Private`runToolInitialization[ { mixedTool1, mixedTool2 } ];
    $initTestValue3,
    42,
    SameTest -> MatchQ,
    TestID   -> "RunToolInitialization-MixedInitAndNoInit@@Tests/StartMCPServer.wlt:530,1-550,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensurePacletsForStart*)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`ensurePacletsForStart[
        MCPServerObject[ "MockMCPPacletTest/TestServer" ]
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "EnsurePacletsForStart-InstalledPacletSucceeds@@Tests/StartMCPServer.wlt:555,1-562,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`ensurePacletsForStart[
        MCPServerObject[ "WolframLanguage" ]
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "EnsurePacletsForStart-BuiltInServerSucceeds@@Tests/StartMCPServer.wlt:564,1-571,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureDependenciesForStart*)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`ensureDependenciesForStart[
        MCPServerObject[ "MockMCPPacletTest/TestServer" ]
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "EnsureDependenciesForStart-InstalledPacletDeps@@Tests/StartMCPServer.wlt:576,1-583,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`ensureDependenciesForStart[
        MCPServerObject[ "WolframLanguage" ]
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "EnsureDependenciesForStart-NoPacletDepsIsNoOp@@Tests/StartMCPServer.wlt:585,1-592,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*runServerInitialization*)
VerificationTest[
    builtInServerData = <|
        "Name" -> "WolframLanguage",
        "Location" -> "BuiltIn",
        "LLMEvaluator" -> <| "Tools" -> { "WolframLanguageEvaluator" } |>
    |>;
    Wolfram`AgentTools`StartMCPServer`Private`runServerInitialization[ builtInServerData ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "RunServerInitialization-BuiltInIsNoOp@@Tests/StartMCPServer.wlt:597,1-607,2"
]

VerificationTest[
    fileServerData = <|
        "Name" -> "UserServer",
        "Location" -> File[ "some/path" ],
        "LLMEvaluator" -> <| "Tools" -> { } |>
    |>;
    Wolfram`AgentTools`StartMCPServer`Private`runServerInitialization[ fileServerData ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "RunServerInitialization-FileBasedIsNoOp@@Tests/StartMCPServer.wlt:609,1-619,2"
]

VerificationTest[
    pacletServerData = <|
        "Name" -> "MockMCPPacletTest/TestServer",
        "Location" -> $mockPaclet,
        "LLMEvaluator" -> <|
            "Tools" -> { "MockMCPPacletTest/TestTool" },
            "MCPPrompts" -> { "MockMCPPacletTest/TestPrompt" }
        |>
    |>;
    (* TestServer definition has no Initialization key, so this should return Null *)
    Wolfram`AgentTools`StartMCPServer`Private`runServerInitialization[ pacletServerData ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "RunServerInitialization-PacletServerNoInit@@Tests/StartMCPServer.wlt:621,1-635,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*disambiguateToolNames*)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`disambiguateToolNames[ { } ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-EmptyList@@Tests/StartMCPServer.wlt:640,1-645,2"
]

VerificationTest[
    toolA = LLMTool[ <| "Name" -> "Alpha", "Description" -> "Tool A", "Function" -> Identity, "Parameters" -> { } |> ];
    toolB = LLMTool[ <| "Name" -> "Beta", "Description" -> "Tool B", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`StartMCPServer`Private`disambiguateToolNames[ { toolA, toolB } ];
    Keys @ result,
    { "Alpha", "Beta" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-NoCollisions@@Tests/StartMCPServer.wlt:647,1-655,2"
]

VerificationTest[
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search JIRA", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search Slack", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`StartMCPServer`Private`disambiguateToolNames[ { toolS1, toolS2 } ];
    Keys @ result,
    { "Search1", "Search2" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-TwoCollisions@@Tests/StartMCPServer.wlt:657,1-665,2"
]

VerificationTest[
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search A", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search B", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS3 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search C", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`StartMCPServer`Private`disambiguateToolNames[ { toolS1, toolS2, toolS3 } ];
    Keys @ result,
    { "Search1", "Search2", "Search3" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-ThreeCollisions@@Tests/StartMCPServer.wlt:667,1-676,2"
]

VerificationTest[
    toolA = LLMTool[ <| "Name" -> "Alpha", "Description" -> "Unique", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search A", "Function" -> Identity, "Parameters" -> { } |> ];
    toolB = LLMTool[ <| "Name" -> "Beta", "Description" -> "Unique", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search B", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`StartMCPServer`Private`disambiguateToolNames[ { toolA, toolS1, toolB, toolS2 } ];
    Keys @ result,
    { "Alpha", "Search1", "Beta", "Search2" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-MixedCollisions@@Tests/StartMCPServer.wlt:678,1-688,2"
]

VerificationTest[
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search JIRA", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search Slack", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`StartMCPServer`Private`disambiguateToolNames[ { toolS1, toolS2 } ];
    (* The values are the original LLMTool objects *)
    { result["Search1"]["Description"], result["Search2"]["Description"] },
    { "Search JIRA", "Search Slack" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-ValuesPreserved@@Tests/StartMCPServer.wlt:690,1-699,2"
]

VerificationTest[
    toolA = LLMTool[ <| "Name" -> "Alpha", "Description" -> "Only tool", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`StartMCPServer`Private`disambiguateToolNames[ { toolA } ];
    Keys @ result,
    { "Alpha" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-SingleTool@@Tests/StartMCPServer.wlt:701,1-708,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolSchema*)

(* Regression for the bugfix that motivated these tests: Restricted["String", DigitCharacter..]
   produced "(?ms)\\d+" from LLMTool, which JS validators choke on. toolSchema should emit "\\d+". *)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`toolSchema[
        LLMTool[ "T", { "x" -> Restricted[ "String", DigitCharacter.. ] }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <| "x" -> <| "type" -> "string", "pattern" -> "\\d+" |> |>,
        "required" -> { "x" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-RestrictedDigitCharacter@@Tests/StartMCPServer.wlt:716,1-727,2"
]

(* The basic "String" Interpreter produces a redundant "(?ms).*" pattern -- toolSchema drops it. *)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`toolSchema[
        LLMTool[ "T", { "x" -> "String" }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <| "x" -> <| "type" -> "string" |> |>,
        "required" -> { "x" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-PlainStringDropsMatchAnyPattern@@Tests/StartMCPServer.wlt:730,1-741,2"
]

(* No parameters -> empty properties and no required keys. *)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`toolSchema[
        LLMTool[ "T", { }, f ]
    ],
    <| "type" -> "object", "properties" -> <| |>, "required" -> { } |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-NoParameters@@Tests/StartMCPServer.wlt:744,1-751,2"
]

(* Non-string types have no "pattern" field, so toolSchema passes them through untouched. *)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`toolSchema[
        LLMTool[ "T", { "n" -> "Number" }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <| "n" -> <| "type" -> "number" |> |>,
        "required" -> { "n" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-NumberType@@Tests/StartMCPServer.wlt:754,1-765,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`toolSchema[
        LLMTool[ "T", { "i" -> "Integer" }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <| "i" -> <| "type" -> "integer" |> |>,
        "required" -> { "i" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-IntegerType@@Tests/StartMCPServer.wlt:767,1-778,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`toolSchema[
        LLMTool[ "T", { "b" -> "Boolean" }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <| "b" -> <| "type" -> "boolean" |> |>,
        "required" -> { "b" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-BooleanType@@Tests/StartMCPServer.wlt:780,1-791,2"
]

(* Optional parameter is absent from "required". *)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`toolSchema[
        LLMTool[ "T", { "x" -> <| "Interpreter" -> "String", "Required" -> False |> }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <| "x" -> <| "type" -> "string" |> |>,
        "required" -> { }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-OptionalParameter@@Tests/StartMCPServer.wlt:794,1-805,2"
]

(* Help text shows up as "description" on the parameter schema. *)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`toolSchema[
        LLMTool[ "T", { "x" -> <| "Interpreter" -> "String", "Help" -> "A string parameter" |> }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <|
            "x" -> <| "type" -> "string", "description" -> "A string parameter" |>
        |>,
        "required" -> { "x" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-ParameterWithHelp@@Tests/StartMCPServer.wlt:808,1-821,2"
]

(* Multiple parameters of mixed types preserve order in "required". *)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`toolSchema[
        LLMTool[ "T", { "a" -> "String", "b" -> "Integer" }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <|
            "a" -> <| "type" -> "string" |>,
            "b" -> <| "type" -> "integer" |>
        |>,
        "required" -> { "a", "b" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-MultipleParameters@@Tests/StartMCPServer.wlt:824,1-838,2"
]

(* Restricted enumeration: the "(?ms)(?:red|green|blue)" pattern from LLMTool should lose its leading flags. *)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`toolSchema[
        LLMTool[ "T", { "color" -> Restricted[ "String", { "red", "green", "blue" } ] }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <|
            "color" -> <| "type" -> "string", "pattern" -> "(?:red|green|blue)" |>
        |>,
        "required" -> { "color" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-RestrictedEnumeration@@Tests/StartMCPServer.wlt:841,1-854,2"
]

(* Private-use-area (PUA) characters in strings are escaped via safeString/convertPUACharacters. *)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`toolSchema[
        LLMTool[
            "T",
            { "x" -> <| "Interpreter" -> "String", "Help" -> "desc" <> FromCharacterCode[ 16^^E000 ] <> "end" |> },
            f
        ]
    ],
    <|
        "type" -> "object",
        "properties" -> <|
            "x" -> <| "type" -> "string", "description" -> "desc\\:e000end" |>
        |>,
        "required" -> { "x" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-PUACharactersEscaped@@Tests/StartMCPServer.wlt:857,1-874,2"
]

(* Return value is an Association suitable for direct use as a JSON Schema object. *)
VerificationTest[
    AssociationQ @ Wolfram`AgentTools`StartMCPServer`Private`toolSchema[
        LLMTool[ "T", { "x" -> "String" }, f ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-ReturnsAssociation@@Tests/StartMCPServer.wlt:877,1-884,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createMCPToolData with name override*)
VerificationTest[
    tool = LLMTool[ <| "Name" -> "Search", "Description" -> "Search things", "Function" -> Identity, "Parameters" -> { } |> ];
    data = Wolfram`AgentTools`StartMCPServer`Private`createMCPToolData[ "Search1", tool ];
    data[ "name" ],
    "Search1",
    SameTest -> MatchQ,
    TestID   -> "CreateMCPToolData-NameOverride@@Tests/StartMCPServer.wlt:889,1-896,2"
]

VerificationTest[
    tool = LLMTool[ <| "Name" -> "Search", "Description" -> "Search things", "Function" -> Identity, "Parameters" -> { } |> ];
    data = Wolfram`AgentTools`StartMCPServer`Private`createMCPToolData[ "Search1", tool ];
    data[ "description" ],
    "Search things",
    SameTest -> MatchQ,
    TestID   -> "CreateMCPToolData-DescriptionPreserved@@Tests/StartMCPServer.wlt:898,1-905,2"
]

VerificationTest[
    tool = LLMTool[ <| "Name" -> "MyTool", "Description" -> "A tool", "Function" -> Identity, "Parameters" -> { } |> ];
    dataOriginal = Wolfram`AgentTools`StartMCPServer`Private`createMCPToolData[ tool ];
    dataOriginal[ "name" ],
    "MyTool",
    SameTest -> MatchQ,
    TestID   -> "CreateMCPToolData-SingleArgUsesToolName@@Tests/StartMCPServer.wlt:907,1-914,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Disambiguation integration with evaluateTool*)
VerificationTest[
    (* Build a disambiguated llmTools association and verify lookup works *)
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search JIRA", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search Slack", "Function" -> Identity, "Parameters" -> { } |> ];
    disambiguated = Wolfram`AgentTools`StartMCPServer`Private`disambiguateToolNames[ { toolS1, toolS2 } ];
    (* evaluateTool looks up tools in $llmTools by the name the client sends *)
    (* Verify the disambiguated keys correctly map to different tools *)
    { disambiguated["Search1"]["Description"], disambiguated["Search2"]["Description"] },
    { "Search JIRA", "Search Slack" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateIntegration-LookupRouting@@Tests/StartMCPServer.wlt:919,1-930,2"
]

VerificationTest[
    (* Verify the tool data sent over MCP wire uses disambiguated names *)
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search JIRA", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search Slack", "Function" -> Identity, "Parameters" -> { } |> ];
    disambiguated = Wolfram`AgentTools`StartMCPServer`Private`disambiguateToolNames[ { toolS1, toolS2 } ];
    toolDataList = KeyValueMap[ Wolfram`AgentTools`StartMCPServer`Private`createMCPToolData, disambiguated ];
    toolDataList[[ All, "name" ]],
    { "Search1", "Search2" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateIntegration-WireNames@@Tests/StartMCPServer.wlt:932,1-942,2"
]

VerificationTest[
    (* Multiple collision groups: two "Search" tools and two "Evaluate" tools *)
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "S1", "Function" -> Identity, "Parameters" -> { } |> ];
    toolE1 = LLMTool[ <| "Name" -> "Evaluate", "Description" -> "E1", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "S2", "Function" -> Identity, "Parameters" -> { } |> ];
    toolE2 = LLMTool[ <| "Name" -> "Evaluate", "Description" -> "E2", "Function" -> Identity, "Parameters" -> { } |> ];
    toolU = LLMTool[ <| "Name" -> "Unique", "Description" -> "U", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`StartMCPServer`Private`disambiguateToolNames[ { toolS1, toolE1, toolS2, toolE2, toolU } ];
    Keys @ result,
    { "Search1", "Evaluate1", "Search2", "Evaluate2", "Unique" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-MultipleGroups@@Tests/StartMCPServer.wlt:944,1-956,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup Mock Paclet*)
VerificationTest[
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ];
    True,
    True,
    SameTest -> MatchQ,
    TestID   -> "PacletCleanup-UnloadMockPaclet@@Tests/StartMCPServer.wlt:961,1-968,2"
]

(* :!CodeAnalysis::EndBlock:: *)
