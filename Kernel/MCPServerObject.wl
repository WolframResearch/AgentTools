(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`MCPServerObject`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

$ContextAliases[ "cb`" ] = "Wolfram`Chatbook`";
$ContextAliases[ "sp`" ] = "System`Private`";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$defaultCommandLineArguments = {
    "-run",
    "PacletSymbol[\"Wolfram/AgentTools\",\"Wolfram`AgentTools`StartMCPServer\"][]",
    "-noinit",
    "-noprompt"
};

$$transport = "StandardInputOutput" | "HTTP" | "ServerSentEvents";

$$metadata = KeyValuePattern @ {
    "LLMEvaluator"  -> _Association? AssociationQ,
    "Location"      -> _File? fileQ | "BuiltIn" | None | _PacletObject,
    "Name"          -> _String? StringQ,
    "ObjectVersion" -> _Integer? IntegerQ,
    "ServerVersion" -> _String? StringQ,
    "Transport"     -> $$transport
};

$$installation = KeyValuePattern @ {
    "ClientName"        -> _String? StringQ | None,
    "ConfigurationFile" -> _? fileQ
};

$defaultMetadata := <|
    "LLMEvaluator"  -> Automatic,
    "Name"          -> CreateUUID[ ],
    "ObjectVersion" -> $objectVersion,
    "ServerVersion" -> $serverVersion,
    "Transport"     -> "StandardInputOutput"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*MCPServerObject*)
MCPServerObject // ClearAll;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Main Definition*)
MCPServerObject[ data_Association ]? sp`HoldNotValidQ :=
    catchTop[ createMCPServerObject @ data, MCPServerObject ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createMCPServerObject*)
createMCPServerObject // beginDefinition;

createMCPServerObject[ data_Association ] := Enclose[
    With[ { valid = validateMCPServerObjectData @ data },
        If[ AssociationQ @ valid,
            sp`HoldSetValid @ MCPServerObject @ valid,
            throwFailure[ "InvalidArguments", MCPServerObject, HoldForm @ MCPServerObject @ data ]
        ]
    ],
    throwInternalFailure
];

createMCPServerObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validateMCPServerObjectData*)
validateMCPServerObjectData // beginDefinition;

validateMCPServerObjectData[ data_Association? AssociationQ ] :=
    Module[ { valid, combined },
        valid = Association @ KeyValueMap[ validateMCPServerObjectData0, data ];
        combined = <| $defaultMetadata, valid |>;
        If[ MatchQ[ combined, $$metadata ], combined, $Failed ]
    ];

validateMCPServerObjectData[ _ ] :=
    $Failed;

validateMCPServerObjectData // endDefinition;


validateMCPServerObjectData0 // beginDefinition;
validateMCPServerObjectData0 // Attributes = { HoldAllComplete };
validateMCPServerObjectData0[ "Initialization", init_ ] := validateInitialization @ init;
validateMCPServerObjectData0[ "LLMEvaluator", config_ ] := "LLMEvaluator" -> validateLLMEvaluator @ config;
validateMCPServerObjectData0[ key_String, value_ ] := key -> value;
validateMCPServerObjectData0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validateInitialization*)
validateInitialization // beginDefinition;
validateInitialization // Attributes = { HoldAllComplete };
validateInitialization[ HoldComplete[ init_ ] ] := validateInitialization @ init;
validateInitialization[ None  ] := "Initialization" -> None;
validateInitialization[ init_ ] := "Initialization" :> init;
validateInitialization // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validateLLMEvaluator*)
validateLLMEvaluator // beginDefinition;

validateLLMEvaluator[ Automatic ] :=
    validateLLMEvaluator @ Symbol[ "System`$LLMEvaluator" ];

validateLLMEvaluator[ HoldPattern @ LLMConfiguration[ config_ ] ] :=
    validateLLMEvaluator @ config;

validateLLMEvaluator[ config_Association? AssociationQ ] :=
    Association @ KeyValueMap[ #1 -> validateLLMEvaluator0[ #1, #2 ] &, config ];

validateLLMEvaluator // endDefinition;


validateLLMEvaluator0 // beginDefinition;
validateLLMEvaluator0[ "Tools", tools_ ] := validateTools @ tools;
validateLLMEvaluator0[ "MCPPrompts", prompts_ ] := validateMCPPrompts @ prompts;
validateLLMEvaluator0[ key_String, value_ ] := value;
validateLLMEvaluator0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validateTools*)
validateTools // beginDefinition;

validateTools[ tool_LLMTool ] := validateTools @ { tool };
validateTools[ tool_String  ] := validateTools @ { tool };

validateTools[ tools_List ] :=
    With[ { v = validateTool /@ Flatten @ { tools } },
        Flatten @ { tools } /; MatchQ[ v, { (_LLMTool | _String)... } ]
    ];

validateTools[ tools_ ] :=
    throwFailure[ "InvalidToolsSpecification", tools ];

validateTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validateTool*)
validateTool // beginDefinition;
validateTool[ tool_LLMTool ] := tool;
validateTool[ name_String ] /; pacletQualifiedNameQ @ name := name;
validateTool[ tool_String ] := convertStringTools @ tool;
validateTool[ tool_TemplateObject ] := TemplateApply @ tool;
validateTool[ other_ ] := throwFailure[ "InvalidToolSpecification", other ];
validateTool // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validateMCPPrompts*)
validateMCPPrompts // beginDefinition;

validateMCPPrompts[ prompt_String ] :=
    validateMCPPrompts @ { prompt };

validateMCPPrompts[ prompts_List ] :=
    With[ { v = validateMCPPrompt /@ Flatten @ { prompts } },
        Flatten @ { prompts } /; MatchQ[ v, { (_Association | _String)... } ]
    ];

validateMCPPrompts[ prompts_ ] :=
    throwFailure[ "InvalidMCPPromptsSpecification", prompts ];

validateMCPPrompts // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validateMCPPrompt*)
validateMCPPrompt // beginDefinition;
validateMCPPrompt[ prompt_Association ] := prompt;
validateMCPPrompt[ name_String ] /; pacletQualifiedNameQ @ name := name;
validateMCPPrompt[ name_String ] /; KeyExistsQ[ $DefaultMCPPrompts, name ] := name;
validateMCPPrompt[ name_String ] := throwFailure[ "PromptNameNotFound", name ];
validateMCPPrompt[ other_ ] := throwFailure[ "InvalidMCPPromptSpecification", other ];
validateMCPPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Get MCP Server by Name*)
MCPServerObject[ name_String ] := catchMine @ getMCPServerObjectByName @ name;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getMCPServerObjectByName*)
getMCPServerObjectByName // beginDefinition;

getMCPServerObjectByName[ name_String ] := Enclose[
    Catch @ Module[ { file, data },
        file = ConfirmBy[ mcpServerFile @ name, fileQ, "File" ];
        If[ ! FileExistsQ @ file,
            Throw @ If[ pacletQualifiedNameQ @ name,
                checkPacletMCPServer @ name,
                checkBuiltInMCPServer @ name
            ]
        ];
        data = readMetadataFile @ file;
        If[ ! AssociationQ @ data, throwFailure[ "MCPServerNotFound", name ] ];
        ConfirmBy[ MCPServerObject @ data, MCPServerObjectQ, "MCPServerObject" ]
    ],
    throwInternalFailure
];

getMCPServerObjectByName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkBuiltInMCPServer*)
checkBuiltInMCPServer // beginDefinition;

checkBuiltInMCPServer[ name_String ] :=
    With[ { server = $DefaultMCPServers[ name ] },
        If[ MCPServerObjectQ @ server,
            server,
            throwFailure[ "MCPServerNotFound", name ]
        ]
    ];

checkBuiltInMCPServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkPacletMCPServer*)
checkPacletMCPServer // beginDefinition;

checkPacletMCPServer[ qualifiedName_String ] := Enclose[
    Module[ { parsed, pacletName, serverName, paclet, serverDef, metadata },
        parsed = ConfirmBy[ parsePacletQualifiedName @ qualifiedName, AssociationQ, "Parse" ];
        pacletName = parsed[ "PacletName" ];
        serverName = parsed[ "ItemName" ];

        (* Try installed paclet first *)
        paclet = findInstalledPaclet @ pacletName;
        If[ MatchQ[ paclet, _PacletObject ]
            ,
            (* Installed: load the server definition file *)
            serverDef = resolvePacletServer @ qualifiedName;
            If[ ! AssociationQ @ serverDef, throwFailure[ "PacletServerNotFound", serverName, pacletName ] ];

            metadata = buildPacletServerMetadata[ qualifiedName, paclet, serverDef ];
            ConfirmBy[ MCPServerObject @ metadata, MCPServerObjectQ, "MCPServerObject" ]
            ,

            (* Not installed: try remote metadata only *)
            checkRemotePacletMCPServer[ qualifiedName, pacletName, serverName ]
        ]
    ],
    throwInternalFailure
];

checkPacletMCPServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buildPacletServerMetadata*)
buildPacletServerMetadata // beginDefinition;

buildPacletServerMetadata[ qualifiedName_String, paclet_PacletObject, serverDef_Association ] :=
    <|
        "LLMEvaluator"  -> Lookup[ serverDef, "LLMEvaluator", <| |> ],
        "Location"      -> paclet,
        "MCPServerName" -> Lookup[ serverDef, "MCPServerName", Last @ StringSplit[ qualifiedName, "/" ] ],
        "Name"          -> qualifiedName,
        "ObjectVersion" -> $objectVersion,
        "ServerVersion" -> Lookup[ serverDef, "ServerVersion", paclet[ "Version" ] ],
        "Transport"     -> Lookup[ serverDef, "Transport", "StandardInputOutput" ]
    |>;

buildPacletServerMetadata // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkRemotePacletMCPServer*)
checkRemotePacletMCPServer // beginDefinition;

checkRemotePacletMCPServer[ qualifiedName_String, pacletName_String, serverName_String ] :=
    Module[ { remote, paclet, declaredServers, metadata },
        remote = Quiet @ PacletFindRemote[ pacletName, <| "Extension" -> "AgentTools" |> ];
        If[ ! MatchQ[ remote, { __PacletObject } ], throwFailure[ "MCPServerNotFound", qualifiedName ] ];

        paclet = First @ remote;
        declaredServers = Quiet @ catchAlways @ getAgentToolsDeclaredItems[ paclet, "MCPServers" ];
        If[ ! MemberQ[ declaredServers, serverName ], throwFailure[ "MCPServerNotFound", qualifiedName ] ];

        metadata = buildRemotePacletServerMetadata[ qualifiedName, paclet, serverName ];
        MCPServerObject @ metadata
    ];

checkRemotePacletMCPServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buildRemotePacletServerMetadata*)
buildRemotePacletServerMetadata // beginDefinition;

buildRemotePacletServerMetadata[ qualifiedName_String, paclet_PacletObject, serverName_String ] :=
    Module[ { extData, serverDecl, tools, prompts, evaluator },

        extData = Quiet @ getAgentToolsExtensionData @ paclet;

        serverDecl = If[ AssociationQ @ extData,
            SelectFirst[
                Lookup[ extData, "MCPServers", { } ],
                MatchQ[ #, serverName | { serverName, _ } | KeyValuePattern[ "Name" -> serverName ] ] &
            ],
            Missing[ "NotAvailable" ]
        ];

        tools = If[ MatchQ[ serverDecl, _Association ] && KeyExistsQ[ serverDecl, "Tools" ],
            serverDecl[ "Tools" ],
            getAgentToolsDeclaredItems[ paclet, "Tools" ]
        ];

        prompts = If[ MatchQ[ serverDecl, _Association ] && KeyExistsQ[ serverDecl, "MCPPrompts" ],
            serverDecl[ "MCPPrompts" ],
            getAgentToolsDeclaredItems[ paclet, "MCPPrompts" ]
        ];

        evaluator = qualifyNamesInLLMEvaluator[ <| "Tools" -> tools, "MCPPrompts" -> prompts |>, paclet[ "Name" ] ];

        <|
            "LLMEvaluator"  -> evaluator,
            "Location"      -> paclet,
            "MCPServerName" -> If[ MatchQ[ serverDecl, _Association ],
                                   Lookup[ serverDecl, "MCPServerName", serverName ],
                                   serverName
                               ],
            "Name"          -> qualifiedName,
            "ObjectVersion" -> $objectVersion,
            "ServerVersion" -> paclet[ "Version" ],
            "Transport"     -> "StandardInputOutput"
        |>
    ];

buildRemotePacletServerMetadata // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Get MCP Server by Location*)
MCPServerObject[ location_File ] := catchMine @ getMCPServerObjectByLocation @ location;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getMCPServerObjectByLocation*)
getMCPServerObjectByLocation // beginDefinition;

getMCPServerObjectByLocation[ dir_File? directoryQ ] :=
    getMCPServerObjectByLocation @ fileNameJoin[ dir, "Metadata.wxf" ];

getMCPServerObjectByLocation[ file_File ] := Enclose[
    Module[ { data },
        data = ConfirmBy[ readMetadataFile @ file, validMetadataQ, "Metadata" ];
        ConfirmBy[ MCPServerObject @ data, MCPServerObjectQ, "MCPServerObject" ]
    ],
    throwInternalFailure
];

getMCPServerObjectByLocation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*readMetadataFile*)
readMetadataFile // beginDefinition;

readMetadataFile[ file_File ] := Enclose[
    Module[ { data },
        If[ ! FileExistsQ @ file, throwFailure[ "InvalidMCPServerFile", file ] ];
        data = Developer`ReadWXFFile @ ExpandFileName @ file;
        If[ ! validMetadataQ @ data, throwFailure[ "InvalidMCPServerFile", file ] ];
        data
    ],
    throwInternalFailure
];

readMetadataFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validMetadataQ*)
validMetadataQ // beginDefinition;
validMetadataQ[ $$metadata ] := True;
validMetadataQ[ _ ] := False;
validMetadataQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Flat*)
MCPServerObject[ obj_MCPServerObject ] := catchMine[
    If[ MCPServerObjectQ @ obj,
        obj,
        throwFailure[ "DeletedMCPServerObject", obj[ "Name" ] ]
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ensureMCPServerExists*)
ensureMCPServerExists // beginDefinition;

ensureMCPServerExists[ obj_MCPServerObject ] :=
    If[ MCPServerObjectQ @ obj,
        obj,
        throwFailure[ "DeletedMCPServerObject", obj[ "Name" ] ]
    ];

ensureMCPServerExists // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Properties*)
MCPServerObject[ KeyValuePattern[ prop_ -> value_ ] ][ prop_String ] :=
    value;

(MCPServerObject[ data_Association ]? MCPServerObjectQ)[ prop: _String | { ___String } ] :=
    catchTop[ getMCPServerObjectProperty[ data, prop ], MCPServerObject ];

(obj_MCPServerObject)[ prop: _String | { ___String } ] :=
    catchTop[ getMCPServerObjectProperty[ ensureMCPServerExists @ obj, prop ], MCPServerObject ];

_MCPServerObject[ invalid_ ] :=
    catchTop[ throwFailure[ "InvalidProperty", invalid ], MCPServerObject ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getMCPServerObjectProperty*)
getMCPServerObjectProperty // beginDefinition;

getMCPServerObjectProperty[ MCPServerObject[ data_Association ], prop_ ] :=
    getMCPServerObjectProperty[ data, prop ];

(* Special properties *)
getMCPServerObjectProperty[ data_Association, "Data"              ] := data;
getMCPServerObjectProperty[ data_Association, "LLMConfiguration"  ] := makeLLMConfiguration @ data;
getMCPServerObjectProperty[ data_Association, "PromptData"        ] := getPromptData @ data;
getMCPServerObjectProperty[ data_Association, "PromptNames"       ] := getPromptNames @ data;
getMCPServerObjectProperty[ data_Association, "Tools"             ] := getToolList @ data;
getMCPServerObjectProperty[ data_Association, "ToolNames"         ] := getToolNames @ data;
getMCPServerObjectProperty[ data_Association, "JSONConfiguration" ] := makeJSONConfiguration @ data;
getMCPServerObjectProperty[ data_Association, "Installations"     ] := getInstallations @ data;
getMCPServerObjectProperty[ data_Association, "Properties"        ] := getProperties @ data;

(* Standard properties *)
getMCPServerObjectProperty[ KeyValuePattern[ key_ -> value_ ], key_ ] := value;
getMCPServerObjectProperty[ KeyValuePattern[ "LLMEvaluator" -> KeyValuePattern[ prop_ -> value_ ] ], prop_ ] := value;

(* Property list *)
getMCPServerObjectProperty[ data_Association, props: { ___String } ] :=
    AssociationMap[ getMCPServerObjectProperty[ data, # ] &, props ];

(* Unknown property *)
getMCPServerObjectProperty[ _, prop_ ] := Missing[ "UnknownProperty", prop ];
getMCPServerObjectProperty // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getProperties*)
getProperties // beginDefinition;
getProperties[ data_Association ] := Union[ Keys @ data, Keys @ data[ "LLMEvaluator" ], $specialProperties ];
getProperties // endDefinition;

$specialProperties = {
    "Data",
    "Installations",
    "JSONConfiguration",
    "LLMConfiguration",
    "PromptData",
    "PromptNames",
    "Properties",
    "ToolNames",
    "Tools"
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getInstallations*)
getInstallations // beginDefinition;

getInstallations[ data_Association ] := Enclose[
    ConfirmMatch[ mcpServerInstallations @ data, { $$installation... }, "Installations" ],
    throwInternalFailure
];

getInstallations // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPromptData*)
getPromptData // beginDefinition;

(* Check for new property first *)
getPromptData[ as_Association ] :=
    getPromptData[ as, as[ "LLMEvaluator", "MCPPrompts" ], as[ "LLMEvaluator", "PromptData" ] ];

(* MCPPrompts takes precedence *)
getPromptData[ as_, prompts: { (_String | _Association)... }, _ ] :=
    normalizePromptData /@ prompts;

(* No MCPPrompts, check for deprecated PromptData *)
getPromptData[ as_, _, prompts: { ___Association } ] :=
    throwFailure[ "DeprecatedPromptData" ];

(* Neither property exists - return empty *)
getPromptData[ as_, _, _ ] := { };

getPromptData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*normalizePromptData*)
normalizePromptData // beginDefinition;

normalizePromptData[ name_String ] /; KeyExistsQ[ $DefaultMCPPrompts, name ] :=
    $DefaultMCPPrompts[ name ];

normalizePromptData[ name_String ] /; pacletQualifiedNameQ[ name ] :=
    normalizePromptData @ resolvePacletPrompt[ name ];

normalizePromptData[ name_String ] :=
    throwFailure[ "PromptNameNotFound", name ];

normalizePromptData[ as_Association ] := Enclose[
    Module[ { type },
        type = ConfirmBy[ determinePromptType @ as, StringQ, "Type" ];
        <| as, "Type" -> type |>
    ],
    throwInternalFailure
];

normalizePromptData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*determinePromptType*)
determinePromptType // beginDefinition;
determinePromptType[ KeyValuePattern[ "Type" -> "Function" ] ] := "Function";
determinePromptType[ KeyValuePattern[ "Type" -> "Text" ] ] := "Text";
determinePromptType[ KeyValuePattern[ "Type" -> Automatic ] ] := determinePromptType @ <| |>;
determinePromptType[ KeyValuePattern[ "Content" -> _String ] ] := "Text";
determinePromptType[ KeyValuePattern[ "Content" -> _TemplateObject ] ] := "Text";
determinePromptType[ KeyValuePattern[ "Content" -> _ ] ] := "Function";
determinePromptType[ _ ] := "Text";
determinePromptType // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolList*)
getToolList // beginDefinition;

getToolList[ as_Association ] := getToolList[ as, as[ "Location" ] ];

getToolList[ as_Association, paclet_PacletObject ] /; ! DirectoryQ @ paclet[ "Location" ] :=
    With[ { pn = paclet[ "Name" ] },
        throwFailure[ "PacletNotInstalled", pn, HoldForm @ PacletInstall @ pn ]
    ];

getToolList[ as_Association, _ ] := Enclose[
    ConfirmMatch[
        toLLMTools @ as[ "LLMEvaluator" ][ "Tools" ],
        { ___LLMTool },
        "GetToolList"
    ],
    throwInternalFailure
];

getToolList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolNames*)
getToolNames // beginDefinition;

getToolNames[ as_Association ] := getToolNames[ as, as[ "Location" ] ];

getToolNames[ as_Association, _PacletObject ] :=
    Replace[ as[ "LLMEvaluator", "Tools" ], _Missing -> { } ];

getToolNames[ as_Association, _ ] :=
    Replace[
        as[ "LLMEvaluator", "Tools" ],
        {
            tools_List :> Replace[
                tools,
                { s_String :> s, tool_LLMTool :> tool[ "Name" ], _ :> Nothing },
                { 1 }
            ],
            _ -> { }
        }
    ];

getToolNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPromptNames*)
getPromptNames // beginDefinition;

getPromptNames[ as_Association ] := getPromptNames[ as, as[ "Location" ] ];

getPromptNames[ as_Association, _PacletObject ] :=
    Replace[ as[ "LLMEvaluator", "MCPPrompts" ], _Missing -> { } ];

getPromptNames[ as_Association, _ ] :=
    Replace[
        as[ "LLMEvaluator", "MCPPrompts" ],
        {
            prompts_List :> Replace[
                prompts,
                { s_String :> s, as2_Association :> Lookup[ as2, "Name", Nothing ], _ :> Nothing },
                { 1 }
            ],
            _ -> { }
        }
    ];

getPromptNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toLLMTools*)
toLLMTools // beginDefinition;

toLLMTools[ _Missing ] := { };

toLLMTools[ tools_ ] := Replace[
    convertStringTools @ Flatten @ { tools },
    t_TemplateObject :> TemplateApply @ t,
    { 1 }
];

toLLMTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeJSONConfiguration*)
makeJSONConfiguration // beginDefinition;

makeJSONConfiguration[ data_Association ] := Enclose[
    Module[ { name, env, cmd, config, full },
        name = ConfirmBy[ data[ "Name" ], StringQ, "Name" ];
        env = <| "MCP_SERVER_NAME" -> name, ConfirmBy[ defaultEnvironment[ ], AssociationQ, "Environment" ] |>;
        cmd = ConfirmBy[ getWolframCommand[ ], StringQ, "WolframCommand" ];
        config = <| "type" -> "stdio", "command" -> cmd, "args" -> $defaultCommandLineArguments, "env" -> env |>;
        full = <| "mcpServers" -> <| name -> config |> |>;
        ConfirmBy[ Developer`WriteRawJSONString @ full, StringQ, "JSONConfiguration" ]
    ],
    throwInternalFailure
];

makeJSONConfiguration // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getWolframCommand*)
getWolframCommand // beginDefinition;
getWolframCommand[           ] := getWolframCommand @ $OperatingSystem;
getWolframCommand[ "Windows" ] := FileNameJoin @ { $InstallationDirectory, "wolfram.exe" };
getWolframCommand[ "MacOSX"  ] := FileNameJoin @ { $InstallationDirectory, "MacOS", "wolfram" };
getWolframCommand[ "Unix"    ] := FileNameJoin @ { $InstallationDirectory, "Executables", "wolfram" };
getWolframCommand[ os_String ] := throwFailure[ "UnsupportedOperatingSystem", os ];
getWolframCommand // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeLLMConfiguration*)
makeLLMConfiguration // beginDefinition;
makeLLMConfiguration[ data_Association ] := makeLLMConfiguration[ data, convertStringTools @ data[ "LLMEvaluator" ] ];
makeLLMConfiguration[ _, evaluator_Association ] := LLMConfiguration @ evaluator;
makeLLMConfiguration // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertStringTools*)
convertStringTools // beginDefinition;

convertStringTools[ as: KeyValuePattern[ "Tools" -> tools_ ] ] :=
    <| as, "Tools" -> convertStringTools @ Flatten @ { tools } |>;

convertStringTools[ tools_List ] :=
    convertStringTools0 /@ Flatten @ { tools };

convertStringTools[ tool_String ] :=
    convertStringTools0 @ tool;

convertStringTools[ other_ ] :=
    other;

convertStringTools // endDefinition;


convertStringTools0 // beginDefinition;
convertStringTools0[ name_String ] /; KeyExistsQ[ $DefaultMCPTools, name ] := $DefaultMCPTools[ name ];
convertStringTools0[ name_String ] /; pacletQualifiedNameQ @ name := convertPacletTool @ resolvePacletTool @ name;
convertStringTools0[ name_String ] := Lookup[ cb`$AvailableTools, name, tryResourceTool @ name ];
convertStringTools0[ template_TemplateObject ] := TemplateApply @ template;
convertStringTools0[ tool_ ] := tool;
convertStringTools0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertPacletTool*)
convertPacletTool // beginDefinition;
convertPacletTool[ tool_LLMTool      ] := tool;
convertPacletTool[ as_Association    ] := LLMTool @ as;
convertPacletTool[ $Failed           ] := $Failed;
convertPacletTool // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tryResourceTool*)
tryResourceTool // beginDefinition;
tryResourceTool[ name_String ] := tryResourceTool[ name, Quiet @ Block[ { PrintTemporary }, LLMResourceTool @ name ] ];
tryResourceTool[ name_String, tool_TemplateObject ] := tryResourceTool[ name, Quiet @ TemplateApply @ tool ];
tryResourceTool[ name_String, tool_LLMTool ] := tool;
tryResourceTool[ name_String, other_ ] := throwFailure[ "ToolNameNotFound", name ];
tryResourceTool // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UpValues*)
MCPServerObject /: DeleteObject[ obj_MCPServerObject ] := catchTop[
    deleteMCPServer @ ensureMCPServerExists @ obj,
    MCPServerObject
];

MCPServerObject /: LLMConfiguration[ obj_MCPServerObject ] := catchTop[
    ensureMCPServerExists[ obj ][ "LLMConfiguration" ],
    MCPServerObject
];

(* CloudDeploy of an MCPServerObject deploys the full directory bundle (the live /mcp endpoint, landing page,
   and owner-only admin page) and returns the directory CloudObject. The implementation -- cloudDeployDirectory
   and its helpers -- lives in Server/Cloud.wl (declared shared in CommonSymbols.wl). *)
MCPServerObject /: CloudDeploy[ obj_MCPServerObject, args___ ] := catchTop[
    cloudDeployDirectory[ obj, args ],
    MCPServerObject
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deleteMCPServer*)
deleteMCPServer // beginDefinition;

deleteMCPServer[ obj_ ] /; MatchQ[ obj[ "Location" ], _PacletObject ] :=
    deleteMCPServer[ obj[ "Name" ], obj[ "Location" ] ];

deleteMCPServer[ obj_ ] := (
    UninstallMCPServer @ obj;
    deleteMCPServer[ obj[ "Name" ], obj[ "Location" ] ]
);

deleteMCPServer[ name_, "BuiltIn" ] :=
    throwFailure[ "DeleteBuiltInMCPServer", name ];

deleteMCPServer[ name_, paclet_PacletObject ] :=
    With[ { pn = paclet[ "Name" ] },
        throwFailure[ "DeletePacletMCPServer", name, HoldForm @ PacletUninstall @ pn ]
    ];

deleteMCPServer[ name_, location_File ] := Enclose[
    If[ DirectoryQ @ location,
        ConfirmMatch[ DeleteDirectory[ location, DeleteContents -> True ], Null, "Delete" ];
        ConfirmAssert[ ! FileExistsQ @ location, "Verify" ];
        Null,
        throwFailure[ "MCPServerFileNotFound", name, location ]
    ],
    throwInternalFailure
];

deleteMCPServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Formatting*)
MCPServerObject /: MakeBoxes[ obj_MCPServerObject? sp`HoldValidQ, fmt_ ] :=
    With[ { boxes = Quiet @ catchAlways @ makeMCPServerObjectBoxes[ obj, fmt ] },
        boxes /; MatchQ[ boxes, _InterpretationBox ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Handling*)
MCPServerObject[ args___ ]? sp`HoldNotValidQ := catchTop[
    throwFailure[
        "InvalidArguments",
        MCPServerObject,
        HoldForm @ MCPServerObject @ args
    ],
    MCPServerObject
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*MCPServerObjectQ*)
MCPServerObjectQ // beginDefinition;
MCPServerObjectQ[ obj_MCPServerObject ] := sp`HoldValidQ @ obj && mcpServerExistsQ @ obj;
MCPServerObjectQ[ _ ] := False;
MCPServerObjectQ // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mcpServerExistsQ*)
mcpServerExistsQ // beginDefinition;
mcpServerExistsQ[ HoldPattern @ MCPServerObject[ as_Association ] ] := mcpServerExistsQ[ as, as[ "Location" ] ];
mcpServerExistsQ[ as_, "BuiltIn" ] := True;
mcpServerExistsQ[ as_, None ] := True; (* A purely in-memory server *)
mcpServerExistsQ[ as_, location_File ] := FileExistsQ @ location;

mcpServerExistsQ[ as_, paclet_PacletObject ] := MemberQ[
    paclet[ "StructuredExtensions" ],
    { "AgentTools", KeyValuePattern[ "MCPServers" -> { __ } ] }
];

mcpServerExistsQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*MCPServerObjects*)
MCPServerObjects // beginDefinition;

MCPServerObjects // Options = {
    "IncludeBuiltIn"       -> False,
    "IncludeRemotePaclets" -> False,
    UpdatePacletSites      -> Automatic
};

MCPServerObjects[ pattern: (All | _String? StringQ) : All, opts: OptionsPattern[ ] ] :=
    catchMine @ mcpServerObjects[
        pattern,
        TrueQ @ OptionValue[ "IncludeBuiltIn" ],
        TrueQ @ OptionValue[ "IncludeRemotePaclets" ],
        OptionValue[ UpdatePacletSites ]
    ];

MCPServerObjects // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mcpServerObjects*)
mcpServerObjects // beginDefinition;

mcpServerObjects[ pattern_, includeBuiltIn_, includeRemote_, updateSites_ ] := Enclose[
    Module[ { fileBased, pacletServers, builtIn, remote, all },
        fileBased = getFileBasedServers @ pattern;
        pacletServers = getInstalledPacletServers @ pattern;
        builtIn = If[ includeBuiltIn, getBuiltInServers @ pattern, { } ];
        remote = If[ includeRemote, getRemotePacletServers[ pattern, updateSites ], { } ];
        all = Join[ fileBased, pacletServers, builtIn, remote ];
        DeleteDuplicatesBy[ all, #[ "Name" ] & ]
    ],
    throwInternalFailure
];

mcpServerObjects // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getFileBasedServers*)
getFileBasedServers // beginDefinition;

getFileBasedServers[ All ] :=
    getFileBasedServers @ Select[ FileNames[ All, $storagePath ], DirectoryQ ];

getFileBasedServers[ pattern_String? StringQ ] :=
    getFileBasedServers @ Select[
        FileNames[ StringReplace[ URLEncode @ pattern, "%2A" -> "*", IgnoreCase -> True ], $storagePath ],
        DirectoryQ
    ];

getFileBasedServers[ dirs: { ___String } ] :=
    Select[ Quiet @ catchAlways @ MCPServerObject @ File[ # ] & /@ dirs, MCPServerObjectQ ];

getFileBasedServers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getInstalledPacletServers*)
getInstalledPacletServers // beginDefinition;

getInstalledPacletServers[ pattern_ ] :=
    Catch @ Module[ { paclets, servers },
        paclets = Quiet @ findAgentToolsPaclets[ ];
        If[ ! MatchQ[ paclets, { __PacletObject } ], Throw @ { } ];
        servers = Flatten[ installedPacletToServers /@ paclets ];
        filterServersByPattern[ servers, pattern ]
    ];

getInstalledPacletServers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installedPacletToServers*)
installedPacletToServers // beginDefinition;

installedPacletToServers[ paclet_PacletObject ] :=
    Catch @ Module[ { pacletName, declaredServers },
        pacletName = paclet[ "Name" ];
        declaredServers = Quiet @ getAgentToolsDeclaredItems[ paclet, "MCPServers" ];
        If[ ! ListQ @ declaredServers, Throw @ { } ];
        Select[
            Quiet @ catchAlways @ MCPServerObject[ pacletName <> "/" <> # ] & /@ declaredServers,
            MCPServerObjectQ
        ]
    ];

installedPacletToServers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getBuiltInServers*)
getBuiltInServers // beginDefinition;
getBuiltInServers[ All ] := Values @ $DefaultMCPServers;
getBuiltInServers[ pattern_String ] := Select[ Values @ $DefaultMCPServers, StringMatchQ[ #[ "Name" ], pattern ] & ];
getBuiltInServers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getRemotePacletServers*)
getRemotePacletServers // beginDefinition;

getRemotePacletServers[ pattern_, updateSites_ ] :=
    Catch @ Module[ { remotePaclets, installedNames, uninstalledPaclets, servers },
        remotePaclets = Quiet @ findRemoteAgentToolsPaclets[ updateSites ];
        If[ ! MatchQ[ remotePaclets, { __PacletObject } ], Throw @ { } ];
        installedNames = Quiet[ #[ "Name" ] & /@ findAgentToolsPaclets[ ] ] /. Except[ { __String } ] -> { };
        uninstalledPaclets = Select[ remotePaclets, !MemberQ[ installedNames, #[ "Name" ] ] & ];
        servers = Flatten[ remotePacletToServers /@ uninstalledPaclets ];
        filterServersByPattern[ servers, pattern ]
    ];

getRemotePacletServers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*remotePacletToServers*)
remotePacletToServers // beginDefinition;

remotePacletToServers[ paclet_PacletObject ] :=
    Catch @ Module[ { pacletName, declaredServers },
        pacletName = paclet[ "Name" ];
        declaredServers = Quiet @ getAgentToolsDeclaredItems[ paclet, "MCPServers" ];
        If[ ! ListQ @ declaredServers, Throw @ { } ];
        Function[ serverName,
            MCPServerObject @ buildRemotePacletServerMetadata[
                pacletName <> "/" <> serverName,
                paclet,
                serverName
            ]
        ] /@ declaredServers
    ];

remotePacletToServers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*filterServersByPattern*)
filterServersByPattern // beginDefinition;
filterServersByPattern[ servers_List, All ] := servers;
filterServersByPattern[ servers_List, pattern_String ] := Select[ servers, StringMatchQ[ #[ "Name" ], pattern ] & ];
filterServersByPattern // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
