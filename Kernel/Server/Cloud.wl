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
(* Decode a session ID back into its feature list. Only the current "1" version shape decodes to
   features; any other version or a malformed ID falls through to {} (fail-closed), so a client
   replaying a session ID minted by an older deployment simply gets no features -- turning MCP-Apps
   off rather than misfiring. *)
getFeaturesFromSessionID // beginDefinition;

getFeaturesFromSessionID[ sessionID_String ] :=
    getFeaturesFromSessionID @ StringSplit[ sessionID, ":" ];

getFeaturesFromSessionID[ { "1", featureString_String, _String } ] :=
    Pick[
        $trackedFeatureList,
        Reverse @ IntegerDigits[ FromDigits[ featureString, 36 ], 2, Length @ $trackedFeatureList ],
        1
    ];

getFeaturesFromSessionID[ _ ] := { };

getFeaturesFromSessionID // endDefinition;

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
        If[ MatchQ[ result, _HTTPResponse ],
            result,
            emptyResponse[ 500 ]
        ]
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
   browser context is rejected with a 403. *)
$allowedOriginSuffixes = { "wolframcloud.com", "wolfram.com" };

originAllowedQ // beginDefinition;
originAllowedQ[ headers_Association ] := originAllowedQ @ Lookup[ headers, "origin", Missing[ "Absent" ] ];
originAllowedQ[ _Missing ] := True;
originAllowedQ[ origin_String ] := allowedOriginHostQ @ URLParse[ origin, "Domain" ];
originAllowedQ[ _ ] := True;
originAllowedQ // endDefinition;

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
   Events data frame for text/event-stream. *)
makeResponseString // beginDefinition;
makeResponseString[ "application/json", result_ ] :=
    Developer`WriteRawJSONString[ result, "Compact" -> True ];
makeResponseString[ "text/event-stream", result_ ] :=
    "data: " <> Developer`WriteRawJSONString[ result, "Compact" -> True ] <> "\n\n";
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
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
