(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/CreateMCPServer.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/CreateMCPServer.wlt:11,1-16,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Basic Examples*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Creation, Retrieval, and Deletion*)
VerificationTest[
    name = CreateUUID[ ];
    server = CreateMCPServer[
        name,
        LLMConfiguration @ <| "Tools" -> { LLMTool[ "PrimeFinder", { "n" -> "Integer" }, Prime[ #n ] & ] } |>
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-BasicExample@@Tests/CreateMCPServer.wlt:25,1-34,2"
]

VerificationTest[
    MCPServerObject @ name,
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-CheckRetrieval@@Tests/CreateMCPServer.wlt:36,1-41,2"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-DeleteObject@@Tests/CreateMCPServer.wlt:43,1-48,2"
]

VerificationTest[
    MCPServerObject @ name,
    _Failure,
    { MCPServerObject::MCPServerNotFound },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-DeletionCheck@@Tests/CreateMCPServer.wlt:50,1-56,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Create MCP Server from Default $LLMEvaluator*)

VerificationTest[
    Block[{$LLMEvaluator = LLMConfiguration @ <| "Tools" -> { LLMTool[ "Calculator", { "expr" -> "String" }, ToExpression[ #expr ] & ] } |>},
        name = CreateUUID[ ];
        server = CreateMCPServer[name]
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-FromDefaultEvaluator@@Tests/CreateMCPServer.wlt:62,1-70,2"
]

VerificationTest[
    server["Tools"],
    { _LLMTool },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-DefaultEvaluatorTools@@Tests/CreateMCPServer.wlt:72,1-77,2"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-DefaultEvaluatorCleanup@@Tests/CreateMCPServer.wlt:79,1-84,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Options*)
VerificationTest[
    name = CreateUUID[ ];
    server = CreateMCPServer[
        name,
        LLMConfiguration @ <| "Tools" -> { LLMTool[ "Doubler", { "x" -> "Number" }, 2 * #x & ] } |>,
        OverwriteTarget -> False
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-OverwriteOptionFalse@@Tests/CreateMCPServer.wlt:89,1-99,2"
]

(* cspell: ignore Tripler *)
VerificationTest[
    CreateMCPServer[
        name,
        LLMConfiguration @ <| "Tools" -> { LLMTool[ "Tripler", { "x" -> "Number" }, 3 * #x & ] } |>,
        OverwriteTarget -> False
    ],
    _Failure,
    { CreateMCPServer::MCPServerExists },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-ExistingServerNoOverwrite@@Tests/CreateMCPServer.wlt:102,1-112,2"
]

VerificationTest[
    newServer = CreateMCPServer[
        name,
        LLMConfiguration @ <| "Tools" -> { LLMTool[ "Tripler", { "x" -> "Number" }, 3 * #x & ] } |>,
        OverwriteTarget -> True
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-OverwriteOptionTrue@@Tests/CreateMCPServer.wlt:114,1-123,2"
]

VerificationTest[
    newServer["Tools"][[1]]["Name"],
    "Tripler",
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-VerifyOverwrite@@Tests/CreateMCPServer.wlt:125,1-130,2"
]

VerificationTest[
    DeleteObject @ newServer,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-OptionsCleanup@@Tests/CreateMCPServer.wlt:132,1-137,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Initialization Option*)

(* Default Initialization is None *)
VerificationTest[
    name = CreateUUID[ ];
    server = CreateMCPServer[
        name,
        <| "Tools" -> { LLMTool[ "Echo", { "x" -> "String" }, #x & ] } |>
    ];
    server[ "Data" ][ "Initialization" ],
    None,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-InitializationDefaultNone@@Tests/CreateMCPServer.wlt:144,1-154,2"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-InitializationDefaultCleanup@@Tests/CreateMCPServer.wlt:156,1-161,2"
]

(* Initialization expression is held during creation when using RuleDelayed *)
VerificationTest[
    $mcpTestInitRan = False;
    name = CreateUUID[ ];
    server = CreateMCPServer[
        name,
        <| "Tools" -> { LLMTool[ "Echo", { "x" -> "String" }, #x & ] } |>,
        Initialization :> ($mcpTestInitRan = True)
    ];
    { MCPServerObjectQ @ server, $mcpTestInitRan },
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-InitializationHeld@@Tests/CreateMCPServer.wlt:164,1-176,2"
]

(* Initialization is present in server data *)
VerificationTest[
    server[ "Data" ],
    KeyValuePattern[ "Initialization" :> ($mcpTestInitRan = True) ],
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-InitializationInData@@Tests/CreateMCPServer.wlt:179,1-184,2"
]

VerificationTest[
    DeleteObject @ server;
    ClearAll @ $mcpTestInitRan,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-InitializationHeldCleanup@@Tests/CreateMCPServer.wlt:186,1-192,2"
]

(* Explicit Initialization -> None is stored correctly *)
VerificationTest[
    name = CreateUUID[ ];
    server = CreateMCPServer[
        name,
        <| "Tools" -> { LLMTool[ "Echo", { "x" -> "String" }, #x & ] } |>,
        Initialization -> None
    ];
    server[ "Data" ],
    KeyValuePattern[ "Initialization" -> None ],
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-InitializationExplicitNone@@Tests/CreateMCPServer.wlt:195,1-206,2"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-InitializationExplicitNoneCleanup@@Tests/CreateMCPServer.wlt:208,1-213,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Properties*)
VerificationTest[
    name = CreateUUID[ ];
    server = CreateMCPServer[
        name,
        LLMConfiguration @ <|
            "Tools" -> { LLMTool[ "StringReverse", { "text" -> "String" }, StringReverse[ #text ] & ] },
            "Temperature" -> 0.7,
            "MaxTokens" -> 1000
        |>
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-WithProperties@@Tests/CreateMCPServer.wlt:218,1-231,2"
]

VerificationTest[
    server["Temperature"],
    0.7,
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-VerifyTemperature@@Tests/CreateMCPServer.wlt:233,1-238,2"
]

VerificationTest[
    server["MaxTokens"],
    1000,
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-VerifyMaxTokens@@Tests/CreateMCPServer.wlt:240,1-245,2"
]

VerificationTest[
    server["ServerVersion"],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-ServerVersion@@Tests/CreateMCPServer.wlt:247,1-252,2"
]

VerificationTest[
    server["Location"],
    _File? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-VerifyLocation@@Tests/CreateMCPServer.wlt:254,1-259,2"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-PropertiesCleanup@@Tests/CreateMCPServer.wlt:261,1-266,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LLMConfiguration Conversion*)
VerificationTest[
    name = CreateUUID[ ];
    config = <| "Tools" -> { LLMTool[ "Identity", { "x" -> "Expression" }, #x & ] } |>;
    server = CreateMCPServer[name, config],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-FromAssociation@@Tests/CreateMCPServer.wlt:271,1-278,2"
]

VerificationTest[
    server["LLMConfiguration"],
    _LLMConfiguration,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-LLMConfigurationProperty@@Tests/CreateMCPServer.wlt:280,1-285,2"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-ConfigCleanup@@Tests/CreateMCPServer.wlt:287,1-292,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Chatbook Tool Rewriting*)

(* Test that LLMConfiguration with string tool names produces equivalent results to association input *)
VerificationTest[
    name1 = CreateUUID[ ];
    name2 = CreateUUID[ ];
    server1 = CreateMCPServer[ name1, LLMConfiguration @ <| "Tools" -> { "WolframLanguageEvaluator" } |> ];
    server2 = CreateMCPServer[ name2, <| "Tools" -> { "WolframLanguageEvaluator" } |> ];
    SameQ[ server1[ "Tools" ], server2[ "Tools" ] ],
    True,
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-WLEvaluatorEquivalence@@Tests/CreateMCPServer.wlt:299,1-308,2"
]

VerificationTest[
    { DeleteObject @ server1, DeleteObject @ server2 },
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-WLEvaluatorCleanup@@Tests/CreateMCPServer.wlt:310,1-315,2"
]

VerificationTest[
    name1 = CreateUUID[ ];
    name2 = CreateUUID[ ];
    server1 = CreateMCPServer[ name1, LLMConfiguration @ <| "Tools" -> { "WolframAlpha" } |> ];
    server2 = CreateMCPServer[ name2, <| "Tools" -> { "WolframAlpha" } |> ];
    SameQ[ server1[ "Tools" ], server2[ "Tools" ] ],
    True,
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-WolframAlphaEquivalence@@Tests/CreateMCPServer.wlt:317,1-326,2"
]

VerificationTest[
    { DeleteObject @ server1, DeleteObject @ server2 },
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-WolframAlphaCleanup@@Tests/CreateMCPServer.wlt:328,1-333,2"
]

(* Test that both tools together are rewritten correctly *)
VerificationTest[
    name1 = CreateUUID[ ];
    name2 = CreateUUID[ ];
    server1 = CreateMCPServer[ name1, LLMConfiguration @ <| "Tools" -> { "WolframLanguageEvaluator", "WolframAlpha" } |> ];
    server2 = CreateMCPServer[ name2, <| "Tools" -> { "WolframLanguageEvaluator", "WolframAlpha" } |> ];
    SameQ[ server1[ "Tools" ], server2[ "Tools" ] ],
    True,
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-BothToolsEquivalence@@Tests/CreateMCPServer.wlt:336,1-345,2"
]

VerificationTest[
    { DeleteObject @ server1, DeleteObject @ server2 },
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-BothToolsCleanup@@Tests/CreateMCPServer.wlt:347,1-352,2"
]

(* Test that custom tools are not affected by the rewriting *)
VerificationTest[
    name1 = CreateUUID[ ];
    name2 = CreateUUID[ ];
    customTool = LLMTool[ "CustomTool", { "x" -> "Integer" }, #x^2 & ];
    server1 = CreateMCPServer[ name1, LLMConfiguration @ <| "Tools" -> { customTool, "WolframLanguageEvaluator" } |> ];
    server2 = CreateMCPServer[ name2, <| "Tools" -> { customTool, "WolframLanguageEvaluator" } |> ];
    SameQ[ server1[ "Tools" ], server2[ "Tools" ] ],
    True,
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-CustomToolPreserved@@Tests/CreateMCPServer.wlt:355,1-365,2"
]

VerificationTest[
    server1[ "Tools" ][[ 1 ]][ "Name" ],
    "CustomTool",
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-CustomToolName@@Tests/CreateMCPServer.wlt:367,1-372,2"
]

VerificationTest[
    { DeleteObject @ server1, DeleteObject @ server2 },
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-CustomToolCleanup@@Tests/CreateMCPServer.wlt:374,1-379,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paclet-Qualified Tool Names*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Three-Segment Paclet-Qualified Tool Name*)
VerificationTest[
    name = CreateUUID[ ];
    server = CreateMCPServer[ name, <|
        "Tools" -> { "TestPublisher/TestPaclet/SomeTool" }
    |> ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-PacletQualifiedToolName@@Tests/CreateMCPServer.wlt:388,1-396,2"
]

VerificationTest[
    server[ "Data" ][ "LLMEvaluator" ][ "Tools" ],
    { "TestPublisher/TestPaclet/SomeTool" },
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-PacletToolPreservedInData@@Tests/CreateMCPServer.wlt:398,1-403,2"
]

VerificationTest[
    Module[ { wxfPath, wxfData },
        wxfPath = FileNameJoin @ { First @ server[ "Location" ], "Metadata.wxf" };
        wxfData = Developer`ReadWXFFile @ wxfPath;
        wxfData[ "LLMEvaluator" ][ "Tools" ]
    ],
    { "TestPublisher/TestPaclet/SomeTool" },
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-PacletToolPreservedInWXF@@Tests/CreateMCPServer.wlt:405,1-414,2"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-PacletToolCleanup@@Tests/CreateMCPServer.wlt:416,1-421,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Two-Segment Paclet-Qualified Tool Name*)
VerificationTest[
    name = CreateUUID[ ];
    server = CreateMCPServer[ name, <|
        "Tools" -> { "SimplePaclet/MyTool" }
    |> ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-TwoSegmentPacletName@@Tests/CreateMCPServer.wlt:426,1-434,2"
]

VerificationTest[
    server[ "Data" ][ "LLMEvaluator" ][ "Tools" ],
    { "SimplePaclet/MyTool" },
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-TwoSegmentPreserved@@Tests/CreateMCPServer.wlt:436,1-441,2"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-TwoSegmentCleanup@@Tests/CreateMCPServer.wlt:443,1-448,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Mixed Tool Types*)
VerificationTest[
    name = CreateUUID[ ];
    customTool = LLMTool[ "CustomTool", { "x" -> "Integer" }, #x^2 & ];
    server = CreateMCPServer[ name, <|
        "Tools" -> {
            customTool,
            "TestPublisher/TestPaclet/ToolA",
            "OtherPaclet/ToolB"
        }
    |> ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-MixedToolTypes@@Tests/CreateMCPServer.wlt:453,1-466,2"
]

VerificationTest[
    With[ { tools = server[ "Data" ][ "LLMEvaluator" ][ "Tools" ] },
        {
            MatchQ[ tools[[ 1 ]], _LLMTool ],
            tools[[ 2 ]],
            tools[[ 3 ]]
        }
    ],
    { True, "TestPublisher/TestPaclet/ToolA", "OtherPaclet/ToolB" },
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-MixedToolTypesPreserved@@Tests/CreateMCPServer.wlt:468,1-479,2"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-MixedToolTypesCleanup@@Tests/CreateMCPServer.wlt:481,1-486,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Multiple Paclet-Qualified Tool Names*)
VerificationTest[
    name = CreateUUID[ ];
    server = CreateMCPServer[ name, <|
        "Tools" -> {
            "Publisher/PacletA/Tool1",
            "Publisher/PacletA/Tool2",
            "PacletB/Tool3"
        }
    |> ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-MultiplePacletTools@@Tests/CreateMCPServer.wlt:491,1-503,2"
]

VerificationTest[
    server[ "Data" ][ "LLMEvaluator" ][ "Tools" ],
    { "Publisher/PacletA/Tool1", "Publisher/PacletA/Tool2", "PacletB/Tool3" },
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-MultiplePacletToolsPreserved@@Tests/CreateMCPServer.wlt:505,1-510,2"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-MultiplePacletToolsCleanup@@Tests/CreateMCPServer.wlt:512,1-517,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Paclet-Qualified Prompt Names*)
VerificationTest[
    name = CreateUUID[ ];
    server = CreateMCPServer[ name, <|
        "Tools" -> { LLMTool[ "SimpleTool", { "x" -> "String" }, #x & ] },
        "MCPPrompts" -> { "TestPublisher/TestPaclet/SomePrompt" }
    |> ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-PacletPromptName@@Tests/CreateMCPServer.wlt:522,1-531,2"
]

VerificationTest[
    server[ "Data" ][ "LLMEvaluator" ][ "MCPPrompts" ],
    { "TestPublisher/TestPaclet/SomePrompt" },
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-PacletPromptPreservedInData@@Tests/CreateMCPServer.wlt:533,1-538,2"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-PacletPromptCleanup@@Tests/CreateMCPServer.wlt:540,1-545,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Paclet Tool Resolution with Mock Paclet*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

$testResourceDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources" };

VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
    $mockPaclet = First @ PacletFind[ "MockMCPPacletTest" ];
    $mockPaclet[ "Name" ],
    "MockMCPPacletTest",
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-MockPacletSetup@@Tests/CreateMCPServer.wlt:556,1-563,2"
]

VerificationTest[
    name = CreateUUID[ ];
    server = CreateMCPServer[ name, <|
        "Tools" -> { "MockMCPPacletTest/TestTool" }
    |> ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-WithMockPacletTool@@Tests/CreateMCPServer.wlt:565,1-573,2"
]

(* Raw data has string *)
VerificationTest[
    server[ "Data" ][ "LLMEvaluator" ][ "Tools" ],
    { "MockMCPPacletTest/TestTool" },
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-MockPacletToolStringInData@@Tests/CreateMCPServer.wlt:576,1-581,2"
]

(* Tools property resolves to LLMTool *)
VerificationTest[
    server[ "Tools" ],
    { _LLMTool },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-MockPacletToolResolves@@Tests/CreateMCPServer.wlt:584,1-589,2"
]

VerificationTest[
    server[ "Tools" ][[ 1 ]][ "Name" ],
    "TestTool",
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-MockPacletToolResolvedName@@Tests/CreateMCPServer.wlt:591,1-596,2"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-MockPacletToolCleanup@@Tests/CreateMCPServer.wlt:598,1-603,2"
]

VerificationTest[
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-MockPacletCleanup@@Tests/CreateMCPServer.wlt:605,1-611,2"
]

(* :!CodeAnalysis::EndBlock:: *)