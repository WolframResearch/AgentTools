# Getting Started with AgentTools Development

This guide helps you set up your development environment and understand the workflow for contributing to AgentTools.

## Prerequisites

- **Wolfram Language** (Mathematica 14.3+ or Wolfram Engine)
- **wolframscript** (for running build scripts)
- **Git**

## Project Overview

AgentTools is a Wolfram Language toolkit for integrating with AI agents and LLMs — providing [MCP](https://modelcontextprotocol.io) servers, agent skills, and other standard interfaces that give AI systems access to Wolfram's computational capabilities.

For user documentation, see the [AgentTools paclet documentation](https://paclets.com/Wolfram/AgentTools).

## Setting Up Your Development Environment

### Cloning the Repository

```bash
git clone https://github.com/WolframResearch/AgentTools.git
cd AgentTools
```

### Configuring Git Hooks

Enable the pre-commit hooks to automatically format notebooks and annotate test IDs:

```bash
git config --local core.hooksPath Scripts/.githooks
```

This runs `Scripts/FormatFiles.wls` before each commit.

### Loading the Paclet for Development

To test changes to paclet code, load the paclet from your local directory:

```wl
PacletDirectoryLoad["path/to/AgentTools"];
Get["Wolfram`AgentTools`"]
```

Replace `"path/to/AgentTools"` with the actual path to your cloned repository.

### Important: MX Files

If you've previously built an MX file for the paclet, you should **delete it before testing your changes**. The MX file is located at:

```
Kernel/64Bit/AgentTools.mx
```

The MX file contains a pre-compiled version of the paclet. If it exists, it will be loaded instead of your modified source files.

### Reloading the Paclet

When reloading the paclet during development:

- **Do not** use `Clear`, `ClearAll`, or `Remove` on symbols
- Reloading the paclet handles symbol cleanup automatically in `Kernel/AgentToolsLoader.wl`
- Manual symbol clearing may lead to unexpected behavior

Simply call ``Get["Wolfram`AgentTools`"]`` again to reload your changes.

## Development Workflow

1. **Make changes** to source files in `Kernel/`
2. **Delete the MX file** if it exists (only needed once per session)
3. **Reload the paclet** using ``Get["Wolfram`AgentTools`"]``
4. **Test changes** interactively in a Wolfram Language session
5. **Run tests** to verify your changes don't break existing functionality
6. **Build the paclet** to verify everything compiles correctly

## Setting Up Coding Agents for Development

When developing AgentTools, you can configure AI coding agents like Claude Code to use your local development version of the paclet. This allows the agent to test your changes in real-time as you develop.

### Why Use Development Mode?

By default, `InstallMCPServer` configures the agent to use the installed paclet from the Wolfram Paclet Repository. During development, you want the agent to use your local source files instead so that:

- Changes you make are immediately available to the agent
- You can iterate quickly without reinstalling the paclet
- The agent can help test and validate your modifications

### Installing for Development

Use `InstallMCPServer` with the `"DevelopmentMode"` option to configure a coding agent to use your local repository:

```wl
InstallMCPServer[
    {"ApplicationName", "/path/to/AgentTools"},
    "WolframPacletDevelopment",
    "DevelopmentMode" -> True
]
```

This command:
- Installs to the project-level configuration file (e.g., `.mcp.json` in the specified directory)
- Uses the `"WolframPacletDevelopment"` server, which provides tools tailored for paclet development
- Sets `"DevelopmentMode" -> True` to use `Scripts/StartMCPServer.wls` from your local repository instead of the installed paclet

### Supported Agents

The `"DevelopmentMode"` option works with any supported agent. Use the appropriate target name:

| Agent | Target Name | Config Location |
|-------|-------------|-----------------|
| Claude Code | `{"ClaudeCode", "/path/to/project"}` | `.mcp.json` in project |
| VS Code | `{"VisualStudioCode", "/path/to/project"}` | `.vscode/mcp.json` |
| OpenCode | `{"OpenCode", "/path/to/project"}` | `opencode.json` in project |

### Development Mode Options

The `"DevelopmentMode"` option accepts:

| Value | Behavior |
|-------|----------|
| `False` (default) | Uses the installed paclet |
| `True` | Uses `Scripts/StartMCPServer.wls` from the current paclet's location |
| `"/path/to/dir"` | Uses `Scripts/StartMCPServer.wls` from the specified directory |

### Example: Setting Up Claude Code

1. Clone the repository and navigate to it
2. Start a Wolfram Language session
3. Load the paclet:
   ```wl
   PacletDirectoryLoad["/path/to/AgentTools"];
   Needs["Wolfram`AgentTools`"]
   ```
4. Install for Claude Code with development mode:
   ```wl
   InstallMCPServer[
       {"ClaudeCode", "/path/to/AgentTools"},
       "WolframPacletDevelopment",
       "DevelopmentMode" -> True
   ]
   ```
5. Restart Claude Code to pick up the new configuration

Now Claude Code will use your local development version of AgentTools when working in the repository.

## Writing and Running Tests

See [testing.md](testing.md) for details on writing and running tests.

## Building the Paclet

See [building.md](building.md) for details on building the paclet.

## Project Structure

```
AgentTools/
├── Assets/                    # Static assets bundled with the paclet
│   └── Apps/                  # HTML/JSON files for MCP Apps UI resources
├── Kernel/                    # Core implementation
│   ├── AgentTools.wl          # Main entry point
│   ├── Main.wl                # Package loading, exported symbols
│   ├── Common.wl              # Utilities and [error handling](error-handling.md)
│   ├── CreateMCPServer.wl     # Server creation
│   ├── Server/                # MCP server core (shared dispatch, stdio + cloud transports)
│   ├── UIResources.wl         # MCP Apps UI resource registry
│   ├── Messages.wl            # Error messages
│   └── Tools/                 # Predefined MCP tools
├── Scripts/                   # Build and utility scripts
├── AgentSkills/               # Distributable agent skills (see [agent-skills.md](agent-skills.md))
│   ├── Manifest.wl            # Tool-to-skill mapping
│   ├── References/            # Shared reference files
│   └── Skills/                # Generated skill directories
├── Tests/                     # Test files (.wlt)
├── Specs/                     # Design specifications for features
├── Notes/                     # Development notes and design explorations
├── Documentation/             # Paclet documentation notebooks
└── docs/                      # Developer documentation
```

For detailed architecture information, see [AGENTS.md](../AGENTS.md#code-architecture).

## Next Steps

- Review the [Code Architecture](../AGENTS.md#code-architecture) section for understanding the codebase
- Check the [Key Development Patterns](../AGENTS.md#key-development-patterns) for function definitions and error handling
- Read the [Error Handling](error-handling.md) guide for the error handling architecture

## Additional Resources

- [Testing](testing.md) - Writing and running tests
- [Building](building.md) - Building the paclet for distribution
- [Error Handling](error-handling.md) - Error handling architecture and patterns
- [AGENTS.md](../AGENTS.md) - Detailed development guidelines and AI agent guidance
- [README.md](../README.md) - User documentation and quick start
- [Paclet Documentation](https://paclets.com/Wolfram/AgentTools) - Published user documentation
