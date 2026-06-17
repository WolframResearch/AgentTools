(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`SupportedClients`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$SupportedMCPClients*)
$SupportedMCPClients := WithCleanup[
    Unprotect @ $SupportedMCPClients,
    $SupportedMCPClients = KeySort @ AssociationMap[ clientMetadata, Keys @ $supportedMCPClients ],
    Protect @ $SupportedMCPClients
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DetectedMCPClients*)
DetectedMCPClients // beginDefinition;

DetectedMCPClients[ ] :=
    catchMine @ KeySelect[
        $SupportedMCPClients,
        Quiet @ FileExistsQ @ catchAlways @ installLocation[ # ] &
    ];

DetectedMCPClients // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$supportedMCPClients*)
$supportedMCPClients = <|
    "ClaudeDesktop" -> <|
        "DisplayName"     -> "Claude Desktop",
        "DefaultToolset"  -> "Wolfram",
        "Aliases"         -> { "Claude" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://claude.ai/download",
        "InstallLocation" -> <|
            "MacOSX"  :> { $HomeDirectory, "Library", "Application Support", "Claude", "claude_desktop_config.json" },
            "Windows" :> { $HomeDirectory, "AppData", "Roaming", "Claude", "claude_desktop_config.json" }
        |>
    |>,
    "ClaudeCode" -> <|
        "DisplayName"     -> "Claude Code",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://code.claude.com",
        "ProjectPath"     -> { ".mcp.json" },
        "InstallLocation" :> { $HomeDirectory, ".claude.json" }
    |>,
    "Cursor" -> <|
        "DisplayName"     -> "Cursor",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://www.cursor.com",
        "InstallLocation" :> { $HomeDirectory, ".cursor", "mcp.json" }
    |>,
    "GeminiCLI" -> <|
        "DisplayName"     -> "Gemini CLI",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { "Gemini" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://github.com/google-gemini/gemini-cli",
        "InstallLocation" :> { $HomeDirectory, ".gemini", "settings.json" }
    |>,
    "Goose" -> <|
        "DisplayName"     -> "Goose",
        "DefaultToolset"  -> "Wolfram",
        "Aliases"         -> { },
        "ConfigFormat"    -> "YAML",
        "ConfigKey"       -> { "extensions" },
        "URL"             -> "https://block.github.io/goose/",
        "InstallLocation" -> <|
            "MacOSX"  :> { $HomeDirectory, ".config", "goose", "config.yaml" },
            "Unix"    :> { $HomeDirectory, ".config", "goose", "config.yaml" },
            "Windows" :> { $HomeDirectory, "AppData", "Roaming", "Block", "goose", "config", "config.yaml" }
        |>
    |>,
    (* A single entry covers the Antigravity IDE, the Antigravity 2.0 desktop app, AND the
       Antigravity CLI. They share one global MCP config file, so they MUST be one client
       entry rather than two: two entries pointing at the same file would let
       DeployAgentTools create two deployments for one file and let
       DeleteObject[AgentToolsDeployment[...]] corrupt shared state. "AntigravityCLI" /
       "GoogleAntigravityCLI" are therefore aliases, not separate clients.

       Global path (antigravityInstallLocation): Antigravity 2.0 reads
       ~/.gemini/config/mcp_config.json once a pre-2.0 install has migrated forward (the
       installer drops a ~/.gemini/config/.migrated marker; ~/.gemini/config/ is the shared
       per-user Antigravity dir). Pre-migration installs use the historical
       ~/.gemini/antigravity/mcp_config.json. The CLI reads the same migrated
       ~/.gemini/config/mcp_config.json (per the official gcli-migration guide); the
       ~/.gemini/antigravity-cli/ dir holds CLI skills/cache/settings only, NOT mcp_config.

       Workspace path (ProjectPath): the CLI reads project-scoped servers from
       .agents/mcp_config.json, so InstallMCPServer[{"Antigravity"|"AntigravityCLI", dir}]
       writes there. *)
    "Antigravity" -> <|
        "DisplayName"     -> "Antigravity",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { "GoogleAntigravity", "AntigravityCLI", "GoogleAntigravityCLI" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://antigravity.google",
        "ProjectPath"     -> { ".agents", "mcp_config.json" },
        "InstallLocation" :> antigravityInstallLocation[ ]
    |>,
    "AugmentCode" -> <|
        "DisplayName"     -> "Augment Code",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { "Auggie", "Augment" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "ServerConverter" -> convertToAugmentCodeFormat,
        "URL"             -> "https://www.augmentcode.com",
        "InstallLocation" :> { $HomeDirectory, ".augment", "settings.json" }
    |>,
    "AugmentCodeIDE" -> <|
        "DisplayName"     -> "Augment Code IDE",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { "AugmentIDE", "AuggieIDE" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { },
        "ServerConverter" -> convertToAugmentCodeIDEFormat,
        "URL"             -> "https://marketplace.visualstudio.com/items?itemName=augment.vscode-augment",
        "InstallLocation" -> <|
            "MacOSX"  :> { $HomeDirectory, "Library", "Application Support", "Code", "User", "globalStorage",
                           "augment.vscode-augment", "augment-global-state", "mcpServers.json" },
            "Windows" :> { $HomeDirectory, "AppData", "Roaming", "Code", "User", "globalStorage",
                           "augment.vscode-augment", "augment-global-state", "mcpServers.json" },
            "Unix"    :> { $HomeDirectory, ".config", "Code", "User", "globalStorage",
                           "augment.vscode-augment", "augment-global-state", "mcpServers.json" }
        |>
    |>,
    "Codex" -> <|
        "DisplayName"     -> "Codex CLI",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { "OpenAICodex" },
        "ConfigFormat"    -> "TOML",
        "ConfigKey"       -> { "mcp_servers" },
        "ProjectPath"     -> { ".codex", "config.toml" },
        "URL"             -> "https://openai.com/codex",
        "InstallLocation" :> { $HomeDirectory, ".codex", "config.toml" }
    |>,
    "CopilotCLI" -> <|
        "DisplayName"     -> "Copilot CLI",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { "Copilot" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "ServerConverter" -> convertToCopilotCLIFormat,
        "URL"             -> "https://github.com/features/copilot/cli",
        "InstallLocation" :> { $HomeDirectory, ".copilot", "mcp-config.json" }
    |>,
    "Junie" -> <|
        "DisplayName"     -> "Junie",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { "JetBrainsJunie" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://www.jetbrains.com/junie/",
        "ProjectPath"     -> { ".junie", "mcp", "mcp.json" },
        "InstallLocation" :> { $HomeDirectory, ".junie", "mcp", "mcp.json" }
    |>,
    "Kiro" -> <|
        "DisplayName"     -> "Kiro",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "ServerConverter" -> convertToClineFormat,
        "URL"             -> "https://kiro.dev",
        "ProjectPath"     -> { ".kiro", "settings", "mcp.json" },
        "InstallLocation" :> { $HomeDirectory, ".kiro", "settings", "mcp.json" }
    |>,
    "OpenCode" -> <|
        "DisplayName"     -> "OpenCode",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcp" },
        "ServerConverter" -> convertToOpenCodeFormat,
        "URL"             -> "https://opencode.ai",
        "ProjectPath"     -> { "opencode.json" },
        "InstallLocation" :> { $HomeDirectory, ".config", "opencode", "opencode.json" }
    |>,
    "VisualStudioCode" -> <|
        "DisplayName"     -> "Visual Studio Code",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { "VSCode" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "servers" },
        "URL"             -> "https://code.visualstudio.com",
        "ProjectPath"     -> { ".vscode", "mcp.json" },
        "InstallLocation" -> <|
            "MacOSX"  :> { $HomeDirectory, "Library", "Application Support", "Code", "User", "mcp.json" },
            "Windows" :> { $HomeDirectory, "AppData", "Roaming", "Code", "User", "mcp.json" },
            "Unix"    :> { $HomeDirectory, ".config", "Code", "User", "mcp.json" }
        |>
    |>,
    "Windsurf" -> <|
        "DisplayName"     -> "Windsurf",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { "Codeium" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://codeium.com/windsurf",
        "InstallLocation" :> { $HomeDirectory, ".codeium", "windsurf", "mcp_config.json" }
    |>,
    "AmazonQ" -> <|
        "DisplayName"     -> "Amazon Q Developer",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { "AmazonQDeveloper", "Q", "QDeveloper" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://aws.amazon.com/q/developer/",
        "ProjectPath"     -> { ".amazonq", "mcp.json" },
        "InstallLocation" :> { $HomeDirectory, ".aws", "amazonq", "mcp.json" }
    |>,
    "Cline" -> <|
        "DisplayName"     -> "Cline",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "ServerConverter" -> convertToClineFormat,
        "URL"             -> "https://cline.bot",
        "InstallLocation" -> <|
            "MacOSX"  :> { $HomeDirectory, "Library", "Application Support", "Code", "User", "globalStorage",
                           "saoudrizwan.claude-dev", "settings", "cline_mcp_settings.json" },
            "Windows" :> { $HomeDirectory, "AppData", "Roaming", "Code", "User", "globalStorage",
                           "saoudrizwan.claude-dev", "settings", "cline_mcp_settings.json" },
            "Unix"    :> { $HomeDirectory, ".config", "Code", "User", "globalStorage", "saoudrizwan.claude-dev",
                           "settings", "cline_mcp_settings.json" }
        |>
    |>,
    "Zed" -> <|
        "DisplayName"     -> "Zed",
        "DefaultToolset"  -> "WolframLanguage",
        "Aliases"         -> { },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "context_servers" },
        "URL"             -> "https://zed.dev",
        "ProjectPath"     -> { ".zed", "settings.json" },
        "InstallLocation" -> <|
            "MacOSX"  :> { $HomeDirectory, ".config", "zed", "settings.json" },
            "Windows" :> { $HomeDirectory, "AppData", "Roaming", "Zed", "settings.json" },
            "Unix"    :> { $HomeDirectory, ".config", "zed", "settings.json" }
        |>
    |>
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*clientMetadata*)
clientMetadata // beginDefinition;

clientMetadata[ name_String ] := Enclose[
    Module[ { data, projectSupport, converter },
        data = ConfirmBy[ $supportedMCPClients @ name, AssociationQ, "Data" ];
        projectSupport = MatchQ[ data[ "ProjectPath" ], { __String } ];
        converter = Lookup[ data, "ServerConverter", Identity ];
        KeySort @ <|
            data,
            "Name"            -> name,
            "ProjectSupport"  -> projectSupport,
            "ServerConverter" -> converter
        |>
    ],
    throwInternalFailure
];

clientMetadata // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$aliasToCanonicalName*)
$aliasToCanonicalName := $aliasToCanonicalName = Association @ Flatten @ KeyValueMap[
    Function[ { name, meta }, Thread[ meta[ "Aliases" ] -> name ] ],
    $supportedMCPClients
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*defaultToolsetForTarget*)
defaultToolsetForTarget // beginDefinition;

defaultToolsetForTarget[ name_String ] :=
    Replace[
        Lookup[
            Lookup[ $supportedMCPClients, toInstallName @ name, <| |> ],
            "DefaultToolset",
            $defaultMCPServer
        ],
        Except[ _String ] :> $defaultMCPServer
    ];

defaultToolsetForTarget[ { name_String, _ } ] :=
    defaultToolsetForTarget @ name;

defaultToolsetForTarget[ file_? fileQ ] := Enclose[
    defaultToolsetForTarget @ ConfirmBy[ guessClientName @ file, StringQ, "Guess" ],
    $defaultMCPServer &
];

defaultToolsetForTarget[ _ ] := $defaultMCPServer;

(* 2-arg form: an explicit ApplicationName takes precedence over target-based
   resolution.  This lets callers like `InstallMCPServer[File[...], Automatic,
   "ApplicationName" -> "Cline"]` pick up Cline's `DefaultToolset` even when the
   file path doesn't reveal the client. *)
defaultToolsetForTarget[ _, name_String ] := defaultToolsetForTarget @ name;
defaultToolsetForTarget[ target_, _ ]     := defaultToolsetForTarget @ target;

defaultToolsetForTarget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Install Location Helpers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*antigravityInstallLocation*)
(* See the rationale in the "Antigravity" entry of $supportedMCPClients: when the 2.0
   installer migrates a pre-2.0 IDE forward, it drops a `.migrated` marker into
   ~/.gemini/config/ and the IDE switches to reading ~/.gemini/config/mcp_config.json
   instead of the historical ~/.gemini/antigravity/mcp_config.json. Fresh 2.0 installs
   that never went through migration keep the historical path. This helper is called
   each time installLocation["Antigravity"] is evaluated, so the decision adapts if the
   user later migrates between machines or reinstalls. *)
antigravityInstallLocation // beginDefinition;

antigravityInstallLocation[ ] := If[
    FileExistsQ @ FileNameJoin @ { $HomeDirectory, ".gemini", "config", ".migrated" },
    { $HomeDirectory, ".gemini", "config", "mcp_config.json" },
    { $HomeDirectory, ".gemini", "antigravity", "mcp_config.json" }
];

antigravityInstallLocation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Converter Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertToOpenCodeFormat*)
convertToOpenCodeFormat // beginDefinition;

convertToOpenCodeFormat[ server_Association ] := Enclose[
    Module[ { command, args, env, result },
        command = ConfirmMatch[ Lookup[ server, "command", Missing[ ] ], _String | _Missing, "Command" ];
        args = Lookup[ server, "args", { } ];
        env = Lookup[ server, "env", <| |> ];

        result = <|
            "type" -> "local",
            "command" -> If[ command === Missing[ ], { }, Prepend[ args, command ] ],
            "enabled" -> True
        |>;

        If[ AssociationQ @ env && Length @ env > 0,
            result[ "environment" ] = env
        ];

        result
    ],
    throwInternalFailure
];

convertToOpenCodeFormat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertToCopilotCLIFormat*)
convertToCopilotCLIFormat // beginDefinition;

convertToCopilotCLIFormat[ server_Association ] := Enclose[
    Module[ { result },
        result = ConfirmBy[ server, AssociationQ, "Server" ];
        result[ "tools" ] = { "*" };
        result
    ],
    throwInternalFailure
];

convertToCopilotCLIFormat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertToClineFormat*)
convertToClineFormat // beginDefinition;

convertToClineFormat[ server_Association ] := Enclose[
    Module[ { result },
        result = ConfirmBy[ server, AssociationQ, "Server" ];
        result[ "disabled" ] = False;
        result[ "autoApprove" ] = { };
        result
    ],
    throwInternalFailure
];

convertToClineFormat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertToAugmentCodeFormat*)
(* Augment Code's CLI shell-invokes the MCP command on Windows, which breaks when the
   wolfram.exe path contains spaces (e.g. "C:\Program Files\..."). Coerce the command to
   its 8.3 short-path form on Windows so the unquoted shell invocation resolves correctly. *)
convertToAugmentCodeFormat // beginDefinition;

convertToAugmentCodeFormat[ server_Association ] :=
    convertToAugmentCodeFormat[ server, $OperatingSystem ];

convertToAugmentCodeFormat[ server_Association, os_String ] := Enclose[
    Module[ { result, command, shortCommand },
        result = ConfirmBy[ server, AssociationQ, "Server" ];
        If[ os === "Windows",
            command = Lookup[ result, "command", Missing[ ] ];
            If[ StringQ @ command && StringContainsQ[ command, " " ],
                shortCommand = toWindowsShortPath @ command;
                If[ StringQ @ shortCommand && shortCommand =!= command,
                    result[ "command" ] = shortCommand
                ]
            ]
        ];
        result
    ],
    throwInternalFailure
];

convertToAugmentCodeFormat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertToAugmentCodeIDEFormat*)
(* The Augment Code VS Code extension stores MCP servers as a flat JSON array at the
   root of its settings file (mcpServers.json), not as a keyed dict under "mcpServers".
   Each entry carries a "type" field and its own "name". This converter maps the
   standard mcpServers entry shape to the array-entry shape; the caller is responsible
   for prepending the "name" field after conversion (the converter does not know the
   configName). Applies the same Windows short-path coercion as the CLI variant, because
   the extension shell-invokes commands too. *)
convertToAugmentCodeIDEFormat // beginDefinition;

convertToAugmentCodeIDEFormat[ server_Association ] :=
    convertToAugmentCodeIDEFormat[ server, $OperatingSystem ];

convertToAugmentCodeIDEFormat[ server_Association, os_String ] := Enclose[
    Module[ { command, args, env, result },
        result = <| "type" -> "stdio" |>;

        command = Lookup[ server, "command", Missing[ ] ];
        If[ StringQ @ command,
            If[ os === "Windows" && StringContainsQ[ command, " " ],
                result[ "command" ] = toWindowsShortPath @ command,
                result[ "command" ] = command
            ]
        ];

        args = Lookup[ server, "args", { } ];
        If[ ListQ @ args && Length @ args > 0,
            result[ "args" ] = args
        ];

        env = Lookup[ server, "env", <| |> ];
        If[ AssociationQ @ env && Length @ env > 0,
            result[ "env" ] = env
        ];

        result
    ],
    throwInternalFailure
];

convertToAugmentCodeIDEFormat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toWindowsShortPath*)
(* Resolve a Windows path to its 8.3 short form. *)
toWindowsShortPath // beginDefinition;

toWindowsShortPath[ path_String ] := Enclose[
    Catch @ Module[ { short, escaped, out },
        If[ ! FileExistsQ @ path, Throw @ path ];

        (* Get the 8.3 short path from the file information *)
        short = Quiet @ Information[ File @ path, "AbsoluteShortFileName" ];
        If[ StringQ @ short && FileExistsQ @ short && StringFreeQ[ short, " " ], Throw @ short ];

        (* If that fails, try using the PowerShell COM interface to get the short path *)
        escaped = StringReplace[ path, "'" -> "''" ];
        out = Quiet @ RunProcess[
            {
                $powerShell,
                "-NoProfile",
                "-Command",
                "(New-Object -ComObject Scripting.FileSystemObject).GetFile('" <> escaped <> "').ShortPath"
            },
            "StandardOutput"
        ];
        If[ ! StringQ @ out, Throw @ path ];

        short = StringTrim @ out;

        If[ StringQ @ short && FileExistsQ @ short && StringFreeQ[ short, " " ],
            short,
            path
        ]
    ],
    throwInternalFailure
];

toWindowsShortPath // endDefinition;


$powerShell := $powerShell = Quiet @ SelectFirst[
    {
        FileNameJoin @ { Environment[ "SystemRoot" ], "System32", "WindowsPowerShell", "v1.0", "powershell.exe" },
        "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
    },
    FileExistsQ,
    "powershell.exe" (* Note: for some reason "powershell" isn't found by RunProcess, but "powershell.exe" is. *)
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $SupportedMCPClients;
    $aliasToCanonicalName;
];

End[ ];
EndPackage[ ];
