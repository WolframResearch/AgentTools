# Cloud Deployment of MCP Servers

This document describes how to deploy an `MCPServerObject` as a remote MCP server running in the
Wolfram Cloud, reachable over HTTP by any MCP-capable client — including the OpenAI Responses API and
the Anthropic Messages API remote-MCP features — without a local kernel.

## Overview

Deploying a server to the cloud produces a set of `CloudObject`s: a live MCP endpoint, a public
landing page with client-configuration help, and an owner-only admin page for managing API keys. The
endpoint speaks a stateless subset of the MCP **Streamable HTTP** transport (protocol revision
`2025-11-25`), and authentication is delegated to Wolfram Cloud's native `PermissionsKey` mechanism.

Two entry points are provided:

| Entry point | Deploys | Returns |
|-------------|---------|---------|
| `CloudDeploy[MCPServerObject[…]]` | The **full directory bundle** (`/mcp`, landing page, `/api/info`, admin page + API). | The **directory** `CloudObject`. |
| `CloudDeployMCPServer[…]` | **Only** the `/mcp` endpoint, with caller-controlled path and permissions. | The **`/mcp`** `CloudObject`. |

`CloudDeploy` is the built-in `System` function, extended here by an UpValue on `MCPServerObject`
(mirroring the existing `DeleteObject` and `LLMConfiguration` upvalues); it reuses
`CloudDeployMCPServer`'s endpoint primitive for its `/mcp` object. `CloudDeployMCPServer` is exported by
the AgentTools paclet, so once the paclet is loaded you can call it unqualified. A third exported
symbol, `RunCloudMCPServer`, is the HTTP request handler that runs *inside* the deployed endpoint — you
do not call it directly, but it is exported so the deployed payload can reference it.

> **Security note.** A deployed server exposes exactly the tools in its server object, including
> code-execution tools such as `WolframLanguageEvaluator`. There is no built-in tool filtering or
> sandboxing in v1 — **access control is the owner's responsibility, mediated entirely by API keys.**
> The recommended pattern is to deploy privately (the default) and mint keys on the admin page, rather
> than deploying `Permissions -> "Public"`.

## Quick Start

```wl
(* Deploy a built-in server. With the default (Private) permissions, the objects are reachable only
   by the owner until you mint an API key on the admin page. *)
server = MCPServerObject["WolframLanguage"];
dir    = CloudDeploy[server]
(* CloudObject["https://www.wolframcloud.com/obj/<user>/<server-assigned-uuid>"] *)
```

The returned `dir` is the deployment directory. From it:

- The **landing page** is at `<dir>/index.html` — open it in a browser for click-to-copy client
  configuration snippets.
- The **MCP endpoint** is at `<dir>/mcp` — this is the URL clients connect to.
- The **admin page** is at `<dir>/admin/index.html` — visit it (signed in as the owner) to mint an API
  key, then paste the key into a client snippet in place of `<YOUR_KEY>`.

Because there is no local registry, the returned `CloudObject` (and, for anonymous deploys, its URL)
is the only handle to the deployment — retain it.

## `CloudDeploy` — Full Directory Bundle

### Signatures

```wl
CloudDeploy[obj]
CloudDeploy[obj, target]
CloudDeploy[obj, target, opts]
```

### Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `obj` | `MCPServerObject` | The server to deploy. |
| `target` (optional) | `String` or `CloudObject` | Deployment directory prefix. Omitted ⇒ an **anonymous** server-assigned directory. |

### Options

Options follow `CloudDeploy`'s grammar and are forwarded to the underlying `CloudDeploy`/`CloudObject`
calls where meaningful.

| Option | Default | Description |
|--------|---------|-------------|
| `Permissions` | `$Permissions` (typically `"Private"`) | Permissions for `/mcp`, `/index.html`, `/assets/*`, and `/api/info`. The admin objects are **always** `"Private"` regardless. |

### Behavior

1. Validate the server object and require a cloud session (`$CloudConnected`, else a
   `NotCloudConnected` failure — see [Requirements](#requirements-and-limitations)).
2. Resolve the directory `CloudObject` — an explicit `target`, or an anonymous directory when omitted.
3. Deploy `/mcp` (carrying the server's definitions), `/index.html`, `/assets/*`, and `/api/info` at
   the resolved `Permissions`.
4. Deploy `/admin/index.html` and `/api/admin` as `"Private"`.
5. Return the directory `CloudObject`.

If the `target` is neither a valid path/object nor an option, an `InvalidCloudTarget` failure is
issued.

### Example

```wl
(* Deploy to a named directory, readable by anyone holding a specific key. *)
key = CreateUUID[];
dir = CloudDeploy[
    MCPServerObject["WolframLanguage"],
    "MyServer",
    Permissions -> {PermissionsKey[key] -> "Execute"}
]
```

## `CloudDeployMCPServer` — Endpoint Only

Deploys *only* the MCP endpoint, with a caller-controlled path and permissions. This is the primitive
the `CloudDeploy` UpValue uses for its `/mcp` object, and is useful directly when the landing and admin
pages are not wanted.

### Signatures

```wl
CloudDeployMCPServer[obj]
CloudDeployMCPServer[obj, target]
CloudDeployMCPServer[obj, target, opts]
```

### Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `obj` | `MCPServerObject`, `String`, or association | The server to deploy. Strings/associations resolve through `MCPServerObject` first. |
| `target` (optional) | `String` or `CloudObject` | Endpoint location. Omitted ⇒ anonymous. |

Options are forwarded to `CloudDeploy`; `Permissions` defaults to `$Permissions`. On error the function
returns a `Failure[…]`.

### Example

```wl
key = CreateUUID[];
mcp = CloudDeployMCPServer[
    MCPServerObject["WolframLanguage"],
    "MCPTest/mcp",
    Permissions -> {PermissionsKey[key] -> "Execute"}
]
(* CloudObject["https://www.wolframcloud.com/obj/<user>/MCPTest/mcp"] *)
```

## Deployed Directory Layout & Permissions

`CloudDeploy[obj]` populates a deployment directory by joining sub-objects onto the directory object:

| Path | Purpose | Permissions |
|------|---------|-------------|
| `/mcp` | Live MCP endpoint. | Resolved `Permissions`; the admin page adds/removes `PermissionsKey`s. |
| `/index.html` | Landing page (client-configuration help). | Resolved `Permissions`. |
| `/api/info` | Public server metadata consumed by the landing page. | Resolved `Permissions`. |
| `/assets/*` | CSS/JS for the landing page. | Resolved `Permissions`. |
| `/admin/index.html` | Owner-only admin page (API key create/revoke). | **Always `"Private"`.** |
| `/api/admin` | Owner-only API backing the admin page. | **Always `"Private"`.** |

Per-deployment `/files/` (artifact area) and `/logs/` (log storage) are deferred to future work.

### Anonymous deployments

When no explicit target is given, the directory is an **anonymous** cloud object at a server-assigned
path (created with `CreateDirectory`). The directory object itself is owner-only, but its child objects
are deployed at their own explicit permissions. Consequently:

- Share the **landing page** as `<dir>/index.html` (not the bare `<dir>/`, which is owner-only).
- The landing page and endpoint URLs are the only handle to an anonymous deployment — retain the
  returned `CloudObject`.

## Authentication

Authentication is delegated entirely to Wolfram Cloud's native `PermissionsKey` mechanism; the endpoint
handler performs **no** key validation of its own — an unauthorized caller never reaches it.

For the `/mcp` endpoint, clients supply a `PermissionsKey`, accepted by Wolfram Cloud in either form:

| Form | Header / parameter | Used by |
|------|--------------------|---------|
| Bearer token | `Authorization: Bearer <key>` | OpenAI's MCP client |
| URL parameter | `<dir>/mcp?_key=<key>` | Anthropic's MCP client |

A missing or invalid key ⇒ Wolfram Cloud returns a `401`/permission error *before* the handler runs.

The **admin** page and API are `"Private"` and reached through the owner's authenticated Wolfram Cloud
session (the page's same-origin `fetch` carries the owner's credentials, and `/api/admin` executes
server-side as the owner so it may `SetPermissions` on the sibling `/mcp`). No secret is embedded in
any page.

## Client Configuration

The landing page (`/index.html`) is a static HTML/JS shell that fetches live server metadata from the
public `/api/info` at view time and renders it client-side — the server name and version, the tool
list, the endpoint URL, and **click-to-copy** configuration snippets. `/api/info` returns JSON
describing the server (name, version, tool names/titles/descriptions, and the `/mcp` URL); it exposes
no keys, permissions, or usage data.

Every snippet shows the API key as a `<YOUR_KEY>` placeholder — keys are minted on the admin page, not
the landing page. The snippets match the forms proven against each provider:

```json
// Generic remote-MCP configuration
{ "type": "http", "url": "…/mcp", "headers": { "Authorization": "Bearer <YOUR_KEY>" } }
```

```json
// OpenAI Responses API (bearer header)
{ "type": "mcp", "server_label": "…", "server_url": "…/mcp",
  "require_approval": "never", "headers": { "Authorization": "Bearer <YOUR_KEY>" } }
```

```json
// Anthropic Messages API (?_key= URL parameter)
{ "type": "url", "url": "…/mcp?_key=<YOUR_KEY>", "name": "…" }
```

## Admin Key Management

The admin page (`/admin/index.html`, owner-only) lists, mints, and revokes API keys for the sibling
`/mcp` object via its `/api/admin` backend. The API manipulates the `/mcp` object's permissions with the
standard cloud primitives:

| Action | Effect | Returns |
|--------|--------|---------|
| `listKeys` | `Information[mcp, "Permissions"]`, joined with any stored labels. | Current `PermissionsKey` entries. |
| `createKey` | `CreateUUID[]` → `SetPermissions[mcp, PermissionsKey[key] -> "Execute"]`. | The new key (shown **once**) + updated list. |
| `revokeKey` | `DeleteObject[PermissionsKey[key]]` (for a key currently granting access to this `/mcp`). | Updated list. |

The created key is shown to the owner only once, on creation (the cloud does not let you read a key back
later). Optional human-readable **labels** are persisted in a `"Private"` `/admin/keys.wxf` object; this
is a convenience only — the authoritative list of valid keys is always the object's live permissions.

You can also manage keys directly from a kernel:

```wl
mcp = CloudObject["…/mcp"];

key = CreateUUID[];                                (* create *)
SetPermissions[mcp, PermissionsKey[key] -> "Execute"];

Information[mcp, "Permissions"];                   (* list   *)

DeleteObject[PermissionsKey[key]];                 (* revoke *)
```

### Tearing down a deployment

There is no local registry to clean up; the cloud objects and their permissions are the source of
truth. To remove a deployment, `DeleteObject` the directory `CloudObject` and revoke any outstanding
`PermissionsKey`s.

## Stateless Evaluation Model

The endpoint is **stateless**: each HTTP request (`initialize`, `tools/list`, `tools/call`, …) is a
separate, self-contained kernel evaluation, matching the Wolfram Cloud `APIFunction`/`Delayed`
execution model. There is no server-side session store, no persistent kernel between calls, and no
warmup. The server rebuilds its tool and prompt tables from the server object on every request.

The consequences, accepted for v1:

- **Per-request cold-start cost.** Paclet loading and any tool initialization recur on every call. In
  particular, the semantic-search `*Context` tools (`WolframContext`, `WolframLanguageContext`,
  `WolframAlphaContext`) install and load a vector database on each request, so they carry a
  substantial latency penalty in the cloud and require cloud connectivity; their reranking/filtering
  further depends on an [LLMKit subscription](https://www.wolfram.com/notebook-assistant-llm-kit/) on
  the **deploying** account (required outright for `WolframAlphaContext`; see the
  [LLMKit table](servers.md#llmkit-requirements)). Servers built around code execution and
  Wolfram|Alpha (`WolframLanguageEvaluator`, `WolframAlpha`) are the most practical to deploy.
- **No cross-request state or sessions.** Any client capability that must survive across requests
  travels in a self-describing session ID (see [MCP Apps Support](#mcp-apps-support)), not in server
  memory.

Caching / persistent kernels are future work.

## MCP Apps Support

[MCP Apps](mcp-apps.md) interactive UI is **supported** in the cloud despite statelessness. Because
`initialize` and later requests are separate evaluations, the client's `io.modelcontextprotocol/ui`
capability cannot live in kernel state between them. Instead it travels in the `Mcp-Session-Id` header,
which the endpoint makes *self-describing*:

- At `initialize`, the server encodes the negotiated capabilities into a fresh session ID and returns
  it in the `Mcp-Session-Id` response header.
- On every later request, the client echoes that ID; the server decodes it and re-establishes the
  capability flags (in v1, `$clientSupportsUI`) for that request.

So a UI-capable client still receives `_meta.ui` on `tools/list`, an enumerated `resources/list`, and
app HTML from `resources/read` — all gated on the decoded capability. The design **fails safe**: if a
client does not echo the session ID (or replays one minted by an older deployment), every request
decodes to no features and MCP Apps simply stays off, with no correctness impact.

UI artifacts (Wolfram|Alpha notebooks, evaluator images) deploy to the existing global cloud locations
(`AgentTools/Notebooks`, `AgentTools/Images`); a per-deployment `/files/` area is deferred.

## Endpoint Behavior (Stateless Streamable HTTP)

The `/mcp` endpoint implements a stateless subset of the MCP Streamable HTTP transport
(`2025-11-25`). It handles one JSON-RPC message per `POST` and always returns an `HTTPResponse`:

| Situation | Response |
|-----------|----------|
| `POST` request (has `id` + `method`) | `200` with the JSON-RPC result (content type negotiated from `Accept`). |
| `POST` notification / response / `id -> Null` | `202` with an empty body. |
| Unknown method | `200` with an in-band JSON-RPC `-32601` error. |
| Internal / tool failure | `200` with an in-band JSON-RPC `-32603` error. |
| `GET` / `DELETE` (no session to stream or tear down) | `405`. |
| Disallowed `Origin` (DNS-rebinding protection; absent `Origin` is allowed) | `403`. |
| Unsupported `MCP-Protocol-Version` on a non-`initialize` request | `400`. |
| Unacceptable `Accept` (neither `application/json` nor `text/event-stream`) | `406`. |
| Malformed / non-object JSON body | `400`. |
| Unexpected pre-dispatch failure | `500`. |

### Protocol version negotiation

Both the local (stdio) and cloud (HTTP) servers negotiate the protocol version: `initialize` echoes the
client's requested `protocolVersion` when it is supported, otherwise returning the preferred
`2025-11-25`. The supported set is `{"2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"}`.

## Requirements and Limitations

- **Cloud connection.** `CloudDeploy[MCPServerObject[…]]` requires an authenticated cloud session; a
  disconnected session issues a `NotCloudConnected` failure (use `CloudConnect` to sign in). The
  deployed endpoint likewise runs in the Wolfram Cloud.
- **LLMKit** on the deploying account for full-quality semantic-search `*Context` results — required
  for `WolframAlphaContext`, suggested for the others (see
  [Stateless Evaluation Model](#stateless-evaluation-model)).
- **No tool filtering / sandboxing** in v1 — see the security note in the [Overview](#overview).
- **Not installable into local clients** yet. Making a deployed remote endpoint consumable by local MCP
  clients (a URL-based `InstallMCPServer`) is future work.

## Related Files

- `Kernel/MCPServerObject.wl` — the `CloudDeploy` UpValue on `MCPServerObject` (with the `DeleteObject`
  and `LLMConfiguration` upvalues), which delegates to `cloudDeployDirectory` in `Cloud.wl`
- `Kernel/Server/Cloud.wl` — `CloudDeployMCPServer`, `RunCloudMCPServer`, the directory-bundle deploy
  implementation (`cloudDeployDirectory`) behind the `CloudDeploy` UpValue, the session-ID capability
  codec, the server-embedding deploy helpers, and the `/api/info` and `/api/admin` handlers
- `Kernel/Server/Shared.wl` — transport-agnostic core shared with the local server (dispatch, tool/prompt
  resolution, result formatting, `initializeServerState`, protocol-version negotiation)
- `Assets/Cloud/` — landing page (`index.html` + `assets/`) and admin page (`admin.html`)
- `Kernel/Messages.wl` — `CloudDeployFailed`, `NotCloudConnected`, `InvalidCloudTarget`
- `Tests/CloudDeployment.wlt` — tests
- `Specs/CloudDeployment.md` — design specification

## Related Documentation

- [servers.md](servers.md) - Predefined servers and creating custom servers to deploy
- [mcp-apps.md](mcp-apps.md) - MCP Apps system for interactive UI resources
- [tools.md](tools.md) - Available MCP tools and creating custom tools
- [deploy-agent-tools.md](deploy-agent-tools.md) - Managed deployment of tools to *local* agent clients
