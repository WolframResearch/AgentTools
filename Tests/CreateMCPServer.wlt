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
    TestID   -> "CreateMCPServer-BasicExample"
]

VerificationTest[
    MCPServerObject @ name,
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-CheckRetrieval"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-DeleteObject"
]

VerificationTest[
    MCPServerObject @ name,
    _Failure,
    { MCPServerObject::MCPServerNotFound },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-DeletionCheck"
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
    TestID   -> "CreateMCPServer-FromDefaultEvaluator"
]

VerificationTest[
    server["Tools"],
    { _LLMTool },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-DefaultEvaluatorTools"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-DefaultEvaluatorCleanup"
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
    TestID   -> "CreateMCPServer-OverwriteOptionFalse"
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
    TestID   -> "CreateMCPServer-ExistingServerNoOverwrite"
]

VerificationTest[
    newServer = CreateMCPServer[
        name,
        LLMConfiguration @ <| "Tools" -> { LLMTool[ "Tripler", { "x" -> "Number" }, 3 * #x & ] } |>,
        OverwriteTarget -> True
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-OverwriteOptionTrue"
]

VerificationTest[
    newServer["Tools"][[1]]["Name"],
    "Tripler",
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-VerifyOverwrite"
]

VerificationTest[
    DeleteObject @ newServer,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-OptionsCleanup"
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
    TestID   -> "CreateMCPServer-InitializationDefaultNone"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-InitializationDefaultCleanup"
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
    TestID   -> "CreateMCPServer-InitializationHeld"
]

(* Initialization is present in server data *)
VerificationTest[
    server[ "Data" ],
    KeyValuePattern[ "Initialization" :> ($mcpTestInitRan = True) ],
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-InitializationInData"
]

VerificationTest[
    DeleteObject @ server;
    ClearAll @ $mcpTestInitRan,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-InitializationHeldCleanup"
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
    TestID   -> "CreateMCPServer-InitializationExplicitNone"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-InitializationExplicitNoneCleanup"
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
    TestID   -> "CreateMCPServer-WithProperties"
]

VerificationTest[
    server["Temperature"],
    0.7,
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-VerifyTemperature"
]

VerificationTest[
    server["MaxTokens"],
    1000,
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-VerifyMaxTokens"
]

VerificationTest[
    server["ServerVersion"],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-ServerVersion"
]

VerificationTest[
    server["Location"],
    _File? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-VerifyLocation"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-PropertiesCleanup"
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
    TestID   -> "CreateMCPServer-FromAssociation"
]

VerificationTest[
    server["LLMConfiguration"],
    _LLMConfiguration,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-LLMConfigurationProperty"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-ConfigCleanup"
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
    TestID   -> "CreateMCPServer-RewriteChatbookTools-WLEvaluatorEquivalence"
]

VerificationTest[
    { DeleteObject @ server1, DeleteObject @ server2 },
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-WLEvaluatorCleanup"
]

VerificationTest[
    name1 = CreateUUID[ ];
    name2 = CreateUUID[ ];
    server1 = CreateMCPServer[ name1, LLMConfiguration @ <| "Tools" -> { "WolframAlpha" } |> ];
    server2 = CreateMCPServer[ name2, <| "Tools" -> { "WolframAlpha" } |> ];
    SameQ[ server1[ "Tools" ], server2[ "Tools" ] ],
    True,
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-WolframAlphaEquivalence"
]

VerificationTest[
    { DeleteObject @ server1, DeleteObject @ server2 },
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-WolframAlphaCleanup"
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
    TestID   -> "CreateMCPServer-RewriteChatbookTools-BothToolsEquivalence"
]

VerificationTest[
    { DeleteObject @ server1, DeleteObject @ server2 },
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-BothToolsCleanup"
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
    TestID   -> "CreateMCPServer-RewriteChatbookTools-CustomToolPreserved"
]

VerificationTest[
    server1[ "Tools" ][[ 1 ]][ "Name" ],
    "CustomTool",
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-CustomToolName"
]

VerificationTest[
    { DeleteObject @ server1, DeleteObject @ server2 },
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-RewriteChatbookTools-CustomToolCleanup"
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
    TestID   -> "CreateMCPServer-PacletQualifiedToolName"
]

VerificationTest[
    server[ "Data" ][ "LLMEvaluator" ][ "Tools" ],
    { "TestPublisher/TestPaclet/SomeTool" },
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-PacletToolPreservedInData"
]

VerificationTest[
    Module[ { wxfPath, wxfData },
        wxfPath = FileNameJoin @ { First @ server[ "Location" ], "Metadata.wxf" };
        wxfData = Developer`ReadWXFFile @ wxfPath;
        wxfData[ "LLMEvaluator" ][ "Tools" ]
    ],
    { "TestPublisher/TestPaclet/SomeTool" },
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-PacletToolPreservedInWXF"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-PacletToolCleanup"
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
    TestID   -> "CreateMCPServer-TwoSegmentPacletName"
]

VerificationTest[
    server[ "Data" ][ "LLMEvaluator" ][ "Tools" ],
    { "SimplePaclet/MyTool" },
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-TwoSegmentPreserved"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-TwoSegmentCleanup"
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
    TestID   -> "CreateMCPServer-MixedToolTypes"
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
    TestID   -> "CreateMCPServer-MixedToolTypesPreserved"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-MixedToolTypesCleanup"
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
    TestID   -> "CreateMCPServer-MultiplePacletTools"
]

VerificationTest[
    server[ "Data" ][ "LLMEvaluator" ][ "Tools" ],
    { "Publisher/PacletA/Tool1", "Publisher/PacletA/Tool2", "PacletB/Tool3" },
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-MultiplePacletToolsPreserved"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-MultiplePacletToolsCleanup"
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
    TestID   -> "CreateMCPServer-PacletPromptName"
]

VerificationTest[
    server[ "Data" ][ "LLMEvaluator" ][ "MCPPrompts" ],
    { "TestPublisher/TestPaclet/SomePrompt" },
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-PacletPromptPreservedInData"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-PacletPromptCleanup"
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
    TestID   -> "CreateMCPServer-MockPacletSetup"
]

VerificationTest[
    name = CreateUUID[ ];
    server = CreateMCPServer[ name, <|
        "Tools" -> { "MockMCPPacletTest/TestTool" }
    |> ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-WithMockPacletTool"
]

(* Raw data has string *)
VerificationTest[
    server[ "Data" ][ "LLMEvaluator" ][ "Tools" ],
    { "MockMCPPacletTest/TestTool" },
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-MockPacletToolStringInData"
]

(* Tools property resolves to LLMTool *)
VerificationTest[
    server[ "Tools" ],
    { _LLMTool },
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-MockPacletToolResolves"
]

VerificationTest[
    server[ "Tools" ][[ 1 ]][ "Name" ],
    "TestTool",
    SameTest -> Equal,
    TestID   -> "CreateMCPServer-MockPacletToolResolvedName"
]

VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-MockPacletToolCleanup"
]

VerificationTest[
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "CreateMCPServer-MockPacletCleanup"
]

(* :!CodeAnalysis::EndBlock:: *)