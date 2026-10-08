(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AgentSkillsBuilder*)
(*
    Builds the agent skills defined by the sources in AgentSkills/ into complete skill directories (the committed
    Assets/AgentSkills tree, which ships as the paclet's "AgentSkills" asset).

    This file is self-contained: it does not depend on PacletCICD, never calls Exit, never writes outside the output
    directory it is given, and returns a Failure[...] on errors. Every source path is derived from an explicit source
    directory (the repository root) rather than from the location of the loaded paclet, so the file can be loaded with
    Get in a kernel running Wolfram`AgentTools` from an MX build that has no Scripts/ or AgentSkills/ directories.

    Sources (relative to sourceDir):
        AgentSkills/Manifest.wl                    <| "skill-name" -> <| "Scripts" -> {...}, "References" -> {...} |>, ... |>
        AgentSkills/References/<Ref>.md            shared reference files
        AgentSkills/Skills/<name>/SKILL.md         hand-authored skill instructions
        AgentSkills/Skills/<name>/references/<f>   optional hand-authored references of this skill only
        AgentSkills/Skills/<name>/scripts/<f>      optional hand-authored scripts of this skill only (e.g. helpers)
        Scripts/Resources/SkillScriptTemplate.wls  template for the generated scripts

    A source skill directory may contain nothing else, and its hand-authored files must be UTF-8 text whose paths
    differ (ignoring case) from the generated files of the skill.

    Output (relative to outputDir), for each skill in the manifest:
        <name>/SKILL.md                            the source SKILL.md with metadata.version set to the given version
        <name>/scripts/<Tool>.wls                  one generated script per tool in "Scripts"
        <name>/references/<Ref>.md                 copied from AgentSkills/References/<Ref>.md
        <name>/references/Scripts.md               generated reference for the scripts
        <name>/references/<f>, <name>/scripts/<f>  copied from the source skill directory

    Exported functions (context Wolfram`AgentSkillsBuilder`):

        buildAgentSkills[ sourceDir, outputDir, version, opts ]
            Builds every skill in the manifest into outputDir, which must not exist or must be an empty directory.
            sourceDir and outputDir may be strings or File[...]; version is a string such as "2.2.16".
            Options:
                "Tools"       :> Wolfram`AgentTools`$DefaultMCPTools
                    An association of tool name -> LLMTool[...] (or -> tool data association with "Description" and
                    "Parameters") used to generate the scripts.
                "LogFunction" -> None
                    A function that is applied to a progress message string for each build step, or None.
            Returns
                Success[ "AgentSkillsBuilt", <|
                    "MessageTemplate" -> ..., "MessageParameters" -> ...,
                    "Directory" -> outputDir (absolute), "Version" -> version,
                    "Skills" -> { skill names in manifest order },
                    "Files" -> { sorted relative file paths using "/", e.g. "wolfram-alpha/SKILL.md" }
                |> ]
            or a Failure[ tag, <| "MessageTemplate" -> ..., "MessageParameters" -> ... |> ]. All inputs are validated
            and all content is generated before anything is written.

        agentSkillsDifferences[ expectedDir, actualDir ]
            Compares two skill trees. Returns
                <| "Missing" -> {...}, "Extra" -> {...}, "Different" -> {...} |>
            where each value is a sorted list of relative file paths using "/": files in expectedDir that are not in
            actualDir, files in actualDir that are not in expectedDir, and files in both whose contents differ after
            normalizing CRLF line endings to LF. All three lists are empty when the trees match. Returns a Failure if
            either argument is not a directory.

        stampSkillVersion[ skillMarkdown, version ]
            Returns skillMarkdown with metadata.version in its YAML frontmatter set to version: any version entries of
            the metadata block are removed and "  version: <version>" is added as the last entry of the block (using
            the block's indentation); a metadata block is appended to the frontmatter if there is none. The body after
            the frontmatter is never changed. The frontmatter must use LF line endings. Returns a Failure if there is
            no frontmatter or if the metadata key is not a block mapping.

        agentSkillsVersion[ dir ]
            Returns the metadata.version string shared by every <name>/SKILL.md in a built skill tree, or a Failure if
            there are no skills, if a SKILL.md has no version, or if the versions differ.

    Example:
        Get[ FileNameJoin @ { repoDir, "Scripts", "Resources", "AgentSkillsBuilder.wl" } ];
        Wolfram`AgentSkillsBuilder`buildAgentSkills[ repoDir, CreateDirectory[ ], "2.2.16" ]
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentSkillsBuilder`" ];

ClearAll[ "Wolfram`AgentSkillsBuilder`*", "Wolfram`AgentSkillsBuilder`Private`*" ];

buildAgentSkills::usage =
"buildAgentSkills[sourceDir, outputDir, version] builds the agent skills defined in sourceDir/AgentSkills into the \
empty or nonexistent directory outputDir and returns a Success object with the sorted relative file list.";

agentSkillsDifferences::usage =
"agentSkillsDifferences[expectedDir, actualDir] returns an association with the \"Missing\", \"Extra\", and \
\"Different\" relative file paths of two skill trees.";

stampSkillVersion::usage =
"stampSkillVersion[skillMarkdown, version] sets metadata.version in the YAML frontmatter of skillMarkdown.";

agentSkillsVersion::usage =
"agentSkillsVersion[dir] gives the metadata.version shared by the SKILL.md files of the built skill tree dir.";

Begin[ "`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$logFunction = None;

$skillNameRegex     = RegularExpression[ "[a-z0-9]+(-[a-z0-9]+)*" ];
$identifierRegex    = RegularExpression[ "[A-Za-z][A-Za-z0-9]*" ];
$referenceNameRegex = RegularExpression[ "[A-Za-z0-9][A-Za-z0-9_-]*" ];
$skillFileNameRegex = RegularExpression[ "[A-Za-z0-9][A-Za-z0-9._-]*" ];
$versionRegex       = RegularExpression[ "[0-9A-Za-z][0-9A-Za-z.+_-]*" ];

(* The subdirectories of a source skill directory that may contain hand-authored files: *)
$skillFileDirectories = { "references", "scripts" };

$manifestKeys = { "Scripts", "References" };

$templatePlaceholders = { "(*<<Usage>>*)", "(*<<HelpText>>*)", "(*<<ArgumentParsing>>*)", "(*<<ToolName>>*)" };

$escapeRules = { "\\" -> "\\\\", "\"" -> "\\\"", "\n" -> "\\n", "\r" -> "\\r" };

(* Operating system metadata files (compared case-insensitively) that are ignored in every directory listing, as in
   Kernel/AgentSkills.wl. They are git-ignored, but desktop file managers create them in any folder that is opened. *)
$junkFileNames = { ".ds_store", "thumbs.db", "desktop.ini" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*buildAgentSkills*)
Options[ buildAgentSkills ] = {
    "Tools"       :> Wolfram`AgentTools`$DefaultMCPTools,
    "LogFunction" -> None
};

buildAgentSkills[ sourceDir_, outputDir_, version_, OptionsPattern[ ] ] :=
    Block[ { $logFunction = OptionValue[ "LogFunction" ] },
        buildSkills[ toPath @ sourceDir, toPath @ outputDir, version, OptionValue[ "Tools" ] ]
    ];

buildAgentSkills[ args___ ] := failure[
    "InvalidArguments",
    "buildAgentSkills expects a source directory, an output directory, a version string, and options, but received \
`1` arguments.",
    Length @ HoldComplete @ args
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*buildSkills*)
buildSkills[ sourceDir_, outputDir_, version_, tools_ ] := Enclose[
    Module[ { paths, manifest, template, scriptNames, metadata, scripts, refNames, references, files },

        If[ ! (StringQ @ sourceDir && DirectoryQ @ sourceDir),
            Confirm @ failure[ "InvalidSourceDirectory", "The source directory `1` does not exist.", sourceDir ]
        ];

        Confirm @ checkVersion @ version;
        Confirm @ checkOutputDirectory @ outputDir;

        If[ ! AssociationQ @ tools,
            Confirm @ failure[
                "InvalidTools",
                "The \"Tools\" option must be an association of tool names to tools (load Wolfram`AgentTools` before \
building), but received `1`.",
                Short @ tools
            ]
        ];

        paths    = sourcePaths @ sourceDir;
        manifest = Confirm @ readManifest @ paths[ "Manifest" ];
        Confirm @ checkSkillDirectories[ paths[ "Skills" ], Keys @ manifest ];
        template = Confirm @ readTemplate @ paths[ "Template" ];

        scriptNames = DeleteDuplicates @ Flatten @ Lookup[ Values @ manifest, "Scripts" ];
        logMessage[ "Generating scripts for tools: ", StringRiffle[ scriptNames, ", " ] ];
        metadata = AssociationMap[ Confirm @ toolMetadata[ tools, # ] &, scriptNames ];
        scripts  = Association @ KeyValueMap[ #1 -> generateScript[ template, #1, #2 ] &, metadata ];

        refNames   = DeleteDuplicates @ Flatten @ Lookup[ Values @ manifest, "References" ];
        references = AssociationMap[ Confirm @ readReference[ paths[ "References" ], # ] &, refNames ];

        files = Join @@ KeyValueMap[
            Confirm @ skillFiles[ #1, #2, paths[ "Skills" ], scripts, references, metadata, version ] &,
            manifest
        ];

        Confirm @ writeFiles[ outputDir, files ];
        logMessage[ "Built ", Length @ manifest, " skills (", Length @ files, " files) in ", outputDir ];

        Success[
            "AgentSkillsBuilt",
            <|
                "MessageTemplate"   -> "Built `1` agent skills (`2` files) in `3`.",
                "MessageParameters" -> { Length @ manifest, Length @ files, outputDir },
                "Directory"         -> outputDir,
                "Version"           -> version,
                "Skills"            -> Keys @ manifest,
                "Files"             -> Sort @ Keys @ files
            |>
        ]
    ],
    unwrapFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sourcePaths*)
sourcePaths[ sourceDir_String ] := <|
    "Manifest"   -> FileNameJoin @ { sourceDir, "AgentSkills", "Manifest.wl" },
    "References" -> FileNameJoin @ { sourceDir, "AgentSkills", "References" },
    "Skills"     -> FileNameJoin @ { sourceDir, "AgentSkills", "Skills" },
    "Template"   -> FileNameJoin @ { sourceDir, "Scripts", "Resources", "SkillScriptTemplate.wls" }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkVersion*)
checkVersion[ version_String ] /; StringMatchQ[ version, $versionRegex ] := version;

checkVersion[ version_ ] := failure[
    "InvalidVersion",
    "The version `1` is not a string of letters, digits, and the characters \".+_-\".",
    version
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkOutputDirectory*)
checkOutputDirectory[ dir_String ] := Which[
    DirectoryQ @ dir && directoryEntries @ dir =!= { },
        failure[ "OutputDirectoryNotEmpty", "The output directory `1` is not empty.", dir ],
    FileExistsQ @ dir && ! DirectoryQ @ dir,
        failure[ "InvalidOutputDirectory", "The output path `1` exists and is not a directory.", dir ],
    True,
        dir
];

checkOutputDirectory[ dir_ ] := failure[ "InvalidOutputDirectory", "The output directory `1` is not valid.", dir ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sources*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readManifest*)
readManifest[ file_String ] := Enclose[
    Module[ { manifest },
        If[ ! FileExistsQ @ file,
            Confirm @ failure[ "MissingManifest", "The skill manifest `1` does not exist.", file ]
        ];

        manifest = Block[ { $Context = "Wolfram`AgentSkillsBuilder`Manifest`", $ContextPath = { "System`" } },
            Get @ file
        ];

        If[ ! (AssociationQ @ manifest && Length @ manifest > 0),
            Confirm @ failure[
                "InvalidManifest",
                "The skill manifest `1` must contain a nonempty association of skill names to skill definitions.",
                file
            ]
        ];

        Association @ KeyValueMap[ #1 -> Confirm @ checkManifestEntry[ #1, #2 ] &, manifest ]
    ],
    unwrapFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkManifestEntry*)
checkManifestEntry[ name_, entry_ ] := Enclose[
    Module[ { scripts, refs },

        If[ ! (StringQ @ name && StringLength @ name <= 64 && StringMatchQ[ name, $skillNameRegex ]),
            Confirm @ failure[
                "InvalidSkillName",
                "The skill name `1` must be at most 64 lowercase letters, digits, and single hyphens that do not start \
or end the name.",
                name
            ]
        ];

        If[ ! AssociationQ @ entry || ! SubsetQ[ $manifestKeys, Keys @ entry ],
            Confirm @ failure[
                "InvalidManifest",
                "The manifest entry for skill `1` must be an association with only the keys `2`.",
                name,
                $manifestKeys
            ]
        ];

        scripts = Confirm @ checkManifestNames[ name, "Scripts", Lookup[ entry, "Scripts", { } ], $identifierRegex ];
        refs = Confirm @ checkManifestNames[ name, "References", Lookup[ entry, "References", { } ], $referenceNameRegex ];

        If[ MemberQ[ ToLowerCase @ refs, "scripts" ],
            Confirm @ failure[
                "InvalidReferenceName",
                "The reference name \"Scripts\" of skill `1` is reserved for the generated script reference.",
                name
            ]
        ];

        <| "Scripts" -> scripts, "References" -> refs |>
    ],
    unwrapFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkManifestNames*)
checkManifestNames[ skill_String, key_String, names: { ___String }, regex_ ] := Which[
    ! AllTrue[ names, StringMatchQ[ #, regex ] & ],
        failure[
            "InvalidManifestName",
            "The \"`1`\" of skill `2` contain names that do not match `3`: `4`.",
            key,
            skill,
            First @ regex,
            Select[ names, ! StringMatchQ[ #, regex ] & ]
        ],
    ! DuplicateFreeQ @ ToLowerCase @ names,
        failure[ "DuplicateManifestName", "The \"`1`\" of skill `2` contain duplicate names.", key, skill ],
    True,
        names
];

checkManifestNames[ skill_String, key_String, names_, _ ] := failure[
    "InvalidManifest",
    "The \"`1`\" of skill `2` must be a list of strings, but found `3`.",
    key,
    skill,
    Short @ names
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkSkillDirectories*)
checkSkillDirectories[ skillsDir_String, names_List ] := Enclose[
    Module[ { unlisted },
        If[ ! DirectoryQ @ skillsDir,
            Confirm @ failure[ "MissingSkillsDirectory", "The skill source directory `1` does not exist.", skillsDir ]
        ];

        unlisted = Complement[ FileNameTake /@ directoryEntries @ skillsDir, names ];
        If[ unlisted =!= { },
            Confirm @ failure[
                "UnlistedSkillDirectory",
                "The skill source directory `1` contains entries that are not skills in the manifest: `2`.",
                skillsDir,
                unlisted
            ]
        ];

        Confirm @ checkSkillDirectory[ skillsDir, # ] & /@ names
    ],
    unwrapFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkSkillDirectory*)
checkSkillDirectory[ skillsDir_String, name_String ] := Module[ { dir, unexpected },
    dir = FileNameJoin @ { skillsDir, name };
    unexpected = If[ DirectoryQ @ dir, Select[ directoryEntries[ dir, Infinity ], ! allowedSkillEntryQ[ dir, # ] & ], { } ];
    Which[
        ! DirectoryQ @ dir,
            failure[ "MissingSkillDirectory", "The source directory `1` of skill `2` does not exist.", dir, name ],
        FileType @ FileNameJoin @ { dir, "SKILL.md" } =!= File,
            failure[ "MissingSkillFile", "The source directory `1` of skill `2` has no SKILL.md file.", dir, name ],
        unexpected =!= { },
            failure[
                "UnexpectedSkillFiles",
                "The source directory `1` of skill `2` must contain only SKILL.md and hand-authored files in its \
references and scripts directories (generated scripts and shared references are added by the build), but it also \
contains `3`.",
                dir,
                name,
                Sort[ relativePath[ dir, # ] & /@ unexpected ]
            ],
        True,
            dir
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*allowedSkillEntryQ*)
(* True for the entries a source skill directory may contain: SKILL.md, the directories in $skillFileDirectories, and
   files with simple names directly in those directories. *)
allowedSkillEntryQ[ dir_String, path_String ] := Module[ { parts, type },
    parts = Drop[ FileNameSplit @ path, Length @ FileNameSplit @ dir ];
    type  = FileType @ path;
    MatchQ[
        { parts, type },
        { { "SKILL.md" }, File } |
        { { Alternatives @@ $skillFileDirectories }, Directory } |
        { { Alternatives @@ $skillFileDirectories, _String? (StringMatchQ[ $skillFileNameRegex ]) }, File }
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*handAuthoredSkillFiles*)
(* The hand-authored files of a checked source skill directory other than SKILL.md, as sorted relative paths using "/" *)
handAuthoredSkillFiles[ skillsDir_String, name_String ] := With[ { dir = FileNameJoin @ { skillsDir, name } },
    Sort @ DeleteCases[
        relativePath[ dir, # ] & /@ Select[ directoryEntries[ dir, Infinity ], FileType @ # === File & ],
        "SKILL.md"
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readTemplate*)
readTemplate[ file_String ] := Enclose[
    Module[ { template, missing },
        If[ ! FileExistsQ @ file,
            Confirm @ failure[ "MissingTemplate", "The script template `1` does not exist.", file ]
        ];
        template = normalizeText @ Confirm @ readUTF8File @ file;
        missing  = Select[ $templatePlaceholders, ! StringContainsQ[ template, # ] & ];
        If[ missing =!= { },
            Confirm @ failure[ "InvalidTemplate", "The script template `1` is missing placeholders `2`.", file, missing ]
        ];
        template
    ],
    unwrapFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readReference*)
readReference[ refsDir_String, name_String ] := Module[ { file },
    file = FileNameJoin @ { refsDir, name <> ".md" };
    If[ FileType @ file === File,
        Replace[ readUTF8File @ file, text_String :> normalizeText @ text ],
        failure[ "MissingReference", "The reference file `1` does not exist.", file ]
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Metadata*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolMetadata*)
(* Returns <| "Description" -> ..., "Required" -> <| name -> help, ... |>, "Optional" -> <| name -> help, ... |> |>
   with all text converted to printable ASCII. *)
toolMetadata[ tools_Association, name_String ] := Enclose[
    Module[ { data, params, help },

        data = Replace[
            Lookup[ tools, name, Missing[ "NotFound" ] ],
            {
                tool_LLMTool        :> tool[ "Data" ],
                as_Association      :> as,
                Missing[ "NotFound" ] :> Confirm @ failure[ "ToolNotFound", "The tool `1` does not exist.", name ],
                other_              :> Confirm @ failure[ "InvalidTool", "The tool `1` is not valid: `2`.", name, Short @ other ]
            }
        ];

        If[ ! AssociationQ @ data || ! StringQ @ Lookup[ data, "Description" ],
            Confirm @ failure[ "InvalidTool", "The tool `1` does not have a description.", name ]
        ];

        If[ StringQ @ Lookup[ data, "Name" ] && data[ "Name" ] =!= name,
            Confirm @ failure[
                "ToolNameMismatch",
                "The tool listed as `1` in the skill manifest is named `2`.",
                name,
                data[ "Name" ]
            ]
        ];

        params = Replace[ Lookup[ data, "Parameters", { } ], rules: { ___Rule } :> Association @ rules ];
        If[ ! AssociationQ @ params || ! AllTrue[ Values @ params, AssociationQ ],
            Confirm @ failure[ "InvalidTool", "The tool `1` does not have valid parameter specifications.", name ]
        ];

        If[ ! AllTrue[ Keys @ params, StringQ @ # && StringMatchQ[ #, $identifierRegex ] & ],
            Confirm @ failure[
                "InvalidParameterName",
                "The tool `1` has parameter names that are not alphanumeric identifiers: `2`.",
                name,
                Keys @ params
            ]
        ];

        help = Replace[ Lookup[ #, "Help" ], { s_String :> toASCII @ s, _ :> "No description" } ] & /@ params;

        <|
            "Description" -> toASCII @ data[ "Description" ],
            "Required"    -> KeyTake[ help, Keys @ Select[ params, TrueQ @ Lookup[ #, "Required" ] & ] ],
            "Optional"    -> KeyTake[ help, Keys @ Select[ params, ! TrueQ @ Lookup[ #, "Required" ] & ] ]
        |>
    ],
    unwrapFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toASCII*)
(* Tool text is written as printable ASCII: line endings are normalized to "\n", and every character other than "\n",
   tab, and printable ASCII is replaced by its PrintableASCII form (e.g. \[LongDash] -> "--", \[Rule] -> "->",
   private-use characters such as \[FreeformPrompt] -> the literal text "\[FreeformPrompt]"). *)
toASCII[ text_String ] := StringJoin[ asciiCharacter /@ Characters @ StringReplace[ text, { "\r\n" -> "\n", "\r" -> "\n" } ] ];

asciiCharacter[ c_String ] := With[ { code = First @ ToCharacterCode @ c },
    If[ 32 <= code <= 126 || code === 10 || code === 9, c, toPrintableASCII @ c ]
];

toPrintableASCII[ expr_ ] := ToString[ Unevaluated @ expr, CharacterEncoding -> "PrintableASCII" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Script Generation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateScript*)
generateScript[ template_String, toolName_String, meta_Association ] := Module[ { reqNames, optNames },
    reqNames = Keys @ meta[ "Required" ];
    optNames = Keys @ meta[ "Optional" ];
    StringReplace[
        template,
        {
            "(*<<Usage>>*)"           -> generateUsageCode[ toolName, reqNames, optNames ],
            "(*<<HelpText>>*)"        -> generateHelpTextCode[ meta, generateHelpLines[ meta, reqNames, optNames ] ],
            "(*<<ArgumentParsing>>*)" -> generateArgParsingCode[ reqNames, optNames ],
            "(*<<ToolName>>*)"        -> toolName
        }
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateUsageCode*)
generateUsageCode[ toolName_String, reqNames_List, optNames_List ] :=
    "$usage = \"" <>
        StringReplace[ "wolframscript -f " <> toolName <> ".wls " <> usageArguments[ reqNames, optNames ], $escapeRules ] <>
        "\";";

usageArguments[ reqNames_List, optNames_List ] :=
    StringRiffle[ Join[ "<" <> # <> ">" & /@ reqNames, "[--" <> # <> " value]" & /@ optNames ], " " ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateHelpLines*)
generateHelpLines[ meta_Association, reqNames_List, optNames_List ] := Join[
    "  " <> # <> " (required): " <> meta[ "Required" ][ # ] & /@ reqNames,
    "  --" <> # <> ": " <> meta[ "Optional" ][ # ] & /@ optNames
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateHelpTextCode*)
generateHelpTextCode[ meta_Association, helpLines_List ] := StringJoin[
    "$helpText = StringJoin[\n",
    "    \"Usage: \", $usage, \"\\n\\n\",\n",
    "    \"", StringReplace[ meta[ "Description" ], $escapeRules ], "\\n\\n\",\n",
    If[ helpLines === { },
        "    \"No arguments.\\n\"\n",
        StringJoin[
            "    \"Arguments:\\n\",\n",
            StringRiffle[ "    \"" <> StringReplace[ #, $escapeRules ] <> "\\n\"" & /@ helpLines, ",\n" ],
            "\n"
        ]
    ],
    "];"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateArgParsingCode*)
generateArgParsingCode[ reqNames_List, optNames_List ] := StringDelete[
    StringJoin[
        If[ reqNames === { },
            "",
            StringJoin[
                "    (* Validate required arguments *)\n",
                "    If[ Length @ positional < ", ToString @ Length @ reqNames, ",\n",
                "        WriteString[ \"stderr\", \"[Error] Missing required argument(s).\\n\\n\" <> $helpText ];\n",
                "        Exit[ 1 ]\n",
                "    ];\n",
                "\n"
            ]
        ],
        MapIndexed[
            "    $parsedArgs[ \"" <> #1 <> "\" ] = positional[[ " <> ToString @ First @ #2 <> " ]];\n" &,
            reqNames
        ],
        Map[
            "    If[ KeyExistsQ[ flags, \"" <> # <> "\" ], $parsedArgs[ \"" <> # <> "\" ] = flags[ \"" <> # <> "\" ] ];\n" &,
            optNames
        ]
    ],
    "\n" ~~ EndOfString
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateScriptsMd*)
generateScriptsMd[ metadata_Association, scriptNames_List ] := StringJoin[
    "# Script Reference\n\n",
    "Auto-generated reference for bundled scripts. Pass `--usage` to any\n",
    "script for the latest argument documentation.\n\n",
    StringRiffle[ scriptMdSection[ #, metadata[ # ] ] & /@ scriptNames, "\n---\n\n" ],
    "\n"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*scriptMdSection*)
scriptMdSection[ toolName_String, meta_Association ] := Module[ { reqNames, optNames },
    reqNames = Keys @ meta[ "Required" ];
    optNames = Keys @ meta[ "Optional" ];
    StringJoin[
        "## ", toolName, ".wls\n\n",
        meta[ "Description" ], "\n\n",
        "**Usage:**\n\n",
        "```\n",
        "wolframscript -f scripts/", toolName, ".wls ", usageArguments[ reqNames, optNames ], "\n",
        "```\n\n",
        "**Arguments:**\n\n",
        scriptArgTable[ meta, reqNames, optNames ]
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*scriptArgTable*)
scriptArgTable[ meta_Association, reqNames_List, optNames_List ] := Module[ { rows },
    rows = Join[
        "| `" <> # <> "` | Yes | " <> escapeMdTableCell @ meta[ "Required" ][ # ] <> " |" & /@ reqNames,
        "| `--" <> # <> "` | No | " <> escapeMdTableCell @ meta[ "Optional" ][ # ] <> " |" & /@ optNames
    ];
    If[ rows === { },
        "This script has no arguments.\n",
        StringJoin[
            "| Argument | Required | Description |\n",
            "| --- | --- | --- |\n",
            StringRiffle[ rows, "\n" ],
            "\n"
        ]
    ]
];

escapeMdTableCell[ s_String ] := StringReplace[ s, { "|" -> "\\|", "\n" -> " " } ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skill Assembly*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillFiles*)
(* The files of one built skill as an association of relative path -> content. *)
skillFiles[ name_String, entry_Association, skillsDir_String, scripts_, references_, metadata_, version_String ] :=
    Enclose[
        Module[ { skillFile, skillMarkdown, stamped, scriptNames, refNames, generated, handAuthored },
            logMessage[ "Building skill: ", name ];
            skillFile     = FileNameJoin @ { skillsDir, name, "SKILL.md" };
            skillMarkdown = normalizeText @ Confirm @ readUTF8File @ skillFile;
            Confirm @ checkSkillName[ skillMarkdown, name, skillFile ];
            stamped = Confirm @ stampSkillVersion[ skillMarkdown, version ];

            scriptNames = entry[ "Scripts" ];
            refNames    = entry[ "References" ];

            generated = Association[
                name <> "/SKILL.md" -> stamped,
                name <> "/scripts/" <> # <> ".wls" -> scripts[ # ] & /@ scriptNames,
                name <> "/references/" <> # <> ".md" -> references[ # ] & /@ refNames,
                If[ scriptNames === { },
                    { },
                    name <> "/references/Scripts.md" -> generateScriptsMd[ metadata, scriptNames ]
                ]
            ];

            handAuthored = Confirm @ readHandAuthoredSkillFiles[ skillsDir, name, generated ];

            Join[ generated, handAuthored ]
        ],
        unwrapFailure
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readHandAuthoredSkillFiles*)
(* The hand-authored files of a skill (other than SKILL.md) as an association of output path -> normalized text.
   Their paths must differ from the generated files of the skill, ignoring case, since skills are also installed on
   case-insensitive file systems. references/Scripts.md is always reserved for the generated script reference. *)
readHandAuthoredSkillFiles[ skillsDir_String, name_String, generated_Association ] := Enclose[
    Module[ { paths, reserved, conflicts },
        paths     = handAuthoredSkillFiles[ skillsDir, name ];
        reserved  = ToLowerCase @ Append[ Keys @ generated, name <> "/references/Scripts.md" ];
        conflicts = Select[ paths, MemberQ[ reserved, ToLowerCase[ name <> "/" <> # ] ] & ];

        If[ conflicts =!= { },
            Confirm @ failure[
                "SkillFileConflict",
                "The hand-authored files `1` of skill `2` have the same paths as files that the build generates.",
                conflicts,
                name
            ]
        ];

        Association @ Map[
            name <> "/" <> # -> normalizeText @ Confirm @ readUTF8File @ FileNameJoin @ Prepend[
                StringSplit[ #, "/" ],
                FileNameJoin @ { skillsDir, name }
            ] &,
            paths
        ]
    ],
    unwrapFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkSkillName*)
checkSkillName[ markdown_String, name_String, file_String ] := Enclose[
    Module[ { frontmatter, names },
        frontmatter = First @ Confirm @ splitFrontmatter @ markdown;
        names = scalarValue /@ Select[ frontmatter, topLevelKeyLineQ[ #, "name" ] & ];
        If[ names =!= { name },
            Confirm @ failure[
                "SkillNameMismatch",
                "The frontmatter name of `1` must be `2`, but found `3`.",
                file,
                name,
                names
            ]
        ];
        name
    ],
    unwrapFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeFiles*)
writeFiles[ outputDir_String, files_Association ] := Enclose[
    If[ ! DirectoryQ @ outputDir,
        ConfirmBy[ CreateDirectory @ outputDir, DirectoryQ, "CreateOutputDirectory" ]
    ];
    KeyValueMap[
        (
            logMessage[ "  ", #1 ];
            Confirm @ writeUTF8File[ FileNameJoin @ Prepend[ StringSplit[ #1, "/" ], outputDir ], #2 ]
        ) &,
        files
    ],
    unwrapFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Version Stamping*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stampSkillVersion*)
stampSkillVersion[ markdown_String, version_ ] := Enclose[
    Module[ { v, frontmatter, rest, stamped },
        v = Confirm @ checkVersion @ version;
        { frontmatter, rest } = Confirm @ splitFrontmatter @ markdown;
        stamped = StringRiffle[ Join[ { "---" }, Confirm @ setMetadataVersion[ frontmatter, v ], rest ], "\n" ];
        ConfirmAssert[ metadataVersion @ stamped === v, "StampedVersion" ];
        stamped
    ],
    unwrapFailure
];

stampSkillVersion[ markdown_, _ ] := failure[
    "InvalidArguments",
    "stampSkillVersion expects the skill markdown as a string, but received `1`.",
    Short @ markdown
];

stampSkillVersion[ args___ ] := failure[
    "InvalidArguments",
    "stampSkillVersion expects two arguments, but received `1`.",
    Length @ HoldComplete @ args
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*splitFrontmatter*)
(* Splits markdown into { frontmatter lines, remaining lines starting with the closing "---" line }, so that
   StringRiffle[ Join[ { "---" }, frontmatter, rest ], "\n" ] restores the original text exactly. *)
splitFrontmatter[ markdown_String ] := Module[ { lines, close },
    lines = StringSplit[ markdown, "\n", All ];
    close = FirstPosition[ Rest @ lines, "---", Missing[ "NotFound" ], { 1 }, Heads -> False ];
    Which[
        First @ lines =!= "---",
            failure[ "MissingFrontmatter", "The skill markdown does not start with a YAML frontmatter line \"---\"." ],
        MissingQ @ close,
            failure[ "MissingFrontmatter", "The YAML frontmatter of the skill markdown has no closing \"---\" line." ],
        True,
            { lines[[ 2 ;; First @ close ]], lines[[ First @ close + 1 ;; ]] }
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*setMetadataVersion*)
setMetadataVersion[ frontmatter_List, version_String ] := Module[ { positions, pos, end, block, indent },
    positions = Flatten @ Position[ frontmatter, _String? (topLevelKeyLineQ[ #, "metadata" ] &), { 1 }, Heads -> False ];
    Which[
        positions === { },
            Join[ frontmatter, { "metadata:", "  version: " <> yamlScalar @ version } ],
        Length @ positions > 1,
            failure[ "UnsupportedMetadata", "The YAML frontmatter contains more than one metadata key." ],
        ! blockHeaderQ @ frontmatter[[ First @ positions ]],
            failure[
                "UnsupportedMetadata",
                "The metadata value in the YAML frontmatter must be a block mapping, but found `1`.",
                frontmatter[[ First @ positions ]]
            ],
        True,
            pos    = First @ positions;
            end    = blockEnd[ frontmatter, pos ];
            block  = frontmatter[[ pos + 1 ;; end ]];
            indent = blockIndent @ block;
            Join[
                frontmatter[[ ;; pos ]],
                dropVersionEntries[ block, indent ],
                { indent <> "version: " <> yamlScalar @ version },
                frontmatter[[ end + 1 ;; ]]
            ]
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*metadataVersion*)
(* The metadata.version value of a skill markdown string, or Missing[ ... ] if there is none. *)
metadataVersion[ markdown_String ] := Module[ { parts, frontmatter, positions, pos, block, indent, entries },
    parts = splitFrontmatter @ markdown;
    frontmatter = If[ FailureQ @ parts, { }, First @ parts ];
    positions = Flatten @ Position[ frontmatter, _String? (topLevelKeyLineQ[ #, "metadata" ] &), { 1 }, Heads -> False ];
    If[ Length @ positions === 1 && blockHeaderQ @ frontmatter[[ First @ positions ]],
        pos     = First @ positions;
        block   = frontmatter[[ pos + 1 ;; blockEnd[ frontmatter, pos ] ]];
        indent  = blockIndent @ block;
        entries = Select[ block, versionEntryQ[ #, indent ] & ];
        If[ Length @ entries === 1, scalarValue @ First @ entries, Missing[ "NotFound" ] ],
        Missing[ "NotFound" ]
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*YAML Line Utilities*)
topLevelKeyLineQ[ line_String, key_String ] :=
    StringMatchQ[ line, RegularExpression[ key <> "[ \\t]*:([ \\t].*)?" ] ];

blockHeaderQ[ line_String ] := StringMatchQ[ line, RegularExpression[ "[A-Za-z0-9_-]+[ \\t]*:[ \\t]*(#.*)?" ] ];

blankQ[ line_String ] := StringMatchQ[ line, RegularExpression[ "[ \\t]*" ] ];

indentedQ[ line_String ] := StringStartsQ[ line, " " | "\t" ] && ! blankQ @ line;

(* The index of the last indented line of the block that follows the key at position pos (pos if the block is empty). *)
blockEnd[ lines_List, pos_Integer ] := Module[ { end, i },
    end = pos;
    i   = pos + 1;
    While[ i <= Length @ lines && (indentedQ @ lines[[ i ]] || blankQ @ lines[[ i ]]),
        If[ indentedQ @ lines[[ i ]], end = i ];
        i++
    ];
    end
];

blockIndent[ block_List ] := Replace[
    SelectFirst[ block, indentedQ ],
    {
        line_String :> First @ StringCases[ line, StartOfString ~~ ws: (" " | "\t").. :> ws, 1 ],
        _           :> "  "
    }
];

versionEntryQ[ line_String, indent_String ] :=
    StringStartsQ[ line, indent ] &&
        StringMatchQ[
            StringDrop[ line, StringLength @ indent ],
            RegularExpression[ "(version|\"version\"|'version')[ \\t]*:([ \\t].*)?" ]
        ];

deeperQ[ line_String, indent_String ] :=
    indentedQ @ line && StringStartsQ[ line, indent ] && StringStartsQ[ StringDrop[ line, StringLength @ indent ], " " | "\t" ];

(* Removes the entries for the version key (and any more deeply indented continuation lines) from a block. *)
dropVersionEntries[ block_List, indent_String ] := Module[ { skipping = False },
    Flatten @ Last @ Reap @ Do[
        Which[
            versionEntryQ[ line, indent ], skipping = True,
            skipping && deeperQ[ line, indent ], Null,
            True, skipping = False; Sow @ line
        ],
        { line, block }
    ]
];

(* The value of a "key: value" line with surrounding whitespace and matching quotes removed. *)
scalarValue[ line_String ] := Module[ { value },
    value = StringTrim @ StringReplace[ line, RegularExpression[ "^[^:]*:" ] -> "", 1 ];
    If[ StringLength @ value >= 2 && MatchQ[ StringTake[ value, { 1, -1, StringLength @ value - 1 } ], "\"\"" | "''" ],
        StringTake[ value, { 2, -2 } ],
        value
    ]
];

(* Quotes a version that YAML would otherwise read as a number, boolean, or null. *)
yamlScalar[ value_String ] := If[
    StringMatchQ[ value, RegularExpression[ "[-+]?(\\.[0-9]+|[0-9]+(\\.[0-9]*)?)([eE][-+]?[0-9]+)?|0[xXoObB][0-9a-fA-F]+" ] ] ||
        MemberQ[ { "true", "false", "null", "yes", "no", "on", "off", "y", "n" }, ToLowerCase @ value ],
    "\"" <> value <> "\"",
    value
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*agentSkillsVersion*)
agentSkillsVersion[ dir_ ] := Enclose[
    Module[ { path, skillMarkdownFiles, versions },
        path = toPath @ dir;
        If[ ! (StringQ @ path && DirectoryQ @ path),
            Confirm @ failure[ "InvalidDirectory", "The skill directory `1` does not exist.", path ]
        ];

        skillMarkdownFiles = Select[ FileNameJoin @ { #, "SKILL.md" } & /@ Select[ FileNames[ All, path ], DirectoryQ ], FileExistsQ ];
        If[ skillMarkdownFiles === { },
            Confirm @ failure[ "MissingVersion", "The directory `1` does not contain any skills.", path ]
        ];

        versions = AssociationMap[
            Replace[ readUTF8File @ #, text_String :> metadataVersion @ normalizeText @ text ] &,
            skillMarkdownFiles
        ];

        If[ ! AllTrue[ versions, StringQ ],
            Confirm @ failure[
                "MissingVersion",
                "These SKILL.md files do not have a metadata version: `1`.",
                Keys @ Select[ versions, ! StringQ @ # & ]
            ]
        ];

        If[ Length @ Union @ Values @ versions > 1,
            Confirm @ failure[ "InconsistentVersions", "The skills in `1` have different versions: `2`.", path, versions ]
        ];

        First @ versions
    ],
    unwrapFailure
];

agentSkillsVersion[ args___ ] := failure[
    "InvalidArguments",
    "agentSkillsVersion expects one argument, but received `1`.",
    Length @ HoldComplete @ args
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*agentSkillsDifferences*)
agentSkillsDifferences[ expectedDir_, actualDir_ ] := Enclose[
    Module[ { expected, actual, common },
        expected = Confirm @ relativeFiles @ toPath @ expectedDir;
        actual   = Confirm @ relativeFiles @ toPath @ actualDir;
        common   = Intersection[ Keys @ expected, Keys @ actual ];
        <|
            "Missing"   -> Sort @ Complement[ Keys @ expected, Keys @ actual ],
            "Extra"     -> Sort @ Complement[ Keys @ actual, Keys @ expected ],
            "Different" -> Sort @ Select[ common, normalizedFileString @ expected[ # ] =!= normalizedFileString @ actual[ # ] & ]
        |>
    ],
    unwrapFailure
];

agentSkillsDifferences[ args___ ] := failure[
    "InvalidArguments",
    "agentSkillsDifferences expects two directories, but received `1` arguments.",
    Length @ HoldComplete @ args
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relativeFiles*)
(* An association of relative path (using "/") -> absolute path for every file under dir. *)
relativeFiles[ dir_String ] /; DirectoryQ @ dir := Module[ { files },
    files = Select[ directoryEntries[ dir, Infinity ], FileType @ # === File & ];
    AssociationThread[ relativePath[ dir, # ] & /@ files, files ]
];

relativeFiles[ dir_ ] := failure[ "InvalidDirectory", "The skill directory `1` does not exist.", dir ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*normalizedFileString*)
(* The bytes of a file as a string of character codes 0-255 with CRLF normalized to LF. *)
normalizedFileString[ file_String ] := Replace[
    ReadByteArray @ file,
    {
        bytes_ByteArray :> StringReplace[ ByteArrayToString[ bytes, "ISOLatin1" ], "\r\n" -> "\n" ],
        EndOfFile       :> "",
        other_          :> other
    }
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toPath*)
toPath[ File[ path_String ] ] := toPath @ path;
toPath[ path_String ] /; StringLength @ path > 0 := ExpandFileName @ path;
toPath[ other_ ] := other;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relativePath*)
relativePath[ dir_String, file_String ] := StringRiffle[ Drop[ FileNameSplit @ file, Length @ FileNameSplit @ dir ], "/" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*directoryEntries*)
(* The entries of a directory (to the given depth), without operating system metadata files ($junkFileNames). *)
directoryEntries[ dir_String ] := directoryEntries[ dir, 1 ];
directoryEntries[ dir_String, depth_ ] := Select[ FileNames[ All, dir, depth ], ! junkFileQ @ # & ];

junkFileQ[ path_String ] := MemberQ[ $junkFileNames, ToLowerCase @ FileNameTake @ path ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readUTF8File*)
readUTF8File[ file_String ] := Module[ { bytes, text },
    bytes = ReadByteArray @ file;
    text  = If[ ByteArrayQ @ bytes, Quiet @ ByteArrayToString[ bytes, "UTF-8" ], bytes ];
    Which[
        bytes === EndOfFile,
            "",
        ! ByteArrayQ @ bytes,
            failure[ "ReadFailed", "Failed to read `1`.", file ],
        ! StringQ @ text || StringToByteArray[ text, "UTF-8" ] =!= bytes,
            failure[ "InvalidUTF8", "The file `1` is not valid UTF-8.", file ],
        True,
            text
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*normalizeText*)
(* Hand-authored text is written with LF line endings and without a byte order mark. *)
normalizeText[ text_String ] := StringReplace[ StringDelete[ text, StartOfString ~~ "\:feff" ], { "\r\n" -> "\n", "\r" -> "\n" } ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeUTF8File*)
writeUTF8File[ file_String, text_String ] := Enclose[
    Module[ { dir, bytes },
        dir = DirectoryName @ file;
        If[ ! DirectoryQ @ dir, ConfirmBy[ CreateDirectory @ dir, DirectoryQ, "CreateDirectory" ] ];
        bytes = StringToByteArray[ text, "UTF-8" ];
        If[ Length @ bytes === 0,
            Close @ OpenWrite[ file, BinaryFormat -> True ],
            ConfirmBy[ Export[ file, bytes, "Binary" ], StringQ, "Export" ]
        ];
        ConfirmAssert[ FileByteCount @ file === Length @ bytes, "ByteCount" ];
        file
    ],
    unwrapFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Error Handling*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*failure*)
failure[ tag_String, template_String, params___ ] :=
    Failure[ tag, <| "MessageTemplate" -> template, "MessageParameters" -> { params } |> ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*unwrapFailure*)
(* Enclose handler: returns the original failure that was passed to Confirm instead of a ConfirmationFailed wrapper. *)
unwrapFailure[ Failure[ "ConfirmationFailed", as_Association ] ] /; MatchQ[ Lookup[ as, "Expression" ], _Failure ] :=
    unwrapFailure @ Lookup[ as, "Expression" ];

unwrapFailure[ f_Failure ] := f;

unwrapFailure[ other_ ] := Failure[
    "AgentSkillsBuilderInternal",
    <| "MessageTemplate" -> "An unexpected error occurred: `1`.", "MessageParameters" -> { Short @ other } |>
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*logMessage*)
logMessage[ parts___ ] := If[ $logFunction =!= None, $logFunction @ StringJoin[ ToString /@ { parts } ] ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
