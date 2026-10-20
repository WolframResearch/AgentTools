(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* Some tests give the server functions that Throw on purpose: *)
(* :!CodeAnalysis::Disable::NoSurroundingCatch:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/SocketServer.wlt:9,1-14,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/SocketServer.wlt:16,1-21,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Fixtures*)
(* These tests drive real servers with loopback TCP clients from this kernel: the SocketListen handlers fire while a
   test waits for a response (Pause, SocketReadyQ). *)

(* An in-memory server, as Chatbook builds one: a few tools, a prompt and instructions. *)
$socketTestServerObject = MCPServerObject @ <|
    "Name"         -> "SocketServerTest",
    "Location"     -> None,
    "LLMEvaluator" -> <|
        "Tools" -> {
            LLMTool[ "Echo"   , { "text" -> "String" }, #text & ],
            LLMTool[ "Aborter", { }, (Abort[ ]; "unreachable") & ],
            LLMTool[ "Sleep"  , { "seconds" -> "Number" }, (Pause[ #seconds ]; "done") & ]
        },
        "MCPPrompts" -> { <| "Name" -> "Greeting", "Description" -> "A greeting", "Content" -> "Hello!" |> },
        "Prompts"    -> "Instructions for the socket server test."
    |>
|>;

(* A tool whose result cannot be encoded as JSON (Missing[] has no JSON representation). *)
$socketEncodingTestServerObject = MCPServerObject @ <|
    "Name"         -> "SocketServerEncodingTest",
    "Location"     -> None,
    "LLMEvaluator" -> <| "Tools" -> {
        LLMTool[ "BadContent", { }, <| "Content" -> { <| "type" -> "text", "text" -> "x", "annotations" -> Missing[ ] |> } |> & ]
    } |>
|>;

$socketEncodingFailedResult = <|
    "content" -> { <| "type" -> "text", "text" -> "The result of this call could not be encoded as JSON." |> },
    "isError" -> True
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Requests*)
socketTestBody[ method_String, id_: None, params_: <| |> ] := Developer`WriteRawJSONString[
    Association[ "jsonrpc" -> "2.0", If[ id === None, Nothing, "id" -> id ], "method" -> method, "params" -> params ],
    "Compact" -> True
];

(* The bytes of an HTTP request. The default headers are those of an MCP client (OpenCode); "Headers" replaces
   or removes (value None) them by name. *)
Options[ socketTestRequest ] = {
    "Method"  -> "POST",
    "Target"  -> Automatic,
    "Version" -> "HTTP/1.1",
    "Headers" -> { }
};

socketTestRequest[ server_, body_String, opts: OptionsPattern[ ] ] :=
    Module[ { bytes, defaults, headers, head },
        bytes    = StringToByteArray[ body, "UTF-8" ];
        defaults = <|
            "Host"           -> "127.0.0.1:" <> ToString @ server[ "Port" ],
            "Authorization"  -> If[ StringQ @ server[ "Token" ], "Bearer " <> server[ "Token" ], None ],
            "Accept"         -> "application/json, text/event-stream",
            "Content-Type"   -> "application/json",
            "Content-Length" -> ToString @ Length @ bytes
        |>;
        headers = DeleteCases[ <| defaults, Association @ OptionValue[ "Headers" ] |>, None ];
        head    = StringJoin[
            OptionValue[ "Method" ], " ",
            Replace[ OptionValue[ "Target" ], Automatic :> server[ "Path" ] <> "?codemode=false" ], " ",
            OptionValue[ "Version" ], "\r\n",
            KeyValueMap[ #1 <> ": " <> #2 <> "\r\n" &, headers ],
            "\r\n"
        ];
        Join[ StringToByteArray[ head, "ISO8859-1" ], bytes ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Clients*)
$socketTestBuffers = <| |>;

socketTestConnect[ server_ ] :=
    With[ { client = SocketConnect[ { "127.0.0.1", server[ "Port" ] }, "TCP" ] },
        $socketTestBuffers[ client ] = ByteArray[ { } ];
        client
    ];

socketTestClose[ client_ ] := (KeyDropFrom[ $socketTestBuffers, client ]; Quiet @ Close @ client; Null);

socketTestSend[ client_, bytes_ByteArray ] := BinaryWrite[ client, bytes ];

(* Moves the bytes that have arrived into the client's buffer, or waits a little. *)
socketTestPump[ client_ ] :=
    If[ SocketReadyQ @ client,
        With[ { bytes = Quiet @ SocketReadMessage @ client },
            If[ ByteArrayQ @ bytes, $socketTestBuffers[ client ] = Join[ $socketTestBuffers[ client ], bytes ] ]
        ],
        Pause[ 0.01 ]
    ];

socketTestBufferString[ client_ ] := ByteArrayToString[ $socketTestBuffers[ client ], "ISO8859-1" ];

(* Waits until the client has received a string (without consuming it). *)
socketTestWaitFor[ client_, text_String, timeout_: 5 ] :=
    Module[ { t0 = AbsoluteTime[ ] },
        While[ ! StringContainsQ[ socketTestBufferString @ client, text ] && AbsoluteTime[ ] - t0 < timeout,
            socketTestPump @ client
        ];
        StringContainsQ[ socketTestBufferString @ client, text ]
    ];

(* Waits for nothing to arrive for a while; gives the bytes that did arrive (without consuming them). *)
socketTestQuiet[ client_, seconds_ ] :=
    Module[ { t0 = AbsoluteTime[ ] },
        While[ AbsoluteTime[ ] - t0 < seconds, socketTestPump @ client ];
        socketTestBufferString @ client
    ];

(* Reads one complete response (consuming it), or gives $TimedOut. *)
socketTestRead[ client_, timeout_: 5 ] :=
    Module[ { t0 = AbsoluteTime[ ], parsed },
        While[ ! AssociationQ[ parsed = socketTestParse @ $socketTestBuffers @ client ] && AbsoluteTime[ ] - t0 < timeout,
            socketTestPump @ client
        ];
        If[ AssociationQ @ parsed,
            $socketTestBuffers[ client ] = Drop[ $socketTestBuffers[ client ], parsed[ "Length" ] ];
            parsed,
            $TimedOut
        ]
    ];

(* Sends a request on a new connection and reads the response. *)
socketTestExchange[ server_, body_String, opts: OptionsPattern[ socketTestRequest ] ] :=
    Module[ { client, response },
        client = socketTestConnect @ server;
        socketTestSend[ client, socketTestRequest[ server, body, opts ] ];
        response = socketTestRead @ client;
        socketTestClose @ client;
        response
    ];

socketTestStatus[ server_, body_String, opts: OptionsPattern[ socketTestRequest ] ] :=
    Replace[ socketTestExchange[ server, body, opts ], r_Association :> r[ "Status" ] ];

socketTestJSON[ server_, body_String, opts: OptionsPattern[ socketTestRequest ] ] :=
    Replace[ socketTestExchange[ server, body, opts ], r_Association :> r[ "JSON" ] ];

(* Polls a condition while handlers and tasks run. *)
socketTestEventually[ condition_, timeout_: 5 ] :=
    Module[ { t0 = AbsoluteTime[ ] },
        While[ ! TrueQ @ condition && AbsoluteTime[ ] - t0 < timeout, Pause[ 0.02 ] ];
        TrueQ @ condition
    ];

SetAttributes[ socketTestEventually, HoldFirst ];

(* Runs a server's maintenance pass now, with a shortened request timeout and the given end of the kernel's last stall,
   as a pass on time: the server's own task cannot run in between, and a late pass would itself find a stall (see
   recordMaintenancePass). *)
socketTestMaintenance[ server_, timeout_, stallEnded_: 0 ] :=
    PreemptProtect[
        Wolfram`AgentToolsState`SocketServer`$servers[ server[ "ID" ], "LastMaintenance" ] = AbsoluteTime[ ];
        Wolfram`AgentToolsState`SocketServer`$servers[ server[ "ID" ], "StallEnded"      ] = stallEnded;
        Block[ { Wolfram`AgentTools`Server`Socket`Private`$requestTimeout = timeout },
            Wolfram`AgentTools`Server`Socket`Private`socketMaintenance @ server[ "ID" ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Response Parsing*)
(* Parses one HTTP response from the start of the bytes, or gives None if it is not complete. "Length" is the number
   of bytes it used, "JSON" the JSON-RPC message (the body, or the data of the event stream's message event). *)
socketTestParse[ bytes_ByteArray ] :=
    Catch @ Module[ { text, end, lines, status, headers, rest, body, length, events },
        text = ByteArrayToString[ bytes, "ISO8859-1" ];
        end  = StringPosition[ text, "\r\n\r\n", 1 ];
        If[ end === { }, Throw @ None ];
        end     = end[[ 1, 2 ]];
        lines   = StringSplit[ StringTake[ text, end - 4 ], "\r\n" ];
        status  = ToExpression @ StringSplit[ First @ lines ][[ 2 ]];
        headers = Association @ Map[ ToLowerCase @ StringTrim @ #[[ 1 ]] -> StringTrim @ #[[ 2 ]] &, StringSplit[ Rest @ lines, ":", 2 ] ];
        rest    = Drop[ bytes, end ];
        Which[
            KeyExistsQ[ headers, "content-length" ],
                length = ToExpression @ headers[ "content-length" ];
                If[ Length @ rest < length, Throw @ None ];
                body = Take[ rest, length ];
                length = end + length,
            ToLowerCase @ Lookup[ headers, "transfer-encoding", "" ] === "chunked",
                { body, length } = Replace[ socketTestDechunk @ rest, None :> Throw @ None ];
                length = end + length,
            True,
                body = ByteArray[ { } ];
                length = end
        ];
        body   = ByteArrayToString[ body, "UTF-8" ];
        events = If[ StringStartsQ[ Lookup[ headers, "content-type", "" ], "text/event-stream" ], socketTestEvents @ body, None ];
        <|
            "Status"  -> status,
            "Headers" -> headers,
            "Body"    -> body,
            "Events"  -> events,
            "JSON"    -> socketTestMessage[ body, events ],
            "Length"  -> length
        |>
    ];

(* Decodes a chunked body: { body bytes, bytes used }, or None if the terminal chunk has not arrived. *)
socketTestDechunk[ bytes_ByteArray ] :=
    Catch @ Module[ { pos = 0, chunks = { }, text, lineEnd, size },
        While[ True,
            text    = ByteArrayToString[ Drop[ bytes, pos ], "ISO8859-1" ];
            lineEnd = StringPosition[ text, "\r\n", 1 ];
            If[ lineEnd === { }, Throw @ None ];
            size = FromDigits[ StringTake[ text, lineEnd[[ 1, 1 ]] - 1 ], 16 ];
            pos  = pos + lineEnd[[ 1, 2 ]];
            If[ Length @ bytes < pos + size + 2, Throw @ None ];
            If[ size === 0, Throw @ { Join[ ByteArray[ { } ], Sequence @@ chunks ], pos + 2 } ];
            AppendTo[ chunks, Take[ bytes, { pos + 1, pos + size } ] ];
            pos = pos + size + 2
        ]
    ];

(* The events of an event stream: comments as "Comment" events, the rest with their "event" and "data" fields. *)
socketTestEvents[ body_String ] :=
    Map[
        Function[ block,
            If[ StringStartsQ[ block, ":" ],
                <| "Comment" -> StringTrim @ StringDrop[ block, 1 ] |>,
                Association @ Map[ StringTrim /@ Rule @@ StringSplit[ #, ":", 2 ] &, StringSplit[ block, "\n" ] ]
            ]
        ],
        StringSplit[ body, "\n\n" ]
    ];

socketTestMessage[ body_String, None ] := Quiet @ Developer`ReadRawJSONString @ body;

socketTestMessage[ _, events_List ] :=
    Replace[
        Cases[ events, KeyValuePattern[ "data" -> data_String ] :> data ],
        { { ___, data_ } :> Quiet @ Developer`ReadRawJSONString @ data, _ :> None }
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Global State*)
(* The kernel state that a request must leave alone. *)
socketTestGlobals[ ] := {
    $Messages,
    $Line,
    $MCPTransport,
    $MCPEvaluationEnvironment,
    Wolfram`AgentTools`Server`$clientName,
    Wolfram`AgentTools`Server`$currentMCPServer,
    Wolfram`AgentTools`Common`$clientSupportsUI,
    Wolfram`AgentTools`Common`$clientSupportsRoots,
    Wolfram`AgentTools`Common`$mcpEvaluation,
    Wolfram`AgentTools`Common`$toolOptions
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Exports*)
VerificationTest[
    AllTrue[
        { "Wolfram`AgentTools`StartMCPSocketServer", "Wolfram`AgentTools`MCPSocketServerObject" },
        MemberQ[ Wolfram`AgentTools`$AgentToolsProtectedNames, # ] &
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Exports-Protected@@Tests/SocketServer.wlt:284,1-292,2"
]

VerificationTest[
    MatchQ[ DownValues @ StartMCPSocketServer, { __ } ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Exports-HasDefinition@@Tests/SocketServer.wlt:294,1-299,2"
]

VerificationTest[
    Options @ StartMCPSocketServer,
    {
        "Authentication"     -> Automatic,
        "EvaluationFunction" -> Automatic,
        "KeepAliveInterval"  -> 15,
        "Path"               -> "/mcp",
        "Port"               -> Automatic,
        "ToolOptions"        -> Automatic
    },
    SameTest -> MatchQ,
    TestID   -> "Exports-Options@@Tests/SocketServer.wlt:301,1-313,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Pure Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parseRequestHead*)
VerificationTest[
    Wolfram`AgentTools`Server`Socket`Private`parseRequestHead[
        "POST /mcp?codemode=false HTTP/1.1\r\nHost: 127.0.0.1:1234\r\nContent-Length: 12\r\nX-Twice: a\r\nx-twice: b"
    ],
    KeyValuePattern @ {
        "Method"        -> "POST",
        "Target"        -> "/mcp?codemode=false",
        "Path"          -> "/mcp",
        "Version"       -> "HTTP/1.1",
        "Headers"       -> <| "host" -> "127.0.0.1:1234", "content-length" -> "12", "x-twice" -> "a, b" |>,
        "ContentLength" -> 12,
        "KeepAlive"     -> True
    },
    SameTest -> MatchQ,
    TestID   -> "ParseRequestHead-Valid@@Tests/SocketServer.wlt:322,1-337,2"
]

VerificationTest[
    Lookup[
        Wolfram`AgentTools`Server`Socket`Private`parseRequestHead /@ {
            "POST /mcp HTTP/1.1\r\nConnection: close",
            "POST /mcp HTTP/1.1\r\nConnection: keep-alive, Upgrade",
            "POST /mcp HTTP/1.0",
            "POST /mcp HTTP/1.0\r\nConnection: Keep-Alive"
        },
        "KeepAlive"
    ],
    { False, True, False, True },
    SameTest -> MatchQ,
    TestID   -> "ParseRequestHead-KeepAlive@@Tests/SocketServer.wlt:339,1-352,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Socket`Private`parseRequestHead /@ {
        "",
        "GARBAGE",
        "POST /mcp HTTP/2.0",
        "POST /mcp HTTP/1.1\r\nContent-Length: -1",
        "POST /mcp HTTP/1.1\r\nContent-Length: 5\r\nContent-Length: 5",
        "POST /mcp HTTP/1.1\r\nTransfer-Encoding: chunked"
    },
    { 400, 400, 400, 400, 400, 501 },
    SameTest -> MatchQ,
    TestID   -> "ParseRequestHead-Errors@@Tests/SocketServer.wlt:354,1-366,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*headEnd*)
VerificationTest[
    Wolfram`AgentTools`Server`Socket`Private`headEnd /@ StringToByteArray /@ { "GET / HTTP/1.1\r\n\r\nbody", "GET / HTTP/1.1\r\n" },
    { 18, None },
    SameTest -> MatchQ,
    TestID   -> "HeadEnd@@Tests/SocketServer.wlt:371,1-376,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Authentication*)
VerificationTest[
    Wolfram`AgentTools`Server`Socket`Private`bearerToken /@ { "Bearer abc", "bearer  abc ", "Basic abc", "Bearer", "Bearer a b", None },
    { "abc", "abc", None, None, None, None },
    SameTest -> MatchQ,
    TestID   -> "BearerToken@@Tests/SocketServer.wlt:381,1-386,2"
]

VerificationTest[
    {
        Wolfram`AgentTools`Server`Socket`Private`tokenMatchQ[ "secret", "secret" ],
        Wolfram`AgentTools`Server`Socket`Private`tokenMatchQ[ "secret", "secreT" ],
        Wolfram`AgentTools`Server`Socket`Private`tokenMatchQ[ "secret", "secret2" ],
        Wolfram`AgentTools`Server`Socket`Private`tokenMatchQ[ "", "secret" ]
    },
    { True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "TokenMatchQ@@Tests/SocketServer.wlt:388,1-398,2"
]

VerificationTest[
    With[ { tokens = Table[ Wolfram`AgentTools`Server`Socket`Private`generateSocketToken[ ], 3 ] },
        { AllTrue[ tokens, StringMatchQ[ #, Repeated[ HexadecimalCharacter, { 64 } ] ] & ], DuplicateFreeQ @ tokens }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "GenerateSocketToken@@Tests/SocketServer.wlt:400,1-407,2"
]

VerificationTest[
    With[ { server = <| "Port" -> 4321 |> },
        {
            Wolfram`AgentTools`Server`Socket`Private`hostAllowedQ[ server, <| "host" -> "127.0.0.1:4321" |> ],
            Wolfram`AgentTools`Server`Socket`Private`hostAllowedQ[ server, <| "host" -> "LOCALHOST:4321" |> ],
            Wolfram`AgentTools`Server`Socket`Private`hostAllowedQ[ server, <| "host" -> "127.0.0.1:1234" |> ],
            Wolfram`AgentTools`Server`Socket`Private`hostAllowedQ[ server, <| "host" -> "evil.example:4321" |> ],
            Wolfram`AgentTools`Server`Socket`Private`hostAllowedQ[ server, <| |> ]
        }
    ],
    { True, True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "HostAllowedQ@@Tests/SocketServer.wlt:409,1-422,2"
]

VerificationTest[
    With[ { server = <| "Port" -> 4321 |> },
        Wolfram`AgentTools`Server`Socket`Private`originAllowedQ[ server, # ] & /@ {
            <| |>,
            <| "origin" -> "http://127.0.0.1:4321" |>,
            <| "origin" -> "http://localhost:4321" |>,
            <| "origin" -> "http://127.0.0.1:1234" |>,
            <| "origin" -> "https://127.0.0.1:4321" |>,
            <| "origin" -> "null" |>,
            <| "origin" -> "http://evil.example" |>
        }
    ],
    { True, True, True, False, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "OriginAllowedQ@@Tests/SocketServer.wlt:424,1-439,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Shared HTTP Helpers*)
VerificationTest[
    {
        Wolfram`AgentTools`Server`acceptsEventStreamQ @ <| "accept" -> "application/json, text/event-stream" |>,
        Wolfram`AgentTools`Server`acceptsEventStreamQ @ <| "accept" -> "Text/Event-Stream;q=0.5" |>,
        Wolfram`AgentTools`Server`acceptsEventStreamQ @ <| "accept" -> "*/*" |>,
        Wolfram`AgentTools`Server`acceptsEventStreamQ @ <| |>
    },
    { True, True, False, False },
    SameTest -> MatchQ,
    TestID   -> "AcceptsEventStreamQ@@Tests/SocketServer.wlt:444,1-454,2"
]

(* An empty media range in the Accept header is ignored rather than failing. *)
VerificationTest[
    Wolfram`AgentTools`Server`responseContentType /@ {
        <| "accept" -> "text/event-stream,,application/json" |>,
        <| "accept" -> "text/event-stream" |>,
        <| "accept" -> "text/plain" |>,
        <| |>
    },
    { "application/json", "text/event-stream", None, "application/json" },
    SameTest -> MatchQ,
    TestID   -> "ResponseContentType-EmptyMediaRange@@Tests/SocketServer.wlt:457,1-467,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`requestBodyJSON /@ {
        <| "BodyByteArray" -> StringToByteArray[ "{\"a\":1}" ] |>,
        <| "BodyByteArray" -> StringToByteArray[ "[1,2]" ] |>,
        <| "BodyByteArray" -> StringToByteArray[ "{nope" ] |>,
        <| "BodyByteArray" -> ByteArray[ { 255, 254 } ] |>
    },
    { <| "a" -> 1 |>, { 1, 2 }, $Failed, $Failed },
    SameTest -> MatchQ,
    TestID   -> "RequestBodyJSON@@Tests/SocketServer.wlt:469,1-479,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`jsonRPCMessageType /@ {
        <| "jsonrpc" -> "2.0", "id" -> 1, "method" -> "ping" |>,
        <| "jsonrpc" -> "2.0", "id" -> "a", "method" -> "tools/call" |>,
        <| "jsonrpc" -> "2.0", "id" -> 1.5, "method" -> "ping" |>,
        <| "jsonrpc" -> "2.0", "method" -> "notifications/initialized" |>,
        <| "jsonrpc" -> "2.0", "id" -> 1, "method" -> "notifications/cancelled" |>,
        <| "jsonrpc" -> "2.0", "method" -> "tools/call" |>,
        <| "jsonrpc" -> "2.0", "id" -> Null, "method" -> "tools/call" |>,
        <| "jsonrpc" -> "2.0", "id" -> "x", "result" -> <| |> |>,
        <| "jsonrpc" -> "2.0", "id" -> Null, "error" -> <| "code" -> -32700 |> |>,
        <| "jsonrpc" -> "2.0", "id" -> 7, "method" -> Null |>,
        <| "jsonrpc" -> "2.0", "id" -> 8, "method" -> { "tools/list" } |>,
        <| "jsonrpc" -> "2.0", "id" -> <| |>, "method" -> "ping" |>,
        <| "jsonrpc" -> "2.0", "id" -> 9, "result" -> <| |>, "error" -> <| |> |>,
        <| "jsonrpc" -> "2.0", "id" -> 10 |>
    },
    {
        "Request", "Request", "Request",
        "Notification", "Notification", "Notification", "Notification",
        "Response", "Response",
        "Invalid", "Invalid", "Invalid", "Invalid", "Invalid"
    },
    SameTest -> MatchQ,
    TestID   -> "JSONRPCMessageType@@Tests/SocketServer.wlt:481,1-506,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Secrets*)
(* Values that can be tokens are redacted from what messages show, also inside held expressions (redactSecrets, which
   Tests/InternalFailureFormatting.wlt tests further). *)
VerificationTest[
    With[
        {
            text = ToString[
                Wolfram`AgentTools`Common`redactSecrets @ {
                    HoldForm @ f[
                        "Authentication" -> "secret1",
                        Authentication :> "secret2",
                        { "Token" -> "secret3" },
                        <| "x" -> <| "authorization" -> "secret4" |>, "keep" -> 1 |>
                    ],
                    <| "ID" -> "keep", "Token" -> "secret5", "Authentication" -> <| "Token" -> "secret6" |> |>
                },
                InputForm
            ]
        },
        { StringFreeQ[ text, "secret" ], StringCount[ text, "keep" ], StringCount[ text, "<redacted>" ] }
    ],
    { True, 2, 6 },
    SameTest -> MatchQ,
    TestID   -> "RedactSecrets@@Tests/SocketServer.wlt:513,1-534,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Starting and Stopping*)
VerificationTest[
    $socketServer = StartMCPSocketServer[ $socketTestServerObject, "KeepAliveInterval" -> 0.5 ],
    _MCPSocketServerObject,
    SameTest -> MatchQ,
    TestID   -> "Start@@Tests/SocketServer.wlt:539,1-544,2"
]

VerificationTest[
    $socketServer[ { "Name", "Path", "Running", "PendingRequests", "Server" } ],
    <|
        "Name"            -> "SocketServerTest",
        "Path"            -> "/mcp",
        "Running"         -> True,
        "PendingRequests" -> 0,
        "Server"          -> _MCPServerObject
    |>,
    SameTest -> MatchQ,
    TestID   -> "Properties@@Tests/SocketServer.wlt:546,1-557,2"
]

VerificationTest[
    With[ { port = $socketServer[ "Port" ] },
        {
            IntegerQ @ port,
            $socketServer[ "URL" ] === "http://127.0.0.1:" <> ToString @ port <> "/mcp",
            StringMatchQ[ $socketServer[ "Token" ], Repeated[ HexadecimalCharacter, { 64 } ] ],
            StringMatchQ[ $socketServer[ "ID" ], Repeated[ HexadecimalCharacter | "-", { 36 } ] ],
            MatchQ[ $socketServer[ "Listener" ], _SocketListener ]
        }
    ],
    { True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Properties-Values@@Tests/SocketServer.wlt:559,1-572,2"
]

VerificationTest[
    {
        Sort @ $socketServer[ "Properties" ],
        AllTrue[ $socketServer[ "Properties" ], ! MissingQ @ $socketServer[ # ] & ],
        $socketServer[ "NoSuchProperty" ]
    },
    {
        {
            "ID", "JSONConfiguration", "Listener", "Name", "Path", "PendingRequests", "Port", "Properties", "Running",
            "Server", "Token", "URL"
        },
        True,
        Missing[ "UnknownProperty", "NoSuchProperty" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Properties-List@@Tests/SocketServer.wlt:574,1-590,2"
]

VerificationTest[
    Developer`ReadRawJSONString @ $socketServer[ "JSONConfiguration" ],
    <|
        "type"    -> "http",
        "url"     -> $socketServer[ "URL" ],
        "headers" -> <| "Authorization" -> "Bearer " <> $socketServer[ "Token" ] |>
    |>,
    SameTest -> MatchQ,
    TestID   -> "Properties-JSONConfiguration@@Tests/SocketServer.wlt:592,1-601,2"
]

(* The listener binds 127.0.0.1 only *)
VerificationTest[
    $socketServer[ "Listener" ][ "Socket" ][ "DestinationIPAddress" ],
    { IPAddress[ "127.0.0.1" ] } | IPAddress[ "127.0.0.1" ] | "127.0.0.1" | { "127.0.0.1" },
    SameTest -> MatchQ,
    TestID   -> "Listener-Loopback@@Tests/SocketServer.wlt:604,1-609,2"
]

VerificationTest[
    ToBoxes @ $socketServer,
    _InterpretationBox,
    SameTest -> MatchQ,
    TestID   -> "Formatting@@Tests/SocketServer.wlt:611,1-616,2"
]

VerificationTest[
    StartMCPSocketServer[ $socketTestServerObject, "Port" -> $socketServer[ "Port" ] ],
    _Failure,
    { StartMCPSocketServer::SocketServerListenFailed },
    SameTest -> MatchQ,
    TestID   -> "Start-PortInUse@@Tests/SocketServer.wlt:618,1-624,2"
]

VerificationTest[
    {
        StartMCPSocketServer[ $socketTestServerObject, "Port" -> 0 ],
        StartMCPSocketServer[ $socketTestServerObject, "Path" -> "mcp" ],
        StartMCPSocketServer[ $socketTestServerObject, "Authentication" -> "has space" ],
        StartMCPSocketServer[ $socketTestServerObject, "KeepAliveInterval" -> -1 ],
        StartMCPSocketServer[ $socketTestServerObject, "ToolOptions" -> { } ]
    },
    { _Failure, _Failure, _Failure, _Failure, _Failure },
    {
        StartMCPSocketServer::InvalidSocketServerPort,
        StartMCPSocketServer::InvalidSocketServerPath,
        StartMCPSocketServer::InvalidSocketServerAuthentication,
        StartMCPSocketServer::InvalidKeepAliveInterval,
        StartMCPSocketServer::InvalidToolOptions
    },
    SameTest -> MatchQ,
    TestID   -> "Start-InvalidOptions@@Tests/SocketServer.wlt:626,1-644,2"
]

VerificationTest[
    StartMCPSocketServer[ "NoSuchServer" <> CreateUUID[ ] ],
    _Failure,
    { StartMCPSocketServer::MCPServerNotFound },
    SameTest -> MatchQ,
    TestID   -> "Start-UnknownServerName@@Tests/SocketServer.wlt:646,1-652,2"
]

VerificationTest[
    StartMCPSocketServer[ 123 ],
    _Failure,
    { StartMCPSocketServer::InvalidArguments },
    SameTest -> MatchQ,
    TestID   -> "Start-InvalidArguments@@Tests/SocketServer.wlt:654,1-660,2"
]

(* Messages and failures never show an authentication token: not an invalid one, not one among invalid arguments. *)
VerificationTest[
    Module[ { failures },
        failures = Quiet @ {
            StartMCPSocketServer[ $socketTestServerObject, "Authentication" -> "secret-token-1\n" ],
            StartMCPSocketServer[ $Failed, "Authentication" -> "secret-token-2" ],
            StartMCPSocketServer[ $socketTestServerObject, 5, Authentication -> "secret-token-3" ],
            MCPSocketServerObject @ <| "ID" -> "x", "Token" -> "secret-token-4" |>
        };
        {
            failures,
            AllTrue[ failures, StringQ @ #[ "Message" ] & ],
            StringFreeQ[ ToString[ { failures, #[ "Message" ] & /@ failures }, InputForm ], "secret-token" ]
        }
    ],
    { { _Failure, _Failure, _Failure, _Failure }, True, True },
    SameTest -> MatchQ,
    TestID   -> "Secrets-NotInMessages@@Tests/SocketServer.wlt:663,1-680,2"
]

(* A server on a chosen port with a chosen path, stopped with DeleteObject. *)
VerificationTest[
    Module[ { first, port, server, result },
        first = StartMCPSocketServer[ $socketTestServerObject ];
        port  = first[ "Port" ];
        DeleteObject @ first;
        server = StartMCPSocketServer[ $socketTestServerObject, "Port" -> port, "Path" -> "/other" ];
        result = {
            server[ "Port" ] === port,
            server[ "URL" ] === "http://127.0.0.1:" <> ToString @ port <> "/other",
            socketTestJSON[ server, socketTestBody[ "ping", 1 ] ],
            DeleteObject @ server,
            server[ "Running" ],
            DeleteObject @ server,
            server[ "Port" ] === port
        };
        result
    ],
    { True, True, <| "jsonrpc" -> "2.0", "id" -> 1, "result" -> <| |> |>, Null, False, Null, True },
    SameTest -> MatchQ,
    TestID   -> "Start-PortAndPath-Stop@@Tests/SocketServer.wlt:683,1-703,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Authentication*)
VerificationTest[
    With[ { response = socketTestExchange[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Authorization" -> None } ] },
        { response[ "Status" ], response[ "Headers", "www-authenticate" ] }
    ],
    { 401, "Bearer" },
    SameTest -> MatchQ,
    TestID   -> "Auth-Automatic-Missing-401@@Tests/SocketServer.wlt:708,1-715,2"
]

VerificationTest[
    {
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Authorization" -> "Bearer wrong" } ],
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Authorization" -> "Basic " <> $socketServer[ "Token" ] } ],
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Authorization" -> "bearer " <> $socketServer[ "Token" ] } ]
    },
    { 401, 401, 200 },
    SameTest -> MatchQ,
    TestID   -> "Auth-Automatic-Tokens@@Tests/SocketServer.wlt:717,1-726,2"
]

VerificationTest[
    Module[ { server, result },
        server = StartMCPSocketServer[ $socketTestServerObject, "Authentication" -> None ];
        result = {
            server[ "Token" ],
            socketTestStatus[ server, socketTestBody[ "ping", 1 ] ],
            socketTestStatus[ server, socketTestBody[ "ping", 1 ], "Headers" -> { "Authorization" -> "Bearer anything" } ],
            Developer`ReadRawJSONString[ server[ "JSONConfiguration" ] ][ "headers" ]
        };
        DeleteObject @ server;
        result
    ],
    { None, 200, 200, <| |> },
    SameTest -> MatchQ,
    TestID   -> "Auth-None@@Tests/SocketServer.wlt:728,1-743,2"
]

VerificationTest[
    Module[ { server, result },
        server = StartMCPSocketServer[ $socketTestServerObject, "Authentication" -> "my-token" ];
        result = {
            server[ "Token" ],
            socketTestStatus[ server, socketTestBody[ "ping", 1 ] ],
            socketTestStatus[ server, socketTestBody[ "ping", 1 ], "Headers" -> { "Authorization" -> "Bearer my-tokeN" } ]
        };
        DeleteObject @ server;
        result
    ],
    { "my-token", 200, 401 },
    SameTest -> MatchQ,
    TestID   -> "Auth-String@@Tests/SocketServer.wlt:745,1-759,2"
]

(* A function decides from the bearer token, or None without one; anything but True refuses the request (including a
   Throw, which must not escape the handler). *)
VerificationTest[
    Module[ { seen = { }, server, result },
        server = StartMCPSocketServer[
            $socketTestServerObject,
            "Authentication" -> Function[ AppendTo[ seen, # ]; Switch[ #, "good", True, "throw", Throw[ 1 ], _, "yes" ] ]
        ];
        result = {
            server[ "Token" ],
            socketTestStatus[ server, socketTestBody[ "ping", 1 ], "Headers" -> { "Authorization" -> "Bearer good" } ],
            socketTestStatus[ server, socketTestBody[ "ping", 1 ], "Headers" -> { "Authorization" -> "Bearer other" } ],
            socketTestStatus[ server, socketTestBody[ "ping", 1 ] ],
            socketTestStatus[ server, socketTestBody[ "ping", 1 ], "Headers" -> { "Authorization" -> "Bearer throw" } ]
        };
        DeleteObject @ server;
        { result, seen }
    ],
    { { None, 200, 401, 401, 401 }, { "good", "other", None, "throw" } },
    SameTest -> MatchQ,
    TestID   -> "Auth-Function@@Tests/SocketServer.wlt:763,1-782,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Transport Validation*)
VerificationTest[
    {
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Target" -> "/other" ],
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Target" -> "/mcp/" ],
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Target" -> "/mcp" ],
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Target" -> "/mcp?a=1&b=2" ]
    },
    { 404, 404, 200, 200 },
    SameTest -> MatchQ,
    TestID   -> "Validation-Path@@Tests/SocketServer.wlt:787,1-797,2"
]

VerificationTest[
    Map[
        With[ { response = socketTestExchange[ $socketServer, "", "Method" -> # ] },
            { response[ "Status" ], response[ "Headers", "allow" ] }
        ] &,
        { "GET", "DELETE", "PUT", "OPTIONS" }
    ],
    ConstantArray[ { 405, "POST" }, 4 ],
    SameTest -> MatchQ,
    TestID   -> "Validation-Method-405@@Tests/SocketServer.wlt:799,1-809,2"
]

VerificationTest[
    {
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Host" -> "localhost:" <> ToString @ $socketServer[ "Port" ] } ],
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Host" -> "evil.example:" <> ToString @ $socketServer[ "Port" ] } ],
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Host" -> "127.0.0.1" } ],
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Host" -> None } ]
    },
    { 200, 403, 403, 403 },
    SameTest -> MatchQ,
    TestID   -> "Validation-Host-403@@Tests/SocketServer.wlt:811,1-821,2"
]

VerificationTest[
    {
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Origin" -> "http://127.0.0.1:" <> ToString @ $socketServer[ "Port" ] } ],
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Origin" -> "http://evil.example" } ],
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Origin" -> "null" } ]
    },
    { 200, 403, 403 },
    SameTest -> MatchQ,
    TestID   -> "Validation-Origin-403@@Tests/SocketServer.wlt:823,1-832,2"
]

(* The Origin is checked before the token, so a cross-site request learns nothing about it. *)
VerificationTest[
    socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Origin" -> "http://evil.example", "Authorization" -> None } ],
    403,
    SameTest -> MatchQ,
    TestID   -> "Validation-Origin-BeforeAuth@@Tests/SocketServer.wlt:835,1-840,2"
]

VerificationTest[
    {
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Accept" -> "text/plain" } ],
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Accept" -> None } ],
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Accept" -> "application/json" } ]
    },
    { 406, 200, 200 },
    SameTest -> MatchQ,
    TestID   -> "Validation-Accept-406@@Tests/SocketServer.wlt:842,1-851,2"
]

VerificationTest[
    Map[
        With[ { response = socketTestExchange[ $socketServer, # ] }, { response[ "Status" ], response[ "JSON", "error", "code" ] } ] &,
        { "{nope", "", "[" <> socketTestBody[ "ping", 1 ] <> "]", "42" }
    ],
    { { 400, -32700 }, { 400, -32700 }, { 400, -32600 }, { 400, -32600 } },
    SameTest -> MatchQ,
    TestID   -> "Validation-Body-400@@Tests/SocketServer.wlt:853,1-861,2"
]

VerificationTest[
    {
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "MCP-Protocol-Version" -> "1999-01-01" } ],
        socketTestStatus[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "mcp-protocol-version" -> "2025-06-18" } ],
        (* initialize negotiates the version, so its header is not checked *)
        socketTestStatus[ $socketServer, socketTestBody[ "initialize", 1, <| "protocolVersion" -> "2025-06-18" |> ], "Headers" -> { "MCP-Protocol-Version" -> "1999-01-01" } ]
    },
    { 400, 200, 200 },
    SameTest -> MatchQ,
    TestID   -> "Validation-ProtocolVersion-400@@Tests/SocketServer.wlt:863,1-873,2"
]

(* Requests that cannot be framed get an error, and the connection is closed. *)
VerificationTest[
    Module[ { exchange },
        exchange = Function[ bytes,
            Module[ { client, response },
                client = socketTestConnect @ $socketServer;
                socketTestSend[ client, bytes ];
                response = socketTestRead @ client;
                socketTestClose @ client;
                { response[ "Status" ], response[ "Headers", "connection" ] }
            ]
        ];
        {
            exchange @ StringToByteArray[ "GARBAGE\r\n\r\n" ],
            exchange @ StringToByteArray[ "POST /mcp HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n" ],
            exchange @ StringToByteArray[ "POST /mcp HTTP/1.1\r\nContent-Length: " <> ToString[ 8 * 1024^2 + 1 ] <> "\r\n\r\n" ],
            exchange @ StringToByteArray[ "POST /mcp HTTP/1.1\r\nX-Big: " <> StringRepeat[ "a", 70000 ] ]
        }
    ],
    { { 400, "close" }, { 501, "close" }, { 413, "close" }, { 431, "close" } },
    SameTest -> MatchQ,
    TestID   -> "Validation-Framing-Errors@@Tests/SocketServer.wlt:876,1-897,2"
]

(* A request that its head refuses is answered at once, before its body arrives, and its connection is closed: a client
   that may not use the server cannot make it buffer a body (nor send a "100 Continue" first). *)
VerificationTest[
    Module[ { exchange },
        exchange = Function[ headers,
            Module[ { client, response },
                client = socketTestConnect @ $socketServer;
                (* the head of a request with a large body, but none of the body *)
                socketTestSend[
                    client,
                    socketTestRequest[ $socketServer, "", "Headers" -> Prepend[ headers, "Content-Length" -> "1000000" ] ]
                ];
                response = socketTestRead[ client, 2 ];
                socketTestClose @ client;
                Replace[ response, r_Association :> { r[ "Status" ], r[ "Headers", "connection" ] } ]
            ]
        ];
        {
            exchange @ { "Host" -> "evil.example:" <> ToString @ $socketServer[ "Port" ] },
            exchange @ { "Origin" -> "http://evil.example" },
            exchange @ { "Authorization" -> None },
            exchange @ { "Authorization" -> None, "Expect" -> "100-continue" },
            exchange @ { "Accept" -> "text/plain" }
        }
    ],
    { { 403, "close" }, { 403, "close" }, { 401, "close" }, { 401, "close" }, { 406, "close" } },
    SameTest -> MatchQ,
    TestID   -> "Validation-HeadRefusedBeforeBody@@Tests/SocketServer.wlt:901,1-927,2"
]

(* Refusals close the connection, so a client that sends requests without reading the responses cannot make the server
   queue them: only the first of several pipelined requests is answered. *)
VerificationTest[
    Module[ { client, first, rest },
        client = socketTestConnect @ $socketServer;
        socketTestSend[ client, StringToByteArray @ StringRepeat[ "POST /x HTTP/1.1\r\n\r\n", 3 ] ];
        first = socketTestRead @ client;
        rest  = socketTestQuiet[ client, 0.5 ];
        socketTestClose @ client;
        { first[ "Status" ], first[ "Headers", "connection" ], rest }
    ],
    { 404, "close", "" },
    SameTest -> MatchQ,
    TestID   -> "Validation-RefusalClosesConnection@@Tests/SocketServer.wlt:931,1-943,2"
]

(* OpenCode probes the endpoint with GET on a connection that it then uses again: the 405 keeps the connection of a client
   that may use the server, and closes it for any other. *)
VerificationTest[
    Module[ { client, probe, ping, refused },
        client = socketTestConnect @ $socketServer;
        socketTestSend[ client, socketTestRequest[ $socketServer, "", "Method" -> "GET" ] ];
        probe = socketTestRead @ client;
        socketTestSend[ client, socketTestRequest[ $socketServer, socketTestBody[ "ping", 1 ] ] ];
        ping = socketTestRead @ client;
        socketTestClose @ client;
        refused = socketTestExchange[ $socketServer, "", "Method" -> "GET", "Headers" -> { "Authorization" -> None } ];
        {
            probe[ "Status" ],
            probe[ "Headers", "keep-alive" ],
            ping[ "JSON", "id" ],
            refused[ "Status" ],
            refused[ "Headers", "connection" ]
        }
    ],
    { 405, "timeout=300", 1, 405, "close" },
    SameTest -> MatchQ,
    TestID   -> "Validation-Method-405-KeepAlive@@Tests/SocketServer.wlt:947,1-967,2"
]

(* Errors in the body close the connection too. *)
VerificationTest[
    With[ { response = socketTestExchange[ $socketServer, "{nope" ] },
        { response[ "Status" ], response[ "Headers", "connection" ] }
    ],
    { 400, "close" },
    SameTest -> MatchQ,
    TestID   -> "Validation-Body-400-Close@@Tests/SocketServer.wlt:970,1-977,2"
]

(* A message with an id that is neither a request nor a response gets an error with that id, since its client may be
   waiting for a response to it. *)
VerificationTest[
    Map[
        With[ { response = socketTestExchange[ $socketServer, # ] },
            { response[ "Status" ], response[ "JSON", "id" ], response[ "JSON", "error", "code" ] }
        ] &,
        {
            "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":null}",
            "{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":[\"tools/list\"]}",
            "{\"jsonrpc\":\"2.0\",\"id\":\"r\",\"result\":{},\"error\":{}}",
            "{\"jsonrpc\":\"2.0\",\"id\":{\"a\":1},\"method\":\"ping\"}"
        }
    ],
    { { 400, 7, -32600 }, { 400, 8, -32600 }, { 400, "r", -32600 }, { 400, Null, -32600 } },
    SameTest -> MatchQ,
    TestID   -> "Validation-InvalidMessage-32600@@Tests/SocketServer.wlt:981,1-996,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Methods*)
VerificationTest[
    $socketInitialize = socketTestExchange[
        $socketServer,
        socketTestBody[ "initialize", 0, <| "protocolVersion" -> "2025-06-18", "clientInfo" -> <| "name" -> "opencode" |>, "capabilities" -> <| "roots" -> <| |> |> |> ]
    ];
    { $socketInitialize[ "Status" ], $socketInitialize[ "Headers", "content-type" ], $socketInitialize[ "JSON", "result" ] },
    {
        200,
        "application/json",
        KeyValuePattern @ {
            "protocolVersion" -> "2025-06-18",
            "instructions"    -> "Instructions for the socket server test.",
            "serverInfo"      -> <| "name" -> "SocketServerTest", "version" -> _String |>,
            "capabilities"    -> KeyValuePattern[ "tools" -> _Association ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Initialize@@Tests/SocketServer.wlt:1001,1-1019,2"
]

(* The server is stateless: no session ID. *)
VerificationTest[
    KeyExistsQ[ $socketInitialize[ "Headers" ], "mcp-session-id" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "Initialize-NoSessionID@@Tests/SocketServer.wlt:1022,1-1027,2"
]

(* Requests leave the kernel's state alone: initialize sets the client name, capabilities and (for most clients, in the
   stdio transport) switches off messages, and tool calls bind the tool options. *)
VerificationTest[
    Block[ { $Messages = Streams[ "stdout" ] }, Module[ { before, after },
        before = socketTestGlobals[ ];
        Scan[
            socketTestExchange[ $socketServer, # ] &,
            {
                socketTestBody[ "initialize", 0, <| "clientInfo" -> <| "name" -> "opencode" |>, "capabilities" -> <| "roots" -> <| |> |> |> ],
                socketTestBody[ "initialize", 1, <| "clientInfo" -> <| "name" -> "claude-ai" |> |> ],
                socketTestBody[ "notifications/initialized" ],
                socketTestBody[ "tools/list", 2 ],
                socketTestBody[ "tools/call", 3, <| "name" -> "Echo", "arguments" -> <| "text" -> "hi" |> |> ],
                socketTestBody[ "prompts/get", 4, <| "name" -> "Greeting" |> ]
            }
        ];
        after = socketTestGlobals[ ];
        { before === after, $Messages === Streams[ "stdout" ] }
    ] ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "GlobalState-Unchanged@@Tests/SocketServer.wlt:1031,1-1051,2"
]

VerificationTest[
    {
        socketTestExchange[ $socketServer, socketTestBody[ "notifications/initialized" ] ][[ { "Status", "Body" } ]],
        socketTestExchange[ $socketServer, socketTestBody[ "ping", Null ] ][[ { "Status", "Body" } ]],
        (* a JSON-RPC response from the client *)
        socketTestExchange[ $socketServer, "{\"jsonrpc\":\"2.0\",\"id\":\"x\",\"result\":{}}" ][[ { "Status", "Body" } ]]
    },
    ConstantArray[ <| "Status" -> 202, "Body" -> "" |>, 3 ],
    SameTest -> MatchQ,
    TestID   -> "Notifications-202@@Tests/SocketServer.wlt:1053,1-1063,2"
]

(* A request without an id (or with a null id) owes no response, and it is not evaluated: a tools/call never runs in the
   handler, and never bypasses the evaluation function. *)
VerificationTest[
    Module[ { ran = { }, calls = 0, server, result },
        server = StartMCPSocketServer[
            MCPServerObject @ <|
                "Name"         -> "SocketServerNoIDTest",
                "Location"     -> None,
                "LLMEvaluator" -> <| "Tools" -> { LLMTool[ "Record", { "text" -> "String" }, (AppendTo[ ran, #text ]; "ok") & ] } |>
            |>,
            "EvaluationFunction" -> Function[ { run, info }, calls++; run[ ] ]
        ];
        result = {
            socketTestStatus[ server, socketTestBody[ "tools/call", None, <| "name" -> "Record", "arguments" -> <| "text" -> "none" |> |> ] ],
            socketTestStatus[ server, socketTestBody[ "tools/call", Null, <| "name" -> "Record", "arguments" -> <| "text" -> "null" |> |> ] ],
            socketTestJSON[ server, socketTestBody[ "tools/call", 1, <| "name" -> "Record", "arguments" -> <| "text" -> "one" |> |> ] ][ "result", "isError" ]
        };
        DeleteObject @ server;
        { result, ran, calls }
    ],
    { { 202, 202, False }, { "one" }, 1 },
    SameTest -> MatchQ,
    TestID   -> "Notifications-RequestWithoutID-NotEvaluated@@Tests/SocketServer.wlt:1067,1-1088,2"
]

VerificationTest[
    socketTestJSON[ $socketServer, socketTestBody[ "ping", "p" ] ],
    <| "jsonrpc" -> "2.0", "id" -> "p", "result" -> <| |> |>,
    SameTest -> MatchQ,
    TestID   -> "Ping@@Tests/SocketServer.wlt:1090,1-1095,2"
]

VerificationTest[
    socketTestJSON[ $socketServer, socketTestBody[ "tools/list", 1 ] ][[ "result", "tools", All, "name" ]],
    { "Echo", "Aborter", "Sleep" },
    SameTest -> MatchQ,
    TestID   -> "ToolsList@@Tests/SocketServer.wlt:1097,1-1102,2"
]

VerificationTest[
    socketTestJSON[ $socketServer, socketTestBody[ "prompts/list", 1 ] ][[ "result", "prompts", All, "name" ]],
    { "Greeting" },
    SameTest -> MatchQ,
    TestID   -> "PromptsList@@Tests/SocketServer.wlt:1104,1-1109,2"
]

VerificationTest[
    socketTestJSON[ $socketServer, socketTestBody[ "no/such/method", 1 ] ][ "error", "code" ],
    -32601,
    SameTest -> MatchQ,
    TestID   -> "UnknownMethod-32601@@Tests/SocketServer.wlt:1111,1-1116,2"
]

(* With the default evaluation function, tool calls are evaluated in the handler and answered as JSON. *)
VerificationTest[
    With[ { response = socketTestExchange[ $socketServer, socketTestBody[ "tools/call", 5, <| "name" -> "Echo", "arguments" -> <| "text" -> "h\[Alpha]llo \:2713" |> |> ] ] },
        { response[ "Status" ], response[ "Headers", "content-type" ], response[ "JSON" ] }
    ],
    {
        200,
        "application/json",
        <| "jsonrpc" -> "2.0", "id" -> 5, "result" -> <| "content" -> { <| "type" -> "text", "text" -> "h\[Alpha]llo \:2713" |> }, "isError" -> False |> |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolsCall-Immediate@@Tests/SocketServer.wlt:1119,1-1130,2"
]

VerificationTest[
    socketTestJSON[ $socketServer, socketTestBody[ "tools/call", 6, <| "name" -> "Aborter", "arguments" -> <| |> |> ] ][ "result" ],
    <| "content" -> { <| "type" -> "text", "text" -> "The tool call was aborted by the user." |> }, "isError" -> True |>,
    SameTest -> MatchQ,
    TestID   -> "ToolsCall-Immediate-Abort@@Tests/SocketServer.wlt:1132,1-1137,2"
]

VerificationTest[
    {
        socketTestJSON[ $socketServer, socketTestBody[ "tools/call", 7, <| "name" -> "NoSuchTool", "arguments" -> <| |> |> ] ][ "result", "isError" ],
        socketTestJSON[ $socketServer, socketTestBody[ "tools/call", 8, <| "arguments" -> <| |> |> ] ][ "error", "code" ],
        socketTestJSON[ $socketServer, socketTestBody[ "tools/call", 9, <| "name" -> "Echo", "arguments" -> { 1 } |> ] ][ "error", "code" ]
    },
    { True, -32602, -32602 },
    SameTest -> MatchQ,
    TestID   -> "ToolsCall-Invalid@@Tests/SocketServer.wlt:1139,1-1148,2"
]

VerificationTest[
    {
        socketTestJSON[ $socketServer, socketTestBody[ "prompts/get", 1, <| "name" -> "Greeting" |> ] ][ "result", "messages" ],
        socketTestJSON[ $socketServer, socketTestBody[ "prompts/get", 2, <| "name" -> "NoSuchPrompt" |> ] ][ "error", "code" ]
    },
    { { <| "role" -> "user", "content" -> <| "type" -> "text", "text" -> "Hello!" |> |> }, -32602 },
    SameTest -> MatchQ,
    TestID   -> "PromptsGet@@Tests/SocketServer.wlt:1150,1-1158,2"
]

(* A client that only accepts event streams gets its response as a single event. *)
VerificationTest[
    With[ { response = socketTestExchange[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Accept" -> "text/event-stream" } ] },
        { response[ "Status" ], response[ "Headers", "content-type" ], response[ "Events" ], response[ "JSON" ] }
    ],
    {
        200,
        "text/event-stream",
        { <| "event" -> "message", "data" -> _String |> },
        <| "jsonrpc" -> "2.0", "id" -> 1, "result" -> <| |> |>
    },
    SameTest -> MatchQ,
    TestID   -> "EventStreamOnly-Immediate@@Tests/SocketServer.wlt:1161,1-1173,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*HTTP Framing*)

(* Several requests on one connection *)
VerificationTest[
    Module[ { client, responses },
        client = socketTestConnect @ $socketServer;
        responses = Table[
            socketTestSend[ client, socketTestRequest[ $socketServer, socketTestBody[ "ping", i ] ] ];
            socketTestRead[ client ][ "JSON", "id" ],
            { i, 3 }
        ];
        socketTestClose @ client;
        responses
    ],
    { 1, 2, 3 },
    SameTest -> MatchQ,
    TestID   -> "Framing-KeepAlive@@Tests/SocketServer.wlt:1180,1-1194,2"
]

(* Pipelined requests in a single write are answered in order *)
VerificationTest[
    Module[ { client, responses },
        client = socketTestConnect @ $socketServer;
        socketTestSend[ client, Join @@ Table[ socketTestRequest[ $socketServer, socketTestBody[ "ping", i ] ], { i, 3 } ] ];
        responses = Table[ socketTestRead[ client ][ "JSON", "id" ], 3 ];
        socketTestClose @ client;
        responses
    ],
    { 1, 2, 3 },
    SameTest -> MatchQ,
    TestID   -> "Framing-Pipelining@@Tests/SocketServer.wlt:1197,1-1208,2"
]

(* A request that arrives one byte at a time *)
VerificationTest[
    Module[ { client, bytes, response },
        client = socketTestConnect @ $socketServer;
        bytes  = socketTestRequest[ $socketServer, socketTestBody[ "tools/call", 1, <| "name" -> "Echo", "arguments" -> <| "text" -> "\[Alpha]\[Beta]" |> |> ] ];
        Do[ socketTestSend[ client, ByteArray @ { b } ]; Pause[ 0.001 ], { b, Normal @ bytes } ];
        response = socketTestRead @ client;
        socketTestClose @ client;
        response[[ "JSON", "result", "content", 1, "text" ]]
    ],
    "\[Alpha]\[Beta]",
    SameTest -> MatchQ,
    TestID   -> "Framing-ByteByByte@@Tests/SocketServer.wlt:1211,1-1223,2"
]

(* A UTF-8 body split inside a character, across two chunks *)
VerificationTest[
    Module[ { client, bytes, split, response },
        client = socketTestConnect @ $socketServer;
        bytes  = socketTestRequest[ $socketServer, socketTestBody[ "tools/call", 1, <| "name" -> "Echo", "arguments" -> <| "text" -> "x\[Alpha]y" |> |> ] ];
        split  = First @ FirstPosition[ Normal @ bytes, 206 ]; (* the first byte of \[Alpha] *)
        socketTestSend[ client, Take[ bytes, split ] ];
        Pause[ 0.2 ];
        socketTestSend[ client, Drop[ bytes, split ] ];
        response = socketTestRead @ client;
        socketTestClose @ client;
        response[[ "JSON", "result", "content", 1, "text" ]]
    ],
    "x\[Alpha]y",
    SameTest -> MatchQ,
    TestID   -> "Framing-SplitUTF8@@Tests/SocketServer.wlt:1226,1-1241,2"
]

(* A body of several chunks *)
VerificationTest[
    Module[ { text },
        text = StringJoin @ ConstantArray[ "0123456789\[Alpha]", 20000 ];
        socketTestJSON[ $socketServer, socketTestBody[ "tools/call", 1, <| "name" -> "Echo", "arguments" -> <| "text" -> text |> |> ] ][[ "result", "content", 1, "text" ]] === text
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Framing-LargeBody@@Tests/SocketServer.wlt:1244,1-1252,2"
]

VerificationTest[
    Module[ { client, bytes, head, interim, response },
        client = socketTestConnect @ $socketServer;
        bytes  = socketTestRequest[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Expect" -> "100-continue" } ];
        head   = First @ FirstPosition[ Partition[ Normal @ bytes, 4, 1 ], { 13, 10, 13, 10 } ] + 3;
        socketTestSend[ client, Take[ bytes, head ] ];
        interim = socketTestRead @ client;
        socketTestSend[ client, Drop[ bytes, head ] ];
        response = socketTestRead @ client;
        socketTestClose @ client;
        { interim[ "Status" ], response[ "Status" ], response[ "JSON", "id" ] }
    ],
    { 100, 200, 1 },
    SameTest -> MatchQ,
    TestID   -> "Framing-ExpectContinue@@Tests/SocketServer.wlt:1254,1-1269,2"
]

(* HTTP/1.0 connections are closed after the response unless the client asks to keep them. *)
VerificationTest[
    Module[ { client, response, closed },
        client = socketTestConnect @ $socketServer;
        socketTestSend[ client, socketTestRequest[ $socketServer, socketTestBody[ "ping", 1 ], "Version" -> "HTTP/1.0" ] ];
        response = socketTestRead @ client;
        closed = socketTestEventually[ $socketServer[ "Listener" ][ "Socket" ][ "ConnectedClients" ] === { } ];
        socketTestClose @ client;
        { response[ "Status" ], response[ "Headers", "connection" ], closed }
    ],
    { 200, "close", True },
    SameTest -> MatchQ,
    TestID   -> "Framing-HTTP10-Close@@Tests/SocketServer.wlt:1272,1-1284,2"
]

VerificationTest[
    Module[ { client, response },
        client = socketTestConnect @ $socketServer;
        socketTestSend[ client, socketTestRequest[ $socketServer, socketTestBody[ "ping", 1 ], "Headers" -> { "Connection" -> "close" } ] ];
        response = socketTestRead @ client;
        socketTestClose @ client;
        { response[ "Status" ], response[ "Headers", "connection" ] }
    ],
    { 200, "close" },
    SameTest -> MatchQ,
    TestID   -> "Framing-ConnectionClose@@Tests/SocketServer.wlt:1286,1-1297,2"
]

VerificationTest[
    socketTestExchange[ $socketServer, socketTestBody[ "ping", 1 ] ][ "Headers", "keep-alive" ],
    "timeout=300",
    SameTest -> MatchQ,
    TestID   -> "Framing-KeepAliveHeader@@Tests/SocketServer.wlt:1299,1-1304,2"
]

(* The framing state of connections that were closed is forgotten. *)
VerificationTest[
    socketTestEventually[
        Wolfram`AgentTools`Server`Socket`Private`socketMaintenance @ $socketServer[ "ID" ];
        Select[
            Wolfram`AgentToolsState`SocketServer`$connections,
            #[ "ServerID" ] === $socketServer[ "ID" ] &
        ] === <| |>
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Framing-PurgeConnections@@Tests/SocketServer.wlt:1307,1-1318,2"
]

(* A partial request (head or body) that gets no more bytes for a while gets a 408 and is closed; idle connections
   between requests are kept. The timeout is shortened for the test. *)
VerificationTest[
    Module[ { partialHead, partialBody, idle, result },
        partialHead = socketTestConnect @ $socketServer;
        socketTestSend[ partialHead, StringToByteArray[ "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:" <> ToString @ $socketServer[ "Port" ] <> "\r\n" ] ];
        partialBody = socketTestConnect @ $socketServer;
        socketTestSend[ partialBody, Drop[ socketTestRequest[ $socketServer, socketTestBody[ "ping", 1 ] ], -5 ] ];
        idle = socketTestConnect @ $socketServer;
        socketTestSend[ idle, socketTestRequest[ $socketServer, socketTestBody[ "ping", 2 ] ] ];
        socketTestRead @ idle;
        Pause[ 0.3 ];
        socketTestMaintenance[ $socketServer, 0.1 ];
        result = {
            socketTestRead[ partialHead ][ "Status" ],
            socketTestRead[ partialBody ][ "Status" ],
            socketTestSend[ idle, socketTestRequest[ $socketServer, socketTestBody[ "ping", 3 ] ] ];
            socketTestRead[ idle ][ "JSON", "id" ]
        };
        socketTestClose /@ { partialHead, partialBody, idle };
        result
    ],
    { 408, 408, 3 },
    SameTest -> MatchQ,
    TestID   -> "Framing-StalledRequest-408@@Tests/SocketServer.wlt:1322,1-1345,2"
]

(* Time during which the kernel could not run the handler (as during a long PreemptProtect in a front end kernel) does
   not count against a partial request. Here the rest of a request arrives while the kernel stalls, and the maintenance
   pass that runs late, right after the stall, finds both requests older than the timeout: it sends no 408, since bytes
   may still wait for the handler, which then completes the request. A request that stalls on its own still gets a 408
   once the timeout has passed since the end of the kernel's stall (here a second ago): not with a timeout of 5 seconds,
   but with one of half a second. The stall is simulated: its maintenance pass is made late and the requests' bytes
   old. *)
VerificationTest[
    Module[ { id, request, waiting, stalled, partial, result },
        id      = $socketServer[ "ID" ];
        request = socketTestRequest[ $socketServer, socketTestBody[ "ping", 4 ] ];
        waiting = socketTestConnect @ $socketServer;
        stalled = socketTestConnect @ $socketServer;
        socketTestSend[ waiting, Drop[ request, -5 ] ];
        socketTestSend[ stalled, Drop[ request, -5 ] ];
        partial[ ] := Keys @ Select[
            Wolfram`AgentToolsState`SocketServer`$connections,
            #[ "ServerID" ] === id && Wolfram`AgentTools`Server`Socket`Private`partialRequestQ @ # &
        ];
        socketTestEventually[ Length @ partial[ ] === 2 ];
        PreemptProtect[
            socketTestSend[ waiting, Take[ request, -5 ] ];
            Pause[ 0.2 ];
            Scan[ (Wolfram`AgentToolsState`SocketServer`$connections[ #, "LastData" ] = AbsoluteTime[ ] - 60) &, partial[ ] ];
            Wolfram`AgentToolsState`SocketServer`$servers[ id, "LastMaintenance" ] = AbsoluteTime[ ] - 60;
            Wolfram`AgentTools`Server`Socket`Private`socketMaintenance @ id
        ];
        result = {
            socketTestRead[ waiting ][ "JSON", "id" ],
            StringFreeQ[ socketTestQuiet[ stalled, 0.3 ], "408" ],
            socketTestMaintenance[ $socketServer, 5, AbsoluteTime[ ] - 1 ];
            StringFreeQ[ socketTestQuiet[ stalled, 0.3 ], "408" ],
            socketTestMaintenance[ $socketServer, 0.5, AbsoluteTime[ ] - 1 ];
            socketTestRead[ stalled ][ "Status" ]
        };
        socketTestClose /@ { waiting, stalled };
        result
    ],
    { 4, True, True, 408 },
    SameTest -> MatchQ,
    TestID   -> "Framing-StalledRequest-KernelStall@@Tests/SocketServer.wlt:1354,1-1388,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Deferred Calls*)
(* A server whose evaluation function only stores the calls, which the tests then run, reject or cancel. *)
VerificationTest[
    $socketDeferred = { };
    $socketDeferredServer = StartMCPSocketServer[
        $socketTestServerObject,
        "KeepAliveInterval"  -> 0.25,
        "EvaluationFunction" -> Function[ { run, info }, AppendTo[ $socketDeferred, { run, info } ] ]
    ],
    _MCPSocketServerObject,
    SameTest -> MatchQ,
    TestID   -> "Deferred-Start@@Tests/SocketServer.wlt:1394,1-1404,2"
]

(* tools/call: the event stream starts at once and is kept alive until run[] answers the call. *)
VerificationTest[
    $socketClient = socketTestConnect @ $socketDeferredServer;
    socketTestSend[
        $socketClient,
        socketTestRequest[ $socketDeferredServer, socketTestBody[ "tools/call", 41, <| "name" -> "Echo", "arguments" -> <| "text" -> "later" |> |> ] ]
    ];
    {
        socketTestWaitFor[ $socketClient, "Transfer-Encoding: chunked\r\n" ],
        socketTestWaitFor[ $socketClient, ": keepalive" ],
        Length @ $socketDeferred,
        $socketDeferredServer[ "PendingRequests" ]
    },
    { True, True, 1, 1 },
    SameTest -> MatchQ,
    TestID   -> "Deferred-StreamStarted@@Tests/SocketServer.wlt:1407,1-1422,2"
]

VerificationTest[
    $socketDeferred[[ 1, 2 ]],
    KeyValuePattern @ {
        "Method"     -> "tools/call",
        "Name"       -> "Echo",
        "Arguments"  -> <| "text" -> "later" |>,
        "RequestID"  -> 41,
        "Token"      -> $socketDeferredServer[ "Token" ],
        "Server"     -> $socketDeferredServer,
        "ReceivedAt" -> _Real,
        "Reject"     -> _Function,
        "ActiveQ"    -> _Function
    },
    SameTest -> MatchQ,
    TestID   -> "Deferred-Information@@Tests/SocketServer.wlt:1424,1-1439,2"
]

(* Only the "Token" property and the evaluation function's information give the token. The object holds none (it ends up
   in notebooks, with its formatting), and neither do the server's record and its jobs (they end up in failure data). *)
VerificationTest[
    With[ { token = $socketDeferredServer[ "Token" ], id = $socketDeferredServer[ "ID" ] },
        {
            StringQ @ token,
            FreeQ[ $socketDeferredServer, token ],
            StringFreeQ[ ToString[ ToBoxes @ $socketDeferredServer, InputForm ], token ],
            FreeQ[ Wolfram`AgentToolsState`SocketServer`$servers[ id ], token ],
            Length @ Select[ Wolfram`AgentToolsState`SocketServer`$jobs, #[ "ServerID" ] === id & ],
            FreeQ[ Wolfram`AgentToolsState`SocketServer`$jobs, token ]
        }
    ],
    { True, True, True, True, 1, True },
    SameTest -> MatchQ,
    TestID   -> "Secrets-NotInObjectsOrRecords@@Tests/SocketServer.wlt:1443,1-1457,2"
]

VerificationTest[
    Module[ { run, info, active, result, response, again },
        { run, info } = First @ $socketDeferred;
        active   = info[ "ActiveQ" ][ ];
        result   = run[ ];
        response = socketTestRead @ $socketClient;
        again    = run[ ];
        {
            active,
            result,
            response[ "Status" ],
            response[ "Headers", "content-type" ],
            response[ "Events" ],
            response[ "JSON" ] === result,
            again,
            info[ "ActiveQ" ][ ],
            info[ "Reject" ][ "too late" ],
            $socketDeferredServer[ "PendingRequests" ]
        }
    ],
    {
        True,
        <| "jsonrpc" -> "2.0", "id" -> 41, "result" -> <| "content" -> { <| "type" -> "text", "text" -> "later" |> }, "isError" -> False |> |>,
        200,
        "text/event-stream",
        { <| "Comment" -> "keepalive" |>.., <| "event" -> "message", "data" -> _String |> },
        True,
        Null,
        False,
        Null,
        0
    },
    SameTest -> MatchQ,
    TestID   -> "Deferred-Run@@Tests/SocketServer.wlt:1459,1-1493,2"
]

(* The connection can be used again after the event stream. *)
VerificationTest[
    socketTestSend[ $socketClient, socketTestRequest[ $socketDeferredServer, socketTestBody[ "ping", 42 ] ] ];
    socketTestRead[ $socketClient ][ "JSON", "id" ],
    42,
    SameTest -> MatchQ,
    TestID   -> "Deferred-ConnectionReused@@Tests/SocketServer.wlt:1496,1-1502,2"
]

(* A client that only accepts JSON gets nothing until the call has been answered. *)
VerificationTest[
    $socketDeferred = { };
    socketTestSend[
        $socketClient,
        socketTestRequest[
            $socketDeferredServer,
            socketTestBody[ "tools/call", 43, <| "name" -> "Echo", "arguments" -> <| "text" -> "json" |> |> ],
            "Headers" -> { "Accept" -> "application/json" }
        ]
    ];
    {
        socketTestEventually[ Length @ $socketDeferred === 1 ],
        socketTestQuiet[ $socketClient, 0.75 ],
        $socketDeferred[[ 1, 1 ]][ ][ "id" ],
        With[ { response = socketTestRead @ $socketClient }, { response[ "Headers", "content-type" ], response[[ "JSON", "result", "content", 1, "text" ]] } ]
    },
    { True, "", 43, { "application/json", "json" } },
    SameTest -> MatchQ,
    TestID   -> "Deferred-JSONOnly@@Tests/SocketServer.wlt:1505,1-1524,2"
]

(* Reject answers without running the call. *)
VerificationTest[
    $socketDeferred = { };
    socketTestSend[
        $socketClient,
        socketTestRequest[ $socketDeferredServer, socketTestBody[ "tools/call", 44, <| "name" -> "Echo", "arguments" -> <| "text" -> "x" |> |> ] ]
    ];
    socketTestEventually[ Length @ $socketDeferred === 1 ];
    {
        $socketDeferred[[ 1, 2 ]][ "Reject" ][ "Not now." ],
        socketTestRead[ $socketClient ][ "JSON" ],
        $socketDeferred[[ 1, 1 ]][ ],
        $socketDeferred[[ 1, 2 ]][ "ActiveQ" ][ ]
    },
    {
        <| "jsonrpc" -> "2.0", "id" -> 44, "result" -> <| "content" -> { <| "type" -> "text", "text" -> "Not now." |> }, "isError" -> True |> |>,
        <| "jsonrpc" -> "2.0", "id" -> 44, "result" -> <| "content" -> { <| "type" -> "text", "text" -> "Not now." |> }, "isError" -> True |> |>,
        Null,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "Deferred-Reject@@Tests/SocketServer.wlt:1527,1-1548,2"
]

VerificationTest[
    $socketDeferred = { };
    socketTestSend[ $socketClient, socketTestRequest[ $socketDeferredServer, socketTestBody[ "prompts/get", 45, <| "name" -> "Greeting" |> ] ] ];
    socketTestEventually[ Length @ $socketDeferred === 1 ];
    $socketDeferred[[ 1, 2 ]][ "Reject" ][ "No prompts today." ];
    socketTestRead[ $socketClient ][ "JSON" ],
    <| "jsonrpc" -> "2.0", "id" -> 45, "error" -> <| "code" -> -32603, "message" -> "No prompts today." |> |>,
    SameTest -> MatchQ,
    TestID   -> "Deferred-Reject-Prompt@@Tests/SocketServer.wlt:1550,1-1559,2"
]

VerificationTest[
    $socketDeferred = { };
    socketTestSend[ $socketClient, socketTestRequest[ $socketDeferredServer, socketTestBody[ "prompts/get", 46, <| "name" -> "Greeting" |> ] ] ];
    socketTestEventually[ Length @ $socketDeferred === 1 ];
    { $socketDeferred[[ 1, 2 ]][ "Method" ], $socketDeferred[[ 1, 1 ]][ ][[ "result", "messages", 1, "content", "text" ]], socketTestRead[ $socketClient ][[ "JSON", "result", "messages", 1, "content", "text" ]] },
    { "prompts/get", "Hello!", "Hello!" },
    SameTest -> MatchQ,
    TestID   -> "Deferred-Prompt@@Tests/SocketServer.wlt:1561,1-1569,2"
]

(* An abort while the call evaluates gives an error result. *)
VerificationTest[
    $socketDeferred = { };
    socketTestSend[ $socketClient, socketTestRequest[ $socketDeferredServer, socketTestBody[ "tools/call", 47, <| "name" -> "Aborter", "arguments" -> <| |> |> ] ] ];
    socketTestEventually[ Length @ $socketDeferred === 1 ];
    { $socketDeferred[[ 1, 1 ]][ ][ "result" ], socketTestRead[ $socketClient ][ "JSON", "result", "isError" ] },
    { <| "content" -> { <| "type" -> "text", "text" -> "The tool call was aborted by the user." |> }, "isError" -> True |>, True },
    SameTest -> MatchQ,
    TestID   -> "Deferred-Abort@@Tests/SocketServer.wlt:1572,1-1580,2"
]

(* An abort that the call's CheckAbort does not catch (here a TimeConstrained around run[]) still answers the call. *)
VerificationTest[
    $socketDeferred = { };
    socketTestSend[ $socketClient, socketTestRequest[ $socketDeferredServer, socketTestBody[ "tools/call", 60, <| "name" -> "Sleep", "arguments" -> <| "seconds" -> 30 |> |> ] ] ];
    socketTestEventually[ Length @ $socketDeferred === 1 ];
    {
        TimeConstrained[ $socketDeferred[[ 1, 1 ]][ ], 0.5, "TimedOut" ],
        socketTestRead[ $socketClient ][ "JSON", "result" ],
        $socketDeferred[[ 1, 2 ]][ "ActiveQ" ][ ],
        $socketDeferredServer[ "PendingRequests" ]
    },
    {
        "TimedOut",
        <| "content" -> { <| "type" -> "text", "text" -> "The tool call was aborted by the user." |> }, "isError" -> True |>,
        False,
        0
    },
    SameTest -> MatchQ,
    TestID   -> "Deferred-AbortOutsideCall@@Tests/SocketServer.wlt:1583,1-1601,2"
]

(* notifications/cancelled, sent on another connection, ends the stream without a response. *)
VerificationTest[
    $socketDeferred = { };
    socketTestSend[ $socketClient, socketTestRequest[ $socketDeferredServer, socketTestBody[ "tools/call", 48, <| "name" -> "Echo", "arguments" -> <| "text" -> "x" |> |> ] ] ];
    socketTestEventually[ Length @ $socketDeferred === 1 ];
    {
        socketTestStatus[ $socketDeferredServer, socketTestBody[ "notifications/cancelled", None, <| "requestId" -> 48, "reason" -> "Timed out" |> ] ],
        With[ { response = socketTestRead @ $socketClient },
            { response[ "Status" ], response[ "JSON" ], MatchQ[ response[ "Events" ], { <| "Comment" -> "keepalive" |>... } ] }
        ],
        $socketDeferred[[ 1, 2 ]][ "ActiveQ" ][ ],
        $socketDeferred[[ 1, 1 ]][ ],
        $socketDeferredServer[ "PendingRequests" ]
    },
    { 202, { 200, None, True }, False, Null, 0 },
    SameTest -> MatchQ,
    TestID   -> "Deferred-Cancelled@@Tests/SocketServer.wlt:1604,1-1620,2"
]

(* JSON-RPC IDs are only unique per client: a cancellation only applies to calls made with the same bearer token. A
   call cancelled before its event stream started is accepted without a body. *)
VerificationTest[
    Module[ { calls = { }, server, client, result },
        server = StartMCPSocketServer[
            $socketTestServerObject,
            "Authentication"     -> (True &),
            "EvaluationFunction" -> Function[ { run, info }, AppendTo[ calls, { run, info } ] ]
        ];
        client = socketTestConnect @ server;
        socketTestSend[
            client,
            socketTestRequest[
                server,
                socketTestBody[ "tools/call", 7, <| "name" -> "Echo", "arguments" -> <| "text" -> "x" |> |> ],
                "Headers" -> { "Authorization" -> "Bearer client-a", "Accept" -> "application/json" }
            ]
        ];
        socketTestEventually[ Length @ calls === 1 ];
        result = {
            calls[[ 1, 2, "Token" ]],
            socketTestStatus[ server, socketTestBody[ "notifications/cancelled", None, <| "requestId" -> 7 |> ], "Headers" -> { "Authorization" -> "Bearer client-b" } ],
            calls[[ 1, 2 ]][ "ActiveQ" ][ ],
            socketTestStatus[ server, socketTestBody[ "notifications/cancelled", None, <| "requestId" -> 7 |> ], "Headers" -> { "Authorization" -> "Bearer client-a" } ],
            socketTestRead[ client ][[ { "Status", "Body" } ]],
            calls[[ 1, 2 ]][ "ActiveQ" ][ ]
        };
        socketTestClose @ client;
        DeleteObject @ server;
        result
    ],
    { "client-a", 202, True, 202, <| "Status" -> 202, "Body" -> "" |>, False },
    SameTest -> MatchQ,
    TestID   -> "Deferred-Cancelled-SameTokenOnly@@Tests/SocketServer.wlt:1624,1-1656,2"
]

(* A request pipelined behind a deferred call is answered after it. *)
VerificationTest[
    $socketDeferred = { };
    socketTestSend[
        $socketClient,
        Join[
            socketTestRequest[ $socketDeferredServer, socketTestBody[ "tools/call", 49, <| "name" -> "Echo", "arguments" -> <| "text" -> "first" |> |> ] ],
            socketTestRequest[ $socketDeferredServer, socketTestBody[ "ping", 50 ] ]
        ]
    ];
    socketTestEventually[ Length @ $socketDeferred === 1 ];
    socketTestQuiet[ $socketClient, 0.5 ];
    $socketDeferred[[ 1, 1 ]][ ];
    { socketTestRead[ $socketClient ][ "JSON", "id" ], socketTestRead[ $socketClient ][ "JSON", "id" ] },
    { 49, 50 },
    SameTest -> MatchQ,
    TestID   -> "Deferred-PipelinedRequestWaits@@Tests/SocketServer.wlt:1659,1-1675,2"
]

(* A client that disconnects: the call becomes inactive and is dropped. *)
VerificationTest[
    $socketDeferred = { };
    socketTestSend[ $socketClient, socketTestRequest[ $socketDeferredServer, socketTestBody[ "tools/call", 51, <| "name" -> "Echo", "arguments" -> <| "text" -> "x" |> |> ] ] ];
    socketTestEventually[ Length @ $socketDeferred === 1 ];
    socketTestClose @ $socketClient;
    {
        socketTestEventually[ ! $socketDeferred[[ 1, 2 ]][ "ActiveQ" ][ ] ],
        socketTestEventually[ $socketDeferredServer[ "PendingRequests" ] === 0 ],
        $socketDeferred[[ 1, 1 ]][ ]
    },
    { True, True, Null },
    SameTest -> MatchQ,
    TestID   -> "Deferred-Disconnected@@Tests/SocketServer.wlt:1678,1-1691,2"
]

(* An evaluation function that fails rejects the call. *)
VerificationTest[
    Module[ { server, response },
        server   = StartMCPSocketServer[ $socketTestServerObject, "EvaluationFunction" -> Function[ Throw[ "oops" ] ] ];
        response = socketTestJSON[ server, socketTestBody[ "tools/call", 52, <| "name" -> "Echo", "arguments" -> <| "text" -> "x" |> |> ] ];
        DeleteObject @ server;
        response[ "result" ]
    ],
    <| "content" -> { <| "type" -> "text", "text" -> _String |> }, "isError" -> True |>,
    SameTest -> MatchQ,
    TestID   -> "Deferred-EvaluationFunctionFails@@Tests/SocketServer.wlt:1694,1-1704,2"
]

(* run[] never leaves a call unanswered. An internal failure of the call's evaluation is answered with an internal
   error, which run[] gives. An internal failure while run[] claims the call makes it give a Failure, and the call is
   answered with an internal error all the same; one while it answers the call makes it give a Failure, and the
   connection is closed if no response could be written. Either way the call is no longer active. The failures are
   logged to a temporary directory. *)
VerificationTest[
    Module[ { calls = { }, server, client, logs, call, evaluating, claiming, answering, result },
        server = StartMCPSocketServer[
            $socketTestServerObject,
            "EvaluationFunction" -> Function[ { run, info }, AppendTo[ calls, { run, info } ] ]
        ];
        client = socketTestConnect @ server;
        logs   = CreateDirectory[ ];
        call[ id_, eval_ ] := (
            socketTestSend[
                client,
                socketTestRequest[ server, socketTestBody[ "tools/call", id, <| "name" -> "Echo", "arguments" -> <| "text" -> "x" |> |> ] ]
            ];
            socketTestEventually[ Length @ calls === id ];
            { Quiet @ eval @ calls[[ id, 1 ]], calls[[ id, 2 ]][ "ActiveQ" ][ ] }
        );
        Block[ { Wolfram`AgentTools`Common`Private`$internalFailureLogDirectory = logs },
            evaluating = Internal`InheritedBlock[ { Wolfram`AgentTools`Common`handleMethod },
                PrependTo[
                    DownValues @ Wolfram`AgentTools`Common`handleMethod,
                    HoldPattern @ Wolfram`AgentTools`Common`handleMethod[ "tools/call", msg_, req_ ] :>
                        Wolfram`AgentTools`Common`throwInternalFailure @ Wolfram`AgentTools`Common`handleMethod[ "tools/call", msg, req ]
                ];
                call[ 1, #[ ] & ]
            ];
            evaluating = Append[ evaluating, socketTestRead[ client ][ "JSON" ] ];
            claiming = Internal`InheritedBlock[ { Wolfram`AgentTools`Server`Socket`Private`claimSocketJob },
                PrependTo[
                    DownValues @ Wolfram`AgentTools`Server`Socket`Private`claimSocketJob,
                    HoldPattern @ Wolfram`AgentTools`Server`Socket`Private`claimSocketJob[ id_String ] :>
                        Wolfram`AgentTools`Common`throwInternalFailure @ Wolfram`AgentTools`Server`Socket`Private`claimSocketJob @ id
                ];
                call[ 2, #[ ] & ]
            ];
            claiming = Append[ claiming, socketTestRead[ client ][ "JSON" ] ];
            answering = Internal`InheritedBlock[ { Wolfram`AgentTools`Server`Socket`Private`encodeJobOutcome },
                PrependTo[
                    DownValues @ Wolfram`AgentTools`Server`Socket`Private`encodeJobOutcome,
                    HoldPattern @ Wolfram`AgentTools`Server`Socket`Private`encodeJobOutcome[ job_, outcome_ ] :>
                        Wolfram`AgentTools`Common`throwInternalFailure @ Wolfram`AgentTools`Server`Socket`Private`encodeJobOutcome[ job, outcome ]
                ];
                call[ 3, #[ ] & ]
            ];
            answering = Append[ answering, socketTestEventually[ ! MemberQ[ server[ "Listener" ][ "Socket" ][ "ConnectedClients" ], _ ] ] ]
        ];
        result = {
            evaluating,
            claiming,
            answering,
            calls[[ 2, 1 ]][ ],
            server[ "PendingRequests" ],
            Length @ FileNames[ "*.mx", logs ]
        };
        socketTestClose @ client;
        DeleteObject @ server;
        DeleteDirectory[ logs, DeleteContents -> True ];
        result
    ],
    {
        {
            KeyValuePattern @ { "id" -> 1, "error" -> KeyValuePattern[ "code" -> -32603 ] },
            False,
            KeyValuePattern @ { "id" -> 1, "error" -> KeyValuePattern[ "code" -> -32603 ] }
        },
        { _Failure, False, KeyValuePattern @ { "id" -> 2, "error" -> KeyValuePattern[ "code" -> -32603 ] } },
        { _Failure, False, True },
        Null,
        0,
        3
    },
    SameTest -> MatchQ,
    TestID   -> "Deferred-RunInternalFailure@@Tests/SocketServer.wlt:1711,1-1783,2"
]

(* DeleteObject answers pending calls before it closes their connections. *)
VerificationTest[
    $socketDeferred = { };
    $socketClient = socketTestConnect @ $socketDeferredServer;
    socketTestSend[ $socketClient, socketTestRequest[ $socketDeferredServer, socketTestBody[ "tools/call", 53, <| "name" -> "Echo", "arguments" -> <| "text" -> "x" |> |> ] ] ];
    socketTestEventually[ Length @ $socketDeferred === 1 ];
    socketTestWaitFor[ $socketClient, "Transfer-Encoding: chunked\r\n" ];
    {
        DeleteObject @ $socketDeferredServer,
        socketTestRead[ $socketClient ][ "JSON", "result" ],
        $socketDeferred[[ 1, 2 ]][ "ActiveQ" ][ ],
        $socketDeferred[[ 1, 1 ]][ ],
        $socketDeferredServer[ "Running" ],
        $socketDeferredServer[ "PendingRequests" ]
    },
    {
        Null,
        <| "content" -> { <| "type" -> "text", "text" -> "The MCP server was stopped." |> }, "isError" -> True |>,
        False,
        Null,
        False,
        0
    },
    SameTest -> MatchQ,
    TestID   -> "Deferred-DeleteObject@@Tests/SocketServer.wlt:1786,1-1810,2"
]

VerificationTest[
    socketTestClose @ $socketClient,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Deferred-Cleanup@@Tests/SocketServer.wlt:1812,1-1817,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Encoding*)
(* A result that cannot be encoded as JSON is answered with an error, rather than leaving the client without a
   response. *)
VerificationTest[
    Module[ { server, response },
        server   = StartMCPSocketServer @ $socketEncodingTestServerObject;
        response = socketTestJSON[ server, socketTestBody[ "tools/call", 1, <| "name" -> "BadContent", "arguments" -> <| |> |> ] ];
        DeleteObject @ server;
        response
    ],
    <| "jsonrpc" -> "2.0", "id" -> 1, "result" -> $socketEncodingFailedResult |>,
    SameTest -> MatchQ,
    TestID   -> "Encoding-Immediate@@Tests/SocketServer.wlt:1824,1-1834,2"
]

(* Deferred: the event stream ends with the error (which run[] gives), and the connection can be used again; a client
   that only accepts JSON gets the error as JSON. *)
VerificationTest[
    Module[ { calls = { }, server, client, streamed, result, final, reused, jsonOnly },
        server = StartMCPSocketServer[
            $socketEncodingTestServerObject,
            "KeepAliveInterval"  -> 0.25,
            "EvaluationFunction" -> Function[ { run, info }, AppendTo[ calls, run ] ]
        ];
        client = socketTestConnect @ server;
        socketTestSend[ client, socketTestRequest[ server, socketTestBody[ "tools/call", 1, <| "name" -> "BadContent", "arguments" -> <| |> |> ] ] ];
        streamed = socketTestWaitFor[ client, "Transfer-Encoding: chunked\r\n" ];
        result   = calls[[ 1 ]][ ];
        final    = socketTestRead @ client;
        socketTestSend[ client, socketTestRequest[ server, socketTestBody[ "ping", 2 ] ] ];
        reused = socketTestRead[ client ][ "JSON", "id" ];
        socketTestSend[
            client,
            socketTestRequest[
                server,
                socketTestBody[ "tools/call", 3, <| "name" -> "BadContent", "arguments" -> <| |> |> ],
                "Headers" -> { "Accept" -> "application/json" }
            ]
        ];
        socketTestEventually[ Length @ calls === 2 ];
        calls[[ 2 ]][ ];
        jsonOnly = socketTestRead @ client;
        socketTestClose @ client;
        DeleteObject @ server;
        { streamed, result, final[ "JSON" ] === result, reused, jsonOnly[ "Headers", "content-type" ], jsonOnly[ "JSON", "result" ] }
    ],
    {
        True,
        <| "jsonrpc" -> "2.0", "id" -> 1, "result" -> $socketEncodingFailedResult |>,
        True,
        2,
        "application/json",
        $socketEncodingFailedResult
    },
    SameTest -> MatchQ,
    TestID   -> "Encoding-Deferred@@Tests/SocketServer.wlt:1838,1-1877,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Options*)
VerificationTest[
    Block[ { $Notebooks = True },
        {
            Wolfram`AgentTools`Server`Socket`Private`socketToolOptions[ Automatic, <| |> ],
            Wolfram`AgentTools`Server`Socket`Private`socketToolOptions[ Automatic, <| "WolframLanguageEvaluator" -> <| "Method" -> "Session", "TimeConstraint" -> 5 |> |> ],
            Wolfram`AgentTools`Server`Socket`Private`socketToolOptions[ <| "WolframLanguageEvaluator" -> <| "Method" -> "Session" |> |>, <| |> ],
            Wolfram`AgentTools`Server`Socket`Private`socketToolOptions[ <| "WolframLanguageEvaluator" -> <| "TimeConstraint" -> 5 |> |>, <| |> ]
        }
    ],
    {
        <| "WolframLanguageEvaluator" -> <| "Method" -> "Local" |> |>,
        <| "WolframLanguageEvaluator" -> <| "Method" -> "Local", "TimeConstraint" -> 5 |> |>,
        <| "WolframLanguageEvaluator" -> <| "Method" -> "Session" |> |>,
        <| "WolframLanguageEvaluator" -> <| "TimeConstraint" -> 5, "Method" -> "Local" |> |>
    },
    SameTest -> MatchQ,
    TestID   -> "ToolOptions-FrontEndKernel@@Tests/SocketServer.wlt:1882,1-1899,2"
]

VerificationTest[
    Block[ { $Notebooks = False },
        Wolfram`AgentTools`Server`Socket`Private`socketToolOptions[ Automatic, <| "WolframLanguageEvaluator" -> <| "Method" -> "Session" |> |> ]
    ],
    <| "WolframLanguageEvaluator" -> <| "Method" -> "Session" |> |>,
    SameTest -> MatchQ,
    TestID   -> "ToolOptions-StandaloneKernel@@Tests/SocketServer.wlt:1901,1-1908,2"
]

(* Tool calls see the server's tool options. *)
VerificationTest[
    Module[ { server, result },
        server = StartMCPSocketServer[
            MCPServerObject @ <|
                "Name"         -> "SocketServerToolOptionsTest",
                "Location"     -> None,
                "LLMEvaluator" -> <| "Tools" -> { LLMTool[ "ShowToolOptions", { }, ToString[ Wolfram`AgentTools`Common`$toolOptions, InputForm ] & ] } |>
            |>,
            "ToolOptions" -> <| "MyTool" -> <| "Setting" -> 1 |> |>
        ];
        result = socketTestJSON[ server, socketTestBody[ "tools/call", 1, <| "name" -> "ShowToolOptions", "arguments" -> <| |> |> ] ];
        DeleteObject @ server;
        StringContainsQ[ result[[ "result", "content", 1, "text" ]], "\"MyTool\" -> <|\"Setting\" -> 1|>" ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ToolOptions-UsedByTools@@Tests/SocketServer.wlt:1911,1-1928,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Robustness*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Scopes*)
(* The entry points have error scopes of their own. Inside the catchTop of another AgentTools evaluation (as a handler or
   a task sees it when it interrupts one), they still return their failures, rather than throwing them into that
   evaluation, and they leave its failure state alone. *)
VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ {
        Quiet @ StartMCPSocketServer[ $socketTestServerObject, "Port" -> 0 ],
        Quiet @ $socketServer[ 123 ],
        Wolfram`AgentTools`Common`Private`$failed
    },
    { _Failure, _Failure, False },
    SameTest -> MatchQ,
    TestID   -> "ErrorScope-Isolated@@Tests/SocketServer.wlt:1940,1-1949,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Internal Failures*)
(* An internal failure while a request is read (here an authentication setting that the server does not know, so that
   the check of the request's bearer token fails) answers the request with a 500 and closes its connection, rather than
   leaving its client waiting. The failure is logged (to a temporary directory) without the token: not in the failing
   call, which gets the token on its own, and not in the request's bytes. The directory is private to the user. *)
VerificationTest[
    Module[ { server, token, logs, response, files, text, result },
        server = StartMCPSocketServer @ $socketTestServerObject;
        token  = server[ "Token" ];
        logs   = FileNameJoin @ { CreateDirectory[ ], "InternalFailures" };
        Wolfram`AgentToolsState`SocketServer`$servers[ server[ "ID" ], "Authentication" ] = <| "Type" -> "Unknown" |>;
        response = Block[ { Wolfram`AgentTools`Common`Private`$internalFailureLogDirectory = logs },
            Quiet @ socketTestExchange[ server, socketTestBody[ "ping", 1 ] ]
        ];
        files = FileNames[ "*.mx", logs ];
        text  = ByteArrayToString[ Join @@ ReadByteArray /@ files, "ISO8859-1" ];
        result = {
            response[ "Status" ],
            response[ "Headers", "connection" ],
            Length @ files,
            StringContainsQ[ text, "Unknown" ],
            StringFreeQ[ text, token ],
            FreeQ[ Import[ First @ files, "MX" ], token ],
            If[ $OperatingSystem === "Windows",
                "drwx------",
                StringTake[ RunProcess[ { "ls", "-ld", logs }, "StandardOutput" ], 10 ]
            ],
            Select[ Wolfram`AgentToolsState`SocketServer`$connections, #[ "ServerID" ] === server[ "ID" ] & ]
        };
        DeleteObject @ server;
        DeleteDirectory[ DirectoryName @ logs, DeleteContents -> True ];
        result
    ],
    { 500, "close", 1, True, True, True, "drwx------", <| |> },
    SameTest -> MatchQ,
    TestID   -> "InternalFailure-RequestPath-Redacted@@Tests/SocketServer.wlt:1958,1-1989,2"
]

(* The same failure for a request whose head arrives in two parts, split inside the bearer token: the token is
   registered as a secret, so no part of it of 8 or more characters is logged, although neither part of the head holds
   all of it. *)
VerificationTest[
    Module[ { server, token, logs, request, cut, client, response, files, text, result },
        server  = StartMCPSocketServer @ $socketTestServerObject;
        token   = server[ "Token" ];
        logs    = FileNameJoin @ { CreateDirectory[ ], "InternalFailures" };
        request = socketTestRequest[ server, socketTestBody[ "ping", 1 ] ];
        cut     = StringPosition[ ByteArrayToString[ request, "ISO8859-1" ], "Bearer " ][[ 1, 2 ]] + 10;
        Wolfram`AgentToolsState`SocketServer`$servers[ server[ "ID" ], "Authentication" ] = <| "Type" -> "Unknown" |>;
        response = Quiet @ Block[ { Wolfram`AgentTools`Common`Private`$internalFailureLogDirectory = logs },
            client = socketTestConnect @ server;
            socketTestSend[ client, Take[ request, cut ] ];
            socketTestEventually @ AnyTrue[
                Wolfram`AgentToolsState`SocketServer`$connections,
                #[ "ServerID" ] === server[ "ID" ] && Length @ #[ "Head" ] === cut &
            ];
            socketTestSend[ client, Drop[ request, cut ] ];
            socketTestRead @ client
        ];
        socketTestClose @ client;
        files = FileNames[ "*.mx", logs ];
        text  = ByteArrayToString[ Join @@ ReadByteArray /@ files, "ISO8859-1" ];
        result = {
            response[ "Status" ],
            Length @ files,
            StringContainsQ[ text, "authorizedQ" ],
            StringFreeQ[ text, StringPartition[ token, 8, 1 ] ]
        };
        DeleteObject @ server;
        DeleteDirectory[ DirectoryName @ logs, DeleteContents -> True ];
        result
    ],
    { 500, 1, True, True },
    SameTest -> MatchQ,
    TestID   -> "InternalFailure-SplitToken-Redacted@@Tests/SocketServer.wlt:1994,1-2028,2"
]

(* A server that authenticates with a function, as Chatbook's does, has no token of its own, so only the check of the
   request head registers the request's bearer token. The same failure logs no part of it of 8 or more characters, nor
   all of it if it is shorter (here a token of 64 and one of 7 characters), and does not put it into the text of the
   bug report either. *)
VerificationTest[
    Module[ { server, exchange, result },
        server = StartMCPSocketServer[ $socketTestServerObject, "Authentication" -> (StringQ[ # ] &) ];
        Wolfram`AgentToolsState`SocketServer`$servers[ server[ "ID" ], "Authentication" ] = <| "Type" -> "Unknown" |>;
        exchange[ token_String ] := Module[ { logs, response, files, text, pieces, data },
            logs     = FileNameJoin @ { CreateDirectory[ ], "InternalFailures" };
            response = Block[ { Wolfram`AgentTools`Common`Private`$internalFailureLogDirectory = logs },
                Quiet @ socketTestExchange[
                    server,
                    socketTestBody[ "ping", 1 ],
                    "Headers" -> { "Authorization" -> "Bearer " <> token }
                ]
            ];
            files  = FileNames[ "*.mx", logs ];
            text   = ByteArrayToString[ Join @@ ReadByteArray /@ files, "ISO8859-1" ];
            pieces = StringPartition[ token, Min[ 8, StringLength @ token ], 1 ];
            data   = {
                response[ "Status" ],
                Length @ files,
                StringContainsQ[ text, "authorizedQ" ],
                StringFreeQ[ text, pieces ],
                FreeQ[ Import[ First @ files, "MX" ], token ],
                StringFreeQ[ $LastAgentToolsFailureText, pieces ]
            };
            DeleteDirectory[ DirectoryName @ logs, DeleteContents -> True ];
            data
        ];
        result = exchange /@ { IntegerString[ Hash[ "fake", "SHA256" ], 16, 64 ], "Zq7#Kp2" };
        DeleteObject @ server;
        result
    ],
    { { 500, 1, True, True, True, True }, { 500, 1, True, True, True, True } },
    SameTest -> MatchQ,
    TestID   -> "InternalFailure-FunctionAuthentication-Redacted@@Tests/SocketServer.wlt:2034,1-2068,2"
]

(* The same for an internal failure after the head was checked, here while a cancellation is handled: there, only the
   handling of the request registers its bearer token. *)
VerificationTest[
    Module[ { server, token, logs, response, files, text, result },
        server   = StartMCPSocketServer[ $socketTestServerObject, "Authentication" -> (StringQ[ # ] &) ];
        token    = IntegerString[ Hash[ "fake", "SHA256" ], 16, 64 ];
        logs     = FileNameJoin @ { CreateDirectory[ ], "InternalFailures" };
        response = Internal`InheritedBlock[ { Wolfram`AgentTools`Server`Socket`Private`cancelSocketJobs },
            PrependTo[
                DownValues @ Wolfram`AgentTools`Server`Socket`Private`cancelSocketJobs,
                HoldPattern @ Wolfram`AgentTools`Server`Socket`Private`cancelSocketJobs[ s_, t_, m_ ] :>
                    Wolfram`AgentTools`Common`throwInternalFailure @ Wolfram`AgentTools`Server`Socket`Private`cancelSocketJobs[ s, t, m ]
            ];
            Block[ { Wolfram`AgentTools`Common`Private`$internalFailureLogDirectory = logs },
                Quiet @ socketTestExchange[
                    server,
                    socketTestBody[ "notifications/cancelled", None, <| "requestId" -> 1 |> ],
                    "Headers" -> { "Authorization" -> "Bearer " <> token }
                ]
            ]
        ];
        files  = FileNames[ "*.mx", logs ];
        text   = ByteArrayToString[ Join @@ ReadByteArray /@ files, "ISO8859-1" ];
        result = {
            response[ "Status" ],
            Length @ files,
            StringContainsQ[ text, "cancelSocketJobs" ],
            StringFreeQ[ text, StringPartition[ token, 8, 1 ] ],
            FreeQ[ Import[ First @ files, "MX" ], token ],
            StringFreeQ[ $LastAgentToolsFailureText, StringPartition[ token, 8, 1 ] ]
        };
        DeleteObject @ server;
        DeleteDirectory[ DirectoryName @ logs, DeleteContents -> True ];
        result
    ],
    { 500, 1, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "InternalFailure-NotificationHandling-Redacted@@Tests/SocketServer.wlt:2072,1-2108,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Starting*)
(* An abort while a server starts is raised once the server has started, and the start then stops the server again
   before the abort goes on: no server, task, listener or token is left behind, and the abort still reaches the caller.
   The abort comes from the part of the start that aborts cannot interrupt: an Abort[ ] there (as from an Alt+.), or a
   TimeConstrained around StartMCPSocketServer whose time runs out during a delay there. *)
VerificationTest[
    Module[ { started, injected, leftovers },
        injected[ start_, delay_, abort_ ] := (
            started = None;
            Internal`InheritedBlock[ { Wolfram`AgentTools`Server`Socket`Private`createMCPSocketServerObject },
                PrependTo[
                    DownValues @ Wolfram`AgentTools`Server`Socket`Private`createMCPSocketServerObject,
                    HoldPattern @ Wolfram`AgentTools`Server`Socket`Private`createMCPSocketServerObject[ data_Association ] :>
                        Null /; (started = data; Pause[ delay ]; If[ abort, Abort[ ] ]; False)
                ];
                start[ ]
            ]
        );
        leftovers[ ] := {
            AssociationQ @ started,
            KeyExistsQ[ Wolfram`AgentToolsState`SocketServer`$servers, started[ "ID" ] ],
            KeyExistsQ[ Wolfram`AgentToolsState`SocketServer`$tokens, started[ "ID" ] ],
            Wolfram`AgentTools`Server`Socket`Private`maintenanceTasks @ started[ "ID" ],
            MemberQ[ Sockets[ ], started[ "Listener" ][ "Socket" ] ]
        };
        {
            injected[ CheckAbort[ StartMCPSocketServer @ $socketTestServerObject, "Aborted" ] &, 0, True ],
            leftovers[ ],
            injected[ TimeConstrained[ StartMCPSocketServer @ $socketTestServerObject, 1, "TimedOut" ] &, 2, False ],
            leftovers[ ]
        }
    ],
    { "Aborted", { True, False, False, { }, False }, "TimedOut", { True, False, False, { }, False } },
    SameTest -> MatchQ,
    TestID   -> "Start-AbortSafe@@Tests/SocketServer.wlt:2117,1-2147,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Stopping*)
(* An abort while a server stops does not leave its listener or task behind. The abort is raised while the pending call
   is answered; it takes effect once the server has stopped. *)
VerificationTest[
    Module[ { calls = { }, server, client, aborted, result },
        server = StartMCPSocketServer[ $socketTestServerObject, "EvaluationFunction" -> Function[ { run, info }, AppendTo[ calls, run ] ] ];
        client = socketTestConnect @ server;
        socketTestSend[ client, socketTestRequest[ server, socketTestBody[ "tools/call", 1, <| "name" -> "Echo", "arguments" -> <| "text" -> "x" |> |> ] ] ];
        socketTestEventually[ Length @ calls === 1 ];
        aborted = Internal`InheritedBlock[ { Wolfram`AgentTools`Server`Socket`Private`writeSocket },
            DownValues @ Wolfram`AgentTools`Server`Socket`Private`writeSocket = Prepend[
                DownValues @ Wolfram`AgentTools`Server`Socket`Private`writeSocket,
                HoldPattern @ Wolfram`AgentTools`Server`Socket`Private`writeSocket[ sock_, bytes_ ] :> (
                    Abort[ ];
                    Quiet @ SocketWriteMessage[ sock, bytes ]
                ) /; StringContainsQ[ ByteArrayToString[ bytes, "ISO8859-1" ], "The MCP server was stopped." ]
            ];
            CheckAbort[ DeleteObject @ server, "Aborted" ]
        ];
        result = {
            aborted,
            server[ "Running" ],
            MemberQ[ Sockets[ ], server[ "Listener" ][ "Socket" ] ],
            Wolfram`AgentTools`Server`Socket`Private`maintenanceTasks @ server[ "ID" ],
            socketTestRead[ client ][[ "JSON", "result", "content", 1, "text" ]]
        };
        socketTestClose @ client;
        result
    ],
    { "Aborted", False, False, { }, "The MCP server was stopped." },
    SameTest -> MatchQ,
    TestID   -> "Stop-AbortSafe@@Tests/SocketServer.wlt:2154,1-2183,2"
]

(* A server whose record was lost (as to a reload of an older version of the paclet): its clients are not left waiting
   for responses, and DeleteObject still removes its listener and its task. *)
VerificationTest[
    Module[ { server, client, closed },
        server = StartMCPSocketServer @ $socketTestServerObject;
        KeyDropFrom[ Wolfram`AgentToolsState`SocketServer`$servers, server[ "ID" ] ];
        client = socketTestConnect @ server;
        socketTestSend[ client, socketTestRequest[ server, socketTestBody[ "ping", 1 ] ] ];
        closed = socketTestEventually[ server[ "Listener" ][ "Socket" ][ "ConnectedClients" ] === { } ];
        socketTestClose @ client;
        {
            closed,
            Length @ Wolfram`AgentTools`Server`Socket`Private`maintenanceTasks @ server[ "ID" ],
            DeleteObject @ server,
            MemberQ[ Sockets[ ], server[ "Listener" ][ "Socket" ] ],
            Wolfram`AgentTools`Server`Socket`Private`maintenanceTasks @ server[ "ID" ]
        }
    ],
    { True, 1, Null, False, { } },
    SameTest -> MatchQ,
    TestID   -> "Stop-LostRecord@@Tests/SocketServer.wlt:2187,1-2206,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server State*)
(* The state of the running servers is outside the paclet's contexts, which a reload clears and its MX file restores. *)
VerificationTest[
    {
        Context @ Wolfram`AgentToolsState`SocketServer`$servers,
        Select[ Wolfram`AgentTools`$AgentToolsSymbolNames, StringContainsQ[ "AgentToolsState" ] ]
    },
    { "Wolfram`AgentToolsState`SocketServer`", { } },
    SameTest -> MatchQ,
    TestID   -> "State-OutsidePacletContexts@@Tests/SocketServer.wlt:2212,1-2220,2"
]

(* Loading the MX file runs no code: the entry points create the state if it is not there. *)
VerificationTest[
    Block[
        {
            Wolfram`AgentToolsState`SocketServer`$servers,
            Wolfram`AgentToolsState`SocketServer`$connections,
            Wolfram`AgentToolsState`SocketServer`$jobs,
            Wolfram`AgentToolsState`SocketServer`$tokens
        },
        {
            $socketServer[ "Running" ],
            AssociationQ /@ {
                Wolfram`AgentToolsState`SocketServer`$servers,
                Wolfram`AgentToolsState`SocketServer`$connections,
                Wolfram`AgentToolsState`SocketServer`$jobs,
                Wolfram`AgentToolsState`SocketServer`$tokens
            }
        }
    ],
    { False, { True, True, True, True } },
    SameTest -> MatchQ,
    TestID   -> "State-CreatedOnDemand@@Tests/SocketServer.wlt:2223,1-2244,2"
]

(* Reloading the paclet keeps the servers that are running: they keep answering, and DeleteObject still stops them. *)
VerificationTest[
    Module[ { server, before, after },
        server = StartMCPSocketServer @ $socketTestServerObject;
        before = socketTestJSON[ server, socketTestBody[ "ping", 1 ] ][ "id" ];
        Quiet[ Get[ "Wolfram`AgentTools`" ], ClearAll::clloc ];
        after = {
            server[ "Running" ],
            $socketServer[ "Running" ],
            socketTestJSON[ server, socketTestBody[ "ping", 2 ] ][ "id" ]
        };
        DeleteObject @ server;
        {
            before,
            after,
            server[ "Running" ],
            MemberQ[ Sockets[ ], server[ "Listener" ][ "Socket" ] ],
            Wolfram`AgentTools`Server`Socket`Private`maintenanceTasks @ server[ "ID" ]
        }
    ],
    { 1, { True, True, 2 }, False, False, { } },
    SameTest -> MatchQ,
    TestID   -> "Reload-KeepsServers@@Tests/SocketServer.wlt:2247,1-2269,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    DeleteObject @ $socketServer;
    {
        $socketServer[ "Running" ],
        Select[ Wolfram`AgentToolsState`SocketServer`$servers, MemberQ[ { $socketServer[ "ID" ], $socketDeferredServer[ "ID" ] }, #[ "ID" ] ] & ],
        Select[ Wolfram`AgentToolsState`SocketServer`$jobs, MemberQ[ { $socketServer[ "ID" ], $socketDeferredServer[ "ID" ] }, #[ "ServerID" ] ] & ]
    },
    { False, <| |>, <| |> },
    SameTest -> MatchQ,
    TestID   -> "Cleanup@@Tests/SocketServer.wlt:2274,1-2284,2"
]

(* :!CodeAnalysis::EndBlock:: *)
