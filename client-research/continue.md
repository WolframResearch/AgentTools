<!-- cspell: ignore continuedev -->

# Continue MCP Client Research

## Overview

[Continue](https://www.continue.dev/) is an open-source AI code assistant. It ships in three forms — a VS Code extension, a JetBrains plugin, and a standalone CLI called `cn` (installed via `npm i -g @continuedev/cli`) — and all three read the **same** configuration files. The Continue CLI docs state explicitly: *"`cn` uses `config.yaml`, the exact same configuration file as Continue,"* and *"`cn` supports MCP tools, which can be configured in the same way as with the Continue IDE extensions."* This means a single `InstallMCPServer["Continue", ...]` covers every distribution. Continue acts as an MCP **Host** that orchestrates user-configured MCP servers.

> **Important:** MCP can only be used in Continue's **agent mode** — it is not active in autocomplete or chat-only modes.

Official references:

- [Continue docs – MCP tools (overview)](https://docs.continue.dev/customize/mcp-tools)
- [Continue docs – MCP deep dive](https://docs.continue.dev/customize/deep-dives/mcp)
- [Continue docs – `config.yaml` reference / `mcpServers`](https://docs.continue.dev/reference#mcpservers)

This research note was originally written when the AgentTools paclet had **no YAML support** and **no precedent for array-rooted MCP entries**, which led to a recommended JSON-workaround approach. Both of those blockers have since been resolved by other client integrations — see [§Implementation Assessment](#implementation-assessment) for the current recommendation.

## Configuration Details

### Config file locations

Continue supports two configuration approaches, and both are read at runtime:

#### 1. Global configuration (single YAML file)

| Platform | Path |
|----------|------|
| macOS / Linux | `~/.continue/config.yaml` |
| Windows | `%USERPROFILE%\.continue\config.yaml` |

> **Note:** If both `config.yaml` and a legacy `config.json` exist in `~/.continue/`, `config.yaml` takes precedence. Continue is actively migrating to YAML as the preferred format.

#### 2. Project-level configuration (directory of "block" files)

| Scope | Path |
|-------|------|
| Project | `<workspace>/.continue/mcpServers/*.yaml` (or `*.json`) |

The `.continue/mcpServers/` directory is intentionally a **directory of independent files**, one per server (or per logical group), rather than a single merged file. Continue picks all of them up automatically.

### YAML format (preferred)

#### Global `config.yaml`

The top of every Continue `config.yaml` requires `name`, `version`, and `schema` — these are the same metadata fields needed by standalone block files (see below) and are **not** optional. The official [`config.yaml` reference](https://docs.continue.dev/reference) says: *"The top-level properties in the `config.yaml` configuration file are: `name` (required), `version` (required), `schema` (required)."* If any are missing, Continue's CLI and IDE plugin silently reject the file and fall back to a hub-hosted "Default Config" with none of the user's MCP servers visible.

MCP servers themselves are defined under the `mcpServers` key as an **array of objects** (not a keyed object like Claude Desktop):

```yaml
name: Local Config
version: 1.0.0
schema: v1
mcpServers:
  - name: WolframLanguage
    command: wolfram
    args:
      - "-run"
      - 'PacletSymbol["Wolfram/AgentTools","Wolfram`AgentTools`StartMCPServer"][]'
      - "-noinit"
      - "-noprompt"
    env:
      MCP_SERVER_NAME: WolframLanguage
```

**Required fields per entry:**

- `name` (string) — display name for the server; also used as the upsert key
- `command` (string) — executable to run (required for stdio transports)

**Optional fields per entry:**

- `args` (array of strings) — command-line arguments
- `env` (object) — environment variables
- `cwd` (string) — working directory
- `type` (string) — explicit transport; one of `stdio`, `sse`, `streamable-http`. Often inferred automatically from the presence of `command` vs. `url`.
- `url` (string) — endpoint URL (required for `sse` / `streamable-http`)
- `connectionTimeout` (number) — initial connection timeout in milliseconds
- `requestOptions` (object) — HTTP options for remote transports

#### Standalone block files in `.continue/mcpServers/`

Per-project block files require the same top-level metadata as the global `config.yaml`:

```yaml
name: Wolfram
version: 1.0.0
schema: v1
mcpServers:
  - name: WolframLanguage
    command: wolfram
    args: ["-run", "...", "-noinit", "-noprompt"]
```

**Required top-level fields (same as global `config.yaml`):**

- `name` (string) — identifier for this block; for a project-scope block file `wolfram.yaml`, the natural value is `"Wolfram"` (the server's display name)
- `version` (string) — version of the block
- `schema` (string) — schema version (currently always `v1`)

### JSON format (drop-in compatibility)

Continue's `.continue/mcpServers/` directory also accepts JSON files using the Claude-Desktop-style keyed-object shape:

```json
{
  "mcpServers": {
    "WolframLanguage": {
      "command": "wolfram",
      "args": ["-run", "...", "-noinit", "-noprompt"],
      "env": { "MCP_SERVER_NAME": "WolframLanguage" }
    }
  }
}
```

This path exists explicitly to let users copy configuration from other tools (Claude Desktop, Cursor, Cline). The deep-dive page notes: *"You can copy those JSON config files directly into your `.continue/mcpServers/` directory…and Continue will automatically pick them up."* As of May 2026 this drop-in is **not** deprecated, but it is positioned as a compatibility shim rather than the native format.

### Environment variables and secrets

Continue supports two mechanisms in `env` values:

- Plain string values (passed straight to the spawned process)
- Continue Hub secrets via `${{ secrets.SECRET_NAME }}` placeholders, resolved at launch time

`InstallMCPServer` does not need to know about the secrets syntax — it would just write literal values that are already in `env`.

### Transport types

Continue supports three transport types: `stdio`, `sse`, and `streamable-http`. `type` can usually be omitted and Continue infers it from whether `command` or `url` is present. For the Wolfram MCP server (stdio only), no `type` field is needed.

### Configuration scope summary

| Scope | Support |
|-------|---------|
| Global | Yes (`~/.continue/config.yaml`, single file) |
| Project | Yes (`<workspace>/.continue/mcpServers/<name>.yaml` or `.json`, one file per block) |

## Format Comparison with Existing Supported Clients

| Property | Continue | Claude Desktop / Junie / Cursor | AugmentCodeIDE | Goose |
|---|---|---|---|---|
| File format | YAML (preferred) / JSON (compat) | JSON | JSON | YAML |
| `mcpServers` shape | **Array of entries with inline `name`** | Object keyed by name | Top-level array (no `mcpServers` key) | Object keyed by name (under `extensions`) |
| Per-server `name` location | Inside the entry | As the object key | Inside the entry | As the object key |
| Project scope | Yes (directory of files) | Varies | No | No |

The shape that most closely matches Continue is **AugmentCodeIDE** — the upsert/delete-by-name-field logic carries over directly. The format that most closely matches Continue is **Goose** — both round-trip YAML and need to preserve user edits to a shared file.

## Mapping to AgentTools

### Central definition

A new entry would go in `$supportedMCPClients` in [`Kernel/SupportedClients.wl`](../Kernel/SupportedClients.wl) following the same pattern as other clients. The key facts that drive the entry:

- Two scopes: a single global YAML file *and* a per-project directory of files.
- Each MCP-server entry is an array element with an inline `name` field, requiring upsert/delete-by-name (not by association key).
- YAML round-tripping is required to preserve unrelated user content in `config.yaml`.

### Proposed `$supportedMCPClients` entry

| Field | Suggested value |
|-------|------------------|
| Canonical name   | `"Continue"` |
| Display name     | `"Continue"` |
| `DefaultToolset` | `"WolframLanguage"` (coding agent, matches Cursor/Junie/etc.) |
| Aliases          | `{ }` |
| `ConfigFormat`   | `"YAML"` |
| `ConfigKey`      | `{ "mcpServers" }` (array under this key, not a keyed dict) |
| `URL`            | `"https://www.continue.dev/"` |
| `InstallLocation`| `{ $HomeDirectory, ".continue", "config.yaml" }` (same path on every OS, under `$HomeDirectory`) |
| `ProjectPath`    | `{ ".continue", "mcpServers", "wolfram.yaml" }` (project scope writes a single standalone block file) |
| `ServerConverter`| `convertToContinueFormat` — strips the keyed-object shape and emits a 1-element array entry with an inline `name` field, plus (project scope only) the standalone-file metadata `name`/`version`/`schema` |

### JSON merge and install path

This is the only client that combines two patterns already in the codebase:

1. **YAML round-tripping** (precedent: Goose — `installMCPServer[...] /; $installClientName === "Goose"` plus `readExistingGooseConfig` and `Kernel/YAML.wl`'s `importYAML` / `exportYAML`).
2. **Array-rooted server collection where the server name is a field on each entry, not a dict key** (precedent: AugmentCodeIDE — `installMCPServer[...] /; $installClientName === "AugmentCodeIDE"` plus `readExistingAugmentCodeIDEConfig`, name-based `FirstPosition` upsert and `DeleteCases` removal).

Continue is essentially *"do what AugmentCodeIDE does, but on a YAML file, and the array lives under `mcpServers` rather than at the root."*

### Other code to update for a full implementation

1. **Dedicated `installMCPServer` overload** in [`Kernel/InstallMCPServer.wl`](../Kernel/InstallMCPServer.wl) guarded by `/; $installClientName === "Continue"`. Reads existing YAML, upserts the entry by `name` inside `mcpServers`, writes back.
2. **Dedicated `uninstallMCPServer` overload** that filters the array by `name`.
3. **A `readExistingContinueConfig` helper** modeled on `readExistingAugmentCodeIDEConfig` and `readExistingGooseConfig`. Returns an `Association` on missing/empty file; surfaces `InvalidMCPConfiguration` on any parse failure.
4. **`guessClientName`** path detection for `.continue/config.yaml` and `.continue/mcpServers/<*>.yaml|json`, alongside the existing Kiro / Augment / Junie entries.
5. **`convertToContinueFormat`** in [`Kernel/SupportedClients.wl`](../Kernel/SupportedClients.wl) — takes the standard server association and returns the Continue-shaped entry. For global scope, an `Association` with `name`/`command`/`args`/`env`. For project scope, the dedicated install overload wraps that in the standalone-file shape with `name`/`version`/`schema` top-level metadata.
6. **Tests** in [`Tests/InstallMCPServer.wlt`](../Tests/InstallMCPServer.wlt) — install location per OS, project-path shape, install/uninstall round-trip on both scopes, name-based upsert idempotency, multi-server, standalone-file metadata, path-based auto-detection, `$SupportedMCPClients` metadata, count bump.
7. **User-facing docs** in [`docs/mcp-clients.md`](../docs/mcp-clients.md) — table row and a "Continue" subsection covering global vs. project scope and the YAML+array shape.
8. **`README.md`** — supported-clients table row.
9. **`AgentSkills/References/SetUpWolframMCPServer.md`** + 4 generated skill copies — table row.
10. **`TODO/more-mcp-clients.md`** — mark as done.

No changes to `PacletInfo.wl` or `Kernel/Main.wl` are required (client support is internal metadata plus existing `InstallMCPServer`).

## Implementation Assessment

### Feasibility: **Feasible — no architectural blockers**

The two original blockers identified in the first pass of this research are no longer relevant:

| Original blocker | Status |
|---|---|
| Paclet had no YAML support | **Resolved.** [`Kernel/YAML.wl`](../Kernel/YAML.wl) (`importYAML`, `importYAMLString`, `exportYAML`, `exportYAMLString`) shipped with the Goose integration and round-trips comments/structure cleanly. |
| Array-shaped `mcpServers` with inline `name` field was a novel format | **Resolved.** `AugmentCodeIDE` already implements array-rooted upsert-by-name. The same algorithm (with the path one level deeper, under the `mcpServers` key) applies here. |

### Recommended approach: native YAML, not the JSON drop-in workaround

The first pass of this research recommended writing JSON files into `.continue/mcpServers/` to sidestep YAML. **That recommendation is now superseded** in favor of writing native YAML into the user's main `config.yaml` (global) or a `.continue/mcpServers/wolfram.yaml` standalone block (project). Reasons:

1. **YAML support exists.** The original reason to avoid YAML doesn't apply anymore.
2. **The JSON drop-in is positioned as a compatibility shim, not the native path.** Continue is migrating *to* YAML; writing into the format Continue is actively standardizing on is more durable than relying on an interop convenience.
3. **Single source of truth at global scope.** Writing into `~/.continue/config.yaml` puts our entry alongside everything else the user has configured, instead of dropping a side-file the user may never look at.
4. **Symmetry with project scope.** Continue's project scope is intrinsically file-per-block; writing `.continue/mcpServers/wolfram.yaml` mirrors the global pattern exactly with one extra metadata block.

### Risks and verification

- **`guessClientName` collisions.** A YAML file with `mcpServers:` at the top of `~/.continue/config.yaml` is unique enough by path that path-based matching via `installLocation` / `ProjectPath` is sufficient. We should *not* rely on a content-level heuristic for Continue, because the same `mcpServers` key is used by every other JSON-based client. This mirrors how `Kiro` is handled today.
- **Preserving user-edited YAML.** `exportYAML` already round-trips Goose user content. Continue's `config.yaml` is more elaborate (it has top-level `models:`, `slashCommands:`, `rules:`, etc.) — the install path needs to read-modify-write with `importYAML`, mutate only the `mcpServers` array, and re-export, never overwriting the whole file. The Goose path already does the equivalent.
- **`cn` does not auto-discover project-scope files.** Verified May 2026 (against `cn` v1.5.47): writing a uniquely-named server into `<project>/.continue/mcpServers/wolfram.yaml` and launching `cn` from inside `<project>` shows only the global Wolfram entry, **not** the project-scope one. Continue's IDE extensions (VS Code + JetBrains) do auto-discover those files; the CLI does not. Implementation choice in AgentTools: still write the project-scope file as documented (it works for the IDE extensions), and surface the limitation in [docs/mcp-clients.md](../docs/mcp-clients.md) for CLI-only users. Workaround for CLI users is `cn --config <path-to-block-file>`.
- **`cn` defaults to a Hub-hosted config**, not the local file. The CLI's `Config: Default Config` header refers to `continuedev/default-cli-config` from the Continue Hub, not `~/.continue/config.yaml`. Users must pass `--config` explicitly or switch via `/config` inside `cn`. The IDE extensions don't have this problem — they default to the local file.
- **Top-level metadata fields are required at every scope.** The Continue [`config.yaml` reference](https://docs.continue.dev/reference) requires `name`, `version`, and `schema` at the top level of every config.yaml — both the user's global file and every standalone block file in `.continue/mcpServers/`. A file missing any of them fails schema validation and is silently rejected. The install path must add them when absent (and never overwrite a user-chosen `name`). Suggested defaults:
  - `name`: `"Wolfram"` for project-scope block files (the server's display name); `"Local Config"` for the global `config.yaml`
  - `version`: `"1.0.0"`
  - `schema`: `"v1"`
  - *Original mistake (corrected May 2026)*: this note initially claimed these metadata fields were only required for "standalone files"; in fact they're required for the global `config.yaml` too. Without them the CLI shows "Default Config" with no servers, masquerading as a no-op install.
- **Field naming on each MCP entry.** Continue does *not* use Cline-style `disabled` / `autoApprove` or Copilot-style `tools`. Don't emit those. The plain `name`/`command`/`args`/`env` set is sufficient.
- **JetBrains AI Assistant and Continue are distinct clients.** The JetBrains AI Assistant plugin is a separate target (not yet supported here); Continue's IDE plugin is the one configured via `~/.continue/config.yaml`.
- **Windows home resolution.** `$HomeDirectory` resolves to `%USERPROFILE%` (e.g. `C:\Users\<user>`) on Windows. AgentTools already relies on this for every other client; no new risk here.

### Recommendation

**Implement.** Continue is a widely-used open-source IDE-extension AI assistant, its MCP configuration is well-documented and stable, both transports of interest (stdio for the Wolfram MCP server) work cleanly, and the two pieces of infrastructure that were previously missing (YAML round-trip, array-shaped MCP entries) are now in place. Estimated scope: roughly the size of `AugmentCodeIDE` — one dedicated install/uninstall overload pair, one converter, one read helper, the usual tests + docs row in five places. Best handled as its own PR after the current Junie + cloud-guard work merges.

## References

- [Continue docs – MCP tools overview](https://docs.continue.dev/customize/mcp-tools)
- [Continue docs – MCP deep dive](https://docs.continue.dev/customize/deep-dives/mcp)
- [Continue docs – `config.yaml` reference (`mcpServers`)](https://docs.continue.dev/reference#mcpservers)
- [Continue docs – YAML migration](https://docs.continue.dev/customize/yaml-migration)
- [Continue blog – Model Context Protocol x Continue](https://blog.continue.dev/model-context-protocol/)
- AgentTools precedent: [`Kernel/SupportedClients.wl`](../Kernel/SupportedClients.wl) (entry shape), [`Kernel/InstallMCPServer.wl`](../Kernel/InstallMCPServer.wl) (Goose YAML overload, AugmentCodeIDE array-rooted overload), [`Kernel/YAML.wl`](../Kernel/YAML.wl) (YAML round-trip)
