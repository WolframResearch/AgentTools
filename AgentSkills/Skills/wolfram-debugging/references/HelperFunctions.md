# Helper Functions (WolframDebugging.wl)

API reference of `scripts/WolframDebugging.wl`, the helper package of this skill: 55 public symbols in the context
``WolframDebugging` `` that wrap the recipes of the other references into bounded, side-effect-free calls. Read it when
a helper is mentioned elsewhere and you need its options, its result shape or its environment limits. Checked with
Wolfram 15.0.

## Loading

```wl
Get["/absolute/path/to/wolfram-debugging/scripts/WolframDebugging.wl"]   (* on its own line or in its own call *)
WolframDebugging`CollectMessages[myFunction[1, 2]]                      (* fully qualified, on a later line *)
```

| environment | how |
|---|---|
| MCP evaluator (Local and Session) | `Get` on its own line or in its own call, then full names. Each top-level input of a call is parsed just before it runs, so a name in the same input as the `Get` (`Get[...]; name[...]`) is created in the session context first. |
| wolframscript | `Get` on its own line of a `-f` file, or ``wolframscript -code 'Get["/abs/.../WolframDebugging.wl"]; Print[ToString[WolframDebugging`EnvironmentInfo[], InputForm]]'`` (`-code` prints OutputForm and drops string quotes: print with `ToString[..., InputForm]`) |
| `wolfram -script` | as with `-f` |
| CloudEvaluate | load locally, then ``CloudEvaluate[WolframDebugging`CollectMessages[...]]``: the definitions are sent along (7 helper calls in one `CloudEvaluate` took 6 s); `ShowDefinition` does not work there |
| deployed API | load locally before `CloudDeploy`; helpers used in the deployed expression are bundled with it (see `HTTPDiagnostics`) |
| remote MCP server | local files cannot be loaded: use the helper-free recipes of the other references |

Loading takes 0.1 s and has no side effects (no messages, ``Global` `` symbols, handlers or settings; dependencies load on
first use). `Get` it again after an update: all definitions are replaced.

## Conventions

- **Fully qualified calls**, always: ``WolframDebugging`Name[...]``.
- **Held arguments**: the code under test is evaluated once, inside the helper (under `StackBegin`, with its handlers
  active). Functions that inspect a value (`StuckCalls`, `FormatStack`, `HTTPSummary`, ...) evaluate their argument.
- **Spies and overrides** (`StackAtCall`, `TimeCalls`, `LogCalls`, `WithOverrides`) work inside
  ``Internal`InheritedBlock``: definitions that your code adds to those symbols (memoized values) are discarded afterwards.
- **Results**: `"Result"` is the value of your code; above `"MaxResultBytes"` (10^4 bytes; `Infinity` keeps all) it is
  `Missing["TooLarge", <|"ByteCount" -> n, "Preview" -> "..."|>]`. An uncaught `Throw` gives `Failure["UncaughtThrow", ...]`,
  `Abort[]` gives `$Aborted`, a helper stop gives `Missing["Stopped"]`: nothing escapes. `WithOverrides` and the
  `CaptureEvaluation` records hold the value as `HoldComplete[...]`, so it is not re-evaluated.
- **Failures**: an invalid call returns
  `Failure["WolframDebugging", <|"MessageTemplate", "MessageParameters", "Function", "Call", "Expected"|>]` without a
  message; unknown option names and invalid option values are named in it, with the valid options. Also
  `Failure["TraceUnavailable", ...]`, `Failure["ProtectedMode", ...]` (MCP Local) and `Missing["UnknownSymbol", name]`
  (names given as strings never create symbols).
- **Output bounds**: strings are cut to about 150 characters (`...`), big subexpressions are elided as `<<k>>`, lists
  are capped by `Max...` options, stacks are formatted text; raw frames only with `"RawStack" -> True`.
- **Messages of your code still print** (recorded, not hidden, except with `"SuppressPrinting" -> True`); in a
  `VerificationTest`, list them as expected messages.
- Options are given as strings (`"StackFrames" -> 3`). Stack frames are `HoldCompleteForm[...]` in 15.0
  (`HoldForm[...]` before); every helper accepts both and never evaluates a frame.

```wl
WolframDebugging`CollectMessages[1 + 1, "StackFrame" -> 3]
(* Failure["WolframDebugging", <|"MessageTemplate" -> "Unknown option(s) `2` for `1`. Valid options: `3`.", "MessageParameters" -> {...},
     "Function" -> "WolframDebugging`CollectMessages", "Call" -> "CollectMessages[1 + 1, \"StackFrame\" -> 3]", "Expected" -> "CollectMessages[expr, opts]"|>] *)
```

The examples below use these definitions; outputs are from wolframscript unless noted:

```wl
otherFn[x_] := 1/x; myFn[a_, b_] := Table[otherFn[i], {i, a, b}];
area[r_?NumericQ] := Pi r^2;
hlp[x_] := x^2; fib[0] = 0; fib[1] = 1; fib[n_] := fib[n - 1] + hlp[fib[n - 2]];
fact[0] = 1; fact[n_] := n fact[n - 1];
loop[] := Module[{k = 0}, While[True, k++]];
```

## Core

### `ShortString[expr, n]`
One-line InputForm string of `expr` with at most `n` (default 150) characters. Strips one `HoldComplete`/
`HoldCompleteForm`/`HoldForm`; prints ``Global` `` and session symbols without context. Use it for anything you print.
```wl
WolframDebugging`ShortString[Range[1000], 60]
(* "{1, 2, 3, 4, 5, 6, 7, 8, 9, <<987>>, 997, 998, 999, 1000}" *)
```

### `EnvironmentInfo[]`
Where the code runs and what that means (run it first when behavior is surprising): `"Environment"`, `"Version"`,
`"TraceWorks"`, `"ProtectedMode"`, `"Context"`, `"UserContexts"` (where your symbols live), `"QuietedGlobally"`,
`"ProcessID"`, `"TimeRemaining"`, `"Notes"`.
```wl
KeyTake[WolframDebugging`EnvironmentInfo[], {"Environment", "TraceWorks", "ProtectedMode", "UserContexts"}]
(* <|"Environment" -> "wolframscript", "TraceWorks" -> True, "ProtectedMode" -> False, "UserContexts" -> {"Global`"}|> *)
```
MCP Local: `"MCP evaluator, Method Local (...)"`, `True`, `True`, ``{"Global`", "Sessions`<id>`"}``; MCP Session:
`"MCP evaluator, Method Session (...)"`, `False`; CloudEvaluate: `"CloudEvaluate"`, `False`, `True`.

## Messages and Stacks

### `CollectMessages[expr, opts]`
Records every message of `expr`: name, text with short arguments, whether it really printed or was quieted, and the last
stack frames. The first tool for "which message, from where"; works in every environment (no Trace). Options:
`"IncludeQuieted"` (False) also record messages silenced by `Quiet`/`Off`; `"StackFrames"` (6) frames per message, 0 =
none; `"MaxMessages"` (25) records kept, counting continues; `"StringLength"` (150); `"StopAt"` (None) stop at a
message: `"Power::infy"`, `"Last::*"`, `"*::infy"`, a pattern, or `{spec, k}` for the k-th match (give names as strings:
`General::stop` evaluates to its text); `"IgnoreOuterQuiet"` (True) evaluate as `Quiet[expr, None, All]`, cancelling a
`Quiet` around the call (the remote MCP server quiets every input); `"ResetMessageList"` (True)
`Block[{$MessageList = {}}, ...]` (fresh `General::stop` count; MCP Session never resets it); `"SuppressPrinting"` (False)
`Block[{$Messages = {}}, ...]`; `"MaxResultBytes"`. `"Printed"` is False for quieted messages and for those suppressed
by `General::stop` (their willPrint flag is still True).
```wl
WolframDebugging`CollectMessages[myFn[-1, 1]]
(* <|"Result" -> {-1, ComplexInfinity, 1}, "MessageCount" -> 1, "Messages" -> {<|"Message" -> HoldForm[Power::infy],
     "Text" -> "Power::infy: Infinite expression 0^(-1) encountered.", "Printed" -> True, "Quieted" -> False,
     "Stack" -> {"myFn[-1, 1]", "Table[otherFn[i], {i, -1, 1}]", "otherFn[i]", "1/0", "0^(-1)"}|>}|> *)
```
`"StopAt" -> "First::*"` on `{First[{}], Last[{}]}` gives `"Result" -> Missing["Stopped"]` after one message; it throws,
so a `Catch[..., _]` in your code can intercept it.

### `StackAtMessage[expr, msg, opts]`
The full stack at the first printed message (or the first matching `msg`: `Power::infy`, `"Power::*"`, `"*::infy"`, a
pattern), formatted. Use it when `CollectMessages`' last frames are not enough. Options: `"MaxCount"` (1) record this
many matches; `"Stop"` (True) stop the evaluation after `"MaxCount"` matches; `"Complete"` (True) `StackComplete`
(keeps the frames of calls already rewritten into their body, such as `myFn[-1, 1]`); `"IncludeQuieted"` (False);
`"IgnoreOuterQuiet"` (True); `"RawStack"` (False) also return the frames; `"MaxResultBytes"`; the `FormatStack` options.
With `"MaxCount"` > 1 the matches are in `"Captures"`; `"Message" -> None`: no match.
```wl
WolframDebugging`StackAtMessage[myFn[-1, 1], Power::infy]
(* <|"Result" -> Missing["Stopped"], "Message" -> "Power::infy: Infinite expression 0^(-1) encountered.",
     "Stack" -> "(6 frames)\n1| myFn[-1, 1]\n2| Table[otherFn[i], {i, -1, 1}]\n3| otherFn[i]\n4| 1/0\n5| 0^(-1)\n6| Message[Power::infy, HoldCompleteForm[0^(-1)]]",
     "StackLength" -> 6|> *)
```
Frames show expressions as pushed (`otherFn[i]`, not `otherFn[0]`): use `StackAtCall` for argument values.

### `StackAtCall[expr, callPattern, opts]`
The stack each time a call matching `callPattern` (`f[0]`, `_f`, `f[x_] /; x < 0`) is evaluated; the call frame shows
the actual arguments. A never-matching conditional rule is prepended to `f` inside ``Internal`InheritedBlock``, so the
definitions are unchanged afterwards. Options: `"MaxCount"` (1); `"Stop"` (True; use False when probing `Throw`);
`"Complete"` (False); `"RawStack"` (False) adds `"RawStacks"`; `"MaxResultBytes"`; plus the `FormatStack` options.
```wl
WolframDebugging`StackAtCall[myFn[-1, 1], otherFn[0]]
(* <|"Result" -> Missing["Stopped"], "Count" -> 1, "Stacks" -> {"(2 frames)\n1| Table[otherFn[i], {i, -1, 1}]\n2| otherFn[0]"}|> *)
```
Not seen: calls answered by literal rules (`f[0] = 1`) and calls made inside kernel code. `f` must not be `Locked`.

### `FormatStack[stack, opts]`
Numbered lines, recursion collapsed (`-- frames 2-11: a 2-frame cycle repeated 5 times (first and last shown) --`).
`stack`: frames (`Stack[_]`, `Stack[]`, your capture) or a `"RawStack" -> True` result; a formatted string is returned as
is. Options: `"MaxFrames"` (25, the last ones); `"MaxFrameLength"` (150); `"Filter"` (All | `"Calls"` drops plumbing
such as `Table`, `If`, `Times` | `"User"` | context prefixes | a pattern for the frame contents); `"Start"`/`"End"`
(None | pattern: keep from the first/to the last match); `"Collapse"` (True); `"ShortContexts"` (False).
```wl
r = WolframDebugging`StackAtMessage[myFn[-1, 1], "RawStack" -> True];
WolframDebugging`FormatStack[r, "Filter" -> "Calls"]
(* "(6 frames, 2 after Filter)\n1| myFn[-1, 1]\n3| otherFn[i]" *)
```

### `StackSummary[stack]`
Size and composition of a stack without its contents: `"Length"`, `"ByteCount"`, `"TopHeads"`, `"Contexts"`. Useful for
deep recursion before formatting anything.
```wl
WolframDebugging`StackSummary[r]
(* <|"Length" -> 6, "ByteCount" -> 1240, "TopHeads" -> {{"myFn", 1}, {"Table", 1}, {"otherFn", 1}, {"Times", 1}, {"Power", 1},
     {"Message", 1}}, "Contexts" -> {{"System`", 4}, {"Global`", 2}}|> *)
```

### `CaptureEvaluation[expr]` and `$CaptureFunction`
One record for a `$Failed`/`Failure` without explanation: `"KernelID"`, `"PID"`, `"Result"` (`HoldComplete`),
`"ResultString"`, `"MessageCount"`, `"Messages"` (first 10), `"PrintCount"`, `"Prints"` (first 10; Print is suppressed),
`"Stack"` (last 12 frames at the first message), `"Aborted"`, `"Thrown"`, `"Seconds"`.
```wl
WolframDebugging`CaptureEvaluation[Print["hi"]; 1/0; Throw[5]]
(* <|"KernelID" -> 0, "PID" -> 4242, "Result" -> HoldComplete[Throw[5]], "ResultString" -> "Throw[5]", "MessageCount" -> 1,
     "Messages" -> {"Power::infy: Infinite expression 0^(-1) encountered."}, "PrintCount" -> 1, "Prints" -> {"hi"},
     "Stack" -> {"Print[\"hi\"]; 1/0; Throw[5]", "1/0", "0^(-1)", "Message[Power::infy, HoldCompleteForm[0^(-1)]]"},
     "Aborted" -> False, "Thrown" -> "Throw[5]", "Seconds" -> 0.001|> *)
```
`$CaptureFunction` is the same as a self-contained pure function (``System` ``/``Internal` `` functions and its own
local variables: no definitions needed) for subkernels, task bodies and handlers:
``With[{cap = WolframDebugging`$CaptureFunction}, ParallelMap[cap[f[#]] &, list]]``.
```wl
With[{cap = WolframDebugging`$CaptureFunction}, Map[cap[otherFn[#]]["ResultString"] &, {1, 2}]]
(* {"1", "1/2"} *)
```

## Performance and Trace

### `SampleStacks[expr, maxSeconds, opts]`
Profiler and hang locator that works everywhere (no Trace): a `ScheduledTask` samples the stack while `expr` runs,
stopped after `maxSeconds` (`Automatic`: at most 10 s, safely below the remaining tool time). Returns `"Seconds"`,
`"TimeLimit"`, `"TimedOut"`, `"Samples"`, `"Functions%"` (% of samples with the function on the stack),
`"InnermostFunction%"`, `"Builtin%"` (innermost frame head), `"LastFrames"` (last sample, with live local values),
`"Result"`. Options: `"Interval"` (0.01 s); `"MaxEntries"` (8); `"MaxFrames"` (12); `"MaxFrameLength"` (100);
`"MaxResultBytes"`.
```wl
WolframDebugging`SampleStacks[loop[], 1]
(* <|"Seconds" -> 1.001, "TimeLimit" -> 1., "TimedOut" -> True, "Samples" -> 98, "Functions%" -> <|"loop" -> 100.|>,
     "InnermostFunction%" -> <|"loop" -> 100.|>, "Builtin%" -> <|"Increment" -> 80.6, "While" -> 19.4|>,
     "LastFrames" -> {"loop[]", "Module[{k = 0}, While[True, k++]]", "While[True, k$17041++]", "k$17041++"}, "Result" -> $TimedOut|> *)
```
A call that cannot be interrupted (a long `Sort`, `Run`, a blocked read) gets at most one sample: the last sample names
it.

### `TimeCalls[expr, {f, ...}, opts]`
Exact call counts and inclusive seconds per function (outermost call only: recursion is not counted twice); works
everywhere. Option: `"MaxResultBytes"`. Not for `Locked` symbols or OwnValues; calls answered by literal rules
(`fib[0] = 0`) are not counted; counts of `Flat`/`Orderless` heads (`Plus`, `StringJoin`) are too high (use `LogCalls`).
```wl
WolframDebugging`TimeCalls[fib[15], {fib, hlp}]
(* <|"TotalSeconds" -> 0.023, "Calls" -> <|"fib" -> 986, "hlp" -> 986|>, "Seconds" -> <|"fib" -> 0.023, "hlp" -> 0.01|>,
     "Result" -> 186242594112190847520182173826|> *)
```

### `TraceAvailableQ[]`
True when `Trace` records evaluations here: wolframscript and MCP Local (notebooks: not checked here); False in MCP
Session, `wolfram -script`, CloudEvaluate, deployed APIs and the remote MCP server.
The three Trace-based helpers below return `Failure["TraceUnavailable", ...]` where it is False.

### `TraceCalls[expr, form, n, opts]`
The first `n` (20) evaluations matching `form`, after argument evaluation, as short strings; the evaluation is stopped
once `n` are collected (`"EvaluationFinished" -> False`). Options: `"MaxLength"` (150) and any `Trace` option
(`TraceInternal -> True` also shows calls inside System functions, `TraceOff`, `TraceDepth`, ...).
```wl
WolframDebugging`TraceCalls[fib[8], _hlp, 3]
(* <|"Calls" -> {"hlp[0]", "hlp[1]", "hlp[0]"}, "EvaluationFinished" -> False|> *)
```

### `CountCalls[expr, form, opts]`
How often calls matching `form` were evaluated, by head. Options: `"MaxEntries"` (25; the rest are summed under
`"(other heads)"`) and `Trace` options.
```wl
WolframDebugging`CountCalls[fib[8], _fib | _hlp]
(* <|"fib" -> 67, "hlp" -> 33|> *)
```

### `FindHang[expr, maxSteps, opts]`
Runs `expr` for at most `maxSteps` (10^5) evaluation steps; if unfinished, gives the stack heads and the last steps.
Options: `"LastSteps"` (15); `"MaxLength"` (120); `"MaxStackHeads"` (25); `"MaxResultBytes"`. Finished:
`<|"Finished" -> True, "Steps", "Result"|>`.
```wl
WolframDebugging`FindHang[loop[], 2000, "LastSteps" -> 3]
(* <|"Finished" -> False, "Steps" -> 2000, "StackHeads" -> {"loop", "Module", "While"}, "LastSteps" -> {"k$18051++", "k$18051++", "k$18051++"}|> *)
```

## Overrides

### `LogCalls[{f, ...}, expr, opts]` and `CallLogSummary[log, n, opts]`
Every call of the functions with depth, result and time (spy rules inside ``Internal`InheritedBlock``; recursion, Hold
attributes, Flat heads, System symbols such as `StringJoin`). Options: `"MaxCalls"` (200, all are counted);
`"IncludeLiteralRules"` (True: also calls answered by rules like `f[0] = 1`); `"MaxResultBytes"`. Returns
`<|"Result", "Calls" -> {<|"ID", "Depth", "Parent", "Call", "Result", "Seconds"|>, ...}, "TotalCalls"|>`;
`"Call"`/`"Result"` are `HoldComplete[...]` (a truncated string above 2000 bytes), `Missing["NotReturned"]` when a call
threw or aborted. `CallLogSummary` prints the first `n` (30) calls as a tree; option `"MaxLength"` (120).
```wl
log = WolframDebugging`LogCalls[{fact}, fact[3]];
WolframDebugging`CallLogSummary[log]
(* "fact[3] -> 6 (0.13 ms)\n  fact[2] -> 2 (0.09 ms)\n    fact[1] -> 1 (0.05 ms)\n      fact[0] -> 1 (0. ms)" *)
```
Not for `Locked` symbols, symbols with OwnValues, or the functions the logger itself uses (`Block`, `TrueQ`, `Not`,
...).

### `WithOverrides[{lhs :> rhs, ...}, expr, opts]`
Evaluates `expr` with the rules temporarily in front of the existing definitions (`sym :> v` OwnValues, `f[...] :> v`
DownValues, `f[...][...] :> v` SubValues; `->` acts like `:>`) and returns `HoldComplete[result]`: mock HTTP (`URLRead`,
`URLFetch`), time (`Now`), files, slow functions. Stubs are loaded first, `Locked` symbols refused; literal left-hand
sides (`f[7]`) are tried before pattern ones whatever the order. Option: `"MaxResultBytes"`.
```wl
WolframDebugging`WithOverrides[{otherFn[0] :> "MOCK"}, myFn[-1, 1]]
(* HoldComplete[{-1, "MOCK", 1}] *)
```

### `SnapshotDefinitions[sym]` and `RestoreDefinitions[sym, snapshot]`
All values, messages and attributes of `sym` (works for ReadProtected symbols); `RestoreDefinitions` puts them back and
gives True when `sym` matches the snapshot. For changes that must span several tool calls; prefer `WithOverrides`.
Assign the snapshot to a variable, do not print it.
```wl
snap = WolframDebugging`SnapshotDefinitions[otherFn];
otherFn[x_] := 0;
{otherFn[2], WolframDebugging`RestoreDefinitions[otherFn, snap], otherFn[2]}
(* {0, True, 1/2} *)
```

## Watchpoints and Probes

### `WatchChanges[{sym, ...}, expr, opts]`
Records every change of the symbols' values or definitions (``Internal`SetValueMonitor`` + a `"ValueChange"` handler)
with the user functions on the stack. Events: `HoldComplete[x, old, new, OwnValues]`,
`HoldComplete[x, x[[1]], 5, Part]`, `HoldComplete[x, Clear]`, definition changes, Block entry/exit. Options:
`"MaxEvents"` (20, all are counted); `"MaxLength"` (160); `"MaxResultBytes"`.
```wl
counter = 0; bump[] := counter++;
WolframDebugging`WatchChanges[{counter}, bump[]; bump[]]
(* <|"Result" -> 1, "Count" -> 2, "Changes" -> {<|"Event" -> "HoldComplete[counter, 0, 1, OwnValues]", "Callers" -> {"bump"}|>,
     <|"Event" -> "HoldComplete[counter, 1, 2, OwnValues]", "Callers" -> {"bump"}|>}|> *)
```

### `StopWhen[sym, test, expr, opts]`
Stops at the first assignment that gives `sym` a value `v` with `test[v]` True and returns the change and the stack
(user frames, or the last frames when only System code is involved). Otherwise `<|"Stopped" -> False, "Result"|>`.
Options: `"MaxFrames"` (15); `"MaxLength"` (120); `"MaxResultBytes"`.
```wl
state = 0;
WolframDebugging`StopWhen[state, # > 2 &, Do[state = k, {k, 5}]]
(* <|"Stopped" -> True, "Event" -> "HoldComplete[state, 2, 3, OwnValues]", "Stack" -> {"Do[state = k, {k, 5}]", "state = k"}|> *)
```

### `NewSymbolsDuring[expr, opts]`
Symbols created at run time (`ToExpression`, `Symbol`, `Get`, ...): typos, leaks, wrong contexts while loading. Symbols
of the input itself were created when it was parsed and are not listed (`ToExpression` creates symbols in `$Context`:
``Sessions`<id>` `` in the MCP evaluator). Options: `"MaxSymbols"` (50); `"MaxResultBytes"`.
```wl
WolframDebugging`NewSymbolsDuring[ToExpression["newSym1 + newSym2"]]
(* <|"Result" -> newSym1 + newSym2, "Count" -> 2, "NewSymbols" -> {"Global`newSym1", "Global`newSym2"}|> *)
```

### `FileWritesDuring[expr, opts]`
Files opened for writing (`"Wolfram.File.OpenWrite"` handler; a notification, the write still happens). Options:
`"MaxFiles"` (50); `"MaxResultBytes"`.
```wl
WolframDebugging`FileWritesDuring[Export[FileNameJoin[{$TemporaryDirectory, "wd-example.txt"}], "x", "Text"]]
(* <|"Result" -> "/tmp/wd-example.txt", "Count" -> 1, "Writes" -> {{"OpenWrite", "/tmp/wd-example.txt"}}|> *)
```

### `CapturePrints[expr, max, opts]`
Suppresses `Print` and returns the first `max` (20) texts; `Echo` goes through `Print` and is captured, except in
CloudEvaluate, deployed APIs and on the remote MCP server, where it bypasses `Print` (and is not shown either).
`Block[{Print = ...}]` hides prints in every environment (`Block[{$Output = {}}, ...]` does not in MCP Session).
Options: `"MaxLength"` (200 per text); `"MaxResultBytes"`.
```wl
WolframDebugging`CapturePrints[Print["a"]; Echo[2, "x:"]; 3]
(* <|"Result" -> 3, "PrintCount" -> 2, "Prints" -> {"a", ">> x: 2"}|> *)
```

### `FailedAssertions[expr, opts]`
`Assert` calls that failed, also when `Assert` is Off (the default); `"Line"`/`"File"` are included for code loaded with
`Get`. Options: `"MaxAssertions"` (20); `"MaxResultBytes"`.
```wl
check[x_] := (Assert[x > 0]; x);
WolframDebugging`FailedAssertions[check[-1] + check[2]]
(* <|"Result" -> 1, "Count" -> 1, "Failed" -> {<|"Assert" -> "-1 > 0", "Callers" -> {"check"}|>}|> *)
```

### `LeakCheck[expr, max, opts]`
Symbols and `Module` temporaries that `expr` left behind (by name pattern, the `max` (5) largest) and the `MemoryInUse`
change. Option: `"MaxResultBytes"`.
```wl
cache = {}; leaky[] := Module[{t}, t[1] = 1; AppendTo[cache, t]];
KeyDrop[WolframDebugging`LeakCheck[Do[leaky[], 3], 2], {"MemoryDelta", "Result"}]
(* <|"NewSymbols" -> 3, "NewTemporaries" -> 3, "TemporariesByName" -> <|"t$*" -> 3|>,
     "LargestTemporaries" -> {{"t$18294", 424}, {"t$18295", 424}}, "OtherNewSymbols" -> {}|> *)
```

## Unevaluated Calls

### `WhyNoMatch[f[args], opts]`
Which definition applies to `f[args]` and why the others do not, without Trace and without evaluating any rule body: the
arguments are evaluated once as the evaluator would (Hold attributes, `Sequence`, Flat, Listable, Orderless), then the
kernel's matcher runs each rule with tests and conditions instrumented. Reports argument counts, the first failing
argument, test/condition values, rule order, OwnValue heads, built-ins (`ArgumentsPattern`), symbols in other contexts,
similar names. Options: `"EvaluateArguments"` (True); `"MaxRules"` (12); `"MaxLength"` (110); `"Hints"` (True).
```wl
WolframDebugging`WhyNoMatch[area["4"]]
(* <|"Summary" -> "no rule matches; area[\"4\"] stays unevaluated (1 rule(s) checked)",
     "Head" -> <|"Symbol" -> "Global`area", "Definitions" -> <|"DownValues" -> 1|>|>, "Call" -> "area[\"4\"]",
     "Rules" -> {"DownValues[[1]]: area[(r_)?NumericQ] -> test NumericQ[\"4\"] gave False"}|> *)
```
```wl
WolframDebugging`WhyNoMatch[myFn[1]]["Rules"]
(* {"DownValues[[1]]: myFn[a_, b_] -> the call has 1 argument(s), the pattern takes 2"} *)
```
An argument that throws or aborts gives `"Summary" -> "the analysis was interrupted: ..."`.

### `StuckCalls[result, opts]`
Summarizes the unevaluated calls in a (large) result: count per head, the smallest example, and why (no definitions,
similar names, defined in another context, autoload stub, rules that did not match). Options: `"MaxHeads"` (8);
`"MaxLength"` (80); `"Heads"` ({}: System heads to include). Also lists `Failure`/`Missing`/`$Failed` found in the
result.
```wl
WolframDebugging`StuckCalls[{area["4"], Lenght[{1}], area[2]}]
(* <|"StuckCalls" -> 2, "ByHead" -> <|"area" -> "1x, has 1 DownValues, none matched (use WhyNoMatch), e.g. area[\"4\"]",
     "Lenght" -> "1x, NO definitions (similar names: System`Length), e.g. Lenght[{1}]"|>|> *)
```

## Definitions and Source

### `ShowDefinition[sym or "name", n]`
`Definition` as text with short contexts, ReadProtected bypassed inside ``Internal`InheritedBlock``, at most `n` (3000)
characters. A string or a string-valued expression is taken as the name (unknown: `Missing["UnknownSymbol", name]`).
An unloaded autoload stub shows only the stub (`CloudGet = ActivateLoad[...]`): call `EnsureLoaded` first. Under
CloudEvaluate it returns `"Null"` (`Definition` is broken in cloud kernels; use `DownValues` there).
```wl
rp[x_] := x + 1; SetAttributes[rp, ReadProtected];
WolframDebugging`ShowDefinition[rp]
(* "rp[x_] := x + 1" *)
```

### `SymbolKind[sym or "name"]`
What a symbol is, without loading it: `"Symbol"`, `"Attributes"`, `"AutoloadStub"`, `"Autoload"` (mechanism and loader
context), `"KernelCode"`, `"Counts"` (Own/Down/Up/Sub values), `"Usage"` (first 150 characters).
```wl
WolframDebugging`SymbolKind["CloudPut"]
(* <|"Symbol" -> "System`CloudPut", "Attributes" -> {Protected, ReadProtected}, "AutoloadStub" -> True,
     "Autoload" -> {"Package`ActivateLoad", "CloudObjectLoader`"}, "KernelCode" -> False,
     "Counts" -> <|"Own" -> 1, "Down" -> 0, "Up" -> 0, "Sub" -> 0|>, "Usage" -> "CloudPut[expr] writes expr to a new anonymous cloud object. ..."|> *)
```
In MCP Local the package is already loaded: `"AutoloadStub" -> False`, `"Down" -> 7`.

### `FindSymbolSource["name" or sym, opts]`
Source files and line ranges of a symbol's definitions (contexts → `FindFile` → paclet roots → CodeParser metadata;
works for stubs). Options: `"MaxDefinitions"` (10); `"Kinds"` (All | e.g.
`{"DownValue", "UpValue", "Options", "Message"}`); `"MaxLength"` (400). Also `"Contexts"`, `"EntryFiles"`,
`"LoadedRoots"`, `"KernelCode"`, `"MXFiles"`, `"Notes"` (why nothing was found). Several definitions on one source line
(`f[x_] := 1; f[] := 0;`) are one entry, so `"TotalDefinitions"` can be lower than `Length[DownValues[f]]`.
```wl
KeyTake[WolframDebugging`FindSymbolSource["CodeParser`CodeParse", "Kinds" -> {"DownValue"}, "MaxDefinitions" -> 1, "MaxLength" -> 60],
  {"PacletRoots", "TotalDefinitions", "Definitions"}]
(* <|"PacletRoots" -> {"/usr/local/Wolfram/Wolfram/15.0/SystemFiles/Components/CodeParser"}, "TotalDefinitions" -> 3,
     "Definitions" -> {<|"File" -> ".../CodeParser/Kernel/CodeParser.wl", "Lines" -> {848, 859}, "Kind" -> "DownValue",
     "Text" -> "CodeParse[s_String, opts:OptionsPattern[]] :=\nCatch[\nModule[ ... (185 chars)"|>}|> *)
```

### `PacletRoot[file]`
The nearest enclosing directory with a `PacletInfo.wl`/`.m` (`Missing["NotFound", file]` outside paclets); always
terminates.
```wl
WolframDebugging`PacletRoot[FindFile["CodeParser`"]]
(* "/usr/local/Wolfram/Wolfram/15.0/SystemFiles/Components/CodeParser" *)
```

## Package Loading

### `LoadTrace[expr, opts]`
The autoloads and file loads that evaluating `expr` causes, with nesting depth and trigger:
`"Loads" -> {{depth, "Autoload"|"Get", target, resolved file or loader context, trigger}, ...}`, plus `"LoadCount"`,
`"NewFileCount"`, `"NewFilesByDirectory"`, `"NewFiles"` (`$LoadedFiles` difference: also `.mx` files). Options:
`"MaxLoads"` (30); `"MaxDepth"` (Infinity; 0 = top-level loads); `"MaxFiles"` (20); `"MaxLength"` (80);
`"MaxResultBytes"`.
```wl
KeyTake[WolframDebugging`LoadTrace[ErlangB[2, 3]], {"Result", "LoadCount", "Loads", "NewFileCount"}]
(* <|"Result" -> 9/17, "LoadCount" -> 2, "Loads" -> {{0, "Autoload", "System`ErlangB", "SpecialFunctions`StatisticalFunctions`", "ErlangB[2, 3]"},
     {0, "Autoload", "Statistics`Library`AdmissibleUnivariateInputQ", "Statistics`Library`", "Statistics`Library`AdmissibleUnivariateInputQ[2]"}},
     "NewFileCount" -> 2|> *)
```
First-time effects only: in MCP Local the same call gives `"LoadCount" -> 0` (already loaded). Use a fresh
wolframscript.

### ``ContextSourceInfo["Ctx`"]``
Where a context's code comes from and whether the loaded code is current: `"InPackages"` (True: `Needs` is a no-op),
`"OnContextPath"`, `"FindFile"`, `"Candidates"` (installed versions, the first one wins), `"LoadedFileCount"`,
`"LoadedFiles"`, `"OtherLoadedCopies"`, `"StaleMX"` (loaded `.mx` older than the newest source), `"NewestSource"`,
`"EditedSinceKernelStart"` (source edited after this kernel started: the running code cannot contain the edit).
```wl
KeyTake[WolframDebugging`ContextSourceInfo["CodeParser`"], {"InPackages", "Candidates", "LoadedFileCount", "StaleMX", "EditedSinceKernelStart"}]
(* <|"InPackages" -> True, "Candidates" -> {{"CodeParser", "1.13", "/usr/local/Wolfram/Wolfram/15.0/SystemFiles/Components/CodeParser"}},
     "LoadedFileCount" -> 19, "StaleMX" -> {}, "EditedSinceKernelStart" -> {}|> *)
```

### `AutoloadStubQ[sym or "name"]` and `EnsureLoaded[sym or "name"]`
`AutoloadStubQ` tells whether a symbol is still an unloaded autoload stub, without loading it. `EnsureLoaded` evaluates
the stub (loading its package) and gives True when no stub remains; do this before overriding or inspecting a stub.
```wl
{WolframDebugging`AutoloadStubQ["CloudPut"], WolframDebugging`EnsureLoaded["CloudPut"], WolframDebugging`AutoloadStubQ["CloudPut"]}
(* {True, True, False} *)
```
MCP Local: `{False, True, False}` (preloaded).

## Tests

The examples use this file (two failing tests and a duplicate TestID):
```wl
file = FileNameJoin[{$TemporaryDirectory, "wd-demo.wlt"}];
Export[file, "VerificationTest[1 + 1, 2, TestID -> \"Pass\"]
VerificationTest[StringJoin[\"a\", \"b\"], \"ba\", TestID -> \"Wrong\"]
VerificationTest[1/0; 1, 1, TestID -> \"Pass\"]", "Text"];
WolframDebugging`TestFailureSummary[TestReport[file], "Format" -> "Text"]
(* "Wrong [Failure/SameTestFailure]\n  in:  StringJoin[\"a\", \"b\"]\n  exp: \"ba\"\n  act: \"ab\"\nPass [MessagesFailure/SameMessagesFailure]\n  in:  1/0; 1 ..." *)
```

### `TestFailureSummary[report, opts]`
One record per failed test of a `TestReportObject`, a `TestObject` or a list: `"TestID"`, `"Outcome"` (with failure
type), `"Input"`, `"Expected"`, `"Actual"`, `"Messages"` (repeats collapsed), `"ExpectedMessages"`, `"FailedSteps"` (for
`IntermediateTest`). Never print a report object itself. Options: `"MaxBytes"` (2000: fields are shortened, then records
dropped); `"MaxLength"` (160); `"Format"` (`"Association"` | `"Text"`, shown above).

### `TestSource[file, idPattern]`
The source of the tests whose TestID (with or without the `@@file:line` suffix) matches the string pattern; nothing is
evaluated.
```wl
WolframDebugging`TestSource[file, "Wrong"]
(* {<|"TestID" -> "Wrong", "Lines" -> {2, 2}, "Code" -> "VerificationTest[StringJoin[\"a\", \"b\"], \"ba\", TestID -> \"Wrong\"]"|>} *)
```

### `RunTestsByID[file, idPattern, opts]`
`TestReport` of the file in which only the matching tests (and `"Setup"` tests) run; returns a summary. Options:
`"Setup"` (None | TestID pattern of setup tests, e.g. `"GetDefinitions" | "LoadContext"`); `"Context"` (Automatic: the
file is read in `$Context`, where your typed definitions are, and symbols the tests create go there; another context:
the file is read there, and `$Context` is taken off `$ContextPath`); `"TimeConstraint"` (Automatic: per test, below the remaining tool time); `"ReturnReport"`
(False: True returns the `TestReportObject`); `"MaxBytes"` (2000).
```wl
WolframDebugging`RunTestsByID[file, "Wrong"]
(* <|"File" -> "/tmp/wd-demo.wlt", "TestsRun" -> 1, "Succeeded" -> 0, "Failed" -> 1, "Outcomes" -> {"Wrong" -> "Failure"},
     "Failures" -> "Wrong [Failure/SameTestFailure]\n  in:  StringJoin[\"a\", \"b\"]\n  exp: \"ba\"\n  act: \"ab\""|> *)
```

### `ReproduceTest[test, opts]`
Re-evaluates a test input like the harness (`$Messages = {}`, only messages that would print are recorded, input under
`StackBegin`) and returns `"Result"`, `"Messages"` and `"StackAtFirstMessage"`. `test`: a `TestObject`, a `TestSource`
record or `HoldComplete[input]`. Options: `"Frames"` (12); `"MaxLength"` (120); `"TimeConstraint"` (30);
`"PrintMessages"` (False).
```wl
WolframDebugging`ReproduceTest[HoldComplete[myFn[-1, 1]]]
(* <|"Result" -> "{-1, ComplexInfinity, 1}", "Messages" -> {"Power::infy: Infinite expression 0^(-1) encountered."},
     "StackAtFirstMessage" -> {"Table[otherFn[i], {i, -1, 1}]", "1/0", "0^(-1)"}|> *)
```

### `CheckTestFile[file]`
Static checks for problems that `TestReport` reports badly or not at all: `"SyntaxError"` (then no test of the file runs
and the TestReport tool reports success with 0 tests), `"TopLevelAbort"`/`Throw`/`Exit`/`Quit`,
`"MalformedVerificationTest"` (more than 3 positional arguments: the test is dropped), `"NoTestID"`,
`"DuplicateTestID"`.
```wl
WolframDebugging`CheckTestFile[file]
(* {<|"Line" -> 3, "Issue" -> "DuplicateTestID", "Detail" -> "Pass"|>} *)
```

## Parallel and Asynchronous

### `ParallelCapture[f, list, opts]`
Maps `f` in parallel under `$CaptureFunction` and reports messages, aborts, throws, items run in the master
(`"RanInMaster"`) and `"MasterOnlyHeads"`: functions left unevaluated on a subkernel but defined in the master (not
distributed: package contexts, ReadProtected/MX code). Options: `"MaxRows"` (5); `"DistributedContexts"` (Automatic).
Launch and close kernels yourself (otherwise `ParallelMap` launches its default number; after `CloseKernels[]` it does
not relaunch and every item runs in the master); subkernels exist in wolframscript, `wolfram -script` and MCP Session
only (wolframscript run):
```wl
sq[x_] := x^2; pkg`cube[x_] := x^3;
LaunchKernels[1];
{KeyTake[WolframDebugging`ParallelCapture[sq, {1, 2, 3}], {"Kernels", "RanInMaster", "ProblemCount", "FirstResults"}],
 WolframDebugging`ParallelCapture[pkg`cube, {2}]["Problems"][[1, {"ResultString", "MasterOnlyHeads"}]]}
(* {<|"Kernels" -> 1, "RanInMaster" -> 0, "ProblemCount" -> 0, "FirstResults" -> {"1", "4", "9"}|>,
    <|"ResultString" -> "pkg`cube[2]", "MasterOnlyHeads" -> {"pkg`cube"}|>} *)
```

### `KernelReport[]`
Parallel kernels and their process IDs, `WolframKernel` child processes of this kernel and those not tracked as
subkernels (orphans), and the number of tasks. `"ChildKernels"` is `Missing["RunProcessUnavailable"]` in MCP Local. A
kernel just closed can still be listed as a child for a moment.
```wl
KeyTake[WolframDebugging`KernelReport[], {"Kernels", "ChildKernels", "Tasks"}]
(* <|"Kernels" -> {}, "ChildKernels" -> {}, "Tasks" -> 0|> *)
```
With one subkernel (wolframscript): `<|"Kernels" -> {"Local (1) id=1"}, "SubkernelPIDs" -> {4243}|>`.

### `TaskReport[]`
`<|"Count", "Tasks" -> {<|"UUID", "Status", "Type", "Expression", "Runs"|>, ...}|>` (first 25), e.g.
`<|"Count" -> 0, "Tasks" -> {}|>`. In MCP Local, `Tasks[]` includes other sessions' tasks: remove only your own.

### `SubmitAndWait[expr, timeout]`
Runs `expr` as a `SessionSubmit` task under `$CaptureFunction`, waits at most `timeout` (10) seconds, removes the task
and returns the capture record plus `"Wait"` (`"Finished"` | `"TimedOut"`).
```wl
KeyTake[WolframDebugging`SubmitAndWait[1/0; 5], {"ResultString", "Messages", "Wait"}]
(* <|"ResultString" -> "5", "Messages" -> {"Power::infy: Infinite expression 0^(-1) encountered."}, "Wait" -> "Finished"|> *)
```

## Cloud and HTTP

### `HTTPSummary[response, opts]`
`<|"StatusCode", "ContentType", "Text"|>` of an `HTTPResponse` or a `URLRead[..., {"StatusCode", "Headers", "Body"}]`
association (HTML reduced to visible text, JSON compacted); `<|"Failure", "Text", "URL"|>` for a `Failure`. `"MaxLength"` (300).
```wl
WolframDebugging`HTTPSummary[HTTPResponse["<html><body>Not <b>found</b></body></html>", <|"StatusCode" -> 404, "ContentType" -> "text/html"|>]]
(* <|"StatusCode" -> 404, "ContentType" -> "text/html;charset=utf-8", "Text" -> "Not found"|> *)
```

### `DebugHTTPResponse[deployable, request, opts]`
Runs `GenerateHTTPResponse` locally (where messages, handlers and stacks work) and returns the response summary,
`"Seconds"`, `"MessageCount"`, `"Messages"` and `"FirstMessageStack"` (from the first user-code frame on). `request`: an
`HTTPRequest`, a URL, or an association/list of parameters. Options: `"Method"` ("GET"; "POST" sends the parameters as a
form body); `"MaxMessages"` (10); `"StackFrames"` (8); `"StringLength"` (200); `"MaxLength"` (300); `"SuppressPrinting"`
(True).
```wl
api = APIFunction[{"a" -> "Integer", "b" -> "Integer"}, myFn[#a, #b] &];
KeyTake[WolframDebugging`DebugHTTPResponse[api, <|"a" -> "-1", "b" -> "1"|>], {"StatusCode", "Text", "MessageCount", "FirstMessageStack"}]
(* <|"StatusCode" -> 200, "Text" -> "{-1, ComplexInfinity, 1}", "MessageCount" -> 1,
     "FirstMessageStack" -> {"myFn[-1, 1]", "Table[otherFn[i], {i, -1, 1}]", "otherFn[i]", "1/0", "0^(-1)"}|> *)
```
`deployable`: an `APIFunction`, a `FormFunction` (`"Method" -> "POST"` to submit it) or a `Delayed`.
`GenerateHTTPResponse` runs the body under `EvaluationData`, which catches every `Throw` (status 500 with
`Throw::nocatch`): the collector only records.

### `HTTPDiagnostics[expr, opts]`
The body wrapper for deployed code:
``APIFunction[{...}, WolframDebugging`HTTPDiagnostics[myFn[#a, #b], "TimeLimit" -> 250] &]`` (load the package before
`CloudDeploy`). Returns the value of `expr` unchanged, or a JSON `HTTPResponse`: `"Success"`, `"Reason"` (`"Messages"`,
`"UncaughtThrow"`, `"Aborted"`, `"TimedOut"`, `"FailureResult"`, `"DebugRequested"`), `"Result"`, `"Messages"`,
`"Output"` (Print text), `"Stack"` (at the first message, or the last sample on a time-out), `"Seconds"`,
`"Environment"`, `"Request"`. Options: `"Debug"` (Automatic: on for `debug=1`/`true`/`yes`); `"DebugParameter"`
("debug"); `"FailOnMessages"` (True); `"TimeLimit"` (None | seconds below the 300 s limit); `"StatusCode"` (500);
`"StackFrames"` (8); `"MaxMessages"` (10); `"StringLength"` (200); `"MaxPrints"` (10); `"Log"` (None |
`CloudObject`/file: `PutAppend`, read with `ReadList`).
```wl
WolframDebugging`HTTPSummary[WolframDebugging`HTTPDiagnostics[myFn[-1, 1]], "MaxLength" -> 150]
(* <|"StatusCode" -> 500, "ContentType" -> "application/json", "Text" -> "{\"Success\":false,\"Reason\":\"Messages\",
     \"Result\":\"{-1, ComplexInfinity, 1}\",\"Messages\":[{\"Message\":\"Power::infy\",\"Text\":\"Power::infy: Infinite express..."|> *)
```
Deployed (`"WebAPI"`), `a=-1, b=1` answered 500 with `"Stack":["myFn[-1, 1]",...,"0^(-1)"]`, an endless loop with a 5 s
`"TimeLimit"` answered `"Reason":"TimedOut"` with the sampled stack, and `debug=1` answered 200 with `"DebugRequested"`;
as the body of a deployed `Delayed` or `FormFunction` it answered the same 500 report.

### `WithHTTPLog[expr, opts]`
Every HTTP request made through `URLFetch` (`URLRead`, `URLExecute`, `CloudGet`, `CloudPut`, ...) or `URLSave` (`Import`
of a URL, `URLDownload`): function, method, URL, status, seconds. Shows the 404 that `URLExecute` hid. Options:
`"MaxRequests"` (50); `"URLLength"` (120); `"MaxResultBytes"`. Returns `<|"Result", "RequestCount", "Requests"|>`.
```wl
WolframDebugging`WithHTTPLog[Quiet[URLRead["http://127.0.0.1:1/x", TimeConstraint -> 5]]]["Requests"]
(* {<|"Function" -> "URLFetch", "Method" -> "GET", "URL" -> "http://127.0.0.1:1/x", "Status" -> $Failed, "Seconds" -> 0.065|>} *)
```

## Headless and Environments

### `EnvironmentFingerprint[]`, `EnvironmentFingerprint[keys, opts]`, `EnvironmentFingerprint[All, opts]`
The kernel described compactly: `"Kind"`, `"Version"`, `"CommandLineFlags"`, `"ProtectedMode"`, `"FrontEnd"`,
`"InitFiles"`, `"ContextPath"`, `"PathExtras"`, `"Directories"`, `"Encoding"`, `"Locale"`, `"Persistence"`, `"Limits"`,
`"Hooks"`, `"Handlers"`, `"OffGeneralMessages"`, `"OptionsHash"`, `"TraceWorks"`, `"Paclets"` (option), ... (`All` adds the
slow `"CloudConnected"`). `Put` one in environment A, compare in B with `FingerprintDiff[Get[file], ...]`.
```wl
fp = WolframDebugging`EnvironmentFingerprint[];
KeyTake[fp, {"Kind", "CommandLineFlags", "TraceWorks", "Handlers"}]
(* <|"Kind" -> "wolframscript", "CommandLineFlags" -> {"-runfirst", "-linkmode", "-linkname", "-mathlink"}, "TraceWorks" -> True,
     "Handlers" -> <|"MessageTextFilter" -> 1|>|> *)
```
MCP Local adds `"VetoableValueChange"`, `"GetFileEvent"` and `"Message"` handlers (one each).

### `FingerprintDiff[fpA, fpB, ignore]`
The nested keys (`"Limits/RecursionLimit"`) whose values differ: `{valueA, valueB}`, or `<|"OnlyInA", "OnlyInB"|>` for
lists. `ignore` defaults to the volatile keys (`"ProcessID"`, `"SessionTime"`, `"MemoryMB"`, `"TimeRemaining"`, ...).
```wl
WolframDebugging`FingerprintDiff[fp, Append[fp, "TraceWorks" -> ! fp["TraceWorks"]]]
(* <|"TraceWorks" -> {True, False}|> *)
```

### `FrontEndCalls[expr, timeout]`
Counts the front end requests `expr` makes (every request goes through ``MathLink`CallFrontEnd``), the front end
messages, and whether a headless front end was launched. `timeout` defaults to 60 s (below the remaining tool time).
```wl
Quiet[WolframDebugging`FrontEndCalls[NotebookDirectory[]]]
(* <|"Result" -> "$Failed", "FrontEndCalls" -> <|"FrontEnd`EvaluationNotebook" -> 1|>,
     "FrontEndMessages" -> {"FrontEndObject::notavail (quiet)"}, "LaunchedFrontEnd" -> False, "Seconds" -> 0.|> *)
```

### `RunIsolated["code" or File[path], opts]`
Runs code in a fresh wolframscript kernel with a hard kill time limit (`timeout -s KILL`) in a private working
directory, kills leftover kernels and their children afterwards, and returns `"ExitCode"`, `"Status"` (`"OK"`,
`"TimedOut"`, `"Killed"`, `"Crashed"` for exit codes above 128, `"Failed"`), `"Seconds"`, the tails of
`"StdOut"`/`"StdErr"` and `"KilledLeftovers"`. Options: `"TimeLimit"` (60); `"MaxOutput"` (2000 characters);
`"Executable"` (Automatic). Needs `RunProcess` and the `timeout` command (tested on Linux):
`Failure["ProtectedMode", ...]` in MCP Local.
```wl
WolframDebugging`RunIsolated["Print[1 + 1]", "TimeLimit" -> 60]
(* <|"ExitCode" -> 0, "Status" -> "OK", "Seconds" -> 6.2, "StdOut" -> "2\n", "StdErr" -> "", "KilledLeftovers" -> {}|> *)
```

## Static Checks

### `LintSummary["code" or File[path], minConfidence]`
One line per CodeInspector issue with confidence `minConfidence` (0.5) or more, formatting and remarks excluded, first
50: `"L<line>:<column> Tag (Severity confidence) description"`, or `"No issues."`.
```wl
WolframDebugging`LintSummary["f[x_] := If[x = 1, {1,2,}, x]"]
(* "L1:13 IfSet (Warning 0.85) `If` has `Set` as first argument.\nL1:25 Comma (Error 1.) Extra `,`." *)
```
