# Overrides and watchpoints

How to spy on, mock or temporarily override any function (your own, a package's or a System function) with
``Internal`InheritedBlock``, what such overrides cannot see, which changes leak out of a block, how to keep an override
across several tool calls safely, how to find out who changes a variable (watchpoints), and other handler probes (new
symbols, file writes, failed assertions, prints). These tools work where `Trace` is disabled (MCP Session, the cloud).
Behavior was checked with Wolfram 15.0 in the environments named in `Environments.md`.

The examples use these definitions:

```wl
ClearAll[otherFn, myFn];
otherFn[x_] := 1/x; myFn[a_, b_] := Table[otherFn[i], {i, a, b}];
```

## Which tool for which question

| question | first choice | section |
|---|---|---|
| with which arguments is `f` called, and what does it return? | spy rule in ``Internal`InheritedBlock``; ``WolframDebugging`LogCalls[{f, g}, expr]`` | The pattern |
| make `f` return canned data for some arguments | prepended rule; ``WolframDebugging`WithOverrides[{lhs :> rhs}, expr]`` | Mocking |
| which HTTP requests does this code make? | spy on `URLFetch` | Mocking |
| my spy or mock is silently ignored | autoload stub, literal rule, C code caller, auto-compilation | What an override cannot see |
| keep an override over several tool calls | `WithCleanup`; ``WolframDebugging`SnapshotDefinitions[f]`` | Several tool calls |
| who changes this variable? who changes it to a bad value? | value monitor + `"ValueChange"` handler; ``WolframDebugging`WatchChanges[{x}, expr]``, ``WolframDebugging`StopWhen[x, test, expr]`` | Watchpoints |
| which symbols, files, failed asserts or prints does this create? | handler probes; ``WolframDebugging`NewSymbolsDuring[expr]``, ``WolframDebugging`FileWritesDuring[expr]``, ``WolframDebugging`FailedAssertions[expr]``, ``WolframDebugging`CapturePrints[expr, max]`` | Other handler probes |
| the stack when `f` gets particular arguments | ``WolframDebugging`StackAtCall[expr, f[0]]`` | `MessagesAndStacks.md` |

Helpers are in `scripts/WolframDebugging.wl` (load it with `Get` in its own call, call them fully qualified; options and
outputs: `HelperFunctions.md`). Every recipe below works without them.

## The pattern: spy on a function

```wl
Module[{calls = Internal`Bag[], inF = False, res},
  otherFn;                                       (* 1. evaluate the bare symbol: loads an autoload stub first *)
  res = Internal`InheritedBlock[{otherFn},       (* 2. InheritedBlock starts from a copy of all definitions *)
    Unprotect[otherFn];                          (* needed for System and package symbols; restored on exit *)
    PrependTo[DownValues[otherFn],               (* 3. prepend: tried before the original rules, which stay *)
      HoldPattern[otherFn[args___] /; !inF] :>  (* 4. HoldPattern[lhs] :> rhs   5. recursion guard *)
        Block[{inF = True}, Internal`StuffBag[calls, HoldComplete[args]]; otherFn[args]]];
    myFn[1, 3]];
  {res, Internal`BagPart[calls, All], Length[DownValues[otherFn]]}]
(* {{1, 1/2, 1/3}, {HoldComplete[1], HoldComplete[2], HoldComplete[3]}, 1}     the extra rule is gone afterwards *)
```

Same result in MCP Local, MCP Session and wolframscript. Each element matters:

1. **Load autoload stubs first.** Many System and package functions start as stubs that load their package on first
   use; an override installed before that is silently replaced and the real function runs ("What an override cannot
   see" below).
2. **``Internal`InheritedBlock``, not `Block`.** `Block[{f}, ...]` starts from a blank symbol: no definitions, no
   attributes, so your rule replaces the whole function, and a System function loses its attributes
   (`Block[{Table}, ...]` drops `HoldAll`). ``Internal`InheritedBlock`` starts from a copy of everything and restores
   all values, attributes (`Protected`, `ReadProtected`, ...), options and `Messages[f]` when it exits, also after
   `Abort[]`, `Throw`, `TimeConstrained` and MCP time-outs (exceptions: "Changes that leak out of a block"):

```wl
ClearAll[g]; g[x_] := x^2;
{Block[{g}, Length[DownValues[g]]], Internal`InheritedBlock[{g}, Length[DownValues[g]]],
 Block[{Plus}, Attributes[Plus]], Internal`InheritedBlock[{Plus}, Attributes[Plus]]}
(* {0, 1, {}, {Flat, Listable, NumericFunction, OneIdentity, Orderless, Protected}} *)
```

3. **Prepend.** `PrependTo[DownValues[f], rule]` puts your rule first and keeps the original rules callable. A
   `SetDelayed` with the same left-hand side *replaces* the original rule (even with other pattern names), and an
   appended rule never runs after a catch-all rule.
4. **`HoldPattern[lhs] :> rhs`.** `PrependTo` evaluates the rule's left-hand side. Without `HoldPattern` the real function
   runs with pattern arguments and a dead rule is stored, silently:

```wl
ClearAll[sideEffect];
sideEffect[x_] := (Print["real sideEffect ran with ", x]; {"result", x});
Internal`InheritedBlock[{sideEffect},
  PrependTo[DownValues[sideEffect], sideEffect[y_String] :> "MOCK"];   (* WRONG: no HoldPattern *)
  {First[DownValues[sideEffect]], sideEffect["abc"]}]
(* real sideEffect ran with y_String
   real sideEffect ran with abc
   {HoldPattern[{"result", y_String}] :> "MOCK", {"result", "abc"}} *)
```

   `->` instead of `:>` evaluates the right-hand side once, when the rule is created.
5. **Recursion guard.** The spy calls `f[args]` again, which would match the spy rule forever: `$RecursionLimit::reclim`,
   and in a wolframscript script the whole rest of the script is skipped. The guard (`/; !inF` plus
   `Block[{inF = True}, ...]`) lets the inner call reach the original rules. Keep guard conditions free of side effects.
   With a Boolean guard only the outermost call of a recursive function is recorded;
   ``WolframDebugging`LogCalls[{f}, expr]`` records every call with its result and timing (also recursive calls, held
   arguments, literal rules, `Throw`/`Abort`), and ``WolframDebugging`CallLogSummary[log]`` prints it as a tree.

The value of the block is evaluated again after the definitions are restored (also outside any `Quiet` inside the
block, so its messages appear). When it contains an unevaluated call of the overridden function, wrap it:

```wl
ClearAll[q]; q[1] := "outside";
{Internal`InheritedBlock[{q}, DownValues[q] = {}; q[1]], Internal`InheritedBlock[{q}, DownValues[q] = {}; HoldComplete @@ {q[1]}]}
(* {"outside", HoldComplete[q[1]]} *)
```

## Mocking

Canned results for specific arguments (the other rules stay active):

```wl
Internal`InheritedBlock[{otherFn},
  PrependTo[DownValues[otherFn], HoldPattern[otherFn[0]] :> "MOCK"];
  myFn[-1, 1]]
(* {-1, "MOCK", 1} *)
```

``WolframDebugging`WithOverrides[{lhs :> rhs, ...}, expr]`` does this for several rules at once (DownValues, OwnValues and
SubValues, stubs loaded first, `Locked` symbols rejected) and returns `HoldComplete[result]`.

HTTP. `URLRead`, `URLExecute` and `CloudGet`/`CloudPut` all send their requests through `URLFetch`; `Import` of a URL and
`URLDownload` go through `URLSave`. `URLExecute` calls `URLRead[{url}, elements]` (a list), so the `URLRead` mock below
does not affect it. Mock one function for one host:

```wl
URLRead;   (* load it first if it is still an autoload stub *)
Internal`InheritedBlock[{URLRead},
  Unprotect[URLRead];
  PrependTo[DownValues[URLRead],
    HoldPattern[URLRead[url_String /; StringStartsQ[url, "https://api.example.invalid"], ___]] :>
      HTTPResponse["{\"ok\":true}", <|"StatusCode" -> 200, "ContentType" -> "application/json"|>]];
  With[{r = URLRead["https://api.example.invalid/x"]}, {r["StatusCode"], r["Body"]}]]
(* {200, "{\"ok\":true}"} *)
```

or mock `URLFetch` to cover `URLRead` and `URLExecute` together (it receives the URL and a list of the elements wanted):

```wl
URLFetch;
Internal`InheritedBlock[{URLFetch},
  Unprotect[URLFetch];
  PrependTo[DownValues[URLFetch],
    HoldPattern[URLFetch[url_String /; StringContainsQ[url, "api.example.invalid"], elems_List, ___]] :>
      Replace[elems, {"StatusCode" -> 200, "HeadersReceived" -> {{"content-type", "application/json"}},
        "CookiesReceived" -> {}, "BodyByteArray" -> StringToByteArray["{\"answer\":42}"], other_ :> Missing["NotMocked", other]}, {1}]];
  {URLExecute["https://api.example.invalid/v1", "RawJSON"], URLRead["https://api.example.invalid/v1"]["StatusCode"]}]
(* {<|"answer" -> 42|>, 200} *)
```

Record every request instead (the same spy around `CloudPut`, `CloudGet` or `ResourceUpdate` lists the cloud API URLs
they call; requests to `.invalid` hosts fail at once, in about 0.1 s):

```wl
Module[{urls = Internal`Bag[], inFetch = False},
  URLFetch;
  Internal`InheritedBlock[{URLFetch},
    Unprotect[URLFetch];
    PrependTo[DownValues[URLFetch], HoldPattern[URLFetch[url_, rest___] /; !inFetch] :>
      Block[{inFetch = True}, Internal`StuffBag[urls, url]; URLFetch[url, rest]]];
    Quiet[{URLRead["https://example.invalid/a"], URLExecute["https://example.invalid/b"]}]];
  Internal`BagPart[urls, All]]
(* {"https://example.invalid/a", "https://example.invalid/b"} *)
```

The first argument is not always a string (cloud functions pass `CloudObject[...]`), so the spy matches `url_`. For
whole request/response logs see ``WolframDebugging`WithHTTPLog`` in `CloudAndHTTP.md`.

Time and randomness:

```wl
Block[{Now = DateObject[{2024, 1, 1, 12, 0, 0}, "Instant", "Gregorian", 0.]}, DateString[Now, "ISODateTime"]]
BlockRandom[SeedRandom[42]; RandomInteger[100, 3]] === BlockRandom[SeedRandom[42]; RandomInteger[100, 3]]
(* "2024-01-01T12:00:00"
   True *)
```

`Block[{Now = ...}]` only affects code that uses `Now` (not `DateObject[]`, `AbsoluteTime[]` or `Date[]`). Do not mock
`RandomReal`: `RandomVariate`, `RandomChoice` and other C code bypass the mock; seed inside `BlockRandom` instead (it
does not disturb the global generator). Other mocks that need no `Unprotect`: an UpValue on a fake argument you pass in
(`fakeURL /: URLRead[fakeURL, ___] := HTTPResponse[...]`), and a prepended `SubValues` rule for `obj[data][prop]` calls.

## What an override cannot see

**Autoload stubs.** An unloaded System or paclet function is an OwnValue stub; querying `DownValues`, `Attributes` or
`Definition` does not load it, the first call does, and the package load wipes the rule you prepended. In a fresh
wolframscript kernel (in a long-running MCP kernel the package may be loaded already: then the first element is `False`
and the mock works):

```wl
{MatchQ[OwnValues[JSONTools`ToJSON], {_ :> (_Package`ActivateLoad | Verbatim[Condition][_System`Dump`AutoLoad, _])}],
 Internal`InheritedBlock[{JSONTools`ToJSON},
   Unprotect[JSONTools`ToJSON];
   PrependTo[DownValues[JSONTools`ToJSON], HoldPattern[JSONTools`ToJSON[___]] :> "MOCK"];
   JSONTools`ToJSON[{1, 2}]]}
(* {True, "[\n    1,\n    2\n]"}     a stub; the REAL function ran, the mock was ignored *)
```

Evaluating the bare symbol first (``JSONTools`ToJSON;``) loads the package; after that the same block returns `"MOCK"`.
This is dangerous with side effects: a mocked but unloaded `CloudPut` wrote a real cloud object. Which symbols are still
stubs differs between a fresh wolframscript kernel, a fresh MCP server and a long-running MCP Local kernel, so always
evaluate the bare symbol first (``WolframDebugging`AutoloadStubQ[f]``, ``WolframDebugging`EnsureLoaded[f]``). For package
symbols that are not stubs yet, `Needs` the package first. More in `PackageLoading.md`.

**Literal rules and memo values** (`f[0] = ...`, `f[n] = ...` inside a memoizing definition) are looked up in a hash
table before any pattern rule, wherever you prepend:

```wl
ClearAll[lit]; lit[0] = "zero"; lit[x_] := "general";
Internal`InheritedBlock[{lit},
  PrependTo[DownValues[lit], HoldPattern[lit[___]] :> "SPY"];
  {lit[0], lit[1]}]
Internal`InheritedBlock[{lit},
  DownValues[lit] = Replace[DownValues[lit],          (* turn literal rules into conditional ones *)
    (Verbatim[HoldPattern][lhs_] :> rhs_) /; FreeQ[Unevaluated[lhs], _Pattern | _Blank | _BlankSequence | _BlankNullSequence] :>
      (HoldPattern[lhs /; True] :> rhs), {1}];
  PrependTo[DownValues[lit], HoldPattern[lit[___]] :> "SPY"];
  {lit[0], lit[1]}]
(* {"zero", "SPY"}
   {"SPY", "SPY"} *)
```

To mock a literal call, prepend a literal rule (`HoldPattern[lit[0]] :> "MOCK"`): it is stored before the old one.
Memo values created inside the block are literal again and are discarded when the block ends.

**C code callers and auto-compilation.** A prepended rule only sees calls that go through the evaluator. Work done in
C does not: a mock of `Plus[1, 2]` was ignored by `1 + 2`, `Plus[1, 2]`, `Total` and `Sum` (numeric `Plus` never
reaches it), a `StringJoin` mock by `StringRiffle`, a `RandomReal` mock by `RandomVariate`, a `Table` mock by `Array`.
`Table` with 250 or more elements and `Map` with 100 or more are compiled automatically and never look at your rule. A
condition with a side effect counts calls without firing:

```wl
Module[{n = 0, counts = {}},
  Internal`InheritedBlock[{Sin},
    Unprotect[Sin];
    PrependTo[DownValues[Sin], HoldPattern[Sin[_Real] /; (n++; False)] :> Null];   (* counts calls, never fires *)
    Table[Sin[N[k]], {k, 100}]; AppendTo[counts, n];
    Table[Sin[N[k]], {k, 1000}]; AppendTo[counts, n];
    With[{old = SystemOptions["CompileOptions"]},
      WithCleanup[
        SetSystemOptions["CompileOptions" -> {"TableCompileLength" -> Infinity, "MapCompileLength" -> Infinity}],
        Table[Sin[N[k]], {k, 1000}],
        SetSystemOptions[old]]];
    AppendTo[counts, n]];
  {counts, SystemOptions["CompileOptions" -> "TableCompileLength"]}]
(* {{100, 100, 1100}, {"CompileOptions" -> {"TableCompileLength" -> 250}}}
   the 1000-element Table made no visible calls until auto-compilation was switched off; the option is restored *)
```

**Flat heads** (`StringJoin`, `Plus`, `Times`, `Join`, `Dot`, ...) try a rule on many sub-sequences, so a condition runs
many times per call: the counting condition above, on `StringJoin`, ran 10 times for one `StringJoin["a", "b", "c"]`.
Use a Boolean guard for them, as in the spy above. Spying on a hot function is slow: a guarded spy on `Plus` made a loop
of symbolic sums about 18 times slower.

**Other limits.** A function defined as an OwnValue (`f = Function[...]`) never reaches `DownValues`: override its
OwnValue. Calls `f[a][b]` use `SubValues[f]`. `Listable` functions thread before your rule sees the call. 35 System
symbols are `Locked` (`List`, `True`, `Symbol`, `$Version`, ...) and cannot be blocked or overridden at all:

```wl
{Internal`InheritedBlock[{List}, 1], MemberQ[Attributes[List], Locked]}
(* Internal`InheritedBlock::lockv: -- Message text not found -- (List) ({List})
   {Internal`InheritedBlock[{List}, 1], True} *)
```

## Changes that leak out of a block

Attributes set inside a block are restored, except `Temporary` and `Locked`, which stay set; and a `Locked` symbol
can never be blocked or cleared again. Run this only in a throwaway wolframscript kernel, never in a shared MCP kernel:

```wl
ClearAll[mySymbol];
Internal`InheritedBlock[{mySymbol}, SetAttributes[mySymbol, {Protected, Flat, Listable, Temporary, Locked}]];
Attributes[mySymbol]
Block[{mySymbol}, 1]
ClearAll[mySymbol]
(* {Locked, Temporary}
   Block::lockv: Cannot localize locked symbol mySymbol in local variable specification {mySymbol}.
   ClearAll::locked: Symbol mySymbol is locked. *)
```

`ClearAll[f]` (and `Remove[f]`) inside ``Internal`InheritedBlock[{f}, ...]`` wipes the outer definitions, and `f::tag = ...`
inside the block is permanent:

```wl
ClearAll[q2, q3]; q2[1] = 1; q3::info = "original";
Internal`InheritedBlock[{q2, q3}, ClearAll[q2]; q2[2] = 2; q3::info = "changed inside"];
{DownValues[q2], q3::info}
(* {{HoldPattern[q2[2]] :> 2}, "changed inside"}     q2[1] is gone, the message text changed for good *)
```

Inside the block use `Clear[f]` or `DownValues[f] = {}`, and `Messages[f] = Append[Messages[f], HoldPattern[f::tag] :> "text"]`
(all restored). `Block[{f}, SetOptions[f, "opt" -> 3]]` issues `SetOptions::optnf` (the blocked `f` has no options)
and still changes the outer options for good. Never `ClearAll` a System symbol to undo an override: it strips its
attributes (after `Unprotect[Table]; ClearAll[Table]`, `Table` no longer holds its arguments); restore the saved values
instead.

## Overrides that span several tool calls

Within one call, guarantee the cleanup with `WithCleanup` when you cannot use a block (setup and cleanup also run on
`Abort[]`, `Throw`, `TimeConstrained` and MCP time-outs; they cannot be interrupted, so keep them fast):

```wl
ClearAll[svc]; svc[x_] := x;
{With[{saved = DownValues[svc]},
   WithCleanup[
     PrependTo[DownValues[svc], HoldPattern[svc[_]] :> "MOCK"],   (* setup *)
     {svc[1], TimeConstrained[Pause[5], 0.5, "timed out"]},      (* body *)
     DownValues[svc] = saved]],                                  (* cleanup: also runs on Abort, Throw, time-outs *)
 svc[1]}
(* {{"MOCK", "timed out"}, 1} *)
```

Across calls, snapshot everything first and restore it in the call that ends the experiment:
``snap = WolframDebugging`SnapshotDefinitions[f]`` ... ``WolframDebugging`RestoreDefinitions[f, snap]`` (gives `True`
when `f` matches the snapshot again). Without the helper, save `OwnValues`, `DownValues`, `UpValues`, `SubValues`,
`Options`, `Attributes` and `Messages` explicitly. Do not use ``Language`ExtendedDefinition`` for this: it returns an
empty list for `ReadProtected` symbols, so there is nothing to restore from:

```wl
ClearAll[rp]; rp[x_] := x + 1; SetAttributes[rp, ReadProtected];
{Length[DownValues[rp]], Language`ExtendedDefinition[rp], Length[DownValues[URLFetch]], Language`ExtendedDefinition[URLFetch]}
(* {1, Language`DefinitionList[], 1, Language`DefinitionList[]} *)
```

An MCP time-out restores scoped overrides (``Internal`InheritedBlock``, `WithCleanup`) but not an unscoped
`PrependTo[DownValues[f], ...]` whose undo line never ran: that rule stays for every later call.

## Overrides in a shared MCP kernel

MCP Local runs every session's code in one shared subkernel, and MCP Session runs it inside the MCP server's own
kernel: an unscoped change to a System symbol affects every session until the kernel restarts. In fresh
MCP Session servers:

- `Unprotect[Print]; Print[args___] := Null` silenced every later `Print`; an unscoped `Message` override hid all later
  messages.
- A prepended `ToString` rule turned every response of the server, from that call on, into `HACKED`.
- A prepended `WriteLine["stdout", ...]` rule made the server go silent for good (it writes its JSON-RPC responses
  with `WriteLine`), including the response to that call.

Even a scoped override of a function the evaluator uses for formatting (such as `ToString`) is active while the MCP
evaluator captures that call's prints and messages: a scoped `ToString` override turned the call's print line into
`During evaluation of In[HACKED]:= HACKED` and its message into `HACKED: HACKED` in MCP Session, and the message into
`Power::infy: Infinite expression HACKED encountered.` in MCP Local. Record raw data into a bag inside the block and
format it afterwards. Do not rely on `$Pre`, `$Post` or `$PrePrint` in MCP: they have no effect in either method. Wrap
the expression instead. To repair a damaged System symbol, restore the saved values; a fresh session does
not help, because System symbols are shared by all sessions of a kernel.

## Watchpoints: who changes this variable?

``Internal`SetValueMonitor[x, True]`` makes every change of `x` call the `"ValueChange"` handlers; `Stack[_]` inside the
handler tells who made the change:

```wl
ClearAll[counter, bump, runAll];
counter = 0; bump[] := counter++; runAll[] := (bump[]; counter = 10; bump[]);
Module[{bag = Internal`Bag[]},
  Internal`WithLocalSettings[
    Internal`SetValueMonitor[counter, True],
    Internal`HandlerBlock[{"ValueChange", Internal`StuffBag[bag, {#,
        Cases[Stack[_], _[h_Symbol[___]] /; MemberQ[{"Global`", $Context}, Context[h]] :> SymbolName[Unevaluated[h]], {1}]}] &},
      StackBegin[StackComplete[runAll[]]]],
    Internal`SetValueMonitor[counter, False]];      (* ALWAYS reset: the flag survives ClearAll *)
  Internal`BagPart[bag, All]]
(* {{HoldComplete[counter, 0, 1, OwnValues], {"runAll", "bump"}}, {HoldComplete[counter, 1, 10, OwnValues], {"runAll"}},
    {HoldComplete[counter, 10, 11, OwnValues], {"runAll", "bump"}}} *)
```

Same output in MCP Local, MCP Session, wolframscript, CloudEvaluate and on the remote MCP server.
``Internal`WithLocalSettings[setup, body, cleanup]`` (like `WithCleanup`) resets the flag even after an abort or a
time-out. The event forms:

```wl
ClearAll[w];
Module[{bag = Internal`Bag[]},
  Internal`WithLocalSettings[
    Internal`SetValueMonitor[w, True],
    Internal`HandlerBlock[{"ValueChange", Internal`StuffBag[bag, ToString[#, InputForm]] &},   (* strings: see below *)
      w = {1, 2}; w[[1]] = 5; AppendTo[w, 3]; Block[{w = 0}, w++]; w =.; w[1] = "def"],
    Internal`SetValueMonitor[w, False]];
  Internal`BagPart[bag, All]]
(* {"HoldComplete[w, Null, {1, 2}, OwnValues]", "HoldComplete[w, w[[1]], 5, Part]", "HoldComplete[w, {5, 2}, {5, 2, 3}, OwnValues]",
    "HoldComplete[w, Block, True]", "HoldComplete[w, Null, 0, OwnValues]", "HoldComplete[w, 0, 1, OwnValues]", "HoldComplete[w, Block, False]",
    "HoldComplete[w, OwnValues]", "HoldComplete[w, w[1], \"def\", Removed[\"$$Failure\"], DownValues]"} *)
```

- Events carry the full old and new values (`HoldComplete[x, old, new, OwnValues]`); `Part` assignments, `Unset`
  (`HoldComplete[x, OwnValues]`), `Clear` (`HoldComplete[x, Clear]`), entering and leaving a `Block`, and new
  definitions (`DownValues`, `UpValues`, `DefaultValues` events) are reported. A `Module` variable with the same name
  is a different symbol and is not reported.
- **Convert events to strings before returning them.** Definition events contain a special removed-symbol object
  (`Removed["$$Failure"]`) that cannot be serialized: in MCP Local a result containing one comes back as
  `BinarySerialize::serializefail` and `Out[n]= $Failed` (MCP Session returns it).
- The flag survives `ClearAll[x]` (``Internal`GetValueMonitor[x]`` stays `True`): always reset it in the cleanup.
- It works on system variables too (`$ContextPath` during ``Needs["CodeParser`"]``: 309 events) and costs little until a
  handler is installed; a tight loop then produced about 700,000 events per second, so count or cap what you store.
- The handler's return value is ignored and it runs after the assignment. ``WolframDebugging`WatchChanges[{x, y}, expr]``
  records changes with their callers.

Stop at the first bad value: `Throw` from the handler.

```wl
ClearAll[state];
state = 0;
{Module[{tag},
   Catch[
     Internal`WithLocalSettings[
       Internal`SetValueMonitor[state, True],
       Internal`HandlerBlock[{"ValueChange", Function[ev,
           If[MatchQ[ev, HoldComplete[state, _, new_ /; new > 2, OwnValues]], Throw[ev, tag]]]},
         Do[state = k, {k, 5}]; "no bad value"],
       Internal`SetValueMonitor[state, False]],
     tag]],
 state}
(* {HoldComplete[state, 2, 3, OwnValues], 3} *)
```

Add `Stack[_]` to the thrown value to see the caller (``WolframDebugging`StopWhen[state, # > 2 &, expr]`` does that). A
`Catch[..., _]` in the code under test can eat the `Throw`; then record without throwing as above.

Freeze a variable and report who tries to change it: ``Internal`ValueChangeVeto[x, True]`` plus a `"VetoableValueChange"`
handler that returns `False` blocks the assignment:

```wl
ClearAll[limit, setLimit, configure];
limit = 5; setLimit[n_] := (limit = n); configure[] := setLimit[99];
Module[{bag = Internal`Bag[]},
  Internal`WithLocalSettings[
    Internal`ValueChangeVeto[limit, True],
    Internal`HandlerBlock[{"VetoableValueChange", Function[ev,
        If[MatchQ[ev, HoldComplete[limit, ___]],
          Internal`StuffBag[bag, {ev, Cases[Stack[_], _[h_Symbol[___]] /; MemberQ[{"Global`", $Context}, Context[h]] :>
              SymbolName[Unevaluated[h]], {1}]}]; False,     (* False blocks the assignment *)
          True]]},
      StackBegin[StackComplete[configure[]]]],
    Internal`ValueChangeVeto[limit, False]];
  {limit, Internal`BagPart[bag, All]}]
(* {5, {{HoldComplete[limit, Null, 99, OwnValues], {"configure", "setLimit"}}}} *)
```

The second element of a veto event is `Null`, not the old value. MCP kernels already have a J/Link veto handler; it only
acts on Java objects and composes with yours (return `True` for everything you do not block).

## Other handler probes

All of these are scoped with ``Internal`HandlerBlock[{"Type", f}, expr]`` (one type per block; nest blocks for more) and
worked in MCP Local, MCP Session and wolframscript. ``Internal`Handlers[]`` lists the handler types.

Symbols created while code runs (`ToExpression`, `Get`, `Symbol["..."]`): typos and context leaks while loading code.
The argument is one list ``{"name", "context`"}``, and the handler runs before the symbol exists:

```wl
Module[{log = Internal`Bag[]},
  Internal`HandlerBlock[{"NewSymbol", Internal`StuffBag[log, #] &},
    ToExpression["newSymA + Global`newSymB; myCtx`newSymC; Module[{tmpq}, tmpq]"]];
  Internal`BagPart[log, All]]
(* wolframscript: {{"newSymA", "Global`"}, {"newSymB", "Global`"}, {"newSymC", "myCtx`"}, {"tmpq", "Global`"}}
   MCP Local and MCP Session: "Sessions`<id>`" instead of "Global`" for newSymA and tmpq *)
```

Symbols typed in an MCP call are created when their input (a line or a multi-line expression) is parsed, before any
handler in it runs, so this only sees run-time symbols (``WolframDebugging`NewSymbolsDuring[expr]``).

Files an evaluation writes (notification only: returning `False` does not prevent the write; `CopyFile`, `CreateFile`
and `ExportString` are not reported):

```wl
Module[{log = Internal`Bag[], file = FileNameJoin[{$TemporaryDirectory, "openwrite-demo.txt"}]},
  Internal`HandlerBlock[{"Wolfram.File.OpenWrite", Internal`StuffBag[log, #] &},
    Export[file, "x", "Text"]; Put[1, file]; WriteString[file, "y"]; Close[file]; DeleteFile[file]];
  Replace[Internal`BagPart[log, All], HoldComplete[h_, f_String] :> {h, FileNameTake[f]}, {1}]]
(* {{OpenWrite, "openwrite-demo.txt"}, {Put, "openwrite-demo.txt"}, {WriteString, "openwrite-demo.txt"}} *)
```

(``WolframDebugging`FileWritesDuring[expr]``.) Failing `Assert` calls, although `Assert` is `Off` by default:

```wl
ClearAll[check]; check[x_] := (Assert[x > 0, "x must be positive"]; Sqrt[x]);
Module[{bag = Internal`Bag[]},
  {Internal`HandlerBlock[{"Assertions", Internal`StuffBag[bag, #] &}, check[-1] + check[4]], Internal`BagPart[bag, All]}]
(* {2 + I, {HoldComplete[Assert[-1 > 0, "x must be positive"]]}} *)
```

While an `"Assertions"` handler is installed, every `Assert` evaluates its test (normally skipped while `Assert` is Off),
so side effects in tests run. Only failing assertions reach the handler (``WolframDebugging`FailedAssertions[expr]``).

Capture `Print` and `Echo` output as data, without printing:

```wl
ClearAll[noisy]; noisy[] := (Print["step 1"]; Echo[2, "value:"]; 42);
Module[{bag = Internal`Bag[]},
  {Block[{Print = Function[Null, Internal`StuffBag[bag, HoldComplete[##]], HoldAllComplete]}, noisy[]],
   Internal`BagPart[bag, All]}]
(* {42, {HoldComplete["step 1"], HoldComplete[">> ", "value:", " ", Unevaluated[2]]}} *)
```

`Print` capture works in every environment, but `Echo` goes through `Print` only outside the cloud: CloudEvaluate,
deployed APIs and the remote MCP server gave `{42, {HoldComplete["step 1"]}}`.

A `"Wolfram.System.Print.Veto"` handler that returns `False` suppresses prints only in MCP Local and wolframscript; MCP
Session (and the remote MCP server) capture the print before your handler runs:

```wl
Internal`HandlerBlock[{"Wolfram.System.Print.Veto", False &}, Print["vetoed print"]; "done"]
(* MCP Local, wolframscript: "done"     MCP Session: During evaluation of In[1]:= vetoed print / Out[1]= "done" *)
```

`EvaluationData[expr]["OutputLog"]` records prints as strings but still lets them print; in MCP Session and on the
remote MCP server it stays `{}`, because their evaluator takes the print first
(``WolframDebugging`CapturePrints[expr, max]`` and ``WolframDebugging`CaptureEvaluation[expr]``).
