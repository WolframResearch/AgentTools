# MCP Tools in AgentTools

This document explains how MCP tools work in AgentTools and how to add new tools.

## Overview

MCP tools allow servers to expose callable functions to language models. Clients can discover available tools, view their parameter specifications, and invoke them with arguments. This follows the [MCP tools specification](https://modelcontextprotocol.io/specification/2025-11-25/server/tools.md).

Tools are designed to be model-controlled, meaning the LLM decides when and how to use them based on the conversation context and user requests.

The tools system provides:
- `$DefaultMCPTools` - An association of predefined tool definitions
- Tools are specified via the `"Tools"` LLMEvaluator property
- Tools can be referenced by name (string) or defined inline (association)

## How Tools Work

### Protocol Flow

1. **Client requests tool list** (`tools/list`): Server returns available tools with names, descriptions, and JSON schemas for parameters
2. **Client invokes tool** (`tools/call`): Server executes the tool function with provided arguments
3. **Result returned**: The generated content is returned as a string to the LLM

### Tool Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `"Name"` | String | Yes | Unique identifier for the tool |
| `"DisplayName"` | String | No | Human-readable display name |
| `"Description"` | String | Yes | Detailed description of what the tool does |
| `"Function"` | Symbol | Yes | The Wolfram Language function to call |
| `"Parameters"` | List | Yes | Parameter specifications (see below) |
| `"Options"` | List | No | Tool options |
| `"LLMKit"` | String | No | Dependency: `"Suggested"`, `"Required"`, or `Automatic` |
| `"Initialization"` | Delayed | No | Optional initialization code run before first use |
| `"Overrides"` | Association or Delayed | No | Environment-specific property overrides merged in when the server state is built (see [Environment-Specific Overrides](#environment-specific-overrides)) |

## $DefaultMCPTools

The paclet provides `$DefaultMCPTools`, an association of predefined tool definitions:

```wl
$DefaultMCPTools = <|
    "WolframLanguageEvaluator" -> LLMTool[ ... ],
    "WolframContext"           -> LLMTool[ ... ],
    "WolframAlpha"             -> LLMTool[ ... ],
    ...
|>
```

### Available Tools

#### Context Tools

| Tool | Description | Server |
|------|-------------|--------|
| `WolframContext` | Semantic search across Wolfram resources (documentation, Wolfram Alpha, repositories, and more) | Wolfram |
| `WolframAlphaContext` | Semantic search for Wolfram Alpha results | WolframAlpha |
| `WolframLanguageContext` | Semantic search across Wolfram Language resources (documentation, function repository, data repository, neural net repository, and more) | WolframLanguage, WolframPacletDevelopment |

#### Code Execution Tools

| Tool | Description | Server |
|------|-------------|--------|
| `WolframLanguageEvaluator` | Evaluates Wolfram Language code with time constraints | Wolfram, WolframLanguage, WolframPacletDevelopment |
| `WolframAlpha` | Natural language queries to Wolfram Alpha | Wolfram, WolframAlpha |
| `SymbolDefinition` | Retrieves symbol definitions in readable markdown format | WolframLanguage, WolframPacletDevelopment |

#### Notebook Tools

| Tool | Description | Server |
|------|-------------|--------|
| `ReadNotebook` | Reads Wolfram notebooks (.nb) as markdown text | WolframLanguage, WolframPacletDevelopment |
| `WriteNotebook` | Converts markdown to Wolfram notebooks | WolframLanguage, WolframPacletDevelopment |

#### Testing Tools

| Tool | Description | Server |
|------|-------------|--------|
| `TestReport` | Runs Wolfram Language test files (.wlt) and returns a report | WolframLanguage, WolframPacletDevelopment |

#### Code Analysis Tools

| Tool | Description | Server |
|------|-------------|--------|
| `CodeInspector` | Inspects Wolfram Language code and returns a formatted report of issues | WolframLanguage, WolframPacletDevelopment |

#### Documentation Tools

| Tool | Description | Server |
|------|-------------|--------|
| `CreateSymbolDoc` | Creates new symbol documentation pages for paclets | WolframPacletDevelopment |
| `EditSymbolDoc` | Edits existing symbol documentation pages | WolframPacletDevelopment |
| `EditSymbolDocExamples` | Edits example sections of symbol documentation | WolframPacletDevelopment |

#### Paclet Release Tools

| Tool | Description | Server |
|------|-------------|--------|
| `CheckPaclet` | Checks a paclet for issues before building or submission | WolframPacletDevelopment |
| `BuildPaclet` | Builds a `.paclet` archive for distribution | WolframPacletDevelopment |
| `SubmitPaclet` | Submits a paclet to the Wolfram Language Paclet Repository | WolframPacletDevelopment |

#### MCP Apps Tools

| Tool | Description | Server |
|------|-------------|--------|
| `NotebookViewer` | Embeds interactive Wolfram Cloud notebooks inline | (available, not in default servers) |
| `MCPAppsTest` | Diagnostic tool for testing the MCP Apps pipeline | (available, not in default servers) |

> **Note:** When a client supports the `io.modelcontextprotocol/ui` extension, the `WolframAlpha` and `WolframLanguageEvaluator` tools are automatically enhanced with UI capabilities (e.g., deploying cloud notebooks and returning `_meta` with `notebookUrl`). See [mcp-apps.md](mcp-apps.md) for details.

## Tool Definition Format

### Structure

```wl
$defaultMCPTools[ "ToolName" ] := LLMTool @ <|
    "Name"           -> "ToolName",
    "DisplayName"    -> "Human Readable Name",
    "Description"    -> "Detailed tool description...",
    "Function"       -> toolFunction,
    "Options"        -> { },
    "Parameters"     -> { ... },
    "LLMKit"         -> "Suggested",           (* Optional *)
    "Initialization" :> initFunction[ ]        (* Optional *)
|>
```

### Parameter Specification

Parameters are specified as a list of rules, where each parameter is defined as:

```wl
"paramName" -> <|
    "Interpreter" -> "String" | "Integer" | "Boolean",
    "Help"        -> "Parameter description",
    "Required"    -> True | False
|>
```

**Example from WolframLanguageEvaluator:**

```wl
"Parameters" -> {
    "code" -> <|
        "Interpreter" -> "String",
        "Help"        -> "The Wolfram Language code to evaluate.",
        "Required"    -> True
    |>,
    "timeConstraint" -> <|
        "Interpreter" -> "Integer",
        "Help"        -> "The time constraint for the evaluation (default is 60 seconds).",
        "Required"    -> False
    |>
}
```

## Adding a New Tool

### Step 1: Create the Tool Definition File

Create a new file in `Kernel/Tools/` following this pattern:

```wl
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Tools`YourTool`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];
Needs[ "Wolfram`AgentTools`Tools`"  ];

(* ::Section::Closed:: *)
(*Prompts*)
$yourToolDescription = "\
Description of what your tool does.
Include usage guidance for the LLM.";

(* ::Section::Closed:: *)
(*Tool Definition*)
$defaultMCPTools[ "YourTool" ] := LLMTool @ <|
    "Name"        -> "YourTool",
    "DisplayName" -> "Your Tool Name",
    "Description" -> $yourToolDescription,
    "Function"    -> yourToolFunction,
    "Options"     -> { },
    "Parameters"  -> {
        "param1" -> <|
            "Interpreter" -> "String",
            "Help"        -> "Description of parameter",
            "Required"    -> True
        |>
    }
|>;

(* ::Section::Closed:: *)
(*Definitions*)
yourToolFunction // beginDefinition;

yourToolFunction[ KeyValuePattern[ "param1" -> value_ ] ] :=
    yourToolFunction @ value;

yourToolFunction[ value_String ] := Enclose[
    Module[ { result },
        result = ConfirmBy[ yourComputation @ value, StringQ, "Result" ];
        (* Tools must return a string *)
        result
    ],
    throwInternalFailure
];

yourToolFunction // endDefinition;

(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
```

### Step 2: Register the Subcontext

Add your new subcontext to `Kernel/Tools/Tools.wl`:

```wl
$subcontexts = {
    "Wolfram`AgentTools`Tools`Context`",
    "Wolfram`AgentTools`Tools`Notebooks`",
    (* ... existing subcontexts ... *)
    "Wolfram`AgentTools`Tools`YourTool`"  (* Add your new subcontext *)
};
```

### Step 3: Add to Server Configuration (Optional)

If you want the tool to be included in default servers, update `Kernel/DefaultServers.wl`:

```wl
$defaultMCPServers[ "ServerName" ] := <|
    "Name"          -> "ServerName",
    "Location"      -> "BuiltIn",
    "Transport"     -> "StandardInputOutput",
    "ServerVersion" -> $pacletVersion,
    "ObjectVersion" -> $objectVersion,
    "LLMEvaluator"  -> <|
        "Tools" -> {
            (* ... existing tools ... *)
            "YourTool"  (* Add your tool *)
        },
        "MCPPrompts" -> { ... }
    |>
|>
```

### Step 4: Write Tests

Add tests to `Tests/Tools.wlt`:

```wl
VerificationTest[
    $DefaultMCPTools[ "YourTool" ][ "Name" ],
    "YourTool",
    TestID -> "YourTool-Name"
]

VerificationTest[
    StringQ @ $DefaultMCPTools[ "YourTool" ][ "Description" ],
    True,
    TestID -> "YourTool-Description"
]
```

## Using Tools in Custom Servers

### Reference by Name

```wl
CreateMCPServer[ "MyServer", <|
    "Tools" -> { "WolframLanguageEvaluator", "WolframAlpha" }
|> ]
```

### Reference Paclet Tools

Tools contributed by third-party paclets can be referenced using paclet-qualified names:

```wl
CreateMCPServer[ "MyServer", <|
    "Tools" -> {
        "WolframLanguageEvaluator",
        "PublisherID/MyPaclet/CustomTool"
    }
|> ]
```

See [paclet-extensions.md](paclet-extensions.md) for details on how paclets declare tools.

### Inline Definition

```wl
CreateMCPServer[ "MyServer", <|
    "Tools" -> {
        LLMTool @ <|
            "Name"        -> "CustomTool",
            "Description" -> "Does something custom",
            "Function"    -> myFunction,
            "Parameters"  -> {
                "input" -> <| "Interpreter" -> "String", "Required" -> True |>
            }
        |>
    }
|> ]
```

## Tool Implementation Patterns

### KeyValuePattern Entry Point

Tools receive parameters as an association. Use `KeyValuePattern` to extract values:

```wl
toolFunction[ KeyValuePattern @ {
    "param1" -> value1_,
    "param2" -> value2_
} ] := toolFunction[ value1, value2 ];
```

### Handling Optional Parameters

Optional parameters may have value `Missing["NoInput"]`:

```wl
toolFunction[ KeyValuePattern @ {
    "required" -> value_,
    "optional" -> optional_
} ] := Module[ { opt },
    opt = Replace[ optional, Except[ _Integer ] -> 60 ];  (* Default value *)
    (* ... *)
];
```

### Using the Evaluator Kernel

For tools that need to access definitions from the evaluator kernel (when using external evaluation):

```wl
toolFunction[ args_ ] := useEvaluatorKernel @ toolFunction0 @ args;
```

### Honoring the Project Root

When the client advertises the `roots` capability, AgentTools selects a project directory and stores it in `$mcpRoot` (see [mcp-roots.md](mcp-roots.md)). The main server kernel and the local evaluator kernel are automatically `SetDirectory`'d to that path, so tools that evaluate Wolfram Language code or read files via `Import` etc. inherit the project root with no extra work.

Tools that spawn external processes via `RunProcess` should pass `ProcessDirectory -> $mcpRoot` (with a `None` fallback) so the child process also starts in the project root:

```wl
RunProcess[
    processArgs,
    ProcessDirectory -> If[ StringQ @ $mcpRoot, $mcpRoot, Inherited ]
]
```

`$mcpRoot` is exported from `Wolfram`AgentTools`Common``. Tools must tolerate `$mcpRoot === None` (no client root, capability not advertised, etc.) and fall back to the kernel's working directory.

### Initialization

Use the `"Initialization"` property for lazy setup (e.g., loading vector databases):

```wl
$defaultMCPTools[ "MyTool" ] := LLMTool @ <|
    (* ... *)
    "Initialization" :> initializeResources[ ]
|>
```

### Environment-Specific Overrides

A tool can behave differently depending on where the MCP server is running. Two exported symbols describe the host and are bound by each transport before the server's tool tables are built (both are `None` outside a server session):

| Symbol | Values |
|--------|--------|
| `$MCPEvaluationEnvironment` | `"Local"` for the stdio server started by `StartMCPServer`; `"Cloud"` for a [cloud-deployed server](cloud-deployment.md) |
| `$MCPTransport` | `"StandardInputOutput"` for the stdio transport; `"StreamableHTTP"` for the cloud (Streamable HTTP) transport |

The `"Overrides"` property is a (typically delayed) association of tool properties that is merged into the tool definition at that point, so one tool name can present a different description, parameter set, and implementation per environment:

```wl
$defaultMCPTools[ "WriteNotebook" ] := LLMTool @ <|
    "Name"        -> "WriteNotebook",
    "Description" -> "Converts markdown text to a Wolfram notebook and saves it to a file.",
    "Function"    -> writeNotebook,
    "Parameters"  -> { (* file, overwrite, markdown *) },
    "Overrides"   :> If[ $MCPEvaluationEnvironment === "Cloud", $writeNotebookCloudOverrides, <| |> ]
|>;

$writeNotebookCloudOverrides = <|
    "Description" -> "Converts markdown text to a Wolfram notebook and deploys it to a cloud object.",
    "Function"    -> writeCloudNotebook,
    "Parameters"  -> { (* path, permissions, overwrite, markdown *) }
|>;
```

Overrides replace whole properties (e.g. the entire `"Parameters"` list); `<| |>` or `None` leaves the tool unchanged. They are applied by `initializeServerState` (both transports) and by `serverToolListData` (the cloud landing page's `/api/info`), not when a tool is evaluated directly, so `$DefaultMCPTools["WriteNotebook"]` always holds the local definition.

Two further exported symbols describe the product rather than the transport: `$StandaloneMCPServer` is `True` when the kernel is the standalone MCP server product (a kernel that only runs the MCP server, without a full Mathematica installation), and `$StandaloneMCPServerInformation` holds the information that product publishes about itself. Both are set by the standalone application and are `False` and `<| |>` everywhere else; see [usage-data.md](usage-data.md#standalone-mcp-server).

## Tool Output Format

Tools must return strings. For structured output, use consistent formats:

### Markdown Output

```wl
"# Result\n\n## Section\n\n```wl\ncode\n```"
```

### Error Messages

Return error information as part of the string:

```wl
"Error: Invalid input \"" <> input <> "\""
```

### Image Output

Images can be exported to cloud and returned as markdown links:

```wl
"![Image](" <> cloudURL <> ")"
```

## Error Handling

Tools should handle errors gracefully using the standard error handling pattern:

```wl
toolFunction[ args_ ] := Enclose[
    Module[ { result },
        result = ConfirmBy[ computation[ args ], StringQ, "Result" ];
        result
    ],
    throwInternalFailure
];
```

The server wraps tool calls with error handling that converts failures to error messages rather than MCP protocol errors.

## LLMKit Dependency

Tools can specify their LLMKit dependency:

| Value | Meaning |
|-------|---------|
| `"Required"` | Tool will fail without LLMKit subscription |
| `"Suggested"` | Tool works better with LLMKit but has fallback |
| `Automatic` | No special dependency |

Example:

```wl
$defaultMCPTools[ "WolframAlphaContext" ] := LLMTool @ <|
    (* ... *)
    "LLMKit" -> "Required"
|>
```

## Tool Options

Tools can define configurable options that users can customize at install time via the `"ToolOptions"` option on `InstallMCPServer`. This allows controlling tool behavior without modifying source code.

### How Tool Options Work

1. **Default values** are defined per-tool in `$defaultToolOptions` (alongside tool definitions in `Kernel/Tools/`)
2. **User overrides** are passed via `"ToolOptions"` when calling `InstallMCPServer`
3. **At install time**, options are serialized to the `MCP_TOOL_OPTIONS` environment variable in the server configuration
4. **At runtime**, `$toolOptions` is populated from this environment variable at server startup
5. **Tool code** reads options via `toolOptionValue[toolName, optionName]`, which falls back from user override to default

### Defining Default Options

Default options are defined alongside the tool definition using `$defaultToolOptions`:

```wl
$defaultToolOptions[ "YourTool" ] = <|
    "OptionName" -> defaultValue
|>;
```

### Reading Options in Tool Code

Use `toolOptionValue` to read an option with automatic fallback:

```wl
toolOptionValue[ "YourTool", "OptionName" ]
```

The lookup priority is:
1. `$toolOptions` (user-specified via `MCP_TOOL_OPTIONS`) — highest priority
2. `$defaultToolOptions` — lowest priority
3. `Missing["ToolOption", ...]` if not found

A common pattern is to define a file-scoped variable that reads the option lazily:

```wl
$myOption := toolOptionValue[ "YourTool", "OptionName" ];
```

### Per-Tool Option Reference

#### WolframLanguageEvaluator

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `"Method"` | String | `Automatic` | Evaluation method. `"Session"` uses the server kernel; `"Local"` spawns a separate sandboxed kernel; `"Cloud"` runs each evaluation in a fresh Wolfram Cloud kernel. `Automatic` means `"Cloud"` when the server itself runs in the cloud (see [cloud-deployment.md](cloud-deployment.md)) and `"Session"` otherwise. |
| `"ImageExportMethod"` | String | `None` | How to export graphics. `None`, `"Local"`, `"Cloud"`, or `"CloudPublic"`. |
| `"TimeConstraint"` | Integer | `60` | Default time limit (seconds) when the LLM doesn't specify `timeConstraint`. The LLM can still override this per-call. |
| `"MaxSessionCount"` | Integer | `100` | Maximum number of saved evaluator sessions to keep (oldest pruned first; the current session is always kept). |
| `"MaxSessionBytes"` | Integer | `1073741824` | Total byte budget for saved evaluator sessions. |
| `"MaxSessionAge"` | Quantity | `Quantity[1, "Months"]` | Saved evaluator sessions older than this are pruned. |

##### Sessions

The evaluator's optional `session` parameter gives each conversation an isolated, resumable session
(its definitions, line numbers, and In/Out history). Sessions are saved under
`$UserBaseDirectory/ApplicationData/Wolfram/AgentTools/Sessions/` after every call, so they survive
server restarts, and every result ends with a reminder of the session ID to pass on subsequent calls.

With Chatbook 2.7.28+, each top-level input of the code gets its own line number, as in an interactive
kernel session (`1 + 1` and `2 + 2` on separate lines give `Out[1]= 2` and `Out[2]= 4`), so one call can
use up several lines. Chatbook reports the line number for the next input (the `"Line"` property of
`WolframLanguageToolEvaluate`), and the session continues from there. Session bookkeeping in the `"Local"`
eval kernel is evaluated with `"Line" -> None`, so it uses no line number and stays out of the In/Out
history. Older Chatbook versions evaluate the code as a single input, so the line number advances by one
per call.

Under the `"Cloud"` method each call runs in a fresh, non-persistent cloud kernel, so only a session's
**global definitions** persist: Chatbook 2.7.11+ returns the evaluator kernel's `` Global` `` definitions
after each call as an MX byte array (`Wolfram`Chatbook`$CloudSessionMX`), which AgentTools stores in
the session file and hands back before the next call. Loaded packages, In/Out history, `%`, and any
other kernel state are lost between calls, and each result's session reminder says so (with an older
Chatbook on the server it says that definitions cannot be restored at all).

#### WolframLanguageContext

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `"MaxItems"` | Integer | `10` | Number of documentation results to return. |

#### WolframAlphaContext

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `"MaxItems"` | Integer or `Automatic` | `Automatic` | Maximum number of Wolfram\|Alpha results. `Automatic` uses internal defaults. |
| `"IncludeWolframLanguageResults"` | Boolean or `Automatic` | `Automatic` | Whether to include Wolfram Language code results. |

#### WolframContext

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `"WolframLanguageMaxItems"` | Integer | `10` | Max documentation results (independent of `WolframLanguageContext` options). |
| `"WolframAlphaMaxItems"` | Integer or `Automatic` | `Automatic` | Max Wolfram\|Alpha results (independent of `WolframAlphaContext` options). |

Because the combined tool provides documentation results alongside the Wolfram\|Alpha results, it also passes `"DocumentationProvided" -> True` to `RelatedWolframAlphaResults` so that queries better answered by documentation are skipped. The option only exists in newer Chatbook versions (2.7.2+), so it is passed only when the loaded Chatbook actually supports it (detected via `documentationProvidedAvailableQ` in `Kernel/Tools/Context.wl`).

### User-Facing Usage

Users customize tool options when installing an MCP server:

```wl
InstallMCPServer[
    "ClaudeCode",
    "WolframLanguage",
    "ToolOptions" -> <|
        "WolframLanguageEvaluator" -> <|"Method" -> "Local", "TimeConstraint" -> 120|>,
        "WolframLanguageContext"   -> <|"MaxItems" -> 20|>
    |>
]
```

## Related Files

- `Kernel/Tools/Tools.wl` - Main tools module, defines `$DefaultMCPTools`
- `Kernel/Tools/Context.wl` - Context tools (WolframContext, WolframAlphaContext, WolframLanguageContext)
- `Kernel/Tools/WolframLanguageEvaluator.wl` - Code evaluation tool (with UI-enhanced mode)
- `Kernel/Tools/WolframAlpha.wl` - Wolfram Alpha query tool (with UI-enhanced mode)
- `Kernel/Tools/NotebookViewer.wl` - Embedded notebook viewer tool (MCP Apps)
- `Kernel/Tools/MCPAppsTest.wl` - MCP Apps diagnostic tool
- `Kernel/Tools/SymbolDefinition.wl` - Symbol definition lookup tool
- `Kernel/Tools/Notebooks.wl` - ReadNotebook and WriteNotebook tools
- `Kernel/Tools/TestReport.wl` - Test runner tool
- `Kernel/Tools/CodeInspector/` - Code inspection tool
- `Kernel/Tools/PacletDocumentation/` - Documentation editing tools
- `Kernel/Tools/PacletTools/` - Paclet check/build/submit tools
- `Kernel/UIResources.wl` - UI resource registry for MCP Apps
- `Kernel/MCPServerObject.wl` - Tool validation and normalization
- `Kernel/Server/Shared.wl` - Protocol handling for `tools/list` and `tools/call` (including `toolSchema`, which sanitizes tool schema `"pattern"` fields for JSON Schema consumers)
- `Kernel/Utilities.wl` - `toJSRegex`, the ICU/PCRE → ECMA 262 regex conversion used by `toolSchema`
- `Kernel/DefaultServers.wl` - Server configurations with `"Tools"` settings
- `Assets/Apps/` - HTML and JSON files for MCP Apps UI resources
- `Kernel/PacletExtension.wl` - Paclet-qualified tool resolution (see [paclet-extensions.md](paclet-extensions.md))
- `Kernel/MCPRoots.wl` - Project-root handshake (`$mcpRoot`); see [mcp-roots.md](mcp-roots.md)
- `Tests/Tools.wlt` - Tests for tool functionality
- `Tests/PacletTools.wlt` - Tests for CheckPaclet, BuildPaclet, and SubmitPaclet
- `Tests/ToolOptions.wlt` - Tests for tool options system
- `Specs/ToolOptions.md` - Design specification for tool options
- `AgentSkills/Manifest.wl` - Maps tools to distributable agent skills (see [agent-skills.md](agent-skills.md))
- `Scripts/BuildAgentSkills.wls` - Generates standalone `.wls` scripts from tool definitions and writes the built skills to `Assets/AgentSkills/` (rebuild and commit after changing a tool that a skill uses; `Tests/AgentSkillsBuild.wlt` fails when the built skills are stale)
