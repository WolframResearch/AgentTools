(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`MCPClientRequests`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Pending-Request Registry*)
$mcpClientRequests = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*sendClientRequest*)
sendClientRequest // beginDefinition;

sendClientRequest[ method_String, params_, handler_ ] :=
    Module[ { uuid, request },
        uuid    = CreateUUID[ ];
        request = <|
            "jsonrpc" -> "2.0",
            "id"      -> uuid,
            "method"  -> method,
            "params"  -> params
        |>;
        $mcpClientRequests[ uuid ] = <|
            "id"      -> uuid,
            "request" -> request,
            "handler" -> handler
        |>;
        WriteLine[ "stdout", Developer`WriteRawJSONString[ sanitizeResponse @ request, "Compact" -> True ] ];
        writeLog[ "ClientRequest" -> request ];
        uuid
    ];

sendClientRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*handleClientResponse*)
handleClientResponse // beginDefinition;

handleClientResponse[ id_String, message_Association ] :=
    Catch @ Module[ { entry, handler, request },
        entry = Lookup[ $mcpClientRequests, id, None ];
        If[ entry === None, Throw @ Null ];
        handler = entry[ "handler" ];
        request = entry[ "request" ];
        KeyDropFrom[ $mcpClientRequests, id ];
        handler[ request, message ]
    ];

handleClientResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*handleNotification*)
handleNotification // beginDefinition;

handleNotification[ "notifications/initialized"        , msg_ ] := onClientInitialized @ msg;
handleNotification[ "notifications/roots/list_changed" , msg_ ] := onRootsListChanged @ msg;
handleNotification[ _, _ ] := Null;

handleNotification // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $mcpClientRequests = <| |>;
];

End[ ];
EndPackage[ ];
