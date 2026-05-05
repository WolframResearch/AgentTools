(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`InstallMCPServer`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$installClientName    = None;
$enableMCPApps        = True;
$installToolOptions   = <| |>;
$installMCPServerName = Automatic;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InstallMCPServer*)
InstallMCPServer // beginDefinition;

(* "DevelopmentMode" option:
   - False (default): Uses the installed paclet via PacletSymbol for server startup
   - True: Uses the Scripts/StartMCPServer.wls from $thisPaclet's location (requires unbuilt paclet)
   - path_String: Uses Scripts/StartMCPServer.wls from the specified directory
   This allows testing local changes without reinstalling the paclet. *)
InstallMCPServer // Options = {
    "ApplicationName"    -> Automatic,
    "DevelopmentMode"    -> False,
    "EnableMCPApps"      -> True,
    "MCPServerName"      -> Automatic,
    "ProcessEnvironment" -> Automatic,
    "ToolOptions"        -> <| |>,
    "VerifyLLMKit"       -> True
};

InstallMCPServer[ target_, opts: OptionsPattern[ ] ] :=
    catchMine @ InstallMCPServer[ target, Automatic, opts ];

InstallMCPServer[ target_, Automatic, opts: OptionsPattern[ ] ] :=
    catchMine @ InstallMCPServer[ target, $defaultMCPServer, opts ];

InstallMCPServer[ target_File? fileQ, server0_String? pacletQualifiedNameQ, opts: OptionsPattern[ ] ] :=
    catchMine @ (
        ensurePacletForInstall @ server0;
        With[ { server = ensureMCPServerExists @ MCPServerObject @ server0 },
            Block[
                {
                    $installClientName    = validateInstallClientName[ OptionValue[ "ApplicationName" ], target ],
                    $enableMCPApps        = OptionValue[ "EnableMCPApps" ],
                    $installToolOptions   = validateToolOptions[ OptionValue[ "ToolOptions" ], server ],
                    $installMCPServerName = OptionValue[ "MCPServerName" ]
                },
                installMCPServer[
                    target,
                    server,
                    OptionValue @ ProcessEnvironment,
                    OptionValue @ VerifyLLMKit,
                    OptionValue[ "DevelopmentMode" ]
                ]
            ]
        ]
    );

InstallMCPServer[ target_File? fileQ, server0_, opts: OptionsPattern[ ] ] :=
    catchMine @ With[ { server = ensureMCPServerExists @ MCPServerObject @ server0 },
        Block[
            {
                $installClientName    = validateInstallClientName[ OptionValue[ "ApplicationName" ], target ],
                $enableMCPApps        = OptionValue[ "EnableMCPApps" ],
                $installToolOptions   = validateToolOptions[ OptionValue[ "ToolOptions" ], server ],
                $installMCPServerName = OptionValue[ "MCPServerName" ]
            },
            installMCPServer[
                target,
                server,
                OptionValue @ ProcessEnvironment,
                OptionValue @ VerifyLLMKit,
                OptionValue[ "DevelopmentMode" ]
            ]
        ]
    ];

InstallMCPServer[ name_String, server_, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[ { $installClientName = toInstallName @ name },
        InstallMCPServer[ installLocation @ name, server, opts ]
    ];

InstallMCPServer[ { name_String, dir_ }, server_, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[ { $installClientName = toInstallName @ name },
        InstallMCPServer[ projectInstallLocation[ $installClientName, dir ], server, opts ]
    ];

InstallMCPServer // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validateInstallClientName*)
validateInstallClientName // beginDefinition;
validateInstallClientName[ Automatic, file_? fileQ ] := guessClientName @ file;
validateInstallClientName[ name_String, _ ] := toInstallName @ name;
validateInstallClientName[ other_, _ ] := throwFailure[ "InvalidApplicationName", other ];
validateInstallClientName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveMCPServerName*)
resolveMCPServerName // beginDefinition;
resolveMCPServerName[ obj_MCPServerObject ] := resolveMCPServerName[ $installMCPServerName, obj ];
resolveMCPServerName[ name_String, _ ] := name;
resolveMCPServerName[ Automatic, obj_MCPServerObject ] := Replace[ Quiet @ obj[ "MCPServerName" ], Except[ _String ] :> obj[ "Name" ] ];
resolveMCPServerName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*installMCPServer*)
installMCPServer // beginDefinition;

installMCPServer[ target_, obj_, Automatic|Inherited, verifyLLMKit_, devMode_ ] :=
    installMCPServer[ target, obj, defaultEnvironment[ ], verifyLLMKit, devMode ];

installMCPServer[ target0_File, obj_MCPServerObject, env_Association, verifyLLMKit_, devMode_ ] /; $installClientName === "Codex" := Enclose[
    Module[ { target, name, configName, json, data, server, existing, updated },

        If[ verifyLLMKit, ConfirmMatch[ checkLLMKitRequirements @ obj, _String|None, "LLMKitCheck" ] ];
        initializeTools @ obj;
        Confirm[ validatePacletServerDefinitions @ obj, "ValidatePacletServerDefinitions" ];

        target     = ConfirmBy[ ensureFilePath @ target0, fileQ, "Target" ];
        name       = ConfirmBy[ obj[ "Name" ], StringQ, "Name" ];
        configName = ConfirmBy[ resolveMCPServerName @ obj, StringQ, "ConfigName" ];
        json       = ConfirmBy[ obj[ "JSONConfiguration" ], StringQ, "JSONConfiguration" ];
        data       = ConfirmBy[ Developer`ReadRawJSONString @ json, AssociationQ, "JSONConfiguration" ];
        server     = ConfirmBy[ addEnvironmentVariables[ data[ "mcpServers", name ], env ], AssociationQ, "Server" ];
        If[ devMode =!= False,
            server[ "args" ] = ConfirmMatch[ makeDevelopmentArgs @ devMode, { __String }, "DevelopmentArgs" ]
        ];

        (* Convert to Codex format *)
        server = ConfirmBy[ convertToCodexFormat @ server, AssociationQ, "CodexServer" ];

        (* Read existing TOML config *)
        existing = ConfirmBy[ readTOMLFile @ target, AssociationQ, "ExistingTOML" ];

        (* Add/update the server *)
        updated = ConfirmBy[ setMCPServer[ existing, configName, server ], AssociationQ, "UpdatedTOML" ];

        (* Write back *)
        ConfirmBy[ writeTOMLFile[ target, updated[ "Data" ], updated ], fileQ, "Export" ];
        clearStaleBuiltInRecords[ target, configName, obj ];
        ConfirmBy[ recordMCPInstallation[ target, obj ], FileExistsQ, "Record" ];

        installSuccess[ name, target, obj ]
    ],
    throwInternalFailure
];

installMCPServer[ target0_File, obj_MCPServerObject, env_Association, verifyLLMKit_, devMode_ ] /; $installClientName === "Goose" := Enclose[
    Module[ { target, name, configName, json, data, server, existing, extensions },

        If[ verifyLLMKit, ConfirmMatch[ checkLLMKitRequirements @ obj, _String|None, "LLMKitCheck" ] ];
        initializeTools @ obj;
        Confirm[ validatePacletServerDefinitions @ obj, "ValidatePacletServerDefinitions" ];

        target     = ConfirmBy[ ensureFilePath @ target0, fileQ, "Target" ];
        name       = ConfirmBy[ obj[ "Name" ], StringQ, "Name" ];
        configName = ConfirmBy[ resolveMCPServerName @ obj, StringQ, "ConfigName" ];
        json       = ConfirmBy[ obj[ "JSONConfiguration" ], StringQ, "JSONConfiguration" ];
        data       = ConfirmBy[ Developer`ReadRawJSONString @ json, AssociationQ, "JSONConfiguration" ];
        server     = ConfirmBy[ addEnvironmentVariables[ data[ "mcpServers", name ], env ], AssociationQ, "Server" ];
        If[ devMode =!= False,
            server[ "args" ] = ConfirmMatch[ makeDevelopmentArgs @ devMode, { __String }, "DevelopmentArgs" ]
        ];

        (* Convert to Goose's extension shape and stamp the display name *)
        server = ConfirmBy[ convertToGooseFormat @ server, AssociationQ, "GooseServer" ];
        server = Prepend[ server, "name" -> configName ];

        (* Read existing YAML config -- empty mapping if missing, otherwise the
           parsed Association.  Surfaces InvalidMCPConfiguration on parse failure
           so we never silently overwrite a user-edited file. *)
        existing   = ConfirmBy[ readExistingGooseConfig @ target, AssociationQ, "Existing" ];
        extensions = Replace[ Lookup[ existing, "extensions", <| |> ], Except[ _? AssociationQ ] -> <| |> ];
        extensions[ configName ] = server;
        existing[ "extensions" ] = extensions;

        ConfirmBy[ exportYAML[ target, existing ], fileQ, "Export" ];

        clearStaleBuiltInRecords[ target, configName, obj ];
        ConfirmBy[ recordMCPInstallation[ target, obj ], FileExistsQ, "Record" ];

        installSuccess[ name, target, obj ]
    ],
    throwInternalFailure
];

installMCPServer[ target0_File, obj_MCPServerObject, env_Association, verifyLLMKit_, devMode_ ] := Enclose[
    Module[ { target, name, configName, json, data, server, existing, path, convert },

        If[ verifyLLMKit, ConfirmMatch[ checkLLMKitRequirements @ obj, _String|None, "LLMKitCheck" ] ];
        initializeTools @ obj;
        Confirm[ validatePacletServerDefinitions @ obj, "ValidatePacletServerDefinitions" ];

        target     = ConfirmBy[ ensureFilePath @ target0, fileQ, "Target" ];
        name       = ConfirmBy[ obj[ "Name" ], StringQ, "Name" ];
        configName = ConfirmBy[ resolveMCPServerName @ obj, StringQ, "ConfigName" ];
        json       = ConfirmBy[ obj[ "JSONConfiguration" ], StringQ, "JSONConfiguration" ];
        data       = ConfirmBy[ Developer`ReadRawJSONString @ json, AssociationQ, "JSONConfiguration" ];
        server     = ConfirmBy[ addEnvironmentVariables[ data[ "mcpServers", name ], env ], AssociationQ, "Server" ];
        If[ devMode =!= False,
            server[ "args" ] = ConfirmMatch[ makeDevelopmentArgs @ devMode, { __String }, "DevelopmentArgs" ]
        ];
        existing = ConfirmBy[ readExistingMCPConfig @ target, AssociationQ, "Existing" ];

        path    = ConfirmMatch[ configKeyPath @ target, { __String }, "ConfigKeyPath" ];
        convert = serverConverter @ $installClientName;
        server  = ConfirmBy[ convert @ server, AssociationQ, "ConvertedServer" ];

        With[ { keys = Sequence @@ path },
            existing[ keys, configName ] = server
        ];

        ConfirmBy[ writeRawJSONFile[ target, existing ], FileExistsQ, "Export" ];
        ConfirmAssert[ readRawJSONFile @ target === existing, "ExportCheck" ];

        clearStaleBuiltInRecords[ target, configName, obj ];
        ConfirmBy[ recordMCPInstallation[ target, obj ], FileExistsQ, "Record" ];

        installSuccess[ name, target, obj ]
    ],
    throwInternalFailure
];

installMCPServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*initializeTools*)
initializeTools // beginDefinition;
initializeTools[ obj_MCPServerObject ] := initializeTools @ obj[ "Tools" ];
initializeTools[ tools_List ] := initializeTools /@ tools;
initializeTools[ tool_LLMTool ] := initializeTools @ tool[ "Data" ];
initializeTools[ as_Association ] := Lookup[ as, "Initialization", Null ];
initializeTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validatePacletServerDefinitions*)

(* Validates paclet-qualified tool and prompt definitions at install time.
   Bypasses obj["Tools"] (which catches errors via catchTop) and instead resolves
   each paclet-qualified name directly so that throwFailure propagates to catchMine. *)
validatePacletServerDefinitions // beginDefinition;

validatePacletServerDefinitions[ obj_MCPServerObject ] :=
    validatePacletServerDefinitions @ obj[ "Data" ];

validatePacletServerDefinitions[ data_Association ] :=
    Catch @ Module[ { evaluator, tools, prompts },
        evaluator = Lookup[ data, "LLMEvaluator", <| |> ];
        If[ ! AssociationQ @ evaluator, Throw @ Null ];

        (* Validate paclet-qualified tools *)
        tools = Flatten @ { Lookup[ evaluator, "Tools", { } ] };
        resolvePacletTool /@ Select[ tools, pacletQualifiedNameQ ];

        (* Validate paclet-qualified prompts *)
        prompts = Flatten @ { Lookup[ evaluator, "MCPPrompts", { } ] };
        resolvePacletPrompt /@ Select[ prompts, pacletQualifiedNameQ ];

        Null
    ];

validatePacletServerDefinitions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkLLMKitRequirements*)
checkLLMKitRequirements // beginDefinition;

checkLLMKitRequirements[ obj_MCPServerObject ] /; llmKitSubscribedQ[ ] :=
    None;

checkLLMKitRequirements[ obj_MCPServerObject ] :=
    checkLLMKitRequirements[ obj[ "Name" ], obj[ "Tools" ] ];

checkLLMKitRequirements[ name_String, tools: { ___LLMTool } ] := Enclose[
    Module[ { requirements, result },

        requirements = ConfirmMatch[
            checkLLMKitRequirements[ name, # ] & /@ tools,
            { (_String|None)... },
            "LLMKitCheck"
        ];

        result = Which[
            MemberQ[ requirements, "Required"  ], "Required",
            MemberQ[ requirements, "Suggested" ], "Suggested",
            True, None
        ];

        issueLLMKitMessage[ name, result ]
    ],
    throwInternalFailure
];


checkLLMKitRequirements[ name_String, tool_LLMTool ] :=
    checkLLMKitRequirements[ name, tool[ "Data" ][ "LLMKit" ] ];

checkLLMKitRequirements[ name_String, type: "Required"|"Suggested" ] :=
    type;

checkLLMKitRequirements[ name_String, _ ] :=
    None;

checkLLMKitRequirements // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*issueLLMKitMessage*)
issueLLMKitMessage // beginDefinition;

issueLLMKitMessage[ name_String, None ] := None;

issueLLMKitMessage[ name_String, "Required" ] := Enclose[
    throwFailure[
        "LLMKitRequired",
        name,
        ConfirmMatch[ $llmKitSubscribeLink, Hyperlink[ _String, _String ], "LLMKitSubscribeLink" ],
        ConfirmMatch[ $llmKitSubscribeURL, _String, "LLMKitSubscribeURL" ]
    ],
    throwInternalFailure
];

issueLLMKitMessage[ name_String, "Suggested" ] := Enclose[
    messagePrint[
        "LLMKitSuggested",
        name,
        ConfirmMatch[ $llmKitSubscribeLink, Hyperlink[ _String, _String ], "LLMKitSubscribeLink" ],
        ConfirmMatch[ $llmKitSubscribeURL, _String, "LLMKitSubscribeURL" ]
    ];
    "Suggested",
    throwInternalFailure
];

issueLLMKitMessage // endDefinition;


$llmKitSubscribeURL  := getLLMKitInfo[ ][ "buyNowUrl" ];
$llmKitSubscribeLink := Hyperlink[ "here", $llmKitSubscribeURL ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*recordMCPInstallation*)
recordMCPInstallation // beginDefinition;

recordMCPInstallation[ target_? fileQ, obj_MCPServerObject ] :=
    recordMCPInstallation[ { $installClientName, target }, obj ];

recordMCPInstallation[ { name: _String|None, target_? fileQ }, obj_MCPServerObject ] := Enclose[
    Module[ { file, existing, installation, new, filtered },
        file = ConfirmBy[ mcpServerFile[ obj, "Installations.wxf" ], fileQ, "File" ];
        existing = mcpServerInstallations @ obj;
        installation = ConfirmBy[ toMCPInstallationData @ { name, target }, AssociationQ, "Installation" ];
        new = If[ ListQ @ existing, Union[ existing, { installation } ], { installation } ];
        filtered = Select[ new, mcpConfigExistsQ ];
        ConfirmBy[ writeWXFFile[ file, filtered ], FileExistsQ, "Export" ]
    ],
    throwInternalFailure
];

recordMCPInstallation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*clearStaleBuiltInRecords*)
clearStaleBuiltInRecords // beginDefinition;

clearStaleBuiltInRecords[ target_, "Wolfram", obj_MCPServerObject ] /;
    KeyExistsQ[ $DefaultMCPServers, obj[ "Name" ] ] :=
    Module[ { currentName, otherNames },
        currentName = obj[ "Name" ];
        otherNames = DeleteCases[ Keys @ $DefaultMCPServers, currentName ];
        Scan[
            Function[ otherName,
                Quiet @ catchAlways @ clearRecordedInstallation[ target, MCPServerObject @ otherName ]
            ],
            otherNames
        ]
    ];

clearStaleBuiltInRecords[ _, _, _ ] := Null;

clearStaleBuiltInRecords // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*clearRecordedInstallation*)
clearRecordedInstallation // beginDefinition;

clearRecordedInstallation[ target_? fileQ, obj_MCPServerObject ] :=
    clearRecordedInstallation[ { $installClientName, target }, obj ];

clearRecordedInstallation[ { name: _String|None, target_? fileQ }, obj_MCPServerObject ] := Enclose[
    Module[ { file, existing, installation, new },
        file = ConfirmBy[ mcpServerFile[ obj, "Installations.wxf" ], fileQ, "File" ];
        existing = mcpServerInstallations @ obj;
        installation = toMCPInstallationData @ { name, target };

        new = DeleteCases[
            If[ ListQ @ existing, existing, { } ],
            installation | KeyValuePattern[ "ConfigurationFile" -> target ]
        ];

        If[ new === { },
            Quiet @ DeleteFile @ file,
            ConfirmBy[ writeWXFFile[ file, new ], FileExistsQ, "Export" ]
        ];

        new
    ],
    throwInternalFailure
];

clearRecordedInstallation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mcpServerInstallations*)
mcpServerInstallations // beginDefinition;

mcpServerInstallations[ obj0_ ] := Enclose[
    Catch @ Module[ { obj, file, installations, updated, unique },
        obj = ConfirmBy[ MCPServerObject @ obj0, MCPServerObjectQ, "MCPServerObject" ];
        file = ConfirmBy[ mcpServerFile[ obj, "Installations.wxf" ], fileQ, "File" ];
        installations = If[ FileExistsQ @ file, Quiet @ readWXFFile @ file, { } ];
        If[ ! ListQ @ installations, Throw @ { } ];

        (* Legacy installations have only the configuration file, so we try to guess the client name from it *)
        updated = ConfirmMatch[ toMCPInstallationData /@ installations, { ___Association }, "Updated" ];
        unique = DeleteDuplicates[ KeySort /@ updated ];

        (* If we've updated legacy data, be sure to write it back to the file *)
        If[ unique =!= installations, ConfirmBy[ writeWXFFile[ file, unique ], FileExistsQ, "Export" ] ];

        (* Return the unique installations *)
        unique
    ],
    throwInternalFailure
];

mcpServerInstallations // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toMCPInstallationData*)
toMCPInstallationData // beginDefinition;

toMCPInstallationData[ as: KeyValuePattern @ { "ClientName" -> _String|None, "ConfigurationFile" -> _? fileQ } ] :=
    as;

toMCPInstallationData[ { name: _String|None, file_? fileQ } ] := <|
    "ClientName"        -> name,
    "ConfigurationFile" -> file
|>;

toMCPInstallationData[ file_? fileQ ] := <|
    "ClientName"        -> guessClientName @ file,
    "ConfigurationFile" -> file
|>;

toMCPInstallationData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*guessClientName*)
guessClientName // beginDefinition;

(* Legacy code only recorded the file name, not the name of the client.
   To update these, we attempt to guess the original client name from the file name. *)
guessClientName[ file_? fileQ ] := Enclose[
    Catch @ Module[ { clientNames, client, split, extension, format },

        (* Check if the file explicitly matches a client's global install location *)
        clientNames = Keys @ $SupportedMCPClients;
        client = SelectFirst[ clientNames, Quiet @ catchAlways @ installLocation @ # === file & ];
        If[ StringQ @ client, Throw @ client ];

        (* Try to guess from the file path for project-level installations *)
        split = ToLowerCase @ ConfirmMatch[ FileNameSplit @ file, { __String }, "Split" ];
        Switch[ split,
            { __, ".mcp.json" }, Throw[ "ClaudeCode" ],
            { __, "opencode.json" }, Throw[ "OpenCode" ],
            { __, ".vscode", "settings.json" | "mcp.json" }, Throw[ "VisualStudioCode" ],
            { __, ".junie", "mcp", "mcp.json" }, Throw[ "Junie" ],
            { __, ".kiro", "settings", "mcp.json" }, Throw[ "Kiro" ],
            { __, ".zed", "settings.json" }, Throw[ "Zed" ]
        ];

        (* Try to guess from the file extension *)
        extension = ToLowerCase @ ConfirmBy[ FileExtension @ file, StringQ, "Extension" ];
        If[ extension === "toml", Throw[ "Codex" ] ];
        If[ extension === "yaml" || extension === "yml", Throw[ "Goose" ] ];
        If[ extension === "json", Throw @ guessClientNameFromJSON @ file ];

        (* Try to guess from the file format (only if the file exists) *)
        If[ ! FileExistsQ @ file, Throw @ None ];
        format = Quiet @ FileFormat @ file;
        If[ ! StringQ @ format, Throw @ None ];
        format = ToLowerCase @ ConfirmBy[ format, StringQ, "Format" ];
        If[ format === "json", Throw @ guessClientNameFromJSON @ file ];
        If[ format === "toml", Throw[ "Codex" ] ];

        (* If all else fails, return None *)
        None
    ],
    None &
];

guessClientName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*guessClientNameFromJSON helpers*)
anyServerEntryQ // beginDefinition;
anyServerEntryQ[ servers_Association, test_ ] := AnyTrue[ Values @ servers, test ];
anyServerEntryQ[ _, _ ] := False;
anyServerEntryQ // endDefinition;

hasOpenCodeTraits // beginDefinition;
hasOpenCodeTraits[ entry_Association ] := KeyExistsQ[ entry, "type" ] && ListQ @ Lookup[ entry, "command" ];
hasOpenCodeTraits[ _ ] := False;
hasOpenCodeTraits // endDefinition;

hasCopilotCLITraits // beginDefinition;
hasCopilotCLITraits[ entry_Association ] := KeyExistsQ[ entry, "tools" ];
hasCopilotCLITraits[ _ ] := False;
hasCopilotCLITraits // endDefinition;

hasClineTraits // beginDefinition;
hasClineTraits[ entry_Association ] := KeyExistsQ[ entry, "disabled" ] && KeyExistsQ[ entry, "autoApprove" ];
hasClineTraits[ _ ] := False;
hasClineTraits // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*guessClientNameFromJSON*)
guessClientNameFromJSON // beginDefinition;

guessClientNameFromJSON[ file_ ] := Enclose[
    Catch @ Module[ { json, mcp, mcpServers },

        json = Quiet @ readRawJSONFile @ file;
        If[ ! AssociationQ @ json, Throw @ None ];

        (* Tier 1: unique top-level keys *)
        If[ KeyExistsQ[ json, "context_servers" ], Throw[ "Zed" ] ];

        (* New mcp.json format: "servers" at root level.
           Require the filename to be mcp.json to avoid false positives
           from unrelated JSON files that happen to have a "servers" key. *)
        If[ KeyExistsQ[ json, "servers" ] && AssociationQ @ json[ "servers" ],
            With[ { name = Quiet @ ToLowerCase @ Last @ FileNameSplit @ file },
                If[ name === "mcp.json", Throw[ "VisualStudioCode" ] ]
            ]
        ];

        If[ KeyExistsQ[ json, "mcp" ] && AssociationQ @ json[ "mcp" ],
            mcp = json[ "mcp" ];
            If[ KeyExistsQ[ mcp, "servers" ],
                Throw[ "VisualStudioCode" ]
            ];
            If[ anyServerEntryQ[ mcp, hasOpenCodeTraits ],
                Throw[ "OpenCode" ]
            ];
        ];

        (* Tier 2: mcpServers clients, distinguished by server entry fields *)
        If[ KeyExistsQ[ json, "mcpServers" ] && AssociationQ @ json[ "mcpServers" ],
            mcpServers = json[ "mcpServers" ];
            If[ anyServerEntryQ[ mcpServers, hasCopilotCLITraits ], Throw[ "CopilotCLI" ] ];
            If[ anyServerEntryQ[ mcpServers, hasClineTraits ], Throw[ "Cline" ] ];
        ];

        None
    ],
    None &
];

guessClientNameFromJSON // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mcpConfigExistsQ*)
mcpConfigExistsQ // beginDefinition;
mcpConfigExistsQ[ KeyValuePattern[ "ConfigurationFile" -> file_ ] ] := mcpConfigExistsQ @ file;
mcpConfigExistsQ[ target_? fileQ ] := FileExistsQ @ target;
mcpConfigExistsQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validateToolOptions*)
validateToolOptions // beginDefinition;

validateToolOptions[ <| |>, _ ] := <| |>;

validateToolOptions[ opts_Association? AssociationQ, server_MCPServerObject ] := Enclose[
    Module[ { toolNames, knownToolNames, knownQ, validated },
        toolNames = ConfirmMatch[ #[ "Name" ] & /@ server[ "Tools" ], { ___String }, "ToolNames" ];
        knownToolNames = ConfirmMatch[ Union[ Keys @ $defaultToolOptions, toolNames ], { ___String }, "KnownNames" ];
        knownQ = AssociationMap[ True &, knownToolNames ];

        validated = KeyValueMap[
            Function[ { toolName, toolOpts },
                If[ ! TrueQ @ knownQ @ toolName, messagePrint[ "UnrecognizedToolOption", toolName ] ];
                If[ ! AssociationQ @ toolOpts,
                    messagePrint[ "InvalidToolOptionValue", toolName, toolOpts ];
                    Nothing,
                    (* else: valid Association *)
                    If[ KeyExistsQ[ $defaultToolOptions, toolName ],
                        Scan[
                            Function[ optName,
                                If[ ! KeyExistsQ[ $defaultToolOptions[ toolName ], optName ],
                                    messagePrint[ "UnrecognizedToolOptionName", optName, toolName ]
                                ]
                            ],
                            Keys @ toolOpts
                        ]
                    ];
                    toolName -> toolOpts
                ]
            ],
            opts
        ];

        Association @ validated
    ],
    throwInternalFailure
];

validateToolOptions[ other_, _ ] := (
    messagePrint[ "InvalidToolOptions", other ];
    <| |>
);

validateToolOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addEnvironmentVariables*)
addEnvironmentVariables // beginDefinition;

addEnvironmentVariables[ server0_Association, extraEnv0_Association ] := Enclose[
    Module[ { server, env, extraEnv, newEnv },

        server = ConfirmBy[ server0, AssociationQ, "Server" ];
        env = ConfirmBy[ server[ "env" ], AssociationQ, "Environment" ];
        extraEnv = If[ $enableMCPApps === False, <| extraEnv0, "MCP_APPS_ENABLED" -> "false" |>, extraEnv0 ];

        If[ AssociationQ @ $installToolOptions && $installToolOptions =!= <| |>,
            extraEnv = <|
                extraEnv,
                "MCP_TOOL_OPTIONS" -> Developer`WriteRawJSONString[ $installToolOptions, "Compact" -> True ]
            |>
        ];

        newEnv = ConfirmBy[ <| env, extraEnv |>, AssociationQ, "NewEnvironment" ];
        server[ "env" ] = newEnv;
        server
    ],
    throwInternalFailure
];

addEnvironmentVariables // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeDevelopmentArgs*)
makeDevelopmentArgs // beginDefinition;

makeDevelopmentArgs[ True ] :=
    makeDevelopmentArgs @ $thisPaclet[ "Location" ];

makeDevelopmentArgs[ dir_String ] :=
    Module[ { script },
        script = FileNameJoin @ { dir, "Scripts", "StartMCPServer.wls" };
        If[ FileExistsQ @ script,
            { "-script", script, "-noinit", "-noprompt" },
            throwFailure[ "DevelopmentModeUnavailable", dir ]
        ]
    ];

makeDevelopmentArgs[ invalid_ ] :=
    throwFailure[ "InvalidDevelopmentMode", invalid ];

makeDevelopmentArgs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertToCodexFormat*)
convertToCodexFormat // beginDefinition;

convertToCodexFormat[ server_Association ] := Enclose[
    Module[ { command, args, env, result },
        command = ConfirmMatch[ Lookup[ server, "command", Missing[ ] ], _String | _Missing, "Command" ];
        args = Lookup[ server, "args", { } ];
        env = Lookup[ server, "env", <| |> ];

        result = <| |>;

        If[ command =!= Missing[ ],
            result[ "command" ] = command
        ];

        If[ ListQ @ args && Length @ args > 0,
            result[ "args" ] = args
        ];

        If[ AssociationQ @ env && Length @ env > 0,
            result[ "env" ] = env
        ];

        result[ "enabled" ] = True;

        result
    ],
    throwInternalFailure
];

convertToCodexFormat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertToGooseFormat*)
(* Maps the internal mcpServers entry shape (command/args/env) to Goose's
   extensions entry shape (cmd/args/envs/enabled/type/timeout).  The display
   "name" field is *not* set here -- the install function prepends it after
   conversion since the converter doesn't know configName. *)
convertToGooseFormat // beginDefinition;

convertToGooseFormat[ server_Association ] := Enclose[
    Module[ { command, args, env, result },
        command = ConfirmMatch[ Lookup[ server, "command", Missing[ ] ], _String | _Missing, "Command" ];
        args    = Lookup[ server, "args", { } ];
        env     = Lookup[ server, "env" , <| |> ];

        result = <| |>;

        If[ command =!= Missing[ ],
            result[ "cmd" ] = command
        ];

        If[ ListQ @ args && Length @ args > 0,
            result[ "args" ] = args
        ];

        result[ "enabled" ] = True;

        If[ AssociationQ @ env && Length @ env > 0,
            result[ "envs" ] = env
        ];

        result[ "type"    ] = "stdio";
        result[ "timeout" ] = 300;

        result
    ],
    throwInternalFailure
];

convertToGooseFormat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*defaultEnvironment*)
defaultEnvironment // beginDefinition;

defaultEnvironment[ ] := Enclose[
    Module[ { env, keys, usable, override },

        env = KeyMap[
            ToUpperCase,
            KeySelect[
                ConfirmBy[ Association @ GetEnvironment[ ], AssociationQ, "Environment" ],
                StringQ
            ]
        ];

        keys = If[ $OperatingSystem === "Windows",
                   $windowsEnvironmentKeys,
                   $defaultEnvironmentKeys
               ];

        usable = ConfirmBy[ KeyTake[ env, keys ], AssociationQ, "Usable" ];

        override = ConfirmBy[ $overrideEnvironment, AssociationQ, "Fallback" ];
        ConfirmAssert[ AllTrue[ override, StringQ ], "FallbackCheck" ];

        defaultEnvironment[ ] = ConfirmBy[ <| usable, override |>, AssociationQ, "Result" ]
    ],
    throwInternalFailure
];

defaultEnvironment // endDefinition;


$defaultEnvironmentKeys = { "WOLFRAM_BASE", "WOLFRAM_USERBASE", "WOLFRAM_LOCALBASE" };
$windowsEnvironmentKeys = Append[ $defaultEnvironmentKeys, "APPDATA" ];

$overrideEnvironment := <|
    "WOLFRAM_BASE"      -> $BaseDirectory,
    "WOLFRAM_LOCALBASE" -> ExpandFileName @ LocalObject @ $LocalBase,
    "WOLFRAM_USERBASE"  -> $UserBaseDirectory
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installSuccess*)
installSuccess // beginDefinition;

installSuccess[ serverName_, installLocation_, obj_ ] :=
    installSuccess[ serverName, installLocation, obj, installDisplayName @ $installClientName ];

installSuccess[ serverName_String, installLocation_File? fileQ, obj_MCPServerObject, installName_String ] :=
    Success[
        "InstallMCPServer",
        <|
            "MessageTemplate"   :> AgentTools::InstallMCPServerNamed,
            "MessageParameters" -> { serverName, installName },
            "Location"          -> installLocation,
            "MCPServerObject"   -> obj
        |>
    ];

installSuccess[ serverName_String, installLocation_File? fileQ, obj_MCPServerObject, installName_ ] :=
    Success[
        "InstallMCPServer",
        <|
            "MessageTemplate"   :> AgentTools::InstallMCPServer,
            "MessageParameters" -> { serverName },
            "Location"          -> installLocation,
            "MCPServerObject"   -> obj
        |>
    ];

installSuccess // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*configKeyPath*)
configKeyPath // beginDefinition;

configKeyPath[ ] := configKeyPath @ $installClientName;

configKeyPath[ file_? fileQ ] := configKeyPath[ $installClientName, file ];

(* VS Code with legacy settings.json: use the old nested key path *)
configKeyPath[ "VisualStudioCode", File[ path_String ] ] /;
    ToLowerCase @ FileNameTake @ path === "settings.json" := { "mcp", "servers" };

configKeyPath[ name_String, _ ] /; KeyExistsQ[ $supportedMCPClients, name ] :=
    $supportedMCPClients[ name, "ConfigKey" ];

configKeyPath[ name_String ] /; KeyExistsQ[ $supportedMCPClients, name ] :=
    $supportedMCPClients[ name, "ConfigKey" ];

configKeyPath[ _ ] := { "mcpServers" };
configKeyPath[ _, _ ] := { "mcpServers" };

configKeyPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*emptyConfigForPath*)
emptyConfigForPath // beginDefinition;
emptyConfigForPath[ { } ] := <| |>;
emptyConfigForPath[ { key_String, rest___String } ] := <| key -> emptyConfigForPath @ { rest } |>;
emptyConfigForPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureNestedKey*)
ensureNestedKey // beginDefinition;
ensureNestedKey[ data_? AssociationQ, { } ] := data;
ensureNestedKey[ data_? AssociationQ, { key_String, rest___String } ] :=
    Append[ data, key -> ensureNestedKey[
        Replace[ data @ key, Except[ _? AssociationQ ] -> <| |> ],
        { rest }
    ] ];
ensureNestedKey[ data_, path_List ] := ensureNestedKey[ <| |>, path ];
ensureNestedKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*serverConverter*)
serverConverter // beginDefinition;
serverConverter[ name_String ] := Replace[ $supportedMCPClients[ name, "ServerConverter" ], _Missing -> Identity ];
serverConverter[ _ ] := Identity;
serverConverter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readExistingMCPConfig*)
readExistingMCPConfig // beginDefinition;

readExistingMCPConfig[ file_ ] := Enclose[
    Catch @ Module[ { path, data },
        path = ConfirmMatch[ configKeyPath @ file, { __String }, "ConfigKeyPath" ];
        If[ ! FileExistsQ @ file, Throw @ emptyConfigForPath @ path ];

        (* Quiet any parsing errors, because we'll be issuing our own `InvalidMCPConfiguration` message if it fails *)
        data = Quiet @ readRawJSONFile @ ExpandFileName @ file;

        (* Handle empty files *)
        If[ data === Missing[ "EmptyFile" ], Throw @ emptyConfigForPath @ path ];

        (* Throw a failure for any other unexpected result*)
        If[ ! AssociationQ @ data, throwFailure[ "InvalidMCPConfiguration", file ] ];

        (* Create the nested key structure *)
        ensureNestedKey[ data, path ]
    ],
    throwInternalFailure
];

readExistingMCPConfig // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readExistingGooseConfig*)
(* YAML counterpart to readExistingMCPConfig.  Returns an empty mapping when the
   target file is missing or empty, otherwise returns the parsed Association.
   On any parse failure (or a top-level value that isn't a mapping) it issues
   InvalidMCPConfiguration so the caller never silently rewrites a file the
   user has been editing by hand. *)
readExistingGooseConfig // beginDefinition;

readExistingGooseConfig[ file_ ] := Enclose[
    Catch @ Module[ { data },
        If[ ! FileExistsQ @ file, Throw @ <| |> ];

        (* Quiet any parsing errors, because we'll be issuing our own `InvalidMCPConfiguration` message if it fails *)
        data = Quiet @ catchAlways @ importYAML @ file;

        Which[
            (* Empty file or empty mapping -- treat as empty config *)
            data === <| |>, <| |>,
            (* Valid mapping -- pass through *)
            AssociationQ @ data, data,
            (* Anything else (parse failure, top-level list, etc.) -- refuse to overwrite *)
            True, throwFailure[ "InvalidMCPConfiguration", file ]
        ]
    ],
    throwInternalFailure
];

readExistingGooseConfig // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*UninstallMCPServer*)
UninstallMCPServer // beginDefinition;

UninstallMCPServer // Options = {
    "ApplicationName" -> Automatic,
    "MCPServerName"   -> Automatic
};

UninstallMCPServer[ target_File, opts: OptionsPattern[ ] ] :=
    catchMine @ UninstallMCPServer[ target, All, opts ];

UninstallMCPServer[ name_String, opts: OptionsPattern[ ] ] :=
    catchMine @ UninstallMCPServer[ name, All, opts ];

UninstallMCPServer[ obj_, opts: OptionsPattern[ ] ] :=
    catchMine @ UninstallMCPServer[ All, obj, opts ];

UninstallMCPServer[ target: _File | All, All, opts: OptionsPattern[ ] ] :=
    catchMine @ UninstallMCPServer[ target, allMCPServers[ ], opts ];

UninstallMCPServer[ target: _File | All, servers_List, opts: OptionsPattern[ ] ] :=
    catchMine @ DeleteMissing @ Flatten[ catchAlways @ UninstallMCPServer[ target, #, opts ] & /@ servers ];

UninstallMCPServer[ All, obj0: _MCPServerObject|_String, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    Module[ { obj, installations },
        obj = ensureMCPServerExists @ MCPServerObject @ obj0;
        installations = ConfirmMatch[ mcpServerInstallations @ obj, { ___Association }, "Installations" ];

        ConfirmMatch[
            DeleteMissing[ catchAlways @ UninstallMCPServer[ #, obj, opts ] & /@ installations ],
            { ___Success },
            "Results"
        ]
    ],
    throwInternalFailure
];

UninstallMCPServer[
    KeyValuePattern @ { "ClientName" -> name_, "ConfigurationFile" -> file_ },
    obj_,
    opts: OptionsPattern[ ]
] := catchMine @ Block[ { $installClientName = toInstallName @ name },
        UninstallMCPServer[ file, obj, opts ]
    ];

UninstallMCPServer[ { name_String, dir_ }, obj_, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[ { $installClientName = toInstallName @ name },
        UninstallMCPServer[ projectInstallLocation[ $installClientName, dir ], obj, opts ]
    ];

UninstallMCPServer[ target_File? fileQ, obj_, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[
        {
            $installClientName    = validateInstallClientName[ OptionValue[ "ApplicationName" ], target ],
            $installMCPServerName = OptionValue[ "MCPServerName" ]
        },
        uninstallMCPServer[ target, ensureMCPServerExists @ MCPServerObject @ obj ]
    ];

UninstallMCPServer[ name_String, obj_, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[ { $installClientName = toInstallName @ name },
        UninstallMCPServer[ installLocation @ name, obj, opts ]
    ];

UninstallMCPServer // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*allMCPServers*)
allMCPServers // beginDefinition;
allMCPServers[ ] := Union[ MCPServerObjects @ All, Values @ $DefaultMCPServers ];
allMCPServers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*uninstallMCPServer*)
uninstallMCPServer // beginDefinition;

uninstallMCPServer[ target0_File, obj_MCPServerObject ] /; $installClientName === "Codex" := Enclose[
    Catch @ Module[ { target, name, configName, existing, mcpServers, updated },

        target     = ConfirmBy[ ensureFilePath @ target0, fileQ, "Target" ];
        If[ ! FileExistsQ @ target, Throw @ Missing[ "NotInstalled", target ] ];

        name       = ConfirmBy[ obj[ "Name" ], StringQ, "Name" ];
        configName = ConfirmBy[ resolveMCPServerName @ obj, StringQ, "ConfigName" ];

        (* Read existing TOML config *)
        existing = ConfirmBy[ readTOMLFile @ target, AssociationQ, "ExistingTOML" ];

        (* Check if server exists *)
        mcpServers = getMCPServers @ existing;
        If[ ! KeyExistsQ[ mcpServers, configName ], Throw @ Missing[ "NotInstalled", target ] ];

        (* Remove the server *)
        updated = ConfirmBy[ removeMCPServer[ existing, configName ], AssociationQ, "UpdatedTOML" ];

        (* Write back *)
        ConfirmBy[ writeTOMLFile[ target, updated[ "Data" ], updated ], fileQ, "Export" ];
        ConfirmMatch[ clearRecordedInstallation[ target, obj ], { ___Association }, "Clear" ];

        uninstallSuccess[ name, target, obj ]
    ],
    throwInternalFailure
];

uninstallMCPServer[ target0_File, obj_MCPServerObject ] /; $installClientName === "Goose" := Enclose[
    Catch @ Module[ { target, name, configName, existing, extensions },

        target     = ConfirmBy[ ensureFilePath @ target0, fileQ, "Target" ];
        If[ ! FileExistsQ @ target, Throw @ Missing[ "NotInstalled", target ] ];

        name       = ConfirmBy[ obj[ "Name" ], StringQ, "Name" ];
        configName = ConfirmBy[ resolveMCPServerName @ obj, StringQ, "ConfigName" ];

        (* Read existing YAML config via the same helper as the install path so
           parse failures surface as InvalidMCPConfiguration rather than an
           internal failure, and the file is never rewritten. *)
        existing = ConfirmBy[ readExistingGooseConfig @ target, AssociationQ, "Existing" ];
        extensions = Lookup[ existing, "extensions", <| |> ];

        If[ ! AssociationQ @ extensions || ! KeyExistsQ[ extensions, configName ],
            Throw @ Missing[ "NotInstalled", target ]
        ];

        KeyDropFrom[ extensions, configName ];
        existing[ "extensions" ] = extensions;

        ConfirmBy[ exportYAML[ target, existing ], fileQ, "Export" ];
        ConfirmMatch[ clearRecordedInstallation[ target, obj ], { ___Association }, "Clear" ];

        uninstallSuccess[ name, target, obj ]
    ],
    throwInternalFailure
];

uninstallMCPServer[ target0_File, obj_MCPServerObject ] := Enclose[
    Catch @ Module[ { target, name, configName, existing, path },

        target     = ConfirmBy[ ensureFilePath @ target0, fileQ, "Target" ];
        If[ ! FileExistsQ @ target, Throw @ Missing[ "NotInstalled", target ] ];

        name       = ConfirmBy[ obj[ "Name" ], StringQ, "Name" ];
        configName = ConfirmBy[ resolveMCPServerName @ obj, StringQ, "ConfigName" ];
        existing   = ConfirmBy[ readExistingMCPConfig @ target, AssociationQ, "Existing" ];

        path = ConfirmMatch[ configKeyPath @ target, { __String }, "ConfigKeyPath" ];

        With[ { keys = Sequence @@ path },
            If[ ! AssociationQ @ existing[ keys ], Throw @ Missing[ "NotInstalled", target ] ];
            If[ ! KeyExistsQ[ existing[ keys ], configName ], Throw @ Missing[ "NotInstalled", target ] ];
            KeyDropFrom[ existing[ keys ], configName ]
        ];

        ConfirmBy[ writeRawJSONFile[ target, existing ], FileExistsQ, "Export" ];

        ConfirmAssert[ readRawJSONFile @ target === existing, "ExportCheck" ];
        ConfirmMatch[ clearRecordedInstallation[ target, obj ], { ___Association }, "Clear" ];

        uninstallSuccess[ name, target, obj ]
    ],
    throwInternalFailure
];

uninstallMCPServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*uninstallSuccess*)
uninstallSuccess // beginDefinition;

uninstallSuccess[ serverName_, installLocation_, obj_ ] :=
    uninstallSuccess[ serverName, installLocation, obj, installDisplayName @ $installClientName ];

uninstallSuccess[ serverName_String, installLocation_File? fileQ, obj_MCPServerObject, installName_String ] :=
    Success[
        "UninstallMCPServer",
        <|
            "MessageTemplate"   :> AgentTools::UninstallMCPServerNamed,
            "MessageParameters" -> { serverName, installName },
            "Location"          -> installLocation,
            "MCPServerObject"   -> obj
        |>
    ];

uninstallSuccess[ serverName_String, installLocation_File? fileQ, obj_MCPServerObject, installName_ ] :=
    Success[
        "UninstallMCPServer",
        <|
            "MessageTemplate"   :> AgentTools::UninstallMCPServer,
            "MessageParameters" -> { serverName },
            "Location"          -> installLocation,
            "MCPServerObject"   -> obj
        |>
    ];

uninstallSuccess // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*installLocation*)
installLocation // beginDefinition;

installLocation[ name_String ] := installLocation[ name, $OperatingSystem ];

installLocation[ name0_String, os0_String ] := Enclose[
    Module[ { name, os, clientData, locationSpec, path },

        name = ConfirmBy[ toInstallName @ name0, StringQ, "Name" ];
        os = ConfirmBy[ os0, StringQ, "OperatingSystem" ];

        clientData = ConfirmMatch[ Lookup[ $SupportedMCPClients, name, None ], _Association|None, "ClientData" ];
        If[ clientData === None, throwFailure[ "UnsupportedMCPClient", name ] ];
        locationSpec = ConfirmMatch[ clientData[ "InstallLocation" ], _Association|_List, "InstallLocation" ];

        path = ConfirmMatch[
            If[ AssociationQ @ locationSpec, Lookup[ locationSpec, os, None ], locationSpec ],
            { __String }|None,
            "Path"
        ];

        If[ path === None, throwFailure[ "UnknownInstallLocation", name, os ] ];

        ConfirmBy[ fileNameJoin @ path, fileQ, "Result" ]
    ],
    throwInternalFailure
];

installLocation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*projectInstallLocation*)
projectInstallLocation // beginDefinition;

projectInstallLocation[ name_String, dir_ ] := Enclose[
    Module[ { clientData, path },
        clientData = Lookup[ $SupportedMCPClients, name, None ];
        If[ clientData === None, throwFailure[ "UnsupportedMCPClient", name ] ];
        ConfirmAssert[ AssociationQ @ clientData, "ClientData" ];
        If[ ! TrueQ @ clientData[ "ProjectSupport" ], throwFailure[ "UnsupportedMCPClientProject", name ] ];
        path = ConfirmMatch[ Lookup[ clientData, "ProjectPath" ], { __String }, "ProjectPath" ];
        If[ path === None, throwFailure[ "UnknownProjectInstallLocation", name ] ];
        If[ ! MatchQ[ dir, _String | _File? fileQ ], throwFailure[ "InvalidProjectDirectory", dir ] ];
        fileNameJoin[ dir, path ]
    ],
    throwInternalFailure
];

projectInstallLocation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toInstallName*)
toInstallName // beginDefinition;
toInstallName[ name_String ] := Lookup[ $aliasToCanonicalName, name, name ];
toInstallName[ None ] := None;
toInstallName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installDisplayName*)
installDisplayName // beginDefinition;
installDisplayName[ name_String ] := Lookup[ $supportedMCPClients, name, <| |> ][ "DisplayName" ] // Replace[ _Missing -> name ];
installDisplayName[ None ] := None;
installDisplayName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
