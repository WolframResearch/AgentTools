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

## Session 5

**Completed Task 4: `RunCloudMCPServer` — stateless Streamable HTTP handler.** The cloud analog of the
local `processRequest`: handles one `HTTPRequestData[]`, always returns an `HTTPResponse`. All of
`Kernel/Server/Cloud.wl`; exported symbol `RunCloudMCPServer` wired into `Main.wl` + `PacletInfo.wl`.

**Handler structure (`Cloud.wl`):**
- `RunCloudMCPServer[obj_MCPServerObject] := runCloudMCPServer[obj, HTTPRequestData[]]` (exported, no
  `catchMine` — the internal handler converts every failure to a response). Tests call the internal
  `runCloudMCPServer[obj, mockRequest]` directly, so `HTTPRequestData[]` is only invoked in the real
  cloud (exercised end-to-end in Task 11).
- `runCloudMCPServer[obj, req]` is the error boundary: `catchAlways @ Catch[runCloudMCPServer0[…],
  $cloudResponseTag]`; if the result isn't an `_HTTPResponse` → `emptyResponse[500]`. The two-layer
  catch is deliberate — transport short-circuits `Throw` an `HTTPResponse` to the file-local
  `$cloudResponseTag` (caught by the inner `Catch`), while an internal-failure `Throw` from
  `initializeServerState` uses `$catchTopTag` (NOT caught by the inner `Catch`) → bubbles to
  `catchAlways` → `Failure` → 500. So: transport → status code; **dispatch/tool failure → −32603 in a
  200** (inner `catchAlways` in `dispatchCloudMethod`); **pre-dispatch/unexpected → 500** (outer).
- `runCloudMCPServer0` does the 6 transport checks in order (method→origin→accept→body→protocol→
  session-ID), then `Block[{$currentMCPServer, $mcpEvaluation=True, $clientSupportsUI=<decoded>,
  $clientSupportsRoots=False}, state=initializeServerState[obj]; Block[{$toolList,$llmTools,$promptList,
  $promptLookup,$toolOptions}, dispatchCloudMethod[…]]]` — mirrors `startMCPServer` exactly, plus the
  two capability binds. **No shared handler change needed** — `tools/list` reads the Block-bound
  `$clientSupportsUI` and lights up `_meta.ui` per request.
- `dispatchCloudMethod`: `replyOwedQ[method,id]` (= method + non-null id + not `notifications/`) →
  200 with result (or −32603 if the handler `Failure`s), else dispatch-for-side-effects + `202` empty.
  `initialize` responses attach a fresh `Mcp-Session-Id` via `sessionIDResponseHeaders` /
  `currentTrackedFeatures` (reads the post-`handleMethod` `$clientSupportsUI`).

**Key design decisions / gotchas (important for Tasks 5–8, 11):**
- **`responseContentType` is lenient**: absent `Accept` → `application/json` (HTTP `*/*` semantics);
  handles `;q=` params and `*/*`/`application/*` wildcards; present-but-unmatchable → `None` → 406. The
  prototype's `None`-on-absent (→ its buggy 405) is replaced — absent must not 406 server-to-server.
- **`CharacterEncoding -> "UTF-8"` on the 200 `HTTPResponse` is REQUIRED, not cosmetic.** Without it, a
  `ByteArray` body + `"text/event-stream"` ContentType makes WL advertise `charset=iso-8859-1` while the
  bytes are UTF-8 (verified: non-ASCII body then fails to round-trip). With it: `application/json` stays
  **bare** (matches prototype; JSON is UTF-8 by spec) and SSE correctly says `charset=utf-8`.
- **Origin policy** (`$allowedOriginSuffixes = {"wolframcloud.com","wolfram.com"}`): absent → allowed;
  present → allowed only for exact host or true `.`-subdomain (so `evilwolframcloud.com` is a 403, tested);
  unparseable present Origin → 403. It's belt-and-suspenders for a key-authed cloud endpoint but the spec
  requires it; relax here if a browser-based client needs `/mcp` later.
- **`$clientSupportsRoots = False` in the Block is load-bearing, not cosmetic**: `notifications/
  initialized` → `handleNotification` → `onClientInitialized`, which only fires the `roots/list`
  server→client callback `If[TrueQ@$clientSupportsRoots]`. Binding it False makes that a clean no-op
  (there's no server→client channel in the stateless transport), so the notification just returns 202.
- **`$clientName` can't be Block-bound from `Cloud.wl`** — it's a `Server`Shared`Private` file-private
  (per Session 1), so a bare `$clientName` in `Cloud.wl` would be a *different* symbol. Not needed: its
  Shared default is `None` → `stderrEnabledQ[]` False → `writeLog`/`writeError`/`debugPrint` are no-ops
  in the cloud; `handleMethod["initialize"]` sets it, but nothing logs during init and the kernel is
  stateless per request.
- **Test fixtures use an in-memory `MCPServerObject[<|"Location"->"BuiltIn","LLMEvaluator"-><|"Tools"->
  {…}|>|>]`** — `mcpServerExistsQ[_,"BuiltIn"]` is `True`, so NO disk persistence / no `CreateMCPServer`
  / no cleanup. A tool literally named `"MCPAppsTest"` matches `$toolUIAssociations` →
  `ui://wolfram/mcp-apps-test`, which is how the `_meta.ui` and `resources/read` round-trips are tested.
  (A bad server with a string tool `{"NotARealPacletTool"}` does NOT construct — validation rejects it —
  so it can't drive the 500 path in-process; I test the −32603-in-200 path deterministically instead via
  a `tools/call` with no `"name"`, which makes `evaluateTool` throw.)

**Tests — `Tests/CloudDeployment.wlt` now 76 (was 37): +39 `RunCloudMCPServer` tests**, all in-process,
100% pass. Sections: Fixtures/Export, Transport (method/origin/accept/protocol/body), Dispatch
(initialize-negotiate, tools/list, tools/call→"11", ping, unknown-method→−32601, notification→202,
null-id→202), MCP-Apps round-trip (init±UI session-ID decode, tools/list _meta with UI/no-feature/
no-header/malformed session IDs, resources/list±UI, resources/read HTML), and the −32603 error path.

**Verification:** `CloudDeployment.wlt` **76/76**; regression `MCPApps.wlt` **83/83**,
`MCPServerObject.wlt` **71/71** (paclet loads cleanly with the new handler + export). CodeInspector
clean (incl. Scoping) on `Kernel/Server/Cloud.wl` and `Tests/CloudDeployment.wlt`.

**For Task 5 (`CloudDeployMCPServer` + embedding):** `RunCloudMCPServer` is the endpoint primitive to
serialize as `Delayed[RunCloudMCPServer[obj]]`. It resolves all state from `obj` via
`initializeServerState` per request (nothing hardcoded), so the deploy payload just needs `obj`'s
definitions captured (the `Language`$InternalContexts` bridge + NOENTRY-aware `extendedFullDefinition`).
The `HTTPRequestData[]`/real-cloud body path (simulation returns `None` for the body under
`GenerateHTTPResponse`) is first exercised for real when Task 5 deploys an endpoint.

## Session 6

**Completed Task 5: Server embedding + `CloudDeployMCPServer`.** The delicate part — making `/mcp`
reconstruct the server (incl. anonymous custom tool functions) in a bare cloud kernel — plus the
exported endpoint-only deploy function. All new code lives in `Kernel/Server/Cloud.wl`.

**Proven end-to-end against the REAL cloud before writing a line of committed code.** This kernel
(`$CloudConnected` is True; the WolframLanguageEvaluator session has the paclet loaded) let me
prototype the embedding inline with the loaded internals and deploy to `/Claude/...`. That de-risked
the one-way-door question — *does `CloudDeploy` preserve the literal `DefinitionList` or re-strip
internal-context defs from it?* Answer: **it preserves it** (no re-strip), so the primary
inline-injection approach works; the spec's WXF-to-Private-object fallback is not needed.

**Source (`Cloud.wl`), all file-private except the exported symbol:**
- `CloudDeployMCPServer[obj_, args___] := catchMine @ cloudDeployEndpoint[obj, args]` (exported;
  declared in `Main.wl` list + `$AgentToolsProtectedNames`, and `PacletInfo.wl` `"Symbols"`).
- `cloudDeployEndpoint` — 2 forms: `[obj_, opts:OptionsPattern[]] -> [obj, Automatic, opts]` and
  `[obj_, target:$$cloudDeployTarget, opts:OptionsPattern[]]`. Resolves the server
  (`ensureMCPServerExists @ MCPServerObject @ obj`, idempotent on an MCPServerObject), builds the
  payload, deploys, validates. `Options = {Permissions :> $Permissions}` (ambient default is
  `"Private"`).
- `cloudMCPServerPayload[server_MCPServerObject]` — **the delicate builder.** Runs
  `extendedFullDefinition[Delayed @ RunCloudMCPServer @ server]` inside
  `Block[{Language`$InternalContexts = deAgentToolsInternalContexts[]}, …]`, then
  `injectServerDefinitions`. Returns a held `Delayed[Language`ExtendedFullDefinition[]=defs;
  RunCloudMCPServer[server]]`.
- `deAgentToolsInternalContexts[]` — `DeleteCases[Language`$InternalContexts,
  _String?(StringStartsQ["Wolfram`AgentTools`"])]` (the dev bridge — removes only AgentTools;
  Chatbook/DiffTools stay internal). The `_String?` guard matters: a bare `_?` trips
  `StringStartsQ::strse` on non-string subexpressions when used under `FreeQ` (though `DeleteCases`
  at level 1 wouldn't).
- `injectServerDefinitions`, `deployMCPEndpoint` (anonymous vs String/CloudObject target),
  `filteredCloudDeployOptions` (drops Permissions to avoid a dup), `cloudDeployResult` (CloudObject →
  itself; else `throwFailure["CloudDeployFailed", …]`). New `CloudDeployFailed` tag in `Messages.wl`.

**CRITICAL hold/pattern insight (get this wrong and nothing is captured):** `extendedFullDefinition`
is `HoldFirst`, but **pattern-variable substitution beats HoldFirst** — so with
`cloudMCPServerPayload[server_MCPServerObject]`, the `server` VALUE (the MCPServerObject, with its
NOENTRY-flagged `LLMTool`s) is substituted *lexically* into the held argument before the hold takes
effect. That lexical presence is exactly what lets `unpackNoEntry` reach the tools and capture
functions hidden behind `NOENTRY`. A prototype using a *global variable* instead of a pattern var
must force the value in with `With[{srv = theVar}, …]` — else `server` stays a symbol, the LLMTool
sits behind its OwnValue, and the custom function is NOT captured. The real code needs no `With`
because the pattern var already does it. `RunCloudMCPServer` is never evaluated at build time (stays
held inside `Delayed`, `HoldFirst`).

**GOTCHA that the cloud-connected test caught (not CodeInspector):** `$$cloudDeployTarget` must be
assigned **before** `cloudDeployEndpoint`'s definitions load — a `target:$$cloudDeployTarget` pattern
set while `$$cloudDeployTarget` is still an undefined symbol stores an unmatchable pattern → every
real call falls through to `endDefinition`'s `UnhandledDownValues`. I'd first placed it in a
subsubsection *after* `endDefinition`; moved it above `beginDefinition`. Lesson: pattern-alias `$$`
vars are evaluated at definition time — define them upstream.

**Verification (all green):**
- `Tests/CloudDeployment.wlt`: **88/88** (was 76; +12 Task-5 tests: export/message wiring,
  `deAgentToolsInternalContexts`, `cloudMCPServerPayload` structure incl. NOENTRY-helper +
  dev-bridge-handler capture + EFD-injection + not-evaluated, `injectServerDefinitions`, and a
  cloud-gated end-to-end).
- **The cloud-gated `CloudDeploy-Endpoint-EndToEnd` test RAN FOR REAL** — the fresh TestReport kernel
  turned out to be `$CloudConnected`, so it deployed a custom self-contained server via the actual
  `CloudDeployMCPServer` path and got `1011` back (`Prime[5]+1000`), then cleaned up. (~40s of the 46s
  file time.) It's gated `If[!TrueQ@$CloudConnected, "no-cloud", …]` with the expected value
  `"no-cloud" | {…"1011"…}`, so it's a fast no-op pass in a disconnected CI kernel.
- **Built-in server verified live** (evaluator, `MCPServerObject["WolframLanguage"]`): deploy →
  initialize/tools/list (all 7 real tools) / `tools/call` `WolframLanguageEvaluator["2 + 2"]` →
  `Out[1]= 4`. Confirms the built-in + Chatbook cold-start path in the cloud.
- **Auth (live):** `Authorization: Bearer <key>` (OpenAI) and `?_key=<key>` (Anthropic) both → `1011`;
  no key / wrong key → `401` (cloud rejects before the handler runs).
- Regression: `MCPApps.wlt` 83/83, `MCPServerObject.wlt` 71/71. CodeInspector clean on `Cloud.wl`
  (incl. Scoping).
- All test cloud objects + keys deleted; `CloudObjects["Claude"]` shows no `mcp-*`/`agenttools-*`
  strays.

**Env notes for later sessions:**
- **The WolframLanguageEvaluator kernel (and, surprisingly, the fresh TestReport kernel) are
  `$CloudConnected` here** — Session 2's "no subprocess tests" caveat still holds, but cloud deploys
  DO work from both. A real `CloudDeploy` of the endpoint is ~12 MB and cold-start takes tens of
  seconds; keep cloud-gated tests to one round-trip.
- To end-to-end test cloud code *without* reloading the paclet in the live server, prototype inline in
  the evaluator using the already-loaded `Wolfram`AgentTools`…` symbols (never `Get` the paclet
  there). Deploy under `/Claude/` (per user's global CLAUDE.md) and always `DeleteObject` the object
  after; deleting the object also removes its `PermissionsKey` (so `DeleteObject[PermissionsKey[…]]`
  then returns `$Failed`/`keynf` — harmless).
- `extendedFullDefinition` and other `Wolfram`AgentTools`Common`` internals show `0` from
  `DownValues[…]` in the evaluator because they're `ReadProtected` — use `SymbolDefinition` to inspect.
- **For Task 8** (`CloudDeploy` UpValue + directory bundle): reuse `cloudDeployEndpoint`/
  `cloudMCPServerPayload` for `/mcp`; add the `$CloudConnected` guard + `NotCloudConnected`/
  `InvalidCloudTarget` tags there (deliberately NOT in Task 5). `deployMCPEndpoint` already handles
  String/CloudObject/Automatic targets and forwards options.

## Session 7

**Completed Task 6: Landing page + `/api/info`.** The public metadata endpoint and the static
HTML/JS landing page that consumes it. All WL logic is in place and unit-tested; the *deployment*
wiring (pushing `/index.html`, `/assets/*`, `/api/info` into the directory) belongs to Task 8.

**Key design decision — `/api/info` is STATIC JSON, generated at deploy time, not a per-request API.**
The info content (name, version, tools, `/mcp` URL) is fixed for a given server object, so there is no
reason to embed the server + pay a cold start on every page view. Task 8 will deploy the precomputed
JSON (e.g. `CloudDeploy[ExportForm[cloudMCPServerInfo[obj, mcpURL], "RawJSON"], <dir>/api/info, ...]`).
This is why Task 6 provides a *generator function* rather than a deployed handler. (Confirmed via the
WolframLanguageContext tool: `CloudDeploy[ExportForm[assoc,"RawJSON"], path]` serves `application/json`;
same-origin `fetch` from the landing page needs no CORS.)

**Source changes:**
- **`Kernel/Server/Shared.wl`** — new **side-effect-free** shared helper `serverToolListData[obj]` =
  `KeyValueMap[createMCPToolData, disambiguateToolNames[obj["Tools"]]]` (placed right after
  `createMCPToolData`). This is the *same* tool-list construction `tools/list` uses via
  `initializeServerState`, but WITHOUT the paclet-install / `runServerInitialization` /
  `runToolInitialization` / `initializeUIResources` side effects — critical so that merely *describing*
  a server for `/api/info` never triggers e.g. a vector-DB install. Handles `{}`/non-tool inputs → `{}`.
- **`Kernel/Server/Server.wl`** — forward-declared `` `serverToolListData `` in the package header (it is
  defined in `Shared.wl` and read by `Cloud.wl`, both under the `Server`` context; only used within the
  Server files, so the header — not `CommonSymbols.wl` — is the right home, matching `stealthCatchTop`).
  I did **not** move `disambiguateToolNames`/`createMCPToolData` out of `Server`Shared`Private` —
  `Tests/StartMCPServer.wlt` references ~15 of them by that private path, so moving them would break it.
  The new helper wraps them in `Shared.wl` where they are in scope and exposes only itself.
- **`Kernel/Server/Cloud.wl`** — new "Landing Page & Server Info API" section:
  `cloudMCPServerInfo[obj_MCPServerObject, url_String]` (Enclose, `ConfirmBy` name/version are strings) →
  `<|"name","version","url","tools"|>`; `cloudInfoTool` projects each `$toolList` entry down to
  `name`/`title`(opt)/`description`(default `""`), dropping `inputSchema`/`annotations`. Both file-private
  (Task 8's deploy code is in the same file). No keys/permissions/usage are ever included.
- **`PacletInfo.wl`** — added `{ "Cloud", "Assets/Cloud" }` to the `"Asset"` extension. Verified a fresh
  TestReport kernel (source paclet, `PacletDataRebuild`) resolves
  `PacletObject["Wolfram/AgentTools"]["AssetLocation","Cloud"]` to the real dir.

**Assets (`Assets/Cloud/`):**
- `index.html` — static shell: header (name + version badge), Endpoint, Connect-a-client (3 snippet
  blocks), Authentication instructions, Tools list, footer/admin link. Loading + error states. References
  `assets/landing.{css,js}` and fetches `api/info` with **relative** paths so it works at any cloud path.
- `assets/landing.css` — self-contained (no external fonts/CDNs — the Wolfram Cloud CSP would block
  them), light/dark via `prefers-color-scheme`, responsive, Wolfram-red accent.
- `assets/landing.js` — fetches `/api/info` (`new URL("api/info", location.href)`), renders name/version/
  tools/URL, builds the click-to-copy snippets, and does clipboard copy in JS (async Clipboard API +
  `execCommand` fallback). Snippet shapes match the notes' proven examples exactly: generic
  `{"type":"http","url","headers":{Authorization:"Bearer <YOUR_KEY>"}}`, OpenAI
  `{type:mcp,server_label,server_url,require_approval:never,headers}`, Anthropic
  `{type:url,url:"…?_key=<YOUR_KEY>",name}`. `<YOUR_KEY>` placeholder everywhere (keys minted on admin
  page). `safeLabel` sanitizes the server name to `[A-Za-z0-9_-]` for provider labels.

**Tests — `Tests/CloudDeployment.wlt` now 104 (was 88): +16 Task-6 tests**, all in-process, 100% pass:
`serverToolListData` (empty, names, full-shape-with-inputSchema); `cloudInfoTool` (projection, no-title,
description-default); `cloudMCPServerInfo` (exact key set = no leak, name/version/url passthrough, tool
projection, plain-tool-no-title, no-inputSchema, JSON-serializable); Cloud assets (AssetLocation
resolves, files exist, index.html links + containers, landing.js content contract: `api/info`/
`<YOUR_KEY>`/`Bearer`/`server_url`/`?_key=`).

**Verification:** `CloudDeployment.wlt` **104/104**; regression `MCPApps.wlt` **83/83**,
`MCPServerObject.wlt` **71/71**; CodeInspector **clean** on `Cloud.wl`, `Shared.wl`, `Server.wl`.
HTML well-formed (all JS-referenced IDs present); snippet JSON shapes cross-checked against the notes.
No JS runtime in the sandbox, so a live browser render of the page (spec Verification #13) stays with
Task 11; the JS logic + JSON shapes are validated statically here.

**For Task 8:** call `cloudMCPServerInfo[obj, mcpURL]` after `/mcp` is deployed (so the URL is known),
serialize with `ExportForm[…, "RawJSON"]`, and `CloudDeploy` it to `<dir>/api/info` at `perms`; push the
`Assets/Cloud/` files (`index.html`→`<dir>/index.html`, `assets/*`→`<dir>/assets/*`) with `CopyFile`
(read the dir via `PacletObject["Wolfram/AgentTools"]["AssetLocation","Cloud"]`, mirroring
`initializeUIResources`). Watch the trailing-slash access question (see the Task 6 TODO note) during the
Task 11 browser check.
