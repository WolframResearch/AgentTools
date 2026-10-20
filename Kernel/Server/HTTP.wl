(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Server`HTTP`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];
Needs[ "Wolfram`AgentTools`Server`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Overview*)
(*
    Transport-agnostic pieces of the MCP Streamable HTTP transport, shared by the cloud transport (Cloud.wl, which
    receives requests through HTTPRequestData) and the socket transport (Socket.wl, which parses raw HTTP itself).
    Both represent a request as an association with the keys "Method", "Headers" (a list of rules or an association)
    and "BodyByteArray" (or "Body", a string), so the accessors below work for either one.

    Everything here is pure: no front end calls, no global state. The symbols are declared in Server.wl so that both
    transports can reach them.
*)

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
    With[ { parsed = readRequestJSON @ str },
        If[ AssociationQ @ parsed, parsed, $Failed ]
    ];
parseRequestBodyString[ _ ] := $Failed;
parseRequestBodyString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*requestBodyJSON*)
(* The request body as a JSON value (an association for an object, a list for an array, ...), or $Failed if the body is
   missing, is not valid UTF-8, or is not valid JSON. Unlike parseRequestBody, this lets a transport tell a parse
   error (JSON-RPC -32700) apart from valid JSON that is not a single message (-32600), e.g. a batch. *)
requestBodyJSON // beginDefinition;
requestBodyJSON[ request_Association ] := readRequestJSON @ requestBodyString @ request;
requestBodyJSON[ _ ] := $Failed;
requestBodyJSON // endDefinition;

readRequestJSON // beginDefinition;
readRequestJSON[ str_String ] := Quiet @ Developer`ReadRawJSONString @ str;
readRequestJSON[ _ ] := $Failed;
readRequestJSON // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Transport Validation*)

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
        types = acceptedMediaTypes @ accept;
        Which[
            ContainsAny[ types, { "application/json", "*/*", "application/*" } ], "application/json",
            MemberQ[ types, "text/event-stream" ],                                 "text/event-stream",
            True,                                                                  None
        ]
    ];
parseAcceptHeader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acceptsEventStreamQ*)
(* True when the Accept header explicitly lists text/event-stream, i.e. when a response can be streamed as Server-Sent
   Events. Wildcards do not count: a client that did not ask for an event stream gets a single JSON response. *)
acceptsEventStreamQ // beginDefinition;
acceptsEventStreamQ[ headers_Association ] := acceptsEventStreamQ @ Lookup[ headers, "accept", Missing[ "Absent" ] ];
acceptsEventStreamQ[ accept_String ] := MemberQ[ acceptedMediaTypes @ accept, "text/event-stream" ];
acceptsEventStreamQ[ _ ] := False;
acceptsEventStreamQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acceptedMediaTypes*)
(* The lowercased media types listed in an Accept header, without their parameters (e.g. ";q=0.9"). *)
acceptedMediaTypes // beginDefinition;
acceptedMediaTypes[ accept_String ] := ToLowerCase @ StringTrim @ First[ StringSplit[ #, ";" ], "" ] & /@ StringSplit[ accept, "," ];
acceptedMediaTypes // endDefinition;

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
(* ::Section::Closed:: *)
(*JSON-RPC Dispatch*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*jsonRPCMessageType*)
(* The kind of a single JSON-RPC message, which decides how a transport answers it:

     "Request"       a string method (not a notification's) and an id that is a string or a number: a reply is owed
     "Notification"  a "notifications/..." method, or any other string method without an id (or with a null id, which
                     MCP forbids): no reply is owed. Only "notifications/..." methods may be dispatched: a request that
                     came without an id (e.g. a tools/call) must not be evaluated.
     "Response"      no method, an id, and exactly one of "result" and "error": a client's answer to a server request
     "Invalid"       anything else, e.g. a method that is not a string, or an id with neither a method nor a result; the
                     client may be waiting for a reply to its id, so it gets an Invalid Request error *)
jsonRPCMessageType // beginDefinition;

jsonRPCMessageType[ message_Association ] :=
    With[ { method = Lookup[ message, "method", Missing[ "Absent" ] ], id = Lookup[ message, "id", Missing[ "Absent" ] ] },
        Which[
            StringQ @ method && StringStartsQ[ method, "notifications/" ],
                "Notification",
            StringQ @ method && (StringQ @ id || NumberQ @ id),
                "Request",
            StringQ @ method && MatchQ[ id, Null | _Missing ],
                "Notification",
            MissingQ @ method && ! MissingQ @ id && Count[ Keys @ message, "result" | "error" ] === 1,
                "Response",
            True,
                "Invalid"
        ]
    ];

jsonRPCMessageType // endDefinition;

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
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
