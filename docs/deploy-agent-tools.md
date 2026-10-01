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

`DeployAgentTools` deploys an `AgentToolsObject` — a bundle of MCP servers and agent skills — as one deployment: it installs the MCP servers with `InstallMCPServer` and copies the agent skills into the client's skills directory. See [agent-tools-objects.md](agent-tools-objects.md) for bundles, agent skills, and how deployments share skill directories. Future phases may add hooks and other components.

## DeployAgentTools

### Signatures

```wl
DeployAgentTools[target]
DeployAgentTools[target, tools]
DeployAgentTools[target, tools, opts]
DeployAgentTools[All]
DeployAgentTools[All, tools]
```

### Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `target` | `String`, `File[...]`, `{String, dir}`, or `All` | The client to deploy to (same target formats as `InstallMCPServer`). Pass `All` to deploy to every client in `$SupportedClients` (see [Deploying to All Clients](#deploying-to-all-clients)). |
| `tools` | `AgentToolsObject`, `MCPServerObject`, `String`, `Association`, or `Automatic` | The toolset to deploy. A name resolves to a user-created MCP server, a built-in bundle (`$DefaultAgentTools`), a paclet bundle, or a paclet MCP server, in that order (installing the paclet if necessary); an association is an ad hoc `AgentToolsObject`. Defaults to `Automatic`, which resolves to the target client's default toolset (see [mcp-clients.md](mcp-clients.md#clients-with-installmcpserver-support)) — `"WolframLanguage"` for coding clients and `"Wolfram"` for chat clients. For `File[...]` targets the per-client default only applies when the path or content identifies a known client (or `"ApplicationName"` is supplied); otherwise it falls back to `"Wolfram"`. |

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `OverwriteTarget` | `False` | `True` replaces conflicting deployments and updates unmodified agent skills from the same source; `All` also overwrites skill directories that were modified or belong to a different skill (see [agent-tools-objects.md](agent-tools-objects.md#overwritetarget)) |
| `"SkillsDirectory"` | `Automatic` | Where to install agent skills: derived from the target (`Automatic`), a directory (`File[...]`), or not at all (`None`) |

`DeployAgentTools` also accepts all `InstallMCPServer` options, which are passed through:

- `"ApplicationName"`, `"CommandLineArguments"`, `"DevelopmentMode"`, `"EnableLLMKit"`, `"EnableMCPApps"`, `"MCPServerName"`, `"ProcessEnvironment"`, `"SubmitUsageData"`, `"ToolOptions"`, `"VerifyLLMKit"`, `"WolframCommand"`

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

1. Resolves the toolset to an `AgentToolsObject` (an `MCPServerObject` becomes a bundle with just that server)
2. Validates the target specification (`AgentTools::InvalidDeployTarget` for unrecognized forms) and resolves the MCP config file and the skills directory; components that the target doesn't support are skipped with a warning, and the deployment fails if nothing can be deployed
3. Runs the checks that `InstallMCPServer` would run (LLMKit, tool initialization) and prepares the skills, before taking a file lock that serializes deployments across kernels
4. Checks for conflicting deployments — the same MCP config key in the same config file, or the same toolset for the same client and location — and fails (unless `OverwriteTarget -> True`)
5. Checks every skill destination (see [agent-tools-objects.md](agent-tools-objects.md#shared-skill-directories)), then installs the MCP servers and agent skills, undoing everything if a step fails
6. Creates a persistent deployment record on disk and removes the deployments it replaced
7. Returns an `AgentToolsDeployment` object

### Deploying to All Clients

`DeployAgentTools[All]` deploys to every client in `$SupportedClients`. The server defaults to `Automatic` so each client receives its own configured default toolset (`"WolframLanguage"` for coding clients, `"Wolfram"` for chat clients); pass an explicit second argument to deploy the same server everywhere.

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
- `Missing["Unsupported", {target, $OperatingSystem}]` for any client to which none of the toolset's components can be deployed: the client has no MCP install location on the current operating system (e.g. clients with platform-specific config paths), or, for a toolset with only agent skills, the client has no skills directory (e.g. Claude Desktop, LM Studio, Amazon Q)
- `Missing["AgentSkillConflict", target]` for any client where an agent skill conflicts with an existing skill directory (use `OverwriteTarget -> All`)

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
| `"ToolsetType"` | `"AgentToolsObject"` or `"MCPServerObject"` |
| `"AgentToolsObject"` | The deployed bundle, resolved again by name (`Missing["NotAvailable"]` for ad hoc bundles); for an `MCPServerObject` deployment, the server's implicit bundle |
| `"MCPServerNames"` / `"MCPServerObjects"` | The deployed MCP servers |
| `"AgentSkills"` / `"SkillsDirectory"` | The installed agent skills and their directory |
| `"ClientName"` | Canonical client name (e.g. `"ClaudeDesktop"`) |
| `"Target"` | Original target specification |
| `"Toolset"` | The name of the deployed toolset: the bundle name (e.g. `"WolframLanguage"` or `"PublisherID/MyPaclet/MyPaclet"`), or the server name for an `MCPServerObject` deployment. For a bundle this is not necessarily a server name; use `"Server"`/`"MCPServerNames"` for server names. |
| `"Server"` | The primary (first) MCP server name (`data["MCP", "Server"]`); `"MCPServerNames"` gives all of them. The raw record's top-level `"Toolset"` key also holds the primary server name, for compatibility with older versions. |
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
1. Removes the recorded MCP config entries from the client's configuration (by their recorded keys — no server is resolved again, so this works after the paclet was updated or uninstalled)
2. Releases the deployment's agent skills: a skill directory is deleted only when no other deployment uses it and it was not modified after it was installed (see [agent-tools-objects.md](agent-tools-objects.md#shared-skill-directories))
3. Deletes the deployment record from disk

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

Deployments are grouped by canonical client name. There is no master index file — `DeployedAgentTools` scans the directory structure directly. The same directory holds the skill registry (`.SkillRegistry/`) and the lock file (`.lock`); dot-prefixed entries are not deployments.

Records written since agent skills were added use schema version 2, a superset of version 1: the `"MCP"` and top-level `"Toolset"` keys still describe the primary MCP server, so older AgentTools versions can list and remove such deployments. Version 1 records are still read, conflict-checked, and removable. See [Specs/AgentToolsObject.md](../Specs/AgentToolsObject.md#deployment-records-schema-v2).

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
