# Definitions and source code

How to see what a symbol really does at run time (ReadProtected, Locked, kernel code, autoload stubs) and how to find the
source file and lines that define it (System functions implemented in paclets, package functions, your own files).
Read it when you need the definition of a function you did not write, want to read its source, or need to know which
copy of a package is in use. Behavior was checked with Wolfram 15.0 in MCP Local and wolframscript (see
`Environments.md` for these names).

## Which tool for which question

| question | first choice | section |
|---|---|---|
| what are the rules of `f` right now? | SymbolDefinition MCP tool; ``WolframDebugging`ShowDefinition[f]`` | Read the runtime definition |
| `Definition[f]` shows nothing useful | ReadProtected, autoload stub, kernel code or Locked: check `Attributes`, `OwnValues`; ``WolframDebugging`SymbolKind[f]`` | same |
| a compact overview of a big function | `Keys[DownValues[f]]`, usage text, dependency list | Compact views |
| where is `f` defined (file and lines)? | contexts → `FindFile`/`PacletFind` → grep or CodeParser; ``WolframDebugging`FindSymbolSource["f"]`` | Find the source file |
| which installed copy is in use? | `PacletFind[<\|"Context" -> ctx\|>]` + `$LoadedFiles` | Which copy is loaded |
| full name of a symbol, which paclet declares it | ``Names["*`name"]``, Kernel extension scan | Names, paclets, message texts |
| text of a message | `sym::tag` with `General::tag` fallback; grep the message files | same |
| documentation of a paclet symbol | ``Documentation`ResolveLink`` + the ReadNotebook MCP tool | same |
| which option values does a call use? | `OptionValue[f, {opts}, {names}]`, `Trace[call, _OptionValue]` | Effective options |

Helpers are in `scripts/WolframDebugging.wl` (load it with `Get` in its own call, call them fully qualified; options and
outputs: `HelperFunctions.md`). Everything below works without them.

The source is better for reading (comments, formatting, macros as written); the runtime definition is better for
predicting behavior (it is what actually runs, after load-time macro expansion and with later redefinitions). Use both.

## Read the runtime definition

### The SymbolDefinition MCP tool

- Runs in the same kernel as the evaluator, so it sees your session's definitions and whatever packages that kernel has
  loaded. It bypasses ReadProtected and formats the result readably.
- Symbols you defined need their full name, ``Sessions`<id>`f``. A bare name gives `Error: Symbol "f" does not exist`
  plus a "Did you mean" list with the right full name (in MCP Local a bare name does find the symbols of the session
  that made the latest evaluator call, whichever session that was).
- The `Attributes` line omits ReadProtected (it is cleared before formatting): `CloudPut // Attributes = { Protected }`
  although `Attributes[CloudPut]` is `{Protected, ReadProtected}`.
- Kernel functions show pseudo-rules: `+___ := "<kernel function>"` for `Plus`.
- Autoload stubs are shown as stubs (`GroupOrder := AutoLoad[Hold @ GroupOrder, ...]`); the tool does not load them.
  Evaluate the bare symbol (`GroupOrder;`) in the evaluator first, then ask again.
- Locked symbols: "No definitions found" for `$CommandLine` (Locked, with a value: use `Definition` directly, see below);
  `Error: ... is Locked and ReadProtected` when nothing can show them.
- Use `maxLength` to keep the output small (default 10000 characters; `CloudPut` alone is 2555).
- The wolfram-language skill's `SymbolDefinition.wls` script starts a fresh kernel with the installed AgentTools: it shows
  stubs for every autoloaded System function (`CloudPut = ActivateLoad[CloudPut, {URLDispatcher, ...`) and never sees
  your evaluator definitions. Use the MCP tool, or a wolframscript that loads the symbol first.
- The remote MCP server has no SymbolDefinition tool; use the recipes below in its evaluator.

### ReadProtected: `DownValues` still works, `Definition` does not

`ReadProtected` hides rules only from `Definition`, `FullDefinition`, `??` and ``Language`ExtendedDefinition``;
`DownValues`, `UpValues`, `SubValues`, `OwnValues`, `Options`, `Messages` and `Attributes` work as usual:

```wl
CloudPut;   (* evaluating the bare symbol loads an autoload stub; nothing else happens *)
{Attributes[CloudPut], Length[DownValues[CloudPut]], Length[Options[CloudPut]],
 StringTake[ToString[Definition[CloudPut], InputForm], UpTo[70]]}
(* {{Protected, ReadProtected}, 7, 13, "Attributes[CloudPut] = {Protected, ReadProtected}\n \nOptions[CloudPut] "} *)
```

Full `Definition` text: clear ReadProtected inside ``Internal`InheritedBlock`` (restored when the block exits) and convert
to a string inside the block:

```wl
CloudPut;
Internal`InheritedBlock[{CloudPut},
  ClearAttributes[CloudPut, ReadProtected];
  StringTake[ToString[Definition[CloudPut], InputForm], UpTo[250]]]
(* "Attributes[CloudPut] = {Protected}\n \nCloudPut[CloudObject`Private`expr_, CloudObject`Private`opts:OptionsPattern[]] :=
    CloudObject`Private`WithProgressReporting[CloudObject`Private`cloudPut[Unevaluated[CloudObject`Private`expr], ..." *)
```

- The `ToString` must be inside the block: a `Definition[...]` returned from the block is formatted after ReadProtected
  is back and shows no rules (460 characters of attributes and options instead of 2664 for `CloudPut`).
- Never `ClearAttributes[s, ReadProtected]` outside the block in an MCP kernel: it is permanent and shared.
- Without the leading `CloudPut;` a fresh kernel (wolframscript) shows the autoload stub instead of the rules
  (``CloudPut = Package`ActivateLoad[CloudPut, {URLDispatcher, ...``).
- The same applies to your own or package symbols. Some packages set ReadProtected on their symbols when built as `.mx`
  files (AgentTools does for its public symbols; see `Testing.md` for the CI consequence). ``Language`ExtendedDefinition``
  silently returns an empty list then:

```wl
ClearAll[rpDemo]; rpDemo[x_] := x + 1; SetAttributes[rpDemo, ReadProtected];
{DownValues[rpDemo], ToString[Definition[rpDemo], InputForm], Language`ExtendedDefinition[rpDemo],
 Internal`InheritedBlock[{rpDemo}, ClearAttributes[rpDemo, ReadProtected]; ToString[Definition[rpDemo], InputForm]]}
(* wolframscript: {{HoldPattern[rpDemo[x_]] :> x + 1}, "Attributes[rpDemo] = {ReadProtected}", Language`DefinitionList[], "rpDemo[x_] := x + 1"} *)
```

Helper: ``WolframDebugging`ShowDefinition[sym, n]`` (the InheritedBlock recipe with short contexts, at most `n` characters).

### Kernel functions: no rules to show

Many System functions are implemented in C. They have no `DownValues`; ``System`Private`HasDownCodeQ`` tells (it holds
its argument, so a stub is not loaded):

```wl
{DownValues[Plus], ToString[Definition[Plus], InputForm],
 System`Private`HasDownCodeQ /@ Unevaluated[{Plus, Table, CloudPut}]}
(* {{}, "Attributes[Plus] = {Flat, Listable, NumericFunction, OneIdentity, Orderless, Protected}\n \nDefault[Plus] := 0", {True, True, False}} *)
```

For kernel functions, read the documentation (WolframLanguageContext tool), `SyntaxInformation[f]` and the messages they
issue. Some System functions (e.g. `Integrate`) have both kernel code and WL rules loaded from the kernel's own `.mx`
files (no source ships for those).

### Autoload stubs

Many System functions are stubs until first use. The stub is an OwnValue; looking at it does not load anything:

```wl
stubQ = Function[s, ! FreeQ[Quiet[OwnValues[s]], Package`ActivateLoad | System`Dump`AutoLoad], HoldAllComplete];
{stubQ[ResourceData], stubQ[GroupOrder], stubQ[Plus],
 StringTake[ToString[OwnValues[ResourceData], InputForm], UpTo[150]],
 StringTake[ToString[OwnValues[GroupOrder], InputForm], UpTo[75]]}
(* wolframscript: {True, True, False,
     "{HoldPattern[ResourceData] :> Package`ActivateLoad[ResourceData, {ResourceData}, \"DataResourceLoader`\", {Package`HiddenImport -> True, Path -> Automat",
     "{HoldPattern[GroupOrder] :> System`Dump`AutoLoad[Hold[GroupOrder], Hold[Gro"}
   MCP Local: {False, False, False, "{}", "{}"}   -- both already loaded by earlier calls in that long-running kernel *)
```

- ``Package`ActivateLoad[sym, {syms}, "LoaderContext`", opts]`` = a paclet's Kernel extension (loads ``LoaderContext` ``,
  the whole package); ``System`Dump`AutoLoad[Hold[sym], Hold[group], "Ctx`"] /; System`Dump`TestLoad`` = kernel
  `SystemResources` `.mx` files. The context in the stub tells you where the code lives.
- Inspecting (`DownValues`, `Definition`, `Attributes`, the SymbolDefinition tool) does not load a stub; evaluating the
  bare symbol (`sym;`) or `Options[sym]` does. Load before you inspect or override (details: `PackageLoading.md`).
- Helpers: ``WolframDebugging`SymbolKind[sym]`` (attributes, stub, kernel code, value counts, usage),
  ``WolframDebugging`AutoloadStubQ[sym]``, ``WolframDebugging`EnsureLoaded[sym]``.

### Locked symbols

`Block` and ``Internal`InheritedBlock`` cannot localize a Locked symbol (`::lockv`, or `Block::lockt` with an initial
value; the InheritedBlock message has no text: "-- Message text not found --"), so every InheritedBlock-based tool
fails on them. A Locked symbol without ReadProtected can be read directly:

```wl
{Attributes[$CommandLine], Length[OwnValues[$CommandLine]],
 StringTake[ToString[Definition[$CommandLine], InputForm], UpTo[48]],
 Quiet[Internal`InheritedBlock[{$CommandLine}, 1]]}
(* {{Locked, Protected}, 1, "Attributes[$CommandLine] = {Locked, Protected}\n ", Internal`InheritedBlock[{$CommandLine}, 1]} *)
```

Locked and ReadProtected together (``System` ``: `I`, `$InputStreamMethods`, `$OutputStreamMethods`, plus some package
internals): nothing shows them. `OwnValues`/`DownValues` give `General::readp` and `$Failed`, `ClearAttributes` fails
(`Attributes::locked`):

```wl
{Attributes[$InputStreamMethods], Quiet[OwnValues[$InputStreamMethods]],
 Quiet[Internal`InheritedBlock[{$InputStreamMethods}, ClearAttributes[$InputStreamMethods, ReadProtected]]]}
(* {{Locked, Protected, ReadProtected}, $Failed, Internal`InheritedBlock[{$InputStreamMethods}, ClearAttributes[...]]} *)
```

Never set `Locked` on anything in a shared kernel: it cannot be undone for the rest of the kernel session.

### Compact views of a big function

Signatures only (the left-hand sides, in the order the evaluator tries them):

```wl
CloudPut;
Block[{$ContextPath = Join[{"CloudObject`Private`"}, $ContextPath]},
  ToString[#, InputForm] & /@ Keys[DownValues[CloudPut]]]
(* {"HoldPattern[CloudPut[expr_, opts:OptionsPattern[]]]", "HoldPattern[CloudPut[expr_, obj_CloudObject, opts:OptionsPattern[]]]",
    "HoldPattern[CloudPut[expr_, uri_String, opts:OptionsPattern[]]]", "HoldPattern[CloudPut[expr_, uriwrapper:_URL | _Hyperlink, opts:OptionsPattern[]]]",
    "HoldPattern[CloudPut[expr_, failureObj_Failure, opts:OptionsPattern[]]]", "HoldPattern[CloudPut[expr_, obj_, opts:OptionsPattern[]]]",
    "HoldPattern[e:CloudPut[args___]]"} *)
```

Putting the definition's private context on `$ContextPath` while formatting shortens the names. The order of
`DownValues` is the kernel's try order (more specific first, literal arguments before patterns), not source order; here
the `_Failure` rule is 5th at run time but last in the source, and `_URL | _Hyperlink` was written `$LinkWrappers` (a
macro expanded at load time).

Usage as plain text (usage strings contain box syntax):

```wl
StringRiffle[ToString[#, OutputForm] & /@ StringSplit[CloudPut::usage, "\n"], "\n"]
(* "CloudPut[expr] writes expr to a new anonymous cloud object.\nCloudPut[expr, \"uri\"] writes expr to a cloud object at a given URI.\n..." *)
```

Package usage messages exist only after the package is loaded. `Definition` does not include `::usage`.

Helper functions a definition uses (the symbols it references, with their own definitions). The default
`"ExcludedContexts" -> Automatic` also drops package contexts, and ReadProtected symbols are skipped silently:

```wl
CloudPut;
With[{d = Language`ExtendedFullDefinition[CloudObject`Private`cloudPut, "ExcludedContexts" -> {"System`"}]},
  {Length[d], Take[Cases[List @@ d, (_[s_] -> defs_) :> {ToString[Unevaluated[s], InputForm], Length[Lookup[defs, DownValues]]}], UpTo[3]]}]
(* {11, {{"CloudObject`Private`cloudPut", 2}, {"CloudObject`Private`opts", 0}, {"CloudObject`Private`handleCBase", 4}}} *)
```

`DownValues`, `Attributes`, `Options` and friends hold their argument: inside `Module` they inspect the local variable.
Use `With` to insert the symbol:

```wl
ClearAll[hdDemo]; hdDemo[x_] := x;
{Module[{h = hdDemo}, DownValues[h]], With[{h = hdDemo}, DownValues[h]]}
(* {{}, {HoldPattern[hdDemo[x_]] :> x}} *)
```

## Find the source file

Works when the package ships `.wl`/`.m` source (most paclets in `$InstallationDirectory/SystemFiles/Components`,
`SystemFiles/Links`, `AddOns/Applications` and the user paclet repository do). The steps: context → entry file → paclet
root → search.

### 1. Which context holds the code?

For a System function implemented in a paclet, `Context["CloudPut"]` is just ``System` ``. Look at the contexts of the
symbols inside its definition (or at the loader context in its stub), then give `FindFile` the package context without
trailing ``Private` `` parts:

```wl
CloudPut;
{DeleteDuplicates @ Cases[DownValues[CloudPut], s_Symbol :> Context[Unevaluated[s]], Infinity, Heads -> True],
 FindFile["CloudObject`"], FindFile["CloudObject`Private`"]}
(* {{"System`", "CloudObject`Private`", "System`Private`"}, "~/.Wolfram/Paclets/Repository/CloudObject-15.0.9/Kernel/CloudObject.m", $Failed} *)
```

### 2. The paclet root

For a context, ask the paclet manager (all candidates, the one in use first):

```wl
{#["Name"], #["Version"], #["Location"]} & /@ PacletFind[<|"Context" -> "CloudObject`"|>]
(* {{"CloudObject", "15.0.9", "~/.Wolfram/Paclets/Repository/CloudObject-15.0.9"},
    {"CloudObject", "15.0.0", "/usr/local/Wolfram/Wolfram/15.0/SystemFiles/Links/CloudObject"}} *)
```

For a file, walk up to the directory with `PacletInfo.wl`/`PacletInfo.m`. The often-quoted
`NestWhile[DirectoryName, file, Not @* PacletObjectQ @* PacletObject @* File]` works for files inside a paclet (with a
``PacletManager`CreatePaclet::badarg`` message for every level below the root) but **never terminates** for a file outside
one: `DirectoryName["/"]` is `""`, `DirectoryName[""]` is `""` again, and `PacletObject[File[""]]` is a `Failure`. Capped
at 6 steps, the loop sits on `""`:

```wl
{TimeConstrained[Quiet @ NestWhile[DirectoryName, "/tmp/foo/bar.m", Not @* PacletObjectQ @* PacletObject @* File], 2],
 Quiet @ NestWhileList[DirectoryName, "/tmp/foo/bar.m", Not @* PacletObjectQ @* PacletObject @* File, 1, 6]}
(* {$Aborted, {"/tmp/foo/bar.m", "/tmp/foo/", "/tmp/", "/", "", "", ""}} *)
```

A version that always stops (at most 64 levels, without the final `""`):

```wl
pacletRootOf[file_String] := SelectFirst[
  DeleteCases[Rest @ NestWhileList[DirectoryName, file, StringLength[#] > 0 &, 1, 64], ""],
  FileExistsQ[FileNameJoin[{#, "PacletInfo.wl"}]] || FileExistsQ[FileNameJoin[{#, "PacletInfo.m"}]] &,
  Missing["NotInPaclet", file]];
{pacletRootOf[FindFile["CloudObject`"]], pacletRootOf[FindFile["CodeParser`"]], pacletRootOf["/tmp/foo/bar.m"]}
(* {"~/.Wolfram/Paclets/Repository/CloudObject-15.0.9/", "/usr/local/Wolfram/Wolfram/15.0/SystemFiles/Components/CodeParser/",
    Missing["NotInPaclet", "/tmp/foo/bar.m"]} *)
```

(The result ends in `/`, as `DirectoryName` returns it.) Helper: ``WolframDebugging`PacletRoot[file]`` (no trailing `/`,
`Missing["NotFound", file]` outside paclets).

The source files of the paclet, relative to its root:

```wl
With[{root = First[PacletFind[<|"Context" -> "CloudObject`"|>]]["Location"]},
  {Length[#], Take[#, 4]} &[StringDelete[FileNames[{"*.wl", "*.m"}, root, Infinity], StartOfString ~~ root ~~ "/"]]]
(* {62, {"Kernel/AccountData.m", "Kernel/BackupUtilities.wl", "Kernel/CharacterEncoding.m", "Kernel/CloudBase.m"}} *)
```

### 3. Search the files

**grep with your own file tools** (fast; finds top-level definitions written at column 0, including `e : f[...] :=`,
`Options[f] =` and `Attributes[f] =`; misses definitions indented or nested in `With`/`Module`):

```bash
grep -rnE --include='*.m' --include='*.wl' '^([A-Za-z$][A-Za-z0-9$]* *: *)?(HoldPattern\[)?(Options\[|Attributes\[)?CloudPut\b' <paclet root>
# Kernel/GetPutSave.m:254:Options[CloudPut] = $defaultOptions[CloudPut] = sortOptions @ objectFunctionOptionsJoin[
# Kernel/GetPutSave.m:518:CloudPut[expr_, opts : OptionsPattern[]] :=
# Kernel/GetPutSave.m:521:CloudPut[expr_, obj_CloudObject, opts:OptionsPattern[]] :=
# ... 540, 546, 549
# Kernel/GetPutSave.m:555:e : CloudPut[args___] := Null /; (System`Private`Arguments[e, {1, 2}]; False)
# Kernel/GetPutSave.m:557:CloudPut[expr_, failureObj_Failure, opts:OptionsPattern[]] := failureObj
```

A plain `'^CloudPut\['` misses the `e : CloudPut[...]` and `Options[CloudPut]` lines. Then read the lines around each hit.

**``GeneralUtilities`FindDefinition``** (preloaded; a first guess): `FileLine[file, line]` of the first match of a line
regex; `$Failed` for the `.wl`-based paclets tried (CodeParser, AgentTools), `.mx`-only code and kernel functions. It can
also land on a message line (`ResourceData` → `DataResource/Kernel/Messages.m:24`, a `ResourceData::elemstring` text).

```wl
{GeneralUtilities`FindDefinition[CloudPut], GeneralUtilities`FindDefinition[CodeParser`CodeParse],
 GeneralUtilities`FindDefinition[Plus]}
(* {GeneralUtilities`FileLine["~/.Wolfram/Paclets/Repository/CloudObject-15.0.9/Kernel/GetPutSave.m", 518], $Failed, $Failed} *)
```

**CodeParser** (exact source text of each top-level definition). The parser annotates top-level `Set`/`SetDelayed`/
`TagSet`/`UpSet` nodes with a `"Definitions"` list; with `"SourceCharacterIndex"` the `Source` is a character range for
`StringTake`. Use fully qualified CodeParser names: typed in the same input as the `Needs`, short names are created in your
own context and the pattern silently matches nothing:

```wl
Needs["CodeParser`"];   (* full names below, so this works in the same input *)
Module[{file, ast, pos},
  file = FileNameJoin[{First[PacletFind[<|"Context" -> "CloudObject`"|>]]["Location"], "Kernel", "GetPutSave.m"}];
  ast = CodeParser`CodeParse[File[file], "SourceConvention" -> "SourceCharacterIndex"];   (* never print an AST *)
  pos = Cases[ast, _[_, _, KeyValuePattern[{"Definitions" -> {CodeParser`LeafNode[Symbol, "CloudPut" | "System`CloudPut", _]},
      CodeParser`Source -> p_}]] :> p, Infinity];
  {Length[pos], StringTake[ReadString[file], pos[[{1, -1}]]]}]
(* {7, {"CloudPut[expr_, opts : OptionsPattern[]] :=\n    WithProgressReporting[cloudPut[Unevaluated[expr], saveDefToIncludeDef[{opts}]]]",
        "CloudPut[expr_, failureObj_Failure, opts:OptionsPattern[]] := failureObj"}} *)
```

- The name in `"Definitions"` is the literal source text: match both `"f"` and ``"Ctx`f"``.
- Only top-level assignments are annotated (`f[a_] := 1;` alone on its line is): definitions inside `With`/`Module`/`If`
  and both definitions of `f[a_] := 1; f[b_] := 2` on one line are not. `f::usage`, `Options[f] =`, `Attributes[f] =`
  and `Format[f] :=` carry `"AdditionalDefinitions"` instead.
- Without `"SourceConvention"`, `Source` is `{{line1, col1}, {line2, col2}}` (line numbers for your Read tool).
- Parse only the files that mention the name (prefilter with `StringContainsQ[ReadString[f], name]`): a whole large paclet
  takes seconds.

Helper: ``WolframDebugging`FindSymbolSource["Ctx`name"]`` does all three steps (contexts from the definition or stub,
paclet roots, CodeParser including nested definitions, fallback to `$LoadedFiles` for loose files) and returns file, line
range, kind and a text preview per definition.

### Which copy is loaded

`FindFile` and `PacletFind` name the copy the next `Get` would load: the highest version, so updated system paclets in
the user paclet repository (`~/.Wolfram/Paclets/Repository`) shadow the installation's copy, and a newer installed
paclet beats a development checkout added with `PacletDirectoryLoad`. `$LoadedFiles` is what this kernel actually read:

```wl
CloudPut;
{FindFile["CloudObject`"], Take[Select[$LoadedFiles, StringContainsQ["CloudObject"]], UpTo[2]]}
(* {"~/.Wolfram/Paclets/Repository/CloudObject-15.0.9/Kernel/CloudObject.m",
    {"~/.Wolfram/Paclets/Repository/CloudObject-15.0.9/Kernel/CloudObjectLoader.m", "~/.Wolfram/Paclets/Repository/CloudObject-15.0.9/Kernel/CloudObject.m"}} *)
```

Read the source of the copy that `$LoadedFiles` lists. After a `.mx` build or an edit made after the kernel started, the
source and the running code differ (`PackageLoading.md`).

### No source: `.mx`-only components and kernel code

Some components ship only a loader and a compiled `.mx` file (in 15.0 among others GeneralUtilities, Dataset, Forms,
Templating, URLUtilities, TypeSystem, NeuralNetworks, Authentication, Streaming). Kernel functions and the kernel's own
`SystemFiles/Kernel/SystemResources/*.mx` code never ship source. Check before you search:

```wl
With[{root = First[PacletFind[<|"Context" -> "GeneralUtilities`"|>]]["Location"]},
  {root, FileNameTake /@ FileNames["*.mx", root, Infinity], FileNameTake /@ FileNames[{"*.m", "*.wl"}, root, Infinity]}]
(* {"/usr/local/Wolfram/Wolfram/15.0/SystemFiles/Components/GeneralUtilities", {"GeneralUtilities.mx"},
    {"GeneralUtilitiesLoader.m", "GeneralUtilities.m", "PacletInfo.m"}} *)
```

`.mx` files present and no grep hits: only the runtime definition is available (SymbolDefinition tool, `DownValues`).

## Names, paclets and message texts

### Names

```wl
CloudPut;
{Names["*InheritedBlock*"], Names["*`*InheritedBlock*"], Names["*`*CloudPut*"], Names["CloudObject`Private`cloudPut*"],
 Names["CloudPu", SpellingCorrection -> True], Context["CloudPut"]}
(* {{}, {"Internal`InheritedBlock"}, {"CloudPut", "CloudObject`Private`iCloudPut"}, {"CloudObject`Private`cloudPut"}, {"CloudPut"}, "System`"} *)
```

- Without a backtick in the pattern, `Names` searches only `$Context` and `$ContextPath`: use ``"*`*name*"`` to search all
  contexts. Symbols on the context path come back short (`"CloudPut"`).
- ``Names["*`name"]`` lists every context that has a symbol called `name` (shadowing check, see `PackageLoading.md`).
- ``Names["*`*"]`` has about 63,000 entries in a fresh kernel and over 200,000 in MCP Local: always wrap searches in
  `Length` or `Take`.
- Typing an unknown name creates the symbol in your context, where it can shadow a package symbol. Pass names as
  strings:

```wl
{Quiet[Context["dsNoSuchName"]], Names["*`dsNoSuchName"], Context[dsNoSuchName2], Names["*`dsNoSuchName2"]}
(* wolframscript: {Context["dsNoSuchName"], {}, "Global`", {"dsNoSuchName2"}}
   MCP evaluator: {Context["dsNoSuchName"], {}, "Sessions`<id>`", {"dsNoSuchName2"}} *)
```

### PacletFind pitfalls

Only `"Context"` filters an association query; any other key (`"Symbol"`, `"Symbols"`, a typo) is ignored silently and
returns every paclet:

```wl
{Length[PacletFind[All]], Length[PacletFind[All, <|"Symbol" -> "System`CloudPut"|>]],
 #["Name"] & /@ PacletFind[All, <|"Context" -> "CodeParser`"|>]}
(* {355, 355, {"CodeParser"}}   (the count depends on the installation) *)
```

Which paclet declares an autoloaded System symbol (scan the Kernel extensions; well under 0.1 s):

```wl
{#["Name"], #["Version"]} & /@ Select[PacletFind[All],
  MemberQ[Flatten @ Cases[#["Extensions"], {"Kernel", ___, "Symbols" -> s_, ___} :> s], "System`CloudPut"] &]
(* {{"CloudObject", "15.0.9"}, {"CloudObject", "15.0.0"}} *)
```

Never return a `PacletObject` or `PacletFind[All]` itself: each object prints its whole PacletInfo. Take properties
(`#["Name"]`, `#["Version"]`, `#["Location"]`).

### Message texts

`Message` looks for `sym::tag` first and falls back to `General::tag`; `Messages[sym]` lists only the specific texts, and
system texts are loaded lazily (in a fresh kernel `Messages[General]` has only about 75 entries), so neither list is
complete. A lookup that mirrors `Message`:

```wl
msgText = Function[{s, tag}, Replace[MessageName[s, tag],
    _MessageName :> Replace[MessageName[General, tag], _MessageName :> Missing["NoText", tag]]], HoldFirst];
CloudPut;
{msgText[CloudPut, "invcloudobj"], msgText[Power, "infy"], msgText[Block, "lockv"], msgText[Internal`InheritedBlock, "lockv"]}
(* {"`1` is not a valid cloud object.", "Infinite expression `1` encountered.",
    "Cannot localize locked symbol `1` in local variable specification `2`.", Missing["NoText", "lockv"]} *)
```

`Missing["NoText", ...]` is what prints as "-- Message text not found --". To find a message by its text, grep the files:
system texts are in `$InstallationDirectory/SystemFiles/Kernel/TextResources/English/Messages.m` (e.g. line 1537
``General::infy = "Infinite expression `1` encountered."``); package texts are in the package source
(`grep -rn 'invcloudobj *=' <paclet root>` → `Kernel/Messages.m:127:General::invcloudobj = ...`).

### Documentation

```wl
{Documentation`ResolveLink["paclet:ref/CloudPut"], Information[CloudPut, "Documentation"],
 Documentation`ResolveLink["paclet:Wolfram/AgentTools/ref/CreateMCPServer"]}
(* {URL["https://reference.wolfram.com/language/ref/CloudPut.html?v=15.0"], <|"Web" -> "http://reference.wolfram.com/language/ref/CloudPut.html"|>,
    ".../Documentation/English/ReferencePages/Symbols/CreateMCPServer.nb"}
   wolframscript: the installed paclet's notebook (~/.Wolfram/Paclets/Repository/Wolfram__AgentTools-2.2.0/...);
   MCP Local: the development checkout loaded by that server -- the same version shadowing as for code *)
```

- Paclet symbols: `ResolveLink["paclet:Publisher/Paclet/ref/Name"]` gives the local reference notebook; read it with the
  ReadNotebook MCP tool (as Markdown; reference pages are long). The pattern is
  `<paclet root>/Documentation/English/ReferencePages/Symbols/<Name>.nb`.
- System symbols: installations without local reference pages (the Linux installation checked here has none) get the
  web URL from `ResolveLink`. Use the WolframLanguageContext MCP tool.

## Effective options

```wl
ClearAll[optDemo]; Options[optDemo] = {"A" -> 1, "B" -> 2};
optDemo[x_, opts : OptionsPattern[]] := {x, OptionValue["A"], OptionValue["B"]};
{OptionValue[optDemo, {"A" -> 7}, {"A", "B"}], Options[optDemo, "B"], OptionValue[CloudPut, {}, {CloudBase, Permissions}],
 Internal`InheritedBlock[{optDemo}, SetOptions[optDemo, "A" -> 99]; optDemo[0]], optDemo[0]}
(* {{7, 2}, {"B" -> 2}, {Automatic, Automatic}, {0, 99, 2}, {0, 1, 2}} *)
```

- `OptionValue[f, {opts}, {names}]`: the values a call with `opts` gets (explicit options, then `Options[f]`).
- Try a different default without leaking it: `SetOptions` inside ``Internal`InheritedBlock[{f}, ...]``. A plain
  `SetOptions` in an MCP kernel changes the option for every session.
- `Options[stub]` loads an autoload stub (it evaluates its argument).

Where Trace works (MCP Local, wolframscript; not in MCP Session or the cloud), see the options a call really received:

```wl
ClearAll[optDemo]; Options[optDemo] = {"A" -> 1, "B" -> 2};
optDemo[x_, opts : OptionsPattern[]] := {x, OptionValue["A"], OptionValue["B"]};
Trace[optDemo[0, "A" -> 10], _OptionValue]
(* {{HoldCompleteForm[OptionValue[optDemo, {"A" -> 10}, "A"]]}, {HoldCompleteForm[OptionValue[optDemo, {"A" -> 10}, "B"]]}}
   (MCP Local shows Sessions`<id>`optDemo; MCP Session gives {}) *)
```

## Environment notes

- MCP Local and MCP Session: long-running kernels with many packages already loaded; which System functions are still
  stubs depends on what earlier calls used. wolframscript: a fresh kernel, so most System packages are stubs until used.
- CloudEvaluate: `Definition` is broken there (`CloudEvaluate[ToString[Definition[Plus], InputForm]]` gives `"$Failed"`
  with `SetDelayed::write` and `Attributes::attnf` messages; the InheritedBlock recipe fails the same way) while
  `DownValues` works; use `DownValues`/`OwnValues`. Source files exist in cloud kernels too, and
  ``GeneralUtilities`FindDefinition`` works there.
- Remote MCP server: no SymbolDefinition tool; `ToString[Definition[...], InputForm]` and the InheritedBlock recipe work in
  its evaluator.
- Output size: never return an AST, a `PacletObject`, ``Names["*`*"]`` or a whole `Definition` of a big function; take a
  `StringTake`/`Length`/`Keys` view first.

## Gotchas

- ReadProtected blocks only `Definition`-style views; `DownValues` works (not on Locked+ReadProtected symbols). Convert
  to a string inside ``Internal`InheritedBlock``; never clear ReadProtected or set attributes permanently in a shared kernel.
- Load autoload stubs first (`sym;`): every inspection, the SymbolDefinition tool included, shows the stub. The tool needs
  full names for your own symbols and omits ReadProtected from its Attributes line.
- `FindFile` wants the package context (``"CloudObject`"``), not a ``Private` `` subcontext; `PacletFind` with any key but
  `"Context"` returns everything.
- The `NestWhile[DirectoryName, ...]` paclet-root loop never ends outside a paclet; use the bounded version or the helper.
- `DownValues` order is try order, not source order, and rules can differ from the source text (macros expanded at load
  time). `FindDefinition` gives the first regex hit only and `$Failed` for `.wl` paclets.
- `Names` without a backtick misses most contexts; typing an unknown name creates it.
