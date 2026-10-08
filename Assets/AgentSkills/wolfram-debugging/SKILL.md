---
name: wolfram-debugging
description: Verified Wolfram Language debugging recipes, tested helpers and undocumented internals (Internal`HandlerBlock, Stack with StackBegin and StackComplete, Internal`InheritedBlock, GetFileEvent, TraceLoading, TraceInternal) and how the Wolfram MCP evaluator, wolframscript, notebooks and the cloud differ. Use whenever Wolfram Language code issues messages, returns $Failed, Failure or unevaluated calls, fires the wrong rule, gives wrong results, is slow, hangs or crashes, or works in one environment but not another; to find where a message comes from or get a stack trace, call log, profile or watchpoint; to spy on, mock or override built-in or package functions; to read ReadProtected definitions or find source files; when edits have no effect or packages or paclets fail to load; and for failing VerificationTest/TestReport tests, parallel or async code, cloud deployments or HTTP requests. Load it even when Echo, Print and Trace seem enough, as Trace records nothing in the MCP evaluator's default mode or the cloud.
compatibility: Requires the Wolfram MCP server or wolframscript on PATH
metadata:
  author: Wolfram Research
  version: 2.2.17
---

# Wolfram Language Debugging

Verified techniques for finding out why Wolfram Language code misbehaves: messages and stack traces, unevaluated calls,
tracing, profiling and hangs, spies, mocks and overrides, watchpoints, definitions and source code, package loading,
tests, parallel and cloud code. Behavior was checked with Wolfram 15.0 in the Wolfram MCP evaluator (both evaluation
methods), wolframscript, `wolfram -script` and the Wolfram Cloud. Many standard techniques silently do nothing in some of
these environments, so read the ground rules below before you start.

## Prerequisites

You need a Wolfram kernel: the Wolfram MCP evaluator tool (for example `mcp__Wolfram__WolframLanguageEvaluator`) or
`wolframscript`. If neither is available, read `references/GetWolframEngine.md`; to set up the MCP server, read
`references/SetUpWolframMCPServer.md` (paths relative to this skill directory).

- **MCP evaluator** (preferred): a persistent kernel, so you can define things in one call and inspect them in the next.
- **wolframscript**: a fresh kernel per run, which is what you need to reproduce first-time effects (autoloading,
  package loading) or to run Trace where the MCP evaluator cannot. `wolframscript -f file.wl` prints only explicit `Print`
  output; `wolframscript -code '...'` prints the result without string quotes (use `ToString[expr, InputForm]`). Always
  bound runs: `timeout -s KILL 300 wolframscript -f file.wl < /dev/null`.

## Start here: where does the code run?

The same code behaves differently depending on where it runs. Check before you debug:

```wl
Module[{cl = StringRiffle[ToString /@ $CommandLine, " "]},
  <|"Env" -> Which[
      $EvaluationEnvironment === "Script", "wolframscript",
      $EvaluationEnvironment === "WebEvaluation", "CloudEvaluate",
      $EvaluationEnvironment === "WebAPI", "deployed API or remote MCP server",
      StringContainsQ[cl, "ChatbookSandbox"], "MCP Local",
      StringContainsQ[cl, "StartMCPServer"] || StringStartsQ[$Context, "Sessions`"], "MCP Session",
      MemberQ[$CommandLine, "-script"], "wolfram -script",
      True, $EvaluationEnvironment],
    "TraceWorks" -> Trace[1 + 1] =!= {}, "ProtectedMode" -> TrueQ[Developer`$ProtectedMode],
    "Context" -> $Context, "TimeRemaining" -> Internal`TimeRemaining[]|>]
(* <|"Env" -> "MCP Local", "TraceWorks" -> True, "ProtectedMode" -> True,
     "Context" -> "Sessions`<id>`", "TimeRemaining" -> 59.999771|> *)
```

| | MCP Local | MCP Session | wolframscript | cloud (CloudEvaluate, deployed APIs, remote MCP server) |
|---|---|---|---|---|
| `Trace`, `TraceScan`, `On[sym]` | work | **record nothing** | work | **record nothing** |
| symbols in typed code | ``Sessions`<id>` `` (``Global` `` with bug #249, see rule 3) | ``Sessions`<id>` `` | ``Global` `` | ``Global` `` |
| state between calls | persists in a subkernel shared by all sessions | persists inside the MCP server kernel | one run | none (fresh kernel per call) |
| `$MessageList` | reset per call | **never reset** | one evaluation per script | per call |
| `Print` output | lost on `Abort[]` | lost when the call times out | stdout | dropped (CloudEvaluate, deployed APIs); the remote MCP server drops `Echo` |
| `RunProcess`, `LaunchKernels` | blocked (protected mode) | allowed | allowed | blocked |
| file writes | only below `$TemporaryDirectory` | anywhere | anywhere | cloud user files (remote MCP server: a temporary directory) |

"MCP Local" and "MCP Session" are the two evaluation methods of the Wolfram MCP evaluator. Installed local servers use
Session by default: your code then runs inside the server's own kernel. `wolfram -script`, which the TestReport MCP tool
uses, also records no Trace. Details, and everything else that differs, are in `references/Environments.md`.

## Ground rules

1. **Check that Trace works before using it**: `Trace[1 + 1] =!= {}`. Where it does not, use Trace-free tools (message
   handlers with `Stack`, ``Internal`InheritedBlock`` spies, stack sampling) or run the Trace in wolframscript.
2. **Stack frames, trace items and kernel message arguments are wrapped in `HoldCompleteForm`** (in versions before 15,
   `HoldForm`). Match them with patterns such as `_[e_]` and convert with
   `ToString[Unevaluated[e], InputForm, TotalWidth -> 150]`. Never extract with `First`, `[[1]]` or `ReleaseHold`: that
   evaluates the frame again (side effects, repeated messages).
3. **Filter user frames with both user contexts**: ``MemberQ[{"Global`", $Context}, Context[s]]``. In the MCP evaluator
   typed code belongs to the session context ``Sessions`<id>` `` (`$Context`), but MCP Local servers affected by
   [AgentTools issue #249](https://github.com/WolframResearch/AgentTools/issues/249) parse it into ``Global` ``, which all
   sessions share (check with `{Context[mySym], $Context}`; details in `references/Environments.md`). The filter works in
   both cases.
4. **A tool call is parsed before it runs.** Put `Get`/`Needs` in its own call (or its own line of a `-f` script) and call
   package functions by their full names, such as ``WolframDebugging`CollectMessages[...]``.
5. **Use `StackBegin[StackComplete[expr]]`, in that order.** `StackBegin` removes the frames of the environment's own
   wrapper code (about 15 in wolframscript and 65 in CloudEvaluate); `StackComplete` keeps the frames of your calls,
   which are otherwise replaced on the stack by their right-hand sides (`myFn[-1, 1]` becomes `Table[...]`).
6. **Keep output small and return data as values.** Raw stacks, traces and `TestReportObject`s can be hundreds of KB.
   `Short` has no effect in the MCP evaluator or wolframscript. `Print` output can be lost when a call aborts or times
   out, so collect diagnostics with ``Internal`Bag``/``Internal`StuffBag`` and return them.
7. **Scope every change; MCP kernels are shared.** Use ``Internal`HandlerBlock`` (not ``Internal`AddHandler``),
   ``Internal`InheritedBlock``, `Block` and `WithCleanup`. Never call `Quit`, `Exit`, `Input`, `InputString`, `Dialog`,
   `ChoiceDialog` or `Run` in an MCP evaluator; never write to `"stdout"` or change `$RecursionLimit`, `$Pre`, `$Post`,
   `Off`, `SetOptions` globally there. In MCP Session such changes can silence or kill the MCP server itself.
8. **First-time effects need a fresh kernel.** MCP kernels have already loaded many packages; reproduce autoloading and
   loading problems in wolframscript.
9. **A `Throw`-based probe can be swallowed** by `Catch[..., _]` or `EvaluationData` inside the code under test. If your
   probe returns the function's normal result instead of your data, record without throwing.
10. **The remote MCP server evaluates every input inside `Quiet`.** Message handlers there see every message as quieted;
    wrap the code under test in `Quiet[expr, None, All]`.

## Symptom → first move → reference

| symptom | first move | read |
|---|---|---|
| messages: which one, from where? | ``WolframDebugging`CollectMessages[expr]`` or the stack-at-message recipe below | `MessagesAndStacks.md` |
| result contains unevaluated `f[...]`, or the wrong definition fires | ``WolframDebugging`StuckCalls[result]``, then ``WolframDebugging`WhyNoMatch[f[args]]`` | `UnevaluatedCalls.md` |
| `$Failed` or `Failure[...]` without explanation | ``WolframDebugging`CaptureEvaluation[expr]`` | `MessagesAndStacks.md` |
| slow, hangs, times out | ``WolframDebugging`SampleStacks[expr]`` (stack sampling; no Trace needed) | `TracingAndPerformance.md` |
| need the calls and arguments inside an evaluation | ``WolframDebugging`LogCalls[{f, g}, expr]``, `Trace` where it works | `TracingAndPerformance.md`, `OverridesAndWatchpoints.md` |
| mock, fake or temporarily replace a function (HTTP, time, randomness) | ``WolframDebugging`WithOverrides[{lhs :> rhs}, expr]`` | `OverridesAndWatchpoints.md` |
| a variable changes unexpectedly | ``WolframDebugging`WatchChanges[{x}, expr]`` | `OverridesAndWatchpoints.md` |
| where is this defined, what does the source look like? | SymbolDefinition MCP tool, ``WolframDebugging`FindSymbolSource["Ctx`name"]`` | `DefinitionsAndSource.md` |
| "my edit has no effect", symbol undefined after loading, what got loaded? | ``WolframDebugging`ContextSourceInfo["Ctx`"]``, ``WolframDebugging`LoadTrace[expr]`` | `PackageLoading.md` |
| a test fails, or a test file reports 0 tests | ``WolframDebugging`TestFailureSummary[report]``, ``WolframDebugging`CheckTestFile[file]`` | `Testing.md` |
| parallel results wrong or slow | ``WolframDebugging`ParallelCapture[f, list]`` | `ParallelAndAsync.md` |
| deployed API or HTTP request fails | `URLRead[req, {"StatusCode", "Headers", "Body"}]`, ``WolframDebugging`DebugHTTPResponse[api, params]`` | `CloudAndHTTP.md` |
| works in a notebook but not in MCP or wolframscript (or vice versa), crashes | ``WolframDebugging`EnvironmentInfo[]``, ``WolframDebugging`EnvironmentFingerprint[]`` | `Environments.md`, `HeadlessAndCrashes.md` |

All references are in `references/` relative to this skill directory.

## The helper package

`scripts/WolframDebugging.wl` (relative to this skill directory) packages the recipes of this skill as tested functions
with small, bounded results. Load it in its own call, then always call the functions by their full names:

```wl
Get["/absolute/path/to/wolfram-debugging/scripts/WolframDebugging.wl"]
```

```wl
WolframDebugging`CollectMessages[myFunction[-1, 1]]
```

The functions work in MCP Local, MCP Session, wolframscript and (for most of them) CloudEvaluate; Trace-based ones return
`Failure["TraceUnavailable", ...]` where Trace records nothing. The remote MCP server cannot load local files: use the
helper-free recipes there. All functions, options and example outputs are in `references/HelperFunctions.md`.

## Core recipes (no helper package needed)

The examples use these definitions:

```wl
otherFn[x_] := 1/x; myFn[a_, b_] := Table[otherFn[i], {i, a, b}]; suspectCode[] := Module[{k = 0}, While[True, k++]]
```

### Messages and the stack at the first message

A `"Message"` handler receives `Hold[Message[name, args...], willPrint]`; `willPrint` is `False` for quieted messages.
Throwing the stack from the handler gives the call chain that led to the message:

```wl
Module[{tag, st},
  st = Catch[Internal`HandlerBlock[{"Message", Replace[#, Hold[Message[_, ___], True] :> Throw[Stack[_], tag]] &},
         StackBegin[StackComplete[myFn[-1, 1]]]], tag];
  If[ListQ[st],
    Block[{$ContextPath = Join[{"Global`", $Context}, $ContextPath]},
      StringRiffle[Replace[Take[st, Position[st, _[_Message], {1}][[-1, 1]]],
        _[e_] :> ToString[Unevaluated[e], InputForm, TotalWidth -> 150], {1}], "\n"]],
    st]]   (* st is the normal result when no message was issued *)
```
```
StackComplete[myFn[-1, 1]]
myFn[-1, 1]
Table[otherFn[i], {i, -1, 1}]
otherFn[i]
1/0
0^(-1)
Message[Power::infy, HoldCompleteForm[0^(-1)]]
```

Use `Hold[Message[Power::infy, ___], True]` for one specific message; throw `Stack[]` instead of `Stack[_]` and return
`st` unformatted for function names only. Frames show expressions as they were pushed (`otherFn[i]`, not `otherFn[0]`).
On the remote MCP server, use `Hold[Message[_, ___], _]` (everything is quieted there). To collect all messages without
stopping, use ``WolframDebugging`CollectMessages`` or `EvaluationData[expr]["MessagesExpressions"]`.

### The stack when a function is called with particular arguments

Prepend a rule whose condition records the stack and then fails, so evaluation is unaffected:

```wl
Module[{bag = Internal`Bag[]},
  Internal`InheritedBlock[{otherFn},
    DownValues[otherFn] = Prepend[DownValues[otherFn],
      HoldPattern[otherFn[0]] /; (Internal`StuffBag[bag, Stack[]]; False) :> Null];
    Quiet @ StackBegin[StackComplete[myFn[-3, 3]]]];
  Internal`BagPart[bag, All]]   (* DownValues[otherFn] are restored when the block exits *)
(* {{StackComplete, myFn, Table, otherFn, CompoundExpression, Internal`StuffBag}} *)
```

Record `Stack[_]` instead for the expressions (format them as above). For System symbols, add `Unprotect[sym]` inside
the block. The helper ``WolframDebugging`StackAtCall[expr, otherFn[0]]`` does this and formats the frames.

### Why does `f[args]` stay unevaluated?

```wl
Keys @ DownValues[f]                                        (* the rules, in the order they are tried *)
Flatten @ Position[Keys @ DownValues[f], lhs_ /; MatchQ[Unevaluated @ f[20.], lhs], {1}, Heads -> False]
                                                            (* which left-hand sides match (conditions on the right-hand side are not checked) *)
{Context[f], Attributes[f]}                                 (* wrong context? Hold attributes? *)
Take[Select[Names["*`f"], ToExpression[#, InputForm, System`Private`HasAnyEvaluationsQ] &], UpTo[10]]
                                                            (* same name with definitions in other contexts (shadowing) *)
```

Common causes: `_Integer` given a Real, a condition or `PatternTest` that does not return exactly `True`, the wrong
number of arguments, `_List` given an Association, HoldAll with a typed pattern, a private package symbol called
unqualified, and memoized values from an old definition. ``WolframDebugging`WhyNoMatch[f[args]]`` explains each rule
without evaluating any rule body. The full catalog of causes is in `references/UnevaluatedCalls.md`.

### Where is slow or hanging code spending its time?

Stack sampling works in every environment, including those where Trace records nothing:

```wl
Module[{bag = Internal`Bag[], task, res},
  task = SessionSubmit[ScheduledTask[Internal`StuffBag[bag, Stack[_]], {0.25, 20}]];   (* always bound the count *)
  res = TimeConstrained[StackBegin[suspectCode[]], 4, $TimedOut];                     (* stay below the tool limit *)
  Quiet[TaskRemove[task]];
  {res, Block[{$ContextPath = Join[{"Global`", $Context}, $ContextPath]},
     Replace[TakeWhile[Internal`BagPart[bag, -1], FreeQ[#, HoldPattern[bag]] &],
       _[e_] :> ToString[Unevaluated[e], InputForm, TotalWidth -> 120], {1}]]}]
(* {$TimedOut, {"Module[{k = 0}, While[True, k++]]", "While[True, k$389372++]", ...}} *)
```

The last sample shows where the code was when time ran out. ``WolframDebugging`SampleStacks[expr]`` turns many samples
into a profile (percent of samples per function).

### Spy on, mock or override a function

``Internal`InheritedBlock`` keeps the existing definitions and attributes and restores them when the block exits, even on
abort:

```wl
Module[{calls = Internal`Bag[], inF = False, res},
  otherFn;                                          (* evaluate the symbol first: loads an autoload stub *)
  res = Internal`InheritedBlock[{otherFn},
    Unprotect[otherFn];
    PrependTo[DownValues[otherFn], HoldPattern[otherFn[args___] /; !inF] :>
      Block[{inF = True}, Internal`StuffBag[calls, HoldComplete[args]]; otherFn[args]]];
    Quiet @ myFn[-1, 1]];
  {res, Internal`BagPart[calls, All]}]
(* {{-1, ComplexInfinity, 1}, {HoldComplete[-1], HoldComplete[0], HoldComplete[1]}} *)
```

To mock, prepend `HoldPattern[lhs] :> fakeValue` instead. Always use `HoldPattern` and `:>`; guard recursion as shown.
Attributes such as `Temporary` or `Locked` set inside the block are permanent, so never set `Locked` in a shared kernel.
Calls made from inside kernel C code (`Total`, `Sum`, auto-compiled `Table`) and literal rules such as `f[0] = 1` are not
seen. HTTP requests from `URLRead`, `URLExecute` and `CloudGet` all go through `URLFetch`. Details in
`references/OverridesAndWatchpoints.md`.

### Read a ReadProtected definition and find the source file

Prefer the SymbolDefinition MCP tool when you have it. Otherwise:

```wl
CloudPut;   (* evaluating the symbol loads an autoload stub *)
Internal`InheritedBlock[{CloudPut}, ClearAttributes[CloudPut, ReadProtected];
  StringTake[ToString[Definition[CloudPut], InputForm], UpTo[2000]]]   (* ToString inside the block *)
```

Without the first line a fresh kernel shows only the stub (``CloudPut = Package`ActivateLoad[...]``). Some symbols are
kernel code (no Wolfram Language definitions). ``FindFile["CloudObject`"]`` gives the package file; search its paclet
directory, or use ``WolframDebugging`FindSymbolSource["CloudPut"]`` (the System symbol `CloudPut` is defined in
``CloudObject` `` files), which returns the files and line ranges of the definitions. See
`references/DefinitionsAndSource.md`.

### What did an evaluation load?

```wl
Module[{before = $LoadedFiles}, Needs["CodeParser`"]; Complement[$LoadedFiles, before]]
(* wolframscript: 48 files; MCP Local: {} (already loaded) *)
```

For the nesting of package loads use a `"GetFileEvent"` handler, and for autoloads ``GeneralUtilities`TraceLoading``:
see `references/PackageLoading.md`. Run this in a fresh kernel (wolframscript); MCP kernels have already loaded most
packages.

## References

| file | read when |
|---|---|
| `references/Environments.md` | behavior differs between the MCP evaluator, wolframscript, notebooks and the cloud; how to run code in each; safety rules for shared kernels |
| `references/MessagesAndStacks.md` | message handlers (`HandlerBlock`, `AddHandler`, `Message.Veto`, `MessageTextFilter`), `willPrint`, `$MessageList`, `Stack`, `StackBegin`, `StackComplete`, recursion and iteration limits, `Assert` |
| `references/UnevaluatedCalls.md` | a call stays unevaluated or the wrong rule fires |
| `references/TracingAndPerformance.md` | `Trace` options (`TraceInternal`, `TraceAbove`, `TraceForward`, `TraceOff`), Trace where it is disabled, profiling, hangs, time limits |
| `references/OverridesAndWatchpoints.md` | spies, mocks and overrides of built-in and package functions, call logging, watchpoints on variables |
| `references/DefinitionsAndSource.md` | definitions of built-in, ReadProtected and autoloaded symbols; finding and reading source files |
| `references/PackageLoading.md` | `GetFileEvent`, `TraceLoading`, `$LoadedFiles`, stale or shadowed code, paclet version precedence |
| `references/Testing.md` | failing `VerificationTest`/`TestReport` tests, tests skipped silently, reproducing one test |
| `references/ParallelAndAsync.md` | `ParallelMap`/subkernels, `SessionSubmit`, `ScheduledTask`, `URLSubmit` |
| `references/CloudAndHTTP.md` | `CloudEvaluate`, deployed `APIFunction`/`Delayed`/`FormFunction`, HTTP requests |
| `references/HeadlessAndCrashes.md` | notebook-only functions, startup differences, crashes, hard hangs, static checks |
| `references/HelperFunctions.md` | every function of the helper package |
