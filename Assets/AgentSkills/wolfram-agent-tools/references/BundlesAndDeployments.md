# Bundles and Deployments

An `AgentToolsObject` is a named bundle of MCP servers and agent skills. `DeployAgentTools` deploys a bundle to a
client as one tracked `AgentToolsDeployment`: the servers go into the client's MCP configuration, the skills into
its skills directory, and `DeleteObject` on the deployment removes both again.

## Kinds of bundles

| Kind | How to get it |
| --- | --- |
| Built-in | `AgentToolsObject["WolframLanguage"]`; all of them: `$DefaultAgentTools` |
| Defined by a paclet | `AgentToolsObject["Publisher/Paclet/BundleName"]`, or `AgentToolsObject["Publisher/Paclet"]` if the paclet has only one (see `PacletDistribution.md`) |
| Ad hoc | `AgentToolsObject[<|...|>]`, made on the spot |

`AgentToolsObjects[]` lists the bundles of installed paclets. Add `"IncludeBuiltIn" -> True` or
`"IncludeRemotePaclets" -> True` (paclets in the Paclet Repository that are not installed) for more.

## Ad hoc bundles

```wl
bundle = AgentToolsObject[<|
    "Name"        -> "MyTools",
    "Description" -> "Text tools with a matching skill",
    "MCPServers"  -> {"TextTools"},                 (* names or MCPServerObjects *)
    "AgentSkills" -> {
        File["path/to/my-skill"],                   (* a skill directory *)
        "wolfram-language"                          (* a built-in skill *)
    }
|>];

bundle["MCPServerNames"]     (* {"TextTools"} *)
bundle["AgentSkillNames"]    (* {"my-skill", "wolfram-language"} *)
```

- `"MCPServers"` and `"AgentSkills"` are both optional (a bundle can hold only skills, or only servers). The ways
  to write a skill are in `AgentSkills.md`.
- The name may not contain `/` or be the name of a built-in bundle (`InvalidAgentToolsObject`).
- An ad hoc bundle exists only in your session. Nothing is saved until it is deployed, and the deployment record
  stores what was installed, not the bundle. To hand a bundle to other people, put it in a paclet.
- Other properties: `"MCPServers"` and `"AgentSkills"` (the objects), `"Tools"`, `"Description"`, `"Properties"`.

## Deploying

```wl
DeployAgentTools["ClaudeCode", bundle]                          (* user level *)
DeployAgentTools[{"ClaudeCode", "/path/to/project"}, bundle]    (* one project *)
DeployAgentTools["Cursor", "Publisher/Paclet"]                  (* a paclet's bundle; installs the paclet if needed *)
DeployAgentTools["ClaudeCode"]                                  (* the client's default built-in bundle *)
```

The second argument can be a bundle, an association (an ad hoc bundle), an `MCPServerObject` (a bundle with just
that server), or a name. A name is looked up as a user-created MCP server, then a built-in bundle, then a paclet
bundle, then a paclet MCP server.

| Target | MCP servers go to | Skills go to |
| --- | --- | --- |
| `"Client"` | the client's user-level MCP configuration | its user skills directory |
| `{"Client", dir}` | the project's MCP configuration | the project's skills directory |
| `File[config]` | that file | the matching skills directory if the file is a client's standard configuration file, otherwise nowhere |

Client names and directories are in `SetUpWolframMCPServer.md`.

| Option | Default | Meaning |
| --- | --- | --- |
| `OverwriteTarget` | `False` | `True` replaces a conflicting deployment and updates unmodified skills. `All` also overwrites skill directories that were edited or that belong to a different skill of the same name. Ask the user before using `All` |
| `"SkillsDirectory"` | `Automatic` | `File[dir]` installs the skills there; `None` deploys no skills |
| every `InstallMCPServer` option | | Passed on to the servers: see `ToolOptions.md`. A string for `"MCPServerName"` only works for a bundle with one server |

What to expect:

- **A target that supports only part of the bundle** gets that part, with a warning (`AgentSkillsNotDeployed`,
  `MCPServersNotDeployed`). Claude Desktop, LM Studio, and Amazon Q Developer have no skills directory, and several
  clients have no project-level MCP configuration. If nothing can be deployed, it fails.
- **`DeploymentExists`** means that the same bundle is already deployed to that client and location, or that
  another deployment uses the same MCP configuration key in the same file. Use `OverwriteTarget -> True` to replace
  it. The four built-in bundles all use the key `Wolfram`, so they replace each other. Different custom bundles
  deploy side by side.
- **A skill directory of the same name with different content** (`AgentSkillExists`, `AgentSkillModified`,
  `AgentSkillConflict`) fails the deployment. A built-in bundle instead skips that skill with an
  `AgentSkillNotInstalled` warning and deploys the rest.
- **A failed deployment changes nothing.** Whatever was already written is undone.
- **`DeployAgentTools[All, ...]`** deploys to every supported client and returns a list with a `Missing[...]` entry
  for each client that was skipped. Use it only when the user asks for it.

Ask the user to restart the client after deploying.

## Inspecting, updating, removing

```wl
DeployedAgentTools[]                 (* every deployment on this machine *)
DeployedAgentTools["ClaudeCode"]     (* for one client *)

(* dep is one of these, or the result of DeployAgentTools *)

dep["Toolset"]            (* the bundle (or server) name *)
dep["Scope"]              (* "Global", or File[projectDirectory] *)
dep["MCPServerNames"]     dep["ConfigFile"]
dep["AgentSkills"]        dep["SkillsDirectory"]
dep["Skills"]             (* what was installed, skipped, or left out because of a conflict *)
dep["Timestamp"]          dep["PacletVersion"]
dep["Properties"]

DeleteObject[dep]
```

- **To pick one deployment**, select on client, toolset, and scope. Without the scope test you would also match
  the same bundle in every project:

```wl
Select[DeployedAgentTools["ClaudeCode"], #["Toolset"] === "MyTools" && #["Scope"] === "Global" &]
```

- **To update** (a changed bundle, new options, a new paclet version), deploy again with `OverwriteTarget -> True`.
  Built-in skills are also brought up to date by any later deployment after the AgentTools paclet was updated.
- **`DeleteObject` removes only what the deployment owns.** A skill directory stays if another deployment still
  uses it (several clients share one skills directory, and several bundles may contain the same skill), if it was
  edited after it was installed, or if it already existed before the deployment. The message tells you which case
  applied. `UninstallAgentSkills` removes a leftover directory.
- Removal works from the stored record, so it still works after the paclet that defined the bundle was updated or
  uninstalled.
- Records are kept under `$UserBaseDirectory/ApplicationData/Wolfram/AgentTools/Deployments`. Changes made by hand
  or with `InstallMCPServer` and `InstallAgentSkills` are not tracked there.
