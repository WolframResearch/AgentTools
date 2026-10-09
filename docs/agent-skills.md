# Agent Skills in AgentTools

This document explains the agent skills system, how skills are structured and built, and how to add new skills.

## Overview

Agent skills package Wolfram MCP tools as distributable skills following the open [Agent Skills](https://agentskills.io/) standard. Each skill bundles standalone Wolfram Language scripts (`.wls`) generated from `$DefaultMCPTools`, along with a hand-authored `SKILL.md` that instructs compatible agents how to use them. A skill can also include hand-authored references and scripts (see [Hand-Authored Files](#hand-authored-files)). Skills work with any agent that supports the standard (Claude Code, Cursor, Gemini CLI, VS Code, and [many others](https://agentskills.io/home)).

Skills support **dual-mode operation**: when the Wolfram MCP server is available, `SKILL.md` instructs the agent to prefer the MCP tools. When it is not, the agent falls back to executing the bundled scripts via `wolframscript`.

The skill sources live in `AgentSkills/`. `Scripts/BuildAgentSkills.wls` builds them into complete skill directories in `Assets/AgentSkills/`, which are committed to the repository and ship with the paclet as its `"AgentSkills"` asset. These built skills are the built-in skills of the `$DefaultAgentTools` bundles, so `DeployAgentTools` installs them together with the matching MCP server (see [Built-in Skills](#built-in-skills)).

For distribution via Claude Code specifically, skills are packaged as plugins using a `marketplace.json` file. See [Plugin Packaging](#plugin-packaging) below.

The full design specification is in [Specs/AgentSkills.md](../Specs/AgentSkills.md).

## Current Skills

Five skills are defined in `AgentSkills/Manifest.wl`:

### wolfram-language

Full Wolfram Language development environment.

| Script | Source Tool | Description |
| --- | --- | --- |
| `WolframLanguageContext.wls` | WolframLanguageContext | Semantic search for Wolfram Language documentation |
| `WolframLanguageEvaluator.wls` | WolframLanguageEvaluator | Evaluate Wolfram Language code |
| `SymbolDefinition.wls` | SymbolDefinition | Retrieve readable symbol definitions |
| `TestReport.wls` | TestReport | Run `.wlt` test files and return results |
| `CodeInspector.wls` | CodeInspector | Inspect code for issues |

### wolfram-paclets

Paclet development, packaging, and submission workflows.

| Script | Source Tool | Description |
| --- | --- | --- |
| `CheckPaclet.wls` | CheckPaclet | Check a paclet for issues before build or submit |
| `BuildPaclet.wls` | BuildPaclet | Build a `.paclet` archive from a paclet directory |
| `SubmitPaclet.wls` | SubmitPaclet | Submit a paclet to the Wolfram Language Paclet Repository |

### wolfram-alpha

Wolfram|Alpha queries and context retrieval.

| Script | Source Tool | Description |
| --- | --- | --- |
| `WolframAlphaContext.wls` | WolframAlphaContext | Semantic search using Wolfram|Alpha |
| `WolframAlpha.wls` | WolframAlpha | Query Wolfram\|Alpha |

### wolfram-notebooks

Read and write Wolfram notebook (`.nb`) files.

| Script | Source Tool | Description |
| --- | --- | --- |
| `ReadNotebook.wls` | ReadNotebook | Read a notebook file as markdown |
| `WriteNotebook.wls` | WriteNotebook | Convert markdown to a notebook file |

### wolfram-debugging

Techniques and a helper package for debugging Wolfram Language code: messages and stack traces, why calls stay unevaluated, tracing and Trace-free alternatives, profiling and hangs, spying on/mocking/overriding functions, watchpoints, finding definitions and source code, package loading problems, failing tests, parallel/async code, cloud deployments and HTTP, crashes, and how the MCP evaluator (Local/Session methods), wolframscript and the cloud differ.

This skill has no generated scripts (its `"Scripts"` list in the manifest is empty, so it has no `references/Scripts.md`). Besides `SKILL.md` and the shared references, it consists of [hand-authored files](#hand-authored-files) in `AgentSkills/Skills/wolfram-debugging/`:

| File | Description |
| --- | --- |
| `references/Environments.md` | How the MCP evaluator (Local/Session methods), wolframscript and the cloud differ |
| `references/MessagesAndStacks.md` | Messages and stack traces |
| `references/UnevaluatedCalls.md` | Why calls stay unevaluated |
| `references/TracingAndPerformance.md` | Tracing, Trace-free alternatives, profiling, and hangs |
| `references/OverridesAndWatchpoints.md` | Spying on, mocking, and overriding functions; watchpoints |
| `references/DefinitionsAndSource.md` | Finding definitions and source code |
| `references/PackageLoading.md` | Package loading problems |
| `references/Testing.md` | Failing tests |
| `references/ParallelAndAsync.md` | Parallel and asynchronous code |
| `references/CloudAndHTTP.md` | Cloud deployments and HTTP |
| `references/HeadlessAndCrashes.md` | Notebook-only functions, startup differences, crashes, and hard hangs |
| `references/HelperFunctions.md` | The functions of the helper package |
| `scripts/WolframDebugging.wl` | Helper package (context `` WolframDebugging` ``), loaded with `Get` and called with fully qualified names |

The helper package is tested by `Tests/WolframDebuggingSkill.wlt`.

## Built-in Skills

The built skills in `Assets/AgentSkills/` are AgentTools' built-in skills. Each built-in bundle in `$DefaultAgentTools` pairs its MCP server with some of them:

| Bundle | Agent skills |
| --- | --- |
| `Wolfram` | wolfram-language, wolfram-alpha, wolfram-debugging |
| `WolframAlpha` | wolfram-alpha |
| `WolframLanguage` | wolfram-language, wolfram-notebooks, wolfram-paclets, wolfram-debugging |
| `WolframPacletDevelopment` | wolfram-language, wolfram-notebooks, wolfram-paclets, wolfram-debugging |

`$defaultAgentSkills` (`Kernel/AgentSkills.wl`) maps each skill name to its directory in the loaded paclet (`File[<AssetLocation "AgentSkills">/<name>]`). The directory is looked up when the skill is used, so nothing machine-specific is stored in the MX file. A bare skill name such as `"wolfram-language"` refers to a built-in skill wherever skills are accepted (`AgentToolsObject`, `InstallAgentSkills`). An unknown name fails with `AgentSkillNotFound`, and a built-in skill whose directory is missing from the installed paclet fails with `BuiltInAgentSkillMissing`.

A built-in skill's source identifier is its name, and its version is the version of the loaded AgentTools paclet, not the `metadata.version` in its `SKILL.md`. As a result:

- **Updates are automatic.** After a paclet update, a deployment replaces unmodified copies that earlier deployments installed, even copies that other deployments share, without `OverwriteTarget` (no `AgentSkillUpdate` conflict; replacing an existing deployment for the same client and location still needs `OverwriteTarget -> True`). A newer copy that another deployment still uses is never downgraded (`AgentSkillNewerVersionKept`).
- **Conflicts don't fail a built-in bundle.** If a skill directory with the same name and different content already exists (installed by hand or by another tool, modified after it was deployed, or belonging to a different skill), the built-in bundle leaves it untouched, deploys everything else, and issues `DeployAgentTools::AgentSkillNotInstalled` for each skipped skill. Only if that would leave nothing to deploy (e.g. a project target without project MCP support where every skill conflicts) does the conflict fail the deployment, as for other bundles. `OverwriteTarget -> All` replaces such directories.
- **Clients without skills get only the server.** On targets without a skills directory, a built-in bundle installs only its MCP server and issues no `AgentSkillsNotDeployed` warning.

See [agent-tools-objects.md](agent-tools-objects.md#built-in-bundles) for details.

## Directory Structure

The sources in `AgentSkills/` are hand-authored:

```
AgentSkills/
├── Manifest.wl                              # Tool-to-skill mapping
├── References/                              # Shared reference sources
│   ├── GetWolframEngine.md
│   └── SetUpWolframMCPServer.md
└── Skills/
    ├── wolfram-alpha/
    │   └── SKILL.md                         # Hand-authored skill instructions
    ├── wolfram-debugging/
    │   ├── SKILL.md
    │   ├── references/                      # Optional hand-authored files, copied by the build
    │   │   ├── CloudAndHTTP.md
    │   │   └── ...
    │   └── scripts/
    │       └── WolframDebugging.wl
    ├── wolfram-language/
    │   └── SKILL.md
    ├── wolfram-notebooks/
    │   └── SKILL.md
    └── wolfram-paclets/
        └── SKILL.md
```

The build writes the complete skills to `Assets/AgentSkills/` (generated; do not edit these files manually):

```
Assets/AgentSkills/
├── wolfram-alpha/
│   ├── SKILL.md                             # Source SKILL.md with metadata.version stamped
│   ├── references/                          # Copied/generated by build
│   │   ├── GetWolframEngine.md
│   │   ├── Scripts.md
│   │   └── SetUpWolframMCPServer.md
│   └── scripts/                             # Generated by build
│       ├── WolframAlphaContext.wls
│       └── WolframAlpha.wls
├── wolfram-debugging/                       # A skill without generated scripts
│   ├── SKILL.md
│   ├── references/                          # Hand-authored and shared references (no Scripts.md)
│   │   ├── CloudAndHTTP.md
│   │   ├── ...
│   │   ├── GetWolframEngine.md
│   │   └── SetUpWolframMCPServer.md
│   └── scripts/                             # Copied from the source skill directory
│       └── WolframDebugging.wl
├── wolfram-language/
│   ├── SKILL.md
│   ├── references/
│   │   └── ...                              # The same three files in every skill with scripts
│   └── scripts/
│       ├── WolframLanguageContext.wls
│       ├── WolframLanguageEvaluator.wls
│       ├── SymbolDefinition.wls
│       ├── TestReport.wls
│       └── CodeInspector.wls
├── wolfram-notebooks/
│   ├── SKILL.md
│   ├── references/
│   └── scripts/
│       ├── ReadNotebook.wls
│       └── WriteNotebook.wls
└── wolfram-paclets/
    ├── SKILL.md
    ├── references/
    └── scripts/
        ├── CheckPaclet.wls
        ├── BuildPaclet.wls
        └── SubmitPaclet.wls
```

| Path | Description |
| --- | --- |
| `AgentSkills/Manifest.wl` | Maps skill names to their tool lists and shared references |
| `AgentSkills/References/` | Single-source reference files copied into every built skill at build time |
| `AgentSkills/Skills/<name>/SKILL.md` | Hand-authored skill instructions following the [Agent Skills spec](https://agentskills.io/specification), without a `version` |
| `AgentSkills/Skills/<name>/references/`, `AgentSkills/Skills/<name>/scripts/` | Optional [hand-authored files](#hand-authored-files) of the skill |
| `Assets/AgentSkills/<name>/` | The built skill: committed, and shipped with the paclet as the `"AgentSkills"` asset |
| `Assets/AgentSkills/<name>/SKILL.md` | The source `SKILL.md` with `metadata.version` set to the paclet version of the build |
| `Assets/AgentSkills/<name>/scripts/` | Generated `.wls` scripts — one per tool — plus the hand-authored scripts |
| `Assets/AgentSkills/<name>/references/` | Copied reference files, a generated `Scripts.md` (if the skill has generated scripts), and the hand-authored references |

## Key Files

### Manifest.wl

The manifest at `AgentSkills/Manifest.wl` is an `Association` mapping each skill name to its references and scripts:

```wl
<|
    "wolfram-alpha" -> <|
        "References" -> {
            "GetWolframEngine",
            "SetUpWolframMCPServer"
        },
        "Scripts" -> {
            "WolframAlphaContext",
            "WolframAlpha"
        }
    |>,
    "wolfram-debugging" -> <|
        "References" -> { ... },
        "Scripts" -> { }
    |>,
    "wolfram-language" -> <|
        "References" -> { ... },
        "Scripts" -> { ... }
    |>,
    "wolfram-paclets" -> <|
        "References" -> { ... },
        "Scripts" -> { ... }
    |>,
    "wolfram-notebooks" -> <|
        "References" -> { ... },
        "Scripts" -> { ... }
    |>
|>
```

Each key under `"Scripts"` must match a tool name in `$DefaultMCPTools`. Each key under `"References"` must match a `.md` file (without extension) in `AgentSkills/References/` (`Scripts` is reserved for the generated reference). A skill's `"Scripts"` list may be empty, as for `wolfram-debugging`; the build then generates no scripts and no `references/Scripts.md` for it. Every skill in the manifest needs a directory `AgentSkills/Skills/<name>/` that contains its `SKILL.md` and, optionally, [hand-authored files](#hand-authored-files) in `references/` and `scripts/`, and `AgentSkills/Skills/` may not contain anything else; the build fails otherwise.

### SKILL.md Format

Each skill has a hand-authored `SKILL.md` with YAML frontmatter and markdown instructions, following the [Agent Skills specification](https://agentskills.io/specification).

**Frontmatter fields:**

| Field | Required | Description |
| --- | --- | --- |
| `name` | Yes | Lowercase letters, numbers, and hyphens. Must match the parent directory name. Max 64 characters. |
| `description` | Yes | What the skill does and when to use it. Max 1024 characters. |
| `compatibility` | No | Environment requirements (max 500 characters). |
| `license` | No | License name or reference to a bundled license file. |
| `metadata` | No | Arbitrary key-value pairs (e.g., `author`). Leave out `version`: the build adds `metadata.version` to the built copy. |
| `allowed-tools` | No | Space-delimited list of pre-approved tools (experimental). |

**Content structure:** Each SKILL.md follows this general outline:

1. **Title** — `# <Skill Title>`
2. **Prerequisites** — Points the agent to `references/GetWolframEngine.md`
3. **Usage** — Dual-mode instructions: MCP tools (preferred) and bundled scripts (fallback)
4. **Available Tools** — Summary table of scripts with per-tool guidance
5. **Tips** — High-level guidance for effective use

See `AgentSkills/Skills/wolfram-language/SKILL.md` for a complete example.

### Script Template

Generated scripts follow the template at `Scripts/Resources/SkillScriptTemplate.wls`. The template:

1. Parses CLI arguments (positional for required params, `--flag value` for optional)
2. Supports `--usage` to print help text and exit
3. Installs and loads the AgentTools paclet
4. Looks up the tool in `$DefaultMCPTools` and invokes it
5. Writes the result to stdout and exits with code 0 (success) or 1 (failure)
6. Replaces any inline data-URI images with `[Image: ...]` text placeholders

### Shared Reference Files

Two hand-authored reference files live in `AgentSkills/References/` and are copied into every built skill's `references/` directory (`Assets/AgentSkills/<name>/references/`) at build time:

- **`GetWolframEngine.md`** — Platform-specific installation instructions for `wolframscript` (macOS via Homebrew, Linux/Windows downloads, activation).
- **`SetUpWolframMCPServer.md`** — How to set up a Wolfram MCP server: the local server, installed with `DeployAgentTools` (MCP server plus agent skills; `InstallMCPServer` when only the MCP server is wanted), manual configuration for clients that AgentTools does not support, and the free remote [Wolfram Cloud MCP](https://www.wolfram.com/artificial-intelligence/mcp/cloud/wolfram-mcp-cloud) server at `https://agenttools.wolfram.com/mcp` (no API key).

A third reference, **`Scripts.md`**, is generated per-skill by the build system from tool metadata. It contains usage syntax and argument tables for every script in that skill. Skills without generated scripts don't have it.

### Hand-Authored Files

Besides `SKILL.md`, a source skill directory may contain hand-authored files that only this skill uses, directly in its `references/` and `scripts/` subdirectories: for example, topic references or a helper package that its `SKILL.md` points to (`wolfram-debugging` has both). The build copies them into the same subdirectories of the built skill (`Assets/AgentSkills/<name>/references/`, `Assets/AgentSkills/<name>/scripts/`):

- They must be valid UTF-8 text. Like the other text files, they are copied with any byte order mark removed and line endings normalized to LF.
- They must be flat: no subdirectories, and names must match the regular expression `[A-Za-z0-9][A-Za-z0-9._-]*`. Anything else in a source skill directory (other files or directories next to `SKILL.md`, nested directories, or other names) fails the build with `UnexpectedSkillFiles`.
- A hand-authored file may not have the same path, compared case-insensitively, as a file that the build generates for the skill: a generated `scripts/<Tool>.wls`, a shared reference copied from `AgentSkills/References/`, or `references/Scripts.md`, which is reserved even for skills without generated scripts. A collision fails the build with `SkillFileConflict`.
- Two hand-authored files of a skill may not have paths that differ only in case (such as `references/Notes.md` and `references/notes.md`), since they would overwrite each other when the skill is installed on a case-insensitive file system. This fails the build with `SkillFileCaseConflict`.

Hand-authored scripts are not generated from MCP tools and are not described in `references/Scripts.md`, so the skill's `SKILL.md` has to explain how to use them.

## Adding a New Skill

This section walks through creating a new skill from scratch. We'll use a hypothetical `wolfram-data` skill as an example.

### Step 1: Ensure the MCP Tools Exist

Every generated script in a skill corresponds to a tool in `$DefaultMCPTools`. Before creating a skill, verify that the tools you want to include are already defined and working. See [tools.md](tools.md) for how to add new tools. A skill without tools (an empty `"Scripts"` list, like `wolfram-debugging`) skips this step.

```wl
(* Check that the tool exists *)
$DefaultMCPTools["YourToolName"]
```

### Step 2: Add to Manifest.wl

Edit `AgentSkills/Manifest.wl` to add your new skill. The key must be a valid skill name (lowercase letters, numbers, hyphens):

```wl
<|
    (* ... existing skills ... *)
    "wolfram-data" -> <|
        "References" -> {
            "GetWolframEngine",
            "SetUpWolframMCPServer"
        },
        "Scripts" -> {
            "DataRepositorySearch",
            "ResourceObject"
        }
    |>
|>
```

Each entry in `"Scripts"` must exactly match a key in `$DefaultMCPTools`. A mismatch causes the build to fail with `The tool <name> does not exist.`

### Step 3: Create SKILL.md

Create `AgentSkills/Skills/wolfram-data/SKILL.md`. Here is a template you can copy and adapt:

```markdown
---
name: wolfram-data
description: >
  Searches and retrieves data from the Wolfram Data Repository.
  Use this skill when the user needs curated datasets for analysis,
  visualization, or computation.
compatibility: Requires the Wolfram MCP server or wolframscript on PATH
metadata:
  author: Wolfram Research
---

# Wolfram Data

Search and retrieve curated datasets from the Wolfram Data Repository.

## Prerequisites

These scripts require `wolframscript`. If it is not installed or not on
your PATH, read `references/GetWolframEngine.md` (relative to this
skill directory) for installation instructions.

## Usage

### With MCP Server (preferred)

If you have Wolfram MCP tools available in your tool list (e.g.,
`mcp__Wolfram__DataRepositorySearch`), use those directly.
They provide richer integration and better performance than the
bundled scripts.

For a richer experience, consider setting up the Wolfram MCP server.
See `references/SetUpWolframMCPServer.md` (relative to this skill
directory) for instructions.

### With Bundled Scripts

If no MCP tools are available, use the bundled scripts in the
`scripts/` directory (relative to this skill directory). Run them with:

    wolframscript -f scripts/<ScriptName>.wls <arguments>

Pass `--usage` to any script to see its argument documentation:

    wolframscript -f scripts/<ScriptName>.wls --usage

For detailed usage, arguments, and invocation syntax for each script,
see `references/Scripts.md` (relative to this skill directory).

Reminder: These scripts are only relevant when you do not have the
equivalent MCP tool available.

## Available Tools

| Script | When to use |
| --- | --- |
| `DataRepositorySearch` | Search the Wolfram Data Repository |
| `ResourceObject` | Retrieve a specific dataset by name |

## Other Tips

- Always search before retrieving to find the best dataset for the task.
```

**Key points:**
- The `name` in the frontmatter must match the directory name exactly (the build checks this).
- The `description` should explain both what the skill does and when an agent should use it.
- Don't add a `version` to `metadata`: the build sets `metadata.version` to the paclet version in the built copy (`Assets/AgentSkills/<name>/SKILL.md`), and a test checks that the source files have no version line.
- Besides `SKILL.md`, the source directory may only contain [hand-authored files](#hand-authored-files) directly in `references/` and `scripts/`; the generated scripts and the shared references are added by the build.
- Follow the dual-mode pattern: MCP tools first, bundled scripts as fallback.

### Step 4: Add Shared References (if needed)

If your skill needs a new shared reference file (beyond the standard `GetWolframEngine` and `SetUpWolframMCPServer`):

1. Create the `.md` file in `AgentSkills/References/`.
2. Add its name (without `.md` extension) to the `"References"` list in `Manifest.wl`.

For most skills, the two existing reference files are sufficient. A reference that only your skill needs goes in its source directory instead (`AgentSkills/Skills/wolfram-data/references/`; see [Hand-Authored Files](#hand-authored-files)), and is not listed in `Manifest.wl`.

### Step 5: Run the Build

```bash
wolframscript -f Scripts/BuildAgentSkills.wls
```

This rebuilds all of `Assets/AgentSkills/`, including the new `Assets/AgentSkills/wolfram-data/`:
- `SKILL.md` with `metadata.version` set to the current paclet version
- A generated `.wls` script in `scripts/` for each tool listed in your skill
- The reference files from `AgentSkills/References/` in `references/`
- A generated `references/Scripts.md` from tool metadata (if the skill has generated scripts)
- The hand-authored files from `AgentSkills/Skills/wolfram-data/references/` and `scripts/`, if any

Commit the regenerated `Assets/AgentSkills/` (and `.claude-plugin/marketplace.json`) together with the sources.

Check the console output for errors. Nothing is changed if the build fails. Common issues:
- **`The tool <name> does not exist.`** — The script name in `Manifest.wl` doesn't match any tool. Check for typos and verify the tool exists.
- **`The reference file <path> does not exist.`** — A reference name in `Manifest.wl` doesn't match any `.md` file in `AgentSkills/References/`.
- **`Plugin "..." lists skill "...", which is not a built skill directory with a SKILL.md.`** — A skill listed in `marketplace.json` is not in the manifest.
- **`The source directory <dir> of skill <name> must contain only SKILL.md and hand-authored files in its references and scripts directories ...`** (`UnexpectedSkillFiles`) — The source skill directory contains something other than `SKILL.md` and flat, simply named files in `references/` and `scripts/`.
- **`The hand-authored files <files> of skill <name> have the same paths as files that the build generates.`** (`SkillFileConflict`) — Rename the hand-authored file; paths are compared ignoring case.
- **`The hand-authored files <files> of skill <name> have paths that differ only in case.`** (`SkillFileCaseConflict`) — Rename or merge the files.

### Step 6: Test the Skill

After building, verify the generated scripts work:

```bash
# Check that --usage works for each generated script
wolframscript -f Assets/AgentSkills/wolfram-data/scripts/DataRepositorySearch.wls --usage

# Run a script with sample arguments
wolframscript -f Assets/AgentSkills/wolfram-data/scripts/DataRepositorySearch.wls "sample data"
```

Also verify:
- `SKILL.md` frontmatter is valid YAML
- All files referenced in `SKILL.md` exist (e.g., `references/GetWolframEngine.md` in `Assets/AgentSkills/wolfram-data/`)
- The `references/Scripts.md` was generated and contains entries for all generated scripts

### Step 7: Add to Plugin Packaging

Add the skill to a plugin in `.claude-plugin/marketplace.json` so that it is distributed via Claude Code; `Tests/AgentSkillsBuild.wlt` expects every skill to be listed in a plugin. See [Plugin Packaging](#plugin-packaging) below.

### Step 8: Register the Built-in Skill

1. Add the skill to `$defaultAgentSkills` in `Kernel/AgentSkills.wl` (`"wolfram-data" :> builtInSkillDirectory["wolfram-data"]`). `Tests/AgentSkillsBuild.wlt` checks that the manifest, `AgentSkills/Skills/`, `Assets/AgentSkills/`, and `$defaultAgentSkills` all list the same skills.
2. If a built-in bundle should deploy the skill, add its name to the bundle's `"AgentSkills"` in `$defaultAgentTools` (`Kernel/AgentToolsObject.wl`).
3. Update the expected skill names and plugin contents in `Tests/AgentSkillsBuild.wlt` (`$expectedSkillNames`, `Marketplace-PluginSkills`), and the bundle tests if you changed a bundle.

## Build System

### How It Works

The build has two parts:

- **`Scripts/Resources/AgentSkillsBuilder.wl`** — The builder (context `` Wolfram`AgentSkillsBuilder` ``), a self-contained file that is loaded with `Get` (by default it takes the tool definitions from `$DefaultMCPTools`, so AgentTools must be loaded too). It never calls `Exit`, never writes outside the output directory it is given, and returns a `Failure` on errors. It reads every source relative to an explicit source directory (the repository root), so it also works when AgentTools itself is loaded from an MX build without `Scripts/` or `AgentSkills/`.
- **`Scripts/BuildAgentSkills.wls`** — The command-line wrapper that builds `Assets/AgentSkills/` and updates `.claude-plugin/marketplace.json`.

`Scripts/BuildAgentSkills.wls` works as follows:

1. **Load paclet** — Loads the AgentTools paclet from the checkout via `PacletDirectoryLoad` + ``Get["Wolfram`AgentTools`"]`` (failing if the context resolves to another copy of AgentTools), then loads the builder.
2. **Build into a staging directory** — `buildAgentSkills[repoDir, stagingDir, pacletVersion]` validates the manifest and source skill directories, then for each skill:
   - Generates a `.wls` script for each of its tools from `$DefaultMCPTools` (parameter names, required/optional, help text) and `Scripts/Resources/SkillScriptTemplate.wls`
   - Copies the shared reference files from `AgentSkills/References/` into `references/`
   - Generates `references/Scripts.md` from the tool metadata, if the skill has tools
   - Copies `SKILL.md`, setting `metadata.version` to the paclet version
   - Copies the [hand-authored files](#hand-authored-files) from the source skill's `references/` and `scripts/`, after checking that none of them has the path of a generated file

   All inputs are validated and all content is generated before anything is written.
3. **Validate the marketplace** — Every plugin in `.claude-plugin/marketplace.json` must have the source `./Assets/AgentSkills` and list only built skills.
4. **Replace `Assets/AgentSkills/`** — Replaces the directory with the staging directory and verifies the copy.
5. **Update marketplace version** — Sets `metadata.version` in `.claude-plugin/marketplace.json` to the paclet version.
6. **Clean up** — Removes the staging directory.

### Running the Build

```bash
# Rebuild Assets/AgentSkills and update the marketplace version
wolframscript -f Scripts/BuildAgentSkills.wls

# Check that Assets/AgentSkills is up to date, without changing anything
wolframscript -f Scripts/BuildAgentSkills.wls --check
```

`--check` builds into a temporary directory with the version of the committed skills (their shared `metadata.version`), compares the result with `Assets/AgentSkills/` (ignoring line-ending differences), checks the marketplace plugins and version, and exits with code 1 if anything is out of date.

Rebuild and commit `Assets/AgentSkills/` whenever you change anything in `AgentSkills/`, `Scripts/Resources/SkillScriptTemplate.wls`, or a tool that a skill uses. The test `CommittedSkills-UpToDate` in `Tests/AgentSkillsBuild.wlt` rebuilds the skills with the committed version, like `--check`, and fails when the committed skills are stale; other tests in that file check the source directories, the marketplace, and the paclet's `"AgentSkills"` asset. The committed version is the paclet version of the last skill build, so it can lag behind the paclet version.

### Builder Functions

All in the `` Wolfram`AgentSkillsBuilder` `` context:

| Function | Description |
| --- | --- |
| `buildAgentSkills[sourceDir, outputDir, version, opts]` | Builds every skill in the manifest into `outputDir`, which must not exist or must be empty. Returns `Success["AgentSkillsBuilt", <\|..., "Directory", "Version", "Skills", "Files"\|>]` or a `Failure`. Options: `"Tools"` (default `$DefaultMCPTools`) and `"LogFunction"` (default `None`). |
| `agentSkillsDifferences[expectedDir, actualDir]` | Compares two skill trees: `<\|"Missing" -> {...}, "Extra" -> {...}, "Different" -> {...}\|>` of relative paths, all empty when the trees match (line endings are normalized) |
| `agentSkillsVersion[dir]` | The `metadata.version` shared by all `SKILL.md` files of a built tree, or a `Failure` |
| `stampSkillVersion[markdown, version]` | Sets `metadata.version` in the YAML frontmatter of a `SKILL.md` string |

Pass the repository checkout as `sourceDir`, never the location of the loaded paclet: CI runs the tests against an MX build in `build/` that has no `Scripts/` or `AgentSkills/` directories. Tests derive the checkout from `DirectoryName[$TestFileName, 2]`.

### What It Does NOT Do

- Does not generate `SKILL.md` content — those are hand-authored. It copies them and only adds `metadata.version`.
- Does not generate or change the content of hand-authored references and scripts. It copies them with only the text normalization (no byte order mark, LF line endings).
- Does not create new plugins or restructure `marketplace.json` — it only updates the version field.
- Does not install or publish skills. `DeployAgentTools` installs the built skills from the paclet, and Claude Code plugins read them from the repository.

### Generated Script Structure

Each generated script follows this pattern:

1. **Argument parsing** — Positional args for required parameters, `--flag value` pairs for optional parameters. All values are strings (matching MCP tool behavior).
2. **`--usage` flag** — Prints usage and help text, then exits with code 0.
3. **Paclet loading** — `PacletInstall["Wolfram/AgentTools"]` + ``Get["Wolfram`AgentTools`"]``.
4. **Tool invocation** — Looks up the tool in `$DefaultMCPTools` and calls it with the parsed arguments.
5. **Output** — Writes the result string to stdout. Inline data-URI images are replaced with `[Image: ...]` placeholders.
6. **Exit code** — 0 on success, 1 on failure or missing arguments.

**Example CLI usage:**

```
wolframscript -f TestReport.wls <paths> [--timeConstraint N] [--memoryConstraint N] [--newKernel true|false]
wolframscript -f CodeInspector.wls [--code "..."] [--file "..."] [--severityExclusions "..."]
```

## Plugin Packaging

For distribution via **Claude Code**, skills are packaged into plugins defined by `.claude-plugin/marketplace.json`.

### marketplace.json Structure

The marketplace file lives at `.claude-plugin/marketplace.json` in the repository root. It defines a marketplace named `wolfram-agent-skills` with individual plugins that bundle one or more skills. Every plugin's `source` is the built skills directory `./Assets/AgentSkills` (the build checks this):

```json
{
  "name": "wolfram-agent-skills",
  "owner": {
    "name": "Richard Hennigan",
    "email": "richardh@wolfram.com"
  },
  "metadata": {
    "description": "A collection of Wolfram agent skills",
    "version": "1.7.21"
  },
  "plugins": [
    {
      "name": "wolfram-language-development",
      "description": "A full Wolfram Language development environment...",
      "source": "./Assets/AgentSkills",
      "strict": false,
      "skills": [
        "./wolfram-language",
        "./wolfram-debugging",
        "./wolfram-notebooks",
        "./wolfram-paclets"
      ]
    },
    {
      "name": "wolfram-alpha",
      "description": "Wolfram|Alpha queries and context retrieval.",
      "source": "./Assets/AgentSkills",
      "strict": false,
      "skills": [
        "./wolfram-alpha"
      ]
    }
  ]
}
```

### Current Plugins

| Plugin | Skills Included | Description |
| --- | --- | --- |
| `wolfram-language-development` | wolfram-language, wolfram-debugging, wolfram-notebooks, wolfram-paclets | Full Wolfram Language development environment, including debugging |
| `wolfram-alpha` | wolfram-alpha | Wolfram\|Alpha queries and context retrieval |

### Installation

Users add the marketplace, then install individual plugins:

```
/plugin marketplace add <owner/repo>
/plugin install wolfram-language-development@wolfram-agent-skills
/plugin install wolfram-alpha@wolfram-agent-skills
```

A project can also pre-configure the marketplace in `.claude/settings.json` using `extraKnownMarketplaces`, so team members are automatically prompted to install.

### Adding a Skill to a Plugin

To include a new skill in an existing plugin, add its relative path to the plugin's `"skills"` array in `marketplace.json`:

```json
{
  "name": "wolfram-language-development",
  "source": "./Assets/AgentSkills",
  "strict": false,
  "skills": [
    "./wolfram-language",
    "./wolfram-debugging",
    "./wolfram-notebooks",
    "./wolfram-paclets",
    "./wolfram-data"
  ]
}
```

To create a new plugin for the skill, add a new entry to the `"plugins"` array:

```json
{
  "name": "wolfram-data",
  "description": "Search and retrieve curated datasets from the Wolfram Data Repository.",
  "source": "./Assets/AgentSkills",
  "strict": false,
  "skills": [
    "./wolfram-data"
  ]
}
```

Since these plugins don't have their own `plugin.json`, `"strict"` must be set to `false`.

## Related Files

- `AgentSkills/Manifest.wl` — Tool-to-skill mapping
- `AgentSkills/References/GetWolframEngine.md` — Shared reference: installing wolframscript
- `AgentSkills/References/SetUpWolframMCPServer.md` — Shared reference: MCP server setup
- `AgentSkills/Skills/*/SKILL.md` — Hand-authored skill instructions
- `AgentSkills/Skills/*/references/`, `AgentSkills/Skills/*/scripts/` — Optional hand-authored skill files (e.g. the `wolfram-debugging` topic references and helper package)
- `Assets/AgentSkills/` — The built skills (generated; committed and shipped with the paclet)
- `PacletInfo.wl` — Declares `Assets/AgentSkills` as the `"AgentSkills"` asset
- `Scripts/BuildAgentSkills.wls` — Command-line build (and `--check`) of `Assets/AgentSkills/`
- `Scripts/Resources/AgentSkillsBuilder.wl` — The loadable skill builder
- `Scripts/Resources/SkillScriptTemplate.wls` — Template used to generate `.wls` scripts
- `Kernel/AgentSkills.wl` — `$defaultAgentSkills` (the built-in skill registry)
- `Kernel/AgentToolsObject.wl` — `$defaultAgentTools` (the built-in bundles and their skills)
- `Tests/AgentSkillsBuild.wlt` — Staleness, source, marketplace, and packaging tests for the built skills, and build tests (including hand-authored files)
- `Tests/WolframDebuggingSkill.wlt` — Tests for the `wolfram-debugging` helper package
- `.claude-plugin/marketplace.json` — Claude Code plugin packaging
- `Specs/AgentSkills.md` — Full design specification
- `docs/tools.md` — MCP tools system (prerequisite for adding tools to skills)
