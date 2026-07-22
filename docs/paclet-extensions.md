# Paclet Extensions

This document describes how third-party Wolfram Language paclets can extend AgentTools with additional MCP tools, prompts, and servers using the `"AgentTools"` paclet extension.

## Overview

The paclet extension system allows any Wolfram Language paclet to contribute MCP tools, prompts, and servers to the AgentTools ecosystem. Paclets declare their contributions in `PacletInfo.wl` using an `"AgentTools"` extension, and AgentTools discovers and integrates them automatically.

This enables:
- **Third-party tool distribution** via the [Wolfram Paclet Repository](https://resources.wolframcloud.com/PacletRepository)
- **Domain-specific servers** bundled with specialized paclets
- **Cross-paclet composition** where servers can reference tools from other paclets

## Declaring an Extension

Add an `"AgentTools"` extension to your paclet's `PacletInfo.wl`:

```wl
PacletObject[<|
    "Name"       -> "PublisherID/MyPaclet",
    "Version"    -> "1.0.0",
    "Extensions" -> {
        { "AgentTools",
            "Root"       -> "AgentTools",
            "MCPServers" -> { "MyServer" },
            "Tools"      -> {
                { "MyTool", "Description of my tool" }
            },
            "MCPPrompts" -> { "MyPrompt" }
        }
    }
|>]
```

### Extension Properties

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `"Root"` | String | No | `"AgentTools"` | Subdirectory containing definition files |
| `"MCPServers"` | List | No | `{}` | Declared server configurations |
| `"Tools"` | List | No | `{}` | Declared tool definitions |
| `"MCPPrompts"` | List | No | `{}` | Declared prompt definitions |

### Declaration Formats

Each item in `"MCPServers"`, `"Tools"`, or `"MCPPrompts"` can use one of three formats:

| Format | Example | Use Case |
|--------|---------|----------|
| Name only | `"MyTool"` | Minimal declaration |
| Name + Description | `{ "MyTool", "Does something" }` | Adds metadata for discovery |
| Association | `<\| "Name" -> "MyTool", ... \|>` | Full metadata including parameters |

## Definition Files

Each declared item must have a corresponding definition file under the extension root directory.

### File Layout

**Per-item files** (recommended):

```
AgentTools/
    MCPServers/MyServer.wl
    Tools/MyTool.wl
    MCPPrompts/MyPrompt.wl
```

**Combined files** (alternative for simpler paclets):

```
AgentTools/
    Tools.wl          (* Returns <| "MyTool" -> <| ... |>, ... |> *)
```

Per-item files take precedence over combined files. Supported formats: `.mx`, `.wxf`, `.wl` (checked in that order).

### Tool Definition Files

A tool definition file must evaluate to an association with required keys:

```wl
(* AgentTools/Tools/MyTool.wl *)
<|
    "Name"        -> "MyTool",
    "Description" -> "Does something useful",
    "Function"    -> MyPackage`myToolFunction,
    "Parameters"  -> {
        "input" -> <|
            "Interpreter" -> "String",
            "Help"        -> "The input value",
            "Required"    -> True
        |>
    }
|>
```

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `"Name"` | String | Yes | MCP-exposed tool name |
| `"Function"` | Symbol | Yes | Wolfram Language function to call |
| `"Parameters"` | List | Yes | Parameter specifications |
| `"Description"` | String | No | Tool description |
| `"DisplayName"` | String | No | Human-readable display name |
| `"Initialization"` | Delayed | No | Setup code run at server start |
| `"Options"` | List | No | Tool options |

### Server Definition Files

A server definition file must evaluate to an association with an `"LLMEvaluator"` key:

```wl
(* AgentTools/MCPServers/MyServer.wl *)
<|
    "Name"           -> "MyServer",
    "Initialization" :> Needs["PublisherID`MyPaclet`"],
    "LLMEvaluator"   -> <|
        "Tools"      -> { "MyTool", "AnotherTool" },
        "MCPPrompts" -> { "MyPrompt" }
    |>,
    "ServerVersion"  -> "1.0.0"
|>
```

Tool and prompt names within a server definition are automatically qualified to the owning paclet at load time. For example, `"MyTool"` becomes `"PublisherID/MyPaclet/MyTool"`.

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `"LLMEvaluator"` | Association | Yes | Server configuration with `"Tools"` and/or `"MCPPrompts"` |
| `"Name"` | String | No | Server name |
| `"Initialization"` | Delayed | No | Setup code run at server start (use `:>`) |
| `"ServerVersion"` | String | No | Version string (defaults to paclet version) |
| `"Transport"` | String | No | Transport type (defaults to `"StandardInputOutput"`) |

### Prompt Definition Files

A prompt definition file must evaluate to an association with a `"Name"` key:

```wl
(* AgentTools/MCPPrompts/MyPrompt.wl *)
<|
    "Name"        -> "MyPrompt",
    "Description" -> "Provides context about something",
    "Arguments"   -> {
        <| "Name" -> "topic", "Description" -> "The topic", "Required" -> True |>
    },
    "Type"        -> "Function",
    "Content"     -> MyPackage`myPromptFunction
|>
```

## Qualified Names

Paclet-contributed items are referenced using qualified names. Two formats are supported:

- **2-segment**: `"PacletName/ItemName"` — for paclets without a publisher ID
- **3-segment**: `"PublisherID/PacletShortName/ItemName"` — for paclets with a publisher ID (the first two segments form the paclet name `"PublisherID/PacletShortName"`)

```wl
(* 2-segment: paclet without publisher ID *)
MCPServerObject["MyPaclet/MyServer"]

(* 3-segment: paclet with publisher ID *)
CreateMCPServer["MyServer", <|
    "Tools" -> { "PublisherID/MyPaclet/MyTool" }
|>]

MCPServerObject["PublisherID/MyPaclet/MyServer"]

InstallMCPServer["ClaudeCode", "PublisherID/MyPaclet/MyServer"]
```

### Name Resolution

| Context | Resolution |
|---------|------------|
| User code (`CreateMCPServer`, etc.) | Built-in tools checked first, then paclet-qualified names |
| Within a paclet's own server definition | Own paclet items first, then built-in, then fully qualified cross-paclet references |
| Cross-paclet reference | Must use fully qualified name (e.g., `"OtherPublisher/OtherPaclet/ToolName"`) |

## Discovering Paclet Servers

### Listing Servers

`MCPServerObjects` discovers servers from installed paclets automatically:

```wl
(* File-based + installed paclet servers *)
MCPServerObjects[]

(* Also include servers from uninstalled paclets in the Paclet Repository *)
MCPServerObjects["IncludeRemotePaclets" -> True]
```

### MCPServerObjects Options

| Option | Default | Description |
|--------|---------|-------------|
| `"IncludeBuiltIn"` | `False` | Include built-in servers from `$DefaultMCPServers` |
| `"IncludeRemotePaclets"` | `False` | Include servers from uninstalled paclets in the Paclet Repository |
| `UpdatePacletSites` | `Automatic` | Force refresh of cached remote paclet data |

### Inspecting a Paclet Server

```wl
server = MCPServerObject["PublisherID/MyPaclet/MyServer"];
server["Name"]       (* "PublisherID/MyPaclet/MyServer" *)
server["Tools"]      (* List of resolved LLMTool objects *)
server["Location"]   (* PacletObject[...] *)
```

For uninstalled paclets, properties that require loading definition files return a `Failure["PacletNotInstalled", ...]` with install instructions.

## MCP Name Collision Handling

When multiple tools in a server share the same MCP-exposed name (e.g., tools from different paclets both named `"Search"`), `StartMCPServer` automatically disambiguates by appending numeric suffixes (`"Search1"`, `"Search2"`). The AI uses tool descriptions to select the correct one.

## Server Initialization

Paclet servers can include initialization code that runs at server start time:

```wl
<|
    "Initialization" :> Needs["PublisherID`MyPaclet`"],
    ...
|>
```

Use `RuleDelayed` (`:>`) so the initialization code is evaluated dynamically when the server starts, not when the definition file is loaded.

## Validation

Use `ValidateAgentToolsPacletExtension` to check your extension before publishing:

```wl
paclet = PacletObject["PublisherID/MyPaclet"];
ValidateAgentToolsPacletExtension[paclet]
(* Success["ValidAgentToolsPacletExtension", <| "MCPServers" -> ..., "Tools" -> ..., "MCPPrompts" -> ... |>] *)
```

The validator checks:
- Extension structure and valid keys in `PacletInfo.wl`
- Definition file existence for all declared items
- File contents evaluate to valid associations with required keys
- Cross-references between servers and tools/prompts are resolvable

## Security Model

Operations on paclet extensions follow three trust levels:

| Level | Operations | Behavior |
|-------|-----------|----------|
| **Discovery** | `MCPServerObjects[]`, `PacletFind` | Reads PacletInfo metadata; may load definition files for installed paclets; never installs paclets |
| **Inspection** | `MCPServerObject[...]["Tools"]` | Loads definition files from installed paclets |
| **Execution** | `StartMCPServer`, `InstallMCPServer` | Executes tool functions and initialization; auto-installs referenced paclets |

## Related Files

- `Kernel/PacletExtension.wl` - Core paclet discovery, parsing, and resolution
- `Kernel/ValidateAgentToolsPacletExtension.wl` - Extension validation
- `Kernel/CommonSymbols.wl` - Shared symbol declarations for paclet extension functions
- `Kernel/Messages.wl` - Error messages for paclet extension operations
- `Kernel/MCPServerObject.wl` - Paclet server integration into server objects
- `Kernel/Server/Shared.wl` - Paclet dependency resolution and initialization at server start
- `Kernel/InstallMCPServer.wl` - Paclet reference validation at install time
- `Tests/PacletExtension.wlt` - Tests for paclet extension loading and resolution
- `Tests/ValidateAgentToolsPacletExtension.wlt` - Tests for extension validation
- `Specs/PacletExtension.md` - Design specification

## Related Documentation

- [tools.md](tools.md) - MCP tools system and how to define tools
- [mcp-prompts.md](mcp-prompts.md) - MCP prompts system and how to define prompts
- [servers.md](servers.md) - Predefined servers and custom server creation
- [mcp-clients.md](mcp-clients.md) - Client installation and configuration
