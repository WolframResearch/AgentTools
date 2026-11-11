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
(*$MCPEvaluationEnvironment and $MCPTransport*)

(* Outside a server session neither descriptor is bound. *)
VerificationTest[
    { $MCPEvaluationEnvironment, $MCPTransport },
    { None, None },
    SameTest -> MatchQ,
    TestID   -> "MCPEnvironment-DefaultsToNone"
]

VerificationTest[
    AllTrue[
        { "Wolfram`AgentTools`$MCPEvaluationEnvironment", "Wolfram`AgentTools`$MCPTransport" },
        MemberQ[ Wolfram`AgentTools`$AgentToolsProtectedNames, # ] &
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MCPEnvironment-Exported-Protected"
]

VerificationTest[
    { MemberQ[ Attributes @ $MCPEvaluationEnvironment, Protected ], MemberQ[ Attributes @ $MCPTransport, Protected ] },
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "MCPEnvironment-Attributes-Protected"
]

(* The transports bind the descriptors with Block, which works despite Protected. *)
VerificationTest[
    Block[ { $MCPTransport = "StreamableHTTP", $MCPEvaluationEnvironment = "Cloud" }, { $MCPTransport, $MCPEvaluationEnvironment } ],
    { "StreamableHTTP", "Cloud" },
    SameTest -> MatchQ,
    TestID   -> "MCPEnvironment-Blockable"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*applyToolOverrides*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fixtures*)
applyOverrides = Wolfram`AgentTools`Server`Shared`Private`applyToolOverrides;

overridesParameter[ name_String, help_String ] :=
    name -> <| "Interpreter" -> "String", "Help" -> help, "Required" -> True |>;

(* No "Overrides" key at all. *)
overridesBaseTool = LLMTool @ <|
    "Name"        -> "OverridesBase",
    "Description" -> "Local description.",
    "Function"    -> Identity,
    "Parameters"  -> { overridesParameter[ "x", "The x argument." ] }
|>;

(* Unconditional overrides: whole properties are replaced, the rest is kept. *)
overridesStaticTool = LLMTool @ <|
    "Name"        -> "OverridesStatic",
    "Description" -> "Local description.",
    "Function"    -> Identity,
    "Parameters"  -> { overridesParameter[ "x", "The x argument." ] },
    "Overrides"   -> <|
        "Description" -> "Overridden description.",
        "Parameters"  -> { overridesParameter[ "y", "The y argument." ] }
    |>
|>;

overridesNoneTool = LLMTool @ <|
    "Name"        -> "OverridesNone",
    "Description" -> "Local description.",
    "Function"    -> Identity,
    "Parameters"  -> { overridesParameter[ "x", "The x argument." ] },
    "Overrides"   -> None
|>;

overridesCloudFunction[ args_Association ] := "cloud";

(* Environment-dependent overrides, the way the built-in tools use the mechanism. *)
overridesDelayedTool = LLMTool @ <|
    "Name"        -> "OverridesDelayed",
    "Description" -> "Local description.",
    "Function"    -> Identity,
    "Parameters"  -> { overridesParameter[ "x", "The x argument." ] },
    "Overrides"   :> If[ $MCPEvaluationEnvironment === "Cloud",
                         <| "Description" -> "Cloud description.", "Function" -> overridesCloudFunction |>,
                         <| |>
                     ]
|>;

overridesInvalidTool = LLMTool @ <|
    "Name"        -> "OverridesInvalid",
    "Description" -> "Local description.",
    "Function"    -> Identity,
    "Parameters"  -> { overridesParameter[ "x", "The x argument." ] },
    "Overrides"   -> "not an association"
|>;

$overridesEvaluationCount = 0;

overridesCountingTool = LLMTool @ <|
    "Name"        -> "OverridesCounting",
    "Description" -> "Local description.",
    "Function"    -> Identity,
    "Parameters"  -> { overridesParameter[ "x", "The x argument." ] },
    "Overrides"   :> ( $overridesEvaluationCount++; <| |> )
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*No-op cases*)
VerificationTest[
    applyOverrides[ { } ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ApplyToolOverrides-EmptyList"
]

VerificationTest[
    applyOverrides @ overridesBaseTool,
    overridesBaseTool,
    SameTest -> SameQ,
    TestID   -> "ApplyToolOverrides-NoOverridesKey-Unchanged"
]

VerificationTest[
    applyOverrides @ overridesNoneTool,
    overridesNoneTool,
    SameTest -> SameQ,
    TestID   -> "ApplyToolOverrides-None-Unchanged"
]

VerificationTest[
    applyOverrides @ overridesDelayedTool,
    overridesDelayedTool,
    SameTest -> SameQ,
    TestID   -> "ApplyToolOverrides-Delayed-DefaultEnvironment-Unchanged"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Merging*)
VerificationTest[
    applyOverrides[ overridesStaticTool ][ "Description" ],
    "Overridden description.",
    SameTest -> MatchQ,
    TestID   -> "ApplyToolOverrides-Static-ReplacesDescription"
]

(* Properties are replaced wholesale: the original parameter list is gone, not merged. *)
VerificationTest[
    applyOverrides[ overridesStaticTool ][ "Parameters" ][[ All, 1 ]],
    { "y" },
    SameTest -> MatchQ,
    TestID   -> "ApplyToolOverrides-Static-ReplacesParameters"
]

VerificationTest[
    { applyOverrides[ overridesStaticTool ][ "Name" ], applyOverrides[ overridesStaticTool ][ "Function" ] },
    { "OverridesStatic", Identity },
    SameTest -> MatchQ,
    TestID   -> "ApplyToolOverrides-Static-KeepsOtherProperties"
]

VerificationTest[
    KeyExistsQ[ applyOverrides[ overridesStaticTool ][ "Data" ], "Overrides" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ApplyToolOverrides-Static-KeepsOverridesKey"
]

VerificationTest[
    applyOverrides @ applyOverrides @ overridesStaticTool,
    applyOverrides @ overridesStaticTool,
    SameTest -> SameQ,
    TestID   -> "ApplyToolOverrides-Idempotent"
]

VerificationTest[
    #[ "Description" ] & /@ applyOverrides @ { overridesStaticTool, overridesBaseTool, overridesNoneTool },
    { "Overridden description.", "Local description.", "Local description." },
    SameTest -> MatchQ,
    TestID   -> "ApplyToolOverrides-List"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Environment-dependent overrides*)
VerificationTest[
    Block[ { $MCPEvaluationEnvironment = "Local" }, applyOverrides[ overridesDelayedTool ][ "Description" ] ],
    "Local description.",
    SameTest -> MatchQ,
    TestID   -> "ApplyToolOverrides-Delayed-Local"
]

VerificationTest[
    Block[ { $MCPEvaluationEnvironment = "Cloud" }, applyOverrides[ overridesDelayedTool ][ "Description" ] ],
    "Cloud description.",
    SameTest -> MatchQ,
    TestID   -> "ApplyToolOverrides-Delayed-Cloud-Description"
]

VerificationTest[
    Block[ { $MCPEvaluationEnvironment = "Cloud" }, applyOverrides[ overridesDelayedTool ][ "Function" ] ],
    overridesCloudFunction,
    SameTest -> SameQ,
    TestID   -> "ApplyToolOverrides-Delayed-Cloud-Function"
]

(* Properties the override does not mention are kept. *)
VerificationTest[
    Block[ { $MCPEvaluationEnvironment = "Cloud" }, applyOverrides[ overridesDelayedTool ][ "Parameters" ][[ All, 1 ]] ],
    { "x" },
    SameTest -> MatchQ,
    TestID   -> "ApplyToolOverrides-Delayed-Cloud-KeepsParameters"
]

(* The overridden function is what the tool then calls. *)
VerificationTest[
    Block[ { $MCPEvaluationEnvironment = "Cloud" }, applyOverrides[ overridesDelayedTool ][ <| "x" -> "value" |> ] ],
    "cloud",
    SameTest -> MatchQ,
    TestID   -> "ApplyToolOverrides-Delayed-Cloud-Callable"
]

(* A delayed "Overrides" value is evaluated when the overrides are applied, not when the tool is defined. *)
VerificationTest[
    $overridesEvaluationCount,
    0,
    SameTest -> MatchQ,
    TestID   -> "ApplyToolOverrides-Delayed-NotEvaluatedAtDefinition"
]

VerificationTest[
    applyOverrides @ overridesCountingTool;
    $overridesEvaluationCount,
    1,
    SameTest -> MatchQ,
    TestID   -> "ApplyToolOverrides-Delayed-EvaluatedOnApply"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid overrides*)
VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ applyOverrides @ overridesInvalidTool,
    _Failure,
    { General::AgentToolsInternal },
    SameTest -> MatchQ,
    TestID   -> "ApplyToolOverrides-Invalid-InternalFailure"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*initializeServerState*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fixtures*)

(* An in-memory server (no disk persistence) with a built-in tool that overrides itself in the cloud
   (WriteNotebook) and the environment-dependent custom tool above. *)
overridesServer = MCPServerObject[ <|
    "Name"         -> "OverridesServer",
    "Location"     -> "BuiltIn",
    "LLMEvaluator" -> <| "Tools" -> { "WriteNotebook", overridesDelayedTool } |>
|> ];

(* Build the transport-agnostic server state the way both transports do. *)
overridesServerState[ ] := Block[ { Wolfram`AgentTools`Server`$currentMCPServer = overridesServer },
    Wolfram`AgentTools`Common`initializeServerState @ overridesServer
];

overridesToolEntry[ state_Association, name_String ] :=
    FirstCase[ state[ "ToolList" ], KeyValuePattern[ "name" -> name ] ];

VerificationTest[
    MCPServerObjectQ @ overridesServer,
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeServerState-Fixture-ServerValid"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Default environment*)
VerificationTest[
    $overridesLocalState = overridesServerState[ ],
    KeyValuePattern[ "ToolList" -> { __Association } ],
    SameTest -> MatchQ,
    TestID   -> "InitializeServerState-Local-Builds"
]

VerificationTest[
    Keys @ overridesToolEntry[ $overridesLocalState, "WriteNotebook" ][ "inputSchema", "properties" ],
    { "file", "overwrite", "markdown" },
    SameTest -> MatchQ,
    TestID   -> "InitializeServerState-Local-WriteNotebookSchema"
]

VerificationTest[
    overridesToolEntry[ $overridesLocalState, "WriteNotebook" ][ "description" ],
    _String? (StringContainsQ[ "saves it to a file" ]),
    SameTest -> MatchQ,
    TestID   -> "InitializeServerState-Local-WriteNotebookDescription"
]

VerificationTest[
    $overridesLocalState[ "LLMTools", "WriteNotebook" ][ "Function" ],
    Except[ Wolfram`AgentTools`Tools`Notebooks`Private`writeCloudNotebook ],
    SameTest -> MatchQ,
    TestID   -> "InitializeServerState-Local-WriteNotebookFunction"
]

VerificationTest[
    overridesToolEntry[ $overridesLocalState, "OverridesDelayed" ][ "description" ],
    "Local description.",
    SameTest -> MatchQ,
    TestID   -> "InitializeServerState-Local-CustomToolDescription"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cloud environment*)
VerificationTest[
    $overridesCloudState = Block[ { $MCPEvaluationEnvironment = "Cloud", $MCPTransport = "StreamableHTTP" }, overridesServerState[ ] ],
    KeyValuePattern[ "ToolList" -> { __Association } ],
    SameTest -> MatchQ,
    TestID   -> "InitializeServerState-Cloud-Builds"
]

VerificationTest[
    Keys @ overridesToolEntry[ $overridesCloudState, "WriteNotebook" ][ "inputSchema", "properties" ],
    { "path", "permissions", "overwrite", "markdown" },
    SameTest -> MatchQ,
    TestID   -> "InitializeServerState-Cloud-WriteNotebookSchema"
]

VerificationTest[
    overridesToolEntry[ $overridesCloudState, "WriteNotebook" ][ "inputSchema", "required" ],
    { "markdown" },
    SameTest -> MatchQ,
    TestID   -> "InitializeServerState-Cloud-WriteNotebookRequired"
]

VerificationTest[
    overridesToolEntry[ $overridesCloudState, "WriteNotebook" ][ "description" ],
    _String? (StringContainsQ[ "cloud object" ]),
    SameTest -> MatchQ,
    TestID   -> "InitializeServerState-Cloud-WriteNotebookDescription"
]

VerificationTest[
    $overridesCloudState[ "LLMTools", "WriteNotebook" ][ "Function" ],
    Wolfram`AgentTools`Tools`Notebooks`Private`writeCloudNotebook,
    SameTest -> SameQ,
    TestID   -> "InitializeServerState-Cloud-WriteNotebookFunction"
]

VerificationTest[
    overridesToolEntry[ $overridesCloudState, "OverridesDelayed" ][ "description" ],
    "Cloud description.",
    SameTest -> MatchQ,
    TestID   -> "InitializeServerState-Cloud-CustomToolDescription"
]

(* The tool name is unchanged by the override, so clients address it the same way in both environments. *)
VerificationTest[
    Keys @ $overridesCloudState[ "LLMTools" ],
    Keys @ $overridesLocalState[ "LLMTools" ],
    SameTest -> MatchQ,
    TestID   -> "InitializeServerState-Cloud-SameToolNames"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Transports*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cloud (RunCloudMCPServer)*)

(* A tool that reports the descriptors it observes while being evaluated. *)
overridesProbeTool = LLMTool[
    "EnvProbe",
    { },
    StringRiffle[ ToString /@ { $MCPTransport, $MCPEvaluationEnvironment }, "/" ] &
];

overridesCloudServer = MCPServerObject[ <|
    "Location"     -> "BuiltIn",
    "LLMEvaluator" -> <| "Tools" -> { "WriteNotebook", overridesProbeTool } |>
|> ];

(* A mock request shaped like HTTPRequestData[] (see CloudDeployment.wlt) driving the internal handler. *)
overridesCloudRun[ method_String, id_Integer, params_Association ] :=
    Wolfram`AgentTools`Server`Cloud`Private`runCloudMCPServer[
        overridesCloudServer,
        <|
            "Method"        -> "POST",
            "Headers"       -> { "accept" -> "application/json" },
            "BodyByteArray" -> StringToByteArray @ Developer`WriteRawJSONString @ <|
                "jsonrpc" -> "2.0",
                "id"      -> id,
                "method"  -> method,
                "params"  -> params
            |>
        |>
    ];

overridesCloudJSON[ resp_HTTPResponse ] := Developer`ReadRawJSONString @ resp[ "Body" ];

VerificationTest[
    $overridesProbeResponse = overridesCloudRun[ "tools/call", 1, <| "name" -> "EnvProbe", "arguments" -> <| |> |> ],
    _HTTPResponse? (#[ "StatusCode" ] === 200 &),
    SameTest -> MatchQ,
    TestID   -> "CloudTransport-ProbeCall-Succeeds"
]

VerificationTest[
    overridesCloudJSON[ $overridesProbeResponse ][[ "result", "content", 1, "text" ]],
    "StreamableHTTP/Cloud",
    SameTest -> MatchQ,
    TestID   -> "CloudTransport-BindsTransportAndEnvironment"
]

(* The bindings are per request: nothing leaks out of the handler. *)
VerificationTest[
    { $MCPTransport, $MCPEvaluationEnvironment },
    { None, None },
    SameTest -> MatchQ,
    TestID   -> "CloudTransport-RestoredAfterRequest"
]

VerificationTest[
    Keys @ FirstCase[
        overridesCloudJSON[ overridesCloudRun[ "tools/list", 2, <| |> ] ][[ "result", "tools" ]],
        KeyValuePattern[ "name" -> "WriteNotebook" ]
    ][ "inputSchema", "properties" ],
    { "path", "permissions", "overwrite", "markdown" },
    SameTest -> MatchQ,
    TestID   -> "CloudTransport-ToolsList-UsesCloudOverrides"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Local (StartMCPServer)*)

(* The stdio read loop cannot run in-process (it blocks on stdin), so check the bindings it establishes
   structurally: startMCPServer Blocks both descriptors around the whole session. *)
VerificationTest[
    With[ { dv = DownValues @ Wolfram`AgentTools`Server`Local`Private`startMCPServer },
        {
            ! FreeQ[ dv, HoldPattern[ $MCPTransport = "StandardInputOutput" ] ],
            ! FreeQ[ dv, HoldPattern[ $MCPEvaluationEnvironment = "Local" ] ]
        }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "LocalTransport-BindsTransportAndEnvironment"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cloud landing page (/api/info)*)

(* The /api/info tool list is generated at deploy time; it must describe the tools as the cloud endpoint
   will list them, i.e. with the cloud overrides applied. *)
overridesInfo = Wolfram`AgentTools`Server`Cloud`Private`cloudMCPServerInfo[
    overridesServer,
    "https://www.wolframcloud.com/obj/user/dir/mcp"
];

VerificationTest[
    FirstCase[ overridesInfo[ "tools" ], KeyValuePattern[ "name" -> "WriteNotebook" ] ][ "description" ],
    _String? (StringContainsQ[ "cloud object" ]),
    SameTest -> MatchQ,
    TestID   -> "CloudMCPServerInfo-WriteNotebook-CloudDescription"
]

VerificationTest[
    FirstCase[ overridesInfo[ "tools" ], KeyValuePattern[ "name" -> "OverridesDelayed" ] ][ "description" ],
    "Cloud description.",
    SameTest -> MatchQ,
    TestID   -> "CloudMCPServerInfo-CustomTool-CloudDescription"
]

(* serverToolListData itself honors whatever environment the caller has bound (none here). *)
VerificationTest[
    FirstCase[ Wolfram`AgentTools`Server`serverToolListData @ overridesServer, KeyValuePattern[ "name" -> "OverridesDelayed" ] ][ "description" ],
    "Local description.",
    SameTest -> MatchQ,
    TestID   -> "ServerToolListData-DefaultEnvironment"
]

VerificationTest[
    FirstCase[ Wolfram`AgentTools`Server`serverToolListData @ { overridesStaticTool }, KeyValuePattern[ "name" -> "OverridesStatic" ] ][ "description" ],
    "Overridden description.",
    SameTest -> MatchQ,
    TestID   -> "ServerToolListData-AppliesOverrides"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Deployment payloads*)

(* The functions a cloud override swaps in are only referenced from inside the tool's delayed "Overrides"
   value, so they must still be captured by the definition gather that embeds the server in the deployed
   /mcp expression. The heavy (self-contained) payload must carry the built-in cloud writer; both payloads
   must carry the user's custom override function. *)
overridesHeavyPayload = Wolfram`AgentTools`Server`Cloud`Private`cloudMCPServerPayload[ overridesServer, False ];
overridesLightPayload = Wolfram`AgentTools`Server`Cloud`Private`cloudMCPServerPayload[ overridesServer, True ];

overridesPayloadDefinitionCount[ payload_, sym_, type_ ] :=
    Cases[ payload, HoldPattern[ HoldForm[ sym ] -> defs_ ] :> Length @ Lookup[ defs, type ], Infinity ];

VerificationTest[
    overridesPayloadDefinitionCount[ overridesHeavyPayload, Wolfram`AgentTools`Tools`Notebooks`Private`writeCloudNotebook, DownValues ],
    { _Integer? Positive },
    SameTest -> MatchQ,
    TestID   -> "CloudPayload-Heavy-CarriesWriteCloudNotebook"
]

VerificationTest[
    Cases[
        overridesHeavyPayload,
        HoldPattern[ HoldForm[ Wolfram`AgentTools`Tools`Notebooks`Private`$writeNotebookCloudOverrides ] -> defs_ ] :>
            Length @ Lookup[ defs, OwnValues ],
        Infinity
    ],
    { _Integer? Positive },
    SameTest -> MatchQ,
    TestID   -> "CloudPayload-Heavy-CarriesWriteNotebookCloudOverrides"
]

VerificationTest[
    overridesPayloadDefinitionCount[ overridesHeavyPayload, overridesCloudFunction, DownValues ],
    { _Integer? Positive },
    SameTest -> MatchQ,
    TestID   -> "CloudPayload-Heavy-CarriesCustomOverrideFunction"
]

VerificationTest[
    overridesPayloadDefinitionCount[ overridesLightPayload, overridesCloudFunction, DownValues ],
    { _Integer? Positive },
    SameTest -> MatchQ,
    TestID   -> "CloudPayload-Light-CarriesCustomOverrideFunction"
]

VerificationTest[
    FreeQ[ overridesLightPayload, Wolfram`AgentTools`Tools`Notebooks`Private`writeCloudNotebook ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudPayload-Light-ReliesOnCloudPaclet"
]

(* :!CodeAnalysis::EndBlock:: *)
