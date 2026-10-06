(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ValidateAgentToolsPacletExtension.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ValidateAgentToolsPacletExtension.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Mock Paclet Setup*)

$testResourceDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources" };

(* Load existing valid mock paclet *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
    $mockValid = First @ PacletFind[ "MockMCPPacletTest" ];
    $mockValid[ "Name" ],
    "MockMCPPacletTest",
    SameTest -> MatchQ,
    TestID   -> "Setup-ValidPaclet@@Tests/ValidateAgentToolsPacletExtension.wlt:28,1-35,2"
]

(* Load mock paclet with invalid extension keys *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletInvalidKeys" };
    $mockInvalidKeys = First @ PacletFind[ "MockMCPPacletInvalidKeys" ];
    $mockInvalidKeys[ "Name" ],
    "MockMCPPacletInvalidKeys",
    SameTest -> MatchQ,
    TestID   -> "Setup-InvalidKeysPaclet@@Tests/ValidateAgentToolsPacletExtension.wlt:38,1-45,2"
]

(* Load mock paclet with missing definition files *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletMissingFiles" };
    $mockMissingFiles = First @ PacletFind[ "MockMCPPacletMissingFiles" ];
    $mockMissingFiles[ "Name" ],
    "MockMCPPacletMissingFiles",
    SameTest -> MatchQ,
    TestID   -> "Setup-MissingFilesPaclet@@Tests/ValidateAgentToolsPacletExtension.wlt:48,1-55,2"
]

(* Load mock paclet with bad definition file contents *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadContents" };
    $mockBadContents = First @ PacletFind[ "MockMCPPacletBadContents" ];
    $mockBadContents[ "Name" ],
    "MockMCPPacletBadContents",
    SameTest -> MatchQ,
    TestID   -> "Setup-BadContentsPaclet@@Tests/ValidateAgentToolsPacletExtension.wlt:58,1-65,2"
]

(* Load mock paclet with bad cross-references *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadCrossRef" };
    $mockBadCrossRef = First @ PacletFind[ "MockMCPPacletBadCrossRef" ];
    $mockBadCrossRef[ "Name" ],
    "MockMCPPacletBadCrossRef",
    SameTest -> MatchQ,
    TestID   -> "Setup-BadCrossRefPaclet@@Tests/ValidateAgentToolsPacletExtension.wlt:68,1-75,2"
]

(* Load mock paclet with invalid declarations *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadDecl" };
    $mockBadDecl = First @ PacletFind[ "MockMCPPacletBadDecl" ];
    $mockBadDecl[ "Name" ],
    "MockMCPPacletBadDecl",
    SameTest -> MatchQ,
    TestID   -> "Setup-BadDeclPaclet@@Tests/ValidateAgentToolsPacletExtension.wlt:78,1-85,2"
]

(* Load mock paclet with duplicate definition files *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletDupFiles" };
    $mockDupFiles = First @ PacletFind[ "MockMCPPacletDupFiles" ];
    $mockDupFiles[ "Name" ],
    "MockMCPPacletDupFiles",
    SameTest -> MatchQ,
    TestID   -> "Setup-DupFilesPaclet@@Tests/ValidateAgentToolsPacletExtension.wlt:88,1-95,2"
]

(* Load mock paclet with no root directory *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletNoRoot" };
    $mockNoRoot = First @ PacletFind[ "MockMCPPacletNoRoot" ];
    $mockNoRoot[ "Name" ],
    "MockMCPPacletNoRoot",
    SameTest -> MatchQ,
    TestID   -> "Setup-NoRootPaclet@@Tests/ValidateAgentToolsPacletExtension.wlt:98,1-105,2"
]

(* Load mock paclet with multiple extension entries and agent skills *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletSkills" };
    $mockSkills = First @ PacletFind[ "MockMCPPacletSkills" ];
    $mockSkills[ "Name" ],
    "MockMCPPacletSkills",
    SameTest -> MatchQ,
    TestID   -> "Setup-SkillsPaclet@@Tests/ValidateAgentToolsPacletExtension.wlt:108,1-115,2"
]

(* Load mock paclet with invalid agent skills *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadSkills" };
    $mockBadSkills = First @ PacletFind[ "MockMCPPacletBadSkills" ];
    $mockBadSkills[ "Name" ],
    "MockMCPPacletBadSkills",
    SameTest -> MatchQ,
    TestID   -> "Setup-BadSkillsPaclet@@Tests/ValidateAgentToolsPacletExtension.wlt:118,1-125,2"
]

(* Load mock paclet with invalid entries and bundles *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadBundles" };
    $mockBadBundles = First @ PacletFind[ "MockMCPPacletBadBundles" ];
    $mockBadBundles[ "Name" ],
    "MockMCPPacletBadBundles",
    SameTest -> MatchQ,
    TestID   -> "Setup-BadBundlesPaclet@@Tests/ValidateAgentToolsPacletExtension.wlt:128,1-135,2"
]

(* Load mock paclet with combined definition files *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletCombined" };
    $mockCombined = First @ PacletFind[ "MockMCPPacletCombined" ];
    $mockCombined[ "Name" ],
    "MockMCPPacletCombined",
    SameTest -> MatchQ,
    TestID   -> "Setup-CombinedPaclet@@Tests/ValidateAgentToolsPacletExtension.wlt:138,1-145,2"
]

(* Clear definition cache before validation tests *)
VerificationTest[
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "Setup-ClearCache@@Tests/ValidateAgentToolsPacletExtension.wlt:148,1-153,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Valid Paclet*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockValid ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-ReturnsSuccess@@Tests/ValidateAgentToolsPacletExtension.wlt:159,1-164,2"
]

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockValid ][ "MCPServers" ],
    { "TestServer" },
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-MCPServers@@Tests/ValidateAgentToolsPacletExtension.wlt:166,1-171,2"
]

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockValid ][ "Tools" ],
    { "TestTool", "DescribedTool", "AssocTool", "LLMToolTest" },
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-Tools@@Tests/ValidateAgentToolsPacletExtension.wlt:173,1-178,2"
]

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockValid ][ "MCPPrompts" ],
    { "TestPrompt" },
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-MCPPrompts@@Tests/ValidateAgentToolsPacletExtension.wlt:180,1-185,2"
]

VerificationTest[
    Keys @ ValidateAgentToolsPacletExtension[ $mockValid ][[ 2 ]],
    { "MCPServers", "Tools", "MCPPrompts", "AgentSkills", "AgentTools" },
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-DataKeys@@Tests/ValidateAgentToolsPacletExtension.wlt:187,1-192,2"
]

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockValid ][ "AgentSkills" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-AgentSkills@@Tests/ValidateAgentToolsPacletExtension.wlt:194,1-199,2"
]

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockValid ][ "AgentTools" ],
    { "MockMCPPacletTest/AgentTools" },
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-AgentTools@@Tests/ValidateAgentToolsPacletExtension.wlt:201,1-206,2"
]

(* Entries that only declare tools define no bundle *)
VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockCombined ],
    Success[ "ValidAgentToolsPacletExtension", KeyValuePattern @ { "Tools" -> { "CombTool1", "CombTool2" }, "AgentTools" -> { } } ],
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-Combined@@Tests/ValidateAgentToolsPacletExtension.wlt:209,1-214,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Multiple Entries and Agent Skills*)

(* Two applicable entries with different roots, skills in every form, and two entries for other systems that share
   a bundle name but have disjoint "SystemID" qualifiers *)
VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockSkills ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "Skills-ReturnsSuccess@@Tests/ValidateAgentToolsPacletExtension.wlt:222,1-227,2"
]

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockSkills ][[ 2 ]],
    <|
        "MCPServers"  -> { "SkillsServer", "DevServer" },
        "Tools"       -> { "SkillsTool", "DevTool" },
        "MCPPrompts"  -> { "SkillsPrompt" },
        "AgentSkills" -> {
            "directory-skill",
            "assoc-skill",
            "llmskill-skill",
            "combined-skill",
            "located-skill",
            "foreign-skill",
            "dev-skill"
        },
        "AgentTools"  -> { "MockMCPPacletSkills/SkillsBundle", "MockMCPPacletSkills/DevBundle" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "Skills-Data@@Tests/ValidateAgentToolsPacletExtension.wlt:229,1-248,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Agent Skill Errors*)
VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockBadSkills ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "BadSkills-ReturnsFailure@@Tests/ValidateAgentToolsPacletExtension.wlt:253,1-259,2"
]

VerificationTest[
    $badSkillsErrors = Quiet[ ValidateAgentToolsPacletExtension[ $mockBadSkills ][[ 2, "Errors" ]] ],
    { __Association },
    SameTest -> MatchQ,
    TestID   -> "BadSkills-Errors@@Tests/ValidateAgentToolsPacletExtension.wlt:261,1-266,2"
]

VerificationTest[
    Cases[
        $badSkillsErrors,
        KeyValuePattern @ { "Type" -> "MissingDefinitionFile", "ItemType" -> "AgentSkills", "Item" -> item_, "ExpectedPath" -> path_ } :>
            { item, FileNameTake[ path, -2 ] }
    ],
    { { "missing-skill", FileNameJoin @ { "missing-skill", "SKILL.md" } } },
    SameTest -> MatchQ,
    TestID   -> "BadSkills-MissingDefinitionFile@@Tests/ValidateAgentToolsPacletExtension.wlt:268,1-277,2"
]

(* A skill directory and a per-item definition file in the same root *)
VerificationTest[
    Cases[
        $badSkillsErrors,
        KeyValuePattern @ { "Type" -> "DuplicateDefinitionFiles", "Item" -> "dup-skill", "Files" -> files_ } :> FileNameTake /@ files
    ],
    { { "dup-skill", "dup-skill.wl" } },
    SameTest -> MatchQ,
    TestID   -> "BadSkills-DirectoryAndFile@@Tests/ValidateAgentToolsPacletExtension.wlt:280,1-288,2"
]

(* Definitions in two roots *)
VerificationTest[
    Cases[
        $badSkillsErrors,
        KeyValuePattern @ { "Type" -> "DuplicateDefinitionFiles", "Item" -> "two-roots-skill", "Roots" -> roots_ } :> FileNameTake /@ roots
    ],
    { { "AgentTools", "Second" } },
    SameTest -> MatchQ,
    TestID   -> "BadSkills-TwoRoots@@Tests/ValidateAgentToolsPacletExtension.wlt:291,1-299,2"
]

VerificationTest[
    Sort @ Cases[ $badSkillsErrors, KeyValuePattern @ { "Type" -> "InvalidSkillDefinition", "Item" -> item_ } :> item ],
    Sort @ { "mismatch-skill", "Bad_Name", "no-description", "blank-description", "long-description", "not-a-skill", "bad-location-skill" },
    SameTest -> MatchQ,
    TestID   -> "BadSkills-InvalidSkillDefinitions@@Tests/ValidateAgentToolsPacletExtension.wlt:301,1-306,2"
]

VerificationTest[
    SelectFirst[ $badSkillsErrors, MatchQ[ KeyValuePattern @ { "Type" -> "InvalidSkillDefinition", "Item" -> "mismatch-skill" } ] ][ "Message" ],
    _String? (StringContainsQ[ #, "\"other-name\"" ] &),
    SameTest -> MatchQ,
    TestID   -> "BadSkills-NameMismatchMessage@@Tests/ValidateAgentToolsPacletExtension.wlt:308,1-313,2"
]

VerificationTest[
    SelectFirst[ $badSkillsErrors, MatchQ[ KeyValuePattern @ { "Type" -> "InvalidSkillDefinition", "Item" -> "long-description" } ] ][ "Message" ],
    _String? (StringContainsQ[ #, "1024" ] &),
    SameTest -> MatchQ,
    TestID   -> "BadSkills-LongDescriptionMessage@@Tests/ValidateAgentToolsPacletExtension.wlt:315,1-320,2"
]

(* Deployment rejects descriptions that are only whitespace, so validation must too *)
VerificationTest[
    SelectFirst[ $badSkillsErrors, MatchQ[ KeyValuePattern @ { "Type" -> "InvalidSkillDefinition", "Item" -> "blank-description" } ] ][ "Message" ],
    _String? (StringContainsQ[ #, "whitespace" ] &),
    SameTest -> MatchQ,
    TestID   -> "BadSkills-BlankDescriptionMessage@@Tests/ValidateAgentToolsPacletExtension.wlt:323,1-328,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Entry and Bundle Errors*)
VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockBadBundles ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-ReturnsFailure@@Tests/ValidateAgentToolsPacletExtension.wlt:333,1-339,2"
]

VerificationTest[
    $badBundlesErrors = Quiet[ ValidateAgentToolsPacletExtension[ $mockBadBundles ][[ 2, "Errors" ]] ],
    { __Association },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-Errors@@Tests/ValidateAgentToolsPacletExtension.wlt:341,1-346,2"
]

VerificationTest[
    Cases[ $badBundlesErrors, KeyValuePattern @ { "Type" -> "InvalidExtensionValue", "Entry" -> entry_, "Key" -> key_ } :> { entry, key } ],
    { { 1, "Description" }, { 3, "MCPPrompts" } },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-InvalidExtensionValue@@Tests/ValidateAgentToolsPacletExtension.wlt:348,1-353,2"
]

VerificationTest[
    Cases[ $badBundlesErrors, KeyValuePattern @ { "Type" -> "InvalidItemName", "ItemType" -> type_, "Item" -> item_ } :> { type, item } ],
    { { "Tools", "Other/Tool" } },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-InvalidItemName@@Tests/ValidateAgentToolsPacletExtension.wlt:355,1-360,2"
]

VerificationTest[
    Cases[ $badBundlesErrors, KeyValuePattern @ { "Type" -> "InvalidBundleName", "Entry" -> entry_ } :> entry ],
    { 4 },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-InvalidBundleName@@Tests/ValidateAgentToolsPacletExtension.wlt:362,1-367,2"
]

(* Includes two entries without "Name" *)
VerificationTest[
    Cases[ $badBundlesErrors, KeyValuePattern @ { "Type" -> "DuplicateBundleName", "Name" -> name_, "Entries" -> entries_ } :> { name, entries } ],
    { { "Main", { 1, 2 } }, { "AgentTools", { 5, 6 } } },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-DuplicateBundleName@@Tests/ValidateAgentToolsPacletExtension.wlt:370,1-375,2"
]

VerificationTest[
    Cases[ $badBundlesErrors, KeyValuePattern @ { "Type" -> "MissingRootDirectory", "Root" -> root_ } :> root ],
    { "MissingRoot" },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-MissingRootDirectory@@Tests/ValidateAgentToolsPacletExtension.wlt:377,1-382,2"
]

(* ServerB is installed with the configuration key "ServerA" *)
VerificationTest[
    Cases[
        $badBundlesErrors,
        KeyValuePattern @ { "Type" -> "DuplicateBundleConfigKey", "Bundle" -> bundle_, "ConfigKey" -> key_, "MCPServers" -> servers_ } :>
            { bundle, key, servers }
    ],
    {
        {
            "MockMCPPacletBadBundles/Main",
            "ServerA",
            { "MockMCPPacletBadBundles/ServerA", "MockMCPPacletBadBundles/ServerB" }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-DuplicateBundleConfigKey@@Tests/ValidateAgentToolsPacletExtension.wlt:385,1-400,2"
]

(* The bundle "ServerA" does not contain the server "ServerA" *)
VerificationTest[
    Cases[ $badBundlesErrors, KeyValuePattern @ { "Type" -> "AmbiguousBundleName", "Bundle" -> bundle_ } :> bundle ],
    { "MockMCPPacletBadBundles/ServerA" },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-AmbiguousBundleName@@Tests/ValidateAgentToolsPacletExtension.wlt:403,1-408,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*checkDuplicateBundleNames*)
VerificationTest[
    Wolfram`AgentTools`ValidateAgentToolsPacletExtension`Private`checkDuplicateBundleNames @ {
        <| "Name" -> "X", "SystemID" -> "MockSystem-A", "MCPServers" -> { "S" } |>,
        <| "Name" -> "X", "SystemID" -> { "MockSystem-B", "MockSystem-C" }, "MCPServers" -> { "S" } |>
    },
    { },
    SameTest -> MatchQ,
    TestID   -> "checkDuplicateBundleNames-DisjointSystemIDs@@Tests/ValidateAgentToolsPacletExtension.wlt:413,1-421,2"
]

VerificationTest[
    Wolfram`AgentTools`ValidateAgentToolsPacletExtension`Private`checkDuplicateBundleNames @ {
        <| "Name" -> "X", "SystemID" -> "MockSystem-A", "MCPServers" -> { "S" } |>,
        <| "Name" -> "X", "SystemID" -> { "MockSystem-A", "MockSystem-B" }, "AgentSkills" -> { "s" } |>
    },
    { KeyValuePattern @ { "Type" -> "DuplicateBundleName", "Name" -> "X", "Entries" -> { 1, 2 } } },
    SameTest -> MatchQ,
    TestID   -> "checkDuplicateBundleNames-OverlappingSystemIDs@@Tests/ValidateAgentToolsPacletExtension.wlt:423,1-431,2"
]

VerificationTest[
    Wolfram`AgentTools`ValidateAgentToolsPacletExtension`Private`checkDuplicateBundleNames @ {
        <| "Name" -> "X", "SystemID" -> "MockSystem-A", "MCPServers" -> { "S" } |>,
        <| "Name" -> "X", "MCPServers" -> { "S" } |>
    },
    { KeyValuePattern @ { "Type" -> "DuplicateBundleName", "Entries" -> { 1, 2 } } },
    SameTest -> MatchQ,
    TestID   -> "checkDuplicateBundleNames-AllSystems@@Tests/ValidateAgentToolsPacletExtension.wlt:433,1-441,2"
]

(* Entries that declare no servers or skills define no bundle *)
VerificationTest[
    Wolfram`AgentTools`ValidateAgentToolsPacletExtension`Private`checkDuplicateBundleNames @ {
        <| "Tools" -> { "A" } |>,
        <| "Root" -> "Other", "Tools" -> { "B" } |>,
        <| "MCPServers" -> { "S" } |>
    },
    { },
    SameTest -> MatchQ,
    TestID   -> "checkDuplicateBundleNames-NoBundles@@Tests/ValidateAgentToolsPacletExtension.wlt:444,1-453,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Extension Structure - Invalid Keys*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockInvalidKeys ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "InvalidKeys-ReturnsFailure@@Tests/ValidateAgentToolsPacletExtension.wlt:459,1-465,2"
]

VerificationTest[
    Module[ { result },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockInvalidKeys ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ "Type" -> "InvalidExtensionKeys" ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InvalidKeys-HasInvalidKeysError@@Tests/ValidateAgentToolsPacletExtension.wlt:467,1-475,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Extension Structure - Invalid Declarations*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockBadDecl ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "BadDecl-ReturnsFailure@@Tests/ValidateAgentToolsPacletExtension.wlt:481,1-487,2"
]

VerificationTest[
    Module[ { result, declErrors },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockBadDecl ];
        declErrors = Select[ result[[ "Errors" ]], #[ "Type" ] === "InvalidDeclaration" & ];
        Length[ declErrors ] >= 1
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BadDecl-HasInvalidDeclarations@@Tests/ValidateAgentToolsPacletExtension.wlt:489,1-498,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Extension Structure - No AgentTools Extension*)

VerificationTest[
    Module[ { nonMCPPaclet },
        nonMCPPaclet = First @ PacletFind[ "PacletTools" ];
        ValidateAgentToolsPacletExtension[ nonMCPPaclet ]
    ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "NoExtension-ReturnsFailure@@Tests/ValidateAgentToolsPacletExtension.wlt:504,1-513,2"
]

VerificationTest[
    Module[ { nonMCPPaclet, result },
        nonMCPPaclet = First @ PacletFind[ "PacletTools" ];
        result = Quiet @ ValidateAgentToolsPacletExtension[ nonMCPPaclet ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ "Type" -> "NoAgentToolsExtension" ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NoExtension-HasNoAgentToolsExtensionError@@Tests/ValidateAgentToolsPacletExtension.wlt:515,1-524,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Existence - Missing Root Directory*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockNoRoot ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "NoRoot-ReturnsFailure@@Tests/ValidateAgentToolsPacletExtension.wlt:530,1-536,2"
]

VerificationTest[
    Module[ { result },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockNoRoot ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ "Type" -> "MissingRootDirectory" ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NoRoot-HasMissingRootError@@Tests/ValidateAgentToolsPacletExtension.wlt:538,1-546,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Existence - Missing Definition Files*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockMissingFiles ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "MissingFiles-ReturnsFailure@@Tests/ValidateAgentToolsPacletExtension.wlt:552,1-558,2"
]

VerificationTest[
    Module[ { result, missingErrors },
        GeneralUtilities`EnsureDirectory @ { $testResourceDirectory, "MockMCPPacletMissingFiles", "AgentTools" };
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockMissingFiles ];
        missingErrors = Select[ result[[ "Errors" ]], #[ "Type" ] === "MissingDefinitionFile" & ];
        Length[ missingErrors ]
    ],
    3,
    SameTest -> MatchQ,
    TestID   -> "MissingFiles-ThreeMissingFiles@@Tests/ValidateAgentToolsPacletExtension.wlt:560,1-570,2"
]

VerificationTest[
    Module[ { result, missingErrors },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockMissingFiles ];
        missingErrors = Select[ result[[ "Errors" ]], #[ "Type" ] === "MissingDefinitionFile" & ];
        Sort @ Lookup[ missingErrors, "Item" ]
    ],
    { "MissingPrompt", "MissingServer", "MissingTool" },
    SameTest -> MatchQ,
    TestID   -> "MissingFiles-CorrectItems@@Tests/ValidateAgentToolsPacletExtension.wlt:572,1-581,2"
]

VerificationTest[
    Module[ { result, missingErrors },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockMissingFiles ];
        missingErrors = Select[ result[[ "Errors" ]], #[ "Type" ] === "MissingDefinitionFile" & ];
        AllTrue[ missingErrors, KeyExistsQ[ #, "ExpectedPath" ] & ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MissingFiles-HasExpectedPaths@@Tests/ValidateAgentToolsPacletExtension.wlt:583,1-592,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Existence - Duplicate Definition Files*)

VerificationTest[
    Module[ { result },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockDupFiles ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ "Type" -> "DuplicateDefinitionFiles" ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "DupFiles-HasDuplicateWarning@@Tests/ValidateAgentToolsPacletExtension.wlt:598,1-606,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Contents - Bad Tool Definition*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockBadContents ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "BadContents-ReturnsFailure@@Tests/ValidateAgentToolsPacletExtension.wlt:612,1-618,2"
]

VerificationTest[
    Module[ { result },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockBadContents ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ { "Type" -> "InvalidDefinitionContents", "Item" -> "BadTool" } ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BadContents-BadToolDetected@@Tests/ValidateAgentToolsPacletExtension.wlt:620,1-628,2"
]

VerificationTest[
    Module[ { result },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockBadContents ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ { "Type" -> "InvalidToolDefinition", "Item" -> "IncompleteTool" } ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BadContents-IncompleteToolDetected@@Tests/ValidateAgentToolsPacletExtension.wlt:630,1-638,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cross-References - Invalid References*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockBadCrossRef ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "BadCrossRef-ReturnsFailure@@Tests/ValidateAgentToolsPacletExtension.wlt:644,1-650,2"
]

VerificationTest[
    Module[ { result },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockBadCrossRef ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ { "Type" -> "InvalidToolReference", "Tool" -> "UndeclaredTool" } ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BadCrossRef-UndeclaredToolDetected@@Tests/ValidateAgentToolsPacletExtension.wlt:652,1-660,2"
]

VerificationTest[
    Module[ { result },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockBadCrossRef ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ { "Type" -> "InvalidPromptReference", "Prompt" -> "UndeclaredPrompt" } ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BadCrossRef-UndeclaredPromptDetected@@Tests/ValidateAgentToolsPacletExtension.wlt:662,1-670,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cross-References - Valid Short Names*)

VerificationTest[
    MatchQ[ ValidateAgentToolsPacletExtension[ $mockValid ], _Success ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CrossRef-ShortNamesValid@@Tests/ValidateAgentToolsPacletExtension.wlt:676,1-681,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Accented Skill Frontmatter*)
(* LLMSkill[File[dir]] can't parse frontmatter with characters in U+0080-U+00FF; the skill is still valid *)
VerificationTest[
    $accentedPaclet = Module[ { dir, skill, stream },
        dir = CreateDirectory[ ];
        Export[
            FileNameJoin @ { dir, "PacletInfo.wl" },
            "PacletObject[<|\"Name\" -> \"MockAccentedSkills\", \"Version\" -> \"1.0.0\", \"Extensions\" -> {{\"AgentTools\", \"AgentSkills\" -> {\"accented-skill\"}}}|>]",
            "Text"
        ];
        skill = FileNameJoin @ { dir, "AgentTools", "AgentSkills", "accented-skill" };
        CreateDirectory[ skill, CreateIntermediateDirectories -> True ];
        stream = OpenWrite[ FileNameJoin @ { skill, "SKILL.md" }, BinaryFormat -> True ];
        BinaryWrite[ stream, StringToByteArray[ "---\nname: accented-skill\ndescription: Solve the Schr\[ODoubleDot]dinger equation\n---\n\nBody.\n", "UTF-8" ] ];
        Close @ stream;
        PacletDirectoryLoad @ dir;
        PacletObject[ "MockAccentedSkills" ]
    ];
    ValidateAgentToolsPacletExtension @ $accentedPaclet,
    _Success,
    SameTest -> MatchQ,
    TestID   -> "AccentedSkill-Valid@@Tests/ValidateAgentToolsPacletExtension.wlt:687,1-707,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockAccentedSkills/accented-skill" ][ "Directory" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "AccentedSkill-Resolves@@Tests/ValidateAgentToolsPacletExtension.wlt:709,1-714,2"
]

VerificationTest[
    With[ { dir = $accentedPaclet[ "Location" ] },
        PacletDirectoryUnload @ dir;
        Quiet @ DeleteDirectory[ dir, DeleteContents -> True ]
    ],
    Null,
    TestID -> "AccentedSkill-Cleanup@@Tests/ValidateAgentToolsPacletExtension.wlt:716,1-723,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Mock Paclet Cleanup*)
VerificationTest[
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletInvalidKeys" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletMissingFiles" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadContents" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadCrossRef" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadDecl" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletDupFiles" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletNoRoot" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletSkills" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadSkills" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadBundles" };
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletCombined" };
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "Cleanup@@Tests/ValidateAgentToolsPacletExtension.wlt:728,1-745,2"
]

(* :!CodeAnalysis::EndBlock:: *)
