# Paclet Extensions

This document describes how third-party Wolfram Language paclets can extend AgentTools with additional MCP tools, prompts, servers, and agent skills using the `"AgentTools"` paclet extension.

## Overview

The paclet extension system allows any Wolfram Language paclet to contribute MCP tools, prompts, servers, and [agent skills](https://agentskills.io/specification) to the AgentTools ecosystem. Paclets declare their contributions in `PacletInfo.wl` using one or more `"AgentTools"` extensions, and AgentTools discovers and integrates them automatically. Each extension that declares servers or skills also defines a bundle (an `AgentToolsObject`) that `DeployAgentTools` deploys as one unit (see [Specs/AgentToolsObject.md](../Specs/AgentToolsObject.md)).

This enables:
- **Third-party tool distribution** via the [Wolfram Paclet Repository](https://resources.wolframcloud.com/PacletRepository)
- **Domain-specific servers** bundled with specialized paclets
- **Cross-paclet composition** where servers can reference tools from other paclets

## Declaring an Extension

Add an `"AgentTools"` extension to your paclet's `PacletInfo.wl`:

```wl
PacletObject[<|
    "Name"       -> "PublisherID/MyPaclet",
    "Version"    -> "1.0.0",
    "Extensions" -> {
        { "AgentTools",
            "Root"        -> "AgentTools",
            "Name"        -> "MyPaclet",
            "Description" -> "Tools and skills for working with MyPaclet",
            "MCPServers"  -> { "MyServer" },
            "Tools"       -> {
                { "MyTool", "Description of my tool" }
            },
            "MCPPrompts"  -> { "MyPrompt" },
            "AgentSkills" -> { "using-my-paclet" }
        }
    }
|>]
```

### Extension Properties

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `"Root"` | String | No | `"AgentTools"` | Subdirectory containing definition files |
| `"Name"` | String | No | `"AgentTools"` | Name of the bundle defined by this entry (must not contain `/`) |
| `"Description"` | String | No | | Description of the bundle |
| `"MCPServers"` | List | No | `{}` | Declared server configurations |
| `"Tools"` | List | No | `{}` | Declared tool definitions |
| `"MCPPrompts"` | List | No | `{}` | Declared prompt definitions |
| `"AgentSkills"` | List | No | `{}` | Declared agent skills |
| `"SystemID"` | String or List | No | All systems | Standard paclet extension qualifier: the entry only applies on these systems |
| `"WolframVersion"` | String | No | | Standard paclet extension qualifier |

### Declaration Formats

Each item in `"MCPServers"`, `"Tools"`, `"MCPPrompts"`, or `"AgentSkills"` can use one of three formats:

| Format | Example | Use Case |
|--------|---------|----------|
| Name only | `"MyTool"` | Minimal declaration |
| Name + Description | `{ "MyTool", "Does something" }` | Adds metadata for discovery |
| Association | `<\| "Name" -> "MyTool", ... \|>` | Full metadata including parameters |

Item names must not contain `/`: items are scoped to the paclet, and cross-paclet references belong in definition files.

### Multiple Extension Entries

A paclet may have several `"AgentTools"` entries, for example to define several bundles or to keep definition files in several root directories. All entries that apply to the current system (see `"SystemID"`) are used:

- **Items are paclet-scoped.** The paclet's servers, tools, prompts, and skills are the union of the declarations of all entries (the first declaration of a name wins). An entry may re-list an item that another entry declares.
- **Every root is searched.** Definition files are looked up in each entry's `"Root"` in entry order (skipping duplicates and roots that don't exist). The first root that defines an item wins.

```wl
PacletObject[<|
    "Name"       -> "PublisherID/MyPaclet",
    "Version"    -> "1.0.0",
    "Extensions" -> {
        { "AgentTools",
            "Name"        -> "MyPaclet",
            "MCPServers"  -> { "MyPacletTools" },
            "AgentSkills" -> { "using-my-paclet" }
        },
        { "AgentTools",
            "Root"        -> "DevTools",
            "Name"        -> "MyPacletDevelopment",
            "MCPServers"  -> { "MyPacletTools", "MyPacletDevTools" },
            "AgentSkills" -> { "using-my-paclet", "my-paclet-development" }
        }
    }
|>]
```

Here `MyPacletDevTools` and `my-paclet-development` may be defined under `DevTools/`, while the re-listed `MyPacletTools` and `using-my-paclet` are found under `AgentTools/`.

### Bundles

Each applicable entry that declares at least one server or skill defines a bundle named `"PacletName/Name"` (`"PublisherID/PacletShortName/Name"` for publisher paclets), containing that entry's own servers and skills. The bundle name comes from the entry's `"Name"` (default `"AgentTools"`). Entries that declare only tools and prompts define no bundle.

```wl
AgentToolsObject["PublisherID/MyPaclet/MyPacletDevelopment"]
DeployAgentTools["ClaudeCode", "PublisherID/MyPaclet/MyPaclet"]
```

Bundle membership comes from `PacletInfo.wl` only, so bundles of installed and uninstalled (remote) paclets can be listed without loading any definition files. See [Specs/AgentToolsObject.md](../Specs/AgentToolsObject.md) for `AgentToolsObject` and `DeployAgentTools`.

## Definition Files

Each declared item must have a corresponding definition file under the extension root directory.

### File Layout

**Per-item files** (recommended):

```
AgentTools/
    MCPServers/MyServer.wl
    Tools/MyTool.wl
    MCPPrompts/MyPrompt.wl
```

**Combined files** (alternative for simpler paclets):

```
AgentTools/
    Tools.wl          (* Returns <| "MyTool" -> <| ... |>, ... |> *)
```

Per-item files take precedence over combined files. Supported formats: `.mx`, `.wxf`, `.wl` (checked in that order). With [multiple entries](#multiple-extension-entries), each root is searched in turn (per-item file, then combined file) and the first root that defines the item wins.

### Tool Definition Files

A tool definition file must evaluate to an association with required keys:

```wl
(* AgentTools/Tools/MyTool.wl *)
<|
    "Name"        -> "MyTool",
    "Description" -> "Does something useful",
    "Function"    -> MyPackage`myToolFunction,
    "Parameters"  -> {
        "input" -> <|
            "Interpreter" -> "String",
            "Help"        -> "The input value",
            "Required"    -> True
        |>
    }
|>
```

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `"Name"` | String | Yes | MCP-exposed tool name |
| `"Function"` | Symbol | Yes | Wolfram Language function to call |
| `"Parameters"` | List | Yes | Parameter specifications |
| `"Description"` | String | No | Tool description |
| `"DisplayName"` | String | No | Human-readable display name |
| `"Initialization"` | Delayed | No | Setup code run at server start |
| `"Options"` | List | No | Tool options |

### Server Definition Files

A server definition file must evaluate to an association with an `"LLMEvaluator"` key:

```wl
(* AgentTools/MCPServers/MyServer.wl *)
<|
    "Name"           -> "MyServer",
    "Initialization" :> Needs["PublisherID`MyPaclet`"],
    "LLMEvaluator"   -> <|
        "Tools"      -> { "MyTool", "AnotherTool" },
        "MCPPrompts" -> { "MyPrompt" }
    |>,
    "ServerVersion"  -> "1.0.0"
|>
```

Tool and prompt names within a server definition are automatically qualified to the owning paclet at load time. For example, `"MyTool"` becomes `"PublisherID/MyPaclet/MyTool"`.

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `"LLMEvaluator"` | Association | Yes | Server configuration with `"Tools"` and/or `"MCPPrompts"` |
| `"Name"` | String | No | Server name |
| `"Initialization"` | Delayed | No | Setup code run at server start (use `:>`) |
| `"ServerVersion"` | String | No | Version string (defaults to paclet version) |
| `"Transport"` | String | No | Transport type (defaults to `"StandardInputOutput"`) |

### Prompt Definition Files

A prompt definition file must evaluate to an association with a `"Name"` key:

```wl
(* AgentTools/MCPPrompts/MyPrompt.wl *)
<|
    "Name"        -> "MyPrompt",
    "Description" -> "Provides context about something",
    "Arguments"   -> {
        <| "Name" -> "topic", "Description" -> "The topic", "Required" -> True |>
    },
    "Type"        -> "Function",
    "Content"     -> MyPackage`myPromptFunction
|>
```

### Agent Skill Definitions

Agent skills follow the [Agent Skills](https://agentskills.io/specification) format. For a declared skill `name`, each root is searched in this order:

1. **Skill directory** `AgentSkills/<name>/SKILL.md`: the only form that can ship bundled files (`scripts/`, `references/`, `assets/`). The directory is copied as-is.
2. **Per-item definition file** `AgentSkills/<name>.mx|.wxf|.wl`.
3. **Combined file** `AgentSkills.mx|.wxf|.wl`, an association keyed by skill name.

```
AgentTools/
    AgentSkills/
        using-my-paclet/
            SKILL.md
            scripts/run.wls
            references/guide.md
        my-paclet-docs.wl
    AgentSkills.wl    (* Returns <| "my-other-skill" -> <| ... |>, ... |> *)
```

A skill directory's `SKILL.md` starts with YAML frontmatter that gives the skill's name (which must equal the declared name and the directory name) and description:

```markdown
---
name: using-my-paclet
description: How to use MyPaclet to analyze widgets. Use when the user asks about widgets.
---

# Using MyPaclet

...
```

A definition file evaluates to an `LLMSkill[...]` or to an association:

```wl
(* AgentTools/AgentSkills/my-paclet-docs.wl *)
<|
    "Name"        -> "my-paclet-docs",
    "Description" -> "Where to find the MyPaclet documentation.",
    "Body"        -> "# MyPaclet Documentation\n\n...",
    "License"     -> "MIT"
|>
```

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `"Name"` | String | Yes | Skill name; must equal the declared name |
| `"Description"` | String | Yes | 1 to 1024 characters, not all whitespace; tells the agent when to use the skill |
| `"Body"` | String | Yes | Markdown instructions (the body of the generated `SKILL.md`) |
| `"License"`, `"Compatibility"`, `"AllowedTools"`, `"Metadata"`, `"AdditionalFrontmatter"` | | No | Additional frontmatter |

In `.wl` files, use an association or `LLMSkill[{name, description}, body]`; `.wxf`/`.mx` files may contain serialized `LLMSkill`s. An `LLMSkill`'s `"Location"` is only used if it is a skill directory inside one of the paclet's extension roots (a relative location is resolved against the directory of the definition file); any other location (e.g. an absolute path from the author's machine) is ignored, and `SKILL.md` is generated from the skill's fields.

Skill names must be 1 to 64 lowercase letters, digits, and hyphens, without leading, trailing, or consecutive hyphens.

## Qualified Names

Paclet-contributed items are referenced using qualified names. Two formats are supported:

- **2-segment**: `"PacletName/ItemName"` — for paclets without a publisher ID
- **3-segment**: `"PublisherID/PacletShortName/ItemName"` — for paclets with a publisher ID (the first two segments form the paclet name `"PublisherID/PacletShortName"`)

```wl
(* 2-segment: paclet without publisher ID *)
MCPServerObject["MyPaclet/MyServer"]

(* 3-segment: paclet with publisher ID *)
CreateMCPServer["MyServer", <|
    "Tools" -> { "PublisherID/MyPaclet/MyTool" }
|>]

MCPServerObject["PublisherID/MyPaclet/MyServer"]

InstallMCPServer["ClaudeCode", "PublisherID/MyPaclet/MyServer"]
```

### Name Resolution

| Context | Resolution |
|---------|------------|
| User code (`CreateMCPServer`, etc.) | Built-in tools checked first, then paclet-qualified names |
| Within a paclet's own server definition | Own paclet items first, then built-in, then fully qualified cross-paclet references |
| Cross-paclet reference | Must use fully qualified name (e.g., `"OtherPublisher/OtherPaclet/ToolName"`) |

## Discovering Paclet Servers

### Listing Servers

`MCPServerObjects` discovers servers from installed paclets automatically:

```wl
(* File-based + installed paclet servers *)
MCPServerObjects[]

(* Also include servers from uninstalled paclets in the Paclet Repository *)
MCPServerObjects["IncludeRemotePaclets" -> True]
```

### MCPServerObjects Options

| Option | Default | Description |
|--------|---------|-------------|
| `"IncludeBuiltIn"` | `False` | Include built-in servers from `$DefaultMCPServers` |
| `"IncludeRemotePaclets"` | `False` | Include servers from uninstalled paclets in the Paclet Repository |
| `UpdatePacletSites` | `Automatic` | Force refresh of cached remote paclet data |

### Inspecting a Paclet Server

```wl
server = MCPServerObject["PublisherID/MyPaclet/MyServer"];
server["Name"]       (* "PublisherID/MyPaclet/MyServer" *)
server["Tools"]      (* List of resolved LLMTool objects *)
server["Location"]   (* PacletObject[...] *)
```

For uninstalled paclets, properties that require loading definition files return a `Failure["PacletNotInstalled", ...]` with install instructions.

## MCP Name Collision Handling

When multiple tools in a server share the same MCP-exposed name (e.g., tools from different paclets both named `"Search"`), `StartMCPServer` automatically disambiguates by appending numeric suffixes (`"Search1"`, `"Search2"`). The AI uses tool descriptions to select the correct one.

## Server Initialization

Paclet servers can include initialization code that runs at server start time:

```wl
<|
    "Initialization" :> Needs["PublisherID`MyPaclet`"],
    ...
|>
```

Use `RuleDelayed` (`:>`) so the initialization code is evaluated dynamically when the server starts, not when the definition file is loaded.

## Validation

Use `ValidateAgentToolsPacletExtension` to check your extension before publishing:

```wl
paclet = PacletObject["PublisherID/MyPaclet"];
ValidateAgentToolsPacletExtension[paclet]
(* Success["ValidAgentToolsPacletExtension", <|
       "MCPServers"  -> ...,
       "Tools"       -> ...,
       "MCPPrompts"  -> ...,
       "AgentSkills" -> { "using-my-paclet", ... },
       "AgentTools"  -> { "PublisherID/MyPaclet/MyPaclet", ... }
   |>] *)
```

The validator checks:
- Extension structure, valid keys, and declaration forms of every `"AgentTools"` entry in `PacletInfo.wl` (including entries for other systems)
- Definition file existence for all declared items, across all roots
- File contents evaluate to valid associations with required keys
- Agent skill definitions have the declared name and valid names and descriptions
- Cross-references between servers and tools/prompts are resolvable
- Bundles have distinct names and can be deployed

On failure, it returns `Failure["InvalidAgentToolsPacletExtension", <| "Errors" -> {...} |>]`, where each error is an association with a `"Type"` and a `"Message"`:

| Type | Meaning |
|------|---------|
| `NoAgentToolsExtension` | `PacletInfo.wl` has no `"AgentTools"` extension |
| `MalformedExtension` | An entry is not a list of rules |
| `InvalidExtensionKeys` | An entry has unknown keys |
| `InvalidExtensionValue` | `"Root"` or `"Description"` is not a string, or a declaration list is not a list |
| `InvalidBundleName` | `"Name"` is not a non-empty string without `/` |
| `InvalidDeclaration` | A declared item does not use one of the three declaration formats |
| `InvalidItemName` | A declared item name is empty or contains `/` |
| `DuplicateBundleName` | Several entries that can apply on the same system define the same bundle name (including two entries without `"Name"`); entries with disjoint `"SystemID"` qualifiers may share a name |
| `MissingRootDirectory` | An entry's `"Root"` does not exist, or no root exists at all |
| `MissingDefinitionFile` | A declared item has no definition (skill directory, per-item file, or combined file entry) in any root |
| `DuplicateDefinitionFiles` | An item has several per-item files in one root, a skill has both a skill directory and a per-item file, or an item is defined in more than one root |
| `InvalidDefinitionContents` | A server, tool, or prompt definition is not an association (or `LLMTool`) |
| `InvalidServerDefinition`, `InvalidToolDefinition`, `InvalidPromptDefinition` | A definition lacks required keys |
| `InvalidSkillDefinition` | A skill's `SKILL.md` or definition cannot be read, has a different name than declared, or has an invalid name or description |
| `InvalidToolReference`, `InvalidPromptReference` | A server references a tool or prompt that is neither declared by the paclet nor fully qualified |
| `DuplicateBundleConfigKey` | Two servers of one bundle would be installed with the same configuration key (their `"MCPServerName"`, or the server name) |
| `AmbiguousBundleName` | A bundle has the name of one of the paclet's servers but does not contain that server |

## Security Model

Operations on paclet extensions follow three trust levels:

| Level | Operations | Behavior |
|-------|-----------|----------|
| **Discovery** | `MCPServerObjects[]`, `PacletFind` | Reads PacletInfo metadata; may load definition files for installed paclets; never installs paclets |
| **Inspection** | `MCPServerObject[...]["Tools"]` | Loads definition files from installed paclets |
| **Execution** | `StartMCPServer`, `InstallMCPServer` | Executes tool functions and initialization; auto-installs referenced paclets |

## Related Files

- `Kernel/PacletExtension.wl` - Core paclet discovery, parsing, and resolution (including bundles and agent skills)
- `Kernel/ValidateAgentToolsPacletExtension.wl` - Extension validation
- `Kernel/CommonSymbols.wl` - Shared symbol declarations for paclet extension functions
- `Kernel/Messages.wl` - Error messages for paclet extension operations
- `Kernel/MCPServerObject.wl` - Paclet server integration into server objects
- `Kernel/Server/Shared.wl` - Paclet dependency resolution and initialization at server start
- `Kernel/InstallMCPServer.wl` - Paclet reference validation at install time
- `Tests/PacletExtension.wlt` - Tests for paclet extension loading and resolution
- `Tests/ValidateAgentToolsPacletExtension.wlt` - Tests for extension validation
- `Specs/PacletExtension.md` - Design specification
- `Specs/AgentToolsObject.md` - Design specification for multiple entries, bundles, and agent skills

## Related Documentation

- [tools.md](tools.md) - MCP tools system and how to define tools
- [mcp-prompts.md](mcp-prompts.md) - MCP prompts system and how to define prompts
- [servers.md](servers.md) - Predefined servers and custom server creation
- [mcp-clients.md](mcp-clients.md) - Client installation and configuration
