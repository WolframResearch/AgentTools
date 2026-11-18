# MCP Protocol Versions

This document describes which MCP protocol revisions the AgentTools servers support and how one server serves clients of two protocol eras. It applies to both transports: the local stdio server (`Kernel/Server/Local.wl`) and the cloud HTTP server (`Kernel/Server/Cloud.wl`).

## Overview

The [2026-07-28 revision](https://modelcontextprotocol.io/specification/2026-07-28) (see its [changelog](https://modelcontextprotocol.io/specification/2026-07-28/changelog), [versioning](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning), and [Streamable HTTP](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http) pages) made MCP stateless: there is no `initialize` handshake, and every request carries its protocol version and the client's capabilities in `_meta`. Earlier revisions negotiate a version once with `initialize`.

AgentTools servers are **dual-era**. Revisions are grouped in `Kernel/Server/Shared.wl`:

| Symbol | Value | Era |
|--------|-------|-----|
| `$modernProtocolVersions` | `{"2026-07-28"}` | Modern: stateless, per-request `_meta` |
| `$legacyProtocolVersions` | `{"2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"}` | Legacy: `initialize` handshake |
| `$supportedProtocolVersions` | Both lists joined, newest first | Reported by `server/discover` and in `-32022` errors |

Legacy behavior is unchanged: a legacy message goes to `handleMethod` exactly as before, and its response is the same as before.

## Deciding the Era of a Message

Both transports pass every incoming message to `handleRequest`, which sends modern requests to `handleModernRequest` and everything else to `handleMethod`. `modernRequestQ` decides the era:

- `initialize` is always legacy. `negotiateProtocolVersion` only negotiates legacy versions, so a requested `"2026-07-28"` or an unknown version gets `"2025-11-25"`.
- Notifications (messages without a non-null `id`) are never modern requests. They carry no per-request `_meta` and are never validated.
- `server/discover` (a modern-only method) is always modern.
- Any other request is modern when `_meta["io.modelcontextprotocol/protocolVersion"]` is present and is **not** a legacy version. Unknown versions count as modern, so they get `-32022`. A legacy version in `_meta` is served as legacy.

The cloud transport also treats a request as modern when its `MCP-Protocol-Version` header names a modern version (`modernHTTPRequestQ`). A request that sends a modern header without the modern `_meta` fields is therefore rejected, not served as legacy.

## Modern Requests

`handleModernRequest` validates the request (`modernRequestError`), evaluates it inside `withModernClient`, and completes the result with `completeModernResponse`.

### Errors

| Condition | JSON-RPC error | stdio | HTTP |
|-----------|----------------|-------|------|
| `_meta` protocol version is not a supported modern version | `-32022` (UnsupportedProtocolVersion), `data: {supported, requested}` | in-band | `400` |
| `_meta` protocol version missing or not a string, or `clientCapabilities` missing or not an object | `-32602` (Invalid params) | in-band | `400` |
| `MCP-Protocol-Version`, `Mcp-Method`, or `Mcp-Name` header missing or not matching the body | `-32020` (HeaderMismatch) | n/a | `400` |
| Method not implemented (including `subscriptions/listen`) | `-32601` | in-band | `404` |
| Legacy request with an unsupported `MCP-Protocol-Version` header | `-32022` | n/a | `400` |

Over HTTP, `Mcp-Name` is required for `tools/call` and `prompts/get` (it must equal `params.name`) and for `resources/read` (it must equal `params.uri`). A Base64 value in the `=?base64?…?=` form is decoded before the comparison (`decodeHeaderValue`). `Mcp-Param-*` headers are not checked, since no tool mirrors its parameters into headers (`x-mcp-header`).

### Per-Request Client State

`withModernClient` binds the client state for one request only, so nothing carries over from other requests or from a legacy `initialize` in the same process:

- `$clientSupportsUI` comes from the request's `clientCapabilities` (`extensions["io.modelcontextprotocol/ui"]`, via `clientSupportsUIQ`) and also requires `mcpAppsEnabledQ[]`. See [MCP Apps](mcp-apps.md).
- `$clientSupportsRoots` is `False`. The server never sends requests to a modern client (see below).
- `$clientName` is `None`, so stderr logging (`stderrEnabledQ`) stays off. The spec says the self-reported `clientInfo` SHOULD NOT change server behavior.

### Results

`completeModernResponse` adds these fields to every modern result. Errors are returned unchanged.

- `resultType: "complete"`
- `_meta["io.modelcontextprotocol/serverInfo"]`: `{name, version}`, merged with any `_meta` the result already has
- `ttlMs: 300000` and `cacheScope: "private"` on cacheable methods (`$cacheableMethods`: `server/discover`, `tools/list`, `prompts/list`, `resources/list`, `resources/templates/list`, `resources/read`)

### `server/discover`

`discoverResult` returns `supportedVersions` (`$supportedProtocolVersions`), `capabilities`, and `instructions`. The capabilities describe what the server supports, not what one client declared:

- `prompts: {}` and `tools: {}`, without `listChanged`, because the server never sends list-changed notifications.
- The MCP Apps extension (`io.modelcontextprotocol/ui`) whenever `mcpAppsEnabledQ[]` is true, whatever the request declared.

A legacy `initialize` result still advertises `tools.listChanged: true`, and it includes the UI extension only when the client declared that extension.

### Not Implemented for Modern Clients

These features are left out on purpose:

| Feature | Reason |
|---------|--------|
| `subscriptions/listen` | The server has no change notifications to send. The tool and prompt lists only change on restart or redeploy, and `ttlMs` covers that. Calls get `-32601` (`404` over HTTP). |
| Multi round-trip requests (`InputRequiredResult`) | No tool needs input from the client, so every result is `"complete"`. |
| Roots | Deprecated in 2026-07-28, and asking for roots would need a server-to-client request. The working directory stays the process's own. See [mcp-roots.md](mcp-roots.md). |
| Logging (`io.modelcontextprotocol/logLevel`) | Not supported in either era. |

`ping` was removed in 2026-07-28, but the server still answers it, with a completed result.

## Cloud Transport Notes

- Modern requests ignore any `Mcp-Session-Id` they send. Session IDs are only issued in response to legacy `initialize`, where the self-describing session ID carries MCP Apps support for later legacy requests ([cloud-deployment.md](cloud-deployment.md#mcp-apps-support)).
- Notifications skip the `_meta` and header checks and get `202`. As for legacy requests, an unsupported `MCP-Protocol-Version` header still gets `400`.
- The cloud cannot see when a client disconnects, so closing the response stream does not stop work on a request (a SHOULD in the spec).
- Deployments that use the light payload run the server code of the AgentTools paclet installed in the cloud account. They support 2026-07-28 only after that paclet is updated, and until then clients fall back to legacy ([cloud-deployment.md](cloud-deployment.md#server-embedding--the-cloud-paclet)).

## Where the Code Lives

| File | Contents |
|------|----------|
| `Kernel/Server/Shared.wl` | Version lists, `handleRequest`, `modernRequestQ`, `requestMetaValue`, `handleModernRequest`, `modernRequestError`, `withModernClient`, `completeModernResponse`, `discoverResult`, `negotiateProtocolVersion` |
| `Kernel/Server/Cloud.wl` | `modernHTTPRequestQ`, `modernHTTPRequestError`, `headerMismatchError`, `decodeHeaderValue`, `responseStatus` (the modern `404`), and the protocol checks in `runCloudMCPServer0` |
| `Kernel/Server/Local.wl` | `processRequest` calls `handleRequest` |
| `Kernel/Server/UsageData.wl` | `modernClientInformation`: for a modern client, the usage-data client information comes from its first valid request ([usage-data.md](usage-data.md)) |
| `Kernel/UIResources.wl` | `clientSupportsUIQ`, which takes a client-capabilities association from either era |

## Tests

- `Tests/CloudDeployment.wlt`: the "Protocol Version Negotiation" section, the "Transport: MCP-Protocol-Version header" tests, and the "Modern protocol (2026-07-28)" section (header validation, Base64 `Mcp-Name`, per-request UI capabilities, the ignored session ID, and error statuses)
- `Tests/StartMCPServer.wlt`: the "Modern Protocol (2026-07-28)" section (stdio end to end: discovery, tools, invalid requests, and no `roots/list`)
- `Tests/UsageData.wlt`: `RecordUsageData-ModernClientInformation`
- `Tests/MCPApps.wlt`: the `clientSupportsUIQ` tests

### Checking With the MCP Inspector CLI

The [MCP Inspector](https://github.com/modelcontextprotocol/inspector) CLI can talk to a server in either era with `--protocol-era modern`, `legacy`, or `auto` (which negotiates 2026-07-28 with this server):

```sh
# stdio, from the repository root
npx @modelcontextprotocol/inspector --cli --protocol-era modern \
    -e MCP_SERVER_NAME=WolframLanguage --method tools/list \
    -- wolfram -script Scripts/StartMCPServer.wls

# cloud
npx @modelcontextprotocol/inspector --cli --protocol-era modern \
    --transport http --method tools/list "<dir>/mcp?_key=<key>"
```

For stdio, start the server with the `wolfram` executable that `InstallMCPServer` configures, found in `$InstallationDirectory` (`wolfram.exe` on Windows, `MacOS/wolfram` on macOS, `Executables/wolfram` on Linux). Other launchers hang: on Windows, `WolframKernel` opens a separate kernel window and never answers on stdio, and `wolframscript -f` produces no stdout when its output is piped. The server usually answers its first request within about 10 seconds. In the `auto` and `modern` eras, the Inspector waits 60 seconds for its `server/discover` probe, and `--connect-timeout` does not change that.
