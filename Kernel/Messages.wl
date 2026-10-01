BeginPackage[ "Wolfram`AgentTools`" ];

AgentTools::usage                         = "AgentTools is a symbol for miscellaneous messages.";
AgentTools::DeleteBuiltInMCPServer        = "The MCP server named \"`1`\" is built-in and cannot be deleted.";
AgentTools::DeletedMCPServerObject        = "The MCP server \"`1`\" no longer exists.";
AgentTools::DevelopmentModeUnavailable    = "Development mode is not available from `1`. This option requires an unbuilt paclet with a Scripts directory.";
AgentTools::InvalidDevelopmentMode        = "Invalid value for DevelopmentMode option: `1`. Expected False, True, or a directory path string.";
AgentTools::InstallMCPServer              = "Successfully installed MCP server \"`1`\".";
AgentTools::InstallMCPServerNamed         = "Successfully installed MCP server \"`1`\" for `2`.";
AgentTools::Internal                      = "An unexpected error occurred. `1`";
AgentTools::InvalidApplicationName        = "Invalid value given for ApplicationName: `1`. Expected a string or Automatic.";
AgentTools::InvalidArguments              = "Invalid arguments given for `1` in `2`.";
AgentTools::InvalidMCPConfiguration       = "Invalid MCP configuration file: `1`.";
AgentTools::InvalidMCPServerFile          = "Invalid MCPServerObject file: \"`1`\".";
AgentTools::InvalidMCPServerObject        = "Invalid MCPServerObject argument: `1`.";
AgentTools::InvalidProperty               = "Invalid property specification: `1`.";
AgentTools::InvalidSession                = "StartMCPServer must run in a standalone kernel.";
AgentTools::InvalidTestFile               = "Invalid test file: \"`1`\".";
AgentTools::InvalidToolSpecification      = "Invalid tool specification: `1`.";
AgentTools::InvalidToolsSpecification     = "Invalid tools specification: `1`.";
AgentTools::LLMKitRequired                = "The MCP server \"`1`\" requires an LLMKit subscription to function. Click `2` to subscribe.";
AgentTools::LLMKitSuggested               = "Warning: The MCP server \"`1`\" requires an LLMKit subscription for full functionality. Click `2` to subscribe.";
AgentTools::MCPServerExists               = "MCP server named \"`1`\" already exists. Use `2` to overwrite it.";
AgentTools::MCPServerFileNotFound         = "MCPServerObject file not found for MCPServer named \"`1`\".";
AgentTools::MCPServerNotFound             = "No MCPServerObject found for name \"`1`\".";
AgentTools::NoTestsInFile                 = "No tests found in file: \"`1`\".";
AgentTools::TestFileNotFound              = "Test file not found: \"`1`\".";
AgentTools::TestKernelFailure             = "Failed to start a new kernel for testing. Try again with 'newKernel' set to False.";
AgentTools::ToolNameNotFound              = "No tool named \"`1`\" found.";
AgentTools::UninstallMCPServer            = "Successfully uninstalled MCP server \"`1`\".";
AgentTools::UninstallMCPServerNamed       = "Successfully uninstalled MCP server \"`1`\" for `2`.";
AgentTools::UnknownInstallLocation        = "Unable to determine install location for `1` on `2`. Use File[\[Ellipsis]] to specify a custom location.";
AgentTools::UnknownProjectInstallLocation = "Unable to determine project install location for `1`. Use File[\[Ellipsis]] to specify a custom location.";
AgentTools::UnsupportedMCPClient          = "No automatic installation support for MCP client `1`.";
AgentTools::UnsupportedMCPClientProject   = "No automatic project-level installation support for MCP client `1`.";
AgentTools::InvalidProjectDirectory       = "Invalid project directory specification: `1`. Expected a directory path string or File[\[Ellipsis]].";
AgentTools::UnsupportedOperatingSystem    = "Unsupported operating system: `1`.";
AgentTools::MCPTimeout                    = "MCP request `1` timed out after `2` seconds.";
AgentTools::UnknownTool                   = "Unknown tool: `1`.";
AgentTools::InvalidTOMLFormat             = "Invalid TOML format in file `1` at line `2`: `3`.";
AgentTools::InvalidYAMLFormat             = "Invalid YAML format in file `1` at line `2`: `3`.";

(* PacletDocumentation messages *)
AgentTools::NotebookFileExists            = "Notebook already exists: `1`.";
AgentTools::InvalidOperation              = "Unknown operation: `1`.";
AgentTools::NotebookNotFound              = "Notebook not found: `1`.";
AgentTools::EmptyUsage                    = "Usage parameter cannot be empty. Provide at least one usage case.";
AgentTools::InvalidUsageFormat            = "Invalid usage format: `1`. Expected bullet points with syntax in backticks.";
AgentTools::InvalidSection                = "Invalid section name: `1`. Expected one of: BasicExamples, Scope, GeneralizationsExtensions, Options, Applications, PropertiesRelations, PossibleIssues, InteractiveExamples, NeatExamples.";

(* MCP Prompts messages *)
AgentTools::InvalidMCPPromptSpecification  = "Invalid MCP prompt specification: `1`.";
AgentTools::InvalidMCPPromptsSpecification = "Invalid MCP prompts specification: `1`.";
AgentTools::PromptNameNotFound             = "No prompt named \"`1`\" found in $DefaultMCPPrompts.";
AgentTools::DeprecatedPromptData           = "The \"PromptData\" property is deprecated. Use \"MCPPrompts\" instead.";

(* MCP Apps / UI resource messages *)
AgentTools::UIResourceNotFound              = "UI resource not found: `1`.";
AgentTools::UIResourceLoadFailed            = "Failed to load UI resource from `1`.";
AgentTools::UIAppAssetsMissing              = "UI app assets directory not found. MCP Apps will be disabled.";

(* CodeInspector messages *)
AgentTools::CodeInspectorNoInput            = "Either 'code' or 'file' parameter must be provided.";
AgentTools::CodeInspectorAmbiguousInput     = "Provide either 'code' or 'file', not both.";
AgentTools::CodeInspectorFileNotFound       = "File or directory not found: `1`.";
AgentTools::CodeInspectorNoFilesFound       = "No .wl, .m, or .wls files found in directory: `1`.";
AgentTools::CodeInspectorFailed             = "CodeInspector failed: `1`.";
AgentTools::CodeInspectorInvalidConfidence  = "Confidence level must be between 0 and 1, got `1`.";

(* DeployAgentTools messages *)
AgentTools::DeploymentExists                = "A deployment already exists for target `1`. Use OverwriteTarget -> True to replace it.";
AgentTools::DeploymentsExistWarning         = "Warning: Some deployments already exist. Use OverwriteTarget -> True to replace them.";
AgentTools::DeploymentNotFound              = "No deployment found with UUID \"`1`\".";
AgentTools::InvalidDeploymentData           = "Invalid deployment data: `1`.";
AgentTools::InvalidDeployTarget             = "Invalid deployment target: `1`. Expected a client name string, {name, directory}, File[\[Ellipsis]], or All.";

(* AgentToolsObject messages *)
AgentTools::AgentToolsNotFound              = "No AgentToolsObject found for name \"`1`\".";
AgentTools::InvalidAgentToolsObject         = "Invalid AgentToolsObject specification: `1`.";
AgentTools::AgentToolsEmpty                 = "The agent tools \"`1`\" contain no MCP servers or agent skills to deploy.";
AgentTools::AgentToolsBundleNameAmbiguous   = "The paclet \"`1`\" defines several agent tools bundles: `2`. Specify one of these names.";
AgentTools::InvalidMCPServerNameOption      = "The \"MCPServerName\" option can only be a string when deploying a single MCP server; \"`1`\" has `2` servers.";
AgentTools::DuplicateBundleConfigKey        = "The MCP servers `1` of \"`2`\" would all be installed with the configuration key \"`3`\".";

(* Agent skills messages *)
AgentTools::AgentSkillNotFound              = "No agent skill found for \"`1`\".";
AgentTools::InvalidAgentSkill               = "Invalid agent skill specification: `1`.";
AgentTools::InvalidAgentSkillName           = "Invalid agent skill name \"`1`\". Skill names must be 1 to 64 lowercase letters, digits, and hyphens, without leading, trailing, or consecutive hyphens.";
AgentTools::InvalidAgentSkillDescription    = "The agent skill \"`1`\" needs a description of 1 to 1024 characters.";
AgentTools::DuplicateAgentSkillName         = "Several skills named \"`1`\" were given.";
AgentTools::InvalidSkillsDirectory          = "Invalid skills directory: `1`. Expected a directory that contains skill folders.";
AgentTools::NoSkillsLocation                = "Unable to determine where to install agent skills for `1`. Use the \"SkillsDirectory\" option to specify a directory.";
AgentTools::InvalidSkillsDirectoryOption    = "Invalid value for the \"SkillsDirectory\" option: `1`. Expected Automatic, None, or File[\[Ellipsis]].";
AgentTools::AgentSkillExists                = "A different skill named \"`1`\" already exists at `2`. Use OverwriteTarget -> `3` to replace it.";
AgentTools::AgentSkillModified              = "The skill \"`1`\" at `2` has been modified since it was installed. Use OverwriteTarget -> All to replace it.";
AgentTools::AgentSkillConflict              = "A different skill named \"`1`\" is already installed at `2`. Use OverwriteTarget -> All to replace it.";
AgentTools::AgentSkillUpdate                = "A different version of the skill \"`1`\" is installed at `2`. Use OverwriteTarget -> True to update it.";
AgentTools::AgentSkillNewerVersionKept      = "The skill \"`1`\" at `2` was not replaced because the installed version (`3`) is newer than `4`.";
AgentTools::AgentSkillReplacedNotRemoved    = "The skill \"`1`\" at `2` was replaced by a file or a broken link after it was installed, so it was not removed.";
AgentTools::AgentSkillInUse                 = "The skill \"`1`\" at `2` was not removed because other agent tools deployments still use it.";
AgentTools::AgentSkillNotRemoved            = "The skill \"`1`\" at `2` was modified after it was installed, so it was not removed. Evaluate `3` to remove it.";
AgentTools::AgentSkillWriteFailed           = "Unable to write the agent skill \"`1`\" to `2`.";
AgentTools::AgentSkillRemoveFailed          = "Unable to remove the agent skill \"`1`\" at `2`.";
AgentTools::InstallAgentSkill               = "Successfully installed agent skill \"`1`\".";
AgentTools::InstallAgentSkillNamed          = "Successfully installed agent skill \"`1`\" for `2`.";
AgentTools::UninstallAgentSkill             = "Successfully uninstalled agent skill \"`1`\".";
AgentTools::UninstallAgentSkillNamed        = "Successfully uninstalled agent skill \"`1`\" for `2`.";
AgentTools::UnsupportedSkillsClient         = "No automatic agent skill installation support for client `1`.";
AgentTools::UnsupportedSkillsClientProject  = "No automatic project-level agent skill installation support for client `1`.";
AgentTools::UnknownSkillsLocation           = "Unable to determine the skills location for `1` on `2`. Use File[\[Ellipsis]] to specify a custom location.";
AgentTools::AgentSkillsNotDeployed          = "Warning: The agent skills of \"`1`\" were not installed because `2` does not support agent skills for this target.";
AgentTools::MCPServersNotDeployed           = "Warning: The MCP servers of \"`1`\" were not installed because `2` does not support MCP servers for this target.";
AgentTools::AgentSkillsNotDeployedWarning   = "Warning: Agent skills were not installed for these clients, which do not support them: `1`.";
AgentTools::AgentSkillConflictWarning       = "Warning: Some deployments were skipped because of conflicting agent skills. Use OverwriteTarget -> All to replace them.";
AgentTools::MCPServerNotRemoved             = "The MCP server configuration \"`1`\" could not be removed from `2`.";
AgentTools::DeploymentNotRemoved            = "Warning: The replaced deployment \"`1`\" could not be removed completely.";
AgentTools::AgentSkillUnreadable            = "Unable to read the agent skill file `1`.";
AgentTools::AgentSkillBackupNotRemoved      = "The agent skill \"`1`\" was removed, but its backup at `2` could not be deleted completely. Delete it manually.";
AgentTools::AgentSkillsDisabled             = "The agent tools \"`1`\" contain only agent skills, but \"SkillsDirectory\" -> None disables installing them.";
AgentTools::AgentToolsNothingToDeploy       = "Nothing from the agent tools \"`1`\" can be deployed to `2`.";
AgentTools::DeploymentLockTimeout           = "Timed out waiting for another kernel to finish modifying agent tools deployments.";

(* Paclet extension messages for bundles and agent skills *)
AgentTools::PacletAgentToolsNotFound        = "Agent tools \"`1`\" not found in paclet \"`2`\".";
AgentTools::PacletSkillNotFound             = "Agent skill \"`1`\" not found in paclet \"`2`\".";
AgentTools::InvalidPacletSkillDefinition    = "Invalid agent skill definition in `1`.";

(* PacletTools messages *)
AgentTools::PacletToolsInvalidPath          = "The path \"`1`\" does not exist. Provide an absolute path to either the paclet root directory or the definition notebook (.nb) file.";
AgentTools::PacletCICDLoadFailed            = "Could not load the Wolfram/PacletCICD paclet. Ensure it is installed or that you have internet access.";

(* Paclet extension messages *)
AgentTools::PacletNotInstalled               = "The paclet \"`1`\" is not installed. Evaluate `2` to install it.";
AgentTools::PacletExtensionNotFound          = "No AgentTools extension found in paclet \"`1`\".";
AgentTools::PacletToolNotFound               = "Tool \"`1`\" not found in paclet \"`2`\".";
AgentTools::PacletServerNotFound             = "Server \"`1`\" not found in paclet \"`2`\".";
AgentTools::PacletPromptNotFound             = "Prompt \"`1`\" not found in paclet \"`2`\".";
AgentTools::InvalidPacletToolDefinition      = "Invalid tool definition in `1`.";
AgentTools::InvalidPacletServerDefinition    = "Invalid server definition in `1`.";
AgentTools::PacletDependencyMissing          = "Server \"`1`\" references tool \"`2`\" from paclet \"`3`\", which could not be installed.";
AgentTools::InvalidAgentToolsPacletExtension = "The AgentTools extension in paclet \"`1`\" is invalid: `2`.";
AgentTools::InvalidPacletSpecification       = "Invalid paclet specification: `1`. Expected a PacletObject or a valid paclet name.";
AgentTools::DeletePacletMCPServer            = "Cannot delete paclet-backed server \"`1`\". Evaluate `2` to uninstall the paclet.";

(* ToolOptions messages *)
AgentTools::InvalidToolOptions             = "Invalid value for ToolOptions: `1`. Expected an Association.";
AgentTools::UnrecognizedToolOption         = "Warning: Unrecognized tool name in ToolOptions: \"`1`\".";
AgentTools::UnrecognizedToolOptionName     = "Warning: Unrecognized option \"`1`\" for tool \"`2`\" in ToolOptions.";
AgentTools::InvalidToolOptionValue         = "Warning: Invalid value for tool \"`1`\" in ToolOptions: `2`. Expected an Association. This entry will be ignored.";

(* Usage data messages *)
AgentTools::InvalidSubmitUsageData         = "Invalid value for SubmitUsageData option: `1`. Expected True, False, or Automatic.";

(* Client configuration messages *)
AgentTools::InvalidWolframCommand          = "Invalid value for WolframCommand option: `1`. Expected a string or Automatic.";
AgentTools::InvalidCommandLineArguments    = "Invalid value for CommandLineArguments option: `1`. Expected a list of strings or Automatic.";

(* Cloud deployment messages *)
AgentTools::CloudDeployFailed              = "Failed to deploy MCP server to the cloud: `1`.";
AgentTools::NotCloudConnected              = "A cloud connection is required to deploy an MCP server. Use CloudConnect to sign in.";
AgentTools::InvalidCloudTarget             = "Invalid cloud deployment target: `1`.";

EndPackage[ ];
