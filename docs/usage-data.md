# Usage Data

This document describes the usage data collected by the local MCP servers, how users control it, and how it is stored and submitted.

## Overview

To learn which AI environments (MCP clients) people use with the Wolfram tools and which tools and prompts get used, the built-in local MCP servers (`Wolfram`, `WolframAlpha`, `WolframLanguage`, and `WolframPacletDevelopment`) record basic usage data for each server session and submit it to Wolfram. The data never contains content: no tool arguments, prompt arguments, results, code, or queries. It is not anonymous, though: every session carries the [product identity information](#product-identity-information) — license, activation key, machine ID, product, release, and so on — that the paclet manager sends with every request to the Wolfram paclet server, so sessions can be related to the Wolfram installation they came from (and to the cloud user, when the server kernel is connected to the Wolfram Cloud). Each session also says whether the server runs under the [standalone MCP server](#standalone-mcp-server) product and, if so, what that product reports about itself.

Cloud-deployed servers (see [cloud-deployment.md](cloud-deployment.md)) do not collect usage data.

## What Is Recorded

For each local server session (one server process, from start to exit):

| Field | Description |
|-------|-------------|
| `MCPSessionID` | A random UUID assigned when the server starts (`$mcpSessionID`) |
| `ServerName` | The name of the MCP server, e.g. `"WolframLanguage"` |
| `ClientInformation` | The `params` of the client's `initialize` request: `clientInfo` (name and version of the MCP client), `protocolVersion`, and `capabilities`. `null` until `initialize` has been received |
| `Events` | One event per `tools/call` and `prompts/get` request (see below) |
| `StandaloneMCPServer` | `true` when the server runs under the [standalone MCP server](#standalone-mcp-server) product, `false` for a regular kernel (`$StandaloneMCPServer`) |
| `StandaloneMCPServerInformation` | The information the standalone MCP server product publishes about itself (version, build, and so on); an empty object for a regular kernel (`$StandaloneMCPServerInformation`) |
| `PacletVersion` | The version of Wolfram/AgentTools |
| `LastUpdated` | `AbsoluteTime[TimeZone -> 0]` of the last change |
| `ActivationKey`, `CloudUserUUID`, `Language`, `LicenseID`, `LicenseProcesses`, `LicenseSubprocesses`, `MachineID`, `MaxLicenseProcesses`, `MaxLicenseSubprocesses`, `ProductIDName`, `ReleaseID`, `SystemID` | The [product identity information](#product-identity-information) described below, at the top level of the same association |

Each event has:

| Field | Description |
|-------|-------------|
| `Type` | `"ToolCall"` or `"PromptGet"` |
| `Name` | The name of the tool or prompt, or `null` if the request named a tool or prompt the server does not have (so arbitrary text can never end up in the data) |
| `Success` | Whether the request succeeded: `false` for tool errors (`isError`), JSON-RPC errors, and internal failures |
| `Timestamp` | `AbsoluteTime[TimeZone -> 0]` of the request |

Everything else in a request — in particular the `arguments` — is never looked at.

### Product Identity Information

Every session file, and therefore every submission, also carries the product identity information that the paclet manager sends as HTTP headers with each request to the paclet server (`` PacletManager`Package`$productIdentityHeaders ``, used by `` PacletManager`Package`downloadPaclet `` and the other paclet server requests). Wolfram already receives this information from every installation that looks up or installs paclets. It identifies the installation — and the cloud user, when the server kernel is connected to the Wolfram Cloud — which is why the usage data is not described as anonymous. `$productIdentityInfo` in `Kernel/Server/UsageData.wl` assembles it:

| Field | Value | Paclet manager equivalent |
|-------|-------|---------------------------|
| `ActivationKey` | `$ActivationKey` | `Mathematica-activationKey` |
| `CloudUserUUID` | `$CloudUserUUID`: the UUID of the cloud user while the server kernel is connected to the Wolfram Cloud, otherwise `"None"` | `Mathematica-wolframID` (which carries `$WolframID` rather than the UUID) |
| `Language` | `$Language` | `Mathematica-language` |
| `LicenseID` | `$LicenseID` | `Mathematica-license` |
| `LicenseProcesses`, `LicenseSubprocesses`, `MaxLicenseProcesses`, `MaxLicenseSubprocesses` | `$LicenseProcesses`, `$LicenseSubprocesses`, `$MaxLicenseProcesses`, `$MaxLicenseSubprocesses` | `Mathematica-kernelStats` |
| `MachineID` | `$MachineID` | `Mathematica-mathID` |
| `ProductIDName` | `SystemInformation["Kernel", "ProductIDName"]`, e.g. `"Wolfram"` | `Mathematica-productID` |
| `ReleaseID` | `SystemInformation["Kernel", "ReleaseID"]`, e.g. `"15.0.1.0 (13811065, 202607025984)"` | The version in the `User-Agent` header |
| `SystemID` | `$SystemID` | `Mathematica-systemID` |

The session file holds the kernel's values as they are. When the payload is written as JSON, integers, reals, strings, booleans, and `Null` are written natively, a `DateObject` becomes an ISO 8601 string in UTC (`"2026-08-01T12:00:00.000Z"`), and any other value becomes its `InputForm` string, so an unlimited process count is `"Infinity"` and a missing cloud connection gives `"None"` (`WriteRawJSONString` cannot encode `Infinity` or `None` themselves; the conversion is the `jsonConvert` function that `writeRawJSONString` and `writeRawJSONFile` in `Kernel/Files.wl` pass as its `"ConversionFunction"`). The values are read again each time the session file is written, so a session whose server kernel connects to the cloud later on picks up the `CloudUserUUID`.

### Standalone MCP Server

The standalone MCP server is a Wolfram kernel that only runs the MCP server, without a full Mathematica installation and under its own licensing. Two exported symbols, defined in `Kernel/Server/Server.wl`, describe it:

| Symbol | Regular kernel | Standalone MCP server |
|--------|----------------|-----------------------|
| `$StandaloneMCPServer` | `False` | `True` |
| `$StandaloneMCPServerInformation` | `<| |>` | An association with string keys describing the product: version, build, and so on |

Nothing in the paclet sets them. The standalone application sets both after loading the paclet (loading resets them to the defaults); since they are Protected like every other exported symbol, that takes `Unprotect` or a `Block` around `StartMCPServer`. Every session file carries both values, so sessions of the standalone product can be told apart from those of a regular installation, and the product identity information above is recorded for them as well. The information association goes into the payload as it is, with values that JSON cannot represent written as strings like the product identity values, so it must only describe the product, never anything about a session. That includes the keys of the product's time-limited [license](tools.md#environment-specific-overrides) (`"ExpirationDate"`, `"Expired"`, `"InstructionsURL"`, `"ProductName"`, `"WarningDays"`), with the expiration date sent as an ISO 8601 string in UTC.

## When It Is Recorded

Whether a session is tracked is decided once, when the server starts (`initializeUsageData` in `Kernel/Server/UsageData.wl`):

1. If the `SUBMIT_USAGE_DATA` environment variable holds a boolean (`true`/`false`, case-insensitive; `yes`/`no`, `on`/`off`, and `1`/`0` are accepted too), that value wins.
2. Otherwise the session is tracked only if the server's `"EnableUsageData"` property is exactly `True` and usage data has not been turned off globally (see [Opting Out](#opting-out-or-in) below). The built-in servers set the property (see `Kernel/DefaultServers.wl`); servers created with `CreateMCPServer` or defined by paclets do not have it, so they are not tracked unless the environment variable says otherwise.

```wl
MCPServerObject["WolframLanguage"]["EnableUsageData"]  (* True *)
```

### Opting Out (or In)

`InstallMCPServer` — and therefore `DeployAgentTools`, which forwards all `InstallMCPServer` options — has a `"SubmitUsageData"` option:

| Value | Behavior |
|-------|----------|
| `Automatic` (default) | Nothing is added to the client configuration; the server's `"EnableUsageData"` property decides |
| `False` | Sets `SUBMIT_USAGE_DATA=false` in the server's environment: no usage data is recorded or submitted by that installation |
| `True` | Sets `SUBMIT_USAGE_DATA=true`: usage data is recorded even for a custom server |

```wl
InstallMCPServer["ClaudeCode", "WolframLanguage", "SubmitUsageData" -> False]
```

Any other value is rejected with `InstallMCPServer::InvalidSubmitUsageData`.

The system preferences panel built by `CreatePreferencesContent` (see [preferences-content.md](preferences-content.md)) has a checkbox, *Share usage data with Wolfram to help improve these tools*, which is checked by default. Its state is a single global setting on this machine rather than anything in the clients' configurations: unchecking it stores `"SubmitUsageData" -> False` in the global settings file (see below), and checking it again stores `True`. Every built-in server session reads the setting when it starts, so the change applies to all existing installations at once without re-deploying anything. Only an explicit `False` opts out, and an explicit `SUBMIT_USAGE_DATA` in a client configuration (from the `"SubmitUsageData"` option) still takes precedence over the global setting, in both directions.

#### The Global Settings File

Settings that apply to everything on the machine live in `$rootPath/GlobalSettings.wxf`, i.e. `$UserBaseDirectory/ApplicationData/Wolfram/AgentTools/GlobalSettings.wxf`: a WXF-encoded association that currently holds only `"SubmitUsageData"` but is meant to take other global settings in the future. `readGlobalSettings`, `getGlobalSetting`, and `setGlobalSetting` in `Kernel/Files.wl` read and write it (a missing or unreadable file counts as no settings; writing merges the new value into the existing ones), and `getGlobalUsageDataSetting`/`setGlobalUsageDataSetting` in `Kernel/Server/UsageData.wl` wrap its `"SubmitUsageData"` entry for the checkbox and for `usageDataEnabledQ`.

Servers started by the test suite never track anything: `GetMCPEnvironment` in `Tests/MCPServerTestUtilities.wl` sets `SUBMIT_USAGE_DATA=false` for every test server.

## How It Is Stored

The session's data is written to `$rootPath/UsageData/<MCPSessionID>.wxf`, i.e. under `$UserBaseDirectory/ApplicationData/Wolfram/AgentTools/UsageData/`. The file is rewritten in full whenever the client information arrives or an event is added, so it always holds the complete session. At most 10,000 events are recorded per session.

A server session cannot know that it is over, and an MCP client may leave a server idle for a long time, so the file's modification time is kept current on purpose: a scheduled task in the server kernel (`SessionSubmit@ScheduledTask[...]`) touches the file once an hour. A session counts as finished once its file has not been modified for 24 hours.

## How It Is Submitted

Submission happens in later sessions. Ten seconds after any tracked server starts, a scheduled task submits every session file that has not been modified for 24 hours by POSTing the file's contents as UTF-8 encoded JSON (`Content-Type: application/json`) to

```
https://www.wolframcloud.com/obj/wolframai-content/api/1.0/usage
```

and deletes the file once the endpoint has accepted it with a 2xx status. The JSON has exactly the fields listed above.

Only one process submits at a time: the scan runs under `WithLock` on `UsageData/Submit.lock`. A server that finds the lock taken skips its turn (it waits at most one second), and a lock left behind by a crashed process expires after ten minutes.

Failures are handled conservatively:

- A failed submission (for example, no network) keeps the file and stops the batch for this session; the remaining files are tried again by a later session.
- Files that could not be submitted for 30 days, and files that cannot be read, are deleted.
- Sessions that are not tracked (opted out, or a server without the property) never submit, delete, or create files.

Usage tracking must never interfere with the server: every hook is wrapped in `usageDataQuietly`, which logs a failure to the server log (`Log.wl`) and otherwise ignores it.

## Implementation

| File | Role |
|------|------|
| `Kernel/Server/UsageData.wl` | Session state, enabling logic (including the global setting: `getGlobalUsageDataSetting`, `setGlobalUsageDataSetting`), recording, the product identity information (`$productIdentityInfo`), the session file, its JSON encoding (`usageDataJSON`), the keep-alive task, and locked submission |
| `Kernel/Server/Local.wl` | Calls `initializeUsageData` when the server starts and `recordUsageData` after each handled request |
| `Kernel/Server/Server.wl` | Declares the session symbols and hooks shared with the local transport; defines `$StandaloneMCPServer` and `$StandaloneMCPServerInformation` |
| `Kernel/DefaultServers.wl` | `"EnableUsageData" -> True` for the built-in servers |
| `Kernel/InstallMCPServer.wl` | The `"SubmitUsageData"` option and the `SUBMIT_USAGE_DATA` environment variable |
| `Kernel/Files.wl` | The global settings file: `$globalSettingsFile`, `readGlobalSettings`, `getGlobalSetting`, `setGlobalSetting`; `writeRawJSONString` and `writeRawJSONFile`, whose `jsonConvert` conversion function writes the values that JSON cannot represent as strings |
| `Kernel/PreferencesContent.wl` | The opt-out checkbox, which reads and writes the global setting |
| `Tests/UsageData.wlt`, `Tests/Files.wlt`, `Tests/PreferencesContent.wlt` | Unit tests and server integration tests; tests of the global settings file and the JSON writers; tests of the checkbox |

Session state lives in the `` Wolfram`AgentTools`Server` `` context: `$mcpSessionID`, `$mcpClientInformation`, `$usageEvents` (an `` Internal`Bag ``), and `$usageDataEnabled`. Tunable settings (endpoint, timeouts, intervals, limits) are file-scoped variables at the top of `Kernel/Server/UsageData.wl`.

## See Also

- [mcp-clients.md](mcp-clients.md) — The `"SubmitUsageData"` option and the `SUBMIT_USAGE_DATA` environment variable
- [servers.md](servers.md) — The built-in servers and their `"EnableUsageData"` property
- [preferences-content.md](preferences-content.md) — The opt-out checkbox in the preferences panel
- [Specs/UsageData.md](../Specs/UsageData.md) — Design specification
