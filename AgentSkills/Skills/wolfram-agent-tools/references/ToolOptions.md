# Tool Options and Other Install Options

`InstallMCPServer` and `DeployAgentTools` take the same options for configuring the server they install. The options
are written into the client's MCP configuration (as environment variables of the server process), so they belong to
one installation: one client, at user level or in one project.

To change the options of a server that is already installed, install or deploy it again with the new options and
have the client restart the server:

```wl
DeployAgentTools["ClaudeCode", "WolframLanguage",
    "ToolOptions"   -> <|"WolframLanguageEvaluator" -> <|"TimeConstraint" -> 300|>|>,
    OverwriteTarget -> True
]
```

Options are not merged with the previous ones: pass everything the installation should have. For a deployment, the
options used last time are in `dep["MCP", "Options"]`. This changes the user's client configuration, so ask first.

## Tool options

`"ToolOptions"` is an association of tool names to option associations. It configures the built-in tools:

```wl
"ToolOptions" -> <|
    "WolframLanguageEvaluator" -> <|"Method" -> "Local", "TimeConstraint" -> 120|>,
    "WolframLanguageContext"   -> <|"MaxItems" -> 20|>
|>
```

`$DefaultMCPToolOptions` gives every option with its default for the installed version. An unknown tool or option
name only produces a warning (`UnrecognizedToolOption`, `UnrecognizedToolOptionName`), so check the spelling when
you see one.

### WolframLanguageEvaluator

| Option | Default | Meaning |
| --- | --- | --- |
| `"Method"` | `Automatic` | Where code is evaluated. `"Session"`: in the server's own kernel (the default for a local server). `"Local"`: in a separate sandboxed kernel. `"Cloud"`: each evaluation in a fresh Wolfram Cloud kernel (the default for a cloud-deployed server) |
| `"TimeConstraint"` | `60` | The time limit in seconds when the model does not pass its own `timeConstraint` |
| `"MemoryConstraint"` | `Automatic` | The memory limit in bytes for each input; `Infinity` for none. `Automatic` is 95% of the memory available when the input starts |
| `"MaxCharacterCount"` | `10000` | The length at which results are cut off |
| `"ImageExportMethod"` | `None` | How graphics in results are exported: `None`, `"Local"`, `"Cloud"`, or `"CloudPublic"` |
| `"AllowedReadPaths"`, `"AllowedWritePaths"`, `"AllowedExecutePaths"` | `Automatic` | What the sandboxed kernel of the `"Local"` method may read, write, and run |
| `"MaxSessionCount"` | `100` | How many saved evaluator sessions are kept |
| `"MaxSessionBytes"` | `1073741824` | The total size of saved evaluator sessions |
| `"MaxSessionAge"` | `Quantity[1, "Months"]` | Older saved sessions are deleted |

**Choosing a method.** `"Session"` has no restrictions: code can write files and run programs anywhere the user
can. `"Local"` runs code in a sandbox, which by default can read everything, write only to the temporary directory
and a few Wolfram directories, and run only parts of the Wolfram installation. Pick `"Local"` when the user wants
the evaluator contained, and expect that code which writes project files or calls `RunProcess` then fails unless
the paths are allowed.

**Sandbox paths** (only for `"Local"`). Each of the three options takes a path, a list of paths, or:

| Value | Meaning |
| --- | --- |
| `Automatic` | The defaults described above |
| `None` | Nothing is allowed |
| `All` | Everything is allowed |
| `{Automatic, "/path/to/project"}` | The defaults plus these paths. This is nearly always what you want |

- A list without `Automatic` replaces the defaults, which can break the sandbox itself (it has to read the Wolfram
  installation and write its session files).
- Paths are used as given: write absolute paths, with no `~` or environment variables. A path covers everything
  that starts with it, so `"/home/me/proj"` also covers `"/home/me/proj2"`.
- For `"AllowedReadPaths"`, a list with `Automatic` *narrows* reading from "everywhere" to the Wolfram directories
  plus the listed paths.
- The permissions are fixed when the server starts.

```wl
"ToolOptions" -> <|"WolframLanguageEvaluator" -> <|
    "Method"              -> "Local",
    "AllowedWritePaths"   -> {Automatic, "/home/me/project"},
    "AllowedExecutePaths" -> {Automatic, "/usr/bin/git"}
|>|>
```

### Context tools

| Tool | Option | Default | Meaning |
| --- | --- | --- | --- |
| `WolframLanguageContext` | `"MaxItems"` | `10` | The number of documentation results |
| `WolframAlphaContext` | `"MaxItems"` | `Automatic` | The maximum number of Wolfram\|Alpha results |
| `WolframAlphaContext` | `"IncludeWolframLanguageResults"` | `Automatic` | Whether results include Wolfram Language code |
| `WolframContext` | `"WolframLanguageMaxItems"` | `10` | The number of documentation results |
| `WolframContext` | `"WolframAlphaMaxItems"` | `Automatic` | The maximum number of Wolfram\|Alpha results |

The other built-in tools have no options.

### Custom tools

`"ToolOptions"` only reaches the built-in tools. To make your own tool configurable per installation, read an
environment variable in the tool function and set it with `"ProcessEnvironment"`:

```wl
maxRows[] := Replace[Environment["WIDGET_MAX_ROWS"], {s_String :> ToExpression[s], _ -> 100}];

DeployAgentTools["ClaudeCode", server, "ProcessEnvironment" -> <|"WIDGET_MAX_ROWS" -> "500"|>]
```

## Other install options

| Option | Default | Meaning |
| --- | --- | --- |
| `"MCPServerName"` | `Automatic` | The key of the server in the client configuration, which is also the name the client shows. The built-in servers all use `Wolfram` and so replace each other. Give another name to install two side by side. `UninstallMCPServer` needs the same option to find the entry |
| `"SubmitUsageData"` | `Automatic` | The built-in servers record which client and which tools are used (never any content) together with information that identifies the Wolfram installation, and send it to Wolfram. `False` turns this off for the installation. Custom servers record nothing unless this is `True` |
| `"EnableLLMKit"` | `Automatic` | `False` makes the context tools work without LLMKit features and without subscription warnings |
| `"VerifyLLMKit"` | `True` | `False` skips the check at install time that the tools' LLMKit requirements are met |
| `"EnableMCPApps"` | `True` | `False` turns off interactive results (embedded notebook views) in clients that support MCP Apps |
| `"ProcessEnvironment"` | `Automatic` | An association of extra environment variables for the server process |
| `"WolframCommand"` | `Automatic` | The executable that the client runs, instead of this installation's `wolfram` kernel |
| `"CommandLineArguments"` | `Automatic` | The arguments for that executable, as a list of strings |
| `"ApplicationName"` | `Automatic` | Which client a `File[...]` target belongs to, when the path does not show it |
| `"DevelopmentMode"` | `False` | For people working on AgentTools itself |

`DeployAgentTools` additionally has `OverwriteTarget` and `"SkillsDirectory"` (see `BundlesAndDeployments.md`).

- **Usage data** can also be turned off for all built-in servers on the machine in the Wolfram preferences (the
  checkbox for sharing usage data in the settings for agent tools). An explicit `"SubmitUsageData"` wins over that
  setting.
- **LLMKit:** `WolframAlphaContext` requires an LLMKit subscription, and the other context tools give better results
  with one. Deploying the `"WolframAlpha"` server without one fails with `LLMKitRequired`. Use `"Wolfram"` instead.
- **Another Wolfram installation:** to make a client start a different installation, pass that installation's
  kernel as `"WolframCommand"`, or simply run the deployment from that installation.
