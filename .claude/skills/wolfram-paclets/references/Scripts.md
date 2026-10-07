# Script Reference

Auto-generated reference for bundled scripts. Pass `--usage` to any
script for the latest argument documentation.

## CheckPaclet.wls

Checks a Wolfram Language paclet for issues such as missing metadata, invalid structure, or other problems that would prevent successful building or submission. Returns a summary of issues organized by severity (Error, Warning, Suggestion). Use this tool before BuildPaclet or SubmitPaclet to identify and fix problems early. The path should be an absolute path to either the paclet root directory or the definition notebook (.nb) file.

**Usage:**

```
wolframscript -f scripts/CheckPaclet.wls <path>
```

**Arguments:**

| Argument | Required | Description |
| --- | --- | --- |
| `path` | Yes | Absolute path to the paclet directory or definition notebook (.nb) file. |

---

## BuildPaclet.wls

Builds a Wolfram Language paclet, producing a .paclet archive file. This can be a long-running operation, especially for paclets with extensive documentation. Optionally runs CheckPaclet first to validate the paclet before building. The path should be an absolute path to either the paclet root directory or the definition notebook (.nb) file.

**Usage:**

```
wolframscript -f scripts/BuildPaclet.wls <path> [--check value]
```

**Arguments:**

| Argument | Required | Description |
| --- | --- | --- |
| `path` | Yes | Absolute path to the paclet directory or definition notebook (.nb) file. |
| `--check` | No | Whether to run CheckPaclet before building (default: false). |

---

## SubmitPaclet.wls

Submits a Wolfram Language paclet to the Wolfram Language Paclet Repository (paclets.com). This builds the paclet and then submits it for review. Requires prior authentication via $PublisherID or an active Wolfram Cloud connection. Use CheckPaclet first to verify the paclet is ready for submission. This is a long-running operation that involves building and uploading. The path should be an absolute path to either the paclet root directory or the definition notebook (.nb) file.

**Usage:**

```
wolframscript -f scripts/SubmitPaclet.wls <path>
```

**Arguments:**

| Argument | Required | Description |
| --- | --- | --- |
| `path` | Yes | Absolute path to the paclet directory or definition notebook (.nb) file. |

