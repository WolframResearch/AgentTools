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

(* :!CodeAnalysis::EndBlock:: *)
