<!-- cspell: ignore continuedev, Dify, Msty, pglite -->

# More MCP Clients

For each MCP client, we need to properly research how MCP servers are added to the client and then decide if we can implement support for `InstallMCPServer` or if we need to reject it. If it's not feasible to implement a client, add text to the relevant section below to explain why.

## Research Instructions

1. For each MCP client, research how MCP servers are added to the client and write a detailed report in `MCPServer/client-research/client-name.md`.

2. Commit research results with an appropriate commit message and wait for user input to continue.

## Implementation Instructions

1. Implement support for `InstallMCPServer` for the client in `MCPServer/Kernel/InstallMCPServer.wl`.

2. Do not add any new aliases to `toInstallName` unless specifically requested.

3. When you've finished implementation, write appropriate unit tests and run them to ensure they pass.

4. When you've finished the tests, commit your changes with an appropriate commit message.

5. Update this file to mark the task as complete and wait for user input to continue.

## Clients

### [Windsurf](https://windsurf.com/)

- [x] Research how MCP servers are added to Windsurf and write a detailed report in [windsurf.md](../client-research/windsurf.md)
- [x] Implement support for `InstallMCPServer["Windsurf", ...]`

### [Cline](https://cline.bot/)

- [x] Research how MCP servers are added to Cline and write a detailed report in [cline.md](../client-research/cline.md)
- [x] Implement support for `InstallMCPServer["Cline", ...]`

### [Zed](https://zed.dev/)

- [x] Research how MCP servers are added to Zed and write a detailed report in [zed.md](../client-research/zed.md)
- [x] Implement support for `InstallMCPServer["Zed", ...]`

### [Cherry Studio](https://github.com/CherryHQ/cherry-studio)

Cherry Studio stores MCP configurations in Redux state with localStorage persistence, not in external JSON files. There is no config file path to write to, so `InstallMCPServer` cannot be implemented.

- [x] Research how MCP servers are added to Cherry Studio and write a detailed report in [cherry-studio.md](../client-research/cherry-studio.md)
- [x] Reject support for `InstallMCPServer["CherryStudio", ...]` - not feasible due to internal storage architecture

### [Goose](https://github.com/block/goose)

- [x] Research how MCP servers are added to Goose and write a detailed report in [goose.md](../client-research/goose.md)
- [x] Implement support for `InstallMCPServer["Goose", ...]`

### [Augment Code](https://www.augmentcode.com/)

- [x] Research how MCP servers are added to Augment Code (CLI and VS Code extension) and write a detailed report in [augment-code.md](../client-research/augment-code.md)
- [x] Implement support for `InstallMCPServer["AugmentCode", ...]` (Auggie CLI)
- [x] Implement support for `InstallMCPServer["AugmentCodeIDE", ...]` (VS Code extension — array-rooted JSON)

### [Junie](https://www.jetbrains.com/junie/)

- [x] Research how MCP servers are added to Junie and write a detailed report in [junie.md](../client-research/junie.md)
- [x] Implement support for `InstallMCPServer["Junie", ...]` (covers both the JetBrains IDE plugin and the Junie CLI — they share `~/.junie/mcp/mcp.json`)

### [Continue](https://www.continue.dev/)

Continue uses a YAML config file (`~/.continue/config.yaml`) with `mcpServers` as an **array of entries** (each carrying its own `name` field), and a project-scope directory of standalone YAML/JSON block files at `<project>/.continue/mcpServers/`. The two infrastructure pieces this needs — YAML round-trip (`Kernel/YAML.wl`, used by Goose) and array-shaped MCP entries with name-based upsert (used by `AugmentCodeIDE`) — are both in place, so the original "more complicated implementation" rationale no longer applies. See [continue.md](../client-research/continue.md) §Implementation Assessment for the current plan.

- [x] Research how MCP servers are added to Continue and write a detailed report in [continue.md](../client-research/continue.md) (revised May 2026 to use native YAML)
- [x] Implement support for `InstallMCPServer["Continue", ...]` — writes into `~/.continue/config.yaml` (global) and `.continue/mcpServers/wolfram.yaml` (project), reusing the Goose YAML pattern and the AugmentCodeIDE name-based upsert pattern. Covers all three Continue distributions — VS Code extension, JetBrains plugin, and the `cn` CLI (`npm i -g @continuedev/cli`) — because they all read the same config files.

### [LM Studio](https://lmstudio.ai/)

LM Studio is a cross-platform (macOS / Windows / Linux) desktop app for running local LLMs that doubles as an MCP client. It uses a single file-based config at `~/.lmstudio/mcp.json` (`%USERPROFILE%\.lmstudio\mcp.json` on Windows) and explicitly "follows Cursor's `mcp.json` notation" — a top-level `mcpServers` object keyed by name with the standard `command`/`args`/`env` fields. It supports both local stdio and remote MCP servers, has no project scope, and needs no custom `ServerConverter`. This makes it one of the easiest clients to add — effectively a clone of the `Cursor` entry with a different path. See [lmstudio.md](../client-research/lmstudio.md) for the full plan. Fully testable on Windows (a Windows build exists).

- [x] Research how MCP servers are added to LM Studio and write a detailed report in [lmstudio.md](../client-research/lmstudio.md)
- [x] Implement support for `InstallMCPServer["LMStudio", ...]` — `$supportedMCPClients` entry pointing at `~/.lmstudio/mcp.json` (standard `mcpServers` JSON, no converter, no project scope, default toolset `"Wolfram"`), `guessClientName` path pattern, tests, and docs rows

## Rejected / Not Feasible

These clients were researched and rejected for `InstallMCPServer` support. The common blocker is the same as Cherry Studio: no documented, stable, external configuration file to write to (configuration lives in an in-app UI, an internal database, or hosted state). For each, the manual workaround remains available to users on supported platforms — generate `MCPServerObject["Wolfram"]["JSONConfiguration"]` (or the relevant server) and add it through the client's own UI.

### [Dify](https://dify.ai/)

Web-based LLM-app platform. MCP servers are added entirely through the web UI (Tools → MCP → Add MCP Server (HTTP)), stored in Dify's backend, and only **HTTP** transport is supported (no stdio). There is no on-disk config file, and Dify runs as a hosted/self-hosted web service rather than a local app, so `InstallMCPServer` has nothing to target.

- [x] Research how MCP servers are added to Dify
- [x] Reject support for `InstallMCPServer["Dify", ...]` — web UI / backend storage, HTTP-only, no local config file

### [RecurseChat](https://recurse.chat/)

Mac App Store app, **Apple-Silicon-only** (macOS Ventura 13.5+, no Intel, no Windows/Linux). MCP servers are configured through the in-app UI ("New Model → New MCP Model → import MCP Server JSON Config"); there is no documented on-disk config file. Cannot be hands-on tested without an Apple Silicon Mac, and there is no config file to write to regardless.

- [x] Research how MCP servers are added to RecurseChat and write a detailed report in [recurse-chat.md](../client-research/recurse-chat.md)
- [x] Reject support for `InstallMCPServer["RecurseChat", ...]` — in-app UI only, no config file, Mac-only

### [Msty Studio](https://msty.ai/)

Cross-platform desktop app (Windows / macOS / Linux) with MCP support for both stdio and streamable-HTTP. However, MCP servers are configured through the in-app "Add New Tool" UI with inline per-tool JSON (not a `mcpServers`-keyed object), and there is no documented on-disk config file. Testable on Windows, but `InstallMCPServer` has no documented file to target. If a stable config file is later confirmed under `%APPDATA%\Msty`, this could be revisited.

- [x] Research how MCP servers are added to Msty Studio and write a detailed report in [msty.md](../client-research/msty.md)
- [x] Reject support for `InstallMCPServer["Msty", ...]` — in-app UI only, no documented config file (revisit if one is found)

### [5ire](https://5ire.app/)

Open-source desktop AI assistant / MCP client. Supports both stdio and remote MCP servers, but stores configuration in an internal **pglite** database (migrated from SQLite + LanceDB), managed through the in-app UI — there is no external config file. Additionally, the latest release ships only macOS and Linux binaries (no Windows installer), so it is not hands-on testable on Windows without building from source. Same blocker as Cherry Studio.

- [x] Research how MCP servers are added to 5ire and write a detailed report in [5ire.md](../client-research/5ire.md)
- [x] Reject support for `InstallMCPServer["5ire", ...]` — internal pglite database, no external config file