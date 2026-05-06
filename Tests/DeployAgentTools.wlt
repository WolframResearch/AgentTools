(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/DeployAgentTools.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/DeployAgentTools.wlt:11,1-16,2"
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
$deploymentsPath = Wolfram`AgentTools`Common`$deploymentsPath;

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
    TestID   -> "AgentToolsDeployment-ValidConstruction@@Tests/DeployAgentTools.wlt:54,1-59,2"
]

VerificationTest[
    agentToolsDeploymentQ @ dep,
    True,
    TestID -> "AgentToolsDeployment-ValidQ@@Tests/DeployAgentTools.wlt:61,1-65,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Construction*)
VerificationTest[
    AgentToolsDeployment[ "not-a-real-uuid" ],
    _Failure,
    { AgentToolsDeployment::DeploymentNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-InvalidUUID@@Tests/DeployAgentTools.wlt:70,1-76,2"
]

VerificationTest[
    AgentToolsDeployment[ <|"UUID" -> "test"|> ],
    _Failure,
    { AgentToolsDeployment::InvalidDeploymentData },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-InvalidIncompleteData@@Tests/DeployAgentTools.wlt:78,1-84,2"
]

VerificationTest[
    AgentToolsDeployment[ <||> ],
    _Failure,
    { AgentToolsDeployment::InvalidDeploymentData },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-InvalidEmptyAssociation@@Tests/DeployAgentTools.wlt:86,1-92,2"
]

VerificationTest[
    Quiet @ agentToolsDeploymentQ @ AgentToolsDeployment[ <||> ],
    False,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-InvalidNotValidQ@@Tests/DeployAgentTools.wlt:94,1-99,2"
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
    TestID   -> "AgentToolsDeployment-Property-UUID@@Tests/DeployAgentTools.wlt:108,1-113,2"
]

VerificationTest[
    dep[ "Timestamp" ],
    _DateObject,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Timestamp@@Tests/DeployAgentTools.wlt:115,1-120,2"
]

VerificationTest[
    dep[ "PacletVersion" ],
    "1.8.0",
    TestID -> "AgentToolsDeployment-Property-PacletVersion@@Tests/DeployAgentTools.wlt:122,1-126,2"
]

VerificationTest[
    dep[ "CreatedBy" ],
    "DeployAgentTools",
    TestID -> "AgentToolsDeployment-Property-CreatedBy@@Tests/DeployAgentTools.wlt:128,1-132,2"
]

VerificationTest[
    dep[ "Version" ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Version-Missing@@Tests/DeployAgentTools.wlt:134,1-139,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCP Shortcut Properties*)
VerificationTest[
    dep[ "ClientName" ],
    "ClaudeDesktop",
    TestID -> "AgentToolsDeployment-Property-ClientName@@Tests/DeployAgentTools.wlt:144,1-148,2"
]

VerificationTest[
    dep[ "Target" ],
    "ClaudeDesktop",
    TestID -> "AgentToolsDeployment-Property-Target@@Tests/DeployAgentTools.wlt:150,1-154,2"
]

VerificationTest[
    dep[ "Server" ],
    "WolframLanguage",
    TestID -> "AgentToolsDeployment-Property-Server@@Tests/DeployAgentTools.wlt:156,1-160,2"
]

(* Legacy-shaped fixture: Toolset falls back through MCP/Server *)
VerificationTest[
    dep[ "Toolset" ],
    "WolframLanguage",
    TestID -> "AgentToolsDeployment-Property-Toolset-LegacyFallback@@Tests/DeployAgentTools.wlt:163,1-167,2"
]

VerificationTest[
    dep[ "ConfigFile" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-ConfigFile@@Tests/DeployAgentTools.wlt:169,1-174,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Sub-Association Properties*)
VerificationTest[
    dep[ "MCP" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-MCP@@Tests/DeployAgentTools.wlt:179,1-184,2"
]

VerificationTest[
    dep[ "Skills" ],
    <||>,
    TestID -> "AgentToolsDeployment-Property-Skills@@Tests/DeployAgentTools.wlt:186,1-190,2"
]

VerificationTest[
    dep[ "Hooks" ],
    <||>,
    TestID -> "AgentToolsDeployment-Property-Hooks@@Tests/DeployAgentTools.wlt:192,1-196,2"
]

VerificationTest[
    dep[ "Meta" ],
    <||>,
    TestID -> "AgentToolsDeployment-Property-Meta@@Tests/DeployAgentTools.wlt:198,1-202,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Derived Properties*)
VerificationTest[
    dep[ "Data" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Data@@Tests/DeployAgentTools.wlt:207,1-212,2"
]

VerificationTest[
    dep[ "Location" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Location@@Tests/DeployAgentTools.wlt:214,1-219,2"
]

VerificationTest[
    dep[ "Properties" ],
    _List,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Properties@@Tests/DeployAgentTools.wlt:221,1-226,2"
]

VerificationTest[
    MemberQ[ dep[ "Properties" ], "UUID" ],
    True,
    TestID -> "AgentToolsDeployment-Property-PropertiesContainsUUID@@Tests/DeployAgentTools.wlt:228,1-232,2"
]

VerificationTest[
    dep[ "MCPServerObject" ],
    _MCPServerObject,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-MCPServerObject@@Tests/DeployAgentTools.wlt:234,1-239,2"
]

VerificationTest[
    dep[ "Tools" ],
    { ___LLMTool },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Tools@@Tests/DeployAgentTools.wlt:241,1-246,2"
]

VerificationTest[
    dep[ "LLMConfiguration" ],
    _LLMConfiguration,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-LLMConfiguration@@Tests/DeployAgentTools.wlt:248,1-253,2"
]

VerificationTest[
    dep[ "Scope" ],
    "Global",
    TestID -> "AgentToolsDeployment-Property-Scope-Global@@Tests/DeployAgentTools.wlt:255,1-259,2"
]

VerificationTest[
    SubsetQ[ dep[ "Properties" ], { "MCPServerObject", "Tools", "LLMConfiguration" } ],
    True,
    TestID -> "AgentToolsDeployment-Property-PropertiesContainsNewDerived@@Tests/DeployAgentTools.wlt:261,1-265,2"
]

VerificationTest[
    MemberQ[ dep[ "Properties" ], "Toolset" ],
    True,
    TestID -> "AgentToolsDeployment-Property-PropertiesContainsToolset@@Tests/DeployAgentTools.wlt:267,1-271,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Two-Argument Property Access*)
VerificationTest[
    dep[ "MCP", "Options" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-MCP-Options@@Tests/DeployAgentTools.wlt:276,1-281,2"
]

VerificationTest[
    dep[ "MCP", "Server" ],
    "WolframLanguage",
    TestID -> "AgentToolsDeployment-Property-MCP-Server@@Tests/DeployAgentTools.wlt:283,1-287,2"
]

(* Legacy fixture doesn't have MCP/Toolset - verify the two-arg accessor reports missing *)
VerificationTest[
    dep[ "MCP", "Toolset" ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-MCP-Toolset-LegacyMissing@@Tests/DeployAgentTools.wlt:290,1-295,2"
]

VerificationTest[
    dep[ "MCP", "ClientName" ],
    "ClaudeDesktop",
    TestID -> "AgentToolsDeployment-Property-MCP-ClientName@@Tests/DeployAgentTools.wlt:297,1-301,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Unknown Property*)
VerificationTest[
    dep[ "NonexistentProperty" ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Unknown@@Tests/DeployAgentTools.wlt:306,1-311,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Property*)
VerificationTest[
    dep[ 42 ],
    _Failure,
    { AgentToolsDeployment::InvalidProperty },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Invalid@@Tests/DeployAgentTools.wlt:316,1-322,2"
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
    TestID   -> "AgentToolsDeployment-Formatting-MakeBoxes@@Tests/DeployAgentTools.wlt:327,1-334,2"
]

VerificationTest[
    (* Invalid objects should not produce formatted boxes *)
    MakeBoxes[ AgentToolsDeployment[ <||> ], StandardForm ],
    _InterpretationBox,
    SameTest -> Not @* MatchQ,
    TestID   -> "AgentToolsDeployment-Formatting-InvalidNoBoxes@@Tests/DeployAgentTools.wlt:336,1-342,2"
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
    TestID   -> "AgentToolsDeployment-Validation-MissingKeys@@Tests/DeployAgentTools.wlt:349,1-359,2"
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
    TestID   -> "AgentToolsDeployment-Validation-WrongUUIDType@@Tests/DeployAgentTools.wlt:362,1-384,2"
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
    TestID   -> "AgentToolsDeployment-Validation-NoneClientName@@Tests/DeployAgentTools.wlt:387,1-408,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Multiple Objects*)
VerificationTest[
    dep1 = AgentToolsDeployment[ $testDeploymentData ];
    dep2 = AgentToolsDeployment[ $testDeploymentData ];
    dep1[ "UUID" ] =!= dep2[ "UUID" ],
    True,
    TestID -> "AgentToolsDeployment-MultipleObjects-UniqueUUIDs@@Tests/DeployAgentTools.wlt:413,1-419,2"
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
    TestID -> "DeployAgentTools-Setup@@Tests/DeployAgentTools.wlt:428,1-434,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Deployment*)
VerificationTest[
    $dep1 = DeployAgentTools[ $deployTestConfig, "Wolfram", "VerifyLLMKit" -> False ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-BasicDeploy@@Tests/DeployAgentTools.wlt:439,1-444,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Returned Object Properties*)
VerificationTest[
    $dep1[ "Server" ],
    "Wolfram",
    TestID -> "DeployAgentTools-Property-Server@@Tests/DeployAgentTools.wlt:449,1-453,2"
]

(* New deployments expose the canonical Toolset property *)
VerificationTest[
    $dep1[ "Toolset" ],
    "Wolfram",
    TestID -> "DeployAgentTools-Property-Toolset@@Tests/DeployAgentTools.wlt:456,1-460,2"
]

(* Legacy MCP/Server is still dual-written for backward compatibility *)
VerificationTest[
    $dep1[ "MCP", "Server" ],
    "Wolfram",
    TestID -> "DeployAgentTools-Property-MCP-Server@@Tests/DeployAgentTools.wlt:463,1-467,2"
]

VerificationTest[
    $dep1[ "Data" ][ "Toolset" ],
    "Wolfram",
    TestID -> "DeployAgentTools-Data-Toolset@@Tests/DeployAgentTools.wlt:469,1-473,2"
]

VerificationTest[
    $dep1[ "ConfigFile" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-ConfigFile@@Tests/DeployAgentTools.wlt:475,1-480,2"
]

VerificationTest[
    $dep1[ "UUID" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-UUID@@Tests/DeployAgentTools.wlt:482,1-487,2"
]

VerificationTest[
    $dep1[ "Timestamp" ],
    _DateObject,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-Timestamp@@Tests/DeployAgentTools.wlt:489,1-494,2"
]

VerificationTest[
    $dep1[ "CreatedBy" ],
    "DeployAgentTools",
    TestID -> "DeployAgentTools-Property-CreatedBy@@Tests/DeployAgentTools.wlt:496,1-500,2"
]

VerificationTest[
    $dep1[ "PacletVersion" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-PacletVersion@@Tests/DeployAgentTools.wlt:502,1-507,2"
]

VerificationTest[
    $dep1[ "Target" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-Target@@Tests/DeployAgentTools.wlt:509,1-514,2"
]

VerificationTest[
    $dep1[ "MCP" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-MCP@@Tests/DeployAgentTools.wlt:516,1-521,2"
]

VerificationTest[
    $dep1[ "MCP", "Options" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-MCP-Options@@Tests/DeployAgentTools.wlt:523,1-528,2"
]

VerificationTest[
    $dep1[ "MCPServerObject" ],
    _MCPServerObject,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-MCPServerObject@@Tests/DeployAgentTools.wlt:530,1-535,2"
]

VerificationTest[
    $dep1[ "Tools" ],
    { __LLMTool },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-Tools@@Tests/DeployAgentTools.wlt:537,1-542,2"
]

VerificationTest[
    $dep1[ "LLMConfiguration" ],
    _LLMConfiguration,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-LLMConfiguration@@Tests/DeployAgentTools.wlt:544,1-549,2"
]

VerificationTest[
    $dep1[ "Scope" ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-Scope-FileTarget@@Tests/DeployAgentTools.wlt:551,1-556,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config File Updated*)
VerificationTest[
    FileExistsQ @ $deployTestConfig,
    True,
    TestID -> "DeployAgentTools-ConfigFileExists@@Tests/DeployAgentTools.wlt:561,1-565,2"
]

VerificationTest[
    Module[ { json },
        json = Developer`ReadRawJSONString @ ReadString @ First @ $deployTestConfig;
        KeyExistsQ[ json, "mcpServers" ] && KeyExistsQ[ json[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    TestID -> "DeployAgentTools-ConfigFileHasServerEntry@@Tests/DeployAgentTools.wlt:567,1-574,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Deployment Record on Disk*)
VerificationTest[
    $dep1[ "Location" ],
    _File? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-DeploymentDirExists@@Tests/DeployAgentTools.wlt:579,1-584,2"
]

VerificationTest[
    FileExistsQ @ FileNameJoin @ { First @ $dep1[ "Location" ], "Deployment.wxf" },
    True,
    TestID -> "DeployAgentTools-DeploymentWXFExists@@Tests/DeployAgentTools.wlt:586,1-590,2"
]

(* Verify the persisted WXF contains the top-level Toolset and keeps legacy MCP/Server *)
VerificationTest[
    Module[ { data },
        data = Developer`ReadWXFFile @ FileNameJoin @ { First @ $dep1[ "Location" ], "Deployment.wxf" };
        {
            data[ "Toolset" ],
            data[ "MCP", "Server" ]
        }
    ],
    { "Wolfram", "Wolfram" },
    TestID -> "DeployAgentTools-DeploymentWXF-DualWrite@@Tests/DeployAgentTools.wlt:593,1-603,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UUID Lookup*)
VerificationTest[
    $dep1Lookup = AgentToolsDeployment[ $dep1[ "UUID" ] ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-UUIDLookup@@Tests/DeployAgentTools.wlt:608,1-613,2"
]

VerificationTest[
    $dep1Lookup[ "UUID" ] === $dep1[ "UUID" ],
    True,
    TestID -> "AgentToolsDeployment-UUIDLookup-SameUUID@@Tests/DeployAgentTools.wlt:615,1-619,2"
]

VerificationTest[
    $dep1Lookup[ "Server" ] === $dep1[ "Server" ],
    True,
    TestID -> "AgentToolsDeployment-UUIDLookup-SameServer@@Tests/DeployAgentTools.wlt:621,1-625,2"
]

VerificationTest[
    AgentToolsDeployment[ "nonexistent-uuid-00000000" ],
    _Failure,
    { AgentToolsDeployment::DeploymentNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-UUIDLookup-NotFound@@Tests/DeployAgentTools.wlt:627,1-633,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Project Directory*)
VerificationTest[
    DeployAgentTools[ { "ClaudeCode", Symbol[ "xyz" ] } ],
    _Failure,
    { DeployAgentTools::InvalidProjectDirectory },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidProjectDirectory@@Tests/DeployAgentTools.wlt:638,1-644,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Deploy Target*)
VerificationTest[
    DeployAgentTools[ 123, "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::InvalidDeployTarget },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidDeployTarget-Integer@@Tests/DeployAgentTools.wlt:649,1-655,2"
]

VerificationTest[
    DeployAgentTools[ <|"a" -> 1|>, "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::InvalidDeployTarget },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidDeployTarget-Association@@Tests/DeployAgentTools.wlt:657,1-663,2"
]

VerificationTest[
    DeployAgentTools[ {1, 2, 3}, "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::InvalidDeployTarget },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidDeployTarget-List@@Tests/DeployAgentTools.wlt:665,1-671,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid ApplicationName with File Target*)
VerificationTest[
    DeployAgentTools[
        File[ FileNameJoin @ { $deployTestDir, "appname_test.json" } ],
        "Wolfram",
        ApplicationName -> 123,
        "VerifyLLMKit"  -> False
    ],
    _Failure,
    { DeployAgentTools::InvalidApplicationName },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidApplicationName-Integer@@Tests/DeployAgentTools.wlt:676,1-687,2"
]

VerificationTest[
    DeployAgentTools[
        File[ FileNameJoin @ { $deployTestDir, "appname_test.json" } ],
        "Wolfram",
        ApplicationName -> { "foo" },
        "VerifyLLMKit"  -> False
    ],
    _Failure,
    { DeployAgentTools::InvalidApplicationName },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidApplicationName-List@@Tests/DeployAgentTools.wlt:689,1-700,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*OverwriteTarget -> False Fails*)
VerificationTest[
    DeployAgentTools[ $deployTestConfig, "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::DeploymentExists },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-DuplicateFails@@Tests/DeployAgentTools.wlt:705,1-711,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*OverwriteTarget -> True Replaces*)
VerificationTest[
    $dep2 = DeployAgentTools[
        $deployTestConfig,
        "Wolfram",
        OverwriteTarget  -> True,
        "VerifyLLMKit"   -> False
    ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-OverwriteTrue@@Tests/DeployAgentTools.wlt:716,1-726,2"
]

VerificationTest[
    $dep2[ "UUID" ] =!= $dep1[ "UUID" ],
    True,
    TestID -> "DeployAgentTools-OverwriteNewUUID@@Tests/DeployAgentTools.wlt:728,1-732,2"
]

VerificationTest[
    (* The old deployment directory should have been cleaned up *)
    ! DirectoryQ @ First @ $dep1[ "Location" ],
    True,
    TestID -> "DeployAgentTools-OverwriteOldDirRemoved@@Tests/DeployAgentTools.wlt:734,1-739,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Equivalent Target Forms*)
VerificationTest[
    $deployTestDir2 = CreateDirectory[ ];
    $dep3 = DeployAgentTools[
        { "ClaudeCode", $deployTestDir2 },
        "Wolfram",
        "VerifyLLMKit" -> False
    ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-ProjectDeploy@@Tests/DeployAgentTools.wlt:744,1-754,2"
]

VerificationTest[
    $dep3[ "ClientName" ],
    "ClaudeCode",
    TestID -> "DeployAgentTools-ProjectDeploy-ClientName@@Tests/DeployAgentTools.wlt:756,1-760,2"
]

VerificationTest[
    $dep3[ "Target" ],
    { "ClaudeCode", File[ $deployTestDir2 ] },
    TestID -> "DeployAgentTools-ProjectDeploy-Target@@Tests/DeployAgentTools.wlt:762,1-766,2"
]

VerificationTest[
    $dep3[ "Scope" ],
    File[ $deployTestDir2 ],
    TestID -> "DeployAgentTools-ProjectDeploy-Scope@@Tests/DeployAgentTools.wlt:768,1-772,2"
]

VerificationTest[
    (* Deploy to the same config file via File target - should fail as duplicate *)
    DeployAgentTools[
        File[ FileNameJoin @ { $deployTestDir2, ".mcp.json" } ],
        "Wolfram",
        "VerifyLLMKit" -> False
    ],
    _Failure,
    { DeployAgentTools::DeploymentExists },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-EquivalentTargetFails@@Tests/DeployAgentTools.wlt:774,1-785,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DeployedAgentTools*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*List All Deployments*)
VerificationTest[
    $allDeps = DeployedAgentTools[ ],
    _List,
    SameTest -> MatchQ,
    TestID   -> "DeployedAgentTools-ListAll@@Tests/DeployAgentTools.wlt:794,1-799,2"
]

VerificationTest[
    AllTrue[ $allDeps, agentToolsDeploymentQ ],
    True,
    TestID -> "DeployedAgentTools-ListAll-AllValid@@Tests/DeployAgentTools.wlt:801,1-805,2"
]

VerificationTest[
    (* The two existing deployments ($dep2 and $dep3) should be in the list *)
    MemberQ[ $allDeps, _? (configFilesEqual[ #[ "ConfigFile" ], $dep2[ "ConfigFile" ] ] &) ] &&
    MemberQ[ $allDeps, _? (configFilesEqual[ #[ "ConfigFile" ], $dep3[ "ConfigFile" ] ] &) ],
    True,
    TestID -> "DeployedAgentTools-ListAll-ContainsDeployments@@Tests/DeployAgentTools.wlt:807,1-813,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Filter By Client Name*)
VerificationTest[
    $ccDeps = DeployedAgentTools[ "ClaudeCode" ],
    _List,
    SameTest -> MatchQ,
    TestID   -> "DeployedAgentTools-FilterClaudeCode@@Tests/DeployAgentTools.wlt:818,1-823,2"
]

VerificationTest[
    MemberQ[ $ccDeps, _? (#[ "UUID" ] === $dep3[ "UUID" ] &) ],
    True,
    TestID -> "DeployedAgentTools-FilterClaudeCode-ContainsDep3@@Tests/DeployAgentTools.wlt:825,1-829,2"
]

VerificationTest[
    (* $dep2 is a File target - should NOT be in the ClaudeCode list *)
    NoneTrue[ $ccDeps, #[ "UUID" ] === $dep2[ "UUID" ] & ],
    True,
    TestID -> "DeployedAgentTools-FilterClaudeCode-ExcludesDep2@@Tests/DeployAgentTools.wlt:831,1-836,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Alias Resolution*)
VerificationTest[
    (* "Claude" is an alias for "ClaudeDesktop" - should return the same result *)
    DeployedAgentTools[ "Claude" ] === DeployedAgentTools[ "ClaudeDesktop" ],
    True,
    TestID -> "DeployedAgentTools-AliasResolution@@Tests/DeployAgentTools.wlt:841,1-846,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Non-Existent Client*)
VerificationTest[
    DeployedAgentTools[ "NonExistentClient" ],
    { },
    TestID -> "DeployedAgentTools-NonExistentClient@@Tests/DeployAgentTools.wlt:851,1-855,2"
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
    TestID -> "DeployedAgentTools-EmptyPath@@Tests/DeployAgentTools.wlt:860,1-867,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Corrupted Records Filtered Out*)
VerificationTest[
    Module[ { corruptDir, corruptFile },
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
    TestID -> "DeployedAgentTools-CorruptedRecordFiltered@@Tests/DeployAgentTools.wlt:872,1-891,2"
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
    $deleteDep = DeployAgentTools[ $deleteTestConfig, "Wolfram", "VerifyLLMKit" -> False ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "DeleteObject-Setup-Deploy@@Tests/DeployAgentTools.wlt:900,1-907,2"
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
    TestID -> "DeleteObject-ConfigHasEntry@@Tests/DeployAgentTools.wlt:912,1-920,2"
]

VerificationTest[
    $deleteDepDir = $deleteDep[ "Location" ];
    DirectoryQ @ $deleteDepDir,
    True,
    TestID -> "DeleteObject-DeploymentDirExists@@Tests/DeployAgentTools.wlt:922,1-927,2"
]

VerificationTest[
    MemberQ[ DeployedAgentTools[ ], _? (#[ "UUID" ] === $deleteDep[ "UUID" ] &) ],
    True,
    TestID -> "DeleteObject-InListing@@Tests/DeployAgentTools.wlt:929,1-933,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Delete*)
VerificationTest[
    DeleteObject[ $deleteDep ],
    Null,
    TestID -> "DeleteObject-Delete@@Tests/DeployAgentTools.wlt:938,1-942,2"
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
    TestID -> "DeleteObject-ConfigEntryRemoved@@Tests/DeployAgentTools.wlt:947,1-955,2"
]

VerificationTest[
    ! DirectoryQ @ $deleteDepDir,
    True,
    TestID -> "DeleteObject-DeploymentDirRemoved@@Tests/DeployAgentTools.wlt:957,1-961,2"
]

VerificationTest[
    NoneTrue[ DeployedAgentTools[ ], #[ "UUID" ] === $deleteDep[ "UUID" ] & ],
    True,
    TestID -> "DeleteObject-NotInListing@@Tests/DeployAgentTools.wlt:963,1-967,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Delete Again Fails*)
VerificationTest[
    DeleteObject[ $deleteDep ],
    _Failure,
    { AgentToolsDeployment::DeploymentNotFound },
    SameTest -> MatchQ,
    TestID   -> "DeleteObject-DeleteAgainFails@@Tests/DeployAgentTools.wlt:972,1-978,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Round-Trip: Deploy -> List -> Delete -> Verify Gone*)
VerificationTest[
    Module[ { dir, config, dep, uuid, listed, listedAfter, json },
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
    TestID -> "DeleteObject-RoundTrip@@Tests/DeployAgentTools.wlt:983,1-1016,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet @ DeleteDirectory[ $deleteTestDir, DeleteContents -> True ];
    True,
    True,
    TestID -> "DeleteObject-Cleanup@@Tests/DeployAgentTools.wlt:1021,1-1026,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet[
        catchAlways @ DeleteObject @ $dep2;
        catchAlways @ DeleteObject @ $dep3;
        Quiet @ DeleteDirectory[ $deployTestDir, DeleteContents -> True ];
        Quiet @ DeleteDirectory[ $deployTestDir2, DeleteContents -> True ];
    ];
    True,
    True,
    TestID -> "DeployAgentTools-Cleanup@@Tests/DeployAgentTools.wlt:1035,1-1045,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Automatic toolset resolution (per-client DefaultToolset)*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DeployAgentTools with Automatic resolution*)
VerificationTest[
    autoDeployDir = CreateDirectory[ ];
    autoDeployAuto = DeployAgentTools[
        { "ClaudeCode", autoDeployDir },
        Automatic,
        "VerifyLLMKit" -> False
    ];
    autoDeployAuto[ "Toolset" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DeployAgentTools-Automatic-ClaudeCode@@Tests/DeployAgentTools.wlt:1054,1-1065,2"
]

VerificationTest[
    autoDeployAutoUUID = autoDeployAuto[ "UUID" ];
    Quiet @ catchAlways @ DeleteObject @ autoDeployAuto;
    Quiet @ DeleteDirectory[ autoDeployDir, DeleteContents -> True ];
    autoDeployDir = CreateDirectory[ ];
    autoDeploy1Arg = DeployAgentTools[
        { "ClaudeCode", autoDeployDir },
        "VerifyLLMKit" -> False
    ];
    autoDeploy1Arg[ "Toolset" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DeployAgentTools-1Arg-ClaudeCode@@Tests/DeployAgentTools.wlt:1067,1-1080,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DeployAgentTools Automatic with File target + ApplicationName*)
(* For arbitrary File[...] targets, an explicit ApplicationName option must
   drive the Automatic toolset choice instead of falling through to "Wolfram". *)
VerificationTest[
    Quiet @ catchAlways @ DeleteObject @ autoDeploy1Arg;
    Quiet @ DeleteDirectory[ autoDeployDir, DeleteContents -> True ];
    autoDeployDir = CreateDirectory[ ];
    autoDeployFile = File @ FileNameJoin @ { autoDeployDir, "custom_config_" <> CreateUUID[ ] <> ".json" };
    autoDeployFileApp = DeployAgentTools[
        autoDeployFile,
        Automatic,
        "ApplicationName" -> "Cline",
        "VerifyLLMKit"    -> False
    ];
    autoDeployFileApp[ "Toolset" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DeployAgentTools-Automatic-File-AppName-Cline@@Tests/DeployAgentTools.wlt:1087,1-1102,2"
]

VerificationTest[
    Quiet @ catchAlways @ DeleteObject @ autoDeployFileApp;
    Quiet @ DeleteDirectory[ autoDeployDir, DeleteContents -> True ];
    autoDeployDir = CreateDirectory[ ];
    autoDeployFile = File @ FileNameJoin @ { autoDeployDir, "custom_config_" <> CreateUUID[ ] <> ".json" };
    autoDeployFileChat = DeployAgentTools[
        autoDeployFile,
        Automatic,
        "ApplicationName" -> "ClaudeDesktop",
        "VerifyLLMKit"    -> False
    ];
    autoDeployFileChat[ "Toolset" ],
    "Wolfram",
    SameTest -> Equal,
    TestID   -> "DeployAgentTools-Automatic-File-AppName-ClaudeDesktop@@Tests/DeployAgentTools.wlt:1104,1-1119,2"
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
    Quiet @ catchAlways @ DeleteObject @ autoDeployFileChat;
    Quiet @ DeleteDirectory[ autoDeployDir, DeleteContents -> True ];
    autoDeployDir = CreateDirectory[ ];
    autoDeployFile = File @ FileNameJoin @ { autoDeployDir, ".mcp.json" };
    autoDeployFilePath = DeployAgentTools[
        autoDeployFile,
        Automatic,
        "VerifyLLMKit" -> False
    ];
    autoDeployFilePath[ "Toolset" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DeployAgentTools-Automatic-File-ClaudeCodeProject@@Tests/DeployAgentTools.wlt:1130,1-1144,2"
]

(* .vscode/mcp.json -> VisualStudioCode -> "WolframLanguage" *)
VerificationTest[
    Quiet @ catchAlways @ DeleteObject @ autoDeployFilePath;
    Quiet @ DeleteDirectory[ autoDeployDir, DeleteContents -> True ];
    autoDeployDir = CreateDirectory[ ];
    CreateDirectory @ FileNameJoin @ { autoDeployDir, ".vscode" };
    autoDeployFile = File @ FileNameJoin @ { autoDeployDir, ".vscode", "mcp.json" };
    autoDeployFileVSCode = DeployAgentTools[
        autoDeployFile,
        Automatic,
        "VerifyLLMKit" -> False
    ];
    autoDeployFileVSCode[ "Toolset" ],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "DeployAgentTools-Automatic-File-VSCodeProject@@Tests/DeployAgentTools.wlt:1147,1-1162,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet @ catchAlways @ DeleteObject @ autoDeployFileVSCode;
    Quiet @ DeleteDirectory[ autoDeployDir, DeleteContents -> True ];
    True,
    True,
    TestID -> "DeployAgentTools-Automatic-Cleanup@@Tests/DeployAgentTools.wlt:1167,1-1173,2"
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

(* :!CodeAnalysis::EndBlock:: *)
