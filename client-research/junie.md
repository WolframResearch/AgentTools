<!-- cspell: ignore heise, Özkan, Pakdil, intellectronica, Vaadin -->

# Junie MCP Client Research

## Overview

[Junie](https://www.jetbrains.com/junie/) is JetBrains' autonomous AI coding agent. It ships as an IDE plugin that runs inside the JetBrains IntelliJ-family IDEs (IntelliJ IDEA, PyCharm, WebStorm, GoLand, PhpStorm, RubyMine, RustRover, Rider) and as a standalone `junie` CLI. Both flavors share the same Model Context Protocol (MCP) configuration files.

MCP support shipped as part of the Junie plugin in the **JetBrains 2025.2 IDE wave** (Rider 2025.2, PhpStorm 2025.2, IntelliJ IDEA 2025.2, etc.), and remote (HTTP) server support was added later via [`JUNIE-461`](https://youtrack.jetbrains.com/projects/JUNIE/issues/JUNIE-461/MCP-Remote-Server-Support). As of December 2025, Junie was integrated into the JetBrains AI Chat as a selectable agent, but its MCP configuration continues to live in the same files described below and remains **separate from** the JetBrains AI Assistant's own MCP configuration.

## Configuration Details

### Config File Locations

Junie uses **plain JSON files** named `mcp.json`, stored under a `.junie/mcp/` directory. It supports **two scopes**, and both are merged at runtime.

| Scope | Path | Notes |
|-------|------|-------|
| User (global) | `~/.junie/mcp/mcp.json` | Shared across all JetBrains IDEs on the user's machine and across Junie CLI |
| Workspace (project) | `<project>/.junie/mcp/mcp.json` | Designed to be checked into version control and shared with the team |

On Windows, the user-scope path is `%USERPROFILE%\.junie\mcp\mcp.json` (i.e. `C:\Users\<user>\.junie\mcp\mcp.json`). There is **no** separate macOS `Application Support` path — the user-scope file sits under `$HomeDirectory` in a `.junie/` tree on all three operating systems, analogous to Cursor, Kiro, and OpenCode.

### Cross-IDE Behavior

The user-scope configuration is **global to Junie**, not per-IDE. The same `~/.junie/mcp/mcp.json` is read by Junie running in IntelliJ IDEA, PyCharm, WebStorm, GoLand, PhpStorm, RubyMine, RustRover, Rider, etc., and is also shared with the standalone Junie CLI. JetBrains explicitly states "Junie CLI uses the same MCP JSON configuration as Junie in JetBrains IDEs."

This is convenient for an installer: there is exactly one user-scope file path per OS, regardless of which JetBrains IDE(s) the user has installed.

### JSON Format

Junie uses **JSON** with a top-level **`mcpServers`** object — the same de-facto standard used by Claude Desktop, Cursor, Cline, Windsurf, and Kiro.

Example (combining patterns from JetBrains, Snyk, Vaadin, and container-use documentation):

```json
{
  "mcpServers": {
    "snyk": {
      "command": "npx",
      "args": ["-y", "snyk@latest", "mcp", "-t", "stdio"]
    },
    "github": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
        "ghcr.io/github/github-mcp-server"
      ],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxx"
      }
    },
    "container-use": {
      "command": "container-use",
      "args": ["stdio"],
      "env": {},
      "timeout": 60000
    },
    "RemoteServer": {
      "url": "https://mcp.example.com/v1",
      "headers": {
        "Authorization": "Bearer token"
      }
    }
  }
}
```

### Local (stdio) Server Fields

| Property | Required | Role |
|----------|----------|------|
| `command` | Yes | Executable to launch |
| `args`    | No  | Command-line arguments |
| `env`     | No  | Environment variables |
| `timeout` | No  | Startup timeout in milliseconds (e.g. `60000`) |

### Remote (HTTP) Server Fields

| Property | Required | Role |
|----------|----------|------|
| `url`     | Yes | `https://...` endpoint for the remote server |
| `headers` | No  | HTTP headers (e.g. `Authorization`) |

A single `mcp.json` may mix local and remote servers. There is no required `type` discriminator — Junie infers the transport from whether `command` or `url` is present. SSE-only servers are not explicitly documented; the common workaround is to wrap them with `npx mcp-remote` as a stdio shim.

### Junie-Specific Fields

Junie's `mcp.json` does **not** define Junie-specific `disabled`, `autoApprove`, or `alwaysAllow` fields on each server. (One third-party AWS guide shows these fields in an example, but they appear to be carried over from Cline-style config and are not documented as Junie fields.)

Instead, Junie has a **separate** approval mechanism:

- **Action Allowlist** stored in `~/.junie/allowlist.json`, controlling which commands run without prompting.
- Servers can be disabled/enabled at runtime via the `/mcp` slash command or the **Settings → Tools → Junie → MCP Settings** UI (state stored separately from `mcp.json`).

**Good news for the installer:** only the standard `mcpServers` shape needs to be written — no client-specific decoration or custom server converter is required.

### UX for Opening Config

Users can configure MCP servers in Junie via any of three equivalent paths:

1. **IDE Settings UI** — `File | Settings` (`Ctrl+Alt+S`) `| Tools | Junie | MCP Settings`. Lists all servers from both scopes. A toolbar button opens `mcp.json` directly for editing.
2. **`/mcp` slash command** — typed inside the Junie chat. Lists configured servers, shows status (Starting / Active / Inactive / Disabled / Failed / Authorization required), and launches the **MCP Installation Assistant**, an AI helper that guides users through adding servers from a registry or from scratch.
3. **Direct JSON editing** — manually create/edit `~/.junie/mcp/mcp.json` (user scope) or `<project>/.junie/mcp/mcp.json` (project scope). This is the approach `InstallMCPServer` would use.

Junie auto-reloads `mcp.json` changes per the docs, so no IDE restart is required after installing.

## Mapping to AgentTools

### Central Definition

Supported clients are defined in `$supportedMCPClients` in [`Kernel/SupportedClients.wl`](../Kernel/SupportedClients.wl). Each entry supplies:

- `"DisplayName"`, `"Aliases"`, `"ConfigFormat"`, `"ConfigKey"`, `"URL"`
- `"InstallLocation"` (per OS or a single delayed path)
- Optional `"ProjectPath"` + implicit project support (see `clientMetadata` in the same file)
- Optional `"ServerConverter"` — not needed for Junie, since the entry shape is plain `command` / `args` / `env`

### JSON Merge and Install Path

For non-Codex JSON clients, [`Kernel/InstallMCPServer.wl`](../Kernel/InstallMCPServer.wl) reads the existing file, follows the client's `"ConfigKey"` path, injects or updates one server entry, and writes JSON back. For Junie, **`"ConfigKey" -> { "mcpServers" }`** matches the documented layout.

### Proposed `$supportedMCPClients` Entry

| Field | Suggested value |
|-------|------------------|
| Canonical name   | `"Junie"` |
| Display name     | `"Junie"` |
| Aliases          | `{ }` (optionally `{ "JetBrainsJunie" }` if disambiguation from a future `"JetBrainsAIAssistant"` is desired) |
| `ConfigFormat`   | `"JSON"` |
| `ConfigKey`      | `{ "mcpServers" }` |
| `URL`            | `https://www.jetbrains.com/junie/` |
| `InstallLocation`| `{ $HomeDirectory, ".junie", "mcp", "mcp.json" }` (same structure on macOS/Linux/Windows under `$HomeDirectory`) |
| `ProjectPath`    | `{ ".junie", "mcp", "mcp.json" }` |
| `ServerConverter`| *None* — the standard server association is valid as-is |

Since the install location is the same relative path on every OS, a single `RuleDelayed` suffices — just like Cursor, Claude Code, and Kiro. This mirrors clients that already support project-level MCP JSON: `InstallMCPServer[{"Junie", dir}, ...]` would target `FileNameJoin[{dir, ".junie", "mcp", "mcp.json"}]`.

### Other Code to Update for a Full Implementation

1. **`guessClientName`** in [`Kernel/InstallMCPServer.wl`](../Kernel/InstallMCPServer.wl): extend the `Switch` on `FileNameSplit` for project/user files, e.g. tail `.../.junie/mcp/mcp.json` → `"Junie"`. Path-based matching is the safest route because Junie's standard `mcpServers` + `command`/`args`/`env` entries otherwise look identical to Claude Desktop.
2. **Tests** ([`Tests/InstallMCPServer.wlt`](../Tests/InstallMCPServer.wlt)): follow the Kiro/Windsurf patterns — `installLocation` per OS (degenerate in this case), `toInstallName`, `installDisplayName`, `$SupportedMCPClients` keys/count, and project-path behavior.
3. **User-facing docs** ([`docs/mcp-clients.md`](../docs/mcp-clients.md)): add a table row and a short "Junie" section with paths and merge behavior.
4. **Parent directory creation:** `.junie/mcp/` may not exist before the first install. The existing `ensureFilePath`/write helpers already create missing parent directories for other clients; verify this still holds for a two-level-deep path under `$HomeDirectory`.

No changes to `PacletInfo.wl` / `Kernel/Main.wl` are required for a new client — client support is internal metadata plus existing `InstallMCPServer`.

## Implementation Assessment

### Feasibility: **Fully feasible (one of the easiest clients to add)**

Reasons:

1. **Documented, file-based JSON** at stable relative paths under the user home and project root.
2. **Same top-level key** (`mcpServers`) and same core entry fields AgentTools already generates for stdio servers.
3. **No mandatory client-specific decoration** — no `disabled`, `autoApprove`, `alwaysAllow`, nested `mcp.servers`, or TOML conversion. A plain server association is valid as-is, so **no new `ServerConverter` is required**.
4. **Single OS-portable user-scope path** (`~/.junie/mcp/mcp.json`) — no per-IDE branching, no `Library/Application Support`, no `%APPDATA%` segment.
5. **Project-level config** is explicitly supported by Junie (designed to be checked into VCS), matching AgentTools' `{client, directory}` install form.
6. **Auto-reload** of `mcp.json` changes means no IDE restart is needed after install.
7. **Shared between IDE plugin and CLI** — a single entry covers both Junie IDE and Junie CLI users.

### Risks / Verification

- **`guessClientName` collisions:** Junie's standard `mcpServers` file has no distinguishing content-level fields, so JSON heuristic matching cannot reliably tell it apart from Claude Desktop. Rely on path-based matching via `installLocation`/`projectPath` and document `"ApplicationName" -> "Junie"` for ad-hoc file targets. This mirrors how Kiro is handled.
- **Field naming:** A handful of third-party guides (notably an AWS Q Developer guide) show Cline-style `disabled` / `autoApprove` fields in Junie examples. Official JetBrains docs do not list these, so we should not emit them. If JetBrains later adds them as documented fields, a `convertToJunieFormat` can be introduced, mirroring `convertToClineFormat`.
- **`timeout` field:** Junie supports an optional `timeout` (ms) field for stdio servers. AgentTools currently does not emit one for other clients; leave it off by default.
- **JetBrains AI Assistant is a different target:** the JetBrains AI Assistant plugin manages MCP servers via IDE settings storage, not a documented standalone JSON file. If we ever support it, it should be a **separate** `"JetBrainsAIAssistant"` client entry.
- **Windows home resolution:** Confirm that `$HomeDirectory` resolves to `%USERPROFILE%` (e.g. `C:\Users\<user>`) on Windows — AgentTools already relies on this for Cursor, Claude Code, Gemini CLI, Codex, Kiro, Copilot CLI, and OpenCode, so this is a formality.

### Recommendation

**Implement.** Junie is a first-party JetBrains product covering a broad set of professional IDEs, its MCP configuration is well-documented and standards-compliant, and the implementation is a near-trivial addition to `$supportedMCPClients` (no converter, no per-OS branching, no schema surprises). Project support comes for free because Junie's project scope is already a first-class feature.

## References

- [Model Context Protocol (MCP) – Junie Documentation](https://www.jetbrains.com/help/junie/model-context-protocol-mcp.html)
- [MCP Settings – Junie Documentation](https://www.jetbrains.com/help/junie/mcp-settings.html)
- [MCP Settings – Junie Documentation (junie.jetbrains.com)](https://junie.jetbrains.com/docs/junie-plugin-mcp-settings.html)
- [Add and configure MCP servers – Junie CLI Documentation](https://junie.jetbrains.com/docs/junie-cli-mcp-configuration.html)
- [Junie IDE plugin – Junie Documentation](https://junie.jetbrains.com/docs/junie-ide-plugin.html)
- [Junie plugin settings – Junie Documentation](https://junie.jetbrains.com/docs/junie-plugin-settings.html)
- [Action Allowlist – Junie Documentation](https://www.jetbrains.com/help/junie/user-approval.html)
- [Junie by JetBrains – JetBrains AI Assistant Documentation](https://www.jetbrains.com/help/ai-assistant/junie-agent.html)
- [Connect MCP Servers to Junie in PhpStorm – The PhpStorm Blog (Sep 2025)](https://blog.jetbrains.com/phpstorm/2025/09/connect-mcp-servers-to-junie-in-phpstorm/)
- [Rider 2025.2 Is Here with Junie – The .NET Tools Blog (Aug 2025)](https://blog.jetbrains.com/dotnet/2025/08/14/rider-2025-2-is-here-with-junie-in-ide-opentelemetry-game-dev-upgrades-and-more/)
- [Junie Now Integrated Into the AI Chat – JetBrains AI Blog (Dec 2025)](https://blog.jetbrains.com/ai/2025/12/junie-now-integrated-into-the-ai-chat/)
- [JetBrains Rider 2025.2: AI coding agent Junie uses MCP – heise online](https://www.heise.de/en/news/JetBrains-Rider-2025-2-AI-coding-agent-Junie-runs-faster-and-uses-MCP-10539910.html)
- [MCP Remote Server Support – JUNIE-461 (YouTrack)](https://youtrack.jetbrains.com/projects/JUNIE/issues/JUNIE-461/MCP-Remote-Server-Support)
- [Junie, the AI coding agent by JetBrains – JetBrains Marketplace](https://plugins.jetbrains.com/plugin/26104-junie-the-ai-coding-agent-by-jetbrains)
- [Configure Junie to Use Vaadin MCP Server](https://vaadin.com/docs/latest/building-apps/mcp/supported-tools/junie)
- [JetBrains Junie – Snyk User Docs](https://docs.snyk.io/integrations/snyk-studio-agentic-integrations/quickstart-guides-for-snyk-studio/jetbrains-junie)
- [How to use Playwright MCP with Junie in IntelliJ – Özkan Pakdil](https://ozkanpakdil.github.io/posts/my_collections/2025/09-01-junie-mcp-playwright/)
- [Configure an MCP server – JetBrains AI Assistant Documentation](https://www.jetbrains.com/help/ai-assistant/configure-an-mcp-server.html)
- [Model Context Protocol (MCP) – JetBrains AI Assistant Documentation](https://www.jetbrains.com/help/ai-assistant/mcp.html)
- [Feature request: Support Junie project MCP configuration – intellectronica/ruler#393](https://github.com/intellectronica/ruler/issues/393)
- AgentTools: [`Kernel/SupportedClients.wl`](../Kernel/SupportedClients.wl), [`Kernel/InstallMCPServer.wl`](../Kernel/InstallMCPServer.wl), [`docs/mcp-clients.md`](../docs/mcp-clients.md)
