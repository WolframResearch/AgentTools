# Agent Skills with AgentTools

An agent skill is a directory in the open [Agent Skills](https://agentskills.io/specification) format: a `SKILL.md`
with YAML frontmatter (`name`, `description`) and Markdown instructions, optionally with `scripts/`, `references/`,
and `assets/`.

**This file only covers what AgentTools adds.** How to write a good skill (what belongs in the description, how to
structure instructions, progressive disclosure, testing whether it triggers) is the same as for any other skill. If
you have a general skill for authoring skills, load it now and follow it for those parts. In Claude Code that is
Anthropic's `skill-creator`. Other agents may have their own equivalent. If you have none, follow the Agent Skills
specification linked above.

## What AgentTools does with skills

- Installs a skill into the right skills directory of any supported client (`InstallAgentSkills`, or
  `DeployAgentTools` for tracked deployments).
- Deploys skills together with the MCP servers they rely on, as one bundle (`BundlesAndDeployments.md`).
- Ships skills in a paclet, so that users get them with `DeployAgentTools` (`PacletDistribution.md`).

## Ways to specify a skill

| Form | Meaning |
| --- | --- |
| `File["path/to/my-skill"]` | A skill directory. It is copied as is, including bundled files |
| `LLMSkill[File["path/to/my-skill"]]` | The same, as an `LLMSkill` object |
| `LLMSkill[{"my-skill", "Description..."}, "Markdown body..."]` | A skill without bundled files. `SKILL.md` is generated from the name, description, and body |
| `"Publisher/Paclet/my-skill"` | A skill that a paclet defines |
| `"wolfram-language"` | A built-in skill, by name |

For anything beyond a few paragraphs, write a skill directory. It is plain files, so it can be reviewed, versioned,
and given scripts and references.

AgentTools checks two things, and fails if they do not hold:

- The name is 1 to 64 lowercase letters, digits, and hyphens, with no leading, trailing, or consecutive hyphens.
- The description is 1 to 1024 characters and not blank.

Name a skill directory after the `name` in its frontmatter. A skill is always installed under its frontmatter name,
and for a skill in a paclet a different directory name is an error.

## Skills that use Wolfram Language

A skill for Wolfram Language work usually gives the agent one or both of these:

**MCP tools.** If the skill relies on tools from an MCP server (built-in or your own), deploy the server and the
skill together as a bundle. In `SKILL.md`, refer to tools by their plain name (`WolframLanguageEvaluator`,
`WordCount`), since each client prefixes tool names differently (Claude Code: `mcp__<server>__<tool>`), and say what
to do if the tools are not available.

**Scripts.** Bundle `.wls` scripts in `scripts/` and tell the agent to run them with `wolframscript`:

```bash
wolframscript -f scripts/Analyze.wls input.csv
```

```wl
(* scripts/Analyze.wls *)
args = Rest @ $ScriptCommandLine;
If[Length[args] < 1, Print["Usage: Analyze.wls <file>"]; Exit[1]];
data = Quiet @ Import[First @ args, "CSV"];
If[! MatrixQ[data], Print["Cannot read a table from ", First @ args]; Exit[1]];
Print @ ExportString[<|"rows" -> Length[data], "columns" -> Length @ First @ data|>, "JSON", "Compact" -> True];
Exit[0]
```

- Scripts get their arguments from `$ScriptCommandLine`, and only what they `Print` reaches the agent. Print compact
  text (`ToString[expr, InputForm]`, JSON, or Markdown), and use the exit code to signal failure.
- Each run starts a fresh kernel, so nothing persists between runs, and startup costs a few seconds. For work that
  needs state or many small calls, an MCP tool is the better fit.
- Paths in `SKILL.md` are relative to the skill directory. Say so in the skill, as agents usually run commands from
  the project directory.
- State what the skill needs in the `compatibility` frontmatter field, for example
  `Requires wolframscript on PATH` or `Requires the Wolfram MCP server`.
- To call a built-in AgentTools tool from a script without an MCP server:
  ``PacletSymbol["Wolfram/AgentTools", "Wolfram`AgentTools`$DefaultMCPTools"]["WolframAlpha"][<|"query" -> "..."|>]``.

Test every script from a shell before you ship the skill.

## Installing skills

`InstallAgentSkills` copies skills into a skills directory and keeps no record of it:

```wl
InstallAgentSkills["ClaudeCode", File["path/to/my-skill"]]                       (* user level: ~/.claude/skills *)
InstallAgentSkills[{"Cursor", "/path/to/project"}, {File["skill-a"], File["skill-b"]}]
InstallAgentSkills[File["/any/skills/directory"], LLMSkill[{"my-skill", "..."}, "..."]]

UninstallAgentSkills["ClaudeCode", "my-skill"]
```

- If a different skill of the same name is already there, it fails with `AgentSkillExists`. Pass
  `OverwriteTarget -> True` to replace it. Identical content is left alone.
- `UninstallAgentSkills` deletes the named skill directory even if it was edited after it was installed.
- Claude Desktop, LM Studio, and Amazon Q Developer have no skills directory. The skills directory of every other
  client is listed in `SetUpWolframMCPServer.md`.

To have the installation tracked (listed by `DeployedAgentTools[]`, removed with `DeleteObject`, updated safely),
deploy the skill as a bundle instead. A bundle may consist of skills only:

```wl
DeployAgentTools["ClaudeCode", <|"Name" -> "MySkills", "AgentSkills" -> {File["path/to/my-skill"]}|>]
```

The agent sees a new or changed skill only after the client is restarted or reloaded.

## While developing a skill

Work on the skill directory in the project (under version control), not on the installed copy: reinstalling
replaces the installed copy. For a fast loop in one project, install at project level, and after each change run
`InstallAgentSkills[{"ClaudeCode", project}, File[dir], OverwriteTarget -> True]`.
