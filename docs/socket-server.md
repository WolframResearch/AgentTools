# Socket MCP Server

`StartMCPSocketServer` runs an `MCPServerObject` as a local MCP server over the **Streamable HTTP** transport inside
the current kernel, including a front end kernel. It listens on `127.0.0.1` with `SocketListen`, returns an
`MCPSocketServerObject` at once, and serves requests in the background until it is stopped with `DeleteObject`.

Unlike `StartMCPServer` (the stdio transport, a blocking read loop that needs a kernel of its own), the socket server
shares the kernel with whatever else runs in it. The motivating use is Chatbook's ACP window: it starts a socket
server with notebook tools and passes it to the coding agent (OpenCode) as an ACP `{"type": "http", ...}` MCP server,
so the agent can call tools that run in the user's front end kernel.

## Quick Start

```wl
server = MCPServerObject[ <|
    "Name"         -> "Notebooks",
    "Location"     -> None,  (* an in-memory server: nothing is written to disk *)
    "LLMEvaluator" -> <| "Tools" -> { LLMTool[ "Echo", { "text" -> "String" }, #text & ] } |>
|> ];

socketServer = StartMCPSocketServer[ server ]
(* MCPSocketServerObject[...] *)

socketServer[ "URL" ]                (* "http://127.0.0.1:41817/mcp" *)
socketServer[ "JSONConfiguration" ]  (* {"type": "http", "url": ..., "headers": {"Authorization": "Bearer ..."}} *)
(* a server entry for a client's config file, such as Claude Code's .mcp.json *)

DeleteObject[ socketServer ]
```

A client connects to the URL with `Authorization: Bearer <token>` (`socketServer["Token"]`):

```bash
curl -X POST "http://127.0.0.1:41817/mcp" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## `StartMCPSocketServer`

```wl
StartMCPSocketServer[ server ]
StartMCPSocketServer[ server, opts ]
```

`server` is an `MCPServerObject` or the name of one (resolved with `MCPServerObject[name]`). The server's tool and
prompt tables are built once, when the server starts (`initializeServerState`); every request reuses them. On error
the function issues a message and returns a `Failure`.

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `"Port"` | `Automatic` | `Automatic` (a free port chosen by the system) or an integer from 1 to 65535. The server always binds `127.0.0.1`. |
| `"Path"` | `"/mcp"` | The endpoint path. Requests are routed on the path alone (OpenCode appends `?codemode=false`); other paths get a 404. |
| `"Authentication"` | `Automatic` | `Automatic`, `None`, a token string, or a function; see [Authentication](#authentication). |
| `"EvaluationFunction"` | `Automatic` | How `tools/call` and `prompts/get` are evaluated; see [Evaluation Function](#evaluation-function). `Automatic` evaluates them at once, in the handler (`#1[ ] &`). |
| `"KeepAliveInterval"` | `15` | Seconds between the keep-alive comments of a pending call's event stream, or `None` for none. |
| `"ToolOptions"` | `Automatic` | The tool options (`$toolOptions`) used for tool evaluations: `Automatic` uses `MCP_TOOL_OPTIONS`, as the stdio server does, or an association of per-tool option associations. See [Tool Options](#tool-options). |

### `MCPSocketServerObject`

| Property | Description |
|----------|-------------|
| `"ID"` | A UUID identifying the server. |
| `"Port"` | The port the server listens on (an integer). |
| `"Path"` | The endpoint path. |
| `"URL"` | `"http://127.0.0.1:<port><path>"`. Always the literal address: the listener has no IPv6 socket, and `localhost` can resolve to `::1` first on macOS and Windows. |
| `"Token"` | The bearer token clients must send, or `None` for `None` and function authentication. The kernel keeps the token, not the object (see [Security](#security)), so an object from another kernel session gives `Missing["NotAvailable"]`. It stays available after the server stops. |
| `"Server"` | The `MCPServerObject` (after paclet resolution). |
| `"Name"` | The server's name. |
| `"Listener"` | The `SocketListener`. |
| `"Running"` | `True` while the server is listening. |
| `"PendingRequests"` | The number of deferred calls that have not been answered yet. |
| `"JSONConfiguration"` | A client configuration entry in the format of the server entries of Claude Code's `.mcp.json` or VS Code's `mcp.json`: `{"type": "http", "url": ..., "headers": {"Authorization": "Bearer ..."}}`. It is not an ACP `mcpServers` entry: those also need a `"name"`, and their `"headers"` are a list of `{"name": ..., "value": ...}` objects. |
| `"Properties"` | The list of properties. |

`obj[ { prop1, prop2, ... } ]` gives an association of several properties. The summary box shows the name, URL, port,
path and tools. The object holds no token, so neither the box nor a notebook that displays the object contains it.

`DeleteObject[ obj ]` stops the server: pending deferred calls are answered with an error ("The MCP server was
stopped."), the server's maintenance task and its listener are removed (which closes every client connection), and its
state is cleared. It returns `Null`; deleting a server that is no longer running does nothing. Starting and stopping a
server are not interrupted by aborts, so neither leaves a listener or a task behind. An abort (Alt+., or a
`TimeConstrained` around `StartMCPSocketServer`) that arrives while a server starts is raised once the start has
finished; the start then stops the server again before the abort goes on, since the caller would never get its object.
Only an abort in the last few evaluation steps of the return, after the start has finished, can still leave a server
running that nothing refers to.

## Request Handling

The `SocketListen` handler is a **preemptive** evaluation: it interrupts whatever the kernel is evaluating, and no
`Dynamic` updates, other handlers or scheduled tasks run until it returns. It must also never make front end calls. So
the handler only frames requests and answers the cheap methods itself:

| Message | Handled |
|---------|---------|
| `initialize`, `ping`, `tools/list`, `prompts/list`, `resources/list`, `resources/read`, unknown methods | Answered in the handler with `handleMethod`. These are cheap and pure, and OpenCode's `session/new` waits for `initialize` and `tools/list`. |
| Notifications, JSON-RPC responses from the client, and requests without an `id` (or with a null one) | 202 with no body. `notifications/cancelled` cancels the matching call. Only `notifications/...` methods are dispatched: a request without an `id` is never evaluated, so a `tools/call` can neither run in the handler nor bypass the evaluation function. |
| Anything else, such as an `id` with a `method` that is not a string | 400 with a JSON-RPC error -32600 that carries the message's `id`: its client may be waiting for a response to it. |
| `tools/call`, `prompts/get` | Deferred: handed to the evaluation function. Calls with malformed parameters (-32602), unknown prompts (-32602) and unknown tools (an error result) are answered at once. |

The server is stateless: it never assigns an `Mcp-Session-Id`, and each request is handled on its own, like the cloud
transport (see [Cloud Deployment](cloud-deployment.md#stateless-evaluation-model)).

### Evaluation Function

The evaluation function is called in the handler as `f[ run, info ]` for every deferred call. It must return quickly and
make no front end calls; typically it puts the call in a queue that an ordinary (main-link) evaluation drains later.

`run` is a function of no arguments. `run[ ]` evaluates the call inside the server's state `Block`s (see
[Isolation](#isolation-from-the-kernel)), converts the result, writes the HTTP response, and returns the JSON-RPC
response association that was sent. Only the first call does anything: if the call was already answered, rejected or
cancelled, its client disconnected, or the server stopped, `run[ ]` evaluates nothing and returns `Null`. Tool code
runs under `CheckAbort`, so an abort (the user's Alt+.) gives a tool result with `"isError" -> True` and the text "The
tool call was aborted by the user." (for `prompts/get`, a JSON-RPC error) instead of aborting `run[ ]`; writing the
response cannot be aborted. If the call was cancelled or rejected while it was running, the result is discarded and
nothing is written, but `run[ ]` still returns it.

A response is encoded before anything is written. A result that cannot be encoded as JSON (a tool result can hold
values that JSON cannot represent, such as `Missing[ ]`) is answered with an error instead: a tool result with
`"isError" -> True` and the text "The result of this call could not be encoded as JSON." (for `prompts/get`, a JSON-RPC
error), which `run[ ]` then returns. If the response cannot be written (the client is gone), the connection is closed.
So a client never waits for a response that will not come.

`info` is an association:

| Key | Value |
|-----|-------|
| `"Method"` | `"tools/call"` or `"prompts/get"` |
| `"Name"` | The tool or prompt name |
| `"Arguments"` | The arguments association |
| `"RequestID"` | The JSON-RPC request ID |
| `"Token"` | The request's bearer token, or `None` |
| `"Server"` | The `MCPSocketServerObject` |
| `"ReceivedAt"` | `AbsoluteTime[ ]` when the request arrived |
| `"Reject"` | `rej[ message ]` answers the call without running it: an error tool result with that text (`prompts/get`: JSON-RPC error -32603 with that message). Gives the response sent, or `Null` if the call was no longer active. |
| `"ActiveQ"` | `act[ ]` gives `False` once the call has been answered, rejected or cancelled, its server stopped, or its client disconnected. |

`run[ ]`, `rej[ ]` and `act[ ]` can be called from any evaluation, including a preemptive one such as a scheduled
task; like every entry point of the server they return their failures rather than throw them (see
[Threading](#threading)).

`run[ ]` never leaves a call unanswered, even when AgentTools fails internally (such failures are logged, see
[Limitations](#limitations)). An internal failure while the call is evaluated is answered with a JSON-RPC error -32603
("Internal error"), which `run[ ]` returns like any other response. Only an internal failure while `run[ ]` claims or
answers the call makes it return a `Failure`, and the call is finished all the same: a call that could not be claimed
is answered with the same internal error, and if a response could not be written, the connection is closed, so the
client fails at once. Either way, once `run[ ]` has returned, `act[ ]` gives `False` and `rej[ ]` does nothing.

If `f` fails with a `Throw` or an abort, the call is rejected. `f` is normally called from the handler; for a request
that was pipelined behind a deferred call on the same connection, it is called when that earlier call finishes (from
whatever evaluation finished it), since HTTP responses must be sent in request order.

A queue drained on the main link of a front end kernel, as Chatbook does it (in outline):

```wl
StartMCPSocketServer[
    server,
    "EvaluationFunction" -> Function[ { run, info }, PreemptProtect @ AppendTo[ $queue, { run, info } ]; wakeDrain[ ] ]
];

drain[ ] := While[ $queue =!= { },
    With[ { job = First @ $queue },
        $queue = Rest @ $queue;
        If[ job[[ 2 ]][ "ActiveQ" ][ ], job[[ 1 ]][ ] ]
    ]
];
```

### Response Modes

What the client receives for a deferred call depends on when it is answered and on its `Accept` header:

- If `f` answered the call before returning (e.g. with the default evaluation function), the response is
  `application/json`, or a single `event: message` event if the client accepts only `text/event-stream`.
- Otherwise, if the client lists `text/event-stream` in `Accept` (MCP clients send
  `Accept: application/json, text/event-stream`) and speaks HTTP/1.1, the response head of an event stream (chunked
  transfer coding) is written at once. The stream carries a `: keepalive` comment about every `"KeepAliveInterval"`
  seconds and ends with `event: message`, `data: <response>` and the terminal chunk once the call is answered. Bun's
  `fetch` (OpenCode) fails a request that receives no bytes for about five minutes, so long calls need this. Events
  carry no `id`, so the client never tries to resume a stream with a GET request.
- Otherwise the client waits silently for an `application/json` response.

A cancelled call (`notifications/cancelled` with its `requestId`, from a request with the same bearer token, since
JSON-RPC IDs are only unique per client) gets no JSON-RPC response: its event stream ends with just the terminal chunk,
or, if no response was started yet, it gets a 202 with no body. A call whose client disconnected is dropped.

A recurring `ScheduledTask` per server writes the keep-alives, finishes the calls of clients that left, and forgets
their connections. It runs every `"KeepAliveInterval"` seconds, but at least every 5 seconds and at most every quarter
second. It is the server's only task: bursts of one-shot tasks can deadlock the 15.0 kernel scheduler.

## HTTP

Each request is checked in this order (the order of the cloud transport, with the checks of a local server added).
The checks of the head, from the path to `Accept`, run as soon as the head has arrived, before the body is read: a
request that they refuse is answered at once, and its body is never buffered.

| Check | Failure |
|-------|---------|
| The path is the server's `"Path"` (the query string is ignored) | 404 |
| The method is `POST` (there is no GET stream and no session to `DELETE`) | 405 with `Allow: POST` |
| `Host` is `127.0.0.1:<port>` or `localhost:<port>` | 403 |
| `Origin` is absent, `http://127.0.0.1:<port>` or `http://localhost:<port>` | 403 |
| Authentication | 401 with `WWW-Authenticate: Bearer` |
| `Accept` allows `application/json` or `text/event-stream` (an absent `Accept` allows JSON) | 406 |
| The body is a single JSON-RPC message | 400 with a JSON-RPC error: -32700 for invalid JSON, -32600 for anything but an object (batches were removed in MCP 2025-06-18) |
| A `MCP-Protocol-Version` header on requests other than `initialize` names a supported version | 400 with a JSON-RPC error -32600 |

Every one of these errors closes the connection (`Connection: close`). So a client that may not use the server can
neither make it buffer a body nor make it queue responses that the client never reads (`SocketWriteMessage` never
blocks). The one exception is a 405 for a request without a body from a client that passes the `Host`, `Origin` and
authentication checks: OpenCode probes the endpoint with a GET request and then uses the same connection again.

`SocketListen` delivers raw chunks of at most 8 KB that can split a request anywhere (even inside a UTF-8 character)
or hold several pipelined requests, so the server buffers each connection and frames requests by `Content-Length`
itself (`ImportByteArray[..., "HTTPRequest"]` ignores `Content-Length`). Requests that cannot be framed are answered
with an error and the connection is closed: a malformed request line or `Content-Length` (400), request bodies with a
`Transfer-Encoding` (501; MCP clients send `Content-Length`), heads over 64 KB (431) and bodies over 8 MB (413; MCP
messages are far smaller). A request whose head or body gets no new bytes for 30 seconds gets a 408, and its connection
is closed; idle connections between requests are kept. Time during which the kernel could not run the server's handler
does not count: after a stall (for example a long `PreemptProtect` or native computation on the main link of a front
end kernel), bytes that arrived meanwhile still wait for the handler. The maintenance task notices a stall when it runs
more than two of its intervals after its previous run, and the 30 seconds then count from the end of the stall. An
unexpected (internal) error while a request is read is answered with a 500, and the connection is closed.
`Expect: 100-continue` gets a `100 Continue` once the head has passed its checks. Pipelined requests are answered in
order; requests behind a deferred call on the same connection are read once it has been answered.

Connections are persistent unless the client asks otherwise (`Connection: close`, or HTTP/1.0 without
`Connection: keep-alive`), and every response on a persistent connection carries `Connection: keep-alive` (which an
HTTP/1.0 client needs to keep it) and `Keep-Alive: timeout=300`, which keeps Node's `fetch` from dropping idle
connections after four seconds. Responses are written with `SocketWriteMessage` as one `ByteArray`; it
never blocks and fails only once the client is gone.

## Authentication

| `"Authentication"` | Requests must send |
|--------------------|--------------------|
| `Automatic` | `Authorization: Bearer <token>` with a 256-bit token generated from a cryptographic source (the key of `GenerateSymmetricKey[ ]`, as 64 hexadecimal digits) |
| `"token"` | `Authorization: Bearer token`; the token must be visible ASCII without spaces |
| `None` | Nothing |
| `f` | Anything for which `f[ token ]` gives `True`, where `token` is the bearer token or `None` without one |

Tokens are compared in constant time (their SHA-256 digests are compared byte by byte). An authentication function is
called in the handler for every request, so it must be fast and make no front end calls; anything but `True`,
including a `Throw` or an abort, refuses the request. With a function, the server has no token of its own (`"Token"`
is `None`), which lets the caller issue and revoke tokens per client, as Chatbook does per ACP connection. A function
is a symbol or a compound expression such as a pure function or an operator form; other values (e.g. `False`, `True`,
a number or a list) give a message rather than a server that refuses every request. The message for an invalid value
does not show it.

## Security

- The server listens on `127.0.0.1` only, so it can only be reached from this machine, but there by every local user
  and process: authentication is what protects it, and the token gives full access to the server's tools.
- The `Host` and `Origin` checks reject requests from web pages (DNS rebinding); there are no CORS headers, so browsers
  cannot read responses either. The `Origin` check comes before authentication.
- The token is not part of the `MCPSocketServerObject` expression: the kernel keeps it (see `"Token"`), so neither the
  object nor its summary box puts it into a notebook. `"Token"` and `"JSONConfiguration"` give it; do not log them.
  Messages and failures never show an `"Authentication"` value, and the server's records and pending calls keep only
  the token's SHA-256 digest.
- Requests are refused on their head, before their body is read, and refusals close the connection (see [HTTP](#http)).
- The data of AgentTools' internal failures, which messages show and bug reports and log files keep (see
  [Limitations](#limitations)), has its secrets redacted: the values of `"Token"`, `"Authentication"` and Authorization
  keys, the values of `Authorization:` header lines and the tokens after `Bearer` in strings and in raw request bytes,
  and every other occurrence of the values found that way that have at least 8 characters (see
  [Error Handling](error-handling.md#bug-report-generation)). In the failures of the socket servers' code, all other
  occurrences of the tokens of the kernel's socket servers and of the bearer token of the request being handled are
  redacted as well, whatever their length. So a failing call that only holds a request's bearer token shows it as
  `"<redacted>"` too, also on a server that authenticates with a function. Secrets are recognized whole, so a part of a
  token is only redacted after `Authorization:` or `Bearer`: if a client sent a request head in two pieces, split
  inside the token, and the failing call held the bytes of the second piece, the rest of the token at their start would
  show.
- Tools run with the full rights of the kernel. Only serve tools that are safe to give to the client.

## Isolation from the Kernel

Every request, and every `run[ ]`, `Block`s the server session globals that the transport-agnostic code uses:
`$MCPTransport` (`"StreamableHTTP"`), `$MCPEvaluationEnvironment` (`"Local"`), `$currentMCPServer`, `$mcpEvaluation`,
`$clientName`, `$clientSupportsUI` and `$clientSupportsRoots` (both `False`: MCP Apps and roots are not supported, so
`mcpAppsEnabledQ` is `False` as well, and `initialize` never advertises the MCP Apps extension), `$toolList`,
`$llmTools`, `$promptList`, `$promptLookup`, `$toolOptions`, `$logFile` and `$Messages`. So nothing a
request does, such as `initialize` recording the client's name and capabilities, leaks into the kernel. The server
does not record usage data, start other tasks, or touch stdout.

The stdio transport switches off messages (`$Messages = { }`) once a client that cannot handle stderr has sent
`initialize`. That policy used to live in `handleMethod["initialize"]`, which silenced every message of the kernel for
the HTTP transports; it now lives in the stdio read loop (`applyStderrPolicy` in `Local.wl`), inside `superQuiet`'s
`Block` of `$Messages`, which applies it from the client name in the `initialize` message before it handles the
message, as `handleMethod` used to.

### Tool Options

In a front end kernel (`$Notebooks`), the `WolframLanguageEvaluator` tool must not evaluate code in the kernel itself:
its default `"Session"` method would run the agent's code in the user's session and reset `In`, `Out` and `$Line`. So
the server uses the `"Local"` method (a sandboxed subkernel) when the method is missing or `Automatic`, and with
`"ToolOptions" -> Automatic` also instead of a `"Session"` from `MCP_TOOL_OPTIONS`. An explicit `"Session"` in the
`"ToolOptions"` option is kept.

## Threading

- Every entry point (`StartMCPSocketServer`, the object's properties and `DeleteObject`, the handler, the maintenance
  task, and `run[ ]`, `rej[ ]` and `act[ ]`) starts an error scope of its own (`catchTopIsolated`). Any of them can be
  a preemptive evaluation that interrupts an evaluation inside another AgentTools function, whose `catchTop` it would
  otherwise share: its failures would be thrown into that evaluation, which would also inherit its failure state.
- The handler and the maintenance task are preemptive evaluations that never preempt each other. `run[ ]`, `rej[ ]`,
  `act[ ]`, `StartMCPSocketServer` and `DeleteObject` can run in ordinary evaluations, which handlers can preempt at
  any evaluation step, so every change they make to the server's state (and every write to a client) is wrapped in
  `PreemptProtect`. The tool evaluation itself is not, so the server keeps answering requests while a tool runs.
- Nothing may escape the handler: an uncaught `Throw` would end, and an `Abort` would abort, the evaluation it
  interrupted. The handler body runs under `AbortProtect` and `CheckAll`.
- With the default evaluation function, tools run in the handler, inside its `AbortProtect`. So Alt+. cannot abort a
  tool; no event stream is started (the call is answered when it finishes), so no keep-alives are sent, and a call
  that takes longer than a client's idle timeout fails (about five minutes for Bun-based clients such as OpenCode); and
  no other request, not even a `notifications/cancelled`, is handled until the tool finishes. In a front end kernel it
  also blocks `Dynamic` updates while a tool runs, and tools whose results contain graphics need the front end
  (`Rasterize`). So give servers with long tools, or in a front end kernel, an evaluation function that queues the
  calls and runs them on the main link.

### Reloading the Paclet

The state of the running servers lives in a context of its own, ``Wolfram`AgentToolsState`SocketServer` ``, outside the
paclet's contexts: reloading the paclet (``Get["Wolfram`AgentTools`"]``) clears every symbol of those contexts, and
loading its MX file restores their values from build time, but the listeners and maintenance tasks of running servers
outlive both. So servers keep running across a reload, and `DeleteObject` still stops them. A listener whose server has
no record (e.g. after a reload of an older version of the paclet) closes every connection at once, and `DeleteObject`
still removes its listener and its task.

## Limitations

- In 15.0, every accepted connection leaks about four file descriptors when the client closes it (the ZeroMQ proxy of
  the connection), which is why connections are kept alive. OpenCode (Bun) reuses its connections.
- There is no GET event stream, so the server cannot send notifications (e.g. `list_changed`) or requests (roots,
  sampling) to the client, and streams cannot be resumed.
- `SocketWriteMessage` buffers without limit: a client that never reads its responses makes the kernel hold them.
  Refusals close the connection, so only a client that may use the server can do this.
- The number of connections is not limited. Each one buffers at most one partial request head (64 KB) before it is
  checked, and partial requests are closed after 30 seconds without new bytes.
- No IPv6 listener; clients must use `127.0.0.1` (or `localhost` where it resolves to `127.0.0.1`).
- An internal failure in the handler builds a bug report, which in a front end kernel asks the front end for its
  version. Its data (the failing call, with the request being handled, and the names of the functions on the evaluation
  stack) is written to `$UserBaseDirectory/Logs/AgentTools/InternalFailures` with its secrets redacted (see
  [Security](#security)). On Unix-like systems that directory is made private to the user (mode 0700); on Windows, the
  user profile that holds it is private already. The rest of a request, such as a tool's arguments, is kept. The
  evaluation stack itself stays in memory, unredacted (`"Stack"` is a delayed value that is never written).

## Related Files

| File | Contents |
|------|----------|
| `Kernel/Server/Socket.wl` | `StartMCPSocketServer`, `MCPSocketServerObject`, HTTP framing, request handling, deferred calls, the maintenance task |
| `Kernel/Server/HTTP.wl` | Streamable HTTP helpers shared with the cloud transport: request accessors, `Accept` negotiation, the protocol-version check, JSON/SSE response strings |
| `Kernel/Server/Shared.wl` | `initializeServerState` and `handleMethod`, shared by all transports |
| `Tests/SocketServer.wlt` | Tests with real loopback clients |
| `Specs/SocketServer.md` | Design notes |

## Related Documentation

- [Cloud Deployment](cloud-deployment.md): the other Streamable HTTP transport
- [MCP Tools](tools.md): tools and tool options
- [Predefined Servers](servers.md)
