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
(*Protocol Version Negotiation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Configuration*)

VerificationTest[
    Wolfram`AgentTools`Common`$supportedProtocolVersions,
    { "2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05" },
    SameTest -> MatchQ,
    TestID   -> "SupportedProtocolVersions-Value"
]

VerificationTest[
    Wolfram`AgentTools`Common`$preferredProtocolVersion,
    "2025-11-25",
    SameTest -> MatchQ,
    TestID   -> "PreferredProtocolVersion-Value"
]

(* Invariant: the preferred version must itself be supported. *)
VerificationTest[
    MemberQ[
        Wolfram`AgentTools`Common`$supportedProtocolVersions,
        Wolfram`AgentTools`Common`$preferredProtocolVersion
    ],
    True,
    SameTest -> Equal,
    TestID   -> "PreferredProtocolVersion-IsSupported"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*negotiateProtocolVersion (string form)*)

(* A supported version is echoed back verbatim (oldest supported). *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`negotiateProtocolVersion[ "2024-11-05" ],
    "2024-11-05",
    SameTest -> MatchQ,
    TestID   -> "NegotiateProtocolVersion-EchoOld"
]

(* A supported version is echoed back verbatim (newest/preferred). *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`negotiateProtocolVersion[ "2025-11-25" ],
    "2025-11-25",
    SameTest -> MatchQ,
    TestID   -> "NegotiateProtocolVersion-EchoNew"
]

(* Intermediate supported versions are echoed too. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`negotiateProtocolVersion /@ { "2025-06-18", "2025-03-26" },
    { "2025-06-18", "2025-03-26" },
    SameTest -> MatchQ,
    TestID   -> "NegotiateProtocolVersion-EchoIntermediate"
]

(* An unsupported version falls back to the preferred version. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`negotiateProtocolVersion[ "1999-01-01" ],
    "2025-11-25",
    SameTest -> MatchQ,
    TestID   -> "NegotiateProtocolVersion-UnknownFallsBack"
]

(* Non-string junk falls back to the preferred version rather than erroring. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`negotiateProtocolVersion[ 12345 ],
    "2025-11-25",
    SameTest -> MatchQ,
    TestID   -> "NegotiateProtocolVersion-NonStringFallsBack"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*negotiateProtocolVersion (client message form)*)

(* Reads params.protocolVersion out of a full client message. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`negotiateProtocolVersion @ <|
        "method" -> "initialize",
        "params" -> <| "protocolVersion" -> "2025-06-18" |>
    |>,
    "2025-06-18",
    SameTest -> MatchQ,
    TestID   -> "NegotiateProtocolVersion-MessageSupported"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`negotiateProtocolVersion @ <|
        "method" -> "initialize",
        "params" -> <| "protocolVersion" -> "1999-01-01" |>
    |>,
    "2025-11-25",
    SameTest -> MatchQ,
    TestID   -> "NegotiateProtocolVersion-MessageUnknown"
]

(* A message with no protocolVersion falls back to the preferred version. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`negotiateProtocolVersion @ <|
        "method" -> "initialize",
        "params" -> <| "clientInfo" -> <| "name" -> "test-client" |> |>
    |>,
    "2025-11-25",
    SameTest -> MatchQ,
    TestID   -> "NegotiateProtocolVersion-MessageMissingVersion"
]

(* An empty message falls back to the preferred version. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`negotiateProtocolVersion @ <| |>,
    "2025-11-25",
    SameTest -> MatchQ,
    TestID   -> "NegotiateProtocolVersion-EmptyMessage"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initResponse negotiation*)

(* The full init response echoes a supported requested version. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`initResponse[
        "TestServer", "1.0.0", { }, { },
        <| "params" -> <| "protocolVersion" -> "2024-11-05" |> |>
    ][ "protocolVersion" ],
    "2024-11-05",
    SameTest -> MatchQ,
    TestID   -> "InitResponse-EchoSupportedVersion"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`initResponse[
        "TestServer", "1.0.0", { }, { },
        <| "params" -> <| "protocolVersion" -> "2025-11-25" |> |>
    ][ "protocolVersion" ],
    "2025-11-25",
    SameTest -> MatchQ,
    TestID   -> "InitResponse-EchoPreferredVersion"
]

(* An unsupported requested version falls back to the preferred version. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`initResponse[
        "TestServer", "1.0.0", { }, { },
        <| "params" -> <| "protocolVersion" -> "1999-01-01" |> |>
    ][ "protocolVersion" ],
    "2025-11-25",
    SameTest -> MatchQ,
    TestID   -> "InitResponse-UnknownVersionFallsBack"
]

(* No client message at all (4-arg form) yields the preferred version. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`initResponse[
        "TestServer", "1.0.0", { }, { }
    ][ "protocolVersion" ],
    "2025-11-25",
    SameTest -> MatchQ,
    TestID   -> "InitResponse-NoClientMessageUsesPreferred"
]

(* An empty client message yields the preferred version. *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`initResponse[
        "TestServer", "1.0.0", { }, { }, <| |>
    ][ "protocolVersion" ],
    "2025-11-25",
    SameTest -> MatchQ,
    TestID   -> "InitResponse-EmptyClientMessageUsesPreferred"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Session-ID Capability Codec*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Configuration*)

VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`$trackedFeatureList,
    { "MCPApps" },
    SameTest -> MatchQ,
    TestID   -> "TrackedFeatureList-Value"
]

VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`$idVersion,
    "1",
    SameTest -> MatchQ,
    TestID   -> "IdVersion-Value"
]

(* The single v1 tracked feature maps to bit position 0. *)
VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`$trackedFeatureIDs === <| "MCPApps" -> 0 |>,
    True,
    SameTest -> MatchQ,
    TestID   -> "TrackedFeatureIDs-Value"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeSessionIDFromFeatureList*)

(* A single tracked feature encodes to its bit: "MCPApps" (bit 0) -> "1:1:<uuid>". *)
VerificationTest[
    StringMatchQ[
        Wolfram`AgentTools`Server`Cloud`Private`makeSessionIDFromFeatureList[ { "MCPApps" } ],
        "1:1:" ~~ __
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MakeSessionID-SingleFeature"
]

(* The empty feature set totals to 0 and encodes as "1:0:<uuid>". *)
VerificationTest[
    StringMatchQ[
        Wolfram`AgentTools`Server`Cloud`Private`makeSessionIDFromFeatureList[ { } ],
        "1:0:" ~~ __
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MakeSessionID-EmptySet"
]

(* The Intersection guard drops an untracked feature before it can reach the bitfield, so a purely
   untracked feature set encodes identically to the empty set (bitfield 0). *)
VerificationTest[
    StringMatchQ[
        Wolfram`AgentTools`Server`Cloud`Private`makeSessionIDFromFeatureList[ { "NotATrackedFeature" } ],
        "1:0:" ~~ __
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MakeSessionID-IntersectionGuardDropsUntracked"
]

(* The trailing component looks like a UUID (hexadecimal characters and hyphens). *)
VerificationTest[
    StringMatchQ[
        Wolfram`AgentTools`Server`Cloud`Private`makeSessionIDFromFeatureList[ { "MCPApps" } ],
        "1:1:" ~~ Repeated[ HexadecimalCharacter | "-" ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MakeSessionID-TrailingUUID"
]

(* The trailing UUID is fresh each call, so two encodings of the same feature set are not identical. *)
VerificationTest[
    SameQ @@ Table[
        Wolfram`AgentTools`Server`Cloud`Private`makeSessionIDFromFeatureList[ { "MCPApps" } ],
        2
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "MakeSessionID-UUIDMakesIDsUnique"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getFeaturesFromSessionID*)

(* Decoding inverts encoding for a single feature. *)
VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`getFeaturesFromSessionID[ "1:1:" <> CreateUUID[ ] ],
    { "MCPApps" },
    SameTest -> MatchQ,
    TestID   -> "GetFeatures-SingleFeature"
]

(* Bitfield 0 decodes to no features. *)
VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`getFeaturesFromSessionID[ "1:0:" <> CreateUUID[ ] ],
    { },
    SameTest -> MatchQ,
    TestID   -> "GetFeatures-EmptySet"
]

(* The Intersection guard drops only the untracked feature, keeping the tracked one. *)
VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`getFeaturesFromSessionID @
        Wolfram`AgentTools`Server`Cloud`Private`makeSessionIDFromFeatureList[
            { "MCPApps", "NotATrackedFeature" }
        ],
    { "MCPApps" },
    SameTest -> MatchQ,
    TestID   -> "GetFeatures-IntersectionGuardKeepsTracked"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Round-trip*)

(* getFeaturesFromSessionID @ makeSessionIDFromFeatureList[f] === f for EVERY subset of the tracked
   feature list (Select returns the subsets that fail to round-trip exactly; expect none). *)
VerificationTest[
    Select[
        Subsets @ Wolfram`AgentTools`Server`Cloud`Private`$trackedFeatureList,
        Wolfram`AgentTools`Server`Cloud`Private`getFeaturesFromSessionID @
            Wolfram`AgentTools`Server`Cloud`Private`makeSessionIDFromFeatureList @ # =!= # &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "SessionID-RoundTripAllSubsets"
]

(* v1 tracks a single feature, but the codec is list-based so features can be appended later. These
   two tests exercise that generality directly by Block-ing a HYPOTHETICAL multi-feature list (not the
   real v1 list): every subset must still round-trip, and multi-bit packing must hold -- bits 0 + 2 + 3
   = 1 + 4 + 8 = 13, which is "d" in base 36. *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Server`Cloud`Private`$trackedFeatureList = { "A", "B", "C", "D" },
            Wolfram`AgentTools`Server`Cloud`Private`$trackedFeatureIDs  = <| "A" -> 0, "B" -> 1, "C" -> 2, "D" -> 3 |>
        },
        Select[
            Subsets @ { "A", "B", "C", "D" },
            Wolfram`AgentTools`Server`Cloud`Private`getFeaturesFromSessionID @
                Wolfram`AgentTools`Server`Cloud`Private`makeSessionIDFromFeatureList @ # =!= # &
        ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "SessionID-GenericMultiBitRoundTrip"
]

VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Server`Cloud`Private`$trackedFeatureList = { "A", "B", "C", "D" },
            Wolfram`AgentTools`Server`Cloud`Private`$trackedFeatureIDs  = <| "A" -> 0, "B" -> 1, "C" -> 2, "D" -> 3 |>
        },
        StringMatchQ[
            Wolfram`AgentTools`Server`Cloud`Private`makeSessionIDFromFeatureList @ { "A", "C", "D" },
            "1:d:" ~~ __
        ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SessionID-GenericMultiBitPacking"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fail-closed decode*)

(* A future/unknown version decodes to no features (the $idVersion bump story): an ID minted by an
   older deployment with a different bit layout must not misfire, even with a valid-looking bitfield. *)
VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`getFeaturesFromSessionID[ "2:1:" <> CreateUUID[ ] ],
    { },
    SameTest -> MatchQ,
    TestID   -> "GetFeatures-WrongVersionFailsClosed"
]

(* A malformed ID with no colon delimiters decodes to no features. *)
VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`getFeaturesFromSessionID[ "garbage" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "GetFeatures-MalformedFailsClosed"
]

(* An ID with too few colon-separated parts decodes to no features. *)
VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`getFeaturesFromSessionID[ "1:1" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "GetFeatures-TooFewPartsFailsClosed"
]

(* The empty string decodes to no features. *)
VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`getFeaturesFromSessionID[ "" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "GetFeatures-EmptyStringFailsClosed"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RunCloudMCPServer (stateless HTTP handler)*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fixtures*)

(* An in-memory server (no disk persistence -- Location "BuiltIn" satisfies mcpServerExistsQ) carrying a
   plain tool (PrimeFinder) and a tool whose name matches a UI resource association (MCPAppsTest). *)
cloudTestServer = Wolfram`AgentTools`MCPServerObject[ <|
    "Location"     -> "BuiltIn",
    "LLMEvaluator" -> <| "Tools" -> {
        LLMTool[ "PrimeFinder", { "n" -> "Integer" }, Prime[ #n ] & ],
        LLMTool[ "MCPAppsTest", { "x" -> "String" }, #x & ]
    } |>
|> ];

(* A mock request shaped like HTTPRequestData[]: Method, lowercased Headers rules, UTF-8 BodyByteArray.
   Providing a "Headers" key replaces the default Accept, so a header-less request can be simulated. *)
cloudMockRequest[ opts_Association ] := <|
    "Method"        -> Lookup[ opts, "Method", "POST" ],
    "Headers"       -> Normal @ KeyMap[ ToLowerCase, Lookup[ opts, "Headers", <| "Accept" -> "application/json" |> ] ],
    "BodyByteArray" -> Replace[ Lookup[ opts, "Body", Missing[ ] ], s_String :> StringToByteArray @ s ]
|>;

(* Drive the internal handler with a mock request and read back the HTTPResponse. *)
cloudRun[ opts_Association ] := Wolfram`AgentTools`Server`Cloud`Private`runCloudMCPServer[
    cloudTestServer,
    cloudMockRequest @ opts
];

cloudStatus[ opts_Association ]  := cloudRun[ opts ][ "StatusCode" ];
cloudSessionID[ resp_ ]          := Lookup[ KeyMap[ ToLowerCase, Association @ resp[ "Headers" ] ], "mcp-session-id", Missing[ "Absent" ] ];
cloudBodyJSON[ resp_ ]           := Quiet @ Developer`ReadRawJSONString @ resp[ "Body" ];
cloudDecode[ id_ ]               := Wolfram`AgentTools`Server`Cloud`Private`getFeaturesFromSessionID @ id;

(* Build a JSON-RPC message body; omit id (None) for notifications, pass Null for an explicit null id. *)
cloudBody[ method_, id_: None, params_: <| |> ] := Developer`WriteRawJSONString @ Association[
    "jsonrpc" -> "2.0",
    If[ id === None, Nothing, "id" -> id ],
    "method"  -> method,
    "params"  -> params
];

cloudInitBodyUI = cloudBody[ "initialize", 0, <|
    "protocolVersion" -> "2025-06-18",
    "capabilities"    -> <| "extensions" -> <| "io.modelcontextprotocol/ui" -> <| "mimeTypes" -> { "text/html;profile=mcp-app" } |> |> |>,
    "clientInfo"      -> <| "name" -> "test-client" |>
|> ];

cloudInitBodyNoUI = cloudBody[ "initialize", 0, <|
    "protocolVersion" -> "2025-06-18",
    "capabilities"    -> <| |>,
    "clientInfo"      -> <| "name" -> "test-client" |>
|> ];

(* Fixture sanity check: the in-memory server is valid without touching disk. *)
VerificationTest[
    Wolfram`AgentTools`MCPServerObjectQ @ cloudTestServer,
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Fixture-ServerValid"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Export*)

VerificationTest[
    MemberQ[ Wolfram`AgentTools`$AgentToolsProtectedNames, "Wolfram`AgentTools`RunCloudMCPServer" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Export-Protected"
]

VerificationTest[
    MatchQ[ DownValues @ Wolfram`AgentTools`RunCloudMCPServer, { __ } ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Export-HasDefinition"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Transport: HTTP method*)

VerificationTest[
    cloudStatus @ <| "Body" -> cloudInitBodyUI |>,
    200,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Method-POST-200"
]

VerificationTest[
    cloudStatus @ <| "Method" -> "GET" |>,
    405,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Method-GET-405"
]

VerificationTest[
    cloudStatus @ <| "Method" -> "DELETE" |>,
    405,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Method-DELETE-405"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Transport: Origin validation*)

(* Absent Origin (typical for server-to-server LLM providers) is allowed. *)
VerificationTest[
    cloudStatus @ <| "Body" -> cloudBody[ "ping", 1 ] |>,
    200,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Origin-Absent-Allowed"
]

(* A trusted Wolfram Cloud Origin is allowed. *)
VerificationTest[
    cloudStatus @ <|
        "Body"    -> cloudBody[ "ping", 1 ],
        "Headers" -> <| "Accept" -> "application/json", "Origin" -> "https://www.wolframcloud.com" |>
    |>,
    200,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Origin-Trusted-Allowed"
]

(* A cross-site Origin is rejected (DNS-rebinding protection). *)
VerificationTest[
    cloudStatus @ <|
        "Body"    -> cloudBody[ "ping", 1 ],
        "Headers" -> <| "Accept" -> "application/json", "Origin" -> "https://evil.example" |>
    |>,
    403,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Origin-CrossSite-403"
]

(* A look-alike host is not treated as a subdomain of the trusted suffix. *)
VerificationTest[
    cloudStatus @ <|
        "Body"    -> cloudBody[ "ping", 1 ],
        "Headers" -> <| "Accept" -> "application/json", "Origin" -> "https://evilwolframcloud.com" |>
    |>,
    403,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Origin-LookAlike-403"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Transport: Accept negotiation*)

VerificationTest[
    With[ { resp = cloudRun @ <| "Body" -> cloudBody[ "ping", 1 ], "Headers" -> <| "Accept" -> "application/json" |> |> },
        { resp[ "StatusCode" ], resp[ "ContentType" ] }
    ],
    { 200, "application/json" },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Accept-JSON"
]

(* An absent Accept header defaults to application/json (client accepts anything). *)
VerificationTest[
    With[ { resp = cloudRun @ <| "Body" -> cloudBody[ "ping", 1 ], "Headers" -> <| |> |> },
        { resp[ "StatusCode" ], resp[ "ContentType" ] }
    ],
    { 200, "application/json" },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Accept-Absent-DefaultsJSON"
]

(* text/event-stream yields a single SSE data frame; the content type is text/event-stream (with a
   charset parameter that must reflect the UTF-8 body). *)
VerificationTest[
    With[ { resp = cloudRun @ <| "Body" -> cloudBody[ "ping", 1 ], "Headers" -> <| "Accept" -> "text/event-stream" |> |> },
        {
            resp[ "StatusCode" ],
            StringStartsQ[ resp[ "ContentType" ], "text/event-stream" ],
            ! StringContainsQ[ resp[ "ContentType" ], "iso-8859-1" ],
            StringStartsQ[ resp[ "Body" ], "data: " ] && StringEndsQ[ resp[ "Body" ], "\n\n" ]
        }
    ],
    { 200, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Accept-SSE"
]

(* An Accept listing neither supported type -> 406. *)
VerificationTest[
    cloudStatus @ <| "Body" -> cloudBody[ "ping", 1 ], "Headers" -> <| "Accept" -> "text/plain" |> |>,
    406,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Accept-Unacceptable-406"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Transport: MCP-Protocol-Version header*)

(* Absent header on a non-initialize request is allowed (assume 2025-03-26). *)
VerificationTest[
    cloudStatus @ <| "Body" -> cloudBody[ "ping", 1 ], "Headers" -> <| "Accept" -> "application/json" |> |>,
    200,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Protocol-Absent-Allowed"
]

(* A supported version is accepted. *)
VerificationTest[
    cloudStatus @ <|
        "Body"    -> cloudBody[ "ping", 1 ],
        "Headers" -> <| "Accept" -> "application/json", "MCP-Protocol-Version" -> "2025-06-18" |>
    |>,
    200,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Protocol-Supported-Allowed"
]

(* An unsupported version on a non-initialize request -> 400. *)
VerificationTest[
    cloudStatus @ <|
        "Body"    -> cloudBody[ "ping", 1 ],
        "Headers" -> <| "Accept" -> "application/json", "MCP-Protocol-Version" -> "1999-01-01" |>
    |>,
    400,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Protocol-Unsupported-400"
]

(* The initialize request itself is exempt from the header check (version is negotiated in the body). *)
VerificationTest[
    cloudStatus @ <|
        "Body"    -> cloudInitBodyUI,
        "Headers" -> <| "Accept" -> "application/json", "MCP-Protocol-Version" -> "1999-01-01" |>
    |>,
    200,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Protocol-InitializeExempt"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Transport: request body*)

(* A non-JSON body -> 400. *)
VerificationTest[
    cloudStatus @ <| "Body" -> "this is not json" |>,
    400,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Body-Malformed-400"
]

(* A well-formed but non-object JSON body (an array) -> 400. *)
VerificationTest[
    cloudStatus @ <| "Body" -> "[1,2,3]" |>,
    400,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Body-NonObject-400"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Dispatch*)

(* initialize echoes a supported requested protocol version and reports the server name. *)
VerificationTest[
    With[ { body = cloudBodyJSON @ cloudRun @ <| "Body" -> cloudBody[ "initialize", 0, <| "protocolVersion" -> "2024-11-05" |> ] |> },
        { body[ "result", "protocolVersion" ], body[ "result", "serverInfo", "name" ] }
    ],
    { "2024-11-05", cloudTestServer[ "Name" ] },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Initialize-Negotiates"
]

(* An unknown requested version falls back to the preferred one. *)
VerificationTest[
    cloudBodyJSON[ cloudRun @ <| "Body" -> cloudBody[ "initialize", 0, <| "protocolVersion" -> "1999-01-01" |> ] |> ][ "result", "protocolVersion" ],
    "2025-11-25",
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Initialize-UnknownVersionFallsBack"
]

(* tools/list returns the server object's tools. *)
VerificationTest[
    Lookup[ cloudBodyJSON[ cloudRun @ <| "Body" -> cloudBody[ "tools/list", 1 ] |> ][ "result", "tools" ], "name" ],
    { "PrimeFinder", "MCPAppsTest" },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-ToolsList-Tools"
]

(* tools/call evaluates a tool and returns its content. *)
VerificationTest[
    With[ { result = cloudBodyJSON[ cloudRun @ <| "Body" -> cloudBody[ "tools/call", 2, <| "name" -> "PrimeFinder", "arguments" -> <| "n" -> 5 |> |> ] |> ][ "result" ] },
        { result[ "content" ], result[ "isError" ] }
    ],
    { { KeyValuePattern[ { "type" -> "text", "text" -> "11" } ] }, False },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-ToolsCall-Result"
]

(* ping returns an empty result. *)
VerificationTest[
    cloudBodyJSON[ cloudRun @ <| "Body" -> cloudBody[ "ping", 3 ] |> ][ "result" ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Ping-Result"
]

(* An unknown method is reported in-band as JSON-RPC -32601 within a 200. *)
VerificationTest[
    With[ { resp = Quiet @ cloudRun @ <| "Body" -> cloudBody[ "no/suchMethod", 4 ] |> },
        { resp[ "StatusCode" ], cloudBodyJSON[ resp ][ "error", "code" ] }
    ],
    { 200, -32601 },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-UnknownMethod-32601"
]

(* A notification owes no reply: 202 with an empty body. *)
VerificationTest[
    With[ { resp = cloudRun @ <| "Body" -> cloudBody[ "notifications/initialized" ] |> },
        { resp[ "StatusCode" ], resp[ "Body" ] }
    ],
    { 202, "" },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-Notification-202"
]

(* A message with an explicit null id owes no reply: 202 with an empty body. *)
VerificationTest[
    With[ { resp = cloudRun @ <| "Body" -> cloudBody[ "ping", Null ] |> },
        { resp[ "StatusCode" ], resp[ "Body" ] }
    ],
    { 202, "" },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-NullId-202"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCP-Apps capability round-trip*)

(* initialize with the UI extension advertises the same extension back. *)
VerificationTest[
    cloudBodyJSON[ cloudRun @ <| "Body" -> cloudInitBodyUI |> ][ "result", "capabilities", "extensions" ],
    KeyValuePattern[ "io.modelcontextprotocol/ui" -> _ ],
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-InitUI-AdvertisesExtension"
]

(* ...and returns an Mcp-Session-Id whose feature bitfield decodes to {"MCPApps"}. Captures the session
   ID for the tools/resources tests below. *)
VerificationTest[
    uiInitResp  = cloudRun @ <| "Body" -> cloudInitBodyUI |>;
    uiSessionID = cloudSessionID @ uiInitResp;
    cloudDecode @ uiSessionID,
    { "MCPApps" },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-InitUI-SessionIDDecodesMCPApps"
]

(* initialize without the UI extension yields a session ID decoding to no features. *)
VerificationTest[
    noUiInitResp  = cloudRun @ <| "Body" -> cloudInitBodyNoUI |>;
    noUiSessionID = cloudSessionID @ noUiInitResp;
    cloudDecode @ noUiSessionID,
    { },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-InitNoUI-SessionIDDecodesEmpty"
]

(* With the UI session ID, tools/list attaches _meta.ui to the UI-associated tool. *)
VerificationTest[
    SelectFirst[
        cloudBodyJSON[
            cloudRun @ <|
                "Body"    -> cloudBody[ "tools/list", 1 ],
                "Headers" -> <| "Accept" -> "application/json", "Mcp-Session-Id" -> uiSessionID |>
            |>
        ][ "result", "tools" ],
        #[ "name" ] === "MCPAppsTest" &
    ],
    KeyValuePattern[ "_meta" -> KeyValuePattern[ "ui" -> KeyValuePattern[ "resourceUri" -> "ui://wolfram/mcp-apps-test" ] ] ],
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-ToolsList-UISessionHasMeta"
]

(* With the no-feature session ID, tools/list carries no _meta. *)
VerificationTest[
    KeyExistsQ[
        SelectFirst[
            cloudBodyJSON[
                cloudRun @ <|
                    "Body"    -> cloudBody[ "tools/list", 1 ],
                    "Headers" -> <| "Accept" -> "application/json", "Mcp-Session-Id" -> noUiSessionID |>
                |>
            ][ "result", "tools" ],
            #[ "name" ] === "MCPAppsTest" &
        ],
        "_meta"
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-ToolsList-NoFeatureSessionNoMeta"
]

(* With no Mcp-Session-Id header at all, UI is off (no _meta). *)
VerificationTest[
    KeyExistsQ[
        SelectFirst[
            cloudBodyJSON[ cloudRun @ <| "Body" -> cloudBody[ "tools/list", 1 ] |> ][ "result", "tools" ],
            #[ "name" ] === "MCPAppsTest" &
        ],
        "_meta"
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-ToolsList-NoSessionNoMeta"
]

(* A malformed / wrong-version session ID fails closed: UI stays off. *)
VerificationTest[
    KeyExistsQ[
        SelectFirst[
            cloudBodyJSON[
                cloudRun @ <|
                    "Body"    -> cloudBody[ "tools/list", 1 ],
                    "Headers" -> <| "Accept" -> "application/json", "Mcp-Session-Id" -> "2:1:whatever" |>
                |>
            ][ "result", "tools" ],
            #[ "name" ] === "MCPAppsTest" &
        ],
        "_meta"
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-ToolsList-MalformedSessionUIOff"
]

(* With the UI session ID, resources/list enumerates the UI registry. *)
VerificationTest[
    cloudBodyJSON[
        cloudRun @ <|
            "Body"    -> cloudBody[ "resources/list", 2 ],
            "Headers" -> <| "Accept" -> "application/json", "Mcp-Session-Id" -> uiSessionID |>
        |>
    ][ "result", "resources" ],
    { __Association },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-ResourcesList-UISessionEnumerates"
]

(* Without UI, resources/list is empty. *)
VerificationTest[
    cloudBodyJSON[ cloudRun @ <| "Body" -> cloudBody[ "resources/list", 2 ] |> ][ "result", "resources" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-ResourcesList-NoSessionEmpty"
]

(* With the UI session ID, resources/read returns the app HTML for a registered URI. *)
VerificationTest[
    cloudBodyJSON[
        cloudRun @ <|
            "Body"    -> cloudBody[ "resources/read", 3, <| "uri" -> "ui://wolfram/mcp-apps-test" |> ],
            "Headers" -> <| "Accept" -> "application/json", "Mcp-Session-Id" -> uiSessionID |>
        |>
    ][ "result", "contents" ],
    { KeyValuePattern[ { "uri" -> "ui://wolfram/mcp-apps-test", "text" -> _String } ] },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-ResourcesRead-UISessionReturnsHTML"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error handling*)

(* A dispatch/tool failure is reported in-band as JSON-RPC -32603 within a 200 (not a raw Failure and
   not a 500). A tools/call with no tool name makes evaluateTool throw an internal failure, which the
   inner catchAlways converts to the -32603 response. *)
VerificationTest[
    With[ { resp = Quiet @ cloudRun @ <| "Body" -> cloudBody[ "tools/call", 5, <| "arguments" -> <| |> |> ] |> },
        { resp[ "StatusCode" ], cloudBodyJSON[ resp ][ "error", "code" ] }
    ],
    { 200, -32603 },
    SameTest -> MatchQ,
    TestID   -> "CloudHandler-ToolFailure-32603In200"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CloudDeployMCPServer (server embedding & deployment)*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Export & message wiring*)

VerificationTest[
    MemberQ[ Wolfram`AgentTools`$AgentToolsProtectedNames, "Wolfram`AgentTools`CloudDeployMCPServer" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudDeploy-Export-Protected"
]

VerificationTest[
    MatchQ[ DownValues @ Wolfram`AgentTools`CloudDeployMCPServer, { __ } ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudDeploy-Export-HasDefinition"
]

(* The CloudDeployFailed message tag is registered (throwFailure requires it to exist). *)
VerificationTest[
    StringQ @ MessageName[ Wolfram`AgentTools`AgentTools, "CloudDeployFailed" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudDeploy-Message-CloudDeployFailedExists"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fixtures*)

(* A helper referenced INSIDE the tool function, i.e. hidden behind LLMTool's NOENTRY flag. Its definition
   is only reconstructible in a bare cloud kernel if the NOENTRY-aware capture picks it up. *)
cloudEmbedHelper[ n_ ] := Prime[ n ] + 1000;

(* A fully self-contained custom server: an anonymous pure-function tool closing over cloudEmbedHelper,
   with no built-in/paclet/Chatbook dependency. *)
cloudEmbedServer = Wolfram`AgentTools`MCPServerObject[ <|
    "Location"     -> "BuiltIn",
    "LLMEvaluator" -> <| "Tools" -> {
        LLMTool[ "PrimePlus", { "n" -> "Integer" }, cloudEmbedHelper[ #n ] & ]
    } |>
|> ];

(* The definition-bearing Delayed[...] payload the deploy helper produces. Building it runs the full
   NOENTRY-aware / internal-contexts capture over the RunCloudMCPServer dependency tree. *)
cloudEmbedPayload = Wolfram`AgentTools`Server`Cloud`Private`cloudMCPServerPayload @ cloudEmbedServer;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deAgentToolsInternalContexts (dev-bundling bridge)*)

(* Removes every Wolfram`AgentTools`* entry so those definitions can be captured rather than stripped. *)
VerificationTest[
    FreeQ[
        Wolfram`AgentTools`Server`Cloud`Private`deAgentToolsInternalContexts[ ],
        _String? (StringStartsQ[ "Wolfram`AgentTools`" ])
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "DeAgentToolsInternalContexts-RemovesAgentTools"
]

(* Leaves the other internal contexts (e.g. Wolfram`Chatbook`*, which stays internal and is installed at
   cold start rather than bundled) intact -- only the AgentTools entries are dropped. *)
VerificationTest[
    With[
        {
            stripped  = Wolfram`AgentTools`Server`Cloud`Private`deAgentToolsInternalContexts[ ],
            agentToolEntries = Select[ Language`$InternalContexts, StringQ[ # ] && StringStartsQ[ #, "Wolfram`AgentTools`" ] & ]
        },
        {
            Complement[ Language`$InternalContexts, stripped ] === agentToolEntries,
            SubsetQ[ Language`$InternalContexts, stripped ]
        }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "DeAgentToolsInternalContexts-KeepsOthers"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cloudMCPServerPayload (definition-bearing payload)*)

(* The payload is a held Delayed[...] -- the handler is NOT evaluated at build time. *)
VerificationTest[
    Head @ cloudEmbedPayload,
    Delayed,
    SameTest -> MatchQ,
    TestID   -> "CloudMCPServerPayload-IsDelayed"
]

(* The NOENTRY-hidden helper's definition is captured (flag-based blocking overcome). *)
VerificationTest[
    ! FreeQ[ cloudEmbedPayload, cloudEmbedHelper ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudMCPServerPayload-CapturesNoEntryHelper"
]

(* The AgentTools handler tree is captured (context-based stripping overcome by the dev bridge). *)
VerificationTest[
    ! FreeQ[ cloudEmbedPayload, Wolfram`AgentTools`Server`Cloud`Private`runCloudMCPServer ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudMCPServerPayload-CapturesHandler"
]

(* The gathered definitions are injected via Language`ExtendedFullDefinition[ ] = defs, so the cloud
   kernel restores them on each request. *)
VerificationTest[
    ! FreeQ[ cloudEmbedPayload, HoldPattern[ Language`ExtendedFullDefinition[ ] = _ ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudMCPServerPayload-HasEFDInjection"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*injectServerDefinitions*)

(* An empty DefinitionList needs no injection: just the held handler call, no EFD assignment. *)
VerificationTest[
    With[
        { payload = Wolfram`AgentTools`Server`Cloud`Private`injectServerDefinitions[
            Language`DefinitionList[ ], cloudEmbedServer ] },
        { Head @ payload, FreeQ[ payload, Language`ExtendedFullDefinition ] }
    ],
    { Delayed, True },
    SameTest -> MatchQ,
    TestID   -> "InjectServerDefinitions-EmptyNoInjection"
]

(* A non-empty DefinitionList is injected ahead of the held handler call. *)
VerificationTest[
    With[
        { payload = Wolfram`AgentTools`Server`Cloud`Private`injectServerDefinitions[
            Language`DefinitionList[ HoldForm[ Global`someSym ] -> { } ], cloudEmbedServer ] },
        { Head @ payload, ! FreeQ[ payload, HoldPattern[ Language`ExtendedFullDefinition[ ] = _ ] ] }
    ],
    { Delayed, True },
    SameTest -> MatchQ,
    TestID   -> "InjectServerDefinitions-NonEmptyInjects"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*End-to-end deployment (cloud-gated)*)

(* Deploy the self-contained custom server to the real cloud and exercise it. Gated on $CloudConnected:
   when there is no cloud session (the usual CI case) the probe returns "no-cloud" and the test passes
   trivially; when connected it deploys via CloudDeployMCPServer, authenticates with a PermissionsKey via
   the ?_key= URL form, calls the NOENTRY-hidden tool (Prime[5] + 1000 = 1011), and cleans up. This
   confirms both capture mechanisms end to end -- the custom tool function and the AgentTools dev bundle
   -- with no relevant paclet pre-installed. *)
cloudDeployEndToEndProbe[ ] := If[ ! TrueQ @ $CloudConnected,
    "no-cloud",
    Module[ { key, obj, content },
        key = CreateUUID[ ];
        obj = Wolfram`AgentTools`CloudDeployMCPServer[
            cloudEmbedServer,
            "Claude/agenttools-cloud-test",
            Permissions -> { PermissionsKey[ key ] -> "Execute" }
        ];
        content = If[ MatchQ[ obj, _CloudObject ],
            Module[ { resp },
                resp = URLRead @ HTTPRequest[
                    First[ obj ] <> "?_key=" <> key,
                    <|
                        "Method"  -> "POST",
                        "Headers" -> <| "Content-Type" -> "application/json", "Accept" -> "application/json" |>,
                        "Body"    -> Developer`WriteRawJSONString @ <|
                            "jsonrpc" -> "2.0", "id" -> 1, "method" -> "tools/call",
                            "params"  -> <| "name" -> "PrimePlus", "arguments" -> <| "n" -> 5 |> |>
                        |>
                    |>
                ];
                Quiet @ Developer`ReadRawJSONString[ resp[ "Body" ] ][ "result", "content" ]
            ],
            obj
        ];
        Quiet[ DeleteObject @ obj; DeleteObject @ PermissionsKey @ key ];
        content
    ]
];

VerificationTest[
    cloudDeployEndToEndProbe[ ],
    "no-cloud" | { KeyValuePattern[ { "type" -> "text", "text" -> "1011" } ] },
    SameTest -> MatchQ,
    TestID   -> "CloudDeploy-Endpoint-EndToEnd"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Landing Page & Server Info (/api/info)*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fixtures*)

(* A tool with an explicit DisplayName and Description, so the info projection's title/description fields
   are exercised (the plain 3-argument LLMTool below has neither). *)
cloudInfoGammaTool = LLMTool[ <|
    "Name"        -> "Gamma",
    "DisplayName" -> "Gamma Tool",
    "Description" -> "Computes a gamma value.",
    "Parameters"  -> { "n" -> <| "Interpreter" -> "Integer", "Help" -> "an integer", "Required" -> True |> },
    "Function"    -> Function[ Gamma[ #n ] ]
|> ];

(* An in-memory server (no disk persistence) with an explicit name and two tools -- one rich, one plain. *)
cloudInfoServer = Wolfram`AgentTools`MCPServerObject[ <|
    "Name"         -> "InfoRich",
    "Location"     -> "BuiltIn",
    "LLMEvaluator" -> <| "Tools" -> { cloudInfoGammaTool, LLMTool[ "Plain", { "x" -> "String" }, #x & ] } |>
|> ];

cloudInfoURL    = "https://www.wolframcloud.com/obj/user/dir/mcp";
cloudInfoResult = Wolfram`AgentTools`Server`Cloud`Private`cloudMCPServerInfo[ cloudInfoServer, cloudInfoURL ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*serverToolListData (shared tool-list construction)*)

(* An empty tool list yields no data (no side effects). *)
VerificationTest[
    Wolfram`AgentTools`Server`serverToolListData[ { } ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ServerToolListData-Empty"
]

(* Builds the same disambiguated name set tools/list produces, from the server object directly. *)
VerificationTest[
    #[ "name" ] & /@ Wolfram`AgentTools`Server`serverToolListData[ cloudInfoServer ],
    { "Gamma", "Plain" },
    SameTest -> MatchQ,
    TestID   -> "ServerToolListData-Names"
]

(* Each entry is the full $toolList-shape association (carries inputSchema), i.e. the same construction
   tools/list uses -- not the trimmed public projection. *)
VerificationTest[
    With[ { data = Wolfram`AgentTools`Server`serverToolListData[ cloudInfoServer ] },
        MatchQ[ data, { __Association } ] && AllTrue[ data, KeyExistsQ[ #, "inputSchema" ] & ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ServerToolListData-HasInputSchema"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cloudInfoTool (public tool projection)*)

(* Projects a $toolList entry down to name/title/description, dropping inputSchema and annotations. *)
VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`cloudInfoTool[
        <| "name" -> "X", "title" -> "T", "description" -> "D", "inputSchema" -> <| |>, "annotations" -> <| |> |>
    ],
    <| "name" -> "X", "title" -> "T", "description" -> "D" |>,
    SameTest -> MatchQ,
    TestID   -> "CloudInfoTool-Projects"
]

(* A tool with no title (DisplayName) omits the title field entirely. *)
VerificationTest[
    KeyExistsQ[
        Wolfram`AgentTools`Server`Cloud`Private`cloudInfoTool[
            <| "name" -> "X", "description" -> "D", "inputSchema" -> <| |> |>
        ],
        "title"
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "CloudInfoTool-NoTitle"
]

(* A missing description defaults to the empty string (never Missing in the JSON). *)
VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`cloudInfoTool[ <| "name" -> "X" |> ],
    <| "name" -> "X", "description" -> "" |>,
    SameTest -> MatchQ,
    TestID   -> "CloudInfoTool-DescriptionDefault"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cloudMCPServerInfo (/api/info payload)*)

(* The payload carries exactly name/version/url/tools -- no keys, permissions, or usage data leak. *)
VerificationTest[
    Sort @ Keys @ cloudInfoResult,
    { "name", "tools", "url", "version" },
    SameTest -> MatchQ,
    TestID   -> "CloudMCPServerInfo-Keys"
]

(* Name, version, and the deployer-supplied endpoint URL are carried through. *)
VerificationTest[
    { cloudInfoResult[ "name" ], cloudInfoResult[ "version" ], cloudInfoResult[ "url" ] },
    { "InfoRich", "1.0.0", cloudInfoURL },
    SameTest -> MatchQ,
    TestID   -> "CloudMCPServerInfo-NameVersionURL"
]

(* The tools list is the projected shape: the rich tool carries title + description, the plain tool
   carries only name + description. *)
VerificationTest[
    MatchQ[
        cloudInfoResult[ "tools" ],
        {
            KeyValuePattern[ { "name" -> "Gamma", "title" -> "Gamma Tool", "description" -> "Computes a gamma value." } ],
            KeyValuePattern[ { "name" -> "Plain" } ]
        }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudMCPServerInfo-Tools"
]

(* The plain tool has no title field. *)
VerificationTest[
    KeyExistsQ[ cloudInfoResult[ "tools" ][[ 2 ]], "title" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "CloudMCPServerInfo-PlainToolNoTitle"
]

(* The public tool projection drops inputSchema -- /api/info advertises what tools are, not their schema. *)
VerificationTest[
    AnyTrue[ cloudInfoResult[ "tools" ], KeyExistsQ[ #, "inputSchema" ] & ],
    False,
    SameTest -> MatchQ,
    TestID   -> "CloudMCPServerInfo-NoInputSchema"
]

(* The whole payload is JSON-serializable (it is plain-data: strings, associations, and lists). *)
VerificationTest[
    StringQ @ Developer`WriteRawJSONString @ cloudInfoResult,
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudMCPServerInfo-JSONSerializable"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cloud assets (PacletInfo extension + landing page)*)

(* The Cloud asset directory is registered in PacletInfo.wl and resolves to a real directory. *)
VerificationTest[
    DirectoryQ @ PacletObject[ "Wolfram/AgentTools" ][ "AssetLocation", "Cloud" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudAssets-AssetLocationResolves"
]

(* The landing-page shell and its CSS/JS are all present under the asset directory. *)
VerificationTest[
    With[ { dir = PacletObject[ "Wolfram/AgentTools" ][ "AssetLocation", "Cloud" ] },
        AllTrue[
            { "index.html", FileNameJoin @ { "assets", "landing.css" }, FileNameJoin @ { "assets", "landing.js" } },
            FileExistsQ @ FileNameJoin @ { dir, # } &
        ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudAssets-FilesExist"
]

(* index.html links its stylesheet/script and carries the containers the JS fills. *)
VerificationTest[
    With[ { html = Import[ FileNameJoin @ { PacletObject[ "Wolfram/AgentTools" ][ "AssetLocation", "Cloud" ], "index.html" }, "Text" ] },
        AllTrue[
            { "assets/landing.css", "assets/landing.js", "endpoint-url", "snippet-openai", "snippet-anthropic", "tools" },
            StringContainsQ[ html, # ] &
        ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudAssets-IndexHTML-Content"
]

(* landing.js fetches /api/info, uses the <YOUR_KEY> placeholder, and builds the generic/OpenAI/Anthropic
   config shapes (bearer header, server_url, and the ?_key= URL form). *)
VerificationTest[
    With[ { js = Import[ FileNameJoin @ { PacletObject[ "Wolfram/AgentTools" ][ "AssetLocation", "Cloud" ], "assets", "landing.js" }, "Text" ] },
        AllTrue[
            { "api/info", "<YOUR_KEY>", "Bearer ", "server_url", "?_key=" },
            StringContainsQ[ js, # ] &
        ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CloudAssets-LandingJS-Content"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Admin Page & Key Management (/api/admin)*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fixtures*)

(* A fake (undeployed) deployment directory. Constructing a CloudObject from a URL touches no network, and
   FileNameJoin resolves siblings purely by string manipulation, so the sibling-resolution / dispatch /
   transport tests below run fully in-process. Actions that hit the cloud (Information / SetPermissions /
   DeleteObject) are exercised only by the cloud-gated end-to-end probe. *)
adminFakeBase = CloudObject[ "https://www.wolframcloud.com/obj/user/dir" ];

(* A mock request shaped like the association RunCloudAdminAPI reads: Method + UTF-8 BodyByteArray. *)
adminMockRequest[ opts_Association ] := <|
    "Method"        -> Lookup[ opts, "Method", "POST" ],
    "BodyByteArray" -> Replace[ Lookup[ opts, "Body", Missing[ ] ], s_String :> StringToByteArray @ s ]
|>;

adminRun[ opts_Association ] :=
    Wolfram`AgentTools`Server`Cloud`Private`runCloudAdminAPI[ adminFakeBase, adminMockRequest @ opts ];

adminStatus[ opts_Association ] := adminRun[ opts ][ "StatusCode" ];
adminBodyJSON[ resp_ ]          := Quiet @ Developer`ReadRawJSONString @ resp[ "Body" ];
adminActionBody[ assoc_ ]       := Developer`WriteRawJSONString @ assoc;

(* Directly dispatch an action against the fake base (only safe for actions that do not reach the cloud). *)
adminAction[ action_, params_: <| |> ] :=
    Wolfram`AgentTools`Server`Cloud`Private`cloudAdminAction[ adminFakeBase, action, params ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Deployment sibling resolution*)

(* /mcp and the key-label store resolve as siblings of the captured deployment base. *)
VerificationTest[
    First @ Wolfram`AgentTools`Server`Cloud`Private`adminMCPObject @ adminFakeBase,
    "https://www.wolframcloud.com/obj/user/dir/mcp",
    SameTest -> MatchQ,
    TestID   -> "Admin-MCPObject-Sibling"
]

VerificationTest[
    First @ Wolfram`AgentTools`Server`Cloud`Private`adminKeyLabelStore @ adminFakeBase,
    "https://www.wolframcloud.com/obj/user/dir/admin/keys.wxf",
    SameTest -> MatchQ,
    TestID   -> "Admin-KeyLabelStore-Sibling"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validKeyStringQ*)

(* A well-formed UUID (as CreateUUID mints) is a revocable key. *)
VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`validKeyStringQ @ CreateUUID[ ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Admin-ValidKey-UUID"
]

(* A non-UUID string, a non-string, and a missing value are all rejected (guarding DeleteObject). *)
VerificationTest[
    Wolfram`AgentTools`Server`Cloud`Private`validKeyStringQ /@ { "not-a-uuid", "", 12345, Null },
    { False, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "Admin-ValidKey-Rejects"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Action dispatch (no cloud)*)

(* An unrecognized action fails closed with ok -> False. *)
VerificationTest[
    adminAction[ "bogus", <| |> ],
    <| "ok" -> False, "error" -> "Unknown action: bogus" |>,
    SameTest -> MatchQ,
    TestID   -> "Admin-Action-Unknown"
]

(* A missing action (no "action" key) also fails closed. *)
VerificationTest[
    adminAction[ None, <| |> ],
    <| "ok" -> False, "error" -> "Unknown action: (none)" |>,
    SameTest -> MatchQ,
    TestID   -> "Admin-Action-NoAction"
]

(* revokeKey validates its key before any cloud call: a missing or malformed key is rejected in-process. *)
VerificationTest[
    { adminAction[ "revokeKey", <| |> ], adminAction[ "revokeKey", <| "key" -> "not-a-uuid" |> ] },
    { <| "ok" -> False, "error" -> "Missing or invalid key." |>, <| "ok" -> False, "error" -> "Missing or invalid key." |> },
    SameTest -> MatchQ,
    TestID   -> "Admin-Action-RevokeInvalidKey"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Response construction*)

(* A successful action is a 200; a client-side (ok -> False) result is a 400. *)
VerificationTest[
    {
        Wolfram`AgentTools`Server`Cloud`Private`adminActionResponse[ <| "ok" -> True, "keys" -> { } |> ][ "StatusCode" ],
        Wolfram`AgentTools`Server`Cloud`Private`adminActionResponse[ <| "ok" -> False, "error" -> "x" |> ][ "StatusCode" ]
    },
    { 200, 400 },
    SameTest -> MatchQ,
    TestID   -> "Admin-ActionResponse-StatusCodes"
]

(* The response is application/json and its body round-trips the data. *)
VerificationTest[
    With[ { resp = Wolfram`AgentTools`Server`Cloud`Private`adminJSONResponse[ <| "ok" -> True, "keys" -> { } |>, 200 ] },
        { resp[ "StatusCode" ], resp[ "ContentType" ], adminBodyJSON @ resp }
    ],
    { 200, "application/json", <| "ok" -> True, "keys" -> { } |> },
    SameTest -> MatchQ,
    TestID   -> "Admin-JSONResponse-Shape"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Transport (via the handler)*)

(* Only POST is dispatched; GET and DELETE are 405. *)
VerificationTest[
    { adminStatus @ <| "Method" -> "GET" |>, adminStatus @ <| "Method" -> "DELETE" |> },
    { 405, 405 },
    SameTest -> MatchQ,
    TestID   -> "Admin-Transport-MethodNotAllowed"
]

(* A non-JSON body is a 400. *)
VerificationTest[
    adminStatus @ <| "Body" -> "not json" |>,
    400,
    SameTest -> MatchQ,
    TestID   -> "Admin-Transport-MalformedBody"
]

(* A well-formed POST with an unrecognized action dispatches to a 400 JSON error (no cloud call). *)
VerificationTest[
    With[ { resp = adminRun @ <| "Body" -> adminActionBody @ <| "action" -> "bogus" |> |> },
        { resp[ "StatusCode" ], TrueQ @ adminBodyJSON[ resp ][ "ok" ] }
    ],
    { 400, False },
    SameTest -> MatchQ,
    TestID   -> "Admin-Transport-UnknownActionDispatch"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cloud-file helpers*)

(* The generic cloud-WXF helpers are declared (Files.wl) and defined. *)
VerificationTest[
    {
        MatchQ[ DownValues @ Wolfram`AgentTools`Common`readCloudWXF, { __ } ],
        MatchQ[ DownValues @ Wolfram`AgentTools`Common`writeCloudWXF, { __ } ]
    },
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "Admin-CloudWXFHelpers-Defined"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cloudAdminAPIPayload (definition-bearing payload)*)

adminPayload = Wolfram`AgentTools`Server`Cloud`Private`cloudAdminAPIPayload @ adminFakeBase;

(* The payload is a held Delayed[...] -- the handler is NOT evaluated at build time. *)
VerificationTest[
    Head @ adminPayload,
    Delayed,
    SameTest -> MatchQ,
    TestID   -> "Admin-Payload-IsDelayed"
]

(* The AgentTools handler tree is captured (context-based stripping overcome by the dev bridge). *)
VerificationTest[
    ! FreeQ[ adminPayload, Wolfram`AgentTools`Server`Cloud`Private`runCloudAdminAPI ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Admin-Payload-CapturesHandler"
]

(* The gathered definitions are injected via Language`ExtendedFullDefinition[ ] = defs. *)
VerificationTest[
    ! FreeQ[ adminPayload, HoldPattern[ Language`ExtendedFullDefinition[ ] = _ ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Admin-Payload-HasEFDInjection"
]

(* The captured deployment base is embedded, so the deployed handler resolves its own /mcp sibling. *)
VerificationTest[
    ! FreeQ[ adminPayload, "https://www.wolframcloud.com/obj/user/dir" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Admin-Payload-EmbedsBase"
]

(* An empty DefinitionList needs no injection: just the held handler call, no EFD assignment. *)
VerificationTest[
    With[
        { payload = Wolfram`AgentTools`Server`Cloud`Private`injectAdminDefinitions[
            Language`DefinitionList[ ], adminFakeBase ] },
        { Head @ payload, FreeQ[ payload, Language`ExtendedFullDefinition ] }
    ],
    { Delayed, True },
    SameTest -> MatchQ,
    TestID   -> "Admin-InjectDefinitions-EmptyNoInjection"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Admin assets (admin page)*)

(* The self-contained admin page is present under the Cloud asset directory. *)
VerificationTest[
    FileExistsQ @ FileNameJoin @ { PacletObject[ "Wolfram/AgentTools" ][ "AssetLocation", "Cloud" ], "admin.html" },
    True,
    SameTest -> MatchQ,
    TestID   -> "Admin-Assets-FileExists"
]

(* admin.html is self-contained (inline style/script, no external /assets references), resolves the sibling
   api/admin endpoint, and drives the three key-management actions. *)
VerificationTest[
    With[ { html = Import[ FileNameJoin @ { PacletObject[ "Wolfram/AgentTools" ][ "AssetLocation", "Cloud" ], "admin.html" }, "Text" ] },
        {
            AllTrue[ { "api/admin", "listKeys", "createKey", "revokeKey", "<style>", "<script>" }, StringContainsQ[ html, # ] & ],
            StringContainsQ[ html, "assets/landing" ]
        }
    ],
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "Admin-Assets-Content"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*End-to-end key management (cloud-gated)*)

(* Deploy a private /mcp placeholder in a deployment directory and exercise the full key lifecycle through
   the real admin dispatch. Gated on $CloudConnected: with no cloud session the probe returns "no-cloud"
   and the test passes trivially. When connected it verifies both Task-7 requirements: createKey mints a key
   that appears in Information[mcp,"Permissions"] AND is usable against /mcp (HTTP 200 via ?_key=), listKeys
   reflects it with its label, and revokeKey removes it from the permissions AND stops it working (HTTP 401). *)
adminKeyMgmtProbe[ ] := If[ ! TrueQ @ $CloudConnected,
    "no-cloud",
    Module[
        {
            base, mcp, mcpURL, label, permKeys, created, key, listed,
            inPermsAfterCreate, usableAfterCreate, revoked, inPermsAfterRevoke, usableAfterRevoke
        },
        label    = "probe-label";
        base     = CloudObject[ "Claude/agenttools-admin-test", Permissions -> "Private" ];
        mcp      = CloudDeploy[ Delayed[ 42 ], FileNameJoin @ { base, "mcp" }, Permissions -> "Private" ];
        mcpURL   = First @ mcp;
        permKeys = Cases[ Information[ mcp, "Permissions" ], HoldPattern[ PermissionsKey[ u_String ] -> _ ] :> u ] &;

        created = Wolfram`AgentTools`Server`Cloud`Private`cloudAdminAction[ base, "createKey", <| "label" -> label |> ];
        key     = created[ "created", "key" ];
        If[ ! StringQ @ key, key = "" ];

        inPermsAfterCreate = MemberQ[ permKeys[ ], key ];
        usableAfterCreate  = URLRead[ mcpURL <> "?_key=" <> key ][ "StatusCode" ];

        listed = Wolfram`AgentTools`Server`Cloud`Private`cloudAdminAction[ base, "listKeys", <| |> ];

        revoked            = Wolfram`AgentTools`Server`Cloud`Private`cloudAdminAction[ base, "revokeKey", <| "key" -> key |> ];
        inPermsAfterRevoke = MemberQ[ permKeys[ ], key ];
        usableAfterRevoke  = URLRead[ mcpURL <> "?_key=" <> key ][ "StatusCode" ];

        Quiet[
            DeleteObject @ PermissionsKey @ key;
            DeleteObject @ mcp;
            DeleteObject @ FileNameJoin @ { base, "admin", "keys.wxf" };
            DeleteObject @ base
        ];

        <|
            "createdOk"          -> TrueQ @ created[ "ok" ],
            "keyIsUUID"          -> Wolfram`AgentTools`Server`Cloud`Private`validKeyStringQ @ key,
            "inPermsAfterCreate" -> inPermsAfterCreate,
            "usableAfterCreate"  -> usableAfterCreate,
            "listedWithLabel"    -> MemberQ[ listed[ "keys" ], KeyValuePattern @ { "key" -> key, "label" -> label } ],
            "revokedOk"          -> TrueQ @ revoked[ "ok" ],
            "inPermsAfterRevoke" -> inPermsAfterRevoke,
            "usableAfterRevoke"  -> usableAfterRevoke
        |>
    ]
];

VerificationTest[
    adminKeyMgmtProbe[ ],
    "no-cloud" | KeyValuePattern @ {
        "createdOk"          -> True,
        "keyIsUUID"          -> True,
        "inPermsAfterCreate" -> True,
        "usableAfterCreate"  -> 200,
        "listedWithLabel"    -> True,
        "revokedOk"          -> True,
        "inPermsAfterRevoke" -> False,
        "usableAfterRevoke"  -> 401
    },
    SameTest -> MatchQ,
    TestID   -> "Admin-KeyManagement-EndToEnd"
]

(* :!CodeAnalysis::EndBlock:: *)
