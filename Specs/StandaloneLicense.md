# Standalone MCP Server License — Specification

## Overview

The standalone MCP server product (a Wolfram kernel that only runs the MCP server) runs under its own time-limited license, separate from the Wolfram Engine license. The MCP server reports this license to the AI client and enforces it on tool calls, so users learn about an upcoming or past expiration through their AI client. The standalone application supplies the license data; the MCP server only reports and enforces it.

## License Input

The standalone application describes the license with keys of `$StandaloneMCPServerInformation`:

| Key | Type | Meaning |
|-----|------|---------|
| `"ExpirationDate"` | `DateObject` | The instant the license expires (e.g. from `FromUnixTime`) |
| `"Expired"` | `True`/`False` | `True` to treat the license as expired regardless of the date (default `False`) |
| `"InstructionsURL"` | String | Where the user finds instructions on how to continue (optional) |
| `"ProductName"` | String | Name of the product in messages (default `"MCP server"`) |
| `"WarningDays"` | Integer | Days before expiration from which reminders appear (default `14`) |

- License handling is on only when `"Expired"` or `"ExpirationDate"` is present. Otherwise (including every regular installation) the server behaves as before.
- A missing or invalid `"ExpirationDate"` (e.g. `None`) counts as expired (fail closed).
- The license is re-read on every request, so a long-running server expires on time.

## Behavior

With a license present, the server:

1. **Instructions:** appends the license status to the `instructions` of the `initialize` response (or sets them, if there are none). Before expiration, it says the server is time-limited and when it expires, and tells the client to use the license tool and pass reminders on to the user. After expiration, it says that every prompt and every other tool call fails, and (with a URL) asks the client to help the user follow the instructions.
2. **License tool:** adds a `WolframLicenseStatus` tool (no parameters) unless the server already lists it. It reports the expiration date, days remaining, and instructions URL. It always runs, even after expiration.
3. **Expiration:** once expired, every other tool call returns an error result (`isError: true`) with the expiration message, without running the tool. Prompts fail too: `prompts/get` returns a JSON-RPC error with the expiration message, without running the prompt.
4. **Warning period:** while *N* (below) is at most `WarningDays`, every other tool result gets the license status appended as an extra text content item.

Messages take the form "Your *ProductName* license expires in *N* days, on *YYYY-MM-DD*." or "Your *ProductName* license has expired.", followed by "Visit *URL* for instructions on how to continue." when a URL is given. *N* counts calendar days from today to the expiration date ("1 day" for one, "less than a day" when it expires later today). Days and dates use the time zone of `"ExpirationDate"`, not UTC.

`WolframLicenseStatus` is also an ordinary default tool that any server can list by name; without a license, it reports that the server has no time-limited license. The standalone application detects license support with `KeyExistsQ[$DefaultMCPTools, "WolframLicenseStatus"]` and won't bundle an AgentTools without it, so the tool must keep this name and stay in `$DefaultMCPTools`.

## Usage Data

The license keys are part of the product information, so they are included in usage data payloads with the rest of it (the expiration date as an ISO 8601 string in UTC).

## Out of Scope

Obtaining and validating the license is the standalone application's job. After expiration, the application keeps serving MCP so that the client can relay the expiration message.
