# DeployAgentTools — Design Specification

## Overview

`DeployAgentTools` provides a unified interface for deploying Wolfram Language tools to AI agent clients. It manages deployments as tracked, reversible operations — each deployment is represented as an `AgentToolsDeployment` object that can be inspected, listed, and deleted.

In phase 1, `DeployAgentTools` wraps `InstallMCPServer` to deploy MCP server configurations. In phase 2 and beyond, it will extend to install agent skills, hooks, LSP servers, and other components as part of a single deployment.

Three new symbols are introduced, all in the `System` context:

- **`DeployAgentTools`** — Create a deployment
- **`AgentToolsDeployment`** — Object representing a deployment
- **`DeployedAgentTools`** — List and query existing deployments

---

## Goals

- Provide a higher-level alternative to `InstallMCPServer` that tracks what was deployed and where.
- Support reversible deployments via `DeleteObject[AgentToolsDeployment[...]]`.
- Use an extensible data model that accommodates future component types (skills, hooks, LSP) without breaking existing deployments.
- Maintain a persistent record of all deployments on disk.

---

## Prerequisite: Unified Config Key for Built-In Servers

### Problem

Currently, `InstallMCPServer` uses the server's `"Name"` property as the key when writing to a client's config file. Since each built-in server has a distinct name (`"Wolfram"`, `"WolframAlpha"`, `"WolframLanguage"`, `"WolframPacletDevelopment"`), multiple built-in servers can be installed to the same client simultaneously:

```wl
InstallMCPServer["ClaudeDesktop", "Wolfram"]
InstallMCPServer["ClaudeDesktop", "WolframLanguage"]
(* Both entries now coexist in claude_desktop_config.json *)
```

This was never intended. The built-in servers are mutually exclusive variants of the same Wolfram MCP server — they differ only in which tools and prompts are enabled. Running multiple built-in servers simultaneously causes overlapping tools, redundant resource usage, and user confusion.

### Solution

Add an `"MCPServerName"` property to each built-in server definition in `DefaultServers.wl`, set to `"Wolfram"` for all of them:

```wl
$defaultMCPServers[ "Wolfram" ] := <|
    "Name"          -> "Wolfram",
    "MCPServerName" -> "Wolfram",
    ...
|>;

$defaultMCPServers[ "WolframLanguage" ] := <|
    "Name"          -> "WolframLanguage",
    "MCPServerName" -> "Wolfram",
    ...
|>;

(* Same for WolframAlpha, WolframPacletDevelopment *)
```

The config key is resolved with the following precedence:

1. The `"MCPServerName"` option passed to `InstallMCPServer` (if not `Automatic`).
2. The `"MCPServerName"` property on the `MCPServerObject` (if present).
3. The `"Name"` property on the `MCPServerObject` (existing fallback behavior).

When the resolved config key is the shared built-in default (`"Wolfram"`), installing one built-in variant must also clear any recorded installation for the same target from the other built-in Wolfram variants before recording the new installation. Otherwise `obj["Installations"]` and `UninstallMCPServer[All, ...]` can become stale even though the client config only has a single `"Wolfram"` entry.

Additionally, `InstallMCPServer` gains a new `"MCPServerName"` option (default `Automatic`) that lets users override the config key. This provides an escape hatch for users who want multiple built-in servers installed simultaneously despite the default mutual-exclusivity:

```wl
(* Default: both write to the "Wolfram" key, so the second overwrites the first *)
InstallMCPServer["ClaudeDesktop", "Wolfram"]
InstallMCPServer["ClaudeDesktop", "WolframLanguage"]

(* Override: install under a custom key to keep both *)
InstallMCPServer["ClaudeDesktop", "Wolfram", "MCPServerName" -> "WolframBasic"]
InstallMCPServer["ClaudeDesktop", "WolframLanguage", "MCPServerName" -> "WolframDev"]
```

### Effects

1. **Built-in servers overwrite each other by default.** Installing `"WolframLanguage"` after `"Wolfram"` replaces the existing entry, since both write to the `"Wolfram"` key.
2. **Consistent client-side naming.** Regardless of which built-in server variant is installed, the MCP client always shows the server as `"Wolfram"`.
3. **User-created servers are unaffected.** They do not set `"MCPServerName"`, so they continue to use their `"Name"` as the config key.
4. **Override available.** Users who need multiple built-in servers can use the `"MCPServerName"` option to assign distinct config keys.

### Breaking Change

This is a deliberate minor breaking change. Users who previously had multiple built-in servers installed to the same client will find that only one remains after upgrading and re-installing. This is the intended behavior — those configurations were never supported and could cause issues with overlapping tools. The `"MCPServerName"` option provides a workaround for users who explicitly want the old behavior.

### Implementation

| File | Change |
|---|---|
| `Kernel/DefaultServers.wl` | Add `"MCPServerName" -> "Wolfram"` to all four built-in server definitions. |
| `Kernel/InstallMCPServer.wl` | Add `"MCPServerName" -> Automatic` option to both `InstallMCPServer` and `UninstallMCPServer`. Resolve the config key using the precedence chain (option, then server property, then `"Name"`). Apply in both internal functions `installMCPServer` and `uninstallMCPServer`. **Important:** `obj["Name"]` is currently used for two purposes — (1) extracting the server config from `data["mcpServers", name]` in the MCPServerObject's JSON, and (2) as the key written to the client's config file. Only usage (2) should be replaced with the resolved MCPServerName; usage (1) must continue to use `obj["Name"]`. This dual-use exists in both the Codex TOML path (where usage 2 is `setMCPServer[existing, name, ...]` / `removeMCPServer[existing, name]`) and the standard JSON path (where usage 2 is `existing[keys, name] = server` / `KeyDropFrom[existing[keys], name]`). Also clear stale built-in installation records when one built-in Wolfram variant overwrites another under the shared default `"Wolfram"` key. |
| `Kernel/MCPServerObject.wl` | No dedicated change required. The current object model already exposes additional stored metadata keys like `"MCPServerName"` through its generic property handling. |

---

## DeployAgentTools

### Signature

```wl
DeployAgentTools[target]
DeployAgentTools[target, opts]
DeployAgentTools[target, server]
DeployAgentTools[target, server, opts]
```

### Arguments

| Argument | Type | Description |
|---|---|---|
| `target` | `String`, `File[...]`, or `{String, dir}` | The client to deploy to. A string client name (e.g. `"ClaudeDesktop"`), a direct config file path, or a `{name, dir}` pair for project-level installation. |
| `server` | `MCPServerObject`, `String`, or `Automatic` | The MCP server to deploy. Defaults to `Automatic`, which resolves to `$defaultMCPServer` (currently `"Wolfram"`). |

### Options

| Option | Default | Description |
|---|---|---|
| `OverwriteTarget` | `False` | If `True`, replace any existing deployment for the same target. If `False`, return a `Failure` when a deployment already exists. |
| `"ApplicationName"` | `Automatic` | Passed through to `InstallMCPServer`. |
| `"DevelopmentMode"` | `False` | Passed through to `InstallMCPServer`. |
| `"MCPServerName"` | `Automatic` | Passed through to `InstallMCPServer`. Override the config file key for the server entry. |
| `"EnableMCPApps"` | `True` | Passed through to `InstallMCPServer`. |
| `"ProcessEnvironment"` | `Automatic` | Passed through to `InstallMCPServer`. |
| `"ToolOptions"` | `<\|\|>` | Passed through to `InstallMCPServer`. |
| `"VerifyLLMKit"` | `True` | Passed through to `InstallMCPServer`. |

`OverwriteTarget` is an existing `System` symbol. All other options are passed through to `InstallMCPServer` using `FilterRules`.

### Behavior

1. Resolve `target` to the same concrete installation location that `InstallMCPServer` will use:
   - Apply alias resolution via `toInstallName` (e.g. `"Claude"` becomes `"ClaudeDesktop"`).
   - For `{name, dir}` pairs, resolve the name component and the concrete project config file path.
   - For `File[...]` targets, canonicalize to an absolute file path and infer the client name with the same logic used by `InstallMCPServer` where possible.
   - Derive a deployment grouping name: the canonical client name if known, otherwise the inferred client name, otherwise `"Unknown"`.
2. Check for an existing deployment matching this config file. Scan the `<ClientName>` (or `"Unknown"`) subdirectory under `$deploymentsPath` and compare each deployment's stored `"MCP"/"ConfigFile"` against the resolved config file path:
   - If a match exists and `OverwriteTarget` is `False`: issue message and return `Failure["DeploymentExists", ...]`.
   - If a match exists and `OverwriteTarget` is `True`: delete the existing deployment first (via `deleteDeployment`).
3. Call `InstallMCPServer[target, server, <filtered options>]`, passing through only `InstallMCPServer`-valid options.
4. On success, build a deployment record containing:
   - A new UUID
   - MCP component data (normalized target, resolved client name, server name, resolved config file, stored options)
   - Empty Skills and Hooks components
   - Metadata (timestamp, paclet version)
5. Write the deployment record to disk as `Deployment.wxf` in a UUID-named directory under `$deploymentsPath`.
6. Return an `AgentToolsDeployment[<|...|>]` object.

### Examples

```wl
(* Deploy to Claude Desktop with default server *)
dep = DeployAgentTools["ClaudeDesktop"]

(* Deploy a specific server to Cursor *)
dep = DeployAgentTools["Cursor", "WolframLanguage"]

(* Replace an existing deployment *)
dep = DeployAgentTools["ClaudeDesktop", OverwriteTarget -> True]

(* Deploy with options *)
dep = DeployAgentTools["ClaudeCode", "ToolOptions" -> <|"WolframAlpha" -> <|"Width" -> 600|>|>]

(* Project-level deployment *)
dep = DeployAgentTools[{"ClaudeCode", "/path/to/project"}]
```

---

## AgentToolsDeployment

### Data Model

An `AgentToolsDeployment` wraps an association with the following structure:

```wl
AgentToolsDeployment[ <|
    "UUID"           -> "a1b2c3d4-e5f6-...",
    "Version"        -> 1,
    "Timestamp"      -> DateObject[ ... ],
    "PacletVersion"  -> "1.8.0",
    "CreatedBy"      -> "DeployAgentTools",
    "Toolset"        -> "WolframLanguage",
    "MCP"            -> <|
        "ClientName" -> "ClaudeDesktop",
        "Target"     -> "ClaudeDesktop",
        "Server"     -> "WolframLanguage",
        "ConfigFile" -> File[ "..." ],
        "Options"    -> <| "DevelopmentMode" -> False, ... |>
    |>,
    "Skills"         -> <| |>,
    "Hooks"          -> <| |>,
    "Meta"           -> <| |>
|> ]
```

| Key | Description |
|---|---|
| `"UUID"` | A UUID string uniquely identifying this deployment. Generated by `CreateUUID[]`. |
| `"Version"` | Integer schema version (currently `1`). Enables future data migration. |
| `"Timestamp"` | `DateObject` recording when the deployment was created. |
| `"PacletVersion"` | Paclet version string at the time of deployment. |
| `"CreatedBy"` | Always `"DeployAgentTools"`. |
| `"Toolset"` | Toolset name string (e.g. `"WolframLanguage"`). The canonical top-level name for the deployed MCP server. |
| `"MCP"` | MCP server component data. |
| `"MCP"/"ClientName"` | The canonical or inferred client name used for grouping and filtering (e.g. `"ClaudeDesktop"`). Falls back to `"Unknown"` when no client can be inferred. |
| `"MCP"/"Target"` | The normalized user-facing target: a canonical client name string (e.g. `"ClaudeDesktop"`), a `{name, dir}` pair for project-level deployments (e.g. `{"ClaudeCode", "/path/to/project"}`), or `File[...]` for direct file targets. |
| `"MCP"/"Server"` | Legacy toolset name key. Retained for backward compatibility with deployments written before the `"Toolset"` rename; new deployments keep writing this alongside the top-level `"Toolset"`. |
| `"MCP"/"ConfigFile"` | `File[...]` pointing to the client's configuration file that was modified. This is the canonical identity used when checking for existing deployments. |
| `"MCP"/"Options"` | The `InstallMCPServer` options that were used, stored for use by `DeleteObject`. |
| `"Skills"` | Reserved for phase 2. Empty association in phase 1. |
| `"Hooks"` | Reserved for phase 2. Empty association in phase 1. |
| `"Meta"` | Reserved for user-defined metadata. Empty association initially. |

### Object Validation

Uses ``System`Private`HoldSetValid`` / ``System`Private`HoldNotValidQ``, following the same pattern as `MCPServerObject`. An `AgentToolsDeployment[data_Association]` auto-validates on first access by checking that `data` matches the expected schema.

### Property Access

```wl
dep["PropertyName"]
dep["MCP", "Options"]
```

| Property | Returns | Source |
|---|---|---|
| `"UUID"` | UUID string | `data["UUID"]` |
| `"ClientName"` | Canonical or inferred client name string | `data["MCP", "ClientName"]` |
| `"Target"` | Client name string or `File` | `data["MCP", "Target"]` |
| `"Toolset"` | Toolset name string | `data["Toolset"]`, falling back to legacy `data["MCP", "Server"]` |
| `"Server"` | Legacy toolset name (alias for `"Toolset"`, retained for backward compatibility) | `data["MCP", "Server"]` |
| `"ConfigFile"` | `File[...]` | `data["MCP", "ConfigFile"]` |
| `"Scope"` | `"Global"`, `File[...]`, or `Missing["Unknown"]` | Derived from `data["MCP", "Target"]` |
| `"Timestamp"` | `DateObject` | `data["Timestamp"]` |
| `"PacletVersion"` | Version string | `data["PacletVersion"]` |
| `"CreatedBy"` | `"DeployAgentTools"` | `data["CreatedBy"]` |
| `"MCP"` | MCP sub-association | `data["MCP"]` |
| `"Skills"` | Skills sub-association | `data["Skills"]` |
| `"Hooks"` | Hooks sub-association | `data["Hooks"]` |
| `"Meta"` | User-defined metadata | `data["Meta"]` |
| `"Data"` | Full internal association | `data` |
| `"Location"` | `File[...]` deployment directory | Derived from UUID |
| `"Properties"` | List of all property names | Static list |

### DeleteObject

```wl
DeleteObject[dep]
```

`AgentToolsDeployment` defines an UpValue for `DeleteObject`:

```wl
AgentToolsDeployment /: DeleteObject[dep_AgentToolsDeployment] := catchTop[
    deleteDeployment @ ensureDeploymentExists @ dep,
    AgentToolsDeployment
];
```

The `deleteDeployment` function:

1. Calls `UninstallMCPServer[dep["ConfigFile"], dep["Toolset"], <filtered options>]` using `FilterRules[dep["MCP", "Options"], Options[UninstallMCPServer]]` to pass only `UninstallMCPServer`-valid options (e.g. `"ApplicationName"`, `"MCPServerName"`). This is wrapped in `catchAlways` to tolerate cases where the config has already been manually modified or removed.
2. Deletes the deployment directory: `DeleteDirectory[deploymentDirectory[dep["UUID"]], DeleteContents -> True]`.
3. Returns `Null`.

### Formatting

`MakeBoxes` is defined via an UpValue using ``BoxForm`ArrangeSummaryBox``:

- **Summary rows**: ClientName, Toolset
- **Hidden rows**: Scope, ConfigFile, Tools

---

## DeployedAgentTools

### Signature

```wl
DeployedAgentTools[]                (* all deployments *)
DeployedAgentTools["ClaudeCode"]    (* filter by target client name *)
```

### Behavior

**No arguments** — returns a list of all `AgentToolsDeployment` objects:

1. Scan `$deploymentsPath` for client subdirectories (e.g. `ClaudeCode/`, `Cursor/`).
2. Within each, scan for UUID subdirectories containing `Deployment.wxf`.
3. Read each record and construct an `AgentToolsDeployment`.
4. Filter out any corrupted or invalid records.
5. Return a `List` of `AgentToolsDeployment` objects.

**With target string** — filters by client name:

1. Resolve the target string through `$aliasToCanonicalName` (e.g. `"Claude"` becomes `"ClaudeDesktop"`).
2. Scan only `$deploymentsPath/<ClientName>/` for UUID subdirectories.
3. Read and return the matching `AgentToolsDeployment` objects.

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

---

## Storage

### Location

Deployment records are stored under:

```
$UserBaseDirectory/ApplicationData/Wolfram/AgentTools/Deployments/<ClientName>/<uuid>/Deployment.wxf
```

The `<ClientName>` directory groups deployments by canonical client name (e.g. `"ClaudeCode"`, `"ClaudeDesktop"`, `"Cursor"`). For `{name, dir}` project-level targets, `<ClientName>` is the resolved canonical client name (e.g. `"ClaudeCode"`). Multiple project-level deployments for the same client (different directories) coexist under the same `<ClientName>` subdirectory. This makes `DeployedAgentTools["ClientName"]` efficient — it only needs to scan a single subdirectory rather than all deployments.

For `File[...]` targets, `<ClientName>` is the inferred client name when one can be determined from the path or file structure; otherwise the fallback directory name `"Unknown"` is used.

### Format

WXF (Wolfram Exchange Format), consistent with existing storage (`Installations.wxf`, `Metadata.wxf`).

### Indexing

No master index file. `DeployedAgentTools[]` scans all client subdirectories under `Deployments/`. `DeployedAgentTools["ClientName"]` scans only the matching `Deployments/<ClientName>/` subdirectory. This avoids index-vs-reality consistency issues while keeping filtered queries efficient.

### Data Versioning

The `"Version"` field in each deployment record enables future schema migration. When phase 2 adds new component types or changes the schema, a migration function can upgrade older records in place.

---

## Messages

The following messages should be added to `Kernel/Messages.wl`:

```wl
AgentTools::DeploymentExists      = "A deployment already exists for target `1`. Use OverwriteTarget -> True to replace it.";
AgentTools::DeploymentNotFound    = "No deployment found with UUID \"`1`\".";
AgentTools::InvalidDeploymentData = "Invalid deployment data: `1`.";
```

---

## Implementation Touchpoints

| File | Change |
|---|---|
| `Kernel/DefaultServers.wl` | Add `"MCPServerName" -> "Wolfram"` to all four built-in server definitions. |
| `Kernel/InstallMCPServer.wl` | Add `"MCPServerName" -> Automatic` option to both `InstallMCPServer` and `UninstallMCPServer`. Use the resolved MCPServerName as the config file key in `installMCPServer` and `uninstallMCPServer` (but not for JSON extraction from `data["mcpServers", name]`, which must still use `obj["Name"]`). Also clear stale built-in installation records when one built-in Wolfram variant overwrites another under the shared default `"Wolfram"` key. |
| `Kernel/DeployAgentTools.wl` | **New file.** All definitions for `DeployAgentTools`, `AgentToolsDeployment`, `DeployedAgentTools`, and internal helpers. Context: ``Wolfram`AgentTools`DeployAgentTools` ``. |
| `Kernel/Main.wl` | Add ``"Wolfram`AgentTools`DeployAgentTools`"`` to `$AgentToolsContexts`. |
| `Kernel/Files.wl` | Add `$deploymentsPath` definition (following the pattern of `$storagePath`, `$rootPath`, `$imagePath`). |
| `Kernel/CommonSymbols.wl` | Declare `$deploymentsPath` (following the pattern of other shared path variables). Also declare `toInstallName`, `installLocation`, `projectInstallLocation`, and `guessClientName` — these are currently private to `InstallMCPServer.wl` but `DeployAgentTools.wl` needs them to resolve targets to concrete config file paths before calling `InstallMCPServer` (for duplicate-checking in step 2). Internal helpers (`deleteDeployment`, `ensureDeploymentExists`, `agentToolsDeploymentQ`, `deploymentDirectory`) should remain private to the `DeployAgentTools` context. |
| `Kernel/Messages.wl` | Add new message definitions. |
| `PacletInfo.wl` | No changes — symbols already declared. |
| `Tests/InstallMCPServer.wlt` | Update existing built-in server install/uninstall expectations to reflect the shared default `"Wolfram"` config key and record-clearing behavior. |
| `Tests/UninstallMCPServer.wlt` | Add or update uninstall coverage for the shared built-in `"Wolfram"` config key. |
| `Tests/DeployAgentTools.wlt` | **New file.** Tests for deployment, listing, filtering, deletion, and error cases. |

---

## Phase 2 Outline

Phase 2 extends the deployment record to include additional component types. The `"Version"` field is incremented and migration logic handles upgrading phase 1 records.

### Skills Component

> **Superseded.** Agent skills are implemented as specified in [AgentToolsObject.md](AgentToolsObject.md): skills are copied into each client's native skills directory and reference counted across deployments, and deployment records use schema version 2. The outline below is kept for history.

```wl
"Skills" -> <|
    "Installed"  -> {"wolfram-language", "wolfram-notebooks"},
    "SkillsDir"  -> File["..."]
|>
```

- Copies selected skill directories to a per-deployment location.
- Registers skills with the target client (e.g. adds marketplace/plugin config for Claude Code).
- `DeleteObject` removes skill registrations and cleans up copied files.

### Hooks Component

```wl
"Hooks" -> <|
    "Installed" -> {<|"Name" -> "...", "Event" -> "...", "Command" -> "..."|>}
|>
```

- Installs git hooks or client-specific hooks that invoke Wolfram tools.
- `DeleteObject` removes installed hooks.

### LSP Component

```wl
"LSP" -> <|
    "Executable" -> File["..."],
    "Port"       -> Automatic
|>
```

- Configures a Wolfram Language Server for the target editor/client.
- `DeleteObject` removes LSP configuration.

Each component gets its own cleanup logic in `deleteDeployment`. Components are independent — a deployment can have any combination of MCP, Skills, Hooks, and LSP.

---

## Verification

### MCPServerName (InstallMCPServer change)

1. Install a built-in server (e.g. `"WolframLanguage"`); verify the config file key is `"Wolfram"`, not `"WolframLanguage"`.
2. Install a different built-in server to the same client; verify it overwrites the existing `"Wolfram"` entry rather than creating a second entry.
3. Install a user-created server (no `"MCPServerName"`); verify its `"Name"` is used as the config key (unchanged behavior).
4. Uninstall a built-in server by name; verify it removes the `"Wolfram"` key from the config file.
5. Install with `"MCPServerName" -> "CustomName"`; verify the config file key is `"CustomName"`.
6. Install two built-in servers with different `"MCPServerName"` overrides; verify both coexist in the config file.
7. Install `"Wolfram"` and then `"WolframLanguage"` with the default shared key; verify only the latter retains a recorded installation for that target.

### DeployAgentTools

1. Deploy to a supported client; verify an `AgentToolsDeployment` is returned with correct properties.
2. Verify the client's MCP config file was updated (consistent with `InstallMCPServer` behavior).
3. Verify `DeployedAgentTools[]` includes the new deployment.
4. Verify `DeployedAgentTools["ClientName"]` filters correctly, including alias resolution.
5. Verify `DeleteObject` removes the MCP config entry and the deployment directory.
6. Verify `OverwriteTarget -> False` returns a `Failure` when a deployment already exists for the target.
7. Verify `OverwriteTarget -> True` replaces the existing deployment.
8. Verify equivalent target forms that resolve to the same config file (e.g. canonical client name vs direct file path) are treated as the same deployment target.
9. Run `CodeInspector` on `Kernel/DeployAgentTools.wl`.
10. Run `Tests/DeployAgentTools.wlt`.
