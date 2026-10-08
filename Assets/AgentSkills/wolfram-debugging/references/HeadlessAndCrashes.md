# Headless kernels, startup differences, crashes and hard hangs

What changes when code that was written in a notebook runs headless (MCP evaluator, wolframscript, cloud), how the
environments start differently, how to compare two environments, what a kernel crash looks like in each environment and
how to find the line that crashes, what no time limit can interrupt, how to launch processes safely, cheap static checks,
and a few smaller facts (Catch/Throw, memory, Function Repository, ``Instrumentation` ``). Environment names are defined
in `Environments.md`. Behavior was checked with Wolfram 15.0 on Linux; no desktop notebook was available for the checks.

## Notebook-only functions fail headless

Headless kernels have no notebook. These return `$Failed` and issue `FrontEndObject::notavail` in MCP Local, MCP
Session, wolframscript and `wolfram -script`, and return `$Failed` **without any message** in CloudEvaluate, deployed APIs
and the remote MCP server: `NotebookDirectory[]`, `EvaluationNotebook[]`, `Notebooks[]`, `SelectedNotebook[]`,
`CreateDocument[...]`, `NotebookPut[...]`, `CurrentValue[...]`, `FrontEndExecute[...]`, `FrontEndTokenExecute[...]`,
`CopyToClipboard[...]`, `DialogInput[...]` and `SystemDialogInput[...]`. `SetOptions[EvaluationNotebook[], ...]` stays
unevaluated as `SetOptions[$Failed, ...]` with `SetOptions::optnf`.

```wl
{NotebookDirectory[], Head[Quiet[EvaluationNotebook[]]] === NotebookObject}
(* MCP Local, MCP Session, wolframscript:
     FrontEndObject::notavail: A front end is not available; certain operations require a front end.
     {$Failed, False}
   CloudEvaluate, remote MCP server: {$Failed, False}   -- no message at all *)
```

- The message is subject to `General::stop`: after three of them in one evaluation, further notebook calls fail silently.
  `Check[expr, alt, FrontEndObject::notavail]` still catches the suppressed ones locally, but never fires in the cloud.
- The failure usually surfaces later as a secondary error: `SetDirectory[NotebookDirectory[]]` gives
  `SetDirectory::badfile` about `$Failed`; `FileNameJoin[{NotebookDirectory[], "data.csv"}]` builds a bad path.
- Not every notavail is a failure: `Monitor[...]` prints the message but returns its result. `PrintTemporary` behaves
  like `Print` in MCP and wolframscript; `MessageDialog["text"]` prints the text; `CellPrint` prints the cell's text
  (in CloudEvaluate and on the remote MCP server `MessageDialog` and `CellPrint` return `$Failed` silently).
- `$Notebooks`/`$FrontEnd` are no guard (`$Notebooks` is `True` and `$FrontEnd` is set in the cloud). Guard notebook-only code with
  `If[Head[Quiet[EvaluationNotebook[]]] === NotebookObject, ...]`, which is `True` only in a notebook or inside
  `UsingFrontEnd[...]`.
- Results: the MCP evaluator returns `Plot` and `Manipulate` results as images and `Dynamic`/`Button` as text; test the
  function behind a `Manipulate` with explicit parameter values instead.

Headless replacements:

| notebook idiom | headless replacement |
|---|---|
| `NotebookDirectory[]`, `SetDirectory[NotebookDirectory[]]` | an explicit absolute path; in a package, `DirectoryName[$InputFileName]` captured **while the file loads** (below) |
| `CreateDocument`, `NotebookPut`, `NotebookWrite` | build `Notebook[{Cell[...], ...}]` and `Put` it to a `.nb` file (no front end needed; `Export` to `.nb` starts a headless front end) |
| `NotebookImport[f, "Input" -> "InputText"]`, `NotebookEvaluate[f]` | extract the input cells as held expressions (below) and evaluate them in order; headless, `NotebookImport` returns a list of `Failure["InterpretationFailure", ...]` and `NotebookEvaluate` stays unevaluated |
| `ChoiceDialog`, `DialogInput`, `Input`, `InputString` | make the answer a function argument or option |
| `Monitor`, `PrintTemporary`, `ProgressIndicator`, `Dynamic` | return progress data instead |
| `CurrentValue`, `FrontEndExecute`, `CopyToClipboard` | delete, or guard as above |

Locate files relative to the package at load time. With a package that contains
`$dir = DirectoryName[$InputFileName]` at top level and `dirLater[] := DirectoryName[$InputFileName]`:

```wl
{EnvDemo`$dir, EnvDemo`dirLater[]}
(* after Get["/tmp/EnvDemo.wl"]:
   MCP Local:            {"/tmp/", ""}
   MCP Session:          {"/tmp/", ".../Scripts/"}       directory of the server's start script (repository dev server)
   wolframscript -f s:   {"/tmp/", "<directory of s>"}
   wolframscript -code:  {"/tmp/", ""} *)
```

`DirectoryName[""]` is `""`, and `FileNameJoin[{"", "data.csv"}]` is `"/data.csv"`, so a late
`FileNameJoin[{DirectoryName[$InputFileName], "data.csv"}]` silently points at the file system root.

Read a notebook's input cells without a front end:

```wl
Module[{file = "/tmp/demo.nb"},
  Put[Notebook[{Cell[BoxData[RowBox[{"x", "=", RowBox[{"1", "+", "1"}]}]], "Input"],
     Cell["Some text", "Text"], Cell[BoxData[SuperscriptBox["x", "2"]], "Input"]}], file];
  Cases[Import[file, "Notebook"],
    Cell[BoxData[b_], "Input" | "Code", ___] :> ToExpression[b, StandardForm, HoldComplete], Infinity]]
(* {HoldComplete[x = 1 + 1], HoldComplete[x^2]}   (MCP Local shows Sessions`<id>`x: run-time symbols go there) *)
```

## Does this code use the front end?

Every front end request goes through ``MathLink`CallFrontEnd``. Count the requests with a never-matching rule inside
``Internal`InheritedBlock`` (works in MCP Local, MCP Session, wolframscript and CloudEvaluate; the only signal in the cloud,
where no message is issued):

```wl
Module[{calls = Internal`Bag[], r},
  r = Internal`InheritedBlock[{MathLink`CallFrontEnd},
    Unprotect[MathLink`CallFrontEnd];
    PrependTo[DownValues[MathLink`CallFrontEnd],
      HoldPattern[MathLink`CallFrontEnd[a_, ___] /; (Internal`StuffBag[calls, Head[Unevaluated[a]]]; False)] :> Null];
    Quiet[{NotebookDirectory[], ImageDimensions[Rasterize[Graphics[Disk[]], ImageResolution -> 72]]}]];
  {r, Counts[Internal`BagPart[calls, All]]}]
(* MCP Local: {{$Failed, {360, 360}}, <|FrontEnd`EvaluationNotebook -> 1, FrontEnd`Value -> 2, FrontEnd`ExportPacket -> 1|>}
   wolframscript, MCP Session (first rendering, 5-10 s):
             {{$Failed, {360, 360}}, <|FrontEnd`EvaluationNotebook -> 1, FrontEnd`SetOptions -> 1, FrontEnd`Value -> 2, FrontEnd`ExportPacket -> 1|>}
   CloudEvaluate (no notavail message):
             {{$Failed, {360, 360}}, <|FrontEnd`EvaluationNotebook -> 1, FrontEnd`Value -> 4, FrontEnd`SetOptions -> 2, FrontEnd`FrontEndExecute -> 1, List -> 1, FrontEnd`ExportPacket -> 1|>} *)
```

``FrontEnd`ExportPacket``/``FrontEnd`Value`` = rendering (works headless, slow the first time);
``FrontEnd`EvaluationNotebook``, ``FrontEnd`NotebookPutReturnObject`` and similar = needs a real notebook. Helper:
``WolframDebugging`FrontEndCalls[expr, timeout]`` (also reports front end messages and whether a front end was launched).

## Rendering launches a headless front end

`Rasterize`, `Export` to PNG/PDF, `Image[graphics]` and even `ExportString[g, "SVG"]` start a headless front end
(`WolframNB ... -platform offscreen`, about 190 MB) on first use: 5-10 s in wolframscript and MCP Session. The MCP Local
subkernel gets one at startup; it runs in protected mode and cannot launch a new one, so if it loses it, `Rasterize`
returns `$Failed` with `Rasterize::nofe` until the subkernel restarts (checked by killing that front end). A
`wolfram -sandbox` kernel gives `Rasterize::nofe` (and ``Developer`UseFrontEnd::nofestart`` for `UsingFrontEnd`). Plain
`ToString[Graphics[...]]` is `"-Graphics-"` and needs no front end.

The default resolution differs between local kernels and the cloud. Pass `ImageResolution`, `RasterSize` or `ImageSize`
whenever pixel sizes matter:

```wl
AbsoluteTiming[{ImageDimensions[Rasterize[Graphics[Disk[]]]],
  ImageDimensions[Rasterize[Graphics[Disk[]], ImageResolution -> 72]]}]
(* MCP Local, MCP Session, wolframscript (front end already running): {0.03, {{480, 480}, {360, 360}}}
   CloudEvaluate:                                                    {..., {{720, 719}, {360, 360}}} *)
```

`UsingFrontEnd[expr]` gives a script a front end for notebook operations (`UsingFrontEnd[EvaluationNotebook[]]` returns a
`NotebookObject`), but after `UsingFrontEnd[NotebookEvaluate[file]]` the kernel, the front end and its helper kernel keep
running after the script ends and hold stdout open: end such scripts with ``Developer`UninstallFrontEnd[]``.

## Dialogs and standard input

Never call `ChoiceDialog`, `Input`, `InputString`, `Dialog` or `TraceDialog` in an MCP evaluator or a script: headless
they fall back to reading stdin. (`DialogInput` and `SystemDialogInput` just return `$Failed` with
`FrontEndObject::notavail`.)

| environment | effect |
|---|---|
| MCP Session | the server hangs forever; the tool time limit does not help (checked with `InputString`) |
| MCP Local | no valid response, whatever the time limit: none within 100 s, or (once) the subkernel was killed and its Failure arrived prefixed with an `In[n]:=` prompt, which breaks the JSON-RPC line (checked with `InputString`) |
| wolframscript | `InputString` returns `EndOfFile` when stdin is `/dev/null`; on an open stdin that never sends data it blocks forever (the kernel even survived killing wolframscript, until stdin closed); `ChoiceDialog` with `/dev/null` printed its prompt in an endless loop (67,000 times in 10 s); `Dialog[]` printed `In[2]:=` and ended without a result |

```bash
wolframscript -code 'InputString["prompt> "]' -format InputForm < /dev/null
# prompt> EndOfFile
```

Always run scripts with `< /dev/null`.

## Startup differences

| environment | how the kernel starts |
|---|---|
| installed MCP server | ``WolframKernel -run PacletSymbol["Wolfram/AgentTools", "Wolfram`AgentTools`StartMCPServer"][] -noinit -noprompt`` |
| MCP Local subkernel | `WolframKernel -wstp -noicon -noinit -pacletreadonly -run ChatbookSandbox...`, then protected mode |
| wolframscript | `WolframKernel -runfirst ...` (sets `$EvaluationEnvironment = "Script"`); init files are loaded |
| `wolfram -script` | init files loaded unless `-noinit` is given; TestReport MCP tool: `-script .../TestReport.wls -noinit` |
| CloudEvaluate, remote | `WolframKernel -noinit -nopaclet -run ...` |

```bash
# probe.wls:
# Print[ToString[{$EvaluationEnvironment, TrueQ[Developer`$ProtectedMode], Trace[1 + 1] =!= {}, $ContextPath,
#   Select[$LoadedFiles, StringEndsQ[#, "init.m"] && !StringStartsQ[#, $InstallationDirectory] &]}, InputForm]]
wolframscript -f probe.wls                     # {"Script", False, True, {"WolframScript`", "Wolfram`Chatbook`", "System`", "Global`"}, {"/usr/share/Wolfram/Kernel/init.m", "~/.Wolfram/Kernel/init.m"}}
wolfram -script probe.wls                      # {"Session", False, False, {"Wolfram`Chatbook`", "System`", "Global`"}, {same two init.m files}}
wolfram -noinit -script probe.wls              # {"Session", False, False, {"Wolfram`Chatbook`", "System`", "Global`"}, {}}
wolfram -sandbox -noinit -script /abs/probe.wls  # {"Session", True, False, {...}, {}}   (a relative path gave Get::noopen)
```

What this means:
- **`-noinit`** (every MCP server and the cloud) skips the `init.m` files (user and `$BaseDirectory`) and
  `InitializationValue` (the installation's `AddOns/Autoload` packages still load). Anything they set is missing: `$Path`
  entries ("the package is found in the notebook but not here"), `SetOptions`, `Off[...]`, `$HistoryLength`. Reproduce
  an MCP server's startup with `wolfram -noinit -script repro.wls`, the Local subkernel with `-noinit -pacletreadonly`,
  and protected mode with `-sandbox`.
- **`InitializationValue` is stored per `$EvaluationEnvironment`**: values set under `wolfram -script` (`"Session"`,
  as in a notebook; not checked there) are not applied in wolframscript (`"Script"`), and the reverse.
- **`$ContextPath`**: wolframscript adds ``WolframScript` ``, MCP Session has ``{"Sessions`<id>`", "System`"}`` and
  CloudEvaluate 36 contexts. ``Wolfram`Chatbook` `` in the probe output above comes from the user base of the machine
  checked here, which has a Chatbook update installed (an empty user base gave ``{"System`", "Global`"}``); with it,
  defining a function named like a Chatbook symbol (`CellToString`, ...) fails in wolframscript, `wolfram -script`
  and MCP Local (see `Environments.md`).
- **Persistence locations** differ, which changes `PersistentSymbol`, `Once[..., "Local"]` and `LocalCache`:

```wl
{Replace[$PersistencePath, Verbatim[PersistenceLocation][t_, ___] :> t, {1}],
 Replace[$PersistenceBase, Verbatim[PersistenceLocation][t_, ___] :> t], $LocalBase}
(* wolframscript, MCP Session:  {{"KernelSession", "Local", "Local", "Installation"}, "Local", "file:///<home>/.Wolfram/Objects"}
   MCP Local (fresh subkernel): {{"KernelSession", "Installation"}, "KernelSession", "file:///tmp/m000001<pid>1/LocalObjects"} *)
```

  In MCP Local, `PersistentSymbol["name"]` does not see values stored in the user's `"Local"` location (it is not on
  `$PersistencePath`; `PersistentSymbol["name", "Local"]` finds them), and `Once[..., "Local"]` results are recomputed
  after every subkernel restart (the `$LocalBase` is per process; the long-running subkernel of one server showed the
  home directory's `$LocalBase`, so check it). (`Verbatim` is needed: a bare `PersistenceLocation[t_, ___]` pattern
  evaluates and issues `PersistenceLocation::unknown`.)
- **Kernel-lifetime state**: memo values survive a redefinition, and `Once[expr]` is computed once per kernel, which in
  MCP means once per server or subkernel lifetime, across all calls and sessions:

```wl
ClearAll[memo]; memo[x_] := memo[x] = x^2; memo[2]; memo[x_] := memo[x] = x^3;
{memo[2], memo[3]}
(* {4, 27}   -- the stale memo[2] = 4 from the old definition is still used; ClearAll before redefining *)
```

- Other differences seen: `$CharacterEncoding` (`"UTF8"` in wolframscript, `"UTF-8"` elsewhere), `$TimeZone` and `LANG`
  (the cloud uses America/Chicago and `en_US.UTF-8`), `Directory[]` (the client's project root in MCP Local), the default
  of `PlotHighlighting` (`None` in the cloud), environment variables (an MCP server inherits them from the MCP client),
  and the version of a `ResourceFunction` (the locally cached one; pin with `ResourceVersion -> "x.y.z"`).

## Comparing two environments

Record the same facts in both environments and diff them. Evaluate this definition in each environment:

```wl
ClearAll[envFingerprint];
envFingerprint[] := <|
  "Version" -> $Version, "EvaluationEnvironment" -> $EvaluationEnvironment,
  "ProtectedMode" -> TrueQ[Developer`$ProtectedMode], "TraceWorks" -> (Trace[1 + 1] =!= {}),
  "Context" -> $Context, "ContextPath" -> $ContextPath, "Path" -> $Path,
  "InitFiles" -> Select[$LoadedFiles, StringEndsQ[#, "init.m"] && !StringStartsQ[#, $InstallationDirectory] &],
  "Directory" -> Directory[], "CharacterEncoding" -> $CharacterEncoding, "TimeZone" -> $TimeZone,
  "RecursionLimit" -> $RecursionLimit, "HistoryLength" -> $HistoryLength, "LocalBase" -> $LocalBase,
  "MessageHandlers" -> Length[Last[Internal`Handlers["Message"]]]|>;
```

In environment A (MCP Local can write below `/tmp`):

```wl
Put[envFingerprint[], "/tmp/fpA.wl"]
```

In environment B:

```wl
With[{a = Get["/tmp/fpA.wl"], b = envFingerprint[]},
  Association @ Map[
    # -> If[ListQ[a[#]] && ListQ[b[#]],
        <|"OnlyInA" -> Complement[a[#], b[#]], "OnlyInB" -> Complement[b[#], a[#]]|>, {a[#], b[#]}] &,
    Select[Keys[b], a[#] =!= b[#] &]]]
(* A = wolframscript, B = MCP Local:
   <|"EvaluationEnvironment" -> {"Script", "Session"}, "ProtectedMode" -> {False, True},
     "Context" -> {"Global`", "Sessions`<id>`"},
     "ContextPath" -> <|"OnlyInA" -> {"Global`", "Wolfram`Chatbook`", "WolframScript`"}, "OnlyInB" -> {..., "Sessions`<id>`"}|>,
     "InitFiles" -> <|"OnlyInA" -> {"~/.Wolfram/Kernel/init.m", "/usr/share/Wolfram/Kernel/init.m"}, "OnlyInB" -> {}|>,
     "Directory" -> {"<shell cwd>", "<project root>"}, "CharacterEncoding" -> {"UTF8", "UTF-8"}, "MessageHandlers" -> {0, 1}|> *)
```

For the cloud, evaluate `CloudEvaluate[envFingerprint[]]` from a local kernel (the definition is sent along). Helpers:
``WolframDebugging`EnvironmentFingerprint[]`` and ``WolframDebugging`FingerprintDiff[fpA, fpB]`` record and compare many
more keys (handlers of every type, `Off` messages, paclet versions, option hashes, locale, persistence).

## Kernel crashes

| environment | what a crash looks like |
|---|---|
| wolframscript | exit code **139**; stderr `Segmentation fault (core dumped)` and `The product exited for an unknown reason.`; output printed before the crash is kept |
| `wolfram -script` | exit code 139 |
| MCP Session | the server process dies and sends no response; a child process can keep stdout open, so a client that waits for an answer just times out |
| MCP Local | `Failure["KernelQuit", ...]` ("The kernel quit unexpectedly during an evaluation."), exactly like `Quit[]`; the next call runs in a new subkernel (new PID, `$Line` 1, all definitions lost) without any notice |

Known crash triggers to avoid in shared kernels: ``Package`PackageInformation[]`` and
``RuntimeTools`SetExecutionState[{"RuntimeAnalysisTools" -> True}]``. Reproduce crashes only in throwaway kernels.

**Breadcrumbs.** `PutAppend` opens and closes the file on every call, so the records survive a crash. This works in every
local environment, including MCP Local (write below `$TemporaryDirectory`):

```wl
crumb[tag_] := PutAppend[{tag, $ProcessID, DateString["Time"]}, "/tmp/crumbs.wl"];
crumb["start"]; data = Range[10];
crumb["loaded data"]; result = suspectStep[data];
crumb["after suspectStep"];
```
```bash
timeout -s KILL 60 wolframscript -f crash.wls < /dev/null > out.txt 2> err.txt; echo "exit=$?"
# exit=139   (err.txt: Segmentation fault (core dumped) / The product exited for an unknown reason.)
wolframscript -code 'ReadList["/tmp/crumbs.wl"]' -format InputForm
# {{"start", <pid>, "21:58:48"}, {"loaded data", <pid>, "21:58:48"}}   -> the crash is in suspectStep
```

**Prefix bisection.** Split the file into its top-level expressions and run prefixes (expressions 1..k, so that state
built by earlier lines is kept) in fresh kernels. Writing the prefix files works anywhere (MCP Local included); running
them needs a shell or `RunProcess`:

```wl
Module[{src = ReadString["/tmp/crash.wls"], ends},
  ends = Cases[CodeParser`CodeParse[src, "SourceConvention" -> "SourceCharacterIndex"][[2]],
    _[___, KeyValuePattern[CodeParser`Source -> {_, e_}]] :> e];
  Table[Export["/tmp/prefix" <> ToString[k] <> ".wls", StringTake[src, ends[[k]]], "Text"], {k, Length[ends]}]]
(* {"/tmp/prefix1.wls", ..., "/tmp/prefix5.wls"}   (load CodeParser` first in wolframscript: Needs["CodeParser`"]) *)
```
```bash
for k in 2 4 3; do timeout -s KILL 60 wolframscript -f /tmp/prefix$k.wls < /dev/null > /dev/null 2>&1; echo "prefix $k: exit $?"; done
# prefix 2: exit 0
# prefix 4: exit 139
# prefix 3: exit 0          -> top-level expression 4 crashes
```

Choose k by binary search for long files (about log2(n) runs of 6-9 s each). Helper:
``WolframDebugging`RunIsolated["code"]`` or ``WolframDebugging`RunIsolated[File[path]]`` runs code in a fresh wolframscript
under `timeout -s KILL` and returns the exit code, a status (`"OK"`, `"TimedOut"`, `"Crashed"`, ...), stdout, stderr and the
leftover kernels it killed; it needs `RunProcess`, so it fails in MCP Local (protected mode).

## Hard hangs

Details on time limits and stack sampling are in `TracingAndPerformance.md`. The short version:
- `TimeConstrained` interrupts `Pause`, loops, waiting `URLRead`/`URLFetch` calls, `RunProcess` (the child is killed) and
  `ReadLine` on a process. It cannot interrupt `Run[...]` or a blocked stdin read at all, and long single primitives
  only when they finish (a 0.2 s limit stopped `Sort` of 3*10^7 reals after 2.6 s and `Eigenvalues` of a 2000x2000
  matrix after 4.3 s; a 0.5 s limit stopped `N[Pi, 10^7]` after 7 s). `AbortProtect` and `WithCleanup` cleanup code
  delays the abort.
- `URLRead`/`URLFetch` have no default time-out: use `URLRead[url, TimeConstraint -> 10]` or
  `TimeConstraint -> <|"Connecting" -> 5, "Reading" -> 10|>` (other keys, such as `"Connect"`, are silently ignored), or
  `URLFetch[url, "ConnectTimeout" -> 5, "ReadTimeout" -> 10]`. `Import[url]` inside `TimeConstrained` aborts the whole
  evaluation: use `CheckAbort[TimeConstrained[Import[url], 10, $TimedOut], $TimedOut]`.

```wl
{AbsoluteTiming[TimeConstrained[Run["sleep 3"], 1, "stopped"]],
 AbsoluteTiming[TimeConstrained[RunProcess[{"sleep", "3"}], 1, "stopped"]]}
(* wolframscript: {{3.00754, 0}, {1.04101, "stopped"}}   -- Run ignored the 1 s limit
   MCP Local:     RunProcess::pnfd: Program sleep not found. Check Environment["PATH"].
                  {{0.000456, $Failed}, {0.004157, $Failed}}   -- both are blocked in protected mode; the message is misleading *)
```

When an MCP call hangs or times out:
1. Read the result. MCP Local: a `Failure["EvaluationTimeExceeded", ...]` **without** `Out[n]=` means the subkernel was
   killed and restarted after about twice the limit (all state lost; the Failure for a 5 s limit came after 21 s).
   MCP Session: a Failure that arrives much later than the limit means a non-abortable call finished late. No response
   at all: the call is blocked on stdin or a dialog (either method), or the MCP Session server crashed.
2. In the next call check `{$ProcessID, SessionTime[], $Line}` to see whether you are in a new kernel.
3. Re-run the suspect code with an inner `TimeConstrained` well below ``Internal`TimeRemaining[]`` and a bounded
   `ScheduledTask` stack sampler (``WolframDebugging`SampleStacks[expr, maxSeconds]``). Only about one sample during the
   whole wait means a non-interruptible call: `Run`, a stdin read, or one long primitive.
4. Look for blocking calls: `Run`, `Input*`, dialogs, `ReadLine`/`Read` on `$Input`, network calls without time-outs,
   cleanup code, huge numeric primitives.
5. Reproduce in a throwaway wolframscript under `timeout -s KILL` (see `Environments.md`) and afterwards kill leftover
   kernels and front ends that you started (`ps -o pid,ppid,etime,args -C WolframKernel,WolframNB`).

## Launching processes

- `Run[...]` is never abortable, and in MCP Session its output goes into the JSON-RPC stream. Prefer `RunProcess`.
- `StartProcess` children keep running after an aborted read; always `KillProcess`:

```wl
Module[{p = StartProcess[{"sleep", "30"}], line},
  line = TimeConstrained[ReadLine[p], 1, "no output yet"];
  {line, ProcessStatus[p], KillProcess[p]; ProcessStatus[p]}]
(* wolframscript: {"no output yet", "Running", "Finished"}
   MCP Local:     StartProcess::pnfd: Program sleep not found. ...  {ReadLine[$Failed], ProcessStatus[$Failed], ProcessStatus[$Failed]} *)
```

- `ReadString[ProcessConnection[p, "StandardOutput"], EndOfBuffer]` reads what is available without blocking.
- Protected mode (MCP Local, `wolfram -sandbox`) blocks `Run`, `RunProcess`, `StartProcess`, `LaunchKernels` and writes
  outside `$TemporaryDirectory`; the messages are misleading (`RunProcess::pnfd: Program ... not found`; under
  `wolfram -sandbox` also `Export::nodir: Directory ... does not exist`), and some writes fail with a silent `$Failed`
  (`Export` and `CreateDirectory` in MCP Local; `Put` and `WriteString` give `::noopen`).

## Static checks first

A linter finds a class of "impossible" runtime behavior in a second. Use the CodeInspector MCP tool (`file` or `code`;
keep the report short with `confidenceLevel`, `limit` and `tagExclusions`), or the helper
``WolframDebugging`LintSummary["code" or File[path], minConfidence]`` (one line per issue).

| tag | example |
|---|---|
| `GroupMissingCloser`, `UnexpectedCloser`, `ExpectedOperand` (Fatal) | `f[x_] := {1, 2]`, `x + * 2`; fix these first: issues after an unclosed bracket are not reported |
| `Comma` | `{1, 2, x,}` |
| `UnscopedObjectError` | `Map[#^2, list]` (missing `&`) |
| `ImplicitTimesAcrossLines` | a line break inside parentheses that multiplies two lines |
| `IfSet` | `If[x = 1, ...]` |
| `DuplicateVariables`, `DuplicateKeys`, `DuplicateClauses` | `Module[{a = 1, a = 2}, a]`, `Association["a" -> 1, "a" -> 2]`, `Switch` with a repeated pattern |
| `TopLevelDefinitionCompoundExpression` | `f[x_] := Print[x]; x` (only `Print[x]` belongs to the definition) |
| `PlusString`, `Arguments` | `"a" + "b"`, `Which[x > 1, "big", "small"]` (confidence 0.55: hidden at the MCP tool's default 0.75) |

Not detected: a trailing `;` that makes a `Module` return `Null`, `f[x_] = RandomReal[]` (Set instead of SetDelayed), and a
binary operator at a line end that joins two lines. Locate syntax errors in a string with `SyntaxQ`/`SyntaxLength`
(a length below `StringLength` is the error position; above it means "input is incomplete"):

```wl
{SyntaxQ["f[x_] := x + * 2; g[1]"], SyntaxLength["f[x_] := x + * 2; g[1]"],
 SyntaxLength["f[x_] := (x + 1"], StringLength["f[x_] := (x + 1"],
 SyntaxQ["a = 1\nb = 2 +\nc = 3"]}
(* {False, 13, 17, 15, True}   -- the last one parses as a = 1; b = 2 + (c = 3) *)
```

The inspector as data (load it in its own call first: ``Needs["CodeInspector`"]``):

```wl
{#[[1]], #[[3]], #[[4]][CodeParser`Source]} & /@ CodeInspector`CodeInspect["f[x_] := If[x = 1, {1, 2,}, x]"]
(* {{"Comma", "Error", {{1, 26}, {1, 26}}}, {"IfSet", "Warning", {{1, 13}, {1, 18}}}}   -- {line, column} ranges *)
```

The MCP evaluator silently closes a bracket that is missing at the end of multi-line input (see `Environments.md`), so
inspect code that behaves impossibly before you debug it.

## Catch, Throw and Enclose

```wl
{Catch[Catch[1 + Throw[5, "inner"], "other"], _, <|"Tag" -> #2, "Value" -> #1|> &],
 Catch[Catch[1 + Throw[5], _, List]],
 Catch[Catch[1 + Throw[5, "t"]], _, {"outer", ##} &],
 Enclose[ConfirmQuiet[1/0], #[{"HeldMessageName", "HeldMessageCall"}] &]}
(* {<|"Tag" -> "inner", "Value" -> 5|>, 5, {"outer", 5, "t"},
    {Hold[Power::infy], Hold[Message[Power::infy, HoldCompleteForm[0^(-1)]]]}} *)
```

- `Catch[expr, _, f]` catches every **tagged** throw (and tells you the tag); it does not catch an untagged `Throw[x]`.
  A plain `Catch[expr]` catches only untagged throws.
- An uncaught `Throw` gives `Throw::nocatch` and `Hold[Throw[...]]` in the MCP evaluator; in a `-f` script it prints
  `Throw::nocatch` and ends the rest of the script; under `wolfram -script` it ends the script without any message.
  The exit code stays 0.
- `Enclose`/`Confirm*` failures carry `"ConfirmationType"`, `"HeldMessageName"` and `"HeldMessageCall"`. Their
  `"Message"` property is a string with linear box syntax, such as
  `"\!\(\*TagBox[FractionBox[...]]\) produced a message on evaluation."`: read the held properties instead.
- Code under test that contains `Catch[..., _]` or runs inside `EvaluationData` can swallow a probe's `Throw`; see
  `MessagesAndStacks.md`.

## Memory and leaks

```wl
{MaxMemoryUsed[Total[RandomReal[1, 10^6]]], ByteCount[RandomReal[1, 10^6]]}
(* {8000440, 8000200}   -- peak bytes while evaluating (varies a little), size of one result *)
```

`Module` temporaries leak when a local symbol escapes the `Module`. One that is still referenced stays alive; once the
reference is dropped it is collected:

```wl
ClearAll[leaky, leakCache]; leakCache = {};
leaky[n_] := Module[{tbl}, tbl = RandomReal[1, n]; AppendTo[leakCache, Hold[tbl]]; Total[tbl]];
With[{n0 = Length[Names["*`tbl$*"]]},
  Do[leaky[1000], {50}];
  {Length[Names["*`tbl$*"]] - n0, leakCache = {}; Length[Names["*`tbl$*"]] - n0}]
(* {50, 0} *)
```

An escaped temporary that has **DownValues** (`tbl[1] = ...` instead of `tbl = ...`) is never collected, even after
the reference is dropped (the same test gives `{50, 50}`; one that never escaped is removed): such leaks last as long as
the kernel. In a shared MCP kernel, remove leaked temporaries you created (`Remove @@ Names[...]` with names you are sure
are yours). The helper
``WolframDebugging`LeakCheck[expr, max]`` reports the memory delta and new temporaries by name. MCP kernels keep
results in the session history (`$HistoryLength` is `Infinity` there, 0 in the cloud): end big intermediate results
with `;`.

## Function Repository helpers

Some community functions are handy for quick checks; they are downloaded from the cloud on first use (about 1-5 s) and
work in MCP Local:

```wl
ResourceFunction["GeneratedMessageList"][1/0; First[{}]]
(* {"Power::infy: Infinite expression Power[0, -1] encountered.", "", "First::nofirst: {} has zero length and no first element."} *)
```

Others: `"FailOnMessage"`, `"MessagedQ"`, `"CatchAll"`, `"TimeMemoryUsed"`, `"SearchMessages"` (find a message by its text)
and `"FailWhenUndefined"` (adds a catch-all rule so that an unmatched call returns a `Failure` instead of staying
unevaluated). `ResourceFunction` uses the locally cached version; two machines can run different versions.

## Instrumentation (advanced)

The ``Instrumentation` `` component rewrites a **copy** of a package's source directory so that every definition records
its source location; this gives file:line provenance for messages, line coverage (`CoverageInstrument`,
`CoverageEvaluate`) and per-function profiles (`ProfileInstrument`, `ProfileEvaluate`) without a front end. Run it in a
throwaway wolframscript kernel: it loads the instrumented package into the kernel and prints a `ProgressIndicator`
expression while instrumenting.

```wl
Quiet[Needs["Instrumentation`"]];
Instrumentation`MessageInstrument["/path/to/src", "/tmp/instr"];
Get["/tmp/instr/Kernel/InstrDemo.wl"];
```
```wl
Module[{prov = Internal`Bag[]},
  Internal`HandlerBlock[{"Message", Function[m, Internal`StuffBag[prov,
      Cases[Stack[_], HoldPattern[(HoldCompleteForm | HoldForm)[msg`InfoWrapper[_, {fn_, file_, line_}]]] :>
        fn <> " @ " <> FileNameTake[file] <> ":" <> ToString[line]]]]},
    Quiet[InstrDemo`MyFunction[-1, 1]]];
  Internal`BagPart[prov, All]]
(* {{"MyFunction @ InstrDemo.wl:7", "OtherFunction @ InstrDemo.wl:5"}}   (wolframscript) *)
```

Here `/path/to/src` contains `Kernel/InstrDemo.wl`, in which `OtherFunction[x_] := 1/x` is on line 5 and
`MyFunction[a_, b_] := Table[OtherFunction[i], {i, a, b}]` on line 7. The `HoldPattern` is required: ``msg`InfoWrapper``
has definitions, so an unprotected pattern would evaluate to `_`. The component's own
``Instrumentation`EnableMessageProvenance[]`` prints an empty `Column[{}]` in 15.0 because it matches `HoldForm` frames,
while 15.0 frames are `HoldCompleteForm`.
