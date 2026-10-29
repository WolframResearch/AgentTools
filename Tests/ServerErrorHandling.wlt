(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::NoSurroundingCatch:: *) (* tagless Throw is exercised deliberately *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ServerErrorHandling.wlt:8,1-13,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ServerErrorHandling.wlt:15,1-20,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*catchUncaughtThrows*)
VerificationTest[
    Wolfram`AgentTools`Server`catchUncaughtThrows[ 1 + 1, { "caught", ##1 } & ],
    2,
    SameTest -> MatchQ,
    TestID   -> "CatchUncaughtThrows-Normal@@Tests/ServerErrorHandling.wlt:25,1-30,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`catchUncaughtThrows[ Throw[ 1, TestThrowTag ], { "caught", ##1 } & ],
    { "caught", 1, TestThrowTag },
    SameTest -> MatchQ,
    TestID   -> "CatchUncaughtThrows-TaggedThrow@@Tests/ServerErrorHandling.wlt:32,1-37,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`catchUncaughtThrows[ Throw[ 2 ], { "caught", ##1 } & ],
    { "caught", 2, None },
    SameTest -> MatchQ,
    TestID   -> "CatchUncaughtThrows-TaglessThrow@@Tests/ServerErrorHandling.wlt:39,1-44,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`catchUncaughtThrows[ Abort[ ], { "caught", ##1 } & ],
    { "caught", $Aborted, Abort },
    SameTest -> MatchQ,
    TestID   -> "CatchUncaughtThrows-Abort@@Tests/ServerErrorHandling.wlt:46,1-51,2"
]

(* Throws caught inside the evaluation are unaffected *)
VerificationTest[
    Wolfram`AgentTools`Server`catchUncaughtThrows[ Catch[ Throw[ 3, InnerTag ], InnerTag ], { "caught", ##1 } & ],
    3,
    SameTest -> MatchQ,
    TestID   -> "CatchUncaughtThrows-InnerCatch@@Tests/ServerErrorHandling.wlt:54,1-59,2"
]

(* The paclet's own failures are still caught by stealthCatchTop first *)
VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Server`catchUncaughtThrows[
        Wolfram`AgentTools`Server`stealthCatchTop @ Wolfram`AgentTools`Common`throwFailure[ "UnknownTool", "x" ],
        { "caught", ##1 } &
    ],
    Failure[ "AgentTools::UnknownTool", _ ],
    { AgentTools::UnknownTool },
    SameTest -> MatchQ,
    TestID   -> "CatchUncaughtThrows-PacletFailureUnaffected@@Tests/ServerErrorHandling.wlt:62,1-71,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Request Handlers*)
VerificationTest[
    Wolfram`AgentTools`Server`uncaughtRequestThrow[ "tools/call", "boom", TestThrowTag ],
    Failure[ "AgentTools::UncaughtThrow", _ ]? (MatchQ[ #1[ "MessageParameters" ], { "tools/call", _String? (StringContainsQ[ "TestThrowTag" ]) } ] &),
    { AgentTools::UncaughtThrow },
    SameTest -> MatchQ,
    TestID   -> "UncaughtRequestThrow-Tagged@@Tests/ServerErrorHandling.wlt:76,1-82,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`uncaughtRequestThrow[ None, $Aborted, Abort ],
    Failure[ "AgentTools::RequestAborted", _ ],
    { AgentTools::RequestAborted },
    SameTest -> MatchQ,
    TestID   -> "UncaughtRequestThrow-Abort@@Tests/ServerErrorHandling.wlt:84,1-90,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Calls*)
VerificationTest[
    $callTestTool = Function[
        tool,
        (* The transports call handleMethod inside catchAlways, which scopes the paclet's error-handling state *)
        Block[ { Wolfram`AgentTools`Server`$llmTools = <| "TestTool" -> tool |> },
            Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`handleMethod[
                "tools/call",
                <| "method" -> "tools/call", "params" -> <| "name" -> "TestTool", "arguments" -> <| |> |> |>,
                <| "jsonrpc" -> "2.0", "id" -> 1 |>
            ]
        ]
    ];
    Null,
    Null,
    SameTest -> MatchQ,
    TestID   -> "DefineCallTestTool@@Tests/ServerErrorHandling.wlt:95,1-111,2"
]

VerificationTest[
    $callTestTool[ Function[ "ok" ] ],
    KeyValuePattern[ "result" -> KeyValuePattern @ { "isError" -> False, "content" -> { KeyValuePattern[ "text" -> "ok" ] } } ],
    SameTest -> MatchQ,
    TestID   -> "ToolsCall-Normal@@Tests/ServerErrorHandling.wlt:113,1-118,2"
]

(* A Throw with a tag nothing in the paclet catches becomes a tool error instead of ending the server *)
VerificationTest[
    $callTestTool[ Function[ Throw[ "boom", TestThrowTag ] ] ],
    KeyValuePattern[
        "result" -> KeyValuePattern @ {
            "isError" -> True,
            "content" -> { KeyValuePattern[ "text" -> _String? (StringContainsQ[ "TestThrowTag" ]) ] }
        }
    ],
    { AgentTools::UncaughtToolThrow },
    SameTest -> MatchQ,
    TestID   -> "ToolsCall-UncaughtTaggedThrow@@Tests/ServerErrorHandling.wlt:121,1-132,2"
]

VerificationTest[
    $callTestTool[ Function[ Throw[ "boom" ] ] ],
    KeyValuePattern[
        "result" -> KeyValuePattern @ {
            "isError" -> True,
            "content" -> { KeyValuePattern[ "text" -> _String? (StringContainsQ[ "Throw[\"boom\"]" ]) ] }
        }
    ],
    { AgentTools::UncaughtToolThrow },
    SameTest -> MatchQ,
    TestID   -> "ToolsCall-UncaughtTaglessThrow@@Tests/ServerErrorHandling.wlt:134,1-145,2"
]

VerificationTest[
    $callTestTool[ Function[ Abort[ ] ] ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "isError" -> True ] ],
    { AgentTools::ToolAborted },
    SameTest -> MatchQ,
    TestID   -> "ToolsCall-Abort@@Tests/ServerErrorHandling.wlt:147,1-153,2"
]

(* The network-failure tag thrown by CloudObject when the Wolfram Cloud is unreachable gets a specific message *)
VerificationTest[
    $callTestTool[ Function[ Throw[ $Failed, CloudObject`Private`NetworkCallFailure ] ] ],
    KeyValuePattern[
        "result" -> KeyValuePattern @ {
            "isError" -> True,
            "content" -> { KeyValuePattern[ "text" -> _String? (StringContainsQ[ "Wolfram Cloud" ]) ] }
        }
    ],
    { AgentTools::CloudUnavailable },
    SameTest -> MatchQ,
    TestID   -> "ToolsCall-CloudUnavailable@@Tests/ServerErrorHandling.wlt:156,1-167,2"
]

(* The paclet's own failures are reported as before *)
VerificationTest[
    $callTestTool[ Function[ Wolfram`AgentTools`Common`throwFailure[ "UnknownTool", "x" ] ] ],
    KeyValuePattern[
        "result" -> KeyValuePattern @ {
            "isError" -> True,
            "content" -> { KeyValuePattern[ "text" -> _String? (StringContainsQ[ "Unknown tool" ]) ] }
        }
    ],
    { AgentTools::UnknownTool },
    SameTest -> MatchQ,
    TestID   -> "ToolsCall-PacletFailure@@Tests/ServerErrorHandling.wlt:170,1-181,2"
]

(* Failure messages are rendered as plain text rather than boxes *)
VerificationTest[
    $callTestTool[ Function[ Wolfram`AgentTools`Common`throwFailure[ "UnknownTool", "x" ] ] ][[ "result", "content", 1, "text" ]],
    "[Error] Unknown tool: x.",
    { AgentTools::UnknownTool },
    SameTest -> MatchQ,
    TestID   -> "ToolsCall-FailureTextIsPlain@@Tests/ServerErrorHandling.wlt:184,1-190,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Context Tools Without Cloud Access*)
(* When Chatbook's searches fail (typically because the Wolfram Cloud could not be reached), the context tools report a
   clear failure instead of an opaque internal one *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Tools`Context`Private`relatedDocumentation0 =
                Function[ Failure[ "General::ChatbookInternal", <| |> ] ]
        },
        Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`relatedDocumentation[ "test" ]
    ],
    Failure[ "AgentTools::DocumentationSearchFailed", _ ]? (#1[ "MessageParameters" ] === { "General::ChatbookInternal" } &),
    { AgentTools::DocumentationSearchFailed },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-ChatbookFailure@@Tests/ServerErrorHandling.wlt:197,1-209,2"
]

VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Tools`Context`Private`relatedWolframAlphaResults0 =
                Function[ Failure[ "General::ChatbookInternal", <| |> ] ]
        },
        Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`relatedWolframAlphaResults[ "test" ]
    ],
    Failure[ "AgentTools::WolframAlphaSearchFailed", _ ]? (#1[ "MessageParameters" ] === { "General::ChatbookInternal" } &),
    { AgentTools::WolframAlphaSearchFailed },
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-ChatbookFailure@@Tests/ServerErrorHandling.wlt:211,1-223,2"
]

(* The same failure through a tools/call of the real tool *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Tools`Context`Private`relatedDocumentation0 =
                Function[ Failure[ "General::ChatbookInternal", <| |> ] ],
            Wolfram`AgentTools`Server`$llmTools = <| "WolframLanguageContext" -> $DefaultMCPTools[ "WolframLanguageContext" ] |>
        },
        Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`handleMethod[
            "tools/call",
            <| "method" -> "tools/call", "params" -> <| "name" -> "WolframLanguageContext", "arguments" -> <| "context" -> "test" |> |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ]
    ],
    KeyValuePattern[
        "result" -> KeyValuePattern @ {
            "isError" -> True,
            "content" -> { KeyValuePattern[ "text" -> _String? (StringStartsQ[ "[Error] Documentation search is currently unavailable (General::ChatbookInternal)" ]) ] }
        }
    ],
    { AgentTools::DocumentationSearchFailed },
    SameTest -> MatchQ,
    TestID   -> "ToolsCall-WolframLanguageContext-ChatbookFailure@@Tests/ServerErrorHandling.wlt:226,1-248,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Response Serialization*)
VerificationTest[
    Wolfram`AgentTools`Server`Local`Private`serializeResponse[ <| "jsonrpc" -> "2.0", "id" -> 5, "result" -> <| "a" -> 1 |> |> ],
    "{\"jsonrpc\":\"2.0\",\"id\":5,\"result\":{\"a\":1}}",
    SameTest -> MatchQ,
    TestID   -> "SerializeResponse-Normal@@Tests/ServerErrorHandling.wlt:253,1-258,2"
]

(* A response that cannot be encoded as JSON becomes an internal error response for the same request *)
VerificationTest[
    Quiet @ Wolfram`AgentTools`Server`Local`Private`serializeResponse[ <| "jsonrpc" -> "2.0", "id" -> 5, "result" -> <| "a" -> Hold[ 1 ] |> |> ],
    _String? (StringContainsQ[ #1, "\"id\":5" ] && StringContainsQ[ #1, "\"code\":-32603" ] &),
    SameTest -> MatchQ,
    TestID   -> "SerializeResponse-Unserializable@@Tests/ServerErrorHandling.wlt:261,1-266,2"
]

(* :!CodeAnalysis::EndBlock:: *)
