(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/DeployAgentToolsSkills.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/DeployAgentToolsSkills.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Test Environment*)
(* Every test runs with a temporary home directory (client config files and skill directories) and a temporary
   AgentTools root (deployment records, the skill registry, MCP server records), so nothing on the machine is touched. *)
$testHome = CreateDirectory[ ];
$testRoot = CreateDirectory[ ];

withTestEnvironment // Attributes = { HoldFirst };
withTestEnvironment[ eval_ ] :=
    Block[ { Wolfram`AgentTools`Common`$rootPath = $testRoot, $HomeDirectory = $testHome }, eval ];

$deploymentsPath   := Wolfram`AgentTools`Common`$deploymentsPath;
$skillRegistryPath := Wolfram`AgentTools`Common`$skillRegistryPath;
agentToolsDeploymentQ = Wolfram`AgentTools`DeployAgentTools`Private`agentToolsDeploymentQ;

registryEntries[ ] := withTestEnvironment @ If[ DirectoryQ @ $skillRegistryPath,
    Developer`ReadWXFFile /@ FileNames[ "*.wxf", $skillRegistryPath ],
    { }
];

registryEntry[ name_String ] := SelectFirst[ registryEntries[ ], #[ "Name" ] === name &, Missing[ "NotFound" ] ];

skillFile[ root_String, name_String ] := FileNameJoin @ { root, name, "SKILL.md" };

readJSON[ file_ ] := Developer`ReadRawJSONFile @ ExpandFileName @ file;

makeSkillDirectory[ parent_String, name_String, description_String ] := Module[ { dir },
    dir = FileNameJoin @ { parent, name };
    CreateDirectory[ dir, CreateIntermediateDirectories -> True ];
    Export[ FileNameJoin @ { dir, "SKILL.md" }, "---\nname: " <> name <> "\ndescription: " <> description <> "\n---\n\nInstructions for " <> name <> ".\n", "Text" ];
    CreateDirectory @ FileNameJoin @ { dir, "scripts" };
    Export[ FileNameJoin @ { dir, "scripts", "run.sh" }, "#!/bin/sh\necho " <> name <> "\n", "Text" ];
    dir
];

$sourceDir = CreateDirectory[ ];
$dirSkill  = makeSkillDirectory[ $sourceDir, "dir-skill", "A skill from a directory." ];
$memSkill  = LLMSkill[ { "mem-skill", "A skill defined in memory." }, "Do the in-memory thing." ];

$bundle = <|
    "Name"        -> "TestBundle",
    "MCPServers"  -> { "WolframLanguage" },
    "AgentSkills" -> { $memSkill, File @ $dirSkill }
|>;

$skillsOnly = <| "Name" -> "SkillsOnly", "AgentSkills" -> { File @ $dirSkill } |>;

$copilotSkills := FileNameJoin @ { $HomeDirectory, ".copilot", "skills" };
$agentsSkills  := FileNameJoin @ { $HomeDirectory, ".agents", "skills" };
$claudeSkills  := FileNameJoin @ { $HomeDirectory, ".claude", "skills" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Project Deployment of a Bundle*)
VerificationTest[
    $project = CreateDirectory[ ];
    $dep = withTestEnvironment @ DeployAgentTools[ { "ClaudeCode", $project }, $bundle, "VerifyLLMKit" -> False ],
    _AgentToolsDeployment? agentToolsDeploymentQ,
    SameTest -> MatchQ,
    TestID   -> "Bundle-Project-Deploy@@Tests/DeployAgentToolsSkills.wlt:76,1-82,2"
]

VerificationTest[
    withTestEnvironment[ $dep /@ { "Toolset", "ToolsetType", "ClientName", "MCPServerNames", "AgentSkills" } ],
    { "TestBundle", "AgentToolsObject", "ClaudeCode", { "WolframLanguage" }, { "mem-skill", "dir-skill" } },
    TestID -> "Bundle-Project-Properties@@Tests/DeployAgentToolsSkills.wlt:84,1-88,2"
]

VerificationTest[
    withTestEnvironment @ { $dep[ "Data" ][ "Toolset" ], $dep[ "MCP", "Server" ], $dep[ "Server" ], $dep[ "Data" ][ "Version" ] },
    { "WolframLanguage", "WolframLanguage", "WolframLanguage", 2 },
    TestID -> "Bundle-Project-PrimaryServerCompatibility@@Tests/DeployAgentToolsSkills.wlt:90,1-94,2"
]

VerificationTest[
    withTestEnvironment @ $dep[ "SkillsDirectory" ],
    File @ FileNameJoin @ { $project, ".claude", "skills" },
    TestID -> "Bundle-Project-SkillsDirectory@@Tests/DeployAgentToolsSkills.wlt:96,1-100,2"
]

VerificationTest[
    FileExistsQ /@ {
        skillFile[ FileNameJoin @ { $project, ".claude", "skills" }, "mem-skill" ],
        skillFile[ FileNameJoin @ { $project, ".claude", "skills" }, "dir-skill" ],
        FileNameJoin @ { $project, ".claude", "skills", "dir-skill", "scripts", "run.sh" }
    },
    { True, True, True },
    TestID -> "Bundle-Project-SkillFiles@@Tests/DeployAgentToolsSkills.wlt:102,1-110,2"
]

VerificationTest[
    StringStartsQ[ ReadString @ skillFile[ FileNameJoin @ { $project, ".claude", "skills" }, "mem-skill" ], "---\nname: mem-skill\n" ],
    True,
    TestID -> "Bundle-Project-GeneratedSkillMarkdown@@Tests/DeployAgentToolsSkills.wlt:112,1-116,2"
]

VerificationTest[
    KeyExistsQ[ readJSON[ FileNameJoin @ { $project, ".mcp.json" } ][ "mcpServers" ], "Wolfram" ],
    True,
    TestID -> "Bundle-Project-MCPConfig@@Tests/DeployAgentToolsSkills.wlt:118,1-122,2"
]

VerificationTest[
    Sort[ #[ "Name" ] & /@ registryEntries[ ] ],
    { "dir-skill", "mem-skill" },
    TestID -> "Bundle-Project-RegistryEntries@@Tests/DeployAgentToolsSkills.wlt:124,1-128,2"
]

VerificationTest[
    AllTrue[ registryEntries[ ], #[ "References" ] === { withTestEnvironment @ $dep[ "UUID" ] } && #[ "External" ] === False & ],
    True,
    TestID -> "Bundle-Project-RegistryReferences@@Tests/DeployAgentToolsSkills.wlt:130,1-134,2"
]

VerificationTest[
    withTestEnvironment @ MemberQ[ DeployedAgentTools[ "ClaudeCode" ], _? (#[ "UUID" ] === $dep[ "UUID" ] &) ],
    True,
    TestID -> "Bundle-Project-Listed@@Tests/DeployAgentToolsSkills.wlt:136,1-140,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Redeploying*)
VerificationTest[
    withTestEnvironment @ DeployAgentTools[ { "ClaudeCode", $project }, $bundle, "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::DeploymentExists },
    SameTest -> MatchQ,
    TestID   -> "Bundle-Project-RedeployFails@@Tests/DeployAgentToolsSkills.wlt:145,1-151,2"
]

(* An edited in-memory skill is an update of the same source, so OverwriteTarget -> True is enough *)
VerificationTest[
    $editedBundle = <| $bundle, "AgentSkills" -> { LLMSkill[ { "mem-skill", "A skill defined in memory." }, "Edited body." ], File @ $dirSkill } |>;
    $dep2 = withTestEnvironment @ DeployAgentTools[ { "ClaudeCode", $project }, $editedBundle, OverwriteTarget -> True, "VerifyLLMKit" -> False ],
    _AgentToolsDeployment? agentToolsDeploymentQ,
    SameTest -> MatchQ,
    TestID   -> "Bundle-Project-RedeployOverwrite@@Tests/DeployAgentToolsSkills.wlt:154,1-160,2"
]

VerificationTest[
    {
        StringContainsQ[ ReadString @ skillFile[ FileNameJoin @ { $project, ".claude", "skills" }, "mem-skill" ], "Edited body." ],
        withTestEnvironment @ FileExistsQ @ $dep[ "Location" ],
        AllTrue[ registryEntries[ ], #[ "References" ] === { withTestEnvironment @ $dep2[ "UUID" ] } & ]
    },
    { True, False, True },
    TestID -> "Bundle-Project-RedeployOverwrite-State@@Tests/DeployAgentToolsSkills.wlt:162,1-170,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DeleteObject*)
VerificationTest[
    withTestEnvironment @ DeleteObject @ $dep2,
    Null,
    TestID -> "Bundle-Project-Delete@@Tests/DeployAgentToolsSkills.wlt:175,1-179,2"
]

VerificationTest[
    {
        DirectoryQ @ FileNameJoin @ { $project, ".claude", "skills", "mem-skill" },
        DirectoryQ @ FileNameJoin @ { $project, ".claude", "skills", "dir-skill" },
        KeyExistsQ[ readJSON[ FileNameJoin @ { $project, ".mcp.json" } ][ "mcpServers" ], "Wolfram" ],
        registryEntries[ ]
    },
    { False, False, False, { } },
    TestID -> "Bundle-Project-Delete-State@@Tests/DeployAgentToolsSkills.wlt:181,1-190,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Shared Skill Directories*)
(* Copilot CLI and VS Code both read ~/.copilot/skills *)
VerificationTest[
    $copilotDep = withTestEnvironment @ DeployAgentTools[ "CopilotCLI", $skillsOnly ];
    $vscodeDep  = withTestEnvironment @ DeployAgentTools[ "VisualStudioCode", $skillsOnly ];
    { $copilotDep, $vscodeDep },
    { _AgentToolsDeployment? agentToolsDeploymentQ, _AgentToolsDeployment? agentToolsDeploymentQ },
    SameTest -> MatchQ,
    TestID   -> "Shared-DeployTwoClients@@Tests/DeployAgentToolsSkills.wlt:196,1-203,2"
]

VerificationTest[
    {
        withTestEnvironment @ FileExistsQ @ skillFile[ $copilotSkills, "dir-skill" ],
        Sort @ registryEntry[ "dir-skill" ][ "References" ],
        withTestEnvironment @ $copilotDep[ "MCPServerNames" ],
        withTestEnvironment @ $copilotDep[ "ConfigFile" ]
    },
    { True, Sort @ withTestEnvironment @ { $copilotDep[ "UUID" ], $vscodeDep[ "UUID" ] }, { }, _Missing },
    SameTest -> MatchQ,
    TestID   -> "Shared-OneDirectoryTwoReferences@@Tests/DeployAgentToolsSkills.wlt:205,1-215,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $copilotDep,
    Null,
    { AgentToolsDeployment::AgentSkillInUse },
    TestID -> "Shared-DeleteFirst-InUse@@Tests/DeployAgentToolsSkills.wlt:217,1-222,2"
]

VerificationTest[
    { withTestEnvironment @ FileExistsQ @ skillFile[ $copilotSkills, "dir-skill" ], registryEntry[ "dir-skill" ][ "References" ] },
    { True, withTestEnvironment @ { $vscodeDep[ "UUID" ] } },
    TestID -> "Shared-DeleteFirst-State@@Tests/DeployAgentToolsSkills.wlt:224,1-228,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $vscodeDep;
    { withTestEnvironment @ DirectoryQ @ FileNameJoin @ { $copilotSkills, "dir-skill" }, registryEntry[ "dir-skill" ] },
    { False, _Missing },
    SameTest -> MatchQ,
    TestID   -> "Shared-DeleteLast-Removed@@Tests/DeployAgentToolsSkills.wlt:230,1-236,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Modified and Foreign Skills*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Modified Skill Is Kept*)
VerificationTest[
    $modDep = withTestEnvironment @ DeployAgentTools[ "Codex", $skillsOnly ];
    withTestEnvironment @ WriteString[ skillFile[ $agentsSkills, "dir-skill" ], "\nUser notes.\n" ];
    withTestEnvironment @ Close @ skillFile[ $agentsSkills, "dir-skill" ];
    withTestEnvironment @ DeleteObject @ $modDep,
    Null,
    { AgentToolsDeployment::AgentSkillNotRemoved },
    TestID -> "Modified-KeptWithWarning@@Tests/DeployAgentToolsSkills.wlt:245,1-253,2"
]

VerificationTest[
    { withTestEnvironment @ FileExistsQ @ skillFile[ $agentsSkills, "dir-skill" ], registryEntry[ "dir-skill" ] },
    { True, _Missing },
    SameTest -> MatchQ,
    TestID   -> "Modified-KeptState@@Tests/DeployAgentToolsSkills.wlt:255,1-260,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Foreign Skill Requires All*)
(* The modified copy left behind above now belongs to the user *)
VerificationTest[
    withTestEnvironment @ DeployAgentTools[ "Codex", $skillsOnly ],
    _Failure,
    { DeployAgentTools::AgentSkillExists },
    SameTest -> MatchQ,
    TestID   -> "Foreign-Fails@@Tests/DeployAgentToolsSkills.wlt:266,1-272,2"
]

VerificationTest[
    withTestEnvironment @ DeployAgentTools[ "Codex", $skillsOnly, OverwriteTarget -> True ],
    _Failure,
    { DeployAgentTools::AgentSkillExists },
    SameTest -> MatchQ,
    TestID   -> "Foreign-OverwriteTrueFails@@Tests/DeployAgentToolsSkills.wlt:274,1-280,2"
]

VerificationTest[
    { withTestEnvironment @ DeployedAgentTools[ "Codex" ], StringContainsQ[ withTestEnvironment @ ReadString @ skillFile[ $agentsSkills, "dir-skill" ], "User notes." ] },
    { { }, True },
    TestID -> "Foreign-NothingChanged@@Tests/DeployAgentToolsSkills.wlt:282,1-286,2"
]

VerificationTest[
    $forcedDep = withTestEnvironment @ DeployAgentTools[ "Codex", $skillsOnly, OverwriteTarget -> All ],
    _AgentToolsDeployment? agentToolsDeploymentQ,
    SameTest -> MatchQ,
    TestID   -> "Foreign-OverwriteAll@@Tests/DeployAgentToolsSkills.wlt:288,1-293,2"
]

VerificationTest[
    { StringContainsQ[ withTestEnvironment @ ReadString @ skillFile[ $agentsSkills, "dir-skill" ], "User notes." ], registryEntry[ "dir-skill" ][ "External" ] },
    { False, False },
    TestID -> "Foreign-OverwriteAll-State@@Tests/DeployAgentToolsSkills.wlt:295,1-299,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $forcedDep;
    withTestEnvironment @ DirectoryQ @ FileNameJoin @ { $agentsSkills, "dir-skill" },
    False,
    TestID -> "Foreign-OverwriteAll-Delete@@Tests/DeployAgentToolsSkills.wlt:301,1-306,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Identical Pre-Existing Skill Is External*)
VerificationTest[
    withTestEnvironment @ CopyDirectory[ $dirSkill, FileNameJoin @ { $agentsSkills, "dir-skill" } ];
    $extDep = withTestEnvironment @ DeployAgentTools[ "Goose", $skillsOnly ];
    registryEntry[ "dir-skill" ][ "External" ],
    True,
    TestID -> "External-Adopted@@Tests/DeployAgentToolsSkills.wlt:311,1-317,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $extDep;
    { withTestEnvironment @ FileExistsQ @ skillFile[ $agentsSkills, "dir-skill" ], registryEntry[ "dir-skill" ] },
    { True, _Missing },
    SameTest -> MatchQ,
    TestID   -> "External-KeptOnDelete@@Tests/DeployAgentToolsSkills.wlt:319,1-325,2"
]

VerificationTest[
    withTestEnvironment @ DeleteDirectory[ FileNameJoin @ { $agentsSkills, "dir-skill" }, DeleteContents -> True ],
    Null,
    TestID -> "External-Cleanup@@Tests/DeployAgentToolsSkills.wlt:327,1-331,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Several Bundles on One Client*)
VerificationTest[
    $mcpBundle  = withTestEnvironment @ DeployAgentTools[ "ClaudeCode", <| "Name" -> "ServerBundle", "MCPServers" -> { "WolframLanguage" } |>, "VerifyLLMKit" -> False ];
    $skillsDep  = withTestEnvironment @ DeployAgentTools[ "ClaudeCode", $skillsOnly ];
    { $mcpBundle, $skillsDep },
    { _AgentToolsDeployment? agentToolsDeploymentQ, _AgentToolsDeployment? agentToolsDeploymentQ },
    SameTest -> MatchQ,
    TestID   -> "SeveralBundles-Coexist@@Tests/DeployAgentToolsSkills.wlt:336,1-343,2"
]

(* The built-in bundles share the "Wolfram" config key with ServerBundle *)
VerificationTest[
    withTestEnvironment @ DeployAgentTools[ "ClaudeCode", "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::DeploymentExists },
    SameTest -> MatchQ,
    TestID   -> "SeveralBundles-SharedKeyConflicts@@Tests/DeployAgentToolsSkills.wlt:346,1-352,2"
]

VerificationTest[
    $wolframDep = withTestEnvironment @ DeployAgentTools[ "ClaudeCode", "Wolfram", OverwriteTarget -> True, "VerifyLLMKit" -> False ];
    withTestEnvironment @ Sort[ #[ "Toolset" ] & /@ DeployedAgentTools[ "ClaudeCode" ] ],
    { "SkillsOnly", "Wolfram" },
    TestID -> "SeveralBundles-ReplaceOnlyConflicting@@Tests/DeployAgentToolsSkills.wlt:354,1-359,2"
]

VerificationTest[
    withTestEnvironment @ KeyExistsQ[ readJSON[ FileNameJoin @ { $HomeDirectory, ".claude.json" } ][ "mcpServers" ], "Wolfram" ],
    True,
    TestID -> "SeveralBundles-ReplacementKeepsSharedKey@@Tests/DeployAgentToolsSkills.wlt:361,1-365,2"
]

VerificationTest[
    withTestEnvironment[ DeleteObject /@ DeployedAgentTools[ "ClaudeCode" ] ];
    withTestEnvironment @ DeployedAgentTools[ "ClaudeCode" ],
    { },
    TestID -> "SeveralBundles-Cleanup@@Tests/DeployAgentToolsSkills.wlt:367,1-372,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Partial Support*)
VerificationTest[
    $lmDep = withTestEnvironment @ DeployAgentTools[ "LMStudio", $bundle, "VerifyLLMKit" -> False ],
    _AgentToolsDeployment? agentToolsDeploymentQ,
    { DeployAgentTools::AgentSkillsNotDeployed },
    SameTest -> MatchQ,
    TestID   -> "Partial-NoSkillsSupport@@Tests/DeployAgentToolsSkills.wlt:377,1-383,2"
]

VerificationTest[
    withTestEnvironment @ { $lmDep[ "AgentSkills" ], $lmDep[ "Skills" ][ "Skipped" ], $lmDep[ "MCPServerNames" ] },
    { { }, { "mem-skill", "dir-skill" }, { "WolframLanguage" } },
    TestID -> "Partial-NoSkillsSupport-Record@@Tests/DeployAgentToolsSkills.wlt:385,1-389,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $lmDep,
    Null,
    TestID -> "Partial-NoSkillsSupport-Delete@@Tests/DeployAgentToolsSkills.wlt:391,1-395,2"
]

VerificationTest[
    withTestEnvironment @ DeployAgentTools[ "LMStudio", $skillsOnly ],
    _Failure,
    { DeployAgentTools::UnsupportedSkillsClient },
    SameTest -> MatchQ,
    TestID   -> "Partial-NothingDeployable@@Tests/DeployAgentToolsSkills.wlt:397,1-403,2"
]

(* Cursor has project skills but no project MCP configuration *)
VerificationTest[
    $cursorProject = CreateDirectory[ ];
    $cursorDep = withTestEnvironment @ DeployAgentTools[ { "Cursor", $cursorProject }, $bundle, "VerifyLLMKit" -> False ],
    _AgentToolsDeployment? agentToolsDeploymentQ,
    { DeployAgentTools::MCPServersNotDeployed },
    SameTest -> MatchQ,
    TestID   -> "Partial-NoProjectMCP@@Tests/DeployAgentToolsSkills.wlt:406,1-413,2"
]

VerificationTest[
    {
        FileExistsQ @ skillFile[ FileNameJoin @ { $cursorProject, ".cursor", "skills" }, "mem-skill" ],
        withTestEnvironment @ $cursorDep[ "MCPServerNames" ],
        withTestEnvironment @ $cursorDep[ "MCP" ]
    },
    { True, { }, _Missing },
    SameTest -> MatchQ,
    TestID   -> "Partial-NoProjectMCP-Record@@Tests/DeployAgentToolsSkills.wlt:415,1-424,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $cursorDep;
    DirectoryQ @ FileNameJoin @ { $cursorProject, ".cursor", "skills", "mem-skill" },
    False,
    TestID -> "Partial-NoProjectMCP-Delete@@Tests/DeployAgentToolsSkills.wlt:426,1-431,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SkillsDirectory Option*)
VerificationTest[
    $customSkills = CreateDirectory[ ];
    $customDep = withTestEnvironment @ DeployAgentTools[ "ClaudeCode", $skillsOnly, "SkillsDirectory" -> File @ $customSkills ];
    { FileExistsQ @ skillFile[ $customSkills, "dir-skill" ], withTestEnvironment @ $customDep[ "SkillsDirectory" ] },
    { True, File @ $customSkills },
    TestID -> "SkillsDirectoryOption-Custom@@Tests/DeployAgentToolsSkills.wlt:436,1-442,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $customDep;
    DirectoryQ @ FileNameJoin @ { $customSkills, "dir-skill" },
    False,
    TestID -> "SkillsDirectoryOption-Delete@@Tests/DeployAgentToolsSkills.wlt:444,1-449,2"
]

VerificationTest[
    withTestEnvironment @ DeployAgentTools[ "ClaudeCode", $skillsOnly, "SkillsDirectory" -> 123 ],
    _Failure,
    { DeployAgentTools::InvalidSkillsDirectoryOption },
    SameTest -> MatchQ,
    TestID   -> "SkillsDirectoryOption-Invalid@@Tests/DeployAgentToolsSkills.wlt:451,1-457,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Rollback*)
(* A read-only parent directory makes writing skills fail after the MCP server has been installed (skill conflicts are
   detected before anything is written, so they can't be used to test rolling back). Unix only. *)
If[ $OperatingSystem =!= "Windows",
    VerificationTest[
        $rollbackProject = CreateDirectory[ ];
        $readOnly = CreateDirectory @ FileNameJoin @ { $rollbackProject, "read-only" };
        Run[ "chmod 555 '" <> $readOnly <> "'" ];
        withTestEnvironment @ DeployAgentTools[
            { "ClaudeCode", $rollbackProject },
            $bundle,
            "SkillsDirectory" -> File @ FileNameJoin @ { $readOnly, "skills" },
            "VerifyLLMKit"    -> False
        ],
        _Failure,
        { DeployAgentTools::AgentSkillWriteFailed },
        SameTest -> MatchQ,
        TestID   -> "Rollback-Fails@@Tests/DeployAgentToolsSkills.wlt:465,5-479,6"
    ];

    VerificationTest[
        {
            FileExistsQ @ FileNameJoin @ { $rollbackProject, ".mcp.json" },
            withTestEnvironment @ DeployedAgentTools[ "ClaudeCode" ],
            registryEntries[ ]
        },
        { False, { }, { } },
        TestID -> "Rollback-NothingLeft@@Tests/DeployAgentToolsSkills.wlt:481,5-489,6"
    ];

    VerificationTest[
        Run[ "chmod 755 '" <> $readOnly <> "'" ],
        0,
        TestID -> "Rollback-Cleanup@@Tests/DeployAgentToolsSkills.wlt:491,5-495,6"
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Version 1 Records*)
VerificationTest[
    $v1Config = File @ FileNameJoin @ { CreateDirectory[ ], "v1_config.json" };
    withTestEnvironment @ InstallMCPServer[ $v1Config, "WolframLanguage", "VerifyLLMKit" -> False ];
    $v1UUID = CreateUUID[ ];
    withTestEnvironment @ Module[ { dir },
        dir = FileNameJoin @ { $deploymentsPath, "Unknown", $v1UUID };
        CreateDirectory[ dir, CreateIntermediateDirectories -> True ];
        Developer`WriteWXFFile[ FileNameJoin @ { dir, "Deployment.wxf" }, <|
            "UUID"          -> $v1UUID,
            "Version"       -> 1,
            "Timestamp"     -> Now,
            "PacletVersion" -> "2.2.0",
            "CreatedBy"     -> "DeployAgentTools",
            "Toolset"       -> "WolframLanguage",
            "MCP"           -> <|
                "ClientName" -> "Unknown",
                "Target"     -> $v1Config,
                "Server"     -> "WolframLanguage",
                "ConfigFile" -> $v1Config,
                "Options"    -> <| "VerifyLLMKit" -> False |>
            |>,
            "Skills"        -> <| |>,
            "Hooks"         -> <| |>,
            "Meta"          -> <| |>
        |> ]
    ];
    $v1Dep = withTestEnvironment @ AgentToolsDeployment @ $v1UUID;
    withTestEnvironment[ $v1Dep /@ { "Toolset", "ToolsetType", "MCPServerNames", "AgentSkills", "Scope" } ],
    { "WolframLanguage", "MCPServerObject", { "WolframLanguage" }, { }, _Missing },
    SameTest -> MatchQ,
    TestID   -> "V1-Normalized@@Tests/DeployAgentToolsSkills.wlt:501,1-532,2"
]

VerificationTest[
    withTestEnvironment @ DeployAgentTools[ $v1Config, "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::DeploymentExists },
    SameTest -> MatchQ,
    TestID   -> "V1-ConflictDetected@@Tests/DeployAgentToolsSkills.wlt:534,1-540,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $v1Dep;
    KeyExistsQ[ readJSON @ $v1Config, "mcpServers" ] && ! KeyExistsQ[ readJSON[ $v1Config ][ "mcpServers" ], "Wolfram" ],
    True,
    TestID -> "V1-Delete@@Tests/DeployAgentToolsSkills.wlt:542,1-547,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Older AgentTools Versions*)
(* Older versions remove a deployment with UninstallMCPServer[ dep["ConfigFile"], dep["Toolset"] ], reading the raw
   record. In schema version 2 the top-level "Toolset" is the primary server name, so this still works. *)
VerificationTest[
    $oldProject = CreateDirectory[ ];
    $oldDep = withTestEnvironment @ DeployAgentTools[ { "ClaudeCode", $oldProject }, $bundle, "VerifyLLMKit" -> False ];
    withTestEnvironment @ UninstallMCPServer[ $oldDep[ "Data" ][ "MCP", "ConfigFile" ], $oldDep[ "Data" ][ "Toolset" ] ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "OldVersion-UninstallByRecordedToolset@@Tests/DeployAgentToolsSkills.wlt:554,1-561,2"
]

(* Simulate the old version deleting the record: the next sweep releases the orphaned skills *)
VerificationTest[
    withTestEnvironment @ DeleteDirectory[ First @ $oldDep[ "Location" ], DeleteContents -> True ];
    withTestEnvironment @ DeployAgentTools[ "Zed", <| "Name" -> "Unrelated", "AgentSkills" -> { $memSkill } |> ];
    {
        DirectoryQ @ FileNameJoin @ { $oldProject, ".claude", "skills", "dir-skill" },
        DirectoryQ @ FileNameJoin @ { $oldProject, ".claude", "skills", "mem-skill" }
    },
    { False, False },
    TestID -> "OldVersion-SweepReleasesOrphans@@Tests/DeployAgentToolsSkills.wlt:564,1-573,2"
]

VerificationTest[
    withTestEnvironment[ DeleteObject /@ DeployedAgentTools[ ] ];
    withTestEnvironment @ { DeployedAgentTools[ ], registryEntries[ ] },
    { { }, { } },
    TestID -> "OldVersion-Cleanup@@Tests/DeployAgentToolsSkills.wlt:575,1-580,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paclet Bundles*)
$mockPacletDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources", "MockMCPPacletSkills" };
PacletDirectoryLoad @ $mockPacletDirectory;

VerificationTest[
    $pacletProject = CreateDirectory[ ];
    $pacletDep = withTestEnvironment @ DeployAgentTools[ { "ClaudeCode", $pacletProject }, "MockMCPPacletSkills/SkillsBundle", "VerifyLLMKit" -> False ],
    _AgentToolsDeployment? agentToolsDeploymentQ,
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-Deploy@@Tests/DeployAgentToolsSkills.wlt:588,1-594,2"
]

VerificationTest[
    withTestEnvironment[ $pacletDep /@ { "Toolset", "ToolsetType", "MCPServerNames" } ],
    { "MockMCPPacletSkills/SkillsBundle", "AgentToolsObject", { "MockMCPPacletSkills/SkillsServer" } },
    TestID -> "PacletBundle-Properties@@Tests/DeployAgentToolsSkills.wlt:596,1-600,2"
]

VerificationTest[
    Sort @ withTestEnvironment @ $pacletDep[ "AgentSkills" ],
    Sort @ { "directory-skill", "assoc-skill", "llmskill-skill", "combined-skill", "located-skill", "foreign-skill" },
    TestID -> "PacletBundle-Skills@@Tests/DeployAgentToolsSkills.wlt:602,1-606,2"
]

VerificationTest[
    {
        FileExistsQ @ FileNameJoin @ { $pacletProject, ".claude", "skills", "directory-skill", "scripts", "run.wls" },
        KeyExistsQ[ readJSON[ FileNameJoin @ { $pacletProject, ".mcp.json" } ][ "mcpServers" ], "SkillsServer" ],
        registryEntry[ "directory-skill" ][ "Identifier" ],
        registryEntry[ "directory-skill" ][ "Version" ]
    },
    { True, True, "MockMCPPacletSkills/directory-skill", "1.0.0" },
    TestID -> "PacletBundle-Installed@@Tests/DeployAgentToolsSkills.wlt:608,1-617,2"
]

(* The second bundle shares directory-skill: it gets another reference *)
VerificationTest[
    $devDep = withTestEnvironment @ DeployAgentTools[ { "ClaudeCode", $pacletProject }, "MockMCPPacletSkills/DevBundle", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::DeploymentExists },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-SharedServerConflicts@@Tests/DeployAgentToolsSkills.wlt:620,1-626,2"
]

VerificationTest[
    $devDep = withTestEnvironment @ DeployAgentTools[ { "ClaudeCode", $pacletProject }, "MockMCPPacletSkills/DevBundle", OverwriteTarget -> True, "VerifyLLMKit" -> False ];
    {
        withTestEnvironment @ Sort @ $devDep[ "AgentSkills" ],
        registryEntry[ "directory-skill" ][ "References" ],
        DirectoryQ @ FileNameJoin @ { $pacletProject, ".claude", "skills", "assoc-skill" },
        DirectoryQ @ FileNameJoin @ { $pacletProject, ".claude", "skills", "directory-skill" }
    },
    { { "dev-skill", "directory-skill" }, { withTestEnvironment @ $devDep[ "UUID" ] }, False, True },
    TestID -> "PacletBundle-ReplaceKeepsSharedSkill@@Tests/DeployAgentToolsSkills.wlt:628,1-638,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $devDep;
    { DirectoryQ @ FileNameJoin @ { $pacletProject, ".claude", "skills", "directory-skill" }, registryEntries[ ] },
    { False, { } },
    TestID -> "PacletBundle-Delete@@Tests/DeployAgentToolsSkills.wlt:640,1-645,2"
]

(* The paclet name refers to the paclet's bundles; it has several, so the name is ambiguous *)
VerificationTest[
    withTestEnvironment @ DeployAgentTools[ "ClaudeCode", "MockMCPPacletSkills", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::AgentToolsBundleNameAmbiguous },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-PacletNameAmbiguous@@Tests/DeployAgentToolsSkills.wlt:648,1-654,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Remote Paclets*)
(* The mock paclet is made "remote" (PacletFindRemote returns a URL-located copy of it), and PacletInstall is stubbed
   to load the local copy. *)
$remoteInstallCalls = { };
$remoteMockPaclet = PacletObject @ Append[ First @ Get @ FileNameJoin @ { $mockPacletDirectory, "PacletInfo.wl" }, "Location" -> "https://example.com/pacletsite" ];

withRemoteMockPaclet // Attributes = { HoldFirst };
withRemoteMockPaclet[ eval_ ] := Block[
    {
        PacletFindRemote = Function[ If[ StringMatchQ[ "MockMCPPacletSkills", First @ { ## } ], { $remoteMockPaclet }, { } ] ],
        PacletInstall    = Function[
            AppendTo[ $remoteInstallCalls, First @ { ## } ];
            If[ First @ { ## } === "MockMCPPacletSkills",
                PacletDirectoryLoad @ $mockPacletDirectory; First @ PacletFind[ "MockMCPPacletSkills" ],
                $Failed
            ]
        ]
    },
    withTestEnvironment @ eval
];

VerificationTest[
    PacletDirectoryUnload @ $mockPacletDirectory;
    $remoteServerDep = withRemoteMockPaclet @ DeployAgentTools[ "Cursor", MCPServerObject[ "MockMCPPacletSkills/SkillsServer" ], "VerifyLLMKit" -> False ];
    { $remoteServerDep, $remoteInstallCalls },
    { _AgentToolsDeployment? agentToolsDeploymentQ, { "MockMCPPacletSkills" } },
    SameTest -> MatchQ,
    TestID   -> "Remote-ServerObjectInstallsPaclet@@Tests/DeployAgentToolsSkills.wlt:679,1-686,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $remoteServerDep;
    PacletDirectoryUnload @ $mockPacletDirectory;
    $remoteInstallCalls = { };
    $remoteProject = CreateDirectory[ ];
    $remoteBundleDep = withRemoteMockPaclet @ DeployAgentTools[ { "ClaudeCode", $remoteProject }, "MockMCPPacletSkills/SkillsBundle", "VerifyLLMKit" -> False ];
    { $remoteBundleDep, $remoteInstallCalls, FileExistsQ @ skillFile[ FileNameJoin @ { $remoteProject, ".claude", "skills" }, "directory-skill" ] },
    { _AgentToolsDeployment? agentToolsDeploymentQ, { "MockMCPPacletSkills" }, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-BundleInstallsPaclet@@Tests/DeployAgentToolsSkills.wlt:688,1-698,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $remoteBundleDep;
    PacletDirectoryUnload @ $mockPacletDirectory;
    $remoteInstallCalls = { };
    {
        withRemoteMockPaclet @ Quiet @ DeployAgentTools[ "ClaudeCode", "*/SkillsBundle", "VerifyLLMKit" -> False ],
        withRemoteMockPaclet @ Quiet @ DeployAgentTools[ "ClaudeCode", "MockMCPPacletSk*/SkillsBundle", "VerifyLLMKit" -> False ],
        withRemoteMockPaclet @ Quiet @ DeployAgentTools[ "ClaudeCode", <| "Name" -> "Wild", "MCPServers" -> { "*/SkillsServer" } |>, "VerifyLLMKit" -> False ],
        $remoteInstallCalls
    },
    { _Failure, _Failure, _Failure, { } },
    SameTest -> MatchQ,
    TestID   -> "Remote-WildcardsNeverInstall@@Tests/DeployAgentToolsSkills.wlt:700,1-713,2"
]

VerificationTest[
    PacletDirectoryLoad @ $mockPacletDirectory;
    PacletFind[ "MockMCPPacletSkills" ],
    { __PacletObject },
    SameTest -> MatchQ,
    TestID   -> "Remote-Restore@@Tests/DeployAgentToolsSkills.wlt:715,1-721,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Accented Frontmatter*)
(* LLMSkill[File[dir]] can't parse frontmatter with characters in U+0080-U+00FF; AgentTools reads it itself *)
VerificationTest[
    $accentedSource = CreateDirectory[ ];
    $accentedSkill  = FileNameJoin @ { $accentedSource, "cafe-skill" };
    CreateDirectory @ $accentedSkill;
    With[ { stream = OpenWrite[ FileNameJoin @ { $accentedSkill, "SKILL.md" }, BinaryFormat -> True ] },
        BinaryWrite[ stream, StringToByteArray[ "---\nname: cafe-skill\ndescription: Caf\[EAcute] helper for the Schr\[ODoubleDot]dinger equation\n---\n\nBody.\n", "UTF-8" ] ];
        Close @ stream
    ];
    $accentedDep = withTestEnvironment @ DeployAgentTools[ "Zed", <| "Name" -> "Accented", "AgentSkills" -> { File @ $accentedSkill } |> ],
    _AgentToolsDeployment? agentToolsDeploymentQ,
    SameTest -> MatchQ,
    TestID   -> "Accented-Deploy@@Tests/DeployAgentToolsSkills.wlt:727,1-739,2"
]

VerificationTest[
    {
        withTestEnvironment @ FileExistsQ @ skillFile[ $agentsSkills, "cafe-skill" ],
        AgentToolsObject[ <| "Name" -> "Accented", "AgentSkills" -> { File @ $accentedSkill } |> ][ "AgentSkillNames" ],
        #[ "Description" ] & /@ AgentToolsObject[ <| "Name" -> "Accented", "AgentSkills" -> { File @ $accentedSkill } |> ][ "LLMSkills" ]
    },
    { True, { "cafe-skill" }, { "Caf\[EAcute] helper for the Schr\[ODoubleDot]dinger equation" } },
    TestID -> "Accented-Properties@@Tests/DeployAgentToolsSkills.wlt:741,1-749,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $accentedDep;
    withTestEnvironment @ DirectoryQ @ FileNameJoin @ { $agentsSkills, "cafe-skill" },
    False,
    TestID -> "Accented-Delete@@Tests/DeployAgentToolsSkills.wlt:751,1-756,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Per-Skill Symbolic Links*)
(* A client's skill directory that is a link to another client's skill directory is a different skill directory: it
   never takes over the other directory's registry entry. Unix only. *)
If[ $OperatingSystem =!= "Windows",
    VerificationTest[
        $linkCodexDep = withTestEnvironment @ DeployAgentTools[ "Codex", $skillsOnly ];
        withTestEnvironment @ If[ ! DirectoryQ @ $claudeSkills, CreateDirectory[ $claudeSkills, CreateIntermediateDirectories -> True ] ];
        withTestEnvironment @ Run[ "ln -s '" <> FileNameJoin @ { $agentsSkills, "dir-skill" } <> "' '" <> FileNameJoin @ { $claudeSkills, "dir-skill" } <> "'" ];
        $linkClaudeDep = withTestEnvironment @ DeployAgentTools[ "ClaudeCode", $skillsOnly, OverwriteTarget -> All ];
        Length @ registryEntries[ ],
        2,
        TestID -> "PerSkillLink-TwoEntries@@Tests/DeployAgentToolsSkills.wlt:764,5-772,6"
    ];

    VerificationTest[
        withTestEnvironment[ DeleteObject /@ { $linkCodexDep, $linkClaudeDep } ];
        withTestEnvironment @ {
            DirectoryQ @ FileNameJoin @ { $agentsSkills, "dir-skill" },
            DirectoryQ @ FileNameJoin @ { $claudeSkills, "dir-skill" },
            registryEntries[ ]
        },
        { False, False, { } },
        TestID -> "PerSkillLink-BothRemoved@@Tests/DeployAgentToolsSkills.wlt:774,5-783,6"
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Publisher-Named Paclets*)
(* An installed paclet that only shares a publisher's name ("RvPubX") doesn't hide a remote paclet with exactly the
   two-segment name ("RvPubX/Tools") *)
VerificationTest[
    $pubDirectory = CreateDirectory[ ];
    $pubPaclet = FileNameJoin @ { $pubDirectory, "RvPubX" };
    CreateDirectory @ $pubPaclet;
    Export[ FileNameJoin @ { $pubPaclet, "PacletInfo.wl" }, "PacletObject[<|\"Name\" -> \"RvPubX\", \"Version\" -> \"1.0.0\", \"Extensions\" -> {{\"Kernel\", \"Root\" -> \"Kernel\", \"Context\" -> {\"RvPubX`\"}}}|>]", "Text" ];
    $toolsPaclet = FileNameJoin @ { $pubDirectory, "RvPubX__Tools" };
    CreateDirectory @ FileNameJoin @ { $toolsPaclet, "AgentTools", "AgentSkills", "rvpubx-skill" };
    Export[ FileNameJoin @ { $toolsPaclet, "PacletInfo.wl" }, "PacletObject[<|\"Name\" -> \"RvPubX/Tools\", \"Version\" -> \"1.0.0\", \"Extensions\" -> {{\"AgentTools\", \"AgentSkills\" -> {\"rvpubx-skill\"}}}|>]", "Text" ];
    Export[ FileNameJoin @ { $toolsPaclet, "AgentTools", "AgentSkills", "rvpubx-skill", "SKILL.md" }, "---\nname: rvpubx-skill\ndescription: A skill of a paclet named after its publisher.\n---\n\nBody.\n", "Text" ];
    $toolsRemote = PacletObject @ Append[ First @ Get @ FileNameJoin @ { $toolsPaclet, "PacletInfo.wl" }, "Location" -> "https://example.com/pacletsite" ];
    PacletDirectoryLoad @ $pubPaclet;
    $pubInstallCalls = { };
    $pubDep = Block[
        {
            PacletFindRemote = Function[ If[ First @ { ## } === "RvPubX/Tools", { $toolsRemote }, { } ] ],
            PacletInstall    = Function[
                AppendTo[ $pubInstallCalls, First @ { ## } ];
                If[ First @ { ## } === "RvPubX/Tools", PacletDirectoryLoad @ $toolsPaclet; First @ PacletFind[ "RvPubX/Tools" ], $Failed ]
            ]
        },
        withTestEnvironment @ DeployAgentTools[ "Zed", "RvPubX/Tools" ]
    ];
    { $pubDep, $pubInstallCalls },
    { _AgentToolsDeployment? agentToolsDeploymentQ, { "RvPubX/Tools" } },
    SameTest -> MatchQ,
    TestID   -> "PublisherNamedPaclet-RemoteFound@@Tests/DeployAgentToolsSkills.wlt:791,1-817,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $pubDep;
    PacletDirectoryUnload /@ { $pubPaclet, $toolsPaclet };
    Quiet @ DeleteDirectory[ $pubDirectory, DeleteContents -> True ],
    Null,
    TestID -> "PublisherNamedPaclet-Cleanup@@Tests/DeployAgentToolsSkills.wlt:819,1-825,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Relative Project Directories*)
VerificationTest[
    $relativeParent = CreateDirectory[ ];
    CreateDirectory @ FileNameJoin @ { $relativeParent, "relproj" };
    SetDirectory @ $relativeParent;
    $relativeDep = WithCleanup[
        withTestEnvironment @ DeployAgentTools[ { "ClaudeCode", "relproj" }, $skillsOnly ],
        ResetDirectory[ ]
    ];
    withTestEnvironment @ $relativeDep[ "SkillsDirectory" ],
    File @ FileNameJoin @ { $relativeParent, "relproj", ".claude", "skills" },
    TestID -> "RelativeProject-AbsoluteSkillsDirectory@@Tests/DeployAgentToolsSkills.wlt:830,1-841,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $relativeDep;
    Quiet @ DeleteDirectory[ $relativeParent, DeleteContents -> True ],
    Null,
    TestID -> "RelativeProject-Cleanup@@Tests/DeployAgentToolsSkills.wlt:843,1-848,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Global Config Files with Native Separators*)
(* A client's global config file given with Windows separators is still recognized as global *)
VerificationTest[
    Block[ { $HomeDirectory = "C:\\Users\\x" },
        Wolfram`AgentTools`DeployAgentTools`Private`fileTargetLocation[ File[ "C:\\Users\\x\\.claude.json" ], "Unknown", Automatic ]
    ][ "Scope" ],
    "Global",
    TestID -> "NativeSeparators-GlobalConfig@@Tests/DeployAgentToolsSkills.wlt:854,1-860,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Release Messages*)
(* A skill directory replaced by a file: there's nothing for UninstallAgentSkills to remove *)
VerificationTest[
    $replacedProject = CreateDirectory[ ];
    $replacedDep = withTestEnvironment @ DeployAgentTools[ { "ClaudeCode", $replacedProject }, $skillsOnly ];
    DeleteDirectory[ FileNameJoin @ { $replacedProject, ".claude", "skills", "dir-skill" }, DeleteContents -> True ];
    Export[ FileNameJoin @ { $replacedProject, ".claude", "skills", "dir-skill" }, "not a skill", "Text" ];
    withTestEnvironment @ DeleteObject @ $replacedDep,
    Null,
    { AgentToolsDeployment::AgentSkillReplacedNotRemoved },
    TestID -> "ReleaseMessages-ReplacedByFile@@Tests/DeployAgentToolsSkills.wlt:866,1-875,2"
]

(* Removing an unmodified skill fails (the skills root's parent is read-only, so it can't be moved to a backup) *)
If[ $OperatingSystem =!= "Windows",
    VerificationTest[
        $lockedParent = CreateDirectory[ ];
        $lockedRoot = FileNameJoin @ { $lockedParent, "skills" };
        $lockedDep = withTestEnvironment @ DeployAgentTools[ "ClaudeCode", $skillsOnly, "SkillsDirectory" -> File @ $lockedRoot ];
        Run[ "chmod a-w '" <> $lockedParent <> "'" ];
        WithCleanup[
            withTestEnvironment @ DeleteObject @ $lockedDep,
            Run[ "chmod u+w '" <> $lockedParent <> "'" ]
        ],
        Null,
        { AgentToolsDeployment::AgentSkillRemoveFailed },
        TestID -> "ReleaseMessages-RemoveFailed@@Tests/DeployAgentToolsSkills.wlt:879,5-891,6"
    ];

    (* The registry entry is kept, so the next sweep removes the directory *)
    VerificationTest[
        withTestEnvironment @ Wolfram`AgentTools`Common`sweepSkillRegistry[ ];
        DirectoryQ @ FileNameJoin @ { $lockedRoot, "dir-skill" },
        False,
        TestID -> "ReleaseMessages-RemoveFailed-Retried@@Tests/DeployAgentToolsSkills.wlt:894,5-899,6"
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Installed Skill Directories as Sources*)
(* A bundle whose source is another deployment's installed skill, reached through a per-skill link: whichever deployment
   is deleted last removes the directory. Unix only. *)
If[ $OperatingSystem =!= "Windows",
    VerificationTest[
        $sameCodexDep = withTestEnvironment @ DeployAgentTools[ "Codex", $skillsOnly ];
        withTestEnvironment @ If[ ! DirectoryQ @ $claudeSkills, CreateDirectory[ $claudeSkills, CreateIntermediateDirectories -> True ] ];
        withTestEnvironment @ Run[ "ln -s '" <> FileNameJoin @ { $agentsSkills, "dir-skill" } <> "' '" <> FileNameJoin @ { $claudeSkills, "dir-skill" } <> "'" ];
        $sameClaudeDep = withTestEnvironment @ DeployAgentTools[
            "ClaudeCode",
            <| "Name" -> "FromInstalled", "AgentSkills" -> { withTestEnvironment @ File @ FileNameJoin @ { $agentsSkills, "dir-skill" } } |>
        ];
        { Length @ registryEntries[ ], Length @ First[ registryEntries[ ] ][ "References" ] },
        { 1, 2 },
        TestID -> "InstalledSource-OneEntry@@Tests/DeployAgentToolsSkills.wlt:908,5-919,6"
    ];

    VerificationTest[
        withTestEnvironment @ Quiet[ DeleteObject @ $sameCodexDep, AgentToolsDeployment::AgentSkillInUse ];
        withTestEnvironment @ DeleteObject @ $sameClaudeDep;
        withTestEnvironment @ {
            DirectoryQ @ FileNameJoin @ { $agentsSkills, "dir-skill" },
            registryEntries[ ]
        },
        { False, { } },
        TestID -> "InstalledSource-RemovedByLastDeployment@@Tests/DeployAgentToolsSkills.wlt:921,5-930,6"
    ];

    VerificationTest[
        withTestEnvironment @ Quiet @ DeleteFile @ FileNameJoin @ { $claudeSkills, "dir-skill" };
        withTestEnvironment @ FileExistsQ @ FileNameJoin @ { $claudeSkills, "dir-skill" },
        False,
        TestID -> "InstalledSource-Cleanup@@Tests/DeployAgentToolsSkills.wlt:932,5-937,6"
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*External Skills Reached Through Links*)
(* A user-installed skill in ~/.agents/skills, linked into ~/.claude/skills (the layout of skill managers). Unix only. *)
If[ $OperatingSystem =!= "Windows",
    resetLinkedSkill[ ] := withTestEnvironment[
        Quiet @ DeleteFile @ FileNameJoin @ { $claudeSkills, "dir-skill" };
        Quiet @ DeleteDirectory[ FileNameJoin @ { $agentsSkills, "dir-skill" }, DeleteContents -> True ];
        If[ ! DirectoryQ @ $claudeSkills, CreateDirectory[ $claudeSkills, CreateIntermediateDirectories -> True ] ];
        If[ ! DirectoryQ @ $agentsSkills, CreateDirectory[ $agentsSkills, CreateIntermediateDirectories -> True ] ];
        CopyDirectory[ $dirSkill, FileNameJoin @ { $agentsSkills, "dir-skill" } ];
        Run[ "ln -s '" <> FileNameJoin @ { $agentsSkills, "dir-skill" } <> "' '" <> FileNameJoin @ { $claudeSkills, "dir-skill" } <> "'" ];
    ];
    $viaLinkBundle := <| "Name" -> "ViaLink", "AgentSkills" -> { withTestEnvironment @ File @ FileNameJoin @ { $agentsSkills, "dir-skill" } } |>;

    (* Another client's deployment of the same source records the physical directory, not the other client's link *)
    VerificationTest[
        resetLinkedSkill[ ];
        $viaLinkClaude = withTestEnvironment @ DeployAgentTools[ "ClaudeCode", $viaLinkBundle ];
        $viaLinkCodex  = withTestEnvironment @ DeployAgentTools[ "Codex", $viaLinkBundle ];
        withTestEnvironment @ First[ $viaLinkCodex[ "Skills" ][ "Installed" ] ][ "Directory" ],
        withTestEnvironment @ File @ FileNameJoin @ { $agentsSkills, "dir-skill" },
        TestID -> "LinkedExternal-OwnDirectory@@Tests/DeployAgentToolsSkills.wlt:956,5-963,6"
    ];

    VerificationTest[
        withTestEnvironment @ DeleteObject @ $viaLinkClaude;
        withTestEnvironment @ DeleteObject @ $viaLinkCodex;
        { withTestEnvironment @ DirectoryQ @ FileNameJoin @ { $agentsSkills, "dir-skill" }, registryEntries[ ] },
        { True, { } },
        TestID -> "LinkedExternal-UserSkillKept@@Tests/DeployAgentToolsSkills.wlt:965,5-971,6"
    ];

    (* The user replaced the external skill and another client's deployment then wrote its own copy there: whichever
       deployment is deleted last removes it, even if the external alias is the last one *)
    VerificationTest[
        resetLinkedSkill[ ];
        $aliasClaude = withTestEnvironment @ DeployAgentTools[ "ClaudeCode", $viaLinkBundle ];
        withTestEnvironment @ DeleteDirectory[ FileNameJoin @ { $agentsSkills, "dir-skill" }, DeleteContents -> True ];
        $aliasCodex = withTestEnvironment @ DeployAgentTools[ "Codex", $skillsOnly ];
        withTestEnvironment @ DeleteObject @ $aliasCodex,
        Null,
        { AgentToolsDeployment::AgentSkillInUse },
        TestID -> "LinkedExternal-OwnerDeletedFirst@@Tests/DeployAgentToolsSkills.wlt:975,5-984,6"
    ];

    VerificationTest[
        withTestEnvironment @ DeleteObject @ $aliasClaude;
        { withTestEnvironment @ DirectoryQ @ FileNameJoin @ { $agentsSkills, "dir-skill" }, registryEntries[ ] },
        { False, { } },
        TestID -> "LinkedExternal-RemovedAfterAlias@@Tests/DeployAgentToolsSkills.wlt:986,5-991,6"
    ];

    VerificationTest[
        withTestEnvironment @ Quiet @ DeleteFile @ FileNameJoin @ { $claudeSkills, "dir-skill" };
        withTestEnvironment @ FileExistsQ @ FileNameJoin @ { $claudeSkills, "dir-skill" },
        False,
        TestID -> "LinkedExternal-Cleanup@@Tests/DeployAgentToolsSkills.wlt:993,5-998,6"
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Invalid Toolsets*)
VerificationTest[
    withTestEnvironment @ DeployAgentTools[ "ClaudeCode", $skillsOnly, "SkillsDirectory" -> None ],
    _Failure,
    { DeployAgentTools::AgentSkillsDisabled },
    SameTest -> MatchQ,
    TestID   -> "Invalid-SkillsOnlyWithoutSkills@@Tests/DeployAgentToolsSkills.wlt:1004,1-1010,2"
]

VerificationTest[
    withTestEnvironment @ DeployAgentTools[ "ClaudeCode", "a/b/c/d", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::MCPServerNotFound },
    SameTest -> MatchQ,
    TestID   -> "Invalid-MalformedName@@Tests/DeployAgentToolsSkills.wlt:1012,1-1018,2"
]

VerificationTest[
    withTestEnvironment @ DeployAgentTools[ "ClaudeCode", "Wolfram/", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::MCPServerNotFound },
    SameTest -> MatchQ,
    TestID   -> "Invalid-TrailingSlash@@Tests/DeployAgentToolsSkills.wlt:1020,1-1026,2"
]

VerificationTest[
    withTestEnvironment @ DeployAgentTools[ File @ CreateDirectory[ ], "WolframLanguage", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::InvalidMCPConfiguration },
    SameTest -> MatchQ,
    TestID   -> "Invalid-DirectoryAsConfigFile@@Tests/DeployAgentToolsSkills.wlt:1028,1-1034,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Built-In Toolset Identity*)
(* A deployment of the built-in server with a custom config key is the same toolset as the built-in bundle *)
VerificationTest[
    $customKeyDep = withTestEnvironment @ DeployAgentTools[ "ClaudeCode", MCPServerObject[ "Wolfram" ], "MCPServerName" -> "Foo", "VerifyLLMKit" -> False ];
    withTestEnvironment @ DeployAgentTools[ "ClaudeCode", "Wolfram", "VerifyLLMKit" -> False ],
    _Failure,
    { DeployAgentTools::DeploymentExists },
    SameTest -> MatchQ,
    TestID   -> "BuiltInIdentity-Conflicts@@Tests/DeployAgentToolsSkills.wlt:1040,1-1047,2"
]

VerificationTest[
    withTestEnvironment @ DeployAgentTools[ "ClaudeCode", "Wolfram", OverwriteTarget -> True, "VerifyLLMKit" -> False ];
    {
        withTestEnvironment @ Sort @ Keys @ readJSON[ FileNameJoin @ { $HomeDirectory, ".claude.json" } ][ "mcpServers" ],
        withTestEnvironment @ Length @ DeployedAgentTools[ "ClaudeCode" ]
    },
    { { "Wolfram" }, 1 },
    TestID -> "BuiltInIdentity-Replaced@@Tests/DeployAgentToolsSkills.wlt:1049,1-1057,2"
]

VerificationTest[
    withTestEnvironment[ DeleteObject /@ DeployedAgentTools[ "ClaudeCode" ] ];
    withTestEnvironment @ DeployedAgentTools[ "ClaudeCode" ],
    { },
    TestID -> "BuiltInIdentity-Cleanup@@Tests/DeployAgentToolsSkills.wlt:1059,1-1064,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Replacement Warnings*)
(* Replacing a deployment whose skill was modified keeps the skill and says so *)
VerificationTest[
    $warnProject = CreateDirectory[ ];
    $warnBundle  = <| "Name" -> "WarnBundle", "AgentSkills" -> { $memSkill, File @ $dirSkill } |>;
    withTestEnvironment @ DeployAgentTools[ { "ClaudeCode", $warnProject }, $warnBundle ];
    WriteString[ skillFile[ FileNameJoin @ { $warnProject, ".claude", "skills" }, "dir-skill" ], "Edited.\n" ];
    Close @ skillFile[ FileNameJoin @ { $warnProject, ".claude", "skills" }, "dir-skill" ];
    withTestEnvironment @ DeployAgentTools[
        { "ClaudeCode", $warnProject },
        <| $warnBundle, "AgentSkills" -> { $memSkill } |>,
        OverwriteTarget -> True
    ],
    _AgentToolsDeployment? agentToolsDeploymentQ,
    { DeployAgentTools::AgentSkillNotRemoved },
    SameTest -> MatchQ,
    TestID   -> "ReplacementWarnings-ModifiedSkillKept@@Tests/DeployAgentToolsSkills.wlt:1070,1-1085,2"
]

VerificationTest[
    DirectoryQ @ FileNameJoin @ { $warnProject, ".claude", "skills", "dir-skill" },
    True,
    TestID -> "ReplacementWarnings-ModifiedSkillStillThere@@Tests/DeployAgentToolsSkills.wlt:1087,1-1091,2"
]

VerificationTest[
    withTestEnvironment[ DeleteObject /@ DeployedAgentTools[ "ClaudeCode" ] ];
    withTestEnvironment @ DeployedAgentTools[ "ClaudeCode" ],
    { },
    TestID -> "ReplacementWarnings-Cleanup@@Tests/DeployAgentToolsSkills.wlt:1093,1-1098,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*User Servers with Slashes*)
VerificationTest[
    withTestEnvironment @ CreateMCPServer[ "team/server", <| "Tools" -> { "WolframAlpha" } |> ];
    $teamDep = withTestEnvironment @ DeployAgentTools[
        "Cursor",
        <| "Name" -> "TeamBundle", "MCPServers" -> { "team/server" } |>,
        "VerifyLLMKit" -> False
    ],
    _AgentToolsDeployment? agentToolsDeploymentQ,
    SameTest -> MatchQ,
    TestID   -> "UserServerWithSlash-Deploys@@Tests/DeployAgentToolsSkills.wlt:1103,1-1113,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ $teamDep,
    Null,
    TestID -> "UserServerWithSlash-Delete@@Tests/DeployAgentToolsSkills.wlt:1115,1-1119,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DeployAgentTools[All, ...]*)
(* Codex, Goose, and Zed all use ~/.agents/skills *)
VerificationTest[
    $allResults = withTestEnvironment @ Block[
        {
            Wolfram`AgentTools`$SupportedClients    = KeyTake[ Wolfram`AgentTools`$SupportedClients, { "Codex", "Goose", "Zed" } ],
            Wolfram`AgentTools`$SupportedMCPClients = KeyTake[ Wolfram`AgentTools`$SupportedClients, { "Codex", "Goose", "Zed" } ]
        },
        DeployAgentTools[ All, $skillsOnly ]
    ],
    { _AgentToolsDeployment, _AgentToolsDeployment, _AgentToolsDeployment },
    SameTest -> MatchQ,
    TestID   -> "All-SharedDirectory@@Tests/DeployAgentToolsSkills.wlt:1125,1-1136,2"
]

VerificationTest[
    { Length @ registryEntry[ "dir-skill" ][ "References" ], withTestEnvironment @ FileExistsQ @ skillFile[ $agentsSkills, "dir-skill" ] },
    { 3, True },
    TestID -> "All-SharedDirectory-ThreeReferences@@Tests/DeployAgentToolsSkills.wlt:1138,1-1142,2"
]

VerificationTest[
    withTestEnvironment @ Quiet[ DeleteObject /@ Most @ $allResults, AgentToolsDeployment::AgentSkillInUse ];
    withTestEnvironment @ FileExistsQ @ skillFile[ $agentsSkills, "dir-skill" ],
    True,
    TestID -> "All-SharedDirectory-StillInUse@@Tests/DeployAgentToolsSkills.wlt:1144,1-1149,2"
]

VerificationTest[
    withTestEnvironment @ DeleteObject @ Last @ $allResults;
    withTestEnvironment @ DirectoryQ @ FileNameJoin @ { $agentsSkills, "dir-skill" },
    False,
    TestID -> "All-SharedDirectory-Removed@@Tests/DeployAgentToolsSkills.wlt:1151,1-1156,2"
]

VerificationTest[
    withTestEnvironment @ Block[
        {
            Wolfram`AgentTools`$SupportedClients    = KeyTake[ Wolfram`AgentTools`$SupportedClients, { "Codex", "LMStudio" } ],
            Wolfram`AgentTools`$SupportedMCPClients = KeyTake[ Wolfram`AgentTools`$SupportedClients, { "Codex", "LMStudio" } ]
        },
        DeployAgentTools[ All, $skillsOnly ]
    ],
    { _AgentToolsDeployment, Missing[ "Unsupported", { "LMStudio", _ } ] },
    SameTest -> MatchQ,
    TestID   -> "All-UnsupportedClient@@Tests/DeployAgentToolsSkills.wlt:1158,1-1169,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skill Directory Edge Cases*)
(* These tests use their own temporary home directory and AgentTools root. *)
$edgeHome = CreateDirectory[ ];
$edgeRoot = CreateDirectory[ ];

withEdgeEnvironment // Attributes = { HoldFirst };
withEdgeEnvironment[ eval_ ] :=
    Block[ { Wolfram`AgentTools`Common`$rootPath = $edgeRoot, $HomeDirectory = $edgeHome }, eval ];

edgeRegistryEntries[ ] := withEdgeEnvironment @ If[ DirectoryQ @ $skillRegistryPath,
    Developer`ReadWXFFile /@ FileNames[ "*.wxf", $skillRegistryPath ],
    { }
];

(* Rewrites a file with extra content appended (keeping it a valid SKILL.md) *)
appendToFile[ file_String, text_String ] :=
    With[ { content = ReadString @ file }, With[ { stream = OpenWrite @ file }, WriteString[ stream, content <> text ]; Close @ stream ] ];

(* File permissions are only enforced on Unix-like systems, and not for root *)
$permissionsEnforced = $OperatingSystem =!= "Windows" && Module[ { file, enforced },
    file = FileNameJoin @ { $edgeHome, "permissions-probe.txt" };
    Export[ file, "probe", "Text" ];
    RunProcess[ { "chmod", "000", file } ];
    enforced = ! ByteArrayQ @ Quiet @ ReadByteArray @ file;
    RunProcess[ { "chmod", "644", file } ];
    DeleteFile @ file;
    enforced
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Skills Root Moved Behind a Symbolic Link*)
(* The same skill directory deployed before and after its skills root started going through a symbolic link (e.g.
   ~/.agents moved into a dotfiles repository and linked back) has one registry entry: deleting the first deployment
   keeps the directory while the second still uses it. *)
If[ $OperatingSystem =!= "Windows",
    VerificationTest[
        withEdgeEnvironment @ Module[ { skills, skill },
            skills = FileNameJoin @ { $HomeDirectory, ".agents", "skills" };
            skill  = LLMSkill[ { "shared-skill", "A skill shared by two bundles." }, "Shared instructions." ];
            $linkDep1 = DeployAgentTools[ "ClaudeCode", <| "Name" -> "BundleOne", "AgentSkills" -> { skill } |>, "SkillsDirectory" -> File @ skills ];
            RenameDirectory[ FileNameJoin @ { $HomeDirectory, ".agents" }, FileNameJoin @ { $HomeDirectory, "dotfiles-agents" } ];
            RunProcess[ { "ln", "-s", FileNameJoin @ { $HomeDirectory, "dotfiles-agents" }, FileNameJoin @ { $HomeDirectory, ".agents" } } ];
            $linkDep2 = DeployAgentTools[ "ClaudeCode", <| "Name" -> "BundleTwo", "AgentSkills" -> { skill } |>, "SkillsDirectory" -> File @ skills ];
            {
                $linkDep1,
                $linkDep2,
                (Sort @ #[ "References" ] & /@ edgeRegistryEntries[ ]) === { Sort @ { $linkDep1[ "UUID" ], $linkDep2[ "UUID" ] } }
            }
        ],
        {
            _AgentToolsDeployment? agentToolsDeploymentQ,
            _AgentToolsDeployment? agentToolsDeploymentQ,
            True
        },
        SameTest -> MatchQ,
        TestID   -> "SymbolicLinkRoot-OneEntry@@Tests/DeployAgentToolsSkills.wlt:1209,5-1230,6"
    ];

    VerificationTest[
        withEdgeEnvironment @ DeleteObject @ $linkDep1;
        withEdgeEnvironment @ DirectoryQ @ FileNameJoin @ { $HomeDirectory, ".agents", "skills", "shared-skill" },
        True,
        { AgentToolsDeployment::AgentSkillInUse },
        TestID -> "SymbolicLinkRoot-DeleteFirst-InUse@@Tests/DeployAgentToolsSkills.wlt:1232,5-1238,6"
    ];

    VerificationTest[
        withEdgeEnvironment @ DeleteObject @ $linkDep2;
        { withEdgeEnvironment @ DirectoryQ @ FileNameJoin @ { $HomeDirectory, ".agents", "skills", "shared-skill" }, edgeRegistryEntries[ ] },
        { False, { } },
        TestID -> "SymbolicLinkRoot-DeleteLast-Removed@@Tests/DeployAgentToolsSkills.wlt:1240,5-1245,6"
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Modified Skill Used as a Source*)
(* A skill that one deployment installed and the user then modified is the source of another deployment: the changes
   are never adopted as removable content, so the directory is kept (and reported) when both are deleted. *)
VerificationTest[
    $sourceDepA = withEdgeEnvironment @ DeployAgentTools[
        "ClaudeCode",
        <| "Name" -> "BundleA", "AgentSkills" -> { LLMSkill[ { "custom-skill", "A skill the user customizes." }, "Original instructions." ] } |>
    ];
    $customSkillDir = withEdgeEnvironment @ FileNameJoin @ { $HomeDirectory, ".claude", "skills", "custom-skill" };
    appendToFile[ FileNameJoin @ { $customSkillDir, "SKILL.md" }, "\nUser customization.\n" ];
    $sourceDepB = withEdgeEnvironment @ DeployAgentTools[ "ClaudeCode", <| "Name" -> "BundleB", "AgentSkills" -> { File @ $customSkillDir } |> ];
    { $sourceDepA, $sourceDepB },
    { _AgentToolsDeployment? agentToolsDeploymentQ, _AgentToolsDeployment? agentToolsDeploymentQ },
    SameTest -> MatchQ,
    TestID   -> "ModifiedSource-Deploy@@Tests/DeployAgentToolsSkills.wlt:1253,1-1265,2"
]

VerificationTest[
    withEdgeEnvironment @ DeleteObject @ $sourceDepA,
    Null,
    { AgentToolsDeployment::AgentSkillInUse },
    TestID -> "ModifiedSource-DeleteFirst-InUse@@Tests/DeployAgentToolsSkills.wlt:1267,1-1272,2"
]

VerificationTest[
    withEdgeEnvironment @ DeleteObject @ $sourceDepB,
    Null,
    { AgentToolsDeployment::AgentSkillNotRemoved },
    TestID -> "ModifiedSource-DeleteLast-Kept@@Tests/DeployAgentToolsSkills.wlt:1274,1-1279,2"
]

VerificationTest[
    { StringContainsQ[ ReadString @ FileNameJoin @ { $customSkillDir, "SKILL.md" }, "User customization." ], edgeRegistryEntries[ ] },
    { True, { } },
    TestID -> "ModifiedSource-State@@Tests/DeployAgentToolsSkills.wlt:1281,1-1285,2"
]

VerificationTest[
    DeleteDirectory[ $customSkillDir, DeleteContents -> True ],
    Null,
    TestID -> "ModifiedSource-Cleanup@@Tests/DeployAgentToolsSkills.wlt:1287,1-1291,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Unreadable Skill Files*)
(* A file that can't be read makes an installed skill directory "Modified": DeleteObject keeps it with a warning
   instead of failing, redeploying is a normal conflict, and an orphaned registry entry for it can't block later
   deployments. Unix only (file permissions). *)
If[ $permissionsEnforced,
    VerificationTest[
        $lockedProject = CreateDirectory[ ];
        $lockedBundle  = <| "Name" -> "LockedBundle", "AgentSkills" -> { LLMSkill[ { "locked-skill", "A skill with an unreadable file." }, "Locked." ] } |>;
        $lockedDep     = withEdgeEnvironment @ DeployAgentTools[ { "ClaudeCode", $lockedProject }, $lockedBundle ];
        $lockedFile    = FileNameJoin @ { $lockedProject, ".claude", "skills", "locked-skill", "SKILL.md" };
        RunProcess[ { "chmod", "000", $lockedFile } ];
        withEdgeEnvironment @ DeleteObject @ $lockedDep,
        Null,
        { AgentToolsDeployment::AgentSkillNotRemoved },
        TestID -> "Unreadable-DeleteKeepsDirectory@@Tests/DeployAgentToolsSkills.wlt:1300,5-1310,6"
    ];

    VerificationTest[
        { FileExistsQ @ $lockedFile, withEdgeEnvironment @ DeployedAgentTools[ "ClaudeCode" ], edgeRegistryEntries[ ] },
        { True, { }, { } },
        TestID -> "Unreadable-DeleteKeepsDirectory-State@@Tests/DeployAgentToolsSkills.wlt:1312,5-1316,6"
    ];

    VerificationTest[
        withEdgeEnvironment @ DeployAgentTools[ { "ClaudeCode", $lockedProject }, $lockedBundle ],
        _Failure,
        { DeployAgentTools::AgentSkillExists },
        SameTest -> MatchQ,
        TestID   -> "Unreadable-RedeployConflict@@Tests/DeployAgentToolsSkills.wlt:1318,5-1324,6"
    ];

    VerificationTest[
        $lockedDep = withEdgeEnvironment @ DeployAgentTools[ { "ClaudeCode", $lockedProject }, $lockedBundle, OverwriteTarget -> All ];
        { $lockedDep, StringContainsQ[ ReadString @ $lockedFile, "Locked." ] },
        { _AgentToolsDeployment? agentToolsDeploymentQ, True },
        SameTest -> MatchQ,
        TestID   -> "Unreadable-RedeployOverwriteAll@@Tests/DeployAgentToolsSkills.wlt:1326,5-1332,6"
    ];

    (* the record is removed without releasing the skill (as an older AgentTools version would), and the skill file
       becomes unreadable: the sweep at the start of every later deploy must not fail on it *)
    VerificationTest[
        RunProcess[ { "chmod", "000", $lockedFile } ];
        withEdgeEnvironment @ DeleteDirectory[ First @ $lockedDep[ "Location" ], DeleteContents -> True ];
        $unrelatedProject = CreateDirectory[ ];
        $unrelatedDep = withEdgeEnvironment @ DeployAgentTools[
            { "ClaudeCode", $unrelatedProject },
            <| "Name" -> "Unrelated", "AgentSkills" -> { LLMSkill[ { "unrelated-skill", "An unrelated skill." }, "Unrelated." ] } |>
        ];
        { $unrelatedDep, FileExistsQ @ $lockedFile, #[ "Name" ] & /@ edgeRegistryEntries[ ] },
        { _AgentToolsDeployment? agentToolsDeploymentQ, True, { "unrelated-skill" } },
        SameTest -> MatchQ,
        TestID   -> "Unreadable-OrphanDoesNotBlockDeploys@@Tests/DeployAgentToolsSkills.wlt:1336,5-1348,6"
    ];

    VerificationTest[
        withEdgeEnvironment @ DeleteObject @ $unrelatedDep;
        RunProcess[ { "chmod", "644", $lockedFile } ];
        Quiet @ DeleteDirectory[ $lockedProject, DeleteContents -> True ];
        Quiet @ DeleteDirectory[ $unrelatedProject, DeleteContents -> True ];
        { withEdgeEnvironment @ DeployedAgentTools[ "ClaudeCode" ], edgeRegistryEntries[ ] },
        { { }, { } },
        TestID -> "Unreadable-Cleanup@@Tests/DeployAgentToolsSkills.wlt:1350,5-1358,6"
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Backup Not Removed*)
(* The skill directory was removed, but its backup can't be deleted completely (a read-only subdirectory): the leftover
   copy is reported. Unix only (file permissions). *)
If[ $permissionsEnforced,
    VerificationTest[
        $backupProject = CreateDirectory[ ];
        $backupDep = withEdgeEnvironment @ DeployAgentTools[ { "ClaudeCode", $backupProject }, $skillsOnly ];
        RunProcess[ { "chmod", "555", FileNameJoin @ { $backupProject, ".claude", "skills", "dir-skill", "scripts" } } ];
        withEdgeEnvironment @ DeleteObject @ $backupDep,
        Null,
        { AgentToolsDeployment::AgentSkillBackupNotRemoved },
        TestID -> "BackupNotRemoved-Reported@@Tests/DeployAgentToolsSkills.wlt:1367,5-1375,6"
    ];

    VerificationTest[
        {
            DirectoryQ @ FileNameJoin @ { $backupProject, ".claude", "skills", "dir-skill" },
            Length @ FileNames[ ".agenttools-backup-*", FileNameJoin @ { $backupProject, ".claude" } ],
            edgeRegistryEntries[ ]
        },
        { False, 1, { } },
        TestID -> "BackupNotRemoved-State@@Tests/DeployAgentToolsSkills.wlt:1377,5-1385,6"
    ];

    VerificationTest[
        RunProcess[ { "chmod", "-R", "u+rwX", $backupProject } ];
        DeleteDirectory[ $backupProject, DeleteContents -> True ],
        Null,
        TestID -> "BackupNotRemoved-Cleanup@@Tests/DeployAgentToolsSkills.wlt:1387,5-1392,6"
    ]
]

VerificationTest[
    withEdgeEnvironment[ Quiet[ DeleteObject /@ DeployedAgentTools[ ] ] ];
    RunProcess[ { "chmod", "-R", "u+rwX", $edgeHome } ];
    Quiet @ Scan[ DeleteDirectory[ #, DeleteContents -> True ] &, { $edgeHome, $edgeRoot } ];
    { DirectoryQ @ $edgeHome, DirectoryQ @ $edgeRoot },
    { False, False },
    TestID -> "EdgeCases-Cleanup@@Tests/DeployAgentToolsSkills.wlt:1395,1-1402,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    withTestEnvironment[ Quiet[ DeleteObject /@ DeployedAgentTools[ ] ] ];
    Quiet @ Scan[
        DeleteDirectory[ #, DeleteContents -> True ] &,
        { $testHome, $testRoot, $sourceDir, $project, $cursorProject, $customSkills, $rollbackProject, $oldProject, DirectoryName @ First @ $v1Config, $pacletProject, $warnProject, $remoteProject, $accentedSource, $replacedProject, $lockedParent }
    ];
    PacletDirectoryUnload @ $mockPacletDirectory;
    True,
    True,
    TestID -> "Cleanup@@Tests/DeployAgentToolsSkills.wlt:1407,1-1417,2"
]

(* :!CodeAnalysis::EndBlock:: *)
