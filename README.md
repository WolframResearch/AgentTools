# [Wolfram/AgentTools](https://paclets.com/Wolfram/AgentTools)

[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Wolfram Version](https://img.shields.io/badge/Wolfram-14.3%2B-red.svg)](https://www.wolfram.com/language/)

A Wolfram Language toolkit for integrating with AI agents and LLMs — providing [MCP](https://modelcontextprotocol.io) servers, agent skills, and other standard interfaces that give AI systems access to Wolfram's computational capabilities.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Predefined Servers](#predefined-servers)
- [Supported Clients](#supported-clients)
- [Available Tools](#available-tools)
- [Creating Custom Servers](#creating-custom-servers)
- [API Reference](#api-reference)
- [Development](#development)
- [License](#license)

## Features

- **Predefined servers** for common use cases (general computation, Wolfram\|Alpha queries, development)
- **Semantic search** across Wolfram documentation and Wolfram\|Alpha results
- **Code evaluation** with Wolfram Language directly in AI conversations
- **Notebook support** for reading and writing Wolfram notebooks
- **Custom servers** with tailored tools for specific needs
- **Wide client support** including Claude Desktop, Cursor, VS Code, and more
- **MCP prompts** for enhanced context and workflows
- **MCP Apps** for interactive UI resources in supported clients (e.g., embedded notebook viewers, Wolfram\|Alpha result displays)
- **MCP Roots** support so the server, evaluator, and external tools (`TestReport` and similar) resolve relative paths against the client's project directory
- **Agent Skills** for distributing Wolfram tools as portable skills to AI coding agents (Claude Code, Cursor, Gemini CLI, VS Code, and [more](https://agentskills.io/))
- **Paclet extensions** allowing third-party paclets to contribute MCP tools, prompts, and servers via the `"AgentTools"` extension
- **Docker image** for running the MCP server in a container without a local Wolfram Engine installation

## Requirements

- Wolfram Language 14.3 or higher
- An MCP-compatible client application (see [Supported Clients](#supported-clients))
- Optional: [LLMKit subscription](https://www.wolfram.com/notebook-assistant-llm-kit) for enhanced semantic search capabilities

## Installation

### Install the Paclet

```wl
PacletInstall["Wolfram/AgentTools"]
```

### Load the Package

```wl
Needs["Wolfram`AgentTools`"]
```

### Docker Image

A prebuilt Docker image is available as an alternative to a local Wolfram Engine installation. See [Docker documentation](docs/docker.md) for setup and MCP client configuration examples.

```bash
docker pull ghcr.io/wolframresearch/mcpserver:latest
```

## Quick Start

Install a Wolfram MCP server for Claude Desktop:

```wl
InstallMCPServer["ClaudeDesktop"]
(* Out: Success["InstallMCPServer", <|...|>] *)
```

When no server is specified, each named client gets a sensible default — chat clients (Claude Desktop, Goose) get the general-purpose `"Wolfram"` server, while coding clients (Claude Code, Cursor, VS Code, etc.) get `"WolframLanguage"`. For `File[...]` targets, the same per-client default applies when the path or content identifies a known client (or `"ApplicationName"` is supplied); otherwise it falls back to `"Wolfram"`. Pass an explicit server name as the second argument to override.

After restarting Claude Desktop, it will have access to Wolfram knowledge and tools:

![Claude Desktop Screenshot](.github/images/sk6raevruc0q.png)

To install a specific server type:

```wl
InstallMCPServer["ClaudeDesktop", "WolframLanguage"]
```

To uninstall:

```wl
UninstallMCPServer["ClaudeDesktop"]              (* Remove all servers *)
UninstallMCPServer["ClaudeDesktop", "Wolfram"]   (* Remove specific server *)
```

## Predefined Servers

AgentTools includes four predefined server configurations, each optimized for different use cases:

| Server | Best For | Tools |
|--------|----------|-------|
| **Wolfram** (default) | General-purpose use combining computational power with natural language | `WolframContext`, `WolframLanguageEvaluator`, `WolframAlpha` |
| **WolframAlpha** | Natural language queries without code execution | `WolframAlphaContext`*, `WolframAlpha` |
| **WolframLanguage** | Wolfram Language development and learning | `WolframLanguageContext`, `WolframLanguageEvaluator`, `ReadNotebook`, `WriteNotebook`, `SymbolDefinition`, `CodeInspector`, `TestReport` |
| **WolframPacletDevelopment** | Developing and maintaining Wolfram paclets | All WolframLanguage tools plus documentation tools (`CreateSymbolDoc`, `EditSymbolDoc`, `EditSymbolDocExamples`) and paclet release tools (`CheckPaclet`, `BuildPaclet`, `SubmitPaclet`) |

*\*Requires [LLMKit subscription](https://www.wolfram.com/notebook-assistant-llm-kit)*

Install a specific server:

```wl
InstallMCPServer["ClaudeDesktop", "WolframLanguage"]
```

See [docs/servers.md](docs/servers.md) for detailed information about each server and guidance on choosing the right one.

## Supported Clients

AgentTools can be installed into the following MCP client applications:

| Client | Name | Project Support |
|--------|------|-----------------|
| [Amazon Q Developer](https://aws.amazon.com/q/developer/) | `"AmazonQ"` | Yes |
| [Augment Code](https://www.augmentcode.com) | `"AugmentCode"` | No |
| [Augment Code IDE](https://marketplace.visualstudio.com/items?itemName=augment.vscode-augment) | `"AugmentCodeIDE"` | No |
| [Claude Code](https://code.claude.com) | `"ClaudeCode"` | Yes |
| [Claude Desktop](https://claude.ai/download) | `"ClaudeDesktop"` | No |
| [Cline](https://cline.bot) | `"Cline"` | No |
| [Copilot CLI](https://github.com/features/copilot/cli) | `"CopilotCLI"` | No |
| [Cursor](https://www.cursor.com) | `"Cursor"` | No |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `"GeminiCLI"` | No |
| [Goose](https://block.github.io/goose/) | `"Goose"` | No |
| [Google Antigravity](https://antigravity.google) | `"Antigravity"` | No |
| [OpenAI Codex](https://openai.com/codex) | `"Codex"` | Yes |
| [OpenCode](https://opencode.ai) | `"OpenCode"` | Yes |
| [Visual Studio Code](https://code.visualstudio.com) | `"VisualStudioCode"` | Yes |
| [Windsurf](https://codeium.com/windsurf) | `"Windsurf"` | No |
| [Zed](https://zed.dev) | `"Zed"` | Yes |

### Project-Level Installation

Clients with project support can have servers installed for specific projects:

```wl
InstallMCPServer[{"ClaudeCode", "/path/to/project"}, "WolframLanguage"]
```

### Claude Desktop

Claude Desktop offers an excellent integration experience with AgentTools, providing seamless access to Wolfram Language's computational capabilities.

### Cursor

Install an MCP server for use in Cursor:

```wl
InstallMCPServer["Cursor"]
(* Out: Success["InstallMCPServer", <|...|>] *)
```

Check the MCP tab in Cursor settings to verify the server connection:

![Cursor MCP Settings Screenshot](.github/images/nldzo3f42xid.png)

Your Wolfram tools will now be available in Cursor agent chat:

![Cursor MCP Chat Screenshot](.github/images/o6ltldxumzkx.png)

### Other Clients

AgentTools works with any stdio-based MCP client. See [docs/mcp-clients.md](docs/mcp-clients.md) for manual configuration instructions.

## Available Tools

AgentTools provides a variety of tools organized by category:

### Context Tools (Semantic Search)

Search Wolfram resources using semantic similarity:

- **WolframContext** - Combines the functionality of `WolframLanguageContext` and `WolframAlphaContext` in a single tool
- **WolframAlphaContext** - Semantic search of Wolfram\|Alpha results (requires [LLMKit](https://www.wolfram.com/notebook-assistant-llm-kit))
- **WolframLanguageContext** - Semantic search of Wolfram Language documentation and other resources

> **Note:** Since `WolframContext` combines the other two, a server should only include one of these three tools. Without LLMKit, `WolframContext` is effectively the same as `WolframLanguageContext` since the Wolfram\|Alpha semantic search functionality is disabled.

Documentation search includes the [Function Repository](https://resources.wolframcloud.com/FunctionRepository), [Data Repository](https://datarepository.wolframcloud.com), [Neural Net Repository](https://resources.wolframcloud.com/NeuralNetRepository), [Paclet Repository](https://resources.wolframcloud.com/PacletRepository), and more.

While only `WolframAlphaContext` *requires* an [LLMKit subscription](https://www.wolfram.com/notebook-assistant-llm-kit), having LLMKit greatly improves search results for all context tools by enabling reranking and filtering.

### Code Execution Tools

- **WolframLanguageEvaluator** - Execute Wolfram Language code with time constraints
- **WolframAlpha** - Natural language queries to Wolfram\|Alpha
- **SymbolDefinition** - Retrieve symbol definitions in readable markdown format

### Notebook Tools

- **ReadNotebook** - Read Wolfram notebooks (.nb) as markdown text
- **WriteNotebook** - Convert markdown to Wolfram notebooks

### Testing Tools

- **TestReport** - Run Wolfram Language test files (.wlt) and return reports

### Code Analysis Tools

- **CodeInspector** - Inspect Wolfram Language code for issues and return formatted reports

### Documentation Tools (Paclet Development)

- **CreateSymbolDoc** - Create new symbol documentation pages
- **EditSymbolDoc** - Edit existing symbol documentation pages
- **EditSymbolDocExamples** - Edit example sections of documentation

### Paclet Release Tools (Paclet Development)

- **CheckPaclet** - Check a paclet for issues before building or submission
- **BuildPaclet** - Build a `.paclet` archive for distribution
- **SubmitPaclet** - Submit a paclet to the Wolfram Language Paclet Repository

### MCP Apps Tools

- **NotebookViewer** - Embed interactive Wolfram Cloud notebooks inline
- **MCPAppsTest** - Diagnostic tool for testing the MCP Apps pipeline

> **Note:** MCP Apps tools require a client that supports the `io.modelcontextprotocol/ui` extension. When UI support is available, the `WolframAlpha` and `WolframLanguageEvaluator` tools are automatically enhanced with interactive notebook viewers. See [docs/mcp-apps.md](docs/mcp-apps.md) for details.

See [docs/tools.md](docs/tools.md) for detailed information about each tool.

## Creating Custom Servers

Create custom MCP servers with your own tools using [LLMConfiguration](https://reference.wolfram.com/language/ref/LLMConfiguration.html):

```wl
config = LLMConfiguration[<|
    "Tools" -> {LLMTool["PrimeFinder", {"n" -> "Integer"}, Prime[#n]&]}
|>];

server = CreateMCPServer["My MCP Server", config]
(* Out: MCPServerObject[...] *)
```

Install for use in Claude Desktop:

```wl
InstallMCPServer["ClaudeDesktop", server]
(* Out: Success["InstallMCPServer", <|...|>] *)
```

After restarting Claude Desktop, your custom tools will be available:

![Claude Desktop Screenshot](.github/images/1j9zrhp9b1y8.png)

You can also mix predefined tools with custom tools:

```wl
CreateMCPServer["My MCP Server", <|
    "Tools" -> {
        "WolframLanguageEvaluator",  (* Predefined tool *)
        "WolframAlpha",               (* Predefined tool *)
        LLMTool["MyCustomTool", ...]  (* Custom tool *)
    }
|>];
```

## API Reference

### Core Functions

| Function | Description |
|----------|-------------|
| `CreateMCPServer[name, config]` | Create a custom MCP server |
| `InstallMCPServer[client]` | Install the default server for a client |
| `InstallMCPServer[client, server]` | Install a specific server for a client |
| `UninstallMCPServer[client]` | Remove all servers from a client |
| `UninstallMCPServer[client, name]` | Remove a specific server from a client |
| `DeployAgentTools[target]` | Deploy tools to a client with tracked deployment management |
| `DeployAgentTools[All]` | Deploy tools to every client in `$SupportedMCPClients` (see [docs/deploy-agent-tools.md](docs/deploy-agent-tools.md#deploying-to-all-clients)) |
| `ValidateAgentToolsPacletExtension[paclet]` | Validate an `"AgentTools"` paclet extension |
| `DeployedAgentTools[]` | List all tracked deployments |
| `CreatePreferencesContent[]` | Build the preferences panel UI for managing deployed Wolfram toolsets (see [docs/preferences-content.md](docs/preferences-content.md)) |

### Deployment Objects

| Symbol | Description |
|--------|-------------|
| `AgentToolsDeployment[...]` | Data structure representing a tracked tool deployment |
| `DeployedAgentTools[]` | List all deployments |
| `DeployedAgentTools[client]` | List deployments for a specific client |

### Server Objects

| Symbol | Description |
|--------|-------------|
| `MCPServerObject[...]` | Data structure representing an MCP server |
| `MCPServerObjectQ[expr]` | Test if an expression is a valid server object |
| `MCPServerObjects[]` | List all created server objects (includes paclet-backed servers) |

### Predefined Resources

| Symbol | Description |
|--------|-------------|
| `$DefaultMCPServers` | Association of predefined server configurations |
| `$DefaultMCPTools` | Association of available tool definitions |
| `$DefaultMCPToolOptions` | Association of default tool option values |
| `$DefaultMCPPrompts` | Association of available prompt definitions |

### Options

#### `CreateMCPServer`

| Option | Default | Description |
|--------|---------|-------------|
| `OverwriteTarget` | `False` | Overwrite an existing server with the same name |
| `IncludeDefinitions` | `True` | Include function definitions in the serialized server |
| `Initialization` | `None` | Code to evaluate when the server starts |

#### `InstallMCPServer`

| Option | Default | Description |
|--------|---------|-------------|
| `"EnableMCPApps"` | `True` | Enable or disable [MCP Apps](docs/mcp-apps.md) UI resources |
| `"DevelopmentMode"` | `False` | Use local source files instead of installed paclet |
| `"MCPServerName"` | `Automatic` | Override the config file key for the server entry |
| `"ToolOptions"` | `<\|\|>` | Customize built-in tool behavior (see [docs/tools.md](docs/tools.md#tool-options)) |
| `"VerifyLLMKit"` | `True` | Check LLMKit subscription requirements |

## Development

See the [developer documentation](docs/README.md) for information on:

- [Getting started](docs/getting-started.md) with development
- [Writing and running tests](docs/testing.md)
- [Building the paclet](docs/building.md)
- [Adding new tools](docs/tools.md)
- [Agent skills](docs/agent-skills.md) for distributing tools to AI coding agents
- [Paclet extensions](docs/paclet-extensions.md) for third-party tool/prompt/server contributions
- [Error handling](docs/error-handling.md)

For AI agents working on this codebase, see [AGENTS.md](AGENTS.md).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Richard Hennigan (Wolfram Research)
