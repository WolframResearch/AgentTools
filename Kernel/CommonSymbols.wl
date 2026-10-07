BeginPackage[ "Wolfram`AgentTools`Common`" ];

`$aliasToCanonicalName;
`$catching;
`$catchTopTag;
`$cloudNotebooks;
`$commandLineArguments;
`$debug;
`$defaultMCPServer;
`$deployCloudNotebooks;
`$deploymentLockFile;
`$deploymentsPath;
`$imagePath;
`$mcpEvaluation;
`$objectVersion;
`$pacletVersion;
`$releaseID;
`$rootPath;
`$serverVersion;
`$skillRegistryPath;
`$storagePath;
`$supportedClients;
`$thisPaclet;
`$wolframCommand;
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
`documentationProvidedAvailableQ;
`documentationProvidedOptions;
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
`writeRawJSONString;
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
`clearMCPInstallationRecord;
`clearRecordedInstallation;
`defaultToolsetForTarget;
`guessClientName;
`installDisplayName;
`installLocation;
`localMCPServerConfigKey;
`mcpServerConfigKey;
`preflightMCPServerInstall;
`projectInstallLocation;
`projectSkillsLocation;
`removeMCPConfigEntry;
`skillsLocation;
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

(* Global settings (Files.wl) and the usage-data setting kept there (Server/UsageData.wl): *)
`$globalSettingsFile;
`getGlobalSetting;
`getGlobalUsageDataSetting;
`readGlobalSettings;
`setGlobalSetting;
`setGlobalUsageDataSetting;

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
`convertPUACharacters;
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
`findRemoteAgentToolsPaclet;
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
(* Paclet extension support for bundles and agent skills: *)
`getAgentToolsBundles;
`getAgentToolsExtensionDirectories;
`getAgentToolsExtensions;
`getAgentToolsItemDeclaration;
`resolvePacletBundle;
`resolvePacletSkill;

(* Agent skills (AgentSkills.wl): *)
`$defaultAgentSkills;
`agentSkillDescriptionQ;
`agentSkillName;
`agentSkillNameQ;
`applySkillInstallPlan;
`builtInSkillDefinition;
`canonicalPath;
`canonicalPathKey;
`compareSkillManifest;
`deleteSkillRegistryEntry;
`deploymentUUIDExistsQ;
`foldPathCase;
`parseSkillMarkdown;
`planSkillInstall;
`readSkillRegistryEntry;
`releaseSkillReference;
`resolveSkillsRoot;
`skillDirectoryState;
`skillManifest;
`skillRegistryKey;
`skillReleaseMessages;
`sweepSkillRegistry;
`toAgentSkillSource;
`writeSkillRegistryEntry;

(* Agent tools bundles (AgentToolsObject.wl): *)
`$defaultAgentTools;
`agentToolsObjectQ;
`makeAgentToolsObjectBoxes;
`toAgentToolsObject;

(* Deployment lock (DeployAgentTools.wl): *)
`withDeploymentLock;

EndPackage[ ];