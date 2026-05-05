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
(* ::Subsection::Closed:: *)
(*$supportedMCPClients*)
$supportedMCPClients = <|
    "ClaudeDesktop" -> <|
        "DisplayName"     -> "Claude Desktop",
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
        "Aliases"         -> { },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://code.claude.com",
        "ProjectPath"     -> { ".mcp.json" },
        "InstallLocation" :> { $HomeDirectory, ".claude.json" }
    |>,
    "Cursor" -> <|
        "DisplayName"     -> "Cursor",
        "Aliases"         -> { },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://www.cursor.com",
        "InstallLocation" :> { $HomeDirectory, ".cursor", "mcp.json" }
    |>,
    "GeminiCLI" -> <|
        "DisplayName"     -> "Gemini CLI",
        "Aliases"         -> { "Gemini" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://github.com/google-gemini/gemini-cli",
        "InstallLocation" :> { $HomeDirectory, ".gemini", "settings.json" }
    |>,
    "Goose" -> <|
        "DisplayName"     -> "Goose",
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
    "Antigravity" -> <|
        "DisplayName"     -> "Antigravity",
        "Aliases"         -> { "GoogleAntigravity" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://antigravity.google",
        "InstallLocation" :> { $HomeDirectory, ".gemini", "antigravity", "mcp_config.json" }
    |>,
    "Codex" -> <|
        "DisplayName"     -> "Codex CLI",
        "Aliases"         -> { "OpenAICodex" },
        "ConfigFormat"    -> "TOML",
        "ConfigKey"       -> { "mcp_servers" },
        "ProjectPath"     -> { ".codex", "config.toml" },
        "URL"             -> "https://openai.com/codex",
        "InstallLocation" :> { $HomeDirectory, ".codex", "config.toml" }
    |>,
    "CopilotCLI" -> <|
        "DisplayName"     -> "Copilot CLI",
        "Aliases"         -> { "Copilot" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "ServerConverter" -> convertToCopilotCLIFormat,
        "URL"             -> "https://github.com/features/copilot/cli",
        "InstallLocation" :> { $HomeDirectory, ".copilot", "mcp-config.json" }
    |>,
    "Kiro" -> <|
        "DisplayName"     -> "Kiro",
        "Aliases"         -> { },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "ServerConverter" -> convertToClineFormat,
        "URL"             -> "https://kiro.dev",
        "ProjectPath"     -> { ".kiro", "settings", "mcp.json" },
        "InstallLocation" :> { $HomeDirectory, ".kiro", "settings", "mcp.json" }
    |>,
    "Junie" -> <|
        "DisplayName"     -> "Junie",
        "Aliases"         -> { },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://www.jetbrains.com/junie/",
        "ProjectPath"     -> { ".junie", "mcp", "mcp.json" },
        "InstallLocation" :> { $HomeDirectory, ".junie", "mcp", "mcp.json" }
    |>,
    "OpenCode" -> <|
        "DisplayName"     -> "OpenCode",
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
        "Aliases"         -> { "Codeium" },
        "ConfigFormat"    -> "JSON",
        "ConfigKey"       -> { "mcpServers" },
        "URL"             -> "https://codeium.com/windsurf",
        "InstallLocation" :> { $HomeDirectory, ".codeium", "windsurf", "mcp_config.json" }
    |>,
    "Cline" -> <|
        "DisplayName"     -> "Cline",
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
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $SupportedMCPClients;
    $aliasToCanonicalName;
];

End[ ];
EndPackage[ ];
