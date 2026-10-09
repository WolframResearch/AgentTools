# Building the Paclet

This guide covers how to build AgentTools for distribution.

## Basic Build

Build the paclet using:

```bash
wolframscript -f Scripts/BuildPaclet.wls
```

This script builds the paclet and performs necessary checks.

## Build Options

| Option | Description | Default |
|--------|-------------|---------|
| `--check` | Run code checks | `true` |
| `--install` | Install the paclet after building | `false` |
| `--mx` | Build MX files | `true` |

## Examples

Build and install:

```bash
wolframscript -f Scripts/BuildPaclet.wls --install=true
```

Build without code checks (faster, for quick iteration):

```bash
wolframscript -f Scripts/BuildPaclet.wls --check=false
```

Build without MX file:

```bash
wolframscript -f Scripts/BuildPaclet.wls --mx=false
```

## Build Output

The built paclet will be placed in the `build/` directory. The output includes:

- The `.paclet` file for distribution
- MX files (unless disabled) for faster loading
- The built agent skills, from the committed `Assets/AgentSkills/` (the paclet's `"AgentSkills"` asset)

## MX Files

MX files are pre-compiled versions of the paclet that load faster. During the MX build, error handling tags are also rewritten to include source file locations for easier debugging (see [Error Handling - Modified Definition](error-handling.md#modified-definition)).

During development, you may want to:

- **Disable MX building** with `--mx=false` for faster build iterations
- **Delete existing MX files** (`Kernel/64Bit/AgentTools.mx`) when testing source changes

See [Getting Started](getting-started.md#important-mx-files) for more details on MX files during development.

## Resource Functions and Offline Builds

The paclet uses a few functions from the Wolfram Function Repository, pinned to the versions in `$resourceVersions` in `Kernel/Common.wl`. Their definitions are also kept as local copies in `ResourceFunctions/` (one `.wl` file per function, each wrapped in `BeginPackage`/`EndPackage` for the context ``Wolfram`AgentTools`ResourceFunctions`<Name>` ``). `importResourceFunction` prefers a local copy and only falls back to fetching the resource function when there is none, so:

- The MX build inlines the local definitions and does not need cloud access. `Scripts/BuildMX.wls` copies `ResourceFunctions/` into the temporary build copy of the paclet and uses the local `ASTPattern` for the source annotations it inserts.
- Loading the paclet from source loads a local copy at the first use of the imported symbol. If a resource function has no local copy and cannot be fetched either, the imported symbol becomes a placeholder that fails with `AgentTools::ResourceFunctionUnavailable` when used, and the import is retried on the next use instead of caching the failure.

The directory is not declared in `PacletInfo.wl` and is not part of the built paclet. See [ResourceFunctions/README.md](../ResourceFunctions/README.md) for the provenance of each copy and how to update one when a pinned version changes.

## Building Agent Skills

Agent skills are built separately from the paclet, and the built skills are committed to the repository. The build script reads the sources in `AgentSkills/`, generates `.wls` scripts from MCP tool definitions, and writes complete skill directories (`SKILL.md`, `scripts/`, `references/`) to `Assets/AgentSkills/`:

```bash
wolframscript -f Scripts/BuildAgentSkills.wls
```

This generates the scripts and `references/Scripts.md`, copies the shared references and any hand-authored `references/` and `scripts/` files of a skill, copies each hand-authored `SKILL.md` with the paclet version stamped into its `metadata.version`, updates the version in `.claude-plugin/marketplace.json`, and cleans up temporary files. The build itself is implemented in `Scripts/Resources/AgentSkillsBuilder.wl`.

`PacletInfo.wl` declares `Assets/AgentSkills` as the `"AgentSkills"` asset, so the paclet build ships whatever is committed there; `BuildPaclet.wls` does not rebuild the skills. Rebuild and commit `Assets/AgentSkills/` after changing `AgentSkills/`, `Scripts/Resources/SkillScriptTemplate.wls`, or a tool that a skill uses. To check whether the committed skills are up to date without changing anything:

```bash
wolframscript -f Scripts/BuildAgentSkills.wls --check
```

The test `CommittedSkills-UpToDate` in `Tests/AgentSkillsBuild.wlt` makes the same check.

See [agent-skills.md](agent-skills.md) for full details on the agent skills system and build process.

## See Also

- [Getting Started](getting-started.md) - Development environment setup
- [Testing](testing.md) - Writing and running tests
- [Error Handling](error-handling.md) - Error handling architecture and patterns
- [Agent Skills](agent-skills.md) - Building and distributing agent skills
- [AGENTS.md](../AGENTS.md) - Detailed development guidelines
