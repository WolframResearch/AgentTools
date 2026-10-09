# Parallel subkernels and asynchronous tasks

Debugging `ParallelMap`/`ParallelTable`/`ParallelEvaluate` (definitions missing on subkernels, output and messages that
the master cannot see, aborts, crashes, leftover kernels) and asynchronous code (`SessionSubmit`, `ScheduledTask`,
`URLSubmit`, `LocalSubmit`) whose bodies and handlers run inside other evaluations. Read it when parallel results are
wrong or slow, or when a task or handler misbehaves. Behavior was checked with Wolfram 15.0.

## Where subkernels exist

| environment | `LaunchKernels` | what `Parallel*` does |
|---|---|---|
| wolframscript, `wolfram -script` | works (5 to 8 s per kernel) | runs on subkernels |
| MCP Session | works; kernels stay alive across tool calls | runs on subkernels |
| MCP Local | fails in protected mode (no process is started) | evaluates sequentially in the master |
| CloudEvaluate, deployed API, remote MCP server | returns `{}` | evaluates sequentially in the master |

```wl
WithCleanup[
  LaunchKernels[1];
  <|"Kernels" -> Length[Kernels[]], "KernelIDs" -> ParallelTable[$KernelID, {3}]|>,
  CloseKernels[]]
(* wolframscript: <|"Kernels" -> 1, "KernelIDs" -> {1, 1, 1}|>
   MCP Local: LocalSubKernelLaunch::somefail, KernelObject::giveup, ParallelTable::nopar, then
              <|"Kernels" -> 0, "KernelIDs" -> {0, 0, 0}|> *)
```

- `$KernelID` is 0 in the master: a 0 inside mapped code means the item ran in the master.
- Without kernels every `ParallelMap`/`ParallelTable`/... call issues its own `::nopar` message and evaluates in the
  master; `ParallelEvaluate[expr]` returns `{}` without a message and does not evaluate `expr`.
- Debug parallel code in wolframscript or an MCP Session server. Launch one kernel and close it in the same evaluation:
  `WithCleanup[LaunchKernels[1]; ..., CloseKernels[]]`. A bare `ParallelMap` launches the default number of kernels
  itself, and in MCP Session those kernels stay alive for the lifetime of the server (about 300 MB each). It does so
  only once per kernel: after any `LaunchKernels` or `CloseKernels`, a later `Parallel*` call without kernels runs
  sequentially with `::nopar`.
- Never return `Kernels[]`, a `KernelObject` or `$ConfiguredKernels` as output: a `KernelObject` is about 6 KB in
  `InputForm`, `$ConfiguredKernels` about 20 KB. Use `Length[Kernels[]]`.

## Definitions missing on the subkernel

The most common parallel bug, and usually an invisible one. The subkernel does not have the definition of `f`, so it
returns `f[x]` unevaluated. The **master then evaluates the returned `f[x]`**: the result looks right but all the work
ran in the master, and it is wrong if the master's state differs from the subkernel's. Detect it by holding the
result on the subkernel:

```wl
pkgDemo`g[x_] := x^2 + 1000;
WithCleanup[
  LaunchKernels[1];
  {ParallelMap[pkgDemo`g, {1, 2}],                                    (* looks right ... *)
   ParallelMap[Hold[Evaluate[pkgDemo`g[#]]] &, {1, 2}],               (* ... but the subkernel returned it unevaluated *)
   ParallelEvaluate[{$KernelID, Length[DownValues[pkgDemo`g]]}, DistributedContexts -> None],
   DistributeDefinitions["pkgDemo`"];
   ParallelMap[Hold[Evaluate[pkgDemo`g[#]]] &, {1, 2}]},              (* fixed *)
  CloseKernels[]]
(* wolframscript and MCP Session:
   {{1001, 1004}, {Hold[pkgDemo`g[1]], Hold[pkgDemo`g[2]]}, {{1, 0}}, {Hold[1001], Hold[1004]}}
   MCP Local (no subkernels, all in the master): {{1001, 1004}, {Hold[1001], Hold[1004]}, {}, {Hold[1001], Hold[1004]}} *)
```

- `Hold[f[x]]` instead of `Hold[value]` (or `ToString[f[#], InputForm] &` returning `"f[1]"`) means that `f` is not
  defined on the subkernel.
- Pass `DistributedContexts -> None` to inspection probes: otherwise the probe itself distributes the definitions and
  hides the bug it is looking for.
- Only symbols whose context starts with `$DistributedContexts` (by default `$Context`) are distributed automatically.
  **Not distributed**: symbols of package contexts, explicit ``Global` `` symbols in MCP Session (whose `$Context` is
  ``Sessions`<id>` ``), symbols that the code reaches only through strings (`ToExpression`, `Symbol`), and ReadProtected
  definitions. `$DistributedDefinitions` lists what was sent.
- Fixes: `DistributeDefinitions[f]` (also sends the definitions `f` depends on), ``DistributeDefinitions["Pkg`"]``, or
  load the package on the subkernels (next section).
- The subkernel's `$Context` is ``Global` ``, also when the master runs in ``Sessions`<id>` ``: `ToExpression` and
  `Symbol` on a subkernel create ``Global` `` symbols.
- Helper: ``WolframDebugging`ParallelCapture[f, list]`` reports `"RanInMaster"` and `"MasterOnlyHeads"` (functions left
  unevaluated on a subkernel but defined in the master); see `HelperFunctions.md`.

### ReadProtected (MX-built) packages

`DistributeDefinitions` silently sends nothing for a ReadProtected symbol (MX builds of paclets often make all package
symbols ReadProtected):

```wl
rpDemo`h[x_] := x^3; SetAttributes[rpDemo`h, ReadProtected];
WithCleanup[
  LaunchKernels[1];
  {DistributeDefinitions[rpDemo`h], DistributeDefinitions["rpDemo`"],
   ParallelMap[Hold[Evaluate[rpDemo`h[#]]] &, {2}]},
  CloseKernels[]]
(* wolframscript: {{}, {"rpDemo`"}, {Hold[rpDemo`h[2]]}}   -- no message *)
```

Load such code on the subkernels instead. Subkernels have their own `$Path` (changes to the master's `$Path` are not
copied), so `ParallelNeeds` alone fails. With `ParDemo.wl` in the directory `dir` (a package whose `sq` is
ReadProtected) loaded in the master:

```wl
WithCleanup[
  LaunchKernels[1];
  {ParallelNeeds["ParDemo`"]; ParallelMap[Hold[Evaluate[ParDemo`sq[#]]] &, {3}],
   With[{d = dir}, ParallelEvaluate[PrependTo[$Path, d]]]; ParallelNeeds["ParDemo`"];
   ParallelMap[Hold[Evaluate[ParDemo`sq[#]]] &, {3}]},
  CloseKernels[]]
(* From kernel 1 (Local (1)): Get::noopen: Cannot open ParDemo`.
   From kernel 1 (Local (1)): Needs::nocont: Context ParDemo` was not created when Needs was evaluated.
   {{Hold[sq[3]]}, {Hold[9]}} *)
```

`ParallelEvaluate[Get[FileNameJoin[{dir, "ParDemo.wl"}]]]` also works (`{Hold[9]}`). For a paclet:
``ParallelEvaluate[PacletDirectoryLoad[dir]; Needs["Ctx`"]]``.

## Messages and Print output from subkernels

Subkernel messages and `Print` output are re-printed by the master as plain text (`From kernel 1 (Local (1)):` followed
by the 2-D message text). The master's `Check`, `EvaluationData`, `$MessageList`, message handlers, `Quiet` and `Off`
neither see nor affect them:

```wl
WithCleanup[
  LaunchKernels[1];
  Lookup[EvaluationData[Check[ParallelMap[1/# &, {0, 1}], "check-fired"]], {"Result", "MessagesText", "OutputLog"}],
  CloseKernels[]]
(* wolframscript: {{ComplexInfinity, 1}, {}, {"From kernel 1 (Local (1)):", "   1\nPower::infy: Infinite expression - encountered.\n   0"}}
   MCP Session:   {{ComplexInfinity, 1}, {}, {}}   (the relayed text is shown in the tool output)
   MCP Local (no subkernels): {"check-fired", {"ParallelMap::nopar : ...", "...Power::infy..."}, {}} *)
```

- `Check` did not fire and `MessagesText` is empty: the message is only Print output in the master.
- `Quiet[ParallelMap[1/# &, {0}]]` still shows the relayed message; `ParallelMap[Quiet[1/#] &, {0}]` and
  `ParallelEvaluate[Off[Power::infy]]` suppress it. Put `Quiet`, `Off` and handlers inside the parallel code.
- In MCP Session the relayed lines count toward the tool's limit of about 10 printed outputs and messages per call
  (each subkernel `Print` costs two); a real message issued later in the same call can disappear.
- `General::stop` counts per subkernel batch, not per master evaluation. When a subkernel reaches it, the master also
  issues a real `General::stop` of its own, and that one does trip the master's `Check`.

Capture the master's relay instead of printing it:

```wl
Module[{bag = Internal`Bag[], res},
  res = WithCleanup[LaunchKernels[1];
    Block[{Print = Internal`StuffBag[bag, StringJoin[ToString /@ {##}]] &},
      ParallelMap[(Print["sub ", #]; 1/#) &, {0, 1}]],
    CloseKernels[]];
  {res, Internal`BagPart[bag, All]}]
(* wolframscript (MCP Session: the same with a higher kernel number):
   {{ComplexInfinity, 1}, {"kernel 1 (Local (1)):", "sub 0\n", "From kernel 1 (Local (1)):",
     "   1\nPower::infy: Infinite expression - encountered.\n   0", "kernel 1 (Local (1)):", "sub 1\n"}} *)
```

Better: collect messages, prints and the stack **inside** the subkernel and return them as data. A pure `Function`
needs no distribution; only `pf` must be defined on the subkernel. `$Messages = {}` stops the relay:

```wl
pf[x_] := (Print["pf ", x]; 1/x);
capture = Function[x, Module[{msgs = Internal`Bag[], prints = Internal`Bag[], stack = None, res},
  res = Internal`HandlerBlock[{"Message", Function[m, If[Last[m],
        Internal`StuffBag[msgs, Replace[m, Hold[Message[mn_, ___], _] :> ToString[Unevaluated[mn], InputForm]]];
        If[stack === None, stack = Replace[Replace[Stack[_], {a___, mf : _[_Message], ___} :> {a, mf}],
          _[e_] :> StringTake[ToString[Unevaluated[e], InputForm], UpTo[80]], {1}]]]]},
    Block[{Print = Internal`StuffBag[prints, StringJoin[ToString /@ {##}]] &, $Messages = {}},
      StackBegin[StackComplete[pf[x]]]]];
  <|"x" -> x, "KernelID" -> $KernelID, "Result" -> ToString[res, InputForm],
    "Messages" -> Internal`BagPart[msgs, All], "Prints" -> Internal`BagPart[prints, All], "Stack" -> stack|>]];
WithCleanup[LaunchKernels[1]; ParallelMap[capture, {0, 1}], CloseKernels[]]
(* wolframscript:
   {<|"x" -> 0, "KernelID" -> 1, "Result" -> "ComplexInfinity", "Messages" -> {"Power::infy"}, "Prints" -> {"pf 0"},
      "Stack" -> {"StackComplete[pf[0]]", "pf[0]", "Print[\"pf \", 0]; 1/0", "1/0", "0^(-1)",
                  "Message[Power::infy, HoldCompleteForm[0^(-1)]]"}|>,
    <|"x" -> 1, "KernelID" -> 1, "Result" -> "1", "Messages" -> {}, "Prints" -> {"pf 1"}, "Stack" -> None|>}
   MCP Session: same, with a higher "KernelID" and names like Sessions`<id>`pf[0] (the session context is not on the
   subkernel's $ContextPath); MCP Local: "KernelID" -> 0 (ran in the master) *)
```

Cutting the stack at the `Message[...]` frame drops the handler's own frames. Helpers:
``With[{cap = WolframDebugging`$CaptureFunction}, ParallelMap[cap[f[#]] &, list]]`` (the same record for any
expression) and ``WolframDebugging`ParallelCapture[f, list]`` (a summary); see `HelperFunctions.md`.

## Aborts, throws, time-outs and crashes in subkernels

```wl
WithCleanup[
  LaunchKernels[1];
  {CheckAbort[ParallelMap[If[# == 2, Abort[], #] &, {1, 2, 3}], "MASTER-ABORTED"],
   ParallelEvaluate[Throw[7, "tag"]],
   ParallelTable[If[i == 2, Throw[i], i], {i, 3}],
   ParallelMap[Catch[If[# == 2, Throw[#, "tag"], #], "tag"] &, {1, 2, 3}],
   TimeConstrained[ParallelMap[(Pause[3]; #) &, {1, 2}], 1, "TimedOut"],
   ParallelEvaluate[$KernelID]},
  CloseKernels[]]
(* {"MASTER-ABORTED", {$Aborted}, $Aborted, {1, 2, 3}, "TimedOut", {1}}   (wolframscript; MCP Session: same shape) *)
```

| in the subkernel | the master sees |
|---|---|
| `Abort[]` | the **master evaluation is aborted** (without `CheckAbort` a wolframscript run stops) |
| uncaught `Throw` | `$Aborted` for that result (or the whole `ParallelTable`), **no message** |
| `Catch` inside the mapped function | normal results |
| returned `Failure[...]` | the `Failure` as a result |
| master `TimeConstrained` expires | the subkernel's evaluation is aborted too; the kernel stays usable |
| `Quit[]` or a crash | `LinkObject::linkd` + `KernelObject::rdead`, `$Failed`; the kernel is discarded |

After a `Quit[]` or crash, `ParallelMap` does not relaunch the kernel; it falls back to the master:

```wl
WithCleanup[
  LaunchKernels[1];
  {ParallelEvaluate[Quit[]], Length[Kernels[]], ParallelMap[$KernelID &, {1, 2}]},
  CloseKernels[]]
(* LinkObject::linkd: Unable to communicate with closed link LinkObject[.../wolfram -noinit -subkernel -wstp, 205, 4].
   KernelObject::rdead: Discarding kernel 1 (Local (1)).
   ParallelMap::nopar: No parallel kernels available; proceeding with sequential evaluation.
   {{$Failed}, 0, {0, 0}} *)
```

**A deterministic crash inside `ParallelMap`, `ParallelTable` or `ParallelSubmit` + `WaitAll` can loop forever**
(not re-checked here, since it pins a CPU): the item is requeued (`LaunchKernels::req`), the kernel relaunched
(`LaunchKernels::clone`), it crashes again, and so on until an outer time limit (`SetSystemOptions["ParallelOptions" -> ...]`
does not stop it); in MCP Session until the tool's time limit, possibly leaving an untracked subkernel process. Probe a
suspect item on one kernel, where nothing is requeued (wolframscript):

```wl
crashF[x_] := If[x == 2, Run["kill -9 " <> ToString[$ProcessID]]; Pause[1]; x, x];   (* item 2 kills its kernel *)
WithCleanup[
  LaunchKernels[1]; DistributeDefinitions[crashF];
  TimeConstrained[ParallelEvaluate[crashF[2], First[Kernels[]]], 30, "TimedOut"],
  CloseKernels[]]
(* LinkObject::linkd: ..., KernelObject::rdead: Discarding kernel 1 (Local (1)).   -> $Failed  (no requeue, no relaunch) *)
```

Run such probes under `timeout -s KILL` and check for leftover kernels afterwards (next section and
`HeadlessAndCrashes.md`).

## Trace and stack sampling inside subkernels

Trace works on a subkernel even where the master's Trace is disabled (MCP Session, `wolfram -script`):

```wl
trF[x_] := x^2 + 1;
WithCleanup[
  LaunchKernels[1]; DistributeDefinitions[trF];
  {Trace[trF[2]], First[ParallelEvaluate[Trace[trF[2]]]]},
  CloseKernels[]]
(* wolfram -script and MCP Session:
   {{}, {HoldCompleteForm[trF[2]], HoldCompleteForm[2^2 + 1], {HoldCompleteForm[2^2], HoldCompleteForm[4]},
         HoldCompleteForm[4 + 1], HoldCompleteForm[5]}}
   wolframscript: both traces are full *)
```

Which item hangs, and where: run a bounded stack sampler (see `TracingAndPerformance.md`) inside the mapped function:

```wl
hangF[x_] := If[x == 2, Module[{k = 0}, While[True, k++]], x^2];
probe = Function[x, Module[{bag = Internal`Bag[], task, res},
   task = SessionSubmit[ScheduledTask[Internal`StuffBag[bag, Stack[_]], {0.2, 20}]];
   res = TimeConstrained[StackBegin[StackComplete[hangF[x]]], 1, "TimedOut"];
   TaskRemove[task];
   {x, $KernelID, res, If[Internal`BagLength[bag] == 0, None,
     Replace[TakeWhile[Internal`BagPart[bag, -1], FreeQ[#, HoldPattern[bag]] &],
       _[e_] :> StringTake[ToString[Unevaluated[e], InputForm], UpTo[60]], {1}]]}]];
WithCleanup[LaunchKernels[1]; ParallelMap[probe, {1, 2}], CloseKernels[]]
(* wolframscript:
   {{1, 1, 1, None}, {2, 1, "TimedOut", {"StackComplete[hangF[2]]", "hangF[2]",
     "If[2 == 2, Module[{k = 0}, While[True, k++]], 2^2]", "Module[{k = 0}, While[True, k++]]", "While[True, k$16796++]"}}}
   MCP Local: the same records with KernelID 0 (sequential fallback) *)
```

## What is sent and received: the Parallel debug tracers

The ``Parallel`Debug` `` tracers are loaded with Parallel in 15.0. They show the batches sent to each kernel and the
results that came back (`-internal value-` = definition distribution). The options are global: restore them.

```wl
tf[x_] := 1/x;
WithCleanup[
  LaunchKernels[1];
  SetOptions[Parallel`Debug`$Parallel, Parallel`Debug`TraceHandler -> "Save",
    Parallel`Debug`Tracers -> {Parallel`Debug`SendReceive, Parallel`Debug`Queueing}];
  ParallelMap[tf, {1, 2}];
  StringTake[ToString[Last[#] /. {Subscript[_, e_] :> e, Short[e_, _] :> e} /.
      HoldForm[e_] :> RuleCondition[ToString[Unevaluated[e], InputForm]]], UpTo[100]] & /@ Parallel`Debug`TraceList[],
  SetOptions[Parallel`Debug`$Parallel, Parallel`Debug`Tracers -> {}, Parallel`Debug`TraceHandler -> "Print"];
  CloseKernels[]]
(* wolframscript (MCP Session: the same with its own kernel and job numbers):
   {"Sending to kernel 1: -internal value- (q=0)", "Receiving from kernel 1: -internal value- (q=0)",
    "Sending to kernel 1: $`w[(Map[tf])[Unevaluated[{1, 2}]], 1] (q=0)", "Receiving from kernel 1: $`j[{1, 1/2}, 1] (q=0)",
    "      [(Map[tf])[Unevaluated[{1, 2}]]] done\neid[1]"} *)
```

Other tracers: ``Parallel`Debug`MathLink`` (kernel connections), ``Parallel`Debug`Exceptions``,
``Parallel`Debug`SharedMemory`` (`SetSharedVariable` reads and writes). `SetOptions` before Parallel is loaded fails
with `SetOptions::optnf`: evaluate `Kernels[]` first (it loads Parallel without launching a kernel, so the
``Parallel`Debug`MathLink`` tracer then also records the launch).

## Leftover kernels

Check both the kernels the master knows about and the operating-system child processes (wolframscript or MCP
Session; uses `ps`, so Linux or macOS):

```wl
childKernels[] := Select[StringSplit[RunProcess[{"ps", "-o", "pid=,args=", "--ppid", ToString[$ProcessID]}, "StandardOutput"], "\n"],
  StringContainsQ["-subkernel"]];
LaunchKernels[1];
{Length[Kernels[]], Length[childKernels[]]}
CloseKernels[]; Pause[1]; {Length[Kernels[]], Length[childKernels[]]}
(* {1, 1}   then   {0, 0} *)
```

- MCP Session keeps kernels (also auto-launched ones) for the whole server lifetime. After a tool time-out during a
  parallel call the kernel is either still in `Kernels[]` (and usable), or discarded while its process keeps running
  until its current evaluation ends. Run `CloseKernels[]` and check the child processes again.
- `RunProcess` is blocked in MCP Local (`RunProcess::pnfd`), and in MCP Session never use `Run` (its output goes into
  the JSON-RPC stream).
- Helper: ``WolframDebugging`KernelReport[]`` (kernels, subkernel PIDs, untracked child kernels, task count).

## Asynchronous tasks run inside other evaluations

`SessionSubmit`/`ScheduledTask` bodies and the handler functions of `SessionSubmit`, `URLSubmit` and `LocalSubmit` run
preemptively **inside whatever evaluation is in progress**: their `Abort[]` aborts it, their uncaught `Throw` unwinds to
its `Catch`, their messages trip its `Check`:

```wl
{SessionSubmit[ScheduledTask[Throw["from-task", "tg"], {0.3, 1}]];
   Catch[Do[Pause[0.05], {30}]; "main-not-thrown", _, {"MAIN-CAUGHT", ##} &],
 SessionSubmit[ScheduledTask[Abort[], {0.3, 1}]];
   CheckAbort[Do[Pause[0.05], {30}]; "main-not-aborted", "MAIN-ABORTED"],
 SessionSubmit[ScheduledTask[Message[General::argx, "task", 2], {0.3, 1}]];
   Check[Do[Pause[0.05], {30}]; "main-done", "CHECK-FIRED"]}
(* {{"MAIN-CAUGHT", "from-task", "tg"}, "MAIN-ABORTED", "CHECK-FIRED"}   (wolframscript, MCP Local, MCP Session) *)
```

- Tasks keep firing between MCP tool calls, and a task submitted in one call can abort or throw out of a **later**
  call (`$Aborted`, or `Throw::nocatch` with `Hold[Throw[...]]`). In MCP Local the kernel is shared, so that later call
  can be another agent's.
- A `Catch[..., _]` in the code under test catches a task's `Throw`, and a `TimeConstrained` around `TaskWait[task]`
  aborts the task's body if it is running at that moment.
- Where task output appears: wolframscript prints it; MCP Session shows it only when it happens during a call (output
  between calls is lost; messages still go into the server's cumulative `$MessageList`); **MCP Local shows neither the
  `Print` output nor the messages of tasks** (the `Check` above still fired). Return data instead (below).

## Keep tasks bounded and remove only your own

```wl
myTick = 0;
myTask = SessionSubmit[ScheduledTask[myTick++, {0.2, 50}]];         (* always bounded: {interval, count} *)
Pause[1];
mine[] := Select[Tasks[], StringContainsQ[ToString[#["EvaluationExpression"], InputForm], "myTick"] &];
{myTick, Length[mine[]], TaskRemove[mine[]]; Length[mine[]]}
(* {4, 1, 0}   (wolframscript, MCP Local; the first number varies) *)
```

`Tasks[]` in MCP Local and MCP Session lists every session's tasks: `TaskRemove[Tasks[]]` would remove other agents'
tasks too. Filter on something unique in `"EvaluationExpression"` (it is a `HoldForm`), or keep the `TaskObject`.
Helper: ``WolframDebugging`TaskReport[]``.

## Task results and failures as data

With the default `AutoRemove -> True` a finished task is removed and `task["EvaluationResult"]` fails with
`TaskObject::timnf`; get the result from a handler (request the keys you use in `HandlerFunctionsKeys`):

```wl
res = None;
t = SessionSubmit[41 + 1, HandlerFunctions -> <|"TaskFinished" -> ((res = #EvaluationResult) &)|>,
   HandlerFunctionsKeys -> {"EvaluationResult"}];
TimeConstrained[TaskWait[t], 5]; Pause[0.2];
{res, t["TaskStatus"]}
(* {42, "Removed"} *)
```

`AutoRemove -> False` keeps the result, but then `TaskWait` never returns: always wrap it in `TimeConstrained`. Wrap the
**task body** so that a failure becomes data instead of hitting whatever evaluation is running:

```wl
bag = Internal`Bag[];
run = Function[body, Internal`StuffBag[bag,
    CheckAbort[KeyTake[EvaluationData[body], {"Result", "MessagesExpressions", "OutputLog"}], "Aborted"]], HoldAll];
tasks = {SessionSubmit[ScheduledTask[run[Print["tick"]; 1/0; 5], {0.1, 1}]],
         SessionSubmit[ScheduledTask[run[Throw[1, "t"]], {0.2, 1}]],
         SessionSubmit[ScheduledTask[run[Abort[]], {0.3, 1}]]};
TimeConstrained[TaskWait[tasks], 5]; Internal`BagPart[bag, All]
(* {<|"Result" :> 5, "MessagesExpressions" -> {Hold[Message[Power::infy, HoldCompleteForm[0^(-1)]]]}, "OutputLog" -> {"tick"}|>,
    <|"Result" :> Hold[Throw[1, "t"]], "MessagesExpressions" -> {Hold[Message[Throw::nocatch, HoldForm[Throw[1, "t"]]]]}, "OutputLog" -> {}|>,
    "Aborted"}
   wolframscript and MCP Local; MCP Session: "OutputLog" -> {} (the server captures Print first) *)
```

`EvaluationData` turns an uncaught `Throw` into `Throw::nocatch` + `Hold[Throw[...]]`; `CheckAbort` keeps an `Abort[]`
inside the task. `EvaluationData` does not suppress printing (wolframscript still prints `tick` and the messages).
Helper: ``WolframDebugging`SubmitAndWait[expr, timeout]`` (submit, capture, bounded wait, remove).

Handler events: `"TaskFinished"`, `"ResultReceived"` and `"TaskStatusChanged"` fire; `"PrintOutputGenerated"` fires
with `#PrintOutput` = `HoldComplete["text"]` and suppresses the print; **`"MessageGenerated"` never fires** for
`SessionSubmit`/`LocalSubmit` (and in wolframscript adding it hides the task's messages): capture messages by wrapping
the body as above.

## URLSubmit

HTTP errors are not failures: a 404 or 500 arrives as a normal `"TaskFinished"` with that `"StatusCode"`; only a
connection failure (refused, unknown host) fires `"ConnectionFailed"`:

```wl
events = Internal`Bag[];
rec = Function[ev, Internal`StuffBag[events, KeyTake[ev, {"EventName", "StatusCode"}]]];
tasks = URLSubmit[#, HandlerFunctions -> <|"TaskFinished" -> rec, "ConnectionFailed" -> rec|>,
     HandlerFunctionsKeys -> {"EventName", "StatusCode"}] & /@
   {"http://127.0.0.1:18765/missing.txt", "http://127.0.0.1:1/refused"};
TimeConstrained[TaskWait[tasks], 10]; Internal`BagPart[events, All]
(* (a local web server on port 18765)
   {<|"EventName" -> "TaskFinished", "StatusCode" -> 404|>,
    <|"EventName" -> "ConnectionFailed", "StatusCode" -> Missing["NotAvailable"]|>,
    <|"EventName" -> "TaskFinished", "StatusCode" -> Missing["NotAvailable"]|>}   (wolframscript, MCP Local) *)
```

Mistakes in the handler specification are easy to miss:

```wl
{URLSubmit["http://127.0.0.1:18765/hello.txt", HandlerFunctions -> <|"TaskFinish" -> Print|>],
 URLSubmit["http://127.0.0.1:18765/hello.txt", HandlerFunctions -> <|"TaskFinished" -> (Print[1]; Print[2]) &|>]} // Map[Head]
(* URLSubmit::invm: TaskFinish is not a known event name.
   URLSubmit::invk: Association[TaskFinished -> (Print[1]; Print[2]) & ] is not a known value for HandlerFunctionsKeys.
   {TaskObject, Failure} *)
```

A misspelled event only warns and the task runs without that handler. `"Event" -> (a; b) &` parses as
`("Event" -> (a; b)) &`: write `"Event" -> ((a; b) &)`. Handlers run inside the current evaluation like task bodies
(their messages, `Throw` and `Abort[]` hit it) and also fire between top-level evaluations.

## LocalSubmit

Each `LocalSubmit` launches a fresh kernel (about 6 s) that receives **no definitions**; its messages appear nowhere,
and `Throw` or `Abort[]` there give `$Failed` as the result without a message:

```wl
lsF[x_] := x + 1;
out = Internal`Bag[];
t = LocalSubmit[ToString[{lsF[1], 1/0}, InputForm],
   HandlerFunctions -> <|"TaskFinished" -> (Internal`StuffBag[out, #EvaluationResult] &)|>,
   HandlerFunctionsKeys -> {"EvaluationResult"}];
TimeConstrained[TaskWait[t], 30]; Internal`BagPart[out, All]
(* wolframscript: {"{lsF[1], ComplexInfinity}"}   -- lsF was not defined there; Power::infy was not shown
   MCP Local: LocalSubmit::subkern: LinkLaunch[".../wolfram -noinit"] failed.  TaskWait::taskid ...  {} *)
```

Return `ToString[..., InputForm]` from the remote kernel (as here): an unevaluated `lsF[1]` that comes back is evaluated
by the local kernel and looks correct (`LocalSubmit[{lsF[1], $ProcessID}, ...]` delivered `{2, <remote PID>}`).
`LocalSubmit` works in wolframscript and MCP Session (there the string shows ``Sessions`<id>`lsF[1]``); it fails in MCP
Local (protected mode) and in the cloud (`LocalSubmit::cloud`).
