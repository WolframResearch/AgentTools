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
    TestID   -> "Setup-ValidPaclet"
]

(* Load mock paclet with invalid extension keys *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletInvalidKeys" };
    $mockInvalidKeys = First @ PacletFind[ "MockMCPPacletInvalidKeys" ];
    $mockInvalidKeys[ "Name" ],
    "MockMCPPacletInvalidKeys",
    SameTest -> MatchQ,
    TestID   -> "Setup-InvalidKeysPaclet"
]

(* Load mock paclet with missing definition files *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletMissingFiles" };
    $mockMissingFiles = First @ PacletFind[ "MockMCPPacletMissingFiles" ];
    $mockMissingFiles[ "Name" ],
    "MockMCPPacletMissingFiles",
    SameTest -> MatchQ,
    TestID   -> "Setup-MissingFilesPaclet"
]

(* Load mock paclet with bad definition file contents *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadContents" };
    $mockBadContents = First @ PacletFind[ "MockMCPPacletBadContents" ];
    $mockBadContents[ "Name" ],
    "MockMCPPacletBadContents",
    SameTest -> MatchQ,
    TestID   -> "Setup-BadContentsPaclet"
]

(* Load mock paclet with bad cross-references *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadCrossRef" };
    $mockBadCrossRef = First @ PacletFind[ "MockMCPPacletBadCrossRef" ];
    $mockBadCrossRef[ "Name" ],
    "MockMCPPacletBadCrossRef",
    SameTest -> MatchQ,
    TestID   -> "Setup-BadCrossRefPaclet"
]

(* Load mock paclet with invalid declarations *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadDecl" };
    $mockBadDecl = First @ PacletFind[ "MockMCPPacletBadDecl" ];
    $mockBadDecl[ "Name" ],
    "MockMCPPacletBadDecl",
    SameTest -> MatchQ,
    TestID   -> "Setup-BadDeclPaclet"
]

(* Load mock paclet with duplicate definition files *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletDupFiles" };
    $mockDupFiles = First @ PacletFind[ "MockMCPPacletDupFiles" ];
    $mockDupFiles[ "Name" ],
    "MockMCPPacletDupFiles",
    SameTest -> MatchQ,
    TestID   -> "Setup-DupFilesPaclet"
]

(* Load mock paclet with no root directory *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletNoRoot" };
    $mockNoRoot = First @ PacletFind[ "MockMCPPacletNoRoot" ];
    $mockNoRoot[ "Name" ],
    "MockMCPPacletNoRoot",
    SameTest -> MatchQ,
    TestID   -> "Setup-NoRootPaclet"
]

(* Load mock paclet with multiple extension entries and agent skills *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletSkills" };
    $mockSkills = First @ PacletFind[ "MockMCPPacletSkills" ];
    $mockSkills[ "Name" ],
    "MockMCPPacletSkills",
    SameTest -> MatchQ,
    TestID   -> "Setup-SkillsPaclet"
]

(* Load mock paclet with invalid agent skills *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadSkills" };
    $mockBadSkills = First @ PacletFind[ "MockMCPPacletBadSkills" ];
    $mockBadSkills[ "Name" ],
    "MockMCPPacletBadSkills",
    SameTest -> MatchQ,
    TestID   -> "Setup-BadSkillsPaclet"
]

(* Load mock paclet with invalid entries and bundles *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletBadBundles" };
    $mockBadBundles = First @ PacletFind[ "MockMCPPacletBadBundles" ];
    $mockBadBundles[ "Name" ],
    "MockMCPPacletBadBundles",
    SameTest -> MatchQ,
    TestID   -> "Setup-BadBundlesPaclet"
]

(* Load mock paclet with combined definition files *)
VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletCombined" };
    $mockCombined = First @ PacletFind[ "MockMCPPacletCombined" ];
    $mockCombined[ "Name" ],
    "MockMCPPacletCombined",
    SameTest -> MatchQ,
    TestID   -> "Setup-CombinedPaclet"
]

(* Clear definition cache before validation tests *)
VerificationTest[
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "Setup-ClearCache"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Valid Paclet*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockValid ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-ReturnsSuccess"
]

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockValid ][ "MCPServers" ],
    { "TestServer" },
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-MCPServers"
]

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockValid ][ "Tools" ],
    { "TestTool", "DescribedTool", "AssocTool", "LLMToolTest" },
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-Tools"
]

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockValid ][ "MCPPrompts" ],
    { "TestPrompt" },
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-MCPPrompts"
]

VerificationTest[
    Keys @ ValidateAgentToolsPacletExtension[ $mockValid ][[ 2 ]],
    { "MCPServers", "Tools", "MCPPrompts", "AgentSkills", "AgentTools" },
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-DataKeys"
]

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockValid ][ "AgentSkills" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-AgentSkills"
]

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockValid ][ "AgentTools" ],
    { "MockMCPPacletTest/AgentTools" },
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-AgentTools"
]

(* Entries that only declare tools define no bundle *)
VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockCombined ],
    Success[ "ValidAgentToolsPacletExtension", KeyValuePattern @ { "Tools" -> { "CombTool1", "CombTool2" }, "AgentTools" -> { } } ],
    SameTest -> MatchQ,
    TestID   -> "ValidPaclet-Combined"
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
    TestID   -> "Skills-ReturnsSuccess"
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
    TestID   -> "Skills-Data"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Agent Skill Errors*)
VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockBadSkills ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "BadSkills-ReturnsFailure"
]

VerificationTest[
    $badSkillsErrors = Quiet[ ValidateAgentToolsPacletExtension[ $mockBadSkills ][[ 2, "Errors" ]] ],
    { __Association },
    SameTest -> MatchQ,
    TestID   -> "BadSkills-Errors"
]

VerificationTest[
    Cases[
        $badSkillsErrors,
        KeyValuePattern @ { "Type" -> "MissingDefinitionFile", "ItemType" -> "AgentSkills", "Item" -> item_, "ExpectedPath" -> path_ } :>
            { item, FileNameTake[ path, -2 ] }
    ],
    { { "missing-skill", FileNameJoin @ { "missing-skill", "SKILL.md" } } },
    SameTest -> MatchQ,
    TestID   -> "BadSkills-MissingDefinitionFile"
]

(* A skill directory and a per-item definition file in the same root *)
VerificationTest[
    Cases[
        $badSkillsErrors,
        KeyValuePattern @ { "Type" -> "DuplicateDefinitionFiles", "Item" -> "dup-skill", "Files" -> files_ } :> FileNameTake /@ files
    ],
    { { "dup-skill", "dup-skill.wl" } },
    SameTest -> MatchQ,
    TestID   -> "BadSkills-DirectoryAndFile"
]

(* Definitions in two roots *)
VerificationTest[
    Cases[
        $badSkillsErrors,
        KeyValuePattern @ { "Type" -> "DuplicateDefinitionFiles", "Item" -> "two-roots-skill", "Roots" -> roots_ } :> FileNameTake /@ roots
    ],
    { { "AgentTools", "Second" } },
    SameTest -> MatchQ,
    TestID   -> "BadSkills-TwoRoots"
]

VerificationTest[
    Sort @ Cases[ $badSkillsErrors, KeyValuePattern @ { "Type" -> "InvalidSkillDefinition", "Item" -> item_ } :> item ],
    Sort @ { "mismatch-skill", "Bad_Name", "no-description", "blank-description", "long-description", "not-a-skill", "bad-location-skill" },
    SameTest -> MatchQ,
    TestID   -> "BadSkills-InvalidSkillDefinitions"
]

VerificationTest[
    SelectFirst[ $badSkillsErrors, MatchQ[ KeyValuePattern @ { "Type" -> "InvalidSkillDefinition", "Item" -> "mismatch-skill" } ] ][ "Message" ],
    _String? (StringContainsQ[ #, "\"other-name\"" ] &),
    SameTest -> MatchQ,
    TestID   -> "BadSkills-NameMismatchMessage"
]

VerificationTest[
    SelectFirst[ $badSkillsErrors, MatchQ[ KeyValuePattern @ { "Type" -> "InvalidSkillDefinition", "Item" -> "long-description" } ] ][ "Message" ],
    _String? (StringContainsQ[ #, "1024" ] &),
    SameTest -> MatchQ,
    TestID   -> "BadSkills-LongDescriptionMessage"
]

(* Deployment rejects descriptions that are only whitespace, so validation must too *)
VerificationTest[
    SelectFirst[ $badSkillsErrors, MatchQ[ KeyValuePattern @ { "Type" -> "InvalidSkillDefinition", "Item" -> "blank-description" } ] ][ "Message" ],
    _String? (StringContainsQ[ #, "whitespace" ] &),
    SameTest -> MatchQ,
    TestID   -> "BadSkills-BlankDescriptionMessage"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Entry and Bundle Errors*)
VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockBadBundles ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-ReturnsFailure"
]

VerificationTest[
    $badBundlesErrors = Quiet[ ValidateAgentToolsPacletExtension[ $mockBadBundles ][[ 2, "Errors" ]] ],
    { __Association },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-Errors"
]

VerificationTest[
    Cases[ $badBundlesErrors, KeyValuePattern @ { "Type" -> "InvalidExtensionValue", "Entry" -> entry_, "Key" -> key_ } :> { entry, key } ],
    { { 1, "Description" }, { 3, "MCPPrompts" } },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-InvalidExtensionValue"
]

VerificationTest[
    Cases[ $badBundlesErrors, KeyValuePattern @ { "Type" -> "InvalidItemName", "ItemType" -> type_, "Item" -> item_ } :> { type, item } ],
    { { "Tools", "Other/Tool" } },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-InvalidItemName"
]

VerificationTest[
    Cases[ $badBundlesErrors, KeyValuePattern @ { "Type" -> "InvalidBundleName", "Entry" -> entry_ } :> entry ],
    { 4 },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-InvalidBundleName"
]

(* Includes two entries without "Name" *)
VerificationTest[
    Cases[ $badBundlesErrors, KeyValuePattern @ { "Type" -> "DuplicateBundleName", "Name" -> name_, "Entries" -> entries_ } :> { name, entries } ],
    { { "Main", { 1, 2 } }, { "AgentTools", { 5, 6 } } },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-DuplicateBundleName"
]

VerificationTest[
    Cases[ $badBundlesErrors, KeyValuePattern @ { "Type" -> "MissingRootDirectory", "Root" -> root_ } :> root ],
    { "MissingRoot" },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-MissingRootDirectory"
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
    TestID   -> "BadBundles-DuplicateBundleConfigKey"
]

(* The bundle "ServerA" does not contain the server "ServerA" *)
VerificationTest[
    Cases[ $badBundlesErrors, KeyValuePattern @ { "Type" -> "AmbiguousBundleName", "Bundle" -> bundle_ } :> bundle ],
    { "MockMCPPacletBadBundles/ServerA" },
    SameTest -> MatchQ,
    TestID   -> "BadBundles-AmbiguousBundleName"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*checkEntryStructure*)
(* Paclets built from in-memory data keep the qualifier values as given (installed paclets read from PacletInfo.wl
   convert scalars to strings) *)
VerificationTest[
    Cases[
        Wolfram`AgentTools`ValidateAgentToolsPacletExtension`Private`checkEntryStructure[
            <| "WolframVersion" -> 15, "SystemID" -> { "Linux-x86-64", 1 }, "Tools" -> { "A" } |>,
            1,
            1
        ],
        KeyValuePattern @ { "Type" -> "InvalidExtensionValue", "Key" -> key_ } :> key
    ],
    { "WolframVersion", "SystemID" },
    SameTest -> MatchQ,
    TestID   -> "checkEntryStructure-InvalidQualifiers"
]

VerificationTest[
    Wolfram`AgentTools`ValidateAgentToolsPacletExtension`Private`checkEntryStructure[ #, 1, 1 ] & /@ {
        <| "SystemID" -> All, "Tools" -> { "A" } |>,
        <| "SystemID" -> "Linux-x86-64", "WolframVersion" -> "14.3+", "Tools" -> { "A" } |>,
        <| "SystemID" -> { "Linux-x86-64", "MacOSX-ARM64" }, "Tools" -> { "A" } |>
    },
    { { }, { }, { } },
    SameTest -> MatchQ,
    TestID   -> "checkEntryStructure-ValidQualifiers"
]

(* Forms that PacletTools`PacletExtensions rejects *)
VerificationTest[
    Wolfram`AgentTools`ValidateAgentToolsPacletExtension`Private`checkEntryStructure[ #, 1, 1 ] & /@ {
        <| "SystemID" -> { }, "Tools" -> { "A" } |>,
        <| "SystemID" -> Automatic, "Tools" -> { "A" } |>,
        <| "SystemID" -> { { "Linux-x86-64" } }, "Tools" -> { "A" } |>
    },
    ConstantArray[ { KeyValuePattern @ { "Type" -> "InvalidExtensionValue", "Key" -> "SystemID" } }, 3 ],
    SameTest -> MatchQ,
    TestID   -> "checkEntryStructure-RejectedSystemIDForms"
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
    TestID   -> "checkDuplicateBundleNames-DisjointSystemIDs"
]

VerificationTest[
    Wolfram`AgentTools`ValidateAgentToolsPacletExtension`Private`checkDuplicateBundleNames @ {
        <| "Name" -> "X", "SystemID" -> "MockSystem-A", "MCPServers" -> { "S" } |>,
        <| "Name" -> "X", "SystemID" -> { "MockSystem-A", "MockSystem-B" }, "AgentSkills" -> { "s" } |>
    },
    { KeyValuePattern @ { "Type" -> "DuplicateBundleName", "Name" -> "X", "Entries" -> { 1, 2 } } },
    SameTest -> MatchQ,
    TestID   -> "checkDuplicateBundleNames-OverlappingSystemIDs"
]

VerificationTest[
    Wolfram`AgentTools`ValidateAgentToolsPacletExtension`Private`checkDuplicateBundleNames @ {
        <| "Name" -> "X", "SystemID" -> "MockSystem-A", "MCPServers" -> { "S" } |>,
        <| "Name" -> "X", "MCPServers" -> { "S" } |>
    },
    { KeyValuePattern @ { "Type" -> "DuplicateBundleName", "Entries" -> { 1, 2 } } },
    SameTest -> MatchQ,
    TestID   -> "checkDuplicateBundleNames-AllSystems"
]

(* The string "All" is an ordinary system ID (as in PacletTools), not a wildcard *)
VerificationTest[
    Wolfram`AgentTools`ValidateAgentToolsPacletExtension`Private`checkDuplicateBundleNames @ {
        <| "Name" -> "X", "SystemID" -> "All", "MCPServers" -> { "S" } |>,
        <| "Name" -> "X", "SystemID" -> "MockSystem-A", "MCPServers" -> { "S" } |>
    },
    { },
    SameTest -> MatchQ,
    TestID   -> "checkDuplicateBundleNames-AllStringIsSystemID"
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
    TestID   -> "checkDuplicateBundleNames-NoBundles"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Extension Structure - Invalid Keys*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockInvalidKeys ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "InvalidKeys-ReturnsFailure"
]

VerificationTest[
    Module[ { result },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockInvalidKeys ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ "Type" -> "InvalidExtensionKeys" ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InvalidKeys-HasInvalidKeysError"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Extension Structure - Invalid Declarations*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockBadDecl ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "BadDecl-ReturnsFailure"
]

VerificationTest[
    Module[ { result, declErrors },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockBadDecl ];
        declErrors = Select[ result[[ "Errors" ]], #[ "Type" ] === "InvalidDeclaration" & ];
        Length[ declErrors ] >= 1
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BadDecl-HasInvalidDeclarations"
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
    TestID   -> "NoExtension-ReturnsFailure"
]

VerificationTest[
    Module[ { nonMCPPaclet, result },
        nonMCPPaclet = First @ PacletFind[ "PacletTools" ];
        result = Quiet @ ValidateAgentToolsPacletExtension[ nonMCPPaclet ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ "Type" -> "NoAgentToolsExtension" ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NoExtension-HasNoAgentToolsExtensionError"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Existence - Missing Root Directory*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockNoRoot ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "NoRoot-ReturnsFailure"
]

VerificationTest[
    Module[ { result },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockNoRoot ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ "Type" -> "MissingRootDirectory" ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NoRoot-HasMissingRootError"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Existence - Missing Definition Files*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockMissingFiles ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "MissingFiles-ReturnsFailure"
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
    TestID   -> "MissingFiles-ThreeMissingFiles"
]

VerificationTest[
    Module[ { result, missingErrors },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockMissingFiles ];
        missingErrors = Select[ result[[ "Errors" ]], #[ "Type" ] === "MissingDefinitionFile" & ];
        Sort @ Lookup[ missingErrors, "Item" ]
    ],
    { "MissingPrompt", "MissingServer", "MissingTool" },
    SameTest -> MatchQ,
    TestID   -> "MissingFiles-CorrectItems"
]

VerificationTest[
    Module[ { result, missingErrors },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockMissingFiles ];
        missingErrors = Select[ result[[ "Errors" ]], #[ "Type" ] === "MissingDefinitionFile" & ];
        AllTrue[ missingErrors, KeyExistsQ[ #, "ExpectedPath" ] & ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MissingFiles-HasExpectedPaths"
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
    TestID   -> "DupFiles-HasDuplicateWarning"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Contents - Bad Tool Definition*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockBadContents ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "BadContents-ReturnsFailure"
]

VerificationTest[
    Module[ { result },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockBadContents ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ { "Type" -> "InvalidDefinitionContents", "Item" -> "BadTool" } ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BadContents-BadToolDetected"
]

VerificationTest[
    Module[ { result },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockBadContents ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ { "Type" -> "InvalidToolDefinition", "Item" -> "IncompleteTool" } ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BadContents-IncompleteToolDetected"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cross-References - Invalid References*)

VerificationTest[
    ValidateAgentToolsPacletExtension[ $mockBadCrossRef ],
    _Failure,
    { ValidateAgentToolsPacletExtension::InvalidAgentToolsPacletExtension },
    SameTest -> MatchQ,
    TestID   -> "BadCrossRef-ReturnsFailure"
]

VerificationTest[
    Module[ { result },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockBadCrossRef ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ { "Type" -> "InvalidToolReference", "Tool" -> "UndeclaredTool" } ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BadCrossRef-UndeclaredToolDetected"
]

VerificationTest[
    Module[ { result },
        result = Quiet @ ValidateAgentToolsPacletExtension[ $mockBadCrossRef ];
        MemberQ[ result[[ "Errors" ]], KeyValuePattern[ { "Type" -> "InvalidPromptReference", "Prompt" -> "UndeclaredPrompt" } ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BadCrossRef-UndeclaredPromptDetected"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cross-References - Valid Short Names*)

VerificationTest[
    MatchQ[ ValidateAgentToolsPacletExtension[ $mockValid ], _Success ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CrossRef-ShortNamesValid"
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
    TestID   -> "AccentedSkill-Valid"
]

VerificationTest[
    Wolfram`AgentTools`Common`resolvePacletSkill[ "MockAccentedSkills/accented-skill" ][ "Directory" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "AccentedSkill-Resolves"
]

VerificationTest[
    With[ { dir = $accentedPaclet[ "Location" ] },
        PacletDirectoryUnload @ dir;
        Quiet @ DeleteDirectory[ dir, DeleteContents -> True ]
    ],
    Null,
    TestID -> "AccentedSkill-Cleanup"
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
    TestID   -> "Cleanup"
]

(* :!CodeAnalysis::EndBlock:: *)
