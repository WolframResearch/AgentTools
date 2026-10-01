(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`DeployAgentTools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

$ContextAliases[ "sp`" ] = "System`Private`";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$deploymentRecordVersion = 2;
$deploymentLockHeld      = False;
$deploymentLockTimeout   = 60;
$deploymentLockLifetime  = 1800;
$undoStack               = None;

(* Failure tags that DeployAgentTools[All, ...] reports as Missing[...] entries instead of propagating: *)
$unsupportedTags = {
    "UnknownInstallLocation",
    "UnsupportedMCPClient",
    "UnsupportedMCPClientProject",
    "UnsupportedSkillsClient",
    "UnsupportedSkillsClientProject",
    "UnknownSkillsLocation",
    "NoSkillsLocation"
};

$skillConflictTags = { "AgentSkillConflict", "AgentSkillModified", "AgentSkillExists", "AgentSkillUpdate" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$deploymentMCP = KeyValuePattern @ {
    "ClientName" -> _String? StringQ | None,
    "Target"     -> _,
    "Server"     -> _String? StringQ,
    "ConfigFile" -> _File? fileQ,
    "Options"    -> _Association? AssociationQ
};

(* Records written before agent skills were supported (schema version 1): *)
$$deploymentDataV1 = KeyValuePattern @ {
    "UUID"          -> _String? StringQ,
    "Version"       -> _Integer? IntegerQ,
    "Timestamp"     -> _DateObject,
    "PacletVersion" -> _String? StringQ,
    "CreatedBy"     -> _String? StringQ,
    "MCP"           -> $$deploymentMCP,
    "Skills"        -> _Association? AssociationQ,
    "Hooks"         -> _Association? AssociationQ,
    "Meta"          -> _Association? AssociationQ
};

$$deployedServer = KeyValuePattern @ {
    "Name"       -> _String? StringQ,
    "ConfigKey"  -> _String? StringQ,
    "ConfigFile" -> _File? fileQ
};

(* Schema version 2 is a superset of version 1 when MCP servers were deployed ("MCP" and "Toolset" describe the
   primary server), so that older AgentTools versions can still list and remove such deployments: *)
$$deploymentDataV2 = KeyValuePattern @ {
    "UUID"          -> _String? StringQ,
    "Version"       -> _Integer? (# >= 2 &),
    "Timestamp"     -> _DateObject,
    "PacletVersion" -> _String? StringQ,
    "CreatedBy"     -> _String? StringQ,
    "AgentTools"    -> KeyValuePattern @ { "Type" -> "AgentToolsObject" | "MCPServerObject", "Name" -> _String? StringQ },
    "ClientName"    -> _String? StringQ,
    "Target"        -> _,
    "LocationKey"   -> _String? StringQ,
    "MCPServers"    -> { $$deployedServer... },
    "Skills"        -> _Association? AssociationQ,
    "Hooks"         -> _Association? AssociationQ,
    "Meta"          -> _Association? AssociationQ
};

$$deploymentData = $$deploymentDataV2 | $$deploymentDataV1;

$deploymentProperties = {
    "AgentSkills",
    "AgentToolsObject",
    "ClientName",
    "ConfigFile",
    "CreatedBy",
    "Data",
    "Hooks",
    "LLMConfiguration",
    "Location",
    "MCP",
    "MCPServerNames",
    "MCPServerObject",
    "MCPServerObjects",
    "Meta",
    "PacletVersion",
    "Properties",
    "Scope",
    "Server",
    "Skills",
    "SkillsDirectory",
    "Target",
    "Timestamp",
    "Toolset",
    "ToolsetType",
    "Tools",
    "UUID"
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AgentToolsDeployment*)
AgentToolsDeployment // Unprotect;
AgentToolsDeployment // ClearAll;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Main Definition*)
AgentToolsDeployment[ data_Association ]? sp`HoldNotValidQ :=
    catchTop[ createAgentToolsDeployment @ data, AgentToolsDeployment ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*UUID Lookup*)
AgentToolsDeployment[ uuid_String ] :=
    catchTop[ getAgentToolsDeploymentByUUID @ uuid, AgentToolsDeployment ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createAgentToolsDeployment*)
createAgentToolsDeployment // beginDefinition;

createAgentToolsDeployment[ data_Association ] :=
    If[ MatchQ[ data, $$deploymentData ],
        sp`HoldSetValid @ AgentToolsDeployment @ data,
        throwFailure[ "InvalidDeploymentData", data ]
    ];

createAgentToolsDeployment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Properties*)
(AgentToolsDeployment[ data_Association ]? sp`HoldValidQ)[ prop_String ] :=
    catchTop[ getDeploymentProperty[ data, prop ], AgentToolsDeployment ];

(AgentToolsDeployment[ data_Association ]? sp`HoldValidQ)[ prop1_String, prop2_String ] :=
    catchTop[ getDeploymentProperty[ data, prop1, prop2 ], AgentToolsDeployment ];

_AgentToolsDeployment[ invalid_ ] :=
    catchTop[ throwFailure[ "InvalidProperty", invalid ], AgentToolsDeployment ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getDeploymentProperty*)
getDeploymentProperty // beginDefinition;

(* Top-level keys *)
getDeploymentProperty[ data_Association, "UUID"          ] := data[ "UUID" ];
getDeploymentProperty[ data_Association, "Timestamp"     ] := data[ "Timestamp" ];
getDeploymentProperty[ data_Association, "PacletVersion" ] := data[ "PacletVersion" ];
getDeploymentProperty[ data_Association, "CreatedBy"     ] := data[ "CreatedBy" ];
getDeploymentProperty[ data_Association, "MCP"           ] := data[ "MCP" ];
getDeploymentProperty[ data_Association, "Skills"        ] := data[ "Skills" ];
getDeploymentProperty[ data_Association, "Hooks"         ] := data[ "Hooks" ];
getDeploymentProperty[ data_Association, "Meta"          ] := data[ "Meta" ];

(* Primary MCP server (the v1 "MCP" component) *)
getDeploymentProperty[ data_Association, "Server"     ] := data[ "MCP", "Server" ];
getDeploymentProperty[ data_Association, "ConfigFile" ] := Lookup[ Lookup[ data, "MCP", <| |> ], "ConfigFile", Missing[ "NotAvailable" ] ];

(* Normalized properties (valid for both schema versions) *)
getDeploymentProperty[ data_Association, "ClientName"  ] := normalizeDeploymentData[ data ][ "ClientName" ];
getDeploymentProperty[ data_Association, "Target"      ] := normalizeDeploymentData[ data ][ "Target" ];
getDeploymentProperty[ data_Association, "Scope"       ] := normalizeDeploymentData[ data ][ "Scope" ];
getDeploymentProperty[ data_Association, "Toolset"     ] := normalizeDeploymentData[ data ][ "AgentTools", "Name" ];
getDeploymentProperty[ data_Association, "ToolsetType" ] := normalizeDeploymentData[ data ][ "AgentTools", "Type" ];

getDeploymentProperty[ data_Association, "MCPServerNames" ] :=
    #[ "Name" ] & /@ normalizeDeploymentData[ data ][ "MCPServers" ];

getDeploymentProperty[ data_Association, "AgentSkills" ] :=
    #[ "Name" ] & /@ Lookup[ data[ "Skills" ], "Installed", { } ];

getDeploymentProperty[ data_Association, "SkillsDirectory" ] :=
    Replace[ Lookup[ data[ "Skills" ], "Directory", None ], None -> Missing[ "NotAvailable" ] ];

(* Derived properties *)
getDeploymentProperty[ data_Association, "Data"             ] := data;
getDeploymentProperty[ data_Association, "Location"         ] := deploymentDirectory @ normalizeDeploymentData @ data;
getDeploymentProperty[ data_Association, "Properties"       ] := $deploymentProperties;
getDeploymentProperty[ data_Association, "MCPServerObjects" ] := toMCPServerObject /@ getDeploymentProperty[ data, "MCPServerNames" ];
getDeploymentProperty[ data_Association, "MCPServerObject"  ] := primaryMCPServerObject @ data;
getDeploymentProperty[ data_Association, "LLMConfiguration" ] := primaryMCPServerObject[ data ][ "LLMConfiguration" ];
getDeploymentProperty[ data_Association, "Tools"            ] := deploymentTools @ data;
getDeploymentProperty[ data_Association, "AgentToolsObject" ] := deploymentAgentToolsObject @ normalizeDeploymentData @ data;

(* Sub-association access *)
getDeploymentProperty[ data_Association, key_String, subKey_String ] := data[ key, subKey ];

(* Unknown property *)
getDeploymentProperty[ _, prop_ ] := Missing[ "UnknownProperty", prop ];

getDeploymentProperty // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*primaryMCPServerObject*)
primaryMCPServerObject // beginDefinition;

primaryMCPServerObject[ data_Association ] :=
    Replace[
        getDeploymentProperty[ data, "MCPServerNames" ],
        { { name_String, ___ } :> toMCPServerObject @ name, _ :> Missing[ "NotAvailable" ] }
    ];

primaryMCPServerObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toMCPServerObject*)
toMCPServerObject // beginDefinition;
toMCPServerObject[ name_String ] := MCPServerObject @ name;
toMCPServerObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deploymentTools*)
deploymentTools // beginDefinition;

deploymentTools[ data_Association ] :=
    Replace[
        getDeploymentProperty[ data, "MCPServerNames" ],
        {
            { name_String } :> toMCPServerObject[ name ][ "Tools" ],
            names_List :> DeleteDuplicatesBy[
                Flatten[ toMCPServerObject[ # ][ "Tools" ] & /@ names ],
                Replace[ tool_LLMTool :> tool[ "Name" ] ]
            ]
        }
    ];

deploymentTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deploymentAgentToolsObject*)
(* Ad hoc bundles are not persisted, so they cannot be resolved by name again. *)
deploymentAgentToolsObject // beginDefinition;

deploymentAgentToolsObject[ data_Association ] :=
    deploymentAgentToolsObject[ data[ "AgentTools" ], data ];

deploymentAgentToolsObject[ KeyValuePattern @ { "Type" -> "MCPServerObject", "Name" -> name_String }, _ ] :=
    toAgentToolsObject @ MCPServerObject @ name;

deploymentAgentToolsObject[ KeyValuePattern @ { "Location" -> None }, _ ] :=
    Missing[ "NotAvailable" ];

deploymentAgentToolsObject[ KeyValuePattern @ { "Name" -> name_String }, _ ] :=
    AgentToolsObject @ name;

deploymentAgentToolsObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getDeploymentScope*)
getDeploymentScope // beginDefinition;
getDeploymentScope[ target_String ] := "Global";
getDeploymentScope[ { _, dir_File? fileQ } ] := dir;
getDeploymentScope[ { _, dir_String } ] := File @ ExpandFileName @ dir;
getDeploymentScope[ _File? fileQ ] := Missing[ "Unknown" ];
getDeploymentScope // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Normalization*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*normalizeDeploymentData*)
(* Gives the schema version 2 view of a deployment record. Version 1 records are converted in memory only (they are
   never rewritten). Their config key is derived locally (no network access), since version 1 did not record it. *)
normalizeDeploymentData // beginDefinition;

normalizeDeploymentData[ data: KeyValuePattern[ "AgentTools" -> _Association ] ] :=
    <|
        "Scope"  -> Missing[ "Unknown" ],
        data,
        "Skills" -> <| "Directory" -> None, "Installed" -> { }, "Skipped" -> { }, Lookup[ data, "Skills", <| |> ] |>
    |>;

normalizeDeploymentData[ data: KeyValuePattern[ "MCP" -> mcp_Association ] ] := Enclose[
    Module[ { server, toolset, clientName, target, scope, configFile, configKey },
        server     = ConfirmBy[ mcp[ "Server" ], StringQ, "Server" ];
        toolset    = FirstCase[ { data[ "Toolset" ], server }, _String? StringQ ];
        clientName = Replace[ mcp[ "ClientName" ], Except[ _String ] -> "Unknown" ];
        target     = mcp[ "Target" ];
        scope      = getDeploymentScope @ target;
        configFile = ConfirmBy[ mcp[ "ConfigFile" ], fileQ, "ConfigFile" ];
        configKey  = ConfirmBy[ localMCPServerConfigKey[ server, Lookup[ mcp, "Options", <| |> ] ], StringQ, "ConfigKey" ];
        <|
            data,
            "AgentTools"  -> <| "Type" -> "MCPServerObject", "Name" -> toolset, "Location" -> Missing[ "Unknown" ] |>,
            "ClientName"  -> clientName,
            "Target"      -> target,
            "Scope"       -> scope,
            "LocationKey" -> locationKey[ scope, configFile ],
            "MCPServers"  -> { <| "Name" -> server, "ConfigKey" -> configKey, "ConfigFile" -> configFile |> },
            "Skills"      -> <| "Directory" -> None, "Installed" -> { }, "Skipped" -> { } |>
        |>
    ],
    throwInternalFailure
];

normalizeDeploymentData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Validation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*agentToolsDeploymentQ*)
agentToolsDeploymentQ // beginDefinition;
agentToolsDeploymentQ[ dep_AgentToolsDeployment ] := sp`HoldValidQ @ dep;
agentToolsDeploymentQ[ _ ] := False;
agentToolsDeploymentQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UpValues*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*DeleteObject*)
(* The registry is swept before (entries left by older versions or interrupted operations) and after (entries that
   this removal left without references, e.g. a directory that only an external alias still used) *)
AgentToolsDeployment /: DeleteObject[ dep_AgentToolsDeployment ] := catchTop[
    withDeploymentLock[
        sweepSkillRegistry[ ];
        removeDeployment[ ensureDeploymentExists @ dep, <| |> ];
        sweepSkillRegistry[ ];
        Null
    ],
    AgentToolsDeployment
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ensureDeploymentExists*)
ensureDeploymentExists // beginDefinition;

ensureDeploymentExists[ dep_AgentToolsDeployment? agentToolsDeploymentQ ] :=
    If[ FileExistsQ @ deploymentRecordFile @ dep[ "Location" ],
        dep,
        throwFailure[ "DeploymentNotFound", dep[ "UUID" ] ]
    ];

ensureDeploymentExists // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Formatting*)
AgentToolsDeployment /: MakeBoxes[ dep_AgentToolsDeployment? sp`HoldValidQ, fmt_ ] :=
    With[ { boxes = Quiet @ catchAlways @ makeDeploymentBoxes[ dep, fmt ] },
        boxes /; MatchQ[ boxes, _InterpretationBox ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Handling*)
AgentToolsDeployment[ args___ ]? sp`HoldNotValidQ := catchTop[
    throwFailure[
        "InvalidDeploymentData",
        HoldForm @ AgentToolsDeployment @ args
    ],
    AgentToolsDeployment
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DeployAgentTools*)
DeployAgentTools // beginDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Options*)
(* OverwriteTarget:
   - False (default): fail if the deployment conflicts with an existing one
   - True: replace conflicting deployments and update unmodified skills from the same source
   - All: additionally overwrite skill directories that were modified or belong to a different source

   "SkillsDirectory":
   - Automatic (default): the skills directory is derived from the target
   - File[dir]: install agent skills into dir (e.g. for clients configured to use a custom home directory)
   - None: do not install agent skills *)
DeployAgentTools // Options = {
    OverwriteTarget   -> False,
    "SkillsDirectory" -> Automatic
    (* DeployAgentTools can also accept any InstallMCPServer options *)
};

$$deployAgentToolsOptions = OptionsPattern @ { DeployAgentTools, InstallMCPServer };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Main Definition*)
(* Default toolset is `Automatic` *)
DeployAgentTools[ target_, opts: $$deployAgentToolsOptions ] :=
    catchMine @ DeployAgentTools[ target, Automatic, opts ];

(* Deploy for all clients *)
DeployAgentTools[ All, tools_, opts: $$deployAgentToolsOptions ] :=
    catchMine @ deployAllAgentTools[ tools, opts ];

(* Resolve automatic toolset *)
DeployAgentTools[ target_, Automatic, opts: $$deployAgentToolsOptions ] :=
    catchMine @ DeployAgentTools[
        target,
        defaultToolsetForTarget[
            target,
            OptionValue[
                InstallMCPServer,
                FilterRules[ { opts }, Options @ InstallMCPServer ],
                "ApplicationName"
            ]
        ],
        opts
    ];

(* Proceed with deployment *)
DeployAgentTools[ target_, tools_, opts: $$deployAgentToolsOptions ] :=
    catchMine @ deployAgentTools[ target, resolveDeployToolset @ tools, opts ];

DeployAgentTools // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Resolving the Toolset*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveDeployToolset*)
(* Resolves the toolset argument of DeployAgentTools to an AgentToolsObject. Unlike AgentToolsObject[name], this is an
   execution-level operation: paclets that the toolset needs are installed (like InstallMCPServer does). *)
resolveDeployToolset // beginDefinition;
resolveDeployToolset[ obj_AgentToolsObject ] := ensureToolsetPaclets @ toAgentToolsObject @ obj;
resolveDeployToolset[ data_Association ] := ensureToolsetPaclets @ toAgentToolsObject @ data;
resolveDeployToolset[ obj_MCPServerObject ] := ensureToolsetPaclets @ toAgentToolsObject @ obj;
resolveDeployToolset[ name_String ] := resolveDeployToolsetName @ name;
resolveDeployToolset[ other_ ] := throwFailure[ "InvalidAgentToolsObject", other ];
resolveDeployToolset // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveDeployToolsetName*)
(* Precedence: a user-created MCP server (as MCPServerObject[name] does), a built-in bundle, then paclet bundles and
   servers (installing the paclet if necessary; a name without "/" only refers to a paclet if it is the exact name of
   an installed one), and finally any other MCP server name. *)
resolveDeployToolsetName // beginDefinition;

resolveDeployToolsetName[ name_String ] := Which[
    userMCPServerQ @ name,                   toAgentToolsObject @ MCPServerObject @ name,
    KeyExistsQ[ $defaultAgentTools, name ],  AgentToolsObject @ name,
    StringContainsQ[ name, "/" ],            resolvePacletToolsetName @ name,
    pacletInstalledQ @ name,                 resolvePacletToolsetName @ name,
    True,                                    toAgentToolsObject @ MCPServerObject @ name
];

resolveDeployToolsetName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*userMCPServerQ*)
userMCPServerQ // beginDefinition;
userMCPServerQ[ name_String ] := TrueQ @ Quiet @ FileExistsQ @ mcpServerFile @ name;
userMCPServerQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolvePacletToolsetName*)
resolvePacletToolsetName // beginDefinition;

resolvePacletToolsetName[ name_String ] := Enclose[
    Catch @ Module[ { bundle },

        (* A paclet with exactly this name (installed, or remote for a two-segment name): its only bundle. Failures
           (several bundles, or none) are reported, and the name is never reinterpreted as "PacletName/ItemName". *)
        If[ exactPacletNameQ @ name,
            Throw @ ensureToolsetPaclets @ ConfirmBy[ AgentToolsObject @ name, agentToolsObjectQ, "ExactPaclet" ]
        ];

        (* A bundle (of an installed paclet, or from remote metadata) *)
        bundle = Quiet @ catchAlways @ AgentToolsObject @ name;
        If[ agentToolsObjectQ @ bundle, Throw @ ensureToolsetPaclets @ bundle ];

        (* Otherwise install the paclet named by the qualified interpretation of the name and try again (never for
           names with "*", which PacletInstall would treat as a wildcard) *)
        If[ pacletQualifiedNameQ @ name && StringFreeQ[ name, "*" ],
            ensurePacletForInstall @ name;
            bundle = Quiet @ catchAlways @ AgentToolsObject @ name;
            If[ agentToolsObjectQ @ bundle, Throw @ ensureToolsetPaclets @ bundle ]
        ];

        (* A paclet MCP server (MCPServerNotFound for anything else) *)
        toAgentToolsObject @ MCPServerObject @ name
    ],
    throwInternalFailure
];

resolvePacletToolsetName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ensureToolsetPaclets*)
(* Installs the paclet of a paclet bundle (if it only came from remote metadata) and the paclets of all paclet-qualified
   servers and skills that it names. *)
ensureToolsetPaclets // beginDefinition;

ensureToolsetPaclets[ bundle0_AgentToolsObject ] := Enclose[
    Module[ { bundle, location, server, qualified },
        bundle   = bundle0;
        location = bundle[ "Location" ];

        (* A toolset that only came from remote metadata: install the paclet if needed, and resolve the toolset again
           from the installed paclet (if an older version is installed, that may fail with AgentToolsNotFound or the
           server's not-found failure). The implicit bundle of an MCPServerObject is named after the server, so it is
           resolved as a server, not as a paclet bundle. *)
        If[ MatchQ[ location, _PacletObject ] && ! TrueQ @ Quiet @ DirectoryQ @ location[ "Location" ],
            ensurePacletForInstall @ bundle[ "Name" ];
            If[ bundle[ "ToolsetType" ] === "MCPServerObject",
                server = ConfirmMatch[ MCPServerObject @ bundle[ "Name" ], _MCPServerObject, "Server" ];
                bundle = ConfirmBy[ toAgentToolsObject @ server, agentToolsObjectQ, "InstalledServer" ],
                bundle = ConfirmBy[ AgentToolsObject @ bundle[ "Name" ], agentToolsObjectQ, "Installed" ]
            ]
        ];

        (* User-created servers may also have names containing "/" *)
        qualified = Join[
            Select[ bundle[ "MCPServers" ], StringQ[ # ] && pacletQualifiedNameQ[ # ] && ! userMCPServerQ[ # ] & ],
            Select[ bundle[ "AgentSkills" ], StringQ[ # ] && pacletQualifiedNameQ[ # ] & ]
        ];
        Scan[ ensurePacletForInstall, qualified ];

        bundle
    ],
    throwInternalFailure
];

ensureToolsetPaclets // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*pacletInstalledQ*)
pacletInstalledQ // beginDefinition;
pacletInstalledQ[ name_String ] := MatchQ[ Quiet @ findInstalledPaclet @ name, _PacletObject ];
pacletInstalledQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*exactPacletNameQ*)
(* True if the name is the exact name of an installed paclet, or (for a two-segment name) of a remote paclet with an
   "AgentTools" extension. PacletFind/PacletFindRemote treat "*" as a wildcard, so the helpers filter by exact name. *)
exactPacletNameQ // beginDefinition;

exactPacletNameQ[ name_String ] :=
    Or[
        pacletInstalledQ @ name,
        Length @ StringSplit[ name, "/" ] === 2 && MatchQ[ findRemoteAgentToolsPaclet @ name, _PacletObject ]
    ];

exactPacletNameQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deployAllAgentTools*)
deployAllAgentTools // beginDefinition;

deployAllAgentTools[ tools0_, opts: $$deployAgentToolsOptions ] := Enclose[
    Module[ { clients, tools, results, skipped },
        clients = ConfirmMatch[ Keys @ $SupportedClients, { __String }, "Clients" ];

        (* Resolve an explicit toolset once, so that paclets are installed at most once *)
        tools = If[ tools0 === Automatic,
                    Automatic,
                    ConfirmBy[ resolveDeployToolset @ tools0, agentToolsObjectQ, "Toolset" ]
                ];

        results = ConfirmMatch[
            Map[ deployAgentToolsQuietly[ #, resolveServerForClient[ #, tools ], opts ] &, clients ],
            {
                (
                    _AgentToolsDeployment |
                    Missing[ "DeploymentExists", _ ] |
                    Missing[ "Unsupported", _ ] |
                    Missing[ "AgentSkillConflict", _ ]
                )..
            },
            "Results"
        ];

        If[ MemberQ[ results, Missing[ "DeploymentExists", _ ] ],
            messagePrint[ "DeploymentsExistWarning" ]
        ];

        If[ MemberQ[ results, Missing[ "AgentSkillConflict", _ ] ],
            messagePrint[ "AgentSkillConflictWarning" ]
        ];

        (* Clients whose skills were skipped because they don't support skills (not because of "SkillsDirectory" -> None) *)
        skipped = Cases[ results, dep_AgentToolsDeployment /; dep[ "Skills" ][ "Skipped" ] =!= { } :> dep[ "ClientName" ] ];
        If[ skipped =!= { } && OptionValue[ DeployAgentTools, FilterRules[ { opts }, Options @ DeployAgentTools ], "SkillsDirectory" ] =!= None,
            messagePrint[ "AgentSkillsNotDeployedWarning", StringRiffle[ installDisplayName /@ skipped, ", " ] ]
        ];

        results
    ],
    throwInternalFailure
];

deployAllAgentTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveServerForClient*)
(* When `tools === Automatic`, resolve each client's `DefaultToolset` directly
   from the client name.  Going through the 2-arg `defaultToolsetForTarget`
   inside `DeployAgentTools[target, Automatic, opts]` would let an explicit
   `"ApplicationName" -> name` option override the per-client default, which
   defeats the point of `All`. *)
resolveServerForClient // beginDefinition;
resolveServerForClient[ client_String, Automatic ] := defaultToolsetForTarget @ client;
resolveServerForClient[ _, tools_ ] := tools;
resolveServerForClient // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deployAgentToolsQuietly*)
deployAgentToolsQuietly // beginDefinition;

deployAgentToolsQuietly[ target_, tools_, opts: $$deployAgentToolsOptions ] :=
    Quiet[
        Replace[
            catchAlways @ DeployAgentTools[ target, tools, opts ],
            {
                (* Used to issue a single warning about OverwriteTarget: *)
                Failure[ "DeployAgentTools::DeploymentExists", _ ] :>
                    Missing[ "DeploymentExists", target ],

                (* Some clients aren't supported on all operating systems, and some don't support every component: *)
                Failure[ tag_String /; MemberQ[ $unsupportedTags, failureMessageTag @ tag ], _ ] :>
                    Missing[ "Unsupported", { target, $OperatingSystem } ],

                (* Used to issue a single warning about conflicting skills: *)
                Failure[ tag_String /; MemberQ[ $skillConflictTags, failureMessageTag @ tag ], _ ] :>
                    Missing[ "AgentSkillConflict", target ],

                (* Other failures are propagated to the top level: *)
                other_Failure :> throwTop @ other
            }
        ],
        (* Per-client messages that DeployAgentTools[All, ...] summarizes instead (see $unsupportedTags and
           $skillConflictTags): *)
        {
            DeployAgentTools::DeploymentExists,
            DeployAgentTools::AgentSkillsNotDeployed,
            DeployAgentTools::MCPServersNotDeployed,
            DeployAgentTools::AgentSkillInUse,
            DeployAgentTools::UnknownInstallLocation,
            DeployAgentTools::UnsupportedMCPClient,
            DeployAgentTools::UnsupportedMCPClientProject,
            DeployAgentTools::UnsupportedSkillsClient,
            DeployAgentTools::UnsupportedSkillsClientProject,
            DeployAgentTools::UnknownSkillsLocation,
            DeployAgentTools::NoSkillsLocation,
            DeployAgentTools::AgentSkillConflict,
            DeployAgentTools::AgentSkillModified,
            DeployAgentTools::AgentSkillExists,
            DeployAgentTools::AgentSkillUpdate
        }
    ];

deployAgentToolsQuietly // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*failureMessageTag*)
failureMessageTag // beginDefinition;
failureMessageTag[ tag_String ] := Last @ StringSplit[ tag, "::" ];
failureMessageTag // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deployAgentTools*)
deployAgentTools // beginDefinition;

deployAgentTools[ target_, bundle_AgentToolsObject, opts0: $$deployAgentToolsOptions ] := Enclose[
    Module[ { opts, overwrite, skillsDirectory, installOpts, appName, toolsetType, toolsetName, servers, skillSpecs,
              resolved, deployMCP, deploySkills, displayName, mcp, skills, context },

        (* Options *)
        opts            = FilterRules[ { opts0 }, Options @ DeployAgentTools ];
        overwrite       = overwriteLevel @ OptionValue[ DeployAgentTools, opts, OverwriteTarget ];
        skillsDirectory = validateSkillsDirectoryOption @ OptionValue[ DeployAgentTools, opts, "SkillsDirectory" ];
        installOpts     = FilterRules[ { opts0 }, Options @ InstallMCPServer ];
        appName         = OptionValue[ InstallMCPServer, installOpts, "ApplicationName" ];

        (* Toolset contents *)
        toolsetType = ConfirmMatch[ bundle[ "ToolsetType" ], "AgentToolsObject" | "MCPServerObject", "ToolsetType" ];
        toolsetName = ConfirmBy[ bundle[ "Name" ], StringQ, "ToolsetName" ];
        servers     = ConfirmMatch[ bundle[ "MCPServerObjects" ], { ___MCPServerObject }, "Servers" ];
        skillSpecs  = ConfirmMatch[ bundle[ "AgentSkills" ], _List, "Skills" ];
        If[ servers === { } && skillSpecs === { }, throwFailure[ "AgentToolsEmpty", toolsetName ] ];
        If[ servers === { } && skillsDirectory === None, throwFailure[ "AgentSkillsDisabled", toolsetName ] ];

        (* Target: which components can be deployed *)
        resolved = ConfirmBy[ resolveDeployTarget[ target, appName, skillsDirectory ], AssociationQ, "Target" ];
        deployMCP    = servers =!= { } && MatchQ[ resolved[ "ConfigFile" ], _File ];
        deploySkills = skillSpecs =!= { } && MatchQ[ resolved[ "SkillsDirectory" ], _File ];

        (* Nothing to deploy: report the MCP failure if there are servers, otherwise the skills failure *)
        If[ ! deployMCP && ! deploySkills,
            ReleaseHold @ If[ servers =!= { }, resolved[ "ConfigFileError" ], resolved[ "SkillsDirectoryError" ] ];
            throwFailure[ "AgentToolsNothingToDeploy", toolsetName, resolved[ "Target" ] ]
        ];

        displayName = Replace[ installDisplayName @ resolved[ "ClientName" ], Except[ _String ] -> resolved[ "ClientName" ] ];
        If[ servers =!= { } && ! deployMCP, messagePrint[ "MCPServersNotDeployed", toolsetName, displayName ] ];
        If[ skillSpecs =!= { } && ! deploySkills && skillsDirectory =!= None,
            messagePrint[ "AgentSkillsNotDeployed", toolsetName, displayName ]
        ];

        (* Everything that may be slow happens before taking the lock *)
        mcp    = If[ deployMCP   , prepareMCPServers[ toolsetName, servers, installOpts ], None ];
        skills = If[ deploySkills, prepareAgentSkills[ toolsetType, toolsetName, skillSpecs ], None ];

        context = <|
            "Target"        -> target,
            "Resolved"      -> resolved,
            "ToolsetType"   -> toolsetType,
            "ToolsetName"   -> toolsetName,
            "ToolsetSource" -> toolsetSource @ bundle,
            "Overwrite"     -> overwrite,
            "InstallOptions"-> installOpts,
            "MCP"           -> mcp,
            "Skills"        -> skills,
            "SkippedSkills" -> If[ deploySkills, { }, skillSpecNames @ skillSpecs ]
        |>;

        withDeploymentLock @ deployLocked @ context
    ],
    throwInternalFailure
];

deployAgentTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*overwriteLevel*)
overwriteLevel // beginDefinition;
overwriteLevel[ All  ] := All;
overwriteLevel[ True ] := True;
overwriteLevel[ _    ] := False;
overwriteLevel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validateSkillsDirectoryOption*)
validateSkillsDirectoryOption // beginDefinition;
validateSkillsDirectoryOption[ value: Automatic | None ] := value;
validateSkillsDirectoryOption[ File[ dir_String ] ] := File @ ExpandFileName @ dir;
validateSkillsDirectoryOption[ other_ ] := throwFailure[ "InvalidSkillsDirectoryOption", other ];
validateSkillsDirectoryOption // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolsetSource*)
toolsetSource // beginDefinition;

toolsetSource[ bundle_AgentToolsObject ] :=
    toolsetSource @ bundle[ "Location" ];

toolsetSource[ paclet_PacletObject ] := <|
    "Location"      -> "Paclet",
    "PacletName"    -> paclet[ "Name" ],
    "PacletVersion" -> paclet[ "Version" ]
|>;

toolsetSource[ "BuiltIn" ] := <| "Location" -> "BuiltIn" |>;
toolsetSource[ _File     ] := <| "Location" -> "User" |>;
toolsetSource[ _         ] := <| "Location" -> None |>;

toolsetSource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillSpecNames*)
skillSpecNames // beginDefinition;

skillSpecNames[ specs_List ] := Replace[
    specs,
    {
        name_String :> Replace[ StringSplit[ name, "/" ], { { ___, last_ } :> last, _ :> name } ],
        HoldPattern[ LLMSkill ][ as_Association ] :> Lookup[ as, "Name", Nothing ],
        as_Association :> Lookup[ as, "Name", Nothing ],
        File[ dir_String ] :> FileNameTake @ dir,
        _ :> Nothing
    },
    { 1 }
];

skillSpecNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Preparing Components*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareMCPServers*)
(* Computes each server's config key and InstallMCPServer options, and runs the checks that InstallMCPServer would run
   before writing anything (LLMKit, tool initialization, paclet definitions). *)
prepareMCPServers // beginDefinition;

prepareMCPServers[ toolsetName_String, servers: { __MCPServerObject }, installOpts_List ] := Enclose[
    Module[ { nameOption, keys, duplicates, serverOpts },

        nameOption = OptionValue[ InstallMCPServer, installOpts, "MCPServerName" ];
        If[ StringQ @ nameOption && Length @ servers > 1,
            throwFailure[ "InvalidMCPServerNameOption", toolsetName, Length @ servers ]
        ];

        keys = ConfirmMatch[ mcpServerConfigKey[ #, nameOption ] & /@ servers, { __String }, "ConfigKeys" ];

        duplicates = Select[ GatherBy[ Transpose @ { #[ "Name" ] & /@ servers, keys }, Last ], Length[ # ] > 1 & ];
        If[ duplicates =!= { },
            With[ { dup = First @ duplicates },
                throwFailure[ "DuplicateBundleConfigKey", dup[[ All, 1 ]], toolsetName, dup[[ 1, 2 ]] ]
            ]
        ];

        serverOpts = ConfirmMatch[ serverInstallOptions[ servers, installOpts ], { __List }, "ServerOptions" ];

        MapThread[ preflightMCPServerInstall[ #1, Sequence @@ #2 ] &, { servers, serverOpts } ];

        <| "Servers" -> servers, "ConfigKeys" -> keys, "Options" -> serverOpts |>
    ],
    throwInternalFailure
];

prepareMCPServers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serverInstallOptions*)
(* With several servers, each server only receives the "ToolOptions" entries for its own tools (and the default tools),
   so that InstallMCPServer does not warn about the other servers' tools. *)
serverInstallOptions // beginDefinition;

serverInstallOptions[ { server_MCPServerObject }, installOpts_List ] :=
    { installOpts };

serverInstallOptions[ servers_List, installOpts_List ] :=
    serverInstallOptions[ servers, installOpts, OptionValue[ InstallMCPServer, installOpts, "ToolOptions" ] ];

serverInstallOptions[ servers_List, installOpts_List, toolOptions_ ] /; ! AssociationQ @ toolOptions || toolOptions === <| |> :=
    ConstantArray[ installOpts, Length @ servers ];

serverInstallOptions[ servers_List, installOpts_List, toolOptions_Association ] :=
    Module[ { rest, slices, known },
        rest   = FilterRules[ installOpts, Except[ "ToolOptions" ] ];
        slices = KeyTake[ toolOptions, Union[ serverToolNames @ #, Keys @ $defaultToolOptions ] ] & /@ servers;
        known  = Union @@ (Keys /@ slices);
        Scan[ messagePrint[ "UnrecognizedToolOption", # ] &, Complement[ Keys @ toolOptions, known ] ];
        Append[ rest, "ToolOptions" -> # ] & /@ slices
    ];

serverInstallOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serverToolNames*)
serverToolNames // beginDefinition;

serverToolNames[ server_MCPServerObject ] :=
    Replace[ Quiet @ server[ "ToolNames" ], Except[ { ___String } ] -> { } ];

serverToolNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareAgentSkills*)
(* Resolves (and hashes) every skill source before taking the lock. Skills that come from an in-memory definition get
   an identifier based on the toolset, so that redeploying an edited skill of the same toolset is an update of the
   same source. *)
prepareAgentSkills // beginDefinition;

prepareAgentSkills[ toolsetType_String, toolsetName_String, specs: { __ } ] := Enclose[
    Module[ { sources, names, duplicates },

        sources = ConfirmMatch[
            setDefaultSkillIdentifier[ toolsetType, toolsetName, toAgentSkillSource @ # ] & /@ specs,
            { __Association },
            "Sources"
        ];

        names = #[ "Name" ] & /@ sources;
        duplicates = Select[ Tally @ names, Last[ # ] > 1 & ];
        If[ duplicates =!= { }, throwFailure[ "DuplicateAgentSkillName", duplicates[[ 1, 1 ]] ] ];

        sources
    ],
    throwInternalFailure
];

prepareAgentSkills // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setDefaultSkillIdentifier*)
setDefaultSkillIdentifier // beginDefinition;

setDefaultSkillIdentifier[ type_String, name_String, source: KeyValuePattern[ "Identifier" -> None ] ] :=
    <| source, "Identifier" -> type <> ":" <> name <> "/" <> source[ "Name" ] |>;

setDefaultSkillIdentifier[ _, _, source_Association ] :=
    source;

setDefaultSkillIdentifier // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Deploying (under the lock)*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deployLocked*)
deployLocked // beginDefinition;

deployLocked[ context_Association ] := Enclose[
    Module[ { resolved, overwrite, existing, identity, conflicts, replaced, uuid, plan, success, mcpResult,
              skillResult, record, dep },

        resolved  = context[ "Resolved" ];
        overwrite = context[ "Overwrite" ];

        sweepSkillRegistry[ ];

        (* Conflicting deployments *)
        existing  = ConfirmMatch[ loadAllDeploymentData[ ], { ___Association }, "Existing" ];
        identity  = ConfirmBy[ deploymentIdentity @ context, AssociationQ, "Identity" ];
        conflicts = Select[ existing, deploymentsConflictQ[ #, identity ] & ];
        If[ conflicts =!= { } && overwrite === False, throwFailure[ "DeploymentExists", resolved[ "Target" ] ] ];
        replaced = #[ "UUID" ] & /@ conflicts;

        uuid = ConfirmBy[ CreateUUID[ ], StringQ, "UUID" ];

        (* Skill preflight: conflicts fail the deployment before anything has been changed *)
        plan = If[ ListQ @ context[ "Skills" ],
                   ConfirmBy[
                       planSkillInstall[ context[ "Skills" ], resolved[ "SkillsDirectory" ], uuid, replaced, overwrite ],
                       AssociationQ,
                       "Plan"
                   ],
                   None
               ];
        If[ AssociationQ @ plan, throwSkillConflicts @ plan[ "Conflicts" ] ];

        (* Apply all changes, undoing them if anything fails or the evaluation is aborted *)
        success = False;
        Block[ { $undoStack = { }, $writtenConfigHashes = <| |> },
            WithCleanup[
                mcpResult   = If[ AssociationQ @ context[ "MCP" ], installMCPServers[ context ], { } ];
                skillResult = If[ AssociationQ @ plan, applySkills[ plan, uuid ], $noSkillResult ];
                record      = buildDeploymentRecord[ context, uuid, mcpResult, skillResult ];
                writeDeploymentRecord @ record;
                success     = True
                ,
                If[ ! TrueQ @ success, runUndo @ $undoStack ]
            ]
        ];

        (* Finalizing (deleting backups) only warns, e.g. with AgentSkillBackupNotRemoved *)
        Scan[ Quiet[ catchAlways[ #[ ] ], General::AgentToolsInternal ] &, Lookup[ skillResult, "Finalize", { } ] ];

        (* Remove the deployments that were replaced, keeping what the new deployment now owns *)
        Scan[ removeReplacedDeployment[ #, record ] &, conflicts ];

        issueSkillMessages @ Lookup[ skillResult, "Messages", { } ];

        dep = ConfirmMatch[ AgentToolsDeployment @ record, _AgentToolsDeployment, "Deployment" ];
        ConfirmAssert[ agentToolsDeploymentQ @ dep, "DeploymentValid" ];
        dep
    ],
    throwInternalFailure
];

deployLocked // endDefinition;


$noSkillResult = <| "Installed" -> { }, "Undo" -> { }, "Finalize" -> { }, "Messages" -> { } |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*throwSkillConflicts*)
throwSkillConflicts // beginDefinition;

throwSkillConflicts[ { } ] := Null;

throwSkillConflicts[ conflicts: { __Association } ] := (
    Scan[ issueSkillMessage, Rest @ conflicts ];
    With[ { tag = First[ conflicts ][ "Tag" ], params = First[ conflicts ][ "Parameters" ] },
        throwFailure[ tag, Sequence @@ params ]
    ]
);

throwSkillConflicts // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*issueSkillMessages*)
issueSkillMessages // beginDefinition;
issueSkillMessages[ messages_List ] := Scan[ issueSkillMessage, messages ];
issueSkillMessages // endDefinition;

issueSkillMessage // beginDefinition;
issueSkillMessage[ KeyValuePattern @ { "Tag" -> tag_String, "Parameters" -> params_List } ] := messagePrint[ tag, Sequence @@ params ];
issueSkillMessage[ _ ] := Null;
issueSkillMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applySkills*)
applySkills // beginDefinition;

applySkills[ plan_Association, uuid_String ] := Enclose[
    Module[ { result },
        result = ConfirmBy[ applySkillInstallPlan[ plan, uuid ], AssociationQ, "Apply" ];
        (* Undo actions are run in reverse order of registration *)
        $undoStack = Join[ $undoStack, Lookup[ result, "Undo", { } ] ];
        result
    ],
    throwInternalFailure
];

applySkills // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*runUndo*)
runUndo // beginDefinition;
runUndo[ actions_List ] := Scan[ Quiet @ catchAlways[ #[ ] ] &, Reverse @ actions ];
runUndo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addUndo*)
addUndo // beginDefinition;
addUndo[ action_ ] := ($undoStack = Append[ $undoStack, action ]);
addUndo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Installing MCP Servers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installMCPServers*)
(* Installs each server with InstallMCPServer. Before the first write to a config file, its content is saved so that
   undoing can restore it -- but only if nothing else changed the file in the meantime (clients rewrite their config
   files on their own). The Installations.wxf records that InstallMCPServer updates are saved and restored, too. *)
installMCPServers // beginDefinition;

installMCPServers[ context_Association ] := Enclose[
    Module[ { mcp, target, servers, keys, serverOpts, configFile, results },

        mcp        = context[ "MCP" ];
        target     = context[ "Target" ];
        servers    = mcp[ "Servers" ];
        keys       = mcp[ "ConfigKeys" ];
        serverOpts = mcp[ "Options" ];
        configFile = context[ "Resolved", "ConfigFile" ];

        saveConfigFile[ configFile, keys ];

        results = MapThread[
            installMCPServerWithUndo[ target, #1, #2, #3, configFile ] &,
            { servers, keys, serverOpts }
        ];

        ConfirmMatch[ results, { __Association }, "Results" ]
    ],
    throwInternalFailure
];

installMCPServers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installMCPServerWithUndo*)
installMCPServerWithUndo // beginDefinition;

installMCPServerWithUndo[ target_, server_MCPServerObject, key_String, opts_List, configFile_File ] := Enclose[
    Module[ { name, path, result, location },
        name = ConfirmBy[ server[ "Name" ], StringQ, "Name" ];
        path = ExpandFileName @ configFile;

        Scan[ saveFile, installationRecordFiles[ server, key ] ];

        (* The LLMKit check already ran in preflightMCPServerInstall. Whatever is on disk after the call is our own
           write (the lock is held), even if InstallMCPServer fails after writing the file, so it may be restored. *)
        WithCleanup[
            result = InstallMCPServer[ target, server, "VerifyLLMKit" -> False, Sequence @@ opts ],
            $writtenConfigHashes[ path ] = fileHash @ File @ path
        ];
        If[ ! MatchQ[ result, _Success ], throwTop @ result ];

        location = ConfirmBy[ result[ "Location" ], fileQ, "Location" ];

        <| "Name" -> name, "ConfigKey" -> key, "ConfigFile" -> location |>
    ],
    throwInternalFailure
];

installMCPServerWithUndo // endDefinition;


$writtenConfigHashes = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*saveConfigFile*)
saveConfigFile // beginDefinition;

saveConfigFile[ file_File, keys_List ] := Enclose[
    Module[ { path, bytes },
        path  = ExpandFileName @ file;
        bytes = If[ FileExistsQ @ path, Quiet @ ReadByteArray @ path, None ];
        If[ ! MatchQ[ bytes, None | EndOfFile | _ByteArray? ByteArrayQ ], throwFailure[ "InvalidMCPConfiguration", file ] ];
        $writtenConfigHashes[ path ] = None;
        addUndo @ Function[ restoreConfigFile[ path, bytes, keys ] ]
    ],
    throwInternalFailure
];

saveConfigFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*restoreConfigFile*)
restoreConfigFile // beginDefinition;

restoreConfigFile[ path_String, bytes_, keys_List ] := Which[
    (* Nothing was written *)
    $writtenConfigHashes[ path ] === None,
        Null,
    (* Someone else changed the file since our last write: leave it alone and report what remains *)
    fileHash @ File @ path =!= $writtenConfigHashes[ path ],
        Scan[ messagePrint[ "MCPServerNotRemoved", #, File @ path ] &, keys ],
    bytes === None,
        Quiet @ DeleteFile @ path,
    True,
        writeBytes[ path, bytes ]
];

restoreConfigFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installationRecordFiles*)
(* The Installations.wxf files that InstallMCPServer may change for a server: its own, and for the shared built-in key
   "Wolfram", those of the other built-in servers (see clearStaleBuiltInRecords). *)
installationRecordFiles // beginDefinition;

installationRecordFiles[ server_MCPServerObject, key_String ] :=
    Module[ { names },
        names = If[ key === "Wolfram" && KeyExistsQ[ $DefaultMCPServers, server[ "Name" ] ],
                    Keys @ $DefaultMCPServers,
                    { server[ "Name" ] }
                ];
        ExpandFileName @ fileNameJoin[ mcpServerDirectory @ #, "Installations.wxf" ] & /@ names
    ];

installationRecordFiles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*saveFile*)
saveFile // beginDefinition;

saveFile[ path_String ] :=
    Module[ { bytes },
        bytes = If[ FileExistsQ @ path, Quiet @ ReadByteArray @ path, None ];
        (* A record file that can't be read can't be restored either; it is left as it is *)
        If[ MatchQ[ bytes, None | EndOfFile | _ByteArray? ByteArrayQ ],
            addUndo @ Function[ If[ bytes === None, Quiet @ DeleteFile @ path, writeBytes[ path, bytes ] ] ]
        ]
    ];

saveFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeBytes*)
writeBytes // beginDefinition;

(* ReadByteArray gives EndOfFile for an empty file *)
writeBytes[ path_String, EndOfFile ] :=
    Module[ { stream },
        ensureDirectory @ DirectoryName @ path;
        stream = Quiet @ OpenWrite[ path, BinaryFormat -> True ];
        If[ MatchQ[ stream, _OutputStream ], Close @ stream; path, $Failed ]
    ];

writeBytes[ path_String, bytes_ByteArray ] :=
    Module[ { stream, written },
        ensureDirectory @ DirectoryName @ path;
        stream = Quiet @ OpenWrite[ path, BinaryFormat -> True ];
        If[ ! MatchQ[ stream, _OutputStream ], Return[ $Failed, Module ] ];
        written = WithCleanup[ Length @ bytes === 0 || Quiet @ BinaryWrite[ stream, bytes ] =!= $Failed, Close @ stream ];
        If[ TrueQ @ written && FileByteCount @ path === Length @ bytes, path, $Failed ]
    ];

writeBytes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fileHash*)
fileHash // beginDefinition;
fileHash[ file_ ] := If[ FileExistsQ @ file, FileHash[ file, "SHA256", All, "HexString" ], None ];
fileHash // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Deployment Records*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buildDeploymentRecord*)
buildDeploymentRecord // beginDefinition;

buildDeploymentRecord[ context_Association, uuid_String, servers_List, skillResult_Association ] := Enclose[
    Module[ { resolved, primary, mcp },

        resolved = context[ "Resolved" ];
        primary  = FirstCase[ servers, _Association, None ];

        (* The primary server, in the shape of a version 1 record *)
        mcp = If[ AssociationQ @ primary,
                  <|
                      "ClientName" -> resolved[ "ClientName" ],
                      "Target"     -> resolved[ "Target" ],
                      "Server"     -> primary[ "Name" ],
                      "ConfigFile" -> primary[ "ConfigFile" ],
                      "Options"    -> Association @ context[ "InstallOptions" ]
                  |>,
                  Missing[ ]
              ];

        DeleteMissing @ <|
            "UUID"          -> uuid,
            "Version"       -> $deploymentRecordVersion,
            "Timestamp"     -> Now,
            "PacletVersion" -> $pacletVersion,
            "CreatedBy"     -> "DeployAgentTools",
            "Toolset"       -> If[ AssociationQ @ primary, primary[ "Name" ], Missing[ ] ],
            "AgentTools"    -> <|
                "Type" -> context[ "ToolsetType" ],
                "Name" -> context[ "ToolsetName" ],
                context[ "ToolsetSource" ]
            |>,
            "ClientName"    -> resolved[ "ClientName" ],
            "Target"        -> resolved[ "Target" ],
            "Scope"         -> resolved[ "Scope" ],
            "LocationKey"   -> resolved[ "LocationKey" ],
            "MCP"           -> mcp,
            "MCPServers"    -> servers,
            "Skills"        -> <|
                "Directory" -> If[ ListQ @ context[ "Skills" ], resolved[ "SkillsDirectory" ], None ],
                "Installed" -> ConfirmMatch[ Lookup[ skillResult, "Installed", { } ], { ___Association }, "Installed" ],
                "Skipped"   -> context[ "SkippedSkills" ]
            |>,
            "Hooks"         -> <| |>,
            "Meta"          -> <| |>
        |>
    ],
    throwInternalFailure
];

buildDeploymentRecord // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*writeDeploymentRecord*)
(* The record is written into a staging directory that is then renamed, so that a deployment directory always
   contains a complete record. *)
writeDeploymentRecord // beginDefinition;

writeDeploymentRecord[ record_Association ] := Enclose[
    Module[ { dir, staging },
        dir     = ConfirmBy[ deploymentDirectory @ record, fileQ, "Directory" ];
        staging = ConfirmBy[ fileNameJoin[ DirectoryName @ First @ dir, ".staging-" <> record[ "UUID" ] ], fileQ, "Staging" ];
        ConfirmBy[ ensureDirectory @ staging, directoryQ, "StagingDirectory" ];
        ConfirmBy[ writeWXFFile[ fileNameJoin[ staging, "Deployment.wxf" ], record ], FileExistsQ, "WriteDeployment" ];
        ConfirmBy[ RenameDirectory[ staging, dir ], StringQ, "Rename" ];
        addUndo @ Function[ Quiet @ DeleteDirectory[ dir, DeleteContents -> True ] ];
        dir
    ],
    throwInternalFailure
];

writeDeploymentRecord // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Targets*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveDeployTarget*)
(* Resolves a target to the client, scope, and the locations of each component. A component location is a File, or
   $Failed when the target doesn't support it; the corresponding "...Error" entry holds an expression that issues the
   reason when evaluated (used when nothing at all can be deployed). *)
resolveDeployTarget // beginDefinition;

resolveDeployTarget[ name0_String, _, skillsOption_ ] :=
    With[ { name = toInstallName @ name0 },
        completeTarget @ <|
            "ClientName"           -> name,
            "Target"               -> name,
            "Scope"                -> "Global",
            "ConfigFileError"      -> HoldComplete @ installLocation @ name,
            "SkillsDirectoryError" -> HoldComplete @ skillsLocation @ name,
            "SkillsOption"         -> skillsOption
        |>
    ];

resolveDeployTarget[ { name0_String, dir_ }, _, skillsOption_ ] := (
    If[ ! MatchQ[ dir, _String | _File? fileQ ], throwFailure[ "InvalidProjectDirectory", dir ] ];
    With[ { name = toInstallName @ name0, fullDir = File @ ExpandFileName @ dir },
        completeTarget @ <|
            "ClientName"           -> name,
            "Target"               -> { name, fullDir },
            "Scope"                -> fullDir,
            "ConfigFileError"      -> HoldComplete @ projectInstallLocation[ name, fullDir ],
            "SkillsDirectoryError" -> HoldComplete @ projectSkillsLocation[ name, fullDir ],
            "SkillsOption"         -> skillsOption
        |>
    ]
);

resolveDeployTarget[ file_File? fileQ, appName_, skillsOption_ ] := Enclose[
    Module[ { configFile, clientName, location },
        If[ ! MatchQ[ appName, Automatic | _String ], throwFailure[ "InvalidApplicationName", appName ] ];
        configFile = ConfirmBy[ ensureFilePath @ file, fileQ, "ConfigFile" ];
        clientName = If[ appName === Automatic,
                         Replace[ guessClientName @ configFile, None -> "Unknown" ],
                         toInstallName @ appName
                     ];
        location = ConfirmBy[ fileTargetLocation[ configFile, clientName, appName ], AssociationQ, "Location" ];
        completeTarget @ <|
            "ClientName"           -> Replace[ location[ "ClientName" ], Except[ _String ] -> clientName ],
            "Target"               -> file,
            "Scope"                -> location[ "Scope" ],
            "ConfigFile"           -> configFile,
            "SkillsDirectoryError" -> location[ "SkillsDirectoryError" ],
            "SkillsOption"         -> skillsOption
        |>
    ],
    throwInternalFailure
];

resolveDeployTarget[ target_, _, _ ] :=
    throwFailure[ "InvalidDeployTarget", target ];

resolveDeployTarget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*completeTarget*)
completeTarget // beginDefinition;

completeTarget[ target_Association ] := Enclose[
    Module[ { configFile, skills, configFileError },
        configFile = If[ KeyExistsQ[ target, "ConfigFile" ], target[ "ConfigFile" ], tryLocation @ target[ "ConfigFileError" ] ];
        configFileError = Lookup[ target, "ConfigFileError", HoldComplete @ Null ];
        skills = Replace[
            target[ "SkillsOption" ],
            {
                Automatic :> tryLocation @ target[ "SkillsDirectoryError" ],
                None      :> None,
                dir_File  :> dir
            }
        ];
        <|
            KeyDrop[ target, { "SkillsOption" } ],
            "ConfigFile"      -> configFile,
            "ConfigFileError" -> configFileError,
            "SkillsDirectory" -> skills,
            "LocationKey"     -> locationKey[ target[ "Scope" ], configFile ]
        |>
    ],
    throwInternalFailure
];

completeTarget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tryLocation*)
tryLocation // beginDefinition;
tryLocation[ HoldComplete[ eval_ ] ] := Replace[ Quiet @ catchAlways @ eval, Except[ _File ] -> $Failed ];
tryLocation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fileTargetLocation*)
(* For a File[...] config file target, the scope and skills directory are only known for exact matches: the file is a
   client's global config file, or it is at a client's project path. Format heuristics (as in guessClientName) are
   never used to choose where skills go. *)
fileTargetLocation // beginDefinition;

fileTargetLocation[ configFile_File, clientName_String, appName_ ] := Enclose[
    Catch @ Module[ { candidates, global, split, project },

        candidates = If[ appName === Automatic,
                         DeleteDuplicates @ Prepend[ Keys @ KeySelect[ $supportedClients, mcpClientQ ], clientName ],
                         { clientName }
                     ];
        candidates = Select[ candidates, KeyExistsQ[ $supportedClients, # ] & ];

        (* A client's global config file *)
        global = With[ { key = pathKey @ configFile },
            SelectFirst[
                candidates,
                MatchQ[ Quiet @ catchAlways @ installLocation @ #, file_File /; pathKey @ file === key ] &,
                None
            ]
        ];
        If[ StringQ @ global,
            Throw @ <|
                "ClientName"           -> global,
                "Scope"                -> "Global",
                "SkillsDirectoryError" -> HoldComplete @ skillsLocation @ global
            |>
        ];

        (* A config file at a client's project path *)
        split = ConfirmMatch[ FileNameSplit @ First @ configFile, { __String }, "Split" ];
        project = SelectFirst[
            candidates,
            With[ { path = Lookup[ $supportedClients[ # ], "ProjectPath", None ] },
                MatchQ[ path, { __String } ] &&
                    Length @ split > Length @ path &&
                    foldPathCase /@ Take[ split, -Length @ path ] === foldPathCase /@ path
            ] &,
            None
        ];
        If[ StringQ @ project,
            With[ { dir = File @ FileNameJoin @ Drop[ split, -Length @ $supportedClients[ project, "ProjectPath" ] ] },
                Throw @ <|
                    "ClientName"           -> project,
                    "Scope"                -> dir,
                    "SkillsDirectoryError" -> HoldComplete @ projectSkillsLocation[ project, dir ]
                |>
            ]
        ];

        <|
            "ClientName"           -> None,
            "Scope"                -> Missing[ "Unknown" ],
            "SkillsDirectoryError" -> HoldComplete @ throwFailure[ "NoSkillsLocation", configFile ]
        |>
    ],
    throwInternalFailure
];

fileTargetLocation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mcpClientQ*)
mcpClientQ // beginDefinition;
mcpClientQ[ name_String ] := KeyExistsQ[ $supportedClients[ name ], "InstallLocation" ];
mcpClientQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*locationKey*)
(* Identifies where a deployment lives, for conflict detection: the scope if it is known, otherwise the config file. *)
locationKey // beginDefinition;
locationKey[ "Global", _ ] := "Global";
locationKey[ dir_File, _ ] := pathKey @ dir;
locationKey[ _Missing, file_File ] := pathKey @ file;
locationKey[ _Missing, _ ] := "Unknown";
locationKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*pathKey*)
(* A canonical form of a path for comparisons (see canonicalPathKey): symbolic links resolved, case-folded where file
   systems are usually case-insensitive. *)
pathKey // beginDefinition;

pathKey[ File[ path_String ] ] := pathKey @ path;

pathKey[ path_String ] :=
    Replace[ Quiet @ canonicalPathKey @ path, Except[ _String ] :> ExpandFileName @ path ];

pathKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Conflicts*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deploymentIdentity*)
deploymentIdentity // beginDefinition;

deploymentIdentity[ context_Association ] :=
    Module[ { resolved, mcp },
        resolved = context[ "Resolved" ];
        mcp      = context[ "MCP" ];
        <|
            "ConfigKeys"  -> If[ AssociationQ @ mcp,
                                 { pathKey @ resolved[ "ConfigFile" ], # } & /@ mcp[ "ConfigKeys" ],
                                 { }
                             ],
            "Toolset"     -> toolsetIdentity @ { context[ "ToolsetType" ], context[ "ToolsetName" ] },
            "ClientName"  -> resolved[ "ClientName" ],
            "LocationKey" -> resolved[ "LocationKey" ]
        |>
    ];

deploymentIdentity // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deploymentsConflictQ*)
(* Two deployments conflict if they write the same config key into the same config file, or if they deploy the same
   toolset to the same client and location. *)
deploymentsConflictQ // beginDefinition;

deploymentsConflictQ[ existing_Association, identity_Association ] :=
    Module[ { keys },
        keys = { pathKey @ #[ "ConfigFile" ], #[ "ConfigKey" ] } & /@ existing[ "MCPServers" ];
        Or[
            IntersectingQ[ keys, identity[ "ConfigKeys" ] ],
            And[
                toolsetIdentity @ { existing[ "AgentTools", "Type" ], existing[ "AgentTools", "Name" ] } === identity[ "Toolset" ],
                existing[ "ClientName" ] === identity[ "ClientName" ],
                existing[ "LocationKey" ] === identity[ "LocationKey" ]
            ]
        ]
    ];

deploymentsConflictQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolsetIdentity*)
(* A built-in bundle contains exactly the built-in server of the same name, so deploying either one (or a version 1
   record of the server) is the same toolset. *)
toolsetIdentity // beginDefinition;
toolsetIdentity[ { "MCPServerObject", name_String } ] /; KeyExistsQ[ $defaultAgentTools, name ] := { "AgentToolsObject", name };
toolsetIdentity[ other_ ] := other;
toolsetIdentity // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Removing Deployments*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeReplacedDeployment*)
(* Removes a deployment that a new deployment replaces, keeping the config entries and skills that the new deployment
   now owns. Failures are reported as warnings: the new deployment stays. *)
removeReplacedDeployment // beginDefinition;

removeReplacedDeployment[ old_Association, new_Association ] :=
    Module[ { newServers, exclude, result },
        newServers = new[ "MCPServers" ];
        exclude = <|
            "ConfigKeys"   -> ({ pathKey @ #[ "ConfigFile" ], #[ "ConfigKey" ] } & /@ newServers),
            "ServerFiles"  -> ({ #[ "Name" ], pathKey @ #[ "ConfigFile" ] } & /@ newServers),
            "RegistryKeys" -> (#[ "RegistryKey" ] & /@ Lookup[ new[ "Skills" ], "Installed", { } ])
        |>;
        result = catchAlways @ removeDeployment[ old, exclude ];
        If[ FailureQ @ result, messagePrint[ "DeploymentNotRemoved", old[ "UUID" ] ] ];
        result
    ];

removeReplacedDeployment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeDeployment*)
(* Removes a deployment using only its recorded data: config entries are removed by their recorded keys (no server is
   resolved, no network access), skill references are released, and the deployment directory is deleted. *)
removeDeployment // beginDefinition;

removeDeployment[ dep_AgentToolsDeployment, exclude_Association ] :=
    removeDeployment[ dep[ "Data" ], exclude ];

removeDeployment[ data_Association, exclude_Association ] := Enclose[
    Module[ { norm, uuid, clientName, formatClient, others, excludedKeys, excludedRecords, excludedSkills, releases, dir },

        norm            = ConfirmBy[ normalizeDeploymentData @ data, AssociationQ, "Normalize" ];
        uuid            = ConfirmBy[ norm[ "UUID" ], StringQ, "UUID" ];
        clientName      = norm[ "ClientName" ];
        formatClient    = If[ KeyExistsQ[ $supportedClients, clientName ], clientName, None ];
        others          = Select[ loadAllDeploymentData[ ], #[ "UUID" ] =!= uuid & ];

        (* Config entries and installation records that another deployment still records are never removed, e.g.
           when a replaced deployment couldn't be removed completely and is removed again later *)
        excludedKeys    = Join[ Lookup[ exclude, "ConfigKeys" , { } ], Flatten[ ownedConfigKeys /@ others, 1 ] ];
        excludedRecords = Join[ Lookup[ exclude, "ServerFiles", { } ], Flatten[ ownedServerFiles /@ others, 1 ] ];
        excludedSkills  = Lookup[ exclude, "RegistryKeys", { } ];

        (* MCP config entries *)
        Scan[
            Function[ server,
                If[ ! MemberQ[ excludedKeys, { pathKey @ server[ "ConfigFile" ], server[ "ConfigKey" ] } ],
                    removeConfigEntry[ server[ "ConfigFile" ], formatClient, server[ "ConfigKey" ] ]
                ];
                If[ ! MemberQ[ excludedRecords, { server[ "Name" ], pathKey @ server[ "ConfigFile" ] } ],
                    Quiet @ catchAlways @ clearMCPInstallationRecord[ server[ "Name" ], server[ "ConfigFile" ] ]
                ]
            ],
            norm[ "MCPServers" ]
        ];

        (* Agent skills: skills that the replacing deployment also references are not reported as in use *)
        releases = safeReleaseSkillReference[ #, uuid ] & /@ Lookup[ norm[ "Skills" ], "Installed", { } ];
        skillReleaseMessages @ Select[ releases, ! MemberQ[ excludedSkills, Lookup[ #, "RegistryKey", None ] ] & ];

        (* Deployment record *)
        dir = ConfirmBy[ deploymentDirectory @ norm, fileQ, "Directory" ];
        If[ DirectoryQ @ dir,
            ConfirmMatch[ DeleteDirectory[ dir, DeleteContents -> True ], Null, "Delete" ];
            ConfirmAssert[ ! FileExistsQ @ dir, "Verify" ]
        ];

        Null
    ],
    throwInternalFailure
];

removeDeployment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ownedConfigKeys*)
ownedConfigKeys // beginDefinition;
ownedConfigKeys[ data_Association ] := { pathKey @ #[ "ConfigFile" ], #[ "ConfigKey" ] } & /@ Lookup[ data, "MCPServers", { } ];
ownedConfigKeys // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ownedServerFiles*)
ownedServerFiles // beginDefinition;
ownedServerFiles[ data_Association ] := { #[ "Name" ], pathKey @ #[ "ConfigFile" ] } & /@ Lookup[ data, "MCPServers", { } ];
ownedServerFiles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*safeReleaseSkillReference*)
(* A skill that can't be released (e.g. an I/O error) is reported as not removed instead of aborting the removal of
   the deployment halfway. *)
safeReleaseSkillReference // beginDefinition;

safeReleaseSkillReference[ installed_Association, uuid_String ] :=
    Replace[
        Quiet[ catchAlways @ releaseSkillReference[ installed, uuid ], General::AgentToolsInternal ],
        Except[ _Association ] :> <|
            KeyTake[ installed, { "Name", "Directory", "RegistryKey" } ],
            "Root"   -> Replace[ installed[ "Directory" ], File[ dir_String ] :> File @ DirectoryName @ dir ],
            "Result" -> "RemoveFailed"
        |>
    ];

safeReleaseSkillReference // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeConfigEntry*)
removeConfigEntry // beginDefinition;

removeConfigEntry[ file_File, clientName_, key_String ] :=
    Module[ { result },
        result = Quiet @ catchAlways @ removeMCPConfigEntry[ file, clientName, key ];
        If[ FailureQ @ result, messagePrint[ "MCPServerNotRemoved", key, file ] ];
        result
    ];

removeConfigEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DeployedAgentTools*)
DeployedAgentTools // beginDefinition;
DeployedAgentTools[ ] := catchMine @ deployedAgentTools[ ];
DeployedAgentTools[ target_String ] := catchMine @ deployedAgentTools @ toInstallName @ target;
DeployedAgentTools // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deployedAgentTools*)
deployedAgentTools // beginDefinition;

(* No arguments: scan all client subdirectories *)
deployedAgentTools[ ] := Enclose[
    Flatten @ Map[ deploymentsInClientDir, clientDirectories[ ] ],
    throwInternalFailure
];

(* With client name: scan only the matching subdirectory *)
deployedAgentTools[ clientName_String ] := Enclose[
    Catch @ Module[ { clientDir },
        clientDir = FileNameJoin @ { $deploymentsPath, clientName };
        If[ ! DirectoryQ @ clientDir, Throw @ { } ];
        deploymentsInClientDir @ clientDir
    ],
    throwInternalFailure
];

deployedAgentTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*clientDirectories*)
(* Client subdirectories of $deploymentsPath. Dot-prefixed entries (the skill registry, the lock file, staging
   directories) are skipped. *)
clientDirectories // beginDefinition;

clientDirectories[ ] :=
    If[ DirectoryQ @ $deploymentsPath,
        Select[ FileNames[ All, $deploymentsPath ], DirectoryQ[ # ] && ! StringStartsQ[ FileNameTake @ #, "." ] & ],
        { }
    ];

clientDirectories // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deploymentsInClientDir*)
deploymentsInClientDir // beginDefinition;

deploymentsInClientDir[ clientDir_String ] :=
    Module[ { uuidDirs },
        uuidDirs = Select[ FileNames[ All, clientDir ], DirectoryQ[ # ] && ! StringStartsQ[ FileNameTake @ #, "." ] & ];
        DeleteMissing @ Map[ loadDeploymentFromDir, uuidDirs ]
    ];

deploymentsInClientDir // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadAllDeploymentData*)
(* Normalized records of all deployments, for conflict detection. *)
loadAllDeploymentData // beginDefinition;

loadAllDeploymentData[ ] :=
    Select[
        Quiet[ catchAlways @ normalizeDeploymentData @ #[ "Data" ] & /@ deployedAgentTools[ ] ],
        AssociationQ
    ];

loadAllDeploymentData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadDeploymentFromDir*)
loadDeploymentFromDir // beginDefinition;

loadDeploymentFromDir[ dir_String ] :=
    Catch @ Module[ { wxfFile, data, dep },
        wxfFile = FileNameJoin @ { dir, "Deployment.wxf" };
        If[ ! FileExistsQ @ wxfFile, Throw @ Missing[ "NotFound" ] ];
        data = Quiet @ readWXFFile @ wxfFile;
        If[ ! AssociationQ @ data, Throw @ Missing[ "InvalidData" ] ];
        dep = Quiet @ AgentToolsDeployment @ data;
        If[ agentToolsDeploymentQ @ dep, dep, Throw @ Missing[ "InvalidDeployment" ] ]
    ];

loadDeploymentFromDir // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*configFilesEqual*)
configFilesEqual // beginDefinition;
configFilesEqual[ File[ a_String ], File[ b_String ] ] := ExpandFileName @ a === ExpandFileName @ b;
configFilesEqual[ _, _ ] := False;
configFilesEqual // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Deployment Lock*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withDeploymentLock*)
(* Deployments, client config files, skill directories, and the skill registry are only modified while holding a file
   lock, so that kernels deploying at the same time don't lose skill references. WithLock is not re-entrant, so nested
   calls in the same kernel run directly. *)
withDeploymentLock // beginDefinition;
withDeploymentLock // Attributes = { HoldFirst };

withDeploymentLock[ eval_ ] /; TrueQ @ $deploymentLockHeld := eval;

withDeploymentLock[ eval_ ] := Enclose[
    Module[ { lockFile, result },
        lockFile = ConfirmBy[ $deploymentLockFile, StringQ, "LockFile" ];
        ConfirmBy[ ensureDirectory @ DirectoryName @ lockFile, directoryQ, "LockDirectory" ];
        result = Quiet[
            WithLock[
                File @ lockFile,
                Block[ { $deploymentLockHeld = True }, { "Result", eval } ],
                TimeConstraint  -> $deploymentLockTimeout,
                PersistenceTime -> $deploymentLockLifetime
            ],
            WithLock::unlock
        ];
        Replace[ result, { { "Result", r_ } :> r, _ :> throwFailure[ "DeploymentLockTimeout" ] } ]
    ],
    throwInternalFailure
];

withDeploymentLock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Helper Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deploymentDirectory*)
deploymentDirectory // beginDefinition;
deploymentDirectory[ data_Association ] := deploymentDirectory[ data[ "ClientName" ], data[ "UUID" ] ];
deploymentDirectory[ clientName_String, uuid_String ] := fileNameJoin[ $deploymentsPath, clientName, uuid ];
deploymentDirectory[ None, uuid_String ] := deploymentDirectory[ "Unknown", uuid ];
deploymentDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deploymentRecordFile*)
deploymentRecordFile // beginDefinition;
deploymentRecordFile[ dir_File ] := fileNameJoin[ dir, "Deployment.wxf" ];
deploymentRecordFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsDeploymentByUUID*)
getAgentToolsDeploymentByUUID // beginDefinition;

getAgentToolsDeploymentByUUID[ uuid_String ] := Enclose[
    Module[ { dir, dep },
        dir = SelectFirst[ FileNameJoin @ { #, uuid } & /@ clientDirectories[ ], DirectoryQ ];
        If[ MissingQ @ dir, throwFailure[ "DeploymentNotFound", uuid ] ];
        dep = loadDeploymentFromDir @ dir;
        If[ ! agentToolsDeploymentQ @ dep, throwFailure[ "DeploymentNotFound", uuid ] ];
        dep
    ],
    throwInternalFailure
];

getAgentToolsDeploymentByUUID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
