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
        "Method"            -> Automatic,
        "ImageExportMethod" -> None,
        "TimeConstraint"    -> 60,
        "MaxCharacterCount" -> 10000
    },
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-WolframLanguageEvaluator@@Tests/ToolOptions.wlt:38,1-48,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions[ "WolframLanguageContext" ],
    KeyValuePattern[ "MaxItems" -> 10 ],
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-WolframLanguageContext@@Tests/ToolOptions.wlt:50,1-55,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions[ "WolframAlphaContext" ],
    KeyValuePattern @ {
        "MaxItems"                     -> Automatic,
        "IncludeWolframLanguageResults" -> Automatic
    },
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-WolframAlphaContext@@Tests/ToolOptions.wlt:57,1-65,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`$defaultToolOptions[ "WolframContext" ],
    KeyValuePattern @ {
        "WolframLanguageMaxItems" -> 10,
        "WolframAlphaMaxItems"    -> Automatic
    },
    SameTest -> MatchQ,
    TestID   -> "DefaultToolOptions-WolframContext@@Tests/ToolOptions.wlt:67,1-75,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*toolOptionValue*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "Method" ]
    ],
    Automatic,
    TestID -> "ToolOptionValue-FallbackToDefault@@Tests/ToolOptions.wlt:80,1-86,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ]
    ],
    60,
    TestID -> "ToolOptionValue-FallbackToDefault-TimeConstraint@@Tests/ToolOptions.wlt:88,1-94,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "MaxCharacterCount" ]
    ],
    10000,
    TestID -> "ToolOptionValue-FallbackToDefault-MaxCharacterCount@@Tests/ToolOptions.wlt:96,1-102,2"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageEvaluator" -> <| "MaxCharacterCount" -> 100000 |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "MaxCharacterCount" ]
    ],
    100000,
    TestID -> "ToolOptionValue-UserOverride-MaxCharacterCount@@Tests/ToolOptions.wlt:104,1-111,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageContext", "MaxItems" ]
    ],
    10,
    TestID -> "ToolOptionValue-FallbackToDefault-MaxItems@@Tests/ToolOptions.wlt:113,1-119,2"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "Method" ]
    ],
    "Local",
    TestID -> "ToolOptionValue-UserOverride@@Tests/ToolOptions.wlt:121,1-128,2"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ]
    ],
    60,
    TestID -> "ToolOptionValue-UserOverridePartial-FallbackForOtherKeys@@Tests/ToolOptions.wlt:130,1-137,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "NonexistentTool", "SomeOption" ]
    ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "ToolOptionValue-MissingTool@@Tests/ToolOptions.wlt:139,1-146,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$toolOptions = <| |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "NonexistentOption" ]
    ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "ToolOptionValue-MissingOption@@Tests/ToolOptions.wlt:148,1-155,2"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageEvaluator" -> <| "TimeConstraint" -> 120 |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ]
    ],
    120,
    TestID -> "ToolOptionValue-CustomTimeConstraint@@Tests/ToolOptions.wlt:157,1-164,2"
]

VerificationTest[
    Block[
        { Wolfram`AgentTools`Common`$toolOptions = <| "WolframLanguageContext" -> <| "MaxItems" -> 5 |> |> },
        Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageContext", "MaxItems" ]
    ],
    5,
    TestID -> "ToolOptionValue-CustomMaxItems@@Tests/ToolOptions.wlt:166,1-173,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*parseToolOptions*)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[ $Failed ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-Failed@@Tests/ToolOptions.wlt:178,1-183,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[ $Failed ],
    _Association,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-FailedReturnsAssociation@@Tests/ToolOptions.wlt:185,1-190,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[ "" ],
    _Association,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-EmptyString@@Tests/ToolOptions.wlt:192,1-197,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[ "invalid json" ],
    _Association,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-InvalidJSON@@Tests/ToolOptions.wlt:199,1-204,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[
        "{\"WolframLanguageEvaluator\":{\"Method\":\"Local\"}}"
    ],
    KeyValuePattern[ "WolframLanguageEvaluator" -> KeyValuePattern[ "Method" -> "Local" ] ],
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-ValidJSON@@Tests/ToolOptions.wlt:206,1-213,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[
        "{\"WolframLanguageEvaluator\":{\"ImageExportMethod\":\"None\",\"Method\":\"Automatic\"}}"
    ],
    KeyValuePattern[
        "WolframLanguageEvaluator" -> KeyValuePattern @ { "ImageExportMethod" -> None, "Method" -> Automatic }
    ],
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-SymbolConversion@@Tests/ToolOptions.wlt:215,1-224,2"
]

(* Values that JSON can't represent are written as InputForm strings (see jsonConvert) and restored when parsed: *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[
        "{\"Tool\":{\"A\":[\"All\",\"Automatic\",\"C:/x\"],\"B\":\"Infinity\",\"C\":\"Quantity[2, \\\"Weeks\\\"]\"}}"
    ],
    <| "Tool" -> <| "A" -> { All, Automatic, "C:/x" }, "B" -> Infinity, "C" -> Quantity[ 2, "Weeks" ] |> |>,
    SameTest -> SameQ,
    TestID   -> "ParseToolOptions-InputFormStrings@@Tests/ToolOptions.wlt:227,1-234,2"
]

(* Strings that only look like a Quantity are never evaluated: *)
VerificationTest[
    Module[ { file },
        file = FileNameJoin @ { $TemporaryDirectory, "parseQuantityString_" <> CreateUUID[ ] };
        {
            Wolfram`AgentTools`Server`Shared`Private`parseQuantityString[
                "Quantity[Put[1, \"" <> StringReplace[ file, "\\" -> "/" ] <> "\"], \"Weeks\"]"
            ],
            Wolfram`AgentTools`Server`Shared`Private`parseQuantityString[ "Quantity[ invalid" ],
            FileExistsQ @ file
        }
    ],
    { _String? (StringStartsQ[ "Quantity[Put[" ]), "Quantity[ invalid", False },
    SameTest -> MatchQ,
    TestID   -> "ParseQuantityString-NotEvaluated@@Tests/ToolOptions.wlt:237,1-251,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`parseToolOptions[
        "{\"WolframLanguageEvaluator\":123,\"WolframAlphaContext\":{\"MaxItems\":3}}"
    ],
    <| "WolframAlphaContext" -> <| "MaxItems" -> 3 |> |>,
    SameTest -> MatchQ,
    TestID   -> "ParseToolOptions-Non-AssociationValues@@Tests/ToolOptions.wlt:253,1-260,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Serialization Round-Trip*)
VerificationTest[
    Module[ { opts, json, parsed },
        opts = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local", "TimeConstraint" -> 120 |> |>;
        json = Developer`WriteRawJSONString[ opts, "Compact" -> True ];
        parsed = Wolfram`AgentTools`Server`Shared`Private`parseToolOptions @ json;
        Block[ { Wolfram`AgentTools`Common`$toolOptions = parsed },
            Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "Method" ]
        ]
    ],
    "Local",
    TestID -> "RoundTrip-MethodPreserved@@Tests/ToolOptions.wlt:265,1-276,2"
]

VerificationTest[
    Module[ { opts, json, parsed },
        opts = <| "WolframLanguageEvaluator" -> <| "Method" -> "Local", "TimeConstraint" -> 120 |> |>;
        json = Developer`WriteRawJSONString[ opts, "Compact" -> True ];
        parsed = Wolfram`AgentTools`Server`Shared`Private`parseToolOptions @ json;
        Block[ { Wolfram`AgentTools`Common`$toolOptions = parsed },
            Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ]
        ]
    ],
    120,
    TestID -> "RoundTrip-TimeConstraintPreserved@@Tests/ToolOptions.wlt:278,1-289,2"
]

VerificationTest[
    Module[ { opts, json, parsed },
        opts = <| "WolframLanguageContext" -> <| "MaxItems" -> 5 |> |>;
        json = Developer`WriteRawJSONString[ opts, "Compact" -> True ];
        parsed = Wolfram`AgentTools`Server`Shared`Private`parseToolOptions @ json;
        Block[ { Wolfram`AgentTools`Common`$toolOptions = parsed },
            Wolfram`AgentTools`Common`toolOptionValue[ "WolframLanguageContext", "MaxItems" ]
        ]
    ],
    5,
    TestID -> "RoundTrip-MaxItemsPreserved@@Tests/ToolOptions.wlt:291,1-302,2"
]

VerificationTest[
    Module[ { opts, json, parsed },
        opts = <|
            "WolframLanguageEvaluator" -> <| "Method" -> "Local" |>,
            "WolframLanguageContext"   -> <| "MaxItems" -> 20 |>
        |>;
        json = Developer`WriteRawJSONString[ opts, "Compact" -> True ];
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
    TestID -> "RoundTrip-MultipleToolsPreserved@@Tests/ToolOptions.wlt:304,1-323,2"
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
    TestID -> "InstallMCPServer-ToolOptionsEnvVarExists@@Tests/ToolOptions.wlt:328,1-348,2"
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
    TestID   -> "InstallMCPServer-ToolOptionsRoundTrip@@Tests/ToolOptions.wlt:350,1-372,2"
]

(* Values that JSON can't represent survive the round trip through the server configuration: *)
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
                "ImageExportMethod" -> None,
                "MaxSessionCount"   -> Infinity,
                "MaxSessionAge"     -> Quantity[ 2, "Weeks" ]
            |>
        |>;
        result = InstallMCPServer[ configFile, server, "ToolOptions" -> opts, "VerifyLLMKit" -> False ];
        data = Developer`ReadRawJSONString @ ReadString @ First @ configFile;
        env = data[ "mcpServers", name, "env" ];
        Quiet @ DeleteFile @ First @ configFile;
        Wolfram`AgentTools`Server`Shared`Private`parseToolOptions @ env[ "MCP_TOOL_OPTIONS" ] === opts
    ],
    True,
    TestID -> "InstallMCPServer-ToolOptionsNonJSONValuesRoundTrip@@Tests/ToolOptions.wlt:375,1-398,2"
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
    TestID -> "InstallMCPServer-EmptyToolOptionsNoEnvVar@@Tests/ToolOptions.wlt:400,1-420,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*validateToolOptions*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[ <| |>, MCPServerObject[ "Wolfram" ] ],
    <| |>,
    TestID -> "ValidateToolOptions-Empty@@Tests/ToolOptions.wlt:425,1-429,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |>,
        MCPServerObject[ "Wolfram" ]
    ],
    KeyValuePattern[ "WolframLanguageEvaluator" -> KeyValuePattern[ "Method" -> "Local" ] ],
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-ValidOptions@@Tests/ToolOptions.wlt:431,1-439,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[ "not an association", MCPServerObject[ "Wolfram" ] ],
    <| |>,
    { AgentTools::InvalidToolOptions },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-InvalidType@@Tests/ToolOptions.wlt:441,1-447,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "NonexistentTool" -> <| "Foo" -> "Bar" |> |>,
        MCPServerObject[ "Wolfram" ]
    ],
    KeyValuePattern[ "NonexistentTool" -> KeyValuePattern[ "Foo" -> "Bar" ] ],
    { AgentTools::UnrecognizedToolOption },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-UnrecognizedToolName@@Tests/ToolOptions.wlt:449,1-458,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> <| "NonexistentOption" -> "value" |> |>,
        MCPServerObject[ "Wolfram" ]
    ],
    KeyValuePattern[ "WolframLanguageEvaluator" -> KeyValuePattern[ "NonexistentOption" -> "value" ] ],
    { AgentTools::UnrecognizedToolOptionName },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-UnrecognizedOptionName@@Tests/ToolOptions.wlt:460,1-469,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> 123 |>,
        MCPServerObject[ "Wolfram" ]
    ],
    <| |>,
    { AgentTools::InvalidToolOptionValue },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-NonAssociationValue@@Tests/ToolOptions.wlt:471,1-480,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> "not an association", "WolframLanguageContext" -> <| "MaxItems" -> 5 |> |>,
        MCPServerObject[ "Wolfram" ]
    ],
    <| "WolframLanguageContext" -> <| "MaxItems" -> 5 |> |>,
    { AgentTools::InvalidToolOptionValue },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-MixedValidAndInvalid@@Tests/ToolOptions.wlt:482,1-491,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`validateToolOptions[
        <| "WolframLanguageEvaluator" -> True |>,
        MCPServerObject[ "Wolfram" ]
    ],
    <| |>,
    { AgentTools::InvalidToolOptionValue },
    SameTest -> MatchQ,
    TestID   -> "ValidateToolOptions-BooleanValue@@Tests/ToolOptions.wlt:493,1-502,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$toolOptions Initialization*)
VerificationTest[
    Wolfram`AgentTools`Common`$toolOptions,
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "ToolOptionsInitialized@@Tests/ToolOptions.wlt:507,1-512,2"
]

(* :!CodeAnalysis::EndBlock:: *)
