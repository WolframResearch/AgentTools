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

VerificationTest[
    $testResourceDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources" },
    _? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "Setup-TestResources"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Built-in Server Formatting*)

VerificationTest[
    ToBoxes @ MCPServerObject[ "Wolfram" ],
    _InterpretationBox,
    SameTest -> MatchQ,
    TestID   -> "ToBoxes-Wolfram"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paclet Server Formatting*)

VerificationTest[
    $mockPacletDirectory = FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
    PacletDirectoryLoad @ $mockPacletDirectory,
    { __String },
    SameTest -> MatchQ,
    TestID   -> "MockPacletDirectory"
]

VerificationTest[
    server = MCPServerObject[ "MockMCPPacletTest/TestServer" ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-Paclet"
]

VerificationTest[
    ToBoxes @ server,
    _InterpretationBox,
    SameTest -> MatchQ,
    TestID   -> "ToBoxes-Paclet"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Unit Tests*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeMCPServerObjectBoxes*)
VerificationTest[
    Wolfram`AgentTools`Common`makeMCPServerObjectBoxes[
        MCPServerObject[ "MockMCPPacletTest/TestServer" ],
        StandardForm
    ],
    _InterpretationBox,
    SameTest -> MatchQ,
    TestID   -> "MakeMCPServerObjectBoxes-Paclet"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)

VerificationTest[
    PacletDirectoryUnload @ $mockPacletDirectory,
    { Except[ $mockPacletDirectory ]... },
    SameTest -> MatchQ,
    TestID   -> "MockPacletCleanup"
]
