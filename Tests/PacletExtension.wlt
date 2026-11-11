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
    TestID   -> "TestResourcesDirectory"
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
    TestID   -> "MockPacletSetup-PerItem"
]

(* Load mock paclet with combined definition files *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletCombined" };
    $mockPacletCombined = PacletObject[ "MockMCPPacletCombined" ];
    $mockPacletCombined[ "Name" ],
    "MockMCPPacletCombined",
    SameTest -> MatchQ,
    TestID   -> "MockPacletSetup-Combined"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Resolve MCPServerObject*)
VerificationTest[
    obj = MCPServerObject[ "MockMCPPacletTest/TestServer" ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "ResolveMCPServerObject-Valid"
]

VerificationTest[
    tools = obj[ "Tools" ],
    { __LLMTool },
    SameTest -> MatchQ,
    TestID   -> "ResolveMCPServerObject-Tools"
]

VerificationTest[
    #[ "Name" ] & /@ tools,
    { "TestTool", "DescribedTool", "LLMToolTest" },
    SameTest -> MatchQ,
    TestID   -> "ResolveMCPServerObject-Tools-Names"
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
    TestID -> "pacletQualifiedNameQ-ThreeSegment"
]

VerificationTest[
    Wolfram`AgentTools`Common`pacletQualifiedNameQ[ "JIRALink/GetIssue" ],
    True,
    TestID -> "pacletQualifiedNameQ-TwoSegment"
]

VerificationTest[
    Wolfram`AgentTools`Common`pacletQualifiedNameQ[ "WolframAlpha" ],
    False,
    TestID -> "pacletQualifiedNameQ-NoSlash"
]

VerificationTest[
    Wolfram`AgentTools`Common`pacletQualifiedNameQ[ "" ],
    False,
    TestID -> "pacletQualifiedNameQ-EmptyString"
]

VerificationTest[
    Wolfram`AgentTools`Common`pacletQualifiedNameQ[ 123 ],
    False,
    TestID -> "pacletQualifiedNameQ-NonString"
]

VerificationTest[
    Wolfram`AgentTools`Common`pacletQualifiedNameQ[ ],
    False,
    TestID -> "pacletQualifiedNameQ-NoArgs"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parsePacletQualifiedName*)
VerificationTest[
    Wolfram`AgentTools`Common`parsePacletQualifiedName[ "JIRALink/GetIssue" ],
    <| "PacletName" -> "JIRALink", "ItemName" -> "GetIssue" |>,
    SameTest -> MatchQ,
    TestID   -> "parsePacletQualifiedName-TwoSegment"
]

VerificationTest[
    Wolfram`AgentTools`Common`parsePacletQualifiedName[ "Wolfram/JIRALink/GetIssue" ],
    <| "PacletName" -> "Wolfram/JIRALink", "ItemName" -> "GetIssue" |>,
    SameTest -> MatchQ,
    TestID   -> "parsePacletQualifiedName-ThreeSegment"
]

VerificationTest[
    Wolfram`AgentTools`Common`parsePacletQualifiedName[ "Wolfram/JIRALink/ProjectManagement" ],
    <| "PacletName" -> "Wolfram/JIRALink", "ItemName" -> "ProjectManagement" |>,
    SameTest -> MatchQ,
    TestID   -> "parsePacletQualifiedName-ThreeSegmentServer"
]

VerificationTest[
    Wolfram`AgentTools`Common`parsePacletQualifiedName[ "MyPaclet/MyTool" ],
    <| "PacletName" -> "MyPaclet", "ItemName" -> "MyTool" |>,
    SameTest -> MatchQ,
    TestID   -> "parsePacletQualifiedName-SimpleTwoSegment"
]

(* Invalid inputs should produce failures *)
VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`parsePacletQualifiedName[ "NoSlashHere" ],
    _Failure,
    { General::AgentToolsInternal },
    SameTest -> MatchQ,
    TestID   -> "parsePacletQualifiedName-NoSlash"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`parsePacletQualifiedName[ "A/B/C/D" ],
    _Failure,
    { General::AgentToolsInternal },
    SameTest -> MatchQ,
    TestID   -> "parsePacletQualifiedName-TooManySegments"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*findAgentToolsPaclets*)
VerificationTest[
    Wolfram`AgentTools`Common`findAgentToolsPaclets[ ],
    { ___PacletObject },
    SameTest -> MatchQ,
    TestID   -> "findAgentToolsPaclets-ReturnsList"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtension*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtension[ $mockPacletTest ],
    { "AgentTools", _Association },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtension-Valid"
]

VerificationTest[
    Module[ { nonMCPPaclet },
        nonMCPPaclet = First @ PacletFind[ "PacletTools" ];
        Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`getAgentToolsExtension[ nonMCPPaclet ]
    ],
    _Failure,
    { AgentTools::PacletExtensionNotFound },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtension-NoExtension"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtensionData*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensionData[ $mockPacletTest ],
    _Association? (KeyExistsQ[ #, "Tools" ] &),
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionData-Valid"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtensionDirectory*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensionDirectory[ $mockPacletTest ],
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionDirectory-Valid"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractItemName*)
VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`extractItemName[ "MyTool" ],
    "MyTool",
    SameTest -> MatchQ,
    TestID   -> "extractItemName-StringForm"
]

VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`extractItemName[ { "MyTool", "A description" } ],
    "MyTool",
    SameTest -> MatchQ,
    TestID   -> "extractItemName-ListForm"
]

VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`extractItemName[ <| "Name" -> "MyTool", "Description" -> "test" |> ],
    "MyTool",
    SameTest -> MatchQ,
    TestID   -> "extractItemName-AssociationForm"
]

VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`extractItemName[ 123 ],
    $Failed,
    SameTest -> MatchQ,
    TestID   -> "extractItemName-Invalid"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsDeclaredItems*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletTest, "Tools" ],
    { "TestTool", "DescribedTool", "AssocTool", "LLMToolTest" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-Tools"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletTest, "MCPServers" ],
    { "TestServer" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-MCPServers"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletTest, "MCPPrompts" ],
    { "TestPrompt" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-MCPPrompts"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletTest, "NonExistentType" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-EmptyType"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*findInstalledPaclet*)
VerificationTest[
    Wolfram`AgentTools`Common`findInstalledPaclet[ "MockMCPPacletTest" ],
    _PacletObject,
    SameTest -> MatchQ,
    TestID   -> "findInstalledPaclet-Found"
]

VerificationTest[
    Wolfram`AgentTools`Common`findInstalledPaclet[ "CompletelyNonExistentPaclet12345" ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "findInstalledPaclet-NotFound"
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
    TestID   -> "loadPacletDefinitionFile-ClearCache"
]

(* Per-item tool file *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletTest, "Tools", "TestTool" ],
    KeyValuePattern[ { "Name" -> "TestTool", "Description" -> "A test tool" } ],
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-PerItemTool"
]

(* Per-item server file *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletTest, "MCPServers", "TestServer" ],
    _Association? (KeyExistsQ[ #, "LLMEvaluator" ] &),
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-PerItemServer"
]

(* Per-item prompt file *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletTest, "MCPPrompts", "TestPrompt" ],
    KeyValuePattern[ { "Name" -> "TestPrompt" } ],
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-PerItemPrompt"
]

(* Combined file *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletCombined, "Tools", "CombTool1" ],
    KeyValuePattern[ { "Name" -> "CombTool1", "Description" -> "Combined tool 1" } ],
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-CombinedFile"
]

VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletCombined, "Tools", "CombTool2" ],
    KeyValuePattern[ { "Name" -> "CombTool2" } ],
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-CombinedFile2"
]

(* Non-existent item returns $Failed *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletTest, "Tools", "NonExistent" ],
    $Failed,
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-NotFound"
]

(* Caching: verify cache is populated after load *)
VerificationTest[
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ];
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletTest, "Tools", "TestTool" ];
    Length @ Wolfram`AgentTools`PacletExtension`Private`$pacletDefinitionCache > 0,
    True,
    SameTest -> MatchQ,
    TestID   -> "loadPacletDefinitionFile-CachePopulated"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePacletTool*)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletTool[ "MockMCPPacletTest/TestTool" ],
    KeyValuePattern[ { "Name" -> "TestTool", "Description" -> "A test tool" } ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletTool-Valid"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletTool[ "MockMCPPacletTest/DescribedTool" ],
    KeyValuePattern[ { "Name" -> "DescribedTool" } ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletTool-DescribedTool"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletTool[ "NonExistentPaclet12345/SomeTool" ],
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletTool-PacletNotInstalled"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletTool[ "MockMCPPacletTest/NonExistentTool" ],
    _Failure,
    { AgentTools::PacletToolNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletTool-ToolNotFound"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePacletServer*)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletServer[ "MockMCPPacletTest/TestServer" ],
    _Association? (KeyExistsQ[ #, "LLMEvaluator" ] &),
    SameTest -> MatchQ,
    TestID   -> "resolvePacletServer-Valid"
]

(* Verify name pre-qualification: short names become fully qualified *)
VerificationTest[
    Module[ { def },
        def = Wolfram`AgentTools`Common`resolvePacletServer[ "MockMCPPacletTest/TestServer" ];
        def[ "LLMEvaluator", "Tools" ]
    ],
    { "MockMCPPacletTest/TestTool", "MockMCPPacletTest/DescribedTool", "MockMCPPacletTest/LLMToolTest" },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletServer-QualifiedToolNames"
]

VerificationTest[
    Module[ { def },
        def = Wolfram`AgentTools`Common`resolvePacletServer[ "MockMCPPacletTest/TestServer" ];
        def[ "LLMEvaluator", "MCPPrompts" ]
    ],
    { "MockMCPPacletTest/TestPrompt" },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletServer-QualifiedPromptNames"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletServer[ "NonExistentPaclet12345/SomeServer" ],
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletServer-PacletNotInstalled"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletServer[ "MockMCPPacletTest/NonExistentServer" ],
    _Failure,
    { AgentTools::PacletServerNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletServer-ServerNotFound"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePacletPrompt*)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletPrompt[ "MockMCPPacletTest/TestPrompt" ],
    KeyValuePattern[ { "Name" -> "TestPrompt", "Description" -> "A test prompt" } ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletPrompt-Valid"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletPrompt[ "NonExistentPaclet12345/SomePrompt" ],
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletPrompt-PacletNotInstalled"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletPrompt[ "MockMCPPacletTest/NonExistentPrompt" ],
    _Failure,
    { AgentTools::PacletPromptNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletPrompt-PromptNotFound"
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
    TestID   -> "MockPacletSetup-Skills"
]

VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadSkills" };
    $mockPacletBadSkills = PacletObject[ "MockMCPPacletBadSkills" ];
    $mockPacletBadSkills[ "Name" ],
    "MockMCPPacletBadSkills",
    SameTest -> MatchQ,
    TestID   -> "MockPacletSetup-BadSkills"
]

VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadBundles" };
    $mockPacletBadBundles = PacletObject[ "MockMCPPacletBadBundles" ];
    $mockPacletBadBundles[ "Name" ],
    "MockMCPPacletBadBundles",
    SameTest -> MatchQ,
    TestID   -> "MockPacletSetup-BadBundles"
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
    TestID   -> "MockPacletSetup-FakeRemote"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtensions*)
VerificationTest[
    Lookup[ Wolfram`AgentTools`Common`getAgentToolsExtensions @ $mockPacletSkills, "Name" ],
    { "SkillsBundle", "DevBundle" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensions-MultipleEntries"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensions @ $mockPacletTest,
    { KeyValuePattern[ "MCPServers" -> { "TestServer" } ] },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensions-SingleEntry"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensions @ First @ PacletFind[ "PacletTools" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensions-NoExtension"
]

(* PacletExtensions fails for paclets without a local directory, so the raw entries are used instead *)
VerificationTest[
    Needs[ "PacletTools`" -> None ];
    Quiet @ PacletTools`PacletExtensions[ $fakeRemotePaclet, "AgentTools" ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensions-PacletExtensionsFailsForRemote"
]

VerificationTest[
    Lookup[ Wolfram`AgentTools`Common`getAgentToolsExtensions @ $fakeRemotePaclet, "Name" ],
    { "Everywhere", "ThisSystem" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensions-RemoteSystemIDFilter"
]

(* The fallback applies "SystemID" like PacletTools`PacletExtensions, where "All" is an ordinary system ID *)
VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`systemIDApplicableQ /@ {
        <| |>,
        <| "SystemID" -> All |>,
        <| "SystemID" -> $SystemID |>,
        <| "SystemID" -> { "MockSystem-A", $SystemID } |>,
        <| "SystemID" -> "All" |>,
        <| "SystemID" -> "MockSystem-A" |>,
        <| "SystemID" -> { } |>,
        <| "SystemID" -> Automatic |>
    },
    { True, True, True, True, False, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensions-FallbackSystemIDSemantics"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtension @ $mockPacletSkills,
    { "AgentTools", KeyValuePattern[ "Name" -> "SkillsBundle" ] },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtension-FirstEntry"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtensionDirectories*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensionDirectories @ $mockPacletSkills,
    { _String? DirectoryQ, _String? DirectoryQ },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionDirectories-MultipleRoots"
]

VerificationTest[
    FileNameTake /@ Wolfram`AgentTools`Common`getAgentToolsExtensionDirectories @ $mockPacletSkills,
    { "AgentTools", "DevTools" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionDirectories-EntryOrder"
]

(* Six entries use the default root, one names a root that doesn't exist *)
VerificationTest[
    FileNameTake /@ Wolfram`AgentTools`Common`getAgentToolsExtensionDirectories @ $mockPacletBadBundles,
    { "AgentTools" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionDirectories-NoDuplicatesNoMissing"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensionDirectories @ $fakeRemotePaclet,
    { },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionDirectories-Remote"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensionDirectories @ $mockPacletTest,
    { _String? DirectoryQ },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsExtensionDirectories-SingleEntry"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsDeclaredItems*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletSkills, "MCPServers" ],
    { "SkillsServer", "DevServer" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-Union-MCPServers"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletSkills, "Tools" ],
    { "SkillsTool", "DevTool" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-Union-Tools"
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
    TestID   -> "getAgentToolsDeclaredItems-AgentSkills"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletTest, "AgentSkills" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-NoAgentSkills"
]

(* Names that contain "/" are skipped *)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $mockPacletBadBundles, "Tools" ],
    { "GoodTool" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-InvalidNamesSkipped"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $fakeRemotePaclet, "MCPServers" ],
    { "ServerA", "ServerC" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsDeclaredItems-Remote"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsItemDeclaration*)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsItemDeclaration[ $mockPacletSkills, "AgentSkills", "assoc-skill" ],
    { "assoc-skill", "A skill defined by an association" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsItemDeclaration-ListForm"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsItemDeclaration[ $fakeRemotePaclet, "MCPServers", "ServerC" ],
    KeyValuePattern[ { "Name" -> "ServerC", "MCPServerName" -> "CustomKey" } ],
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsItemDeclaration-LaterEntry"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsItemDeclaration[ $mockPacletSkills, "MCPServers", "NonExistentServer" ],
    Missing[ "NotFound" ],
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsItemDeclaration-NotFound"
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
    TestID   -> "buildRemotePacletServerMetadata-LaterEntry"
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
    TestID   -> "buildRemotePacletServerMetadata-NameOnly"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*findInstalledPaclet*)
VerificationTest[
    Wolfram`AgentTools`Common`findInstalledPaclet[ "MockMCPPacletSkills" ],
    _PacletObject? (#[ "Name" ] === "MockMCPPacletSkills" &),
    SameTest -> MatchQ,
    TestID   -> "findInstalledPaclet-ExactName"
]

(* PacletFind treats "*" as a wildcard, but paclet names must match exactly *)
VerificationTest[
    Wolfram`AgentTools`Common`findInstalledPaclet[ "MockMCPPacletSkill*" ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "findInstalledPaclet-NoWildcards"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Multi-Root Definition Lookup*)
VerificationTest[
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-ClearCache"
]

(* Defined in the second root *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "MCPServers", "DevServer" ],
    KeyValuePattern[ { "Name" -> "DevServer", "MCPServerName" -> "MockSkillsDev" } ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-SecondRootServer"
]

VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "Tools", "DevTool" ],
    KeyValuePattern[ { "Name" -> "DevTool", "Description" -> "A tool in the second root" } ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-SecondRootTool"
]

(* Defined in the first root *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "Tools", "SkillsTool" ],
    KeyValuePattern[ { "Name" -> "SkillsTool", "Description" -> "A tool in the first root" } ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-FirstRootTool"
]

(* Defined in both roots: the first root wins *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletBadSkills, "AgentSkills", "two-roots-skill" ],
    KeyValuePattern[ "Body" -> "# First Root" ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-FirstRootWins"
]

(* Skill directories load as the LLMSkill parsed from SKILL.md *)
VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "AgentSkills", "directory-skill" ],
    HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "directory-skill" ] ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-SkillDirectory"
]

VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "AgentSkills", "combined-skill" ],
    KeyValuePattern[ "Name" -> "combined-skill" ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-CombinedSkill"
]

VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "AgentSkills", "llmskill-skill" ];
    Wolfram`AgentTools`PacletExtension`Private`$pacletDefinitionCache[
        { "MockMCPPacletSkills", "1.0.0", "AgentSkills", "llmskill-skill" }
    ],
    HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "llmskill-skill" ] ],
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-LLMSkillCached"
]

VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`cacheableResultQ @ LLMSkill[ { "some-skill", "A skill" }, "Body" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "cacheableResultQ-LLMSkill"
]

VerificationTest[
    Wolfram`AgentTools`Common`loadPacletDefinitionFile[ $mockPacletSkills, "AgentSkills", "no-such-skill" ],
    $Failed,
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-NotFound"
]

(* Servers combine tools from both roots *)
VerificationTest[
    withTemporaryRoot @ MCPServerObject[ "MockMCPPacletSkills/DevServer" ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-MCPServerObject"
]

VerificationTest[
    withTemporaryRoot @ With[ { obj = MCPServerObject[ "MockMCPPacletSkills/DevServer" ] },
        { obj[ "MCPServerName" ], #[ "Name" ] & /@ obj[ "Tools" ] }
    ],
    { "MockSkillsDev", { "SkillsTool", "DevTool" } },
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-MCPServerObject-Tools"
]

VerificationTest[
    withTemporaryRoot[ #[ "Name" ] & /@ MCPServerObjects[ "MockMCPPacletSkills/*" ] ],
    { "MockMCPPacletSkills/SkillsServer", "MockMCPPacletSkills/DevServer" },
    SameTest -> MatchQ,
    TestID   -> "MultiRoot-MCPServerObjects"
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
    TestID   -> "getAgentToolsBundles-MultipleEntries"
]

VerificationTest[
    KeyExistsQ[ Last @ Wolfram`AgentTools`Common`getAgentToolsBundles @ $mockPacletSkills, "Description" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsBundles-NoDescription"
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
    TestID   -> "getAgentToolsBundles-DefaultName"
]

(* Entries that only declare tools and prompts define no bundle *)
VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsBundles @ $mockPacletCombined,
    { },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsBundles-ToolsOnly"
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
    TestID   -> "getAgentToolsBundles-InvalidAndDuplicateNames"
]

VerificationTest[
    Lookup[ Wolfram`AgentTools`Common`getAgentToolsBundles @ $fakeRemotePaclet, "Name" ],
    { "FakeRemoteAgentToolsPaclet/Everywhere", "FakeRemoteAgentToolsPaclet/ThisSystem" },
    SameTest -> MatchQ,
    TestID   -> "getAgentToolsBundles-Remote"
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
    TestID   -> "resolvePacletBundle-Installed"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletBundle[ "MockMCPPacletSkills/NoSuchBundle" ],
    Missing[ "NotFound" ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletBundle-MissingBundle"
]

(* A server name is not a bundle name *)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletBundle[ "MockMCPPacletSkills/DevServer" ],
    Missing[ "NotFound" ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletBundle-ServerName"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletBundle[ "NotAQualifiedName" ],
    Missing[ "NotFound" ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletBundle-NotQualified"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletBundle[ "NonExistentPaclet12345/SomeBundle" ],
    Missing[ "NotFound" ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletBundle-UnknownPaclet"
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
    TestID   -> "resolvePacletSkill-Directory"
]

VerificationTest[
    Keys @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/directory-skill" ],
    { "Type", "Name", "QualifiedName", "PacletName", "PacletVersion", "Directory" },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-Directory-Keys"
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
    TestID   -> "resolvePacletSkill-Association"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/llmskill-skill" ],
    KeyValuePattern[ "Definition" -> HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "llmskill-skill" ] ] ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-LLMSkill"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/combined-skill" ],
    KeyValuePattern[ "Definition" -> KeyValuePattern[ "Name" -> "combined-skill" ] ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-CombinedFile"
]

(* An LLMSkill whose relative "Location" is a skill directory inside an extension root uses that directory *)
VerificationTest[
    Lookup[ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/located-skill" ], "Directory" ],
    File[ _String? (Take[ FileNameSplit @ #, -2 ] === { "SkillSources", "located-skill" } &) ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-HonoredLocation"
]

(* A "Location" outside of the extension roots is ignored, even if it names an existing skill directory *)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/foreign-skill" ],
    KeyValuePattern[ "Definition" -> _Association? (! KeyExistsQ[ #, "Location" ] && #[ "Name" ] === "foreign-skill" &) ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-IgnoredLocation"
]

VerificationTest[
    KeyExistsQ[ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/foreign-skill" ], "Directory" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-IgnoredLocation-NoDirectory"
]

(* A skill directory in the second root *)
VerificationTest[
    Lookup[ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/dev-skill" ], "Directory" ],
    File[ _String? (Take[ FileNameSplit @ #, -3 ] === { "DevTools", "AgentSkills", "dev-skill" } &) ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-SecondRoot"
]

(* The skill directory is checked before definition files *)
VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletBadSkills/dup-skill" ],
    KeyValuePattern[ "Directory" -> File[ _String ] ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-DirectoryFirst"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletBadSkills/two-roots-skill" ],
    KeyValuePattern[ "Definition" -> KeyValuePattern[ "Body" -> "# First Root" ] ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-FirstRootWins"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ $mockPacletSkills, "dev-skill" ],
    KeyValuePattern[ { "QualifiedName" -> "MockMCPPacletSkills/dev-skill", "Directory" -> File[ _String ] } ],
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-PacletForm"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePacletSkill Failures*)
VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/no-such-skill" ],
    _Failure,
    { AgentTools::PacletSkillNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-NotDeclared"
]

(* Declared skills of other types are not skills *)
VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletSkills/SkillsServer" ],
    _Failure,
    { AgentTools::PacletSkillNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-ServerName"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletBadSkills/missing-skill" ],
    _Failure,
    { AgentTools::PacletSkillNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-NoDefinition"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "NonExistentPaclet12345/some-skill" ],
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-PacletNotInstalled"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "not-qualified" ],
    _Failure,
    { AgentTools::AgentSkillNotFound },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-NotQualified"
]

(* SKILL.md declares a different name *)
VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletBadSkills/mismatch-skill" ],
    _Failure,
    { AgentTools::InvalidPacletSkillDefinition },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-NameMismatch"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletBadSkills/not-a-skill" ],
    _Failure,
    { AgentTools::InvalidPacletSkillDefinition },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-InvalidContents"
]

(* The honored "Location" names a skill directory with a different name *)
VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Common`resolvePacletSkill[ "MockMCPPacletBadSkills/bad-location-skill" ],
    _Failure,
    { AgentTools::InvalidPacletSkillDefinition },
    SameTest -> MatchQ,
    TestID   -> "resolvePacletSkill-LocationNameMismatch"
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
    TestID   -> "pathInsideDirectoryQ"
]

VerificationTest[
    Wolfram`AgentTools`PacletExtension`Private`absolutePathQ /@ { "/a/b", "C:\\a", "~/a", "a/b", "../a" },
    { True, True, True, False, False },
    SameTest -> MatchQ,
    TestID   -> "absolutePathQ"
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
    TestID -> "RemotePacletFallback-Setup"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $remotePaclet, "MCPServers" ],
    { "SampleServer" },
    SameTest -> MatchQ,
    TestID -> "RemotePacletFallback-MCPServers"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $remotePaclet, "Tools" ],
    { "Identity", "PrimeFinder" },
    SameTest -> MatchQ,
    TestID -> "RemotePacletFallback-Tools"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsDeclaredItems[ $remotePaclet, "MCPPrompts" ],
    { },
    SameTest -> MatchQ,
    TestID -> "RemotePacletFallback-EmptyPrompts"
]

VerificationTest[
    Wolfram`AgentTools`Common`getAgentToolsExtensionDirectories @ $remotePaclet,
    { },
    SameTest -> MatchQ,
    TestID   -> "RemotePacletFallback-NoDirectories"
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
    TestID   -> "RemotePacletFallback-Bundles"
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
    TestID   -> "RemotePacletFallback-resolvePacletBundle"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Remote Server Resolution*)

VerificationTest[
    $remoteServer = MCPServerObject[ "SamplePublisher/SamplePaclet/SampleServer" ];
    Head @ $remoteServer,
    MCPServerObject,
    SameTest -> MatchQ,
    TestID -> "RemoteServerResolution-NoFailure"
]

VerificationTest[
    $remoteServer[ "ToolNames" ],
    { "SamplePublisher/SamplePaclet/Identity", "SamplePublisher/SamplePaclet/PrimeFinder" },
    SameTest -> MatchQ,
    TestID -> "RemoteServerResolution-ToolNames"
]

(* If paclet is installed, we get a list of LLMTools, otherwise we should get a Failure *)
VerificationTest[
    Quiet[ $remoteServer[ "Tools" ], MCPServerObject::PacletNotInstalled ],
    If[ Quiet @ PacletObjectQ @ PacletObject[ "SamplePublisher/SamplePaclet" ],
        { __LLMTool },
        Failure[ "MCPServerObject::PacletNotInstalled", _ ]
    ],
    SameTest -> MatchQ,
    TestID -> "RemoteServerResolution-Tools"
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
    TestID   -> "MockPacletCleanup"
]

(* :!CodeAnalysis::EndBlock:: *)
