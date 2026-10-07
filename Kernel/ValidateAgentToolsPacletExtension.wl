(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`ValidateAgentToolsPacletExtension`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

Needs[ "PacletTools`" -> "pt`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$validExtensionKeys = {
    "Root",
    "Name",
    "Description",
    "MCPServers",
    "Tools",
    "MCPPrompts",
    "AgentSkills",
    "SystemID",
    "WolframVersion"
};

$itemTypes                 = { "MCPServers", "Tools", "MCPPrompts", "AgentSkills" };
$defaultBundleName         = "AgentTools";
$maxSkillDescriptionLength = 1024;
$extensionPriority         = <| "mx" -> 1, "wxf" -> 2, "wl" -> 3 |>;

$$declarationItem  = _String | { _String, _String } | _Association? (KeyExistsQ[ #, "Name" ] &);
$$systemIDQualifier = All | _String | { __String };

(* Combined definition files loaded during one validation, keyed by { root, type }: *)
$combinedFileCache = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ValidateAgentToolsPacletExtension*)
ValidateAgentToolsPacletExtension // beginDefinition;

ValidateAgentToolsPacletExtension[ paclet_PacletObject? PacletObjectQ ] :=
    catchMine @ validateAgentToolsPacletExtension @ paclet;

ValidateAgentToolsPacletExtension[ spec_ ] :=
    catchMine @ With[ { paclet = Quiet @ PacletObject @ spec },
        If[ PacletObjectQ @ paclet,
            validateAgentToolsPacletExtension @ paclet,
            throwFailure[ "InvalidPacletSpecification", spec ]
        ]
    ];

ValidateAgentToolsPacletExtension // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*validateAgentToolsPacletExtension*)
validateAgentToolsPacletExtension // beginDefinition;

validateAgentToolsPacletExtension[ paclet_PacletObject ] := Enclose[
    Block[ { $combinedFileCache = <| |> }, Catch @ Module[
        { structureResult, structureErrors, roots, rootErrors, servers, tools, prompts, skills,
          fileErrors, defined, contentErrors, crossRefErrors, bundles, bundleErrors, allErrors },

        (* 1. Extension structure (every entry, including entries for other systems) *)
        structureResult = validateExtensionStructure @ paclet;
        structureErrors = structureResult[ "Errors" ];

        If[ ! TrueQ @ structureResult[ "Valid" ],
            Throw @ buildFailure[ paclet, structureErrors ]
        ];

        (* 2. File existence (entries that apply to this system) *)
        roots = ConfirmMatch[ getAgentToolsExtensionDirectories @ paclet, { ___String }, "Roots" ];
        rootErrors = checkRootDirectories[ paclet, roots ];

        servers = ConfirmMatch[ getAgentToolsDeclaredItems[ paclet, "MCPServers"  ], { ___String }, "Servers" ];
        tools   = ConfirmMatch[ getAgentToolsDeclaredItems[ paclet, "Tools"       ], { ___String }, "Tools"   ];
        prompts = ConfirmMatch[ getAgentToolsDeclaredItems[ paclet, "MCPPrompts"  ], { ___String }, "Prompts" ];
        skills  = ConfirmMatch[ getAgentToolsDeclaredItems[ paclet, "AgentSkills" ], { ___String }, "Skills"  ];

        fileErrors = If[ roots =!= { },
            Join[
                checkFileExistence[ roots, "MCPServers" , servers ],
                checkFileExistence[ roots, "Tools"      , tools   ],
                checkFileExistence[ roots, "MCPPrompts" , prompts ],
                checkFileExistence[ roots, "AgentSkills", skills  ]
            ],
            { }
        ];

        (* Items without any definition are only reported as missing *)
        defined = definedItems[ fileErrors, <|
            "MCPServers"  -> servers,
            "Tools"       -> tools,
            "MCPPrompts"  -> prompts,
            "AgentSkills" -> skills
        |> ];

        (* 3. File contents *)
        contentErrors = If[ roots =!= { },
            Join[
                checkFileContents[ paclet, "MCPServers", defined[ "MCPServers" ] ],
                checkFileContents[ paclet, "Tools"     , defined[ "Tools"      ] ],
                checkFileContents[ paclet, "MCPPrompts", defined[ "MCPPrompts" ] ],
                checkSkillContents[ paclet, defined[ "AgentSkills" ] ]
            ],
            { }
        ];

        (* 4. Cross-references *)
        crossRefErrors = If[ roots =!= { },
            checkCrossReferences[ paclet, servers, tools, prompts ],
            { }
        ];

        (* 5. Bundles *)
        bundles = ConfirmMatch[ getAgentToolsBundles @ paclet, { ___Association }, "Bundles" ];
        bundleErrors = checkBundles[ paclet, bundles, servers ];

        allErrors = Join[ structureErrors, rootErrors, fileErrors, contentErrors, crossRefErrors, bundleErrors ];

        If[ Length @ allErrors > 0,
            buildFailure[ paclet, allErrors ],
            Success[ "ValidAgentToolsPacletExtension", <|
                "MCPServers"  -> servers,
                "Tools"       -> tools,
                "MCPPrompts"  -> prompts,
                "AgentSkills" -> skills,
                "AgentTools"  -> (#[ "Name" ] & /@ bundles)
            |> ]
        ]
    ] ],
    throwInternalFailure
];

validateAgentToolsPacletExtension // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Extension Structure*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validateExtensionStructure*)
(* Checks every {"AgentTools", ...} entry in PacletInfo. "Valid" is False if there is no entry that can be used. *)
validateExtensionStructure // beginDefinition;

validateExtensionStructure[ paclet_PacletObject ] :=
    Catch @ Module[ { rawEntries, entries, count, errors },

        rawEntries = Cases[ Replace[ paclet[ "Extensions" ], Except[ _List ] -> { } ], { "AgentTools", ___ } ];

        (* Check that the paclet has an AgentTools extension *)
        If[ rawEntries === { },
            Throw @ <| "Valid" -> False, "Errors" -> {
                <| "Type" -> "NoAgentToolsExtension", "Message" -> "PacletInfo does not contain an \"AgentTools\" extension." |>
            } |>
        ];

        entries = toEntryData /@ rawEntries;
        count   = Length @ entries;

        errors = Join[
            Join @@ MapIndexed[ checkEntryStructure[ #1, First @ #2, count ] &, entries ],
            checkDuplicateBundleNames @ entries
        ];

        <| "Valid" -> AnyTrue[ entries, AssociationQ ], "Errors" -> errors |>
    ];

validateExtensionStructure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toEntryData*)
toEntryData // beginDefinition;
toEntryData[ { "AgentTools", data_Association } ] := data;
toEntryData[ { "AgentTools", rules: (_Rule|_RuleDelayed)... } ] := Association @ { rules };
toEntryData[ _ ] := $Failed;
toEntryData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*entryLabel*)
(* Identifies the entry in messages when the paclet has several AgentTools extensions. *)
entryLabel // beginDefinition;
entryLabel[ index_Integer, 1 ] := "";
entryLabel[ index_Integer, count_Integer ] := " in AgentTools extension " <> ToString @ index;
entryLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkEntryStructure*)
checkEntryStructure // beginDefinition;

checkEntryStructure[ $Failed, index_Integer, count_Integer ] := {
    <|
        "Type"    -> "MalformedExtension",
        "Entry"   -> index,
        "Message" -> "AgentTools extension" <> If[ count > 1, " " <> ToString @ index, "" ] <> " has unexpected format."
    |>
};

checkEntryStructure[ data_Association, index_Integer, count_Integer ] :=
    Module[ { label, errors, invalidKeys },

        label  = entryLabel[ index, count ];
        errors = { };

        (* Check for invalid keys *)
        invalidKeys = Complement[ Keys @ data, $validExtensionKeys ];
        If[ Length @ invalidKeys > 0,
            AppendTo[ errors, <|
                "Type"    -> "InvalidExtensionKeys",
                "Entry"   -> index,
                "Keys"    -> invalidKeys,
                "Message" -> "Unknown extension keys" <> label <> ": " <> StringRiffle[ ToString /@ invalidKeys, ", " ] <> "."
            |> ]
        ];

        (* Check the bundle name *)
        If[ KeyExistsQ[ data, "Name" ] && ! validItemNameQ @ data[ "Name" ],
            AppendTo[ errors, <|
                "Type"    -> "InvalidBundleName",
                "Entry"   -> index,
                "Name"    -> data[ "Name" ],
                "Message" -> "The \"Name\"" <> label <> " must be a non-empty string without \"/\"."
            |> ]
        ];

        (* Check values that must be strings *)
        Scan[
            Function[ key,
                If[ KeyExistsQ[ data, key ] && ! StringQ @ data[ key ],
                    AppendTo[ errors, <|
                        "Type"    -> "InvalidExtensionValue",
                        "Entry"   -> index,
                        "Key"     -> key,
                        "Message" -> "The value of \"" <> key <> "\"" <> label <> " must be a string."
                    |> ]
                ]
            ],
            { "Root", "Description", "WolframVersion" }
        ];

        (* Check the "SystemID" qualifier has a form that PacletTools accepts *)
        If[ KeyExistsQ[ data, "SystemID" ] && ! MatchQ[ data[ "SystemID" ], $$systemIDQualifier ],
            AppendTo[ errors, <|
                "Type"    -> "InvalidExtensionValue",
                "Entry"   -> index,
                "Key"     -> "SystemID",
                "Message" -> "The value of \"SystemID\"" <> label <> " must be All, a string, or a non-empty list of strings."
            |> ]
        ];

        (* Check each declared item uses a valid form and a valid name *)
        Scan[
            Function[ type,
                Module[ { items },
                    items = Lookup[ data, type, { } ];
                    If[ ListQ @ items,
                        MapIndexed[
                            Function[ { item, pos },
                                Which[
                                    ! MatchQ[ item, $$declarationItem ],
                                    AppendTo[ errors, <|
                                        "Type"     -> "InvalidDeclaration",
                                        "Entry"    -> index,
                                        "ItemType" -> type,
                                        "Position" -> First @ pos,
                                        "Message"  -> "Invalid declaration form at position " <> ToString @ First @ pos <> " in \"" <> type <> "\"" <> label <> "."
                                    |> ],

                                    ! validItemNameQ @ itemName @ item,
                                    AppendTo[ errors, <|
                                        "Type"     -> "InvalidItemName",
                                        "Entry"    -> index,
                                        "ItemType" -> type,
                                        "Item"     -> itemName @ item,
                                        "Message"  -> "Invalid name " <> ToString[ itemName @ item, InputForm ] <> " in \"" <> type <> "\"" <> label <> ". Item names must be non-empty strings without \"/\"."
                                    |> ]
                                ]
                            ],
                            items
                        ],
                        AppendTo[ errors, <|
                            "Type"    -> "InvalidExtensionValue",
                            "Entry"   -> index,
                            "Key"     -> type,
                            "Message" -> "The value of \"" <> type <> "\"" <> label <> " must be a list."
                        |> ]
                    ]
                ]
            ],
            $itemTypes
        ];

        errors
    ];

checkEntryStructure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*itemName*)
itemName // beginDefinition;
itemName[ name_String ] := name;
itemName[ { name_String, _String } ] := name;
itemName[ as_Association ] := Lookup[ as, "Name" ];
itemName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validItemNameQ*)
validItemNameQ // beginDefinition;
validItemNameQ[ name_String ] := StringLength @ name > 0 && ! StringContainsQ[ name, "/" ];
validItemNameQ[ _ ] := False;
validItemNameQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkDuplicateBundleNames*)
(* Entries that define bundles (at least one server or skill) must have distinct names, unless their "SystemID"
   qualifiers are disjoint (so that they are never active on the same system). *)
checkDuplicateBundleNames // beginDefinition;

checkDuplicateBundleNames[ entries_List ] :=
    Module[ { bundleEntries, groups },
        bundleEntries = Select[
            MapIndexed[
                If[ AssociationQ @ #1 && definesBundleQ @ #1,
                    <|
                        "Entry"     -> First @ #2,
                        "Name"      -> Lookup[ #1, "Name", $defaultBundleName ],
                        "SystemIDs" -> systemIDSet @ #1
                    |>,
                    Nothing
                ] &,
                entries
            ],
            validItemNameQ @ #[ "Name" ] &
        ];

        groups = Select[ GatherBy[ bundleEntries, #[ "Name" ] & ], Length @ # > 1 & ];

        DeleteCases[ duplicateBundleNameError /@ groups, None ]
    ];

checkDuplicateBundleNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*duplicateBundleNameError*)
duplicateBundleNameError // beginDefinition;

duplicateBundleNameError[ group: { __Association } ] :=
    Module[ { conflicting, name },
        conflicting = Union @ Flatten @ Cases[
            Subsets[ group, { 2 } ],
            { a_, b_ } /; systemIDsOverlapQ[ a[ "SystemIDs" ], b[ "SystemIDs" ] ] :> { a[ "Entry" ], b[ "Entry" ] }
        ];
        name = group[[ 1, "Name" ]];
        If[ conflicting === { },
            None,
            <|
                "Type"    -> "DuplicateBundleName",
                "Name"    -> name,
                "Entries" -> conflicting,
                "Message" -> StringJoin[
                    "AgentTools extensions ",
                    StringRiffle[ ToString /@ conflicting, ", " ],
                    " define the same bundle name \"",
                    name,
                    "\"",
                    If[ name === $defaultBundleName, " (the default when \"Name\" is not given)", "" ],
                    "."
                ]
            |>
        ]
    ];

duplicateBundleNameError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*definesBundleQ*)
definesBundleQ // beginDefinition;
definesBundleQ[ data_Association ] := AnyTrue[ { "MCPServers", "AgentSkills" }, MatchQ[ Lookup[ data, #, { } ], { __ } ] & ];
definesBundleQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*systemIDSet*)
systemIDSet // beginDefinition;

systemIDSet[ data_Association ] := Replace[
    Lookup[ data, "SystemID", All ],
    {
        id_String :> { id },
        ids: { ___String } :> ids,
        _ :> All
    }
];

systemIDSet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*systemIDsOverlapQ*)
systemIDsOverlapQ // beginDefinition;
systemIDsOverlapQ[ All, _ ] := True;
systemIDsOverlapQ[ _, All ] := True;
systemIDsOverlapQ[ a_List, b_List ] := IntersectingQ[ a, b ];
systemIDsOverlapQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Existence*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkRootDirectories*)
(* An explicitly given "Root" must exist. Otherwise, roots that don't exist are skipped (e.g. an entry that only
   re-lists items declared by another entry), so it is only an error if no root exists at all. *)
checkRootDirectories // beginDefinition;

checkRootDirectories[ paclet_PacletObject, roots_List ] := Enclose[
    Module[ { extensions, explicitErrors },
        extensions = ConfirmMatch[ getAgentToolsExtensions @ paclet, { ___Association }, "Extensions" ];

        explicitErrors = DeleteDuplicates @ Cases[
            extensions,
            data_Association /; StringQ @ Lookup[ data, "Root" ] && ! existingRootQ[ paclet, data ] :>
                <|
                    "Type"    -> "MissingRootDirectory",
                    "Root"    -> data[ "Root" ],
                    "Message" -> "Root directory \"" <> data[ "Root" ] <> "\" does not exist."
                |>
        ];

        If[ extensions =!= { } && roots === { } && explicitErrors === { },
            { <| "Type" -> "MissingRootDirectory", "Message" -> "Root directory does not exist." |> },
            explicitErrors
        ]
    ],
    throwInternalFailure
];

checkRootDirectories // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*existingRootQ*)
existingRootQ // beginDefinition;

existingRootQ[ paclet_PacletObject, data_Association ] :=
    With[ { dir = Quiet @ pt`PacletExtensionDirectory[ paclet, { "AgentTools", data } ] },
        StringQ @ dir && DirectoryQ @ dir
    ];

existingRootQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkFileExistence*)
checkFileExistence // beginDefinition;

checkFileExistence[ roots_List, type_String, names_List ] :=
    Join @@ (checkItemFileExistence[ roots, type, # ] & /@ names);

checkFileExistence // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkItemFileExistence*)
checkItemFileExistence // beginDefinition;

checkItemFileExistence[ roots: { __String }, type_String, name_String ] :=
    Module[ { infos, defining, errors },

        infos    = rootDefinitionInfo[ #, type, name ] & /@ roots;
        defining = Select[ infos, #[ "Defined" ] & ];
        errors   = Join @@ (duplicateFilesInRoot[ #, type, name ] & /@ infos);

        If[ Length @ defining > 1,
            AppendTo[ errors, <|
                "Type"     -> "DuplicateDefinitionFiles",
                "Item"     -> name,
                "ItemType" -> type,
                "Roots"    -> Lookup[ defining, "Root" ],
                "Message"  -> StringJoin[
                    type, " \"", name, "\" is defined in multiple root directories: ",
                    StringRiffle[ Lookup[ defining, "Root" ], ", " ],
                    "."
                ]
            |> ]
        ];

        If[ defining === { },
            AppendTo[ errors, <|
                "Type"         -> "MissingDefinitionFile",
                "Item"         -> name,
                "ItemType"     -> type,
                "ExpectedPath" -> expectedDefinitionPath[ First @ roots, type, name ],
                "Message"      -> "Missing definition file for " <> type <> " \"" <> name <> "\"."
            |> ]
        ];

        errors
    ];

checkItemFileExistence // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*rootDefinitionInfo*)
(* How one root defines an item: per-item files, a skill directory (skills only), and/or an entry in the combined
   file. *)
rootDefinitionInfo // beginDefinition;

rootDefinitionInfo[ root_String, type_String, name_String ] :=
    Module[ { dir, perItemFiles, skillDirectory, combined },

        dir = FileNameJoin @ { root, type };
        perItemFiles = If[ DirectoryQ @ dir, FileNames[ { name<>".mx", name<>".wxf", name<>".wl" }, dir ], { } ];

        skillDirectory = If[ type === "AgentSkills" && skillDirectoryQ @ FileNameJoin @ { dir, name },
                             FileNameJoin @ { dir, name },
                             None
                         ];

        combined = With[ { data = combinedFileData[ root, type ] },
            AssociationQ @ data && KeyExistsQ[ data, name ]
        ];

        <|
            "Root"           -> root,
            "PerItemFiles"   -> perItemFiles,
            "SkillDirectory" -> skillDirectory,
            "Combined"       -> combined,
            "Defined"        -> perItemFiles =!= { } || StringQ @ skillDirectory || combined
        |>
    ];

rootDefinitionInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*duplicateFilesInRoot*)
duplicateFilesInRoot // beginDefinition;

duplicateFilesInRoot[ info_Association, type_String, name_String ] :=
    Module[ { perItemFiles, skillDirectory, errors },

        perItemFiles   = info[ "PerItemFiles"   ];
        skillDirectory = info[ "SkillDirectory" ];
        errors = { };

        If[ Length @ perItemFiles > 1,
            AppendTo[ errors, <|
                "Type"     -> "DuplicateDefinitionFiles",
                "Item"     -> name,
                "ItemType" -> type,
                "Files"    -> perItemFiles,
                "Message"  -> "Multiple definition files for " <> type <> " \"" <> name <> "\": " <> StringRiffle[ FileNameTake /@ perItemFiles, ", " ] <> "."
            |> ]
        ];

        If[ StringQ @ skillDirectory && perItemFiles =!= { },
            AppendTo[ errors, <|
                "Type"     -> "DuplicateDefinitionFiles",
                "Item"     -> name,
                "ItemType" -> type,
                "Files"    -> Prepend[ perItemFiles, skillDirectory ],
                "Message"  -> StringJoin[
                    "Agent skill \"", name, "\" has both a skill directory and a definition file: ",
                    StringRiffle[ FileNameTake /@ Prepend[ perItemFiles, skillDirectory ], ", " ],
                    "."
                ]
            |> ]
        ];

        errors
    ];

duplicateFilesInRoot // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expectedDefinitionPath*)
expectedDefinitionPath // beginDefinition;
expectedDefinitionPath[ root_String, "AgentSkills", name_String ] := FileNameJoin @ { root, "AgentSkills", name, "SKILL.md" };
expectedDefinitionPath[ root_String, type_String, name_String ] := FileNameJoin @ { root, type, name <> ".wl" };
expectedDefinitionPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillDirectoryQ*)
skillDirectoryQ // beginDefinition;
skillDirectoryQ[ dir_String ] := DirectoryQ @ dir && FileExistsQ @ FileNameJoin @ { dir, "SKILL.md" };
skillDirectoryQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*combinedFileData*)
(* The contents of a root's combined definition file for a type (None if there is none), loaded once per
   validation. *)
combinedFileData // beginDefinition;

combinedFileData[ root_String, type_String ] :=
    With[ { key = { root, type } },
        (* Lookup holds its arguments, so the file is only loaded if it is not cached yet *)
        Lookup[ $combinedFileCache, Key @ key, $combinedFileCache[ key ] = loadCombinedFile[ root, type ] ]
    ];

combinedFileData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadCombinedFile*)
loadCombinedFile // beginDefinition;

loadCombinedFile[ root_String, type_String ] :=
    Module[ { files, file },
        files = FileNames[ { type <> ".mx", type <> ".wxf", type <> ".wl" }, root ];
        If[ files === { },
            None,
            file = First @ SortBy[ files, Lookup[ $extensionPriority, FileExtension @ #, 99 ] & ];
            Quiet @ Switch[ FileExtension @ file,
                "mx" , Import[ file, "MX" ],
                "wxf", readWXFFile @ file,
                _    , Get @ file
            ]
        ]
    ];

loadCombinedFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*definedItems*)
(* The declared items of each type that have a definition (i.e. no MissingDefinitionFile error). *)
definedItems // beginDefinition;

definedItems[ fileErrors_List, declared_Association ] :=
    Module[ { missing },
        missing = Cases[
            fileErrors,
            KeyValuePattern @ { "Type" -> "MissingDefinitionFile", "ItemType" -> type_, "Item" -> name_ } :> { type, name }
        ];
        AssociationMap[
            Function[ type, Select[ declared[ type ], ! MemberQ[ missing, { type, # } ] & ] ],
            Keys @ declared
        ]
    ];

definedItems // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Contents*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkFileContents*)
checkFileContents // beginDefinition;

checkFileContents[ paclet_PacletObject, type_String, names_List ] :=
    Join @@ (checkItemFileContents[ paclet, type, # ] & /@ names);

checkFileContents // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkItemFileContents*)
checkItemFileContents // beginDefinition;

checkItemFileContents[ paclet_PacletObject, type_String, name_String ] :=
    Catch @ Module[ { data },
        data = Quiet @ loadPacletDefinitionFile[ paclet, type, name ];
        (* LLMTool expressions are valid tool definitions that need no further checking *)
        If[ type === "Tools" && MatchQ[ data, _LLMTool ], Throw @ { } ];
        If[ ! AssociationQ @ data,
            Throw @ { <| "Type" -> "InvalidDefinitionContents", "Item" -> name, "ItemType" -> type,
                     "Message" -> "Definition file for " <> type <> " \"" <> name <> "\" did not evaluate to a valid Association." |> }
        ];
        Switch[ type,
            "MCPServers", checkServerDefinition[ name, data ],
            "Tools"     , checkToolDefinition[ name, data ],
            "MCPPrompts", checkPromptDefinition[ name, data ],
            _           , { }
        ]
    ];

checkItemFileContents // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkServerDefinition*)
checkServerDefinition // beginDefinition;

checkServerDefinition[ name_String, data_Association ] :=
    If[ ! KeyExistsQ[ data, "LLMEvaluator" ],
        { <| "Type" -> "InvalidServerDefinition", "Item" -> name,
             "Message" -> "Server definition \"" <> name <> "\" is missing required key \"LLMEvaluator\"." |> },
        { }
    ];

checkServerDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkToolDefinition*)
$requiredToolKeys = { "Name", "Function", "Parameters" };

checkToolDefinition // beginDefinition;

checkToolDefinition[ name_String, data_Association ] :=
    Module[ { missing },
        missing = Select[ $requiredToolKeys, ! KeyExistsQ[ data, # ] & ];
        If[ Length @ missing > 0,
            { <| "Type" -> "InvalidToolDefinition", "Item" -> name, "MissingKeys" -> missing,
                 "Message" -> "Tool definition \"" <> name <> "\" is missing required keys: " <> StringRiffle[ missing, ", " ] <> "." |> },
            { }
        ]
    ];

checkToolDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkPromptDefinition*)
checkPromptDefinition // beginDefinition;

checkPromptDefinition[ name_String, data_Association ] :=
    If[ ! KeyExistsQ[ data, "Name" ],
        { <| "Type" -> "InvalidPromptDefinition", "Item" -> name,
             "Message" -> "Prompt definition \"" <> name <> "\" is missing required key \"Name\"." |> },
        { }
    ];

checkPromptDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkSkillContents*)
checkSkillContents // beginDefinition;

checkSkillContents[ paclet_PacletObject, names_List ] :=
    Join @@ (checkSkillDefinition[ paclet, # ] & /@ names);

checkSkillContents // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkSkillDefinition*)
(* A skill directory's SKILL.md (parsed as an LLMSkill) or a definition file's LLMSkill or association must have the
   declared name and follow the Agent Skills rules for names and descriptions. *)
checkSkillDefinition // beginDefinition;

checkSkillDefinition[ paclet_PacletObject, name_String ] :=
    Catch @ Module[ { definition, data, problems, resolved },

        definition = Quiet @ loadPacletDefinitionFile[ paclet, "AgentSkills", name ];

        data = Replace[ definition, {
            HoldPattern[ LLMSkill ][ as_Association ] :> as,
            as_Association :> as,
            _ :> $Failed
        } ];

        If[ ! AssociationQ @ data,
            Throw @ { skillDefinitionError[ name, "expected a SKILL.md file with name and description frontmatter, an LLMSkill, or an Association" ] }
        ];

        problems = skillDataProblems[ data, name ];
        If[ problems =!= { }, Throw[ skillDefinitionError[ name, # ] & /@ problems ] ];

        (* Anything else that would prevent the skill from being resolved (e.g. an honored "Location" that names a
           skill directory with a different name) *)
        resolved = Quiet @ catchAlways @ resolvePacletSkill[ paclet, name ];
        If[ FailureQ @ resolved,
            Throw @ { skillDefinitionError[ name, "it could not be resolved (" <> StringTrim[ failureText @ resolved, "." ] <> ")" ] }
        ];

        { }
    ];

checkSkillDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*failureText*)
(* The plain text of a failure's message (its "Message" property formats the parameters as boxes). *)
failureText // beginDefinition;

failureText[ failure_Failure ] :=
    Module[ { template, parameters },
        template   = failure[ "MessageTemplate"   ];
        parameters = failure[ "MessageParameters" ];
        If[ StringQ @ template && ListQ @ parameters,
            ToString @ StringForm[ template, Sequence @@ parameters ],
            "it could not be resolved"
        ]
    ];

failureText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillDataProblems*)
skillDataProblems // beginDefinition;

skillDataProblems[ data_Association, name_String ] :=
    Module[ { problems, skillName, description },
        problems    = { };
        skillName   = Lookup[ data, "Name" ];
        description = Lookup[ data, "Description" ];

        If[ skillName =!= name,
            AppendTo[ problems, "its name " <> ToString[ skillName, InputForm ] <> " does not match the declared name \"" <> name <> "\"" ]
        ];

        If[ ! agentSkillNameQ @ name,
            AppendTo[ problems, "\"" <> name <> "\" is not a valid skill name (1 to 64 lowercase letters, digits, and hyphens, without leading, trailing, or consecutive hyphens)" ]
        ];

        If[ ! agentSkillDescriptionQ @ description,
            AppendTo[ problems, "the description must be a string of 1 to " <> ToString @ $maxSkillDescriptionLength <> " characters that are not all whitespace" ]
        ];

        If[ ! StringQ @ Lookup[ data, "Body" ],
            AppendTo[ problems, "the body must be a string" ]
        ];

        problems
    ];

skillDataProblems // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillDefinitionError*)
skillDefinitionError // beginDefinition;

skillDefinitionError[ name_String, problem_String ] := <|
    "Type"     -> "InvalidSkillDefinition",
    "Item"     -> name,
    "ItemType" -> "AgentSkills",
    "Message"  -> "Invalid definition for agent skill \"" <> name <> "\": " <> StringTrim[ problem, "." ] <> "."
|>;

skillDefinitionError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cross-References*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkCrossReferences*)
checkCrossReferences // beginDefinition;

checkCrossReferences[ paclet_PacletObject, servers_List, tools_List, prompts_List ] :=
    Join @@ (checkServerCrossReferences[ paclet, #, tools, prompts ] & /@ servers);

checkCrossReferences // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkServerCrossReferences*)
checkServerCrossReferences // beginDefinition;

checkServerCrossReferences[ paclet_PacletObject, serverName_String, tools_List, prompts_List ] :=
    Catch @ Module[ { data, evaluator, referencedTools, referencedPrompts, toolErrors, promptErrors },
        data = Quiet @ loadPacletDefinitionFile[ paclet, "MCPServers", serverName ];
        If[ ! AssociationQ @ data, Throw @ { } ];

        evaluator = Lookup[ data, "LLMEvaluator", <| |> ];
        If[ ! AssociationQ @ evaluator, Throw @ { } ];

        referencedTools = Lookup[ evaluator, "Tools", { } ];
        toolErrors = If[ ListQ @ referencedTools,
            Cases[
                referencedTools,
                toolRef_String /; ! validCrossReference[ toolRef, tools ] :>
                    <| "Type" -> "InvalidToolReference", "Server" -> serverName, "Tool" -> toolRef,
                       "Message" -> "Server \"" <> serverName <> "\" references tool \"" <> toolRef <> "\" which is not declared in this paclet and is not a fully qualified name." |>
            ],
            { }
        ];

        referencedPrompts = Lookup[ evaluator, "MCPPrompts", { } ];
        promptErrors = If[ ListQ @ referencedPrompts,
            Cases[
                referencedPrompts,
                promptRef_String /; ! validCrossReference[ promptRef, prompts ] :>
                    <| "Type" -> "InvalidPromptReference", "Server" -> serverName, "Prompt" -> promptRef,
                       "Message" -> "Server \"" <> serverName <> "\" references prompt \"" <> promptRef <> "\" which is not declared in this paclet and is not a fully qualified name." |>
            ],
            { }
        ];

        Join[ toolErrors, promptErrors ]
    ];

checkServerCrossReferences // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validCrossReference*)
validCrossReference // beginDefinition;
validCrossReference[ name_String, declared_List ] := MemberQ[ declared, name ] || pacletQualifiedNameQ @ name;
validCrossReference // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Bundles*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkBundles*)
checkBundles // beginDefinition;

checkBundles[ paclet_PacletObject, bundles_List, servers_List ] :=
    Join @@ (checkBundle[ paclet, #, servers ] & /@ bundles);

checkBundles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkBundle*)
checkBundle // beginDefinition;

checkBundle[ paclet_PacletObject, bundle_Association, servers_List ] :=
    Join[ checkBundleConfigKeys[ paclet, bundle ], checkBundleName[ paclet, bundle, servers ] ];

checkBundle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkBundleConfigKeys*)
(* The servers of a bundle are deployed together, so they must be installed with distinct configuration keys. *)
checkBundleConfigKeys // beginDefinition;

checkBundleConfigKeys[ paclet_PacletObject, bundle_Association ] :=
    Module[ { pacletName, names, keys, groups },
        pacletName = paclet[ "Name" ];
        names  = Lookup[ bundle, "MCPServers", { } ];
        keys   = serverConfigKey[ paclet, shortItemName[ #, pacletName ] ] & /@ names;
        groups = Select[ GroupBy[ Transpose @ { names, keys }, Last -> First ], Length @ # > 1 & ];
        KeyValueMap[
            <|
                "Type"       -> "DuplicateBundleConfigKey",
                "Bundle"     -> bundle[ "Name" ],
                "ConfigKey"  -> #1,
                "MCPServers" -> #2,
                "Message"    -> StringJoin[
                    "The MCP servers ",
                    StringRiffle[ ("\"" <> # <> "\"" &) /@ #2, ", " ],
                    " of \"", bundle[ "Name" ], "\" would all be installed with the configuration key \"", #1, "\"."
                ]
            |> &,
            groups
        ]
    ];

checkBundleConfigKeys // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serverConfigKey*)
(* Matches the "MCPServerName" of paclet servers: from the definition file for installed paclets, otherwise from the
   declaration, defaulting to the short server name. *)
serverConfigKey // beginDefinition;

serverConfigKey[ paclet_PacletObject, name_String ] :=
    Module[ { definition, declaration },
        definition = Quiet @ loadPacletDefinitionFile[ paclet, "MCPServers", name ];
        If[ AssociationQ @ definition,
            Replace[ Lookup[ definition, "MCPServerName" ], Except[ _String ] -> name ],
            declaration = Quiet @ catchAlways @ getAgentToolsItemDeclaration[ paclet, "MCPServers", name ];
            Replace[
                If[ AssociationQ @ declaration, Lookup[ declaration, "MCPServerName" ], Missing[ ] ],
                Except[ _String ] -> name
            ]
        ]
    ];

serverConfigKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkBundleName*)
(* "Pub/Paclet/X" can name both a bundle and a server, so a bundle may only share its name with a server of the same
   paclet if it contains that server. *)
checkBundleName // beginDefinition;

checkBundleName[ paclet_PacletObject, bundle_Association, servers_List ] :=
    Module[ { pacletName, name },
        pacletName = paclet[ "Name" ];
        name = shortItemName[ bundle[ "Name" ], pacletName ];
        If[ MemberQ[ servers, name ] && ! MemberQ[ Lookup[ bundle, "MCPServers", { } ], bundle[ "Name" ] ],
            {
                <|
                    "Type"      -> "AmbiguousBundleName",
                    "Bundle"    -> bundle[ "Name" ],
                    "MCPServer" -> bundle[ "Name" ],
                    "Message"   -> StringJoin[
                        "The bundle name \"", bundle[ "Name" ],
                        "\" is also the name of an MCP server of this paclet, but the bundle does not contain that server."
                    ]
                |>
            },
            { }
        ]
    ];

checkBundleName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*shortItemName*)
shortItemName // beginDefinition;

shortItemName[ qualifiedName_String, pacletName_String ] :=
    If[ StringStartsQ[ qualifiedName, pacletName <> "/" ],
        StringDrop[ qualifiedName, StringLength @ pacletName + 1 ],
        qualifiedName
    ];

shortItemName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*buildFailure*)
buildFailure // beginDefinition;

buildFailure[ paclet_PacletObject, errors_List ] :=
    Module[ { firstMessage },
        firstMessage = If[ Length @ errors > 0, errors[[ 1, "Message" ]], "Unknown error." ];
        messagePrint[ "InvalidAgentToolsPacletExtension", paclet[ "Name" ], firstMessage ];
        Failure[ "InvalidAgentToolsPacletExtension", <| "Errors" -> errors |> ]
    ];

buildFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
