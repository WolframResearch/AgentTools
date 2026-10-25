# Socket MCP Server — Design Specification

## Overview

`StartMCPSocketServer[server, opts]` serves an `MCPServerObject` over the MCP Streamable HTTP transport (stateless
subset, protocol revision 2025-11-25) from inside the current kernel, including a front end kernel, and returns an
`MCPSocketServerObject`. It exists so that Chatbook's ACP window can give a coding agent (OpenCode, through an ACP
`{"type": "http", ...}` MCP server) tools that run in the user's front end kernel. The user-facing description is in
[docs/socket-server.md](../docs/socket-server.md); this document records the design decisions.

## Requirements

1. Run in a kernel that is doing other work, without blocking it: no read loop, no stdout, no usage data.
2. Never change the kernel's global state: a front end kernel must keep its messages, `In`/`Out`/`$Line` and every
   setting, whatever the client sends.
3. Let the caller decide where tool code runs. In a front end kernel, tools that make front end calls must run on the
   main link, not in a `SocketListen` handler.
4. Keep long tool calls alive for clients with idle timeouts (Bun's `fetch` fails after about five minutes without
   bytes), and never leave a client waiting for a response that will not come.
5. Be safe on a shared machine: loopback only, a bearer token, DNS-rebinding protection.

## Decisions

| Topic | Decision | Reason |
|-------|----------|--------|
| Listener | `SocketListen[{"127.0.0.1", port}, handler]` with raw TCP and our own HTTP/1.1 framing | `SocketListen` delivers raw chunks of at most 8 KB; `ImportByteArray[..., "HTTPRequest"]` ignores `Content-Length` and `ExportString[..., "HTTPResponse"]` writes no `Content-Length`. Measured in 15.0.1. |
| Bytes | `"DataByteArray"` only, decoded once a body is complete | `"Data"` decodes each chunk on its own and breaks UTF-8 characters split across chunks. |
| Writes | One `ByteArray` per write with `SocketWriteMessage` | It never blocks and fails only when the client is gone; `WriteString` drops data silently. |
| Sessions | Stateless: no `Mcp-Session-Id`, no GET stream (405) | Same model as the cloud transport; OpenCode works without a session and then never sends DELETE. |
| Handler work | Only framing and the cheap methods (`initialize`, `ping`, `tools/list`, ...) | The handler is preemptive: it blocks `Dynamic` updates, other handlers and tasks while it runs, and must not make front end calls. |
| Deferred calls | `tools/call` and `prompts/get` go to `"EvaluationFunction"` as `f[run, info]` | The caller (Chatbook) queues them for a main-link evaluation; `run[]` re-establishes the server state and writes the response from there. |
| Long calls | An SSE stream (chunked) started as soon as `f` returns, keep-alive comments, a final `event: message` | Keeps idle-timeout clients alive; chunked coding keeps the connection reusable. No event IDs, so clients never try to resume with GET. |
| Cancellation | `notifications/cancelled` from a request with the same bearer token ends the call without a JSON-RPC response | JSON-RPC IDs are unique per client only; MCP says a cancelled request gets no response. |
| Response order | Requests pipelined behind a deferred call wait until it is answered | HTTP/1.1 responses must be sent in request order. |
| Disconnects | Polled from `ConnectedClients` by one recurring task per server | There is no disconnect event; one-shot tasks in bursts can deadlock the 15.0 scheduler. |
| State isolation | Every request and `run[]` `Block`s all server session globals and `$Messages` | `handleMethod["initialize"]` assigns `$clientName` and capabilities. The stdio-only `$Messages = {}` policy moved from `handleMethod` to the stdio read loop. |
| Tool options | In a front end kernel, `WolframLanguageEvaluator` defaults to the `"Local"` method | The `"Session"` method would evaluate agent code in the user's session and reset its history. |
| Authentication | A 256-bit token (`GenerateSymmetricKey`), or the caller's function, compared in constant time | Loopback ports are reachable by every local user and process. |
| Host and Origin | `Host` must be the server; a present `Origin` must be the server | DNS-rebinding protection; MCP clients send no `Origin`. |
| Head checks | Path, method, `Host`, `Origin`, authentication and `Accept` are checked as soon as the head arrives; refusals close the connection (except a 405 without a body for an allowed client); bodies are capped at 8 MB; partial requests time out after 30 s, not counting a stall of the kernel (a maintenance pass more than two intervals late) | A client that may not use the server must not be able to make the kernel buffer bodies or unread responses. OpenCode probes with GET on a connection it reuses. Bytes that arrive while the kernel cannot run the handler wait for it. |
| Message classification | Requests, notifications and responses are told apart explicitly (`jsonRPCMessageType`); a request without an `id` gets a 202 and is never evaluated; anything else gets -32600 with its `id` | A `tools/call` must never run in the handler or bypass the evaluation function; a client waiting on an invalid message must get an answer. |
| Response encoding | Responses are encoded before they are written; one that cannot be encoded is replaced by an error | A tool result can hold values that JSON cannot represent; an event stream must never end without a response. |
| Error scopes | Every entry point uses `catchTopIsolated`, a `catchTop` that always starts a new scope | Preemptive evaluations see the `Block`s of the evaluation they interrupt, including another `catchTop`. |
| Tokens | The object, the server records and the jobs hold no tokens (records and jobs keep SHA-256 digests); messages and internal-failure data redact secrets (`redactSecrets` in `Common.wl`): token values, Authorization header lines and `Bearer` tokens, and their other occurrences (those of 8 or more characters) and those of the secrets registered with `withFailureSecrets`, whatever their length (every entry point registers the servers' tokens, the request handling the request's token, so a server that authenticates with a function is covered too); the evaluation stack is not searched; the failure log directory is made private (0700) | Objects end up in notebooks, records and jobs in failure data, and failure data in log files. A failing call can hold a bare token; the stack can hold any amount of the interrupted evaluation's data. |
| Internal failures | One while a request is read answers it with a 500 and closes the connection; `run[]` finishes its call even when it fails internally | A client must never wait for a response that will not come. |
| Start and stop | Neither is interrupted by aborts; an abort that arrives during the start (it is postponed until the start has finished) stops the server again | The caller of an aborted start never gets the object, so nothing could stop the server. |
| Server state | Kept in ``Wolfram`AgentToolsState`SocketServer` ``, outside the paclet's contexts; created on demand at every entry point | A paclet reload clears its symbols and an MX load restores build-time values, but listeners and tasks outlive both. |
| Shared code | Accept negotiation, body parsing, the protocol-version check, message classification and response strings moved from `Cloud.wl` to `HTTP.wl` | Both HTTP transports use them; `RunCloudMCPServer` now also leaves requests without an `id` unevaluated and answers invalid messages with a 400. |

## Known Limitations

- 15.0 leaks about four file descriptors per accepted connection that the client closes; connections are kept alive
  (`Keep-Alive: timeout=300`) to keep the leak small.
- No server-to-client messages (no GET stream): no `list_changed` notifications, roots or sampling.
- `SocketWriteMessage` buffers without limit for clients that never read (only clients that pass the checks can cause it).
- With the default evaluation function, tools run in the handler: no aborts, no keep-alives, and no other requests
  while a tool runs.
- No IPv6 listener.
