# AgentTools Developer Documentation

This is the developer documentation for contributing to AgentTools. For user documentation, see the [AgentTools paclet documentation](https://paclets.com/Wolfram/AgentTools).

## User Guides

- **[Quick Start: AI Coding Tools](quickstart-coding.md)** - Set up the Wolfram MCP Server with Claude Code, Cursor, VS Code, and other coding tools
- **[Quick Start: Chat Clients](quickstart-chat.md)** - Add Wolfram computational capabilities to Claude Desktop and other chat clients

## Developer Quick Start

- **[Getting Started](getting-started.md)** - Set up your development environment and learn the workflow

## Core Concepts

- **[Error Handling](error-handling.md)** - Error handling architecture using `catchTop`, `throwFailure`, and the `Enclose`/`Confirm` pattern
- **[MCP Tools](tools.md)** - How MCP tools work, tool options, and how to add new tools
- **[MCP Prompts](mcp-prompts.md)** - How MCP prompts work and how to add new prompts
- **[MCP Apps](mcp-apps.md)** - Interactive UI resources for supported clients
- **[MCP Roots](mcp-roots.md)** - Project-directory handshake that aligns the server, evaluator, and external tools with the client's working directory
- **[Predefined Servers](servers.md)** - Available server configurations and how to choose the right one
- **[MCP Clients](mcp-clients.md)** - Supported client applications and configuration
- **[CodeInspector Rules](code-inspector-rules.md)** - Adding custom CodeInspector rules and current rule catalog
- **[Agent Skills](agent-skills.md)** - Distributable agent skills, dual-mode architecture, and how to add new skills
- **[Deploy Agent Tools](deploy-agent-tools.md)** - Managed deployment of Wolfram tools to AI agent clients
- **[Cloud Deployment](cloud-deployment.md)** - Deploying an `MCPServerObject` as a remote HTTP MCP server in the Wolfram Cloud
- **[Preferences Content](preferences-content.md)** - System preferences UI for managing deployed Wolfram toolsets
- **[Paclet Extensions](paclet-extensions.md)** - Third-party paclet extension system for contributing tools, prompts, and servers

## Development Workflow

- **[Testing](testing.md)** - Writing and running tests
- **[Building](building.md)** - Building the paclet for distribution

## Additional Resources

- [AGENTS.md](../AGENTS.md) - Detailed development guidelines and AI agent guidance
- [README.md](../README.md) - Project overview and quick start for users
