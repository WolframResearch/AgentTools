(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Server`UsageData`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];
Needs[ "Wolfram`AgentTools`Server`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Overview*)
(*
    Basic usage tracking for the local (stdio) MCP servers. See docs/usage-data.md.

    What is recorded for a server session:
      * the client information from the legacy "initialize" request (its "params": clientInfo, protocolVersion,
        capabilities), or, for a modern client (protocol 2026-07-28 and later, which has no initialize), the same
        information from the _meta of its first valid request
      * one event per "tools/call" and "prompts/get" request: the tool/prompt name, whether it succeeded, and when
      * the product identity information that the paclet manager sends with every request to the paclet server
        (license, activation key, machine ID, product, release, system ID, language, license process counts, and the
        cloud user UUID when connected; see $productIdentityInfo). This identifies the installation, so the data is
        not anonymous.
      * whether the server runs under the standalone MCP server product, and the information that product publishes
        about itself ($StandaloneMCPServer and $StandaloneMCPServerInformation, defined in Server.wl and set only by
        the standalone application; False and <| |> everywhere else)
    No tool arguments, prompt arguments, results, or any other content are ever recorded (see recordUsageData0).

    Tracking is enabled for a session when the SUBMIT_USAGE_DATA environment variable holds a boolean (written into
    the client's configuration by the "SubmitUsageData" option of InstallMCPServer), or -- when that variable is
    absent -- when the server's "EnableUsageData" property is explicitly True (the built-in servers set it; see
    DefaultServers.wl) and the user has not opted out globally: the preferences panel's checkbox keeps its state in
    $rootPath/GlobalSettings.wxf (see getGlobalUsageDataSetting), which every later session reads when it starts.
    Nothing is tracked for cloud-deployed servers.

    The session's data lives in $rootPath/UsageData/<session id>.wxf. The file is rewritten whenever the data changes
    and touched hourly by a scheduled task, so its modification time tells whether the session is still alive even
    when the client has been idle. A server session cannot know that it is over, so submission happens later: a
    subsequent session (of any tracked server) submits the files that have not been modified for a day to
    $usageDataEndpoint as JSON and deletes them, under a file lock so that only one process submits at a time.
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$usageDataEndpoint          = "https://www.wolframcloud.com/obj/wolframai-content/api/1.0/usage";
$usageDataSubmitTimeout     = 10;                        (* seconds allowed for each HTTP request *)
$usageDataSubmitDelay       = Quantity[ 10, "Seconds" ]; (* delay after server start before finished sessions are submitted *)
$usageDataKeepAliveInterval = Quantity[ 1, "Hours" ];    (* how often the current session's file is touched *)
$usageDataStaleAge          = 24 * 3600;                 (* seconds since the last touch before a session counts as finished *)
$usageDataMaxAge            = 30 * 24 * 3600;            (* seconds after which a session that could not be submitted is discarded *)
$usageDataMaxEvents         = 10000;                     (* maximum number of events recorded per session *)
$usageDataLockTimeout       = 1;                         (* seconds to wait for another process to release the submit lock *)
$usageDataLockLifetime      = 600;                       (* seconds after which a lock left behind by a dead process is broken *)

(* Session state: $mcpSessionID is assigned once per kernel session by initializeUsageData, the rest is only
   populated while tracking is enabled. *)
$usageDataEnabled     = False;
$mcpSessionID         = None;
$mcpClientInformation = Null;
$usageDataServerName  = Null;
$usageKeepAliveTask   = None;
$usageSubmitTask      = None;

$usageEvents := $usageEvents = Internal`Bag[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Paths*)
$usageDataPath  := FileNameJoin @ { $rootPath, "UsageData" };
$usageStatsFile := FileNameJoin @ { $usageDataPath, $mcpSessionID <> ".wxf" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*usageDataQuietly*)
(* Usage tracking must never interfere with the server, so failures in it are logged and otherwise ignored. *)
usageDataQuietly // beginDefinition;
usageDataQuietly // Attributes = { HoldFirst };

usageDataQuietly[ eval_ ] :=
    With[ { result = Quiet @ catchAlways @ eval },
        If[ FailureQ @ result, writeLog[ "UsageDataFailure" -> result ] ];
        result
    ];

usageDataQuietly // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*usageDataEnabledQ*)
(* SUBMIT_USAGE_DATA takes precedence when it holds a boolean: an explicit true also tracks custom servers and an
   explicit false opts a built-in server out. Otherwise only servers whose "EnableUsageData" property is exactly
   True are tracked, and only if the user has not opted out globally (getGlobalUsageDataSetting). *)
usageDataEnabledQ // beginDefinition;
usageDataEnabledQ[ obj_ ] := usageDataEnabledQ[ obj, booleanEnvironment[ "SUBMIT_USAGE_DATA" ] ];
usageDataEnabledQ[ _, enabled: True|False ] := enabled;
usageDataEnabledQ[ obj_MCPServerObject, None ] := obj[ "EnableUsageData" ] === True && getGlobalUsageDataSetting[ ];
usageDataEnabledQ[ _, None ] := False;
usageDataEnabledQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*booleanEnvironment*)
booleanEnvironment // beginDefinition;
booleanEnvironment[ name_String ] := booleanString @ Environment @ name;
booleanEnvironment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*booleanString*)
booleanString // beginDefinition;

booleanString[ value_String ] :=
    Switch[ ToLowerCase @ StringTrim @ value,
        "true"  | "yes" | "on"  | "1", True,
        "false" | "no"  | "off" | "0", False,
        _                            , None
    ];

booleanString[ _ ] := None;

booleanString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Global Setting*)
(* The opt-out made with the preferences panel's checkbox (usageDataCheckbox in PreferencesContent.wl) is stored as
   the "SubmitUsageData" entry of the global settings file (see Files.wl), where every later server session finds it,
   so nothing has to be re-deployed when it changes. Only an explicit False opts out: a missing setting (or file), or
   anything else, means the default, which is to share usage data. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getGlobalUsageDataSetting*)
getGlobalUsageDataSetting // beginDefinition;
getGlobalUsageDataSetting[ ] := getGlobalSetting[ "SubmitUsageData" ] =!= False;
getGlobalUsageDataSetting // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*setGlobalUsageDataSetting*)
setGlobalUsageDataSetting // beginDefinition;
setGlobalUsageDataSetting[ setting: True|False ] := setGlobalSetting[ "SubmitUsageData", setting ];
setGlobalUsageDataSetting // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*initializeUsageData*)
(* Called once by the local transport after the server state has been built. Always assigns a fresh $mcpSessionID;
   when tracking is enabled for the server it also starts the keep-alive task and schedules the submission of
   finished sessions. Returns whether tracking is enabled. *)
initializeUsageData // beginDefinition;
initializeUsageData[ obj_ ] := usageDataQuietly @ initializeUsageData0 @ obj;
initializeUsageData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*initializeUsageData0*)
initializeUsageData0 // beginDefinition;

initializeUsageData0[ obj_ ] := Enclose[
    Module[ { enabled },
        stopUsageDataTasks[ ];
        $usageDataEnabled     = False;
        $mcpSessionID         = ConfirmBy[ CreateUUID[ ], StringQ, "SessionID" ];
        $mcpClientInformation = Null;
        $usageEvents          = Internal`Bag[ ];
        $usageDataServerName  = Replace[ obj[ "Name" ], Except[ _String ] -> Null ];
        enabled = ConfirmMatch[ usageDataEnabledQ @ obj, True|False, "Enabled" ];
        writeLog[ "UsageData" -> <| "SessionID" -> $mcpSessionID, "Enabled" -> enabled |> ];
        If[ enabled, startUsageDataTasks[ ] ];
        $usageDataEnabled = enabled
    ],
    throwInternalFailure
];

initializeUsageData0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*startUsageDataTasks*)
startUsageDataTasks // beginDefinition;

startUsageDataTasks[ ] :=
    With[ { interval = $usageDataKeepAliveInterval, delay = $usageDataSubmitDelay },
        $usageKeepAliveTask = SessionSubmit @ ScheduledTask[ usageDataQuietly @ touchUsageStatsFile[ ], interval ];
        $usageSubmitTask = SessionSubmit @ ScheduledTask[ usageDataQuietly @ submitUsageData[ ], { delay }, AutoRemove -> True ];
        Null
    ];

startUsageDataTasks // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stopUsageDataTasks*)
stopUsageDataTasks // beginDefinition;

stopUsageDataTasks[ ] := (
    Scan[ removeUsageDataTask, { $usageKeepAliveTask, $usageSubmitTask } ];
    $usageKeepAliveTask = None;
    $usageSubmitTask    = None;
);

stopUsageDataTasks // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeUsageDataTask*)
removeUsageDataTask // beginDefinition;
removeUsageDataTask[ task_TaskObject ] := Quiet @ TaskRemove @ task;
removeUsageDataTask[ _ ] := Null;
removeUsageDataTask // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*recordUsageData*)
(* Called by the local read loop for every request once it has been handled. A no-op unless tracking is enabled. *)
recordUsageData // beginDefinition;
recordUsageData[ method_, msg_, response_ ] /; $usageDataEnabled := usageDataQuietly @ recordUsageData0[ method, msg, response ];
recordUsageData[ _, _, _ ] := Null;
recordUsageData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*recordUsageData0*)
(* Only the requested name is taken from a message, and only when it names one of the server's tools/prompts, so a
   made-up name cannot smuggle arbitrary text into the data. Arguments are never looked at. *)
recordUsageData0 // beginDefinition;

recordUsageData0[ "initialize", msg_Association, _ ] :=
    setClientInformation @ msg[ "params" ];

(* A modern client has no initialize request, so its client information is taken from the first valid modern request: *)
recordUsageData0[ method_, msg_Association, response_ ] /;
    $mcpClientInformation === Null && modernRequestQ[ method, msg ] && modernRequestError @ msg === None := (
        setClientInformation @ modernClientInformation @ msg;
        recordUsageData0[ method, msg, response ]
    );

recordUsageData0[ "tools/call", msg_Association, response_ ] :=
    recordUsageEvent[ "ToolCall", requestedName[ msg, $llmTools ], toolCallSuccessQ @ response ];

recordUsageData0[ "prompts/get", msg_Association, response_ ] :=
    recordUsageEvent[ "PromptGet", requestedName[ msg, $promptLookup ], responseSuccessQ @ response ];

recordUsageData0[ _, _, _ ] :=
    Null;

recordUsageData0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*requestedName*)
requestedName // beginDefinition;
requestedName[ msg_Association, known_ ] := requestedName[ msg[ "params", "name" ], known ];
requestedName[ name_String, known_Association ] /; KeyExistsQ[ known, name ] := name;
requestedName[ _, _ ] := Null;
requestedName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*responseSuccessQ*)
(* The response as produced by handleMethod: a JSON-RPC result or error, or a Failure for an internal error. *)
responseSuccessQ // beginDefinition;
responseSuccessQ[ KeyValuePattern[ "error" -> _ ] ] := False;
responseSuccessQ[ KeyValuePattern[ "result" -> _ ] ] := True;
responseSuccessQ[ _ ] := False;
responseSuccessQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolCallSuccessQ*)
(* Tool errors are reported inside a successful JSON-RPC result via "isError". *)
toolCallSuccessQ // beginDefinition;
toolCallSuccessQ[ KeyValuePattern[ "result" -> KeyValuePattern[ "isError" -> True ] ] ] := False;
toolCallSuccessQ[ response_ ] := responseSuccessQ @ response;
toolCallSuccessQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setClientInformation*)
setClientInformation // beginDefinition;

setClientInformation[ params_ ] := (
    $mcpClientInformation = Replace[ params, Except[ _Association ] -> Null ];
    writeUsageDataFile[ ]
);

setClientInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modernClientInformation*)
(* The client information of a modern request, in the shape of legacy initialize params *)
modernClientInformation // beginDefinition;

modernClientInformation[ msg_Association ] := DeleteMissing @ <|
    "protocolVersion" -> requestMetaValue[ msg, "protocolVersion" ],
    "capabilities"    -> requestMetaValue[ msg, "clientCapabilities" ],
    "clientInfo"      -> requestMetaValue[ msg, "clientInfo" ]
|>;

modernClientInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*recordUsageEvent*)
recordUsageEvent // beginDefinition;

recordUsageEvent[ type_String, name: _String|Null, success: True|False ] /;
    Internal`BagLength @ $usageEvents < $usageDataMaxEvents := (
        Internal`StuffBag[
            $usageEvents,
            <| "Type" -> type, "Name" -> name, "Success" -> success, "Timestamp" -> AbsoluteTime[ TimeZone -> 0 ] |>
        ];
        writeUsageDataFile[ ]
    );

(* Event limit reached: keep the session's data as is *)
recordUsageEvent[ _String, _String|Null, True|False ] := Null;

recordUsageEvent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Session File*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*usageDataPayload*)
(* The data stored in the session file, and later submitted as JSON (usageDataJSON). Kernel values are kept as they
   are here, including ones that JSON cannot represent (None, Infinity, dates, ...); those are converted to strings
   when the JSON is written. *)
usageDataPayload // beginDefinition;

usageDataPayload[ ] := Enclose[
    <|
        (* MCP information *)
        "MCPSessionID"      -> $mcpSessionID,
        "ServerName"        -> $usageDataServerName,
        "ClientInformation" -> $mcpClientInformation,
        "Events"            -> ConfirmBy[ Internal`BagPart[ $usageEvents, All ], ListQ, "Events" ],

        (* Standalone MCP server information *)
        "StandaloneMCPServer" -> ConfirmBy[ $StandaloneMCPServer, BooleanQ, "StandaloneMCPServer" ],

        "StandaloneMCPServerInformation" -> ConfirmBy[
            $StandaloneMCPServerInformation,
            AssociationQ,
            "StandaloneMCPServerInformation"
        ],

        (* Product identity information *)
        ConfirmBy[ $productIdentityInfo, AssociationQ, "ProductIdentityInfo" ],

        (* Other *)
        "PacletVersion" -> ConfirmBy[ $pacletVersion, StringQ, "PacletVersion" ],
        "LastUpdated"   -> AbsoluteTime[ TimeZone -> 0 ]
    |>,
    throwInternalFailure
];

usageDataPayload // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$productIdentityInfo*)
(* The product identity information that the paclet manager sends as HTTP headers with every request to the paclet
   server (PacletManager`Package`$productIdentityHeaders, used by PacletManager`Package`downloadPaclet and the other
   paclet server requests), so Wolfram already receives it from every installation that looks up or installs paclets.
   It identifies the installation (and the cloud user, when the kernel is connected), which is why the usage data is
   not anonymous.

   The values are stored in the session file as they are. Those that JSON cannot represent, e.g. Infinity for an
   unlimited process count and None for $CloudUserUUID without a cloud connection, become their InputForm strings
   ("Infinity", "None") when the payload is written as JSON (see usageDataJSON, and jsonConvert in Files.wl). The
   values are read again on every write of the session file, so a kernel that connects to the cloud later in the
   session picks up the CloudUserUUID. *)
$productIdentityInfo := <|
    "ActivationKey"          -> $ActivationKey,
    "CloudUserUUID"          -> $CloudUserUUID,
    "Language"               -> $Language,
    "LicenseID"              -> $LicenseID,
    "LicenseProcesses"       -> $LicenseProcesses,
    "LicenseSubprocesses"    -> $LicenseSubprocesses,
    "MachineID"              -> $MachineID,
    "MaxLicenseProcesses"    -> $MaxLicenseProcesses,
    "MaxLicenseSubprocesses" -> $MaxLicenseSubprocesses,
    "ProductIDName"          -> SystemInformation[ "Kernel", "ProductIDName" ],
    "ReleaseID"              -> SystemInformation[ "Kernel", "ReleaseID" ],
    "SystemID"               -> $SystemID
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*usageDataJSON*)
(* The payload as compact JSON, encoded as UTF-8 bytes so that the HTTP body is exactly these bytes (a String body
   would be encoded by URLRead). writeRawJSONString converts the values that JSON cannot represent (None, Infinity,
   dates, anything the standalone application puts in $StandaloneMCPServerInformation, ...) to strings; see
   jsonConvert in Files.wl. *)
usageDataJSON // beginDefinition;
usageDataJSON[ payload_Association ] := StringToByteArray[ writeRawJSONString[ payload, "Compact" -> True ], "UTF-8" ];
usageDataJSON // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeUsageDataFile*)
(* The file is rewritten in full whenever the session's data changes. *)
writeUsageDataFile // beginDefinition;

writeUsageDataFile[ ] := writeUsageDataFile @ $usageStatsFile;

writeUsageDataFile[ file_String ] := Enclose[
    ConfirmBy[ writeWXFFile[ file, usageDataPayload[ ] ], FileExistsQ, "Write" ],
    throwInternalFailure
];

writeUsageDataFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*touchUsageStatsFile*)
(* Keeps the modification time of the current session's file current while the session is alive, so an idle session
   is not mistaken for a finished one. Does nothing before the file has been written. *)
touchUsageStatsFile // beginDefinition;
touchUsageStatsFile[ ] := touchUsageStatsFile @ $usageStatsFile;
touchUsageStatsFile[ file_String ] /; FileExistsQ @ file := (SetFileDate @ file; file);
touchUsageStatsFile[ _ ] := Null;
touchUsageStatsFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Submission*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*submitUsageData*)
(* Submits the files of finished sessions (see staleUsageFileQ) and deletes them afterward. Runs under a file lock
   so that concurrently starting servers do not submit the same file twice; when another process holds the lock,
   this one simply skips its turn. Returns the files that were submitted or discarded. *)
submitUsageData // beginDefinition;

submitUsageData[ ] := submitUsageData @ $usageDataPath;

submitUsageData[ dir_String ] /; ! DirectoryQ @ dir := { };

submitUsageData[ dir_String ] := Enclose[
    Module[ { lock, result },
        lock = ConfirmBy[ FileNameJoin @ { dir, "Submit.lock" }, StringQ, "Lock" ];
        result = With[ { timeout = $usageDataLockTimeout, lifetime = $usageDataLockLifetime },
            WithLock[
                File @ lock,
                submitStaleUsageFiles @ dir,
                TimeConstraint  -> timeout,
                PersistenceTime -> lifetime
            ]
        ];
        If[ ListQ @ result,
            result,
            writeLog[ "UsageDataSubmitSkipped" -> result ];
            { }
        ]
    ],
    throwInternalFailure
];

submitUsageData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*submitStaleUsageFiles*)
submitStaleUsageFiles // beginDefinition;

submitStaleUsageFiles[ dir_String ] := Enclose[
    Catch @ Module[ { files, processed = { } },
        files = ConfirmMatch[ staleUsageFiles @ dir, { ___String }, "Files" ];
        Scan[
            Function[ file,
                If[ MatchQ[ submitUsageFile @ file, "Submitted"|"Discarded" ],
                    AppendTo[ processed, file ],
                    (* A failed submission is most likely a connectivity problem that would affect the remaining
                       files too, so stop here; they will be tried again in a later session *)
                    Throw @ processed
                ]
            ],
            files
        ];
        processed
    ],
    throwInternalFailure
];

submitStaleUsageFiles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*staleUsageFiles*)
(* Oldest first *)
staleUsageFiles // beginDefinition;
staleUsageFiles[ dir_String ] := ReverseSortBy[ Select[ FileNames[ "*.wxf", dir ], staleUsageFileQ ], fileAge ];
staleUsageFiles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*staleUsageFileQ*)
(* A session is considered finished once its file has not been touched for $usageDataStaleAge seconds. The current
   session's own file is never stale. *)
staleUsageFileQ // beginDefinition;
staleUsageFileQ[ file_String ] := ! currentUsageFileQ @ file && TrueQ[ fileAge @ file > $usageDataStaleAge ];
staleUsageFileQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*currentUsageFileQ*)
currentUsageFileQ // beginDefinition;
currentUsageFileQ[ file_String ] := StringQ @ $mcpSessionID && FileBaseName @ file === $mcpSessionID;
currentUsageFileQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fileAge*)
(* Seconds since the file was last modified *)
fileAge // beginDefinition;
fileAge[ file_String ] := UnixTime[ ] - UnixTime @ FileDate[ file, "Modification" ];
fileAge // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*submitUsageFile*)
submitUsageFile // beginDefinition;

submitUsageFile[ file_String ] := Enclose[
    Catch @ Module[ { data },

        (* Sessions that could not be submitted for a long time (e.g. from a machine that has been offline) are dropped *)
        If[ TrueQ[ fileAge @ file > $usageDataMaxAge ], Throw @ discardUsageFile[ file, "Expired" ] ];

        (* Files that cannot be read cannot be submitted either *)
        data = Quiet @ readWXFFile @ file;
        If[ ! AssociationQ @ data, Throw @ discardUsageFile[ file, "Unreadable" ] ];

        If[ TrueQ @ submitUsagePayload @ data,
            Quiet @ DeleteFile @ file;
            writeLog[ "UsageDataSubmitted" -> file ];
            "Submitted",
            writeLog[ "UsageDataSubmitFailed" -> file ];
            "Failed"
        ]
    ],
    throwInternalFailure
];

submitUsageFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*discardUsageFile*)
discardUsageFile // beginDefinition;

discardUsageFile[ file_String, reason_String ] := (
    Quiet @ DeleteFile @ file;
    writeLog[ "UsageDataDiscarded" -> <| "File" -> file, "Reason" -> reason |> ];
    "Discarded"
);

discardUsageFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*submitUsagePayload*)
(* POSTs one session's data as JSON. Returns True when the endpoint accepted it. *)
submitUsagePayload // beginDefinition;

submitUsagePayload[ payload_Association ] := Enclose[
    Module[ { json, request, response },
        json = ConfirmBy[ usageDataJSON @ payload, ByteArrayQ, "JSON" ];
        request = HTTPRequest[
            $usageDataEndpoint,
            <| "Method" -> "POST", "ContentType" -> "application/json", "Body" -> json |>
        ];
        response = Quiet @ URLRead[ request, TimeConstraint -> $usageDataSubmitTimeout ];
        MatchQ[ response, _HTTPResponse ] && TrueQ[ 200 <= response[ "StatusCode" ] < 300 ]
    ],
    throwInternalFailure
];

submitUsagePayload // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
