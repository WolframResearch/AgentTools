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