# Setting Up the Wolfram MCP Server

This guide explains how to connect your agent to a Wolfram MCP server for richer integration than the bundled scripts provide.

There are two options:

1. **Local server** — Best performance; requires a local Wolfram Engine installation.
2. **Remote Wolfram MCP Service** — No local installation needed; requires a subscription.

---

## Option 1: Local Server (via InstallMCPServer)

If `wolframscript` is available on your system, you can install and configure the Wolfram MCP server locally.

### Step 1: Install the AgentTools paclet

Run the following in a Wolfram Language session (e.g. via `wolframscript`):

```wl
PacletInstall["Wolfram/AgentTools"]
```

### Step 2: Install the server for your client

```wl
Needs["Wolfram`AgentTools`"]
Wolfram`AgentTools`InstallMCPServer["<ClientName>", "<ServerName>"]
```

Replace `<ClientName>` with one of the supported clients:

| Client | Name to use |
| --- | --- |
| Claude Code | `"ClaudeCode"` |
| Claude Desktop | `"ClaudeDesktop"` |
| Cline | `"Cline"` |
| Codex CLI | `"Codex"` |
| Copilot CLI | `"CopilotCLI"` |
| Cursor | `"Cursor"` |
| Gemini CLI | `"GeminiCLI"` |
| Junie | `"Junie"` |
| OpenCode | `"OpenCode"` |
| VS Code | `"VisualStudioCode"` |
| Windsurf | `"Windsurf"` |
| Zed | `"Zed"` |

Here are the available values for `<ServerName>`:

| Server Name | Primary Use Case |
| --- | --- |
| `Wolfram` | General-purpose: Wolfram\|Alpha results and Wolfram Language evaluation |
| `WolframAlpha` | Natural language queries via Wolfram\|Alpha |
| `WolframLanguage` | Wolfram Language development |

Here are the tools provided by these servers:

| Tool | Description | Wolfram | WolframAlpha | WolframLanguage |
| --- | --- | :---: | :---: | :---: |
| `WolframAlphaContext` | Semantic search for Wolfram\|Alpha results | | X | |
| `WolframLanguageContext` | Semantic search across Wolfram Language resources | | | X |
| `WolframContext` | Combines `WolframAlphaContext` and `WolframLanguageContext` | X | | |
| `WolframLanguageEvaluator` | Evaluates Wolfram Language code | X | | X |
| `WolframAlpha` | Submit queries to Wolfram\|Alpha | X | X | |
| `ReadNotebook` | Reads Wolfram notebooks (.nb) as markdown text | | | X |
| `WriteNotebook` | Create Wolfram notebooks (.nb) from markdown text | | | X |
| `SymbolDefinition` | Retrieves Wolfram Language symbol definitions | | | X |
| `CodeInspector` | Inspects Wolfram Language code and returns a formatted report of issues | | | X |
| `TestReport` | Runs Wolfram Language test files (.wlt) and returns a report | | | X |

If it's not obvious which server to install based on the context, ask the user about their use cases.

For project-level installation (supported by some clients):

```wl
InstallMCPServer[{"ClaudeCode", "/path/to/project"}, "<ServerName>"]
```

### Step 3: Restart your client

After installation, ask the user to restart or reload the MCP client to pick up the new server configuration.

---

## Option 2: Remote Wolfram MCP Service

If you do not have a local Wolfram Engine, you can use the hosted [Wolfram MCP Service](https://www.wolfram.com/artificial-intelligence/mcp-service).

The remote MCP service has a fixed set of tools:

| Tool | Description |
| --- | --- |
| `WolframContext` | Combines `WolframAlphaContext` and `WolframLanguageContext` |
| `WolframLanguageEvaluator` | Evaluates Wolfram Language code |
| `WolframAlpha` | Submit queries to Wolfram\|Alpha |

These are functionally equivalent to the ones provided by the local server, except for the following differences with the `WolframLanguageEvaluator` tool:

- It is stateless, meaning that you cannot reuse definitions from one call to the next
- It has fixed memory and time constraints

For coding agents or anything requiring heavy computation, the local server is strongly recommended.

### Step 1: Subscribe to the service

Visit [wolfram.com/artificial-intelligence/mcp-service](https://www.wolfram.com/artificial-intelligence/mcp-service) to subscribe.

### Step 2: Get your API key

Find your API key at [account.wolfram.com/developer-tools/api-keys](https://account.wolfram.com/developer-tools/api-keys).

### Step 3: Configure your client

The remote server URL is:

```
https://services.wolfram.com/api/mcp
```

The transport type is **streamable HTTP** with bearer token authentication.

#### For clients that support remote MCP servers natively

Add this to your MCP configuration:

```json
{
  "wolfram": {
    "url": "https://services.wolfram.com/api/mcp",
    "headers": {
      "Authorization": "Bearer <YOUR_WOLFRAM_MCP_SERVICE_API_KEY>"
    }
  }
}
```

#### For clients that require a stdio wrapper (e.g. Claude Desktop)

Use `mcp-remote` as a bridge:

```json
{
  "wolfram": {
    "command": "npx",
    "args": [
      "-y", "mcp-remote@latest",
      "https://services.wolfram.com/api/mcp",
      "--header", "Authorization: Bearer ${WOLFRAM_API_KEY}"
    ],
    "env": {
      "WOLFRAM_API_KEY": "<YOUR_WOLFRAM_MCP_SERVICE_API_KEY>"
    }
  }
}
```

### Step 4: Restart your client

Ask the user to restart or reload the MCP client to connect to the remote server.

---

## More Information

- Wolfram MCP Service: <https://www.wolfram.com/artificial-intelligence/mcp-service>
- AgentTools paclet: <https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/AgentTools/>
- Setup support article: <https://support.wolfram.com/73463>
