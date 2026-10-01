(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/AgentSkills.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/AgentSkills.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Helper Functions*)
(* Every test works in fresh directories under $skillTestBase (removed at the end of the file). Tests that touch the
   skill registry or deployment records use withTemporaryRoot, and tests that use client names Block $HomeDirectory. *)

catchTop                 = Wolfram`AgentTools`Common`catchTop;
agentSkillName           = Wolfram`AgentTools`Common`agentSkillName;
agentSkillNameQ          = Wolfram`AgentTools`Common`agentSkillNameQ;
applySkillInstallPlan    = Wolfram`AgentTools`Common`applySkillInstallPlan;
canonicalPath            = Wolfram`AgentTools`Common`canonicalPath;
canonicalPathKey         = Wolfram`AgentTools`Common`canonicalPathKey;
compareSkillManifest     = Wolfram`AgentTools`Common`compareSkillManifest;
deleteSkillRegistryEntry = Wolfram`AgentTools`Common`deleteSkillRegistryEntry;
deploymentUUIDExistsQ    = Wolfram`AgentTools`Common`deploymentUUIDExistsQ;
planSkillInstall         = Wolfram`AgentTools`Common`planSkillInstall;
readSkillRegistryEntry   = Wolfram`AgentTools`Common`readSkillRegistryEntry;
releaseSkillReference    = Wolfram`AgentTools`Common`releaseSkillReference;
resolveSkillsRoot        = Wolfram`AgentTools`Common`resolveSkillsRoot;
skillDirectoryState      = Wolfram`AgentTools`Common`skillDirectoryState;
skillManifest            = Wolfram`AgentTools`Common`skillManifest;
skillRegistryKey         = Wolfram`AgentTools`Common`skillRegistryKey;
skillReleaseMessages     = Wolfram`AgentTools`Common`skillReleaseMessages;
sweepSkillRegistry       = Wolfram`AgentTools`Common`sweepSkillRegistry;
toAgentSkillSource       = Wolfram`AgentTools`Common`toAgentSkillSource;
writeSkillRegistryEntry  = Wolfram`AgentTools`Common`writeSkillRegistryEntry;

applyLowLevelInstall     = Wolfram`AgentTools`AgentSkills`Private`applyLowLevelInstall;
lowLevelInstallPlan      = Wolfram`AgentTools`AgentSkills`Private`lowLevelInstallPlan;
skillFileHash            = Wolfram`AgentTools`AgentSkills`Private`skillFileHash;
versionOlderQ            = Wolfram`AgentTools`AgentSkills`Private`versionOlderQ;
writeBytes               = Wolfram`AgentTools`AgentSkills`Private`writeBytes;
writeSkillFile           = Wolfram`AgentTools`AgentSkills`Private`writeSkillFile;

$skillTestBase = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, "AgentSkillsTests_" <> CreateUUID[ ] };

ifSymlinks = conditionalTest[ $OperatingSystem =!= "Windows" ];

(* A fresh, empty directory *)
skillTestDirectory[ ] := CreateDirectory @ FileNameJoin @ { $skillTestBase, CreateUUID[ ] };

(* Writes UTF-8 bytes exactly as given (no line ending conversion), creating parent directories *)
writeTestFile[ file_String, content_String ] := (
    If[ ! DirectoryQ @ DirectoryName @ file, CreateDirectory @ DirectoryName @ file ];
    With[ { stream = OpenWrite[ file, BinaryFormat -> True ] },
        If[ content =!= "", BinaryWrite[ stream, StringToByteArray[ content, "UTF-8" ] ] ];
        Close @ stream
    ];
    file
);

readTestFile[ file_String ] :=
    Replace[ ReadByteArray @ file, { bytes_ByteArray :> ByteArrayToString[ bytes, "UTF-8" ], EndOfFile -> "" } ];

skillMarkdown[ name_String, description_String, body_String ] :=
    "---\nname: " <> name <> "\ndescription: " <> description <> "\n---\n\n" <> body <> "\n";

(* Creates parent/name with a SKILL.md and the given extra files (relative path -> content) *)
makeTestSkill[ parent_String, name_String ] := makeTestSkill[ parent, name, "Test body.", <| |> ];
makeTestSkill[ parent_String, name_String, body_String ] := makeTestSkill[ parent, name, body, <| |> ];
makeTestSkill[ parent_String, name_String, body_String, extra_Association ] :=
    Module[ { dir },
        dir = FileNameJoin @ { parent, name };
        writeTestFile[ FileNameJoin @ { dir, "SKILL.md" }, skillMarkdown[ name, "A test skill named " <> name, body ] ];
        KeyValueMap[ writeTestFile[ FileNameJoin @ Prepend[ StringSplit[ #1, "/" ], dir ], #2 ] &, extra ];
        dir
    ];

(* In-memory skill sources with a deployment-style identifier *)
genSource[ name_String, body_String ] := genSource[ name, body, "AgentToolsObject:Test/" <> name ];
genSource[ name_String, body_String, id_ ] :=
    toAgentSkillSource[ <| "Name" -> name, "Description" -> "Test skill " <> name, "Body" -> body |>, id ];

(* Paclet skill sources (identified by qualified name, versioned by paclet version) *)
pacletSource[ name_String, body_String, version_String ] :=
    toAgentSkillSource @ <|
        "Type"          -> "PacletSkill",
        "Name"          -> name,
        "QualifiedName" -> "Pub/TestPaclet/" <> name,
        "PacletName"    -> "Pub/TestPaclet",
        "PacletVersion" -> version,
        "Definition"    -> <| "Name" -> name, "Description" -> "Paclet skill " <> name, "Body" -> body |>
    |>;

(* Simulated deployment records: $deploymentsPath/<client>/<uuid>/Deployment.wxf *)
fakeDeployment[ uuid_String ] := fakeDeployment[ uuid, "ClaudeCode" ];
fakeDeployment[ uuid_String, client_String ] :=
    Module[ { dir },
        dir = FileNameJoin @ { Wolfram`AgentTools`Common`$deploymentsPath, client, uuid };
        If[ ! DirectoryQ @ dir, CreateDirectory @ dir ];
        Developer`WriteWXFFile[ FileNameJoin @ { dir, "Deployment.wxf" }, <| "UUID" -> uuid |> ];
        uuid
    ];

removeFakeDeployment[ uuid_String ] :=
    Scan[
        If[ DirectoryQ @ FileNameJoin @ { #, uuid }, DeleteDirectory[ FileNameJoin @ { #, uuid }, DeleteContents -> True ] ] &,
        FileNames[ All, Wolfram`AgentTools`Common`$deploymentsPath ]
    ];

(* Plans and applies a deployment's skills, finalizes, and records the deployment *)
deploySkills[ sources_List, root_File, uuid_String ] := deploySkills[ sources, root, uuid, { }, False ];
deploySkills[ sources_List, root_File, uuid_String, replaced_List, overwrite_ ] :=
    Module[ { plan, result },
        plan = planSkillInstall[ sources, root, uuid, replaced, overwrite ];
        result = applySkillInstallPlan[ plan, uuid ];
        Scan[ #[ ] &, result[ "Finalize" ] ];
        fakeDeployment @ uuid;
        result
    ];

planAction[ sources_List, root_File, uuid_String, replaced_List, overwrite_ ] :=
    Replace[
        planSkillInstall[ sources, root, uuid, replaced, overwrite ],
        {
            KeyValuePattern @ { "Conflicts" -> { c_, ___ } } :> { "Conflict", c[ "Tag" ], c[ "Parameters" ] },
            KeyValuePattern @ { "Decisions" -> { d_, ___ } } :> d[ "Action" ]
        }
    ];

backupFiles[ root_String ] := FileNames[ ".agenttools-backup-*", DirectoryName @ root ];

symlink[ target_String, link_String ] := RunProcess[ { "ln", "-s", target, link } ][ "ExitCode" ] === 0;

chmod[ mode_String, path_String ] := RunProcess[ { "chmod", mode, path } ][ "ExitCode" ] === 0;

(* Restores write permissions below a test directory, so that it can be cleaned up *)
restoreWritable[ dir_String ] := RunProcess[ { "chmod", "-R", "u+rwX", dir } ][ "ExitCode" ] === 0;

(* File permissions are only enforced on Unix-like systems, and not for root *)
$permissionsEnforced = $OperatingSystem =!= "Windows" && Module[ { file, enforced },
    file = writeTestFile[ FileNameJoin @ { $skillTestBase, "permissions-probe.txt" }, "probe" ];
    chmod[ "000", file ];
    enforced = ! ByteArrayQ @ Quiet @ ReadByteArray @ file;
    chmod[ "644", file ];
    DeleteFile @ file;
    enforced
];

ifPermissions = conditionalTest[ $permissionsEnforced ];

(* The test's root is a fresh subdirectory, so that the backups made in its parent belong to this test only *)
isolatedSkillsRoot[ ] := CreateDirectory @ FileNameJoin @ { skillTestDirectory[ ], "skills" };

(* A directory skill source with a scripts subdirectory *)
scriptedSource[ name_String, body_String ] :=
    toAgentSkillSource @ File @ makeTestSkill[ skillTestDirectory[ ], name, body, <| "scripts/run.sh" -> "#!/bin/sh\necho run\n" |> ];

(* Makes the given internal function return value for calls matching lhs (e.g. to simulate a failure) *)
withFailureInjection // Attributes = { HoldAll };
withFailureInjection[ sym_Symbol, lhs_, value_, eval_ ] :=
    Module[ { saved = DownValues @ sym },
        WithCleanup[
            DownValues[ sym ] = Prepend[ saved, HoldPattern @ lhs :> value ],
            eval,
            DownValues[ sym ] = saved
        ]
    ];

(* Each test that uses the registry runs in a fresh $rootPath and $HomeDirectory *)
withSkillTestRoot // Attributes = { HoldFirst };
withSkillTestRoot[ eval_ ] := withTemporaryRoot @ Block[ { $HomeDirectory = skillTestDirectory[ ] }, eval ];

testSkillsRoot[ ] := File @ FileNameJoin @ { $HomeDirectory, ".claude", "skills" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skill Names*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*agentSkillNameQ*)
VerificationTest[
    agentSkillNameQ /@ { "a", "my-skill", "a1-b2-c3", "0", StringRepeat[ "a", 64 ] },
    { True, True, True, True, True },
    SameTest -> SameQ,
    TestID   -> "AgentSkillNameQ-Valid@@Tests/AgentSkills.wlt:193,1-198,2"
]

VerificationTest[
    agentSkillNameQ /@ { "", "-a", "a-", "a--b", "My-Skill", "a_b", "a b", "a/b", ".", "..", StringRepeat[ "a", 65 ], 1, None },
    ConstantArray[ False, 13 ],
    SameTest -> SameQ,
    TestID   -> "AgentSkillNameQ-Invalid@@Tests/AgentSkills.wlt:200,1-205,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*agentSkillName*)
VerificationTest[
    Module[ { dir },
        dir = skillTestDirectory[ ];
        (* the name comes from SKILL.md, not from the directory name *)
        writeTestFile[ FileNameJoin @ { dir, "folder", "SKILL.md" }, skillMarkdown[ "inner-name", "Described", "Body" ] ];
        {
            agentSkillName[ "my-skill" ],
            agentSkillName[ "Pub/Paclet/paclet-skill" ],
            agentSkillName[ "Paclet/short-skill" ],
            agentSkillName @ LLMSkill[ { "llm-skill", "Description" }, "Body" ],
            agentSkillName @ <| "Name" -> "assoc-skill", "Description" -> "d", "Body" -> "b" |>,
            agentSkillName @ <| "Type" -> "PacletSkill", "Name" -> "def-skill", "QualifiedName" -> "P/def-skill" |>,
            agentSkillName @ File @ FileNameJoin @ { dir, "folder" }
        }
    ],
    { "my-skill", "paclet-skill", "short-skill", "llm-skill", "assoc-skill", "def-skill", "inner-name" },
    SameTest -> SameQ,
    TestID   -> "AgentSkillName-Forms@@Tests/AgentSkills.wlt:210,1-228,2"
]

VerificationTest[
    catchTop @ agentSkillName[ 123 ],
    Failure[ "AgentTools::InvalidAgentSkill", _ ],
    { AgentTools::InvalidAgentSkill },
    SameTest -> MatchQ,
    TestID   -> "AgentSkillName-Invalid@@Tests/AgentSkills.wlt:230,1-236,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skill Sources*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Directory Sources*)
VerificationTest[
    Module[ { parent, dir, source },
        parent = skillTestDirectory[ ];
        dir = makeTestSkill[
            parent,
            "dir-skill",
            "Body",
            <|
                "scripts/run.wls"            -> "#!/usr/bin/env wolframscript\nPrint[1]\n",
                "references/notes.md"        -> "Notes",
                ".DS_Store"                  -> "junk",
                "Thumbs.db"                  -> "junk",
                "references/desktop.ini"     -> "junk",
                "scripts/__pycache__/a.pyc"  -> "junk",
                ".git/config"                -> "vcs",
                ".hg"                        -> "vcs",
                "references/.svn/entries"    -> "vcs"
            |>
        ];
        source = toAgentSkillSource @ File @ dir;
        {
            source[ "Name" ],
            source[ "Description" ],
            source[ "Identifier" ] === "File:" <> canonicalPathKey @ dir,
            source[ "Version" ],
            source[ "SourceDirectory" ],
            Sort @ Keys @ source[ "Files" ],
            Keys @ source[ "Files" ] === Keys @ KeySort @ source[ "Files" ],
            Keys @ source[ "Manifest" ] === Keys @ source[ "Files" ],
            source[ "Files", "SKILL.md" ] === File @ FileNameJoin @ { dir, "SKILL.md" },
            AllTrue[ source[ "Manifest" ], StringMatchQ[ #, Repeated[ HexadecimalCharacter, { 64 } ] ] & ]
        }
    ],
    {
        "dir-skill",
        "A test skill named dir-skill",
        True,
        Missing[ ],
        File[ _String ],
        { "references/notes.md", "scripts/run.wls", "SKILL.md" },
        True,
        True,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-Directory@@Tests/AgentSkills.wlt:245,1-292,2"
]

VerificationTest[
    Module[ { dir, a, b, c },
        dir = makeTestSkill[ skillTestDirectory[ ], "file-forms" ];
        a = toAgentSkillSource @ File @ dir;
        b = toAgentSkillSource @ File @ FileNameJoin @ { dir, "SKILL.md" };
        c = toAgentSkillSource @ File[ dir <> "/" ];
        { a === b, a === c }
    ],
    { True, True },
    SameTest -> SameQ,
    TestID   -> "ToAgentSkillSource-Directory-PathForms@@Tests/AgentSkills.wlt:294,1-305,2"
]

VerificationTest[
    Module[ { dir },
        dir = skillTestDirectory[ ];
        writeTestFile[ FileNameJoin @ { dir, "README.md" }, "Not a skill" ];
        catchTop @ toAgentSkillSource @ File @ dir
    ],
    Failure[ "AgentTools::InvalidAgentSkill", _ ],
    { AgentTools::InvalidAgentSkill },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-Directory-NoSkillFile@@Tests/AgentSkills.wlt:307,1-317,2"
]

VerificationTest[
    Module[ { dir },
        dir = skillTestDirectory[ ];
        writeTestFile[ FileNameJoin @ { dir, "SKILL.md" }, "No frontmatter here" ];
        catchTop @ toAgentSkillSource @ File @ dir
    ],
    Failure[ "AgentTools::InvalidAgentSkill", _ ],
    { AgentTools::InvalidAgentSkill },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-Directory-InvalidSkillFile@@Tests/AgentSkills.wlt:319,1-329,2"
]

VerificationTest[
    Module[ { dir },
        dir = skillTestDirectory[ ];
        writeTestFile[ FileNameJoin @ { dir, "SKILL.md" }, "---\nname: no-description\n---\n\nBody\n" ];
        catchTop @ toAgentSkillSource @ File @ dir
    ],
    Failure[ "AgentTools::InvalidAgentSkillDescription", KeyValuePattern[ "MessageParameters" :> { "no-description" } ] ],
    { AgentTools::InvalidAgentSkillDescription },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-Directory-MissingDescription@@Tests/AgentSkills.wlt:331,1-341,2"
]

VerificationTest[
    Module[ { dir },
        dir = skillTestDirectory[ ];
        writeTestFile[ FileNameJoin @ { dir, "SKILL.md" }, skillMarkdown[ "Bad_Name", "Described", "Body" ] ];
        catchTop @ toAgentSkillSource @ File @ dir
    ],
    Failure[ "AgentTools::InvalidAgentSkillName", KeyValuePattern[ "MessageParameters" :> { "Bad_Name" } ] ],
    { AgentTools::InvalidAgentSkillName },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-Directory-InvalidName@@Tests/AgentSkills.wlt:343,1-353,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LLMSkill Sources*)

(* An LLMSkill whose location is an existing skill directory copies that directory *)
VerificationTest[
    Module[ { dir, skill, fromSkill, fromFile },
        dir = makeTestSkill[ skillTestDirectory[ ], "located-skill", "Body", <| "scripts/a.txt" -> "a" |> ];
        skill = LLMSkill @ File @ dir;
        fromSkill = toAgentSkillSource[ skill, "AgentToolsObject:Ignored/located-skill" ];
        fromFile = toAgentSkillSource @ File @ dir;
        {
            fromSkill === fromFile,
            StringEndsQ[ fromSkill[ "Identifier" ], "/" ],
            Keys @ fromSkill[ "Files" ]
        }
    ],
    { True, False, { "scripts/a.txt", "SKILL.md" } },
    SameTest -> SameQ,
    TestID   -> "ToAgentSkillSource-LLMSkill-Location@@Tests/AgentSkills.wlt:360,1-375,2"
]

VerificationTest[
    Module[ { a, b },
        a = toAgentSkillSource @ LLMSkill[ { "memory-skill", "In memory" }, "Body text" ];
        b = toAgentSkillSource[ LLMSkill[ { "memory-skill", "In memory" }, "Body text" ], "AgentToolsObject:Bundle/memory-skill" ];
        {
            a[ "Identifier" ],
            b[ "Identifier" ],
            a[ "SourceDirectory" ],
            a[ "Files" ],
            a[ "Manifest" ] === b[ "Manifest" ]
        }
    ],
    {
        None,
        "AgentToolsObject:Bundle/memory-skill",
        None,
        <| "SKILL.md" -> "---\nname: memory-skill\ndescription: In memory\n---\n\nBody text\n" |>,
        True
    },
    SameTest -> SameQ,
    TestID   -> "ToAgentSkillSource-LLMSkill-InMemory@@Tests/AgentSkills.wlt:377,1-398,2"
]

(* A location that no longer exists is ignored, and SKILL.md is generated from the fields. LLMFunctions reads
   "allowed-Tools" (sic), so a standard allowed-tools key ends up in the additional frontmatter; it is written back as
   allowed-tools, in its standard position. *)
VerificationTest[
    Module[ { dir, skill, source },
        dir = skillTestDirectory[ ];
        writeTestFile[
            FileNameJoin @ { dir, "moved-skill", "SKILL.md" },
            "---\nname: moved-skill\ndescription: Moved\nx-custom: 1\nallowed-tools: Bash\n---\n\nBody\n"
        ];
        skill = LLMSkill @ File @ FileNameJoin @ { dir, "moved-skill" };
        DeleteDirectory[ dir, DeleteContents -> True ];
        source = toAgentSkillSource @ skill;
        { source[ "SourceDirectory" ], source[ "Files", "SKILL.md" ] }
    ],
    { None, "---\nname: moved-skill\ndescription: Moved\nallowed-tools: Bash\nx-custom: 1\n---\n\nBody\n" },
    SameTest -> SameQ,
    TestID   -> "ToAgentSkillSource-LLMSkill-StaleLocation@@Tests/AgentSkills.wlt:403,1-418,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Generated SKILL.md*)
VerificationTest[
    toAgentSkillSource[
        <|
            "Name"                  -> "full-skill",
            "Description"           -> "Does things: well",
            "Body"                  -> "\r\nLine one\r\nLine two  \n\n",
            "License"               -> "MIT",
            "Compatibility"         -> "Requires wolframscript",
            "Metadata"              -> <| "author" -> "me", "version" -> 1.5, "count" -> 3, "flag" -> True |>,
            "AdditionalFrontmatter" -> <| "x-extra" -> "value", "allowed-tools" -> "Bash Read", "another" -> "z" |>
        |>
    ][ "Files", "SKILL.md" ],
    StringJoin[
        "---\n",
        "name: full-skill\n",
        "description: \"Does things: well\"\n",
        "license: MIT\n",
        "compatibility: Requires wolframscript\n",
        "allowed-tools: Bash Read\n",
        "metadata:\n",
        "  author: me\n",
        "  version: \"1.5\"\n",
        "  count: \"3\"\n",
        "  flag: \"true\"\n",
        "x-extra: value\n",
        "another: z\n",
        "---\n",
        "\n",
        "Line one\n",
        "Line two\n"
    ],
    SameTest -> SameQ,
    TestID   -> "GeneratedSkillFile-AllFields@@Tests/AgentSkills.wlt:423,1-456,2"
]

(* AllowedTools takes precedence over the additional frontmatter; absent values are omitted *)
VerificationTest[
    toAgentSkillSource[
        <|
            "Name"                  -> "allowed-skill",
            "Description"           -> "Allowed",
            "Body"                  -> "Body",
            "License"               -> None,
            "AllowedTools"          -> "Read",
            "AdditionalFrontmatter" -> <| "allowed-tools" -> "Bash" |>
        |>
    ][ "Files", "SKILL.md" ],
    "---\nname: allowed-skill\ndescription: Allowed\nallowed-tools: Read\n---\n\nBody\n",
    SameTest -> SameQ,
    TestID   -> "GeneratedSkillFile-AllowedTools@@Tests/AgentSkills.wlt:459,1-473,2"
]

VerificationTest[
    toAgentSkillSource[ <| "Name" -> "empty-body", "Description" -> "Nothing else" |> ][ "Files", "SKILL.md" ],
    "---\nname: empty-body\ndescription: Nothing else\n---\n",
    SameTest -> SameQ,
    TestID   -> "GeneratedSkillFile-EmptyBody@@Tests/AgentSkills.wlt:475,1-480,2"
]

(* Byte-identical for identical input, so redeploys don't look like modifications *)
VerificationTest[
    Module[ { spec, a, b, dir },
        spec = <|
            "Name"        -> "stable-skill",
            "Description" -> "Stable \[LongDash] unicode \[Alpha]",
            "Body"        -> "Some body \[Pi]",
            "Metadata"    -> { "b" -> "2", "a" -> "1" }
        |>;
        a = toAgentSkillSource @ spec;
        b = toAgentSkillSource @ spec;
        dir = skillTestDirectory[ ];
        InstallAgentSkills[ File @ dir, spec ];
        {
            a === b,
            a[ "Manifest", "SKILL.md" ] === skillFileHash @ File @ FileNameJoin @ { dir, "stable-skill", "SKILL.md" },
            readTestFile @ FileNameJoin @ { dir, "stable-skill", "SKILL.md" } === a[ "Files", "SKILL.md" ]
        }
    ],
    { True, True, True },
    SameTest -> SameQ,
    TestID   -> "GeneratedSkillFile-Deterministic@@Tests/AgentSkills.wlt:483,1-504,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Validation*)
VerificationTest[
    catchTop @ toAgentSkillSource @ <| "Name" -> "Not Valid", "Description" -> "d", "Body" -> "b" |>,
    Failure[ "AgentTools::InvalidAgentSkillName", KeyValuePattern[ "MessageParameters" :> { "Not Valid" } ] ],
    { AgentTools::InvalidAgentSkillName },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-InvalidName@@Tests/AgentSkills.wlt:509,1-515,2"
]

VerificationTest[
    catchTop @ toAgentSkillSource @ LLMSkill[ { "a--b", "d" }, "b" ],
    Failure[ "AgentTools::InvalidAgentSkillName", _ ],
    { AgentTools::InvalidAgentSkillName },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-InvalidName-LLMSkill@@Tests/AgentSkills.wlt:517,1-523,2"
]

VerificationTest[
    {
        catchTop @ toAgentSkillSource @ <| "Name" -> "no-desc", "Body" -> "b" |>,
        catchTop @ toAgentSkillSource @ <| "Name" -> "empty-desc", "Description" -> "", "Body" -> "b" |>
    },
    {
        Failure[ "AgentTools::InvalidAgentSkillDescription", KeyValuePattern[ "MessageParameters" :> { "no-desc" } ] ],
        Failure[ "AgentTools::InvalidAgentSkillDescription", KeyValuePattern[ "MessageParameters" :> { "empty-desc" } ] ]
    },
    { AgentTools::InvalidAgentSkillDescription, AgentTools::InvalidAgentSkillDescription },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-InvalidDescription-Empty@@Tests/AgentSkills.wlt:525,1-537,2"
]

VerificationTest[
    {
        catchTop @ toAgentSkillSource @ <| "Name" -> "blank-desc", "Description" -> "  \n ", "Body" -> "b" |>,
        catchTop @ toAgentSkillSource @ <| "Name" -> "long-desc", "Description" -> StringRepeat[ "x", 1025 ], "Body" -> "b" |>
    },
    {
        Failure[ "AgentTools::InvalidAgentSkillDescription", KeyValuePattern[ "MessageParameters" :> { "blank-desc" } ] ],
        Failure[ "AgentTools::InvalidAgentSkillDescription", KeyValuePattern[ "MessageParameters" :> { "long-desc" } ] ]
    },
    { AgentTools::InvalidAgentSkillDescription, AgentTools::InvalidAgentSkillDescription },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-InvalidDescription-BlankOrLong@@Tests/AgentSkills.wlt:539,1-551,2"
]

VerificationTest[
    catchTop @ toAgentSkillSource @ LLMSkill[ "llm-no-desc", "b" ],
    Failure[ "AgentTools::InvalidAgentSkillDescription", KeyValuePattern[ "MessageParameters" :> { "llm-no-desc" } ] ],
    { AgentTools::InvalidAgentSkillDescription },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-InvalidDescription-LLMSkill@@Tests/AgentSkills.wlt:553,1-559,2"
]

VerificationTest[
    toAgentSkillSource[ <| "Name" -> "max-desc", "Description" -> StringRepeat[ "x", 1024 ], "Body" -> "b" |> ][ "Name" ],
    "max-desc",
    SameTest -> SameQ,
    TestID   -> "ToAgentSkillSource-MaxDescription@@Tests/AgentSkills.wlt:561,1-566,2"
]

VerificationTest[
    {
        catchTop @ toAgentSkillSource[ 123 ],
        catchTop @ toAgentSkillSource @ <| "Description" -> "no name" |>
    },
    { Failure[ "AgentTools::InvalidAgentSkill", _ ], Failure[ "AgentTools::InvalidAgentSkill", _ ] },
    { AgentTools::InvalidAgentSkill, AgentTools::InvalidAgentSkill },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-InvalidSpecification@@Tests/AgentSkills.wlt:568,1-577,2"
]

VerificationTest[
    catchTop @ toAgentSkillSource @ <| "Name" -> "bad-body", "Description" -> "d", "Body" -> 5 |>,
    Failure[ "AgentTools::InvalidAgentSkill", _ ],
    { AgentTools::InvalidAgentSkill },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-InvalidBody@@Tests/AgentSkills.wlt:579,1-585,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Built-in Skills*)
VerificationTest[
    catchTop @ toAgentSkillSource[ "no-such-built-in-skill" ],
    Failure[ "AgentTools::AgentSkillNotFound", KeyValuePattern[ "MessageParameters" :> { "no-such-built-in-skill" } ] ],
    { AgentTools::AgentSkillNotFound },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-BuiltIn-NotFound@@Tests/AgentSkills.wlt:590,1-596,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`$defaultAgentSkills,
    <| |>,
    SameTest -> SameQ,
    TestID   -> "DefaultAgentSkills-Empty@@Tests/AgentSkills.wlt:598,1-603,2"
]

VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Common`$defaultAgentSkills = <|
                "built-in-skill" -> <| "Name" -> "built-in-skill", "Description" -> "Built in", "Body" -> "Body" |>
            |>
        },
        KeyTake[ toAgentSkillSource[ "built-in-skill", "AgentToolsObject:Ignored/built-in-skill" ], { "Name", "Identifier" } ]
    ],
    <| "Name" -> "built-in-skill", "Identifier" -> "built-in-skill" |>,
    SameTest -> SameQ,
    TestID   -> "ToAgentSkillSource-BuiltIn@@Tests/AgentSkills.wlt:605,1-617,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Paclet Skill Definitions*)
(* Paclet-qualified names are resolved by resolvePacletSkill (PacletExtension.wl); the skill definitions it returns are
   tested here directly. *)
VerificationTest[
    Module[ { dir, source },
        dir = makeTestSkill[ skillTestDirectory[ ], "paclet-dir-skill", "Body", <| "scripts/x.wl" -> "1" |> ];
        source = toAgentSkillSource[
            <|
                "Type"          -> "PacletSkill",
                "Name"          -> "paclet-dir-skill",
                "QualifiedName" -> "Pub/Paclet/paclet-dir-skill",
                "PacletName"    -> "Pub/Paclet",
                "PacletVersion" -> "1.2.0",
                "Directory"     -> File @ dir
            |>,
            "AgentToolsObject:Ignored/paclet-dir-skill"
        ];
        { source[ "Identifier" ], source[ "Version" ], Keys @ source[ "Files" ], source[ "SourceDirectory" ] === File @ dir }
    ],
    { "Pub/Paclet/paclet-dir-skill", "1.2.0", { "scripts/x.wl", "SKILL.md" }, True },
    SameTest -> SameQ,
    TestID   -> "ToAgentSkillSource-PacletSkill-Directory@@Tests/AgentSkills.wlt:624,1-643,2"
]

VerificationTest[
    KeyTake[ pacletSource[ "paclet-def-skill", "Body", "2.0.1" ], { "Name", "Identifier", "Version", "Files" } ],
    <|
        "Name"       -> "paclet-def-skill",
        "Identifier" -> "Pub/TestPaclet/paclet-def-skill",
        "Version"    -> "2.0.1",
        "Files"      -> <| "SKILL.md" -> "---\nname: paclet-def-skill\ndescription: Paclet skill paclet-def-skill\n---\n\nBody\n" |>
    |>,
    SameTest -> SameQ,
    TestID   -> "ToAgentSkillSource-PacletSkill-Association@@Tests/AgentSkills.wlt:645,1-655,2"
]

(* An LLMSkill definition never uses its "Location" (resolvePacletSkill returns "Directory" for honored locations) *)
VerificationTest[
    Module[ { dir, source },
        dir = makeTestSkill[ skillTestDirectory[ ], "paclet-llm-skill", "Body", <| "extra.txt" -> "x" |> ];
        source = toAgentSkillSource @ <|
            "Type"          -> "PacletSkill",
            "Name"          -> "paclet-llm-skill",
            "QualifiedName" -> "Paclet/paclet-llm-skill",
            "PacletName"    -> "Paclet",
            "PacletVersion" -> "1.0.0",
            "Definition"    -> LLMSkill @ File @ dir
        |>;
        { Keys @ source[ "Files" ], StringQ @ source[ "Files", "SKILL.md" ], source[ "SourceDirectory" ], source[ "Identifier" ] }
    ],
    { { "SKILL.md" }, True, None, "Paclet/paclet-llm-skill" },
    SameTest -> SameQ,
    TestID   -> "ToAgentSkillSource-PacletSkill-LLMSkillLocationIgnored@@Tests/AgentSkills.wlt:658,1-674,2"
]

VerificationTest[
    catchTop @ toAgentSkillSource @ <|
        "Type"          -> "PacletSkill",
        "Name"          -> "declared-name",
        "QualifiedName" -> "Paclet/declared-name",
        "PacletName"    -> "Paclet",
        "PacletVersion" -> "1.0.0",
        "Definition"    -> <| "Name" -> "other-name", "Description" -> "d", "Body" -> "b" |>
    |>,
    Failure[ "AgentTools::InvalidPacletSkillDefinition", KeyValuePattern[ "MessageParameters" :> { "Paclet/declared-name" } ] ],
    { AgentTools::InvalidPacletSkillDefinition },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-PacletSkill-NameMismatch@@Tests/AgentSkills.wlt:676,1-689,2"
]

VerificationTest[
    catchTop @ toAgentSkillSource @ <|
        "Type"          -> "PacletSkill",
        "Name"          -> "nothing",
        "QualifiedName" -> "Paclet/nothing",
        "PacletName"    -> "Paclet",
        "PacletVersion" -> "1.0.0"
    |>,
    Failure[ "AgentTools::InvalidPacletSkillDefinition", _ ],
    { AgentTools::InvalidPacletSkillDefinition },
    SameTest -> MatchQ,
    TestID   -> "ToAgentSkillSource-PacletSkill-NoDefinition@@Tests/AgentSkills.wlt:691,1-703,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Hashing*)
VerificationTest[
    {
        skillFileHash[ "hello\n" ],
        skillFileHash[ "" ]
    },
    {
        "5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03",
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    },
    SameTest -> SameQ,
    TestID   -> "SkillFileHash-SHA256@@Tests/AgentSkills.wlt:708,1-719,2"
]

VerificationTest[
    Module[ { dir },
        dir = skillTestDirectory[ ];
        writeTestFile[ FileNameJoin @ { dir, "crlf.txt" }, "line one\r\nline two\r\n" ];
        writeTestFile[ FileNameJoin @ { dir, "lf.txt" }, "line one\nline two\n" ];
        writeTestFile[ FileNameJoin @ { dir, "empty.txt" }, "" ];
        {
            skillFileHash @ File @ FileNameJoin @ { dir, "crlf.txt" } === skillFileHash @ File @ FileNameJoin @ { dir, "lf.txt" },
            skillFileHash @ File @ FileNameJoin @ { dir, "lf.txt" } === skillFileHash[ "line one\nline two\n" ],
            skillFileHash[ "a\r\nb" ] === skillFileHash[ "a\nb" ],
            skillFileHash @ File @ FileNameJoin @ { dir, "empty.txt" } === skillFileHash[ "" ]
        }
    ],
    { True, True, True, True },
    SameTest -> SameQ,
    TestID   -> "SkillFileHash-LineEndings@@Tests/AgentSkills.wlt:721,1-737,2"
]

(* Content with NUL bytes is binary: line endings are part of the content *)
VerificationTest[
    skillFileHash[ "a" <> FromCharacterCode[ 0 ] <> "\r\n" ] === skillFileHash[ "a" <> FromCharacterCode[ 0 ] <> "\n" ],
    False,
    SameTest -> SameQ,
    TestID   -> "SkillFileHash-BinaryNotNormalized@@Tests/AgentSkills.wlt:740,1-745,2"
]

VerificationTest[
    Module[ { dir },
        dir = makeTestSkill[ skillTestDirectory[ ], "manifest-skill", "Body", <| "a/b.txt" -> "b", ".DS_Store" -> "x", ".git/HEAD" -> "x" |> ];
        { Keys @ skillManifest @ File @ dir, skillManifest @ File @ dir === toAgentSkillSource[ File @ dir ][ "Manifest" ] }
    ],
    { { "a/b.txt", "SKILL.md" }, True },
    SameTest -> SameQ,
    TestID   -> "SkillManifest-Directory@@Tests/AgentSkills.wlt:747,1-755,2"
]

(* A file that can't be read: an installed directory with one is "Modified" (never an internal failure), and a source
   with one fails with a message that names the file *)
ifPermissions @ VerificationTest[
    Module[ { dir, file, baseline },
        dir      = makeTestSkill[ skillTestDirectory[ ], "unreadable-hash", "Body", <| "secret.txt" -> "secret" |> ];
        file     = FileNameJoin @ { dir, "secret.txt" };
        baseline = skillManifest @ File @ dir;
        WithCleanup[
            chmod[ "000", file ];
            {
                skillFileHash @ File @ file,
                skillManifest @ File @ dir,
                compareSkillManifest[ File @ dir, baseline ],
                catchTop @ toAgentSkillSource @ File @ dir
            },
            chmod[ "644", file ]
        ]
    ],
    {
        Missing[ "Unreadable", _String? (StringEndsQ[ "secret.txt" ]) ],
        None,
        "Modified",
        Failure[ "AgentTools::AgentSkillUnreadable", _? (MatchQ[ #[ "MessageParameters" ], { File[ _String? (StringEndsQ[ "secret.txt" ]) ] } ] &) ]
    },
    { AgentTools::AgentSkillUnreadable },
    SameTest -> MatchQ,
    TestID   -> "SkillFileHash-Unreadable@@Tests/AgentSkills.wlt:759,17-784,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*compareSkillManifest*)
VerificationTest[
    Module[ { dir, baseline, results },
        dir = makeTestSkill[ skillTestDirectory[ ], "compare-skill", "Body", <| "scripts/a.txt" -> "a\nb\n" |> ];
        baseline = skillManifest @ File @ dir;
        results = <| |>;
        results[ "Unmodified" ] = compareSkillManifest[ File @ dir, baseline ];

        (* junk entries never count as modifications *)
        writeTestFile[ FileNameJoin @ { dir, ".DS_Store" }, "junk" ];
        writeTestFile[ FileNameJoin @ { dir, "scripts", "__pycache__", "a.cpython-312.pyc" }, "junk" ];
        writeTestFile[ FileNameJoin @ { dir, "scripts", "Thumbs.db" }, "junk" ];
        results[ "Junk" ] = compareSkillManifest[ File @ dir, baseline ];

        (* CRLF line endings (e.g. from git core.autocrlf) are not modifications *)
        writeTestFile[ FileNameJoin @ { dir, "scripts", "a.txt" }, "a\r\nb\r\n" ];
        results[ "CRLF" ] = compareSkillManifest[ File @ dir, baseline ];

        writeTestFile[ FileNameJoin @ { dir, "scripts", "a.txt" }, "changed" ];
        results[ "Edited" ] = compareSkillManifest[ File @ dir, baseline ];
        writeTestFile[ FileNameJoin @ { dir, "scripts", "a.txt" }, "a\nb\n" ];

        writeTestFile[ FileNameJoin @ { dir, "new.txt" }, "new" ];
        results[ "Added" ] = compareSkillManifest[ File @ dir, baseline ];
        DeleteFile @ FileNameJoin @ { dir, "new.txt" };

        DeleteFile @ FileNameJoin @ { dir, "scripts", "a.txt" };
        results[ "Deleted" ] = compareSkillManifest[ File @ dir, baseline ];
        writeTestFile[ FileNameJoin @ { dir, "scripts", "a.txt" }, "a\nb\n" ];
        results[ "Restored" ] = compareSkillManifest[ File @ dir, baseline ];

        (* version-control metadata makes the directory "Modified" *)
        writeTestFile[ FileNameJoin @ { dir, ".git", "HEAD" }, "ref: refs/heads/main" ];
        results[ "VCS" ] = compareSkillManifest[ File @ dir, baseline ];

        results[ "Missing" ] = compareSkillManifest[ File @ FileNameJoin @ { dir, "nope" }, baseline ];
        results
    ],
    <|
        "Unmodified" -> "Unmodified",
        "Junk"       -> "Unmodified",
        "CRLF"       -> "Unmodified",
        "Edited"     -> "Modified",
        "Added"      -> "Modified",
        "Deleted"    -> "Modified",
        "Restored"   -> "Unmodified",
        "VCS"        -> "Modified",
        "Missing"    -> "Missing"
    |>,
    SameTest -> SameQ,
    TestID   -> "CompareSkillManifest@@Tests/AgentSkills.wlt:789,1-839,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paths*)
VerificationTest[
    Module[ { dir },
        dir = skillTestDirectory[ ];
        {
            canonicalPath @ dir === AbsoluteFileName @ dir,
            canonicalPath @ File @ dir === AbsoluteFileName @ dir,
            canonicalPath @ FileNameJoin @ { dir, "a", "b" } === FileNameJoin @ { AbsoluteFileName @ dir, "a", "b" },
            canonicalPath @ FileNameJoin @ { dir, "a", "..", "c" } === FileNameJoin @ { AbsoluteFileName @ dir, "c" },
            canonicalPathKey @ FileNameJoin @ { dir, "x" } === StringReplace[
                If[ MemberQ[ { "Windows", "MacOSX" }, $OperatingSystem ], ToLowerCase, Identity ][
                    FileNameJoin @ { AbsoluteFileName @ dir, "x" }
                ],
                "\\" -> "/"
            ]
        }
    ],
    { True, True, True, True, True },
    SameTest -> SameQ,
    TestID   -> "CanonicalPath@@Tests/AgentSkills.wlt:844,1-863,2"
]

ifSymlinks @ VerificationTest[
    Module[ { dir, target, link },
        dir = skillTestDirectory[ ];
        target = CreateDirectory @ FileNameJoin @ { dir, "target" };
        link = FileNameJoin @ { dir, "link" };
        symlink[ target, link ];
        {
            canonicalPath @ FileNameJoin @ { link, "not-yet", "skill" } === FileNameJoin @ { AbsoluteFileName @ target, "not-yet", "skill" },
            skillRegistryKey[ File @ link, "my-skill" ] === skillRegistryKey[ File @ target, "my-skill" ],
            skillRegistryKey[ File @ link, "my-skill" ] =!= skillRegistryKey[ File @ target, "other-skill" ]
        }
    ],
    { True, True, True },
    SameTest -> SameQ,
    TestID   -> "CanonicalPath-SymbolicLinks@@Tests/AgentSkills.wlt:865,14-880,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*skillDirectoryState*)
VerificationTest[
    Module[ { root },
        root = skillTestDirectory[ ];
        makeTestSkill[ root, "real-skill" ];
        writeTestFile[ FileNameJoin @ { root, "a-file" }, "x" ];
        {
            skillDirectoryState[ File @ FileNameJoin @ { root, "no-root" }, "x" ],
            skillDirectoryState[ File @ root, "missing" ],
            skillDirectoryState[ File @ root, "real-skill" ],
            skillDirectoryState[ File @ root, "a-file" ],
            skillDirectoryState @ File @ FileNameJoin @ { root, "real-skill" }
        }
    ],
    { "Missing", "Missing", "Directory", "File", "Directory" },
    SameTest -> SameQ,
    TestID   -> "SkillDirectoryState-Basic@@Tests/AgentSkills.wlt:885,1-901,2"
]

ifSymlinks @ VerificationTest[
    Module[ { base, root, target, linkedRoot },
        base = skillTestDirectory[ ];
        root = CreateDirectory @ FileNameJoin @ { base, "root" };
        target = makeTestSkill[ base, "target-skill" ];
        symlink[ target, FileNameJoin @ { root, "linked-skill" } ];
        symlink[ FileNameJoin @ { base, "does-not-exist" }, FileNameJoin @ { root, "dangling-skill" } ];
        makeTestSkill[ root, "plain-skill" ];
        (* a regular directory inside a symbolically linked root is a regular directory *)
        linkedRoot = FileNameJoin @ { base, "linked-root" };
        symlink[ root, linkedRoot ];
        {
            skillDirectoryState[ File @ root, "linked-skill" ],
            skillDirectoryState[ File @ root, "dangling-skill" ],
            skillDirectoryState[ File @ root, "plain-skill" ],
            skillDirectoryState[ File @ linkedRoot, "plain-skill" ],
            skillDirectoryState[ File @ linkedRoot, "linked-skill" ]
        }
    ],
    { "Link", "Dangling", "Directory", "Directory", "Link" },
    SameTest -> SameQ,
    TestID   -> "SkillDirectoryState-SymbolicLinks@@Tests/AgentSkills.wlt:903,14-925,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InstallAgentSkills*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Installation*)
VerificationTest[
    Module[ { src, root, result },
        src = makeTestSkill[ skillTestDirectory[ ], "basic-skill", "Basic body", <| "scripts/tool.txt" -> "tool\r\n" |> ];
        root = FileNameJoin @ { skillTestDirectory[ ], "skills" };
        result = InstallAgentSkills[ File @ root, File @ src ];
        {
            result,
            readTestFile @ FileNameJoin @ { root, "basic-skill", "SKILL.md" } === readTestFile @ FileNameJoin @ { src, "SKILL.md" },
            (* files are copied byte for byte *)
            readTestFile @ FileNameJoin @ { root, "basic-skill", "scripts", "tool.txt" },
            backupFiles @ root
        }
    ],
    {
        Success[
            "InstallAgentSkills",
            KeyValuePattern @ {
                "MessageTemplate"   :> AgentTools::InstallAgentSkill,
                "MessageParameters" -> { "basic-skill" },
                "Name"              -> "basic-skill",
                "Location"          -> File[ _String? (StringEndsQ[ "basic-skill" ]) ],
                "ClientName"        -> None
            }
        ],
        True,
        "tool\r\n",
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-Single@@Tests/AgentSkills.wlt:934,1-964,2"
]

VerificationTest[
    Module[ { root, result },
        root = FileNameJoin @ { skillTestDirectory[ ], "skills" };
        result = InstallAgentSkills[
            File @ root,
            {
                LLMSkill[ { "first-skill", "First" }, "One" ],
                <| "Name" -> "second-skill", "Description" -> "Second", "Body" -> "Two" |>
            }
        ];
        { result, Sort @ FileNames[ All, root ] === Sort @ { FileNameJoin @ { root, "first-skill" }, FileNameJoin @ { root, "second-skill" } } }
    ],
    {
        { Success[ "InstallAgentSkills", KeyValuePattern[ "Name" -> "first-skill" ] ], Success[ "InstallAgentSkills", KeyValuePattern[ "Name" -> "second-skill" ] ] },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-List@@Tests/AgentSkills.wlt:966,1-984,2"
]

VerificationTest[
    InstallAgentSkills[ File @ FileNameJoin @ { skillTestDirectory[ ], "skills" }, { } ],
    { },
    SameTest -> SameQ,
    TestID   -> "InstallAgentSkills-EmptyList@@Tests/AgentSkills.wlt:986,1-991,2"
]

(* Junk and version-control entries are never copied *)
VerificationTest[
    Module[ { src, root },
        src = makeTestSkill[
            skillTestDirectory[ ],
            "clean-skill",
            "Body",
            <| ".DS_Store" -> "x", "desktop.ini" -> "x", "__pycache__/a.pyc" -> "x", ".git/HEAD" -> "x", ".svn" -> "x", "keep.txt" -> "k" |>
        ];
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, File @ src ];
        Sort[ FileNameTake /@ FileNames[ All, FileNameJoin @ { root, "clean-skill" } ] ]
    ],
    { "keep.txt", "SKILL.md" },
    SameTest -> SameQ,
    TestID   -> "InstallAgentSkills-SkipsJunkAndVCS@@Tests/AgentSkills.wlt:994,1-1009,2"
]

(* Files that are executable in the source or start with "#!" are made executable *)
ifSymlinks @ VerificationTest[
    Module[ { src, root, mode },
        src = makeTestSkill[
            skillTestDirectory[ ],
            "exec-skill",
            "Body",
            <| "scripts/shebang.sh" -> "#!/bin/sh\necho hi\n", "scripts/mode.bin" -> "binary", "scripts/plain.txt" -> "plain" |>
        ];
        RunProcess @ { "chmod", "+x", FileNameJoin @ { src, "scripts", "mode.bin" } };
        RunProcess @ { "chmod", "-x", FileNameJoin @ { src, "scripts", "shebang.sh" } };
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, File @ src ];
        mode = BitAnd[ FileInformation[ FileNameJoin @ { root, "exec-skill", "scripts", # }, "Permissions" ], 8^^100 ] =!= 0 &;
        mode /@ { "shebang.sh", "mode.bin", "plain.txt" }
    ],
    { True, True, False },
    SameTest -> SameQ,
    TestID   -> "InstallAgentSkills-ExecutableFiles@@Tests/AgentSkills.wlt:1012,14-1030,2"
]

ifSymlinks @ VerificationTest[
    Module[ { root, mode },
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, <| "Name" -> "gen-exec", "Description" -> "d", "Body" -> "b" |> ];
        mode = FileInformation[ FileNameJoin @ { root, "gen-exec", "SKILL.md" }, "Permissions" ];
        BitAnd[ mode, 8^^111 ]
    ],
    0,
    SameTest -> SameQ,
    TestID   -> "InstallAgentSkills-GeneratedNotExecutable@@Tests/AgentSkills.wlt:1032,14-1042,2"
]

(* Symbolic links inside a skill are followed when copying *)
ifSymlinks @ VerificationTest[
    Module[ { base, external, src, root, installed },
        base = skillTestDirectory[ ];
        external = CreateDirectory @ FileNameJoin @ { base, "external" };
        writeTestFile[ FileNameJoin @ { external, "shared.txt" }, "shared" ];
        src = makeTestSkill[ base, "linking-skill" ];
        symlink[ external, FileNameJoin @ { src, "linked-dir" } ];
        symlink[ FileNameJoin @ { external, "shared.txt" }, FileNameJoin @ { src, "linked-file.txt" } ];
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, File @ src ];
        installed = FileNameJoin @ { root, "linking-skill" };
        {
            skillDirectoryState[ File @ installed, "linked-dir" ],
            readTestFile @ FileNameJoin @ { installed, "linked-dir", "shared.txt" },
            readTestFile @ FileNameJoin @ { installed, "linked-file.txt" },
            AbsoluteFileName @ FileNameJoin @ { installed, "linked-file.txt" } === FileNameJoin @ { AbsoluteFileName @ installed, "linked-file.txt" }
        }
    ],
    { "Directory", "shared", "shared", True },
    SameTest -> SameQ,
    TestID   -> "InstallAgentSkills-FollowsLinks@@Tests/AgentSkills.wlt:1045,14-1066,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Existing Entries*)

(* Identical content is a no-op success: nothing is written (a junk file added after installing survives) *)
VerificationTest[
    Module[ { src, root },
        src = makeTestSkill[ skillTestDirectory[ ], "same-skill", "Body", <| "a.txt" -> "a\nb\n" |> ];
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, File @ src ];
        writeTestFile[ FileNameJoin @ { root, "same-skill", ".DS_Store" }, "junk" ];
        (* CRLF line endings don't count as different content *)
        writeTestFile[ FileNameJoin @ { root, "same-skill", "a.txt" }, "a\r\nb\r\n" ];
        {
            InstallAgentSkills[ File @ root, File @ src ],
            InstallAgentSkills[ File @ root, File @ src, OverwriteTarget -> True ],
            FileExistsQ @ FileNameJoin @ { root, "same-skill", ".DS_Store" },
            readTestFile @ FileNameJoin @ { root, "same-skill", "a.txt" }
        }
    ],
    {
        Success[ "InstallAgentSkills", KeyValuePattern[ "Name" -> "same-skill" ] ],
        Success[ "InstallAgentSkills", KeyValuePattern[ "Name" -> "same-skill" ] ],
        True,
        "a\r\nb\r\n"
    },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-IdenticalNoOp@@Tests/AgentSkills.wlt:1073,1-1096,2"
]

VerificationTest[
    Module[ { root, before },
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, <| "Name" -> "exists-skill", "Description" -> "d", "Body" -> "Version 1" |> ];
        before = readTestFile @ FileNameJoin @ { root, "exists-skill", "SKILL.md" };
        {
            InstallAgentSkills[ File @ root, <| "Name" -> "exists-skill", "Description" -> "d", "Body" -> "Version 2" |> ],
            readTestFile @ FileNameJoin @ { root, "exists-skill", "SKILL.md" } === before
        }
    ],
    {
        Failure[
            "InstallAgentSkills::AgentSkillExists",
            KeyValuePattern[ "MessageParameters" :> { "exists-skill", File[ _String ], True } ]
        ],
        True
    },
    { InstallAgentSkills::AgentSkillExists },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-ExistsFails@@Tests/AgentSkills.wlt:1098,1-1118,2"
]

VerificationTest[
    Module[ { root, results },
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, <| "Name" -> "overwrite-skill", "Description" -> "d", "Body" -> "Version 1" |> ];
        writeTestFile[ FileNameJoin @ { root, "overwrite-skill", "user-file.txt" }, "user" ];
        results = {
            InstallAgentSkills[ File @ root, <| "Name" -> "overwrite-skill", "Description" -> "d", "Body" -> "Version 2" |>, OverwriteTarget -> True ],
            StringContainsQ[ readTestFile @ FileNameJoin @ { root, "overwrite-skill", "SKILL.md" }, "Version 2" ],
            FileExistsQ @ FileNameJoin @ { root, "overwrite-skill", "user-file.txt" },
            InstallAgentSkills[ File @ root, <| "Name" -> "overwrite-skill", "Description" -> "d", "Body" -> "Version 3" |>, OverwriteTarget -> All ],
            StringContainsQ[ readTestFile @ FileNameJoin @ { root, "overwrite-skill", "SKILL.md" }, "Version 3" ],
            backupFiles @ root
        };
        results
    ],
    {
        Success[ "InstallAgentSkills", KeyValuePattern[ "Name" -> "overwrite-skill" ] ],
        True,
        False,
        Success[ "InstallAgentSkills", KeyValuePattern[ "Name" -> "overwrite-skill" ] ],
        True,
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-Overwrite@@Tests/AgentSkills.wlt:1120,1-1145,2"
]

(* Preflight: a conflict anywhere fails the whole call before anything is written *)
VerificationTest[
    Module[ { root, result },
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, <| "Name" -> "conflict-skill", "Description" -> "d", "Body" -> "Version 1" |> ];
        result = InstallAgentSkills[
            File @ root,
            {
                <| "Name" -> "fresh-skill", "Description" -> "d", "Body" -> "Fresh" |>,
                <| "Name" -> "conflict-skill", "Description" -> "d", "Body" -> "Version 2" |>
            }
        ];
        { result, DirectoryQ @ FileNameJoin @ { root, "fresh-skill" } }
    ],
    { Failure[ "InstallAgentSkills::AgentSkillExists", _ ], False },
    { InstallAgentSkills::AgentSkillExists },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-PreflightNothingWritten@@Tests/AgentSkills.wlt:1148,1-1165,2"
]

VerificationTest[
    Module[ { root },
        root = skillTestDirectory[ ];
        writeTestFile[ FileNameJoin @ { root, "file-entry" }, "a plain file" ];
        {
            InstallAgentSkills[ File @ root, <| "Name" -> "file-entry", "Description" -> "d", "Body" -> "b" |> ],
            readTestFile @ FileNameJoin @ { root, "file-entry" },
            InstallAgentSkills[ File @ root, <| "Name" -> "file-entry", "Description" -> "d", "Body" -> "b" |>, OverwriteTarget -> True ],
            DirectoryQ @ FileNameJoin @ { root, "file-entry" },
            backupFiles @ root
        }
    ],
    {
        Failure[ "InstallAgentSkills::AgentSkillExists", _ ],
        "a plain file",
        Success[ "InstallAgentSkills", _ ],
        True,
        { }
    },
    { InstallAgentSkills::AgentSkillExists },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-FileEntry@@Tests/AgentSkills.wlt:1167,1-1189,2"
]

(* A link is replaced as a link: its target is never written through *)
ifSymlinks @ VerificationTest[
    Module[ { base, root, target },
        base = skillTestDirectory[ ];
        root = CreateDirectory @ FileNameJoin @ { base, "root" };
        target = makeTestSkill[ base, "link-skill", "Target body" ];
        symlink[ target, FileNameJoin @ { root, "link-skill" } ];
        {
            InstallAgentSkills[ File @ root, <| "Name" -> "link-skill", "Description" -> "d", "Body" -> "New body" |> ],
            InstallAgentSkills[ File @ root, <| "Name" -> "link-skill", "Description" -> "d", "Body" -> "New body" |>, OverwriteTarget -> True ],
            skillDirectoryState[ File @ root, "link-skill" ],
            StringContainsQ[ readTestFile @ FileNameJoin @ { root, "link-skill", "SKILL.md" }, "New body" ],
            StringContainsQ[ readTestFile @ FileNameJoin @ { target, "SKILL.md" }, "Target body" ],
            backupFiles @ root
        }
    ],
    {
        Failure[ "InstallAgentSkills::AgentSkillExists", _ ],
        Success[ "InstallAgentSkills", _ ],
        "Directory",
        True,
        True,
        { }
    },
    { InstallAgentSkills::AgentSkillExists },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-LinkEntry@@Tests/AgentSkills.wlt:1192,14-1218,2"
]

ifSymlinks @ VerificationTest[
    Module[ { base, root, target, copy },
        base = skillTestDirectory[ ];
        root = CreateDirectory @ FileNameJoin @ { base, "root" };
        target = makeTestSkill[ CreateDirectory @ FileNameJoin @ { base, "a" }, "same-link-skill" ];
        copy = makeTestSkill[ CreateDirectory @ FileNameJoin @ { base, "b" }, "same-link-skill" ];
        symlink[ target, FileNameJoin @ { root, "same-link-skill" } ];
        {
            (* a link to identical content is a no-op *)
            InstallAgentSkills[ File @ root, File @ copy ],
            (* the link resolves to the source directory itself *)
            InstallAgentSkills[ File @ root, File @ target ],
            skillDirectoryState[ File @ root, "same-link-skill" ]
        }
    ],
    { Success[ "InstallAgentSkills", _ ], Success[ "InstallAgentSkills", _ ], "Link" },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-LinkToIdentical@@Tests/AgentSkills.wlt:1220,14-1238,2"
]

ifSymlinks @ VerificationTest[
    Module[ { base, root },
        base = skillTestDirectory[ ];
        root = CreateDirectory @ FileNameJoin @ { base, "root" };
        symlink[ FileNameJoin @ { base, "nowhere" }, FileNameJoin @ { root, "dangling" } ];
        {
            InstallAgentSkills[ File @ root, <| "Name" -> "dangling", "Description" -> "d", "Body" -> "b" |> ],
            InstallAgentSkills[ File @ root, <| "Name" -> "dangling", "Description" -> "d", "Body" -> "b" |>, OverwriteTarget -> All ],
            skillDirectoryState[ File @ root, "dangling" ],
            backupFiles @ root
        }
    ],
    { Failure[ "InstallAgentSkills::AgentSkillExists", _ ], Success[ "InstallAgentSkills", _ ], "Directory", { } },
    { InstallAgentSkills::AgentSkillExists },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-DanglingEntry@@Tests/AgentSkills.wlt:1240,14-1256,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Source and Destination*)

(* Installing a skill directory into the root that already contains it is a no-op *)
VerificationTest[
    Module[ { root, dir, before },
        root = skillTestDirectory[ ];
        dir = makeTestSkill[ root, "in-place-skill" ];
        before = FileNames[ All, dir, Infinity ];
        { InstallAgentSkills[ File @ root, File @ dir ], FileNames[ All, dir, Infinity ] === before, backupFiles @ root }
    ],
    { Success[ "InstallAgentSkills", KeyValuePattern[ "Name" -> "in-place-skill" ] ], True, { } },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-SourceIsDestination@@Tests/AgentSkills.wlt:1263,1-1273,2"
]

VerificationTest[
    Module[ { dir },
        dir = makeTestSkill[ skillTestDirectory[ ], "nesting-skill" ];
        (* the destination would be inside the source *)
        InstallAgentSkills[ File @ FileNameJoin @ { dir, "nested-root" }, File @ dir ]
    ],
    Failure[ "InstallAgentSkills::InvalidAgentSkill", _ ],
    { InstallAgentSkills::InvalidAgentSkill },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-NestedSource@@Tests/AgentSkills.wlt:1275,1-1285,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Arguments*)
VerificationTest[
    Module[ { dir },
        dir = makeTestSkill[ skillTestDirectory[ ], "root-is-skill" ];
        InstallAgentSkills[ File @ dir, <| "Name" -> "x", "Description" -> "d", "Body" -> "b" |> ]
    ],
    Failure[ "InstallAgentSkills::InvalidSkillsDirectory", _ ],
    { InstallAgentSkills::InvalidSkillsDirectory },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-RootIsSkillDirectory@@Tests/AgentSkills.wlt:1290,1-1299,2"
]

VerificationTest[
    Module[ { file },
        file = writeTestFile[ FileNameJoin @ { skillTestDirectory[ ], "file.txt" }, "x" ];
        InstallAgentSkills[ File @ file, <| "Name" -> "x", "Description" -> "d", "Body" -> "b" |> ]
    ],
    Failure[ "InstallAgentSkills::InvalidSkillsDirectory", _ ],
    { InstallAgentSkills::InvalidSkillsDirectory },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-RootIsFile@@Tests/AgentSkills.wlt:1301,1-1310,2"
]

VerificationTest[
    InstallAgentSkills[ 123, <| "Name" -> "x", "Description" -> "d", "Body" -> "b" |> ],
    Failure[ "InstallAgentSkills::InvalidSkillsDirectory", _ ],
    { InstallAgentSkills::InvalidSkillsDirectory },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-InvalidTarget@@Tests/AgentSkills.wlt:1312,1-1318,2"
]

VerificationTest[
    InstallAgentSkills[ File @ skillTestDirectory[ ], 123 ],
    Failure[ "InstallAgentSkills::InvalidAgentSkill", _ ],
    { InstallAgentSkills::InvalidAgentSkill },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-InvalidSkill@@Tests/AgentSkills.wlt:1320,1-1326,2"
]

VerificationTest[
    Module[ { root },
        root = skillTestDirectory[ ];
        {
            InstallAgentSkills[
                File @ root,
                { <| "Name" -> "twice", "Description" -> "d", "Body" -> "1" |>, LLMSkill[ { "twice", "d" }, "2" ] }
            ],
            FileNames[ All, root ]
        }
    ],
    { Failure[ "InstallAgentSkills::DuplicateAgentSkillName", KeyValuePattern[ "MessageParameters" :> { "twice" } ] ], { } },
    { InstallAgentSkills::DuplicateAgentSkillName },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-DuplicateNames@@Tests/AgentSkills.wlt:1328,1-1343,2"
]

VerificationTest[
    InstallAgentSkills[ File @ skillTestDirectory[ ] ],
    _Failure,
    { InstallAgentSkills::InvalidArguments },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-InvalidArgumentCount@@Tests/AgentSkills.wlt:1345,1-1351,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Rollback*)

(* If a later skill fails to be written, the skills already written by this call are rolled back (created directories
   are removed, replaced ones are restored from their backups) *)
VerificationTest[
    Module[ { root, result },
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, <| "Name" -> "replaced-skill", "Description" -> "d", "Body" -> "Original" |> ];
        result = withFailureInjection[
            Wolfram`AgentTools`AgentSkills`Private`writeSkillFileContent,
            Wolfram`AgentTools`AgentSkills`Private`writeSkillFileContent[ t_String /; StringContainsQ[ t, "failing-skill" ], _ ],
            False,
            InstallAgentSkills[
                File @ root,
                {
                    <| "Name" -> "created-skill", "Description" -> "d", "Body" -> "Created" |>,
                    <| "Name" -> "replaced-skill", "Description" -> "d", "Body" -> "Replacement" |>,
                    <| "Name" -> "failing-skill", "Description" -> "d", "Body" -> "Fails" |>
                },
                OverwriteTarget -> True
            ]
        ];
        {
            result,
            Sort[ FileNameTake /@ FileNames[ All, root ] ],
            StringContainsQ[ readTestFile @ FileNameJoin @ { root, "replaced-skill", "SKILL.md" }, "Original" ],
            backupFiles @ root
        }
    ],
    {
        Failure[ "InstallAgentSkills::AgentSkillWriteFailed", KeyValuePattern[ "MessageParameters" :> { "failing-skill", _File } ] ],
        { "replaced-skill" },
        True,
        { }
    },
    { InstallAgentSkills::AgentSkillWriteFailed },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-Rollback@@Tests/AgentSkills.wlt:1359,1-1393,2"
]

(* If the existing entry can't be moved out of the way (e.g. a file in use on Windows), nothing is changed *)
VerificationTest[
    Module[ { root, result },
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, <| "Name" -> "locked-skill", "Description" -> "d", "Body" -> "Original" |> ];
        result = withFailureInjection[
            Wolfram`AgentTools`AgentSkills`Private`moveSkillEntry,
            Wolfram`AgentTools`AgentSkills`Private`moveSkillEntry[ _, _, _ ],
            False,
            InstallAgentSkills[ File @ root, <| "Name" -> "locked-skill", "Description" -> "d", "Body" -> "New" |>, OverwriteTarget -> True ]
        ];
        { result, StringContainsQ[ readTestFile @ FileNameJoin @ { root, "locked-skill", "SKILL.md" }, "Original" ] }
    ],
    { Failure[ "InstallAgentSkills::AgentSkillRemoveFailed", _ ], True },
    { InstallAgentSkills::AgentSkillRemoveFailed },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-MoveFails@@Tests/AgentSkills.wlt:1396,1-1412,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Unreadable Files and Write Errors*)

(* A source with a file that can't be read fails before anything is written *)
ifPermissions @ VerificationTest[
    Module[ { src, file, dest },
        src  = makeTestSkill[ skillTestDirectory[ ], "unreadable-source", "Body", <| "secret.txt" -> "secret" |> ];
        file = FileNameJoin @ { src, "secret.txt" };
        dest = skillTestDirectory[ ];
        WithCleanup[
            chmod[ "000", file ];
            { InstallAgentSkills[ File @ dest, File @ src ], FileNames[ All, dest ] },
            chmod[ "644", file ]
        ]
    ],
    {
        Failure[ "InstallAgentSkills::AgentSkillUnreadable", _? (MatchQ[ #[ "MessageParameters" ], { File[ _String? (StringEndsQ[ "secret.txt" ]) ] } ] &) ],
        { }
    },
    { InstallAgentSkills::AgentSkillUnreadable },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-UnreadableSource@@Tests/AgentSkills.wlt:1419,17-1437,2"
]

(* An existing directory with a file that can't be read is different content: a conflict, or replaced when
   overwriting *)
ifPermissions @ VerificationTest[
    Module[ { src, dest, file },
        src  = makeTestSkill[ skillTestDirectory[ ], "unreadable-destination" ];
        dest = isolatedSkillsRoot[ ];
        InstallAgentSkills[ File @ dest, File @ src ];
        file = writeTestFile[ FileNameJoin @ { dest, "unreadable-destination", "extra.txt" }, "extra" ];
        WithCleanup[
            chmod[ "000", file ];
            {
                InstallAgentSkills[ File @ dest, File @ src ],
                InstallAgentSkills[ File @ dest, File @ src, OverwriteTarget -> True ],
                FileExistsQ @ file,
                FileExistsQ @ FileNameJoin @ { dest, "unreadable-destination", "SKILL.md" },
                backupFiles @ dest
            },
            restoreWritable @ DirectoryName @ dest
        ]
    ],
    {
        Failure[ "InstallAgentSkills::AgentSkillExists", _ ],
        Success[ "InstallAgentSkills", _ ],
        False,
        True,
        { }
    },
    { InstallAgentSkills::AgentSkillExists },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-UnreadableDestination@@Tests/AgentSkills.wlt:1441,17-1469,2"
]

(* Write errors are detected (a full device accepts the write and fails when the data is flushed) *)
conditionalTest[ $OperatingSystem =!= "Windows" && FileExistsQ[ "/dev/full" ] ] @ VerificationTest[
    Module[ { dir },
        dir = skillTestDirectory[ ];
        symlink[ "/dev/full", FileNameJoin @ { dir, "SKILL.md" } ];
        {
            writeBytes[ "/dev/full", StringToByteArray[ "content" ] ],
            writeSkillFile[ dir, "SKILL.md", "---\nname: full\n---\n" ],
            writeBytes[ FileNameJoin @ { dir, "written.txt" }, StringToByteArray[ "content" ] ],
            readTestFile @ FileNameJoin @ { dir, "written.txt" },
            writeBytes[ FileNameJoin @ { dir, "empty.txt" }, ByteArray[ { } ] ],
            FileByteCount @ FileNameJoin @ { dir, "empty.txt" }
        }
    ],
    { False, False, True, "content", True, 0 },
    SameTest -> SameQ,
    TestID   -> "WriteBytes-WriteErrors@@Tests/AgentSkills.wlt:1472,83-1488,2"
]

(* A replaced directory whose backup can't be deleted completely (e.g. a read-only subdirectory) is reported *)
ifPermissions @ VerificationTest[
    Module[ { root, src, scripts, result },
        root = isolatedSkillsRoot[ ];
        src  = makeTestSkill[ skillTestDirectory[ ], "stuck-replace", "Version 1", <| "scripts/run.sh" -> "echo 1" |> ];
        InstallAgentSkills[ File @ root, File @ src ];
        scripts = FileNameJoin @ { root, "stuck-replace", "scripts" };
        WithCleanup[
            chmod[ "555", scripts ];
            makeTestSkill[ DirectoryName @ src, "stuck-replace", "Version 2", <| "scripts/run.sh" -> "echo 2" |> ];
            result = InstallAgentSkills[ File @ root, File @ src, OverwriteTarget -> True ];
            {
                result,
                StringContainsQ[ readTestFile @ FileNameJoin @ { root, "stuck-replace", "SKILL.md" }, "Version 2" ],
                Length @ backupFiles @ root
            },
            restoreWritable @ DirectoryName @ root
        ]
    ],
    { Success[ "InstallAgentSkills", _ ], True, 1 },
    { InstallAgentSkills::AgentSkillBackupNotRemoved },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-BackupNotRemoved@@Tests/AgentSkills.wlt:1491,17-1513,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*UninstallAgentSkills*)
VerificationTest[
    Module[ { root, result },
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, <| "Name" -> "remove-me", "Description" -> "d", "Body" -> "b" |> ];
        (* modifications don't prevent removal; junk goes with the directory *)
        writeTestFile[ FileNameJoin @ { root, "remove-me", "user.txt" }, "user" ];
        writeTestFile[ FileNameJoin @ { root, "remove-me", ".DS_Store" }, "junk" ];
        result = UninstallAgentSkills[ File @ root, "remove-me" ];
        { result, FileNames[ All, root ], DirectoryQ @ root, backupFiles @ root }
    ],
    {
        Success[
            "UninstallAgentSkills",
            KeyValuePattern @ {
                "MessageTemplate"   :> AgentTools::UninstallAgentSkill,
                "MessageParameters" -> { "remove-me" },
                "Name"              -> "remove-me",
                "Location"          -> File[ _String ],
                "ClientName"        -> None
            }
        ],
        { },
        True,
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "UninstallAgentSkills-Single@@Tests/AgentSkills.wlt:1518,1-1545,2"
]

VerificationTest[
    Module[ { root, dir },
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, { LLMSkill[ { "skill-a", "d" }, "b" ], LLMSkill[ { "skill-b", "d" }, "b" ], LLMSkill[ { "skill-c", "d" }, "b" ] } ];
        dir = makeTestSkill[ skillTestDirectory[ ], "skill-c" ];
        {
            UninstallAgentSkills[ File @ root, { "skill-a", "not-installed" } ],
            (* names are taken from qualified paclet names, LLMSkill objects, and skill directories *)
            UninstallAgentSkills[ File @ root, { "Pub/Paclet/skill-b", File @ dir } ],
            FileNames[ All, root ]
        }
    ],
    {
        { Success[ "UninstallAgentSkills", KeyValuePattern[ "Name" -> "skill-a" ] ], Missing[ "NotInstalled", File[ _String ] ] },
        { Success[ "UninstallAgentSkills", KeyValuePattern[ "Name" -> "skill-b" ] ], Success[ "UninstallAgentSkills", KeyValuePattern[ "Name" -> "skill-c" ] ] },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "UninstallAgentSkills-List@@Tests/AgentSkills.wlt:1547,1-1566,2"
]

VerificationTest[
    Module[ { root },
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, LLMSkill[ { "llm-uninstall", "d" }, "b" ] ];
        { UninstallAgentSkills[ File @ root, LLMSkill[ { "llm-uninstall", "d" }, "other body" ] ], FileNames[ All, root ] }
    ],
    { Success[ "UninstallAgentSkills", KeyValuePattern[ "Name" -> "llm-uninstall" ] ], { } },
    SameTest -> MatchQ,
    TestID   -> "UninstallAgentSkills-LLMSkill@@Tests/AgentSkills.wlt:1568,1-1577,2"
]

VerificationTest[
    UninstallAgentSkills[ File @ skillTestDirectory[ ], "never-installed" ],
    Missing[ "NotInstalled", File[ _String? (StringEndsQ[ "never-installed" ]) ] ],
    SameTest -> MatchQ,
    TestID   -> "UninstallAgentSkills-NotInstalled@@Tests/AgentSkills.wlt:1579,1-1584,2"
]

(* Names are validated before any path is built, so the root (or anything outside it) is never removed *)
VerificationTest[
    Module[ { base, root, outside, results },
        base = skillTestDirectory[ ];
        root = FileNameJoin @ { base, "root" };
        InstallAgentSkills[ File @ root, LLMSkill[ { "kept-skill", "d" }, "b" ] ];
        outside = makeTestSkill[ base, "outside-skill" ];
        results = Quiet[
            UninstallAgentSkills[ File @ root, # ] & /@ { "", ".", "..", "../outside-skill", "a/b/c/d", "Bad Name", "-x" },
            UninstallAgentSkills::InvalidAgentSkillName
        ];
        {
            results,
            (* one invalid name fails the whole call before anything is removed *)
            Quiet[ UninstallAgentSkills[ File @ root, { "kept-skill", ".." } ], UninstallAgentSkills::InvalidAgentSkillName ],
            DirectoryQ @ root,
            DirectoryQ @ FileNameJoin @ { root, "kept-skill" },
            DirectoryQ @ outside
        }
    ],
    {
        {
            Failure[ "UninstallAgentSkills::InvalidAgentSkillName", _ ],
            Failure[ "UninstallAgentSkills::InvalidAgentSkillName", _ ],
            Failure[ "UninstallAgentSkills::InvalidAgentSkillName", _ ],
            (* a qualified name: its item name is used, which is not installed in the root *)
            Missing[ "NotInstalled", File[ _String? (StringEndsQ[ FileNameJoin @ { "root", "outside-skill" } ]) ] ],
            Failure[ "UninstallAgentSkills::InvalidAgentSkillName", _ ],
            Failure[ "UninstallAgentSkills::InvalidAgentSkillName", _ ],
            Failure[ "UninstallAgentSkills::InvalidAgentSkillName", _ ]
        },
        Failure[ "UninstallAgentSkills::InvalidAgentSkillName", KeyValuePattern[ "MessageParameters" :> { ".." } ] ],
        True,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "UninstallAgentSkills-InvalidNames@@Tests/AgentSkills.wlt:1587,1-1624,2"
]

VerificationTest[
    Module[ { root },
        root = skillTestDirectory[ ];
        { UninstallAgentSkills[ File @ root, ".." ], DirectoryQ @ root }
    ],
    { Failure[ "UninstallAgentSkills::InvalidAgentSkillName", KeyValuePattern[ "MessageParameters" :> { ".." } ] ], True },
    { UninstallAgentSkills::InvalidAgentSkillName },
    SameTest -> MatchQ,
    TestID   -> "UninstallAgentSkills-InvalidName-Message@@Tests/AgentSkills.wlt:1626,1-1635,2"
]

(* Only directories that contain SKILL.md (or links to one) are removed *)
VerificationTest[
    Module[ { root },
        root = skillTestDirectory[ ];
        writeTestFile[ FileNameJoin @ { root, "not-a-skill", "README.md" }, "x" ];
        writeTestFile[ FileNameJoin @ { root, "plain-file" }, "x" ];
        {
            UninstallAgentSkills[ File @ root, "not-a-skill" ],
            UninstallAgentSkills[ File @ root, "plain-file" ],
            FileExistsQ @ FileNameJoin @ { root, "not-a-skill", "README.md" },
            FileExistsQ @ FileNameJoin @ { root, "plain-file" }
        }
    ],
    { Missing[ "NotInstalled", _File ], Missing[ "NotInstalled", _File ], True, True },
    SameTest -> MatchQ,
    TestID   -> "UninstallAgentSkills-NotSkillDirectory@@Tests/AgentSkills.wlt:1638,1-1653,2"
]

ifSymlinks @ VerificationTest[
    Module[ { base, root, target, other },
        base = skillTestDirectory[ ];
        root = CreateDirectory @ FileNameJoin @ { base, "root" };
        target = makeTestSkill[ base, "linked-target" ];
        other = CreateDirectory @ FileNameJoin @ { base, "not-a-skill" };
        symlink[ target, FileNameJoin @ { root, "linked-skill" } ];
        symlink[ other, FileNameJoin @ { root, "linked-other" } ];
        symlink[ FileNameJoin @ { base, "nowhere" }, FileNameJoin @ { root, "dangling" } ];
        {
            UninstallAgentSkills[ File @ root, { "linked-skill", "linked-other", "dangling" } ],
            Sort[ FileNameTake /@ FileNames[ All, root ] ],
            FileExistsQ @ FileNameJoin @ { target, "SKILL.md" }
        }
    ],
    {
        { Success[ "UninstallAgentSkills", _ ], Missing[ "NotInstalled", _ ], Missing[ "NotInstalled", _ ] },
        { "dangling", "linked-other" },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "UninstallAgentSkills-Links@@Tests/AgentSkills.wlt:1655,14-1677,2"
]

VerificationTest[
    Module[ { root, result },
        root = skillTestDirectory[ ];
        InstallAgentSkills[ File @ root, LLMSkill[ { "busy-skill", "d" }, "b" ] ];
        result = withFailureInjection[
            Wolfram`AgentTools`AgentSkills`Private`moveSkillEntry,
            Wolfram`AgentTools`AgentSkills`Private`moveSkillEntry[ _, _, _ ],
            False,
            UninstallAgentSkills[ File @ root, "busy-skill" ]
        ];
        { result, DirectoryQ @ FileNameJoin @ { root, "busy-skill" } }
    ],
    { Failure[ "UninstallAgentSkills::AgentSkillRemoveFailed", _ ], True },
    { UninstallAgentSkills::AgentSkillRemoveFailed },
    SameTest -> MatchQ,
    TestID   -> "UninstallAgentSkills-RemoveFails@@Tests/AgentSkills.wlt:1679,1-1695,2"
]

VerificationTest[
    UninstallAgentSkills[ 123, "x" ],
    Failure[ "UninstallAgentSkills::InvalidSkillsDirectory", _ ],
    { UninstallAgentSkills::InvalidSkillsDirectory },
    SameTest -> MatchQ,
    TestID   -> "UninstallAgentSkills-InvalidTarget@@Tests/AgentSkills.wlt:1697,1-1703,2"
]

(* The skill has left the root, but its backup can't be deleted completely (a read-only subdirectory): the leftover
   copy is reported instead of being left behind silently *)
ifPermissions @ VerificationTest[
    Module[ { root, dir },
        root = isolatedSkillsRoot[ ];
        dir  = makeTestSkill[ root, "stuck-backup", "Body", <| "scripts/a.sh" -> "echo a" |> ];
        WithCleanup[
            chmod[ "555", FileNameJoin @ { dir, "scripts" } ];
            {
                UninstallAgentSkills[ File @ root, "stuck-backup" ],
                DirectoryQ @ dir,
                FileExistsQ @ FileNameJoin @ { First @ backupFiles @ root, "scripts", "a.sh" }
            },
            restoreWritable @ DirectoryName @ root
        ]
    ],
    { Success[ "UninstallAgentSkills", _ ], False, True },
    {
        UninstallAgentSkills::AgentSkillBackupNotRemoved
    },
    SameTest -> MatchQ,
    TestID   -> "UninstallAgentSkills-BackupNotRemoved@@Tests/AgentSkills.wlt:1707,17-1727,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skill Registry*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Storage*)
VerificationTest[
    withTemporaryRoot @ {
        StringStartsQ[ Wolfram`AgentTools`Common`$skillRegistryPath, Wolfram`AgentTools`Common`$rootPath ],
        Wolfram`AgentTools`Common`$skillRegistryPath === FileNameJoin @ { Wolfram`AgentTools`Common`$deploymentsPath, ".SkillRegistry" }
    },
    { True, True },
    SameTest -> SameQ,
    TestID   -> "SkillRegistry-Location@@Tests/AgentSkills.wlt:1736,1-1744,2"
]

VerificationTest[
    Module[ { root },
        root = File @ skillTestDirectory[ ];
        {
            StringMatchQ[ skillRegistryKey[ root, "a-skill" ], Repeated[ HexadecimalCharacter, { 64 } ] ],
            skillRegistryKey[ root, "a-skill" ] === Hash[ canonicalPathKey @ root <> "/a-skill", "SHA256", "HexString" ],
            (* computed before anything is created, and unchanged afterwards *)
            skillRegistryKey[ File @ FileNameJoin @ { First @ root, "new" }, "a-skill" ] === (
                CreateDirectory @ FileNameJoin @ { First @ root, "new" };
                skillRegistryKey[ File @ FileNameJoin @ { First @ root, "new" }, "a-skill" ]
            )
        }
    ],
    { True, True, True },
    SameTest -> SameQ,
    TestID   -> "SkillRegistryKey@@Tests/AgentSkills.wlt:1746,1-1762,2"
]

VerificationTest[
    withTemporaryRoot @ Module[ { key, entry, missing, written, read, corrupt },
        key = skillRegistryKey[ File @ skillTestDirectory[ ], "entry-skill" ];
        entry = <| "RegistryKey" -> key, "Name" -> "entry-skill", "References" -> { "u" } |>;
        missing = readSkillRegistryEntry @ key;
        written = writeSkillRegistryEntry @ entry;
        read = readSkillRegistryEntry @ key;
        deleteSkillRegistryEntry @ key;
        Export[ FileNameJoin @ { Wolfram`AgentTools`Common`$skillRegistryPath, key <> ".wxf" }, "not wxf", "Text" ];
        corrupt = readSkillRegistryEntry @ key;
        {
            missing,
            written === File @ FileNameJoin @ { Wolfram`AgentTools`Common`$skillRegistryPath, key <> ".wxf" },
            read === entry,
            corrupt,
            readSkillRegistryEntry[ "../not-a-key" ]
        }
    ],
    { Missing[ "NotFound" ], True, True, Missing[ "Invalid", _File ], Missing[ "NotFound" ] },
    SameTest -> MatchQ,
    TestID   -> "SkillRegistry-ReadWriteDelete@@Tests/AgentSkills.wlt:1764,1-1785,2"
]

(* A registry entry that doesn't read back (e.g. truncated by a full disk although the write reported success) fails
   the write, so the files of that skill are rolled back *)
VerificationTest[
    withSkillTestRoot @ Module[ { root, result },
        root = testSkillsRoot[ ];
        result = withFailureInjection[
            Wolfram`AgentTools`Common`writeWXFFile,
            Wolfram`AgentTools`Common`writeWXFFile[ file_String, KeyValuePattern[ "Name" -> "truncated-entry" ] ],
            writeTestFile[ file, "" ],
            catchTop @ applySkillInstallPlan[
                planSkillInstall[ { genSource[ "truncated-entry", "Body" ] }, root, "uuid-1", { }, False ],
                "uuid-1"
            ]
        ];
        { result, DirectoryQ @ FileNameJoin @ { First @ root, "truncated-entry" } }
    ],
    { Failure[ "AgentTools::Internal", _ ], False },
    { General::AgentToolsInternal },
    SameTest -> MatchQ,
    TestID   -> "SkillRegistry-WriteReadBack@@Tests/AgentSkills.wlt:1789,1-1807,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deploymentUUIDExistsQ*)
VerificationTest[
    withTemporaryRoot @ Module[ { results },
        results = <| |>;
        results[ "None" ] = deploymentUUIDExistsQ[ "uuid-a" ];
        fakeDeployment[ "uuid-a" ];
        fakeDeployment[ "uuid-b", "Cursor" ];
        results[ "ClaudeCode" ] = deploymentUUIDExistsQ[ "uuid-a" ];
        results[ "OtherClient" ] = deploymentUUIDExistsQ[ "uuid-b" ];
        (* a directory without Deployment.wxf (a crashed write) is stale *)
        CreateDirectory @ FileNameJoin @ { Wolfram`AgentTools`Common`$deploymentsPath, "ClaudeCode", "uuid-c" };
        results[ "NoRecord" ] = deploymentUUIDExistsQ[ "uuid-c" ];
        (* a record that fails to parse is not stale *)
        Export[ FileNameJoin @ { Wolfram`AgentTools`Common`$deploymentsPath, "ClaudeCode", "uuid-c", "Deployment.wxf" }, "garbage", "Text" ];
        results[ "Unparseable" ] = deploymentUUIDExistsQ[ "uuid-c" ];
        results[ "Invalid" ] = deploymentUUIDExistsQ /@ { "../ClaudeCode/uuid-a", "", None };
        results
    ],
    <|
        "None"        -> False,
        "ClaudeCode"  -> True,
        "OtherClient" -> True,
        "NoRecord"    -> False,
        "Unparseable" -> True,
        "Invalid"     -> { False, False, False }
    |>,
    SameTest -> SameQ,
    TestID   -> "DeploymentUUIDExistsQ@@Tests/AgentSkills.wlt:1812,1-1839,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Install Decisions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Missing*)
VerificationTest[
    withSkillTestRoot @ Module[ { root, source, plan, before, result, entry },
        root = testSkillsRoot[ ];
        source = genSource[ "create-skill", "Body" ];
        plan = planSkillInstall[ { source }, root, "uuid-1", { }, False ];
        (* planning writes nothing *)
        before = { DirectoryQ @ First @ root, DirectoryQ @ Wolfram`AgentTools`Common`$skillRegistryPath };
        result = applySkillInstallPlan[ plan, "uuid-1" ];
        entry = readSkillRegistryEntry @ First[ result[ "Installed" ] ][ "RegistryKey" ];
        {
            plan[ "Root" ] === root,
            plan[ "Conflicts" ],
            KeyTake[ First @ plan[ "Decisions" ], { "Name", "State", "Action" } ],
            before,
            result[ "Installed" ],
            result[ "Messages" ],
            result[ "Finalize" ],
            KeyTake[ entry, { "Name", "Identifier", "External", "References" } ],
            entry[ "Hashes" ] === source[ "Manifest" ],
            entry[ "Directory" ] === File @ FileNameJoin @ { First @ root, "create-skill" },
            compareSkillManifest[ entry[ "Directory" ], entry[ "Hashes" ] ]
        }
    ],
    {
        True,
        { },
        <| "Name" -> "create-skill", "State" -> "Missing", "Action" -> "Create" |>,
        { False, False },
        {
            <|
                "Name"        -> "create-skill",
                "Directory"   -> File[ _String ],
                "RegistryKey" -> _String,
                "Identifier"  -> "AgentToolsObject:Test/create-skill",
                "Version"     -> Missing[ ]
            |>
        },
        { },
        { },
        <| "Name" -> "create-skill", "Identifier" -> "AgentToolsObject:Test/create-skill", "External" -> False, "References" -> { "uuid-1" } |>,
        True,
        True,
        "Unmodified"
    },
    SameTest -> MatchQ,
    TestID   -> "InstallDecision-Missing-Create@@Tests/AgentSkills.wlt:1848,1-1894,2"
]

(* The directory was deleted by hand: it is created again and the live references are kept *)
VerificationTest[
    withSkillTestRoot @ Module[ { root, source, key },
        root = testSkillsRoot[ ];
        source = genSource[ "recreate-skill", "Body" ];
        deploySkills[ { source }, root, "uuid-1" ];
        DeleteDirectory[ FileNameJoin @ { First @ root, "recreate-skill" }, DeleteContents -> True ];
        key = skillRegistryKey[ root, "recreate-skill" ];
        {
            planAction[ { source }, root, "uuid-2", { }, False ],
            deploySkills[ { source }, root, "uuid-2" ][ "Installed" ][[ 1, "RegistryKey" ]] === key,
            readSkillRegistryEntry[ key ][ "References" ],
            DirectoryQ @ FileNameJoin @ { First @ root, "recreate-skill" }
        }
    ],
    { "Create", True, { "uuid-1", "uuid-2" }, True },
    SameTest -> SameQ,
    TestID   -> "InstallDecision-Missing-KeepsReferences@@Tests/AgentSkills.wlt:1897,1-1914,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Links, Dangling Links, and Files*)
ifSymlinks @ VerificationTest[
    withSkillTestRoot @ Module[ { root, base, target, source, result },
        root = testSkillsRoot[ ];
        base = skillTestDirectory[ ];
        target = makeTestSkill[ base, "link-decision", "Target" ];
        CreateDirectory @ First @ root;
        symlink[ target, FileNameJoin @ { First @ root, "link-decision" } ];
        source = genSource[ "link-decision", "Body" ];
        {
            planAction[ { source }, root, "uuid-1", { }, False ],
            planAction[ { source }, root, "uuid-1", { }, True ],
            planAction[ { source }, root, "uuid-1", { }, All ],
            result = deploySkills[ { source }, root, "uuid-1", { }, All ];
            skillDirectoryState[ root, "link-decision" ],
            StringContainsQ[ readTestFile @ FileNameJoin @ { target, "SKILL.md" }, "Target" ],
            readSkillRegistryEntry[ skillRegistryKey[ root, "link-decision" ] ][ "External" ],
            backupFiles @ First @ root
        }
    ],
    {
        { "Conflict", "AgentSkillExists", { "link-decision", File[ _String ], All } },
        { "Conflict", "AgentSkillExists", _ },
        "Replace",
        "Directory",
        True,
        False,
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "InstallDecision-Link@@Tests/AgentSkills.wlt:1919,14-1949,2"
]

ifSymlinks @ VerificationTest[
    withSkillTestRoot @ Module[ { root, source },
        root = testSkillsRoot[ ];
        CreateDirectory @ First @ root;
        symlink[ FileNameJoin @ { $HomeDirectory, "nowhere" }, FileNameJoin @ { First @ root, "dangling-decision" } ];
        writeTestFile[ FileNameJoin @ { First @ root, "file-decision" }, "file" ];
        source = { genSource[ "dangling-decision", "Body" ], genSource[ "file-decision", "Body" ] };
        {
            Lookup[ planSkillInstall[ source, root, "uuid-1", { }, True ][ "Conflicts" ], "Tag" ],
            Lookup[ planSkillInstall[ source, root, "uuid-1", { }, All ][ "Decisions" ], "Action" ],
            deploySkills[ source, root, "uuid-1", { }, All ][ "Installed" ][[ All, "Name" ]],
            skillDirectoryState[ root, # ] & /@ { "dangling-decision", "file-decision" }
        }
    ],
    {
        { "AgentSkillExists", "AgentSkillExists" },
        { "Replace", "Replace" },
        { "dangling-decision", "file-decision" },
        { "Directory", "Directory" }
    },
    SameTest -> SameQ,
    TestID   -> "InstallDecision-DanglingAndFile@@Tests/AgentSkills.wlt:1951,14-1973,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Directories Written by Deployments*)
VerificationTest[
    withSkillTestRoot @ Module[ { root, source },
        root = testSkillsRoot[ ];
        source = genSource[ "shared-skill", "Body" ];
        deploySkills[ { source }, root, "uuid-1" ];
        {
            planAction[ { source }, root, "uuid-2", { }, False ],
            deploySkills[ { source }, root, "uuid-2" ][ "Undo" ] // Length,
            readSkillRegistryEntry[ skillRegistryKey[ root, "shared-skill" ] ][ "References" ],
            backupFiles @ First @ root
        }
    ],
    { "AddReference", 1, { "uuid-1", "uuid-2" }, { } },
    SameTest -> SameQ,
    TestID   -> "InstallDecision-SameContent-AddReference@@Tests/AgentSkills.wlt:1978,1-1993,2"
]

(* A directory used only by the deployments being replaced is owned by the replacement: no force needed. The replaced
   deployment keeps its reference until it is released (after the new deployment record exists). *)
VerificationTest[
    withSkillTestRoot @ Module[ { root, installed, entry },
        root = testSkillsRoot[ ];
        installed = First @ deploySkills[ { genSource[ "owned-skill", "Version 1", "AgentToolsObject:Old/owned-skill" ] }, root, "uuid-1" ][ "Installed" ];
        {
            planAction[ { genSource[ "owned-skill", "Version 2", "AgentToolsObject:New/owned-skill" ] }, root, "uuid-2", { }, False ],
            planAction[ { genSource[ "owned-skill", "Version 2", "AgentToolsObject:New/owned-skill" ] }, root, "uuid-2", { "uuid-1" }, False ],
            deploySkills[ { genSource[ "owned-skill", "Version 2", "AgentToolsObject:New/owned-skill" ] }, root, "uuid-2", { "uuid-1" }, False ];
            entry = readSkillRegistryEntry @ skillRegistryKey[ root, "owned-skill" ];
            entry[ "Identifier" ],
            entry[ "References" ],
            StringContainsQ[ readTestFile @ FileNameJoin @ { First @ root, "owned-skill", "SKILL.md" }, "Version 2" ],
            releaseSkillReference[ installed, "uuid-1" ][ "Result" ],
            readSkillRegistryEntry[ skillRegistryKey[ root, "owned-skill" ] ][ "References" ]
        }
    ],
    {
        { "Conflict", "AgentSkillConflict", { "owned-skill", File[ _String ] } },
        "Replace",
        "AgentToolsObject:New/owned-skill",
        { "uuid-1", "uuid-2" },
        True,
        "InUse",
        { "uuid-2" }
    },
    SameTest -> MatchQ,
    TestID   -> "InstallDecision-OwnedByReplacement@@Tests/AgentSkills.wlt:1997,1-2024,2"
]

(* If a replacing deploy is interrupted after its skills were applied but before its deployment record was written
   (e.g. the kernel was killed), the replaced deployment still references its skills, so the sweep keeps them *)
VerificationTest[
    withSkillTestRoot @ Module[ { root, installed, keys, result },
        root = testSkillsRoot[ ];
        installed = deploySkills[
            { genSource[ "interrupted-shared", "Body" ], genSource[ "interrupted-owned", "Version 1", "AgentToolsObject:Old/interrupted-owned" ] },
            root,
            "uuid-1"
        ][ "Installed" ];
        keys = Lookup[ installed, "RegistryKey" ];
        result = applySkillInstallPlan[
            planSkillInstall[
                { genSource[ "interrupted-shared", "Body" ], genSource[ "interrupted-owned", "Version 2", "AgentToolsObject:New/interrupted-owned" ] },
                root,
                "uuid-2",
                { "uuid-1" },
                False
            ],
            "uuid-2"
        ];
        Scan[ #[ ] &, result[ "Finalize" ] ];
        {
            readSkillRegistryEntry[ # ][ "References" ] & /@ keys,
            sweepSkillRegistry[ ],
            readSkillRegistryEntry[ # ][ "References" ] & /@ keys,
            DirectoryQ @ FileNameJoin @ { First @ root, # } & /@ { "interrupted-shared", "interrupted-owned" }
        }
    ],
    {
        { { "uuid-1", "uuid-2" }, { "uuid-1", "uuid-2" } },
        { },
        { { "uuid-1" }, { "uuid-1" } },
        { True, True }
    },
    SameTest -> SameQ,
    TestID   -> "InstallDecision-ReplacedReferencesKept@@Tests/AgentSkills.wlt:2028,1-2063,2"
]

(* Stale references don't keep a directory alive *)
VerificationTest[
    withSkillTestRoot @ Module[ { root },
        root = testSkillsRoot[ ];
        deploySkills[ { genSource[ "stale-skill", "Version 1" ] }, root, "uuid-1" ];
        removeFakeDeployment[ "uuid-1" ];
        {
            planAction[ { genSource[ "stale-skill", "Version 2", "AgentToolsObject:Other/stale-skill" ] }, root, "uuid-2", { }, False ],
            (* planning prunes in memory only *)
            readSkillRegistryEntry[ skillRegistryKey[ root, "stale-skill" ] ][ "References" ]
        }
    ],
    { "Replace", { "uuid-1" } },
    SameTest -> SameQ,
    TestID   -> "InstallDecision-StaleReferences@@Tests/AgentSkills.wlt:2066,1-2080,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { root, result, entry },
        root = testSkillsRoot[ ];
        deploySkills[ { pacletSource[ "versioned-skill", "Version 2", "2.0.0" ] }, root, "uuid-1" ];
        result = deploySkills[ { pacletSource[ "versioned-skill", "Version 1", "1.0.0" ] }, root, "uuid-2" ];
        entry = readSkillRegistryEntry @ skillRegistryKey[ root, "versioned-skill" ];
        {
            planAction[ { pacletSource[ "versioned-skill", "Version 1", "1.0.0" ] }, root, "uuid-3", { }, False ],
            result[ "Messages" ],
            result[ "Installed" ][[ 1, "Version" ]],
            entry[ "Version" ],
            entry[ "References" ],
            StringContainsQ[ readTestFile @ FileNameJoin @ { First @ root, "versioned-skill", "SKILL.md" }, "Version 2" ]
        }
    ],
    {
        "KeepNewer",
        {
            <|
                "Tag"        -> "AgentSkillNewerVersionKept",
                "Parameters" -> { "versioned-skill", File[ _String ], "2.0.0", "1.0.0" }
            |>
        },
        "2.0.0",
        "2.0.0",
        { "uuid-1", "uuid-2" },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "InstallDecision-KeepNewerVersion@@Tests/AgentSkills.wlt:2082,1-2112,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { root, entry },
        root = testSkillsRoot[ ];
        deploySkills[ { pacletSource[ "upgrade-skill", "Version 1", "1.0.0" ] }, root, "uuid-1" ];
        {
            planAction[ { pacletSource[ "upgrade-skill", "Version 2", "1.10.0" ] }, root, "uuid-2", { }, False ],
            planAction[ { pacletSource[ "upgrade-skill", "Version 2", "1.10.0" ] }, root, "uuid-2", { }, True ],
            deploySkills[ { pacletSource[ "upgrade-skill", "Version 2", "1.10.0" ] }, root, "uuid-2", { }, True ];
            entry = readSkillRegistryEntry @ skillRegistryKey[ root, "upgrade-skill" ];
            KeyTake[ entry, { "Identifier", "Version", "References" } ],
            StringContainsQ[ readTestFile @ FileNameJoin @ { First @ root, "upgrade-skill", "SKILL.md" }, "Version 2" ],
            backupFiles @ First @ root
        }
    ],
    {
        { "Conflict", "AgentSkillUpdate", { "upgrade-skill", File[ _String ] } },
        "Replace",
        <| "Identifier" -> "Pub/TestPaclet/upgrade-skill", "Version" -> "1.10.0", "References" -> { "uuid-1", "uuid-2" } |>,
        True,
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "InstallDecision-Upgrade@@Tests/AgentSkills.wlt:2114,1-2137,2"
]

(* Redeploying an edited in-memory skill of the same bundle is an upgrade of the same source *)
VerificationTest[
    withSkillTestRoot @ Module[ { root },
        root = testSkillsRoot[ ];
        deploySkills[ { genSource[ "edited-skill", "Version 1" ] }, root, "uuid-1" ];
        fakeDeployment[ "uuid-other" ];
        writeSkillRegistryEntry @ <|
            readSkillRegistryEntry @ skillRegistryKey[ root, "edited-skill" ],
            "References" -> { "uuid-1", "uuid-other" }
        |>;
        {
            planAction[ { genSource[ "edited-skill", "Version 2" ] }, root, "uuid-2", { "uuid-1" }, False ],
            planAction[ { genSource[ "edited-skill", "Version 2" ] }, root, "uuid-2", { "uuid-1" }, True ]
        }
    ],
    { { "Conflict", "AgentSkillUpdate", _ }, "Replace" },
    SameTest -> MatchQ,
    TestID   -> "InstallDecision-EditedInMemorySkill@@Tests/AgentSkills.wlt:2140,1-2157,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { root, entry },
        root = testSkillsRoot[ ];
        deploySkills[ { genSource[ "contested-skill", "Mine", "AgentToolsObject:A/contested-skill" ] }, root, "uuid-1" ];
        {
            planAction[ { genSource[ "contested-skill", "Theirs", "AgentToolsObject:B/contested-skill" ] }, root, "uuid-2", { }, False ],
            planAction[ { genSource[ "contested-skill", "Theirs", "AgentToolsObject:B/contested-skill" ] }, root, "uuid-2", { }, True ],
            planAction[ { genSource[ "contested-skill", "Theirs", None ] }, root, "uuid-2", { }, True ],
            planAction[ { genSource[ "contested-skill", "Theirs", "AgentToolsObject:B/contested-skill" ] }, root, "uuid-2", { }, All ],
            deploySkills[ { genSource[ "contested-skill", "Theirs", "AgentToolsObject:B/contested-skill" ] }, root, "uuid-2", { }, All ];
            entry = readSkillRegistryEntry @ skillRegistryKey[ root, "contested-skill" ];
            KeyTake[ entry, { "Identifier", "References", "External" } ]
        }
    ],
    {
        { "Conflict", "AgentSkillConflict", { "contested-skill", File[ _String ] } },
        { "Conflict", "AgentSkillConflict", _ },
        { "Conflict", "AgentSkillConflict", _ },
        "Replace",
        <| "Identifier" -> "AgentToolsObject:B/contested-skill", "References" -> { "uuid-1", "uuid-2" }, "External" -> False |>
    },
    SameTest -> MatchQ,
    TestID   -> "InstallDecision-DifferentSource@@Tests/AgentSkills.wlt:2159,1-2182,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Modified Directories*)
VerificationTest[
    withSkillTestRoot @ Module[ { root, dir, source2, entry },
        root = testSkillsRoot[ ];
        deploySkills[ { genSource[ "adopt-skill", "Version 1" ] }, root, "uuid-1" ];
        dir = FileNameJoin @ { First @ root, "adopt-skill" };
        source2 = genSource[ "adopt-skill", "Version 2" ];
        (* the user edited the directory to exactly the new content *)
        writeTestFile[ FileNameJoin @ { dir, "SKILL.md" }, StringReplace[ source2[ "Files", "SKILL.md" ], "\n" -> "\r\n" ] ];
        {
            planAction[ { source2 }, root, "uuid-2", { }, False ],
            deploySkills[ { source2 }, root, "uuid-2" ];
            entry = readSkillRegistryEntry @ skillRegistryKey[ root, "adopt-skill" ];
            entry[ "Hashes" ] === source2[ "Manifest" ],
            entry[ "References" ],
            (* nothing was written *)
            StringContainsQ[ readTestFile @ FileNameJoin @ { dir, "SKILL.md" }, "\r\n" ]
        }
    ],
    { "AdoptChange", True, { "uuid-1", "uuid-2" }, True },
    SameTest -> SameQ,
    TestID   -> "InstallDecision-Modified-AdoptChange@@Tests/AgentSkills.wlt:2187,1-2208,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { root, dir },
        root = testSkillsRoot[ ];
        deploySkills[ { genSource[ "modified-skill", "Version 1" ] }, root, "uuid-1" ];
        dir = FileNameJoin @ { First @ root, "modified-skill" };
        writeTestFile[ FileNameJoin @ { dir, "notes.txt" }, "user notes" ];
        {
            planAction[ { genSource[ "modified-skill", "Version 1" ] }, root, "uuid-2", { }, False ],
            planAction[ { genSource[ "modified-skill", "Version 2" ] }, root, "uuid-2", { }, True ],
            (* only the replaced deployment used it, but it was modified: still needs force *)
            planAction[ { genSource[ "modified-skill", "Version 2" ] }, root, "uuid-2", { "uuid-1" }, True ],
            planAction[ { genSource[ "modified-skill", "Version 2" ] }, root, "uuid-2", { }, All ]
        }
    ],
    {
        { "Conflict", "AgentSkillModified", { "modified-skill", File[ _String ] } },
        { "Conflict", "AgentSkillModified", _ },
        { "Conflict", "AgentSkillModified", _ },
        "Replace"
    },
    SameTest -> MatchQ,
    TestID   -> "InstallDecision-Modified-Conflict@@Tests/AgentSkills.wlt:2210,1-2232,2"
]

(* A repository inside a skill directory makes it "Modified" *)
VerificationTest[
    withSkillTestRoot @ Module[ { root },
        root = testSkillsRoot[ ];
        deploySkills[ { genSource[ "repo-skill", "Version 1" ] }, root, "uuid-1" ];
        writeTestFile[ FileNameJoin @ { First @ root, "repo-skill", ".git", "HEAD" }, "ref" ];
        planAction[ { genSource[ "repo-skill", "Version 2" ] }, root, "uuid-2", { "uuid-1" }, True ]
    ],
    { "Conflict", "AgentSkillModified", _ },
    SameTest -> MatchQ,
    TestID   -> "InstallDecision-Modified-VCS@@Tests/AgentSkills.wlt:2235,1-2245,2"
]

(* A file that can't be read makes a directory "Modified" (a conflict, not an internal failure) *)
ifPermissions @ VerificationTest[
    withSkillTestRoot @ Module[ { root, file },
        root = testSkillsRoot[ ];
        deploySkills[ { genSource[ "unreadable-plan", "Version 1" ] }, root, "uuid-1" ];
        file = FileNameJoin @ { First @ root, "unreadable-plan", "SKILL.md" };
        WithCleanup[
            chmod[ "000", file ];
            {
                planAction[ { genSource[ "unreadable-plan", "Version 1" ] }, root, "uuid-2", { }, False ],
                planAction[ { genSource[ "unreadable-plan", "Version 2" ] }, root, "uuid-2", { "uuid-1" }, True ],
                planAction[ { genSource[ "unreadable-plan", "Version 2" ] }, root, "uuid-2", { }, All ]
            },
            chmod[ "644", file ]
        ]
    ],
    {
        { "Conflict", "AgentSkillModified", { "unreadable-plan", File[ _String ] } },
        { "Conflict", "AgentSkillModified", _ },
        "Replace"
    },
    SameTest -> MatchQ,
    TestID   -> "InstallDecision-Modified-Unreadable@@Tests/AgentSkills.wlt:2248,17-2270,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*External Directories*)
VerificationTest[
    withSkillTestRoot @ Module[ { root, source, entry },
        root = testSkillsRoot[ ];
        source = genSource[ "foreign-skill", "Body" ];
        (* installed by the user (or InstallAgentSkills) before any deployment *)
        InstallAgentSkills[ root, LLMSkill[ { "foreign-skill", "Test skill foreign-skill" }, "Body" ] ];
        {
            planAction[ { source }, root, "uuid-1", { }, False ],
            deploySkills[ { source }, root, "uuid-1" ];
            entry = readSkillRegistryEntry @ skillRegistryKey[ root, "foreign-skill" ];
            KeyTake[ entry, { "External", "References" } ],
            planAction[ { source }, root, "uuid-2", { }, False ],
            deploySkills[ { source }, root, "uuid-2" ];
            KeyTake[ readSkillRegistryEntry @ skillRegistryKey[ root, "foreign-skill" ], { "External", "References" } ]
        }
    ],
    {
        "AdoptExternal",
        <| "External" -> True, "References" -> { "uuid-1" } |>,
        "AddReference",
        <| "External" -> True, "References" -> { "uuid-1", "uuid-2" } |>
    },
    SameTest -> SameQ,
    TestID   -> "InstallDecision-External-SameContent@@Tests/AgentSkills.wlt:2275,1-2299,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { root, entry },
        root = testSkillsRoot[ ];
        InstallAgentSkills[ root, LLMSkill[ { "foreign-change", "Test skill foreign-change" }, "Version 1" ] ];
        deploySkills[ { genSource[ "foreign-change", "Version 1" ] }, root, "uuid-1" ];
        {
            planAction[ { genSource[ "foreign-change", "Version 2" ] }, root, "uuid-2", { }, True ],
            planAction[ { genSource[ "foreign-change", "Version 2" ] }, root, "uuid-2", { "uuid-1" }, True ],
            planAction[ { genSource[ "foreign-change", "Version 2" ] }, root, "uuid-2", { }, All ],
            deploySkills[ { genSource[ "foreign-change", "Version 2" ] }, root, "uuid-2", { }, All ];
            KeyTake[ readSkillRegistryEntry @ skillRegistryKey[ root, "foreign-change" ], { "External", "References" } ]
        }
    ],
    {
        { "Conflict", "AgentSkillExists", { "foreign-change", File[ _String ], All } },
        { "Conflict", "AgentSkillExists", _ },
        "Replace",
        <| "External" -> False, "References" -> { "uuid-1", "uuid-2" } |>
    },
    SameTest -> MatchQ,
    TestID   -> "InstallDecision-External-DifferentContent@@Tests/AgentSkills.wlt:2301,1-2322,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { root },
        root = testSkillsRoot[ ];
        InstallAgentSkills[ root, LLMSkill[ { "unknown-skill", "Someone else's" }, "Theirs" ] ];
        {
            planAction[ { genSource[ "unknown-skill", "Mine" ] }, root, "uuid-1", { }, True ],
            planAction[ { genSource[ "unknown-skill", "Mine" ] }, root, "uuid-1", { }, All ],
            deploySkills[ { genSource[ "unknown-skill", "Mine" ] }, root, "uuid-1", { }, All ];
            KeyTake[ readSkillRegistryEntry @ skillRegistryKey[ root, "unknown-skill" ], { "External", "References" } ],
            backupFiles @ First @ root
        }
    ],
    {
        { "Conflict", "AgentSkillExists", { "unknown-skill", File[ _String ], All } },
        "Replace",
        <| "External" -> False, "References" -> { "uuid-1" } |>,
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "InstallDecision-Foreign-DifferentContent@@Tests/AgentSkills.wlt:2324,1-2344,2"
]

(* A foreign directory with a file that can't be read is not identical content: a normal conflict *)
ifPermissions @ VerificationTest[
    withSkillTestRoot @ Module[ { root, file },
        root = testSkillsRoot[ ];
        InstallAgentSkills[ root, LLMSkill[ { "foreign-unreadable", "Test skill foreign-unreadable" }, "Body" ] ];
        file = writeTestFile[ FileNameJoin @ { First @ root, "foreign-unreadable", "extra.txt" }, "extra" ];
        WithCleanup[
            chmod[ "000", file ];
            {
                planAction[ { genSource[ "foreign-unreadable", "Body" ] }, root, "uuid-1", { }, True ],
                planAction[ { genSource[ "foreign-unreadable", "Body" ] }, root, "uuid-1", { }, All ]
            },
            chmod[ "644", file ]
        ]
    ],
    { { "Conflict", "AgentSkillExists", { "foreign-unreadable", File[ _String ], All } }, "Replace" },
    SameTest -> MatchQ,
    TestID   -> "InstallDecision-Foreign-Unreadable@@Tests/AgentSkills.wlt:2347,17-2364,2"
]

(* A source directory that is the destination itself is already installed: it is adopted, nothing is written *)
VerificationTest[
    withSkillTestRoot @ Module[ { root, dir, result },
        root = testSkillsRoot[ ];
        dir = makeTestSkill[ First @ root, "in-place-decision" ];
        result = deploySkills[ { toAgentSkillSource @ File @ dir }, root, "uuid-1" ];
        {
            planAction[ { toAgentSkillSource @ File @ dir }, root, "uuid-2", { }, False ],
            result[ "Undo" ] // Length,
            readSkillRegistryEntry[ skillRegistryKey[ root, "in-place-decision" ] ][ "External" ]
        }
    ],
    { "AddReference", 1, True },
    SameTest -> SameQ,
    TestID   -> "InstallDecision-SourceIsDestination@@Tests/AgentSkills.wlt:2367,1-2381,2"
]

(* A directory that a deployment installed and the user then modified is the source of another deployment: the
   changes are not adopted as the baseline (the source is the only copy of them), so the directory stays "Modified"
   and is kept when the last reference is released *)
VerificationTest[
    withSkillTestRoot @ Module[ { root, dir, installed1, installed2, baseline, entry },
        root       = testSkillsRoot[ ];
        installed1 = First @ deploySkills[ { genSource[ "same-modified", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        dir        = FileNameJoin @ { First @ root, "same-modified" };
        baseline   = readSkillRegistryEntry[ installed1[ "RegistryKey" ] ][ "Hashes" ];
        writeTestFile[ FileNameJoin @ { dir, "SKILL.md" }, readTestFile[ FileNameJoin @ { dir, "SKILL.md" } ] <> "\nUser customization.\n" ];
        {
            planAction[ { toAgentSkillSource @ File @ dir }, root, "uuid-2", { }, False ],
            installed2 = First @ deploySkills[ { toAgentSkillSource @ File @ dir }, root, "uuid-2" ][ "Installed" ];
            entry = readSkillRegistryEntry @ installed2[ "RegistryKey" ];
            { entry[ "Hashes" ] === baseline, entry[ "External" ], entry[ "References" ] },
            releaseSkillReference[ installed1, "uuid-1" ][ "Result" ],
            removeFakeDeployment[ "uuid-1" ];
            releaseSkillReference[ installed2, "uuid-2" ][ "Result" ],
            StringContainsQ[ readTestFile @ FileNameJoin @ { dir, "SKILL.md" }, "User customization." ]
        }
    ],
    { "AddReference", { True, False, { "uuid-1", "uuid-2" } }, "InUse", "KeptModified", True },
    SameTest -> SameQ,
    TestID   -> "InstallDecision-SourceIsDestination-Modified@@Tests/AgentSkills.wlt:2386,1-2407,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Registry Keys and Symbolic Links*)
(* A registry key depends on how the skills root resolved when the directory was first installed. If the root later
   goes through a symbolic link (e.g. ~/.claude moved into a dotfiles repository and linked back), the same directory
   gets a different key: the existing entry is found by its directory and shared. *)
ifSymlinks @ VerificationTest[
    withSkillTestRoot @ Module[ { root, installed1, installed2, oldKey, newKey, dir },
        root       = testSkillsRoot[ ];
        dir        = FileNameJoin @ { First @ root, "moved-skill" };
        installed1 = First @ deploySkills[ { genSource[ "moved-skill", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        oldKey     = installed1[ "RegistryKey" ];
        RenameDirectory[ FileNameJoin @ { $HomeDirectory, ".claude" }, FileNameJoin @ { $HomeDirectory, "dotfiles-claude" } ];
        symlink[ FileNameJoin @ { $HomeDirectory, "dotfiles-claude" }, FileNameJoin @ { $HomeDirectory, ".claude" } ];
        newKey = skillRegistryKey[ root, "moved-skill" ];
        {
            newKey =!= oldKey,
            planAction[ { genSource[ "moved-skill", "Body" ] }, root, "uuid-2", { }, False ],
            installed2 = First @ deploySkills[ { genSource[ "moved-skill", "Body" ] }, root, "uuid-2" ][ "Installed" ];
            installed2[ "RegistryKey" ] === oldKey,
            readSkillRegistryEntry[ oldKey ][ "References" ],
            readSkillRegistryEntry @ newKey,
            releaseSkillReference[ installed1, "uuid-1" ][ "Result" ],
            removeFakeDeployment[ "uuid-1" ];
            DirectoryQ @ dir,
            releaseSkillReference[ installed2, "uuid-2" ][ "Result" ],
            DirectoryQ @ dir
        }
    ],
    { True, "AddReference", True, { "uuid-1", "uuid-2" }, Missing[ "NotFound" ], "InUse", True, "Removed", False },
    SameTest -> SameQ,
    TestID   -> "InstallDecision-SymbolicLinkRoot@@Tests/AgentSkills.wlt:2415,14-2441,2"
]

(* The entry of a directory that was removed by hand is found by its directory too, so its references are kept *)
ifSymlinks @ VerificationTest[
    withSkillTestRoot @ Module[ { root, installed1, dir },
        root       = testSkillsRoot[ ];
        dir        = FileNameJoin @ { First @ root, "moved-missing" };
        installed1 = First @ deploySkills[ { genSource[ "moved-missing", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        DeleteDirectory[ dir, DeleteContents -> True ];
        RenameDirectory[ FileNameJoin @ { $HomeDirectory, ".claude" }, FileNameJoin @ { $HomeDirectory, "dotfiles-claude" } ];
        symlink[ FileNameJoin @ { $HomeDirectory, "dotfiles-claude" }, FileNameJoin @ { $HomeDirectory, ".claude" } ];
        {
            planAction[ { genSource[ "moved-missing", "Body" ] }, root, "uuid-2", { }, False ],
            deploySkills[ { genSource[ "moved-missing", "Body" ] }, root, "uuid-2" ][ "Installed" ][[ 1, "RegistryKey" ]] === installed1[ "RegistryKey" ],
            readSkillRegistryEntry[ installed1[ "RegistryKey" ] ][ "References" ]
        }
    ],
    { "Create", True, { "uuid-1", "uuid-2" } },
    SameTest -> SameQ,
    TestID   -> "InstallDecision-SymbolicLinkRoot-Missing@@Tests/AgentSkills.wlt:2444,14-2461,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Plans*)
VerificationTest[
    withSkillTestRoot @ Module[ { root, plan },
        root = testSkillsRoot[ ];
        deploySkills[ { genSource[ "plan-a", "1", "AgentToolsObject:A/plan-a" ] }, root, "uuid-1" ];
        plan = planSkillInstall[
            { genSource[ "plan-a", "2", "AgentToolsObject:B/plan-a" ], genSource[ "plan-b", "1" ] },
            root,
            "uuid-2",
            { },
            False
        ];
        {
            Lookup[ plan[ "Decisions" ], "Name" ],
            plan[ "Conflicts" ],
            catchTop @ applySkillInstallPlan[ plan, "uuid-2" ],
            DirectoryQ @ FileNameJoin @ { First @ root, "plan-b" }
        }
    ],
    {
        { "plan-b" },
        { <| "Tag" -> "AgentSkillConflict", "Parameters" -> { "plan-a", File[ _String ] } |> },
        Failure[ "AgentTools::AgentSkillConflict", _ ],
        False
    },
    { AgentTools::AgentSkillConflict },
    SameTest -> MatchQ,
    TestID   -> "PlanSkillInstall-Conflicts@@Tests/AgentSkills.wlt:2466,1-2493,2"
]

VerificationTest[
    withSkillTestRoot @ catchTop @ planSkillInstall[
        { genSource[ "dup-skill", "1" ], genSource[ "dup-skill", "2" ] },
        testSkillsRoot[ ],
        "uuid-1",
        { },
        False
    ],
    Failure[ "AgentTools::DuplicateAgentSkillName", _ ],
    { AgentTools::DuplicateAgentSkillName },
    SameTest -> MatchQ,
    TestID   -> "PlanSkillInstall-DuplicateNames@@Tests/AgentSkills.wlt:2495,1-2507,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { dir },
        dir = makeTestSkill[ skillTestDirectory[ ], "root-skill" ];
        catchTop @ planSkillInstall[ { genSource[ "x", "1" ] }, File @ dir, "uuid-1", { }, False ]
    ],
    Failure[ "AgentTools::InvalidSkillsDirectory", _ ],
    { AgentTools::InvalidSkillsDirectory },
    SameTest -> MatchQ,
    TestID   -> "PlanSkillInstall-InvalidRoot@@Tests/AgentSkills.wlt:2509,1-2518,2"
]

VerificationTest[
    versionOlderQ @@@ { { "1.0.0", "2.0.0" }, { "1.9.0", "1.10.0" }, { "1.10.0", "1.9.0" }, { "1.0", "1.0.0" }, { "1.0.0", "1.0.1" }, { "1.0.0", Missing[ ] }, { "dev", "1.0.0" } },
    { True, True, False, False, True, False, False },
    SameTest -> SameQ,
    TestID   -> "VersionOlderQ@@Tests/AgentSkills.wlt:2520,1-2525,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Undo and Rollback*)
VerificationTest[
    withSkillTestRoot @ Module[ { root, key, before, result },
        root = testSkillsRoot[ ];
        deploySkills[ { pacletSource[ "undo-skill", "Version 1", "1.0.0" ] }, root, "uuid-1" ];
        key = skillRegistryKey[ root, "undo-skill" ];
        before = readSkillRegistryEntry @ key;
        result = applySkillInstallPlan[
            planSkillInstall[ { pacletSource[ "undo-skill", "Version 2", "2.0.0" ], genSource[ "undo-new", "New" ] }, root, "uuid-2", { }, True ],
            "uuid-2"
        ];
        {
            Length @ backupFiles @ First @ root,
            StringContainsQ[ readTestFile @ FileNameJoin @ { First @ root, "undo-skill", "SKILL.md" }, "Version 2" ],
            Scan[ #[ ] &, Reverse @ result[ "Undo" ] ];
            StringContainsQ[ readTestFile @ FileNameJoin @ { First @ root, "undo-skill", "SKILL.md" }, "Version 1" ],
            readSkillRegistryEntry @ key === before,
            DirectoryQ @ FileNameJoin @ { First @ root, "undo-new" },
            readSkillRegistryEntry @ skillRegistryKey[ root, "undo-new" ],
            backupFiles @ First @ root
        }
    ],
    { 1, True, True, True, False, Missing[ "NotFound" ], { } },
    SameTest -> SameQ,
    TestID   -> "ApplySkillInstallPlan-Undo@@Tests/AgentSkills.wlt:2530,1-2554,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { root, result },
        root = testSkillsRoot[ ];
        deploySkills[ { pacletSource[ "final-skill", "Version 1", "1.0.0" ] }, root, "uuid-1" ];
        result = applySkillInstallPlan[
            planSkillInstall[ { pacletSource[ "final-skill", "Version 2", "2.0.0" ] }, root, "uuid-2", { }, True ],
            "uuid-2"
        ];
        { Length @ backupFiles @ First @ root, Scan[ #[ ] &, result[ "Finalize" ] ]; backupFiles @ First @ root }
    ],
    { 1, { } },
    SameTest -> SameQ,
    TestID   -> "ApplySkillInstallPlan-Finalize@@Tests/AgentSkills.wlt:2556,1-2569,2"
]

(* A failure midway rolls back the changes already made by the plan and propagates *)
VerificationTest[
    withSkillTestRoot @ Module[ { root, plan, result },
        root = testSkillsRoot[ ];
        deploySkills[ { pacletSource[ "rollback-replaced", "Version 1", "1.0.0" ] }, root, "uuid-1" ];
        plan = planSkillInstall[
            {
                pacletSource[ "rollback-replaced", "Version 2", "2.0.0" ],
                genSource[ "rollback-created", "Created" ],
                genSource[ "rollback-failing", "Fails" ]
            },
            root,
            "uuid-2",
            { },
            True
        ];
        result = withFailureInjection[
            Wolfram`AgentTools`AgentSkills`Private`writeSkillFileContent,
            Wolfram`AgentTools`AgentSkills`Private`writeSkillFileContent[ t_String /; StringContainsQ[ t, "rollback-failing" ], _ ],
            False,
            catchTop @ applySkillInstallPlan[ plan, "uuid-2" ]
        ];
        {
            result,
            Sort[ FileNameTake /@ FileNames[ All, First @ root ] ],
            StringContainsQ[ readTestFile @ FileNameJoin @ { First @ root, "rollback-replaced", "SKILL.md" }, "Version 1" ],
            readSkillRegistryEntry[ skillRegistryKey[ root, "rollback-replaced" ] ][ "References" ],
            readSkillRegistryEntry @ skillRegistryKey[ root, "rollback-created" ],
            backupFiles @ First @ root
        }
    ],
    {
        Failure[ "AgentTools::AgentSkillWriteFailed", _ ],
        { "rollback-replaced" },
        True,
        { "uuid-1" },
        Missing[ "NotFound" ],
        { }
    },
    { AgentTools::AgentSkillWriteFailed },
    SameTest -> MatchQ,
    TestID   -> "ApplySkillInstallPlan-Rollback@@Tests/AgentSkills.wlt:2572,1-2613,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Release Decisions*)
VerificationTest[
    withSkillTestRoot @ Module[ { root, installed, r1, r2 },
        root = testSkillsRoot[ ];
        installed = First @ deploySkills[ { genSource[ "release-skill", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        deploySkills[ { genSource[ "release-skill", "Body" ] }, root, "uuid-2" ];
        (* junk files written by clients don't prevent removal *)
        writeTestFile[ FileNameJoin @ { First @ root, "release-skill", ".DS_Store" }, "junk" ];
        r1 = releaseSkillReference[ installed, "uuid-1" ];
        removeFakeDeployment[ "uuid-1" ];
        r1 = { r1, DirectoryQ @ FileNameJoin @ { First @ root, "release-skill" } };
        r2 = releaseSkillReference[ installed, "uuid-2" ];
        {
            r1,
            r2,
            DirectoryQ @ FileNameJoin @ { First @ root, "release-skill" },
            readSkillRegistryEntry @ installed[ "RegistryKey" ],
            backupFiles @ First @ root
        }
    ],
    {
        {
            KeyValuePattern @ { "Name" -> "release-skill", "Result" -> "InUse", "References" -> { "uuid-2" }, "Directory" -> File[ _String ], "RegistryKey" -> _String },
            True
        },
        KeyValuePattern @ { "Name" -> "release-skill", "Result" -> "Removed", "State" -> "Directory", "Root" -> File[ _String ] },
        False,
        Missing[ "NotFound" ],
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "ReleaseSkillReference-InUseThenRemoved@@Tests/AgentSkills.wlt:2618,1-2649,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { root, installed, result },
        root = testSkillsRoot[ ];
        installed = First @ deploySkills[ { genSource[ "kept-modified", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        writeTestFile[ FileNameJoin @ { First @ root, "kept-modified", "notes.txt" }, "user notes" ];
        result = releaseSkillReference[ installed, "uuid-1" ];
        { result[ "Result" ], DirectoryQ @ FileNameJoin @ { First @ root, "kept-modified" }, readSkillRegistryEntry @ installed[ "RegistryKey" ] }
    ],
    { "KeptModified", True, Missing[ "NotFound" ] },
    SameTest -> SameQ,
    TestID   -> "ReleaseSkillReference-KeptModified@@Tests/AgentSkills.wlt:2651,1-2662,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { root, installed, result },
        root = testSkillsRoot[ ];
        installed = First @ deploySkills[ { genSource[ "kept-repo", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        writeTestFile[ FileNameJoin @ { First @ root, "kept-repo", ".git", "HEAD" }, "ref" ];
        result = releaseSkillReference[ installed, "uuid-1" ];
        { result[ "Result" ], FileExistsQ @ FileNameJoin @ { First @ root, "kept-repo", ".git", "HEAD" } }
    ],
    { "KeptModified", True },
    SameTest -> SameQ,
    TestID   -> "ReleaseSkillReference-KeptVCS@@Tests/AgentSkills.wlt:2664,1-2675,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { root, installed, result },
        root = testSkillsRoot[ ];
        InstallAgentSkills[ root, LLMSkill[ { "kept-external", "Test skill kept-external" }, "Body" ] ];
        installed = First @ deploySkills[ { genSource[ "kept-external", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        result = releaseSkillReference[ installed, "uuid-1" ];
        { result[ "Result" ], DirectoryQ @ FileNameJoin @ { First @ root, "kept-external" }, readSkillRegistryEntry @ installed[ "RegistryKey" ] }
    ],
    { "KeptExternal", True, Missing[ "NotFound" ] },
    SameTest -> SameQ,
    TestID   -> "ReleaseSkillReference-KeptExternal@@Tests/AgentSkills.wlt:2677,1-2688,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { root, installed, result },
        root = testSkillsRoot[ ];
        installed = First @ deploySkills[ { genSource[ "gone-skill", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        (* e.g. removed by UninstallAgentSkills: the reference is dropped silently *)
        UninstallAgentSkills[ root, "gone-skill" ];
        result = releaseSkillReference[ installed, "uuid-1" ];
        { result[ "Result" ], readSkillRegistryEntry @ installed[ "RegistryKey" ] }
    ],
    { "Missing", Missing[ "NotFound" ] },
    SameTest -> SameQ,
    TestID   -> "ReleaseSkillReference-Missing@@Tests/AgentSkills.wlt:2690,1-2702,2"
]

ifSymlinks @ VerificationTest[
    withSkillTestRoot @ Module[ { root, installed, target, result },
        root = testSkillsRoot[ ];
        installed = First @ deploySkills[ { genSource[ "now-a-link", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        DeleteDirectory[ FileNameJoin @ { First @ root, "now-a-link" }, DeleteContents -> True ];
        target = makeTestSkill[ skillTestDirectory[ ], "now-a-link" ];
        symlink[ target, FileNameJoin @ { First @ root, "now-a-link" } ];
        result = releaseSkillReference[ installed, "uuid-1" ];
        {
            result[ "Result" ],
            result[ "State" ],
            skillDirectoryState[ root, "now-a-link" ],
            FileExistsQ @ FileNameJoin @ { target, "SKILL.md" },
            readSkillRegistryEntry @ installed[ "RegistryKey" ]
        }
    ],
    { "KeptLink", "Link", "Link", True, Missing[ "NotFound" ] },
    SameTest -> SameQ,
    TestID   -> "ReleaseSkillReference-KeptLink@@Tests/AgentSkills.wlt:2704,14-2723,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { root, result },
        root = testSkillsRoot[ ];
        makeTestSkill[ First @ root, "no-entry" ];
        result = releaseSkillReference[
            <| "Name" -> "no-entry", "Directory" -> File @ FileNameJoin @ { First @ root, "no-entry" }, "RegistryKey" -> skillRegistryKey[ root, "no-entry" ] |>,
            "uuid-1"
        ];
        { result[ "Result" ], DirectoryQ @ FileNameJoin @ { First @ root, "no-entry" } }
    ],
    { "NoEntry", True },
    SameTest -> SameQ,
    TestID   -> "ReleaseSkillReference-NoEntry@@Tests/AgentSkills.wlt:2725,1-2738,2"
]

(* Stale references are pruned when releasing *)
VerificationTest[
    withSkillTestRoot @ Module[ { root, installed },
        root = testSkillsRoot[ ];
        installed = First @ deploySkills[ { genSource[ "stale-release", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        deploySkills[ { genSource[ "stale-release", "Body" ] }, root, "uuid-2" ];
        removeFakeDeployment[ "uuid-2" ];
        releaseSkillReference[ installed, "uuid-1" ][ "Result" ]
    ],
    "Removed",
    SameTest -> SameQ,
    TestID   -> "ReleaseSkillReference-PrunesStale@@Tests/AgentSkills.wlt:2741,1-2752,2"
]

(* If the directory can't be removed, the entry is kept without references and the next sweep retries *)
VerificationTest[
    withSkillTestRoot @ Module[ { root, installed, result, entry },
        root = testSkillsRoot[ ];
        installed = First @ deploySkills[ { genSource[ "busy-release", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        result = withFailureInjection[
            Wolfram`AgentTools`AgentSkills`Private`moveSkillEntry,
            Wolfram`AgentTools`AgentSkills`Private`moveSkillEntry[ _, _, _ ],
            False,
            releaseSkillReference[ installed, "uuid-1" ]
        ];
        entry = readSkillRegistryEntry @ installed[ "RegistryKey" ];
        {
            result[ "Result" ],
            entry[ "References" ],
            DirectoryQ @ FileNameJoin @ { First @ root, "busy-release" },
            Lookup[ sweepSkillRegistry[ ], "Result" ],
            DirectoryQ @ FileNameJoin @ { First @ root, "busy-release" },
            readSkillRegistryEntry @ installed[ "RegistryKey" ]
        }
    ],
    { "RemoveFailed", { }, True, { "Removed" }, False, Missing[ "NotFound" ] },
    SameTest -> SameQ,
    TestID   -> "ReleaseSkillReference-RemoveFailed@@Tests/AgentSkills.wlt:2755,1-2778,2"
]

(* A file that can't be read makes the directory "Modified": it is kept (not an internal failure) *)
ifPermissions @ VerificationTest[
    withSkillTestRoot @ Module[ { root, installed, file, result },
        root      = testSkillsRoot[ ];
        installed = First @ deploySkills[ { genSource[ "unreadable-release", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        file      = FileNameJoin @ { First @ root, "unreadable-release", "SKILL.md" };
        WithCleanup[
            chmod[ "000", file ];
            result = releaseSkillReference[ installed, "uuid-1" ];
            { result[ "Result" ], FileExistsQ @ file, readSkillRegistryEntry @ installed[ "RegistryKey" ] },
            chmod[ "644", file ]
        ]
    ],
    { "KeptModified", True, Missing[ "NotFound" ] },
    SameTest -> SameQ,
    TestID   -> "ReleaseSkillReference-Unreadable@@Tests/AgentSkills.wlt:2781,17-2796,2"
]

(* The directory was removed, but its backup can't be deleted completely (a read-only subdirectory): reported *)
ifPermissions @ VerificationTest[
    withSkillTestRoot @ Module[ { root, installed, result },
        root      = testSkillsRoot[ ];
        installed = First @ deploySkills[ { scriptedSource[ "stuck-release", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        WithCleanup[
            chmod[ "555", FileNameJoin @ { First @ root, "stuck-release", "scripts" } ];
            result = catchTop @ releaseSkillReference[ installed, "uuid-1" ];
            {
                result[ "Result" ],
                DirectoryQ @ FileNameJoin @ { First @ root, "stuck-release" },
                readSkillRegistryEntry @ installed[ "RegistryKey" ],
                Length @ backupFiles @ First @ root
            },
            restoreWritable @ $HomeDirectory
        ]
    ],
    { "Removed", False, Missing[ "NotFound" ], 1 },
    { AgentTools::AgentSkillBackupNotRemoved },
    SameTest -> SameQ,
    TestID   -> "ReleaseSkillReference-BackupNotRemoved@@Tests/AgentSkills.wlt:2799,17-2819,2"
]

(* Several entries for one directory (registry keys from before entries were matched by their directory): the
   directory is never removed while another entry for it is in use or external *)
VerificationTest[
    withSkillTestRoot @ Module[ { root, dir, installed, entry, otherKey, results },
        root      = testSkillsRoot[ ];
        dir       = FileNameJoin @ { First @ root, "duplicate-entry" };
        installed = First @ deploySkills[ { genSource[ "duplicate-entry", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        entry     = readSkillRegistryEntry @ installed[ "RegistryKey" ];
        otherKey  = Hash[ "another spelling of duplicate-entry", "SHA256", "HexString" ];
        results   = <| |>;

        (* the other entry is in use *)
        writeSkillRegistryEntry @ <| entry, "RegistryKey" -> otherKey, "External" -> True, "References" -> { fakeDeployment[ "uuid-2" ] } |>;
        results[ "InUse" ] = KeyTake[ releaseSkillReference[ installed, "uuid-1" ], { "Result", "References" } ];
        results[ "InUseState" ] = { DirectoryQ @ dir, readSkillRegistryEntry @ installed[ "RegistryKey" ], readSkillRegistryEntry[ otherKey ][ "References" ] };

        (* the other entry is external, but no longer in use *)
        removeFakeDeployment[ "uuid-2" ];
        writeSkillRegistryEntry @ <| entry, "References" -> { fakeDeployment[ "uuid-3" ] } |>;
        results[ "External" ] = releaseSkillReference[ installed, "uuid-3" ][ "Result" ];
        results[ "ExternalState" ] = { DirectoryQ @ dir, readSkillRegistryEntry @ installed[ "RegistryKey" ] };

        (* the other entry is neither in use nor external: the directory is removed *)
        writeSkillRegistryEntry @ <| entry, "RegistryKey" -> otherKey, "External" -> False, "References" -> { } |>;
        writeSkillRegistryEntry @ <| entry, "References" -> { fakeDeployment[ "uuid-4" ] } |>;
        results[ "Unused" ] = releaseSkillReference[ installed, "uuid-4" ][ "Result" ];
        results[ "UnusedState" ] = DirectoryQ @ dir;
        results
    ],
    (* While only an external entry uses the directory, this (owning) entry is kept without references, so that the
       directory is released again once the external entry is gone *)
    <|
        "InUse"         -> <| "Result" -> "InUse", "References" -> { "uuid-2" } |>,
        "InUseState"    -> { True, _Association? (#[ "References" ] === { } &), { "uuid-2" } },
        "External"      -> "KeptExternal",
        "ExternalState" -> { True, Missing[ "NotFound" ] },
        "Unused"        -> "Removed",
        "UnusedState"   -> False
    |>,
    SameTest -> MatchQ,
    TestID   -> "ReleaseSkillReference-DuplicateEntries@@Tests/AgentSkills.wlt:2823,1-2862,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillReleaseMessages*)
VerificationTest[
    Module[ { root, results },
        root = File @ FileNameJoin @ { $TemporaryDirectory, "skills" };
        results = {
            <| "Name" -> "in-use", "Directory" -> File @ FileNameJoin @ { First @ root, "in-use" }, "RegistryKey" -> "a1", "Root" -> root, "Result" -> "InUse" |>,
            <| "Name" -> "in-use", "Directory" -> File @ FileNameJoin @ { First @ root, "in-use" }, "RegistryKey" -> "a1", "Root" -> root, "Result" -> "InUse" |>,
            <| "Name" -> "modified", "Directory" -> File @ FileNameJoin @ { First @ root, "modified" }, "RegistryKey" -> "b2", "Root" -> root, "Result" -> "KeptModified" |>,
            <| "Name" -> "removed", "Directory" -> File @ FileNameJoin @ { First @ root, "removed" }, "RegistryKey" -> "c3", "Root" -> root, "Result" -> "Removed" |>,
            <| "Name" -> "external", "Directory" -> File @ FileNameJoin @ { First @ root, "external" }, "RegistryKey" -> "d4", "Root" -> root, "Result" -> "KeptExternal" |>
        };
        catchTop @ skillReleaseMessages @ results
    ],
    {
        Failure[ "AgentTools::AgentSkillInUse", KeyValuePattern[ "MessageParameters" :> { "in-use", _File } ] ],
        Failure[
            "AgentTools::AgentSkillNotRemoved",
            KeyValuePattern[
                "MessageParameters" :> {
                    "modified",
                    _File,
                    HoldForm @ UninstallAgentSkills[ File[ _String? (StringEndsQ[ "skills" ]) ], "modified" ]
                }
            ]
        ]
    },
    { AgentTools::AgentSkillInUse, AgentTools::AgentSkillNotRemoved },
    SameTest -> MatchQ,
    TestID   -> "SkillReleaseMessages@@Tests/AgentSkills.wlt:2867,1-2895,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*sweepSkillRegistry*)
VerificationTest[
    withTemporaryRoot @ sweepSkillRegistry[ ],
    { },
    SameTest -> SameQ,
    TestID   -> "SweepSkillRegistry-Empty@@Tests/AgentSkills.wlt:2900,1-2905,2"
]

VerificationTest[
    withSkillTestRoot @ Module[ { root, results },
        root = testSkillsRoot[ ];
        (* released: the only deployment vanished (e.g. removed by an older AgentTools version) *)
        deploySkills[ { genSource[ "sweep-orphan", "Body" ] }, root, "uuid-1" ];
        (* pruned: one of two deployments vanished *)
        deploySkills[ { genSource[ "sweep-pruned", "Body" ] }, root, "uuid-1" ];
        deploySkills[ { genSource[ "sweep-pruned", "Body" ] }, root, "uuid-2" ];
        (* untouched *)
        deploySkills[ { genSource[ "sweep-live", "Body" ] }, root, "uuid-2" ];
        (* external entries are released without deleting files *)
        InstallAgentSkills[ root, LLMSkill[ { "sweep-external", "Test skill sweep-external" }, "Body" ] ];
        deploySkills[ { genSource[ "sweep-external", "Body" ] }, root, "uuid-1" ];
        (* unreadable entries are ignored *)
        Export[ FileNameJoin @ { Wolfram`AgentTools`Common`$skillRegistryPath, "abc123.wxf" }, "garbage", "Text" ];
        removeFakeDeployment[ "uuid-1" ];
        results = sweepSkillRegistry[ ];
        {
            Sort[ { #[ "Name" ], #[ "Result" ] } & /@ results ],
            readSkillRegistryEntry[ skillRegistryKey[ root, "sweep-pruned" ] ][ "References" ],
            readSkillRegistryEntry[ skillRegistryKey[ root, "sweep-live" ] ][ "References" ],
            Sort[ FileNameTake /@ FileNames[ All, First @ root ] ],
            FileExistsQ @ FileNameJoin @ { Wolfram`AgentTools`Common`$skillRegistryPath, "abc123.wxf" }
        }
    ],
    {
        { { "sweep-external", "KeptExternal" }, { "sweep-orphan", "Removed" } },
        { "uuid-2" },
        { "uuid-2" },
        { "sweep-external", "sweep-live", "sweep-pruned" },
        True
    },
    SameTest -> SameQ,
    TestID   -> "SweepSkillRegistry@@Tests/AgentSkills.wlt:2907,1-2941,2"
]

(* The sweep runs before every locked deploy and delete: an entry that fails is skipped (and retried by the next
   sweep), so it can't block every deployment *)
VerificationTest[
    withSkillTestRoot @ Module[ { root, results },
        root = testSkillsRoot[ ];
        deploySkills[ { genSource[ "sweep-failing", "Body" ] }, root, "uuid-1" ];
        deploySkills[ { genSource[ "sweep-other", "Body" ] }, root, "uuid-1" ];
        removeFakeDeployment[ "uuid-1" ];
        results = withFailureInjection[
            Wolfram`AgentTools`AgentSkills`Private`releaseSkillEntry,
            Wolfram`AgentTools`AgentSkills`Private`releaseSkillEntry[ KeyValuePattern[ "Name" -> "sweep-failing" ] ],
            Wolfram`AgentTools`Common`throwInternalFailure[ "injected" ],
            sweepSkillRegistry[ ]
        ];
        {
            { #[ "Name" ], #[ "Result" ] } & /@ results,
            DirectoryQ @ FileNameJoin @ { First @ root, "sweep-failing" },
            DirectoryQ @ FileNameJoin @ { First @ root, "sweep-other" },
            { #[ "Name" ], #[ "Result" ] } & /@ sweepSkillRegistry[ ],
            DirectoryQ @ FileNameJoin @ { First @ root, "sweep-failing" }
        }
    ],
    { { { "sweep-other", "Removed" } }, True, False, { { "sweep-failing", "Removed" } }, False },
    SameTest -> SameQ,
    TestID   -> "SweepSkillRegistry-SkipsFailures@@Tests/AgentSkills.wlt:2945,1-2968,2"
]

(* An orphaned entry whose directory has a file that can't be read is released as "Modified" *)
ifPermissions @ VerificationTest[
    withSkillTestRoot @ Module[ { root, installed, file },
        root      = testSkillsRoot[ ];
        installed = First @ deploySkills[ { genSource[ "sweep-unreadable", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        removeFakeDeployment[ "uuid-1" ];
        file = FileNameJoin @ { First @ root, "sweep-unreadable", "SKILL.md" };
        WithCleanup[
            chmod[ "000", file ];
            {
                { #[ "Name" ], #[ "Result" ] } & /@ sweepSkillRegistry[ ],
                FileExistsQ @ file,
                readSkillRegistryEntry @ installed[ "RegistryKey" ]
            },
            chmod[ "644", file ]
        ]
    ],
    { { { "sweep-unreadable", "KeptModified" } }, True, Missing[ "NotFound" ] },
    SameTest -> SameQ,
    TestID   -> "SweepSkillRegistry-Unreadable@@Tests/AgentSkills.wlt:2971,17-2990,2"
]

(* An orphaned entry is not removed while another entry for the same directory is in use *)
VerificationTest[
    withSkillTestRoot @ Module[ { root, installed, otherKey },
        root      = testSkillsRoot[ ];
        installed = First @ deploySkills[ { genSource[ "sweep-duplicate", "Body" ] }, root, "uuid-1" ][ "Installed" ];
        otherKey  = Hash[ "another spelling of sweep-duplicate", "SHA256", "HexString" ];
        writeSkillRegistryEntry @ <|
            readSkillRegistryEntry @ installed[ "RegistryKey" ],
            "RegistryKey" -> otherKey,
            "References"  -> { fakeDeployment[ "uuid-2" ] }
        |>;
        removeFakeDeployment[ "uuid-1" ];
        {
            { #[ "Name" ], #[ "Result" ] } & /@ sweepSkillRegistry[ ],
            DirectoryQ @ FileNameJoin @ { First @ root, "sweep-duplicate" },
            readSkillRegistryEntry @ installed[ "RegistryKey" ],
            readSkillRegistryEntry[ otherKey ][ "References" ]
        }
    ],
    { { { "sweep-duplicate", "InUse" } }, True, Missing[ "NotFound" ], { "uuid-2" } },
    SameTest -> SameQ,
    TestID   -> "SweepSkillRegistry-DuplicateEntries@@Tests/AgentSkills.wlt:2993,1-3014,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Client Targets*)
(* These tests use skillsLocation / projectSkillsLocation (Kernel/InstallMCPServer.wl) and the "SkillsLocation" /
   "SkillsProjectPath" client metadata (Kernel/SupportedClients.wl). $HomeDirectory is redirected to a temporary
   directory. *)
VerificationTest[
    Block[ { $HomeDirectory = skillTestDirectory[ ] },
        resolveSkillsRoot[ "ClaudeCode" ] === <|
            "Root"       -> File @ FileNameJoin @ { $HomeDirectory, ".claude", "skills" },
            "ClientName" -> "ClaudeCode"
        |>
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "ResolveSkillsRoot-Client@@Tests/AgentSkills.wlt:3022,1-3032,2"
]

VerificationTest[
    Block[ { $HomeDirectory = skillTestDirectory[ ] },
        {
            InstallAgentSkills[ "ClaudeCode", LLMSkill[ { "client-skill", "Client skill" }, "Body" ] ],
            FileExistsQ @ FileNameJoin @ { $HomeDirectory, ".claude", "skills", "client-skill", "SKILL.md" },
            UninstallAgentSkills[ "ClaudeCode", "client-skill" ],
            DirectoryQ @ FileNameJoin @ { $HomeDirectory, ".claude", "skills", "client-skill" }
        }
    ],
    {
        Success[
            "InstallAgentSkills",
            KeyValuePattern @ {
                "MessageTemplate"   :> AgentTools::InstallAgentSkillNamed,
                "MessageParameters" -> { "client-skill", "Claude Code" },
                "ClientName"        -> "ClaudeCode"
            }
        ],
        True,
        Success[
            "UninstallAgentSkills",
            KeyValuePattern @ {
                "MessageTemplate"   :> AgentTools::UninstallAgentSkillNamed,
                "MessageParameters" -> { "client-skill", "Claude Code" },
                "ClientName"        -> "ClaudeCode"
            }
        ],
        False
    },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-Client@@Tests/AgentSkills.wlt:3034,1-3065,2"
]

VerificationTest[
    Block[ { $HomeDirectory = skillTestDirectory[ ] },
        Module[ { project },
            project = skillTestDirectory[ ];
            {
                InstallAgentSkills[ { "ClaudeCode", project }, LLMSkill[ { "project-skill", "Project skill" }, "Body" ] ],
                FileExistsQ @ FileNameJoin @ { project, ".claude", "skills", "project-skill", "SKILL.md" },
                UninstallAgentSkills[ { "ClaudeCode", File @ project }, "project-skill" ]
            }
        ]
    ],
    {
        Success[ "InstallAgentSkills", KeyValuePattern @ { "ClientName" -> "ClaudeCode", "Name" -> "project-skill" } ],
        True,
        Success[ "UninstallAgentSkills", KeyValuePattern[ "Name" -> "project-skill" ] ]
    },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-ProjectClient@@Tests/AgentSkills.wlt:3067,1-3085,2"
]

VerificationTest[
    Block[ { $HomeDirectory = skillTestDirectory[ ] },
        InstallAgentSkills[ "LMStudio", LLMSkill[ { "unsupported", "Unsupported" }, "Body" ] ]
    ],
    Failure[ "InstallAgentSkills::UnsupportedSkillsClient", _ ],
    { InstallAgentSkills::UnsupportedSkillsClient },
    SameTest -> MatchQ,
    TestID   -> "InstallAgentSkills-UnsupportedClient@@Tests/AgentSkills.wlt:3087,1-3095,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    DeleteDirectory[ $skillTestBase, DeleteContents -> True ];
    DirectoryQ @ $skillTestBase,
    False,
    SameTest -> SameQ,
    TestID   -> "Cleanup@@Tests/AgentSkills.wlt:3100,1-3106,2"
]

(* :!CodeAnalysis::EndBlock:: *)
