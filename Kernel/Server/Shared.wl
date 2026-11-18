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
(* Supported MCP protocol revisions, newest first. Shared by both transports.
   "Modern" revisions (2026-07-28 and later) are stateless: every request carries its protocol version and the client's
   capabilities in _meta, and there is no initialize handshake. "Legacy" revisions (2025-11-25 and earlier) negotiate a
   version with initialize. The server supports both eras (see handleRequest): an initialize request selects legacy
   semantics, and any other request that carries a modern version in _meta is served statelessly. *)
$modernProtocolVersions    = { "2026-07-28" };
$legacyProtocolVersions    = { "2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05" };
$supportedProtocolVersions = Join[ $modernProtocolVersions, $legacyProtocolVersions ];
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
(*Tool Options JSON*)
(* Tool options are passed from InstallMCPServer to the server as JSON in the MCP_TOOL_OPTIONS environment variable.
   Values that JSON can't represent are written as their InputForm with this prefix, so that they can't be confused with
   strings: the symbol None is written as "_wl_None", but the string "None" as "None". A string value that itself
   starts with the prefix would be read back as an expression, which isn't expected to happen in practice. *)
$expressionPrefix = "_wl_";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolOptionsJSONString*)
toolOptionsJSONString // beginDefinition;

toolOptionsJSONString[ options_Association ] :=
    Developer`WriteRawJSONString[ options, "Compact" -> True, "ConversionFunction" -> toolOptionExpressionString ];

toolOptionsJSONString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolOptionExpressionString*)
toolOptionExpressionString // beginDefinition;
toolOptionExpressionString // Attributes = { HoldAllComplete };
toolOptionExpressionString[ expr_ ] := $expressionPrefix <> ToString[ Unevaluated @ expr, InputForm ];
toolOptionExpressionString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
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

(* Values that JSON can't represent were written with $expressionPrefix (see toolOptionsJSONString): *)
parseToolOptions0[ tool_String, optionName_String, optionValue_ ] :=
    optionName -> ReplaceAll[
        optionValue,
        s_String /; StringStartsQ[ s, $expressionPrefix ] :>
            ToExpression[ StringDrop[ s, StringLength @ $expressionPrefix ], InputForm ]
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

        llmTools = withLicenseTool @ disambiguateToolNames @ applyToolOverrides @ ConfirmMatch[
            obj[ "Tools" ],
            { ___LLMTool },
            "Tools"
        ];

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
(*applyToolOverrides*)
(* Merge a tool's environment-specific "Overrides" into its data. The value is typically a delayed rule
   that inspects $MCPEvaluationEnvironment / $MCPTransport (bound by each transport before the server
   state is built) and yields an association of tool properties to replace -- or an empty association /
   None for no change. Whole properties are replaced (e.g. the entire "Parameters" list), the "Overrides"
   key itself is kept, and applying twice is a no-op. The LLMTool pattern must be held: an unheld
   LLMTool[ as_Association, opts___ ] evaluates (LLMTool::argrx) while the definition is being made. *)
applyToolOverrides // beginDefinition;

applyToolOverrides[ { } ] := { };

applyToolOverrides[ tools: { __LLMTool } ] := applyToolOverrides /@ tools;

applyToolOverrides[ HoldPattern @ LLMTool[ as_Association, opts___ ] ] := Enclose[
    Module[ { overrides },
        overrides = ConfirmBy[
            Replace[ Lookup[ as, "Overrides", <| |> ], None -> <| |> ],
            AssociationQ,
            "Overrides"
        ];
        LLMTool[ <| as, overrides |>, opts ]
    ],
    throwInternalFailure
];

applyToolOverrides // endDefinition;

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
(*withLicenseTool*)
(* A server running under the standalone MCP server's time-limited license gets the WolframLicenseStatus tool, unless
   it already lists a tool by that name (see Tools/LicenseStatus.wl). *)
withLicenseTool // beginDefinition;

withLicenseTool[ tools_Association ] /; licenseStatus[ ] =!= None && ! KeyExistsQ[ tools, $licenseToolName ] :=
    Append[ tools, $licenseToolName -> $DefaultMCPTools[ $licenseToolName ] ];

withLicenseTool[ tools_Association ] := tools;

withLicenseTool // endDefinition;

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
   initializeServerState builds): each tool has its environment overrides applied (applyToolOverrides, so
   the caller's $MCPEvaluationEnvironment / $MCPTransport bindings are honored), is disambiguated, then
   passed through createMCPToolData. Unlike initializeServerState this runs no paclet install / server or
   tool initialization / UI setup -- it only reads tool metadata -- so it is safe to call purely to
   describe a server, e.g. for the cloud /api/info landing-page endpoint. Declared in the Server` context
   (Server.wl) so the cloud transport can reach it. *)
serverToolListData // beginDefinition;
serverToolListData[ obj_MCPServerObject ] := serverToolListData @ obj[ "Tools" ];
serverToolListData[ tools: { ___LLMTool } ] := KeyValueMap[ createMCPToolData, disambiguateToolNames @ applyToolOverrides @ tools ];
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
(*Request Handling*)
(* The entry point used by both transports for every incoming message. A legacy message is dispatched to handleMethod
   as is, and the client information it relies on was stored by the legacy initialize request. A modern request
   carries that information itself (in _meta), so it is validated, dispatched with the client information bound for
   just this request, and its result is completed with the fields that modern results carry. *)
$metaPrefix = "io.modelcontextprotocol/";

(* Methods that only exist in the modern protocol, which are modern requests even without the _meta fields: *)
$modernOnlyMethods = { "server/discover" };

(* Results of these methods are cacheable and must carry caching hints (ttlMs and cacheScope). The tool, prompt, and
   resource lists only change when a server is redeployed (cloud) or restarted (local), but a client should not use a
   stale list for long after a redeployment. The "private" scope keeps shared caches (e.g. gateways) from serving a
   private cloud deployment's results to other callers. *)
$cacheableMethods = {
    "server/discover",
    "tools/list",
    "prompts/list",
    "resources/list",
    "resources/templates/list",
    "resources/read"
};

$cacheTTL   = 300000; (* milliseconds *)
$cacheScope = "private";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*handleRequest*)
handleRequest // beginDefinition;
handleRequest[ method_, msg_, req_ ] /; modernRequestQ[ method, msg ] := handleModernRequest[ method, msg, req ];
handleRequest[ method_, msg_, req_ ] := handleMethod[ method, msg, req ];
handleRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*modernRequestQ*)
(* A message is a modern request when it carries a protocol version in _meta that is not a legacy one (an unsupported
   version included, so that it gets UnsupportedProtocolVersionError), or when it calls a modern-only method. An
   initialize request always selects legacy semantics. Notifications (messages without an id) are not requests: they
   carry no per-request _meta fields and must never get a response. *)
modernRequestQ // beginDefinition;
modernRequestQ[ "initialize", _ ] := False;
modernRequestQ[ _, Except[ KeyValuePattern[ "id" -> Except[ Null ] ] ] ] := False;
modernRequestQ[ method_String, _ ] /; MemberQ[ $modernOnlyMethods, method ] := True;
modernRequestQ[ _, msg_ ] := modernVersionQ @ requestMetaValue[ msg, "protocolVersion" ];
modernRequestQ // endDefinition;

modernVersionQ // beginDefinition;
modernVersionQ[ _Missing ] := False;
modernVersionQ[ version_ ] := ! MemberQ[ $legacyProtocolVersions, version ];
modernVersionQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*requestMetaValue*)
(* The value of one of the io.modelcontextprotocol/ fields of a request's _meta, e.g. "protocolVersion" *)
requestMetaValue // beginDefinition;
requestMetaValue[ msg_, name_String ] := Lookup[ requestMeta @ msg, $metaPrefix <> name, Missing[ "NotFound" ] ];
requestMetaValue // endDefinition;

requestMeta // beginDefinition;
requestMeta[ KeyValuePattern[ "params" -> KeyValuePattern[ "_meta" -> meta_Association ] ] ] := meta;
requestMeta[ _ ] := <| |>;
requestMeta // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*handleModernRequest*)
handleModernRequest // beginDefinition;

handleModernRequest[ method_, msg_, req_ ] :=
    With[ { error = modernRequestError @ msg },
        If[ AssociationQ @ error,
            <| req, "error" -> error |>,
            withModernClient[ msg, completeModernResponse[ method, handleMethod[ method, msg, req ] ] ]
        ]
    ];

handleModernRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*modernRequestError*)
(* The JSON-RPC error for a modern request whose required _meta fields are missing or name a protocol version that is
   not supported, or None for a valid request. The cloud transport also uses this to choose the HTTP status. *)
modernRequestError // beginDefinition;

modernRequestError[ msg_ ] :=
    modernRequestError[ requestMetaValue[ msg, "protocolVersion" ], requestMetaValue[ msg, "clientCapabilities" ] ];

modernRequestError[ version_String, _ ] /; ! MemberQ[ $modernProtocolVersions, version ] :=
    unsupportedProtocolVersionError @ version;

modernRequestError[ _String, _Association ] :=
    None;

modernRequestError[ _String, _ ] :=
    invalidRequestMetaError[ "clientCapabilities" ];

modernRequestError[ _, _ ] :=
    invalidRequestMetaError[ "protocolVersion" ];

modernRequestError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unsupportedProtocolVersionError*)
unsupportedProtocolVersionError // beginDefinition;

unsupportedProtocolVersionError[ version_ ] := <|
    "code"    -> -32022,
    "message" -> "Unsupported protocol version",
    "data"    -> <| "supported" -> $supportedProtocolVersions, "requested" -> version |>
|>;

unsupportedProtocolVersionError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*invalidRequestMetaError*)
invalidRequestMetaError // beginDefinition;

invalidRequestMetaError[ name_String ] := <|
    "code"    -> -32602,
    "message" -> "Invalid params: missing or invalid _meta field " <> $metaPrefix <> name
|>;

invalidRequestMetaError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withModernClient*)
(* Binds the client information of a modern request for its evaluation, so that nothing carries over from other
   requests (or from a legacy initialize in the same process). The spec says the client's self-reported identity should
   not change the server's behavior, so stderr logging (see stderrEnabledQ) stays off, as for unrecognized legacy
   clients. The server never sends requests of its own to a modern client (server-to-client requests were replaced by
   multi round-trip requests), so roots are not requested (the Roots feature is deprecated as of 2026-07-28). *)
withModernClient // beginDefinition;
withModernClient // Attributes = { HoldRest };

withModernClient[ msg_, eval_ ] :=
    Block[
        {
            $clientName          = None,
            $clientSupportsUI    = mcpAppsEnabledQ[ ] && clientSupportsUIQ @ requestMetaValue[ msg, "clientCapabilities" ],
            $clientSupportsRoots = False
        },
        eval
    ];

withModernClient // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*completeModernResponse*)
(* Every modern result has a resultType ("complete": this server never needs further input from the client) and the
   server's identity in its _meta, and the results of cacheable methods have caching hints. Errors, notifications (a
   Null response), and failures are returned as they are. *)
completeModernResponse // beginDefinition;

completeModernResponse[ method_, response: KeyValuePattern[ "result" -> result_Association ] ] :=
    <| response, "result" -> completeModernResult[ method, result ] |>;

completeModernResponse[ method_, response_ ] :=
    response;

completeModernResponse // endDefinition;


completeModernResult // beginDefinition;

completeModernResult[ method_, result_Association ] := <|
    "resultType" -> "complete",
    result,
    If[ MemberQ[ $cacheableMethods, method ], <| "ttlMs" -> $cacheTTL, "cacheScope" -> $cacheScope |>, <| |> ],
    "_meta" -> <|
        Replace[ Lookup[ result, "_meta", <| |> ], Except[ _Association ] :> <| |> ],
        $metaPrefix <> "serverInfo" -> serverInfo @ $currentMCPServer
    |>
|>;

completeModernResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Method Dispatch*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handleMethod*)
handleMethod // beginDefinition;

handleMethod[ "initialize", msg_, req_ ] := (
    $clientName = Replace[ msg[[ "params", "clientInfo", "name" ]], Except[ _String ] :> None ];
    $clientSupportsUI = mcpAppsEnabledQ[ ] && clientSupportsUIQ @ msg[ "params", "capabilities" ];
    $clientSupportsRoots = ! MissingQ @ msg[ "params", "capabilities", "roots" ];
    If[ ! stderrEnabledQ[ ], $Messages = { } ];
    <| req, "result" -> initResponse[ $currentMCPServer, msg ] |>
);

handleMethod[ "server/discover", msg_, req_ ] := <| req, "result" -> discoverResult @ $currentMCPServer |>;
handleMethod[ "ping"          , msg_, req_ ] := <| req, "result" -> <| |> |>;
handleMethod[ "resources/list", msg_, req_ ] := <| req, "result" -> <| "resources" -> listUIResources[ ] |> |>;
handleMethod[ "resources/read", msg_, req_ ] := handleResourceRead[ msg, req ];
handleMethod[ "prompts/list"  , msg_, req_ ] := <| req, "result" -> <| "prompts" -> $promptList |> |>;
handleMethod[ "prompts/get"   , msg_, req_ ] := handlePromptGet[ msg, req ];
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
    With[ { failureMsg = failureMessageText @ failure },
        If[ StringQ @ failureMsg, failureMsg, resourceReadErrorMessage[ msg ] ]
    ];

resourceReadErrorMessage[ msg_Association ] :=
    resourceReadErrorMessage @ Replace[ msg[[ "params", "uri" ]], Except[ _String ] :> "unknown" ];

resourceReadErrorMessage[ uri_String ] :=
    "UI resource not found: " <> uri;

resourceReadErrorMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*handlePromptGet*)
(* Once the standalone MCP server's time-limited license has expired, prompts fail with the expiration message instead
   of running, like tool calls (see evaluateTool and Tools/LicenseStatus.wl) *)
handlePromptGet // beginDefinition;

handlePromptGet[ msg_, req_ ] := handlePromptGet[ msg, req, licenseStatus[ ] ];

handlePromptGet[ msg_, req_, license: KeyValuePattern[ "Expired" -> True ] ] :=
    <| req, "error" -> <| "code" -> -32603, "message" -> license[ "Message" ] |> |>;

handlePromptGet[ msg_, req_, _ ] := <| req, "result" -> getPrompt[ msg, req ] |>;

handlePromptGet // endDefinition;

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
    With[ { msg = failureMessageText @ failure },
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
    Catch @ Module[ { params, toolName, args, license, tool, result, content, toolResultAssoc },
        Quiet @ TaskRemove @ $warmupTask; (* We're in a tool call, so it no longer makes sense to warm up tools *)
        writeLog[ "ToolCall" -> msg ];
        params = ConfirmBy[ Lookup[ msg, "params", <| |> ], AssociationQ ];
        toolName = ConfirmBy[ Lookup[ params, "name" ], StringQ ];
        args = Lookup[ params, "arguments", <| |> ];

        (* The standalone MCP server's time-limited license (read again on every call) applies to every tool except
           WolframLicenseStatus: once it has expired, the requested tool is not run and the call returns the expiration
           message as an error (see Tools/LicenseStatus.wl) *)
        license = If[ toolName === $licenseToolName, None, licenseStatus[ ] ];
        If[ MatchQ[ license, KeyValuePattern[ "Expired" -> True ] ],
            Throw @ <| "content" -> { <| "type" -> "text", "text" -> license[ "Message" ] |> }, "isError" -> True |>
        ];

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

        (* In the license's warning period, remind the user that it expires soon *)
        If[ MatchQ[ license, KeyValuePattern[ "Warning" -> True ] ],
            content = Append[ content, <| "type" -> "text", "text" -> license[ "Message" ] |> ]
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

safeString[ failure_Failure ] :=
    With[ { s = failureMessageText @ failure }, "[Error] " <> safeString @ s /; StringQ @ s ];
safeString[ string_String ] := convertPUACharacters @ string; (* avoid mangling due to StandardForm strings *)
safeString[ arg_ ] := convertPUACharacters @ ToString @ Unevaluated @ arg;
safeString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*failureMessageText*)
(* The plain text of a failure's message. The "Message" property embeds the parameters as linear syntax box markup,
   so the template and parameters are formatted with StringForm instead. Otherwise, ToString renders any markup in
   the message as text (e.g. LLMTool's "ConfirmationFailed" failures, whose template already contains it).
   TODO: parameters with 2D forms (e.g. fractions) and strings with newlines are laid out as multi-line blocks,
   and long parameters are not shortened. *)
failureMessageText // beginDefinition;

failureMessageText[
    Failure[ _, KeyValuePattern @ { "MessageTemplate" -> template_String, "MessageParameters" -> params: { __ } } ]
] := ToString @ StringForm[ template, Sequence @@ params ];

failureMessageText[ failure_Failure ] := Replace[ failure[ "Message" ], s_String :> ToString @ s ];

failureMessageText // endDefinition;

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

initResponse[ name_String, version_String, tools0: { ___LLMTool }, prompts_, clientMsg_Association ] :=
    DeleteMissing @ <|
        "protocolVersion" -> negotiateProtocolVersion @ clientMsg,
        "instructions"    -> serverInstructions @ prompts,
        "capabilities"    -> serverCapabilities[ If[ Length @ tools0 > 0, <| "listChanged" -> True |>, <| |> ], $clientSupportsUI ],
        "serverInfo"      -> <| "name" -> name, "version" -> version |>
    |>;

initResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*discoverResult*)
(* The result of the modern server/discover request; the server's identity is added to its _meta along with the other
   fields of a modern result (see completeModernResult). Unlike the legacy initialize result, which answers the
   capabilities the client declared once for the session, it describes what the server supports: the MCP Apps
   extension whenever it is enabled, since a client declares its own capabilities on each later request. The tools
   capability does not claim listChanged, since the server never sends list-changed notifications (which a modern
   client would have to request with subscriptions/listen). *)
discoverResult // beginDefinition;

discoverResult[ obj_MCPServerObject ] := DeleteMissing @ <|
    "supportedVersions" -> $supportedProtocolVersions,
    "capabilities"      -> serverCapabilities[ <| |>, mcpAppsEnabledQ[ ] ],
    "instructions"      -> serverInstructions @ obj[ "Prompts" ]
|>;

discoverResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*serverCapabilities*)
serverCapabilities // beginDefinition;

serverCapabilities[ tools_Association, ui_ ] := <|
    "prompts" -> <| |>,
    "tools"   -> tools,
    If[ TrueQ @ ui,
        "extensions" -> <|
            "io.modelcontextprotocol/ui" -> <|
                "mimeTypes" -> { "text/html;profile=mcp-app" }
            |>
        |>,
        Nothing
    ]
|>;

serverCapabilities // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*serverInstructions*)
serverInstructions // beginDefinition;

serverInstructions[ prompts_ ] := Enclose[
    ConfirmMatch[ withLicenseInstructions @ makeInstructions @ prompts, _Missing | _String, "Instructions" ],
    throwInternalFailure
];

serverInstructions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*serverInfo*)
serverInfo // beginDefinition;
serverInfo[ obj_MCPServerObject ] := <| "name" -> obj[ "Name" ], "version" -> obj[ "ServerVersion" ] |>;
serverInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*negotiateProtocolVersion*)
(* The protocol version of a legacy initialize response: the client's requested version when it is a supported legacy
   version, otherwise the latest legacy version (a modern version can't be negotiated with initialize). A
   missing/malformed request also yields the latest legacy version. Per the MCP lifecycle rules:
   https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle *)
negotiateProtocolVersion // beginDefinition;

negotiateProtocolVersion[ clientMsg_Association ] :=
    negotiateProtocolVersion @ clientMsg[ "params", "protocolVersion" ];

negotiateProtocolVersion[ version_String ] /; MemberQ[ $legacyProtocolVersions, version ] :=
    version;

negotiateProtocolVersion[ _ ] := First @ $legacyProtocolVersions;

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
(* ::Subsubsection::Closed:: *)
(*withLicenseInstructions*)
(* Appends the status of the standalone MCP server's time-limited license, if there is one, to the instructions *)
withLicenseInstructions // beginDefinition;
withLicenseInstructions[ instructions_ ] := withLicenseInstructions[ instructions, licenseInstructions[ ] ];
withLicenseInstructions[ instructions_, None ] := instructions;
withLicenseInstructions[ _Missing, license_String ] := license;
withLicenseInstructions[ instructions_String, license_String ] := instructions <> "\n\n" <> license;
withLicenseInstructions // endDefinition;

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
