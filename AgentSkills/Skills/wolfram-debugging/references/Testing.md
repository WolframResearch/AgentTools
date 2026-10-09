# Testing: VerificationTest, TestReport, MUnit

How to run test files and read the results compactly, what the outcome and failure-type values really are, which file
problems make tests silently disappear, how the test harness evaluates a test, how to re-run or reproduce one failing
test, and how to find order dependence. Read it when a test fails, passes only alone (or only in the suite), or a test
run reports suspiciously few tests. Behavior was checked with Wolfram 15.0 (MCP Local, wolframscript, the TestReport MCP
tool, fresh MCP Session and Local servers and the remote MCP server where stated; see `Environments.md`).

## Which tool for which question

| question | first choice | section |
|---|---|---|
| run a test file | TestReport MCP tool (one file, `timeConstraint`) | Run tests with the TestReport MCP tool |
| which tests failed and why, compactly | `tr["Results"]` filtered + selected properties; ``WolframDebugging`TestFailureSummary[tr]`` | Read a TestReportObject compactly |
| "Total Tests: 0" or fewer tests than expected | syntax error / malformed test / top-level abort: static check; ``WolframDebugging`CheckTestFile[file]`` | Silent whole-file failures |
| test fails only on its messages | expected-message rules | Expected messages |
| re-run one test (with its setup tests) | `VerificationTest` filter in ``Internal`InheritedBlock``; ``WolframDebugging`RunTestsByID[file, id]`` | Re-run one test |
| where does the failing input go wrong? | stack at the first message; `IntermediateTest`; ``WolframDebugging`ReproduceTest[t]`` | Reproduce a failing input |
| passes alone, fails in the suite | run alone in a fresh kernel, per-test state snapshots | Order dependence |
| passes locally, fails in CI | MX build: ReadProtected symbols | CI-only failures |

Helpers are in `scripts/WolframDebugging.wl` (load it with `Get` in its own call, call them fully qualified; options and
outputs: `HelperFunctions.md`; ``WolframDebugging`TestSource[file, idPattern]`` gives a test's source lines without
evaluating anything). Everything below works without them.

The examples use small test files in `testDir` (`testDir = "/abs/path/to/tests";`). `Demo.wlt`:

```wl
VerificationTest[1 + 1, 2, TestID -> "Pass"]
VerificationTest[StringJoin["a", "b"], "ba", TestID -> "WrongResult"]
VerificationTest[1/0, ComplexInfinity, TestID -> "UnexpectedMessage"]
VerificationTest[1/0, ComplexInfinity, {Power::infy}, TestID -> "ExpectedMessageOK"]
VerificationTest[1/2, 1/2, {Power::infy}, TestID -> "ExpectedMessageMissing"]
VerificationTest[Failure["Boom", <|"MessageTemplate" -> "boom"|>], 1, TestID -> "FailureResult"]
VerificationTest[Throw[42, "tag"], 42, TestID -> "UncaughtThrow"]
VerificationTest[Pause[3]; 1, 1, TimeConstraint -> 1, TestID -> "TimeOut"]
VerificationTest[Table[1/0, 5]; 7, 7, TestID -> "GeneralStop"]
VerificationTest[StringLength[ToString[1/0]], 14, TestID -> "WrongAndMessage"]
```

## Run tests with the TestReport MCP tool

- Each call starts a fresh `wolfram -script` kernel with `-noinit` (several seconds of startup); all files of one call
  (a comma list or a directory) run in that one kernel, so state leaks from file to file. (`newKernel: false` runs
  them in the MCP server's own kernel instead, and their state stays there.)
- `timeConstraint` is the default limit **per test** (not per file); there is no overall limit, so a hanging test without
  it hangs the tool call. Pass it.
- Trace records nothing inside these tests. A test that prints its environment showed
  ``{First[$ContextPath], $Context, Trace[1 + 1] =!= {}, MemberQ[$CommandLine, "-noinit"], Internal`TimeRemaining[]}`` =
  ``{"MUnit`", "Global`", False, True, 29.999894}`` with `timeConstraint: 30`.
- Output: a Markdown summary (Overall Result, Total Tests, Passed, Failed), then per failed test its Input, Expected and
  Actual Output and Messages (about 400–700 bytes per failure). Passing tests and the failure type are not listed.
- Anything printed outside the tests (messages from top-level code, `VerificationTest::nonopt`, syntax errors, `Print`)
  appears **above** `# Test Results Summary`. Read it.
- **Always check "Total Tests"**: a file with a syntax error reports `Overall Result: Success` with `Total Tests: 0`, and a
  file with a top-level `Abort[]` returns no output at all (next section).

## Read a TestReportObject compactly

In the evaluator or wolframscript, never return the `TestReportObject` or a `TestObject` itself (`ByteCount` of the
10-test report below: 51 KB; every TestObject carries its inputs, outputs and timing). Select what you need:

```wl
tstReport = TestReport[FileNameJoin[{testDir, "Demo.wlt"}], ProgressReporting -> False, TimeConstraint -> 30];
{tstReport["TestsSucceededCount"], tstReport["TestsFailedCount"],
 #[{"TestID", "Outcome", "FailureType"}] & /@ Select[tstReport["Results"], #["Outcome"] =!= "Success" &]}
(* {2, 8, {<|"TestID" -> "WrongResult", "Outcome" -> "Failure", "FailureType" -> "SameTestFailure"|>,
           <|"TestID" -> "UnexpectedMessage", "Outcome" -> "MessagesFailure", "FailureType" -> "SameMessagesFailure"|>,
           <|"TestID" -> "ExpectedMessageMissing", "Outcome" -> "MessagesFailure", "FailureType" -> "SameMessagesFailure"|>,
           <|"TestID" -> "FailureResult", "Outcome" -> "Failure", "FailureType" -> "SameTestFailure"|>,
           <|"TestID" -> "UncaughtThrow", "Outcome" -> "Failure", "FailureType" -> "UncaughtThrowFailure"|>,
           <|"TestID" -> "TimeOut", "Outcome" -> "Failure", "FailureType" -> "TimeConstrainedFailure"|>,
           <|"TestID" -> "GeneralStop", "Outcome" -> "MessagesFailure", "FailureType" -> "SameMessagesFailure"|>,
           <|"TestID" -> "WrongAndMessage", "Outcome" -> "Failure", "FailureType" -> "SameTestFailure"|>}} *)
```

One line per failure, with the actual value and the message names (`tstReport` from above):

```wl
StringRiffle[Function[t, StringJoin[t["TestID"], " [", t["Outcome"], "/", ToString[t["FailureType"]], "] act: ",
    StringTake[ToString[t["ActualOutput"], InputForm], UpTo[60]], " msgs: ",
    StringTake[ToString[Replace[t["ActualMessages"], HoldForm[Message[m_, ___]] :> HoldForm[m], {1}], InputForm], UpTo[80]]]] /@
  Select[tstReport["Results"], #["Outcome"] =!= "Success" &], "\n"]
```
```
WrongResult [Failure/SameTestFailure] act: HoldForm["ab"] msgs: {}
UnexpectedMessage [MessagesFailure/SameMessagesFailure] act: HoldForm[ComplexInfinity] msgs: {HoldForm[Power::infy]}
ExpectedMessageMissing [MessagesFailure/SameMessagesFailure] act: HoldForm[1/2] msgs: {}
FailureResult [Failure/SameTestFailure] act: HoldForm[Failure["Boom", <|"MessageTemplate" -> "boom"|>]] msgs: {}
UncaughtThrow [Failure/UncaughtThrowFailure] act: Hold[Throw[42, "tag"]] msgs: {}
TimeOut [Failure/TimeConstrainedFailure] act: HoldForm[Failure["TimeConstrained", <|"MessageTemplate" :> T msgs: {}
GeneralStop [MessagesFailure/SameMessagesFailure] act: HoldForm[7] msgs: {HoldForm[Power::infy], HoldForm[Power::infy], HoldForm[Power::infy], HoldForm[G
WrongAndMessage [Failure/SameTestFailure] act: HoldForm[15] msgs: {HoldForm[Power::infy]}
```

Helper: ``WolframDebugging`TestFailureSummary[tstReport]`` (input, expected, actual, message texts,
failed `IntermediateTest` steps, within a byte budget).

### Outcomes, failure types, value formats

| situation | `"Outcome"` | `"FailureType"` |
|---|---|---|
| passed | `"Success"` | `None` |
| wrong value (also a returned `Failure[...]` or an unevaluated `f[3]`) | `"Failure"` | `"SameTestFailure"` |
| `SameTest` function returned a non-Boolean | `"Failure"` | `"SameTestUnevaluated"` |
| unexpected, missing or different messages | `"MessagesFailure"` | `"SameMessagesFailure"` |
| uncaught `Throw` | `"Failure"` | `"UncaughtThrowFailure"` |
| `Abort[]` in the input | `"Failure"` | `"EvaluationAbortedFailure"` |
| `TimeConstraint` / `MemoryConstraint` exceeded | `"Failure"` | `"TimeConstrainedFailure"` / `"MemoryConstrainedFailure"` |
| an `IntermediateTest` step failed | `"Failure"` | `"IntermediateTestFailure"` |
| created with `TestCreate` but not run | `"NotEvaluated"` | `None` |

The documentation's `"MessageFailure"`, `"TimeConstraintFailure"` and `"MemoryConstraintFailure"` do not occur; compare
against the strings above. A wrong value wins over messages: `WrongAndMessage` is `"Failure"` although it also issued
`Power::infy`, so look at `"ActualMessages"` for every failure.

Values are held, not evaluated; never `ReleaseHold` them (that re-runs the input):

```wl
{ToString[#, InputForm] & /@ First[tstReport["ResultsByTestID"]["UnexpectedMessage"]][
   {"Input", "ExpectedOutput", "ActualOutput", "ExpectedMessages", "ActualMessages"}],
 First[tstReport["ResultsByTestID"]["UncaughtThrow"]]["ActualOutput"],
 First[tstReport["ResultsByTestID"]["ExpectedMessageOK"]]["ExpectedMessages"]}
(* {<|"Input" -> "HoldForm[1/0]", "ExpectedOutput" -> "HoldForm[ComplexInfinity]", "ActualOutput" -> "HoldForm[ComplexInfinity]",
      "ExpectedMessages" -> "HoldForm[{}]", "ActualMessages" -> "{HoldForm[Message[Power::infy, HoldCompleteForm[0^(-1)]]]}"|>,
    Hold[Throw[42, "tag"]], HoldForm[{Power::infy}]} *)
```

`"Input"`/`"ExpectedOutput"`/`"ActualOutput"` are `HoldForm[...]` (a `Throw` or `Abort[]` gives `Hold[...]`),
`"ExpectedMessages"` is one `HoldForm` around the list, `"ActualMessages"` a list of `HoldForm[Message[...]]` whose
kernel-issued arguments are `HoldCompleteForm[...]` in 15.0 (older versions: `HoldForm`). Strip with patterns such as
`Replace[v, (HoldForm | Hold)[e_] :> ToString[Unevaluated[e], InputForm]]`.

`tr["Properties"]` lists only some of the properties that work; the legacy groups are useful too:

```wl
{tstReport["Properties"], Keys[tstReport["TestsFailed"]], Length /@ tstReport["ResultsByOutcome"]}
(* {{"Title", "Results", "ResultsDataset", "ResultsByOutcome", "ResultsByTestFileName", "ResultsByTestID", "RuntimeFailures",
     "ReportSucceeded", "MemoryUsed", "CPUTimeUsed", "AbsoluteTimeUsed"},
    {"TestsFailedWrongResults", "TestsFailedWithMessages", "TestsFailedWithErrors"},
    <|"Success" -> 2, "MessagesFailure" -> 3, "Failure" -> 5, "NotEvaluated" -> 0|>} *)
```

`"TestsSucceededCount"`, `"TestsFailedCount"`, `"TestsFailedWrongResults"` (every `"Failure"`, including throws, aborts and
time-outs) and `"TestsFailedWithMessages"` work although they are not listed; `"TestsFailedWithErrors"` is always empty.
`"ResultsByTestID"` maps each ID to a *list* (IDs can repeat). Unknown property names return `Missing["KeyAbsent", ...]`
without a message.

## Silent whole-file failures

Three file problems lose tests without a failing outcome (`Syntax.wlt`: a test `VerificationTest[1 +, 2, ...]` between
two good ones; `Dropped.wlt`: a good test and one with a fourth positional argument; `TopAbort.wlt`: `Abort[];` between
two tests):

```wl
{With[{r = TestReport[FileNameJoin[{testDir, "Syntax.wlt"}], ProgressReporting -> False]},
   {Length[r["Results"]], r["TestsSucceededCount"], r["RuntimeFailures"]}],
 Length[TestReport[FileNameJoin[{testDir, "Dropped.wlt"}], ProgressReporting -> False]["Results"]],
 CheckAbort[TestReport[FileNameJoin[{testDir, "TopAbort.wlt"}], ProgressReporting -> False], "aborted"]}
```
```
Read::readt: Invalid input found when reading VerificationTest[1 +, 2, TestID -> "S-Broken"] from .../Syntax.wlt.
TestReport::rnterr: Syntax error reading: VerificationTest[1 +, 2, TestID -> "S-Broken"].
VerificationTest::nonopt: Options expected (instead of {extra}) beyond position 3 in VerificationTest[...]. An option must be a rule or a list of rules.
{{0, 0, {Failure["TestReportFailure", <|"MessageTemplate" :> TestReport::rnterr, "MessageParameters" -> {"Syntax error reading: ..."}, "Level" -> "Fatal"|>]}},
 1, "aborted"}
```

- **A syntax error anywhere runs no test at all**, not even the ones before it (the whole file is syntax-checked
  before the first test runs). The TestReport MCP tool then says `Overall Result: Success`, `Total Tests: 0` (with the
  messages and `AgentTools::NoTestsInFile` above the summary).
- **A `VerificationTest` with more than three positional arguments** (e.g. a stray second message list) issues
  `VerificationTest::nonopt` and is dropped from the report; the tool counts 1 test for `Dropped.wlt`.
- **A top-level `Abort[]`** (outside any test) aborts the whole `TestReport`; an uncaught top-level `Throw` escapes it.
  The TestReport MCP tool returns no output at all.
- MUnit's `BeginTestSection[name, False]` skips the tests of its section, and a top-level `TestIgnore[True]` every later
  test of the file (a later `TestIgnore[False]` does not undo it), without listing them.

Check files statically before trusting a count: the CodeInspector MCP tool (finds syntax errors, not malformed tests),
``WolframDebugging`CheckTestFile[file]`` (syntax errors, top-level `Abort`/`Throw`/`Exit`/`Quit`, malformed tests, missing
or duplicate TestIDs), or CodeParser directly:

```wl
Block[{$ContextPath}, Needs["CodeParser`"]];
Table[{FileNameTake[file],
   Cases[CodeParser`CodeParse[File[file]], (h : CodeParser`SyntaxErrorNode | CodeParser`ErrorNode |
        CodeParser`UnterminatedGroupNode | CodeParser`GroupMissingCloserNode)[tag_, _, KeyValuePattern[CodeParser`Source -> src_]] :>
      {SymbolName[h], tag, src}, Infinity],
   Cases[CodeParser`CodeParse[File[file]], CodeParser`CallNode[CodeParser`LeafNode[Symbol, "VerificationTest", _], args_,
        KeyValuePattern[CodeParser`Source -> src_]] /;
      Count[args, Except[CodeParser`CallNode[CodeParser`LeafNode[Symbol, "Rule" | "RuleDelayed", _], ___]]] > 3 :>
      {"MoreThan3PositionalArgs", src}, Infinity]},
  {file, FileNameJoin[{testDir, #}] & /@ {"Syntax.wlt", "Dropped.wlt", "Demo.wlt"}}]
(* {{"Syntax.wlt", {{"ErrorNode", Token`Error`ExpectedOperand, {{2, 21}, {2, 21}}}}, {}},
    {"Dropped.wlt", {}, {{"MoreThan3PositionalArgs", {{2, 1}, {2, 95}}}}},
    {"Demo.wlt", {}, {}}}      -- sources are {{line, column}, {line, column}} *)
```

## How the harness evaluates a test

Knowing this explains most surprises:

- The file is read **one expression at a time**, each parsed after the previous one ran. A `Get`/`Needs` in an earlier
  test (or top-level line) makes later short names resolve; a `Get` and a use of its symbols **inside one test** do not
  work (the whole test was parsed first). `Load.wlt` loads `ShadowDemo.wl` (exporting `shFn[x_] := x^2`) in its first
  test and uses `shFn` in both:

```wl
{#["TestID"], #["Outcome"], #["ActualOutput"], #["ActualMessages"]} & /@
  TestReport[FileNameJoin[{testDir, "Load.wlt"}], ProgressReporting -> False]["Results"]
(* {{"L-GetAndUseSameTest", "Failure", HoldForm[Global`shFn[3]], {HoldForm[Message[shFn::shdw, ...]]}},
    {"L-UseInLaterTest", "Success", HoldForm[9], {}}}
   (MCP evaluator: Sessions`<id>`shFn instead of Global`shFn) *)
```

  Load packages in a separate setup test (a common convention is tests with IDs like `"GetDefinitions"`/`"LoadContext"`).
- Each test runs inside `Block[{$Messages = {}, $MessageList = {}}]`: test messages are not printed, and the
  `General::stop` count starts again for every test. Messages are recorded by a `"MessageTextFilter"` handler, so only
  messages that would really print count (quieted ones, `Off` ones and the occurrences that `General::stop` suppresses
  do not; `General::stop` itself does). `Check` does not hide a message.
- The input runs under `StackBegin` (a stack taken inside a test starts at the test input) and `CheckAll`, which turns
  `Throw` and `Abort[]` into failures; `TimeConstraint`/`MemoryConstraint` (per test, or `TestReport`'s option as the
  default) wrap it.
- The expected output is evaluated **after** the input, and ``MUnit` `` is first on `$ContextPath` while a file runs:

```wl
ClearAll[tsOrder];
{VerificationTest[tsOrder = 5; tsOrder, tsOrder]["Outcome"],
 #["ActualMessages"] & /@ {VerificationTest[Table[1/0, 2]; 1, 1, {Power::infy ..}], VerificationTest[Table[1/0, 2]; 1, 1, {Power::infy ..}]}}
(* {"Success", {{HoldForm[Message[Power::infy, HoldCompleteForm[0^(-1)]]], HoldForm[Message[Power::infy, HoldCompleteForm[0^(-1)]]]},
                {HoldForm[Message[Power::infy, HoldCompleteForm[0^(-1)]]], HoldForm[Message[Power::infy, HoldCompleteForm[0^(-1)]]]}}}
   -- both tests record two Power::infy: the count restarts per test (shared counting would give General::stop in the second) *)
```

- `Print` inside a test is not captured: it goes to the output of the evaluator call, wolframscript's stdout, or the top of
  the TestReport tool's output.

## Expected messages

The third argument is matched against the ordered list of recorded messages, with exact multiplicity:

```wl
#["Outcome"] & /@ {
  VerificationTest[1/0, ComplexInfinity, {Power::infy}],
  VerificationTest[Table[1/0, 2], {ComplexInfinity, ComplexInfinity}, {Power::infy}],
  VerificationTest[Table[1/0, 2], {ComplexInfinity, ComplexInfinity}, {Power::infy ..}],
  VerificationTest[Table[1/0, 5]; 7, 7, {Power::infy .., General::stop}],
  VerificationTest[1/0, ComplexInfinity, {Message[Power::infy, HoldForm[1/0]]}],
  VerificationTest[1/0, ComplexInfinity, {Message[Power::infy, _]}],
  VerificationTest[Check[1/0, "chk"], "chk", {Power::infy}],
  VerificationTest[Quiet[1/0], ComplexInfinity]}
(* {"Success", "MessagesFailure", "Success", "Success", "MessagesFailure", "Success", "Success", "Success"} *)
```

- List names in issue order with the exact count; `name ..` means one or more. A message issued more than three times
  in a test is recorded three times plus `General::stop`: `{Power::infy .., General::stop}`.
- Do not write message arguments: 15.0 records kernel message arguments as `HoldCompleteForm[0^(-1)]`, so an older-style
  `Message[Power::infy, HoldForm[1/0]]` fails. Use `_` or copy the form verbatim from `"ActualMessages"`.
- The expected symbol must match exactly (`General::nodef` does not match a message issued as `f::nodef`).
- An **outer `Quiet`** inverts message outcomes: unexpected messages pass, expected ones fail. The **remote MCP server
  evaluates every input under `Quiet`**, so there wrap tests in `Quiet[..., None, All]`:

```wl
{Quiet[VerificationTest[1/0, ComplexInfinity]]["Outcome"],
 Quiet[VerificationTest[1/0, ComplexInfinity, {Power::infy}]]["Outcome"],
 Quiet[Quiet[VerificationTest[1/0, ComplexInfinity, {Power::infy}], None, All]]["Outcome"]}
(* {"Success", "MessagesFailure", "Success"}   -- the first two are wrong; on the remote MCP server the plain tests give the same
   wrong results, and Quiet[VerificationTest[...], None, All] gives the correct ones *)
```

## Re-run one test

`TestEvaluate[t]` re-runs a `TestObject` (side effects happen again); `TestReport[{t}]` only re-reports it:

```wl
ClearAll[tsCount]; tsCount = 0;
With[{t = VerificationTest[++tsCount, 1]}, {t["Outcome"], TestEvaluate[t]["Outcome"], TestReport[{t}]["TestsSucceededCount"], tsCount}]
(* {"Success", "Failure", 1, 2}   -- TestEvaluate ran the input again (tsCount 2), TestReport[{t}] did not *)
```

To run only some tests of a file, skip the others with a rule prepended to `VerificationTest` inside
``Internal`InheritedBlock`` (top-level code and the tests you keep, e.g. setup tests, still run). `TestReport`'s
`TestEvaluationFunction` option has no effect on files. `OrderDep.wlt` is
`odMode = "fast"` (`"OD-Setup"`), `odMode = "slow"` (`"OD-ChangesMode"`), and a test expecting `odMode` to be `"fast"`
(`"OD-ReadsMode"`, which fails in the full file):

```wl
Needs["MUnit`"];   (* first: VerificationTest is an autoload stub until MUnit is loaded *)
Internal`InheritedBlock[{VerificationTest},
  Unprotect[VerificationTest];
  PrependTo[DownValues[VerificationTest], HoldPattern[VerificationTest[___, TestID -> id_, ___]] /;
    ! StringMatchQ[First[StringSplit[id, "@@"]], "OD-Setup" | "OD-ReadsMode"] :> Null];
  Protect[VerificationTest];
  #["TestID"] -> #["Outcome"] & /@ TestReport[FileNameJoin[{testDir, "OrderDep.wlt"}], ProgressReporting -> False]["Results"]]
(* {"OD-Setup" -> "Success", "OD-ReadsMode" -> "Success"} *)
```

- Load MUnit first: if it autoloads inside the block, its definitions replace the filter and every test runs.
- Some projects append the source location to TestIDs (`"GetDefinitions@@Tests/YAML.wlt:4,1-9,2"` = lines 4–9); match
  the part before `@@`, and use the suffix to find the source.
- Helpers: ``WolframDebugging`RunTestsByID[file, "MyTest"]`` (with an option for setup tests; summary of the
  selected tests), ``WolframDebugging`TestSource[file, "MyTest"]`` (the test's code and lines).
- In a fresh kernel from the shell (no state from earlier runs), put the same code in a `-f` script and run
  `timeout -s KILL 300 wolframscript -f rerun.wls < /dev/null`.

## Reproduce a failing input with a stack

Take the held input from the `TestObject` and run it under a message handler that throws the stack at the first message
(the `Replace` keeps the input unevaluated until it runs inside the handler):

```wl
Module[{t = First[tstReport["ResultsByTestID"]["GeneralStop"]], tag, st},
  st = Replace[t["Input"], HoldForm[in_] :> Catch[
     Internal`HandlerBlock[{"Message", Replace[#, Hold[Message[_, ___], True] :> Throw[Stack[_], tag]] &},
        StackBegin[StackComplete[in]]], tag]];
  If[ListQ[st], Replace[st, _[e_] :> ToString[Unevaluated[e], InputForm, TotalWidth -> 100], {1}], st]]
(* {"StackComplete[Table[1/0, 5]; 7]", "Table[1/0, 5]; 7", "Table[1/0, 5]", "1/0", "0^(-1)",
    "Message[Power::infy, HoldCompleteForm[0^(-1)]]", <3 frames of the handler>}
   (the message is printed once here: outside the harness, $Messages is not blocked) *)
```

- A `Catch` in the code under test can eat the `Throw`; then use a recording handler instead (see `MessagesAndStacks.md`)
  or ``WolframDebugging`ReproduceTest[t]`` (mirrors the harness: messages counted like the test, stack at the first one,
  nothing thrown).
- For a wrong value, apply the other references' tools to the input (`UnevaluatedCalls.md`, `OverridesAndWatchpoints.md`,
  `TracingAndPerformance.md`). Trace works in MCP Local and wolframscript, not inside the TestReport MCP tool.
- Localize the wrong step inside one long test with `IntermediateTest`:

```wl
With[{t = VerificationTest[Module[{a, b}, a = IntermediateTest[StringLength["abc"], 3, TestID -> "step-a"];
      b = IntermediateTest[a + 1, 5, TestID -> "step-b"]; b*2], 8, TestID -> "multi-step"]},
  {t["Outcome"], t["FailureType"], #[{"TestID", "Outcome", "ActualOutput"}] & /@ t["IntermediateTests"]}]
(* {"Failure", "IntermediateTestFailure", {<|"TestID" -> "step-a", "Outcome" -> "Success", "ActualOutput" -> HoldForm[3]|>,
                                           <|"TestID" -> "step-b", "Outcome" -> "Failure", "ActualOutput" -> HoldForm[4]|>}} *)
```

## Order dependence: passes alone, fails in the suite (or the reverse)

1. Run the failing test alone with its setup tests in a **fresh** kernel (the filter recipe above in a wolframscript
   file, or `RunTestsByID`). Passes alone → an earlier test, or an earlier *file* in the same TestReport tool call,
   leaves state behind. Fails alone → it depends on state from an earlier test: add that test to the setup or make the
   test self-contained.
2. Find the culprit: record which symbols each test changed, using the `"FileStarted"` and `"TestEvaluated"` events
   of `TestReport` (hashes of `OwnValues`/`DownValues` of the user contexts and `$ContextPath`):

```wl
Module[{snap, before, changes = Internal`Bag[]},
  snap[] := Join[<|"$ContextPath" -> Hash[$ContextPath]|>,
    Association @ Map[# -> Hash[ToExpression[#, InputForm, Function[s, {OwnValues[s], DownValues[s]}, HoldAllComplete]]] &,
      Select[Flatten[Function[c, c <> StringDelete[#, ___ ~~ "`"] & /@ Names[c <> "*"]] /@ DeleteDuplicates[{"Global`", $Context}]],
        StringFreeQ["$" ~~ DigitCharacter ..]]]];
  TestReport[FileNameJoin[{testDir, "OrderDep.wlt"}], ProgressReporting -> False,
    HandlerFunctions -> <|"FileStarted" -> ((before = snap[]) &), "TestEvaluated" -> Function[Module[{now = snap[]},
      Internal`StuffBag[changes, #TestObject["TestID"] -> Select[Keys[now], now[#] =!= Lookup[before, #] &]]; before = now]]|>];
  Internal`BagPart[changes, All]]
(* wolframscript: {"OD-Setup" -> {"Global`odMode"}, "OD-ChangesMode" -> {"Global`odMode"}, "OD-ReadsMode" -> {}}
   MCP evaluator (where an earlier run had left odMode = "fast"): {"OD-Setup" -> {}, "OD-ChangesMode" -> {"Sessions`<id>`odMode"}, "OD-ReadsMode" -> {}} *)
```

   `"OD-ChangesMode"` changed `odMode`, which `"OD-ReadsMode"` reads. Run this in a fresh kernel: assigning a value a
   symbol already had is not a change (the MCP evaluator result). Add your package's contexts to the list, and watch other
   channels when needed (`Hold[Messages[sym]]` for `Off[sym::tag]`, `Options[f]` for `SetOptions`). Note the parentheses
   in `((before = snap[]) &)`: `before = snap[] &` would assign the function itself.
3. Or bisect: re-run the failing test with growing sets of the preceding tests, each in a fresh kernel.

Typical leak channels: values and definitions of shared symbols, `Off[...]`, `SetOptions`, `$ContextPath`, handlers,
package-private flags and caches.

## TestReport in the evaluator, in wolframscript and in the tool

| | TestReport MCP tool | `TestReport` in MCP Local | in MCP Session | wolframscript |
|---|---|---|---|---|
| kernel | fresh per call (`-noinit`) | the shared subkernel | the MCP server kernel | fresh per run |
| `$Context` of test code | ``Global` `` | ``Sessions`<id>` `` | ``Sessions`<id>` `` | ``Global` `` |
| Trace inside tests | no | yes | no | yes |
| test messages in the output | hidden | hidden | **shown** (Chatbook's handler ignores the harness) + `General::messages` | hidden |
| evaluator time limit | none (per-test `timeConstraint`) | not enforced (see below) | not enforced | none |
| state left behind | none | yes, for every session | yes, in the server | none |

- **The evaluator's time limit does not stop `TestReport`.** When it fires, the running (possibly passing) test fails
  with `"EvaluationAbortedFailure"` (both methods) and the remaining tests keep running past the limit (four 2-second
  tests under a 5-second limit took 7 s, the third one "failed", and the call returned its normal result). Pass
  `TimeConstraint -> n` to `TestReport` and treat such a failure as possibly caused by the tool limit. In MCP Local a
  call that is still running about 20 s after its limit gets the shared subkernel restarted, which loses every
  session's state (fifteen 2-second tests under a 5-second limit: only the time-out Failure, after 22 s).
- Never run a project's whole test files in the MCP evaluator: their setup code (`PacletDirectoryLoad`, `Off[...]`,
  `SetOptions`, global flags) changes the shared kernel or the server. Use the TestReport tool or wolframscript; use the
  evaluator to reproduce single inputs.
- wolframscript, compact (prints `{2, 8}` for `Demo.wlt`):
  `timeout -s KILL 300 wolframscript -code 'tr = TestReport["/abs/Foo.wlt", ProgressReporting -> False, TimeConstraint -> 30]; ToString[{tr["TestsSucceededCount"], tr["TestsFailedCount"]}, InputForm]'`
- In MCP Session, messages raised inside tests appear in the tool output (they are not failures of your call); read the
  outcomes instead.

## CI-only failures: MX builds and ReadProtected

CI pipelines often test the built paclet, where an MX build may set `ReadProtected` on all package symbols. Code (or
tests) that read definitions with `Definition`, `FullDefinition` or ``Language`ExtendedFullDefinition`` then see
nothing, while `DownValues` still works. Emulate it locally before running the tests:

```wl
ClearAll[mxDemo`mean]; mxDemo`mean[l_List] := Total[l]/Length[l];
{ToString[Definition[mxDemo`mean], InputForm],
 SetAttributes[Evaluate @ Names["mxDemo`*"], ReadProtected]; ToString[Definition[mxDemo`mean], InputForm],
 Length[DownValues[mxDemo`mean]]}
(* {"mxDemo`mean[l_List] := Total[l]/Length[l]", "Attributes[mxDemo`mean] = {ReadProtected}", 1} *)
```

Use `DownValues` (or clear ReadProtected inside ``Internal`InheritedBlock``, see `DefinitionsAndSource.md`) in code that
inspects definitions. Also check that the build under test is current: a stale build directory can shadow the source
(`PackageLoading.md`).

## Gotchas

- Check "Total Tests" (or `Length[tr["Results"]]`) against the number of tests in the file; read the text above the tool's
  summary.
- Outcome strings are `"MessagesFailure"`, `"TimeConstrainedFailure"`, `"MemoryConstrainedFailure"` (not the documented
  names); a wrong value hides messages in the outcome.
- Never `ReleaseHold` test values; never return report objects.
- `Get` and use in one test fails; load in an earlier test.
- Expected messages: order and count matter, `General::stop` counts, no literal arguments; an outer `Quiet` (and the
  remote MCP server) inverts message outcomes.
- ``Needs["MUnit`"]`` before overriding `VerificationTest`; `TestEvaluationFunction` does nothing for files.
- Files of one TestReport tool call share a kernel; the evaluator time limit does not bound `TestReport`.
- MCP evaluator: tests run in ``Sessions`<id>` ``, where your typed definitions are.
