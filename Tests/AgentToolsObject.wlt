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
    $wolfram /@ { "Name", "Location", "AgentSkills", "MCPServerNames", "AgentSkillNames", "ToolsetType" },
    { "Wolfram", "BuiltIn", { }, { "Wolfram" }, { }, "AgentToolsObject" },
    TestID -> "AgentToolsObject-BuiltIn-Properties@@Tests/AgentToolsObject.wlt:94,1-98,2"
]

VerificationTest[
    $wolfram[ "Description" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-BuiltIn-Description@@Tests/AgentToolsObject.wlt:100,1-105,2"
]

VerificationTest[
    $wolfram[ "MCPServers" ],
    { _MCPServerObject? MCPServerObjectQ },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-BuiltIn-MCPServers@@Tests/AgentToolsObject.wlt:107,1-112,2"
]

VerificationTest[
    $wolfram[ "MCPServers" ] === $wolfram[ "MCPServerObjects" ] === { MCPServerObject[ "Wolfram" ] },
    True,
    TestID -> "AgentToolsObject-BuiltIn-MCPServerObjects@@Tests/AgentToolsObject.wlt:114,1-118,2"
]

VerificationTest[
    #[ "Name" ] & /@ $wolfram[ "Tools" ],
    #[ "Name" ] & /@ MCPServerObject[ "Wolfram" ][ "Tools" ],
    TestID -> "AgentToolsObject-BuiltIn-Tools@@Tests/AgentToolsObject.wlt:120,1-124,2"
]

VerificationTest[
    $wolfram /@ { "AgentSkills", "Skills", "LLMSkills" },
    { { }, { }, { } },
    TestID -> "AgentToolsObject-BuiltIn-LLMSkills@@Tests/AgentToolsObject.wlt:126,1-130,2"
]

VerificationTest[
    SubsetQ[
        $wolfram[ "Properties" ],
        { "Name", "MCPServers", "MCPServerNames", "AgentSkills", "AgentSkillNames", "Skills", "Tools", "Data" }
    ],
    True,
    TestID -> "AgentToolsObject-Properties@@Tests/AgentToolsObject.wlt:132,1-139,2"
]

VerificationTest[
    $wolfram[ { "Name", "Location" } ],
    <| "Name" -> "Wolfram", "Location" -> "BuiltIn" |>,
    TestID -> "AgentToolsObject-PropertyList@@Tests/AgentToolsObject.wlt:141,1-145,2"
]

VerificationTest[
    $wolfram[ "NotAProperty" ],
    Missing[ "UnknownProperty", "NotAProperty" ],
    TestID -> "AgentToolsObject-UnknownProperty@@Tests/AgentToolsObject.wlt:147,1-151,2"
]

VerificationTest[
    $wolfram[ 1 ],
    _Failure,
    { AgentToolsObject::InvalidProperty },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-InvalidProperty@@Tests/AgentToolsObject.wlt:153,1-159,2"
]

VerificationTest[
    AgentToolsObject @ $wolfram,
    $wolfram,
    TestID -> "AgentToolsObject-Idempotent@@Tests/AgentToolsObject.wlt:161,1-165,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Not Found*)
VerificationTest[
    AgentToolsObject[ "NoSuchAgentTools" ],
    _Failure,
    { AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-NotFound@@Tests/AgentToolsObject.wlt:170,1-176,2"
]

VerificationTest[
    AgentToolsObject[ "NoSuchPublisher" <> CreateUUID[ ] <> "/NoSuchPaclet/NoSuchBundle" ],
    _Failure,
    { AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-NotFound-Qualified@@Tests/AgentToolsObject.wlt:178,1-184,2"
]

VerificationTest[
    AgentToolsObject[ 1, 2 ],
    _Failure,
    { AgentToolsObject::InvalidArguments },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-InvalidArguments@@Tests/AgentToolsObject.wlt:186,1-192,2"
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
    TestID   -> "AgentToolsObject-AdHoc@@Tests/AgentToolsObject.wlt:197,1-207,2"
]

VerificationTest[
    $adHoc /@ { "Name", "Location", "MCPServerNames", "AgentSkillNames", "Description" },
    { "MyTools", None, { "WolframLanguage" }, { "my-test-skill", "dir-test-skill" }, "Tools for testing" },
    TestID -> "AgentToolsObject-AdHoc-Properties@@Tests/AgentToolsObject.wlt:209,1-213,2"
]

VerificationTest[
    $adHoc[ "MCPServers" ],
    { MCPServerObject[ "WolframLanguage" ] },
    TestID -> "AgentToolsObject-AdHoc-MCPServers@@Tests/AgentToolsObject.wlt:215,1-219,2"
]

VerificationTest[
    $adHoc[ "AgentSkills" ],
    { $testSkill, HoldPattern[ LLMSkill ][ KeyValuePattern[ "Name" -> "dir-test-skill" ] ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-AgentSkills@@Tests/AgentToolsObject.wlt:221,1-226,2"
]

VerificationTest[
    $adHoc[ "AgentSkills" ] === $adHoc[ "Skills" ] === $adHoc[ "LLMSkills" ],
    True,
    TestID -> "AgentToolsObject-AdHoc-SkillsAliases@@Tests/AgentToolsObject.wlt:228,1-232,2"
]

(* The stored specifications are kept as given *)
VerificationTest[
    Lookup[ $adHoc[ "Data" ], { "MCPServers", "AgentSkills" } ],
    { { "WolframLanguage" }, { $testSkill, File @ $testSkillDirectory } },
    TestID -> "AgentToolsObject-AdHoc-StoredSpecs@@Tests/AgentToolsObject.wlt:235,1-239,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "OnlySkills", "AgentSkills" -> $testSkill |>,
    _AgentToolsObject? (#[ "MCPServers" ] === { } && #[ "AgentSkills" ] === { $testSkill } &),
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-SkillsOnly@@Tests/AgentToolsObject.wlt:241,1-246,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "Empty" |>,
    _AgentToolsObject? (#[ "MCPServers" ] === { } && #[ "AgentSkills" ] === { } &),
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-Empty@@Tests/AgentToolsObject.wlt:248,1-253,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "WithServerObject", "MCPServers" -> { MCPServerObject[ "WolframAlpha" ] } |>,
    _AgentToolsObject? (#[ "MCPServerNames" ] === { "WolframAlpha" } &),
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-ServerObject@@Tests/AgentToolsObject.wlt:255,1-260,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Ad Hoc Bundles*)
VerificationTest[
    AgentToolsObject @ <| "Name" -> "Wolfram", "MCPServers" -> { "Wolfram" } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-BuiltInName@@Tests/AgentToolsObject.wlt:265,1-271,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "Publisher/Paclet/Bundle" |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-ReservedName@@Tests/AgentToolsObject.wlt:273,1-279,2"
]

VerificationTest[
    AgentToolsObject @ <| "MCPServers" -> { "Wolfram" } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-NoName@@Tests/AgentToolsObject.wlt:281,1-287,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "BadServers", "MCPServers" -> { 1 } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-InvalidServers@@Tests/AgentToolsObject.wlt:289,1-295,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "BadSkills", "AgentSkills" -> { 1 } |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-InvalidSkills@@Tests/AgentToolsObject.wlt:297,1-303,2"
]

VerificationTest[
    AgentToolsObject @ <| "Name" -> "BadDescription", "Description" -> 1 |>,
    _Failure,
    { AgentToolsObject::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-InvalidDescription@@Tests/AgentToolsObject.wlt:305,1-311,2"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "BadSkillFile", "AgentSkills" -> { File[ "/no/such/skill/dir" ] } |> ][ "AgentSkills" ],
    _Failure,
    { AgentToolsObject::InvalidAgentSkill },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AdHoc-AgentSkills-InvalidFile@@Tests/AgentToolsObject.wlt:313,1-319,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Skill Specifications*)
VerificationTest[
    AgentToolsObject[ <| "Name" -> "NoBody", "AgentSkills" -> { <| "Name" -> "t-skill", "Description" -> "d" |> } |> ][ "AgentSkills" ],
    { HoldPattern[ LLMSkill ][ KeyValuePattern @ { "Name" -> "t-skill", "Body" -> "" } ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AgentSkills-NoBody@@Tests/AgentToolsObject.wlt:324,1-329,2"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "OtherType", "AgentSkills" -> { <| "Name" -> "t-skill", "Description" -> "d", "Body" -> "b", "Type" -> "Skill" |> } |> ][ "AgentSkills" ],
    { HoldPattern[ LLMSkill ][ KeyValuePattern @ { "Name" -> "t-skill", "Body" -> "b" } ] },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-AgentSkills-OtherTypeKey@@Tests/AgentToolsObject.wlt:331,1-336,2"
]

VerificationTest[
    AgentToolsObject[ <| "Name" -> "OddNames", "AgentSkills" -> { "", "a/b" } |> ][ "AgentSkillNames" ],
    { "", "a/b" },
    TestID -> "AgentToolsObject-AgentSkillNames-OddStrings@@Tests/AgentToolsObject.wlt:338,1-342,2"
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
    TestID   -> "PacletBundle-ByName@@Tests/AgentToolsObject.wlt:350,1-355,2"
]

VerificationTest[
    $pacletBundle /@ { "Name", "MCPServerNames", "Description", "ToolsetType" },
    { "MockMCPPacletSkills/SkillsBundle", { "MockMCPPacletSkills/SkillsServer" }, "Servers and skills for testing", "AgentToolsObject" },
    TestID -> "PacletBundle-Properties@@Tests/AgentToolsObject.wlt:357,1-361,2"
]

VerificationTest[
    $pacletBundle[ "AgentSkillNames" ],
    "MockMCPPacletSkills/" <> # & /@ {
        "directory-skill", "assoc-skill", "llmskill-skill", "combined-skill", "located-skill", "foreign-skill"
    },
    TestID -> "PacletBundle-AgentSkillNames@@Tests/AgentToolsObject.wlt:363,1-369,2"
]

VerificationTest[
    $pacletBundle[ "Location" ],
    _PacletObject,
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-Location@@Tests/AgentToolsObject.wlt:371,1-376,2"
]

VerificationTest[
    #[ "Name" ] & /@ $pacletBundle[ "AgentSkills" ],
    { "directory-skill", "assoc-skill", "llmskill-skill", "combined-skill", "located-skill", "foreign-skill" },
    TestID -> "PacletBundle-AgentSkills@@Tests/AgentToolsObject.wlt:378,1-382,2"
]

VerificationTest[
    $pacletBundle[ "Skills" ] === $pacletBundle[ "AgentSkills" ],
    True,
    TestID -> "PacletBundle-Skills@@Tests/AgentToolsObject.wlt:384,1-388,2"
]

VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills/DevBundle" ][ "MCPServerNames" ],
    { "MockMCPPacletSkills/SkillsServer", "MockMCPPacletSkills/DevServer" },
    TestID -> "PacletBundle-SecondEntry@@Tests/AgentToolsObject.wlt:390,1-394,2"
]

VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills/DevBundle" ][ "MCPServers" ],
    { MCPServerObject[ "MockMCPPacletSkills/SkillsServer" ], MCPServerObject[ "MockMCPPacletSkills/DevServer" ] },
    TestID -> "PacletBundle-SecondEntry-MCPServers@@Tests/AgentToolsObject.wlt:396,1-400,2"
]

(* Entries for other systems define no bundle *)
VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills/PerSystemBundle" ],
    _Failure,
    { AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-OtherSystem@@Tests/AgentToolsObject.wlt:403,1-409,2"
]

VerificationTest[
    AgentToolsObject[ "MockMCPPacletSkills" ],
    _Failure,
    { AgentToolsObject::AgentToolsBundleNameAmbiguous },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-PacletNameAmbiguous@@Tests/AgentToolsObject.wlt:411,1-417,2"
]

VerificationTest[
    { AgentToolsObject[ "MockMCPPacletSkill*" ], AgentToolsObject[ "MockMCPPacletSkills/Skills*" ] },
    { _Failure, _Failure },
    { AgentToolsObject::AgentToolsNotFound, AgentToolsObject::AgentToolsNotFound },
    SameTest -> MatchQ,
    TestID   -> "PacletBundle-NoWildcards@@Tests/AgentToolsObject.wlt:419,1-425,2"
]

VerificationTest[
    SubsetQ[
        #[ "Name" ] & /@ AgentToolsObjects[ ],
        { "MockMCPPacletSkills/SkillsBundle", "MockMCPPacletSkills/DevBundle" }
    ],
    True,
    TestID -> "PacletBundle-AgentToolsObjects@@Tests/AgentToolsObject.wlt:427,1-434,2"
]

VerificationTest[
    #[ "Name" ] & /@ AgentToolsObjects[ "MockMCPPacletSkills/*" ],
    { "MockMCPPacletSkills/SkillsBundle", "MockMCPPacletSkills/DevBundle" },
    TestID -> "PacletBundle-AgentToolsObjects-Pattern@@Tests/AgentToolsObject.wlt:436,1-440,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*toAgentToolsObject*)
VerificationTest[
    toAgentToolsObject @ MCPServerObject[ "WolframAlpha" ],
    _AgentToolsObject? agentToolsObjectQ,
    SameTest -> MatchQ,
    TestID   -> "toAgentToolsObject-MCPServerObject@@Tests/AgentToolsObject.wlt:445,1-450,2"
]

VerificationTest[
    toAgentToolsObject[ MCPServerObject[ "WolframAlpha" ] ] /@ { "Name", "Location", "MCPServerNames", "MCPServers", "AgentSkills", "ToolsetType" },
    { "WolframAlpha", "BuiltIn", { "WolframAlpha" }, { MCPServerObject[ "WolframAlpha" ] }, { }, "MCPServerObject" },
    TestID -> "toAgentToolsObject-MCPServerObject-Properties@@Tests/AgentToolsObject.wlt:452,1-456,2"
]

VerificationTest[
    toAgentToolsObject @ $wolfram,
    $wolfram,
    TestID -> "toAgentToolsObject-AgentToolsObject@@Tests/AgentToolsObject.wlt:458,1-462,2"
]

VerificationTest[
    toAgentToolsObject[ "Wolfram" ],
    $wolfram,
    TestID -> "toAgentToolsObject-Name@@Tests/AgentToolsObject.wlt:464,1-468,2"
]

VerificationTest[
    toAgentToolsObject[ <| "Name" -> "Mine", "MCPServers" -> { "Wolfram" } |> ][ "Name" ],
    "Mine",
    TestID -> "toAgentToolsObject-Association@@Tests/AgentToolsObject.wlt:470,1-474,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ toAgentToolsObject[ 123 ],
    _Failure,
    { AgentTools::InvalidAgentToolsObject },
    SameTest -> MatchQ,
    TestID   -> "toAgentToolsObject-Invalid@@Tests/AgentToolsObject.wlt:476,1-482,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AgentToolsObjects*)
VerificationTest[
    AgentToolsObjects[ ],
    { ___AgentToolsObject? agentToolsObjectQ },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObjects-Installed@@Tests/AgentToolsObject.wlt:487,1-492,2"
]

VerificationTest[
    SubsetQ[ AgentToolsObjects[ "IncludeBuiltIn" -> True ], Values @ $DefaultAgentTools ],
    True,
    TestID -> "AgentToolsObjects-IncludeBuiltIn@@Tests/AgentToolsObject.wlt:494,1-498,2"
]

VerificationTest[
    AgentToolsObjects[ "Wolfram*", "IncludeBuiltIn" -> True ],
    { __AgentToolsObject? (StringStartsQ[ #[ "Name" ], "Wolfram" ] &) },
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObjects-Pattern@@Tests/AgentToolsObject.wlt:500,1-505,2"
]

VerificationTest[
    AgentToolsObjects[ "NoSuchName*", "IncludeBuiltIn" -> True ],
    { },
    TestID -> "AgentToolsObjects-PatternNoMatch@@Tests/AgentToolsObject.wlt:507,1-511,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatting*)
VerificationTest[
    MakeBoxes[ $wolfram, StandardForm ],
    Except[ _MakeBoxes ],
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-Formatting@@Tests/AgentToolsObject.wlt:516,1-521,2"
]

VerificationTest[
    ToBoxes @ $adHoc,
    Except[ _ToBoxes ],
    SameTest -> MatchQ,
    TestID   -> "AgentToolsObject-Formatting-AdHoc@@Tests/AgentToolsObject.wlt:523,1-528,2"
]

VerificationTest[
    With[ { boxes = ToString[ ToBoxes @ $wolfram, InputForm ] },
        {
            StringContainsQ[ boxes, "Tools for general computation and knowledge" ],
            StringFreeQ[ boxes, "TruncateStringToWidth" ]
        }
    ],
    { True, True },
    TestID -> "AgentToolsObject-Formatting-Description@@Tests/AgentToolsObject.wlt:530,1-539,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet @ DeleteDirectory[ DirectoryName @ $testSkillDirectory, DeleteContents -> True ];
    PacletDirectoryUnload @ $mockPacletDirectory;
    True,
    True,
    TestID -> "Cleanup@@Tests/AgentToolsObject.wlt:544,1-550,2"
]

(* :!CodeAnalysis::EndBlock:: *)
