# Local Resource Function Definitions

AgentTools uses a few functions from the [Wolfram Function Repository](https://resources.wolframcloud.com/FunctionRepository/), pinned to the versions listed in `$resourceVersions` in `Kernel/Common.wl`. This directory holds a local copy of each of their definitions, so that the paclet can be built and loaded from source without access to the Wolfram Cloud.

`importResourceFunction` (`Kernel/Common.wl`) prefers a file in this directory over fetching the resource function. When building the MX file, the definitions are inlined into the paclet in the context ``Wolfram`AgentTools`ResourceFunctions`<Name>` `` exactly as fetched definitions would be; when loading from source, the file is loaded into that context at the first use of the imported symbol. `Scripts/BuildMX.wls` copies this directory into the temporary build copy of the paclet and uses the local `ASTPattern` for its own source annotations.

This directory is not declared in `PacletInfo.wl` and is not part of the built paclet.

## Files

| File | Version | Source |
|------|---------|--------|
| `ASTPattern.wl` | 1.0.0 | Generated from the published definition |
| `ExportMarkdownString.wl` | 1.0.0 | Generated from the published definition |
| `ImportMarkdownString.wl` | 1.0.0 | Copied from [rhennigan/ResourceFunctions](https://github.com/rhennigan/ResourceFunctions) |
| `MessageFailure.wl` | 1.0.1 | Copied from [rhennigan/ResourceFunctions](https://github.com/rhennigan/ResourceFunctions) |
| `ReadableForm.wl` | 2.1.1 | Copied from [rhennigan/ResourceFunctions](https://github.com/rhennigan/ResourceFunctions) |
| `ResourceFunctionMessage.wl` | 2.1.1 | Generated from the published definition (a dependency of `MessageFailure`) |

`ReplaceContext` (also in `$resourceVersions`) has no local copy: it is only used to move fetched definitions into their target context, which a local copy does not need.

Each file wraps the definition in `BeginPackage`/`EndPackage` for its own context so that the helper symbols of the different functions do not clash with each other or with the paclet. References to other resource functions inside a definition (e.g. `ResourceFunction[ "MessageFailure" ]`) are left as they are in the file; `importResourceFunction` rewrites them to the local symbols when it loads the file, and loads those definitions as well.

## Updating a copy

The copies must match the pinned versions in `$resourceVersions`. When a version is bumped, replace the copy:

- **Copied files** (`ImportMarkdownString`, `MessageFailure`, `ReadableForm`): copy `Definitions/<Name>/Definition.wl` from the [rhennigan/ResourceFunctions](https://github.com/rhennigan/ResourceFunctions) repository verbatim between the header and the `BeginPackage`/`EndPackage` lines. The commit it was copied from is recorded in the header. The repository's development version may be newer than the published one; only copy a version that has been published (`ASTPattern` and `ExportMarkdownString` were generated instead for this reason).

- **Generated files** (`ASTPattern`, `ExportMarkdownString`, `ResourceFunctionMessage`): these assign the published definition list directly (`Language`ExtendedFullDefinition[ ] = Language`DefinitionList[ ... ]`) rather than re-stating the definitions as code, because re-evaluating a definition such as `f[ args___ ] := ...` together with its `e: HoldPattern[ f[ ___ ] ] := ...` fallthrough merges the two rules, whereas the published definition list keeps both. Regenerate from the published definition, with cloud access:

  ```wl
  name    = "ASTPattern";
  target  = "Wolfram`AgentTools`ResourceFunctions`" <> name <> "`";
  version = ResourceObject[ name ][ "Version" ];
  defs    = ResourceFunction[ "ReplaceContext" ][
      ResourceFunction[ name, "DefinitionList" ],
      ResourceFunction[ name, "Context" ] -> target
  ];
  (* drop the repository's box formatting and usage message *)
  defs = DeleteCases[ defs, Verbatim[ RuleDelayed ][ Verbatim[ HoldPattern ][ HoldPattern[ MakeBoxes ][ _, _ ] ], FunctionResource`MakeResourceFunctionBoxes[ _ ] ], Infinity ];
  defs = DeleteCases[ defs, (Rule|RuleDelayed)[ Verbatim[ HoldPattern ][ MessageName[ _, "usage" ] ], _ ], Infinity ];
  defs = DeleteCases[ defs, (FormatValues|Messages) -> { }, Infinity ];
  code = Block[ { $Context = target, $ContextPath = { target, "System`" } },
      With[ { d = defs },
          ToString[ ResourceFunction[ "ReadableForm" ] @ Unevaluated[ Language`ExtendedFullDefinition[ ] = d ] ]
      ]
  ];
  ```

  then write `code` (followed by `;`) between the header and the `BeginPackage`/`EndPackage` lines of the existing file, updating the version in the header.

After updating, run `Tests/ResourceFunctions.wlt` and rebuild the MX file.
