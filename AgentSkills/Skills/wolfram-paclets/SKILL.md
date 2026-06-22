---
name: wolfram-paclets
description: Checks, builds, and submits Wolfram Language paclets. Use this skill when working on paclet packaging, release readiness, and paclet repository submission workflows.
compatibility: Requires the Wolfram MCP server or wolframscript on PATH
metadata:
  author: Wolfram Research
  version: 2.1.24
---

# Wolfram Paclets

Paclet development and release workflow tools for checking, building, and submitting Wolfram Language paclets.

## Prerequisites

These scripts require `wolframscript`. If it is not installed or not on your PATH, read `references/GetWolframEngine.md` (relative to this skill directory) for installation instructions.

## Usage

### With MCP Server (preferred)

If you have Wolfram paclet tools available in your tool list (e.g., `mcp__WolframLanguage__CheckPaclet`), use those directly. They provide richer integration and better performance than the bundled scripts.

For a richer experience, consider setting up the Wolfram MCP server. See `references/SetUpWolframMCPServer.md` (relative to this skill directory) for instructions.

### With Bundled Scripts

If no MCP tools are available, use the bundled scripts in the `scripts/` directory (relative to this skill directory). Run them with:

```
wolframscript -f scripts/<ScriptName>.wls <arguments>
```

Pass `--usage` to any script to see its argument documentation:

```
wolframscript -f scripts/<ScriptName>.wls --usage
```

For detailed usage, arguments, and invocation syntax for each script, see `references/Scripts.md` (relative to this skill directory).

Reminder: These scripts are only relevant when you do not have the equivalent MCP tool available.

## Available Tools


| Script | When to use |
| --- | --- |
| `CheckPaclet` | Check a paclet for issues before building or submitting |
| `BuildPaclet` | Build a `.paclet` archive from a paclet directory |
| `SubmitPaclet` | Submit a paclet to the Wolfram Language Paclet Repository |


### CheckPaclet

Use `CheckPaclet` before building or submitting a paclet. It reports errors, warnings, and suggestions organized by severity. The path should be an absolute path to the paclet root directory or the definition notebook (`.nb`) file.

### BuildPaclet

Use `BuildPaclet` to produce a `.paclet` archive. Optionally pass `--check true` to run `CheckPaclet` before building. The build is aborted if errors are found.

### SubmitPaclet

Use `SubmitPaclet` to submit a paclet to the Wolfram Language Paclet Repository. This builds the paclet internally before submitting. Requires prior authentication via `$PublisherID` or an active Wolfram Cloud connection. Use `CheckPaclet` first to verify readiness.

## Other Tips

- Run `CheckPaclet` first, then `BuildPaclet`, and only then `SubmitPaclet` for a reliable release flow.
