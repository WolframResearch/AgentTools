# Paclet Extension — Design Specification

## Overview

External Wolfram paclets can contribute MCP servers, tools, and prompts by declaring a custom `"AgentTools"` extension in their `PacletInfo.wl`. AgentTools discovers these extensions via the PacletManager and exposes them through the existing APIs (`MCPServerObject`, `InstallMCPServer`, `CreateMCPServer`, etc.). This leverages the Wolfram Paclet Repository as a distribution mechanism for AgentTools extensions.

> **See also:** [AgentToolsObject.md](AgentToolsObject.md) extends this design: a paclet may have several `"AgentTools"` entries (all applicable entries are used, items are paclet-scoped, and definition files are looked up in every entry's root), entries can declare `"AgentSkills"`, and each entry that declares servers or skills defines a bundle (`AgentToolsObject`). It also describes the additional entry keys (`"Name"`, `"Description"`, `"AgentSkills"`, `"SystemID"`, `"WolframVersion"`) and validation checks. Where the two documents differ, AgentToolsObject.md takes precedence.

---

## Goals

- Allow third-party paclets to contribute MCP servers, tools, and prompts without modifying the AgentTools paclet.
- Leverage the Wolfram Paclet Repository for distribution and version management.
- Maintain security by never auto-installing paclets and clearly separating discovery from code execution.
- Seamlessly integrate with existing APIs.
- Support flexible declaration formats — from minimal (names only) to rich (full metadata).

---

## Naming Convention

Paclet-defined items use a fully qualified name constructed from the paclet name and the item name:

```
"PacletName/ItemName"
```

Since paclet names may include a publisher prefix (e.g., `"Wolfram/JIRALink"`), this can result in either a two-segment or three-segment name:

- **Two-segment** — for paclets without a publisher prefix: `"PacletName/ItemName"`
- **Three-segment** — for paclets with a publisher prefix: `"PublisherID/PacletShortName/ItemName"`

Examples:

```wl
(* Paclet with publisher prefix: "Wolfram/JIRALink" *)
"Wolfram/JIRALink/GetIssue"            (* tool *)
"Wolfram/JIRALink/ProjectManagement"   (* server *)
"Wolfram/JIRALink/IssueText"           (* prompt *)

(* Paclet without publisher prefix: "JIRALink" *)
"JIRALink/GetIssue"                    (* tool *)
"JIRALink/ProjectManagement"           (* server *)
"JIRALink/IssueText"                   (* prompt *)
```

Names containing `/` are reserved for paclet-defined items. Built-in names (e.g., `"WolframAlpha"`, `"WolframLanguage"`) never contain `/`.

### Naming Scope

The `PacletName/ItemName` convention applies to **WL lookup/resolution keys** — internal identifiers used for cross-referencing tools and prompts within `CreateMCPServer`, `MCPServerObject`, and server definition files. These are not the names exposed to MCP clients.

The **MCP-exposed name** (what clients see in `tools/list` and `prompts/list` responses) is determined by the `"Name"` property in the tool or prompt definition file. By default, the MCP-exposed name is the short item name (e.g., `"GetIssue"`), not the fully qualified name.

Example:

```wl
(* In WL code, the fully qualified key is used: *)
CreateMCPServer["MyServer", <|
    "Tools" -> {"Wolfram/JIRALink/GetIssue"}
|>]

(* But the MCP client sees the short name from the definition file: *)
(* tools/list response includes: {"name": "GetIssue", ...} *)
```

This means two paclets could both define a tool with the MCP-exposed name `"Search"` without conflict at the WL level (they have distinct qualified keys), but would conflict if included in the same MCP server (duplicate MCP names). When this occurs, `StartMCPServer` automatically disambiguates by appending numeric suffixes (e.g., `"Search1"`, `"Search2"`). The tool descriptions already contain enough context for the AI to select the correct tool. See [MCP Name Collision Handling](#mcp-name-collision-handling) for details.

### Config Key (MCPServerName)

When a paclet extension server is installed via `InstallMCPServer`, the key used in the client configuration file (e.g., `claude_desktop_config.json`) defaults to the **short server name** (the item name part), not the fully qualified name. For example, installing `"Wolfram/JIRALink/ProjectManagement"` produces a config entry keyed as `"ProjectManagement"`.

This keeps tool names well within MCP's character limits and produces cleaner configuration files. The fully qualified name is still used internally for server lookup and the `MCP_SERVER_NAME` environment variable.

The config key can be overridden:
- By specifying `"MCPServerName"` in the server definition file
- By passing the `"MCPServerName"` option to `InstallMCPServer`

---

## PacletInfo Extension Declaration

A paclet declares MCP items by adding an `"AgentTools"` extension to its `PacletInfo.wl`:

```wl
PacletObject[ <|
    "Name"           -> "Wolfram/JIRALink",
    "Version"        -> "1.0.0",
    "PublisherID"    -> "Wolfram",
    "PrimaryContext" -> "Wolfram`JIRALink`",
    "Extensions"     -> {
        { "Kernel",
            "Root"    -> "Kernel",
            "Context" -> { "Wolfram`JIRALink`" }
        },
        { "AgentTools",
            "Root"       -> "AgentTools",
            "MCPServers" -> { "ProjectManagement" },
            "Tools"      -> {
                { "CreateIssue",  "Create a new JIRA issue" },
                { "DeleteIssue",  "Delete a JIRA issue" },
                { "GetIssue",     "Get a JIRA issue by key" },
                { "SearchIssues", "Search for JIRA issues" }
            },
            "MCPPrompts" -> { "IssueText" }
        }
    }
|> ]
```

### Extension Properties

| Property | Type | Required | Default | Description |
|---|---|---|---|---|
| `"Root"` | `String` | No | `"AgentTools"` | Subdirectory for definition files. Resolved by ``PacletTools`PacletExtensionDirectory``. |
| `"MCPServers"` | `List` | No | `{}` | Server declarations. |
| `"Tools"` | `List` | No | `{}` | Tool declarations. |
| `"MCPPrompts"` | `List` | No | `{}` | Prompt declarations. |

**PacletTools dependency:** The implementation must call ``Needs["PacletTools`"]`` before using ``PacletTools`PacletExtensions`` (to discover paclets with `"AgentTools"` extensions) and ``PacletTools`PacletExtensionDirectory`` (to resolve the root directory for definition files). These are not `System` symbols.

### Three-Tier Declaration Format

Each of `"MCPServers"`, `"Tools"`, and `"MCPPrompts"` accepts three declaration forms. All three can be mixed freely within a single list. The name + description form is encouraged but not enforced.

#### Name Only

```wl
"Tools" -> { "CreateIssue", "GetIssue" }
```

#### Name + Description (Encouraged)

```wl
"Tools" -> {
    { "CreateIssue",  "Create a new JIRA issue" },
    { "GetIssue",     "Get a JIRA issue by key" }
}
```

#### Association

```wl
"Tools" -> {
    <| "Name"        -> "CreateIssue",
       "Description" -> "Create a new JIRA issue",
       "Parameters"  -> { "summary", "description", "projectKey" } |>,
    <| "Name"        -> "GetIssue",
       "Description" -> "Get a JIRA issue by key",
       "Parameters"  -> { "issueKey" } |>
}
```

The association form supports additional keys depending on the item type:

| Item Type | Extra Keys | Description |
|---|---|---|
| Servers | `"Tools"`, `"MCPPrompts"` | Lists of tool/prompt names this server uses |
| Tools | `"Parameters"` | List of parameter names (strings) or basic parameter associations |
| Prompts | `"Arguments"` | List of argument names |

**Note:** Because PacletInfo files do not allow arbitrary expressions, only basic types (strings, integers, lists, associations with string keys and simple values) are permitted. Complex specifications like `Interpreter` functions, delayed rules, or symbol references belong in definition files.

---

## Definition File Layout

### Per-Item Files (Default)

Each declared item has its own file in the extension root directory:

```
MyPaclet/
    PacletInfo.wl
    Kernel/
        ...
    AgentTools/                      (* Root from "Root" -> "AgentTools" *)
        MCPServers/
            ProjectManagement.wl
        Tools/
            CreateIssue.wl
            DeleteIssue.wl
            GetIssue.wl
            SearchIssues.wl
        MCPPrompts/
            IssueText.wl
```

### Combined Files (Alternative)

For simpler paclets, all items of a type can be defined in a single file. The file must evaluate to an `Association` keyed by item name.

```
MyPaclet/
    AgentTools/
        MCPServers.wl
        Tools.wl
        MCPPrompts.wl
```

Example combined `Tools.wl`:

```wl
(* AgentTools/Tools.wl *)
<|
    "CreateIssue" -> <|
        "Name"        -> "CreateIssue",
        "Description" -> "Create a new JIRA issue",
        "Function"    -> Wolfram`JIRALink`CreateIssue,
        "Parameters"  -> { ... }
    |>,
    "GetIssue" -> <|
        "Name"        -> "GetIssue",
        "Description" -> "Get a JIRA issue by key",
        "Function"    -> Wolfram`JIRALink`GetIssue,
        "Parameters"  -> { ... }
    |>
|>
```

### Supported File Formats

| Extension | Load Method | Use Case |
|---|---|---|
| `.wl` | `Get` | Standard — Wolfram Language source |
| `.mx` | `Import[..., "MX"]` | Compiled — faster loading, platform-specific |
| `.wxf` | `readWXFFile[...]` | Serialized data — portable binary format |

### Resolution Order

When loading a definition for item `"GetIssue"` of type `"Tools"`:

1. **Per-item file:** `First @ FileNames[ "GetIssue." ~~ ("mx"|"wl"|"wxf"), "<root>/Tools" ]`
2. **Combined file:** `First @ FileNames[ "Tools." ~~ ("mx"|"wl"|"wxf"), "<root>" ]` — look up `"GetIssue"` key

When loading a definition for type `"MCPServers"`, the subdirectory and combined file names use `MCPServers` (e.g., `<root>/MCPServers/` and `MCPServers.wl`). Similarly for `"MCPPrompts"`.

Per-item files take precedence over combined files. If multiple definition files exist for the same item (e.g., both `GetIssue.wl` and `GetIssue.mx`), the priority order is `.mx` > `.wxf` > `.wl` (preferring compiled formats for performance). `ValidateAgentToolsPacletExtension` warns about duplicate definition files.

---

## Definition File Contents

### Server Definitions

Importing a server definition file must give an `Association`:

```wl
(* AgentTools/MCPServers/ProjectManagement.wl *)
<|
    "Name"           -> "ProjectManagement",
    "Initialization" :> Needs[ "Wolfram`JIRALink`" ],
    "LLMEvaluator"   -> <|
        "Tools"      -> { "CreateIssue", "DeleteIssue", "GetIssue", "SearchIssues" },
        "MCPPrompts" -> { "IssueText" }
    |>
|>
```

Tool and prompt names within `"LLMEvaluator"` use short names that resolve within the paclet first (see [Name Resolution](#name-resolution)).

| Key | Type | Required | Default | Description |
|---|---|---|---|---|
| `"Name"` | `String` | No | Extension item name | Server display name |
| `"MCPServerName"` | `String` | No | Short server name | Config key used when installing via `InstallMCPServer` |
| `"Initialization"` | `RuleDelayed` | No | `None` | Delayed initialization code |
| `"LLMEvaluator"` | `Association` | Yes | — | Server configuration (tools, prompts) |
| `"Transport"` | `String` | No | `"StandardInputOutput"` | Transport protocol |
| `"ServerVersion"` | `String` | No | Paclet version | MCP server version |

### Tool Definitions

A tool definition file must evaluate to either an `Association` compatible with `LLMTool` or an explicit `LLMTool[...]` expression.

#### Association Form

The association form is recommended for most cases, as it separates metadata from implementation and supports additional keys like `"Initialization"` and `"Options"`:

```wl
(* AgentTools/Tools/GetIssue.wl *)
<|
    "Name"        -> "GetIssue",
    "Description" -> "Get a JIRA issue by its key",
    "Function"    -> Wolfram`JIRALink`GetIssue,
    "Parameters"  -> {
        "issueKey" -> <|
            "Interpreter" -> "String",
            "Help"        -> "The JIRA issue key (e.g. PROJ-123)",
            "Required"    -> True
        |>
    }
|>
```

| Key | Type | Required | Description |
|---|---|---|---|
| `"Name"` | `String` | Yes | Tool name |
| `"Description"` | `String` | Yes | Description shown to the LLM |
| `"Function"` | `Symbol` or `Function` | Yes | The function to call |
| `"Parameters"` | `List` | Yes | Parameter specifications |
| `"DisplayName"` | `String` | No | Human-readable display name |
| `"Initialization"` | `RuleDelayed` | No | Delayed initialization code |
| `"Options"` | `List` | No | Tool options |

#### Explicit LLMTool Form

Definition files may also evaluate directly to an `LLMTool[...]` expression. This is convenient for simple tools where the standard `LLMTool` constructor arguments are sufficient:

```wl
(* AgentTools/Tools/Increment.wl *)
LLMTool[ "Increment", { "x" -> "Integer" }, #x + 1 & ]
```

When a definition file evaluates to an `LLMTool[...]`, the tool is used as-is without further construction. The tool name for resolution purposes is extracted from the `LLMTool` expression (i.e., the first argument). Extension-level keys like `"Initialization"` and `"Options"` are not available in this form — use the association form if those are needed.

In combined definition files (`Tools.wl`), values may also be `LLMTool[...]` expressions:

```wl
(* AgentTools/Tools.wl *)
<|
    "Increment" -> LLMTool[ "Increment", { "x" -> "Integer" }, #x + 1 & ],
    "GetIssue"  -> <| "Name" -> "GetIssue", ... |>
|>
```

### Prompt Definitions

A prompt definition file must evaluate to an `Association`:

```wl
(* AgentTools/MCPPrompts/IssueText.wl *)
<|
    "Name"        -> "IssueText",
    "Description" -> "Format a JIRA issue for display",
    "Arguments"   -> {
        <| "Name" -> "issueKey", "Description" -> "The issue key", "Required" -> True |>
    },
    "Type"        -> "Function",
    "Content"     -> Wolfram`JIRALink`FormatIssueText
|>
```

### Initialization

Initialization code belongs **only** in definition files, never in PacletInfo. It uses delayed evaluation (`:>`) and runs at server start time.

Common patterns:

```wl
(* Load the paclet's primary context *)
"Initialization" :> Needs[ "Wolfram`JIRALink`" ]

(* Multiple initialization steps *)
"Initialization" :> (
    Needs[ "Wolfram`JIRALink`" ];
    Wolfram`JIRALink`ConfigureAPI[ ]
)
```

---

## Name Resolution

| Context | Short name resolves to | Example |
|---|---|---|
| User code (e.g., `CreateMCPServer`) | Built-in tools only | `"WolframAlpha"` → `$DefaultMCPTools["WolframAlpha"]` |
| Within a paclet's own definition files | Own paclet first, then built-in | `"GetIssue"` → `"Wolfram/JIRALink/GetIssue"` |
| Cross-paclet reference | Must use fully qualified name | `"Wolfram/SlackLink/PostMessage"` |
| Fully qualified name anywhere | Specific paclet tool | `"Wolfram/JIRALink/GetIssue"` |

### Resolution Chain

The existing `convertStringTools0` in `Kernel/MCPServerObject.wl` currently checks:

1. `$DefaultMCPTools[name]` — built-in AgentTools tools
2. ``cb`$AvailableTools[name]`` — Chatbook tools (where ``cb`` is a context alias for ``Wolfram`Chatbook` ``)
3. `LLMResourceTool[name]` — Wolfram resource tools

The new resolution adds a check for `/`-containing names that routes through paclet tool resolution:

```wl
convertStringTools0[ name_String ] /; KeyExistsQ[ $DefaultMCPTools, name ] :=
    $DefaultMCPTools[ name ];

convertStringTools0[ name_String ] /; pacletQualifiedNameQ[ name ] :=
    resolvePacletTool[ name ];

convertStringTools0[ name_String ] :=
    Lookup[ cb`$AvailableTools, name, tryResourceTool @ name ];
```

Built-in tools always take precedence for short (unqualified) names.

### Intra-Paclet Name Resolution

When loading a paclet's server definition file, tool and prompt names within `"LLMEvaluator"` are short names that should resolve within the owning paclet first. To support this, the system pre-qualifies short names to fully qualified names at definition file load time. When a server definition is loaded from paclet `"Wolfram/JIRALink"`, a tool reference `"GetIssue"` is rewritten to `"Wolfram/JIRALink/GetIssue"` before being stored in the metadata association. Names that already contain `/` (fully qualified or cross-paclet references) are left unchanged. This avoids the need for dynamic resolution context during tool/prompt resolution.

---

## Security Model

### Trust Levels

| Level | Trigger | PacletInfo | Definition Files | Tool/Init Execution |
|---|---|---|---|---|
| **Discovery** | `MCPServerObjects[]`, `PacletFind` | Yes | No | No |
| **Inspection** | `MCPServerObject["Wolfram/JIRALink/PM"]` | Yes | Yes (installed only) | No |
| **Execution** | `StartMCPServer`, `InstallMCPServer` | Yes | Yes | Yes |

**Note on definition file loading:** Loading `.wl` definition files for installed paclets uses `Get`, which evaluates the file contents. This is analogous to ``Needs["Wolfram`JIRALink`"]`` — installed paclets are trusted code. Definition files should evaluate to inert data (associations of strings, lists, and delayed rules) or standard `LLMTool[...]` expressions, and should not have side effects. `ValidateAgentToolsPacletExtension` can verify that definition files produce well-formed associations. The "Tool/Init Execution" column above distinguishes this code-loading step from active execution of tool functions and `"Initialization"` code, which only occurs at the Execution level.

### Installed = Trusted

When a user writes `MCPServerObject["Wolfram/JIRALink/ProjectManagement"]`, they are explicitly referencing a paclet-qualified name. If the paclet is locally installed, AgentTools loads its definition files. This is analogous to how ``Needs["Wolfram`JIRALink`"]`` trusts installed paclets.

### Paclet Installation Policy

Metadata-only operations (`MCPServerObject`, `MCPServerObjects`) must **never** call `PacletInstall` automatically. These functions work with PacletInfo metadata from `PacletFindRemote` and should not trigger code execution.

Execution-level operations (`InstallMCPServer`, `StartMCPServer`) automatically install the referenced paclet via `PacletInstall` if it is not already installed. This is safe because these operations represent explicit user intent: `InstallMCPServer` is a direct request to set up a server, and `StartMCPServer` runs only on servers the user has opted into (via `InstallMCPServer` or manual config editing). Since the user would never see error messages in a running MCP server process, failing silently with a `PacletNotInstalled` error would be unhelpful.

### Uninstalled Paclet Behavior

For uninstalled paclets discovered via `PacletFindRemote`, only PacletInfo metadata is available. `MCPServerObject` properties that require loading definition files return a failure:

```wl
MCPServerObject["Unknown/Paclet/Server"]["Tools"]
(* Failure["PacletNotInstalled", <|
       "MessageTemplate" -> "The paclet \"`1`\" is not installed. Evaluate `2` to install it.",
       "MessageParameters" -> {"Unknown/Paclet", HoldForm[PacletInstall["Unknown/Paclet"]]}
   |>] *)
```

`"ToolNames"` and `"PromptNames"` also require the paclet to be installed, since they derive per-server membership from definition files:

```wl
MCPServerObject["Unknown/Paclet/Server"]["ToolNames"]
(* Failure["PacletNotInstalled", <|
       "MessageTemplate" -> "The paclet \"`1`\" is not installed. Evaluate `2` to install it.",
       "MessageParameters" -> {"Unknown/Paclet", HoldForm[PacletInstall["Unknown/Paclet"]]}
   |>] *)
```

`InstallMCPServer` and `StartMCPServer` automatically call `PacletInstall` as needed to ensure the paclet is available before proceeding (see [Paclet Installation Policy](#paclet-installation-policy)).

---

## Integration with Existing APIs

### MCPServerObject

`MCPServerObject[name_String]` is extended to handle paclet-qualified names. If `name` contains `/`, it is parsed as a paclet-qualified name and resolved via the paclet extension system.

Resolution order for `getMCPServerObjectByName`:

1. File-based servers (existing — user-created via `CreateMCPServer`)
2. Built-in servers (existing — `$DefaultMCPServers`)
3. Installed paclet servers (new — scan installed paclets with `"AgentTools"` extension)
4. Remote paclet servers (new — `PacletFindRemote`, metadata only; supports `UpdatePacletSites` option)

The `"Location"` property for paclet-defined servers is `PacletObject["Wolfram/JIRALink"]`:

```wl
MCPServerObject["Wolfram/JIRALink/ProjectManagement"]["Location"]
(* PacletObject["Wolfram/JIRALink"] *)
```

The following patterns and functions in `Kernel/MCPServerObject.wl` must be updated to handle paclet-backed servers:

- **`$$metadata` pattern:** Add `_PacletObject` as a valid `"Location"` value (currently only accepts `_File? fileQ | "BuiltIn"`).
- **`$specialProperties`:** Add `"ToolNames"` and `"PromptNames"`.
- **`mcpServerExistsQ`:** Add a case for `_PacletObject` locations — check if the paclet is installed via `PacletFind` (e.g., `mcpServerExistsQ[as_, paclet_PacletObject] := Length[PacletFind[paclet["Name"]]] > 0`).
- **`deleteMCPServer`:** Add a case for `_PacletObject` locations — refuse deletion with an error message, analogous to the existing `"BuiltIn"` case (e.g., `throwFailure["DeletePacletMCPServer", name]`). Paclet servers should be removed by uninstalling the paclet, not via `DeleteObject`.

### Paclet Server Metadata Construction

When `MCPServerObject` resolves a paclet-qualified server name, it constructs a metadata association:

- **Installed paclets:** The server definition file is loaded (via `loadPacletDefinitionFile`). Short tool/prompt names in `"LLMEvaluator"` are pre-qualified to fully qualified names. The resulting metadata has `"Location" -> PacletObject[...]`.
- **Uninstalled remote paclets (metadata only):** Only PacletInfo metadata is available. A partial metadata association is constructed with `"Name"`, `"Location"`, `"Transport"` (default), `"ServerVersion"` (from paclet version), and `"LLMEvaluator"` containing only tool/prompt name strings from PacletInfo declarations (no loaded `LLMTool` objects). Properties that require definition file loading (e.g., `"Tools"`) return a `PacletNotInstalled` failure.

New properties:

| Property | Description |
|---|---|
| `"ToolNames"` | List of tool name strings for this server. For installed paclets, derived from the server definition file's `"LLMEvaluator"` `"Tools"` list. For uninstalled paclets, returns `Failure["PacletNotInstalled", ...]`. |
| `"PromptNames"` | List of prompt name strings for this server. Same resolution behavior as `"ToolNames"`. |

### MCPServerObjects

**Behavior change:** `MCPServerObjects[]` currently returns only file-based (user-created) servers. This is extended to also include installed paclet servers, since they represent user-installed extensions analogous to user-created servers. Built-in servers are **not** included by default to preserve backward compatibility.

New options `"IncludeBuiltIn"`, `"IncludeRemotePaclets"`, and `UpdatePacletSites`:

```wl
MCPServerObjects[]                                    (* file-based + installed paclet servers *)
MCPServerObjects["IncludeBuiltIn" -> True]            (* also includes built-in servers *)
MCPServerObjects["IncludeRemotePaclets" -> True]      (* also includes uninstalled paclet servers from the Paclet Repository *)
MCPServerObjects["IncludeRemotePaclets" -> True,
    UpdatePacletSites -> True]                         (* force refresh of cached remote paclet site data *)
```

The function signature is extended to accept options alongside the existing pattern argument:

```wl
MCPServerObjects[ pattern: All | _String? StringQ : All, opts: OptionsPattern[] ]
```

| Option | Default | Description |
|---|---|---|
| `"IncludeBuiltIn"` | `False` | Include built-in servers from `$DefaultMCPServers` |
| `"IncludeRemotePaclets"` | `False` | Include uninstalled paclet servers from the Paclet Repository |
| `UpdatePacletSites` | `False` | Force refresh of cached remote paclet site data (passed through to `PacletFindRemote`) |

`UpdatePacletSites` is passed through to `PacletFindRemote`. By default, the PacletManager uses cached remote paclet site data, so `"IncludeRemotePaclets" -> True` is fast after the first call. Use `UpdatePacletSites -> True` to force a refresh.

### CreateMCPServer

Paclet tool name strings (containing `/`) are stored as-is without resolving. They are resolved dynamically when `obj["Tools"]` is accessed or at `StartMCPServer` time.

**Implementation note:** The current `CreateMCPServer` flow passes tool strings through `validateMCPServerObjectData` → `validateTools` → `convertStringTools`, which attempts resolution at creation time. `convertStringTools0` and `validateTool` must be modified to pass through `/`-containing strings without attempting resolution, so that paclet-qualified names survive as plain strings in `Metadata.wxf`.

```wl
CreateMCPServer[ "MyServer", <|
    "Tools" -> {
        "Wolfram/JIRALink/GetIssue",    (* stored as string, resolved later *)
        "WolframAlpha"                   (* resolved now from $DefaultMCPTools *)
    }
|> ]
```

### InstallMCPServer

Supports paclet-qualified server names. Automatically installs the referenced paclet via `PacletInstall` if not already present:

```wl
InstallMCPServer[ "ClaudeCode", "Wolfram/JIRALink/ProjectManagement" ]
```

**Validation at install time:** `InstallMCPServer` is the user's interactive entry point and the best opportunity to surface errors. When the server references paclet-qualified tool or prompt names, `InstallMCPServer` performs full validation:

1. Ensures the referenced paclet is installed (via `PacletInstall` if needed).
2. Loads definition files for all paclet-qualified tool and prompt strings.
3. Verifies that each definition produces a valid `LLMTool` expression or association / prompt association.
4. Validates tool options for paclet-defined tools.

If any step fails, `InstallMCPServer` reports the error immediately rather than deferring it to `StartMCPServer` time when the user is no longer present. However, the server configuration still stores paclet-qualified names as plain strings (not resolved `LLMTool` objects), consistent with `CreateMCPServer`. This ensures that paclet updates are picked up on next start without reinstalling.

**Config key:** The key used in the client config file defaults to the short server name (e.g., `"ProjectManagement"` for `"Wolfram/JIRALink/ProjectManagement"`), not the fully qualified name. This is controlled by the `"MCPServerName"` metadata property, which is automatically set to the short name for paclet extension servers. Server definition files can override this with an explicit `"MCPServerName"` key. Users can also override via the `"MCPServerName"` option on `InstallMCPServer`.

### StartMCPServer

At start time, all paclet tool and prompt references are fully resolved: definition files are loaded, `Initialization` code is executed, and `LLMTool` objects are constructed. This is the **Execution** trust level. Referenced paclets are automatically installed via `PacletInstall` if not already present.

`StartMCPServer` is responsible for:

1. Installing any referenced paclets that are not yet locally available.
2. Loading definition files for all paclet-qualified tool and prompt strings.
3. Running `"Initialization"` code from paclet server definitions and from all tool definitions (see behavioral change note below).
4. Constructing `LLMTool` objects from association-form definitions (definitions that are already `LLMTool[...]` expressions are used as-is) and assembling prompt data.
5. Disambiguating MCP name collisions by appending numeric suffixes (see [MCP Name Collision Handling](#mcp-name-collision-handling)).

**Behavioral change — start-time initialization:** Currently, tool `"Initialization"` code (e.g., `initializeVectorDatabases` for the context tools) is executed only at install time by `InstallMCPServer` via `initializeTools`. As part of this spec, `StartMCPServer` will also execute `"Initialization"` code for all tools at server startup. This ensures that initialization runs even when a server is started without a preceding `InstallMCPServer` call (e.g., when launched directly by an MCP client from an existing config file). Only built-in tools currently use the `"Initialization"` property, so this is not a breaking change. Install-time initialization in `InstallMCPServer` is retained as-is — it serves as an early validation step to surface errors while the user is present.

### $DefaultMCPTools / $DefaultMCPServers / $DefaultMCPPrompts

These variables continue to hold only built-in items. Paclet-defined items are **not** merged into these variables. They are resolved on demand through the paclet extension system.

---

## Dynamic Resolution

Paclet tools are always resolved from the currently installed paclet version — they are never snapshotted or cached permanently:

- `CreateMCPServer` stores paclet-qualified tool names as plain strings in `Metadata.wxf`.
- Resolution occurs when `obj["Tools"]` is accessed or at `StartMCPServer` time.
- If a user updates a paclet, the next resolution picks up the new version automatically.

Per-session caching of loaded definition files is recommended for performance, with cache invalidation when paclets are installed or updated.

---

## Error Handling

New messages to add to `Kernel/Messages.wl`:

| Tag | Template | Trigger |
|---|---|---|
| `PacletNotInstalled` | ``"The paclet \"`1`\" is not installed. Evaluate `2` to install it."`` | `MCPServerObject` accessing definition-file properties of an uninstalled paclet |
| `PacletExtensionNotFound` | ``"No AgentTools extension found in paclet \"`1`\"."`` | Referencing a paclet that exists but has no `"AgentTools"` extension |
| `PacletToolNotFound` | ``"Tool \"`1`\" not found in paclet \"`2`\"."`` | Tool name not declared in the paclet's extension |
| `PacletServerNotFound` | ``"Server \"`1`\" not found in paclet \"`2`\"."`` | Server name not declared in the paclet's extension |
| `PacletPromptNotFound` | ``"Prompt \"`1`\" not found in paclet \"`2`\"."`` | Prompt name not declared in the paclet's extension |
| `InvalidPacletToolDefinition` | ``"Invalid tool definition in `1`."`` | Definition file returns malformed data |
| `InvalidPacletServerDefinition` | ``"Invalid server definition in `1`."`` | Server definition file returns malformed data |
| `PacletDependencyMissing` | ``"Server \"`1`\" references tool \"`2`\" from paclet \"`3`\", which could not be installed."`` | Cross-paclet tool reference to a paclet that fails to install at start time |
| `InvalidAgentToolsPacletExtension` | ``"The AgentTools extension in paclet \"`1`\" is invalid: `2`."`` | `ValidateAgentToolsPacletExtension` finds errors |
| `DeletePacletMCPServer` | ``"Cannot delete paclet-backed server \"`1`\". Evaluate `2` to uninstall the paclet."`` | `DeleteObject` on a paclet-backed `MCPServerObject` |

Example error scenarios:

```wl
(* Cross-paclet dependency that fails to install *)
StartMCPServer @ MCPServerObject["MyServer"]
(* AgentTools::PacletDependencyMissing: Server "MyServer" references tool
   "Wolfram/SlackLink/PostMessage" from paclet "Wolfram/SlackLink",
   which could not be installed. *)
```

---

## Developer Validation Utility

### ValidateAgentToolsPacletExtension

New exported function for paclet developers to validate their AgentTools extension:

```wl
ValidateAgentToolsPacletExtension[ PacletObject["Wolfram/JIRALink"] ]
```

### Validation Checks

1. **Extension structure**
   - PacletInfo contains an `"AgentTools"` extension
   - Extension properties use valid keys (`"Root"`, `"MCPServers"`, `"Tools"`, `"MCPPrompts"`)
   - Each declared item uses a valid declaration form (name-only, name+description, or association)

2. **File existence**
   - Root directory exists
   - Each declared server, tool, and prompt has a corresponding definition file (per-item or combined)
   - Warn if multiple definition files exist for the same item (e.g., both `GetIssue.wl` and `GetIssue.mx`)

3. **File contents** (for installed paclets)
   - Each definition file evaluates without error
   - Server definitions produce valid associations with required keys
   - Tool definitions produce valid associations that can construct `LLMTool` objects, or are valid `LLMTool[...]` expressions
   - Prompt definitions produce valid associations with required keys

4. **Cross-references**
   - Tool names referenced by servers are declared in the same paclet or are valid fully qualified names
   - Prompt names referenced by servers exist similarly

### Example Output

Successful validation:

```wl
ValidateAgentToolsPacletExtension[ PacletObject["Wolfram/JIRALink"] ]
(* Success["ValidAgentToolsPacletExtension", <|
       "MCPServers" -> { "ProjectManagement" },
       "Tools"      -> { "CreateIssue", "DeleteIssue", "GetIssue", "SearchIssues" },
       "MCPPrompts" -> { "IssueText" }
   |>] *)
```

Failed validation:

```wl
ValidateAgentToolsPacletExtension[ PacletObject["Wolfram/BrokenPaclet"] ]
(* AgentTools::InvalidAgentToolsPacletExtension: The AgentTools extension in paclet
   "Wolfram/BrokenPaclet" is invalid: Missing definition file for tool "MyTool". *)
(* Failure["InvalidAgentToolsPacletExtension", <|
       "Errors" -> {
           <| "Type" -> "MissingDefinitionFile",
              "Item" -> "MyTool",
              "ExpectedPath" -> "path/to/AgentTools/Tools/MyTool.wl" |>
       }
   |>] *)
```

---

## Source Files Requiring Changes

Existing files:

- `Kernel/MCPServerObject.wl` — paclet name resolution in `getMCPServerObjectByName`, update `$$metadata` pattern to accept `_PacletObject` as Location, add `_PacletObject` case to `mcpServerExistsQ` (check via `PacletFind`), add `_PacletObject` case to `deleteMCPServer` (refuse deletion with error), add `"ToolNames"` and `"PromptNames"` properties to `$specialProperties`, extend `convertStringTools0` with paclet tool resolution for `/`-containing names, extend `normalizePromptData` with paclet prompt resolution for `/`-containing names, extend `MCPServerObjects` to include paclet servers with new options, modify `validateTools` to accept unresolved paclet-qualified strings alongside `LLMTool` objects, modify `getToolList` to handle mixed lists of `LLMTool` objects and paclet-qualified strings (resolving at access time), modify `validateMCPPrompt` to accept `/`-containing prompt names without rejecting, modify `validateTool` to pass through `/`-containing strings
- `Kernel/CreateMCPServer.wl` — store paclet-qualified tool name strings without resolving
- `Kernel/InstallMCPServer.wl` — support paclet-qualified server names
- `Kernel/StartMCPServer.wl` — resolve all paclet references at start time, run `"Initialization"` code for all tools at startup (new — currently only done at install time), disambiguate MCP name collisions
- `Kernel/CommonSymbols.wl` — declare new shared symbols (`resolvePacletTool`, `resolvePacletServer`, `resolvePacletPrompt`, `pacletQualifiedNameQ`, `parsePacletQualifiedName`, `findAgentToolsPaclets`, `loadPacletDefinitionFile`)
- `Kernel/Main.wl` — add `ValidateAgentToolsPacletExtension` to exports, add new subcontexts ``Wolfram`AgentTools`PacletExtension` `` and ``Wolfram`AgentTools`ValidateAgentToolsPacletExtension` ``
- `Kernel/Messages.wl` — add new error messages
- `PacletInfo.wl` — add `ValidateAgentToolsPacletExtension` to Symbols list

New files:

- `Kernel/PacletExtension.wl` — core implementation: paclet discovery, name parsing, definition file loading (handling both association and `LLMTool[...]` results), resolution logic
- `Kernel/ValidateAgentToolsPacletExtension.wl` — validation utility implementation

**Note:** `convertStringTools0` and `normalizePromptData` are both defined in `Kernel/MCPServerObject.wl`, not in `Kernel/Tools/Tools.wl` or `Kernel/Prompts/Prompts.wl`. Those files (`Tools.wl`, `Prompts.wl`) only contain `$DefaultMCPTools` / `$DefaultMCPPrompts` initialization and subcontext loading — they do not need changes for paclet extension support. The `insertCatchTop` wrapping in `Tools.wl` is only for built-in tools and does not apply to paclet-loaded tools.

---

## MCP Name Collision Handling

When multiple tools included in the same MCP server share the same MCP-exposed name (the `"Name"` field from their definition files), `StartMCPServer` automatically disambiguates them by appending numeric suffixes.

### Example

A server includes tools from two paclets that both expose a tool named `"Search"`:

```wl
CreateMCPServer["MyServer", <|
    "Tools" -> {
        "Wolfram/JIRALink/Search",   (* MCP name: "Search" *)
        "Wolfram/SlackLink/Search"  (* MCP name: "Search" *)
    }
|>]
```

At `StartMCPServer` time, the `tools/list` response exposes:

```json
[
    {"name": "Search1", "description": "Search for JIRA issues ..."},
    {"name": "Search2", "description": "Search Slack messages ..."}
]
```

The AI uses the tool descriptions to determine which tool to call.

### Disambiguation Rules

1. **Detection:** After all tool definitions are loaded, `StartMCPServer` groups tools by their MCP-exposed name.
2. **Renaming:** For any group with more than one tool, each tool's MCP name is replaced with `name <> ToString[i]` where `i` is a sequential index starting at 1, ordered by the tool's position in the server's tool list.
3. **Non-conflicting tools are unchanged:** Tools with unique MCP names keep their original name.
4. **Internal tracking:** The server maintains a mapping from disambiguated MCP names back to the original qualified tool keys, so that `tools/call` requests route to the correct tool function.
5. **Scope:** This applies to all tools in the server, not just paclet-defined ones. A built-in tool and a paclet tool with the same MCP name are disambiguated the same way.

### Implementation Location

The disambiguation logic lives in `StartMCPServer.wl`, after all tool definitions have been resolved into `LLMTool` objects but before the tool list is registered with the MCP protocol handler. This is a thin renaming layer — it does not modify the underlying `LLMTool` objects, only the names sent over the MCP wire.

---

## Edge Cases

- **Version collisions:** When multiple versions of the same paclet are installed, `PacletFind` with `SplitBy[..., #["Name"]&]` returns only the latest version.
- **Circular initialization:** If Paclet A's init loads Paclet B and Paclet B's init loads Paclet A, this is the paclet developer's responsibility to avoid.
- **Short name shadowing:** A paclet can define a tool named `"WolframAlpha"`, but the fully qualified name is `"Publisher/Paclet/WolframAlpha"`. The short name `"WolframAlpha"` always resolves to the built-in tool.
- **Paclet uninstalled while server running:** Tool calls will fail at runtime. This is expected behavior.
- **`PacletFindRemote` performance:** The PacletManager caches remote paclet site data automatically, so `MCPServerObjects["IncludeRemotePaclets" -> True]` is fast after the initial fetch. A fresh network call only occurs when `UpdatePacletSites -> True` is passed.
- **Missing root directory:** If the `"Root"` directory doesn't exist in a paclet, definition file loading fails gracefully. PacletInfo metadata remains available.

---

## Future Considerations

- Minimum MCPServer version requirements in the `"AgentTools"` extension
- Tool categories or tag groups in PacletInfo metadata
- Remote paclet browsing UI
- Automatic update notifications for extension paclets
- `"Dependencies"` property in the `"AgentTools"` extension for declaring required paclets
