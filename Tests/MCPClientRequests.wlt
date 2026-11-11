(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Pending-Request Registry*)

VerificationTest[
    AssociationQ @ Wolfram`AgentTools`Common`$mcpClientRequests,
    True,
    SameTest -> MatchQ,
    TestID   -> "MCPClientRequests-RegistryIsAssociation"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*sendClientRequest*)

(* sendClientRequest writes JSON to "stdout" as part of its contract. The unit
   test mocks WriteLine so the call doesn't pollute the test runner's stdout
   stream, and verifies the observable side effects: a UUID is returned and the
   registry is updated with the correct entry shape. *)
VerificationTest[
    Module[ { uuid, entry, savedRegistry },
        savedRegistry = Wolfram`AgentTools`Common`$mcpClientRequests;
        WithCleanup[
            Wolfram`AgentTools`Common`$mcpClientRequests = <| |>,
            Block[ { WriteLine = (Null &) },
                uuid = Wolfram`AgentTools`Common`sendClientRequest[
                    "test/method",
                    <| "x" -> 1 |>,
                    Identity
                ]
            ];
            entry = Wolfram`AgentTools`Common`$mcpClientRequests[ uuid ],
            Wolfram`AgentTools`Common`$mcpClientRequests = savedRegistry
        ];
        {
            StringQ @ uuid,
            AssociationQ @ entry,
            entry[ "id" ] === uuid,
            entry[ "handler" ] === Identity,
            entry[ "request", "jsonrpc" ] === "2.0",
            entry[ "request", "id" ] === uuid,
            entry[ "request", "method" ] === "test/method",
            entry[ "request", "params" ] === <| "x" -> 1 |>
        }
    ],
    { True, True, True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "MCPClientRequests-SendRegistersEntry"
]

VerificationTest[
    Module[ { uuid1, uuid2, savedRegistry },
        savedRegistry = Wolfram`AgentTools`Common`$mcpClientRequests;
        WithCleanup[
            Wolfram`AgentTools`Common`$mcpClientRequests = <| |>,
            Block[ { WriteLine = (Null &) },
                uuid1 = Wolfram`AgentTools`Common`sendClientRequest[ "m1", <| |>, Identity ];
                uuid2 = Wolfram`AgentTools`Common`sendClientRequest[ "m2", <| |>, Identity ]
            ],
            Wolfram`AgentTools`Common`$mcpClientRequests = savedRegistry
        ];
        uuid1 =!= uuid2 && StringQ @ uuid1 && StringQ @ uuid2
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MCPClientRequests-SendUUIDsAreUnique"
]

(* Requests are sanitized before JSON encoding so PUA characters never reach the wire,
   matching the response sanitization in StartMCPServer.wl. *)
VerificationTest[
    Module[ { written, savedRegistry },
        savedRegistry = Wolfram`AgentTools`Common`$mcpClientRequests;
        written = None;
        WithCleanup[
            Wolfram`AgentTools`Common`$mcpClientRequests = <| |>,
            Block[ { WriteLine = Function[ { stream, line }, written = line ] },
                Wolfram`AgentTools`Common`sendClientRequest[
                    "test/method",
                    <| "text" -> FromCharacterCode @ { 97, 32, 57345, 32, 98 } |>,
                    Identity
                ]
            ],
            Wolfram`AgentTools`Common`$mcpClientRequests = savedRegistry
        ];
        {
            StringQ @ written,
            Max @ ToCharacterCode @ written < 57344,
            AssociationQ @ Developer`ReadRawJSONString @ written
        }
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "MCPClientRequests-SendSanitizesPUACharacters"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*handleClientResponse*)

(* The handler is invoked with the original request and the response message,
   and the entry is removed from the registry. *)
VerificationTest[
    Module[ { uuid, called, savedRegistry, request, response },
        savedRegistry = Wolfram`AgentTools`Common`$mcpClientRequests;
        uuid = "test-uuid-123";
        called = None;
        request = <| "jsonrpc" -> "2.0", "id" -> uuid, "method" -> "roots/list", "params" -> <| |> |>;
        response = <| "jsonrpc" -> "2.0", "id" -> uuid, "result" -> <| "roots" -> { } |> |>;
        WithCleanup[
            Wolfram`AgentTools`Common`$mcpClientRequests = <|
                uuid -> <|
                    "id"      -> uuid,
                    "request" -> request,
                    "handler" -> Function[ { req, resp }, called = { req, resp } ]
                |>
            |>,
            Wolfram`AgentTools`Common`handleClientResponse[ uuid, response ],
            Wolfram`AgentTools`Common`$mcpClientRequests = savedRegistry
        ];
        {
            KeyExistsQ[ Wolfram`AgentTools`Common`$mcpClientRequests, uuid ],
            called === { request, response }
        }
    ],
    { False, True },
    SameTest -> MatchQ,
    TestID   -> "MCPClientRequests-ResponseCallsHandlerAndRemoves"
]

(* Unknown response IDs are silently ignored - no handler call, no registry mutation. *)
VerificationTest[
    Module[ { result, savedRegistry },
        savedRegistry = Wolfram`AgentTools`Common`$mcpClientRequests;
        WithCleanup[
            Wolfram`AgentTools`Common`$mcpClientRequests = <| "known-id" -> <| "id" -> "known-id" |> |>,
            result = Wolfram`AgentTools`Common`handleClientResponse[
                "unknown-id",
                <| "jsonrpc" -> "2.0", "id" -> "unknown-id", "result" -> <| |> |>
            ],
            Wolfram`AgentTools`Common`$mcpClientRequests = savedRegistry
        ];
        result
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "MCPClientRequests-ResponseUnknownIDIsNoOp"
]

(* The handler still fires for error responses - interpretation is the handler's job. *)
VerificationTest[
    Module[ { uuid, called, savedRegistry, errorResponse },
        savedRegistry = Wolfram`AgentTools`Common`$mcpClientRequests;
        uuid = "err-uuid";
        called = None;
        errorResponse = <| "jsonrpc" -> "2.0", "id" -> uuid, "error" -> <| "code" -> -32601, "message" -> "Method not found" |> |>;
        WithCleanup[
            Wolfram`AgentTools`Common`$mcpClientRequests = <|
                uuid -> <|
                    "id"      -> uuid,
                    "request" -> <| "method" -> "foo", "id" -> uuid |>,
                    "handler" -> Function[ { req, resp }, called = resp ]
                |>
            |>,
            Wolfram`AgentTools`Common`handleClientResponse[ uuid, errorResponse ],
            Wolfram`AgentTools`Common`$mcpClientRequests = savedRegistry
        ];
        called
    ],
    KeyValuePattern[ "error" -> KeyValuePattern[ "code" -> -32601 ] ],
    SameTest -> MatchQ,
    TestID   -> "MCPClientRequests-ResponseHandlerFiresOnError"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*handleNotification*)

(* Unknown notifications are silently ignored. *)
VerificationTest[
    Wolfram`AgentTools`Common`handleNotification[ "notifications/cancelled", <| |> ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "MCPClientRequests-NotificationUnknownIsNoOp"
]

(* notifications/initialized dispatches to onClientInitialized with the message.
   onClientInitialized is defined in MCPRoots.wl (Task 3) - we mock it here so
   the dispatch can be verified independent of the roots feature. *)
VerificationTest[
    Module[ { received },
        received = None;
        Block[ { Wolfram`AgentTools`Common`onClientInitialized = Function[ msg, received = msg ] },
            Wolfram`AgentTools`Common`handleNotification[
                "notifications/initialized",
                <| "method" -> "notifications/initialized" |>
            ]
        ];
        received
    ],
    <| "method" -> "notifications/initialized" |>,
    SameTest -> MatchQ,
    TestID   -> "MCPClientRequests-NotificationInitializedDispatch"
]

(* notifications/roots/list_changed dispatches to onRootsListChanged with the message. *)
VerificationTest[
    Module[ { received },
        received = None;
        Block[ { Wolfram`AgentTools`Common`onRootsListChanged = Function[ msg, received = msg ] },
            Wolfram`AgentTools`Common`handleNotification[
                "notifications/roots/list_changed",
                <| "method" -> "notifications/roots/list_changed" |>
            ]
        ];
        received
    ],
    <| "method" -> "notifications/roots/list_changed" |>,
    SameTest -> MatchQ,
    TestID   -> "MCPClientRequests-NotificationRootsListChangedDispatch"
]

(* :!CodeAnalysis::EndBlock:: *)
