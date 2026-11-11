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
    TestID   -> "DefaultAgentTools-AllValid"
]

VerificationTest[
    Keys @ $DefaultAgentTools,
    Sort @ Keys @ $DefaultMCPServers,
    TestID -> "DefaultAgentTools-OnePerDefaultServer"
]

VerificationTest[
    AllTrue[ Keys @ $DefaultAgentTools, $DefaultAgentTools[ # ][ "MCPServerNames" ] === { # } & ],
    True,
    TestID -> "DefaultAgentTools-ServerNamesMatch"
]

VerificationTest[
    #[ "AgentSkillNames" ] & /@ $DefaultAgentTools,
    <|
        "Wolfram"                  -> { "wolfram-language", "wolfram-alpha", "wolfram-debugging", "wolfram-agent-tools" },
        "WolframAlpha"             -> { "wolfram-alpha" },
        "WolframLanguage"          -> { "wolfram-language", "wolfram-notebooks", "wolfram-paclets", "wolfram-debugging", "wolfram-agent-tools" },
        "WolframPacletDevelopment" -> { "wolfram-language", "wolfram-notebooks", "wolfram-paclets", "wolfram-debugging", "wolfram-agent-tools" }
    |>,
    SameTest -> SameQ,
    TestID   -> "DefaultAgentTools-AgentSkillNames"
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
    TestID   -> "DefaultAgentTools-AgentSkillsBuiltIn"
]

VerificationTest[
    Map[ #[ "Name" ] &, #[ "AgentSkills" ] ] & /@ $DefaultAgentTools,
    #[ "AgentSkillNames" ] & /@ $DefaultAgentTools,
    SameTest -> SameQ,
    TestID   -> "DefaultAgentTools-AgentSkills"
]

VerificationTest[
    Flatten[ #[ "AgentSkills" ] & /@ Values @ $DefaultAgentTools ],
    { __LLMSkill },
    SameTest -> MatchQ,
    TestID   -> "DefaultAgentTools-AgentSkills-LLMSkills"
]

VerificationTest[
    Union[ #[ "Location" ] & /@ Values @ $DefaultAgentTools ],
    { "BuiltIn" },
    TestID -> "DefaultAgentTools-BuiltInLocation"
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
    TestID   -> "AgentToolsObject-BuiltIn"
]

VerificationTest[
    $wolfram === $DefaultAgentTools[ "Wolfram" ],
    True,
    TestID -> "AgentToolsObject-BuiltIn-SameAsDefault"
]

VerificationTest[
    $wolfram /@ { "Name", "Location", "AgentSkills", "MCPServerNames", "AgentSkillNames", "ToolsetType" },
    {
        "Wolfram",
        "BuiltIn",
        {
            HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "wolfram-language" ] ],
            HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "wolfram-alpha" ] ],
            HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "wolfram-debugging" ] ],
            HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "wolfram-agent-tools" ] ]
        },
        { "Wolfram" },
        { "wolfram-language", "wolfram-alpha", "wolfram-debugging", "wolfram-agent-tools" },
        "AgentToolsObject"
    },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-BuiltIn-Properties"
]

VerificationTest[
    $wolfram[ "Description" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-BuiltIn-Description"
]

VerificationTest[
    $wolfram[ "MCPServers" ],
    { _MCPServerObject? MCPServerObjectQ },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-BuiltIn-MCPServers"
]

VerificationTest[
    $wolfram[ "MCPServers" ] === $wolfram[ "MCPServerObjects" ] === { MCPServerObject[ "Wolfram" ] },
    True,
    TestID -> "AgentToolsObject-BuiltIn-MCPServerObjects"
]

VerificationTest[
    #[ "Name" ] & /@ $wolfram[ "Tools" ],
    #[ "Name" ] & /@ MCPServerObject[ "Wolfram" ][ "Tools" ],
    TestID -> "AgentToolsObject-BuiltIn-Tools"
]

VerificationTest[
    With[ { skills = $wolfram /@ { "AgentSkills", "Skills", "LLMSkills" } },
        { SameQ @@ skills, MatchQ[ First @ skills, { __LLMSkill } ], Map[ #[ "Name" ] &, First @ skills ] }
    ],
    { True, True, { "wolfram-language", "wolfram-alpha", "wolfram-debugging", "wolfram-agent-tools" } },
    SameTest -> SameQ,
    TestID   -> "AgentToolsObject-BuiltIn-LLMSkills"
]

(* The skills are the skill directories in the "AgentSkills" asset of the loaded paclet *)
VerificationTest[
    With[ { root = FileNameSplit @ ExpandFileName @ PacletObject[ "Wolfram/AgentTools" ][ "AssetLocation", "AgentSkills" ] },
        Map[
            Function[ skill, FileNameSplit @ ExpandFileName @ skill[ "Location" ] === Append[ root, skill[ "Name" ] ] ],
            $wolfram[ "AgentSkills" ]
        ]
    ],
    { True, True, True, True },
    SameTest -> SameQ,
    TestID   -> "AgentToolsObject-BuiltIn-SkillLocations"
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
        { "wolfram-language", "wolfram-alpha", "wolfram-debugging", "wolfram-agent-tools" },
        Failure[ "AgentToolsObject::BuiltInAgentSkillMissing", KeyValuePattern[ "MessageParameters" :> { "wolfram-language" } ] ]
    },
    { AgentToolsObject::BuiltInAgentSkillMissing },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-BuiltIn-MissingAsset"
]

VerificationTest[
    SubsetQ[
        $wolfram[ "Properties" ],
        { "Name", "MCPServers", "MCPServerNames", "AgentSkills", "AgentSkillNames", "Skills", "Tools", "Data" }
    ],
    True,
    TestID -> "AgentToolsObject-Properties"
]

VerificationTest[
    $wolfram[ { "Name", "Location" } ],
    <| "Name" -> "Wolfram", "Location" -> "BuiltIn" |>,
    TestID -> "AgentToolsObject-PropertyList"
]

VerificationTest[
    $wolfram[ "NotAProperty" ],
    Missing[ "UnknownProperty", "NotAProperty" ],
    TestID -> "AgentToolsObject-UnknownProperty"
]

VerificationTest[
    $wolfram[ 1 ],
    _Failure,
    { AgentToolsObject::InvalidProperty },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-InvalidProperty"
]

VerificationTest[
    AgentToolsObject @ $wolfram,
    $wolfram,
    TestID -> "AgentToolsObject-Idempotent"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Not Found*)
VerificationTest[
    AgentToolsObject[ "NoSuchAgentTools" ],
    _Failure,
    { AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-NotFound"
]

VerificationTest[
    AgentToolsObject[ "NoSuchPublisher" <> CreateUUID[ ] <> "/NoSuchPaclet/NoSuchBundle" ],
    _Failure,
    { AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-NotFound-Qualified"
]

VerificationTest[
    AgentToolsObject[ 1, 2 ],
    _Failure,
    { AgentToolsObject::InvalidArguments },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-InvalidArguments"
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
    TestID   -> "AgentToolsObject-AdHoc"
]

VerificationTest[
    $adHoc /@ { "Name", "Location", "MCPServerNames", "AgentSkillNames", "Description" },
    { "MyTools", None, { "WolframLanguage" }, { "my-test-skill", "dir-test-skill" }, "Tools for testing" },
    TestID -> "AgentToolsObject-AdHoc-Properties"
]

VerificationTest[
    $adHoc[ "MCPServers" ],
    { MCPServerObject[ "WolframLanguage" ] },
    TestID -> "AgentToolsObject-AdHoc-MCPServers"
]

VerificationTest[
    $adHoc[ "AgentSkills" ],
    { $testSkill, HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "dir-test-skill" ] ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-AgentSkills"
]

VerificationTest[
    $adHoc[ "AgentSkills" ] === $adHoc[ "Skills" ] === $adHoc[ "LLMSkills" ],
    True,
    TestID -> "AgentToolsObject-AdHoc-SkillsAliases"
]

(* The stored specifications are kept as given *)
VerificationTest[
    Lookup[ $adHoc[ "Data" ], { "MCPServers", "AgentSkills" } ],
    { { "WolframLanguage" }, { $testSkill, File @ $testSkillDirectory } },
    TestID -> "AgentToolsObject-AdHoc-StoredSpecs"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "OnlySkills", "AgentSkills" -> $testSkill |>,
    _AgentToolsObject? (#[ "MCPServers" ] === { } && #[ "AgentSkills" ] === { $testSkill } &),
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-SkillsOnly"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "Empty" |>,
    _AgentToolsObject? (#[ "MCPServers" ] === { } && #[ "AgentSkills" ] === { } &),
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-Empty"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "WithServerObject", "MCPServers" -> { MCPServerObject[ "WolframAlpha" ] } |>,
    _AgentToolsObject? (#[ "MCPServerNames" ] === { "WolframAlpha" } &),
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-ServerObject"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Ad Hoc Bundles*)
VerificationTest[
    AgentToolsObject @ <| "Name" -> "Wolfram", "MCPServers" -> { "Wolfram" } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-BuiltInName"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "Publisher/Paclet/Bundle" |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-ReservedName"
]

VerificationTest[
    AgentToolsObject @ <| "MCPServers" -> { "Wolfram" } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-NoName"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "BadServers", "MCPServers" -> { 1 } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-InvalidServers"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "BadSkills", "AgentSkills" -> { 1 } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-InvalidSkills"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "BadDescription", "Description" -> 1 |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-InvalidDescription"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "BadSkillFile", "AgentSkills" -> { File[ "/no/such/skill/dir" ] } |> ][ "AgentSkills" ],
    _Failure,
    { AgentToolsObject::InvalidAgentSkill },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-AgentSkills-InvalidFile"
]

(* Bare skill names are names of built-in skills *)
VerificationTest[
    AgentToolsObject[ <| "Name" -> "UnknownSkill", "AgentSkills" -> { "no-such-built-in-skill" } |> ][ "AgentSkills" ],
    Failure[ "AgentToolsObject::AgentSkillNotFound", KeyValuePattern[ "MessageParameters" :> { "no-such-built-in-skill" } ] ],
    { AgentToolsObject::AgentSkillNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-AgentSkills-UnknownName"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "WithBuiltInSkill", "AgentSkills" -> { $testSkill, "wolfram-alpha" } |> ][ "AgentSkills" ],
    { $testSkill, HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "wolfram-alpha" ] ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-AgentSkills-BuiltInName"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Skill Specifications*)
VerificationTest[
    AgentToolsObject[ <| "Name" -> "NoBody", "AgentSkills" -> { <| "Name" -> "t-skill", "Description" -> "d" |> } |> ][ "AgentSkills" ],
    { HoldPattern[ LLMSkill ][ KeyValuePattern @ { "Name" -> "t-skill", "Body" -> "" } ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AgentSkills-NoBody"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "OtherType", "AgentSkills" -> { <| "Name" -> "t-skill", "Description" -> "d", "Body" -> "b", "Type" -> "Skill" |> } |> ][ "AgentSkills" ],
    { HoldPattern[ LLMSkill ][ KeyValuePattern @ { "Name" -> "t-skill", "Body" -> "b" } ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AgentSkills-OtherTypeKey"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "OddNames", "AgentSkills" -> { "", "a/b" } |> ][ "AgentSkillNames" ],
    { "", "a/b" },
    TestID -> "AgentToolsObject-AgentSkillNames-OddStrings"
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
    TestID   -> "PacletBundle-ByName"
]

VerificationTest[
    $pacletBundle /@ { "Name", "MCPServerNames", "Description", "ToolsetType" },
    { "MockMCPPacletSkills/SkillsBundle", { "MockMCPPacletSkills/SkillsServer" }, "Servers and skills for testing", "AgentToolsObject" },
    TestID -> "PacletBundle-Properties"
]

VerificationTest[
    $pacletBundle[ "AgentSkillNames" ],
    "MockMCPPacletSkills/" <> # & /@ {
        "directory-skill", "assoc-skill", "llmskill-skill", "combined-skill", "located-skill", "foreign-skill"
    },
    TestID -> "PacletBundle-AgentSkillNames"
]

VerificationTest[
    $pacletBundle[ "Location" ],
    _PacletObject,
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-Location"
]

VerificationTest[
    #[ "Name" ] & /@ $pacletBundle[ "AgentSkills" ],
    { "directory-skill", "assoc-skill", "llmskill-skill", "combined-skill", "located-skill", "foreign-skill" },
    TestID -> "PacletBundle-AgentSkills"
]

VerificationTest[
    $pacletBundle[ "Skills" ] === $pacletBundle[ "AgentSkills" ],
    True,
    TestID -> "PacletBundle-Skills"
]

VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills/DevBundle" ][ "MCPServerNames" ],
    { "MockMCPPacletSkills/SkillsServer", "MockMCPPacletSkills/DevServer" },
    TestID -> "PacletBundle-SecondEntry"
]

VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills/DevBundle" ][ "MCPServers" ],
    { MCPServerObject[ "MockMCPPacletSkills/SkillsServer" ], MCPServerObject[ "MockMCPPacletSkills/DevServer" ] },
    TestID -> "PacletBundle-SecondEntry-MCPServers"
]

(* Entries for other systems define no bundle *)
VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills/PerSystemBundle" ],
    _Failure,
    { AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-OtherSystem"
]

VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills" ],
    _Failure,
    { AgentToolsObject::AgentToolsBundleNameAmbiguous },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-PacletNameAmbiguous"
]

VerificationTest[
    { AgentToolsObject[ "MockMCPPacletSkill*" ], AgentToolsObject[ "MockMCPPacletSkills/Skills*" ] },
    { _Failure, _Failure },
    { AgentToolsObject::AgentToolsNotFound, AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-NoWildcards"
]

VerificationTest[
    SubsetQ[
        #[ "Name" ] & /@ AgentToolsObjects[ ],
        { "MockMCPPacletSkills/SkillsBundle", "MockMCPPacletSkills/DevBundle" }
    ],
    True,
    TestID -> "PacletBundle-AgentToolsObjects"
]

VerificationTest[
    #[ "Name" ] & /@ AgentToolsObjects[ "MockMCPPacletSkills/*" ],
    { "MockMCPPacletSkills/SkillsBundle", "MockMCPPacletSkills/DevBundle" },
    TestID -> "PacletBundle-AgentToolsObjects-Pattern"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*toAgentToolsObject*)
VerificationTest[
    toAgentToolsObject @ MCPServerObject[ "WolframAlpha" ],
    _AgentToolsObject? agentToolsObjectQ,
    SameTest -> MatchQ,
    TestID   -> "toAgentToolsObject-MCPServerObject"
]

VerificationTest[
    toAgentToolsObject[ MCPServerObject[ "WolframAlpha" ] ] /@ { "Name", "Location", "MCPServerNames", "MCPServers", "AgentSkills", "ToolsetType" },
    { "WolframAlpha", "BuiltIn", { "WolframAlpha" }, { MCPServerObject[ "WolframAlpha" ] }, { }, "MCPServerObject" },
    TestID -> "toAgentToolsObject-MCPServerObject-Properties"
]

(* The implicit bundle of an MCP server has no skills, even if the built-in bundle of the same name has some *)
VerificationTest[
    {
        toAgentToolsObject[ MCPServerObject[ "Wolfram" ] ] /@ { "Name", "AgentSkills", "AgentSkillNames" },
        AgentToolsObject[ "Wolfram" ][ "AgentSkillNames" ]
    },
    { { "Wolfram", { }, { } }, { "wolfram-language", "wolfram-alpha", "wolfram-debugging", "wolfram-agent-tools" } },
    SameTest -> SameQ,
    TestID   -> "toAgentToolsObject-MCPServerObject-NoSkills"
]

VerificationTest[
    toAgentToolsObject @ $wolfram,
    $wolfram,
    TestID -> "toAgentToolsObject-AgentToolsObject"
]

VerificationTest[
    toAgentToolsObject[ "Wolfram" ],
    $wolfram,
    TestID -> "toAgentToolsObject-Name"
]

VerificationTest[
    toAgentToolsObject[ <| "Name" -> "Mine", "MCPServers" -> { "Wolfram" } |> ][ "Name" ],
    "Mine",
    TestID -> "toAgentToolsObject-Association"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ toAgentToolsObject[ 123 ],
    _Failure,
    { AgentTools::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "toAgentToolsObject-Invalid"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AgentToolsObjects*)
VerificationTest[
    AgentToolsObjects[ ],
    { ___AgentToolsObject? agentToolsObjectQ },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObjects-Installed"
]

VerificationTest[
    SubsetQ[ AgentToolsObjects[ "IncludeBuiltIn" -> True ], Values @ $DefaultAgentTools ],
    True,
    TestID -> "AgentToolsObjects-IncludeBuiltIn"
]

VerificationTest[
    AgentToolsObjects[ "Wolfram*", "IncludeBuiltIn" -> True ],
    { __AgentToolsObject? (StringStartsQ[ #[ "Name" ], "Wolfram" ] &) },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObjects-Pattern"
]

VerificationTest[
    AgentToolsObjects[ "NoSuchName*", "IncludeBuiltIn" -> True ],
    { },
    TestID -> "AgentToolsObjects-PatternNoMatch"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatting*)
VerificationTest[
    MakeBoxes[ $wolfram, StandardForm ],
    Except[ _MakeBoxes ],
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-Formatting"
]

VerificationTest[
    ToBoxes @ $adHoc,
    Except[ _ToBoxes ],
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-Formatting-AdHoc"
]

VerificationTest[
    With[ { boxes = ToString[ ToBoxes @ $wolfram, InputForm ] },
        {
            StringContainsQ[ boxes, "Tools for general computation and knowledge" ],
            StringFreeQ[ boxes, "TruncateStringToWidth" ]
        }
    ],
    { True, True },
    TestID -> "AgentToolsObject-Formatting-Description"
]

VerificationTest[
    With[ { boxes = ToString[ ToBoxes @ $wolfram, InputForm ] },
        StringContainsQ[ boxes, "wolfram-language" ] && StringContainsQ[ boxes, "wolfram-alpha" ]
    ],
    True,
    TestID -> "AgentToolsObject-Formatting-SkillNames"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet @ DeleteDirectory[ DirectoryName @ $testSkillDirectory, DeleteContents -> True ];
    PacletDirectoryUnload @ $mockPacletDirectory;
    True,
    True,
    TestID -> "Cleanup"
]

(* :!CodeAnalysis::EndBlock:: *)
