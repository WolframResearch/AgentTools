# Script Reference

Auto-generated reference for bundled scripts. Pass `--usage` to any
script for the latest argument documentation.

## WolframLanguageContext.wls

Uses semantic search to retrieve information from various sources that can be used to help write Wolfram Language code. Always use this tool at the start of new conversations or if the topic changes to ensure you have up-to-date relevant information. This uses semantic search, so the context argument should be written in natural language (not a search query) and contain as much detail as possible.

**Usage:**

```
wolframscript -f scripts/WolframLanguageContext.wls <context>
```

**Arguments:**

| Argument | Required | Description |
| --- | --- | --- |
| `context` | Yes | A detailed summary of what the user is trying to achieve or learn about. |

---

## WolframLanguageEvaluator.wls

Evaluates Wolfram Language code for the user in a Wolfram Language kernel.
Do not ask permission to evaluate code.
You have read access to local files.
Always use the Wolfram context tool before using this tool to make sure you have the most up-to-date information.

Use `\[FreeformPrompt]["query"]` to parse natural language into Wolfram Language expressions (like ctrl+= in notebooks). Always use this for `Quantity`, `Entity`, `EntityClass`, etc. It composes freely: `ColorNegate[\[FreeformPrompt]["picture of a cat"]]`.

Examples:
```
\[FreeformPrompt]["France population"]  (* Entity property value *)
\[FreeformPrompt]["123 terawatt hours"] (* Quantity *)
```

The argument MUST be a string literal -- it parses before evaluation, so runtime construction will not work.

**Usage:**

```
wolframscript -f scripts/WolframLanguageEvaluator.wls <code> [--timeConstraint value] [--session value]
```

**Arguments:**

| Argument | Required | Description |
| --- | --- | --- |
| `code` | Yes | The Wolfram Language code to evaluate. |
| `--timeConstraint` | No | The time constraint for the evaluation. Uses the server's configured default if not specified. |
| `--session` | No | An opaque session ID returned by a previous call to this tool. Pass it to continue that conversation's isolated session (its definitions, line numbers, and history). Omit it to start a new session; the response returns a new ID that you should reuse on subsequent calls in this conversation. |

---

## SymbolDefinition.wls

Retrieves the definitions of one or more Wolfram Language symbols and returns them in a readable markdown format.
The tool generates clean, formatted definition strings by intelligently managing the context path to minimize fully qualified symbol names.

Use fully qualified symbol names (e.g., System`Plus, Wolfram`AgentTools`CreateMCPServer) if the context is known.
Multiple symbols can be requested by separating them with commas.

**Usage:**

```
wolframscript -f scripts/SymbolDefinition.wls <symbols> [--includeContextDetails value] [--maxLength value]
```

**Arguments:**

| Argument | Required | Description |
| --- | --- | --- |
| `symbols` | Yes | The symbol name (or multiple names, comma separated). |
| `--includeContextDetails` | No | Whether to include a JSON map showing which symbols belong to which contexts (default: false). |
| `--maxLength` | No | Maximum character length for output before truncation (default: 10000). |

---

## TestReport.wls

Runs Wolfram Language test files (.wlt) and returns a report of the results

**Usage:**

```
wolframscript -f scripts/TestReport.wls <paths> [--timeConstraint value] [--memoryConstraint value] [--newKernel value]
```

**Arguments:**

| Argument | Required | Description |
| --- | --- | --- |
| `paths` | Yes | Comma separated list of paths to Wolfram Language test files (.wlt) or directories of test files |
| `--timeConstraint` | No | An optional time constraint (in seconds) for each test file |
| `--memoryConstraint` | No | An optional memory constraint (in bytes) for each test file |
| `--newKernel` | No | Whether to use a fresh kernel for running tests (default is true) |

---

## CodeInspector.wls

Inspects Wolfram Language code using the CodeInspector package and returns a formatted report of issues found. The tool supports inspecting code strings, individual files, or entire directories of Wolfram Language source files.

**Usage:**

```
wolframscript -f scripts/CodeInspector.wls [--code value] [--file value] [--tagExclusions value] [--severityExclusions value] [--confidenceLevel value] [--limit value]
```

**Arguments:**

| Argument | Required | Description |
| --- | --- | --- |
| `--code` | No | Wolfram Language code string to inspect. |
| `--file` | No | File or directory path to inspect. For directories, recursively inspects all .wl, .m, and .wls files. |
| `--tagExclusions` | No | Comma-separated list of tags to exclude (e.g., "UnusedVariable,SuspiciousSessionSymbol"). |
| `--severityExclusions` | No | Comma-separated list of severities to exclude. Default: "Formatting,Scoping". Available: Fatal, Error, Warning, Scoping, Remark, Formatting. |
| `--confidenceLevel` | No | Minimum confidence level (0.0 to 1.0). Default: 0.75. Issues below this confidence are excluded. |
| `--limit` | No | Maximum number of issues to display. Default: 100. |

