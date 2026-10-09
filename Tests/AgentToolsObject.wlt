(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/AgentToolsObject.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/AgentToolsObject.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Helper Functions*)
agentToolsObjectQ  = Wolfram`AgentTools`Common`agentToolsObjectQ;
toAgentToolsObject = Wolfram`AgentTools`Common`toAgentToolsObject;

$testSkill = LLMSkill[ { "my-test-skill", "A skill used for testing." }, "Do the test thing." ];

$testSkillDirectory := $testSkillDirectory = Module[ { dir },
    dir = FileNameJoin @ { CreateDirectory[ ], "dir-test-skill" };
    CreateDirectory @ dir;
    Export[
        FileNameJoin @ { dir, "SKILL.md" },
        "---\nname: dir-test-skill\ndescription: A skill directory used for testing.\n---\n\nBody.\n",
        "Text"
    ];
    dir
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$DefaultAgentTools*)
VerificationTest[
    $DefaultAgentTools,
    _Association? (AllTrue[ #, agentToolsObjectQ ] &),
    SameTest -> MatchQ,
    TestID   -> "DefaultAgentTools-AllValid@@Tests/AgentToolsObject.wlt:43,1-48,2"
]

VerificationTest[
    Keys @ $DefaultAgentTools,
    Sort @ Keys @ $DefaultMCPServers,
    TestID -> "DefaultAgentTools-OnePerDefaultServer@@Tests/AgentToolsObject.wlt:50,1-54,2"
]

VerificationTest[
    AllTrue[ Keys @ $DefaultAgentTools, $DefaultAgentTools[ # ][ "MCPServerNames" ] === { # } & ],
    True,
    TestID -> "DefaultAgentTools-ServerNamesMatch@@Tests/AgentToolsObject.wlt:56,1-60,2"
]

VerificationTest[
    #[ "AgentSkillNames" ] & /@ $DefaultAgentTools,
    <|
        "Wolfram"                  -> { "wolfram-language", "wolfram-alpha", "wolfram-debugging" },
        "WolframAlpha"             -> { "wolfram-alpha" },
        "WolframLanguage"          -> { "wolfram-language", "wolfram-notebooks", "wolfram-paclets", "wolfram-debugging" },
        "WolframPacletDevelopment" -> { "wolfram-language", "wolfram-notebooks", "wolfram-paclets", "wolfram-debugging" }
    |>,
    SameTest -> SameQ,
    TestID   -> "DefaultAgentTools-AgentSkillNames@@Tests/AgentToolsObject.wlt:62,1-72,2"
]

(* The bundles use exactly the built-in skills: { not built-in, not used by any bundle } *)
VerificationTest[
    With[
        {
            used     = Union @ Flatten[ #[ "AgentSkillNames" ] & /@ Values @ $DefaultAgentTools ],
            builtIns = Union @ Keys @ Wolfram`AgentTools`Common`$defaultAgentSkills
        },
        { Complement[ used, builtIns ], Complement[ builtIns, used ] }
    ],
    { { }, { } },
    SameTest -> SameQ,
    TestID   -> "DefaultAgentTools-AgentSkillsBuiltIn@@Tests/AgentToolsObject.wlt:75,1-86,2"
]

VerificationTest[
    Map[ #[ "Name" ] &, #[ "AgentSkills" ] ] & /@ $DefaultAgentTools,
    #[ "AgentSkillNames" ] & /@ $DefaultAgentTools,
    SameTest -> SameQ,
    TestID   -> "DefaultAgentTools-AgentSkills@@Tests/AgentToolsObject.wlt:88,1-93,2"
]

VerificationTest[
    Flatten[ #[ "AgentSkills" ] & /@ Values @ $DefaultAgentTools ],
    { __LLMSkill },
    SameTest -> MatchQ,
    TestID   -> "DefaultAgentTools-AgentSkills-LLMSkills@@Tests/AgentToolsObject.wlt:95,1-100,2"
]

VerificationTest[
    Union[ #[ "Location" ] & /@ Values @ $DefaultAgentTools ],
    { "BuiltIn" },
    TestID -> "DefaultAgentTools-BuiltInLocation@@Tests/AgentToolsObject.wlt:102,1-106,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AgentToolsObject*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Built-In by Name*)
VerificationTest[
    $wolfram = AgentToolsObject[ "Wolfram" ],
    _AgentToolsObject? agentToolsObjectQ,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-BuiltIn@@Tests/AgentToolsObject.wlt:115,1-120,2"
]

VerificationTest[
    $wolfram === $DefaultAgentTools[ "Wolfram" ],
    True,
    TestID -> "AgentToolsObject-BuiltIn-SameAsDefault@@Tests/AgentToolsObject.wlt:122,1-126,2"
]

VerificationTest[
    $wolfram /@ { "Name", "Location", "AgentSkills", "MCPServerNames", "AgentSkillNames", "ToolsetType" },
    {
        "Wolfram",
        "BuiltIn",
        {
            HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "wolfram-language" ] ],
            HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "wolfram-alpha" ] ],
            HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "wolfram-debugging" ] ]
        },
        { "Wolfram" },
        { "wolfram-language", "wolfram-alpha", "wolfram-debugging" },
        "AgentToolsObject"
    },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-BuiltIn-Properties@@Tests/AgentToolsObject.wlt:128,1-144,2"
]

VerificationTest[
    $wolfram[ "Description" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-BuiltIn-Description@@Tests/AgentToolsObject.wlt:146,1-151,2"
]

VerificationTest[
    $wolfram[ "MCPServers" ],
    { _MCPServerObject? MCPServerObjectQ },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-BuiltIn-MCPServers@@Tests/AgentToolsObject.wlt:153,1-158,2"
]

VerificationTest[
    $wolfram[ "MCPServers" ] === $wolfram[ "MCPServerObjects" ] === { MCPServerObject[ "Wolfram" ] },
    True,
    TestID -> "AgentToolsObject-BuiltIn-MCPServerObjects@@Tests/AgentToolsObject.wlt:160,1-164,2"
]

VerificationTest[
    #[ "Name" ] & /@ $wolfram[ "Tools" ],
    #[ "Name" ] & /@ MCPServerObject[ "Wolfram" ][ "Tools" ],
    TestID -> "AgentToolsObject-BuiltIn-Tools@@Tests/AgentToolsObject.wlt:166,1-170,2"
]

VerificationTest[
    With[ { skills = $wolfram /@ { "AgentSkills", "Skills", "LLMSkills" } },
        { SameQ @@ skills, MatchQ[ First @ skills, { __LLMSkill } ], Map[ #[ "Name" ] &, First @ skills ] }
    ],
    { True, True, { "wolfram-language", "wolfram-alpha", "wolfram-debugging" } },
    SameTest -> SameQ,
    TestID   -> "AgentToolsObject-BuiltIn-LLMSkills@@Tests/AgentToolsObject.wlt:172,1-179,2"
]

(* The skills are the skill directories in the "AgentSkills" asset of the loaded paclet *)
VerificationTest[
    With[ { root = FileNameSplit @ ExpandFileName @ PacletObject[ "Wolfram/AgentTools" ][ "AssetLocation", "AgentSkills" ] },
        Map[
            Function[ skill, FileNameSplit @ ExpandFileName @ skill[ "Location" ] === Append[ root, skill[ "Name" ] ] ],
            $wolfram[ "AgentSkills" ]
        ]
    ],
    { True, True, True },
    SameTest -> SameQ,
    TestID   -> "AgentToolsObject-BuiltIn-SkillLocations@@Tests/AgentToolsObject.wlt:182,1-192,2"
]

(* A paclet without the skills (e.g. a damaged installation) still has the skill names, but not the skills *)
VerificationTest[
    Module[ { dir },
        dir = CreateDirectory[ ];
        WithCleanup[
            Export[
                FileNameJoin @ { dir, "PacletInfo.wl" },
                ToString[
                    PacletObject @ <|
                        "Name"       -> "AgentToolsObjectTestPaclet",
                        "Version"    -> "1.0.0",
                        "Extensions" -> { { "Asset", "Assets" -> { { "AgentSkills", "Assets/AgentSkills" } } } }
                    |>,
                    InputForm
                ],
                "Text"
            ];
            Block[ { Wolfram`AgentTools`Common`$thisPaclet = PacletObject @ File @ dir },
                { $wolfram[ "AgentSkillNames" ], $wolfram[ "AgentSkills" ] }
            ],
            DeleteDirectory[ dir, DeleteContents -> True ]
        ]
    ],
    {
        { "wolfram-language", "wolfram-alpha", "wolfram-debugging" },
        Failure[ "AgentToolsObject::BuiltInAgentSkillMissing", KeyValuePattern[ "MessageParameters" :> { "wolfram-language" } ] ]
    },
    { AgentToolsObject::BuiltInAgentSkillMissing },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-BuiltIn-MissingAsset@@Tests/AgentToolsObject.wlt:195,1-224,2"
]

VerificationTest[
    SubsetQ[
        $wolfram[ "Properties" ],
        { "Name", "MCPServers", "MCPServerNames", "AgentSkills", "AgentSkillNames", "Skills", "Tools", "Data" }
    ],
    True,
    TestID -> "AgentToolsObject-Properties@@Tests/AgentToolsObject.wlt:226,1-233,2"
]

VerificationTest[
    $wolfram[ { "Name", "Location" } ],
    <| "Name" -> "Wolfram", "Location" -> "BuiltIn" |>,
    TestID -> "AgentToolsObject-PropertyList@@Tests/AgentToolsObject.wlt:235,1-239,2"
]

VerificationTest[
    $wolfram[ "NotAProperty" ],
    Missing[ "UnknownProperty", "NotAProperty" ],
    TestID -> "AgentToolsObject-UnknownProperty@@Tests/AgentToolsObject.wlt:241,1-245,2"
]

VerificationTest[
    $wolfram[ 1 ],
    _Failure,
    { AgentToolsObject::InvalidProperty },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-InvalidProperty@@Tests/AgentToolsObject.wlt:247,1-253,2"
]

VerificationTest[
    AgentToolsObject @ $wolfram,
    $wolfram,
    TestID -> "AgentToolsObject-Idempotent@@Tests/AgentToolsObject.wlt:255,1-259,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Not Found*)
VerificationTest[
    AgentToolsObject[ "NoSuchAgentTools" ],
    _Failure,
    { AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-NotFound@@Tests/AgentToolsObject.wlt:264,1-270,2"
]

VerificationTest[
    AgentToolsObject[ "NoSuchPublisher" <> CreateUUID[ ] <> "/NoSuchPaclet/NoSuchBundle" ],
    _Failure,
    { AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-NotFound-Qualified@@Tests/AgentToolsObject.wlt:272,1-278,2"
]

VerificationTest[
    AgentToolsObject[ 1, 2 ],
    _Failure,
    { AgentToolsObject::InvalidArguments },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-InvalidArguments@@Tests/AgentToolsObject.wlt:280,1-286,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Ad Hoc Bundles*)
VerificationTest[
    $adHoc = AgentToolsObject @ <|
        "Name"        -> "MyTools",
        "MCPServers"  -> "WolframLanguage",
        "AgentSkills" -> { $testSkill, File @ $testSkillDirectory },
        "Description" -> "Tools for testing"
    |>,
    _AgentToolsObject? agentToolsObjectQ,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc@@Tests/AgentToolsObject.wlt:291,1-301,2"
]

VerificationTest[
    $adHoc /@ { "Name", "Location", "MCPServerNames", "AgentSkillNames", "Description" },
    { "MyTools", None, { "WolframLanguage" }, { "my-test-skill", "dir-test-skill" }, "Tools for testing" },
    TestID -> "AgentToolsObject-AdHoc-Properties@@Tests/AgentToolsObject.wlt:303,1-307,2"
]

VerificationTest[
    $adHoc[ "MCPServers" ],
    { MCPServerObject[ "WolframLanguage" ] },
    TestID -> "AgentToolsObject-AdHoc-MCPServers@@Tests/AgentToolsObject.wlt:309,1-313,2"
]

VerificationTest[
    $adHoc[ "AgentSkills" ],
    { $testSkill, HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "dir-test-skill" ] ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-AgentSkills@@Tests/AgentToolsObject.wlt:315,1-320,2"
]

VerificationTest[
    $adHoc[ "AgentSkills" ] === $adHoc[ "Skills" ] === $adHoc[ "LLMSkills" ],
    True,
    TestID -> "AgentToolsObject-AdHoc-SkillsAliases@@Tests/AgentToolsObject.wlt:322,1-326,2"
]

(* The stored specifications are kept as given *)
VerificationTest[
    Lookup[ $adHoc[ "Data" ], { "MCPServers", "AgentSkills" } ],
    { { "WolframLanguage" }, { $testSkill, File @ $testSkillDirectory } },
    TestID -> "AgentToolsObject-AdHoc-StoredSpecs@@Tests/AgentToolsObject.wlt:329,1-333,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "OnlySkills", "AgentSkills" -> $testSkill |>,
    _AgentToolsObject? (#[ "MCPServers" ] === { } && #[ "AgentSkills" ] === { $testSkill } &),
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-SkillsOnly@@Tests/AgentToolsObject.wlt:335,1-340,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "Empty" |>,
    _AgentToolsObject? (#[ "MCPServers" ] === { } && #[ "AgentSkills" ] === { } &),
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-Empty@@Tests/AgentToolsObject.wlt:342,1-347,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "WithServerObject", "MCPServers" -> { MCPServerObject[ "WolframAlpha" ] } |>,
    _AgentToolsObject? (#[ "MCPServerNames" ] === { "WolframAlpha" } &),
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-ServerObject@@Tests/AgentToolsObject.wlt:349,1-354,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Ad Hoc Bundles*)
VerificationTest[
    AgentToolsObject @ <| "Name" -> "Wolfram", "MCPServers" -> { "Wolfram" } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-BuiltInName@@Tests/AgentToolsObject.wlt:359,1-365,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "Publisher/Paclet/Bundle" |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-ReservedName@@Tests/AgentToolsObject.wlt:367,1-373,2"
]

VerificationTest[
    AgentToolsObject @ <| "MCPServers" -> { "Wolfram" } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-NoName@@Tests/AgentToolsObject.wlt:375,1-381,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "BadServers", "MCPServers" -> { 1 } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-InvalidServers@@Tests/AgentToolsObject.wlt:383,1-389,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "BadSkills", "AgentSkills" -> { 1 } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-InvalidSkills@@Tests/AgentToolsObject.wlt:391,1-397,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "BadDescription", "Description" -> 1 |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-InvalidDescription@@Tests/AgentToolsObject.wlt:399,1-405,2"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "BadSkillFile", "AgentSkills" -> { File[ "/no/such/skill/dir" ] } |> ][ "AgentSkills" ],
    _Failure,
    { AgentToolsObject::InvalidAgentSkill },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-AgentSkills-InvalidFile@@Tests/AgentToolsObject.wlt:407,1-413,2"
]

(* Bare skill names are names of built-in skills *)
VerificationTest[
    AgentToolsObject[ <| "Name" -> "UnknownSkill", "AgentSkills" -> { "no-such-built-in-skill" } |> ][ "AgentSkills" ],
    Failure[ "AgentToolsObject::AgentSkillNotFound", KeyValuePattern[ "MessageParameters" :> { "no-such-built-in-skill" } ] ],
    { AgentToolsObject::AgentSkillNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-AgentSkills-UnknownName@@Tests/AgentToolsObject.wlt:416,1-422,2"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "WithBuiltInSkill", "AgentSkills" -> { $testSkill, "wolfram-alpha" } |> ][ "AgentSkills" ],
    { $testSkill, HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "wolfram-alpha" ] ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-AgentSkills-BuiltInName@@Tests/AgentToolsObject.wlt:424,1-429,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Skill Specifications*)
VerificationTest[
    AgentToolsObject[ <| "Name" -> "NoBody", "AgentSkills" -> { <| "Name" -> "t-skill", "Description" -> "d" |> } |> ][ "AgentSkills" ],
    { HoldPattern[ LLMSkill ][ KeyValuePattern @ { "Name" -> "t-skill", "Body" -> "" } ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AgentSkills-NoBody@@Tests/AgentToolsObject.wlt:434,1-439,2"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "OtherType", "AgentSkills" -> { <| "Name" -> "t-skill", "Description" -> "d", "Body" -> "b", "Type" -> "Skill" |> } |> ][ "AgentSkills" ],
    { HoldPattern[ LLMSkill ][ KeyValuePattern @ { "Name" -> "t-skill", "Body" -> "b" } ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AgentSkills-OtherTypeKey@@Tests/AgentToolsObject.wlt:441,1-446,2"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "OddNames", "AgentSkills" -> { "", "a/b" } |> ][ "AgentSkillNames" ],
    { "", "a/b" },
    TestID -> "AgentToolsObject-AgentSkillNames-OddStrings@@Tests/AgentToolsObject.wlt:448,1-452,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paclet Bundles*)
$mockPacletDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources", "MockMCPPacletSkills" };
PacletDirectoryLoad @ $mockPacletDirectory;

VerificationTest[
    $pacletBundle = AgentToolsObject[ "MockMCPPacletSkills/SkillsBundle" ],
    _AgentToolsObject? agentToolsObjectQ,
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-ByName@@Tests/AgentToolsObject.wlt:460,1-465,2"
]

VerificationTest[
    $pacletBundle /@ { "Name", "MCPServerNames", "Description", "ToolsetType" },
    { "MockMCPPacletSkills/SkillsBundle", { "MockMCPPacletSkills/SkillsServer" }, "Servers and skills for testing", "AgentToolsObject" },
    TestID -> "PacletBundle-Properties@@Tests/AgentToolsObject.wlt:467,1-471,2"
]

VerificationTest[
    $pacletBundle[ "AgentSkillNames" ],
    "MockMCPPacletSkills/" <> # & /@ {
        "directory-skill", "assoc-skill", "llmskill-skill", "combined-skill", "located-skill", "foreign-skill"
    },
    TestID -> "PacletBundle-AgentSkillNames@@Tests/AgentToolsObject.wlt:473,1-479,2"
]

VerificationTest[
    $pacletBundle[ "Location" ],
    _PacletObject,
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-Location@@Tests/AgentToolsObject.wlt:481,1-486,2"
]

VerificationTest[
    #[ "Name" ] & /@ $pacletBundle[ "AgentSkills" ],
    { "directory-skill", "assoc-skill", "llmskill-skill", "combined-skill", "located-skill", "foreign-skill" },
    TestID -> "PacletBundle-AgentSkills@@Tests/AgentToolsObject.wlt:488,1-492,2"
]

VerificationTest[
    $pacletBundle[ "Skills" ] === $pacletBundle[ "AgentSkills" ],
    True,
    TestID -> "PacletBundle-Skills@@Tests/AgentToolsObject.wlt:494,1-498,2"
]

VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills/DevBundle" ][ "MCPServerNames" ],
    { "MockMCPPacletSkills/SkillsServer", "MockMCPPacletSkills/DevServer" },
    TestID -> "PacletBundle-SecondEntry@@Tests/AgentToolsObject.wlt:500,1-504,2"
]

VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills/DevBundle" ][ "MCPServers" ],
    { MCPServerObject[ "MockMCPPacletSkills/SkillsServer" ], MCPServerObject[ "MockMCPPacletSkills/DevServer" ] },
    TestID -> "PacletBundle-SecondEntry-MCPServers@@Tests/AgentToolsObject.wlt:506,1-510,2"
]

(* Entries for other systems define no bundle *)
VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills/PerSystemBundle" ],
    _Failure,
    { AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-OtherSystem@@Tests/AgentToolsObject.wlt:513,1-519,2"
]

VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills" ],
    _Failure,
    { AgentToolsObject::AgentToolsBundleNameAmbiguous },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-PacletNameAmbiguous@@Tests/AgentToolsObject.wlt:521,1-527,2"
]

VerificationTest[
    { AgentToolsObject[ "MockMCPPacletSkill*" ], AgentToolsObject[ "MockMCPPacletSkills/Skills*" ] },
    { _Failure, _Failure },
    { AgentToolsObject::AgentToolsNotFound, AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-NoWildcards@@Tests/AgentToolsObject.wlt:529,1-535,2"
]

VerificationTest[
    SubsetQ[
        #[ "Name" ] & /@ AgentToolsObjects[ ],
        { "MockMCPPacletSkills/SkillsBundle", "MockMCPPacletSkills/DevBundle" }
    ],
    True,
    TestID -> "PacletBundle-AgentToolsObjects@@Tests/AgentToolsObject.wlt:537,1-544,2"
]

VerificationTest[
    #[ "Name" ] & /@ AgentToolsObjects[ "MockMCPPacletSkills/*" ],
    { "MockMCPPacletSkills/SkillsBundle", "MockMCPPacletSkills/DevBundle" },
    TestID -> "PacletBundle-AgentToolsObjects-Pattern@@Tests/AgentToolsObject.wlt:546,1-550,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*toAgentToolsObject*)
VerificationTest[
    toAgentToolsObject @ MCPServerObject[ "WolframAlpha" ],
    _AgentToolsObject? agentToolsObjectQ,
    SameTest -> MatchQ,
    TestID   -> "toAgentToolsObject-MCPServerObject@@Tests/AgentToolsObject.wlt:555,1-560,2"
]

VerificationTest[
    toAgentToolsObject[ MCPServerObject[ "WolframAlpha" ] ] /@ { "Name", "Location", "MCPServerNames", "MCPServers", "AgentSkills", "ToolsetType" },
    { "WolframAlpha", "BuiltIn", { "WolframAlpha" }, { MCPServerObject[ "WolframAlpha" ] }, { }, "MCPServerObject" },
    TestID -> "toAgentToolsObject-MCPServerObject-Properties@@Tests/AgentToolsObject.wlt:562,1-566,2"
]

(* The implicit bundle of an MCP server has no skills, even if the built-in bundle of the same name has some *)
VerificationTest[
    {
        toAgentToolsObject[ MCPServerObject[ "Wolfram" ] ] /@ { "Name", "AgentSkills", "AgentSkillNames" },
        AgentToolsObject[ "Wolfram" ][ "AgentSkillNames" ]
    },
    { { "Wolfram", { }, { } }, { "wolfram-language", "wolfram-alpha", "wolfram-debugging" } },
    SameTest -> SameQ,
    TestID   -> "toAgentToolsObject-MCPServerObject-NoSkills@@Tests/AgentToolsObject.wlt:569,1-577,2"
]

VerificationTest[
    toAgentToolsObject @ $wolfram,
    $wolfram,
    TestID -> "toAgentToolsObject-AgentToolsObject@@Tests/AgentToolsObject.wlt:579,1-583,2"
]

VerificationTest[
    toAgentToolsObject[ "Wolfram" ],
    $wolfram,
    TestID -> "toAgentToolsObject-Name@@Tests/AgentToolsObject.wlt:585,1-589,2"
]

VerificationTest[
    toAgentToolsObject[ <| "Name" -> "Mine", "MCPServers" -> { "Wolfram" } |> ][ "Name" ],
    "Mine",
    TestID -> "toAgentToolsObject-Association@@Tests/AgentToolsObject.wlt:591,1-595,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ toAgentToolsObject[ 123 ],
    _Failure,
    { AgentTools::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "toAgentToolsObject-Invalid@@Tests/AgentToolsObject.wlt:597,1-603,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AgentToolsObjects*)
VerificationTest[
    AgentToolsObjects[ ],
    { ___AgentToolsObject? agentToolsObjectQ },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObjects-Installed@@Tests/AgentToolsObject.wlt:608,1-613,2"
]

VerificationTest[
    SubsetQ[ AgentToolsObjects[ "IncludeBuiltIn" -> True ], Values @ $DefaultAgentTools ],
    True,
    TestID -> "AgentToolsObjects-IncludeBuiltIn@@Tests/AgentToolsObject.wlt:615,1-619,2"
]

VerificationTest[
    AgentToolsObjects[ "Wolfram*", "IncludeBuiltIn" -> True ],
    { __AgentToolsObject? (StringStartsQ[ #[ "Name" ], "Wolfram" ] &) },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObjects-Pattern@@Tests/AgentToolsObject.wlt:621,1-626,2"
]

VerificationTest[
    AgentToolsObjects[ "NoSuchName*", "IncludeBuiltIn" -> True ],
    { },
    TestID -> "AgentToolsObjects-PatternNoMatch@@Tests/AgentToolsObject.wlt:628,1-632,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatting*)
VerificationTest[
    MakeBoxes[ $wolfram, StandardForm ],
    Except[ _MakeBoxes ],
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-Formatting@@Tests/AgentToolsObject.wlt:637,1-642,2"
]

VerificationTest[
    ToBoxes @ $adHoc,
    Except[ _ToBoxes ],
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-Formatting-AdHoc@@Tests/AgentToolsObject.wlt:644,1-649,2"
]

VerificationTest[
    With[ { boxes = ToString[ ToBoxes @ $wolfram, InputForm ] },
        {
            StringContainsQ[ boxes, "Tools for general computation and knowledge" ],
            StringFreeQ[ boxes, "TruncateStringToWidth" ]
        }
    ],
    { True, True },
    TestID -> "AgentToolsObject-Formatting-Description@@Tests/AgentToolsObject.wlt:651,1-660,2"
]

VerificationTest[
    With[ { boxes = ToString[ ToBoxes @ $wolfram, InputForm ] },
        StringContainsQ[ boxes, "wolfram-language" ] && StringContainsQ[ boxes, "wolfram-alpha" ]
    ],
    True,
    TestID -> "AgentToolsObject-Formatting-SkillNames@@Tests/AgentToolsObject.wlt:662,1-668,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet @ DeleteDirectory[ DirectoryName @ $testSkillDirectory, DeleteContents -> True ];
    PacletDirectoryUnload @ $mockPacletDirectory;
    True,
    True,
    TestID -> "Cleanup@@Tests/AgentToolsObject.wlt:673,1-679,2"
]

(* :!CodeAnalysis::EndBlock:: *)
