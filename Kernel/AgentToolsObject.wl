(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`AgentToolsObject`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

$ContextAliases[ "sp`" ] = "System`Private`";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$serverSpec   = _String? StringQ | _MCPServerObject;
$$skillSpec    = _String? StringQ | HoldPattern[ LLMSkill ][ _Association? AssociationQ ] | _File | _Association? AssociationQ;
$$toolsetType  = "AgentToolsObject" | "MCPServerObject";
$$location     = "BuiltIn" | _PacletObject | _File | None;

$$agentToolsData = KeyValuePattern @ {
    "Name"        -> _String? StringQ,
    "Location"    -> $$location,
    "MCPServers"  -> { $$serverSpec... },
    "AgentSkills" -> { $$skillSpec... }
};

$agentToolsProperties = {
    "AgentSkillNames",
    "AgentSkills",
    "Data",
    "Description",
    "LLMSkills",
    "Location",
    "MCPServerNames",
    "MCPServerObjects",
    "MCPServers",
    "Name",
    "Properties",
    "Tools",
    "ToolsetType"
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$DefaultAgentTools*)
(* The built-in bundles: one per default MCP server, with the same name. Skills are given by name only and resolved
   at deploy time, so nothing machine-specific is baked into the MX file. *)
$DefaultAgentTools := WithCleanup[
    Unprotect @ $DefaultAgentTools,
    $DefaultAgentTools = AgentToolsObject /@ KeySort @ $defaultAgentTools,
    Protect @ $DefaultAgentTools
];

$defaultAgentTools = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Wolfram*)
$defaultAgentTools[ "Wolfram" ] = <|
    "Name"        -> "Wolfram",
    "Description" -> "Tools for general computation and knowledge",
    "Location"    -> "BuiltIn",
    "MCPServers"  -> { "Wolfram" },
    "AgentSkills" -> { }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WolframAlpha*)
$defaultAgentTools[ "WolframAlpha" ] = <|
    "Name"        -> "WolframAlpha",
    "Description" -> "Tools for Wolfram|Alpha natural language queries",
    "Location"    -> "BuiltIn",
    "MCPServers"  -> { "WolframAlpha" },
    "AgentSkills" -> { }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WolframLanguage*)
$defaultAgentTools[ "WolframLanguage" ] = <|
    "Name"        -> "WolframLanguage",
    "Description" -> "Tools for Wolfram Language development",
    "Location"    -> "BuiltIn",
    "MCPServers"  -> { "WolframLanguage" },
    "AgentSkills" -> { }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WolframPacletDevelopment*)
$defaultAgentTools[ "WolframPacletDevelopment" ] = <|
    "Name"        -> "WolframPacletDevelopment",
    "Description" -> "Tools for Wolfram Paclet development",
    "Location"    -> "BuiltIn",
    "MCPServers"  -> { "WolframPacletDevelopment" },
    "AgentSkills" -> { }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AgentToolsObject*)
AgentToolsObject // ClearAll;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Main Definition*)
AgentToolsObject[ data_Association ]? sp`HoldNotValidQ :=
    catchTop[ createAgentToolsObject @ data, AgentToolsObject ];

AgentToolsObject[ name_String ] :=
    catchMine @ getAgentToolsObjectByName @ name;

AgentToolsObject[ obj_AgentToolsObject? agentToolsObjectQ ] :=
    obj;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createAgentToolsObject*)
createAgentToolsObject // beginDefinition;

createAgentToolsObject[ data_Association ] := Enclose[
    Module[ { name, location, servers, skills, description, valid },

        name = Lookup[ data, "Name", Missing[ "NotAvailable" ] ];
        If[ ! StringQ @ name, throwFailure[ "InvalidAgentToolsObject", data ] ];

        location    = Lookup[ data, "Location"   , None ];
        servers     = Flatten @ { Lookup[ data, "MCPServers" , { } ] };
        skills      = Flatten @ { Lookup[ data, "AgentSkills", { } ] };
        description = Lookup[ data, "Description", Missing[ "NotAvailable" ] ];

        If[ ! MatchQ[ description, _String | _Missing ], throwFailure[ "InvalidAgentToolsObject", data ] ];

        valid = DeleteMissing @ <|
            data,
            "Name"        -> name,
            "Location"    -> location,
            "MCPServers"  -> servers,
            "AgentSkills" -> skills,
            "Description" -> description
        |>;

        If[ ! MatchQ[ valid, $$agentToolsData ], throwFailure[ "InvalidAgentToolsObject", data ] ];
        If[ ! MatchQ[ Lookup[ valid, "ToolsetType", "AgentToolsObject" ], $$toolsetType ],
            throwFailure[ "InvalidAgentToolsObject", data ]
        ];

        (* Names containing "/" are reserved for paclets, and ad hoc bundles may not shadow the built-in ones *)
        If[ adHocAgentToolsQ @ valid && (StringContainsQ[ name, "/" ] || KeyExistsQ[ $defaultAgentTools, name ]),
            throwFailure[ "InvalidAgentToolsObject", data ]
        ];

        With[ { v = valid }, sp`HoldSetValid @ AgentToolsObject @ v ]
    ],
    throwInternalFailure
];

createAgentToolsObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*adHocAgentToolsQ*)
(* An ad hoc bundle: created directly from an association, as opposed to a built-in bundle, a paclet bundle, or the
   implicit bundle that wraps an MCPServerObject. *)
adHocAgentToolsQ // beginDefinition;
adHocAgentToolsQ[ data_Association ] := data[ "Location" ] === None && ! KeyExistsQ[ data, "ToolsetType" ];
adHocAgentToolsQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Get AgentToolsObject by Name*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAgentToolsObjectByName*)
getAgentToolsObjectByName // beginDefinition;

getAgentToolsObjectByName[ name_String ] := Enclose[
    Catch @ Module[ { data },

        (* Built-in bundles *)
        If[ KeyExistsQ[ $defaultAgentTools, name ],
            Throw @ ConfirmBy[ AgentToolsObject @ $defaultAgentTools @ name, agentToolsObjectQ, "BuiltIn" ]
        ];

        (* A paclet without a publisher prefix, named by its paclet name *)
        If[ ! StringContainsQ[ name, "/" ],
            data = Replace[ installedAgentToolsPaclet @ name, paclet_PacletObject :> onlyBundle[ paclet, name ] ];
            If[ ! AssociationQ @ data, throwFailure[ "AgentToolsNotFound", name ] ];
            Throw @ ConfirmBy[ AgentToolsObject @ data, agentToolsObjectQ, "PacletName" ]
        ];

        data = findPacletBundle @ name;
        If[ ! AssociationQ @ data, throwFailure[ "AgentToolsNotFound", name ] ];

        ConfirmBy[ AgentToolsObject @ data, agentToolsObjectQ, "Paclet" ]
    ],
    throwInternalFailure
];

getAgentToolsObjectByName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*findPacletBundle*)
(* Resolves a name containing "/" to the bundle data of a paclet, without installing anything:
     1. an installed paclet with exactly this name -> its only bundle
     2. an installed paclet that declares the bundle named by the qualified interpretation of the name
     3. for a two-segment name, a remote paclet with exactly this name -> its only bundle
     4. a remote paclet that declares the bundle named by the qualified interpretation of the name
   Checking the full name as a paclet name first means that "Publisher/Paclet" never means paclet "Publisher",
   bundle "Paclet". Returns the bundle data or Missing["NotFound"]. *)
findPacletBundle // beginDefinition;

findPacletBundle[ name_String ] := Enclose[
    Catch @ Module[ { paclet, parsed, segments, installedQualified, data },

        paclet = installedAgentToolsPaclet @ name;
        If[ MatchQ[ paclet, _PacletObject ], Throw @ onlyBundle[ paclet, name ] ];

        segments = Length @ StringSplit[ name, "/" ];
        parsed   = If[ pacletQualifiedNameQ @ name, parsePacletQualifiedName @ name, None ];
        installedQualified = False;
        If[ AssociationQ @ parsed,
            paclet = installedAgentToolsPaclet @ parsed[ "PacletName" ];
            If[ MatchQ[ paclet, _PacletObject ],
                data = namedBundle[ paclet, name ];
                (* For a two-segment name, the installed paclet may only share the publisher's name, so a remote paclet
                   with exactly this name is still checked below (but never the installed paclet's remote metadata) *)
                If[ AssociationQ @ data || segments =!= 2, Throw @ data ];
                installedQualified = True
            ]
        ];

        If[ segments === 2,
            paclet = remoteAgentToolsPaclet @ name;
            If[ MatchQ[ paclet, _PacletObject ], Throw @ onlyBundle[ paclet, name ] ]
        ];

        If[ AssociationQ @ parsed && ! installedQualified,
            paclet = remoteAgentToolsPaclet @ parsed[ "PacletName" ];
            If[ MatchQ[ paclet, _PacletObject ], Throw @ namedBundle[ paclet, name ] ]
        ];

        Missing[ "NotFound" ]
    ],
    throwInternalFailure
];

findPacletBundle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installedAgentToolsPaclet*)
installedAgentToolsPaclet // beginDefinition;

(* An installed paclet with exactly this name (PacletFind treats "*" as a wildcard), whether or not it has an
   "AgentTools" extension: as for MCPServerObject, an installed version takes precedence over remote metadata, so an
   installed version without the bundle means the bundle is not found (the paclet needs to be updated). *)
installedAgentToolsPaclet[ pacletName_String ] :=
    Replace[ Quiet @ findInstalledPaclet @ pacletName, Except[ _PacletObject ] -> Missing[ "NotInstalled" ] ];

installedAgentToolsPaclet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*remoteAgentToolsPaclet*)
remoteAgentToolsPaclet // beginDefinition;

(* Exact names only (see findRemoteAgentToolsPaclet) *)
remoteAgentToolsPaclet[ pacletName_String ] :=
    findRemoteAgentToolsPaclet @ pacletName;

remoteAgentToolsPaclet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*onlyBundle*)
(* The bundle of a paclet that was named by its paclet name. *)
onlyBundle // beginDefinition;

onlyBundle[ paclet_PacletObject, name_String ] := Enclose[
    Module[ { bundles },
        bundles = ConfirmMatch[ pacletBundles @ paclet, { ___Association }, "Bundles" ];
        Switch[ Length @ bundles,
            0, throwFailure[ "AgentToolsNotFound", name ],
            1, First @ bundles,
            _, throwFailure[ "AgentToolsBundleNameAmbiguous", paclet[ "Name" ], #[ "Name" ] & /@ bundles ]
        ]
    ],
    throwInternalFailure
];

onlyBundle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*namedBundle*)
namedBundle // beginDefinition;

namedBundle[ paclet_PacletObject, name_String ] := Enclose[
    Module[ { bundles },
        bundles = ConfirmMatch[ pacletBundles @ paclet, { ___Association }, "Bundles" ];
        SelectFirst[ bundles, #[ "Name" ] === name &, Missing[ "NotFound" ] ]
    ],
    throwInternalFailure
];

namedBundle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*pacletBundles*)
pacletBundles // beginDefinition;

pacletBundles[ paclet_PacletObject ] :=
    Replace[ Quiet @ catchAlways @ getAgentToolsBundles @ paclet, Except[ { ___Association } ] :> { } ];

pacletBundles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Properties*)
(AgentToolsObject[ data_Association ]? agentToolsObjectQ)[ prop_String ] :=
    catchTop[ getAgentToolsObjectProperty[ data, prop ], AgentToolsObject ];

(AgentToolsObject[ data_Association ]? agentToolsObjectQ)[ props: { ___String } ] :=
    catchTop[ AssociationMap[ getAgentToolsObjectProperty[ data, # ] &, props ], AgentToolsObject ];

_AgentToolsObject[ invalid_ ] :=
    catchTop[ throwFailure[ "InvalidProperty", invalid ], AgentToolsObject ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAgentToolsObjectProperty*)
getAgentToolsObjectProperty // beginDefinition;

getAgentToolsObjectProperty[ data_, "Data"             ] := data;
getAgentToolsObjectProperty[ data_, "Properties"       ] := $agentToolsProperties;
getAgentToolsObjectProperty[ data_, "Name"             ] := data[ "Name" ];
getAgentToolsObjectProperty[ data_, "Location"         ] := data[ "Location" ];
getAgentToolsObjectProperty[ data_, "MCPServers"       ] := data[ "MCPServers" ];
getAgentToolsObjectProperty[ data_, "AgentSkills"      ] := data[ "AgentSkills" ];
getAgentToolsObjectProperty[ data_, "Description"      ] := Lookup[ data, "Description", Missing[ "NotAvailable" ] ];
getAgentToolsObjectProperty[ data_, "ToolsetType"      ] := Lookup[ data, "ToolsetType", "AgentToolsObject" ];
getAgentToolsObjectProperty[ data_, "MCPServerNames"   ] := serverSpecName /@ data[ "MCPServers" ];
getAgentToolsObjectProperty[ data_, "AgentSkillNames"  ] := skillSpecName /@ data[ "AgentSkills" ];
getAgentToolsObjectProperty[ data_, "MCPServerObjects" ] := toMCPServerObject /@ data[ "MCPServers" ];
getAgentToolsObjectProperty[ data_, "LLMSkills"        ] := toLLMSkill /@ data[ "AgentSkills" ];
getAgentToolsObjectProperty[ data_, "Tools"            ] := getAgentToolsTools @ data;
getAgentToolsObjectProperty[ data_, prop_String        ] := Missing[ "UnknownProperty", prop ];

getAgentToolsObjectProperty // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serverSpecName*)
serverSpecName // beginDefinition;
serverSpecName[ name_String ] := name;
serverSpecName[ obj_MCPServerObject ] := obj[ "Name" ];
serverSpecName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillSpecName*)
(* The name of a skill specification, without loading any definitions. *)
skillSpecName // beginDefinition;
skillSpecName[ name_String ] := Replace[ StringSplit[ name, "/" ], { { ___, last_ } :> last, _ :> name } ];
skillSpecName[ HoldPattern[ LLMSkill ][ as_Association ] ] := Lookup[ as, "Name", Missing[ "NotAvailable" ] ];
skillSpecName[ as_Association ] := Lookup[ as, "Name", Missing[ "NotAvailable" ] ];
skillSpecName[ file_File ] := Replace[ skillDirectoryLLMSkill @ file, { HoldPattern[ LLMSkill ][ as_Association ] :> as[ "Name" ], _ :> FileNameTake @ file } ];
skillSpecName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toMCPServerObject*)
toMCPServerObject // beginDefinition;
toMCPServerObject[ obj_MCPServerObject ] := ensureMCPServerExists @ obj;
toMCPServerObject[ name_String ] := Replace[ MCPServerObject @ name, failure_Failure :> throwTop @ failure ];
toMCPServerObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toLLMSkill*)
(* Resolves a skill specification to an LLMSkill. Only the public LLMSkill constructors are used: LLMSkill[File[dir]]
   for skill directories and LLMSkill[{name, description}, body] otherwise (frontmatter other than the name and the
   description is not represented). *)
toLLMSkill // beginDefinition;

toLLMSkill[ skill: HoldPattern[ LLMSkill ][ _Association ] ] := skill;
toLLMSkill[ file_File ] := checkLLMSkill[ skillDirectoryLLMSkill @ file, file ];
toLLMSkill[ as: KeyValuePattern[ "Type" -> "PacletSkill" ] ] := toLLMSkill[ as, "PacletSkill" ];
toLLMSkill[ as_Association ] := checkLLMSkill[ Quiet @ LLMSkill[ { as[ "Name" ], as[ "Description" ] }, Lookup[ as, "Body", "" ] ], as ];
toLLMSkill[ name_String ] /; pacletQualifiedNameQ @ name := toLLMSkill @ resolvePacletSkill @ name;
toLLMSkill[ name_String ] := throwFailure[ "AgentSkillNotFound", name ];

toLLMSkill[ as_Association, "PacletSkill" ] := Which[
    MatchQ[ as[ "Directory" ], _File ], toLLMSkill @ as[ "Directory" ],
    True, toLLMSkill @ as[ "Definition" ]
];

toLLMSkill // endDefinition;


(* LLMSkill[File[dir]] fails for frontmatter containing characters in U+0080-U+00FF; in that case the skill is built
   from the data read by parseSkillMarkdown with the public two-argument constructor. *)
skillDirectoryLLMSkill // beginDefinition;

skillDirectoryLLMSkill[ file: File[ path_String ] ] :=
    Replace[
        Quiet @ LLMSkill @ file,
        Except[ HoldPattern[ LLMSkill ][ _Association ] ] :> Replace[
            parseSkillMarkdown @ If[ FileNameTake @ path === "SKILL.md", DirectoryName @ path, path ],
            data_Association :> Quiet @ LLMSkill[ { data[ "Name" ], data[ "Description" ] }, data[ "Body" ] ]
        ]
    ];

skillDirectoryLLMSkill // endDefinition;


checkLLMSkill // beginDefinition;
checkLLMSkill[ skill: HoldPattern[ LLMSkill ][ _Association ], _ ] := skill;
checkLLMSkill[ _, spec_ ] := throwFailure[ "InvalidAgentSkill", spec ];
checkLLMSkill // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAgentToolsTools*)
getAgentToolsTools // beginDefinition;

getAgentToolsTools[ data_Association ] :=
    DeleteDuplicatesBy[
        Flatten[ #[ "Tools" ] & /@ (toMCPServerObject /@ data[ "MCPServers" ]) ],
        Replace[ tool_LLMTool :> tool[ "Name" ] ]
    ];

getAgentToolsTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Formatting*)
AgentToolsObject /: MakeBoxes[ obj_AgentToolsObject? sp`HoldValidQ, fmt_ ] :=
    With[ { boxes = Quiet @ catchAlways @ makeAgentToolsObjectBoxes[ obj, fmt ] },
        boxes /; MatchQ[ boxes, _InterpretationBox ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Handling*)
AgentToolsObject[ args___ ]? sp`HoldNotValidQ := catchTop[
    throwFailure[ "InvalidArguments", AgentToolsObject, HoldForm @ AgentToolsObject @ args ],
    AgentToolsObject
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*agentToolsObjectQ*)
agentToolsObjectQ // beginDefinition;
agentToolsObjectQ[ obj_AgentToolsObject ] := sp`HoldValidQ @ obj;
agentToolsObjectQ[ _ ] := False;
agentToolsObjectQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*toAgentToolsObject*)
(* Converts the values accepted as the toolset argument of DeployAgentTools into an AgentToolsObject, without
   installing anything. An MCPServerObject becomes an implicit single-server bundle with the server's name. Names are
   resolved with AgentToolsObject[name]; DeployAgentTools has its own, installing, name resolution. *)
toAgentToolsObject // beginDefinition;

toAgentToolsObject[ obj_AgentToolsObject? agentToolsObjectQ ] := obj;
toAgentToolsObject[ data_Association ] := Replace[ AgentToolsObject @ data, failure_Failure :> throwTop @ failure ];
toAgentToolsObject[ name_String ] := Replace[ AgentToolsObject @ name, failure_Failure :> throwTop @ failure ];

toAgentToolsObject[ server_MCPServerObject ] := Enclose[
    Module[ { obj, name },
        obj  = ensureMCPServerExists @ server;
        name = ConfirmBy[ obj[ "Name" ], StringQ, "Name" ];
        ConfirmBy[
            AgentToolsObject @ <|
                "Name"        -> name,
                "Location"    -> Replace[ obj[ "Location" ], Except[ $$location ] -> None ],
                "MCPServers"  -> { obj },
                "AgentSkills" -> { },
                "ToolsetType" -> "MCPServerObject"
            |>,
            agentToolsObjectQ,
            "AgentToolsObject"
        ]
    ],
    throwInternalFailure
];

toAgentToolsObject[ other_ ] := throwFailure[ "InvalidAgentToolsObject", other ];

toAgentToolsObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AgentToolsObjects*)
AgentToolsObjects // beginDefinition;

AgentToolsObjects // Options = {
    "IncludeBuiltIn"       -> False,
    "IncludeRemotePaclets" -> False,
    UpdatePacletSites      -> Automatic
};

AgentToolsObjects[ pattern: (All | _String? StringQ) : All, opts: OptionsPattern[ ] ] :=
    catchMine @ agentToolsObjects[
        pattern,
        TrueQ @ OptionValue[ "IncludeBuiltIn" ],
        TrueQ @ OptionValue[ "IncludeRemotePaclets" ],
        OptionValue[ UpdatePacletSites ]
    ];

AgentToolsObjects // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*agentToolsObjects*)
agentToolsObjects // beginDefinition;

agentToolsObjects[ pattern_, includeBuiltIn_, includeRemote_, updateSites_ ] := Enclose[
    Module[ { installedPaclets, installedNames, installed, builtIn, remote, all },

        installedPaclets = Replace[ Quiet @ findAgentToolsPaclets[ ], Except[ { ___PacletObject } ] -> { } ];
        installed = Flatten[ pacletBundles /@ installedPaclets ];

        builtIn = If[ includeBuiltIn, Values @ $defaultAgentTools, { } ];

        remote = If[ includeRemote,
            installedNames = #[ "Name" ] & /@ installedPaclets;
            Flatten[
                pacletBundles /@ Select[
                    Replace[ Quiet @ findRemoteAgentToolsPaclets @ updateSites, Except[ { ___PacletObject } ] -> { } ],
                    ! MemberQ[ installedNames, #[ "Name" ] ] &
                ]
            ],
            { }
        ];

        all = Select[
            Quiet[ AgentToolsObject /@ DeleteDuplicatesBy[ Join[ installed, builtIn, remote ], #[ "Name" ] & ] ],
            agentToolsObjectQ
        ];

        If[ pattern === All, all, Select[ all, StringMatchQ[ #[ "Name" ], pattern ] & ] ]
    ],
    throwInternalFailure
];

agentToolsObjects // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $DefaultAgentTools
];

End[ ];
EndPackage[ ];
