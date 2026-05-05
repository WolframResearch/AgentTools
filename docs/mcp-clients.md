# MCP Client Support in AgentTools

This document explains how AgentTools supports different MCP client applications and how to install MCP servers into them.

## Overview

AgentTools works with **any MCP client that supports the stdio server transport**. The server communicates via standard input/output using JSON-RPC messages, which is the most common transport mechanism for local MCP servers.

For convenience, `InstallMCPServer` and `UninstallMCPServer` functions are provided to automatically configure several popular client applications. These functions handle the different configuration file formats and locations used by each client.

## Clients with InstallMCPServer Support

The following clients have built-in support for automatic configuration via `InstallMCPServer`:

| Client | Canonical Name | Aliases | Config Format | Project Support |
|--------|---------------|---------|---------------|-----------------|
| Claude Code | `"ClaudeCode"` | — | JSON | Yes |
| Claude Desktop | `"ClaudeDesktop"` | `"Claude"` | JSON | No |
| Cline | `"Cline"` | — | JSON | No |
| Copilot CLI | `"CopilotCLI"` | `"Copilot"` | JSON | No |
| Cursor | `"Cursor"` | — | JSON | No |
| Gemini CLI | `"GeminiCLI"` | `"Gemini"` | JSON | No |
| Goose | `"Goose"` | — | YAML | No |
| Antigravity | `"Antigravity"` | `"GoogleAntigravity"` | JSON | No |
| Junie | `"Junie"` | — | JSON | Yes |
| Kiro | `"Kiro"` | — | JSON | Yes |
| Codex CLI | `"Codex"` | `"OpenAICodex"` | TOML | Yes |
| OpenCode | `"OpenCode"` | — | JSON | Yes |
| Visual Studio Code | `"VisualStudioCode"` | `"VSCode"` | JSON | Yes |
| Windsurf | `"Windsurf"` | `"Codeium"` | JSON | No |
| Zed | `"Zed"` | — | JSON | Yes |

## Usage

### Basic Installation

Install an MCP server into a client application:

```wl
InstallMCPServer["ClaudeDesktop"]
```

This installs the default MCP server into Claude Desktop's configuration file.

### Installing a Specific Server

```wl
InstallMCPServer["ClaudeCode", "WolframLanguage"]
```

### Project-Level Installation

For clients that support project-level configuration, use a `{name, directory}` specification:

```wl
InstallMCPServer[{"ClaudeCode", "/path/to/project"}]
```

This creates a `.mcp.json` file in the specified project directory.

### Installing to a Custom File

```wl
InstallMCPServer[File["/custom/path/config.json"]]
```

For TOML files (Codex), the format is auto-detected from the `.toml` extension. For YAML files (Goose), the format is auto-detected from the `.yaml` or `.yml` extension.

### Uninstalling

```wl
UninstallMCPServer["ClaudeDesktop"]              (* Remove all servers *)
UninstallMCPServer["ClaudeDesktop", "Wolfram"]   (* Remove specific server *)
UninstallMCPServer[myServerObject]               (* Remove from all locations *)
```

## Client Configuration Details

### Claude Desktop

| OS | Config Location |
|----|----------------|
| macOS | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Windows | `%APPDATA%\Claude\claude_desktop_config.json` |

**Format:**
```json
{
    "mcpServers": {
        "ServerName": {
            "command": "...",
            "args": ["..."],
            "env": { ... }
        }
    }
}
```

### Claude Code

| Scope | Config Location |
|-------|----------------|
| Global | `~/.claude.json` |
| Project | `.mcp.json` (in project root) |

**Format:** Same as Claude Desktop (`mcpServers` key).

### Cline

Cline stores its configuration in VS Code's extension global storage.

| OS | Config Location |
|----|----------------|
| macOS | `~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json` |
| Windows | `%APPDATA%\Code\User\globalStorage\saoudrizwan.claude-dev\settings\cline_mcp_settings.json` |
| Linux | `~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json` |

**Format:**
```json
{
    "mcpServers": {
        "ServerName": {
            "command": "...",
            "args": ["..."],
            "env": { ... },
            "disabled": false,
            "autoApprove": []
        }
    }
}
```

Note: Cline uses the standard `mcpServers` format with additional `disabled` and `autoApprove` fields. `InstallMCPServer` automatically adds these defaults.

### Copilot CLI

| Scope | Config Location |
|-------|----------------|
| Global | `~/.copilot/mcp-config.json` |

**Format:**
```json
{
    "mcpServers": {
        "ServerName": {
            "command": "...",
            "args": ["..."],
            "env": { ... },
            "tools": ["*"]
        }
    }
}
```

Note: Copilot CLI requires the `tools` field to specify which tools to enable. `InstallMCPServer` automatically adds `"tools": ["*"]` to enable all tools.

### Cursor

| Scope | Config Location |
|-------|----------------|
| Global | `~/.cursor/mcp.json` |

**Format:** Same as Claude Desktop (`mcpServers` key).

### Gemini CLI

| Scope | Config Location |
|-------|----------------|
| Global | `~/.gemini/settings.json` |

**Format:** Same as Claude Desktop (`mcpServers` key).

### Antigravity

| Scope | Config Location |
|-------|----------------|
| Global | `~/.gemini/antigravity/mcp_config.json` |

**Format:** Same as Claude Desktop (`mcpServers` key).

### Goose

| OS | Config Location |
|----|----------------|
| macOS | `~/.config/goose/config.yaml` |
| Linux | `~/.config/goose/config.yaml` |
| Windows | `%APPDATA%\Block\goose\config\config.yaml` |

**Format (YAML):**
```yaml
extensions:
  ServerName:
    name: ServerName
    cmd: "..."
    args: ["...", "..."]
    enabled: true
    envs:
      KEY: value
    type: stdio
    timeout: 300
```

Note: Goose uses YAML with an `extensions` key (not `mcpServers`) and renames several fields: `command` → `cmd`, `env` → `envs`. `InstallMCPServer` automatically adds the required `name`, `enabled: true`, `type: stdio`, and `timeout: 300` fields. Goose has no project-level configuration.

### Junie

| Scope | Config Location |
|-------|----------------|
| Global | `~/.junie/mcp/mcp.json` |
| Project | `.junie/mcp/mcp.json` (in project root) |

**Format:** Same as Claude Desktop (`mcpServers` key).

Note: Junie is JetBrains' AI coding agent for IntelliJ-family IDEs (IntelliJ IDEA, PyCharm, WebStorm, GoLand, PhpStorm, RubyMine, RustRover, Rider) and the Junie CLI. The same configuration file is shared across all JetBrains IDEs and the standalone CLI.

### Kiro

| Scope | Config Location |
|-------|----------------|
| Global | `~/.kiro/settings/mcp.json` |
| Project | `.kiro/settings/mcp.json` (in project root) |

**Format:**
```json
{
    "mcpServers": {
        "ServerName": {
            "command": "...",
            "args": ["..."],
            "env": { ... },
            "disabled": false,
            "autoApprove": []
        }
    }
}
```

Note: Kiro uses the standard `mcpServers` format with optional `disabled` and `autoApprove` fields. `InstallMCPServer` automatically adds these defaults.

### Codex CLI

| Scope | Config Location |
|-------|----------------|
| Global | `~/.codex/config.toml` |
| Project | `.codex/config.toml` (in project root) |

**Format (TOML):**
```toml
[mcp_servers.ServerName]
command = "..."
args = ["..."]
enabled = true

[mcp_servers.ServerName.env]
KEY = "value"
```

Note: Project-level Codex configuration is stored in `.codex/config.toml`. This lets `InstallMCPServer[{"Codex", "/path/to/project"}]` install a server for just that project.

### OpenCode

| Scope | Config Location |
|-------|----------------|
| Global | `~/.config/opencode/opencode.json` |
| Project | `opencode.json` (in project root) |

**Format:**
```json
{
    "mcp": {
        "ServerName": {
            "type": "local",
            "command": ["...", "arg1", "arg2"],
            "enabled": true,
            "environment": { ... }
        }
    }
}
```

Note: OpenCode uses a different format where the command and args are combined into a single `command` array.

### Visual Studio Code

| OS | Config Location |
|----|----------------|
| macOS | `~/Library/Application Support/Code/User/mcp.json` |
| Windows | `%APPDATA%\Code\User\mcp.json` |
| Linux | `~/.config/Code/User/mcp.json` |
| Project | `.vscode/mcp.json` |

**Format:**
```json
{
    "servers": {
        "ServerName": {
            "command": "...",
            "args": ["..."],
            "env": { ... }
        }
    }
}
```

Note: VS Code uses a dedicated `mcp.json` file with `servers` at the root level.

### Windsurf

| OS | Config Location |
|----|----------------|
| macOS/Linux | `~/.codeium/windsurf/mcp_config.json` |
| Windows | `%USERPROFILE%\.codeium\windsurf\mcp_config.json` |

**Format:** Same as Claude Desktop (`mcpServers` key).

### Zed

| Scope | Config Location |
|-------|----------------|
| Global (macOS/Linux) | `~/.config/zed/settings.json` |
| Global (Windows) | `%APPDATA%\Zed\settings.json` |
| Project | `.zed/settings.json` |

**Format:**
```json
{
    "context_servers": {
        "ServerName": {
            "command": "...",
            "args": ["..."],
            "env": { ... }
        }
    }
}
```

Note: Zed uses `context_servers` instead of `mcpServers`. The inner server entry format is the same as Claude Desktop.

## Using Other MCP Clients

AgentTools can be used with any MCP client that supports the stdio transport. If your client is not listed above, you can manually configure it using the server's command, arguments, and environment variables.

### Server Configuration

The basic configuration requires:

| Field | Value |
|-------|-------|
| Command | `/full/path/to/wolfram` (or `wolfram.exe` on Windows) |
| Arguments | ``-run PacletSymbol["Wolfram/AgentTools","StartMCPServer"][] -noinit -noprompt`` |

### Environment Variables

Include these environment variables for proper operation:

| Variable | Description |
|----------|-------------|
| `MCP_SERVER_NAME` | Name of the MCP server to run (e.g. `"WolframLanguage"`, optional) |
| `WOLFRAM_BASE` | Path to Wolfram base directory (`$BaseDirectory`) |
| `WOLFRAM_USERBASE` | Path to user's Wolfram files (`$UserBaseDirectory`) |
| `APPDATA` | (Windows only) Path to application data (typically `ParentDirectory[$UserBaseDirectory]`) |
| `MCP_APPS_ENABLED` | Set to `"false"` to disable [MCP Apps](mcp-apps.md) UI resources (optional) |
| `MCP_TOOL_OPTIONS` | JSON string of tool option overrides, set automatically by `"ToolOptions"` (optional) |

### Getting the Configuration

You can generate the JSON configuration for manual use:

```wl
MCPServerObject["Wolfram"]["JSONConfiguration"]
```

This returns a JSON string with the complete server configuration that you can adapt to your client's format.

### Setup Instructions

For clients not listed here, consult the [MCP documentation](https://modelcontextprotocol.io/) or your client's documentation for instructions on configuring stdio-based MCP servers.

## Options

### DevelopmentMode

Controls how the MCP server is started:

| Value | Behavior |
|-------|----------|
| `False` (default) | Uses the installed paclet via `PacletSymbol` |
| `True` | Uses `Scripts/StartMCPServer.wls` from the current paclet location |
| `"path/to/directory"` | Uses `Scripts/StartMCPServer.wls` from the specified directory |

This is useful for testing local changes without reinstalling the paclet:

```wl
InstallMCPServer["ClaudeCode", "DevelopmentMode" -> True]
```

### ProcessEnvironment

Specifies additional environment variables to include in the configuration:

```wl
InstallMCPServer["ClaudeCode", ProcessEnvironment -> <|"MY_VAR" -> "value"|>]
```

By default, `InstallMCPServer` includes:
- `MCP_SERVER_NAME`
- `WOLFRAM_BASE`
- `WOLFRAM_USERBASE`
- `APPDATA` (Windows only)

### EnableMCPApps

Controls whether [MCP Apps](mcp-apps.md) UI resources are enabled for the installed server:

| Value | Behavior |
|-------|----------|
| `True` (default) | MCP Apps are enabled; the server will negotiate UI support with compatible clients |
| `False` | MCP Apps are disabled; sets `MCP_APPS_ENABLED=false` in the server environment |

```wl
InstallMCPServer["ClaudeDesktop", "EnableMCPApps" -> False]
```

### MCPServerName

Controls the key used for the server entry in the client's configuration file:

| Value | Behavior |
|-------|----------|
| `Automatic` (default) | Uses the server's `"MCPServerName"` property if set, otherwise falls back to `"Name"` |
| `"CustomName"` | Uses the specified string as the config key |

All built-in servers (`Wolfram`, `WolframAlpha`, `WolframLanguage`, `WolframPacletDevelopment`) share the config key `"Wolfram"` by default. This means installing one built-in server variant replaces any previously installed built-in variant in the same client — they are mutually exclusive configurations of the same Wolfram MCP server.

To install multiple built-in servers side by side, override the config key:

```wl
InstallMCPServer["ClaudeDesktop", "Wolfram", "MCPServerName" -> "WolframBasic"]
InstallMCPServer["ClaudeDesktop", "WolframLanguage", "MCPServerName" -> "WolframDev"]
```

User-created servers are unaffected — they continue to use their `"Name"` as the config key.

This option works with both `InstallMCPServer` and `UninstallMCPServer`. When uninstalling, use the same `"MCPServerName"` override that was used at install time:

```wl
(* Uninstall the "WolframDev" entry that was installed with a custom name *)
UninstallMCPServer["ClaudeDesktop", "WolframLanguage", "MCPServerName" -> "WolframDev"]
```

### ToolOptions

Customizes the behavior of built-in MCP tools at install time. The value is an association mapping tool names to their option overrides:

```wl
InstallMCPServer["ClaudeCode", "WolframLanguage",
    "ToolOptions" -> <|
        "WolframLanguageEvaluator" -> <|"Method" -> "Local", "TimeConstraint" -> 120|>,
        "WolframLanguageContext"   -> <|"MaxItems" -> 20|>
    |>
]
```

Options are serialized to the `MCP_TOOL_OPTIONS` environment variable and read by the server at startup. See [tools.md](tools.md#tool-options) for the full list of per-tool options.

Unrecognized tool names or option names generate warnings but do not prevent installation (for forward compatibility).

### VerifyLLMKit

Controls whether to check LLMKit subscription requirements:

| Value | Behavior |
|-------|----------|
| `True` (default) | Warns or errors if tools require LLMKit subscription |
| `False` | Skips the LLMKit check |

### ApplicationName

Specifies which MCP client the configuration file belongs to:

| Value | Behavior |
|-------|----------|
| `Automatic` (default) | Auto-detects the client from the file path or content |
| `"ClientName"` | Explicitly specifies the target client |

This option works with both `InstallMCPServer` and `UninstallMCPServer`. It is useful when installing to a `File[...]` target where the client cannot be auto-detected from the path:

```wl
InstallMCPServer[File["config.json"], "ApplicationName" -> "Cline"]
UninstallMCPServer[File["config.json"], "ApplicationName" -> "Cline"]
```

## Querying Supported Clients

The public variable `$SupportedMCPClients` provides an association of all supported client metadata. It can be used to programmatically query which clients are supported and inspect their configuration details.

```wl
(* List all supported client names *)
Keys[$SupportedMCPClients]
(* {"Antigravity", "ClaudeCode", "ClaudeDesktop", "Cline", "Codex", ...} *)

(* Get metadata for a specific client *)
$SupportedMCPClients["ClaudeDesktop"]
(* <|"Aliases" -> {"Claude"}, "ConfigFormat" -> "JSON", "ConfigKey" -> {"mcpServers"}, ...|> *)
```

## Adding Support for New Clients

All client configuration is centralized in `$supportedMCPClients` in `Kernel/SupportedClients.wl`. To add support for a new MCP client, add an entry to this association.

### Client Entry Structure

Each entry is keyed by the canonical client name and contains an association with the following fields:

| Field | Required | Description |
|-------|----------|-------------|
| `"DisplayName"` | Yes | Human-readable name shown to users |
| `"Aliases"` | Yes | List of alternative names (can be empty `{ }`) |
| `"ConfigFormat"` | Yes | File format: `"JSON"`, `"TOML"`, or `"YAML"` |
| `"ConfigKey"` | Yes | Key path to the servers section (e.g. `{"mcpServers"}` or `{"servers"}`) |
| `"URL"` | Yes | Client's website or download page |
| `"InstallLocation"` | Yes | Config file path(s) per OS (see below) |
| `"ProjectPath"` | No | Relative path components for project-level config |
| `"ServerConverter"` | No | Function to transform the standard server entry into a client-specific format |

### Example Entry

```wl
"NewClient" -> <|
    "DisplayName"     -> "New Client",
    "Aliases"         -> { "NC" },
    "ConfigFormat"    -> "JSON",
    "ConfigKey"       -> { "mcpServers" },
    "URL"             -> "https://newclient.example.com",
    "ProjectPath"     -> { ".newclient.json" },
    "InstallLocation" -> <|
        "MacOSX"  :> { $HomeDirectory, ".newclient", "config.json" },
        "Windows" :> { $HomeDirectory, "AppData", "Roaming", "NewClient", "config.json" },
        "Unix"    :> { $HomeDirectory, ".config", "newclient", "config.json" }
    |>
|>
```

If the install location is the same on all platforms, use a single `RuleDelayed` instead of a per-OS association:

```wl
"InstallLocation" :> { $HomeDirectory, ".newclient", "config.json" }
```

### Custom Server Converters

If the client uses a non-standard server entry format, provide a `"ServerConverter"` function. This function receives a standard server association (with `"command"`, `"args"`, `"env"` keys) and should return the client-specific format. For example, Cline adds `"disabled"` and `"autoApprove"` fields:

```wl
convertToClineFormat[ server_Association ] := Enclose[
    Module[ { result },
        result = ConfirmBy[ server, AssociationQ, "Server" ];
        result[ "disabled" ] = False;
        result[ "autoApprove" ] = { };
        result
    ],
    throwInternalFailure
];
```

## Related Files

- `Kernel/SupportedClients.wl` - Supported MCP client definitions and format converters
- `Kernel/InstallMCPServer.wl` - Installation and uninstallation implementation
- `Kernel/DeployAgentTools.wl` - Managed deployment of agent tools (see [deploy-agent-tools.md](deploy-agent-tools.md))
- `Kernel/CreateMCPServer.wl` - Server creation and JSON configuration generation
- `Kernel/MCPServerObject.wl` - Server object structure
