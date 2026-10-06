(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`AgentSkills`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)

(* The built-in skill registry (name -> skill definition): the skills in the paclet's "AgentSkills" asset
   (Assets/AgentSkills, built by Scripts/BuildAgentSkills.wls). The values are delayed so that each directory is resolved
   in the paclet that is actually loaded, and nothing machine-specific is stored in the MX file. *)
$defaultAgentSkills = <|
    "wolfram-alpha"     :> builtInSkillDirectory[ "wolfram-alpha"     ],
    "wolfram-language"  :> builtInSkillDirectory[ "wolfram-language"  ],
    "wolfram-notebooks" :> builtInSkillDirectory[ "wolfram-notebooks" ],
    "wolfram-paclets"   :> builtInSkillDirectory[ "wolfram-paclets"   ]
|>;

(* Entries that are never copied, hashed, or counted as modifications (compared case-insensitively): *)
$junkFileNames      = { ".ds_store", "thumbs.db", "desktop.ini" };
$junkDirectoryNames = { "__pycache__" };

(* Version-control metadata (file or directory): never copied or hashed, and its presence in an installed skill
   directory makes the directory "Modified", so a user's repository is never deleted or replaced: *)
$vcsNames = { ".git", ".hg", ".svn" };

(* Files that contain NUL bytes are binary, so their line endings are not normalized when hashing: *)
$nul = FromCharacterCode[ 0 ];

(* Guards against symbolic link cycles and pathological trees when listing a skill directory: *)
$maxSkillDirectoryDepth = 32;

(* Prefix of the temporary entries that hold replaced or removed skill directories (in the skills root's parent): *)
$skillBackupPrefix = ".agenttools-backup-";

(* Standard frontmatter keys of a generated SKILL.md (anything else from "AdditionalFrontmatter" follows them): *)
$reservedFrontmatterKeys = { "name", "description", "license", "compatibility", "allowed-tools", "allowed-Tools", "metadata" };

$$skillState    = "Missing" | "Dangling" | "File" | "Link" | "Directory";
$$overwrite     = True | False | All;
$$absent        = _Missing | None | Null;
$$installAction = "Create" | "AddReference" | "Replace" | "KeepNewer" | "AdoptExternal" | "AdoptChange";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skill Names*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*agentSkillNameQ*)
(* Agent Skills name rules: 1-64 lowercase ASCII letters, digits, and hyphens, without leading, trailing, or
   consecutive hyphens. These rules also guarantee that a name can never resolve to a skills root or escape it. *)
agentSkillNameQ // beginDefinition;
agentSkillNameQ[ name_String ] := StringLength @ name <= 64 && StringMatchQ[ name, RegularExpression[ "[a-z0-9]+(-[a-z0-9]+)*" ] ];
agentSkillNameQ[ _ ] := False;
agentSkillNameQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*agentSkillName*)
(* The skill name of a skill specification, without resolving paclet definitions: the item name of a qualified paclet
   skill name, the name of an LLMSkill or definition association, or the name in a skill directory's SKILL.md. The
   result is not validated (see agentSkillNameQ). *)
agentSkillName // beginDefinition;

agentSkillName[ name_String ] /; pacletQualifiedNameQ @ name :=
    Replace[ parsePacletQualifiedName @ name, { KeyValuePattern[ "ItemName" -> item_String ] :> item, _ :> name } ];

agentSkillName[ name_String ] :=
    name;

agentSkillName[ skill: HoldPattern[ LLMSkill ][ as_Association ] ] :=
    Replace[ Lookup[ as, "Name" ], Except[ _String ] :> throwFailure[ "InvalidAgentSkill", skill ] ];

agentSkillName[ file: File[ _String ] ] :=
    Replace[ readSkillDirectory @ skillDirectoryPath @ file, KeyValuePattern[ "Name" -> name_ ] :> name ];

agentSkillName[ KeyValuePattern[ "Name" -> name_String ] ] :=
    name;

agentSkillName[ other_ ] :=
    throwFailure[ "InvalidAgentSkill", other ];

agentSkillName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validateSkillName*)
validateSkillName // beginDefinition;
validateSkillName[ name_ ] := If[ agentSkillNameQ @ name, name, throwFailure[ "InvalidAgentSkillName", name ] ];
validateSkillName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validateSkillDescription*)
(* Clients skip skills without a description, so installing one would silently do nothing. *)
validateSkillDescription // beginDefinition;

validateSkillDescription[ name_, description_String ] /;
    StringLength @ description <= 1024 && ! StringMatchQ[ description, WhitespaceCharacter... ] :=
        description;

validateSkillDescription[ name_, _ ] :=
    throwFailure[ "InvalidAgentSkillDescription", name ];

validateSkillDescription // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkDuplicateSkillNames*)
checkDuplicateSkillNames // beginDefinition;

checkDuplicateSkillNames[ sources: { ___Association } ] :=
    Replace[
        Select[ Tally[ #[ "Name" ] & /@ sources ], Last @ # > 1 & ],
        { { { name_, _ }, ___ } :> throwFailure[ "DuplicateAgentSkillName", name ], _ :> sources }
    ];

checkDuplicateSkillNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skill Sources*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toAgentSkillSource*)
(* Normalizes a skill specification to a skill source (see "Normalized skill source" in Specs/AgentToolsObject.md):
    <|
        "Name"            -> name,                     (* validated; the installed directory name *)
        "Description"     -> description,              (* validated *)
        "Identifier"      -> id | None,                (* source identity for upgrade decisions *)
        "Version"         -> version | Missing[ ],     (* paclet version for paclet skills *)
        "SourceDirectory" -> File[ dir ] | None,       (* the skill directory that is copied, if any *)
        "Files"           -> <| relPath -> File[ absoluteSourcePath ] | content_String, ... |>,  (* KeySort'ed *)
        "Manifest"        -> <| relPath -> sha256Hex, ... |>                                     (* KeySort'ed *)
    |>
   The defaultIdentifier is used for in-memory skills (LLMSkill objects without a usable location and association
   definitions); paclet and built-in skills use their qualified names, and directory sources use "File:<path>". *)
toAgentSkillSource // beginDefinition;

toAgentSkillSource[ spec_ ] :=
    toAgentSkillSource[ spec, None ];

(* LLMSkill objects (read as raw data, so this also works for deserialized skills) *)
toAgentSkillSource[ HoldPattern[ LLMSkill ][ as_Association ], default: _String | None ] :=
    With[ { dir = usableSkillLocation @ Lookup[ as, "Location", None ] },
        If[ StringQ @ dir,
            directorySkillSource[ dir, Lookup[ as, "Name" ], Lookup[ as, "Description" ] ],
            generatedSkillSource[ as, default ]
        ]
    ];

(* Skill directories *)
toAgentSkillSource[ file: File[ _String ], _ ] :=
    directorySkillSource @ file;

(* Paclet-qualified skill names *)
toAgentSkillSource[ name_String, _ ] /; pacletQualifiedNameQ @ name :=
    toAgentSkillSource[ resolvePacletSkill @ name, None ];

(* Built-in skills *)
toAgentSkillSource[ name_String, _ ] :=
    builtInSkillSource @ name;

(* Skill definitions returned by resolvePacletSkill *)
toAgentSkillSource[ definition: KeyValuePattern[ "Type" -> "PacletSkill" ], _ ] :=
    pacletSkillSource @ definition;

(* Association definitions *)
toAgentSkillSource[ as: KeyValuePattern[ "Name" -> _ ], default: _String | None ] :=
    generatedSkillSource[ as, default ];

toAgentSkillSource[ other_, _ ] :=
    throwFailure[ "InvalidAgentSkill", other ];

toAgentSkillSource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*usableSkillLocation*)
(* The directory of an LLMSkill's "Location" if it is an existing directory that contains SKILL.md (LLMSkill stores
   directory locations with a trailing separator, which is removed), otherwise None. *)
usableSkillLocation // beginDefinition;

usableSkillLocation[ File[ path_String ] ] :=
    With[ { dir = stripTrailingSeparators @ ExpandFileName @ path },
        If[ skillDirectoryQ @ dir, dir, None ]
    ];

usableSkillLocation[ _ ] :=
    None;

usableSkillLocation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*builtInSkillSource*)
builtInSkillSource // beginDefinition;

(* Built-in skills are identified by their name and versioned by the AgentTools version, so redeploying them after a
   paclet update is an update of the same source. *)
builtInSkillSource[ name_String ] := Enclose[
    Module[ { definition, source },
        definition = builtInSkillDefinition @ name;
        source = ConfirmBy[ toAgentSkillSource[ definition, name ], AssociationQ, "Source" ];
        ConfirmAssert[ source[ "Name" ] === name, "Name" ];
        <| source, "Identifier" -> name, "Version" -> $pacletVersion |>
    ],
    throwInternalFailure
];

builtInSkillSource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*builtInSkillDefinition*)
(* The definition of a built-in skill (a skill directory); fails with AgentSkillNotFound for other names. *)
builtInSkillDefinition // beginDefinition;

builtInSkillDefinition[ name_String ] :=
    Replace[
        Lookup[ $defaultAgentSkills, name, Missing[ "NotFound" ] ],
        {
            Missing[ "NotFound" ] :> throwFailure[ "AgentSkillNotFound", name ],
            _Missing              :> throwFailure[ "BuiltInAgentSkillMissing", name ]
        }
    ];

builtInSkillDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*builtInSkillDirectory*)
(* The directory of a built-in skill in the loaded paclet, or Missing[ "NotAvailable", name ] if the paclet does not
   contain it. This never fails, since evaluating Values[ $defaultAgentSkills ] resolves every skill. *)
builtInSkillDirectory // beginDefinition;

builtInSkillDirectory[ name_String ] :=
    Module[ { root, dir },
        root = Quiet @ $thisPaclet[ "AssetLocation", "AgentSkills" ];
        dir  = If[ StringQ @ root, FileNameJoin @ { root, name }, None ];
        If[ skillDirectoryQ @ dir, File @ dir, Missing[ "NotAvailable", name ] ]
    ];

builtInSkillDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*builtInSkillSourceQ*)
(* Only built-in skill sources have a bare skill name as their identifier (see toAgentSkillSource). *)
builtInSkillSourceQ // beginDefinition;

builtInSkillSourceQ[ source_Association ] :=
    With[ { id = Lookup[ source, "Identifier" ] }, StringQ @ id && KeyExistsQ[ $defaultAgentSkills, id ] ];

builtInSkillSourceQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*pacletSkillSource*)
(* Converts a skill definition (as returned by resolvePacletSkill) to a source. The skill is identified by its
   qualified name and versioned by its paclet version. An LLMSkill given as a "Definition" never uses its "Location"
   (resolvePacletSkill returns a "Directory" for locations that are honored). *)
pacletSkillSource // beginDefinition;

pacletSkillSource[ definition_Association ] := Enclose[
    Module[ { qualified, version, source },

        qualified = Lookup[ definition, "QualifiedName" ];
        If[ ! StringQ @ qualified, throwFailure[ "InvalidAgentSkill", definition ] ];
        version = Replace[ Lookup[ definition, "PacletVersion" ], Except[ _String ] :> Missing[ ] ];

        source = ConfirmBy[
            If[ MatchQ[ Lookup[ definition, "Directory" ], File[ _String ] ],
                directorySkillSource @ definition[ "Directory" ],
                definitionSkillSource[ Lookup[ definition, "Definition" ], qualified ]
            ],
            AssociationQ,
            "Source"
        ];

        If[ source[ "Name" ] =!= Lookup[ definition, "Name" ], throwFailure[ "InvalidPacletSkillDefinition", qualified ] ];

        <| source, "Identifier" -> qualified, "Version" -> version |>
    ],
    throwInternalFailure
];

pacletSkillSource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*definitionSkillSource*)
definitionSkillSource // beginDefinition;
definitionSkillSource[ HoldPattern[ LLMSkill ][ as_Association ], id_String ] := generatedSkillSource[ as, id ];
definitionSkillSource[ as_Association, id_String ] := generatedSkillSource[ as, id ];
definitionSkillSource[ _, id_String ] := throwFailure[ "InvalidPacletSkillDefinition", id ];
definitionSkillSource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*directorySkillSource*)
(* A skill directory in Agent Skills format: every entry (except junk and version-control metadata) is copied. *)
directorySkillSource // beginDefinition;

directorySkillSource[ file: File[ _String ] ] := Enclose[
    Module[ { dir, skill },
        dir   = skillDirectoryPath @ file;
        skill = ConfirmBy[ readSkillDirectory @ dir, AssociationQ, "Skill" ];
        directorySkillSource[ dir, Lookup[ skill, "Name" ], Lookup[ skill, "Description" ] ]
    ],
    throwInternalFailure
];

directorySkillSource[ dir_String, name0_, description0_ ] := Enclose[
    Module[ { name, description, listing, files },
        name        = validateSkillName @ name0;
        description = validateSkillDescription[ name, description0 ];
        listing     = ConfirmBy[ skillDirectoryListing @ dir, AssociationQ, "Listing" ];
        files       = ConfirmBy[ listing[ "Files" ], AssociationQ, "Files" ];
        If[ ! KeyExistsQ[ files, "SKILL.md" ], throwFailure[ "InvalidAgentSkill", File @ dir ] ];
        <|
            "Name"            -> name,
            "Description"     -> description,
            "Identifier"      -> "File:" <> canonicalPathKey @ dir,
            "Version"         -> Missing[ ],
            "SourceDirectory" -> File @ dir,
            "Files"           -> KeySort @ files,
            "Manifest"        -> ConfirmBy[ skillManifest @ files, AssociationQ, "Manifest" ]
        |>
    ],
    throwInternalFailure
];

directorySkillSource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillDirectoryPath*)
(* The absolute path of a skill directory given as File[dir] (or File[".../SKILL.md"]); fails with InvalidAgentSkill
   unless the directory contains SKILL.md. *)
skillDirectoryPath // beginDefinition;

skillDirectoryPath[ file: File[ path_String ] ] :=
    Module[ { expanded, dir },
        expanded = stripTrailingSeparators @ ExpandFileName @ path;
        dir = If[ FileNameTake @ expanded === "SKILL.md" && ! DirectoryQ @ expanded,
                  parentDirectory @ expanded,
                  expanded
              ];
        If[ skillDirectoryQ @ dir, dir, throwFailure[ "InvalidAgentSkill", file ] ]
    ];

skillDirectoryPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillDirectoryQ*)
skillDirectoryQ // beginDefinition;
skillDirectoryQ[ dir_String ] := DirectoryQ @ dir && FileType @ FileNameJoin @ { dir, "SKILL.md" } === File;
skillDirectoryQ[ _ ] := False;
skillDirectoryQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readSkillDirectory*)
(* The data of LLMSkill[ File[ dir ] ] (only the public constructor is used); fails with InvalidAgentSkill if SKILL.md
   cannot be parsed. *)
readSkillDirectory // beginDefinition;

readSkillDirectory[ dir_String ] :=
    Replace[
        Quiet @ LLMSkill @ File @ dir,
        {
            HoldPattern[ LLMSkill ][ as_Association ] :> as,
            _ :> Replace[ parseSkillMarkdown @ dir, Except[ _Association ] :> throwFailure[ "InvalidAgentSkill", File @ dir ] ]
        }
    ];

readSkillDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseSkillMarkdown*)
(* Reads the name, description, and body of a skill directory's SKILL.md with AgentTools' own YAML parser. This is the
   fallback for LLMSkill[File[dir]], which fails for frontmatter containing characters in U+0080-U+00FF (e.g. an accented letter),
   because it parses the decoded text with ImportString[..., "YAML"]. Returns the skill data or $Failed. *)
parseSkillMarkdown // beginDefinition;

parseSkillMarkdown[ dir_String ] :=
    Catch @ Module[ { file, text, parts, yaml },
        file = FileNameJoin @ { dir, "SKILL.md" };
        If[ ! FileExistsQ @ file, Throw @ $Failed ];
        text = Quiet @ ByteArrayToString[ ReadByteArray @ file, "UTF-8" ];
        If[ ! StringQ @ text, Throw @ $Failed ];
        text  = StringReplace[ text, "\r\n" -> "\n" ];
        parts = StringCases[ text, StartOfString ~~ "---\n" ~~ Shortest[ fm___ ] ~~ "\n---" ~~ body___ ~~ EndOfString :> { fm, body }, 1 ];
        If[ ! MatchQ[ parts, { { _String, _String } } ], Throw @ $Failed ];
        yaml = Quiet @ catchAlways @ importYAMLString @ parts[[ 1, 1 ]];
        If[ ! AssociationQ @ yaml || ! StringQ @ yaml[ "name" ], Throw @ $Failed ];
        DeleteMissing @ <|
            "Name"                  -> yaml[ "name" ],
            "Description"           -> Replace[ Lookup[ yaml, "description", "" ], Except[ _String ] -> "" ],
            "Location"              -> File @ dir,
            "License"               -> Lookup[ yaml, "license"      , Missing[ ] ],
            "Compatibility"         -> Lookup[ yaml, "compatibility", Missing[ ] ],
            "Metadata"              -> Lookup[ yaml, "metadata"     , Missing[ ] ],
            "AllowedTools"          -> Lookup[ yaml, "allowed-tools", Missing[ ] ],
            "AdditionalFrontmatter" -> Replace[
                KeyDrop[ yaml, { "name", "description", "license", "compatibility", "metadata", "allowed-tools" } ],
                <| |> -> Missing[ ]
            ],
            "Body"                  -> StringTrim @ parts[[ 1, 2 ]]
        |>
    ];

parseSkillMarkdown // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generatedSkillSource*)
(* A skill without a usable directory: SKILL.md is generated from its fields. *)
generatedSkillSource // beginDefinition;

generatedSkillSource[ as_Association, identifier: _String | None ] := Enclose[
    Module[ { name, description, content },
        If[ ! KeyExistsQ[ as, "Name" ], throwFailure[ "InvalidAgentSkill", as ] ];
        name        = validateSkillName @ as[ "Name" ];
        description = validateSkillDescription[ name, Lookup[ as, "Description" ] ];
        If[ ! StringQ @ Lookup[ as, "Body", "" ], throwFailure[ "InvalidAgentSkill", as ] ];
        content = ConfirmBy[ generateSkillMarkdown @ as, StringQ, "Content" ];
        <|
            "Name"            -> name,
            "Description"     -> description,
            "Identifier"      -> identifier,
            "Version"         -> Missing[ ],
            "SourceDirectory" -> None,
            "Files"           -> <| "SKILL.md" -> content |>,
            "Manifest"        -> <| "SKILL.md" -> ConfirmBy[ skillFileHash @ content, StringQ, "Hash" ] |>
        |>
    ],
    throwInternalFailure
];

generatedSkillSource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Generated SKILL.md*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateSkillMarkdown*)
(* Deterministic: identical input gives byte-identical content (so redeploys don't look like modifications). Line
   endings are "\n" and the content ends with exactly one newline. Frontmatter is passed through as given. *)
generateSkillMarkdown // beginDefinition;

generateSkillMarkdown[ as_Association ] := Enclose[
    Module[ { additional, allowedTools, frontmatter, yaml, body },

        additional = toFrontmatterAssociation @ Lookup[ as, "AdditionalFrontmatter", <| |> ];

        (* LLMFunctions reads "allowed-Tools" (sic) from SKILL.md, so a standard "allowed-tools" key ends up in the
           additional frontmatter of a parsed skill *)
        allowedTools = SelectFirst[
            {
                Lookup[ as, "AllowedTools" ],
                Lookup[ additional, "allowed-tools" ],
                Lookup[ additional, "allowed-Tools" ]
            },
            ! MatchQ[ #, $$absent ] &,
            Missing[ ]
        ];

        frontmatter = DeleteMissing @ <|
            "name"          -> as[ "Name" ],
            "description"   -> as[ "Description" ],
            "license"       -> presentValue @ Lookup[ as, "License" ],
            "compatibility" -> presentValue @ Lookup[ as, "Compatibility" ],
            "allowed-tools" -> allowedTools,
            "metadata"      -> toMetadataStrings @ Lookup[ as, "Metadata" ]
        |>;

        frontmatter = Join[ frontmatter, KeyDrop[ additional, $reservedFrontmatterKeys ] ];
        yaml = ConfirmBy[ exportYAMLString @ frontmatter, StringQ, "YAML" ];
        body = normalizeSkillBody @ Lookup[ as, "Body", "" ];

        StringJoin[ "---\n", yaml, "\n---\n", If[ body === "", "", { "\n", body, "\n" } ] ]
    ],
    throwInternalFailure
];

generateSkillMarkdown // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toFrontmatterAssociation*)
toFrontmatterAssociation // beginDefinition;
toFrontmatterAssociation[ as_Association ] := KeyMap[ ToString, as ];
toFrontmatterAssociation[ rules: { (_Rule|_RuleDelayed)... } ] := toFrontmatterAssociation @ Association @ rules;
toFrontmatterAssociation[ _ ] := <| |>;
toFrontmatterAssociation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*presentValue*)
presentValue // beginDefinition;
presentValue[ $$absent ] := Missing[ ];
presentValue[ value_ ] := value;
presentValue // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toMetadataStrings*)
(* The Agent Skills format defines metadata as a map from strings to strings. *)
toMetadataStrings // beginDefinition;

toMetadataStrings[ as_Association ] :=
    Replace[ KeyMap[ ToString, toMetadataString /@ as ], <| |> -> Missing[ ] ];

toMetadataStrings[ rules: { (_Rule|_RuleDelayed).. } ] :=
    toMetadataStrings @ Association @ rules;

toMetadataStrings[ _ ] :=
    Missing[ ];

toMetadataStrings // endDefinition;

toMetadataString // beginDefinition;
toMetadataString[ value_String ] := value;
toMetadataString[ True ] := "true";
toMetadataString[ False ] := "false";
toMetadataString[ value_Integer ] := IntegerString @ value;
toMetadataString[ value_Real ] := Developer`WriteRawJSONString @ value;
toMetadataString[ value_ ] := TextString @ value;
toMetadataString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*normalizeSkillBody*)
normalizeSkillBody // beginDefinition;

normalizeSkillBody[ body_String ] :=
    StringReplace[
        StringReplace[ body, { "\r\n" -> "\n", "\r" -> "\n" } ],
        { StartOfString ~~ "\n".. -> "", WhitespaceCharacter.. ~~ EndOfString -> "" }
    ];

normalizeSkillBody // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Hashing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillManifest*)
(* A manifest is a KeySort'ed association of relative paths ("/"-separated) to SHA-256 hashes:
    skillManifest[ files_Association ]  - from the "Files" of a skill source (File[...] or String values); a file
                                          that can't be read fails with AgentSkillUnreadable
    skillManifest[ File[ dir ] ]        - from an installed directory (junk and version-control entries skipped), or
                                          None if a file can't be read (see installedSkillManifest) *)
skillManifest // beginDefinition;

skillManifest[ files_Association ] := Enclose[
    Module[ { hashes, unreadable },
        hashes     = skillFileHash /@ files;
        unreadable = FirstCase[ hashes, Missing[ "Unreadable", path_String ] :> path, None ];
        If[ StringQ @ unreadable, throwFailure[ "AgentSkillUnreadable", File @ unreadable ] ];
        KeySort @ ConfirmBy[ hashes, AllTrue[ #, StringQ ] &, "Hashes" ]
    ],
    throwInternalFailure
];

skillManifest[ File[ dir_String ] ] := Enclose[
    installedSkillManifest @ ConfirmBy[ skillDirectoryListing[ dir ][ "Files" ], AssociationQ, "Files" ],
    throwInternalFailure
];

skillManifest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installedSkillManifest*)
(* The manifest of the files of an installed directory, or None if any of them can't be read (e.g. mode 000, a file
   owned by another user, or an offline cloud placeholder). An installed directory with an unreadable file is never
   identical to anything, so it counts as "Modified": it is kept on release, and replacing it needs a conflict to be
   overridden. *)
installedSkillManifest // beginDefinition;

installedSkillManifest[ files_Association ] :=
    With[ { hashes = skillFileHash /@ files },
        If[ AllTrue[ hashes, StringQ ], KeySort @ hashes, None ]
    ];

installedSkillManifest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillFileHash*)
(* SHA-256 of the bytes, with CRLF line endings normalized to LF for content without NUL bytes, so a checkout with
   CRLF line endings (git core.autocrlf) is still recognized as identical. A file that can't be read gives
   Missing[ "Unreadable", path ] (sources turn that into AgentSkillUnreadable; installed directories into "Modified"). *)
skillFileHash // beginDefinition;

skillFileHash[ File[ path_String ] ] :=
    Module[ { bytes },
        bytes = Quiet @ ReadByteArray @ path;
        If[ bytes === EndOfFile, bytes = ByteArray[ { } ] ];
        If[ ByteArrayQ @ bytes, normalizedHash @ bytes, Missing[ "Unreadable", path ] ]
    ];

skillFileHash[ content_String ] :=
    normalizedHash @ StringToByteArray[ content, "UTF-8" ];

skillFileHash // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*normalizedHash*)
normalizedHash // beginDefinition;

normalizedHash[ bytes_ByteArray ] /; Length @ bytes === 0 :=
    Hash[ bytes, "SHA256", "HexString" ];

(* ISO8859-1 maps every byte to exactly one character, so this round trip is lossless *)
normalizedHash[ bytes_ByteArray ] :=
    With[ { string = ByteArrayToString[ bytes, "ISO8859-1" ] },
        If[ StringFreeQ[ string, $nul ] && StringContainsQ[ string, "\r\n" ],
            Hash[ StringToByteArray[ StringReplace[ string, "\r\n" -> "\n" ], "ISO8859-1" ], "SHA256", "HexString" ],
            Hash[ bytes, "SHA256", "HexString" ]
        ]
    ];

normalizedHash // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillDirectoryListing*)
(* Recursively lists a skill directory, following symbolic links (without cycles):
    <| "Files" -> <| relPath -> File[ absolutePath ], ... |>, "VCS" -> True | False |>
   Junk entries are skipped, and version-control metadata is reported in "VCS" instead of being listed. *)
skillDirectoryListing // beginDefinition;

skillDirectoryListing[ File[ dir_String ] ] :=
    skillDirectoryListing @ dir;

skillDirectoryListing[ dir_String ] := Enclose[
    Module[ { root, reaped, files, vcs },
        root   = ConfirmBy[ Quiet @ AbsoluteFileName @ dir, StringQ, "Root" ];
        reaped = Last @ Reap[ sowSkillEntries[ dir, { }, { root } ], { "File", "VCS" } ];
        files  = Flatten @ First @ reaped;
        vcs    = Flatten @ Last @ reaped;
        <| "Files" -> KeySort @ Association @ files, "VCS" -> vcs =!= { } |>
    ],
    throwInternalFailure
];

skillDirectoryListing // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sowSkillEntries*)
sowSkillEntries // beginDefinition;

sowSkillEntries[ dir_String, prefix_List, ancestors_List ] :=
    Scan[ sowSkillEntry[ #, prefix, ancestors ] &, FileNames[ All, dir ] ];

sowSkillEntries // endDefinition;

sowSkillEntry // beginDefinition;

sowSkillEntry[ path_String, prefix_List, ancestors_List ] :=
    Module[ { name, type, relative, resolved },
        name     = FileNameTake @ path;
        type     = FileType @ path; (* follows symbolic links; None for dangling links *)
        relative = Append[ prefix, name ];
        Which[
            vcsNameQ @ name,
                Sow[ relative, "VCS" ],
            type === Directory && junkDirectoryNameQ @ name,
                Null,
            type === Directory,
                resolved = Quiet @ AbsoluteFileName @ path;
                If[ StringQ @ resolved && ! MemberQ[ ancestors, resolved ] && Length @ relative < $maxSkillDirectoryDepth,
                    sowSkillEntries[ path, relative, Append[ ancestors, resolved ] ]
                ],
            type === File && junkFileNameQ @ name,
                Null,
            type === File,
                Sow[ StringRiffle[ relative, "/" ] -> File @ path, "File" ],
            True,
                Null
        ]
    ];

sowSkillEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Entry kinds*)
vcsNameQ // beginDefinition;
vcsNameQ[ name_String ] := MemberQ[ $vcsNames, ToLowerCase @ name ];
vcsNameQ // endDefinition;

junkFileNameQ // beginDefinition;
junkFileNameQ[ name_String ] := MemberQ[ $junkFileNames, ToLowerCase @ name ];
junkFileNameQ // endDefinition;

junkDirectoryNameQ // beginDefinition;
junkDirectoryNameQ[ name_String ] := MemberQ[ $junkDirectoryNames, ToLowerCase @ name ];
junkDirectoryNameQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*compareSkillManifest*)
(* Compares an installed directory against a baseline manifest:
    "Missing"    - nothing exists at the path
    "Unmodified" - every baseline file exists with the same hash, there are no other non-junk files, and there is no
                   version-control metadata
    "Modified"   - anything else (including a directory that can't be resolved or a file that can't be read) *)
compareSkillManifest // beginDefinition;

compareSkillManifest[ File[ dir_String ], baseline_Association ] := Enclose[
    Catch @ Module[ { listing, files },
        If[ ! DirectoryQ @ dir, Throw @ If[ entryExistsQ @ dir, "Modified", "Missing" ] ];
        If[ ! StringQ @ Quiet @ AbsoluteFileName @ dir, Throw[ "Modified" ] ];
        listing = ConfirmBy[ skillDirectoryListing @ dir, AssociationQ, "Listing" ];
        files   = ConfirmBy[ listing[ "Files" ], AssociationQ, "Files" ];
        Which[
            TrueQ @ listing[ "VCS" ], "Modified",
            Sort @ Keys @ files =!= Sort @ Keys @ baseline, "Modified",
            manifestsEqualQ[ installedSkillManifest @ files, baseline ], "Unmodified",
            True, "Modified"
        ]
    ],
    throwInternalFailure
];

compareSkillManifest[ File[ _String ], _ ] :=
    "Modified";

compareSkillManifest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*manifestsEqualQ*)
manifestsEqualQ // beginDefinition;
manifestsEqualQ[ a_Association, b_Association ] := KeySort @ a === KeySort @ b;
manifestsEqualQ[ _, _ ] := False;
manifestsEqualQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*diskManifest*)
(* The manifest of an existing destination entry (a directory or a link to one), or None if it can't be listed or a
   file in it can't be read (None is never equal to a manifest, so such a destination counts as different content). *)
diskManifest // beginDefinition;

diskManifest[ dir_String ] :=
    If[ DirectoryQ @ dir && StringQ @ Quiet @ AbsoluteFileName @ dir, skillManifest @ File @ dir, None ];

diskManifest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paths*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*canonicalPath*)
(* The AbsoluteFileName of the deepest existing ancestor of path (which resolves symbolic links), joined with the
   remaining path components. Returns a string in the native form (not case-folded); see canonicalPathKey for
   comparisons. *)
canonicalPath // beginDefinition;

canonicalPath[ File[ path_String ] ] :=
    canonicalPath @ path;

canonicalPath[ path_String ] := Enclose[
    Catch @ Module[ { expanded, parts, prefix, resolved },
        expanded = ConfirmBy[ ExpandFileName @ path, StringQ, "Expanded" ];
        parts    = FileNameSplit @ expanded;
        Do[
            prefix = FileNameJoin @ Take[ parts, i ];
            If[ StringQ @ prefix && prefix =!= "" && FileExistsQ @ prefix,
                resolved = Quiet @ AbsoluteFileName @ prefix;
                If[ StringQ @ resolved,
                    Throw @ stripTrailingSeparators @ FileNameJoin @ Prepend[ Drop[ parts, i ], resolved ]
                ]
            ],
            { i, Length @ parts, 1, -1 }
        ];
        expanded
    ],
    throwInternalFailure
];

canonicalPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*canonicalPathKey*)
(* A comparison key for paths: the canonical path with "/" separators, case-folded on Windows and macOS (whose file
   systems are usually case-insensitive). Used for registry keys, "File:" identifiers, and path comparisons. *)
canonicalPathKey // beginDefinition;
canonicalPathKey[ path: _String | File[ _String ] ] := foldPathCase @ StringReplace[ canonicalPath @ path, "\\" -> "/" ];
canonicalPathKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*foldPathCase*)
foldPathCase // beginDefinition;
foldPathCase[ path_String ] := If[ MemberQ[ { "Windows", "MacOSX" }, $OperatingSystem ], ToLowerCase @ path, path ];
foldPathCase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stripTrailingSeparators*)
stripTrailingSeparators // beginDefinition;

stripTrailingSeparators[ path_String ] :=
    With[ { stripped = StringDelete[ path, ("/" | "\\").. ~~ EndOfString ] },
        If[ stripped === "" || StringMatchQ[ stripped, LetterCharacter ~~ ":" ], path, stripped ]
    ];

stripTrailingSeparators // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parentDirectory*)
parentDirectory // beginDefinition;
parentDirectory[ path_String ] := FileNameDrop[ stripTrailingSeparators @ path, -1 ];
parentDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*entryExistsQ*)
(* Like FileExistsQ, but also True for dangling symbolic links. *)
entryExistsQ // beginDefinition;

entryExistsQ[ path_String ] :=
    TrueQ @ Or[
        FileExistsQ @ path,
        With[ { parent = parentDirectory @ path, name = FileNameTake @ path },
            DirectoryQ @ parent && MemberQ[ FileNameTake /@ FileNames[ All, parent ], name ]
        ]
    ];

entryExistsQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sourceDestinationRelation*)
(* "Same" if a directory source is the destination itself (the skill is already installed), "Distinct" otherwise.
   A source inside the destination or vice versa fails with InvalidAgentSkill. *)
sourceDestinationRelation // beginDefinition;

sourceDestinationRelation[ KeyValuePattern[ "SourceDirectory" -> File[ source_String ] ], destination_String ] :=
    Module[ { s, d },
        s = canonicalPathKey @ source;
        d = canonicalPathKey @ destination;
        Which[
            s === d, "Same",
            StringStartsQ[ d, s <> "/" ] || StringStartsQ[ s, d <> "/" ], throwFailure[ "InvalidAgentSkill", File @ source ],
            True, "Distinct"
        ]
    ];

sourceDestinationRelation[ _Association, _String ] :=
    "Distinct";

sourceDestinationRelation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inspecting Destinations*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillDirectoryState*)
(* Classifies root/name as one of:
    "Missing"   - not listed in root
    "Dangling"  - listed, but FileType is None (a dangling symbolic link)
    "File"      - a file (or a link to one)
    "Link"      - a directory whose resolved path differs from the resolved root joined with name
    "Directory" - a regular directory *)
skillDirectoryState // beginDefinition;

skillDirectoryState[ File[ dir_String ] ] :=
    With[ { path = stripTrailingSeparators @ ExpandFileName @ dir },
        skillDirectoryState[ File @ parentDirectory @ path, FileNameTake @ path ]
    ];

skillDirectoryState[ File[ root_String ], name_String ] :=
    Module[ { path, type },
        path = FileNameJoin @ { root, name };
        type = FileType @ path;
        Which[
            ! DirectoryQ @ root, "Missing",
            ! MemberQ[ foldPathCase /@ FileNameTake /@ FileNames[ All, root ], foldPathCase @ name ], "Missing",
            type === None, "Dangling",
            type === Directory, If[ linkedDirectoryQ[ root, name ], "Link", "Directory" ],
            True, "File"
        ]
    ];

skillDirectoryState // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*linkedDirectoryQ*)
linkedDirectoryQ // beginDefinition;

linkedDirectoryQ[ root_String, name_String ] :=
    Module[ { resolved, resolvedRoot },
        resolved     = Quiet @ AbsoluteFileName @ FileNameJoin @ { root, name };
        resolvedRoot = Quiet @ AbsoluteFileName @ root;
        ! TrueQ @ And[
            StringQ @ resolved,
            StringQ @ resolvedRoot,
            foldPathCase @ resolved === foldPathCase @ FileNameJoin @ { resolvedRoot, name }
        ]
    ];

linkedDirectoryQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Writing Skill Directories*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createSkillDirectory*)
(* Creates root/name (and the root if needed) and writes every entry of the source's "Files". A partially written
   directory is deleted before failing with AgentSkillWriteFailed. *)
createSkillDirectory // beginDefinition;

createSkillDirectory[ dest_String, name_String, files_Association ] :=
    Module[ { created = False, done = False },
        WithCleanup[
            Quiet[
                created = StringQ @ CreateDirectory @ dest;
                done = created && Catch[
                    KeyValueMap[ If[ ! TrueQ @ writeSkillFile[ dest, #1, #2 ], Throw @ False ] &, files ];
                    True
                ]
            ],
            If[ created && ! done, Quiet @ DeleteDirectory[ dest, DeleteContents -> True ] ]
        ];
        If[ ! done, throwFailure[ "AgentSkillWriteFailed", name, File @ dest ] ];
        makeSkillFilesExecutable[ dest, files ];
        File @ dest
    ];

createSkillDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeSkillFile*)
writeSkillFile // beginDefinition;

writeSkillFile[ dest_String, relative_String, source_ ] :=
    Module[ { parts, target, parent },
        parts = StringSplit[ relative, "/" ];
        If[ ! safeRelativePathQ @ parts,
            False,
            target = FileNameJoin @ Prepend[ parts, dest ];
            parent = parentDirectory @ target;
            If[ ! DirectoryQ @ parent, CreateDirectory @ parent ];
            writeSkillFileContent[ target, source ]
        ]
    ];

writeSkillFile // endDefinition;

safeRelativePathQ // beginDefinition;
safeRelativePathQ[ parts: { __String } ] := ! MemberQ[ parts, "" | "." | ".." ];
safeRelativePathQ[ _ ] := False;
safeRelativePathQ // endDefinition;

writeSkillFileContent // beginDefinition;
writeSkillFileContent[ target_String, File[ source_String ] ] := StringQ @ CopyFile[ source, target ]; (* follows links *)
writeSkillFileContent[ target_String, content_String ] := writeBytes[ target, StringToByteArray[ content, "UTF-8" ] ];
writeSkillFileContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeBytes*)
(* Writes bytes to target and returns True only if the file now holds all of them. Write errors (e.g. a full disk or
   an exceeded quota) often surface only when the stream is flushed, without any failure from BinaryWrite or Close, so
   the size of the written file is checked as well. *)
writeBytes // beginDefinition;

writeBytes[ target_String, bytes_ ] :=
    Module[ { expected, stream, written = True, closed = False },
        expected = If[ ByteArrayQ @ bytes, Length @ bytes, 0 ];
        stream   = Quiet @ OpenWrite[ target, BinaryFormat -> True ];
        If[ MatchQ[ stream, _OutputStream ],
            WithCleanup[
                If[ expected > 0, written = ! FailureQ @ Quiet @ BinaryWrite[ stream, bytes ] ],
                closed = ! FailureQ @ Quiet @ Close @ stream
            ];
            TrueQ @ And[ written, closed, FileExistsQ @ target, Quiet @ FileByteCount @ target === expected ],
            False
        ]
    ];

writeBytes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeSkillFilesExecutable*)
(* On Unix-like systems, a copied file that is executable in the source or starts with "#!" is made executable,
   because .paclet archives drop file modes. Modes are not part of the hashes. *)
makeSkillFilesExecutable // beginDefinition;

makeSkillFilesExecutable[ dest_String, files_Association ] /; $OperatingSystem =!= "Windows" :=
    Module[ { targets },
        targets = KeyValueMap[
            If[ executableSourceQ @ #2, FileNameJoin @ Prepend[ StringSplit[ #1, "/" ], dest ], Nothing ] &,
            files
        ];
        If[ targets =!= { }, Quiet @ RunProcess @ Join[ { "chmod", "+x" }, targets ] ];
        targets
    ];

makeSkillFilesExecutable[ _, _ ] :=
    { };

makeSkillFilesExecutable // endDefinition;

executableSourceQ // beginDefinition;
executableSourceQ[ File[ source_String ] ] := executableFileQ @ source || shebangFileQ @ source;
executableSourceQ[ content_String ] := StringStartsQ[ content, "#!" ];
executableSourceQ // endDefinition;

executableFileQ // beginDefinition;
executableFileQ[ file_String ] := With[ { p = Quiet @ FileInformation[ file, "Permissions" ] }, IntegerQ @ p && BitAnd[ p, 8^^111 ] =!= 0 ];
executableFileQ // endDefinition;

shebangFileQ // beginDefinition;
shebangFileQ[ file_String ] := Quiet @ BinaryReadList[ file, "Byte", 2 ] === ToCharacterCode[ "#!" ];
shebangFileQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*moveSkillEntryToBackup*)
(* Moves an existing entry out of the skills root to <parent of root>/.agenttools-backup-<uuid> (same volume, and not
   visible to clients as a skill). Links, dangling links, and files are moved as themselves. Returns the backup path,
   or $Failed if the entry could not be moved (e.g. a file in use on Windows), in which case nothing was changed. *)
moveSkillEntryToBackup // beginDefinition;

moveSkillEntryToBackup[ root_String, path_String, state: $$skillState ] :=
    With[ { backup = FileNameJoin @ { parentDirectory @ root, $skillBackupPrefix <> CreateUUID[ ] } },
        If[ moveSkillEntry[ path, backup, state ], backup, $Failed ]
    ];

moveSkillEntryToBackup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*moveSkillEntry*)
moveSkillEntry // beginDefinition;

moveSkillEntry[ source_String, target_String, state: $$skillState ] := (
    Quiet @ If[ state === "Directory", RenameDirectory[ source, target ], RenameFile[ source, target ] ];
    (* RenameFile can't move dangling symbolic links *)
    If[ $OperatingSystem =!= "Windows" && entryExistsQ @ source && ! entryExistsQ @ target,
        Quiet @ RunProcess @ { "mv", source, target }
    ];
    entryExistsQ @ target && ! entryExistsQ @ source
);

moveSkillEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deleteSkillEntry*)
(* Deletes an entry as itself: a directory with its contents (symbolic links inside it are not followed), a link to a
   directory as a link (its target is untouched), or a file. Returns True if the entry is gone. *)
deleteSkillEntry // beginDefinition;

deleteSkillEntry[ path_String, state: $$skillState ] := (
    Quiet @ Switch[ state,
        "Directory", DeleteDirectory[ path, DeleteContents -> True ],
        "Link"     , DeleteDirectory @ path,
        _          , DeleteFile @ path
    ];
    If[ state =!= "Directory" && entryExistsQ @ path,
        Quiet @ DeleteFile @ path;
        (* rm without -r never removes a directory, only a link to one *)
        If[ $OperatingSystem =!= "Windows" && entryExistsQ @ path, Quiet @ RunProcess @ { "rm", "-f", path } ]
    ];
    ! entryExistsQ @ path
);

deleteSkillEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*replaceSkillEntry*)
(* Replaces the existing entry root/name with a new skill directory: the entry is first moved to a backup, then the
   new directory is created. If creating fails, the backup is moved back. Returns the backup path, which the caller
   deletes once the replacement is final (deleteSkillEntry[ backup, state ]) or restores (restoreSkillBackup). *)
replaceSkillEntry // beginDefinition;

replaceSkillEntry[ root_String, name_String, state: $$skillState, files_Association ] :=
    Module[ { dest, backup, done = False },
        dest   = FileNameJoin @ { root, name };
        backup = moveSkillEntryToBackup[ root, dest, state ];
        If[ ! StringQ @ backup, throwFailure[ "AgentSkillRemoveFailed", name, File @ dest ] ];
        WithCleanup[
            createSkillDirectory[ dest, name, files ];
            done = True,
            If[ ! done, restoreSkillBackup[ dest, backup, state ] ]
        ];
        backup
    ];

replaceSkillEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*restoreSkillBackup*)
(* Undoes a replacement: deletes the directory that was created at dest and moves the backup back. *)
restoreSkillBackup // beginDefinition;

restoreSkillBackup[ dest_String, backup_String, state: $$skillState ] := (
    If[ entryExistsQ @ dest, deleteSkillEntry[ dest, "Directory" ] ];
    moveSkillEntry[ backup, dest, state ]
);

restoreSkillBackup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeSkillEntry*)
(* Removes root/name by moving it to a backup and deleting the backup. If the move fails, nothing is deleted and the
   result is False. The result is True once the entry has left the root, even if the backup could not be deleted
   completely (e.g. a read-only subdirectory); that is reported with AgentSkillBackupNotRemoved (see
   deleteSkillBackup). *)
removeSkillEntry // beginDefinition;

removeSkillEntry[ root_String, name_String, state: $$skillState ] :=
    With[ { backup = moveSkillEntryToBackup[ root, FileNameJoin @ { root, name }, state ] },
        If[ StringQ @ backup, deleteSkillBackup[ name, backup, state ]; True, False ]
    ];

removeSkillEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deleteSkillBackup*)
(* Deletes the backup of a removed or replaced skill entry. Returns True if it is gone; otherwise it reports the
   leftover path with AgentSkillBackupNotRemoved (so a hidden partial copy is never left behind silently) and returns
   False. *)
deleteSkillBackup // beginDefinition;

deleteSkillBackup[ name_String, backup_String, state: $$skillState ] :=
    If[ TrueQ @ deleteSkillEntry[ backup, state ],
        True,
        messagePrint[ "AgentSkillBackupNotRemoved", name, File @ backup ];
        False
    ];

deleteSkillBackup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*runSkillUndo*)
(* Runs undo actions (zero-argument functions) in reverse order of registration, ignoring failures. *)
runSkillUndo // beginDefinition;
runSkillUndo[ actions_List ] := Scan[ Quiet @ catchAlways[ #[ ] ] &, Reverse @ actions ];
runSkillUndo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skills Roots*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveSkillsRoot*)
(* Resolves an InstallAgentSkills/UninstallAgentSkills target:
    "ClientName"           - the client's user-scope skills root (skillsLocation)
    { "ClientName", dir }  - the client's project-scope skills root (projectSkillsLocation)
    File[ root ]           - a directory that contains skill folders
   Returns <| "Root" -> File[ root ], "ClientName" -> name | None |>. *)
resolveSkillsRoot // beginDefinition;

resolveSkillsRoot[ File[ root_String ] ] :=
    <| "Root" -> validateSkillsRoot @ root, "ClientName" -> None |>;

resolveSkillsRoot[ name_String ] :=
    With[ { client = toInstallName @ name },
        <| "Root" -> validateSkillsRoot @ skillsLocation @ client, "ClientName" -> client |>
    ];

resolveSkillsRoot[ { name_String, dir_ } ] :=
    With[ { client = toInstallName @ name },
        <| "Root" -> validateSkillsRoot @ projectSkillsLocation[ client, dir ], "ClientName" -> client |>
    ];

resolveSkillsRoot[ other_ ] :=
    throwFailure[ "InvalidSkillsDirectory", other ];

resolveSkillsRoot // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validateSkillsRoot*)
(* A skills root must not be a file or itself a skill directory (i.e. contain SKILL.md). *)
validateSkillsRoot // beginDefinition;

validateSkillsRoot[ File[ root_String ] ] :=
    validateSkillsRoot @ root;

validateSkillsRoot[ root0_String ] :=
    With[ { root = stripTrailingSeparators @ ExpandFileName @ root0 },
        If[ (FileExistsQ @ root && ! DirectoryQ @ root) || FileExistsQ @ FileNameJoin @ { root, "SKILL.md" },
            throwFailure[ "InvalidSkillsDirectory", File @ root0 ],
            File @ root
        ]
    ];

validateSkillsRoot[ other_ ] :=
    throwFailure[ "InvalidSkillsDirectory", other ];

validateSkillsRoot // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillSpecList*)
(* { specs, single }: the skill specifications given to InstallAgentSkills/UninstallAgentSkills, and whether a single
   result should be returned. *)
skillSpecList // beginDefinition;
skillSpecList[ specs_List ] := { specs, False };
skillSpecList[ obj_AgentToolsObject? agentToolsObjectQ ] := { Replace[ obj[ "Data" ][ "AgentSkills" ], Except[ _List ] -> { } ], False };
skillSpecList[ spec_ ] := { { spec }, True };
skillSpecList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*normalizeOverwrite*)
normalizeOverwrite // beginDefinition;
normalizeOverwrite[ All ] := All;
normalizeOverwrite[ True ] := True;
normalizeOverwrite[ _ ] := False;
normalizeOverwrite // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InstallAgentSkills*)
InstallAgentSkills // beginDefinition;
InstallAgentSkills // Options = { OverwriteTarget -> False };

InstallAgentSkills[ target_, skills_, opts: OptionsPattern[ ] ] :=
    catchMine @ installAgentSkills[ target, skills, normalizeOverwrite @ OptionValue @ OverwriteTarget ];

InstallAgentSkills // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*installAgentSkills*)
(* Low-level installation: no references or hashes are kept, and the skill registry is not modified. Every
   destination is classified before anything is written; skills already written by this call are rolled back if a
   later one fails. *)
installAgentSkills // beginDefinition;

installAgentSkills[ target_, skills_, overwrite: $$overwrite ] := Enclose[
    Module[ { resolved, root, client, specs, single, sources, plans, results },

        resolved = ConfirmBy[ resolveSkillsRoot @ target, AssociationQ, "Resolved" ];
        root     = ConfirmBy[ First @ resolved[ "Root" ], StringQ, "Root" ];
        client   = resolved[ "ClientName" ];

        { specs, single } = skillSpecList @ skills;
        sources = ConfirmMatch[ toAgentSkillSource[ #, None ] & /@ specs, { ___Association }, "Sources" ];
        checkDuplicateSkillNames @ sources;

        plans = ConfirmMatch[ lowLevelInstallPlan[ #, root, overwrite ] & /@ sources, { ___Association }, "Plans" ];
        applyLowLevelInstall @ plans;

        results = installAgentSkillSuccess[ #, client ] & /@ plans;
        If[ single, ConfirmMatch[ First @ results, _Success, "Result" ], results ]
    ],
    throwInternalFailure
];

installAgentSkills // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*lowLevelInstallPlan*)
(* Preflight for one skill: "None" (identical content, or the source is the destination), "Create", or "Replace".
   An existing entry with different content fails with AgentSkillExists unless overwriting. *)
lowLevelInstallPlan // beginDefinition;

lowLevelInstallPlan[ source_Association, root_String, overwrite: $$overwrite ] := Enclose[
    Module[ { name, dest, state, action },
        name  = ConfirmBy[ source[ "Name" ], StringQ, "Name" ];
        dest  = FileNameJoin @ { root, name };
        state = If[ sourceDestinationRelation[ source, dest ] === "Same",
                    "Same",
                    ConfirmMatch[ skillDirectoryState[ File @ root, name ], $$skillState, "State" ]
                ];
        action = Which[
            state === "Same", "None",
            state === "Missing", "Create",
            MatchQ[ state, "Directory" | "Link" ] && manifestsEqualQ[ diskManifest @ dest, source[ "Manifest" ] ], "None",
            overwrite =!= False, "Replace",
            True, throwFailure[ "AgentSkillExists", name, File @ dest, True ]
        ];
        <| "Name" -> name, "Root" -> root, "Directory" -> dest, "State" -> state, "Action" -> action, "Source" -> source |>
    ],
    throwInternalFailure
];

lowLevelInstallPlan // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*applyLowLevelInstall*)
applyLowLevelInstall // beginDefinition;

applyLowLevelInstall[ plans: { ___Association } ] :=
    Module[ { undo = { }, finalize = { }, success = False },
        WithCleanup[
            Scan[
                Function[ plan,
                    Switch[ plan[ "Action" ],
                        "Create",
                            createSkillDirectory[ plan[ "Directory" ], plan[ "Name" ], plan[ "Source", "Files" ] ];
                            AppendTo[ undo, With[ { d = plan[ "Directory" ] }, deleteSkillEntry[ d, "Directory" ] & ] ],
                        "Replace",
                            With[
                                {
                                    d = plan[ "Directory" ],
                                    s = plan[ "State" ],
                                    n = plan[ "Name" ],
                                    b = replaceSkillEntry[ plan[ "Root" ], plan[ "Name" ], plan[ "State" ], plan[ "Source", "Files" ] ]
                                },
                                AppendTo[ undo, restoreSkillBackup[ d, b, s ] & ];
                                AppendTo[ finalize, deleteSkillBackup[ n, b, s ] & ]
                            ],
                        _,
                            Null
                    ]
                ],
                plans
            ];
            success = True,
            (* finalizing only deletes backups: failures are reported (AgentSkillBackupNotRemoved), never thrown *)
            If[ success, Scan[ Quiet[ catchAlways[ #[ ] ], General::AgentToolsInternal ] &, finalize ], runSkillUndo @ undo ]
        ]
    ];

applyLowLevelInstall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*installAgentSkillSuccess*)
installAgentSkillSuccess // beginDefinition;

installAgentSkillSuccess[ plan_Association, client_String ] :=
    Success[
        "InstallAgentSkills",
        <|
            "MessageTemplate"   :> AgentTools::InstallAgentSkillNamed,
            "MessageParameters" -> { plan[ "Name" ], installDisplayName @ client },
            "Name"              -> plan[ "Name" ],
            "Location"          -> File @ plan[ "Directory" ],
            "ClientName"        -> client
        |>
    ];

installAgentSkillSuccess[ plan_Association, None ] :=
    Success[
        "InstallAgentSkills",
        <|
            "MessageTemplate"   :> AgentTools::InstallAgentSkill,
            "MessageParameters" -> { plan[ "Name" ] },
            "Name"              -> plan[ "Name" ],
            "Location"          -> File @ plan[ "Directory" ],
            "ClientName"        -> None
        |>
    ];

installAgentSkillSuccess // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*UninstallAgentSkills*)
UninstallAgentSkills // beginDefinition;
UninstallAgentSkills[ target_, names_ ] := catchMine @ uninstallAgentSkills[ target, names ];
UninstallAgentSkills // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*uninstallAgentSkills*)
(* Every name is validated before any path is built, so the root itself (or anything outside it) is never removed. *)
uninstallAgentSkills // beginDefinition;

uninstallAgentSkills[ target_, names_ ] := Enclose[
    Module[ { resolved, root, client, specs, single, skillNames, results },

        resolved = ConfirmBy[ resolveSkillsRoot @ target, AssociationQ, "Resolved" ];
        root     = ConfirmBy[ First @ resolved[ "Root" ], StringQ, "Root" ];
        client   = resolved[ "ClientName" ];

        { specs, single } = skillSpecList @ names;
        skillNames = validateSkillName /@ (agentSkillName /@ specs);

        results = uninstallAgentSkill[ root, #, client ] & /@ skillNames;
        If[ single, First @ results, results ]
    ],
    throwInternalFailure
];

uninstallAgentSkills // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*uninstallAgentSkill*)
(* Removes root/name only if it is a directory that contains SKILL.md, or a link to one (removed as a link). *)
uninstallAgentSkill // beginDefinition;

uninstallAgentSkill[ root_String, name_String? agentSkillNameQ, client_ ] :=
    Module[ { dest, state },
        dest  = FileNameJoin @ { root, name };
        state = skillDirectoryState[ File @ root, name ];
        Which[
            ! MatchQ[ state, "Directory" | "Link" ] || ! FileExistsQ @ FileNameJoin @ { dest, "SKILL.md" },
                Missing[ "NotInstalled", File @ dest ],
            removeSkillEntry[ root, name, state ],
                uninstallAgentSkillSuccess[ name, dest, client ],
            True,
                throwFailure[ "AgentSkillRemoveFailed", name, File @ dest ]
        ]
    ];

uninstallAgentSkill // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*uninstallAgentSkillSuccess*)
uninstallAgentSkillSuccess // beginDefinition;

uninstallAgentSkillSuccess[ name_String, dest_String, client_String ] :=
    Success[
        "UninstallAgentSkills",
        <|
            "MessageTemplate"   :> AgentTools::UninstallAgentSkillNamed,
            "MessageParameters" -> { name, installDisplayName @ client },
            "Name"              -> name,
            "Location"          -> File @ dest,
            "ClientName"        -> client
        |>
    ];

uninstallAgentSkillSuccess[ name_String, dest_String, None ] :=
    Success[
        "UninstallAgentSkills",
        <|
            "MessageTemplate"   :> AgentTools::UninstallAgentSkill,
            "MessageParameters" -> { name },
            "Name"              -> name,
            "Location"          -> File @ dest,
            "ClientName"        -> None
        |>
    ];

uninstallAgentSkillSuccess // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skill Registry*)

(* Deployments track the skill directories they install in a registry, one WXF file per installed directory:
    $skillRegistryPath/<registry key>.wxf      ($skillRegistryPath is $deploymentsPath/.SkillRegistry)
   Each entry:
    <|
        "RegistryKey" -> key,                           (* skillRegistryKey[ root, name ] *)
        "Directory"   -> File[ skillDir ],              (* as installed (not case-folded) *)
        "Name"        -> name,
        "Identifier"  -> id | None,
        "Version"     -> version | Missing[ ],
        "Hashes"      -> <| relPath -> sha256Hex, ... |>,  (* baseline: what AgentTools last wrote *)
        "External"    -> True | False,                  (* True: existed before any deployment referenced it *)
        "References"  -> { uuid, ... },
        "Timestamp"   -> DateObject[ ... ]
    |>
   A reference is stale if no $deploymentsPath/<client>/<uuid>/Deployment.wxf exists. Stale references are pruned only
   by sweepSkillRegistry, planSkillInstall (in memory), and releaseSkillReference. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillRegistryKey*)
(* skillRegistryKey[ File[ root ], name ] -> SHA-256 hex string of the canonical path key of root/name. It must be
   computed before anything is created, and is recorded by deployments (release always uses the recorded key). *)
skillRegistryKey // beginDefinition;
skillRegistryKey[ root: File[ _String ], name_String ] := Hash[ canonicalPathKey @ root <> "/" <> name, "SHA256", "HexString" ];
skillRegistryKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*registryKeyQ*)
registryKeyQ // beginDefinition;
registryKeyQ[ key_String ] := 0 < StringLength @ key <= 128 && StringMatchQ[ key, HexadecimalCharacter.. ];
registryKeyQ[ _ ] := False;
registryKeyQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillRegistryFile*)
skillRegistryFile // beginDefinition;
skillRegistryFile[ key_String? registryKeyQ ] := FileNameJoin @ { $skillRegistryPath, key <> ".wxf" };
skillRegistryFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readSkillRegistryEntry*)
(* readSkillRegistryEntry[ key ] -> entry_Association | Missing[ "NotFound" ] | Missing[ "Invalid", File[ ... ] ] *)
readSkillRegistryEntry // beginDefinition;

readSkillRegistryEntry[ key_String? registryKeyQ ] :=
    With[ { file = skillRegistryFile @ key },
        If[ FileExistsQ @ file,
            Replace[ Quiet @ readWXFFile @ file, Except[ _Association ] :> Missing[ "Invalid", File @ file ] ],
            Missing[ "NotFound" ]
        ]
    ];

readSkillRegistryEntry[ _ ] :=
    Missing[ "NotFound" ];

readSkillRegistryEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillRegistryEntries*)
(* All registry entries that can be read (the registry holds one small file per installed skill directory). *)
skillRegistryEntries // beginDefinition;

skillRegistryEntries[ ] :=
    If[ DirectoryQ @ $skillRegistryPath,
        Select[
            Quiet @ readWXFFile @ # & /@ FileNames[ "*.wxf", $skillRegistryPath ],
            AssociationQ @ # && registryKeyQ @ Lookup[ #, "RegistryKey" ] &
        ],
        { }
    ];

skillRegistryEntries // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*registryEntriesForDirectory*)
(* registryEntriesForDirectory[ dir, key ] gives the registry entries, other than the one with the given key, whose
   recorded directory is the same physical directory as dir (compared by canonicalPathKey now). The registry key of a
   directory depends on how its path resolved when it was first installed: if a skills root later goes through a
   symbolic link (e.g. ~/.agents moved into a dotfiles repository and linked back), the same directory gets a
   different key. These entries keep one physical directory under one shared reference list. *)
registryEntriesForDirectory // beginDefinition;

registryEntriesForDirectory[ dir_String, key_ ] :=
    With[ { target = canonicalPathKey @ dir },
        Select[ skillRegistryEntries[ ], #[ "RegistryKey" ] =!= key && registryEntryPathKey @ # === target & ]
    ];

registryEntriesForDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*registryEntryPathKey*)
registryAliasEntries // beginDefinition;

(* Entries recorded under another key for the same skill directory, comparing paths the way registry keys are built:
   symbolic links are resolved in the skills root (e.g. a root that later moved behind a link), but not in the skill
   directory itself, so a per-skill link never takes over the entry of the directory it points to. Used when planning;
   release uses the full resolution of registryEntriesForDirectory, which can only prevent a deletion. *)
registryAliasEntries[ dest_String, key_ ] :=
    With[ { target = skillDirectoryPathKey @ dest },
        Select[
            skillRegistryEntries[ ],
            #[ "RegistryKey" ] =!= key &&
                MatchQ[ Lookup[ #, "Directory" ], File[ _String ] ] &&
                skillDirectoryPathKey @ First @ #[ "Directory" ] === target &
        ]
    ];

registryAliasEntries // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillDirectoryPathKey*)
skillDirectoryPathKey // beginDefinition;

skillDirectoryPathKey[ path0_String ] :=
    With[ { path = stripTrailingSeparators @ ExpandFileName @ path0 },
        canonicalPathKey @ parentDirectory @ path <> "/" <> foldPathCase @ FileNameTake @ path
    ];

skillDirectoryPathKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*registryEntryPathKey*)
registryEntryPathKey // beginDefinition;
registryEntryPathKey[ KeyValuePattern[ "Directory" -> File[ path_String ] ] ] := canonicalPathKey @ path;
registryEntryPathKey[ _ ] := None;
registryEntryPathKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*liveReferences*)
(* The references of a registry entry that are not stale. *)
liveReferences // beginDefinition;
liveReferences[ entry_Association ] := pruneSkillReferences @ Lookup[ entry, "References", { } ];
liveReferences[ _ ] := { };
liveReferences // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeSkillRegistryEntry*)
(* writeSkillRegistryEntry[ entry ] writes the entry to the file of entry[ "RegistryKey" ] and returns File[ file ].
   WriteWXFFile can report success although the data didn't reach the disk (e.g. a full disk), so the entry is read
   back to confirm it was written. *)
writeSkillRegistryEntry // beginDefinition;

writeSkillRegistryEntry[ entry: KeyValuePattern[ "RegistryKey" -> key_String? registryKeyQ ] ] := Enclose[
    Module[ { file },
        file = skillRegistryFile @ key;
        ConfirmBy[ ensureDirectory @ $skillRegistryPath, directoryQ, "Directory" ];
        ConfirmMatch[ writeWXFFile[ file, entry ], _String | _File, "Write" ];
        ConfirmAssert[ Quiet @ readWXFFile @ file === entry, "ReadBack" ];
        File @ file
    ],
    throwInternalFailure
];

writeSkillRegistryEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deleteSkillRegistryEntry*)
deleteSkillRegistryEntry // beginDefinition;

deleteSkillRegistryEntry[ key_String? registryKeyQ ] :=
    With[ { file = skillRegistryFile @ key },
        If[ FileExistsQ @ file, Quiet @ DeleteFile @ file ];
        Null
    ];

deleteSkillRegistryEntry[ _ ] :=
    Null;

deleteSkillRegistryEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeSkillRegistryEntryWithUndo*)
(* Writes an entry and returns an undo action that restores the previous file (raw bytes) or deletes the new one. *)
writeSkillRegistryEntryWithUndo // beginDefinition;

writeSkillRegistryEntryWithUndo[ entry_Association ] := Enclose[
    Module[ { file, previous },
        file     = ConfirmBy[ skillRegistryFile @ entry[ "RegistryKey" ], StringQ, "File" ];
        previous = If[ FileExistsQ @ file, Replace[ Quiet @ ReadByteArray @ file, EndOfFile -> ByteArray[ { } ] ], None ];
        ConfirmMatch[ writeSkillRegistryEntry @ entry, File[ _String ], "Write" ];
        With[ { f = file, p = previous }, restoreFileBytes[ f, p ] & ]
    ],
    throwInternalFailure
];

writeSkillRegistryEntryWithUndo // endDefinition;

restoreFileBytes // beginDefinition;
restoreFileBytes[ file_String, None ] := If[ FileExistsQ @ file, DeleteFile @ file ];
restoreFileBytes[ file_String, bytes_ByteArray ] := writeBytes[ file, bytes ];
restoreFileBytes[ _String, _ ] := Null; (* the previous file could not be read *)
restoreFileBytes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deploymentUUIDExistsQ*)
(* True iff $deploymentsPath/<client>/<uuid>/Deployment.wxf exists for some client directory. A record that fails to
   parse still counts (it is not stale). *)
deploymentUUIDExistsQ // beginDefinition;

deploymentUUIDExistsQ[ uuid_String ] /; StringMatchQ[ uuid, (WordCharacter | "-").. ] :=
    TrueQ @ AnyTrue[
        deploymentClientDirectories[ ],
        FileExistsQ @ FileNameJoin @ { #, uuid, "Deployment.wxf" } &
    ];

deploymentUUIDExistsQ[ _ ] :=
    False;

deploymentUUIDExistsQ // endDefinition;

deploymentClientDirectories // beginDefinition;

deploymentClientDirectories[ ] :=
    If[ DirectoryQ @ $deploymentsPath,
        Select[ FileNames[ All, $deploymentsPath ], DirectoryQ @ # && ! StringStartsQ[ FileNameTake @ #, "." ] & ],
        { }
    ];

deploymentClientDirectories // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*pruneSkillReferences*)
pruneSkillReferences // beginDefinition;
pruneSkillReferences[ refs_List ] := Select[ DeleteDuplicates @ refs, deploymentUUIDExistsQ ];
pruneSkillReferences[ _ ] := { };
pruneSkillReferences // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sweepSkillRegistry*)
(* Prunes the stale references of every registry entry. Entries left without references (e.g. their deployments were
   removed by an older AgentTools version, or a deploy crashed) go through step 4 of the release decision.
   Returns the release results of those entries (see releaseSkillReference). The sweep runs at the start of every
   locked deploy and delete, so an entry that fails is skipped (and retried by the next sweep) instead of blocking
   every deployment. Issues no release messages; only AgentSkillBackupNotRemoved is reported, since it names a leftover
   copy that nothing tracks. *)
sweepSkillRegistry // beginDefinition;

sweepSkillRegistry[ ] :=
    If[ DirectoryQ @ $skillRegistryPath,
        Flatten[ sweepSkillRegistryFile /@ FileNames[ "*.wxf", $skillRegistryPath ] ],
        { }
    ];

sweepSkillRegistry // endDefinition;

sweepSkillRegistryFile // beginDefinition;

sweepSkillRegistryFile[ file_String ] :=
    Replace[
        Quiet[ catchAlways @ sweepSkillRegistryEntry @ file, General::AgentToolsInternal ],
        Except[ _List ] -> { }
    ];

sweepSkillRegistryFile // endDefinition;

sweepSkillRegistryEntry // beginDefinition;

sweepSkillRegistryEntry[ file_String ] :=
    Module[ { entry, references, pruned },
        entry = Quiet @ readWXFFile @ file;
        If[ ! AssociationQ @ entry || ! registryKeyQ @ Lookup[ entry, "RegistryKey" ],
            { },
            references = Replace[ Lookup[ entry, "References" ], Except[ _List ] -> { } ];
            pruned = pruneSkillReferences @ references;
            Which[
                pruned === { }, { releaseSkillEntry @ <| entry, "References" -> { } |> },
                pruned =!= references, writeSkillRegistryEntry @ <| entry, "References" -> pruned |>; { },
                True, { }
            ]
        ]
    ];

sweepSkillRegistryEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Install Decisions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*planSkillInstall*)
(* planSkillInstall[ sources, File[ root ], uuid, replacedUUIDs, overwrite ] computes the install decisions of a
   deployment (see "Install decision" in Specs/AgentToolsObject.md). It reads the registry and the disk, and writes
   nothing. Stale references and the references of the replaced deployments are excluded from the live references
   that decide each action, but the references of the replaced deployments are kept in the entries that will be
   written (DeployAgentTools releases them after the new deployment record exists, so an interrupted deploy never
   leaves a surviving deployment without its reference). An existing entry that records the same physical directory
   under another registry key (see registryEntriesForDirectory) is used with its own key.
    <|
        "Root"      -> File[ root ],
        "Decisions" -> {
            <|
                "Name"          -> name,
                "Source"        -> source,                (* as given by toAgentSkillSource *)
                "Directory"     -> File[ root/name ],
                "Root"          -> File[ root ],
                "RegistryKey"   -> key,                   (* the key of the entry that will be written *)
                "State"         -> state,                 (* skillDirectoryState of the destination, or "Same" *)
                "Action"        -> "Create" | "AddReference" | "Replace" | "KeepNewer" | "AdoptExternal" | "AdoptChange",
                "PreviousEntry" -> entry | Missing[ ... ],
                "Entry"         -> entry,                 (* the registry entry that will be written *)
                "Installed"     -> <| "Name", "Directory", "RegistryKey", "Identifier", "Version" |>,
                "Messages"      -> { <| "Tag" -> "AgentSkillNewerVersionKept", "Parameters" -> { ... } |>, ... }
            |>,
            ...
        },
        "Conflicts" -> { <| "Tag" -> "AgentSkillExists" | ..., "Parameters" -> { name, File[ dir ], ... } |>, ... }
    |>
   Conflicting skills have no decision. *)
planSkillInstall // beginDefinition;

planSkillInstall[ sources: { ___Association }, root0: File[ _String ], uuid_String, replaced_List, overwrite: $$overwrite ] :=
    Enclose[
        Module[ { root, results },
            root = ConfirmMatch[ validateSkillsRoot @ root0, File[ _String ], "Root" ];
            checkDuplicateSkillNames @ sources;
            results = ConfirmMatch[
                planSkillDecision[ #, root, uuid, replaced, overwrite ] & /@ sources,
                { ___Association },
                "Results"
            ];
            <|
                "Root"      -> root,
                "Decisions" -> Select[ results, MatchQ[ #[ "Action" ], $$installAction ] & ],
                "Conflicts" -> Cases[ results, c: KeyValuePattern[ "Action" -> "Conflict" ] :> KeyTake[ c, { "Tag", "Parameters" } ] ]
            |>
        ],
        throwInternalFailure
    ];

planSkillInstall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*planSkillDecision*)
planSkillDecision // beginDefinition;

planSkillDecision[ source_Association, root: File[ rootPath_String ], uuid_String, replaced_List, overwrite_ ] := Enclose[
    Module[ { name, dest, destKey, key, previous, sameQ, entry, kept, live, state, decision },

        name    = ConfirmBy[ source[ "Name" ], StringQ, "Name" ];
        dest    = ConfirmBy[ FileNameJoin @ { rootPath, name }, StringQ, "Destination" ];
        destKey = ConfirmBy[ skillRegistryKey[ root, name ], StringQ, "Key" ];

        (* the entry under this destination's key, or an entry that records the same physical directory under another
           key (which is then kept, with its references, "External" flag, and baseline) *)
        { key, previous } = ConfirmMatch[ registryEntryForDestination[ destKey, dest ], { _String, _ }, "Entry" ];

        (* A source that is the destination itself, reached through a per-skill link to a directory that another entry
           owns: the reference goes to that entry (keeping its key and directory), so one physical directory keeps one
           reference list and whichever deployment is released last can remove it *)
        sameQ = sourceDestinationRelation[ source, dest ] === "Same";
        If[ sameQ && ! AssociationQ @ previous,
            With[ { owners = Select[
                        registryEntriesForDirectory[ dest, destKey ],
                        MatchQ[ Lookup[ #, "Directory" ], File[ _String ] ] &&
                            skillDirectoryPathKey @ First @ #[ "Directory" ] === canonicalPathKey @ dest &
                    ] },
                If[ owners =!= { },
                    previous = SelectFirst[ owners, ! TrueQ @ #[ "External" ] &, First @ owners ];
                    key      = previous[ "RegistryKey" ]
                ]
            ]
        ];

        entry = If[ AssociationQ @ previous, previous, None ];

        (* the references that are kept in the entry: the replaced deployments keep theirs until DeployAgentTools
           releases them after the new deployment record exists (so an interrupted deploy can't orphan them) *)
        kept = liveReferences @ entry;

        (* the references that decide the action: the replaced deployments don't count *)
        live = Select[ kept, ! MemberQ[ replaced, # ] & ];

        state = If[ sameQ, "Same", ConfirmMatch[ skillDirectoryState[ root, name ], $$skillState, "State" ] ];

        decision = ConfirmBy[ skillInstallAction[ source, dest, state, entry, live, overwrite ], AssociationQ, "Action" ];

        Which[
            decision[ "Action" ] === "Conflict",
                decision,
            (* the owner's directory stays the recorded one *)
            sameQ && key =!= destKey && MatchQ[ Lookup[ entry, "Directory" ], File[ _String ] ],
                keepOwnerDirectory[
                    completeSkillDecision[ decision, source, root, dest, key, state, previous, entry, kept, uuid ],
                    entry[ "Directory" ]
                ],
            True,
                completeSkillDecision[ decision, source, root, dest, key, state, previous, entry, kept, uuid ]
        ]
    ],
    throwInternalFailure
];

planSkillDecision // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*registryEntryForDestination*)
(* { key, entry }: the registry entry of a destination, read by its key; if there is none, an entry that records the
   same physical directory under another key (see registryEntriesForDirectory), preferring one that is still in use.
   Its key is then used, so one physical directory keeps one shared reference list. *)
registryEntryForDestination // beginDefinition;

registryEntryForDestination[ key_String, dest_String ] :=
    Module[ { previous, aliases },
        previous = readSkillRegistryEntry @ key;
        aliases  = If[ AssociationQ @ previous, { }, registryAliasEntries[ dest, key ] ];
        If[ aliases === { },
            { key, previous },
            With[ { alias = SelectFirst[ aliases, liveReferences @ # =!= { } &, First @ aliases ] },
                { alias[ "RegistryKey" ], alias }
            ]
        ]
    ];

registryEntryForDestination // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillInstallAction*)
(* The install decision table. Returns <| "Action" -> action, "External" -> True | False |> (plus "Messages"), or a
   conflict <| "Action" -> "Conflict", "Tag" -> tag, "Parameters" -> { ... } |>. "Force" means OverwriteTarget -> All;
   "upgrade level" means OverwriteTarget -> True | All. *)
skillInstallAction // beginDefinition;

(* The source directory is the destination: the skill is already installed, so nothing is written. The baseline of an
   existing entry is never replaced by the directory's content: the source is the only copy of any changes the user
   made, so a modified directory must stay "Modified" (kept and reported on release) instead of becoming removable. *)
skillInstallAction[ source_, dest_, "Same", entry_, live_, overwrite_ ] :=
    Which[
        entry === None, <| "Action" -> "AdoptExternal", "External" -> True |>,
        externalEntryQ @ entry, <| "Action" -> "AddReference", "External" -> True |>,
        True, <| "Action" -> "AddReference", "External" -> False |>
    ];

skillInstallAction[ source_, dest_, "Missing", entry_, live_, overwrite_ ] :=
    <| "Action" -> "Create", "External" -> False |>;

skillInstallAction[ source_, dest_, "Dangling" | "File" | "Link", entry_, live_, overwrite_ ] :=
    If[ overwrite === All,
        <| "Action" -> "Replace", "External" -> False |>,
        skillConflict[ "AgentSkillExists", source, dest, All ]
    ];

(* A directory that no deployment references (installed by the user, another tool, or InstallAgentSkills) *)
skillInstallAction[ source_, dest_, "Directory", None, live_, overwrite_ ] :=
    Which[
        manifestsEqualQ[ diskManifest @ dest, source[ "Manifest" ] ], <| "Action" -> "AdoptExternal", "External" -> True |>,
        overwrite === All, <| "Action" -> "Replace", "External" -> False |>,
        True, skillConflict[ "AgentSkillExists", source, dest, All ]
    ];

(* A directory that existed before any deployment referenced it *)
skillInstallAction[ source_, dest_, "Directory", entry_Association? externalEntryQ, live_, overwrite_ ] :=
    Which[
        manifestsEqualQ[ diskManifest @ dest, source[ "Manifest" ] ], <| "Action" -> "AddReference", "External" -> True |>,
        overwrite === All, <| "Action" -> "Replace", "External" -> False |>,
        True, skillConflict[ "AgentSkillExists", source, dest, All ]
    ];

(* A directory written by a deployment *)
skillInstallAction[ source_, dest_, "Directory", entry_Association, live_List, overwrite_ ] :=
    Module[ { hashes, sameIdentifier },
        hashes = Replace[ Lookup[ entry, "Hashes" ], Except[ _Association ] -> <| |> ];
        sameIdentifier = StringQ @ source[ "Identifier" ] && source[ "Identifier" ] === Lookup[ entry, "Identifier" ];
        If[ compareSkillManifest[ File @ dest, hashes ] === "Unmodified",
            Which[
                manifestsEqualQ[ source[ "Manifest" ], hashes ],
                    <| "Action" -> "AddReference", "External" -> False |>,
                live === { },
                    (* only the replaced deployments used it: owned by the replacement *)
                    <| "Action" -> "Replace", "External" -> False |>,
                sameIdentifier && versionOlderQ[ source[ "Version" ], Lookup[ entry, "Version" ] ],
                    <|
                        "Action"   -> "KeepNewer",
                        "External" -> False,
                        "Messages" -> {
                            <|
                                "Tag"        -> "AgentSkillNewerVersionKept",
                                "Parameters" -> { source[ "Name" ], File @ dest, entry[ "Version" ], source[ "Version" ] }
                            |>
                        }
                    |>,
                (* Built-in skills only change with the paclet, so they are updated without OverwriteTarget (the
                   KeepNewer case above makes sure that a directory that others still use is never downgraded) *)
                sameIdentifier,
                    If[ MatchQ[ overwrite, True | All ] || builtInSkillSourceQ @ source,
                        <| "Action" -> "Replace", "External" -> False |>,
                        skillConflict[ "AgentSkillUpdate", source, dest ]
                    ],
                overwrite === All,
                    <| "Action" -> "Replace", "External" -> False |>,
                True,
                    skillConflict[ "AgentSkillConflict", source, dest ]
            ],
            Which[
                manifestsEqualQ[ diskManifest @ dest, source[ "Manifest" ] ],
                    <| "Action" -> "AdoptChange", "External" -> False |>,
                overwrite === All,
                    <| "Action" -> "Replace", "External" -> False |>,
                True,
                    skillConflict[ "AgentSkillModified", source, dest ]
            ]
        ]
    ];

skillInstallAction // endDefinition;

externalEntryQ // beginDefinition;
externalEntryQ[ entry_Association ] := TrueQ @ Lookup[ entry, "External" ];
externalEntryQ // endDefinition;

skillConflict // beginDefinition;

skillConflict[ tag_String, source_Association, dest_String, params___ ] :=
    <| "Action" -> "Conflict", "Tag" -> tag, "Parameters" -> { source[ "Name" ], File @ dest, params } |>;

skillConflict // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*completeSkillDecision*)
(* Adds the registry entry that will be written and the record of the installed skill to a decision. The entry's
   references are the entry's non-stale references (including those of the deployments being replaced, which
   DeployAgentTools releases after the new deployment record exists) plus uuid. *)
keepOwnerDirectory // beginDefinition;

keepOwnerDirectory[ decision_Association, dir: File[ _String ] ] := <|
    decision,
    "Entry"     -> <| decision[ "Entry" ], "Directory" -> dir |>,
    "Installed" -> <| decision[ "Installed" ], "Directory" -> dir |>
|>;

keepOwnerDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*completeSkillDecision*)
completeSkillDecision // beginDefinition;

completeSkillDecision[ decision_, source_, root_, dest_, key_, state_, previous_, entry_, kept_List, uuid_ ] :=
    Module[ { action, references, newEntry },
        action     = decision[ "Action" ];
        references = DeleteDuplicates @ Append[ kept, uuid ];
        newEntry   = If[ MatchQ[ action, "Create" | "Replace" | "AdoptExternal" ] || entry === None,
                         <|
                             "RegistryKey" -> key,
                             "Directory"   -> File @ dest,
                             "Name"        -> source[ "Name" ],
                             "Identifier"  -> source[ "Identifier" ],
                             "Version"     -> source[ "Version" ],
                             "Hashes"      -> source[ "Manifest" ],
                             "External"    -> decision[ "External" ],
                             "References"  -> references,
                             "Timestamp"   -> Now
                         |>,
                         <|
                             entry,
                             "RegistryKey" -> key,
                             "Directory"   -> File @ dest,
                             "Hashes"      -> If[ action === "AdoptChange", source[ "Manifest" ], Lookup[ entry, "Hashes", <| |> ] ],
                             "External"    -> decision[ "External" ],
                             "References"  -> references,
                             "Timestamp"   -> Now
                         |>
                     ];
        <|
            "Name"          -> source[ "Name" ],
            "Source"        -> source,
            "Directory"     -> File @ dest,
            "Root"          -> root,
            "RegistryKey"   -> key,
            "State"         -> state,
            "Action"        -> action,
            "PreviousEntry" -> previous,
            "Entry"         -> newEntry,
            "Installed"     -> <|
                "Name"        -> source[ "Name" ],
                "Directory"   -> File @ dest,
                "RegistryKey" -> key,
                "Identifier"  -> Lookup[ newEntry, "Identifier", None ],
                "Version"     -> Lookup[ newEntry, "Version", Missing[ ] ]
            |>,
            "Messages"      -> Lookup[ decision, "Messages", { } ]
        |>
    ];

completeSkillDecision // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*versionOlderQ*)
(* True if both versions are known (numeric dotted versions) and the first is older than the second. *)
versionOlderQ // beginDefinition;

versionOlderQ[ a_String, b_String ] /; dottedVersionQ @ a && dottedVersionQ @ b :=
    Module[ { va, vb, n },
        va = FromDigits /@ StringSplit[ a, "." ];
        vb = FromDigits /@ StringSplit[ b, "." ];
        n  = Max[ Length @ va, Length @ vb ];
        Order[ PadRight[ va, n ], PadRight[ vb, n ] ] === 1
    ];

versionOlderQ[ _, _ ] :=
    False;

versionOlderQ // endDefinition;

dottedVersionQ // beginDefinition;
dottedVersionQ[ version_String ] := StringMatchQ[ version, DigitCharacter.. ~~ ("." ~~ DigitCharacter..)... ];
dottedVersionQ[ _ ] := False;
dottedVersionQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*applySkillInstallPlan*)
(* applySkillInstallPlan[ plan, uuid ] applies the decisions of planSkillInstall (fails with the first conflict's
   message if the plan has conflicts):
    <|
        "Installed" -> { <| "Name", "Directory", "RegistryKey", "Identifier", "Version" |>, ... },
        "Undo"      -> { action, ... },   (* zero-argument functions, run in reverse order to roll everything back *)
        "Finalize"  -> { action, ... },   (* zero-argument functions, run after the whole deployment succeeded *)
        "Messages"  -> { <| "Tag" -> tag, "Parameters" -> { ... } |>, ... }
    |>
   Replaced entries are kept as backups until Finalize runs. If anything fails midway, the changes made so far are
   rolled back and the failure propagates. *)
applySkillInstallPlan // beginDefinition;

applySkillInstallPlan[ plan_Association, uuid_String ] := Enclose[
    Module[ { conflicts, decisions, undo = { }, finalize = { }, installed = { }, messages = { }, success = False },

        conflicts = Lookup[ plan, "Conflicts", { } ];
        If[ conflicts =!= { }, throwSkillConflict @ First @ conflicts ];
        decisions = ConfirmMatch[ Lookup[ plan, "Decisions", { } ], { ___Association }, "Decisions" ];

        WithCleanup[
            Scan[
                Function[ decision,
                    With[ { result = applySkillDecision @ decision },
                        undo      = Join[ undo, result[ "Undo" ] ];
                        finalize  = Join[ finalize, result[ "Finalize" ] ];
                        installed = Append[ installed, decision[ "Installed" ] ];
                        messages  = Join[ messages, decision[ "Messages" ] ]
                    ]
                ],
                decisions
            ];
            success = True,
            If[ ! success, runSkillUndo @ undo ]
        ];

        <| "Installed" -> installed, "Undo" -> undo, "Finalize" -> finalize, "Messages" -> messages |>
    ],
    throwInternalFailure
];

applySkillInstallPlan // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*throwSkillConflict*)
throwSkillConflict // beginDefinition;

throwSkillConflict[ KeyValuePattern @ { "Tag" -> tag_String, "Parameters" -> { params___ } } ] :=
    throwFailure[ tag, params ];

throwSkillConflict // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applySkillDecision*)
(* Applies one decision: the files first, then the registry entry. If writing the entry fails, the file changes of
   this decision are undone before the failure propagates. *)
applySkillDecision // beginDefinition;

applySkillDecision[ decision_Association ] := Enclose[
    Module[ { files, success = False, entryUndo },
        files = ConfirmBy[ applySkillDecisionFiles @ decision, AssociationQ, "Files" ];
        WithCleanup[
            entryUndo = ConfirmMatch[ writeSkillRegistryEntryWithUndo @ decision[ "Entry" ], _Function, "Entry" ];
            success = True,
            If[ ! success, runSkillUndo @ files[ "Undo" ] ]
        ];
        <| "Undo" -> Append[ files[ "Undo" ], entryUndo ], "Finalize" -> files[ "Finalize" ] |>
    ],
    throwInternalFailure
];

applySkillDecision // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applySkillDecisionFiles*)
applySkillDecisionFiles // beginDefinition;

applySkillDecisionFiles[ decision: KeyValuePattern[ "Action" -> "Create" ] ] :=
    With[ { dest = First @ decision[ "Directory" ] },
        createSkillDirectory[ dest, decision[ "Name" ], decision[ "Source", "Files" ] ];
        <| "Undo" -> { deleteSkillEntry[ dest, "Directory" ] & }, "Finalize" -> { } |>
    ];

applySkillDecisionFiles[ decision: KeyValuePattern[ "Action" -> "Replace" ] ] :=
    With[
        {
            dest   = First @ decision[ "Directory" ],
            state  = decision[ "State" ],
            name   = decision[ "Name" ],
            backup = replaceSkillEntry[
                First @ decision[ "Root" ],
                decision[ "Name" ],
                decision[ "State" ],
                decision[ "Source", "Files" ]
            ]
        },
        <|
            "Undo"     -> { restoreSkillBackup[ dest, backup, state ] & },
            "Finalize" -> { deleteSkillBackup[ name, backup, state ] & }
        |>
    ];

applySkillDecisionFiles[ KeyValuePattern[ "Action" -> "AddReference" | "KeepNewer" | "AdoptExternal" | "AdoptChange" ] ] :=
    <| "Undo" -> { }, "Finalize" -> { } |>;

applySkillDecisionFiles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Release Decisions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*releaseSkillReference*)
(* releaseSkillReference[ installed, uuid ] releases the reference of deployment uuid to an installed skill (a record
   from applySkillInstallPlan's "Installed", using its recorded "RegistryKey"). Issues no messages (see
   skillReleaseMessages). Returns
    <| "Name", "Directory", "RegistryKey", "Root", "Result" -> result, ... |>
   where result is one of
    "InUse"        - other deployments still reference it (the entry was updated)
    "Removed"      - the unmodified directory was removed
    "KeptExternal" - the directory existed before any deployment used it, so it was kept
    "KeptModified" - the directory was modified after it was installed, so it was kept
    "KeptLink"     - the entry is a link, dangling link, or file, so it was kept
    "Missing"      - the directory no longer exists
    "NoEntry"      - there is no registry entry (the directory is left alone)
    "RemoveFailed" - removing the directory failed; the entry is kept without references so the next sweep retries *)
releaseSkillReference // beginDefinition;

releaseSkillReference[ installed_Association, uuid_String ] :=
    Module[ { key, base, entry, references },
        key   = Lookup[ installed, "RegistryKey", None ];
        base  = <|
            "Name"        -> Lookup[ installed, "Name" ],
            "Directory"   -> Lookup[ installed, "Directory" ],
            "RegistryKey" -> key
        |>;
        entry = readSkillRegistryEntry @ key;
        If[ ! AssociationQ @ entry,
            <| base, "Result" -> "NoEntry" |>,
            references = pruneSkillReferences @ DeleteCases[ Lookup[ entry, "References", { } ], uuid ];
            If[ references =!= { },
                writeSkillRegistryEntry @ <| entry, "References" -> references |>;
                <| releaseResultBase @ entry, "Result" -> "InUse", "References" -> references |>,
                releaseSkillEntry @ <| entry, "References" -> { } |>
            ]
        ]
    ];

releaseSkillReference // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*releaseSkillEntry*)
(* Step 4 of the release decision, for an entry without references. *)
releaseSkillEntry // beginDefinition;

releaseSkillEntry[ entry_Association ] :=
    Module[ { base, key, path, root, name, state },
        base = releaseResultBase @ entry;
        key  = base[ "RegistryKey" ];
        path = Replace[ base[ "Directory" ], { File[ p_String ] :> stripTrailingSeparators @ p, _ -> None } ];
        root = If[ StringQ @ path, parentDirectory @ path, None ];
        name = If[ StringQ @ path, FileNameTake @ path, None ];
        Which[
            ! agentSkillNameQ @ name || ! StringQ @ root,
                (* not a directory that AgentTools wrote: leave the files alone *)
                <| base, "Result" -> "NoEntry" |>,
            TrueQ @ Lookup[ entry, "External" ],
                deleteSkillRegistryEntry @ key;
                <| base, "Result" -> "KeptExternal" |>,
            True,
                state = skillDirectoryState[ File @ root, name ];
                <| base, "State" -> state, releaseSkillDirectory[ entry, key, root, name, state ] |>
        ]
    ];

releaseSkillEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*releaseSkillDirectory*)
releaseSkillDirectory // beginDefinition;

releaseSkillDirectory[ entry_, key_, root_, name_, "Missing" ] := (
    deleteSkillRegistryEntry @ key;
    <| "Result" -> "Missing" |>
);

releaseSkillDirectory[ entry_, key_, root_, name_, "Link" | "Dangling" | "File" ] := (
    deleteSkillRegistryEntry @ key;
    <| "Result" -> "KeptLink" |>
);

releaseSkillDirectory[ entry_, key_, root_String, name_String, "Directory" ] :=
    Module[ { dir, others, inUse, hashes },
        dir    = FileNameJoin @ { root, name };
        (* other entries (under different registry keys) for the same physical directory: see registryEntriesForDirectory *)
        others = registryEntriesForDirectory[ dir, key ];
        inUse  = Union @@ (liveReferences /@ others);
        hashes = Replace[ Lookup[ entry, "Hashes" ], Except[ _Association ] -> <| |> ];
        Which[
            (* Only external aliases (which never remove the directory) still use it: keep owning it with no references,
               so it is released again (by the sweep) once they are gone *)
            inUse =!= { } && ! externalEntryQ @ entry && AllTrue[ Select[ others, liveReferences @ # =!= { } & ], externalEntryQ ],
                writeSkillRegistryEntry @ <| entry, "References" -> { } |>;
                <| "Result" -> "InUse", "References" -> inUse |>,
            inUse =!= { },
                deleteSkillRegistryEntry @ key;
                <| "Result" -> "InUse", "References" -> inUse |>,
            AnyTrue[ others, externalEntryQ ],
                deleteSkillRegistryEntry @ key;
                <| "Result" -> "KeptExternal" |>,
            compareSkillManifest[ File @ dir, hashes ] =!= "Unmodified",
                deleteSkillRegistryEntry @ key;
                <| "Result" -> "KeptModified" |>,
            removeSkillEntry[ root, name, "Directory" ],
                (* the entry is deleted only after the directory is gone *)
                deleteSkillRegistryEntry @ key;
                <| "Result" -> "Removed" |>,
            True,
                writeSkillRegistryEntry @ <| entry, "References" -> { } |>;
                <| "Result" -> "RemoveFailed" |>
        ]
    ];

releaseSkillDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*releaseResultBase*)
releaseResultBase // beginDefinition;

releaseResultBase[ entry_Association ] :=
    Module[ { dir, path },
        dir  = Lookup[ entry, "Directory" ];
        path = Replace[ dir, { File[ p_String ] :> stripTrailingSeparators @ p, _ -> None } ];
        <|
            "Name"        -> Lookup[ entry, "Name", If[ StringQ @ path, FileNameTake @ path, None ] ],
            "Directory"   -> dir,
            "RegistryKey" -> Lookup[ entry, "RegistryKey" ],
            "Root"        -> If[ StringQ @ path, File @ parentDirectory @ path, None ]
        |>
    ];

releaseResultBase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillReleaseMessages*)
(* Issues the messages for release results (one per skill directory): AgentSkillInUse (informational) for skills that
   other deployments still use, and AgentSkillNotRemoved for skills that were kept although no deployment uses them
   (with an UninstallAgentSkills call that removes them). Returns the issued message failures. *)
skillReleaseMessages // beginDefinition;

skillReleaseMessages[ results_List ] :=
    Flatten[ skillReleaseMessage /@ DeleteDuplicatesBy[ Select[ results, AssociationQ ], Lookup[ #, "RegistryKey" ] & ] ];

skillReleaseMessages // endDefinition;

skillReleaseMessage // beginDefinition;

skillReleaseMessage[ KeyValuePattern @ { "Result" -> "InUse", "Name" -> name_, "Directory" -> dir_ } ] :=
    messagePrint[ "AgentSkillInUse", name, dir ];

(* The skill directory was replaced by a file or a dangling link: there is nothing that UninstallAgentSkills removes *)
skillReleaseMessage[ KeyValuePattern @ { "Result" -> "KeptLink", "State" -> "File" | "Dangling", "Name" -> name_, "Directory" -> dir_ } ] :=
    messagePrint[ "AgentSkillReplacedNotRemoved", name, dir ];

skillReleaseMessage[ result: KeyValuePattern @ { "Result" -> "KeptModified" | "KeptLink" } ] :=
    With[ { name = result[ "Name" ], root = Lookup[ result, "Root" ] },
        messagePrint[ "AgentSkillNotRemoved", name, result[ "Directory" ], HoldForm @ UninstallAgentSkills[ root, name ] ]
    ];

(* Removing an unmodified skill failed (e.g. permissions); the registry entry is kept, so a later release retries *)
skillReleaseMessage[ KeyValuePattern @ { "Result" -> "RemoveFailed", "Name" -> name_, "Directory" -> dir_ } ] :=
    messagePrint[ "AgentSkillRemoveFailed", name, dir ];

skillReleaseMessage[ _ ] :=
    { };

skillReleaseMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
