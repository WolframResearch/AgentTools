# Cloud Deployment of MCP Servers — TODO

Tasks for implementing the [Cloud Deployment specification](../Specs/CloudDeployment.md).
Each item is a logical unit of work for one coding session.

Nothing is implemented yet: `Kernel/Server/`, `Assets/Cloud/`, `Tests/CloudDeployment.wlt`,
`docs/cloud-deployment.md`, and the reference pages do not exist. The only pre-existing code is
`Kernel/StartMCPServer.wl`, which Task 1 splits apart. Tasks are ordered by dependency.

---

- [x] **1. `Kernel/Server/` refactor (transport-agnostic move, no behavior change)**

  Split `StartMCPServer.wl` (1145 lines, context `Wolfram`AgentTools`StartMCPServer`) into the new
  `Server/` subdirectory per the spec's *What moves to `Shared.wl`* / *What stays in `Local.wl`*
  tables, moving code essentially verbatim (context changes only). Create `Server.wl` as the
  aggregator (mirror the `Kernel/Tools/Tools.wl` header pattern: forward-declare server-shared
  symbols, then load children via a local `$subcontexts` list `Union`-ed into `$AgentToolsContexts`).
  This task deliberately introduces **no** behavior change — protocol negotiation is Task 2.

  Key wiring / gotchas surfaced during exploration:
  - `Main.wl`: replace `"Wolfram`AgentTools`StartMCPServer`"` (line 78) with the `Server` context in
    `$AgentToolsContexts`; the `StartMCPServer` entries in the exported list (line 32) and
    `$AgentToolsProtectedNames` (line 119) stay (it remains exported from `Local.wl`).
  - `CommonSymbols.wl`: declare `handleMethod` and `initializeServerState` (Task 3/next tasks need
    them paclet-wide). The **shared state variables** the moved handlers read — `$currentMCPServer`,
    `$mcpEvaluation`, `$clientName`, `$clientSupportsUI`, `$clientSupportsRoots`, `$toolList`,
    `$llmTools`, `$promptList`, `$promptLookup`, `$toolOptions` — are currently private/Block-scoped
    in `StartMCPServer.wl`; they must live in a context all three `Server` files can bind
    (`Server.wl` header, or `CommonSymbols.wl` for the ones read elsewhere in the paclet such as
    `$clientSupportsRoots`, `$toolOptions`, `$clientName`).
  - **Shared-declaration trap:** `$logFile` (read by `writeLog`) and `$warmupTask` (read by
    `evaluateTool`) are currently `StartMCPServer.wl` file-privates, but their readers move to
    `Shared.wl`. They must be declared in a shared context or local logging/warmup-cancel silently
    break. `$warmupTools` is genuinely local (stays in `Local.wl`). `$toolWarmupDelay` (line 16)
    appears to be dead code — verify before dropping.
  - New `initializeServerState[obj_MCPServerObject]` in `Shared.wl`: extract the state build from
    `startMCPServer` (lines 132–142, including `initializeUIResources[]`) into a transport-agnostic
    function returning the state bundle. `Local` calls it once and `Block`s the values around the read
    loop, exactly as today.
  - Loading is by context name (`Scan[Needs[#->None]&, $AgentToolsContexts]`), not by `Get` of file
    paths; the MX fast path (`Kernel/AgentToolsLoader.wl`) re-registers `$AgentToolsContexts`, so keep
    that list authoritative and rebuild the MX (see `docs/building.md`).
  - Reduce `Kernel/StartMCPServer.wl` to a thin shim or delete it.
  - Update `AGENTS.md` project-structure list (replace the `StartMCPServer.wl` bullet with the four
    `Server/` files; update the "server implementation (`Kernel/StartMCPServer.wl`)" reference).

  Verify no regression before relying on the tools (this paclet *is* the running MCP server):

  - [x] Paclet loads cleanly; `Get["Wolfram`AgentTools`"]` succeeds after `PacletDirectoryLoad`.
  - [x] Local stdio `StartMCPServer` still initializes and serves `tools/list` / `tools/call`
        (verified in-process; the subprocess integration tests fail identically to `main` — a
        pre-existing Windows/TestReport transport limitation, not a regression).
  - [x] `Tests/StartMCPServer.wlt` and the other server suites (`MCPServerObject.wlt`, `MCPApps.wlt`,
        `Prompts.wlt`) pass unchanged.
  - [x] `CodeInspector` clean on all new `Kernel/Server/*.wl` files.

  **Files:** `Kernel/Server/Server.wl`, `Kernel/Server/Shared.wl`, `Kernel/Server/Local.wl`,
  `Kernel/StartMCPServer.wl`, `Kernel/Main.wl`, `Kernel/CommonSymbols.wl`, `AGENTS.md`,
  `Tests/StartMCPServer.wlt`

---

- [x] **2. Protocol-version negotiation (shared)**

  The one deliberate behavior change extracted from the refactor. Replace the hardcoded
  `$protocolVersion = "2024-11-05"` / client-ignoring `initResponse` (was `StartMCPServer.wl:15`,
  `1018–1041`) with `$supportedProtocolVersions` + `$preferredProtocolVersion` and an `initResponse`
  that echoes the client's requested `protocolVersion` when supported, else returns the preferred
  `2025-11-25`. Declare the two new symbols in `CommonSymbols.wl`. Used by both transports, so this
  also bumps the local server's advertised version — verify the local stdio server still negotiates
  correctly for an old, new, and unknown requested version. (Re-confirm the exact preferred version
  against what OpenAI/Anthropic send during Task 11.)

  **Files:** `Kernel/Server/Shared.wl`, `Kernel/CommonSymbols.wl`, `Tests/StartMCPServer.wlt`,
  `Tests/CloudDeployment.wlt`

---

- [ ] **3. Self-describing session-ID capability codec**

  Create `Kernel/Server/Cloud.wl` (context `Wolfram`AgentTools`Server`Cloud`) and register it in
  `Server.wl`'s `$subcontexts`. Implement the file-scoped capability codec: `$trackedFeatureList`,
  `$idVersion`, `$trackedFeatureIDs`, `makeSessionIDFromFeatureList`, `getFeaturesFromSessionID` (exact
  code in the spec). Pure and fully unit-testable in isolation, so do it before the handler that
  consumes it.

  - [ ] Round-trip: `getFeaturesFromSessionID @ makeSessionIDFromFeatureList[f] === f` for each subset.
  - [ ] Empty set encodes `"1:0:…"`; `Intersection` guard drops untracked features.
  - [ ] Fail-closed decode: wrong version / malformed ID → `{}` (verifies the `$idVersion` bump story).
  - [ ] Trailing `CreateUUID[]` present (IDs unique/opaque).

  **Files:** `Kernel/Server/Cloud.wl`, `Kernel/Server/Server.wl`, `Tests/CloudDeployment.wlt`

---

- [ ] **4. `RunCloudMCPServer` — stateless Streamable HTTP handler**

  The cloud analog of `processRequest`: handle one `HTTPRequestData[]`, always return an `HTTPResponse`.
  Runs the shared dispatch inside `Block[{$currentMCPServer=obj, $mcpEvaluation=True,
  $clientSupportsUI=<decoded>, <initializeServerState[obj]>}, …]`. Because `tools/list` calls
  `withToolUIMetadata` unconditionally (the `$clientSupportsUI` gate lives inside `toolUIMetadata`,
  `UIResources.wl:289`), binding the decoded flag per request is sufficient — no handler change needed.
  Add the new `responseContentType` / `makeResponseString` helpers (adapted from the prototype; fix the
  prototype bugs — set `ContentType` to the *negotiated* type, not always `application/json`). Declare
  `RunCloudMCPServer` (exported: `Main.wl` list + `$AgentToolsProtectedNames`; `PacletInfo.wl`
  `"Symbols"`). Note its error wrapper does **not** use `catchMine`: it converts failures to responses
  (transport → status code; dispatch/tool failure → `-32603` inside a `200`; unexpected → `500`).

  Transport-level checks (status codes):

  - [ ] `POST` dispatch works; `GET`/`DELETE` → `405`.
  - [ ] Disallowed `Origin` → `403`; absent `Origin` allowed.
  - [ ] Unsupported `MCP-Protocol-Version` (non-`initialize`) → `400`; absent assumes `2025-03-26`.
  - [ ] Unacceptable `Accept` → `406` (prototype wrongly returned `405`).
  - [ ] Malformed / non-object body → `400`.
  - [ ] Request → `200` with negotiated content type; notification/`id->Null` → `202`, empty body.

  MCP-Apps capability round-trip (spec Verification #19–21):

  - [ ] `initialize` with the `io.modelcontextprotocol/ui` extension → response advertises it **and**
        returns an `Mcp-Session-Id` header decoding to `{"MCPApps"}`; without it, decodes to `{}`.
  - [ ] With the UI session ID, `tools/list` carries `_meta.ui`; with no-feature ID or no header, absent.
  - [ ] With the UI session ID, `resources/list` enumerates the registry and `resources/read` returns
        the app HTML; malformed/wrong-version ID → UI safely off.

  **Files:** `Kernel/Server/Cloud.wl`, `Kernel/Main.wl`, `PacletInfo.wl`, `Tests/CloudDeployment.wlt`

---

- [ ] **5. Server embedding + `CloudDeployMCPServer`**

  The most delicate part: make `/mcp` reconstruct the server (including anonymous custom tool
  functions) in a bare cloud kernel. Build the definition-bearing `Delayed[RunCloudMCPServer[obj]]`
  payload in a single deploy helper that combines both fixes — (a) `Block[{Language`$InternalContexts =
  DeleteCases[…, Wolfram`AgentTools`*]}, …]` dev-bundling bridge so AgentTools's own definitions are
  captured, and (b) the paclet's existing NOENTRY-aware `extendedFullDefinition` /
  `Language`ExtendedFullDefinition[]=defs; expr` injection (`Utilities.wl:16–103`, reused as-is) so
  custom tool functions inside `LLMTool`s are captured (do **not** rely on `CloudDeploy`'s own capture —
  it is NOENTRY-blocked). Implement exported `CloudDeployMCPServer` (`catchMine @ cloudDeployEndpoint`)
  + declarations (`Main.wl` list + protected names, `PacletInfo.wl` `"Symbols"`). Add the
  `CloudDeployFailed` message tag to `Messages.wl`. Built-in servers additionally require
  `Wolfram/Chatbook` in the cloud kernel (ensured by the shared bootstrapping already moved in Task 1).

  - [ ] Deploy a built-in server (e.g. `"WolframLanguage"`) with a `PermissionsKey`; returned object is
        the `/mcp` `CloudObject`; `initialize`/`tools/list`/`tools/call` work against it.
  - [ ] Deploy a **custom self-contained** server (anonymous pure-function tool) and confirm it works
        with no relevant paclet pre-installed (custom-function capture + dev bundling).
  - [ ] Both `Authorization: Bearer <key>` and `?_key=<key>` auth forms succeed; no/invalid key rejected
        by the cloud before the handler runs.

  (Requires cloud connectivity; gate or mark cloud-dependent tests accordingly.)

  **Files:** `Kernel/Server/Cloud.wl`, `Kernel/Main.wl`, `PacletInfo.wl`, `Kernel/Messages.wl`,
  `Tests/CloudDeployment.wlt`

---

- [ ] **6. Landing page + `/api/info`**

  Static dynamic shell + the public metadata API it consumes. Create `Assets/Cloud/index.html` and
  `Assets/Cloud/assets/*` (CSS/JS): fetch `/api/info` at view time; render name/version/tools/URL;
  implement **click-to-copy in JavaScript** (the notebook helper `clickToCopy`, `Formatting.wl:263`,
  emits FE boxes, not HTML — reuse only the JSON *shape* from `makeJSONConfiguration`,
  `MCPServerObject.wl:646`, adapted to the remote `url`+`headers` form) for: raw URL, generic remote-MCP
  snippet, OpenAI (`server_url`+bearer) and Anthropic (`url?_key=`) examples, all with a `<YOUR_KEY>`
  placeholder. Implement `/api/info` (JSON: name, version, tool names/titles/descriptions from the
  shared tool-list construction, endpoint URL — no keys/permissions/usage). Add
  `{ "Cloud", "Assets/Cloud" }` to `PacletInfo.wl`'s `"Asset"` extension (read via
  `PacletObject[…]["AssetLocation","Cloud"]`).

  **Files:** `Assets/Cloud/index.html`, `Assets/Cloud/assets/` (CSS/JS), `Kernel/Server/Cloud.wl`,
  `PacletInfo.wl`, `Tests/CloudDeployment.wlt`

---

- [ ] **7. Admin page + `/api/admin`**

  Owner-only (`"Private"`) key management. Create `Assets/Cloud/admin.html` (static shell calling
  `/api/admin` over the owner session). Implement `/api/admin` actions against the sibling `/mcp`
  object's permissions: `listKeys` (`Information[mcp,"Permissions"]` + labels), `createKey`
  (`CreateUUID` → `SetPermissions[mcp, PermissionsKey[key]->"Execute"]`, returned once), `revokeKey`
  (`DeleteObject[PermissionsKey[key]]`). Optional human-readable label store in a `"Private"`
  `/admin/keys.wxf` (authoritative list is always the live permissions) — add a cloud-path helper to
  `Files.wl` if needed. No embedded secret; the API executes server-side as the owner.

  - [ ] `createKey` → key appears in `Information[mcp,"Permissions"]` and is usable against `/mcp`.
  - [ ] `listKeys` reflects current keys (+ labels); `revokeKey` removes it and it stops working.

  **Files:** `Assets/Cloud/admin.html`, `Kernel/Server/Cloud.wl`, `Kernel/Files.wl`,
  `Tests/CloudDeployment.wlt`

---

- [ ] **8. `CloudDeploy` UpValue + full directory bundle**

  The headline integration: `MCPServerObject /: CloudDeploy[obj, args___] := catchTop[
  cloudDeployDirectory[…], MCPServerObject]` (mirror the existing UpValues at
  `MCPServerObject.wl:732`; the UpValue itself lives in `Cloud.wl`, no data-model change). Resolve the
  directory `CloudObject` (explicit target, or **anonymous** `CloudObject[Permissions->perms]`) and
  join sub-object paths onto it (declare distinct-named deployment-path helpers in `CommonSymbols.wl` —
  avoid colliding with the existing `$deploymentsPath` / `deployCloudNotebookForMCPApp`). Deploy `/mcp`
  (via Task 5's endpoint primitive), `/index.html`, `/assets/*`, `/api/info` at resolved `perms`;
  `/admin/index.html` and `/api/admin` forced `"Private"`. Add the **new** `$CloudConnected` guard →
  `throwFailure["NotCloudConnected"]` (no existing abort-on-disconnect precedent — `$CloudConnected` is
  used nowhere in `Kernel/` today; this is deliberate new behavior). Forward options via the
  `FilterRules`-by-`Options` pattern (`DeployAgentTools.wl:254–259,373`). Add `NotCloudConnected` and
  `InvalidCloudTarget` message tags. Return the directory `CloudObject` (no local registry).

  - [ ] `CloudDeploy[server]` (anonymous) and `CloudDeploy[server,"Name"]` return the directory object;
        `/mcp`, `/index.html`, `/api/info`, `/admin/index.html`, `/api/admin` all exist.
  - [ ] `/index.html`, `/api/info`, `/mcp` carry resolved `Permissions`; `/admin/*`, `/api/admin` are
        `"Private"` and unreachable without owner credentials.
  - [ ] Disconnected session → `NotCloudConnected` failure.

  **Files:** `Kernel/Server/Cloud.wl`, `Kernel/CommonSymbols.wl`, `Kernel/Messages.wl`,
  `Tests/CloudDeployment.wlt`

---

- [ ] **9. User documentation**

  Write `docs/cloud-deployment.md` covering `CloudDeploy[MCPServerObject[…]]`, `CloudDeployMCPServer`,
  the directory layout & permissions, authentication (bearer vs `?_key=`), the stateless evaluation
  model and its cold-start/latency consequences, MCP-Apps support, and admin key management. Add its
  entry to the `AGENTS.md` `docs/` list and cross-link from related docs (`servers.md`, `mcp-apps.md`).

  **Files:** `docs/cloud-deployment.md`, `AGENTS.md`

---

- [ ] **10. Reference pages**

  Author English symbol reference pages for `CloudDeployMCPServer` and `RunCloudMCPServer`
  (`Documentation/English/ReferencePages/Symbols/`), following the existing pages
  (e.g. `CreateMCPServer.nb`) and the `SymbolPage` template. Use the `WriteNotebook` / `ReadNotebook`
  tools. (Japanese pages exist for other symbols by convention but are not required by the spec.)

  **Files:** `Documentation/English/ReferencePages/Symbols/CloudDeployMCPServer.nb`,
  `Documentation/English/ReferencePages/Symbols/RunCloudMCPServer.nb`

---

- [ ] **11. End-to-end verification & cross-cutting checks**

  Spanning verification not owned by a single task above. Requires cloud connectivity and OpenAI /
  Anthropic API keys.

  - [ ] Reproduce the OpenAI and Anthropic remote-MCP end-to-end examples
        (`Notes/cloud-deployed-mcp-servers.md:258–332`) against a deployed endpoint; confirm the
        `$preferredProtocolVersion` chosen in Task 2 matches what they send.
  - [ ] Load `/index.html` in a browser and confirm it fetches `/api/info` and renders name, tools,
        URL, and click-to-copy snippets with the `<YOUR_KEY>` placeholder.
  - [ ] Run the full `Tests/CloudDeployment.wlt` plus the existing server suites; confirm green.
  - [ ] Run `CodeInspector` across all new/changed `Kernel/Server/*.wl` files.

  **Files:** `Tests/CloudDeployment.wlt`
