# Writing and Running Tests

This guide covers how to write and run tests for AgentTools.

## Test File Format

Tests use `VerificationTest` with the following format:

```wl
VerificationTest[
    input,
    expected,
    SameTest -> MatchQ,
    TestID   -> "AnAppropriateTestID"
]
```

You can optionally include expected messages (see [Error Handling](error-handling.md) for how messages are defined and thrown):

```wl
VerificationTest[
    input,
    expected,
    { AgentTools::Tag, ... },
    SameTest -> MatchQ,
    TestID   -> "AnAppropriateTestID"
]
```

### Creating New Test Files

Always start new test files with the following boilerplate:

```wl
(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Name of First Section*)
```

The first test defines some helper functions and ensures that the paclet is loaded from the correct directory. The second test puts the main context into scope.

## TestID Conventions

- Every test should have a `TestID` specification
- If the test corresponds to a GitHub issue, you should include the issue number in the test ID, e.g. `"AnAppropriateTestID-GH#123"`
- Do not manually write the trailing `@@path/to/file.wlt:l,c` suffix
- This location suffix is automatically generated on commit by `Scripts/FormatFiles.wls`

To enable automatic TestID annotation, configure the git hook:

```bash
git config --local core.hooksPath Scripts/.githooks
```

## Running Tests with the TestReport MCP Tool

If you're using an AI coding agent with the WolframPacletDevelopment MCP server, you can run tests using the `TestReport` tool on the `Tests/` directory.

## Running Tests with `wolframscript`

> Note: Only use `wolframscript` for running tests if the TestReport MCP tool is not available.

Run all tests:

```bash
wolframscript -f Scripts/TestPaclet.wls
```

Run a specific test file:

```bash
wolframscript -f Scripts/TestPaclet.wls Tests/CreateMCPServer.wlt
```

Run multiple test files:

```bash
wolframscript -f Scripts/TestPaclet.wls Tests/CreateMCPServer.wlt Tests/StartMCPServer.wlt
```

**Path resolution**: The script accepts both absolute paths and paths relative to the paclet root directory. For example, `Tests/Foo.wlt` is equivalent to the full path `H:\Documents\AgentTools\Tests\Foo.wlt`.

## Unit Tests for Private Symbols

You can write unit tests for private symbols. Suppress linting errors by wrapping the test file content:

```wl
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* Your tests here *)

(* :!CodeAnalysis::EndBlock:: *)
```

## Testing Paclet Extensions

The paclet extension system has dedicated test files and mock paclets for testing:

- `Tests/PacletExtension.wlt` - Tests for paclet discovery, name parsing, definition loading, and resolution
- `Tests/ValidateAgentToolsPacletExtension.wlt` - Tests for extension validation

### Mock Paclets

The `TestResources/` directory contains mock paclets that simulate various extension configurations:

| Mock Paclet | Purpose |
|-------------|---------|
| `MockMCPPacletTest` | Valid extension with per-item definition files (tools, servers, prompts) |
| `MockMCPPacletCombined` | Valid extension using combined definition files (e.g., `Tools.wl`) |
| `MockMCPPacletSkills` | Valid paclet with two applicable `"AgentTools"` entries (bundles `SkillsBundle` with the default root and `DevBundle` with root `DevTools`, which re-lists items of the first entry), two entries for other systems that share a bundle name, and agent skills in every form: a skill directory with `scripts/` and `references/` files, per-item `.wl` files (association and `LLMSkill`), the combined `AgentSkills.wl`, and serialized `LLMSkill`s (`.wxf`) whose `"Location"` is inside (honored) or outside (ignored) the extension roots |
| `MockMCPPacletBadContents` | Definition files with invalid contents |
| `MockMCPPacletBadCrossRef` | Server referencing non-existent tools/prompts |
| `MockMCPPacletBadDecl` | Invalid declaration format in PacletInfo.wl |
| `MockMCPPacletBadSkills` | Invalid agent skills: missing definition, skill directory plus definition file, definitions in two roots, name mismatches (including through a `"Location"`), invalid names and descriptions, and a definition that is not a skill |
| `MockMCPPacletBadBundles` | Invalid entries and bundles: non-string `"Description"`, non-list declarations, item and bundle names with `/`, duplicate bundle names, a missing `"Root"`, servers with the same configuration key, and a bundle named after a server it does not contain |
| `MockMCPPacletDupFiles` | Duplicate definition files (`.wl` + `.wxf`) |
| `MockMCPPacletInvalidKeys` | Invalid keys in the extension block |
| `MockMCPPacletMissingFiles` | Declared items with no corresponding definition files |
| `MockMCPPacletNoRoot` | Extension without a root directory |

The `.wxf` skill definitions in `MockMCPPacletSkills` and `MockMCPPacletBadSkills` contain `LLMSkill`s with a `"Location"`, which can only be created with the `LLMSkill` association constructor (for example, `LLMSkill[ Append[ data, "Location" -> File[ "../SkillSources/located-skill" ] ] ]` where `data` is the association inside `LLMSkill[ { name, description }, body ]`), written with ``Developer`WriteWXFFile``.

Note that the PacletManager converts numbers in `PacletInfo.wl` to strings (e.g., `"Description" -> 42` becomes `"42"`), so use lists or associations to test values that must not be strings.

### Loading Mock Paclets in Tests

Use `PacletDirectoryLoad` to make mock paclets discoverable in tests:

```wl
$testResourceDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources" };

PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
$mockPaclet = PacletObject[ "MockMCPPacletTest" ];
```

For tests that expect failures (e.g., validation errors), wrap the test input with `catchTop` so that `throwFailure` throws properly:

```wl
VerificationTest[
    catchTop @ MCPServerObject[ "MockMCPPacletBadDecl/BadServer" ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "BadDecl-Fails"
]
```

See [paclet-extensions.md](paclet-extensions.md) for details on the extension system.

## Troubleshooting

If tests fail, consider:

1. **Check for MX file conflicts**: If you've modified source files but an MX file exists, delete `Kernel/64Bit/AgentTools.mx` and reload the paclet
2. **Reload the paclet**: Changes to source files require reloading with ``PacletDirectoryLoad["path/to/AgentTools"]; Get["Wolfram`AgentTools`"]``
3. **Review test output**: The test report will show which tests failed and why

## See Also

- [Getting Started](getting-started.md) - Development environment setup
- [Building](building.md) - Building the paclet
- [Error Handling](error-handling.md) - Error handling architecture and patterns
- [Paclet Extensions](paclet-extensions.md) - Extension system and validation
- [AGENTS.md](../AGENTS.md) - Detailed development guidelines
