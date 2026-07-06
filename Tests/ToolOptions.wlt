(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ToolOptions.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ToolOptions.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$defaultToolOptions*)
VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions,
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-IsAssociation@@Tests/ToolOptions.wlt:24,1-29,2"
]

VerificationTest[
    Sort @ Keys @ Wolfram`AgentTools`Common`$defaultToolOptions,
    { "WolframAlphaContext", "WolframContext", "WolframLanguageContext", "WolframLanguageEvaluator" },
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-Keys@@Tests/ToolOptions.wlt:31,1-36,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions[ "WolframLanguageEvaluator" ],
    KeyValuePattern @ {
        "Method"            -> "Session",
        "ImageExportMethod" -> None,
        "TimeConstraint"    -> 60
    },
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-WolframLanguageEvaluator@@Tests/ToolOptions.wlt:38,1-47,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions[ "WolframLanguageContext" ],
    KeyValuePattern[ "MaxItems" -> 10 ],
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-WolframLanguageContext@@Tests/ToolOptions.wlt:49,1-54,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions[ "WolframAlphaContext" ],
    KeyValuePattern @ {
        "MaxItems"                     -> Automatic,
        "IncludeWolframLanguageResults" -> Automatic
    },
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-WolframAlphaContext@@Tests/ToolOptions.wlt:56,1-64,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions[ "WolframContext" ],
    KeyValuePattern @ {
        "WolframLanguageMaxItems" -> 10,
        "WolframAlphaMaxItems"    -> Automatic
    },
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-WolframContext@@Tests/ToolOptions.wlt:66,1-74,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*toolOptionValue*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "Method" ]
    ],
    "Session",
    TestID -> "ToolOptionValue-FallbackToDefault@@Tests/ToolOptions.wlt:79,1-85,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ]
    ],
    60,
    TestID -> "ToolOptionValue-FallbackToDefault-TimeConstraint@@Tests/ToolOptions.wlt:87,1-93,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageContext", "MaxItems" ]
    ],
    10,
    TestID -> "ToolOptionValue-FallbackToDefault-MaxItems@@Tests/ToolOptions.wlt:95,1-101,2"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "Method" ]
    ],
    "Local",
    TestID -> "ToolOptionValue-UserOverride@@Tests/ToolOptions.wlt:103,1-110,2"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ]
    ],
    60,
    TestID -> "ToolOptionValue-UserOverridePartial-FallbackForOtherKeys@@Tests/ToolOptions.wlt:112,1-119,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "NonexistentTool", "SomeOption" ]
    ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "ToolOptionValue-MissingTool@@Tests/ToolOptions.wlt:121,1-128,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "NonexistentOption" ]
    ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "ToolOptionValue-MissingOption@@Tests/ToolOptions.wlt:130,1-137,2"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageEvaluator" -> <| "TimeConstraint" -> 120 |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ]
    ],
    120,
    TestID -> "ToolOptionValue-CustomTimeConstraint@@Tests/ToolOptions.wlt:139,1-146,2"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageContext" -> <| "MaxItems" -> 5 |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageContext", "MaxItems" ]
    ],
    5,
    TestID -> "ToolOptionValue-CustomMaxItems@@Tests/ToolOptions.wlt:148,1-155,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*parseToolOptions*)
VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`parseToolOptions[ $Failed ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-Failed@@Tests/ToolOptions.wlt:160,1-165,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`parseToolOptions[ $Failed ],
    _Association,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-FailedReturnsAssociation@@Tests/ToolOptions.wlt:167,1-172,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`parseToolOptions[ "" ],
    _Association,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-EmptyString@@Tests/ToolOptions.wlt:174,1-179,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`parseToolOptions[ "invalid json" ],
    _Association,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-InvalidJSON@@Tests/ToolOptions.wlt:181,1-186,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`parseToolOptions[
        "{\"WolframLanguageEvaluator\":{\"Method\":\"Local\"}}"
    ],
    KeyValuePattern[ "WolframLanguageEvaluator" -> KeyValuePattern[ "Method" -> "Local" ] ],
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-ValidJSON@@Tests/ToolOptions.wlt:188,1-195,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`parseToolOptions[
        "{\"WolframLanguageEvaluator\":{\"ImageExportMethod\":\"None\",\"Method\":\"Automatic\"}}"
    ],
    KeyValuePattern[
        "WolframLanguageEvaluator" -> KeyValuePattern @ { "ImageExportMethod" -> None, "Method" -> Automatic }
    ],
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-SymbolConversion@@Tests/ToolOptions.wlt:197,1-206,2"
]

VerificationTest[
    Wolfram`AgentTools`StartMCPServer`Private`parseToolOptions[
        "{\"WolframLanguageEvaluator\":123,\"WolframAlphaContext\":{\"MaxItems\":3}}"
    ],
    <| "WolframAlphaContext" -> <| "MaxItems" -> 3 |> |>,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-Non-AssociationValues@@Tests/ToolOptions.wlt:208,1-215,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Serialization Round-Trip*)
VerificationTest[
    Module[ { opts, json, parsed },
        opts = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local", "TimeConstraint" -> 120 |> |>;
        json = Developer`WriteRawJSONString[ opts, "Compact" -> True ];
        parsed = Wolfram`AgentTools`StartMCPServer`Private`parseToolOptions @ json;
        Block[ { Wolfram`AgentTools`Common`$toolOptions = parsed },
            Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "Method" ]
        ]
    ],
    "Local",
    TestID -> "RoundTrip-MethodPreserved@@Tests/ToolOptions.wlt:220,1-231,2"
]

VerificationTest[
    Module[ { opts, json, parsed },
        opts = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local", "TimeConstraint" -> 120 |> |>;
        json = Developer`WriteRawJSONString[ opts, "Compact" -> True ];
        parsed = Wolfram`AgentTools`StartMCPServer`Private`parseToolOptions @ json;
        Block[ { Wolfram`AgentTools`Common`$toolOptions = parsed },
            Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ]
        ]
    ],
    120,
    TestID -> "RoundTrip-TimeConstraintPreserved@@Tests/ToolOptions.wlt:233,1-244,2"
]

VerificationTest[
    Module[ { opts, json, parsed },
        opts = <| "WolframLanguageContext" -> <| "MaxItems" -> 5 |> |>;
        json = Developer`WriteRawJSONString[ opts, "Compact" -> True ];
        parsed = Wolfram`AgentTools`StartMCPServer`Private`parseToolOptions @ json;
        Block[ { Wolfram`AgentTools`Common`$toolOptions = parsed },
            Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageContext", "MaxItems" ]
        ]
    ],
    5,
    TestID -> "RoundTrip-MaxItemsPreserved@@Tests/ToolOptions.wlt:246,1-257,2"
]

VerificationTest[
    Module[ { opts, json, parsed },
        opts = <|
            "WolframLanguageEvaluator" -> <| "Method" -> "Local" |>,
            "WolframLanguageContext"   -> <| "MaxItems" -> 20 |>
        |>;
        json = Developer`WriteRawJSONString[ opts, "Compact" -> True ];
        parsed = Wolfram`AgentTools`StartMCPServer`Private`parseToolOptions @ json;
        Block[ { Wolfram`AgentTools`Common`$toolOptions = parsed },
            {
                Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "Method" ],
                Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageContext", "MaxItems" ],
                (* Unset options fall back to defaults *)
                Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "ImageExportMethod" ]
            }
        ]
    ],
    { "Local", 20, None },
    TestID -> "RoundTrip-MultipleToolsPreserved@@Tests/ToolOptions.wlt:259,1-278,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InstallMCPServer with ToolOptions*)
VerificationTest[
    Module[ { configFile, name, server, result, data, env },
        configFile = File @ FileNameJoin @ { $TemporaryDirectory, StringJoin[ "mcp_test_toolOpts_", CreateUUID[], ".json" ] };
        name = StringJoin[ "TestServer_ToolOpts_", CreateUUID[] ];
        server = CreateMCPServer[
            name,
            LLMConfiguration @ <| "Tools" -> { LLMTool[ "PrimeFinder", { "n" -> "Integer" }, Prime[ #n ] & ] } |>
        ];
        result = InstallMCPServer[
            configFile, server,
            "ToolOptions" -> <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |>,
            "VerifyLLMKit" -> False
        ];
        data = Developer`ReadRawJSONString @ ReadString @ First @ configFile;
        env = data[ "mcpServers", name, "env" ];
        Quiet @ DeleteFile @ First @ configFile;
        KeyExistsQ[ env, "MCP_TOOL_OPTIONS" ]
    ],
    True,
    TestID -> "InstallMCPServer-ToolOptionsEnvVarExists@@Tests/ToolOptions.wlt:283,1-303,2"
]

VerificationTest[
    Module[ { configFile, name, server, result, data, env, toolOpts },
        configFile = File @ FileNameJoin @ { $TemporaryDirectory, StringJoin[ "mcp_test_toolOpts2_", CreateUUID[], ".json" ] };
        name = StringJoin[ "TestServer_ToolOpts2_", CreateUUID[] ];
        server = CreateMCPServer[
            name,
            LLMConfiguration @ <| "Tools" -> { LLMTool[ "PrimeFinder", { "n" -> "Integer" }, Prime[ #n ] & ] } |>
        ];
        result = InstallMCPServer[
            configFile, server,
            "ToolOptions" -> <| "WolframLanguageEvaluator" -> <| "Method" -> "Local", "TimeConstraint" -> 120 |> |>,
            "VerifyLLMKit" -> False
        ];
        data = Developer`ReadRawJSONString @ ReadString @ First @ configFile;
        env = data[ "mcpServers", name, "env" ];
        toolOpts = Developer`ReadRawJSONString @ env[ "MCP_TOOL_OPTIONS" ];
        Quiet @ DeleteFile @ First @ configFile;
        toolOpts[ "WolframLanguageEvaluator" ]
    ],
    KeyValuePattern @ { "Method" -> "Local", "TimeConstraint" -> 120 },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-ToolOptionsRoundTrip@@Tests/ToolOptions.wlt:305,1-327,2"
]

VerificationTest[
    Module[ { configFile, name, server, result, data, env },
        configFile = File @ FileNameJoin @ { $TemporaryDirectory, StringJoin[ "mcp_test_toolOpts3_", CreateUUID[], ".json" ] };
        name = StringJoin[ "TestServer_ToolOpts3_", CreateUUID[] ];
        server = CreateMCPServer[
            name,
            LLMConfiguration @ <| "Tools" -> { LLMTool[ "PrimeFinder", { "n" -> "Integer" }, Prime[ #n ] & ] } |>
        ];
        result = InstallMCPServer[
            configFile, server,
            "ToolOptions" -> <| |>,
            "VerifyLLMKit" -> False
        ];
        data = Developer`ReadRawJSONString @ ReadString @ First @ configFile;
        env = data[ "mcpServers", name, "env" ];
        Quiet @ DeleteFile @ First @ configFile;
        KeyExistsQ[ env, "MCP_TOOL_OPTIONS" ]
    ],
    False,
    TestID -> "InstallMCPServer-EmptyToolOptionsNoEnvVar@@Tests/ToolOptions.wlt:329,1-349,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*validateToolOptions*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[ <| |>, MCPServerObject[ "Wolfram" ] ],
    <| |>,
    TestID -> "ValidateToolOptions-Empty@@Tests/ToolOptions.wlt:354,1-358,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |>,
        MCPServerObject[ "Wolfram" ]
    ],
    KeyValuePattern[ "WolframLanguageEvaluator" -> KeyValuePattern[ "Method" -> "Local" ] ],
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-ValidOptions@@Tests/ToolOptions.wlt:360,1-368,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[ "not an association", MCPServerObject[ "Wolfram" ] ],
    <| |>,
    { AgentTools::InvalidToolOptions },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-InvalidType@@Tests/ToolOptions.wlt:370,1-376,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "NonexistentTool" -> <| "Foo" -> "Bar" |> |>,
        MCPServerObject[ "Wolfram" ]
    ],
    KeyValuePattern[ "NonexistentTool" -> KeyValuePattern[ "Foo" -> "Bar" ] ],
    { AgentTools::UnrecognizedToolOption },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-UnrecognizedToolName@@Tests/ToolOptions.wlt:378,1-387,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> <| "NonexistentOption" -> "value" |> |>,
        MCPServerObject[ "Wolfram" ]
    ],
    KeyValuePattern[ "WolframLanguageEvaluator" -> KeyValuePattern[ "NonexistentOption" -> "value" ] ],
    { AgentTools::UnrecognizedToolOptionName },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-UnrecognizedOptionName@@Tests/ToolOptions.wlt:389,1-398,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> 123 |>,
        MCPServerObject[ "Wolfram" ]
    ],
    <| |>,
    { AgentTools::InvalidToolOptionValue },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-NonAssociationValue@@Tests/ToolOptions.wlt:400,1-409,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> "not an association", "WolframLanguageContext" -> <| "MaxItems" -> 5 |> |>,
        MCPServerObject[ "Wolfram" ]
    ],
    <| "WolframLanguageContext" -> <| "MaxItems" -> 5 |> |>,
    { AgentTools::InvalidToolOptionValue },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-MixedValidAndInvalid@@Tests/ToolOptions.wlt:411,1-420,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> True |>,
        MCPServerObject[ "Wolfram" ]
    ],
    <| |>,
    { AgentTools::InvalidToolOptionValue },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-BooleanValue@@Tests/ToolOptions.wlt:422,1-431,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$toolOptions Initialization*)
VerificationTest[
    Wolfram`AgentTools`Common`$toolOptions,
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "ToolOptionsInitialized@@Tests/ToolOptions.wlt:436,1-441,2"
]

(* :!CodeAnalysis::EndBlock:: *)
