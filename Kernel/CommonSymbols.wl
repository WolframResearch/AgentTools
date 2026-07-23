BeginPackage[ "Wolfram`AgentTools`Common`" ];

`$aliasToCanonicalName;
`$catching;
`$catchTopTag;
`$cloudNotebooks;
`$debug;
`$defaultMCPServer;
`$deployCloudNotebooks;
`$deploymentsPath;
`$imagePath;
`$mcpEvaluation;
`$objectVersion;
`$pacletVersion;
`$releaseID;
`$rootPath;
`$serverVersion;
`$storagePath;
`$supportedMCPClients;
`$thisPaclet;
`addToMXInitialization;
`beginDefinition;
`binarySerializeWithDefinitions;
`catchAlways;
`catchMine;
`catchTop;
`catchTopAs;
`chatbookVersionCheck;
`cloudDeployDirectory;
`defaultEnvironment;
`delayedDisplay;
`deployCloudNotebookForMCPApp;
`directoryQ;
`endDefinition;
`endExportedDefinition;
`ensureDirectory;
`ensureFilePath;
`ensureMCPServerExists;
`extendedFullDefinition;
`fileNameJoin;
`fileQ;
`getLLMKitInfo;
`getWolframCommand;
`importResourceFunction;
`initializeVectorDatabases;
`llmKitEnabledQ;
`llmKitSubscribedQ;
`llmKitUsageLimitFailureQ;
`llmKitUsageLimitMessage;
`makeDeploymentBoxes;
`makeMCPServerObjectBoxes;
`mcpServerDirectory;
`mcpServerFile;
`mcpServerInstallations;
`mcpServerLogFile;
`messageFailure;
`messagePrint;
`mxInitialize;
`readCloudWXF;
`readRawJSONFile;
`readWXFFile;
`relatedDocumentation;
`relatedWolframAlphaResults;
`relatedWolframContext;
`throwFailure;
`throwInternalFailure;
`throwTop;
`toJSRegex;
`validateMCPServerObjectData;
`writeCloudWXF;
`writeRawJSONFile;
`writeWXFFile;

(* TOML support for Codex: *)
`getMCPServers;
`readTOMLFile;
`removeMCPServer;
`setMCPServer;
`writeTOMLFile;

(* YAML support for Goose: *)
`exportYAML;
`exportYAMLString;
`importYAML;
`importYAMLString;

(* Shared symbols with Tools subcontexts: *)
`exportMarkdownString;

(* Shared symbols with DeployAgentTools: *)
`defaultToolsetForTarget;
`guessClientName;
`installLocation;
`projectInstallLocation;
`toInstallName;

(* Graphics detection and conversion: *)
`graphicsQ;
`graphicsToImageContent;

(* WolframAlpha image extraction: *)
`extractWolframAlphaImages;

(* Internal failure formatting: *)
`$internalFailureLogPath;
`extractFailureTag;
`formatInternalFailureForMCP;
`generateUniqueFailureFileName;
`cleanupOldFailureLogs;

(* Output logging: *)
`$outputLogDirectory;
`outputLogFile;
`cleanupOldOutputLogs;

(* Logging utilities: *)
`debugPrint;
`writeError;
`writeLog;

(* MCP server dispatch (shared by the local and cloud transports): *)
`handleMethod;
`initializeServerState;
`$preferredProtocolVersion;
`$supportedProtocolVersions;

(* Output sanitization: *)
`sanitizeResponse;

(* MCP client requests / server-to-client traffic: *)
`$mcpClientRequests;
`handleClientResponse;
`handleNotification;
`onClientInitialized;
`onRootsListChanged;
`sendClientRequest;

(* MCP roots: *)
`$clientSupportsRoots;
`$mcpRoot;
`useEvaluatorKernel;

(* MCP Apps / UI resources: *)
`$clientSupportsUI;
`$uiResourceRegistry;
`$toolUIAssociations;
`clientSupportsUIQ;
`mcpAppsEnabledQ;
`initializeUIResources;
`listUIResources;
`loadUIResource;
`makeNotebookUIResult;
`readUIResource;
`toolUIMetadata;
`withToolUIMetadata;

(* Tool options: *)
`$toolOptions;
`$defaultToolOptions;
`toolOptionValue;

(* Paclet extension support: *)
`clearPacletDefinitionCache;
`ensurePacletForInstall;
`findAgentToolsPaclets;
`findInstalledPaclet;
`findRemoteAgentToolsPaclets;
`getAgentToolsDeclaredItems;
`getAgentToolsExtension;
`getAgentToolsExtensionData;
`getAgentToolsExtensionDirectory;
`loadPacletDefinitionFile;
`pacletQualifiedNameQ;
`parsePacletQualifiedName;
`qualifyNamesInLLMEvaluator;
`resolvePacletPrompt;
`resolvePacletServer;
`resolvePacletTool;

EndPackage[ ];