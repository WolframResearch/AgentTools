# Deploying an MCP Server to the Wolfram Cloud

Any `MCPServerObject` (built-in, custom, or from a paclet) can be deployed as a remote MCP server in the Wolfram
Cloud. Clients reach it over HTTP (the MCP Streamable HTTP transport), with no local Wolfram installation, for
example from the remote-MCP features of the Anthropic Messages API and the OpenAI Responses API.

> If the user only wants Wolfram tools without a local installation, they may not need their own deployment:
> Wolfram runs a free public server (see `SetUpWolframMCPServer.md`). Deploy when they need their own tools, their
> own account's resources, or control over access.

## Before you deploy

- **A cloud connection is required.** Check `$CloudConnected` in the kernel that will deploy. If it is `False`, do
  not call `CloudConnect[]` yourself: it can open a login prompt that you cannot answer, and you must not ask for or
  handle the user's password. Ask the user to sign in once from their own terminal or notebook
  (`CloudConnect["their-wolfram-id"]`), which caches the credentials, then connect with the same ID and check again.
  Without a connection, deployment fails with `NotCloudConnected`.
- **Deploying publishes code execution.** The endpoint exposes every tool of the server, and tools run as the
  deploying account, with its files and resources. A server with `WolframLanguageEvaluator` lets anyone who holds
  a key run arbitrary code as that account. There is no tool filtering or sandboxing, so access control is the keys.
  Confirm with the user before deploying, deploy privately (the default), and never use `Permissions -> "Public"`
  unless the user explicitly asks for an open endpoint.
- **Deploy only the tools that are needed.** Create a custom server with a short tool list (`MCPServers.md`) instead
  of deploying a large built-in one.

## Deploying

```wl
dir = CloudDeploy[MCPServerObject["TextTools"], "TextToolsMCP"]
(* CloudObject["https://www.wolframcloud.com/obj/<user>/TextToolsMCP"] *)
```

| Call | Deploys | Returns |
| --- | --- | --- |
| `CloudDeploy[server, target, opts]` | The endpoint, a landing page, and an admin page | The directory `CloudObject` |
| `CloudDeployMCPServerBundle[server, target, opts]` | The same. `server` may also be a server name | The directory `CloudObject` |
| `CloudDeployMCPServer[server, target, opts]` | Only the endpoint, at exactly `target` | The endpoint `CloudObject` |

- `target` is a cloud path or `CloudObject`. Deploying to an existing target replaces what is there. Without a
  target, the deployment gets an anonymous address, and the returned object is the only handle to it, so keep it.
- `Permissions` defaults to `$Permissions` (normally `"Private"`). It applies to the endpoint and the landing page.
  The admin page is always private.
- Deploying takes around a minute.

| Path below `dir` | What it is |
| --- | --- |
| `/mcp` | The MCP endpoint. This is the URL that clients connect to |
| `/index.html` | A landing page with the tool list and configuration snippets to copy |
| `/admin/index.html` | The owner's page for creating and revoking API keys |

## Access: API keys

Access is controlled with Wolfram Cloud permissions keys. With private permissions, only the owner can reach the
endpoint until a key exists. To create one, the owner opens `<dir>/admin/index.html` in a browser while signed in.
The key is shown once. From a kernel:

```wl
mcp = FileNameJoin[{dir, "mcp"}];          (* the endpoint object *)
key = CreateUUID[];

SetPermissions[mcp, PermissionsKey[key] -> "Execute"];    (* create a key *)
Information[mcp, "Permissions"]                            (* list *)
DeleteObject[PermissionsKey[key]]                          (* revoke *)
```

A key can also be granted at deployment time: `Permissions -> {PermissionsKey[key] -> "Execute"}`.

Treat keys as secrets: do not write them into files that get committed, and give them to the user instead of
keeping them in the conversation longer than needed.

## Connecting clients

A client sends the key either as a bearer token or as the `_key` URL parameter:

```json
{ "type": "http", "url": "https://www.wolframcloud.com/obj/<user>/TextToolsMCP/mcp",
  "headers": { "Authorization": "Bearer <KEY>" } }
```

```json
{ "type": "url", "name": "TextTools",
  "url": "https://www.wolframcloud.com/obj/<user>/TextToolsMCP/mcp?_key=<KEY>" }
```

The first form is the usual remote-MCP configuration (the OpenAI Responses API takes the same header in its `mcp`
tool, with `server_url`). The second is the form for the Anthropic Messages API. The landing page shows ready-made
snippets for the deployment. `InstallMCPServer` and `DeployAgentTools` cannot install a remote endpoint into a
local client; add it with the client's own way of configuring an HTTP MCP server.

## Testing the endpoint

```bash
URL='https://www.wolframcloud.com/obj/<user>/TextToolsMCP/mcp'

curl -s -X POST "$URL" -H "Authorization: Bearer $KEY" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'

curl -s -X POST "$URL" -H "Authorization: Bearer $KEY" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"WordCount","arguments":{"text":"one two three"}}}'
```

Without a valid key, the cloud answers `401` before the server runs. Tool failures come back as normal results with
`"isError":true`.

## How cloud servers differ from local ones

- **Stateless.** Every request runs in a fresh cloud kernel. Nothing a tool defines or loads is there on the next
  call, and all initialization runs again for every request. Write tools that depend only on their arguments and on
  persistent storage (cloud objects, files, databases).
- **Custom tools travel with the deployment.** The definitions that a custom server's tools depend on are embedded,
  as with `CreateMCPServer`. Code in packages or paclets must be loadable in the cloud kernel: install the paclet in
  the cloud account (`CloudEvaluate[PacletInstall["Publisher/Paclet"]]`) and load it in the tool's
  `"Initialization"`.
- **Built-in tools adapt.** `WolframLanguageEvaluator` evaluates each call in a fresh cloud kernel; with its
  `session` parameter only global definitions carry over between calls. `WriteNotebook` writes a cloud object
  instead of a local file. Tools that work on files (`TestReport`, `CodeInspector` on a path, the paclet
  tools) see the cloud account's files, not the user's machine, so they are rarely useful there.
- **The semantic search tools are slow in the cloud.** `WolframContext`, `WolframLanguageContext`, and
  `WolframAlphaContext` load their search index on every request, and they depend on an LLMKit subscription of the
  deploying account (required for `WolframAlphaContext`). Servers built around `WolframLanguageEvaluator`,
  `WolframAlpha`, and custom tools work best.
- **Your own tools can branch** on `$MCPEvaluationEnvironment === "Cloud"`, or use `"Overrides"` (`Tools.md`).
- **Faster deployments.** By default the deployment embeds AgentTools itself (several MB). If the paclet is
  installed in the cloud account, only the server's own definitions are embedded and the endpoint uses the installed
  paclet: `CloudEvaluate[PacletInstall["Wolfram/AgentTools", UpdatePacletSites -> True]]`. Keep that copy up to date,
  and do not uninstall it while such a deployment is in use.

## Updating and removing

- To update a deployment, deploy again to the same target. That replaces the endpoint object, so keys that were
  created for it stop working: create new ones, or pass the keys again with `Permissions`.
- To remove one, `DeleteObject[dir]`. Its keys stop working with it. Nothing is recorded locally, so the cloud
  objects are all there is.
