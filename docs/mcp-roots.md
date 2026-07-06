# MCP Roots in AgentTools

This document explains how AgentTools handles the [MCP roots](https://modelcontextprotocol.io/specification/2025-11-25/client/roots.md) protocol feature and how it affects tools that touch the filesystem.

## Overview

When an MCP client (e.g. Claude Code, OpenCode) advertises a project directory via the `roots` capability, AgentTools queries it via `roots/list`, picks a single working directory, and propagates that directory to:

- The main server kernel via `SetDirectory`
- The local evaluator kernel (when the `WolframLanguageEvaluator` `Method` option is `"Local"`)
- Tools that invoke external processes via `RunProcess` (e.g. `TestReport`)

This means relative paths the LLM passes to a tool resolve against the project the user is actually working in, rather than against whatever directory the server happened to start in.

When a client does not advertise the `roots` capability, no `roots/list` request is ever sent and tools fall back to running with the kernel's original working directory.

## How It Works

### Capability Negotiation

The roots handshake is gated on the client's advertised capabilities during `initialize`:

1. The client lists `roots` (optionally with `listChanged: true`) in its `capabilities`.
2. The server records this in `$clientSupportsRoots` while building the `initialize` response.
3. After receiving `notifications/initialized`, the server issues a `roots/list` request to the client. The request uses a **UUID** as its JSON-RPC `id` to avoid colliding with the integer `id`s the client typically uses for its own requests.
4. When the client replies, the server picks the first valid root and applies it.
5. If the client later sends `notifications/roots/list_changed`, the server re-issues `roots/list` and replaces the active root.

If the client never advertises `roots`, none of this happens — `$mcpRoot` stays `None` and tools behave exactly as they did before.

### Pending-Request Registry

Server-to-client requests are tracked in a registry, `$mcpClientRequests`, so an in-flight request is not confused with the client's normal `tools/call` / `prompts/get` traffic that may already be buffered:

```wl
$mcpClientRequests[ uuid ] = <|
    "id"      -> uuid,
    "request" -> <| (* the JSON-RPC request *) |>,
    "handler" -> handlerFunction
|>;
```

When a JSON-RPC message arrives whose `id` is a UUID present in this registry, the message loop dispatches it to the registered handler instead of treating it as a new client request. This infrastructure is general; the roots handshake is the first consumer, but it is also intended to be reused for future server-initiated calls (e.g., sampling, elicitation).

### Root Selection

`roots/list` may return multiple roots, but AgentTools is single-rooted: it picks the **first valid** entry (a `file://` URI that decodes to an existing directory) and ignores the rest. Entries that fail any of these checks are skipped:

- Missing `"uri"` field
- Non-`file://` scheme (e.g., `https://`, `git+ssh://`)
- Non-string `"uri"` value
- Path that does not exist or is not a directory

If no entry passes, `$mcpRoot` stays `None` and the failure is logged.

### URI Normalization

A well-formed file URI looks like `file:///C:/Users/me/project` (or `file:///home/me/project` on POSIX). Some clients — notably Claude Code on Windows — emit malformed variants such as `file://H:\Documents\AgentTools` (backslashes, only two slashes before the drive letter). AgentTools normalizes these forms before decoding:

- `\` → `/`
- `file://<letter>:/...` → `file:///<letter>:/...`

POSIX URIs (`file:///home/...`) and UNC URIs (`file://server/share/...`) are passed through unchanged.

After normalization, the URI is decoded to a native path with `ExpandFileName[LocalObject[uri]]`.

### Applying the Root

Once a valid root is selected:

1. `$mcpRoot` is set to the native path.
2. `SetDirectory[$mcpRoot]` runs in the server kernel.
3. If the `WolframLanguageEvaluator` `Method` option is `"Local"`, the same `SetDirectory[$mcpRoot]` is dispatched to the local evaluator kernel via `useEvaluatorKernel`.
4. Tools that spawn external processes via `RunProcess` pass `ProcessDirectory -> $mcpRoot` so the child process inherits the project root. Currently `TestReport` honors this; other tools can opt in by following the same pattern.

`$mcpRoot` is replaced (not stacked) on each `roots/list_changed` re-fetch.

## Error and Edge-Case Behavior

| Condition | Behavior |
|---|---|
| Client does not advertise `roots` capability | No `roots/list` ever sent; `$mcpRoot` stays `None`. |
| Client never replies to `roots/list` | No timeout; server continues serving other requests. |
| Response contains `"error"` | Error logged; no root applied. |
| Response result has empty `roots` list | Logged; no root applied. |
| All roots fail `DirectoryQ` | Logged; no root applied. |
| URI is not `file://` | The entry is skipped during scan. |
| Malformed Windows URI | Normalized before decoding; succeeds if the underlying path is valid. |

In all of these cases the server stays alive and continues serving tool calls — `$mcpRoot` simply remains `None`, and tools fall through to today's behavior.

### Race: `tools/call` Before `roots/list` Resolves

Because the message loop processes messages strictly in arrival order, a client that fires `tools/call` before responding to our `roots/list` will have that tool execute with `$mcpRoot === None`. This is **accepted, not mitigated**: in practice, MCP clients sequence `notifications/initialized` immediately after `initialize` and do not fire `tools/call` until the user takes an action, by which time the round-trip has long completed. Tools should therefore tolerate `$mcpRoot === None` and behave as they do today.

## Tool Authoring Guidance

If you are writing or modifying a tool that resolves filesystem paths, consider how it should behave when `$mcpRoot` is set.

### Tools That Use Relative Paths Directly

Tools that evaluate Wolfram Language code (e.g., `WolframLanguageEvaluator`) automatically benefit from `SetDirectory[$mcpRoot]` — relative paths in the evaluated code resolve against the project root with no additional work.

### Tools That Use `RunProcess`

If your tool calls `RunProcess` to invoke an external program, pass `ProcessDirectory -> $mcpRoot` (with a `None` fallback) so the child process starts in the project root:

```wl
RunProcess[
    processArgs,
    ProcessDirectory -> If[ StringQ @ $mcpRoot, $mcpRoot, Inherited ]
]
```

`$mcpRoot` is exported from `Wolfram`AgentTools`Common`` and can be referenced directly in any subcontext.

Calls that already use a deliberate, explicit `ProcessDirectory` for another purpose (e.g., the `git rev-parse` lookup in `Common.wl`) should keep that explicit value — the roots feature is not meant to override targeted overrides.

## Architecture

### Key Files

| File | Description |
|------|-------------|
| `Kernel/MCPClientRequests.wl` | Server-to-client request registry, response correlation, and notification dispatch |
| `Kernel/MCPRoots.wl` | Roots-specific handlers: `onClientInitialized`, `onRootsListChanged`, `handleRootsListResponse`, `pickFirstValidRoot`, `rootURIToPath`, `normalizeFileURI`, `applyMCPRoot` |
| `Kernel/Server/Shared.wl` | Method dispatch (`handleMethod`): `initialize` capability detection and `notifications/*` dispatch to `handleNotification` |
| `Kernel/Server/Local.wl` | stdio read loop: routes UUID-keyed client responses to `handleClientResponse` |
| `Kernel/CommonSymbols.wl` | Shared declarations (`$clientSupportsRoots`, `$mcpRoot`, `$mcpClientRequests`, `sendClientRequest`, `handleClientResponse`, `handleNotification`, `useEvaluatorKernel`, etc.) |
| `Kernel/Tools/TestReport.wl` | First tool to honor `$mcpRoot` via `ProcessDirectory` on `RunProcess` |
| `Tests/MCPClientRequests.wlt` | Unit tests for the request registry and dispatch |
| `Tests/MCPRoots.wlt` | Unit tests for URI normalization, root selection, and response handling |
| `Tests/StartMCPServer.wlt` | End-to-end roots handshake tests (with and without the `roots` capability, plus `list_changed`) |
| `Tests/MCPServerTestUtilities.wl` | Adds `ReadMCPMessage` and `SendMCPResponse` helpers for tests that need to receive server-issued requests and reply to them |
| `Specs/MCPRoots.md` | Design specification |

### Key Symbols

| Symbol | Context | Description |
|--------|---------|-------------|
| `$clientSupportsRoots` | `Common` | `True` when the current client advertised `roots` in its `initialize` capabilities |
| `$mcpRoot` | `Common` | Native path of the active project root, or `None` |
| `$mcpClientRequests` | `Common` | Association of pending server-to-client requests, keyed by UUID |
| `sendClientRequest` | `Common` | Sends a JSON-RPC request to the client and registers a response handler |
| `handleClientResponse` | `Common` | Dispatches an inbound message back to the registered handler when its `id` matches a pending request |
| `handleNotification` | `Common` | Dispatches `notifications/*` messages (e.g. `notifications/initialized`, `notifications/roots/list_changed`) |
| `onClientInitialized` | `Common` | Hook fired on `notifications/initialized`; issues the initial `roots/list` request when the client supports it |
| `onRootsListChanged` | `Common` | Hook fired on `notifications/roots/list_changed`; re-issues `roots/list` |
| `useEvaluatorKernel` | `Common` | Dispatches an expression to the local evaluator kernel (used to apply `SetDirectory` there as well as in the server kernel) |

## Related Documentation

- [MCP roots specification](https://modelcontextprotocol.io/specification/2025-11-25/client/roots.md) - Official MCP roots documentation
- [Specs/MCPRoots.md](../Specs/MCPRoots.md) - Design specification for this feature
- [tools.md](tools.md) - MCP tools system and how to add new tools
- [servers.md](servers.md) - Predefined server configurations
- [mcp-clients.md](mcp-clients.md) - Client support
