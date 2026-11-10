---
name: wolfram-agent-tools
description: Use when the user wants to build, customize, or share Wolfram Language tooling for AI agents with the AgentTools paclet. Typical requests are writing a custom tool or MCP server, making an agent skill that uses Wolfram Language, bundling or distributing these (for example in a paclet), deploying an MCP server to the Wolfram Cloud, and changing how an installed Wolfram MCP server or its tools are configured (options, limits, switching or removing toolsets). Not needed just to use the Wolfram tools.
compatibility: Requires the Wolfram MCP server or wolframscript on PATH
metadata:
  author: Wolfram Research
---

# Wolfram Agent Tools

How to extend and configure the AgentTools paclet (`Wolfram/AgentTools`): the paclet behind the Wolfram MCP servers
and agent skills. Paths are relative to this skill directory.

## Prerequisites

You need a Wolfram kernel (15.0 or later): the MCP evaluator (for example `mcp__Wolfram__WolframLanguageEvaluator`)
or `wolframscript`. If you have neither, read `references/GetWolframEngine.md`.

Wolfram 15 ships an older copy of AgentTools, so update it once, then load it:

```wl
PacletInstall["Wolfram/AgentTools", UpdatePacletSites -> True]["Version"]
Needs["Wolfram`AgentTools`"]
```

**Run `Needs` on its own before anything else.** An MCP evaluator call and `wolframscript -code '...'` both parse
the whole input before `Needs` runs, so AgentTools symbols in the same input can end up in the wrong context, and a
call like `CreateMCPServer[...]` comes back unevaluated. Either evaluate `Needs` in a first call and the rest in later
calls (with the MCP evaluator, pass the same `session`), use full names (``Wolfram`AgentTools`CreateMCPServer``), or
put the code in a `.wls` file with `Needs` first and `Print` what you want to see. The examples in this skill assume
that `Needs` has already been evaluated. `DeployAgentTools`, `DeployedAgentTools`, and `AgentToolsDeployment` are
built-in symbols and need no context.

## Concepts

| Thing | Wolfram Language | What it is |
| --- | --- | --- |
| Tool | `LLMTool` | A function that a model can call, with a name, description, and typed parameters |
| MCP prompt | association | A user-invoked template or function (a slash command in most clients) |
| MCP server | `MCPServerObject` | A named set of tools and prompts, run by `StartMCPServer` in its own kernel |
| Agent skill | `LLMSkill` or a directory with `SKILL.md` | Instructions (and files) that an agent loads on demand |
| Bundle | `AgentToolsObject` | MCP servers plus agent skills, deployed as one unit |
| Deployment | `AgentToolsDeployment` | A tracked installation of a bundle in one client, removable with `DeleteObject` |
| Paclet extension | `"AgentTools"` in `PacletInfo.wl` | How a paclet ships tools, prompts, servers, skills, and bundles |

The built-in servers and bundles are `"Wolfram"`, `"WolframAlpha"`, `"WolframLanguage"`, and
`"WolframPacletDevelopment"` (`$DefaultMCPServers`, `$DefaultAgentTools`); the built-in tools are in
`$DefaultMCPTools`.

## What to read

Read only the reference that matches the task.

| Task | Reference |
| --- | --- |
| Write a custom tool (parameters, return values, errors, images, initialization) | `references/Tools.md` |
| Create, test, install, or remove a custom MCP server; add MCP prompts; configure a client by hand | `references/MCPServers.md` |
| Create an agent skill that uses Wolfram Language, or install skills | `references/AgentSkills.md` |
| Combine servers and skills into a bundle; deploy, list, update, or remove deployments | `references/BundlesAndDeployments.md` |
| Distribute tools, prompts, servers, skills, or bundles in a paclet | `references/PacletDistribution.md` |
| Deploy an MCP server to the Wolfram Cloud as a remote HTTP server; API keys | `references/CloudDeployment.md` |
| Change tool options (evaluator method, time and memory limits, sandbox paths, result counts) or other install options (usage data, LLMKit, MCP Apps, server name, environment variables) | `references/ToolOptions.md` |
| Set up one of the built-in Wolfram MCP servers; supported clients and their skills directories | `references/SetUpWolframMCPServer.md` |

## Quick start

A custom tool in a custom server, tested and deployed to one project:

```wl
wordCount[KeyValuePattern["text" -> text_String]] := ToString @ Length @ TextWords @ text;

server = CreateMCPServer["TextTools", <|
    "Tools" -> {
        "WolframLanguageEvaluator",                       (* a built-in tool, by name *)
        LLMTool[<|
            "Name"        -> "WordCount",
            "Description" -> "Counts the words in a piece of text.",
            "Function"    -> wordCount,
            "Parameters"  -> {
                "text" -> <|"Interpreter" -> "String", "Help" -> "The text.", "Required" -> True|>
            }
        |>]
    }
|>];

server["Tools"][[2]][<|"text" -> "one two three"|>]       (* "3": call the tool directly first *)

DeployAgentTools[{"ClaudeCode", "/path/to/project"}, server]
```

The server is saved under `$UserBaseDirectory` together with the definitions its tools depend on, and each client
starts it in a fresh kernel. Before deploying anything nontrivial, run the stdio smoke test in
`references/MCPServers.md`.

## Ground rules

1. **Ask before changing a client's configuration.** Deploying, installing, and uninstalling edit the user's MCP
   configuration and skills directories. Never use `DeployAgentTools[All]` or `OverwriteTarget -> All` unless the
   user asks: the first writes to every supported client, and the second replaces skill directories that the
   deployment does not own.
2. **Project-level configuration is machine-specific.** A `{"Client", dir}` target writes the project's MCP
   configuration (`.mcp.json` for Claude Code) with absolute paths of this machine's Wolfram installation. Tell the
   user, so that they can decide whether to commit it.
3. **Changes need a client restart.** New or changed servers and skills appear only after the client is restarted or
   reloaded, so you cannot use them in your current session. Tell the user.
4. **Prefer `DeployAgentTools` to `InstallMCPServer`.** It records what it installed, so `DeployedAgentTools[]` lists
   it and `DeleteObject` removes it again. `InstallMCPServer` only writes the MCP configuration entry.
5. **Test before you deploy.** Call the tool function directly, then run the server over stdio. A server that fails
   in the client gives very little feedback.
6. **Check every result.** The functions return `Failure[...]` with a message instead of throwing. Read the message:
   it usually names the fix (`OverwriteTarget -> True`, a missing paclet, an unsupported client).
7. **Use distinct names.** Do not give a custom server or bundle the name of a built-in one (a custom server named
   `"Wolfram"` silently takes the place of the built-in server wherever that name is used), and keep `/` out of
   names: it marks names that come from paclets (`"Publisher/Paclet/Item"`).
8. **Creating a skill?** This skill only covers what is specific to AgentTools. If you have a general skill for
   authoring skills (for example Anthropic's `skill-creator` in Claude Code), load it too and follow it for
   everything else. See `references/AgentSkills.md`.

## Also useful

- `MCPServerObjects[]` lists the user's servers and those of installed paclets (`"IncludeBuiltIn" -> True`,
  `"IncludeRemotePaclets" -> True` for more); `AgentToolsObjects[]` does the same for bundles.
- `$SupportedClients` describes every supported client; `DetectedMCPClients[]` gives the ones that appear to be
  installed on this machine.
- `LLMConfiguration[server]` gives a server's tools as an `LLMConfiguration`, for use with `LLMSynthesize`,
  `ChatEvaluate`, and similar functions without any MCP client.
- A tool is an `LLMTool`, so `$DefaultMCPTools["WolframAlpha"][<|"query" -> "..."|>]` calls it directly.
