<!-- cspell: ignore nanbingxyz, pglite -->

# 5ire MCP Client Research

## Overview

[5ire](https://5ire.app/) is an open-source ([github.com/nanbingxyz/5ire](https://github.com/nanbingxyz/5ire)) cross-platform desktop AI assistant and MCP client. It supports chatting with major providers plus a local knowledge base and tools via MCP servers.

## Key Findings

### Configuration: internal database (pglite), no external config file

5ire stores its configuration — including MCP server definitions — in an **internal database**. The storage engine was migrated from SQLite + LanceDB to **pglite** (Postgres compiled to WASM). MCP servers are added through the in-app UI (Tools → New/Local for stdio, or remote), and 5ire writes the configuration into its own database; "5ire will create configuration on its own."

There is no documented external, user-editable config file (no `mcp.json`-style file) that `InstallMCPServer` could write to.

### Server configuration shape

A valid 5ire server entry requires a `name` (letters/hyphens/numbers, length > 1, not starting with a number or ending with a hyphen) and either a `url` (remote) or a `command` (local stdio), with optional `args`, `env`, and `headers`. Example stdio entry:

```json
{
  "name": "Blender",
  "description": "A Blender MCP server …",
  "command": "uvx",
  "args": ["blender-mcp"]
}
```

This is a per-server object, not a `mcpServers`-keyed object, and it is entered through the UI rather than a file.

### Transport

Both local **stdio** (`command`/`args`/`env`) and **remote** (`url`/`headers`) are supported, so the Wolfram stdio server is transport-compatible.

### Platform: no Windows prebuilt binary

Although the README calls 5ire "cross-platform," the latest release (v0.15.4) ships installers only for:

- **macOS** (`.dmg`, `.zip` — arm64 and x86_64)
- **Linux** (`.AppImage` — x86_64)

There is **no Windows `.exe`/`.msi`** in the release assets. Running it on Windows would require building from source (Node/TypeScript), so it is not realistically hands-on testable on Windows.

## Why InstallMCPServer Cannot Be Implemented

Two independent blockers, either of which is disqualifying:

1. **No external config file.** Configuration lives in an internal pglite database managed by the app — the same architectural blocker as [Cherry Studio](cherry-studio.md). `InstallMCPServer` has nothing to write to, and writing into the app's database is not a supported or stable integration point.
2. **No Windows build.** The integration cannot be developed or hands-on tested on Windows without building from source.

## Recommendation

**Reject support for `InstallMCPServer["5ire", ...]`** because the configuration is stored in an internal database with no external config file, and there is no Windows binary for testing.

### Manual workaround (Mac/Linux users)

Add the Wolfram server through 5ire's UI (Tools → New/Local) using `command` = the Wolfram executable path and the appropriate `args`/`env`, which can be read off `MCPServerObject["Wolfram"]["JSONConfiguration"]`.

## References

- [5ire docs](https://5ire.app/docs)
- [5ire GitHub repository](https://github.com/nanbingxyz/5ire)
- [5ire releases (platform binaries)](https://github.com/nanbingxyz/5ire/releases)
- [Tools & MCP Servers — DeepWiki](https://deepwiki.com/nanbingxyz/5ire/5-tools-and-mcp-servers)
