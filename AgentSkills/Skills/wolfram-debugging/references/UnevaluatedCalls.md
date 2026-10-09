# Unevaluated calls and the wrong rule firing

Why `f[args]` comes back unchanged, or a different definition than expected fires: checks that need no `Trace` (so they
work in every environment), the order in which rules are tried, and a catalog of verified causes with fixes. Read it
when a result contains calls such as `f[2.5]` that should have evaluated, or when a function returns a fallback value.
Behavior was checked with Wolfram 15.0 in MCP Local and wolframscript (MCP Session where stated).

## Unevaluated, or failed?

- An **unevaluated call** means no rule matched (or a rule that only checks arguments declined, usually with a message
  such as `f::argx`). Nothing went "wrong" inside `f`; look at the patterns.
- `$Failed`, `Failure[...]` or `Missing[...]` means a rule matched and decided to fail: look at the messages and the
  `Failure` properties (`MessagesAndStacks.md`).

```wl
FailureQ /@ {$Failed, Failure["x", <||>], Missing["NotFound"], sq[2.5]}
(* {True, True, False, False} *)
```

## Find the stuck calls in a large result

Calls of your own functions that survive in a result are stuck. List them with whether the head has any definitions
(`False`: typo, wrong context, file not loaded; `True`: rules exist but none matched):

```wl
area[r_?NumericQ] := Pi r^2;
stuckRes = {area["4"], area[2], helpr[5], Lenght[{1}]};
Counts @ Cases[stuckRes, (s_Symbol)[___] /; MemberQ[{"Global`", $Context}, Context[s]] :>
   {SymbolName[Unevaluated[s]], System`Private`HasAnyEvaluationsQ[s]}, {0, Infinity}]
(* <|{"area", True} -> 1, {"helpr", False} -> 1, {"Lenght", False} -> 1|> *)
```

Add your package contexts to the list. ``WolframDebugging`StuckCalls[result]`` gives counts per head, the shortest example
and hints such as similar names or the same name defined in another context.

## Checks that work everywhere (no Trace)

```wl
price[x_Integer] := 10 x; price[x_Real /; x > 100] := "bulk"; price[s_String] := "parse " <> s;
price[20.]
(* price[20.] *)
```

```wl
{Keys @ DownValues[price],
 Flatten @ Position[Keys @ DownValues[price], lhs_ /; MatchQ[Unevaluated @ price[20.], lhs], {1}, Heads -> False],
 MatchQ[20., _Integer],
 Replace[Unevaluated @ price[20.], {HoldPattern[price[x_Real]] :> {x > 100}, _ :> "no match"}],
 {Context[price], Attributes[price], System`Private`HasAnyEvaluationsQ[price]},
 Select[Names["*`price"], ToExpression[#, InputForm, System`Private`HasAnyEvaluationsQ] &]}
```
```
{{HoldPattern[price[x_Integer]], HoldPattern[price[x_Real /; x > 100]], HoldPattern[price[s_String]]},   rules in try order
 {},                         positions of the left-hand sides (with their tests and conditions) that match: none
 False,                      one argument against one pattern
 {False},                    the condition's value for this call
 {"Global`", {}, True},      context ("Sessions`<id>`" in the MCP evaluator), attributes, has definitions
 {"price"}}                  every "price" that has definitions (a second one means shadowing); names in
                             $Context come without context
```

- Run the checks on the arguments as the function receives them (already evaluated, unless `f` has a Hold attribute).
- `MatchQ` with a `DownValues` key checks the left-hand side only; conditions written on the right-hand side
  (`f[x_] := body /; test`) are not tested, and no rule body runs.
- Always give `Replace[Unevaluated[f[...]], rules]` a catch-all rule: when nothing matches, `Replace` returns the call,
  which then evaluates (`Replace[Unevaluated[1 + 1], x_Integer :> "int"]` gives `2`).
- ``WolframDebugging`WhyNoMatch[f[args]]`` explains every rule (which argument fails which pattern, the value each test
  and condition returned, rules shadowed by earlier ones, similar names, other contexts) without evaluating any rule body
  and without changing definitions. It works where `Trace` records nothing.
- `Trace[f[args]]` (only where it works: MCP Local, wolframscript) shows the conditions that ran, but not which pattern
  failed structurally.

## The order in which rules are tried

```wl
ord[x_?NumericQ] := "numeric"; ord[x_Integer] := "integer"; ord[0] = "zero";
ord2[x_] := "any"; ord2[x_Integer] := "integer";
{Keys[DownValues[ord]], ord[0], ord[1], Keys[DownValues[ord2]], ord2[1]}
(* {{HoldPattern[ord[0]], HoldPattern[ord[(x_)?NumericQ]], HoldPattern[ord[x_Integer]]}, "zero", "numeric",
    {HoldPattern[ord2[x_Integer]], HoldPattern[ord2[x_]]}, "integer"} *)
```

- `DownValues[f]` lists the rules in the order they are tried.
- Literal rules (`f[0] = ...`, memoized values) come first.
- Pattern rules are sorted by specificity when the kernel can compare them (`x_Integer` before `x_`); otherwise they keep
  definition order (`x_?NumericQ` stays before `x_Integer`, so `ord[1]` gives `"numeric"`).
- UpValues of the arguments are tried before any DownValue, even a literal one:

```wl
lt[up[1]] = "literal DownValue"; up /: lt[up[x_]] := "UpValue";
lt[up[1]]
(* "UpValue" *)
```

- Assigning the list keeps your order (use this to force a rule first, or `Prepend` a rule inside
  ``Internal`InheritedBlock`` for a temporary probe, see `MessagesAndStacks.md`):

```wl
DownValues[ord2] = Reverse[DownValues[ord2]];
{Keys[DownValues[ord2]], ord2[1]}
(* {{HoldPattern[ord2[x_]], HoldPattern[ord2[x_Integer]]}, "any"} *)
```

- `f[a][b]` uses `SubValues[f]` (after `f[a]` itself failed to evaluate); `HoldAllComplete` functions ignore UpValues.

## Catalog of causes

Each example was evaluated as written; "stays" means the call is returned unevaluated.

| cause | example | result | fix |
|---|---|---|---|
| Integer pattern, Real or Rational argument | `sq[x_Integer] := x^2; {sq[2.5], sq[1/2]}` | both stay | `x_?NumericQ`, `x_Real`, or convert first |
| `NumberQ` is False for exact constants | `nq[x_?NumberQ] := N[x]; nq[Pi]` | stays | `_?NumericQ` |
| test does not return exactly `True` | `pos[x_?(# > 0 &)] := x; pos[a]`; `isPos[x_?(If[# > 0, 1, 0] &)] := x; isPos[5]` | both stay (`a > 0` and `1` are not `True`) | tests must return `True`/`False` (`TrueQ`) |
| condition uses a symbol with no value | `big[x_] /; x > cutoff := "big"; big[3]` | stays (`3 > cutoff`); `"big"` once `cutoff = 1` | define or pass the value |
| options without `OptionsPattern[]` | `opt1[x_] := x; opt1[1, "Verbose" -> True]` | stays | `opt1[x_, OptionsPattern[]]` |
| positional argument after the options start | `Options[opt2] = {"A" -> 1}; opt2[x_, OptionsPattern[]] := {x, OptionValue["A"]}; opt2[1, 2, "A" -> 3]` | stays | add a pattern for it |
| unknown option name | `opt2[1, "B" -> 2]` | matches anyway: `{1, 1}` + `OptionValue::nodef` | fix the name |
| a list where a sequence is expected | `pair[x_, y_] := {x, y}; pair[{1, 2}]` | stays | `pair @@ {1, 2}` |
| `y_.` without a `Default` | `dflt[x_, y_.] := {x, y}; dflt[1]` | stays | `y_ : 0` |
| a typed default is not checked | `td[x_, y_Integer : 1.5] := {x, y}; td[1]` | `{1, 1.5}` | check inside the body |
| repeated pattern name needs identical values | `same[x_, x_] := x; same[1, 1.]` | stays (`1` and `1.` are not `SameQ`) | `same[x_, y_] /; x == y` |
| Hold attribute plus a typed pattern | `SetAttributes[hl, HoldAll]; hl[x_Integer] := x; hl[1 + 1]` | stays (`1 + 1` is a `Plus`) | `hl[Evaluate[1 + 1]]` → `2`, or test inside |
| `_List` given an Association or SparseArray (atomic objects) | `len[x_List] := Length[x]; len[Association["a" -> 1]]`, `len[SparseArray[{1, 0, 2}]]` | both stay | `_Association`; `len[Normal[SparseArray[{1, 0, 2}]]]` → `3` |
| string pattern in an ordinary pattern | `url[s : ("http" ~~ ___)] := s; url["http://x"]` | stays | `url[s_String /; StringStartsQ[s, "http"]]` |
| `=` (Set) evaluated the right-hand side once | `rad = 5; area2[rad_] = Pi rad^2; Clear[rad]; {area2[1], area2[7]}` | `{25 Pi, 25 Pi}` | `:=` |
| stale memoized values after redefining | `memo[x_] := memo[x] = x^2; memo[3]; memo[x_] := memo[x] = x^3; memo[3]` | `9` (old literal rule wins) | `Clear[memo]` before redefining |
| same left-hand side defined again | `dup[x_] := "first"; dup[y_] := "second"; dup[1]` | `"second"`, one rule left (pattern names do not matter) | add a condition or a different pattern |
| typo in a lower-case name | `totalCost[x_] := 2 x; totalcost[3]` | stays, no warning | (the MCP evaluator warns only for undefined upper-case names) |
| general rule tried first | `kind[x_?NumericQ] := "numeric"; kind[x_Integer] := "integer"; kind[1]` | `"numeric"` | define the specific rule first, or add conditions |
| `KeyValuePattern` with an outer condition | `kv[KeyValuePattern[{"ok" -> True, "url" -> u_String}]] /; StringStartsQ[u, "http"] := u; kv[_] := "fallback"`, called with an association whose `"url"` is `"https://x"` | `"fallback"` | see the next section |
| inner condition uses a sibling variable | `sib[x_, y_ /; y > x] := {x, y}; sib[1, 5]` | stays (`x` is not bound inside `y_ /; ...`) | `sib[x_, y_] /; y > x` |
| `OptionValue["A"]` in a left-hand-side condition | `ov[x_, OptionsPattern[]] /; OptionValue["A"] > 1 := "big A"; ov[x_, OptionsPattern[]] := "small A"; ov[1, "A" -> 2]` (with `Options[ov] = {"A" -> 1}`) | `"small A"` | see "Conditions" below |
| `/;` inside `If`, `Enclose`, `Catch`, `Quiet`, ... | `ce[x_] := Enclose[x /; x > 0]; ce[-1]`; `ifc[x_] := If[x > 0, "pos" /; True, "neg"]; ifc[1]` | `-1 /; -1 > 0`, `"pos" /; True` (the rule fired) | put the condition on the left-hand side, or directly in the body of `Module`/`With`/`Block` |
| `Flat` head matches a subsequence | `SetAttributes[fl, Flat]; fl[x_Integer, y_Integer] := x + y; fl[1, 2, 3]` | `6` | expected for `Flat` |
| `Orderless` sorts the arguments first | `SetAttributes[ol, Orderless]; ol[a_, b_] := {a, b}; ol[2, 1]` | `{1, 2}` | expected for `Orderless` |
| `Listable` with unequal lengths | `SetAttributes[ls, Listable]; ls[x_, y_] := x + y; ls[{1, 2}, {1, 2, 3}]` | `Thread::tdlen`, then the rule runs on the lists: `{1, 2} + {1, 2, 3}` | fix the lengths |
| `SubValues` argument mismatch | `sv[a_Integer][b_String] := {a, b}; sv[1][2]` | stays | |
| UpValue ignored by `HoldAllComplete` | `SetAttributes[hac, HoldAllComplete]; up2 /: hac[up2[x_]] := "up"; hac[up2[1]]` | stays | define a DownValue for `hac` |
| pure function with the wrong arity | `fn = Function[{x, y}, x + y]; fn[1]`; `fs = #1 + #2 &; fs[1]` | stays + `Function::fpct`; `1 + #2` + `Function::slotn` | |
| built-in called with the wrong arguments | `StringTake["abc"]` | stays + `StringTake::argr` | `Lookup[SyntaxInformation[StringTake], "ArgumentsPattern"]` → `{_, _}` |

## KeyValuePattern with an outer condition

When an outer `/;` (on the left-hand side or the right-hand side) uses a variable bound in the second or a later element
of a `KeyValuePattern`, the condition is first evaluated with that variable missing (`Sequence[]`), and the rule only
applies if that evaluation also returns `True`:

```wl
kvSeen = {};
kvTest[v___] := (AppendTo[kvSeen, {v}]; MatchQ[{v}, {_Integer}]);
kv5[KeyValuePattern[{"a" -> 1, "b" -> v_}]] /; kvTest[v] := {"hit", v};
kv5[_] := "fallback";
{kv5[<|"a" -> 1, "b" -> 2|>], kvSeen}
(* {"fallback", {{}}}   -- the condition ran once, with no argument *)
```

So `v > 0` happens to work (`Greater[0]` is `True`), `StringStartsQ[u, "http"]` fails silently (it becomes the operator
form `StringStartsQ["http"]`), and `IntegerQ[v]` fails with `IntegerQ::argx`. `Trace` shows the condition called without
the argument (`kvTest[]`), or nothing when that form is inert. Variables bound in the first element work. Fixes:

```wl
kv2[KeyValuePattern[{"ok" -> True, "url" -> u_String /; StringStartsQ[u, "http"]}]] := u;
kv3[(KeyValuePattern[{"ok" -> True, "url" -> u_String}] /; StringStartsQ[u, "http"])] := u;
kv4[json : KeyValuePattern[{"ok" -> True}]] /; StringStartsQ[Lookup[json, "url", ""], "http"] := json["url"];
With[{a = <|"ok" -> True, "url" -> "https://x"|>}, {kv2[a], kv3[a], kv4[a]}]
(* {"https://x", "https://x", "https://x"} *)
```

`ReplaceList` has a related problem: it binds only the first element's variables.

```wl
{ReplaceList[<|"a" -> 1, "b" -> 2|>, KeyValuePattern[{"a" -> w_, "b" -> v_}] :> {w, v}],
 Replace[<|"a" -> 1, "b" -> 2|>, KeyValuePattern[{"a" -> w_, "b" -> v_}] :> {w, v}]}
(* {{{1}}, {1, 2}} *)
```

## Conditions on the right-hand side, and OptionValue

- `body /; test` is a rule condition only directly on the right-hand side, as the last statement of a
  `CompoundExpression`, or directly in the body of `Module`, `With` or `Block` (also nested, `With[..., Module[..., body /; test]]`).
  There the scoping initializers run first: `mod[x_] := Module[{y = x^2}, "big" /; y > 10]; mod[x_] := "small"` gives
  `{mod[2], mod[5]}` → `{"small", "big"}`. Inside `If`, `Enclose`, `Catch`, `Quiet`, `Check`, `WithCleanup` or a
  `Function` the rule fires and returns a literal `a /; b`.
- `OptionValue["A"]` (short form) is not resolved inside a left-hand-side condition. Name the options or move the
  condition to the right-hand side:

```wl
Options[ov2] = {"A" -> 1};
ov2[x_, opts : OptionsPattern[]] /; OptionValue[ov2, {opts}, "A"] > 1 := "big A";
ov2[x_, OptionsPattern[]] := "small A";
ov3[x_, OptionsPattern[]] := "big A" /; OptionValue["A"] > 1;
ov3[x_, OptionsPattern[]] := "small A";
Options[ov3] = {"A" -> 1};
{ov2[1, "A" -> 2], ov3[1, "A" -> 2], ov3[1]}
(* {"big A", "big A", "small A"} *)
```

## The call refers to a different symbol (contexts)

The head you call is not the symbol you defined. `Context[f]` and the `Names` check above reveal it.

- **Same input as the load**: `Get["ShadowDemo.wl"]; {pkgFn[1], Context[pkgFn]}` as one input (one line of a tool call
  or `-f` file, or one `-code` string) gives `` {Global`pkgFn[1], "Global`"} `` (``Sessions`<id>` `` in the MCP
  evaluator) and `pkgFn::shdw`: the input is parsed before `Get` runs, so `pkgFn` was created in your context. Load on
  its own line: later lines, also later lines of the same tool call, are parsed after the load and reach
  ``ShadowDemo`pkgFn`` (`{pkgFn[1], Context[pkgFn]}` → `` {2, "ShadowDemo`"} ``). The leftover symbol in your context
  can be removed with ``Remove["Global`pkgFn"]`` (``Remove[Evaluate[$Context <> "pkgFn"]]`` in the MCP evaluator).
- **Another evaluator session**: each MCP evaluator session has its own ``Sessions`<id>` ``. A definition made in
  another session is invisible (`sessF[1]` stayed unevaluated; the definition was ``Sessions`<other id>`sessF``). Reuse
  the session id.
- **Private package functions**: ``Pkg`Private`helper`` is not reachable as `helper`; call it by its full name
  (``ShadowDemo`Private`pkgHelper[1]`` → `2`, while `pkgHelper[1]` stays).
- **Typos**: the MCP evaluator (both methods) warns about undefined upper-case symbols of your session before evaluating
  (``Symbol::undefined: Warning: Global symbol Lenght is undefined.``), never about lower-case ones, and not about
  symbols defined or localized in the same input.

## Built-ins and argument checks of your own

Kernel functions have no inspectable rules: read the message (`::argx`, `::argr`, `::argt`, `::argb` for argument counts,
`::nonopt`, `::optx` for options) and `Lookup[SyntaxInformation[f], "ArgumentsPattern"]`. System packages report wrong
argument counts with a rule that issues a message in its condition and then fails, so the call stays unevaluated with an
explanation; you can do the same:

```wl
chk[args___] := Null /; (CheckArguments[chk[args], 1]; False);
chk[x_Integer] := x^2;
{chk[3], chk[1, 2], chk[2.5]}
(* chk::argx: chk called with 2 arguments; 1 argument is expected.
   {9, chk[1, 2], chk[2.5]} *)
```

## Compiled code

- `cf = Compile[{{x, _Real}}, x^2 + 1]`: `cf[1, 2]` stays unevaluated with `CompiledFunction::cfct`; `cf["a"]` issues
  `CompiledFunction::cfsa` and falls back to uncompiled evaluation, returning `1 + "a"^2` (not an unevaluated call).
- `fc = FunctionCompile[Function[Typed[x, "MachineInteger"], x + 1]]`: `fc[2.5]` returns `Failure["ArgumentType", ...]`
  with `CompiledCodeFunction::argtype`, `fc[1, 2]` returns `Failure["ArgumentCount", ...]` with
  `CompiledCodeFunction::argx` (the first `FunctionCompile` in a kernel took about 10 s).
- Calling a `Failure` object (for example a failed `FunctionCompile` result) gives `Missing["NotAvailable", arg]`:
  `Failure["TypeError", <||>][1]` → `Missing["NotAvailable", 1]`.
