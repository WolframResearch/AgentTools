---
name: wolfram-debugging
description: Verified recipes and tested helpers for debugging Wolfram Language code. Use whenever code issues messages, returns $Failed, Failure or unevaluated calls, gives wrong results, is slow, hangs or crashes, or works in one environment but not another; for stack traces, call logs, profiles, mocks or overrides, watchpoints, ReadProtected definitions, edits that have no effect, failing tests, parallel, cloud or HTTP code. Use it even when Echo or Trace seem enough, as Trace records nothing in the MCP evaluator's default mode or the cloud.
compatibility: Requires the Wolfram MCP server or wolframscript on PATH
metadata:
  author: Wolfram Research
  version: 2.2.18
---

# Wolfram Language Debugging

Verified techniques for finding out why Wolfram Language code misbehaves, checked with Wolfram 15.0 in the MCP
evaluator (both methods), wolframscript, `wolfram -script` and the cloud. Many standard techniques silently do nothing
in some of these environments, so read the ground rules first. Paths are relative to this skill directory.

## Prerequisites

You need a Wolfram kernel. If you have neither of the following, read `references/GetWolframEngine.md`; to set up the
MCP server, read `references/SetUpWolframMCPServer.md`.

- **MCP evaluator** (preferred, for example `mcp__Wolfram__WolframLanguageEvaluator`): a persistent kernel, so
  definitions made in one call can be inspected in the next.
- **wolframscript**: a fresh kernel per run, needed for first-time effects (autoloading, package loading) and for Trace
  where the MCP evaluator cannot run it. `-f file.wl` prints only `Print` output; `-code '...'` drops string quotes
  (print `ToString[expr, InputForm]`). Always bound runs: `timeout -s KILL 300 wolframscript -f file.wl < /dev/null`.

## Start here: where does the code run?

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
    "TraceWorks" -> Trace[1 + 1] =!= {}, "Context" -> $Context, "TimeRemaining" -> Internal`TimeRemaining[]|>]
```

| | MCP Local | MCP Session | wolframscript | cloud |
|---|---|---|---|---|
| `Trace`, `TraceScan`, `On[sym]` | work | **record nothing** | work | **record nothing** |
| context of typed symbols | ``Sessions`<id>` `` | ``Sessions`<id>` `` | ``Global` `` | ``Global` `` |
| state between calls | persists in a subkernel shared by all sessions | persists in the MCP server's own kernel | none | none |
| `$MessageList` | reset per input | **never reset** | per script | per call |
| `Print`, `Echo` | shown | shown | stdout | dropped (the remote MCP server shows `Print` only) |
| `RunProcess`, `LaunchKernels` | blocked (protected mode) | allowed | allowed | blocked |
| file writes | only below `$TemporaryDirectory` | anywhere | anywhere | cloud files (remote MCP server: a throwaway directory) |

MCP Local and MCP Session are the two evaluation methods of the MCP evaluator; installed local servers use Session by
default. "Cloud" is CloudEvaluate, deployed APIs and the remote MCP server. `wolfram -script`, used by the TestReport
MCP tool, also records no Trace. Everything else that differs: `references/Environments.md`.

## Ground rules

1. **Check `Trace[1 + 1] =!= {}` before using Trace.** Where it records nothing, use message handlers with `Stack`,
   ``Internal`InheritedBlock`` spies or stack sampling, or run the Trace in wolframscript (more workarounds:
   `references/TracingAndPerformance.md`).
2. **Stack frames, trace items and arguments of kernel messages are wrapped in `HoldCompleteForm`** (`HoldForm` before
   version 15). Match them with `_[e_]` and format with `ToString[Unevaluated[e], InputForm, TotalWidth -> 150]`. Never
   extract them with `First`, `[[1]]` or `ReleaseHold`: that evaluates the frame again.
3. **Filter user frames with both user contexts**: ``MemberQ[{"Global`", $Context}, Context[s]]``.
4. **Each input is parsed just before it runs**, so a name in the same input as the `Get`/`Needs` that defines it is
   created in your own context. An input is one line in `-f` scripts and in the MCP evaluator with Chatbook 2.7.28+, but
   the whole call with older Chatbook. Put `Get`/`Needs` in its own call and call package functions by their full names.
5. **Evaluate code under test as `StackBegin[StackComplete[expr]]`.** `StackBegin` drops the environment's wrapper
   frames (about 15 in wolframscript, 65 in CloudEvaluate); `StackComplete` keeps your calls, which are otherwise
   replaced on the stack by their right-hand sides.
6. **Return small data as the value.** Raw stacks, traces and `TestReportObject`s can be hundreds of KB (`Short` has no
   effect in the MCP evaluator or wolframscript), and `Print` output can be lost: collect diagnostics with
   ``Internal`Bag``/``Internal`StuffBag`` and return them.
7. **Scope every change: MCP kernels are shared.** Use ``Internal`HandlerBlock`` (not ``Internal`AddHandler``),
   ``Internal`InheritedBlock``, `Block` and `WithCleanup`. In an MCP evaluator, never call `Quit`, `Exit`, `Input`,
   `InputString`, `Dialog`, `ChoiceDialog` or `Run`, write to `"stdout"`, or change `$RecursionLimit`, `$Pre`, `$Post`,
   `Off` or `SetOptions` globally; in MCP Session this can silence or kill the server. In MCP Local, lower
   `$RecursionLimit` (even in a `Block`) only after the subkernel has printed an ordinary message (`1/0;` in an earlier
   call): a first printed message under a low limit breaks `$Context` for every session.
8. **Reproduce autoloading and package-loading problems in wolframscript**: MCP kernels have many packages loaded.
9. **A `Throw`-based probe can be swallowed** by `Catch[..., _]` or `EvaluationData` in the code under test. If the
   probe returns the normal result instead of your data, record without throwing.
10. **The remote MCP server evaluates every input inside `Quiet`**, so handlers see every message as quieted: wrap the
    code under test in `Quiet[expr, None, All]`.

## Symptom → first move → reference

| symptom | first move | read in `references/` |
|---|---|---|
| messages (which, from where?), unexplained `$Failed` or `Failure` | ``WolframDebugging`CollectMessages[expr]``, ``WolframDebugging`CaptureEvaluation[expr]``, the recipe below | `MessagesAndStacks.md` |
| unevaluated `f[...]` in the result, or the wrong rule fires | ``WolframDebugging`StuckCalls[result]``, ``WolframDebugging`WhyNoMatch[f[args]]`` | `UnevaluatedCalls.md` |
| slow, hangs, times out; `Trace` options | ``WolframDebugging`SampleStacks[expr]``, ``WolframDebugging`TimeCalls[expr, {f, g}]`` (no Trace needed) | `TracingAndPerformance.md` |
| calls and arguments inside an evaluation; mocks (HTTP, time, randomness); a variable changes unexpectedly | ``WolframDebugging`LogCalls[{f, g}, expr]``, ``WolframDebugging`WithOverrides[{lhs :> rhs}, expr]``, ``WolframDebugging`WatchChanges[{x}, expr]`` | `OverridesAndWatchpoints.md` |
| definition or source file of a symbol | SymbolDefinition MCP tool, ``WolframDebugging`FindSymbolSource["Ctx`name"]`` | `DefinitionsAndSource.md` |
| edits have no effect, symbol undefined after loading, what got loaded? | ``WolframDebugging`ContextSourceInfo["Ctx`"]``, ``WolframDebugging`LoadTrace[expr]`` | `PackageLoading.md` |
| a test fails, or a test file reports 0 tests | ``WolframDebugging`TestFailureSummary[report]``, ``WolframDebugging`CheckTestFile[file]`` | `Testing.md` |
| parallel or asynchronous code misbehaves | ``WolframDebugging`ParallelCapture[f, list]`` | `ParallelAndAsync.md` |
| deployed API or HTTP request fails | `URLRead[req, {"StatusCode", "Headers", "Body"}]`, ``WolframDebugging`DebugHTTPResponse[api, params]`` | `CloudAndHTTP.md` |
| works in one environment but not another, notebook-only code, crashes | ``WolframDebugging`EnvironmentInfo[]``, ``WolframDebugging`EnvironmentFingerprint[]`` | `Environments.md`, `HeadlessAndCrashes.md` |

## The helper package

`scripts/WolframDebugging.wl` packages the recipes of this skill as tested functions with small, bounded results. Load
it in its own call (see rule 4), then call its functions by their full names:

```wl
Get["/absolute/path/to/wolfram-debugging/scripts/WolframDebugging.wl"]
WolframDebugging`CollectMessages[myFn[-1, 1]]   (* in a later call *)
```

The helpers work in MCP Local, MCP Session, wolframscript and (most of them) CloudEvaluate; Trace-based ones return
`Failure["TraceUnavailable", ...]` where Trace records nothing. The remote MCP server cannot load local files: use the
recipes below there. Every function, option and result shape is in `references/HelperFunctions.md`.

## Core recipes (no helper package needed)

The examples use these definitions:

```wl
otherFn[x_] := 1/x; myFn[a_, b_] := Table[otherFn[i], {i, a, b}]; suspectCode[] := Module[{k = 0}, While[True, k++]]
```

### The stack at the first message

A `"Message"` handler receives `Hold[Message[name, args...], willPrint]`, where `willPrint` is `False` for quieted
messages. Throwing the stack from the handler gives the call chain that led to the message:

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

Frames show expressions as they were pushed (`otherFn[i]`, not `otherFn[0]`). For function names only, throw `Stack[]`
instead of `Stack[_]` and return `st` unformatted. Match `Hold[Message[Power::infy, ___], True]` for one message, and
`Hold[Message[_, ___], _]` on the remote MCP server. To collect all messages without stopping, use
`EvaluationData[expr]["MessagesExpressions"]`.

### Spy on, mock or override a function

``Internal`InheritedBlock`` keeps the existing definitions and attributes and restores them when the block exits, even
on abort:

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

- To mock, prepend `HoldPattern[lhs] :> fakeValue` instead. Always use `HoldPattern` and `:>`; guard recursion as shown.
- For the stack when a function gets particular arguments, prepend a rule whose condition records the stack and fails,
  ``HoldPattern[otherFn[0]] /; (Internal`StuffBag[bag, Stack[]]; False) :> Null``, and run the code as
  `StackBegin[StackComplete[...]]` (helper: ``WolframDebugging`StackAtCall[expr, otherFn[0]]``).
- Some changes leak out of the block: `ClearAll`/`Remove` of the symbol wipes the outer definitions (use `Clear` or
  `DownValues[f] = {}`), and `Temporary` or `Locked` set inside stay set (never set `Locked` in a shared kernel).
- Calls made from kernel C code (`Total`, `Sum`, auto-compiled `Table`) and literal rules such as `f[0] = 1` are not
  seen. HTTP requests from `URLRead`, `URLExecute` and `CloudGet` all go through `URLFetch`.

### Why does `f[args]` stay unevaluated?

```wl
Keys @ DownValues[f]                (* the rules, in the order they are tried *)
Flatten @ Position[Keys @ DownValues[f], lhs_ /; MatchQ[Unevaluated @ f[20.], lhs], {1}, Heads -> False]
                                    (* which left-hand sides match (right-hand-side conditions are not checked) *)
{Context[f], Attributes[f]}         (* wrong context? Hold attributes? *)
Select[Names["*`f"], ToExpression[#, InputForm, System`Private`HasAnyEvaluationsQ] &]   (* shadowing contexts *)
```

Common causes: `_Integer` given a Real, a condition or `PatternTest` that does not return exactly `True`, the wrong
number of arguments, `_List` given an Association, HoldAll with a typed pattern, a private package symbol called
unqualified, and memoized values from an old definition.

### Where is slow or hanging code spending its time?

Stack sampling works in every environment, including those where Trace records nothing:

```wl
Module[{bag = Internal`Bag[], task, res},
  task = SessionSubmit[ScheduledTask[Internal`StuffBag[bag, Stack[_]], {0.25, 20}]];  (* always bound the count *)
  res = TimeConstrained[StackBegin[suspectCode[]], 4, $TimedOut];  (* stay below Internal`TimeRemaining[] *)
  Quiet[TaskRemove[task]];
  {res, Block[{$ContextPath = Join[{"Global`", $Context}, $ContextPath]},
     Replace[TakeWhile[Internal`BagPart[bag, -1], FreeQ[#, HoldPattern[bag]] &],
       _[e_] :> ToString[Unevaluated[e], InputForm, TotalWidth -> 120], {1}]]}]
(* {$TimedOut, {"Module[{k = 0}, While[True, k++]]", "While[True, k$389372++]", ...}} *)
```

The last sample shows where the code was when time ran out; ``WolframDebugging`SampleStacks`` turns many samples into a
profile.

### Read a ReadProtected definition

Prefer the SymbolDefinition MCP tool. Otherwise:

```wl
CloudPut;   (* evaluate the symbol first, or a fresh kernel shows only its autoload stub *)
Internal`InheritedBlock[{CloudPut}, ClearAttributes[CloudPut, ReadProtected];
  StringTake[ToString[Definition[CloudPut], InputForm], UpTo[2000]]]   (* ToString inside the block *)
```

Some symbols are kernel code without Wolfram Language definitions. For the source files and line ranges, use
``WolframDebugging`FindSymbolSource["CloudPut"]`` (System symbols are often defined in paclets, here ``CloudObject` ``).

To see what an evaluation loads, compare `$LoadedFiles` before and after it in a fresh kernel; nesting and autoloads are
in `references/PackageLoading.md`.
