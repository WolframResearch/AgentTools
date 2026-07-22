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

(* Shared catch wrapper: defined in Local.wl but also used by evaluateTool in Shared.wl,
   so it is declared here where both subcontexts can bind it. *)
`stealthCatchTop;

(* Tool-list construction shared by the transports: defined in Shared.wl and also read by the cloud
   transport (Cloud.wl) to describe a server for the /api/info landing-page endpoint. *)
`serverToolListData;

Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* Default when not inside a request; each transport Blocks this per session/request. *)
$currentMCPServer = None;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Subcontexts*)
$subcontexts = {
    (* Transport-agnostic core: dispatch, tool/prompt resolution, result formatting, init *)
    "Wolfram`AgentTools`Server`Shared`",

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
