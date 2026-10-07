(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/AgentSkillsBuild.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/AgentSkillsBuild.wlt:11,1-16,2"
]

(* The builder is loaded from the checkout, never from the loaded paclet: in CI the tests run against a build directory
   that has no Scripts/ or AgentSkills/ directories. *)
VerificationTest[
    Get @ FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "Scripts", "Resources", "AgentSkillsBuilder.wl" },
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadBuilder@@Tests/AgentSkillsBuild.wlt:20,1-25,2"
]

VerificationTest[
    Length @ DownValues @ # > 0 & /@ {
        Wolfram`AgentSkillsBuilder`buildAgentSkills,
        Wolfram`AgentSkillsBuilder`agentSkillsDifferences,
        Wolfram`AgentSkillsBuilder`agentSkillsVersion,
        Wolfram`AgentSkillsBuilder`stampSkillVersion
    },
    { True, True, True, True },
    SameTest -> SameQ,
    TestID   -> "LoadBuilder-Definitions@@Tests/AgentSkillsBuild.wlt:27,1-37,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Helper Functions*)
(* The builder functions are always called by their full names (Wolfram`AgentSkillsBuilder`...), since the builder's
   context may or may not be on $ContextPath when the expressions of this file are read. Nothing in this file writes
   outside $skillsBuildTestBase (removed at the end of the file) and the CreateDirectory[ ] directory of the staleness
   test (removed by the test itself). *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Paths*)
(* Every source path is derived from the checkout (the directory that contains Tests/), not from the loaded paclet *)
$skillsCheckoutDirectory   = FileNameDrop[ ExpandFileName @ $TestFileName, -2 ];
$skillsSourceDirectory     = FileNameJoin @ { $skillsCheckoutDirectory, "AgentSkills", "Skills" };
$skillsReferencesDirectory = FileNameJoin @ { $skillsCheckoutDirectory, "AgentSkills", "References" };
$skillsManifestPath        = FileNameJoin @ { $skillsCheckoutDirectory, "AgentSkills", "Manifest.wl" };
$skillsCommittedDirectory  = FileNameJoin @ { $skillsCheckoutDirectory, "Assets", "AgentSkills" };
$skillsTemplateFile        = FileNameJoin @ { $skillsCheckoutDirectory, "Scripts", "Resources", "SkillScriptTemplate.wls" };
$skillsMarketplaceFile     = FileNameJoin @ { $skillsCheckoutDirectory, ".claude-plugin", "marketplace.json" };
$skillsPacletInfoFile      = FileNameJoin @ { $skillsCheckoutDirectory, "PacletInfo.wl" };

(* The "AgentSkills" asset of the loaded paclet (the checkout itself, or the built paclet in CI) *)
$skillsAssetLocation := PacletObject[ "Wolfram/AgentTools" ][ "AssetLocation", "AgentSkills" ];

$skillsManifest = Get @ $skillsManifestPath;

$expectedSkillNames = { "wolfram-alpha", "wolfram-language", "wolfram-notebooks", "wolfram-paclets" };

(* Files every built skill must contain, in addition to its scripts *)
$requiredSkillFiles = {
    "SKILL.md",
    "references/GetWolframEngine.md",
    "references/Scripts.md",
    "references/SetUpWolframMCPServer.md"
};

$emptySkillsDifferences = <| "Missing" -> { }, "Extra" -> { }, "Different" -> { } |>;

ifBuiltPaclet  = conditionalTest[ TrueQ @ Wolfram`AgentToolsTests`$BuiltPaclet ];
ifSourcePaclet = conditionalTest[ ! TrueQ @ Wolfram`AgentToolsTests`$BuiltPaclet ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Temporary Directories*)
$skillsBuildTestBase = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, "AgentSkillsBuildTests_" <> CreateUUID[ ] };

(* A fresh, empty directory *)
skillsBuildDirectory[ ] := CreateDirectory @ FileNameJoin @ { $skillsBuildTestBase, CreateUUID[ ] };

(* A path that does not exist yet, in a fresh directory *)
skillsBuildNewPath[ ] := FileNameJoin @ { skillsBuildDirectory[ ], "out" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Files*)
(* Writes UTF-8 bytes exactly as given (no line ending conversion), creating parent directories *)
writeSkillsBuildFile[ file_String, content_String ] := (
    If[ ! DirectoryQ @ DirectoryName @ file, CreateDirectory @ DirectoryName @ file ];
    With[ { stream = OpenWrite[ file, BinaryFormat -> True ] },
        If[ content =!= "", BinaryWrite[ stream, StringToByteArray[ content, "UTF-8" ] ] ];
        Close @ stream
    ];
    file
);

(* The exact UTF-8 text of a file *)
readSkillsBuildFile[ file_String ] :=
    Replace[ ReadByteArray @ file, { bytes_ByteArray :> ByteArrayToString[ bytes, "UTF-8" ], EndOfFile -> "" } ];

(* The text of a file with CRLF line endings normalized to LF (a checkout on Windows may use CRLF) *)
readSkillsBuildText[ file_String ] := StringReplace[ readSkillsBuildFile @ file, "\r\n" -> "\n" ];

(* Operating system metadata files that desktop file managers create (git-ignored; also ignored by the builder) *)
skillsBuildJunkQ[ path_String ] := MemberQ[ { ".ds_store", "thumbs.db", "desktop.ini" }, ToLowerCase @ FileNameTake @ path ];

(* The sorted relative paths (using "/") of all files under dir, or {} if dir is not a directory *)
skillsBuildFiles[ dir_String ] /; DirectoryQ @ dir := Sort[
    StringRiffle[ Drop[ FileNameSplit @ #, Length @ FileNameSplit @ dir ], "/" ] & /@
        Select[ FileNames[ All, dir, Infinity ], FileType @ # === File && ! skillsBuildJunkQ @ # & ]
];

skillsBuildFiles[ _ ] := { };

(* The sorted names of all entries (files and directories) directly in dir *)
skillsBuildEntries[ dir_String ] /; DirectoryQ @ dir := Sort[ FileNameTake /@ Select[ FileNames[ All, dir ], ! skillsBuildJunkQ @ # & ] ];
skillsBuildEntries[ _ ] := { };

sameDirectoryQ[ a_String, b_String ] := FileNameSplit @ ExpandFileName @ a === FileNameSplit @ ExpandFileName @ b;
sameDirectoryQ[ _, _ ] := False;

(* The lines of a text that start with "  version:" (the stamped metadata.version entry) *)
versionLines[ text_String ] := Select[ StringSplit[ text, "\n", All ], StringStartsQ[ "  version:" ] ];

(* True if the numeric dotted version a is not newer than b *)
skillsVersionNotNewerQ[ a_String, b_String ] /;
    StringMatchQ[ a <> "." <> b, (DigitCharacter.. ~~ ".")... ~~ DigitCharacter.. ] :=
    Module[ { va, vb, n },
        va = FromDigits /@ StringSplit[ a, "." ];
        vb = FromDigits /@ StringSplit[ b, "." ];
        n  = Max[ Length @ va, Length @ vb ];
        Order[ PadRight[ va, n ], PadRight[ vb, n ] ] =!= -1
    ];

skillsVersionNotNewerQ[ _, _ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Skill Sources*)
(* A copy of the real skill sources of the checkout (AgentSkills/ and the script template) in a fresh directory *)
skillsSourceCopy[ ] := Module[ { dir },
    dir = skillsBuildDirectory[ ];
    CopyDirectory[ FileNameJoin @ { $skillsCheckoutDirectory, "AgentSkills" }, FileNameJoin @ { dir, "AgentSkills" } ];
    CreateDirectory @ FileNameJoin @ { dir, "Scripts", "Resources" };
    CopyFile[ $skillsTemplateFile, FileNameJoin @ { dir, "Scripts", "Resources", "SkillScriptTemplate.wls" } ];
    dir
];

(* Rewrites the manifest of a source directory with f applied to its association *)
editSkillsManifest[ dir_String, f_ ] := With[ { file = FileNameJoin @ { dir, "AgentSkills", "Manifest.wl" } },
    Put[ f @ Get @ file, file ];
    dir
];

(* A tool definition used to build synthetic skills without depending on the real MCP tools *)
$syntheticTools = <|
    "EchoTool" -> <|
        "Name"        -> "EchoTool",
        "Description" -> "Echoes its input.",
        "Parameters"  -> <|
            "text"  -> <| "Help" -> "The text to echo", "Required" -> True |>,
            "count" -> <| "Help" -> "How many times | to echo", "Required" -> False |>
        |>
    |>
|>;

(* The source SKILL.md of the synthetic skill: the body contains lines that look like YAML and must not change *)
$syntheticSkillMarkdown = "---\nname: test-skill\ndescription: A test skill\nmetadata:\n  author: Test\n---\n\n\
# Test Skill\n\nmetadata:\n  version: body\n";

(* The default files of a synthetic source directory with one skill (test-skill) *)
$syntheticSourceFiles := <|
    "AgentSkills/Manifest.wl" ->
        "<| \"test-skill\" -> <| \"Scripts\" -> { \"EchoTool\" }, \"References\" -> { \"Guide\" } |> |>\n",
    "AgentSkills/References/Guide.md"        -> "# Guide\r\n\r\nSome guidance.\r\n",
    "AgentSkills/Skills/test-skill/SKILL.md" -> $syntheticSkillMarkdown,
    "Scripts/Resources/SkillScriptTemplate.wls" -> readSkillsBuildFile @ $skillsTemplateFile
|>;

(* A synthetic source directory: the default files with the given changes (relative path -> content) *)
syntheticSkillSource[ ] := syntheticSkillSource[ <| |> ];
syntheticSkillSource[ changes_Association ] := Module[ { dir },
    dir = skillsBuildDirectory[ ];
    KeyValueMap[
        writeSkillsBuildFile[ FileNameJoin @ Prepend[ StringSplit[ #1, "/" ], dir ], #2 ] &,
        Join[ $syntheticSourceFiles, changes ]
    ];
    dir
];

(* Builds a synthetic source into a new directory with $syntheticTools, giving { result, output directory } *)
buildSyntheticSkills[ changes_Association, opts___ ] := Module[ { out },
    out = skillsBuildNewPath[ ];
    {
        Wolfram`AgentSkillsBuilder`buildAgentSkills[
            syntheticSkillSource @ changes,
            out,
            "1.2.3",
            "Tools" -> $syntheticTools,
            opts
        ],
        out
    }
];

(* A minimal built skill tree: skill name -> SKILL.md content *)
skillsTree[ skills_Association ] := Module[ { dir },
    dir = skillsBuildDirectory[ ];
    KeyValueMap[ writeSkillsBuildFile[ FileNameJoin @ { dir, #1, "SKILL.md" }, #2 ] &, skills ];
    dir
];

versionedSkillMarkdown[ name_String, version_String ] :=
    "---\nname: " <> name <> "\ndescription: d\nmetadata:\n  version: " <> version <> "\n---\n\nBody\n";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Committed Skills*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Staleness*)
(* Rebuilds the skills from their sources (AgentSkills/, Scripts/Resources/SkillScriptTemplate.wls, and the tool
   definitions in Kernel/Tools/) with the version of the committed skills and compares the result with the committed
   Assets/AgentSkills. If this test fails, the actual output lists the files that are out of date. The fix is to run
       wolframscript -f Scripts/BuildAgentSkills.wls
   and commit the updated Assets/AgentSkills (and .claude-plugin/marketplace.json). *)
VerificationTest[
    Module[ { dir, version, result, differences },
        dir = CreateDirectory[ ];
        WithCleanup[
            version = Wolfram`AgentSkillsBuilder`agentSkillsVersion @ $skillsCommittedDirectory;
            result  = If[ StringQ @ version,
                          Wolfram`AgentSkillsBuilder`buildAgentSkills[ $skillsCheckoutDirectory, dir, version ],
                          version
                      ];
            differences = If[ MatchQ[ result, _Success ],
                              Wolfram`AgentSkillsBuilder`agentSkillsDifferences[ dir, $skillsCommittedDirectory ],
                              result
                          ];
            If[ differences === $emptySkillsDifferences,
                differences,
                Failure[ "StaleAgentSkills", <|
                    "MessageTemplate" ->
                        "Assets/AgentSkills does not match a fresh build of its sources. \
Run: wolframscript -f Scripts/BuildAgentSkills.wls",
                    "Differences"     -> differences
                |> ]
            ],
            DeleteDirectory[ dir, DeleteContents -> True ]
        ]
    ],
    <| "Missing" -> { }, "Extra" -> { }, "Different" -> { } |>,
    SameTest -> SameQ,
    TestID   -> "CommittedSkills-UpToDate@@Tests/AgentSkillsBuild.wlt:238,1-266,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Version*)
(* The committed skills share one dotted version. It is the paclet version at the time of the last skill build, so it
   lags behind the paclet version (CI increments the paclet version after every release) and is not compared with it
   for equality. *)
VerificationTest[
    Wolfram`AgentSkillsBuilder`agentSkillsVersion @ $skillsCommittedDirectory,
    _String? (StringMatchQ[ DigitCharacter.. ~~ ("." ~~ DigitCharacter..).. ]),
    SameTest -> MatchQ,
    TestID   -> "CommittedSkills-Version@@Tests/AgentSkillsBuild.wlt:274,1-279,2"
]

VerificationTest[
    AssociationMap[
        Length @ versionLines @ readSkillsBuildText @ FileNameJoin @ { $skillsCommittedDirectory, #, "SKILL.md" } &,
        $expectedSkillNames
    ],
    AssociationMap[ 1 &, $expectedSkillNames ],
    SameTest -> SameQ,
    TestID   -> "CommittedSkills-OneVersionLine@@Tests/AgentSkillsBuild.wlt:281,1-289,2"
]

(* The build stamps the current paclet version, and paclet versions only increase *)
VerificationTest[
    With[
        {
            version = Wolfram`AgentSkillsBuilder`agentSkillsVersion @ $skillsCommittedDirectory,
            paclet  = PacletObject[ "Wolfram/AgentTools" ][ "Version" ]
        },
        { version, paclet, skillsVersionNotNewerQ[ version, paclet ] }
    ],
    { _String, _String, True },
    SameTest -> MatchQ,
    TestID   -> "CommittedSkills-VersionNotNewerThanPaclet@@Tests/AgentSkillsBuild.wlt:292,1-303,2"
]

(* The build adds only the version line to the source SKILL.md *)
VerificationTest[
    With[ { version = Wolfram`AgentSkillsBuilder`agentSkillsVersion @ $skillsCommittedDirectory },
        AssociationMap[
            StringReplace[
                readSkillsBuildText @ FileNameJoin @ { $skillsCommittedDirectory, #, "SKILL.md" },
                "\n  version: " <> version <> "\n" -> "\n"
            ] === readSkillsBuildText @ FileNameJoin @ { $skillsSourceDirectory, #, "SKILL.md" } &,
            $expectedSkillNames
        ]
    ],
    AssociationMap[ True &, $expectedSkillNames ],
    SameTest -> SameQ,
    TestID   -> "CommittedSkills-OnlyVersionAdded@@Tests/AgentSkillsBuild.wlt:306,1-319,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Parsing*)
(* Each built skill is a valid skill for LLMSkill and for the parser used by deployments, with the shared version *)
VerificationTest[
    With[ { version = Wolfram`AgentSkillsBuilder`agentSkillsVersion @ $skillsCommittedDirectory },
        AssociationMap[
            Function[ name,
                Module[ { dir, skill, parsed },
                    dir    = FileNameJoin @ { $skillsCommittedDirectory, name };
                    skill  = LLMSkill @ File @ dir;
                    parsed = Wolfram`AgentTools`Common`parseSkillMarkdown @ dir;
                    {
                        skill[ "Name" ],
                        StringQ @ skill[ "Description" ] && StringLength @ StringTrim @ skill[ "Description" ] > 0,
                        skill[ "Metadata" ][ "version" ] === version,
                        parsed[ "Name" ],
                        parsed[ "Description" ] === skill[ "Description" ]
                    }
                ]
            ],
            skillsBuildEntries @ $skillsCommittedDirectory
        ]
    ],
    AssociationMap[ { #, True, True, #, True } &, $expectedSkillNames ],
    SameTest -> SameQ,
    TestID   -> "CommittedSkills-Parse@@Tests/AgentSkillsBuild.wlt:325,1-348,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Packaging*)
VerificationTest[
    DirectoryQ @ $skillsAssetLocation,
    True,
    SameTest -> SameQ,
    TestID   -> "PacletAsset-Directory@@Tests/AgentSkillsBuild.wlt:353,1-358,2"
]

VerificationTest[
    skillsBuildEntries @ $skillsAssetLocation,
    $expectedSkillNames,
    SameTest -> SameQ,
    TestID   -> "PacletAsset-SkillNames@@Tests/AgentSkillsBuild.wlt:360,1-365,2"
]

(* Missing required files for each skill *)
VerificationTest[
    AssociationMap[
        Complement[
            Join[ $requiredSkillFiles, "scripts/" <> # <> ".wls" & /@ $skillsManifest[ #, "Scripts" ] ],
            skillsBuildFiles @ FileNameJoin @ { $skillsAssetLocation, # }
        ] &,
        $expectedSkillNames
    ],
    AssociationMap[ { } &, $expectedSkillNames ],
    SameTest -> SameQ,
    TestID   -> "PacletAsset-RequiredFiles@@Tests/AgentSkillsBuild.wlt:368,1-379,2"
]

(* Each skill contains exactly the files that its manifest entry defines *)
VerificationTest[
    AssociationMap[ skillsBuildFiles @ FileNameJoin @ { $skillsAssetLocation, # } &, $expectedSkillNames ],
    AssociationMap[
        Sort @ Join[
            { "SKILL.md", "references/Scripts.md" },
            "references/" <> # <> ".md" & /@ $skillsManifest[ #, "References" ],
            "scripts/" <> # <> ".wls" & /@ $skillsManifest[ #, "Scripts" ]
        ] &,
        $expectedSkillNames
    ],
    SameTest -> SameQ,
    TestID   -> "PacletAsset-MatchesManifest@@Tests/AgentSkillsBuild.wlt:382,1-394,2"
]

(* The built paclet ships the committed skills unchanged *)
ifBuiltPaclet @ VerificationTest[
    Wolfram`AgentSkillsBuilder`agentSkillsDifferences[ $skillsCommittedDirectory, $skillsAssetLocation ],
    <| "Missing" -> { }, "Extra" -> { }, "Different" -> { } |>,
    SameTest -> SameQ,
    TestID   -> "PacletAsset-MatchesCheckout@@Tests/AgentSkillsBuild.wlt:397,17-402,2"
]

(* Without a build, the asset is the committed directory of the checkout *)
ifSourcePaclet @ VerificationTest[
    sameDirectoryQ[ $skillsAssetLocation, $skillsCommittedDirectory ],
    True,
    SameTest -> SameQ,
    TestID   -> "PacletAsset-SourceLocation@@Tests/AgentSkillsBuild.wlt:405,18-410,2"
]

VerificationTest[
    sameDirectoryQ[
        PacletObject[ File @ $skillsCheckoutDirectory ][ "AssetLocation", "AgentSkills" ],
        $skillsCommittedDirectory
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "PacletInfo-DeclaresAsset@@Tests/AgentSkillsBuild.wlt:412,1-420,2"
]

VerificationTest[
    Cases[
        ToExpression[ readSkillsBuildFile @ $skillsPacletInfoFile, InputForm, HoldComplete ],
        { "Asset", ___, "Assets" -> assets_List, ___ } :> MemberQ[ assets, { "AgentSkills", "Assets/AgentSkills" } ],
        Infinity
    ],
    { True },
    SameTest -> SameQ,
    TestID   -> "PacletInfo-AssetEntry@@Tests/AgentSkillsBuild.wlt:422,1-431,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Source Hygiene*)
(* The source skill directories are hand-authored: scripts, references, and the version are added by the build *)
VerificationTest[
    AssociationMap[ skillsBuildFiles @ FileNameJoin @ { $skillsSourceDirectory, # } &, $expectedSkillNames ],
    AssociationMap[ { "SKILL.md" } &, $expectedSkillNames ],
    SameTest -> SameQ,
    TestID   -> "SourceSkills-OnlySkillMarkdown@@Tests/AgentSkillsBuild.wlt:437,1-442,2"
]

VerificationTest[
    AssociationMap[
        Select[
            StringSplit[ readSkillsBuildText @ FileNameJoin @ { $skillsSourceDirectory, #, "SKILL.md" }, "\n", All ],
            StringMatchQ[ RegularExpression[ "\\s*version\\s*:.*" ] ]
        ] &,
        $expectedSkillNames
    ],
    AssociationMap[ { } &, $expectedSkillNames ],
    SameTest -> SameQ,
    TestID   -> "SourceSkills-NoVersion@@Tests/AgentSkillsBuild.wlt:444,1-455,2"
]

VerificationTest[
    {
        Sort @ Keys @ $skillsManifest,
        skillsBuildEntries @ $skillsSourceDirectory,
        skillsBuildEntries @ $skillsCommittedDirectory,
        Sort @ Keys @ Wolfram`AgentTools`Common`$defaultAgentSkills
    },
    { $expectedSkillNames, $expectedSkillNames, $expectedSkillNames, $expectedSkillNames },
    SameTest -> SameQ,
    TestID   -> "SkillNames-Consistent@@Tests/AgentSkillsBuild.wlt:457,1-467,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Marketplace*)
$skillsMarketplace := Import[ $skillsMarketplaceFile, "RawJSON" ];

VerificationTest[
    Lookup[ $skillsMarketplace[ "plugins" ], "source" ],
    { "./Assets/AgentSkills".. },
    SameTest -> MatchQ,
    TestID   -> "Marketplace-Source@@Tests/AgentSkillsBuild.wlt:474,1-479,2"
]

(* Listed skills that are not built skill directories with a SKILL.md *)
VerificationTest[
    Select[
        Flatten @ Lookup[ $skillsMarketplace[ "plugins" ], "skills" ],
        ! (StringQ @ # &&
            StringMatchQ[ #, "./" ~~ Except[ "/" ].. ] &&
            FileType @ FileNameJoin @ { $skillsCommittedDirectory, StringDrop[ #, 2 ], "SKILL.md" } === File) &
    ],
    { },
    SameTest -> SameQ,
    TestID   -> "Marketplace-SkillsExist@@Tests/AgentSkillsBuild.wlt:482,1-492,2"
]

VerificationTest[
    Sort @ DeleteDuplicates[
        StringDelete[ StartOfString ~~ "./" ] /@ Flatten @ Lookup[ $skillsMarketplace[ "plugins" ], "skills" ]
    ],
    $expectedSkillNames,
    SameTest -> SameQ,
    TestID   -> "Marketplace-AllSkillsListed@@Tests/AgentSkillsBuild.wlt:494,1-501,2"
]

(* The plugins match the built-in bundles: WolframLanguage (and WolframPacletDevelopment) and WolframAlpha *)
VerificationTest[
    Association[ #[ "name" ] -> Sort @ #[ "skills" ] & /@ $skillsMarketplace[ "plugins" ] ],
    <|
        "wolfram-language-development" -> { "./wolfram-language", "./wolfram-notebooks", "./wolfram-paclets" },
        "wolfram-alpha"                -> { "./wolfram-alpha" }
    |>,
    SameTest -> SameQ,
    TestID   -> "Marketplace-PluginSkills@@Tests/AgentSkillsBuild.wlt:504,1-512,2"
]

(* Scripts/BuildAgentSkills.wls writes the version of the built skills into the marketplace *)
VerificationTest[
    $skillsMarketplace[ "metadata", "version" ] === Wolfram`AgentSkillsBuilder`agentSkillsVersion @ $skillsCommittedDirectory,
    True,
    SameTest -> SameQ,
    TestID   -> "Marketplace-VersionMatchesSkills@@Tests/AgentSkillsBuild.wlt:515,1-520,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SetUpWolframMCPServer Reference*)
$setUpReference := readSkillsBuildText @ FileNameJoin @ { $skillsReferencesDirectory, "SetUpWolframMCPServer.md" };

VerificationTest[
    AssociationMap[
        StringContainsQ[ $setUpReference, # ] &,
        {
            "https://agenttools.wolfram.com/mcp",
            "https://www.wolfram.com/artificial-intelligence/mcp/cloud/wolfram-mcp-cloud",
            "https://support.wolfram.com/75237",
            "DeployAgentTools"
        }
    ],
    <|
        "https://agenttools.wolfram.com/mcp"                                          -> True,
        "https://www.wolfram.com/artificial-intelligence/mcp/cloud/wolfram-mcp-cloud" -> True,
        "https://support.wolfram.com/75237"                                           -> True,
        "DeployAgentTools"                                                            -> True
    |>,
    SameTest -> SameQ,
    TestID   -> "SetUpReference-RequiredContent@@Tests/AgentSkillsBuild.wlt:527,1-545,2"
]

(* The obsolete remote service (services.wolfram.com, which needed an API key passed as a bearer token) is gone *)
VerificationTest[
    AssociationMap[
        StringContainsQ[ $setUpReference, #, IgnoreCase -> True ] &,
        { "services.wolfram.com", "mcp-service", "Bearer", "73463" }
    ],
    <| "services.wolfram.com" -> False, "mcp-service" -> False, "Bearer" -> False, "73463" -> False |>,
    SameTest -> SameQ,
    TestID   -> "SetUpReference-NoObsoleteService@@Tests/AgentSkillsBuild.wlt:548,1-556,2"
]

VerificationTest[
    AssociationMap[
        readSkillsBuildText @ FileNameJoin @ { $skillsCommittedDirectory, #, "references", "SetUpWolframMCPServer.md" } ===
            $setUpReference &,
        $expectedSkillNames
    ],
    AssociationMap[ True &, $expectedSkillNames ],
    SameTest -> SameQ,
    TestID   -> "SetUpReference-SameInEverySkill@@Tests/AgentSkillsBuild.wlt:558,1-567,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*stampSkillVersion*)
VerificationTest[
    Wolfram`AgentSkillsBuilder`stampSkillVersion[
        "---\nname: x\ndescription: d\nmetadata:\n  author: A\n  license: MIT\ncompatibility: c\n---\n\n# Body\n",
        "2.0.1"
    ],
    "---\nname: x\ndescription: d\nmetadata:\n  author: A\n  license: MIT\n  version: 2.0.1\ncompatibility: c\n---\n\n# Body\n",
    SameTest -> SameQ,
    TestID   -> "StampSkillVersion-AppendsLast@@Tests/AgentSkillsBuild.wlt:572,1-580,2"
]

VerificationTest[
    Wolfram`AgentSkillsBuilder`stampSkillVersion[
        "---\nname: x\nmetadata:\n  version: 1.0.0\n  author: A\n---\nBody\n",
        "2.0.1"
    ],
    "---\nname: x\nmetadata:\n  author: A\n  version: 2.0.1\n---\nBody\n",
    SameTest -> SameQ,
    TestID   -> "StampSkillVersion-ReplacesExisting@@Tests/AgentSkillsBuild.wlt:582,1-590,2"
]

(* Every version entry of the block is removed, including quoted keys and continuation lines *)
VerificationTest[
    Wolfram`AgentSkillsBuilder`stampSkillVersion[
        "---\nname: x\nmetadata:\n  version:\n    1.0.0\n  author: A\n  \"version\": 0.9\n---\nBody\n",
        "2.0.1"
    ],
    "---\nname: x\nmetadata:\n  author: A\n  version: 2.0.1\n---\nBody\n",
    SameTest -> SameQ,
    TestID   -> "StampSkillVersion-RemovesAllVersionEntries@@Tests/AgentSkillsBuild.wlt:593,1-601,2"
]

VerificationTest[
    Wolfram`AgentSkillsBuilder`stampSkillVersion[ "---\nname: x\ndescription: d\n---\n\nBody\n", "2.0.1" ],
    "---\nname: x\ndescription: d\nmetadata:\n  version: 2.0.1\n---\n\nBody\n",
    SameTest -> SameQ,
    TestID   -> "StampSkillVersion-CreatesMetadata@@Tests/AgentSkillsBuild.wlt:603,1-608,2"
]

VerificationTest[
    Wolfram`AgentSkillsBuilder`stampSkillVersion[ "---\nname: x\nmetadata:\n    author: A\n---\nBody", "2.0.1" ],
    "---\nname: x\nmetadata:\n    author: A\n    version: 2.0.1\n---\nBody",
    SameTest -> SameQ,
    TestID   -> "StampSkillVersion-KeepsIndentation@@Tests/AgentSkillsBuild.wlt:610,1-615,2"
]

(* Lines in the body that look like frontmatter, and CRLF line endings in the body, are never changed *)
VerificationTest[
    {
        Wolfram`AgentSkillsBuilder`stampSkillVersion[
            "---\nname: x\nmetadata:\n  author: A\n---\n\nmetadata:\n  version: x\n---\n  version: y\n",
            "2.0.1"
        ],
        Wolfram`AgentSkillsBuilder`stampSkillVersion[ "---\nname: x\n---\nLine 1\r\n  version: x\r\n", "2.0.1" ]
    },
    {
        "---\nname: x\nmetadata:\n  author: A\n  version: 2.0.1\n---\n\nmetadata:\n  version: x\n---\n  version: y\n",
        "---\nname: x\nmetadata:\n  version: 2.0.1\n---\nLine 1\r\n  version: x\r\n"
    },
    SameTest -> SameQ,
    TestID   -> "StampSkillVersion-BodyUnchanged@@Tests/AgentSkillsBuild.wlt:618,1-632,2"
]

(* Versions that YAML would read as numbers are quoted *)
VerificationTest[
    Wolfram`AgentSkillsBuilder`stampSkillVersion[ "---\nname: x\n---\n", # ] & /@ { "3.1", "2", "2.0.1", "1.0-beta" },
    {
        "---\nname: x\nmetadata:\n  version: \"3.1\"\n---\n",
        "---\nname: x\nmetadata:\n  version: \"2\"\n---\n",
        "---\nname: x\nmetadata:\n  version: 2.0.1\n---\n",
        "---\nname: x\nmetadata:\n  version: 1.0-beta\n---\n"
    },
    SameTest -> SameQ,
    TestID   -> "StampSkillVersion-QuotesNumericVersions@@Tests/AgentSkillsBuild.wlt:635,1-645,2"
]

VerificationTest[
    With[ { md = "---\nname: x\nmetadata:\n  version: 1.0.0\n  author: A\n---\nBody\n" },
        With[ { once = Wolfram`AgentSkillsBuilder`stampSkillVersion[ md, "2.0.1" ] },
            Wolfram`AgentSkillsBuilder`stampSkillVersion[ once, "2.0.1" ] === once
        ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "StampSkillVersion-Idempotent@@Tests/AgentSkillsBuild.wlt:647,1-656,2"
]

VerificationTest[
    Wolfram`AgentSkillsBuilder`stampSkillVersion[ #, "2.0.1" ] & /@ {
        "# Title\n\n  version: x\n",
        "---\nname: x\n",
        "\n---\nname: x\n---\nBody\n"
    },
    { Failure[ "MissingFrontmatter", _ ], Failure[ "MissingFrontmatter", _ ], Failure[ "MissingFrontmatter", _ ] },
    SameTest -> MatchQ,
    TestID   -> "StampSkillVersion-NoFrontmatter@@Tests/AgentSkillsBuild.wlt:658,1-667,2"
]

VerificationTest[
    {
        Wolfram`AgentSkillsBuilder`stampSkillVersion[ "---\nname: x\n---\n", "" ],
        Wolfram`AgentSkillsBuilder`stampSkillVersion[ "---\nname: x\n---\n", "1 0" ],
        Wolfram`AgentSkillsBuilder`stampSkillVersion[ "---\nname: x\n---\n", 1 ],
        Wolfram`AgentSkillsBuilder`stampSkillVersion[ None, "1.0" ]
    },
    {
        Failure[ "InvalidVersion", _ ],
        Failure[ "InvalidVersion", _ ],
        Failure[ "InvalidVersion", _ ],
        Failure[ "InvalidArguments", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "StampSkillVersion-InvalidArguments@@Tests/AgentSkillsBuild.wlt:669,1-684,2"
]

VerificationTest[
    Wolfram`AgentSkillsBuilder`stampSkillVersion[ "---\nname: x\nmetadata: { author: A }\n---\nBody\n", "2.0.1" ],
    Failure[ "UnsupportedMetadata", _ ],
    SameTest -> MatchQ,
    TestID   -> "StampSkillVersion-FlowMetadata@@Tests/AgentSkillsBuild.wlt:686,1-691,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*buildAgentSkills*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Output Directory*)
(* The build returns a Failure (it never calls Exit) and writes nothing *)
VerificationTest[
    Module[ { out, result },
        out = skillsBuildDirectory[ ];
        writeSkillsBuildFile[ FileNameJoin @ { out, "keep.txt" }, "keep\n" ];
        result = Wolfram`AgentSkillsBuilder`buildAgentSkills[ $skillsCheckoutDirectory, out, "1.0.0" ];
        { result, skillsBuildFiles @ out, readSkillsBuildFile @ FileNameJoin @ { out, "keep.txt" } }
    ],
    { Failure[ "OutputDirectoryNotEmpty", _ ], { "keep.txt" }, "keep\n" },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-OutputDirectoryNotEmpty@@Tests/AgentSkillsBuild.wlt:701,1-711,2"
]

VerificationTest[
    Module[ { out },
        out = writeSkillsBuildFile[ FileNameJoin @ { skillsBuildDirectory[ ], "out" }, "file\n" ];
        { Wolfram`AgentSkillsBuilder`buildAgentSkills[ $skillsCheckoutDirectory, out, "1.0.0" ], readSkillsBuildFile @ out }
    ],
    { Failure[ "InvalidOutputDirectory", _ ], "file\n" },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-OutputPathIsFile@@Tests/AgentSkillsBuild.wlt:713,1-721,2"
]

(* An empty existing directory is a valid output directory *)
VerificationTest[
    Module[ { out },
        out = skillsBuildDirectory[ ];
        {
            Wolfram`AgentSkillsBuilder`buildAgentSkills[ $skillsCheckoutDirectory, out, "1.0.0" ],
            Wolfram`AgentSkillsBuilder`agentSkillsVersion @ out
        }
    ],
    { Success[ "AgentSkillsBuilt", _ ], "1.0.0" },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-EmptyOutputDirectory@@Tests/AgentSkillsBuild.wlt:724,1-735,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Arguments*)
VerificationTest[
    Module[ { out },
        out = skillsBuildNewPath[ ];
        {
            Wolfram`AgentSkillsBuilder`buildAgentSkills[ $skillsCheckoutDirectory, out, "not a version" ],
            Wolfram`AgentSkillsBuilder`buildAgentSkills[ $skillsCheckoutDirectory, out, 2 ],
            FileExistsQ @ out
        }
    ],
    { Failure[ "InvalidVersion", _ ], Failure[ "InvalidVersion", _ ], False },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-InvalidVersion@@Tests/AgentSkillsBuild.wlt:740,1-752,2"
]

VerificationTest[
    Module[ { out },
        out = skillsBuildNewPath[ ];
        {
            Wolfram`AgentSkillsBuilder`buildAgentSkills[ FileNameJoin @ { skillsBuildDirectory[ ], "missing" }, out, "1.0.0" ],
            FileExistsQ @ out
        }
    ],
    { Failure[ "InvalidSourceDirectory", _ ], False },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-InvalidSourceDirectory@@Tests/AgentSkillsBuild.wlt:754,1-765,2"
]

VerificationTest[
    Module[ { out },
        out = skillsBuildNewPath[ ];
        {
            Wolfram`AgentSkillsBuilder`buildAgentSkills[ $skillsCheckoutDirectory, out, "1.0.0", "Tools" -> None ],
            FileExistsQ @ out
        }
    ],
    { Failure[ "InvalidTools", _ ], False },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-InvalidTools@@Tests/AgentSkillsBuild.wlt:767,1-778,2"
]

VerificationTest[
    Wolfram`AgentSkillsBuilder`buildAgentSkills[ $skillsCheckoutDirectory ],
    Failure[ "InvalidArguments", _ ],
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-InvalidArgumentCount@@Tests/AgentSkillsBuild.wlt:780,1-785,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Copies of the Real Sources*)
(* A copy of the sources builds (with File[...] arguments) every skill of the manifest with the given version. The
   copy builds the same files as the checkout, so the build output differs from the committed skills only in the
   version lines of the SKILL.md files. *)
VerificationTest[
    Module[ { src, out, result, differences },
        src    = skillsSourceCopy[ ];
        out    = skillsBuildNewPath[ ];
        result = Wolfram`AgentSkillsBuilder`buildAgentSkills[ File @ src, File @ out, "0.0.1" ];
        differences = Wolfram`AgentSkillsBuilder`agentSkillsDifferences[ out, $skillsCommittedDirectory ];
        {
            result,
            result[ "Files" ] === skillsBuildFiles @ out,
            result[ "Skills" ] === Keys @ $skillsManifest,
            Wolfram`AgentSkillsBuilder`agentSkillsVersion @ out,
            KeyTake[ differences, { "Missing", "Extra" } ],
            SubsetQ[ differences[ "Different" ], # <> "/SKILL.md" & /@ $expectedSkillNames ]
        }
    ],
    {
        Success[ "AgentSkillsBuilt", KeyValuePattern @ { "Directory" -> _String, "Version" -> "0.0.1" } ],
        True,
        True,
        "0.0.1",
        <| "Missing" -> { }, "Extra" -> { } |>,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-SourceCopy@@Tests/AgentSkillsBuild.wlt:793,1-818,2"
]

(* A script name in the manifest that is not a tool *)
VerificationTest[
    Module[ { src, out },
        src = editSkillsManifest[
            skillsSourceCopy[ ],
            MapAt[ Append[ "NotARealTool" ], { Key[ "wolfram-alpha" ], Key[ "Scripts" ] } ]
        ];
        out = skillsBuildNewPath[ ];
        { Wolfram`AgentSkillsBuilder`buildAgentSkills[ src, out, "1.0.0" ], FileExistsQ @ out }
    ],
    { Failure[ "ToolNotFound", KeyValuePattern[ "MessageParameters" -> { "NotARealTool" } ] ], False },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-SourceCopy-UnknownTool@@Tests/AgentSkillsBuild.wlt:821,1-833,2"
]

(* A source skill directory with a file other than SKILL.md (e.g. a leftover generated script) *)
VerificationTest[
    Module[ { src, out },
        src = skillsSourceCopy[ ];
        writeSkillsBuildFile[
            FileNameJoin @ { src, "AgentSkills", "Skills", "wolfram-language", "scripts", "Stale.wls" },
            "Print[ 1 ]\n"
        ];
        out = skillsBuildNewPath[ ];
        { Wolfram`AgentSkillsBuilder`buildAgentSkills[ src, out, "1.0.0" ], FileExistsQ @ out }
    ],
    {
        Failure[
            "UnexpectedSkillFiles",
            KeyValuePattern[ "MessageParameters" -> { _, "wolfram-language", { ___, "scripts/Stale.wls", ___ } } ]
        ],
        False
    },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-SourceCopy-ExtraSkillFile@@Tests/AgentSkillsBuild.wlt:836,1-855,2"
]

(* Operating system metadata files (e.g. a .DS_Store created by Finder) are ignored in the sources *)
VerificationTest[
    Module[ { src, out },
        src = skillsSourceCopy[ ];
        writeSkillsBuildFile[ FileNameJoin @ { src, "AgentSkills", "Skills", ".DS_Store" }, "junk" ];
        writeSkillsBuildFile[ FileNameJoin @ { src, "AgentSkills", "Skills", "wolfram-language", "Thumbs.db" }, "junk" ];
        out = skillsBuildNewPath[ ];
        { Wolfram`AgentSkillsBuilder`buildAgentSkills[ src, out, "1.0.0" ], skillsBuildEntries @ out }
    ],
    { _Success, Sort @ $expectedSkillNames },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-SourceCopy-IgnoresJunkFiles@@Tests/AgentSkillsBuild.wlt:858,1-869,2"
]

(* A source skill directory that is not in the manifest *)
VerificationTest[
    Module[ { src, out },
        src = skillsSourceCopy[ ];
        writeSkillsBuildFile[
            FileNameJoin @ { src, "AgentSkills", "Skills", "unlisted-skill", "SKILL.md" },
            "---\nname: unlisted-skill\ndescription: d\n---\nBody\n"
        ];
        out = skillsBuildNewPath[ ];
        { Wolfram`AgentSkillsBuilder`buildAgentSkills[ src, out, "1.0.0" ], FileExistsQ @ out }
    ],
    { Failure[ "UnlistedSkillDirectory", KeyValuePattern[ "MessageParameters" -> { _, { "unlisted-skill" } } ] ], False },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-SourceCopy-UnlistedSkillDirectory@@Tests/AgentSkillsBuild.wlt:872,1-885,2"
]

(* A skill in the manifest without a source directory *)
VerificationTest[
    Module[ { src, out },
        src = skillsSourceCopy[ ];
        DeleteDirectory[ FileNameJoin @ { src, "AgentSkills", "Skills", "wolfram-paclets" }, DeleteContents -> True ];
        out = skillsBuildNewPath[ ];
        { Wolfram`AgentSkillsBuilder`buildAgentSkills[ src, out, "1.0.0" ], FileExistsQ @ out }
    ],
    { Failure[ "MissingSkillDirectory", _ ], False },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-SourceCopy-MissingSkillDirectory@@Tests/AgentSkillsBuild.wlt:888,1-898,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Synthetic Sources*)
(* A synthetic skill built with a custom "Tools" option: the SKILL.md is stamped (its body is unchanged), the
   reference is copied with LF line endings, and the script and its reference are generated from the tool *)
VerificationTest[
    Module[ { result, out },
        { result, out } = buildSyntheticSkills[ <| |> ];
        {
            result,
            skillsBuildFiles @ out,
            readSkillsBuildFile @ FileNameJoin @ { out, "test-skill", "SKILL.md" },
            readSkillsBuildFile @ FileNameJoin @ { out, "test-skill", "references", "Guide.md" }
        }
    ],
    {
        Success[
            "AgentSkillsBuilt",
            KeyValuePattern @ {
                "Version" -> "1.2.3",
                "Skills"  -> { "test-skill" },
                "Files"   -> {
                    "test-skill/references/Guide.md",
                    "test-skill/references/Scripts.md",
                    "test-skill/scripts/EchoTool.wls",
                    "test-skill/SKILL.md"
                }
            }
        ],
        {
            "test-skill/references/Guide.md",
            "test-skill/references/Scripts.md",
            "test-skill/scripts/EchoTool.wls",
            "test-skill/SKILL.md"
        },
        "---\nname: test-skill\ndescription: A test skill\nmetadata:\n  author: Test\n  version: 1.2.3\n---\n\n\
# Test Skill\n\nmetadata:\n  version: body\n",
        "# Guide\n\nSome guidance.\n"
    },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-Synthetic@@Tests/AgentSkillsBuild.wlt:905,1-941,2"
]

VerificationTest[
    Module[ { result, out, script, scriptsMd },
        { result, out } = buildSyntheticSkills[ <| |> ];
        script    = readSkillsBuildFile @ FileNameJoin @ { out, "test-skill", "scripts", "EchoTool.wls" };
        scriptsMd = readSkillsBuildFile @ FileNameJoin @ { out, "test-skill", "references", "Scripts.md" };
        {
            StringContainsQ[ script, "$usage = \"wolframscript -f EchoTool.wls <text> [--count value]\";" ],
            StringContainsQ[ script, "Echoes its input." ],
            StringFreeQ[ script, "(*<<" ],
            StringContainsQ[ scriptsMd, "## EchoTool.wls" ],
            StringContainsQ[ scriptsMd, "wolframscript -f scripts/EchoTool.wls <text> [--count value]" ],
            StringContainsQ[ scriptsMd, "| `text` | Yes | The text to echo |" ],
            StringContainsQ[ scriptsMd, "| `--count` | No | How many times \\| to echo |" ]
        }
    ],
    { True, True, True, True, True, True, True },
    SameTest -> SameQ,
    TestID   -> "BuildAgentSkills-Synthetic-GeneratedScripts@@Tests/AgentSkillsBuild.wlt:943,1-961,2"
]

VerificationTest[
    Module[ { log, result },
        { result, log } = Reap @ First @ buildSyntheticSkills[ <| |>, "LogFunction" -> Sow ];
        { result, log }
    ],
    { Success[ "AgentSkillsBuilt", _ ], { { __String } } },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-Synthetic-LogFunction@@Tests/AgentSkillsBuild.wlt:963,1-971,2"
]

(* The source SKILL.md may use CRLF line endings and a byte order mark: the built SKILL.md uses neither *)
VerificationTest[
    Module[ { result, out },
        { result, out } = buildSyntheticSkills @ <|
            "AgentSkills/Skills/test-skill/SKILL.md" ->
                "\:feff" <> StringReplace[ $syntheticSkillMarkdown, "\n" -> "\r\n" ]
        |>;
        { result, readSkillsBuildFile @ FileNameJoin @ { out, "test-skill", "SKILL.md" } }
    ],
    {
        Success[ "AgentSkillsBuilt", _ ],
        "---\nname: test-skill\ndescription: A test skill\nmetadata:\n  author: Test\n  version: 1.2.3\n---\n\n\
# Test Skill\n\nmetadata:\n  version: body\n"
    },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-Synthetic-NormalizesLineEndings@@Tests/AgentSkillsBuild.wlt:974,1-989,2"
]

VerificationTest[
    Module[ { result, out },
        { result, out } = buildSyntheticSkills @ <|
            "AgentSkills/Skills/test-skill/SKILL.md" ->
                StringReplace[ $syntheticSkillMarkdown, "name: test-skill" -> "name: other-skill" ]
        |>;
        { result, FileExistsQ @ out }
    ],
    { Failure[ "SkillNameMismatch", _ ], False },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-Synthetic-NameMismatch@@Tests/AgentSkillsBuild.wlt:991,1-1002,2"
]

VerificationTest[
    Module[ { result, out },
        { result, out } = buildSyntheticSkills @ <|
            "AgentSkills/Skills/test-skill/SKILL.md" -> "# No frontmatter\n"
        |>;
        { result, FileExistsQ @ out }
    ],
    { Failure[ "MissingFrontmatter", _ ], False },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-Synthetic-NoFrontmatter@@Tests/AgentSkillsBuild.wlt:1004,1-1014,2"
]

VerificationTest[
    Module[ { result, out },
        { result, out } = buildSyntheticSkills @ <|
            "AgentSkills/Manifest.wl" ->
                "<| \"test-skill\" -> <| \"Scripts\" -> { \"EchoTool\" }, \"References\" -> { \"Guide\", \"Missing\" } |> |>\n"
        |>;
        { result, FileExistsQ @ out }
    ],
    { Failure[ "MissingReference", _ ], False },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-Synthetic-MissingReference@@Tests/AgentSkillsBuild.wlt:1016,1-1027,2"
]

(* "Scripts" is reserved for the generated script reference *)
VerificationTest[
    Module[ { result, out },
        { result, out } = buildSyntheticSkills @ <|
            "AgentSkills/Manifest.wl" ->
                "<| \"test-skill\" -> <| \"Scripts\" -> { \"EchoTool\" }, \"References\" -> { \"Scripts\" } |> |>\n",
            "AgentSkills/References/Scripts.md" -> "# Not generated\n"
        |>;
        { result, FileExistsQ @ out }
    ],
    { Failure[ "InvalidReferenceName", _ ], False },
    SameTest -> MatchQ,
    TestID   -> "BuildAgentSkills-Synthetic-ReservedReferenceName@@Tests/AgentSkillsBuild.wlt:1030,1-1042,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*agentSkillsDifferences*)
VerificationTest[
    Module[ { expected, actual },
        expected = skillsBuildDirectory[ ];
        actual   = skillsBuildDirectory[ ];
        writeSkillsBuildFile[ FileNameJoin @ { #, "skill", "SKILL.md" }, "same\n" ] & /@ { expected, actual };
        Wolfram`AgentSkillsBuilder`agentSkillsDifferences[ expected, File @ actual ]
    ],
    <| "Missing" -> { }, "Extra" -> { }, "Different" -> { } |>,
    SameTest -> SameQ,
    TestID   -> "AgentSkillsDifferences-Identical@@Tests/AgentSkillsBuild.wlt:1047,1-1057,2"
]

VerificationTest[
    Module[ { expected, actual },
        expected = skillsBuildDirectory[ ];
        actual   = skillsBuildDirectory[ ];
        writeSkillsBuildFile[ FileNameJoin @ { expected, "a", "SKILL.md" }, "one\n" ];
        writeSkillsBuildFile[ FileNameJoin @ { actual, "a", "SKILL.md" }, "two\n" ];
        writeSkillsBuildFile[ FileNameJoin @ { expected, "a", "scripts", "Run.wls" }, "Run[]\n" ];
        writeSkillsBuildFile[ FileNameJoin @ { actual, "b", "references", "Extra.md" }, "extra\n" ];
        writeSkillsBuildFile[ FileNameJoin @ { #, "a", "references", "Same.md" }, "same\n" ] & /@ { expected, actual };
        Wolfram`AgentSkillsBuilder`agentSkillsDifferences[ expected, actual ]
    ],
    <| "Missing" -> { "a/scripts/Run.wls" }, "Extra" -> { "b/references/Extra.md" }, "Different" -> { "a/SKILL.md" } |>,
    SameTest -> SameQ,
    TestID   -> "AgentSkillsDifferences-ChangedMissingExtra@@Tests/AgentSkillsBuild.wlt:1059,1-1073,2"
]

VerificationTest[
    Module[ { expected, actual },
        expected = skillsBuildDirectory[ ];
        actual   = skillsBuildDirectory[ ];
        writeSkillsBuildFile[ FileNameJoin @ { expected, "a", "SKILL.md" }, "line 1\nline 2\n" ];
        writeSkillsBuildFile[ FileNameJoin @ { actual, "a", "SKILL.md" }, "line 1\r\nline 2\r\n" ];
        writeSkillsBuildFile[ FileNameJoin @ { expected, "a", "Other.md" }, "line 1\nline 2\n" ];
        writeSkillsBuildFile[ FileNameJoin @ { actual, "a", "Other.md" }, "line 1\r\nline 2 changed\r\n" ];
        Wolfram`AgentSkillsBuilder`agentSkillsDifferences[ expected, actual ]
    ],
    <| "Missing" -> { }, "Extra" -> { }, "Different" -> { "a/Other.md" } |>,
    SameTest -> SameQ,
    TestID   -> "AgentSkillsDifferences-IgnoresCRLF@@Tests/AgentSkillsBuild.wlt:1075,1-1088,2"
]

VerificationTest[
    Module[ { expected, actual },
        expected = skillsBuildDirectory[ ];
        actual   = skillsBuildDirectory[ ];
        writeSkillsBuildFile[ FileNameJoin @ { #, "a", "SKILL.md" }, "same\n" ] & /@ { expected, actual };
        writeSkillsBuildFile[ FileNameJoin @ { actual, ".DS_Store" }, "junk" ];
        writeSkillsBuildFile[ FileNameJoin @ { actual, "a", "desktop.ini" }, "junk" ];
        writeSkillsBuildFile[ FileNameJoin @ { expected, "a", "Thumbs.db" }, "junk" ];
        Wolfram`AgentSkillsBuilder`agentSkillsDifferences[ expected, actual ]
    ],
    <| "Missing" -> { }, "Extra" -> { }, "Different" -> { } |>,
    SameTest -> SameQ,
    TestID   -> "AgentSkillsDifferences-IgnoresJunkFiles@@Tests/AgentSkillsBuild.wlt:1090,1-1103,2"
]

VerificationTest[
    Module[ { dir, file, missing },
        dir     = skillsBuildDirectory[ ];
        file    = writeSkillsBuildFile[ FileNameJoin @ { dir, "file.txt" }, "x\n" ];
        missing = FileNameJoin @ { dir, "missing" };
        {
            Wolfram`AgentSkillsBuilder`agentSkillsDifferences[ file, dir ],
            Wolfram`AgentSkillsBuilder`agentSkillsDifferences[ dir, file ],
            Wolfram`AgentSkillsBuilder`agentSkillsDifferences[ dir, missing ],
            Wolfram`AgentSkillsBuilder`agentSkillsDifferences[ dir ]
        }
    ],
    {
        Failure[ "InvalidDirectory", _ ],
        Failure[ "InvalidDirectory", _ ],
        Failure[ "InvalidDirectory", _ ],
        Failure[ "InvalidArguments", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "AgentSkillsDifferences-NotADirectory@@Tests/AgentSkillsBuild.wlt:1105,1-1125,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*agentSkillsVersion*)
VerificationTest[
    Wolfram`AgentSkillsBuilder`agentSkillsVersion @ File @ skillsTree @ <|
        "a" -> versionedSkillMarkdown[ "a", "1.2.3" ],
        "b" -> versionedSkillMarkdown[ "b", "1.2.3" ]
    |>,
    "1.2.3",
    SameTest -> SameQ,
    TestID   -> "AgentSkillsVersion-Shared@@Tests/AgentSkillsBuild.wlt:1130,1-1138,2"
]

VerificationTest[
    {
        Wolfram`AgentSkillsBuilder`agentSkillsVersion @ skillsTree @ <|
            "a" -> versionedSkillMarkdown[ "a", "1.2.3" ],
            "b" -> versionedSkillMarkdown[ "b", "1.2.4" ]
        |>,
        Wolfram`AgentSkillsBuilder`agentSkillsVersion @ skillsTree @ <|
            "a" -> versionedSkillMarkdown[ "a", "1.2.3" ],
            "b" -> "---\nname: b\ndescription: d\n---\nBody\n"
        |>,
        Wolfram`AgentSkillsBuilder`agentSkillsVersion @ skillsBuildDirectory[ ],
        Wolfram`AgentSkillsBuilder`agentSkillsVersion @ FileNameJoin @ { skillsBuildDirectory[ ], "missing" }
    },
    {
        Failure[ "InconsistentVersions", _ ],
        Failure[ "MissingVersion", _ ],
        Failure[ "MissingVersion", _ ],
        Failure[ "InvalidDirectory", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "AgentSkillsVersion-Failures@@Tests/AgentSkillsBuild.wlt:1140,1-1161,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    DeleteDirectory[ $skillsBuildTestBase, DeleteContents -> True ];
    DirectoryQ @ $skillsBuildTestBase,
    False,
    SameTest -> SameQ,
    TestID   -> "Cleanup@@Tests/AgentSkillsBuild.wlt:1166,1-1172,2"
]

(* :!CodeAnalysis::EndBlock:: *)
