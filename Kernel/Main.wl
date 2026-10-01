(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*System Symbols*)
System`AgentToolsDeployment;
System`DeployedAgentTools;
System`DeployAgentTools;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Exported Symbols*)
`$DefaultAgentTools;
`$DefaultMCPPrompts;
`$DefaultMCPServers;
`$DefaultMCPToolOptions;
`$DefaultMCPTools;
`$LastAgentToolsFailure;
`$LastAgentToolsFailureText;
`$MCPEvaluationEnvironment;
`$MCPTransport;
`$StandaloneMCPServer;
`$StandaloneMCPServerInformation;
`$SupportedClients;
`$SupportedMCPClients;
`AgentTools;
`AgentToolsObject;
`AgentToolsObjects;
`CloudDeployMCPServer;
`CloudDeployMCPServerBundle;
`CodeInspectorToolFunction;
`CreateMCPServer;
`CreatePreferencesContent;
`DetectedMCPClients;
`InstallAgentSkills;
`InstallMCPServer;
`ManageWelcomeScreenData;
`MCPServerObject;
`MCPServerObjectQ;
`MCPServerObjects;
`RunCloudMCPServer;
`StartMCPServer;
`TestReportToolFunction;
`UninstallAgentSkills;
`UninstallMCPServer;
`ValidateAgentToolsPacletExtension;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Begin Private Context*)
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`Common`" ];

(* Avoiding context aliasing due to bug 434990: *)
Needs[ "GeneralUtilities`" -> None ];

(* Clear subcontexts from `$Packages` to force `Needs` to run again: *)
WithCleanup[
    Unprotect @ $Packages,
    $Packages = Select[ $Packages, Not @* StringStartsQ[ "Wolfram`AgentTools`"~~__~~"`" ] ],
    Protect @ $Packages
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Usage Messages*)
GeneralUtilities`SetUsage[ AgentTools, "AgentTools is a symbol for miscellaneous messages." ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Files*)
$AgentToolsContexts = {
    "Wolfram`AgentTools`",
    "Wolfram`AgentTools`AgentSkills`",
    "Wolfram`AgentTools`AgentToolsObject`",
    "Wolfram`AgentTools`Common`",
    "Wolfram`AgentTools`CreateMCPServer`",
    "Wolfram`AgentTools`DefaultServers`",
    "Wolfram`AgentTools`DeployAgentTools`",
    "Wolfram`AgentTools`Files`",
    "Wolfram`AgentTools`Formatting`",
    "Wolfram`AgentTools`Graphics`",
    "Wolfram`AgentTools`InstallMCPServer`",
    "Wolfram`AgentTools`MCPClientRequests`",
    "Wolfram`AgentTools`MCPRoots`",
    "Wolfram`AgentTools`MCPServerObject`",
    "Wolfram`AgentTools`PacletExtension`",
    "Wolfram`AgentTools`PreferencesContent`",
    "Wolfram`AgentTools`Prompts`",
    "Wolfram`AgentTools`Server`",
    "Wolfram`AgentTools`SupportedClients`",
    "Wolfram`AgentTools`TOML`",
    "Wolfram`AgentTools`Tools`",
    "Wolfram`AgentTools`UIResources`",
    "Wolfram`AgentTools`Utilities`",
    "Wolfram`AgentTools`ValidateAgentToolsPacletExtension`",
    "Wolfram`AgentTools`YAML`"
};

Scan[ Needs[ # -> None ] &, $AgentToolsContexts ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Names*)
$AgentToolsSymbolNames = $AgentToolsSymbolNames =
    Block[ { $Context, $ContextPath },
        Union[ Names[ "Wolfram`AgentTools`*" ], Names[ "Wolfram`AgentTools`*`*" ] ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Protected Symbols*)
$AgentToolsProtectedNames = "Wolfram`AgentTools`" <> # & /@ {
    "$DefaultAgentTools",
    "$DefaultMCPPrompts",
    "$DefaultMCPServers",
    "$DefaultMCPToolOptions",
    "$DefaultMCPTools",
    "$LastAgentToolsFailure",
    "$LastAgentToolsFailureText",
    "$MCPEvaluationEnvironment",
    "$MCPTransport",
    "$StandaloneMCPServer",
    "$StandaloneMCPServerInformation",
    "$SupportedClients",
    "$SupportedMCPClients",
    "AgentTools",
    "AgentToolsObject",
    "AgentToolsObjects",
    "CloudDeployMCPServer",
    "CloudDeployMCPServerBundle",
    "CodeInspectorToolFunction",
    "CreateMCPServer",
    "CreatePreferencesContent",
    "DetectedMCPClients",
    "InstallAgentSkills",
    "InstallMCPServer",
    "ManageWelcomeScreenData",
    "MCPServerObject",
    "MCPServerObjectQ",
    "MCPServerObjects",
    "RunCloudMCPServer",
    "StartMCPServer",
    "TestReportToolFunction",
    "UninstallAgentSkills",
    "UninstallMCPServer",
    "ValidateAgentToolsPacletExtension"
};

Scan[ Protect, $AgentToolsProtectedNames ];

SetAttributes[
    { AgentToolsDeployment, DeployedAgentTools, DeployAgentTools },
    { Protected, ReadProtected }
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $AgentToolsContexts;
    $AgentToolsSymbolNames;
    SetAttributes[ Evaluate @ Names[ "Wolfram`AgentTools`*" ], ReadProtected ];
];

mxInitialize[ ];

End[ ];
EndPackage[ ];
