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

#### `catchTopIsolated[eval]` / `catchTopIsolated[eval, sym]`

Like `catchTop`, but it always starts an error boundary of its own, even inside another `catchTop`. Use it for code that
can run as a preemptive evaluation (a `SocketListen` handler or a scheduled task) and for functions that such code
calls. A preemptive evaluation sees the `Block`s of the evaluation that it interrupted: inside a `catchTop` there,
`catchTop` is the identity and `$catching`, `$failed` and `$messageSymbol` belong to the interrupted evaluation, so a
nested `catchTop` would share its failure state and throw its failures into it. The socket MCP server's entry points
use it (`catchSocket` in `Kernel/Server/Socket.wl`).

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

## Bug Report Generation

When `throwInternalFailure` is called, the system automatically:

1. Captures debug data (paclet version, system info, etc.)
2. Records the evaluation stack (kept in memory only: the failure data holds it as a delayed value, never written)
3. Redacts secrets in the failure data (`redactSecrets`, see below)
4. Generates a GitHub issue URL with pre-filled information
5. Saves the failure data to a new file in `$UserBaseDirectory/Logs/AgentTools/InternalFailures` (keeping the 50 most
   recent), a directory that is made private to the user (mode 0700) on Unix-like systems
6. Sets `$LastAgentToolsFailure` for programmatic access

The failure data holds the failing call with its arguments, which messages show and the bug report and log file keep,
so `makeInternalFailureData` redacts it with `redactSecrets[expr, secrets]`. Without evaluating anything, also inside
held expressions, this replaces with `"<redacted>"`:

- the values of keys that can hold secrets (`"Token"`, `"Authentication"`, `Authentication`, `"Authorization"`,
  `"authorization"`), in rules and associations
- the values of `Authorization:` header lines and the tokens after `Bearer`, in strings and in byte arrays decoded as
  text (such as the raw bytes of an HTTP request)
- every other occurrence, in strings and byte arrays, of the given `secrets`, of the secrets registered with
  `withFailureSecrets[secrets, eval]` while the failure happened, and of the values and tokens found as above

A failing call can hold a secret on its own, such as a bearer token passed to an authentication check, which nothing in
the failure data shows to be one. So code that handles secrets registers them with `withFailureSecrets`: the socket MCP
server registers the tokens of its servers and the bearer token of the request it handles. The evaluation stack is not
searched for secrets, since it can hold any amount of data (in a preemptive evaluation, also that of the evaluation it
interrupted).

Secrets are only recognized whole. The other occurrences of the secrets found in the data are redacted only for those of
at least 8 characters (shorter strings occur by chance, and replacing them would garble the data), and for at most 32 of
them. The given and registered secrets are known to be secrets, so all their other occurrences are redacted, whatever
their length. The time taken grows only with the size of the failure data and the number of given and registered
secrets, and packed arrays are not searched. The socket MCP server also uses `redactSecrets` for the messages of
invalid calls. Keys that hold secrets should use one of these names; a new kind of secret needs a new key name or
pattern in `Common.wl`.

## Best Practices

- Use `throwFailure` for expected error conditions (bad user input, invalid arguments)
- Use `Enclose`/`Confirm*` with `throwInternalFailure` for unexpected conditions
- Always include a string tag in `Confirm*` calls (e.g., `ConfirmBy[ expr, test, "MyTag" ]`)
- Define all message tags in `Kernel/Messages.wl`
- Use `catchMine` for exported functions
- Let errors propagate naturally; avoid catching and re-throwing unless you plan to handle them in a different way

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
