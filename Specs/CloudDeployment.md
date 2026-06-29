# Cloud Deployment of MCP Servers — Design Specification

## Overview

This feature lets a user deploy an `MCPServerObject` as a remote MCP server running in the
Wolfram Cloud, reachable over HTTP by any MCP-capable client (OpenAI, Anthropic, etc.):

```wl
CloudDeploy[ MCPServerObject[ ... ], ... ]
```

`CloudDeploy` of an `MCPServerObject` produces a `CloudObject` corresponding to a **deployment
directory** that contains the live MCP endpoint, a landing page, and an owner-only admin page.
A lower-level function, `CloudDeployMCPServer`, deploys *only* the MCP endpoint with
caller-controlled path and permissions. The endpoint itself is served by a new
`RunRemoteMCPServer` handler that speaks the **Streamable HTTP** transport of MCP protocol
revision **2025-11-25**.

The local (`StartMCPServer`, stdio) and remote (cloud, HTTP) server implementations share a large
amount of request-handling logic. As part of this work that logic is refactored into a new
`Kernel/Server/` directory so both transports call into a common core (`handleMethod`, tool/prompt
resolution, result formatting, capability negotiation).

Three new public symbols are introduced in the ``Wolfram`AgentTools` `` context:

- **`CloudDeployMCPServer`** — deploy just the `/mcp` endpoint.
- **`RunRemoteMCPServer`** — the HTTP request handler that runs inside a deployed endpoint.
- An UpValue for **`CloudDeploy`** on `MCPServerObject` — deploy the full directory.

---

## Goals

- Support `CloudDeploy[MCPServerObject[...], ...]` returning a `CloudObject` directory.
- Provide `CloudDeployMCPServer` for deploying only the endpoint, with arbitrary path/permissions.
- Provide `RunRemoteMCPServer[obj]` implementing the remote MCP transport from a server object.
- Reuse Wolfram Cloud's native `PermissionsKey` mechanism for API authentication.
- Ship a landing page (client configuration help) and an owner-only admin page (API key
  create/revoke).
- Refactor shared server logic into `Kernel/Server/` so local and cloud transports share a core.
- Keep the deployment self-managing: the returned `CloudObject` and its admin page are the source
  of truth — no new local registry.

## Non-Goals (v1)

The following are explicitly **out of scope** for the initial implementation and are listed under
[Future Work](#future-work):

- `/logs/` — server log storage.
- `/files/` — per-deployment artifact area. MCP-App artifacts (e.g. Wolfram|Alpha cloud notebooks)
  continue to use the existing **global** `AgentTools/Notebooks` cloud location written by
  `deployCloudNotebookForMCPApp` (`Kernel/UIResources.wl`), independent of any deployment.
- **Usage monitoring** and an **enable/disable** toggle on the admin page.
- **Tool filtering / safety gating.** A deployed server exposes exactly the tools in its server
  object, including code-execution tools such as `WolframLanguageEvaluator`. Access control is the
  owner's responsibility, mediated entirely by API keys.
- **Caching / persistent kernels.** Each request is a fresh, stateless evaluation
  (see [Evaluation Model](#evaluation-model)).
- **Local consumption.** Making the deployed remote endpoint installable into local MCP clients
  (a URL-based `InstallMCPServer`) is a separate future effort.

---

## New Public Symbols

| Symbol | Context | Purpose |
|---|---|---|
| `CloudDeployMCPServer` | ``Wolfram`AgentTools` `` | Deploy only the `/mcp` endpoint for a server object. |
| `RunRemoteMCPServer` | ``Wolfram`AgentTools` `` | HTTP request handler invoked inside a deployed endpoint. |
| `CloudDeploy` (UpValue) | (existing `System` symbol) | `MCPServerObject /: CloudDeploy[obj, args___]` deploys the full directory. |

Both new symbols follow the standard export pattern: declared in `Kernel/Main.wl` (exported names +
protected names list) and `PacletInfo.wl` (`"Symbols"`), defined with `beginDefinition` /
`endExportedDefinition`, and bodies wrapped in `catchMine`.

---

## Architecture: `Kernel/Server/` Refactor

`StartMCPServer.wl` currently mixes transport-agnostic request handling with stdio-specific
plumbing. The shared portions are needed verbatim by the cloud handler, so the implementation is
reorganized into a `Server/` subdirectory:

| File | Context | Contents |
|---|---|---|
| `Kernel/Server/Server.wl` | ``…`Server` `` | Entry point that `Get`s the other three files. Added to `$AgentToolsContexts` in `Main.wl`. |
| `Kernel/Server/Shared.wl` | ``…`Server`Shared` `` | Transport-agnostic core (see below). |
| `Kernel/Server/Local.wl` | ``…`Server`Local` `` | `StartMCPServer` and stdio-specific logic. |
| `Kernel/Server/Cloud.wl` | ``…`Server`Cloud` `` | `CloudDeployMCPServer`, `RunRemoteMCPServer`, the `CloudDeploy` UpValue, page/asset deployment, and the admin/info APIs. |

### What moves to `Shared.wl`

The following move out of `StartMCPServer.wl` unchanged (modulo context):

- `handleMethod` and every method handler (`initialize`, `ping`, `tools/list`, `tools/call`,
  `prompts/list`, `prompts/get`, `resources/list`, `resources/read`, notification dispatch,
  unknown-method fallback).
- Tool list construction: `disambiguateToolNames`, `createMCPToolData`, `toolSchema`.
- Prompt construction: `makePromptData`, `makePromptLookup`, `makePromptData0`,
  `normalizeArguments`, `normalizeArgument`, `getPrompt`, `makePromptContent`,
  `consolidateTextContent`, `catchPromptFunction`, `formatPromptError`.
- Tool evaluation and result formatting: `evaluateTool`, `resultToContent`,
  `graphicsToImageContent`, `makeImageContent`, `extractWolframAlphaImages`,
  `extractImageContent`, `safeString`, `convertPUACharacters`, `toPrintableASCII`.
- Capability/init: `initResponse`, `makeInstructions`.
- Server/tool bootstrapping reused by both transports: `ensurePacletsForStart`,
  `ensureDependenciesForStart`, `runServerInitialization`, `runToolInitialization`.
- The `$currentMCPServer`, `$mcpEvaluation`, `$clientName`, `$clientSupportsUI`,
  `$clientSupportsRoots`, `$toolList`, `$llmTools`, `$promptList`, `$promptLookup`, `$toolOptions`
  state variables that the handlers read.

### What stays in `Local.wl`

- `StartMCPServer` (exported entry) and the stdio read loop (`startMCPServer`, `processRequest`).
- `stdinShutdownQ`, `superQuiet` (stdout/stderr redirection), the stdio logging helpers
  (`writeLog`, `writeError`, `debugPrint`, `stderrEnabledQ`), and tool warmup (`toolWarmup`,
  `preinstallVectorDatabases`) — warmup is a long-lived-process optimization that does not apply to
  stateless cloud requests.

### Protocol version negotiation (shared)

Today `$protocolVersion = "2024-11-05"` is a hardcoded constant in `StartMCPServer.wl` echoed
verbatim by `initResponse`. The shared layer replaces this with explicit negotiation, required to
support 2025-11-25 cleanly:

```wl
$supportedProtocolVersions = { "2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05" };
$preferredProtocolVersion  = "2025-11-25";
```

`initResponse` negotiates per the [lifecycle rules](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle):
if the client's requested `protocolVersion` is in `$supportedProtocolVersions`, echo it back;
otherwise return `$preferredProtocolVersion`. Both transports use the same logic. (Bumping the
local stdio server's advertised version to 2025-11-25 is a low-risk side benefit but not required;
negotiation makes it backward compatible either way.)

### `CommonSymbols.wl`

Symbols shared across the new `Server` subcontexts (and any reached from `Cloud.wl`,
`MCPServerObject.wl`, or the existing `StartMCPServer` callers) must be declared in
`CommonSymbols.wl`, following the existing convention. At minimum: `handleMethod`,
`RunRemoteMCPServer`'s internal helpers as needed, `$preferredProtocolVersion`, and the deployment
path helpers introduced below.

---

## Deployed Directory Layout

`CloudDeploy[obj]` populates a deployment directory (a `CloudObject` path prefix) with several
objects. Sub-objects are created by joining onto the directory object, mirroring the existing
pattern in `UIResources.wl`:

```wl
dir = CloudObject[ (* path or anonymous *) , Permissions -> permissions ];
mcp = FileNameJoin @ { dir, "mcp" };   (* etc. *)
```

| Path | Purpose | v1 |
|---|---|---|
| `/mcp` | The live MCP endpoint (`Delayed[RunRemoteMCPServer[obj]]`). | ✅ |
| `/index.html` | Landing page (client configuration help). | ✅ |
| `/api/info` | Server metadata consumed by the landing page. | ✅ |
| `/admin/index.html` | Owner-only admin page (API key create/revoke). | ✅ |
| `/api/admin` | Owner-only API backing the admin page actions. | ✅ |
| `/files/` | Per-deployment artifact area. | Deferred |
| `/logs/` | Server log storage. | Deferred |

Supporting static assets (CSS/JS for the two HTML pages) are deployed into a sensible
sub-location (e.g. `/assets/`), referenced by the pages. See [Static Assets](#static-assets).

### Default location

When the caller supplies no explicit target, the directory is an **anonymous** cloud object:

```wl
dir = CloudObject[ Permissions -> permissions ]   (* anonymous, server-assigned path *)
```

An explicit second argument (`"MyServer"` or a `CloudObject[...]`) overrides this and is used as the
directory prefix.

### Return value

`CloudDeploy[obj, ...]` returns the **directory** `CloudObject` (not the `/mcp` object).
`CloudDeployMCPServer[...]` returns the **`/mcp`** `CloudObject`.

---

## Permissions Model

The default permissions for a deployment are the ambient `$Permissions` value, overridable by an
explicit `Permissions` option to `CloudDeploy`. Individual objects within the deployment override
this where the design requires it:

| Object | Permissions | Rationale |
|---|---|---|
| `/index.html` | The resolved `Permissions` (default `$Permissions`). | Landing page visibility is the user's choice. |
| `/api/info` | Same as `/index.html`. | Must be readable by anyone who can view the landing page. |
| `/mcp` | Starts at the same resolved `Permissions` as `/index.html`; the admin page then adds/removes `PermissionsKey` entries. | Public reachability is controlled by minting API keys. |
| `/admin/index.html` | **Always `"Private"`.** | Owner-only management surface. |
| `/api/admin` | **Always `"Private"`.** | Mutates permissions; owner-only. |

### Authentication

Authentication is delegated entirely to Wolfram Cloud's native `PermissionsKey` mechanism; no custom
key validation is implemented in the handler.

- **`/mcp`** — callers authenticate with a `PermissionsKey`. Wolfram Cloud accepts the key either as
  the bearer token in an `Authorization: Bearer <key>` header (used by OpenAI's MCP client) or as a
  `?_key=<key>` URL parameter (used by Anthropic's MCP client). Both forms were validated against the
  prototype in `Notes/cloud-deployed-mcp-servers.md`.
- **`/admin/index.html` and `/api/admin`** — these are `"Private"`, so they are reached through the
  owner's authenticated Wolfram Cloud session. The admin page's browser requests to `/api/admin`
  carry the owner's session credentials.

### Managing API keys

The admin page manipulates the `/mcp` object's permissions directly using the standard cloud
primitives (as prototyped in the notes):

```wl
(* create *)
key = CreateUUID[ ];
SetPermissions[ mcp, PermissionsKey[ key ] -> "Execute" ];

(* list *)
Information[ mcp, "Permissions" ];

(* revoke *)
DeleteObject[ PermissionsKey[ key ] ];
```

Because `PermissionsKey` UUIDs are opaque, the admin API may persist optional human-readable
**labels** for keys in a small `"Private"` cloud object inside the deployment (e.g.
`/admin/keys.wxf`). This is a convenience only; the authoritative list of valid keys is always the
object's live permissions. (No usage statistics are recorded in v1.)

---

## `CloudDeploy` (UpValue on `MCPServerObject`)

### Definition

Per the notes, the behavior is attached via an UpValue so `CloudDeploy` dispatches on an
`MCPServerObject` argument:

```wl
MCPServerObject /: CloudDeploy[ obj_MCPServerObject, args___ ] := catchTop[
    cloudDeployMCPServer[ obj, args ],     (* full-directory variant *)
    MCPServerObject
];
```

> Note: the internal `cloudDeployMCPServer` (full directory) is distinct from the exported
> `CloudDeployMCPServer` (endpoint only). Naming is finalized during implementation; the UpValue
> builds the full directory while reusing the endpoint-deployment primitive for `/mcp`.

### Arguments and options

| Argument | Type | Description |
|---|---|---|
| `obj` | `MCPServerObject` | The server to deploy. |
| target (optional) | `String` or `CloudObject` | Deployment directory prefix. Omitted ⇒ anonymous `CloudObject[]`. |

Options are forwarded to the underlying `CloudDeploy`/`CloudObject` calls. `Permissions` (default
`$Permissions`) sets the resolved permissions used for `/index.html`, `/api/info`, and the initial
`/mcp` state. `/admin/*` permissions are forced to `"Private"` regardless.

### Behavior

1. Validate the server object (`ensureMCPServerExists`).
2. Resolve the directory `CloudObject` (explicit target or anonymous) and the resolved
   `Permissions`.
3. Deploy `/mcp` via the endpoint primitive (see [`CloudDeployMCPServer`](#clouddeploymcpserver)),
   carrying the definition-bearing server object (see [Embedding](#embedding-the-server)).
4. Deploy `/index.html`, `/assets/*`, and `/api/info` at the resolved permissions.
5. Deploy `/admin/index.html` and `/api/admin` as `"Private"`.
6. Return the directory `CloudObject`.

### Example

```wl
server = MCPServerObject[ "WolframLanguage" ];
dir    = CloudDeploy[ server, "MyTools" ]
(* CloudObject["https://www.wolframcloud.com/obj/<user>/MyTools"] *)
```

---

## `CloudDeployMCPServer`

Deploys *only* the MCP endpoint, with caller-controlled path and permissions. This is the primitive
that the `CloudDeploy` UpValue uses for the `/mcp` object, and is also useful directly when the
landing/admin pages are not wanted.

### Signature

```wl
CloudDeployMCPServer[ obj ]
CloudDeployMCPServer[ obj, target ]
CloudDeployMCPServer[ obj, target, opts ]
```

| Argument | Type | Description |
|---|---|---|
| `obj` | `MCPServerObject`, `String`, or association | The server to deploy. Strings/associations resolve through `MCPServerObject` first. |
| `target` | `String` or `CloudObject` | Endpoint location. Omitted ⇒ anonymous `CloudObject[]`. |

Options forwarded to `CloudDeploy`; `Permissions` defaults to `$Permissions`.

### Behavior

1. Resolve `obj` to a validated `MCPServerObject`.
2. Build the deployable expression `Delayed[RunRemoteMCPServer[obj]]` carrying the server's
   definitions (see [Embedding](#embedding-the-server)).
3. `CloudDeploy` it to `target` with the resolved permissions.
4. Return the resulting `CloudObject`.

### Example

```wl
key = CreateUUID[ ];
mcp = CloudDeployMCPServer[
    MCPServerObject[ "WolframLanguage" ],
    "MCPTest/mcp",
    Permissions -> { PermissionsKey[ key ] -> "Execute" }
]
(* CloudObject["https://www.wolframcloud.com/obj/<user>/MCPTest/mcp"] *)
```

---

## `RunRemoteMCPServer`

The handler deployed (via `Delayed`) at `/mcp`. It accepts an `MCPServerObject`, prepares the
shared server state, reads the inbound HTTP request, dispatches one JSON-RPC message through the
shared `handleMethod`, and returns an `HTTPResponse`.

### Signature

```wl
RunRemoteMCPServer[ obj_MCPServerObject ]
```

The notes' prototype hardcodes `$toolList`/`$llmTools`; the real implementation derives all server
state from `obj` using the same shared bootstrapping as `StartMCPServer` (`ensurePacletsForStart`,
`runServerInitialization`, `runToolInitialization`, `disambiguateToolNames`, `createMCPToolData`,
`makePromptData`, `makePromptLookup`).

### Request handling (stateless Streamable HTTP, 2025-11-25)

Grounded in the [transport spec](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports):

1. **Method.** The endpoint is a single path handling `POST`. `GET` (the optional server→client SSE
   stream) and `DELETE` (session teardown) are not supported by a stateless server ⇒ respond
   **`405 Method Not Allowed`**.
2. **Origin validation.** If an `Origin` header is present and not allowed, respond **`403
   Forbidden`** (DNS-rebinding protection). Absent `Origin` (typical for server-to-server LLM
   providers) is allowed.
3. **Protocol version header.** For non-`initialize` requests, read `MCP-Protocol-Version`. If
   present but unsupported ⇒ **`400 Bad Request`**. If absent, assume `2025-03-26` per spec.
4. **Accept negotiation.** The body is parsed as a single JSON-RPC message. The response content
   type is chosen from the `Accept` header, preferring `application/json`, falling back to
   `text/event-stream` (reusing the prototype's `responseContentType`). A stateless server returns a
   single JSON object (or a single SSE `data:` event) — it never holds the stream open.
5. **Message kind:**
   - **Request** (has `id` + `method`) ⇒ dispatch through `handleMethod`; return the JSON-RPC result
     as `application/json` (or single-shot SSE) with **`200`**.
   - **Notification** or **Response** (no response is owed) ⇒ return **`202 Accepted`** with no body.
6. **Malformed input** (non-JSON body, not an association) ⇒ **`400 Bad Request`**.
7. **Unsupported `Accept`** (neither JSON nor SSE) ⇒ **`406 Not Acceptable`** (the prototype returned
   `405`; `406` is the correct code).

The dispatch itself is identical to the local server because `handleMethod` is shared. The handler
runs inside `Block[{ $currentMCPServer = obj, $mcpEvaluation = True }, … ]` so tools format their
output for MCP exactly as they do locally. Unlike the stdio path, there is no `stdout` to protect, so
`superQuiet`'s redirection is unnecessary (messages are still suppressed from the response body).

### Capabilities in the cloud

`initialize` advertises `tools` and `prompts` as today. `resources`/MCP-Apps UI continues to depend
on the client advertising the `io.modelcontextprotocol/ui` extension; remote LLM providers generally
do not, so it degrades naturally. The MCP **roots** handshake is a no-op in the cloud (no local
working directory), so the server simply does not use it.

---

## Embedding the Server

The deployed `/mcp` endpoint must reconstruct the server — including any **custom, anonymous tool
functions** — at request time, in a cloud kernel that does not have the user's local definitions.
Two mechanisms combine:

1. **Embed the definition-bearing object.** The `Delayed[RunRemoteMCPServer[obj]]` expression carries
   `obj` together with the definitions it references, using the same approach `CreateMCPServer`
   already uses for local serialization (`binarySerializeWithDefinitions` /
   `Language`ExtendedFullDefinition`). This makes self-contained custom servers (pure-function tools)
   work without any paclet present.
2. **Ensure paclets at runtime.** Built-in tools reference `Wolfram/AgentTools` and `Wolfram/Chatbook`
   internals that are impractical to serialize wholesale. On each cold start, the handler ensures the
   required paclets are installed/loaded in the cloud (reusing `ensurePacletsForStart` /
   `ensureDependenciesForStart`, which are fast no-ops once present), then resolves built-in and
   paclet-qualified tools by name exactly as the local server does.

If inline definition capture proves insufficient for a given server, an equivalent fallback is to
write the server's WXF (as produced by `CreateMCPServer`) to a `"Private"` object in the deployment
directory and have the handler read it on cold start. The two approaches are interchangeable; the
implementation may choose per case.

### Evaluation Model

Each request is a **fresh, stateless** evaluation (`Delayed`/`APIFunction`-style). There is no
persistent kernel between calls in v1. Consequences, accepted for v1 and documented for users:

- Per-request **cold-start cost**: paclet loading and any tool initialization (e.g. vector-database
  installation for the `*Context` search tools) recur on every call. Context/search tools therefore
  carry a substantial latency penalty in the cloud and additionally require cloud connectivity and an
  LLMKit subscription on the deploying account.
- No cross-request state, sessions, or warmup. The stdio-only `toolWarmup` path is not used.

Caching / persistent kernels are [future work](#future-work).

---

## Landing Page (`/index.html` + `/api/info`)

The landing page is **dynamic**: a static HTML/JS shell deployed at `/index.html` that fetches live
server metadata from `/api/info` at view time and renders it client-side.

### `/api/info`

A read-only API (permissions matching `/index.html`) returning JSON describing the server:

- Server name and version.
- Tool list (names, titles, descriptions) — derived from the same shared tool-list construction used
  by `tools/list`.
- The endpoint URL (`/mcp`).

It does **not** expose API keys, permissions, or usage data.

### Page contents

Rendered from `/api/info`:

- Basic server information (name, available tools).
- **Click-to-copy** configuration snippets to ease client setup. At minimum:
  - the raw endpoint URL;
  - a generic remote-MCP JSON snippet
    (`{"type":"http","url":"…/mcp","headers":{"Authorization":"Bearer <YOUR_KEY>"}}`);
  - provider-specific examples (OpenAI `server_url` + bearer header; Anthropic `url?_key=` form),
    matching the working examples in the notes.
  - The API key is shown as a `<YOUR_KEY>` placeholder — keys are minted on the admin page, not here.
- Basic usage instructions.
- A link to the admin page (`/admin/index.html`).

---

## Admin Page (`/admin/index.html` + `/api/admin`)

Owner-only (`"Private"`). v1 scope is **API key create/revoke** only.

### `/api/admin`

A `"Private"` API that performs key-management actions against the `/mcp` object's permissions. It
accepts an action plus parameters and returns the updated key list. Actions:

| Action | Effect |
|---|---|
| list | Return current `PermissionsKey` entries (`Information[mcp, "Permissions"]`), joined with any stored labels. |
| create | `key = CreateUUID[]`; `SetPermissions[mcp, PermissionsKey[key] -> "Execute"]`; optionally store a label; return the new key. |
| revoke | `DeleteObject[PermissionsKey[key]]`; drop any stored label. |

The created key is returned to the page once on creation so the owner can copy it (cloud does not
let you read a key back later).

### `/admin/index.html`

A static shell that calls `/api/admin` (over the owner session) to list keys, mint a new key
(displaying it once with a copy button), and revoke keys. No usage charts, no enable/disable toggle
in v1.

---

## Static Assets

HTML/CSS/JS for the landing and admin pages are bundled as paclet assets and deployed with
`CopyFile` to the target objects, as the notes suggest:

```wl
CopyFile[
    "path/to/local.html",
    CloudObject[ "path/to/target.html", Permissions -> permissions ],
    OverwriteTarget -> True
]
```

Proposed location: `Assets/Cloud/` (alongside the existing `Assets/Apps/`), e.g.
`Assets/Cloud/index.html`, `Assets/Cloud/admin.html`, `Assets/Cloud/assets/…`. The deploy code reads
them via `PacletObject["Wolfram/AgentTools"]["AssetLocation", "Cloud"]`, mirroring
`initializeUIResources`. The `PacletInfo.wl` `Asset` declarations are extended accordingly.

---

## Messages

New message tags to add to `Kernel/Messages.wl` (final wording during implementation):

```wl
AgentTools::CloudDeployFailed     = "Failed to deploy MCP server to the cloud: `1`.";
AgentTools::NotCloudConnected     = "A cloud connection is required to deploy an MCP server. Use CloudConnect to sign in.";
AgentTools::InvalidCloudTarget    = "Invalid cloud deployment target: `1`.";
```

Any tag used with `throwFailure` must be declared here. Reuse existing tags
(`InvalidArguments`, `DeletedMCPServerObject`, …) where applicable.

---

## Implementation Touchpoints

| File | Change |
|---|---|
| `Kernel/Server/Server.wl` | **New.** Entry point loading `Shared.wl`, `Local.wl`, `Cloud.wl`. |
| `Kernel/Server/Shared.wl` | **New.** Transport-agnostic core moved from `StartMCPServer.wl` (`handleMethod`, tool/prompt resolution, `evaluateTool`, result formatting, `initResponse`, bootstrapping) plus protocol-version negotiation. |
| `Kernel/Server/Local.wl` | **New.** `StartMCPServer`, stdio read loop, `superQuiet`, stdio logging, `toolWarmup`. |
| `Kernel/Server/Cloud.wl` | **New.** `CloudDeployMCPServer`, `RunRemoteMCPServer`, the `CloudDeploy` UpValue, directory/page/asset deployment, `/api/info`, `/api/admin`. |
| `Kernel/StartMCPServer.wl` | Removed (contents migrated to `Server/`), or reduced to a thin shim. Update `$AgentToolsContexts` accordingly. |
| `Kernel/Main.wl` | Replace `…`StartMCPServer` ` in `$AgentToolsContexts` with the `Server` contexts; add `CloudDeployMCPServer` and `RunRemoteMCPServer` to exported + protected name lists. |
| `Kernel/CommonSymbols.wl` | Declare newly shared symbols (`handleMethod`, `$preferredProtocolVersion`, deployment-path helpers, etc.). |
| `Kernel/MCPServerObject.wl` | No data-model change required. The `CloudDeploy` UpValue lives in `Cloud.wl`; the `$$transport` pattern already includes `"HTTP"`/`"ServerSentEvents"` should a transport tag be desired. |
| `Kernel/Files.wl` | Add any cloud-path helpers if needed (e.g. for the optional key-label store). |
| `PacletInfo.wl` | Add the two new symbols to `"Symbols"`; add `Assets/Cloud` to the asset declarations. |
| `Assets/Cloud/` | **New.** Landing/admin HTML, CSS, JS. |
| `Kernel/Messages.wl` | Add the new message tags. |
| `Tests/CloudDeployment.wlt` | **New.** Tests (see [Verification](#verification)). |
| `docs/cloud-deployment.md` | **New.** User-facing documentation. |
| `Documentation/English/ReferencePages/Symbols/` | Reference pages for `CloudDeployMCPServer` and `RunRemoteMCPServer`. |

> **MCP-server caution.** Because this paclet *is* the running MCP server providing the development
> tools, the `Server/` refactor must preserve `StartMCPServer` behavior exactly. Validate the local
> stdio server still starts and serves after the move before relying on the tools.

---

## Future Work

Items deferred from v1, in rough priority order:

- **`/logs/`** — capture per-request logs to a deployment log area, surfaced in the admin page.
- **`/files/`** — per-deployment artifact area; route MCP-App notebooks/images here instead of the
  global `AgentTools/Notebooks` location.
- **Usage monitoring** — request/usage counts per key, shown on the admin page (likely requires
  logging first).
- **Enable/disable toggle** — temporarily disable `/mcp` without deleting it (e.g. a flag the handler
  checks, or stripping/restoring non-owner permissions).
- **Caching / persistent kernels** — reduce per-request cold-start latency for heavyweight tools.
- **Local consumption** — a URL-based `InstallMCPServer` so local clients (Claude Desktop, etc.) can
  consume a deployed endpoint directly from its config.
- **Tool-safety options** — optional allowlisting / sandboxing of code-execution tools for public
  deployments.

---

## Verification

### `CloudDeployMCPServer` / `RunRemoteMCPServer`

1. Deploy a built-in server (e.g. `"WolframLanguage"`) with a single `PermissionsKey`; confirm the
   returned object is the `/mcp` `CloudObject`.
2. `POST` an `initialize` request; confirm a `200` `application/json` response whose result
   `protocolVersion` echoes a supported requested version (and falls back to `2025-11-25` for an
   unknown one).
3. `POST` `tools/list`; confirm the tool list matches the server object's tools.
4. `POST` `tools/call` for a simple tool (e.g. the notes' `PrimeFinder`, or `WolframAlpha`); confirm
   the result content.
5. `POST` a notification (e.g. `notifications/initialized`); confirm **`202`** with no body.
6. `GET` and `DELETE` the endpoint; confirm **`405`**.
7. Send a request with an unsupported `MCP-Protocol-Version`; confirm **`400`**. Send a disallowed
   `Origin`; confirm **`403`**. Send a malformed body; confirm **`400`**.
8. Authenticate via `Authorization: Bearer <key>` (OpenAI form) and via `?_key=<key>` (Anthropic
   form); confirm both succeed and that a request with no/invalid key is rejected by the cloud.
9. Deploy a **custom** server with an anonymous pure-function tool; confirm it works in the cloud
   (definition embedding), with no relevant paclet pre-installed.

### `CloudDeploy` (full directory)

10. `CloudDeploy[server]` (anonymous) and `CloudDeploy[server, "Name"]`; confirm the directory
    `CloudObject` is returned and that `/mcp`, `/index.html`, `/api/info`, `/admin/index.html`,
    `/api/admin` all exist.
11. Confirm `/index.html`, `/api/info`, and `/mcp` carry the resolved `Permissions` (default
    `$Permissions`), while `/admin/index.html` and `/api/admin` are `"Private"`.
12. Load `/index.html`; confirm it fetches `/api/info` and renders server name, tools, URL, and
    click-to-copy snippets with a `<YOUR_KEY>` placeholder.
13. Through `/api/admin`: create a key (confirm it appears in `Information[mcp, "Permissions"]` and
    is usable against `/mcp`), list keys, revoke it (confirm it is removed and no longer works).
14. Confirm `/api/admin` is unreachable without owner credentials.

### Refactor integrity

15. Confirm the local stdio `StartMCPServer` still initializes and serves `tools/list` / `tools/call`
    after the `Server/` refactor (no regression).
16. Run `CodeInspector` on all new/changed `Kernel/Server/*.wl` files.
17. Run `Tests/CloudDeployment.wlt` and the existing server test suites.
```