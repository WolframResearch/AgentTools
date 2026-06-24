# LM Studio MCP Client Research

## Overview

[LM Studio](https://lmstudio.ai/) is a cross-platform desktop application for discovering, downloading, and running local LLMs, with a built-in chat interface. Since v0.3.17 it also acts as an **MCP client**, letting the local model call tools exposed by MCP servers.

MCP support is file-based and standards-compliant, which makes LM Studio one of the easiest clients to add to AgentTools — effectively a clone of the existing `Cursor` entry with a different path.

## Configuration Details

### Config file location

LM Studio uses a single global config file named `mcp.json`:

| Platform | Path |
|----------|------|
| macOS / Linux | `~/.lmstudio/mcp.json` |
| Windows | `%USERPROFILE%\.lmstudio\mcp.json` |

The same relative path under the home directory on every OS, exactly like Cursor, Claude Code, Kiro, and Junie — so a single delayed `InstallLocation` suffices, with no per-OS branching.

The in-app editor (Program tab → Install → Edit `mcp.json`) opens and writes this same file, so hand-editing it and editing it through the UI are equivalent.

> **Known macOS quirk (testing only):** there is an [open bug](https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/1371) where a *copy* of `mcp.json` also appears under `~/.cache/lm-studio/mcp.json` on macOS. The primary/correct location is `~/.lmstudio/mcp.json` (what we target). Not relevant to Windows; worth a docs note so Mac users don't edit the stray copy.

### JSON format

LM Studio "**follows Cursor's `mcp.json` notation**" — a top-level **`mcpServers`** object keyed by server name, the de-facto standard shared by Claude Desktop, Cursor, Cline, Windsurf, Kiro, and Junie. This is exactly the shape `MCPServerObject["…"]["JSONConfiguration"]` already produces, so **no `ServerConverter` is needed.**

Local (stdio) server entry:

```json
{
  "mcpServers": {
    "Wolfram": {
      "command": "wolfram",
      "args": [
        "-run",
        "PacletSymbol[\"Wolfram/AgentTools\",\"Wolfram`AgentTools`StartMCPServer\"][]",
        "-noinit",
        "-noprompt"
      ],
      "env": {
        "MCP_SERVER_NAME": "WolframLanguage"
      }
    }
  }
}
```

Remote server entries use `url` (and an optional `auth`/`headers` object) instead of `command`. LM Studio infers the transport from which fields are present.

### Transport types

LM Studio "supports both local and remote MCP servers" — local **stdio** (via `command`/`args`/`env`) and **remote** (via `url`). The Wolfram MCP server is stdio, which is fully supported.

### Configuration scope

| Scope | Support |
|-------|---------|
| Global | Yes (`~/.lmstudio/mcp.json`, single file) |
| Project | **No** — there is no documented project/workspace-level MCP config |

### Platforms

LM Studio ships desktop builds for **macOS, Windows, and Linux**. A Windows build exists, so the integration is fully hands-on testable on a Windows machine (no Mac required).

## Mapping to AgentTools

### Central definition

Add one entry to `$supportedMCPClients` in [`Kernel/SupportedClients.wl`](../Kernel/SupportedClients.wl). The file is a plain `mcpServers` JSON object, so the standard (non-Codex, non-Goose, non-AugmentCodeIDE, non-Continue) install/uninstall code path handles it with no special overload.

### Proposed `$supportedMCPClients` entry

| Field | Suggested value |
|-------|------------------|
| Canonical name   | `"LMStudio"` |
| Display name     | `"LM Studio"` |
| `DefaultToolset` | `"Wolfram"` — LM Studio is a chat client for local LLMs, so it follows the chat-client convention (like Claude Desktop and Goose) rather than the coding-client default of `"WolframLanguage"`. **Confirm with maintainer**; debatable. |
| Aliases          | `{ }` |
| `ConfigFormat`   | `"JSON"` |
| `ConfigKey`      | `{ "mcpServers" }` |
| `URL`            | `"https://lmstudio.ai"` |
| `InstallLocation`| `:> { $HomeDirectory, ".lmstudio", "mcp.json" }` (single delayed path — same on every OS) |
| `ProjectPath`    | *None* — no project scope |
| `ServerConverter`| *None* — Cursor-style notation is valid as-is |

### Other code to update for a full implementation

1. **`guessClientName`** in [`Kernel/InstallMCPServer.wl`](../Kernel/InstallMCPServer.wl): add a `FileNameSplit` tail case for `{ __, ".lmstudio", "mcp.json" }` → `"LMStudio"`, alongside the existing Kiro / Junie / Augment cases. Path-based matching is the right approach because the standard `mcpServers` + `command`/`args`/`env` content is otherwise indistinguishable from Claude Desktop.
2. **Tests** ([`Tests/InstallMCPServer.wlt`](../Tests/InstallMCPServer.wlt)): follow the Cursor / Junie pattern — `installLocation` per OS, path-shape check (`{".lmstudio", "mcp.json"}`), `toInstallName`, `installDisplayName`, install/uninstall round-trip, standard-format check (no Cline `disabled`/`autoApprove`, no Copilot `tools`), path-based auto-detection, `$SupportedMCPClients` metadata, and the supported-client count bump + sorted-keys update.
3. **Docs** ([`docs/mcp-clients.md`](../docs/mcp-clients.md)): table row + a short "LM Studio" section with the path table and the macOS stray-copy note.
4. **README.md**: supported-clients table row.
5. **AgentSkills** ([`AgentSkills/References/SetUpWolframMCPServer.md`](../AgentSkills/References/SetUpWolframMCPServer.md)): add a row to the **source** reference file only, then run `Scripts/BuildAgentSkills.wls` to regenerate the four `AgentSkills/Skills/*/references/` copies — do **not** edit the generated copies by hand.
6. **`TODO/more-mcp-clients.md`**: mark the implementation checkbox done.

No changes to `PacletInfo.wl` or `Kernel/Main.wl` are required.

## Implementation Assessment

### Feasibility: **Fully feasible — one of the easiest clients to add**

1. **Documented, file-based JSON** at a stable home-directory path on every OS.
2. **Standard `mcpServers` notation** ("follows Cursor's `mcp.json`") — identical to the shape we already emit, so **no converter, no dedicated install overload**.
3. **stdio supported** — the Wolfram MCP server works as-is.
4. **Single OS-portable path** — no per-OS branching, no `Library/Application Support`, no `%APPDATA%` segment.
5. **Cross-platform with a Windows build** — fully testable on Windows, no Mac needed.

It is strictly simpler than Junie (no project scope) and far simpler than Continue (no YAML, no array shape) or AugmentCodeIDE (no root-array format).

### Risks / Verification

- **`guessClientName` collisions:** LM Studio's `mcp.json` content is indistinguishable from Cursor/Claude Desktop, so rely on path-based matching via `installLocation` and document `"ApplicationName" -> "LMStudio"` for ad-hoc `File[…]` targets. Mirrors how Kiro/Junie are handled.
- **macOS stray copy:** the `~/.cache/lm-studio/mcp.json` duplicate (bug #1371) should be mentioned in docs so Mac users edit the right file. We always write the documented `~/.lmstudio/mcp.json`.
- **Default toolset choice:** `"Wolfram"` (chat-client convention) vs `"WolframLanguage"` (coding-client convention) is a judgment call — LM Studio is chat-first, so `"Wolfram"` is the suggested default, but confirm with the maintainer.
- **Windows home resolution:** `$HomeDirectory` resolves to `%USERPROFILE%` on Windows, as already relied on for Cursor, Claude Code, Gemini CLI, Codex, Kiro, Copilot CLI, OpenCode, and Junie. No new risk.

### Recommendation

**Implement.** LM Studio is a widely used local-LLM desktop app, its MCP configuration is documented, standards-compliant (Cursor `mcp.json` notation), file-based at a stable path, and stdio-compatible. The implementation is a near-trivial addition to `$supportedMCPClients` plus one `guessClientName` line, tests, and docs — and it is fully verifiable on Windows.

### How to test (Windows)

1. `InstallMCPServer["LMStudio", "WolframLanguage"]` → writes `%USERPROFILE%\.lmstudio\mcp.json`.
2. Open LM Studio → Program tab (right sidebar) → confirm the Wolfram server appears and connects (stdio), exposing the Wolfram tools.
3. `UninstallMCPServer["LMStudio", "WolframLanguage"]` → confirm the entry is removed from `mcp.json`.

## References

- [LM Studio — Use MCP Servers](https://lmstudio.ai/docs/app/mcp)
- [LM Studio — MCP plugin overview](https://lmstudio.ai/docs/app/plugins/mcp)
- [LM Studio — Remote MCP / auth](https://lmstudio.ai/docs/integrations/mcp-remote)
- [LM Studio v0.3.17 blog (MCP launch)](https://lmstudio.ai/blog/lmstudio-v0.3.17)
- [mcp.json path bug tracker issue #1371 (macOS stray copy)](https://github.com/lmstudio-ai/lmstudio-bug-tracker/issues/1371)
- AgentTools precedent: [`Kernel/SupportedClients.wl`](../Kernel/SupportedClients.wl) (Cursor entry — closest analog), [`Kernel/InstallMCPServer.wl`](../Kernel/InstallMCPServer.wl) (`guessClientName` path detection)
