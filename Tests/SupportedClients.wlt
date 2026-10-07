(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/SupportedClients.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/SupportedClients.wlt:11,1-16,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DetectedMCPClients*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Returns an association of supported client metadata keyed by canonical name*)
VerificationTest[
    DetectedMCPClients[ ],
    KeyValuePattern[ { } ]?AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DetectedMCPClients-ReturnShape@@Tests/SupportedClients.wlt:25,1-30,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*All detected names are valid supported clients*)
VerificationTest[
    SubsetQ[ Keys @ $SupportedMCPClients, Keys @ DetectedMCPClients[ ] ],
    True,
    TestID -> "DetectedMCPClients-Subset@@Tests/SupportedClients.wlt:35,1-39,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Result preserves the ordering of $SupportedMCPClients*)
VerificationTest[
    With[ { detected = DetectedMCPClients[ ] },
        Keys[ detected ] === Select[ Keys @ $SupportedMCPClients, KeyExistsQ[ detected, # ] & ]
    ],
    True,
    TestID -> "DetectedMCPClients-Ordering@@Tests/SupportedClients.wlt:44,1-50,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid arguments*)
VerificationTest[
    DetectedMCPClients[ "bogus" ],
    _Failure,
    { DetectedMCPClients::InvalidArguments },
    SameTest -> MatchQ,
    TestID   -> "DetectedMCPClients-InvalidArguments@@Tests/SupportedClients.wlt:55,1-61,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Helpers*)

(* Path components of a File result relative to a base directory, so expectations don't depend on the separator. *)
relativePathParts[ File[ path_String ], base_String ] :=
    Replace[ FileNameSplit @ path, { Sequence @@ FileNameSplit @ base, rest___ } :> { rest } ];

relativePathParts[ other_, _ ] := other;

(* A synthetic registry entry that only supports agent skills (no "InstallLocation") *)
$skillsOnlyClient = <|
    "Aliases"              -> { },
    "DefaultToolset"       -> "WolframLanguage",
    "DisplayName"          -> "Skills Only Test Client",
    "Name"                 -> "SkillsOnlyTestClient",
    "ProjectSupport"       -> False,
    "SkillsLocation"       :> { $HomeDirectory, ".skillsonly", "skills" },
    "SkillsProjectPath"    -> { ".skillsonly", "skills" },
    "SkillsProjectSupport" -> True,
    "SkillsSupport"        -> True,
    "URL"                  -> "https://example.com"
|>;

(* A synthetic registry entry whose "SkillsLocation" is only defined for an OS that doesn't exist *)
$unknownOSSkillsClient = <|
    "Aliases"              -> { },
    "DefaultToolset"       -> "WolframLanguage",
    "DisplayName"          -> "Unknown OS Skills Test Client",
    "Name"                 -> "UnknownOSSkillsTestClient",
    "ProjectSupport"       -> False,
    "SkillsLocation"       -> <| "DefinitelyNotARealOS" :> { $HomeDirectory, ".unknownos", "skills" } |>,
    "SkillsProjectSupport" -> False,
    "SkillsSupport"        -> True,
    "URL"                  -> "https://example.com"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$SupportedClients*)
VerificationTest[
    $SupportedClients,
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "SupportedClients-ReturnsAssociation@@Tests/SupportedClients.wlt:106,1-111,2"
]

VerificationTest[
    Keys @ $SupportedClients,
    {
        "AmazonQ", "Antigravity", "AugmentCode", "AugmentCodeIDE", "ClaudeCode", "ClaudeDesktop", "Cline", "Codex",
        "Continue", "CopilotCLI", "Cursor", "GeminiCLI", "Goose", "Junie", "KimiCode", "Kiro", "LMStudio", "OpenCode",
        "QwenCode", "VisualStudioCode", "Windsurf", "Zed"
    },
    SameTest -> Equal,
    TestID   -> "SupportedClients-KeysSorted@@Tests/SupportedClients.wlt:113,1-122,2"
]

VerificationTest[
    MemberQ[ Attributes @ $SupportedClients, Protected ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedClients-Protected@@Tests/SupportedClients.wlt:124,1-129,2"
]

VerificationTest[
    AllTrue[
        Values @ $SupportedClients,
        BooleanQ @ #[ "SkillsSupport" ] && BooleanQ @ #[ "SkillsProjectSupport" ] && BooleanQ @ #[ "ProjectSupport" ] &
    ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedClients-DerivedSupportFlags@@Tests/SupportedClients.wlt:131,1-139,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$SupportedMCPClients is the InstallLocation subset*)
VerificationTest[
    $SupportedMCPClients === Select[ $SupportedClients, KeyExistsQ[ #, "InstallLocation" ] & ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-InstallLocationSubset@@Tests/SupportedClients.wlt:144,1-149,2"
]

(* Every current client supports MCP, so the value is unchanged for backward compatibility *)
VerificationTest[
    Keys @ $SupportedMCPClients === Keys @ $SupportedClients,
    True,
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-AllCurrentClients@@Tests/SupportedClients.wlt:152,1-157,2"
]

(* $SupportedMCPClients is not cached, so it follows a Block of $SupportedClients *)
VerificationTest[
    Block[
        {
            $SupportedClients = <|
                KeyTake[ $SupportedClients, { "Cursor" } ],
                "SkillsOnlyTestClient" -> $skillsOnlyClient
            |>
        },
        Keys @ $SupportedMCPClients
    ],
    { "Cursor" },
    SameTest -> Equal,
    TestID   -> "SupportedMCPClients-FollowsSupportedClients@@Tests/SupportedClients.wlt:160,1-173,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Skills support flags*)
VerificationTest[
    Keys @ Select[ $SupportedClients, ! #[ "SkillsSupport" ] & ],
    { "AmazonQ", "ClaudeDesktop", "LMStudio" },
    SameTest -> Equal,
    TestID   -> "SupportedClients-SkillsSupport-Unsupported@@Tests/SupportedClients.wlt:178,1-183,2"
]

VerificationTest[
    Keys @ Select[ $SupportedClients, ! #[ "SkillsProjectSupport" ] & ],
    { "AmazonQ", "ClaudeDesktop", "LMStudio" },
    SameTest -> Equal,
    TestID   -> "SupportedClients-SkillsProjectSupport-Unsupported@@Tests/SupportedClients.wlt:185,1-190,2"
]

VerificationTest[
    AllTrue[
        Values @ $SupportedClients,
        #[ "SkillsSupport" ] === KeyExistsQ[ #, "SkillsLocation" ] &&
            #[ "SkillsProjectSupport" ] === MatchQ[ #[ "SkillsProjectPath" ], { __String } ] &
    ],
    True,
    SameTest -> Equal,
    TestID   -> "SupportedClients-SkillsSupport-MatchesKeys@@Tests/SupportedClients.wlt:192,1-201,2"
]

(* ProjectSupport keeps its MCP-only meaning (e.g. Cursor has project skills but no project MCP config) *)
VerificationTest[
    {
        $SupportedClients[ "Cursor", "ProjectSupport" ],
        $SupportedClients[ "Cursor", "SkillsProjectSupport" ],
        $SupportedClients[ "AmazonQ", "ProjectSupport" ],
        $SupportedClients[ "AmazonQ", "SkillsProjectSupport" ]
    },
    { False, True, True, False },
    SameTest -> Equal,
    TestID   -> "SupportedClients-ProjectSupport-MCPOnly@@Tests/SupportedClients.wlt:204,1-214,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*SkillsProjectPath values*)
VerificationTest[
    Lookup[ #, "SkillsProjectPath", None ] & /@ $SupportedClients,
    <|
        "AmazonQ"          -> None,
        "Antigravity"      -> { ".agents", "skills" },
        "AugmentCode"      -> { ".augment", "skills" },
        "AugmentCodeIDE"   -> { ".augment", "skills" },
        "ClaudeCode"       -> { ".claude", "skills" },
        "ClaudeDesktop"    -> None,
        "Cline"            -> { ".cline", "skills" },
        "Codex"            -> { ".agents", "skills" },
        "Continue"         -> { ".continue", "skills" },
        "CopilotCLI"       -> { ".github", "skills" },
        "Cursor"           -> { ".cursor", "skills" },
        "GeminiCLI"        -> { ".gemini", "skills" },
        "Goose"            -> { ".agents", "skills" },
        "Junie"            -> { ".junie", "skills" },
        "KimiCode"         -> { ".kimi", "skills" },
        "Kiro"             -> { ".kiro", "skills" },
        "LMStudio"         -> None,
        "OpenCode"         -> { ".opencode", "skills" },
        "QwenCode"         -> { ".qwen", "skills" },
        "VisualStudioCode" -> { ".github", "skills" },
        "Windsurf"         -> { ".windsurf", "skills" },
        "Zed"              -> { ".agents", "skills" }
    |>,
    SameTest -> Equal,
    TestID   -> "SupportedClients-SkillsProjectPath-Values@@Tests/SupportedClients.wlt:219,1-247,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*skillsLocation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Setup*)
VerificationTest[
    $skillsTestHome = CreateDirectory[ ];
    DirectoryQ @ $skillsTestHome,
    True,
    SameTest -> Equal,
    TestID   -> "SkillsLocation-Setup@@Tests/SupportedClients.wlt:256,1-262,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*User-scope locations for every client*)
(* All user-scope skills locations are relative to $HomeDirectory, so a Block isolates them from the real home. *)
VerificationTest[
    Block[ { $HomeDirectory = $skillsTestHome },
        AssociationMap[
            relativePathParts[
                Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`skillsLocation[ #, $OperatingSystem ],
                $skillsTestHome
            ] &,
            Keys @ Select[ $SupportedClients, #[ "SkillsSupport" ] & ]
        ]
    ],
    <|
        "Antigravity"      -> { ".gemini", "antigravity", "skills" },
        "AugmentCode"      -> { ".augment", "skills" },
        "AugmentCodeIDE"   -> { ".augment", "skills" },
        "ClaudeCode"       -> { ".claude", "skills" },
        "Cline"            -> { ".cline", "skills" },
        "Codex"            -> { ".agents", "skills" },
        "Continue"         -> { ".continue", "skills" },
        "CopilotCLI"       -> { ".copilot", "skills" },
        "Cursor"           -> { ".cursor", "skills" },
        "GeminiCLI"        -> { ".gemini", "skills" },
        "Goose"            -> { ".agents", "skills" },
        "Junie"            -> { ".junie", "skills" },
        "KimiCode"         -> { ".kimi", "skills" },
        "Kiro"             -> { ".kiro", "skills" },
        "OpenCode"         -> { ".config", "opencode", "skills" },
        "QwenCode"         -> { ".qwen", "skills" },
        "VisualStudioCode" -> { ".copilot", "skills" },
        "Windsurf"         -> { ".codeium", "windsurf", "skills" },
        "Zed"              -> { ".agents", "skills" }
    |>,
    SameTest -> Equal,
    TestID   -> "SkillsLocation-AllClients@@Tests/SupportedClients.wlt:268,1-301,2"
]

(* The locations are the same on every operating system *)
VerificationTest[
    Block[ { $HomeDirectory = $skillsTestHome },
        Union @ Table[
            Wolfram`AgentTools`Common`skillsLocation[ "ClaudeCode", os ],
            { os, { "Windows", "MacOSX", "Unix" } }
        ]
    ],
    { _File },
    SameTest -> MatchQ,
    TestID   -> "SkillsLocation-SameOnEveryOS@@Tests/SupportedClients.wlt:304,1-314,2"
]

VerificationTest[
    Block[ { $HomeDirectory = $skillsTestHome },
        Wolfram`AgentTools`Common`skillsLocation[ "ClaudeCode" ] ===
            Wolfram`AgentTools`Common`skillsLocation[ "ClaudeCode", $OperatingSystem ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "SkillsLocation-DefaultOperatingSystem@@Tests/SupportedClients.wlt:316,1-324,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Aliases*)
VerificationTest[
    Block[ { $HomeDirectory = $skillsTestHome },
        {
            Wolfram`AgentTools`Common`skillsLocation[ "VSCode" ] ===
                Wolfram`AgentTools`Common`skillsLocation[ "VisualStudioCode" ],
            Wolfram`AgentTools`Common`skillsLocation[ "Copilot" ] ===
                Wolfram`AgentTools`Common`skillsLocation[ "CopilotCLI" ],
            Wolfram`AgentTools`Common`skillsLocation[ "AntigravityCLI" ] ===
                Wolfram`AgentTools`Common`skillsLocation[ "Antigravity" ]
        }
    ],
    { True, True, True },
    SameTest -> Equal,
    TestID   -> "SkillsLocation-Aliases@@Tests/SupportedClients.wlt:329,1-343,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Antigravity migrated vs. unmigrated*)
VerificationTest[
    Block[ { $HomeDirectory = $skillsTestHome },
        relativePathParts[ Wolfram`AgentTools`Common`skillsLocation[ "Antigravity" ], $skillsTestHome ]
    ],
    { ".gemini", "antigravity", "skills" },
    SameTest -> Equal,
    TestID   -> "SkillsLocation-Antigravity-Unmigrated@@Tests/SupportedClients.wlt:348,1-355,2"
]

VerificationTest[
    Block[ { $HomeDirectory = $skillsTestHome },
        CreateDirectory[ FileNameJoin @ { $skillsTestHome, ".gemini", "config" }, CreateIntermediateDirectories -> True ];
        CreateFile @ FileNameJoin @ { $skillsTestHome, ".gemini", "config", ".migrated" };
        {
            relativePathParts[ Wolfram`AgentTools`Common`skillsLocation[ "Antigravity" ], $skillsTestHome ],
            (* The MCP location follows the same marker *)
            relativePathParts[ Wolfram`AgentTools`Common`installLocation[ "Antigravity" ], $skillsTestHome ]
        }
    ],
    { { ".gemini", "config", "skills" }, { ".gemini", "config", "mcp_config.json" } },
    SameTest -> Equal,
    TestID   -> "SkillsLocation-Antigravity-Migrated@@Tests/SupportedClients.wlt:357,1-370,2"
]

VerificationTest[
    Block[ { $HomeDirectory = $skillsTestHome },
        Wolfram`AgentTools`SupportedClients`Private`antigravitySkillsLocation[ ]
    ],
    { $skillsTestHome, ".gemini", "config", "skills" },
    SameTest -> Equal,
    TestID   -> "AntigravitySkillsLocation-Helper@@Tests/SupportedClients.wlt:372,1-379,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UnsupportedSkillsClient*)
VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`skillsLocation[ "ClaudeDesktop" ],
    Failure[ "AgentTools::UnsupportedSkillsClient", _ ],
    { AgentTools::UnsupportedSkillsClient },
    SameTest -> MatchQ,
    TestID   -> "SkillsLocation-Unsupported-ClaudeDesktop@@Tests/SupportedClients.wlt:384,1-390,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`skillsLocation[ "LMStudio" ],
    Failure[ "AgentTools::UnsupportedSkillsClient", _ ],
    { AgentTools::UnsupportedSkillsClient },
    SameTest -> MatchQ,
    TestID   -> "SkillsLocation-Unsupported-LMStudio@@Tests/SupportedClients.wlt:392,1-398,2"
]

(* "Q" is an alias of AmazonQ, so the failure names the canonical client *)
VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`skillsLocation[ "Q", "Unix" ],
    Failure[ "AgentTools::UnsupportedSkillsClient", KeyValuePattern[ "MessageParameters" :> { "AmazonQ" } ] ],
    { AgentTools::UnsupportedSkillsClient },
    SameTest -> MatchQ,
    TestID   -> "SkillsLocation-Unsupported-AmazonQAlias@@Tests/SupportedClients.wlt:401,1-407,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`skillsLocation[ "NotARealClient" ],
    Failure[ "AgentTools::UnsupportedSkillsClient", _ ],
    { AgentTools::UnsupportedSkillsClient },
    SameTest -> MatchQ,
    TestID   -> "SkillsLocation-Unsupported-UnknownClient@@Tests/SupportedClients.wlt:409,1-415,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UnknownSkillsLocation*)
VerificationTest[
    Block[ { $SupportedClients = <| "UnknownOSSkillsTestClient" -> $unknownOSSkillsClient |> },
        Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`skillsLocation[
            "UnknownOSSkillsTestClient",
            "Unix"
        ]
    ],
    Failure[
        "AgentTools::UnknownSkillsLocation",
        KeyValuePattern[ "MessageParameters" :> { "UnknownOSSkillsTestClient", "Unix" } ]
    ],
    { AgentTools::UnknownSkillsLocation },
    SameTest -> MatchQ,
    TestID   -> "SkillsLocation-UnknownSkillsLocation@@Tests/SupportedClients.wlt:420,1-434,2"
]

VerificationTest[
    Block[ { $SupportedClients = <| "UnknownOSSkillsTestClient" -> $unknownOSSkillsClient |>, $HomeDirectory = $skillsTestHome },
        relativePathParts[
            Wolfram`AgentTools`Common`skillsLocation[ "UnknownOSSkillsTestClient", "DefinitelyNotARealOS" ],
            $skillsTestHome
        ]
    ],
    { ".unknownos", "skills" },
    SameTest -> Equal,
    TestID   -> "SkillsLocation-PerOSAssociation@@Tests/SupportedClients.wlt:436,1-446,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*projectSkillsLocation*)
VerificationTest[
    relativePathParts[
        Wolfram`AgentTools`Common`projectSkillsLocation[ "ClaudeCode", $skillsTestHome ],
        $skillsTestHome
    ],
    { ".claude", "skills" },
    SameTest -> Equal,
    TestID   -> "ProjectSkillsLocation-ClaudeCode@@Tests/SupportedClients.wlt:451,1-459,2"
]

VerificationTest[
    relativePathParts[
        Wolfram`AgentTools`Common`projectSkillsLocation[ "ClaudeCode", File @ $skillsTestHome ],
        $skillsTestHome
    ],
    { ".claude", "skills" },
    SameTest -> Equal,
    TestID   -> "ProjectSkillsLocation-FileWrapper@@Tests/SupportedClients.wlt:461,1-469,2"
]

VerificationTest[
    relativePathParts[ Wolfram`AgentTools`Common`projectSkillsLocation[ #, $skillsTestHome ], $skillsTestHome ] & /@
        { "VSCode", "CopilotCLI", "Antigravity", "AntigravityCLI", "OpenCode", "Windsurf" },
    {
        { ".github", "skills" },
        { ".github", "skills" },
        { ".agents", "skills" },
        { ".agents", "skills" },
        { ".opencode", "skills" },
        { ".windsurf", "skills" }
    },
    SameTest -> Equal,
    TestID   -> "ProjectSkillsLocation-AliasesAndClients@@Tests/SupportedClients.wlt:471,1-484,2"
]

VerificationTest[
    AllTrue[
        Keys @ Select[ $SupportedClients, #[ "SkillsProjectSupport" ] & ],
        MatchQ[
            Wolfram`AgentTools`Common`projectSkillsLocation[ #, $skillsTestHome ],
            File[ _String ]
        ] &
    ],
    True,
    SameTest -> Equal,
    TestID   -> "ProjectSkillsLocation-AllSupportedClients@@Tests/SupportedClients.wlt:486,1-497,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UnsupportedSkillsClientProject*)
VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`projectSkillsLocation[ #, $skillsTestHome ] & /@
        { "ClaudeDesktop", "LMStudio", "AmazonQ", "NotARealClient" },
    {
        Failure[ "AgentTools::UnsupportedSkillsClientProject", _ ],
        Failure[ "AgentTools::UnsupportedSkillsClientProject", _ ],
        Failure[ "AgentTools::UnsupportedSkillsClientProject", _ ],
        Failure[ "AgentTools::UnsupportedSkillsClientProject", _ ]
    },
    {
        AgentTools::UnsupportedSkillsClientProject,
        AgentTools::UnsupportedSkillsClientProject,
        AgentTools::UnsupportedSkillsClientProject,
        General::stop
    },
    SameTest -> MatchQ,
    TestID   -> "ProjectSkillsLocation-Unsupported@@Tests/SupportedClients.wlt:502,1-519,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*InvalidProjectDirectory*)
VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`projectSkillsLocation[ "ClaudeCode", 123 ],
    Failure[ "AgentTools::InvalidProjectDirectory", _ ],
    { AgentTools::InvalidProjectDirectory },
    SameTest -> MatchQ,
    TestID   -> "ProjectSkillsLocation-InvalidDirectory-Integer@@Tests/SupportedClients.wlt:524,1-530,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`projectSkillsLocation[ "ClaudeCode", Symbol[ "xyz" ] ],
    Failure[ "AgentTools::InvalidProjectDirectory", _ ],
    { AgentTools::InvalidProjectDirectory },
    SameTest -> MatchQ,
    TestID   -> "ProjectSkillsLocation-InvalidDirectory-Symbol@@Tests/SupportedClients.wlt:532,1-538,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Clients Without an InstallLocation*)
(* "InstallLocation" is optional in principle (a future skills-only client). Such clients must fail with
   UnsupportedMCPClient instead of an internal failure, and must never be enumerated as MCP clients. *)
VerificationTest[
    Block[ { $SupportedClients = <| "SkillsOnlyTestClient" -> $skillsOnlyClient |> },
        Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`installLocation[ "SkillsOnlyTestClient" ]
    ],
    Failure[ "AgentTools::UnsupportedMCPClient", _ ],
    { AgentTools::UnsupportedMCPClient },
    SameTest -> MatchQ,
    TestID   -> "InstallLocation-NoInstallLocation-UnsupportedMCPClient@@Tests/SupportedClients.wlt:545,1-553,2"
]

VerificationTest[
    Block[ { $SupportedClients = <| "SkillsOnlyTestClient" -> $skillsOnlyClient |> },
        Wolfram`AgentTools`Common`catchAlways @ Wolfram`AgentTools`Common`projectInstallLocation[
            "SkillsOnlyTestClient",
            $skillsTestHome
        ]
    ],
    Failure[ "AgentTools::UnsupportedMCPClient", _ ],
    { AgentTools::UnsupportedMCPClient },
    SameTest -> MatchQ,
    TestID   -> "ProjectInstallLocation-NoInstallLocation-UnsupportedMCPClient@@Tests/SupportedClients.wlt:555,1-566,2"
]

VerificationTest[
    Block[ { $SupportedClients = <| "SkillsOnlyTestClient" -> $skillsOnlyClient |>, $HomeDirectory = $skillsTestHome },
        {
            relativePathParts[ Wolfram`AgentTools`Common`skillsLocation[ "SkillsOnlyTestClient" ], $skillsTestHome ],
            relativePathParts[
                Wolfram`AgentTools`Common`projectSkillsLocation[ "SkillsOnlyTestClient", $skillsTestHome ],
                $skillsTestHome
            ]
        }
    ],
    { { ".skillsonly", "skills" }, { ".skillsonly", "skills" } },
    SameTest -> Equal,
    TestID   -> "SkillsLocation-SkillsOnlyClient@@Tests/SupportedClients.wlt:568,1-581,2"
]

VerificationTest[
    Block[
        {
            $SupportedClients = <|
                KeyTake[ $SupportedClients, { "Cursor" } ],
                "SkillsOnlyTestClient" -> $skillsOnlyClient
            |>,
            $HomeDirectory = $skillsTestHome
        },
        (* Make both clients look installed *)
        CreateDirectory[ FileNameJoin @ { $skillsTestHome, ".cursor" }, CreateIntermediateDirectories -> True ];
        CreateFile @ FileNameJoin @ { $skillsTestHome, ".cursor", "mcp.json" };
        CreateDirectory[ FileNameJoin @ { $skillsTestHome, ".skillsonly", "skills" }, CreateIntermediateDirectories -> True ];
        Keys @ DetectedMCPClients[ ]
    ],
    { "Cursor" },
    SameTest -> Equal,
    TestID   -> "DetectedMCPClients-SkipsClientsWithoutInstallLocation@@Tests/SupportedClients.wlt:583,1-601,2"
]

VerificationTest[
    Block[
        {
            $SupportedClients = <|
                "SkillsOnlyTestClient" -> $skillsOnlyClient,
                KeyTake[ $SupportedClients, { "Cursor" } ]
            |>,
            $HomeDirectory = $skillsTestHome
        },
        Wolfram`AgentTools`Common`guessClientName @ File @ FileNameJoin @ { $skillsTestHome, ".cursor", "mcp.json" }
    ],
    "Cursor",
    SameTest -> Equal,
    TestID   -> "GuessClientName-SkipsClientsWithoutInstallLocation@@Tests/SupportedClients.wlt:603,1-617,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    DeleteDirectory[ $skillsTestHome, DeleteContents -> True ];
    DirectoryQ @ $skillsTestHome,
    False,
    SameTest -> Equal,
    TestID   -> "SkillsLocation-Cleanup@@Tests/SupportedClients.wlt:622,1-628,2"
]

(* :!CodeAnalysis::EndBlock:: *)
