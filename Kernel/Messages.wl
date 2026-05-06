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

EndPackage[ ];
