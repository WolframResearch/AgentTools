# Cloud Deployment of MCP Servers — Design Specification

## Overview

This feature lets a user deploy an `MCPServerObject` as a remote MCP server running in the
Wolfram Cloud, reachable over HTTP by any MCP-capable client — including the OpenAI Responses API
and the Anthropic Messages API remote-MCP features — without a local kernel:

```wl
CloudDeploy[ MCPServerObject[ ... ], ... ]
```

`CloudDeploy` of an `MCPServerObject` produces a `CloudObject` corresponding to a **deployment
directory** that contains the live MCP endpoint, a landing page, and an owner-only admin page. A
lower-level function, `CloudDeployMCPServer`, deploys *only* the MCP endpoint with caller-controlled
path and permissions. The endpoint itself is served by a new `RunCloudMCPServer` handler that
speaks a stateless subset of the **Streamable HTTP** transport of MCP protocol revision
**2025-11-25**. Although each request is a self-contained evaluation with no server-side session
store, the endpoint still supports **MCP-Apps** UI: it round-trips the client's UI capability through
a *self-describing* `Mcp-Session-Id` (see
[Client Capability Propagation](#client-capability-propagation-self-describing-session-ids)).

The local (`StartMCPServer`, stdio) and remote (cloud, HTTP) server implementations share a large
amount of request-handling logic. As part of this work that logic is refactored into a new
`Kernel/Server/` directory so both transports call into a common core (`handleMethod`, tool/prompt
resolution, result formatting, capability negotiation).

Three new public symbols are introduced:

| Symbol | Context | Purpose |
|---|---|---|
| `CloudDeployMCPServer` | ``Wolfram`AgentTools` `` | Deploy just the `/mcp` endpoint for a server object. |
| `RunCloudMCPServer` | ``Wolfram`AgentTools` `` | HTTP request handler invoked inside a deployed endpoint. |
| `CloudDeploy` (UpValue) | (existing `System` symbol) | `MCPServerObject /: CloudDeploy[obj, args___]` deploys the full directory. |

Both new symbols are declared identically — in `Kernel/Main.wl` (exported name list +
`$AgentToolsProtectedNames`) and `PacletInfo.wl` (`"Symbols"`) — and defined with
`beginDefinition` / `endExportedDefinition`. Their top-level error handling differs by role,
however: `CloudDeployMCPServer` wraps its body in `catchMine` (surfacing a `Failure[...]` on error).
`RunCloudMCPServer` is an HTTP handler that must **always return an `HTTPResponse`**, so it does
*not* rely on `catchMine` to surface a raw `Failure`; its wrapper converts failures into responses
instead — transport-level problems into HTTP status codes, dispatch/tool failures into an in-band
JSON-RPC `-32603` error within a `200` (mirroring the local `processRequest`'s
`If[ FailureQ @ response, … -32603 … ]` at `StartMCPServer.wl:528–531`), and any other unexpected
failure (e.g. from `initializeServerState`) into a `500`.

---

## Goals

- Support `CloudDeploy[MCPServerObject[...], ...]` returning a `CloudObject` directory bundle.
- Provide `CloudDeployMCPServer` for deploying only the endpoint, with arbitrary path/permissions.
- Provide `RunCloudMCPServer[obj]` implementing the remote MCP transport from a server object.
- Reuse the local server's method dispatch / tool evaluation / serialization unchanged, by factoring
  the transport-agnostic core into a shared file.
- Reuse Wolfram Cloud's native `PermissionsKey` mechanism for API authentication (as a bearer token
  header **or** a `?_key=` URL parameter — both proven against OpenAI/Anthropic in the prototype).
- Ship a dynamic landing page (client-configuration help) and an owner-only admin page (API key
  create/revoke).
- Keep the cloud endpoint **stateless** — each HTTP request is a self-contained evaluation with no
  server-side session store, matching the Wolfram Cloud `APIFunction`/`Delayed` execution model. Any
  client capability that must survive across requests travels in a self-describing `Mcp-Session-Id`,
  not in server memory.
- Support **MCP-Apps** UI in the cloud despite statelessness, by propagating the client's
  `io.modelcontextprotocol/ui` capability across requests through that session ID.
- Keep the deployment self-managing: the returned `CloudObject` and its admin page are the source of
  truth — no new local registry.

## Non-Goals (v1)

Explicitly out of scope for the initial implementation (see [Future Work](#future-work)):

- **`/logs/`** — server log storage.
- **`/files/`** — per-deployment artifact area. MCP-App artifacts (e.g. Wolfram|Alpha cloud
  notebooks, evaluator images) continue to use the existing **global** cloud locations written today
  by `deployCloudNotebookForMCPApp` (``AgentTools/Notebooks``, `Kernel/UIResources.wl:23`) and the
  Wolfram Language evaluator (``AgentTools/Images``, `Kernel/Tools/WolframLanguageEvaluator.wl:19`),
  independent of any deployment. MCP-Apps UI *itself* **is** in scope for v1 (see
  [Client Capability Propagation](#client-capability-propagation-self-describing-session-ids)); only
  the per-deployment `/files/` area is deferred, so those artifacts land in the global locations for
  now.
- **Usage monitoring** and an **enable/disable** toggle on the admin page.
- **Tool filtering / safety gating.** A deployed server exposes exactly the tools in its server
  object, including code-execution tools such as `WolframLanguageEvaluator`. Access control is the
  owner's responsibility, mediated entirely by API keys.
- **Caching / persistent kernels.** Each request is a fresh, stateless evaluation
  (see [Evaluation Model](#evaluation-model)).
- **Local consumption.** Making the deployed remote endpoint installable into local MCP clients
  (a URL-based `InstallMCPServer`) is a separate future effort.

---

## Design Decisions

At a glance (decisions resolved for v1):

| Decision | Choice |
|---|---|
| Phase 1 deliverables | `/mcp`, `/index.html`, `/api/info`, `/admin/index.html`, `/api/admin`, + 3 symbols. `/files/`, `/logs/` deferred. |
| `/mcp` transport | Stateless request/response (one POST → one JSON or single SSE frame). No server-side session store, no streaming, no server→client channel — but a **self-describing `Mcp-Session-Id`** carries client capabilities across requests. |
| MCP-Apps UI | **Supported in v1.** The client's UI capability is encoded into the session ID at `initialize` and decoded on later requests, re-establishing `$clientSupportsUI` per request. |
| Default target (no explicit path) | **Anonymous** `CloudObject[Permissions -> perms]` (server-assigned path). |
| `/mcp` permissions | Inherit the `Permissions` passed to `CloudDeploy` (same as `/index.html`); the admin page then adds/removes `PermissionsKey`s. |
| Landing page | **Dynamic**: static shell fetches live server metadata from a public `/api/info` at view time. |
| Protocol version | **Negotiate**: echo the client's requested version when supported, else return the preferred **2025-11-25**. Shared by local + cloud. |
| Cloud tool definitions | Runtime paclet presence (`Wolfram/AgentTools` + `Wolfram/Chatbook`) for built-in machinery; NOENTRY-aware capture of custom tool functions; **plus** a `Language`$InternalContexts`` dev-bundling bridge (removed once a cloud-native paclet exists). |
| Admin auth | Wolfram Cloud owner session (both admin artifacts `Private`; no embedded secret). |
| Local management | `CloudDeploy` returns the `CloudObject` directory; no local registry / wrapper object. |
| Client setup | Landing-page click-to-copy config snippets only; no auto-install into local clients. |
| Enable/disable | Dropped for v1. Admin page = API-key management only. |

Rationale for the less-obvious choices:

- **Stateless transport.** The endpoint implements a simplified MCP HTTP transport: one JSON-RPC
  request per POST, one response. No SSE streaming and no server→client `GET` channel, and — crucially
  — **no server-side session store**. It does, however, use the `Mcp-Session-Id` header the way the
  spec intends: the server issues one at `initialize` and the client echoes it on later requests. The
  twist is that the ID is *self-describing* — it encodes the client's negotiated capabilities
  directly, the way a signed token carries claims, so the server reconstructs them per request without
  storing anything (see
  [Client Capability Propagation](#client-capability-propagation-self-describing-session-ids)). This
  matches Wolfram Cloud's request/response model and is already proven against OpenAI/Anthropic remote
  MCP (`Notes/cloud-deployed-mcp-servers.md`). The consequence examined in
  [Statelessness](#statelessness-and-per-request-state) is that state set during `initialize` beyond
  what the session ID carries does not persist; `initializeServerState[obj]` rebuilds the rest per
  request from `obj` alone.
- **`/mcp` inherits the user's `Permissions`.** Whatever `Permissions` the user passes to
  `CloudDeploy` apply to both `/index.html` and the starting state of `/mcp`. The admin page then
  mints/revokes `PermissionsKey`s on `/mcp` without redeploying. (Deploying `Permissions -> "Public"`
  makes `/mcp` open; the recommended pattern is to deploy private and mint keys.)
- **No local registry.** `CloudDeploy` returns the directory `CloudObject`; the cloud objects and
  their permissions are the source of truth. Teardown is `DeleteObject` on the directory (and
  revoking any `PermissionsKey`s). A richer local deployment object/registry analogous to
  `AgentToolsDeployment` (`Kernel/DeployAgentTools.wl`, entirely local-disk today) is intentionally
  deferred.

---

## Architecture: `Kernel/Server/` Refactor

`StartMCPServer.wl` currently mixes transport-agnostic request handling with stdio-specific
plumbing. The shared portions are needed verbatim by the cloud handler, so the implementation is
reorganized into a `Server/` subdirectory.

| File | Context | Contents |
|---|---|---|
| `Kernel/Server/Server.wl` | ``…`Server` `` | Entry point that `Get`s the other three files. Added to `$AgentToolsContexts` in `Main.wl`. |
| `Kernel/Server/Shared.wl` | ``…`Server`Shared` `` | Transport-agnostic core (see below). |
| `Kernel/Server/Local.wl` | ``…`Server`Local` `` | `StartMCPServer` and stdio-specific logic. |
| `Kernel/Server/Cloud.wl` | ``…`Server`Cloud` `` | `CloudDeployMCPServer`, `RunCloudMCPServer`, the `CloudDeploy` UpValue, page/asset deployment, and the admin/info APIs. |

> **Symbol sharing.** Symbols consumed across the three `Server` files (or reached from
> `MCPServerObject.wl` and existing callers) are declared paclet-wide in `Kernel/CommonSymbols.wl`
> (context ``Wolfram`AgentTools`Common` ``), following the precedent for subcontext-shared symbols
> there (e.g. `exportMarkdownString`). Symbols shared *only* among the `Server` files may instead be
> forward-declared in `Server.wl`'s package header, following the `Kernel/Tools/Tools.wl` precedent.
> At minimum `handleMethod`, `initializeServerState`, `$preferredProtocolVersion`,
> `$supportedProtocolVersions`, and the deployment-path helpers are declared in `CommonSymbols.wl`.

### What moves to `Shared.wl`

Moved out of `StartMCPServer.wl` essentially unchanged (modulo context):

- **Dispatch:** `handleMethod` and every method handler (`initialize`, `ping`, `tools/list`,
  `tools/call`, `prompts/list`, `prompts/get`, `resources/list`, `resources/read`, notification
  dispatch, `id -> Null` and unknown-method fallbacks); `handleResourceRead`, `resourceReadError`,
  `resourceReadErrorMessage`.
- **Tool list construction:** `disambiguateToolNames`, `createMCPToolData`, `toolSchema`.
- **Prompt construction:** `makePromptData`, `makePromptData0`, `makePromptLookup`,
  `normalizeArguments`, `normalizeArgument`, `getPrompt`, `makePromptContent`,
  `consolidateTextContent`, `catchPromptFunction`, `formatPromptError`.
- **Tool evaluation & result formatting:** `evaluateTool`, `resultToContent`,
  `graphicsToImageContent`, `makeImageContent`, `extractWolframAlphaImages`, `extractImageContent`,
  `safeString`, `convertPUACharacters`, `toPrintableASCII`.
- **Capability / init:** `initResponse`, `makeInstructions` (with the negotiation change below).
- **Server/tool bootstrapping** reused by both transports: `ensurePacletsForStart`,
  `ensureDependenciesForStart`, `runServerInitialization`, `runToolInitialization`, plus
  `parseToolOptions` / `parseToolOptions0`.
- **State variables** the handlers read: `$currentMCPServer`, `$mcpEvaluation`, `$clientName`,
  `$clientSupportsUI`, `$clientSupportsRoots`, `$toolList`, `$llmTools`, `$promptList`,
  `$promptLookup`, `$toolOptions`.
- **Logging helpers** `writeLog`, `writeError`, `debugPrint`, `debugEcho`, `stderrEnabledQ`,
  `sequenceString`, `$logTimeStamp`. These already no-op safely off-stdio (`writeLog` requires
  `$logFile` to be a `File[...]`, which is unset in the cloud; `writeError`/`debugPrint` gate on
  `stderrEnabledQ[]`, which is `False` when `$clientName` is `None`). No sink abstraction is needed —
  they degrade to no-ops in the cloud. `superQuiet` (stdout/`$Output` redirection) is the one
  stdio-only piece and stays in `Local.wl`.

### New in `Shared.wl`: `initializeServerState`

The local server builds `$toolList` / `$llmTools` / `$promptList` / `$promptLookup` / `$toolOptions`
once at startup and `Block`s them for the life of the read loop
(`StartMCPServer.wl:102–143`). Extract that build into a transport-agnostic

```wl
initializeServerState[ obj_MCPServerObject ]
```

which runs the shared bootstrapping (`ensurePacletsForStart`, `runServerInitialization`,
`runToolInitialization`, `disambiguateToolNames`, `createMCPToolData`, `makePromptData`,
`makePromptLookup`, `parseToolOptions`, `initializeUIResources`) and returns the computed state
bundle. Each transport binds it with `Block`:

- **Local** calls it **once** at startup and `Block`s the values around the read loop.
- **Cloud** calls it **per request** inside `RunCloudMCPServer`'s `Block` (see
  [Evaluation Model](#evaluation-model)). *(Optional later optimization: memoize on `obj` within a
  warm cloud kernel.)*

`ensurePacletsForStart` / `ensureDependenciesForStart` are the runtime paclet-install hook that makes
paclet-backed and built-in tools resolvable in a fresh cloud kernel; they are fast no-ops once the
relevant paclets are present.

`initializeUIResources[]` is included because it is what populates the `$uiResourceRegistry` global that
`resources/list` (`listUIResources`, `UIResources.wl:240,250`) and `resources/read` (`readUIResource`,
`UIResources.wl:265`) read. Today the **local** server calls it once, outside the state-build `Block`
(`StartMCPServer.wl:132`), so the global persists for the life of the process. In the **stateless cloud**
that global is empty on every fresh request, so unless `initializeServerState` re-runs
`initializeUIResources[]` per request the UI registry is empty — and a UI-capable client that was told (via
`tools/list` `_meta.ui`, which derives from the load-time `$toolUIAssociations` and *does* work) to fetch a
resource would get an empty `resources/list` and a `-32602 UIResourceNotFound` from `resources/read`. Folding
the call into `initializeServerState` is what keeps MCP-Apps `resources/*` working in the cloud rather than
silently half-lit. (`initializeUIResources` degrades gracefully to `$uiResourceRegistry = <||>` if the app
assets are missing, so it is always safe to call.)

### What stays in `Local.wl`

- `StartMCPServer` (exported entry), `stealthCatchTop`, and the stdio read loop (`startMCPServer`,
  `processRequest`, `stdinShutdownQ`).
- `superQuiet`, the log-file plumbing (`$logFile`, `cleanupOldOutputLogs`, `outputLogFile`,
  `mcpServerLogFile` — some already in `Files.wl`), and the `While[True]` loop with its
  orphan-process check.
- Tool warmup (`toolWarmup`, `preinstallVectorDatabases`, `initializeVectorDatabases`,
  `$warmupTools`, `$warmupTask`) — a long-lived-process optimization that does not apply to
  stateless cloud requests.

> **Shared-declaration caveat.** A symbol can only "stay in `Local.wl`" as a *file-private* if nothing
> moved to `Shared.wl` reads it. Two do not qualify and must be **declared in a shared context**
> (`Server.wl`'s header or `CommonSymbols.wl`) even though only the local read loop ever assigns them —
> because the functions that read them are moving to `Shared.wl`: `$logFile` (read by `writeLog`,
> `StartMCPServer.wl:1078`) and `$warmupTask` (read by `evaluateTool`, `StartMCPServer.wl:882`). Both are
> currently pure file-privates of `StartMCPServer.wl` (no `CommonSymbols.wl` declaration). If they are left
> private to `Local.wl`, the `Shared.wl` readers resolve a *different*, always-unset symbol, silently
> disabling local file logging and warmup cancellation — precisely the `StartMCPServer` regression the
> refactor is cautioned to avoid. Only `$warmupTools` (assigned in `processRequest` and read in
> `startMCPServer`, both staying in `Local.wl`) is genuinely file-local.

### Protocol version negotiation (shared)

Today `$protocolVersion = "2024-11-05"` is a hardcoded constant (`StartMCPServer.wl:15`) that
`initResponse` echoes verbatim; the current `initResponse` accepts the client message but **ignores
its requested `protocolVersion`** (`StartMCPServer.wl:1012–1039`). The shared layer replaces this
with explicit negotiation:

```wl
$supportedProtocolVersions = { "2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05" };
$preferredProtocolVersion  = "2025-11-25";
```

`initResponse` reads `msg[["params","protocolVersion"]]`: if it is a member of
`$supportedProtocolVersions`, echo it back; otherwise return `$preferredProtocolVersion`. This
follows the [lifecycle rules](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle)
and is used by **both** transports, so bumping the local stdio server's advertised version comes for
free and remains backward compatible. The exact `$preferredProtocolVersion` should be re-confirmed
against the versions OpenAI/Anthropic actually send during [verification](#verification).

---

## Statelessness and Per-Request State

The cloud endpoint is stateless: `initialize`, `tools/list`, and `tools/call` each arrive as
*separate* HTTP requests, each a fresh kernel evaluation. This has a design consequence worth making
explicit, because the shared `handleMethod` was written for a long-lived stdio process:

- `handleMethod["initialize", …]` sets session globals `$clientName`, `$clientSupportsUI`,
  `$clientSupportsRoots` (`StartMCPServer.wl:542–548`). In the cloud these do not survive as *kernel*
  state to the following `tools/list` request — but the ones the client needs downstream are not lost:
  they are re-derived from the **session ID** the client echoes on each request (see
  [Client Capability Propagation](#client-capability-propagation-self-describing-session-ids)).
- `tools/list` renders `withToolUIMetadata @ $toolList`, gated on `$clientSupportsUI`
  (`StartMCPServer.wl:555`). In the cloud, `RunCloudMCPServer` `Block`s `$clientSupportsUI` to the
  value decoded from the request's `Mcp-Session-Id`, so a client that advertised
  `io.modelcontextprotocol/ui` at `initialize` **still receives** UI metadata here — MCP-Apps UI works
  rather than silently degrading. A client that advertised no UI support gets a session ID encoding no
  features, and `withToolUIMetadata` is a no-op exactly as on the local server.

This *does* require code — the session-ID encode/decode described below — but no change to the shared
handlers: they keep reading `$clientSupportsUI`, and the cloud transport binds it correctly per
request. The handler must also not *assume* `initialize` ran first: `initializeServerState[obj]`
rebuilds the tool and prompt tables on every request from `obj` alone, and the capability globals come
from the session ID, not from any retained `initialize` call.

The MCP **roots** handshake is likewise a no-op in the cloud (no local working directory), so the
server simply does not issue it. Acting on roots would need the server→client channel the stateless
transport does not provide, so it is deferred rather than tracked in v1 (see
[Deferred capabilities](#deferred-capabilities)).

---

## Client Capability Propagation (Self-Describing Session IDs)

MCP-Apps UI hinges on a single boolean, `$clientSupportsUI`: `initResponse` advertises the
`io.modelcontextprotocol/ui` extension under it (`StartMCPServer.wl:1028–1035`), `tools/list` attaches
`_meta.ui` under it (`withToolUIMetadata`, `UIResources.wl:289,306`), `resources/list` enumerates the
UI registry under it (`UIResources.wl:240`), and the built-in tools deploy their app notebooks under it
(`WolframAlpha.wl:63`, `WolframLanguageEvaluator.wl:119`). Locally that boolean is set once at
`initialize` and stays set for the life of the process. In the stateless cloud, `initialize` and
`tools/list` are *different requests* — so the boolean would be back to `False` by the time it matters,
and MCP-Apps would never light up.

Rather than add a server-side session store, v1 makes the **session ID itself carry the answer**. This
is the `Mcp-Session-Id` mechanism the Streamable HTTP transport already defines — the server issues an
ID at `initialize` and the client echoes it on every subsequent request — but the ID is
*self-describing*: it encodes the client's negotiated capabilities directly, the way a signed token
carries claims. The server reconstructs `$clientSupportsUI` from the ID on each request and stores
nothing.

### Tracked features and the session-ID format

A small, ordered list of tracked capability flags is packed into a bit vector, base-36 encoded, and
embedded in a versioned, colon-delimited session ID (file-scoped in `Cloud.wl`):

```wl
$trackedFeatureList = { "MCPApps" };
$idVersion          = "1";
$trackedFeatureIDs  = First /@ PositionIndex[ $trackedFeatureList ] - 1;
(* <| "MCPApps" -> 0 |> *)

(* encode: feature list -> "version:base36bitfield:uuid" *)
makeSessionIDFromFeatureList[ clientFeatures_List ] :=
    StringRiffle[
        {
            $idVersion,
            IntegerString[
                Total[ 2 ^ Lookup[ $trackedFeatureIDs, Intersection[ clientFeatures, $trackedFeatureList ] ] ],
                36
            ],
            CreateUUID[ ]
        },
        ":"
    ];

(* decode: session ID -> feature list (unknown version / malformed -> {}) *)
getFeaturesFromSessionID[ sessionID_String ] := getFeaturesFromSessionID @ StringSplit[ sessionID, ":" ];

getFeaturesFromSessionID[ { "1", featureString_String, _String } ] :=
    Pick[
        $trackedFeatureList,
        Reverse @ IntegerDigits[ FromDigits[ featureString, 36 ], 2, Length @ $trackedFeatureList ],
        1
    ];

getFeaturesFromSessionID[ _ ] := { };
```

For example, `makeSessionIDFromFeatureList[{"MCPApps"}]` → `"1:1:880837da-…"` and
`makeSessionIDFromFeatureList[{}]` → `"1:0:…"`; `getFeaturesFromSessionID` inverts each. The middle
field is a genuine base-36 bit vector, so the format extends to more features without changing shape
(a second flag at bit 1 would push the field to `"3"` when both are set) — but v1 tracks only
`MCPApps`, so the field is always `"0"` or `"1"`.

Three properties make this safe:

- **`Intersection` guard.** Encoding intersects with `$trackedFeatureList` first, so an untracked
  feature never reaches `Lookup`/`2^…`. The empty set totals to `0` (`"1:0:…"`).
- **Versioned, fail-closed decode.** Only the `"1"` shape decodes to features; any other version or a
  malformed ID falls through to `{ }`. So a client replaying a session ID minted by an *older*
  deployment — after the feature list changed and `$idVersion` was bumped — simply gets no features,
  turning MCP-Apps **off** rather than misfiring. `$idVersion` must be bumped whenever
  `$trackedFeatureList` changes in a way that shifts bit positions.
- **Opaque and unique.** The trailing `CreateUUID[ ]` keeps every ID unique and unguessable, so the
  string remains a valid session identifier, not merely a capability blob.

### v1 wiring

In v1 `"MCPApps"` is the only tracked feature, and it maps to the one boolean that gates all UI
behavior:

| Tracked feature | Encoded when | Decoded state (v1) |
|---|---|---|
| `MCPApps` | client sent `io.modelcontextprotocol/ui` **and** `mcpAppsEnabledQ[]` | `$clientSupportsUI = True` |

The two directions:

- **At `initialize`** (no incoming session ID): the shared `handleMethod["initialize", …]` sets
  `$clientSupportsUI` / `$clientSupportsRoots` from the client message exactly as today
  (`StartMCPServer.wl:542–548`, reusing `clientSupportsUIQ` / `mcpAppsEnabledQ`). `RunCloudMCPServer`
  then reads those flags, builds the tracked-feature list, calls `makeSessionIDFromFeatureList`, and
  returns the result in the **`Mcp-Session-Id` response header**.
- **On every later request**: `RunCloudMCPServer` reads the `Mcp-Session-Id` request header
  (case-insensitively), calls `getFeaturesFromSessionID`, and `Block`s
  `$clientSupportsUI = MemberQ[ features, "MCPApps" ]` (and, in future, the other globals) around
  dispatch. The shared handlers are unchanged — they still just read `$clientSupportsUI`.

### Deferred capabilities

MCP-Apps is the only capability the cloud transport tracks in v1 because it is special: it is
satisfiable *within a single request* — the server only has to format its own response (attach
metadata, serve a resource). Other capabilities such as **roots** and **elicitation** instead require
the server to *call back to the client* (`roots/list`, an elicitation request), which needs the
server→client channel the stateless transport does not provide. They are therefore left out of the
tracked-feature list entirely in v1; when a fuller transport exists they can be added as new flags
(appended to `$trackedFeatureList`, bumping `$idVersion` if any existing bit position would shift). See
[Future Work](#future-work).

### Compatibility

This rests on one assumption: that the client honors the spec's rule that a returned `Mcp-Session-Id`
is echoed on every subsequent request. Spec-compliant clients must, but the stateless prototype in the
notes never issued a session ID, so whether the **OpenAI and Anthropic** remote-MCP clients actually
round-trip it is unconfirmed and is called out explicitly in [verification](#verification). The design
fails safe either way: if a client does *not* echo it, every request decodes to no features and
MCP-Apps simply stays off — a clean degradation with no correctness impact, identical to the
pre-session behavior. (Only MCP-Apps-capable clients that also honor session IDs light up the UI; no
client is worse off than before.)

---

## `CloudDeploy` (UpValue on `MCPServerObject`)

Deploys the full directory bundle. Defined as an UpValue, mirroring the existing `MCPServerObject`
upvalues `DeleteObject` and `LLMConfiguration` (`MCPServerObject.wl:732–740`).

### Definition

```wl
MCPServerObject /: CloudDeploy[ obj_MCPServerObject, args___ ] :=
    catchTop[ cloudDeployDirectory[ obj, args ], MCPServerObject ];
```

> **Naming.** The internal `cloudDeployDirectory` (full directory) is distinct from the exported
> `CloudDeployMCPServer` / internal `cloudDeployEndpoint` (endpoint only). The directory builder
> reuses the endpoint primitive for `/mcp`.

### Arguments and options

| Argument | Type | Description |
|---|---|---|
| `obj` | `MCPServerObject` | The server to deploy. |
| target (optional) | `String` or `CloudObject` | Deployment directory prefix. Omitted ⇒ anonymous `CloudObject[Permissions -> perms]`. |

Options follow `CloudDeploy`'s grammar and are forwarded to the underlying `CloudDeploy`/`CloudObject`
calls where meaningful (mirroring the `FilterRules`-by-`Options` pass-through pattern in
`DeployAgentTools.wl:254–259,373`). `Permissions` (default the ambient `$Permissions`) sets the
resolved permissions used for `/index.html`, `/api/info`, and the initial `/mcp` state; `/admin/*` and
`/api/admin` are forced to `"Private"` regardless.

### Behavior

Given resolved permissions `perms`:

1. Validate the server object (`ensureMCPServerExists`) and require a cloud session
   (`$CloudConnected`, else `throwFailure["NotCloudConnected"]`). *(Note: there is no existing
   abort-on-disconnect pattern in the codebase — current cloud code silently falls back — so this is
   a new, deliberate guard.)*
2. Resolve the directory `CloudObject` (explicit target, or anonymous `CloudObject[Permissions ->
   perms]`) and sub-object paths by joining onto the directory, mirroring `UIResources.wl`
   (`FileNameJoin[{dir, "mcp"}]`, etc.).
3. Deploy `/mcp` via the endpoint primitive (see [`CloudDeployMCPServer`](#clouddeploymcpserver)),
   carrying the server's definitions (see [Embedding the Server](#embedding-the-server)), at `perms`.
4. Deploy `/index.html`, `/assets/*`, and `/api/info` at `perms`.
5. Deploy `/admin/index.html` and `/api/admin` as `"Private"`.
6. Return the directory `CloudObject`.

### Example

```wl
server = MCPServerObject[ "WolframLanguage" ];
dir    = CloudDeploy[ server ]
(* CloudObject["https://www.wolframcloud.com/obj/<user>/<server-assigned-uuid>"] *)
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
| `target` | `String` or `CloudObject` | Endpoint location. Omitted ⇒ anonymous `CloudObject[Permissions -> perms]`. |

```wl
CloudDeployMCPServer // beginDefinition;
CloudDeployMCPServer[ obj_, args___ ] := catchMine @ cloudDeployEndpoint[ obj, args ];
CloudDeployMCPServer // endExportedDefinition;
```

Options are forwarded to `CloudDeploy`; `Permissions` defaults to `$Permissions`.

### Behavior

1. Resolve `obj` to a validated `MCPServerObject`.
2. Build the deployable, definition-bearing expression for `Delayed[RunCloudMCPServer[obj]]`
   (see [Embedding the Server](#embedding-the-server)).
3. `CloudDeploy` it to `target` with the resolved permissions.
4. Return the resulting `/mcp` `CloudObject`.

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

## `RunCloudMCPServer`

The handler deployed (via `Delayed`) at `/mcp`. It is the cloud analog of the local
`processRequest`/read-loop, but handles exactly one HTTP request and returns an `HTTPResponse`. It is
exported so the serialized `Delayed[RunCloudMCPServer[obj]]` payload references a real symbol.

### Signature

```wl
RunCloudMCPServer[ obj_MCPServerObject ]   (* handles the current HTTPRequestData[] *)
```

The notes' prototype hardcodes `$toolList`/`$llmTools`; the real implementation derives all server
state from `obj` via the shared `initializeServerState[obj]`.

### Request handling (stateless Streamable HTTP, 2025-11-25)

Grounded in the
[transport spec](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports). The
handler runs inside `Block[{ $currentMCPServer = obj, $mcpEvaluation = True, $clientSupportsUI = <decoded>,
<state from initializeServerState[obj]> }, … ]` so tools format their output for MCP exactly as they
do locally. `$clientSupportsUI` (and any other capability global) is bound to the value decoded from
the request's `Mcp-Session-Id` header (see
[Client Capability Propagation](#client-capability-propagation-self-describing-session-ids)); for the
`initialize` request itself there is no incoming session ID, so `handleMethod["initialize", …]` sets
it from the message as usual. Unlike the stdio path there is no `stdout` to protect, so `superQuiet`
is not used (messages are still suppressed from the response body).

**Transport-level checks (produce HTTP status codes):**

1. **Method.** The endpoint handles `POST`. `GET` (the optional server→client SSE stream) and
   `DELETE` (session teardown) return **`405 Method Not Allowed`** — there is no server-side session
   state to stream from or tear down, so both are no-ops the spec permits a server to decline. (The
   self-describing session ID needs no explicit teardown: it lives only in the client's copy.)
2. **Origin validation.** If an `Origin` header is present and not allowed ⇒ **`403 Forbidden`**
   (DNS-rebinding protection). Absent `Origin` (typical for server-to-server LLM providers) is
   allowed.
3. **Protocol version header.** For non-`initialize` requests, read `MCP-Protocol-Version`. If
   present but unsupported ⇒ **`400 Bad Request`**. If absent, assume `2025-03-26` per spec.
4. **Accept negotiation.** Choose the response content type from the `Accept` header via
   `responseContentType`, preferring `application/json`, falling back to `text/event-stream`. If
   neither is acceptable ⇒ **`406 Not Acceptable`**. *(The prototype returned `405` here;
   `406` is the correct code.)*
5. **Malformed body** (non-JSON, or not a JSON object) ⇒ **`400 Bad Request`**.

**Message dispatch (JSON-RPC, HTTP `200`/`202`):** the single JSON-RPC message in the body is routed
through the shared `handleMethod`:

- **Request** (has `id` + `method`) ⇒ dispatch; return the JSON-RPC result as the negotiated content
  type with **`200`**. A handler-level problem is reported *in the JSON-RPC body*, not as an HTTP
  error: unknown method ⇒ error `-32601`; internal/tool failure ⇒ error `-32603` (still HTTP `200`).
- **Notification / Response / `id -> Null`** (no reply owed) ⇒ **`202 Accepted`** with an empty body.

**Session ID (client-capability round-trip).** Before dispatch, the handler reads the `Mcp-Session-Id`
request header (case-insensitively) and decodes it via `getFeaturesFromSessionID` into the capability
set that parameterizes the `Block` above. For an `initialize` request there is no incoming session ID;
after `handleMethod` runs (setting `$clientSupportsUI` / `$clientSupportsRoots` from the client's
declared capabilities), the handler encodes those into a fresh session ID with
`makeSessionIDFromFeatureList` and returns it as the `Mcp-Session-Id` **response** header, per the
Streamable HTTP spec. Full mechanism, encoding, and robustness in
[Client Capability Propagation](#client-capability-propagation-self-describing-session-ids).

`responseContentType` and `makeResponseString` (which emits compact JSON for `application/json`, or a
single `data: <json>\n\n` frame for `text/event-stream`) are new helpers adapted from the prototype;
neither, nor any of `Delayed`/`APIFunction`/`HTTPResponse`/`HTTPRequestData`/`SetPermissions`/
`PermissionsKey`, exists in the codebase today. The `HTTPResponse` `ContentType` must reflect the
negotiated type (the prototype hardcoded `application/json` even for the SSE branch — a bug to avoid).

### Capabilities in the cloud

`initialize` advertises `tools` and `prompts` as the local server does, and — when the client's
`initialize` declares the `io.modelcontextprotocol/ui` extension — advertises that extension too,
exactly as `initResponse` already does under `$clientSupportsUI` (`StartMCPServer.wl:1028–1035`).
Because that same capability is re-established on every later request from the session ID, **MCP-Apps
UI is fully supported**: `tools/list` attaches `_meta.ui` (`withToolUIMetadata`), `resources/list`
enumerates the UI registry, and `resources/read` serves the app HTML — all gated on the decoded
`$clientSupportsUI`. UI artifacts (Wolfram|Alpha notebooks, evaluator images) deploy through the
existing `deployCloudNotebookForMCPApp` path to the global cloud locations (per-deployment `/files/` is
still deferred; see [Non-Goals](#non-goals-v1)). `logging` is still **not** advertised — log
notifications require a server→client streaming channel, which the stateless transport does not
provide.

---

## Embedding the Server

The deployed `/mcp` endpoint must reconstruct the server — including any **custom, anonymous tool
functions** — at request time, in a cloud kernel that lacks the user's local definitions. This is the
most technically delicate part of the design. Two independent stripping mechanisms must be overcome,
both confirmed empirically in a live kernel:

1. **Context-based stripping.** Both ``Wolfram`AgentTools`*`` and ``Wolfram`Chatbook`*`` are members
   of ``Language`$InternalContexts``, so their definitions are stripped from serialized expressions
   (and from `CloudDeploy`) by default. Removing ``Wolfram`AgentTools`*`` from that list causes the
   AgentTools definitions reachable from `RunCloudMCPServer[obj]` to be captured — but the payload
   grows from ~0.4 KB to **~5 MB**, and Chatbook remains stripped.
2. **Flag-based blocking.** `LLMTool` carries the `NOENTRY` flag, so standard `ExtendedFullDefinition`
   (and therefore `CloudDeploy`'s own definition capture) **cannot see the user-defined functions
   inside a tool**. The paclet already solves this for local serialization: `CreateMCPServer` uses
   `binarySerializeWithDefinitions` (`Kernel/Utilities.wl:16–46`), whose `extendedFullDefinition`
   recursively unpacks `NOENTRY` subexpressions (`Utilities.wl:51–103`) so tool functions are
   captured.

### v1 mechanism (dev-bundling bridge + custom-function capture)

A single deploy helper builds the definition-bearing payload for `/mcp`, combining both fixes:

- Run inside ``Block[{ Language`$InternalContexts = DeleteCases[ Language`$InternalContexts, _?(StringStartsQ[#, "Wolfram`AgentTools`"]&) ] }, … ]`` so AgentTools's own definitions
  (`RunCloudMCPServer`, `handleMethod`, tool/prompt resolution, result formatting) are captured
  rather than stripped. This makes the endpoint self-contained without a published paclet — the point
  of the dev bridge.
- Gather definitions with the paclet's **NOENTRY-aware** `extendedFullDefinition` so custom tool
  functions inside the server object's `LLMTool`s are included, and inject them into the deployed
  expression using the same ``Language`ExtendedFullDefinition[ ] = defs; expr`` strategy that
  `binarySerializeWithDefinitions` already implements. (Do **not** rely on `CloudDeploy`'s built-in
  capture for these — it is NOENTRY-blocked.)

Chatbook is deliberately *not* serialized (it stays internal, and bundling it is neither necessary nor
practical). Built-in tools (e.g. `WolframLanguageEvaluator`, `WolframAlpha`) call into Chatbook, so a
deployed built-in server additionally **requires `Wolfram/Chatbook` to be present in the cloud
kernel** — ensured at cold start by the shared bootstrapping (`ensureDependenciesForStart`, and
`PacletInstall` for paclet-qualified names). A fully **self-contained custom server** (pure-function
tools, no built-in/Chatbook dependencies) works with no paclet present.

> The ``Language`$InternalContexts`` block is isolated in this one deploy helper so it can be removed
> cleanly. If inline injection proves awkward for a given server, an equivalent fallback is to write
> the payload's bytes (as produced by `binarySerializeWithDefinitions`) to a `"Private"` object in the
> deployment directory and have the handler `BinaryDeserialize` it on cold start; the two approaches
> are interchangeable.

### End state (future)

Once a cloud-native `Wolfram/AgentTools` paclet is available by default in the Wolfram Cloud, drop the
``Language`$InternalContexts`` block: `RunCloudMCPServer` and the built-in tools resolve from the
installed paclet, and only the user's custom tool functions are carried in the payload (still via the
NOENTRY-aware serializer). See [Future Work](#future-work).

### Evaluation Model

Each request is a **fresh, stateless** evaluation (`Delayed`/`APIFunction`-style); there is no
persistent kernel between calls in v1. Consequences, accepted for v1 and documented for users:

- Per-request **cold-start cost**: paclet loading and any tool initialization (e.g. vector-database
  installation for the `*Context` search tools) recur on every call. Context/search tools therefore
  carry a substantial latency penalty in the cloud and additionally require cloud connectivity and an
  LLMKit subscription on the deploying account.
- No cross-request state, sessions, or warmup. The stdio-only `toolWarmup` path is not used.

Caching / persistent kernels are [future work](#future-work).

---

## Deployed Directory Layout & Permissions

`CloudDeploy[obj]` populates a deployment directory (a `CloudObject` path prefix) by joining
sub-objects onto the directory object, mirroring `UIResources.wl`.

| Path | Purpose | Permissions | v1 |
|---|---|---|---|
| `/mcp` | Live MCP endpoint (`Delayed[RunCloudMCPServer[obj]]`). | Resolved `Permissions`; admin page adds/removes `PermissionsKey`s. | ✅ |
| `/index.html` | Landing page (client-configuration help). | Resolved `Permissions`. | ✅ |
| `/api/info` | Public server metadata consumed by the landing page. | Resolved `Permissions` (readable by anyone who can view the page). | ✅ |
| `/assets/*` | CSS/JS for the two pages. | Resolved `Permissions`. | ✅ |
| `/admin/index.html` | Owner-only admin page (API key create/revoke). | **Always `"Private"`.** | ✅ |
| `/api/admin` | Owner-only API backing the admin page. | **Always `"Private"`.** | ✅ |
| `/files/` | Per-deployment artifact area. | — | Deferred |
| `/logs/` | Server log storage. | — | Deferred |

### Default location

When the caller supplies no explicit target, the directory is an **anonymous** cloud object:

```wl
dir = CloudObject[ Permissions -> perms ]   (* anonymous, server-assigned path *)
```

An explicit second argument (`"MyServer"` or a `CloudObject[...]`) overrides this. Because there is no
local registry, the returned `CloudObject` (and, for anonymous deploys, its URL) is the only handle to
the deployment — callers should retain it.

### Return values

`CloudDeploy[obj, ...]` returns the **directory** `CloudObject`. `CloudDeployMCPServer[...]` returns
the **`/mcp`** `CloudObject`.

### Authentication

Authentication is delegated entirely to Wolfram Cloud's native `PermissionsKey` mechanism; the handler
performs **no** key validation — an unauthorized caller never reaches `RunCloudMCPServer`.

- **`/mcp`** — callers authenticate with a `PermissionsKey`, accepted by Wolfram Cloud either as the
  bearer token in an `Authorization: Bearer <key>` header (OpenAI's MCP client) or as a `?_key=<key>`
  URL parameter (Anthropic's MCP client). Both were validated against the prototype
  (`Notes/cloud-deployed-mcp-servers.md:258–332`). Missing/invalid key ⇒ Wolfram Cloud returns a
  `401`/permission error before the handler runs.
- **`/admin/index.html` and `/api/admin`** — `"Private"`, reached through the owner's authenticated
  Wolfram Cloud session; the admin page's same-origin `fetch` calls carry the owner's credentials, and
  `/api/admin` executes server-side as the owner (so it may `SetPermissions` on the sibling `/mcp`).
  No secret is embedded in any page.

### Managing API keys

The admin API manipulates the `/mcp` object's permissions with the standard cloud primitives, as
prototyped (`Notes/cloud-deployed-mcp-servers.md:64–108`):

```wl
key = CreateUUID[ ];                                  (* create *)
SetPermissions[ mcp, PermissionsKey[ key ] -> "Execute" ];

Information[ mcp, "Permissions" ];                    (* list   *)

DeleteObject[ PermissionsKey[ key ] ];                (* revoke *)
```

Because `PermissionsKey` UUIDs are opaque, the admin API *may* persist optional human-readable
**labels** in a small `"Private"` object inside the deployment (e.g. `/admin/keys.wxf`). This is a
convenience only; the authoritative list of valid keys is always the object's live permissions. No
usage statistics are recorded in v1.

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

- Basic server information (name, version, available tools).
- **Click-to-copy** configuration snippets to ease client setup. Note that the notebook helper
  `clickToCopy` (`Formatting.wl:263–270`) emits *notebook boxes*, not HTML, so the page implements
  copy-to-clipboard in JavaScript; only the JSON-config *shape* from `makeJSONConfiguration`
  (`MCPServerObject.wl:649–659`) is reused, adapted to the remote `url`+`headers` form. At minimum:
  - the raw endpoint URL;
  - a generic remote-MCP JSON snippet
    (`{"type":"http","url":"…/mcp","headers":{"Authorization":"Bearer <YOUR_KEY>"}}`);
  - provider-specific examples (OpenAI `server_url` + bearer header; Anthropic `url?_key=` form),
    matching the working examples in the notes;
  - the API key shown as a `<YOUR_KEY>` placeholder — keys are minted on the admin page, not here.
- Basic usage instructions (how to obtain a key, how to authenticate).
- A link to the admin page (`/admin/index.html`).

---

## Admin Page (`/admin/index.html` + `/api/admin`)

Owner-only (`"Private"`). v1 scope is **API-key create/revoke** only.

### `/api/admin`

A `"Private"` API that performs key-management actions against the `/mcp` object's permissions,
resolving the sibling `/mcp` object from the captured deployment base. Actions:

| Action | Effect | Returns |
|---|---|---|
| `listKeys` | `Information[mcp, "Permissions"]`, joined with any stored labels. | Current `PermissionsKey` entries. |
| `createKey` | `key = CreateUUID[]`; `SetPermissions[mcp, PermissionsKey[key] -> "Execute"]`; optionally store a label. | The new key (shown once) + updated list. |
| `revokeKey` | `DeleteObject[PermissionsKey[key]]`; drop any stored label. | Updated key list. |

The created key is returned to the page once on creation so the owner can copy it (the cloud does not
let you read a key back later).

### `/admin/index.html`

A static shell that calls `/api/admin` (over the owner session) to list keys, mint a new key
(displaying it once with a copy button), and revoke keys. No usage charts, no enable/disable toggle in
v1.

---

## Static Assets

HTML/CSS/JS for the landing and admin pages are bundled as paclet assets under `Assets/Cloud/`
(alongside the existing `Assets/Apps/`), e.g. `Assets/Cloud/index.html`, `Assets/Cloud/admin.html`,
`Assets/Cloud/assets/…`. The deploy code reads them via
`PacletObject["Wolfram/AgentTools"]["AssetLocation", "Cloud"]`, mirroring `initializeUIResources`
(`UIResources.wl:186–190`), and pushes them with `CopyFile` (static admin assets) or renders the shell
before writing (the dynamic landing page needs no deploy-time templating, since it fetches
`/api/info`):

```wl
CopyFile[
    localPath,
    CloudObject[ targetPath, Permissions -> perms ],
    OverwriteTarget -> True
]
```

`PacletInfo.wl`'s `"Asset"` extension (`PacletInfo.wl:59–66`) gains a `{ "Cloud", "Assets/Cloud" }`
row.

---

## Messages

New tags for `Kernel/Messages.wl`, under a `(* Cloud deployment messages *)` banner (final wording
during implementation), registered on `AgentTools` and resolved onto the wrapping symbol by
`throwFailure`:

```wl
AgentTools::CloudDeployFailed  = "Failed to deploy MCP server to the cloud: `1`.";
AgentTools::NotCloudConnected  = "A cloud connection is required to deploy an MCP server. Use CloudConnect to sign in.";
AgentTools::InvalidCloudTarget = "Invalid cloud deployment target: `1`.";
```

Any tag used with `throwFailure` must be declared here. Reuse existing tags (`InvalidArguments`,
`DeletedMCPServerObject`, …) where applicable.

---

## Implementation Touchpoints

| File | Change |
|---|---|
| `Kernel/Server/Server.wl` | **New.** Entry point loading `Shared.wl`, `Local.wl`, `Cloud.wl`. |
| `Kernel/Server/Shared.wl` | **New.** Transport-agnostic core moved from `StartMCPServer.wl` (dispatch, tool/prompt resolution, `evaluateTool`, result formatting, `initResponse`, bootstrapping, logging helpers) + `initializeServerState` + protocol-version negotiation. |
| `Kernel/Server/Local.wl` | **New.** `StartMCPServer`, stdio read loop, `superQuiet`, log-file plumbing, `toolWarmup`. |
| `Kernel/Server/Cloud.wl` | **New.** `CloudDeployMCPServer`, `RunCloudMCPServer`, the `CloudDeploy` UpValue, directory/page/asset deployment, `responseContentType`/`makeResponseString`, the `Mcp-Session-Id` capability encode/decode (`$trackedFeatureList`, `$idVersion`, `makeSessionIDFromFeatureList`, `getFeaturesFromSessionID`), `/api/info`, `/api/admin`, the definition-bundling deploy helper, key CRUD. |
| `Kernel/StartMCPServer.wl` | Reduced to a thin shim (or removed) once contents migrate to `Server/`. |
| `Kernel/Main.wl` | Replace ``…`StartMCPServer` `` in `$AgentToolsContexts` (`:62–86`) with the `Server` contexts; add `CloudDeployMCPServer`, `RunCloudMCPServer` to the exported list (`:14–35`) and `$AgentToolsProtectedNames` (`:101–123`). |
| `Kernel/CommonSymbols.wl` | Declare newly-shared symbols (`handleMethod`, `initializeServerState`, `$preferredProtocolVersion`, `$supportedProtocolVersions`, deployment-path helpers). |
| `Kernel/MCPServerObject.wl` | No data-model change required. The `CloudDeploy` UpValue lives in `Cloud.wl`; `$$transport` already admits `"HTTP"`/`"ServerSentEvents"` (`:22`) should a transport tag be desired. |
| `Kernel/Files.wl` | Add cloud-path helpers if needed (e.g. for the optional key-label store). |
| `PacletInfo.wl` | Add the two symbols to `"Symbols"` (`:22–50`); add `{ "Cloud", "Assets/Cloud" }` to the `"Asset"` extension (`:59–66`). |
| `Assets/Cloud/` | **New.** Landing/admin HTML, CSS, JS. |
| `Kernel/Messages.wl` | Add the new message tags. |
| `Tests/CloudDeployment.wlt` | **New.** Tests (see [Verification](#verification)). |
| `docs/cloud-deployment.md` | **New.** User-facing documentation. |
| `Documentation/English/ReferencePages/Symbols/` | Reference pages for `CloudDeployMCPServer` and `RunCloudMCPServer`. |

> **MCP-server caution.** Because this paclet *is* the running MCP server providing the development
> tools, the `Server/` refactor must preserve `StartMCPServer` behavior exactly. Validate the local
> stdio server still starts and serves after the move before relying on the tools.

---

## Future Work

Deferred from v1, in rough priority order:

- **Cloud-native AgentTools paclet** → drop the ``Language`$InternalContexts`` dev-bundling block;
  resolve `RunCloudMCPServer` and built-in tools from the installed paclet.
- **`/logs/`** — capture per-request logs to a deployment log area, surfaced on the admin page.
- **`/files/`** — per-deployment artifact area; route MCP-App notebooks/images here instead of the
  global `AgentTools/Notebooks` / `AgentTools/Images` locations.
- **Usage monitoring** — request/usage counts per key on the admin page (likely requires logging).
- **Enable/disable toggle** — temporarily disable `/mcp` without deleting it.
- **Caching / persistent kernels** — reduce per-request cold-start latency for heavyweight tools.
- **Local consumption** — a URL-based `InstallMCPServer` so local clients (Claude Desktop, etc.) can
  consume a deployed endpoint directly (new `url`+`headers` converter shapes in `SupportedClients.wl`
  + `InstallMCPServer.wl`).
- **Full Streamable HTTP transport** — sessions, SSE streaming, logging notifications, if needed.
- **Track additional capability flags** — roots and elicitation are out of scope in v1 because acting
  on them needs a server→client channel; add them to the self-describing session ID as new
  `$trackedFeatureList` flags (bumping `$idVersion` if bit positions shift) alongside the fuller
  transport above.
- **Tool-safety options** — optional allowlisting / sandboxing of code-execution tools for public
  deployments.

---

## Verification

### `CloudDeployMCPServer` / `RunCloudMCPServer`

1. Deploy a built-in server (e.g. `"WolframLanguage"`) with a single `PermissionsKey`; confirm the
   returned object is the `/mcp` `CloudObject`.
2. `POST` an `initialize` request; confirm a `200` `application/json` response whose result
   `protocolVersion` echoes a supported requested version, and falls back to `2025-11-25` for an
   unknown one.
3. `POST` `tools/list`; confirm the tool list matches the server object's tools.
4. `POST` `tools/call` for a simple tool (the notes' `PrimeFinder`, or `WolframAlpha`); confirm the
   result content.
5. `POST` a notification (e.g. `notifications/initialized`); confirm **`202`** with no body.
6. `GET` and `DELETE` the endpoint; confirm **`405`**.
7. Send an unsupported `MCP-Protocol-Version`; confirm **`400`**. Send a disallowed `Origin`; confirm
   **`403`**. Send a malformed body; confirm **`400`**. Send an unacceptable `Accept`; confirm
   **`406`**.
8. Authenticate via `Authorization: Bearer <key>` (OpenAI form) and via `?_key=<key>` (Anthropic
   form); confirm both succeed and that a request with no/invalid key is rejected by the cloud.
9. Deploy a **custom self-contained** server with an anonymous pure-function tool; confirm it works in
   the cloud with no relevant paclet pre-installed (custom-function capture + dev bundling).
10. Reproduce the OpenAI and Anthropic end-to-end remote-MCP examples from
    `Notes/cloud-deployed-mcp-servers.md:258–332` against the deployed endpoint.

### `CloudDeploy` (full directory)

11. `CloudDeploy[server]` (anonymous) and `CloudDeploy[server, "Name"]`; confirm the directory
    `CloudObject` is returned and that `/mcp`, `/index.html`, `/api/info`, `/admin/index.html`,
    `/api/admin` all exist.
12. Confirm `/index.html`, `/api/info`, and `/mcp` carry the resolved `Permissions` (default
    `$Permissions`), while `/admin/index.html` and `/api/admin` are `"Private"`.
13. Load `/index.html`; confirm it fetches `/api/info` and renders server name, tools, URL, and
    click-to-copy snippets with a `<YOUR_KEY>` placeholder.
14. Through `/api/admin`: create a key (confirm it appears in `Information[mcp, "Permissions"]` and is
    usable against `/mcp`), list keys, revoke it (confirm removed and no longer works).
15. Confirm `/api/admin` is unreachable without owner credentials.

### Refactor integrity

16. Confirm the local stdio `StartMCPServer` still initializes and serves `tools/list` / `tools/call`
    after the `Server/` refactor (no regression), including protocol-version negotiation for old and
    new requested versions.
17. Run `CodeInspector` on all new/changed `Kernel/Server/*.wl` files.
18. Run `Tests/CloudDeployment.wlt` and the existing server test suites.

### MCP-Apps (client capability propagation)

19. `POST` `initialize` with `capabilities.extensions."io.modelcontextprotocol/ui"` present; confirm
    the response advertises the same extension **and** carries an `Mcp-Session-Id` header whose feature
    bitfield decodes to `{"MCPApps"}`. Repeat without the extension; confirm the session ID decodes to
    `{ }`.
20. Using the session ID from the UI-enabled `initialize`, `POST` `tools/list`; confirm UI-bearing
    tools carry `_meta.ui`. Repeat with the no-feature session ID and with no `Mcp-Session-Id` header
    at all; confirm `_meta.ui` is absent in both.
21. With the UI-enabled session ID, `POST` `resources/list` and `resources/read` for a UI resource;
    confirm the registry lists it and the app HTML is returned. Confirm a malformed or wrong-version
    session ID decodes to no features (UI safely off), and that the OpenAI and Anthropic clients echo
    `Mcp-Session-Id` on follow-up requests (else UI stays off with no error).
