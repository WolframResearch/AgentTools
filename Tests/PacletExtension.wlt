(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/PacletExtension.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/PacletExtension.wlt:11,1-16,2"
]

VerificationTest[
    $testResourceDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources" },
    _? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "TestResourcesDirectory@@Tests/PacletExtension.wlt:18,1-23,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Mock Paclet Setup*)
(* Load mock paclet with per-item definition files *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
    $mockPacletTest = PacletObject[ "MockMCPPacletTest" ];
    $mockPacletTest[ "Name" ],
    "MockMCPPacletTest",
    SameTest -> MatchQ,
    TestID   -> "MockPacletSetup-PerItem@@Tests/PacletExtension.wlt:29,1-36,2"
]

(* Load mock paclet with combined definition files *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletCombined" };
    $mockPacletCombined = PacletObject[ "MockMCPPacletCombined" ];
    $mockPacletCombined[ "Name" ],
    "MockMCPPacletCombined",
    SameTest -> MatchQ,
    TestID   -> "MockPacletSetup-Combined@@Tests/PacletExtension.wlt:39,1-46,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Resolve MCPServerObject*)
VerificationTest[
    obj = MCPServerObject[ "MockMCPPacletTest/TestServer" ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "ResolveMCPServerObject-Valid@@Tests/PacletExtension.wlt:51,1-56,2"
]

VerificationTest[
    tools = obj[ "Tools" ],
    { __LLMTool },
    SameTest -> MatchQ,
    TestID   -> "ResolveMCPServerObject-Tools@@Tests/PacletExtension.wlt:58,1-63,2"
]

VerificationTest[
    #[ "Name" ] & /@ tools,
    { "TestTool", "DescribedTool", "LLMToolTest" },
    SameTest -> MatchQ,
    TestID   -> "ResolveMCPServerObject-Tools-Names@@Tests/PacletExtension.wlt:65,1-70,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Unit Tests*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*pacletQualifiedNameQ*)
VerificationTest[
    Wolfram`AgentTools`Common`pacletQualifiedNameQ[ "Wolfram/JIRALink/GetIssue" ],
    True,
    TestID -> "pacletQualifiedNameQ-ThreeSegment@@Tests/PacletExtension.wlt:82,1-86,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`pacletQualifiedNameQ[ "JIRALink/GetIssue" ],
    True,
    TestID -> "pacletQualifiedNameQ-TwoSegment@@Tests/PacletExtension.wlt:88,1-92,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`pacletQualifiedNameQ[ "WolframAlpha" ],
    False,
    TestID -> "pacletQualifiedNameQ-NoSlash@@Tests/PacletExtension.wlt:94,1-98,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`pacletQualifiedNameQ[ "" ],
    False,
    TestID -> "pacletQualifiedNameQ-EmptyString@@Tests/PacletExtension.wlt:100,1-104,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`pacletQualifiedNameQ[ 123 ],
    False,
    TestID -> "pacletQualifiedNameQ-NonString@@Tests/PacletExtension.wlt:106,1-110,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`pacletQualifiedNameQ[ ],
    False,
    TestID -> "pacletQualifiedNameQ-NoArgs@@Tests/PacletExtension.wlt:112,1-116,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parsePacletQualifiedName*)
VerificationTest[
    Wolfram`AgentTools`Common`parsePacletQualifiedName[ "JIRALink/GetIssue" ],
    <| "PacletName" -> "JIRALink", "ItemName" -> "GetIssue" |>,
    SameTest -> MatchQ,
    TestID   -> "parsePacletQualifiedName-TwoSegment@@Tests/PacletExtension.wlt:121,1-126,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`parsePacletQualifiedName[ "Wolfram/JIRALink/GetIssue" ],
    <| "PacletName" -> "Wolfram/JIRALink", "ItemName" -> "GetIssue" |>,
    SameTest -> MatchQ,
    TestID   -> "parsePacletQualifiedName-ThreeSegment@@Tests/PacletExtension.wlt:128,1-133,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`parsePacletQualifiedName[ "Wolfram/JIRALink/ProjectManagement" ],
    <| "PacletName" -> "Wolfram/JIRALink", "ItemName" -> "ProjectManagement" |>,
    SameTest -> MatchQ,
    TestID   -> "parsePacletQualifiedName-ThreeSegmentServer@@Tests/PacletExtension.wlt:135,1-140,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`parsePacletQualifiedName[ "MyPaclet/MyTool" ],
    <| "PacletName" -> "MyPaclet", "ItemName" -> "MyTool" |>,
    SameTest -> MatchQ,
    TestID   -> "parsePacletQualifiedName-SimpleTwoSegment@@Tests/PacletExtension.wlt:142,1-147,2"
]

(* Invalid inputs should produce failures *)
VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`parsePacletQualifiedName[ "NoSlashHere" ],
    _Failure,
    { General::AgentToolsInternal },
    SameTest -> MatchQ,
    TestID   -> "parsePacletQualifiedName-NoSlash@@Tests/PacletExtension.wlt:150,1-156,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`parsePacletQualifiedName[ "A/B/C/D" ],
    _Failure,
    { General::AgentToolsInternal },
    SameTest -> MatchQ,
    TestID   -> "parsePacletQualifiedName-TooManySegments@@Tests/PacletExtension.wlt:158,1-164,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*findAgentToolsPaclets*)
VerificationTest[
    Wolfram`AgentTools`Common`findAgentToolsPaclets[ ],
    { ___PacletObject },
    SameTest -> MatchQ,
    TestID   -> "findAgentToolsPaclets-ReturnsList@@Tests/PacletExtension.wlt:169,1-174,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtension*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtension[ $mockPacletTest ],
    { "AgentTools", _Association },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtension-Valid@@Tests/PacletExtension.wlt:179,1-184,2"
]

VerificationTest[
    Module[ { nonMCPPaclet },
        nonMCPPaclet = First @ PacletFind[ "PacletTools" ];
        Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`getAgentToolsExtension[ nonMCPPaclet ]
    ],
    _Failure,
    { AgentTools::PacletExtensionNotFound },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtension-NoExtension@@Tests/PacletExtension.wlt:186,1-195,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtensionData*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensionData[ $mockPacletTest ],
    _Association? (KeyExistsQ[ #, "Tools" ] &),
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionData-Valid@@Tests/PacletExtension.wlt:200,1-205,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtensionDirectory*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensionDirectory[ $mockPacletTest ],
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionDirectory-Valid@@Tests/PacletExtension.wlt:210,1-215,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractItemName*)
VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`extractItemName[ "MyTool" ],
    "MyTool",
    SameTest -> MatchQ,
    TestID   -> "extractItemName-StringForm@@Tests/PacletExtension.wlt:220,1-225,2"
]

VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`extractItemName[ { "MyTool", "A description" } ],
    "MyTool",
    SameTest -> MatchQ,
    TestID   -> "extractItemName-ListForm@@Tests/PacletExtension.wlt:227,1-232,2"
]

VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`extractItemName[ <| "Name" -> "MyTool", "Description" -> "test" |> ],
    "MyTool",
    SameTest -> MatchQ,
    TestID   -> "extractItemName-AssociationForm@@Tests/PacletExtension.wlt:234,1-239,2"
]

VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`extractItemName[ 123 ],
    $Failed,
    SameTest -> MatchQ,
    TestID   -> "extractItemName-Invalid@@Tests/PacletExtension.wlt:241,1-246,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsDeclaredItems*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletTest, "Tools" ],
    { "TestTool", "DescribedTool", "AssocTool", "LLMToolTest" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-Tools@@Tests/PacletExtension.wlt:251,1-256,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletTest, "MCPServers" ],
    { "TestServer" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-MCPServers@@Tests/PacletExtension.wlt:258,1-263,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletTest, "MCPPrompts" ],
    { "TestPrompt" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-MCPPrompts@@Tests/PacletExtension.wlt:265,1-270,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletTest, "NonExistentType" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-EmptyType@@Tests/PacletExtension.wlt:272,1-277,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*findInstalledPaclet*)
VerificationTest[
    Wolfram`AgentTools`Common`findInstalledPaclet[ "MockMCPPacletTest" ],
    _PacletObject,
    SameTest -> MatchQ,
    TestID   -> "findInstalledPaclet-Found@@Tests/PacletExtension.wlt:282,1-287,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`findInstalledPaclet[ "CompletelyNonExistentPaclet12345" ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "findInstalledPaclet-NotFound@@Tests/PacletExtension.wlt:289,1-294,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadPacletDefinitionFile*)

(* Clear cache before testing *)
VerificationTest[
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ];
    Wolfram`AgentTools`PacletExtension`Private`$pacletDefinitionCache,
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-ClearCache@@Tests/PacletExtension.wlt:301,1-307,2"
]

(* Per-item tool file *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletTest, "Tools", "TestTool" ],
    KeyValuePattern[ { "Name" -> "TestTool", "Description" -> "A test tool" } ],
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-PerItemTool@@Tests/PacletExtension.wlt:310,1-315,2"
]

(* Per-item server file *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletTest, "MCPServers", "TestServer" ],
    _Association? (KeyExistsQ[ #, "LLMEvaluator" ] &),
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-PerItemServer@@Tests/PacletExtension.wlt:318,1-323,2"
]

(* Per-item prompt file *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletTest, "MCPPrompts", "TestPrompt" ],
    KeyValuePattern[ { "Name" -> "TestPrompt" } ],
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-PerItemPrompt@@Tests/PacletExtension.wlt:326,1-331,2"
]

(* Combined file *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletCombined, "Tools", "CombTool1" ],
    KeyValuePattern[ { "Name" -> "CombTool1", "Description" -> "Combined tool 1" } ],
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-CombinedFile@@Tests/PacletExtension.wlt:334,1-339,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletCombined, "Tools", "CombTool2" ],
    KeyValuePattern[ { "Name" -> "CombTool2" } ],
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-CombinedFile2@@Tests/PacletExtension.wlt:341,1-346,2"
]

(* Non-existent item returns $Failed *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletTest, "Tools", "NonExistent" ],
    $Failed,
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-NotFound@@Tests/PacletExtension.wlt:349,1-354,2"
]

(* Caching: verify cache is populated after load *)
VerificationTest[
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ];
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletTest, "Tools", "TestTool" ];
    Length @ Wolfram`AgentTools`PacletExtension`Private`$pacletDefinitionCache > 0,
    True,
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-CachePopulated@@Tests/PacletExtension.wlt:357,1-364,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePacletTool*)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletTool[ "MockMCPPacletTest/TestTool" ],
    KeyValuePattern[ { "Name" -> "TestTool", "Description" -> "A test tool" } ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletTool-Valid@@Tests/PacletExtension.wlt:369,1-374,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletTool[ "MockMCPPacletTest/DescribedTool" ],
    KeyValuePattern[ { "Name" -> "DescribedTool" } ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletTool-DescribedTool@@Tests/PacletExtension.wlt:376,1-381,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletTool[ "NonExistentPaclet12345/SomeTool" ],
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletTool-PacletNotInstalled@@Tests/PacletExtension.wlt:383,1-389,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletTool[ "MockMCPPacletTest/NonExistentTool" ],
    _Failure,
    { AgentTools::PacletToolNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletTool-ToolNotFound@@Tests/PacletExtension.wlt:391,1-397,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePacletServer*)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletServer[ "MockMCPPacletTest/TestServer" ],
    _Association? (KeyExistsQ[ #, "LLMEvaluator" ] &),
    SameTest -> MatchQ,
    TestID   -> "resolvePacletServer-Valid@@Tests/PacletExtension.wlt:402,1-407,2"
]

(* Verify name pre-qualification: short names become fully qualified *)
VerificationTest[
    Module[ { def },
        def = Wolfram`AgentTools`Common`resolvePacletServer[ "MockMCPPacletTest/TestServer" ];
        def[ "LLMEvaluator", "Tools" ]
    ],
    { "MockMCPPacletTest/TestTool", "MockMCPPacletTest/DescribedTool", "MockMCPPacletTest/LLMToolTest" },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletServer-QualifiedToolNames@@Tests/PacletExtension.wlt:410,1-418,2"
]

VerificationTest[
    Module[ { def },
        def = Wolfram`AgentTools`Common`resolvePacletServer[ "MockMCPPacletTest/TestServer" ];
        def[ "LLMEvaluator", "MCPPrompts" ]
    ],
    { "MockMCPPacletTest/TestPrompt" },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletServer-QualifiedPromptNames@@Tests/PacletExtension.wlt:420,1-428,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletServer[ "NonExistentPaclet12345/SomeServer" ],
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletServer-PacletNotInstalled@@Tests/PacletExtension.wlt:430,1-436,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletServer[ "MockMCPPacletTest/NonExistentServer" ],
    _Failure,
    { AgentTools::PacletServerNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletServer-ServerNotFound@@Tests/PacletExtension.wlt:438,1-444,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePacletPrompt*)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletPrompt[ "MockMCPPacletTest/TestPrompt" ],
    KeyValuePattern[ { "Name" -> "TestPrompt", "Description" -> "A test prompt" } ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletPrompt-Valid@@Tests/PacletExtension.wlt:449,1-454,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletPrompt[ "NonExistentPaclet12345/SomePrompt" ],
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletPrompt-PacletNotInstalled@@Tests/PacletExtension.wlt:456,1-462,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletPrompt[ "MockMCPPacletTest/NonExistentPrompt" ],
    _Failure,
    { AgentTools::PacletPromptNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletPrompt-PromptNotFound@@Tests/PacletExtension.wlt:464,1-470,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Multiple Extension Entries*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Setup*)

(* Two applicable entries (default root "AgentTools" and root "DevTools"), plus two entries for other systems *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletSkills" };
    $mockPacletSkills = PacletObject[ "MockMCPPacletSkills" ];
    $mockPacletSkills[ "Name" ],
    "MockMCPPacletSkills",
    SameTest -> MatchQ,
    TestID   -> "MockPacletSetup-Skills@@Tests/PacletExtension.wlt:481,1-488,2"
]

VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadSkills" };
    $mockPacletBadSkills = PacletObject[ "MockMCPPacletBadSkills" ];
    $mockPacletBadSkills[ "Name" ],
    "MockMCPPacletBadSkills",
    SameTest -> MatchQ,
    TestID   -> "MockPacletSetup-BadSkills@@Tests/PacletExtension.wlt:490,1-497,2"
]

VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadBundles" };
    $mockPacletBadBundles = PacletObject[ "MockMCPPacletBadBundles" ];
    $mockPacletBadBundles[ "Name" ],
    "MockMCPPacletBadBundles",
    SameTest -> MatchQ,
    TestID   -> "MockPacletSetup-BadBundles@@Tests/PacletExtension.wlt:499,1-506,2"
]

(* A paclet whose location is a URL, like the remote paclets returned by PacletFindRemote *)
VerificationTest[
    $fakeRemotePaclet = PacletObject @ <|
        "Name"       -> "FakeRemoteAgentToolsPaclet",
        "Version"    -> "1.0.0",
        "Location"   -> "https://example.com/pacletsite",
        "Extensions" -> {
            { "AgentTools", "Name" -> "Everywhere", "MCPServers" -> { "ServerA" }, "Tools" -> { "ToolA" } },
            { "AgentTools", "Name" -> "OtherSystem", "SystemID" -> "MockSystem-A", "MCPServers" -> { "ServerB" } },
            { "AgentTools",
                "Name"       -> "ThisSystem",
                "SystemID"   -> { "MockSystem-B", $SystemID },
                "MCPServers" -> { <| "Name" -> "ServerC", "MCPServerName" -> "CustomKey", "Tools" -> { "ToolC" } |> }
            }
        }
    |>,
    _PacletObject,
    SameTest -> MatchQ,
    TestID   -> "MockPacletSetup-FakeRemote@@Tests/PacletExtension.wlt:509,1-527,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtensions*)
VerificationTest[
    Lookup[ Wolfram`AgentTools`Common`getAgentToolsExtensions @ $mockPacletSkills, "Name" ],
    { "SkillsBundle", "DevBundle" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensions-MultipleEntries@@Tests/PacletExtension.wlt:532,1-537,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensions @ $mockPacletTest,
    { KeyValuePattern[ "MCPServers" -> { "TestServer" } ] },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensions-SingleEntry@@Tests/PacletExtension.wlt:539,1-544,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensions @ First @ PacletFind[ "PacletTools" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensions-NoExtension@@Tests/PacletExtension.wlt:546,1-551,2"
]

(* PacletExtensions fails for paclets without a local directory, so the raw entries are used instead *)
VerificationTest[
    Needs[ "PacletTools`" -> None ];
    Quiet @ PacletTools`PacletExtensions[ $fakeRemotePaclet, "AgentTools" ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensions-PacletExtensionsFailsForRemote@@Tests/PacletExtension.wlt:554,1-560,2"
]

VerificationTest[
    Lookup[ Wolfram`AgentTools`Common`getAgentToolsExtensions @ $fakeRemotePaclet, "Name" ],
    { "Everywhere", "ThisSystem" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensions-RemoteSystemIDFilter@@Tests/PacletExtension.wlt:562,1-567,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtension @ $mockPacletSkills,
    { "AgentTools", KeyValuePattern[ "Name" -> "SkillsBundle" ] },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtension-FirstEntry@@Tests/PacletExtension.wlt:569,1-574,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtensionDirectories*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensionDirectories @ $mockPacletSkills,
    { _String? DirectoryQ, _String? DirectoryQ },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionDirectories-MultipleRoots@@Tests/PacletExtension.wlt:579,1-584,2"
]

VerificationTest[
    FileNameTake /@ Wolfram`AgentTools`Common`getAgentToolsExtensionDirectories @ $mockPacletSkills,
    { "AgentTools", "DevTools" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionDirectories-EntryOrder@@Tests/PacletExtension.wlt:586,1-591,2"
]

(* Six entries use the default root, one names a root that doesn't exist *)
VerificationTest[
    FileNameTake /@ Wolfram`AgentTools`Common`getAgentToolsExtensionDirectories @ $mockPacletBadBundles,
    { "AgentTools" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionDirectories-NoDuplicatesNoMissing@@Tests/PacletExtension.wlt:594,1-599,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensionDirectories @ $fakeRemotePaclet,
    { },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionDirectories-Remote@@Tests/PacletExtension.wlt:601,1-606,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensionDirectories @ $mockPacletTest,
    { _String? DirectoryQ },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionDirectories-SingleEntry@@Tests/PacletExtension.wlt:608,1-613,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsDeclaredItems*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletSkills, "MCPServers" ],
    { "SkillsServer", "DevServer" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-Union-MCPServers@@Tests/PacletExtension.wlt:618,1-623,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletSkills, "Tools" ],
    { "SkillsTool", "DevTool" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-Union-Tools@@Tests/PacletExtension.wlt:625,1-630,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletSkills, "AgentSkills" ],
    {
        "directory-skill",
        "assoc-skill",
        "llmskill-skill",
        "combined-skill",
        "located-skill",
        "foreign-skill",
        "dev-skill"
    },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-AgentSkills@@Tests/PacletExtension.wlt:632,1-645,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletTest, "AgentSkills" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-NoAgentSkills@@Tests/PacletExtension.wlt:647,1-652,2"
]

(* Names that contain "/" are skipped *)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletBadBundles, "Tools" ],
    { "GoodTool" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-InvalidNamesSkipped@@Tests/PacletExtension.wlt:655,1-660,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $fakeRemotePaclet, "MCPServers" ],
    { "ServerA", "ServerC" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-Remote@@Tests/PacletExtension.wlt:662,1-667,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsItemDeclaration*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsItemDeclaration[ $mockPacletSkills, "AgentSkills", "assoc-skill" ],
    { "assoc-skill", "A skill defined by an association" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsItemDeclaration-ListForm@@Tests/PacletExtension.wlt:672,1-677,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsItemDeclaration[ $fakeRemotePaclet, "MCPServers", "ServerC" ],
    KeyValuePattern[ { "Name" -> "ServerC", "MCPServerName" -> "CustomKey" } ],
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsItemDeclaration-LaterEntry@@Tests/PacletExtension.wlt:679,1-684,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsItemDeclaration[ $mockPacletSkills, "MCPServers", "NonExistentServer" ],
    Missing[ "NotFound" ],
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsItemDeclaration-NotFound@@Tests/PacletExtension.wlt:686,1-691,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*buildRemotePacletServerMetadata*)

(* The declaration of a remote server is found in any entry *)
VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`buildRemotePacletServerMetadata[
        "FakeRemoteAgentToolsPaclet/ServerC",
        $fakeRemotePaclet,
        "ServerC"
    ],
    KeyValuePattern @ {
        "MCPServerName" -> "CustomKey",
        "LLMEvaluator"  -> KeyValuePattern[ "Tools" -> { "FakeRemoteAgentToolsPaclet/ToolC" } ]
    },
    SameTest -> MatchQ,
    TestID   -> "buildRemotePacletServerMetadata-LaterEntry@@Tests/PacletExtension.wlt:698,1-710,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`buildRemotePacletServerMetadata[
        "FakeRemoteAgentToolsPaclet/ServerA",
        $fakeRemotePaclet,
        "ServerA"
    ],
    KeyValuePattern @ {
        "MCPServerName" -> "ServerA",
        "LLMEvaluator"  -> KeyValuePattern[ "Tools" -> { "FakeRemoteAgentToolsPaclet/ToolA" } ]
    },
    SameTest -> MatchQ,
    TestID   -> "buildRemotePacletServerMetadata-NameOnly@@Tests/PacletExtension.wlt:712,1-724,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*findInstalledPaclet*)
VerificationTest[
    Wolfram`AgentTools`Common`findInstalledPaclet[ "MockMCPPacletSkills" ],
    _PacletObject? (#[ "Name" ] === "MockMCPPacletSkills" &),
    SameTest -> MatchQ,
    TestID   -> "findInstalledPaclet-ExactName@@Tests/PacletExtension.wlt:729,1-734,2"
]

(* PacletFind treats "*" as a wildcard, but paclet names must match exactly *)
VerificationTest[
    Wolfram`AgentTools`Common`findInstalledPaclet[ "MockMCPPacletSkill*" ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "findInstalledPaclet-NoWildcards@@Tests/PacletExtension.wlt:737,1-742,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Multi-Root Definition Lookup*)
VerificationTest[
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-ClearCache@@Tests/PacletExtension.wlt:747,1-752,2"
]

(* Defined in the second root *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "MCPServers", "DevServer" ],
    KeyValuePattern[ { "Name" -> "DevServer", "MCPServerName" -> "MockSkillsDev" } ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-SecondRootServer@@Tests/PacletExtension.wlt:755,1-760,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "Tools", "DevTool" ],
    KeyValuePattern[ { "Name" -> "DevTool", "Description" -> "A tool in the second root" } ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-SecondRootTool@@Tests/PacletExtension.wlt:762,1-767,2"
]

(* Defined in the first root *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "Tools", "SkillsTool" ],
    KeyValuePattern[ { "Name" -> "SkillsTool", "Description" -> "A tool in the first root" } ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-FirstRootTool@@Tests/PacletExtension.wlt:770,1-775,2"
]

(* Defined in both roots: the first root wins *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletBadSkills, "AgentSkills", "two-roots-skill" ],
    KeyValuePattern[ "Body" -> "# First Root" ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-FirstRootWins@@Tests/PacletExtension.wlt:778,1-783,2"
]

(* Skill directories load as the LLMSkill parsed from SKILL.md *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "AgentSkills", "directory-skill" ],
    HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "directory-skill" ] ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-SkillDirectory@@Tests/PacletExtension.wlt:786,1-791,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "AgentSkills", "combined-skill" ],
    KeyValuePattern[ "Name" -> "combined-skill" ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-CombinedSkill@@Tests/PacletExtension.wlt:793,1-798,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "AgentSkills", "llmskill-skill" ];
    Wolfram`AgentTools`PacletExtension`Private`$pacletDefinitionCache[
        { "MockMCPPacletSkills", "1.0.0", "AgentSkills", "llmskill-skill" }
    ],
    HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "llmskill-skill" ] ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-LLMSkillCached@@Tests/PacletExtension.wlt:800,1-808,2"
]

VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`cacheableResultQ @ LLMSkill[ { "some-skill", "A skill" }, "Body" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "cacheableResultQ-LLMSkill@@Tests/PacletExtension.wlt:810,1-815,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "AgentSkills", "no-such-skill" ],
    $Failed,
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-NotFound@@Tests/PacletExtension.wlt:817,1-822,2"
]

(* Servers combine tools from both roots *)
VerificationTest[
    withTemporaryRoot @ MCPServerObject[ "MockMCPPacletSkills/DevServer" ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-MCPServerObject@@Tests/PacletExtension.wlt:825,1-830,2"
]

VerificationTest[
    withTemporaryRoot @ With[ { obj = MCPServerObject[ "MockMCPPacletSkills/DevServer" ] },
        { obj[ "MCPServerName" ], #[ "Name" ] & /@ obj[ "Tools" ] }
    ],
    { "MockSkillsDev", { "SkillsTool", "DevTool" } },
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-MCPServerObject-Tools@@Tests/PacletExtension.wlt:832,1-839,2"
]

VerificationTest[
    withTemporaryRoot[ #[ "Name" ] & /@ MCPServerObjects[ "MockMCPPacletSkills/*" ] ],
    { "MockMCPPacletSkills/SkillsServer", "MockMCPPacletSkills/DevServer" },
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-MCPServerObjects@@Tests/PacletExtension.wlt:841,1-846,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Bundles*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsBundles*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsBundles @ $mockPacletSkills,
    {
        KeyValuePattern @ {
            "Name"        -> "MockMCPPacletSkills/SkillsBundle",
            "Location"    -> _PacletObject,
            "MCPServers"  -> { "MockMCPPacletSkills/SkillsServer" },
            "AgentSkills" -> {
                "MockMCPPacletSkills/directory-skill",
                "MockMCPPacletSkills/assoc-skill",
                "MockMCPPacletSkills/llmskill-skill",
                "MockMCPPacletSkills/combined-skill",
                "MockMCPPacletSkills/located-skill",
                "MockMCPPacletSkills/foreign-skill"
            },
            "Description" -> "Servers and skills for testing"
        },
        KeyValuePattern @ {
            "Name"        -> "MockMCPPacletSkills/DevBundle",
            "Location"    -> _PacletObject,
            "MCPServers"  -> { "MockMCPPacletSkills/SkillsServer", "MockMCPPacletSkills/DevServer" },
            "AgentSkills" -> { "MockMCPPacletSkills/directory-skill", "MockMCPPacletSkills/dev-skill" }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsBundles-MultipleEntries@@Tests/PacletExtension.wlt:855,1-881,2"
]

VerificationTest[
    KeyExistsQ[ Last @ Wolfram`AgentTools`Common`getAgentToolsBundles @ $mockPacletSkills, "Description" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsBundles-NoDescription@@Tests/PacletExtension.wlt:883,1-888,2"
]

(* An entry without "Name" defines the bundle "AgentTools" *)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsBundles @ $mockPacletTest,
    {
        KeyValuePattern @ {
            "Name"        -> "MockMCPPacletTest/AgentTools",
            "MCPServers"  -> { "MockMCPPacletTest/TestServer" },
            "AgentSkills" -> { }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsBundles-DefaultName@@Tests/PacletExtension.wlt:891,1-902,2"
]

(* Entries that only declare tools and prompts define no bundle *)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsBundles @ $mockPacletCombined,
    { },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsBundles-ToolsOnly@@Tests/PacletExtension.wlt:905,1-910,2"
]

(* Invalid names are skipped and the first of several entries with the same name wins *)
VerificationTest[
    Lookup[ Wolfram`AgentTools`Common`getAgentToolsBundles @ $mockPacletBadBundles, { "Name", "MCPServers" } ],
    {
        { "MockMCPPacletBadBundles/Main", { "MockMCPPacletBadBundles/ServerA", "MockMCPPacletBadBundles/ServerB" } },
        { "MockMCPPacletBadBundles/ServerA", { "MockMCPPacletBadBundles/ServerB" } },
        { "MockMCPPacletBadBundles/AgentTools", { "MockMCPPacletBadBundles/ServerA" } }
    },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsBundles-InvalidAndDuplicateNames@@Tests/PacletExtension.wlt:913,1-922,2"
]

VerificationTest[
    Lookup[ Wolfram`AgentTools`Common`getAgentToolsBundles @ $fakeRemotePaclet, "Name" ],
    { "FakeRemoteAgentToolsPaclet/Everywhere", "FakeRemoteAgentToolsPaclet/ThisSystem" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsBundles-Remote@@Tests/PacletExtension.wlt:924,1-929,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePacletBundle*)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletBundle[ "MockMCPPacletSkills/DevBundle" ],
    KeyValuePattern @ {
        "Name"       -> "MockMCPPacletSkills/DevBundle",
        "Location"   -> _PacletObject? (#[ "Name" ] === "MockMCPPacletSkills" &),
        "MCPServers" -> { "MockMCPPacletSkills/SkillsServer", "MockMCPPacletSkills/DevServer" }
    },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletBundle-Installed@@Tests/PacletExtension.wlt:934,1-943,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletBundle[ "MockMCPPacletSkills/NoSuchBundle" ],
    Missing[ "NotFound" ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletBundle-MissingBundle@@Tests/PacletExtension.wlt:945,1-950,2"
]

(* A server name is not a bundle name *)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletBundle[ "MockMCPPacletSkills/DevServer" ],
    Missing[ "NotFound" ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletBundle-ServerName@@Tests/PacletExtension.wlt:953,1-958,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletBundle[ "NotAQualifiedName" ],
    Missing[ "NotFound" ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletBundle-NotQualified@@Tests/PacletExtension.wlt:960,1-965,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletBundle[ "NonExistentPaclet12345/SomeBundle" ],
    Missing[ "NotFound" ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletBundle-UnknownPaclet@@Tests/PacletExtension.wlt:967,1-972,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skills*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePacletSkill*)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/directory-skill" ],
    KeyValuePattern @ {
        "Type"          -> "PacletSkill",
        "Name"          -> "directory-skill",
        "QualifiedName" -> "MockMCPPacletSkills/directory-skill",
        "PacletName"    -> "MockMCPPacletSkills",
        "PacletVersion" -> "1.0.0",
        "Directory"     -> File[ _String? (FileExistsQ @ FileNameJoin @ { #, "scripts", "run.wls" } &) ]
    },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-Directory@@Tests/PacletExtension.wlt:981,1-993,2"
]

VerificationTest[
    Keys @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/directory-skill" ],
    { "Type", "Name", "QualifiedName", "PacletName", "PacletVersion", "Directory" },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-Directory-Keys@@Tests/PacletExtension.wlt:995,1-1000,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/assoc-skill" ],
    KeyValuePattern @ {
        "Type"       -> "PacletSkill",
        "Name"       -> "assoc-skill",
        "Definition" -> KeyValuePattern @ {
            "Name"        -> "assoc-skill",
            "Description" -> "A skill defined by an association.",
            "License"     -> "MIT"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-Association@@Tests/PacletExtension.wlt:1002,1-1015,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/llmskill-skill" ],
    KeyValuePattern[ "Definition" -> HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "llmskill-skill" ] ] ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-LLMSkill@@Tests/PacletExtension.wlt:1017,1-1022,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/combined-skill" ],
    KeyValuePattern[ "Definition" -> KeyValuePattern[ "Name" -> "combined-skill" ] ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-CombinedFile@@Tests/PacletExtension.wlt:1024,1-1029,2"
]

(* An LLMSkill whose relative "Location" is a skill directory inside an extension root uses that directory *)
VerificationTest[
    Lookup[ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/located-skill" ], "Directory" ],
    File[ _String? (Take[ FileNameSplit @ #, -2 ] === { "SkillSources", "located-skill" } &) ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-HonoredLocation@@Tests/PacletExtension.wlt:1032,1-1037,2"
]

(* A "Location" outside of the extension roots is ignored, even if it names an existing skill directory *)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/foreign-skill" ],
    KeyValuePattern[ "Definition" -> _Association? (! KeyExistsQ[ #, "Location" ] && #[ "Name" ] === "foreign-skill" &) ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-IgnoredLocation@@Tests/PacletExtension.wlt:1040,1-1045,2"
]

VerificationTest[
    KeyExistsQ[ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/foreign-skill" ], "Directory" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-IgnoredLocation-NoDirectory@@Tests/PacletExtension.wlt:1047,1-1052,2"
]

(* A skill directory in the second root *)
VerificationTest[
    Lookup[ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/dev-skill" ], "Directory" ],
    File[ _String? (Take[ FileNameSplit @ #, -3 ] === { "DevTools", "AgentSkills", "dev-skill" } &) ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-SecondRoot@@Tests/PacletExtension.wlt:1055,1-1060,2"
]

(* The skill directory is checked before definition files *)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletBadSkills/dup-skill" ],
    KeyValuePattern[ "Directory" -> File[ _String ] ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-DirectoryFirst@@Tests/PacletExtension.wlt:1063,1-1068,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletBadSkills/two-roots-skill" ],
    KeyValuePattern[ "Definition" -> KeyValuePattern[ "Body" -> "# First Root" ] ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-FirstRootWins@@Tests/PacletExtension.wlt:1070,1-1075,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ $mockPacletSkills, "dev-skill" ],
    KeyValuePattern[ { "QualifiedName" -> "MockMCPPacletSkills/dev-skill", "Directory" -> File[ _String ] } ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-PacletForm@@Tests/PacletExtension.wlt:1077,1-1082,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePacletSkill Failures*)
VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/no-such-skill" ],
    _Failure,
    { AgentTools::PacletSkillNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-NotDeclared@@Tests/PacletExtension.wlt:1087,1-1093,2"
]

(* Declared skills of other types are not skills *)
VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/SkillsServer" ],
    _Failure,
    { AgentTools::PacletSkillNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-ServerName@@Tests/PacletExtension.wlt:1096,1-1102,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletBadSkills/missing-skill" ],
    _Failure,
    { AgentTools::PacletSkillNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-NoDefinition@@Tests/PacletExtension.wlt:1104,1-1110,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "NonExistentPaclet12345/some-skill" ],
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-PacletNotInstalled@@Tests/PacletExtension.wlt:1112,1-1118,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "not-qualified" ],
    _Failure,
    { AgentTools::AgentSkillNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-NotQualified@@Tests/PacletExtension.wlt:1120,1-1126,2"
]

(* SKILL.md declares a different name *)
VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletBadSkills/mismatch-skill" ],
    _Failure,
    { AgentTools::InvalidPacletSkillDefinition },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-NameMismatch@@Tests/PacletExtension.wlt:1129,1-1135,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletBadSkills/not-a-skill" ],
    _Failure,
    { AgentTools::InvalidPacletSkillDefinition },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-InvalidContents@@Tests/PacletExtension.wlt:1137,1-1143,2"
]

(* The honored "Location" names a skill directory with a different name *)
VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletBadSkills/bad-location-skill" ],
    _Failure,
    { AgentTools::InvalidPacletSkillDefinition },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-LocationNameMismatch@@Tests/PacletExtension.wlt:1146,1-1152,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Location Helpers*)
VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`pathInsideDirectoryQ @@@ {
        { "/a/b/c", "/a/b" },
        { "/a/b/c/d", "/a/b" },
        { "/a/b", "/a/b" },
        { "/a/bc", "/a/b" },
        { "/a", "/a/b" }
    },
    { True, True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "pathInsideDirectoryQ@@Tests/PacletExtension.wlt:1157,1-1168,2"
]

VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`absolutePathQ /@ { "/a/b", "C:\\a", "~/a", "a/b", "../a" },
    { True, True, True, False, False },
    SameTest -> MatchQ,
    TestID   -> "absolutePathQ@@Tests/PacletExtension.wlt:1170,1-1175,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Remote Paclet Fallback*)

(* Use the real remote paclet from the Paclet Repository *)
VerificationTest[
    $remotePaclet = First @ Replace[
        PacletFindRemote[ "SamplePublisher/SamplePaclet", <| "Extension" -> "AgentTools" |> ],
        { } :> PacletFindRemote[
            "SamplePublisher/SamplePaclet",
            <| "Extension" -> "AgentTools" |>,
            UpdatePacletSites -> True
        ]
    ];
    PacletObjectQ @ $remotePaclet,
    True,
    SameTest -> MatchQ,
    TestID -> "RemotePacletFallback-Setup@@Tests/PacletExtension.wlt:1182,1-1195,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $remotePaclet, "MCPServers" ],
    { "SampleServer" },
    SameTest -> MatchQ,
    TestID -> "RemotePacletFallback-MCPServers@@Tests/PacletExtension.wlt:1197,1-1202,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $remotePaclet, "Tools" ],
    { "Identity", "PrimeFinder" },
    SameTest -> MatchQ,
    TestID -> "RemotePacletFallback-Tools@@Tests/PacletExtension.wlt:1204,1-1209,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $remotePaclet, "MCPPrompts" ],
    { },
    SameTest -> MatchQ,
    TestID -> "RemotePacletFallback-EmptyPrompts@@Tests/PacletExtension.wlt:1211,1-1216,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensionDirectories @ $remotePaclet,
    { },
    SameTest -> MatchQ,
    TestID   -> "RemotePacletFallback-NoDirectories@@Tests/PacletExtension.wlt:1218,1-1223,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsBundles @ $remotePaclet,
    {
        KeyValuePattern @ {
            "Name"        -> "SamplePublisher/SamplePaclet/AgentTools",
            "Location"    -> _PacletObject,
            "MCPServers"  -> { "SamplePublisher/SamplePaclet/SampleServer" },
            "AgentSkills" -> { }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "RemotePacletFallback-Bundles@@Tests/PacletExtension.wlt:1225,1-1237,2"
]

(* Installed if available, otherwise remote metadata (never installs) *)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletBundle[ "SamplePublisher/SamplePaclet/AgentTools" ],
    KeyValuePattern @ {
        "Name"       -> "SamplePublisher/SamplePaclet/AgentTools",
        "Location"   -> _PacletObject,
        "MCPServers" -> { "SamplePublisher/SamplePaclet/SampleServer" }
    },
    SameTest -> MatchQ,
    TestID   -> "RemotePacletFallback-resolvePacletBundle@@Tests/PacletExtension.wlt:1240,1-1249,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Remote Server Resolution*)

VerificationTest[
    $remoteServer = MCPServerObject[ "SamplePublisher/SamplePaclet/SampleServer" ];
    Head @ $remoteServer,
    MCPServerObject,
    SameTest -> MatchQ,
    TestID -> "RemoteServerResolution-NoFailure@@Tests/PacletExtension.wlt:1255,1-1261,2"
]

VerificationTest[
    $remoteServer[ "ToolNames" ],
    { "SamplePublisher/SamplePaclet/Identity", "SamplePublisher/SamplePaclet/PrimeFinder" },
    SameTest -> MatchQ,
    TestID -> "RemoteServerResolution-ToolNames@@Tests/PacletExtension.wlt:1263,1-1268,2"
]

(* If paclet is installed, we get a list of LLMTools, otherwise we should get a Failure *)
VerificationTest[
    Quiet[ $remoteServer[ "Tools" ], MCPServerObject::PacletNotInstalled ],
    If[ Quiet @ PacletObjectQ @ PacletObject[ "SamplePublisher/SamplePaclet" ],
        { __LLMTool },
        Failure[ "MCPServerObject::PacletNotInstalled", _ ]
    ],
    SameTest -> MatchQ,
    TestID -> "RemoteServerResolution-Tools@@Tests/PacletExtension.wlt:1271,1-1279,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Mock Paclet Cleanup*)
VerificationTest[
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletCombined" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletSkills" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadSkills" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadBundles" };
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "MockPacletCleanup@@Tests/PacletExtension.wlt:1284,1-1294,2"
]

(* :!CodeAnalysis::EndBlock:: *)
