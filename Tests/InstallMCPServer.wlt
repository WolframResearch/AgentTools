(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/InstallMCPServer.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/InstallMCPServer.wlt:11,1-16,2"
]

If[ StringQ @ Environment[ "GITHUB_ACTIONS" ], SetOptions[ InstallMCPServer, "VerifyLLMKit" -> False ] ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Helper Functions*)

(* Setup a temporary file to use for testing installations *)
testConfigFile = Function[
    File @ FileNameJoin @ { $TemporaryDirectory, StringJoin["mcp_test_config_", CreateUUID[], ".json"] }
];

(* Clean up any test files that might be created *)
cleanupTestFiles = Function[files,
    DeleteFile /@ Select[Flatten[{files}], FileExistsQ]
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Basic Examples*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install and Uninstall Custom Server*)
VerificationTest[
    configFile = testConfigFile[];
    name = StringJoin["TestServer_", CreateUUID[]];
    server = CreateMCPServer[
        name,
        LLMConfiguration @ <| "Tools" -> { LLMTool[ "PrimeFinder", { "n" -> "Integer" }, Prime[ #n ] & ] } |>
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-CreateTestServer@@Tests/InstallMCPServer.wlt:41,1-51,2"
]

VerificationTest[
    result = InstallMCPServer[configFile, server],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-FileLocation@@Tests/InstallMCPServer.wlt:53,1-58,2"
]

VerificationTest[
    FileExistsQ[configFile],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-ConfigFileExists@@Tests/InstallMCPServer.wlt:60,1-65,2"
]

VerificationTest[
    jsonContent = Import[configFile, "RawJSON"];
    KeyExistsQ[jsonContent, "mcpServers"] && KeyExistsQ[jsonContent["mcpServers"], name],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-VerifyConfigContent@@Tests/InstallMCPServer.wlt:67,1-73,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[configFile, server],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Uninstall@@Tests/InstallMCPServer.wlt:75,1-80,2"
]

VerificationTest[
    jsonContent = Import[configFile, "RawJSON"];
    KeyExistsQ[jsonContent, "mcpServers"] && !KeyExistsQ[jsonContent["mcpServers"], name],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-VerifyUninstall@@Tests/InstallMCPServer.wlt:82,1-88,2"
]

VerificationTest[
    DeleteObject[server];
    cleanupTestFiles[configFile],
    {Null},
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-CleanupTestServer@@Tests/InstallMCPServer.wlt:90,1-96,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install with Relative File Path*)
VerificationTest[
    WithCleanup[
        SetDirectory[ $TemporaryDirectory ],
        Module[ { file },
            file = "mcp_test_relative_" <> CreateUUID[] <> ".json";
            WithCleanup[
                Quiet @ InstallMCPServer[ File[ file ], "WolframLanguage", "VerifyLLMKit" -> False ],
                If[ FileExistsQ @ ExpandFileName @ file, DeleteFile @ ExpandFileName @ file ]
            ]
        ],
        ResetDirectory[]
    ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-RelativeFilePath-GH#108@@Tests/InstallMCPServer.wlt:101,1-116,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install into Empty Config File*)
VerificationTest[
    Module[ { file },
        file = FileNameJoin @ { $TemporaryDirectory, "mcp_test_empty_" <> CreateUUID[] <> ".json" };
        WithCleanup[
            CreateFile @ file;
            InstallMCPServer[ File[ file ], "WolframLanguage", "VerifyLLMKit" -> False ],
            Quiet @ DeleteFile @ file
        ]
    ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-EmptyConfigFile@@Tests/InstallMCPServer.wlt:121,1-133,2"
]

(* Files with only whitespace should be treated as empty *)
VerificationTest[
    Module[ { whitespace, file },
        whitespace = StringJoin @ RandomChoice[ { "\t", "\n", "\r", " " }, RandomInteger @ { 1, 10 } ];
        WithCleanup[
            file = Export[ CreateFile[ ], whitespace, "String" ];
            InstallMCPServer[ File[ file ], "WolframLanguage", "VerifyLLMKit" -> False ],
            Quiet @ DeleteFile @ file
        ]
    ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-EmptyConfigFile-Whitespace@@Tests/InstallMCPServer.wlt:136,1-148,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Predefined Server by Name*)
VerificationTest[
    configFile = testConfigFile[];
    installResult = InstallMCPServer[configFile, "WolframLanguage"],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-PredefinedServer@@Tests/InstallMCPServer.wlt:153,1-159,2"
]

VerificationTest[
    jsonContent = Import[configFile, "RawJSON"];
    KeyExistsQ[jsonContent, "mcpServers"] && KeyExistsQ[jsonContent["mcpServers"], "Wolfram"],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-VerifyPredefinedServer@@Tests/InstallMCPServer.wlt:161,1-167,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[configFile, "WolframLanguage"],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-UninstallPredefinedServer@@Tests/InstallMCPServer.wlt:169,1-174,2"
]

VerificationTest[
    cleanupTestFiles[configFile],
    {Null},
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-CleanupPredefinedServer@@Tests/InstallMCPServer.wlt:176,1-181,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Multiple Server Installations*)
VerificationTest[
    configFile = testConfigFile[];
    installAlpha = InstallMCPServer[configFile, "WolframAlpha"];
    installLang = InstallMCPServer[configFile, "WolframLanguage"],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-MultipleServers@@Tests/InstallMCPServer.wlt:186,1-193,2"
]

VerificationTest[
    jsonContent = Import[configFile, "RawJSON"];
    KeyExistsQ[jsonContent["mcpServers"], "Wolfram"] &&
    Length[Keys[jsonContent["mcpServers"]]] === 1,
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-VerifyMultipleBuiltInServersShareKey@@Tests/InstallMCPServer.wlt:195,1-202,2"
]

VerificationTest[
    UninstallMCPServer[configFile];
    jsonContent = Import[configFile, "RawJSON"];
    jsonContent["mcpServers"] === <| |>,
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-UninstallAll@@Tests/InstallMCPServer.wlt:204,1-211,2"
]

VerificationTest[
    cleanupTestFiles[configFile],
    {Null},
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-CleanupMultipleServers@@Tests/InstallMCPServer.wlt:213,1-218,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Environment Variables*)
VerificationTest[
    configFile = testConfigFile[];
    installResult = InstallMCPServer[
        configFile,
        "WolframLanguage",
        ProcessEnvironment -> <|"TEST_VAR" -> "test_value"|>
    ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-WithEnvironment@@Tests/InstallMCPServer.wlt:223,1-233,2"
]

VerificationTest[
    jsonContent = Import[configFile, "RawJSON"];
    envVars = jsonContent["mcpServers"]["Wolfram"]["env"];
    KeyExistsQ[envVars, "TEST_VAR"] && envVars["TEST_VAR"] === "test_value",
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-VerifyEnvironmentVars@@Tests/InstallMCPServer.wlt:235,1-242,2"
]

VerificationTest[
    UninstallMCPServer[configFile, "WolframLanguage"];
    cleanupTestFiles[configFile],
    {Null},
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-CleanupEnvironment@@Tests/InstallMCPServer.wlt:244,1-250,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install from Association*)
VerificationTest[
    configFile = testConfigFile[];
    name = CreateUUID[];
    config = <| "Tools" -> { LLMTool[ "SquareNumber", { "x" -> "Number" }, #x^2 & ] } |>;
    server = CreateMCPServer[name, config];
    installResult = InstallMCPServer[configFile, server],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-FromAssociation@@Tests/InstallMCPServer.wlt:255,1-264,2"
]

VerificationTest[
    jsonContent = Import[configFile, "RawJSON"];
    KeyExistsQ[jsonContent, "mcpServers"] && KeyExistsQ[jsonContent["mcpServers"], name],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-VerifyAssociationServer@@Tests/InstallMCPServer.wlt:266,1-272,2"
]

VerificationTest[
    UninstallMCPServer[configFile, name];
    DeleteObject[server];
    cleanupTestFiles[configFile],
    {Null},
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-CleanupAssociation@@Tests/InstallMCPServer.wlt:274,1-281,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Named Client Installations*)
VerificationTest[
    (* Create a temporary .claude.json-like file with existing data *)
    configFile = testConfigFile[];
    Export[configFile, <|"numStartups" -> 1, "mcpServers" -> <| |>|>, "JSON"];
    installResult = InstallMCPServer[configFile, "WolframLanguage"],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-ClaudeCodeLike@@Tests/InstallMCPServer.wlt:286,1-294,2"
]

VerificationTest[
    (* Verify the server was added and other data preserved *)
    jsonContent = Import[configFile, "RawJSON"];
    KeyExistsQ[jsonContent, "mcpServers"] &&
    KeyExistsQ[jsonContent["mcpServers"], "Wolfram"] &&
    KeyExistsQ[jsonContent, "numStartups"] &&
    jsonContent["numStartups"] === 1,
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-PreservesOtherData@@Tests/InstallMCPServer.wlt:296,1-306,2"
]

VerificationTest[
    (* Install a second server to verify multiple installations work *)
    installResult2 = InstallMCPServer[configFile, "WolframAlpha"];
    jsonContent = Import[configFile, "RawJSON"];
    Length[Keys[jsonContent["mcpServers"]]] === 1 &&
    KeyExistsQ[jsonContent["mcpServers"], "Wolfram"],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-MultipleBuiltInOverwrite@@Tests/InstallMCPServer.wlt:308,1-317,2"
]

VerificationTest[
    UninstallMCPServer[configFile];
    cleanupTestFiles[configFile],
    {Null},
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-CleanupClaudeCodeLike@@Tests/InstallMCPServer.wlt:319,1-325,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Cases*)
VerificationTest[
    configFile = testConfigFile[];
    Export[configFile, "{\"invalidJSON\":true", "String"];
    InstallMCPServer[configFile, "WolframLanguage"],
    _Failure,
    {InstallMCPServer::InvalidMCPConfiguration},
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-InvalidJSON@@Tests/InstallMCPServer.wlt:330,1-338,2"
]

VerificationTest[
    configFile = testConfigFile[];
    Export[configFile, "{}", "JSON"];
    InstallMCPServer[configFile, "NonExistentServer"],
    _Failure,
    {InstallMCPServer::MCPServerNotFound},
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-NonExistentServer@@Tests/InstallMCPServer.wlt:340,1-348,2"
]

VerificationTest[
    cleanupTestFiles[configFile],
    {Null},
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-CleanupErrorTests@@Tests/InstallMCPServer.wlt:350,1-355,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Install Location Resolution*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Antigravity", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Antigravity-Windows@@Tests/InstallMCPServer.wlt:364,1-369,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Antigravity", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Antigravity-MacOSX@@Tests/InstallMCPServer.wlt:371,1-376,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Antigravity", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Antigravity-Unix@@Tests/InstallMCPServer.wlt:378,1-383,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Antigravity" ],
    "Antigravity",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Antigravity@@Tests/InstallMCPServer.wlt:385,1-390,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "GoogleAntigravity" ],
    "Antigravity",
    SameTest -> Equal,
    TestID   -> "ToInstallName-GoogleAntigravity@@Tests/InstallMCPServer.wlt:392,1-397,2"
]

(* Antigravity install path detection: when the 2.0 installer migrates a pre-2.0 IDE
   forward it drops ~/.gemini/config/.migrated; the helper must route to ~/.gemini/config/
   in that case and to the historical ~/.gemini/antigravity/ otherwise. We exercise both
   branches by stubbing FileExistsQ for the duration of the test. *)
VerificationTest[
    Module[ { migrated, fresh },
        Block[
            { FileExistsQ },
            FileExistsQ[ p_ ] := StringEndsQ[ p, ".migrated" ];
            migrated = Wolfram`AgentTools`SupportedClients`Private`antigravityInstallLocation[ ];
            FileExistsQ[ p_ ] := False;
            fresh = Wolfram`AgentTools`SupportedClients`Private`antigravityInstallLocation[ ]
        ];
        { Last @ migrated, FileNameTake[ FileNameJoin @ migrated, -2 ],
          Last @ fresh,    FileNameTake[ FileNameJoin @ fresh, -2 ] }
    ],
    {
        "mcp_config.json", FileNameJoin @ { "config",      "mcp_config.json" },
        "mcp_config.json", FileNameJoin @ { "antigravity", "mcp_config.json" }
    },
    SameTest -> Equal,
    TestID   -> "AntigravityInstallLocation-MigratedVsFresh@@Tests/InstallMCPServer.wlt:398,1-417,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AntigravityCLI", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AntigravityCLI-Windows@@Tests/InstallMCPServer.wlt:419,1-424,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AntigravityCLI", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AntigravityCLI-MacOSX@@Tests/InstallMCPServer.wlt:426,1-431,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AntigravityCLI", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AntigravityCLI-Unix@@Tests/InstallMCPServer.wlt:433,1-438,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "AntigravityCLI" ],
    "Antigravity CLI",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-AntigravityCLI@@Tests/InstallMCPServer.wlt:440,1-445,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "GoogleAntigravityCLI" ],
    "AntigravityCLI",
    SameTest -> Equal,
    TestID   -> "ToInstallName-GoogleAntigravityCLI@@Tests/InstallMCPServer.wlt:447,1-452,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*projectInstallLocation*)

(* Tests for project-scoped install locations *)
VerificationTest[
    Module[ { path, result },
        path = FileNameJoin @ { $TemporaryDirectory, "TestProject" };
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "ClaudeCode", path ];
        FileNameTake[ First @ result, -1 ]
    ],
    ".mcp.json",
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-ClaudeCode@@Tests/InstallMCPServer.wlt:404,1-413,2"
]

VerificationTest[
    Module[ { result },
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "ClaudeCode", File[ "AgentTools" ] ];
        FileNameTake[ First @ result, -1 ]
    ],
    ".mcp.json",
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-ClaudeCode-FileWrapper@@Tests/InstallMCPServer.wlt:415,1-423,2"
]

VerificationTest[
    Module[ { path, result },
        path = FileNameJoin @ { $TemporaryDirectory, "TestProject" };
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "OpenCode", path ];
        FileNameTake[ First @ result, -1 ]
    ],
    "opencode.json",
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-OpenCode@@Tests/InstallMCPServer.wlt:425,1-434,2"
]

VerificationTest[
    Module[ { path, result },
        path = FileNameJoin @ { $TemporaryDirectory, "TestProject" };
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "Codex", path ];
        FileNameTake[ First @ result, -2 ]
    ],
    FileNameJoin @ { ".codex", "config.toml" },
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-Codex@@Tests/InstallMCPServer.wlt:436,1-445,2"
]

VerificationTest[
    Module[ { path, result },
        path = FileNameJoin @ { $TemporaryDirectory, "TestProject" };
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "AntigravityCLI", path ];
        FileNameTake[ First @ result, -2 ]
    ],
    FileNameJoin @ { ".agents", "mcp_config.json" },
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-AntigravityCLI@@Tests/InstallMCPServer.wlt:447,1-456,2"
]

VerificationTest[
    Module[ { path, result },
        path = FileNameJoin @ { $TemporaryDirectory, "TestProject" };
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "VisualStudioCode", path ];
        FileNameTake[ First @ result, -2 ]
    ],
    FileNameJoin @ { ".vscode", "mcp.json" },
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-VisualStudioCode@@Tests/InstallMCPServer.wlt:447,1-456,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways[
        Wolfram`AgentTools`Common`projectInstallLocation[ "ClaudeCode", Symbol[ "xyz" ] ]
    ],
    _Failure,
    { AgentTools::InvalidProjectDirectory },
    SameTest -> MatchQ,
    TestID   -> "ProjectInstallLocation-InvalidDirectory-Symbol@@Tests/InstallMCPServer.wlt:458,1-466,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways[
        Wolfram`AgentTools`Common`projectInstallLocation[ "ClaudeCode", 123 ]
    ],
    _Failure,
    { AgentTools::InvalidProjectDirectory },
    SameTest -> MatchQ,
    TestID   -> "ProjectInstallLocation-InvalidDirectory-Integer@@Tests/InstallMCPServer.wlt:468,1-476,2"
]

VerificationTest[
    InstallMCPServer[ { "ClaudeCode", Symbol[ "xyz" ] } ],
    _Failure,
    { InstallMCPServer::InvalidProjectDirectory },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-InvalidProjectDirectory@@Tests/InstallMCPServer.wlt:478,1-484,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeDevelopmentArgs*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`makeDevelopmentArgs[ DirectoryName[ $TestFileName, 2 ] ],
    { "-script", _String? FileExistsQ, "-noinit", "-noprompt" },
    SameTest -> MatchQ,
    TestID   -> "MakeDevelopmentArgs-ValidPath@@Tests/InstallMCPServer.wlt:489,1-494,2"
]

VerificationTest[
    configFile = testConfigFile[];
    invalidPath = FileNameJoin @ { $TemporaryDirectory, CreateUUID[ "InvalidPath-" ] };
    InstallMCPServer[ configFile, "DevelopmentMode" -> invalidPath, "VerifyLLMKit" -> False ],
    Failure[ "InstallMCPServer::DevelopmentModeUnavailable", _ ],
    { InstallMCPServer::DevelopmentModeUnavailable },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-DevelopmentMode-InvalidPath@@Tests/InstallMCPServer.wlt:496,1-504,2"
]

VerificationTest[
    configFile = testConfigFile[];
    InstallMCPServer[ configFile, "DevelopmentMode" -> InvalidValue, "VerifyLLMKit" -> False ],
    Failure[ "InstallMCPServer::InvalidDevelopmentMode", _ ],
    { InstallMCPServer::InvalidDevelopmentMode },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-DevelopmentMode-InvalidValue@@Tests/InstallMCPServer.wlt:506,1-513,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DevelopmentMode Option*)
VerificationTest[
    MemberQ[ Keys @ Options @ InstallMCPServer, "DevelopmentMode" ],
    True,
    TestID -> "DevelopmentMode-OptionExists@@Tests/InstallMCPServer.wlt:518,1-522,2"
]

VerificationTest[
    configFile = testConfigFile[];
    InstallMCPServer[ configFile, "DevelopmentMode" -> DirectoryName[ $TestFileName, 2 ], "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-DevelopmentMode-Success@@Tests/InstallMCPServer.wlt:524,1-530,2"
]

VerificationTest[
    json = Developer`ReadRawJSONFile @ First @ configFile;
    json[ "mcpServers", "Wolfram", "args" ],
    { "-script", _String, "-noinit", "-noprompt" },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-DevelopmentMode-Args@@Tests/InstallMCPServer.wlt:532,1-538,2"
]

VerificationTest[
    cleanupTestFiles[ configFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-DevelopmentMode-Cleanup@@Tests/InstallMCPServer.wlt:540,1-545,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Codex (TOML) Support*)

(* Helper function for TOML test files *)
testTOMLFile = Function[
    File @ FileNameJoin @ { $TemporaryDirectory, StringJoin["mcp_test_config_", CreateUUID[], ".toml"] }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Location for Codex*)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Codex", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Codex-Windows@@Tests/InstallMCPServer.wlt:559,1-564,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Codex", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Codex-MacOSX@@Tests/InstallMCPServer.wlt:566,1-571,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Codex", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Codex-Unix@@Tests/InstallMCPServer.wlt:573,1-578,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "OpenAICodex" ],
    "Codex",
    SameTest -> Equal,
    TestID   -> "ToInstallName-OpenAICodex@@Tests/InstallMCPServer.wlt:583,1-588,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Codex" ],
    "Codex",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Codex@@Tests/InstallMCPServer.wlt:590,1-595,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Codex" ],
    "Codex CLI",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Codex@@Tests/InstallMCPServer.wlt:597,1-602,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TOML Parsing and Writing*)
VerificationTest[
    toml = Wolfram`AgentTools`Common`readTOMLFile @ FileNameJoin @ { $TemporaryDirectory, "nonexistent.toml" };
    toml[ "Data" ],
    <| |>,
    SameTest -> Equal,
    TestID   -> "ReadTOMLFile-NonExistent@@Tests/InstallMCPServer.wlt:607,1-613,2"
]

VerificationTest[
    Module[ { tempFile, content },
        tempFile = First @ testTOMLFile[];
        content = "[section]\nkey = \"value\"\nnumber = 42\nenabled = true\n";
        WriteString[ tempFile, content ];
        Close @ tempFile;
        toml = Wolfram`AgentTools`Common`readTOMLFile @ tempFile;
        DeleteFile @ tempFile;
        toml[ "Data", "section" ]
    ],
    <| "key" -> "value", "number" -> 42, "enabled" -> True |>,
    SameTest -> Equal,
    TestID   -> "ReadTOMLFile-BasicParsing@@Tests/InstallMCPServer.wlt:615,1-628,2"
]

VerificationTest[
    Module[ { tempFile, content },
        tempFile = First @ testTOMLFile[];
        content = "[mcp_servers.TestServer]\ncommand = \"wolfram\"\nargs = [\"-run\", \"test\"]\nenv = { KEY = \"value\" }\nenabled = true\n";
        WriteString[ tempFile, content ];
        Close @ tempFile;
        toml = Wolfram`AgentTools`Common`readTOMLFile @ tempFile;
        DeleteFile @ tempFile;
        toml[ "Data", "mcp_servers", "TestServer" ]
    ],
    <|
        "command" -> "wolfram",
        "args" -> { "-run", "test" },
        "env" -> <| "KEY" -> "value" |>,
        "enabled" -> True
    |>,
    SameTest -> Equal,
    TestID   -> "ReadTOMLFile-MCPServerSection@@Tests/InstallMCPServer.wlt:630,1-648,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Codex Install/Uninstall*)
VerificationTest[
    codexConfigFile = testTOMLFile[];
    (* Use file-based install - TOML format is auto-detected from .toml extension *)
    installResult = InstallMCPServer[ codexConfigFile, "WolframLanguage", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Codex-Basic@@Tests/InstallMCPServer.wlt:653,1-660,2"
]

VerificationTest[
    FileExistsQ[ codexConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-FileExists@@Tests/InstallMCPServer.wlt:662,1-667,2"
]

VerificationTest[
    Module[ { content, toml },
        content = ReadString @ codexConfigFile;
        toml = Wolfram`AgentTools`Common`readTOMLFile @ codexConfigFile;
        KeyExistsQ[ toml[ "Data", "mcp_servers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-VerifyContent@@Tests/InstallMCPServer.wlt:669,1-678,2"
]

VerificationTest[
    Module[ { content },
        content = ReadString @ codexConfigFile;
        StringContainsQ[ content, "[mcp_servers.Wolfram]" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-VerifySectionFormat@@Tests/InstallMCPServer.wlt:680,1-688,2"
]

VerificationTest[
    (* Use file-based uninstall - TOML format is auto-detected from .toml extension *)
    uninstallResult = UninstallMCPServer[ codexConfigFile, "WolframLanguage" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Codex-Basic@@Tests/InstallMCPServer.wlt:690,1-696,2"
]

VerificationTest[
    Module[ { toml },
        toml = Wolfram`AgentTools`Common`readTOMLFile @ codexConfigFile;
        ! KeyExistsQ[ Lookup[ toml[ "Data" ], "mcp_servers", <| |> ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Codex-VerifyRemoval@@Tests/InstallMCPServer.wlt:698,1-706,2"
]

VerificationTest[
    cleanupTestFiles[ codexConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Codex-Cleanup@@Tests/InstallMCPServer.wlt:708,1-713,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Multiple Server Installations (Codex)*)
VerificationTest[
    codexConfigFile = testTOMLFile[];
    (* File-based install with TOML auto-detection *)
    InstallMCPServer[ codexConfigFile, "WolframAlpha", "VerifyLLMKit" -> False ];
    InstallMCPServer[ codexConfigFile, "WolframLanguage", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Codex-MultipleServers@@Tests/InstallMCPServer.wlt:718,1-726,2"
]

VerificationTest[
    Module[ { toml, mcpServers },
        toml = Wolfram`AgentTools`Common`readTOMLFile @ codexConfigFile;
        mcpServers = Lookup[ toml[ "Data" ], "mcp_servers", <| |> ];
        KeyExistsQ[ mcpServers, "Wolfram" ] && Length[ Keys @ mcpServers ] === 1
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-VerifyMultipleBuiltInShareKey@@Tests/InstallMCPServer.wlt:728,1-737,2"
]

VerificationTest[
    cleanupTestFiles[ codexConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Codex-MultipleServers-Cleanup@@Tests/InstallMCPServer.wlt:739,1-744,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Preserve Existing Config (Codex)*)
VerificationTest[
    codexConfigFile = testTOMLFile[];
    Module[ { stream },
        stream = OpenWrite[ First @ codexConfigFile ];
        WriteString[ stream, "# User configuration\nmodel = \"gpt-4\"\nhistory_size = 100\n\n" ];
        Close @ stream
    ];
    (* File-based install with TOML auto-detection *)
    InstallMCPServer[ codexConfigFile, "WolframLanguage", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Codex-PreserveExisting@@Tests/InstallMCPServer.wlt:749,1-761,2"
]

VerificationTest[
    Module[ { content },
        content = ReadString @ codexConfigFile;
        StringContainsQ[ content, "model = \"gpt-4\"" ] &&
        StringContainsQ[ content, "history_size = 100" ] &&
        StringContainsQ[ content, "[mcp_servers.Wolfram]" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-VerifyPreserved@@Tests/InstallMCPServer.wlt:763,1-773,2"
]

VerificationTest[
    cleanupTestFiles[ codexConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Codex-PreserveExisting-Cleanup@@Tests/InstallMCPServer.wlt:775,1-780,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertToCodexFormat*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`convertToCodexFormat @ <|
        "command" -> "wolfram",
        "args" -> { "-run", "test" },
        "env" -> <| "KEY" -> "value" |>
    |>,
    <|
        "command" -> "wolfram",
        "args" -> { "-run", "test" },
        "env" -> <| "KEY" -> "value" |>,
        "enabled" -> True
    |>,
    SameTest -> Equal,
    TestID   -> "ConvertToCodexFormat-Basic@@Tests/InstallMCPServer.wlt:785,1-799,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`convertToCodexFormat @ <|
        "command" -> "wolfram"
    |>,
    <| "command" -> "wolfram", "enabled" -> True |>,
    SameTest -> Equal,
    TestID   -> "ConvertToCodexFormat-MinimalConfig@@Tests/InstallMCPServer.wlt:801,1-808,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Project-Level Codex Install/Uninstall*)
VerificationTest[
    codexProjectDir = FileNameJoin @ { $TemporaryDirectory, "mcp_codex_project_" <> CreateUUID[] };
    codexProjectConfigFile = File @ FileNameJoin @ { codexProjectDir, ".codex", "config.toml" };
    installResult = InstallMCPServer[
        { "Codex", codexProjectDir },
        "WolframLanguage",
        "VerifyLLMKit" -> False
    ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Codex-ProjectInstall@@Tests/InstallMCPServer.wlt:813,1-824,2"
]

VerificationTest[
    FileExistsQ @ codexProjectConfigFile,
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-ProjectConfigExists@@Tests/InstallMCPServer.wlt:826,1-831,2"
]

VerificationTest[
    Module[ { toml },
        toml = Wolfram`AgentTools`Common`readTOMLFile @ codexProjectConfigFile;
        KeyExistsQ[ Lookup[ toml[ "Data" ], "mcp_servers", <| |> ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-ProjectVerifyContent@@Tests/InstallMCPServer.wlt:833,1-841,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ { "Codex", codexProjectDir }, "WolframLanguage" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Codex-ProjectInstall@@Tests/InstallMCPServer.wlt:843,1-848,2"
]

VerificationTest[
    Module[ { toml },
        toml = Wolfram`AgentTools`Common`readTOMLFile @ codexProjectConfigFile;
        ! KeyExistsQ[ Lookup[ toml[ "Data" ], "mcp_servers", <| |> ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Codex-ProjectVerifyRemoval@@Tests/InstallMCPServer.wlt:850,1-858,2"
]

VerificationTest[
    cleanupTestFiles[ codexProjectConfigFile ];
    If[ DirectoryQ @ FileNameJoin @ { codexProjectDir, ".codex" },
        DeleteDirectory[ FileNameJoin @ { codexProjectDir, ".codex" } ]
    ];
    If[ DirectoryQ @ codexProjectDir,
        DeleteDirectory @ codexProjectDir
    ];
    Null,
    Null,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-ProjectCleanup@@Tests/InstallMCPServer.wlt:860,1-872,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Goose (YAML) Support*)

(* Helper function for YAML test files *)
testYAMLFile = Function[
    File @ FileNameJoin @ { $TemporaryDirectory, StringJoin[ "mcp_test_config_", CreateUUID[ ], ".yaml" ] }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Location for Goose*)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Goose", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Goose-Windows@@Tests/InstallMCPServer.wlt:886,1-891,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Goose", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Goose-MacOSX@@Tests/InstallMCPServer.wlt:893,1-898,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Goose", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Goose-Unix@@Tests/InstallMCPServer.wlt:900,1-905,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Display Name*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Goose" ],
    "Goose",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Goose@@Tests/InstallMCPServer.wlt:910,1-915,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertToGooseFormat*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`convertToGooseFormat @ <|
        "command" -> "wolfram",
        "args"    -> { "-run", "test" },
        "env"     -> <| "K" -> "v" |>
    |>,
    <|
        "cmd"     -> "wolfram",
        "args"    -> { "-run", "test" },
        "enabled" -> True,
        "envs"    -> <| "K" -> "v" |>,
        "type"    -> "stdio",
        "timeout" -> 300
    |>,
    SameTest -> Equal,
    TestID   -> "ConvertToGooseFormat-Basic@@Tests/InstallMCPServer.wlt:920,1-936,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`convertToGooseFormat @ <|
        "command" -> "wolfram"
    |>,
    <|
        "cmd"     -> "wolfram",
        "enabled" -> True,
        "type"    -> "stdio",
        "timeout" -> 300
    |>,
    SameTest -> Equal,
    TestID   -> "ConvertToGooseFormat-MinimalConfig@@Tests/InstallMCPServer.wlt:938,1-950,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Goose Install/Uninstall*)
VerificationTest[
    gooseConfigFile = testYAMLFile[ ];
    installResult = InstallMCPServer[ gooseConfigFile, "WolframLanguage", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-Basic@@Tests/InstallMCPServer.wlt:955,1-961,2"
]

VerificationTest[
    FileExistsQ @ gooseConfigFile,
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Goose-FileExists@@Tests/InstallMCPServer.wlt:963,1-968,2"
]

VerificationTest[
    Module[ { yaml },
        yaml = Wolfram`AgentTools`Common`importYAML @ gooseConfigFile;
        AssociationQ @ yaml &&
            AssociationQ @ Lookup[ yaml, "extensions" ] &&
            KeyExistsQ[ yaml[ "extensions" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Goose-VerifyContent@@Tests/InstallMCPServer.wlt:970,1-980,2"
]

VerificationTest[
    Module[ { yaml, server },
        yaml = Wolfram`AgentTools`Common`importYAML @ gooseConfigFile;
        server = yaml[ "extensions", "Wolfram" ];
        AllTrue[
            { "name", "cmd", "args", "enabled", "envs", "type", "timeout" },
            KeyExistsQ[ server, # ] &
        ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Goose-VerifyAllFields@@Tests/InstallMCPServer.wlt:982,1-994,2"
]

VerificationTest[
    Module[ { yaml, server },
        yaml = Wolfram`AgentTools`Common`importYAML @ gooseConfigFile;
        server = yaml[ "extensions", "Wolfram" ];
        server[ "enabled" ] === True &&
            server[ "type" ] === "stdio" &&
            server[ "timeout" ] === 300 &&
            server[ "name" ] === "Wolfram"
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Goose-VerifyFieldValues@@Tests/InstallMCPServer.wlt:996,1-1008,2"
]

VerificationTest[
    Module[ { content },
        content = ReadString @ gooseConfigFile;
        StringContainsQ[ content, "extensions:" ] &&
            StringContainsQ[ content, "cmd:" ] &&
            StringContainsQ[ content, "type: stdio" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Goose-VerifyLiteralYAML@@Tests/InstallMCPServer.wlt:1010,1-1020,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ gooseConfigFile, "WolframLanguage" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Goose-Basic@@Tests/InstallMCPServer.wlt:1022,1-1027,2"
]

VerificationTest[
    Module[ { yaml },
        yaml = Wolfram`AgentTools`Common`importYAML @ gooseConfigFile;
        ! KeyExistsQ[ Lookup[ yaml, "extensions", <| |> ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Goose-VerifyRemoval@@Tests/InstallMCPServer.wlt:1029,1-1037,2"
]

VerificationTest[
    cleanupTestFiles[ gooseConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-Cleanup@@Tests/InstallMCPServer.wlt:1039,1-1044,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Multiple Server Installations (Goose)*)
VerificationTest[
    gooseConfigFile = testYAMLFile[ ];
    InstallMCPServer[ gooseConfigFile, "WolframAlpha", "VerifyLLMKit" -> False ];
    InstallMCPServer[ gooseConfigFile, "WolframLanguage", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-MultipleServers@@Tests/InstallMCPServer.wlt:1049,1-1056,2"
]

VerificationTest[
    Module[ { yaml, extensions },
        yaml = Wolfram`AgentTools`Common`importYAML @ gooseConfigFile;
        extensions = Lookup[ yaml, "extensions", <| |> ];
        KeyExistsQ[ extensions, "Wolfram" ] && Length[ Keys @ extensions ] === 1
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Goose-VerifyMultipleBuiltInShareKey@@Tests/InstallMCPServer.wlt:1058,1-1067,2"
]

VerificationTest[
    cleanupTestFiles[ gooseConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-MultipleServers-Cleanup@@Tests/InstallMCPServer.wlt:1069,1-1074,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Preserve Existing Extension (Goose)*)
VerificationTest[
    gooseConfigFile = testYAMLFile[ ];
    Module[ { stream },
        stream = OpenWrite[ First @ gooseConfigFile ];
        WriteString[
            stream,
            "extensions:\n  other:\n    cmd: foo\n    enabled: true\n    type: stdio\n    timeout: 60\n"
        ];
        Close @ stream
    ];
    InstallMCPServer[ gooseConfigFile, "WolframLanguage", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-PreserveExisting@@Tests/InstallMCPServer.wlt:1079,1-1093,2"
]

VerificationTest[
    Module[ { yaml, extensions },
        yaml = Wolfram`AgentTools`Common`importYAML @ gooseConfigFile;
        extensions = Lookup[ yaml, "extensions", <| |> ];
        KeyExistsQ[ extensions, "other" ] && KeyExistsQ[ extensions, "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Goose-VerifyPreserved@@Tests/InstallMCPServer.wlt:1095,1-1104,2"
]

VerificationTest[
    cleanupTestFiles[ gooseConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-PreserveExisting-Cleanup@@Tests/InstallMCPServer.wlt:1106,1-1111,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Refuse to Overwrite Unparseable YAML (Goose)*)
VerificationTest[
    gooseConfigFile = testYAMLFile[ ];
    (* A file that is just plausible enough to be hand-edited but malformed enough to fail parsing *)
    Module[ { stream },
        stream = OpenWrite @ First @ gooseConfigFile;
        WriteString[ stream, "extensions:\n  Wolfram:\n    cmd: wolfram\n     name: bad-indent\n" ];
        Close @ stream
    ];
    InstallMCPServer[ gooseConfigFile, "WolframLanguage", "VerifyLLMKit" -> False ],
    _Failure,
    { InstallMCPServer::InvalidMCPConfiguration },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-RefusesUnparseableYAML@@Tests/InstallMCPServer.wlt:1116,1-1129,2"
]

VerificationTest[
    Module[ { content },
        content = ReadString @ First @ gooseConfigFile;
        (* The file must NOT have been overwritten *)
        StringContainsQ[ content, "bad-indent" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Goose-PreservesUnparseableYAML@@Tests/InstallMCPServer.wlt:1131,1-1140,2"
]

VerificationTest[
    cleanupTestFiles[ gooseConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-RefusesUnparseableYAML-Cleanup@@Tests/InstallMCPServer.wlt:1142,1-1147,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Refuse to Overwrite Unparseable YAML on Uninstall (Goose)*)
VerificationTest[
    gooseConfigFile = testYAMLFile[ ];
    Module[ { stream },
        stream = OpenWrite @ First @ gooseConfigFile;
        WriteString[ stream, "extensions:\n  Wolfram:\n    cmd: wolfram\n     name: bad-indent\n" ];
        Close @ stream
    ];
    UninstallMCPServer[ gooseConfigFile, "WolframLanguage" ],
    _Failure,
    { UninstallMCPServer::InvalidMCPConfiguration },
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Goose-RefusesUnparseableYAML@@Tests/InstallMCPServer.wlt:1152,1-1164,2"
]

VerificationTest[
    Module[ { content },
        content = ReadString @ First @ gooseConfigFile;
        (* The file must NOT have been overwritten *)
        StringContainsQ[ content, "bad-indent" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Goose-PreservesUnparseableYAML@@Tests/InstallMCPServer.wlt:1166,1-1175,2"
]

VerificationTest[
    cleanupTestFiles[ gooseConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Goose-RefusesUnparseableYAML-Cleanup@@Tests/InstallMCPServer.wlt:1177,1-1182,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*No Project Support*)
VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ InstallMCPServer[
        { "Goose", $TemporaryDirectory },
        "WolframLanguage",
        "VerifyLLMKit" -> False
    ],
    _Failure,
    { AgentTools::UnsupportedMCPClientProject },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-NoProjectSupport@@Tests/InstallMCPServer.wlt:1187,1-1197,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Copilot CLI Support*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Location for Copilot CLI*)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "CopilotCLI", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-CopilotCLI-Windows@@Tests/InstallMCPServer.wlt:1206,1-1211,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "CopilotCLI", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-CopilotCLI-MacOSX@@Tests/InstallMCPServer.wlt:1213,1-1218,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "CopilotCLI", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-CopilotCLI-Unix@@Tests/InstallMCPServer.wlt:1220,1-1225,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Copilot" ],
    "CopilotCLI",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Copilot@@Tests/InstallMCPServer.wlt:1230,1-1235,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "CopilotCLI" ],
    "CopilotCLI",
    SameTest -> Equal,
    TestID   -> "ToInstallName-CopilotCLI@@Tests/InstallMCPServer.wlt:1237,1-1242,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "CopilotCLI" ],
    "Copilot CLI",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-CopilotCLI@@Tests/InstallMCPServer.wlt:1244,1-1249,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertToCopilotCLIFormat*)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToCopilotCLIFormat @ <|
        "command" -> "wolfram",
        "args" -> { "-run", "test" },
        "env" -> <| "KEY" -> "value" |>
    |>,
    <|
        "command" -> "wolfram",
        "args" -> { "-run", "test" },
        "env" -> <| "KEY" -> "value" |>,
        "tools" -> { "*" }
    |>,
    SameTest -> Equal,
    TestID   -> "ConvertToCopilotCLIFormat-Basic@@Tests/InstallMCPServer.wlt:1254,1-1268,2"
]

VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToCopilotCLIFormat @ <|
        "command" -> "wolfram"
    |>,
    <| "command" -> "wolfram", "tools" -> { "*" } |>,
    SameTest -> Equal,
    TestID   -> "ConvertToCopilotCLIFormat-MinimalConfig@@Tests/InstallMCPServer.wlt:1270,1-1277,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Windsurf Support*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Location for Windsurf*)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Windsurf", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Windsurf-Windows@@Tests/InstallMCPServer.wlt:1286,1-1291,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Windsurf", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Windsurf-MacOSX@@Tests/InstallMCPServer.wlt:1293,1-1298,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Windsurf", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Windsurf-Unix@@Tests/InstallMCPServer.wlt:1300,1-1305,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Codeium" ],
    "Windsurf",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Codeium@@Tests/InstallMCPServer.wlt:1310,1-1315,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Windsurf" ],
    "Windsurf",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Windsurf@@Tests/InstallMCPServer.wlt:1317,1-1322,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Windsurf" ],
    "Windsurf",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Windsurf@@Tests/InstallMCPServer.wlt:1324,1-1329,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cline Support*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Location for Cline*)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Cline", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Cline-Windows@@Tests/InstallMCPServer.wlt:1338,1-1343,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Cline", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Cline-MacOSX@@Tests/InstallMCPServer.wlt:1345,1-1350,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Cline", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Cline-Unix@@Tests/InstallMCPServer.wlt:1352,1-1357,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Cline" ],
    "Cline",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Cline@@Tests/InstallMCPServer.wlt:1362,1-1367,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Cline" ],
    "Cline",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Cline@@Tests/InstallMCPServer.wlt:1369,1-1374,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertToClineFormat*)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToClineFormat @ <|
        "command" -> "wolfram",
        "args" -> { "-run", "test" },
        "env" -> <| "KEY" -> "value" |>
    |>,
    <|
        "command" -> "wolfram",
        "args" -> { "-run", "test" },
        "env" -> <| "KEY" -> "value" |>,
        "disabled" -> False,
        "autoApprove" -> { }
    |>,
    SameTest -> Equal,
    TestID   -> "ConvertToClineFormat-Basic@@Tests/InstallMCPServer.wlt:1379,1-1394,2"
]

VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToClineFormat @ <|
        "command" -> "wolfram"
    |>,
    <| "command" -> "wolfram", "disabled" -> False, "autoApprove" -> { } |>,
    SameTest -> Equal,
    TestID   -> "ConvertToClineFormat-MinimalConfig@@Tests/InstallMCPServer.wlt:1396,1-1403,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cline Install and Uninstall*)
VerificationTest[
    clineConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ clineConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "Cline" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Cline-Basic@@Tests/InstallMCPServer.wlt:1408,1-1414,2"
]

VerificationTest[
    FileExistsQ[ clineConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Cline-FileExists@@Tests/InstallMCPServer.wlt:1416,1-1421,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ clineConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Cline-VerifyContent@@Tests/InstallMCPServer.wlt:1423,1-1431,2"
]

VerificationTest[
    Module[ { content, server },
        content = Import[ clineConfigFile, "RawJSON" ];
        server = content[ "mcpServers", "Wolfram" ];
        KeyExistsQ[ server, "disabled" ] && server[ "disabled" ] === False &&
        KeyExistsQ[ server, "autoApprove" ] && server[ "autoApprove" ] === { }
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Cline-VerifyClineFields@@Tests/InstallMCPServer.wlt:1433,1-1443,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ clineConfigFile, "WolframLanguage", "ApplicationName" -> "Cline" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Cline-Basic@@Tests/InstallMCPServer.wlt:1445,1-1450,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ clineConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && ! KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Cline-VerifyRemoval@@Tests/InstallMCPServer.wlt:1452,1-1460,2"
]

VerificationTest[
    cleanupTestFiles[ clineConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Cline-Cleanup@@Tests/InstallMCPServer.wlt:1462,1-1467,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Windsurf Install and Uninstall*)
VerificationTest[
    windsurfConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ windsurfConfigFile, "WolframLanguage", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Windsurf-Basic@@Tests/InstallMCPServer.wlt:1472,1-1478,2"
]

VerificationTest[
    FileExistsQ[ windsurfConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Windsurf-FileExists@@Tests/InstallMCPServer.wlt:1480,1-1485,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ windsurfConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Windsurf-VerifyContent@@Tests/InstallMCPServer.wlt:1487,1-1495,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ windsurfConfigFile, "WolframLanguage" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Windsurf-Basic@@Tests/InstallMCPServer.wlt:1497,1-1502,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ windsurfConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && ! KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Windsurf-VerifyRemoval@@Tests/InstallMCPServer.wlt:1504,1-1512,2"
]

VerificationTest[
    cleanupTestFiles[ windsurfConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Windsurf-Cleanup@@Tests/InstallMCPServer.wlt:1514,1-1519,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Augment Code Support*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Location for AugmentCode*)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AugmentCode", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AugmentCode-Windows@@Tests/InstallMCPServer.wlt:1528,1-1533,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AugmentCode", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AugmentCode-MacOSX@@Tests/InstallMCPServer.wlt:1535,1-1540,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AugmentCode", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AugmentCode-Unix@@Tests/InstallMCPServer.wlt:1542,1-1547,2"
]

(* Install location path must end with .augment/settings.json on all platforms *)
VerificationTest[
    Module[ { file, split },
        file = Wolfram`AgentTools`Common`installLocation[ "AugmentCode", $OperatingSystem ];
        split = FileNameSplit @ First @ file;
        Take[ split, -2 ]
    ],
    { ".augment", "settings.json" },
    SameTest -> Equal,
    TestID   -> "InstallLocation-AugmentCode-PathShape@@Tests/InstallMCPServer.wlt:1550,1-1559,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "AugmentCode" ],
    "AugmentCode",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AugmentCode@@Tests/InstallMCPServer.wlt:1564,1-1569,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Auggie" ],
    "AugmentCode",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Auggie@@Tests/InstallMCPServer.wlt:1571,1-1576,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Augment" ],
    "AugmentCode",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Augment@@Tests/InstallMCPServer.wlt:1578,1-1583,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "AugmentCode" ],
    "Augment Code",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-AugmentCode@@Tests/InstallMCPServer.wlt:1585,1-1590,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AugmentCode Install and Uninstall*)
VerificationTest[
    augmentConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ augmentConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "AugmentCode" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AugmentCode-Basic@@Tests/InstallMCPServer.wlt:1595,1-1601,2"
]

VerificationTest[
    FileExistsQ[ augmentConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AugmentCode-FileExists@@Tests/InstallMCPServer.wlt:1603,1-1608,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ augmentConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AugmentCode-VerifyContent@@Tests/InstallMCPServer.wlt:1610,1-1618,2"
]

(* AugmentCode uses the standard mcpServers format: no Cline-style disabled/autoApprove fields
   and no Copilot-style tools field should be added *)
VerificationTest[
    Module[ { content, server },
        content = Import[ augmentConfigFile, "RawJSON" ];
        server = content[ "mcpServers", "Wolfram" ];
        KeyExistsQ[ server, "command" ] &&
        ! KeyExistsQ[ server, "disabled" ] &&
        ! KeyExistsQ[ server, "autoApprove" ] &&
        ! KeyExistsQ[ server, "tools" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AugmentCode-StandardFormat@@Tests/InstallMCPServer.wlt:1622,1-1634,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ augmentConfigFile, "WolframLanguage", "ApplicationName" -> "AugmentCode" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-AugmentCode-Basic@@Tests/InstallMCPServer.wlt:1636,1-1641,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ augmentConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && ! KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-AugmentCode-VerifyRemoval@@Tests/InstallMCPServer.wlt:1643,1-1651,2"
]

VerificationTest[
    cleanupTestFiles[ augmentConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AugmentCode-Cleanup@@Tests/InstallMCPServer.wlt:1653,1-1658,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertToAugmentCodeFormat*)

(* Non-Windows: converter returns the entry unchanged regardless of the command path *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeFormat[
        <|
            "command" -> "/usr/local/bin/wolfram",
            "args" -> { "-run", "test" },
            "env" -> <| "KEY" -> "value" |>
        |>,
        "Unix"
    ],
    <|
        "command" -> "/usr/local/bin/wolfram",
        "args" -> { "-run", "test" },
        "env" -> <| "KEY" -> "value" |>
    |>,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeFormat-NonWindows@@Tests/InstallMCPServer.wlt:1665,1-1681,2"
]

(* Non-Windows with a space-containing command: still unchanged *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeFormat[
        <| "command" -> "/Applications/Wolfram Desktop.app/Contents/MacOS/wolfram" |>,
        "MacOSX"
    ],
    <| "command" -> "/Applications/Wolfram Desktop.app/Contents/MacOS/wolfram" |>,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeFormat-NonWindows-WithSpaces@@Tests/InstallMCPServer.wlt:1684,1-1692,2"
]

(* Windows with a space-free command: unchanged (no short-path lookup needed) *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeFormat[
        <|
            "command" -> "C:\\Wolfram\\wolfram.exe",
            "args" -> { "-run", "test" }
        |>,
        "Windows"
    ],
    <|
        "command" -> "C:\\Wolfram\\wolfram.exe",
        "args" -> { "-run", "test" }
    |>,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeFormat-Windows-NoSpaces@@Tests/InstallMCPServer.wlt:1695,1-1709,2"
]

(* Missing command: converter should not error *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeFormat[
        <| "args" -> { "-run", "test" } |>,
        "Windows"
    ],
    <| "args" -> { "-run", "test" } |>,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeFormat-MissingCommand@@Tests/InstallMCPServer.wlt:1712,1-1720,2"
]

(* Windows with a space-containing path to a non-existent file: falls back to the
   original path (toWindowsShortPath returns unchanged when the file does not exist) *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeFormat[
        <| "command" -> "C:\\Does Not Exist\\wolfram.exe" |>,
        "Windows"
    ],
    <| "command" -> "C:\\Does Not Exist\\wolfram.exe" |>,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeFormat-Windows-NonExistentPath@@Tests/InstallMCPServer.wlt:1724,1-1732,2"
]

(* 1-arg form dispatches to 2-arg form using $OperatingSystem *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeFormat @ <|
        "command" -> "/no/spaces/here"
    |>,
    <| "command" -> "/no/spaces/here" |>,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeFormat-OneArgForm@@Tests/InstallMCPServer.wlt:1735,1-1742,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Augment Code IDE Support*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Location for AugmentCodeIDE*)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AugmentCodeIDE", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AugmentCodeIDE-Windows@@Tests/InstallMCPServer.wlt:1751,1-1756,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AugmentCodeIDE", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AugmentCodeIDE-MacOSX@@Tests/InstallMCPServer.wlt:1758,1-1763,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AugmentCodeIDE", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AugmentCodeIDE-Unix@@Tests/InstallMCPServer.wlt:1765,1-1770,2"
]

(* Install location must end with augment.vscode-augment/augment-global-state/mcpServers.json on all platforms *)
VerificationTest[
    Module[ { file, split },
        file = Wolfram`AgentTools`Common`installLocation[ "AugmentCodeIDE", $OperatingSystem ];
        split = FileNameSplit @ First @ file;
        Take[ split, -3 ]
    ],
    { "augment.vscode-augment", "augment-global-state", "mcpServers.json" },
    SameTest -> Equal,
    TestID   -> "InstallLocation-AugmentCodeIDE-PathShape@@Tests/InstallMCPServer.wlt:1773,1-1782,2"
]

(* Install locations for AugmentCode (CLI) and AugmentCodeIDE must differ *)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AugmentCode", $OperatingSystem ] =!=
        Wolfram`AgentTools`Common`installLocation[ "AugmentCodeIDE", $OperatingSystem ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallLocation-AugmentCode-vs-AugmentCodeIDE-Distinct@@Tests/InstallMCPServer.wlt:1785,1-1791,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "AugmentCodeIDE" ],
    "AugmentCodeIDE",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AugmentCodeIDE@@Tests/InstallMCPServer.wlt:1796,1-1801,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "AugmentIDE" ],
    "AugmentCodeIDE",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AugmentIDE@@Tests/InstallMCPServer.wlt:1803,1-1808,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "AuggieIDE" ],
    "AugmentCodeIDE",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AuggieIDE@@Tests/InstallMCPServer.wlt:1810,1-1815,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "AugmentCodeIDE" ],
    "Augment Code IDE",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-AugmentCodeIDE@@Tests/InstallMCPServer.wlt:1817,1-1822,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AugmentCodeIDE Install and Uninstall*)
VerificationTest[
    augmentIDEConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ augmentIDEConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "AugmentCodeIDE" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AugmentCodeIDE-Basic@@Tests/InstallMCPServer.wlt:1827,1-1833,2"
]

VerificationTest[
    FileExistsQ[ augmentIDEConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AugmentCodeIDE-FileExists@@Tests/InstallMCPServer.wlt:1835,1-1840,2"
]

(* The file root is a JSON array, not an object *)
VerificationTest[
    Module[ { content },
        content = Import[ augmentIDEConfigFile, "RawJSON" ];
        ListQ @ content
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AugmentCodeIDE-RootIsArray@@Tests/InstallMCPServer.wlt:1843,1-1851,2"
]

(* Verify the Wolfram server entry is present with the required array-entry fields *)
VerificationTest[
    Module[ { content, entry },
        content = Import[ augmentIDEConfigFile, "RawJSON" ];
        entry = SelectFirst[ content, MatchQ[ #, KeyValuePattern @ { "name" -> "Wolfram" } ] &, Missing[ ] ];
        AssociationQ @ entry &&
        entry[ "type" ] === "stdio" &&
        entry[ "name" ] === "Wolfram" &&
        StringQ @ entry[ "command" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AugmentCodeIDE-EntryShape@@Tests/InstallMCPServer.wlt:1854,1-1866,2"
]

(* Installing the same server a second time should upsert (not duplicate) *)
VerificationTest[
    InstallMCPServer[ augmentIDEConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "AugmentCodeIDE" ];
    Module[ { content, matches },
        content = Import[ augmentIDEConfigFile, "RawJSON" ];
        matches = Select[ content, MatchQ[ #, KeyValuePattern @ { "name" -> "Wolfram" } ] & ];
        Length @ matches
    ],
    1,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AugmentCodeIDE-Idempotent@@Tests/InstallMCPServer.wlt:1869,1-1879,2"
]

(* A second, differently-named server is appended (not replaced) *)
VerificationTest[
    InstallMCPServer[ augmentIDEConfigFile, "WolframAlpha", "VerifyLLMKit" -> False, "ApplicationName" -> "AugmentCodeIDE", "MCPServerName" -> "WolframAlphaExtra" ];
    Module[ { content, names },
        content = Import[ augmentIDEConfigFile, "RawJSON" ];
        names = Sort @ DeleteDuplicates @ Cases[ content, KeyValuePattern @ { "name" -> n_String } :> n ];
        names
    ],
    { "Wolfram", "WolframAlphaExtra" },
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AugmentCodeIDE-MultiServer@@Tests/InstallMCPServer.wlt:1882,1-1892,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ augmentIDEConfigFile, "WolframLanguage", "ApplicationName" -> "AugmentCodeIDE" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-AugmentCodeIDE-Basic@@Tests/InstallMCPServer.wlt:1894,1-1899,2"
]

VerificationTest[
    Module[ { content, matches },
        content = Import[ augmentIDEConfigFile, "RawJSON" ];
        matches = Select[ content, MatchQ[ #, KeyValuePattern @ { "name" -> "Wolfram" } ] & ];
        Length @ matches
    ],
    0,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-AugmentCodeIDE-VerifyRemoval@@Tests/InstallMCPServer.wlt:1901,1-1910,2"
]

(* Uninstalling the other entry as well leaves an empty array, not a removed file *)
VerificationTest[
    UninstallMCPServer[ augmentIDEConfigFile, "WolframAlpha", "ApplicationName" -> "AugmentCodeIDE", "MCPServerName" -> "WolframAlphaExtra" ];
    Import[ augmentIDEConfigFile, "RawJSON" ],
    { },
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-AugmentCodeIDE-EmptiesToArray@@Tests/InstallMCPServer.wlt:1913,1-1919,2"
]

(* Uninstalling a server that isn't installed returns NotInstalled, not an error *)
VerificationTest[
    UninstallMCPServer[ augmentIDEConfigFile, "WolframLanguage", "ApplicationName" -> "AugmentCodeIDE" ],
    Missing[ "NotInstalled", _ ],
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-AugmentCodeIDE-NotInstalled@@Tests/InstallMCPServer.wlt:1922,1-1927,2"
]

VerificationTest[
    cleanupTestFiles[ augmentIDEConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AugmentCodeIDE-Cleanup@@Tests/InstallMCPServer.wlt:1929,1-1934,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertToAugmentCodeIDEFormat*)

(* Basic shape transform: adds "type" -> "stdio", preserves command/args/env *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeIDEFormat[
        <|
            "command" -> "/usr/local/bin/wolfram",
            "args" -> { "-run", "test" },
            "env" -> <| "KEY" -> "value" |>
        |>,
        "Unix"
    ],
    <|
        "type" -> "stdio",
        "command" -> "/usr/local/bin/wolfram",
        "args" -> { "-run", "test" },
        "env" -> <| "KEY" -> "value" |>
    |>,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeIDEFormat-Basic@@Tests/InstallMCPServer.wlt:1941,1-1958,2"
]

(* Non-Windows with a space-containing path: does NOT apply short-path coercion *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeIDEFormat[
        <| "command" -> "/Applications/Wolfram Desktop.app/Contents/MacOS/wolfram" |>,
        "MacOSX"
    ],
    <|
        "type" -> "stdio",
        "command" -> "/Applications/Wolfram Desktop.app/Contents/MacOS/wolfram"
    |>,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeIDEFormat-NonWindows-WithSpaces@@Tests/InstallMCPServer.wlt:1961,1-1972,2"
]

(* Windows with a space-free command: unchanged *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeIDEFormat[
        <| "command" -> "C:\\Wolfram\\wolfram.exe", "args" -> { "-run" } |>,
        "Windows"
    ],
    <|
        "type" -> "stdio",
        "command" -> "C:\\Wolfram\\wolfram.exe",
        "args" -> { "-run" }
    |>,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeIDEFormat-Windows-NoSpaces@@Tests/InstallMCPServer.wlt:1975,1-1987,2"
]

(* Missing command: converter should not error, just omit "command" *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeIDEFormat[
        <| "args" -> { "-run" } |>,
        "Windows"
    ],
    <|
        "type" -> "stdio",
        "args" -> { "-run" }
    |>,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeIDEFormat-MissingCommand@@Tests/InstallMCPServer.wlt:1990,1-2001,2"
]

(* Converter does NOT set the "name" field - the install flow prepends it after conversion *)
VerificationTest[
    KeyExistsQ[
        Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeIDEFormat[
            <| "command" -> "/tmp/wolfram" |>,
            "Unix"
        ],
        "name"
    ],
    False,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeIDEFormat-NoNameField@@Tests/InstallMCPServer.wlt:2004,1-2015,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readExistingAugmentCodeIDEConfig*)

(* Non-existent file returns empty list *)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`readExistingAugmentCodeIDEConfig @ File @
        FileNameJoin @ { $TemporaryDirectory, "ide_noexist_" <> CreateUUID[] <> ".json" },
    { },
    SameTest -> Equal,
    TestID   -> "ReadExistingAugmentCodeIDEConfig-NonExistent@@Tests/InstallMCPServer.wlt:2022,1-2028,2"
]

(* Empty file returns empty list *)
VerificationTest[
    Module[ { file },
        file = File @ FileNameJoin @ { $TemporaryDirectory, "ide_empty_" <> CreateUUID[] <> ".json" };
        WithCleanup[
            CreateFile[ First @ file ];
            Wolfram`AgentTools`InstallMCPServer`Private`readExistingAugmentCodeIDEConfig @ file,
            Quiet @ DeleteFile @ First @ file
        ]
    ],
    { },
    SameTest -> Equal,
    TestID   -> "ReadExistingAugmentCodeIDEConfig-EmptyFile@@Tests/InstallMCPServer.wlt:2031,1-2043,2"
]

(* File with a valid array is returned as-is *)
VerificationTest[
    Module[ { file, result },
        file = File @ FileNameJoin @ { $TemporaryDirectory, "ide_array_" <> CreateUUID[] <> ".json" };
        WithCleanup[
            Developer`WriteRawJSONFile[ First @ file, { <| "name" -> "X", "type" -> "stdio" |> } ];
            result = Wolfram`AgentTools`InstallMCPServer`Private`readExistingAugmentCodeIDEConfig @ file,
            Quiet @ DeleteFile @ First @ file
        ];
        result
    ],
    { <| "name" -> "X", "type" -> "stdio" |> },
    SameTest -> Equal,
    TestID   -> "ReadExistingAugmentCodeIDEConfig-ValidArray@@Tests/InstallMCPServer.wlt:2046,1-2059,2"
]

(* File with a non-list top level issues InvalidMCPConfiguration when installing.
   (Calling readExistingAugmentCodeIDEConfig directly returns the data because
   throwFailure only throws inside the catchMine wrapper used by InstallMCPServer.) *)
VerificationTest[
    Module[ { file },
        file = FileNameJoin @ { $TemporaryDirectory, "ide_obj_" <> CreateUUID[] <> ".json" };
        WithCleanup[
            Developer`WriteRawJSONFile[ file, <| "mcpServers" -> <| |> |> ];
            Quiet @ InstallMCPServer[ File @ file, "WolframLanguage",
                "VerifyLLMKit" -> False, "ApplicationName" -> "AugmentCodeIDE" ],
            Quiet @ DeleteFile @ file
        ]
    ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "ReadExistingAugmentCodeIDEConfig-NonListRoot@@Tests/InstallMCPServer.wlt:2064,1-2077,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Client Detection from File Path*)

(* File at the VS Code extension's settings location is auto-detected as AugmentCodeIDE
   when installing without an explicit "ApplicationName" - the resulting file is an
   array (AugmentCodeIDE format), not an object (AugmentCode/CLI format). *)
VerificationTest[
    Module[ { dir, file, result },
        dir = FileNameJoin @ { $TemporaryDirectory,
            "guess_" <> CreateUUID[], "augment.vscode-augment", "augment-global-state" };
        CreateDirectory[ dir, CreateIntermediateDirectories -> True ];
        file = FileNameJoin @ { dir, "mcpServers.json" };
        WithCleanup[
            InstallMCPServer[ File @ file, "WolframLanguage", "VerifyLLMKit" -> False ];
            result = Import[ file, "RawJSON" ],
            Quiet @ DeleteDirectory[ dir, DeleteContents -> True ];
            Quiet @ DeleteDirectory[ DirectoryName @ dir ]
        ];
        ListQ @ result &&
        AnyTrue[ result, MatchQ[ #, KeyValuePattern @ { "name" -> _String, "type" -> "stdio" } ] & ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "GuessClientName-AugmentCodeIDE-PathMatch@@Tests/InstallMCPServer.wlt:2086,1-2104,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$SupportedMCPClients metadata for AugmentCodeIDE*)
VerificationTest[
    $SupportedMCPClients[ "AugmentCodeIDE", "DisplayName" ],
    "Augment Code IDE",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeIDEDisplayName@@Tests/InstallMCPServer.wlt:2109,1-2114,2"
]

VerificationTest[
    Sort @ $SupportedMCPClients[ "AugmentCodeIDE", "Aliases" ],
    Sort @ { "AugmentIDE", "AuggieIDE" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeIDEAliases@@Tests/InstallMCPServer.wlt:2116,1-2121,2"
]

VerificationTest[
    $SupportedMCPClients[ "AugmentCodeIDE", "ConfigFormat" ],
    "JSON",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeIDEConfigFormat@@Tests/InstallMCPServer.wlt:2123,1-2128,2"
]

(* Empty ConfigKey signals the root of the file is an array, not a keyed object *)
VerificationTest[
    $SupportedMCPClients[ "AugmentCodeIDE", "ConfigKey" ],
    { },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeIDEConfigKey@@Tests/InstallMCPServer.wlt:2131,1-2136,2"
]

VerificationTest[
    $SupportedMCPClients[ "AugmentCodeIDE", "ProjectSupport" ],
    False,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeIDEProjectSupport@@Tests/InstallMCPServer.wlt:2138,1-2143,2"
]

VerificationTest[
    StringStartsQ[ $SupportedMCPClients[ "AugmentCodeIDE", "URL" ], "https://" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeIDEURL@@Tests/InstallMCPServer.wlt:2145,1-2150,2"
]

(* AugmentCode (CLI) and AugmentCodeIDE (VS Code) must be distinct entries with distinct display names *)
VerificationTest[
    $SupportedMCPClients[ "AugmentCode", "DisplayName" ] =!=
        $SupportedMCPClients[ "AugmentCodeIDE", "DisplayName" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCode-vs-AugmentCodeIDE-Distinct@@Tests/InstallMCPServer.wlt:2153,1-2159,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toWindowsShortPath*)

(* Non-existent path: returns the input unchanged *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`toWindowsShortPath[
        "C:\\__this_path_does_not_exist_" <> CreateUUID[] <> "__\\wolfram.exe"
    ],
    _String? (! StringContainsQ[ #, "~" ] &),
    SameTest -> MatchQ,
    TestID   -> "ToWindowsShortPath-NonExistent@@Tests/InstallMCPServer.wlt:2166,1-2173,2"
]

(* Space-free existing path on Windows: result equals the input (no short form needed).
   On non-Windows, the file probably exists and the function still returns a string. *)
VerificationTest[
    With[ { result = Wolfram`AgentTools`SupportedClients`Private`toWindowsShortPath @ $TemporaryDirectory },
        StringQ @ result
    ],
    True,
    SameTest -> Equal,
    TestID   -> "ToWindowsShortPath-ReturnsString@@Tests/InstallMCPServer.wlt:2177,1-2184,2"
]

(* Windows-only: the wolfram.exe short path should not contain spaces when the
   original is in "Program Files" *)
If[ $OperatingSystem === "Windows",
    VerificationTest[
        Module[ { candidate, shortPath },
            candidate = "C:\\Program Files\\Wolfram Research\\Wolfram\\15.0\\wolfram.exe";
            If[ ! FileExistsQ @ candidate, Return[ True, Module ] ];
            shortPath = Wolfram`AgentTools`SupportedClients`Private`toWindowsShortPath @ candidate;
            StringQ @ shortPath && ! StringContainsQ[ shortPath, " " ]
        ],
        True,
        SameTest -> Equal,
        TestID   -> "ToWindowsShortPath-WolframExe@@Tests/InstallMCPServer.wlt:2189,5-2199,6"
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$SupportedMCPClients metadata for AugmentCode*)
VerificationTest[
    $SupportedMCPClients[ "AugmentCode", "DisplayName" ],
    "Augment Code",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeDisplayName@@Tests/InstallMCPServer.wlt:2205,1-2210,2"
]

VerificationTest[
    Sort @ $SupportedMCPClients[ "AugmentCode", "Aliases" ],
    Sort @ { "Auggie", "Augment" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeAliases@@Tests/InstallMCPServer.wlt:2212,1-2217,2"
]

VerificationTest[
    $SupportedMCPClients[ "AugmentCode", "ConfigFormat" ],
    "JSON",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeConfigFormat@@Tests/InstallMCPServer.wlt:2219,1-2224,2"
]

VerificationTest[
    $SupportedMCPClients[ "AugmentCode", "ConfigKey" ],
    { "mcpServers" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeConfigKey@@Tests/InstallMCPServer.wlt:2226,1-2231,2"
]

VerificationTest[
    $SupportedMCPClients[ "AugmentCode", "ProjectSupport" ],
    False,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeProjectSupport@@Tests/InstallMCPServer.wlt:2233,1-2238,2"
]

VerificationTest[
    StringStartsQ[ $SupportedMCPClients[ "AugmentCode", "URL" ], "https://" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeURL@@Tests/InstallMCPServer.wlt:2240,1-2245,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Zed Support*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Location for Zed*)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Zed", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Zed-Windows@@Tests/InstallMCPServer.wlt:2254,1-2259,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Zed", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Zed-MacOSX@@Tests/InstallMCPServer.wlt:2261,1-2266,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Zed", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Zed-Unix@@Tests/InstallMCPServer.wlt:2268,1-2273,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Zed" ],
    "Zed",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Zed@@Tests/InstallMCPServer.wlt:2278,1-2283,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Zed" ],
    "Zed",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Zed@@Tests/InstallMCPServer.wlt:2285,1-2290,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Project Install Location*)
VerificationTest[
    Module[ { path, result },
        path = FileNameJoin @ { $TemporaryDirectory, "TestProject" };
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "Zed", path ];
        FileNameTake[ First @ result, -2 ]
    ],
    FileNameJoin @ { ".zed", "settings.json" },
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-Zed@@Tests/InstallMCPServer.wlt:2295,1-2304,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Zed Install and Uninstall*)
VerificationTest[
    zedConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ zedConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "Zed" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Zed-Basic@@Tests/InstallMCPServer.wlt:2309,1-2315,2"
]

VerificationTest[
    FileExistsQ[ zedConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Zed-FileExists@@Tests/InstallMCPServer.wlt:2317,1-2322,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ zedConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "context_servers" ] && KeyExistsQ[ content[ "context_servers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Zed-VerifyContent@@Tests/InstallMCPServer.wlt:2324,1-2332,2"
]

VerificationTest[
    Module[ { content, server },
        content = Import[ zedConfigFile, "RawJSON" ];
        server = content[ "context_servers", "Wolfram" ];
        KeyExistsQ[ server, "command" ] && KeyExistsQ[ server, "args" ] && KeyExistsQ[ server, "env" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Zed-VerifyServerFields@@Tests/InstallMCPServer.wlt:2334,1-2343,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ zedConfigFile, "WolframLanguage", "ApplicationName" -> "Zed" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Zed-Basic@@Tests/InstallMCPServer.wlt:2345,1-2350,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ zedConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "context_servers" ] && ! KeyExistsQ[ content[ "context_servers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Zed-VerifyRemoval@@Tests/InstallMCPServer.wlt:2352,1-2360,2"
]

VerificationTest[
    cleanupTestFiles[ zedConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Zed-Cleanup@@Tests/InstallMCPServer.wlt:2362,1-2367,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Zed Preserves Existing Config*)
VerificationTest[
    zedConfigFile = testConfigFile[];
    Export[ zedConfigFile, <| "theme" -> "One Dark", "context_servers" -> <| |> |>, "JSON" ];
    installResult = InstallMCPServer[ zedConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "Zed" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Zed-PreserveExisting@@Tests/InstallMCPServer.wlt:2372,1-2379,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ zedConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "theme" ] && content[ "theme" ] === "One Dark" &&
        KeyExistsQ[ content[ "context_servers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Zed-VerifyPreserved@@Tests/InstallMCPServer.wlt:2381,1-2390,2"
]

VerificationTest[
    cleanupTestFiles[ zedConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Zed-PreserveExisting-Cleanup@@Tests/InstallMCPServer.wlt:2392,1-2397,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Junie Support*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Location for Junie*)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Junie", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Junie-Windows@@Tests/InstallMCPServer.wlt:2406,1-2411,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Junie", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Junie-MacOSX@@Tests/InstallMCPServer.wlt:2413,1-2418,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Junie", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Junie-Unix@@Tests/InstallMCPServer.wlt:2420,1-2425,2"
]

(* Junie's user-scope path is .junie/mcp/mcp.json under $HomeDirectory on every OS *)
VerificationTest[
    Module[ { file, split },
        file = Wolfram`AgentTools`Common`installLocation[ "Junie", $OperatingSystem ];
        split = FileNameSplit @ First @ file;
        Take[ split, -3 ]
    ],
    { ".junie", "mcp", "mcp.json" },
    SameTest -> Equal,
    TestID   -> "InstallLocation-Junie-PathShape@@Tests/InstallMCPServer.wlt:2428,1-2437,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Junie" ],
    "Junie",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Junie@@Tests/InstallMCPServer.wlt:2442,1-2447,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "JetBrainsJunie" ],
    "Junie",
    SameTest -> Equal,
    TestID   -> "ToInstallName-JetBrainsJunie@@Tests/InstallMCPServer.wlt:2449,1-2454,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Junie" ],
    "Junie",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Junie@@Tests/InstallMCPServer.wlt:2456,1-2461,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Junie Install and Uninstall*)
VerificationTest[
    junieConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ junieConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "Junie" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Junie-Basic@@Tests/InstallMCPServer.wlt:2466,1-2472,2"
]

VerificationTest[
    FileExistsQ[ junieConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Junie-FileExists@@Tests/InstallMCPServer.wlt:2474,1-2479,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ junieConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Junie-VerifyContent@@Tests/InstallMCPServer.wlt:2481,1-2489,2"
]

(* Junie uses the standard mcpServers format: no Cline-style disabled/autoApprove fields,
   no Copilot-style tools field, no OpenCode-style top-level "mcp" key *)
VerificationTest[
    Module[ { content, server },
        content = Import[ junieConfigFile, "RawJSON" ];
        server = content[ "mcpServers", "Wolfram" ];
        AssociationQ @ server &&
        KeyExistsQ[ server, "command" ] &&
        ! KeyExistsQ[ server, "disabled" ] &&
        ! KeyExistsQ[ server, "autoApprove" ] &&
        ! KeyExistsQ[ server, "tools" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Junie-StandardFormat@@Tests/InstallMCPServer.wlt:2493,1-2506,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ junieConfigFile, "WolframLanguage", "ApplicationName" -> "Junie" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Junie-Basic@@Tests/InstallMCPServer.wlt:2508,1-2513,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ junieConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && ! KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Junie-VerifyRemoval@@Tests/InstallMCPServer.wlt:2515,1-2523,2"
]

VerificationTest[
    cleanupTestFiles[ junieConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Junie-Cleanup@@Tests/InstallMCPServer.wlt:2525,1-2530,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Junie Project-Level Install*)
VerificationTest[
    Module[ { dir, projectFile, result },
        dir = FileNameJoin @ { $TemporaryDirectory, "junie_proj_" <> CreateUUID[] };
        CreateDirectory @ dir;
        WithCleanup[
            result = InstallMCPServer[ { "Junie", dir }, "WolframLanguage", "VerifyLLMKit" -> False ];
            projectFile = FileNameJoin @ { dir, ".junie", "mcp", "mcp.json" };
            { MatchQ[ result, _Success ], FileExistsQ @ projectFile },
            Quiet @ DeleteDirectory[ dir, DeleteContents -> True ]
        ]
    ],
    { True, True },
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Junie-ProjectLevel@@Tests/InstallMCPServer.wlt:2535,1-2549,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Auto-Detection from Path*)

(* File at .junie/mcp/mcp.json under any directory should be detected as Junie when
   installing without an explicit ApplicationName. *)
VerificationTest[
    Module[ { dir, file, result },
        dir = FileNameJoin @ { $TemporaryDirectory, "junie_guess_" <> CreateUUID[], ".junie", "mcp" };
        CreateDirectory[ dir, CreateIntermediateDirectories -> True ];
        file = FileNameJoin @ { dir, "mcp.json" };
        WithCleanup[
            InstallMCPServer[ File @ file, "WolframLanguage", "VerifyLLMKit" -> False ];
            result = Import[ file, "RawJSON" ],
            Quiet @ DeleteDirectory[ dir, DeleteContents -> True ];
            Quiet @ DeleteDirectory[ DirectoryName[ dir, 2 ], DeleteContents -> True ]
        ];
        AssociationQ @ result && KeyExistsQ[ result, "mcpServers" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "GuessClientName-Junie-PathMatch@@Tests/InstallMCPServer.wlt:2557,1-2573,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$SupportedMCPClients metadata for Junie*)
VerificationTest[
    $SupportedMCPClients[ "Junie", "DisplayName" ],
    "Junie",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieDisplayName@@Tests/InstallMCPServer.wlt:2578,1-2583,2"
]

VerificationTest[
    $SupportedMCPClients[ "Junie", "Aliases" ],
    { "JetBrainsJunie" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieAliases@@Tests/InstallMCPServer.wlt:2585,1-2590,2"
]

VerificationTest[
    $SupportedMCPClients[ "Junie", "ConfigFormat" ],
    "JSON",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieConfigFormat@@Tests/InstallMCPServer.wlt:2592,1-2597,2"
]

VerificationTest[
    $SupportedMCPClients[ "Junie", "ConfigKey" ],
    { "mcpServers" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieConfigKey@@Tests/InstallMCPServer.wlt:2599,1-2604,2"
]

VerificationTest[
    $SupportedMCPClients[ "Junie", "ProjectSupport" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieProjectSupport@@Tests/InstallMCPServer.wlt:2606,1-2611,2"
]

VerificationTest[
    StringStartsQ[ $SupportedMCPClients[ "Junie", "URL" ], "https://" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieURL@@Tests/InstallMCPServer.wlt:2613,1-2618,2"
]

(* Junie is a coding agent - default toolset is WolframLanguage (matches Cursor, ClaudeCode, etc.) *)
VerificationTest[
    $SupportedMCPClients[ "Junie", "DefaultToolset" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieDefaultToolset@@Tests/InstallMCPServer.wlt:2621,1-2626,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Kiro Support*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Location for Kiro*)

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Kiro", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Kiro-Windows@@Tests/InstallMCPServer.wlt:2636,1-2641,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Kiro", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Kiro-MacOSX@@Tests/InstallMCPServer.wlt:2643,1-2648,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Kiro", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Kiro-Unix@@Tests/InstallMCPServer.wlt:2650,1-2655,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Kiro" ],
    "Kiro",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Kiro@@Tests/InstallMCPServer.wlt:2657,1-2662,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Kiro" ],
    "Kiro",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Kiro@@Tests/InstallMCPServer.wlt:2664,1-2669,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Project Install Location*)
VerificationTest[
    Module[ { path, result },
        path = FileNameJoin @ { $TemporaryDirectory, "TestProject" };
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "Kiro", path ];
        FileNameTake[ First @ result, -3 ]
    ],
    FileNameJoin @ { ".kiro", "settings", "mcp.json" },
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-Kiro@@Tests/InstallMCPServer.wlt:2674,1-2683,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Kiro Install and Uninstall*)
VerificationTest[
    kiroConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ kiroConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "Kiro" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Kiro-Basic@@Tests/InstallMCPServer.wlt:2688,1-2694,2"
]

VerificationTest[
    FileExistsQ[ kiroConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Kiro-FileExists@@Tests/InstallMCPServer.wlt:2696,1-2701,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ kiroConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Kiro-VerifyContent@@Tests/InstallMCPServer.wlt:2703,1-2711,2"
]

VerificationTest[
    Module[ { content, server },
        content = Import[ kiroConfigFile, "RawJSON" ];
        server = content[ "mcpServers", "Wolfram" ];
        KeyExistsQ[ server, "disabled" ] && server[ "disabled" ] === False &&
        KeyExistsQ[ server, "autoApprove" ] && server[ "autoApprove" ] === { }
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Kiro-VerifyKiroFields@@Tests/InstallMCPServer.wlt:2713,1-2723,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ kiroConfigFile, "WolframLanguage", "ApplicationName" -> "Kiro" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Kiro-Basic@@Tests/InstallMCPServer.wlt:2725,1-2730,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ kiroConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && ! KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Kiro-VerifyRemoval@@Tests/InstallMCPServer.wlt:2732,1-2740,2"
]

VerificationTest[
    cleanupTestFiles[ kiroConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Kiro-Cleanup@@Tests/InstallMCPServer.wlt:2742,1-2747,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Kiro Preserves Existing Config*)
VerificationTest[
    kiroConfigFile = testConfigFile[];
    Export[ kiroConfigFile, <| "customSetting" -> True, "mcpServers" -> <| |> |>, "JSON" ];
    installResult = InstallMCPServer[ kiroConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "Kiro" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Kiro-PreserveExisting@@Tests/InstallMCPServer.wlt:2752,1-2759,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ kiroConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "customSetting" ] && content[ "customSetting" ] === True &&
        KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Kiro-VerifyPreserved@@Tests/InstallMCPServer.wlt:2761,1-2770,2"
]

VerificationTest[
    cleanupTestFiles[ kiroConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Kiro-PreserveExisting-Cleanup@@Tests/InstallMCPServer.wlt:2772,1-2777,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Amazon Q Developer Support*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Location for Amazon Q Developer*)

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AmazonQ", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AmazonQ-Windows@@Tests/InstallMCPServer.wlt:2787,1-2792,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AmazonQ", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AmazonQ-MacOSX@@Tests/InstallMCPServer.wlt:2794,1-2799,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AmazonQ", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AmazonQ-Unix@@Tests/InstallMCPServer.wlt:2801,1-2806,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "AmazonQ" ],
    "Amazon Q Developer",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-AmazonQ@@Tests/InstallMCPServer.wlt:2808,1-2813,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "AmazonQ" ],
    "AmazonQ",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AmazonQ@@Tests/InstallMCPServer.wlt:2815,1-2820,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "AmazonQDeveloper" ],
    "AmazonQ",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AmazonQ-Alias-AmazonQDeveloper@@Tests/InstallMCPServer.wlt:2822,1-2827,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Q" ],
    "AmazonQ",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AmazonQ-Alias-Q@@Tests/InstallMCPServer.wlt:2829,1-2834,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "QDeveloper" ],
    "AmazonQ",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AmazonQ-Alias-QDeveloper@@Tests/InstallMCPServer.wlt:2836,1-2841,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Project Install Location*)
VerificationTest[
    Module[ { path, result },
        path = FileNameJoin @ { $TemporaryDirectory, "TestProject" };
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "AmazonQ", path ];
        FileNameTake[ First @ result, -2 ]
    ],
    FileNameJoin @ { ".amazonq", "mcp.json" },
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-AmazonQ@@Tests/InstallMCPServer.wlt:2846,1-2855,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Amazon Q Install and Uninstall*)
VerificationTest[
    amazonQConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ amazonQConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "AmazonQ" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AmazonQ-Basic@@Tests/InstallMCPServer.wlt:2860,1-2866,2"
]

VerificationTest[
    FileExistsQ[ amazonQConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AmazonQ-FileExists@@Tests/InstallMCPServer.wlt:2868,1-2873,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ amazonQConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AmazonQ-VerifyContent@@Tests/InstallMCPServer.wlt:2875,1-2883,2"
]

VerificationTest[
    Module[ { content, server },
        content = Import[ amazonQConfigFile, "RawJSON" ];
        server = content[ "mcpServers", "Wolfram" ];
        KeyExistsQ[ server, "command" ] &&
        ! KeyExistsQ[ server, "disabled" ] &&
        ! KeyExistsQ[ server, "autoApprove" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AmazonQ-VerifyFields@@Tests/InstallMCPServer.wlt:2885,1-2896,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ amazonQConfigFile, "WolframLanguage", "ApplicationName" -> "AmazonQ" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-AmazonQ-Basic@@Tests/InstallMCPServer.wlt:2898,1-2903,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ amazonQConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && ! KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-AmazonQ-VerifyRemoval@@Tests/InstallMCPServer.wlt:2905,1-2913,2"
]

VerificationTest[
    cleanupTestFiles[ amazonQConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AmazonQ-Cleanup@@Tests/InstallMCPServer.wlt:2915,1-2920,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Amazon Q Preserves Existing Config*)
VerificationTest[
    amazonQConfigFile = testConfigFile[];
    Export[ amazonQConfigFile, <| "customSetting" -> True, "mcpServers" -> <| |> |>, "JSON" ];
    installResult = InstallMCPServer[ amazonQConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "AmazonQ" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AmazonQ-PreserveExisting@@Tests/InstallMCPServer.wlt:2925,1-2932,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ amazonQConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "customSetting" ] && content[ "customSetting" ] === True &&
        KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AmazonQ-VerifyPreserved@@Tests/InstallMCPServer.wlt:2934,1-2943,2"
]

VerificationTest[
    cleanupTestFiles[ amazonQConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AmazonQ-PreserveExisting-Cleanup@@Tests/InstallMCPServer.wlt:2945,1-2950,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Amazon Q Path Auto-Detection*)
VerificationTest[
    Module[ { dir, file, result },
        dir = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, CreateUUID[ "amzq-" ], ".amazonq" };
        file = File @ FileNameJoin @ { dir, "mcp.json" };
        result = InstallMCPServer[ file, "WolframLanguage", "VerifyLLMKit" -> False ];
        cleanupTestFiles[ file ];
        result
    ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AmazonQ-AutoDetect-Project@@Tests/InstallMCPServer.wlt:2955,1-2966,2"
]

VerificationTest[
    Module[ { dir, file, result },
        dir = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, CreateUUID[ "amzq-" ], ".aws", "amazonq" };
        file = File @ FileNameJoin @ { dir, "mcp.json" };
        result = InstallMCPServer[ file, "WolframLanguage", "VerifyLLMKit" -> False ];
        cleanupTestFiles[ file ];
        result
    ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AmazonQ-AutoDetect-Global@@Tests/InstallMCPServer.wlt:2968,1-2979,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$SupportedMCPClients*)
VerificationTest[
    $SupportedMCPClients,
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "SupportedMCPClients-ReturnsAssociation@@Tests/InstallMCPServer.wlt:2984,1-2989,2"
]

VerificationTest[
    Length @ $SupportedMCPClients,
    19,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-Has19Clients@@Tests/InstallMCPServer.wlt:2991,1-2996,2"
]

VerificationTest[
    Keys @ $SupportedMCPClients,
    { "AmazonQ", "Antigravity", "AntigravityCLI", "AugmentCode", "AugmentCodeIDE", "ClaudeCode", "ClaudeDesktop", "Cline", "Codex", "CopilotCLI", "Cursor", "GeminiCLI", "Goose", "Junie", "Kiro", "OpenCode", "VisualStudioCode", "Windsurf", "Zed" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-KeysSorted@@Tests/InstallMCPServer.wlt:2998,1-3003,2"
]

VerificationTest[
    AllTrue[
        Values @ $SupportedMCPClients,
        Function[ meta,
            KeyExistsQ[ meta, "Name" ] &&
            KeyExistsQ[ meta, "DisplayName" ] &&
            KeyExistsQ[ meta, "Aliases" ] &&
            KeyExistsQ[ meta, "ConfigFormat" ] &&
            KeyExistsQ[ meta, "ProjectSupport" ] &&
            KeyExistsQ[ meta, "ConfigKey" ] &&
            MatchQ[ meta[ "ConfigKey" ], { ___String } ] &&
            KeyExistsQ[ meta, "URL" ]
        ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AllHaveRequiredKeys@@Tests/InstallMCPServer.wlt:3005,1-3022,2"
]

VerificationTest[
    $SupportedMCPClients[ "ClaudeDesktop", "DisplayName" ],
    "Claude Desktop",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ClaudeDesktopDisplayName@@Tests/InstallMCPServer.wlt:3024,1-3029,2"
]

VerificationTest[
    $SupportedMCPClients[ "ClaudeDesktop", "Aliases" ],
    { "Claude" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ClaudeDesktopAliases@@Tests/InstallMCPServer.wlt:3031,1-3036,2"
]

VerificationTest[
    $SupportedMCPClients[ "Codex", "ConfigFormat" ],
    "TOML",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-CodexConfigFormat@@Tests/InstallMCPServer.wlt:3038,1-3043,2"
]

VerificationTest[
    $SupportedMCPClients[ "Codex", "ProjectSupport" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-CodexProjectSupport@@Tests/InstallMCPServer.wlt:3045,1-3050,2"
]

VerificationTest[
    $SupportedMCPClients[ "ClaudeCode", "ProjectSupport" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ClaudeCodeProjectSupport@@Tests/InstallMCPServer.wlt:3052,1-3057,2"
]

VerificationTest[
    $SupportedMCPClients[ "Zed", "ConfigKey" ],
    { "context_servers" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ZedConfigKey@@Tests/InstallMCPServer.wlt:3059,1-3064,2"
]

VerificationTest[
    $SupportedMCPClients[ "VisualStudioCode", "ConfigKey" ],
    { "servers" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-VSCodeConfigKey@@Tests/InstallMCPServer.wlt:3066,1-3071,2"
]

VerificationTest[
    $SupportedMCPClients[ "OpenCode", "ConfigKey" ],
    { "mcp" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-OpenCodeConfigKey@@Tests/InstallMCPServer.wlt:3073,1-3078,2"
]

VerificationTest[
    AllTrue[ Values @ $SupportedMCPClients, StringQ[ #[ "URL" ] ] && StringStartsQ[ #[ "URL" ], "https://" ] & ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AllHaveValidURLs@@Tests/InstallMCPServer.wlt:3080,1-3085,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Helper Function Unit Tests*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*guessClientNameFromJSON*)

(* Helper to create a temp JSON file with given content *)
makeTestJSONFile[ data_Association ] := Module[ { file },
    file = FileNameJoin @ { $TemporaryDirectory, StringJoin[ "guess_test_", CreateUUID[], ".json" ] };
    Developer`WriteRawJSONFile[ file, data ];
    file
];

(* Variant that uses a specific filename (in a unique temp subdirectory to avoid collisions) *)
makeTestJSONFile[ data_Association, name_String ] := Module[ { dir, file },
    dir = FileNameJoin @ { $TemporaryDirectory, "guess_test_" <> CreateUUID[] };
    CreateDirectory @ dir;
    file = FileNameJoin @ { dir, name };
    Developer`WriteRawJSONFile[ file, data ];
    file
];

(* Zed: has "context_servers" top-level key *)
VerificationTest[
    Module[ { file, result },
        file = makeTestJSONFile @ <| "context_servers" -> <| "MyServer" -> <| "command" -> "wolframscript" |> |> |>;
        result = Wolfram`AgentTools`InstallMCPServer`Private`guessClientNameFromJSON @ file;
        DeleteFile @ file;
        result
    ],
    "Zed",
    SameTest -> Equal,
    TestID   -> "GuessClientNameFromJSON-Zed@@Tests/InstallMCPServer.wlt:3112,1-3122,2"
]

(* VSCode legacy: has "mcp" with nested "servers" (settings.json format) *)
VerificationTest[
    Module[ { file, result },
        file = makeTestJSONFile @ <| "mcp" -> <| "servers" -> <| "MyServer" -> <| "command" -> "wolframscript" |> |> |> |>;
        result = Wolfram`AgentTools`InstallMCPServer`Private`guessClientNameFromJSON @ file;
        DeleteFile @ file;
        result
    ],
    "VisualStudioCode",
    SameTest -> Equal,
    TestID   -> "GuessClientNameFromJSON-VisualStudioCode-Legacy@@Tests/InstallMCPServer.wlt:3125,1-3135,2"
]

(* VSCode: has "servers" at root level (mcp.json format) *)
VerificationTest[
    Module[ { file, result },
        file = makeTestJSONFile[ <| "servers" -> <| "MyServer" -> <| "command" -> "wolframscript" |> |> |>, "mcp.json" ];
        result = Wolfram`AgentTools`InstallMCPServer`Private`guessClientNameFromJSON @ file;
        Quiet @ DeleteFile @ file;
        Quiet @ DeleteDirectory[ DirectoryName @ file ];
        result
    ],
    "VisualStudioCode",
    SameTest -> Equal,
    TestID   -> "GuessClientNameFromJSON-VisualStudioCode@@Tests/InstallMCPServer.wlt:3138,1-3149,2"
]

(* Generic "servers" key in non-mcp.json file -> None (avoid false positives) *)
VerificationTest[
    Module[ { file, result },
        file = makeTestJSONFile @ <| "servers" -> <| "MyServer" -> <| "command" -> "wolframscript" |> |> |>;
        result = Wolfram`AgentTools`InstallMCPServer`Private`guessClientNameFromJSON @ file;
        DeleteFile @ file;
        result
    ],
    None,
    SameTest -> Equal,
    TestID   -> "GuessClientNameFromJSON-GenericServersKey@@Tests/InstallMCPServer.wlt:3152,1-3162,2"
]

(* OpenCode: has "mcp" with entries that have "type" and List-valued "command" *)
VerificationTest[
    Module[ { file, result },
        file = makeTestJSONFile @ <| "mcp" -> <| "MyServer" -> <| "type" -> "local", "command" -> { "wolframscript" }, "enabled" -> True |> |> |>;
        result = Wolfram`AgentTools`InstallMCPServer`Private`guessClientNameFromJSON @ file;
        DeleteFile @ file;
        result
    ],
    "OpenCode",
    SameTest -> Equal,
    TestID   -> "GuessClientNameFromJSON-OpenCode@@Tests/InstallMCPServer.wlt:3165,1-3175,2"
]

(* CopilotCLI: has "mcpServers" with entries that have "tools" *)
VerificationTest[
    Module[ { file, result },
        file = makeTestJSONFile @ <| "mcpServers" -> <| "MyServer" -> <| "command" -> "wolframscript", "args" -> { }, "tools" -> { "*" } |> |> |>;
        result = Wolfram`AgentTools`InstallMCPServer`Private`guessClientNameFromJSON @ file;
        DeleteFile @ file;
        result
    ],
    "CopilotCLI",
    SameTest -> Equal,
    TestID   -> "GuessClientNameFromJSON-CopilotCLI@@Tests/InstallMCPServer.wlt:3178,1-3188,2"
]

(* Cline: has "mcpServers" with entries that have "disabled" and "autoApprove" *)
VerificationTest[
    Module[ { file, result },
        file = makeTestJSONFile @ <| "mcpServers" -> <| "MyServer" -> <| "command" -> "wolframscript", "disabled" -> False, "autoApprove" -> { } |> |> |>;
        result = Wolfram`AgentTools`InstallMCPServer`Private`guessClientNameFromJSON @ file;
        DeleteFile @ file;
        result
    ],
    "Cline",
    SameTest -> Equal,
    TestID   -> "GuessClientNameFromJSON-Cline@@Tests/InstallMCPServer.wlt:3191,1-3201,2"
]

(* Ambiguous: standard mcpServers with only command/args/env -> None *)
VerificationTest[
    Module[ { file, result },
        file = makeTestJSONFile @ <| "mcpServers" -> <| "MyServer" -> <| "command" -> "wolframscript", "args" -> { "-run" }, "env" -> <| |> |> |> |>;
        result = Wolfram`AgentTools`InstallMCPServer`Private`guessClientNameFromJSON @ file;
        DeleteFile @ file;
        result
    ],
    None,
    SameTest -> Equal,
    TestID   -> "GuessClientNameFromJSON-Ambiguous@@Tests/InstallMCPServer.wlt:3204,1-3214,2"
]

(* Empty JSON -> None *)
VerificationTest[
    Module[ { file, result },
        file = makeTestJSONFile @ <| |>;
        result = Wolfram`AgentTools`InstallMCPServer`Private`guessClientNameFromJSON @ file;
        DeleteFile @ file;
        result
    ],
    None,
    SameTest -> Equal,
    TestID   -> "GuessClientNameFromJSON-EmptyJSON@@Tests/InstallMCPServer.wlt:3217,1-3227,2"
]

(* Non-existent file -> None *)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`guessClientNameFromJSON @
        FileNameJoin @ { $TemporaryDirectory, "nonexistent_" <> CreateUUID[] <> ".json" },
    None,
    SameTest -> Equal,
    TestID   -> "GuessClientNameFromJSON-NonExistentFile@@Tests/InstallMCPServer.wlt:3230,1-3236,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*configKeyPath*)
VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installClientName = "ClaudeDesktop" },
        Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath[ ]
    ],
    { "mcpServers" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-ClaudeDesktop@@Tests/InstallMCPServer.wlt:3241,1-3248,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installClientName = "VisualStudioCode" },
        Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath[ ]
    ],
    { "servers" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-VSCode@@Tests/InstallMCPServer.wlt:3250,1-3257,2"
]

(* VS Code with mcp.json file: uses new key path *)
VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installClientName = "VisualStudioCode" },
        Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath @
            File @ FileNameJoin @ { $TemporaryDirectory, "mcp.json" }
    ],
    { "servers" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-VSCode-MCPJson@@Tests/InstallMCPServer.wlt:3260,1-3268,2"
]

(* VS Code with legacy settings.json: uses old nested key path *)
VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installClientName = "VisualStudioCode" },
        Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath @
            File @ FileNameJoin @ { $TemporaryDirectory, "settings.json" }
    ],
    { "mcp", "servers" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-VSCode-LegacySettings@@Tests/InstallMCPServer.wlt:3271,1-3279,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installClientName = "Zed" },
        Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath[ ]
    ],
    { "context_servers" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-Zed@@Tests/InstallMCPServer.wlt:3281,1-3288,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installClientName = "OpenCode" },
        Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath[ ]
    ],
    { "mcp" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-OpenCode@@Tests/InstallMCPServer.wlt:3290,1-3297,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath[ "UnknownClient" ],
    { "mcpServers" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-UnknownFallback@@Tests/InstallMCPServer.wlt:3299,1-3304,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installClientName = None },
        Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath[ ]
    ],
    { "mcpServers" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-NoneFallback@@Tests/InstallMCPServer.wlt:3306,1-3313,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*emptyConfigForPath*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`emptyConfigForPath @ { "mcpServers" },
    <| "mcpServers" -> <| |> |>,
    SameTest -> Equal,
    TestID   -> "EmptyConfigForPath-SingleKey@@Tests/InstallMCPServer.wlt:3318,1-3323,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`emptyConfigForPath @ { "mcp", "servers" },
    <| "mcp" -> <| "servers" -> <| |> |> |>,
    SameTest -> Equal,
    TestID   -> "EmptyConfigForPath-NestedKeys@@Tests/InstallMCPServer.wlt:3325,1-3330,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`emptyConfigForPath @ { },
    <| |>,
    SameTest -> Equal,
    TestID   -> "EmptyConfigForPath-EmptyPath@@Tests/InstallMCPServer.wlt:3332,1-3337,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureNestedKey*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`ensureNestedKey[ <| "other" -> 1 |>, { "mcpServers" } ],
    <| "other" -> 1, "mcpServers" -> <| |> |>,
    SameTest -> Equal,
    TestID   -> "EnsureNestedKey-AddMissing@@Tests/InstallMCPServer.wlt:3342,1-3347,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`ensureNestedKey[
        <| "mcpServers" -> <| "existing" -> "data" |> |>,
        { "mcpServers" }
    ],
    <| "mcpServers" -> <| "existing" -> "data" |> |>,
    SameTest -> Equal,
    TestID   -> "EnsureNestedKey-PreserveExisting@@Tests/InstallMCPServer.wlt:3349,1-3357,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`ensureNestedKey[
        <| "theme" -> "dark" |>,
        { "mcp", "servers" }
    ],
    <| "theme" -> "dark", "mcp" -> <| "servers" -> <| |> |> |>,
    SameTest -> Equal,
    TestID   -> "EnsureNestedKey-DeepNesting@@Tests/InstallMCPServer.wlt:3359,1-3367,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`ensureNestedKey[
        <| "mcp" -> <| "existing" -> 1 |> |>,
        { "mcp", "servers" }
    ],
    <| "mcp" -> <| "existing" -> 1, "servers" -> <| |> |> |>,
    SameTest -> Equal,
    TestID   -> "EnsureNestedKey-PartiallyExisting@@Tests/InstallMCPServer.wlt:3369,1-3377,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`ensureNestedKey[ "notAssoc", { "mcpServers" } ],
    <| "mcpServers" -> <| |> |>,
    SameTest -> Equal,
    TestID   -> "EnsureNestedKey-NonAssocInput@@Tests/InstallMCPServer.wlt:3379,1-3384,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*serverConverter*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`serverConverter[ "OpenCode" ],
    Wolfram`AgentTools`SupportedClients`Private`convertToOpenCodeFormat,
    SameTest -> SameQ,
    TestID   -> "ServerConverter-OpenCode@@Tests/InstallMCPServer.wlt:3389,1-3394,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`serverConverter[ "CopilotCLI" ],
    Wolfram`AgentTools`SupportedClients`Private`convertToCopilotCLIFormat,
    SameTest -> SameQ,
    TestID   -> "ServerConverter-CopilotCLI@@Tests/InstallMCPServer.wlt:3396,1-3401,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`serverConverter[ "Cline" ],
    Wolfram`AgentTools`SupportedClients`Private`convertToClineFormat,
    SameTest -> SameQ,
    TestID   -> "ServerConverter-Cline@@Tests/InstallMCPServer.wlt:3403,1-3408,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`serverConverter[ "ClaudeDesktop" ],
    Identity,
    SameTest -> SameQ,
    TestID   -> "ServerConverter-Default@@Tests/InstallMCPServer.wlt:3410,1-3415,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveMCPServerName*)
VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installMCPServerName = Automatic },
        Wolfram`AgentTools`InstallMCPServer`Private`resolveMCPServerName @ MCPServerObject[ "WolframLanguage" ]
    ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "ResolveMCPServerName-BuiltInServer@@Tests/InstallMCPServer.wlt:3420,1-3427,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installMCPServerName = "CustomKey" },
        Wolfram`AgentTools`InstallMCPServer`Private`resolveMCPServerName @ MCPServerObject[ "WolframLanguage" ]
    ],
    "CustomKey",
    SameTest -> Equal,
    TestID   -> "ResolveMCPServerName-OptionOverride@@Tests/InstallMCPServer.wlt:3429,1-3436,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installMCPServerName = Automatic },
        Wolfram`AgentTools`InstallMCPServer`Private`resolveMCPServerName @ MCPServerObject[ "Wolfram" ]
    ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "ResolveMCPServerName-WolframServer@@Tests/InstallMCPServer.wlt:3438,1-3445,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paclet-Qualified Server Names*)

$testResourceDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Mock Paclet Setup*)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
    $mockPaclet = First @ PacletFind[ "MockMCPPacletTest" ];
    $mockPaclet[ "Name" ],
    "MockMCPPacletTest",
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-MockPacletSetup@@Tests/InstallMCPServer.wlt:3456,1-3463,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCPServerName property for paclet server*)
VerificationTest[
    MCPServerObject[ "MockMCPPacletTest/TestServer" ][ "MCPServerName" ],
    "TestServer",
    SameTest -> Equal,
    TestID   -> "MCPServerName-PacletServerProperty@@Tests/InstallMCPServer.wlt:3468,1-3473,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveMCPServerName - paclet server uses short name*)
VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installMCPServerName = Automatic },
        Wolfram`AgentTools`InstallMCPServer`Private`resolveMCPServerName @ MCPServerObject[ "MockMCPPacletTest/TestServer" ]
    ],
    "TestServer",
    SameTest -> Equal,
    TestID   -> "ResolveMCPServerName-PacletServerShortName@@Tests/InstallMCPServer.wlt:3478,1-3485,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensurePacletForInstall - already installed*)
VerificationTest[
    Wolfram`AgentTools`Common`ensurePacletForInstall[ "MockMCPPacletTest/TestServer" ],
    _PacletObject,
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-EnsurePacletAlreadyInstalled@@Tests/InstallMCPServer.wlt:3490,1-3495,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensurePacletForInstall - three-segment name*)
VerificationTest[
    Wolfram`AgentTools`Common`ensurePacletForInstall[ "MockMCPPacletTest/TestServer/SomeItem" ],
    (* "MockMCPPacletTest/TestServer" is NOT a valid paclet name here, so this should fail *)
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-EnsurePacletThreeSegment@@Tests/InstallMCPServer.wlt:3500,1-3507,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install paclet-qualified server to config file*)
VerificationTest[
    $pacletConfigFile = testConfigFile[];
    $pacletInstallResult = InstallMCPServer[ $pacletConfigFile, "MockMCPPacletTest/TestServer", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-Install@@Tests/InstallMCPServer.wlt:3512,1-3518,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config file created*)
VerificationTest[
    FileExistsQ @ $pacletConfigFile,
    True,
    SameTest -> Equal,
    TestID   -> "InstallPacletServer-ConfigFileExists@@Tests/InstallMCPServer.wlt:3523,1-3528,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config file has correct server name as key*)
VerificationTest[
    $pacletConfigJSON = Import[ $pacletConfigFile, "RawJSON" ];
    KeyExistsQ[ $pacletConfigJSON[ "mcpServers" ], "TestServer" ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallPacletServer-ConfigHasServerName@@Tests/InstallMCPServer.wlt:3533,1-3539,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config server entry has correct MCP_SERVER_NAME env var*)
VerificationTest[
    $pacletConfigJSON[ "mcpServers", "TestServer", "env", "MCP_SERVER_NAME" ],
    "MockMCPPacletTest/TestServer",
    SameTest -> Equal,
    TestID   -> "InstallPacletServer-ConfigEnvServerName@@Tests/InstallMCPServer.wlt:3544,1-3549,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Uninstall paclet server*)
VerificationTest[
    UninstallMCPServer[ $pacletConfigFile, MCPServerObject[ "MockMCPPacletTest/TestServer" ] ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-Uninstall@@Tests/InstallMCPServer.wlt:3554,1-3559,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config no longer has server after uninstall*)
VerificationTest[
    updatedJSON = Import[ $pacletConfigFile, "RawJSON" ];
    KeyExistsQ[ updatedJSON[ "mcpServers" ], "TestServer" ],
    False,
    SameTest -> Equal,
    TestID   -> "InstallPacletServer-VerifyUninstall@@Tests/InstallMCPServer.wlt:3564,1-3570,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install result contains MCPServerObject*)
VerificationTest[
    $pacletInstallResult2 = InstallMCPServer[ $pacletConfigFile, "MockMCPPacletTest/TestServer", "VerifyLLMKit" -> False ];
    $pacletInstallResult2[ "MCPServerObject" ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-ResultHasMCPServerObject@@Tests/InstallMCPServer.wlt:3575,1-3581,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validatePacletServerDefinitions - no error for valid paclet server*)
VerificationTest[
    obj = MCPServerObject[ "MockMCPPacletTest/TestServer" ];
    Wolfram`AgentTools`InstallMCPServer`Private`validatePacletServerDefinitions @ obj,
    Null,
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-ValidateDefinitionsValid@@Tests/InstallMCPServer.wlt:3586,1-3592,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validatePacletServerDefinitions - no-op for server without paclet references*)
VerificationTest[
    testServer = CreateMCPServer[
        StringJoin[ "NoPacletRefs_", CreateUUID[] ],
        LLMConfiguration @ <| "Tools" -> { LLMTool[ "Simple", { "x" -> "Integer" }, #x & ] } |>
    ];
    result = Wolfram`AgentTools`InstallMCPServer`Private`validatePacletServerDefinitions @ testServer;
    DeleteObject @ testServer;
    result,
    Null,
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-ValidateDefinitionsNoOp@@Tests/InstallMCPServer.wlt:3597,1-3608,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validatePacletServerDefinitions - catches invalid paclet tool*)
VerificationTest[
    badToolServerName = StringJoin[ "BadToolServer_", CreateUUID[] ];
    badToolServer = CreateMCPServer[
        badToolServerName,
        <| "Tools" -> { "NonExistentPaclet/BadTool" } |>
    ];
    result = Wolfram`AgentTools`Common`catchAlways[
        Wolfram`AgentTools`InstallMCPServer`Private`validatePacletServerDefinitions @ badToolServer
    ];
    DeleteObject @ badToolServer;
    result,
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-ValidateToolError@@Tests/InstallMCPServer.wlt:3613,1-3628,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validatePacletServerDefinitions - catches invalid paclet prompt*)
VerificationTest[
    badPromptServerName = StringJoin[ "BadPromptServer_", CreateUUID[] ];
    badPromptServer = CreateMCPServer[
        badPromptServerName,
        <| "MCPPrompts" -> { "NonExistentPaclet/BadPrompt" } |>
    ];
    result = Wolfram`AgentTools`Common`catchAlways[
        Wolfram`AgentTools`InstallMCPServer`Private`validatePacletServerDefinitions @ badPromptServer
    ];
    DeleteObject @ badPromptServer;
    result,
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-ValidatePromptError@@Tests/InstallMCPServer.wlt:3633,1-3648,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    cleanupTestFiles @ $pacletConfigFile;
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-Cleanup@@Tests/InstallMCPServer.wlt:3653,1-3659,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*MCPServerName Option*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Built-in server uses "Wolfram" config key*)
VerificationTest[
    mcpNameConfigFile = testConfigFile[];
    InstallMCPServer[ mcpNameConfigFile, "WolframLanguage", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "MCPServerName-BuiltInUsesWolframKey-Install@@Tests/InstallMCPServer.wlt:3668,1-3674,2"
]

VerificationTest[
    jsonContent = Import[ mcpNameConfigFile, "RawJSON" ];
    KeyExistsQ[ jsonContent[ "mcpServers" ], "Wolfram" ] &&
    ! KeyExistsQ[ jsonContent[ "mcpServers" ], "WolframLanguage" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-BuiltInUsesWolframKey-Verify@@Tests/InstallMCPServer.wlt:3676,1-3683,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Second built-in overwrites first under shared key*)
VerificationTest[
    InstallMCPServer[ mcpNameConfigFile, "WolframAlpha", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "MCPServerName-SecondBuiltInOverwrites-Install@@Tests/InstallMCPServer.wlt:3688,1-3693,2"
]

VerificationTest[
    jsonContent = Import[ mcpNameConfigFile, "RawJSON" ];
    Length[ Keys[ jsonContent[ "mcpServers" ] ] ] === 1 &&
    KeyExistsQ[ jsonContent[ "mcpServers" ], "Wolfram" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-SecondBuiltInOverwrites-Verify@@Tests/InstallMCPServer.wlt:3695,1-3702,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Uninstall built-in removes "Wolfram" key*)
VerificationTest[
    UninstallMCPServer[ mcpNameConfigFile, "WolframAlpha" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "MCPServerName-UninstallBuiltIn@@Tests/InstallMCPServer.wlt:3707,1-3712,2"
]

VerificationTest[
    jsonContent = Import[ mcpNameConfigFile, "RawJSON" ];
    ! KeyExistsQ[ jsonContent[ "mcpServers" ], "Wolfram" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-UninstallBuiltIn-Verify@@Tests/InstallMCPServer.wlt:3714,1-3720,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Custom server uses its Name as config key*)
VerificationTest[
    mcpNameCustomName = StringJoin[ "CustomMCPTest_", CreateUUID[] ];
    mcpNameCustomServer = CreateMCPServer[
        mcpNameCustomName,
        LLMConfiguration @ <| "Tools" -> { LLMTool[ "Echo", { "x" -> "String" }, #x & ] } |>
    ];
    InstallMCPServer[ mcpNameConfigFile, mcpNameCustomServer, "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "MCPServerName-CustomServerUsesName-Install@@Tests/InstallMCPServer.wlt:3725,1-3735,2"
]

VerificationTest[
    jsonContent = Import[ mcpNameConfigFile, "RawJSON" ];
    KeyExistsQ[ jsonContent[ "mcpServers" ], mcpNameCustomName ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-CustomServerUsesName-Verify@@Tests/InstallMCPServer.wlt:3737,1-3743,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCPServerName option override*)
VerificationTest[
    InstallMCPServer[ mcpNameConfigFile, "WolframLanguage", "MCPServerName" -> "WolframDev", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "MCPServerName-OptionOverride-Install@@Tests/InstallMCPServer.wlt:3748,1-3753,2"
]

VerificationTest[
    jsonContent = Import[ mcpNameConfigFile, "RawJSON" ];
    KeyExistsQ[ jsonContent[ "mcpServers" ], "WolframDev" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-OptionOverride-Verify@@Tests/InstallMCPServer.wlt:3755,1-3761,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Two built-in servers with different MCPServerName overrides coexist*)
VerificationTest[
    mcpNameConfigFile2 = testConfigFile[];
    InstallMCPServer[ mcpNameConfigFile2, "Wolfram", "MCPServerName" -> "WolframBasic", "VerifyLLMKit" -> False ];
    InstallMCPServer[ mcpNameConfigFile2, "WolframLanguage", "MCPServerName" -> "WolframDev2", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "MCPServerName-TwoBuiltInWithOverrides-Install@@Tests/InstallMCPServer.wlt:3766,1-3773,2"
]

VerificationTest[
    jsonContent = Import[ mcpNameConfigFile2, "RawJSON" ];
    KeyExistsQ[ jsonContent[ "mcpServers" ], "WolframBasic" ] &&
    KeyExistsQ[ jsonContent[ "mcpServers" ], "WolframDev2" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-TwoBuiltInWithOverrides-Verify@@Tests/InstallMCPServer.wlt:3775,1-3782,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Installation record clearing for shared key*)
VerificationTest[
    mcpNameConfigFile3 = testConfigFile[];
    InstallMCPServer[ mcpNameConfigFile3, "Wolfram", "VerifyLLMKit" -> False ];
    wolframInstalls = MCPServerObject[ "Wolfram" ][ "Installations" ];
    MemberQ[ wolframInstalls, KeyValuePattern[ "ConfigurationFile" -> mcpNameConfigFile3 ] ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-StaleRecordClearing-Setup@@Tests/InstallMCPServer.wlt:3787,1-3795,2"
]

VerificationTest[
    InstallMCPServer[ mcpNameConfigFile3, "WolframLanguage", "VerifyLLMKit" -> False ];
    wolframInstalls = MCPServerObject[ "Wolfram" ][ "Installations" ];
    wlInstalls = MCPServerObject[ "WolframLanguage" ][ "Installations" ];
    (* Wolfram's record for this file should be cleared, WolframLanguage should have it *)
    ! MemberQ[ wolframInstalls, KeyValuePattern[ "ConfigurationFile" -> mcpNameConfigFile3 ] ] &&
    MemberQ[ wlInstalls, KeyValuePattern[ "ConfigurationFile" -> mcpNameConfigFile3 ] ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-StaleRecordClearing-Verify@@Tests/InstallMCPServer.wlt:3797,1-3807,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    UninstallMCPServer[ mcpNameConfigFile ];
    UninstallMCPServer[ mcpNameConfigFile2 ];
    UninstallMCPServer[ mcpNameConfigFile3 ];
    DeleteObject[ mcpNameCustomServer ];
    cleanupTestFiles[ { mcpNameConfigFile, mcpNameConfigFile2, mcpNameConfigFile3 } ],
    { Null.. },
    SameTest -> MatchQ,
    TestID   -> "MCPServerName-Cleanup@@Tests/InstallMCPServer.wlt:3812,1-3821,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Automatic toolset resolution (per-client DefaultToolset)*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*defaultToolsetForTarget helper*)
VerificationTest[
    defaultToolsetForTarget = Wolfram`AgentTools`Common`defaultToolsetForTarget;
    defaultToolsetForTarget[ "ClaudeCode" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-ClaudeCode@@Tests/InstallMCPServer.wlt:3830,1-3836,2"
]

VerificationTest[
    defaultToolsetForTarget[ "ClaudeDesktop" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-ClaudeDesktop@@Tests/InstallMCPServer.wlt:3838,1-3843,2"
]

VerificationTest[
    defaultToolsetForTarget[ "Goose" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Goose@@Tests/InstallMCPServer.wlt:3845,1-3850,2"
]

VerificationTest[
    defaultToolsetForTarget[ "Cursor" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Cursor@@Tests/InstallMCPServer.wlt:3852,1-3857,2"
]

(* Junie is a coding agent (covers JetBrains IDE plugin and Junie CLI), so it defaults to WolframLanguage *)
VerificationTest[
    defaultToolsetForTarget[ "Junie" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Junie@@Tests/InstallMCPServer.wlt:3860,1-3865,2"
]

(* Junie alias resolves to the canonical client's default *)
VerificationTest[
    defaultToolsetForTarget[ "JetBrainsJunie" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Alias-JetBrainsJunie@@Tests/InstallMCPServer.wlt:3868,1-3873,2"
]

(* {Junie, dir} project-install form *)
VerificationTest[
    defaultToolsetForTarget[ { "Junie", "/some/dir" } ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-NameDir-Junie@@Tests/InstallMCPServer.wlt:3876,1-3881,2"
]

(* Aliases resolve to their canonical client's default *)
VerificationTest[
    defaultToolsetForTarget[ "Claude" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Alias-Claude@@Tests/InstallMCPServer.wlt:3884,1-3889,2"
]

VerificationTest[
    defaultToolsetForTarget[ "VSCode" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Alias-VSCode@@Tests/InstallMCPServer.wlt:3891,1-3896,2"
]

(* Unknown client falls back to $defaultMCPServer *)
VerificationTest[
    defaultToolsetForTarget[ "TotallyMadeUpClient" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Unknown@@Tests/InstallMCPServer.wlt:3899,1-3904,2"
]

(* {name, dir} project-install form dispatches on the name *)
VerificationTest[
    defaultToolsetForTarget[ { "ClaudeCode", "/some/dir" } ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-NameDir-ClaudeCode@@Tests/InstallMCPServer.wlt:3907,1-3912,2"
]

VerificationTest[
    defaultToolsetForTarget[ { "ClaudeDesktop", "/some/dir" } ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-NameDir-ClaudeDesktop@@Tests/InstallMCPServer.wlt:3914,1-3919,2"
]

(* File target with no client match falls back *)
VerificationTest[
    defaultToolsetForTarget[ File[ "C:/this/path/is/not/a/known/client.json" ] ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-Unknown@@Tests/InstallMCPServer.wlt:3922,1-3927,2"
]

(* Recognizable File[...] targets resolve via path-based client detection
   (no ApplicationName needed). These guard against regressions where
   defaultToolsetForTarget would silently fall back to "Wolfram" for files
   that guessClientName already identifies. *)

(* .mcp.json -> ClaudeCode (coding client, "WolframLanguage") *)
VerificationTest[
    defaultToolsetForTarget[ File[ "/some/project/.mcp.json" ] ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-ClaudeCodeProject@@Tests/InstallMCPServer.wlt:3935,1-3940,2"
]

(* .vscode/mcp.json -> VisualStudioCode (coding client, "WolframLanguage") *)
VerificationTest[
    defaultToolsetForTarget[ File[ "/some/project/.vscode/mcp.json" ] ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-VSCodeProject@@Tests/InstallMCPServer.wlt:3943,1-3948,2"
]

(* opencode.json -> OpenCode (coding client, "WolframLanguage") *)
VerificationTest[
    defaultToolsetForTarget[ File[ "/some/project/opencode.json" ] ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-OpenCodeProject@@Tests/InstallMCPServer.wlt:3951,1-3956,2"
]

(* Non-target argument falls back *)
VerificationTest[
    defaultToolsetForTarget[ 42 ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-NonTarget@@Tests/InstallMCPServer.wlt:3959,1-3964,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*defaultToolsetForTarget with explicit ApplicationName*)
(* The 2-arg form lets callers override path-based resolution by passing an
   explicit application name (the same string accepted by "ApplicationName"). *)
VerificationTest[
    defaultToolsetForTarget[ File[ "C:/this/path/is/not/a/known/client.json" ], "Cline" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-AppName-Cline@@Tests/InstallMCPServer.wlt:3971,1-3976,2"
]

VerificationTest[
    defaultToolsetForTarget[ File[ "C:/this/path/is/not/a/known/client.json" ], "ClaudeDesktop" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-AppName-ClaudeDesktop@@Tests/InstallMCPServer.wlt:3978,1-3983,2"
]

(* Aliases route through toInstallName, so an alias picks up the canonical client's default *)
VerificationTest[
    defaultToolsetForTarget[ File[ "C:/this/path/is/not/a/known/client.json" ], "VSCode" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-AppName-Alias@@Tests/InstallMCPServer.wlt:3986,1-3991,2"
]

(* Automatic in the 2-arg form falls back to the existing target-based resolution *)
VerificationTest[
    defaultToolsetForTarget[ File[ "C:/this/path/is/not/a/known/client.json" ], Automatic ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-AppName-Automatic@@Tests/InstallMCPServer.wlt:3994,1-3999,2"
]

(* String target is also overridden by an explicit ApplicationName *)
VerificationTest[
    defaultToolsetForTarget[ "ClaudeCode", "ClaudeDesktop" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-StringTarget-AppName@@Tests/InstallMCPServer.wlt:4002,1-4007,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*InstallMCPServer with Automatic resolution*)
VerificationTest[
    autoTestDir = CreateDirectory[ ];
    autoInstallResultAuto = InstallMCPServer[
        { "ClaudeCode", autoTestDir },
        Automatic,
        "VerifyLLMKit" -> False
    ];
    autoInstallResultAuto[[ 2 ]][ "MCPServerObject" ][ "Name" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Automatic-ClaudeCode@@Tests/InstallMCPServer.wlt:4012,1-4023,2"
]

(* 1-arg form should give the same result as Automatic *)
VerificationTest[
    Quiet @ DeleteDirectory[ autoTestDir, DeleteContents -> True ];
    autoTestDir = CreateDirectory[ ];
    autoInstallResult1Arg = InstallMCPServer[
        { "ClaudeCode", autoTestDir },
        "VerifyLLMKit" -> False
    ];
    autoInstallResult1Arg[[ 2 ]][ "MCPServerObject" ][ "Name" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-1Arg-ClaudeCode@@Tests/InstallMCPServer.wlt:4026,1-4037,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*InstallMCPServer Automatic with File target + ApplicationName*)
(* For arbitrary File[...] targets whose path doesn't reveal the client, an
   explicit "ApplicationName" must drive the Automatic toolset choice. *)
VerificationTest[
    autoCustomFile = testConfigFile[ ];
    autoInstallResultFileApp = InstallMCPServer[
        autoCustomFile,
        Automatic,
        "ApplicationName" -> "Cline",
        "VerifyLLMKit"    -> False
    ];
    autoInstallResultFileApp[[ 2 ]][ "MCPServerObject" ][ "Name" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Automatic-File-AppName-Cline@@Tests/InstallMCPServer.wlt:4044,1-4056,2"
]

VerificationTest[
    cleanupTestFiles @ autoCustomFile;
    autoCustomFile = testConfigFile[ ];
    autoInstallResultFileChat = InstallMCPServer[
        autoCustomFile,
        Automatic,
        "ApplicationName" -> "ClaudeDesktop",
        "VerifyLLMKit"    -> False
    ];
    autoInstallResultFileChat[[ 2 ]][ "MCPServerObject" ][ "Name" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Automatic-File-AppName-ClaudeDesktop@@Tests/InstallMCPServer.wlt:4058,1-4071,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*InstallMCPServer Automatic with recognizable File targets (no ApplicationName)*)
(* When the File[...] path itself identifies a known client, Automatic must
   resolve to that client's DefaultToolset without any "ApplicationName"
   override.  These guard against regressions where path-based detection
   silently drops back to the global default. *)

(* .mcp.json -> ClaudeCode -> "WolframLanguage" *)
VerificationTest[
    autoRecognizableDir = CreateDirectory[ ];
    autoRecognizableFile = File @ FileNameJoin @ { autoRecognizableDir, ".mcp.json" };
    autoInstallResultFileClaudeCode = InstallMCPServer[
        autoRecognizableFile,
        Automatic,
        "VerifyLLMKit" -> False
    ];
    autoInstallResultFileClaudeCode[[ 2 ]][ "MCPServerObject" ][ "Name" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Automatic-File-ClaudeCodeProject@@Tests/InstallMCPServer.wlt:4082,1-4094,2"
]

(* .vscode/mcp.json -> VisualStudioCode -> "WolframLanguage" *)
VerificationTest[
    Quiet @ DeleteDirectory[ autoRecognizableDir, DeleteContents -> True ];
    autoRecognizableDir = CreateDirectory[ ];
    CreateDirectory @ FileNameJoin @ { autoRecognizableDir, ".vscode" };
    autoRecognizableFile = File @ FileNameJoin @ { autoRecognizableDir, ".vscode", "mcp.json" };
    autoInstallResultFileVSCode = InstallMCPServer[
        autoRecognizableFile,
        Automatic,
        "VerifyLLMKit" -> False
    ];
    autoInstallResultFileVSCode[[ 2 ]][ "MCPServerObject" ][ "Name" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Automatic-File-VSCodeProject@@Tests/InstallMCPServer.wlt:4097,1-4111,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$SupportedMCPClients DefaultToolset coverage*)
(* Every $SupportedMCPClients entry must expose a string DefaultToolset that
   names a real predefined server.  This catches typos or missing metadata in
   any client whose toolset isn't covered by an individual VerificationTest. *)
VerificationTest[
    Module[ { knownServers, validQ },
        knownServers = Keys @ $DefaultMCPServers;
        validQ = Function[ meta,
            With[ { toolset = Lookup[ meta, "DefaultToolset" ] },
                StringQ @ toolset && MemberQ[ knownServers, toolset ]
            ]
        ];
        Keys @ Select[ $SupportedMCPClients, ! validQ[ # ] & ]
    ],
    { },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-DefaultToolset-Coverage@@Tests/InstallMCPServer.wlt:4119,1-4132,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet @ DeleteDirectory[ autoTestDir, DeleteContents -> True ];
    Quiet @ DeleteDirectory[ autoRecognizableDir, DeleteContents -> True ];
    cleanupTestFiles @ autoCustomFile;
    True,
    True,
    TestID -> "Automatic-Cleanup@@Tests/InstallMCPServer.wlt:4137,1-4144,2"
]

(* :!CodeAnalysis::EndBlock:: *)