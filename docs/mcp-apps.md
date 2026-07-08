# MCP Apps in AgentTools

This document explains how MCP Apps work in AgentTools and how to extend them.

## Overview

[MCP Apps](https://modelcontextprotocol.io/docs/extensions/apps) is the first official MCP extension (`io.modelcontextprotocol/ui`), enabling servers to deliver interactive HTML user interfaces that render inside MCP hosts (Claude Desktop, VS Code, etc.) in sandboxed iframes.

AgentTools uses MCP Apps to provide:

- **Interactive Wolfram|Alpha results** displayed in an embedded notebook viewer
- **Rich evaluation output** from `WolframLanguageEvaluator` with interactive cloud notebooks
- **Embedded notebook viewers** for Wolfram Cloud notebooks

When a client does not support MCP Apps, all tools fall back to their standard text and image output, maintaining full backward compatibility.

## How It Works

### Capability Negotiation

MCP Apps support is negotiated during the `initialize` handshake:

1. The client advertises support for the `io.modelcontextprotocol/ui` extension in its `capabilities`
2. The server detects this and echoes the extension in its response
3. For the rest of the session, the server enriches tool definitions and results with UI metadata

The server checks two conditions before enabling MCP Apps:

- The client must advertise `io.modelcontextprotocol/ui` in `capabilities.extensions`
- The `MCP_APPS_ENABLED` environment variable must not be set to `"false"`

### UI Resources

UI resources are HTML apps served via the MCP `resources/read` endpoint. Each resource is identified by a `ui://` URI (e.g., `ui://wolfram/wolframalpha-viewer`).

Resources are loaded from HTML files in the `Assets/Apps/` directory at server startup. Each HTML file can have an accompanying `.json` metadata file with the same base name.

The server handles these MCP methods for UI resources:

| Method | Description |
|--------|-------------|
| `resources/list` | Returns the list of available UI resources (empty if MCP Apps is not active) |
| `resources/read` | Returns the HTML content and metadata for a specific UI resource |

### Tool-UI Linkage

Tools can be associated with a UI resource. When the client supports MCP Apps, the `tools/list` response includes `_meta.ui` metadata on each linked tool:

```json
{
  "name": "WolframAlpha",
  "description": "...",
  "inputSchema": { ... },
  "_meta": {
    "ui": {
      "resourceUri": "ui://wolfram/wolframalpha-viewer",
      "visibility": ["model", "app"]
    }
  }
}
```

The host uses this metadata to preload the HTML app and render it alongside tool results.

### UI-Enhanced Tool Results

When MCP Apps is active, certain tools return enhanced results with `_meta` containing a `notebookUrl`. The host forwards this metadata to the rendered app, which can then embed the notebook interactively.

Tools with UI-enhanced behavior:

| Tool | Enhancement |
|------|-------------|
| `WolframAlpha` | Deploys a cloud notebook with formatted Wolfram\|Alpha pods and returns `notebookUrl` in `_meta` |
| `WolframLanguageEvaluator` | Deploys a cloud notebook with evaluation results and returns `notebookUrl` in `_meta` |

These enhancements require both MCP Apps support and an active Wolfram Cloud connection. The session flag `$deployCloudNotebooks` (initialized from `$CloudConnected`) gates deployment: if a `CloudDeploy` call fails at runtime, the helper `deployCloudNotebookForMCPApp` sets the flag to `False` and the tools fall back to their standard (non-UI) results for the rest of the session rather than surfacing an internal failure.

Cloud notebooks are deployed with `AppearanceElements -> None` by default, which hides the footer links that would not be clickable inside the MCP App iframe. Some cloud accounts reject this option with `CloudDeploy::appearancenotsup`; in that case the deployment is transparently retried without `AppearanceElements`, and the unsupported status is cached in a session flag (`$includeAppearanceElements`) so subsequent deployments skip the failing attempt.

The fallback is per-tool:

- `WolframLanguageEvaluator` always has a text/image result it can return, so it degrades in place.
- `WolframAlpha` has no text-only fallback app view, so its entry in `$toolUIAssociations` is itself conditional on `$deployCloudNotebooks` — when the flag is `False`, no `_meta.ui` is attached to the tool definition and the client never sees it as a UI-enabled tool.

### Notebook Delivery: Cloud vs. Inline

By default, a UI-enhanced notebook is deployed to the Wolfram Cloud and its URL is sent to the app in `_meta.notebookUrl`. An experimental alternative serializes the notebook and embeds it inline, avoiding the cloud round-trip. The delivery method is selected by the `MCP_APPS_NOTEBOOK_METHOD` environment variable:

| `MCP_APPS_NOTEBOOK_METHOD` | Behavior of `deployCloudNotebookForMCPApp` |
|----------------------------|--------------------------------------------|
| unset (default) | Deploys the notebook with `CloudDeploy` and returns the cloud URL |
| `"Inline"` | Returns `ExportString[nb, "NB"]` — the serialized notebook itself — instead of a URL |

The same `notebookUrl` field carries both forms. Each viewer app (`evaluator-viewer.html`, `notebook-viewer.html`, `wolframalpha-viewer.html`) decides how to embed based on the value: a string starting with `http` is embedded as a cloud URL, while any other value is passed to `WolframNotebookEmbedder.embed` as an inline notebook expression (`{expr: ...}`).

Inline embedding is **experimental and not yet the default**. Both methods currently require an active cloud connection, since the UI-enhanced path is gated on `$deployCloudNotebooks` regardless of the delivery method (the `"Inline"` branch only asserts the flag rather than deploying).

When inline embedding is active, graphics can render empty in the embedded notebook. The `delayedDisplay` helper works around this for `WolframLanguageEvaluator` output: any output boxes containing `GraphicsBox`/`Graphics3DBox` are serialized and reconstructed asynchronously inside a `DynamicModule` (showing a progress indicator until ready). Outside inline mode, or for output without graphics, `delayedDisplay` returns the boxes unchanged.

### Recovering the Notebook URL When `_meta` Is Dropped

The `notebookUrl` is delivered to the app through `_meta` and `structuredContent` (per the MCP Apps spec), both of which are meant to reach the app without entering model context. Some hosts, however, drop both from tool results ([ext-apps#696](https://github.com/modelcontextprotocol/ext-apps/issues/696)), so the app never receives the URL directly and can only render the text/image fallback. Those same hosts also do not forward app-initiated `resources/read` (they answer it with JSON-RPC `-32601 "Method not found"`), so the app cannot ask the server for the URL either.

The one channel that does survive is the tool result's `content`. So for cloud-notebook results, `makeNotebookUIResult` appends the URL to the content inside a self-describing marker (a separate text item):

```
<internal>This tool call was displayed to the user as an interactive notebook, which they can already see. The URL below only renders that notebook; you do not need to read, repeat, visit, or otherwise use it. <url>https://www.wolframcloud.com/obj/.../56a24661be6b3368.nb</url></internal>
```

The wrapper text is addressed to the model — it explains that the notebook is already shown and the URL is not for it to act on — while the `<url>` tags let the viewer extract it. When a viewer sees a result with no `notebookUrl` from `_meta`/`structuredContent`, `findNotebookUrl` falls back to `extractNotebookUrlMarker`, which pulls the URL straight out of the marker (no server round-trip). Each text-rendering viewer also strips the whole `<internal>…</internal>` block (via `stripAgentOnlyText`) so it never reaches the user.

This path applies only to cloud delivery: inline notebooks (`MCP_APPS_NOTEBOOK_METHOD="Inline"`) carry the whole serialized notebook, which is delivered via `_meta` only, so no marker is appended. The `notebook-viewer` app normally receives its URL through the tool **input** (`arguments.url`), which is unaffected by the dropped-`_meta` issue; it applies the same marker recovery only as a fallback when a result arrives without a prior embed.

## Available UI Resources

| URI | HTML Asset | Description |
|-----|-----------|-------------|
| `ui://wolfram/wolframalpha-viewer` | `wolframalpha-viewer.html` | Displays Wolfram\|Alpha results with embedded notebook viewer |
| `ui://wolfram/evaluator-viewer` | `evaluator-viewer.html` | Displays Wolfram Language evaluation results with embedded notebook viewer |
| `ui://wolfram/notebook-viewer` | `notebook-viewer.html` | Generic embedded Wolfram Cloud notebook viewer |
| `ui://wolfram/mcp-apps-test` | `mcp-apps-test.html` | Diagnostic app for testing the MCP Apps pipeline |

## Available MCP Apps Tools

These tools are defined in `$DefaultMCPTools` but are not included in any default server configuration:

| Tool | Description |
|------|-------------|
| `NotebookViewer` | Embeds an interactive Wolfram Cloud notebook given a URL |
| `MCPAppsTest` | Diagnostic tool that echoes input with server metadata, useful for testing the MCP Apps pipeline |

To include these tools in a custom server:

```wl
CreateMCPServer["MyServer", <|
    "Tools" -> {
        "WolframLanguageEvaluator",
        "WolframAlpha",
        "NotebookViewer"
    }
|>]
```

## Tool-UI Associations

The mapping between tools and their UI resources is defined in `$toolUIAssociations` in `Kernel/UIResources.wl`:

| Tool | UI Resource URI |
|------|----------------|
| `NotebookViewer` | `ui://wolfram/notebook-viewer` |
| `MCPAppsTest` | `ui://wolfram/mcp-apps-test` |
| `WolframAlpha` | `ui://wolfram/wolframalpha-viewer` (only when `$deployCloudNotebooks` is `True`) |
| `WolframLanguageEvaluator` | `ui://wolfram/evaluator-viewer` |

## Disabling MCP Apps

MCP Apps can be disabled at install time:

```wl
InstallMCPServer["ClaudeDesktop", "EnableMCPApps" -> False]
```

This sets `MCP_APPS_ENABLED=false` in the server's environment, which prevents the server from negotiating UI support regardless of client capabilities.

MCP Apps are also effectively disabled when:

- The client does not advertise the `io.modelcontextprotocol/ui` extension
- The server cannot load its UI assets (graceful fallback)

## Adding a New UI Resource

### Step 1: Create the HTML App

Create an HTML file in `Assets/Apps/`:

```
Assets/Apps/my-app.html
```

The HTML file should implement the MCP Apps host-app protocol using `postMessage`. At minimum, the app should:

1. Send `ui/initialize` to the host when ready
2. Handle `ui/notifications/tool-input` and `ui/notifications/tool-result` messages

### Step 2: Add Optional Metadata

Create a JSON metadata file with the same base name:

```
Assets/Apps/my-app.json
```

This file can contain CSP declarations and other metadata used by the host. Under `csp`, the host adds an implicit `'self'` and appends each declared domain to the matching directive:

| `csp` field | Maps to | Governs |
|-------------|---------|---------|
| `connectDomains` | `connect-src` | `fetch`/XHR/WebSocket, and `data:`/streaming WebAssembly loads |
| `resourceDomains` | `script-src`, `style-src`, `img-src`, … | External scripts, styles, images, fonts |
| `frameDomains` | `frame-src` | Nested iframes (e.g. the embedded notebook) |

Apps that embed a notebook with `WolframNotebookEmbedder` must include `"data:"` in `connectDomains`: the embedder's WXFWeb library instantiates a WebAssembly module from a `data:` URI, which the browser governs under `connect-src`. The `evaluator-viewer`, `notebook-viewer`, and `wolframalpha-viewer` apps declare this.

CSP only governs whether a request may *start*; cross-origin *responses* are still subject to CORS, which the host cannot influence through this metadata.

### Step 3: Associate with a Tool

Add the tool-to-resource mapping in `$toolUIAssociations` in `Kernel/UIResources.wl`:

```wl
$toolUIAssociations = <|
    (* ... existing entries ... *)
    "MyTool" -> "ui://wolfram/my-app"
|>;
```

The URI is derived from the HTML filename: `ui://wolfram/<basename>`.

### Step 4: Write Tests

Add tests in `Tests/` for the new resource. See the existing test files (`Tests/MCPApps.wlt`, `Tests/MCPAppsTest.wlt`, etc.) for patterns.

## Architecture

### Key Files

| File | Description |
|------|-------------|
| `Kernel/UIResources.wl` | UI resource registry, capability detection, tool-UI metadata |
| `Kernel/StartMCPServer.wl` | Protocol handling for `resources/list`, `resources/read`, and `_meta` forwarding |
| `Kernel/CommonSymbols.wl` | Shared symbols for MCP Apps (`$clientSupportsUI`, `$uiResourceRegistry`, etc.) |
| `Kernel/InstallMCPServer.wl` | `"EnableMCPApps"` option and `MCP_APPS_ENABLED` environment variable |
| `Kernel/Messages.wl` | Error messages for UI resources |
| `Assets/Apps/` | HTML and JSON files for UI resources |
| `Kernel/Tools/NotebookViewer.wl` | NotebookViewer tool definition |
| `Kernel/Tools/MCPAppsTest.wl` | MCPAppsTest diagnostic tool definition |
| `Kernel/Tools/WolframAlpha.wl` | UI-enhanced Wolfram\|Alpha evaluation |
| `Kernel/Tools/WolframLanguageEvaluator.wl` | UI-enhanced code evaluation |

### Key Symbols

| Symbol | Context | Description |
|--------|---------|-------------|
| `$clientSupportsUI` | `Common` | Whether the current client supports MCP Apps |
| `$uiResourceRegistry` | `Common` | Association of loaded UI resources keyed by URI |
| `$toolUIAssociations` | `Common` | Mapping of tool names to UI resource URIs (entries may be `RuleDelayed` to gate on `$deployCloudNotebooks`) |
| `$deployCloudNotebooks` | `Common` | Session flag gating cloud notebook deployment; initialized from `$CloudConnected` and set to `False` after a deployment failure |
| `deployCloudNotebookForMCPApp` | `Common` | Shared helper that delivers a notebook for a UI-enhanced tool result — deploys to the cloud and returns a URL, or returns the serialized notebook when `MCP_APPS_NOTEBOOK_METHOD` is `"Inline"`; disables `$deployCloudNotebooks` on a deploy failure |
| `makeNotebookUIResult` | `Common` | Builds the UI-enhanced tool result from the text content and the delivered notebook value: carries `notebookUrl` in `_meta`/`structuredContent`, and for cloud URLs appends the `<internal>…<url>…</url></internal>` content marker (the dropped-`_meta` workaround); returns `$Failed` when deployment failed |
| `delayedDisplay` | `Common` | Wraps `WolframLanguageEvaluator` output boxes so graphics reconstruct asynchronously when notebooks are embedded inline; a no-op outside inline mode or for graphics-free output |
| `clientSupportsUIQ` | `Common` | Checks if an `initialize` message advertises UI support |
| `mcpAppsEnabledQ` | `Common` | Checks the `MCP_APPS_ENABLED` environment variable |
| `initializeUIResources` | `Common` | Loads HTML assets into the resource registry |
| `listUIResources` | `Common` | Returns the resource list for `resources/list` |
| `readUIResource` | `Common` | Handles `resources/read` requests |
| `toolUIMetadata` | `Common` | Returns `_meta.ui` for a tool name |
| `withToolUIMetadata` | `Common` | Augments a tool list with UI metadata |

## Related Documentation

- [MCP Apps specification](https://modelcontextprotocol.io/docs/extensions/apps) - Official MCP Apps documentation
- [tools.md](tools.md) - MCP tools system and how to add new tools
- [servers.md](servers.md) - Predefined server configurations
- [mcp-clients.md](mcp-clients.md) - Client support and `EnableMCPApps` option
