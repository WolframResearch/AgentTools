# Package loading

How to find out what an evaluation loads (files, contexts, autoloads, `.mx` files), which copy of a package is in use,
and why edits or new definitions do not take effect. Read it for "my change has no effect", "symbol is undefined after
loading", "it works in a fresh kernel but not here" (or the reverse), and before overriding a function that may not be
loaded yet. Behavior was checked with Wolfram 15.0 in MCP Local and wolframscript (see `Environments.md`).

## Which tool for which question

| question | first choice | section |
|---|---|---|
| what did this evaluation load (including `.mx`)? | `$LoadedFiles` before/after | What did an evaluation load? |
| which files/contexts, nested, and who triggered them? | `"GetFileEvent"` handler (+ `Stack` inside it) | The GetFileEvent handler |
| which autoload stubs fired? | ``GeneralUtilities`TraceLoading``; ``WolframDebugging`LoadTrace[expr]`` | Autoloads: TraceLoading |
| is `sym` still an unloaded stub? | `OwnValues[sym]`; ``WolframDebugging`AutoloadStubQ[sym]`` | Autoload stubs |
| which copy of a package is used, and is it current? | `FindFile`, `PacletFind[<\|"Context" -> ctx\|>]`, `$LoadedFiles`; ``WolframDebugging`ContextSourceInfo["Ctx`"]`` | Where does a context's code come from? |
| my edit has no effect | the checklist | "My edits don't take effect" |
| `f` stays unevaluated right after loading its package | ``Names["*`f"]``, parse-before-run | Shadowed symbols |
| typos and leaked symbols in a package | `"NewSymbol"` handler while loading | Symbols created while loading |

Helpers are in `scripts/WolframDebugging.wl` (load it with `Get` in its own call, call them fully qualified; options and
outputs: `HelperFunctions.md`). Everything below works without them.

## First-time effects need a fresh kernel

Autoloads, file loads and their messages happen once per kernel. The MCP kernels (MCP Local and MCP Session) are
long-running and have hundreds of packages loaded already (CloudObject, CodeParser, GeneralUtilities, MUnit, ...), so a
loading problem often does not reproduce there, and the probes below show less or nothing. Reproduce loading problems in
a fresh kernel:

```bash
timeout -s KILL 300 wolframscript -f probe.wls < /dev/null > out.txt 2>&1
```

The MCP servers also start with `-noinit` (see "Startup differences" below).

## What did an evaluation load?

`$LoadedFiles` is an append-only log of every file the kernel loaded with `Get` (`.wl`, `.m`, `.mx`, also data paclets'
`.mx` files such as `ElementData.mx`; not files read with `Import`), with duplicates, in load order:
`Drop[$LoadedFiles, before]` is exactly what an evaluation loaded. A `"GetFileEvent"` handler shows the `Get`s as they
happen, with nesting:

```wl
Module[{before = Length[$LoadedFiles], log = Internal`Bag[], res},
  res = Internal`HandlerBlock[{"GetFileEvent", Internal`StuffBag[log, #] &}, ArrayReduce[Total, {{1, 2}, {3, 4}}, 1]];
  {res, Internal`BagPart[log, All], FileNameTake /@ Drop[$LoadedFiles, before]}]
```
```
wolframscript (fresh kernel):
{{4, 6},
 {HoldComplete["NumericArrayUtilities`", Identity, First],
  HoldComplete[".../Components/NumericArrayUtilities/Kernel/Common.m", Identity, First],
  HoldComplete["GeneralUtilities`", Identity, First], HoldComplete["GeneralUtilitiesLoader`", Identity, First],
  HoldComplete["GeneralUtilitiesLoader`", Identity, Last], HoldComplete["GeneralUtilities`", Identity, Last],
  HoldComplete["Developer`", Identity, First], HoldComplete["Developer`", Identity, Last],
  HoldComplete[".../Components/NumericArrayUtilities/Kernel/Common.m", Identity, Last],
  HoldComplete["NumericArrayUtilities`", Identity, Last]},
 {"init.m", "Common.m", "GeneralUtilities.m", "GeneralUtilitiesLoader.m", "GeneralUtilities.mx", "Developer.m", "Descriptive.mx", "RobustStatistics.mx"}}
fresh MCP Session server (GeneralUtilities already loaded): the same without the GeneralUtilities events and files
MCP Local (everything already loaded by earlier calls): {{4, 6}, {}, {}}
```

The `.mx` files (`GeneralUtilities.mx`, `Descriptive.mx`, `RobustStatistics.mx`) appear only in `$LoadedFiles`: the
handler does not see them. MCP kernels have hundreds to thousands of entries (about 600 in a fresh MCP Session server,
nearly 2000 in a long-running MCP Local, where every switch between evaluator sessions adds that session's saved
`.mx` state file), so always filter it (`Select[..., StringStartsQ[#, root] &]`, `DeleteDuplicates`, `Take`) and never
return it whole.

## The "GetFileEvent" handler

``Internal`HandlerBlock[{"GetFileEvent", f}, expr]`` calls `f` before and after every `Get` (also the `Get`s done by
`Needs`, by paclet autoload stubs and by files being loaded). The argument is `HoldComplete[arg, Identity, First]` when
reading starts and `HoldComplete[arg, Identity, Last]` when it ends; nested loads nest. `arg` is the **literal first
argument** of that `Get`: a context, an absolute or relative path, a stream. Resolve it with `FindFile[arg]` inside the
handler (later the current directory or `$Path` may differ). The second element was `Identity` in every load path
tested; match it with `_`.

The examples below use a few small files in a directory `demoDir` (`demoDir = "/abs/path/to/demo";`):
`LoadDemo.wl` (a package that does `Get[FileNameJoin[{DirectoryName[$InputFileName], "LoadDemoSub.wl"}]]`),
`LoadAbort.wl` (just `Abort[];`), `ShadowDemo.wl` (``BeginPackage["ShadowDemo`"]`` exporting `shFn[x_] := x^2`),
`TypoDemo.wl` and `DeclDemo.wl` (shown in their sections), and two paclet directories `ver1/VerDemo`, `ver2/VerDemo`
(versions 1.0.0 and 2.0.0 of a paclet with context ``VerDemo` ``, whose `verFn[]` returns `"v1"` or `"v2"`).

```wl
Module[{log = Internal`Bag[]},
  Internal`HandlerBlock[{"GetFileEvent", Internal`StuffBag[log, #] &}, Get[FileNameJoin[{demoDir, "LoadDemo.wl"}]]];
  Replace[Internal`BagPart[log, All], HoldComplete[f_String, w_, fl_] :> {FileNameTake[f], w, fl}, {1}]]
(* {{"LoadDemo.wl", Identity, First}, {"LoadDemoSub.wl", Identity, First}, {"LoadDemoSub.wl", Identity, Last}, {"LoadDemo.wl", Identity, Last}} *)
```

A file that aborts (or throws) produces `First` without `Last`, so depth counters must tolerate unmatched events:

```wl
Module[{log = Internal`Bag[]},
  CheckAbort[Internal`HandlerBlock[{"GetFileEvent", Internal`StuffBag[log, #] &},
    Get[FileNameJoin[{demoDir, "LoadAbort.wl"}]]], "aborted"];
  Replace[Internal`BagPart[log, All], HoldComplete[f_String, w_, fl_] :> {FileNameTake[f], w, fl}, {1}]]
(* {{"LoadAbort.wl", Identity, First}} *)
```

It does **not** fire for a missing file (`Get::noopen`), `Needs` of a context that is already loaded, kernel autoloads
(they read `SystemResources/*.mx`), `Get` of an `.mx` file, or `PacletDirectoryLoad`:

```wl
Module[{count},
  count = Function[expr, Module[{n = 0}, Internal`HandlerBlock[{"GetFileEvent", n++ &}, expr]; n], HoldAll];
  {count[Quiet[Get["/nonexistent/x.wl"]]], count[Needs["CodeParser`"]], count[Needs["CodeParser`"]],
   count[Adjugate[{{1, 2}, {3, 4}}]], Select[$LoadedFiles, StringContainsQ["Adjugate"]]}]
(* wolframscript: {0, 96, 0, 0, {".../SystemFiles/Kernel/SystemResources/64Bit/LinearAlgebra/Adjugate.mx"}}
   MCP Local:     {0, 0, 0, 0, {...Adjugate.mx}}     -- CodeParser was already loaded there *)
```

(Checked separately in wolframscript: `Get` of a `DumpSave`d `.mx` file and `PacletDirectoryLoad` also give 0 events.)

MCP servers already have MUnit's handler installed (``Internal`Handlers["GetFileEvent"]`` gives
``"GetFileEvent" -> {MUnit`Package`MUnitGetFileHandler}``; a fresh wolframscript has none).
``Internal`HandlerBlock`` adds yours on top and removes it afterwards. Never use ``Internal`AddHandler`` for this in an
MCP kernel.

### Who triggered a load?

Take the stack inside the handler at the first `First` event. The trigger is the last frame before the first
``Package`ActivateLoad``, `Get`, `Needs` or ``System`Dump`AutoLoad`` frame. Record data instead of printing it (a package
load can fire hundreds of events), and convert frames to strings without evaluating them (15.0 frames are
`HoldCompleteForm[...]`, older versions `HoldForm[...]`; `_[e_]` matches both):

```wl
Module[{st = None},
  Internal`HandlerBlock[{"GetFileEvent", Function[ev, If[st === None && ev[[3]] === First,
      st = {ev[[1]], Replace[Stack[_], _[e_] :> ToString[Unevaluated[e], InputForm, TotalWidth -> 70], {1}]}]]},
    StackBegin[Length[Diff[{1, 2}, {1, 3}]]]];
  st]
(* {"Wolfram`DiffTools`", {"Length[Diff[{1, 2}, {1, 3}]]", "Diff[{1, 2}, {1, 3}]",
     "Package`ActivateLoad[Diff, {<<15>>}, \"Wolfram`DiffTools`\", {<<2>>}]", "AbortProtect[Get[\"Wolfram`DiffTools`\"]]",
     "Get[\"Wolfram`DiffTools`\"]", <3 frames of the handler itself>}} *)
```

To catch one particular package, test the event in the handler, e.g. ``MatchQ[ev, HoldComplete["DataResource`", _, First]]``.
Wrap the expression in `StackBegin` (drops the frames of the environment) and add `StackComplete` if you need to see your
own functions (without it a call is replaced on the stack by its right-hand side; see `MessagesAndStacks.md`).

## Autoloads: ``GeneralUtilities`TraceLoading``

``GeneralUtilities`TraceLoading[expr]`` is available in every kernel without `Needs` (call it fully qualified). Its usage
text says it reports "all file and MX load events"; in 15.0 it reports only

- autoload stubs that fire: ``"Sym" -> "Ctx`"`` (the stub of `Sym` loaded ``Ctx` ``), and
- `Get` of `.mx` files given as a string path,

**not** ordinary `.wl`/`.m` loads (its file handler is not defined). It prints, and only the first time a stub fires:

```wl
GeneralUtilities`TraceLoading[GroupOrder[SymmetricGroup[3]]]
(* wolframscript -f:  /path/to/file/being/read.wl:1: InputForm[GroupOrder -> GroupTheory`PermutationGroups`]
   MCP Local:         :40: "GroupOrder" -> "GroupTheory`PermutationGroups`"
   result: 6;  run it again in the same kernel: prints nothing *)
```

The prefix is `$InputFileName:$Line` at the time the stub fired, not necessarily the code that triggered it (in MCP Local
the file name is empty and the number is the `In[n]` line). Copied out of a notebook as plain text, the same printed row
looks like ``""*":"*1*": "*InputForm["CloudPut" -> "CloudObjectLoader`"]`` (not checked in a notebook here). Data
instead of printed lines: the undocumented second argument is a callback, called as ``callback[Hold[sym] -> "Ctx`", Symbol]``
for an autoload and `callback[mxPath, Begin]`/`callback[mxPath, End]` around an `.mx` load. `Block[{Print}, ...]` silences the printing (and any `Print` of your code):

```wl
Module[{ev = Internal`Bag[], res},
  res = Block[{Print}, GeneralUtilities`TraceLoading[RegionEqual[Disk[], Disk[{1, 1}]], Internal`StuffBag[ev, {##}] &]];
  {res, Length[Internal`BagPart[ev, All]], Take[Internal`BagPart[ev, All], UpTo[2]]}]
(* {False, 6, {{Hold[RegionEqual] -> "Regions`RegionRelations`RegionEqual`", Symbol},
               {Hold[Region`RegionRelationsDump`regionAccessor] -> "Regions`RegionRelations`RegionRelationsLibrary`", Symbol}}}
   (fresh kernel; {False, 0, {}} once RegionEqual is loaded, as in MCP Local by now) *)
```

A package loaded from source is invisible to it (the `"GetFileEvent"` handler above sees the same `Get`):

```wl
GeneralUtilities`TraceLoading[Get[FileNameJoin[{demoDir, "LoadDemo.wl"}]]; LoadDemo`ldFn[1]]
(* 3   -- nothing printed *)
```

Helper: ``WolframDebugging`LoadTrace[expr]`` combines autoload hooks, the `"GetFileEvent"` handler and the `$LoadedFiles`
difference into one bounded result (depth, kind, target, trigger, new files).

## Autoload stubs

Most System functions implemented in packages start as stubs: an OwnValue
``sym :> Package`ActivateLoad[sym, {group}, "LoaderContext`", opts]`` (paclet Kernel extensions) or
``sym :> System`Dump`AutoLoad[Hold[sym], Hold[group], "Ctx`"] /; System`Dump`TestLoad`` (kernel `.mx` files). The first
evaluation of the symbol loads the whole package and replaces the stub. Inspecting does not load it; evaluating does:

```wl
stubQ = Function[s, ! FreeQ[Quiet[OwnValues[s]], Package`ActivateLoad | System`Dump`AutoLoad], HoldAllComplete];
{Attributes[GroupOrder]; DownValues[GroupOrder]; ToString[Definition[GroupOrder]]; Context[GroupOrder]; stubQ[GroupOrder],
 GroupOrder; stubQ[GroupOrder],
 Options[RegionEqual]; stubQ[RegionEqual],
 Head[Diff]; stubQ[Diff]}
(* {True, False, False, False}   (fresh kernel: wolframscript, or a freshly started MCP server) *)
```

So: `Attributes`, `DownValues`, `Definition`, `Context` and the SymbolDefinition tool leave the stub alone; evaluating the
bare symbol, `Options[sym]`, `Head[sym]` or any call loads it. Consequences:

- Inspect a stub's definitions only after loading it (`sym;`), see `DefinitionsAndSource.md`.
- Defining on a stub fails: `Unprotect[Diff3]; Diff3["mock"] := "MOCK"` evaluates the head, the load re-protects the symbol,
  and you get `SetDelayed::write: Tag Diff3 in Diff3[mock] is Protected.`; the mock is never installed. Overrides
  inside ``Internal`InheritedBlock`` fail on stubs too (a `GroupOrder[_] := "MOCK"` there was ignored, and the package
  loaded inside the block was rolled back to the stub when it exited). Load first, then override
  (`OverridesAndWatchpoints.md`).
- Helpers: ``WolframDebugging`AutoloadStubQ[sym]`` (does not load), ``WolframDebugging`EnsureLoaded[sym]`` (loads, then
  True when no stub remains).

`DeclarePackage` stubs are different: they have no OwnValues, only the attribute `Stub`, and load the package when the
symbol name is *parsed*, before anything evaluates. `DeclDemo.wl` is
``BeginPackage["DeclDemo`"]; declFn[x_] := {"declFn", x}; EndPackage[];`` (one statement per line):

```wl
Block[{$Path = Prepend[$Path, demoDir]},
  DeclarePackage["DeclDemo`", {"declFn"}];
  {MemberQ[$Packages, "DeclDemo`"],
   ToExpression["DeclDemo`declFn", InputForm, Hold],
   MemberQ[$Packages, "DeclDemo`"]}]
(* {False, Hold[declFn], True}      -- parsing the name inside Hold loaded the package (MCP Local: Hold[DeclDemo`declFn]) *)
```

## Where does a context's code come from?

```wl
With[{ctx = "CodeParser`"},
  {FindFile[ctx], {#["Version"], #["Location"]} & /@ PacletFind[<|"Context" -> ctx|>], MemberQ[$Packages, ctx],
   Length[Select[$LoadedFiles, StringContainsQ["/CodeParser/"]]]}]
(* wolframscript: {".../SystemFiles/Components/CodeParser/Kernel/CodeParser.wl", {{"1.13", ".../SystemFiles/Components/CodeParser"}}, False, 0}
   MCP Local:     {..., {{"1.13", ...}}, True, 21} *)
```

- `FindFile[ctx]` and the first `PacletFind` entry are what the next `Get`/`Needs` would load; `$LoadedFiles` is what was
  loaded. They differ after a paclet update, a `PacletDirectoryLoad` or an `.mx` build.
- `$Packages` is the list `Needs` checks, not a list of loaded packages: loader contexts are registered before anything
  loads, and a package loaded from `.mx` at startup can be missing from it (the first `Needs` then loads it again: the
  GeneralUtilities events in the first example):

```wl
{MemberQ[$Packages, "GeneralUtilities`"], AnyTrue[$LoadedFiles, StringEndsQ["GeneralUtilities.mx"]],
 MemberQ[$Packages, "CloudObjectLoader`"], MatchQ[OwnValues[CloudPut], {_ :> _Package`ActivateLoad}]}
(* wolframscript: {False, True, True, True}   -- GeneralUtilities loaded but not in $Packages; CloudObjectLoader` listed while CloudPut is still a stub
   MCP Local:     {True, True, True, False} *)
```

### Which version wins

Among paclets, the **highest version wins**, whatever the `PacletDirectoryLoad` order; with equal versions the directory
loaded first wins. `Needs` does nothing once the context is in `$Packages`, so only `Get` loads the newly preferred copy
(wolframscript; `PacletDirectoryLoad` changes the kernel's paclet configuration, so do not try this in a shared MCP
kernel):

```wl
PacletDirectoryLoad[FileNameJoin[{demoDir, "ver1"}]]; Needs["VerDemo`"];
PacletDirectoryLoad[FileNameJoin[{demoDir, "ver2"}]];
r1 = {VerDemo`verFn[], FileNameTake[FindFile["VerDemo`"], -4], #["Version"] & /@ PacletFind["VerDemo"]};
Needs["VerDemo`"]; r2 = VerDemo`verFn[];
Get["VerDemo`"]; r3 = VerDemo`verFn[];
{r1, r2, r3}
(* {{"v1", "ver2/VerDemo/Kernel/VerDemo.wl", {"2.0.0", "1.0.0"}}, "v1", "v2"} *)
```

(Loading `ver2` first and `ver1` second gives the same `FindFile` result; two directories with the same version: the
first one loaded is used.) A development checkout added with `PacletDirectoryLoad` is therefore ignored when an
installed copy has a higher version, and updated system paclets in the user paclet repository shadow the copies in the
installation (see `DefinitionsAndSource.md`). Helper: ``WolframDebugging`ContextSourceInfo["Ctx`"]`` (candidates, loaded
files, other loaded copies, stale `.mx`, files edited since the kernel started).

## "My edits don't take effect"

Check in this order:

1. **`Needs` is a no-op** once the context is in `$Packages` (above): use ``Get["Ctx`"]`` or `Get[file]`.
2. **Reloading keeps old rules.** A second `Get` adds and replaces rules but never removes deleted ones (without
   `Protect` below, the reload gives `"v2"` for integers and still `"v1 string"` for strings), and fails on `Protect`ed
   symbols. Clear first:

```wl
Module[{file = FileNameJoin[{$TemporaryDirectory, "ReloadDemo.wl"}], write, r},
  write = Export[file, StringRiffle[Join[{"BeginPackage[\"ReloadDemo`\"]", "rdFn", "Begin[\"`Private`\"]"}, #,
      {"End[]", "Protect[rdFn]", "EndPackage[]"}], "\n"], "Text"] &;
  write[{"rdFn[x_Integer] := \"v1\"", "rdFn[x_String] := \"v1 string\""}]; Get[file];
  write[{"rdFn[x_Integer] := \"v2\""}];
  r = Check[Get[file], "messages"];                   (* SetDelayed::write: Tag rdFn ... is Protected *)
  {r, ReloadDemo`rdFn[1], ReloadDemo`rdFn["a"],
   Unprotect["ReloadDemo`*"]; ClearAll["ReloadDemo`*", "ReloadDemo`*`*"]; Get[file];
   {ReloadDemo`rdFn[1], ReloadDemo`rdFn["a"]}}]
(* SetDelayed::write: Tag rdFn in rdFn[x_Integer] is Protected.
   {"messages", "v1", "v1 string", {"v2", rdFn["a"]}}    -- nothing changed until the symbols were cleared *)
```

   The reload recipe is ``Unprotect["Ctx`*"]; ClearAll["Ctx`*", "Ctx`*`*"]; Get["Ctx`"]`` (memo values and caches go too).
   In MCP Local, files can only be written below `$TemporaryDirectory`.
3. **Another copy wins**: a higher-version installed paclet, or the first of two equal versions (above). Compare
   `FindFile`, `PacletFind[<|"Context" -> ctx|>]` and `$LoadedFiles`.
4. **A compiled `.mx` build is loaded instead of the source.** Some paclet loaders (Chatbook's, AgentTools') load a
   `64Bit/*.mx` build when it exists; source edits are then ignored until the `.mx` is rebuilt or removed. `FindFile`
   still names the `.wl` loader (for Chatbook: `Source/Chatbook/Chatbook.wl`); only `$LoadedFiles` shows the `.mx`:

```wl
With[{root = First[PacletFind[<|"Context" -> "Wolfram`Chatbook`"|>]]["Location"]},
  DeleteDuplicates @ Select[$LoadedFiles, StringStartsQ[#, root] && StringEndsQ[#, ".mx"] &]]
(* {"~/.Wolfram/Paclets/Repository/Wolfram__Chatbook-2.7.0/Source/Chatbook/64Bit/Chatbook.mx"} *)
```

   A stale build directory inside a checkout (a built paclet layout that a test runner prefers) can have the same effect
   (not checked here).
5. **The file was edited after the kernel loaded it.** MCP servers and their evaluator kernels load their packages at
   startup; editing the source changes nothing in them until the server restarts (you cannot restart it from inside an
   evaluator call; ask the user, or test in wolframscript). Files of a package modified after this kernel started:

```wl
With[{root = First[PacletFind[<|"Context" -> "Wolfram`AgentTools`"|>]]["Location"]},
  {root, DeleteDuplicates @ Select[$LoadedFiles,
    StringStartsQ[#, root] && AbsoluteTime[FileDate[#]] > AbsoluteTime[] - SessionTime[] &]}]
(* MCP Local (development checkout loaded by the server):
     {"~/AgentTools", {"~/AgentTools/Kernel/AgentSkills.wl", "~/AgentTools/Kernel/AgentToolsObject.wl", ...}}
   wolframscript (fresh kernel, installed copy): {"~/.Wolfram/Paclets/Repository/Wolfram__AgentTools-2.2.0", {}} *)
```

   It also lists files that were edited and *then* loaded later in the session (they are current); for a package loaded
   at startup, every hit means the running code is older than the file.
6. **Your call hits a different symbol** (shadowing, next section).

## Shadowed symbols and parse-before-run

The whole input (an MCP tool call, a `-code` string, one top-level expression of a `-f` file) is parsed before it runs,
so a name used in the same input as the `Get` that defines it is created in the current context first:

```wl
Get[FileNameJoin[{demoDir, "ShadowDemo.wl"}]]; {shFn[3], Context[shFn], ShadowDemo`shFn[3]}
(* {Global`shFn[3], "Global`", 9}    (wolframscript; MCP Local with bug #249 prints shFn[3]; no General::shdw message
   was issued in either) *)
```

```wl
{Names["*`shFn"], Remove["Global`shFn"]; Names["*`shFn"]}
(* {{"Global`shFn", "shFn"}, {"shFn"}}   -- two symbols before, only ShadowDemo`shFn after *)
```

- Put `Get`/`Needs` in its own tool call (or its own line of a `-f` script), and call package functions by their full
  names. In MCP Local with AgentTools bug #249 unqualified names never resolve to a package loaded with `Get`/`Needs`,
  not even in a later call (typed code is parsed into ``Global` ``); details in `Environments.md`.
- ``Names["*`name"]`` lists every context with that name; ``Remove["Global`name"]`` deletes the stray copy (expressions
  parsed earlier still hold the removed symbol). `General::shdw` is not always issued, so do not wait for it.
- Unevaluated `f[...]` right after loading: also check `UnevaluatedCalls.md`.

## Symbols created while loading (typos, leaks)

A `"NewSymbol"` handler receives ``{"name", "Context`"}`` for every symbol created while the code is read: typos show up
as new names next to the intended ones, leaks as names outside the package context. `TypoDemo.wl`:
`tdLeaked = 1;` before ``BeginPackage["TypoDemo`"]``, then `tdFn[x_] := tdHelpr[x]; tdHelper[x_] := x + 1;` in the
private context:

```wl
Module[{bag = Internal`Bag[]},
  Internal`HandlerBlock[{"NewSymbol", Internal`StuffBag[bag, #] &}, Get[FileNameJoin[{demoDir, "TypoDemo.wl"}]]];
  Internal`BagPart[bag, All]]
(* wolframscript: {{"tdLeaked", "Global`"}, {"tdFn", "TypoDemo`"}, {"x", "TypoDemo`Private`"}, {"tdHelpr", "TypoDemo`Private`"}, {"tdHelper", "TypoDemo`Private`"}}
   MCP Local: the same except {"tdLeaked", "Sessions`<id>`"}  -- files loaded with Get use the session context there *)
```

Only symbols that did not exist yet are reported (load into a fresh kernel for a complete list). Filter with
``Select[list, ! StringStartsQ[#[[2]], "TypoDemo`"] &]`` for leaks. Helper: ``WolframDebugging`NewSymbolsDuring[expr]``.

## Startup differences: `-noinit`

MCP servers (and the TestReport MCP tool's kernel) start with `-noinit`: no `init.m` files, so no `$Path` additions,
`SetOptions`, `Off[...]` or packages loaded there. Code that works in a notebook or in wolframscript but not in MCP often
depends on an init file:

```wl
{MemberQ[$CommandLine, "-noinit"],
 Select[$LoadedFiles, StringStartsQ[#, $UserBaseDirectory | $BaseDirectory] && StringEndsQ[#, "/Kernel/init.m"] &]}
(* wolframscript: {False, {"/usr/share/Wolfram/Kernel/init.m", "~/.Wolfram/Kernel/init.m"}}
   MCP Local:     {True, {}} *)
```

Reproduce MCP startup with `wolfram -noinit -script file.wl`; more startup differences in `HeadlessAndCrashes.md`.

## Gotchas

- First-time effects (autoloads, `GetFileEvent`, TraceLoading output) happen once per kernel; MCP kernels have most
  packages loaded already. Use a fresh wolframscript.
- `$LoadedFiles` is the ground truth, including `.mx` files that the `"GetFileEvent"` handler misses; filter it, it is long.
- `"GetFileEvent"` `arg` is unresolved; `First` without `Last` when a file aborts; nothing for `.mx`, kernel autoloads,
  missing files, `PacletDirectoryLoad` or `Needs` of a loaded context.
- TraceLoading reports autoloads and string-path `.mx` loads only, prints, and is silent the second time.
- `Needs` is a no-op for a context in `$Packages`; `$Packages` membership does not mean loaded.
- Highest version wins over a `PacletDirectoryLoad`ed checkout; a loader may prefer a stale `.mx`.
- Re-`Get` keeps deleted rules and fails on protected symbols: `Unprotect` + `ClearAll` the contexts first.
- Load before inspecting or overriding a stub; `DeclarePackage` stubs load when the name is parsed.
- `Get`/`Needs` in its own call; full names for package symbols.
