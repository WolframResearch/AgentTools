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
``Wolfram`AgentTools`Common`$supportedProtocolVersions`` etc.

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

## Session 3

**Completed Task 3: Self-describing session-ID capability codec.** Pure, fully unit-testable — the
foundation Task 4's `RunCloudMCPServer` will consume to round-trip client UI capability through the
`Mcp-Session-Id` header in the stateless cloud transport.

**Source changes:**
- **New `Kernel/Server/Cloud.wl`** (context `Wolfram`AgentTools`Server`Cloud`): the first Cloud-transport
  file. For now it holds only the file-scoped codec (config + two functions); Tasks 4–8 grow it.
  - Config: `$trackedFeatureList = {"MCPApps","Roots","FormElicitation","URLElicitation"}`,
    `$idVersion = "1"`, `$trackedFeatureIDs = First /@ PositionIndex[$trackedFeatureList] - 1`
    (`<|MCPApps->0,Roots->1,FormElicitation->2,URLElicitation->3|>`).
  - `makeSessionIDFromFeatureList[features]` → `"version:base36bitfield:uuid"` (encode).
  - `getFeaturesFromSessionID[id]` → feature list; fail-closed to `{}` on wrong version / malformed.
  - Header `Needs` mirror the sibling leaf files (`AgentTools`, `Common`, `Server`); footer is
    `addToMXInitialization[Null]` like `Shared.wl`/`Local.wl`.
- **`Kernel/Server/Server.wl`**: added `"Wolfram`AgentTools`Server`Cloud`"` to `$subcontexts` (the only
  registration point — it's `Union`-ed into `$AgentToolsContexts`; nothing else enumerates subcontexts).

**Key implementation decisions:**
- **Followed repo convention over the spec's literal code.** The spec gives the codec as bare
  `f[...] :=` definitions, but I wrapped both functions in `beginDefinition`/`endDefinition` to match
  AGENTS.md and the directly-analogous `negotiateProtocolVersion` (Task 2), which uses the *exact same
  shape* — a `_` catch-all returning a default (`getFeaturesFromSessionID[_] := {}` mirrors
  `negotiateProtocolVersion[_] := $preferredProtocolVersion`). Verified the algorithm is byte-for-byte
  the spec's; only the wrappers were added. CodeInspector clean, so the `_` fallback coexists fine with
  `endDefinition`'s auto-added `___` fallthrough (the `_` is more specific, wins for all valid 1-arg
  calls; `___` only catches wrong-arity).
- **Codec is genuinely file-private** — no `CommonSymbols.wl` declaration needed (Task 4's handler is in
  the same `Cloud.wl` file, so it reaches these directly).

**Verification (all in-process, fresh `TestReport` kernels):**
- Pre-validated the algorithm standalone (local symbols, paclet untouched) before writing: exact
  round-trip for **all 16 subsets**, empty→`"1:0:…"`, Intersection guard drops untracked, fail-closed
  `{}` for wrong-version/malformed/too-few-parts, unique UUIDs; spec examples reproduce (`{"MCPApps"}`→
  `"1:1:…"`, three-feature→`"1:d:…"`).
- **`Tests/CloudDeployment.wlt`: 37/37 pass** (19 protocol from Task 2 + **18 new codec tests**). Added a
  `Session-ID Capability Codec` section: Configuration (3), makeSessionID (6), getFeatures (4),
  Round-trip-all-subsets (1), Fail-closed (4). Tests reference the private symbols by full path
  (`Wolfram`AgentTools`Server`Cloud`Private`…`); the file already disables the `PrivateContextSymbol`
  rule. Association compared via `===` (order-deterministic) to sidestep MatchQ-on-assoc order questions.
- **No regression:** `MCPApps.wlt` 83/83, `MCPServerObject.wlt` 71/71 — confirms the paclet still loads
  cleanly with the new subcontext on the load path (the `CloudDeployment.wlt` `LoadContext` test also
  passes). CodeInspector clean on `Cloud.wl`, `Server.wl`, and `CloudDeployment.wlt`.

**Note for Task 4:** `RunCloudMCPServer` will (a) read the `Mcp-Session-Id` request header
case-insensitively → `getFeaturesFromSessionID` → `Block` `$clientSupportsUI = MemberQ[features,"MCPApps"]`
around dispatch; (b) on `initialize` (no incoming ID), after `handleMethod` sets the flags, encode via
`makeSessionIDFromFeatureList` into the `Mcp-Session-Id` **response** header. Both functions are ready.

## Session 4

**Scope trim (user request): v1 tracks only `"MCPApps"`.** Removed `"Roots"`, `"FormElicitation"`, and
`"URLElicitation"` from the tracked-feature list in both the spec and the code. Supersedes Session 3's
4-feature `$trackedFeatureList`/`$trackedFeatureIDs` values.

- **`Kernel/Server/Cloud.wl`**: `$trackedFeatureList = { "MCPApps" }` (was 4 features); comment now
  `<| "MCPApps" -> 0 |>`. Config comment reframed — the codec **stays list-based** so features can be
  appended later (bump `$idVersion` only if an existing bit position would shift). Codec bodies
  unchanged (they were already generic over the list).
- **`Specs/CloudDeployment.md`**: shrank the config code block + examples (now `{"MCPApps"}`→`"1:1:…"`
  and `{}`→`"1:0:…"`, keeping a one-line note that the base-36 field is a genuine bit vector that
  extends to more flags); dropped the reserved-features table row; renamed the *Reserved and future
  features* subsection to **Deferred capabilities** (roots/elicitation are simply not tracked in v1,
  not "reserved bit positions carried in the ID") and fixed the two cross-links + the Future Work
  bullet; updated the Statelessness paragraph that referenced `"Roots"` in the tracked list. Left the
  unrelated `$clientSupportsRoots` state-variable mentions intact (that's the existing local-server
  roots flag, not a tracked session-ID feature).
- **`Tests/CloudDeployment.wlt`**: updated `TrackedFeatureList-Value` → `{"MCPApps"}` and
  `TrackedFeatureIDs-Value` → `<|"MCPApps"->0|>`; **removed** the two real multi-feature tests
  (`MakeSessionID-MultipleFeatures`, `GetFeatures-MultipleFeatures` — they named the removed features);
  **added** two `SessionID-GenericMultiBit*` tests that `Block` a *hypothetical* `{"A","B","C","D"}`
  list to keep multi-bit round-trip + `"1:d:"` packing under test (so the codec's documented generality
  isn't silently uncovered when only one real feature remains). Net test count unchanged at 37.

**Verification:** `Tests/CloudDeployment.wlt` **37/37**; CodeInspector clean on `Cloud.wl`. (Codec
behavior for `{"MCPApps"}`/`{}` is byte-identical to Session 3 — `MCPApps` is bit 0, so dropping the
higher-bit features doesn't shift it; `$idVersion` stays `"1"` since the 4-feature layout never
shipped.)
