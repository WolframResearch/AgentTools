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
(*EnableLLMKit Option*)

(* "EnableLLMKit" -> False injects LLMKIT_ENABLED=false into the server's env block. The server then
   runs the context tools as if the user has no LLMKit subscription, but without any subscription
   warnings. Mirrors the "EnableMCPApps" / MCP_APPS_ENABLED pattern. *)
installLLMKitEnv[ opts___ ] := Module[ { configFile, name, server, env },
    configFile = File @ FileNameJoin @ { $TemporaryDirectory, StringJoin[ "mcp_llmkit_", CreateUUID[], ".json" ] };
    name       = StringJoin[ "TestServer_LLMKit_", CreateUUID[] ];
    server     = CreateMCPServer[
        name,
        LLMConfiguration @ <| "Tools" -> { LLMTool[ "PrimeFinder", { "n" -> "Integer" }, Prime[ #n ] & ] } |>
    ];
    InstallMCPServer[ configFile, server, opts, "VerifyLLMKit" -> False ];
    env = Developer`ReadRawJSONString[ ReadString @ First @ configFile ][ "mcpServers", name, "env" ];
    Quiet @ DeleteFile @ First @ configFile;
    DeleteObject[ server ];
    Lookup[ env, "LLMKIT_ENABLED", Missing[ "Absent" ] ]
];

VerificationTest[
    installLLMKitEnv[ "EnableLLMKit" -> False ],
    "false",
    SameTest -> SameQ,
    TestID   -> "InstallMCPServer-EnableLLMKitFalseInjectsEnv@@Tests/InstallMCPServer.wlt:273,1-278,2"
]

(* Default is Automatic (equivalent to True): no LLMKIT_ENABLED variable is injected, so LLMKit
   stays enabled and existing installations are unaffected. *)
VerificationTest[
    installLLMKitEnv[ ],
    Missing[ "Absent" ],
    SameTest -> SameQ,
    TestID   -> "InstallMCPServer-EnableLLMKitDefaultAbsent@@Tests/InstallMCPServer.wlt:282,1-287,2"
]

VerificationTest[
    installLLMKitEnv[ "EnableLLMKit" -> True ],
    Missing[ "Absent" ],
    SameTest -> SameQ,
    TestID   -> "InstallMCPServer-EnableLLMKitTrueAbsent@@Tests/InstallMCPServer.wlt:289,1-294,2"
]

VerificationTest[
    installLLMKitEnv[ "EnableLLMKit" -> Automatic ],
    Missing[ "Absent" ],
    SameTest -> SameQ,
    TestID   -> "InstallMCPServer-EnableLLMKitAutomaticAbsent@@Tests/InstallMCPServer.wlt:296,1-301,2"
]

(* "EnableLLMKit" -> False must also skip the install-time LLMKit requirement check, so a server with
   an LLMKit-required tool installs without a subscription failure and without consulting the
   subscription status. Verified at the unit level: the guard returns None before llmKitSubscribedQ
   is ever called. *)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
VerificationTest[
    Module[ { name, server, called = False, result },
        name   = StringJoin[ "TestServer_LLMKitGuard_", CreateUUID[] ];
        server = CreateMCPServer[
            name,
            LLMConfiguration @ <| "Tools" -> { $DefaultMCPTools[ "WolframAlphaContext" ] } |>
        ];
        result = Block[
            {
                Wolfram`AgentTools`InstallMCPServer`Private`$enableLLMKit = False,
                Wolfram`AgentTools`Common`llmKitSubscribedQ = Function[ called = True; False ]
            },
            Wolfram`AgentTools`InstallMCPServer`Private`checkLLMKitRequirements[ server ]
        ];
        DeleteObject[ server ];
        { result, called }
    ],
    { None, False },
    SameTest -> SameQ,
    TestID   -> "CheckLLMKitRequirements-DisabledSkipsCheck@@Tests/InstallMCPServer.wlt:309,1-329,2"
]
(* :!CodeAnalysis::EndBlock:: *)

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
    TestID   -> "InstallMCPServer-FromAssociation@@Tests/InstallMCPServer.wlt:335,1-344,2"
]

VerificationTest[
    jsonContent = Import[configFile, "RawJSON"];
    KeyExistsQ[jsonContent, "mcpServers"] && KeyExistsQ[jsonContent["mcpServers"], name],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-VerifyAssociationServer@@Tests/InstallMCPServer.wlt:346,1-352,2"
]

VerificationTest[
    UninstallMCPServer[configFile, name];
    DeleteObject[server];
    cleanupTestFiles[configFile],
    {Null},
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-CleanupAssociation@@Tests/InstallMCPServer.wlt:354,1-361,2"
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
    TestID   -> "InstallMCPServer-ClaudeCodeLike@@Tests/InstallMCPServer.wlt:366,1-374,2"
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
    TestID   -> "InstallMCPServer-PreservesOtherData@@Tests/InstallMCPServer.wlt:376,1-386,2"
]

VerificationTest[
    (* Install a second server to verify multiple installations work *)
    installResult2 = InstallMCPServer[configFile, "WolframAlpha"];
    jsonContent = Import[configFile, "RawJSON"];
    Length[Keys[jsonContent["mcpServers"]]] === 1 &&
    KeyExistsQ[jsonContent["mcpServers"], "Wolfram"],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-MultipleBuiltInOverwrite@@Tests/InstallMCPServer.wlt:388,1-397,2"
]

VerificationTest[
    UninstallMCPServer[configFile];
    cleanupTestFiles[configFile],
    {Null},
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-CleanupClaudeCodeLike@@Tests/InstallMCPServer.wlt:399,1-405,2"
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
    TestID   -> "InstallMCPServer-InvalidJSON@@Tests/InstallMCPServer.wlt:410,1-418,2"
]

VerificationTest[
    configFile = testConfigFile[];
    Export[configFile, "{}", "JSON"];
    InstallMCPServer[configFile, "NonExistentServer"],
    _Failure,
    {InstallMCPServer::MCPServerNotFound},
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-NonExistentServer@@Tests/InstallMCPServer.wlt:420,1-428,2"
]

VerificationTest[
    cleanupTestFiles[configFile],
    {Null},
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-CleanupErrorTests@@Tests/InstallMCPServer.wlt:430,1-435,2"
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
    TestID   -> "InstallLocation-Antigravity-Windows@@Tests/InstallMCPServer.wlt:444,1-449,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Antigravity", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Antigravity-MacOSX@@Tests/InstallMCPServer.wlt:451,1-456,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Antigravity", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Antigravity-Unix@@Tests/InstallMCPServer.wlt:458,1-463,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Antigravity" ],
    "Antigravity",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Antigravity@@Tests/InstallMCPServer.wlt:465,1-470,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "GoogleAntigravity" ],
    "Antigravity",
    SameTest -> Equal,
    TestID   -> "ToInstallName-GoogleAntigravity@@Tests/InstallMCPServer.wlt:472,1-477,2"
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
    TestID   -> "AntigravityInstallLocation-MigratedVsFresh@@Tests/InstallMCPServer.wlt:483,1-501,2"
]

(* "AntigravityCLI" and "GoogleAntigravityCLI" are aliases of the unified "Antigravity"
   client, not separate entries -- the CLI and IDE share one global config file, so two
   entries would collide in DeployAgentTools/DeleteObject. Resolution must canonicalize to
   "Antigravity". *)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "AntigravityCLI" ],
    "Antigravity",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AntigravityCLI@@Tests/InstallMCPServer.wlt:507,1-512,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "GoogleAntigravityCLI" ],
    "Antigravity",
    SameTest -> Equal,
    TestID   -> "ToInstallName-GoogleAntigravityCLI@@Tests/InstallMCPServer.wlt:514,1-519,2"
]

(* installLocation alias-resolves internally, so the CLI alias yields the same _File as
   the canonical "Antigravity" entry. *)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AntigravityCLI", "Windows" ] ===
        Wolfram`AgentTools`Common`installLocation[ "Antigravity", "Windows" ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallLocation-AntigravityCLI-AliasMatchesCanonical@@Tests/InstallMCPServer.wlt:523,1-529,2"
]

(* The unified entry has project support (the CLI's workspace path .agents/mcp_config.json),
   reachable via the alias. *)
VerificationTest[
    TrueQ @ $SupportedMCPClients[ "Antigravity", "ProjectSupport" ],
    True,
    SameTest -> Equal,
    TestID   -> "Antigravity-HasProjectSupport@@Tests/InstallMCPServer.wlt:533,1-538,2"
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
    TestID   -> "ProjectInstallLocation-ClaudeCode@@Tests/InstallMCPServer.wlt:545,1-554,2"
]

VerificationTest[
    Module[ { result },
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "ClaudeCode", File[ "AgentTools" ] ];
        FileNameTake[ First @ result, -1 ]
    ],
    ".mcp.json",
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-ClaudeCode-FileWrapper@@Tests/InstallMCPServer.wlt:556,1-564,2"
]

VerificationTest[
    Module[ { path, result },
        path = FileNameJoin @ { $TemporaryDirectory, "TestProject" };
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "OpenCode", path ];
        FileNameTake[ First @ result, -1 ]
    ],
    "opencode.json",
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-OpenCode@@Tests/InstallMCPServer.wlt:566,1-575,2"
]

VerificationTest[
    Module[ { path, result },
        path = FileNameJoin @ { $TemporaryDirectory, "TestProject" };
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "Codex", path ];
        FileNameTake[ First @ result, -2 ]
    ],
    FileNameJoin @ { ".codex", "config.toml" },
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-Codex@@Tests/InstallMCPServer.wlt:577,1-586,2"
]

(* Workspace install for the unified Antigravity entry goes to .agents/mcp_config.json
   (the CLI's project path). projectInstallLocation is always called with the canonical
   name -- InstallMCPServer[{"AntigravityCLI", dir}] canonicalizes via toInstallName first
   -- so we test the canonical "Antigravity" here. *)
VerificationTest[
    Module[ { path, result },
        path = FileNameJoin @ { $TemporaryDirectory, "TestProject" };
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "Antigravity", path ];
        FileNameTake[ First @ result, -2 ]
    ],
    FileNameJoin @ { ".agents", "mcp_config.json" },
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-Antigravity@@Tests/InstallMCPServer.wlt:592,1-601,2"
]

VerificationTest[
    Module[ { path, result },
        path = FileNameJoin @ { $TemporaryDirectory, "TestProject" };
        result = Wolfram`AgentTools`Common`projectInstallLocation[ "VisualStudioCode", path ];
        FileNameTake[ First @ result, -2 ]
    ],
    FileNameJoin @ { ".vscode", "mcp.json" },
    SameTest -> Equal,
    TestID   -> "ProjectInstallLocation-VisualStudioCode@@Tests/InstallMCPServer.wlt:603,1-612,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways[
        Wolfram`AgentTools`Common`projectInstallLocation[ "ClaudeCode", Symbol[ "xyz" ] ]
    ],
    _Failure,
    { AgentTools::InvalidProjectDirectory },
    SameTest -> MatchQ,
    TestID   -> "ProjectInstallLocation-InvalidDirectory-Symbol@@Tests/InstallMCPServer.wlt:614,1-622,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways[
        Wolfram`AgentTools`Common`projectInstallLocation[ "ClaudeCode", 123 ]
    ],
    _Failure,
    { AgentTools::InvalidProjectDirectory },
    SameTest -> MatchQ,
    TestID   -> "ProjectInstallLocation-InvalidDirectory-Integer@@Tests/InstallMCPServer.wlt:624,1-632,2"
]

VerificationTest[
    InstallMCPServer[ { "ClaudeCode", Symbol[ "xyz" ] } ],
    _Failure,
    { InstallMCPServer::InvalidProjectDirectory },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-InvalidProjectDirectory@@Tests/InstallMCPServer.wlt:634,1-640,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeDevelopmentArgs*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`makeDevelopmentArgs[ DirectoryName[ $TestFileName, 2 ] ],
    { "-script", _String? FileExistsQ, "-noinit", "-noprompt" },
    SameTest -> MatchQ,
    TestID   -> "MakeDevelopmentArgs-ValidPath@@Tests/InstallMCPServer.wlt:645,1-650,2"
]

VerificationTest[
    configFile = testConfigFile[];
    invalidPath = FileNameJoin @ { $TemporaryDirectory, CreateUUID[ "InvalidPath-" ] };
    InstallMCPServer[ configFile, "DevelopmentMode" -> invalidPath, "VerifyLLMKit" -> False ],
    Failure[ "InstallMCPServer::DevelopmentModeUnavailable", _ ],
    { InstallMCPServer::DevelopmentModeUnavailable },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-DevelopmentMode-InvalidPath@@Tests/InstallMCPServer.wlt:652,1-660,2"
]

VerificationTest[
    configFile = testConfigFile[];
    InstallMCPServer[ configFile, "DevelopmentMode" -> InvalidValue, "VerifyLLMKit" -> False ],
    Failure[ "InstallMCPServer::InvalidDevelopmentMode", _ ],
    { InstallMCPServer::InvalidDevelopmentMode },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-DevelopmentMode-InvalidValue@@Tests/InstallMCPServer.wlt:662,1-669,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DevelopmentMode Option*)
VerificationTest[
    MemberQ[ Keys @ Options @ InstallMCPServer, "DevelopmentMode" ],
    True,
    TestID -> "DevelopmentMode-OptionExists@@Tests/InstallMCPServer.wlt:674,1-678,2"
]

VerificationTest[
    configFile = testConfigFile[];
    InstallMCPServer[ configFile, "DevelopmentMode" -> DirectoryName[ $TestFileName, 2 ], "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-DevelopmentMode-Success@@Tests/InstallMCPServer.wlt:680,1-686,2"
]

VerificationTest[
    json = Developer`ReadRawJSONFile @ First @ configFile;
    json[ "mcpServers", "Wolfram", "args" ],
    { "-script", _String, "-noinit", "-noprompt" },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-DevelopmentMode-Args@@Tests/InstallMCPServer.wlt:688,1-694,2"
]

VerificationTest[
    cleanupTestFiles[ configFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-DevelopmentMode-Cleanup@@Tests/InstallMCPServer.wlt:696,1-701,2"
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
    TestID   -> "InstallLocation-Codex-Windows@@Tests/InstallMCPServer.wlt:715,1-720,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Codex", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Codex-MacOSX@@Tests/InstallMCPServer.wlt:722,1-727,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Codex", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Codex-Unix@@Tests/InstallMCPServer.wlt:729,1-734,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "OpenAICodex" ],
    "Codex",
    SameTest -> Equal,
    TestID   -> "ToInstallName-OpenAICodex@@Tests/InstallMCPServer.wlt:739,1-744,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Codex" ],
    "Codex",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Codex@@Tests/InstallMCPServer.wlt:746,1-751,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Codex" ],
    "Codex CLI",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Codex@@Tests/InstallMCPServer.wlt:753,1-758,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TOML Parsing and Writing*)
VerificationTest[
    toml = Wolfram`AgentTools`Common`readTOMLFile @ FileNameJoin @ { $TemporaryDirectory, "nonexistent.toml" };
    toml[ "Data" ],
    <| |>,
    SameTest -> Equal,
    TestID   -> "ReadTOMLFile-NonExistent@@Tests/InstallMCPServer.wlt:763,1-769,2"
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
    TestID   -> "ReadTOMLFile-BasicParsing@@Tests/InstallMCPServer.wlt:771,1-784,2"
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
    TestID   -> "ReadTOMLFile-MCPServerSection@@Tests/InstallMCPServer.wlt:786,1-804,2"
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
    TestID   -> "InstallMCPServer-Codex-Basic@@Tests/InstallMCPServer.wlt:809,1-816,2"
]

VerificationTest[
    FileExistsQ[ codexConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-FileExists@@Tests/InstallMCPServer.wlt:818,1-823,2"
]

VerificationTest[
    Module[ { content, toml },
        content = ReadString @ codexConfigFile;
        toml = Wolfram`AgentTools`Common`readTOMLFile @ codexConfigFile;
        KeyExistsQ[ toml[ "Data", "mcp_servers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-VerifyContent@@Tests/InstallMCPServer.wlt:825,1-834,2"
]

VerificationTest[
    Module[ { content },
        content = ReadString @ codexConfigFile;
        StringContainsQ[ content, "[mcp_servers.Wolfram]" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-VerifySectionFormat@@Tests/InstallMCPServer.wlt:836,1-844,2"
]

VerificationTest[
    (* Use file-based uninstall - TOML format is auto-detected from .toml extension *)
    uninstallResult = UninstallMCPServer[ codexConfigFile, "WolframLanguage" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Codex-Basic@@Tests/InstallMCPServer.wlt:846,1-852,2"
]

VerificationTest[
    Module[ { toml },
        toml = Wolfram`AgentTools`Common`readTOMLFile @ codexConfigFile;
        ! KeyExistsQ[ Lookup[ toml[ "Data" ], "mcp_servers", <| |> ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Codex-VerifyRemoval@@Tests/InstallMCPServer.wlt:854,1-862,2"
]

VerificationTest[
    cleanupTestFiles[ codexConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Codex-Cleanup@@Tests/InstallMCPServer.wlt:864,1-869,2"
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
    TestID   -> "InstallMCPServer-Codex-MultipleServers@@Tests/InstallMCPServer.wlt:874,1-882,2"
]

VerificationTest[
    Module[ { toml, mcpServers },
        toml = Wolfram`AgentTools`Common`readTOMLFile @ codexConfigFile;
        mcpServers = Lookup[ toml[ "Data" ], "mcp_servers", <| |> ];
        KeyExistsQ[ mcpServers, "Wolfram" ] && Length[ Keys @ mcpServers ] === 1
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-VerifyMultipleBuiltInShareKey@@Tests/InstallMCPServer.wlt:884,1-893,2"
]

VerificationTest[
    cleanupTestFiles[ codexConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Codex-MultipleServers-Cleanup@@Tests/InstallMCPServer.wlt:895,1-900,2"
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
    TestID   -> "InstallMCPServer-Codex-PreserveExisting@@Tests/InstallMCPServer.wlt:905,1-917,2"
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
    TestID   -> "InstallMCPServer-Codex-VerifyPreserved@@Tests/InstallMCPServer.wlt:919,1-929,2"
]

VerificationTest[
    cleanupTestFiles[ codexConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Codex-PreserveExisting-Cleanup@@Tests/InstallMCPServer.wlt:931,1-936,2"
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
    TestID   -> "ConvertToCodexFormat-Basic@@Tests/InstallMCPServer.wlt:941,1-955,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`convertToCodexFormat @ <|
        "command" -> "wolfram"
    |>,
    <| "command" -> "wolfram", "enabled" -> True |>,
    SameTest -> Equal,
    TestID   -> "ConvertToCodexFormat-MinimalConfig@@Tests/InstallMCPServer.wlt:957,1-964,2"
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
    TestID   -> "InstallMCPServer-Codex-ProjectInstall@@Tests/InstallMCPServer.wlt:969,1-980,2"
]

VerificationTest[
    FileExistsQ @ codexProjectConfigFile,
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-ProjectConfigExists@@Tests/InstallMCPServer.wlt:982,1-987,2"
]

VerificationTest[
    Module[ { toml },
        toml = Wolfram`AgentTools`Common`readTOMLFile @ codexProjectConfigFile;
        KeyExistsQ[ Lookup[ toml[ "Data" ], "mcp_servers", <| |> ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Codex-ProjectVerifyContent@@Tests/InstallMCPServer.wlt:989,1-997,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ { "Codex", codexProjectDir }, "WolframLanguage" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Codex-ProjectInstall@@Tests/InstallMCPServer.wlt:999,1-1004,2"
]

VerificationTest[
    Module[ { toml },
        toml = Wolfram`AgentTools`Common`readTOMLFile @ codexProjectConfigFile;
        ! KeyExistsQ[ Lookup[ toml[ "Data" ], "mcp_servers", <| |> ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Codex-ProjectVerifyRemoval@@Tests/InstallMCPServer.wlt:1006,1-1014,2"
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
    TestID   -> "InstallMCPServer-Codex-ProjectCleanup@@Tests/InstallMCPServer.wlt:1016,1-1028,2"
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
    TestID   -> "InstallLocation-Goose-Windows@@Tests/InstallMCPServer.wlt:1042,1-1047,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Goose", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Goose-MacOSX@@Tests/InstallMCPServer.wlt:1049,1-1054,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Goose", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Goose-Unix@@Tests/InstallMCPServer.wlt:1056,1-1061,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Display Name*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Goose" ],
    "Goose",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Goose@@Tests/InstallMCPServer.wlt:1066,1-1071,2"
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
    TestID   -> "ConvertToGooseFormat-Basic@@Tests/InstallMCPServer.wlt:1076,1-1092,2"
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
    TestID   -> "ConvertToGooseFormat-MinimalConfig@@Tests/InstallMCPServer.wlt:1094,1-1106,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Goose Install/Uninstall*)
VerificationTest[
    gooseConfigFile = testYAMLFile[ ];
    installResult = InstallMCPServer[ gooseConfigFile, "WolframLanguage", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-Basic@@Tests/InstallMCPServer.wlt:1111,1-1117,2"
]

VerificationTest[
    FileExistsQ @ gooseConfigFile,
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Goose-FileExists@@Tests/InstallMCPServer.wlt:1119,1-1124,2"
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
    TestID   -> "InstallMCPServer-Goose-VerifyContent@@Tests/InstallMCPServer.wlt:1126,1-1136,2"
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
    TestID   -> "InstallMCPServer-Goose-VerifyAllFields@@Tests/InstallMCPServer.wlt:1138,1-1150,2"
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
    TestID   -> "InstallMCPServer-Goose-VerifyFieldValues@@Tests/InstallMCPServer.wlt:1152,1-1164,2"
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
    TestID   -> "InstallMCPServer-Goose-VerifyLiteralYAML@@Tests/InstallMCPServer.wlt:1166,1-1176,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ gooseConfigFile, "WolframLanguage" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Goose-Basic@@Tests/InstallMCPServer.wlt:1178,1-1183,2"
]

VerificationTest[
    Module[ { yaml },
        yaml = Wolfram`AgentTools`Common`importYAML @ gooseConfigFile;
        ! KeyExistsQ[ Lookup[ yaml, "extensions", <| |> ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Goose-VerifyRemoval@@Tests/InstallMCPServer.wlt:1185,1-1193,2"
]

VerificationTest[
    cleanupTestFiles[ gooseConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-Cleanup@@Tests/InstallMCPServer.wlt:1195,1-1200,2"
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
    TestID   -> "InstallMCPServer-Goose-MultipleServers@@Tests/InstallMCPServer.wlt:1205,1-1212,2"
]

VerificationTest[
    Module[ { yaml, extensions },
        yaml = Wolfram`AgentTools`Common`importYAML @ gooseConfigFile;
        extensions = Lookup[ yaml, "extensions", <| |> ];
        KeyExistsQ[ extensions, "Wolfram" ] && Length[ Keys @ extensions ] === 1
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Goose-VerifyMultipleBuiltInShareKey@@Tests/InstallMCPServer.wlt:1214,1-1223,2"
]

VerificationTest[
    cleanupTestFiles[ gooseConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-MultipleServers-Cleanup@@Tests/InstallMCPServer.wlt:1225,1-1230,2"
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
    TestID   -> "InstallMCPServer-Goose-PreserveExisting@@Tests/InstallMCPServer.wlt:1235,1-1249,2"
]

VerificationTest[
    Module[ { yaml, extensions },
        yaml = Wolfram`AgentTools`Common`importYAML @ gooseConfigFile;
        extensions = Lookup[ yaml, "extensions", <| |> ];
        KeyExistsQ[ extensions, "other" ] && KeyExistsQ[ extensions, "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Goose-VerifyPreserved@@Tests/InstallMCPServer.wlt:1251,1-1260,2"
]

VerificationTest[
    cleanupTestFiles[ gooseConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-PreserveExisting-Cleanup@@Tests/InstallMCPServer.wlt:1262,1-1267,2"
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
    TestID   -> "InstallMCPServer-Goose-RefusesUnparseableYAML@@Tests/InstallMCPServer.wlt:1272,1-1285,2"
]

VerificationTest[
    Module[ { content },
        content = ReadString @ First @ gooseConfigFile;
        (* The file must NOT have been overwritten *)
        StringContainsQ[ content, "bad-indent" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Goose-PreservesUnparseableYAML@@Tests/InstallMCPServer.wlt:1287,1-1296,2"
]

VerificationTest[
    cleanupTestFiles[ gooseConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Goose-RefusesUnparseableYAML-Cleanup@@Tests/InstallMCPServer.wlt:1298,1-1303,2"
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
    TestID   -> "UninstallMCPServer-Goose-RefusesUnparseableYAML@@Tests/InstallMCPServer.wlt:1308,1-1320,2"
]

VerificationTest[
    Module[ { content },
        content = ReadString @ First @ gooseConfigFile;
        (* The file must NOT have been overwritten *)
        StringContainsQ[ content, "bad-indent" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Goose-PreservesUnparseableYAML@@Tests/InstallMCPServer.wlt:1322,1-1331,2"
]

VerificationTest[
    cleanupTestFiles[ gooseConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Goose-RefusesUnparseableYAML-Cleanup@@Tests/InstallMCPServer.wlt:1333,1-1338,2"
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
    TestID   -> "InstallMCPServer-Goose-NoProjectSupport@@Tests/InstallMCPServer.wlt:1343,1-1353,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Continue (YAML) Support*)

(* Helper for Continue YAML test files *)
testContinueFile = Function[
    File @ FileNameJoin @ { $TemporaryDirectory, StringJoin[ "continue_test_", CreateUUID[ ], ".yaml" ] }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Location for Continue*)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Continue", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Continue-Windows@@Tests/InstallMCPServer.wlt:1367,1-1372,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Continue", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Continue-MacOSX@@Tests/InstallMCPServer.wlt:1374,1-1379,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Continue", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Continue-Unix@@Tests/InstallMCPServer.wlt:1381,1-1386,2"
]

(* Continue's user-scope path is .continue/config.yaml under $HomeDirectory on every OS *)
VerificationTest[
    Module[ { file, split },
        file = Wolfram`AgentTools`Common`installLocation[ "Continue", $OperatingSystem ];
        split = FileNameSplit @ First @ file;
        Take[ split, -2 ]
    ],
    { ".continue", "config.yaml" },
    SameTest -> Equal,
    TestID   -> "InstallLocation-Continue-PathShape@@Tests/InstallMCPServer.wlt:1389,1-1398,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Continue" ],
    "Continue",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Continue@@Tests/InstallMCPServer.wlt:1403,1-1408,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Continue" ],
    "Continue",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Continue@@Tests/InstallMCPServer.wlt:1410,1-1415,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertToContinueFormat*)

(* Drops "type" key, keeps command/args/env; omits empty args/env *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToContinueFormat @ <|
        "type" -> "stdio",
        "command" -> "wolfram",
        "args" -> { "-run", "test" },
        "env" -> <| "KEY" -> "value" |>
    |>,
    <|
        "command" -> "wolfram",
        "args" -> { "-run", "test" },
        "env" -> <| "KEY" -> "value" |>
    |>,
    SameTest -> Equal,
    TestID   -> "ConvertToContinueFormat-Basic@@Tests/InstallMCPServer.wlt:1422,1-1436,2"
]

(* Empty args and env are omitted *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToContinueFormat @ <|
        "command" -> "wolfram",
        "args" -> { },
        "env" -> <| |>
    |>,
    <| "command" -> "wolfram" |>,
    SameTest -> Equal,
    TestID   -> "ConvertToContinueFormat-OmitsEmpty@@Tests/InstallMCPServer.wlt:1439,1-1448,2"
]

(* Converter does NOT set the "name" field -- the install flow prepends it after conversion *)
VerificationTest[
    KeyExistsQ[
        Wolfram`AgentTools`SupportedClients`Private`convertToContinueFormat @ <| "command" -> "/tmp/wolfram" |>,
        "name"
    ],
    False,
    SameTest -> Equal,
    TestID   -> "ConvertToContinueFormat-NoNameField@@Tests/InstallMCPServer.wlt:1451,1-1459,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readExistingContinueConfig*)

(* Non-existent file returns empty mapping *)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`readExistingContinueConfig @ File @
        FileNameJoin @ { $TemporaryDirectory, "continue_noexist_" <> CreateUUID[] <> ".yaml" },
    <| |>,
    SameTest -> Equal,
    TestID   -> "ReadExistingContinueConfig-NonExistent@@Tests/InstallMCPServer.wlt:1466,1-1472,2"
]

(* Valid YAML with mcpServers array is returned as an Association *)
VerificationTest[
    Module[ { file, result },
        file = File @ FileNameJoin @ { $TemporaryDirectory, "continue_valid_" <> CreateUUID[] <> ".yaml" };
        WithCleanup[
            Wolfram`AgentTools`Common`exportYAML[
                file,
                <| "mcpServers" -> { <| "name" -> "X", "command" -> "y" |> } |>
            ];
            result = Wolfram`AgentTools`InstallMCPServer`Private`readExistingContinueConfig @ file,
            Quiet @ DeleteFile @ First @ file
        ];
        AssociationQ @ result && ListQ @ result[ "mcpServers" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "ReadExistingContinueConfig-ValidYAML@@Tests/InstallMCPServer.wlt:1475,1-1491,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Continue Install and Uninstall (Global Scope)*)
VerificationTest[
    continueConfigFile = testContinueFile[ ];
    installResult = InstallMCPServer[
        continueConfigFile,
        "WolframLanguage",
        "VerifyLLMKit" -> False,
        "ApplicationName" -> "Continue"
    ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Continue-Basic@@Tests/InstallMCPServer.wlt:1496,1-1507,2"
]

VerificationTest[
    FileExistsQ[ continueConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Continue-FileExists@@Tests/InstallMCPServer.wlt:1509,1-1514,2"
]

(* Root is an Association with mcpServers as an array *)
VerificationTest[
    Module[ { content },
        content = Wolfram`AgentTools`Common`importYAML @ continueConfigFile;
        AssociationQ @ content &&
        ListQ @ content[ "mcpServers" ] &&
        Length @ content[ "mcpServers" ] === 1
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Continue-RootShape@@Tests/InstallMCPServer.wlt:1517,1-1527,2"
]

(* The single entry has inline name + command + args + env *)
VerificationTest[
    Module[ { content, entry },
        content = Wolfram`AgentTools`Common`importYAML @ continueConfigFile;
        entry = First @ content[ "mcpServers" ];
        AssociationQ @ entry &&
        entry[ "name" ] === "Wolfram" &&
        StringQ @ entry[ "command" ] &&
        ListQ @ Lookup[ entry, "args", { } ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Continue-EntryShape@@Tests/InstallMCPServer.wlt:1530,1-1542,2"
]

(* Continue REQUIRES name / version / schema at the top of every config.yaml -- including
   the global one. A file missing any of these fails Continue's schema validation and
   is silently ignored. *)
VerificationTest[
    Module[ { content },
        content = Wolfram`AgentTools`Common`importYAML @ continueConfigFile;
        StringQ @ content[ "name" ] &&
        StringQ @ content[ "version" ] &&
        content[ "schema" ] === "v1"
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Continue-Global-RequiredMetadata@@Tests/InstallMCPServer.wlt:1547,1-1557,2"
]

(* Continue uses the standard server fields -- no Cline disabled/autoApprove, no Copilot tools *)
VerificationTest[
    Module[ { content, entry },
        content = Wolfram`AgentTools`Common`importYAML @ continueConfigFile;
        entry = First @ content[ "mcpServers" ];
        ! KeyExistsQ[ entry, "disabled" ] &&
        ! KeyExistsQ[ entry, "autoApprove" ] &&
        ! KeyExistsQ[ entry, "tools" ] &&
        ! KeyExistsQ[ entry, "type" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Continue-StandardFormat@@Tests/InstallMCPServer.wlt:1560,1-1572,2"
]

(* Idempotent re-install: array stays length 1 *)
VerificationTest[
    InstallMCPServer[ continueConfigFile, "WolframLanguage",
        "VerifyLLMKit" -> False, "ApplicationName" -> "Continue" ];
    Module[ { content },
        content = Wolfram`AgentTools`Common`importYAML @ continueConfigFile;
        Length @ Cases[ content[ "mcpServers" ], KeyValuePattern @ { "name" -> "Wolfram" } ]
    ],
    1,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Continue-Idempotent@@Tests/InstallMCPServer.wlt:1575,1-1585,2"
]

(* Second, differently-named server is appended, not replaced *)
VerificationTest[
    InstallMCPServer[ continueConfigFile, "WolframAlpha",
        "VerifyLLMKit" -> False, "ApplicationName" -> "Continue", "MCPServerName" -> "WolframAlphaExtra" ];
    Module[ { content, names },
        content = Wolfram`AgentTools`Common`importYAML @ continueConfigFile;
        names = Sort @ Cases[ content[ "mcpServers" ], KeyValuePattern @ { "name" -> n_String } :> n ];
        names
    ],
    { "Wolfram", "WolframAlphaExtra" },
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Continue-MultiServer@@Tests/InstallMCPServer.wlt:1588,1-1599,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ continueConfigFile, "WolframLanguage", "ApplicationName" -> "Continue" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Continue-Basic@@Tests/InstallMCPServer.wlt:1601,1-1606,2"
]

(* After removing WolframLanguage, only WolframAlphaExtra remains *)
VerificationTest[
    Module[ { content, names },
        content = Wolfram`AgentTools`Common`importYAML @ continueConfigFile;
        names = Cases[ content[ "mcpServers" ], KeyValuePattern @ { "name" -> n_String } :> n ];
        names
    ],
    { "WolframAlphaExtra" },
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Continue-VerifyRemoval@@Tests/InstallMCPServer.wlt:1609,1-1618,2"
]

(* Uninstalling a name that isn't in the array returns NotInstalled *)
VerificationTest[
    UninstallMCPServer[ continueConfigFile, "WolframLanguage", "ApplicationName" -> "Continue" ],
    Missing[ "NotInstalled", _ ],
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Continue-NotInstalled@@Tests/InstallMCPServer.wlt:1621,1-1626,2"
]

VerificationTest[
    cleanupTestFiles[ continueConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Continue-Cleanup@@Tests/InstallMCPServer.wlt:1628,1-1633,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Continue Project-Level Install (Standalone Block File)*)

(* Project-scope writes a standalone block file in .continue/mcpServers/ with required metadata *)
VerificationTest[
    Module[ { dir, projectFile, content, result },
        dir = FileNameJoin @ { $TemporaryDirectory, "continue_proj_" <> CreateUUID[] };
        CreateDirectory @ dir;
        WithCleanup[
            result = InstallMCPServer[
                { "Continue", dir },
                "WolframLanguage",
                "VerifyLLMKit" -> False
            ];
            projectFile = FileNameJoin @ { dir, ".continue", "mcpServers", "wolfram.yaml" };
            content = If[ FileExistsQ @ projectFile,
                Wolfram`AgentTools`Common`importYAML @ File @ projectFile,
                Missing[ ]
            ];
            {
                MatchQ[ result, _Success ],
                FileExistsQ @ projectFile,
                AssociationQ @ content,
                content[ "name" ],
                StringQ @ content[ "version" ],
                content[ "schema" ],
                ListQ @ content[ "mcpServers" ],
                Length @ content[ "mcpServers" ]
            },
            Quiet @ DeleteDirectory[ dir, DeleteContents -> True ]
        ]
    ],
    { True, True, True, "Wolfram", True, "v1", True, 1 },
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Continue-ProjectLevel@@Tests/InstallMCPServer.wlt:1640,1-1671,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Continue Preserves Unrelated Top-Level Keys*)

(* Continue's config.yaml may contain unrelated top-level sections (models:, rules:, etc.)
   and a user-chosen `name`. InstallMCPServer must preserve those -- only the mcpServers
   section may change. The required top-level `version` and `schema` should be added
   if missing, but a pre-existing `name` must not be overwritten. *)
VerificationTest[
    Module[ { file, content },
        file = testContinueFile[ ];
        WithCleanup[
            (* Seed the file with unrelated top-level keys and a user-chosen name *)
            Wolfram`AgentTools`Common`exportYAML[
                file,
                <|
                    "name"   -> "My Continue Config",
                    "models" -> { <| "name" -> "gpt-4", "provider" -> "openai" |> },
                    "rules"  -> { "Be concise." }
                |>
            ];
            InstallMCPServer[ file, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "Continue" ];
            content = Wolfram`AgentTools`Common`importYAML @ file,
            cleanupTestFiles @ file
        ];
        {
            content[ "name" ],
            content[ "models" ],
            content[ "rules" ],
            ListQ @ content[ "mcpServers" ],
            Length @ content[ "mcpServers" ],
            (* Version and schema must be added when missing *)
            StringQ @ content[ "version" ],
            content[ "schema" ]
        }
    ],
    { "My Continue Config", { <| "name" -> "gpt-4", "provider" -> "openai" |> }, { "Be concise." }, True, 1, True, "v1" },
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Continue-PreservesUnrelatedKeys@@Tests/InstallMCPServer.wlt:1681,1-1712,2"
]

(* Fresh global config.yaml (no pre-existing user keys) gets the "Local Config" default
   name rather than the project-scope "Wolfram" name. *)
VerificationTest[
    Module[ { file, content },
        file = testContinueFile[ ];
        WithCleanup[
            InstallMCPServer[ file, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "Continue" ];
            content = Wolfram`AgentTools`Common`importYAML @ file,
            cleanupTestFiles @ file
        ];
        content[ "name" ]
    ],
    "Local Config",
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Continue-Global-DefaultName@@Tests/InstallMCPServer.wlt:1716,1-1729,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Auto-Detection from Path*)

(* File at .continue/config.yaml is auto-detected as Continue when installing without ApplicationName *)
VerificationTest[
    Module[ { dir, file, content },
        dir = FileNameJoin @ { $TemporaryDirectory, "continue_auto_" <> CreateUUID[], ".continue" };
        CreateDirectory[ dir, CreateIntermediateDirectories -> True ];
        file = FileNameJoin @ { dir, "config.yaml" };
        WithCleanup[
            InstallMCPServer[ File @ file, "WolframLanguage", "VerifyLLMKit" -> False ];
            content = Wolfram`AgentTools`Common`importYAML @ File @ file,
            Quiet @ DeleteDirectory[ DirectoryName @ dir, DeleteContents -> True ]
        ];
        AssociationQ @ content && ListQ @ content[ "mcpServers" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "GuessClientName-Continue-GlobalPath@@Tests/InstallMCPServer.wlt:1736,1-1751,2"
]

(* File at .continue/mcpServers/<X>.yaml is auto-detected as Continue *)
VerificationTest[
    Module[ { dir, file, content },
        dir = FileNameJoin @ { $TemporaryDirectory, "continue_auto_proj_" <> CreateUUID[], ".continue", "mcpServers" };
        CreateDirectory[ dir, CreateIntermediateDirectories -> True ];
        file = FileNameJoin @ { dir, "wolfram.yaml" };
        WithCleanup[
            InstallMCPServer[ File @ file, "WolframLanguage", "VerifyLLMKit" -> False ];
            content = Wolfram`AgentTools`Common`importYAML @ File @ file,
            Quiet @ DeleteDirectory[ DirectoryName @ dir, DeleteContents -> True ];
            Quiet @ DeleteDirectory[ DirectoryName[ dir, 2 ] ]
        ];
        AssociationQ @ content &&
        content[ "schema" ] === "v1" &&
        ListQ @ content[ "mcpServers" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "GuessClientName-Continue-ProjectPath@@Tests/InstallMCPServer.wlt:1754,1-1772,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$SupportedMCPClients metadata for Continue*)
VerificationTest[
    $SupportedMCPClients[ "Continue", "DisplayName" ],
    "Continue",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ContinueDisplayName@@Tests/InstallMCPServer.wlt:1777,1-1782,2"
]

VerificationTest[
    $SupportedMCPClients[ "Continue", "ConfigFormat" ],
    "YAML",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ContinueConfigFormat@@Tests/InstallMCPServer.wlt:1784,1-1789,2"
]

VerificationTest[
    $SupportedMCPClients[ "Continue", "ConfigKey" ],
    { "mcpServers" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ContinueConfigKey@@Tests/InstallMCPServer.wlt:1791,1-1796,2"
]

VerificationTest[
    $SupportedMCPClients[ "Continue", "ProjectSupport" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ContinueProjectSupport@@Tests/InstallMCPServer.wlt:1798,1-1803,2"
]

VerificationTest[
    $SupportedMCPClients[ "Continue", "DefaultToolset" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ContinueDefaultToolset@@Tests/InstallMCPServer.wlt:1805,1-1810,2"
]

VerificationTest[
    StringStartsQ[ $SupportedMCPClients[ "Continue", "URL" ], "https://" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ContinueURL@@Tests/InstallMCPServer.wlt:1812,1-1817,2"
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
    TestID   -> "InstallLocation-CopilotCLI-Windows@@Tests/InstallMCPServer.wlt:1826,1-1831,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "CopilotCLI", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-CopilotCLI-MacOSX@@Tests/InstallMCPServer.wlt:1833,1-1838,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "CopilotCLI", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-CopilotCLI-Unix@@Tests/InstallMCPServer.wlt:1840,1-1845,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Copilot" ],
    "CopilotCLI",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Copilot@@Tests/InstallMCPServer.wlt:1850,1-1855,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "CopilotCLI" ],
    "CopilotCLI",
    SameTest -> Equal,
    TestID   -> "ToInstallName-CopilotCLI@@Tests/InstallMCPServer.wlt:1857,1-1862,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "CopilotCLI" ],
    "Copilot CLI",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-CopilotCLI@@Tests/InstallMCPServer.wlt:1864,1-1869,2"
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
    TestID   -> "ConvertToCopilotCLIFormat-Basic@@Tests/InstallMCPServer.wlt:1874,1-1888,2"
]

VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToCopilotCLIFormat @ <|
        "command" -> "wolfram"
    |>,
    <| "command" -> "wolfram", "tools" -> { "*" } |>,
    SameTest -> Equal,
    TestID   -> "ConvertToCopilotCLIFormat-MinimalConfig@@Tests/InstallMCPServer.wlt:1890,1-1897,2"
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
    TestID   -> "InstallLocation-Windsurf-Windows@@Tests/InstallMCPServer.wlt:1906,1-1911,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Windsurf", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Windsurf-MacOSX@@Tests/InstallMCPServer.wlt:1913,1-1918,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Windsurf", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Windsurf-Unix@@Tests/InstallMCPServer.wlt:1920,1-1925,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Codeium" ],
    "Windsurf",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Codeium@@Tests/InstallMCPServer.wlt:1930,1-1935,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Windsurf" ],
    "Windsurf",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Windsurf@@Tests/InstallMCPServer.wlt:1937,1-1942,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Windsurf" ],
    "Windsurf",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Windsurf@@Tests/InstallMCPServer.wlt:1944,1-1949,2"
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
    TestID   -> "InstallLocation-Cline-Windows@@Tests/InstallMCPServer.wlt:1958,1-1963,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Cline", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Cline-MacOSX@@Tests/InstallMCPServer.wlt:1965,1-1970,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Cline", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Cline-Unix@@Tests/InstallMCPServer.wlt:1972,1-1977,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Cline" ],
    "Cline",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Cline@@Tests/InstallMCPServer.wlt:1982,1-1987,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Cline" ],
    "Cline",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Cline@@Tests/InstallMCPServer.wlt:1989,1-1994,2"
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
    TestID   -> "ConvertToClineFormat-Basic@@Tests/InstallMCPServer.wlt:1999,1-2014,2"
]

VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToClineFormat @ <|
        "command" -> "wolfram"
    |>,
    <| "command" -> "wolfram", "disabled" -> False, "autoApprove" -> { } |>,
    SameTest -> Equal,
    TestID   -> "ConvertToClineFormat-MinimalConfig@@Tests/InstallMCPServer.wlt:2016,1-2023,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cline Install and Uninstall*)
VerificationTest[
    clineConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ clineConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "Cline" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Cline-Basic@@Tests/InstallMCPServer.wlt:2028,1-2034,2"
]

VerificationTest[
    FileExistsQ[ clineConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Cline-FileExists@@Tests/InstallMCPServer.wlt:2036,1-2041,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ clineConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Cline-VerifyContent@@Tests/InstallMCPServer.wlt:2043,1-2051,2"
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
    TestID   -> "InstallMCPServer-Cline-VerifyClineFields@@Tests/InstallMCPServer.wlt:2053,1-2063,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ clineConfigFile, "WolframLanguage", "ApplicationName" -> "Cline" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Cline-Basic@@Tests/InstallMCPServer.wlt:2065,1-2070,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ clineConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && ! KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Cline-VerifyRemoval@@Tests/InstallMCPServer.wlt:2072,1-2080,2"
]

VerificationTest[
    cleanupTestFiles[ clineConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Cline-Cleanup@@Tests/InstallMCPServer.wlt:2082,1-2087,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Windsurf Install and Uninstall*)
VerificationTest[
    windsurfConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ windsurfConfigFile, "WolframLanguage", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Windsurf-Basic@@Tests/InstallMCPServer.wlt:2092,1-2098,2"
]

VerificationTest[
    FileExistsQ[ windsurfConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Windsurf-FileExists@@Tests/InstallMCPServer.wlt:2100,1-2105,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ windsurfConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Windsurf-VerifyContent@@Tests/InstallMCPServer.wlt:2107,1-2115,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ windsurfConfigFile, "WolframLanguage" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Windsurf-Basic@@Tests/InstallMCPServer.wlt:2117,1-2122,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ windsurfConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && ! KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Windsurf-VerifyRemoval@@Tests/InstallMCPServer.wlt:2124,1-2132,2"
]

VerificationTest[
    cleanupTestFiles[ windsurfConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Windsurf-Cleanup@@Tests/InstallMCPServer.wlt:2134,1-2139,2"
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
    TestID   -> "InstallLocation-AugmentCode-Windows@@Tests/InstallMCPServer.wlt:2148,1-2153,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AugmentCode", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AugmentCode-MacOSX@@Tests/InstallMCPServer.wlt:2155,1-2160,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AugmentCode", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AugmentCode-Unix@@Tests/InstallMCPServer.wlt:2162,1-2167,2"
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
    TestID   -> "InstallLocation-AugmentCode-PathShape@@Tests/InstallMCPServer.wlt:2170,1-2179,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "AugmentCode" ],
    "AugmentCode",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AugmentCode@@Tests/InstallMCPServer.wlt:2184,1-2189,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Auggie" ],
    "AugmentCode",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Auggie@@Tests/InstallMCPServer.wlt:2191,1-2196,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Augment" ],
    "AugmentCode",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Augment@@Tests/InstallMCPServer.wlt:2198,1-2203,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "AugmentCode" ],
    "Augment Code",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-AugmentCode@@Tests/InstallMCPServer.wlt:2205,1-2210,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AugmentCode Install and Uninstall*)
VerificationTest[
    augmentConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ augmentConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "AugmentCode" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AugmentCode-Basic@@Tests/InstallMCPServer.wlt:2215,1-2221,2"
]

VerificationTest[
    FileExistsQ[ augmentConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AugmentCode-FileExists@@Tests/InstallMCPServer.wlt:2223,1-2228,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ augmentConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AugmentCode-VerifyContent@@Tests/InstallMCPServer.wlt:2230,1-2238,2"
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
    TestID   -> "InstallMCPServer-AugmentCode-StandardFormat@@Tests/InstallMCPServer.wlt:2242,1-2254,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ augmentConfigFile, "WolframLanguage", "ApplicationName" -> "AugmentCode" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-AugmentCode-Basic@@Tests/InstallMCPServer.wlt:2256,1-2261,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ augmentConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && ! KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-AugmentCode-VerifyRemoval@@Tests/InstallMCPServer.wlt:2263,1-2271,2"
]

VerificationTest[
    cleanupTestFiles[ augmentConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AugmentCode-Cleanup@@Tests/InstallMCPServer.wlt:2273,1-2278,2"
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
    TestID   -> "ConvertToAugmentCodeFormat-NonWindows@@Tests/InstallMCPServer.wlt:2285,1-2301,2"
]

(* Non-Windows with a space-containing command: still unchanged *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeFormat[
        <| "command" -> "/Applications/Wolfram Desktop.app/Contents/MacOS/wolfram" |>,
        "MacOSX"
    ],
    <| "command" -> "/Applications/Wolfram Desktop.app/Contents/MacOS/wolfram" |>,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeFormat-NonWindows-WithSpaces@@Tests/InstallMCPServer.wlt:2304,1-2312,2"
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
    TestID   -> "ConvertToAugmentCodeFormat-Windows-NoSpaces@@Tests/InstallMCPServer.wlt:2315,1-2329,2"
]

(* Missing command: converter should not error *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeFormat[
        <| "args" -> { "-run", "test" } |>,
        "Windows"
    ],
    <| "args" -> { "-run", "test" } |>,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeFormat-MissingCommand@@Tests/InstallMCPServer.wlt:2332,1-2340,2"
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
    TestID   -> "ConvertToAugmentCodeFormat-Windows-NonExistentPath@@Tests/InstallMCPServer.wlt:2344,1-2352,2"
]

(* 1-arg form dispatches to 2-arg form using $OperatingSystem *)
VerificationTest[
    Wolfram`AgentTools`SupportedClients`Private`convertToAugmentCodeFormat @ <|
        "command" -> "/no/spaces/here"
    |>,
    <| "command" -> "/no/spaces/here" |>,
    SameTest -> Equal,
    TestID   -> "ConvertToAugmentCodeFormat-OneArgForm@@Tests/InstallMCPServer.wlt:2355,1-2362,2"
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
    TestID   -> "InstallLocation-AugmentCodeIDE-Windows@@Tests/InstallMCPServer.wlt:2371,1-2376,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AugmentCodeIDE", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AugmentCodeIDE-MacOSX@@Tests/InstallMCPServer.wlt:2378,1-2383,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AugmentCodeIDE", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AugmentCodeIDE-Unix@@Tests/InstallMCPServer.wlt:2385,1-2390,2"
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
    TestID   -> "InstallLocation-AugmentCodeIDE-PathShape@@Tests/InstallMCPServer.wlt:2393,1-2402,2"
]

(* Install locations for AugmentCode (CLI) and AugmentCodeIDE must differ *)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AugmentCode", $OperatingSystem ] =!=
        Wolfram`AgentTools`Common`installLocation[ "AugmentCodeIDE", $OperatingSystem ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallLocation-AugmentCode-vs-AugmentCodeIDE-Distinct@@Tests/InstallMCPServer.wlt:2405,1-2411,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "AugmentCodeIDE" ],
    "AugmentCodeIDE",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AugmentCodeIDE@@Tests/InstallMCPServer.wlt:2416,1-2421,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "AugmentIDE" ],
    "AugmentCodeIDE",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AugmentIDE@@Tests/InstallMCPServer.wlt:2423,1-2428,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "AuggieIDE" ],
    "AugmentCodeIDE",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AuggieIDE@@Tests/InstallMCPServer.wlt:2430,1-2435,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "AugmentCodeIDE" ],
    "Augment Code IDE",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-AugmentCodeIDE@@Tests/InstallMCPServer.wlt:2437,1-2442,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AugmentCodeIDE Install and Uninstall*)
VerificationTest[
    augmentIDEConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ augmentIDEConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "AugmentCodeIDE" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AugmentCodeIDE-Basic@@Tests/InstallMCPServer.wlt:2447,1-2453,2"
]

VerificationTest[
    FileExistsQ[ augmentIDEConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AugmentCodeIDE-FileExists@@Tests/InstallMCPServer.wlt:2455,1-2460,2"
]

(* The file root is a JSON array, not an object *)
VerificationTest[
    Module[ { content },
        content = Import[ augmentIDEConfigFile, "RawJSON" ];
        ListQ @ content
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AugmentCodeIDE-RootIsArray@@Tests/InstallMCPServer.wlt:2463,1-2471,2"
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
    TestID   -> "InstallMCPServer-AugmentCodeIDE-EntryShape@@Tests/InstallMCPServer.wlt:2474,1-2486,2"
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
    TestID   -> "InstallMCPServer-AugmentCodeIDE-Idempotent@@Tests/InstallMCPServer.wlt:2489,1-2499,2"
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
    TestID   -> "InstallMCPServer-AugmentCodeIDE-MultiServer@@Tests/InstallMCPServer.wlt:2502,1-2512,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ augmentIDEConfigFile, "WolframLanguage", "ApplicationName" -> "AugmentCodeIDE" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-AugmentCodeIDE-Basic@@Tests/InstallMCPServer.wlt:2514,1-2519,2"
]

VerificationTest[
    Module[ { content, matches },
        content = Import[ augmentIDEConfigFile, "RawJSON" ];
        matches = Select[ content, MatchQ[ #, KeyValuePattern @ { "name" -> "Wolfram" } ] & ];
        Length @ matches
    ],
    0,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-AugmentCodeIDE-VerifyRemoval@@Tests/InstallMCPServer.wlt:2521,1-2530,2"
]

(* Uninstalling the other entry as well leaves an empty array, not a removed file *)
VerificationTest[
    UninstallMCPServer[ augmentIDEConfigFile, "WolframAlpha", "ApplicationName" -> "AugmentCodeIDE", "MCPServerName" -> "WolframAlphaExtra" ];
    Import[ augmentIDEConfigFile, "RawJSON" ],
    { },
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-AugmentCodeIDE-EmptiesToArray@@Tests/InstallMCPServer.wlt:2533,1-2539,2"
]

(* Uninstalling a server that isn't installed returns NotInstalled, not an error *)
VerificationTest[
    UninstallMCPServer[ augmentIDEConfigFile, "WolframLanguage", "ApplicationName" -> "AugmentCodeIDE" ],
    Missing[ "NotInstalled", _ ],
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-AugmentCodeIDE-NotInstalled@@Tests/InstallMCPServer.wlt:2542,1-2547,2"
]

VerificationTest[
    cleanupTestFiles[ augmentIDEConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AugmentCodeIDE-Cleanup@@Tests/InstallMCPServer.wlt:2549,1-2554,2"
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
    TestID   -> "ConvertToAugmentCodeIDEFormat-Basic@@Tests/InstallMCPServer.wlt:2561,1-2578,2"
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
    TestID   -> "ConvertToAugmentCodeIDEFormat-NonWindows-WithSpaces@@Tests/InstallMCPServer.wlt:2581,1-2592,2"
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
    TestID   -> "ConvertToAugmentCodeIDEFormat-Windows-NoSpaces@@Tests/InstallMCPServer.wlt:2595,1-2607,2"
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
    TestID   -> "ConvertToAugmentCodeIDEFormat-MissingCommand@@Tests/InstallMCPServer.wlt:2610,1-2621,2"
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
    TestID   -> "ConvertToAugmentCodeIDEFormat-NoNameField@@Tests/InstallMCPServer.wlt:2624,1-2635,2"
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
    TestID   -> "ReadExistingAugmentCodeIDEConfig-NonExistent@@Tests/InstallMCPServer.wlt:2642,1-2648,2"
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
    TestID   -> "ReadExistingAugmentCodeIDEConfig-EmptyFile@@Tests/InstallMCPServer.wlt:2651,1-2663,2"
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
    TestID   -> "ReadExistingAugmentCodeIDEConfig-ValidArray@@Tests/InstallMCPServer.wlt:2666,1-2679,2"
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
    TestID   -> "ReadExistingAugmentCodeIDEConfig-NonListRoot@@Tests/InstallMCPServer.wlt:2684,1-2697,2"
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
    TestID   -> "GuessClientName-AugmentCodeIDE-PathMatch@@Tests/InstallMCPServer.wlt:2706,1-2724,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$SupportedMCPClients metadata for AugmentCodeIDE*)
VerificationTest[
    $SupportedMCPClients[ "AugmentCodeIDE", "DisplayName" ],
    "Augment Code IDE",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeIDEDisplayName@@Tests/InstallMCPServer.wlt:2729,1-2734,2"
]

VerificationTest[
    Sort @ $SupportedMCPClients[ "AugmentCodeIDE", "Aliases" ],
    Sort @ { "AugmentIDE", "AuggieIDE" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeIDEAliases@@Tests/InstallMCPServer.wlt:2736,1-2741,2"
]

VerificationTest[
    $SupportedMCPClients[ "AugmentCodeIDE", "ConfigFormat" ],
    "JSON",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeIDEConfigFormat@@Tests/InstallMCPServer.wlt:2743,1-2748,2"
]

(* Empty ConfigKey signals the root of the file is an array, not a keyed object *)
VerificationTest[
    $SupportedMCPClients[ "AugmentCodeIDE", "ConfigKey" ],
    { },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeIDEConfigKey@@Tests/InstallMCPServer.wlt:2751,1-2756,2"
]

VerificationTest[
    $SupportedMCPClients[ "AugmentCodeIDE", "ProjectSupport" ],
    False,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeIDEProjectSupport@@Tests/InstallMCPServer.wlt:2758,1-2763,2"
]

VerificationTest[
    StringStartsQ[ $SupportedMCPClients[ "AugmentCodeIDE", "URL" ], "https://" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeIDEURL@@Tests/InstallMCPServer.wlt:2765,1-2770,2"
]

(* AugmentCode (CLI) and AugmentCodeIDE (VS Code) must be distinct entries with distinct display names *)
VerificationTest[
    $SupportedMCPClients[ "AugmentCode", "DisplayName" ] =!=
        $SupportedMCPClients[ "AugmentCodeIDE", "DisplayName" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCode-vs-AugmentCodeIDE-Distinct@@Tests/InstallMCPServer.wlt:2773,1-2779,2"
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
    TestID   -> "ToWindowsShortPath-NonExistent@@Tests/InstallMCPServer.wlt:2786,1-2793,2"
]

(* Space-free existing path on Windows: result equals the input (no short form needed).
   On non-Windows, the file probably exists and the function still returns a string. *)
VerificationTest[
    With[ { result = Wolfram`AgentTools`SupportedClients`Private`toWindowsShortPath @ $TemporaryDirectory },
        StringQ @ result
    ],
    True,
    SameTest -> Equal,
    TestID   -> "ToWindowsShortPath-ReturnsString@@Tests/InstallMCPServer.wlt:2797,1-2804,2"
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
        TestID   -> "ToWindowsShortPath-WolframExe@@Tests/InstallMCPServer.wlt:2809,5-2819,6"
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$SupportedMCPClients metadata for AugmentCode*)
VerificationTest[
    $SupportedMCPClients[ "AugmentCode", "DisplayName" ],
    "Augment Code",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeDisplayName@@Tests/InstallMCPServer.wlt:2825,1-2830,2"
]

VerificationTest[
    Sort @ $SupportedMCPClients[ "AugmentCode", "Aliases" ],
    Sort @ { "Auggie", "Augment" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeAliases@@Tests/InstallMCPServer.wlt:2832,1-2837,2"
]

VerificationTest[
    $SupportedMCPClients[ "AugmentCode", "ConfigFormat" ],
    "JSON",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeConfigFormat@@Tests/InstallMCPServer.wlt:2839,1-2844,2"
]

VerificationTest[
    $SupportedMCPClients[ "AugmentCode", "ConfigKey" ],
    { "mcpServers" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeConfigKey@@Tests/InstallMCPServer.wlt:2846,1-2851,2"
]

VerificationTest[
    $SupportedMCPClients[ "AugmentCode", "ProjectSupport" ],
    False,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeProjectSupport@@Tests/InstallMCPServer.wlt:2853,1-2858,2"
]

VerificationTest[
    StringStartsQ[ $SupportedMCPClients[ "AugmentCode", "URL" ], "https://" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AugmentCodeURL@@Tests/InstallMCPServer.wlt:2860,1-2865,2"
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
    TestID   -> "InstallLocation-Zed-Windows@@Tests/InstallMCPServer.wlt:2874,1-2879,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Zed", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Zed-MacOSX@@Tests/InstallMCPServer.wlt:2881,1-2886,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Zed", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Zed-Unix@@Tests/InstallMCPServer.wlt:2888,1-2893,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Zed" ],
    "Zed",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Zed@@Tests/InstallMCPServer.wlt:2898,1-2903,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Zed" ],
    "Zed",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Zed@@Tests/InstallMCPServer.wlt:2905,1-2910,2"
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
    TestID   -> "ProjectInstallLocation-Zed@@Tests/InstallMCPServer.wlt:2915,1-2924,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Zed Install and Uninstall*)
VerificationTest[
    zedConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ zedConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "Zed" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Zed-Basic@@Tests/InstallMCPServer.wlt:2929,1-2935,2"
]

VerificationTest[
    FileExistsQ[ zedConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Zed-FileExists@@Tests/InstallMCPServer.wlt:2937,1-2942,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ zedConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "context_servers" ] && KeyExistsQ[ content[ "context_servers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Zed-VerifyContent@@Tests/InstallMCPServer.wlt:2944,1-2952,2"
]

VerificationTest[
    Module[ { content, server },
        content = Import[ zedConfigFile, "RawJSON" ];
        server = content[ "context_servers", "Wolfram" ];
        KeyExistsQ[ server, "command" ] && KeyExistsQ[ server, "args" ] && KeyExistsQ[ server, "env" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Zed-VerifyServerFields@@Tests/InstallMCPServer.wlt:2954,1-2963,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ zedConfigFile, "WolframLanguage", "ApplicationName" -> "Zed" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Zed-Basic@@Tests/InstallMCPServer.wlt:2965,1-2970,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ zedConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "context_servers" ] && ! KeyExistsQ[ content[ "context_servers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Zed-VerifyRemoval@@Tests/InstallMCPServer.wlt:2972,1-2980,2"
]

VerificationTest[
    cleanupTestFiles[ zedConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Zed-Cleanup@@Tests/InstallMCPServer.wlt:2982,1-2987,2"
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
    TestID   -> "InstallMCPServer-Zed-PreserveExisting@@Tests/InstallMCPServer.wlt:2992,1-2999,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ zedConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "theme" ] && content[ "theme" ] === "One Dark" &&
        KeyExistsQ[ content[ "context_servers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Zed-VerifyPreserved@@Tests/InstallMCPServer.wlt:3001,1-3010,2"
]

VerificationTest[
    cleanupTestFiles[ zedConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Zed-PreserveExisting-Cleanup@@Tests/InstallMCPServer.wlt:3012,1-3017,2"
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
    TestID   -> "InstallLocation-Junie-Windows@@Tests/InstallMCPServer.wlt:3026,1-3031,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Junie", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Junie-MacOSX@@Tests/InstallMCPServer.wlt:3033,1-3038,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Junie", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Junie-Unix@@Tests/InstallMCPServer.wlt:3040,1-3045,2"
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
    TestID   -> "InstallLocation-Junie-PathShape@@Tests/InstallMCPServer.wlt:3048,1-3057,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Junie" ],
    "Junie",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Junie@@Tests/InstallMCPServer.wlt:3062,1-3067,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "JetBrainsJunie" ],
    "Junie",
    SameTest -> Equal,
    TestID   -> "ToInstallName-JetBrainsJunie@@Tests/InstallMCPServer.wlt:3069,1-3074,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Junie" ],
    "Junie",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Junie@@Tests/InstallMCPServer.wlt:3076,1-3081,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Junie Install and Uninstall*)
VerificationTest[
    junieConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ junieConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "Junie" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Junie-Basic@@Tests/InstallMCPServer.wlt:3086,1-3092,2"
]

VerificationTest[
    FileExistsQ[ junieConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Junie-FileExists@@Tests/InstallMCPServer.wlt:3094,1-3099,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ junieConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Junie-VerifyContent@@Tests/InstallMCPServer.wlt:3101,1-3109,2"
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
    TestID   -> "InstallMCPServer-Junie-StandardFormat@@Tests/InstallMCPServer.wlt:3113,1-3126,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ junieConfigFile, "WolframLanguage", "ApplicationName" -> "Junie" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Junie-Basic@@Tests/InstallMCPServer.wlt:3128,1-3133,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ junieConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && ! KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Junie-VerifyRemoval@@Tests/InstallMCPServer.wlt:3135,1-3143,2"
]

VerificationTest[
    cleanupTestFiles[ junieConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Junie-Cleanup@@Tests/InstallMCPServer.wlt:3145,1-3150,2"
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
    TestID   -> "InstallMCPServer-Junie-ProjectLevel@@Tests/InstallMCPServer.wlt:3155,1-3169,2"
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
    TestID   -> "GuessClientName-Junie-PathMatch@@Tests/InstallMCPServer.wlt:3177,1-3193,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$SupportedMCPClients metadata for Junie*)
VerificationTest[
    $SupportedMCPClients[ "Junie", "DisplayName" ],
    "Junie",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieDisplayName@@Tests/InstallMCPServer.wlt:3198,1-3203,2"
]

VerificationTest[
    $SupportedMCPClients[ "Junie", "Aliases" ],
    { "JetBrainsJunie" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieAliases@@Tests/InstallMCPServer.wlt:3205,1-3210,2"
]

VerificationTest[
    $SupportedMCPClients[ "Junie", "ConfigFormat" ],
    "JSON",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieConfigFormat@@Tests/InstallMCPServer.wlt:3212,1-3217,2"
]

VerificationTest[
    $SupportedMCPClients[ "Junie", "ConfigKey" ],
    { "mcpServers" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieConfigKey@@Tests/InstallMCPServer.wlt:3219,1-3224,2"
]

VerificationTest[
    $SupportedMCPClients[ "Junie", "ProjectSupport" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieProjectSupport@@Tests/InstallMCPServer.wlt:3226,1-3231,2"
]

VerificationTest[
    StringStartsQ[ $SupportedMCPClients[ "Junie", "URL" ], "https://" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieURL@@Tests/InstallMCPServer.wlt:3233,1-3238,2"
]

(* Junie is a coding agent - default toolset is WolframLanguage (matches Cursor, ClaudeCode, etc.) *)
VerificationTest[
    $SupportedMCPClients[ "Junie", "DefaultToolset" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-JunieDefaultToolset@@Tests/InstallMCPServer.wlt:3241,1-3246,2"
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
    TestID   -> "InstallLocation-Kiro-Windows@@Tests/InstallMCPServer.wlt:3256,1-3261,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Kiro", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Kiro-MacOSX@@Tests/InstallMCPServer.wlt:3263,1-3268,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "Kiro", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-Kiro-Unix@@Tests/InstallMCPServer.wlt:3270,1-3275,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "Kiro" ],
    "Kiro",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-Kiro@@Tests/InstallMCPServer.wlt:3277,1-3282,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Kiro" ],
    "Kiro",
    SameTest -> Equal,
    TestID   -> "ToInstallName-Kiro@@Tests/InstallMCPServer.wlt:3284,1-3289,2"
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
    TestID   -> "ProjectInstallLocation-Kiro@@Tests/InstallMCPServer.wlt:3294,1-3303,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Kiro Install and Uninstall*)
VerificationTest[
    kiroConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ kiroConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "Kiro" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Kiro-Basic@@Tests/InstallMCPServer.wlt:3308,1-3314,2"
]

VerificationTest[
    FileExistsQ[ kiroConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Kiro-FileExists@@Tests/InstallMCPServer.wlt:3316,1-3321,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ kiroConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Kiro-VerifyContent@@Tests/InstallMCPServer.wlt:3323,1-3331,2"
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
    TestID   -> "InstallMCPServer-Kiro-VerifyKiroFields@@Tests/InstallMCPServer.wlt:3333,1-3343,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ kiroConfigFile, "WolframLanguage", "ApplicationName" -> "Kiro" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Kiro-Basic@@Tests/InstallMCPServer.wlt:3345,1-3350,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ kiroConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && ! KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Kiro-VerifyRemoval@@Tests/InstallMCPServer.wlt:3352,1-3360,2"
]

VerificationTest[
    cleanupTestFiles[ kiroConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Kiro-Cleanup@@Tests/InstallMCPServer.wlt:3362,1-3367,2"
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
    TestID   -> "InstallMCPServer-Kiro-PreserveExisting@@Tests/InstallMCPServer.wlt:3372,1-3379,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ kiroConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "customSetting" ] && content[ "customSetting" ] === True &&
        KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-Kiro-VerifyPreserved@@Tests/InstallMCPServer.wlt:3381,1-3390,2"
]

VerificationTest[
    cleanupTestFiles[ kiroConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-Kiro-PreserveExisting-Cleanup@@Tests/InstallMCPServer.wlt:3392,1-3397,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*LM Studio Support*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install Location for LM Studio*)
VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "LMStudio", "Windows" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-LMStudio-Windows@@Tests/InstallMCPServer.wlt:3406,1-3411,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "LMStudio", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-LMStudio-MacOSX@@Tests/InstallMCPServer.wlt:3413,1-3418,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "LMStudio", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-LMStudio-Unix@@Tests/InstallMCPServer.wlt:3420,1-3425,2"
]

(* LM Studio's path is .lmstudio/mcp.json under $HomeDirectory on every OS *)
VerificationTest[
    Module[ { file, split },
        file = Wolfram`AgentTools`Common`installLocation[ "LMStudio", $OperatingSystem ];
        split = FileNameSplit @ First @ file;
        Take[ split, -2 ]
    ],
    { ".lmstudio", "mcp.json" },
    SameTest -> Equal,
    TestID   -> "InstallLocation-LMStudio-PathShape@@Tests/InstallMCPServer.wlt:3428,1-3437,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Name Normalization*)
VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "LMStudio" ],
    "LMStudio",
    SameTest -> Equal,
    TestID   -> "ToInstallName-LMStudio@@Tests/InstallMCPServer.wlt:3442,1-3447,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "LMStudio" ],
    "LM Studio",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-LMStudio@@Tests/InstallMCPServer.wlt:3449,1-3454,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LM Studio Install and Uninstall*)
VerificationTest[
    lmStudioConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ lmStudioConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "LMStudio" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-LMStudio-Basic@@Tests/InstallMCPServer.wlt:3459,1-3465,2"
]

VerificationTest[
    FileExistsQ[ lmStudioConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-LMStudio-FileExists@@Tests/InstallMCPServer.wlt:3467,1-3472,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ lmStudioConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-LMStudio-VerifyContent@@Tests/InstallMCPServer.wlt:3474,1-3482,2"
]

(* LM Studio uses the standard mcpServers format (Cursor notation): no Cline-style
   disabled/autoApprove fields, no Copilot-style tools field, no OpenCode-style top-level "mcp" key *)
VerificationTest[
    Module[ { content, server },
        content = Import[ lmStudioConfigFile, "RawJSON" ];
        server = content[ "mcpServers", "Wolfram" ];
        AssociationQ @ server &&
        KeyExistsQ[ server, "command" ] &&
        ! KeyExistsQ[ server, "disabled" ] &&
        ! KeyExistsQ[ server, "autoApprove" ] &&
        ! KeyExistsQ[ server, "tools" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-LMStudio-StandardFormat@@Tests/InstallMCPServer.wlt:3486,1-3499,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ lmStudioConfigFile, "WolframLanguage", "ApplicationName" -> "LMStudio" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-LMStudio-Basic@@Tests/InstallMCPServer.wlt:3501,1-3506,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ lmStudioConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && ! KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-LMStudio-VerifyRemoval@@Tests/InstallMCPServer.wlt:3508,1-3516,2"
]

VerificationTest[
    cleanupTestFiles[ lmStudioConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-LMStudio-Cleanup@@Tests/InstallMCPServer.wlt:3518,1-3523,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LM Studio Preserves Existing Config*)

(* The mcp.json may contain other servers and unrelated keys; install must preserve them *)
VerificationTest[
    lmStudioPreserveFile = testConfigFile[];
    Export[ lmStudioPreserveFile, <| "mcpServers" -> <| "ExistingServer" -> <| "command" -> "foo" |> |> |>, "JSON" ];
    InstallMCPServer[ lmStudioPreserveFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "LMStudio" ];
    Module[ { content },
        content = Import[ lmStudioPreserveFile, "RawJSON" ];
        KeyExistsQ[ content[ "mcpServers" ], "ExistingServer" ] &&
        KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-LMStudio-PreserveExisting@@Tests/InstallMCPServer.wlt:3530,1-3542,2"
]

VerificationTest[
    cleanupTestFiles[ lmStudioPreserveFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-LMStudio-PreserveExisting-Cleanup@@Tests/InstallMCPServer.wlt:3544,1-3549,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Auto-Detection from Path*)

(* File at .lmstudio/mcp.json is auto-detected as LMStudio when installing without ApplicationName *)
VerificationTest[
    Module[ { dir, file, content },
        dir = FileNameJoin @ { $TemporaryDirectory, "lmstudio_auto_" <> CreateUUID[], ".lmstudio" };
        CreateDirectory[ dir, CreateIntermediateDirectories -> True ];
        file = FileNameJoin @ { dir, "mcp.json" };
        WithCleanup[
            InstallMCPServer[ File @ file, "WolframLanguage", "VerifyLLMKit" -> False ];
            content = Import[ file, "RawJSON" ],
            Quiet @ DeleteDirectory[ DirectoryName @ dir, DeleteContents -> True ]
        ];
        AssociationQ @ content && KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "GuessClientName-LMStudio-PathMatch@@Tests/InstallMCPServer.wlt:3556,1-3571,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$SupportedMCPClients metadata for LM Studio*)
VerificationTest[
    $SupportedMCPClients[ "LMStudio", "DisplayName" ],
    "LM Studio",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-LMStudioDisplayName@@Tests/InstallMCPServer.wlt:3576,1-3581,2"
]

VerificationTest[
    $SupportedMCPClients[ "LMStudio", "ConfigFormat" ],
    "JSON",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-LMStudioConfigFormat@@Tests/InstallMCPServer.wlt:3583,1-3588,2"
]

VerificationTest[
    $SupportedMCPClients[ "LMStudio", "ConfigKey" ],
    { "mcpServers" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-LMStudioConfigKey@@Tests/InstallMCPServer.wlt:3590,1-3595,2"
]

VerificationTest[
    $SupportedMCPClients[ "LMStudio", "ProjectSupport" ],
    False,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-LMStudioProjectSupport@@Tests/InstallMCPServer.wlt:3597,1-3602,2"
]

(* LM Studio is a chat-first client, so its default toolset is "Wolfram" (like Claude Desktop / Goose) *)
VerificationTest[
    $SupportedMCPClients[ "LMStudio", "DefaultToolset" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-LMStudioDefaultToolset@@Tests/InstallMCPServer.wlt:3605,1-3610,2"
]

VerificationTest[
    StringStartsQ[ $SupportedMCPClients[ "LMStudio", "URL" ], "https://" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-LMStudioURL@@Tests/InstallMCPServer.wlt:3612,1-3617,2"
]

(* Confirm the chat-client default flows through defaultToolsetForTarget *)
VerificationTest[
    Wolfram`AgentTools`Common`defaultToolsetForTarget[ "LMStudio" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-LMStudio@@Tests/InstallMCPServer.wlt:3620,1-3625,2"
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
    TestID   -> "InstallLocation-AmazonQ-Windows@@Tests/InstallMCPServer.wlt:3635,1-3640,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AmazonQ", "MacOSX" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AmazonQ-MacOSX@@Tests/InstallMCPServer.wlt:3642,1-3647,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`installLocation[ "AmazonQ", "Unix" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-AmazonQ-Unix@@Tests/InstallMCPServer.wlt:3649,1-3654,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`installDisplayName[ "AmazonQ" ],
    "Amazon Q Developer",
    SameTest -> Equal,
    TestID   -> "InstallDisplayName-AmazonQ@@Tests/InstallMCPServer.wlt:3656,1-3661,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "AmazonQ" ],
    "AmazonQ",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AmazonQ@@Tests/InstallMCPServer.wlt:3663,1-3668,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "AmazonQDeveloper" ],
    "AmazonQ",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AmazonQ-Alias-AmazonQDeveloper@@Tests/InstallMCPServer.wlt:3670,1-3675,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "Q" ],
    "AmazonQ",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AmazonQ-Alias-Q@@Tests/InstallMCPServer.wlt:3677,1-3682,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toInstallName[ "QDeveloper" ],
    "AmazonQ",
    SameTest -> Equal,
    TestID   -> "ToInstallName-AmazonQ-Alias-QDeveloper@@Tests/InstallMCPServer.wlt:3684,1-3689,2"
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
    TestID   -> "ProjectInstallLocation-AmazonQ@@Tests/InstallMCPServer.wlt:3694,1-3703,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Amazon Q Install and Uninstall*)
VerificationTest[
    amazonQConfigFile = testConfigFile[];
    installResult = InstallMCPServer[ amazonQConfigFile, "WolframLanguage", "VerifyLLMKit" -> False, "ApplicationName" -> "AmazonQ" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AmazonQ-Basic@@Tests/InstallMCPServer.wlt:3708,1-3714,2"
]

VerificationTest[
    FileExistsQ[ amazonQConfigFile ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AmazonQ-FileExists@@Tests/InstallMCPServer.wlt:3716,1-3721,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ amazonQConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AmazonQ-VerifyContent@@Tests/InstallMCPServer.wlt:3723,1-3731,2"
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
    TestID   -> "InstallMCPServer-AmazonQ-VerifyFields@@Tests/InstallMCPServer.wlt:3733,1-3744,2"
]

VerificationTest[
    uninstallResult = UninstallMCPServer[ amazonQConfigFile, "WolframLanguage", "ApplicationName" -> "AmazonQ" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-AmazonQ-Basic@@Tests/InstallMCPServer.wlt:3746,1-3751,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ amazonQConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "mcpServers" ] && ! KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-AmazonQ-VerifyRemoval@@Tests/InstallMCPServer.wlt:3753,1-3761,2"
]

VerificationTest[
    cleanupTestFiles[ amazonQConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AmazonQ-Cleanup@@Tests/InstallMCPServer.wlt:3763,1-3768,2"
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
    TestID   -> "InstallMCPServer-AmazonQ-PreserveExisting@@Tests/InstallMCPServer.wlt:3773,1-3780,2"
]

VerificationTest[
    Module[ { content },
        content = Import[ amazonQConfigFile, "RawJSON" ];
        KeyExistsQ[ content, "customSetting" ] && content[ "customSetting" ] === True &&
        KeyExistsQ[ content[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallMCPServer-AmazonQ-VerifyPreserved@@Tests/InstallMCPServer.wlt:3782,1-3791,2"
]

VerificationTest[
    cleanupTestFiles[ amazonQConfigFile ],
    { Null },
    SameTest -> MatchQ,
    TestID   -> "InstallMCPServer-AmazonQ-PreserveExisting-Cleanup@@Tests/InstallMCPServer.wlt:3793,1-3798,2"
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
    TestID   -> "InstallMCPServer-AmazonQ-AutoDetect-Project@@Tests/InstallMCPServer.wlt:3803,1-3814,2"
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
    TestID   -> "InstallMCPServer-AmazonQ-AutoDetect-Global@@Tests/InstallMCPServer.wlt:3816,1-3827,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$SupportedMCPClients*)
VerificationTest[
    $SupportedMCPClients,
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "SupportedMCPClients-ReturnsAssociation@@Tests/InstallMCPServer.wlt:3832,1-3837,2"
]

VerificationTest[
    Length @ $SupportedMCPClients,
    20,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-Has20Clients@@Tests/InstallMCPServer.wlt:3839,1-3844,2"
]

VerificationTest[
    Keys @ $SupportedMCPClients,
    { "AmazonQ", "Antigravity", "AugmentCode", "AugmentCodeIDE", "ClaudeCode", "ClaudeDesktop", "Cline", "Codex", "Continue", "CopilotCLI", "Cursor", "GeminiCLI", "Goose", "Junie", "Kiro", "LMStudio", "OpenCode", "VisualStudioCode", "Windsurf", "Zed" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-KeysSorted@@Tests/InstallMCPServer.wlt:3846,1-3851,2"
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
    TestID   -> "SupportedMCPClients-AllHaveRequiredKeys@@Tests/InstallMCPServer.wlt:3853,1-3870,2"
]

VerificationTest[
    $SupportedMCPClients[ "ClaudeDesktop", "DisplayName" ],
    "Claude Desktop",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ClaudeDesktopDisplayName@@Tests/InstallMCPServer.wlt:3872,1-3877,2"
]

VerificationTest[
    $SupportedMCPClients[ "ClaudeDesktop", "Aliases" ],
    { "Claude" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ClaudeDesktopAliases@@Tests/InstallMCPServer.wlt:3879,1-3884,2"
]

VerificationTest[
    $SupportedMCPClients[ "Codex", "ConfigFormat" ],
    "TOML",
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-CodexConfigFormat@@Tests/InstallMCPServer.wlt:3886,1-3891,2"
]

VerificationTest[
    $SupportedMCPClients[ "Codex", "ProjectSupport" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-CodexProjectSupport@@Tests/InstallMCPServer.wlt:3893,1-3898,2"
]

VerificationTest[
    $SupportedMCPClients[ "ClaudeCode", "ProjectSupport" ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ClaudeCodeProjectSupport@@Tests/InstallMCPServer.wlt:3900,1-3905,2"
]

VerificationTest[
    $SupportedMCPClients[ "Zed", "ConfigKey" ],
    { "context_servers" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-ZedConfigKey@@Tests/InstallMCPServer.wlt:3907,1-3912,2"
]

VerificationTest[
    $SupportedMCPClients[ "VisualStudioCode", "ConfigKey" ],
    { "servers" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-VSCodeConfigKey@@Tests/InstallMCPServer.wlt:3914,1-3919,2"
]

VerificationTest[
    $SupportedMCPClients[ "OpenCode", "ConfigKey" ],
    { "mcp" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-OpenCodeConfigKey@@Tests/InstallMCPServer.wlt:3921,1-3926,2"
]

VerificationTest[
    AllTrue[ Values @ $SupportedMCPClients, StringQ[ #[ "URL" ] ] && StringStartsQ[ #[ "URL" ], "https://" ] & ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AllHaveValidURLs@@Tests/InstallMCPServer.wlt:3928,1-3933,2"
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
    TestID   -> "GuessClientNameFromJSON-Zed@@Tests/InstallMCPServer.wlt:3960,1-3970,2"
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
    TestID   -> "GuessClientNameFromJSON-VisualStudioCode-Legacy@@Tests/InstallMCPServer.wlt:3973,1-3983,2"
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
    TestID   -> "GuessClientNameFromJSON-VisualStudioCode@@Tests/InstallMCPServer.wlt:3986,1-3997,2"
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
    TestID   -> "GuessClientNameFromJSON-GenericServersKey@@Tests/InstallMCPServer.wlt:4000,1-4010,2"
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
    TestID   -> "GuessClientNameFromJSON-OpenCode@@Tests/InstallMCPServer.wlt:4013,1-4023,2"
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
    TestID   -> "GuessClientNameFromJSON-CopilotCLI@@Tests/InstallMCPServer.wlt:4026,1-4036,2"
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
    TestID   -> "GuessClientNameFromJSON-Cline@@Tests/InstallMCPServer.wlt:4039,1-4049,2"
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
    TestID   -> "GuessClientNameFromJSON-Ambiguous@@Tests/InstallMCPServer.wlt:4052,1-4062,2"
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
    TestID   -> "GuessClientNameFromJSON-EmptyJSON@@Tests/InstallMCPServer.wlt:4065,1-4075,2"
]

(* Non-existent file -> None *)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`guessClientNameFromJSON @
        FileNameJoin @ { $TemporaryDirectory, "nonexistent_" <> CreateUUID[] <> ".json" },
    None,
    SameTest -> Equal,
    TestID   -> "GuessClientNameFromJSON-NonExistentFile@@Tests/InstallMCPServer.wlt:4078,1-4084,2"
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
    TestID   -> "ConfigKeyPath-ClaudeDesktop@@Tests/InstallMCPServer.wlt:4089,1-4096,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installClientName = "VisualStudioCode" },
        Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath[ ]
    ],
    { "servers" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-VSCode@@Tests/InstallMCPServer.wlt:4098,1-4105,2"
]

(* VS Code with mcp.json file: uses new key path *)
VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installClientName = "VisualStudioCode" },
        Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath @
            File @ FileNameJoin @ { $TemporaryDirectory, "mcp.json" }
    ],
    { "servers" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-VSCode-MCPJson@@Tests/InstallMCPServer.wlt:4108,1-4116,2"
]

(* VS Code with legacy settings.json: uses old nested key path *)
VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installClientName = "VisualStudioCode" },
        Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath @
            File @ FileNameJoin @ { $TemporaryDirectory, "settings.json" }
    ],
    { "mcp", "servers" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-VSCode-LegacySettings@@Tests/InstallMCPServer.wlt:4119,1-4127,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installClientName = "Zed" },
        Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath[ ]
    ],
    { "context_servers" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-Zed@@Tests/InstallMCPServer.wlt:4129,1-4136,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installClientName = "OpenCode" },
        Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath[ ]
    ],
    { "mcp" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-OpenCode@@Tests/InstallMCPServer.wlt:4138,1-4145,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath[ "UnknownClient" ],
    { "mcpServers" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-UnknownFallback@@Tests/InstallMCPServer.wlt:4147,1-4152,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installClientName = None },
        Wolfram`AgentTools`InstallMCPServer`Private`configKeyPath[ ]
    ],
    { "mcpServers" },
    SameTest -> Equal,
    TestID   -> "ConfigKeyPath-NoneFallback@@Tests/InstallMCPServer.wlt:4154,1-4161,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*emptyConfigForPath*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`emptyConfigForPath @ { "mcpServers" },
    <| "mcpServers" -> <| |> |>,
    SameTest -> Equal,
    TestID   -> "EmptyConfigForPath-SingleKey@@Tests/InstallMCPServer.wlt:4166,1-4171,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`emptyConfigForPath @ { "mcp", "servers" },
    <| "mcp" -> <| "servers" -> <| |> |> |>,
    SameTest -> Equal,
    TestID   -> "EmptyConfigForPath-NestedKeys@@Tests/InstallMCPServer.wlt:4173,1-4178,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`emptyConfigForPath @ { },
    <| |>,
    SameTest -> Equal,
    TestID   -> "EmptyConfigForPath-EmptyPath@@Tests/InstallMCPServer.wlt:4180,1-4185,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureNestedKey*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`ensureNestedKey[ <| "other" -> 1 |>, { "mcpServers" } ],
    <| "other" -> 1, "mcpServers" -> <| |> |>,
    SameTest -> Equal,
    TestID   -> "EnsureNestedKey-AddMissing@@Tests/InstallMCPServer.wlt:4190,1-4195,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`ensureNestedKey[
        <| "mcpServers" -> <| "existing" -> "data" |> |>,
        { "mcpServers" }
    ],
    <| "mcpServers" -> <| "existing" -> "data" |> |>,
    SameTest -> Equal,
    TestID   -> "EnsureNestedKey-PreserveExisting@@Tests/InstallMCPServer.wlt:4197,1-4205,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`ensureNestedKey[
        <| "theme" -> "dark" |>,
        { "mcp", "servers" }
    ],
    <| "theme" -> "dark", "mcp" -> <| "servers" -> <| |> |> |>,
    SameTest -> Equal,
    TestID   -> "EnsureNestedKey-DeepNesting@@Tests/InstallMCPServer.wlt:4207,1-4215,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`ensureNestedKey[
        <| "mcp" -> <| "existing" -> 1 |> |>,
        { "mcp", "servers" }
    ],
    <| "mcp" -> <| "existing" -> 1, "servers" -> <| |> |> |>,
    SameTest -> Equal,
    TestID   -> "EnsureNestedKey-PartiallyExisting@@Tests/InstallMCPServer.wlt:4217,1-4225,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`ensureNestedKey[ "notAssoc", { "mcpServers" } ],
    <| "mcpServers" -> <| |> |>,
    SameTest -> Equal,
    TestID   -> "EnsureNestedKey-NonAssocInput@@Tests/InstallMCPServer.wlt:4227,1-4232,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*serverConverter*)
VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`serverConverter[ "OpenCode" ],
    Wolfram`AgentTools`SupportedClients`Private`convertToOpenCodeFormat,
    SameTest -> SameQ,
    TestID   -> "ServerConverter-OpenCode@@Tests/InstallMCPServer.wlt:4237,1-4242,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`serverConverter[ "CopilotCLI" ],
    Wolfram`AgentTools`SupportedClients`Private`convertToCopilotCLIFormat,
    SameTest -> SameQ,
    TestID   -> "ServerConverter-CopilotCLI@@Tests/InstallMCPServer.wlt:4244,1-4249,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`serverConverter[ "Cline" ],
    Wolfram`AgentTools`SupportedClients`Private`convertToClineFormat,
    SameTest -> SameQ,
    TestID   -> "ServerConverter-Cline@@Tests/InstallMCPServer.wlt:4251,1-4256,2"
]

VerificationTest[
    Wolfram`AgentTools`InstallMCPServer`Private`serverConverter[ "ClaudeDesktop" ],
    Identity,
    SameTest -> SameQ,
    TestID   -> "ServerConverter-Default@@Tests/InstallMCPServer.wlt:4258,1-4263,2"
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
    TestID   -> "ResolveMCPServerName-BuiltInServer@@Tests/InstallMCPServer.wlt:4268,1-4275,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installMCPServerName = "CustomKey" },
        Wolfram`AgentTools`InstallMCPServer`Private`resolveMCPServerName @ MCPServerObject[ "WolframLanguage" ]
    ],
    "CustomKey",
    SameTest -> Equal,
    TestID   -> "ResolveMCPServerName-OptionOverride@@Tests/InstallMCPServer.wlt:4277,1-4284,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`InstallMCPServer`Private`$installMCPServerName = Automatic },
        Wolfram`AgentTools`InstallMCPServer`Private`resolveMCPServerName @ MCPServerObject[ "Wolfram" ]
    ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "ResolveMCPServerName-WolframServer@@Tests/InstallMCPServer.wlt:4286,1-4293,2"
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
    TestID   -> "InstallPacletServer-MockPacletSetup@@Tests/InstallMCPServer.wlt:4304,1-4311,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCPServerName property for paclet server*)
VerificationTest[
    MCPServerObject[ "MockMCPPacletTest/TestServer" ][ "MCPServerName" ],
    "TestServer",
    SameTest -> Equal,
    TestID   -> "MCPServerName-PacletServerProperty@@Tests/InstallMCPServer.wlt:4316,1-4321,2"
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
    TestID   -> "ResolveMCPServerName-PacletServerShortName@@Tests/InstallMCPServer.wlt:4326,1-4333,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensurePacletForInstall - already installed*)
VerificationTest[
    Wolfram`AgentTools`Common`ensurePacletForInstall[ "MockMCPPacletTest/TestServer" ],
    _PacletObject,
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-EnsurePacletAlreadyInstalled@@Tests/InstallMCPServer.wlt:4338,1-4343,2"
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
    TestID   -> "InstallPacletServer-EnsurePacletThreeSegment@@Tests/InstallMCPServer.wlt:4348,1-4355,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install paclet-qualified server to config file*)
VerificationTest[
    $pacletConfigFile = testConfigFile[];
    $pacletInstallResult = InstallMCPServer[ $pacletConfigFile, "MockMCPPacletTest/TestServer", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-Install@@Tests/InstallMCPServer.wlt:4360,1-4366,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config file created*)
VerificationTest[
    FileExistsQ @ $pacletConfigFile,
    True,
    SameTest -> Equal,
    TestID   -> "InstallPacletServer-ConfigFileExists@@Tests/InstallMCPServer.wlt:4371,1-4376,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config file has correct server name as key*)
VerificationTest[
    $pacletConfigJSON = Import[ $pacletConfigFile, "RawJSON" ];
    KeyExistsQ[ $pacletConfigJSON[ "mcpServers" ], "TestServer" ],
    True,
    SameTest -> Equal,
    TestID   -> "InstallPacletServer-ConfigHasServerName@@Tests/InstallMCPServer.wlt:4381,1-4387,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config server entry has correct MCP_SERVER_NAME env var*)
VerificationTest[
    $pacletConfigJSON[ "mcpServers", "TestServer", "env", "MCP_SERVER_NAME" ],
    "MockMCPPacletTest/TestServer",
    SameTest -> Equal,
    TestID   -> "InstallPacletServer-ConfigEnvServerName@@Tests/InstallMCPServer.wlt:4392,1-4397,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Uninstall paclet server*)
VerificationTest[
    UninstallMCPServer[ $pacletConfigFile, MCPServerObject[ "MockMCPPacletTest/TestServer" ] ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-Uninstall@@Tests/InstallMCPServer.wlt:4402,1-4407,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config no longer has server after uninstall*)
VerificationTest[
    updatedJSON = Import[ $pacletConfigFile, "RawJSON" ];
    KeyExistsQ[ updatedJSON[ "mcpServers" ], "TestServer" ],
    False,
    SameTest -> Equal,
    TestID   -> "InstallPacletServer-VerifyUninstall@@Tests/InstallMCPServer.wlt:4412,1-4418,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install result contains MCPServerObject*)
VerificationTest[
    $pacletInstallResult2 = InstallMCPServer[ $pacletConfigFile, "MockMCPPacletTest/TestServer", "VerifyLLMKit" -> False ];
    $pacletInstallResult2[ "MCPServerObject" ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-ResultHasMCPServerObject@@Tests/InstallMCPServer.wlt:4423,1-4429,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validatePacletServerDefinitions - no error for valid paclet server*)
VerificationTest[
    obj = MCPServerObject[ "MockMCPPacletTest/TestServer" ];
    Wolfram`AgentTools`InstallMCPServer`Private`validatePacletServerDefinitions @ obj,
    Null,
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-ValidateDefinitionsValid@@Tests/InstallMCPServer.wlt:4434,1-4440,2"
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
    TestID   -> "InstallPacletServer-ValidateDefinitionsNoOp@@Tests/InstallMCPServer.wlt:4445,1-4456,2"
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
    TestID   -> "InstallPacletServer-ValidateToolError@@Tests/InstallMCPServer.wlt:4461,1-4476,2"
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
    TestID   -> "InstallPacletServer-ValidatePromptError@@Tests/InstallMCPServer.wlt:4481,1-4496,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    cleanupTestFiles @ $pacletConfigFile;
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "InstallPacletServer-Cleanup@@Tests/InstallMCPServer.wlt:4501,1-4507,2"
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
    TestID   -> "MCPServerName-BuiltInUsesWolframKey-Install@@Tests/InstallMCPServer.wlt:4516,1-4522,2"
]

VerificationTest[
    jsonContent = Import[ mcpNameConfigFile, "RawJSON" ];
    KeyExistsQ[ jsonContent[ "mcpServers" ], "Wolfram" ] &&
    ! KeyExistsQ[ jsonContent[ "mcpServers" ], "WolframLanguage" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-BuiltInUsesWolframKey-Verify@@Tests/InstallMCPServer.wlt:4524,1-4531,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Second built-in overwrites first under shared key*)
VerificationTest[
    InstallMCPServer[ mcpNameConfigFile, "WolframAlpha", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "MCPServerName-SecondBuiltInOverwrites-Install@@Tests/InstallMCPServer.wlt:4536,1-4541,2"
]

VerificationTest[
    jsonContent = Import[ mcpNameConfigFile, "RawJSON" ];
    Length[ Keys[ jsonContent[ "mcpServers" ] ] ] === 1 &&
    KeyExistsQ[ jsonContent[ "mcpServers" ], "Wolfram" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-SecondBuiltInOverwrites-Verify@@Tests/InstallMCPServer.wlt:4543,1-4550,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Uninstall built-in removes "Wolfram" key*)
VerificationTest[
    UninstallMCPServer[ mcpNameConfigFile, "WolframAlpha" ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "MCPServerName-UninstallBuiltIn@@Tests/InstallMCPServer.wlt:4555,1-4560,2"
]

VerificationTest[
    jsonContent = Import[ mcpNameConfigFile, "RawJSON" ];
    ! KeyExistsQ[ jsonContent[ "mcpServers" ], "Wolfram" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-UninstallBuiltIn-Verify@@Tests/InstallMCPServer.wlt:4562,1-4568,2"
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
    TestID   -> "MCPServerName-CustomServerUsesName-Install@@Tests/InstallMCPServer.wlt:4573,1-4583,2"
]

VerificationTest[
    jsonContent = Import[ mcpNameConfigFile, "RawJSON" ];
    KeyExistsQ[ jsonContent[ "mcpServers" ], mcpNameCustomName ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-CustomServerUsesName-Verify@@Tests/InstallMCPServer.wlt:4585,1-4591,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCPServerName option override*)
VerificationTest[
    InstallMCPServer[ mcpNameConfigFile, "WolframLanguage", "MCPServerName" -> "WolframDev", "VerifyLLMKit" -> False ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "MCPServerName-OptionOverride-Install@@Tests/InstallMCPServer.wlt:4596,1-4601,2"
]

VerificationTest[
    jsonContent = Import[ mcpNameConfigFile, "RawJSON" ];
    KeyExistsQ[ jsonContent[ "mcpServers" ], "WolframDev" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-OptionOverride-Verify@@Tests/InstallMCPServer.wlt:4603,1-4609,2"
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
    TestID   -> "MCPServerName-TwoBuiltInWithOverrides-Install@@Tests/InstallMCPServer.wlt:4614,1-4621,2"
]

VerificationTest[
    jsonContent = Import[ mcpNameConfigFile2, "RawJSON" ];
    KeyExistsQ[ jsonContent[ "mcpServers" ], "WolframBasic" ] &&
    KeyExistsQ[ jsonContent[ "mcpServers" ], "WolframDev2" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerName-TwoBuiltInWithOverrides-Verify@@Tests/InstallMCPServer.wlt:4623,1-4630,2"
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
    TestID   -> "MCPServerName-StaleRecordClearing-Setup@@Tests/InstallMCPServer.wlt:4635,1-4643,2"
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
    TestID   -> "MCPServerName-StaleRecordClearing-Verify@@Tests/InstallMCPServer.wlt:4645,1-4655,2"
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
    TestID   -> "MCPServerName-Cleanup@@Tests/InstallMCPServer.wlt:4660,1-4669,2"
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
    TestID   -> "DefaultToolsetForTarget-ClaudeCode@@Tests/InstallMCPServer.wlt:4678,1-4684,2"
]

VerificationTest[
    defaultToolsetForTarget[ "ClaudeDesktop" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-ClaudeDesktop@@Tests/InstallMCPServer.wlt:4686,1-4691,2"
]

VerificationTest[
    defaultToolsetForTarget[ "Goose" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Goose@@Tests/InstallMCPServer.wlt:4693,1-4698,2"
]

VerificationTest[
    defaultToolsetForTarget[ "Cursor" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Cursor@@Tests/InstallMCPServer.wlt:4700,1-4705,2"
]

(* Junie is a coding agent (covers JetBrains IDE plugin and Junie CLI), so it defaults to WolframLanguage *)
VerificationTest[
    defaultToolsetForTarget[ "Junie" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Junie@@Tests/InstallMCPServer.wlt:4708,1-4713,2"
]

(* Junie alias resolves to the canonical client's default *)
VerificationTest[
    defaultToolsetForTarget[ "JetBrainsJunie" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Alias-JetBrainsJunie@@Tests/InstallMCPServer.wlt:4716,1-4721,2"
]

(* {Junie, dir} project-install form *)
VerificationTest[
    defaultToolsetForTarget[ { "Junie", "/some/dir" } ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-NameDir-Junie@@Tests/InstallMCPServer.wlt:4724,1-4729,2"
]

(* Aliases resolve to their canonical client's default *)
VerificationTest[
    defaultToolsetForTarget[ "Claude" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Alias-Claude@@Tests/InstallMCPServer.wlt:4732,1-4737,2"
]

VerificationTest[
    defaultToolsetForTarget[ "VSCode" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Alias-VSCode@@Tests/InstallMCPServer.wlt:4739,1-4744,2"
]

(* Unknown client falls back to $defaultMCPServer *)
VerificationTest[
    defaultToolsetForTarget[ "TotallyMadeUpClient" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-Unknown@@Tests/InstallMCPServer.wlt:4747,1-4752,2"
]

(* {name, dir} project-install form dispatches on the name *)
VerificationTest[
    defaultToolsetForTarget[ { "ClaudeCode", "/some/dir" } ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-NameDir-ClaudeCode@@Tests/InstallMCPServer.wlt:4755,1-4760,2"
]

VerificationTest[
    defaultToolsetForTarget[ { "ClaudeDesktop", "/some/dir" } ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-NameDir-ClaudeDesktop@@Tests/InstallMCPServer.wlt:4762,1-4767,2"
]

(* File target with no client match falls back *)
VerificationTest[
    defaultToolsetForTarget[ File[ "C:/this/path/is/not/a/known/client.json" ] ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-Unknown@@Tests/InstallMCPServer.wlt:4770,1-4775,2"
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
    TestID   -> "DefaultToolsetForTarget-File-ClaudeCodeProject@@Tests/InstallMCPServer.wlt:4783,1-4788,2"
]

(* .vscode/mcp.json -> VisualStudioCode (coding client, "WolframLanguage") *)
VerificationTest[
    defaultToolsetForTarget[ File[ "/some/project/.vscode/mcp.json" ] ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-VSCodeProject@@Tests/InstallMCPServer.wlt:4791,1-4796,2"
]

(* opencode.json -> OpenCode (coding client, "WolframLanguage") *)
VerificationTest[
    defaultToolsetForTarget[ File[ "/some/project/opencode.json" ] ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-OpenCodeProject@@Tests/InstallMCPServer.wlt:4799,1-4804,2"
]

(* Non-target argument falls back *)
VerificationTest[
    defaultToolsetForTarget[ 42 ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-NonTarget@@Tests/InstallMCPServer.wlt:4807,1-4812,2"
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
    TestID   -> "DefaultToolsetForTarget-File-AppName-Cline@@Tests/InstallMCPServer.wlt:4819,1-4824,2"
]

VerificationTest[
    defaultToolsetForTarget[ File[ "C:/this/path/is/not/a/known/client.json" ], "ClaudeDesktop" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-AppName-ClaudeDesktop@@Tests/InstallMCPServer.wlt:4826,1-4831,2"
]

(* Aliases route through toInstallName, so an alias picks up the canonical client's default *)
VerificationTest[
    defaultToolsetForTarget[ File[ "C:/this/path/is/not/a/known/client.json" ], "VSCode" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-AppName-Alias@@Tests/InstallMCPServer.wlt:4834,1-4839,2"
]

(* Automatic in the 2-arg form falls back to the existing target-based resolution *)
VerificationTest[
    defaultToolsetForTarget[ File[ "C:/this/path/is/not/a/known/client.json" ], Automatic ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-File-AppName-Automatic@@Tests/InstallMCPServer.wlt:4842,1-4847,2"
]

(* String target is also overridden by an explicit ApplicationName *)
VerificationTest[
    defaultToolsetForTarget[ "ClaudeCode", "ClaudeDesktop" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DefaultToolsetForTarget-StringTarget-AppName@@Tests/InstallMCPServer.wlt:4850,1-4855,2"
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
    TestID   -> "InstallMCPServer-Automatic-ClaudeCode@@Tests/InstallMCPServer.wlt:4860,1-4871,2"
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
    TestID   -> "InstallMCPServer-1Arg-ClaudeCode@@Tests/InstallMCPServer.wlt:4874,1-4885,2"
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
    TestID   -> "InstallMCPServer-Automatic-File-AppName-Cline@@Tests/InstallMCPServer.wlt:4892,1-4904,2"
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
    TestID   -> "InstallMCPServer-Automatic-File-AppName-ClaudeDesktop@@Tests/InstallMCPServer.wlt:4906,1-4919,2"
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
    TestID   -> "InstallMCPServer-Automatic-File-ClaudeCodeProject@@Tests/InstallMCPServer.wlt:4930,1-4942,2"
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
    TestID   -> "InstallMCPServer-Automatic-File-VSCodeProject@@Tests/InstallMCPServer.wlt:4945,1-4959,2"
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
    TestID   -> "SupportedMCPClients-DefaultToolset-Coverage@@Tests/InstallMCPServer.wlt:4967,1-4980,2"
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
    TestID -> "Automatic-Cleanup@@Tests/InstallMCPServer.wlt:4985,1-4992,2"
]

(* :!CodeAnalysis::EndBlock:: *)