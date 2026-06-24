# RecurseChat MCP Client Research

## Overview

[RecurseChat](https://recurse.chat/) is a native desktop AI assistant for chatting with local LLMs, Claude, and ChatGPT. It supports MCP as a client.

## Key Findings

### Platform: Apple Silicon Mac only

RecurseChat is distributed exclusively through the **Mac App Store** and requires **Apple Silicon** (M1/M2/M3/M4) on **macOS Ventura 13.5 or later**. It does **not** run on Intel Macs, Windows, or Linux, and the project states no plans to support other operating systems.

This alone makes the integration impossible to develop or hands-on test on a Windows or Linux machine.

### Configuration: in-app UI, no external config file

MCP servers are added through the application UI: **Model Page → New Model → New MCP Model**, where the user can import an "MCP Server JSON Config." Configuration is stored internally by the app; the [MCP documentation](https://recurse.chat/docs/features/mcp/) does not document any external, user-editable config file path.

### Transport

The documentation references an "SSE endpoint" (remote) and does not explicitly document local stdio support. The current Wolfram MCP server is stdio-only.

## Why InstallMCPServer Cannot Be Implemented

`InstallMCPServer` works by writing a known configuration file at a known path that the client reads on startup. RecurseChat provides no such file — MCP servers are added through the in-app UI and stored internally. This is the same blocker as [Cherry Studio](cherry-studio.md): no external configuration file to write to.

The Apple-Silicon-only platform requirement is a secondary blocker: even the manual workflow can only be exercised by users on a recent Apple Silicon Mac.

## Recommendation

**Reject support for `InstallMCPServer["RecurseChat", ...]`** because:

- There is no documented external configuration file to write to (in-app UI / internal storage only).
- The app is Apple-Silicon-Mac-only, so it cannot be developed or tested on Windows/Linux.

### Manual workaround (Mac users)

Mac users can still connect the Wolfram MCP server manually:

1. Generate the JSON configuration: `MCPServerObject["Wolfram"]["JSONConfiguration"]`
2. In RecurseChat: Model Page → New Model → New MCP Model → import the JSON config.

## References

- [RecurseChat MCP documentation](https://recurse.chat/docs/features/mcp/)
- [RecurseChat FAQ (platform requirements)](https://recurse.chat/docs/resources/faq/)
- [RecurseChat on the Mac App Store](https://apps.apple.com/us/app/recursechat/id6476835702)
