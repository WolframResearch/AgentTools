(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`PacletExtension`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

Needs[ "PacletTools`" -> "pt`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$toolDefaults      = <| "Options" -> { }, "Parameters" -> { }, "Description" -> "" |>;
$defaultBundleName = "AgentTools";
$skillFileName     = "SKILL.md";

(* Keys of an LLMSkill's data that are not part of a skill definition association: *)
$nonDefinitionSkillKeys = { "Location", "Options", "LLMPacletVersion" };

(* LLMSkill data is read directly from the raw expression (never through LLMFunctions internals): *)
$$llmSkill = HoldPattern[ LLMSkill ][ _Association ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*pacletQualifiedNameQ*)
pacletQualifiedNameQ // beginDefinition;
pacletQualifiedNameQ[ name_String ] := MatchQ[ StringSplit[ name, "/" ], { _String, _String } | { _String, _String, _String } ];
pacletQualifiedNameQ[ ___ ] := False;
pacletQualifiedNameQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*parsePacletQualifiedName*)
parsePacletQualifiedName // beginDefinition;

parsePacletQualifiedName[ name_String ] := Enclose[
    Module[ { parts },
        parts = ConfirmMatch[
            StringSplit[ name, "/" ],
            { _String, _String } | { _String, _String, _String },
            "Parts"
        ];
        parsePacletQualifiedName0 @ parts
    ],
    throwInternalFailure
];

parsePacletQualifiedName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parsePacletQualifiedName0*)
parsePacletQualifiedName0 // beginDefinition;

(* Two-segment: "PacletName/ItemName" *)
parsePacletQualifiedName0[ { pacletName_String, itemName_String } ] :=
    <| "PacletName" -> pacletName, "ItemName" -> itemName |>;

(* Three-segment: "PublisherID/PacletShortName/ItemName" *)
parsePacletQualifiedName0[ { publisherID_String, pacletShortName_String, itemName_String } ] :=
    <| "PacletName" -> publisherID <> "/" <> pacletShortName, "ItemName" -> itemName |>;

parsePacletQualifiedName0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*findAgentToolsPaclets*)
findAgentToolsPaclets // beginDefinition;

findAgentToolsPaclets[ ] := Enclose[
    ConfirmMatch[ PacletFind[ All, <| "Extension" -> "AgentTools" |> ], { ___PacletObject }, "Result" ],
    throwInternalFailure
];

findAgentToolsPaclets // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*findRemoteAgentToolsPaclets*)
findRemoteAgentToolsPaclets // beginDefinition;

findRemoteAgentToolsPaclets[ ] := findRemoteAgentToolsPaclets @ Automatic;

findRemoteAgentToolsPaclets[ updateSites: Automatic|True|False ] := Enclose[
    Catch @ Module[ { remotePaclets },
        remotePaclets = Quiet @ PacletFindRemote[ All, <| "Extension" -> "AgentTools" |>, UpdatePacletSites -> updateSites ];
        If[ ! MatchQ[ remotePaclets, { ___PacletObject } ], Throw @ { } ];
        ConfirmMatch[ remotePaclets, { ___PacletObject }, "Result" ]
    ],
    throwInternalFailure
];

findRemoteAgentToolsPaclets // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*findRemoteAgentToolsPaclet*)
(* The newest remote paclet with exactly this name that has an AgentTools extension (metadata only; never installs).
   PacletFindRemote treats "*" as a wildcard, so results are filtered by exact name. *)
findRemoteAgentToolsPaclet // beginDefinition;

findRemoteAgentToolsPaclet[ pacletName_String ] :=
    Module[ { remote },
        remote = Quiet @ PacletFindRemote[ pacletName, <| "Extension" -> "AgentTools" |> ];
        If[ MatchQ[ remote, { __PacletObject } ],
            SelectFirst[ remote, #[ "Name" ] === pacletName &, Missing[ "NotFound" ] ],
            Missing[ "NotFound" ]
        ]
    ];

findRemoteAgentToolsPaclet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Session-Level Cache*)
$pacletDefinitionCache = <| |>;

clearPacletDefinitionCache // beginDefinition;
clearPacletDefinitionCache[ ] := $pacletDefinitionCache = <| |>;
clearPacletDefinitionCache // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Extension Entries*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtensions*)
(* The data associations of all applicable {"AgentTools", ...} entries of a paclet, in PacletInfo order. *)
getAgentToolsExtensions // beginDefinition;

getAgentToolsExtensions[ paclet_PacletObject ] := Enclose[
    Module[ { extensions },
        Needs[ "PacletTools`" -> None ];
        (* Filters entries by their qualifiers, but fails for paclets without a local directory (e.g. remote paclets
           from PacletFindRemote, whose location is a URL) or with a malformed entry: *)
        extensions = Quiet @ pt`PacletExtensions[ paclet, "AgentTools" ];
        ConfirmMatch[
            If[ MatchQ[ extensions, { { "AgentTools", _Association } .. } ],
                Last /@ extensions,
                rawAgentToolsExtensions @ paclet
            ],
            { ___Association },
            "Result"
        ]
    ],
    throwInternalFailure
];

getAgentToolsExtensions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*rawAgentToolsExtensions*)
rawAgentToolsExtensions // beginDefinition;

rawAgentToolsExtensions[ paclet_PacletObject ] := Select[
    Cases[
        Replace[ paclet[ "Extensions" ], Except[ _List ] -> { } ],
        { "AgentTools", rules___ } :> With[ { data = toExtensionData @ { rules } }, data /; AssociationQ @ data ]
    ],
    systemIDApplicableQ
];

rawAgentToolsExtensions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toExtensionData*)
toExtensionData // beginDefinition;
toExtensionData[ { data_Association } ] := data;
toExtensionData[ rules: { (_Rule|_RuleDelayed)... } ] := Association @ rules;
toExtensionData[ _ ] := $Failed;
toExtensionData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*systemIDApplicableQ*)
systemIDApplicableQ // beginDefinition;
systemIDApplicableQ[ data_Association ] := systemIDMatchQ @ Lookup[ data, "SystemID", All ];
systemIDApplicableQ // endDefinition;

(* Same semantics as PacletTools`PacletExtensions: "All" is an ordinary (non-matching) system ID. *)
systemIDMatchQ // beginDefinition;
systemIDMatchQ[ All ] := True;
systemIDMatchQ[ id_String ] := id === $SystemID;
systemIDMatchQ[ ids: { __String } ] := MemberQ[ ids, $SystemID ];
systemIDMatchQ[ _ ] := False;
systemIDMatchQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtension*)
(* Kept for compatibility: the first applicable entry. Code that needs extension data uses getAgentToolsExtensions. *)
getAgentToolsExtension // beginDefinition;

getAgentToolsExtension[ paclet_PacletObject ] := Enclose[
    Module[ { extensions },
        extensions = ConfirmMatch[ getAgentToolsExtensions @ paclet, { ___Association }, "Extensions" ];
        If[ extensions === { }, throwFailure[ "PacletExtensionNotFound", paclet[ "Name" ] ] ];
        { "AgentTools", First @ extensions }
    ],
    throwInternalFailure
];

getAgentToolsExtension // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtensionData*)
getAgentToolsExtensionData // beginDefinition;

getAgentToolsExtensionData[ paclet_PacletObject ] := Enclose[
    Last @ ConfirmMatch[ getAgentToolsExtension @ paclet, { "AgentTools", _Association }, "Extension" ],
    throwInternalFailure
];

getAgentToolsExtensionData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtensionDirectory*)
(* Kept for compatibility: the root directory of the first applicable entry. *)
getAgentToolsExtensionDirectory // beginDefinition;

getAgentToolsExtensionDirectory[ paclet_PacletObject ] := Enclose[
    Module[ { extension },
        extension = ConfirmMatch[ getAgentToolsExtension @ paclet, { "AgentTools", _Association }, "Extension" ];
        Needs[ "PacletTools`" -> None ];
        ConfirmBy[ pt`PacletExtensionDirectory[ paclet, extension ], StringQ, "Directory" ]
    ],
    throwInternalFailure
];

getAgentToolsExtensionDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsExtensionDirectories*)
(* The existing root directories of all applicable entries, in entry order, without duplicates. *)
getAgentToolsExtensionDirectories // beginDefinition;

getAgentToolsExtensionDirectories[ paclet_PacletObject ] := Enclose[
    Module[ { extensions },
        extensions = ConfirmMatch[ getAgentToolsExtensions @ paclet, { ___Association }, "Extensions" ];
        DeleteDuplicates @ Cases[ extensionDirectory[ paclet, # ] & /@ extensions, _String ]
    ],
    throwInternalFailure
];

getAgentToolsExtensionDirectories // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extensionDirectory*)
(* PacletExtensionDirectory returns a Failure for a "Root" that does not exist and Missing[...] for a missing default
   root, so anything other than an existing directory is treated as missing. *)
extensionDirectory // beginDefinition;

extensionDirectory[ paclet_PacletObject, data_Association ] :=
    Module[ { dir },
        Needs[ "PacletTools`" -> None ];
        dir = Quiet @ pt`PacletExtensionDirectory[ paclet, { "AgentTools", data } ];
        If[ StringQ @ dir && DirectoryQ @ dir, normalizeDirectory @ dir, Missing[ "NotAvailable" ] ]
    ];

extensionDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*normalizeDirectory*)
(* Resolves "." and ".." components and removes trailing separators, so that equal directories compare equal. *)
normalizeDirectory // beginDefinition;
normalizeDirectory[ dir_String ] := FileNameJoin @ FileNameSplit @ ExpandFileName @ dir;
normalizeDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Declarations*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractItemName*)
extractItemName // beginDefinition;
extractItemName[ name_String ] := name;
extractItemName[ { name_String, _String } ] := name;
extractItemName[ as_Association ] /; KeyExistsQ[ as, "Name" ] := as[ "Name" ];
extractItemName[ ___ ] := $Failed;
extractItemName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validItemNameQ*)
(* Item names are paclet-scoped and must not contain "/" (cross-paclet references belong in definition files). *)
validItemNameQ // beginDefinition;
validItemNameQ[ name_String ] := StringLength @ name > 0 && ! StringContainsQ[ name, "/" ];
validItemNameQ[ _ ] := False;
validItemNameQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsDeclaredItems*)
(* The union of the item names of the given type declared by all applicable entries, in declaration order. *)
getAgentToolsDeclaredItems // beginDefinition;

getAgentToolsDeclaredItems[ paclet_PacletObject, type_String ] := Enclose[
    Module[ { declarations },
        declarations = ConfirmMatch[ getAgentToolsDeclarations[ paclet, type ], { ___ }, "Declarations" ];
        ConfirmMatch[ extractItemName /@ declarations, { ___String }, "Names" ]
    ],
    throwInternalFailure
];

getAgentToolsDeclaredItems // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsItemDeclaration*)
(* The declaration (name, {name, description}, or association) of a declared item; the first occurrence wins. *)
getAgentToolsItemDeclaration // beginDefinition;

getAgentToolsItemDeclaration[ paclet_PacletObject, type_String, name_String ] := Enclose[
    SelectFirst[
        ConfirmMatch[ getAgentToolsDeclarations[ paclet, type ], { ___ }, "Declarations" ],
        extractItemName @ # === name &,
        Missing[ "NotFound" ]
    ],
    throwInternalFailure
];

getAgentToolsItemDeclaration // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsDeclarations*)
getAgentToolsDeclarations // beginDefinition;

getAgentToolsDeclarations[ paclet_PacletObject, type_String ] := Enclose[
    Module[ { extensions },
        extensions = ConfirmMatch[ getAgentToolsExtensions @ paclet, { ___Association }, "Extensions" ];
        DeleteDuplicatesBy[ Join @@ (entryDeclarations[ #, type ] & /@ extensions), extractItemName ]
    ],
    throwInternalFailure
];

getAgentToolsDeclarations // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*entryDeclarations*)
(* Malformed declarations and invalid names are skipped here (ValidateAgentToolsPacletExtension reports them). *)
entryDeclarations // beginDefinition;

entryDeclarations[ data_Association, type_String ] :=
    Select[ Replace[ Lookup[ data, type, { } ], Except[ _List ] -> { } ], validItemNameQ @* extractItemName ];

entryDeclarations // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*findInstalledPaclet*)
(* PacletObject[ name ] would also treat "*" as a wildcard and names ending in ".paclet" as files, so the installed
   paclet is selected from PacletFind by exact name. *)
findInstalledPaclet // beginDefinition;

findInstalledPaclet[ pacletName_String ] :=
    Replace[
        Select[ PacletFind @ pacletName, #[ "Name" ] === pacletName & ],
        {
            { paclet_PacletObject, ___ } :> paclet,
            _ :> Failure[
                "PacletNotFound",
                <|
                    "MessageTemplate"   -> "No appropriate paclet with name `1` is installed.",
                    "MessageParameters" -> { pacletName }
                |>
            ]
        }
    ];

findInstalledPaclet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definition Files*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadFile*)
loadFile // beginDefinition;
loadFile[ file_String ] /; StringEndsQ[ file, ".mx"  ] := Import[ file, "MX" ];
loadFile[ file_String ] /; StringEndsQ[ file, ".wxf" ] := readWXFFile @ file;
loadFile[ file_String ] /; StringEndsQ[ file, ".wl"  ] := Get @ file;
loadFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*findPerItemFile*)
$extensionPriority = <| "mx" -> 1, "wxf" -> 2, "wl" -> 3 |>;

findPerItemFile // beginDefinition;

findPerItemFile[ root_String, type_String, name_String ] :=
    Module[ { dir, files },
        dir = FileNameJoin @ { root, type };
        files = FileNames[ { name <> ".mx", name <> ".wxf", name <> ".wl" }, dir ];
        If[ Length @ files > 0,
            First @ SortBy[ files, Lookup[ $extensionPriority, FileExtension[ # ], 99 ] & ],
            $Failed
        ]
    ];

findPerItemFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*findCombinedFile*)
findCombinedFile // beginDefinition;

findCombinedFile[ root_String, type_String ] :=
    Module[ { files },
        files = FileNames[ { type <> ".mx", type <> ".wxf", type <> ".wl" }, root ];
        If[ Length @ files > 0,
            First @ SortBy[ files, Lookup[ $extensionPriority, FileExtension[ # ], 99 ] & ],
            $Failed
        ]
    ];

findCombinedFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillDirectoryQ*)
skillDirectoryQ // beginDefinition;
skillDirectoryQ[ dir_String ] := DirectoryQ @ dir && FileExistsQ @ FileNameJoin @ { dir, $skillFileName };
skillDirectoryQ[ _ ] := False;
skillDirectoryQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*findPacletDefinitionSource*)
(* Searches every root (in entry order) and returns where the first root that defines the item defines it:
   <| "Type" -> "Directory" | "File" | "Combined", "Root" -> root, "Path" -> path (, "Definition" -> def) |>,
   or Missing[ "NotFound" ]. *)
findPacletDefinitionSource // beginDefinition;

findPacletDefinitionSource[ paclet_PacletObject, type_String, name_String ] := Enclose[
    Catch @ Module[ { roots },
        roots = ConfirmMatch[ getAgentToolsExtensionDirectories @ paclet, { ___String }, "Roots" ];
        Do[
            With[ { source = findDefinitionSourceInRoot[ root, type, name ] },
                If[ AssociationQ @ source, Throw @ source ]
            ],
            { root, roots }
        ];
        Missing[ "NotFound" ]
    ],
    throwInternalFailure
];

findPacletDefinitionSource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*findDefinitionSourceInRoot*)
(* Within one root: the skill directory (skills only), then the per-item file, then the combined file (which only
   defines the item if it contains its key). *)
findDefinitionSourceInRoot // beginDefinition;

findDefinitionSourceInRoot[ root_String, type_String, name_String ] := Catch @ Module[ { dir, file, combined, data },

    If[ type === "AgentSkills",
        dir = FileNameJoin @ { root, type, name };
        If[ skillDirectoryQ @ dir, Throw @ <| "Type" -> "Directory", "Root" -> root, "Path" -> dir |> ]
    ];

    file = findPerItemFile[ root, type, name ];
    If[ StringQ @ file, Throw @ <| "Type" -> "File", "Root" -> root, "Path" -> file |> ];

    combined = findCombinedFile[ root, type ];
    If[ StringQ @ combined,
        data = loadFile @ combined;
        If[ AssociationQ @ data && KeyExistsQ[ data, name ],
            Throw @ <| "Type" -> "Combined", "Root" -> root, "Path" -> combined, "Definition" -> data[ name ] |>
        ]
    ];

    Missing[ "NotFound" ]
];

findDefinitionSourceInRoot // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadPacletDefinitionFile*)
(* Loads the definition of a declared item (see findPacletDefinitionSource), or returns $Failed if no root defines
   it. For a skill directory, the definition is the LLMSkill parsed from its SKILL.md. Definitions are cached per
   session; the search is deterministic, so the cache key does not include the root. *)
loadPacletDefinitionFile // beginDefinition;

loadPacletDefinitionFile[ paclet_PacletObject, type_String, name_String ] :=
    loadPacletDefinitionFile[ paclet, type, name, Automatic ];

loadPacletDefinitionFile[ paclet_PacletObject, type_String, name_String, source0_ ] := Enclose[
    Catch @ Module[ { cacheKey, cached, source, result },
        (* Check cache *)
        cacheKey = { paclet[ "Name" ], paclet[ "Version" ], type, name };
        cached = $pacletDefinitionCache[ cacheKey ];
        If[ cacheableResultQ @ cached, Throw @ cached ];

        source = If[ source0 === Automatic, findPacletDefinitionSource[ paclet, type, name ], source0 ];
        If[ ! AssociationQ @ source, Throw @ $Failed ];

        result = loadDefinitionSource @ source;
        If[ cacheableResultQ @ result, $pacletDefinitionCache[ cacheKey ] = result ];
        result
    ],
    throwInternalFailure
];

loadPacletDefinitionFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadDefinitionSource*)
loadDefinitionSource // beginDefinition;
loadDefinitionSource[ KeyValuePattern @ { "Type" -> "Directory", "Path" -> dir_String } ] := skillDirectoryDefinition @ dir;
loadDefinitionSource[ KeyValuePattern @ { "Type" -> "File", "Path" -> file_String } ] := loadFile @ file;
loadDefinitionSource[ KeyValuePattern @ { "Type" -> "Combined", "Definition" -> definition_ } ] := definition;
loadDefinitionSource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillDirectoryDefinition*)
(* The LLMSkill of a skill directory, or its data read with parseSkillMarkdown when LLMSkill[File[dir]] fails (it does
   for frontmatter containing characters in U+0080-U+00FF). *)
skillDirectoryDefinition // beginDefinition;
skillDirectoryDefinition[ dir_String ] := Replace[ Quiet @ LLMSkill @ File @ dir, Except[ $$llmSkill ] :> parseSkillMarkdown @ dir ];
skillDirectoryDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cacheableResultQ*)
cacheableResultQ // beginDefinition;
cacheableResultQ[ _Association ] := True;
cacheableResultQ[ _LLMTool     ] := True;
cacheableResultQ[ $$llmSkill   ] := True;
cacheableResultQ[ ___          ] := False;
cacheableResultQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*qualifyName*)
qualifyName // beginDefinition;

qualifyName[ name_String, pacletName_String ] :=
    If[ StringContainsQ[ name, "/" ], name, pacletName <> "/" <> name ];

qualifyName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*qualifyNamesInLLMEvaluator*)
qualifyNamesInLLMEvaluator // beginDefinition;

qualifyNamesInLLMEvaluator[ evaluator_Association, pacletName_String ] :=
    Module[ { result = evaluator },
        If[ KeyExistsQ[ result, "Tools" ] && ListQ @ result[ "Tools" ],
            result[ "Tools" ] = qualifyName[ #, pacletName ] & /@ result[ "Tools" ]
        ];
        If[ KeyExistsQ[ result, "MCPPrompts" ] && ListQ @ result[ "MCPPrompts" ],
            result[ "MCPPrompts" ] = qualifyName[ #, pacletName ] & /@ result[ "MCPPrompts" ]
        ];
        result
    ];

qualifyNamesInLLMEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*resolvePacletTool*)
resolvePacletTool // beginDefinition;

resolvePacletTool[ qualifiedName_String ] := Enclose[
    Module[ { parsed, pacletName, itemName, paclet, declaredTools, definition },
        parsed = ConfirmBy[ parsePacletQualifiedName @ qualifiedName, AssociationQ, "Parse" ];
        pacletName = parsed[ "PacletName" ];
        itemName = parsed[ "ItemName" ];

        paclet = findInstalledPaclet @ pacletName;
        If[ ! MatchQ[ paclet, _PacletObject ],
            With[ { pn = pacletName }, throwFailure[ "PacletNotInstalled", pn, HoldForm @ PacletInstall @ pn ] ]
        ];

        declaredTools = getAgentToolsDeclaredItems[ paclet, "Tools" ];
        If[ ! MemberQ[ declaredTools, itemName ],
            throwFailure[ "PacletToolNotFound", itemName, pacletName ]
        ];

        definition = ConfirmMatch[
            loadPacletDefinitionFile[ paclet, "Tools", itemName ],
            _Association | _LLMTool | $Failed,
            "Definition"
        ];

        toResolvedToolDefinition @ definition
    ],
    throwInternalFailure
];

resolvePacletTool // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toResolvedToolDefinition*)
toResolvedToolDefinition // beginDefinition;
toResolvedToolDefinition[ tool_LLMTool     ] := tool;
toResolvedToolDefinition[ as_Association   ] := KeySort @ <| $toolDefaults, as |>;
toResolvedToolDefinition[ $Failed          ] := $Failed;
toResolvedToolDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*resolvePacletServer*)
resolvePacletServer // beginDefinition;

resolvePacletServer[ qualifiedName_String ] := Enclose[
    Catch @ Module[ { parsed, pacletName, itemName, paclet, declaredServers, definition },
        parsed = ConfirmBy[ parsePacletQualifiedName @ qualifiedName, AssociationQ, "Parse" ];
        pacletName = parsed[ "PacletName" ];
        itemName = parsed[ "ItemName" ];

        paclet = findInstalledPaclet @ pacletName;
        If[ ! MatchQ[ paclet, _PacletObject ],
            With[ { pn = pacletName }, throwFailure[ "PacletNotInstalled", pn, HoldForm @ PacletInstall @ pn ] ]
        ];

        declaredServers = getAgentToolsDeclaredItems[ paclet, "MCPServers" ];
        If[ ! MemberQ[ declaredServers, itemName ],
            throwFailure[ "PacletServerNotFound", itemName, pacletName ]
        ];

        definition = ConfirmMatch[
            loadPacletDefinitionFile[ paclet, "MCPServers", itemName ],
            _Association | $Failed,
            "Definition"
        ];

        If[ ! AssociationQ @ definition, Throw @ $Failed ];

        (* Pre-qualify short names in LLMEvaluator *)
        If[ KeyExistsQ[ definition, "LLMEvaluator" ] && AssociationQ @ definition[ "LLMEvaluator" ],
            definition[ "LLMEvaluator" ] = qualifyNamesInLLMEvaluator[ definition[ "LLMEvaluator" ], pacletName ]
        ];

        KeySort @ definition
    ],
    throwInternalFailure
];

resolvePacletServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*resolvePacletPrompt*)
resolvePacletPrompt // beginDefinition;

resolvePacletPrompt[ qualifiedName_String ] := Enclose[
    Module[ { parsed, pacletName, itemName, paclet, declaredPrompts },
        parsed = ConfirmBy[ parsePacletQualifiedName @ qualifiedName, AssociationQ, "Parse" ];
        pacletName = parsed[ "PacletName" ];
        itemName = parsed[ "ItemName" ];

        paclet = findInstalledPaclet @ pacletName;
        If[ ! MatchQ[ paclet, _PacletObject ],
            With[ { pn = pacletName }, throwFailure[ "PacletNotInstalled", pn, HoldForm @ PacletInstall @ pn ] ]
        ];

        declaredPrompts = getAgentToolsDeclaredItems[ paclet, "MCPPrompts" ];
        If[ ! MemberQ[ declaredPrompts, itemName ],
            throwFailure[ "PacletPromptNotFound", itemName, pacletName ]
        ];

        ConfirmBy[
            loadPacletDefinitionFile[ paclet, "MCPPrompts", itemName ],
            AssociationQ,
            "Definition"
        ]
    ],
    throwInternalFailure
];

resolvePacletPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Bundles*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsBundles*)
(* Each applicable entry that declares at least one MCP server or agent skill defines a bundle. Built from PacletInfo
   only (no definition files are loaded). Entries with an invalid "Name" are skipped, and the first entry wins if
   several entries define the same name (ValidateAgentToolsPacletExtension reports both). *)
getAgentToolsBundles // beginDefinition;

getAgentToolsBundles[ paclet_PacletObject ] := Enclose[
    Module[ { pacletName, extensions, bundles },
        pacletName = ConfirmBy[ paclet[ "Name" ], StringQ, "PacletName" ];
        extensions = ConfirmMatch[ getAgentToolsExtensions @ paclet, { ___Association }, "Extensions" ];
        bundles = DeleteMissing[ extensionBundle[ paclet, pacletName, # ] & /@ extensions ];
        ConfirmMatch[ DeleteDuplicatesBy[ bundles, Lookup[ "Name" ] ], { ___Association }, "Result" ]
    ],
    throwInternalFailure
];

getAgentToolsBundles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extensionBundle*)
extensionBundle // beginDefinition;

extensionBundle[ paclet_PacletObject, pacletName_String, data_Association ] := Catch @ Module[
    { name, servers, skills, description },

    name = Lookup[ data, "Name", $defaultBundleName ];
    If[ ! validItemNameQ @ name, Throw @ Missing[ "InvalidName" ] ];

    servers = DeleteDuplicates[ extractItemName /@ entryDeclarations[ data, "MCPServers"  ] ];
    skills  = DeleteDuplicates[ extractItemName /@ entryDeclarations[ data, "AgentSkills" ] ];
    If[ servers === { } && skills === { }, Throw @ Missing[ "NoBundle" ] ];

    description = Lookup[ data, "Description" ];

    DeleteMissing @ <|
        "Name"        -> qualifyName[ name, pacletName ],
        "Location"    -> paclet,
        "MCPServers"  -> (qualifyName[ #, pacletName ] & /@ servers),
        "AgentSkills" -> (qualifyName[ #, pacletName ] & /@ skills),
        "Description" -> If[ StringQ @ description, description, Missing[ "NotAvailable" ] ]
    |>
];

extensionBundle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePacletBundle*)
(* Bundle data for a qualified bundle name: from the installed paclet if there is one, otherwise from remote
   paclet metadata (never installs). Returns Missing[ "NotFound" ] so that callers can decide the failure. *)
resolvePacletBundle // beginDefinition;

resolvePacletBundle[ qualifiedName_String ] := Enclose[
    Catch @ Module[ { parsed, pacletName, paclet, bundles },
        If[ ! pacletQualifiedNameQ @ qualifiedName, Throw @ Missing[ "NotFound" ] ];
        parsed = ConfirmBy[ parsePacletQualifiedName @ qualifiedName, AssociationQ, "Parse" ];
        pacletName = parsed[ "PacletName" ];

        paclet = findInstalledPaclet @ pacletName;
        If[ ! MatchQ[ paclet, _PacletObject ], paclet = findRemoteAgentToolsPaclet @ pacletName ];
        If[ ! MatchQ[ paclet, _PacletObject ], Throw @ Missing[ "NotFound" ] ];

        bundles = ConfirmMatch[ getAgentToolsBundles @ paclet, { ___Association }, "Bundles" ];
        SelectFirst[ bundles, #[ "Name" ] === qualifiedName &, Missing[ "NotFound" ] ]
    ],
    throwInternalFailure
];

resolvePacletBundle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skills*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePacletSkill*)
(* Resolves a skill declared by an installed paclet to a skill definition:
   <|
       "Type"          -> "PacletSkill",
       "Name"          -> name,
       "QualifiedName" -> "Pub/Paclet/name",
       "PacletName"    -> "Pub/Paclet",
       "PacletVersion" -> version,
       "Directory"     -> File[ dir ]                     (* skill directory, or an LLMSkill whose Location is honored *)
       (* or *)
       "Definition"    -> LLMSkill[ ... ] | <| ... |>
   |> *)
resolvePacletSkill // beginDefinition;

resolvePacletSkill[ qualifiedName_String ] := Enclose[
    Module[ { parsed, pacletName, paclet },
        If[ ! pacletQualifiedNameQ @ qualifiedName, throwFailure[ "AgentSkillNotFound", qualifiedName ] ];
        parsed = ConfirmBy[ parsePacletQualifiedName @ qualifiedName, AssociationQ, "Parse" ];
        pacletName = parsed[ "PacletName" ];

        paclet = findInstalledPaclet @ pacletName;
        If[ ! MatchQ[ paclet, _PacletObject ],
            With[ { pn = pacletName }, throwFailure[ "PacletNotInstalled", pn, HoldForm @ PacletInstall @ pn ] ]
        ];

        resolvePacletSkill[ paclet, parsed[ "ItemName" ] ]
    ],
    throwInternalFailure
];

resolvePacletSkill[ paclet_PacletObject, name_String ] := Enclose[
    Module[ { pacletName, declared, source, definition, content },
        pacletName = ConfirmBy[ paclet[ "Name" ], StringQ, "PacletName" ];

        declared = ConfirmMatch[ getAgentToolsDeclaredItems[ paclet, "AgentSkills" ], { ___String }, "Declared" ];
        If[ ! MemberQ[ declared, name ], throwFailure[ "PacletSkillNotFound", name, pacletName ] ];

        source = findPacletDefinitionSource[ paclet, "AgentSkills", name ];
        If[ ! AssociationQ @ source, throwFailure[ "PacletSkillNotFound", name, pacletName ] ];

        definition = loadPacletDefinitionFile[ paclet, "AgentSkills", name, source ];
        content = ConfirmBy[ pacletSkillContent[ paclet, name, source, definition ], AssociationQ, "Content" ];

        Join[
            <|
                "Type"          -> "PacletSkill",
                "Name"          -> name,
                "QualifiedName" -> pacletName <> "/" <> name,
                "PacletName"    -> pacletName,
                "PacletVersion" -> paclet[ "Version" ]
            |>,
            content
        ]
    ],
    throwInternalFailure
];

resolvePacletSkill // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*pacletSkillContent*)
(* <| "Directory" -> File[ dir ] |> or <| "Definition" -> definition |> for a loaded skill definition. *)
pacletSkillContent // beginDefinition;

pacletSkillContent[ paclet_PacletObject, name_String, source_Association, definition_ ] := Catch @ Module[
    { data, dir },

    data = skillDefinitionData @ definition;
    If[ ! validSkillDefinitionDataQ[ data, name ],
        throwFailure[ "InvalidPacletSkillDefinition", source[ "Path" ] ]
    ];

    (* A skill directory is copied as-is *)
    If[ source[ "Type" ] === "Directory", Throw @ <| "Directory" -> File @ source[ "Path" ] |> ];

    (* A "Location" is only honored if it is a skill directory inside one of the paclet's extension roots *)
    dir = honoredSkillDirectory[ paclet, Lookup[ data, "Location", None ], source ];
    If[ StringQ @ dir,
        If[ ! validSkillDefinitionDataQ[ skillDefinitionData @ skillDirectoryDefinition @ dir, name ],
            throwFailure[ "InvalidPacletSkillDefinition", dir ]
        ];
        Throw @ <| "Directory" -> File @ dir |>
    ];

    If[ MatchQ[ definition, $$llmSkill ] && MatchQ[ Lookup[ data, "Location", None ], None ],
        <| "Definition" -> definition |>,
        (* Any other "Location" is ignored, so SKILL.md is generated from the fields: *)
        <| "Definition" -> KeyDrop[ data, $nonDefinitionSkillKeys ] |>
    ]
];

pacletSkillContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillDefinitionData*)
skillDefinitionData // beginDefinition;
skillDefinitionData[ HoldPattern[ LLMSkill ][ as_Association ] ] := as;
skillDefinitionData[ as_Association ] := as;
skillDefinitionData[ _ ] := $Failed;
skillDefinitionData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validSkillDefinitionDataQ*)
(* The declared name must equal the skill's name. Name and description rules are checked when the skill is
   installed (and by ValidateAgentToolsPacletExtension). *)
validSkillDefinitionDataQ // beginDefinition;

validSkillDefinitionDataQ[ data_Association, name_String ] :=
    TrueQ @ And[
        Lookup[ data, "Name" ] === name,
        StringQ @ Lookup[ data, "Description" ],
        StringQ @ Lookup[ data, "Body" ]
    ];

validSkillDefinitionDataQ[ _, _ ] := False;

validSkillDefinitionDataQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*honoredSkillDirectory*)
(* A relative location is resolved against the directory of the definition file. *)
honoredSkillDirectory // beginDefinition;

honoredSkillDirectory[ paclet_PacletObject, File[ location_String ], source_Association ] := Enclose[
    Catch @ Module[ { path, roots },
        If[ location === "", Throw @ None ];
        path = normalizeDirectory @ If[ absolutePathQ @ location,
                                        location,
                                        FileNameJoin @ { DirectoryName @ source[ "Path" ], location }
                                    ];
        roots = ConfirmMatch[ getAgentToolsExtensionDirectories @ paclet, { ___String }, "Roots" ];
        If[ AnyTrue[ roots, pathInsideDirectoryQ[ path, # ] & ] && skillDirectoryQ @ path, path, None ]
    ],
    throwInternalFailure
];

honoredSkillDirectory[ paclet_PacletObject, _, source_Association ] := None;

honoredSkillDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*absolutePathQ*)
absolutePathQ // beginDefinition;
absolutePathQ[ path_String ] := StringStartsQ[ path, "/" | "\\" | "~" | (LetterCharacter ~~ ":") ];
absolutePathQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*pathInsideDirectoryQ*)
(* True if path is strictly inside dir (both already normalized). *)
pathInsideDirectoryQ // beginDefinition;

pathInsideDirectoryQ[ path_String, dir_String ] :=
    Module[ { pathParts, dirParts },
        pathParts = comparablePathParts @ path;
        dirParts  = comparablePathParts @ dir;
        Length @ pathParts > Length @ dirParts && Take[ pathParts, Length @ dirParts ] === dirParts
    ];

pathInsideDirectoryQ // endDefinition;

comparablePathParts // beginDefinition;
comparablePathParts[ path_String ] /; $OperatingSystem === "Unix" := FileNameSplit @ path;
comparablePathParts[ path_String ] := ToLowerCase @ FileNameSplit @ path;
comparablePathParts // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ensurePacletForInstall*)
ensurePacletForInstall // beginDefinition;

ensurePacletForInstall[ qualifiedName_String ] := Enclose[
    Catch @ Module[ { parsed, pacletName, paclet },
        parsed = ConfirmBy[ parsePacletQualifiedName @ qualifiedName, AssociationQ, "Parse" ];
        pacletName = parsed[ "PacletName" ];

        (* Already installed? *)
        paclet = findInstalledPaclet @ pacletName;
        If[ MatchQ[ paclet, _PacletObject ], Throw @ paclet ];

        (* Try to install (PacletInstall treats "*" as a wildcard and could install an unrelated paclet) *)
        If[ StringFreeQ[ pacletName, "*" ],
            paclet = Quiet @ PacletInstall @ pacletName;
            If[ MatchQ[ paclet, _PacletObject ] && paclet[ "Name" ] === pacletName, Throw @ paclet ]
        ];

        With[ { pn = pacletName },
            throwFailure[ "PacletNotInstalled", pn, HoldForm @ PacletInstall @ pn ]
        ]
    ],
    throwInternalFailure
];

ensurePacletForInstall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
