# MCP Client Support in AgentTools

This document explains how AgentTools supports different MCP client applications and how to install MCP servers into them.

## Overview

AgentTools works with **any MCP client that supports the stdio server transport**. The server communicates via standard input/output using JSON-RPC messages, which is the most common transport mechanism for local MCP servers.

For convenience, `InstallMCPServer` and `UninstallMCPServer` functions are provided to automatically configure several popular client applications. These functions handle the different configuration file formats and locations used by each client.

## Clients with InstallMCPServer Support

The following clients have built-in support for automatic configuration via `InstallMCPServer`:

| Client | Canonical Name | Aliases | Config Format | Project Support | Default Toolset |
|--------|---------------|---------|---------------|-----------------|-----------------|
| Amazon Q Developer | `"AmazonQ"` | `"AmazonQDeveloper"`, `"Q"`, `"QDeveloper"` | JSON | Yes | `"WolframLanguage"` |
| Augment Code | `"AugmentCode"` | `"Auggie"`, `"Augment"` | JSON | No | `"WolframLanguage"` |
| Augment Code IDE | `"AugmentCodeIDE"` | `"AugmentIDE"`, `"AuggieIDE"` | JSON (array) | No | `"WolframLanguage"` |
| Claude Code | `"ClaudeCode"` | — | JSON | Yes | `"WolframLanguage"` |
| Claude Desktop | `"ClaudeDesktop"` | `"Claude"` | JSON | No | `"Wolfram"` |
| Cline | `"Cline"` | — | JSON | No | `"WolframLanguage"` |
| Continue | `"Continue"` | — | YAML | Yes | `"WolframLanguage"` |
| Copilot CLI | `"CopilotCLI"` | `"Copilot"` | JSON | No | `"WolframLanguage"` |
| Cursor | `"Cursor"` | — | JSON | No | `"WolframLanguage"` |
| Gemini CLI | `"GeminiCLI"` | `"Gemini"` | JSON | No | `"WolframLanguage"` |
| Goose | `"Goose"` | — | YAML | No | `"Wolfram"` |
| Antigravity (IDE, desktop + CLI) | `"Antigravity"` | `"GoogleAntigravity"`, `"AntigravityCLI"`, `"GoogleAntigravityCLI"` | JSON | Yes | `"WolframLanguage"` |
| Junie (IDE + CLI) | `"Junie"` | `"JetBrainsJunie"` | JSON | Yes | `"WolframLanguage"` |
| Kiro | `"Kiro"` | — | JSON | Yes | `"WolframLanguage"` |
| Codex CLI | `"Codex"` | `"OpenAICodex"` | TOML | Yes | `"WolframLanguage"` |
| OpenCode | `"OpenCode"` | — | JSON | Yes | `"WolframLanguage"` |
| Visual Studio Code | `"VisualStudioCode"` | `"VSCode"` | JSON | Yes | `"WolframLanguage"` |
| Windsurf | `"Windsurf"` | `"Codeium"` | JSON | No | `"WolframLanguage"` |
| Zed | `"Zed"` | — | JSON | Yes | `"WolframLanguage"` |

The **Default Toolset** is the [predefined server](servers.md) used when `InstallMCPServer`/`DeployAgentTools` is called without an explicit server (or with `Automatic`). Coding clients default to `"WolframLanguage"`; chat clients (Claude Desktop, Goose) default to `"Wolfram"`.

## Usage

### Basic Installation

Install an MCP server into a client application:

```wl
InstallMCPServer["ClaudeDesktop"]
```

This installs the client's default toolset into Claude Desktop's configuration file. Each client has its own default — Claude Desktop and Goose default to `"Wolfram"`; coding clients (Claude Code, Cursor, VS Code, etc.) default to `"WolframLanguage"`. Pass `Automatic` explicitly for the same behavior, or pass a server name to override (see the table above for each client's default).

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

### Amazon Q Developer

| Scope | Config Location |
|-------|----------------|
| Global | `~/.aws/amazonq/mcp.json` |
| Project | `.amazonq/mcp.json` (in project root) |

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

Amazon Q Developer supports an optional `timeout` field (milliseconds, default 120000) per server entry. `InstallMCPServer` does not emit `timeout`; Amazon Q uses its default when absent. Runtime fields like `disabled` and per-tool auto-approve are managed through the Amazon Q IDE UI, not in `mcp.json`.

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

### Continue

| Scope | Config Location |
|-------|----------------|
| Global | `~/.continue/config.yaml` |
| Project | `<project>/.continue/mcpServers/wolfram.yaml` |

**Format (global `config.yaml` — YAML with `mcpServers` as an array, alongside the user's other top-level Continue config; the `name` / `version` / `schema` fields are required by Continue at the top level of every config.yaml):**
```yaml
name: Local Config
version: 1.0.0
schema: v1
mcpServers:
  - name: WolframLanguage
    command: wolfram
    args:
      - "-run"
      - 'PacletSymbol["Wolfram/AgentTools","Wolfram`AgentTools`StartMCPServer"][]'
      - "-noinit"
      - "-noprompt"
    env:
      MCP_SERVER_NAME: WolframLanguage
```

**Format (project `.continue/mcpServers/wolfram.yaml` — standalone block file with required top-level metadata):**
```yaml
name: Wolfram
version: 1.0.0
schema: v1
mcpServers:
  - name: WolframLanguage
    command: wolfram
    args: ["-run", "...", "-noinit", "-noprompt"]
    env:
      MCP_SERVER_NAME: WolframLanguage
```

Notes:
- Continue stores MCP servers as a **JSON/YAML array** under the top-level `mcpServers` key (not as a keyed object like Claude Desktop). Each entry carries its own `name` field, which `InstallMCPServer` uses as the upsert/delete key.
- Continue requires `name`, `version`, and `schema` at the top level of **every** `config.yaml` (and every standalone block file in `.continue/mcpServers/`). `InstallMCPServer` adds these fields with sensible defaults (`name: "Local Config"` for the global file, `name: "Wolfram"` for the project block file; `version: "1.0.0"`; `schema: "v1"`) when they aren't already present, and **never overwrites a user-chosen `name`**. Without these fields Continue's CLI and IDE plugin silently reject the file and fall back to "Default Config" with no MCP servers visible.
- Global scope writes into the user's single `config.yaml` and **preserves any unrelated top-level keys** (`models:`, `slashCommands:`, `rules:`, etc.) — only the `mcpServers` array (and missing metadata) is modified.
- Project scope writes a dedicated standalone block file at `<project>/.continue/mcpServers/wolfram.yaml`. Continue auto-discovers any `.yaml` or `.json` file in that directory.
- Continue supports `stdio`, `sse`, and `streamable-http` transports. `InstallMCPServer` writes the stdio form. MCP is only active in Continue's **agent mode**.
- A single `InstallMCPServer["Continue", ...]` covers all three distributions of Continue — the VS Code extension, the JetBrains plugin, and the standalone [`cn` CLI](https://www.npmjs.com/package/@continuedev/cli) (`npm i -g @continuedev/cli`) — because they all read the same `~/.continue/config.yaml` and `<project>/.continue/mcpServers/<*>.yaml` files.

**Troubleshooting `cn` ("MCP Servers: No servers configured" after a successful install):** The `cn` CLI defaults to a Continue-Hub-hosted config (typically labeled `Default Config` in `cn`'s header), **not** your local `~/.continue/config.yaml`. The IDE extensions read the local file by default, but the CLI does not. To point `cn` at the local file:

- **Windows:** `cn --config "$env:USERPROFILE\.continue\config.yaml"`
- **macOS / Linux:** `cn --config ~/.continue/config.yaml`
- Or, inside a running `cn` session, use the `/config` slash command and pick the entry that matches your local file's `name:` field (e.g. `Local Config`).

When `cn` is correctly reading the local file, its header changes from `Config: Default Config` to `Config: <name from your config.yaml>`, and the Wolfram MCP server appears under **MCP Servers** with status `connected`.

**Project scope is supported by Continue's IDE extensions only.** Continue's VS Code extension and JetBrains plugin auto-discover MCP server block files in `<workspace>/.continue/mcpServers/`, but as of `cn` v1.5.47 the standalone CLI does **not** auto-discover them — even when launched from inside the project directory. `cn` only reads the global `~/.continue/config.yaml` by default. Verified by writing a uniquely-named project-scope server (`InstallMCPServer[{"Continue", dir}, "WolframLanguage", "MCPServerName" -> "WolframProjectTest"]`) and observing that `cn` launched from `dir` shows the global Wolfram entry but not the project-scope `WolframProjectTest` entry. If you're a CLI-only user and want a per-project Wolfram server, either:

- Install at global scope (`InstallMCPServer["Continue", "WolframLanguage"]`) and rely on `cn`'s existing config, or
- Point `cn` explicitly at the project block file: `cn --config "C:\path\to\project\.continue\mcpServers\wolfram.yaml"` (Windows) / `cn --config ./.continue/mcpServers/wolfram.yaml` (macOS / Linux), or
- Use the `/config` slash command inside `cn` to switch to the project file at runtime.

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

> **Deprecation notice (announced at Google I/O 2026):** Google is retiring Gemini CLI for free / consumer tiers on **June 18, 2026** and unifying its CLI offering under Antigravity CLI (see [Antigravity (IDE, desktop app, and CLI)](#antigravity-ide-desktop-app-and-cli) below). Enterprise customers on Standard or Enterprise licenses can continue using Gemini CLI unchanged. New users should target `"Antigravity"` (alias `"AntigravityCLI"`) instead — see the [official migration announcement](https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/).

| Scope | Config Location |
|-------|----------------|
| Global | `~/.gemini/settings.json` |

**Format:** Same as Claude Desktop (`mcpServers` key).

### Antigravity (IDE, desktop app, and CLI)

A **single** `"Antigravity"` client entry covers the Antigravity IDE, the Antigravity 2.0 desktop app, and the Antigravity CLI (the terminal agent that replaces Gemini CLI for free / consumer tiers on **June 18, 2026**). `"AntigravityCLI"`, `"GoogleAntigravity"`, and `"GoogleAntigravityCLI"` are **aliases** of this entry — not separate clients. They share one global config file, so a single entry is required: two entries pointing at the same file would let `DeployAgentTools` create two deployments for one file and let `DeleteObject[AgentToolsDeployment[...]]` corrupt shared state.

| Scope | Condition | Config Location |
|-------|-----------|----------------|
| Global (migrated from pre-2.0, or Antigravity 2.0 / CLI) | `~/.gemini/config/.migrated` is **present** | `~/.gemini/config/mcp_config.json` |
| Global (pre-2.0 install, no migration) | `~/.gemini/config/.migrated` is **absent** | `~/.gemini/antigravity/mcp_config.json` |
| Project (CLI workspace) | — | `.agents/mcp_config.json` (in project root) |

**Format:** Same as Claude Desktop (`mcpServers` key).

`InstallMCPServer["Antigravity"]` (or any alias) auto-detects the global path. When the 2.0 installer migrates a pre-2.0 install forward, it drops a zero-byte `~/.gemini/config/.migrated` marker and both the desktop app and the CLI read `~/.gemini/config/mcp_config.json` (the shared per-user Antigravity config dir, per the official [Gemini-CLI → Antigravity-CLI migration guide](https://antigravity.google/docs/gcli-migration)); the historical `~/.gemini/antigravity/mcp_config.json` is then ignored. So a server installed once is visible to the IDE, the desktop app, and the CLI. Project-scoped installs (`InstallMCPServer[{"Antigravity", dir}]`) write the CLI's workspace file `.agents/mcp_config.json`.

Notes:
- **Do not** put a server in `~/.gemini/antigravity-cli/mcp_config.json` (the CLI's data dir holds skills/cache/settings only, not MCP config). The CLI reads `~/.gemini/config/mcp_config.json`; a stray server in the `antigravity-cli/` dir is reconciled against the real entry as a duplicate. If you have one, delete it.
- The CLI's `/mcp` command reloads the config, which **stops** the running server first. The Wolfram MCP server exits cleanly when the CLI closes its stdin (the MCP stdio shutdown signal). Older paclet builds did not — on Windows the kernel kept spinning after stdin closed, the CLI force-killed it after a timeout, and Go's exec reported the kill as `failed to reload MCP config: failed to stop mcp instance: Wolfram: exit status 1`. Fixed in `StartMCPServer.wl` (`stdinShutdownQ`); update to the latest paclet build if you hit it.
- Workspace skills moved from Gemini CLI's `.gemini/skills/` to Antigravity CLI's `~/.gemini/antigravity-cli/skills/` (global) and `.agents/skills/` (workspace), and workspace MCP config moved from `.gemini/settings.json` to `.agents/mcp_config.json`.
- Antigravity CLI renamed the HTTP-transport field from `"url"` (Gemini CLI) to `"serverUrl"`. The Wolfram MCP server is stdio (`command`/`args`), so this doesn't affect `InstallMCPServer` output — relevant only if you hand-edit an HTTP entry.

#### Antigravity 2.0 troubleshooting

If `InstallMCPServer["Antigravity"]` writes the file but Antigravity 2.0 does not pick the server up, the cause is almost always one of the following:

1. **App restart required.** Antigravity caches the config on launch; "reload window" is not always enough — fully quit and relaunch the app.
2. **Installer directory conflict (Windows).** The Antigravity 2.0 installer can drop `app.asar` into a previous 1.x install dir under `%LOCALAPPDATA%\Programs\Antigravity\resources`. Electron's `.asar` priority then causes the wrong binary to launch, and that binary may read a different config dir than you expect. Reinstall into a clean, dedicated folder (the installer accepts `/DIR="..."`). See the [forum thread](https://discuss.ai.google.dev/t/fixing-the-antigravity-2-0-installer-directory-conflict/145591).
3. **macOS GUI launch doesn't inherit `$PATH`.** When Antigravity is launched from Finder/Dock, MCP servers that rely on user-shell `$PATH` (including the `wolframscript`/`wolfram` resolution used by the Wolfram MCP server) crash silently. Either launch Antigravity from a terminal, or pass an absolute command path in `mcp_config.json`. See the [bug report](https://discuss.ai.google.dev/t/bug-mcp-servers-crash-with-executable-file-not-found-in-path-when-antigravity-is-launched-via-macos-gui/138495).
4. **WSL file permissions.** When Antigravity is running inside WSL, the agent may not be able to write `~/.gemini/` on the Linux side — `InstallMCPServer` succeeds but the server is invisible at runtime. Run `InstallMCPServer` from within the same WSL distribution Antigravity is launched from.
5. **Cloud-synced settings overriding local edits.** Google syncs some Antigravity settings to your Google account. If the cloud copy doesn't list your server, Antigravity may overwrite your local `mcp_config.json` on next launch. Sign out / sign back in to force a resync after installing.

Post-migration directory layout (Antigravity 2.0 creates several siblings under `~/.gemini/` during the 1.x → 2.0 upgrade — `InstallMCPServer` only writes to the one the IDE actually reads):

| Path | Role |
|------|------|
| `~/.gemini/antigravity/` | Pre-migration runtime data; the historical MCP config path is here |
| `~/.gemini/config/` | Post-migration shared per-user config; `mcp_config.json` here is read by **both** the migrated IDE and the Antigravity CLI, alongside the `.migrated` marker |
| `~/.gemini/antigravity-cli/` | Antigravity CLI skills, cache, and settings — **not** MCP config (the CLI reads `~/.gemini/config/mcp_config.json`) |
| `~/.gemini/antigravity-ide/` | Old pre-2.0 IDE data — not read by 2.0; safe to delete after upgrading |
| `~/.gemini/antigravity-backup/` | Pre-migration backup created by the 2.0 installer; safe to delete after confirming 2.0 works |
| `~/.gemini/antigravity-browser-profile/` | Embedded browser profile for the in-app browser tool |

### Augment Code

| Scope | Config Location |
|-------|----------------|
| Global | `~/.augment/settings.json` |

**Format:** Same as Claude Desktop (`mcpServers` key).

Note: Augment Code uses a single config file at `~/.augment/settings.json` on all platforms (macOS, Windows, Linux). It supports stdio, HTTP, and SSE transports; `InstallMCPServer` writes the standard stdio form. Augment Code has no project-level MCP configuration — server entries can also be managed from the Auggie CLI via `auggie mcp add` / `auggie mcp list` / `auggie mcp remove`.

On Windows, `InstallMCPServer` automatically rewrites the `command` to its 8.3 short-path form (e.g. `C:\PROGRA~1\WOLFRA~1\Wolfram\15.0\wolfram.exe`) to work around a shell-invocation quirk where spaces in `C:\Program Files\...` cause cmd.exe to fail with `'C:\Program' is not recognized as an internal or external command`.

### Augment Code IDE

The Augment Code VS Code extension stores its MCP servers separately from the Auggie CLI. Use `"AugmentCodeIDE"` (not `"AugmentCode"`) to target the extension.

| OS | Config Location |
|----|----------------|
| macOS | `~/Library/Application Support/Code/User/globalStorage/augment.vscode-augment/augment-global-state/mcpServers.json` |
| Windows | `%APPDATA%\Code\User\globalStorage\augment.vscode-augment\augment-global-state\mcpServers.json` |
| Linux | `~/.config/Code/User/globalStorage/augment.vscode-augment/augment-global-state/mcpServers.json` |

**Format (JSON array at root, not `mcpServers` object):**
```json
[
    {
        "type": "stdio",
        "name": "ServerName",
        "command": "...",
        "args": ["..."],
        "env": { ... }
    }
]
```

Notes:
- This is the only supported client whose config file is a **JSON array at the root** rather than an object with an `mcpServers`/`servers`/`context_servers` key. `InstallMCPServer` upserts by the `name` field inside each array entry.
- The Windows 8.3 short-path coercion applied to the CLI variant (`"AugmentCode"`) applies here too — the VS Code extension also shell-invokes the command on Windows.
- No project-level MCP configuration — the VS Code extension reads a single global file.
- After `InstallMCPServer` writes the file, VS Code may need to be reloaded (`Ctrl+Shift+P` → "Reload Window") for the extension to pick up the change.

If you primarily use the Auggie CLI instead of the VS Code extension, use `"AugmentCode"` — the two configurations are independent.

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

### Junie (JetBrains IDE plugin + Junie CLI)

| Scope | Config Location |
|-------|----------------|
| Global | `~/.junie/mcp/mcp.json` |
| Project | `.junie/mcp/mcp.json` (in project root) |

**Format:** Same as Claude Desktop (`mcpServers` key).

Junie is JetBrains' AI coding agent. **A single `InstallMCPServer["Junie", ...]` call covers both the JetBrains IDE plugin and the standalone Junie CLI** — they read the same files. Specifically:

- The user-scope file at `~/.junie/mcp/mcp.json` is shared across every JetBrains IDE that hosts the Junie plugin (IntelliJ IDEA, PyCharm, WebStorm, GoLand, PhpStorm, RubyMine, RustRover, Rider, etc.) **and** the standalone `junie` CLI. There is no per-IDE config split.
- The project-scope file at `.junie/mcp/mcp.json` (in the project root) is designed to be checked into version control and is read by the same plugin and CLI.
- Junie auto-reloads `mcp.json` changes, so no IDE restart is needed after running `InstallMCPServer`.

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
| `MCP_APPS_NOTEBOOK_METHOD` | Set to `"Inline"` to embed [MCP Apps](mcp-apps.md) notebooks inline instead of deploying them to the cloud (experimental, optional) |
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

### Detecting Installed Clients

`DetectedMCPClients[]` returns the subset of `$SupportedMCPClients` whose user-scope config file exists on the current machine — a quick way to discover which supported clients are actually installed before calling `InstallMCPServer`.

```wl
(* Names of clients that appear to be installed locally *)
Keys @ DetectedMCPClients[ ]
(* {"ClaudeCode", "Cursor", "VisualStudioCode", ...} *)

(* Full metadata for detected clients *)
DetectedMCPClients[ ]
(* <|"ClaudeCode" -> <|...|>, "Cursor" -> <|...|>, ...|> *)
```

The result is keyed by canonical client name and preserves the ordering of `$SupportedMCPClients`. Detection is based purely on the existence of each client's `"InstallLocation"` config file for the current `$OperatingSystem`; project-scope config files (`"ProjectPath"`) are not checked.

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
| `"DefaultToolset"` | Yes | Predefined server name to use when `InstallMCPServer`/`DeployAgentTools` is called with `Automatic`. Use `"WolframLanguage"` for coding-oriented clients and `"Wolfram"` for general-purpose chat clients. |
| `"ProjectPath"` | No | Relative path components for project-level config |
| `"ServerConverter"` | No | Function to transform the standard server entry into a client-specific format |

### Example Entry

```wl
"NewClient" -> <|
    "DisplayName"     -> "New Client",
    "DefaultToolset"  -> "WolframLanguage",
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
