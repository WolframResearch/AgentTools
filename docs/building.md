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

## Building Agent Skills

Agent skills are built separately from the paclet, and the built skills are committed to the repository. The build script reads the sources in `AgentSkills/`, generates `.wls` scripts from MCP tool definitions, and writes complete skill directories (`SKILL.md`, `scripts/`, `references/`) to `Assets/AgentSkills/`:

```bash
wolframscript -f Scripts/BuildAgentSkills.wls
```

This generates the scripts and `references/Scripts.md`, copies the shared references, copies each hand-authored `SKILL.md` with the paclet version stamped into its `metadata.version`, updates the version in `.claude-plugin/marketplace.json`, and cleans up temporary files. The build itself is implemented in `Scripts/Resources/AgentSkillsBuilder.wl`.

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
