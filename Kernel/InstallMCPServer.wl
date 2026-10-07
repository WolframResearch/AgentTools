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
$enableLLMKit         = Automatic;
$installToolOptions   = <| |>;
$installMCPServerName = Automatic;
$submitUsageData      = Automatic;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InstallMCPServer*)
InstallMCPServer // beginDefinition;

(* "DevelopmentMode" option:
   - False (default): Uses the installed paclet via PacletSymbol for server startup
   - True: Uses the Scripts/StartMCPServer.wls from $thisPaclet's location (requires unbuilt paclet)
   - path_String: Uses Scripts/StartMCPServer.wls from the specified directory
   This allows testing local changes without reinstalling the paclet.

   "SubmitUsageData" option:
   - Automatic (default): Nothing is added to the configuration; the server tracks usage data only if its
     "EnableUsageData" property is True (as it is for the built-in servers)
   - True/False: Sets SUBMIT_USAGE_DATA in the server's environment, which takes precedence over the property
   See docs/usage-data.md.

   "WolframCommand" option:
   - Automatic (default): The command is resolved from $InstallationDirectory for the current operating system
   - command_String: Written verbatim as the "command" field of the client configuration, so a
     standalone executable can be launched instead of the local Wolfram kernel

   "CommandLineArguments" option:
   - Automatic (default): The standard kernel arguments that start the server (-run PacletSymbol[...][], -noinit,
     -noprompt); see $defaultCommandLineArguments in MCPServerObject.wl
   - { args___String }: Written verbatim as the "args" field of the client configuration; an empty list is allowed,
     but a single string is rejected since clients expect a JSON array
   A non-False "DevelopmentMode" replaces the arguments with the development-mode ones and takes precedence. *)
InstallMCPServer // Options = {
    "ApplicationName"      -> Automatic,
    "CommandLineArguments" -> Automatic,
    "DevelopmentMode"      -> False,
    "EnableLLMKit"         -> Automatic,
    "EnableMCPApps"        -> True,
    "MCPServerName"        -> Automatic,
    "ProcessEnvironment"   -> Automatic,
    "SubmitUsageData"      -> Automatic,
    "ToolOptions"          -> <| |>,
    "VerifyLLMKit"         -> True,
    "WolframCommand"       -> Automatic
};

InstallMCPServer[ target_, opts: OptionsPattern[ ] ] :=
    catchMine @ InstallMCPServer[ target, Automatic, opts ];

InstallMCPServer[ target_, Automatic, opts: OptionsPattern[ ] ] :=
    catchMine @ InstallMCPServer[
        target,
        defaultToolsetForTarget[ target, OptionValue[ "ApplicationName" ] ],
        opts
    ];

InstallMCPServer[ target_File? fileQ, server0_String? pacletQualifiedNameQ, opts: OptionsPattern[ ] ] :=
    catchMine @ (
        ensurePacletForInstall @ server0;
        With[ { server = ensureMCPServerExists @ MCPServerObject @ server0 },
            Block[
                {
                    $installClientName    = validateInstallClientName[ OptionValue[ "ApplicationName" ], target ],
                    $enableMCPApps        = OptionValue[ "EnableMCPApps" ],
                    $enableLLMKit         = OptionValue[ "EnableLLMKit" ],
                    $installToolOptions   = validateToolOptions[ OptionValue[ "ToolOptions" ], server ],
                    $installMCPServerName = OptionValue[ "MCPServerName" ],
                    $submitUsageData      = validateSubmitUsageData @ OptionValue[ "SubmitUsageData" ],
                    $wolframCommand       = validateWolframCommand @ OptionValue[ "WolframCommand" ],
                    $commandLineArguments = validateCommandLineArguments @ OptionValue[ "CommandLineArguments" ]
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
                $enableLLMKit         = OptionValue[ "EnableLLMKit" ],
                $installToolOptions   = validateToolOptions[ OptionValue[ "ToolOptions" ], server ],
                $installMCPServerName = OptionValue[ "MCPServerName" ],
                $submitUsageData      = validateSubmitUsageData @ OptionValue[ "SubmitUsageData" ],
                $wolframCommand       = validateWolframCommand @ OptionValue[ "WolframCommand" ],
                $commandLineArguments = validateCommandLineArguments @ OptionValue[ "CommandLineArguments" ]
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
(*validateSubmitUsageData*)
validateSubmitUsageData // beginDefinition;
validateSubmitUsageData[ value: Automatic|True|False ] := value;
validateSubmitUsageData[ other_ ] := throwFailure[ "InvalidSubmitUsageData", other ];
validateSubmitUsageData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validateWolframCommand*)
validateWolframCommand // beginDefinition;
validateWolframCommand[ value: Automatic|_String ] := value;
validateWolframCommand[ other_ ] := throwFailure[ "InvalidWolframCommand", other ];
validateWolframCommand // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validateCommandLineArguments*)
validateCommandLineArguments // beginDefinition;
validateCommandLineArguments[ value: Automatic|{ ___String } ] := value;
validateCommandLineArguments[ other_ ] := throwFailure[ "InvalidCommandLineArguments", other ];
validateCommandLineArguments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveMCPServerName*)
resolveMCPServerName // beginDefinition;
resolveMCPServerName[ obj_MCPServerObject ] := mcpServerConfigKey[ obj, $installMCPServerName ];
resolveMCPServerName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mcpServerConfigKey*)
(* The key under which a server is written into a client's configuration file: the "MCPServerName" option if it is a
   string, otherwise the server's "MCPServerName" property (e.g. "Wolfram" for every built-in server, or the short item
   name for a paclet server), falling back to the server's "Name". *)
mcpServerConfigKey // beginDefinition;
mcpServerConfigKey[ obj_MCPServerObject, name_String ] := name;
mcpServerConfigKey[ obj_MCPServerObject, _ ] := Replace[ Quiet @ obj[ "MCPServerName" ], Except[ _String ] :> obj[ "Name" ] ];
mcpServerConfigKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*localMCPServerConfigKey*)
(* Derives the configuration key of a server from its name and recorded InstallMCPServer options without any network
   access (unlike MCPServerObject, which falls back to PacletFindRemote for uninstalled paclets). This is used for
   deployment records that only recorded the server name. In order:
     1. the "MCPServerName" option, if it is a string
     2. a user server with that name (an existing Metadata.wxf), which takes precedence over built-in servers just
        like in MCPServerObject[ name ]
     3. a built-in server
     4. a paclet server whose paclet is installed (falling back to the item name if the definition can't be loaded)
     5. the last "/"-separated segment of the name (the default key for an uninstalled paclet server)
   Never throws for servers that can't be resolved. *)
localMCPServerConfigKey // beginDefinition;

localMCPServerConfigKey[ name_String, options_Association ] :=
    Replace[ Lookup[ options, "MCPServerName" ], Except[ _String ] :> localMCPServerConfigKey @ name ];

localMCPServerConfigKey[ name_String ] :=
    Replace[ Quiet @ catchAlways @ resolveLocalMCPServerConfigKey @ name, Except[ _String ] :> lastNameSegment @ name ];

localMCPServerConfigKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveLocalMCPServerConfigKey*)
resolveLocalMCPServerConfigKey // beginDefinition;

resolveLocalMCPServerConfigKey[ name_String ] := Enclose[
    Catch @ Module[ { file, data, parsed, definition },

        (* User servers *)
        file = ConfirmBy[ mcpServerFile @ name, fileQ, "File" ];
        If[ FileExistsQ @ file,
            data = Quiet @ readWXFFile @ file;
            If[ AssociationQ @ data,
                Throw @ Replace[ Lookup[ data, "MCPServerName" ], Except[ _String ] :> Lookup[ data, "Name" ] ]
            ]
        ];

        (* Built-in servers *)
        If[ KeyExistsQ[ $DefaultMCPServers, name ],
            Throw @ mcpServerConfigKey[ $DefaultMCPServers @ name, Automatic ]
        ];

        (* Paclet servers (installed paclets only) *)
        If[ pacletQualifiedNameQ @ name,
            parsed = ConfirmBy[ parsePacletQualifiedName @ name, AssociationQ, "Parsed" ];
            If[ MatchQ[ PacletFind @ parsed[ "PacletName" ], { __PacletObject } ],
                definition = Quiet @ catchAlways @ resolvePacletServer @ name;
                Throw @ Replace[
                    If[ AssociationQ @ definition, Lookup[ definition, "MCPServerName" ], Missing[ ] ],
                    Except[ _String ] :> parsed[ "ItemName" ]
                ]
            ]
        ];

        Missing[ "NotFound", name ]
    ],
    throwInternalFailure
];

resolveLocalMCPServerConfigKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*lastNameSegment*)
lastNameSegment // beginDefinition;
lastNameSegment[ name_String ] := Replace[ StringSplit[ name, "/" ], { { ___, last_String } :> last, _ :> name } ];
lastNameSegment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*preflightMCPServerInstall*)
(* Everything InstallMCPServer checks before it writes anything, given InstallMCPServer options: installs the paclet of
   a paclet server, validates the options, runs the LLMKit check (honoring "VerifyLLMKit" and "EnableLLMKit"),
   initializes the tools, and validates paclet definitions. DeployAgentTools runs this for every server of a bundle
   before modifying any files, so these failures can't leave a partially deployed bundle behind. Returns Null or throws
   a failure; nothing is written (other than installing a missing paclet). *)
preflightMCPServerInstall // beginDefinition;

preflightMCPServerInstall[ server0_MCPServerObject, opts: OptionsPattern[ ] ] := Enclose[
    Module[ { installOpts, server, appName, devMode },

        installOpts = FilterRules[ Flatten @ { opts }, Options @ InstallMCPServer ];
        server = ConfirmBy[ ensureMCPServerExists @ server0, MCPServerObjectQ, "Server" ];

        (* Like InstallMCPServer, installing a paclet server is an execution-level operation that installs its paclet.
           Only servers that come from a paclet are checked, since a user server's name may also contain "/". *)
        If[ MatchQ[ server[ "Location" ], _PacletObject ] && pacletQualifiedNameQ @ server[ "Name" ],
            ConfirmMatch[ ensurePacletForInstall @ server[ "Name" ], _PacletObject, "EnsurePaclet" ]
        ];

        (* Option validation *)
        appName = OptionValue[ InstallMCPServer, installOpts, "ApplicationName" ];
        If[ ! MatchQ[ appName, Automatic | _String ], throwFailure[ "InvalidApplicationName", appName ] ];
        validateToolOptions[ OptionValue[ InstallMCPServer, installOpts, "ToolOptions" ], server ];
        validateSubmitUsageData @ OptionValue[ InstallMCPServer, installOpts, "SubmitUsageData" ];
        validateWolframCommand @ OptionValue[ InstallMCPServer, installOpts, "WolframCommand" ];
        validateCommandLineArguments @ OptionValue[ InstallMCPServer, installOpts, "CommandLineArguments" ];
        devMode = OptionValue[ InstallMCPServer, installOpts, "DevelopmentMode" ];
        If[ devMode =!= False,
            ConfirmMatch[ makeDevelopmentArgs @ devMode, { __String }, "DevelopmentArgs" ]
        ];

        (* The same checks that installMCPServer performs before writing the configuration *)
        Block[ { $enableLLMKit = OptionValue[ InstallMCPServer, installOpts, "EnableLLMKit" ] },
            If[ TrueQ @ OptionValue[ InstallMCPServer, installOpts, "VerifyLLMKit" ],
                ConfirmMatch[ checkLLMKitRequirements @ server, _String|None, "LLMKitCheck" ]
            ]
        ];
        initializeTools @ server;
        Confirm[ validatePacletServerDefinitions @ server, "ValidatePacletServerDefinitions" ];

        Null
    ],
    throwInternalFailure
];

preflightMCPServerInstall // endDefinition;

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

(* Continue: YAML config where `mcpServers` is an *array* of entries, each carrying
   an inline `name` field. Two scopes share this overload, distinguished by the
   target path:
     - Global  ~/.continue/config.yaml          -> merge into an existing config that
                                                   may have unrelated top-level keys
                                                   (models:, slashCommands:, rules:, etc.)
     - Project <dir>/.continue/mcpServers/<*.yaml> -> standalone block file with
                                                      required top-level metadata
                                                      `name`, `version`, `schema`
   In both cases, the upsert is by the entry's `name` field. *)
installMCPServer[ target0_File, obj_MCPServerObject, env_Association, verifyLLMKit_, devMode_ ] /; $installClientName === "Continue" := Enclose[
    Module[ { target, name, configName, json, data, server, convert, existing, entries, idx, projectScopeQ },

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

        (* Convert to the Continue per-entry shape and prepend the inline name field. *)
        convert = serverConverter @ $installClientName;
        server  = ConfirmBy[ convert @ server, AssociationQ, "ContinueServer" ];
        server  = Prepend[ server, "name" -> configName ];

        (* Read existing YAML (empty mapping if missing) and locate the mcpServers array. *)
        existing = ConfirmBy[ readExistingContinueConfig @ target, AssociationQ, "Existing" ];
        entries  = Replace[ Lookup[ existing, "mcpServers", { } ], Except[ _List ] -> { } ];

        (* Upsert by name *)
        idx = FirstPosition[ entries, KeyValuePattern @ { "name" -> configName }, Missing[ "NotFound" ] ];
        entries = If[ MatchQ[ idx, _Missing ],
            Append[ entries, server ],
            ReplacePart[ entries, First @ idx -> server ]
        ];
        existing[ "mcpServers" ] = entries;

        (* Continue requires `name`, `version`, and `schema` at the top level of EVERY
           config.yaml (and every standalone block file under .continue/mcpServers/) -
           not just project-scope files. A file missing any of them fails schema
           validation and is silently ignored by Continue's CLI / IDE plugin, falling
           back to "Default Config" with no MCP servers visible. Only set defaults when
           the user hasn't already provided them; never overwrite a user-chosen value.
           The `name` default differs between scopes: project-scope block files in
           .continue/mcpServers/ are server-specific blocks, so the natural name is the
           server's display name; the global config.yaml is the user's main config and
           gets a neutral "Local Config" placeholder. *)
        projectScopeQ = MatchQ[
            ToLowerCase /@ FileNameSplit @ target,
            { ___, ".continue", "mcpservers", __ }
        ];
        If[ ! StringQ @ Lookup[ existing, "name", None ],
            existing[ "name" ] = If[ projectScopeQ, "Wolfram", "Local Config" ]
        ];
        If[ ! StringQ @ Lookup[ existing, "version", None ],
            existing[ "version" ] = "1.0.0"
        ];
        If[ ! StringQ @ Lookup[ existing, "schema", None ],
            existing[ "schema" ] = "v1"
        ];

        ConfirmBy[ exportYAML[ target, existing ], fileQ, "Export" ];

        clearStaleBuiltInRecords[ target, configName, obj ];
        ConfirmBy[ recordMCPInstallation[ target, obj ], FileExistsQ, "Record" ];

        installSuccess[ name, target, obj ]
    ],
    throwInternalFailure
];

(* Augment Code VS Code extension: mcpServers.json is a flat JSON array at the root,
   not an object with an "mcpServers" key. Each entry has its own "name" field. *)
installMCPServer[ target0_File, obj_MCPServerObject, env_Association, verifyLLMKit_, devMode_ ] /; $installClientName === "AugmentCodeIDE" := Enclose[
    Module[ { target, name, configName, json, data, server, convert, existing, idx },

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

        (* Convert to the VS Code extension's array-entry shape and stamp the display name *)
        convert = serverConverter @ $installClientName;
        server = ConfirmBy[ convert @ server, AssociationQ, "AugmentIDEServer" ];
        server = Prepend[ server, "name" -> configName ];

        (* Read existing array config (empty list if missing/empty) and upsert by name *)
        existing = ConfirmBy[ readExistingAugmentCodeIDEConfig @ target, ListQ, "Existing" ];
        idx = FirstPosition[ existing, KeyValuePattern @ { "name" -> configName }, Missing[ "NotFound" ] ];
        existing = If[ MatchQ[ idx, _Missing ],
            Append[ existing, server ],
            ReplacePart[ existing, First @ idx -> server ]
        ];

        ConfirmBy[ writeRawJSONFile[ target, existing ], FileExistsQ, "Export" ];
        ConfirmAssert[ readRawJSONFile @ target === existing, "ExportCheck" ];

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

(* When LLMKit is disabled for this installation ("EnableLLMKit" -> False), skip the requirement
   check entirely so no "subscribe to LLMKit" message or failure is issued -- the server will run
   with LLMKIT_ENABLED=false and the context tools will behave as if unsubscribed. *)
checkLLMKitRequirements[ obj_MCPServerObject ] /; $enableLLMKit === False :=
    None;

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
(*clearMCPInstallationRecord*)
(* Removes the installation records for a configuration file from a server's Installations.wxf by server name. Unlike
   clearRecordedInstallation, this never resolves the MCPServerObject (which could require network access or fail for
   a server that no longer exists), so it can be used when removing deployments. The file is deleted when no records
   remain. Returns the remaining records ({ } if there was no file). *)
clearMCPInstallationRecord // beginDefinition;

clearMCPInstallationRecord[ serverName_String, configFile: _File | _String ] := Enclose[
    Catch @ Module[ { target, file, existing, remaining },
        target = ConfirmBy[ expandConfigFile @ configFile, fileQ, "Target" ];
        file = ConfirmBy[ fileNameJoin[ mcpServerDirectory @ serverName, "Installations.wxf" ], fileQ, "File" ];
        If[ ! FileExistsQ @ file, Throw @ { } ];

        existing = Quiet @ readWXFFile @ file;
        If[ ! ListQ @ existing, Throw @ { } ];

        remaining = DeleteCases[ existing, _? (installationRecordFileQ[ #, target ] &) ];

        Which[
            remaining === { }, Quiet @ DeleteFile @ file,
            remaining =!= existing, ConfirmBy[ writeWXFFile[ file, remaining ], FileExistsQ, "Export" ]
        ];

        remaining
    ],
    throwInternalFailure
];

clearMCPInstallationRecord // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installationRecordFileQ*)
(* Whether an installation record refers to the given (expanded) configuration file. Legacy records are just the
   configuration file. *)
installationRecordFileQ // beginDefinition;
installationRecordFileQ[ KeyValuePattern[ "ConfigurationFile" -> file_ ], target_File ] := installationRecordFileQ[ file, target ];
installationRecordFileQ[ file: _File | _String, target_File ] := Quiet @ expandConfigFile @ file === target;
installationRecordFileQ[ _, _File ] := False;
installationRecordFileQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expandConfigFile*)
expandConfigFile // beginDefinition;
expandConfigFile[ file: _File | _String ] := File @ ExpandFileName @ file;
expandConfigFile // endDefinition;

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
        clientNames = Keys @ Select[ $SupportedClients, KeyExistsQ[ #, "InstallLocation" ] & ];
        client = SelectFirst[ clientNames, Quiet @ catchAlways @ installLocation @ # === file & ];
        If[ StringQ @ client, Throw @ client ];

        (* Try to guess from the file path for project-level installations *)
        split = ToLowerCase @ ConfirmMatch[ FileNameSplit @ file, { __String }, "Split" ];
        Switch[ split,
            { __, ".mcp.json" }, Throw[ "ClaudeCode" ],
            { __, "opencode.json" }, Throw[ "OpenCode" ],
            { __, ".vscode", "settings.json" | "mcp.json" }, Throw[ "VisualStudioCode" ],
            { __, ".kiro", "settings", "mcp.json" }, Throw[ "Kiro" ],
            { __, ".zed", "settings.json" }, Throw[ "Zed" ],
            { __, ".amazonq", "mcp.json" }, Throw[ "AmazonQ" ],
            { __, ".aws", "amazonq", "mcp.json" }, Throw[ "AmazonQ" ],
            { __, ".junie", "mcp", "mcp.json" }, Throw[ "Junie" ],
            { __, ".kimi", "mcp.json" }, Throw[ "KimiCode" ],
            { __, ".qwen", "settings.json" }, Throw[ "QwenCode" ],
            { __, ".continue", "config.yaml" }, Throw[ "Continue" ],
            { __, ".continue", "mcpservers", _ }, Throw[ "Continue" ],
            { __, ".lmstudio", "mcp.json" }, Throw[ "LMStudio" ],
            { __, "augment.vscode-augment", "augment-global-state", "mcpservers.json" }, Throw[ "AugmentCodeIDE" ]
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

        If[ $enableLLMKit === False,
            extraEnv = <| extraEnv, "LLMKIT_ENABLED" -> "false" |>
        ];

        (* An explicit "SubmitUsageData" -> True/False overrides the server's "EnableUsageData" property at startup *)
        If[ BooleanQ @ $submitUsageData,
            extraEnv = <| extraEnv, "SUBMIT_USAGE_DATA" -> If[ $submitUsageData, "true", "false" ] |>
        ];

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

configKeyPath[ name_String, _ ] /; KeyExistsQ[ $supportedClients, name ] :=
    $supportedClients[ name, "ConfigKey" ];

configKeyPath[ name_String ] /; KeyExistsQ[ $supportedClients, name ] :=
    $supportedClients[ name, "ConfigKey" ];

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
serverConverter[ name_String ] := Replace[ $supportedClients[ name, "ServerConverter" ], _Missing -> Identity ];
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
(*readExistingAugmentCodeIDEConfig*)
(* Array-rooted counterpart to readExistingMCPConfig, for the Augment Code VS Code
   extension's mcpServers.json. Returns an empty list when the target file is missing
   or empty, otherwise returns the parsed List. On any parse failure (or a top-level
   value that isn't a list) it issues InvalidMCPConfiguration so the caller never
   silently rewrites a file the user has been editing by hand. *)
readExistingAugmentCodeIDEConfig // beginDefinition;

readExistingAugmentCodeIDEConfig[ file_ ] := Enclose[
    Catch @ Module[ { data },
        If[ ! FileExistsQ @ file, Throw @ { } ];

        data = Quiet @ readRawJSONFile @ ExpandFileName @ file;

        If[ data === Missing[ "EmptyFile" ], Throw @ { } ];

        If[ ! ListQ @ data, throwFailure[ "InvalidMCPConfiguration", file ] ];

        data
    ],
    throwInternalFailure
];

readExistingAugmentCodeIDEConfig // endDefinition;

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
(* ::Subsection::Closed:: *)
(*readExistingContinueConfig*)
(* YAML reader for Continue, sharing the same shape contract as readExistingGooseConfig.
   Returns an empty mapping on missing/empty file, the parsed Association on success,
   and surfaces InvalidMCPConfiguration on any parse failure or non-mapping root so
   we never silently overwrite a user-edited file. *)
readExistingContinueConfig // beginDefinition;

readExistingContinueConfig[ file_ ] := Enclose[
    Catch @ Module[ { data },
        If[ ! FileExistsQ @ file, Throw @ <| |> ];

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

readExistingContinueConfig // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readExistingCodexConfig*)
(* TOML counterpart to readExistingMCPConfig for removing entries. The TOML reader is lenient, so the only failure is a
   file that can't be read as text (e.g. a directory or a file without read permission), which surfaces as
   InvalidMCPConfiguration instead of an internal failure. *)
readExistingCodexConfig // beginDefinition;

readExistingCodexConfig[ file_ ] := Enclose[
    Module[ { content },
        content = Quiet @ ReadString @ ExpandFileName @ file;
        If[ ! MatchQ[ content, _String | EndOfFile ], throwFailure[ "InvalidMCPConfiguration", file ] ];
        ConfirmBy[ readTOMLFile @ file, AssociationQ, "TOML" ]
    ],
    throwInternalFailure
];

readExistingCodexConfig // endDefinition;

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

uninstallMCPServer[ target0_File, obj_MCPServerObject ] := Enclose[
    Catch @ Module[ { target, name, configName, removed },

        target     = ConfirmBy[ expandConfigFile @ target0, fileQ, "Target" ];
        name       = ConfirmBy[ obj[ "Name" ], StringQ, "Name" ];
        configName = ConfirmBy[ resolveMCPServerName @ obj, StringQ, "ConfigName" ];

        removed = ConfirmMatch[
            removeMCPConfigEntry[ target, $installClientName, configName ],
            True | Missing[ "NotInstalled", _ ],
            "Remove"
        ];

        If[ MissingQ @ removed, Throw @ removed ];

        ConfirmMatch[ clearRecordedInstallation[ target, obj ], { ___Association }, "Clear" ];

        uninstallSuccess[ name, target, obj ]
    ],
    throwInternalFailure
];

uninstallMCPServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeMCPConfigEntry*)
(* Removes the entry with the given configuration key from a client's MCP configuration file, using the file format of
   the client (clientName is None for an unknown client, which uses the generic JSON format). This is shared by
   UninstallMCPServer and DeleteObject[ AgentToolsDeployment[ ... ] ], which only knows the recorded configuration key.
   Returns True if an entry was removed, or Missing[ "NotInstalled", file ] if the file or the entry doesn't exist (in
   which case nothing is written). Throws InvalidMCPConfiguration if the file can't be parsed, so a file that the user
   has been editing by hand is never rewritten. *)
removeMCPConfigEntry // beginDefinition;

removeMCPConfigEntry[ file_File, clientName: _String|None, configKey_String ] := Enclose[
    Module[ { target },
        target = ConfirmBy[ expandConfigFile @ file, fileQ, "Target" ];
        If[ FileExistsQ @ target,
            Block[ { $installClientName = toInstallName @ clientName },
                removeMCPConfigEntry0[ $installClientName, target, configKey ]
            ],
            Missing[ "NotInstalled", target ]
        ]
    ],
    throwInternalFailure
];

removeMCPConfigEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeMCPConfigEntry0*)
removeMCPConfigEntry0 // beginDefinition;

(* Codex: TOML file with servers under [mcp_servers.<name>] *)
removeMCPConfigEntry0[ "Codex", target_File, configKey_String ] := Enclose[
    Catch @ Module[ { existing, servers, updated },
        existing = ConfirmBy[ readExistingCodexConfig @ target, AssociationQ, "Existing" ];
        servers  = getMCPServers @ existing;

        If[ ! AssociationQ @ servers || ! KeyExistsQ[ servers, configKey ],
            Throw @ Missing[ "NotInstalled", target ]
        ];

        updated = ConfirmBy[ removeMCPServer[ existing, configKey ], AssociationQ, "UpdatedTOML" ];
        ConfirmBy[ writeTOMLFile[ target, updated[ "Data" ], updated ], fileQ, "Export" ];
        True
    ],
    throwInternalFailure
];

(* Augment Code VS Code extension: remove an entry matched by "name" from the root-level JSON array. *)
removeMCPConfigEntry0[ "AugmentCodeIDE", target_File, configKey_String ] := Enclose[
    Catch @ Module[ { existing, filtered },
        existing = ConfirmBy[ readExistingAugmentCodeIDEConfig @ target, ListQ, "Existing" ];
        filtered = DeleteCases[ existing, KeyValuePattern @ { "name" -> configKey } ];

        If[ Length @ filtered === Length @ existing, Throw @ Missing[ "NotInstalled", target ] ];

        ConfirmBy[ writeRawJSONFile[ target, filtered ], FileExistsQ, "Export" ];
        ConfirmAssert[ readRawJSONFile @ target === filtered, "ExportCheck" ];
        True
    ],
    throwInternalFailure
];

(* Continue: filter the `mcpServers` array by entry's `name` field (global config.yaml and project block files). *)
removeMCPConfigEntry0[ "Continue", target_File, configKey_String ] := Enclose[
    Catch @ Module[ { existing, entries, filtered },
        existing = ConfirmBy[ readExistingContinueConfig @ target, AssociationQ, "Existing" ];
        entries  = Lookup[ existing, "mcpServers", { } ];

        If[ ! ListQ @ entries, Throw @ Missing[ "NotInstalled", target ] ];

        filtered = DeleteCases[ entries, KeyValuePattern @ { "name" -> configKey } ];

        If[ Length @ filtered === Length @ entries, Throw @ Missing[ "NotInstalled", target ] ];

        existing[ "mcpServers" ] = filtered;
        ConfirmBy[ exportYAML[ target, existing ], fileQ, "Export" ];
        True
    ],
    throwInternalFailure
];

(* Goose: YAML file with servers under the `extensions` mapping. The file is read via the same helper as the install
   path so parse failures surface as InvalidMCPConfiguration rather than an internal failure, and the file is never
   rewritten. *)
removeMCPConfigEntry0[ "Goose", target_File, configKey_String ] := Enclose[
    Catch @ Module[ { existing, extensions },
        existing   = ConfirmBy[ readExistingGooseConfig @ target, AssociationQ, "Existing" ];
        extensions = Lookup[ existing, "extensions", <| |> ];

        If[ ! AssociationQ @ extensions || ! KeyExistsQ[ extensions, configKey ],
            Throw @ Missing[ "NotInstalled", target ]
        ];

        KeyDropFrom[ extensions, configKey ];
        existing[ "extensions" ] = extensions;

        ConfirmBy[ exportYAML[ target, existing ], fileQ, "Export" ];
        True
    ],
    throwInternalFailure
];

(* Everything else: JSON file with servers under the client's config key path (configKeyPath reads
   $installClientName, which also selects the legacy VS Code settings.json key path). *)
removeMCPConfigEntry0[ _, target_File, configKey_String ] := Enclose[
    Catch @ Module[ { existing, path },
        existing = ConfirmBy[ readExistingMCPConfig @ target, AssociationQ, "Existing" ];
        path     = ConfirmMatch[ configKeyPath @ target, { __String }, "ConfigKeyPath" ];

        With[ { keys = Sequence @@ path },
            If[ ! AssociationQ @ existing[ keys ], Throw @ Missing[ "NotInstalled", target ] ];
            If[ ! KeyExistsQ[ existing[ keys ], configKey ], Throw @ Missing[ "NotInstalled", target ] ];
            KeyDropFrom[ existing[ keys ], configKey ]
        ];

        ConfirmBy[ writeRawJSONFile[ target, existing ], FileExistsQ, "Export" ];
        ConfirmAssert[ readRawJSONFile @ target === existing, "ExportCheck" ];
        True
    ],
    throwInternalFailure
];

removeMCPConfigEntry0 // endDefinition;

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

        clientData = ConfirmMatch[ Lookup[ $SupportedClients, name, None ], _Association|None, "ClientData" ];

        (* "InstallLocation" is optional: a client might only support agent skills *)
        If[ clientData === None || ! KeyExistsQ[ clientData, "InstallLocation" ],
            throwFailure[ "UnsupportedMCPClient", name ]
        ];

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
        clientData = ConfirmMatch[ Lookup[ $SupportedClients, name, None ], _Association|None, "ClientData" ];
        If[ clientData === None || ! KeyExistsQ[ clientData, "InstallLocation" ],
            throwFailure[ "UnsupportedMCPClient", name ]
        ];
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
(* ::Subsection::Closed:: *)
(*skillsLocation*)
(* The user-scope agent skills root of a client (the directory that contains skill folders), from its "SkillsLocation",
   which has the same format as "InstallLocation". *)
skillsLocation // beginDefinition;

skillsLocation[ name_String ] := skillsLocation[ name, $OperatingSystem ];

skillsLocation[ name0_String, os0_String ] := Enclose[
    Module[ { name, os, clientData, locationSpec, path },

        name = ConfirmBy[ toInstallName @ name0, StringQ, "Name" ];
        os = ConfirmBy[ os0, StringQ, "OperatingSystem" ];

        clientData = ConfirmMatch[ Lookup[ $SupportedClients, name, None ], _Association|None, "ClientData" ];
        If[ clientData === None || ! KeyExistsQ[ clientData, "SkillsLocation" ],
            throwFailure[ "UnsupportedSkillsClient", name ]
        ];

        locationSpec = ConfirmMatch[ clientData[ "SkillsLocation" ], _Association|_List, "SkillsLocation" ];

        path = ConfirmMatch[
            If[ AssociationQ @ locationSpec, Lookup[ locationSpec, os, None ], locationSpec ],
            { __String }|None,
            "Path"
        ];

        If[ path === None, throwFailure[ "UnknownSkillsLocation", name, os ] ];

        ConfirmBy[ fileNameJoin @ path, fileQ, "Result" ]
    ],
    throwInternalFailure
];

skillsLocation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*projectSkillsLocation*)
(* The project-scope agent skills root of a client: the project directory joined with its "SkillsProjectPath". *)
projectSkillsLocation // beginDefinition;

projectSkillsLocation[ name0_String, dir_ ] := Enclose[
    Module[ { name, clientData, path },
        name = ConfirmBy[ toInstallName @ name0, StringQ, "Name" ];
        clientData = ConfirmMatch[ Lookup[ $SupportedClients, name, None ], _Association|None, "ClientData" ];
        path = If[ AssociationQ @ clientData, Lookup[ clientData, "SkillsProjectPath", None ], None ];
        If[ ! MatchQ[ path, { __String } ], throwFailure[ "UnsupportedSkillsClientProject", name ] ];
        If[ ! MatchQ[ dir, _String | _File? fileQ ], throwFailure[ "InvalidProjectDirectory", dir ] ];
        ConfirmBy[ fileNameJoin[ dir, path ], fileQ, "Result" ]
    ],
    throwInternalFailure
];

projectSkillsLocation // endDefinition;

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
installDisplayName[ name_String ] := Lookup[ $supportedClients, name, <| |> ][ "DisplayName" ] // Replace[ _Missing -> name ];
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
