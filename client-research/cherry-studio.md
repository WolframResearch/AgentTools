<!-- cspell: ignore leveldb -->

# Cherry Studio MCP Client Research

## Overview

[Cherry Studio](https://github.com/CherryHQ/cherry-studio) is an Electron-based desktop AI assistant application that supports multiple LLM providers and includes MCP server integration.

## Key Finding: No External Config File

**Cherry Studio does NOT use editable JSON configuration files for MCP servers.** Instead, MCP configurations are managed through:

- **Redux state management** in the renderer process
- **localStorage persistence** via `redux-persist`
- **UI-based configuration** through the Settings panel

This is confirmed in the [official GitHub discussion](https://github.com/CherryHQ/cherry-studio/discussions/7190):

> "The MCP configuration is not saved in a JSON file, but rather stored in the Redux state and persisted through redux-persist."

## Application Data Directories

While Cherry Studio does use standard application data directories, MCP configurations are NOT stored as files:

| OS | Application Data Directory |
|----|---------------------------|
| Windows | `%APPDATA%\Cherry Studio\` |
| macOS | `~/Library/Application Support/Cherry Studio/` |
| Linux | `~/.config/Cherry Studio/` |

The MCP configuration lives in the Electron app's localStorage, which is stored in:
- `Local Storage/leveldb/` subdirectory of the application data folder
- Accessible only through the app's internal Redux store

## MCP Server Configuration Format

When configuring MCP servers through the UI, Cherry Studio uses the following internal structure:

### STDIO Transport (Local Commands)

```json
{
  "id": "unique-nanoid",
  "name": "server-name",
  "type": "stdio",
  "command": "uvx",
  "args": ["mcp-server-fetch"],
  "env": {
    "API_KEY": "your-key"
  },
  "isActive": true,
  "timeout": 30
}
```

### SSE Transport (HTTP Server-Sent Events)

```json
{
  "id": "unique-nanoid",
  "name": "remote-server",
  "type": "sse",
  "baseUrl": "https://your-server-url.com/mcp",
  "headers": {
    "Authorization": "Bearer token"
  },
  "isActive": true
}
```

### Streamable HTTP Transport

```json
{
  "id": "unique-nanoid",
  "name": "streaming-server",
  "type": "streamableHttp",
  "baseUrl": "https://your-server-url.com/mcp",
  "headers": {},
  "isActive": true
}
```

## Configuration Fields

### Universal Fields (All Server Types)

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique identifier (nanoid format) |
| `name` | String | Display name for the server |
| `type` | String | Transport: `"stdio"`, `"sse"`, `"streamableHttp"`, or `"inMemory"` |
| `isActive` | Boolean | Current connection status |

### STDIO-Specific Fields

| Field | Type | Description |
|-------|------|-------------|
| `command` | String | Executable command (e.g., `npx`, `uvx`, binary path) |
| `args` | Array | Command-line arguments |
| `env` | Object | Environment variables as key-value pairs |
| `registryUrl` | String | Optional NPM/pip registry URL |

### Network Server Fields (SSE/Streamable HTTP)

| Field | Type | Description |
|-------|------|-------------|
| `baseUrl` | String | Server endpoint URL |
| `headers` | Object | HTTP headers for authentication |

### Optional Advanced Fields

| Field | Type | Description |
|-------|------|-------------|
| `timeout` | Number | Request timeout in seconds |
| `longRunning` | Boolean | Extended timeout flag |
| `disabledTools` | Array | Tool names to disable |
| `trust` | Boolean | Pre-approval eligibility flag |

## Project-Level Configuration

**Not supported.** Cherry Studio stores all MCP configurations at the application level. There is no project-level or workspace-level MCP configuration.

## Configuration Method

Users must configure MCP servers through the Cherry Studio UI:

1. Open Cherry Studio
2. Click Settings (gear icon)
3. Select "MCP Servers" from the left menu
4. Click "Add Server"
5. Fill in the required parameters
6. Click "Confirm" to save

There is a JSON editor within the UI for advanced configuration, but this still writes to the internal Redux store, not to an external file.

## Why InstallMCPServer Cannot Be Implemented

`InstallMCPServer` relies on writing to external configuration files that MCP clients read on startup. Cherry Studio's architecture prevents this approach:

1. **No config file path**: MCP configs are stored in localStorage/leveldb, not JSON files
2. **Internal state management**: Configuration is managed by Redux, not file I/O
3. **Electron isolation**: localStorage is sandboxed to the Electron app
4. **No documented API**: Cherry Studio doesn't expose an external API for adding MCP servers

The only way to add MCP servers to Cherry Studio is through its built-in UI.

## Recommendation

**Reject support for `InstallMCPServer["CherryStudio", ...]`** because:

- There is no external configuration file to write to
- The internal storage mechanism (Redux + localStorage) is not accessible to external tools
- Cherry Studio's architecture fundamentally differs from other MCP clients that use file-based configuration

## References

- [Cherry Studio GitHub Repository](https://github.com/CherryHQ/cherry-studio)
- [Official MCP Configuration Guide](https://docs.cherry-ai.com/docs/en-us/advanced-basic/mcp/config)
- [GitHub Discussion: Config File Location](https://github.com/CherryHQ/cherry-studio/discussions/7190)
- [MCP Architecture Documentation](https://deepwiki.com/CherryHQ/cherry-studio/6.1-mcp-architecture)
- [MCP Server Management](https://deepwiki.com/CherryHQ/cherry-studio/6.2-mcp-server-management)
