#!/usr/bin/env wolframscript

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Usage*)
(*
    Builds the agent skills defined in AgentSkills/ into Assets/AgentSkills (the paclet's "AgentSkills" asset) using
    Scripts/Resources/AgentSkillsBuilder.wl.

    wolframscript -f Scripts/BuildAgentSkills.wls
        Rebuilds Assets/AgentSkills with the current paclet version and updates the version in
        .claude-plugin/marketplace.json.

    wolframscript -f Scripts/BuildAgentSkills.wls --check
        Builds into a temporary directory using the version found in the committed Assets/AgentSkills, compares the
        result with Assets/AgentSkills, and exits with code 1 if it is out of date. Nothing is modified.
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
If[ ! PacletObjectQ @ PacletObject[ "Wolfram/PacletCICD" ],
    PacletInstall[ "https://github.com/WolframResearch/PacletCICD/releases/download/v0.36.2/Wolfram__PacletCICD-0.36.2.paclet" ]
];
Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Arguments*)
arguments = Rest @ Replace[ $ScriptCommandLine, { } :> { "" } ];

If[ ! SubsetQ[ { "--check" }, arguments ],
    cicd`ConsoleError @ SequenceForm[
        "Unknown arguments: ",
        Complement[ arguments, { "--check" } ],
        ". Usage: wolframscript -f Scripts/BuildAgentSkills.wls [--check]"
    ];
    Exit[ 1 ]
];

checkMode = MemberQ[ arguments, "--check" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Paths*)
pacletDir       = cicd`ScriptConfirmBy[ FileNameDrop[ ExpandFileName @ $InputFileName, -2 ], DirectoryQ ];
skillsDir       = FileNameJoin @ { pacletDir, "Assets", "AgentSkills" };
marketplaceFile = cicd`ScriptConfirmBy[ FileNameJoin @ { pacletDir, ".claude-plugin", "marketplace.json" }, FileExistsQ ];
builderFile     = cicd`ScriptConfirmBy[ FileNameJoin @ { pacletDir, "Scripts", "Resources", "AgentSkillsBuilder.wl" }, FileExistsQ ];
stagingDir      = FileNameJoin @ { $TemporaryDirectory, "AgentSkillsBuild-" <> CreateUUID[ ] };

$marketplaceSource = "./Assets/AgentSkills";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Load Paclet*)
cicd`ScriptConfirmBy[ PacletDirectoryLoad @ pacletDir, MemberQ @ pacletDir ];

(* Make sure an installed copy of AgentTools cannot shadow the source being built: *)
cicd`ScriptConfirmAssert[
    StringQ @ FindFile[ "Wolfram`AgentTools`" ] &&
        StringStartsQ[ ExpandFileName @ FindFile[ "Wolfram`AgentTools`" ], pacletDir <> $PathnameSeparator ],
    TemplateApply[
        "AgentTools context points to \"`1`\" which is not contained in the expected paclet directory \"`2`\".",
        { FindFile[ "Wolfram`AgentTools`" ], pacletDir }
    ]
];

cicd`ScriptConfirmMatch[ Get[ "Wolfram`AgentTools`" ], Null ];
pacletVersion = cicd`ScriptConfirmBy[ PacletObject[ File @ pacletDir ][ "Version" ], StringQ ];
cicd`ScriptConfirmMatch[ Get @ builderFile, Null ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Exiting*)
(* The staging directory is removed before every exit after this point. *)
exitWith[ code_Integer ] := (
    If[ DirectoryQ @ stagingDir, DeleteDirectory[ stagingDir, DeleteContents -> True ] ];
    Exit[ code ]
);

abort[ message__ ] := (
    cicd`ConsoleError @ SequenceForm @ message;
    exitWith[ 1 ]
);

failureMessage[ failure_Failure ] := Replace[ failure[ "Message" ], Except[ _String ] :> ToString[ failure, InputForm ] ];
failureMessage[ other_ ] := ToString[ other, InputForm ];

confirmResult[ result_, context_String ] := If[ FailureQ @ result, abort[ context, ": ", failureMessage @ result ], result ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*buildSkills*)
buildSkills[ version_String ] := (
    cicd`ConsoleLog @ SequenceForm[ "Building agent skills (version ", version, ") in ", stagingDir ];
    confirmResult[
        Wolfram`AgentSkillsBuilder`buildAgentSkills[ pacletDir, stagingDir, version, "LogFunction" -> cicd`ConsoleLog ],
        "Failed to build agent skills"
    ]
);

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readMarketplace*)
readMarketplace[ ] := Replace[
    Quiet @ Import[ marketplaceFile, "RawJSON" ],
    Except[ KeyValuePattern[ "metadata" -> _Association ] ] :>
        abort[ "Failed to read ", marketplaceFile, " as a JSON object with a \"metadata\" object." ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*marketplaceProblems*)
(* Problems with the plugin definitions of the marketplace data, checked against the built skill tree in dir. *)
marketplaceProblems[ data_Association, dir_String ] := Flatten @ Replace[
    Lookup[ data, "plugins" ],
    {
        plugins: { __Association } :> Map[ pluginProblems[ #, dir ] &, plugins ],
        _ :> { "\"plugins\" must be a nonempty list of plugin objects." }
    }
];

pluginProblems[ plugin_Association, dir_String ] := Module[ { name, skills },
    name   = Lookup[ plugin, "name", "(unnamed)" ];
    skills = Lookup[ plugin, "skills" ];
    {
        If[ Lookup[ plugin, "source" ] =!= $marketplaceSource,
            TemplateApply[
                "Plugin \"`1`\" has source `2`, but it must be \"`3`\".",
                { name, Lookup[ plugin, "source" ], $marketplaceSource }
            ],
            { }
        ],
        If[ MatchQ[ skills, { __String } ],
            skillProblems[ name, #, dir ] & /@ skills,
            TemplateApply[ "Plugin \"`1`\" must list its skills as a nonempty list of strings.", { name } ]
        ]
    }
];

skillProblems[ plugin_, skill_String, dir_String ] :=
    If[ StringMatchQ[ skill, "./" ~~ Except[ "/" ].. ] &&
            FileType @ FileNameJoin @ { dir, StringDrop[ skill, 2 ], "SKILL.md" } === File,
        { },
        TemplateApply[
            "Plugin \"`1`\" lists skill \"`2`\", which is not a built skill directory with a SKILL.md.",
            { plugin, skill }
        ]
    ];

reportProblems[ list_List ] := cicd`ConsoleError[ marketplaceFile <> ": " <> # ] & /@ list;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Check Mode*)
If[ checkMode,
    Module[ { committedVersion, differences, marketplace, problems, stale },

        committedVersion = confirmResult[
            Wolfram`AgentSkillsBuilder`agentSkillsVersion @ skillsDir,
            "Cannot determine the version of the committed skills in " <> skillsDir
        ];

        buildSkills @ committedVersion;

        differences = confirmResult[
            Wolfram`AgentSkillsBuilder`agentSkillsDifferences[ stagingDir, skillsDir ],
            "Failed to compare agent skills"
        ];

        KeyValueMap[
            Function[ { key, paths },
                cicd`ConsoleError[ key <> " in Assets/AgentSkills: " <> # ] & /@ paths
            ],
            differences
        ];

        marketplace = readMarketplace[ ];
        problems = marketplaceProblems[ marketplace, skillsDir ];
        If[ marketplace[ "metadata", "version" ] =!= committedVersion,
            AppendTo[
                problems,
                TemplateApply[
                    "metadata.version is `1`, but the committed skills have version \"`2`\".",
                    { marketplace[ "metadata", "version" ], committedVersion }
                ]
            ]
        ];
        reportProblems @ problems;

        stale = ! AllTrue[ differences, # === { } & ] || problems =!= { };
        If[ stale,
            cicd`ConsoleError[ "Agent skills are out of date. Run: wolframscript -f Scripts/BuildAgentSkills.wls" ];
            exitWith[ 1 ],
            cicd`ConsoleLog @ SequenceForm[ "Agent skills are up to date (version ", committedVersion, ")." ];
            exitWith[ 0 ]
        ]
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Build Mode*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Build Skills*)
buildSkills @ pacletVersion;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Validate Marketplace*)
marketplaceData = readMarketplace[ ];
marketplaceIssues = marketplaceProblems[ marketplaceData, stagingDir ];
If[ marketplaceIssues =!= { }, reportProblems @ marketplaceIssues; exitWith[ 1 ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Replace Assets/AgentSkills*)
cicd`ConsoleLog @ SequenceForm[ "Replacing ", skillsDir ];
If[ FileExistsQ @ skillsDir, DeleteDirectory[ skillsDir, DeleteContents -> True ] ];
If[ FileExistsQ @ skillsDir, abort[ "Failed to delete ", skillsDir ] ];
If[ ! DirectoryQ @ CopyDirectory[ stagingDir, skillsDir ], abort[ "Failed to copy ", stagingDir, " to ", skillsDir ] ];

If[ ! AllTrue[
        confirmResult[
            Wolfram`AgentSkillsBuilder`agentSkillsDifferences[ stagingDir, skillsDir ],
            "Failed to compare agent skills"
        ],
        # === { } &
    ],
    abort[ "The copied skills in ", skillsDir, " do not match the build output." ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Update Marketplace Version*)
cicd`ConsoleLog[ "Updating marketplace version..." ];
marketplaceData[ "metadata", "version" ] = pacletVersion;
json = StringReplace[ Developer`WriteRawJSONString @ marketplaceData, "\\/" -> "/" ];
If[ ! StringQ @ json, abort[ "Failed to serialize the marketplace data." ] ];
If[ ! StringQ @ Export[ marketplaceFile, StringToByteArray @ json, "Binary" ], abort[ "Failed to write ", marketplaceFile ] ];
If[ Import[ marketplaceFile, "RawJSON" ] =!= marketplaceData, abort[ "Failed to verify ", marketplaceFile ] ];

cicd`ConsoleLog @ SequenceForm[ "Build complete: ", skillsDir, " (version ", pacletVersion, ")." ];
exitWith[ 0 ];

(* :!CodeAnalysis::EndBlock:: *)
