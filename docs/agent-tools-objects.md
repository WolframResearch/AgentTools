# Agent Tools Bundles and Agent Skills

This document describes `AgentToolsObject` (bundles of MCP servers and agent skills), how `DeployAgentTools` deploys them, and the low-level `InstallAgentSkills` / `UninstallAgentSkills` functions. The design specification is [Specs/AgentToolsObject.md](../Specs/AgentToolsObject.md).

## Overview

An **agent skill** is a directory in the open [Agent Skills](https://agentskills.io/specification) format: a `SKILL.md` file with YAML frontmatter (`name`, `description`, ...) and Markdown instructions, optionally with `scripts/`, `references/`, and `assets/`. In Wolfram Language a skill is an `LLMSkill` (defined by the LLMFunctions paclet).

An **`AgentToolsObject`** is a named bundle of MCP servers and agent skills. `DeployAgentTools` deploys a bundle to a client as one tracked deployment: it installs the MCP servers into the client's MCP configuration and copies the skills into the client's skills directory. `DeleteObject` on the deployment removes both.

| Symbol | Description |
|--------|-------------|
| `AgentToolsObject[name]` | A built-in or paclet-defined bundle |
| `AgentToolsObject[<\|...\|>]` | An ad hoc bundle |
| `AgentToolsObjects[]` | List bundles of installed paclets (options as for `MCPServerObjects`) |
| `$DefaultAgentTools` | The built-in bundles (each built-in MCP server with its built-in agent skills) |
| `InstallAgentSkills[target, skills]` | Copy skills into a client's skills directory (untracked) |
| `UninstallAgentSkills[target, names]` | Remove skills from a client's skills directory (untracked) |
| `$SupportedClients` | All supported clients; each entry includes its skill locations |

## AgentToolsObject

### Built-in bundles

`$DefaultAgentTools` has one bundle per built-in MCP server, with the same name. Each bundle also contains built-in agent skills, which ship with the paclet (its `"AgentSkills"` asset, built into `Assets/AgentSkills/`; see [agent-skills.md](agent-skills.md#built-in-skills)):

| Bundle | MCP server | Agent skills |
|--------|------------|--------------|
| `"Wolfram"` | `Wolfram` | wolfram-language, wolfram-alpha, wolfram-debugging |
| `"WolframAlpha"` | `WolframAlpha` | wolfram-alpha |
| `"WolframLanguage"` | `WolframLanguage` | wolfram-language, wolfram-notebooks, wolfram-paclets, wolfram-debugging |
| `"WolframPacletDevelopment"` | `WolframPacletDevelopment` | wolfram-language, wolfram-notebooks, wolfram-paclets, wolfram-debugging |

```wl
AgentToolsObject["WolframLanguage"]["MCPServerNames"]
(* {"WolframLanguage"} *)

AgentToolsObject["WolframLanguage"]["AgentSkillNames"]
(* {"wolfram-language", "wolfram-notebooks", "wolfram-paclets", "wolfram-debugging"} *)
```

The skills of a built-in bundle complement its MCP server, so `DeployAgentTools` treats them differently from the skills of other bundles:

- On a target without a skills directory (Claude Desktop, LM Studio, Amazon Q Developer, or a `File[...]` configuration that isn't a known client's), only the MCP server is installed, without an `AgentSkillsNotDeployed` warning. The record still lists the skills under `"Skipped"`.
- A conflicting skill directory (`AgentSkillExists`, `AgentSkillModified`, or `AgentSkillConflict`) does not fail the deployment. That skill is left untouched, everything else is deployed, `DeployAgentTools::AgentSkillNotInstalled` names the skill and its directory, and the record lists the skill under `"NotInstalled"`. If nothing else could be deployed (no MCP server for this target and no other skill to install), the conflict fails the deployment as for other bundles. Use `OverwriteTarget -> All` to replace such directories.
- Built-in skills are versioned by the AgentTools version, so unmodified copies installed by earlier deployments are updated without `OverwriteTarget` (see [OverwriteTarget](#overwritetarget)).

### Paclet bundles

Each `{"AgentTools", ...}` extension entry of a paclet that declares MCP servers or agent skills defines a bundle named `"PacletName/Name"` (the entry's `"Name"`, default `"AgentTools"`). See [paclet-extensions.md](paclet-extensions.md).

```wl
AgentToolsObject["PublisherID/MyPaclet/MyPaclet"]
AgentToolsObject["PublisherID/MyPaclet"]   (* the paclet's bundle, if it defines exactly one *)
AgentToolsObject["MyPaclet"]               (* the same for an installed paclet without a publisher prefix *)
AgentToolsObjects["IncludeBuiltIn" -> True]
```

### Ad hoc bundles

```wl
AgentToolsObject[<|
    "Name"        -> "MyTools",
    "MCPServers"  -> {"WolframLanguage"},
    "AgentSkills" -> {
        LLMSkill[{"my-skill", "What the skill does and when to use it."}, "Instructions..."],
        File["path/to/another-skill"]
    }
|>]
```

Ad hoc names may not contain `/` or equal a built-in bundle name.

### Skill specifications

| Form | Meaning |
|------|---------|
| `LLMSkill[...]` | If its `"Location"` is a skill directory, that directory is copied (including bundled files); otherwise a `SKILL.md` is generated from its fields |
| `File[dir]` | A skill directory |
| `"Publisher/Paclet/skill-name"` | A paclet-defined skill |
| `"skill-name"` | A built-in skill (`"wolfram-alpha"`, `"wolfram-debugging"`, `"wolfram-language"`, `"wolfram-notebooks"`, `"wolfram-paclets"`); other names fail with `AgentSkillNotFound` |

Skill names must be 1–64 lowercase letters, digits, and hyphens (no leading, trailing, or consecutive hyphens), and skills need a description of 1–1024 characters that are not all whitespace.

### Properties

| Property | Description |
|----------|-------------|
| `"Name"`, `"Location"`, `"Description"` | Basic data |
| `"MCPServers"` | The servers as `MCPServerObject`s (alias `"MCPServerObjects"`) |
| `"AgentSkills"` | The skills as `LLMSkill`s (aliases `"Skills"`, `"LLMSkills"`) |
| `"MCPServerNames"`, `"AgentSkillNames"` | Names only (qualified names for paclet servers and skills); no definitions are loaded |
| `"Tools"` | The tools of all servers |
| `"Data"` | The stored data, including the server and skill specifications as given |

As with `MCPServerObject`'s `"Tools"` and `"ToolNames"`, `"MCPServers"` and `"AgentSkills"` give objects, and `"MCPServerNames"` and `"AgentSkillNames"` give names:

```wl
AgentToolsObject["PublisherID/MyPaclet/MyPaclet"]["AgentSkillNames"]
(* {"PublisherID/MyPaclet/using-my-paclet", ...} *)

AgentToolsObject["PublisherID/MyPaclet/MyPaclet"]["AgentSkills"]
(* {LLMSkill[<|"Name" -> "using-my-paclet", ...|>], ...} *)
```

## DeployAgentTools

```wl
DeployAgentTools["ClaudeCode", "PublisherID/MyPaclet/MyPaclet"]
DeployAgentTools[{"ClaudeCode", "/path/to/project"}, AgentToolsObject[...]]
DeployAgentTools[All, "PublisherID/MyPaclet/MyPaclet"]
```

The toolset argument can be a bundle, a bundle or server name, an `MCPServerObject`, or an association (an ad hoc bundle). A name resolves to a user-created MCP server, then a built-in bundle, then a paclet bundle (a paclet's exact name refers to its only bundle), then a paclet MCP server (installing the paclet if necessary). Names are matched exactly; `*` is not a wildcard.

### What gets deployed

| Target | MCP servers | Agent skills |
|--------|-------------|--------------|
| `"Client"` | the client's MCP configuration | the client's skills directory |
| `{"Client", dir}` | the client's project MCP configuration | the client's project skills directory |
| `File[config]` | that file | the matching skills directory if the file is a client's global or project configuration file; otherwise none |

If the target supports only some components, the rest is deployed and a warning is issued (`AgentSkillsNotDeployed`, `MCPServersNotDeployed`; built-in bundles skip their skills without a warning); if nothing can be deployed, `DeployAgentTools` fails. Use the `"SkillsDirectory"` option to choose the skills directory explicitly (`File[dir]`) or to skip skills (`None`).

### Several deployments per client

Different bundles can be deployed to the same client side by side. A deployment conflicts with an existing one when both write the same MCP configuration key into the same file (the built-in bundles all use the key `"Wolfram"`, so they replace each other), or when the same bundle is deployed again to the same client and location. When one built-in bundle replaces another, the skills they share stay in place and the others are released.

### OverwriteTarget

| Value | Effect |
|-------|--------|
| `False` (default) | Fail with `DeploymentExists` on a conflicting deployment |
| `True` | Replace conflicting deployments; update skills from the same source that haven't been modified (e.g. after `PacletUpdate`). Built-in skills are updated this way even without `OverwriteTarget` |
| `All` | Also overwrite skill directories that were modified since they were installed, or that belong to a different skill with the same name |

### Shared skill directories

Several clients read the same directory (Copilot CLI and VS Code share `~/.copilot/skills`; Codex, Goose, and Zed share `~/.agents/skills`), and several bundles may contain the same skill. AgentTools keeps a registry of the skill directories it installed, with the deployments that reference each one and the hashes of the files it wrote:

- A skill that is already installed with identical content gets another reference instead of a second copy.
- `DeleteObject` on a deployment removes its reference. The directory is deleted only when no other deployment uses it (otherwise `AgentSkillInUse` is reported), and only if it was not modified after it was installed (otherwise `AgentSkillNotRemoved` tells you how to remove it with `UninstallAgentSkills`). If deleting it fails (e.g. permissions), `AgentSkillRemoveFailed` is reported and a later deployment operation tries again.
- A skill directory that existed before the deployment (installed by hand, by another tool, or committed to a project's repository) is never deleted by `DeleteObject`.
- Line-ending changes don't count as modifications; a `.git` directory inside a skill directory, or a file that can't be read, does.
- If a skills directory is later reached through a symbolic link (e.g. `~/.agents` moved into a dotfiles repository and linked back), AgentTools still recognizes the skill directories it installed there.

### Skill locations

See [mcp-clients.md](mcp-clients.md) for the skills directory of each client. Skills go to each client's own directory; the shared `~/.agents/skills` is used only for clients whose primary location it is. Claude Desktop (its Chat and Cowork tabs only see skills uploaded to claude.ai), LM Studio, and Amazon Q Developer have no skills directory; deploying a built-in bundle to them installs only its MCP server.

## InstallAgentSkills / UninstallAgentSkills

These low-level functions copy and remove skills without any tracking; you are responsible for what they change.

```wl
InstallAgentSkills["ClaudeCode", LLMSkill[...]]
InstallAgentSkills[{"Cursor", "/path/to/project"}, {File["skill-a"], File["skill-b"]}]
InstallAgentSkills[File["/custom/skills"], "PublisherID/MyPaclet/my-skill", OverwriteTarget -> True]

UninstallAgentSkills["ClaudeCode", "my-skill"]
```

- `InstallAgentSkills` fails with `AgentSkillExists` if a different skill with the same name exists, unless `OverwriteTarget -> True`. Identical content is a no-op.
- `UninstallAgentSkills` removes the named skill directories even if they were modified. It never removes anything but a skill directory directly inside the skills directory.

## Deployment Records

Deployment records (schema version 2) store everything needed to remove a deployment later: the config keys and files of the MCP servers and the installed skill directories with their registry keys. Removal never resolves servers or bundles by name again, so it works after the paclet was updated or uninstalled. Records written by earlier versions (schema version 1) are still listed, conflict-checked, and removable. See [deploy-agent-tools.md](deploy-agent-tools.md).

## Related Files

- `Kernel/AgentToolsObject.wl` — `AgentToolsObject`, `AgentToolsObjects`, `$DefaultAgentTools`
- `Kernel/AgentSkills.wl` — skill sources, the built-in skills (`$defaultAgentSkills`), `InstallAgentSkills`, `UninstallAgentSkills`, the skill registry
- `Assets/AgentSkills/` — the built-in skills (built by `Scripts/BuildAgentSkills.wls`; see [agent-skills.md](agent-skills.md))
- `Kernel/DeployAgentTools.wl` — deployments
- `Kernel/SupportedClients.wl` — client skill locations
- `Kernel/PacletExtension.wl` — paclet bundles and skills
- `Tests/AgentToolsObject.wlt`, `Tests/AgentSkills.wlt`, `Tests/DeployAgentToolsSkills.wlt`, `Tests/AgentSkillsBuild.wlt`
