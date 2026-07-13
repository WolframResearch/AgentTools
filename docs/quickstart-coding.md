# Quick Start for AI Coding Applications

This guide walks you through setting up the Wolfram MCP Server with AI coding applications like Claude Code, Cursor, Visual Studio Code, and others. By the end, your AI coding assistant will be able to evaluate Wolfram Language code, search documentation, read and write notebooks, run tests, and inspect code.

## Recommended Server

For Wolfram Language development, it's recommended to use the **WolframLanguage** server. It gives the AI the ability to:

- **Search Wolfram resources** including documentation, function repository, data repository, and more
- **Execute code** to test implementations and verify behavior
- **Read and write notebooks** for working with `.nb` files as markdown
- **Look up symbol definitions** to understand existing code
- **Inspect code** for potential issues and style problems
- **Run tests** to validate changes against your test suite

## Installation

All installation methods use the `InstallMCPServer` function. Open a Wolfram Language session and run the appropriate command for your application.

### Amazon Q Developer

Choose whether to install the server globally or project-level. Global installation is available in all projects, while project-level installation is available only in a specific project directory.

Global installation:

```wl
InstallMCPServer["AmazonQ", "WolframLanguage"]
```

Project-level installation:

```wl
InstallMCPServer[{"AmazonQ", "/path/to/project"}, "WolframLanguage"]
```

### Augment Code

Augment Code has two independent configurations — one for the Auggie CLI and one for the VS Code extension. Install into whichever you use.

For the Auggie CLI:

```wl
InstallMCPServer["AugmentCode", "WolframLanguage"]
```

Verify with `auggie mcp list`.

For the Augment Code VS Code extension:

```wl
InstallMCPServer["AugmentCodeIDE", "WolframLanguage"]
```

Then reload the VS Code window (`Ctrl+Shift+P` → "Reload Window"). The server will appear in the Augment Settings panel's MCP section.

### Claude Code

Choose whether to install the server globally or project-level. Global installation is available in all projects, while project-level installation is available only in a specific project directory.

Global installation:

```wl
InstallMCPServer["ClaudeCode", "WolframLanguage"]
```

Project-level installation:

```wl
InstallMCPServer[{"ClaudeCode", "/path/to/project"}, "WolframLanguage"]
```

Verify the installation from the command line:

```shell
claude mcp get WolframLanguage
```

The output should indicate that the "WolframLanguage" server is connected.

### Cline

```wl
InstallMCPServer["Cline", "WolframLanguage"]
```

### Copilot CLI

```wl
InstallMCPServer["CopilotCLI", "WolframLanguage"]
```

To verify the installation from the command line:

```shell
copilot -i "/mcp show"
```

The output should indicate that the "WolframLanguage" server is configured.

### Cursor

```wl
InstallMCPServer["Cursor", "WolframLanguage"]
```

To verify the installation:

- Navigate to Cursor settings
- Select the "Tools & MCP" tab
- Verify that "WolframLanguage" is listed under "Installed MCP Servers"

### Gemini CLI

```wl
InstallMCPServer["GeminiCLI", "WolframLanguage"]
```

To verify the installation from the command line:

```shell
gemini -i "/mcp"
```

The output should indicate that the "WolframLanguage" server is configured.

### Google Antigravity

```wl
InstallMCPServer["Antigravity", "WolframLanguage"]
```

To verify the installation:

- In the editor view, click the "..." menu at the top right of the "Agent" panel
- Select "MCP Servers"
- Click "Manage MCP Servers" at the top right of the panel
- Verify that "WolframLanguage" is listed under "Installed MCP Servers"

### Goose

```wl
InstallMCPServer["Goose", "WolframLanguage"]
```

To verify the installation from the command line:

```shell
goose mcp list
```

The output should indicate that the "Wolfram" extension is enabled. Both the Goose desktop app and CLI share the same `config.yaml`, so the server will be available in both.

### OpenAI Codex

Choose whether to install the server globally or for a single project. Project-level installation writes `.codex/config.toml` in the project root.

Global installation:

```wl
InstallMCPServer["Codex", "WolframLanguage"]
```

Project-level installation:

```wl
InstallMCPServer[{"Codex", "/path/to/project"}, "WolframLanguage"]
```

To verify the installation from the command line:

```shell
codex mcp get WolframLanguage
```

If you installed the server project-level, run the command from that project directory. The output should indicate that the "WolframLanguage" server is enabled.

### OpenCode

Choose whether to install the server globally or project-level. Global installation is available in all projects, while project-level installation is available only in a specific project directory.

Global installation:

```wl
InstallMCPServer["OpenCode", "WolframLanguage"]
```

Project-level installation:

```wl
InstallMCPServer[{"OpenCode", "/path/to/project"}, "WolframLanguage"]
```

To verify the installation from the command line:

```shell
opencode mcp list
```

The output should indicate that the "WolframLanguage" server is connected.

### Qwen Code

Choose whether to install the server globally or project-level. Global installation is available in all projects, while project-level installation writes `.qwen/settings.json` in the project root.

Global installation:

```wl
InstallMCPServer["QwenCode", "WolframLanguage"]
```

Project-level installation:

```wl
InstallMCPServer[{"QwenCode", "/path/to/project"}, "WolframLanguage"]
```

To verify the installation from the command line:

```shell
qwen mcp list
```

The output should indicate that the "WolframLanguage" server is configured.

### Visual Studio Code

Choose whether to install the server globally or project-level. Global installation is available in all projects, while project-level installation is available only in a specific project directory.

Global installation:

```wl
InstallMCPServer["VisualStudioCode", "WolframLanguage"]
```

Project-level installation:

```wl
InstallMCPServer[{"VisualStudioCode", "/path/to/project"}, "WolframLanguage"]
```

### Windsurf

```wl
InstallMCPServer["Windsurf", "WolframLanguage"]
```

### Zed

```wl
InstallMCPServer["Zed", "WolframLanguage"]
```

### Other Clients

For other MCP-compatible clients, you can generate the raw JSON configuration and adapt it manually:

```wl
MCPServerObject["WolframLanguage"]["JSONConfiguration"]
```

See [mcp-clients.md](mcp-clients.md) for a full list of supported clients, configuration file locations, and format details.

#### Verifying the Installation

After installing, restart your coding tool and confirm the Wolfram tools are available. Most applications have a way to list configured MCP servers and their status. If you're unsure, you can always just ask the AI:

> "What Wolfram Language tools do you have access to?"

The AI should list tools like `WolframLanguageEvaluator`, `WolframLanguageContext`, `TestReport`, etc.

## Configuring AI Guidance with AGENTS.md

AI coding tools start each session with no memory of previous conversations. An `AGENTS.md` file (or similar project-level instructions file) at the root of your project gives the AI essential context about your codebase, conventions, and how to use the Wolfram Language tools effectively.

> **Note for Claude Code users:** Claude Code uses a `CLAUDE.md` file for project instructions rather than `AGENTS.md`. If your project only uses Claude Code, you can name your instructions file `CLAUDE.md` instead. If you use multiple AI coding tools and want to maintain a single source of truth, you have two options:
> - Put `@AGENTS.md` in your `CLAUDE.md` file to automatically include the contents of `AGENTS.md`
> - Create `CLAUDE.md` as a symlink to `AGENTS.md` (e.g., `ln -s AGENTS.md CLAUDE.md`)

### Why AGENTS.md Matters

Without guidance, the AI will:
- Not know when to use `WolframLanguageContext` to look up documentation
- Miss your project's coding conventions and patterns
- Write code in unfamiliar styles or use deprecated patterns
- Skip testing and code inspection

With a well-written `AGENTS.md`, the AI will follow your conventions from the start.

### What to Include

1. **Tool guidance** - When and how to use each Wolfram Language tool
2. **Project layout** - Directory structure, key files, entry points
3. **Code style** - Naming conventions, patterns, error handling approach
4. **Testing** - How to run tests, where test files live, test format

### Available Tools

The WolframLanguage server provides these tools that you can reference in your AGENTS.md:

| Tool | Description |
|------|-------------|
| `WolframLanguageContext` | Semantic search across Wolfram resources (documentation, function repository, data repository, neural net repository, and more) |
| `WolframLanguageEvaluator` | Execute Wolfram Language code |
| `ReadNotebook` | Read Wolfram notebooks (.nb) as markdown |
| `WriteNotebook` | Convert markdown to Wolfram notebooks |
| `SymbolDefinition` | Look up symbol definitions in readable format |
| `CodeInspector` | Inspect code for issues and return a formatted report |
| `TestReport` | Run Wolfram Language test files (.wlt) |

### AGENTS.md Template

Below is a template you can adapt for your Wolfram Language project:

````markdown
# AGENTS.md

## Overview

Brief description of what your project does.

## Development

Always use the WolframLanguageContext tool when working with Wolfram Language code
to look up documentation and find relevant functions before writing code.

When you make changes to source code, write and run tests using the TestReport tool
and check your work with the CodeInspector tool.

## Project Structure

- `Kernel/` - Main source files
  - `MyPaclet.wl` - Entry point
  - `Utilities.wl` - Helper functions
- `Tests/` - Test files (.wlt)
- `Documentation/` - Notebooks and docs

## Code Style

- Use `UpperCamelCase` for public function names
- Use `lowerCamelCase` for internal function names
- Use `Enclose`/`Confirm` for error handling:
  ```wl
  myFunction[arg_] := Enclose[
      Module[{result},
          result = ConfirmBy[computation[arg], StringQ];
          result
      ]
  ];
  ```

## Writing Tests

Write tests in this format:

```wl
VerificationTest[
    input,
    expected,
    TestID -> "DescriptiveTestID"
]
```

Test files go in the `Tests/` directory with a `.wlt` extension.

## Key Patterns

Describe any project-specific patterns, conventions, or architectural decisions
that the AI should follow.
````

Adjust the template to match your actual project structure, conventions, and requirements.

**Example:** To see a real-world `AGENTS.md` file, view the one used during development of this paclet:
```wl
Import[PacletObject["Wolfram/AgentTools"]["AssetLocation", "AGENTS.md"], "Text"]
```

### Keeping AGENTS.md Up to Date

Your `AGENTS.md` is a living document that should evolve with your project. Update it when you:
- Add new files, directories, or architectural components
- Establish new coding patterns or conventions
- Discover edge cases or gotchas the AI should know about
- Change testing strategies or workflows

A few minutes spent updating `AGENTS.md` after significant changes saves time in future sessions by preventing the AI from making outdated assumptions.

> **Tip:** AI coding assistants can help you write and update your `AGENTS.md` file—just ask! However, always review AI-suggested changes carefully to ensure they accurately reflect your project's conventions and requirements.

## Best Practices for AI-Assisted Development

### Test-Driven Development

AI coding tools work well with a test-driven workflow:

1. **Write tests first** describing the expected behavior
2. **Ask the AI to implement** the function to pass the tests
3. **Run tests with TestReport** to verify
4. **Iterate** until all tests pass

This gives the AI a concrete specification to work against and provides automatic verification.

### Use Planning Mode

For non-trivial tasks, ask the AI to plan before implementing:

> "I need to add a function that parses CSV files into Associations according to a given schema. Plan the implementation before writing code and ask me clarifying questions as needed."

This lets the AI explore the codebase, understand existing patterns, and propose an approach for your review before making changes.

**Note:** Many applications support a built-in "planning mode" that switches it into a mode that is optimized for this type of work. If your application supports this, you should use it to plan the implementation before writing code.

### Avoiding "Context Rot" in Large Tasks

AI coding tools have finite context windows. When implementing large features, accumulated context can degrade performance as the conversation grows. Many tools offer mitigation strategies—context compression, subagents, task management—but these rely on AI deciding what information matters. Mistakes compound over time, leading to progressively worse results.

For complex features spanning multiple sessions, a manual approach to context management often works better. Here we'll describe an example workflow that's a variation of the currently popular ["Ralph" loop](https://ghuntley.com/ralph/). The core idea: instead of continuing one long conversation, start fresh sessions with carefully curated context.

**When to use this approach:**
- Features requiring more than 3-4 implementation sessions
- Work that's likely to span multiple hours (or days)
- Tasks where maintaining accuracy is critical

**When it's overkill:**
- Single-session features
- Quick bug fixes or refactors
- Exploratory prototyping

#### The Workflow

Organize your feature work using three documents:

```
Specs/FeatureName.md      # What to build (requirements, API, edge cases)
TODO/FeatureName.md       # Tasks to complete (checklist)
Progress/FeatureName.md   # What's been done (session summaries)
```

Each session, you provide these three files as context along with instructions to complete one task. After completing a task, the AI updates the progress log and task list, then you start a fresh session for the next task.

#### Create a Specifications Document

Before starting, write a detailed spec:

````markdown
# Feature: CSV Import with Schema Validation

## Requirements
- Parse CSV files into lists of Associations
- Support custom column type specifications
- Validate data against provided schema
- Return Failure objects for invalid data

## API Design
```wl
CSVImportValidated[file, schema] (* returns {<|...|>, ...} or Failure *)
```

## Schema Format
```wl
<|"Name" -> "String", "Age" -> "Integer", "Score" -> "Real"|>
```

## Edge Cases
- Empty files return {}
- Missing columns return Failure["MissingColumn", ...]
- Type mismatches return Failure["TypeError", ...]
````

AI assistants can help draft this spec—ask them to propose an API design or identify edge cases you might have missed. However, iterate until every detail is correct. This spec becomes the source of truth for all implementation work, so inaccuracies here will propagate into the code.

**Tips for good specs:**
- Be explicit about return types and error conditions
- Include concrete examples for non-obvious behavior
- Document assumptions and constraints

#### Generate a Task List

In a new session, ask the AI to generate a task list based on the spec:

> "Analyze @Specs/CSVImportValidated.md and break it down into implementation tasks. Create TODO/CSVImportValidated.md with a checklist."

Aim for tasks that can each be completed in a single focused session:

````markdown
# TODO: CSVImportValidated

- [ ] Implement CSVImportValidated with basic parsing
- [ ] Add schema validation for String, Integer, Real types
- [ ] Write 12 tests, all passing
- [ ] Add support for DateObject columns
- [ ] Handle quoted strings with commas
- [ ] Add Options for delimiter and header row
- [ ] Verify all tests pass
- [ ] Update documentation
- [ ] Perform final review
````

#### Write Progress Reports

At the end of each session, have the AI append a progress report:

> "Append a progress report to Progress/CSVImportValidated.md as a new '## Session N' section summarizing what was accomplished and anything useful for resuming this task."

This log captures institutional knowledge that would otherwise be lost between sessions. After the first session:

````markdown
# Progress: CSVImportValidated

## Session 1

Task: Implement CSVImportValidated with basic parsing
Status: Completed

Work completed:

- Created Kernel/CSVImportValidated.wl with basic parsing implementation
- CSVImportValidated currently returns a list of associations with no validation yet
...

Things learned:

- `FileFormatQ["path/to/file.csv", "CSV"]` can check if a file is a valid CSV file without fully importing it
...

````

#### Iteratively Implement Tasks

For each session, provide the three context files with instructions to complete one task. Save this as a reusable prompt file (e.g., `prompts/implement-task.md`):

````markdown
## Context

@TODO/CSVImportValidated.md
@Specs/CSVImportValidated.md
@Progress/CSVImportValidated.md

## Instructions

1. Choose the next incomplete task from the task list
2. Study the specification requirements for that task
3. Implement the task
4. Append a progress report to Progress/CSVImportValidated.md
5. Mark the task complete in TODO/CSVImportValidated.md
6. Commit your changes
7. Stop and wait for user input

IMPORTANT: Complete only ONE task per session.
````

Then start each session with:

```shell
claude "$(cat prompts/implement-task.md)"
```

> **Note:** The `@path/to/file` syntax inserts file contents into the prompt. Most AI coding tools support similar syntax. If yours doesn't, ask the AI to read the files as its first action.

#### Best Practices

**Start fresh sessions:** After completing a task, start a new session with the same prompt rather than continuing. This prevents context accumulation.

**Monitor and edit:** Review changes to the progress file. When necessary, manually edit it to ensure good context for the next session—the AI may miss important details or include irrelevant information.

**Stay involved:** This approach works best when you're actively reviewing changes, not running unattended. Your judgment about what context matters is what prevents "context rot."

**Automation:** You can script this as a loop that runs until all tasks are checked off, but monitor the results carefully.

## Security Considerations

The **WolframLanguageEvaluator** and **TestReport** tools execute arbitrary Wolfram Language code. This means they can perform any action that a Wolfram kernel can perform, including:

- Reading, writing, and deleting files
- Making network requests
- Running system commands
- Accessing environment variables

Most AI coding applications support **approval-based permissions** that prompt you before the AI executes potentially dangerous tools. You should configure your application to require approval for these tools:

| Tool | Risk | Recommendation |
|------|------|----------------|
| `WolframLanguageEvaluator` | Executes arbitrary code | Require approval |
| `TestReport` | Runs test files (which execute code) | Require approval |
| `WriteNotebook` | Writes notebook files | Require approval |
| `CodeInspector` | Read-only, but reads file contents | Auto-approve or require approval* |
| `ReadNotebook` | Read-only, but reads file contents | Auto-approve or require approval* |
| `WolframLanguageContext` | Read-only documentation search | Auto-approve is safe |
| `SymbolDefinition` | Read-only symbol lookup | Auto-approve is safe |

*`CodeInspector` and `ReadNotebook` read file contents that are sent to your LLM provider. If your project contains sensitive information you wouldn't want included in LLM context, consider requiring approval for these tools as well. Note that these tools are designed for Wolfram Language files and notebooks respectively, so they will likely fail on other file types.

### Prompt Injection Considerations

If your AI coding application has access to tools that fetch content from the web or other untrusted sources, be aware of prompt injection risks. Malicious content could instruct the AI to use other tools in unintended ways.

For example, `SymbolDefinition` is generally safe, but if the AI previously used `WolframLanguageEvaluator` to connect to a service (storing API keys in memory), a prompt injection attack could potentially instruct the AI to use `SymbolDefinition` to extract those values.

As a general rule: if you auto-approve any tools that read untrusted external content, consider requiring approval for all other tools that could expose sensitive information.

Consult your AI coding application's documentation for how to configure tool permissions.

## Troubleshooting

### Server not connecting

- Fully restart your coding application after installation (closing the window often just minimizes it to the system tray)
- Manually inspect the configuration file returned by `InstallMCPServer` to ensure the server is configured correctly
- Check your client's documentation for location of log files or other diagnostic information to check for errors

### WolframLanguageContext not working as expected

The `WolframLanguageContext` tool requires an [LLM Kit subscription](https://www.wolfram.com/notebook-assistant-llm-kit/) for best results. Without it, documentation search will be less accurate. Code execution (`WolframLanguageEvaluator`) and other tools work without LLM Kit.

### Server is using the wrong version of Wolfram Language

The installed MCP server will use the same version of Wolfram Language as the session it was installed from. If you want to use a different version of Wolfram Language, you need to install the MCP server in a session of that version or manually edit the configuration file to point to a different Wolfram kernel.
