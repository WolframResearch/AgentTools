---
name: wolfram-language
description: Evaluates Wolfram Language code, searches documentation, inspects code, runs tests, and retrieves symbol definitions. Use this skill when the user needs Wolfram Language computation or development assistance, including symbolic math, data analysis, visualization, or working with .wl/.wls/.wlt files.
compatibility: Requires the Wolfram MCP server or wolframscript on PATH
metadata:
  author: Wolfram Research
  version: 2.1.24
---

# Wolfram Language

A full Wolfram Language development environment with code evaluation, documentation search, symbol inspection, static analysis, and test execution.

## Prerequisites

These scripts require `wolframscript`. If it is not installed or not on your PATH, read `references/GetWolframEngine.md` (relative to this skill directory) for installation instructions.

## Usage

### With MCP Server (preferred)

If you have Wolfram Language MCP tools available in your tool list (e.g., `mcp__WolframLanguage__WolframLanguageEvaluator`), use those directly. They provide richer integration, stateful evaluation, and better performance than the bundled scripts.

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
| `WolframLanguageContext` | Agentic search for documentation and other Wolfram Language resources |
| `WolframLanguageEvaluator` | Evaluate Wolfram Language code and return results |
| `SymbolDefinition` | Inspect how symbols are defined |
| `TestReport` | Run `.wlt` test files and directories to verify correctness |
| `CodeInspector` | Check Wolfram Language code or files for issues and style problems |


### WolframLanguageContext

If your MCP server provides a `WolframContext` tool instead of `WolframLanguageContext`, you can use that instead. It's effectively equivalent, except it may include additional context from Wolfram Alpha.

You should almost always search with `WolframLanguageContext` as a first step. It searches a variety of sources, including documentation, the Wolfram Function Repository, Data Repository, Neural Net Repository, Paclet Repository, and more. Even if you're very familiar with Wolfram Language, it's a good idea to search first because there may be a new `ResourceFunction`, paclet, etc. that does what you need.

The `context` argument should be as specific as possible, but avoid mentioning specific code that's only defined in the codebase you're working on, since it only knows about publicly available resources.

### WolframLanguageEvaluator

If you have access to this tool via a local MCP server, evaluations are done in a persistent kernel session. This means that you can evaluate code that modifies global state, such as defining functions, loading packages, and the changes will persist between evaluations. If it's a remote MCP server, or you're using the bundled scripts, the kernel is disposed after each evaluation. This means that you need to redefine functions, load packages, etc. for each evaluation that needs them.

#### Working with Natural Language Input

The `\[FreeformPrompt]` syntax is analogous to ctrl+= input in notebooks. It parses natural language input into Wolfram Language expressions. You should ALWAYS use this natural language input to obtain things like `Quantity`, `Entity`, `EntityClass`, etc.

**Important:** Natural language input is parsed before evaluation, so it works like macro expansion. For example:

```wl
In[1]:= Hold[\[FreeformPrompt]["picture of a cat"]]

Out[1]= Hold[Entity["TaxonomicSpecies", "FelisCatus::ddvt3"][EntityProperty["TaxonomicSpecies", "Image"]]]
```

This means that programmatic uses like the following will NOT work:

```wl
Table[\[FreeformPrompt]["picture of a "<>name], {name, {"cat", "dog"}}]
```

You can use a symbol as the second argument to specify the expected head of the parsed expression:


| Input | Parsed Expression |
| --- | --- |
| `\[FreeformPrompt]["Pennsylvania", Entity]` | `Entity["AdministrativeDivision", {"Pennsylvania", "UnitedStates"}]` |
| `\[FreeformPrompt]["lanthanide elements", EntityClass]` | `EntityClass["Element", "Lanthanide"]` |
| `\[FreeformPrompt]["123 terawatt hours", Quantity]` | `Quantity[123, "Hours"*"Terawatts"]` |


A string as the second argument represents an expected entity type, which can be an `Entity` or `EntityClass`:


| Input | Parsed Expression |
| --- | --- |
| `\[FreeformPrompt]["Mercury", "Planet"]` | `Entity["Planet", "Mercury"]` |
| `\[FreeformPrompt]["Mercury", "MannedSpaceMission"]` | `EntityClass["MannedSpaceMission", "ProjectMercuryMannedMission"]` |


When in doubt, use the single argument form. You'll get feedback about other valid interpretations, which you can then choose from. For example:

```wl
In[2]:= \[FreeformPrompt]["12:00"]

During evaluation of In[2]:= [WARNING] Interpreted "12:00" as TimeObject[{12, 0}] with other possible interpretations:
	ResourceFunction["RatioSimplify"][{12, 0}]
	Quantity[MixedMagnitude[{12, 0}], MixedUnit[{"Minutes", "Seconds"}]]
	TimeObject[{0, 0}]

Out[2]= TimeObject[{12, 0}, "Minute"]
```

### SymbolDefinition

Use `SymbolDefinition` instead of evaluating `Definition` or `DownValues` via the `WolframLanguageEvaluator` tool to inspect symbol definitions. This tool is optimized for producing LLM readable output for definitions. If you have a persistent local kernel for the MCP server, this tool has access to the same kernel session as the `WolframLanguageEvaluator` tool.

### TestReport

If the user has test files for their project (`.wlt` files), you can run them with the `TestReport` tool to get a Markdown formatted report of the test results.

### CodeInspector

If you've edited Wolfram Language files, you should check your work with `CodeInspector`.

## Other Tips

- When using Markdown formatting, you should ALWAYS use double backticks for inline code containing fully qualified symbol names: ``MyContext`MySymbol[x]``
