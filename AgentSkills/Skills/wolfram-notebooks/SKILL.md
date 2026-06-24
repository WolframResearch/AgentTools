---
name: wolfram-notebooks
description: Reads and writes Wolfram notebook (.nb) files. Use this skill when the user needs to create, read, or convert Wolfram notebooks, including converting between markdown and notebook format.
compatibility: Requires the Wolfram MCP server or wolframscript on PATH
metadata:
  author: Wolfram Research
  version: 2.1.28
---

# Wolfram Notebooks

Read and write Wolfram notebook (`.nb`) files, including conversion between markdown and notebook format.

## Prerequisites

These scripts require `wolframscript`. If it is not installed or not on your PATH, read `references/GetWolframEngine.md` (relative to this skill directory) for installation instructions.

## Usage

### With MCP Server (preferred)

If you have Wolfram notebook MCP tools available in your tool list (e.g., `mcp__WolframLanguage__ReadNotebook`), use those directly. They provide richer integration and better performance than the bundled scripts.

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
| `ReadNotebook` | Read a Wolfram notebook (`.nb`) file and return its contents as markdown |
| `WriteNotebook` | Convert markdown text to a Wolfram notebook and save it to a `.nb` file |

### ReadNotebook

Use `ReadNotebook` to inspect the contents of an existing Wolfram notebook. The tool returns the notebook's content as markdown text, including code cells, text cells, and their outputs. This is useful for:

- Understanding what a notebook contains without opening it in a Wolfram notebook interface
- Reviewing notebook code and results in a text-based workflow
- Extracting code or documentation from notebooks

The `notebook` argument should be a file path to a `.nb` file.

### WriteNotebook

Use `WriteNotebook` to create a new Wolfram notebook from markdown text. The markdown is converted to notebook cell structure with appropriate cell types (code cells, text cells, section headers, etc.). This is useful for:

- Creating notebooks programmatically from documentation or code
- Converting markdown-based content into interactive Wolfram notebooks
- Generating starter notebooks for users

The `file` argument must end in `.nb`. The `markdown` argument is the content to convert. Use the `--overwrite` flag if you need to replace an existing file.

## Other Tips

- Use `ReadNotebook` before modifying a notebook to understand its current structure and content.
- When writing notebooks, use standard markdown formatting: `#` headers become Section/Subsection cells, fenced code blocks become Code cells, and plain text becomes Text cells.
- If you also have the `wolfram-language` skill available, you can evaluate code from a notebook using `WolframLanguageEvaluator` after reading it with `ReadNotebook`.
