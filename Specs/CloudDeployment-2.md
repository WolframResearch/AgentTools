# Cloud Deployment of MCP Servers — Design Specification

## Overview

This feature lets a user deploy an `MCPServerObject` to the Wolfram Cloud as a remote MCP
server reachable over HTTP, so that remote LLM clients (e.g. the OpenAI Responses API and
the Anthropic Messages API remote-MCP feature) and any HTTP MCP client can call AgentTools
tools without a local kernel.

The primary entry point is an `UpValue` on `MCPServerObject`:

```wl
CloudDeploy[ MCPServerObject[ ... ], "MyServer", Permissions -> ... ]
```

This deploys a **directory bundle** of cloud objects (the MCP endpoint, a public landing
page, a private owner admin page, and a private admin API) and returns the directory
`CloudObject`. A lower-level `CloudDeployMCPServer` deploys *only* the `/mcp` endpoint with a
caller-chosen path and permissions. `RunRemoteMCPServer` is the request handler that runs
inside the deployed endpoint on each HTTP request.

The work reuses the existing MCP request-handling core (`handleMethod` and its serialization
helpers in `Kernel/StartMCPServer.wl`) by factoring the transport-agnostic logic into a
shared file so the local (stdio) and cloud (HTTP) servers share one implementation.

## Goals

- Deploy an MCP server to the Wolfram Cloud with one `CloudDeploy[MCPServerObject[…]]` call.
- Reuse the local server's method dispatch / tool evaluation / serialization unchanged.
- Authenticate remote callers with Wolfram Cloud `PermissionsKey`s, passed either as an
  `Authorization: Bearer <key>` header or a `?_key=<key>` URL parameter.
- Provide a public landing page with server info, usage instructions, and click-to-copy
  client configuration.
- Provide a private, owner-only admin page to create and revoke API keys.
- Keep the cloud endpoint **stateless** — each HTTP request is self-contained, matching the
  Wolfram Cloud `APIFunction`/`Delayed` execution model.
- Lay groundwork (paclet structure, permission model) for later phases (`/files/` artifacts,
  `/logs/` + usage monitoring, auto-install into local clients).

## Design Decisions

At a glance:

| Decision | Choice |
|---|---|
| Phase 1 deliverables | `/mcp`, `/index.html`, `/admin/index.html`, `/api/admin`, + 3 functions. `/files/`, `/logs/` deferred to Phase 2. |
| `/mcp` transport | Stateless request/response (one POST → one JSON or SSE-frame response). |
| `/mcp` permissions | Inherit the `Permissions` the user passes to `CloudDeploy` (same as `index.html`). |
| Cloud tool definitions | Bundle into the deployment via `Block[{Language`$InternalContexts = …}]` during dev; cloud-native paclet later. |
| Admin auth | Wolfram Cloud owner session (both admin artifacts Private; no embedded secret). |
| Local management | `CloudDeploy` returns the `CloudObject` directory; no local registry / wrapper object. |
| Client setup | Landing-page click-to-copy config snippets only; no auto-install into local clients. |
| Enable/disable | Dropped for v1. Admin page = API-key management only. |

Rationale:

- **Stateless transport.** The cloud endpoint implements a simplified MCP HTTP transport:
  one JSON-RPC request per POST, one response. No `Mcp-Session-Id`, no SSE streaming channel,
  no server→client GET channel. This matches Wolfram Cloud's request/response model and is
  already proven against OpenAI/Anthropic remote MCP (see `Notes/cloud-deployed-mcp-servers.md`).
- **`/mcp` inherits the user's `Permissions`.** Whatever `Permissions` the user passes to
  `CloudDeploy` apply to both `index.html` and the starting state of `/mcp`. The admin page
  then adds/removes `PermissionsKey`s on `/mcp` without redeploying. (If the user deploys
  `Permissions -> "Public"`, `/mcp` is open; the recommended pattern is to deploy private and
  mint keys.)
- **Bundled tool definitions (dev), cloud-native (later).** Until AgentTools ships in the
  cloud by default, the deployment must serialize the `Wolfram`AgentTools`` definitions into
  the `Delayed` payload. This is done by removing the AgentTools contexts from
  `Language`$InternalContexts` for the duration of the deploy so they are not stripped from
  the serialized expression (see *Tool Definition Bundling*).
- **Owner-session admin auth.** `/admin/index.html` and `/api/admin` deploy Private. The owner
  views them while signed into Wolfram Cloud; the same-origin session authorizes the page's
  `fetch` calls to `/api/admin`. `/api/admin` runs server-side as the owner, so it has rights
  to `SetPermissions` on the sibling `/mcp` object. No admin secret is embedded in the page.
- **No local registry.** `CloudDeploy` returns the directory `CloudObject`; the cloud objects
  and their permissions are the source of truth. Teardown is `DeleteObject` on the directory
  (and revoking any `PermissionsKey`s). A richer local deployment object/registry (à la
  `AgentToolsDeployment`) is explicitly out of scope for v1.

---

## `CloudDeploy[MCPServerObject[…]]`

Deploys the full directory bundle. Defined as an `UpValue`, mirroring the existing
`MCPServerObject` upvalues (`DeleteObject`, `LLMConfiguration` at `MCPServerObject.wl:730–793`).

### Signature

```wl
MCPServerObject /: CloudDeploy[ obj_MCPServerObject, args___ ] :=
    catchTop[ cloudDeployMCPServer[ obj, args ], MCPServerObject ];
```

`args` follow `CloudDeploy`'s own grammar: an optional target (a path `String` or
`CloudObject`) and options. If no target is given, a default name derived from the server name
is used (e.g. `CloudObject["AgentTools/Servers/<URLEncoded name>"]`).

### Behavior

Given target base `base` (e.g. `"MyServer"`) and effective `Permissions perms`:

1. Confirm the object exists (`ensureMCPServerExists`) and the session is `$CloudConnected`
   (else `throwFailure["NotCloudConnected", …]`).
2. **`base/index.html`** — render the landing-page template with this server's name, version,
   tool list, and endpoint URL, then deploy with `Permissions -> perms`.
3. **`base/mcp`** — deploy `Delayed[ RunRemoteMCPServer[ obj ] ]` with `Permissions -> perms`,
   inside the definition-bundling `Block` (see below). This is the MCP endpoint.
4. **`base/admin/index.html`** — deploy the (static) admin page with `Permissions -> "Private"`.
5. **`base/api/admin`** — deploy the admin `APIFunction` (key CRUD) with
   `Permissions -> "Private"`. The endpoint captures `base` so it can resolve the sibling
   `base/mcp` object.
6. Return `CloudObject[base]` (the directory).

### Options

- `Permissions` — applied to `index.html` and as the initial permissions of `/mcp`. Default
  is the `CloudDeploy` default (effectively private to the owner); the recommended explicit
  value is a private deployment plus keys minted on the admin page.
- All other `CloudDeploy` options are passed through to the individual deployments where they
  make sense (following the `DeployAgentTools` pass-through pattern,
  `DeployAgentTools.wl:254–259`).

### Examples

```wl
obj = MCPServerObject[ "Wolfram" ];
dir = CloudDeploy[ obj, "MyWolframServer", Permissions -> "Private" ]
(* CloudObject["https://www.wolframcloud.com/obj/<user>/MyWolframServer"] *)
```

---

## `CloudDeployMCPServer`

Public function that deploys **only** the `/mcp` endpoint, with a caller-chosen path and
permissions — for users who want just the endpoint and will build their own surrounding pages.

### Signature

```wl
CloudDeployMCPServer[ obj_MCPServerObject ]                        (* default path *)
CloudDeployMCPServer[ obj_MCPServerObject, target_ ]              (* String or CloudObject *)
CloudDeployMCPServer[ obj_MCPServerObject, target_, opts___ ]     (* CloudDeploy options *)
```

```wl
CloudDeployMCPServer // beginDefinition;
CloudDeployMCPServer[ obj_MCPServerObject, args___ ] := catchMine @ cloudDeployMCPServer0[ obj, args ];
CloudDeployMCPServer // endExportedDefinition;
```

### Behavior

Deploys `Delayed[ RunRemoteMCPServer[ obj ] ]` to `target` with the given options, inside the
definition-bundling `Block`, and returns the resulting `CloudObject`. This is the same step 3
that `CloudDeploy[MCPServerObject[…]]` performs; `CloudDeploy` is `CloudDeployMCPServer` plus
the landing/admin artifacts.

### Examples

```wl
key = CreateUUID[ ];
mcp = CloudDeployMCPServer[ MCPServerObject[ "Wolfram" ], "MyServer/mcp",
    Permissions -> { PermissionsKey[ key ] -> "Execute" } ]
(* CloudObject["https://www.wolframcloud.com/obj/<user>/MyServer/mcp"] *)
```

---

## `RunRemoteMCPServer`

The request handler that runs inside the deployed endpoint. It is the cloud analog of the
local `processRequest`/`startMCPServer` loop, but handles exactly one HTTP request and returns
an `HTTPResponse`. Exported so the serialized `Delayed[ RunRemoteMCPServer[ obj ] ]` payload
references a real symbol.

### Signature

```wl
RunRemoteMCPServer[ obj_MCPServerObject ]   (* handles the current HTTPRequestData[] *)
```

### Behavior

1. `req = HTTPRequestData[ ]`.
2. Negotiate the response content type from the `Accept` header via `responseContentType`
   (`"application/json"` preferred, else `"text/event-stream"`); `405` if neither is acceptable.
3. Parse the JSON-RPC message from the request body; `400` if not a JSON object.
4. `initializeServerState[ obj ]` (shared) binds `$currentMCPServer`, `$toolList`, `$llmTools`,
   `$promptList`, `$promptLookup`, `$toolOptions` — the per-request equivalent of the local
   startup state-build (`StartMCPServer.wl:123–143`).
5. `result = handleMethod[ method, message, <| "jsonrpc" -> "2.0", "id" -> id |> ]` (shared,
   unchanged from local).
6. Serialize via `makeResponseString[ contentType, result ]` and return
   `HTTPResponse[ StringToByteArray[ resp ], <| "ContentType" -> contentType |> ]`.
   Notifications and `id -> Null` requests produce an empty `202`/`200` body (no JSON-RPC result).

### Statelessness notes

- Authentication is handled by the Wolfram Cloud permission layer **before** `RunRemoteMCPServer`
  runs — an unauthorized caller never reaches the handler.
- `initialize` is answered per request; there is no persisted session. The handler returns
  capabilities reflecting the actual server (tools, `prompts`, and `resources` when UI is
  supported). `logging` is **not** advertised (log notifications require a streaming channel —
  Phase 2).
- `protocolVersion`: echo the client's requested `params.protocolVersion` when it is a version
  the server supports; otherwise return the shared default `$protocolVersion`
  (currently `"2024-11-05"`). *Implementation note:* confirm against the versions OpenAI/Anthropic
  send and bump the shared default if needed.

---

## Deployment Layout & Permissions

Bundle deployed by `CloudDeploy[MCPServerObject[…]]` under base directory `base`:

| Path | Contents | Permissions |
|---|---|---|
| `base/mcp` | `Delayed[RunRemoteMCPServer[obj]]` — the MCP endpoint | Inherit user's `Permissions`; admin page adds/removes `PermissionsKey`s |
| `base/index.html` | Landing page (server info, instructions, click-to-copy config) | User's `Permissions` (respected as-is) |
| `base/admin/index.html` | Owner admin page (API-key CRUD) | **Always Private** |
| `base/api/admin` | Admin `APIFunction` (key CRUD) | **Always Private** |
| `base/files/` | Generated artifacts (notebooks, images) | *Phase 2* |
| `base/logs/` | Server log files | *Phase 2* |

A public `base/api/info` returning server name/version/tools as JSON is an **optional**
alternative to deploy-time templating of the landing page (see *Landing Page*); not required
if the landing page is templated at deploy time.

---

## The `/mcp` Endpoint — Wire Protocol

Stateless JSON-RPC over HTTP POST.

### Content negotiation

```wl
responseContentType[ accept : { ___String } ] :=
    SelectFirst[ { "application/json", "text/event-stream" }, MemberQ[ accept, # ] &, None ];
```

`makeResponseString` emits compact JSON for `application/json`, or a single
`data: <json>\n\n` frame for `text/event-stream`.

### Authentication

`/mcp` is protected by Wolfram Cloud permissions. When private, callers supply a
`PermissionsKey` either way the upstream client supports:

- **Header** (OpenAI Responses API): `Authorization: Bearer <key>`.
- **URL parameter** (Anthropic Messages API): `…/mcp?_key=<key>`.

Both are accepted by the Wolfram Cloud permission layer; the handler itself does no auth.

### Status / error behavior

| Condition | Response |
|---|---|
| `Accept` allows neither JSON nor SSE | HTTP `405` |
| Body is not a JSON object | HTTP `400` |
| Unknown JSON-RPC method | JSON-RPC error `-32601` "Unknown method" |
| Tool/handler internal failure | JSON-RPC error `-32603` "Internal error" |
| Notification / `id: null` | Empty body, HTTP `200`/`202` |
| Missing/invalid key | Handled by Wolfram Cloud (HTTP `401`/permission error) before the handler runs |

### Example (request → response)

```json
// POST base/mcp   Authorization: Bearer <key>   Accept: application/json
{ "jsonrpc": "2.0", "id": 1, "method": "tools/list" }
```
```json
{ "jsonrpc": "2.0", "id": 1, "result": { "tools": [ { "name": "...", "inputSchema": { ... } } ] } }
```

The OpenAI and Anthropic end-to-end request examples in
`Notes/cloud-deployed-mcp-servers.md` (lines 258–332) are the acceptance references for this
endpoint and should be reproduced in this spec's appendix.

---

## Tool Definition Bundling

The deployed `Delayed[ RunRemoteMCPServer[ obj ] ]` must carry the `Wolfram`AgentTools`` symbol
definitions so the cloud kernel can evaluate tools without a locally installed paclet. By
default Wolfram Language strips symbols whose contexts are listed in `Language`$InternalContexts`
from serialized expressions. The deploy therefore runs inside:

```wl
Block[
    {
        Language`$InternalContexts =
            Select[ Language`$InternalContexts, Not @* StringStartsQ[ "Wolfram`AgentTools`" ] ]
    },
    CloudDeploy[ Delayed @ RunRemoteMCPServer[ obj ], target, Permissions -> perms, opts ]
]
```

This forces the AgentTools definitions reachable from `RunRemoteMCPServer[obj]` (and the
serialized tool functions inside `obj`) to be included in the deployment payload.

**End state:** once a cloud-native AgentTools paclet is available by default in the Wolfram
Cloud, this `Block` is dropped and `RunRemoteMCPServer` simply loads the cloud paclet. The spec
treats the `Block` as a development-mode mechanism, isolated in one deploy helper so it can be
removed cleanly.

---

## Landing Page (`/index.html`)

A static HTML/CSS asset bundled with the paclet, **rendered at deploy time** with this server's
details substituted (via `StringTemplate`/`TemplateApply`), then written to `base/index.html`.
Rendering at deploy time avoids a runtime info API and keeps the page self-contained. Contents:

- **Server info**: name, version, available tools (name + description from the same data used by
  `tools/list`).
- **Endpoint URL** for `base/mcp`, with click-to-copy.
- **Click-to-copy client configuration** snippets:
  - Generic remote MCP: `{ "type": "url", "url": "<…/mcp>", "headers": { "Authorization": "Bearer <KEY>" } }`
  - OpenAI Responses API `tools` block.
  - Anthropic `mcp_servers` block using `?_key=<KEY>`.
  - Claude Desktop / other URL-MCP clients.
- **Usage instructions** (how to obtain a key, how to authenticate).
- **Link to the admin page** (`base/admin/`).

Reuse `clickToCopy` (`Formatting.wl:75,262–275`) styling ideas and the JSON-config shape from
`makeJSONConfiguration` (`MCPServerObject.wl:647–661`), adapted to the remote `url`+`headers`
form.

---

## Admin Page (`/admin/index.html`) + `/api/admin`

### Auth model

Both deploy **Private**. The owner opens `base/admin/` while signed into Wolfram Cloud; the
same-origin session authorizes the page's `fetch` calls to `base/api/admin`. The API function
executes server-side as the owner and thus may modify `/mcp`'s permissions. No secret is stored
in the page.

### `/api/admin` actions

The admin page POSTs an action; the API resolves the sibling `base/mcp` object from the captured
`base`:

| Action | Effect | Returns |
|---|---|---|
| `listKeys` | Read `Information[ mcpObj, "Permissions" ]` | Current `PermissionsKey`s |
| `createKey` | `key = CreateUUID[]; SetPermissions[ mcpObj, PermissionsKey[key] -> "Execute" ]` | The new key (shown once) + updated list |
| `revokeKey` | `DeleteObject[ PermissionsKey[ key ] ]` | Updated key list |

These mirror the verified key lifecycle in `Notes/cloud-deployed-mcp-servers.md:64–108`.

### v1 admin scope

API-key management only. **Usage monitoring** depends on `/logs/` (Phase 2). **Enable/disable**
is dropped for v1.

---

## Paclet Layout & Refactor

Per the notes, factor the server runtime into `Kernel/Server/`:

- **`Kernel/Server/Server.wl`** — entry point that loads the sibling files; add its context to
  `$AgentToolsContexts` (`Main.wl:62–86`).
- **`Kernel/Server/Shared.wl`** — transport-agnostic core promoted out of
  `StartMCPServer.wl`'s private context: `handleMethod` (`:540–572`), `evaluateTool`
  (`:878–925`), `getPrompt`/`makePromptContent` (`:626–728`), `initResponse`/`makeInstructions`
  (`:1007–1072`), `createMCPToolData`/`toolSchema`/`disambiguateToolNames` (`:280–373`),
  `makePromptData*`/`makePromptLookup`/`normalizeArgument` (`:418–481`),
  `resultToContent`/`safeString`/image helpers (`:733–957`), `handleResourceRead` (`:577–621`),
  `parseToolOptions` (`:55–90`), `$protocolVersion` (`:15`), and the `writeLog`/`writeError`/
  `debugPrint` definitions. **New:** `initializeServerState[obj]`, extracted from the local
  startup build so both transports use it.
- **`Kernel/Server/Local.wl`** — stdio-specific: `StartMCPServer`/`startMCPServer`,
  `processRequest`, `stdinShutdownQ`, `superQuiet`, the `While[True]` loop + orphan check,
  warmup/init helpers, `stderrEnabledQ`.
- **`Kernel/Server/Cloud.wl`** — `CloudDeployMCPServer`, `RunRemoteMCPServer`, the
  `MCPServerObject /: CloudDeploy` upvalue, `responseContentType`/`makeResponseString`, the
  definition-bundling deploy helper, the landing-page templating helper, and the admin
  page / `/api/admin` deploy helpers.

**Shared-state extraction.** Local builds `$toolList`/`$llmTools`/`$promptList`/`$promptLookup`/
`$toolOptions` once and `Block`s them for the session (`StartMCPServer.wl:123–143`). Extract this
into `initializeServerState[obj]`; Local calls it once at startup, Cloud calls it per request.
*(Optional later optimization: memoize on `obj` within a warm cloud kernel.)*

**Logging indirection.** `writeLog` (local file `PutAppend`), `superQuiet` (stdout protection),
and `stderrEnabledQ` are stdio-only assumptions. Route shared logging through a sink that Local
binds to its file and Cloud binds to a no-op for v1 (and to `/logs/` in Phase 2); `superQuiet`
becomes a no-op in cloud.

**Symbol registration** (three places must agree, per existing convention):

- `Kernel/Main.wl` — add `CloudDeployMCPServer`, `RunRemoteMCPServer` to the export list
  (`:15–35`) and `$AgentToolsProtectedNames` (`:101–123`); add the new `Server` contexts to
  `$AgentToolsContexts`.
- `PacletInfo.wl` — add the fully-qualified symbols to the Kernel extension `"Symbols"` list
  (`:22–50`); register any new HTML/CSS/JS under the `"Asset"` extension (`:59–66`).
- `Kernel/CommonSymbols.wl` — declare newly-shared symbols (`initializeServerState`, and any of
  the promoted `handleMethod`-core symbols not already shared) so `Server/*` files can see them.

**Assets.** Landing/admin HTML/CSS/JS live under `Assets/` (e.g. `Assets/Cloud/`), registered in
the `"Asset"` extension and read at deploy time via
`PacletObject["Wolfram/AgentTools"]["AssetLocation", …]`, then pushed with `CopyFile`
(static admin page) or rendered-then-written (templated landing page).

---

## Messages

Add a `(* Cloud deployment messages *)` banner block to `Kernel/Messages.wl` (registered on
`AgentTools`, resolved onto the wrapping symbol by `throwFailure`). Initial tags:

- `NotCloudConnected` — `CloudDeploy[MCPServerObject…]` requires an active cloud connection.
- `CloudDeployFailed` — a sub-deployment (mcp/index/admin/api) failed.
- `InvalidCloudTarget` — the target path/`CloudObject` is malformed.

---

## Storage / State

No local persistence in v1. The deployed `CloudObject`s and their permissions are the source of
truth. Teardown: `DeleteObject` on the directory `CloudObject` (and revoke outstanding
`PermissionsKey`s). A local deployment registry/object analogous to `AgentToolsDeployment`
(`DeployAgentTools.wl`) is intentionally deferred.

---

## Implementation Phases

**Phase 1 (this spec):** `Server/` refactor + shared `initializeServerState`; `RunRemoteMCPServer`;
`CloudDeployMCPServer`; `CloudDeploy[MCPServerObject[…]]` upvalue; templated landing page; static
admin page + `/api/admin` key CRUD; definition bundling `Block`; messages; symbol/asset
registration; tests.

**Phase 2+ (documented, not built):**

- `/files/` artifact storage (redirect WL-evaluator images/notebooks here instead of the shared
  `AgentTools/Images`/`AgentTools/Notebooks` paths).
- `/logs/` + usage monitoring on the admin page.
- Server enable/disable.
- Auto-install of remote servers into local client config files (new `url`+`headers` converter
  shapes in `SupportedClients.wl` + `InstallMCPServer.wl`).
- Cloud-native AgentTools paclet → drop the `Language`$InternalContexts` bundling `Block`.
- Full Streamable HTTP transport (sessions, SSE streaming, logging notifications) if needed.

---

## Implementation Touchpoints

- **Create:** `Kernel/Server/{Server,Shared,Local,Cloud}.wl`; `Assets/Cloud/` landing+admin
  HTML/CSS/JS; `Tests/` coverage for cloud deploy + remote handler; `Documentation/` reference
  pages for `CloudDeployMCPServer` and `RunRemoteMCPServer`.
- **Modify:** `Kernel/Main.wl`, `PacletInfo.wl`, `Kernel/CommonSymbols.wl`, `Kernel/Messages.wl`;
  migrate definitions out of `Kernel/StartMCPServer.wl` into `Server/*` (keep `StartMCPServer.wl`
  as a thin shim or fold into `Server/Local.wl`).

---

## Verification

- **Unit/integration (TestReport):** deploy a tiny `MCPServerObject` (e.g. a `PrimeFinder` tool)
  via `CloudDeployMCPServer` with a `PermissionsKey`; `URLRead` the `/mcp` endpoint and assert
  `initialize`, `tools/list`, and `tools/call` results; assert unauthorized calls are rejected.
- **Bundle:** `CloudDeploy[obj, "…"]`; verify `index.html` renders with correct server/tool
  info, the admin page loads only for the owner, `createKey`/`listKeys`/`revokeKey` work, and a
  newly minted key authorizes `/mcp`.
- **Remote clients:** reproduce the OpenAI and Anthropic remote-MCP examples from
  `Notes/cloud-deployed-mcp-servers.md` against the deployed endpoint.
- **Static analysis:** run `CodeInspector` on all new/changed files; ensure the local stdio
  server still passes its existing tests after the `Server/` refactor.
