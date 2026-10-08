# Tracing and performance

How to use `Trace`, `TraceScan` and their options without drowning in output, what to do where `Trace` is disabled
(MCP Session, the cloud), how to find where the time goes and where an evaluation is stuck with a stack
sampler, and what time limits can and cannot interrupt. Read it for "which code path ran", "why is this slow" and
"why does this hang or time out". Behavior was checked with Wolfram 15.0 in the environments named in `Environments.md`.

The examples use these definitions:

```wl
ClearAll[fib, hlp];
hlp[x_] := x^2;
fib[0] = 0; fib[1] = 1; fib[n_] := fib[n - 1] + hlp[fib[n - 2]];
```

## Which tool for which question

| question | first choice | works where Trace is disabled |
|---|---|---|
| which calls of `f` happened, with which arguments? | `Trace[expr, _f]`; rule form with early exit; ``WolframDebugging`TraceCalls[expr, _f, n]`` | no: use an ``Internal`InheritedBlock`` spy (`OverridesAndWatchpoints.md`) |
| how often is each function called? | `Counts` over `Trace[expr, _f \| _g]`; ``WolframDebugging`CountCalls[expr, _f \| _g]`` | ``WolframDebugging`TimeCalls[expr, {f, g}]`` |
| what does a system function call internally? | `Trace[expr, form, TraceInternal -> True]` | spy on the internal function |
| where does the time go? | stack sampler; ``WolframDebugging`SampleStacks[expr, maxSeconds]`` | yes |
| exact count and time per function | ``WolframDebugging`TimeCalls[expr, {f, g}]`` | yes |
| where is it stuck? | stack sampler (last samples); ``WolframDebugging`FindHang[expr, maxSteps]`` (Trace only) | sampler: yes |
| why is this numeric solver slow or diverging? | `EvaluationMonitor`, `StepMonitor` | yes |
| why did the call time out? | "Time limits" below | yes |

Helpers are in `scripts/WolframDebugging.wl` (load it with `Get` in its own call, call them fully qualified; options and
outputs: `HelperFunctions.md`). Every recipe below works without them.

## Is Trace available here?

```wl
{Trace[1 + 2*3], CloudEvaluate[Trace[1 + 2*3]]}
(* {{{HoldCompleteForm[2*3], HoldCompleteForm[6]}, HoldCompleteForm[1 + 6], HoldCompleteForm[7]}, {}} *)
```

`Trace`, `TraceScan`, `TracePrint` and `On[sym]` work in MCP Local and wolframscript (notebooks: not checked here). They
silently record nothing in **MCP Session (the default method of installed local servers)**, `wolfram -script`, CloudEvaluate, deployed
APIs and the remote MCP server: `Trace` returns `{}` and the `TraceScan` function is never called, so a `TraceScan`
step limiter never fires and an infinite loop runs into the tool's time limit. Check with `Trace[1 + 1] =!= {}`
(``WolframDebugging`TraceAvailableQ[]``) before relying on it. Where it is `{}`, use the workarounds below or the
Trace-free tools: message handlers with `Stack` (`MessagesAndStacks.md`), ``Internal`InheritedBlock`` spies and value
monitors (`OverridesAndWatchpoints.md`), and the stack sampler (below). (CloudEvaluate also works from MCP Local.)

## Trace forms

Each item of a trace is wrapped in `HoldCompleteForm` in 15.0 (older versions: `HoldForm`). Match items with `_[e_]`
or `(HoldCompleteForm | HoldForm)[e_]`; never unwrap them with `First`, `[[1]]` or `ReleaseHold`, which re-evaluates
the item. Outputs in this section drop the wrappers for readability:

```wl
Trace[fib[3], _fib]                    (* calls that match, arguments already evaluated *)
Trace[fib[2], fib]                     (* bare symbol: each rewrite done by fib's own rules *)
Trace[fib[3], hlp[x_] :> {"arg", x}]   (* rule: the rhs is evaluated at each match and replaces the item *)
Trace[fib[3], TraceDepth -> 1]         (* only the top-level rewrite chain *)
(* {fib[3], {fib[2], {fib[1]}, {{fib[0]}}}, {{fib[1]}}}
   {fib[2], fib[2 - 1] + hlp[fib[2 - 2]], {fib[1], 1}, {{fib[0], 0}}}
   {{{{"arg", 0}}}, {{"arg", 1}}}
   {fib[3], fib[3 - 1] + hlp[fib[3 - 2]], 1 + 1, 2} *)
```

- `Flatten[Trace[...]]` gives the items in chronological order (`Flatten` does not enter `HoldCompleteForm`).
- A bare symbol `f` as the form means "rewrites done by f's rules", `_f` means "expressions with head f".
- In the rule form `lhs :> rhs` the rhs is evaluated at every match: use it as a callback (next section).

### Options

```wl
Trace[fib[3], _hlp, TraceAbove -> True]       (* who called it: the enclosing evaluation chains *)
Trace[fib[3], _hlp, TraceForward -> True]     (* what each match evaluated to *)
Trace[fib[3], _Power, TraceBackward -> All]   (* what produced each match *)
Trace[fib[2], _fib, TraceOriginal -> True]    (* also the forms before their arguments were evaluated *)
Trace[fib[3], TraceOn -> _hlp]                (* trace only inside hlp[...] evaluations *)
Trace[(1 + 1) + fib[3], TraceOff -> _fib]     (* do not trace inside fib[...] evaluations *)
(* {fib[3], {fib[2], {hlp[0], 0}, 1}, {hlp[1], 1}, 2}
   {{{hlp[0], 0}}, {hlp[1], 1}}
   {{{hlp[0], 0^2}}, {hlp[1], 1^2}}
   {fib[2], {fib[2 - 1], fib[1]}, {{fib[2 - 2], fib[0]}}}
   {{{hlp[0], 0^2, 0}}, {hlp[1], 1^2, 1}}
   {{1 + 1, 2}, {fib[3], 2}, 2 + 2, 4} *)
```

`TraceForward -> All` and `TraceBackward -> True` also exist; `MatchLocalNames -> False` stops a form `x` from
matching Module locals `x$123`. `TraceOff` also makes a trace faster (it skips the subcomputations), `TraceDepth -> 1`
is the cheapest "what did it rewrite to".

### `TraceInternal -> True`: see inside system functions

```wl
ClearAll[key]; key[x_] := -x;
{Length[Flatten[Trace[SortBy[{3, 1, 2}, key], _key]]], Length[Flatten[Trace[SortBy[{3, 1, 2}, key], _key, TraceInternal -> True]]]}
Trace[URLParse["http://a.com/b?q=1"], _URLQueryDecode, TraceInternal -> True]
(* {0, 3}
   {{{{{{{{{HoldCompleteForm[URLQueryDecode["q=1"]], {HoldCompleteForm[URLQueryDecode[{"q=1"}]]}}}}}}}}}}   (the default finds nothing) *)
```

Without it, a trace does not show evaluations made by kernel code on your behalf: the key functions of `SortBy`,
`GatherBy`, `MaximalBy`, `AssociationMap`, `Plot` sample points, callbacks of compiled code, and helpers that system
packages (URLParse, DateString, ...) call internally. Calls made by `Map`, `Select`, `Table`, `Fold`, `Nest`,
`GroupBy`, `Cases` conditions, `Dataset` queries and `NIntegrate` (sample points of a `_?NumericQ` integrand) are
visible by default. With `TraceInternal -> True` an internal call can appear twice (before and after its arguments were
evaluated); use a form like `f[_String, ___]` to keep only evaluated calls.

Find the HTTP requests made by a high-level function (network access):

```wl
Cases[Flatten[Trace[ResourceUpdate["Gettysburg Address"], _URLFetch | _URLRead, TraceInternal -> True]],
  _[(h : URLFetch | URLRead)[u_, ___]] :> ToString[Unevaluated[h[u]], InputForm]]
(* ResourceObject::newest: The most recent version of resource ... is already downloaded.
   {"URLFetch[\"https://www.wolframcloud.com/obj/resourcesystem/api/1.0/AcquireResource\"]", (the same again)}
   MCP Local shows URLFetch[CloudObject["https://.../AcquireResource"]] *)
```

Here the default `TraceInternal -> Automatic` finds the same two items (the request is made by top-level package code),
but `TraceInternal -> True` is the safe choice when you trace into system functions. The spy in
`OverridesAndWatchpoints.md` finds the same requests where Trace is disabled.

## Streaming traces: stop early, count, keep the output small

The rule form is a callback that runs at each match; a `Throw` from it stops the evaluation. This collects the first
five calls of `hlp` as strings and stops:

```wl
Module[{bag = Internal`Bag[], k = 0, tag},
  Catch[
    Trace[fib[10], e : _hlp :> (Internal`StuffBag[bag, ToString[Unevaluated[e], InputForm]]; If[++k >= 5, Throw[Null, tag]])],
    tag];
  Internal`BagPart[bag, All]]
(* {"hlp[0]", "hlp[1]", "hlp[0]", "hlp[1]", "hlp[0]"}     MCP Local with bug #249: {"Global`hlp[0]", ...} *)
```

Count calls per function:

```wl
Counts[Cases[Flatten[Trace[fib[10], _fib | _hlp]], _[h_Symbol[___]] :> SymbolName[Unevaluated[h]]]]
{Block[{c = 0}, TraceScan[c++ &, fib[10], _fib]; c], Block[{c = 0}, TraceScan[c++ &, fib[10], fib[_Integer]]; c]}
(* <|"fib" -> 177, "hlp" -> 88|>
   {353, 177} *)
```

`TraceScan` (and `TracePrint`) report each call twice, before and after its arguments are evaluated (`fib[10 - 1]` and
`fib[9]`): count with `Trace`, or use a pattern such as `fib[_Integer]` that only matches evaluated arguments. A pattern
test does not help, because it evaluates its argument: `fib[_?NumberQ]` matches `fib[10 - 1]` too (353 again).
``WolframDebugging`TraceCalls[expr, form, n]`` and ``WolframDebugging`CountCalls[expr, form]`` do both (they return
`Failure["TraceUnavailable", ...]` where Trace is disabled).

Collect with ``Internal`Bag`` and a Module-local tag, not with `Sow` or a plain tag:

```wl
ClearAll[usesReap, catchesAll];
usesReap[] := First[Reap[hlp[3]; 7]];
catchesAll[] := Catch[hlp[3]; "finished anyway", _];
{Reap[TraceScan[Sow[#, "mine"] &, usesReap[], _hlp], "mine"],
 Module[{bag = Internal`Bag[]}, TraceScan[Internal`StuffBag[bag, #] &, usesReap[], _hlp]; Internal`BagPart[bag, All]],
 Catch[Trace[catchesAll[], _hlp :> Throw["found", "mine"]], "mine"],
 CheckAbort[TraceScan[Abort[] &, catchesAll[], _hlp], "stopped by Abort"]}
(* {{7, {}}, {HoldCompleteForm[hlp[3]]}, {}, "stopped by Abort"} *)
```

- An untagged `Reap` inside the traced code swallows your `Sow`, even a tagged one (`{7, {}}`); the bag sees the call.
- A `Catch[..., _]` (or `CheckAll`, `EvaluationData`) inside the traced code eats your `Throw`: the evaluation goes on
  and you get its normal result (`{}` here). Real package code contains such catch-alls. Record without throwing, or
  stop with `Abort[]` inside `CheckAbort`.
- Never return a raw trace or stack: a few hundred items are tens of kilobytes. `Short` does not shorten anything in MCP
  or wolframscript output; convert items with `ToString[Unevaluated[e], InputForm, TotalWidth -> n]` (see "Output budget"
  in `Environments.md`). Symbols whose context is not on `$ContextPath` print with it (in
  MCP Local with bug #249 typed symbols print as ``Global`f``): put ``"Global`"`` and `$Context` on `$ContextPath` while
  formatting (the hang locator below does).

## What Trace cannot show, and what it costs

- Built-in functions show only input and result (`Trace[Sort[{3, 1, 2}]]` has two items).
- Compiled code shows no inner steps, and the whole `CompiledFunction` or `CompiledCodeFunction` expression appears in
  the trace (large).
- `ReadProtected` does not hide anything from Trace, but functions that are both `Locked` and `ReadProtected` are opaque,
  even with `TraceInternal -> True`.
- The first call of a function in a fresh kernel traces all the package loading it triggers: one
  `Trace[ExportString[<|"a" -> 1|>, "JSON"]]` in a fresh wolframscript kernel had 15,467 items (118 MB), the second
  995 items. Evaluate once before tracing unless the loading is what you investigate.
- Cost (`fib[20]` in wolframscript): `Trace` with a narrow form took about 3.5 times the plain time, `TraceScan` about
  7 times (it streams, so memory stays flat: 7.5 KB); a full `Trace` (about 33,000 calls) kept 17 MB. Narrow the form,
  use `TraceOff`, and stop early.
- `TracePrint` prints one line per item (a lot of output); `TraceDialog` enters a `Dialog[]`: never use it in MCP.
- The MCP evaluator's own code does not appear in traces made in MCP Local.

## Where Trace is disabled: three workarounds

1. A fresh local kernel with your definitions transferred (MCP Session, about 9 s; not available in MCP Local, which
   is protected mode, or in the cloud):

```wl
ClearAll[sq]; sq[x_] := x^2 + 1;
With[{defs = Language`ExtendedFullDefinition[sq]},
  LocalEvaluate[Language`ExtendedFullDefinition[] = defs; ToString[Trace[sq[2]], InputForm]]]
(* "{HoldCompleteForm[sq[2]], HoldCompleteForm[2^2 + 1], {HoldCompleteForm[2^2], HoldCompleteForm[4]}, HoldCompleteForm[4 + 1], HoldCompleteForm[5]}" *)
```

``Language`ExtendedFullDefinition`` includes the definitions `sq` depends on, including package contexts, but silently
drops `ReadProtected` symbols. For package code, `Get` the package inside the `LocalEvaluate` instead.

2. A parallel subkernel traces even when the main kernel cannot (MCP Session; the call took about 9 s):

```wl
ClearAll[sq]; sq[x_] := x^2 + 1;
Module[{k = LaunchKernels[1]},
  WithCleanup[DistributeDefinitions[sq]; First[ParallelEvaluate[ToString[Trace[sq[2]], InputForm], k]], CloseKernels[k]]]
(* "{HoldCompleteForm[Sessions`<id>`sq[2]], HoldCompleteForm[2^2 + 1], ..., HoldCompleteForm[5]}" *)
```

3. Run the code in wolframscript from the shell (each run is a fresh kernel; see `Environments.md`):

```bash
cat > "${TMPDIR:-/tmp}/trace_me.wls" <<'WL'
sq[x_] := x^2 + 1;
Print[ToString[Trace[sq[2]], InputForm]]
WL
timeout -s KILL 120 wolframscript -f "${TMPDIR:-/tmp}/trace_me.wls"
# {HoldCompleteForm[sq[2]], HoldCompleteForm[2^2 + 1], {HoldCompleteForm[2^2], HoldCompleteForm[4]}, HoldCompleteForm[4 + 1], HoldCompleteForm[5]}
```

## Where does the time go?

Quick measurements:

```wl
{AbsoluteTiming[Pause[0.2]], Timing[Pause[0.2]], MaxMemoryUsed[Range[10^6];]}
EchoTiming[Pause[0.2]; 7]
GeneralUtilities`EchoPerformance[Total[Range[10^6]]]
(* {{0.200249, Null}, {0.003324, Null}, 8000264}
   >> 0.201199                              (prints, returns 7)
   >> Total {0.001908 s, 8000760 B}         (prints, returns 500000500000) *)
```

`Timing` is the CPU time of this kernel only (it excludes `Pause`, waiting for the network and other processes): use
`AbsoluteTiming` for wall-clock time and `RepeatedTiming` for short operations. Headless, `Monitor` only issues
`FrontEndObject::notavail`, `PrintTemporary` prints like `Print`, and ``GeneralUtilities`MonitoredMap`` prints raw box
junk: return measurements as values instead.

### Sampling profiler (works everywhere)

A repeating `ScheduledTask` preempts the running evaluation and `Stack[_]` evaluated in the task sees the main
evaluation's stack. The share of samples in which a function is on the stack is its share of the (inclusive) time:

```wl
ClearAll[slowA, slowB, driver];
slowA[n_] := Module[{s = 0.}, Do[s += Sin[N[i]]^2, {i, n}]; s];
slowB[n_] := Module[{s = 0.}, Do[s += Cos[N[i]], {i, n}]; s];
driver[k_] := Table[slowA[60000] + slowB[20000], {k}];
Module[{bag = Internal`Bag[], task, samples},
  task = SessionSubmit[ScheduledTask[Internal`StuffBag[bag, Stack[_]], {0.01, 2000}]];
  TimeConstrained[StackBegin[StackComplete[driver[5]]], 10];
  Quiet[TaskRemove[task]];
  samples = Internal`BagPart[bag, All];
  {Length[samples], Round[100. Counts[Flatten[Union[Cases[#, _[h_Symbol[___]] /; MemberQ[{"Global`", $Context}, Context[h]] :>
      SymbolName[Unevaluated[h]], {1}]] & /@ samples]] / Length[samples]]}]
(* wolframscript: {56, <|"driver" -> 100, "slowA" -> 82, "slowB" -> 18|>}
   MCP Local:     {82, <|"driver" -> 100, "slowA" -> 80, "slowB" -> 20|>} *)
```

- `StackComplete` is required: without it every call of your functions is replaced on the stack by its right-hand
  side (`driver[5]` by `Table[...]`) and never shows up. `StackBegin` drops the frames of the environment's wrapper code.
- The filter ``MemberQ[{"Global`", $Context}, Context[h]]`` keeps your own functions in every environment (typed code is
  in ``Sessions`<id>` `` in the MCP evaluator, but in ``Global` `` in wolframscript and in MCP Local with bug #249); use a
  package context to profile a package.
- Always give the task a repetition count and remove it: if the MCP tool limit fires first, the `TaskRemove` never runs,
  and in MCP Session a leftover task keeps sampling the server's own stack during later calls.
- Return strings or counts, as above, never the samples: 50 samples of this profile were 370 KB.
- ``WolframDebugging`SampleStacks[expr, maxSeconds]`` adds the innermost function, builtin shares and the last frames;
  ``WolframDebugging`TimeCalls[expr, {f, g}]`` gives exact call counts and inclusive seconds per function (it wraps the
  functions with ``Internal`InheritedBlock``, so it works everywhere, but it misses calls answered by literal rules such as
  `fib[0] = 0`).

### Packed-array unpacking

```wl
GeneralUtilities`TraceUnpacking[Total[Append[RandomReal[1, 10^5], "a"]]]
(* <|HoldCompleteForm[{100000}] -> 1|>     dimensions of the arrays that were unpacked, and how often *)
```

It works everywhere (it uses a message handler with `On["Packing"]`, not Trace) and returns the statistics, not the
result. To find where an array is unpacked, record ``Developer`FromPackedArray::punpack1`` messages with their stacks
(`MessagesAndStacks.md`) inside `WithCleanup[On["Packing"], expr, Off["Packing"]]`.

### Profilers that do not work headless

``RuntimeTools`Profile`` and the other ``RuntimeTools` `` functions belong to the notebook debugger: headless they stay
unevaluated or return no data, and **``RuntimeTools`SetExecutionState[{"RuntimeAnalysisTools" -> True}]`` crashes the
kernel** (segmentation fault), as does ``Package`PackageInformation[]``. Never probe unknown internals in a shared MCP
kernel; try them in a throwaway wolframscript. For per-line profiles and coverage of a package's source, see
"Instrumentation" in `HeadlessAndCrashes.md`.

## Where is it stuck?

The same sampler locates a hang: run the code under an inner `TimeConstrained` and look at the last sample.

```wl
ClearAll[collatzLen];
collatzLen[n_] := Module[{k = 0, m = n}, While[m != 1, m = If[EvenQ[m], m/2, 3 m - 1]; k++]; k];   (* bug: 3 m - 1 *)
Module[{bag = Internal`Bag[], task, res},
  task = SessionSubmit[ScheduledTask[Internal`StuffBag[bag, Stack[_]], {0.2, 20}]];   (* ALWAYS bound the repeat count *)
  res = TimeConstrained[StackBegin[StackComplete[collatzLen[5]]], 2, $TimedOut];       (* stay below the tool limit *)
  Quiet[TaskRemove[task]];
  {res, Internal`BagLength[bag], Block[{$ContextPath = Join[{"Global`", $Context}, $ContextPath]},
    Replace[TakeWhile[Internal`BagPart[bag, -1], FreeQ[#, HoldPattern[bag]] &],
      _[e_] :> ToString[Unevaluated[e], InputForm, TotalWidth -> 70], {1}]]}]
(* {$TimedOut, 9, {"StackComplete[collatzLen[5]]", "collatzLen[5]", "Module[{k = 0, m = 5}, While[m != 1, m = <<1>>; k++]; k]",
    "While[m$16877 != 1, m$16877 = If[<<3>>]; k$16877++]; k$16877", ..., "m$16877 = If[EvenQ[m$16877], m$16877/2, 3*m$16877 - 1]", "5"}} *)
```

It gave the same answer in MCP Local, MCP Session, wolframscript, `wolfram -script`, CloudEvaluate and on the remote
MCP server, as did the profiler above. `TakeWhile[..., FreeQ[#, HoldPattern[bag]] &]` drops the task's own frames. If
only about one sample arrived during the whole wait, the code is inside a call that cannot be interrupted (see "Time
limits").
`TimeConstrained[expr, t, Stack[_]]` does not work: the fail expression runs after the stack has unwound.

Where Trace works, a step limiter shows the last evaluation steps, including live values:

```wl
Module[{steps = 0, last = Internal`Bag[], tag},
  If[Trace[1 + 1] === {}, "Trace is disabled here",
    Catch[
      TraceScan[
        Function[item, Internal`StuffBag[last, Replace[item, _[e_] :> ToString[Unevaluated[e], InputForm, TotalWidth -> 60]]];
          If[++steps >= 2000, Throw[Internal`BagPart[last, -4 ;; -1], tag]]],
        collatzLen[5], _[___]];
      "finished", tag]]]
(* {"m$16788 != 1", "7 != 1", "m$16788 = If[EvenQ[m$16788], <<2>>]; k$16788++", "m$16788 = If[EvenQ[m$16788], m$16788/2, 3*m$16788 - 1]"}
   MCP Session: "Trace is disabled here" *)
```

The guard matters: without it the step counter never fires where Trace is disabled and the loop runs into the tool
limit. ``WolframDebugging`FindHang[expr, maxSteps]`` keeps a ring buffer and also reports the stack heads.

Runaway recursion: `Block[{$RecursionLimit = 200, $IterationLimit = 1000}, expr]` fails fast instead of at depth 1024 or
4096 iterations; a stack at the `$RecursionLimit::reclim` message shows the recursion (`MessagesAndStacks.md`), and
`res = Catch[..., _TerminatedEvaluation, ...]; ...` contains the overflow (in the MCP evaluators a `Catch` that is the
whole input or a list element does not; `Environments.md`). `While`, `FixedPoint` and
`NestWhile` have no built-in limit: give them a maximum (`FixedPoint[f, x, 1000]`) or a `TimeConstrained`.

## Numeric solvers: monitors

```wl
Block[{x}, Catch[FindRoot[Exp[x] == 0, {x, 1}, EvaluationMonitor :> If[x < -20, Throw[{"diverging", x}, "fr"]]], "fr"]]
Block[{x, n = 0}, {NIntegrate[1/Sqrt[x], {x, 0, 1}, EvaluationMonitor :> n++], n}]
Block[{x}, Last[Reap[FindRoot[Cos[x] == x, {x, 1}, StepMonitor :> Sow[x]]]]]
(* {"diverging", -21.}
   {2.000000000000003, 131}
   {{0.7503638678402439, 0.7391128909113617, 0.739085133385284, 0.7390851332151607}} *)
```

`EvaluationMonitor` runs at every function evaluation, `StepMonitor` at every accepted step (FindRoot, FindMinimum,
NMinimize, NDSolve, NIntegrate, ...). Some methods have no monitor support (`NMinimize::noopmon`): choose an
iterative `Method`. Localize the variable: in MCP Local with bug #249 typed symbols live in a ``Global` `` shared by every
session, and another session had left `x = Range[500]` there, so an unlocalized `FindRoot[..., {x, 1}]` returned
`{{1, 2, ..., 500} -> 0.739...}`. Do not return `{x -> value}` from `Block[{x}, ...]`: the result is evaluated again
after `Block` restores the outer `x`.

## Time limits: what they can interrupt

```wl
With[{data = RandomReal[1, 2*10^7]},
  {AbsoluteTiming[TimeConstrained[Pause[5], 0.5, "stopped"]],
   AbsoluteTiming[TimeConstrained[Length[Sort[data]], 0.5, "stopped"]]}]
(* {{0.500411, "stopped"}, {1.697772, "stopped"}}     MCP Local: {{0.500776, "stopped"}, {2.45265, "stopped"}} *)
```

| `TimeConstrained` (and the MCP tool limit) | behavior |
|---|---|
| `Pause`, loops, waiting `URLRead`/`URLFetch`, `RunProcess` (the child is killed), `ReadLine` on a process | stopped on time |
| one long primitive (`Sort` of a huge list, `Eigenvalues` of 2500x2500: 8 s for a 2 s limit, `N[Pi, 10^7]`: 6.5 s for 1 s) | stopped only when it returns |
| `AbortProtect` and `WithCleanup` setup and cleanup code | finishes first, then the abort happens |
| `Run[...]`, a blocked stdin read (`InputString`) | runs to its end (`Run["sleep 3"]` under a 1 s limit: 3 s, normal result) |
| `MemoryConstrained[expr, bytes, fail]` | aborts after the allocation that crosses the limit (`Range[10^8]` under 1 MB still took 800 MB) |

`URLRead` and `URLFetch` have no default time-out. `10.255.255.1` below is an address that never answers:

```wl
{AbsoluteTiming[URLRead["http://10.255.255.1/", TimeConstraint -> 2]],
 AbsoluteTiming[TimeConstrained[URLRead["http://10.255.255.1/"], 2, $TimedOut]],
 AbsoluteTiming[TimeConstrained[URLRead["http://10.255.255.1/", TimeConstraint -> <|"Connecting" -> 1|>], 4, $TimedOut]],
 AbsoluteTiming[TimeConstrained[URLRead["http://10.255.255.1/", TimeConstraint -> <|"Connect" -> 1|>], 4, $TimedOut]]}
(* URLRead::invhttp: Connection timed out after 2000 milliseconds.
   URLRead::invhttp: Connection timed out after 1000 milliseconds.
   MCP Local: {{2.110298, Failure["ConnectionFailure", <|"MessageTemplate" :> URLRead::iurl, ...|>]}, {2.112629, $TimedOut},
               {1.111145, Failure["ConnectionFailure", ...]}, {4.115872, $TimedOut}} *)
```

The association form of `TimeConstraint` takes the keys `"Connecting"` and `"Reading"`; an unknown key such as
`"Connect"` is silently ignored (the outer limit stopped that call after 4 s). For `URLFetch` use
`"ConnectTimeout" -> 5, "ReadTimeout" -> 10`. wolframscript also prints `Connecting… | Elapsed time 1s` progress lines
while it waits. `Import` of a URL inside `TimeConstrained` turns the time-out into an abort of the whole evaluation
(a wolframscript script stops there); contain it with `CheckAbort`:

```wl
{CheckAbort[TimeConstrained[Import["http://10.255.255.1/", "String"], 2, $TimedOut], "aborted"], "next"}
(* {"aborted", "next"} *)
```

### The MCP tool time limit

```wl
{Internal`TimeRemaining[], TimeConstrained[Internal`TimeRemaining[], 5]}
(* MCP Local: {59.999937, 4.999999}   MCP Session: {59.999929, 4.999986}   wolframscript: {Infinity, 4.999999} *)
```

``Internal`TimeRemaining[]`` gives the seconds left of the innermost time limit, including the evaluator's (60 s by
default; the remote MCP server about 60 s, CloudEvaluate and deployed APIs 300 s). Wrap experiments in an inner
`TimeConstrained[expr, t, $TimedOut]` with `t` well below it, so that your own code returns the diagnostics:

- MCP Local: a normal time-out returns `Out[n]= Failure["EvaluationTimeExceeded", ...]` and keeps the session's state
  and the Print output so far. If the code is inside a call that cannot be interrupted, the subkernel is killed after
  about twice the limit and restarted (a 3 s limit returned after 19 s): the Failure then arrives **without** `Out[n]=`
  and all definitions (of every session) are gone. Check `{$ProcessID, SessionTime[]}` in the next call.
- MCP Session: the call returns only the Failure (all Print output of the call is lost), but state is kept; a call that
  cannot be interrupted (`Run["sleep 8"]` with a 5 s limit) blocks the server until it finishes, then returns the
  Failure.
- A `ScheduledTask` you started keeps running after a time-out; remove it (`TaskRemove`) or give it a repeat count.
- `TestReport` inside the evaluator: the evaluator's limit is absorbed by the test harness (an innocent test fails with
  `"EvaluationAbortedFailure"` in MCP Local, `"UncaughtThrowFailure"` in MCP Session) and the remaining tests run
  unbounded. Pass `TimeConstraint -> n` to `TestReport` (see `Testing.md`).

More on hard hangs, `Run` versus `RunProcess` and killing stuck wolframscript kernels: `HeadlessAndCrashes.md`.
