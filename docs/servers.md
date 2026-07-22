# Predefined MCP Servers

This document describes the predefined MCP servers available in AgentTools and helps you choose the right one for your needs.

## Overview

AgentTools provides four predefined server configurations, each tailored for different use cases. These are available via `$DefaultMCPServers` and can be installed into MCP clients using `InstallMCPServer`.

| Server | Primary Use Case |
|--------|------------------|
| `Wolfram` | General-purpose: Wolfram Language + Wolfram Alpha |
| `WolframAlpha` | Natural language queries via Wolfram Alpha |
| `WolframLanguage` | Wolfram Language development with notebook support |
| `WolframPacletDevelopment` | Paclet development with documentation tools |

## Choosing a Server

### Wolfram

**Best for:** General-purpose use combining computational power with natural language understanding.

```wl
InstallMCPServer["ClaudeDesktop", "Wolfram"]
```

This is the default server for chat clients (`ClaudeDesktop`, `Goose`) when no server name is specified. Coding clients default to `"WolframLanguage"` instead — see [mcp-clients.md](mcp-clients.md#clients-with-installmcpserver-support) for each client's default. It provides:

| Component | Name | Description |
|-----------|------|-------------|
| Tool | `WolframContext` | Semantic search across Wolfram resources (documentation, Wolfram Alpha, repositories, and more) |
| Tool | `WolframLanguageEvaluator` | Execute Wolfram Language code |
| Tool | `WolframAlpha` | Natural language queries to Wolfram Alpha |
| Prompt | `Search` | Combined documentation and Wolfram Alpha search |

**Use this when:** You want a balanced mix of code execution, documentation lookup, and natural language computation.

### WolframAlpha

**Best for:** Natural language queries without code execution.

```wl
InstallMCPServer["ClaudeDesktop", "WolframAlpha"]
```

This server focuses on Wolfram Alpha's natural language capabilities:

| Component | Name | Description |
|-----------|------|-------------|
| Tool | `WolframAlphaContext` | Semantic search for Wolfram Alpha results |
| Tool | `WolframAlpha` | Natural language queries to Wolfram Alpha |
| Prompt | `Search` | Wolfram Alpha search |

**Use this when:** You need computational knowledge (math, science, data) without running Wolfram Language code.

### WolframLanguage

**Best for:** Wolfram Language development and learning.

```wl
InstallMCPServer["ClaudeCode", "WolframLanguage"]
```

This server provides comprehensive Wolfram Language development tools:

| Component | Name | Description |
|-----------|------|-------------|
| Tool | `WolframLanguageContext` | Semantic search across Wolfram Language resources (documentation, repositories, and more) |
| Tool | `WolframLanguageEvaluator` | Execute Wolfram Language code |
| Tool | `ReadNotebook` | Read Wolfram notebooks (.nb) as markdown |
| Tool | `WriteNotebook` | Convert markdown to Wolfram notebooks |
| Tool | `SymbolDefinition` | Look up symbol definitions |
| Tool | `CodeInspector` | Inspect Wolfram Language code for issues |
| Tool | `TestReport` | Run Wolfram Language test files (.wlt) |
| Prompt | `Search` | Wolfram Language documentation search |
| Prompt | `Notebook` | Attach notebook contents to context |

**Use this when:** You're developing Wolfram Language code, working with notebooks, or learning the language.

### WolframPacletDevelopment

**Best for:** Developing and maintaining Wolfram paclets.

```wl
InstallMCPServer[{"ClaudeCode", "/path/to/paclet"}, "WolframPacletDevelopment"]
```

This server extends `WolframLanguage` with paclet documentation and development tools:

| Component | Name | Description |
|-----------|------|-------------|
| Tool | `WolframLanguageContext` | Semantic search across Wolfram Language resources (documentation, repositories, and more) |
| Tool | `WolframLanguageEvaluator` | Execute Wolfram Language code |
| Tool | `ReadNotebook` | Read Wolfram notebooks (.nb) as markdown |
| Tool | `WriteNotebook` | Convert markdown to Wolfram notebooks |
| Tool | `SymbolDefinition` | Look up symbol definitions |
| Tool | `CodeInspector` | Inspect Wolfram Language code for issues |
| Tool | `TestReport` | Run Wolfram Language test files (.wlt) |
| Tool | `CreateSymbolDoc` | Create new symbol documentation pages |
| Tool | `EditSymbolDoc` | Edit existing symbol documentation |
| Tool | `EditSymbolDocExamples` | Edit example sections in documentation |
| Tool | `CheckPaclet` | Check a paclet for issues (missing metadata, invalid structure, etc.) |
| Tool | `BuildPaclet` | Build a paclet archive (.paclet) for distribution |
| Tool | `SubmitPaclet` | Submit a paclet to the Wolfram Language Paclet Repository |
| Prompt | `Search` | Wolfram Language documentation search |
| Prompt | `Notebook` | Attach notebook contents to context |

**Use this when:** You're developing a Wolfram paclet and need to create or maintain documentation notebooks, or check/build/submit paclets.

## Server Comparison

### Tools by Server

| Tool | Wolfram | WolframAlpha | WolframLanguage | WolframPacletDevelopment |
|------|:-------:|:------------:|:---------------:|:------------------------:|
| `WolframContext` | X | | | |
| `WolframAlphaContext` | | X | | |
| `WolframLanguageContext` | | | X | X |
| `WolframLanguageEvaluator` | X | | X | X |
| `WolframAlpha` | X | X | | |
| `ReadNotebook` | | | X | X |
| `WriteNotebook` | | | X | X |
| `SymbolDefinition` | | | X | X |
| `CodeInspector` | | | X | X |
| `TestReport` | | | X | X |
| `CreateSymbolDoc` | | | | X |
| `EditSymbolDoc` | | | | X |
| `EditSymbolDocExamples` | | | | X |
| `CheckPaclet` | | | | X |
| `BuildPaclet` | | | | X |
| `SubmitPaclet` | | | | X |

### Prompts by Server

| Prompt (MCP Name) | Wolfram | WolframAlpha | WolframLanguage | WolframPacletDevelopment |
|-------------------|:-------:|:------------:|:---------------:|:------------------------:|
| `Search` | X | X | X | X |
| `Notebook` | | | X | X |

Note: The `Search` prompt has different implementations depending on the server:
- **Wolfram**: Searches both documentation and Wolfram Alpha
- **WolframAlpha**: Searches Wolfram Alpha only
- **WolframLanguage/WolframPacletDevelopment**: Searches documentation only

## Shared Config Key

All built-in servers share the config key `"Wolfram"` in client configuration files (via the `"MCPServerName"` property). This means they are **mutually exclusive** — installing one built-in server variant replaces any previously installed built-in variant in the same client:

```wl
InstallMCPServer["ClaudeDesktop", "Wolfram"]
InstallMCPServer["ClaudeDesktop", "WolframLanguage"]
(* Only "WolframLanguage" remains, under the "Wolfram" config key *)
```

This is intentional: the built-in servers are different configurations of the same Wolfram MCP server and should not run simultaneously. To override this behavior, use the `"MCPServerName"` option (see [mcp-clients.md](mcp-clients.md#mcpservername)).

## Using Predefined Servers

### Installation

Install a server into an MCP client:

```wl
(* Install default (Wolfram) server *)
InstallMCPServer["ClaudeDesktop"]

(* Install a specific server *)
InstallMCPServer["ClaudeCode", "WolframLanguage"]

(* Install to a project directory *)
InstallMCPServer[{"ClaudeCode", "/path/to/project"}, "WolframPacletDevelopment"]
```

See [mcp-clients.md](mcp-clients.md) for details on supported clients and installation options.

### Accessing Server Objects

Get a server object programmatically:

```wl
(* Get all predefined servers *)
$DefaultMCPServers
(* <|"Wolfram" -> MCPServerObject[...], ...|> *)

(* Get a specific server *)
MCPServerObject["WolframLanguage"]
```

### Server Properties

Query server properties:

```wl
server = MCPServerObject["WolframLanguage"];
server["Name"]           (* "WolframLanguage" *)
server["Tools"]          (* List of LLMTool objects *)
server["MCPPrompts"]     (* List of prompt definitions *)
server["JSONConfiguration"]  (* JSON config for manual setup *)
```

## Creating Custom Servers

If the predefined servers don't meet your needs, you can create custom servers with `CreateMCPServer`.

### Basic Custom Server

```wl
CreateMCPServer["MyServer", <|
    "Tools" -> {"WolframLanguageEvaluator", "WolframAlpha"}
|>]
```

### Mixing Predefined and Custom Tools

```wl
CreateMCPServer["MyServer", <|
    "Tools" -> {
        "WolframLanguageEvaluator",
        LLMTool @ <|
            "Name" -> "CustomTool",
            "Description" -> "My custom tool",
            "Function" -> myFunction,
            "Parameters" -> {"input" -> <|"Interpreter" -> "String"|>}
        |>
    }
|>]
```

### Adding Custom Prompts

```wl
CreateMCPServer["MyServer", <|
    "Tools" -> {"WolframLanguageEvaluator"},
    "MCPPrompts" -> {
        "WolframLanguageSearch",
        <|
            "Name" -> "Greet",
            "Description" -> "Generates a greeting",
            "Arguments" -> {<|"Name" -> "name", "Required" -> True|>},
            "Type" -> "Text",
            "Content" -> StringTemplate["Hello, `name`!"]
        |>
    }
|>]
```

See [tools.md](tools.md) and [mcp-prompts.md](mcp-prompts.md) for details on creating custom tools and prompts.

### Server Initialization

Custom servers can include initialization code that runs when the server starts:

```wl
CreateMCPServer["MyServer", <|
    "Tools" -> {"WolframLanguageEvaluator"}
|>, Initialization :> Needs["MyPackage`"]]
```

The `Initialization` option accepts an expression that will be evaluated at server start time before any tools are invoked.

### CreateMCPServer Options

| Option | Default | Description |
|--------|---------|-------------|
| `OverwriteTarget` | `False` | Overwrite an existing server with the same name |
| `IncludeDefinitions` | `True` | Include function definitions in the serialized server |
| `Initialization` | `None` | Code to evaluate when the server starts |

## LLMKit Requirements

Some tools require an [LLMKit subscription](https://www.wolfram.com/notebook-assistant-llm-kit/) for full functionality:

| Tool | LLMKit Dependency |
|------|-------------------|
| `WolframContext` | Suggested |
| `WolframAlphaContext` | Required |
| `WolframLanguageContext` | Suggested |
| Other tools | Not required |

Not having an LLMKit subscription will have the following effects:
- `WolframContext` will not provide reranking or filtering and will not include any Wolfram\|Alpha results
- `WolframAlphaContext` will not function at all
- `WolframLanguageContext` will only provide basic semantic search without reranking or filtering

Other tools (e.g. `WolframLanguageEvaluator`, `WolframAlpha`) do not depend on LLMKit.

## MCP Apps Support

All predefined servers support [MCP Apps](mcp-apps.md) when the client advertises the `io.modelcontextprotocol/ui` extension. When active, the `WolframAlpha` and `WolframLanguageEvaluator` tools are automatically enhanced with interactive UI (e.g., embedded cloud notebook viewers). No server configuration changes are needed; capability negotiation happens automatically during `initialize`.

To disable MCP Apps for a specific installation, use:

```wl
InstallMCPServer["ClaudeDesktop", "EnableMCPApps" -> False]
```

## MCP Roots Support

All predefined servers support the [MCP roots](mcp-roots.md) handshake. When a client advertises the `roots` capability (e.g., Claude Code passing the project directory the user opened), the server queries `roots/list`, picks the first valid directory, and propagates it to the kernel, the local evaluator, and tools that invoke external processes (`TestReport`). Relative paths the LLM passes to a tool then resolve against the user's project rather than against the server's startup directory.

If the client does not advertise `roots`, no `roots/list` request is sent and tools fall back to the kernel's original working directory. No server configuration is required either way.

## Paclet-Backed Servers

Third-party paclets can contribute MCP servers via the `"AgentTools"` paclet extension. These servers are referenced using paclet-qualified names:

```wl
(* View a paclet-backed server *)
MCPServerObject["PublisherID/MyPaclet/ServerName"]

(* Install a paclet-backed server *)
InstallMCPServer["ClaudeCode", "PublisherID/MyPaclet/ServerName"]
```

Paclet servers appear alongside file-based and built-in servers when listing with `MCPServerObjects[]`. Use `"IncludeRemotePaclets" -> True` to also discover servers from uninstalled paclets in the Paclet Repository.

See [paclet-extensions.md](paclet-extensions.md) for details on how paclets declare servers, tools, and prompts.

## Deploying a Server to the Cloud

Any `MCPServerObject` — predefined or custom — can be deployed as a remote HTTP MCP server in the Wolfram Cloud, reachable by clients such as the OpenAI Responses API and the Anthropic Messages API without a local kernel:

```wl
CloudDeploy[MCPServerObject["WolframLanguage"]]
```

This returns a `CloudObject` directory containing the live `/mcp` endpoint, a landing page with client-configuration snippets, and an owner-only admin page for managing API keys. See [cloud-deployment.md](cloud-deployment.md) for the full workflow, directory layout, authentication, and the stateless evaluation model.

## Related Documentation

- [tools.md](tools.md) - Detailed tool documentation, [tool options](tools.md#tool-options), and creating custom tools
- [mcp-prompts.md](mcp-prompts.md) - Prompt system and creating custom prompts
- [mcp-apps.md](mcp-apps.md) - MCP Apps system for interactive UI resources
- [mcp-clients.md](mcp-clients.md) - Client installation, configuration, and the [`"MCPServerName"` option](mcp-clients.md#mcpservername)
- [deploy-agent-tools.md](deploy-agent-tools.md) - Managed deployment of tools to agent clients
- [cloud-deployment.md](cloud-deployment.md) - Deploying a server as a remote HTTP MCP server in the Wolfram Cloud
- [paclet-extensions.md](paclet-extensions.md) - Third-party paclet extension system
- [getting-started.md](getting-started.md) - Development setup
