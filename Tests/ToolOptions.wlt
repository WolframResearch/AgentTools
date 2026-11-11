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

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$defaultToolOptions*)
VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions,
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-IsAssociation"
]

VerificationTest[
    Sort @ Keys @ Wolfram`AgentTools`Common`$defaultToolOptions,
    { "WolframAlphaContext", "WolframContext", "WolframLanguageContext", "WolframLanguageEvaluator" },
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-Keys"
]

VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions[ "WolframLanguageEvaluator" ],
    KeyValuePattern @ {
        "Method"            -> Automatic,
        "ImageExportMethod" -> None,
        "TimeConstraint"    -> 60,
        "MaxCharacterCount" -> 10000
    },
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-WolframLanguageEvaluator"
]

VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions[ "WolframLanguageContext" ],
    KeyValuePattern[ "MaxItems" -> 10 ],
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-WolframLanguageContext"
]

VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions[ "WolframAlphaContext" ],
    KeyValuePattern @ {
        "MaxItems"                     -> Automatic,
        "IncludeWolframLanguageResults" -> Automatic
    },
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-WolframAlphaContext"
]

VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions[ "WolframContext" ],
    KeyValuePattern @ {
        "WolframLanguageMaxItems" -> 10,
        "WolframAlphaMaxItems"    -> Automatic
    },
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-WolframContext"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*toolOptionValue*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "Method" ]
    ],
    Automatic,
    TestID -> "ToolOptionValue-FallbackToDefault"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ]
    ],
    60,
    TestID -> "ToolOptionValue-FallbackToDefault-TimeConstraint"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "MaxCharacterCount" ]
    ],
    10000,
    TestID -> "ToolOptionValue-FallbackToDefault-MaxCharacterCount"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageEvaluator" -> <| "MaxCharacterCount" -> 100000 |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "MaxCharacterCount" ]
    ],
    100000,
    TestID -> "ToolOptionValue-UserOverride-MaxCharacterCount"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageContext", "MaxItems" ]
    ],
    10,
    TestID -> "ToolOptionValue-FallbackToDefault-MaxItems"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "Method" ]
    ],
    "Local",
    TestID -> "ToolOptionValue-UserOverride"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ]
    ],
    60,
    TestID -> "ToolOptionValue-UserOverridePartial-FallbackForOtherKeys"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "NonexistentTool", "SomeOption" ]
    ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "ToolOptionValue-MissingTool"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "NonexistentOption" ]
    ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "ToolOptionValue-MissingOption"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageEvaluator" -> <| "TimeConstraint" -> 120 |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ]
    ],
    120,
    TestID -> "ToolOptionValue-CustomTimeConstraint"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageContext" -> <| "MaxItems" -> 5 |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageContext", "MaxItems" ]
    ],
    5,
    TestID -> "ToolOptionValue-CustomMaxItems"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*parseToolOptions*)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[ $Failed ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-Failed"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[ $Failed ],
    _Association,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-FailedReturnsAssociation"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[ "" ],
    _Association,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-EmptyString"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[ "invalid json" ],
    _Association,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-InvalidJSON"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[
        "{\"WolframLanguageEvaluator\":{\"Method\":\"Local\"}}"
    ],
    KeyValuePattern[ "WolframLanguageEvaluator" -> KeyValuePattern[ "Method" -> "Local" ] ],
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-ValidJSON"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[
        "{\"WolframLanguageEvaluator\":{\"ImageExportMethod\":\"_wl_None\",\"Method\":\"_wl_Automatic\"}}"
    ],
    KeyValuePattern[
        "WolframLanguageEvaluator" -> KeyValuePattern @ { "ImageExportMethod" -> None, "Method" -> Automatic }
    ],
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-SymbolConversion"
]

(* Values that JSON can't represent are written with a "_wl_" prefix (see toolOptionsJSONString) and restored when
   parsed: *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[
        "{\"Tool\":{\"A\":[\"_wl_All\",\"_wl_Automatic\",\"C:/x\"],\"B\":\"_wl_Infinity\"," <>
            "\"C\":\"_wl_Quantity[2, \\\"Weeks\\\"]\",\"D\":\"_wl_Hold[$TemporaryDirectory]\"}}"
    ],
    <|
        "Tool" -> <|
            "A" -> { All, Automatic, "C:/x" },
            "B" -> Infinity,
            "C" -> Quantity[ 2, "Weeks" ],
            "D" -> Hold[ $TemporaryDirectory ]
        |>
    |>,
    SameTest -> SameQ,
    TestID   -> "ParseToolOptions-PrefixedExpressions"
]

(* Strings without the prefix are always strings: *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[
        "{\"Tool\":{\"A\":[\"All\",\"Automatic\",\"None\"],\"B\":\"Infinity\",\"C\":\"Quantity[2, \\\"Weeks\\\"]\"}}"
    ],
    <| "Tool" -> <| "A" -> { "All", "Automatic", "None" }, "B" -> "Infinity", "C" -> "Quantity[2, \"Weeks\"]" |> |>,
    SameTest -> SameQ,
    TestID   -> "ParseToolOptions-PlainStringsUnchanged"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[
        "{\"WolframLanguageEvaluator\":123,\"WolframAlphaContext\":{\"MaxItems\":3}}"
    ],
    <| "WolframAlphaContext" -> <| "MaxItems" -> 3 |> |>,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-Non-AssociationValues"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Serialization Round-Trip*)
VerificationTest[
    Module[ { opts, json, parsed },
        opts = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local", "TimeConstraint" -> 120 |> |>;
        json = Wolfram`AgentTools`Common`toolOptionsJSONString @ opts;
        parsed = Wolfram`AgentTools`Server`Shared`Private`parseToolOptions @ json;
        Block[ { Wolfram`AgentTools`Common`$toolOptions = parsed },
            Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "Method" ]
        ]
    ],
    "Local",
    TestID -> "RoundTrip-MethodPreserved"
]

VerificationTest[
    Module[ { opts, json, parsed },
        opts = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local", "TimeConstraint" -> 120 |> |>;
        json = Wolfram`AgentTools`Common`toolOptionsJSONString @ opts;
        parsed = Wolfram`AgentTools`Server`Shared`Private`parseToolOptions @ json;
        Block[ { Wolfram`AgentTools`Common`$toolOptions = parsed },
            Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ]
        ]
    ],
    120,
    TestID -> "RoundTrip-TimeConstraintPreserved"
]

VerificationTest[
    Module[ { opts, json, parsed },
        opts = <| "WolframLanguageContext" -> <| "MaxItems" -> 5 |> |>;
        json = Wolfram`AgentTools`Common`toolOptionsJSONString @ opts;
        parsed = Wolfram`AgentTools`Server`Shared`Private`parseToolOptions @ json;
        Block[ { Wolfram`AgentTools`Common`$toolOptions = parsed },
            Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageContext", "MaxItems" ]
        ]
    ],
    5,
    TestID -> "RoundTrip-MaxItemsPreserved"
]

VerificationTest[
    Module[ { opts, json, parsed },
        opts = <|
            "WolframLanguageEvaluator" -> <| "Method" -> "Local" |>,
            "WolframLanguageContext"   -> <| "MaxItems" -> 20 |>
        |>;
        json = Wolfram`AgentTools`Common`toolOptionsJSONString @ opts;
        parsed = Wolfram`AgentTools`Server`Shared`Private`parseToolOptions @ json;
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
    TestID -> "RoundTrip-MultipleToolsPreserved"
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
    TestID -> "InstallMCPServer-ToolOptionsEnvVarExists"
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
    TestID   -> "InstallMCPServer-ToolOptionsRoundTrip"
]

(* Values that JSON can't represent survive the round trip through the server configuration, and strings stay strings: *)
VerificationTest[
    Module[ { configFile, name, server, opts, result, data, env },
        configFile = File @ FileNameJoin @ { $TemporaryDirectory, StringJoin[ "mcp_test_toolOpts4_", CreateUUID[], ".json" ] };
        name = StringJoin[ "TestServer_ToolOpts4_", CreateUUID[] ];
        server = CreateMCPServer[
            name,
            LLMConfiguration @ <| "Tools" -> { LLMTool[ "PrimeFinder", { "n" -> "Integer" }, Prime[ #n ] & ] } |>
        ];
        opts = <|
            "WolframLanguageEvaluator" -> <|
                "Method"            -> "Automatic",
                "ImageExportMethod" -> None,
                "MaxSessionCount"   -> Infinity,
                "MaxSessionAge"     -> Quantity[ 2, "Weeks" ]
            |>
        |>;
        result = InstallMCPServer[ configFile, server, "ToolOptions" -> opts, "VerifyLLMKit" -> False ];
        data = Developer`ReadRawJSONString @ ReadString @ First @ configFile;
        env = data[ "mcpServers", name, "env" ];
        UninstallMCPServer[ configFile, server ];
        DeleteObject @ server;
        Quiet @ DeleteFile @ First @ configFile;
        Wolfram`AgentTools`Server`Shared`Private`parseToolOptions @ env[ "MCP_TOOL_OPTIONS" ] === opts
    ],
    True,
    TestID -> "InstallMCPServer-ToolOptionsNonJSONValuesRoundTrip"
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
    TestID -> "InstallMCPServer-EmptyToolOptionsNoEnvVar"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*validateToolOptions*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[ <| |>, MCPServerObject[ "Wolfram" ] ],
    <| |>,
    TestID -> "ValidateToolOptions-Empty"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |>,
        MCPServerObject[ "Wolfram" ]
    ],
    KeyValuePattern[ "WolframLanguageEvaluator" -> KeyValuePattern[ "Method" -> "Local" ] ],
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-ValidOptions"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[ "not an association", MCPServerObject[ "Wolfram" ] ],
    <| |>,
    { AgentTools::InvalidToolOptions },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-InvalidType"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "NonexistentTool" -> <| "Foo" -> "Bar" |> |>,
        MCPServerObject[ "Wolfram" ]
    ],
    KeyValuePattern[ "NonexistentTool" -> KeyValuePattern[ "Foo" -> "Bar" ] ],
    { AgentTools::UnrecognizedToolOption },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-UnrecognizedToolName"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> <| "NonexistentOption" -> "value" |> |>,
        MCPServerObject[ "Wolfram" ]
    ],
    KeyValuePattern[ "WolframLanguageEvaluator" -> KeyValuePattern[ "NonexistentOption" -> "value" ] ],
    { AgentTools::UnrecognizedToolOptionName },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-UnrecognizedOptionName"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> 123 |>,
        MCPServerObject[ "Wolfram" ]
    ],
    <| |>,
    { AgentTools::InvalidToolOptionValue },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-NonAssociationValue"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> "not an association", "WolframLanguageContext" -> <| "MaxItems" -> 5 |> |>,
        MCPServerObject[ "Wolfram" ]
    ],
    <| "WolframLanguageContext" -> <| "MaxItems" -> 5 |> |>,
    { AgentTools::InvalidToolOptionValue },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-MixedValidAndInvalid"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> True |>,
        MCPServerObject[ "Wolfram" ]
    ],
    <| |>,
    { AgentTools::InvalidToolOptionValue },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-BooleanValue"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$toolOptions Initialization*)
VerificationTest[
    Wolfram`AgentTools`Common`$toolOptions,
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "ToolOptionsInitialized"
]

(* :!CodeAnalysis::EndBlock:: *)
