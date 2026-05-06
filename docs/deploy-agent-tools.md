# Deploy Agent Tools

This document describes the deployment management system for deploying Wolfram tools to AI agent clients.

## Overview

`DeployAgentTools` provides a higher-level alternative to `InstallMCPServer` that tracks deployments as managed, reversible operations. Each deployment is represented as an `AgentToolsDeployment` object that can be inspected, listed, and deleted.

Three symbols are provided, all in the `System` context:

| Symbol | Description |
|--------|-------------|
| `DeployAgentTools[target]` | Create a tracked deployment |
| `AgentToolsDeployment[...]` | Object representing a deployment |
| `DeployedAgentTools[]` | List and query existing deployments |

In the current phase, `DeployAgentTools` wraps `InstallMCPServer` to deploy MCP server configurations. Future phases will extend it to install agent skills, hooks, and other components as part of a single deployment.

## DeployAgentTools

### Signatures

```wl
DeployAgentTools[target]
DeployAgentTools[target, server]
DeployAgentTools[target, server, opts]
DeployAgentTools[All]
DeployAgentTools[All, server]
```

### Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `target` | `String`, `File[...]`, `{String, dir}`, or `All` | The client to deploy to (same target formats as `InstallMCPServer`). Pass `All` to deploy to every client in `$SupportedMCPClients` (see [Deploying to All Clients](#deploying-to-all-clients)). |
| `server` | `MCPServerObject`, `String`, or `Automatic` | The MCP server to deploy. Defaults to `Automatic`, which resolves to the target client's default toolset (see [mcp-clients.md](mcp-clients.md#clients-with-installmcpserver-support)) — `"WolframLanguage"` for coding clients and `"Wolfram"` for chat clients. For `File[...]` targets the per-client default only applies when the path or content identifies a known client (or `"ApplicationName"` is supplied); otherwise it falls back to `"Wolfram"`. |

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `OverwriteTarget` | `False` | If `True`, replace any existing deployment for the same target |

`DeployAgentTools` also accepts all `InstallMCPServer` options, which are passed through:

- `"ApplicationName"`, `"DevelopmentMode"`, `"EnableMCPApps"`, `"MCPServerName"`, `"ProcessEnvironment"`, `"ToolOptions"`, `"VerifyLLMKit"`

### Examples

```wl
(* Deploy to Claude Desktop with default server *)
dep = DeployAgentTools["ClaudeDesktop"]

(* Deploy a specific server to Cursor *)
dep = DeployAgentTools["Cursor", "WolframLanguage"]

(* Replace an existing deployment *)
dep = DeployAgentTools["ClaudeDesktop", OverwriteTarget -> True]

(* Project-level deployment *)
dep = DeployAgentTools[{"ClaudeCode", "/path/to/project"}]

(* Deploy with tool options *)
dep = DeployAgentTools["ClaudeCode",
    "ToolOptions" -> <|"WolframLanguageEvaluator" -> <|"Method" -> "Local"|>|>
]

(* Deploy to every supported client at once *)
deps = DeployAgentTools[All]
```

### Behavior

1. Validates the target specification; issues `AgentTools::InvalidDeployTarget` for unrecognized forms
2. Resolves the target to a concrete config file path (same resolution as `InstallMCPServer`)
3. For `{name, dir}` targets, the directory is expanded to an absolute `File[...]` path in the stored deployment record
4. Checks for an existing deployment matching the config file; errors if one exists (unless `OverwriteTarget -> True`)
5. Calls `InstallMCPServer` with the resolved target and filtered options
6. Creates a persistent deployment record on disk
7. Returns an `AgentToolsDeployment` object

### Deploying to All Clients

`DeployAgentTools[All]` deploys to every client in `$SupportedMCPClients`. The server defaults to `Automatic` so each client receives its own configured default toolset (`"WolframLanguage"` for coding clients, `"Wolfram"` for chat clients); pass an explicit second argument to deploy the same server everywhere.

```wl
(* One default deployment per supported client *)
deps = DeployAgentTools[All]

(* Force a specific toolset for every client *)
deps = DeployAgentTools[All, "WolframLanguage"]

(* Replace any existing deployments along the way *)
deps = DeployAgentTools[All, OverwriteTarget -> True]
```

The return value is a list with one entry per client:

- `AgentToolsDeployment[...]` for each newly created deployment
- `Missing["DeploymentExists", target]` for any client that already had a deployment and was skipped (only when `OverwriteTarget -> False`)
- `Missing["Unsupported", {target, $OperatingSystem}]` for any client that has no install location on the current operating system (e.g. clients with platform-specific config paths)

When at least one client is skipped because of an existing deployment, `AgentTools::DeploymentsExistWarning` is issued. Use `OverwriteTarget -> True` to replace existing deployments instead of skipping them. The warning is not issued for unsupported clients — those entries simply appear in the result list so callers can see which clients were skipped.

## AgentToolsDeployment

An `AgentToolsDeployment` wraps an association containing the deployment record.

### Properties

```wl
dep["PropertyName"]
dep["MCP", "Options"]
```

| Property | Returns |
|----------|---------|
| `"UUID"` | UUID string uniquely identifying the deployment |
| `"ClientName"` | Canonical client name (e.g. `"ClaudeDesktop"`) |
| `"Target"` | Original target specification |
| `"Toolset"` | Toolset name string (e.g. `"WolframLanguage"`). The canonical name for the deployed MCP server. |
| `"Server"` | Legacy shortcut for `data["MCP", "Server"]`. New deployments dual-write this alongside `"Toolset"`; prefer `"Toolset"` in new code. |
| `"ConfigFile"` | `File[...]` pointing to the client's config file |
| `"Timestamp"` | `DateObject` when the deployment was created |
| `"PacletVersion"` | Paclet version at deployment time |
| `"MCPServerObject"` | The `MCPServerObject` for the deployed toolset |
| `"Scope"` | Deployment scope: `"Global"` for named clients, or `File[...]` directory for project-level deployments |
| `"Tools"` | List of tools provided by the deployed toolset |
| `"LLMConfiguration"` | The `LLMConfiguration` for the deployed toolset |
| `"Data"` | Full internal data association |
| `"Location"` | `File[...]` deployment directory |
| `"Properties"` | List of all property names |

### Deleting Deployments

Use `DeleteObject` to remove a deployment:

```wl
DeleteObject[dep]
```

This:
1. Calls `UninstallMCPServer` to remove the server configuration from the client
2. Deletes the deployment record from disk

## DeployedAgentTools

### Signatures

```wl
DeployedAgentTools[]           (* all deployments *)
DeployedAgentTools["Client"]   (* filter by client name *)
```

### Examples

```wl
(* List all deployments *)
DeployedAgentTools[]
(* {AgentToolsDeployment[...], AgentToolsDeployment[...]} *)

(* Filter by client *)
DeployedAgentTools["ClaudeDesktop"]
(* {AgentToolsDeployment[...]} *)

(* Aliases are resolved *)
DeployedAgentTools["Claude"]  (* same as "ClaudeDesktop" *)
```

## Storage

Deployment records are stored as WXF files under:

```
$UserBaseDirectory/ApplicationData/Wolfram/AgentTools/Deployments/<ClientName>/<UUID>/Deployment.wxf
```

Deployments are grouped by canonical client name. There is no master index file — `DeployedAgentTools` scans the directory structure directly.

## Related Files

- `Kernel/DeployAgentTools.wl` - Implementation of `DeployAgentTools`, `AgentToolsDeployment`, and `DeployedAgentTools`
- `Kernel/InstallMCPServer.wl` - Underlying installation mechanism
- `Kernel/Formatting.wl` - Summary box formatting for `AgentToolsDeployment`
- `Kernel/Files.wl` - `$deploymentsPath` definition
- `Kernel/Messages.wl` - Error messages for deployment operations
- `Tests/DeployAgentTools.wlt` - Tests for the deployment system
- `Specs/DeployAgentTools.md` - Design specification

## Related Documentation

- [mcp-clients.md](mcp-clients.md) - Client installation and the `"MCPServerName"` option
- [servers.md](servers.md) - Predefined servers and the shared config key
- [tools.md](tools.md) - Available MCP tools
