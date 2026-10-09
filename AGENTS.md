# AGENTS.md

This file provides guidance to AI agents (Claude Code, GitHub Copilot, etc.) when working with code in this repository.

## Overview

AgentTools is a Wolfram Language package for integrating with AI agents and large language models. It provides MCP servers, agent skills, and other standard interfaces that enable AI systems to leverage Wolfram Language computation, Wolfram|Alpha knowledge, and related resources. The package supports a wide range of AI clients and protocols, with an extensible architecture for adding new tools, prompts, servers, and integration points.

## Development

Always use the WolframLanguageContext tool when working with Wolfram Language code to ensure that you are aware of the latest documentation and other Wolfram resources.

When you make changes to paclet source code, you should also write and run tests for the changes you made using the TestReport tool and check the updated files (including test files) with the CodeInspector tool.

If you need to debug code in the WolframLanguageEvaluator tool, you'll first need to evaluate:

```wl
PacletDirectoryLoad[ "path/to/AgentTools" ];
Get[ "Wolfram`AgentTools`" ]
```

Note: This is not necessary for the TestReport tool, since the tests load the paclet automatically.

You should use the SymbolDefinition tool to investigate symbols rather than use things like `DownValues`, `Definition`, etc. It runs in the same kernel as the WolframLanguageEvaluator tool, so it will have access to the same definitions.

## Writing and Running Tests

Use the TestReport MCP tool to run tests.

Always review [testing.md](docs/testing.md) for detailed instructions before modifying or adding tests.

## Building the Paclet

See [building.md](docs/building.md) for detailed instructions.

## Code Architecture

### Project Structure

- `Kernel/`: Contains the core implementation files
  - `AgentTools.wl`: Main entry point which loads an MX file if available, otherwise proceeds to `Main.wl`
  - `Main.wl`: Entry point for loading other package files; exported symbols must be declared here
  - `AgentSkills.wl`: [Agent skills](docs/agent-tools-objects.md) — normalizing skill specifications (`LLMSkill`, skill directories, paclet skills) into sources, deterministic `SKILL.md` generation, the built-in skill registry (`$defaultAgentSkills`: the skills shipped in `Assets/AgentSkills/`, resolved through the paclet's `"AgentSkills"` asset), hashing (line-ending-normalized manifests), the exported low-level `InstallAgentSkills`/`UninstallAgentSkills`, and the skill registry (`$deploymentsPath/.SkillRegistry`) that reference-counts skill directories shared by several deployments
  - `AgentToolsObject.wl`: `AgentToolsObject` (bundles of MCP servers and agent skills: built-in, paclet-defined, or ad hoc), `AgentToolsObjects`, and `$DefaultAgentTools` (the built-in bundles: each default MCP server plus its built-in agent skills)
  - `Common.wl`: Common utilities and [error handling](docs/error-handling.md)
  - `CommonSymbols.wl`: Any symbols shared between paclet files must be declared here
  - `CreateMCPServer.wl`: Implementation for creating MCP servers
  - `DefaultServers.wl`: Defines several predefined named MCP servers
  - `DeployAgentTools.wl`: Implementation for deploying and managing agent tool deployments: resolves the toolset to an `AgentToolsObject`, deploys its MCP servers and agent skills under a file lock with rollback, and records deployments (schema v2, a superset of v1) so that `DeleteObject` works from recorded data only
  - `Files.wl`: Helper functions for file operations (local WXF/JSON I/O — `writeRawJSONFile`/`writeRawJSONString` use the `jsonConvert` conversion function, which writes values that JSON cannot represent (`None`, `Infinity`, dates, …) as strings — plus `readCloudWXF`/`writeCloudWXF` for cloud-object WXF, used by the cloud admin API's key-label store) and the machine-wide settings store `$rootPath/GlobalSettings.wxf` (`readGlobalSettings`/`getGlobalSetting`/`setGlobalSetting`), which currently holds the usage-data opt-out
  - `Formatting.wl`: Definitions for formatting in notebooks
  - `InstallMCPServer.wl`: Implementation for installing MCP servers for use in some common MCP client applications
  - `MCPClientRequests.wl`: Server-to-client request infrastructure (request registry, response correlation, notification dispatch) used by [MCP roots](docs/mcp-roots.md) and other server-initiated requests
  - `MCPRoots.wl`: [MCP roots](docs/mcp-roots.md) handshake — issues `roots/list`, normalizes `file://` URIs (including malformed Windows variants), and applies the selected directory to the kernel, evaluator, and `RunProcess` calls
  - `MCPServerObject.wl`: Defines the MCP server object format, including its `MCPServerObject` upvalues (`DeleteObject`, `LLMConfiguration`, and `CloudDeploy`)
  - `Messages.wl`: Definitions for error messages
  - `PacletExtension.wl`: Paclet discovery, name resolution, and definition loading for the [paclet extension](docs/paclet-extensions.md) system, including multiple `"AgentTools"` entries per paclet, implicit bundles, and `"AgentSkills"`
  - `PreferencesContent.wl`: Implementation of `CreatePreferencesContent`, which builds the toolset configuration UI for the system preferences dialog (see [preferences-content.md](docs/preferences-content.md))
  - `Server/`: MCP server implementation, split by transport so the local (stdio) and cloud (HTTP) servers share a common core
    - `Server.wl`: Aggregator that declares the server-session state shared across the subcontexts, defines the exported `$MCPEvaluationEnvironment`/`$MCPTransport` host descriptors (bound per session/request by each transport) and the exported `$StandaloneMCPServer`/`$StandaloneMCPServerInformation` descriptors of the standalone MCP server product (a kernel that only runs the MCP server; set only by the standalone application, `False`/`<| |>` everywhere else), and loads the children below
    - `Shared.wl`: Transport-agnostic core — method dispatch (`handleMethod`), tool/prompt resolution, tool evaluation and result formatting, capability negotiation (`initResponse`), server-state build (`initializeServerState`), environment-specific tool overrides (`applyToolOverrides`, driven by the `"Overrides"` tool property), and logging helpers
    - `Local.wl`: Local stdio transport — `StartMCPServer`, the read loop (`processRequest`), tool warmup, and stdout-protecting output suppression (`superQuiet`); calls the usage-data hooks (`initializeUsageData`, `recordUsageData`)
    - `UsageData.wl`: [Usage data](docs/usage-data.md) for local servers — per-session state (`$mcpSessionID`, `$mcpClientInformation`, `$usageEvents`), the product identity information included in every payload (`$productIdentityInfo`: the same license/machine/product data the paclet manager sends to the paclet server, which is why the data is not anonymous), the standalone MCP server descriptors included alongside it, the enabling logic (`SUBMIT_USAGE_DATA` environment variable, otherwise the servers' `"EnableUsageData"` property combined with the global opt-out from `GlobalSettings.wxf` via `getGlobalUsageDataSetting`/`setGlobalUsageDataSetting`, which the preferences checkbox reads and writes), the session file under `$rootPath/UsageData`, the hourly keep-alive task, and the locked submission of finished sessions to the usage endpoint
    - `Cloud.wl`: Cloud HTTP transport — `RunCloudMCPServer` (stateless Streamable HTTP handler), `CloudDeployMCPServer`, the full-directory-bundle deploy implementation (`cloudDeployDirectory`) behind both the `CloudDeploy` UpValue on `MCPServerObject` (the UpValue itself is defined in `MCPServerObject.wl`) and the exported `CloudDeployMCPServerBundle` that deploys `/mcp`, the landing page, `/api/info`, and the forced-`Private` admin page/API, the self-describing session-ID capability codec, server-embedding deploy helpers (including the cloud-paclet detection — `$cloudSupportPacletVersion`/`cloudAgentToolsAvailableQ` — that swaps the heavy definition-bundling payloads for light paclet-loading ones when the connected cloud account has a new-enough Wolfram/AgentTools installed), the landing-page `/api/info` metadata generator, and the owner-only `/api/admin` key-management handler (`runCloudAdminAPI`: list/create/revoke `PermissionsKey`s) (see [Cloud Deployment spec](Specs/CloudDeployment.md))
  - `SupportedClients.wl`: Registry of supported clients (`$SupportedClients`; `$SupportedMCPClients` is the subset with an MCP install location), including each client's MCP configuration location and agent skills locations (`"SkillsLocation"`, `"SkillsProjectPath"`), and relevant utility functions
  - `ValidateAgentToolsPacletExtension.wl`: Validation of `"AgentTools"` [paclet extensions](docs/paclet-extensions.md)
  - `UIResources.wl`: [MCP Apps](docs/mcp-apps.md) UI resource registry, client capability detection, and shared notebook delivery helpers (cloud deployment and experimental inline embedding)
  - `Utilities.wl`: General-purpose helpers — LLMKit subscription checks, Chatbook version verification, and `toJSRegex` for converting ICU/PCRE patterns to ECMA 262 (used when sanitizing tool schema `"pattern"` fields)
  - `YAML.wl`: YAML import/export helpers (`importYAML`, `importYAMLString`, `exportYAML`, `exportYAMLString`) used by YAML-based MCP clients (e.g. Goose)
  - `Tools/`: Contains several files defining predefined MCP tools used by default servers. If tool schemas are modified, rebuild the agent skills (`wolframscript -f Scripts/BuildAgentSkills.wls`) and commit the updated `Assets/AgentSkills/`; a test in `Tests/AgentSkillsBuild.wlt` fails when the built skills are stale.
  - `Prompts/`: Contains files defining predefined [MCP prompts](docs/mcp-prompts.md) used by default servers
- `Assets/`: Static assets bundled with the paclet
  - `AgentSkills/`: The built agent skills (complete skill directories generated by `Scripts/BuildAgentSkills.wls`; **do not edit manually**), shipped as the paclet's `"AgentSkills"` asset and deployed by the built-in `$DefaultAgentTools` bundles
  - `Apps/`: HTML and JSON files for [MCP Apps](docs/mcp-apps.md) UI resources
  - `Cloud/`: Landing- and admin-page HTML/CSS/JS for [cloud-deployed MCP servers](Specs/CloudDeployment.md) — the dynamic `index.html` + `assets/` (fetches `/api/info`) and the self-contained owner-only `admin.html` (calls `/api/admin`), read via `PacletObject[…]["AssetLocation","Cloud"]`
- `ResourceFunctions/`: Local copies of the Wolfram Function Repository functions the paclet uses (one `.wl` file per function, each wrapped in its own context), which `importResourceFunction` in `Kernel/Common.wl` prefers over fetching from the repository so that builds and source loads work without cloud access; not declared in `PacletInfo.wl`, so not part of the built paclet (see [building.md](docs/building.md#resource-functions-and-offline-builds) and [ResourceFunctions/README.md](ResourceFunctions/README.md))
- `FrontEnd/`: FrontEnd extension resources loaded by the notebook front end
  - `Assets/AgentTools.wl`: Localized strings (`AgentToolsStrings`) and graphics (`AgentToolsExpressions`) used by `CreatePreferencesContent` (see [preferences-content.md](docs/preferences-content.md))
- `Scripts/`: Contains utility scripts for building, testing, and running the paclet
  - `BuildAgentSkills.wls`: Builds the agent skills from `AgentSkills/` into `Assets/AgentSkills/`, or checks that they are up to date with `--check` (see [agent-skills.md](docs/agent-skills.md))
  - `Resources/AgentSkillsBuilder.wl`: The loadable skill builder (context `` Wolfram`AgentSkillsBuilder` ``) used by `BuildAgentSkills.wls` and `Tests/AgentSkillsBuild.wlt`: generates the `.wls` scripts from MCP tool definitions, copies the references, and stamps the version into `SKILL.md`
  - `Resources/SkillScriptTemplate.wls`: Template used to generate `.wls` scripts for agent skills
- `AgentSkills/`: Agent skill sources (see [agent-skills.md](docs/agent-skills.md)); the built skills are in `Assets/AgentSkills/`
  - `Manifest.wl`: Maps skill names to their MCP tools and shared references
  - `References/`: Single-source shared reference files copied into every built skill at build time
  - `Skills/`: The hand-authored `SKILL.md` of each skill (`Skills/<name>/SKILL.md`, without a `version` line), plus any hand-authored files of that skill directly in `Skills/<name>/references/` and `Skills/<name>/scripts/`, which the build copies into the built skill. The built skills in `Assets/AgentSkills/<name>/` (`SKILL.md` with `metadata.version` stamped, `scripts/`, `references/`) are generated by `Scripts/BuildAgentSkills.wls` and **must not be edited manually** — modify the source files (`AgentSkills/`, `Scripts/Resources/SkillScriptTemplate.wls`, and the corresponding tool definitions in `Kernel/Tools/`) and rebuild instead.
- `.claude-plugin/`: Claude Code plugin packaging
  - `marketplace.json`: Plugin marketplace definition for distributing agent skills via Claude Code (the plugins' `source` is `./Assets/AgentSkills`)
- `Notes/`: Development notes and design explorations
- `Documentation/`: Contains documentation notebooks
  - `English/`: English documentation
    - `ReferencePages/Symbols/`: Reference pages for exported symbols
    - Use the ReadNotebook tool to read documentation notebooks as markdown text
- `TestResources/`: Mock paclets and other test fixtures
- `Tests/`: Contains test files (.wlt)
- `Specs/`: Design specifications for features
- `docs/`: Developer documentation
  - `testing.md`: Writing and running tests
  - `building.md`: Building the paclet for distribution
  - `error-handling.md`: Error handling architecture and patterns
  - `servers.md`: Predefined MCP servers and choosing the right one
  - `tools.md`: MCP tools system, tool options, and how to add new tools
  - `mcp-prompts.md`: MCP prompts system and how to add new prompts
  - `mcp-clients.md`: MCP client support and installation
  - `mcp-apps.md`: MCP Apps system for interactive UI resources
  - `code-inspector-rules.md`: Adding custom CodeInspector rules
  - `agent-skills.md`: Agent skills system, build process, and how to add new skills
  - `deploy-agent-tools.md`: Deployment management for agent tools
  - `agent-tools-objects.md`: `AgentToolsObject` bundles, agent skills, `InstallAgentSkills`/`UninstallAgentSkills`, and how deployments share skill directories
  - `cloud-deployment.md`: Deploying an `MCPServerObject` as a remote HTTP MCP server in the Wolfram Cloud (`CloudDeploy`/`CloudDeployMCPServer`, directory layout, authentication, statelessness, admin key management)
  - `mcp-roots.md`: MCP roots handshake, working-directory propagation, and guidance for tools that resolve relative paths
  - `paclet-extensions.md`: Third-party paclet extension system for contributing tools, prompts, and servers
  - `preferences-content.md`: System preferences UI for managing deployed Wolfram toolsets
  - `usage-data.md`: Usage data collected by the built-in local servers (what is recorded, including the product identity information that identifies the installation; the `"SubmitUsageData"` option, `SUBMIT_USAGE_DATA`, the global opt-out in `GlobalSettings.wxf`, storage and submission)

### MCP Documentation

Use the official MCP documentation when working on the server implementation (`Kernel/Server/`).

- [Overview](https://modelcontextprotocol.io/specification/2025-11-25/basic/index.md)
- [Lifecycle](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle.md)
- [Tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools.md)
- [Prompts](https://modelcontextprotocol.io/specification/2025-11-25/server/prompts.md)
- [List of all documentation pages](https://modelcontextprotocol.io/llms.txt)

## Key Development Patterns

### Error Handling

- Use `beginDefinition` and `endDefinition` wrappers for function definitions
- Follow error handling patterns using `Enclose`, `Confirm`, and `ConfirmBy`
- Use `catchMine` around the body of exported functions
- Use `throwFailure["tag", args...]` to issue a message and return a `Failure[...]` to top level
- Any tag used in `throwFailure` must be defined in `Messages.wl`

For comprehensive documentation on error handling, see [error-handling.md](docs/error-handling.md).

### Exported Functions

Exported functions in the main context must be declared in both the PacletInfo.wl and Kernel/Main.wl files. Define them using the following format:

```wl
NameOfFunction // beginDefinition;
NameOfFunction[ ... ] := catchMine @ internalFunction[ ... ];
NameOfFunction // endExportedDefinition;
```

The name of the internal function is often the same as the exported function, but beginning with a lowercase letter.

### Internal Functions

Define internal helper functions using the following format:

```wl
nameOfFunction // beginDefinition;

nameOfFunction[ ... ] := Enclose[
    body,
    throwInternalFailure
];

nameOfFunction // endDefinition;
```

The `Enclose` wrapper is only necessary if you are using any `Confirm`, `ConfirmBy`, `ConfirmMatch`, etc. functions in the body, and it will trigger a throw of an internal failure error if any of them fail. See [error-handling.md](docs/error-handling.md) for details on how these are optimized.

### Naming Conventions

- Use `UpperCamelCase` for exported function names.
- Use `lowerCamelCase` for internal function names.
- Use `$UpperCamelCase` for exported variables and constants.
- Use `$lowerCamelCase` for package or file-scoped variables and constants.
- Use `$$patternName` for reusable patterns to improve readability, e.g.
  ```wl
  $$strings = _String | { ___String };
  ```
  which can improve readability:
  ```wl
  toCommaSeparated[ names: $$strings ] := StringRiffle[ Flatten @ { names }, "," ];
  ```

### Other Development Guidelines

- Whenever you modify source code, you should also write and run tests for the changes you made.
- If you are using a package-scoped symbol defined in a different file, ensure that it is declared in a context that's reachable (e.g. `CommonSymbols.wl`).

## Special Considerations

While working on this paclet, you are also working on the code that's running the MCP server providing your Wolfram tools. Sometimes you might run into issues related to this and you'll need to carefully consider how current changes might be affecting the MCP server.