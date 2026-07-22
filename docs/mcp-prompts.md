# MCP Prompts in AgentTools

This document explains how MCP prompts work in AgentTools and how to add new prompts.

## Overview

MCP prompts allow servers to provide structured messages and instructions for interacting with language models. Clients can discover available prompts, retrieve their contents, and provide arguments to customize them. This follows the [MCP prompts specification](https://modelcontextprotocol.io/specification/2025-11-25/server/prompts.md).

Prompts are designed to be user-controlled, typically exposed through user-initiated commands in the client interface (e.g., slash commands), though clients are free to expose prompts through any interface pattern.

The prompts system is parallel to the tools system:
- `$DefaultMCPPrompts` is analogous to `$DefaultMCPTools`
- Prompts are specified via the `"MCPPrompts"` LLMEvaluator property
- Prompts can be referenced by name (string) or defined inline (association)

## How Prompts Work

### Protocol Flow

1. **Client requests prompt list** (`prompts/list`): Server returns available prompts with names, descriptions, and argument specifications
2. **Client invokes prompt** (`prompts/get`): Server generates content based on the prompt type and arguments
3. **Content returned**: The generated content is returned as a message to the LLM

### Prompt Types

Prompts can be one of two types:

| Type | Content | Behavior |
|------|---------|----------|
| `"Function"` | Callable function | Function is called with arguments association; must return a string |
| `"Text"` | String or `StringTemplate` | For templates, `TemplateApply` is used; strings are returned as-is |

Type is inferred automatically from `"Content"` if not specified:
- `_String` or `_TemplateObject` -> `"Text"`
- Anything else (assumed callable) -> `"Function"`

## $DefaultMCPPrompts

The paclet provides `$DefaultMCPPrompts`, an association of predefined prompt definitions:

```wl
$DefaultMCPPrompts = <|
    "Notebook"              -> <| ... |>,
    "WolframSearch"         -> <| ... |>,
    "WolframLanguageSearch" -> <| ... |>,
    "WolframAlphaSearch"    -> <| ... |>
|>
```

### Naming Convention

- **WL Name**: The key in `$DefaultMCPPrompts` (e.g., `"WolframSearch"`)
- **MCP Name**: The `"Name"` property inside the definition (e.g., `"Search"`)

Multiple WL prompts can share the same MCP name. Each server includes the appropriate WL prompt, but users see the same command name. Note that the `"Name"` property must be unique per server—a server cannot have two prompts with the same MCP name.

| WL Name | MCP Name | Server | Description |
|---------|----------|--------|-------------|
| `"Notebook"` | `"Notebook"` | WolframLanguage, WolframPacletDevelopment | Attaches notebook contents to context |
| `"WolframSearch"` | `"Search"` | Wolfram | Combined documentation + Wolfram Alpha |
| `"WolframLanguageSearch"` | `"Search"` | WolframLanguage, WolframPacletDevelopment | Documentation only |
| `"WolframAlphaSearch"` | `"Search"` | WolframAlpha | Wolfram Alpha only |

## Prompt Definition Format

### Structure

```wl
<|
    "Name"        -> "string",           (* MCP prompt name *)
    "Description" -> "string",           (* Human-readable description *)
    "Arguments"   -> { ... },            (* List of argument specifications *)
    "Type"        -> "Function" | "Text" | Automatic,  (* Content type *)
    "Content"     -> content             (* Function, String, or StringTemplate *)
|>
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `"Name"` | String | Yes | The MCP prompt name visible to clients |
| `"Description"` | String | No | Human-readable description |
| `"Arguments"` | List | No | List of argument specifications |
| `"Type"` | String | No | Content type; defaults to `Automatic` (inferred) |
| `"Content"` | Any | Yes | The prompt content |

### Argument Specification

```wl
<|
    "Name"        -> "string",     (* Argument identifier *)
    "Description" -> "string",     (* Human-readable description *)
    "Required"    -> True | False  (* Whether the argument is required *)
|>
```

## Adding a New Prompt

### Step 1: Create the Prompt Definition File

Create a new file in `Kernel/Prompts/` following the pattern of `Search.wl`:

```wl
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Prompts`YourPrompt`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"         ];
Needs[ "Wolfram`AgentTools`Common`"  ];
Needs[ "Wolfram`AgentTools`Prompts`" ];

(* ::Section::Closed:: *)
(*Prompt Definition*)
$defaultMCPPrompts[ "YourPromptName" ] := <|
    "Name"        -> "YourMCPName",
    "Description" -> "Description of what the prompt does.",
    "Arguments"   -> {
        <|
            "Name"        -> "arg1",
            "Description" -> "Description of argument",
            "Required"    -> True
        |>
    },
    "Type"        -> "Function",
    "Content"     -> yourPromptFunction
|>;

(* ::Section::Closed:: *)
(*Prompt Function*)
yourPromptFunction // beginDefinition;

yourPromptFunction[ KeyValuePattern[ "arg1" -> value_String ] ] :=
    yourPromptFunction @ value;

yourPromptFunction[ value_String ] := Enclose[
    Module[ { result },
        result = ConfirmBy[ yourComputation @ value, StringQ, "Result" ];
        (* Return a string *)
        result
    ],
    throwInternalFailure
];

yourPromptFunction // endDefinition;

(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
```

### Step 2: Register the Subcontext

Add your new subcontext to `Kernel/Prompts/Prompts.wl`:

```wl
$subcontexts = {
    "Wolfram`AgentTools`Prompts`Search`",
    "Wolfram`AgentTools`Prompts`YourPrompt`"  (* Add your new subcontext *)
};
```

### Step 3: Add to Server Configuration (Optional)

If you want the prompt to be included in default servers, update `Kernel/DefaultServers.wl`:

```wl
"ServerName" -> <|
    "LLMEvaluator" -> <|
        "Tools" -> { ... },
        "MCPPrompts" -> { "YourPromptName" }  (* Add your prompt *)
    |>
|>
```

### Step 4: Write Tests

Add tests to `Tests/Prompts.wlt`:

```wl
VerificationTest[
    $DefaultMCPPrompts[ "YourPromptName" ][ "Name" ],
    "YourMCPName",
    TestID -> "YourPromptName-MCPName"
]
```

## Using Prompts in Custom Servers

### Reference by Name

```wl
CreateMCPServer[ "MyServer", <|
    "MCPPrompts" -> { "WolframLanguageSearch" }
|> ]
```

### Reference Paclet Prompts

Prompts contributed by third-party paclets can be referenced using paclet-qualified names:

```wl
CreateMCPServer[ "MyServer", <|
    "MCPPrompts" -> {
        "WolframLanguageSearch",
        "PublisherID/MyPaclet/CustomPrompt"
    }
|> ]
```

See [paclet-extensions.md](paclet-extensions.md) for details on how paclets declare prompts.

### Inline Definition

```wl
CreateMCPServer[ "MyServer", <|
    "MCPPrompts" -> {
        <|
            "Name"        -> "Greet",
            "Description" -> "Generates a greeting message",
            "Arguments"   -> {
                <| "Name" -> "name", "Required" -> True |>
            },
            "Type"    -> "Text",
            "Content" -> StringTemplate[ "Hello, `name`!" ]
        |>
    }
|> ]
```

## Prompt Output Format

The built-in prompts use consistent XML-style formats for structured output.

### Search Prompts

The search prompts (`WolframSearch`, `WolframLanguageSearch`, `WolframAlphaSearch`) use:

```
<search-query>{query}</search-query>
<search-results>
{results}
</search-results>
Use the above search results to answer the user's query below.
<user-query>{query}</user-query>
```

The query is intentionally repeated to help LLMs detect argument parsing issues in clients.

### Notebook Prompt

The `Notebook` prompt attaches the contents of a Wolfram notebook (`.nb` file) to the conversation context:

```
<notebook-path>{path}</notebook-path>
<notebook-content>
{markdown}
</notebook-content>
```

The notebook is converted to markdown format, preserving:
- Section headers and text cells
- Code cells with `In[n]:=` / `Out[n]=` formatting in fenced code blocks
- Graphics as box expressions

## Error Handling

Function-type prompts should handle errors gracefully. The server wraps function calls with error handling that converts failures to error messages rather than MCP protocol errors.

Use the standard error handling pattern:

```wl
yourFunction[ args_ ] := Enclose[
    Module[ { result },
        result = ConfirmBy[ computation[ args ], StringQ, "Result" ];
        result
    ],
    throwInternalFailure
];
```

## Related Files

- `Kernel/Prompts/Prompts.wl` - Main prompts module, defines `$DefaultMCPPrompts`
- `Kernel/Prompts/Search.wl` - Search prompt implementations
- `Kernel/Prompts/Notebook.wl` - Notebook prompt implementation
- `Kernel/PacletExtension.wl` - Paclet-qualified prompt resolution (see [paclet-extensions.md](paclet-extensions.md))
- `Kernel/MCPServerObject.wl` - Prompt validation and normalization
- `Kernel/Server/Shared.wl` - Protocol handling for `prompts/list` and `prompts/get`
- `Kernel/DefaultServers.wl` - Server configurations with `"MCPPrompts"` settings
- `Tests/Prompts.wlt` - Tests for prompt functionality
