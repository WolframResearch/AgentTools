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

## Session 2

**Completed Task 2: Protocol-version negotiation (shared).** The one deliberate behavior change
carved out of the Task 1 refactor.

**Source changes:**
- `Kernel/Server/Shared.wl`: replaced the hardcoded file-private `$protocolVersion = "2024-11-05"`
  (Configuration block) with `$supportedProtocolVersions = {"2025-11-25","2025-06-18","2025-03-26",
  "2024-11-05"}` (newest first) and `$preferredProtocolVersion = "2025-11-25"`. Added the internal
  `negotiateProtocolVersion` helper (new subsubsection right after `initResponse`) and changed
  `initResponse`'s `"protocolVersion"` field from `$protocolVersion` to
  `negotiateProtocolVersion @ clientMsg`.
- `Kernel/CommonSymbols.wl`: declared `$preferredProtocolVersion` and `$supportedProtocolVersions`
  in the "MCP server dispatch" section so both transports (and Task 4's `Cloud.wl`) can reach them.

**How negotiation resolves (important for later tasks):**
- `negotiateProtocolVersion[clientMsg_Association]` reads `clientMsg["params","protocolVersion"]`
  and recurses; `negotiateProtocolVersion[version_String] /; MemberQ[$supportedProtocolVersions, …]`
  echoes a supported version; the `_` fallback returns `$preferredProtocolVersion`. So missing params,
  missing/absent protocolVersion, non-string junk, and unsupported versions ALL fall back to preferred
  — fail-safe, no errors.
- `initResponse`'s two entry paths both feed the 5-arg overload: `initResponse[obj, msg]` (from
  `handleMethod["initialize"]`) passes the real client message; `initResponse[obj]` / the 4-arg form
  route through `<||>`, which negotiates to preferred. No caller change needed.

**Symbol-context note:** like `$mcpEvaluation`/`$clientSupportsUI`, the two new symbols are *declared*
in `Wolfram`AgentTools`Common`` but *assigned* their default values at the top of `Shared.wl`'s
Private section — the bare names resolve to the Common context via `Needs`. Tests reference them as
`Wolfram`AgentTools`Common`$supportedProtocolVersions` etc.

**Tests — new `Tests/CloudDeployment.wlt` (19 tests, all in-process, 100% pass):** bootstraps the
file Tasks 3–8 will extend. Covers: config symbol values + the invariant that preferred ∈ supported;
`negotiateProtocolVersion` string form (echo old/new/intermediate, unknown→preferred, non-string→
preferred); client-message form (supported/unknown/missing-version/empty); and end-to-end via
`initResponse` (echo supported 2024-11-05 & 2025-11-25, unknown→preferred, 4-arg & empty-msg→preferred).
These call the *exact* shared `initResponse`/`negotiateProtocolVersion` code the local stdio server
runs, so they directly verify "the local stdio server negotiates correctly for old/new/unknown."

**Decision — did NOT modify `Tests/StartMCPServer.wlt`** (listed in the task's Files but left
untouched deliberately): its existing assertions expect `protocolVersion == "2024-11-05"` when
`MCPInitialize` sends its default `2024-11-05`; under negotiation a supported version is echoed, so
those stay correct. Adding subprocess-level negotiation tests there would be unverifiable in this
sandbox (see env note) and redundant with the in-process coverage.

**Verification:**
- `Tests/CloudDeployment.wlt`: **19/19 pass**.
- `Tests/MCPApps.wlt`: **83/83 pass** — its direct `initResponse` tests (empty `<||>` clientMsg) still
  pass since they only assert key existence, not the version value.
- CodeInspector: **clean** on `Kernel/Server/Shared.wl` and `Kernel/CommonSymbols.wl`.
- `Tests/StartMCPServer.wlt`: 51/85 pass, 34 fail — **verified identical to the git-stash baseline**
  (changes reverted), so **zero regression**. See env note below for why the 34 fail.

**Environment note (updates Session 1's diagnosis):** the 34 `StartMCPServer.wlt` failures are NOT a
TestReport stdin/stdout quirk — the `wolframscript` binary is simply absent at
`/usr/local/Wolfram/WolframEngine/14.3/Executables/wolframscript`, so `StartMCPTestServer` fails with
`StartProcess::pnfd` and every downstream subprocess test cascades (`MCPTestServerNotRunning` →
`Missing["KeyAbsent","result"]`). None reference protocol versions or the new symbols. The pass count
is a stable 51 here (Session 1's "57" was subprocess-spawn flakiness). Bottom line: **no subprocess
integration test can run in this sandbox**; rely on in-process `.wlt` files (fresh `TestReport` kernel)
for verification, as done here.
