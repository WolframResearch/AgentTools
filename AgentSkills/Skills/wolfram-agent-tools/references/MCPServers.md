# Custom MCP Servers

An MCP server is a named set of tools and MCP prompts. `CreateMCPServer` saves it on the user's machine, and an MCP
client then starts it as a local (stdio) server in its own Wolfram kernel.

## Creating a server

```wl
server = CreateMCPServer["TextTools", <|
    "Tools" -> {
        "WolframLanguageEvaluator",                 (* built-in tool: a key of $DefaultMCPTools *)
        "Publisher/Paclet/ToolName",                (* tool from a paclet *)
        LLMTool[<|...|>]                            (* custom tool: see Tools.md *)
    },
    "MCPPrompts" -> {
        "WolframLanguageSearch",                    (* built-in prompt: a key of $DefaultMCPPrompts *)
        <|"Name" -> "Summarize", ...|>              (* custom prompt: see below *)
    }
|>]
```

| Option | Default | Meaning |
| --- | --- | --- |
| `OverwriteTarget` | `False` | `True` replaces an existing server of that name. Without it, `CreateMCPServer` fails with `MCPServerExists` |
| `IncludeDefinitions` | `True` | Saves the definitions that the tools and prompts depend on with the server |
| `Initialization` | `None` | Code to run when the server starts, before any tool is called: `Initialization :> Needs["MyPackage`"]` |

The second argument can also be an `LLMConfiguration`. Server names should be simple identifiers: no `/`, and not
the name of a built-in server (`"Wolfram"`, `"WolframAlpha"`, `"WolframLanguage"`, `"WolframPacletDevelopment"`).

To start from a built-in server and change its tool list:

```wl
tools = MCPServerObject["WolframLanguage"]["LLMEvaluator"]["Tools"];
CreateMCPServer["MyWolfram", <|
    "Tools"      -> Append[DeleteCases[tools, "TestReport"], myTool],
    "MCPPrompts" -> MCPServerObject["WolframLanguage"]["LLMEvaluator"]["MCPPrompts"]
|>]
```

## Working with server objects

```wl
MCPServerObject["TextTools"]                  (* look up by name: user, built-in, or "Publisher/Paclet/Server" *)
MCPServerObjects[]                            (* user servers and servers of installed paclets *)
MCPServerObjects["IncludeBuiltIn" -> True]
$DefaultMCPServers                            (* the built-in servers *)

server["ToolNames"]      server["Tools"]      (* names, or LLMTool objects *)
server["PromptNames"]    server["Location"]
server["Installations"]                       (* clients it was installed into with InstallMCPServer *)
server["JSONConfiguration"]                   (* configuration for a client that AgentTools does not support *)
server["Properties"]

DeleteObject[server]                          (* deletes a user-created server *)
```

`DeleteObject` uninstalls the server from the clients it was installed into and deletes the saved server. If it was
deployed with `DeployAgentTools`, delete those deployments first, so that no deployment record is left behind.
Built-in servers cannot be deleted, and a paclet's servers go away with `PacletUninstall`.

## MCP prompts

A prompt is something the *user* invokes (a slash command in most clients), with optional arguments. It returns
text that is put into the conversation.

```wl
"MCPPrompts" -> {
    <|
        "Name"        -> "Summarize",
        "Description" -> "Summarizes a topic from the project notes.",
        "Arguments"   -> {<|"Name" -> "topic", "Description" -> "The topic", "Required" -> True|>},
        "Content"     -> StringTemplate["Summarize what the notes say about `topic`."]
    |>
}
```

`"Content"` is a string, a `StringTemplate` (filled in with the arguments), or a function that is called with the
association of arguments and returns a string, for example to look something up and attach it to the conversation.
Argument values are always strings. Prompt names must be unique within a server.

## Testing a server

1. Call each tool directly: `server["Tools"][[1]][<|"text" -> "..."|>]`.
2. Run the server over stdio, exactly as a client would. Write one JSON-RPC message per line to a file:

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"WordCount","arguments":{"text":"one two three"}}}
{"jsonrpc":"2.0","id":4,"method":"prompts/get","params":{"name":"Summarize","arguments":{"topic":"gears"}}}
```

Then pipe it into the server. Use the kernel executable from the `"command"` field of
`server["JSONConfiguration"]` if `wolfram` is not on your PATH:

```bash
MCP_SERVER_NAME=TextTools SUBMIT_USAGE_DATA=false \
  wolfram -run 'PacletSymbol["Wolfram/AgentTools","Wolfram`AgentTools`StartMCPServer"][]' -noinit -noprompt \
  < requests.jsonl
```

The server prints one response per line and exits at the end of the input. Check that `tools/list` shows the
schemas you expect and that each call returns `"isError":false`. Startup takes several seconds, so use a timeout of
a minute or more.

- `Syntax::sntxf` errors mentioning your JSON mean that the server failed to start and the kernel is reading the
  requests as code. Check the server name, and that every paclet or package it needs can be loaded by a fresh
  kernel.
- Every request and response of a server is logged to
  `$UserBaseDirectory/ApplicationData/Wolfram/AgentTools/Servers/<name>/Log.wl`. Read the end of that file when a
  server misbehaves inside a client.

## Installing into a client

Prefer `DeployAgentTools`, which tracks what it installs (see `BundlesAndDeployments.md`):

```wl
DeployAgentTools["ClaudeCode", server]                         (* user level *)
DeployAgentTools[{"ClaudeCode", "/path/to/project"}, server]   (* one project *)
```

`InstallMCPServer` takes the same targets and only writes the MCP configuration entry. `UninstallMCPServer` removes
it:

```wl
InstallMCPServer["Cursor", server]
UninstallMCPServer["Cursor", server]
UninstallMCPServer[server]                (* from every client it was installed into *)
```

- Client names, project support, and what to do for a non-standard configuration file are in
  `SetUpWolframMCPServer.md`. `Keys[$SupportedClients]` lists the names.
- A custom server is installed under its own name, so it sits next to a built-in Wolfram server instead of replacing
  it. The four built-in servers share the configuration key `Wolfram` and replace each other.
- Both functions accept the options in `ToolOptions.md`.
- Ask the user to restart the client afterwards.

### Clients that AgentTools does not support

Any client that can launch a stdio MCP server works. `server["JSONConfiguration"]` gives the command, arguments, and
environment variables for this machine as JSON. Adapt that to the client's configuration format. The details are in
`SetUpWolframMCPServer.md`.

## Using a server without an MCP client

`LLMConfiguration[server]` gives the server's tools as an `LLMConfiguration` for `LLMSynthesize`, `ChatEvaluate`,
and `ChatObject`. `CloudDeploy[server]` turns it into a remote HTTP server (see `CloudDeployment.md`).
