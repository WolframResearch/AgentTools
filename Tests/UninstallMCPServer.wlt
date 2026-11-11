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
(*Uninstall Single Server*)
VerificationTest[
    configFile = testConfigFile[];
    Export[configFile, <| "mcpServers" -> <| |> |>, "RawJSON"];

    (* Install a custom server and a built-in server *)
    uninstallTestName = StringJoin["UninstallSingle_", CreateUUID[]];
    uninstallTestServer = CreateMCPServer[
        uninstallTestName,
        LLMConfiguration @ <| "Tools" -> { LLMTool[ "PrimeFinder", { "n" -> "Integer" }, Prime[ #n ] & ] } |>
    ];
    InstallMCPServer[configFile, uninstallTestServer];
    InstallMCPServer[configFile, "WolframLanguage"];

    (* Verify both servers were installed (custom name + "Wolfram") *)
    jsonContent = Import[configFile, "RawJSON"];
    startingServerCount = Length[Keys[jsonContent["mcpServers"]]],

    2,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-Setup"
]

VerificationTest[
    (* Uninstall only the built-in server *)
    uninstallResult = UninstallMCPServer[configFile, "WolframLanguage"],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-SingleServer"
]

VerificationTest[
    (* Verify that only the built-in "Wolfram" key was removed, custom server remains *)
    jsonContent = Import[configFile, "RawJSON"];
    KeyExistsQ[jsonContent["mcpServers"], uninstallTestName] &&
    !KeyExistsQ[jsonContent["mcpServers"], "Wolfram"],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-VerifySingleServerRemoval"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Uninstall Cross-Variant Built-in Server*)
VerificationTest[
    (* Install "WolframLanguage" (config key "Wolfram"), then uninstall using "Wolfram" *)
    crossVariantConfig = testConfigFile[];
    Export[crossVariantConfig, <| "mcpServers" -> <| |> |>, "RawJSON"];
    InstallMCPServer[crossVariantConfig, "WolframLanguage"],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-CrossVariantSetup"
]

VerificationTest[
    (* Uninstall using a different built-in variant name that shares the same config key *)
    UninstallMCPServer[crossVariantConfig, "Wolfram"],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-CrossVariant"
]

VerificationTest[
    (* Verify the "Wolfram" key was removed *)
    crossVariantJSON = Import[crossVariantConfig, "RawJSON"];
    crossVariantJSON["mcpServers"] === <||>,
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-VerifyCrossVariantRemoval"
]

VerificationTest[
    cleanupTestFiles[crossVariantConfig],
    {Null},
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-CrossVariantCleanup"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Uninstall All Servers*)
VerificationTest[
    (* Uninstall all remaining servers *)
    uninstallAllResult = UninstallMCPServer[configFile],
    { ___Success },
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-AllServers"
]

VerificationTest[
    (* Verify that all servers were removed *)
    jsonContent = Import[configFile, "RawJSON"];
    jsonContent["mcpServers"] === <| |>,
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-VerifyAllServersRemoval"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Uninstall by Object*)
VerificationTest[
    (* Create a new server and install it *)
    configFile = testConfigFile[];
    Export[configFile, <| "mcpServers" -> <| |> |>, "RawJSON"];

    name = StringJoin["UninstallTest_", CreateUUID[]];
    server = CreateMCPServer[
        name,
        LLMConfiguration @ <| "Tools" -> { LLMTool[ "PrimeFinder", { "n" -> "Integer" }, Prime[ #n ] & ] } |>
    ];

    installResult = InstallMCPServer[configFile, server],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-ServerObjectSetup"
]

VerificationTest[
    (* Uninstall using the server object *)
    uninstallObjectResult = UninstallMCPServer[configFile, server],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-ByObject"
]

VerificationTest[
    (* Verify the server was removed *)
    jsonContent = Import[configFile, "RawJSON"];
    !KeyExistsQ[jsonContent["mcpServers"], name],
    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-VerifyObjectRemoval"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Uninstall All Instances*)
VerificationTest[
    (* Create and install on multiple config files *)
    configFile1 = testConfigFile[];
    configFile2 = testConfigFile[];

    Export[configFile1, <| "mcpServers" -> <| |> |>, "RawJSON"];
    Export[configFile2, <| "mcpServers" -> <| |> |>, "RawJSON"];

    name = StringJoin["MultipleInstall_", CreateUUID[]];
    server = CreateMCPServer[
        name,
        LLMConfiguration @ <| "Tools" -> { LLMTool[ "Doubler", { "x" -> "Number" }, 2 * #x & ] } |>
    ];

    InstallMCPServer[configFile1, server];
    InstallMCPServer[configFile2, server],

    _Success,
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-MultipleInstallsSetup"
]

VerificationTest[
    (* Uninstall server from all config files *)
    uninstallAllInstancesResult = UninstallMCPServer[All, server],
    { _Success, _Success },
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-AllInstances"
]

VerificationTest[
    (* Verify removal from all files *)
    jsonContent1 = Import[configFile1, "RawJSON"];
    jsonContent2 = Import[configFile2, "RawJSON"];

    !KeyExistsQ[jsonContent1["mcpServers"], name] &&
    !KeyExistsQ[jsonContent2["mcpServers"], name],

    True,
    SameTest -> Equal,
    TestID   -> "UninstallMCPServer-VerifyAllInstancesRemoval"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    DeleteObject[server];
    Quiet @ DeleteObject[uninstallTestServer];
    cleanupTestFiles[{configFile, configFile1, configFile2}],
    {Null..},
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-Cleanup"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Cases*)
VerificationTest[
    configFile = testConfigFile[];
    Export[configFile, <| "mcpServers" -> <| |> |>, "RawJSON"];
    UninstallMCPServer[configFile, "NonExistentServer"],
    _Failure,
    {UninstallMCPServer::MCPServerNotFound},
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-NonExistentServer"
]

VerificationTest[
    nonExistentFile = File @ FileNameJoin[{$TemporaryDirectory, "non_existent_config.json"}];
    UninstallMCPServer[nonExistentFile, "WolframLanguage"],
    _Missing,
    { },  (* No messages expected since notFoundQ just returns Missing *)
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-NonExistentFile"
]

VerificationTest[
    cleanupTestFiles[configFile],
    {Null},
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-ErrorCleanup"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Missing File Does Not Create Directories*)
VerificationTest[
    missingConfigDir = FileNameJoin @ { $TemporaryDirectory, "mcp_test_missing_" <> CreateUUID[ ] };
    {
        UninstallMCPServer[ File @ FileNameJoin @ { missingConfigDir, "mcp.json" }, "WolframLanguage" ],
        DirectoryQ @ missingConfigDir
    },
    { Missing[ "NotInstalled", _File ], False },
    SameTest -> MatchQ,
    TestID   -> "UninstallMCPServer-MissingFile-NoDirectoriesCreated"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*removeMCPConfigEntry*)
(* removeMCPConfigEntry[ file, clientName, configKey ] removes one entry from a client configuration file using the
   client's config format. It returns True when an entry was removed, Missing[ "NotInstalled", file ] when the file or
   the entry doesn't exist, and fails with InvalidMCPConfiguration for a file it can't parse. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Setup*)
VerificationTest[
    removeEntry  = Wolfram`AgentTools`Common`removeMCPConfigEntry;
    $removeTestDir = CreateDirectory[ ];

    (* Writes a configuration file (creating its parent directories) and returns it as File[ ... ] *)
    writeConfig[ path_String, content_String ] :=
        Module[ { file },
            file = FileNameJoin @ { $removeTestDir, path };
            Quiet @ CreateDirectory[ DirectoryName @ file, CreateIntermediateDirectories -> True ];
            Export[ file, content, "String" ];
            File @ file
        ];

    fileBytes[ File[ file_ ] ] := ReadByteArray @ file;

    DirectoryQ @ $removeTestDir,
    True,
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-Setup"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*JSON*)
VerificationTest[
    removeJSONFile = writeConfig[
        "generic.json",
        "{\"mcpServers\": {\"Wolfram\": {\"command\": \"wolfram\"}, \"Other\": {\"command\": \"other\"}}, \"theme\": \"dark\"}"
    ];
    removeEntry[ removeJSONFile, None, "Wolfram" ],
    True,
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-JSON"
]

VerificationTest[
    With[ { json = Developer`ReadRawJSONFile @ First @ removeJSONFile },
        { Keys @ json[ "mcpServers" ], json[ "mcpServers", "Other" ], json[ "theme" ] }
    ],
    { { "Other" }, <| "command" -> "other" |>, "dark" },
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-JSON-Content"
]

VerificationTest[
    Module[ { before, result },
        before = fileBytes @ removeJSONFile;
        result = removeEntry[ removeJSONFile, None, "NotThere" ];
        { result, fileBytes @ removeJSONFile === before }
    ],
    { Missing[ "NotInstalled", File[ _String ] ], True },
    SameTest -> MatchQ,
    TestID   -> "RemoveMCPConfigEntry-JSON-AbsentKey"
]

(* An unknown client name uses the generic JSON format *)
VerificationTest[
    removeEntry[ writeConfig[ "unknown-client.json", "{\"mcpServers\": {\"Wolfram\": {}}}" ], "NotARealClient", "Wolfram" ],
    True,
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-JSON-UnknownClient"
]

VerificationTest[
    Module[ { dir },
        dir = FileNameJoin @ { $removeTestDir, "does-not-exist" };
        { removeEntry[ File @ FileNameJoin @ { dir, "mcp.json" }, None, "Wolfram" ], DirectoryQ @ dir }
    ],
    { Missing[ "NotInstalled", File[ _String ] ], False },
    SameTest -> MatchQ,
    TestID   -> "RemoveMCPConfigEntry-MissingFile"
]

VerificationTest[
    removeInvalidJSONFile = writeConfig[ "invalid.json", "{\"mcpServers\": {\"Wolfram\": " ];
    Wolfram`AgentTools`Common`catchAlways @ removeEntry[ removeInvalidJSONFile, None, "Wolfram" ],
    Failure[ "AgentTools::InvalidMCPConfiguration", _ ],
    { AgentTools::InvalidMCPConfiguration },
    SameTest -> MatchQ,
    TestID   -> "RemoveMCPConfigEntry-JSON-Invalid"
]

VerificationTest[
    ReadString @ First @ removeInvalidJSONFile,
    "{\"mcpServers\": {\"Wolfram\": ",
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-JSON-InvalidUnchanged"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other JSON Key Paths*)

(* VS Code's legacy settings.json keeps servers under "mcp" > "servers" *)
VerificationTest[
    removeVSCodeSettingsFile = writeConfig[
        FileNameJoin @ { "vscode-legacy", "settings.json" },
        "{\"editor.fontSize\": 12, \"mcp\": {\"servers\": {\"Wolfram\": {\"command\": \"wolfram\"}, \"Other\": {}}}}"
    ];
    removeEntry[ removeVSCodeSettingsFile, "VisualStudioCode", "Wolfram" ],
    True,
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-VSCodeLegacySettings"
]

VerificationTest[
    With[ { json = Developer`ReadRawJSONFile @ First @ removeVSCodeSettingsFile },
        { Keys @ json[ "mcp", "servers" ], json[ "editor.fontSize" ] }
    ],
    { { "Other" }, 12 },
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-VSCodeLegacySettings-Content"
]

(* Aliases are resolved, and the newer mcp.json format uses a top-level "servers" key *)
VerificationTest[
    removeVSCodeMCPFile = writeConfig[
        FileNameJoin @ { "vscode", "mcp.json" },
        "{\"servers\": {\"Wolfram\": {\"command\": \"wolfram\"}}}"
    ];
    {
        (* Without the client name, the generic "mcpServers" key is used, so nothing is found *)
        removeEntry[ removeVSCodeMCPFile, None, "Wolfram" ],
        removeEntry[ removeVSCodeMCPFile, "VSCode", "Wolfram" ],
        Developer`ReadRawJSONFile @ First @ removeVSCodeMCPFile
    },
    { Missing[ "NotInstalled", _ ], True, <| "servers" -> <| |> |> },
    SameTest -> MatchQ,
    TestID   -> "RemoveMCPConfigEntry-VSCodeMCPJSON"
]

VerificationTest[
    removeZedFile = writeConfig[
        FileNameJoin @ { "zed", "settings.json" },
        "{\"theme\": \"One Dark\", \"context_servers\": {\"Wolfram\": {\"command\": \"wolfram\"}}}"
    ];
    {
        removeEntry[ removeZedFile, "Zed", "Wolfram" ],
        Developer`ReadRawJSONFile @ First @ removeZedFile
    },
    { True, KeyValuePattern @ { "theme" -> "One Dark", "context_servers" -> <| |> } },
    SameTest -> MatchQ,
    TestID   -> "RemoveMCPConfigEntry-Zed"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Codex (TOML)*)
VerificationTest[
    removeCodexFile = writeConfig[
        FileNameJoin @ { "codex", "config.toml" },
        StringJoin[
            "[mcp_servers.Wolfram]\n",
            "command = \"wolfram\"\n",
            "args = [\"-run\", \"x\"]\n",
            "\n",
            "[mcp_servers.Other]\n",
            "command = \"other\"\n",
            "\n",
            "[profiles.default]\n",
            "model = \"o3\"\n"
        ]
    ];
    removeEntry[ removeCodexFile, "Codex", "Wolfram" ],
    True,
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-Codex"
]

VerificationTest[
    With[ { data = Wolfram`AgentTools`Common`readTOMLFile[ removeCodexFile ][ "Data" ] },
        { Keys @ data[ "mcp_servers" ], data[ "mcp_servers", "Other", "command" ], data[ "profiles", "default", "model" ] }
    ],
    { { "Other" }, "other", "o3" },
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-Codex-Content"
]

VerificationTest[
    Module[ { before, result },
        before = fileBytes @ removeCodexFile;
        (* "OpenAICodex" is an alias of "Codex" *)
        result = removeEntry[ removeCodexFile, "OpenAICodex", "Wolfram" ];
        { result, fileBytes @ removeCodexFile === before }
    ],
    { Missing[ "NotInstalled", File[ _String ] ], True },
    SameTest -> MatchQ,
    TestID   -> "RemoveMCPConfigEntry-Codex-AbsentKey"
]

(* The TOML reader is lenient; a config path that can't be read as a file (here a directory) is invalid *)
VerificationTest[
    Module[ { dir },
        dir = FileNameJoin @ { $removeTestDir, "codex-dir", "config.toml" };
        CreateDirectory[ dir, CreateIntermediateDirectories -> True ];
        Wolfram`AgentTools`Common`catchAlways @ removeEntry[ File @ dir, "Codex", "Wolfram" ]
    ],
    Failure[ "AgentTools::InvalidMCPConfiguration", _ ],
    { AgentTools::InvalidMCPConfiguration },
    SameTest -> MatchQ,
    TestID   -> "RemoveMCPConfigEntry-Codex-Invalid"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Goose (YAML)*)
VerificationTest[
    removeGooseFile = writeConfig[
        FileNameJoin @ { "goose", "config.yaml" },
        StringJoin[
            "extensions:\n",
            "  Wolfram:\n",
            "    name: Wolfram\n",
            "    cmd: wolfram\n",
            "    enabled: true\n",
            "  developer:\n",
            "    name: developer\n",
            "    enabled: true\n",
            "    type: builtin\n",
            "GOOSE_MODEL: gpt-4o\n"
        ]
    ];
    removeEntry[ removeGooseFile, "Goose", "Wolfram" ],
    True,
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-Goose"
]

VerificationTest[
    With[ { yaml = Wolfram`AgentTools`Common`importYAML @ removeGooseFile },
        { Keys @ yaml[ "extensions" ], yaml[ "extensions", "developer", "type" ], yaml[ "GOOSE_MODEL" ] }
    ],
    { { "developer" }, "builtin", "gpt-4o" },
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-Goose-Content"
]

VerificationTest[
    Module[ { before, result },
        before = fileBytes @ removeGooseFile;
        result = removeEntry[ removeGooseFile, "Goose", "Wolfram" ];
        { result, fileBytes @ removeGooseFile === before }
    ],
    { Missing[ "NotInstalled", File[ _String ] ], True },
    SameTest -> MatchQ,
    TestID   -> "RemoveMCPConfigEntry-Goose-AbsentKey"
]

VerificationTest[
    removeInvalidGooseFile = writeConfig[
        FileNameJoin @ { "goose-invalid", "config.yaml" },
        "extensions:\n  Wolfram:\n    cmd: wolfram\n     name: bad-indent\n"
    ];
    Wolfram`AgentTools`Common`catchAlways @ removeEntry[ removeInvalidGooseFile, "Goose", "Wolfram" ],
    Failure[ "AgentTools::InvalidMCPConfiguration", _ ],
    { AgentTools::InvalidMCPConfiguration },
    SameTest -> MatchQ,
    TestID   -> "RemoveMCPConfigEntry-Goose-Invalid"
]

VerificationTest[
    StringContainsQ[ ReadString @ First @ removeInvalidGooseFile, "bad-indent" ],
    True,
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-Goose-InvalidUnchanged"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Continue (YAML)*)
VerificationTest[
    removeContinueFile = writeConfig[
        FileNameJoin @ { "continue", "config.yaml" },
        StringJoin[
            "name: Local Config\n",
            "version: 1.0.0\n",
            "schema: v1\n",
            "models:\n",
            "  - name: GPT\n",
            "    provider: openai\n",
            "mcpServers:\n",
            "  - name: Wolfram\n",
            "    command: wolfram\n",
            "  - name: Other\n",
            "    command: other\n"
        ]
    ];
    removeEntry[ removeContinueFile, "Continue", "Wolfram" ],
    True,
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-Continue-Global"
]

VerificationTest[
    With[ { yaml = Wolfram`AgentTools`Common`importYAML @ removeContinueFile },
        { Lookup[ yaml[ "mcpServers" ], "name" ], yaml[ "models" ], yaml[ "name" ] }
    ],
    { { "Other" }, { <| "name" -> "GPT", "provider" -> "openai" |> }, "Local Config" },
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-Continue-Global-Content"
]

VerificationTest[
    Module[ { before, result },
        before = fileBytes @ removeContinueFile;
        result = removeEntry[ removeContinueFile, "Continue", "Wolfram" ];
        { result, fileBytes @ removeContinueFile === before }
    ],
    { Missing[ "NotInstalled", File[ _String ] ], True },
    SameTest -> MatchQ,
    TestID   -> "RemoveMCPConfigEntry-Continue-AbsentKey"
]

(* Project scope: a standalone block file in .continue/mcpServers/ *)
VerificationTest[
    removeContinueProjectFile = writeConfig[
        FileNameJoin @ { "project", ".continue", "mcpServers", "wolfram.yaml" },
        StringJoin[
            "name: Wolfram\n",
            "version: 1.0.0\n",
            "schema: v1\n",
            "mcpServers:\n",
            "  - name: Wolfram\n",
            "    command: wolfram\n"
        ]
    ];
    {
        removeEntry[ removeContinueProjectFile, "Continue", "Wolfram" ],
        Wolfram`AgentTools`Common`importYAML[ removeContinueProjectFile ][ "mcpServers" ]
    },
    { True, { } },
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-Continue-Project"
]

VerificationTest[
    removeInvalidContinueFile = writeConfig[
        FileNameJoin @ { "continue-invalid", "config.yaml" },
        "mcpServers:\n  - name: Wolfram\n     command: bad-indent\n"
    ];
    Wolfram`AgentTools`Common`catchAlways @ removeEntry[ removeInvalidContinueFile, "Continue", "Wolfram" ],
    Failure[ "AgentTools::InvalidMCPConfiguration", _ ],
    { AgentTools::InvalidMCPConfiguration },
    SameTest -> MatchQ,
    TestID   -> "RemoveMCPConfigEntry-Continue-Invalid"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AugmentCodeIDE (JSON Array)*)
VerificationTest[
    removeAugmentFile = writeConfig[
        FileNameJoin @ { "augment", "mcpServers.json" },
        StringJoin[
            "[{\"name\": \"Wolfram\", \"type\": \"stdio\", \"command\": \"wolfram\"},",
            " {\"name\": \"Other\", \"type\": \"stdio\", \"command\": \"other\"}]"
        ]
    ];
    {
        removeEntry[ removeAugmentFile, "AugmentCodeIDE", "Wolfram" ],
        Lookup[ Developer`ReadRawJSONFile @ First @ removeAugmentFile, "name" ]
    },
    { True, { "Other" } },
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-AugmentCodeIDE"
]

VerificationTest[
    Module[ { before, result },
        before = fileBytes @ removeAugmentFile;
        result = removeEntry[ removeAugmentFile, "AugmentIDE", "Wolfram" ];
        { result, fileBytes @ removeAugmentFile === before }
    ],
    { Missing[ "NotInstalled", File[ _String ] ], True },
    SameTest -> MatchQ,
    TestID   -> "RemoveMCPConfigEntry-AugmentCodeIDE-AbsentKey"
]

(* The extension's file must be a JSON array *)
VerificationTest[
    removeInvalidAugmentFile = writeConfig[
        FileNameJoin @ { "augment-invalid", "mcpServers.json" },
        "{\"mcpServers\": {\"Wolfram\": {}}}"
    ];
    {
        Wolfram`AgentTools`Common`catchAlways @ removeEntry[ removeInvalidAugmentFile, "AugmentCodeIDE", "Wolfram" ],
        ReadString @ First @ removeInvalidAugmentFile
    },
    { Failure[ "AgentTools::InvalidMCPConfiguration", _ ], "{\"mcpServers\": {\"Wolfram\": {}}}" },
    { AgentTools::InvalidMCPConfiguration },
    SameTest -> MatchQ,
    TestID   -> "RemoveMCPConfigEntry-AugmentCodeIDE-Invalid"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    DeleteDirectory[ $removeTestDir, DeleteContents -> True ];
    DirectoryQ @ $removeTestDir,
    False,
    SameTest -> Equal,
    TestID   -> "RemoveMCPConfigEntry-Cleanup"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*clearMCPInstallationRecord*)
(* clearMCPInstallationRecord[ serverName, configFile ] edits the server's Installations.wxf by name, without resolving
   the server. withTemporaryRoot keeps the records away from the real server storage. *)
VerificationTest[
    withTemporaryRoot @ Module[ { name, file, configA, configB, records, result },
        name    = "Pub/NotInstalledPaclet/SomeServer"; (* never resolvable, so this can't be resolving the server *)
        file    = Wolfram`AgentTools`Common`fileNameJoin[
            Wolfram`AgentTools`Common`mcpServerDirectory @ name,
            "Installations.wxf"
        ];
        configA = File @ FileNameJoin @ { $TemporaryDirectory, "configA.json" };
        configB = File @ FileNameJoin @ { $TemporaryDirectory, "configB.json" };
        records = {
            <| "ClientName" -> "ClaudeCode", "ConfigurationFile" -> configA |>,
            <| "ClientName" -> "Cursor"    , "ConfigurationFile" -> configB |>,
            configA (* legacy record *)
        };
        Wolfram`AgentTools`Common`writeWXFFile[ file, records ];
        result = Wolfram`AgentTools`Common`clearMCPInstallationRecord[ name, configA ];
        { result, Wolfram`AgentTools`Common`readWXFFile @ file }
    ],
    {
        { <| "ClientName" -> "Cursor", "ConfigurationFile" -> File[ _String ] |> },
        { <| "ClientName" -> "Cursor", "ConfigurationFile" -> File[ _String ] |> }
    },
    SameTest -> MatchQ,
    TestID   -> "ClearMCPInstallationRecord-RemovesMatchingRecords"
]

VerificationTest[
    withTemporaryRoot @ Module[ { name, file, config, result },
        name   = "ClearRecordTestServer";
        file   = Wolfram`AgentTools`Common`fileNameJoin[
            Wolfram`AgentTools`Common`mcpServerDirectory @ name,
            "Installations.wxf"
        ];
        config = FileNameJoin @ { $TemporaryDirectory, "configC.json" };
        Wolfram`AgentTools`Common`writeWXFFile[
            file,
            { <| "ClientName" -> "ClaudeCode", "ConfigurationFile" -> File @ config |> }
        ];
        (* A string path matches the File record *)
        result = Wolfram`AgentTools`Common`clearMCPInstallationRecord[ name, config ];
        { result, FileExistsQ @ file }
    ],
    { { }, False },
    SameTest -> Equal,
    TestID   -> "ClearMCPInstallationRecord-DeletesEmptyFile"
]

VerificationTest[
    withTemporaryRoot @ Module[ { name, file, config, records, result },
        name    = "ClearRecordTestServer";
        file    = Wolfram`AgentTools`Common`fileNameJoin[
            Wolfram`AgentTools`Common`mcpServerDirectory @ name,
            "Installations.wxf"
        ];
        config  = File @ FileNameJoin @ { $TemporaryDirectory, "configD.json" };
        records = { <| "ClientName" -> "ClaudeCode", "ConfigurationFile" -> config |> };
        Wolfram`AgentTools`Common`writeWXFFile[ file, records ];
        result = Wolfram`AgentTools`Common`clearMCPInstallationRecord[
            name,
            File @ FileNameJoin @ { $TemporaryDirectory, "some-other-config.json" }
        ];
        { result === records, Wolfram`AgentTools`Common`readWXFFile @ file === records }
    ],
    { True, True },
    SameTest -> Equal,
    TestID   -> "ClearMCPInstallationRecord-NoMatchingRecords"
]

VerificationTest[
    withTemporaryRoot @ Module[ { name, result },
        name   = "ServerWithoutRecords";
        result = Wolfram`AgentTools`Common`clearMCPInstallationRecord[
            name,
            File @ FileNameJoin @ { $TemporaryDirectory, "configE.json" }
        ];
        { result, DirectoryQ @ Wolfram`AgentTools`Common`mcpServerDirectory @ name }
    ],
    { { }, False },
    SameTest -> Equal,
    TestID   -> "ClearMCPInstallationRecord-NoFile"
]

(* :!CodeAnalysis::EndBlock:: *)
