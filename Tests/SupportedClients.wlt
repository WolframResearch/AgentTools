(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/SupportedClients.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/SupportedClients.wlt:11,1-16,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DetectedMCPClients*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Returns an association of supported client metadata keyed by canonical name*)
VerificationTest[
    DetectedMCPClients[ ],
    KeyValuePattern[ { } ]?AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DetectedMCPClients-ReturnShape@@Tests/SupportedClients.wlt:25,1-30,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*All detected names are valid supported clients*)
VerificationTest[
    SubsetQ[ Keys @ $SupportedMCPClients, Keys @ DetectedMCPClients[ ] ],
    True,
    TestID -> "DetectedMCPClients-Subset@@Tests/SupportedClients.wlt:35,1-39,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Result preserves the ordering of $SupportedMCPClients*)
VerificationTest[
    With[ { detected = DetectedMCPClients[ ] },
        Keys[ detected ] === Select[ Keys @ $SupportedMCPClients, KeyExistsQ[ detected, # ] & ]
    ],
    True,
    TestID -> "DetectedMCPClients-Ordering@@Tests/SupportedClients.wlt:44,1-50,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid arguments*)
VerificationTest[
    DetectedMCPClients[ "bogus" ],
    _Failure,
    { DetectedMCPClients::InvalidArguments },
    SameTest -> MatchQ,
    TestID   -> "DetectedMCPClients-InvalidArguments@@Tests/SupportedClients.wlt:55,1-61,2"
]
