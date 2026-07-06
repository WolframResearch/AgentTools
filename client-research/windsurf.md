<!-- cspell: ignore Natoma -->

# Windsurf MCP Client Research

## Overview

[Windsurf](https://windsurf.com/) is an AI-powered IDE (formerly known as Codeium) that features Cascade, an AI agent that natively integrates with MCP servers. This document details how MCP servers are configured in Windsurf and assesses the feasibility of implementing `InstallMCPServer` support.

## Configuration Details

### Config File Location

| Platform | Path |
|----------|------|
| macOS/Linux | `~/.codeium/windsurf/mcp_config.json` |
| Windows | `%USERPROFILE%\.codeium\windsurf\mcp_config.json` |

### JSON Format

Windsurf uses the standard `mcpServers` JSON structure, identical to Claude Desktop:

```json
{
  "mcpServers": {
    "ServerName": {
      "command": "...",
      "args": ["..."],
      "env": {
        "KEY": "value"
      }
    }
  }
}
```

### Supported Fields

**For stdio/command-based servers:**
- `command` (string): The executable to run
- `args` (array): Arguments passed to the command
- `env` (object): Environment variables

**For remote HTTP servers:**
- `serverUrl` or `url` (string): The HTTP endpoint
- `headers` (object): Custom HTTP headers

### Special Features

- **Environment Variable Interpolation**: Supports `${env:VARIABLE_NAME}` syntax in `command`, `args`, `env`, `serverUrl`, `url`, and `headers` fields
- **OAuth Support**: Available for all transport types (stdio, Streamable HTTP, SSE)
- **Tool Limit**: Maximum of 100 total tools across all connected MCP servers

### Transport Types

Windsurf supports three transport types:
1. stdio (standard input/output)
2. Streamable HTTP
3. SSE (Server-Sent Events)

### Configuration Scope

- **Global only**: Configuration is at the user level only
- **No project-level support**: The documentation does not mention per-project MCP configuration

## Implementation Assessment

### Feasibility: **Fully Feasible**

Windsurf's MCP configuration is straightforward to implement because:

1. **Standard Format**: Uses the same `mcpServers` JSON structure as Claude Desktop, Cursor, and other clients already supported
2. **Simple File Location**: Single global config file per platform
3. **No Special Conversion**: No format conversion needed (unlike OpenCode or Codex)

### Implementation Notes

1. Add install location definitions for macOS/Linux and Windows
2. Add name aliases (e.g., "windsurf", "Codeium")
3. Add display name "Windsurf"
4. Uses standard format - no special handling in `installMCPServer` needed

### Proposed Configuration

| Field | Value |
|-------|-------|
| Canonical Name | `"Windsurf"` |
| Config Format | JSON (standard `mcpServers`) |
| Project Support | No |

## References

- [Official MCP Documentation](https://docs.windsurf.com/windsurf/cascade/mcp)
- [MCP Setup Tutorial](https://windsurf.com/university/tutorials/configuring-first-mcp-server)
- [Windsurf MCP Guide (BrainGrid)](https://www.braingrid.ai/blog/windsurf-mcp)
- [MCP Setup Guide (Natoma)](https://natoma.ai/blog/how-to-enabling-mcp-in-windsurf)
