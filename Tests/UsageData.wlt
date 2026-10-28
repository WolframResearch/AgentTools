(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/UsageData.wlt:7,1-12,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/UsageData.wlt:14,1-19,2"
]

VerificationTest[
    Get[ FileNameJoin @ { DirectoryName @ $TestFileName, "MCPServerTestUtilities.wl" } ];
    (* Set the source directory so the test utilities can find Scripts/StartMCPServer.wls *)
    Wolfram`AgentToolsTests`MCPServerTestUtilities`$MCPTestSourceDirectory = DirectoryName[ $TestFileName, 2 ],
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "LoadTestUtilities@@Tests/UsageData.wlt:21,1-28,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Fixtures*)
usageDataEnabledQ   = Wolfram`AgentTools`Server`UsageData`Private`usageDataEnabledQ;
booleanString       = Wolfram`AgentTools`Server`UsageData`Private`booleanString;
initializeUsageData = Wolfram`AgentTools`Server`initializeUsageData;
recordUsageData     = Wolfram`AgentTools`Server`recordUsageData;
stopUsageDataTasks  = Wolfram`AgentTools`Server`UsageData`Private`stopUsageDataTasks;
usageDataPayload    = Wolfram`AgentTools`Server`UsageData`Private`usageDataPayload;
usageDataJSON       = Wolfram`AgentTools`Server`UsageData`Private`usageDataJSON;
touchUsageStatsFile = Wolfram`AgentTools`Server`UsageData`Private`touchUsageStatsFile;
staleUsageFileQ     = Wolfram`AgentTools`Server`UsageData`Private`staleUsageFileQ;
fileAge             = Wolfram`AgentTools`Server`UsageData`Private`fileAge;
submitUsageData     = Wolfram`AgentTools`Server`UsageData`Private`submitUsageData;
submitUsagePayload  = Wolfram`AgentTools`Server`UsageData`Private`submitUsagePayload;
getGlobalUsageDataSetting = Wolfram`AgentTools`Common`getGlobalUsageDataSetting;
setGlobalUsageDataSetting = Wolfram`AgentTools`Common`setGlobalUsageDataSetting;

usageStatsFile[ ]      := Wolfram`AgentTools`Server`UsageData`Private`$usageStatsFile;
usageDataPath[ ]       := Wolfram`AgentTools`Server`UsageData`Private`$usageDataPath;
productIdentityInfo[ ] := Wolfram`AgentTools`Server`UsageData`Private`$productIdentityInfo;
sessionData[ ]         := Developer`ReadWXFFile @ usageStatsFile[ ];
usageEvents[ ]         := Internal`BagPart[ Wolfram`AgentTools`Server`$usageEvents, All ];
globalSettingsFile[ ]  := Wolfram`AgentTools`Common`$globalSettingsFile;

(* The product identity fields of the payload (see docs/usage-data.md) *)
$productIdentityKeys = {
    "ActivationKey", "CloudUserUUID", "Language", "LicenseID", "LicenseProcesses", "LicenseSubprocesses",
    "MachineID", "MaxLicenseProcesses", "MaxLicenseSubprocesses", "ProductIDName", "ReleaseID", "SystemID"
};

(* Every field of a session file (the product identity information is spliced in at the top level) *)
$payloadKeys = Join[
    { "ClientInformation", "Events", "LastUpdated", "MCPSessionID", "PacletVersion", "ServerName" },
    { "StandaloneMCPServer", "StandaloneMCPServerInformation" },
    $productIdentityKeys
];

(* What the JSON holds for a top-level payload value: JSON-representable values as they are, anything else
   (Infinity, None, ...) as its InputForm string (see jsonConvert in Kernel/Files.wl) *)
jsonValue[ value: _Integer|_Real|_String|Null|True|False|_List|_Association ] := value;
jsonValue[ value_ ] := ToString[ value, InputForm ];

(* usageDataJSON gives the UTF-8 bytes of the JSON that is submitted *)
readUsageJSON[ bytes_ByteArray ] := Developer`ReadRawJSONString @ ByteArrayToString[ bytes, "UTF-8" ];

$testTool = LLMTool[ "PrimeFinder", { "n" -> "Integer" }, Prime[ #n ] & ];

makeTempRoot[ ] := FileNameJoin @ { $TemporaryDirectory, "AgentToolsUsageData_" <> CreateUUID[ ] };

(* Evaluates body as if inside a tracked server session (fresh session ID, data under a temporary root directory),
   then removes the directory again. *)
withUsageSession // Attributes = { HoldFirst };
withUsageSession[ body_ ] :=
    Module[ { root, result },
        root = makeTempRoot[ ];
        result = Block[
            {
                Wolfram`AgentTools`Common`$rootPath                              = root,
                Wolfram`AgentTools`Server`$usageDataEnabled                      = True,
                Wolfram`AgentTools`Server`$mcpSessionID                          = CreateUUID[ ],
                Wolfram`AgentTools`Server`$mcpClientInformation                  = Null,
                Wolfram`AgentTools`Server`$usageEvents                           = Internal`Bag[ ],
                Wolfram`AgentTools`Server`UsageData`Private`$usageDataServerName = "TestServer",
                Wolfram`AgentTools`Server`$llmTools                              = <| "PrimeFinder" -> $testTool |>,
                Wolfram`AgentTools`Server`$promptLookup                          = <| "Greet" -> <| "Name" -> "Greet", "Type" -> "Text", "Content" -> "Hello" |> |>
            },
            body
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        result
    ];

(* A session file for a session named `name` whose last modification was `age` ago *)
makeUsageFile[ dir_, name_, age_ ] :=
    With[ { file = FileNameJoin @ { dir, name <> ".wxf" } },
        Developer`WriteWXFFile[ file, <| "MCPSessionID" -> name, "Events" -> { } |> ];
        SetFileDate[ file, Now - age, "Modification" ];
        file
    ];

$initMessage = <|
    "jsonrpc" -> "2.0",
    "id"      -> 0,
    "method"  -> "initialize",
    "params"  -> <|
        "clientInfo"      -> <| "name" -> "test-client", "version" -> "1.2.3" |>,
        "protocolVersion" -> "2025-11-25",
        "capabilities"    -> <| "roots" -> <| |> |>
    |>
|>;

$initResponse = <| "jsonrpc" -> "2.0", "id" -> 0, "result" -> <| "protocolVersion" -> "2025-11-25" |> |>;

$toolCallMessage = <|
    "jsonrpc" -> "2.0",
    "id"      -> 1,
    "method"  -> "tools/call",
    "params"  -> <| "name" -> "PrimeFinder", "arguments" -> <| "n" -> 12345 |> |>
|>;

$toolCallResponse = <|
    "jsonrpc" -> "2.0",
    "id"      -> 1,
    "result"  -> <| "content" -> { <| "type" -> "text", "text" -> "SECRET-RESULT" |> }, "isError" -> False |>
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
VerificationTest[
    Wolfram`AgentTools`Server`UsageData`Private`$usageDataEndpoint,
    "https://www.wolframcloud.com/obj/wolframai-content/api/1.0/usage",
    SameTest -> SameQ,
    TestID   -> "UsageData-Endpoint@@Tests/UsageData.wlt:140,1-145,2"
]

(* Outside a server session nothing is tracked *)
VerificationTest[
    {
        Wolfram`AgentTools`Server`$usageDataEnabled,
        Wolfram`AgentTools`Server`$mcpSessionID,
        recordUsageData[ "tools/call", $toolCallMessage, $toolCallResponse ]
    },
    { False, None, Null },
    SameTest -> SameQ,
    TestID   -> "UsageData-DisabledOutsideServer@@Tests/UsageData.wlt:148,1-157,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Global Setting*)
(* The preferences panel's checkbox stores its state as the "SubmitUsageData" entry of the global settings file
   ($rootPath/GlobalSettings.wxf), which is read again by every server session when it starts. *)

(* Nothing stored means the default: usage data is shared, and no file is created just by asking *)
VerificationTest[
    withTemporaryRoot @ { getGlobalUsageDataSetting[ ], FileExistsQ @ globalSettingsFile[ ] },
    { True, False },
    SameTest -> SameQ,
    TestID   -> "GlobalUsageDataSetting-Default@@Tests/UsageData.wlt:166,1-171,2"
]

(* Opting out and back in *)
VerificationTest[
    withTemporaryRoot @ {
        setGlobalUsageDataSetting[ False ],
        getGlobalUsageDataSetting[ ],
        Developer`ReadWXFFile @ globalSettingsFile[ ],
        setGlobalUsageDataSetting[ True ],
        getGlobalUsageDataSetting[ ],
        Developer`ReadWXFFile @ globalSettingsFile[ ]
    },
    { False, False, <| "SubmitUsageData" -> False |>, True, True, <| "SubmitUsageData" -> True |> },
    SameTest -> SameQ,
    TestID   -> "GlobalUsageDataSetting-SetAndGet@@Tests/UsageData.wlt:174,1-186,2"
]

(* Other global settings in the file are left alone *)
VerificationTest[
    withTemporaryRoot @ (
        Wolfram`AgentTools`Common`setGlobalSetting[ "Other", 1 ];
        setGlobalUsageDataSetting[ False ];
        Developer`ReadWXFFile @ globalSettingsFile[ ]
    ),
    <| "Other" -> 1, "SubmitUsageData" -> False |>,
    SameTest -> SameQ,
    TestID   -> "GlobalUsageDataSetting-PreservesOtherSettings@@Tests/UsageData.wlt:189,1-198,2"
]

(* Only an explicit False opts out *)
VerificationTest[
    withTemporaryRoot @ (
        Wolfram`AgentTools`Common`setGlobalSetting[ "SubmitUsageData", "no" ];
        getGlobalUsageDataSetting[ ]
    ),
    True,
    SameTest -> SameQ,
    TestID   -> "GlobalUsageDataSetting-NonBooleanIgnored@@Tests/UsageData.wlt:201,1-209,2"
]

(* The setting can only be set to a boolean *)
VerificationTest[
    withTemporaryRoot @ Wolfram`AgentTools`Common`catchTop @ setGlobalUsageDataSetting[ "no" ],
    Failure[ "AgentTools::Internal", _ ],
    { General::AgentToolsInternal },
    SameTest -> MatchQ,
    TestID   -> "GlobalUsageDataSetting-InvalidValue@@Tests/UsageData.wlt:212,1-218,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*usageDataEnabledQ*)
VerificationTest[
    booleanString /@ { "true", "TRUE", " yes ", "on", "1", "false", "No", "off", "0", "", "maybe", 1, None },
    { True, True, True, True, True, False, False, False, False, None, None, None, None },
    SameTest -> SameQ,
    TestID   -> "UsageData-BooleanString@@Tests/UsageData.wlt:223,1-228,2"
]

$customServer = CreateMCPServer[
    "TestServer_UsageData_" <> CreateUUID[ ],
    LLMConfiguration @ <| "Tools" -> { $testTool } |>
];

(* Without SUBMIT_USAGE_DATA (and without a global opt-out) the server's "EnableUsageData" property decides *)
VerificationTest[
    withTemporaryRoot @ environmentBlock[ "SUBMIT_USAGE_DATA" -> None,
        {
            usageDataEnabledQ @ MCPServerObject[ "Wolfram" ],
            AllTrue[ Values @ $DefaultMCPServers, usageDataEnabledQ ],
            usageDataEnabledQ @ $customServer,
            usageDataEnabledQ @ None
        }
    ],
    { True, True, False, False },
    SameTest -> SameQ,
    TestID   -> "UsageDataEnabledQ-Property@@Tests/UsageData.wlt:236,1-248,2"
]

(* An explicit boolean in SUBMIT_USAGE_DATA takes precedence over the property in both directions *)
VerificationTest[
    environmentBlock[ "SUBMIT_USAGE_DATA" -> "false",
        { usageDataEnabledQ @ MCPServerObject[ "Wolfram" ], usageDataEnabledQ @ $customServer }
    ],
    { False, False },
    SameTest -> SameQ,
    TestID   -> "UsageDataEnabledQ-EnvironmentFalse@@Tests/UsageData.wlt:251,1-258,2"
]

VerificationTest[
    environmentBlock[ "SUBMIT_USAGE_DATA" -> "true",
        { usageDataEnabledQ @ MCPServerObject[ "Wolfram" ], usageDataEnabledQ @ $customServer }
    ],
    { True, True },
    SameTest -> SameQ,
    TestID   -> "UsageDataEnabledQ-EnvironmentTrue@@Tests/UsageData.wlt:260,1-267,2"
]

(* A value that is not a boolean is ignored *)
VerificationTest[
    withTemporaryRoot @ environmentBlock[ "SUBMIT_USAGE_DATA" -> "maybe",
        { usageDataEnabledQ @ MCPServerObject[ "Wolfram" ], usageDataEnabledQ @ $customServer }
    ],
    { True, False },
    SameTest -> SameQ,
    TestID   -> "UsageDataEnabledQ-EnvironmentNonBoolean@@Tests/UsageData.wlt:270,1-277,2"
]

(* A global opt-out (the preferences panel's checkbox) turns tracking off for the built-in servers... *)
VerificationTest[
    withTemporaryRoot @ (
        setGlobalUsageDataSetting[ False ];
        environmentBlock[ "SUBMIT_USAGE_DATA" -> None,
            {
                usageDataEnabledQ @ MCPServerObject[ "Wolfram" ],
                AnyTrue[ Values @ $DefaultMCPServers, usageDataEnabledQ ],
                usageDataEnabledQ @ $customServer
            }
        ]
    ),
    { False, False, False },
    SameTest -> SameQ,
    TestID   -> "UsageDataEnabledQ-GlobalOptOut@@Tests/UsageData.wlt:280,1-294,2"
]

(* ...but an explicit boolean in SUBMIT_USAGE_DATA still takes precedence over it *)
VerificationTest[
    withTemporaryRoot @ (
        setGlobalUsageDataSetting[ False ];
        {
            environmentBlock[ "SUBMIT_USAGE_DATA" -> "true",
                { usageDataEnabledQ @ MCPServerObject[ "Wolfram" ], usageDataEnabledQ @ $customServer }
            ],
            environmentBlock[ "SUBMIT_USAGE_DATA" -> "maybe",
                { usageDataEnabledQ @ MCPServerObject[ "Wolfram" ], usageDataEnabledQ @ $customServer }
            ]
        }
    ),
    { { True, True }, { False, False } },
    SameTest -> SameQ,
    TestID   -> "UsageDataEnabledQ-GlobalOptOutEnvironmentPrecedence@@Tests/UsageData.wlt:297,1-312,2"
]

(* Opting back in restores the default *)
VerificationTest[
    withTemporaryRoot @ (
        setGlobalUsageDataSetting[ False ];
        setGlobalUsageDataSetting[ True ];
        environmentBlock[ "SUBMIT_USAGE_DATA" -> None,
            { usageDataEnabledQ @ MCPServerObject[ "Wolfram" ], usageDataEnabledQ @ $customServer }
        ]
    ),
    { True, False },
    SameTest -> SameQ,
    TestID   -> "UsageDataEnabledQ-GlobalOptIn@@Tests/UsageData.wlt:315,1-326,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*initializeUsageData*)

(* A tracked server: fresh session ID, tracking enabled, keep-alive and submission tasks started, but no file yet *)
VerificationTest[
    Module[ { root, result },
        root = makeTempRoot[ ];
        result = Block[
            {
                Wolfram`AgentTools`Common`$rootPath                             = root,
                Wolfram`AgentTools`Server`$usageDataEnabled                     = False,
                Wolfram`AgentTools`Server`$mcpSessionID                         = None,
                Wolfram`AgentTools`Server`$mcpClientInformation                 = Null,
                Wolfram`AgentTools`Server`$usageEvents                          = Internal`Bag[ ],
                Wolfram`AgentTools`Server`UsageData`Private`$usageKeepAliveTask = None,
                Wolfram`AgentTools`Server`UsageData`Private`$usageSubmitTask    = None
            },
            environmentBlock[ "SUBMIT_USAGE_DATA" -> None,
                WithCleanup[
                    {
                        initializeUsageData @ MCPServerObject[ "Wolfram" ],
                        Wolfram`AgentTools`Server`$usageDataEnabled,
                        StringMatchQ[ Wolfram`AgentTools`Server`$mcpSessionID, Repeated[ HexadecimalCharacter | "-" ] ],
                        Head @ Wolfram`AgentTools`Server`UsageData`Private`$usageKeepAliveTask,
                        Head @ Wolfram`AgentTools`Server`UsageData`Private`$usageSubmitTask,
                        Wolfram`AgentTools`Server`UsageData`Private`$usageDataServerName,
                        DirectoryQ @ usageDataPath[ ]
                    },
                    stopUsageDataTasks[ ]
                ]
            ]
        ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        result
    ],
    { True, True, True, TaskObject, TaskObject, "Wolfram", False },
    SameTest -> SameQ,
    TestID   -> "InitializeUsageData-Enabled@@Tests/UsageData.wlt:333,1-367,2"
]

(* An untracked server still gets a session ID, but nothing else happens *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Server`$usageDataEnabled                     = False,
            Wolfram`AgentTools`Server`$mcpSessionID                         = None,
            Wolfram`AgentTools`Server`UsageData`Private`$usageKeepAliveTask = None,
            Wolfram`AgentTools`Server`UsageData`Private`$usageSubmitTask    = None
        },
        environmentBlock[ "SUBMIT_USAGE_DATA" -> None,
            {
                initializeUsageData @ $customServer,
                Wolfram`AgentTools`Server`$usageDataEnabled,
                StringQ @ Wolfram`AgentTools`Server`$mcpSessionID,
                Wolfram`AgentTools`Server`UsageData`Private`$usageKeepAliveTask,
                Wolfram`AgentTools`Server`UsageData`Private`$usageSubmitTask
            }
        ]
    ],
    { False, False, True, None, None },
    SameTest -> SameQ,
    TestID   -> "InitializeUsageData-Disabled@@Tests/UsageData.wlt:370,1-391,2"
]

(* Opting out via the environment wins over the built-in server's property *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Server`$usageDataEnabled                     = False,
            Wolfram`AgentTools`Server`$mcpSessionID                         = None,
            Wolfram`AgentTools`Server`UsageData`Private`$usageKeepAliveTask = None,
            Wolfram`AgentTools`Server`UsageData`Private`$usageSubmitTask    = None
        },
        environmentBlock[ "SUBMIT_USAGE_DATA" -> "false",
            { initializeUsageData @ MCPServerObject[ "Wolfram" ], Wolfram`AgentTools`Server`$usageDataEnabled }
        ]
    ],
    { False, False },
    SameTest -> SameQ,
    TestID   -> "InitializeUsageData-OptedOut@@Tests/UsageData.wlt:394,1-409,2"
]

(* A global opt-out (the preferences panel's checkbox) is read when the server starts *)
VerificationTest[
    withTemporaryRoot @ Block[
        {
            Wolfram`AgentTools`Server`$usageDataEnabled                     = False,
            Wolfram`AgentTools`Server`$mcpSessionID                         = None,
            Wolfram`AgentTools`Server`UsageData`Private`$usageKeepAliveTask = None,
            Wolfram`AgentTools`Server`UsageData`Private`$usageSubmitTask    = None
        },
        setGlobalUsageDataSetting[ False ];
        environmentBlock[ "SUBMIT_USAGE_DATA" -> None,
            {
                initializeUsageData @ MCPServerObject[ "Wolfram" ],
                Wolfram`AgentTools`Server`$usageDataEnabled,
                StringQ @ Wolfram`AgentTools`Server`$mcpSessionID,
                Wolfram`AgentTools`Server`UsageData`Private`$usageKeepAliveTask,
                Wolfram`AgentTools`Server`UsageData`Private`$usageSubmitTask
            }
        ]
    ],
    { False, False, True, None, None },
    SameTest -> SameQ,
    TestID   -> "InitializeUsageData-GlobalOptOut@@Tests/UsageData.wlt:412,1-434,2"
]

(* Initialization never breaks server startup, even with a bogus server *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Server`$usageDataEnabled                     = False,
            Wolfram`AgentTools`Server`$mcpSessionID                         = None,
            Wolfram`AgentTools`Server`UsageData`Private`$usageKeepAliveTask = None,
            Wolfram`AgentTools`Server`UsageData`Private`$usageSubmitTask    = None
        },
        environmentBlock[ "SUBMIT_USAGE_DATA" -> None, initializeUsageData @ None ]
    ],
    False,
    SameTest -> SameQ,
    TestID   -> "InitializeUsageData-InvalidServer@@Tests/UsageData.wlt:437,1-450,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Recording*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Client Information*)
VerificationTest[
    withUsageSession[
        recordUsageData[ "initialize", $initMessage, $initResponse ];
        With[ { data = sessionData[ ] },
            {
                data[ "MCPSessionID" ] === Wolfram`AgentTools`Server`$mcpSessionID,
                data[ "ClientInformation" ] === $initMessage[ "params" ],
                data[ "Events" ],
                data[ "ServerName" ],
                data[ "StandaloneMCPServer" ],
                data[ "StandaloneMCPServerInformation" ],
                data[ "PacletVersion" ] === Wolfram`AgentTools`Common`$pacletVersion,
                KeyTake[ data, $productIdentityKeys ] === productIdentityInfo[ ],
                Abs[ data[ "LastUpdated" ] - AbsoluteTime[ TimeZone -> 0 ] ] < 60,
                Sort @ Keys @ data
            }
        ]
    ],
    {
        True, True, { }, "TestServer", False, <| |>, True, True, True,
        Sort @ $payloadKeys
    },
    SameTest -> SameQ,
    TestID   -> "RecordUsageData-Initialize@@Tests/UsageData.wlt:459,1-483,2"
]

(* The session file is named after the session ID and lives in $rootPath/UsageData *)
VerificationTest[
    withUsageSession[
        recordUsageData[ "initialize", $initMessage, $initResponse ];
        {
            FileExistsQ @ usageStatsFile[ ],
            FileBaseName @ usageStatsFile[ ] === Wolfram`AgentTools`Server`$mcpSessionID,
            DirectoryName @ usageStatsFile[ ] === FileNameJoin @ { Wolfram`AgentTools`Common`$rootPath, "UsageData" } <> $PathnameSeparator
        }
    ],
    { True, True, True },
    SameTest -> SameQ,
    TestID   -> "RecordUsageData-SessionFileLocation@@Tests/UsageData.wlt:486,1-498,2"
]

(* Malformed initialize parameters are stored as Null rather than failing *)
VerificationTest[
    withUsageSession[
        recordUsageData[ "initialize", <| "method" -> "initialize", "params" -> "bogus" |>, $initResponse ];
        sessionData[ ][ "ClientInformation" ]
    ],
    Null,
    SameTest -> SameQ,
    TestID   -> "RecordUsageData-InitializeInvalidParams@@Tests/UsageData.wlt:501,1-509,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Calls*)
VerificationTest[
    withUsageSession[
        recordUsageData[ "tools/call", $toolCallMessage, $toolCallResponse ];
        sessionData[ ][ "Events" ]
    ],
    { KeyValuePattern @ { "Type" -> "ToolCall", "Name" -> "PrimeFinder", "Success" -> True, "Timestamp" -> _Real } },
    SameTest -> MatchQ,
    TestID   -> "RecordUsageData-ToolCallSuccess@@Tests/UsageData.wlt:514,1-522,2"
]

VerificationTest[
    withUsageSession[
        recordUsageData[ "tools/call", $toolCallMessage, $toolCallResponse ];
        With[ { event = First @ sessionData[ ][ "Events" ] },
            { Sort @ Keys @ event, Abs[ event[ "Timestamp" ] - AbsoluteTime[ TimeZone -> 0 ] ] < 60 }
        ]
    ],
    { { "Name", "Success", "Timestamp", "Type" }, True },
    SameTest -> SameQ,
    TestID   -> "RecordUsageData-ToolCallEventShape@@Tests/UsageData.wlt:524,1-534,2"
]

(* Neither arguments nor results are recorded *)
VerificationTest[
    withUsageSession[
        recordUsageData[ "tools/call", $toolCallMessage, $toolCallResponse ];
        With[ { data = sessionData[ ] },
            { FreeQ[ data, 12345 ], FreeQ[ data, "arguments" ], FreeQ[ data, "SECRET-RESULT" ], FreeQ[ data, "content" ] }
        ]
    ],
    { True, True, True, True },
    SameTest -> SameQ,
    TestID   -> "RecordUsageData-ToolCallNoParameters@@Tests/UsageData.wlt:537,1-547,2"
]

(* Failures: tool errors, unknown tools (name not recorded), internal failures, and JSON-RPC errors *)
VerificationTest[
    withUsageSession[
        recordUsageData[ "tools/call", $toolCallMessage, <| "result" -> <| "content" -> { }, "isError" -> True |> |> ];
        recordUsageData[ "tools/call", <| "params" -> <| "name" -> "NoSuchTool", "arguments" -> <| "n" -> 1 |> |> |>, <| "result" -> <| "content" -> { }, "isError" -> True |> |> ];
        recordUsageData[ "tools/call", $toolCallMessage, Failure[ "AgentTools::Internal", <| |> ] ];
        recordUsageData[ "tools/call", $toolCallMessage, <| "error" -> <| "code" -> -32603, "message" -> "Internal error" |> |> ];
        recordUsageData[ "tools/call", <| "params" -> <| |> |>, <| "result" -> <| "isError" -> True |> |> ];
        Lookup[ sessionData[ ][ "Events" ], { "Name", "Success" } ]
    ],
    { { "PrimeFinder", False }, { Null, False }, { "PrimeFinder", False }, { "PrimeFinder", False }, { Null, False } },
    SameTest -> SameQ,
    TestID   -> "RecordUsageData-ToolCallFailures@@Tests/UsageData.wlt:550,1-562,2"
]

(* Events accumulate in order, and the file always holds all of them *)
VerificationTest[
    withUsageSession[
        recordUsageData[ "initialize", $initMessage, $initResponse ];
        recordUsageData[ "tools/call", $toolCallMessage, $toolCallResponse ];
        recordUsageData[ "tools/call", $toolCallMessage, <| "result" -> <| "content" -> { }, "isError" -> True |> |> ];
        recordUsageData[ "tools/call", $toolCallMessage, $toolCallResponse ];
        { Lookup[ sessionData[ ][ "Events" ], "Success" ], Length @ usageEvents[ ], sessionData[ ][ "ClientInformation" ] === $initMessage[ "params" ] }
    ],
    { { True, False, True }, 3, True },
    SameTest -> SameQ,
    TestID   -> "RecordUsageData-EventsAccumulate@@Tests/UsageData.wlt:565,1-576,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Prompts*)
VerificationTest[
    withUsageSession[
        recordUsageData[ "prompts/get", <| "params" -> <| "name" -> "Greet", "arguments" -> <| "who" -> "SECRET" |> |> |>, <| "result" -> <| "messages" -> { } |> |> ];
        recordUsageData[ "prompts/get", <| "params" -> <| "name" -> "NoSuchPrompt" |> |>, Failure[ "AgentTools::Internal", <| |> ] ];
        With[ { data = sessionData[ ] },
            { Lookup[ data[ "Events" ], { "Type", "Name", "Success" } ], FreeQ[ data, "SECRET" ], FreeQ[ data, "who" ] }
        ]
    ],
    { { { "PromptGet", "Greet", True }, { "PromptGet", Null, False } }, True, True },
    SameTest -> SameQ,
    TestID   -> "RecordUsageData-Prompts@@Tests/UsageData.wlt:581,1-592,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other Requests and Disabled Tracking*)
VerificationTest[
    withUsageSession[
        recordUsageData[ "tools/list", <| "params" -> <| |> |>, <| "result" -> <| "tools" -> { } |> |> ];
        recordUsageData[ "ping", <| |>, <| "result" -> <| |> |> ];
        recordUsageData[ "resources/list", <| |>, <| "result" -> <| "resources" -> { } |> |> ];
        recordUsageData[ "notifications/initialized", <| |>, Null ];
        recordUsageData[ None, <| |>, Null ];
        { FileExistsQ @ usageStatsFile[ ], Length @ usageEvents[ ] }
    ],
    { False, 0 },
    SameTest -> SameQ,
    TestID   -> "RecordUsageData-OtherMethodsIgnored@@Tests/UsageData.wlt:597,1-609,2"
]

VerificationTest[
    withUsageSession[
        Block[ { Wolfram`AgentTools`Server`$usageDataEnabled = False },
            {
                recordUsageData[ "initialize", $initMessage, $initResponse ],
                recordUsageData[ "tools/call", $toolCallMessage, $toolCallResponse ],
                FileExistsQ @ usageStatsFile[ ],
                DirectoryQ @ usageDataPath[ ],
                Wolfram`AgentTools`Server`$mcpClientInformation,
                Length @ usageEvents[ ]
            }
        ]
    ],
    { Null, Null, False, False, Null, 0 },
    SameTest -> SameQ,
    TestID   -> "RecordUsageData-DisabledRecordsNothing@@Tests/UsageData.wlt:611,1-627,2"
]

(* The number of events per session is capped *)
VerificationTest[
    withUsageSession[
        Block[ { Wolfram`AgentTools`Server`UsageData`Private`$usageDataMaxEvents = 3 },
            Do[ recordUsageData[ "tools/call", $toolCallMessage, $toolCallResponse ], 5 ];
            { Length @ usageEvents[ ], Length @ sessionData[ ][ "Events" ] }
        ]
    ],
    { 3, 3 },
    SameTest -> SameQ,
    TestID   -> "RecordUsageData-EventLimit@@Tests/UsageData.wlt:630,1-640,2"
]

(* A failure while recording (here: the session file cannot be written) is swallowed and never propagates to the
   read loop; the event itself is still kept in memory *)
VerificationTest[
    withUsageSession[
        Block[ { Wolfram`AgentTools`Common`writeWXFFile = $Failed & },
            { recordUsageData[ "tools/call", $toolCallMessage, $toolCallResponse ], Length @ usageEvents[ ] }
        ]
    ],
    { _Failure, 1 },
    SameTest -> MatchQ,
    TestID   -> "RecordUsageData-FailuresAreIsolated@@Tests/UsageData.wlt:644,1-653,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Product Identity Information*)
(* The payload carries the same product identity information that the paclet manager sends with every request to the
   paclet server (PacletManager`Package`$productIdentityHeaders), which identifies the installation. *)
VerificationTest[
    Keys @ productIdentityInfo[ ],
    $productIdentityKeys,
    SameTest -> SameQ,
    TestID   -> "ProductIdentityInfo-Keys@@Tests/UsageData.wlt:660,1-665,2"
]

(* Each value is the kernel's own, as it is; values that JSON cannot represent are converted when the payload is
   written as JSON (see below) *)
VerificationTest[
    With[ { info = productIdentityInfo[ ] },
        {
            info[ "ActivationKey"          ] === $ActivationKey,
            info[ "CloudUserUUID"          ] === $CloudUserUUID,
            info[ "Language"               ] === $Language,
            info[ "LicenseID"              ] === $LicenseID,
            info[ "LicenseProcesses"       ] === $LicenseProcesses,
            info[ "LicenseSubprocesses"    ] === $LicenseSubprocesses,
            info[ "MachineID"              ] === $MachineID,
            info[ "MaxLicenseProcesses"    ] === $MaxLicenseProcesses,
            info[ "MaxLicenseSubprocesses" ] === $MaxLicenseSubprocesses,
            info[ "ProductIDName"          ] === SystemInformation[ "Kernel", "ProductIDName" ],
            info[ "ReleaseID"              ] === SystemInformation[ "Kernel", "ReleaseID" ],
            info[ "SystemID"               ] === $SystemID,
            StringQ @ info[ "MachineID" ],
            StringQ @ info[ "SystemID" ]
        }
    ],
    { True, True, True, True, True, True, True, True, True, True, True, True, True, True },
    SameTest -> SameQ,
    TestID   -> "ProductIdentityInfo-Values@@Tests/UsageData.wlt:669,1-691,2"
]

(* Values that JSON cannot represent, e.g. None when the kernel is not connected to the cloud, are kept as they are in
   the payload (and so in the session file) and become their InputForm strings in the JSON. (Block stands in for the
   connection state here; $MaxLicenseProcesses, which is Infinity for an unlimited license, is a special symbol that
   cannot be Blocked.) *)
VerificationTest[
    {
        Block[ { $CloudUserUUID = None }, productIdentityInfo[ ][ "CloudUserUUID" ] ],
        Block[ { $CloudUserUUID = "11111111-2222-3333-4444-555555555555" }, productIdentityInfo[ ][ "CloudUserUUID" ] ],
        Block[ { $CloudUserUUID = Infinity }, productIdentityInfo[ ][ "CloudUserUUID" ] ],
        Block[ { $CloudUserUUID = $Failed }, productIdentityInfo[ ][ "CloudUserUUID" ] ]
    },
    { None, "11111111-2222-3333-4444-555555555555", Infinity, $Failed },
    SameTest -> SameQ,
    TestID   -> "ProductIdentityInfo-NonJSONValuesKept@@Tests/UsageData.wlt:697,1-707,2"
]

VerificationTest[
    {
        Block[ { $CloudUserUUID = None }, readUsageJSON[ usageDataJSON @ productIdentityInfo[ ] ][ "CloudUserUUID" ] ],
        Block[ { $CloudUserUUID = "11111111-2222-3333-4444-555555555555" }, readUsageJSON[ usageDataJSON @ productIdentityInfo[ ] ][ "CloudUserUUID" ] ],
        Block[ { $CloudUserUUID = Infinity }, readUsageJSON[ usageDataJSON @ productIdentityInfo[ ] ][ "CloudUserUUID" ] ],
        Block[ { $CloudUserUUID = $Failed }, readUsageJSON[ usageDataJSON @ productIdentityInfo[ ] ][ "CloudUserUUID" ] ]
    },
    { "None", "11111111-2222-3333-4444-555555555555", "Infinity", "$Failed" },
    SameTest -> SameQ,
    TestID   -> "ProductIdentityInfo-NonJSONValuesAsStrings@@Tests/UsageData.wlt:709,1-719,2"
]

(* The payload can always be serialized, as UTF-8 bytes in which every value is JSON-representable (WriteRawJSONString
   itself rejects None and Infinity) *)
VerificationTest[
    Block[ { $CloudUserUUID = None },
        With[ { json = readUsageJSON @ usageDataJSON @ productIdentityInfo[ ] },
            {
                usageDataJSON @ productIdentityInfo[ ],
                MatchQ[ Values @ json, { (_Integer|_Real|_String|Null).. } ],
                json
            }
        ]
    ],
    { _ByteArray, True, KeyValuePattern @ { "CloudUserUUID" -> "None", "MachineID" -> $MachineID, "SystemID" -> $SystemID } },
    SameTest -> MatchQ,
    TestID   -> "ProductIdentityInfo-JSON@@Tests/UsageData.wlt:723,1-736,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Standalone MCP Server*)
(* $StandaloneMCPServer and $StandaloneMCPServerInformation (Kernel/Server/Server.wl) are set by the standalone MCP
   server application and never by the paclet; the payload carries both so that sessions of the standalone product can
   be told apart from those of a regular kernel. *)
$standaloneInfo = <|
    "Version"   -> "1.0.0",
    "BuildDate" -> DateObject[ { 2026, 8, 1, 12, 0, 0 }, TimeZone -> 0 ],
    "Something" -> Missing[ "NotAvailable" ]
|>;

(* Exported and protected like the other exported symbols *)
VerificationTest[
    { Context @ $StandaloneMCPServer, Context @ $StandaloneMCPServerInformation },
    { "Wolfram`AgentTools`", "Wolfram`AgentTools`" },
    SameTest -> SameQ,
    TestID   -> "StandaloneMCPServer-Exported@@Tests/UsageData.wlt:751,1-756,2"
]

VerificationTest[
    {
        MemberQ[ Wolfram`AgentTools`$AgentToolsProtectedNames, "Wolfram`AgentTools`$StandaloneMCPServer" ],
        MemberQ[ Wolfram`AgentTools`$AgentToolsProtectedNames, "Wolfram`AgentTools`$StandaloneMCPServerInformation" ],
        MemberQ[ Attributes[ "Wolfram`AgentTools`$StandaloneMCPServer" ], Protected ],
        MemberQ[ Attributes[ "Wolfram`AgentTools`$StandaloneMCPServerInformation" ], Protected ]
    },
    { True, True, True, True },
    SameTest -> SameQ,
    TestID   -> "StandaloneMCPServer-Protected@@Tests/UsageData.wlt:758,1-768,2"
]

(* A regular kernel has the defaults *)
VerificationTest[
    { $StandaloneMCPServer, $StandaloneMCPServerInformation },
    { False, <| |> },
    SameTest -> SameQ,
    TestID   -> "StandaloneMCPServer-Defaults@@Tests/UsageData.wlt:771,1-776,2"
]

(* The standalone application sets both; Block stands in for it here, and works despite Protected *)
VerificationTest[
    Block[ { $StandaloneMCPServer = True, $StandaloneMCPServerInformation = $standaloneInfo },
        { $StandaloneMCPServer, $StandaloneMCPServerInformation }
    ],
    { True, $standaloneInfo },
    SameTest -> SameQ,
    TestID   -> "StandaloneMCPServer-Blockable@@Tests/UsageData.wlt:779,1-786,2"
]

(* The session file stores both as they are, including values in the information that JSON cannot represent *)
VerificationTest[
    Block[ { $StandaloneMCPServer = True, $StandaloneMCPServerInformation = $standaloneInfo },
        withUsageSession[
            recordUsageData[ "initialize", $initMessage, $initResponse ];
            KeyTake[ sessionData[ ], { "StandaloneMCPServer", "StandaloneMCPServerInformation" } ]
        ]
    ],
    <| "StandaloneMCPServer" -> True, "StandaloneMCPServerInformation" -> $standaloneInfo |>,
    SameTest -> SameQ,
    TestID   -> "StandaloneMCPServer-SessionFile@@Tests/UsageData.wlt:789,1-799,2"
]

(* In the JSON, dates in the information become ISO 8601 strings and other values that JSON cannot represent become
   their InputForm strings *)
VerificationTest[
    Block[ { $StandaloneMCPServer = True, $StandaloneMCPServerInformation = $standaloneInfo },
        withUsageSession[
            recordUsageData[ "initialize", $initMessage, $initResponse ];
            KeyTake[ readUsageJSON @ usageDataJSON @ sessionData[ ], { "StandaloneMCPServer", "StandaloneMCPServerInformation" } ]
        ]
    ],
    <|
        "StandaloneMCPServer"            -> True,
        "StandaloneMCPServerInformation" -> <|
            "Version"   -> "1.0.0",
            "BuildDate" -> "2026-08-01T12:00:00.000Z",
            "Something" -> "Missing[\"NotAvailable\"]"
        |>
    |>,
    SameTest -> SameQ,
    TestID   -> "StandaloneMCPServer-JSON@@Tests/UsageData.wlt:803,1-820,2"
]

(* The keys that describe the standalone MCP server's time-limited license (see Specs/StandaloneLicense.md) are part
   of the information, so the payload includes them, with the expiration date as an ISO 8601 string in UTC *)
VerificationTest[
    Block[
        {
            $StandaloneMCPServer            = True,
            $StandaloneMCPServerInformation = <|
                "Version"         -> "1.0.0",
                "ExpirationDate"  -> DateObject[ { 2026, 11, 1, 0, 30, 0 }, TimeZone -> -7 ],
                "Expired"         -> False,
                "InstructionsURL" -> "https://example.com/renew",
                "ProductName"     -> "Wolfram MCP Server",
                "WarningDays"     -> 7
            |>
        },
        withUsageSession[
            recordUsageData[ "initialize", $initMessage, $initResponse ];
            readUsageJSON[ usageDataJSON @ sessionData[ ] ][ "StandaloneMCPServerInformation" ]
        ]
    ],
    <|
        "Version"         -> "1.0.0",
        "ExpirationDate"  -> "2026-11-01T07:30:00.000Z",
        "Expired"         -> False,
        "InstructionsURL" -> "https://example.com/renew",
        "ProductName"     -> "Wolfram MCP Server",
        "WarningDays"     -> 7
    |>,
    SameTest -> SameQ,
    TestID   -> "StandaloneMCPServer-JSON-License@@Tests/UsageData.wlt:824,1-852,2"
]

(* A missing expiration date (which counts as expired) is kept as None and becomes its InputForm string *)
VerificationTest[
    Block[
        {
            $StandaloneMCPServer            = True,
            $StandaloneMCPServerInformation = <| "Version" -> "1.0.0", "ExpirationDate" -> None, "Expired" -> True |>
        },
        withUsageSession[
            recordUsageData[ "initialize", $initMessage, $initResponse ];
            {
                sessionData[ ][ "StandaloneMCPServerInformation" ],
                readUsageJSON[ usageDataJSON @ sessionData[ ] ][ "StandaloneMCPServerInformation" ]
            }
        ]
    ],
    {
        <| "Version" -> "1.0.0", "ExpirationDate" -> None, "Expired" -> True |>,
        <| "Version" -> "1.0.0", "ExpirationDate" -> "None", "Expired" -> True |>
    },
    SameTest -> SameQ,
    TestID   -> "StandaloneMCPServer-JSON-LicenseNoExpirationDate@@Tests/UsageData.wlt:855,1-875,2"
]

(* Values the standalone application must not set: the payload cannot be built, and as with every other tracking
   failure nothing propagates (the failure is only logged) and no file is written *)
VerificationTest[
    {
        Block[ { $StandaloneMCPServer = "yes" },
            withUsageSession @ { recordUsageData[ "initialize", $initMessage, $initResponse ], FileExistsQ @ usageStatsFile[ ] }
        ],
        Block[ { $StandaloneMCPServerInformation = { "Version" -> "1.0.0" } },
            withUsageSession @ { recordUsageData[ "initialize", $initMessage, $initResponse ], FileExistsQ @ usageStatsFile[ ] }
        ]
    },
    { { _Failure, False }, { _Failure, False } },
    SameTest -> MatchQ,
    TestID   -> "StandaloneMCPServer-InvalidValuesIsolated@@Tests/UsageData.wlt:879,1-891,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*JSON Payload*)
VerificationTest[
    withUsageSession[
        recordUsageData[ "initialize", $initMessage, $initResponse ];
        recordUsageData[ "tools/call", $toolCallMessage, $toolCallResponse ];
        recordUsageData[ "tools/call", <| "params" -> <| "name" -> "NoSuchTool" |> |>, <| "result" -> <| "isError" -> True |> |> ];
        readUsageJSON @ usageDataJSON @ usageDataPayload[ ]
    ],
    KeyValuePattern @ {
        "MCPSessionID"                   -> _String,
        "ServerName"                     -> "TestServer",
        "ClientInformation"              -> KeyValuePattern[ "clientInfo" -> KeyValuePattern[ "name" -> "test-client" ] ],
        "Events"                         -> {
            KeyValuePattern @ { "Type" -> "ToolCall", "Name" -> "PrimeFinder", "Success" -> True, "Timestamp" -> _Real },
            KeyValuePattern @ { "Type" -> "ToolCall", "Name" -> Null, "Success" -> False }
        },
        "StandaloneMCPServer"            -> False,
        "StandaloneMCPServerInformation" -> <| |>,
        "PacletVersion"                  -> _String,
        "LastUpdated"                    -> _Real,
        "MachineID"                      -> $MachineID,
        "LicenseID"                      -> _String,
        "ProductIDName"                  -> _String,
        "ReleaseID"                      -> _String,
        "SystemID"                       -> $SystemID
    },
    SameTest -> MatchQ,
    TestID   -> "UsageData-JSONPayload@@Tests/UsageData.wlt:896,1-923,2"
]

(* The JSON is exactly what is stored in the session file, with the values that JSON cannot represent (e.g. None or
   Infinity in the product identity information) as their InputForm strings *)
VerificationTest[
    withUsageSession[
        recordUsageData[ "initialize", $initMessage, $initResponse ];
        recordUsageData[ "tools/call", $toolCallMessage, $toolCallResponse ];
        With[ { stored = sessionData[ ] },
            KeyDrop[ readUsageJSON @ usageDataJSON @ stored, "LastUpdated" ] === KeyDrop[ jsonValue /@ stored, "LastUpdated" ]
        ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "UsageData-JSONRoundTrip@@Tests/UsageData.wlt:927,1-938,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Keep-Alive*)
VerificationTest[
    withUsageSession[
        recordUsageData[ "initialize", $initMessage, $initResponse ];
        SetFileDate[ usageStatsFile[ ], Now - Quantity[ 2, "Hours" ], "Modification" ];
        {
            fileAge @ usageStatsFile[ ] > 3600,
            touchUsageStatsFile[ ] === usageStatsFile[ ],
            fileAge @ usageStatsFile[ ] < 60,
            sessionData[ ][ "ClientInformation" ] === $initMessage[ "params" ] (* touching does not rewrite the data *)
        }
    ],
    { True, True, True, True },
    SameTest -> SameQ,
    TestID   -> "UsageData-KeepAliveTouchesFile@@Tests/UsageData.wlt:943,1-957,2"
]

VerificationTest[
    withUsageSession[ { touchUsageStatsFile[ ], FileExistsQ @ usageStatsFile[ ] } ],
    { Null, False },
    SameTest -> SameQ,
    TestID   -> "UsageData-KeepAliveWithoutFile@@Tests/UsageData.wlt:959,1-964,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Finished Sessions*)
VerificationTest[
    withUsageSession[
        recordUsageData[ "initialize", $initMessage, $initResponse ];
        With[ { other = FileNameJoin @ { usageDataPath[ ], "other-session.wxf" } },
            CopyFile[ usageStatsFile[ ], other ];
            SetFileDate[ other, Now - Quantity[ 25, "Hours" ], "Modification" ];
            SetFileDate[ usageStatsFile[ ], Now - Quantity[ 25, "Hours" ], "Modification" ];
            {
                staleUsageFileQ @ other,
                staleUsageFileQ @ usageStatsFile[ ], (* the current session is never considered finished *)
                (SetFileDate @ other; staleUsageFileQ @ other)
            }
        ]
    ],
    { True, False, False },
    SameTest -> SameQ,
    TestID   -> "UsageData-StaleUsageFileQ@@Tests/UsageData.wlt:969,1-986,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Submission*)

(* Finished sessions are submitted (oldest first) and deleted; expired and unreadable files are discarded without
   submission; the fresh session stays; the lock is released. *)
VerificationTest[
    Module[ { root, dir, submitted = { }, result, remaining, lockLeft },
        root = makeTempRoot[ ];
        dir  = FileNameJoin @ { root, "UsageData" };
        CreateDirectory[ dir, CreateIntermediateDirectories -> True ];
        makeUsageFile[ dir, "finished", Quantity[ 25, "Hours" ] ];
        makeUsageFile[ dir, "older"   , Quantity[ 3, "Days" ] ];
        makeUsageFile[ dir, "fresh"   , Quantity[ 1, "Hours" ] ];
        makeUsageFile[ dir, "expired" , Quantity[ 31, "Days" ] ];
        Export[ FileNameJoin @ { dir, "corrupt.wxf" }, "this is not WXF", "Text" ];
        SetFileDate[ FileNameJoin @ { dir, "corrupt.wxf" }, Now - Quantity[ 25, "Hours" ], "Modification" ];
        result = Block[
            {
                Wolfram`AgentTools`Common`$rootPath                            = root,
                Wolfram`AgentTools`Server`$mcpSessionID                        = None,
                Wolfram`AgentTools`Server`UsageData`Private`submitUsagePayload = Function[ AppendTo[ submitted, #MCPSessionID ]; True ]
            },
            submitUsageData[ ]
        ];
        remaining = FileBaseName /@ FileNames[ "*.wxf", dir ];
        lockLeft  = FileExistsQ @ FileNameJoin @ { dir, "Submit.lock" };
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        { Sort[ FileBaseName /@ result ], submitted, remaining, lockLeft }
    ],
    { { "corrupt", "expired", "finished", "older" }, { "older", "finished" }, { "fresh" }, False },
    SameTest -> SameQ,
    TestID   -> "SubmitUsageData-SubmitsFinishedSessions@@Tests/UsageData.wlt:994,1-1021,2"
]

(* A failed submission keeps the file and stops the batch *)
VerificationTest[
    Module[ { root, dir, calls = 0, result, remaining },
        root = makeTempRoot[ ];
        dir  = FileNameJoin @ { root, "UsageData" };
        CreateDirectory[ dir, CreateIntermediateDirectories -> True ];
        makeUsageFile[ dir, "first" , Quantity[ 26, "Hours" ] ];
        makeUsageFile[ dir, "second", Quantity[ 25, "Hours" ] ];
        result = Block[
            {
                Wolfram`AgentTools`Common`$rootPath                            = root,
                Wolfram`AgentTools`Server`$mcpSessionID                        = None,
                Wolfram`AgentTools`Server`UsageData`Private`submitUsagePayload = Function[ calls++; False ]
            },
            submitUsageData[ ]
        ];
        remaining = Sort[ FileBaseName /@ FileNames[ "*.wxf", dir ] ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        { result, calls, remaining }
    ],
    { { }, 1, { "first", "second" } },
    SameTest -> SameQ,
    TestID   -> "SubmitUsageData-FailureStopsBatch@@Tests/UsageData.wlt:1024,1-1046,2"
]

(* While another process holds the lock, this one skips its turn without waiting long *)
VerificationTest[
    Module[ { root, dir, calls = 0, timing, result, remaining },
        root = makeTempRoot[ ];
        dir  = FileNameJoin @ { root, "UsageData" };
        CreateDirectory[ dir, CreateIntermediateDirectories -> True ];
        makeUsageFile[ dir, "finished", Quantity[ 25, "Hours" ] ];
        Put[ <| "Header" -> "held by another process" |>, FileNameJoin @ { dir, "Submit.lock" } ];
        { timing, result } = AbsoluteTiming @ Block[
            {
                Wolfram`AgentTools`Common`$rootPath                            = root,
                Wolfram`AgentTools`Server`$mcpSessionID                        = None,
                Wolfram`AgentTools`Server`UsageData`Private`submitUsagePayload = Function[ calls++; True ]
            },
            submitUsageData[ ]
        ];
        remaining = FileBaseName /@ FileNames[ "*.wxf", dir ];
        Quiet @ DeleteDirectory[ root, DeleteContents -> True ];
        { result, calls, remaining, timing < 30 }
    ],
    { { }, 0, { "finished" }, True },
    SameTest -> SameQ,
    TestID   -> "SubmitUsageData-LockHeld@@Tests/UsageData.wlt:1049,1-1071,2"
]

VerificationTest[
    submitUsageData @ FileNameJoin @ { $TemporaryDirectory, "does-not-exist-" <> CreateUUID[ ] },
    { },
    SameTest -> SameQ,
    TestID   -> "SubmitUsageData-NoDirectory@@Tests/UsageData.wlt:1073,1-1078,2"
]

(* The current session's file is never submitted, even when it looks old *)
VerificationTest[
    withUsageSession[
        Module[ { calls = 0, result, remaining },
            recordUsageData[ "initialize", $initMessage, $initResponse ];
            SetFileDate[ usageStatsFile[ ], Now - Quantity[ 25, "Hours" ], "Modification" ];
            result = Block[
                { Wolfram`AgentTools`Server`UsageData`Private`submitUsagePayload = Function[ calls++; True ] },
                submitUsageData[ ]
            ];
            { result, calls, FileExistsQ @ usageStatsFile[ ] }
        ]
    ],
    { { }, 0, True },
    SameTest -> SameQ,
    TestID   -> "SubmitUsageData-CurrentSessionExcluded@@Tests/UsageData.wlt:1081,1-1096,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*HTTP Request*)

(* An unreachable endpoint reports failure (and nothing is thrown) *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Server`UsageData`Private`$usageDataEndpoint      = "http://127.0.0.1:9/usage",
            Wolfram`AgentTools`Server`UsageData`Private`$usageDataSubmitTimeout = 2
        },
        submitUsagePayload @ <| "MCPSessionID" -> "test", "Events" -> { } |>
    ],
    False,
    SameTest -> SameQ,
    TestID   -> "SubmitUsagePayload-Unreachable@@Tests/UsageData.wlt:1103,1-1114,2"
]

(* The development endpoint accepts a JSON body (skipped on CI, where network access is not guaranteed) *)
skipIfGitHubActions @ VerificationTest[
    submitUsagePayload @ <|
        "MCPSessionID"                   -> "AgentToolsTestSuite-" <> CreateUUID[ ],
        "ServerName"                     -> "AgentToolsTestSuite",
        "ClientInformation"              -> Null,
        "Events"                         -> { },
        "StandaloneMCPServer"            -> False,
        "StandaloneMCPServerInformation" -> <| |>,
        "PacletVersion"                  -> Wolfram`AgentTools`Common`$pacletVersion,
        "LastUpdated"                    -> AbsoluteTime[ TimeZone -> 0 ],
        productIdentityInfo[ ]
    |>,
    True,
    SameTest -> SameQ,
    TestID   -> "SubmitUsagePayload-Endpoint@@Tests/UsageData.wlt:1117,23-1132,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Server Integration*)

(* Note: These integration tests spawn a subprocess running the MCP server and communicate via JSON-RPC. As in
   StartMCPServer.wlt, they are skipped when running as a script (see skipIfScript). Test servers get
   SUBMIT_USAGE_DATA=false by default (see GetMCPEnvironment), so the tracked session here opts in explicitly. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tracked Session*)
skipIfScript @ VerificationTest[
    $usageProcess = StartMCPTestServer[
        "ServerName"  -> "WolframLanguage",
        "Environment" -> <| "SUBMIT_USAGE_DATA" -> "true" |>
    ],
    _ProcessObject,
    SameTest -> MatchQ,
    TestID   -> "UsageData-Integration-ServerStarts@@Tests/UsageData.wlt:1145,16-1153,2"
]

skipIfScript @ VerificationTest[
    $usageClientName = "usage-data-test-" <> CreateUUID[ ];
    MCPInitialize[ "ClientName" -> $usageClientName ],
    KeyValuePattern[ "result" -> _Association ],
    SameTest -> MatchQ,
    TestID   -> "UsageData-Integration-Initialize@@Tests/UsageData.wlt:1155,16-1161,2"
]

skipIfScript @ VerificationTest[
    SendMCPRequest[ "tools/call", <| "name" -> "WolframLanguageEvaluator", "arguments" -> <| "code" -> "Prime[1000]" |> |> ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "isError" -> False ] ],
    SameTest -> MatchQ,
    TestID   -> "UsageData-Integration-ToolCall@@Tests/UsageData.wlt:1163,16-1168,2"
]

skipIfScript @ VerificationTest[
    SendMCPRequest[ "tools/call", <| "name" -> "NoSuchTool", "arguments" -> <| |> |> ],
    KeyValuePattern[ "result" -> KeyValuePattern[ "isError" -> True ] ],
    SameTest -> MatchQ,
    TestID   -> "UsageData-Integration-UnknownToolCall@@Tests/UsageData.wlt:1170,16-1175,2"
]

skipIfScript @ VerificationTest[
    SendMCPRequest[ "prompts/get", <| "name" -> "NoSuchPrompt", "arguments" -> <| |> |> ],
    KeyValuePattern[ "error" -> _Association ],
    SameTest -> MatchQ,
    TestID   -> "UsageData-Integration-UnknownPrompt@@Tests/UsageData.wlt:1177,16-1182,2"
]

skipIfScript @ VerificationTest[
    $usageFile = SelectFirst[
        FileNames[ "*.wxf", FileNameJoin @ { Wolfram`AgentTools`Common`$rootPath, "UsageData" } ],
        Quiet[ Developer`ReadWXFFile[ # ][ "ClientInformation", "clientInfo", "name" ] ] === $usageClientName &
    ],
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "UsageData-Integration-SessionFileWritten@@Tests/UsageData.wlt:1184,16-1192,2"
]

skipIfScript @ VerificationTest[
    $usageSession = Developer`ReadWXFFile @ $usageFile;
    $usageSession[ "Events" ],
    {
        KeyValuePattern @ { "Type" -> "ToolCall" , "Name" -> "WolframLanguageEvaluator", "Success" -> True, "Timestamp" -> _Real },
        KeyValuePattern @ { "Type" -> "ToolCall" , "Name" -> Null, "Success" -> False },
        KeyValuePattern @ { "Type" -> "PromptGet", "Name" -> Null, "Success" -> False }
    },
    SameTest -> MatchQ,
    TestID   -> "UsageData-Integration-Events@@Tests/UsageData.wlt:1194,16-1204,2"
]

skipIfScript @ VerificationTest[
    {
        $usageSession[ "ServerName" ],
        $usageSession[ "ClientInformation", "protocolVersion" ],
        StringQ @ $usageSession[ "MCPSessionID" ],
        FreeQ[ $usageSession, "Prime[1000]" ],
        SubsetQ[ Keys @ $usageSession, $productIdentityKeys ],
        $usageSession[ "MachineID" ] === $MachineID, (* the server process runs on this machine *)
        $usageSession[ "SystemID" ] === $SystemID,
        $usageSession[ "StandaloneMCPServer" ], (* a regular kernel, not the standalone product *)
        $usageSession[ "StandaloneMCPServerInformation" ]
    },
    { "WolframLanguage", "2024-11-05", True, True, True, True, True, False, <| |> },
    SameTest -> SameQ,
    TestID   -> "UsageData-Integration-Payload@@Tests/UsageData.wlt:1206,16-1221,2"
]

skipIfScript @ VerificationTest[
    StopMCPTestServer[ ];
    Quiet @ DeleteFile @ $usageFile;
    FileExistsQ @ $usageFile,
    False,
    SameTest -> SameQ,
    TestID   -> "UsageData-Integration-Cleanup@@Tests/UsageData.wlt:1223,16-1230,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Opted-Out Session*)
skipIfScript @ VerificationTest[
    $usageProcess = StartMCPTestServer[ "ServerName" -> "WolframLanguage" ]; (* SUBMIT_USAGE_DATA=false *)
    $usageClientName = "usage-data-test-" <> CreateUUID[ ];
    MCPInitialize[ "ClientName" -> $usageClientName ];
    SendMCPRequest[ "tools/call", <| "name" -> "WolframLanguageEvaluator", "arguments" -> <| "code" -> "1 + 1" |> |> ];
    StopMCPTestServer[ ];
    SelectFirst[
        FileNames[ "*.wxf", FileNameJoin @ { Wolfram`AgentTools`Common`$rootPath, "UsageData" } ],
        Quiet[ Developer`ReadWXFFile[ # ][ "ClientInformation", "clientInfo", "name" ] ] === $usageClientName &
    ],
    _Missing,
    SameTest -> MatchQ,
    TestID   -> "UsageData-Integration-OptedOutWritesNothing@@Tests/UsageData.wlt:1235,16-1248,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    DeleteObject @ $customServer,
    Null,
    SameTest -> MatchQ,
    TestID   -> "UsageData-Cleanup@@Tests/UsageData.wlt:1253,1-1258,2"
]

(* :!CodeAnalysis::EndBlock:: *)
