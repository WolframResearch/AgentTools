# Setting Up the Wolfram MCP Server

This guide explains how to connect your client to a Wolfram MCP server. With an MCP server you call the Wolfram tools directly instead of running the bundled scripts. A local server also keeps one Wolfram Language session alive between calls (definitions persist, and no kernel has to start for each call) and provides more tools.

There are two options:

| | Wolfram Local MCP | Wolfram Cloud MCP |
| --- | --- | --- |
| Requires | A local Wolfram installation (Wolfram Engine, Wolfram, or Mathematica) | Nothing: free, no subscription or API key |
| Tools | Depends on the toolset ([Step 3](#step-3-choose-a-toolset)) | `WolframContext`, `WolframLanguageEvaluator`, `WolframAlpha` |
| Evaluation | Persistent session | Stateless, 60-second default time limit |
| Agent skills | `DeployAgentTools` installs them with the server | Not included |

Use the local server for coding agents and for anything that needs heavy computation, notebooks, tests, or paclet tools. Use Wolfram Cloud MCP when there is no local Wolfram installation and the user does not want to install one.

Both options change the user's client configuration, so ask the user before setting either one up. Also ask which toolset they want if the context does not make it clear. New MCP servers appear only after the client is restarted or reloaded, so the tools will not show up in your current session.

---

## Option 1: Wolfram Local MCP

### Step 1: Check for `wolframscript`

```bash
wolframscript -code '$VersionNumber'
```

If `wolframscript` is not found, read `GetWolframEngine.md` (in this `references/` directory) or use [Option 2](#option-2-wolfram-cloud-mcp). Current versions of AgentTools require Wolfram 15.0 or later.

The commands below are written for a POSIX shell. On Windows, shell quoting can mangle the double quotes in the code. To avoid that, put the code in a `.wls` file, wrap each result in `Print[...]`, and run `wolframscript -f file.wls`.

### Step 2: Install or update the AgentTools paclet

```bash
wolframscript -code 'PacletInstall["Wolfram/AgentTools", UpdatePacletSites -> True]["Version"]'
wolframscript -code 'Wolfram`AgentTools`AgentToolsObject["WolframLanguage"]["AgentSkillNames"]'
```

Wolfram 15 includes an older built-in copy of AgentTools. The first command installs the latest version, and Wolfram uses that version from then on. The second command should print `{wolfram-language, wolfram-notebooks, wolfram-paclets, wolfram-debugging}`. If it prints `{}`, or the expression comes back unevaluated, the installed AgentTools cannot install agent skills. In that case use `InstallMCPServer` ([Step 5](#step-5-install-the-server)).

### Step 3: Choose a toolset

| Toolset | MCP tools | Agent skills installed by `DeployAgentTools` |
| --- | --- | --- |
| `Wolfram` | `WolframContext`, `WolframLanguageEvaluator`, `WolframAlpha` | `wolfram-language`, `wolfram-alpha`, `wolfram-debugging` |
| `WolframAlpha` | `WolframAlphaContext`, `WolframAlpha` | `wolfram-alpha` |
| `WolframLanguage` | `WolframLanguageContext`, `WolframLanguageEvaluator`, `ReadNotebook`, `WriteNotebook`, `SymbolDefinition`, `CodeInspector`, `TestReport` | `wolfram-language`, `wolfram-notebooks`, `wolfram-paclets`, `wolfram-debugging` |
| `WolframPacletDevelopment` | The `WolframLanguage` tools plus `CreateSymbolDoc`, `EditSymbolDoc`, `EditSymbolDocExamples`, `CheckPaclet`, `BuildPaclet`, `SubmitPaclet` | `wolfram-language`, `wolfram-notebooks`, `wolfram-paclets`, `wolfram-debugging` |

- **Use cases:** `Wolfram` is for general computation and knowledge, `WolframAlpha` for Wolfram|Alpha queries only, and `WolframLanguage` for Wolfram Language development. `WolframPacletDevelopment` adds tools for writing documentation pages and for checking, building, and submitting paclets.
- **Tools:** the `*Context` tools are semantic search (`WolframAlphaContext` over Wolfram|Alpha, `WolframLanguageContext` over Wolfram Language documentation and resources, `WolframContext` over both). `ReadNotebook`/`WriteNotebook` convert notebooks (`.nb`) to and from markdown, `SymbolDefinition` retrieves symbol definitions, `CodeInspector` reports code issues, and `TestReport` runs `.wlt` test files.
- **Default toolset:** without a toolset argument, the client's default is used: `Wolfram` for Claude Desktop, Goose, and LM Studio, and `WolframLanguage` for every other client.
- **One toolset per client:** all four toolsets use the MCP configuration key `Wolfram`, so a client (at a given user or project level) has only one of them. Switch with `OverwriteTarget -> True`, or use `"MCPServerName"` (Step 5) to install two side by side.
- **LLMKit:** the context tools work best with an [LLMKit](https://www.wolfram.com/notebook-assistant-llm-kit) subscription. `WolframAlphaContext` requires one, so installing the `WolframAlpha` toolset fails with `LLMKitRequired` unless the kernel is connected to the Wolfram Cloud with an account that has LLMKit (use `Wolfram` instead). For the other toolsets, an `LLMKitSuggested` warning is informational only.

### Step 4: Choose `DeployAgentTools` or `InstallMCPServer`

**`DeployAgentTools` is the recommended way.** It installs the toolset's MCP server **and** its agent skills as one tracked deployment, which `DeleteObject` can remove again. `InstallMCPServer` writes only the MCP server configuration. Use it only when the MCP server is all that should be installed.

You are reading this from a Wolfram skill that is already installed, so check two things first:

1. **Existing deployments:** run `wolframscript -code 'DeployedAgentTools[]'`. If your client and location already have a deployment, the server is already configured. Ask the user to restart the client, or redeploy with `OverwriteTarget -> True` to switch toolsets or to add the skills that an older AgentTools did not install.
2. **Where this skill is installed:** this is the directory that contains this `references/` folder. Compare its parent directory with the skills directory that `DeployAgentTools` will use ([Supported Clients](#supported-clients)).

Use **`DeployAgentTools`** when this skill is already in that directory (same client, same user or project scope), or when no Wolfram skills are installed yet. It handles existing skills safely:

- **An identical copy** is adopted as is, and `DeleteObject` never deletes a skill directory that existed before the deployment.
- **A copy with different content** (installed by hand or by another tool, or a deployed copy that the user modified) is left untouched. The MCP server and the other skills are still installed, and the warning `DeployAgentTools::AgentSkillNotInstalled` names the skipped skill.
- **Copies installed by an earlier deployment** are updated to the current AgentTools version automatically; a newer copy that another deployment still uses is never downgraded. (Replacing a deployment for the same client and location still needs `OverwriteTarget -> True`.)

Use **`InstallMCPServer`**, or `DeployAgentTools` with `"SkillsDirectory" -> None` (only the MCP server, still tracked as a deployment), when:

- **The user only wants the MCP server**, or Step 2 showed that the installed AgentTools has no agent skills.
- **The Wolfram skills are installed somewhere that `DeployAgentTools` does not manage, but that your client also reads.** `DeployAgentTools` would add a second copy, and the client would see each skill twice. Examples: a Claude Code plugin (a path under `~/.claude/plugins/`); another skills directory that your client loads, such as `~/.agents/skills` or `~/.claude/skills` for a client that also reads those; or the project's skills directory while you deploy at user level (a project-level deployment also works there if the client supports project MCP configuration).

Never use `OverwriteTarget -> All` without asking the user. It replaces skill directories that the deployment does not own and discards any changes in them.

### Step 5: Install the server

`DeployAgentTools`, `DeployedAgentTools`, and `AgentToolsDeployment` are built-in symbols, so they need no context prefix:

```bash
# The client's default toolset, at user level
wolframscript -code 'DeployAgentTools["ClaudeCode"]'

# A specific toolset, at project level (the project's MCP configuration and skills directory)
wolframscript -code 'DeployAgentTools[{"ClaudeCode", "/path/to/project"}, "WolframLanguage"]'

# Only the MCP server, as a tracked deployment
wolframscript -code 'DeployAgentTools["ClaudeCode", "WolframLanguage", "SkillsDirectory" -> None]'

# Replace the Wolfram toolset already deployed for this client and location
wolframscript -code 'DeployAgentTools["ClaudeCode", "Wolfram", OverwriteTarget -> True]'
```

- **Result:** an `AgentToolsDeployment[...]`. The first run can take a few minutes while the context tools download their search indexes, so use a generous command timeout.
- **Clients without agent skills support** (Claude Desktop, LM Studio, Amazon Q Developer) get only the MCP server.
- **Project level without project MCP support:** the client gets only the project skills, with an `MCPServersNotDeployed` warning. Add the server at user level with `InstallMCPServer`.
- **`DeploymentExists`:** a Wolfram toolset is already deployed for that client and location. Use `OverwriteTarget -> True` to replace it.
- **`DeployAgentTools[All]`** deploys to every supported client, installed or not. Do not use it unless the user asks.
- **Removing:** `DeleteObject /@ Select[DeployedAgentTools["ClaudeCode"], #["Scope"] === "Global" && #["Toolset"] === "WolframLanguage" &]` removes the user-level deployment. For a project deployment, match `#["Scope"] === File["/path/to/project"]` (the absolute project path) instead; without a scope test, every project's deployment of that toolset is removed too. Skills that another deployment still uses, that were modified, or that existed before the deployment are kept.

`InstallMCPServer` needs the full context name:

```bash
wolframscript -code 'Wolfram`AgentTools`InstallMCPServer["ClaudeCode", "WolframLanguage"]'
wolframscript -code 'Wolfram`AgentTools`InstallMCPServer[{"ClaudeCode", "/path/to/project"}, "WolframLanguage"]'
wolframscript -code 'Wolfram`AgentTools`UninstallMCPServer["ClaudeCode", "WolframLanguage"]'
```

`InstallMCPServer` is not tracked by `DeployedAgentTools`. It replaces whatever Wolfram server is already configured under the key `Wolfram`.

Both functions accept these options:

- `"ToolOptions" -> <|"WolframLanguageEvaluator" -> <|"TimeConstraint" -> 120|>|>`: per-tool settings.
- `"SubmitUsageData" -> False`: opts out of usage data collection, which the built-in servers do by default.
- `"MCPServerName" -> "WolframDev"`: uses a different configuration key, so that two Wolfram toolsets can be installed side by side.

### Step 6: Restart the client

Ask the user to restart or reload the client. The tools then appear under the server name `Wolfram`, for example `mcp__Wolfram__WolframLanguageEvaluator` in Claude Code. When they are available, use them instead of the bundled scripts.

### Supported Clients

| Client | Name | Project MCP | User skills directory | Project skills directory |
| --- | --- | :---: | --- | --- |
| Amazon Q Developer | `"AmazonQ"` | yes | — | — |
| Antigravity | `"Antigravity"` | yes | `~/.gemini/config/skills` (before migration: `~/.gemini/antigravity/skills`) | `.agents/skills` |
| Augment Code | `"AugmentCode"` | no | `~/.augment/skills` | `.augment/skills` |
| Augment Code IDE | `"AugmentCodeIDE"` | no | `~/.augment/skills` | `.augment/skills` |
| Claude Code | `"ClaudeCode"` | yes | `~/.claude/skills` | `.claude/skills` |
| Claude Desktop (macOS, Windows) | `"ClaudeDesktop"` | no | — | — |
| Cline | `"Cline"` | no | `~/.cline/skills` | `.cline/skills` |
| Codex CLI | `"Codex"` | yes | `~/.agents/skills` | `.agents/skills` |
| Continue | `"Continue"` | yes | `~/.continue/skills` | `.continue/skills` |
| Copilot CLI | `"CopilotCLI"` | no | `~/.copilot/skills` | `.github/skills` |
| Cursor | `"Cursor"` | no | `~/.cursor/skills` | `.cursor/skills` |
| Gemini CLI | `"GeminiCLI"` | no | `~/.gemini/skills` | `.gemini/skills` |
| Goose | `"Goose"` | no | `~/.agents/skills` | `.agents/skills` |
| Junie | `"Junie"` | yes | `~/.junie/skills` | `.junie/skills` |
| Kimi Code | `"KimiCode"` | no | `~/.kimi/skills` | `.kimi/skills` |
| Kiro | `"Kiro"` | yes | `~/.kiro/skills` | `.kiro/skills` |
| LM Studio | `"LMStudio"` | no | — | — |
| OpenCode | `"OpenCode"` | yes | `~/.config/opencode/skills` | `.opencode/skills` |
| Qwen Code | `"QwenCode"` | yes | `~/.qwen/skills` | `.qwen/skills` |
| Visual Studio Code | `"VisualStudioCode"` | yes | `~/.copilot/skills` | `.github/skills` |
| Windsurf | `"Windsurf"` | no | `~/.codeium/windsurf/skills` | `.windsurf/skills` |
| Zed | `"Zed"` | yes | `~/.agents/skills` | `.agents/skills` |

- **Paths:** `~` is the user's home directory on every operating system. Project skills directories are relative to the project directory.
- **Aliases** are accepted, such as `"Claude"` (Claude Desktop), `"VSCode"`, `"Copilot"` (Copilot CLI), and `"Gemini"` (Gemini CLI).
- **Shared skills directories:** several clients share one. AgentTools tracks which deployments use each skill, so removing one deployment never deletes skills that another deployment still uses.
- **Non-standard configuration file:** pass `File["/path/to/config.json"]` as the target. Add `"ApplicationName" -> "<Name>"` if the path does not identify the client. With `DeployAgentTools`, also pass `"SkillsDirectory" -> File["/path/to/skills"]`, unless the file is the client's standard global or project configuration file.

---

## Local Server in Other Clients: Manual Configuration

Any MCP client that can launch local (stdio) servers can run the local Wolfram server, even if it is not in the [Supported Clients](#supported-clients) table. To print the exact configuration for this machine, run this command with the toolset you want:

```bash
wolframscript -code 'Wolfram`AgentTools`MCPServerObject["WolframLanguage"]["JSONConfiguration"]'
```

Example output on Linux, shown with `/` instead of the `\/` escapes that the real output contains (both are valid JSON):

```json
{
  "mcpServers": {
    "WolframLanguage": {
      "type": "stdio",
      "command": "/usr/local/Wolfram/Wolfram/15.0/Executables/wolfram",
      "args": [
        "-run",
        "PacletSymbol[\"Wolfram/AgentTools\",\"Wolfram`AgentTools`StartMCPServer\"][]",
        "-noinit",
        "-noprompt"
      ],
      "env": {
        "MCP_SERVER_NAME": "WolframLanguage",
        "WOLFRAM_BASE": "/usr/share/Wolfram",
        "WOLFRAM_LOCALBASE": "/home/user/.Wolfram/Objects",
        "WOLFRAM_USERBASE": "/home/user/.Wolfram"
      }
    }
  }
}
```

If the client uses this common `mcpServers` JSON format, AgentTools can write the entry (under the key `Wolfram`) for you: ``Wolfram`AgentTools`InstallMCPServer[File["/path/to/config.json"], "WolframLanguage"]`` writes only the server, and `DeployAgentTools[File["/path/to/config.json"], "WolframLanguage", "SkillsDirectory" -> File["/path/to/skills"]]` also installs the skills. Otherwise, copy the values into the client's own format; any server name works.

**Command:** the Wolfram kernel executable `wolfram`, not `wolframscript`.

| OS | Command |
| --- | --- |
| Windows | `$InstallationDirectory\wolfram.exe` |
| macOS | `$InstallationDirectory/MacOS/wolfram` |
| Linux | `$InstallationDirectory/Executables/wolfram` |

**Arguments:** four separate arguments, given to the client exactly as in the printed `"args"`:

- `-run`, followed by ``PacletSymbol["Wolfram/AgentTools","Wolfram`AgentTools`StartMCPServer"][]``. This loads the newest installed AgentTools and starts the stdio server.
- `-noinit`: skips the user's init files.
- `-noprompt`: keeps kernel prompts off standard output, which must carry only MCP messages.

As a single shell command line:

```bash
/path/to/wolfram -run 'PacletSymbol["Wolfram/AgentTools","Wolfram`AgentTools`StartMCPServer"][]' -noinit -noprompt
```

If the client cannot set environment variables, name the toolset in the argument instead: ``PacletSymbol["Wolfram/AgentTools","Wolfram`AgentTools`StartMCPServer"]["WolframLanguage"]``.

**Environment variables:**

| Variable | Needed | Purpose |
| --- | --- | --- |
| `MCP_SERVER_NAME` | Recommended | The toolset to run: `Wolfram` (the default when unset), `WolframAlpha`, `WolframLanguage`, `WolframPacletDevelopment`, or the name of another server known to AgentTools |
| `WOLFRAM_USERBASE` | Recommended | `$UserBaseDirectory`. It must be the directory where AgentTools was installed; otherwise the kernel may load the older built-in copy |
| `WOLFRAM_BASE` | Recommended | `$BaseDirectory` |
| `WOLFRAM_LOCALBASE` | Recommended | `$LocalBase` (storage for `LocalObject`) |
| `APPDATA` | Windows | The user's application data directory, from which Windows derives the default `$UserBaseDirectory` |
| `MCP_TOOL_OPTIONS` | Optional | Per-tool options as compact JSON, e.g. `{"WolframLanguageEvaluator":{"TimeConstraint":120}}` |
| `SUBMIT_USAGE_DATA` | Optional | `false` opts out of usage data collection |
| `MCP_APPS_ENABLED` | Optional | `false` disables MCP Apps (interactive UI resources) |
| `LLMKIT_ENABLED` | Optional | `false` makes the context tools behave as if there were no LLMKit subscription, without warnings |

The printed configuration already holds this machine's values for the directory variables. Keep them, because the client may start servers with a reduced environment.

---

## Option 2: Wolfram Cloud MCP

[Wolfram Cloud MCP](https://www.wolfram.com/artificial-intelligence/mcp/cloud/wolfram-mcp-cloud) is a hosted Wolfram MCP server. It is free and needs no subscription, API key, or local installation.

- **URL:** `https://agenttools.wolfram.com/mcp`
- **Transport:** Streamable HTTP, with no authentication

| Tool | Description |
| --- | --- |
| `WolframContext` | Semantic search over Wolfram\|Alpha and Wolfram Language resources |
| `WolframLanguageEvaluator` | Evaluates Wolfram Language code |
| `WolframAlpha` | Sends natural language queries to Wolfram\|Alpha |

Differences from the local server:

- **Stateless evaluation:** `WolframLanguageEvaluator` does not carry definitions over between calls. Its default time constraint is 60 seconds per call, which its `timeConstraint` argument can change.
- **No other tools:** there are no notebook, symbol definition, code inspection, test, or paclet tools. The `wolfram-notebooks` and `wolfram-paclets` skills still need `wolframscript` for their scripts.
- **Manual setup only:** `DeployAgentTools` and `InstallMCPServer` configure only the local server.

### Configure your client

Clients that support remote servers (some spell it differently: Cline adds `"type": "streamableHttp"`, Antigravity uses `"serverUrl"`; the support article below has steps for many clients):

```json
{ "mcpServers": { "wolfram": { "url": "https://agenttools.wolfram.com/mcp" } } }
```

Claude Code (add `--scope user` to make it available in all projects):

```bash
claude mcp add --transport http wolfram https://agenttools.wolfram.com/mcp
```

Visual Studio Code (the user `mcp.json` or the workspace's `.vscode/mcp.json`):

```json
{ "servers": { "wolfram": { "type": "http", "url": "https://agenttools.wolfram.com/mcp" } } }
```

Claude Desktop: in Customize → Connectors, search for Wolfram and click **+**.

Clients that only support local (stdio) servers can use the `mcp-remote` bridge, which requires Node.js:

```json
{ "mcpServers": { "wolfram": { "command": "npx", "args": ["-y", "mcp-remote@latest", "https://agenttools.wolfram.com/mcp"] } } }
```

The local `Wolfram` toolset already provides all three of these tools, so don't add the cloud server next to it. Next to another local toolset (for example `WolframLanguage`, which has no `WolframAlpha` tool), the cloud server can supply the missing tools under its own key, such as `wolfram`. Then ask the user to restart or reload the client.

---

## Troubleshooting

- **`LLMKitRequired`:** the local `WolframAlpha` toolset needs LLMKit. Use the `Wolfram` toolset or Wolfram Cloud MCP instead.
- **`DeploymentExists`:** a Wolfram toolset is already deployed for that client and location. Use `OverwriteTarget -> True` to replace it.
- **`AgentSkillNotInstalled` (warning):** a different skill with the same name already exists. Everything else was installed. Keep the existing skill, or ask the user before using `OverwriteTarget -> All`.
- **`UnknownInstallLocation`:** the client has no known configuration file on this operating system (for example, Claude Desktop on Linux). Use a `File[...]` target.
- **The tools do not appear after a restart:** check the configuration file that was written (`dep["ConfigFile"]` for a deployment, or the `"Location"` of the `InstallMCPServer` result), then the server log at `$UserBaseDirectory/ApplicationData/Wolfram/AgentTools/Servers/<Toolset>/Log.wl`. Also make sure the kernel is activated (`wolframscript -code '1+1'` prints `2`).

---

## More Information

- Wolfram Local MCP: <https://www.wolfram.com/artificial-intelligence/mcp/local/wolfram-mcp-local/>
- Wolfram Cloud MCP: <https://www.wolfram.com/artificial-intelligence/mcp/cloud/wolfram-mcp-cloud>
- Connecting Wolfram Cloud MCP to an AI application: <https://support.wolfram.com/75237>
- AgentTools paclet: <https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/AgentTools/>
