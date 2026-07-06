<!-- cspell: ignore AAIF, direnv -->

# Goose MCP Client Research

## Overview

[Goose](https://github.com/block/goose) is an open source, extensible AI agent developed by Block (formerly Square) that goes beyond code suggestions to install, execute, edit, and test with any LLM. In December 2025, Block contributed Goose to the Linux Foundation's Agentic AI Foundation (AAIF). Goose seamlessly integrates with MCP servers and is available as both a desktop app and CLI.

## Configuration Details

### Config File Location

| Platform | Path |
|----------|------|
| macOS | `~/.config/goose/config.yaml` |
| Linux | `~/.config/goose/config.yaml` |
| Windows | `%APPDATA%\Block\goose\config\config.yaml` |

Note: Both Desktop and CLI share the same configuration file.

### YAML Format

Goose uses YAML format with an `extensions` key:

```yaml
extensions:
  my-server:
    name: My Server
    cmd: /path/to/command
    args: [arg1, arg2]
    enabled: true
    envs:
      "VAR_NAME": "value"
    type: stdio
    timeout: 300
```

### Supported Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name for the extension |
| `cmd` | string | Base command to execute |
| `args` | array | Command arguments as a list |
| `enabled` | boolean | Whether the extension is active |
| `envs` | object | Environment variables as key-value pairs |
| `type` | string | Connection type (`stdio`, `streamable_http`, etc.) |
| `timeout` | integer | Maximum seconds to wait for responses (default: 300) |

### Configuration Methods

1. **CLI Configuration**: Run `goose configure` and select "Add Extension"
2. **Manual Editing**: Directly edit `config.yaml`

### Project-Level Support

Goose does **not currently support project-level configuration**. Settings are global only. Users can work around this using:
- Environment variables (`GOOSE_PATH_ROOT`)
- Tools like `mise` or `direnv` for directory-specific settings

## Implementation Assessment

### Feasibility: **Fully Feasible**

Implementing `InstallMCPServer` support for Goose is straightforward:

1. **Standard Structure**: Uses familiar command/args/env pattern
2. **Known File Locations**: Documented paths for all platforms
3. **YAML Format**: Requires YAML serialization instead of JSON

### Implementation Notes

1. Add install location definitions for macOS, Linux, and Windows
2. Add canonical name `"Goose"`
3. Add display name `"Goose"`
4. Handle YAML format conversion (different from JSON clients)
5. Use `extensions` key instead of `mcpServers`
6. Map fields appropriately:
   - `command` → `cmd`
   - `args` → `args` (same)
   - `env` → `envs`
7. Add required fields: `enabled: true`, `type: "stdio"`, `timeout: 300`
8. Project-level support: **No** (not supported by Goose)

### Key Differences from Other Clients

| Aspect | Goose | Claude Desktop |
|--------|-------|----------------|
| Format | YAML | JSON |
| Top-level key | `extensions` | `mcpServers` |
| Command field | `cmd` | `command` |
| Environment field | `envs` | `env` |
| Requires `enabled` | Yes | No |
| Requires `type` | Yes | No |
| Project support | No | No |

### Proposed Configuration

| Field | Value |
|-------|-------|
| Canonical Name | `"Goose"` |
| Config Format | YAML (`extensions` key) |
| Project Support | No |

### Example Output

For a Wolfram MCP server, the generated config should look like:

```yaml
extensions:
  Wolfram:
    name: Wolfram
    cmd: /path/to/wolfram
    args: [-run, 'PacletSymbol["Wolfram/AgentTools","StartMCPServer"][]', -noinit, -noprompt]
    enabled: true
    envs:
      "MCP_SERVER_NAME": "WolframLanguage"
      "WOLFRAM_BASE": "/path/to/base"
      "WOLFRAM_USERBASE": "/path/to/userbase"
    type: stdio
    timeout: 300
```

## Implementation Complexity

**Medium** - Requires adding YAML support to `InstallMCPServer`. The existing codebase already handles TOML format for OpenAI Codex, so adding YAML should follow a similar pattern. The main work involves:

1. Adding a YAML serialization function (or using `ImportExport` with YAML)
2. Handling the different field naming conventions
3. Merging with existing `extensions` in the config file

## References

- [Goose GitHub Repository](https://github.com/block/goose)
- [Goose Documentation](https://block.github.io/goose/)
- [Using Extensions](https://block.github.io/goose/docs/getting-started/using-extensions/)
- [Configuration Files](https://block.github.io/goose/docs/guides/config-files/)
- [Getting Started with Goose on Windows](https://dev.to/lymah/getting-started-with-goose-on-windows-30bh)
