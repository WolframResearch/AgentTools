<!-- cspell: ignore Zechner, badlogic, mariozechner, nicobailon, Mintlify -->

# Pi MCP Client Research

## Overview

**Pi** (a.k.a. the "Pi coding agent") is a minimal terminal coding harness by Mario Zechner ([`badlogic/pi-mono`](https://github.com/badlogic/pi-mono), npm package [`@mariozechner/pi-coding-agent`](https://www.npmjs.com/package/@mariozechner/pi-coding-agent)). Its design philosophy is deliberately minimalist: by default, Pi gives the model four tools (`read`, `write`, `edit`, `bash`) and is "aggressively extensible" through TypeScript extensions and "skills" distributed via npm or git.

**Critical caveat:** Pi's README explicitly states **"No MCP."** Pi does *not* support the Model Context Protocol natively. MCP support is provided by a **third-party extension**, [`pi-mcp-adapter`](https://github.com/nicobailon/pi-mcp-adapter) by `nicobailon`, which acts as a token-efficient proxy between Pi and MCP servers. Users must install this adapter separately before any `InstallMCPServer["Pi", ...]` configuration becomes usable:

```
pi install npm:pi-mcp-adapter
```

Everything below describes the configuration format defined by `pi-mcp-adapter`, because that is the only surface `InstallMCPServer` could reasonably target for a "Pi" client.

## Configuration Details

### Config file locations

Like Claude Code, Kiro, OpenCode, and several others, `pi-mcp-adapter` supports **two scopes** with project overriding user:

| Scope | Path | Notes |
|-------|------|--------|
| User (global) | `~/.pi/agent/mcp.json` | Applies to all Pi sessions |
| Project | `.pi/mcp.json` (in project root) | Overrides global/imported entries |

Paths are relative to `$HomeDirectory` / the project root and do not change between macOS, Linux, and Windows — the adapter is pure Node.js and uses the same layout everywhere.

### JSON format

The file is **JSON** with up to three top-level keys:

| Key | Role |
|------|------|
| `mcpServers` | Map of `name -> server entry`. The only key needed by `InstallMCPServer` today. |
| `settings` | Global adapter defaults (`toolPrefix`, `idleTimeout`, `directTools`, …). Optional. |
| `imports` | Array of names of *other* MCP clients whose config should be inherited, e.g. `["cursor", "claude-code", "claude-desktop", "vscode", "windsurf"]`. Optional. |

Example (abridged from the adapter README):

```json
{
  "imports": ["cursor", "claude-code"],
  "settings": {
    "toolPrefix": "server",
    "idleTimeout": 10,
    "directTools": false
  },
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest"],
      "env": {},
      "cwd": "/path/to/dir",
      "lifecycle": "lazy",
      "idleTimeout": 10
    }
  }
}
```

### Local (stdio) server fields

| Property | Required | Role |
|----------|----------|------|
| `command` | Yes (stdio) | Executable |
| `args` | Optional | Argument list |
| `env` | Optional | Environment variables; supports `${VAR}` interpolation from the shell |
| `cwd` | Optional | Working directory |
| `lifecycle` | Optional | `"lazy"` (default), `"eager"`, or `"keep-alive"` |
| `idleTimeout` | Optional | Minutes before disconnection (default 10) |
| `directTools` | Optional | Promote specific tool names to first-class Pi tools |
| `debug` | Optional | Forward server stderr to the terminal |
| `url` | Remote only | HTTP endpoint (replaces `command`) |
| `auth` | Remote only | `"bearer"` or `"oauth"` |

All non-identity fields are optional; the defaults `lifecycle: "lazy"` / `idleTimeout: 10` are applied by the adapter at load time. **A bare `command` + `args` + `env` entry — exactly what AgentTools produces — is a valid Pi server entry with no transformation.**

### UX / activation

Pi loads `mcp.json` on startup, via the adapter. Adding or changing a server requires a Pi restart (analogous to Kiro and most other non-hot-reloading clients). The adapter also maintains a `~/.pi/agent/mcp-cache.json` to speed up tool metadata for `directTools`, which users may want to clear when editing existing entries.

## Mapping to AgentTools

### Central definition

Supported clients are defined in `$supportedMCPClients` in [`Kernel/SupportedClients.wl`](../Kernel/SupportedClients.wl). Each entry supplies:

- `"DisplayName"`, `"Aliases"`, `"ConfigFormat"`, `"ConfigKey"`, `"URL"`
- `"InstallLocation"` (per OS or a single delayed path)
- Optional `"ProjectPath"` (implicit project support via `clientMetadata`)
- Optional `"ServerConverter"` when the on-disk entry shape differs from the standard `command` / `args` / `env` association produced from `MCPServerObject`

### JSON merge and install path

For non-Codex JSON clients, [`Kernel/InstallMCPServer.wl`](../Kernel/InstallMCPServer.wl) reads the existing file (via `readExistingMCPConfig`), walks the client's `"ConfigKey"` path, injects or updates one server entry, and writes JSON back. For Pi, **`"ConfigKey" -> { "mcpServers" }`** matches the documented file layout — same shape as Claude Desktop, Cursor, Windsurf, Cline, and Kiro.

### Server entry shape

Pi/`pi-mcp-adapter` accepts the standard `command` / `args` / `env` Claude-style entry as-is. The `lifecycle` and `idleTimeout` keys are optional with sensible defaults, and `directTools` is an opt-in feature. Therefore **no `"ServerConverter"` is required** for a first implementation; the `Identity` default used in `serverConverter` in `InstallMCPServer.wl` is enough.

If we later want to be explicit about the adapter's behavior (for clarity when users inspect the file), a thin converter could pin `"lifecycle" -> "lazy"` and `"idleTimeout" -> 10`, but this is purely cosmetic — the adapter applies those defaults anyway.

### `imports` as an alternative path

Pi's `imports` key is an interesting second option that does not exist in any currently supported client. Since the adapter can re-use any MCP server already configured for `cursor`, `claude-code`, `claude-desktop`, `vscode`, or `windsurf`, a Pi user can reach the AgentTools MCP server today, without any code changes, by:

1. Running `InstallMCPServer["ClaudeDesktop"]` (or another already-supported client).
2. Adding `"imports": ["claude-desktop"]` to their `~/.pi/agent/mcp.json`.

This means adding `"Pi"` to `$supportedMCPClients` is a convenience feature, not a hard requirement. It's still worth doing, because the `imports`-based workflow requires a second install that the user maintains separately and it conflates the lifecycles of two unrelated clients.

### Heuristic collisions in `guessClientName`

`guessClientName` / `guessClientNameFromJSON` in `InstallMCPServer.wl` already has to disambiguate JSON files that use `mcpServers`. The Pi config has no distinguishing top-level shape — `mcpServers` is shared with Claude Desktop, Cursor, Cline, Copilot CLI, Windsurf, Kiro, etc. The only reliable signals for Pi are **path-based**:

- Global: `.../.pi/agent/mcp.json`
- Project: `.../.pi/mcp.json`

Both are unique enough to add to the `Switch[ FileNameSplit @ file, ... ]` block alongside the existing `.kiro/settings/mcp.json`, `.vscode/...`, `.mcp.json`, etc. clauses.

Because the tiered JSON heuristics (`hasOpenCodeTraits`, `hasCopilotCLITraits`, `hasClineTraits`) key on server-entry fields that Pi leaves optional, a stray Pi config at a non-standard path would fall through to `None` unless the user passes `"ApplicationName" -> "Pi"` — the same story as several existing clients. No new heuristic traits are needed.

### Proposed `$supportedMCPClients` entry (illustrative)

| Field | Suggested value |
|-------|-----------------|
| Canonical name | `"Pi"` |
| Display name | `"Pi"` (or `"Pi Coding Agent"` for disambiguation) |
| Aliases | `{ "PiCodingAgent", "PiAgent" }` — the bare name "Pi" is generic |
| `ConfigFormat` | `"JSON"` |
| `ConfigKey` | `{ "mcpServers" }` |
| `URL` | `https://github.com/badlogic/pi-mono` |
| `InstallLocation` | `{ $HomeDirectory, ".pi", "agent", "mcp.json" }` (same on all OSes) |
| `ProjectPath` | `{ ".pi", "mcp.json" }` |
| `ServerConverter` | (omit; `Identity` is correct) |

`$HomeDirectory` is the right base on all platforms since Pi is a Node.js CLI that creates its data in `~/.pi` regardless of OS — mirroring the single-path pattern already used for `ClaudeCode`, `Cursor`, `CopilotCLI`, `Kiro`, `Windsurf`, and `Antigravity`.

### Other code to update for a full implementation

1. **`guessClientName`** (`InstallMCPServer.wl`): add two cases to the `Switch` on `FileNameSplit`, matching project (`{ __, ".pi", "mcp.json" }`) and user (`{ __, ".pi", "agent", "mcp.json" }`) paths so ad-hoc `File[...]` targets resolve to `"Pi"`.
2. **Tests** ([`Tests/InstallMCPServer.wlt`](../Tests/InstallMCPServer.wlt)):
   - `installLocation[ "Pi", "MacOSX" | "Unix" | "Windows" ]`
   - `toInstallName[ "Pi" ]`, `toInstallName[ "PiCodingAgent" ]`, `installDisplayName[ "Pi" ]`
   - `projectInstallLocation[ "Pi", path ]`
   - Install/uninstall round-trip on a temp `mcp.json`, verifying `mcpServers` key path is honored and existing `settings` / `imports` entries are preserved (this is the Pi-specific regression risk, since no other client today has sibling top-level keys in the same file).
   - Update the `Length` and `Keys` equality tests for `$SupportedMCPClients` (currently pinned to the 13-client list ending with `Zed`).
3. **User-facing docs** ([`docs/mcp-clients.md`](../docs/mcp-clients.md)):
   - Add a row to the "Clients with InstallMCPServer Support" table.
   - Add a "Pi" subsection under "Client Configuration Details" noting that Pi requires `pi-mcp-adapter` to be installed first, citing the user/project paths, and mentioning the `imports` alternative.
4. **Optional but recommended:** A clear user-visible warning (or at least doc note) explaining that `InstallMCPServer["Pi", ...]` has a hard prerequisite — the adapter must already be installed, otherwise the written config is inert. This could be an up-front check in the Pi-specific install branch using `RunProcess[{"pi", "list"}, ...]` or equivalent, but that's fragile; a doc note is probably sufficient.

No changes to `PacletInfo.wl` / `Main.wl` are required — client support is internal metadata plus existing `InstallMCPServer` dispatch.

## Implementation Assessment

### Feasibility: **Feasible, with one caveat**

Positives:

1. **Standard JSON at stable paths** under both `$HomeDirectory` and the project root. No per-OS branching.
2. **Identical `mcpServers` top-level key** and identical core entry fields (`command`, `args`, `env`) to what AgentTools already generates — `Identity` converter suffices.
3. **Project-level config** is explicitly supported, matching AgentTools' `{client, directory}` install form.
4. **`settings` / `imports` peers** are easy to preserve: the existing JSON merge strategy writes only the `mcpServers` subtree and leaves siblings alone, so no new code is needed to avoid clobbering them.

The caveat:

- **Pi does not natively speak MCP.** Unlike every other supported client, writing a correct `mcp.json` is necessary but not sufficient — the user must also `pi install npm:pi-mcp-adapter` and restart Pi. Shipping `InstallMCPServer["Pi", ...]` without at least a doc note risks users reporting that "the install succeeds but no tools appear."

### Risks / verification

- **Name collisions:** "Pi" is a generic string; users might expect Inflection's Pi chatbot, Raspberry Pi tooling, or PiAPI. Aliasing the canonical entry to something like `"PiCodingAgent"` in the public-facing display and keeping `"Pi"` primarily as a short alias reduces confusion.
- **Adapter drift:** `pi-mcp-adapter` is a third-party extension whose schema could change independently of Pi. The `lifecycle` / `idleTimeout` / `directTools` vocabulary in particular is adapter-specific. Since AgentTools emits none of those keys, drift is low-risk, but the doc reference should point at the adapter repo, not the Pi repo, for the schema of record.
- **`mcp-cache.json` staleness:** When a user reinstalls or updates a server, the adapter's cache at `~/.pi/agent/mcp-cache.json` may hold stale `directTools` metadata. `InstallMCPServer` doesn't need to touch it for a simple stdio-only install, but if we later add `directTools` support, cache invalidation becomes part of the contract.
- **Windows path confirmation:** The adapter README specifies `~/.pi/agent/mcp.json` as cross-platform, but worth confirming on Windows that Node's `os.homedir()` and AgentTools' `$HomeDirectory` resolve to the same directory before claiming "Windows" support in the client entry.

## References

- [badlogic/pi-mono (Pi coding agent monorepo)](https://github.com/badlogic/pi-mono)
- [`packages/coding-agent/README.md` (explicit "No MCP" stance)](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md)
- [`@mariozechner/pi-coding-agent` on npm](https://www.npmjs.com/package/@mariozechner/pi-coding-agent)
- [nicobailon/pi-mcp-adapter (third-party MCP bridge for Pi)](https://github.com/nicobailon/pi-mcp-adapter)
- [pi-mcp-adapter configuration guide (DeepWiki)](https://deepwiki.com/nicobailon/pi-mcp-adapter/4-configuration-guide)
- [pi-mcp-adapter quickstart (Mintlify)](https://www.mintlify.com/nicobailon/pi-mcp-adapter/quickstart)
- AgentTools: [`docs/mcp-clients.md`](../docs/mcp-clients.md) ("Adding Support for New Clients")
- AgentTools: [`Kernel/SupportedClients.wl`](../Kernel/SupportedClients.wl), [`Kernel/InstallMCPServer.wl`](../Kernel/InstallMCPServer.wl)
