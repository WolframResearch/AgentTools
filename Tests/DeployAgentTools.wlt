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
    TestID   -> "AgentToolsDeployment-ValidConstruction@@Tests/DeployAgentTools.wlt:65,1-70,2"
]

VerificationTest[
    agentToolsDeploymentQ @ dep,
    True,
    TestID -> "AgentToolsDeployment-ValidQ@@Tests/DeployAgentTools.wlt:72,1-76,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Construction*)
VerificationTest[
    AgentToolsDeployment[ "not-a-real-uuid" ],
    _Failure,
    { AgentToolsDeployment::DeploymentNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-InvalidUUID@@Tests/DeployAgentTools.wlt:81,1-87,2"
]

VerificationTest[
    AgentToolsDeployment[ <|"UUID" -> "test"|> ],
    _Failure,
    { AgentToolsDeployment::InvalidDeploymentData },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-InvalidIncompleteData@@Tests/DeployAgentTools.wlt:89,1-95,2"
]

VerificationTest[
    AgentToolsDeployment[ <||> ],
    _Failure,
    { AgentToolsDeployment::InvalidDeploymentData },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-InvalidEmptyAssociation@@Tests/DeployAgentTools.wlt:97,1-103,2"
]

VerificationTest[
    Quiet @ agentToolsDeploymentQ @ AgentToolsDeployment[ <||> ],
    False,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-InvalidNotValidQ@@Tests/DeployAgentTools.wlt:105,1-110,2"
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
    TestID   -> "AgentToolsDeployment-Property-UUID@@Tests/DeployAgentTools.wlt:119,1-124,2"
]

VerificationTest[
    dep[ "Timestamp" ],
    _DateObject,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Timestamp@@Tests/DeployAgentTools.wlt:126,1-131,2"
]

VerificationTest[
    dep[ "PacletVersion" ],
    "1.8.0",
    TestID -> "AgentToolsDeployment-Property-PacletVersion@@Tests/DeployAgentTools.wlt:133,1-137,2"
]

VerificationTest[
    dep[ "CreatedBy" ],
    "DeployAgentTools",
    TestID -> "AgentToolsDeployment-Property-CreatedBy@@Tests/DeployAgentTools.wlt:139,1-143,2"
]

VerificationTest[
    dep[ "Version" ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Version-Missing@@Tests/DeployAgentTools.wlt:145,1-150,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCP Shortcut Properties*)
VerificationTest[
    dep[ "ClientName" ],
    "ClaudeDesktop",
    TestID -> "AgentToolsDeployment-Property-ClientName@@Tests/DeployAgentTools.wlt:155,1-159,2"
]

VerificationTest[
    dep[ "Target" ],
    "ClaudeDesktop",
    TestID -> "AgentToolsDeployment-Property-Target@@Tests/DeployAgentTools.wlt:161,1-165,2"
]

VerificationTest[
    dep[ "Server" ],
    "WolframLanguage",
    TestID -> "AgentToolsDeployment-Property-Server@@Tests/DeployAgentTools.wlt:167,1-171,2"
]

(* Legacy-shaped fixture: Toolset falls back through MCP/Server *)
VerificationTest[
    dep[ "Toolset" ],
    "WolframLanguage",
    TestID -> "AgentToolsDeployment-Property-Toolset-LegacyFallback@@Tests/DeployAgentTools.wlt:174,1-178,2"
]

VerificationTest[
    dep[ "ConfigFile" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-ConfigFile@@Tests/DeployAgentTools.wlt:180,1-185,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Sub-Association Properties*)
VerificationTest[
    dep[ "MCP" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-MCP@@Tests/DeployAgentTools.wlt:190,1-195,2"
]

VerificationTest[
    dep[ "Skills" ],
    <||>,
    TestID -> "AgentToolsDeployment-Property-Skills@@Tests/DeployAgentTools.wlt:197,1-201,2"
]

VerificationTest[
    dep[ "Hooks" ],
    <||>,
    TestID -> "AgentToolsDeployment-Property-Hooks@@Tests/DeployAgentTools.wlt:203,1-207,2"
]

VerificationTest[
    dep[ "Meta" ],
    <||>,
    TestID -> "AgentToolsDeployment-Property-Meta@@Tests/DeployAgentTools.wlt:209,1-213,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Derived Properties*)
VerificationTest[
    dep[ "Data" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Data@@Tests/DeployAgentTools.wlt:218,1-223,2"
]

VerificationTest[
    dep[ "Location" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Location@@Tests/DeployAgentTools.wlt:225,1-230,2"
]

VerificationTest[
    dep[ "Properties" ],
    _List,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Properties@@Tests/DeployAgentTools.wlt:232,1-237,2"
]

VerificationTest[
    MemberQ[ dep[ "Properties" ], "UUID" ],
    True,
    TestID -> "AgentToolsDeployment-Property-PropertiesContainsUUID@@Tests/DeployAgentTools.wlt:239,1-243,2"
]

VerificationTest[
    dep[ "MCPServerObject" ],
    _MCPServerObject,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-MCPServerObject@@Tests/DeployAgentTools.wlt:245,1-250,2"
]

VerificationTest[
    dep[ "Tools" ],
    { ___LLMTool },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Tools@@Tests/DeployAgentTools.wlt:252,1-257,2"
]

VerificationTest[
    dep[ "LLMConfiguration" ],
    _LLMConfiguration,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-LLMConfiguration@@Tests/DeployAgentTools.wlt:259,1-264,2"
]

VerificationTest[
    dep[ "Scope" ],
    "Global",
    TestID -> "AgentToolsDeployment-Property-Scope-Global@@Tests/DeployAgentTools.wlt:266,1-270,2"
]

VerificationTest[
    SubsetQ[ dep[ "Properties" ], { "MCPServerObject", "Tools", "LLMConfiguration" } ],
    True,
    TestID -> "AgentToolsDeployment-Property-PropertiesContainsNewDerived@@Tests/DeployAgentTools.wlt:272,1-276,2"
]

VerificationTest[
    MemberQ[ dep[ "Properties" ], "Toolset" ],
    True,
    TestID -> "AgentToolsDeployment-Property-PropertiesContainsToolset@@Tests/DeployAgentTools.wlt:278,1-282,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Two-Argument Property Access*)
VerificationTest[
    dep[ "MCP", "Options" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-MCP-Options@@Tests/DeployAgentTools.wlt:287,1-292,2"
]

VerificationTest[
    dep[ "MCP", "Server" ],
    "WolframLanguage",
    TestID -> "AgentToolsDeployment-Property-MCP-Server@@Tests/DeployAgentTools.wlt:294,1-298,2"
]

(* Legacy fixture doesn't have MCP/Toolset - verify the two-arg accessor reports missing *)
VerificationTest[
    dep[ "MCP", "Toolset" ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-MCP-Toolset-LegacyMissing@@Tests/DeployAgentTools.wlt:301,1-306,2"
]

VerificationTest[
    dep[ "MCP", "ClientName" ],
    "ClaudeDesktop",
    TestID -> "AgentToolsDeployment-Property-MCP-ClientName@@Tests/DeployAgentTools.wlt:308,1-312,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Unknown Property*)
VerificationTest[
    dep[ "NonexistentProperty" ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Unknown@@Tests/DeployAgentTools.wlt:317,1-322,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Property*)
VerificationTest[
    dep[ 42 ],
    _Failure,
    { AgentToolsDeployment::InvalidProperty },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-Property-Invalid@@Tests/DeployAgentTools.wlt:327,1-333,2"
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
    TestID   -> "AgentToolsDeployment-Formatting-MakeBoxes@@Tests/DeployAgentTools.wlt:338,1-345,2"
]

VerificationTest[
    (* Invalid objects should not produce formatted boxes *)
    MakeBoxes[ AgentToolsDeployment[ <||> ], StandardForm ],
    _InterpretationBox,
    SameTest -> Not @* MatchQ,
    TestID   -> "AgentToolsDeployment-Formatting-InvalidNoBoxes@@Tests/DeployAgentTools.wlt:347,1-353,2"
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
    TestID   -> "AgentToolsDeployment-Validation-MissingKeys@@Tests/DeployAgentTools.wlt:360,1-370,2"
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
    TestID   -> "AgentToolsDeployment-Validation-WrongUUIDType@@Tests/DeployAgentTools.wlt:373,1-395,2"
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
    TestID   -> "AgentToolsDeployment-Validation-NoneClientName@@Tests/DeployAgentTools.wlt:398,1-419,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Multiple Objects*)
VerificationTest[
    dep1 = AgentToolsDeployment[ $testDeploymentData ];
    dep2 = AgentToolsDeployment[ $testDeploymentData ];
    dep1[ "UUID" ] =!= dep2[ "UUID" ],
    True,
    TestID -> "AgentToolsDeployment-MultipleObjects-UniqueUUIDs@@Tests/DeployAgentTools.wlt:424,1-430,2"
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
    TestID -> "DeployAgentTools-Setup@@Tests/DeployAgentTools.wlt:439,1-445,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Deployment*)
VerificationTest[
    $dep1 = withTestEnvironment @ DeployAgentTools[ $deployTestConfig, "Wolfram", "VerifyLLMKit" -> False ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-BasicDeploy@@Tests/DeployAgentTools.wlt:450,1-455,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Returned Object Properties*)
VerificationTest[
    $dep1[ "Server" ],
    "Wolfram",
    TestID -> "DeployAgentTools-Property-Server@@Tests/DeployAgentTools.wlt:460,1-464,2"
]

(* New deployments expose the canonical Toolset property *)
VerificationTest[
    $dep1[ "Toolset" ],
    "Wolfram",
    TestID -> "DeployAgentTools-Property-Toolset@@Tests/DeployAgentTools.wlt:467,1-471,2"
]

(* Legacy MCP/Server is still dual-written for backward compatibility *)
VerificationTest[
    $dep1[ "MCP", "Server" ],
    "Wolfram",
    TestID -> "DeployAgentTools-Property-MCP-Server@@Tests/DeployAgentTools.wlt:474,1-478,2"
]

VerificationTest[
    $dep1[ "Data" ][ "Toolset" ],
    "Wolfram",
    TestID -> "DeployAgentTools-Data-Toolset@@Tests/DeployAgentTools.wlt:480,1-484,2"
]

VerificationTest[
    $dep1[ "ConfigFile" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-ConfigFile@@Tests/DeployAgentTools.wlt:486,1-491,2"
]

VerificationTest[
    $dep1[ "UUID" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-UUID@@Tests/DeployAgentTools.wlt:493,1-498,2"
]

VerificationTest[
    $dep1[ "Timestamp" ],
    _DateObject,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-Timestamp@@Tests/DeployAgentTools.wlt:500,1-505,2"
]

VerificationTest[
    $dep1[ "CreatedBy" ],
    "DeployAgentTools",
    TestID -> "DeployAgentTools-Property-CreatedBy@@Tests/DeployAgentTools.wlt:507,1-511,2"
]

VerificationTest[
    $dep1[ "PacletVersion" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-PacletVersion@@Tests/DeployAgentTools.wlt:513,1-518,2"
]

VerificationTest[
    $dep1[ "Target" ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-Target@@Tests/DeployAgentTools.wlt:520,1-525,2"
]

VerificationTest[
    $dep1[ "MCP" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-MCP@@Tests/DeployAgentTools.wlt:527,1-532,2"
]

VerificationTest[
    $dep1[ "MCP", "Options" ],
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-MCP-Options@@Tests/DeployAgentTools.wlt:534,1-539,2"
]

VerificationTest[
    $dep1[ "MCPServerObject" ],
    _MCPServerObject,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-MCPServerObject@@Tests/DeployAgentTools.wlt:541,1-546,2"
]

VerificationTest[
    $dep1[ "Tools" ],
    { __LLMTool },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-Tools@@Tests/DeployAgentTools.wlt:548,1-553,2"
]

VerificationTest[
    $dep1[ "LLMConfiguration" ],
    _LLMConfiguration,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-LLMConfiguration@@Tests/DeployAgentTools.wlt:555,1-560,2"
]

VerificationTest[
    $dep1[ "Scope" ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-Property-Scope-FileTarget@@Tests/DeployAgentTools.wlt:562,1-567,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config File Updated*)
VerificationTest[
    FileExistsQ @ $deployTestConfig,
    True,
    TestID -> "DeployAgentTools-ConfigFileExists@@Tests/DeployAgentTools.wlt:572,1-576,2"
]

VerificationTest[
    Module[ { json },
        json = Developer`ReadRawJSONString @ ReadString @ First @ $deployTestConfig;
        KeyExistsQ[ json, "mcpServers" ] && KeyExistsQ[ json[ "mcpServers" ], "Wolfram" ]
    ],
    True,
    TestID -> "DeployAgentTools-ConfigFileHasServerEntry@@Tests/DeployAgentTools.wlt:578,1-585,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Deployment Record on Disk*)
VerificationTest[
    withTestEnvironment @ $dep1[ "Location" ],
    _File? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-DeploymentDirExists@@Tests/DeployAgentTools.wlt:590,1-595,2"
]

VerificationTest[
    withTestEnvironment @ FileExistsQ @ FileNameJoin @ { First @ $dep1[ "Location" ], "Deployment.wxf" },
    True,
    TestID -> "DeployAgentTools-DeploymentWXFExists@@Tests/DeployAgentTools.wlt:597,1-601,2"
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
    TestID -> "DeployAgentTools-DeploymentWXF-DualWrite@@Tests/DeployAgentTools.wlt:604,1-614,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UUID Lookup*)
VerificationTest[
    $dep1Lookup = withTestEnvironment @ AgentToolsDeployment[ $dep1[ "UUID" ] ],
    _AgentToolsDeployment,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-UUIDLookup@@Tests/DeployAgentTools.wlt:619,1-624,2"
]

VerificationTest[
    $dep1Lookup[ "UUID" ] === $dep1[ "UUID" ],
    True,
    TestID -> "AgentToolsDeployment-UUIDLookup-SameUUID@@Tests/DeployAgentTools.wlt:626,1-630,2"
]

VerificationTest[
    $dep1Lookup[ "Server" ] === $dep1[ "Server" ],
    True,
    TestID -> "AgentToolsDeployment-UUIDLookup-SameServer@@Tests/DeployAgentTools.wlt:632,1-636,2"
]

VerificationTest[
    withTestEnvironment @ AgentToolsDeployment[ "nonexistent-uuid-00000000" ],
    _Failure,
    { AgentToolsDeployment::DeploymentNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsDeployment-UUIDLookup-NotFound@@Tests/DeployAgentTools.wlt:638,1-644,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Project Directory*)
VerificationTest[
    withTestEnvironment @ DeployAgentTools[ { "ClaudeCode", Symbol[ "xyz" ] } ],
    _Failure,
    { DeployAgentTools::InvalidProjectDirectory },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidProjectDirectory@@Tests/DeployAgentTools.wlt:649,1-655,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Deploy Target*)
VerificationTest[
    withTestEnvironment @ DeployAgentTools[ 123, "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::InvalidDeployTarget },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidDeployTarget-Integer@@Tests/DeployAgentTools.wlt:660,1-666,2"
]

VerificationTest[
    withTestEnvironment @ DeployAgentTools[ <|"a" -> 1|>, "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::InvalidDeployTarget },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidDeployTarget-Association@@Tests/DeployAgentTools.wlt:668,1-674,2"
]

VerificationTest[
    withTestEnvironment @ DeployAgentTools[ {1, 2, 3}, "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::InvalidDeployTarget },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-InvalidDeployTarget-List@@Tests/DeployAgentTools.wlt:676,1-682,2"
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
    TestID   -> "DeployAgentTools-InvalidApplicationName-Integer@@Tests/DeployAgentTools.wlt:687,1-698,2"
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
    TestID   -> "DeployAgentTools-InvalidApplicationName-List@@Tests/DeployAgentTools.wlt:700,1-711,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*OverwriteTarget -> False Fails*)
VerificationTest[
    withTestEnvironment @ DeployAgentTools[ $deployTestConfig, "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::DeploymentExists },
    SameTest -> MatchQ,
    TestID   -> "DeployAgentTools-DuplicateFails@@Tests/DeployAgentTools.wlt:716,1-722,2"
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
    TestID   -> "DeployAgentTools-OverwriteTrue@@Tests/DeployAgentTools.wlt:727,1-737,2"
]

VerificationTest[
    $dep2[ "UUID" ] =!= $dep1[ "UUID" ],
    True,
    TestID -> "DeployAgentTools-OverwriteNewUUID@@Tests/DeployAgentTools.wlt:739,1-743,2"
]

VerificationTest[
    (* The old deployment directory should have been cleaned up *)
    ! DirectoryQ @ First @ withTestEnvironment @ $dep1[ "Location" ],
    True,
    TestID -> "DeployAgentTools-OverwriteOldDirRemoved@@Tests/DeployAgentTools.wlt:745,1-750,2"
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
    TestID   -> "DeployAgentTools-ProjectDeploy@@Tests/DeployAgentTools.wlt:755,1-765,2"
]

VerificationTest[
    $dep3[ "ClientName" ],
    "ClaudeCode",
    TestID -> "DeployAgentTools-ProjectDeploy-ClientName@@Tests/DeployAgentTools.wlt:767,1-771,2"
]

VerificationTest[
    $dep3[ "Target" ],
    { "ClaudeCode", File[ $deployTestDir2 ] },
    TestID -> "DeployAgentTools-ProjectDeploy-Target@@Tests/DeployAgentTools.wlt:773,1-777,2"
]

VerificationTest[
    $dep3[ "Scope" ],
    File[ $deployTestDir2 ],
    TestID -> "DeployAgentTools-ProjectDeploy-Scope@@Tests/DeployAgentTools.wlt:779,1-783,2"
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
    TestID   -> "DeployAgentTools-EquivalentTargetFails@@Tests/DeployAgentTools.wlt:785,1-796,2"
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
    TestID   -> "DeployedAgentTools-ListAll@@Tests/DeployAgentTools.wlt:805,1-810,2"
]

VerificationTest[
    AllTrue[ $allDeps, agentToolsDeploymentQ ],
    True,
    TestID -> "DeployedAgentTools-ListAll-AllValid@@Tests/DeployAgentTools.wlt:812,1-816,2"
]

VerificationTest[
    (* The two existing deployments ($dep2 and $dep3) should be in the list *)
    MemberQ[ $allDeps, _? (configFilesEqual[ #[ "ConfigFile" ], $dep2[ "ConfigFile" ] ] &) ] &&
    MemberQ[ $allDeps, _? (configFilesEqual[ #[ "ConfigFile" ], $dep3[ "ConfigFile" ] ] &) ],
    True,
    TestID -> "DeployedAgentTools-ListAll-ContainsDeployments@@Tests/DeployAgentTools.wlt:818,1-824,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Filter By Client Name*)
VerificationTest[
    $ccDeps = withTestEnvironment @ DeployedAgentTools[ "ClaudeCode" ],
    _List,
    SameTest -> MatchQ,
    TestID   -> "DeployedAgentTools-FilterClaudeCode@@Tests/DeployAgentTools.wlt:829,1-834,2"
]

VerificationTest[
    MemberQ[ $ccDeps, _? (#[ "UUID" ] === $dep3[ "UUID" ] &) ],
    True,
    TestID -> "DeployedAgentTools-FilterClaudeCode-ContainsDep3@@Tests/DeployAgentTools.wlt:836,1-840,2"
]

VerificationTest[
    (* $dep2 is a File target - should NOT be in the ClaudeCode list *)
    NoneTrue[ $ccDeps, #[ "UUID" ] === $dep2[ "UUID" ] & ],
    True,
    TestID -> "DeployedAgentTools-FilterClaudeCode-ExcludesDep2@@Tests/DeployAgentTools.wlt:842,1-847,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Alias Resolution*)
VerificationTest[
    (* "Claude" is an alias for "ClaudeDesktop" - should return the same result *)
    withTestEnvironment[ DeployedAgentTools[ "Claude" ] === DeployedAgentTools[ "ClaudeDesktop" ] ],
    True,
    TestID -> "DeployedAgentTools-AliasResolution@@Tests/DeployAgentTools.wlt:852,1-857,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Non-Existent Client*)
VerificationTest[
    withTestEnvironment @ DeployedAgentTools[ "NonExistentClient" ],
    { },
    TestID -> "DeployedAgentTools-NonExistentClient@@Tests/DeployAgentTools.wlt:862,1-866,2"
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
    TestID -> "DeployedAgentTools-EmptyPath@@Tests/DeployAgentTools.wlt:871,1-878,2"
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
    TestID -> "DeployedAgentTools-CorruptedRecordFiltered@@Tests/DeployAgentTools.wlt:883,1-902,2"
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
    TestID   -> "DeleteObject-Setup-Deploy@@Tests/DeployAgentTools.wlt:911,1-918,2"
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
    TestID -> "DeleteObject-ConfigHasEntry@@Tests/DeployAgentTools.wlt:923,1-931,2"
]

VerificationTest[
    $deleteDepDir = withTestEnvironment @ $deleteDep[ "Location" ];
    DirectoryQ @ $deleteDepDir,
    True,
    TestID -> "DeleteObject-DeploymentDirExists@@Tests/DeployAgentTools.wlt:933,1-938,2"
]

VerificationTest[
    MemberQ[ withTestEnvironment @ DeployedAgentTools[ ], _? (#[ "UUID" ] === $deleteDep[ "UUID" ] &) ],
    True,
    TestID -> "DeleteObject-InListing@@Tests/DeployAgentTools.wlt:940,1-944,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Delete*)
VerificationTest[
    withTestEnvironment @ DeleteObject[ $deleteDep ],
    Null,
    TestID -> "DeleteObject-Delete@@Tests/DeployAgentTools.wlt:949,1-953,2"
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
    TestID -> "DeleteObject-ConfigEntryRemoved@@Tests/DeployAgentTools.wlt:958,1-966,2"
]

VerificationTest[
    ! DirectoryQ @ $deleteDepDir,
    True,
    TestID -> "DeleteObject-DeploymentDirRemoved@@Tests/DeployAgentTools.wlt:968,1-972,2"
]

VerificationTest[
    NoneTrue[ withTestEnvironment @ DeployedAgentTools[ ], #[ "UUID" ] === $deleteDep[ "UUID" ] & ],
    True,
    TestID -> "DeleteObject-NotInListing@@Tests/DeployAgentTools.wlt:974,1-978,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Delete Again Fails*)
VerificationTest[
    withTestEnvironment @ DeleteObject[ $deleteDep ],
    _Failure,
    { AgentToolsDeployment::DeploymentNotFound },
    SameTest -> MatchQ,
    TestID   -> "DeleteObject-DeleteAgainFails@@Tests/DeployAgentTools.wlt:983,1-989,2"
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
    TestID -> "DeleteObject-RoundTrip@@Tests/DeployAgentTools.wlt:994,1-1027,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet @ DeleteDirectory[ $deleteTestDir, DeleteContents -> True ];
    True,
    True,
    TestID -> "DeleteObject-Cleanup@@Tests/DeployAgentTools.wlt:1032,1-1037,2"
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
    TestID -> "DeployAgentTools-Cleanup@@Tests/DeployAgentTools.wlt:1046,1-1056,2"
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
    TestID   -> "DeployAgentTools-Automatic-ClaudeCode@@Tests/DeployAgentTools.wlt:1065,1-1076,2"
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
    TestID   -> "DeployAgentTools-1Arg-ClaudeCode@@Tests/DeployAgentTools.wlt:1078,1-1091,2"
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
    TestID   -> "DeployAgentTools-Automatic-File-AppName-Cline@@Tests/DeployAgentTools.wlt:1098,1-1113,2"
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
    TestID   -> "DeployAgentTools-Automatic-File-AppName-ClaudeDesktop@@Tests/DeployAgentTools.wlt:1115,1-1130,2"
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
    TestID   -> "DeployAgentTools-Automatic-File-ClaudeCodeProject@@Tests/DeployAgentTools.wlt:1141,1-1155,2"
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
    TestID   -> "DeployAgentTools-Automatic-File-VSCodeProject@@Tests/DeployAgentTools.wlt:1158,1-1173,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    withTestEnvironment @ Quiet @ catchAlways @ DeleteObject @ autoDeployFileVSCode;
    Quiet @ DeleteDirectory[ autoDeployDir, DeleteContents -> True ];
    True,
    True,
    TestID -> "DeployAgentTools-Automatic-Cleanup@@Tests/DeployAgentTools.wlt:1178,1-1184,2"
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
    TestID -> "DeployAgentTools-All-Setup@@Tests/DeployAgentTools.wlt:1197,1-1207,2"
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
    TestID   -> "DeployAgentTools-All-BasicResultShape@@Tests/DeployAgentTools.wlt:1212,1-1225,2"
]

VerificationTest[
    Length @ $allDep1,
    Length @ $allTestClients,
    TestID -> "DeployAgentTools-All-LengthMatchesClients@@Tests/DeployAgentTools.wlt:1227,1-1231,2"
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
    TestID -> "DeployAgentTools-All-AutomaticToolsetPerClient@@Tests/DeployAgentTools.wlt:1239,1-1243,2"
]

VerificationTest[
    Sort @ Map[ #[ "ClientName" ] &, $allDep1 ],
    Sort @ Keys @ $allTestClients,
    TestID -> "DeployAgentTools-All-CoversEveryClient@@Tests/DeployAgentTools.wlt:1245,1-1249,2"
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
    TestID   -> "DeployAgentTools-All-MissingDeploymentExistsEntries@@Tests/DeployAgentTools.wlt:1254,1-1270,2"
]

VerificationTest[
    Sort @ Map[ #[[ 2 ]] &, $allDep2 ],
    Sort @ Keys @ $allTestClients,
    TestID -> "DeployAgentTools-All-MissingTargetsAreClientNames@@Tests/DeployAgentTools.wlt:1272,1-1276,2"
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
    TestID   -> "DeployAgentTools-All-WarningMessageIssued@@Tests/DeployAgentTools.wlt:1280,1-1294,2"
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
    TestID   -> "DeployAgentTools-All-OverwriteShape@@Tests/DeployAgentTools.wlt:1299,1-1313,2"
]

VerificationTest[
    (* All UUIDs in the new result should be different from the originals *)
    Intersection[ Sort @ Map[ #[ "UUID" ] &, $allDep3 ], $allDep1UUIDs ],
    { },
    TestID -> "DeployAgentTools-All-OverwriteNewUUIDs@@Tests/DeployAgentTools.wlt:1315,1-1320,2"
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
    TestID   -> "DeployAgentTools-All-ExplicitServerShape@@Tests/DeployAgentTools.wlt:1327,1-1345,2"
]

VerificationTest[
    Sort @ DeleteDuplicates @ Map[ #[ "Toolset" ] &, $allDep4 ],
    { "Wolfram" },
    TestID -> "DeployAgentTools-All-ExplicitServerOverridesDefault@@Tests/DeployAgentTools.wlt:1347,1-1351,2"
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
    TestID   -> "DeployAgentTools-All-1ArgForm@@Tests/DeployAgentTools.wlt:1359,1-1375,2"
]

VerificationTest[
    (* 1-arg form falls through to per-client DefaultToolset, like Automatic *)
    Sort @ DeleteDuplicates @ Map[ #[ "Toolset" ] &, $allDep5 ],
    { "WolframLanguage" },
    TestID -> "DeployAgentTools-All-1ArgFormUsesDefaultToolset@@Tests/DeployAgentTools.wlt:1377,1-1382,2"
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
    TestID -> "DeployAgentTools-All-resolveServerForClient-CursorAutomatic@@Tests/DeployAgentTools.wlt:1390,1-1395,2"
]

VerificationTest[
    resolveServerForClient[ "ClaudeDesktop", Automatic ],
    "Wolfram",
    TestID -> "DeployAgentTools-All-resolveServerForClient-ClaudeDesktopAutomatic@@Tests/DeployAgentTools.wlt:1397,1-1401,2"
]

VerificationTest[
    resolveServerForClient[ "Cursor", "Wolfram" ],
    "Wolfram",
    TestID -> "DeployAgentTools-All-resolveServerForClient-ExplicitPassthrough@@Tests/DeployAgentTools.wlt:1403,1-1407,2"
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
    TestID   -> "DeployAgentTools-All-ApplicationName-Setup@@Tests/DeployAgentTools.wlt:1417,1-1435,2"
]

VerificationTest[
    (* ClaudeDesktop's DefaultToolset is "Wolfram"; if ApplicationName were
       being honored as the default-toolset selector, both deployments would
       come back as "Wolfram".  Both Cursor and ClaudeCode are coding clients,
       so the correct result is "WolframLanguage" for both. *)
    Sort @ DeleteDuplicates @ Map[ #[ "Toolset" ] &, $allDepAppName ],
    { "WolframLanguage" },
    TestID -> "DeployAgentTools-All-ApplicationName-PerClientDefault@@Tests/DeployAgentTools.wlt:1437,1-1445,2"
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
    TestID   -> "DeployAgentTools-All-UnsupportedClientShape@@Tests/DeployAgentTools.wlt:1468,1-1488,2"
]

VerificationTest[
    Cases[ $allDepUnsupported, _Missing ],
    { Missing[ "Unsupported", { "AlwaysUnsupported", $OperatingSystem } ] },
    TestID -> "DeployAgentTools-All-UnsupportedClientPayload@@Tests/DeployAgentTools.wlt:1490,1-1494,2"
]

VerificationTest[
    Length @ Cases[ $allDepUnsupported, _AgentToolsDeployment ],
    1,
    TestID -> "DeployAgentTools-All-UnsupportedClientStillDeploysSupported@@Tests/DeployAgentTools.wlt:1496,1-1500,2"
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
    TestID   -> "DeployAgentTools-All-NoWarningForUnsupportedOnly@@Tests/DeployAgentTools.wlt:1507,1-1526,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet @ DeleteDirectory[ $allTestTmpHome, DeleteContents -> True ];
    True,
    True,
    TestID -> "DeployAgentTools-All-Cleanup@@Tests/DeployAgentTools.wlt:1531,1-1536,2"
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
    TestID -> "DeployAgentTools-TestEnvironment-NothingLeft@@Tests/DeployAgentTools.wlt:1542,1-1552,2"
]

VerificationTest[
    Quiet @ Scan[ DeleteDirectory[ #, DeleteContents -> True ] &, { $testRoot, $testHome } ];
    { DirectoryQ @ $testRoot, DirectoryQ @ $testHome },
    { False, False },
    TestID -> "DeployAgentTools-TestEnvironment-Cleanup@@Tests/DeployAgentTools.wlt:1554,1-1559,2"
]

(* :!CodeAnalysis::EndBlock:: *)
