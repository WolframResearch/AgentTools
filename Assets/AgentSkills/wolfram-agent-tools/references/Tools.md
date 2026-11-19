# Custom Tools

A tool is an `LLMTool`: a Wolfram Language function with a name, a description, and typed parameters. Tools do
nothing on their own. Put them in an MCP server (`MCPServers.md`) or ship them in a paclet (`PacletDistribution.md`).

## Defining a tool

```wl
wordCount[KeyValuePattern["text" -> text_String]] := ToString @ Length @ TextWords @ text;

tool = LLMTool[<|
    "Name"        -> "WordCount",
    "DisplayName" -> "Word Count",
    "Description" -> "Counts the words in a piece of text. Use it for exact counts instead of estimating.",
    "Function"    -> wordCount,
    "Parameters"  -> {
        "text" -> <|"Interpreter" -> "String", "Help" -> "The text to count words in.", "Required" -> True|>
    }
|>];

tool[<|"text" -> "one two three"|>]    (* "3" *)
```

| Property | Required | Meaning |
| --- | --- | --- |
| `"Name"` | yes | The tool name the model sees. Keep it short, without spaces |
| `"Description"` | yes | What the tool does and when to use it. The model chooses tools from this text alone |
| `"Function"` | yes | Called with one association that has every declared parameter as a key |
| `"Parameters"` | yes | A list of `"name" -> spec` rules; `{}` for none |
| `"DisplayName"` | no | A human-readable title |
| `"Initialization"` | no | Code that runs once when the server starts: `"Initialization" :> Needs["MyPackage`"]`. Use `:>` |
| `"Overrides"` | no | Properties that replace the ones above depending on where the server runs (see below) |

The short form `LLMTool[{"Name", "Description"}, {"x" -> "Integer"}, #x + 1 &]` also works. Use it only for
trivial tools: its parameters have no `"Help"` text unless you give the full specification.

## Parameters

Each specification is `<|"Interpreter" -> type, "Help" -> "...", "Required" -> True | False|>`. The interpreter
becomes the JSON schema that the client sees, and the server interprets and checks each argument before it calls
your function:

| `"Interpreter"` | Schema the model sees | Your function receives |
| --- | --- | --- |
| `"String"` | string | a string |
| `"Integer"` | integer | an integer |
| `"Number"` | number | a number |
| `"Boolean"` | boolean | `True` or `False` |
| `{"red", "green"}` | an enumeration | one of the strings |
| `Restricted["Integer", {1, 10}]` | integer with minimum and maximum | an integer in that range |
| other `Interpreter` types, such as `"Date"` or `DelimitedSequence["String", ","]` | string | the interpreted expression (a `DateObject`, a list) |

- A missing required argument, or a value that cannot be interpreted, is returned to the model as an error. Your
  function is not called.
- An optional parameter that the model leaves out arrives as `Missing["NoInput"]`. Give it a default yourself:

```wl
search[KeyValuePattern[{"query" -> query_String, "limit" -> limit0_}]] :=
    Module[{limit = Replace[limit0, Except[_Integer] -> 10]}, ...];
```

- Write `"Help"` for the model: say what the value means, its format, and its default.

## Results

| The function returns | The model gets |
| --- | --- |
| a string | the string |
| `Failure[tag, <|"MessageTemplate" -> "..."|>]` | `[Error] ...`, marked as an error result |
| graphics or an image | the image, in addition to a short text placeholder |
| anything else | `ToString[result]` (`OutputForm`), which drops string quotes and is hard to read |

So return a string. Format structured results yourself (Markdown, `ToString[expr, InputForm]`, or
`ExportString[expr, "JSON"]`), and keep them short: the result goes into the model's context. Return a `Failure`
with a message that tells the model what to do differently.

- Only the return value reaches the model. `Print` and `Echo` output and messages are discarded.
- If no definition of your function matches the arguments, the unevaluated call is returned as text. Add a
  catch-all definition that returns a `Failure`.
- AgentTools sets no time limit on custom tools. Wrap anything that could hang in `TimeConstrained`.

## Where tool code runs

- **A local server is one long-running kernel.** Definitions and other kernel state persist between calls until the
  client stops the server. The kernel starts with `-noinit`, so nothing from the user's `init.m` is loaded.
- **`CreateMCPServer` saves the definitions your tools depend on** with the server, so functions defined in your
  session work when the server starts later in a fresh kernel. This is fine for small tools. For anything larger,
  keep the code in a package or paclet and load it at startup with `"Initialization" :> Needs["MyPackage`"]` on the
  tool, or the `Initialization` option of `CreateMCPServer`. The package must be findable by a fresh kernel (an
  installed paclet, or `Get` with an absolute path). If you change a saved definition, create the server again with
  `OverwriteTarget -> True` and have the client restart it.
- **The working directory is the project** when the client reports one (the MCP roots capability; Claude Code and
  most coding clients do). Relative paths then resolve against the user's project. Otherwise it is whatever
  directory the client started the server in, so accept absolute paths. External programs do not follow the kernel's
  directory: pass `ProcessDirectory -> Directory[]` to `RunProcess`.
- **A cloud-deployed server is stateless.** Every request runs in a fresh kernel. See `CloudDeployment.md`.

## Different behavior per environment

Inside a running server, `$MCPEvaluationEnvironment` is `"Local"` (a stdio server started by a client) or `"Cloud"`
(a cloud deployment), and `$MCPTransport` is `"StandardInputOutput"` or `"StreamableHTTP"`. Both are `None`
elsewhere. A function can branch on them, or the tool can replace whole properties with `"Overrides"`:

```wl
LLMTool[<|
    "Name"        -> "SaveReport",
    "Description" -> "Saves a report to a file.",
    "Function"    -> saveReportToFile,
    "Parameters"  -> {"path" -> <|"Interpreter" -> "String", "Help" -> "Output file.", "Required" -> True|>},
    "Overrides"   :> If[$MCPEvaluationEnvironment === "Cloud",
        <|"Description" -> "Saves a report to a cloud object.", "Function" -> saveReportToCloud|>,
        <||>
    ]
|>]
```

Overrides are applied when a server starts, not when you call the `LLMTool` directly.

## Using existing tools

- Built-in tools are referenced by name in a server's `"Tools"` list: `Keys[$DefaultMCPTools]`.
- Tools from a paclet are referenced by qualified name: `"Publisher/Paclet/ToolName"`.
- If two tools in one server have the same name, the server appends numbers to tell them apart (`Search1`,
  `Search2`), so prefer distinct names.
