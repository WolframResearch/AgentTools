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

VerificationTest[
    Get[ FileNameJoin @ { DirectoryName @ $TestFileName, "MCPServerTestUtilities.wl" } ];
    (* Set the source directory so the test utilities can find Scripts/StartMCPServer.wls *)
    Wolfram`AgentToolsTests`MCPServerTestUtilities`$MCPTestSourceDirectory = DirectoryName[ $TestFileName, 2 ],
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "LoadTestUtilities"
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
    TestID   -> "WolframLanguage-ServerStarts"
]

skipIfScript @ VerificationTest[
    ProcessStatus @ $process,
    "Running",
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ServerRunning"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Initialize Protocol*)
skipIfScript @ VerificationTest[
    $initResponse = MCPInitialize[ "ClientName" -> "test-client" ],
    KeyValuePattern[ "result" -> _Association ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-Initialize"
]

skipIfScript @ VerificationTest[
    $initResponse[[ "result", "protocolVersion" ]],
    "2024-11-05",
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ProtocolVersion"
]

skipIfScript @ VerificationTest[
    $initResponse[[ "result", "serverInfo", "name" ]],
    "WolframLanguage",
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ServerInfoName"
]

skipIfScript @ VerificationTest[
    $initResponse[[ "result", "serverInfo", "version" ]],
    _String,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ServerInfoVersion"
]

skipIfScript @ VerificationTest[
    KeyExistsQ[ $initResponse[[ "result", "capabilities" ]], "tools" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-CapabilitiesTools"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Ping*)
skipIfScript @ VerificationTest[
    $pingResponse = SendMCPRequest[ "ping" ],
    KeyValuePattern[ "result" -> <| |> ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-Ping"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tools Protocol*)
skipIfScript @ VerificationTest[
    $toolsResponse = SendMCPRequest[ "tools/list" ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "tools" -> { __Association } ] ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolsList"
]

skipIfScript @ VerificationTest[
    MemberQ[ $toolsResponse[[ "result", "tools", All, "name" ]], "WolframLanguageEvaluator" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolsListContainsEvaluator"
]

skipIfScript @ VerificationTest[
    $toolSchema = SelectFirst[ $toolsResponse[[ "result", "tools" ]], #name === "WolframLanguageEvaluator" & ];
    AllTrue[ { "name", "description", "inputSchema" }, KeyExistsQ[ $toolSchema, # ] & ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolSchemaComplete"
]

skipIfScript @ VerificationTest[
    $evalResponse = SendMCPRequest[
        "tools/call",
        <| "name" -> "WolframLanguageEvaluator", "arguments" -> <| "code" -> "1+1" |> |>
    ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "isError" -> False ] ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolCallSimple"
]

skipIfScript @ VerificationTest[
    StringContainsQ[ $evalResponse[[ "result", "content", 1, "text" ]], "2" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolCallResult"
]

skipIfScript @ VerificationTest[
    $evalResponse2 = SendMCPRequest[
        "tools/call",
        <| "name" -> "WolframLanguageEvaluator", "arguments" -> <| "code" -> "Prime[100]" |> |>
    ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "isError" -> False ] ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolCallComplex"
]

skipIfScript @ VerificationTest[
    StringContainsQ[ $evalResponse2[[ "result", "content", 1, "text" ]], "541" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ToolCallComplexResult"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Prompts Protocol*)
skipIfScript @ VerificationTest[
    $promptsResponse = SendMCPRequest[ "prompts/list" ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "prompts" -> _List ] ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-PromptsList"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Handling*)
skipIfScript @ VerificationTest[
    $unknownMethodResponse = SendMCPRequest[ "unknown/method" ],
    KeyValuePattern[ "error" -> KeyValuePattern[ "code" -> -32601 ] ],
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-UnknownMethod"
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
    TestID   -> "WolframLanguage-NonExistentToolReturnsError"
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
    TestID   -> "WolframLanguage-PrintOutputEvaluates"
]

skipIfScript @ VerificationTest[
    StringContainsQ[ $printResponse[[ "result", "content", 1, "text" ]], "TestOutput123" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-PrintOutputCaptured"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Cleanup*)
skipIfScript @ VerificationTest[
    StopMCPTestServer[ ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguage-ServerStopped"
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
    TestID   -> "Wolfram-ServerStarts"
]

skipIfScript @ VerificationTest[
    ProcessStatus @ $processWolfram,
    "Running",
    SameTest -> MatchQ,
    TestID   -> "Wolfram-ServerRunning"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Initialize*)
skipIfScript @ VerificationTest[
    $initWolfram = MCPInitialize[ ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "protocolVersion" -> "2024-11-05" ] ],
    SameTest -> MatchQ,
    TestID   -> "Wolfram-Initialize"
]

skipIfScript @ VerificationTest[
    $initWolfram[[ "result", "serverInfo", "name" ]],
    "Wolfram",
    SameTest -> MatchQ,
    TestID   -> "Wolfram-ServerInfoName"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tools List*)
skipIfScript @ VerificationTest[
    $toolsWolfram = SendMCPRequest[ "tools/list" ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "tools" -> { __Association } ] ],
    SameTest -> MatchQ,
    TestID   -> "Wolfram-ToolsList"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Cleanup*)
skipIfScript @ VerificationTest[
    StopMCPTestServer[ ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "Wolfram-ServerStopped"
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
    TestID   -> "RootsHandshake-ServerStarts"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Setup Temp Directories*)
skipIfScript @ VerificationTest[
    $rootsTmpDir1 = CreateDirectory[ ];
    $rootsTmpDir2 = CreateDirectory[ ];
    Export[ FileNameJoin @ { $rootsTmpDir1, "RootMarker1.txt" }, "marker1", "Text" ];
    Export[ FileNameJoin @ { $rootsTmpDir2, "RootMarker2.txt" }, "marker2", "Text" ];
    $rootsTmpURI1 = "file:///" <> StringReplace[ $rootsTmpDir1, "\\" -> "/" ];
    $rootsTmpURI2 = "file:///" <> StringReplace[ $rootsTmpDir2, "\\" -> "/" ];
    AllTrue[ { $rootsTmpDir1, $rootsTmpDir2 }, DirectoryQ ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RootsHandshake-CreateTempDirs"
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
    TestID   -> "RootsHandshake-Initialize"
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
    TestID   -> "RootsHandshake-EmitsRootsList"
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
           "arguments" -> <| "code" -> "FileExistsQ[\"RootMarker1.txt\"]" |> |>
    ];
    StringContainsQ[ $rootsDirCheck[[ "result", "content", 1, "text" ]], "True" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RootsHandshake-RootApplied"
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
    TestID   -> "RootsHandshake-ListChangedReFetch"
]

(* The re-fetch must use a fresh UUID so client-side correlation does not collide. *)
skipIfScript @ VerificationTest[
    $rootsListRequest2[ "id" ] =!= $rootsListRequest[ "id" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RootsHandshake-ListChangedNewID"
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
           "arguments" -> <| "code" -> "{ FileExistsQ[\"RootMarker1.txt\"], FileExistsQ[\"RootMarker2.txt\"] }" |> |>
    ];
    (* RootMarker1.txt is in the old root, RootMarker2.txt is in the new one;
       only the new one should resolve. *)
    StringContainsQ[ $rootsDirCheck2[[ "result", "content", 1, "text" ]], "{False, True}" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RootsHandshake-ListChangedApplied"
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
    TestID   -> "RootsHandshake-ServerStopped"
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
    TestID   -> "NoRootsCap-ServerStarts"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Initialize Without Roots*)
skipIfScript @ VerificationTest[
    $noRootsInitResponse = MCPInitialize[ "ClientName" -> "test-client-no-roots" ],
    KeyValuePattern[ "result" -> _Association ],
    SameTest -> MatchQ,
    TestID   -> "NoRootsCap-Initialize"
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
    TestID   -> "NoRootsCap-NoRootsListEmitted"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Cleanup*)
skipIfScript @ VerificationTest[
    StopMCPTestServer[ ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "NoRootsCap-ServerStopped"
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
    TestID   -> "PacletInit-LoadMockPaclet"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stdinShutdownQ*)

(* A closed stdin surfaces as the EndOfFile symbol from InputString and must trigger a
   clean exit; the "Quit" sentinel does too. Anything else (a real request line, an empty
   keep-alive line) must NOT be treated as shutdown. This guards the fix for the
   Antigravity CLI "failed to stop mcp instance: <name>: exit status 1" hang. *)
VerificationTest[
    Wolfram`AgentTools`Server`Local`Private`stdinShutdownQ @ EndOfFile,
    True,
    SameTest -> Equal,
    TestID   -> "StdinShutdownQ-EndOfFile"
]

VerificationTest[
    Wolfram`AgentTools`Server`Local`Private`stdinShutdownQ @ "Quit",
    True,
    SameTest -> Equal,
    TestID   -> "StdinShutdownQ-Quit"
]

VerificationTest[
    Wolfram`AgentTools`Server`Local`Private`stdinShutdownQ @
        "{\"jsonrpc\":\"2.0\",\"id\":0,\"method\":\"initialize\"}",
    False,
    SameTest -> Equal,
    TestID   -> "StdinShutdownQ-RequestLine"
]

VerificationTest[
    Wolfram`AgentTools`Server`Local`Private`stdinShutdownQ @ "",
    False,
    SameTest -> Equal,
    TestID   -> "StdinShutdownQ-EmptyLine"
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
    Wolfram`AgentTools`Server`Shared`Private`runToolInitialization[ { tool1, tool2 } ];
    $initTestValue,
    11,
    SameTest -> MatchQ,
    TestID   -> "RunToolInitialization-RunsBothInits"
]

VerificationTest[
    $initTestValue2 = 0;
    toolNoInit = LLMTool[ <|
        "Name" -> "NoInitTool",
        "Description" -> "Tool without initialization",
        "Function" -> Identity,
        "Parameters" -> { }
    |> ];
    Wolfram`AgentTools`Server`Shared`Private`runToolInitialization[ { toolNoInit } ];
    $initTestValue2,
    0,
    SameTest -> MatchQ,
    TestID   -> "RunToolInitialization-NoInitIsNoOp"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`runToolInitialization[ { } ],
    { },
    SameTest -> MatchQ,
    TestID   -> "RunToolInitialization-EmptyListIsNoOp"
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
    Wolfram`AgentTools`Server`Shared`Private`runToolInitialization[ { mixedTool1, mixedTool2 } ];
    $initTestValue3,
    42,
    SameTest -> MatchQ,
    TestID   -> "RunToolInitialization-MixedInitAndNoInit"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensurePacletsForStart*)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`ensurePacletsForStart[
        MCPServerObject[ "MockMCPPacletTest/TestServer" ]
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "EnsurePacletsForStart-InstalledPacletSucceeds"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`ensurePacletsForStart[
        MCPServerObject[ "WolframLanguage" ]
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "EnsurePacletsForStart-BuiltInServerSucceeds"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureDependenciesForStart*)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`ensureDependenciesForStart[
        MCPServerObject[ "MockMCPPacletTest/TestServer" ]
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "EnsureDependenciesForStart-InstalledPacletDeps"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`ensureDependenciesForStart[
        MCPServerObject[ "WolframLanguage" ]
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "EnsureDependenciesForStart-NoPacletDepsIsNoOp"
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
    Wolfram`AgentTools`Server`Shared`Private`runServerInitialization[ builtInServerData ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "RunServerInitialization-BuiltInIsNoOp"
]

VerificationTest[
    fileServerData = <|
        "Name" -> "UserServer",
        "Location" -> File[ "some/path" ],
        "LLMEvaluator" -> <| "Tools" -> { } |>
    |>;
    Wolfram`AgentTools`Server`Shared`Private`runServerInitialization[ fileServerData ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "RunServerInitialization-FileBasedIsNoOp"
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
    Wolfram`AgentTools`Server`Shared`Private`runServerInitialization[ pacletServerData ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "RunServerInitialization-PacletServerNoInit"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*disambiguateToolNames*)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`disambiguateToolNames[ { } ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-EmptyList"
]

VerificationTest[
    toolA = LLMTool[ <| "Name" -> "Alpha", "Description" -> "Tool A", "Function" -> Identity, "Parameters" -> { } |> ];
    toolB = LLMTool[ <| "Name" -> "Beta", "Description" -> "Tool B", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`Server`Shared`Private`disambiguateToolNames[ { toolA, toolB } ];
    Keys @ result,
    { "Alpha", "Beta" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-NoCollisions"
]

VerificationTest[
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search JIRA", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search Slack", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`Server`Shared`Private`disambiguateToolNames[ { toolS1, toolS2 } ];
    Keys @ result,
    { "Search1", "Search2" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-TwoCollisions"
]

VerificationTest[
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search A", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search B", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS3 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search C", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`Server`Shared`Private`disambiguateToolNames[ { toolS1, toolS2, toolS3 } ];
    Keys @ result,
    { "Search1", "Search2", "Search3" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-ThreeCollisions"
]

VerificationTest[
    toolA = LLMTool[ <| "Name" -> "Alpha", "Description" -> "Unique", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search A", "Function" -> Identity, "Parameters" -> { } |> ];
    toolB = LLMTool[ <| "Name" -> "Beta", "Description" -> "Unique", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search B", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`Server`Shared`Private`disambiguateToolNames[ { toolA, toolS1, toolB, toolS2 } ];
    Keys @ result,
    { "Alpha", "Search1", "Beta", "Search2" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-MixedCollisions"
]

VerificationTest[
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search JIRA", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search Slack", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`Server`Shared`Private`disambiguateToolNames[ { toolS1, toolS2 } ];
    (* The values are the original LLMTool objects *)
    { result["Search1"]["Description"], result["Search2"]["Description"] },
    { "Search JIRA", "Search Slack" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-ValuesPreserved"
]

VerificationTest[
    toolA = LLMTool[ <| "Name" -> "Alpha", "Description" -> "Only tool", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`Server`Shared`Private`disambiguateToolNames[ { toolA } ];
    Keys @ result,
    { "Alpha" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-SingleTool"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolSchema*)

(* Regression for the bugfix that motivated these tests: Restricted["String", DigitCharacter..]
   produced "(?ms)\\d+" from LLMTool, which JS validators choke on. toolSchema should emit "\\d+". *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`toolSchema[
        LLMTool[ "T", { "x" -> Restricted[ "String", DigitCharacter.. ] }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <| "x" -> <| "type" -> "string", "pattern" -> "\\d+" |> |>,
        "required" -> { "x" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-RestrictedDigitCharacter"
]

(* The basic "String" Interpreter produces a redundant "(?ms).*" pattern -- toolSchema drops it. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`toolSchema[
        LLMTool[ "T", { "x" -> "String" }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <| "x" -> <| "type" -> "string" |> |>,
        "required" -> { "x" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-PlainStringDropsMatchAnyPattern"
]

(* No parameters -> empty properties and no required keys. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`toolSchema[
        LLMTool[ "T", { }, f ]
    ],
    <| "type" -> "object", "properties" -> <| |>, "required" -> { } |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-NoParameters"
]

(* Non-string types have no "pattern" field, so toolSchema passes them through untouched. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`toolSchema[
        LLMTool[ "T", { "n" -> "Number" }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <| "n" -> <| "type" -> "number" |> |>,
        "required" -> { "n" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-NumberType"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`toolSchema[
        LLMTool[ "T", { "i" -> "Integer" }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <| "i" -> <| "type" -> "integer" |> |>,
        "required" -> { "i" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-IntegerType"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`toolSchema[
        LLMTool[ "T", { "b" -> "Boolean" }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <| "b" -> <| "type" -> "boolean" |> |>,
        "required" -> { "b" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-BooleanType"
]

(* Optional parameter is absent from "required". *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`toolSchema[
        LLMTool[ "T", { "x" -> <| "Interpreter" -> "String", "Required" -> False |> }, f ]
    ],
    <|
        "type" -> "object",
        "properties" -> <| "x" -> <| "type" -> "string" |> |>,
        "required" -> { }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-OptionalParameter"
]

(* Help text shows up as "description" on the parameter schema. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`toolSchema[
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
    TestID   -> "ToolSchema-ParameterWithHelp"
]

(* Multiple parameters of mixed types preserve order in "required". *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`toolSchema[
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
    TestID   -> "ToolSchema-MultipleParameters"
]

(* Restricted enumeration: the "(?ms)(?:red|green|blue)" pattern from LLMTool should lose its leading flags. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`toolSchema[
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
    TestID   -> "ToolSchema-RestrictedEnumeration"
]

(* Private-use-area (PUA) characters in strings are escaped via safeString/convertPUACharacters. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`toolSchema[
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
    TestID   -> "ToolSchema-PUACharactersEscaped"
]

(* Return value is an Association suitable for direct use as a JSON Schema object. *)
VerificationTest[
    AssociationQ @ Wolfram`AgentTools`Server`Shared`Private`toolSchema[
        LLMTool[ "T", { "x" -> "String" }, f ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ToolSchema-ReturnsAssociation"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createMCPToolData with name override*)
VerificationTest[
    tool = LLMTool[ <| "Name" -> "Search", "Description" -> "Search things", "Function" -> Identity, "Parameters" -> { } |> ];
    data = Wolfram`AgentTools`Server`Shared`Private`createMCPToolData[ "Search1", tool ];
    data[ "name" ],
    "Search1",
    SameTest -> MatchQ,
    TestID   -> "CreateMCPToolData-NameOverride"
]

VerificationTest[
    tool = LLMTool[ <| "Name" -> "Search", "Description" -> "Search things", "Function" -> Identity, "Parameters" -> { } |> ];
    data = Wolfram`AgentTools`Server`Shared`Private`createMCPToolData[ "Search1", tool ];
    data[ "description" ],
    "Search things",
    SameTest -> MatchQ,
    TestID   -> "CreateMCPToolData-DescriptionPreserved"
]

VerificationTest[
    tool = LLMTool[ <| "Name" -> "MyTool", "Description" -> "A tool", "Function" -> Identity, "Parameters" -> { } |> ];
    dataOriginal = Wolfram`AgentTools`Server`Shared`Private`createMCPToolData[ tool ];
    dataOriginal[ "name" ],
    "MyTool",
    SameTest -> MatchQ,
    TestID   -> "CreateMCPToolData-SingleArgUsesToolName"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Disambiguation integration with evaluateTool*)
VerificationTest[
    (* Build a disambiguated llmTools association and verify lookup works *)
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search JIRA", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search Slack", "Function" -> Identity, "Parameters" -> { } |> ];
    disambiguated = Wolfram`AgentTools`Server`Shared`Private`disambiguateToolNames[ { toolS1, toolS2 } ];
    (* evaluateTool looks up tools in $llmTools by the name the client sends *)
    (* Verify the disambiguated keys correctly map to different tools *)
    { disambiguated["Search1"]["Description"], disambiguated["Search2"]["Description"] },
    { "Search JIRA", "Search Slack" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateIntegration-LookupRouting"
]

VerificationTest[
    (* Verify the tool data sent over MCP wire uses disambiguated names *)
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search JIRA", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "Search Slack", "Function" -> Identity, "Parameters" -> { } |> ];
    disambiguated = Wolfram`AgentTools`Server`Shared`Private`disambiguateToolNames[ { toolS1, toolS2 } ];
    toolDataList = KeyValueMap[ Wolfram`AgentTools`Server`Shared`Private`createMCPToolData, disambiguated ];
    toolDataList[[ All, "name" ]],
    { "Search1", "Search2" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateIntegration-WireNames"
]

VerificationTest[
    (* Multiple collision groups: two "Search" tools and two "Evaluate" tools *)
    toolS1 = LLMTool[ <| "Name" -> "Search", "Description" -> "S1", "Function" -> Identity, "Parameters" -> { } |> ];
    toolE1 = LLMTool[ <| "Name" -> "Evaluate", "Description" -> "E1", "Function" -> Identity, "Parameters" -> { } |> ];
    toolS2 = LLMTool[ <| "Name" -> "Search", "Description" -> "S2", "Function" -> Identity, "Parameters" -> { } |> ];
    toolE2 = LLMTool[ <| "Name" -> "Evaluate", "Description" -> "E2", "Function" -> Identity, "Parameters" -> { } |> ];
    toolU = LLMTool[ <| "Name" -> "Unique", "Description" -> "U", "Function" -> Identity, "Parameters" -> { } |> ];
    result = Wolfram`AgentTools`Server`Shared`Private`disambiguateToolNames[ { toolS1, toolE1, toolS2, toolE2, toolU } ];
    Keys @ result,
    { "Search1", "Evaluate1", "Search2", "Evaluate2", "Unique" },
    SameTest -> MatchQ,
    TestID   -> "DisambiguateToolNames-MultipleGroups"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Output Sanitization*)

(* Strings containing inline StandardForm content hold PUA linear-syntax markers. safeString
   must convert these to printable linear syntax on a single line; routing the string through
   ToString instead would render the boxes as multi-line 2D typesetting and mangle the text. *)
VerificationTest[
    Module[ { converted },
        converted = Wolfram`AgentTools`Server`Shared`Private`safeString[
            "inline " <> ToString[ 1/2, StandardForm ] <> " form"
        ];
        {
            StringContainsQ[ converted, "FractionBox" ],
            StringFreeQ[ converted, "\n" ],
            Max @ ToCharacterCode @ converted < 57344
        }
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "SafeString-PreservesStandardFormStrings"
]

(* Responses are sanitized before JSON encoding so PUA characters never reach the wire.
   Sanitizing the encoded JSON instead would corrupt it, since convertPUACharacters output
   can contain backslash sequences or raw control characters. *)
VerificationTest[
    Module[ { response, json },
        response = <|
            "jsonrpc" -> "2.0",
            "id"      -> 1,
            "result"  -> <|
                "content" -> { <| "type" -> "text", "text" -> FromCharacterCode @ { 97, 32, 57345, 32, 62371, 32, 98 } |> },
                "isError" -> False
            |>
        |>;
        json = Developer`WriteRawJSONString[
            Wolfram`AgentTools`Common`sanitizeResponse @ response,
            "Compact" -> True
        ];
        {
            StringQ @ json,
            Max @ ToCharacterCode @ json < 57344,
            AssociationQ @ Developer`ReadRawJSONString @ json
        }
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "SanitizeResponse-PUACharactersProduceValidJSON"
]

(* Non-string values and association structure pass through sanitization unchanged. *)
VerificationTest[
    Wolfram`AgentTools`Common`sanitizeResponse @ <| "a" -> { 1, True, Null }, "b" -> <| "c" -> 3.5 |> |>,
    <| "a" -> { 1, True, Null }, "b" -> <| "c" -> 3.5 |> |>,
    SameTest -> MatchQ,
    TestID   -> "SanitizeResponse-NonStringsUntouched"
]

(* Association keys are sanitized too: forwarded associations (e.g. _meta) can carry arbitrary keys. *)
VerificationTest[
    Module[ { response, json },
        response = <| "result" -> <| FromCharacterCode @ { 107, 101, 121, 57345 } -> "value" |> |>;
        json = Developer`WriteRawJSONString[
            Wolfram`AgentTools`Common`sanitizeResponse @ response,
            "Compact" -> True
        ];
        {
            Max @ ToCharacterCode @ json < 57344,
            AssociationQ @ Developer`ReadRawJSONString @ json
        }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "SanitizeResponse-PUAKeysSanitized"
]

(* Strings without PUA characters are returned unchanged. *)
VerificationTest[
    With[ { s = "plain ASCII text" },
        Wolfram`AgentTools`Common`convertPUACharacters @ s === s
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ConvertPUACharacters-NoOpWithoutPUA"
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
    TestID   -> "PacletCleanup-UnloadMockPaclet"
]

(* :!CodeAnalysis::EndBlock:: *)
