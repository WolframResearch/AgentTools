(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`DeployAgentTools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

$ContextAliases[ "sp`" ] = "System`Private`";

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

$$deploymentData = KeyValuePattern @ {
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

$deploymentProperties = {
    "ClientName",
    "ConfigFile",
    "CreatedBy",
    "Data",
    "Hooks",
    "LLMConfiguration",
    "Location",
    "MCP",
    "MCPServerObject",
    "Meta",
    "PacletVersion",
    "Properties",
    "Scope",
    "Server",
    "Skills",
    "Target",
    "Timestamp",
    "Toolset",
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

(* MCP shortcut properties *)
getDeploymentProperty[ data_Association, "ClientName" ] := data[ "MCP", "ClientName" ];
getDeploymentProperty[ data_Association, "Target"     ] := data[ "MCP", "Target" ];
getDeploymentProperty[ data_Association, "Server"     ] := data[ "MCP", "Server" ];
getDeploymentProperty[ data_Association, "ConfigFile" ] := data[ "MCP", "ConfigFile" ];

(* Toolset: canonical name with fallback through legacy MCP/Server *)
getDeploymentProperty[ data_Association, "Toolset" ] :=
    FirstCase[
        { data[ "Toolset" ], data[ "MCP", "Server" ] },
        _String? StringQ,
        Missing[ "NotAvailable" ]
    ];

(* Derived properties *)
getDeploymentProperty[ data_Association, "Data"             ] := data;
getDeploymentProperty[ data_Association, "LLMConfiguration" ] := getDeploymentProperty[ data, "MCPServerObject" ][ "LLMConfiguration" ];
getDeploymentProperty[ data_Association, "Location"         ] := deploymentDirectory[ data[ "MCP", "ClientName" ], data[ "UUID" ] ];
getDeploymentProperty[ data_Association, "MCPServerObject"  ] := MCPServerObject @ getDeploymentProperty[ data, "Toolset" ];
getDeploymentProperty[ data_Association, "Properties"       ] := $deploymentProperties;
getDeploymentProperty[ data_Association, "Scope"            ] := getDeploymentScope @ data[ "MCP", "Target" ];
getDeploymentProperty[ data_Association, "Tools"            ] := getDeploymentProperty[ data, "MCPServerObject" ][ "Tools" ];

(* Sub-association access *)
getDeploymentProperty[ data_Association, key_String, subKey_String ] := data[ key, subKey ];

(* Unknown property *)
getDeploymentProperty[ _, prop_ ] := Missing[ "UnknownProperty", prop ];

getDeploymentProperty // endDefinition;

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
AgentToolsDeployment /: DeleteObject[ dep_AgentToolsDeployment ] := catchTop[
    deleteDeployment @ ensureDeploymentExists @ dep,
    AgentToolsDeployment
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ensureDeploymentExists*)
ensureDeploymentExists // beginDefinition;

ensureDeploymentExists[ dep_AgentToolsDeployment? agentToolsDeploymentQ ] :=
    Module[ { uuid, dir },
        uuid = dep[ "UUID" ];
        dir = deploymentDirectory[ dep[ "ClientName" ], uuid ];
        If[ DirectoryQ @ dir,
            dep,
            throwFailure[ "DeploymentNotFound", uuid ]
        ]
    ];

ensureDeploymentExists // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deleteDeployment*)
deleteDeployment // beginDefinition;

deleteDeployment[ dep_AgentToolsDeployment ] := Enclose[
    Module[ { options, uuid, dir },

        (* Uninstall MCP server config, tolerating already-removed cases *)
        options = FilterRules[
            Normal @ dep[ "MCP", "Options" ],
            Options @ UninstallMCPServer
        ];
        catchAlways @ UninstallMCPServer[ dep[ "ConfigFile" ], dep[ "Toolset" ], Sequence @@ options ];

        (* Remove deployment directory *)
        uuid = ConfirmBy[ dep[ "UUID" ], StringQ, "UUID" ];
        dir = ConfirmBy[ deploymentDirectory[ dep[ "ClientName" ], uuid ], fileQ, "Directory" ];
        If[ DirectoryQ @ dir,
            ConfirmMatch[ DeleteDirectory[ dir, DeleteContents -> True ], Null, "Delete" ];
            ConfirmAssert[ ! FileExistsQ @ dir, "Verify" ]
        ];

        Null
    ],
    throwInternalFailure
];

deleteDeployment // endDefinition;

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
DeployAgentTools // Options = {
    OverwriteTarget -> False
    (* DeployAgentTools can also accept any InstallMCPServer options *)
};

$$deployAgentToolsOptions = OptionsPattern @ { DeployAgentTools, InstallMCPServer };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Main Definition*)
(* Default server is `Automatic` *)
DeployAgentTools[ target_, opts: $$deployAgentToolsOptions ] :=
    catchMine @ DeployAgentTools[ target, Automatic, opts ];

(* Deploy for all clients *)
DeployAgentTools[ All, server_, opts: $$deployAgentToolsOptions ] :=
    catchMine @ deployAllAgentTools[ server, opts ];

(* Resolve automatic server *)
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
DeployAgentTools[ target_, server_, opts: $$deployAgentToolsOptions ] :=
    catchMine @ deployAgentTools[ target, ensureMCPServerExists @ MCPServerObject @ server, opts ];

DeployAgentTools // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deployAllAgentTools*)
deployAllAgentTools // beginDefinition;

deployAllAgentTools[ server0_, opts: $$deployAgentToolsOptions ] := Enclose[
    Module[ { clients, server, results },
        clients = ConfirmMatch[ Keys @ $SupportedMCPClients, { __String }, "Clients" ];

        server = If[ server0 === Automatic,
                     Automatic,
                     ConfirmBy[ ensureMCPServerExists @ MCPServerObject @ server0, MCPServerObjectQ, "Server" ]
                 ];

        results = ConfirmMatch[
            Map[ deployAgentToolsQuietly[ #, resolveServerForClient[ #, server ], opts ] &, clients ],
            { (_AgentToolsDeployment | Missing[ "DeploymentExists", _ ] | Missing[ "Unsupported", _ ]).. },
            "Results"
        ];

        If[ MemberQ[ results, Missing[ "DeploymentExists", _ ] ],
            messagePrint[ "DeploymentsExistWarning" ]
        ];

        results
    ],
    throwInternalFailure
];

deployAllAgentTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveServerForClient*)
(* When `server === Automatic`, resolve each client's `DefaultToolset` directly
   from the client name.  Going through the 2-arg `defaultToolsetForTarget`
   inside `DeployAgentTools[target, Automatic, opts]` would let an explicit
   `"ApplicationName" -> name` option override the per-client default, which
   defeats the point of `All`. *)
resolveServerForClient // beginDefinition;
resolveServerForClient[ client_String, Automatic ] := defaultToolsetForTarget @ client;
resolveServerForClient[ _, server_ ] := server;
resolveServerForClient // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deployAgentToolsQuietly*)
deployAgentToolsQuietly // beginDefinition;

deployAgentToolsQuietly[ target_, server_, opts: $$deployAgentToolsOptions ] :=
    Quiet[
        Replace[
            catchAlways @ DeployAgentTools[ target, server, opts ],
            {
                (* Used to issue a single warning about OverwriteTarget: *)
                Failure[ "DeployAgentTools::DeploymentExists", _ ] :>
                    Missing[ "DeploymentExists", target ],

                (* Some clients aren't supported on all operating systems: *)
                Failure[ "DeployAgentTools::UnknownInstallLocation", _ ] :>
                    Missing[ "Unsupported", { target, $OperatingSystem } ],

                (* Other failures are propagated to the top level: *)
                other_Failure :> throwTop @ other
            }
        ],
        { DeployAgentTools::DeploymentExists, DeployAgentTools::UnknownInstallLocation }
    ];

deployAgentToolsQuietly // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deployAgentTools*)
deployAgentTools // beginDefinition;

deployAgentTools[ target_, server_MCPServerObject, opts0: $$deployAgentToolsOptions ] := Enclose[
    Module[ { opts, appName, resolved, clientName, configFile, normalizedTarget, overwrite,
              existingDep, installOpts, installResult, uuid, deployData, dir },

        opts = Sequence @@ FilterRules[ { opts0 }, Options @ DeployAgentTools ];

        (* Step 1: Resolve target *)
        appName = OptionValue[ InstallMCPServer, FilterRules[ { opts0 }, Options @ InstallMCPServer ], "ApplicationName" ];
        resolved = ConfirmMatch[ resolveDeployTarget[ target, appName ], { _String, _File, _ }, "ResolveTarget" ];
        { clientName, configFile, normalizedTarget } = resolved;

        (* Step 2: Check for existing deployment *)
        overwrite = TrueQ @ OptionValue[ DeployAgentTools, { opts }, OverwriteTarget ];
        existingDep = findExistingDeployment[ clientName, configFile ];
        If[ existingDep =!= None,
            If[ overwrite,
                deleteDeployment @ existingDep,
                throwFailure[ "DeploymentExists", normalizedTarget ]
            ]
        ];

        (* Step 3: Call InstallMCPServer *)
        installOpts = FilterRules[ { opts0 }, Options @ InstallMCPServer ];
        installResult = ConfirmBy[
            InstallMCPServer[ target, server, Sequence @@ installOpts ],
            MatchQ[ _Success ],
            "Install"
        ];

        (* Step 4: Build deployment record *)
        uuid = ConfirmBy[ CreateUUID[ ], StringQ, "UUID" ];
        deployData = <|
            "UUID"          -> uuid,
            "Version"       -> 1,
            "Timestamp"     -> Now,
            "PacletVersion" -> $pacletVersion,
            "CreatedBy"     -> "DeployAgentTools",
            "Toolset"       -> server[ "Name" ],
            "MCP"           -> <|
                "ClientName" -> clientName,
                "Target"     -> normalizedTarget,
                "Server"     -> server[ "Name" ],
                "ConfigFile" -> installResult[ "Location" ],
                "Options"    -> Association @ installOpts
            |>,
            "Skills"        -> <| |>,
            "Hooks"         -> <| |>,
            "Meta"          -> <| |>
        |>;

        (* Step 5: Write to disk *)
        dir = ConfirmBy[
            ensureDirectory @ fileNameJoin[ $deploymentsPath, clientName, uuid ],
            directoryQ,
            "DeploymentDir"
        ];
        ConfirmBy[
            writeWXFFile[ fileNameJoin[ dir, "Deployment.wxf" ], deployData ],
            FileExistsQ,
            "WriteDeployment"
        ];

        (* Step 6: Return object *)
        AgentToolsDeployment @ deployData
    ],
    throwInternalFailure
];

deployAgentTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveDeployTarget*)
resolveDeployTarget // beginDefinition;

resolveDeployTarget[ name0_String, _ ] :=
    Module[ { name, configFile },
        name = toInstallName @ name0;
        configFile = installLocation @ name;
        { name, configFile, name }
    ];

resolveDeployTarget[ { name0_String, dir_ }, _ ] := Enclose[
    Module[ { name, configFile, fullDir },
        name = toInstallName @ name0;
        configFile = ConfirmBy[ projectInstallLocation[ name, dir ], fileQ, "ConfigFile" ];
        fullDir = ConfirmBy[ File @ ExpandFileName @ dir, fileQ, "Directory" ];
        { name, configFile, { name, fullDir } }
    ],
    throwInternalFailure
];

resolveDeployTarget[ file_File? fileQ, Automatic ] :=
    Module[ { configFile, clientName },
        configFile = ensureFilePath @ file;
        clientName = guessClientName @ configFile;
        { Replace[ clientName, None -> "Unknown" ], configFile, file }
    ];

resolveDeployTarget[ file_File? fileQ, appName_ ] :=
    Module[ { configFile, clientName },
        If[ ! StringQ @ appName, throwFailure[ "InvalidApplicationName", appName ] ];
        configFile = ensureFilePath @ file;
        clientName = toInstallName @ appName;
        { clientName, configFile, file }
    ];

resolveDeployTarget[ target_, _ ] :=
    throwFailure[ "InvalidDeployTarget", target ];

resolveDeployTarget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*findExistingDeployment*)
findExistingDeployment // beginDefinition;

findExistingDeployment[ clientName_String, configFile_File ] :=
    Catch @ Module[ { clientDir, uuidDirs },
        clientDir = FileNameJoin @ { $deploymentsPath, clientName };
        If[ ! DirectoryQ @ clientDir, Throw @ None ];
        uuidDirs = Select[ FileNames[ All, clientDir ], DirectoryQ ];
        SelectFirst[
            DeleteMissing @ Map[ loadDeploymentFromDir, uuidDirs ],
            configFilesEqual[ #[ "ConfigFile" ], configFile ] &,
            None
        ]
    ];

findExistingDeployment // endDefinition;

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
    Catch @ Module[ { clientDirs },
        If[ ! DirectoryQ @ $deploymentsPath, Throw @ { } ];
        clientDirs = Select[ FileNames[ All, $deploymentsPath ], DirectoryQ ];
        Flatten @ Map[ deploymentsInClientDir, clientDirs ]
    ],
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
(*deploymentsInClientDir*)
deploymentsInClientDir // beginDefinition;

deploymentsInClientDir[ clientDir_String ] :=
    Module[ { uuidDirs },
        uuidDirs = Select[ FileNames[ All, clientDir ], DirectoryQ ];
        DeleteMissing @ Map[ loadDeploymentFromDir, uuidDirs ]
    ];

deploymentsInClientDir // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Helper Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deploymentDirectory*)
deploymentDirectory // beginDefinition;
deploymentDirectory[ clientName_String, uuid_String ] := fileNameJoin[ $deploymentsPath, clientName, uuid ];
deploymentDirectory[ None, uuid_String ] := deploymentDirectory[ "Unknown", uuid ];
deploymentDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAgentToolsDeploymentByUUID*)
getAgentToolsDeploymentByUUID // beginDefinition;

getAgentToolsDeploymentByUUID[ uuid_String ] := Enclose[
    Module[ { clientDirs, dir, dep },
        If[ ! DirectoryQ @ $deploymentsPath, throwFailure[ "DeploymentNotFound", uuid ] ];
        clientDirs = Select[ FileNames[ All, $deploymentsPath ], DirectoryQ ];
        dir = SelectFirst[ Map[ FileNameJoin @ { #, uuid } &, clientDirs ], DirectoryQ ];
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
