(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Server`Socket`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];
Needs[ "Wolfram`AgentTools`Server`" ];

$ContextAliases[ "sp`"    ] = "System`Private`";
$ContextAliases[ "state`" ] = "Wolfram`AgentToolsState`SocketServer`"; (* see Server State *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Overview*)
(*
    A Streamable HTTP MCP server that runs inside the current kernel, including a front end kernel, without blocking
    it: StartMCPSocketServer listens on 127.0.0.1 with SocketListen and returns an MCPSocketServerObject at once. See
    docs/socket-server.md.

    The SocketListen handler (socketEvent) is a preemptive evaluation: it interrupts whatever the kernel is doing, no
    Dynamic updates, other handlers or scheduled tasks run until it returns, and it must not make front end calls. So
    the handler only frames HTTP requests and answers the cheap methods (initialize, ping, tools/list, ...) directly.
    The calls that run tool or prompt code (tools/call and prompts/get) are handed to the server's "EvaluationFunction"
    as a run function and an information association; the caller decides where and when run[] evaluates the call
    (e.g. on the main link of a front end kernel) and run[] writes the response from there. Meanwhile the client
    waits on a Server-Sent Events stream that the server keeps alive with comments.

    Where the code runs:
      * socketEvent (SocketListen handler) and socketMaintenance (the server's recurring ScheduledTask) run as
        preemptive evaluations, which never preempt each other.
      * run[], the Reject and ActiveQ functions of a deferred call, StartMCPSocketServer and DeleteObject can run in
        ordinary evaluations, which handlers and tasks can preempt at any evaluation step. Everything they do to the
        shared state below (and every write to a client socket) is therefore wrapped in PreemptProtect, but the tool
        evaluation itself is not, so the server stays responsive while a tool runs.
      * Every one of these entry points runs in an error scope of its own (catchSocket), since any of them can be a
        preemptive evaluation that interrupts an evaluation inside AgentTools' catchTop.

    The server is stateless (no Mcp-Session-Id): the tool and prompt tables are built once at start, and every request
    is handled on its own inside withSocketRequestState, which Blocks every server session global so that nothing a
    request does (e.g. handleMethod["initialize"] setting $clientName) leaks into the kernel.

    HTTP framing follows a prototype that was tested against curl, Node and Bun (OpenCode) clients: SocketListen
    delivers raw chunks of at most 8 KB, which may split a request anywhere (even inside a UTF-8 character) or hold
    several pipelined requests, so each client connection keeps its own buffer and requests are framed by
    Content-Length. Responses are written as one ByteArray with SocketWriteMessage, which never blocks and fails only
    once the client is gone. There is no disconnect event: clients that left disappear from the listener's
    ConnectedClients, which the maintenance task polls.
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$socketHost             = "127.0.0.1";  (* the only interface the server listens on *)
$maxHeaderBytes         = 64 * 1024;    (* larger request headers get a 431 *)
$maxBodyBytes           = 8 * 1024^2;   (* larger request bodies get a 413; MCP messages are much smaller *)
$requestTimeout         = 30;           (* seconds a partial request may go without new bytes before it gets a 408 *)
$lateMaintenanceFactor  = 2;            (* a maintenance pass this many intervals after the last one finds a stall *)
$keepAliveTimeout       = 300;          (* seconds, advertised in the Keep-Alive header of every response *)
$maxMaintenanceInterval = 5;            (* longest time in seconds between runs of a server's maintenance task *)
$minMaintenanceInterval = 0.25;         (* shortest time in seconds between runs of a server's maintenance task *)
$socketResponseTag      = "Wolfram`AgentTools`Server`Socket`Response";

$abortedToolText            = "The tool call was aborted by the user.";
$abortedPromptText          = "The prompt request was aborted by the user.";
$serverStoppedText          = "The MCP server was stopped.";
$evaluationFunctionFailText = "The MCP server could not schedule this request.";
$encodingFailedText         = "The result of this call could not be encoded as JSON.";

$deferredMethods = { "tools/call", "prompts/get" };

(* Request tokens are sent in an HTTP header, so they must be visible ASCII characters without spaces. *)
$$tokenString = _String? (StringMatchQ[ RegularExpression[ "[!-~]+" ] ]);

$socketServerProperties = {
    "ID",
    "JSONConfiguration",
    "Listener",
    "Name",
    "Path",
    "PendingRequests",
    "Port",
    "Properties",
    "Running",
    "Server",
    "Token",
    "URL"
};

(* The object holds no token: objects end up in notebooks (see Server State). *)
$$socketServerData = KeyValuePattern @ {
    "ID"       -> _String,
    "Listener" -> _SocketListener,
    "Name"     -> _String,
    "Path"     -> _String,
    "Port"     -> _Integer,
    "Server"   -> _MCPServerObject,
    "URL"      -> _String
};

$httpReasons = <|
    100 -> "Continue",
    200 -> "OK",
    202 -> "Accepted",
    400 -> "Bad Request",
    401 -> "Unauthorized",
    403 -> "Forbidden",
    404 -> "Not Found",
    405 -> "Method Not Allowed",
    406 -> "Not Acceptable",
    408 -> "Request Timeout",
    413 -> "Content Too Large",
    431 -> "Request Header Fields Too Large",
    500 -> "Internal Server Error",
    501 -> "Not Implemented"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Server State*)
(* The state of the running servers lives in a context of its own (state`), outside Wolfram`AgentTools`: reloading the
   paclet clears every symbol of its contexts (AgentToolsLoader.wl), and loading its MX file restores their values from
   build time, but the listeners and maintenance tasks of running servers outlive a reload, and their handlers, the
   deferred calls of their clients and DeleteObject must still find them afterwards.

     state`$servers      server ID -> the server record (configuration, server state, listener, task)
     state`$connections  client SocketObject -> the framing state of that connection (see newConnection)
     state`$jobs         job ID -> a deferred tools/call or prompts/get request that has not finished yet
     state`$tokens       server ID -> the server's own bearer token, or None (the "Token" property). Server objects,
                         records and jobs hold no tokens, since objects end up in notebooks and records and jobs in
                         failure data. A token is kept after its server stops, like the server's other properties. *)
initializeSocketState // beginDefinition;

initializeSocketState[ ] := (
    If[ ! AssociationQ @ state`$servers    , state`$servers     = <| |> ];
    If[ ! AssociationQ @ state`$connections, state`$connections = <| |> ];
    If[ ! AssociationQ @ state`$jobs       , state`$jobs        = <| |> ];
    If[ ! AssociationQ @ state`$tokens     , state`$tokens      = <| |> ];
    Null
);

initializeSocketState // endDefinition;

(* Loading the MX file runs no code, so the entry points create the registries as well (catchSocket). *)
initializeSocketState[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*catchSocket*)
(* The error scope of every entry point of the transport: StartMCPSocketServer, the object's properties and
   DeleteObject, the handler, the maintenance task, and the run, Reject and ActiveQ functions of deferred calls. Each of
   them can run as a preemptive evaluation (the handler and the task always do, and a caller's own task can call the
   others, as Chatbook's ACP pump does), so unlike catchTop it always starts a scope of its own (catchTopIsolated):
   otherwise it would share the failure state of an AgentTools evaluation that it interrupted, and Throw its failures
   into that evaluation. The data of its internal failures never shows the servers' tokens (withFailureSecrets). *)
catchSocket // beginDefinition;
catchSocket // Attributes = { HoldFirst };
catchSocket[ eval_ ] := catchSocket[ eval, AgentTools ];

catchSocket[ eval_, sym_Symbol ] :=
    catchTopIsolated[ initializeSocketState[ ]; withFailureSecrets[ Values @ state`$tokens, eval ], sym ];

catchSocket // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*StartMCPSocketServer*)
StartMCPSocketServer // beginDefinition;

StartMCPSocketServer // Options = {
    "Authentication"     -> Automatic,
    "EvaluationFunction" -> Automatic,
    "KeepAliveInterval"  -> 15,
    "Path"               -> "/mcp",
    "Port"               -> Automatic,
    "ToolOptions"        -> Automatic
};

StartMCPSocketServer[ server: _MCPServerObject | _String, opts: OptionsPattern[ ] ] :=
    catchSocket[
        startMCPSocketServer[
            server,
            <|
                "Authentication"     -> OptionValue[ "Authentication"     ],
                "EvaluationFunction" -> OptionValue[ "EvaluationFunction" ],
                "KeepAliveInterval"  -> OptionValue[ "KeepAliveInterval"  ],
                "Path"               -> OptionValue[ "Path"               ],
                "Port"               -> OptionValue[ "Port"               ],
                "ToolOptions"        -> OptionValue[ "ToolOptions"        ]
            |>
        ],
        StartMCPSocketServer
    ];

(* The message for invalid arguments shows the call, but never the value of an "Authentication" option. *)
StartMCPSocketServer[ args___ ] :=
    catchSocket[
        throwFailure[ "InvalidArguments", StartMCPSocketServer, redactSecrets @ HoldForm @ StartMCPSocketServer @ args ],
        StartMCPSocketServer
    ];

StartMCPSocketServer // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*startMCPSocketServer*)
startMCPSocketServer // beginDefinition;

startMCPSocketServer[ server_, options_Association ] := Enclose[
    Module[
        {
            obj, port, path, auth, token, evaluator, keepAlive, interval, toolOptions, built, name, serverState, id,
            handler, listener = None, boundPort, url, object, record, task, started = False
        },

        obj         = ConfirmBy[ ensureMCPServerExists @ toMCPServerObject @ server, MCPServerObjectQ, "Server" ];
        port        = validateSocketPort @ options[ "Port" ];
        path        = validateSocketPath @ options[ "Path" ];
        auth        = socketAuthentication @ options[ "Authentication" ];
        token       = Lookup[ auth, "Token", None ];
        evaluator   = Replace[ options[ "EvaluationFunction" ], Automatic -> $socketDefaultEvaluationFunction ];
        keepAlive   = validateKeepAliveInterval @ options[ "KeepAliveInterval" ];
        toolOptions = validateSocketToolOptions @ options[ "ToolOptions" ];
        interval    = Clip[
            Replace[ keepAlive, None -> $maxMaintenanceInterval ],
            { $minMaintenanceInterval, $maxMaintenanceInterval }
        ];

        (* Build the tool and prompt tables once; every request reuses them. *)
        built       = ConfirmBy[ initializeSocketServerState @ obj, AssociationQ, "State" ];
        name        = ConfirmBy[ built[ "Server" ][ "Name" ], StringQ, "Name" ];
        serverState = <|
            built[ "State" ],
            "ToolOptions" -> socketToolOptions[ toolOptions, built[ "State", "ToolOptions" ] ]
        |>;

        id      = CreateUUID[ ];
        handler = With[ { i = id }, Function[ event, socketEvent[ i, event ] ] ];

        (* Starting is not interrupted by aborts, so that it never leaves a listener without a registered server, or a
           registered server without its maintenance task. AbortProtect only postpones an abort (Alt+., or a caller's
           TimeConstrained), which is raised once the block has finished: the caller would then never get the object
           of the server that the block started, so a start that does not finish stops the server again (and forgets
           its token, which nobody can ask for) before the abort goes on. CheckAbort would not do: it does not see the
           aborts of TimeConstrained. *)
        WithCleanup[
            AbortProtect[
                (* No handler may run before the server is registered, so the listener is created and registered as
                   one step that handlers cannot preempt. A listener whose server could not be registered is removed
                   again. *)
                PreemptProtect @ WithCleanup[
                    listener = Quiet @ SocketListen[ { $socketHost, port }, handler ];
                    If[ ! MatchQ[ listener, _SocketListener ],
                        throwFailure[ "SocketServerListenFailed", port, failureText @ listener ]
                    ];

                    boundPort = ConfirmBy[ listener[ "Socket" ][ "DestinationPort" ], IntegerQ, "Port" ];
                    url       = "http://" <> $socketHost <> ":" <> ToString @ boundPort <> path;
                    object    = ConfirmMatch[
                        createMCPSocketServerObject @ <|
                            "ID"       -> id,
                            "Listener" -> listener,
                            "Name"     -> name,
                            "Path"     -> path,
                            "Port"     -> boundPort,
                            "Server"   -> built[ "Server" ],
                            "URL"      -> url
                        |>,
                        _MCPSocketServerObject,
                        "Object"
                    ];

                    record = <|
                        "ID"                  -> id,
                        "Object"              -> object,
                        "Server"              -> built[ "Server" ],
                        "Port"                -> boundPort,
                        "Path"                -> path,
                        (* the token's digest, but not the token itself *)
                        "Authentication"      -> KeyDrop[ auth, "Token" ],
                        "EvaluationFunction"  -> evaluator,
                        "KeepAliveInterval"   -> keepAlive,
                        "MaintenanceInterval" -> interval,
                        (* when the last maintenance pass ran, and when the kernel's last stall ended (see
                           recordMaintenancePass); both start at the server's start *)
                        "LastMaintenance"     -> AbsoluteTime[ ],
                        "StallEnded"          -> AbsoluteTime[ ],
                        "State"               -> serverState,
                        "Listener"            -> listener,
                        "Task"                -> None
                    |>;

                    state`$tokens[ id ]  = token;
                    state`$servers[ id ] = record,

                    If[ ! KeyExistsQ[ state`$servers, id ] && MatchQ[ listener, _SocketListener ],
                        Quiet @ DeleteObject @ listener
                    ]
                ];

                (* One recurring task per server writes keep-alives and notices clients that left. Never one-shot tasks:
                   bursts of them can deadlock the 15.0 kernel scheduler. A server without its task must not run, so a
                   task that could not be submitted fails the start, which stops the server again. *)
                task = ConfirmMatch[
                    With[ { i = id }, SessionSubmit @ ScheduledTask[ socketMaintenanceTask @ i, interval ] ],
                    _TaskObject,
                    "Task"
                ];
                PreemptProtect @ If[ KeyExistsQ[ state`$servers, id ],
                    state`$servers[ id, "Task" ] = task,
                    Quiet @ TaskRemove @ task
                ]
            ];
            started = True,
            If[ ! started, stopSocketServer[ id, listener ]; KeyDropFrom[ state`$tokens, id ] ]
        ];

        object
    ],
    throwInternalFailure
];

startMCPSocketServer // endDefinition;

(* Evaluate deferred calls immediately, in the handler that received them. *)
$socketDefaultEvaluationFunction = #1[ ] &;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toMCPServerObject*)
toMCPServerObject // beginDefinition;
toMCPServerObject[ obj_MCPServerObject ] := obj;
toMCPServerObject[ name_String ] := MCPServerObject @ name;
toMCPServerObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*initializeSocketServerState*)
(* Builds the server state (initializeServerState) under the same bindings that requests see, so that tool overrides
   resolve for this transport. initializeServerState may replace $currentMCPServer (paclet-backed servers), so the
   server object that requests use is read back from it. *)
initializeSocketServerState // beginDefinition;

initializeSocketServerState[ obj_MCPServerObject ] := Enclose[
    Block[
        {
            $MCPTransport             = "StreamableHTTP",
            $MCPEvaluationEnvironment = "Local",
            $currentMCPServer         = obj,
            $mcpEvaluation            = True,
            $clientName               = None,
            $clientSupportsUI         = False,
            $clientSupportsRoots      = False
        },
        Module[ { state, server },
            state  = ConfirmBy[ initializeServerState @ obj, AssociationQ, "InitializeServerState" ];
            server = ConfirmBy[ $currentMCPServer, MCPServerObjectQ, "Server" ];
            <| "Server" -> server, "State" -> state |>
        ]
    ],
    throwInternalFailure
];

initializeSocketServerState // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*socketToolOptions*)
(* The tool options used for tool evaluations. In a front end kernel, the WolframLanguageEvaluator must never evaluate
   in the kernel itself (its default "Session" method would run agent code in the user's session and reset In, Out
   and $Line), so a missing or Automatic method becomes "Local" (a sandboxed subkernel). With "ToolOptions" ->
   Automatic, an explicit "Session" from MCP_TOOL_OPTIONS is replaced too; an explicit "Session" given in the option
   itself is kept. *)
socketToolOptions // beginDefinition;

socketToolOptions[ Automatic, stateOptions_Association ] :=
    localEvaluatorOptions[ stateOptions, Automatic | "Session" ];

socketToolOptions[ options_Association, _ ] :=
    localEvaluatorOptions[ options, Automatic ];

socketToolOptions // endDefinition;


validateSocketToolOptions // beginDefinition;
validateSocketToolOptions[ Automatic ] := Automatic;
validateSocketToolOptions[ options_Association ] /; AllTrue[ options, AssociationQ ] := options;
validateSocketToolOptions[ invalid_ ] := throwFailure[ "InvalidToolOptions", invalid ];
validateSocketToolOptions // endDefinition;


localEvaluatorOptions // beginDefinition;

localEvaluatorOptions[ options_Association, replace_ ] /; TrueQ @ $Notebooks :=
    Module[ { evaluator },
        evaluator = Replace[ Lookup[ options, "WolframLanguageEvaluator", <| |> ], Except[ _Association ] -> <| |> ];
        <|
            options,
            "WolframLanguageEvaluator" -> <|
                evaluator,
                "Method" -> Replace[ Lookup[ evaluator, "Method", Automatic ], replace -> "Local" ]
            |>
        |>
    ];

localEvaluatorOptions[ options_Association, _ ] :=
    options;

localEvaluatorOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Option Validation*)
validateSocketPort // beginDefinition;
validateSocketPort[ Automatic ] := Automatic;
validateSocketPort[ port_Integer ] /; 1 <= port <= 65535 := port;
validateSocketPort[ port_ ] := throwFailure[ "InvalidSocketServerPort", port ];
validateSocketPort // endDefinition;


validateSocketPath // beginDefinition;
validateSocketPath[ path_String ] /; StringMatchQ[ path, RegularExpression[ "/[^\\s?#]*" ] ] := path;
validateSocketPath[ path_ ] := throwFailure[ "InvalidSocketServerPath", path ];
validateSocketPath // endDefinition;


validateKeepAliveInterval // beginDefinition;
validateKeepAliveInterval[ None ] := None;
validateKeepAliveInterval[ t: _Integer | _Real | _Rational ] /; t > 0 := t;
validateKeepAliveInterval[ t_ ] := throwFailure[ "InvalidKeepAliveInterval", t ];
validateKeepAliveInterval // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*socketAuthentication*)
(* Automatic generates a token, a string is the token itself, None disables authentication, and a function decides from
   the bearer token (see authorizedQ). A token comes with its digest, which is all that the server record keeps of it.
   Values that cannot be functions (e.g. False, meant to disable authentication) are rejected rather than taken as a
   function that refuses every request. The message for an invalid value does not show it. *)
socketAuthentication // beginDefinition;
socketAuthentication[ Automatic ] := tokenAuthentication @ generateSocketToken[ ];
socketAuthentication[ None ] := <| "Type" -> "None" |>;
socketAuthentication[ token: $$tokenString ] := tokenAuthentication @ token;
socketAuthentication[ function_? authenticationFunctionQ ] := <| "Type" -> "Function", "Function" -> function |>;
socketAuthentication[ _ ] := throwFailure[ "InvalidSocketServerAuthentication" ];
socketAuthentication // endDefinition;


(* Whether a value can be an authentication function: a symbol (other than True, False and Null) or a compound
   expression such as a pure function or an operator form, but not a list or another atom. *)
authenticationFunctionQ // beginDefinition;
authenticationFunctionQ // Attributes = { HoldAllComplete };
authenticationFunctionQ[ True | False | Null ] := False;
authenticationFunctionQ[ _Symbol ] := True;
authenticationFunctionQ[ _List | _Missing | _Failure ] := False;
authenticationFunctionQ[ expr_ ] := ! AtomQ @ Unevaluated @ expr;
authenticationFunctionQ // endDefinition;


(* The new server's token is not registered yet (see catchSocket). *)
tokenAuthentication // beginDefinition;

tokenAuthentication[ token_String ] :=
    withFailureSecrets[ { token }, <| "Type" -> "Token", "Token" -> token, "Digest" -> tokenDigest @ token |> ];

tokenAuthentication // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*generateSocketToken*)
(* A 256-bit token from a cryptographic random source (the key of a new AES-256 key), as 64 hexadecimal digits. *)
generateSocketToken // beginDefinition;

generateSocketToken[ ] := Enclose[
    Module[ { bytes },
        bytes = ConfirmBy[ GenerateSymmetricKey[ ][ "Key" ], ByteArrayQ, "Key" ];
        ConfirmAssert[ Length @ bytes === 32, "KeyLength" ];
        StringJoin @ IntegerString[ Normal @ bytes, 16, 2 ]
    ],
    throwInternalFailure
];

generateSocketToken // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*failureText*)
failureText // beginDefinition;
failureText[ failure_Failure ] := Replace[ Quiet @ failure[ "Message" ], Except[ _String ] -> "unknown error" ];
failureText[ _ ] := "unknown error";
failureText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*MCPSocketServerObject*)
MCPSocketServerObject // ClearAll;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Main Definition*)
MCPSocketServerObject[ data_Association ]? sp`HoldNotValidQ :=
    catchSocket[ createMCPSocketServerObject @ data, MCPSocketServerObject ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createMCPSocketServerObject*)
createMCPSocketServerObject // beginDefinition;

createMCPSocketServerObject[ data_Association ] :=
    If[ MatchQ[ data, $$socketServerData ],
        sp`HoldSetValid @ MCPSocketServerObject @ data,
        throwFailure[ "InvalidArguments", MCPSocketServerObject, redactSecrets @ HoldForm @ MCPSocketServerObject @ data ]
    ];

createMCPSocketServerObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Properties*)
(MCPSocketServerObject[ data_Association ]? sp`HoldValidQ)[ prop: _String | { ___String } ] :=
    catchSocket[ getSocketServerProperty[ data, prop ], MCPSocketServerObject ];

_MCPSocketServerObject[ invalid_ ] :=
    catchSocket[ throwFailure[ "InvalidProperty", invalid ], MCPSocketServerObject ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSocketServerProperty*)
getSocketServerProperty // beginDefinition;

getSocketServerProperty[ data_Association, "Running"           ] := socketServerRunningQ @ data[ "ID" ];
getSocketServerProperty[ data_Association, "PendingRequests"   ] := Length @ serverJobs @ data[ "ID" ];
getSocketServerProperty[ data_Association, "Token"             ] := socketServerToken @ data[ "ID" ];
getSocketServerProperty[ data_Association, "JSONConfiguration" ] := socketServerJSONConfiguration @ data;
getSocketServerProperty[ data_Association, "Properties"        ] := $socketServerProperties;
getSocketServerProperty[ data_Association, "Data"              ] := data;

getSocketServerProperty[ data_Association, prop_String ] /; MemberQ[ $socketServerProperties, prop ] := data[ prop ];

getSocketServerProperty[ data_Association, props: { ___String } ] :=
    AssociationMap[ getSocketServerProperty[ data, # ] &, props ];

getSocketServerProperty[ _, prop_ ] := Missing[ "UnknownProperty", prop ];

getSocketServerProperty // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*socketServerRunningQ*)
(* True while the server is registered and its listening socket is open (the listener could also have been deleted
   directly). *)
socketServerRunningQ // beginDefinition;

socketServerRunningQ[ id_String ] :=
    With[ { server = Lookup[ state`$servers, id, None ] },
        AssociationQ @ server && MemberQ[ Sockets[ ], Quiet @ server[ "Listener" ][ "Socket" ] ]
    ];

socketServerRunningQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*socketServerToken*)
(* The server's own bearer token, which the object does not hold (see Server State): None for None and function
   authentication, and Missing for a server that this kernel did not start (e.g. an object from a saved notebook). *)
socketServerToken // beginDefinition;
socketServerToken[ id_String ] := Lookup[ state`$tokens, id, Missing[ "NotAvailable" ] ];
socketServerToken // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*socketServerJSONConfiguration*)
(* A client's configuration entry for the server, in the format of the server entries of Claude Code's .mcp.json or
   VS Code's mcp.json. It is not an ACP "mcpServers" entry: those also need a "name", and their "headers" are a list
   of { "name", "value" } objects. *)
socketServerJSONConfiguration // beginDefinition;

socketServerJSONConfiguration[ data_Association ] := Enclose[
    Module[ { token },
        token = socketServerToken @ data[ "ID" ];
        ConfirmBy[
            Developer`WriteRawJSONString @ <|
                "type"    -> "http",
                "url"     -> data[ "URL" ],
                "headers" -> If[ StringQ @ token, <| "Authorization" -> "Bearer " <> token |>, <| |> ]
            |>,
            StringQ,
            "JSON"
        ]
    ],
    throwInternalFailure
];

socketServerJSONConfiguration // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DeleteObject*)
(* Stops the server: pending deferred calls are answered with an error, the maintenance task and the listener (which
   closes every client connection) are removed, and the server's state is cleared. Stopping a server that is no longer
   running does nothing. *)
MCPSocketServerObject /: DeleteObject[ MCPSocketServerObject[ data_Association ] ] :=
    catchSocket[ stopSocketServer[ Lookup[ data, "ID" ], Lookup[ data, "Listener" ] ], MCPSocketServerObject ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stopSocketServer*)
(* Stopping is not interrupted by aborts, and the server's task and listener are removed even if answering its pending
   calls fails, so that a stopped server never leaves a listener or a task behind that nothing can remove. A server
   without a record (lost, e.g. to a reload of an older version of this paclet that kept its state in the paclet's
   contexts) can still have them: they are found from the object's data and the task's expression. *)
stopSocketServer // beginDefinition;

stopSocketServer[ id_String, listener_ ] :=
    PreemptProtect @ AbortProtect @ Module[ { server },
        server = Lookup[ state`$servers, id, None ];
        If[ AssociationQ @ server,
            WithCleanup[
                (* Unregister first: the pending calls are then answered without reading the requests held behind them
                   (releaseConnection), and handler events that are still due find no server. *)
                KeyDropFrom[ state`$servers, id ],
                Scan[
                    finishSocketJob[ #, jobErrorResponse[ state`$jobs[ # ], $serverStoppedText ] ] &,
                    Keys @ serverJobs @ id
                ],
                removeServerResources[ id, server[ "Task" ], server[ "Listener" ] ]
            ],
            removeServerResources[ id, None, listener ]
        ];
        Null
    ];

stopSocketServer[ _, _ ] := Null;

stopSocketServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeServerResources*)
(* Removes what an unregistered server leaves behind: its maintenance task (found by its expression when it is not
   known), its listener (which closes every client connection), and its connections and jobs. A task cannot remove
   itself (TaskRemove[$CurrentTask] is unsafe); the body of a task that is left ignores unknown servers. *)
removeServerResources // beginDefinition;

removeServerResources[ id_String, task_, listener_ ] := (
    Scan[
        If[ # =!= $CurrentTask, Quiet @ TaskRemove @ # ] &,
        If[ MatchQ[ task, _TaskObject ], { task }, maintenanceTasks @ id ]
    ];
    If[ MatchQ[ listener, _SocketListener ], Quiet @ DeleteObject @ listener ];
    state`$connections = Select[ state`$connections, #[ "ServerID" ] =!= id & ];
    KeyDropFrom[ state`$jobs, Keys @ serverJobs @ id ];
    Null
);

removeServerResources // endDefinition;


maintenanceTasks // beginDefinition;

maintenanceTasks[ id_String ] :=
    Select[ Tasks[ ], MatchQ[ Quiet @ #[ "EvaluationExpression" ], HoldForm @ socketMaintenanceTask @ id ] & ];

maintenanceTasks // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Formatting*)
MCPSocketServerObject /: MakeBoxes[ obj_MCPSocketServerObject? sp`HoldValidQ, fmt_ ] :=
    With[ { boxes = Quiet @ catchAlways @ makeMCPSocketServerObjectBoxes[ obj, fmt ] },
        boxes /; MatchQ[ boxes, _InterpretationBox ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Handling*)
MCPSocketServerObject[ args___ ]? sp`HoldNotValidQ := catchSocket[
    throwFailure[
        "InvalidArguments",
        MCPSocketServerObject,
        redactSecrets @ HoldForm @ MCPSocketServerObject @ args
    ],
    MCPSocketServerObject
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Request Framing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*socketEvent*)
(* The SocketListen handler. Nothing may escape it: an uncaught Throw would end, and an Abort would abort, the
   evaluation that the handler interrupted. *)
socketEvent // beginDefinition;

socketEvent[ id_String, event_ ] :=
    AbortProtect @ CheckAll[ catchSocket @ socketEvent0[ id, event ], Null & ];

socketEvent // endDefinition;


socketEvent0 // beginDefinition;

socketEvent0[ id_String, event_Association ] :=
    With[
        {
            server = Lookup[ state`$servers, id, None ],
            sock   = event[ "SourceSocket" ],
            (* "Data" decodes each chunk on its own, which breaks UTF-8 characters split across chunks *)
            bytes  = event[ "DataByteArray" ]
        },
        Which[
            ! MatchQ[ sock, _SocketObject ],
                Null,
            (* The listener of a server that has no record (see stopSocketServer): its clients must not wait for
               responses that will never come. *)
            ! AssociationQ @ server,
                closeSocket @ sock,
            ByteArrayQ @ bytes && Length @ bytes > 0,
                receiveBytes[ server, sock, bytes ]
        ];
        Null
    ];

socketEvent0[ _, _ ] := Null;

socketEvent0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*receiveBytes*)
(* Handles bytes received on a connection (feedSocket). If that fails (an internal failure, which is logged), the
   connection can no longer be framed, so it is closed and forgotten: its client fails at once, rather than waiting for
   a response that will not come. It gets a 500 first, unless it waits for the response to a deferred call (which the
   maintenance task finishes once the client is gone). *)
receiveBytes // beginDefinition;

receiveBytes[ server_Association, sock_SocketObject, bytes_ByteArray ] :=
    If[ FailureQ @ catchAlways @ feedSocket[ server, sock, bytes ],
        If[ MatchQ[ Lookup[ state`$connections, sock, None ], KeyValuePattern[ "Busy" -> _String ] ],
            closeSocket @ sock,
            writeHTTPError[ sock, 500 ]
        ];
        KeyDropFrom[ state`$connections, sock ];
        Null
    ];

receiveBytes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*feedSocket*)
(* Adds received bytes to a connection's buffer and handles every request they complete. Called by the handler and,
   for requests that arrived while a deferred call held the connection, when that call finishes (releaseConnection). *)
feedSocket // beginDefinition;

feedSocket[ server_Association, sock_SocketObject, bytes_ByteArray ] :=
    Module[ { conn },
        conn = Lookup[ state`$connections, sock, None ];
        If[ conn === None,
            (* A new connection: a good time to forget connections that were closed. *)
            purgeConnections @ server;
            conn = newConnection @ server[ "ID" ]
        ];
        conn = feedConnection[ server, sock, <| conn, "LastData" -> AbsoluteTime[ ] |>, bytes ];
        If[ AssociationQ @ conn,
            state`$connections[ sock ] = conn,
            KeyDropFrom[ state`$connections, sock ]
        ]
    ];

feedSocket // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*newConnection*)
(* The framing state of a client connection:
     "Head"     bytes of a request head that is not complete yet
     "Request"  the checked head of the request whose body is being received, or None
     "Chunks"   the body bytes received so far, and "Have" their total length
     "Busy"     the ID of the deferred call whose response the connection is waiting for, or None
     "Held"     bytes received while the connection was busy: HTTP responses must be sent in request order, so these
                requests are only read once the deferred call has been answered
     "LastData" when the handler last received bytes: a partial request that gets no more bytes for a while is
                closed (closeStalledConnections) *)
newConnection // beginDefinition;

newConnection[ id_String ] := <|
    "ServerID" -> id,
    "Head"     -> ByteArray[ { } ],
    "Request"  -> None,
    "Chunks"   -> { },
    "Have"     -> 0,
    "Busy"     -> None,
    "Held"     -> { },
    "LastData" -> AbsoluteTime[ ]
|>;

newConnection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*feedConnection*)
(* Frames as many requests as the buffered bytes complete, handles each one, and returns the new connection state, or
   None once the connection is closed. A request that its head already refuses is answered before its body is read
   (checkRequestHead), so a client that may not use the server cannot make it buffer a body. *)
feedConnection // beginDefinition;

feedConnection[ server_, sock_, conn_Association, bytes_ ] /; conn[ "Busy" ] =!= None :=
    holdBytes[ sock, conn, bytes ];

feedConnection[ server_, sock_, conn0_Association, bytes_ByteArray ] :=
    Catch[
        Module[ { conn = conn0, rest = bytes, head, end, request, need, body, outcome },
            While[ True,
                If[ conn[ "Request" ] === None,
                    head = Join[ conn[ "Head" ], rest ];
                    end  = headEnd @ head;
                    If[ end === None,
                        If[ Length @ head > $maxHeaderBytes, closeWithError[ sock, 431 ] ];
                        Throw[ <| conn, "Head" -> head |>, $feedTag ]
                    ];
                    If[ end - 4 > $maxHeaderBytes, closeWithError[ sock, 431 ] ];
                    request = parseRequestHead @ ByteArrayToString[ Take[ head, end - 4 ], "ISO8859-1" ];
                    If[ IntegerQ @ request, closeWithError[ sock, request ] ];
                    If[ request[ "ContentLength" ] > $maxBodyBytes, closeWithError[ sock, 413 ] ];
                    rest = Drop[ head, end ];
                    conn = <| conn, "Head" -> ByteArray[ { } ] |>;

                    request = checkRequestHead[ server, request ];
                    If[ MatchQ[ request, _refusal ],
                        If[ ! refuseRequest[ sock, request ], Throw[ None, $feedTag ] ];
                        If[ Length @ rest === 0, Throw[ conn, $feedTag ] ];
                        Continue[ ]
                    ];

                    If[ expectContinueQ @ request, writeSocket[ sock, StringToByteArray[ "HTTP/1.1 100 Continue\r\n\r\n" ] ] ];
                    conn = <| conn, "Request" -> request, "Chunks" -> { }, "Have" -> 0 |>
                ];

                request = conn[ "Request" ];
                need = request[ "ContentLength" ] - conn[ "Have" ];
                If[ Length @ rest < need,
                    Throw[ <| conn, "Chunks" -> Append[ conn[ "Chunks" ], rest ], "Have" -> conn[ "Have" ] + Length @ rest |>, $feedTag ]
                ];

                body = Join @@ Append[ conn[ "Chunks" ], Take[ rest, need ] ];
                rest = Drop[ rest, need ];
                conn = <| conn, "Request" -> None, "Chunks" -> { }, "Have" -> 0 |>;

                outcome = handleSocketRequest[ server, sock, <| request, "BodyByteArray" -> body |> ];
                Which[
                    (* A deferred call holds the connection until it is answered. *)
                    StringQ @ outcome,
                        Throw[ <| conn, "Busy" -> outcome, "Held" -> If[ Length @ rest > 0, { rest }, { } ] |>, $feedTag ],
                    (* The response closed the connection. *)
                    outcome === $Failed || ! TrueQ @ request[ "KeepAlive" ],
                        Throw[ None, $feedTag ],
                    Length @ rest === 0,
                        Throw[ conn, $feedTag ]
                ]
            ]
        ],
        $feedTag
    ];

feedConnection // endDefinition;

$feedTag = "Wolfram`AgentTools`Server`Socket`Feed";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*holdBytes*)
(* A client should not send another request on a connection before it has read the previous response, so held bytes
   stay small; a connection that holds more than a maximal request is closed. *)
holdBytes // beginDefinition;

holdBytes[ sock_, conn_Association, bytes_ByteArray ] :=
    With[ { held = Append[ conn[ "Held" ], bytes ] },
        If[ Total[ Length /@ held ] > $maxHeaderBytes + $maxBodyBytes,
            closeSocket @ sock; None,
            <| conn, "Held" -> held |>
        ]
    ];

holdBytes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*closeWithError*)
(* Answers a request that cannot be framed with an error and closes the connection, since the rest of its bytes cannot
   be read reliably. Only for use inside feedConnection. *)
closeWithError // beginDefinition;
closeWithError[ sock_, status_Integer ] := Throw[ writeHTTPError[ sock, status ]; None, $feedTag ];
closeWithError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*headEnd*)
(* The position of the last byte of the blank line that ends a request head, or None if it has not arrived yet.
   ISO8859-1 decodes every byte to one character, so string positions are byte positions. *)
headEnd // beginDefinition;

headEnd[ head_ByteArray ] :=
    Replace[ StringPosition[ ByteArrayToString[ head, "ISO8859-1" ], "\r\n\r\n", 1 ], { { { _, e_ } } :> e, _ :> None } ];

headEnd // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseRequestHead*)
(* Parses a request line and its header fields. Gives an association, or the status code of the error response:
   400 for a malformed head, 501 for request bodies with a Transfer-Encoding (MCP clients always send Content-Length).
   Header names are lowercased and repeated fields are joined with ", ", so a repeated Content-Length, Host or
   Authorization field is rejected by the checks that read it. *)
parseRequestHead // beginDefinition;

parseRequestHead[ head_String ] :=
    Catch @ Module[ { lines, parts, version, headers, length, connection },
        lines = StringSplit[ head, "\r\n" ];
        parts = If[ lines === { }, { }, StringSplit[ First @ lines, " " ] ];
        If[ Length @ parts =!= 3, Throw[ 400 ] ];
        version = parts[[ 3 ]];
        If[ ! MatchQ[ version, "HTTP/1.0" | "HTTP/1.1" ], Throw[ 400 ] ];

        headers = Merge[
            Cases[
                StringSplit[ #, ":", 2 ] & /@ Rest @ lines,
                { name_String, value_String } :> ToLowerCase @ StringTrim @ name -> StringTrim @ value
            ],
            StringRiffle[ #, ", " ] &
        ];
        If[ KeyExistsQ[ headers, "transfer-encoding" ], Throw[ 501 ] ];

        length = Lookup[ headers, "content-length", "0" ];
        If[ ! StringMatchQ[ length, DigitCharacter.. ], Throw[ 400 ] ];

        connection = ToLowerCase @ StringTrim @ StringSplit[ Lookup[ headers, "connection", "" ], "," ];

        <|
            "Method"        -> parts[[ 1 ]],
            "Target"        -> parts[[ 2 ]],
            (* MCP clients may add a query string (OpenCode appends ?codemode=false), so requests are routed on the
               path alone *)
            "Path"          -> First[ StringSplit[ parts[[ 2 ]], "?", 2 ], "" ],
            "Version"       -> version,
            "Headers"       -> headers,
            "ContentLength" -> FromDigits @ length,
            (* HTTP/1.1 connections are persistent unless the client says otherwise, HTTP/1.0 ones only on request *)
            "KeepAlive"     -> If[ version === "HTTP/1.0", MemberQ[ connection, "keep-alive" ], ! MemberQ[ connection, "close" ] ]
        |>
    ];

parseRequestHead // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expectContinueQ*)
(* curl waits a second before sending a large body unless the server answers "Expect: 100-continue". *)
expectContinueQ // beginDefinition;

expectContinueQ[ request_Association ] :=
    And[
        request[ "ContentLength" ] > 0,
        request[ "Version" ] === "HTTP/1.1",
        ToLowerCase @ Lookup[ request[ "Headers" ], "expect", "" ] === "100-continue"
    ];

expectContinueQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*purgeConnections*)
(* Forgets the framing state of connections that are no longer connected. *)
purgeConnections // beginDefinition;

purgeConnections[ server_Association ] :=
    purgeConnections[ server, connectedClients @ server ];

purgeConnections[ server_Association, clients_List ] :=
    With[ { id = server[ "ID" ] },
        KeyDropFrom[
            state`$connections,
            Select[ Keys @ state`$connections, state`$connections[ # ][ "ServerID" ] === id && ! MemberQ[ clients, # ] & ]
        ]
    ];

(* The client list could not be read: keep everything. *)
purgeConnections[ _, _ ] := Null;

purgeConnections // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*connectedClients*)
(* The client sockets that are still connected to a server, or Missing if they cannot be determined. There is no
   disconnect event, so this is the only way to notice clients that left. *)
connectedClients // beginDefinition;

connectedClients[ server_Association ] :=
    Replace[ Quiet @ server[ "Listener" ][ "Socket" ][ "ConnectedClients" ], Except[ _List ] -> Missing[ "NotAvailable" ] ];

connectedClients // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*socketConnectedQ*)
socketConnectedQ // beginDefinition;
socketConnectedQ[ server_Association, sock_ ] := socketConnectedQ[ connectedClients @ server, sock ];
socketConnectedQ[ clients_List, sock_ ] := MemberQ[ clients, sock ];
socketConnectedQ[ _Missing, _ ] := True;
socketConnectedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Request Handling*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkRequestHead*)
(* The checks of the MCP Streamable HTTP transport that need only the request head, in the order of the cloud transport
   (runCloudMCPServer0), with the path, Host and authentication checks of a local server added. They run before the
   body is read. Gives the request with its "ContentType", bearer "Token" and "Streamable" added (and without its
   Authorization header, which is not needed any more), or a refusal[status, headers, keepAlive]. The data of internal
   failures never shows the token (withFailureSecrets), which need not be a server's own token. *)
checkRequestHead // beginDefinition;

checkRequestHead[ server_Association, request_Association ] :=
    Module[ { headers, token, contentType },
        headers = requestHeaders @ request;
        token   = bearerToken @ Lookup[ headers, "authorization", None ];
        withFailureSecrets[
            { token },
            Which[
                (* 1. The endpoint path; the query string is ignored. *)
                request[ "Path" ] =!= server[ "Path" ],
                    refusal[ 404, { }, False ],

                (* 2. Only POST: there is no session to stream from (GET) or to end (DELETE). OpenCode probes the
                      endpoint with a GET request on a connection that it uses again, so the connection is kept for a
                      client that may use the server. *)
                ToUpperCase @ requestMethod @ request =!= "POST",
                    refusal[
                        405,
                        { "Allow" -> "POST" },
                        And[
                            request[ "ContentLength" ] === 0,
                            TrueQ @ request[ "KeepAlive" ],
                            clientAllowedQ[ server, headers, token ]
                        ]
                    ],

                (* 3. DNS-rebinding protection: the Host must be this server, and a browser Origin must be this server
                      too. *)
                ! hostAllowedQ[ server, headers ] || ! originAllowedQ[ server, headers ],
                    refusal[ 403, { }, False ],

                (* 4. Authentication. *)
                ! authorizedQ[ server[ "Authentication" ], token ],
                    refusal[ 401, { "WWW-Authenticate" -> "Bearer" }, False ],

                (* 5. Accept negotiation. *)
                (contentType = responseContentType @ headers) === None,
                    refusal[ 406, { }, False ],

                True,
                    <|
                        request,
                        "Headers"     -> KeyDrop[ headers, "authorization" ],
                        "ContentType" -> contentType,
                        "Token"       -> token,
                        "Streamable"  -> streamableQ[ request, headers ]
                    |>
            ]
        ]
    ];

checkRequestHead // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*refuseRequest*)
(* Answers a request that its head refuses and gives whether the connection is kept. Only a 405 for a request without a
   body from a client that may use the server keeps it (see checkRequestHead): otherwise the body would have to be read
   (and the server must not buffer data for clients that may not use it), and since SocketWriteMessage never blocks,
   a client that sends requests without reading their responses could make the kernel hold any number of them. *)
refuseRequest // beginDefinition;

refuseRequest[ sock_SocketObject, refusal[ status_Integer, headers_List, keepAlive_ ] ] := (
    writeHTTPResponse[ sock, status, headers, "", TrueQ @ keepAlive ];
    TrueQ @ keepAlive
);

refuseRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*hostAllowedQ*)
hostAllowedQ // beginDefinition;

hostAllowedQ[ server_Association, headers_Association ] :=
    With[ { host = Lookup[ headers, "host", None ], port = ToString @ server[ "Port" ] },
        StringQ @ host && MemberQ[ { $socketHost <> ":" <> port, "localhost:" <> port }, ToLowerCase @ host ]
    ];

hostAllowedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*originAllowedQ*)
(* MCP clients send no Origin; browsers always do. A present Origin must be this server itself, so web pages on other
   origins cannot drive it (DNS rebinding). *)
originAllowedQ // beginDefinition;

originAllowedQ[ server_Association, headers_Association ] :=
    With[ { origin = Lookup[ headers, "origin", None ], port = ToString @ server[ "Port" ] },
        origin === None || StringQ @ origin && MemberQ[
            { "http://" <> $socketHost <> ":" <> port, "http://localhost:" <> port },
            ToLowerCase @ origin
        ]
    ];

originAllowedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*clientAllowedQ*)
(* Whether a request comes from a client that may use the server: the checks 3 and 4 of checkRequestHead. *)
clientAllowedQ // beginDefinition;

clientAllowedQ[ server_Association, headers_Association, token_ ] :=
    hostAllowedQ[ server, headers ] && originAllowedQ[ server, headers ] && authorizedQ[ server[ "Authentication" ], token ];

clientAllowedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*bearerToken*)
(* The token of an "Authorization: Bearer <token>" header, or None. *)
bearerToken // beginDefinition;

bearerToken[ value_String ] :=
    Replace[
        StringCases[ value, RegularExpression[ "(?i)^\\s*bearer\\s+(\\S+)\\s*$" ] :> "$1" ],
        { { token_String } :> token, _ :> None }
    ];

bearerToken[ _ ] := None;

bearerToken // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*authorizedQ*)
(* An authentication function runs in the handler, so it must be fast and make no front end calls; anything but True
   (including an error) refuses the request. *)
authorizedQ // beginDefinition;

authorizedQ[ KeyValuePattern[ "Type" -> "None" ], _ ] := True;

authorizedQ[ KeyValuePattern[ "Type" -> "Token" ], None ] := False;

authorizedQ[ KeyValuePattern[ { "Type" -> "Token", "Digest" -> expected_ByteArray } ], token_String ] :=
    tokenMatchQ[ token, expected ];

authorizedQ[ KeyValuePattern[ { "Type" -> "Function", "Function" -> function_ } ], token_ ] :=
    CheckAll[ function @ token, Function[ { result, control }, control === Hold[ ] && result === True ] ];

authorizedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tokenMatchQ*)
(* Compares tokens in constant time: the time taken depends neither on where the tokens differ nor on their lengths,
   since only their SHA-256 digests are compared, and every byte of those. The expected token is given as its digest,
   which is all that a server record keeps of it, or as the token itself. *)
tokenMatchQ // beginDefinition;

tokenMatchQ[ token_String, expected_String ] :=
    tokenMatchQ[ token, tokenDigest @ expected ];

tokenMatchQ[ token_String, expected_ByteArray ] :=
    BitOr @@ BitXor[ Normal @ tokenDigest @ token, Normal @ expected ] === 0;

tokenMatchQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tokenDigest*)
(* The SHA-256 digest of a bearer token: what server records and jobs keep of tokens (see Server State). *)
tokenDigest // beginDefinition;
tokenDigest[ token_String ] := Hash[ token, "SHA256", "ByteArray" ];
tokenDigest[ None ] := None;
tokenDigest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*streamableQ*)
(* Whether the response to a deferred call can be streamed as Server-Sent Events: the client must ask for an event
   stream, and chunked transfer coding needs HTTP/1.1. *)
streamableQ // beginDefinition;
streamableQ[ request_Association, headers_Association ] := request[ "Version" ] === "HTTP/1.1" && acceptsEventStreamQ @ headers;
streamableQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*handleSocketRequest*)
(* Validates and dispatches one complete request whose head has been checked. Gives None when the request has been
   answered, the ID of a deferred call that will answer it later, or $Failed when the connection was closed (after an
   error response, or after an unexpected error). The data of internal failures never shows the request's bearer token
   (withFailureSecrets). *)
handleSocketRequest // beginDefinition;

handleSocketRequest[ server_Association, sock_SocketObject, request_Association ] :=
    Module[ { outcome },
        outcome = catchAlways @ withFailureSecrets[
            { request[ "Token" ] },
            Catch[ handleSocketRequest0[ server, sock, request ], $socketResponseTag ]
        ];
        If[ MatchQ[ outcome, None | _String | $Failed ],
            outcome,
            writeHTTPError[ sock, 500 ];
            $Failed
        ]
    ];

handleSocketRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handleSocketRequest0*)
(* The checks of the body, after those of the head (checkRequestHead). Each failed check Throws its result to
   $socketResponseTag. *)
handleSocketRequest0 // beginDefinition;

handleSocketRequest0[ server_, sock_, request_ ] :=
    Module[ { message },

        (* 6. A single JSON-RPC message; batches were removed from MCP in 2025-06-18. *)
        message = requestBodyJSON @ request;
        If[ message === $Failed, throwJSONRPCError[ sock, -32700, "Parse error" ] ];
        If[ ! AssociationQ @ message, throwJSONRPCError[ sock, -32600, "Invalid Request" ] ];

        (* 7. The negotiated protocol version on requests after initialize. *)
        If[ Lookup[ message, "method", None ] =!= "initialize" && ! supportedProtocolHeaderQ @ requestHeaders @ request,
            throwJSONRPCError[ sock, -32600, "Unsupported MCP-Protocol-Version" ]
        ];

        dispatchSocketMessage[ server, sock, request, message ]
    ];

handleSocketRequest0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*throwJSONRPCError*)
(* A 400 whose body is a JSON-RPC error, with the id of the message if it has a valid one. Like the refusals of request
   heads, it closes the connection: MCP clients never cause it. *)
throwJSONRPCError // beginDefinition;

throwJSONRPCError[ sock_, code_Integer, text_String ] :=
    throwJSONRPCError[ sock, code, text, Null ];

throwJSONRPCError[ sock_, code_Integer, text_String, id_ ] :=
    Throw[
        writeHTTPResponse[
            sock,
            400,
            { "Content-Type" -> "application/json" },
            makeResponseString[
                "application/json",
                <|
                    "jsonrpc" -> "2.0",
                    "id"      -> If[ StringQ @ id || NumberQ @ id, id, Null ],
                    "error"   -> <| "code" -> code, "message" -> text |>
                |>
            ],
            False
        ];
        $Failed,
        $socketResponseTag
    ];

throwJSONRPCError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*dispatchSocketMessage*)
(* Notifications and client responses get a 202 (see jsonRPCMessageType in HTTP.wl). Requests that run tool or prompt
   code are deferred; every other request is cheap and pure, so it is answered right here, in the handler. Anything
   else is not a JSON-RPC message: it gets an error with its id, since the client may be waiting for a response. *)
dispatchSocketMessage // beginDefinition;

dispatchSocketMessage[ server_, sock_, request_, message_Association ] :=
    Module[ { method, id, req },
        method = Lookup[ message, "method", None ];
        id     = Lookup[ message, "id", Null ];
        req    = <| "jsonrpc" -> "2.0", "id" -> id |>;
        Switch[ jsonRPCMessageType @ message,
            "Request",
                If[ MemberQ[ $deferredMethods, method ],
                    deferSocketRequest[ server, sock, request, method, message, req ],
                    answerSocketRequest[ server, sock, request, method, message, req ]
                ],
            "Notification" | "Response",
                acceptNotification[ server, sock, request, method, message, req ],
            _,
                throwJSONRPCError[ sock, -32600, "Invalid Request", id ]
        ]
    ];

dispatchSocketMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acceptNotification*)
(* Notifications are dispatched for their side effects (none, with roots disabled) like the cloud transport does. Only
   "notifications/..." methods are: a request that came without an id is accepted but never evaluated, since a tools/call
   must not run in the handler (or bypass the evaluation function). A JSON-RPC response from the client is accepted
   and ignored, since this server sends no requests. *)
acceptNotification // beginDefinition;

acceptNotification[ server_, sock_, request_, method_, message_, req_ ] := (
    If[ method === "notifications/cancelled", cancelSocketJobs[ server, request[ "Token" ], message ] ];
    If[ StringQ @ method && StringStartsQ[ method, "notifications/" ],
        withSocketRequestState[ server, catchAlways @ handleMethod[ method, message, req ] ]
    ];
    writeHTTPResponse[ sock, 202, { }, "", request[ "KeepAlive" ] ];
    None
);

acceptNotification // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*answerSocketRequest*)
answerSocketRequest // beginDefinition;

answerSocketRequest[ server_, sock_, request_, method_, message_, req_ ] :=
    With[ { response = withSocketRequestState[ server, catchAlways @ handleMethod[ method, message, req ] ] },
        writeJSONRPCResponse[
            sock,
            request[ "ContentType" ],
            If[ AssociationQ @ response, response, internalErrorResponse @ req ],
            request[ "KeepAlive" ]
        ];
        None
    ];

answerSocketRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withSocketRequestState*)
(* Evaluates a request with every server session global bound, so that nothing it does leaks into the kernel:
   handleMethod["initialize"] sets $clientName, $clientSupportsUI and $clientSupportsRoots, and tools read the tool
   options. UI resources (MCP Apps) and roots (server-to-client requests over stdout) stay disabled: mcpAppsEnabledQ is
   False too, since handleMethod["initialize"] sets $clientSupportsUI from it, and initialize would otherwise advertise
   the MCP Apps extension to clients that support it. $Messages is Blocked as well, since a front end kernel must never
   lose its messages. *)
withSocketRequestState // beginDefinition;
withSocketRequestState // Attributes = { HoldRest };

withSocketRequestState[ server_Association, eval_ ] :=
    With[ { serverState = server[ "State" ] },
        Block[
            {
                $MCPTransport             = "StreamableHTTP",
                $MCPEvaluationEnvironment = "Local",
                $currentMCPServer         = server[ "Server" ],
                $mcpEvaluation            = True,
                $clientName               = None,
                $clientSupportsUI         = False,
                $clientSupportsRoots      = False,
                mcpAppsEnabledQ           = False &,
                $logFile                  = None,
                $toolList                 = serverState[ "ToolList"     ],
                $llmTools                 = serverState[ "LLMTools"     ],
                $promptList               = serverState[ "PromptList"   ],
                $promptLookup             = serverState[ "PromptLookup" ],
                $toolOptions              = serverState[ "ToolOptions"  ],
                $Messages                 = $Messages
            },
            eval
        ]
    ];

withSocketRequestState // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Deferred Calls*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deferSocketRequest*)
(* Registers a tools/call or prompts/get request as a job and hands it to the server's evaluation function as
   f[run, info]. If the job is not finished when f returns, a client that accepts an event stream gets the response
   head at once and keep-alive comments until the job finishes; any other client waits for a JSON response. Requests
   for unknown tools or prompts and malformed parameters are answered at once instead. *)
deferSocketRequest // beginDefinition;

deferSocketRequest[ server_, sock_, request_, method_, message_, req_ ] :=
    Module[ { params, name, arguments },
        params    = Replace[ Lookup[ message, "params", <| |> ], Null -> <| |> ];
        name      = If[ AssociationQ @ params, Lookup[ params, "name", None ], None ];
        arguments = If[ AssociationQ @ params, Replace[ Lookup[ params, "arguments", <| |> ], Null -> <| |> ], None ];
        Which[
            ! StringQ @ name || ! AssociationQ @ arguments,
                answerSocketError[ sock, request, req, -32602, "Invalid params" ],

            (* evaluateTool answers unknown tools without running anything, so the handler can do it. *)
            method === "tools/call" && ! KeyExistsQ[ server[ "State", "LLMTools" ], name ],
                answerSocketRequest[ server, sock, request, method, message, req ],

            method === "prompts/get" && ! KeyExistsQ[ server[ "State", "PromptLookup" ], name ],
                answerSocketError[ sock, request, req, -32602, "Unknown prompt: " <> name ],

            True,
                startSocketJob[
                    server,
                    sock,
                    request,
                    <| message, "params" -> <| params, "arguments" -> arguments |> |>,
                    req
                ]
        ]
    ];

deferSocketRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*startSocketJob*)
startSocketJob // beginDefinition;

startSocketJob[ server_, sock_, request_, message_, req_ ] :=
    Module[ { jobID, job },
        jobID = CreateUUID[ ];
        job   = <|
            "ID"          -> jobID,
            "ServerID"    -> server[ "ID" ],
            "Socket"      -> sock,
            "Method"      -> message[ "method" ],
            "Name"        -> message[ "params", "name" ],
            "Arguments"   -> message[ "params", "arguments" ],
            "RequestID"   -> req[ "id" ],
            "Message"     -> message,
            (* for cancellations; only the evaluation function gets the token itself *)
            "TokenDigest" -> tokenDigest @ request[ "Token" ],
            "ReceivedAt"  -> AbsoluteTime[ ],
            "ContentType" -> request[ "ContentType" ],
            "Streamable"  -> request[ "Streamable" ],
            "Streaming"   -> False,
            "KeepAlive"   -> request[ "KeepAlive" ],
            "LastWrite"   -> AbsoluteTime[ ],
            "Status"      -> "Pending"
        |>;

        state`$jobs[ jobID ] = job;
        callEvaluationFunction[ server, jobID, socketJobInformation[ job, request[ "Token" ] ] ];

        If[ KeyExistsQ[ state`$jobs, jobID ],
            startJobResponse @ jobID,
            (* f already ran (or rejected) the call, which wrote the response *)
            None
        ]
    ];

startSocketJob // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*answerSocketError*)
answerSocketError // beginDefinition;

answerSocketError[ sock_, request_, req_, code_Integer, text_String ] := (
    writeJSONRPCResponse[
        sock,
        request[ "ContentType" ],
        <| req, "error" -> <| "code" -> code, "message" -> text |> |>,
        request[ "KeepAlive" ]
    ];
    None
);

answerSocketError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*socketJobInformation*)
(* The second argument of the evaluation function, with the request's bearer token (or None). *)
socketJobInformation // beginDefinition;

socketJobInformation[ job_Association, token_ ] :=
    With[ { jobID = job[ "ID" ] },
        <|
            "Method"     -> job[ "Method" ],
            "Name"       -> job[ "Name" ],
            "Arguments"  -> job[ "Arguments" ],
            "RequestID"  -> job[ "RequestID" ],
            "Token"      -> token,
            "Server"     -> state`$servers[ job[ "ServerID" ], "Object" ],
            "ReceivedAt" -> job[ "ReceivedAt" ],
            "Reject"     -> Function[ catchSocket @ rejectSocketJob[ jobID, ## ] ],
            "ActiveQ"    -> Function[ catchSocket @ socketJobActiveQ @ jobID ]
        |>
    ];

socketJobInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*callEvaluationFunction*)
(* f must return quickly, but it is user code: if it fails with a Throw or an Abort, the call is rejected rather than
   left waiting forever. *)
callEvaluationFunction // beginDefinition;

callEvaluationFunction[ server_Association, jobID_String, info_Association ] :=
    With[ { run = Function[ runSocketJob @ jobID ] },
        CheckAll[
            server[ "EvaluationFunction" ][ run, info ],
            Function[ { result, control },
                If[ control =!= Hold[ ], rejectSocketJob[ jobID, $evaluationFunctionFailText ] ];
                Null
            ]
        ]
    ];

callEvaluationFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*startJobResponse*)
(* Called in the handler once f has returned with the job still pending: starts the event stream if the client
   accepts one. Gives the job ID, which marks the connection as busy until the job finishes. *)
startJobResponse // beginDefinition;

startJobResponse[ jobID_String ] :=
    With[ { job = state`$jobs[ jobID ] },
        Which[
            ! TrueQ @ job[ "Streamable" ],
                jobID,
            FailureQ @ startEventStream[ job[ "Socket" ], job[ "KeepAlive" ] ],
                finishSocketJob[ jobID, Missing[ "Disconnected" ] ];
                None,
            True,
                state`$jobs[ jobID ] = <| job, "Streaming" -> True, "LastWrite" -> AbsoluteTime[ ] |>;
                jobID
        ]
    ];

startJobResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*runSocketJob*)
(* The run function of a deferred call (run[]): evaluates the call under the server's state Blocks, writes the
   response and gives it (the error that replaced it, if it could not be encoded). Does nothing and gives Null unless
   the job is still pending and its client still connected, so only the first call does anything. An abort (e.g. the
   user's Alt+.) while the call evaluates gives an error result instead of aborting run[]. Claiming the job and writing
   the response cannot be interrupted, so a claimed job is always answered, even when an abort arrives outside the
   evaluation of the call itself (it then propagates).

   An internal failure of the call's evaluation is answered with an internal error, which run[] gives. Only an internal
   failure while claiming or answering the call makes run[] give a Failure, and the call is finished all the same: a
   claimed call has been answered (or its connection closed, if no response could be written), and a call that could
   not be claimed is answered with an internal error (failSocketJob). So its client never waits for a response that
   will not come, and the call is no longer active once run[] returns. *)
runSocketJob // beginDefinition;

runSocketJob[ jobID_String ] :=
    With[ { result = catchSocket @ runSocketJob0 @ jobID },
        If[ FailureQ @ result, catchSocket @ failSocketJob @ jobID ];
        result
    ];

runSocketJob // endDefinition;


runSocketJob0 // beginDefinition;

runSocketJob0[ jobID_String ] :=
    Module[ { claimed, response = None },
        WithCleanup[
            claimed = PreemptProtect @ claimSocketJob @ jobID,
            If[ AssociationQ @ claimed, response = evaluateSocketJob[ claimed[ "Server" ], claimed[ "Job" ] ] ],
            If[ AssociationQ @ claimed,
                If[ ! AssociationQ @ response, response = abortedResponse[ claimed[ "Job" ] ] ];
                (* Nothing is sent for a call that was cancelled or rejected meanwhile, but its result is still given. *)
                With[ { sent = finishSocketJob[ jobID, response ] }, If[ AssociationQ @ sent, response = sent ] ]
            ]
        ];
        If[ AssociationQ @ claimed, response, Null ]
    ];

runSocketJob0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*failSocketJob*)
(* Answers a call that is still there after run[] failed with an internal error. *)
failSocketJob // beginDefinition;

failSocketJob[ jobID_String ] :=
    PreemptProtect @ With[ { job = Lookup[ state`$jobs, jobID, None ] },
        If[ AssociationQ @ job,
            finishSocketJob[ jobID, internalErrorResponse @ jobRequest @ job ]
        ];
        Null
    ];

failSocketJob // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*claimSocketJob*)
(* Marks a pending job as running. Gives <| "Job" -> ..., "Server" -> ... |>, or None if the job cannot run. *)
claimSocketJob // beginDefinition;

claimSocketJob[ jobID_String ] :=
    Module[ { job, server },
        job    = Lookup[ state`$jobs, jobID, None ];
        server = If[ AssociationQ @ job, Lookup[ state`$servers, job[ "ServerID" ], None ], None ];
        Which[
            ! AssociationQ @ job || job[ "Status" ] =!= "Pending" || ! AssociationQ @ server,
                None,
            ! socketConnectedQ[ server, job[ "Socket" ] ],
                finishSocketJob[ jobID, Missing[ "Disconnected" ] ];
                None,
            True,
                state`$jobs[ jobID, "Status" ] = "Running";
                <| "Job" -> job, "Server" -> server |>
        ]
    ];

claimSocketJob // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*evaluateSocketJob*)
evaluateSocketJob // beginDefinition;

evaluateSocketJob[ server_Association, job_Association ] :=
    With[ { req = jobRequest @ job },
        withSocketRequestState[
            server,
            CheckAbort[
                Replace[
                    catchAlways @ handleMethod[ job[ "Method" ], job[ "Message" ], req ],
                    Except[ _Association ] :> internalErrorResponse @ req
                ],
                abortedResponse[ job[ "Method" ], req ]
            ]
        ]
    ];

evaluateSocketJob // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*abortedResponse*)
abortedResponse // beginDefinition;
abortedResponse[ job_Association ] := abortedResponse[ job[ "Method" ], jobRequest @ job ];

abortedResponse[ method_String, req_Association ] :=
    jobErrorResponse[ method, req, If[ method === "tools/call", $abortedToolText, $abortedPromptText ] ];

abortedResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*jobErrorResponse*)
(* The response that ends a deferred call with an error text (aborted, rejected, server stopped, or not encodable): a
   tool result with "isError" -> True for tools/call, so that the model sees the text, or a JSON-RPC error for
   prompts/get. *)
jobErrorResponse // beginDefinition;

jobErrorResponse[ job_Association, text_String ] :=
    jobErrorResponse[ job[ "Method" ], jobRequest @ job, text ];

jobErrorResponse[ "tools/call", req_Association, text_String ] :=
    <| req, "result" -> <| "content" -> { <| "type" -> "text", "text" -> text |> }, "isError" -> True |> |>;

jobErrorResponse[ _String, req_Association, text_String ] :=
    <| req, "error" -> <| "code" -> -32603, "message" -> text |> |>;

jobErrorResponse // endDefinition;


(* The JSON-RPC envelope ("jsonrpc" and "id") of the response to a job's request. *)
jobRequest // beginDefinition;
jobRequest[ job_Association ] := <| "jsonrpc" -> "2.0", "id" -> job[ "RequestID" ] |>;
jobRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*rejectSocketJob*)
(* The Reject function of a deferred call: finishes it without running it (or while it runs, in which case its result
   is discarded). Gives the response that was sent, or Null if the job was no longer active. *)
rejectSocketJob // beginDefinition;

rejectSocketJob[ jobID_String, text_String ] :=
    PreemptProtect @ With[ { job = Lookup[ state`$jobs, jobID, None ] },
        If[ AssociationQ @ job,
            Replace[ finishSocketJob[ jobID, jobErrorResponse[ job, text ] ], Except[ _Association ] -> Null ],
            Null
        ]
    ];

rejectSocketJob[ jobID_String, text_ ] := rejectSocketJob[ jobID, TextString @ text ];

rejectSocketJob[ jobID_String ] := rejectSocketJob[ jobID, "The request was rejected." ];

rejectSocketJob // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*socketJobActiveQ*)
(* The ActiveQ function of a deferred call: False once it has been answered, rejected or cancelled, its server
   stopped, or its client disconnected. *)
socketJobActiveQ // beginDefinition;

socketJobActiveQ[ jobID_String ] :=
    With[ { job = Lookup[ state`$jobs, jobID, None ] },
        AssociationQ @ job && With[ { server = Lookup[ state`$servers, job[ "ServerID" ], None ] },
            AssociationQ @ server && socketConnectedQ[ server, job[ "Socket" ] ]
        ]
    ];

socketJobActiveQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cancelSocketJobs*)
(* notifications/cancelled finishes the matching calls without a response. JSON-RPC IDs are only unique per client,
   so a call only matches when it came with the same bearer token. A running call keeps running, but its result is
   discarded. *)
cancelSocketJobs // beginDefinition;

cancelSocketJobs[ server_Association, token_, message_Association ] :=
    With[
        {
            requestID = Replace[ message[ "params" ], { KeyValuePattern[ "requestId" -> id_ ] :> id, _ :> Missing[ ] } ],
            digest    = tokenDigest @ token
        },
        If[ ! MissingQ @ requestID,
            Scan[
                finishSocketJob[ #, Missing[ "Cancelled" ] ] &,
                Keys @ Select[ serverJobs @ server[ "ID" ], #[ "RequestID" ] === requestID && #[ "TokenDigest" ] === digest & ]
            ]
        ]
    ];

cancelSocketJobs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*finishSocketJob*)
(* Ends a job: removes it, answers its request according to the outcome, and frees its connection. The outcome is the
   JSON-RPC response to send, Missing["Cancelled"] (finish the HTTP response without a JSON-RPC response) or
   Missing["Disconnected"] (nothing can be sent). A client that waits for the job must always get an answer, so
   nothing interrupts this, a response is encoded before anything is written (encodeJobOutcome), and a connection
   whose response could not be written is closed, so that its client fails at once. Gives the outcome that was sent,
   or None if the job was no longer there. *)
finishSocketJob // beginDefinition;

finishSocketJob[ jobID_String, outcome_ ] :=
    PreemptProtect @ AbortProtect @ Module[ { job, sent, body, written = $Failed },
        job = Lookup[ state`$jobs, jobID, None ];
        If[ AssociationQ @ job,
            KeyDropFrom[ state`$jobs, jobID ];
            WithCleanup[
                { sent, body } = encodeJobOutcome[ job, outcome ];
                written = writeJobOutcome[ job, sent, body ],
                If[ FailureQ @ written, closeJobConnection @ job, releaseConnection[ job, sent ] ]
            ];
            sent,
            None
        ]
    ];

finishSocketJob // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*encodeJobOutcome*)
(* Gives { outcome, body }: a response with its encoded body, in which a response that cannot be encoded as JSON (a
   tool result can hold values that JSON cannot represent, such as Missing[]) is replaced by an error; or a Missing
   outcome with no body. *)
encodeJobOutcome // beginDefinition;

encodeJobOutcome[ job_Association, response_Association ] :=
    encodeJSONRPCResponse[
        If[ TrueQ @ job[ "Streaming" ], "text/event-stream", job[ "ContentType" ] ],
        response,
        jobErrorResponse[ job, $encodingFailedText ]
    ];

encodeJobOutcome[ _Association, outcome: Missing[ "Cancelled" | "Disconnected" ] ] :=
    { outcome, None };

encodeJobOutcome // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeJobOutcome*)
(* Gives the result of the write (a Failure once the client is gone), or Null if there is nothing to write. *)
writeJobOutcome // beginDefinition;

writeJobOutcome[ job_Association, _Association, body_String ] :=
    If[ TrueQ @ job[ "Streaming" ],
        endEventStream[ job[ "Socket" ], body, job[ "KeepAlive" ] ],
        writeJSONRPCBody[ job[ "Socket" ], job[ "ContentType" ], body, job[ "KeepAlive" ] ]
    ];

(* A cancelled request gets no JSON-RPC response: end the event stream, or accept the request without a body. *)
writeJobOutcome[ job_Association, Missing[ "Cancelled" ], None ] :=
    If[ TrueQ @ job[ "Streaming" ],
        endEventStream[ job[ "Socket" ], None, job[ "KeepAlive" ] ],
        writeHTTPResponse[ job[ "Socket" ], 202, { }, "", job[ "KeepAlive" ] ]
    ];

writeJobOutcome[ _Association, Missing[ "Disconnected" ], None ] := Null;

writeJobOutcome // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*releaseConnection*)
(* Frees the connection that waited for a job and reads the requests that arrived on it in the meantime. The held bytes
   are read chunk by chunk, as the handler received them (at most 8 KB each), rather than joined: framing rescans the
   unread part of its buffer for every request, which would take quadratic time for many requests held behind a call.
   Once a chunk makes the connection wait for another call, the next chunks are held again (feedConnection), and once
   it closes the connection, they are dropped. *)
releaseConnection // beginDefinition;

releaseConnection[ job_Association, outcome_ ] :=
    Module[ { sock, conn, server },
        sock   = job[ "Socket" ];
        conn   = Lookup[ state`$connections, sock, None ];
        server = Lookup[ state`$servers, job[ "ServerID" ], None ];
        If[ AssociationQ @ conn && conn[ "Busy" ] === job[ "ID" ],
            If[ AssociationQ @ server && TrueQ @ job[ "KeepAlive" ] && outcome =!= Missing[ "Disconnected" ],
                state`$connections[ sock ] = <| conn, "Busy" -> None, "Held" -> { } |>;
                Scan[
                    If[ KeyExistsQ[ state`$connections, sock ], receiveBytes[ server, sock, # ] ] &,
                    conn[ "Held" ]
                ],
                KeyDropFrom[ state`$connections, sock ]
            ]
        ]
    ];

releaseConnection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*closeJobConnection*)
(* Closes the connection of a job whose response could not be written, and forgets it if it waited for the job. *)
closeJobConnection // beginDefinition;

closeJobConnection[ job_Association ] := (
    If[ MatchQ[ Lookup[ state`$connections, job[ "Socket" ], None ], KeyValuePattern[ "Busy" -> job[ "ID" ] ] ],
        KeyDropFrom[ state`$connections, job[ "Socket" ] ]
    ];
    closeSocket @ job[ "Socket" ]
);

closeJobConnection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serverJobs*)
serverJobs // beginDefinition;
serverJobs[ id_String ] := Select[ state`$jobs, #[ "ServerID" ] === id & ];
serverJobs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Maintenance*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*socketMaintenanceTask*)
(* The body of a server's recurring task. Like the handler, it must never let anything escape. *)
socketMaintenanceTask // beginDefinition;

socketMaintenanceTask[ id_String ] :=
    AbortProtect @ CheckAll[ catchSocket @ socketMaintenance @ id, Null & ];

socketMaintenanceTask // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*socketMaintenance*)
(* Finishes the jobs of clients that left, forgets their connections, closes connections whose requests stalled, and
   keeps event streams alive. *)
socketMaintenance // beginDefinition;

socketMaintenance[ id_String ] :=
    With[ { server = recordMaintenancePass @ id },
        If[ AssociationQ @ server,
            With[ { clients = connectedClients @ server },
                If[ ListQ @ clients,
                    Scan[
                        If[ ! MemberQ[ clients, #[ "Socket" ] ], finishSocketJob[ #[ "ID" ], Missing[ "Disconnected" ] ] ] &,
                        Values @ serverJobs @ id
                    ];
                    purgeConnections[ server, clients ]
                ]
            ];
            closeStalledConnections @ server;
            writeKeepAlives @ server
        ];
        Null
    ];

socketMaintenance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*recordMaintenancePass*)
(* Records the time of a maintenance pass in the server's record and gives the record, or None if the server is not
   running. A pass that comes much later than the task's interval shows that the kernel could not run preemptive
   evaluations for a while (e.g. during a long PreemptProtect or native computation on the main link of a front end
   kernel), and so neither the server's handlers: bytes that arrived meanwhile may still wait for the handler, which
   can run after this pass. The pass then records its time as "StallEnded" (see closeStalledConnections). *)
recordMaintenancePass // beginDefinition;

recordMaintenancePass[ id_String ] :=
    With[ { server = Lookup[ state`$servers, id, None ], now = AbsoluteTime[ ] },
        If[ AssociationQ @ server,
            (* Records from an older version of this paclet have no "LastMaintenance": the pass counts as late. *)
            If[ now - Lookup[ server, "LastMaintenance", 0 ] > $lateMaintenanceFactor * server[ "MaintenanceInterval" ],
                state`$servers[ id, "StallEnded" ] = now
            ];
            state`$servers[ id, "LastMaintenance" ] = now;
            state`$servers[ id ],
            None
        ]
    ];

recordMaintenancePass // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*closeStalledConnections*)
(* A request whose head or body has received no bytes for $requestTimeout seconds gets a 408, and its connection is
   closed: MCP clients send each request at once, and a partial request holds on to its buffer. Idle connections
   between requests are kept (clients reuse them), and so are connections that wait for a deferred call. Time during
   which the kernel could not run the handler is not the client's: the bytes of a request that arrived meanwhile wait
   for the handler, which can run after this pass. So the time is counted from the end of the kernel's last stall
   ("StallEnded", see recordMaintenancePass) if that is later than the last bytes. *)
closeStalledConnections // beginDefinition;

closeStalledConnections[ server_Association ] :=
    With[
        {
            id    = server[ "ID" ],
            due   = AbsoluteTime[ ] - $requestTimeout,
            since = Lookup[ server, "StallEnded", 0 ]
        },
        KeyValueMap[
            Function[ { sock, conn },
                If[ conn[ "ServerID" ] === id && partialRequestQ @ conn && TrueQ[ Max[ conn[ "LastData" ], since ] < due ],
                    writeHTTPError[ sock, 408 ];
                    KeyDropFrom[ state`$connections, sock ]
                ]
            ],
            state`$connections
        ];
        Null
    ];

closeStalledConnections // endDefinition;


partialRequestQ // beginDefinition;

partialRequestQ[ conn_Association ] :=
    conn[ "Busy" ] === None && (conn[ "Request" ] =!= None || Length @ conn[ "Head" ] > 0);

partialRequestQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeKeepAlives*)
(* Sends an SSE comment on every event stream that has been silent for about the keep-alive interval: Bun's fetch
   (OpenCode) fails a request that receives no bytes for about five minutes. *)
writeKeepAlives // beginDefinition;

writeKeepAlives[ server_Association ] :=
    With[ { interval = server[ "KeepAliveInterval" ] },
        If[ interval =!= None,
            With[ { due = AbsoluteTime[ ] - interval + server[ "MaintenanceInterval" ] / 2 },
                Scan[
                    If[ TrueQ @ #[ "Streaming" ] && #[ "LastWrite" ] <= due, writeKeepAlive @ #[ "ID" ] ] &,
                    Values @ serverJobs @ server[ "ID" ]
                ]
            ]
        ]
    ];

writeKeepAlives // endDefinition;


writeKeepAlive // beginDefinition;

writeKeepAlive[ jobID_String ] :=
    With[ { job = Lookup[ state`$jobs, jobID, None ] },
        Which[
            ! AssociationQ @ job,
                Null,
            FailureQ @ writeSocket[ job[ "Socket" ], eventStreamChunk[ ": keepalive\n\n" ] ],
                finishSocketJob[ jobID, Missing[ "Disconnected" ] ],
            True,
                state`$jobs[ jobID, "LastWrite" ] = AbsoluteTime[ ]
        ]
    ];

writeKeepAlive // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Writing Responses*)
(* Every response is written as a single ByteArray with SocketWriteMessage, which never blocks and gives a Failure
   (without a message) only when the client is gone. WriteString would drop data silently. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeHTTPResponse*)
writeHTTPResponse // beginDefinition;

writeHTTPResponse[ sock_SocketObject, status_Integer, headers_List, body_, keepAlive_ ] :=
    Module[ { bytes, head, result },
        bytes = toBytes @ body;
        head  = StringJoin[
            "HTTP/1.1 ", ToString @ status, " ", Lookup[ $httpReasons, status, "Unknown" ], "\r\n",
            #1 <> ": " <> #2 <> "\r\n" & @@@ headers,
            "Content-Length: ", ToString @ Length @ bytes, "\r\n",
            connectionHeader @ keepAlive,
            "\r\n"
        ];
        result = writeSocket[ sock, Join[ StringToByteArray[ head, "ISO8859-1" ], bytes ] ];
        If[ ! TrueQ @ keepAlive, closeSocket @ sock ];
        result
    ];

writeHTTPResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeHTTPError*)
(* Error responses for requests that cannot be framed (or that stalled); the connection is closed. *)
writeHTTPError // beginDefinition;

writeHTTPError[ sock_SocketObject, status_Integer ] :=
    writeHTTPResponse[ sock, status, { "Content-Type" -> "text/plain; charset=utf-8" }, Lookup[ $httpReasons, status, "Error" ], False ];

writeHTTPError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeJSONRPCResponse*)
(* A JSON-RPC response in the negotiated media type: JSON, or a single event for clients that only accept an event
   stream. A response that cannot be encoded is answered with an internal error. *)
writeJSONRPCResponse // beginDefinition;

writeJSONRPCResponse[ sock_, type_String, response_Association, keepAlive_ ] :=
    writeJSONRPCBody[
        sock,
        type,
        Last @ encodeJSONRPCResponse[ type, response, internalErrorResponse @ KeyTake[ response, { "jsonrpc", "id" } ] ],
        keepAlive
    ];

writeJSONRPCResponse // endDefinition;


writeJSONRPCBody // beginDefinition;

writeJSONRPCBody[ sock_, "application/json", body_String, keepAlive_ ] :=
    writeHTTPResponse[ sock, 200, { "Content-Type" -> "application/json" }, body, keepAlive ];

writeJSONRPCBody[ sock_, "text/event-stream", body_String, keepAlive_ ] :=
    writeHTTPResponse[ sock, 200, { "Content-Type" -> "text/event-stream", "Cache-Control" -> "no-cache" }, body, keepAlive ];

writeJSONRPCBody // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*encodeJSONRPCResponse*)
(* Encodes a JSON-RPC response for a media type: compact JSON, or a single event for an event stream. A response that
   cannot be encoded is replaced by the fallback, which always can be. Gives { response, body }, with the response that
   was encoded. The messages of a failed encoding are expected here, so they are quieted. *)
encodeJSONRPCResponse // beginDefinition;

encodeJSONRPCResponse[ type_String, response_Association, fallback_Association ] := Enclose[
    Module[ { body },
        body = Quiet @ jsonRPCBody[ type, response ];
        If[ StringQ @ body,
            { response, body },
            { fallback, ConfirmBy[ jsonRPCBody[ type, fallback ], StringQ, "Fallback" ] }
        ]
    ],
    throwInternalFailure
];

encodeJSONRPCResponse // endDefinition;


jsonRPCBody // beginDefinition;
jsonRPCBody[ "application/json" , response_ ] := makeResponseString[ "application/json", response ];
jsonRPCBody[ "text/event-stream", response_ ] := sseMessageEvent @ response;
jsonRPCBody // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sseMessageEvent*)
(* A JSON-RPC message as a Server-Sent Events "message" event. Compact JSON has no line breaks, so it fits on a single
   data line. Events never carry an id: the client would try to resume a broken stream with a GET request. *)
sseMessageEvent // beginDefinition;
sseMessageEvent[ response_Association ] := "event: message\n" <> makeResponseString[ "text/event-stream", response ];
sseMessageEvent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Event Streams*)
(* The response to a deferred call that is still running is an event stream in chunked transfer coding, so that the
   connection can be used again once the stream ends with the terminal chunk. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*startEventStream*)
startEventStream // beginDefinition;

startEventStream[ sock_SocketObject, keepAlive_ ] :=
    writeSocket[
        sock,
        StringToByteArray[
            StringJoin[
                "HTTP/1.1 200 OK\r\n",
                "Content-Type: text/event-stream\r\n",
                "Cache-Control: no-cache\r\n",
                "Transfer-Encoding: chunked\r\n",
                connectionHeader @ keepAlive,
                "\r\n"
            ],
            "ISO8859-1"
        ]
    ];

startEventStream // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*eventStreamChunk*)
eventStreamChunk // beginDefinition;

eventStreamChunk[ data_String ] :=
    With[ { bytes = StringToByteArray[ data, "UTF-8" ] },
        Join[ StringToByteArray[ IntegerString[ Length @ bytes, 16 ] <> "\r\n" ], bytes, StringToByteArray[ "\r\n" ] ]
    ];

eventStreamChunk // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*endEventStream*)
(* Writes the last event, if any, and the terminal chunk. A stream must never end without the response of a call that
   the client still waits for (it would wait forever), so only cancelled calls end without an event. *)
endEventStream // beginDefinition;

endEventStream[ sock_SocketObject, event: _String | None, keepAlive_ ] :=
    With[
        {
            result = writeSocket[
                sock,
                Join[
                    If[ StringQ @ event, eventStreamChunk @ event, ByteArray[ { } ] ],
                    StringToByteArray[ "0\r\n\r\n" ]
                ]
            ]
        },
        If[ ! TrueQ @ keepAlive, closeSocket @ sock ];
        result
    ];

endEventStream // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*connectionHeader*)
(* Without the Keep-Alive hint, Node's fetch drops idle connections after about four seconds. Persistent connections
   matter: in 15.0, every accepted connection leaks a few file descriptors. "Connection: keep-alive" is what tells an
   HTTP/1.0 client that asked for a persistent connection that it has one (HTTP/1.1 connections are persistent anyway). *)
connectionHeader // beginDefinition;
connectionHeader[ True  ] := "Connection: keep-alive\r\nKeep-Alive: timeout=" <> ToString @ $keepAliveTimeout <> "\r\n";
connectionHeader[ _     ] := "Connection: close\r\n";
connectionHeader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toBytes*)
toBytes // beginDefinition;
toBytes[ bytes_ByteArray ] := bytes;
toBytes[ string_String ] := StringToByteArray[ string, "UTF-8" ];
toBytes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeSocket*)
writeSocket // beginDefinition;
writeSocket[ sock_SocketObject, bytes_ByteArray ] := Quiet @ SocketWriteMessage[ sock, bytes ];
writeSocket // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*closeSocket*)
(* Close delivers what was written before it. *)
closeSocket // beginDefinition;
closeSocket[ sock_SocketObject ] := (Quiet @ Close @ sock; Null);
closeSocket // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
