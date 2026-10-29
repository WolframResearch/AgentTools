# Error Handling in AgentTools

This document explains the error handling architecture used throughout the AgentTools paclet.

## Overview

The paclet uses a layered error handling system built on top of Wolfram Language's `Catch`/`Throw` mechanism combined with the `Enclose`/`Confirm` pattern. This provides:

- Consistent error propagation to the top level
- Automatic message generation with appropriate symbols
- Distinction between expected errors and internal failures
- Automatic bug report generation for unexpected errors

## Core Components

### Error Catching: `catchTop`, `catchTopAs`, `catchMine`

These functions establish error boundaries that catch failures thrown by `throwFailure` or `throwInternalFailure`.

#### `catchTop[eval]` / `catchTop[eval, sym]`

The fundamental error catcher. Wraps an evaluation and catches any thrown failures:

```wl
catchTop @ riskyOperation[ ]
catchTop[ riskyOperation[ ], AgentTools ]
```

You should usually use the one-argument form, unless you need to specify a different message symbol.

Key behaviors:
- Sets up `$catching = True` so throws know they can be caught
- Sets `$messageSymbol` to control which symbol issues messages
- Only the **outermost** `catchTop` is active (nested calls become identity)
- Returns the failure object if one is thrown

#### `catchTopAs[sym]`

Returns a function that wraps evaluation with `catchTop` using the specified symbol:

```wl
catchTopAs[ MyFunction ][ riskyOperation[ ] ]
(* equivalent to: catchTop[ riskyOperation[ ], MyFunction ] *)
```

#### `catchMine`

A convenience wrapper for defining exported functions. When used at top-level in the right-hand side of a function definition, it automatically uses the function's symbol for messages:

```wl
MyFunction[ args___ ] := catchMine @ internalImplementation @ args
```

This effectively expands to using `catchTop` with `MyFunction` as the message symbol:
```wl
MyFunction[ args___ ] := catchTop[ internalImplementation @ args, MyFunction ];
```

### Error Throwing: `throwFailure`, `throwInternalFailure`

#### `throwFailure[tag, args___]`

Throws a **handled** error. Use this for expected error conditions where you want to show a user-friendly message:

```wl
throwFailure[ "InvalidArguments", f, HoldForm @ f @ badArg ]
```

Behavior:
- Looks up the message template from `$messageSymbol` (e.g., `AgentTools::InvalidArguments`)
- Falls back to `AgentTools::tag` if not found on the current symbol
- Creates a `Failure` object via `messageFailure`
- Throws to the nearest `catchTop` if `$catching` is true
- Returns the failure directly if not inside a `catchTop`

**Important:** The message tag must be defined in `Kernel/Messages.wl`:

```wl
AgentTools::InvalidArguments = "Invalid arguments: `1`";
```

#### `throwInternalFailure[expr, args___]`

Throws an **unhandled** internal error. Use this when something unexpected happens that indicates a bug:

```wl
throwInternalFailure[ myFunction[ x, y ], "unexpected state" ]
```

This:
- Captures the evaluation that failed
- Records the stack trace
- Generates a bug report link
- Issues `AgentTools::Internal` message

### The Enclose/Confirm Pattern

The paclet uses Wolfram's `Enclose`/`Confirm` pattern with automatic optimization for internal failures.

#### Basic Usage

```wl
myFunction // beginDefinition;

myFunction[ x_ ] := Enclose[
    Module[ { result },
        result = ConfirmBy[ computation @ x, validQ, "Computation" ];
        ConfirmMatch[ transform @ result, _String, "Transform" ];
        result
    ],
    throwInternalFailure
];

myFunction // endDefinition;
```

**Important:** Always include a string tag (the last argument) in `Confirm*` calls. This tag identifies the source location when an internal failure is triggered, making debugging much easier.

#### How It Works

The `endDefinition` function calls the following on the symbol that was just defined:
    - `expandThrowInternalFailures`
    - `optimizeEnclosures`
    - `appendFallthroughError`

##### `expandThrowInternalFailures`

The `expandThrowInternalFailures` function rewrites definitions of the form
```wl
myFunction[ args ] := Enclose[
    body,
    throwInternalFailure
];
```

to:
```wl
e$: myFunction[ args ] :=
    Module[ { eh$ = HoldComplete @ e$ },
        Enclose[ body, internalFailureFunction @ eh$, $enclosure ]
    ];
```

This ensures that any internal failures triggered in the body also include the full held function call in the error data.

##### `optimizeEnclosures`

The `optimizeEnclosures` function also looks for `Confirm*` calls in the body and adds the corresponding `$enclosure` tags to them. This avoids the need for `Enclose` to generate and insert tags at runtime.

Available confirmation functions (always include a string tag):
- `Confirm[ expr, "Tag" ]` - fails if `expr` is a `Failure` or `$Failed`
- `ConfirmBy[ expr, test, "Tag" ]` - fails if `test[ expr ]` is not `True`
- `ConfirmMatch[ expr, pattern, "Tag" ]` - fails if `expr` doesn't match `pattern`
- `ConfirmQuiet[ expr, msgs, "Tag" ]` - fails if specified messages are generated
- `ConfirmAssert[ test, "Tag" ]` - fails if `test` is not `True`

##### `appendFallthroughError`

The `appendFallthroughError` function adds a fallthrough definition to the symbol that throws an internal failure for unmatched calls:

```wl
expr: myFunction[ ___ ] := throwInternalFailure[ expr, "UnhandledDownValues", HoldForm @ myFunction ];
```

If the function already has a definition for patterns like `myFunction[ ___ ]`, it will not be modified.

#### Modified Definition

The modified definition ends up looking something like this after being processed by the above functions:

```wl
e$: myFunction[ x_ ] :=
    Module[ { eh$ = HoldComplete @ e$ },
        Enclose[
            Module[ { result },
                result = ConfirmBy[ computation @ x, validQ, "Computation", $enclosure ];
                ConfirmMatch[ transform @ result, _String, "Transform", $enclosure ];
                result
            ],
            internalFailureFunction @ eh$,
            $enclosure
        ]
    ];

e$: HoldPattern[ myFunction[ ___ ] ] := throwInternalFailure[
    e$,
    "UnhandledDownValues",
    HoldForm @ myFunction
];
```

Additionally, when building the MX file for the paclet, tags are rewritten to also include the location of the error in the original source file, for example:

```wl
e$: myFunction[ x_ ] :=
    Module[ { eh$ = HoldComplete @ e$ },
        Enclose[
            Module[ { result },
                result = ConfirmBy[ computation @ x, validQ, "Computation@@Kernel/Utilities.wl:13,18-13,69", $enclosure ];
                ConfirmMatch[ transform @ result, _String, "Transform@@Kernel/Utilities.wl:14,9-14,65", $enclosure ];
                result
            ],
            internalFailureFunction @ eh$,
            $enclosure
        ]
    ];

e$: HoldPattern[ myFunction[ ___ ] ] :=
    throwInternalFailure[ e$, "UnhandledDownValues", HoldForm @ myFunction ];
```

## Function Definition Pattern

### Exported Functions

Exported functions should use `catchMine` and `endExportedDefinition`:

```wl
MyExportedFunction // beginDefinition;
MyExportedFunction[ arg_String ] := catchMine @ myExportedFunction @ arg;
MyExportedFunction // endExportedDefinition;
```

The `endExportedDefinition`:
- Optimizes enclosures
- Adds a fallthrough definition that throws `"InvalidArguments"` for unmatched calls

### Internal Functions

Internal functions should use `Enclose` when using `Confirm*` functions:

```wl
internalHelper // beginDefinition;

internalHelper[ x_ ] := Enclose[
    Module[ { data },
        data = ConfirmBy[ loadData @ x, AssociationQ, "LoadData" ];
        processData @ data
    ],
    throwInternalFailure
];

internalHelper // endDefinition;
```

The `endDefinition`:
- Optimizes enclosures
- Adds a fallthrough definition that throws an internal failure for unmatched calls

## Error Flow Diagram

```
User calls MyFunction[...]
         │
         ▼
    ┌─────────────────────────────────────────────────────┐
    │  catchMine (establishes error boundary)             │
    │         │                                           │
    │         ▼                                           │
    │  internalFunction[...]                              │
    │         │                                           │
    │         ├──► ConfirmBy[...] fails                   │
    │         │         │                                 │
    │         │         ▼                                 │
    │         │    throwInternalFailure                   │
    │         │         │                                 │
    │         │         └──────────────────────┐          │
    │         │                                │          │
    │         ├──► throwFailure["Tag", ...]    │          │
    │         │         │                      │          │
    │         │         └──────────────────────┤          │
    │         │                                │          │
    │         ▼                                ▼          │
    │    Normal result              Thrown Failure        │
    │                                      │              │
    └─────────────────────────────────────────────────────┘
                                           │
                                           ▼
                              Failure[...] returned to user
```

## Utility Functions

### `messagePrint[args___]`

Works like `throwFailure` but returns the `Failure` object instead of throwing it. This allows execution to continue:

```wl
(* throwFailure stops execution and throws to catchTop *)
catchTop @ { throwFailure[ "MessageTag", value ], 1 + 1 }
(* => Failure[...] *)

(* messagePrint returns the Failure and continues *)
catchTop @ { messagePrint[ "MessageTag", value ], 1 + 1 }
(* => {Failure[...], 2} *)
```

Useful for issuing warnings or collecting multiple errors without stopping execution.

### `catchAlways[eval]`

Like `catchTop`, but *always* catches (even if already inside a `catchTop`):

```wl
catchAlways @ riskySubOperation[ ]
```

Use when you want to handle errors instead of propagating them to the nearest `catchTop`. Typically used in combination with `Quiet` to suppress messages.

### `catchUncaughtThrows[eval, handler]`

The MCP server's exception boundary (`Kernel/Server/Shared.wl`). `catchTop` and friends only catch the paclet's own `$catchTopTag` throws. A `Throw` with any other tag (for example ``CloudObject`Private`NetworkCallFailure``, which the cloud framework throws when the Wolfram Cloud cannot be reached), a tagless `Throw`, or an `Abort[]` would unwind through the whole server, and in the local transport that ends the read loop and with it the server process. `catchUncaughtThrows` evaluates `eval` and hands any such exception to `handler[value, tag]`, where `tag` is `None` for a tagless `Throw` and `Abort` for an abort, returning the handler's result:

```wl
result = catchUncaughtThrows[ stealthCatchTop @ tool @ args, uncaughtToolThrow[ toolName, ##1 ] & ];
```

It wraps tool evaluation in `evaluateTool` (where `uncaughtToolThrow` turns the exception into the tool's error result, with `AgentTools::CloudUnavailable` for the cloud network-failure tag), `handleMethod` in both transports (where `uncaughtRequestThrow` produces a failure that becomes a JSON-RPC internal error response), and tool warmup in the local read loop. Always place it *outside* `catchTop`/`stealthCatchTop`, so the paclet's own failures are handled first.

## Bug Report Generation

When `throwInternalFailure` is called, the system automatically:

1. Captures debug data (paclet version, system info, etc.)
2. Records the evaluation stack
3. Generates a GitHub issue URL with pre-filled information
4. Saves failure data to `$UserBaseDirectory/Logs/AgentTools/LastInternalFailureData.mx`
5. Sets `$LastAgentToolsFailure` for programmatic access

## Best Practices

- Use `throwFailure` for expected error conditions (bad user input, invalid arguments)
- Use `Enclose`/`Confirm*` with `throwInternalFailure` for unexpected conditions
- Always include a string tag in `Confirm*` calls (e.g., `ConfirmBy[ expr, test, "MyTag" ]`)
- Define all message tags in `Kernel/Messages.wl`
- Use `catchMine` for exported functions
- Let errors propagate naturally; avoid catching and re-throwing unless you plan to handle them in a different way
- Code that runs inside the MCP server must not let a `Throw` with a foreign tag escape: keep `catchUncaughtThrows` around every place where tool or request handling is evaluated (see above)

## Example: Complete Function Implementation

```wl
(* In Messages.wl *)
AgentTools::InvalidInput = "Expected a positive integer, got `1`.";

(* Exported function definition in your implementation file *)
ProcessNumber // beginDefinition;
ProcessNumber[ n_ ] := catchMine @ processNumber @ n;
ProcessNumber // endExportedDefinition;

(* In the same implementation file *)
processNumber // beginDefinition;

processNumber[ n_Integer? Positive ] := Enclose[
    Module[ { result },
        result = ConfirmBy[ expensiveComputation @ n, NumericQ, "ExpensiveComputation" ];
        ConfirmMatch[ formatResult @ result, _String, "FormatResult" ]
    ],
    throwInternalFailure
];

processNumber[ other_ ] := throwFailure[ "InvalidInput", other ];

processNumber // endDefinition;
```
