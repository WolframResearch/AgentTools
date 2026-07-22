(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Server`Shared`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"          ];
Needs[ "Wolfram`AgentTools`Common`"   ];
Needs[ "Wolfram`AgentTools`Graphics`" ];
Needs[ "Wolfram`AgentTools`Server`"   ];

Needs[ "Wolfram`Chatbook`" -> "cb`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
(* Supported MCP protocol revisions, newest first; the preferred version is returned when the
   client requests an unsupported one (see negotiateProtocolVersion). Shared by both transports. *)
$supportedProtocolVersions = { "2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05" };
$preferredProtocolVersion  = "2025-11-25";
$waImageFetchTimeout       = 5; (* seconds, applied to the whole WA image batch via TaskWait *)
$clientName                = None;
$clientSupportsUI          = False;
$mcpEvaluation             = False;

$logTimeStamp := DateString[
    {
        "Year", "-", "Month", "-", "Day",
        "T",
        "Hour", ":", "Minute", ":", "Second", ".", "Millisecond",
        "Z"
    },
    TimeZone -> 0
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*parseToolOptions*)
parseToolOptions // beginDefinition;
parseToolOptions[ env_String ] := parseToolOptions0 @ Quiet @ Developer`ReadRawJSONString @ env;
parseToolOptions[ _ ] := <| |>;
parseToolOptions // endDefinition;


parseToolOptions0 // beginDefinition;

parseToolOptions0[ options_ ] := Enclose[
    If[ AssociationQ @ options,
        ConfirmBy[ Association @ KeyValueMap[ parseToolOptions0, options ], AssociationQ, "ToolOptions" ],
        <| |>
    ],
    throwInternalFailure
];

parseToolOptions0[ tool_String, opts_ ] := Enclose[
    If[ AssociationQ @ opts,
        tool -> ConfirmBy[
            DeleteMissing @ Association @ KeyValueMap[ parseToolOptions0[ tool, #1, #2 ] &, opts ],
            AssociationQ,
            "ToolOptions"
        ],
        Nothing
    ],
    throwInternalFailure
];

parseToolOptions0[ tool_String, optionName_String, optionValue_ ] :=
    optionName -> ReplaceAll[
        optionValue,
        (* Symbols that don't have a corresponding JSON representation: *)
        { "Automatic" -> Automatic, "None" -> None }
    ];

parseToolOptions0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*initializeServerState*)
(* Transport-agnostic build of the server's tool/prompt state, extracted from the local
   read-loop startup so both the stdio and cloud transports share it. The local server calls
   this once at startup and Blocks the returned values around its read loop; the cloud handler
   calls it per request. Callers must have bound $currentMCPServer (ensurePacletsForStart may
   reassign it for paclet-backed servers). *)
initializeServerState // beginDefinition;

initializeServerState[ obj0_MCPServerObject ] := Enclose[
    Module[ { obj, llmTools, toolList, promptList, promptLookup, toolOptions },

        (* Ensure referenced paclets are installed before tool/prompt resolution *)
        obj = ConfirmBy[ ensurePacletsForStart @ obj0, MCPServerObjectQ, "EnsurePacletsForStart" ];

        (* Run server-level initialization for custom and paclet-backed servers *)
        runServerInitialization @ obj;

        llmTools = disambiguateToolNames @ ConfirmMatch[ obj[ "Tools" ], { ___LLMTool }, "Tools" ];

        (* Run tool initialization for all tools at startup *)
        runToolInitialization @ Values @ llmTools;

        toolList     = ConfirmMatch[ KeyValueMap[ createMCPToolData, llmTools ], { ___Association }, "ToolList" ];
        promptList   = ConfirmMatch[ makePromptData @ obj[ "PromptData" ], { ___Association }, "PromptData" ];
        promptLookup = ConfirmBy[ makePromptLookup @ obj[ "PromptData" ], AssociationQ, "PromptLookup" ];

        initializeUIResources[ ];
        toolOptions = parseToolOptions @ Environment[ "MCP_TOOL_OPTIONS" ];

        <|
            "ToolList"     -> toolList,
            "LLMTools"     -> llmTools,
            "PromptList"   -> promptList,
            "PromptLookup" -> promptLookup,
            "ToolOptions"  -> toolOptions
        |>
    ],
    throwInternalFailure
];

initializeServerState // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ensurePacletsForStart*)
ensurePacletsForStart // beginDefinition;

ensurePacletsForStart[ obj_MCPServerObject ] :=
    ensurePacletsForStart[ obj, obj[ "Location" ] ];

(* For paclet-based servers, we need to ensure that the primary paclet and all dependencies are installed *)
ensurePacletsForStart[ obj_MCPServerObject, paclet_PacletObject ] := Enclose[
    Catch @ Module[ { location, installed, name, new },
        location = paclet[ "Location" ];

        (* Already installed? *)
        If[ DirectoryQ @ location, Throw @ ensureDependenciesForStart @ obj ];

        (* Install the paclet *)
        installed = ConfirmBy[ PacletInstall @ paclet, PacletObjectQ, "Installed" ];

        (* Generate a new server object with full metadata *)
        name = obj[ "Name" ];
        new = ConfirmBy[ MCPServerObject @ name, MCPServerObjectQ, "New" ];

        (* Ensure dependencies are installed too *)
        $currentMCPServer = ConfirmBy[ ensureDependenciesForStart @ new, MCPServerObjectQ, "EnsureDependencies" ]
    ],
    throwInternalFailure
];

(* For other servers, we just ensure dependencies are installed *)
ensurePacletsForStart[ obj_MCPServerObject, _ ] :=
    ensureDependenciesForStart @ obj;

ensurePacletsForStart // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ensureDependenciesForStart*)
(* Tools and prompts may be defined in other paclets, so we make sure they are all installed here *)
ensureDependenciesForStart // beginDefinition;

ensureDependenciesForStart[ obj_MCPServerObject ] := Enclose[
    Catch @ Module[ { names, qualified, parsed, paclets },

        names = ConfirmMatch[ Union[ obj[ "ToolNames" ], obj[ "PromptNames" ] ], { ___String }, "Names" ];
        qualified = Select[ names, pacletQualifiedNameQ ];
        If[ qualified === { }, Throw @ obj ];

        (* Get the list of paclet names that need to be installed *)
        parsed = ConfirmMatch[ parsePacletQualifiedName /@ qualified, { __Association }, "Parsed" ];
        paclets = ConfirmMatch[
            Union @ Cases[ parsed, KeyValuePattern[ "PacletName" -> name_String ] :> name ],
            { __String },
            "Paclets"
        ];

        (* PacletInstall is very fast for already installed paclets *)
        ConfirmMatch[ PacletInstall /@ paclets, { __PacletObject }, "Installed" ];

        obj
    ],
    throwInternalFailure
];

ensureDependenciesForStart // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*runServerInitialization*)
runServerInitialization // beginDefinition;

runServerInitialization[ obj_MCPServerObject ] :=
    runServerInitialization @ obj[ "Data" ];

runServerInitialization[ data_Association ] :=
    Catch @ Module[ { location, qualifiedName, serverDef },

        (* Run initialization specified via the Initialization option of CreateMCPServer: *)
        Lookup[ data, "Initialization", Null ];

        location = Lookup[ data, "Location" ];
        If[ ! MatchQ[ location, _PacletObject ], Throw @ Null ];

        qualifiedName = data[ "Name" ];
        If[ ! StringQ @ qualifiedName || ! pacletQualifiedNameQ @ qualifiedName,
            Throw @ Null
        ];

        (* Load server definition to access Initialization code *)
        serverDef = Quiet @ resolvePacletServer @ qualifiedName;
        If[ ! AssociationQ @ serverDef, Throw @ Null ];

        (* Initialization uses RuleDelayed, so accessing the key evaluates it *)
        Lookup[ serverDef, "Initialization", Null ]
    ];

runServerInitialization // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*runToolInitialization*)
runToolInitialization // beginDefinition;
runToolInitialization[ tools_List ] := runToolInitialization /@ tools;
runToolInitialization[ tool_LLMTool ] := runToolInitialization @ tool[ "Data" ];
runToolInitialization[ as_Association ] := Lookup[ as, "Initialization", Null ];
runToolInitialization[ _ ] := Null;
runToolInitialization // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*disambiguateToolNames*)
disambiguateToolNames // beginDefinition;

disambiguateToolNames[ { } ] := <| |>;

disambiguateToolNames[ tools: { __LLMTool } ] :=
    Module[ { names, nameCounts, usedNames, indices = <| |>, mcpName, suffix },
        names = #[ "Name" ] & /@ tools;
        nameCounts = Counts @ names;
        usedNames = Association[ # -> True & /@ DeleteDuplicates @ names ];
        Association @ Table[
            mcpName = names[[ i ]];
            If[ nameCounts[ mcpName ] > 1,
                indices[ mcpName ] = Lookup[ indices, mcpName, 0 ] + 1;
                suffix = indices[ mcpName ];
                While[ Lookup[ usedNames, mcpName <> ToString @ suffix, False ],
                    suffix++
                ];
                indices[ mcpName ] = suffix;
                usedNames[ mcpName <> ToString @ suffix ] = True;
                (mcpName <> ToString @ suffix) -> tools[[ i ]],
                mcpName -> tools[[ i ]]
            ],
            { i, Length @ tools }
        ]
    ];

disambiguateToolNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createMCPToolData*)
createMCPToolData // beginDefinition;

createMCPToolData[ tool: HoldPattern[ _LLMTool ] ] :=
    createMCPToolData[ tool[ "Name" ], tool ];

createMCPToolData[ mcpName_String, tool: HoldPattern[ _LLMTool ] ] := Enclose[
    Module[ { data, description, inputSchema, title, annotations },

        data = ConfirmBy[ tool[ "Data" ], AssociationQ, "Data" ];
        description = safeString @ ConfirmBy[ tool[ "Description" ], StringQ, "Description" ];
        inputSchema = ConfirmBy[ toolSchema @ tool, AssociationQ, "InputSchema" ];

        title = Lookup[ data, "DisplayName", Missing[ ] ];
        If[ StringQ @ title, title = safeString @ title ];

        annotations = If[ StringQ @ title, <| "title" -> title |>, Missing[ ] ];

        DeleteMissing @ <|
            "name"        -> safeString @ mcpName,
            "title"       -> title,
            "description" -> description,
            "inputSchema" -> inputSchema,
            "annotations" -> annotations
        |>
    ],
    throwInternalFailure
];

createMCPToolData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serverToolListData*)
(* The tool-list data for a server object, in the same shape tools/list returns (the $toolList that
   initializeServerState builds): each tool disambiguated, then passed through createMCPToolData. Unlike
   initializeServerState this runs no paclet install / server or tool initialization / UI setup -- it only
   reads tool metadata -- so it is safe to call purely to describe a server, e.g. for the cloud /api/info
   landing-page endpoint. Declared in the Server` context (Server.wl) so the cloud transport can reach it. *)
serverToolListData // beginDefinition;
serverToolListData[ obj_MCPServerObject ] := serverToolListData @ obj[ "Tools" ];
serverToolListData[ tools: { ___LLMTool } ] := KeyValueMap[ createMCPToolData, disambiguateToolNames @ tools ];
serverToolListData[ _ ] := { };
serverToolListData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolSchema*)
toolSchema // beginDefinition;

toolSchema[ tool: HoldPattern[ _LLMTool ] ] := Enclose[
    ReplaceAll[
        ReplaceAll[
            tool[ "JSONSchema" ],
            (* Make sure regex patterns are valid in JavaScript *)
            {
                (* The vast majority of patterns will just be the one that matches anything,
                   since it's the pattern produced by the basic "String" Interpreter.
                   We can safely drop it, since it's redundant. *)
                as: KeyValuePattern[ "pattern" -> "(?ms).*" ] :>
                    RuleCondition @ KeyDrop[ as, "pattern" ],

                (* For other patterns produced via `Interpreter[Restricted["String", pattern]]`,
                   we attempt to convert to JS-compatible format. *)
                as: KeyValuePattern[ "pattern" -> regex_String ] :>
                    RuleCondition @ <|
                        as,
                        "pattern" -> ConfirmBy[ toJSRegex @ regex, StringQ, "ToJSRegex" ]
                    |>
            }
        ],
        (* Make sure strings in schemas do not contain private-use characters *)
        s_String :> RuleCondition @ safeString @ s
    ],
    throwInternalFailure
];

toolSchema // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePromptLookup*)
makePromptLookup // beginDefinition;
makePromptLookup[ prompts: { ___Association } ] := Association[ #Name -> # & /@ prompts ];
makePromptLookup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePromptData*)
makePromptData // beginDefinition;
makePromptData[ prompts: { ___Association } ] := makePromptData0 /@ prompts;
makePromptData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePromptData0*)
makePromptData0 // beginDefinition;

makePromptData0[ prompt_Association ] := Enclose[
    Module[ { name, description, arguments },
        name = ConfirmBy[
            prompt[ "Name" ] /. _Missing :> prompt[ "name" ],
            StringQ,
            "Name"
        ];
        description = Replace[
            prompt[ "Description" ] /. _Missing :> prompt[ "description" ],
            Except[ _String ] :> ""
        ];
        arguments = Replace[
            prompt[ "Arguments" ] /. _Missing :> prompt[ "arguments" ],
            {
                args: { ___Association } :> normalizeArguments @ args,
                _ :> { }
            }
        ];
        <|
            "name"        -> name,
            "description" -> description,
            If[ Length @ arguments > 0, "arguments" -> arguments, Nothing ]
        |>
    ],
    throwInternalFailure
];

makePromptData0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*normalizeArguments*)
normalizeArguments // beginDefinition;
normalizeArguments[ args: { ___Association } ] := normalizeArgument /@ args;
normalizeArguments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*normalizeArgument*)
normalizeArgument // beginDefinition;

normalizeArgument[ arg_Association ] := <|
    "name"        -> (arg[ "Name" ] /. _Missing :> arg[ "name" ]),
    "description" -> (arg[ "Description" ] /. _Missing :> arg[ "description" ]) /. _Missing :> "",
    "required"    -> (arg[ "Required" ] /. _Missing :> arg[ "required" ]) /. _Missing :> False
|>;

normalizeArgument // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Method Dispatch*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handleMethod*)
handleMethod // beginDefinition;

handleMethod[ "initialize", msg_, req_ ] := (
    $clientName = Replace[ msg[[ "params", "clientInfo", "name" ]], Except[ _String ] :> None ];
    $clientSupportsUI = mcpAppsEnabledQ[ ] && clientSupportsUIQ @ msg;
    $clientSupportsRoots = ! MissingQ @ msg[ "params", "capabilities", "roots" ];
    If[ ! stderrEnabledQ[ ], $Messages = { } ];
    <| req, "result" -> initResponse[ $currentMCPServer, msg ] |>
);

handleMethod[ "ping"          , msg_, req_ ] := <| req, "result" -> <| |> |>;
handleMethod[ "resources/list", msg_, req_ ] := <| req, "result" -> <| "resources" -> listUIResources[ ] |> |>;
handleMethod[ "resources/read", msg_, req_ ] := handleResourceRead[ msg, req ];
handleMethod[ "prompts/list"  , msg_, req_ ] := <| req, "result" -> <| "prompts" -> $promptList |> |>;
handleMethod[ "prompts/get"   , msg_, req_ ] := <| req, "result" -> getPrompt[ msg, req ] |>;
handleMethod[ "tools/list"    , msg_, req_ ] := <| req, "result" -> <| "tools" -> withToolUIMetadata @ $toolList |> |>;
handleMethod[ "tools/call"    , msg_, req_ ] := <| req, "result" -> evaluateTool[ msg, req ] |>;

(* Notifications: dispatch to handleNotification, then drop the response *)
handleMethod[ method_String, msg_, req_ ] /; StringStartsQ[ method, "notifications/" ] := (
    handleNotification[ method, msg ];
    Null
);

handleMethod[ _, _, KeyValuePattern[ "id" -> Null ] ] := Null;

(* Unknown method *)
e: handleMethod[ method_, msg_, req_ ] := (
    writeError[ "Unhandled method: " <> ToString[ Unevaluated @ e, InputForm ] ];
    <| req, "error" -> <| "code" -> -32601, "message" -> "Unknown method" |> |>
);

handleMethod // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handleResourceRead*)
handleResourceRead // beginDefinition;

handleResourceRead[ msg_Association, req_ ] :=
    Module[ { result },
        result = catchAlways @ readUIResource[ msg, req ];
        If[ FailureQ @ result,
            <| req, "error" -> resourceReadError[ result, msg ] |>,
            <| req, "result" -> result |>
        ]
    ];

handleResourceRead // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceReadError*)
resourceReadError // beginDefinition;

(* Resource not found: invalid params (-32602) *)
resourceReadError[ failure: Failure[ _String? (StringEndsQ[ "::UIResourceNotFound" ]), _ ], msg_ ] :=
    <| "code" -> -32602, "message" -> resourceReadErrorMessage[ failure, msg ] |>;

(* Any other failure: internal error (-32603) *)
resourceReadError[ failure_Failure, msg_ ] :=
    <| "code" -> -32603, "message" -> resourceReadErrorMessage[ failure, msg ] |>;

resourceReadError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceReadErrorMessage*)
resourceReadErrorMessage // beginDefinition;

resourceReadErrorMessage[ failure_Failure, msg_ ] :=
    With[ { failureMsg = failure[ "Message" ] },
        If[ StringQ @ failureMsg, failureMsg, resourceReadErrorMessage[ msg ] ]
    ];

resourceReadErrorMessage[ msg_Association ] :=
    resourceReadErrorMessage @ Replace[ msg[[ "params", "uri" ]], Except[ _String ] :> "unknown" ];

resourceReadErrorMessage[ uri_String ] :=
    "UI resource not found: " <> uri;

resourceReadErrorMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPrompt*)
getPrompt // beginDefinition;

getPrompt[ msg_, req_ ] := getPrompt[ msg, req, $promptLookup ];

getPrompt[ msg_Association, req_Association, prompts_Association ] := Enclose[
    Module[ { params, name, arguments, promptData, content, messages },
        params = ConfirmBy[ Lookup[ msg, "params" ], AssociationQ, "Parameters" ];
        name = ConfirmBy[ Lookup[ params, "name" ], StringQ, "Name" ];
        arguments = ConfirmBy[ Lookup[ params, "arguments", <| |> ], AssociationQ, "Arguments" ];
        promptData = ConfirmBy[ Lookup[ prompts, name ], AssociationQ, "PromptData" ];
        content = makePromptContent[ promptData, arguments ];
        messages = { <| "role" -> "user", "content" -> content |> };
        <| "messages" -> messages |>
    ],
    throwInternalFailure
];

getPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*consolidateTextContent*)

(* Consolidates content arrays into a single text object for client compatibility.
   Extracts all text items and merges them. Non-text items (images) are dropped
   since many MCP clients don't support multimodal prompt responses. *)
consolidateTextContent // beginDefinition;

consolidateTextContent[ content: { __Association } ] :=
    Module[ { textItems },
        textItems = Select[ content, MatchQ[ #, KeyValuePattern[ "type" -> "text" ] ] & ];
        <| "type" -> "text", "text" -> StringJoin @ Lookup[ textItems, "text", "" ] |>
    ];

consolidateTextContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePromptContent*)
makePromptContent // beginDefinition;

(* Handle Function type - call the function with arguments *)
makePromptContent[ KeyValuePattern[ { "Type" -> "Function", "Content" -> func_ } ], arguments_ ] :=
    makePromptContent[ catchPromptFunction[ func, arguments ], arguments ];

(* Handle multimodal content - list of content items *)
(* Consolidate text-only arrays into a single text object for client compatibility *)
makePromptContent[ content: { __Association }, arguments_ ] :=
    consolidateTextContent @ content;

(* Handle structured content with "Content" key containing multimodal content *)
makePromptContent[ KeyValuePattern[ "Content" -> content: { __Association } ], arguments_ ] :=
    consolidateTextContent @ content;

(* Handle Text type with Content *)
makePromptContent[ KeyValuePattern[ "Content" -> content_ ], arguments_ ] :=
    makePromptContent[ content, arguments ];

(* Handle string content *)
makePromptContent[ content_String, arguments_ ] :=
    <| "type" -> "text", "text" -> content |>;

(* Handle template content *)
makePromptContent[ template_TemplateObject, arguments_Association ] :=
    makePromptContent[ TemplateApply[ template, arguments ], arguments ];

(* Fallback - convert to string *)
makePromptContent[ content_, arguments_ ] :=
    <| "type" -> "text", "text" -> ToString @ content |>;

makePromptContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*catchPromptFunction*)
catchPromptFunction // beginDefinition;

catchPromptFunction[ func_, arguments_ ] :=
    With[ { result = Quiet @ catchAlways @ func @ arguments },
        If[ FailureQ @ result,
            formatPromptError @ result,
            result
        ]
    ];

catchPromptFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatPromptError*)
formatPromptError // beginDefinition;

formatPromptError[ failure_Failure ] :=
    With[ { msg = failure[ "Message" ] },
        If[ StringQ @ msg,
            "[Error] " <> msg,
            "[Error] Failed to generate prompt content."
        ]
    ];

formatPromptError[ _ ] := "[Error] Failed to generate prompt content.";

formatPromptError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Evaluation and Result Formatting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*graphicsToImageContent*)
graphicsToImageContent // beginDefinition;

graphicsToImageContent[ g_ ] := Enclose[
    Module[ { img, png, base64 },
        (* Ensure it's an image, otherwise ExportByteArray may try to export an animated PNG, which is not desired *)
        img = If[ ImageQ @ g, g, Rasterize @ g ];
        png = ConfirmBy[ Quiet @ ExportByteArray[ img, "PNG" ], ByteArrayQ, "PNG" ];
        base64 = ConfirmBy[ BaseEncode @ png, StringQ, "Base64" ];
        <| "type" -> "image", "data" -> base64, "mimeType" -> "image/png" |>
    ],
    $Failed &  (* Return $Failed on failure *)
];

graphicsToImageContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeImageContent*)
makeImageContent // beginDefinition;

makeImageContent[
    URL[ url_String ],
    KeyValuePattern @ {
        "StatusCode"    -> 200,
        "BodyByteArray" -> bytes_ByteArray,
        "Headers"       -> KeyValuePattern[ "content-type" -> type_String ? (StringStartsQ[ "image/" ]) ]
    }
] := {
    <| "type" -> "text" , "text" -> "![Image](" <> url <> ")" |>,
    <| "type" -> "image", "data" -> BaseEncode @ bytes, "mimeType" -> type |>
};

makeImageContent[ URL[ url_String ], _ ] :=
    { <| "type" -> "text", "text" -> "![Image](" <> url <> ")" |> };

makeImageContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractWolframAlphaImages*)

(* Pattern for WolframAlpha image URLs in markdown *)
(* Matches: public6.wolframalpha.com, www6.wolframalpha.com, etc. *)
$$waImageURLPattern = Shortest[
    "![" ~~ Except[ "]" ]... ~~ "](" ~~
    url: ("https://" ~~ __ ~~ "wolframalpha.com/files/" ~~ __ ~~ (".gif"|".png"|".jpg"|".jpeg"|".webp"|".svg")) ~~
    ")"
];

extractWolframAlphaImages // beginDefinition;

(* When not running as an MCP server, we don't want to format for MCP outputs: *)
extractWolframAlphaImages[ str_String ] /; ! $mcpEvaluation := str;

extractWolframAlphaImages[ str_String ] := Enclose[
    Catch @ Module[ { parts, urls, fetched, tasks, replaced, contentItems },

        (* Split string into text segments and URL[..] tokens *)
        parts = StringSplit[ str, $$waImageURLPattern :> URL[ url ] ];
        urls  = Cases[ parts, _URL ];

        (* If no images found, return plain text for backward compatibility *)
        If[ urls === { }, Throw @ str ];

        (* Pre-fill every URL with a text-only fallback so a timeout still yields the markdown link *)
        fetched = AssociationMap[ <| "type" -> "text", "text" -> "![Image](" <> First @ # <> ")" |> &, urls ];

        (* Submit all URLs concurrently; each handler overwrites its slot in `fetched` on success.
           The outer Function captures the URL in a closure so each handler knows its own key. *)
        tasks = Function[ u,
            URLSubmit[
                u,
                HandlerFunctions     -> <| "BodyReceived" -> Function[ fetched[ u ] = makeImageContent[ u, # ] ] |>,
                HandlerFunctionsKeys -> { "StatusCode", "BodyByteArray", "Headers" }
            ]
        ] /@ urls;

        (* Bound the whole batch, not each request *)
        TaskWait[ tasks, TimeConstraint -> $waImageFetchTimeout ];
        Quiet[ TaskRemove /@ tasks ];

        replaced = Flatten @ Replace[
            parts,
            {
                ""       :> Nothing,
                s_String :> <| "type" -> "text", "text" -> s |>,
                u_URL    :> fetched[ u ]
            },
            { 1 }
        ];

        (* Merge runs of adjacent text items into one *)
        contentItems = SequenceReplace[
            replaced,
            { as: KeyValuePattern[ "type" -> "text" ].. } :>
                <| "type" -> "text", "text" -> StringJoin @ Lookup[ { as }, "text" ] |>
        ];

        If[ MatchQ[ contentItems, { __Association } ],
            <| "Content" -> contentItems |>,
            str  (* Fallback to plain string *)
        ]
    ],
    str &  (* On any error, return original string *)
];

extractWolframAlphaImages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractImageContent*)
extractImageContent // beginDefinition;

extractImageContent[ g_? graphicsQ ] :=
    With[ { img = graphicsToImageContent @ g },
        If[ AssociationQ @ img, { img }, { } ]
    ];

extractImageContent[ list_List ] := Flatten[ extractImageContent /@ list, 1 ];
extractImageContent[ as_Association ] := extractImageContent @ Values @ as;
extractImageContent[ _Failure ] := { };
extractImageContent[ _String  ] := { };
extractImageContent[ _        ] := { };

extractImageContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resultToContent*)
resultToContent // beginDefinition;

resultToContent[ result_ ] := Enclose[
    Module[ { textContent, imageContents },
        textContent = <| "type" -> "text", "text" -> ConfirmBy[ safeString @ result, StringQ ] |>;
        imageContents = ConfirmMatch[ extractImageContent @ result, { ___Association } ];
        Flatten @ { textContent, imageContents }
    ],
    throwInternalFailure
];

resultToContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*evaluateTool*)
evaluateTool // beginDefinition;

evaluateTool[ msg_, req_ ] := Enclose[
    Catch @ Module[ { params, toolName, args, tool, result, content, toolResultAssoc },
        Quiet @ TaskRemove @ $warmupTask; (* We're in a tool call, so it no longer makes sense to warm up tools *)
        writeLog[ "ToolCall" -> msg ];
        params = ConfirmBy[ Lookup[ msg, "params", <| |> ], AssociationQ ];
        toolName = ConfirmBy[ Lookup[ params, "name" ], StringQ ];
        args = Lookup[ params, "arguments", <| |> ];

        (* Check if the tool exists before calling it *)
        tool = Lookup[ $llmTools, toolName, Missing[ "UnknownTool", toolName ] ];
        If[ MissingQ @ tool,
            Throw @ <|
                "content" -> { <| "type" -> "text", "text" -> "[Error] Unknown tool: " <> toolName |> },
                "isError" -> True
            |>
        ];

        result = stealthCatchTop @ tool @ args;

        content = Which[
            (* Structured result with Content key (from WolframLanguageEvaluator) *)
            AssociationQ @ result && KeyExistsQ[ result, "Content" ],
                result[ "Content" ],

            (* Legacy: result has String key *)
            StringQ @ result[ "String" ],
                resultToContent @ result[ "String" ],

            (* Default: auto-detect graphics *)
            True,
                resultToContent @ result
        ];

        toolResultAssoc = <| "content" -> ConfirmMatch[ content, { __Association } ], "isError" -> FailureQ @ result |>;

        (* Forward _meta from structured tool results (e.g. notebookUrl for MCP Apps). We deliberately
           do not forward structuredContent: some clients discard the content (text/images) entirely
           when structuredContent is present, so the notebookUrl travels via _meta (and the content
           marker fallback) only. *)
        If[ AssociationQ @ result && AssociationQ @ result[ "_meta" ],
            toolResultAssoc[ "_meta" ] = result[ "_meta" ]
        ];

        toolResultAssoc
    ],
    throwInternalFailure
];

evaluateTool // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*safeString*)
safeString // beginDefinition;

(* Special handling for internal failures - format cleanly for MCP output *)
safeString[ failure: Failure[ "AgentTools::Internal" | "General::ChatbookInternal", _ ] ] :=
    With[ { formatted = formatInternalFailureForMCP @ failure },
        formatted /; StringQ @ formatted
    ];

safeString[ failure_Failure ] := With[ { s = failure[ "Message" ] }, "[Error] " <> safeString @ s /; StringQ @ s ];
safeString[ string_String ] := convertPUACharacters @ string; (* avoid mangling due to StandardForm strings *)
safeString[ arg_ ] := convertPUACharacters @ ToString @ Unevaluated @ arg;
safeString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertPUACharacters*)
(* Characters in the Unicode private use area (0xE000-0xF8FF) *)
$$puaCharacter = RegularExpression[ "[\\x{E000}-\\x{F8FF}]" ];

convertPUACharacters // beginDefinition;
convertPUACharacters[ str_String ] /; StringFreeQ[ str, $$puaCharacter ] := str;
convertPUACharacters[ str_String ] := StringJoin[ convertPUACharacters /@ ToCharacterCode @ str ];
convertPUACharacters[ n_Integer ] /; 57344 <= n <= 63743 := toPrintableASCII @ FromCharacterCode @ n;
convertPUACharacters[ n_Integer ] := FromCharacterCode @ n;
convertPUACharacters // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toPrintableASCII*)
toPrintableASCII // beginDefinition;
toPrintableASCII[ expr_ ] := ToString[ Unevaluated @ expr, CharacterEncoding -> "PrintableASCII" ];
toPrintableASCII // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sanitizeResponse*)
(* Applies convertPUACharacters to every string in an outgoing message (a response or a
   server-to-client request) before it is encoded as JSON.
   Sanitizing must happen before JSON encoding: the converted output can contain backslash
   sequences or raw control characters, which would corrupt an already-encoded JSON document. *)
sanitizeResponse // beginDefinition;
sanitizeResponse[ response_Association ] := KeyMap[ sanitizeResponse, sanitizeResponse /@ response ];
sanitizeResponse[ list_List ] := sanitizeResponse /@ list;
sanitizeResponse[ string_String ] := convertPUACharacters @ string;
sanitizeResponse[ other_ ] := other;
sanitizeResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Capability / Initialization*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initResponse*)
initResponse // beginDefinition;

initResponse[ obj_MCPServerObject ] :=
    initResponse[ obj[ "Name" ], obj[ "ServerVersion" ], obj[ "Tools" ], obj[ "Prompts" ] ];

initResponse[ obj_MCPServerObject, clientMsg_Association ] :=
    initResponse[ obj[ "Name" ], obj[ "ServerVersion" ], obj[ "Tools" ], obj[ "Prompts" ], clientMsg ];

initResponse[ name_String, version_String, tools0: { ___LLMTool }, prompts_ ] :=
    initResponse[ name, version, tools0, prompts, <| |> ];

initResponse[ name_String, version_String, tools0: { ___LLMTool }, prompts_, clientMsg_Association ] := Enclose[
    Module[ { tools, instructions },
        tools = If[ Length @ tools0 > 0, <| "listChanged" -> True |>, <| |> ];
        instructions = ConfirmMatch[ makeInstructions @ prompts, _Missing | _String, "Instructions" ];
        DeleteMissing @ <|
            "protocolVersion" -> negotiateProtocolVersion @ clientMsg,
            "instructions"    -> instructions,
            "capabilities" -> <|
                "prompts" -> <| |>,
                "tools" -> tools,
                If[ TrueQ @ $clientSupportsUI,
                    "extensions" -> <|
                        "io.modelcontextprotocol/ui" -> <|
                            "mimeTypes" -> { "text/html;profile=mcp-app" }
                        |>
                    |>,
                    Nothing
                ]
            |>,
            "serverInfo" -> <| "name" -> name, "version" -> version |>
        |>
    ],
    throwInternalFailure
];

initResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*negotiateProtocolVersion*)
(* Echo the client's requested protocol version when we support it, otherwise fall back to the
   preferred version. A missing/malformed request also yields the preferred version. Per the MCP
   lifecycle rules: https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle *)
negotiateProtocolVersion // beginDefinition;

negotiateProtocolVersion[ clientMsg_Association ] :=
    negotiateProtocolVersion @ clientMsg[ "params", "protocolVersion" ];

negotiateProtocolVersion[ version_String ] /; MemberQ[ $supportedProtocolVersions, version ] :=
    version;

negotiateProtocolVersion[ _ ] := $preferredProtocolVersion;

negotiateProtocolVersion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeInstructions*)
makeInstructions // beginDefinition;

makeInstructions[ { } | "" ] :=
    Missing[ "NotAvailable" ];

makeInstructions[ prompt_String ] :=
    makeInstructions @ { prompt };

makeInstructions[ prompts: { __String } ] :=
    StringRiffle[ prompts, "\n\n" ];

makeInstructions[ prompts: { (_String|_TemplateObject)... } ] :=
    makeInstructions @ Select[
        Replace[
            prompts,
            t_TemplateObject :> TemplateApply @ t,
            { 1 }
        ],
        StringQ
    ];

makeInstructions[ _ ] :=
    Missing[ "NotAvailable" ];

makeInstructions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Logging Helpers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeLog*)
writeLog // beginDefinition;
writeLog[ expr_ ] := writeLog[ expr, $logFile ];
writeLog[ expr_, File[ file_String ] ] := PutAppend[ expr, file ];
writeLog[ expr_, _ ] := Null;
writeLog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stderrEnabledQ*)
(* stderr output causes issues with several clients, so we disable it unless we know it's safe to use *)
stderrEnabledQ // beginDefinition;
stderrEnabledQ[ ] := stderrEnabledQ @ $clientName;
stderrEnabledQ[ "claude-ai" ] := True;
stderrEnabledQ[ _ ] := False;
stderrEnabledQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeError*)
writeError // beginDefinition;

writeError[ args___ ] /; stderrEnabledQ[ ] :=
    With[ { time = $logTimeStamp },
        WriteLine[ "stderr", sequenceString[ time, " [Wolfram/AgentTools] [error] ", args ] ]
    ];

writeError[ ___ ] := Null;

writeError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*debugEcho*)
debugEcho // beginDefinition;
debugEcho[ expr_ ] := (debugPrint @ Unevaluated @ expr; expr);
debugEcho // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*debugPrint*)
debugPrint // beginDefinition;

debugPrint[ args___ ] /; stderrEnabledQ[ ] :=
    With[ { time = $logTimeStamp },
        WriteLine[ "stderr", sequenceString[ time, " [Wolfram/AgentTools] [info] ", args ] ]
    ];

debugPrint[ ___ ] := Null;

debugPrint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sequenceString*)
sequenceString // beginDefinition;
sequenceString // Attributes = { HoldAll };
sequenceString[ args___ ] := ToString @ Unevaluated @ SequenceForm @ args;
sequenceString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
