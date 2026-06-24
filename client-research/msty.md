# Msty Studio MCP Client Research

## Overview

[Msty Studio](https://msty.ai/) is a desktop (and web) AI application for chatting with local and cloud LLMs. The desktop app supports MCP servers via its "Toolbox" feature.

## Key Findings

### Platform: cross-platform (testable on Windows)

Msty Studio Desktop ships prebuilt installers for:

- **Windows** (x64)
- **macOS** (Apple Silicon M1–M4 and Intel)
- **Linux** (AppImage and `.deb`)

There is also a "Msty Studio Web" browser version. The Windows build means the manual workflow *is* hands-on testable on a Windows machine — unlike RecurseChat or 5ire.

### Configuration: in-app UI with inline per-tool JSON, no external config file

MCP servers are added through the in-app UI: **Add New Tool** opens a window where the user defines the tool's name, configuration (entered as JSON), and notes. The configuration JSON for a local server uses `command` / `args` / `env`, but it is a **single tool's** configuration entered inline — **not** a `mcpServers`-keyed object like Claude Desktop / Cursor.

The [Toolbox documentation](https://docs.msty.ai/studio/toolbox/tools) does not document any external, user-editable config file path; configuration is managed through the UI and stored internally by the app.

### Transport

Both supported:

- **STDIO / JSON** for local MCP servers and tools
- **HTTP** for remote (streamable HTTP) MCP servers — the docs note SSE is deprecated in favor of streamable HTTP

So the Wolfram stdio server is transport-compatible.

## Why InstallMCPServer Cannot (Currently) Be Implemented

`InstallMCPServer` writes a known config file at a known path. Msty exposes no documented external config file — MCP tools are added through the "Add New Tool" UI with inline JSON, stored internally. There is also a format mismatch: Msty's tool dialog expects a single tool's `command`/`args`/`env`, whereas `MCPServerObject["Wolfram"]["JSONConfiguration"]` emits a `{"mcpServers": {"Wolfram": {…}}}` wrapper that would need manual extraction.

This is the same blocker as [Cherry Studio](cherry-studio.md): no external configuration file to target.

## Recommendation

**Reject support for `InstallMCPServer["Msty", ...]`** for now, because there is no documented external configuration file to write to.

**Revisit if** a stable, documented config file is later confirmed (e.g. under `%APPDATA%\Msty` on Windows). Because the Windows build is available, this is a quick check for a future contributor: install Msty, add one tool through the UI, and inspect the application-data directory for a human-readable, stable MCP config file. If one exists, Msty becomes implementable and would be treated like any other file-based JSON client.

### Manual workaround

1. Generate the JSON configuration: `MCPServerObject["Wolfram"]["JSONConfiguration"]`
2. Extract the inner server object's `command` / `args` / `env` (drop the `mcpServers` wrapper).
3. In Msty: Toolbox → Add New Tool → paste the configuration JSON.

## References

- [Msty Studio — Getting Started](https://docs.msty.ai/studio/getting-started)
- [Msty Studio — Toolbox / Tools](https://docs.msty.ai/studio/toolbox/tools)
- [Msty Studio — Download (platform list)](https://docs.msty.ai/studio/getting-started/download)
