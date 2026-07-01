# Progress

Append concise notes about your progress to this file (don't remove existing notes). Include the following types of information:

- What was achieved during this session
- Anything you learned that would be helpful to others resuming your work

Use the following format incrementing the session number from the latest entry:

## Session {sessionNumber}

{your notes}

## Session 1

**Completed Task 1: `Kernel/Server/` refactor** (transport-agnostic move, no behavior change).

Split `Kernel/StartMCPServer.wl` (1145 lines) into a new `Kernel/Server/` directory:
- `Server.wl` — aggregator (mirrors `Tools/Tools.wl`): declares server-session state in its public
  header, inits `$currentMCPServer = None`, loads `Shared.wl` then `Local.wl` via `$subcontexts`, and
  `Union`s them into `$AgentToolsContexts`.
- `Shared.wl` (context `…Server`Shared`) — transport-agnostic core: `handleMethod` + all handlers,
  `initializeServerState` (new), tool/prompt resolution, `evaluateTool`, result formatting,
  `initResponse`, bootstrapping (`ensurePacletsForStart` etc.), logging helpers.
- `Local.wl` (context `…Server`Local`) — stdio: `StartMCPServer`, `startMCPServer` (now calls
  `initializeServerState`), read loop, `stealthCatchTop`, warmup, `superQuiet`.
- Deleted `Kernel/StartMCPServer.wl` (the `ResourceDefinition.nb` file list is auto-generated later,
  per the user, so no notebook edit needed).

**Symbol placement (important for later tasks):**
- `handleMethod`, `initializeServerState` → declared in `CommonSymbols.wl` (paclet-wide, per spec).
- Server-session state → declared in `Server.wl` public header (`…Server`<name>`):
  `$currentMCPServer`, `$toolList`, `$llmTools`, `$promptList`, `$promptLookup`, `$logFile`,
  `$warmupTask`, and **`stealthCatchTop`** (see gotcha below).
- `$clientName`, `$protocolVersion`, `$waImageFetchTimeout`, `$logTimeStamp` → file-private to
  `Shared.wl` (only read within Shared; contrary to the spec's hint, `$clientName` is not read
  elsewhere in the paclet).
- `initializeServerState[obj]` returns `<|"ToolList","LLMTools","PromptList","PromptLookup","ToolOptions"|>`;
  `Local` Blocks these around the read loop exactly as before.

**Gotcha found & fixed (not in the spec):** the spec's file-assignment table places `stealthCatchTop`
in `Local.wl`, but `evaluateTool` (moved to `Shared.wl`) calls it — so a Shared reference would
resolve to an undefined `Server`Shared`Private`stealthCatchTop` and corrupt **every** tool call's
result. Fixed by declaring `stealthCatchTop` in the `Server.wl` shared header (definition stays in
`Local.wl`). Task 4's `Cloud.wl` handler reuses `evaluateTool`, so it inherits this correctly.
Systematically checked both directions for other cross-context leaks — none remain.

**Dead code:** dropped `$toolWarmupDelay` (set once, never read). `$warmupTask` is never actually
assigned anywhere (vestigial no-op `TaskRemove`), but declared in the Server header per spec so the
Shared reader and any future Local writer bind the same symbol.

**Test context updates** (mechanical, behavior unchanged): `StartMCPServer`Private`<x>` →
`Server`Shared`Private`<x>` for the moved functions across Graphics/MCPApps/EvaluatorSessions/
InternalFailureFormatting/Prompts/ToolOptions/StartMCPServer `.wlt`; special cases: `handleMethod` →
`Common`handleMethod`, `$toolList` → `Server`$toolList`, `stdinShutdownQ` → `Server`Local`Private`.

**Verification:**
- CodeInspector clean on all `Kernel/Server/*.wl`.
- MCPApps/Graphics/Prompts/ToolOptions/InternalFailureFormatting/EvaluatorSessions/MCPServerObject:
  **100% pass**.
- Wrote a throwaway in-process `.wlt` (initializeServerState + handleMethod for
  initialize/tools/list/tools/call/unknown-method) → **all pass**, directly validating the full
  refactored dispatch and the `stealthCatchTop` fix. (Deleted after.)
- `Tests/StartMCPServer.wlt`: 57/85 pass; the 28 failing tests are the subprocess integration tests
  that return `EndOfFile`. **Verified via `git stash` that these fail *identically* on the pre-refactor
  baseline** — a pre-existing Windows/TestReport subprocess stdin/stdout limitation (the test file's
  own header comment warns about it), **not** a regression.

**Environment notes for future sessions:**
- No `.mx` file exists, so the loader always loads from source — no MX rebuild needed after edits.
- To test refactored server code, prefer `TestReport` (fresh kernel) or an in-process `handleMethod`
  `.wlt`. Avoid `Get["Wolfram`AgentTools`"]` in the running WolframLanguageEvaluator kernel — that
  reloads the in-progress paclet into the live MCP server.
- `Scripts/StartMCPServer.wls` and other file references point at the `.wls` script (unchanged); only
  `ResourceDefinition.nb` referenced the deleted `.wl` file (auto-regenerated, ignore).
