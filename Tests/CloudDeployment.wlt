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

(* :!CodeAnalysis::EndBlock:: *)
