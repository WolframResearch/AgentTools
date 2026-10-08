# Messages and stacks

How to see messages as data (which message, from where, printed or quieted), how `Quiet`, `Off`, `Check`,
`General::stop` and `$MessageList` really behave, how to get a stack trace at a message or at any call, and how to read,
filter and shrink stacks. Read it when code issues messages, returns `$Failed`, hits a recursion limit or throws
unexpectedly. Behavior was checked with Wolfram 15.0 (MCP Local, MCP Session, wolframscript, CloudEvaluate and the remote
MCP server where stated; see `Environments.md` for these names).

The examples use these definitions:

```wl
otherFn[x_] := 1/x; myFn[a_, b_] := Table[otherFn[i], {i, a, b}];
```

## Which tool for which question

| question | first choice | section |
|---|---|---|
| which messages, printed or quieted, from where? | a `"Message"` handler that records into an ``Internal`Bag``; ``WolframDebugging`CollectMessages[expr]`` | Message handlers |
| first message only, as data, nothing printed | `Enclose[ConfirmQuiet[expr], ...]` | Messages as data |
| all messages, Print output and timing as data | `EvaluationData[expr]`; ``WolframDebugging`CaptureEvaluation[expr]`` | Messages as data |
| the call chain that led to a message | handler + `Throw[Stack[_], tag]` + `StackBegin[StackComplete[expr]]`; ``WolframDebugging`StackAtMessage[expr, Power::infy]`` | Stack at a message |
| the stack (with argument values) when `f` gets particular arguments | never-matching conditional rule; ``WolframDebugging`StackAtCall[expr, f[0]]`` | Stack at a call |
| hide or rewrite one message | `"Message.Veto"`, `"MessageTextFilter"` handlers | Other handler types |
| recursion/iteration limit, uncaught `Throw`, failed `Assert` | lower the limit + stack at the message; probe `Throw`; `"Assertions"` handler | Other triggers |

Helpers are in `scripts/WolframDebugging.wl` (load it with `Get` in its own call, call them fully qualified; options and
outputs: `HelperFunctions.md`). Everything below works without them, including on the remote MCP server.

## Message handlers: ``Internal`HandlerBlock``

``Internal`HandlerBlock[{"Message", f}, expr]`` calls `f` for every message issued while `expr` evaluates, then removes
`f`. The argument is `Hold[Message[name, args...], willPrint]`:

```wl
Internal`HandlerBlock[{"Message", Print[ToString[#, InputForm]] &}, {myFn[-1, 1], Quiet[First[{}]]}]
```
```
Power::infy: Infinite expression 1/0 encountered.            (printed first; 2-D in MCP Local and wolframscript)
Hold[Message[Power::infy, HoldCompleteForm[0^(-1)]], True]
Hold[Message[First::nofirst, HoldCompleteForm[{}]], False]    (quieted: willPrint is False)
Out= {{-1, ComplexInfinity, 1}, First[{}]}
```

- Arguments of messages issued by kernel functions are wrapped in `HoldCompleteForm` in 15.0 (older versions:
  `HoldForm`); arguments of an explicit `Message[f::tag, 5]` arrive unwrapped: `Hold[Message[f::tag, 5], True]`.
  The held argument of `Power::infy` is `0^(-1)` (the message comes from `Power[0, -1]`, not from `1/0`).
- `Print` in a handler is only for illustration: one evaluation can issue thousands of messages (a fresh kernel loading a
  package issues quieted `General::newsym` by the thousand). Record into a bag and filter on `willPrint` (`Last[m]`).
- `Print[InputForm[x]]` in a `wolframscript -f` script prints the text `InputForm[...]` with string quotes stripped; use
  `Print[ToString[x, InputForm]]`.

Collect the printed messages without stopping (MCP Local, MCP Session, wolframscript, CloudEvaluate; on the remote MCP
server see Environments below):

```wl
Module[{bag = Internal`Bag[]},
  Internal`HandlerBlock[{"Message", Function[m, If[Last[m],
      Internal`StuffBag[bag, Replace[m, Hold[Message[mn_, ___], _] :> ToString[Unevaluated[mn], InputForm]]]]]},
    {Quiet[1/0], First["xyz"]}];
  Internal`BagPart[bag, All]]
(* {"First::normal"}   -- the quieted Power::infy arrived with willPrint False and was skipped *)
```

``WolframDebugging`CollectMessages[expr]`` does this with message text, a printed/quieted flag and the last stack frames
of each message.

Rules for writing handlers:
- **Never use `#[[1]]` on the handler argument**: `Part` re-evaluates `Message[...]` (the message is issued again and
  the extracted value is `Null`). `#[[1, 1]]` evaluates the message name: `General::stop` becomes its template text.
  Use patterns (`Hold[Message[mn_, args___], flag_]` does not evaluate anything), `Delete[#, -1]`
  (→ `Hold[Message[...]]`), `Extract[#, {1, 1}, HoldForm]` (→ `HoldForm[First::nofirst]`) and `Last[#]` (the flag).
- Exactly one `{"Type", f}` pair per `HandlerBlock`; nest blocks for several handlers. A malformed spec (for example
  `{{"Message.Veto", f}, {"Message", g}}`) issues ``Internal`HandlerBlock::string`` and **does not evaluate the body**.
- Handlers are added, never replaced: the MCP evaluator's own Chatbook handlers keep running beside yours. Handlers run
  in installation order (oldest first); a handler that `Throw`s stops the newer ones from seeing that message.
- The `"Message"` handler's return value is ignored and it runs after the text was printed: it cannot hide a message
  (use `"Message.Veto"`). Stop the evaluation from a handler with a tagged `Throw` (or `Abort[]`).
- A message pattern written as `mySym::err` outside a hold evaluates to its text if the message has one; match inside
  `Hold[Message[mySym::err, ___], _]` or compare names as strings.

### What `willPrint` means

| situation | `willPrint` | text printed |
|---|---|---|
| plain message | `True` | yes |
| inside `Quiet[...]`, after `Off[msg]`, inside ``Internal`DeactivateMessages`` or `ConfirmQuiet` | `False` | no |
| 4th and later occurrence after `General::stop` | **`True`** | **no** |
| `General::stop` itself | `True` | yes |
| `Off[General::stop]` | `True` | yes, every occurrence |
| inside `Block[{$Messages = {}}, ...]` | **`True`** | no (MCP Session still shows it) |
| `Quiet[expr, None, All]` inside an outer `Quiet` | `True` | yes (cancels the outer `Quiet`) |
| remote MCP server (every input runs inside `Quiet`) | **always `False`** | shown by the server anyway |
| message issued in a parallel subkernel | handler in the master **not called** | printed by the master as `From kernel 1 ...` |

`True` therefore means "not quieted", not "printed". Per message the handler types run in this order: `"Message.Veto"`,
`"Message.Silent"`, `"MessageTextFilter"` (skipped for quieted messages and after `General::stop`, still called under
`$Messages = {}` or when `"Message.Silent"` returned `False`), then the text is printed, then the `"Message"` handlers.

## Persistent handlers: ``Internal`AddHandler``, ``Internal`RemoveHandler``, ``Internal`Handlers``

``Internal`AddHandler["Message", f]`` installs `f` globally until ``Internal`RemoveHandler["Message", f]``. Only use it
in a throwaway kernel (wolframscript):

```wl
Internal`AddHandler["Message", Print];
First["xyz"];
Print[Internal`Handlers["Message"]];
Internal`RemoveHandler["Message", Print];
Print[Internal`Handlers["Message"]];
Internal`RemoveHandler["Message", Print];
```
```
First::normal: Nonatomic expression expected at position 1 in First[xyz].
Hold[Message[MessageName[First, normal], HoldCompleteForm[1], HoldCompleteForm[First[xyz]]], True]
Message -> {Print}
Message -> {}
Internal`RemoveHandler::noevent: -- Message text not found -- (Message)      (removing a handler that is not installed)
```

- **Global handlers leak.** They persist across MCP calls (both methods); in MCP Local they fire for every session and
  agent sharing the subkernel; in MCP Session they also see the server's own quieted messages (16 `Show::gtype` during
  a single `1 + 1` call). A notebook can show stray handler output from front-end background evaluations (untested).
- **Reference counted**: adding the same handler twice lists it once but needs two removals.
- ``Internal`Handlers[]`` lists every handler type (`"Message"`, `"Message.Veto"`, `"Message.Silent"`,
  `"MessageTextFilter"`, `"GetFileEvent"`, `"NewSymbol"`, `"ValueChange"`, `"Assertions"`, `"Wolfram.System.Print"`, ...);
  ``Internal`Handlers["Message"]`` gives `"Message" -> {newest, ..., oldest}`.
  ``Select[Internal`Handlers[], Last[#] =!= {} &]`` shows what is installed: in MCP Local a J/Link
  `"VetoableValueChange"`, an MUnit `"GetFileEvent"`, ``Internal`MessageButtonHandler`` (`"MessageTextFilter"`) and
  Chatbook's `"Message"` handler; in a fresh wolframscript only the `"MessageTextFilter"` one.

If a global handler is unavoidable (for example the code under test spawns evaluations a block does not cover), add and
remove it in the same call:

```wl
Module[{bag = Internal`Bag[], h},
  h = Function[m, If[Last[m], Internal`StuffBag[bag, Extract[m, {1, 1}, HoldForm]]]];
  WithCleanup[Internal`AddHandler["Message", h]; myFn[-1, 1], Internal`RemoveHandler["Message", h]];
  {Internal`BagPart[bag, All], MemberQ[Last[Internal`Handlers["Message"]], h]}]
(* {{HoldForm[Power::infy]}, False}   -- recorded, and removed again *)
```

## Other handler types: hide, silence or rewrite messages

```wl
Internal`HandlerBlock[{"Message.Veto", (!MatchQ[#, Hold[Message[Power::infy, ___], _]]) &},
  {Check[1/0, "Check fired"], First[{}]}]
(* only First::nofirst is printed; {ComplexInfinity, First[{}]} -- the vetoed message did not trigger Check *)
```

- `"Message.Veto"`: same argument as `"Message"`; returning exactly `False` removes the message completely (not printed,
  `Check` does not fire, `"Message"` handlers not called, hidden from the MCP tool output in MCP Local and MCP Session).
  Any other return value lets it through.
- `"Message.Silent"`: returning `False` suppresses only the text; the message still counts
  (``Internal`HandlerBlock[{"Message.Silent", False &}, Check[1/0, "Check fired"]]`` → `"Check fired"`, nothing printed in
  MCP Local and wolframscript). In MCP Session the tool output still shows the message.
- `"MessageTextFilter"`: called with the text template, `Hold[name]` and `Hold[Message[...]]`; a returned string replaces
  the template. Works in MCP Local and wolframscript, no effect on MCP Session output:

```wl
Internal`HandlerBlock[{"MessageTextFilter", ("[myFn] " <> #1) &}, First[{}]]
(* First::nofirst: [myFn] {} has zero length and no first element. *)
```

- Shorter message arguments: `Block[{$MessagePrePrint = Shallow}, Range[200][[300]];]` prints
  `Part::partw: Part 300 of {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, <<190>>} does not exist.` (MCP Local, wolframscript;
  MCP Session ignores it and truncates long arguments itself). `$MessagePrePrint = Short` has no effect (infinite page width).

## Quiet, Off, Check, General::stop, $Messages and $MessageList

| mechanism | effect | scope and gotchas |
|---|---|---|
| `Quiet[expr]`, `Quiet[expr, {msgs}]` | not printed, `willPrint` False, `Check` outside does not fire | scoped: preferred. `Quiet[expr, None, All]` cancels an outer `Quiet` |
| `Off[msg]` / `On[msg]` | like `Quiet` for that message | **global**: persists across MCP calls and sessions. Use `Quiet[expr, {msg}]` instead |
| `Check[expr, failExpr]` | returns `failExpr` if an unquieted message was issued; does not stop evaluation or suppress printing | `Quiet[Check[1/0, "x"]]` → `"x"` (still fires); `Check[Quiet[1/0], "x"]` → `ComplexInfinity` |
| `General::stop` | after 3 occurrences of a message in one evaluation the rest are not printed | accounting uses `$MessageList`; `willPrint` stays True |
| `Block[{$Messages = {}}, expr]` | nothing printed, everything else unchanged (`Check` fires, handlers see True) | MCP Session ignores it (`$Messages` is already `{}` there; the tool collects messages through a handler) |
| `$MessageList` | list of `HoldForm[name]` issued in the current evaluation | **Protected**: `$MessageList = {}` gives `Set::wrsym`; use `Block[{$MessageList = {}}, expr]` |

`$MessageList` is reset per tool call in MCP Local, once per script in wolframscript (a whole `-f` file is one
evaluation) and `wolfram -script` (the third `First[{}]` statement of a file triggers `General::stop`), and **never in MCP
Session** (it accumulates over the server's lifetime and all sessions,
so `General::stop` can fire on the first occurrence in a call). Wrap experiments in `Block[{$MessageList = {}}, ...]`.
Quieted messages are added while inside `Quiet` (and count toward `General::stop`), but `Quiet` restores the list on exit:

```wl
{Block[{$MessageList = {}}, Quiet[Table[1/0, 5]]; $MessageList], Block[{$MessageList = {}}, Quiet[Table[1/0, 5]; $MessageList]]}
(* {{}, {HoldForm[Power::infy], HoldForm[Power::infy], HoldForm[Power::infy], HoldForm[General::stop]}} *)
```

When counting occurrences, use fresh expressions: an unchanged literal subexpression such as `First[{}]` is evaluated
only once, so `Do[First[{}], 4]` issues one message while `Do[g[{}], 4]` with `g[x_] := First[x]` issues four.

## Messages as data: EvaluationData, ConfirmQuiet

```wl
KeyTake[Block[{$Messages = {}}, EvaluationData[myFn[-1, 1]]], {"Success", "FailureType", "MessagesExpressions", "OutputLog"}]
(* <|"Success" -> False, "FailureType" -> "MessageFailure",
     "MessagesExpressions" -> {Hold[Message[Power::infy, HoldCompleteForm[0^(-1)]]]}, "OutputLog" -> {}|> *)
```

- Keys: `"Result"` (a `RuleDelayed`), `"Success"`, `"FailureType"`, `"OutputLog"` (Print/Echo text), `"Messages"`,
  `"MessagesText"`, `"MessagesExpressions"`, `"Timing"`, `"AbsoluteTiming"`, `"InputString"`. Quieted messages are not
  recorded. It does not suppress printing (hence the `Block`; in MCP Session the tool shows the messages anyway).
- Use `"MessagesExpressions"`: `"Messages"` holds evaluated names, so `General::stop`, `Throw::nocatch` and user
  messages with text appear as template strings (``"Uncaught `1` returned to top level."``).
- `EvaluationData` catches every `Throw`, tagged or not:
  `KeyTake[Catch[EvaluationData[Throw[1, "t"]], "t"], {"Result", "Success"}]` →
  `<|"Result" :> Hold[Throw[1, "t"]], "Success" -> False|>` plus `Throw::nocatch` (see "When a Throw-based probe returns the normal result" below).

First message only, evaluation stopped there, nothing printed:

```wl
Enclose[ConfirmQuiet[myFn[-1, 1]], #[{"HeldMessageName", "HeldMessageCall"}] &]
(* {Hold[Power::infy], Hold[Message[Power::infy, HoldCompleteForm[0^(-1)]]]} *)
```

`ConfirmQuiet[expr, {msg}]` reacts only to the listed messages. Other `Confirm*` functions ignore messages.

## Stacks: Stack, StackBegin, StackComplete

- `Stack[]`: the heads of the expressions being evaluated (tiny). `Stack[_]`: every frame as
  `HoldCompleteForm[expr]` (older versions: `HoldForm`). `Stack[patt]`: frames whose expression matches `patt`.
- A frame holds the **latest form** of an evaluation chain: when `f[x]` is rewritten by its definition, its frame is
  replaced by the right-hand side (`Module[...]`, `If[...]`, ...), so `f` itself vanishes from the stack, whatever its
  body. `StackComplete[expr]` keeps those frames.
- `StackBegin[expr]` starts a fresh stack (removes the frames of whatever runs your code: wolframscript, CloudEvaluate).
- Nest them as **`StackBegin[StackComplete[expr]]`**: `StackBegin` inside `StackComplete` turns `StackComplete` off.
- Frames show expressions as they were pushed: `otherFn[i]` inside `Table`, not `otherFn[0]`. For argument values use
  the stack-at-a-call probe below.

```wl
outerFn[x_] := innerFn[x^2]; innerFn[y_] := Stack[_];
{StackBegin[outerFn[2]], StackBegin[StackComplete[outerFn[2]]], StackComplete[StackBegin[outerFn[2]]]}
(* {{}, {HoldCompleteForm[StackComplete[outerFn[2]]], HoldCompleteForm[outerFn[2]], HoldCompleteForm[innerFn[2^2]]}, {}} *)
```

Stack size added by each environment (why `StackBegin` matters):

| environment | `Stack[_]` at top level | stack at `Power::infy` in `StackComplete[myFn[-3, 3]]` without `StackBegin` |
|---|---|---|
| MCP Local, MCP Session, remote MCP server | 2–3 frames (they hold your whole input) | 13 frames (MCP Local, MCP Session) |
| wolframscript | 17–19 frames, 90–120 KB (the frames embed the script) | 28 frames, 120 KB |
| `wolfram -script` | 3–4 frames | 14 frames |
| CloudEvaluate | about 68 frames, 310 KB | 78 frames, 315 KB |

With `StackBegin` the stack at that message is 9 frames and 2.1 KB in every environment. A real package stack is large:
in a fresh kernel, the stack at `URLRead::invhttp` from `StackBegin[StackComplete[URLRead["http://localhost:1/x"]]]` had
59 frames, 269 KB, about 83,000 characters in InputForm. Capturing is cheap; never return a raw stack from an MCP call,
format it (below).

**Frames are inert only while wrapped.** `First[frame]`, `frame[[1]]`, `ReleaseHold[frame]`, `First /@ stack` and
`Cases[stack, HoldCompleteForm[e_] :> e]` evaluate the frame again (side effects, repeated messages, even re-running the
`Throw` that captured it). Safe: patterns, `Extract[frame, 1, Hold]`, `Cases[stack, _[(h_Symbol)[___]] :> h]`, and
`Replace[stack, _[e_] :> ToString[Unevaluated[e], InputForm, TotalWidth -> 150], {1}]`.

## Stack at a message

Throw the stack from a `"Message"` handler (MCP Local, MCP Session, wolframscript, CloudEvaluate):

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

- One specific message: `Hold[Message[Power::infy, ___], True]`. Heads only: `Stack[]` instead of `Stack[_]` →
  `{StackComplete, myFn, Table, otherFn, Times, Power, Message, Function, Replace, Throw}`.
- `Take[..., Position[...][[-1, 1]]]` drops the handler's own frames after the `Message` frame. The `$ContextPath` block
  avoids context prefixes on your symbols (``Global` `` ones in MCP Local with bug #249).
- The message is printed before the handler runs, and the `Throw` abandons the computation (the result is lost). Without
  `StackComplete` the `myFn` and `otherFn` frames are missing; without `StackBegin` you get the wrapper frames above.
- Package code often issues and quiets internal messages before the public one (`URLRead` quiets `URLFetch::invhttp`,
  then issues `URLRead::invhttp`; a fresh kernel also sent 15,000 quieted `General::newsym` during that call); matching
  `True` skips them.

The same with a named handler, keeping the raw frames for the filters below:

```wl
infyHandler[Hold[Message[Power::infy, ___], True]] := Throw[Stack[_], "infy"];
stk = Catch[Internal`HandlerBlock[{"Message", infyHandler}, StackBegin[StackComplete[myFn[-3, 3]]]], "infy"];
{Length[stk], ByteCount[stk]}
(* {9, 2104} *)
```

``WolframDebugging`StackAtMessage[expr, Power::infy]`` returns the stack up to the message as one string of numbered
lines (`"Stack"`; raw frames on request, see `HelperFunctions.md`);
``WolframDebugging`FormatStack[stack]`` renders any stack as numbered, truncated lines and collapses recursion cycles;
``WolframDebugging`StackSummary[stack]`` gives its length, size, most common heads and contexts.

## Filter, trim and format a stack

Only frames of your own functions. Typed code lives in ``Global` `` (wolframscript, and MCP Local with AgentTools bug
#249, see `Environments.md`) or in ``Sessions`<id>` `` (`$Context` in the MCP evaluator), so test both (add your package
contexts):

```wl
Cases[stk, _[(s_Symbol)[___]] /; MemberQ[{"Global`", $Context}, Context[s]]]
(* {HoldCompleteForm[myFn[-3, 3]], HoldCompleteForm[otherFn[i]], HoldCompleteForm[infyHandler[Hold[Message[...], True]]]} *)
```

From the first frame matching a pattern on:

```wl
Replace[stk, {___, first : _[_myFn], rest___} :> {first, rest}] // Length
(* 8 *)
```

The last n frames as one line each (`Take[st, -UpTo[n]]` is invalid; use `-Min[n, Length[st]]`):

```wl
Block[{$ContextPath = Join[{"Global`", $Context}, $ContextPath]},
  StringRiffle[Replace[Take[stk, -Min[5, Length[stk]]],
    _[e_] :> ToString[Unevaluated[e], InputForm, TotalWidth -> 100], {1}], "\n"]]
```
```
1/0
0^(-1)
Message[Power::infy, HoldCompleteForm[0^(-1)]]
infyHandler[Hold[Message[Power::infy, HoldCompleteForm[0^(-1)]], True]]
Throw[Stack[_], "infy"]
```

Which functions dominate (deep recursion):

```wl
Tally[Cases[stk, _[(h_Symbol)[___]] :> h]]
(* {{StackComplete, 1}, {myFn, 1}, {Table, 1}, {otherFn, 1}, {Times, 1}, {Power, 1}, {Message, 1}, {infyHandler, 1}, {Throw, 1}} *)
```

`TotalWidth` truncates structurally (`{1, 2, ..., <<962>>, ...}`) but does not shorten one long string, and widths below
about 15 give `"-toobig-"` with `Format::toobig`: add `StringTake[s, UpTo[n]]` for hard limits. `Short` does nothing in the
MCP evaluator or wolframscript.

## Stack at a call with particular arguments

Prepend a rule whose condition records the stack and then fails. The condition runs while the call frame, with its
evaluated arguments, is on the stack; evaluation is otherwise unaffected and the definitions are restored afterwards:

```wl
probeBag = Internal`Bag[];
Internal`InheritedBlock[{otherFn},
  DownValues[otherFn] = Prepend[DownValues[otherFn],
    HoldPattern[otherFn[0]] /; (Internal`StuffBag[probeBag, Stack[_]]; False) :> Null];
  Quiet @ StackBegin[myFn[-3, 3]]]
(* {-1/3, -1/2, -1, ComplexInfinity, 1, 1/2, 1/3}   -- normal result *)
```
```wl
{Internal`BagLength[probeBag], Internal`BagPart[probeBag, 1], DownValues[otherFn]}
(* {1, {HoldCompleteForm[Table[otherFn[i], {i, -3, 3}]], HoldCompleteForm[otherFn[0]],
        HoldCompleteForm[Internal`StuffBag[probeBag, Stack[_]]; False], HoldCompleteForm[Internal`StuffBag[probeBag, Stack[_]]]},
    {HoldPattern[otherFn[x_]] :> 1/x}} *)
```

- The frame shows `otherFn[0]`, the actual argument. Putting the capture in the right-hand side instead would replace the
  call frame.
- Stop at the first hit by throwing from the condition:

```wl
Catch[Internal`InheritedBlock[{otherFn},
    DownValues[otherFn] = Prepend[DownValues[otherFn],
      HoldPattern[otherFn[x_ /; x == 0]] /; (Throw[Stack[], "probe"]; False) :> Null];
    StackBegin[StackComplete[myFn[-3, 3]]]],
  "probe"]
(* {StackComplete, myFn, Table, otherFn, CompoundExpression, Throw} *)
```

- System functions: `Unprotect` inside the block (attributes and definitions come back on exit):

```wl
Module[{bag = Internal`Bag[]},
  Internal`InheritedBlock[{StringLength},
    Unprotect[StringLength];
    PrependTo[DownValues[StringLength],
      HoldPattern[StringLength[x_ /; !StringQ[x]]] /; (Internal`StuffBag[bag, Stack[]]; False) :> Null];
    Quiet @ StackBegin[StringLength /@ {"ab", 7}];];
  {Internal`BagPart[bag, All], MemberQ[Attributes[StringLength], Protected], DownValues[StringLength]}]
(* {{{List, StringLength, CompoundExpression, Internal`StuffBag}}, True, {}} *)
```

- End the block body with `;` (or return `HoldComplete[...]`): the value of an ``Internal`InheritedBlock`` that changed a
  definition is evaluated again after the block exits, outside your `Quiet` (`StringLength[7]` returned from the block
  printed `StringLength::string` again).
- ``WolframDebugging`StackAtCall[expr, otherFn[0]]`` does this for any call pattern. Literal rules such as `f[0] = 1`
  are tried before your conditional rule, and calls made from kernel code (`Total`, auto-compiled `Table`) never reach
  it; see `OverridesAndWatchpoints.md` for the full list of what an override does not see.

## Other triggers

### `$RecursionLimit` and `$IterationLimit`

Lower the limit locally (defaults 1024 and 4096) and capture the stack at the message:

```wl
recFn[n_] := 1 + recFn[n + 1];
recStk = Catch[Internal`HandlerBlock[{"Message", Throw[Stack[_], "rec"] &},
    StackBegin[Block[{$RecursionLimit = 20}, recFn[1]]]], "rec"];
{Length[recStk], Tally[Cases[recStk, _[(h_Symbol)[___]] :> h]]}
(* {22, {{Block, 1}, {Plus, 18}, {recFn, 1}, {Message, 1}, {Throw, 1}}}   -- the message is $RecursionLimit::reclim *)
```

```wl
itFn[n_] := itFn[n + 1];
Catch[Internal`HandlerBlock[{"Message", Throw[Stack[_], "it"] &},
    StackBegin[Block[{$IterationLimit = 50}, itFn[1]]]], "it"]
(* 4 frames: Block[{$IterationLimit = 50}, itFn[1]], itFn[50 + 1], Message[$IterationLimit::itlim, ...], Throw[...] *)
```

`While`/`Do` loops do not count toward `$IterationLimit`; for loops use stack sampling (`TracingAndPerformance.md`).
Never set `$RecursionLimit` globally in an MCP kernel (in MCP Session a low global value closed the server); use `Block`.

In 15.0 the runaway evaluation is replaced by `TerminatedEvaluation[...]`, and how much is replaced depends on the
environment:

```wl
{Block[{$RecursionLimit = 50}, recFn[1]], "after"}
(* MCP Local, MCP Session: {TerminatedEvaluation["RecursionLimit"], "after"}
   wolfram -script: the same inside Print[ToString[...]]; a statement ending in ";" is dropped whole; later lines run
   wolframscript -f: the whole script ends; its result is TerminatedEvaluation[RecursionLimit], later lines never run
   CloudEvaluate: Hold[Throw[TerminatedEvaluation["RecursionLimit"], TerminatedEvaluation["RecursionLimit", 50]]] + Throw::nocatch *)
```

Contain it portably (checked in MCP Local, MCP Session, wolframscript and the remote MCP server; in CloudEvaluate with a
limit of 150, because its 64 wrapper frames count toward the limit). The termination is a `Throw` with a
`TerminatedEvaluation[...]` tag, but under `StackBegin` a `Catch` sees it only when a `CompoundExpression`, `Module`,
`Block`, `Table` or another `Catch` lies between them (not a list, `If`, `With` or a function argument). Both MCP methods
wrap every input in `StackBegin`, so there a `Catch[...]` that is the whole input, a list element or an argument becomes
`TerminatedEvaluation["RecursionLimit"]` itself, while `res = Catch[...]; ...` works. Assign the result and also test
the value:

```wl
recRes = Catch[Block[{$RecursionLimit = 50}, recFn[1]], _TerminatedEvaluation, Function[{value, tag}, tag]];
If[FreeQ[recRes, _TerminatedEvaluation], recRes, Failure["RecursionLimit", <|"Terminated" -> recRes|>]]
(* Failure["RecursionLimit", <|"Terminated" -> TerminatedEvaluation["RecursionLimit", 50]|>] *)
```

Wrapping the part in `StackBegin[...]` also keeps wolframscript from ending the script (that part becomes
`TerminatedEvaluation["RecursionLimit"]`).

### Uncaught `Throw` (`Throw::nocatch`)

`Throw::nocatch` is issued after the evaluation has unwound, so `"Message"` handlers never see it (and in
`wolfram -script` an uncaught `Throw` ends the file silently). Find where the `Throw` comes from by probing `Throw`
itself, in record mode (throwing from the condition of a rule for `Throw` is unreliable: unless a `Catch` for the
original tag lies inside yours, the original or your `Throw` ends up uncaught):

```wl
thrower[x_] := Throw[x, "nope"]; wrapper[x_] := 1 + thrower[x];
Module[{bag = Internal`Bag[]},
  Internal`InheritedBlock[{Throw},
    Unprotect[Throw];
    PrependTo[DownValues[Throw],
      HoldPattern[Throw[_, "nope"]] /; (Internal`StuffBag[bag, Stack[]]; False) :> Null];
    Catch[StackBegin[StackComplete[wrapper[5]]], _, Function[{value, tag}, Null]];];
  Internal`BagPart[bag, All]]
(* {{StackComplete, wrapper, Plus, thrower, Throw, CompoundExpression, Internal`StuffBag}} *)
```

### `Assert`

An `"Assertions"` handler receives every failing `Assert` as `HoldComplete[Assert[test]]` (with `{line, file}` when the
code was loaded with `Get`), even though `Assert` is off by default; passing assertions are not reported:

```wl
assertFn[x_] := (Assert[x > 0]; Sqrt[x]);
Module[{bag = Internal`Bag[]},
  Internal`HandlerBlock[{"Assertions", Internal`StuffBag[bag, {#, Stack[]}] &},
    StackBegin[StackComplete[assertFn /@ {4, -1}]]];
  Internal`BagPart[bag, All]]
(* {{HoldComplete[Assert[-1 > 0]], {StackComplete, Map, List, assertFn, CompoundExpression, Assert, Function, Internal`StuffBag, List}}}
   loaded from a file: HoldComplete[Assert[-1 > 0, {1, "/path/to/file.wl"}]] *)
```

``WolframDebugging`FailedAssertions[expr]`` lists them.

## When a Throw-based probe returns the normal result

A tagged `Throw` from your handler or probe is intercepted by a catch-all `Catch[..., _]` in the code under test, and by
`EvaluationData`, `VerificationTest`/`TestReport` and `GenerateHTTPResponse`; `EvaluationData` and `GenerateHTTPResponse`
turn it into `Throw::nocatch`, which can trigger your handler again at an unrelated place. The code continues with its
fallback and you get no stack, or the wrong one:

```wl
safeFirst[x_] := Catch[First[x], _, Function[{value, tag}, "fallback"]];
Catch[Internal`HandlerBlock[{"Message", Throw[Stack[], "msg"] &}, StackBegin[StackComplete[safeFirst[{}]]]], "msg"]
(* "fallback" *)
```

Record and continue instead (no `Throw`):

```wl
Module[{bag = Internal`Bag[]},
  {Internal`HandlerBlock[{"Message", If[Last[#], Internal`StuffBag[bag, Stack[]]] &},
     StackBegin[StackComplete[safeFirst[{}]]]],
   Internal`BagPart[bag, All]}]
(* {First[{}], {{StackComplete, safeFirst, Catch, First, Message, Function, If, Internal`StuffBag}}} *)
```

Plain `Catch[expr]` (no tag), `Enclose`, `Check` and `Quiet` do not intercept a tagged `Throw`.

## Environment notes

- **Remote MCP server**: every input runs inside `Quiet`, so all handlers see `willPrint = False` and recipes that test
  for `True` record nothing. Detect it with ``Lookup[Internal`QuietStatus[], "Global"] === "Quiet"`` (`"Unquiet"` in MCP
  Local and MCP Session; do not wrap the test in `Quiet`). Wrap the code under test in `Quiet[expr, None, All]` (the
  handler then sees `True` again) or match `Hold[Message[_, ___], _]`.
- **MCP Session**: messages render on one line; the tool collects them through its own handler, so only `Quiet`, `Off`
  and `"Message.Veto"` hide one from the tool output; `Off`, ``Internal`AddHandler`` and limit changes affect the server.
- **MCP Local**: message text is printed in 2-D form (fractions over three lines). Both MCP methods append
  `General::messages` after a one-line message (MCP Local omits it when every message came out in 2-D, as `Power::infy`).
- MCP Session and the remote MCP server drop messages after 10 prints and messages in one call; return collected data as the
  value instead (`Environments.md`).
- **Parallel subkernels**: master handlers, `Check`, `EvaluationData` and `$MessageList` do not see subkernel messages;
  collect inside the subkernel (`ParallelAndAsync.md`). An unevaluated result such as `First[{}]` returned by a subkernel
  is evaluated again in the master and issues its message there too.
- `On[f]` (trace messages `f::trace`) only works where `Trace` works (`TracingAndPerformance.md`).
