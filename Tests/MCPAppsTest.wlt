(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Registration*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Registered in $DefaultMCPTools*)
VerificationTest[
    KeyExistsQ[ $DefaultMCPTools, "MCPAppsTest" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-RegisteredInDefaultTools"
]

VerificationTest[
    Head @ $DefaultMCPTools[ "MCPAppsTest" ],
    LLMTool,
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-IsLLMTool"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Returns Correct Structure*)
VerificationTest[
    result = Wolfram`AgentTools`Tools`MCPAppsTest`Private`mcpAppsTestEvaluate[
        <| "message" -> "hello world" |>
    ];
    MatchQ[ result, <| "Content" -> { _Association } |> ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-ReturnsContentStructure"
]

VerificationTest[
    result = Wolfram`AgentTools`Tools`MCPAppsTest`Private`mcpAppsTestEvaluate[
        <| "message" -> "hello world" |>
    ];
    result[[ "Content", 1, "type" ]],
    "text",
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-ContentTypeIsText"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Echoes Message*)
VerificationTest[
    result = Wolfram`AgentTools`Tools`MCPAppsTest`Private`mcpAppsTestEvaluate[
        <| "message" -> "test echo" |>
    ];
    json = Developer`ReadRawJSONString @ result[[ "Content", 1, "text" ]];
    json[ "echo" ],
    "test echo",
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-EchoesMessage"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Contains Timestamp*)
VerificationTest[
    result = Wolfram`AgentTools`Tools`MCPAppsTest`Private`mcpAppsTestEvaluate[
        <| "message" -> "ts test" |>
    ];
    json = Developer`ReadRawJSONString @ result[[ "Content", 1, "text" ]];
    StringQ @ json[ "timestamp" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-ContainsTimestamp"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Contains Server Info*)
VerificationTest[
    result = Wolfram`AgentTools`Tools`MCPAppsTest`Private`mcpAppsTestEvaluate[
        <| "message" -> "server info test" |>
    ];
    json = Developer`ReadRawJSONString @ result[[ "Content", 1, "text" ]];
    AssociationQ @ json[ "server" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-ContainsServerInfo"
]

VerificationTest[
    result = Wolfram`AgentTools`Tools`MCPAppsTest`Private`mcpAppsTestEvaluate[
        <| "message" -> "version test" |>
    ];
    json = Developer`ReadRawJSONString @ result[[ "Content", 1, "text" ]];
    { StringQ @ json[ "server", "name" ], StringQ @ json[ "server", "version" ], NumberQ @ json[ "server", "kernel" ] },
    { True, True, True },
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-ServerInfoFields"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*UI Resource Integration*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool UI Associations*)
VerificationTest[
    KeyExistsQ[ Wolfram`AgentTools`Common`$toolUIAssociations, "MCPAppsTest" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-InToolUIAssociations"
]

VerificationTest[
    Wolfram`AgentTools`Common`$toolUIAssociations[ "MCPAppsTest" ],
    "ui://wolfram/mcp-apps-test",
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-CorrectResourceURI"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolUIMetadata*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = True },
        meta = Wolfram`AgentTools`Common`toolUIMetadata[ "MCPAppsTest" ];
        ("_meta" /. meta)[ "ui", "resourceUri" ]
    ],
    "ui://wolfram/mcp-apps-test",
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-ToolUIMetadataResourceURI"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = True },
        meta = Wolfram`AgentTools`Common`toolUIMetadata[ "MCPAppsTest" ];
        ("_meta" /. meta)[ "ui", "visibility" ]
    ],
    { "model", "app" },
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-ToolUIMetadataVisibility"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Resource Registry*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        KeyExistsQ[ Wolfram`AgentTools`Common`$uiResourceRegistry, "ui://wolfram/mcp-apps-test" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-InResourceRegistry"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`$uiResourceRegistry[ "ui://wolfram/mcp-apps-test", "mimeType" ]
    ],
    "text/html;profile=mcp-app",
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-ResourceMimeType"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readUIResource*)
VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        result = Wolfram`AgentTools`Common`readUIResource[
            <| "params" -> <| "uri" -> "ui://wolfram/mcp-apps-test" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ];
        StringContainsQ[ result[[ "contents", 1, "text" ]], "MCPAppsTest" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-ReadUIResourceContainsMCPAppsTest"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        result = Wolfram`AgentTools`Common`readUIResource[
            <| "params" -> <| "uri" -> "ui://wolfram/mcp-apps-test" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ];
        result[[ "contents", 1, "mimeType" ]]
    ],
    "text/html;profile=mcp-app",
    SameTest -> Equal,
    TestID   -> "MCPAppsTest-ReadUIResourceMimeType"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*JSON Metadata*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`$uiResourceRegistry[ "ui://wolfram/mcp-apps-test", "meta" ]
    ],
    KeyValuePattern[ "ui" -> KeyValuePattern[ "prefersBorder" -> True ] ],
    SameTest -> MatchQ,
    TestID   -> "MCPAppsTest-JSONMetadataLoaded"
]

(* :!CodeAnalysis::EndBlock:: *)
