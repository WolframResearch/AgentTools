# Distributing Tools, Servers, Skills, and Bundles in a Paclet

A paclet can ship tools, MCP prompts, MCP servers, agent skills, and bundles by declaring an `"AgentTools"`
extension in its `PacletInfo.wl`. Anyone with AgentTools can then use them by name. For a paclet published in the
[Wolfram Paclet Repository](https://resources.wolframcloud.com/PacletRepository), this is all a user has to run:

```wl
DeployAgentTools["ClaudeCode", "MyPublisher/WidgetTools"]
```

For building, checking, and submitting the paclet itself, use the `wolfram-paclets` skill if you have it.

## Layout

```
WidgetTools/
├── PacletInfo.wl
├── Kernel/
│   └── WidgetTools.wl                       the paclet's own code
└── AgentTools/                              the extension root
    ├── Tools/
    │   └── WidgetCount.wl
    ├── MCPPrompts/
    │   └── WidgetReport.wl
    ├── MCPServers/
    │   └── Widgets.wl
    └── AgentSkills/
        └── using-widgets/
            ├── SKILL.md
            └── scripts/ ...
```

## Declaring the extension

```wl
PacletObject[<|
    "Name"           -> "MyPublisher/WidgetTools",
    "Version"        -> "1.0.0",
    "WolframVersion" -> "15.0+",
    "Extensions"     -> {
        { "Kernel", "Root" -> "Kernel", "Context" -> "MyPublisher`WidgetTools`" },
        { "AgentTools",
            "Root"        -> "AgentTools",
            "Name"        -> "WidgetTools",
            "Description" -> "Tools and skills for working with widgets",
            "MCPServers"  -> { "Widgets" },
            "Tools"       -> { { "WidgetCount", "Counts the widgets in a piece of text" } },
            "MCPPrompts"  -> { "WidgetReport" },
            "AgentSkills" -> { "using-widgets" }
        }
    }
|>]
```

| Property | Default | Meaning |
| --- | --- | --- |
| `"Root"` | `"AgentTools"` | The directory that holds the definition files |
| `"Name"` | `"AgentTools"` | The name of the bundle that this entry defines (no `/`) |
| `"Description"` | | A description of the bundle |
| `"MCPServers"`, `"Tools"`, `"MCPPrompts"`, `"AgentSkills"` | `{}` | The declared items |
| `"SystemID"`, `"WolframVersion"` | | The usual paclet extension qualifiers |

Each declared item is a name, `{name, description}`, or an association with a `"Name"`. Names may not contain `/`.
Declare every item that the paclet defines; every declared item needs a definition file.

## Definition files

A definition file is a `.wl` file (or `.wxf` or `.mx`) whose content evaluates to the definition. Each item has its
own file, `<Root>/<Type>/<Name>.wl`. Alternatively, one combined file per type (`<Root>/Tools.wl`,
`<Root>/MCPServers.wl`, and so on) evaluates to an association of all definitions keyed by name.

**Tool** (`AgentTools/Tools/WidgetCount.wl`): an association with the properties described in `Tools.md`, or an
`LLMTool`.

```wl
<|
    "Name"           -> "WidgetCount",
    "Description"    -> "Counts the widgets mentioned in a piece of text.",
    "Function"       -> MyPublisher`WidgetTools`WidgetCountTool,
    "Initialization" :> Needs["MyPublisher`WidgetTools`"],
    "Parameters"     -> {
        "text" -> <| "Interpreter" -> "String", "Help" -> "The text to search.", "Required" -> True |>
    }
|>
```

Definition files are read without loading your package. Write the function as a full symbol name, and load the
package in `"Initialization"` (with `:>`), which runs when a server that contains the tool starts.

**Server** (`AgentTools/MCPServers/Widgets.wl`):

```wl
<|
    "Name"         -> "Widgets",
    "LLMEvaluator" -> <|
        "Tools"      -> { "WidgetCount" },
        "MCPPrompts" -> { "WidgetReport" }
    |>
|>
```

Optional keys: `"Initialization" :> ...` (runs when the server starts), `"ServerVersion"` (default: the paclet
version), and `"MCPServerName"` (the key in client configurations; default: the server name).

A plain name in `"Tools"` or `"MCPPrompts"` always means an item **of this paclet**. Refer to another paclet's item
by its full name (`"OtherPublisher/OtherPaclet/ToolName"`); that paclet is installed automatically when the server
starts. A built-in tool such as `"WolframLanguageEvaluator"` cannot be listed by its plain name. To include one,
declare a tool of that name in the extension and define it as the built-in tool:

```wl
(* AgentTools/Tools/WolframLanguageEvaluator.wl *)
Wolfram`AgentTools`$DefaultMCPTools["WolframLanguageEvaluator"]
```

**MCP prompt** (`AgentTools/MCPPrompts/WidgetReport.wl`): the association described in `MCPServers.md`.

```wl
<|
    "Name"        -> "WidgetReport",
    "Description" -> "Asks for a widget report on a topic.",
    "Arguments"   -> { <| "Name" -> "topic", "Description" -> "The topic", "Required" -> True |> },
    "Content"     -> StringTemplate["Write a widget report about `topic`."]
|>
```

**Agent skill**: a skill directory `AgentTools/AgentSkills/<name>/` with a `SKILL.md`, whose frontmatter `name`
equals the declared name and the directory name. The directory is copied as is, so it can contain `scripts/`,
`references/`, and `assets/`. A skill without bundled files can instead be a definition file
`AgentTools/AgentSkills/<name>.wl` that evaluates to `<|"Name" -> ..., "Description" -> ..., "Body" -> ...|>` or
`LLMSkill[{name, description}, body]`. See `AgentSkills.md`.

## Names

Everything a paclet defines is addressed as `"PacletName/ItemName"`. With a publisher ID that makes three parts:

| Item | Name |
| --- | --- |
| Server | `"MyPublisher/WidgetTools/Widgets"` |
| Tool, prompt | `"MyPublisher/WidgetTools/WidgetCount"`, usable in any `CreateMCPServer` |
| Skill | `"MyPublisher/WidgetTools/using-widgets"` |
| Bundle | `"MyPublisher/WidgetTools/WidgetTools"` (the entry's `"Name"`), or just `"MyPublisher/WidgetTools"` if the paclet defines one bundle |

## Bundles

Every `"AgentTools"` entry that declares at least one server or skill defines a bundle with that entry's servers
and skills. A paclet can have several entries, for example a bundle for users and a larger one for developers:

```wl
{ "AgentTools", "Name" -> "WidgetTools",
    "MCPServers" -> { "Widgets" }, "Tools" -> { "WidgetCount" }, "AgentSkills" -> { "using-widgets" } },
{ "AgentTools", "Name" -> "WidgetDevelopment", "Root" -> "DevTools",
    "MCPServers" -> { "Widgets", "WidgetDev" }, "AgentSkills" -> { "using-widgets", "widget-development" } }
```

An entry may list items that another entry declares. Definition files are searched in every entry's root, in
order.

## Checking and testing

Validate the extension from the paclet directory, before building:

```wl
ValidateAgentToolsPacletExtension[File["/path/to/WidgetTools"]]
(* Success["ValidAgentToolsPacletExtension", <|"MCPServers" -> ..., "Tools" -> ..., "AgentTools" -> {bundles}|>] *)
```

A `Failure` lists every problem under `"Errors"`, each with a `"Type"` and a `"Message"`: a declared item without a
definition file, a definition without its required keys, a skill whose name differs from the declared one, a server
that refers to a tool or prompt that is not declared (`InvalidToolReference`, `InvalidPromptReference`), and so on.

To try the paclet without installing it, load its directory in your session:

```wl
PacletDirectoryLoad["/path/to/WidgetTools"];
MCPServerObject["MyPublisher/WidgetTools/Widgets"]["ToolNames"]
AgentToolsObject["MyPublisher/WidgetTools"]["AgentSkillNames"]
```

A server started by a client runs in a fresh kernel that knows only installed paclets. For the stdio smoke test in
`MCPServers.md`, add the same `PacletDirectoryLoad` in front of the start command:

```bash
MCP_SERVER_NAME=MyPublisher/WidgetTools/Widgets SUBMIT_USAGE_DATA=false \
  wolfram -run 'PacletDirectoryLoad["/path/to/WidgetTools"];PacletSymbol["Wolfram/AgentTools","Wolfram`AgentTools`StartMCPServer"][]' -noinit -noprompt \
  < requests.jsonl
```

To use it in a real client before publishing, build the paclet and install the archive with `PacletInstall`, then
deploy. After changing the paclet, install the new build and have the client restart the server.

## What users do

```wl
DeployAgentTools["ClaudeCode", "MyPublisher/WidgetTools"]              (* servers and skills, tracked *)
InstallMCPServer["ClaudeCode", "MyPublisher/WidgetTools/Widgets"]      (* only one server *)
InstallAgentSkills["ClaudeCode", "MyPublisher/WidgetTools/using-widgets"]

CreateMCPServer["Mine", <|"Tools" -> {"WolframLanguageEvaluator", "MyPublisher/WidgetTools/WidgetCount"}|>]
```

`DeployAgentTools` and `InstallMCPServer` install the paclet from the Paclet Repository if it is not installed yet.
After `PacletUpdate`, deploying again with `OverwriteTarget -> True` updates the installed skills.
`MCPServerObjects[]` and `AgentToolsObjects[]` list what installed paclets provide; with
`"IncludeRemotePaclets" -> True` they also search the Paclet Repository.
