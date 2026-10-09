# Agent Tools Bundles and Agent Skills — Design Specification

## Overview

AgentTools can discover and deploy MCP servers. This spec adds **agent skills** (``System`LLMSkill``, defined by the LLMFunctions paclet, following the [Agent Skills](https://agentskills.io/specification) format) as a second deployable component, and introduces `AgentToolsObject`: a named bundle of MCP servers and agent skills that `DeployAgentTools` deploys as one tracked, reversible unit.

New exported symbols (all in ``Wolfram`AgentTools` ``):

| Symbol | Description |
|---|---|
| `AgentToolsObject` | A bundle of MCP servers and agent skills (built-in, paclet-defined, or ad hoc) |
| `AgentToolsObjects` | List available bundles (like `MCPServerObjects`) |
| `$DefaultAgentTools` | The built-in bundles (like `$DefaultMCPServers`) |
| `InstallAgentSkills` | Low-level: copy skills into a client's skills directory |
| `UninstallAgentSkills` | Low-level: remove skills from a client's skills directory |
| `$SupportedClients` | All supported clients (MCP and/or skills). `$SupportedMCPClients` remains for backward compatibility |

Changed: `DeployAgentTools`, `AgentToolsDeployment` / `DeleteObject`, `DeployedAgentTools`, the paclet extension system (`"AgentSkills"`, multiple `{"AgentTools", ...}` entries, implicit bundles), `ValidateAgentToolsPacletExtension`, and the client registry in `Kernel/SupportedClients.wl`.

This spec supersedes the "Phase 2 Outline → Skills Component" section of [DeployAgentTools.md](DeployAgentTools.md) (which proposed per-deployment copies plus Claude Code plugin registration). Skills are instead copied directly into each client's native skills directory, with reference counting for directories shared by several clients or deployments.

---

## Goals

- Deploy MCP servers and agent skills together with `DeployAgentTools`, and remove them together with `DeleteObject`.
- Let paclets contribute skills and declare one or more bundles through their `"AgentTools"` extension.
- Never delete or overwrite files that AgentTools did not create, unless the user explicitly forces it.
- Share skill directories safely: several clients (e.g. VS Code and Copilot CLI both read `~/.copilot/skills`) and several deployments (two bundles containing the same skill) may reference one installed skill.
- Keep existing callers working: the preferences UI, existing deployment records (schema v1), older AgentTools versions reading new records, `$SupportedMCPClients`, single-extension paclets.

## Non-Goals (this pass)

- Persisted user-defined bundles (no `CreateAgentTools`). Ad hoc `AgentToolsObject[<|...|>]` values can be deployed.
- Preferences UI changes. The UI keeps working: the built-in bundles it deploys now carry skills, which are installed with the server where the client supports skills (only the server, without a warning, where it doesn't, and conflicting skill directories are left alone; see [Built-in skills](#built-in-skills)), records keep the fields the UI reads, and `OverwriteTarget -> True` never clobbers modified or foreign skill files. (Known limitation: the UI identifies Wolfram deployments by toolset name, so an ad hoc bundle that contains a built-in server is not shown as "configured".)
- Reference documentation notebooks for the new symbols.
- Honoring client environment-variable overrides (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `COPILOT_HOME`, `XDG_CONFIG_HOME`, `KIRO_HOME`, ...). Locations are home-relative for both MCP and skills, consistent with existing MCP behavior. The override mechanisms are `File[...]` / `{client, dir}` targets and the `"SkillsDirectory"` option of `DeployAgentTools`.
- Refreshing other copies of a skill (e.g. in other clients' directories) when one client's copy is upgraded. Redeploying to every client refreshes every copy.
- Uploading skills to claude.ai (Claude Desktop Chat/Cowork tabs only see account-uploaded skills).

---

## Client Skill Locations

### Registry changes (`Kernel/SupportedClients.wl`)

- The internal registry `$supportedMCPClients` is renamed to `$supportedClients` (done in the scaffolding, including `Kernel/CommonSymbols.wl`).
- `$SupportedClients` is the exported, self-caching, protected association of client metadata (the current `$SupportedMCPClients` definition, renamed).
- `$SupportedMCPClients := Select[ $SupportedClients, KeyExistsQ[ #, "InstallLocation" ] & ]` — the clients with an MCP `"InstallLocation"`. Today this is every client, so the value is unchanged. It is a delayed definition (not cached).
- Internal code that enumerates clients reads `$SupportedClients` (filtering by capability where needed): `DetectedMCPClients`, `guessClientName`, `deployAllAgentTools`. Tests that pin the client list `Block` `$SupportedClients` (existing `Block`s of `$SupportedMCPClients` in `Tests/DeployAgentTools.wlt` are updated).
- `"InstallLocation"` becomes optional in principle (a future skills-only client); `installLocation` fails with `UnsupportedMCPClient` instead of an internal failure when it is missing.
- New per-client keys:
  - `"SkillsLocation"`: same format as `"InstallLocation"` (a path-component list, a per-`$OperatingSystem` association, or a `RuleDelayed`), naming the **user-scope skills root directory** (the directory that contains skill folders).
  - `"SkillsProjectPath"`: path components relative to a project directory (like `"ProjectPath"`), naming the project-scope skills root.
- New derived keys in `clientMetadata`: `"SkillsSupport"` (`True` iff `"SkillsLocation"` is present) and `"SkillsProjectSupport"` (`True` iff `"SkillsProjectPath"` matches `{__String}`). `"ProjectSupport"` keeps its MCP-only meaning.

### Location policy

Skills go to each client's **native** skills directory. The shared `~/.agents/skills` / `.agents/skills` is used only where it is the client's primary (or only) location. Rationale: precise targeting (deploying to one client does not expose skills to every client that reads the shared directory), and the shared directory is ignored by several clients (Claude Code, Continue, Kiro, Antigravity's user scope), ranked lowest by others, or disabled by settings/env vars.

| Client | `"SkillsLocation"` | `"SkillsProjectPath"` | Notes |
|---|---|---|---|
| ClaudeCode | `~/.claude/skills` | `.claude/skills` | Does not read `.agents/skills`. |
| ClaudeDesktop | — | — | Chat/Cowork use skills uploaded to the claude.ai account; only the Code tab reads `~/.claude/skills` (covered by ClaudeCode). |
| Cursor | `~/.cursor/skills` | `.cursor/skills` | Also reads `.agents`, `.claude`, `.codex` skills. |
| GeminiCLI | `~/.gemini/skills` | `.gemini/skills` | `.agents/skills` (v0.28+) wins within a tier. |
| Antigravity | `antigravitySkillsLocation[]` | `.agents/skills` | `~/.gemini/config/skills` when `~/.gemini/config/.migrated` exists, else legacy `~/.gemini/antigravity/skills` (creating `~/.gemini/config/skills` before migration would strand legacy skills). |
| Goose | `~/.agents/skills` | `.agents/skills` | Canonical location. |
| Codex | `~/.agents/skills` | `.agents/skills` | Primary; `~/.codex/skills` is deprecated. |
| CopilotCLI | `~/.copilot/skills` | `.github/skills` | Shares both with VisualStudioCode. |
| VisualStudioCode | `~/.copilot/skills` | `.github/skills` | |
| AugmentCode | `~/.augment/skills` | `.augment/skills` | Shares both with AugmentCodeIDE. |
| AugmentCodeIDE | `~/.augment/skills` | `.augment/skills` | Skills are a beta feature in the extension. |
| Cline | `~/.cline/skills` | `.cline/skills` | Documented locations (code also reads `.agents/skills`). |
| Continue | `~/.continue/skills` | `.continue/skills` | |
| Junie | `~/.junie/skills` | `.junie/skills` | |
| KimiCode | `~/.kimi/skills` | `.kimi/skills` | |
| Kiro | `~/.kiro/skills` | `.kiro/skills` | |
| LMStudio | — | — | No skills support. |
| OpenCode | `~/.config/opencode/skills` | `.opencode/skills` | Same path on Windows (`%USERPROFILE%\.config\opencode\skills`). |
| QwenCode | `~/.qwen/skills` | `.qwen/skills` | |
| Windsurf | `~/.codeium/windsurf/skills` | `.windsurf/skills` | |
| AmazonQ | — | — | The legacy Q Developer CLI has no skills (its successor, Kiro CLI, uses `~/.kiro/skills` — use the Kiro client). |
| Zed | `~/.agents/skills` | `.agents/skills` | Only location. |

All user-scope paths are relative to `$HomeDirectory` on every OS (written as `"SkillsLocation" :> { $HomeDirectory, ".claude", "skills" }`), so tests isolate them by `Block`ing `$HomeDirectory`.

### Location helpers (`Kernel/InstallMCPServer.wl`, shared via `CommonSymbols.wl`)

- `skillsLocation[ name ]` / `skillsLocation[ name, os ]` → `File[root]`. Mirrors `installLocation`: resolves aliases, fails with `UnsupportedSkillsClient` when the client has no `"SkillsLocation"`, `UnknownSkillsLocation` when it has none for `os`.
- `projectSkillsLocation[ name, dir ]` → `File[dir/<SkillsProjectPath>]`; fails with `UnsupportedSkillsClientProject` when the client has no `"SkillsProjectPath"` and `InvalidProjectDirectory` for a bad `dir`.

---

## Agent Skills

### Skill specifications

Wherever a skill is accepted (`InstallAgentSkills`, an `AgentToolsObject`'s `"AgentSkills"`), it may be given as:

| Form | Meaning |
|---|---|
| `LLMSkill[...]` | An `LLMSkill` object. If its `"Location"` is an existing directory containing `SKILL.md`, that directory is the source (all bundled files are copied). Otherwise a `SKILL.md` is generated from its fields. |
| `File[dir]` | A skill directory in Agent Skills format (contains `SKILL.md`). Parsed with `LLMSkill[File[dir]]` for its name and description. |
| `"Publisher/Paclet/skill-name"`, `"Paclet/skill-name"` | A paclet-defined skill (see [Paclet Extension](#paclet-extension)). |
| `"skill-name"` | A built-in skill (internal registry `$defaultAgentSkills`: `wolfram-alpha`, `wolfram-debugging`, `wolfram-language`, `wolfram-notebooks`, `wolfram-paclets`; see [Built-in skills](#built-in-skills)). Other names → `AgentSkillNotFound`. |

AgentTools never calls ``LLMSkillQ`` or other LLMFunctions internals; it reads an `LLMSkill`'s data association directly (`HoldPattern[LLMSkill][as_Association]`), which also works for deserialized skills. To *create* `LLMSkill`s it uses only the public constructors `LLMSkill[File[dir]]` and `LLMSkill[{name, description}, body]` (the association constructor requires LLMFunctions internals).

### Normalized skill source (internal)

All forms normalize (`toAgentSkillSource[ spec ]`, or `toAgentSkillSource[ spec, defaultIdentifier ]`) to:

```wl
<|
    "Name"        -> "using-my-paclet",          (* validated skill name; the installed directory name *)
    "Description" -> "...",                      (* validated description *)
    "Identifier"  -> "Pub/MyPaclet/using-my-paclet" | "File:/canonical/source/dir" | "AgentToolsObject:MyBundle/using-my-paclet" | None,
    "Version"     -> "1.2.0" | Missing[ ],        (* paclet version for paclet skills; AgentTools version for built-in skills *)
    "Files"       -> <| "SKILL.md" -> source, "scripts/run.wls" -> source, ... |>,  (* KeySort'ed *)
    "Manifest"    -> <| "SKILL.md" -> "ab12...", ... |>                              (* see Hashing *)
|>
```

- `"Files"` maps relative paths (always `/`-separated) to either `File[absoluteSourcePath]` or a `String` (generated UTF-8 content).
- `"Identifier"` is the source identity used for upgrade decisions:
  - paclet skills: the qualified name; built-in skills: the skill name (e.g. `"wolfram-language"`);
  - directory sources (`File[dir]`, and any `LLMSkill` whose `"Location"` is used): `"File:" <> canonicalPath[ dir ]`;
  - in-memory `LLMSkill`s: the `defaultIdentifier` given by the caller — `DeployAgentTools` passes `"<ToolsetType>:<toolset name>/<skill name>"`, so redeploying an edited in-memory skill of the same bundle is an upgrade of the same source; `InstallAgentSkills` passes `None` (it keeps no registry).
- Directory sources are listed recursively, skipping ignored entries (see [Hashing](#hashing)). Symbolic links inside a skill are followed when copying.

### Skill names and descriptions

Names must satisfy the Agent Skills rules: 1–64 characters, lowercase ASCII letters, digits, and hyphens, no leading/trailing hyphen, no `--` (`^[a-z0-9]+(-[a-z0-9]+)*$`). Invalid names fail with `InvalidAgentSkillName` at install time **and** are rejected by `UninstallAgentSkills` before any path is built (so `""`, `".."`, or `"a/b"` can never resolve to the skills root or outside it). For paclet skills the declared name must equal the skill's name (`InvalidPacletSkillDefinition` otherwise).

Descriptions must be strings of at most 1024 characters that are not empty or all whitespace (`InvalidAgentSkillDescription`); clients skip skills without a description, so installing one would silently do nothing.

### Generated `SKILL.md`

For an `LLMSkill` (or association definition) without a usable `"Location"`, the file is generated deterministically (byte-identical for identical input, so redeploys don't look like modifications):

```
---
name: <Name>
description: <Description>
license: <License>              (only if present)
compatibility: <Compatibility>  (only if present)
allowed-tools: <AllowedTools>   (only if present; also taken from AdditionalFrontmatter["allowed-tools"])
metadata:                       (only if present; values converted to strings)
  key: value
<other AdditionalFrontmatter keys, in their original order>
---

<Body>
```

The frontmatter is produced with `exportYAMLString`; line endings are `\n`; the file ends with exactly one newline; content is written as UTF-8 bytes. Frontmatter (including `allowed-tools`) is passed through as given: installing a paclet is already the trust boundary (its MCP server code runs with the user's privileges).

### Hashing

A **manifest** is a `KeySort`ed association `<| relativePath -> sha256Hex, ... |>` (keys `/`-separated). The hash of a file is SHA-256 of its bytes after normalizing line endings (`\r\n` → `\n`) for files that contain no NUL byte, so a checkout with CRLF line endings (git `core.autocrlf`) is still recognized as identical. For a `String` source it is the same hash of its UTF-8 bytes.

Entry kinds inside a skill directory:

- **Junk** (`.DS_Store`, `Thumbs.db`, `desktop.ini` files; `__pycache__` directories): never copied, never hashed, never counted as modifications; deleted along with the skill.
- **Version-control metadata** (`.git`, `.hg`, `.svn`, file or directory): never copied from a source and never hashed. If present in an *installed* directory, the directory counts as `"Modified"`, so it is never deleted or replaced without `OverwriteTarget -> All` (a user's repository inside a skill directory is never lost).

Comparing an installed directory against a baseline manifest gives one of:

- `"Missing"` — nothing exists at the path.
- `"Unmodified"` — every baseline file exists with the same hash, there are no other non-junk files, and no version-control metadata.
- `"Modified"` — anything else.

### Inspecting a destination

`root/name` is classified (`skillDirectoryState`) as:

| State | Detection |
|---|---|
| `"Missing"` | not listed by `FileNames[ All, root ]` |
| `"Dangling"` | listed, but `FileType` is `None` (a dangling symbolic link) |
| `"File"` | `FileType` is `File` |
| `"Link"` | a directory whose resolved path differs from the resolved root joined with `name` (`AbsoluteFileName[ root/name ] =!= FileNameJoin[ { AbsoluteFileName[ root ], name } ]`) |
| `"Directory"` | a regular directory |

### Writing and replacing a skill directory

- **Create**: create `root/name` and write every entry of `"Files"` (copying `File` sources, writing `String` sources as UTF-8 bytes).
- **Replace** (overwrite or upgrade): first move the existing entry out of the root with `RenameDirectory`/`RenameFile` to a backup path in the root's parent directory (`<parent>/.agenttools-backup-<uuid>`, same volume), then create; on success delete the backup; on failure delete the partial directory and move the backup back. A `"Link"`/`"Dangling"`/`"File"` entry is removed as itself (`DeleteDirectory` on a link removes only the link), never written through.
- **Remove**: move the directory to a backup path as above, then delete it. If the move fails (e.g. a file in use on Windows), nothing is deleted and the operation reports failure.
- On Unix-like systems, a copied file that is executable in the source or starts with `#!` is made executable (`chmod +x`), because `.paclet` archives drop file modes. Modes are not part of the hashes.
- If the source directory is the destination (same canonical path), the skill is already installed: nothing is written. A source inside the destination or vice versa fails with `InvalidAgentSkill`.

### Low-level `InstallAgentSkills`

```wl
InstallAgentSkills[ target, skills, opts ]
```

| Argument | Values |
|---|---|
| `target` | `"ClientName"` (user scope, `skillsLocation`), `{ "ClientName", dir }` (project scope, `projectSkillsLocation`), or `File[ skillsRoot ]` (a directory that contains skill folders; fails with `InvalidSkillsDirectory` if it is itself a skill directory, i.e. contains `SKILL.md`) |
| `skills` | A skill specification, a list of them, or an `AgentToolsObject` (its skills) |

| Option | Default | Description |
|---|---|---|
| `OverwriteTarget` | `False` | `True` (or `All`) replaces an existing entry of the same name. `False` fails with `AgentSkillExists` if an entry exists with different content. Identical content is a no-op success for every value. |

Behavior:
1. Resolve the target root and every skill source (`None` identifiers); validate names and descriptions; detect duplicate names in the request (`DuplicateAgentSkillName`).
2. Preflight: classify every destination before writing anything; with `OverwriteTarget -> False`, any existing entry whose manifest differs from the source fails the whole call.
3. Write each skill (create or replace, as above). If a later skill fails, the skills already written by this call are rolled back.
4. Return `Success[ "InstallAgentSkills", <| "MessageTemplate" :> AgentTools::InstallAgentSkillNamed, "MessageParameters" -> { name, clientDisplayName }, "Name" -> name, "Location" -> File[ dir ], "ClientName" -> client | None |> ]` per skill (the `InstallAgentSkill` template without a client name) — a single `Success` for a single skill specification, a list for a list or bundle.

The low-level functions keep **no** references or hashes; the user is responsible. They do not modify the skill registry. (A deployment that references a skill dir later overwritten by `InstallAgentSkills` will see it as `"Modified"` and keep it; a dir removed by `UninstallAgentSkills` is seen as `"Missing"` and its reference is dropped silently.)

### Low-level `UninstallAgentSkills`

```wl
UninstallAgentSkills[ target, names ]
```

`target` as for `InstallAgentSkills`. `names` is a skill name, a list of names, or anything that has a name (an `LLMSkill`, a `File[skillDir]`, a qualified paclet skill name — its item name is used, an `AgentToolsObject` — its skills). There is no target-less or "all skills" form: skills roots are shared with skills from other sources.

For each name (validated first), removes `root/name` **only if** it is a direct child of the resolved root that is a directory containing `SKILL.md` (or a link to one), regardless of modifications. A `"Link"` entry is removed as a link only (its target is untouched). Returns `Success[ "UninstallAgentSkills", <| "MessageTemplate" :> AgentTools::UninstallAgentSkillNamed, ..., "Name" -> name, "Location" -> File[ dir ] |> ]` per skill, or `Missing[ "NotInstalled", File[ dir ] ]` when absent (mirroring `uninstallMCPServer`). The root itself is never deleted.

---

## Skill Registry (reference counting for deployments)

### Storage and keys

Deployments track the skill directories they install in a registry, one WXF file per installed skill directory:

```
$deploymentsPath/.SkillRegistry/<registry key>.wxf
```

- `canonicalPath[ path ]`: `AbsoluteFileName` of the deepest existing ancestor of `path` (resolving symbolic links), joined with the remaining path components. `canonicalPathKey[ path ]` is its comparison form: `/`-separated and case-folded (`ToLowerCase`) on Windows and macOS. Used for registry keys, `"File:"` identifiers, and all path comparisons in conflict detection.
- The registry key is `Hash[ canonicalPath[ root ] <> "/" <> name, "SHA256", "HexString" ]`, computed **before** anything is created, and stored in the deployment record (`"Skills"/"Installed"/"RegistryKey"`). Release always uses the recorded key, never a recomputed one.
- The registry and the lock file live under `$deploymentsPath` (dot-prefixed, so deployment scans skip them; older AgentTools versions find no records in them), so `Block`ing `$deploymentsPath` (as existing tests do) or `$rootPath` (`withTemporaryRoot`) isolates deployments, registry, and lock together. Stale-reference pruning must never see a real registry next to a redirected `$deploymentsPath`.

Each entry:

```wl
<|
    "RegistryKey" -> "...",
    "Directory"   -> File[ skillDir ],         (* as installed (not case-folded) *)
    "Name"        -> "using-my-paclet",
    "Identifier"  -> "Pub/MyPaclet/using-my-paclet" | "File:..." | "AgentToolsObject:..." | None,
    "Version"     -> "1.2.0" | Missing[ ],
    "Hashes"      -> <| "SKILL.md" -> "ab12...", ... |>,   (* baseline: what AgentTools last wrote *)
    "External"    -> False,      (* True: the directory existed before any deployment referenced it; never deleted *)
    "References"  -> { uuid1, uuid2, ... },
    "Timestamp"   -> DateObject[ ... ]
|>
```

### Stale references and garbage collection

A reference is **stale** if `$deploymentsPath` has no directory for its UUID, or the directory has no `Deployment.wxf` (a crashed write). An existing record that fails to parse is *not* stale. Stale references are pruned only under the deployment lock, at three points:

1. **Sweep** at the start of every locked deploy/delete: every registry entry is pruned; an entry left with no references (e.g. its deployments were removed by an older AgentTools version, or a deploy crashed) goes through the [release decision](#release-decision-deployment-removal) step 4.
2. **Preflight**, when computing an entry's live references.
3. **Release**.

### Install decision (deployment)

For incoming source `S` (manifest `Min`), destination `D = root/name`, registry entry `E` (if any), and `live = E.References` minus stale references **minus the UUIDs of the deployments this call replaces**. "Force" means `OverwriteTarget -> All`. "Upgrade level" means `OverwriteTarget -> True | All`.

| State of `D` | Condition | Action |
|---|---|---|
| `"Missing"` | — | Create `S`. `E.Hashes = Min`, `External -> False`, `References = kept ∪ {uuid}`. |
| `"Dangling"` or `"File"` | — | Conflict `AgentSkillExists`. Force: remove the entry, create `S`, `External -> False`. |
| `"Link"` | — | Conflict `AgentSkillExists`. Force: remove the link (not its target), create `S`; keep `E.References` if `E` exists; `External -> False`. |
| `"Directory"`, `E` exists, not external, disk `"Unmodified"` vs `E.Hashes` | `Min == E.Hashes` | Add reference. |
| 〃 | `live` is empty (only replaced deployments used it) | **Owned by the replacement**: replace with `S`; set `Hashes`, `Identifier`, `Version`. No force needed. |
| 〃 | same string `Identifier`, `S.Version` older than `E.Version` (both known) | Keep the newer installed copy; add reference; record the installed version; issue `AgentSkillNewerVersionKept`. |
| 〃 | same string `Identifier` otherwise | **Upgrade**: requires upgrade level (not needed for built-in skills, which only change with the paclet), else conflict `AgentSkillUpdate`. Replace with `S`, update `Hashes`/`Version`, add reference. All referencing deployments now share the new version. |
| 〃 | different or unknown `Identifier` | Conflict `AgentSkillConflict`. Force: replace, `E.Identifier = S.Identifier`, add reference. |
| `"Directory"`, `E` exists, not external, disk `"Modified"` | disk manifest `== Min` | Adopt the change as baseline (`Hashes = Min`), add reference. |
| 〃 | otherwise | Conflict `AgentSkillModified`. Force: replace, add reference. |
| `"Directory"`, `E.External` | disk manifest `== Min` | Add reference (stays external). |
| 〃 | otherwise | Conflict `AgentSkillExists`. Force: replace, `External -> False`, add reference. |
| `"Directory"`, no `E` (foreign: installed by the user, another tool, or `InstallAgentSkills`) | disk manifest `== Min` | Create `E` with `External -> True` and add reference. External directories are never deleted by deployment cleanup. |
| 〃 | otherwise | Conflict `AgentSkillExists`. Force: replace, create `E` with `External -> False`. |

`kept` is `E.References` without stale references; it still includes the replaced deployments, whose references are released in step 8 of the [algorithm](#algorithm) after the new record exists (so a crash in between never leaves a skill referenced only by a deployment that has no record). `live` (which excludes them) is only used to choose the action; every "add reference" writes `kept ∪ {uuid}`.

When the source directory **is** the destination (`"Same"`, e.g. a bundle that names an installed skill directory), nothing is written: with no `E` the directory is adopted as external; an existing `E` just gets the reference, keeping `E.Hashes` (a user's edits are never adopted as a removable baseline, because the source is the only copy).

Registry entries are found by key and, failing that, by skill directory (the skills root resolved through symbolic links, plus the skill name), so a skills root that later goes through a symbolic link keeps one shared entry, while a per-skill link (`~/.claude/skills/foo` → `~/.agents/skills/foo`) is a different skill directory with its own entry. A `"Same"` source reached through such a per-skill link joins the entry recorded at the physical directory, if there is one. Release never deletes a directory that another entry for the same physical directory (resolving all links) still references or marks as external; if only external entries still use it, the owning entry is kept without references, and the sweep at the end of `DeleteObject` (or of a later operation) releases it once they are gone.

Unreadable files: in an installed directory they make it `"Modified"`; in a skill source they fail with `AgentSkillUnreadable`.

Version comparison uses numeric dotted-version order. All decisions for all skills of a deployment are computed before anything is written (preflight). Any unforced conflict fails the whole deployment with the conflict message(s); nothing is changed. Built-in bundles are the exception: a conflicting skill is left out instead (see [Built-in skills](#built-in-skills)).

### Release decision (deployment removal)

For each skill recorded by the deployment being removed (by recorded registry key):

1. Load `E` (if there is none, leave the directory alone).
2. Remove the deployment's UUID from `E.References` and prune stale references.
3. If references remain: keep the files, write `E`, and report the skill as still in use (`AgentSkillInUse`, informational; one message per skill per `DeleteObject` call).
4. Otherwise, depending on the directory state:
   - `E.External` → keep the files; delete `E`.
   - `"Missing"` → delete `E`.
   - `"Link"` → keep it; delete `E`; issue `AgentSkillNotRemoved`. `"Dangling"`, `"File"` → keep it; delete `E`; issue `AgentSkillReplacedNotRemoved` (there is no skill directory for `UninstallAgentSkills` to remove).
   - `"Unmodified"` → remove the directory (junk files go with it); delete `E` only after the directory is gone. If removal fails, keep `E` with `References -> {}` (the next sweep retries) and issue `AgentSkillRemoveFailed`.
   - `"Modified"` → keep it; delete `E`; issue `AgentSkillNotRemoved`, which tells the user to evaluate ``UninstallAgentSkills[ File[ root ], "name" ]`` to force removal.

### Concurrency

`DeployAgentTools` and `DeleteObject[ AgentToolsDeployment[...] ]` (and the sweep, which skips entries it can't process) modify deployments, client config files, skill directories, and the registry only inside `withDeploymentLock[ eval ]`:

- `WithLock[ File[ $deploymentLockFile ], eval, TimeConstraint -> 60, PersistenceTime -> 1800 ]` (`$deploymentLockFile` is `$deploymentsPath/.lock`). A `$TimedOut` result (or any non-result) fails with `DeploymentLockTimeout`; `WithLock::unlock` is quieted.
- `WithLock` is not re-entrant, so a `Block`ed flag (`$deploymentLockHeld`) makes nested calls in the same kernel run `eval` directly.
- Everything slow happens **before** the lock is taken: resolving the toolset, installing paclets, loading definitions, building and hashing skill sources, and the MCP preflight (LLMKit check, tool initialization, paclet definition validation). The locked section only reads records and the registry, runs the sweep, conflict detection, and skill preflight, applies changes, and writes records. `DeployAgentTools[All]` takes the lock once per client.

### Project scope

Project skill directories are often committed to version control. The rules above protect them: a directory that existed before deployment (e.g. checked out from git) is external and never deleted; line-ending differences don't count as changes; any other change, or a `.git` inside the skill directory, makes it `"Modified"`, so it is reported instead of deleted. Deleting a deployment does delete project skill directories that the deployment created and that are unchanged.

---

## AgentToolsObject

### Data

```wl
AgentToolsObject[ <|
    "Name"        -> "Wolfram" | "Publisher/Paclet/Bundle" | "MyBundle",
    "Location"    -> "BuiltIn" | PacletObject[ ... ] | None,
    "MCPServers"  -> { "Wolfram" | "Publisher/Paclet/Server" | MCPServerObject[ ... ], ... },
    "AgentSkills" -> { "Publisher/Paclet/skill" | "skill" | LLMSkill[ ... ] | File[ ... ], ... },
    "Description" -> "..." (optional)
|> ]
```

Validated on construction (`System`Private`HoldSetValid`, like `MCPServerObject`): `"Name"` string, `"MCPServers"` list of strings / `MCPServerObject`s, `"AgentSkills"` list of skill specifications; missing lists default to `{}`; `"Location"` defaults to `None`. Ad hoc bundles (`"Location" -> None`) may not use a name containing `/` (reserved for paclets) or the name of a built-in bundle (`InvalidAgentToolsObject`). At least one server or skill is required to deploy (`AgentToolsEmpty`), not to construct.

### Constructors

| Form | Result |
|---|---|
| `AgentToolsObject[ "Wolfram" ]` | Built-in bundle from `$defaultAgentTools`. |
| `AgentToolsObject[ "Publisher/Paclet/Bundle" ]`, `AgentToolsObject[ "Paclet/Bundle" ]` | Paclet bundle: installed paclet first, otherwise remote metadata from `PacletFindRemote` (metadata only; never installs). |
| `AgentToolsObject[ "Publisher/Paclet" ]`, `AgentToolsObject[ "Paclet" ]` (a paclet name) | That paclet's bundle if it defines exactly one; `AgentToolsBundleNameAmbiguous` (listing the names) if several; `AgentToolsNotFound` if none. Checked before qualified-name parsing for installed paclets so `"Wolfram/JIRALink"` never means paclet `"Wolfram"`, bundle `"JIRALink"`. For uninstalled paclets, a remote paclet with exactly this name (two-segment names only) is checked before the qualified interpretation. Names are matched exactly (`PacletFind`/`PacletFindRemote` treat `*` as a wildcard; wildcards never match). A name without `/` only refers to an installed paclet. |
| `AgentToolsObject[ <| ... |> ]` | Ad hoc bundle (`"Location" -> None` unless given). |
| `AgentToolsObject[ obj_AgentToolsObject ]` | `obj` |

Unknown names fail with `AgentToolsNotFound`. Name resolution never loads definition files (bundle membership comes from PacletInfo only); properties that need definitions load them on access.

### Properties

| Property | Description |
|---|---|
| `"Name"`, `"Location"`, `"Description"` | Stored values (`"Description"` → `Missing[...]` if absent) |
| `"MCPServers"` | Resolved servers as `MCPServerObject`s (loads definitions); alias `"MCPServerObjects"` |
| `"AgentSkills"` | Resolved skills as `LLMSkill` objects (loads definitions): `LLMSkill[File[dir]]` for directory sources, `LLMSkill[{name, description}, body]` otherwise (other frontmatter is not represented); aliases `"Skills"`, `"LLMSkills"` |
| `"MCPServerNames"`, `"AgentSkillNames"` | Names only, without loading definitions: qualified names for paclet items (as given in the bundle), the skill's name for `LLMSkill`/`File`/association specs |
| `"Tools"` | Union of the servers' tools |
| `"Data"`, `"Properties"` | Full association (including the stored server and skill specifications) / property list |

As for `MCPServerObject`'s `"Tools"` and `"ToolNames"`, the plural properties give the resolved objects and the `"...Names"` properties give the (qualified) names. Internal code that needs the stored specifications (paclet installation before deploying, `InstallAgentSkills`/`UninstallAgentSkills` on a bundle) reads them from `"Data"`.

Formatting: summary box (name, server names, skill names; hidden: location, description).

### `$DefaultAgentTools`

One built-in bundle per default MCP server, with the same name, plus the built-in skills that go with it:

```wl
$defaultAgentTools[ "Wolfram" ] = <|
    "Name"        -> "Wolfram",
    "Location"    -> "BuiltIn",
    "MCPServers"  -> { "Wolfram" },
    "AgentSkills" -> { "wolfram-language", "wolfram-alpha", "wolfram-debugging" }
|>;
(* likewise "WolframAlpha" -> { "wolfram-alpha" },
   "WolframLanguage" and "WolframPacletDevelopment" -> { "wolfram-language", "wolfram-notebooks", "wolfram-paclets", "wolfram-debugging" } *)
```

`$DefaultAgentTools := AgentToolsObject /@ KeySort @ $defaultAgentTools` (self-caching and protected, like `$DefaultMCPServers`; skill specs are names only, resolved lazily when they are used, so nothing machine-specific is baked into the MX).

### Built-in skills

The built-in skills are the skill directories in the paclet's `"AgentSkills"` asset (`Assets/AgentSkills/`, built from `AgentSkills/` by `Scripts/BuildAgentSkills.wls` and committed; see [docs/agent-skills.md](../docs/agent-skills.md)). `$defaultAgentSkills` maps each name to `builtInSkillDirectory[ name ]` with `RuleDelayed`, which gives `File[ <$thisPaclet AssetLocation "AgentSkills">/<name> ]`, or `Missing[ "NotAvailable", name ]` if the loaded paclet lacks it:

- `builtInSkillDefinition[ name ]` gives the definition; unknown names fail with `AgentSkillNotFound`, a missing directory with `BuiltInAgentSkillMissing`. `toLLMSkill[ name ]` (the `"AgentSkills"` property) and `toAgentSkillSource[ name, _ ]` use it for bare names.
- `builtInSkillSource[ name ]` adds `"Identifier" -> name` and `"Version" -> $pacletVersion` (the loaded AgentTools version, not the `metadata.version` of the built `SKILL.md`), so redeploying after a paclet update is an upgrade of the same source. Because built-in skills only change with the paclet, the upgrade needs no `OverwriteTarget` (`builtInSkillSourceQ` in the [install decision](#install-decision-deployment)); the "keep the newer installed copy" rule still runs first, so a directory that other deployments use is never downgraded.

Deploying a built-in bundle (`"Location" -> "BuiltIn"`, recorded as `"AgentTools"/"Location" -> "BuiltIn"`) differs from other bundles in two ways, because its skills complement its MCP server:

- A target without a skills root gets only the server, without `AgentSkillsNotDeployed` (see [Targets, scope, and partial support](#targets-scope-and-partial-support)).
- Skill conflicts (`AgentSkillExists`, `AgentSkillModified`, `AgentSkillConflict`, `AgentSkillUpdate`) don't fail the deployment. The conflicting skills are left untouched and dropped from the plan, everything else is deployed, `AgentSkillNotInstalled` (skill name, `File[ dir ]`) is issued per skipped skill, and the record lists them in `"Skills"/"NotInstalled"`. If that would leave nothing to deploy (no MCP server for the target and no remaining skill decision), the conflicts fail the deployment as before, so no empty deployment is recorded. `OverwriteTarget -> All` still replaces them. Ad hoc and paclet bundles keep failing on conflicts.

### `AgentToolsObjects`

```wl
AgentToolsObjects[ pattern : All | _String : All, opts ]
```

Same options and semantics as `MCPServerObjects`: installed paclet bundles by default; `"IncludeBuiltIn" -> True` adds `$DefaultAgentTools`; `"IncludeRemotePaclets" -> True` adds bundles of uninstalled paclets (`UpdatePacletSites` passed through). Built from PacletInfo only (no definition files are loaded).

---

## Paclet Extension

### Multiple extension entries

A paclet may have several `{"AgentTools", ...}` entries. All applicable entries are used, everywhere (the current code only reads the first):

- `getAgentToolsExtensions[ paclet ]` uses ``PacletTools`PacletExtensions[ paclet, "AgentTools" ]``, which filters entries by their `"SystemID"` qualifier for installed paclets (it does not filter `"WolframVersion"` in 15.0; neither does AgentTools). When that fails (it does for remote `PacletFindRemote` paclets, whose location is a URL), it falls back to the raw `paclet[ "Extensions" ]` and applies the `"SystemID"` qualifier itself, with the same semantics (`All` matches every system; the string `"All"` is an ordinary system ID).
- **Items are paclet-scoped.** A paclet's declared servers, tools, prompts, and skills are the union of all its entries' declarations (first occurrence wins for the declaration form). An entry may list an item declared in another entry of the same paclet (as in the example below, where the second bundle re-lists `MyPacletTools`).
- **Definition lookup searches every entry's `Root`** (in entry order, without duplicates, skipping roots that don't exist): for each root, the item's per-item file, then the combined file (for skills, the skill directory first; see below). The first root that defines the item wins. The session cache key stays `{ pacletName, version, type, name }` (the search is deterministic). `ValidateAgentToolsPacletExtension` reports an item defined in two roots as `DuplicateDefinitionFiles`.
- Item names in PacletInfo must not contain `/` (cross-paclet references belong in definition files, as today).

### Implicit bundles

Each applicable entry that declares at least one `"MCPServers"` or `"AgentSkills"` item defines an `AgentToolsObject`:

- `"Name"`: the entry's `"Name"` (default `"AgentTools"`), qualified as `"PacletName/Name"` (`"Publisher/Paclet/Name"` for publisher paclets). Must not contain `/`.
- `"MCPServers"` / `"AgentSkills"`: the entry's own declarations, qualified.
- `"Description"`: the entry's optional `"Description"`.
- `"Location"`: the paclet.

Entries that declare only `"Tools"`/`"MCPPrompts"` define no bundle (tools and prompts are building blocks deployed through servers).

```wl
PacletObject[ <|
    "Name"       -> "PublisherID/MyPaclet",
    "Version"    -> "1.0.0",
    "Extensions" -> {
        { "AgentTools",
            "Name"        -> "MyPaclet",
            "MCPServers"  -> { "MyPacletTools" },
            "AgentSkills" -> { "using-my-paclet", "my-paclet-docs" }
        },
        { "AgentTools",
            "Name"        -> "MyPacletDevelopment",
            "MCPServers"  -> { "MyPacletTools", "MyPacletDevTools" },
            "AgentSkills" -> { "using-my-paclet", "my-paclet-docs", "my-paclet-development", "my-paclet-building" }
        }
    }
|> ]

AgentToolsObject[ "PublisherID/MyPaclet/MyPacletDevelopment" ]
DeployAgentTools[ "ClaudeCode", "PublisherID/MyPaclet/MyPaclet" ]
```

Valid entry keys: `"Root"`, `"Name"`, `"Description"`, `"MCPServers"`, `"Tools"`, `"MCPPrompts"`, `"AgentSkills"`, and the paclet-extension qualifiers `"SystemID"` and `"WolframVersion"`.

### Skill definitions

`"AgentSkills"` declarations use the same three forms as other items (name, `{ name, description }`, association with `"Name"`). For declared skill `name`, each root is searched in this order:

1. **Skill directory** `<Root>/AgentSkills/<name>/SKILL.md` — the only form that can ship bundled files (`scripts/`, `references/`, `assets/`). Copied as-is.
2. **Per-item definition file** `<Root>/AgentSkills/<name>.mx|.wxf|.wl` (priority `mx > wxf > wl`).
3. **Combined file** `<Root>/AgentSkills.mx|.wxf|.wl`, an association keyed by skill name.

A definition evaluates to an `LLMSkill[...]` or an association with `"Name"`, `"Description"`, `"Body"` and optional frontmatter keys (`"License"`, `"Compatibility"`, `"Metadata"`, `"AllowedTools"`, `"AdditionalFrontmatter"`). Associations are used directly (no `LLMSkill` is constructed: the association constructor needs LLMFunctions internals). In `.wl` files, use an association or `LLMSkill[{name, description}, body]`; `.wxf`/`.mx` may contain serialized `LLMSkill`s. An `LLMSkill`'s `"Location"` is honored only if it is a directory inside one of the paclet's extension roots (a relative location is resolved against the definition file's directory); any other `"Location"` (e.g. an absolute path from the author's machine baked into a `.wxf`/`.mx`) is ignored and `SKILL.md` is generated from the fields. Definitions are cached per session like other definitions (`$pacletDefinitionCache`, which now also accepts `LLMSkill` results).

`resolvePacletSkill[ "Pub/Paclet/name" ]` (installed paclets only) returns a **skill definition**, which `toAgentSkillSource` turns into a normalized source:

```wl
<|
    "Type"          -> "PacletSkill",
    "Name"          -> "name",
    "QualifiedName" -> "Pub/Paclet/name",
    "PacletName"    -> "Pub/Paclet",
    "PacletVersion" -> "1.0.0",
    "Directory"     -> File[ dir ]          (* skill directory form, or an LLMSkill whose Location is honored *)
    (* or *)
    "Definition"    -> LLMSkill[ ... ] | <| "Name" -> ..., "Description" -> ..., "Body" -> ..., ... |>
|>
```

It fails with `PacletNotInstalled`, `PacletSkillNotFound` (not declared or no definition), or `InvalidPacletSkillDefinition` (bad contents or name mismatch).

### Validation (`ValidateAgentToolsPacletExtension`)

Extended checks:
- Every entry is checked (structure, keys, declaration forms); `"Name"`/`"Description"`/`"WolframVersion"` must be strings; `"SystemID"` must be `All`, a string, or a non-empty list of strings (the forms ``PacletTools`PacletExtensions`` accepts); names must not contain `/`.
- Duplicate bundle names (`DuplicateBundleName`) among entries that can be active on the same system (entries whose `"SystemID"` qualifiers are disjoint may share a name), including two entries without `"Name"`.
- Declared item names must not contain `/` (`InvalidItemName`).
- Each declared skill has a directory or definition file in some root (`MissingDefinitionFile`); a skill with both a directory and a per-item definition file, or defined in two roots, is `DuplicateDefinitionFiles`.
- Skill contents (installed paclets): the directory's `SKILL.md` parses with a name equal to the declared name; definition files yield a valid `LLMSkill`/association with that name; names and descriptions follow the Agent Skills rules (`InvalidSkillDefinition`).
- Bundle checks: servers within one bundle must resolve to distinct config keys (`DuplicateBundleConfigKey`); a bundle name equal to a server name of the same paclet is an error unless that bundle contains that server (`AmbiguousBundleName`).
- The `Success` data gains `"AgentSkills"` (declared skills) and `"AgentTools"` (qualified bundle names).

### Shared helpers (`Kernel/PacletExtension.wl`)

| Function | Description |
|---|---|
| `getAgentToolsExtensions[ paclet ]` | `{ <|entry data|>, ... }` for all applicable entries (empty list if none) |
| `getAgentToolsExtensionDirectories[ paclet ]` | Existing root directories (strings), in entry order, without duplicates |
| `getAgentToolsDeclaredItems[ paclet, type ]` | Union of declared item names across entries (existing signature; now all entries) |
| `getAgentToolsBundles[ paclet ]` | `{ <| "Name" -> qualified, "Location" -> paclet, "MCPServers" -> {...}, "AgentSkills" -> {...}, "Description" -> ... |>, ... }` built from PacletInfo only |
| `resolvePacletBundle[ qualifiedName ]` | Bundle data for a qualified bundle name (installed, else remote metadata), or `Missing[ "NotFound" ]` (callers decide the failure) |
| `resolvePacletSkill[ qualifiedName ]` | Skill definition (above) |

`getAgentToolsExtension`, `getAgentToolsExtensionData`, `getAgentToolsExtensionDirectory` keep working (first entry) for compatibility, but no code path relies on "first entry only" semantics any more.

---

## DeployAgentTools

### Signatures (unchanged shape)

```wl
DeployAgentTools[ target ]
DeployAgentTools[ target, tools ]
DeployAgentTools[ All, tools ]
```

`tools` is `Automatic` (the client's default toolset name), a name, an `AgentToolsObject`, an `MCPServerObject`, or an association (ad hoc `AgentToolsObject`).

### Resolving `tools` (before the lock)

A name string resolves in this order:
1. A user-created MCP server with that name (an existing `Metadata.wxf`), preserving today's precedence of user servers over built-ins.
2. A built-in bundle (`$defaultAgentTools`).
3. If it contains `/`, or is the exact name of an installed paclet:
   1. an installed paclet with exactly that name, or (two-segment names) a remote one → install it if needed, then its single bundle (`AgentToolsBundleNameAmbiguous` / `AgentToolsNotFound` otherwise; the name is never reinterpreted as `"PacletName/ItemName"`);
   2. a bundle under the qualified interpretation (installed paclet, else remote metadata);
   3. for valid qualified names only: `ensurePacletForInstall` (installs the paclet named by the qualified interpretation), then 3.2;
   4. that paclet's MCP server.
4. Otherwise an MCP server of that name (`MCPServerNotFound` if there is none, as before).

An `MCPServerObject` (given directly or found above) is wrapped in an implicit single-server bundle with the server's name and `"ToolsetType" -> "MCPServerObject"`. For any bundle (including one given as a value), `ensurePacletForInstall` runs for the bundle's paclet and for every paclet-qualified server (except user-created servers whose names contain `/`) or skill it names, before definitions are resolved (`DeployAgentTools` is an execution-level operation, like `InstallMCPServer`); a bundle that only came from remote metadata is then resolved again from the installed paclet (the implicit bundle of a server as that server).

### Options

| Option | Default | Description |
|---|---|---|
| `OverwriteTarget` | `False` | `False`: fail with `DeploymentExists` if the deployment conflicts with an existing one. `True`: replace conflicting deployments and upgrade unmodified skills from the same source. `All`: also overwrite skill directories that were modified or belong to a different source (see [Install decision](#install-decision-deployment)). |
| `"SkillsDirectory"` | `Automatic` | `Automatic`: derive the skills root from the target. `File[ root ]`: install skills there (for custom client homes). `None`: don't deploy skills. |
| (all `InstallMCPServer` options) | | Passed through to each server's `InstallMCPServer` call. A string `"MCPServerName"` is only allowed when the bundle has exactly one server (`InvalidMCPServerNameOption`). `"ToolOptions"` is validated once against the union of the bundle's tools, and each server receives only the entries for its own tools and the default tools. |

### Targets, scope, and partial support

`resolveDeployTarget` returns `<| "ClientName", "Target", "Scope", "LocationKey", "ConfigFile" -> File | None, "SkillsDirectory" -> File | None |>`:

| Target | MCP config file | Skills root (`"SkillsDirectory" -> Automatic`) | Scope |
|---|---|---|---|
| `"Client"` | `installLocation` | `skillsLocation` (if the client supports skills) | `"Global"` |
| `{ "Client", dir }` | `projectInstallLocation` (if `"ProjectSupport"`) | `projectSkillsLocation` (if `"SkillsProjectSupport"`) | `File[ dir ]` |
| `File[ config ]` | the file | exact matches only: the file equals `installLocation[ c ]` → `skillsLocation[ c ]`; the path ends with `c`'s `"ProjectPath"` → project root + `"SkillsProjectPath"`. Otherwise none. Never inferred from `guessClientName`'s format heuristics. | `"Global"` / `File[ projectRoot ]` for the exact matches, else `Missing[ "Unknown" ]` |

`"LocationKey"` identifies *where* a deployment lives for conflict detection: the scope when it is known, otherwise the canonical config file.

A component is deployed if the bundle has it and the target supports it. If some component can't be deployed, the rest is deployed and one warning is issued (`MCPServersNotDeployed` / `AgentSkillsNotDeployed`, naming the bundle and the client). Built-in bundles (`"Location" -> "BuiltIn"`) never issue `AgentSkillsNotDeployed`: their skills complement the server, and several default targets (Claude Desktop, LM Studio, Amazon Q Developer) have no skills directory. The record still lists the skills under `"Skipped"`. If nothing can be deployed, the deployment fails: with the MCP failure (`UnknownInstallLocation`, `UnsupportedMCPClient`, `UnsupportedMCPClientProject`) when the bundle has servers, otherwise with the skills failure (`UnsupportedSkillsClient`, `UnsupportedSkillsClientProject`, `UnknownSkillsLocation`, or `NoSkillsLocation` for a `File` target without a skills root), and `AgentToolsNothingToDeploy` if neither applies. An empty bundle fails with `AgentToolsEmpty`, and a skills-only bundle with `"SkillsDirectory" -> None` with `AgentSkillsDisabled` (checked before the target, so `DeployAgentTools[All, ...]` fails once instead of per client).

### Conflicts

A new deployment conflicts with an existing deployment if either:
- they write the same MCP config key into the same (canonical) config file — so the built-in variants, which share the `"Wolfram"` key, stay mutually exclusive; or
- they deploy the same toolset (same `"ToolsetType"` and name) to the same client and `"LocationKey"`. A built-in server and the built-in bundle of the same name count as the same toolset (the bundle contains exactly that server), which also covers version 1 records.

Several different bundles can therefore be deployed to one client side by side (e.g. `"WolframLanguage"` and `"Publisher/Paclet/Bundle"`), and one toolset can be deployed to several custom config files. Shared skill directories never cause deployment conflicts (they are reference counted). Conflict detection scans all deployment records and uses only recorded data.

### Algorithm

Before the lock:
1. Resolve `tools` to a bundle and `target` to config file / skills root; validate options.
2. Resolve the bundle's servers (`MCPServerObject`) and skills (normalized sources, hashed); compute each server's config key (`mcpServerConfigKey[ obj, mcpServerNameOption ]`: option string → server `"MCPServerName"` → server `"Name"`). Two servers of one bundle with the same key fail (`DuplicateBundleConfigKey`).
3. MCP preflight for every server (`preflightMCPServerInstall`, shared from `InstallMCPServer.wl`): option validation, LLMKit check (honoring `"VerifyLLMKit"`/`"EnableLLMKit"`), tool initialization, paclet definition validation.

Under the lock:
4. Sweep the registry. Find conflicting deployments; with `OverwriteTarget -> False`, fail with `DeploymentExists`.
5. Skill preflight: compute install decisions for all skills (excluding the replaced deployments' references, see above). Unforced conflicts fail (`AgentSkillConflict` / `AgentSkillModified` / `AgentSkillExists` / `AgentSkillUpdate`), except for built-in bundles, whose conflicting skills are removed from the plan and recorded under `"NotInstalled"`; one `AgentSkillNotInstalled` warning per skipped skill is issued in step 9.
6. Apply, recording an undo action for every change, inside `WithCleanup` so aborts also roll back:
   - before each `InstallMCPServer` call, snapshot the config file (raw bytes, or "did not exist") and the server's `Installations.wxf` (and those of the other built-in servers, which `clearStaleBuiltInRecords` may touch); after the call, record the config file's hash;
   - `InstallMCPServer[ target, server, opts ]` for each server (with `"VerifyLLMKit" -> False`; the check ran in step 3);
   - create/replace skill directories (replacements keep a backup until the end of the step);
   - write registry entries (snapshotting the previous entry files).
   Undo runs in reverse: config files are restored only if their current hash still equals the hash after our last write (otherwise they are left as they are and `MCPServerNotRemoved`-style warnings name the keys that remain); `Installations.wxf` files, skill directories (from backups), and registry entries are restored from their snapshots. The failure then propagates.
7. Write the deployment record into a staging directory under `$deploymentsPath` and rename it to its UUID directory (a failure rolls back step 6).
8. Remove the replaced deployments, **excluding** what the new deployment now owns: MCP config keys the new deployment wrote to the same config file are not removed (nor are their `Installations.wxf` records for the same server and file), and skill references are simply dropped for directories the new deployment references (its reference was added in step 6, so shared skills are never deleted and re-copied). Failures here are warnings; the new deployment stays.
9. Issue aggregated messages; return the `AgentToolsDeployment`.

### `DeployAgentTools[ All, ... ]`

Iterates over `Keys @ $SupportedClients` (taking the lock per client). Per-client results:

| Result | When |
|---|---|
| `AgentToolsDeployment[ ... ]` | deployed (possibly partially; see warnings) |
| `Missing[ "DeploymentExists", client ]` | `DeploymentExists` |
| `Missing[ "Unsupported", { client, $OperatingSystem } ]` | `UnknownInstallLocation`, `UnsupportedMCPClient`, `UnsupportedMCPClientProject`, `UnsupportedSkillsClient`, `UnsupportedSkillsClientProject`, `UnknownSkillsLocation`, `NoSkillsLocation` |
| `Missing[ "AgentSkillConflict", client ]` | `AgentSkillConflict`, `AgentSkillModified`, `AgentSkillExists`, `AgentSkillUpdate` |

Per-client messages for these tags and for `AgentSkillsNotDeployed`/`MCPServersNotDeployed`/`AgentSkillNotInstalled` are quieted and summarized once: `DeploymentsExistWarning` (existing), `AgentSkillsNotDeployedWarning` (lists the clients whose skills were skipped, excluding built-in bundles), `AgentSkillConflictWarning`, `AgentSkillsNotInstalledWarning` (lists the clients where a built-in bundle was deployed without some of its skills). Other failures still propagate.

---

## Deployment Records (schema v2)

```wl
<|
    "UUID"          -> "...",
    "Version"       -> 2,
    "Timestamp"     -> DateObject[ ... ],
    "PacletVersion" -> "2.3.0",
    "CreatedBy"     -> "DeployAgentTools",
    "Toolset"       -> "Publisher/MyPaclet/MyPacletTools",  (* PRIMARY SERVER name (v1 meaning); absent if no servers *)
    "AgentTools"    -> <|
        "Type"          -> "AgentToolsObject" | "MCPServerObject",
        "Name"          -> "Publisher/MyPaclet/MyPaclet",    (* bundle (or wrapped server) name *)
        "Location"      -> "BuiltIn" | "Paclet" | "User" | None,
        "PacletName"    -> "Publisher/MyPaclet" | Missing[ ],
        "PacletVersion" -> "1.0.0" | Missing[ ]
    |>,
    "ClientName"    -> "ClaudeCode",
    "Target"        -> "ClaudeCode" | { "ClaudeCode", File[ dir ] } | File[ ... ],
    "Scope"         -> "Global" | File[ dir ] | Missing[ "Unknown" ],
    "LocationKey"   -> "Global" | "/canonical/project/dir" | "/canonical/config/file",
    "MCP"           -> <| (* v1 shape, for the primary (first) server; absent if no servers were deployed *)
        "ClientName" -> "ClaudeCode",
        "Target"     -> ...,
        "Server"     -> "Publisher/MyPaclet/MyPacletTools",
        "ConfigFile" -> File[ ... ],
        "Options"    -> <| ... |>
    |>,
    "MCPServers"    -> {
        <| "Name" -> "Publisher/MyPaclet/MyPacletTools", "ConfigKey" -> "MyPacletTools", "ConfigFile" -> File[ ... ] |>,
        ...
    },
    "Skills"        -> <|
        "Directory" -> File[ root ] | None,
        "Installed" -> {
            <| "Name" -> "using-my-paclet", "Directory" -> File[ ... ], "RegistryKey" -> "...", "Identifier" -> ..., "Version" -> ... |>,
            ...
        },
        "Skipped"   -> { "using-my-paclet", ... },    (* skills not deployed because the target lacks support *)
        "NotInstalled" -> { "wolfram-language", ... } (* skills of a built-in bundle left out because of conflicts; usually { } *)
    |>,
    "Hooks"         -> <| |>,
    "Meta"          -> <| |>
|>
```

- **Compatible with older AgentTools versions.** Older versions match records against the v1 pattern (extra keys are ignored) and remove a deployment with `UninstallMCPServer[ dep["ConfigFile"], dep["Toolset"] ]`. Because top-level `"Toolset"` is the primary *server* name and `"MCP"` keeps its v1 shape, they list the deployment, detect config-file conflicts, and remove the primary server's entry. They don't remove other servers or release skills; registry entries left without references are released by the next [sweep](#stale-references-and-garbage-collection). Skills-only deployments have no `"MCP"`/`"Toolset"` key and are invisible to older versions. The preferences UI's direct reads (`#["MCP"]["Server"]`, `#["MCP"]["ConfigFile"]`, `#["Server"]`) keep working.
- **Snapshots, not re-resolution.** Removal and conflict checks use only recorded data: config keys, config files, skill registry keys. `DeleteObject` never resolves servers or bundles by name and makes no network calls.
- **v1 records** are normalized in memory on read (never rewritten): top-level `"ClientName"`/`"Target"`/`"Scope"` from `"MCP"`; `"LocationKey"` from the scope or the config file; `"AgentTools" -> <| "Type" -> "MCPServerObject", "Name" -> server, ... |>`; `"MCPServers" -> { <| "Name" -> server, "ConfigKey" -> key, "ConfigFile" -> file |> }`; `"Skills" -> <| "Directory" -> None, "Installed" -> { }, "Skipped" -> { }, "NotInstalled" -> { } |>`. The config key is derived **locally** (`localMCPServerConfigKey`): the recorded `"MCPServerName"` option if it is a string; else the `"MCPServerName"` (or `"Name"`) of the server if it resolves without network access (built-in server, user server file, or installed paclet); else the last `/`-segment of the name.
- **Validation pattern.** `"UUID"`, `"Version"`, `"Timestamp"`, `"PacletVersion"`, `"CreatedBy"`, `"Skills"`, `"Hooks"`, `"Meta"` are required as before; `"MCP"` is required for v1 and optional for v2; v2 additionally requires `"AgentTools"`, `"ClientName"`, `"Target"`, `"LocationKey"`, `"MCPServers"`.

### `DeployedAgentTools`

Unchanged API. Lists v1 (normalized) and v2 records, including skills-only ones; `DeployedAgentTools[ client ]` filters by the recorded client name.

### Properties

Existing properties keep their meaning. Changes and additions:

| Property | Description |
|---|---|
| `"ClientName"`, `"Target"`, `"Scope"`, `"Location"` | Read from the top level (normalized for v1) |
| `"Toolset"` | The bundle (or wrapped server) name: `"AgentTools"/"Name"`, falling back to top-level `"Toolset"` and `"MCP"/"Server"` (unchanged for single-server and built-in deployments, which is what the preferences UI uses) |
| `"ToolsetType"` | `"AgentToolsObject"` or `"MCPServerObject"` |
| `"AgentToolsObject"` | The deployed bundle resolved by name (`Missing[ "NotAvailable" ]` for ad hoc bundles); the wrapped server's implicit bundle for `"MCPServerObject"` |
| `"Server"` | Primary server name (unchanged meaning) |
| `"MCPServerObject"` | The primary server's object; `"MCPServerObjects"` gives all |
| `"MCPServerNames"` | Recorded server names |
| `"ConfigFile"` | The primary server's config file (`Missing[ "NotAvailable" ]` if none) |
| `"Tools"` | Union of the servers' tools |
| `"AgentSkills"` | Installed skill names; `"SkillsDirectory"` the skills root |
| `"Skills"` | The recorded skills component (as before) |

### `DeleteObject`

Under the lock: sweep; remove each recorded config key (except keys that another existing deployment records for the same config file — e.g. a replaced deployment that couldn't be removed completely must not remove what its replacement owns) from its config file (`removeMCPConfigEntry[ file, clientName, configKey ]`, a new shared helper in `InstallMCPServer.wl` that dispatches on the client's config format and is also used by `uninstallMCPServer`); clear the matching `Installations.wxf` record **by name** (`mcpServerDirectory[ name ]`, no resolution); release the skill references (see [Release decision](#release-decision-deployment-removal)); delete the deployment directory; return `Null`. A config entry that can't be removed (unparseable file, permission error) is reported with `MCPServerNotRemoved` instead of being silently swallowed; a key that is already absent is not an error.

---

## Messages

New (in `Kernel/Messages.wl`; most already added in the scaffolding):

| Tag | Template |
|---|---|
| `AgentToolsNotFound` | ``No AgentToolsObject found for name "`1`".`` |
| `InvalidAgentToolsObject` | ``Invalid AgentToolsObject specification: `1`.`` |
| `AgentToolsEmpty` | ``The agent tools "`1`" contain no MCP servers or agent skills to deploy.`` |
| `AgentToolsBundleNameAmbiguous` | ``The paclet "`1`" defines several agent tools bundles: `2`. Specify one of these names.`` |
| `PacletAgentToolsNotFound` | ``Agent tools "`1`" not found in paclet "`2`".`` |
| `PacletSkillNotFound` | ``Agent skill "`1`" not found in paclet "`2`".`` |
| `InvalidPacletSkillDefinition` | ``Invalid agent skill definition in `1`.`` |
| `AgentSkillNotFound` | ``No agent skill found for "`1`".`` |
| `BuiltInAgentSkillMissing` | ``The built-in agent skill "`1`" is missing from the installed AgentTools paclet. Reinstall the paclet with PacletInstall["Wolfram/AgentTools", ForceVersionInstall -> True].`` |
| `InvalidAgentSkill` | ``Invalid agent skill specification: `1`.`` |
| `InvalidAgentSkillName` | ``Invalid agent skill name "`1`". Skill names must be 1 to 64 lowercase letters, digits, and hyphens, without leading, trailing, or consecutive hyphens.`` |
| `InvalidAgentSkillDescription` | ``The agent skill "`1`" needs a description of 1 to 1024 characters.`` |
| `DuplicateAgentSkillName` | ``Several skills named "`1`" were given.`` |
| `InvalidSkillsDirectory` | ``Invalid skills directory: `1`. Expected a directory that contains skill folders.`` |
| `NoSkillsLocation` | ``Unable to determine where to install agent skills for `1`. Use the "SkillsDirectory" option to specify a directory.`` |
| `AgentSkillExists` | ``A different skill named "`1`" already exists at `2`. Use OverwriteTarget -> `3` to replace it.`` |
| `AgentSkillModified` | ``The skill "`1`" at `2` has been modified since it was installed. Use OverwriteTarget -> All to replace it.`` |
| `AgentSkillConflict` | ``A different skill named "`1`" is already installed at `2`. Use OverwriteTarget -> All to replace it.`` |
| `AgentSkillUpdate` | ``A different version of the skill "`1`" is installed at `2`. Use OverwriteTarget -> True to update it.`` |
| `AgentSkillNewerVersionKept` | ``The skill "`1`" at `2` was not replaced because the installed version (`3`) is newer than `4`.`` |
| `AgentSkillInUse` | ``The skill "`1`" at `2` was not removed because other agent tools deployments still use it.`` |
| `AgentSkillNotRemoved` | ``The skill "`1`" at `2` was modified after it was installed, so it was not removed. Evaluate `3` to remove it.`` |
| `InstallAgentSkill` / `InstallAgentSkillNamed` | ``Successfully installed agent skill "`1`".`` / ``... for `2`.`` |
| `UninstallAgentSkill` / `UninstallAgentSkillNamed` | ``Successfully uninstalled agent skill "`1`".`` / ``... for `2`.`` |
| `UnsupportedSkillsClient` | ``No automatic agent skill installation support for client `1`.`` |
| `UnsupportedSkillsClientProject` | ``No automatic project-level agent skill installation support for client `1`.`` |
| `UnknownSkillsLocation` | ``Unable to determine the skills location for `1` on `2`. Use File[…] to specify a custom location.`` |
| `AgentSkillsNotDeployed` | ``Warning: The agent skills of "`1`" were not installed because `2` does not support agent skills for this target.`` |
| `MCPServersNotDeployed` | ``Warning: The MCP servers of "`1`" were not installed because `2` does not support MCP servers for this target.`` |
| `AgentSkillsNotDeployedWarning` | ``Warning: Agent skills were not installed for these clients, which do not support them: `1`.`` |
| `AgentSkillConflictWarning` | ``Warning: Some deployments were skipped because of conflicting agent skills. Use OverwriteTarget -> All to replace them.`` |
| `AgentSkillNotInstalled` | ``Warning: The agent skill "`1`" was not installed because a different or modified skill with that name already exists at `2`. Use OverwriteTarget -> All to replace it.`` |
| `AgentSkillsNotInstalledWarning` | ``Warning: Some agent skills were not installed for these clients because different or modified skills with the same names already exist: `1`. Use OverwriteTarget -> All to replace them.`` |
| `InvalidMCPServerNameOption` | ``The "MCPServerName" option can only be a string when deploying a single MCP server; "`1`" has `2` servers.`` |
| `InvalidSkillsDirectoryOption` | ``Invalid value for the "SkillsDirectory" option: `1`. Expected Automatic, None, or File[…].`` |
| `DuplicateBundleConfigKey` | ``The MCP servers `1` of "`2`" would all be installed with the configuration key "`3`".`` |
| `MCPServerNotRemoved` | ``The MCP server configuration "`1`" could not be removed from `2`.`` |
| `AgentToolsNothingToDeploy` | ``Nothing from the agent tools "`1`" can be deployed to `2`.`` |
| `AgentSkillsDisabled` | ``The agent tools "`1`" contain only agent skills, but "SkillsDirectory" -> None disables installing them.`` |
| `AgentSkillUnreadable` | ``Unable to read the agent skill file `1`.`` |
| `AgentSkillWriteFailed` / `AgentSkillRemoveFailed` | Writing or removing a skill directory failed (it is rolled back / left in place). |
| `AgentSkillBackupNotRemoved` | ``The agent skill "`1`" was removed, but its backup at `2` could not be deleted completely. Delete it manually.`` |
| `DeploymentNotRemoved` | ``Warning: The replaced deployment "`1`" could not be removed completely.`` |
| `DeploymentLockTimeout` | ``Timed out waiting for another kernel to finish modifying agent tools deployments.`` |

Existing tags reused: `DeploymentExists`, `DeploymentsExistWarning`, `PacletNotInstalled`, `InvalidProjectDirectory`, `UnsupportedMCPClient`, `UnknownInstallLocation`.

---

## Implementation Touchpoints

| File | Change |
|---|---|
| `Kernel/SupportedClients.wl` | `$SupportedClients`; `$SupportedMCPClients` subset; `"SkillsLocation"`/`"SkillsProjectPath"` for every client per the table; derived `"SkillsSupport"`/`"SkillsProjectSupport"`; `antigravitySkillsLocation`. |
| `Kernel/InstallMCPServer.wl` | `skillsLocation`, `projectSkillsLocation`; `removeMCPConfigEntry` (refactored out of `uninstallMCPServer`'s five format variants); `mcpServerConfigKey`; `preflightMCPServerInstall`; `installLocation` tolerant of a missing `"InstallLocation"`; `guessClientName`/`DetectedMCPClients` read `$SupportedClients`. |
| `Kernel/PacletExtension.wl` | Multiple entries; multi-root lookup; `"AgentSkills"` resolution; bundles; new helpers. |
| `Kernel/ValidateAgentToolsPacletExtension.wl` | Checks listed above. |
| `Kernel/MCPServerObject.wl` | `buildRemotePacletServerMetadata` searches all entries; `mcpServerExistsQ` unchanged (already matches any entry). |
| `Kernel/AgentSkills.wl` (new, ``Wolfram`AgentTools`AgentSkills` ``) | Skill specs → sources, `SKILL.md` generation, writing/replacing/removing, hashing, `canonicalPath`, `skillDirectoryState`, `InstallAgentSkills`, `UninstallAgentSkills`, the skill registry (sweep, install/release decisions), built-in skill registry (`$defaultAgentSkills`, resolved from the paclet's `"AgentSkills"` asset). |
| `Kernel/AgentToolsObject.wl` (new, ``Wolfram`AgentTools`AgentToolsObject` ``) | `AgentToolsObject`, `AgentToolsObjects`, `$DefaultAgentTools`, `toAgentToolsObject`. |
| `Kernel/DeployAgentTools.wl` | Schema v2, v1 normalization, tools resolution, target resolution, conflicts, plan/apply/undo, lock, `DeleteObject`, new properties, `All` aggregation. |
| `Kernel/Formatting.wl` | `AgentToolsObject` boxes; deployment hidden rows gain skills. |
| `Kernel/Files.wl` | `$skillRegistryPath` (`$deploymentsPath/.SkillRegistry`), `$deploymentLockFile` (`$deploymentsPath/.lock`). |
| `Kernel/CommonSymbols.wl`, `Kernel/Messages.wl`, `Kernel/Main.wl`, `PacletInfo.wl` | Shared symbols, messages, exports, contexts (mostly done in the scaffolding). |
| `Assets/AgentSkills/`, `Scripts/BuildAgentSkills.wls`, `Scripts/Resources/AgentSkillsBuilder.wl` | The built-in skills (committed build output, declared as the `"AgentSkills"` asset in `PacletInfo.wl`) and their build; see [docs/agent-skills.md](../docs/agent-skills.md). |
| `Tests/` | New `AgentSkills.wlt`, `AgentToolsObject.wlt`, `AgentSkillsBuild.wlt`, `DeployAgentToolsSkills.wlt`; extend `SupportedClients.wlt`, `DeployAgentTools.wlt`, `PacletExtension.wlt`, `ValidateAgentToolsPacletExtension.wlt`, `InstallMCPServer.wlt`/`UninstallMCPServer.wlt` (refactor); update `Block`s of `$SupportedMCPClients`. |
| `TestResources/` | `MockMCPPacletSkills` (two entries, skills as directory / `.wl` / combined file, a `scripts/` file). |
| Docs | `docs/agent-tools-objects.md` (new), `docs/deploy-agent-tools.md`, `docs/paclet-extensions.md`, `docs/mcp-clients.md` (skill locations), `AGENTS.md`, `Specs/DeployAgentTools.md` (point Phase 2 to this spec), `Specs/PacletExtension.md`. |

## Verification

- `InstallAgentSkills`/`UninstallAgentSkills` with every target and skill form; name and description validation; uninstall never deletes the root or anything outside it; link, dangling-link, and file entries; junk and VCS entries; deterministic generated `SKILL.md`; CRLF-normalized comparison; executable bits; source equal to destination; rollback of a partially failed multi-skill install.
- Deployment reference counting: two clients sharing a root (CopilotCLI + VisualStudioCode, Codex + Goose + Zed); two bundles sharing a skill; removal order permutations; modified skill kept with warning; external (pre-existing) skill adopted and kept; upgrade after a source update requires `True`; an older version keeps the newer copy; different-source conflict requires `All`; `True` never clobbers; redeploying an edited in-memory skill with `True`; the sweep releases entries whose deployments vanished.
- Conflicts: two different bundles on one client coexist; built-in variants replace each other; same bundle twice → `DeploymentExists`; one toolset to two custom config files coexists; replacement keeps shared skills and config keys without delete-and-recopy.
- Partial support: bundle with skills to LMStudio (MCP only + warning); built-in bundle to LMStudio/ClaudeDesktop (MCP only, no warning); built-in bundle with a conflicting skill directory (deployed without that skill + `AgentSkillNotInstalled`); `{ "Cursor", dir }` (skills only + warning); skills-only bundle to LMStudio → failure / `Missing[ "Unsupported", ... ]` under `All`; `"SkillsDirectory"` option.
- v1 records: listed, removable (including paclet servers with a custom `"MCPServerName"`), conflict-checked against v2 deployments; the preferences UI accessors work on v2 records; an older-version-style removal (`UninstallMCPServer[ configFile, toolset ]`) of a v2 record removes the primary server.
- Rollback: a failure in the second server of a bundle restores config files, `Installations.wxf`, skill directories, and the registry; a config file changed by someone else during the deploy is not restored.
- Paclet extension: multiple entries, multi-root lookup, skill forms, validation errors, `AgentToolsObjects` discovery, exact-paclet-name bundle lookup.
