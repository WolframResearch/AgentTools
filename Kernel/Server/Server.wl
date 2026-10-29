(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Server`" ];

(* Server session state shared among the Server subcontexts (Shared / Local / Cloud).
   These are read by the transport-agnostic handlers in Shared.wl and bound (via Block)
   by each transport. They are not read elsewhere in the paclet, so they live here rather
   than in CommonSymbols.wl. `handleMethod` and `initializeServerState` are declared in
   CommonSymbols.wl instead, since they are needed paclet-wide. *)
`$currentMCPServer;
`$llmTools;
`$logFile;
`$promptList;
`$promptLookup;
`$toolList;
`$warmupTask;

(* Usage data (UsageData.wl): per-session tracking state and the hooks called by the local transport. *)
`$mcpClientInformation;
`$mcpSessionID;
`$usageDataEnabled;
`$usageEvents;
`initializeUsageData;
`recordUsageData;

(* Shared catch wrapper: defined in Local.wl but also used by evaluateTool in Shared.wl,
   so it is declared here where both subcontexts can bind it. *)
`stealthCatchTop;

(* Boundary for exceptions that nothing in the paclet catches (foreign Throw tags, tagless Throw, Abort): defined in
   Shared.wl, used by evaluateTool there and by both transports around handleMethod (see catchUncaughtThrows). *)
`catchUncaughtThrows;
`uncaughtRequestThrow;

(* Tool-list construction shared by the transports: defined in Shared.wl and also read by the cloud
   transport (Cloud.wl) to describe a server for the /api/info landing-page endpoint. *)
`serverToolListData;

Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Current MCP Server Information*)

(* Exported descriptors of where the current MCP server is running, for tools that adapt their behavior
   to the host. Both are None outside a server session; each transport Blocks them for the duration of a
   session (local) or request (cloud) before the server state is built:

     $MCPEvaluationEnvironment  "Local" for the stdio server started by StartMCPServer, or "Cloud" for a
                                cloud-deployed server handled by RunCloudMCPServer.
     $MCPTransport              "StandardInputOutput" for the stdio transport, or "StreamableHTTP" for
                                the cloud (Streamable HTTP) transport.

   Tools consult these through the "Overrides" key of their LLMTool data (see applyToolOverrides in
   Shared.wl): a delayed association of tool properties merged in when the server state is built, e.g.
   WriteNotebook swaps in a cloud-object writer when $MCPEvaluationEnvironment === "Cloud". *)
$MCPEvaluationEnvironment = None;
$MCPTransport             = None;

(* Exported descriptors of the standalone MCP server product: a kernel that only runs the MCP server, without a full
   Mathematica installation and under its own licensing. Nothing in this paclet sets them; the standalone application
   sets both after the paclet has been loaded (loading resets them to the defaults below). Like the other exported
   symbols they are Protected (see $AgentToolsProtectedNames in Main.wl), so setting them takes Unprotect or Block.

     $StandaloneMCPServer             True when running under the standalone MCP server, False everywhere else.
     $StandaloneMCPServerInformation  Information the standalone product publishes about itself (version, build,
                                      and so on), as an association with string keys; empty everywhere else.

   Both are included in the usage data of local server sessions (usageDataPayload in UsageData.wl); the information
   association is included as it is, with values that JSON cannot represent written as strings (jsonConvert in
   Files.wl), so it must only describe the product, never anything about a session. *)
$StandaloneMCPServer            = False;
$StandaloneMCPServerInformation = <| |>;

(* Default when not inside a request; each transport Blocks this per session/request. *)
$currentMCPServer = None;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Subcontexts*)
$subcontexts = {
    (* Transport-agnostic core: dispatch, tool/prompt resolution, result formatting, init *)
    "Wolfram`AgentTools`Server`Shared`",

    (* Usage data: session ID, usage tracking for local servers, and submission of finished sessions *)
    "Wolfram`AgentTools`Server`UsageData`",

    (* Local stdio transport: StartMCPServer, the read loop, warmup, superQuiet *)
    "Wolfram`AgentTools`Server`Local`",

    (* Cloud HTTP transport: CloudDeployMCPServer, CloudDeployMCPServerBundle, RunCloudMCPServer,
       the CloudDeploy UpValue, page/asset deployment, the self-describing session-ID codec, and the
       admin/info APIs *)
    "Wolfram`AgentTools`Server`Cloud`"
};

Scan[ Needs[ # -> None ] &, $subcontexts ];

$AgentToolsContexts = Union[ $AgentToolsContexts, $subcontexts ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
