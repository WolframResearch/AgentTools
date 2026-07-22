(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Server`Local`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];
Needs[ "Wolfram`AgentTools`Server`" ];

Needs[ "Wolfram`Chatbook`" -> "cb`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*StartMCPServer*)
StartMCPServer // beginDefinition;
StartMCPServer[ ] := stealthCatchTop @ StartMCPServer @ Environment[ "MCP_SERVER_NAME" ];
StartMCPServer[ $Failed ] := stealthCatchTop @ StartMCPServer @ $defaultMCPServer;
StartMCPServer[ name_String ] := stealthCatchTop @ StartMCPServer @ MCPServerObject @ name;
StartMCPServer[ obj_MCPServerObject ] := stealthCatchTop @ startMCPServer @ ensureMCPServerExists @ obj;
StartMCPServer // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stealthCatchTop*)
(* A version of `catchTop` that doesn't set the message symbol or interfere with inner calls to `catchTop`. *)
stealthCatchTop // beginDefinition;
stealthCatchTop // Attributes = { HoldFirst };
stealthCatchTop[ eval_ ] := Block[ { $catching = True }, Catch[ eval, $catchTopTag ] ];
stealthCatchTop // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*startMCPServer*)
startMCPServer // beginDefinition;

startMCPServer[ obj_ ] /; $Notebooks :=
    throwFailure[ "InvalidSession" ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
startMCPServer[ obj0_MCPServerObject ] := Enclose[
    Block[ { $currentMCPServer = obj0, $mcpEvaluation = True },
        superQuiet @ Module[ { logFile, state, response, output },

        SetOptions[ First @ Streams[ "stdout" ], CharacterEncoding -> "UTF-8" ];
        SetOptions[ First @ Streams[ "stderr" ], CharacterEncoding -> "UTF-8" ];

        (* Apply any cloud base override before anything uses the cloud: *)
        setCloudBaseFromEnvironment[ ];

        cleanupOldOutputLogs[ ];

        logFile = ConfirmBy[ ensureFilePath @ mcpServerLogFile @ obj0, fileQ, "LogFile" ];
        If[ FileExistsQ @ logFile, DeleteFile @ logFile ];
        writeLog[ "LogFile" -> logFile ];

        (* Build the transport-agnostic tool/prompt state (paclet resolution, tool/prompt
           tables, UI resources, tool options); $currentMCPServer may be reassigned within. *)
        state = ConfirmBy[ initializeServerState @ obj0, AssociationQ, "InitializeServerState" ];

        Block[
            {
                $toolList     = state[ "ToolList" ],
                $llmTools     = state[ "LLMTools" ],
                $promptList   = state[ "PromptList" ],
                $promptLookup = state[ "PromptLookup" ],
                $logFile      = logFile,
                $toolOptions  = state[ "ToolOptions" ]
            },
            While[ True,
                If[
                    And[
                        Or[ $OperatingSystem === "MacOSX", $OperatingSystem === "Unix" ],
                        $ParentProcessID === 1
                    ],
                    Exit[0]
                ];
                response = catchAlways @ processRequest[ ];
                If[ response =!= EndOfFile, writeLog[ "Response" -> response ] ];
                If[ AssociationQ @ response,
                    output = ConfirmBy[
                        Developer`WriteRawJSONString[ sanitizeResponse @ response, "Compact" -> True ],
                        StringQ,
                        "WriteRawJSONString"
                    ];
                    WriteLine[ "stdout", output ];
                    If[ TrueQ @ $warmupTools, toolWarmup @ $toolList ],
                    Pause[ 0.1 ]
                ]
            ]
        ]
    ]
    ],
    throwInternalFailure
];
(* :!CodeAnalysis::EndBlock:: *)

startMCPServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setCloudBaseFromEnvironment*)
(* Overrides the default cloud base for the server session when the WOLFRAM_CLOUDBASE environment
   variable is set, e.g. WOLFRAM_CLOUDBASE="https://www.test.wolframcloud.com" (primarily for
   internal purposes). All cloud operations (MCP Apps notebook deployments, LLMKit subscription
   checks, etc.) then target that cloud, and UI resources are rewritten to match as they are
   loaded (see applyCloudBaseToHTML and applyCloudBaseToMeta in UIResources.wl). *)
setCloudBaseFromEnvironment // beginDefinition;

setCloudBaseFromEnvironment[ ] := setCloudBaseFromEnvironment @ Environment[ "WOLFRAM_CLOUDBASE" ];
setCloudBaseFromEnvironment[ base_String ] /; StringTrim @ base =!= "" := (CloudObject; $CloudBase = StringTrim @ base);
setCloudBaseFromEnvironment[ _ ] := Null;

setCloudBaseFromEnvironment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolWarmup*)
toolWarmup // beginDefinition;
toolWarmup[ ] := toolWarmup @ $toolList;
toolWarmup[ tools_List ] := toolWarmup /@ tools;
toolWarmup[ KeyValuePattern[ "name" -> name_String ] ] := toolWarmup @ name;
toolWarmup[ "WolframContext" ] := toolWarmup @ { "WolframAlphaContext", "WolframLanguageContext" };
toolWarmup[ "WolframLanguageContext"|"WolframAlphaContext" ] := preinstallVectorDatabases[ ];
toolWarmup[ _ ] := Null;
toolWarmup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*preinstallVectorDatabases*)
preinstallVectorDatabases // beginDefinition;

preinstallVectorDatabases[ ] := preinstallVectorDatabases[ ] = (
    debugPrint[ "Warming up vector databases" ];
    debugPrint[ "Warmed up vector databases: ", First @ AbsoluteTiming @ initializeVectorDatabases[ ] ]
);

preinstallVectorDatabases // endDefinition;

(* Test messages:

```
{"method":"initialize","params":{"clientInfo":{"name":"test-client"},"protocolVersion":"2024-11-05"},"jsonrpc":"2.0","id":0}
{"method":"tools/list","params":{},"jsonrpc":"2.0","id":1}
{"method":"tools/call","params":{"name":"WolframContext","arguments":{"context":"What's the 123456789th prime?"}},"jsonrpc":"2.0","id":2}
```
*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*initializeVectorDatabases*)
initializeVectorDatabases // beginDefinition;
initializeVectorDatabases[ ] := initializeVectorDatabases[ ] = cb`InstallVectorDatabases[ ];
initializeVectorDatabases // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stdinShutdownQ*)
(* The MCP stdio transport signals shutdown by closing the server's stdin, after which
   InputString[""] returns the EndOfFile symbol on every call. We must exit the process
   when that happens. Historically the read loop only detected client death on Unix (via
   $ParentProcessID === 1) and treated EndOfFile as a transient empty read -- Pause[0.1]
   and retry -- so on Windows a closed stdin left the kernel busy-spinning forever. The
   Antigravity CLI then force-killed the hung process during a `/mcp` reload, and Go's
   exec surfaced the TerminateProcess as "failed to stop mcp instance: <name>: exit
   status 1". Treating the EndOfFile symbol (and the explicit "Quit" sentinel) as a
   shutdown signal makes the server exit cleanly on all platforms. *)
stdinShutdownQ // beginDefinition;
stdinShutdownQ[ EndOfFile ] := True;
stdinShutdownQ[ "Quit" ]    := True;
stdinShutdownQ[ _ ]         := False;
stdinShutdownQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processRequest*)
processRequest // beginDefinition;

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
processRequest[ ] :=
    Catch @ Enclose @ Module[ { stdin, message, method, id, req, response },
        stdin = InputString[ "" ];
        If[ stdinShutdownQ @ stdin, Exit[ 0 ] ];
        If[ ! StringQ @ stdin || StringTrim @ stdin === "", Throw @ EndOfFile ];
        message = ConfirmBy[ Developer`ReadRawJSONString @ stdin, AssociationQ ];
        writeLog[ "Request" -> message ];
        method = Lookup[ message, "method", None ];
        id     = Lookup[ message, "id", Null ];

        (* Response to one of our outstanding server-to-client requests *)
        If[ method === None && StringQ @ id && KeyExistsQ[ $mcpClientRequests, id ],
            handleClientResponse[ id, message ];
            Throw @ Null
        ];

        req = <| "jsonrpc" -> "2.0", "id" -> id |>;
        response = catchAlways @ handleMethod[ method, message, req ];
        If[ method === "tools/list", $warmupTools = True ];
        writeLog[ "Response" -> response ];
        If[ FailureQ @ response,
            <| req, "error" -> <| "code" -> -32603, "message" -> "Internal error" |> |>,
            response
        ]
    ];
(* :!CodeAnalysis::EndBlock:: *)

processRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*superQuiet*)
(* Nothing can be written to stdout while running as an MCP server, so we aggressively suppress output. *)
superQuiet // beginDefinition;
superQuiet // Attributes = { HoldFirst };

superQuiet[ eval_ ] :=
    Module[ { logFile, logStream },
        logFile = Quiet @ outputLogFile @ $currentMCPServer;
        logStream = If[ fileQ @ logFile,
            Quiet @ OpenWrite[ First @ logFile, CharacterEncoding -> "UTF-8" ],
            $Failed
        ];

        If[ MatchQ[ logStream, _OutputStream ],
            (* Success: redirect to log file *)

            WithCleanup[
                Block[
                    {
                        $ProgressReporting = False,
                        $Messages = { logStream },
                        $Output   = { logStream }
                    },
                    (* We use a veto handler to prevent print output from being written to stdout/stderr.
                       We do this instead of redefining Print as a local symbol in Block because we need to let the
                       WL evaluator tool capture and include print outputs in the tool call response. *)
                    Internal`HandlerBlock[ { "Wolfram.System.Print.Veto", False & }, eval ]
                ],
                Quiet @ Close @ logStream
            ],
            (* Fallback: redirect to stderr as before *)
            Block[
                {
                    $ProgressReporting = False,
                    $Messages = Streams[ "stderr" ],
                    $Output   = Streams[ "stderr" ]
                },
                Internal`HandlerBlock[ { "Wolfram.System.Print.Veto", False & }, eval ]
            ]
        ]
    ];

superQuiet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
