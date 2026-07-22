(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Server`Cloud`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];
Needs[ "Wolfram`AgentTools`Server`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Client Capability Propagation (Self-Describing Session IDs)*)
(* The cloud transport is stateless: initialize, tools/list, and tools/call each arrive as separate
   HTTP requests with no server-side session store. A client capability that must survive across
   requests (in v1 this is only MCP-Apps UI support, gated on $clientSupportsUI) therefore cannot
   live in kernel state between requests. Instead it is packed into the Mcp-Session-Id header itself:
   the server encodes the negotiated capabilities into the session ID at `initialize`, the client
   echoes that ID on every later request, and the server decodes it back to re-establish the
   capability flags per request -- the way a signed token carries claims. The ID is a versioned,
   colon-delimited string "version:base36bitfield:uuid" where the bitfield packs the tracked feature
   flags and the trailing UUID keeps every ID unique and opaque. See Specs/CloudDeployment.md. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Configuration*)

(* Ordered list of tracked capability flags packed into the session-ID bitfield. Each flag maps to a
   fixed bit position, so this order must not change without bumping $idVersion -- a shifted bit
   position would make a session ID minted by an older deployment decode to the wrong features. In v1
   the only tracked capability is MCP-Apps UI support; the codec stays list-based so further features
   can be appended later (bumping $idVersion if any existing bit position would shift). *)
$trackedFeatureList = { "MCPApps" };

(* Session-ID format version. Bump whenever $trackedFeatureList changes in a way that shifts bit
   positions, so that IDs minted by an older deployment decode to no features (fail-closed) rather
   than misfiring on the new bit layout. *)
$idVersion = "1";

(* <| "MCPApps" -> 0 |> *)
$trackedFeatureIDs = First /@ PositionIndex[ $trackedFeatureList ] - 1;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeSessionIDFromFeatureList*)
(* Encode a client feature list into a self-describing session ID "version:base36bitfield:uuid".
   Intersecting with $trackedFeatureList first drops any untracked feature before it can reach the
   bitfield (so an unknown feature never contributes a bit); the empty set totals to 0 and encodes
   as "1:0:...". *)
makeSessionIDFromFeatureList // beginDefinition;

makeSessionIDFromFeatureList[ clientFeatures_List ] :=
    StringRiffle[
        {
            $idVersion,
            IntegerString[
                Total[ 2 ^ Lookup[ $trackedFeatureIDs, Intersection[ clientFeatures, $trackedFeatureList ] ] ],
                36
            ],
            CreateUUID[ ]
        },
        ":"
    ];

makeSessionIDFromFeatureList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getFeaturesFromSessionID*)
(* Decode a session ID back into its feature list. Only the current "1" version shape with a valid
   base-36 bitfield decodes to features; any other version or a malformed ID (wrong segment count,
   non-base36 bitfield, etc.) falls through to {} (fail-closed), so a client replaying a session ID
   minted by an older deployment simply gets no features -- turning MCP-Apps off rather than
   misfiring. The base36StringQ guard keeps a tampered or corrupted bitfield segment away from
   FromDigits, which would emit messages and return unevaluated on non-base36 input instead of
   failing closed. *)
getFeaturesFromSessionID // beginDefinition;

getFeaturesFromSessionID[ sessionID_String ] :=
    getFeaturesFromSessionID @ StringSplit[ sessionID, ":" ];

getFeaturesFromSessionID[ { "1", featureString_String? base36StringQ, _String } ] :=
    Pick[
        $trackedFeatureList,
        Reverse @ IntegerDigits[ FromDigits[ featureString, 36 ], 2, Length @ $trackedFeatureList ],
        1
    ];

getFeaturesFromSessionID[ _ ] := { };

getFeaturesFromSessionID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*base36StringQ*)
(* Matches exactly what the IntegerString[n, 36] call in makeSessionIDFromFeatureList can mint:
   lowercase base-36 digits. Anything else (including uppercase) is not an ID this server issued. *)
$base36Pattern = RegularExpression[ "[0-9a-z]+" ];

base36StringQ // beginDefinition;
base36StringQ[ s_String ] := StringMatchQ[ s, $base36Pattern ];
base36StringQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RunCloudMCPServer*)
(* The stateless Streamable HTTP handler deployed (via Delayed) at /mcp. It is the cloud analog of the
   local processRequest read loop, but handles exactly one HTTP request and always returns an
   HTTPResponse. Unlike the exported functions that use catchMine to surface a Failure, this handler
   must ALWAYS return an HTTPResponse: transport-level problems become HTTP status codes, dispatch/tool
   failures become an in-band JSON-RPC -32603 within a 200, and any other unexpected failure (e.g. from
   initializeServerState) becomes a 500. It is exported so the serialized Delayed[RunCloudMCPServer[obj]]
   payload references a real symbol. *)

RunCloudMCPServer // beginDefinition;
RunCloudMCPServer[ obj_MCPServerObject ] := runCloudMCPServer[
    obj,
    (* Read only the three properties the handler needs, rather than the full HTTPRequestData[]
       association (which would also compute FormRules / MultipartElements by parsing the body). *)
    <|
        "Method"        -> HTTPRequestData[ "Method" ],
        "Headers"       -> HTTPRequestData[ "Headers" ],
        "BodyByteArray" -> HTTPRequestData[ "BodyByteArray" ]
    |>
];
RunCloudMCPServer // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*runCloudMCPServer*)
(* Top-level error boundary. Transport short-circuits Throw an HTTPResponse to $cloudResponseTag; any
   other failure (e.g. the internal-failure Throw from initializeServerState) is caught by catchAlways
   and turned into a 500. The tag is kept distinct from the $catchTopTag that catchAlways catches, so
   internal failures still bubble up to the 500 handler rather than being mistaken for a response. *)
$cloudResponseTag = "Wolfram`AgentTools`Server`Cloud`Response";

runCloudMCPServer // beginDefinition;

runCloudMCPServer[ obj_MCPServerObject, request_ ] :=
    Module[ { result },
        result = catchAlways @ Catch[ runCloudMCPServer0[ obj, request ], $cloudResponseTag ];
        ensureHTTPResponse @ result
    ];

runCloudMCPServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*runCloudMCPServer0*)
(* Transport-level validation followed by JSON-RPC dispatch, implementing the stateless subset of the
   MCP Streamable HTTP transport (2025-11-25). Each transport check either passes or Throws its
   HTTPResponse to $cloudResponseTag. On success the dispatch Block's value (an HTTPResponse) is
   returned normally. *)
runCloudMCPServer0 // beginDefinition;

runCloudMCPServer0[ obj_MCPServerObject, request_ ] :=
    Module[ { headers, contentType, message, method, id, uiEnabled, req },

        (* 1. Method: only POST is dispatched. GET (the optional server->client SSE stream) and DELETE
              (session teardown) -- and anything else -- return 405: there is no server-side session to
              stream from or tear down in the stateless transport. *)
        If[ ToUpperCase @ requestMethod @ request =!= "POST",
            Throw[ emptyResponse[ 405 ], $cloudResponseTag ]
        ];

        headers = requestHeaders @ request;

        (* 2. Origin validation (DNS-rebinding protection): a present, untrusted Origin -> 403. An absent
              Origin (typical for server-to-server LLM providers) is allowed. *)
        If[ ! originAllowedQ @ headers,
            Throw[ emptyResponse[ 403 ], $cloudResponseTag ]
        ];

        (* 3. Accept negotiation: pick the response content type from the Accept header, else 406. *)
        contentType = responseContentType @ headers;
        If[ contentType === None,
            Throw[ emptyResponse[ 406 ], $cloudResponseTag ]
        ];

        (* 4. Parse the JSON-RPC body: a non-JSON or non-object body -> 400. *)
        message = parseRequestBody @ request;
        If[ ! AssociationQ @ message,
            Throw[ emptyResponse[ 400 ], $cloudResponseTag ]
        ];

        method = Lookup[ message, "method", None ];
        id     = Lookup[ message, "id", Null ];

        (* 5. Protocol-version header on non-initialize requests: present but unsupported -> 400. An
              absent header is allowed (the spec says assume 2025-03-26, which is supported). *)
        If[ method =!= "initialize" && ! supportedProtocolHeaderQ @ headers,
            Throw[ emptyResponse[ 400 ], $cloudResponseTag ]
        ];

        (* 6. Re-establish the client's UI capability from the self-describing session ID. *)
        uiEnabled = MemberQ[ getFeaturesFromSessionID @ sessionIDHeader @ headers, "MCPApps" ];

        req = <| "jsonrpc" -> "2.0", "id" -> id |>;

        (* 7. Dispatch inside the capability + per-request server-state Block, mirroring the local read
              loop (startMCPServer). initializeServerState rebuilds the tool/prompt tables from obj alone,
              so the handler never assumes a prior initialize ran; $clientSupportsUI comes from the
              session ID (or, for initialize itself, is reset by handleMethod from the client message). *)
        Block[
            {
                $currentMCPServer    = obj,
                $mcpEvaluation       = True,
                $clientSupportsUI    = uiEnabled,
                $clientSupportsRoots = False
            },
            Module[ { state },
                state = initializeServerState @ obj;
                Block[
                    {
                        $toolList     = state[ "ToolList" ],
                        $llmTools     = state[ "LLMTools" ],
                        $promptList   = state[ "PromptList" ],
                        $promptLookup = state[ "PromptLookup" ],
                        $toolOptions  = state[ "ToolOptions" ]
                    },
                    dispatchCloudMethod[ method, id, message, req, contentType ]
                ]
            ]
        ]
    ];

runCloudMCPServer0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ensureHTTPResponse*)
ensureHTTPResponse // beginDefinition;

ensureHTTPResponse[ resp_HTTPResponse ] :=
    resp;

ensureHTTPResponse[ Failure[ tag_String, _ ] ] :=
    HTTPResponse[ "An unexpected error occurred: " <> tag, <| "StatusCode" -> 500 |> ];

ensureHTTPResponse[ other_ ] :=
    HTTPResponse[ "An unexpected error occurred.", <| "StatusCode" -> 500 |> ];

ensureHTTPResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*dispatchCloudMethod*)
(* Route the single JSON-RPC message. A request (a method plus a non-null id, not a notification)
   returns its result in a 200; a notification / response / id->Null returns 202 with an empty body. A
   dispatch or tool failure is reported in-band as JSON-RPC -32603 within a 200, mirroring the local
   processRequest. initialize responses additionally carry a fresh self-describing Mcp-Session-Id. *)
dispatchCloudMethod // beginDefinition;

dispatchCloudMethod[ method_, id_, message_, req_, contentType_ ] :=
    Module[ { response, respHeaders },
        If[ replyOwedQ[ method, id ],
            response    = catchAlways @ handleMethod[ method, message, req ];
            respHeaders = sessionIDResponseHeaders @ method;
            If[ FailureQ @ response,
                jsonResponse[ <| req, "error" -> <| "code" -> -32603, "message" -> "Internal error" |> |>, contentType, respHeaders ],
                jsonResponse[ response, contentType, respHeaders ]
            ],
            (* No reply owed: still dispatch notifications for their side effects, then 202 empty. *)
            If[ StringQ @ method, catchAlways @ handleMethod[ method, message, req ] ];
            emptyResponse[ 202 ]
        ]
    ];

dispatchCloudMethod // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*replyOwedQ*)
(* A JSON-RPC reply is owed only for requests: a method plus a non-null id, excluding notifications. *)
replyOwedQ // beginDefinition;
replyOwedQ[ method_String, id_ ] := id =!= Null && ! StringStartsQ[ method, "notifications/" ];
replyOwedQ[ _, _ ] := False;
replyOwedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sessionIDResponseHeaders*)
(* initialize responses carry a fresh Mcp-Session-Id encoding the negotiated capabilities (read from
   $clientSupportsUI, which handleMethod["initialize"] has just set); every other response carries none,
   since the client keeps reusing the ID minted at initialize. Must run inside the dispatch Block. *)
sessionIDResponseHeaders // beginDefinition;
sessionIDResponseHeaders[ "initialize" ] := { "Mcp-Session-Id" -> makeSessionIDFromFeatureList @ currentTrackedFeatures[ ] };
sessionIDResponseHeaders[ _ ] := { };
sessionIDResponseHeaders // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*currentTrackedFeatures*)
(* Build the tracked-feature list from the capability globals set during initialize. v1 tracks only
   MCP-Apps UI support; append further features here as they are added to $trackedFeatureList. *)
currentTrackedFeatures // beginDefinition;
currentTrackedFeatures[ ] := If[ TrueQ @ $clientSupportsUI, { "MCPApps" }, { } ];
currentTrackedFeatures // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*HTTP Request Accessors*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*requestMethod*)
requestMethod // beginDefinition;
requestMethod[ request_Association ] := Replace[ Lookup[ request, "Method", "POST" ], Except[ _String ] -> "POST" ];
requestMethod[ _ ] := "POST";
requestMethod // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*requestHeaders*)
(* HTTPRequestData returns headers as a list of rules with lowercased names; normalize to a lowercased
   association so header lookups are case-insensitive regardless of the transport's representation. *)
requestHeaders // beginDefinition;
requestHeaders[ request_Association ] := toHeaderAssociation @ Lookup[ request, "Headers", { } ];
requestHeaders[ _ ] := <| |>;
requestHeaders // endDefinition;

toHeaderAssociation // beginDefinition;
toHeaderAssociation[ headers: { ___Rule } ] := KeyMap[ ToLowerCase, Association @ headers ];
toHeaderAssociation[ headers_Association ] := KeyMap[ ToLowerCase, headers ];
toHeaderAssociation[ _ ] := <| |>;
toHeaderAssociation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parseRequestBody*)
(* Decode the request body to a JSON value; return the association for a JSON object, else $Failed
   (which the caller maps to a 400). *)
parseRequestBody // beginDefinition;
parseRequestBody[ request_Association ] := parseRequestBodyString @ requestBodyString @ request;
parseRequestBody[ _ ] := $Failed;
parseRequestBody // endDefinition;

requestBodyString // beginDefinition;
requestBodyString[ request_Association ] :=
    requestBodyString[ Lookup[ request, "BodyByteArray", Missing[ ] ], Lookup[ request, "Body", Missing[ ] ] ];
requestBodyString[ bytes_ByteArray, _ ] := Quiet @ ByteArrayToString @ bytes;
requestBodyString[ _, body_String ] := body;
requestBodyString[ _, _ ] := Missing[ "NotAvailable" ];
requestBodyString // endDefinition;

parseRequestBodyString // beginDefinition;
parseRequestBodyString[ str_String ] :=
    With[ { parsed = Quiet @ Developer`ReadRawJSONString @ str },
        If[ AssociationQ @ parsed, parsed, $Failed ]
    ];
parseRequestBodyString[ _ ] := $Failed;
parseRequestBodyString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Transport Validation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*originAllowedQ*)
(* DNS-rebinding protection: an absent Origin (server-to-server LLM providers) is allowed; a present
   Origin is allowed only when its host is within the trusted Wolfram Cloud family, so a cross-site
   browser context is rejected with a 403. A present Origin in any unrecognized representation
   (e.g. a duplicated header surfacing as a list) fails closed. *)
$allowedOriginSuffixes = { "wolframcloud.com", "wolfram.com" };

originAllowedQ // beginDefinition;
originAllowedQ[ headers_Association ] := originHeaderAllowedQ @ Lookup[ headers, "origin", Missing[ "Absent" ] ];
originAllowedQ // endDefinition;

originHeaderAllowedQ // beginDefinition;
originHeaderAllowedQ[ _Missing ] := True;
originHeaderAllowedQ[ origin_String ] := allowedOriginHostQ @ URLParse[ origin, "Domain" ];
originHeaderAllowedQ[ _ ] := False;
originHeaderAllowedQ // endDefinition;

allowedOriginHostQ // beginDefinition;
allowedOriginHostQ[ host_String ] :=
    With[ { h = ToLowerCase @ host },
        AnyTrue[ $allowedOriginSuffixes, h === # || StringEndsQ[ h, "." <> # ] & ]
    ];
allowedOriginHostQ[ _ ] := False;
allowedOriginHostQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*responseContentType*)
(* Choose the response media type from the Accept header, preferring application/json and falling back
   to text/event-stream. An absent Accept (client accepts anything) defaults to application/json; a
   present Accept listing neither yields None, which the caller maps to a 406. *)
responseContentType // beginDefinition;
responseContentType[ headers_Association ] := responseContentType @ Lookup[ headers, "accept", Missing[ "Absent" ] ];
responseContentType[ _Missing ] := "application/json";
responseContentType[ accept_String ] := parseAcceptHeader @ accept;
responseContentType[ _ ] := None;
responseContentType // endDefinition;

parseAcceptHeader // beginDefinition;
parseAcceptHeader[ accept_String ] :=
    Module[ { types },
        types = ToLowerCase @ StringTrim @ First @ StringSplit[ #, ";" ] & /@ StringSplit[ accept, "," ];
        Which[
            ContainsAny[ types, { "application/json", "*/*", "application/*" } ], "application/json",
            MemberQ[ types, "text/event-stream" ],                                 "text/event-stream",
            True,                                                                  None
        ]
    ];
parseAcceptHeader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*supportedProtocolHeaderQ*)
(* The MCP-Protocol-Version request header must name a supported revision on non-initialize requests.
   An absent header is allowed (the spec says assume 2025-03-26, which is supported). *)
supportedProtocolHeaderQ // beginDefinition;
supportedProtocolHeaderQ[ headers_Association ] := supportedProtocolHeaderQ @ Lookup[ headers, "mcp-protocol-version", Missing[ "Absent" ] ];
supportedProtocolHeaderQ[ _Missing ] := True;
supportedProtocolHeaderQ[ version_String ] := MemberQ[ $supportedProtocolVersions, version ];
supportedProtocolHeaderQ[ _ ] := False;
supportedProtocolHeaderQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sessionIDHeader*)
sessionIDHeader // beginDefinition;
sessionIDHeader[ headers_Association ] := Replace[ Lookup[ headers, "mcp-session-id", "" ], Except[ _String ] -> "" ];
sessionIDHeader[ _ ] := "";
sessionIDHeader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*HTTP Response Construction*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeResponseString*)
(* Serialize a JSON-RPC result for the negotiated media type: compact JSON, or a single Server-Sent
   Events data frame for text/event-stream. Sanitizes PUA characters before encoding, matching the
   stdio transport's write path (see sanitizeResponse in Shared.wl). *)
makeResponseString // beginDefinition;
makeResponseString[ "application/json", result_ ] :=
    Developer`WriteRawJSONString[ sanitizeResponse @ result, "Compact" -> True ];
makeResponseString[ "text/event-stream", result_ ] :=
    "data: " <> Developer`WriteRawJSONString[ sanitizeResponse @ result, "Compact" -> True ] <> "\n\n";
makeResponseString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*jsonResponse*)
(* A 200 response carrying the serialized JSON-RPC result. ContentType reflects the negotiated media
   type (not always application/json -- a bug in the prototype). The body is UTF-8, and CharacterEncoding
   -> "UTF-8" makes the advertised charset match: application/json stays bare (JSON is UTF-8 by spec),
   while a text/event-stream response correctly advertises charset=utf-8 rather than a mismatched
   iso-8859-1. *)
jsonResponse // beginDefinition;
jsonResponse[ result_, contentType_String, headers_List ] :=
    HTTPResponse[
        StringToByteArray @ makeResponseString[ contentType, result ],
        <|
            "StatusCode"  -> 200,
            "ContentType" -> contentType,
            "Headers"     -> headers
        |>,
        CharacterEncoding -> "UTF-8"
    ];
jsonResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*emptyResponse*)
(* A response with an empty body and only a status code: 202 for accepted notifications/responses, and
   the transport-level error codes (400/403/405/406/500). *)
emptyResponse // beginDefinition;
emptyResponse[ code_Integer ] := HTTPResponse[ "", <| "StatusCode" -> code |> ];
emptyResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CloudDeployMCPServer*)
(* Deploy just the /mcp endpoint for a server object, with caller-controlled path and permissions. This
   is the primitive that the CloudDeploy UpValue (Task 8) reuses for the /mcp object, and is also useful
   directly when the landing/admin pages are not wanted. Unlike RunCloudMCPServer (an HTTP handler that
   must always return a response), this is an ordinary exported function: it wraps its body in catchMine
   so an error surfaces as a Failure[...]. *)

CloudDeployMCPServer // beginDefinition;
CloudDeployMCPServer[ obj_, args___ ] := catchMine @ cloudDeployEndpoint[ obj, args ];
CloudDeployMCPServer // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cloudDeployEndpoint*)
(* Resolve the server object, build the definition-bearing Delayed[RunCloudMCPServer[obj]] payload, and
   CloudDeploy it. An omitted target deploys anonymously (server-assigned path); an explicit String or
   CloudObject target overrides that. Permissions default to the ambient $Permissions and are applied to
   the deployed object; any other CloudDeploy options are forwarded. *)

(* A deployment target is a cloud path string, an explicit CloudObject, or Automatic (anonymous). Defined
   before the definitions below so the pattern resolves when they are set. *)
$$cloudDeployTarget = _String | _CloudObject | Automatic;

cloudDeployEndpoint // beginDefinition;
cloudDeployEndpoint // Options = { Permissions :> $Permissions };

(* An omitted target -> anonymous deployment. *)
cloudDeployEndpoint[ obj_, opts: OptionsPattern[ ] ] :=
    cloudDeployEndpoint[ obj, Automatic, opts ];

cloudDeployEndpoint[ obj_, target: $$cloudDeployTarget, opts: OptionsPattern[ ] ] := Enclose[
    Module[ { server, payload, perms, deployed },
        server   = ConfirmBy[ ensureMCPServerExists @ MCPServerObject @ obj, MCPServerObjectQ, "Server" ];
        payload  = ConfirmMatch[ cloudMCPServerPayload @ server, _Delayed, "Payload" ];
        perms    = OptionValue[ Permissions ];
        deployed = deployMCPEndpoint[ payload, target, perms, opts ];
        cloudDeployResult @ deployed
    ],
    throwInternalFailure
];

cloudDeployEndpoint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deployMCPEndpoint*)
(* CloudDeploy the (already definition-bearing, held) Delayed payload at the resolved permissions. An
   Automatic target deploys anonymously; a String/CloudObject target deploys there. Permissions is passed
   explicitly and dropped from the forwarded options to avoid a duplicate. *)
deployMCPEndpoint // beginDefinition;

deployMCPEndpoint[ payload_, Automatic, perms_, opts: OptionsPattern[ ] ] :=
    CloudDeploy[ payload, Permissions -> perms, filteredCloudDeployOptions @ opts ];

deployMCPEndpoint[ payload_, target: _String | _CloudObject, perms_, opts: OptionsPattern[ ] ] :=
    CloudDeploy[ payload, target, Permissions -> perms, filteredCloudDeployOptions @ opts ];

deployMCPEndpoint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*filteredCloudDeployOptions*)
(* Keep only valid CloudDeploy options, dropping Permissions (which is supplied explicitly). *)
filteredCloudDeployOptions // beginDefinition;
filteredCloudDeployOptions[ opts: OptionsPattern[ ] ] :=
    Sequence @@ DeleteCases[
        FilterRules[ { opts }, Options @ CloudDeploy ],
        HoldPattern[ Permissions -> _ ]
    ];
filteredCloudDeployOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudDeployResult*)
(* CloudDeploy returns a CloudObject on success; anything else (e.g. $Failed on a permission or
   connectivity error) becomes a CloudDeployFailed failure. *)
cloudDeployResult // beginDefinition;
cloudDeployResult[ obj_CloudObject ] := obj;
cloudDeployResult[ other_ ] := throwFailure[ "CloudDeployFailed", other ];
cloudDeployResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Server Embedding*)
(* The deployed /mcp endpoint must reconstruct the server -- including any custom, anonymous tool
   functions -- at request time, in a cloud kernel that lacks the user's local definitions. Two
   independent stripping mechanisms must be overcome:

     1. Context-based stripping. Wolfram`AgentTools`* is a member of Language`$InternalContexts, so the
        AgentTools definitions reachable from RunCloudMCPServer[obj] are stripped from serialized/deployed
        expressions by default. Gathering them inside a Block that removes Wolfram`AgentTools`* from that
        list captures them instead (a dev-bundling bridge, removed once a cloud-native paclet exists).

     2. Flag-based blocking. LLMTool carries the NOENTRY flag, so ordinary ExtendedFullDefinition (and
        CloudDeploy's own capture) cannot see the user-defined functions inside a tool. The paclet's
        NOENTRY-aware extendedFullDefinition recursively unpacks NOENTRY subexpressions so those functions
        are captured.

   The gathered definitions are injected into the deployed expression with the same
   `Language`ExtendedFullDefinition[ ] = defs; expr` strategy binarySerializeWithDefinitions uses, so the
   cloud kernel restores them on each (stateless) request. Chatbook is deliberately not bundled: built-in
   tools that call into it rely on Wolfram/Chatbook being installed at cold start (via the shared
   bootstrapping in initializeServerState); a fully self-contained custom server needs no paclet present.
   See Specs/CloudDeployment.md (Embedding the Server). *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cloudMCPServerPayload*)
(* Build the definition-bearing Delayed[RunCloudMCPServer[server]] expression to deploy at /mcp. server is
   a pattern variable bound to the actual MCPServerObject, so its value is substituted into the held
   argument of the HoldFirst extendedFullDefinition before the hold takes effect -- placing the server's
   NOENTRY-flagged tools lexically inside the gathered expression so extendedFullDefinition can unpack
   them. The gather runs inside the internal-contexts Block so AgentTools's own definitions are captured
   too; RunCloudMCPServer is never evaluated here (it stays held inside Delayed). *)
cloudMCPServerPayload // beginDefinition;

cloudMCPServerPayload[ server_MCPServerObject ] /; MatchQ[ server[ "Location" ], _File ] :=
    cloudMCPServerPayload @ removeLocalServerLocation @ server;

cloudMCPServerPayload[ server_MCPServerObject ] := Enclose[
    Block[ { Language`$InternalContexts = deAgentToolsInternalContexts[ ] },
        Module[ { defs },
            defs = ConfirmMatch[
                extendedFullDefinition[ Delayed @ RunCloudMCPServer @ server ],
                _Language`DefinitionList,
                "Definitions"
            ];
            injectServerDefinitions[ defs, server ]
        ]
    ],
    throwInternalFailure
];

cloudMCPServerPayload // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeLocalServerLocation*)
(* Converts the MCPServerObject to a purely in-memory representation, removing the local server location.
   This is necessary for custom MCP servers, since they'll have a `"Location" -> File[...]` in their metadata.
   This would cause validation to fail in the cloud, since that file doesn't exist in the cloud. *)
removeLocalServerLocation // beginDefinition;

removeLocalServerLocation[ server_MCPServerObject ] := Enclose[
    MCPServerObject @ <|
        ConfirmBy[ server[ "Data" ], AssociationQ, "Data" ],
        "Location" -> None
    |>,
    throwInternalFailure
];

removeLocalServerLocation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deAgentToolsInternalContexts*)
(* Language`$InternalContexts with the Wolfram`AgentTools`* entry removed, so the dev-bundling bridge can
   capture AgentTools's own definitions. Wolfram`Chatbook`* (and any other internal context) is left
   intact -- Chatbook stays internal and is installed at cold start rather than bundled. *)
deAgentToolsInternalContexts // beginDefinition;
deAgentToolsInternalContexts[ ] :=
    DeleteCases[ Language`$InternalContexts, _String? (StringStartsQ[ "Wolfram`AgentTools`" ]) ];
deAgentToolsInternalContexts // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*injectServerDefinitions*)
(* Wrap the handler call so the gathered definitions are restored before it runs. With injects the
   DefinitionList and server value into the held Delayed body; Language`ExtendedFullDefinition[ ] = defs
   re-establishes every captured definition in the (fresh, stateless) cloud kernel on each request, then
   RunCloudMCPServer[server] handles it -- mirroring binarySerializeWithDefinitions. An empty
   DefinitionList (no dependent definitions) needs no injection. *)
injectServerDefinitions // beginDefinition;

injectServerDefinitions[ Language`DefinitionList[ ], server_ ] :=
    Delayed @ RunCloudMCPServer @ server;

injectServerDefinitions[ defs_Language`DefinitionList, server_ ] :=
    With[ { d = defs, o = server },
        Delayed[ Language`ExtendedFullDefinition[ ] = d; RunCloudMCPServer[ o ] ]
    ];

injectServerDefinitions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Landing Page & Server Info API*)
(* /api/info is the public metadata endpoint the landing page (a static HTML/JS shell) fetches at view
   time to render the server name, version, tool list, and endpoint URL, plus its click-to-copy client
   configuration snippets. Its content is fixed for a given server object, so it is generated once at
   deploy time and deployed as static JSON (Task 8), rather than recomputed per request -- a page view
   needs no server embedding or cold start. cloudMCPServerInfo builds the plain-data association: the
   deployer resolves the /mcp endpoint URL and passes it in. It deliberately exposes no keys, permissions,
   or usage data. See Specs/CloudDeployment.md (Landing Page). *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cloudMCPServerInfo*)
cloudMCPServerInfo // beginDefinition;

cloudMCPServerInfo[ obj_MCPServerObject, url_String ] := Enclose[
    <|
        "name"    -> ConfirmBy[ obj[ "Name" ], StringQ, "Name" ],
        "version" -> ConfirmBy[ obj[ "ServerVersion" ], StringQ, "Version" ],
        "url"     -> url,
        "tools"   -> ConfirmMatch[ cloudInfoTool /@ serverToolListData @ obj, { ___Association }, "Tools" ]
    |>,
    throwInternalFailure
];

cloudMCPServerInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudInfoTool*)
(* Project a $toolList entry down to the public fields the landing page shows: name, optional title
   (the tool's DisplayName), and description. inputSchema and annotations are intentionally dropped --
   the landing page only lists what a tool is, not its call schema. *)
cloudInfoTool // beginDefinition;

cloudInfoTool[ data_Association ] := DeleteMissing @ <|
    "name"        -> data[ "name" ],
    "title"       -> Lookup[ data, "title", Missing[ ] ],
    "description" -> Lookup[ data, "description", "" ]
|>;

cloudInfoTool // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Admin Page & Key Management API*)
(* /api/admin is the owner-only (Private) API backing the admin page. It manages the sibling /mcp object's
   Wolfram Cloud PermissionsKeys -- listing, minting, and revoking API keys -- using the standard cloud
   primitives (Information[mcp,"Permissions"], SetPermissions, DeleteObject[PermissionsKey[...]]). It is
   deployed (Task 8) as Delayed[runCloudAdminAPI[base]] forced Private, capturing the deployment directory
   (base) so it can resolve its siblings <base>/mcp (the endpoint whose keys it manages) and
   <base>/admin/keys.wxf (an optional human-readable label store). Because the object is Private and reached
   only over the owner's authenticated Wolfram Cloud session, no secret is embedded and the handler does no
   auth of its own -- an unauthorized caller never reaches it. The authoritative list of valid keys is
   always /mcp's live permissions; the label store is a best-effort convenience. See
   Specs/CloudDeployment.md (Admin Page). *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*runCloudAdminAPI*)
(* The handler deployed (via Delayed) at /api/admin. Like RunCloudMCPServer it always returns an
   HTTPResponse: a well-formed action yields a 200 JSON result, a client error (bad method / body /
   action / key) yields a 4xx JSON error, and any unexpected internal failure yields a 500. It is not
   exported -- the deployed Delayed[runCloudAdminAPI[base]] payload carries its definition via the same
   dev-bundling capture used for /mcp. *)
runCloudAdminAPI // beginDefinition;

runCloudAdminAPI[ base_CloudObject ] := runCloudAdminAPI[
    base,
    <|
        "Method"        -> HTTPRequestData[ "Method" ],
        "BodyByteArray" -> HTTPRequestData[ "BodyByteArray" ]
    |>
];

runCloudAdminAPI[ base_CloudObject, request_ ] :=
    Module[ { result },
        result = catchAlways @ runCloudAdminAPI0[ base, request ];
        If[ MatchQ[ result, _HTTPResponse ],
            result,
            adminJSONResponse[ <| "ok" -> False, "error" -> "Internal error." |>, 500 ]
        ]
    ];

runCloudAdminAPI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*runCloudAdminAPI0*)
(* Transport validation (POST + a JSON object body) followed by action dispatch. The admin page always
   POSTs a JSON body { "action", "key"?, "label"? }; a non-POST method or a malformed body short-circuits
   to a 4xx before any cloud operation runs. *)
runCloudAdminAPI0 // beginDefinition;

runCloudAdminAPI0[ base_CloudObject, request_ ] :=
    If[ ToUpperCase @ requestMethod @ request =!= "POST",
        adminJSONResponse[ <| "ok" -> False, "error" -> "Method not allowed." |>, 405 ],
        Module[ { message },
            message = parseRequestBody @ request;
            If[ ! AssociationQ @ message,
                adminJSONResponse[ <| "ok" -> False, "error" -> "Malformed request body." |>, 400 ],
                adminActionResponse @ cloudAdminAction[ base, Lookup[ message, "action", None ], message ]
            ]
        ]
    ];

runCloudAdminAPI0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*adminActionResponse*)
(* Map an action's plain-data result to an HTTP response: a successful action (ok -> True) is a 200; a
   client-side error (ok -> False: unknown action, missing/invalid key, key not found) is a 400. *)
adminActionResponse // beginDefinition;
adminActionResponse[ result_Association ] := adminJSONResponse[ result, If[ TrueQ @ result[ "ok" ], 200, 400 ] ];
adminActionResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*adminJSONResponse*)
(* A JSON HTTPResponse. CharacterEncoding -> "UTF-8" keeps the advertised charset consistent with the
   UTF-8 body, mirroring the /mcp jsonResponse. *)
adminJSONResponse // beginDefinition;
adminJSONResponse[ data_, code_Integer ] :=
    HTTPResponse[
        StringToByteArray @ Developer`WriteRawJSONString[ data, "Compact" -> True ],
        <| "StatusCode" -> code, "ContentType" -> "application/json" |>,
        CharacterEncoding -> "UTF-8"
    ];
adminJSONResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cloudAdminAction*)
(* Dispatch a single admin action against the deployment. Each branch returns a plain-data association
   serialized to JSON by adminJSONResponse. An unrecognized action fails closed with ok -> False. *)
cloudAdminAction // beginDefinition;

cloudAdminAction[ base_CloudObject, "listKeys", _Association ] :=
    <| "ok" -> True, "keys" -> adminKeyList @ base |>;

cloudAdminAction[ base_CloudObject, "createKey", params_Association ] :=
    adminCreateKey[ base, Lookup[ params, "label", Null ] ];

cloudAdminAction[ base_CloudObject, "revokeKey", params_Association ] :=
    adminRevokeKey[ base, Lookup[ params, "key", Null ] ];

cloudAdminAction[ _CloudObject, action_, _ ] :=
    <| "ok" -> False, "error" -> "Unknown action: " <> Replace[ action, Except[ _String ] -> "(none)" ] |>;

cloudAdminAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*adminCreateKey*)
(* Mint a new PermissionsKey with Execute rights on /mcp (the authoritative step) and, if a label was
   given, record it in the best-effort label store. Returns the new key once (the owner copies it now)
   plus the refreshed key list. A cloud failure of the SetPermissions step surfaces as a 500 via the
   Enclose boundary; a label-store failure is quietly ignored. *)
adminCreateKey // beginDefinition;

adminCreateKey[ base_CloudObject, label_ ] := Enclose[
    Module[ { mcp, key, labeled },
        mcp     = adminMCPObject @ base;
        key     = CreateUUID[ ];
        labeled = StringQ[ label ] && label =!= "";
        ConfirmMatch[ SetPermissions[ mcp, PermissionsKey[ key ] -> "Execute" ], _List, "SetPermissions" ];
        If[ labeled, Quiet @ adminSetLabel[ base, key, label ] ];
        <|
            "ok"      -> True,
            "created" -> <| "key" -> key, "label" -> If[ labeled, label, Null ] |>,
            "keys"    -> adminKeyList @ base
        |>
    ],
    throwInternalFailure
];

adminCreateKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*adminRevokeKey*)
(* Revoke a key by deleting its PermissionsKey (and dropping any stored label). The key must be a
   well-formed UUID that currently grants access to this /mcp, guarding DeleteObject against an arbitrary
   or cross-deployment key. Returns the refreshed key list. *)
adminRevokeKey // beginDefinition;

adminRevokeKey[ base_CloudObject, key_ ] := Enclose[
    If[ ! validKeyStringQ @ key,
        <| "ok" -> False, "error" -> "Missing or invalid key." |>,
        Module[ { mcp, current },
            mcp     = adminMCPObject @ base;
            current = ConfirmMatch[ adminPermissionKeyStrings @ mcp, { ___String }, "Current" ];
            If[ ! MemberQ[ current, key ],
                <| "ok" -> False, "error" -> "Key not found." |>,
                Quiet @ DeleteObject @ PermissionsKey @ key;
                Quiet @ adminDropLabel[ base, key ];
                <| "ok" -> True, "keys" -> adminKeyList @ base |>
            ]
        ]
    ],
    throwInternalFailure
];

adminRevokeKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*adminKeyList*)
(* The authoritative key list from /mcp's live permissions, each annotated with its stored human-readable
   label (Null when none). *)
adminKeyList // beginDefinition;

adminKeyList[ base_CloudObject ] := Enclose[
    Module[ { mcp, entries, labels },
        mcp     = adminMCPObject @ base;
        entries = ConfirmMatch[ adminPermissionEntries @ mcp, { ___Association }, "Entries" ];
        labels  = adminReadLabels @ base;
        Map[ Append[ #, "label" -> Lookup[ labels, #[ "key" ], Null ] ] &, entries ]
    ],
    throwInternalFailure
];

adminKeyList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*adminPermissionEntries*)
(* Extract the PermissionsKey rules from Information[mcp,"Permissions"] as { <|"key","permissions"|>, ... },
   dropping the non-key "Owner" entry. Permission levels are coerced to strings for JSON. *)
adminPermissionEntries // beginDefinition;

adminPermissionEntries[ mcp_CloudObject ] := Enclose[
    Module[ { perms },
        perms = ConfirmMatch[ Information[ mcp, "Permissions" ], _List, "Permissions" ];
        Cases[
            perms,
            HoldPattern[ PermissionsKey[ uuid_String ] -> levels_ ] :>
                <| "key" -> uuid, "permissions" -> (ToString /@ Flatten @ { levels }) |>
        ]
    ],
    throwInternalFailure
];

adminPermissionEntries // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*adminPermissionKeyStrings*)
adminPermissionKeyStrings // beginDefinition;
adminPermissionKeyStrings[ mcp_CloudObject ] := #[ "key" ] & /@ adminPermissionEntries @ mcp;
adminPermissionKeyStrings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Deployment siblings*)
(* Resolve the /mcp endpoint and the label store as siblings of the captured deployment base, mirroring the
   FileNameJoin-on-CloudObject joining used elsewhere (e.g. UIResources.wl deployCloudNotebookForMCPApp). *)
adminMCPObject // beginDefinition;
adminMCPObject[ base_CloudObject ] := FileNameJoin @ { base, "mcp" };
adminMCPObject // endDefinition;

adminKeyLabelStore // beginDefinition;
adminKeyLabelStore[ base_CloudObject ] := FileNameJoin @ { base, "admin", "keys.wxf" };
adminKeyLabelStore // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Key labels (best-effort)*)
(* Optional human-readable labels persisted as a Private WXF association (uuid -> label) in the deployment's
   /admin/keys.wxf. The authoritative key list is always the live permissions, so every label operation is
   best-effort: a read miss yields no labels, and a write is only attempted alongside a successful key
   change (and quieted by the caller). *)
adminReadLabels // beginDefinition;
adminReadLabels[ base_CloudObject ] :=
    Replace[ readCloudWXF @ adminKeyLabelStore @ base, Except[ _Association ] -> <| |> ];
adminReadLabels // endDefinition;

adminSetLabel // beginDefinition;
adminSetLabel[ base_CloudObject, key_String, label_String ] :=
    writeCloudWXF[ adminKeyLabelStore @ base, Append[ adminReadLabels @ base, key -> label ] ];
adminSetLabel // endDefinition;

adminDropLabel // beginDefinition;
adminDropLabel[ base_CloudObject, key_String ] :=
    With[ { labels = adminReadLabels @ base },
        If[ KeyExistsQ[ labels, key ], writeCloudWXF[ adminKeyLabelStore @ base, KeyDrop[ labels, key ] ] ]
    ];
adminDropLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validKeyStringQ*)
(* A revocable key must be a well-formed UUID (as minted by CreateUUID), guarding DeleteObject against an
   arbitrary PermissionsKey argument. *)
$uuidPattern = RegularExpression[ "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" ];

validKeyStringQ // beginDefinition;
validKeyStringQ[ key_String ] := StringMatchQ[ key, $uuidPattern ];
validKeyStringQ[ _ ] := False;
validKeyStringQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cloudAdminAPIPayload*)
(* Build the definition-bearing Delayed[runCloudAdminAPI[base]] expression to deploy at /api/admin (Task 8,
   forced Private). base is a pattern variable bound to the deployment directory CloudObject, so its value
   is substituted into the gathered expression. As with cloudMCPServerPayload, the gather runs inside the
   internal-contexts Block so AgentTools's own definitions (runCloudAdminAPI and its dependency closure) are
   captured rather than stripped, then injected so the cloud kernel restores them on each request. *)
cloudAdminAPIPayload // beginDefinition;

cloudAdminAPIPayload[ base_CloudObject ] := Enclose[
    Block[ { Language`$InternalContexts = deAgentToolsInternalContexts[ ] },
        Module[ { defs },
            defs = ConfirmMatch[
                extendedFullDefinition[ Delayed @ runCloudAdminAPI @ base ],
                _Language`DefinitionList,
                "Definitions"
            ];
            injectAdminDefinitions[ defs, base ]
        ]
    ],
    throwInternalFailure
];

cloudAdminAPIPayload // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*injectAdminDefinitions*)
(* Wrap the handler call so the gathered definitions are restored before it runs in the cloud kernel,
   mirroring injectServerDefinitions. An empty DefinitionList needs no injection. *)
injectAdminDefinitions // beginDefinition;

injectAdminDefinitions[ Language`DefinitionList[ ], base_ ] :=
    Delayed @ runCloudAdminAPI @ base;

injectAdminDefinitions[ defs_Language`DefinitionList, base_ ] :=
    With[ { d = defs, o = base },
        Delayed[ Language`ExtendedFullDefinition[ ] = d; runCloudAdminAPI[ o ] ]
    ];

injectAdminDefinitions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CloudDeploy (Full Directory Bundle)*)
(* The headline integration: CloudDeploy of an MCPServerObject deploys a full directory bundle -- the live
   /mcp endpoint, a public landing page (/index.html + /assets/* + /api/info), and an owner-only admin page
   (/admin/index.html + /api/admin) -- and returns the directory CloudObject. The CloudDeploy UpValue on
   MCPServerObject lives with the other upvalues (DeleteObject / LLMConfiguration) in MCPServerObject.wl;
   both it and the exported CloudDeployMCPServerBundle (below) delegate to cloudDeployDirectory, which
   orchestrates the primitives built by the earlier tasks:
   the endpoint payload (cloudMCPServerPayload) and deploy helper (deployMCPEndpoint), the /api/info generator
   (cloudMCPServerInfo), and the admin payload (cloudAdminAPIPayload). /mcp, /index.html, /assets/*, and
   /api/info carry the resolved Permissions; /admin/index.html and /api/admin are always Private. See
   Specs/CloudDeployment.md (CloudDeploy UpValue, Deployed Directory Layout). *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*CloudDeployMCPServerBundle*)
(* Exported entry point for the full directory bundle, equivalent to CloudDeploy[MCPServerObject[obj], ...]
   but callable without going through the UpValue (e.g. with a server name or spec directly). Like
   CloudDeployMCPServer, it wraps its body in catchMine so an error surfaces as a Failure[...]. *)

CloudDeployMCPServerBundle // beginDefinition;
CloudDeployMCPServerBundle[ obj_, args___ ] := catchMine @ cloudDeployDirectory[ obj, args ];
CloudDeployMCPServerBundle // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cloudDeployDirectory*)
(* Validate the server, require a cloud session, resolve the directory CloudObject, clear any pre-existing
   object at an explicit target (matching CloudDeploy's default overwrite behavior), deploy the bundle, and
   return the (bare, option-free) directory. Permissions defaults to the ambient $Permissions and applies to
   /mcp, /index.html, /assets/*, and /api/info; the admin objects are forced Private inside
   deployDirectoryBundle. *)
cloudDeployDirectory // beginDefinition;
cloudDeployDirectory // Options = { Permissions :> $Permissions };

(* An omitted target -> anonymous deployment (a server-assigned directory prefix). *)
cloudDeployDirectory[ obj_, opts: OptionsPattern[ ] ] :=
    cloudDeployDirectory[ obj, Automatic, opts ];

cloudDeployDirectory[ obj_, target: $$cloudDeployTarget, opts: OptionsPattern[ ] ] := Enclose[
    Module[ { server, perms, dir },
        server = ConfirmBy[ ensureMCPServerExists @ MCPServerObject @ obj, MCPServerObjectQ, "Server" ];
        (* A deliberate abort-on-disconnect guard. There is no prior precedent in the codebase (existing
           cloud code silently falls back), so this is new behavior -- fail fast rather than emit an opaque
           cloud error partway through the bundle. *)
        If[ ! TrueQ @ $CloudConnected, throwFailure[ "NotCloudConnected" ] ];
        perms = OptionValue[ Permissions ];
        dir   = bareCloudObject @ ConfirmMatch[ resolveDeploymentDirectory[ target, perms ], _CloudObject, "Directory" ];
        clearExistingCloudTarget[ target, dir ];
        ConfirmMatch[ deployDirectoryBundle[ server, dir, perms, opts ], { __CloudObject }, "Bundle" ];
        dir
    ],
    throwInternalFailure
];

(* A second argument that is neither a valid target nor an option -> InvalidCloudTarget. Rules and rule lists
   are excluded so the pure-options call CloudDeploy[obj, Permissions -> ...] still routes to the anonymous
   form above (verified: $$cloudDeployTarget is typed, so a bare Permissions rule never matches the target
   overload). *)
cloudDeployDirectory[
    _,
    target: Except[ $$cloudDeployTarget | _Rule | _RuleDelayed | { ___Rule } | { ___RuleDelayed } ],
    OptionsPattern[ ]
] := throwFailure[ "InvalidCloudTarget", target ];

cloudDeployDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveDeploymentDirectory*)
(* Resolve the deployment directory CloudObject. An omitted target creates an anonymous cloud directory with
   CreateDirectory: the bare CloudObject[Permissions -> perms] the spec sketches materializes a leaf at
   /obj/<uuid> that cannot hold children (a child deploy fails with CloudDeploy::cloudunknown), whereas
   CreateDirectory yields an actual directory object at an anonymous server-assigned path that children nest
   under. (CreateDirectory returns an Owner-only directory regardless of the requested perms; that governs
   only the bare directory URL -- each child object is deployed at its own explicit permissions, and the
   landing page is reached at <dir>/index.html.) An explicit string name resolves under the user's cloud
   area; an explicit CloudObject is used as given. *)
resolveDeploymentDirectory // beginDefinition;
resolveDeploymentDirectory[ Automatic, perms_ ]      := CreateDirectory @ CloudObject[ Permissions -> perms ];
resolveDeploymentDirectory[ target_String, perms_ ]  := CloudObject[ target, Permissions -> perms ];
resolveDeploymentDirectory[ target_CloudObject, _ ]  := target;
resolveDeploymentDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*bareCloudObject*)
(* Strip any options (e.g. the Permissions attached during resolution) down to a bare CloudObject[url].
   Plain CloudDeploy returns an option-free CloudObject, so the directory deploy returns one too; keeping the
   directory bare also keeps the base embedded in the admin payload (cloudAdminAPIPayload) option-free. *)
bareCloudObject // beginDefinition;
bareCloudObject[ CloudObject[ url_String, ___ ] ] := CloudObject @ url;
bareCloudObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*clearExistingCloudTarget*)
(* CloudDeploy's default for ordinary expressions is to overwrite whatever already occupies the target path,
   but a pre-existing (leaf) object blocks the bundle's child deploys instead: the first child fails with
   CloudDeploy::cloudunknown, surfacing as CloudDeployFailed. Deleting an explicit target up front restores
   the overwrite semantics (DeleteObject removes a directory recursively, so a previous deployment at the
   same path is fully replaced). The Quiet covers the usual case where nothing exists at the target yet. An
   Automatic target is the anonymous directory CreateDirectory just made, so there is nothing to clear. *)
clearExistingCloudTarget // beginDefinition;
clearExistingCloudTarget[ Automatic, _CloudObject ] := Null;
clearExistingCloudTarget[ _String | _CloudObject, dir_CloudObject ] := (Quiet @ DeleteObject @ dir; Null);
clearExistingCloudTarget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deployDirectoryBundle*)
(* Deploy every object in the directory and return the flat list of deployed CloudObjects. Ordered so /mcp is
   deployed first: its URL feeds the static /api/info payload. A failure of any step surfaces (as
   CloudDeployFailed for a cloud write, or an internal failure for a local problem) rather than leaving a
   partial bundle silently. *)
deployDirectoryBundle // beginDefinition;

deployDirectoryBundle[ server_MCPServerObject, dir_CloudObject, perms_, opts: OptionsPattern[ ] ] := Enclose[
    Module[ { mcp, mcpURL, info, landing, admin },
        mcp     = ConfirmMatch[ deployEndpointObject[ server, dir, perms, opts ], _CloudObject, "MCP" ];
        mcpURL  = ConfirmBy[ First @ mcp, StringQ, "MCPURL" ];
        info    = ConfirmMatch[ deployInfoObject[ server, dir, mcpURL, perms, opts ], _CloudObject, "Info" ];
        landing = ConfirmMatch[ deployLandingAssets[ dir, perms ], { __CloudObject }, "Landing" ];
        admin   = ConfirmMatch[ deployAdminBundle[ dir, opts ], { __CloudObject }, "Admin" ];
        Flatten @ { mcp, info, landing, admin }
    ],
    throwInternalFailure
];

deployDirectoryBundle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deployEndpointObject*)
(* Deploy /mcp via the endpoint primitive (cloudMCPServerPayload + deployMCPEndpoint), carrying the server's
   definitions, at the resolved permissions. *)
deployEndpointObject // beginDefinition;
deployEndpointObject[ server_MCPServerObject, dir_CloudObject, perms_, opts: OptionsPattern[ ] ] :=
    cloudDeployResult @ deployMCPEndpoint[
        cloudMCPServerPayload @ server,
        cloudDeploymentSubObject[ dir, { "mcp" } ],
        perms,
        opts
    ];
deployEndpointObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deployInfoObject*)
(* Deploy /api/info as static JSON (application/json). Its content is fixed for a given server object, so it
   is generated once here rather than served by an embedded per-request handler. *)
deployInfoObject // beginDefinition;
deployInfoObject[ server_MCPServerObject, dir_CloudObject, mcpURL_String, perms_, opts: OptionsPattern[ ] ] :=
    cloudDeployResult @ CloudDeploy[
        ExportForm[ cloudMCPServerInfo[ server, mcpURL ], "RawJSON" ],
        cloudDeploymentSubObject[ dir, { "api", "info" } ],
        Permissions -> perms,
        filteredCloudDeployOptions @ opts
    ];
deployInfoObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deployLandingAssets*)
(* Copy /index.html and every file under the local assets/ directory to /assets/* at the resolved permissions.
   CopyFile preserves each file's content type from its extension (text/html, text/css, text/javascript). *)
deployLandingAssets // beginDefinition;

deployLandingAssets[ dir_CloudObject, perms_ ] := Enclose[
    Module[ { assetsDir, index, assetFiles },
        assetsDir  = ConfirmBy[ cloudAssetDirectory[ ], DirectoryQ, "AssetsDir" ];
        index      = ConfirmBy[ FileNameJoin @ { assetsDir, "index.html" }, FileExistsQ, "Index" ];
        assetFiles = FileNames[ "*", FileNameJoin @ { assetsDir, "assets" } ];
        Join[
            { ConfirmMatch[
                copyFileToCloud[ index, cloudDeploymentSubObject[ dir, { "index.html" } ], perms ],
                _CloudObject,
                "IndexCopy"
            ] },
            Map[
                ConfirmMatch[
                    copyFileToCloud[ #, cloudDeploymentSubObject[ dir, { "assets", FileNameTake @ # } ], perms ],
                    _CloudObject,
                    "AssetCopy"
                ] &,
                assetFiles
            ]
        ]
    ],
    throwInternalFailure
];

deployLandingAssets // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deployAdminBundle*)
(* Deploy /admin/index.html (the self-contained admin page) and /api/admin (the key-management handler),
   both forced Private regardless of the resolved permissions -- they are reached only through the owner's
   authenticated cloud session. *)
deployAdminBundle // beginDefinition;

deployAdminBundle[ dir_CloudObject, opts: OptionsPattern[ ] ] := Enclose[
    Module[ { assetsDir, adminHTML, page, api },
        assetsDir = ConfirmBy[ cloudAssetDirectory[ ], DirectoryQ, "AssetsDir" ];
        adminHTML = ConfirmBy[ FileNameJoin @ { assetsDir, "admin.html" }, FileExistsQ, "AdminHTML" ];
        page = ConfirmMatch[
            copyFileToCloud[ adminHTML, cloudDeploymentSubObject[ dir, { "admin", "index.html" } ], "Private" ],
            _CloudObject,
            "AdminPage"
        ];
        api = cloudDeployResult @ CloudDeploy[
            cloudAdminAPIPayload @ dir,
            cloudDeploymentSubObject[ dir, { "api", "admin" } ],
            Permissions -> "Private",
            filteredCloudDeployOptions @ opts
        ];
        { page, api }
    ],
    throwInternalFailure
];

deployAdminBundle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Deployment paths & asset copy*)
(* Resolve a deployment sub-object at the given relative path parts under the directory, mirroring the
   FileNameJoin-on-CloudObject joining used elsewhere (UIResources.wl, the admin sibling resolution). These
   are file-private helpers used only by the directory bundle, following the same convention as the admin
   sibling resolvers (adminMCPObject / adminKeyLabelStore) above. The result is re-wrapped from the bare URL
   so it carries NO Permissions: FileNameJoin propagates the directory's Permissions option to the child, so
   stripping it here keeps each deploy's explicit Permissions authoritative (otherwise the directory's key
   permission would leak into the Private admin objects). *)
cloudDeploymentSubObject // beginDefinition;
cloudDeploymentSubObject[ dir_CloudObject, rel_List ] :=
    CloudObject[ First @ FileNameJoin @ Prepend[ rel, dir ] ];
cloudDeploymentSubObject // endDefinition;

(* Copy a local file to the given sub-object at the resolved permissions. Re-wrapping the target URL in
   CloudObject[..., Permissions -> perms] is how CopyFile attaches permissions to the created object. *)
copyFileToCloud // beginDefinition;
copyFileToCloud[ localFile_String, target_CloudObject, perms_ ] :=
    CopyFile[ localFile, CloudObject[ First @ target, Permissions -> perms ], OverwriteTarget -> True ];
copyFileToCloud // endDefinition;

(* The bundled Cloud asset directory (index.html, admin.html, assets/), mirroring initializeUIResources. *)
cloudAssetDirectory // beginDefinition;
cloudAssetDirectory[ ] := PacletObject[ "Wolfram/AgentTools" ][ "AssetLocation", "Cloud" ];
cloudAssetDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
