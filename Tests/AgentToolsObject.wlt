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
    AllTrue[ Keys @ $DefaultAgentTools, $DefaultAgentTools[ # ][ "MCPServers" ] === { # } & ],
    True,
    TestID -> "DefaultAgentTools-ServerNamesMatch@@Tests/AgentToolsObject.wlt:56,1-60,2"
]

VerificationTest[
    Union @ Flatten[ #[ "AgentSkills" ] & /@ Values @ $DefaultAgentTools ],
    { },
    TestID -> "DefaultAgentTools-NoSkillsYet@@Tests/AgentToolsObject.wlt:62,1-66,2"
]

VerificationTest[
    Union[ #[ "Location" ] & /@ Values @ $DefaultAgentTools ],
    { "BuiltIn" },
    TestID -> "DefaultAgentTools-BuiltInLocation@@Tests/AgentToolsObject.wlt:68,1-72,2"
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
    TestID   -> "AgentToolsObject-BuiltIn@@Tests/AgentToolsObject.wlt:81,1-86,2"
]

VerificationTest[
    $wolfram === $DefaultAgentTools[ "Wolfram" ],
    True,
    TestID -> "AgentToolsObject-BuiltIn-SameAsDefault@@Tests/AgentToolsObject.wlt:88,1-92,2"
]

VerificationTest[
    $wolfram /@ { "Name", "Location", "MCPServers", "AgentSkills", "MCPServerNames", "AgentSkillNames", "ToolsetType" },
    { "Wolfram", "BuiltIn", { "Wolfram" }, { }, { "Wolfram" }, { }, "AgentToolsObject" },
    TestID -> "AgentToolsObject-BuiltIn-Properties@@Tests/AgentToolsObject.wlt:94,1-98,2"
]

VerificationTest[
    $wolfram[ "Description" ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-BuiltIn-NoDescription@@Tests/AgentToolsObject.wlt:100,1-105,2"
]

VerificationTest[
    $wolfram[ "MCPServerObjects" ],
    { _MCPServerObject? MCPServerObjectQ },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-BuiltIn-MCPServerObjects@@Tests/AgentToolsObject.wlt:107,1-112,2"
]

VerificationTest[
    #[ "Name" ] & /@ $wolfram[ "Tools" ],
    #[ "Name" ] & /@ MCPServerObject[ "Wolfram" ][ "Tools" ],
    TestID -> "AgentToolsObject-BuiltIn-Tools@@Tests/AgentToolsObject.wlt:114,1-118,2"
]

VerificationTest[
    $wolfram[ "LLMSkills" ],
    { },
    TestID -> "AgentToolsObject-BuiltIn-LLMSkills@@Tests/AgentToolsObject.wlt:120,1-124,2"
]

VerificationTest[
    SubsetQ[ $wolfram[ "Properties" ], { "Name", "MCPServers", "AgentSkills", "LLMSkills", "Data" } ],
    True,
    TestID -> "AgentToolsObject-Properties@@Tests/AgentToolsObject.wlt:126,1-130,2"
]

VerificationTest[
    $wolfram[ { "Name", "Location" } ],
    <| "Name" -> "Wolfram", "Location" -> "BuiltIn" |>,
    TestID -> "AgentToolsObject-PropertyList@@Tests/AgentToolsObject.wlt:132,1-136,2"
]

VerificationTest[
    $wolfram[ "NotAProperty" ],
    Missing[ "UnknownProperty", "NotAProperty" ],
    TestID -> "AgentToolsObject-UnknownProperty@@Tests/AgentToolsObject.wlt:138,1-142,2"
]

VerificationTest[
    $wolfram[ 1 ],
    _Failure,
    { AgentToolsObject::InvalidProperty },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-InvalidProperty@@Tests/AgentToolsObject.wlt:144,1-150,2"
]

VerificationTest[
    AgentToolsObject @ $wolfram,
    $wolfram,
    TestID -> "AgentToolsObject-Idempotent@@Tests/AgentToolsObject.wlt:152,1-156,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Not Found*)
VerificationTest[
    AgentToolsObject[ "NoSuchAgentTools" ],
    _Failure,
    { AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-NotFound@@Tests/AgentToolsObject.wlt:161,1-167,2"
]

VerificationTest[
    AgentToolsObject[ "NoSuchPublisher" <> CreateUUID[ ] <> "/NoSuchPaclet/NoSuchBundle" ],
    _Failure,
    { AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-NotFound-Qualified@@Tests/AgentToolsObject.wlt:169,1-175,2"
]

VerificationTest[
    AgentToolsObject[ 1, 2 ],
    _Failure,
    { AgentToolsObject::InvalidArguments },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-InvalidArguments@@Tests/AgentToolsObject.wlt:177,1-183,2"
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
    TestID   -> "AgentToolsObject-AdHoc@@Tests/AgentToolsObject.wlt:188,1-198,2"
]

VerificationTest[
    $adHoc /@ { "Name", "Location", "MCPServers", "MCPServerNames", "AgentSkillNames", "Description" },
    { "MyTools", None, { "WolframLanguage" }, { "WolframLanguage" }, { "my-test-skill", "dir-test-skill" }, "Tools for testing" },
    TestID -> "AgentToolsObject-AdHoc-Properties@@Tests/AgentToolsObject.wlt:200,1-204,2"
]

VerificationTest[
    $adHoc[ "LLMSkills" ],
    { $testSkill, HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "dir-test-skill" ] ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-LLMSkills@@Tests/AgentToolsObject.wlt:206,1-211,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "OnlySkills", "AgentSkills" -> $testSkill |>,
    _AgentToolsObject? (#[ "MCPServers" ] === { } && Length @ #[ "AgentSkills" ] === 1 &),
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-SkillsOnly@@Tests/AgentToolsObject.wlt:213,1-218,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "Empty" |>,
    _AgentToolsObject? (#[ "MCPServers" ] === { } && #[ "AgentSkills" ] === { } &),
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-Empty@@Tests/AgentToolsObject.wlt:220,1-225,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "WithServerObject", "MCPServers" -> { MCPServerObject[ "WolframAlpha" ] } |>,
    _AgentToolsObject? (#[ "MCPServerNames" ] === { "WolframAlpha" } &),
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-ServerObject@@Tests/AgentToolsObject.wlt:227,1-232,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Ad Hoc Bundles*)
VerificationTest[
    AgentToolsObject @ <| "Name" -> "Wolfram", "MCPServers" -> { "Wolfram" } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-BuiltInName@@Tests/AgentToolsObject.wlt:237,1-243,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "Publisher/Paclet/Bundle" |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-ReservedName@@Tests/AgentToolsObject.wlt:245,1-251,2"
]

VerificationTest[
    AgentToolsObject @ <| "MCPServers" -> { "Wolfram" } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-NoName@@Tests/AgentToolsObject.wlt:253,1-259,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "BadServers", "MCPServers" -> { 1 } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-InvalidServers@@Tests/AgentToolsObject.wlt:261,1-267,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "BadSkills", "AgentSkills" -> { 1 } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-InvalidSkills@@Tests/AgentToolsObject.wlt:269,1-275,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "BadDescription", "Description" -> 1 |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-InvalidDescription@@Tests/AgentToolsObject.wlt:277,1-283,2"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "BadSkillFile", "AgentSkills" -> { File[ "/no/such/skill/dir" ] } |> ][ "LLMSkills" ],
    _Failure,
    { AgentToolsObject::InvalidAgentSkill },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-LLMSkills-InvalidFile@@Tests/AgentToolsObject.wlt:285,1-291,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Skill Specifications*)
VerificationTest[
    AgentToolsObject[ <| "Name" -> "NoBody", "AgentSkills" -> { <| "Name" -> "t-skill", "Description" -> "d" |> } |> ][ "LLMSkills" ],
    { HoldPattern[ LLMSkill ][ KeyValuePattern @ { "Name" -> "t-skill", "Body" -> "" } ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-LLMSkills-NoBody@@Tests/AgentToolsObject.wlt:296,1-301,2"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "OtherType", "AgentSkills" -> { <| "Name" -> "t-skill", "Description" -> "d", "Body" -> "b", "Type" -> "Skill" |> } |> ][ "LLMSkills" ],
    { HoldPattern[ LLMSkill ][ KeyValuePattern @ { "Name" -> "t-skill", "Body" -> "b" } ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-LLMSkills-OtherTypeKey@@Tests/AgentToolsObject.wlt:303,1-308,2"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "OddNames", "AgentSkills" -> { "", "a/b" } |> ][ "AgentSkillNames" ],
    { "", "b" },
    TestID -> "AgentToolsObject-AgentSkillNames-OddStrings@@Tests/AgentToolsObject.wlt:310,1-314,2"
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
    TestID   -> "PacletBundle-ByName@@Tests/AgentToolsObject.wlt:322,1-327,2"
]

VerificationTest[
    $pacletBundle /@ { "Name", "MCPServers", "Description", "ToolsetType" },
    { "MockMCPPacletSkills/SkillsBundle", { "MockMCPPacletSkills/SkillsServer" }, "Servers and skills for testing", "AgentToolsObject" },
    TestID -> "PacletBundle-Properties@@Tests/AgentToolsObject.wlt:329,1-333,2"
]

VerificationTest[
    $pacletBundle[ "AgentSkillNames" ],
    { "directory-skill", "assoc-skill", "llmskill-skill", "combined-skill", "located-skill", "foreign-skill" },
    TestID -> "PacletBundle-AgentSkillNames@@Tests/AgentToolsObject.wlt:335,1-339,2"
]

VerificationTest[
    $pacletBundle[ "Location" ],
    _PacletObject,
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-Location@@Tests/AgentToolsObject.wlt:341,1-346,2"
]

VerificationTest[
    #[ "Name" ] & /@ $pacletBundle[ "LLMSkills" ],
    { "directory-skill", "assoc-skill", "llmskill-skill", "combined-skill", "located-skill", "foreign-skill" },
    TestID -> "PacletBundle-LLMSkills@@Tests/AgentToolsObject.wlt:348,1-352,2"
]

VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills/DevBundle" ][ "MCPServers" ],
    { "MockMCPPacletSkills/SkillsServer", "MockMCPPacletSkills/DevServer" },
    TestID -> "PacletBundle-SecondEntry@@Tests/AgentToolsObject.wlt:354,1-358,2"
]

(* Entries for other systems define no bundle *)
VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills/PerSystemBundle" ],
    _Failure,
    { AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-OtherSystem@@Tests/AgentToolsObject.wlt:361,1-367,2"
]

VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills" ],
    _Failure,
    { AgentToolsObject::AgentToolsBundleNameAmbiguous },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-PacletNameAmbiguous@@Tests/AgentToolsObject.wlt:369,1-375,2"
]

VerificationTest[
    { AgentToolsObject[ "MockMCPPacletSkill*" ], AgentToolsObject[ "MockMCPPacletSkills/Skills*" ] },
    { _Failure, _Failure },
    { AgentToolsObject::AgentToolsNotFound, AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-NoWildcards@@Tests/AgentToolsObject.wlt:377,1-383,2"
]

VerificationTest[
    SubsetQ[
        #[ "Name" ] & /@ AgentToolsObjects[ ],
        { "MockMCPPacletSkills/SkillsBundle", "MockMCPPacletSkills/DevBundle" }
    ],
    True,
    TestID -> "PacletBundle-AgentToolsObjects@@Tests/AgentToolsObject.wlt:385,1-392,2"
]

VerificationTest[
    #[ "Name" ] & /@ AgentToolsObjects[ "MockMCPPacletSkills/*" ],
    { "MockMCPPacletSkills/SkillsBundle", "MockMCPPacletSkills/DevBundle" },
    TestID -> "PacletBundle-AgentToolsObjects-Pattern@@Tests/AgentToolsObject.wlt:394,1-398,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*toAgentToolsObject*)
VerificationTest[
    toAgentToolsObject @ MCPServerObject[ "WolframAlpha" ],
    _AgentToolsObject? agentToolsObjectQ,
    SameTest -> MatchQ,
    TestID   -> "toAgentToolsObject-MCPServerObject@@Tests/AgentToolsObject.wlt:403,1-408,2"
]

VerificationTest[
    toAgentToolsObject[ MCPServerObject[ "WolframAlpha" ] ] /@ { "Name", "Location", "MCPServerNames", "AgentSkills", "ToolsetType" },
    { "WolframAlpha", "BuiltIn", { "WolframAlpha" }, { }, "MCPServerObject" },
    TestID -> "toAgentToolsObject-MCPServerObject-Properties@@Tests/AgentToolsObject.wlt:410,1-414,2"
]

VerificationTest[
    toAgentToolsObject @ $wolfram,
    $wolfram,
    TestID -> "toAgentToolsObject-AgentToolsObject@@Tests/AgentToolsObject.wlt:416,1-420,2"
]

VerificationTest[
    toAgentToolsObject[ "Wolfram" ],
    $wolfram,
    TestID -> "toAgentToolsObject-Name@@Tests/AgentToolsObject.wlt:422,1-426,2"
]

VerificationTest[
    toAgentToolsObject[ <| "Name" -> "Mine", "MCPServers" -> { "Wolfram" } |> ][ "Name" ],
    "Mine",
    TestID -> "toAgentToolsObject-Association@@Tests/AgentToolsObject.wlt:428,1-432,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ toAgentToolsObject[ 123 ],
    _Failure,
    { AgentTools::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "toAgentToolsObject-Invalid@@Tests/AgentToolsObject.wlt:434,1-440,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AgentToolsObjects*)
VerificationTest[
    AgentToolsObjects[ ],
    { ___AgentToolsObject? agentToolsObjectQ },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObjects-Installed@@Tests/AgentToolsObject.wlt:445,1-450,2"
]

VerificationTest[
    SubsetQ[ AgentToolsObjects[ "IncludeBuiltIn" -> True ], Values @ $DefaultAgentTools ],
    True,
    TestID -> "AgentToolsObjects-IncludeBuiltIn@@Tests/AgentToolsObject.wlt:452,1-456,2"
]

VerificationTest[
    AgentToolsObjects[ "Wolfram*", "IncludeBuiltIn" -> True ],
    { __AgentToolsObject? (StringStartsQ[ #[ "Name" ], "Wolfram" ] &) },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObjects-Pattern@@Tests/AgentToolsObject.wlt:458,1-463,2"
]

VerificationTest[
    AgentToolsObjects[ "NoSuchName*", "IncludeBuiltIn" -> True ],
    { },
    TestID -> "AgentToolsObjects-PatternNoMatch@@Tests/AgentToolsObject.wlt:465,1-469,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatting*)
VerificationTest[
    MakeBoxes[ $wolfram, StandardForm ],
    Except[ _MakeBoxes ],
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-Formatting@@Tests/AgentToolsObject.wlt:474,1-479,2"
]

VerificationTest[
    ToBoxes @ $adHoc,
    Except[ _ToBoxes ],
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-Formatting-AdHoc@@Tests/AgentToolsObject.wlt:481,1-486,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet @ DeleteDirectory[ DirectoryName @ $testSkillDirectory, DeleteContents -> True ];
    PacletDirectoryUnload @ $mockPacletDirectory;
    True,
    True,
    TestID -> "Cleanup@@Tests/AgentToolsObject.wlt:491,1-497,2"
]

(* :!CodeAnalysis::EndBlock:: *)
