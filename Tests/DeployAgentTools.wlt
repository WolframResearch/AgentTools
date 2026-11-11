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
(*Helper Functions*)

$testDeploymentData := <|
    "UUID"          -> CreateUUID[],
    "Version"       -> 1,
    "Timestamp"     -> Now,
    "PacletVersion" -> "1.8.0",
    "CreatedBy"     -> "DeployAgentTools",
    "MCP"           -> <|
        "ClientName" -> "ClaudeDesktop",
        "Target"     -> "ClaudeDesktop",
        "Server"     -> "WolframLanguage",
        "ConfigFile" -> File[ FileNameJoin @ { $TemporaryDirectory, "test_config_" <> CreateUUID[] <> ".json" } ],
        "Options"    -> <|"DevelopmentMode" -> False|>
    |>,
    "Skills"        -> <||>,
    "Hooks"         -> <||>,
    "Meta"          -> <||>
|>;

agentToolsDeploymentQ = Wolfram`AgentTools`DeployAgentTools`Private`agentToolsDeploymentQ;
configFilesEqual = Wolfram`AgentTools`DeployAgentTools`Private`configFilesEqual;

(* Tests that deploy, list, or delete run with a temporary AgentTools root (deployment records and the skill registry)
   and a temporary home directory (client config files and skill directories), so nothing on the machine is touched.
   The built-in bundles install agent skills wherever the target supports them. *)
$testRoot = CreateDirectory[ ];
$testHome = CreateDirectory[ ];

withTestEnvironment // Attributes = { HoldFirst };
withTestEnvironment[ eval_ ] :=
    Block[ { Wolfram`AgentTools`Common`$rootPath = $testRoot, $HomeDirectory = $testHome }, eval ];

$deploymentsPath := Wolfram`AgentTools`Common`$deploymentsPath;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AgentToolsDeployment Construction*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Valid Construction*)
VerificationTest[
    dep = AgentToolsDeployment[ $testDeploymentData ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-ValidConstruction"
]

VerificationTest[
    agentToolsDeploymentQ @ dep,
    True,
    TestID -> "AgentToolsDeployment-ValidQ"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Construction*)
VerificationTest[
    AgentToolsDeployment[ "not-a-real-uuid" ],
    _Failure,
    { AgentToolsDeployment::DeploymentNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-InvalidUUID"
]

VerificationTest[
    AgentToolsDeployment[ <|"UUID" -> "test"|> ],
    _Failure,
    { AgentToolsDeployment::InvalidDeploymentData },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-InvalidIncompleteData"
]

VerificationTest[
    AgentToolsDeployment[ <||> ],
    _Failure,
    { AgentToolsDeployment::InvalidDeploymentData },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-InvalidEmptyAssociation"
]

VerificationTest[
    Quiet @ agentToolsDeploymentQ @ AgentToolsDeployment[ <||> ],
    False,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-InvalidNotValidQ"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Property Access*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Top-Level Properties*)
VerificationTest[
    dep[ "UUID" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-UUID"
]

VerificationTest[
    dep[ "Timestamp" ],
    _DateObject,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Timestamp"
]

VerificationTest[
    dep[ "PacletVersion" ],
    "1.8.0",
    TestID -> "AgentToolsDeployment-Property-PacletVersion"
]

VerificationTest[
    dep[ "CreatedBy" ],
    "DeployAgentTools",
    TestID -> "AgentToolsDeployment-Property-CreatedBy"
]

VerificationTest[
    dep[ "Version" ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Version-Missing"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCP Shortcut Properties*)
VerificationTest[
    dep[ "ClientName" ],
    "ClaudeDesktop",
    TestID -> "AgentToolsDeployment-Property-ClientName"
]

VerificationTest[
    dep[ "Target" ],
    "ClaudeDesktop",
    TestID -> "AgentToolsDeployment-Property-Target"
]

VerificationTest[
    dep[ "Server" ],
    "WolframLanguage",
    TestID -> "AgentToolsDeployment-Property-Server"
]

(* Legacy-shaped fixture: Toolset falls back through MCP/Server *)
VerificationTest[
    dep[ "Toolset" ],
    "WolframLanguage",
    TestID -> "AgentToolsDeployment-Property-Toolset-LegacyFallback"
]

VerificationTest[
    dep[ "ConfigFile" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-ConfigFile"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Sub-Association Properties*)
VerificationTest[
    dep[ "MCP" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-MCP"
]

VerificationTest[
    dep[ "Skills" ],
    <||>,
    TestID -> "AgentToolsDeployment-Property-Skills"
]

VerificationTest[
    dep[ "Hooks" ],
    <||>,
    TestID -> "AgentToolsDeployment-Property-Hooks"
]

VerificationTest[
    dep[ "Meta" ],
    <||>,
    TestID -> "AgentToolsDeployment-Property-Meta"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Derived Properties*)
VerificationTest[
    dep[ "Data" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Data"
]

VerificationTest[
    dep[ "Location" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Location"
]

VerificationTest[
    dep[ "Properties" ],
    _List,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Properties"
]

VerificationTest[
    MemberQ[ dep[ "Properties" ], "UUID" ],
    True,
    TestID -> "AgentToolsDeployment-Property-PropertiesContainsUUID"
]

VerificationTest[
    dep[ "MCPServerObject" ],
    _MCPServerObject,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-MCPServerObject"
]

VerificationTest[
    dep[ "Tools" ],
    { ___LLMTool },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Tools"
]

VerificationTest[
    dep[ "LLMConfiguration" ],
    _LLMConfiguration,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-LLMConfiguration"
]

VerificationTest[
    dep[ "Scope" ],
    "Global",
    TestID -> "AgentToolsDeployment-Property-Scope-Global"
]

VerificationTest[
    SubsetQ[ dep[ "Properties" ], { "MCPServerObject", "Tools", "LLMConfiguration" } ],
    True,
    TestID -> "AgentToolsDeployment-Property-PropertiesContainsNewDerived"
]

VerificationTest[
    MemberQ[ dep[ "Properties" ], "Toolset" ],
    True,
    TestID -> "AgentToolsDeployment-Property-PropertiesContainsToolset"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Two-Argument Property Access*)
VerificationTest[
    dep[ "MCP", "Options" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-MCP-Options"
]

VerificationTest[
    dep[ "MCP", "Server" ],
    "WolframLanguage",
    TestID -> "AgentToolsDeployment-Property-MCP-Server"
]

(* Legacy fixture doesn't have MCP/Toolset - verify the two-arg accessor reports missing *)
VerificationTest[
    dep[ "MCP", "Toolset" ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-MCP-Toolset-LegacyMissing"
]

VerificationTest[
    dep[ "MCP", "ClientName" ],
    "ClaudeDesktop",
    TestID -> "AgentToolsDeployment-Property-MCP-ClientName"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Unknown Property*)
VerificationTest[
    dep[ "NonexistentProperty" ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Unknown"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Property*)
VerificationTest[
    dep[ 42 ],
    _Failure,
    { AgentToolsDeployment::InvalidProperty },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Invalid"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatting*)
VerificationTest[
    With[ { obj = AgentToolsDeployment[ $testDeploymentData ] },
        MakeBoxes[ obj, StandardForm ]
    ],
    _InterpretationBox,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Formatting-MakeBoxes"
]

VerificationTest[
    (* Invalid objects should not produce formatted boxes *)
    MakeBoxes[ AgentToolsDeployment[ <||> ], StandardForm ],
    _InterpretationBox,
    SameTest -> Not @* MatchQ,
    TestID   -> "AgentToolsDeployment-Formatting-InvalidNoBoxes"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Validation Edge Cases*)

(* Missing required keys *)
VerificationTest[
    AgentToolsDeployment[ <|
        "UUID"     -> "test-uuid",
        "Version"  -> 1,
        "MCP"      -> <||>
    |> ],
    _Failure,
    { AgentToolsDeployment::InvalidDeploymentData },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Validation-MissingKeys"
]

(* Wrong types for required keys *)
VerificationTest[
    AgentToolsDeployment[ <|
        "UUID"          -> 123,
        "Version"       -> 1,
        "Timestamp"     -> Now,
        "PacletVersion" -> "1.8.0",
        "CreatedBy"     -> "DeployAgentTools",
        "MCP"           -> <|
            "ClientName" -> "Test",
            "Target"     -> "Test",
            "Server"     -> "Test",
            "ConfigFile" -> File[ "/tmp/test.json" ],
            "Options"    -> <||>
        |>,
        "Skills"        -> <||>,
        "Hooks"         -> <||>,
        "Meta"          -> <||>
    |> ],
    _Failure,
    { AgentToolsDeployment::InvalidDeploymentData },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Validation-WrongUUIDType"
]

(* Valid with None ClientName *)
VerificationTest[
    AgentToolsDeployment[ <|
        "UUID"          -> CreateUUID[],
        "Version"       -> 1,
        "Timestamp"     -> Now,
        "PacletVersion" -> "1.8.0",
        "CreatedBy"     -> "DeployAgentTools",
        "MCP"           -> <|
            "ClientName" -> None,
            "Target"     -> File[ "/tmp/test.json" ],
            "Server"     -> "Wolfram",
            "ConfigFile" -> File[ "/tmp/test.json" ],
            "Options"    -> <||>
        |>,
        "Skills"        -> <||>,
        "Hooks"         -> <||>,
        "Meta"          -> <||>
    |> ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Validation-NoneClientName"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Multiple Objects*)
VerificationTest[
    dep1 = AgentToolsDeployment[ $testDeploymentData ];
    dep2 = AgentToolsDeployment[ $testDeploymentData ];
    dep1[ "UUID" ] =!= dep2[ "UUID" ],
    True,
    TestID -> "AgentToolsDeployment-MultipleObjects-UniqueUUIDs"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DeployAgentTools*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Setup*)
VerificationTest[
    $deployTestDir = CreateDirectory[ ];
    $deployTestConfig = File[ FileNameJoin @ { $deployTestDir, "test_mcp_config.json" } ];
    FileExistsQ @ $deployTestDir,
    True,
    TestID -> "DeployAgentTools-Setup"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Deployment*)
VerificationTest[
    $dep1 = withTestEnvironment @ DeployAgentTools[ $deployTestConfig, "Wolfram", "VerifyLLMKit" -> False ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-BasicDeploy"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Returned Object Properties*)
VerificationTest[
    $dep1[ "Server" ],
    "Wolfram",
    TestID -> "DeployAgentTools-Property-Server"
]

(* New deployments expose the canonical Toolset property *)
VerificationTest[
    $dep1[ "Toolset" ],
    "Wolfram",
    TestID -> "DeployAgentTools-Property-Toolset"
]

(* Legacy MCP/Server is still dual-written for backward compatibility *)
VerificationTest[
    $dep1[ "MCP", "Server" ],
    "Wolfram",
    TestID -> "DeployAgentTools-Property-MCP-Server"
]

VerificationTest[
    $dep1[ "Data" ][ "Toolset" ],
    "Wolfram",
    TestID -> "DeployAgentTools-Data-Toolset"
]

VerificationTest[
    $dep1[ "ConfigFile" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-ConfigFile"
]

VerificationTest[
    $dep1[ "UUID" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-UUID"
]

VerificationTest[
    $dep1[ "Timestamp" ],
    _DateObject,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-Timestamp"
]

VerificationTest[
    $dep1[ "CreatedBy" ],
    "DeployAgentTools",
    TestID -> "DeployAgentTools-Property-CreatedBy"
]

VerificationTest[
    $dep1[ "PacletVersion" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-PacletVersion"
]

VerificationTest[
    $dep1[ "Target" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-Target"
]

VerificationTest[
    $dep1[ "MCP" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-MCP"
]

VerificationTest[
    $dep1[ "MCP", "Options" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-MCP-Options"
]

VerificationTest[
    $dep1[ "MCPServerObject" ],
    _MCPServerObject,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-MCPServerObject"
]

VerificationTest[
    $dep1[ "Tools" ],
    { __LLMTool },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-Tools"
]

VerificationTest[
    $dep1[ "LLMConfiguration" ],
    _LLMConfiguration,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-LLMConfiguration"
]

VerificationTest[
    $dep1[ "Scope" ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-Scope-FileTarget"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config File Updated*)
VerificationTest[
    FileExistsQ @ $deployTestConfig,
    True,
    TestID -> "DeployAgentTools-ConfigFileExists"
]

VerificationTest[
    Module[ { json },
        json = Developer`ReadRawJSONString @ ReadString @ First @ $deployTestConfig;
        KeyExistsQ[ json, "mcpServers" ] && KeyExistsQ[ json[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    TestID -> "DeployAgentTools-ConfigFileHasServerEntry"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Deployment Record on Disk*)
VerificationTest[
    withTestEnvironment @ $dep1[ "Location" ],
    _File? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-DeploymentDirExists"
]

VerificationTest[
    withTestEnvironment @ FileExistsQ @ FileNameJoin @ { First @ $dep1[ "Location" ], "Deployment.wxf" },
    True,
    TestID -> "DeployAgentTools-DeploymentWXFExists"
]

(* Verify the persisted WXF contains the top-level Toolset and keeps legacy MCP/Server *)
VerificationTest[
    Module[ { data },
        data = Developer`ReadWXFFile @ FileNameJoin @ { First @ withTestEnvironment @ $dep1[ "Location" ], "Deployment.wxf" };
        {
            data[ "Toolset" ],
            data[ "MCP", "Server" ]
        }
    ],
    { "Wolfram", "Wolfram" },
    TestID -> "DeployAgentTools-DeploymentWXF-DualWrite"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UUID Lookup*)
VerificationTest[
    $dep1Lookup = withTestEnvironment @ AgentToolsDeployment[ $dep1[ "UUID" ] ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-UUIDLookup"
]

VerificationTest[
    $dep1Lookup[ "UUID" ] === $dep1[ "UUID" ],
    True,
    TestID -> "AgentToolsDeployment-UUIDLookup-SameUUID"
]

VerificationTest[
    $dep1Lookup[ "Server" ] === $dep1[ "Server" ],
    True,
    TestID -> "AgentToolsDeployment-UUIDLookup-SameServer"
]

VerificationTest[
    withTestEnvironment @ AgentToolsDeployment[ "nonexistent-uuid-00000000" ],
    _Failure,
    { AgentToolsDeployment::DeploymentNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-UUIDLookup-NotFound"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Project Directory*)
VerificationTest[
    withTestEnvironment @ DeployAgentTools[ { "ClaudeCode", Symbol[ "xyz" ] } ],
    _Failure,
    { DeployAgentTools::InvalidProjectDirectory },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidProjectDirectory"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Deploy Target*)
VerificationTest[
    withTestEnvironment @ DeployAgentTools[ 123, "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::InvalidDeployTarget },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidDeployTarget-Integer"
]

VerificationTest[
    withTestEnvironment @ DeployAgentTools[ <|"a" -> 1|>, "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::InvalidDeployTarget },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidDeployTarget-Association"
]

VerificationTest[
    withTestEnvironment @ DeployAgentTools[ {1, 2, 3}, "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::InvalidDeployTarget },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidDeployTarget-List"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid ApplicationName with File Target*)
VerificationTest[
    withTestEnvironment @ DeployAgentTools[
        File[ FileNameJoin @ { $deployTestDir, "appname_test.json" } ],
        "Wolfram",
        ApplicationName -> 123,
        "VerifyLLMKit"  -> False
    ],
    _Failure,
    { DeployAgentTools::InvalidApplicationName },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidApplicationName-Integer"
]

VerificationTest[
    withTestEnvironment @ DeployAgentTools[
        File[ FileNameJoin @ { $deployTestDir, "appname_test.json" } ],
        "Wolfram",
        ApplicationName -> { "foo" },
        "VerifyLLMKit"  -> False
    ],
    _Failure,
    { DeployAgentTools::InvalidApplicationName },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidApplicationName-List"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*OverwriteTarget -> False Fails*)
VerificationTest[
    withTestEnvironment @ DeployAgentTools[ $deployTestConfig, "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::DeploymentExists },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-DuplicateFails"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*OverwriteTarget -> True Replaces*)
VerificationTest[
    $dep2 = withTestEnvironment @ DeployAgentTools[
        $deployTestConfig,
        "Wolfram",
        OverwriteTarget  -> True,
        "VerifyLLMKit"   -> False
    ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-OverwriteTrue"
]

VerificationTest[
    $dep2[ "UUID" ] =!= $dep1[ "UUID" ],
    True,
    TestID -> "DeployAgentTools-OverwriteNewUUID"
]

VerificationTest[
    (* The old deployment directory should have been cleaned up *)
    ! DirectoryQ @ First @ withTestEnvironment @ $dep1[ "Location" ],
    True,
    TestID -> "DeployAgentTools-OverwriteOldDirRemoved"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Equivalent Target Forms*)
VerificationTest[
    $deployTestDir2 = CreateDirectory[ ];
    $dep3 = withTestEnvironment @ DeployAgentTools[
        { "ClaudeCode", $deployTestDir2 },
        "Wolfram",
        "VerifyLLMKit" -> False
    ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-ProjectDeploy"
]

VerificationTest[
    $dep3[ "ClientName" ],
    "ClaudeCode",
    TestID -> "DeployAgentTools-ProjectDeploy-ClientName"
]

VerificationTest[
    $dep3[ "Target" ],
    { "ClaudeCode", File[ $deployTestDir2 ] },
    TestID -> "DeployAgentTools-ProjectDeploy-Target"
]

VerificationTest[
    $dep3[ "Scope" ],
    File[ $deployTestDir2 ],
    TestID -> "DeployAgentTools-ProjectDeploy-Scope"
]

VerificationTest[
    (* Deploy to the same config file via File target - should fail as duplicate *)
    withTestEnvironment @ DeployAgentTools[
        File[ FileNameJoin @ { $deployTestDir2, ".mcp.json" } ],
        "Wolfram",
        "VerifyLLMKit" -> False
    ],
    _Failure,
    { DeployAgentTools::DeploymentExists },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-EquivalentTargetFails"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DeployedAgentTools*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*List All Deployments*)
VerificationTest[
    $allDeps = withTestEnvironment @ DeployedAgentTools[ ],
    _List,
    SameTest -> MatchQ,
    TestID   -> "DeployedAgentTools-ListAll"
]

VerificationTest[
    AllTrue[ $allDeps, agentToolsDeploymentQ ],
    True,
    TestID -> "DeployedAgentTools-ListAll-AllValid"
]

VerificationTest[
    (* The two existing deployments ($dep2 and $dep3) should be in the list *)
    MemberQ[ $allDeps, _? (configFilesEqual[ #[ "ConfigFile" ], $dep2[ "ConfigFile" ] ] &) ] &&
    MemberQ[ $allDeps, _? (configFilesEqual[ #[ "ConfigFile" ], $dep3[ "ConfigFile" ] ] &) ],
    True,
    TestID -> "DeployedAgentTools-ListAll-ContainsDeployments"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Filter By Client Name*)
VerificationTest[
    $ccDeps = withTestEnvironment @ DeployedAgentTools[ "ClaudeCode" ],
    _List,
    SameTest -> MatchQ,
    TestID   -> "DeployedAgentTools-FilterClaudeCode"
]

VerificationTest[
    MemberQ[ $ccDeps, _? (#[ "UUID" ] === $dep3[ "UUID" ] &) ],
    True,
    TestID -> "DeployedAgentTools-FilterClaudeCode-ContainsDep3"
]

VerificationTest[
    (* $dep2 is a File target - should NOT be in the ClaudeCode list *)
    NoneTrue[ $ccDeps, #[ "UUID" ] === $dep2[ "UUID" ] & ],
    True,
    TestID -> "DeployedAgentTools-FilterClaudeCode-ExcludesDep2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Alias Resolution*)
VerificationTest[
    (* "Claude" is an alias for "ClaudeDesktop" - should return the same result *)
    withTestEnvironment[ DeployedAgentTools[ "Claude" ] === DeployedAgentTools[ "ClaudeDesktop" ] ],
    True,
    TestID -> "DeployedAgentTools-AliasResolution"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Non-Existent Client*)
VerificationTest[
    withTestEnvironment @ DeployedAgentTools[ "NonExistentClient" ],
    { },
    TestID -> "DeployedAgentTools-NonExistentClient"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Empty Deployments Path*)
VerificationTest[
    (* With no deployments directory at all, should return empty list *)
    Block[ { Wolfram`AgentTools`Common`$deploymentsPath = FileNameJoin @ { $TemporaryDirectory, "nonexistent_deployments_" <> CreateUUID[ ] } },
        DeployedAgentTools[ ]
    ],
    { },
    TestID -> "DeployedAgentTools-EmptyPath"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Corrupted Records Filtered Out*)
VerificationTest[
    withTestEnvironment @ Module[ { corruptDir, corruptFile },
        (* Create a corrupted deployment record *)
        corruptDir = FileNameJoin @ {
            $deploymentsPath,
            $dep3[ "ClientName" ],
            "corrupted-" <> CreateUUID[ ]
        };
        CreateDirectory[ corruptDir ];
        corruptFile = FileNameJoin @ { corruptDir, "Deployment.wxf" };
        BinaryWrite[ corruptFile, "not valid wxf data" ];
        Close @ corruptFile;
        (* Should still return valid deployments, skipping the corrupted one *)
        $ccDeps2 = DeployedAgentTools[ "ClaudeCode" ];
        Quiet @ DeleteDirectory[ corruptDir, DeleteContents -> True ];
        AllTrue[ $ccDeps2, agentToolsDeploymentQ ]
    ],
    True,
    TestID -> "DeployedAgentTools-CorruptedRecordFiltered"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DeleteObject End-to-End*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Setup*)
VerificationTest[
    $deleteTestDir = CreateDirectory[ ];
    $deleteTestConfig = File[ FileNameJoin @ { $deleteTestDir, "delete_test_config.json" } ];
    $deleteDep = withTestEnvironment @ DeployAgentTools[ $deleteTestConfig, "Wolfram", "VerifyLLMKit" -> False ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "DeleteObject-Setup-Deploy"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Verify Pre-Delete State*)
VerificationTest[
    (* Config file should have the server entry *)
    Module[ { json },
        json = Developer`ReadRawJSONString @ ReadString @ First @ $deleteTestConfig;
        KeyExistsQ[ json, "mcpServers" ] && KeyExistsQ[ json[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    TestID -> "DeleteObject-ConfigHasEntry"
]

VerificationTest[
    $deleteDepDir = withTestEnvironment @ $deleteDep[ "Location" ];
    DirectoryQ @ $deleteDepDir,
    True,
    TestID -> "DeleteObject-DeploymentDirExists"
]

VerificationTest[
    MemberQ[ withTestEnvironment @ DeployedAgentTools[ ], _? (#[ "UUID" ] === $deleteDep[ "UUID" ] &) ],
    True,
    TestID -> "DeleteObject-InListing"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Delete*)
VerificationTest[
    withTestEnvironment @ DeleteObject[ $deleteDep ],
    Null,
    TestID -> "DeleteObject-Delete"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Verify Post-Delete State*)
VerificationTest[
    (* Config file should no longer have the server entry *)
    Module[ { json },
        json = Developer`ReadRawJSONString @ ReadString @ First @ $deleteTestConfig;
        ! KeyExistsQ[ json[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    TestID -> "DeleteObject-ConfigEntryRemoved"
]

VerificationTest[
    ! DirectoryQ @ $deleteDepDir,
    True,
    TestID -> "DeleteObject-DeploymentDirRemoved"
]

VerificationTest[
    NoneTrue[ withTestEnvironment @ DeployedAgentTools[ ], #[ "UUID" ] === $deleteDep[ "UUID" ] & ],
    True,
    TestID -> "DeleteObject-NotInListing"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Delete Again Fails*)
VerificationTest[
    withTestEnvironment @ DeleteObject[ $deleteDep ],
    _Failure,
    { AgentToolsDeployment::DeploymentNotFound },
    SameTest -> MatchQ,
    TestID   -> "DeleteObject-DeleteAgainFails"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Round-Trip: Deploy -> List -> Delete -> Verify Gone*)
VerificationTest[
    withTestEnvironment @ Module[ { dir, config, dep, uuid, listed, listedAfter, json },
        dir = CreateDirectory[ ];
        config = File[ FileNameJoin @ { dir, "roundtrip_config.json" } ];

        (* Deploy *)
        dep = DeployAgentTools[ config, "Wolfram", "VerifyLLMKit" -> False ];
        uuid = dep[ "UUID" ];

        (* Verify in listing *)
        listed = DeployedAgentTools[ ];
        If[ ! MemberQ[ listed, _? (#[ "UUID" ] === uuid &) ],
            Quiet @ DeleteDirectory[ dir, DeleteContents -> True ];
            Return[ False, Module ]
        ];

        (* Delete *)
        DeleteObject[ dep ];

        (* Verify gone from listing *)
        listedAfter = DeployedAgentTools[ ];
        If[ MemberQ[ listedAfter, _? (#[ "UUID" ] === uuid &) ],
            Quiet @ DeleteDirectory[ dir, DeleteContents -> True ];
            Return[ False, Module ]
        ];

        (* Verify config entry removed *)
        json = Developer`ReadRawJSONString @ ReadString @ First @ config;
        Quiet @ DeleteDirectory[ dir, DeleteContents -> True ];
        ! KeyExistsQ[ json[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    TestID -> "DeleteObject-RoundTrip"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet @ DeleteDirectory[ $deleteTestDir, DeleteContents -> True ];
    True,
    True,
    TestID -> "DeleteObject-Cleanup"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet[
        withTestEnvironment @ catchAlways @ DeleteObject @ $dep2;
        withTestEnvironment @ catchAlways @ DeleteObject @ $dep3;
        Quiet @ DeleteDirectory[ $deployTestDir, DeleteContents -> True ];
        Quiet @ DeleteDirectory[ $deployTestDir2, DeleteContents -> True ];
    ];
    True,
    True,
    TestID -> "DeployAgentTools-Cleanup"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Automatic toolset resolution (per-client DefaultToolset)*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DeployAgentTools with Automatic resolution*)
VerificationTest[
    autoDeployDir = CreateDirectory[ ];
    autoDeployAuto = withTestEnvironment @ DeployAgentTools[
        { "ClaudeCode", autoDeployDir },
        Automatic,
        "VerifyLLMKit" -> False
    ];
    autoDeployAuto[ "Toolset" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DeployAgentTools-Automatic-ClaudeCode"
]

VerificationTest[
    autoDeployAutoUUID = autoDeployAuto[ "UUID" ];
    withTestEnvironment @ Quiet @ catchAlways @ DeleteObject @ autoDeployAuto;
    Quiet @ DeleteDirectory[ autoDeployDir, DeleteContents -> True ];
    autoDeployDir = CreateDirectory[ ];
    autoDeploy1Arg = withTestEnvironment @ DeployAgentTools[
        { "ClaudeCode", autoDeployDir },
        "VerifyLLMKit" -> False
    ];
    autoDeploy1Arg[ "Toolset" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DeployAgentTools-1Arg-ClaudeCode"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DeployAgentTools Automatic with File target + ApplicationName*)
(* For arbitrary File[...] targets, an explicit ApplicationName option must
   drive the Automatic toolset choice instead of falling through to "Wolfram". *)
VerificationTest[
    withTestEnvironment @ Quiet @ catchAlways @ DeleteObject @ autoDeploy1Arg;
    Quiet @ DeleteDirectory[ autoDeployDir, DeleteContents -> True ];
    autoDeployDir = CreateDirectory[ ];
    autoDeployFile = File @ FileNameJoin @ { autoDeployDir, "custom_config_" <> CreateUUID[ ] <> ".json" };
    autoDeployFileApp = withTestEnvironment @ DeployAgentTools[
        autoDeployFile,
        Automatic,
        "ApplicationName" -> "Cline",
        "VerifyLLMKit"    -> False
    ];
    autoDeployFileApp[ "Toolset" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DeployAgentTools-Automatic-File-AppName-Cline"
]

VerificationTest[
    withTestEnvironment @ Quiet @ catchAlways @ DeleteObject @ autoDeployFileApp;
    Quiet @ DeleteDirectory[ autoDeployDir, DeleteContents -> True ];
    autoDeployDir = CreateDirectory[ ];
    autoDeployFile = File @ FileNameJoin @ { autoDeployDir, "custom_config_" <> CreateUUID[ ] <> ".json" };
    autoDeployFileChat = withTestEnvironment @ DeployAgentTools[
        autoDeployFile,
        Automatic,
        "ApplicationName" -> "ClaudeDesktop",
        "VerifyLLMKit"    -> False
    ];
    autoDeployFileChat[ "Toolset" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DeployAgentTools-Automatic-File-AppName-ClaudeDesktop"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DeployAgentTools Automatic with recognizable File target (no ApplicationName)*)
(* When the File[...] path itself identifies a known client, Automatic must
   pick up that client's DefaultToolset without needing an explicit
   "ApplicationName" option.  These guard against regressions where
   path-based detection silently drops back to "Wolfram". *)

(* .mcp.json -> ClaudeCode -> "WolframLanguage" *)
VerificationTest[
    withTestEnvironment @ Quiet @ catchAlways @ DeleteObject @ autoDeployFileChat;
    Quiet @ DeleteDirectory[ autoDeployDir, DeleteContents -> True ];
    autoDeployDir = CreateDirectory[ ];
    autoDeployFile = File @ FileNameJoin @ { autoDeployDir, ".mcp.json" };
    autoDeployFilePath = withTestEnvironment @ DeployAgentTools[
        autoDeployFile,
        Automatic,
        "VerifyLLMKit" -> False
    ];
    autoDeployFilePath[ "Toolset" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DeployAgentTools-Automatic-File-ClaudeCodeProject"
]

(* .vscode/mcp.json -> VisualStudioCode -> "WolframLanguage" *)
VerificationTest[
    withTestEnvironment @ Quiet @ catchAlways @ DeleteObject @ autoDeployFilePath;
    Quiet @ DeleteDirectory[ autoDeployDir, DeleteContents -> True ];
    autoDeployDir = CreateDirectory[ ];
    CreateDirectory @ FileNameJoin @ { autoDeployDir, ".vscode" };
    autoDeployFile = File @ FileNameJoin @ { autoDeployDir, ".vscode", "mcp.json" };
    autoDeployFileVSCode = withTestEnvironment @ DeployAgentTools[
        autoDeployFile,
        Automatic,
        "VerifyLLMKit" -> False
    ];
    autoDeployFileVSCode[ "Toolset" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DeployAgentTools-Automatic-File-VSCodeProject"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    withTestEnvironment @ Quiet @ catchAlways @ DeleteObject @ autoDeployFileVSCode;
    Quiet @ DeleteDirectory[ autoDeployDir, DeleteContents -> True ];
    True,
    True,
    TestID -> "DeployAgentTools-Automatic-Cleanup"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DeployAgentTools[All, ...]*)
(* These tests redirect $HomeDirectory and $deploymentsPath so that real client
   config files on the test machine are not touched, and pin
   $SupportedMCPClients to a small set of clients that have valid install
   locations on the current operating system. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Setup*)
VerificationTest[
    $allTestTmpHome    = CreateDirectory[ ];
    $allTestDeployPath = FileNameJoin @ { $allTestTmpHome, ".deployments" };
    $allTestClients    = KeyTake[
        Wolfram`AgentTools`$SupportedMCPClients,
        { "Cursor", "ClaudeCode" }
    ];
    Length @ $allTestClients,
    2,
    TestID -> "DeployAgentTools-All-Setup"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Result Shape*)
VerificationTest[
    $allDep1 = Block[
        {
            Wolfram`AgentTools`$SupportedClients    = $allTestClients,
            Wolfram`AgentTools`$SupportedMCPClients = $allTestClients,
            $HomeDirectory                          = $allTestTmpHome,
            Wolfram`AgentTools`Common`$deploymentsPath = $allTestDeployPath
        },
        DeployAgentTools[ All, "VerifyLLMKit" -> False ]
    ],
    { _AgentToolsDeployment, _AgentToolsDeployment },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-All-BasicResultShape"
]

VerificationTest[
    Length @ $allDep1,
    Length @ $allTestClients,
    TestID -> "DeployAgentTools-All-LengthMatchesClients"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Per-Client DefaultToolset (Automatic Server)*)
(* With server = Automatic (the default), each deployment should pick up its
   client's "DefaultToolset" from $SupportedMCPClients.  Both Cursor and
   ClaudeCode are coding clients -> "WolframLanguage". *)
VerificationTest[
    Sort @ Map[ #[ "Toolset" ] &, $allDep1 ],
    { "WolframLanguage", "WolframLanguage" },
    TestID -> "DeployAgentTools-All-AutomaticToolsetPerClient"
]

VerificationTest[
    Sort @ Map[ #[ "ClientName" ] &, $allDep1 ],
    Sort @ Keys @ $allTestClients,
    TestID -> "DeployAgentTools-All-CoversEveryClient"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Re-Deploy Without Overwrite Returns Missing Entries*)
VerificationTest[
    $allDep2 = Block[
        {
            Wolfram`AgentTools`$SupportedClients    = $allTestClients,
            Wolfram`AgentTools`$SupportedMCPClients = $allTestClients,
            $HomeDirectory                          = $allTestTmpHome,
            Wolfram`AgentTools`Common`$deploymentsPath = $allTestDeployPath
        },
        Quiet[
            DeployAgentTools[ All, "VerifyLLMKit" -> False ],
            { DeployAgentTools::DeploymentsExistWarning }
        ]
    ],
    { Missing[ "DeploymentExists", _ ], Missing[ "DeploymentExists", _ ] },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-All-MissingDeploymentExistsEntries"
]

VerificationTest[
    Sort @ Map[ #[[ 2 ]] &, $allDep2 ],
    Sort @ Keys @ $allTestClients,
    TestID -> "DeployAgentTools-All-MissingTargetsAreClientNames"
]

(* The DeploymentsExistWarning message should be issued when at least one
   client is skipped due to an existing deployment. *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`$SupportedClients    = $allTestClients,
            Wolfram`AgentTools`$SupportedMCPClients = $allTestClients,
            $HomeDirectory                          = $allTestTmpHome,
            Wolfram`AgentTools`Common`$deploymentsPath = $allTestDeployPath
        },
        DeployAgentTools[ All, "VerifyLLMKit" -> False ]
    ],
    _List,
    { DeployAgentTools::DeploymentsExistWarning },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-All-WarningMessageIssued"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*OverwriteTarget -> True Replaces Every Deployment*)
VerificationTest[
    $allDep1UUIDs = Sort @ Map[ #[ "UUID" ] &, $allDep1 ];
    $allDep3 = Block[
        {
            Wolfram`AgentTools`$SupportedClients    = $allTestClients,
            Wolfram`AgentTools`$SupportedMCPClients = $allTestClients,
            $HomeDirectory                          = $allTestTmpHome,
            Wolfram`AgentTools`Common`$deploymentsPath = $allTestDeployPath
        },
        DeployAgentTools[ All, OverwriteTarget -> True, "VerifyLLMKit" -> False ]
    ],
    { _AgentToolsDeployment, _AgentToolsDeployment },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-All-OverwriteShape"
]

VerificationTest[
    (* All UUIDs in the new result should be different from the originals *)
    Intersection[ Sort @ Map[ #[ "UUID" ] &, $allDep3 ], $allDep1UUIDs ],
    { },
    TestID -> "DeployAgentTools-All-OverwriteNewUUIDs"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Explicit Server Argument*)
(* DeployAgentTools[All, server, ...] should use the given server for every
   client instead of falling back to per-client DefaultToolset. *)
VerificationTest[
    $allDep4 = Block[
        {
            Wolfram`AgentTools`$SupportedClients    = $allTestClients,
            Wolfram`AgentTools`$SupportedMCPClients = $allTestClients,
            $HomeDirectory                          = $allTestTmpHome,
            Wolfram`AgentTools`Common`$deploymentsPath = $allTestDeployPath
        },
        DeployAgentTools[
            All,
            "Wolfram",
            OverwriteTarget -> True,
            "VerifyLLMKit"  -> False
        ]
    ],
    { _AgentToolsDeployment, _AgentToolsDeployment },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-All-ExplicitServerShape"
]

VerificationTest[
    Sort @ DeleteDuplicates @ Map[ #[ "Toolset" ] &, $allDep4 ],
    { "Wolfram" },
    TestID -> "DeployAgentTools-All-ExplicitServerOverridesDefault"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*1-Argument Form Defaults to Automatic*)
(* DeployAgentTools[All] (no server argument) should be equivalent to
   DeployAgentTools[All, Automatic, ...].  Use a fresh deployments path so
   nothing already exists. *)
VerificationTest[
    $allDep5Path = FileNameJoin @ { $allTestTmpHome, ".deployments_1arg" };
    $allDep5 = Block[
        {
            Wolfram`AgentTools`$SupportedClients    = $allTestClients,
            Wolfram`AgentTools`$SupportedMCPClients = $allTestClients,
            $HomeDirectory                          = $allTestTmpHome,
            Wolfram`AgentTools`Common`$deploymentsPath = $allDep5Path
        },
        (* Use OverwriteTarget so we don't conflict with the configs already
           written under $allTestTmpHome by earlier tests. *)
        DeployAgentTools[ All, OverwriteTarget -> True, "VerifyLLMKit" -> False ]
    ],
    { _AgentToolsDeployment, _AgentToolsDeployment },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-All-1ArgForm"
]

VerificationTest[
    (* 1-arg form falls through to per-client DefaultToolset, like Automatic *)
    Sort @ DeleteDuplicates @ Map[ #[ "Toolset" ] &, $allDep5 ],
    { "WolframLanguage" },
    TestID -> "DeployAgentTools-All-1ArgFormUsesDefaultToolset"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveServerForClient Helper*)
(* Unit tests for the per-client server resolver used by deployAllAgentTools.
   When server is Automatic, each client's own DefaultToolset is used; an
   explicit server passes through. *)
VerificationTest[
    resolveServerForClient = Wolfram`AgentTools`DeployAgentTools`Private`resolveServerForClient;
    resolveServerForClient[ "Cursor", Automatic ],
    "WolframLanguage",
    TestID -> "DeployAgentTools-All-resolveServerForClient-CursorAutomatic"
]

VerificationTest[
    resolveServerForClient[ "ClaudeDesktop", Automatic ],
    "Wolfram",
    TestID -> "DeployAgentTools-All-resolveServerForClient-ClaudeDesktopAutomatic"
]

VerificationTest[
    resolveServerForClient[ "Cursor", "Wolfram" ],
    "Wolfram",
    TestID -> "DeployAgentTools-All-resolveServerForClient-ExplicitPassthrough"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ApplicationName Doesn't Override Per-Client Default*)
(* When server is Automatic, an explicit "ApplicationName" option must not
   override each client's own DefaultToolset.  Without the resolveServerForClient
   indirection, DeployAgentTools[target, Automatic, opts] gives ApplicationName
   precedence over target-based resolution, which would silently rewrite every
   client's toolset to whatever ApplicationName resolves to. *)
VerificationTest[
    $allDepAppName = Block[
        {
            Wolfram`AgentTools`$SupportedClients       = $allTestClients,
            Wolfram`AgentTools`$SupportedMCPClients    = $allTestClients,
            $HomeDirectory                             = $allTestTmpHome,
            Wolfram`AgentTools`Common`$deploymentsPath =
                FileNameJoin @ { $allTestTmpHome, ".deployments_appname" }
        },
        DeployAgentTools[
            All,
            "VerifyLLMKit"    -> False,
            "ApplicationName" -> "ClaudeDesktop"
        ]
    ],
    { _AgentToolsDeployment, _AgentToolsDeployment },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-All-ApplicationName-Setup"
]

VerificationTest[
    (* ClaudeDesktop's DefaultToolset is "Wolfram"; if ApplicationName were
       being honored as the default-toolset selector, both deployments would
       come back as "Wolfram".  Both Cursor and ClaudeCode are coding clients,
       so the correct result is "WolframLanguage" for both. *)
    Sort @ DeleteDuplicates @ Map[ #[ "Toolset" ] &, $allDepAppName ],
    { "WolframLanguage" },
    TestID -> "DeployAgentTools-All-ApplicationName-PerClientDefault"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Unsupported Clients Return Missing["Unsupported", ...]*)
(* Clients without an InstallLocation entry for the current operating system
   should be reported as Missing["Unsupported", {client, $OperatingSystem}]
   rather than failing the entire DeployAgentTools[All, ...] call. *)

(* Synthetic client whose InstallLocation never matches any real OS *)
$alwaysUnsupportedEntry = <|
    "Aliases"         -> { },
    "ConfigFormat"    -> "JSON",
    "ConfigKey"       -> { "mcpServers" },
    "DefaultToolset"  -> "WolframLanguage",
    "DisplayName"     -> "Always Unsupported Test Client",
    "InstallLocation" -> <| "DefinitelyNotARealOS" :> { "/never/used" } |>,
    "Name"            -> "AlwaysUnsupported",
    "ProjectSupport"  -> False,
    "ServerConverter" -> Identity,
    "URL"             -> "https://example.com"
|>;

VerificationTest[
    $allDepUnsupported = Block[
        {
            Wolfram`AgentTools`$SupportedClients       = <|
                KeyTake[ Wolfram`AgentTools`$SupportedClients, { "Cursor" } ],
                "AlwaysUnsupported" -> $alwaysUnsupportedEntry
            |>,
            Wolfram`AgentTools`$SupportedMCPClients    = <|
                KeyTake[ Wolfram`AgentTools`$SupportedMCPClients, { "Cursor" } ],
                "AlwaysUnsupported" -> $alwaysUnsupportedEntry
            |>,
            $HomeDirectory                             = $allTestTmpHome,
            Wolfram`AgentTools`Common`$deploymentsPath =
                FileNameJoin @ { $allTestTmpHome, ".deployments_unsupported" }
        },
        DeployAgentTools[ All, "VerifyLLMKit" -> False ]
    ],
    _List? (Length @ # === 2 &),
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-All-UnsupportedClientShape"
]

VerificationTest[
    Cases[ $allDepUnsupported, _Missing ],
    { Missing[ "Unsupported", { "AlwaysUnsupported", $OperatingSystem } ] },
    TestID -> "DeployAgentTools-All-UnsupportedClientPayload"
]

VerificationTest[
    Length @ Cases[ $allDepUnsupported, _AgentToolsDeployment ],
    1,
    TestID -> "DeployAgentTools-All-UnsupportedClientStillDeploysSupported"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DeploymentsExistWarning Only Fires for DeploymentExists*)
(* When only unsupported clients are skipped (no DeploymentExists entries),
   AgentTools::DeploymentsExistWarning must NOT be issued. *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`$SupportedClients       = <|
                "AlwaysUnsupported" -> $alwaysUnsupportedEntry
            |>,
            Wolfram`AgentTools`$SupportedMCPClients    = <|
                "AlwaysUnsupported" -> $alwaysUnsupportedEntry
            |>,
            $HomeDirectory                             = $allTestTmpHome,
            Wolfram`AgentTools`Common`$deploymentsPath =
                FileNameJoin @ { $allTestTmpHome, ".deployments_unsupported_only" }
        },
        DeployAgentTools[ All, "VerifyLLMKit" -> False ]
    ],
    { Missing[ "Unsupported", { "AlwaysUnsupported", $OperatingSystem } ] },
    { },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-All-NoWarningForUnsupportedOnly"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet @ DeleteDirectory[ $allTestTmpHome, DeleteContents -> True ];
    True,
    True,
    TestID -> "DeployAgentTools-All-Cleanup"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Test Environment Cleanup*)
(* Every deployment made in the temporary environment was deleted, including its agent skills *)
VerificationTest[
    withTestEnvironment @ {
        DeployedAgentTools[ ],
        If[ DirectoryQ @ Wolfram`AgentTools`Common`$skillRegistryPath,
            FileNames[ "*.wxf", Wolfram`AgentTools`Common`$skillRegistryPath ],
            { }
        ]
    },
    { { }, { } },
    TestID -> "DeployAgentTools-TestEnvironment-NothingLeft"
]

VerificationTest[
    Quiet @ Scan[ DeleteDirectory[ #, DeleteContents -> True ] &, { $testRoot, $testHome } ];
    { DirectoryQ @ $testRoot, DirectoryQ @ $testHome },
    { False, False },
    TestID -> "DeployAgentTools-TestEnvironment-Cleanup"
]

(* :!CodeAnalysis::EndBlock:: *)
