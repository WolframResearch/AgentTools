---
name: wolfram-alpha
description: Queries Wolfram|Alpha for up-to-date computational results and retrieves contextual information via semantic search. Use this skill when the user needs real-world data, calculations, or factual answers about entities in science, math, geography, history, finance, and more.
compatibility: Requires the Wolfram MCP server or wolframscript on PATH
metadata:
  author: Wolfram Research
  version: 2.1.24
---

# Wolfram|Alpha

Query Wolfram|Alpha for computational answers and retrieve contextual information using semantic search.

## Prerequisites

These scripts require `wolframscript`. If it is not installed or not on your PATH, read `references/GetWolframEngine.md` (relative to this skill directory) for installation instructions.

## Usage

### With MCP Server (preferred)

If you have Wolfram|Alpha MCP tools available in your tool list (e.g., `mcp__WolframLanguage__WolframAlpha`), use those directly. They provide richer integration and better performance than the bundled scripts.

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
| `WolframAlphaContext` | Retrieve contextual information about a topic via semantic search |
| `WolframAlpha` | Query Wolfram\|Alpha for computational answers and real-world data |

### WolframAlphaContext

Always use `WolframAlphaContext` as a first step before querying `WolframAlpha`. It uses semantic search to retrieve relevant background information and helps ensure you have up-to-date context. The `context` argument should be written in natural language (not as a search query) and be as detailed as possible (up to 250 words).

If your MCP server provides a `WolframContext` tool, you can use that instead of `WolframAlphaContext`. It's effectively equivalent, except it may include additional context from Wolfram Language documentation.

### WolframAlpha

Use `WolframAlpha` for natural language queries that need computational answers or real-world data. This is especially useful for questions about:

- Mathematics (equations, calculus, algebra, statistics)
- Science (physics, chemistry, biology, astronomy)
- Geography and demographics
- History and culture
- Finance and economics
- Unit conversions and comparisons
- Weather, dates, and time zones

Queries should be phrased in natural language, similar to how you would ask a question. For example: `"population of France"`, `"integrate sin(x) from 0 to pi"`, `"distance from Earth to Mars"`.

## Other Tips

- Always call `WolframAlphaContext` before `WolframAlpha` to ensure you have the most up-to-date context for your query.
- If a query returns unexpected results, try rephrasing it or being more specific.
- For complex mathematical expressions, use standard notation that Wolfram|Alpha understands (e.g., `sin(x)`, `x^2`, `sqrt(x)`).
