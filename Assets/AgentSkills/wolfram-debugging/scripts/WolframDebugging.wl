(* ::Package:: *)

(* ::**************************************************************************************************************:: *)
(* ::Title:: *)
(*WolframDebugging*)

(* :Summary: Helper functions of the wolfram-debugging agent skill: bounded, side-effect-free tools for debugging
   Wolfram Language code (messages and stacks, unevaluated calls, tracing and profiling, spies and mocks, watchpoints,
   definitions and source files, package loading, tests, parallel and asynchronous code, cloud/HTTP, environments). *)

(* :Tested-With: Wolfram 15.0 (Linux): wolframscript, the MCP evaluator (Local and Session methods), CloudEvaluate. *)

(*
    LOADING
        Load the file with Get on its OWN line (of an MCP tool call or a wolframscript -f file), then ALWAYS call the
        helpers fully qualified, on a later line or in a later call:

            Get["/absolute/path/to/wolfram-debugging/scripts/WolframDebugging.wl"]
            WolframDebugging`CollectMessages[myFunction[1, 2]]

        - MCP evaluator and wolframscript: each input (a line of a tool call or -f file, a whole -code string) is
          parsed before it runs, so an unqualified name in the same input as Get is created in the current context.
        - wolframscript:  wolframscript -code 'Get["/abs/WolframDebugging.wl"]; Print[ToString[WolframDebugging`EnvironmentInfo[], InputForm]]'
        - CloudEvaluate:  load the file locally, then CloudEvaluate[WolframDebugging`CollectMessages[...]] (the
          definitions are sent along); a CloudDeploy of code that calls the helpers bundles them automatically.

    DESIGN RULES (every public function)
        - Loading has no side effects: no handlers, no global settings, no System` changes, no Global` symbols, no
          messages; dependencies (CodeParser`, CodeInspector`, MUnit`, Parallel`) load lazily inside the functions.
          Loading again with Get replaces the definitions (re-Get safe).
        - Handlers are only installed with Internal`HandlerBlock and overrides only with Internal`InheritedBlock, so
          everything is restored when the helper returns, aborts or throws.
        - The code under test is evaluated only inside the helper (Hold attributes) and contained: an uncaught Throw
          or Abort[] in it becomes a Failure["UncaughtThrow", ...] or $Aborted result instead of escaping.
        - Results are small associations or strings: stacks, traces and reports are summarized (raw data only on
          request, e.g. "RawStack" -> True), and the value of the evaluated code is replaced by
          Missing["TooLarge", <|"ByteCount" -> ..., "Preview" -> ...|>] when it exceeds "MaxResultBytes" (10^4).
        - Invalid calls return Failure["WolframDebugging", <|"MessageTemplate" -> ..., "MessageParameters" -> ...,
          "Expected" -> <call form>|>] and are never left unevaluated.
        - Stack frames, trace items and message arguments are HoldCompleteForm[...] in 15.0 (HoldForm[...] in older
          versions); every pattern here accepts both, and frames are never evaluated.
        - Trace-based helpers (TraceCalls, CountCalls, FindHang) return Failure["TraceUnavailable", ...] where Trace
          records nothing (MCP Session method, wolfram -script, Wolfram Cloud, remote MCP server).
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)

(* MUnit` (on $ContextPath inside TestReport) has its own TestSource symbol. Get warns about symbols that a package
   creates while a symbol of the same name is visible (TestSource::shdw); creating this one before BeginPackage avoids
   the warning. The helpers are always called fully qualified, so the shadowing does not matter. *)
WolframDebugging`TestSource;

BeginPackage[ "WolframDebugging`" ];

(* Loading the file again replaces every definition: *)
Unprotect[ "WolframDebugging`*" ];
ClearAll[ "WolframDebugging`*" ];
ClearAll[ "WolframDebugging`Private`*" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Usage Messages*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Core*)
ShortString::usage =
"ShortString[expr] gives a one-line InputForm string of expr with at most 150 characters.
ShortString[expr, n] uses at most n characters. One HoldComplete/HoldCompleteForm/HoldForm wrapper is stripped; big \
subexpressions are elided as <<k>>.";

EnvironmentInfo::usage =
"EnvironmentInfo[] describes the evaluation environment (MCP evaluator method, wolframscript, wolfram -script, cloud) \
and what it means for debugging.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Messages and Stacks*)
CollectMessages::usage =
"CollectMessages[expr] evaluates expr and returns its result and the messages it issued, each with its text, \
whether it was printed or quieted, and the last stack frames.";

StackAtMessage::usage =
"StackAtMessage[expr] gives the evaluation stack at the first printed message of expr.
StackAtMessage[expr, msg] uses the first message matching msg (Power::infy, \"Power::*\", \"*::infy\" or a pattern).";

StackAtCall::usage =
"StackAtCall[expr, callPattern] gives the evaluation stack when a call matching callPattern (f[0], _f, f[x_] /; x < 0) \
is evaluated during expr; the call frame shows the actual argument values.";

FormatStack::usage =
"FormatStack[stack] renders a list of stack frames (HoldCompleteForm[...] or HoldForm[...]) as a numbered, \
truncated string, collapsing recursion cycles.";

StackSummary::usage =
"StackSummary[stack] gives the length, byte count, most common frame heads and head contexts of a list of stack frames.";

CaptureEvaluation::usage =
"CaptureEvaluation[expr] evaluates expr under $CaptureFunction and returns its result, messages, Print output, \
stack at the first message, Abort/Throw status and time as one small association.";

$CaptureFunction::usage =
"$CaptureFunction is a self-contained pure function (HoldAll; it needs no definitions: only System` and Internal` \
functions and its own local variables) that evaluates its argument like CaptureEvaluation. Inject it into subkernels \
and task bodies: With[{cap = WolframDebugging`$CaptureFunction}, ParallelMap[cap[f[#]] &, list]].";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Performance and Trace*)
SampleStacks::usage =
"SampleStacks[expr] evaluates expr for at most min(10 s, the remaining tool time) while sampling the evaluation stack, \
and reports where the time went and where the evaluation was when it stopped.
SampleStacks[expr, maxSeconds] stops expr after maxSeconds.";

TimeCalls::usage =
"TimeCalls[expr, {f, g, ...}] gives exact call counts and inclusive wall-clock seconds of the functions f, g, ... \
while expr is evaluated.";

TraceAvailableQ::usage =
"TraceAvailableQ[] gives True if Trace records evaluations in this kernel.";

TraceCalls::usage =
"TraceCalls[expr, form] gives the first 20 evaluations matching form (after their arguments were evaluated) as short \
strings and stops the evaluation.
TraceCalls[expr, form, n] gives the first n.";

CountCalls::usage =
"CountCalls[expr, form] counts the evaluations matching form during expr, grouped by head.";

FindHang::usage =
"FindHang[expr] evaluates expr for at most 10^5 evaluation steps and, if it has not finished, gives the stack heads \
and the last steps.
FindHang[expr, maxSteps] uses at most maxSteps steps.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Overrides*)
LogCalls::usage =
"LogCalls[{f, g, ...}, expr] evaluates expr while recording every call to f, g, ... with its depth, result and time.";

CallLogSummary::usage =
"CallLogSummary[log] gives an indented text tree of the first 30 calls in a LogCalls result.
CallLogSummary[log, n] shows the first n calls.";

WithOverrides::usage =
"WithOverrides[{lhs :> rhs, ...}, expr] evaluates expr with the rules temporarily added in front of the existing \
definitions and returns HoldComplete[result].";

SnapshotDefinitions::usage =
"SnapshotDefinitions[sym] returns an association with all definitions and attributes of sym.";

RestoreDefinitions::usage =
"RestoreDefinitions[sym, snapshot] restores the definitions and attributes saved by SnapshotDefinitions and gives \
True if sym now matches the snapshot.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Watchpoints and Probes*)
WatchChanges::usage =
"WatchChanges[{sym, ...}, expr] records every change of the values or definitions of the symbols while expr is \
evaluated, with the functions that made it.";

StopWhen::usage =
"StopWhen[sym, test, expr] evaluates expr and stops at the first assignment that gives sym a value v with test[v] True, \
returning the change and the call stack.";

NewSymbolsDuring::usage =
"NewSymbolsDuring[expr] lists the symbols created at run time (ToExpression, Symbol, Get, ...) while expr is evaluated.";

FileWritesDuring::usage =
"FileWritesDuring[expr] lists the files opened for writing while expr is evaluated.";

CapturePrints::usage =
"CapturePrints[expr] evaluates expr with Print (and Echo) output suppressed and returns the first 20 printed texts.
CapturePrints[expr, max] returns the first max texts.";

FailedAssertions::usage =
"FailedAssertions[expr] lists the Assert calls that failed while expr was evaluated (also when Assert is Off).";

LeakCheck::usage =
"LeakCheck[expr] reports the symbols and Module temporaries that evaluating expr left behind and its MemoryInUse \
change.
LeakCheck[expr, max] lists at most max of the largest temporaries and other new symbols.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Unevaluated Calls*)
WhyNoMatch::usage =
"WhyNoMatch[f[args]] explains which definition applies to f[args] and why the others do not, without Trace and \
without evaluating any rule body.";

StuckCalls::usage =
"StuckCalls[result] summarizes the calls left unevaluated in result: count per head, an example, and whether the head \
has no definitions or has rules that did not match.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Definitions and Source*)
ShowDefinition::usage =
"ShowDefinition[sym] or ShowDefinition[\"name\"] gives the definitions of a symbol as text (ReadProtected is bypassed), \
truncated to 3000 characters.
ShowDefinition[sym, n] truncates to n characters.";

SymbolKind::usage =
"SymbolKind[sym] or SymbolKind[\"name\"] tells whether a symbol is kernel code, an unloaded autoload stub, or has \
Wolfram Language definitions (with counts), without loading it.";

FindSymbolSource::usage =
"FindSymbolSource[\"name\"] or FindSymbolSource[sym] locates the paclet, the source files and the line ranges of the \
definitions of a symbol.";

PacletRoot::usage =
"PacletRoot[file] gives the nearest enclosing directory of file that contains a PacletInfo.wl or PacletInfo.m file.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Package Loading*)
LoadTrace::usage =
"LoadTrace[expr] evaluates expr and reports the autoloads and file loads it caused, with nesting depth and trigger.";

ContextSourceInfo::usage =
"ContextSourceInfo[\"Ctx`\"] reports where the code of a context comes from and whether the loaded code is current.";

AutoloadStubQ::usage =
"AutoloadStubQ[sym] or AutoloadStubQ[\"name\"] gives True if sym is still an unloaded autoload stub (without loading it).";

EnsureLoaded::usage =
"EnsureLoaded[sym] or EnsureLoaded[\"name\"] loads the package behind an autoload stub and gives True when no stub \
remains.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tests*)
TestFailureSummary::usage =
"TestFailureSummary[report] gives one compact record per failed test of a TestReportObject, a TestObject or a list \
of them.";

TestSource::usage =
"TestSource[file, idPattern] gives the TestID, line range and source code of the VerificationTests in file whose \
TestID matches idPattern, without evaluating anything.";

RunTestsByID::usage =
"RunTestsByID[file, idPattern] runs only the VerificationTests of file whose TestID matches idPattern and summarizes \
the results.";

ReproduceTest::usage =
"ReproduceTest[test] re-evaluates the input of a test (TestObject, TestSource record or HoldComplete[input]) like the \
test harness and returns the result, the messages and the stack at the first message.";

CheckTestFile::usage =
"CheckTestFile[file] statically finds problems that make TestReport skip or drop tests (syntax errors, malformed \
VerificationTests, missing or duplicate TestIDs, top-level Abort/Throw/Exit).";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Parallel and Asynchronous*)
ParallelCapture::usage =
"ParallelCapture[f, list] maps f over list in parallel under $CaptureFunction and summarizes the problems: messages, \
aborts, throws, items that ran in the master kernel, and functions not defined on the subkernels.";

KernelReport::usage =
"KernelReport[] summarizes the parallel kernels, their process IDs, WolframKernel child processes and tasks.";

TaskReport::usage =
"TaskReport[] summarizes Tasks[] as small associations.";

SubmitAndWait::usage =
"SubmitAndWait[expr] evaluates expr as a SessionSubmit task under $CaptureFunction, waits at most 10 seconds and \
removes the task.
SubmitAndWait[expr, timeout] waits at most timeout seconds.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cloud and HTTP*)
HTTPSummary::usage =
"HTTPSummary[response] gives the status code, content type and a short text of an HTTPResponse, a URLRead \
association or a Failure (HTML reduced to its visible text).";

DebugHTTPResponse::usage =
"DebugHTTPResponse[deployable, request] runs GenerateHTTPResponse locally and returns the response summary, the \
messages and the stack at the first message.";

WithHTTPLog::usage =
"WithHTTPLog[expr] evaluates expr and lists the HTTP requests made through URLFetch and URLSave (URLRead, URLExecute, \
CloudGet, Import, ...): method, URL, status and seconds.";

HTTPDiagnostics::usage =
"HTTPDiagnostics[expr] (the body of a deployed APIFunction, Delayed or FormFunction) returns the value of expr, or a \
JSON diagnostics HTTPResponse when expr fails or the request has the parameter debug=1.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Headless and Environments*)
EnvironmentFingerprint::usage =
"EnvironmentFingerprint[] gives a compact association describing the kernel environment.
EnvironmentFingerprint[keys] gives only the given keys; EnvironmentFingerprint[All] gives every key.";

FingerprintDiff::usage =
"FingerprintDiff[fpA, fpB] gives the (nested) keys whose values differ between two environment fingerprints.";

FrontEndCalls::usage =
"FrontEndCalls[expr] evaluates expr and counts the front end requests it makes.
FrontEndCalls[expr, timeout] stops expr after timeout seconds.";

RunIsolated::usage =
"RunIsolated[\"code\"] or RunIsolated[File[path]] runs code in a fresh wolframscript kernel with a hard time limit and \
returns its exit code, status and output.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Static Checks*)
LintSummary::usage =
"LintSummary[\"code\"] or LintSummary[File[path]] gives one line per CodeInspector issue with confidence 0.5 or more.
LintSummary[code, minConfidence] uses the given minimum confidence.";

Begin[ "`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Shared Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Constants*)
$maxResultBytes = 10000;

(* contexts treated as "system" when looking for user code *)
$systemContexts = "System`" | "Internal`" | "Developer`" | "Language`" | "Experimental`" | "Compile`";

(* frames of these contexts belong to this package and are dropped from caller lists *)
$packageContextPattern = "WolframDebugging`" ~~ ___;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Argument Checking*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Expected Call Forms*)
$callForms = <|
    "ShortString"            -> "ShortString[expr] or ShortString[expr, n] with a positive integer n",
    "EnvironmentInfo"        -> "EnvironmentInfo[]",
    "CollectMessages"        -> "CollectMessages[expr, opts]",
    "StackAtMessage"         -> "StackAtMessage[expr, opts] or StackAtMessage[expr, msg, opts]",
    "StackAtCall"            -> "StackAtCall[expr, callPattern, opts], where callPattern is f[...], _f or f[...] /; cond with a symbol f that is not Locked",
    "FormatStack"            -> "FormatStack[stack, opts], where stack is a list of frames or a result of StackAtMessage/StackAtCall with \"RawStack\" -> True",
    "StackSummary"           -> "StackSummary[stack] with a list of stack frames",
    "CaptureEvaluation"      -> "CaptureEvaluation[expr]",
    "SampleStacks"           -> "SampleStacks[expr, opts] or SampleStacks[expr, maxSeconds, opts]",
    "TimeCalls"              -> "TimeCalls[expr, {f, ...}, opts] with symbols that are not Locked and have no OwnValues",
    "TraceAvailableQ"        -> "TraceAvailableQ[]",
    "TraceCalls"             -> "TraceCalls[expr, form, opts] or TraceCalls[expr, form, n, opts]",
    "CountCalls"             -> "CountCalls[expr, form, opts]",
    "FindHang"               -> "FindHang[expr, opts] or FindHang[expr, maxSteps, opts]",
    "LogCalls"               -> "LogCalls[{f, ...}, expr, opts] with symbols that are not Locked and have no OwnValues",
    "CallLogSummary"         -> "CallLogSummary[log, opts] or CallLogSummary[log, n, opts] with a LogCalls result log",
    "WithOverrides"          -> "WithOverrides[{lhs :> rhs, ...}, expr, opts], where each lhs is sym, sym[...] or sym[...][...] and sym is not Locked",
    "SnapshotDefinitions"    -> "SnapshotDefinitions[sym] with a symbol that is not Locked",
    "RestoreDefinitions"     -> "RestoreDefinitions[sym, snapshot] with a snapshot from SnapshotDefinitions[sym]",
    "WatchChanges"           -> "WatchChanges[{sym, ...}, expr, opts]",
    "StopWhen"               -> "StopWhen[sym, test, expr, opts]",
    "NewSymbolsDuring"       -> "NewSymbolsDuring[expr, opts]",
    "FileWritesDuring"       -> "FileWritesDuring[expr, opts]",
    "CapturePrints"          -> "CapturePrints[expr, opts] or CapturePrints[expr, max, opts]",
    "FailedAssertions"       -> "FailedAssertions[expr, opts]",
    "LeakCheck"              -> "LeakCheck[expr, opts] or LeakCheck[expr, max, opts]",
    "WhyNoMatch"             -> "WhyNoMatch[f[args], opts]",
    "StuckCalls"             -> "StuckCalls[result, opts]",
    "ShowDefinition"         -> "ShowDefinition[sym], ShowDefinition[\"name\"] or ShowDefinition[sym, n]",
    "SymbolKind"             -> "SymbolKind[sym] or SymbolKind[\"name\"]",
    "FindSymbolSource"       -> "FindSymbolSource[\"name\", opts] or FindSymbolSource[sym, opts]",
    "PacletRoot"             -> "PacletRoot[\"file\"] or PacletRoot[File[\"file\"]]",
    "LoadTrace"              -> "LoadTrace[expr, opts]",
    "ContextSourceInfo"      -> "ContextSourceInfo[\"Ctx`\"]",
    "AutoloadStubQ"          -> "AutoloadStubQ[sym] or AutoloadStubQ[\"name\"]",
    "EnsureLoaded"           -> "EnsureLoaded[sym] or EnsureLoaded[\"name\"]",
    "TestFailureSummary"     -> "TestFailureSummary[report, opts] with a TestReportObject, a TestObject or a list of them",
    "TestSource"             -> "TestSource[\"file.wlt\", idPattern] with an existing file",
    "RunTestsByID"           -> "RunTestsByID[\"file.wlt\", idPattern, opts] with an existing file",
    "ReproduceTest"          -> "ReproduceTest[test, opts] with a TestObject, a TestSource record or HoldComplete[input]",
    "CheckTestFile"          -> "CheckTestFile[\"file.wlt\"] with an existing file",
    "ParallelCapture"        -> "ParallelCapture[f, list, opts]",
    "KernelReport"           -> "KernelReport[]",
    "TaskReport"             -> "TaskReport[]",
    "SubmitAndWait"          -> "SubmitAndWait[expr] or SubmitAndWait[expr, timeout] with a positive timeout",
    "HTTPSummary"            -> "HTTPSummary[response, opts] with an HTTPResponse, a URLRead association or a Failure",
    "DebugHTTPResponse"      -> "DebugHTTPResponse[deployable, request, opts] with an HTTPRequest, a URL or an association/list of parameters",
    "WithHTTPLog"            -> "WithHTTPLog[expr, opts]",
    "HTTPDiagnostics"        -> "HTTPDiagnostics[expr, opts]",
    "EnvironmentFingerprint" -> "EnvironmentFingerprint[], EnvironmentFingerprint[{key, ...}, opts] or EnvironmentFingerprint[All, opts]",
    "FingerprintDiff"        -> "FingerprintDiff[fpA, fpB] or FingerprintDiff[fpA, fpB, {ignoredKey, ...}] with two associations",
    "FrontEndCalls"          -> "FrontEndCalls[expr] or FrontEndCalls[expr, timeout] with a positive timeout",
    "RunIsolated"            -> "RunIsolated[\"code\", opts] or RunIsolated[File[path], opts] with an existing file",
    "LintSummary"            -> "LintSummary[\"code\"], LintSummary[File[path]] or LintSummary[code, minConfidence] with 0 <= minConfidence <= 1"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Option Specifications*)

(* defineOptions[f, {{name, default, test, description}, ...}] sets Options[f] and the value tests used by validOptionsQ *)
defineOptions[ f_Symbol, specs: { { _String, _, _, _String } ... } ] := (
    Options[ f ] = Replace[ specs, { name_, default_, _, _ } :> ( name -> default ), { 1 } ];
    $optionSpecs[ f ] = Association @ Replace[ specs, { name_, _, test_, desc_ } :> ( name -> { test, desc } ), { 1 } ];
);

$optionSpecs[ _ ] := <| |>;

(* options passed through to another function (e.g. Trace options of TraceCalls), any value accepted *)
$passThroughOptions[ TraceCalls | CountCalls ] := SymbolName /@ Keys @ Options @ Trace;
$passThroughOptions[ _ ] := { };

optionKey[ name_String ] := name;
optionKey[ name_Symbol ] := SymbolName @ Unevaluated @ name;
optionKey[ other_ ] := ToString[ other, InputForm ];

(* {} if the option is fine, otherwise {"Unknown", name} or {"BadValue", name, value, description} *)
optionProblem[ f_Symbol, ( Rule | RuleDelayed )[ name_, value_ ] ] :=
    Module[ { key = optionKey @ name, spec },
        spec = Lookup[ $optionSpecs @ f, key, None ];
        Which[
            spec =!= None, If[ TrueQ @ First[ spec ][ value ], { }, { "BadValue", key, value, Last @ spec } ],
            MemberQ[ $passThroughOptions @ f, key ], { },
            True, { "Unknown", key }
        ]
    ];
optionProblem[ _, other_ ] := { "NotAnOption", other };

optionProblems[ f_Symbol, opts_List ] := DeleteCases[ optionProblem[ f, # ] & /@ Flatten @ opts, { } ];

validOptionsQ[ f_Symbol, opts_List ] := optionProblems[ f, opts ] === { };

(* Options[f] merged with the given options; option names given as symbols are turned into strings *)
optionsAssociation[ f_Symbol, opts_List ] := Association[
    Options @ f,
    Replace[ Flatten @ opts, ( r: Rule | RuleDelayed )[ k_, v_ ] :> r[ optionKey @ k, v ], { 1 } ]
];

(* option values for the trace pass-through, with string names turned into the Trace option symbols *)
traceOptions[ opts_List ] := Cases[
    Flatten @ opts,
    ( r: Rule | RuleDelayed )[ name_, value_ ] /; MemberQ[ SymbolName /@ Keys @ Options @ Trace, optionKey @ name ] :>
        r[ Symbol[ "System`" <> optionKey @ name ], value ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Option Value Tests*)
nonNegativeIntegerQ[ x_ ] := IntegerQ @ x && x >= 0;
positiveIntegerQ[ x_ ] := IntegerQ @ x && x > 0;
positiveNumberQ[ x_ ] := NumericQ @ x && Element[ x, Reals ] && x > 0;
byteLimitQ[ x_ ] := x === Infinity || nonNegativeIntegerQ @ x;
countLimitQ[ x_ ] := x === Infinity || positiveIntegerQ @ x;
booleanQ[ x_ ] := BooleanQ @ x;
stringListQ[ x_ ] := MatchQ[ x, { ___String } ];
anyValueQ[ _ ] := True;

$resultOptionSpec = { "MaxResultBytes", $maxResultBytes, byteLimitQ, "a non-negative integer or Infinity" };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Failures*)
(* badCall[f, HoldComplete[args]] is the catch-all of every public function: a Failure that names the function, the
   problem and the expected call form. The arguments are never evaluated, except trailing options. *)
badCall // Attributes = { HoldAllComplete };

badCall[ f_Symbol, HoldComplete[ args___ ] ] :=
    Module[ { name, call, held, opts, problems, template, params },
        name     = SymbolName @ Unevaluated @ f;
        call     = heldString[ HoldComplete @ f @ args, 200 ];
        held     = List @@ ( HoldComplete /@ HoldComplete @ args );
        (* trailing option-like arguments after the first one, evaluated only now *)
        opts     = If[ Length @ held > 1, Reverse @ TakeWhile[ Reverse @ Rest @ held, optionLikeHeldQ ], { } ];
        opts     = Flatten[ ReleaseHold /@ opts ];
        problems = If[ Options @ f === { } && $passThroughOptions @ f === { }, { }, optionProblems[ f, opts ] ];
        { template, params } = Which[
            MemberQ[ problems, { "Unknown", _ } ],
                {
                    "Unknown option(s) `2` for `1`. Valid options: `3`.",
                    {
                        "WolframDebugging`" <> name,
                        StringRiffle[ Cases[ problems, { "Unknown", k_ } :> "\"" <> k <> "\"" ], ", " ],
                        StringRiffle[ Join[ "\"" <> # <> "\"" & /@ Keys @ $optionSpecs @ f, $passThroughOptions @ f ], ", " ]
                    }
                },
            MemberQ[ problems, { "BadValue", __ } ],
                With[ { p = FirstCase[ problems, { "BadValue", __ } ] },
                    {
                        "Invalid value `3` for option \"`2`\" of `1`: expected `4`.",
                        { "WolframDebugging`" <> name, p[[ 2 ]], ShortString[ p[[ 3 ]], 80 ], p[[ 4 ]] }
                    }
                ],
            True,
                { "Invalid call `2`. Expected `3`.", { "WolframDebugging`" <> name, call, Lookup[ $callForms, name, name <> "[...]" ] } }
        ];
        Failure[ "WolframDebugging", <|
            "MessageTemplate"   -> template,
            "MessageParameters" -> params,
            "Function"          -> "WolframDebugging`" <> name,
            "Call"              -> call,
            "Expected"          -> Lookup[ $callForms, name, name <> "[...]" ]
        |> ]
    ];

optionLikeHeldQ[ HoldComplete[ ( Rule | RuleDelayed )[ _String | _Symbol, _ ] ] ] := True;
optionLikeHeldQ[ HoldComplete[ { ( ( Rule | RuleDelayed )[ _String | _Symbol, _ ] ) .. } ] ] := True;
optionLikeHeldQ[ _ ] := False;

(* a Failure for a well-formed call that cannot be carried out (e.g. a Locked symbol) *)
helperFailure[ f_Symbol, template_String, params_List ] := Failure[ "WolframDebugging", <|
    "MessageTemplate"   -> template,
    "MessageParameters" -> params,
    "Function"          -> "WolframDebugging`" <> SymbolName @ Unevaluated @ f,
    "Expected"          -> Lookup[ $callForms, SymbolName @ Unevaluated @ f, Missing[ ] ]
|> ];

(* thrown from deep inside a helper and turned into its result by catchHelperFailure *)
throwHelperFailure[ f_Symbol, template_String, params_List ] := Throw[ helperFailure[ f, template, params ], $helperFailureTag ];

catchHelperFailure // Attributes = { HoldFirst };
catchHelperFailure[ expr_ ] := Catch[ expr, $helperFailureTag ];

traceUnavailableFailure[ f_Symbol ] := Failure[ "TraceUnavailable", <|
    "MessageTemplate"   -> "`1`: Trace records nothing in this kernel (MCP Session method, wolfram -script, Wolfram Cloud). Use SampleStacks, StackAtCall, LogCalls or WhyNoMatch, or run the code in wolframscript.",
    "MessageParameters" -> { "WolframDebugging`" <> SymbolName @ Unevaluated @ f }
|> ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Contained Evaluation*)

(* evaluateContained[expr] evaluates expr and gives HoldComplete[value]. An uncaught Throw (tagged or not) becomes
   HoldComplete[Failure["UncaughtThrow", ...]] and an Abort[] HoldComplete[$Aborted], so neither escapes the helper. *)
evaluateContained // Attributes = { HoldAllComplete };

evaluateContained[ expr_ ] :=
    CheckAbort[
        Replace[
            Catch[ normalResult @ Catch[ HoldComplete @@ { expr }, _, taggedThrowResult ] ],
            { normalResult[ h_HoldComplete ] :> h, v_ :> HoldComplete @@ { uncaughtThrowFailure[ v, None ] } }
        ],
        HoldComplete[ $Aborted ]
    ];

taggedThrowResult[ v_, tag_ ] := HoldComplete @@ { uncaughtThrowFailure[ v, If[ untaggedMarkerQ @ tag, None, tag ] ] };

(* the MCP evaluator (Chatbook sandbox) turns an untagged Throw[v] into Throw[v, ...`$untagged] *)
untaggedMarkerQ[ tag_Symbol ] := SymbolName @ Unevaluated @ tag === "$untagged" && StringContainsQ[ Context @ Unevaluated @ tag, "Chatbook" ];
untaggedMarkerQ[ _ ] := False;

uncaughtThrowFailure[ v_, None ] := Failure[ "UncaughtThrow", <|
    "MessageTemplate"   -> "The evaluation ended with an uncaught Throw[`1`].",
    "MessageParameters" -> { ShortString[ v, 120 ] }
|> ];

uncaughtThrowFailure[ v_, tag_ ] := Failure[ "UncaughtThrow", <|
    "MessageTemplate"   -> "The evaluation ended with an uncaught Throw[`1`, `2`].",
    "MessageParameters" -> { ShortString[ v, 120 ], ShortString[ tag, 60 ] }
|> ];

(* boundedResult[HoldComplete[v], max] gives v, or Missing["TooLarge", ...] when v needs more than max bytes *)
boundedResult[ HoldComplete[ v_ ], max_ ] /; max === Infinity || ByteCount @ Unevaluated @ v <= max := v;
boundedResult[ HoldComplete[ v_ ], _ ] := tooLarge @ HoldComplete @ v;
boundedResult[ h: HoldComplete[ ___ ], max_ ] := boundedResult[ HoldComplete @@ { List @@ h }, max ];

(* the same, but the value stays in HoldComplete *)
boundedHeld[ h: HoldComplete[ _ ], max_ ] /; max === Infinity || ByteCount @ h <= max := h;
boundedHeld[ h_HoldComplete, _ ] := tooLarge @ h;

tooLarge[ h_HoldComplete ] := Missing[ "TooLarge", <| "ByteCount" -> ByteCount @ h, "Preview" -> heldString[ h, 150 ] |> ];

(* default time limit: at most def seconds, and comfortably below the time left for this evaluation (MCP tool limit) *)
autoTimeLimit[ def_ ] :=
    With[ { r = Internal`TimeRemaining[ ] },
        If[ NumericQ @ r && r < Infinity, Max[ 0.5, Min[ def, r - Max[ 3, 0.2 * r ] ] ], def ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Rendering*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*heldString*)
(* heldString[HoldComplete[e], n] is the one renderer of the package: a one-line InputForm string of e (never
   evaluated) with at most n characters. ToString with TotalWidth elides big subexpressions as <<k>> and stays fast for
   MB-sized expressions; StringTake handles long atoms (TotalWidth does not shorten strings); TotalWidth below ~40 gives
   "-toobig-", so it is clamped and a Shallow-based fallback is used. Symbols of the user contexts (Global`, $Context)
   and of $extraContexts print without their context. Short[] does nothing useful here: wolframscript and the MCP
   evaluators format with an infinite page width. *)
$extraContexts = { };

userContexts[ ] := DeleteDuplicates @ { "Global`", $Context };

heldString[ held_HoldComplete, n_Integer ] :=
    Module[ { s },
        s = Block[ { $ContextPath = DeleteDuplicates @ Join[ $ContextPath, userContexts[ ], $extraContexts ] },
            Replace[
                held,
                {
                    HoldComplete[ e_ ] :> Quiet @ ToString[ Unevaluated @ e, InputForm, PageWidth -> Infinity, TotalWidth -> Max[ n, 40 ] ],
                    HoldComplete[ e___ ] :> StringReplace[
                        Quiet @ ToString[ Unevaluated @ HoldComplete @ e, InputForm, PageWidth -> Infinity, TotalWidth -> Max[ n, 40 ] + 14 ],
                        { StartOfString ~~ "HoldComplete[" -> "", "]" ~~ EndOfString -> "" }
                    ]
                }
            ]
        ];
        If[ ! StringQ @ s || StringContainsQ[ s, "-toobig-" ], s = shallowString @ held ];
        s = StringReplace[ s, { "\r\n" -> " ", "\n" -> " " } ];
        If[ StringLength @ s > n, StringTake[ s, Max[ n - 3, 1 ] ] <> "...", s ]
    ];

(* fallback: structural elision by depth and length *)
shallowString[ HoldComplete[ e_ ] ] := StringReplace[
    Block[ { $ContextPath = DeleteDuplicates @ Join[ $ContextPath, userContexts[ ], $extraContexts ] },
        ToString @ Shallow[ InputForm @ HoldForm @ e, { 6, 6 } ]
    ],
    StartOfString ~~ "HoldForm[" ~~ x___ ~~ "]" ~~ EndOfString :> x
];
shallowString[ h_HoldComplete ] := ToString @ Shallow[ InputForm @ h, { 6, 6 } ];

truncateString[ s_String, n_Integer ] := If[ StringLength @ s > n, StringTake[ s, Max[ n - 3, 1 ] ] <> "...", s ];

(* symbol name without the context when the context is on $ContextPath or is a user context *)
symbolString // Attributes = { HoldAllComplete };
symbolString[ s_Symbol ] :=
    With[ { ctx = Quiet @ Context @ Unevaluated @ s, name = Quiet @ SymbolName @ Unevaluated @ s },
        Which[
            ! StringQ @ ctx || ! StringQ @ name, ToString @ Unevaluated @ s,  (* e.g. Removed["$$Failure"] *)
            MemberQ[ Join[ $ContextPath, userContexts[ ] ], ctx ], name,
            True, ctx <> name
        ]
    ];
symbolString[ other_ ] := heldString[ HoldComplete @ other, 60 ];

fullSymbolName // Attributes = { HoldAllComplete };
fullSymbolName[ s_Symbol ] := Context @ Unevaluated @ s <> SymbolName @ Unevaluated @ s;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*messageText*)
(* one-line text of a message with shortened arguments; never lets the MessageName evaluate out of place *)
messageText[ Hold[ Message[ mn: MessageName[ sym_Symbol, tag_String, ___ ], args___ ] ], n_Integer ] :=
    Module[ { template, label, shortArgs },
        template = SelectFirst[ Replace[ { mn, MessageName[ General, tag ] }, $Off[ t_String ] :> t, { 1 } ], StringQ, None ];
        label = SymbolName @ Unevaluated @ sym <> "::" <> tag;
        shortArgs = List @@ Map[
            Function[ a, heldString[ HoldComplete @ a, 60 ], HoldAllComplete ],
            Replace[ HoldComplete @ args, ( HoldForm | HoldCompleteForm )[ a_ ] :> a, { 1 } ]
        ];
        truncateString[
            StringReplace[
                If[ StringQ @ template,
                    label <> ": " <> Quiet @ ToString[ StringForm[ template, Sequence @@ shortArgs ], PageWidth -> Infinity ],
                    label <> ": -- Message text not found -- " <> StringRiffle[ ( "(" <> # <> ")" ) & /@ shortArgs, " " ]
                ],
                { "\r\n" -> " ", "\n" -> " " }
            ],
            n
        ]
    ];
messageText[ Hold[ other_ ], n_Integer ] := heldString[ HoldComplete @ other, n ];
messageText[ other_, n_Integer ] := heldString[ HoldComplete @ other, n ];

(* "Power::infy" for Hold[Message[Power::infy, ...], ...] *)
messageNameString[ Hold[ Message[ MessageName[ s_Symbol, t_String, ___ ], ___ ], ___ ] ] := SymbolName @ Unevaluated @ s <> "::" <> t;
messageNameString[ _ ] := "?";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Message Selectors*)
(* messageSelector turns a message specification into All, a string pattern or HoldPattern[pattern]:
   Power::infy (held), "Power::infy", "Power::*", "*::infy", _ (any message), a pattern for the MessageName *)
messageSelector // Attributes = { HoldAllComplete };
messageSelector[ Verbatim[ _ ] | All | Verbatim[ _MessageName ] ] := All;
messageSelector[ MessageName[ s_Symbol, t_String ] ] := SymbolName @ Unevaluated @ s <> "::" <> t;
messageSelector[ s_String ] := s;
messageSelector[ Verbatim[ HoldPattern ][ p_ ] ] := HoldPattern @ p;
messageSelector[ p_ ] := HoldPattern @ p;

(* a string that is not a message name (e.g. the text that General::stop evaluates to) cannot select messages *)
messageSelectorQ // Attributes = { HoldAllComplete };
messageSelectorQ[ s_String ] := StringContainsQ[ s, "::" ];
messageSelectorQ[ _ ] := True;

stopAtQ[ None ] := True;
stopAtQ[ { s_, k_ } ] := positiveIntegerQ @ k && messageSelectorQ @ s;
stopAtQ[ s_ ] := messageSelectorQ @ s;

selectorMatchQ[ All, _ ] := True;
selectorMatchQ[ s_String, h: Hold[ Message[ MessageName[ sym_Symbol, _String, ___ ], ___ ], ___ ] ] :=
    StringMatchQ[ messageNameString @ h, s ] || StringMatchQ[ Context @ Unevaluated @ sym <> messageNameString @ h, s ];
selectorMatchQ[ Verbatim[ HoldPattern ][ p_ ], Hold[ Message[ mn_, ___ ], ___ ] ] := MatchQ[ Unevaluated @ mn, HoldPattern @ p ];
selectorMatchQ[ _, _ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Stack Frames*)
(* A frame is HoldCompleteForm[e] in 15.0 (HoldForm[e] in older versions); _[e] covers both. Frames are never
   evaluated: no First, no ReleaseHold. Stack[] (heads only) gives bare symbols, which are accepted too. *)
(* frameHead gives HoldComplete[head] (heads are never evaluated: a symbol could have an OwnValue or be a stub, and
   the head of f[a][b][c] is the call f[a][b]); for compound heads it is the innermost head symbol (f) *)
frameHead[ ( HoldCompleteForm | HoldForm )[ e: _[ ___ ] ] ] := heldHead @ HoldComplete @ e;
frameHead[ ( HoldCompleteForm | HoldForm )[ s_Symbol ] ] := HoldComplete @ s;
frameHead[ s_Symbol ] := HoldComplete @ s;
frameHead[ _ ] := None;

heldHead[ HoldComplete[ ( h_Symbol )[ ___ ] ] ] := HoldComplete @ h;
heldHead[ HoldComplete[ ( h: _[ ___ ] )[ ___ ] ] ] := heldHead @ HoldComplete @ h;
heldHead[ HoldComplete[ ( h_ )[ ___ ] ] ] := HoldComplete @@ { Head @ Unevaluated @ h };  (* an atom such as "s" in "s"[1] *)

frameContext[ fr_ ] := Replace[ frameHead @ fr, { HoldComplete[ h_Symbol ] :> Context @ Unevaluated @ h, _ -> None } ];

frameHeadString[ fr_ ] := Replace[ frameHead @ fr, { HoldComplete[ h_ ] :> symbolString @ h, _ -> "None" } ];

userFrameQ[ fr_ ] := MemberQ[ userContexts[ ], frameContext @ fr ];

messageFrameQ[ fr_ ] := MatchQ[ fr, ( HoldCompleteForm | HoldForm )[ _Message ] ];

wrapperFrameQ[ fr_ ] := MatchQ[ fr, ( HoldCompleteForm | HoldForm )[ _StackComplete | _StackBegin ] | StackComplete | StackBegin ];

(* "plumbing" heads dropped by the "Calls" filter of FormatStack, as HoldComplete[head]: the symbols are never evaluated
   (EvaluationData, for example, is an autoload stub, and evaluating it at load time would load its package) *)
$plumbing = List @@ ( HoldComplete /@ HoldComplete[
    CompoundExpression, Set, SetDelayed, Block, Module, With, If, Which, Switch, Catch, Throw, CheckAbort,
    Check, Quiet, Replace, ReplaceAll, Condition, Function, AbortProtect, WithCleanup, TimeConstrained,
    MemoryConstrained, Internal`HandlerBlock, Internal`InheritedBlock, Reap, Sow, Hold, HoldComplete, List,
    Association, Rule, RuleDelayed, StackBegin, StackComplete, StackInhibit, Message, MessageName, Do, Table,
    Map, Scan, Apply, While, For, Nest, NestWhile, Fold, FoldList, AbsoluteTiming, Timing, EvaluationData,
    Part, Lookup, Increment, PreIncrement, AddTo, AppendTo, Equal, SameQ, UnsameQ, Not, And, Or, Plus, Times, Power
] );

callFrameQ[ fr_ ] := With[ { h = frameHead @ fr }, h =!= None && ! MemberQ[ $plumbing, h ] ];

(* frames up to the message being issued: drops the handler's own frames (after the last Message frame) and the
   StackBegin/StackComplete wrapper frames *)
framesToMessage[ frames_List, includeMessage_ ] :=
    Module[ { pos, fr = frames },
        pos = Position[ fr, _?messageFrameQ, { 1 }, Heads -> False ];
        If[ pos =!= { }, fr = Take[ fr, If[ TrueQ @ includeMessage, pos[[ -1, 1 ]], pos[[ -1, 1 ]] - 1 ] ] ];
        DeleteCases[ fr, _?wrapperFrameQ ]
    ];

(* frames from the first user-code frame on (or all frames if there is none) *)
fromFirstUserFrame[ frames_List ] :=
    With[ { i = FirstPosition[ frames, _?userFrameQ, { 1 }, { 1 }, Heads -> False ][[ 1 ]] },
        Drop[ frames, i - 1 ]
    ];

(* render frames as strings: the last k frames, each at most n characters *)
frameStrings[ frames_List, k_, n_Integer ] :=
    Replace[ Take[ frames, -Min[ k, Length @ frames ] ], fr_ :> frameString[ fr, n, False ], { 1 } ];

(* one frame as a one-line string, never evaluated; shortCtx: print every symbol without its context *)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::ShadowedVariable::Block:: *)
frameString[ fr: ( HoldCompleteForm | HoldForm )[ e_ ], n_Integer, shortCtx_ ] :=
    Block[
        {
            $extraContexts = If[ TrueQ @ shortCtx,
                DeleteDuplicates @ Cases[ fr, s_Symbol :> Context @ Unevaluated @ s, Infinity, Heads -> True ],
                $extraContexts
            ]
        },
        heldString[ HoldComplete @ e, n ]
    ];
(* :!CodeAnalysis::EndBlock:: *)
frameString[ s_Symbol, n_Integer, _ ] := heldString[ HoldComplete @ s, n ];
frameString[ other_, n_Integer, _ ] := heldString[ HoldComplete @ other, n ];

(* {item, count} pairs, most frequent first; ties in order of first appearance *)
tallyByCount[ list_List ] := With[ { t = Tally @ list }, t[[ Ordering[ -t[[ All, 2 ]] ] ]] ];

(* names of the user-level functions on the current stack (no System`, Internal` or package frames) *)
callerNames[ ] := DeleteDuplicates @ Cases[
    Stack[ _ ],
    ( HoldCompleteForm | HoldForm )[ ( h_Symbol )[ ___ ] ] /;
        ! MatchQ[ Context @ h, $systemContexts ] && ! StringMatchQ[ Context @ h, $packageContextPattern ] :>
            symbolString @ h,
    { 1 }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Message Collector*)
(* collectMessagesCore[HoldComplete[expr], settings] is the one message collector of the package (CollectMessages,
   StackAtMessage, ReproduceTest, DebugHTTPResponse and HTTPDiagnostics use it). It evaluates expr under a "Message"
   handler and a "MessageTextFilter" handler; the latter runs only for messages that really print (it knows about
   Quiet, Off and General::stop, and runs even when $Messages is {}), which gives the "Printed" flag. *)
$collectorDefaults = <|
    "IncludeQuieted"   -> False,   (* also record messages with willPrint False (Quiet, Off) *)
    "StackFrames"      -> 6,       (* trailing frames per record, as strings; 0: none *)
    "MaxMessages"      -> 25,      (* records kept (counting continues) *)
    "StringLength"     -> 150,
    "Select"           -> All,     (* message selector: only matching messages are counted and recorded *)
    "StopAt"           -> None,    (* None | {selector, k}: stop the evaluation at the k-th matching message *)
    "IgnoreOuterQuiet" -> True,    (* Quiet[expr, None, All]: cancels a Quiet around the call (remote MCP server) *)
    "ResetMessageList" -> True,    (* Block[{$MessageList = {}}, ...]: fresh General::stop accounting (never reset in MCP Session) *)
    "SuppressPrinting" -> False,   (* Block[{$Messages = {}}, ...] *)
    "Complete"         -> True,    (* StackComplete: show user function calls in the stack *)
    "RawStack"         -> False,   (* keep the frames of each record (up to the Message frame) as "RawStack" *)
    "StackStart"       -> None,    (* None | "UserCode": drop the frames before the first user-code frame *)
    "TimeConstraint"   -> None     (* None | seconds: the result is $TimedOut when exceeded *)
|>;

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::ShadowedVariable::Block:: *)
collectMessagesCore[ HoldComplete[ expr_ ], settings0_Association ] :=
    Module[ { s, bag, count, stopCount, lastPrinted, busy, tag, stopped, filter, handler, record, result },
        s = Join[ $collectorDefaults, settings0 ];
        bag = Internal`Bag[ ];
        count = 0;
        stopCount = 0;
        lastPrinted = None;
        busy = False;
        stopped = False;
        filter = Function[ lastPrinted = #2; Null ];  (* arguments: text, Hold[name], message *)
        record = Function[ { h, flag },
            Module[ { printed, frames },
                printed = flag && lastPrinted === Replace[ h, Hold[ Message[ mn_, ___ ], ___ ] :> Hold @ mn ];
                lastPrinted = None;
                If[ ( TrueQ @ s[ "IncludeQuieted" ] || flag ) && selectorMatchQ[ s[ "Select" ], h ],
                    count++;
                    If[ count <= s[ "MaxMessages" ],
                        frames = If[ s[ "StackFrames" ] > 0 || TrueQ @ s[ "RawStack" ], Stack[ _ ], { } ];
                        Internal`StuffBag[ bag, collectorRecord[ h, flag, printed, frames, s ] ]
                    ]
                ];
                If[ ( TrueQ @ s[ "IncludeQuieted" ] || flag ) &&
                    MatchQ[ s[ "StopAt" ], { sel_, k_ } /; selectorMatchQ[ sel, h ] && ++stopCount >= k ],
                    Throw[ Null, tag ]
                ]
            ]
        ];
        handler = Function[ h,
            If[ ! busy,
                Block[ { busy = True },
                    Replace[ h, {
                        Hold[ Message[ General::newsym, ___ ], _ ] :> Null,
                        Hold[ Message[ _MessageName, ___ ], flag_ ] :> record[ h, TrueQ @ flag ]
                    } ]
                ]
            ]
        ];
        result = evaluateContained @ Catch[
            Internal`HandlerBlock[ { "MessageTextFilter", filter },
                Internal`HandlerBlock[ { "Message", handler },
                    collectorEvaluate[ expr, s ]
                ]
            ],
            tag,
            ( stopped = True; Missing[ "Stopped" ] ) &
        ];
        <| "Result" -> result, "MessageCount" -> count, "Messages" -> Internal`BagPart[ bag, All ], "Stopped" -> stopped |>
    ];
(* :!CodeAnalysis::EndBlock:: *)

collectorRecord[ Hold[ msg: Message[ mn_, ___ ], ___ ], flag_, printed_, frames_List, s_Association ] :=
    Module[ { upTo, shown },
        upTo  = framesToMessage[ frames, True ];
        shown = If[ upTo =!= { } && messageFrameQ @ Last @ upTo, Most @ upTo, upTo ];
        If[ s[ "StackStart" ] === "UserCode", shown = fromFirstUserFrame @ shown ];
        <|
            "Message" -> HoldForm @ mn,
            "Text"    -> messageText[ Hold @ msg, s[ "StringLength" ] ],
            "Printed" -> printed,
            "Quieted" -> ! flag,
            "Stack"   -> If[ s[ "StackFrames" ] > 0, frameStrings[ shown, s[ "StackFrames" ], s[ "StringLength" ] ], { } ],
            If[ TrueQ @ s[ "RawStack" ], "RawStack" -> upTo, Nothing ]
        |>
    ];

(* the evaluation wrappers, outermost first: Block $MessageList/$Messages, Quiet[..., None, All], TimeConstrained,
   StackBegin, StackComplete *)
collectorEvaluate // Attributes = { HoldFirst };
collectorEvaluate[ expr_, s_Association ] :=
    Block[
        {
            $MessageList = If[ TrueQ @ s[ "ResetMessageList" ], { }, $MessageList ],
            $Messages    = If[ TrueQ @ s[ "SuppressPrinting" ], { }, $Messages ]
        },
        If[ TrueQ @ s[ "IgnoreOuterQuiet" ],
            Quiet[ collectorTimed[ expr, s ], None, All ],
            collectorTimed[ expr, s ]
        ]
    ];

collectorTimed // Attributes = { HoldFirst };
collectorTimed[ expr_, s_Association ] :=
    If[ positiveNumberQ @ s[ "TimeConstraint" ],
        TimeConstrained[ collectorStack[ expr, s ], s[ "TimeConstraint" ], $TimedOut ],
        collectorStack[ expr, s ]
    ];

collectorStack // Attributes = { HoldFirst };
collectorStack[ expr_, s_Association ] := If[ TrueQ @ s[ "Complete" ], StackBegin @ StackComplete @ expr, StackBegin @ expr ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Symbols*)
autoloadStubQ // Attributes = { HoldAllComplete };
autoloadStubQ[ s_Symbol ] := ! FreeQ[ Quiet @ OwnValues @ s, Package`ActivateLoad | System`Dump`AutoLoad ];
autoloadStubQ[ ___ ] := False;

(* evaluate bare autoload stubs so that their packages load (before an InheritedBlock, which would discard them) *)
ensureLoaded // Attributes = { HoldAllComplete };
ensureLoaded[ { syms___Symbol } ] := ( Scan[ Function[ s, If[ autoloadStubQ @ s, Quiet @ s ], HoldAllComplete ], Hold @ syms ]; Null );
ensureLoaded[ s_Symbol ] := ensureLoaded @ { s };

lockedQ // Attributes = { HoldAllComplete };
lockedQ[ s_Symbol ] := MemberQ[ Attributes @ Unevaluated @ s, Locked ];

(* nameToHeld["name"] gives HoldComplete[sym] for an existing symbol (never creates one), or a Missing *)
nameToHeld[ name_String ] :=
    If[ ! StringQ @ name || Quiet @ Names @ name === { } || StringContainsQ[ name, "*" | "@" ],
        Missing[ "UnknownSymbol", name ],
        Replace[
            Quiet @ ToExpression[ name, InputForm, HoldComplete ],
            { h: HoldComplete[ _Symbol ] :> h, _ :> Missing[ "InvalidSymbol", name ] }
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Core*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ShortString*)
ShortString[ expr_ ] := ShortString[ expr, 150 ];
ShortString[ expr_, n_Integer? Positive ] := heldString[ stripHold @ HoldComplete @ expr, n ];
ShortString[ args___ ] := badCall[ ShortString, HoldComplete @ args ];

stripHold[ HoldComplete[ ( HoldComplete | HoldCompleteForm | HoldForm )[ e_ ] ] ] := HoldComplete @ e;
stripHold[ h_HoldComplete ] := h;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*EnvironmentInfo*)
EnvironmentInfo[ ] :=
    Module[ { kind, trace, pm, quiet, notes = { } },
        kind  = environmentKind[ ];
        trace = Trace[ 1 + 1 ] =!= { };
        pm    = TrueQ @ Developer`$ProtectedMode;
        quiet = Lookup[ Internal`QuietStatus[ ], "Global", Missing[ ] ] === "Quiet";  (* never wrap this in Quiet *)
        If[ ! trace,
            AppendTo[ notes, "Trace/TraceScan/TracePrint/On[sym] record nothing here: use StackAtMessage, StackAtCall, SampleStacks, LogCalls or WhyNoMatch (or run Trace in wolframscript)" ]
        ];
        If[ StringStartsQ[ kind, "MCP evaluator, Method Local" ],
            AppendTo[ notes, "One subkernel is shared by every session of this server: a crash, Quit[] or a hard time-out silently restarts it (all definitions of every session lost)" ]
        ];
        If[ StringStartsQ[ kind, "MCP evaluator, Method Session" ],
            AppendTo[ notes, "Code runs inside the MCP server: never write to \"stdout\", Run[...], Input*/Dialog or set global limits; $MessageList never resets (use Block[{$MessageList = {}}, ...]); messages after 10 outputs per call are dropped" ]
        ];
        If[ quiet,
            AppendTo[ notes, "The whole input runs under Quiet: message handlers see willPrint False; wrap probes in Quiet[expr, None, All]" ]
        ];
        If[ MatchQ[ $EvaluationEnvironment, "WebEvaluation" | "WebAPI" | "Scheduled" ],
            AppendTo[ notes, "Cloud kernel: Print/Echo output is dropped or invisible ($Notebooks is True): return data instead" ]
        ];
        If[ pm,
            AppendTo[ notes, "Protected mode: no RunProcess/Run/LaunchKernels/LocalSubmit; file writes only below $TemporaryDirectory (often a silent $Failed)" ]
        ];
        <|
            "Environment"     -> kind,
            "Version"         -> $VersionNumber,
            "TraceWorks"      -> trace,
            "ProtectedMode"   -> pm,
            "Context"         -> $Context,
            "UserContexts"    -> userContexts[ ],
            "QuietedGlobally" -> quiet,
            "ProcessID"       -> $ProcessID,
            "TimeRemaining"   -> Replace[ Internal`TimeRemaining[ ], r_? NumericQ :> Round[ r, 0.1 ] ],
            "Notes"           -> notes
        |>
    ];

EnvironmentInfo[ args__ ] := badCall[ EnvironmentInfo, HoldComplete @ args ];

(* one detector for the whole package (EnvironmentInfo, EnvironmentFingerprint). $Context alone is not enough to
   detect the Session method: it changes inside Begin[...] and package code. *)
environmentKind[ ] :=
    Module[ { cl = StringRiffle[ ToString /@ $CommandLine, " " ] },
        Which[
            $EvaluationEnvironment === "Script"       , "wolframscript",
            $EvaluationEnvironment === "WebEvaluation", "CloudEvaluate",
            $EvaluationEnvironment === "WebAPI"       , "Cloud API (deployed APIFunction/Delayed or the remote MCP server)",
            $EvaluationEnvironment === "Scheduled"    , "Cloud scheduled task",
            StringContainsQ[ cl, "ChatbookSandbox" ]  , "MCP evaluator, Method Local (protected sandbox subkernel)",
            StringContainsQ[ cl, "StartMCPServer" ] || StringStartsQ[ $Context, "Sessions`" ] ||
                StringQ @ Quiet @ If[ NameQ[ "Wolfram`AgentTools`$MCPTransport" ], Symbol[ "Wolfram`AgentTools`$MCPTransport" ] ],
                "MCP evaluator, Method Session (code runs in the MCP server kernel)",
            MemberQ[ $CommandLine, "-script" ]        , "wolfram -script",
            TrueQ @ $Notebooks && Head @ $FrontEnd === FrontEndObject, "Notebook front end",
            True                                      , "Other: " <> ToString @ $EvaluationEnvironment
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages and Stacks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*CollectMessages*)
CollectMessages // Attributes = { HoldFirst };

defineOptions[ CollectMessages, {
    { "IncludeQuieted"  , False, booleanQ           , "True or False" },
    { "StackFrames"     , 6    , nonNegativeIntegerQ, "a non-negative integer" },
    { "MaxMessages"     , 25   , nonNegativeIntegerQ, "a non-negative integer" },
    { "StringLength"    , 150  , positiveIntegerQ   , "a positive integer" },
    { "StopAt"          , None , stopAtQ            , "None, a message name such as \"Power::infy\" (wildcards * allowed), a pattern, or {spec, k}" },
    { "IgnoreOuterQuiet", True , booleanQ           , "True or False" },
    { "ResetMessageList", True , booleanQ           , "True or False" },
    { "SuppressPrinting", False, booleanQ           , "True or False" },
    $resultOptionSpec
} ];

CollectMessages[ expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ CollectMessages, { opts } ] :=
    Module[ { r },
        r = collectMessagesCore[
            HoldComplete @ expr,
            <|
                "IncludeQuieted"   -> OptionValue[ "IncludeQuieted" ],
                "StackFrames"      -> OptionValue[ "StackFrames" ],
                "MaxMessages"      -> OptionValue[ "MaxMessages" ],
                "StringLength"     -> OptionValue[ "StringLength" ],
                "StopAt"           -> stopAtSpec @ OptionValue[ "StopAt" ],
                "IgnoreOuterQuiet" -> OptionValue[ "IgnoreOuterQuiet" ],
                "ResetMessageList" -> OptionValue[ "ResetMessageList" ],
                "SuppressPrinting" -> OptionValue[ "SuppressPrinting" ]
            |>
        ];
        <|
            "Result"       -> boundedResult[ r[ "Result" ], OptionValue[ "MaxResultBytes" ] ],
            "MessageCount" -> r[ "MessageCount" ],
            "Messages"     -> r[ "Messages" ]
        |>
    ];

CollectMessages[ args___ ] := badCall[ CollectMessages, HoldComplete @ args ];

stopAtSpec[ None ] := None;
stopAtSpec[ { s_, k_Integer } ] := { messageSelector @@ { s }, k };
stopAtSpec[ s_ ] := { messageSelector @@ { s }, 1 };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FormatStack*)
$formatStackOptionSpecs = {
    { "MaxFrames"     , 25  , positiveIntegerQ, "a positive integer" },
    { "MaxFrameLength", 150 , positiveIntegerQ, "a positive integer" },
    { "Filter"        , All , anyValueQ       , "All, \"Calls\", \"User\", a list of context prefixes, or a pattern for the frame contents" },
    { "Start"         , None, anyValueQ       , "None or a pattern for the frame contents" },
    { "End"           , None, anyValueQ       , "None or a pattern for the frame contents" },
    { "Collapse"      , True, booleanQ        , "True or False" },
    { "ShortContexts" , False, booleanQ       , "True or False" }
};

defineOptions[ FormatStack, $formatStackOptionSpecs ];

FormatStack[ stack_List, opts: OptionsPattern[ ] ] /; validOptionsQ[ FormatStack, { opts } ] := formatStack[ stack, { opts } ];

(* results of StackAtMessage/StackAtCall with "RawStack" -> True *)
FormatStack[ a_Association /; ListQ @ Lookup[ a, "RawStack" ], opts: OptionsPattern[ ] ] /; validOptionsQ[ FormatStack, { opts } ] :=
    formatStack[ a[ "RawStack" ], { opts } ];

FormatStack[ a_Association /; ListQ @ Lookup[ a, "RawStacks" ], opts: OptionsPattern[ ] ] /; validOptionsQ[ FormatStack, { opts } ] :=
    formatStack[ #, { opts } ] & /@ a[ "RawStacks" ];

(* an already formatted stack (the "Stack" of StackAtMessage) is returned unchanged *)
FormatStack[ s_String ] := s;

FormatStack[ args___ ] := badCall[ FormatStack, HoldComplete @ args ];

formatStack[ stack_List, opts_List ] :=
    Module[ { o, frames, filter, keep, groups, max, len, short, omitted, line, lines },
        o = optionsAssociation[ FormatStack, opts ];
        frames = trimFrames[ stack, o[ "Start" ], o[ "End" ] ];
        filter = o[ "Filter" ];
        keep = Switch[ filter,  (* indices into the trimmed frame list *)
            All               , Range @ Length @ frames,
            "Calls"           , Select[ Range @ Length @ frames, callFrameQ[ frames[[ # ]] ] & ],
            "User"            , Select[ Range @ Length @ frames, userFrameQ[ frames[[ # ]] ] & ],
            { __String }      ,
                Select[
                    Range @ Length @ frames,
                    With[ { c = frameContext @ frames[[ # ]] }, StringQ @ c && StringStartsQ[ c, filter ] ] &
                ],
            _String           ,
                Select[
                    Range @ Length @ frames,
                    With[ { c = frameContext @ frames[[ # ]] }, StringQ @ c && StringStartsQ[ c, filter ] ] &
                ],
            _                 , Select[ Range @ Length @ frames, MatchQ[ frames[[ # ]], ( HoldCompleteForm | HoldForm )[ filter ] ] & ]
        ];
        groups = If[ TrueQ @ o[ "Collapse" ],
            cycleGroups[ frameHead /@ frames[[ keep ]] ],
            Table[ { i, 1, 1 }, { i, Length @ keep } ]
        ];
        max     = o[ "MaxFrames" ];
        omitted = Max[ 0, Length @ groups - max ];
        groups  = Take[ groups, -Min[ max, Length @ groups ] ];
        len     = o[ "MaxFrameLength" ];
        short   = o[ "ShortContexts" ];
        line    = Function[ k, ToString @ keep[[ k ]] <> "| " <> frameString[ frames[[ keep[[ k ]] ]], len, short ] ];
        lines   = Map[
            Function[ g,
                If[ g[[ 3 ]] == 1,
                    line @ g[[ 1 ]],
                    With[ { a = g[[ 1 ]], p = g[[ 2 ]], r = g[[ 3 ]] },
                        StringRiffle[
                            Join[
                                {
                                    StringJoin[
                                        "-- frames ", ToString @ keep[[ a ]], "-", ToString @ keep[[ a + p * r - 1 ]],
                                        ": a ", ToString @ p, "-frame cycle repeated ", ToString @ r,
                                        " times (first and last shown) --"
                                    ]
                                },
                                line /@ Range[ a, a + p - 1 ],
                                { "   ..." },
                                line /@ Range[ a + p * ( r - 1 ), a + p * r - 1 ]
                            ],
                            "\n"
                        ]
                    ]
                ]
            ],
            groups
        ];
        StringJoin[
            "(", ToString @ Length @ stack, " frames",
            If[ Length @ frames =!= Length @ stack, ", " <> ToString @ Length @ frames <> " after Start/End", "" ],
            If[ Length @ keep =!= Length @ frames, ", " <> ToString @ Length @ keep <> " after Filter", "" ],
            If[ omitted > 0, ", " <> ToString @ omitted <> " earlier entries omitted", "" ],
            ")\n",
            StringRiffle[ lines, "\n" ]
        ]
    ];

(* keep the frames from the first frame matching start to the last frame matching end *)
trimFrames[ stack_List, start_, end_ ] :=
    Module[ { s = stack, i },
        If[ start =!= None,
            i = FirstPosition[ s, ( HoldCompleteForm | HoldForm )[ start ], { 0 }, { 1 }, Heads -> False ][[ 1 ]];
            If[ i > 0, s = Drop[ s, i - 1 ] ]
        ];
        If[ end =!= None,
            i = FirstPosition[ Reverse @ s, ( HoldCompleteForm | HoldForm )[ end ], { 0 }, { 1 }, Heads -> False ][[ 1 ]];
            If[ i > 0, s = Drop[ s, -( i - 1 ) ] ]
        ];
        s
    ];

(* runs of a repeating cycle of frame heads (recursion): {{start, period, repetitions}, ...} covering 1 .. n *)
cycleGroups[ keys_List ] := cycleGroups[ keys, 4, 3 ];
cycleGroups[ keys_List, maxPeriod_Integer, minReps_Integer ] :=
    Module[ { i = 1, n = Length @ keys, groups = Internal`Bag[ ], best, reps },
        While[ i <= n,
            best = { 1, 1 };
            Do[
                reps = 1;
                While[
                    i + ( reps + 1 ) * p - 1 <= n && keys[[ i + reps * p ;; i + ( reps + 1 ) * p - 1 ]] === keys[[ i ;; i + p - 1 ]],
                    reps++
                ];
                If[ reps >= minReps && reps * p > Times @@ best, best = { p, reps } ],
                { p, 1, Min[ maxPeriod, n - i + 1 ] }
            ];
            If[ best[[ 2 ]] >= minReps,
                Internal`StuffBag[ groups, { i, best[[ 1 ]], best[[ 2 ]] } ]; i += Times @@ best,
                Internal`StuffBag[ groups, { i, 1, 1 } ]; i++
            ]
        ];
        Internal`BagPart[ groups, All ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*StackSummary*)
StackSummary[ stack_List ] := <|
    "Length"    -> Length @ stack,
    "ByteCount" -> ByteCount @ stack,
    "TopHeads"  -> Take[ tallyByCount[ frameHeadString /@ stack ], UpTo[ 10 ] ],
    "Contexts"  -> Take[ tallyByCount @ DeleteCases[ frameContext /@ stack, None ], UpTo[ 10 ] ]
|>;

StackSummary[ a_Association /; ListQ @ Lookup[ a, "RawStack" ] ] := StackSummary @ a[ "RawStack" ];

StackSummary[ args___ ] := badCall[ StackSummary, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*StackAtMessage*)
StackAtMessage // Attributes = { HoldAll };

defineOptions[ StackAtMessage, Join[
    {
        { "MaxCount"        , 1    , positiveIntegerQ, "a positive integer" },
        { "Stop"            , True , booleanQ        , "True or False" },
        { "Complete"        , True , booleanQ        , "True or False" },
        { "IncludeQuieted"  , False, booleanQ        , "True or False" },
        { "IgnoreOuterQuiet", True , booleanQ        , "True or False" },
        { "RawStack"        , False, booleanQ        , "True or False" },
        $resultOptionSpec
    },
    $formatStackOptionSpecs
] ];

StackAtMessage[ expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ StackAtMessage, { opts } ] :=
    stackAtMessage[ HoldComplete @ expr, All, { opts } ];

StackAtMessage[ expr_, msg: Except[ _Rule | _RuleDelayed | { ( _Rule | _RuleDelayed ) ... } ], opts: OptionsPattern[ ] ] /;
    messageSelectorQ @ msg && validOptionsQ[ StackAtMessage, { opts } ] :=
        stackAtMessage[ HoldComplete @ expr, messageSelector @ msg, { opts } ];

StackAtMessage[ args___ ] := badCall[ StackAtMessage, HoldComplete @ args ];

stackAtMessage[ HoldComplete[ expr_ ], selector_, opts_List ] :=
    Module[ { o, max, r, recs, fmtOpts, raw, result },
        o   = optionsAssociation[ StackAtMessage, opts ];
        max = o[ "MaxCount" ];
        raw = TrueQ @ o[ "RawStack" ];
        r = collectMessagesCore[
            HoldComplete @ expr,
            <|
                "IncludeQuieted"   -> o[ "IncludeQuieted" ],
                "IgnoreOuterQuiet" -> o[ "IgnoreOuterQuiet" ],
                "Complete"         -> o[ "Complete" ],
                "StackFrames"      -> 0,
                "MaxMessages"      -> max,
                "Select"           -> selector,
                "StopAt"           -> If[ TrueQ @ o[ "Stop" ], { selector, max }, None ],
                "RawStack"         -> True
            |>
        ];
        fmtOpts = FilterRules[ Normal @ o, Options @ FormatStack ];
        recs = Map[
            Function[ rec,
                <|
                    "Message"     -> rec[ "Text" ],
                    "Stack"       -> formatStack[ rec[ "RawStack" ], fmtOpts ],
                    "StackLength" -> Length @ rec[ "RawStack" ],
                    If[ raw, "RawStack" -> rec[ "RawStack" ], Nothing ]
                |>
            ],
            r[ "Messages" ]
        ];
        result = boundedResult[ r[ "Result" ], o[ "MaxResultBytes" ] ];
        Which[
            recs === { }, <| "Result" -> result, "Message" -> None, "Stack" -> None |>,
            max === 1   , Join[ <| "Result" -> result |>, First @ recs ],
            True        , <| "Result" -> result, "Count" -> Length @ recs, "Captures" -> recs |>
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*StackAtCall*)
(* A never-matching conditional rule is prepended to the head symbol inside Internal`InheritedBlock: its condition
   runs while the call frame (with evaluated arguments) is on the stack, and evaluation is otherwise unaffected. *)
StackAtCall // Attributes = { HoldAll };

defineOptions[ StackAtCall, Join[
    {
        { "MaxCount", 1    , positiveIntegerQ, "a positive integer" },
        { "Stop"    , True , booleanQ        , "True or False" },
        { "Complete", False, booleanQ        , "True or False" },
        { "RawStack", False, booleanQ        , "True or False" },
        $resultOptionSpec
    },
    $formatStackOptionSpecs
] ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::VariableError::Block:: *)
(* :!CodeAnalysis::Disable::UnusedParameter:: *)
StackAtCall[ expr_, callPatt_, opts: OptionsPattern[ ] ] /; validOptionsQ[ StackAtCall, { opts } ] :=
    catchHelperFailure @ Module[ { o, sym, bag, tag, max, stop, result, rule, stacks, fmtOpts },
        o   = optionsAssociation[ StackAtCall, { opts } ];
        sym = callPatternSymbol @ callPatt;
        If[ sym === $Failed,
            throwHelperFailure[
                StackAtCall,
                "Cannot find the head symbol of the call pattern `1`: use f[...], _f or f[...] /; cond.",
                { heldString[ HoldComplete @ callPatt, 80 ] }
            ]
        ];
        If[ lockedQ @@ sym,
            throwHelperFailure[ StackAtCall, "Cannot probe the Locked symbol `1`.", { heldString[ sym, 80 ] } ]
        ];
        ensureLoaded @@ sym;
        bag  = Internal`Bag[ ];
        max  = o[ "MaxCount" ];
        stop = TrueQ @ o[ "Stop" ];
        rule = RuleDelayed @@ {
            Condition[
                HoldPattern @ callPatt,
                (
                    If[ Internal`BagLength @ bag < max,
                        Internal`StuffBag[ bag, DeleteCases[ TakeWhile[ Stack[ _ ], FreeQ[ #, HoldPattern @ bag ] & ], _?wrapperFrameQ ] ]
                    ];
                    If[ stop && Internal`BagLength @ bag >= max, Throw[ Null, tag ] ];
                    False
                )
            ],
            Null
        };
        result = Replace[
            sym,
            HoldComplete[ s_ ] :> evaluateContained @ Catch[
                Internal`InheritedBlock[ { s },
                    Unprotect @ s;
                    DownValues[ s ] = Prepend[ DownValues @ s, rule ];
                    If[ TrueQ @ o[ "Complete" ], StackBegin @ StackComplete @ expr, StackBegin @ expr ]
                ],
                tag,
                Missing[ "Stopped" ] &
            ]
        ];
        stacks = Internal`BagPart[ bag, All ];
        fmtOpts = FilterRules[ Normal @ o, Options @ FormatStack ];
        <|
            "Result" -> boundedResult[ result, o[ "MaxResultBytes" ] ],
            "Count"  -> Length @ stacks,
            "Stacks" -> ( formatStack[ #, fmtOpts ] & /@ stacks ),
            If[ TrueQ @ o[ "RawStack" ], "RawStacks" -> stacks, Nothing ]
        |>
    ];
(* :!CodeAnalysis::EndBlock:: *)

StackAtCall[ args___ ] := badCall[ StackAtCall, HoldComplete @ args ];

(* HoldComplete[f] for the call patterns f[...], _f, e_f, f[...] /; cond and HoldPattern[...] of these *)
callPatternSymbol // Attributes = { HoldAllComplete };
callPatternSymbol[ Verbatim[ HoldPattern ][ p_ ] ] := callPatternSymbol @ p;
callPatternSymbol[ Verbatim[ Blank ][ s_Symbol ] ] := HoldComplete @ s;
callPatternSymbol[ Verbatim[ Pattern ][ _, p_ ] ] := callPatternSymbol @ p;
callPatternSymbol[ Verbatim[ Condition ][ p_, _ ] ] := callPatternSymbol @ p;
callPatternSymbol[ ( s_Symbol )[ ___ ] ] /;
    ! MatchQ[ Unevaluated @ s, Blank | Pattern | Condition | PatternTest | Alternatives | HoldPattern | Verbatim | Rule | RuleDelayed | List ] :=
        HoldComplete @ s;
callPatternSymbol[ ___ ] := $Failed;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*CaptureEvaluation*)
(* $CaptureFunction must stay self-contained (pure Function, only System` and Internal` symbols and its own Module
   locals): it is sent to subkernels and task bodies, where this package is not loaded. It therefore has its own
   compact message collector instead of collectMessagesCore. *)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
$CaptureFunction = Function[
    expr,
    Module[
        {
            msgs = Internal`Bag[ ], nMsgs = 0, prints = Internal`Bag[ ], nPrints = 0, stack = None, res, ok,
            t0 = AbsoluteTime[ ], aborted = False, thrown = None, str, msgStr
        },
        str = Function[
            e,
            StringTake[
                StringReplace[ ToString[ Unevaluated @ e, InputForm, PageWidth -> Infinity, TotalWidth -> 200 ], "\n" -> " " ],
                UpTo[ 160 ]
            ],
            HoldAllComplete
        ];
        msgStr = Function[
            m,
            Replace[
                m,
                {
                    Hold[ Message[ MessageName[ s_, t_ ], args___ ], _ ] :>
                        With[ { tmpl = Replace[ MessageName[ s, t ], Except[ _String ] :> Replace[ MessageName[ General, t ], Except[ _String ] -> "" ] ] },
                            StringTake[
                                SymbolName @ Unevaluated @ s <> "::" <> t <> ": " <>
                                    ToString @ StringForm[ tmpl, Sequence @@ Replace[ { args }, ( HoldCompleteForm | HoldForm )[ a_ ] :> str @ a, { 1 } ] ],
                                UpTo[ 300 ]
                            ]
                        ],
                    other_ :> str @ other
                }
            ],
            HoldAllComplete
        ];
        res = CheckAbort[
            Replace[
                Catch @ ok @ Catch[
                    Internal`HandlerBlock[
                        {
                            "Message",
                            Function[ m,
                                If[ TrueQ @ Last @ m,  (* only messages that would be shown (not quieted) *)
                                    nMsgs++;
                                    If[ nMsgs <= 10, Internal`StuffBag[ msgs, msgStr @ m ] ];
                                    If[ stack === None,
                                        stack = Replace[
                                            Replace[ Stack[ _ ], { a___, mf: ( HoldCompleteForm | HoldForm )[ _Message ], ___ } :> { a, mf } ],
                                            ( HoldCompleteForm | HoldForm )[ e_ ] :> str @ e,
                                            { 1 }
                                        ];
                                        stack = Take[ stack, -Min[ 12, Length @ stack ] ]
                                    ]
                                ]
                            ]
                        },
                        Block[
                            {
                                Print = Function[
                                    Null,
                                    nPrints++;
                                    If[ nPrints <= 10, Internal`StuffBag[ prints, StringTake[ StringJoin[ ToString /@ { ## } ], UpTo[ 200 ] ] ] ],
                                    HoldAllComplete
                                ]
                            },
                            Quiet[ HoldComplete @@ { StackBegin @ expr }, None, All ]
                        ]
                    ],
                    _,
                    Function[ { v, tag },
                        (* the MCP evaluator (Chatbook sandbox) turns an untagged Throw[v] into Throw[v, ...`$untagged] *)
                        If[ MatchQ[ tag, _Symbol ] && SymbolName @ tag === "$untagged",
                            thrown = "Throw[" <> str @ v <> "]"; HoldComplete @ Throw @ v,
                            thrown = "Throw[" <> str @ v <> ", " <> str @ tag <> "]"; HoldComplete @ Throw[ v, tag ]
                        ]
                    ]
                ],
                { ok[ h_ ] :> h, v_ :> ( thrown = "Throw[" <> str @ v <> "]"; HoldComplete @ Throw @ v ) }
            ],
            aborted = True; HoldComplete @ $Aborted
        ];
        <|
            "KernelID"     -> If[ MemberQ[ $Packages, "Parallel`" ], $KernelID, 0 ],  (* $KernelID alone would load Parallel` *)
            "PID"          -> $ProcessID,
            "Result"       -> If[ ByteCount @ res <= 10000, res, Missing[ "TooLarge", <| "ByteCount" -> ByteCount @ res, "Preview" -> Replace[ res, HoldComplete[ r_ ] :> str @ r ] |> ] ],
            "ResultString" -> Replace[ res, HoldComplete[ r_ ] :> str @ r ],
            "MessageCount" -> nMsgs,
            "Messages"     -> Internal`BagPart[ msgs, All ],
            "PrintCount"   -> nPrints,
            "Prints"       -> Internal`BagPart[ prints, All ],
            "Stack"        -> stack,
            "Aborted"      -> aborted,
            "Thrown"       -> thrown,
            "Seconds"      -> Round[ AbsoluteTime[ ] - t0, 0.001 ]
        |>
    ],
    HoldAll
];
(* :!CodeAnalysis::EndBlock:: *)

CaptureEvaluation // Attributes = { HoldAll };
CaptureEvaluation[ expr_ ] := $CaptureFunction @ expr;
CaptureEvaluation[ args___ ] := badCall[ CaptureEvaluation, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Performance and Trace*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*SampleStacks*)
(* Statistical profiler and hang locator that works in every environment (no Trace): a ScheduledTask samples the
   stack while expr runs; expr is stopped with TimeConstrained after maxSeconds. *)
SampleStacks // Attributes = { HoldFirst };

defineOptions[ SampleStacks, {
    { "Interval"      , 0.01, positiveNumberQ , "a positive number of seconds" },
    { "MaxEntries"    , 8   , positiveIntegerQ, "a positive integer" },
    { "MaxFrames"     , 12  , positiveIntegerQ, "a positive integer" },
    { "MaxFrameLength", 100 , positiveIntegerQ, "a positive integer" },
    $resultOptionSpec
} ];

SampleStacks[ expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ SampleStacks, { opts } ] :=
    sampleStacks[ HoldComplete @ expr, Automatic, { opts } ];

SampleStacks[ expr_, t: Automatic | _? positiveNumberQ, opts: OptionsPattern[ ] ] /; validOptionsQ[ SampleStacks, { opts } ] :=
    sampleStacks[ HoldComplete @ expr, t, { opts } ];

SampleStacks[ args___ ] := badCall[ SampleStacks, HoldComplete @ args ];

sampleStacks[ HoldComplete[ expr_ ], t_, opts_List ] :=
    Module[ { o, maxTime, dt, bag, last, sample, removedQ, task, time, result, stacks, n, user, pct, incl, inner, self, lastFrames },
        o       = optionsAssociation[ SampleStacks, opts ];
        maxTime = If[ t === Automatic, autoTimeLimit[ 10 ], t ];
        dt      = o[ "Interval" ];
        bag     = Internal`Bag[ ];
        last    = { };
        (* the task body: heads of every sample, full frames of the most recent sample only *)
        sample[ ] := ( Internal`StuffBag[ bag, Stack[ ] ]; last = Stack[ _ ] );
        removedQ = Function[ h, StringStartsQ[ ToString @ Unevaluated @ h, "Removed[" ], HoldAllComplete ];
        task = SessionSubmit @ ScheduledTask[ sample[ ], { dt, Ceiling[ maxTime / dt ] + 10 } ];  (* always bounded *)
        { time, result } = WithCleanup[
            AbsoluteTiming @ evaluateContained @ TimeConstrained[ StackBegin @ StackComplete @ expr, maxTime, $TimedOut ],
            Quiet @ TaskRemove @ task
        ];
        (* drop the task's own frames: everything from the LAST Block (the task's Block[{$CurrentTask = ...}, ...])
           onwards, plus Removed["$$Failure"] frames that the task machinery sometimes leaves just before it *)
        stacks = Function[ st,
            Select[
                Replace[ Position[ st, Block, { 1 }, Heads -> False ], { { } -> st, p_ :> Take[ st, p[[ -1, 1 ]] - 1 ] } ],
                ! MatchQ[ #, StackComplete ] && ! removedQ[ # ] &
            ]
        ] /@ Internal`BagPart[ bag, All ];
        stacks = Select[ stacks, # =!= { } & ];
        n = Length @ stacks;
        (* frames of non-System` symbols (Quiet: removed symbols such as Removed["$$Failure"] can show up) *)
        user = Function[ st,
            Select[ st, Quiet @ With[ { c = Context @ # }, StringQ @ c && c =!= "System`" && ! StringMatchQ[ c, $packageContextPattern ] ] & ]
        ];
        pct = Function[ c,
            Take[ ReverseSort @ N @ Round[ 100 * KeyMap[ symbolString, c ] / Max[ n, 1 ], 1 / 10 ], UpTo[ o[ "MaxEntries" ] ] ]
        ];
        incl  = Counts @ Flatten[ DeleteDuplicates @* user /@ stacks ];
        inner = Counts @ DeleteCases[ Replace[ user /@ stacks, { { } -> Missing[ ], l_ :> Last @ l }, { 1 } ], _Missing ];
        self  = Counts[ Last /@ stacks ];
        lastFrames = Select[
            TakeWhile[ last, FreeQ[ #, $CurrentTask | sample ] & ],
            ! MatchQ[ #, ( HoldCompleteForm | HoldForm )[ _StackComplete ] | ( HoldCompleteForm | HoldForm )[ h_[ ___ ] /; removedQ @ h ] ] &
        ];
        <|
            "Seconds"            -> N @ Round[ time, 1 / 1000 ],
            "TimeLimit"          -> N @ maxTime,
            "TimedOut"           -> result === HoldComplete @ $TimedOut,
            "Samples"            -> n,
            "Functions%"         -> pct @ incl,   (* % of samples with the function anywhere on the stack *)
            "InnermostFunction%" -> pct @ inner,  (* % of samples where it is the innermost non-System function *)
            "Builtin%"           -> pct @ self,   (* % of samples by innermost frame head (usually System`) *)
            "LastFrames"         -> frameStrings[ lastFrames, o[ "MaxFrames" ], o[ "MaxFrameLength" ] ],
            "Result"             -> boundedResult[ result, o[ "MaxResultBytes" ] ]
        |>
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TimeCalls*)
(* Exact call counts and inclusive wall-clock time, attributed to the outermost active call of each symbol (recursion
   is not double counted). Calls answered by literal rules (f[0] = 1) are tried before pattern rules and not counted. *)
TimeCalls // Attributes = { HoldAll };

defineOptions[ TimeCalls, { $resultOptionSpec } ];

TimeCalls[ expr_, syms: { __Symbol }, opts: OptionsPattern[ ] ] /; validOptionsQ[ TimeCalls, { opts } ] :=
    catchHelperFailure[
        checkSpySymbols[ TimeCalls, HoldComplete @ syms ];
        timeCalls[ HoldComplete @ expr, HoldComplete @ syms, optionsAssociation[ TimeCalls, { opts } ] ]
    ];

TimeCalls[ args___ ] := badCall[ TimeCalls, HoldComplete @ args ];

timeCalls[ HoldComplete[ expr_ ], HoldComplete[ syms_ ], o_Association ] :=
    Module[ { calls = <| |>, secs = <| |>, active, skip, total, result },
        active[ _ ] = False;
        skip[ _ ] = False;
        ensureLoaded @ syms;
        (* :!CodeAnalysis::BeginBlock:: *)
        (* :!CodeAnalysis::Disable::VariableError::Block:: *)
        (* :!CodeAnalysis::Disable::Arguments::Block:: *)
        Internal`InheritedBlock[ syms,
            Scan[
                Function[ s,
                    Unprotect @ s;
                    PrependTo[
                        DownValues @ s,
                        HoldPattern[ s[ args___ ] ] /;
                            If[ skip @ s,
                                skip[ s ] = False; False,  (* the wrapper's own re-call: use the original rules *)
                                calls[ s ] = Lookup[ calls, s, 0 ] + 1; ! active @ s
                            ] :>
                            Module[ { t0 = AbsoluteTime[ ] },
                                WithCleanup[
                                    active[ s ] = True; skip[ s ] = True,
                                    s @ args,
                                    active[ s ] = False; secs[ s ] = Lookup[ secs, s, 0 ] + AbsoluteTime[ ] - t0
                                ]
                            ]
                    ]
                ],
                syms
            ];
            total = First @ AbsoluteTiming[ result = evaluateContained @ expr ]
        ];
        (* :!CodeAnalysis::EndBlock:: *)
        <|
            "TotalSeconds" -> N @ Round[ total, 1 / 1000 ],
            "Calls"        -> KeyMap[ symbolString, calls ],
            "Seconds"      -> ReverseSort @ N @ Round[ KeyMap[ symbolString, secs ], 1 / 1000 ],
            "Result"       -> boundedResult[ result, o[ "MaxResultBytes" ] ]
        |>
    ];

(* symbols for spies (TimeCalls, LogCalls): not Locked, no OwnValues (calls to f = Function[...] never reach DownValues) *)
checkSpySymbols[ f_Symbol, HoldComplete[ { syms___ } ] ] := (
    ensureLoaded @ { syms };
    With[ { locked = Select[ HoldComplete @ syms, lockedQ ] },
        If[ locked =!= HoldComplete[ ],
            throwHelperFailure[ f, "Cannot spy on the Locked symbol(s) `1`.", { heldString[ locked, 100 ] } ]
        ]
    ];
    With[ { own = Select[ HoldComplete @ syms, Function[ s, OwnValues @ s =!= { }, HoldAllComplete ] ] },
        If[ own =!= HoldComplete[ ],
            throwHelperFailure[ f, "The symbol(s) `1` have OwnValues (e.g. f = Function[...]): calls to them never reach DownValues.", { heldString[ own, 100 ] } ]
        ]
    ];
);

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TraceAvailableQ*)
TraceAvailableQ[ ] := Trace[ 1 + 1 ] =!= { };
TraceAvailableQ[ args__ ] := badCall[ TraceAvailableQ, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TraceCalls*)
(* The rule form of Trace is a streaming callback: each match is recorded as a short string and the evaluation is
   stopped (Throw) after n matches. Traced code that contains Catch[..., _] can intercept that Throw. *)
TraceCalls // Attributes = { HoldAll };

defineOptions[ TraceCalls, { { "MaxLength", 150, positiveIntegerQ, "a positive integer" } } ];

TraceCalls[ expr_, form_, opts: OptionsPattern[ ] ] /; validOptionsQ[ TraceCalls, { opts } ] :=
    traceCalls[ HoldComplete @ expr, HoldComplete @ form, 20, { opts } ];

TraceCalls[ expr_, form_, n_, opts: OptionsPattern[ ] ] /; positiveIntegerQ @ n && validOptionsQ[ TraceCalls, { opts } ] :=
    traceCalls[ HoldComplete @ expr, HoldComplete @ form, n, { opts } ];

TraceCalls[ args___ ] := badCall[ TraceCalls, HoldComplete @ args ];

traceCalls[ _HoldComplete, _HoldComplete, _Integer, _List ] /; ! TraceAvailableQ[ ] :=
    traceUnavailableFailure @ TraceCalls;

traceCalls[ HoldComplete[ expr_ ], HoldComplete[ form_ ], n_Integer, opts_List ] /; TraceAvailableQ[ ] :=
    Module[ { o, bag, k, tag, w, finished },
        o   = optionsAssociation[ TraceCalls, opts ];
        bag = Internal`Bag[ ];
        k   = 0;
        w   = o[ "MaxLength" ];
        finished = With[ { to = Sequence @@ traceOptions @ opts },
            evaluateContained @ Catch[
                Trace[
                    expr,
                    e: form :> ( Internal`StuffBag[ bag, heldString[ HoldComplete @ e, w ] ]; If[ ++k >= n, Throw[ False, tag ] ]; Null ),
                    to
                ];
                True,
                tag
            ]
        ];
        <|
            "Calls"              -> Internal`BagPart[ bag, All ],
            "EvaluationFinished" -> Replace[ finished, { HoldComplete[ b: True | False ] :> b, HoldComplete[ other_ ] :> other } ]
        |>
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*CountCalls*)
CountCalls // Attributes = { HoldAll };

defineOptions[ CountCalls, { { "MaxEntries", 25, positiveIntegerQ, "a positive integer" } } ];

CountCalls[ expr_, form_, opts: OptionsPattern[ ] ] /; validOptionsQ[ CountCalls, { opts } ] :=
    countCalls[ HoldComplete @ expr, HoldComplete @ form, { opts } ];

CountCalls[ args___ ] := badCall[ CountCalls, HoldComplete @ args ];

countCalls[ _HoldComplete, _HoldComplete, _List ] /; ! TraceAvailableQ[ ] :=
    traceUnavailableFailure @ CountCalls;

countCalls[ HoldComplete[ expr_ ], HoldComplete[ form_ ], opts_List ] /; TraceAvailableQ[ ] :=
    Module[ { o, bag, counts, max },
        o   = optionsAssociation[ CountCalls, opts ];
        bag = Internal`Bag[ ];
        max = o[ "MaxEntries" ];
        With[ { to = Sequence @@ traceOptions @ opts },
            evaluateContained @ Trace[ expr, e: form :> ( Internal`StuffBag[ bag, headString @ e ]; Null ), to ]
        ];
        counts = ReverseSort @ Counts @ Internal`BagPart[ bag, All ];
        If[ Length @ counts > max,
            Append[ Take[ counts, max ], "(other heads)" -> Total @ Drop[ Values @ counts, max ] ],
            counts
        ]
    ];

headString // Attributes = { HoldAllComplete };
headString[ ( h_Symbol )[ ___ ] ] := symbolString @ h;
headString[ ( h_ )[ ___ ] ] := heldString[ HoldComplete @ h, 60 ];
headString[ e_ ] := heldString[ HoldComplete @ e, 60 ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FindHang*)
(* Runs expr for at most maxSteps evaluation steps (TraceScan); if it has not finished, it is stopped and the last
   steps and the stack heads at that moment are returned. *)
FindHang // Attributes = { HoldFirst };

defineOptions[ FindHang, {
    { "LastSteps"    , 15 , positiveIntegerQ, "a positive integer" },
    { "MaxLength"    , 120, positiveIntegerQ, "a positive integer" },
    { "MaxStackHeads", 25 , positiveIntegerQ, "a positive integer" },
    $resultOptionSpec
} ];

FindHang[ expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ FindHang, { opts } ] :=
    findHang[ HoldComplete @ expr, 10^5, { opts } ];

FindHang[ expr_, maxSteps_? positiveIntegerQ, opts: OptionsPattern[ ] ] /; validOptionsQ[ FindHang, { opts } ] :=
    findHang[ HoldComplete @ expr, maxSteps, { opts } ];

FindHang[ args___ ] := badCall[ FindHang, HoldComplete @ args ];

findHang[ _HoldComplete, _Integer, _List ] /; ! TraceAvailableQ[ ] :=
    traceUnavailableFailure @ FindHang;

findHang[ HoldComplete[ expr_ ], maxSteps_Integer, opts_List ] /; TraceAvailableQ[ ] :=
    Module[ { o, k, ring, i, tag, step, outcome },
        o    = optionsAssociation[ FindHang, opts ];
        k    = o[ "LastSteps" ];
        ring = ConstantArray[ Null, k ];
        i    = 0;
        step[ e_ ] := (
            ring[[ Mod[ i, k ] + 1 ]] = e;
            If[ ++i >= maxSteps, Throw[ { RotateLeft[ ring, Mod[ i, k ] ], Stack[ ] }, tag ] ]
        );
        outcome = evaluateContained @ Catch[
            finishedValue @ TraceScan[ step, StackBegin @ StackComplete @ expr, _[ ___ ] ],  (* _[___]: skip atoms *)
            tag,
            stoppedAt
        ];
        Replace[
            outcome,
            {
                HoldComplete[ stoppedAt[ { steps_, heads_ }, _ ] ] :>
                    (* the stack when it was stopped; the frames from step[...] on belong to this helper *)
                    With[ { hs = symbolString /@ DeleteCases[ TakeWhile[ heads, # =!= step & ], StackComplete ] },
                        <|
                            "Finished"   -> False,
                            "Steps"      -> i,
                            "StackHeads" -> Take[ hs, -Min[ o[ "MaxStackHeads" ], Length @ hs ] ],
                            "LastSteps"  -> ( frameString[ #, o[ "MaxLength" ], False ] & /@ DeleteCases[ steps, Null ] )
                        |>
                    ],
                HoldComplete[ finishedValue[ v_ ] ] :> <|
                    "Finished" -> True,
                    "Steps"    -> i,
                    "Result"   -> boundedResult[ HoldComplete @ v, o[ "MaxResultBytes" ] ]
                |>,
                other_ :> <| "Finished" -> True, "Steps" -> i, "Result" -> boundedResult[ other, o[ "MaxResultBytes" ] ] |>
            }
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Overrides*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LogCalls*)
(* Spy rules are prepended inside Internal`InheritedBlock: HoldPattern[f[...]] /; guard :> logCall[...], where
   logCall records the call, re-dispatches it to the original rules and records the result. Literal rules (f[0] = 1)
   are hashed and tried before any pattern rule, so with "IncludeLiteralRules" -> True they are turned into
   conditional pattern rules inside the block. Flat heads get a per-function boolean guard. *)
LogCalls // Attributes = { HoldAll };

defineOptions[ LogCalls, {
    { "MaxCalls"           , 200 , positiveIntegerQ, "a positive integer" },
    { "IncludeLiteralRules", True, booleanQ        , "True or False" },
    $resultOptionSpec
} ];

(* used by the spy condition or outside the inLogger guard: spying on them would recurse forever *)
$loggerInternals = { Block, AbsoluteTiming, TrueQ, Not, And, FreeQ, Verbatim, HoldComplete };

LogCalls[ s_Symbol, expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ LogCalls, { opts } ] := LogCalls[ { s }, expr, opts ];

LogCalls[ syms: { __Symbol }, expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ LogCalls, { opts } ] :=
    catchHelperFailure[
        checkSpySymbols[ LogCalls, HoldComplete @ syms ];
        With[ { unsafe = Select[ HoldComplete @@ Unevaluated @ syms, Function[ s, MemberQ[ $loggerInternals, Unevaluated @ s ], HoldAllComplete ] ] },
            If[ unsafe =!= HoldComplete[ ],
                throwHelperFailure[ LogCalls, "Cannot spy on `1`: LogCalls itself uses these functions.", { heldString[ unsafe, 100 ] } ]
            ]
        ];
        logCalls[ HoldComplete @ syms, HoldComplete @ expr, optionsAssociation[ LogCalls, { opts } ] ]
    ];

LogCalls[ args___ ] := badCall[ LogCalls, HoldComplete @ args ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::VariableError::Block:: *)
(* :!CodeAnalysis::Disable::ShadowedVariable::Block:: *)
(* :!CodeAnalysis::Disable::UnusedParameter:: *)
logCalls[ HoldComplete[ { syms___ } ], HoldComplete[ expr_ ], o_Association ] :=
    Module[ { calls = <| |>, id = 0, parent = 0, depth = 0, skip = { }, inLogger = False, max, literal, result, logCall },
        max     = o[ "MaxCalls" ];
        literal = TrueQ @ o[ "IncludeLiteralRules" ];
        result = Internal`InheritedBlock[ { syms },
            Block[ { inLogger = True },
                Scan[
                    Function[ s,
                        Unprotect @ s;
                        If[ literal, DownValues[ s ] = literalToPattern /@ DownValues @ s ];
                        PrependTo[
                            DownValues @ s,
                            If[ MemberQ[ Attributes @ s, Flat ],
                                (* Flat heads (StringJoin, Plus, Join, ...): the matcher evaluates the condition many times
                                   and can match subsequences: nested calls of the SAME Flat function are not logged *)
                                HoldPattern[ e: s[ ___ ] /; ! TrueQ @ inLogger && FreeQ[ skip, HoldComplete @ s, { 1 } ] ] :>
                                    logCall[ HoldComplete @ e, HoldComplete @ s ],
                                (* other heads: skip only the exact call being re-dispatched, so recursion is logged *)
                                HoldPattern[ e: s[ ___ ] /; ! TrueQ @ inLogger && FreeQ[ skip, Verbatim @ HoldComplete @ e, { 1 } ] ] :>
                                    logCall[ HoldComplete @ e, HoldComplete @ e ]
                            ]
                        ]
                    ],
                    Hold @ syms
                ]
            ];
            Block[ { logCall },
                logCall // Attributes = { HoldAllComplete };
                logCall[ HoldComplete[ e_ ], key_ ] :=
                    Block[ { inLogger = True },
                        With[ { myID = ++id, d = depth + 1, newSkip = Append[ skip, key ] },
                            If[ myID <= max,
                                calls[ myID ] = <|
                                    "ID"      -> myID,
                                    "Depth"   -> d,
                                    "Parent"  -> parent,
                                    "Call"    -> boundedEntry @ HoldComplete @ e,
                                    "Result"  -> Missing[ "NotReturned" ],
                                    "Seconds" -> Missing[ "NotReturned" ]
                                |>
                            ];
                            With[ { tr = Block[ { skip = newSkip, depth = d, parent = myID, inLogger = False }, AbsoluteTiming @ e ] },
                                If[ myID <= max,
                                    calls[ myID ] = Join[
                                        calls @ myID,
                                        <| "Result" -> boundedEntry[ HoldComplete @@ { Last @ tr } ], "Seconds" -> First @ tr |>
                                    ]
                                ];
                                Last @ tr
                            ]
                        ]
                    ];
                evaluateContained @ expr
            ]
        ];
        <| "Result" -> boundedResult[ result, o[ "MaxResultBytes" ] ], "Calls" -> Values @ calls, "TotalCalls" -> id |>
    ];
(* :!CodeAnalysis::EndBlock:: *)

(* call and result entries stay held unless they are big *)
boundedEntry[ h_HoldComplete ] := If[ ByteCount @ h <= 2000, h, heldString[ h, 200 ] ];

$$patternHead = Pattern | Blank | BlankSequence | BlankNullSequence | Condition | PatternTest | Alternatives |
    Optional | Repeated | RepeatedNull | Except | Longest | Shortest | OptionsPattern | KeyValuePattern |
    PatternSequence | OrderlessPatternSequence | Verbatim;

literalToPattern[ Verbatim[ RuleDelayed ][ Verbatim[ HoldPattern ][ lhs_ ], rhs_ ] ] /;
    FreeQ[ Unevaluated @ lhs, $$patternHead, Heads -> True ] :=
        HoldPattern[ lhs /; True ] :> rhs;
literalToPattern[ rule_ ] := rule;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*CallLogSummary*)
defineOptions[ CallLogSummary, { { "MaxLength", 120, positiveIntegerQ, "a positive integer" } } ];

CallLogSummary[ log_? callLogQ, opts: OptionsPattern[ ] ] /; validOptionsQ[ CallLogSummary, { opts } ] :=
    callLogSummary[ log, 30, OptionValue[ "MaxLength" ] ];

CallLogSummary[ log_? callLogQ, n_? positiveIntegerQ, opts: OptionsPattern[ ] ] /; validOptionsQ[ CallLogSummary, { opts } ] :=
    callLogSummary[ log, n, OptionValue[ "MaxLength" ] ];

CallLogSummary[ args___ ] := badCall[ CallLogSummary, HoldComplete @ args ];

callLogQ[ log_ ] := AssociationQ @ log && ListQ @ Lookup[ log, "Calls" ] && IntegerQ @ Lookup[ log, "TotalCalls" ];

callLogSummary[ log_Association, n_Integer, w_Integer ] :=
    StringRiffle[
        Map[
            Function[ c,
                StringJoin[
                    StringRepeat[ "  ", Max[ c[ "Depth" ] - 1, 0 ] ],
                    truncateString[
                        StringJoin[
                            entryString[ c[ "Call" ], w ],
                            " -> ",
                            entryString[ c[ "Result" ], w ],
                            If[ NumberQ @ c[ "Seconds" ], " (" <> ToString @ Round[ 1000 * c[ "Seconds" ], 0.01 ] <> " ms)", "" ]
                        ],
                        w
                    ]
                ]
            ],
            Take[ log[ "Calls" ], UpTo[ n ] ]
        ],
        "\n"
    ] <> If[ log[ "TotalCalls" ] > n, "\n... (" <> ToString @ log[ "TotalCalls" ] <> " calls total)", "" ];

entryString[ h_HoldComplete, w_ ] := heldString[ h, w ];
entryString[ s_String, _ ] := s;
entryString[ other_, w_ ] := heldString[ HoldComplete @ other, w ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WithOverrides*)
(* Prepends the rules temporarily (OwnValues for a bare symbol LHS, DownValues for s[...], SubValues for s[...][...]);
   rules are always treated as delayed. The result is returned in HoldComplete so that it is not re-evaluated after
   the real definitions are back. *)
WithOverrides // Attributes = { HoldAll };

defineOptions[ WithOverrides, { $resultOptionSpec } ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::VariableError::Block:: *)
WithOverrides[ rules: { ( _RuleDelayed | _Rule ) .. }, expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ WithOverrides, { opts } ] :=
    catchHelperFailure @ Module[ { targets, syms, bad },
        targets = Cases[ Unevaluated @ rules, ( Rule | RuleDelayed )[ lhs_, _ ] :> ruleTarget @ lhs, { 1 } ];
        If[ ! MatchQ[ targets, { { HoldComplete[ _Symbol ], OwnValues | DownValues | SubValues } .. } ],
            throwHelperFailure[
                WithOverrides,
                "Cannot determine the symbol to attach every rule to: each lhs must be sym, sym[...] or sym[...][...] (optionally with HoldPattern or a condition)."
                , { }
            ]
        ];
        syms = DeleteDuplicates @ Flatten[ HoldComplete @@ targets[[ All, 1 ]], 1, HoldComplete ];
        bad  = Select[ syms, lockedQ ];
        If[ bad =!= HoldComplete[ ],
            throwHelperFailure[ WithOverrides, "Cannot override the Locked symbol(s) `1`.", { heldString[ bad, 100 ] } ]
        ];
        boundedHeld[
            Replace[
                syms,
                HoldComplete[ s___ ] :> (
                    ensureLoaded @ { s };
                    Internal`InheritedBlock[ { s },
                        Unprotect @ s;
                        (* add in reverse so that the first rule given ends up first *)
                        Scan[ Function[ r, addRule @ r, HoldAllComplete ], Reverse[ Hold @@ Unevaluated @ rules ] ];
                        evaluateContained @ expr
                    ]
                )
            ],
            OptionValue[ "MaxResultBytes" ]
        ]
    ];
(* :!CodeAnalysis::EndBlock:: *)

WithOverrides[ args___ ] := badCall[ WithOverrides, HoldComplete @ args ];

ruleTarget // Attributes = { HoldAllComplete };
ruleTarget[ Verbatim[ HoldPattern ][ lhs_ ] ] := ruleTarget @ lhs;
ruleTarget[ Verbatim[ Condition ][ lhs_, _ ] ] := ruleTarget @ lhs;
ruleTarget[ Verbatim[ Pattern ][ _, lhs_ ] ] := ruleTarget @ lhs;
ruleTarget[ s_Symbol ] := { HoldComplete @ s, OwnValues };
ruleTarget[ h_[ ___ ] ] := Replace[
    ruleTarget @ h,
    { { s_, OwnValues } :> { s, DownValues }, { s_, DownValues | SubValues } :> { s, SubValues } }
];
ruleTarget[ _ ] := $Failed;

addRule // Attributes = { HoldAllComplete };
addRule[ ( Rule | RuleDelayed )[ lhs_, rhs_ ] ] :=
    With[ { t = ruleTarget @ lhs, heldLHS = ensureHoldPattern @ lhs },
        Replace[
            t,
            {
                { HoldComplete[ sym_ ], OwnValues  } :> ( OwnValues[ sym ] = { heldLHS :> rhs } ),
                { HoldComplete[ sym_ ], DownValues } :> PrependTo[ DownValues @ sym, heldLHS :> rhs ],
                { HoldComplete[ sym_ ], SubValues  } :> PrependTo[ SubValues @ sym, heldLHS :> rhs ]
            }
        ]
    ];

ensureHoldPattern // Attributes = { HoldAllComplete };
ensureHoldPattern[ Verbatim[ HoldPattern ][ lhs_ ] ] := HoldPattern @ lhs;
ensureHoldPattern[ lhs_ ] := HoldPattern @ lhs;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*SnapshotDefinitions and RestoreDefinitions*)
(* For overrides that must span several tool calls (prefer WithOverrides). Language`ExtendedDefinition returns an
   empty DefinitionList for ReadProtected symbols, so the value lists are saved instead. *)
$snapshotKeys = { "OwnValues", "DownValues", "UpValues", "SubValues", "NValues", "FormatValues", "DefaultValues", "Messages", "Attributes" };

SnapshotDefinitions // Attributes = { HoldFirst };

SnapshotDefinitions[ s_Symbol ] /; ! lockedQ @ s := <|
    "Symbol"        -> fullSymbolName @ s,
    "OwnValues"     -> OwnValues @ s,
    "DownValues"    -> DownValues @ s,
    "UpValues"      -> UpValues @ s,
    "SubValues"     -> SubValues @ s,
    "NValues"       -> NValues @ s,
    "FormatValues"  -> FormatValues @ s,
    "DefaultValues" -> DefaultValues @ s,
    "Messages"      -> Messages @ s,
    "Attributes"    -> Attributes @ s
|>;

SnapshotDefinitions[ args___ ] := badCall[ SnapshotDefinitions, HoldComplete @ args ];

RestoreDefinitions // Attributes = { HoldFirst };

RestoreDefinitions[ s_Symbol, d_Association ] /; ! lockedQ @ s && SubsetQ[ Keys @ d, $snapshotKeys ] && d[ "Symbol" ] === fullSymbolName @ s := (
    Unprotect @ s;
    ClearAttributes[ s, ReadProtected ];
    OwnValues[ s ]     = d[ "OwnValues" ];
    DownValues[ s ]    = d[ "DownValues" ];
    UpValues[ s ]      = d[ "UpValues" ];
    SubValues[ s ]     = d[ "SubValues" ];
    NValues[ s ]       = d[ "NValues" ];
    FormatValues[ s ]  = d[ "FormatValues" ];
    DefaultValues[ s ] = d[ "DefaultValues" ];
    Messages[ s ]      = d[ "Messages" ];
    Attributes[ s ]    = d[ "Attributes" ];
    SnapshotDefinitions @ s === d
);

RestoreDefinitions[ args___ ] := badCall[ RestoreDefinitions, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Watchpoints and Probes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WatchChanges*)
(* Internal`SetValueMonitor + a "ValueChange" handler. The monitor flag survives ClearAll, so the previous state is
   always restored. Events: HoldComplete[x, old, new, OwnValues], HoldComplete[x, x[[1]], 5, Part], HoldComplete[x, Clear],
   definitions (DownValues), Block enter/exit. *)
WatchChanges // Attributes = { HoldAll };

defineOptions[ WatchChanges, {
    { "MaxEvents", 20 , nonNegativeIntegerQ, "a non-negative integer" },
    { "MaxLength", 160, positiveIntegerQ   , "a positive integer" },
    $resultOptionSpec
} ];

WatchChanges[ s_Symbol, expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ WatchChanges, { opts } ] := WatchChanges[ { s }, expr, opts ];

WatchChanges[ syms: { __Symbol }, expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ WatchChanges, { opts } ] :=
    Module[ { o, bag, n, prev, res },
        o    = optionsAssociation[ WatchChanges, { opts } ];
        bag  = Internal`Bag[ ];
        n    = 0;
        prev = Internal`GetValueMonitor @ syms;
        res  = Internal`WithLocalSettings[
            Internal`SetValueMonitor[ syms, True ],
            Internal`HandlerBlock[
                (* only the first MaxEvents events are formatted and stored; the rest are counted *)
                {
                    "ValueChange",
                    Function[ ev,
                        If[ ++n <= o[ "MaxEvents" ],
                            Internal`StuffBag[ bag, <| "Event" -> eventString[ ev, o[ "MaxLength" ] ], "Callers" -> callerNames[ ] |> ]
                        ]
                    ]
                },
                evaluateContained @ StackBegin @ StackComplete @ expr
            ],
            Internal`SetValueMonitor[ syms, prev ]
        ];
        <| "Result" -> boundedResult[ res, o[ "MaxResultBytes" ] ], "Count" -> n, "Changes" -> Internal`BagPart[ bag, All ] |>
    ];

WatchChanges[ args___ ] := badCall[ WatchChanges, HoldComplete @ args ];

eventString[ HoldComplete[ e___ ], n_Integer ] := "HoldComplete[" <> heldString[ HoldComplete @ e, n - 14 ] <> "]";
eventString[ other_, n_Integer ] := heldString[ HoldComplete @ other, n ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*StopWhen*)
StopWhen // Attributes = { HoldAll };

defineOptions[ StopWhen, {
    { "MaxFrames", 15 , positiveIntegerQ, "a positive integer" },
    { "MaxLength", 120, positiveIntegerQ, "a positive integer" },
    $resultOptionSpec
} ];

StopWhen[ sym_Symbol, test_, expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ StopWhen, { opts } ] :=
    Module[ { o, tag, prev, res },
        o    = optionsAssociation[ StopWhen, { opts } ];
        prev = Internal`GetValueMonitor @ sym;
        res  = evaluateContained @ Catch[
            Internal`WithLocalSettings[
                Internal`SetValueMonitor[ sym, True ],
                Internal`HandlerBlock[
                    {
                        "ValueChange",
                        Function[ ev,
                            Replace[
                                ev,
                                HoldComplete[ _, _, new_, OwnValues ] /; TrueQ @ test @ new :>
                                    Throw[ stoppedEvent[ eventString[ ev, o[ "MaxLength" ] ], stopStack[ Stack[ _ ], o ] ], tag ]
                            ]
                        ]
                    },
                    StackBegin @ StackComplete @ expr
                ],
                Internal`SetValueMonitor[ sym, prev ]
            ],
            tag
        ];
        Replace[
            res,
            {
                HoldComplete[ stoppedEvent[ ev_, st_ ] ] :> <| "Stopped" -> True, "Event" -> ev, "Stack" -> st |>,
                other_ :> <| "Stopped" -> False, "Result" -> boundedResult[ other, o[ "MaxResultBytes" ] ] |>
            }
        ]
    ];

StopWhen[ args___ ] := badCall[ StopWhen, HoldComplete @ args ];

(* the user-level frames at the assignment; when there are none (only System` code involved), the last frames *)
stopStack[ frames_List, o_Association ] :=
    Module[ { fr, user },
        (* the handler's own frames (from Function[ev, ...][...] on) mention stoppedEvent *)
        fr   = DeleteCases[ TakeWhile[ frames, FreeQ[ #, stoppedEvent ] & ], _?wrapperFrameQ ];
        user = Select[ fr, userCodeContextQ @ frameContext @ # & ];
        frameStrings[ If[ user === { }, fr, user ], If[ user === { }, Min[ 5, o[ "MaxFrames" ] ], o[ "MaxFrames" ] ], o[ "MaxLength" ] ]
    ];

userCodeContextQ[ c_String ] := ! MatchQ[ c, $systemContexts ] && ! StringMatchQ[ c, $packageContextPattern ];
userCodeContextQ[ _ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*NewSymbolsDuring*)
(* "NewSymbol" handler: only symbols created at run time (ToExpression, Symbol, Get, ...), not those of the input *)
NewSymbolsDuring // Attributes = { HoldFirst };

defineOptions[ NewSymbolsDuring, { { "MaxSymbols", 50, positiveIntegerQ, "a positive integer" }, $resultOptionSpec } ];

NewSymbolsDuring[ expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ NewSymbolsDuring, { opts } ] :=
    Module[ { o, bag, res, all },
        o   = optionsAssociation[ NewSymbolsDuring, { opts } ];
        bag = Internal`Bag[ ];
        res = Internal`HandlerBlock[ { "NewSymbol", Internal`StuffBag[ bag, #[[ 2 ]] <> #[[ 1 ]] ] & }, evaluateContained @ expr ];
        all = DeleteDuplicates @ Internal`BagPart[ bag, All ];
        <|
            "Result"     -> boundedResult[ res, o[ "MaxResultBytes" ] ],
            "Count"      -> Length @ all,
            "NewSymbols" -> Take[ all, UpTo[ o[ "MaxSymbols" ] ] ]
        |>
    ];

NewSymbolsDuring[ args___ ] := badCall[ NewSymbolsDuring, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FileWritesDuring*)
(* "Wolfram.File.OpenWrite" handler: a notification for every file opened for writing (OpenWrite, OpenAppend, ...) *)
FileWritesDuring // Attributes = { HoldFirst };

defineOptions[ FileWritesDuring, { { "MaxFiles", 50, positiveIntegerQ, "a positive integer" }, $resultOptionSpec } ];

FileWritesDuring[ expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ FileWritesDuring, { opts } ] :=
    Module[ { o, bag, res, all },
        o   = optionsAssociation[ FileWritesDuring, { opts } ];
        bag = Internal`Bag[ ];
        res = Internal`HandlerBlock[ { "Wolfram.File.OpenWrite", Internal`StuffBag[ bag, writeRecord @ # ] & }, evaluateContained @ expr ];
        all = DeleteDuplicates @ Internal`BagPart[ bag, All ];
        <|
            "Result" -> boundedResult[ res, o[ "MaxResultBytes" ] ],
            "Count"  -> Length @ all,
            "Writes" -> Take[ all, UpTo[ o[ "MaxFiles" ] ] ]
        |>
    ];

FileWritesDuring[ args___ ] := badCall[ FileWritesDuring, HoldComplete @ args ];

writeRecord[ ( _ )[ f_Symbol, file_String, ___ ] ] := { SymbolName @ f, file };
writeRecord[ other_ ] := { heldString[ HoldComplete @ other, 200 ] };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*CapturePrints*)
(* Block[{Print = ...}] is the only method that hides Print output in every environment (a "Print.Veto" handler
   works only in wolframscript and the MCP Local method). Echo prints through Print. *)
CapturePrints // Attributes = { HoldFirst };

defineOptions[ CapturePrints, { { "MaxLength", 200, positiveIntegerQ, "a positive integer" }, $resultOptionSpec } ];

CapturePrints[ expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ CapturePrints, { opts } ] :=
    capturePrints[ HoldComplete @ expr, 20, { opts } ];

CapturePrints[ expr_, max_? positiveIntegerQ, opts: OptionsPattern[ ] ] /; validOptionsQ[ CapturePrints, { opts } ] :=
    capturePrints[ HoldComplete @ expr, max, { opts } ];

CapturePrints[ args___ ] := badCall[ CapturePrints, HoldComplete @ args ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
capturePrints[ HoldComplete[ expr_ ], max_Integer, opts_List ] :=
    Module[ { o, bag, n, res },
        o   = optionsAssociation[ CapturePrints, opts ];
        bag = Internal`Bag[ ];
        n   = 0;
        res = Block[
            {
                Print = Function[
                    Null,
                    If[ ++n <= max, Internal`StuffBag[ bag, truncateString[ StringJoin[ ToString /@ { ## } ], o[ "MaxLength" ] ] ] ],
                    HoldAllComplete
                ]
            },
            evaluateContained @ expr
        ];
        <| "Result" -> boundedResult[ res, o[ "MaxResultBytes" ] ], "PrintCount" -> n, "Prints" -> Internal`BagPart[ bag, All ] |>
    ];
(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FailedAssertions*)
(* the "Assertions" handler receives HoldComplete[Assert[test, {line, file}]] for every failed Assert, even when
   Assert is Off (line and file are present when the code was loaded with Get) *)
FailedAssertions // Attributes = { HoldFirst };

defineOptions[ FailedAssertions, { { "MaxAssertions", 20, positiveIntegerQ, "a positive integer" }, $resultOptionSpec } ];

FailedAssertions[ expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ FailedAssertions, { opts } ] :=
    Module[ { o, bag, n, res },
        o   = optionsAssociation[ FailedAssertions, { opts } ];
        bag = Internal`Bag[ ];
        n   = 0;
        res = Internal`HandlerBlock[
            { "Assertions", If[ ++n <= o[ "MaxAssertions" ], Internal`StuffBag[ bag, assertionRecord @ # ] ] & },
            evaluateContained @ StackBegin @ StackComplete @ expr
        ];
        <| "Result" -> boundedResult[ res, o[ "MaxResultBytes" ] ], "Count" -> n, "Failed" -> Internal`BagPart[ bag, All ] |>
    ];

FailedAssertions[ args___ ] := badCall[ FailedAssertions, HoldComplete @ args ];

assertionRecord[ HoldComplete[ Assert[ test_, { line_Integer, file_String }, ___ ] ] ] := <|
    "Assert"  -> heldString[ HoldComplete @ test, 150 ],
    "Line"    -> line,
    "File"    -> file,
    "Callers" -> callerNames[ ]
|>;
assertionRecord[ HoldComplete[ Assert[ test_, ___ ] ] ] := <| "Assert" -> heldString[ HoldComplete @ test, 150 ], "Callers" -> callerNames[ ] |>;
assertionRecord[ other_ ] := <| "Assert" -> heldString[ HoldComplete @ other, 150 ], "Callers" -> callerNames[ ] |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LeakCheck*)
LeakCheck // Attributes = { HoldFirst };

defineOptions[ LeakCheck, { $resultOptionSpec } ];

LeakCheck[ expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ LeakCheck, { opts } ] := leakCheck[ HoldComplete @ expr, 5, { opts } ];

LeakCheck[ expr_, max_? positiveIntegerQ, opts: OptionsPattern[ ] ] /; validOptionsQ[ LeakCheck, { opts } ] :=
    leakCheck[ HoldComplete @ expr, max, { opts } ];

LeakCheck[ args___ ] := badCall[ LeakCheck, HoldComplete @ args ];

leakCheck[ HoldComplete[ expr_ ], max_Integer, opts_List ] :=
    Module[ { o, before, after, new, temps, m0, m1, res },
        o      = optionsAssociation[ LeakCheck, opts ];
        before = Names[ "*`*" ];
        m0     = MemoryInUse[ ];
        res    = evaluateContained @ expr;
        m1     = MemoryInUse[ ];
        after  = Names[ "*`*" ];
        new    = Complement[ after, before ];
        temps  = Select[ new, StringMatchQ[ #, __ ~~ "$" ~~ DigitCharacter .. ] & ];
        <|
            "Result"             -> boundedResult[ res, o[ "MaxResultBytes" ] ],
            "MemoryDelta"        -> m1 - m0,
            "NewSymbols"         -> Length @ new,
            "NewTemporaries"     -> Length @ temps,
            "TemporariesByName"  -> Take[ ReverseSort @ Counts @ StringReplace[ temps, "$" ~~ DigitCharacter .. ~~ EndOfString -> "$*" ], UpTo[ 10 ] ],
            "LargestTemporaries" -> TakeLargestBy[
                Map[
                    { #, ToExpression[ #, InputForm, Function[ s, ByteCount @ { OwnValues @ s, DownValues @ s, SubValues @ s, UpValues @ s }, HoldAllComplete ] ] } &,
                    temps
                ],
                Last,
                UpTo[ max ]
            ],
            "OtherNewSymbols"    -> Take[ Complement[ new, temps ], UpTo[ max ] ]
        |>
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Unevaluated Calls*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WhyNoMatch*)
(* WhyNoMatch evaluates the arguments once like the evaluator (Hold attributes, Sequence, Flat, Listable, Orderless),
   then runs the kernel's own matcher on each rule with the tests and conditions instrumented (recording what they
   gave). No rule body is evaluated and the definitions are not changed. Works without Trace. *)
WhyNoMatch // Attributes = { HoldFirst };

defineOptions[ WhyNoMatch, {
    { "EvaluateArguments", True, booleanQ           , "True or False" },
    { "MaxRules"         , 12  , nonNegativeIntegerQ, "a non-negative integer" },
    { "MaxLength"        , 110 , positiveIntegerQ   , "a positive integer" },
    { "Hints"            , True, booleanQ           , "True or False" }
} ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::ShadowedVariable::Block:: *)
WhyNoMatch[ expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ WhyNoMatch, { opts } ] :=
    Block[ { $fmtLength = OptionValue[ "MaxLength" ], $extraContexts = { } },
        Replace[
            (* argument evaluation and rule conditions run user code: contain Throw/Abort *)
            evaluateContained @ whyNoMatch[ HoldComplete @ expr, optionsAssociation[ WhyNoMatch, { opts } ], 0 ],
            {
                HoldComplete[ a_Association ] :> cleanup @ a,
                HoldComplete[ other_ ] :> <| "Summary" -> "the analysis was interrupted: " <> ShortString[ other, 200 ] |>
            }
        ]
    ];
(* :!CodeAnalysis::EndBlock:: *)

WhyNoMatch[ args___ ] := badCall[ WhyNoMatch, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Constants and Formatting*)
cnd // Attributes = { HoldAllComplete };
ptst // Attributes = { HoldAllComplete };
recCond // Attributes = { HoldAll };

(* characters per formatted expression (option "MaxLength"); rule contexts go to $extraContexts *)
$fmtLength = 110;

fmt[ h_HoldComplete ] := heldString[ h, $fmtLength ];
fmt[ h_HoldComplete, n_Integer ] := heldString[ h, n ];

(* early exits from the analysis functions *)
catchReturn // Attributes = { HoldFirst };
catchReturn[ body_ ] := Catch[ body, $returnTag ];
earlyReturn[ value_ ] := Throw[ value, $returnTag ];

heldList[ h_HoldComplete ] := List @@ ( HoldComplete /@ h );
hp[ HoldComplete[ s_ ] ] := HoldPattern @ s;   (* a held symbol as a literal pattern, never evaluated *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Symbol Information*)
(* all HoldFirst: never evaluate the symbol *)
defCounts // Attributes = { HoldFirst };
otherContexts // Attributes = { HoldFirst };
didYouMean // Attributes = { HoldFirst };

defCounts[ s_Symbol ] := DeleteCases[
    <|
        "OwnValues"  -> Length @ Quiet @ OwnValues @ s,
        "DownValues" -> Length @ Quiet @ DownValues @ s,
        "SubValues"  -> Length @ Quiet @ SubValues @ s,
        "UpValues"   -> Length @ Quiet @ UpValues @ s
    |>,
    0
];

(* Other symbols with the same short name, e.g. Global`f vs MyPkg`f, with their definition counts *)
otherContexts[ s_Symbol ] := Module[ { me = fullSymbolName @ s, names },
    names = Names[ "*`" <> SymbolName @ Unevaluated @ s ];
    names = DeleteDuplicates[ If[ StringContainsQ[ #, "`" ], #, Context[ # ] <> # ] & /@ names ];
    names = DeleteCases[ names, me ];
    (* only the ones that have definitions (or are autoload stubs) matter *)
    names = Select[ names, ! StringEndsQ[ descCounts @ ToExpression[ #, InputForm, HoldComplete ], "(no definitions)" ] & ];
    Map[ # <> " " <> descCounts @ ToExpression[ #, InputForm, HoldComplete ] &, Take[ names, UpTo[ 5 ] ] ]
];

descCounts[ HoldComplete[ s_Symbol ] ] := With[ { c = defCounts @ s },
    Which[
        autoloadStubQ @ s, "(autoload stub)",
        c === <| |> && System`Private`HasAnyEvaluationsQ @ s, "(kernel code)",
        c === <| |>, "(no definitions)",
        True, "(" <> StringRiffle[ KeyValueMap[ ToString[ #2 ] <> " " <> #1 &, c ], ", " ] <> ")"
    ]
];

(* Similar names (typos, case) that DO have definitions; searched in $Context, Global` and $ContextPath *)
didYouMean[ s_Symbol ] := catchReturn @ Module[ { name = SymbolName @ Unevaluated @ s, me = fullSymbolName @ s, ctxs, cands, lname },
    lname = ToLowerCase @ name;
    If[ StringLength @ name < 3, earlyReturn @ { } ];
    ctxs = DeleteDuplicates @ Join[ { $Context, "Global`" }, $ContextPath ];
    cands = DeleteDuplicates @ Flatten[ Names[ # <> "*" ] & /@ ctxs ];
    cands = Select[ cands,
        Function[ c,
            With[ { short = Last @ StringSplit[ c, "`" ] },
                short =!= name && Abs[ StringLength @ short - StringLength @ name ] <= 2 &&
                EditDistance[ ToLowerCase @ short, lname ] <= If[ StringLength @ name < 6, 1, 2 ]
            ]
        ]
    ];
    cands = Select[ cands, ToExpression[ #, InputForm, System`Private`HasAnyEvaluationsQ ] & ];
    cands = SortBy[ cands, EditDistance[ ToLowerCase @ Last @ StringSplit[ #, "`" ], lname ] & ];
    DeleteCases[ If[ StringContainsQ[ #, "`" ], #, Context[ # ] <> # ] & /@ Take[ cands, UpTo[ 3 ] ], me ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Argument Normalization*)

heldPosQ[ attrs_, i_ ] :=
    MemberQ[ attrs, HoldAll | HoldAllComplete ] ||
    ( i === 1 && MemberQ[ attrs, HoldFirst ] ) ||
    ( i > 1 && MemberQ[ attrs, HoldRest ] );

evalArg[ HoldComplete[ x_ ], "HAC" ] := HoldComplete @ x;
evalArg[ HoldComplete[ Evaluate[ x_ ] ], "Held" ] := With[ { v = x }, HoldComplete @ v ];
evalArg[ HoldComplete[ x_ ], "Held" ] := HoldComplete @ x;
evalArg[ HoldComplete[ Unevaluated[ x_ ] ], "Eval" ] := HoldComplete @ x;
evalArg[ HoldComplete[ x_ ], "Eval" ] := With[ { v = x }, HoldComplete @ v ];

evalArgs[ args_HoldComplete, attrs_ ] := With[ { hac = MemberQ[ attrs, HoldAllComplete ] },
    Join @@ Prepend[
        MapIndexed[ evalArg[ #1, Which[ hac, "HAC", heldPosQ[ attrs, First @ #2 ], "Held", True, "Eval" ] ] &, heldList @ args ],
        HoldComplete[ ]
    ]
];

(* normalizeCall[HoldComplete[f[args]], evalQ] -> {HoldComplete[f[args']], notes, flag}.
   Evaluates arguments per attributes, splices Sequence, flattens Flat, threads Listable, sorts Orderless. *)
normalizeCall[ HoldComplete[ h_Symbol[ args___ ] ], evalQ_ ] := catchReturn @ Module[
    { attrs = Attributes @ h, notes = { }, argsH, list, lens, listPos, heldNonAtoms },
    list = heldList @ HoldComplete @ args;
    argsH = If[ TrueQ @ evalQ, evalArgs[ HoldComplete @ args, attrs ], HoldComplete @ args ];
    If[ TrueQ @ evalQ && MemberQ[ attrs, HoldAll | HoldFirst | HoldRest | HoldAllComplete ],
        heldNonAtoms = Select[
            MapIndexed[ { First @ #2, #1 } &, list ],
            heldPosQ[ attrs, First @ # ] && ! MatchQ[ Last @ #, HoldComplete[ x_ /; AtomQ @ Unevaluated @ x ] | HoldComplete[ Evaluate[ _ ] ] ] &
        ];
        If[ heldNonAtoms =!= { },
            AppendTo[ notes, "argument(s) kept unevaluated by Hold attributes: " <>
                StringRiffle[ ( "#" <> ToString @ First @ # <> " " <> fmt[ Last @ #, 40 ] & ) /@ Take[ heldNonAtoms, UpTo[ 3 ] ], ", " ] ]
        ]
    ];
    If[ ! MemberQ[ attrs, HoldAllComplete | SequenceHold ] && ! FreeQ[ argsH, _Sequence, { 1 } ],
        argsH = Flatten[ argsH, 1, Sequence ];
        AppendTo[ notes, "Sequence[...] argument(s) spliced" ]
    ];
    If[ MemberQ[ attrs, Flat ] && ! FreeQ[ argsH, Blank[ h ], { 1 } ],
        argsH = Flatten[ argsH, Infinity, h ];
        AppendTo[ notes, "Flat: nested " <> SymbolName @ Unevaluated @ h <> "[...] flattened" ]
    ];
    If[ MemberQ[ attrs, Listable ],
        listPos = Flatten @ Position[ heldList @ argsH, HoldComplete[ _List ], { 1 }, Heads -> False ];
        If[ listPos =!= { },
            lens = DeleteDuplicates @ Replace[ heldList[ argsH ][[ listPos ]], HoldComplete[ l_ ] :> Length @ Unevaluated @ l, { 1 } ];
            Which[
                Length @ lens > 1,
                    AppendTo[ notes, "Listable with list arguments of unequal lengths " <> ToString @ lens <>
                        ": Thread::tdlen is issued and the rules are then tried on the unthreaded call" ],
                lens === { 0 },
                    earlyReturn @ { Replace[ argsH, HoldComplete[ a___ ] :> HoldComplete @ h @ a ],
                        Append[ notes, "Listable with empty list argument(s): the result is {} and no rule is tried" ], "empty" },
                True,
                    argsH = Join @@ Prepend[
                        MapIndexed[ If[ MemberQ[ listPos, First @ #2 ], Replace[ #1, HoldComplete[ { x_, ___ } ] :> HoldComplete @ x ], #1 ] &, heldList @ argsH ],
                        HoldComplete[ ]
                    ];
                    AppendTo[ notes, "Listable: the call threads over lists of length " <> ToString @ First @ lens <> "; diagnosing the first element" ]
            ]
        ]
    ];
    If[ MemberQ[ attrs, Flat ] && ! MemberQ[ attrs, OneIdentity ],
        AppendTo[ notes, "Flat without OneIdentity: a pattern variable may bind " <> SymbolName @ Unevaluated @ h <> "[a] instead of a" ]
    ];
    If[ MemberQ[ attrs, Orderless ],
        With[ { sorted = Sort @ argsH },
            If[ sorted =!= argsH, AppendTo[ notes, "Orderless: arguments sorted into canonical order" ] ];
            argsH = sorted
        ]
    ];
    { Replace[ argsH, HoldComplete[ a___ ] :> HoldComplete @ h @ a ], notes, None }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Rules*)

$$patternHeads = Blank | BlankSequence | BlankNullSequence | Pattern | Condition | PatternTest | Alternatives |
    Optional | Repeated | RepeatedNull | Except | OptionsPattern | KeyValuePattern | PatternSequence |
    OrderlessPatternSequence | Verbatim | Longest | Shortest | HoldPattern | StringExpression | RegularExpression;

splitRule[ ( RuleDelayed | Rule )[ Verbatim[ HoldPattern ][ l_ ], r_ ] ] := { HoldComplete @ l, HoldComplete @ r };
splitRule[ ( RuleDelayed | Rule )[ l_, r_ ] ] := { HoldComplete @ l, HoldComplete @ r };

literalQ[ h_HoldComplete ] := FreeQ[ h, $$patternHeads, Heads -> True ];

(* LHS without its top-level condition *)
lhsCore[ HoldComplete[ Verbatim[ Condition ][ l_, _ ] ] ] := lhsCore @ HoldComplete @ l;
lhsCore[ HoldComplete[ Verbatim[ HoldPattern ][ l_ ] ] ] := lhsCore @ HoldComplete @ l;
lhsCore[ HoldComplete[ Verbatim[ Pattern ][ _, l_ ] ] ] := lhsCore @ HoldComplete @ l;  (* e : f[...] (e.g. from endDefinition) *)
lhsCore[ h_ ] := h;

(* structural version: no conditions, no pattern tests *)
(* (tests inside Except[...] are kept: stripping them would invert the meaning) *)
stripLHS[ h_HoldComplete ] := ReplaceRepeated[ h, { e_Except :> e, Verbatim[ Condition ][ p_, _ ] :> p, Verbatim[ PatternTest ][ p_, _ ] :> p } ];

(* Instrumented conditions and pattern tests: the kernel's own matcher records each evaluation *)
recCond[ k_, c_ ] := With[ { r = c },
    If[ $nRec++ < 40, Internal`StuffBag[ $records, { k, HoldComplete @ c, HoldComplete @ r } ] ];
    r
];
recTest[ k_, t_ ] := Function[ Null,
    With[ { r = t[ # ] },
        If[ $nRec++ < 40, Internal`StuffBag[ $records, { k, HoldComplete @ t @ #, HoldComplete @ r } ] ];
        r
    ],
    HoldAllComplete
];

instrumentLHS[ h_HoldComplete ] := Module[ { k = 0 },
    ReplaceRepeated[
        h,
        {
            e_Except :> e,  (* not inside Except: a failing test there means a successful match *)
            Verbatim[ Condition ][ p_, c_ ] :> RuleCondition @ With[ { i = ++k }, cnd[ p, recCond[ { "condition", i }, c ] ] ],
            Verbatim[ PatternTest ][ p_, t_ ] :> RuleCondition @ With[ { i = ++k }, ptst[ p, recTest[ { "test", i }, t ] ] ]
        }
    ] /. { cnd -> Condition, ptst -> PatternTest }
];

(* RHS conditions: body /; cond directly, or as the (last statement of the) body of Module/With/Block, nested *)
rhsCondition[ HoldComplete[ Verbatim[ Condition ][ _, c_ ] ] ] := HoldComplete @ cnd[ $hit, recCond[ { "RHS condition", 0 }, c ] ];
rhsCondition[ HoldComplete[ ( s : Module | With | Block )[ v_, b_ ] ] ] :=
    Replace[ rhsCondition @ HoldComplete @ b, HoldComplete[ nb_ ] :> HoldComplete @ s[ v, nb ] ];
rhsCondition[ HoldComplete[ CompoundExpression[ pre___, last_ ] ] ] :=
    Replace[ rhsCondition @ HoldComplete @ last, HoldComplete[ nl_ ] :> HoldComplete @ CompoundExpression[ pre, nl ] ];
rhsCondition[ _ ] := None;

markerRHS[ r_HoldComplete ] := Replace[ rhsCondition @ r, None -> HoldComplete @ $hit ] /. cnd -> Condition;

mkRule[ HoldComplete[ l_ ], HoldComplete[ r_ ] ] := RuleDelayed @@ HoldComplete[ HoldPattern @ l, r ];

(* Run the kernel's matcher on the instrumented rule. Returns {hitQ, records, messageNames}. *)
runMatch[ HoldComplete[ call_ ], rule_, flat_ : False ] := Module[ { res, msgs = { } },
    Block[ { $records = Internal`Bag[ ], $nRec = 0 },
        res = Internal`HandlerBlock[
            { "Message", Function[ m, If[ Length @ msgs < 4, AppendTo[ msgs, messageNameString @ m ] ] ] },
            Quiet @ If[ TrueQ @ flat,
                (* Flat heads: the evaluator also applies rules to subsequences, like ReplaceAll *)
                If[ FreeQ[ ReplaceAll[ HoldComplete @ call, rule ], $hit ], $miss, $hit ],
                Replace[ Unevaluated @ call, { rule, _ :> $miss } ]
            ]
        ];
        { res === $hit, Internal`BagPart[ $records, All ], DeleteDuplicates @ msgs }
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Structural Mismatches*)

arity[ HoldComplete[ p_ ] ] := arity0 @ p;
arity0 // Attributes = { HoldAllComplete };
arity0[ Verbatim[ Pattern ][ _, q_ ] ] := arity0 @ q;
arity0[ Verbatim[ Condition ][ q_, _ ] ] := arity0 @ q;
arity0[ Verbatim[ PatternTest ][ q_, _ ] ] := arity0 @ q;
arity0[ Verbatim[ HoldPattern ][ q_ ] ] := arity0 @ q;
arity0[ ( Verbatim[ Longest ] | Verbatim[ Shortest ] )[ q_, ___ ] ] := arity0 @ q;
arity0[ Verbatim[ Blank ][ ___ ] ] := { 1, 1 };
arity0[ Verbatim[ BlankSequence ][ ___ ] ] := { 1, Infinity };
arity0[ Verbatim[ BlankNullSequence ][ ___ ] ] := { 0, Infinity };
arity0[ Verbatim[ OptionsPattern ][ ___ ] ] := { 0, Infinity };
arity0[ Verbatim[ Optional ][ q_, ___ ] ] := { 0, Last @ arity0 @ q };
arity0[ Verbatim[ Repeated ][ q_, ___ ] ] := { First @ arity0 @ q, Infinity };
arity0[ Verbatim[ RepeatedNull ][ ___ ] ] := { 0, Infinity };
arity0[ ( Verbatim[ PatternSequence ] | Verbatim[ OrderlessPatternSequence ] )[ qs___ ] ] :=
    Total[ Prepend[ List @@ ( arity0 /@ HoldComplete @ qs ), { 0, 0 } ] ];
arity0[ Verbatim[ Alternatives ][ qs___ ] ] := With[ { a = List @@ ( arity0 /@ HoldComplete @ qs ) }, { Min @ a[[ All, 1 ]], Max @ a[[ All, 2 ]] } ];
arity0[ _ ] := { 1, 1 };

arityString[ { min_, max_ } ] := Which[
    min === max, ToString @ min,
    max === Infinity, ToString @ min <> " or more",
    True, ToString @ min <> " to " <> ToString @ max
];

optionLikeQ[ HoldComplete[ ( Rule | RuleDelayed )[ _, _ ] ] ] := True;
optionLikeQ[ HoldComplete[ l_List ] ] := MatchQ[ Unevaluated @ l, { ( _Rule | _RuleDelayed ) ... } ];
optionLikeQ[ _ ] := False;

patternNames[ h_HoldComplete ] := Cases[ h, Verbatim[ Pattern ][ n_Symbol, _ ] :> HoldComplete @ n, { 0, Infinity } ];

(* the one head a pattern requires, e.g. x_Integer -> Integer, {__} -> List *)
headOfPattern[ HoldComplete[ Verbatim[ Pattern ][ _, q_ ] ] ] := headOfPattern @ HoldComplete @ q;
headOfPattern[ HoldComplete[ Verbatim[ Blank ][ h_Symbol ] ] ] := h;
headOfPattern[ HoldComplete[ _List ] ] := List;
headOfPattern[ _ ] := None;

typeHint[ arg_HoldComplete, pat_HoldComplete ] := Module[ { ph = headOfPattern @ pat, ah },
    ah = Replace[ arg, HoldComplete[ x_ ] :> Head @ Unevaluated @ x ];
    Which[
        ph === None || ph === ah, "",
        ph === List && Replace[ arg, HoldComplete[ x_ ] :> AtomQ @ Unevaluated @ x ] && ! MemberQ[ { Symbol, Integer, Real, Rational, Complex, String }, ah ],
            " (head " <> ToString @ ah <> ": an atomic object, not a List; use _" <> ToString @ ah <> " or Normal)",
        True, " (head " <> ToString @ ah <> ", pattern needs " <> ToString @ ph <> ")"
    ]
];

(* KeyValuePattern detail: which key is missing or has the wrong value *)
kvpWhy[ a_HoldComplete, HoldComplete[ Verbatim[ Pattern ][ _, q_ ] ] ] := kvpWhy[ a, HoldComplete @ q ];
kvpWhy[ HoldComplete[ a_ ], HoldComplete[ Verbatim[ KeyValuePattern ][ spec_ ] ] ] := catchReturn @ Module[ { rules, assoc },
    assoc = Quiet @ Association @ a;
    If[ ! AssociationQ @ assoc, earlyReturn[ " (not an Association or list of rules)" ] ];
    rules = If[ MatchQ[ HoldComplete @ spec, HoldComplete[ _List ] ],
        heldList[ HoldComplete @@ Unevaluated @ spec ],
        { HoldComplete @ spec }
    ];
    StringJoin @ Replace[
        rules,
        {
            HoldComplete[ ( Rule | RuleDelayed )[ k_, vp_ ] ] /; FreeQ[ HoldComplete @ k, $$patternHeads, Heads -> True ] :>
                Which[
                    ! KeyExistsQ[ assoc, k ], "; key " <> fmt[ HoldComplete @ k, 30 ] <> " is missing",
                    ! MatchQ[ assoc @ k, vp ], "; key " <> fmt[ HoldComplete @ k, 30 ] <> ": " <> fmt[ HoldComplete @@ { assoc @ k }, 40 ] <>
                        " does not match " <> fmt[ HoldComplete @ vp, 40 ],
                    True, ""
                ],
            _ -> ""
        },
        { 1 }
    ]
];
kvpWhy[ _, _ ] := "";

(* positional diagnosis of a structural mismatch (conditions and tests already stripped) *)
positionWhy[ HoldComplete[ call_ ], HoldComplete[ pat_ ], attrs_, depth_ : 0 ] := catchReturn @ Module[
    { a, p, n, ar, min, max, i, j, k, names, dup, hc, hp0, seqIdx },
    If[ AtomQ @ Unevaluated @ pat || AtomQ @ Unevaluated @ call,
        earlyReturn[ fmt[ HoldComplete @ call, 50 ] <> " does not match " <> fmt[ HoldComplete @ pat, 50 ] ]
    ];
    (* compound heads (f[a][b] vs f[a_][b_]): check the head part first *)
    hc = Replace[ HoldComplete @ call, HoldComplete[ h_[ ___ ] ] :> HoldComplete @ h ];
    hp0 = Replace[ HoldComplete @ pat, HoldComplete[ h_[ ___ ] ] :> HoldComplete @ h ];
    If[ ! AtomQ @@ hp0 && ! MatchQ[ hc, hp0 ],
        earlyReturn[ "in the head " <> fmt[ hc, 40 ] <> ": " <> positionWhy[ hc, hp0, { }, depth ] ]
    ];
    If[ depth === 0 && MemberQ[ attrs, Orderless | Flat ],
        earlyReturn[ "no match (" <> StringRiffle[ ToString /@ Intersection[ attrs, { Flat, Orderless, OneIdentity } ], "/" ] <>
            " head: arguments are tried in every order/grouping)" ]
    ];
    a = heldList[ HoldComplete @@ Unevaluated @ call ];
    p = heldList[ HoldComplete @@ Unevaluated @ pat ];
    n = Length @ a;
    ar = arity /@ p;
    { min, max } = If[ ar === { }, { 0, 0 }, { Total @ ar[[ All, 1 ]], Total @ ar[[ All, 2 ]] } ];
    If[ n < min || n > max,
        earlyReturn[ If[ depth === 0, "the call has ", "it has " ] <> ToString @ n <> " argument(s), the pattern takes " <> arityString @ { min, max } <>
            If[ n > max && AllTrue[ a[[ max + 1 ;; ]], optionLikeQ ], " (the extra ones are rules: add OptionsPattern[] or ___ to accept options)", "" ] ]
    ];
    (* :!CodeAnalysis::BeginBlock:: *)
    (* :!CodeAnalysis::Disable::For:: *)
    (* prefix positions with fixed arity 1 *)
    For[ i = 1, i <= Min[ n, Length @ p ] && ar[[ i ]] === { 1, 1 }, i++,
        If[ ! MatchQ[ a[[ i ]], p[[ i ]] ], earlyReturn[ argWhy[ i, a[[ i ]], p[[ i ]], depth ] ] ]
    ];
    (* suffix positions with fixed arity 1 *)
    For[ j = 0, j < Min[ n, Length @ p ] - i + 1 && ar[[ -1 - j ]] === { 1, 1 }, j++,
        If[ ! MatchQ[ a[[ -1 - j ]], p[[ -1 - j ]] ], earlyReturn[ argWhy[ n - j, a[[ -1 - j ]], p[[ -1 - j ]], depth ] ] ]
    ];
    (* :!CodeAnalysis::EndBlock:: *)
    (* trailing OptionsPattern[] with non-option arguments *)
    If[ MatchQ[ Last[ p, None ], HoldComplete[ Verbatim[ OptionsPattern ][ ___ ] | Verbatim[ Pattern ][ _, Verbatim[ OptionsPattern ][ ___ ] ] ] ],
        k = Length @ p - 1;
        If[ ar[[ ;; k ]] === ConstantArray[ { 1, 1 }, k ] && n > k,
            With[ { bad = SelectFirst[ Range[ k + 1, n ], ! optionLikeQ @ a[[ # ]] &, None ] },
                If[ bad =!= None,
                    earlyReturn[ "argument #" <> ToString @ bad <> " " <> fmt[ a[[ bad ]], 40 ] <>
                        " is not a rule, but OptionsPattern[] accepts only options after argument #" <> ToString @ k ] ]
            ]
        ]
    ];
    (* one sequence pattern (x__Integer, Repeated[p]) in the middle: find the first element it rejects *)
    seqIdx = Flatten @ Position[ ar, { _, Infinity } | { 0, 1 }, { 1 }, Heads -> False ];
    If[ Length @ seqIdx === 1 && elementPattern @ p[[ First @ seqIdx ]] =!= None,
        With[ { ep = elementPattern @ p[[ First @ seqIdx ]], mid = Range[ First @ seqIdx, n - ( Length @ p - First @ seqIdx ) ] },
            With[ { bad = SelectFirst[ mid, ! MatchQ[ a[[ # ]], ep ] &, None ] },
                If[ bad =!= None,
                    earlyReturn[ If[ depth === 0, "argument #", "element " ] <> ToString @ bad <> ": " <> fmt[ a[[ bad ]], 40 ] <>
                        " does not match " <> fmt[ ep, 30 ] <> " (from " <> fmt[ p[[ First @ seqIdx ]], 30 ] <> ")" <> typeHint[ a[[ bad ]], ep ] ]
                ]
            ]
        ]
    ];
    (* everything matches individually: repeated pattern names must bind identical values *)
    names = patternNames @ HoldComplete @ pat;
    dup = Select[ Tally @ names, Last @ # > 1 & ][[ All, 1 ]];
    If[ dup =!= { },
        earlyReturn[ "each argument fits its own pattern, but the repeated pattern name(s) " <>
            StringRiffle[ fmt[ #, 20 ] & /@ dup, ", " ] <> " must bind identical (SameQ) values" ]
    ];
    "no structural match for " <> fmt[ HoldComplete @ call, 40 ] <> " vs " <> fmt[ HoldComplete @ pat, 60 ]
];

(* x : p -> p *)
stripPatternName[ HoldComplete[ Verbatim[ Pattern ][ _, q_ ] ] ] := stripPatternName @ HoldComplete @ q;
stripPatternName[ h_HoldComplete ] := h;

(* the pattern for one element of a sequence pattern: x__Integer -> _Integer, Repeated[p] -> p *)
elementPattern[ HoldComplete[ Verbatim[ Pattern ][ _, q_ ] ] ] := elementPattern @ HoldComplete @ q;
elementPattern[ HoldComplete[ ( Verbatim[ BlankSequence ] | Verbatim[ BlankNullSequence ] )[ h___ ] ] ] := HoldComplete @ Blank @ h;
elementPattern[ HoldComplete[ ( Verbatim[ Repeated ] | Verbatim[ RepeatedNull ] )[ q_, ___ ] ] ] := HoldComplete @ q;
elementPattern[ _ ] := None;

argWhy[ i_, a_HoldComplete, p_HoldComplete, depth_ ] := Module[ { pre, inner = "", q = stripPatternName @ p },
    pre = If[ depth === 0, "argument #", "part " ] <> ToString @ i <> ": ";
    (* same non-pattern head on both sides (e.g. two lists, also x : {__Integer}): descend one more level *)
    If[ depth < 2 &&
        MatchQ[ q, HoldComplete[ h_[ ___ ] ] /; AtomQ @ Unevaluated @ h && FreeQ[ HoldComplete @ h, $$patternHeads, Heads -> True ] ] &&
        MatchQ[ { a, q }, { HoldComplete[ h_[ ___ ] ], HoldComplete[ h_[ ___ ] ] } ],
        inner = Replace[ { a, q }, { HoldComplete[ x_ ], HoldComplete[ y_ ] } :> positionWhy[ HoldComplete @ x, HoldComplete @ y, { }, depth + 1 ] ]
    ];
    If[ inner =!= "",
        pre <> fmt[ a, 40 ] <> " -> " <> inner,
        pre <> fmt[ a, 50 ] <> " does not match " <> fmt[ p, 50 ] <> typeHint[ a, p ] <> kvpWhy[ a, p ]
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Hints*)

conditionsIn[ h_HoldComplete ] := Cases[ h, Verbatim[ Condition ][ p_, c_ ] :> { HoldComplete @ p, HoldComplete @ c }, { 0, Infinity } ];

staticHints[ l_HoldComplete, r_HoldComplete, f_HoldComplete, hitQ_ ] := Module[
    { hints = { }, core = lhsCore @ l, allNames, late, topConds },
    allNames = DeleteDuplicates @ patternNames @ l;
    (* inner condition that uses a variable bound outside its own pattern *)
    Scan[
        Function[ pc,
            With[ { own = patternNames @ First @ pc, used = Select[ allNames, ! FreeQ[ Last @ pc, hp @ # ] & ] },
                With[ { foreign = Complement[ used, own ] },
                    If[ foreign =!= { },
                        AppendTo[ hints, "the inner condition on " <> fmt[ First @ pc, 30 ] <> " uses " <> StringRiffle[ fmt[ #, 15 ] & /@ foreign, ", " ] <>
                            ", which is bound outside it: an inner /; only sees its own pattern's variables (use an outer /; or the RHS)" ]
                    ]
                ]
            ]
        ],
        conditionsIn @ core
    ];
    (* OptionValue[name] short form in an LHS condition *)
    If[ ! FreeQ[ Last /@ conditionsIn @ l, Verbatim[ OptionValue ][ _ ] ],
        AppendTo[ hints, "OptionValue[name] (short form) is not resolved inside an LHS condition: use opts:OptionsPattern[] with OptionValue[f, {opts}, name], or test it in the RHS (body /; cond)" ]
    ];
    (* KeyValuePattern with 2+ elements whose later variables are used by an outer condition *)
    late = Flatten[ Cases[ core, Verbatim[ KeyValuePattern ][ { _, rest__ } ] :> patternNames @ HoldComplete @ { rest }, { 0, Infinity } ] ];
    topConds = Join[
        Cases[ l, Verbatim[ Condition ][ _, c_ ] :> HoldComplete @ c, { 1 } ],
        Cases[ { rhsCondition @ r }, cnd[ _, recCond[ _, c_ ] ] :> HoldComplete @ c, Infinity ]
    ];
    If[ late =!= { } && AnyTrue[ late, ! FreeQ[ topConds, hp @ # ] & ],
        AppendTo[ hints, "an outer /; condition uses a variable bound in element 2+ of a KeyValuePattern: in 15.0 such a condition is first evaluated with that variable = Sequence[] and the rule fails unless that also gives True (test inside the KeyValuePattern element, or name the argument and use Lookup)" ]
    ];
    (* string patterns used where an expression pattern is needed *)
    If[ ! FreeQ[ core, _StringExpression | _RegularExpression ],
        AppendTo[ hints, "string patterns (~~, RegularExpression) do not match strings in ordinary patterns: use s_String /; StringMatchQ[s, patt]" ]
    ];
    (* x_. without a Default *)
    If[ ! FreeQ[ core, Verbatim[ Optional ][ _ ] ] && Replace[ f, { HoldComplete[ s_Symbol ] :> DefaultValues @ s === { }, _ -> False } ],
        AppendTo[ hints, "x_. needs a Default[f] value, which is not set: use x_ : value" ]
    ];
    (* body /; cond where it is not a rule condition *)
    If[ ! FreeQ[ r, ( If | Which | Switch | Enclose | Catch | Quiet | Check | WithCleanup | Internal`InheritedBlock | Function | CheckAbort | TimeConstrained )[ ___, _Condition, ___ ] ],
        AppendTo[ hints, "the RHS has body /; cond inside If/Enclose/Catch/...: that is not a rule condition (only directly, or as the body of Module/With/Block); the rule fires and returns a literal Condition" ]
    ];
    (* RHS that ignores all pattern variables: maybe f[x_] = rhs (Set evaluated the RHS once) *)
    If[ hitQ && allNames =!= { } && AllTrue[ allNames, FreeQ[ r, hp @ # ] & ] &&
        MatchQ[ r, HoldComplete[ _Integer | _Real | _Rational | _Complex | { ( _Integer | _Real | _Rational | _Complex ) .. } ] ],
        AppendTo[ hints, "the RHS is the number " <> fmt[ r, 30 ] <> " and uses none of the pattern variables: if it was defined with = (Set), the RHS was evaluated once, at definition time (use :=)" ]
    ];
    hints
];

(* hints from evaluated records *)
recordHints[ recs_List, l_HoldComplete ] := Module[ { hints = { }, syms, pvars = patternNames @ l },
    Scan[
        Function[ rec,
            Replace[ rec, {
                { { "test", _ }, HoldComplete[ NumberQ[ v_ ] ], HoldComplete[ False ] } /; NumericQ @ Unevaluated @ v :>
                    AppendTo[ hints, "NumberQ is False for exact numeric quantities like " <> fmt[ HoldComplete @ v, 20 ] <> ": use NumericQ" ],
                { _, c_HoldComplete, HoldComplete[ val_ ] } /; ! BooleanQ @ Unevaluated @ val :> (
                    If[ ! FreeQ[ c, Verbatim[ Sequence ][ ] ],
                        AppendTo[ hints, "a variable in a test/condition was bound to Sequence[] (unbound at that point)" ] ];
                    syms = Cases[ c, s_Symbol /; ! MatchQ[ Context @ s, $systemContexts ] && ! StringMatchQ[ Context @ s, $packageContextPattern ] &&
                        ! System`Private`HasAnyEvaluationsQ @ s && ! MemberQ[ pvars, HoldComplete @ s ] :>
                        fmt[ HoldComplete @ s, 30 ], { 0, Infinity }, Heads -> True ];
                    If[ syms =!= { }, AppendTo[ hints, "symbol(s) with no value or definitions in a test/condition: " <> StringRiffle[ DeleteDuplicates @ syms, ", " ] ] ]
                )
            } ]
        ],
        recs
    ];
    DeleteDuplicates @ hints
];

recordString[ { { kind_, _ }, c_HoldComplete, HoldComplete[ val_ ] } ] :=
    kind <> " " <> fmt[ c, 60 ] <> " gave " <> fmt[ HoldComplete @ val, 40 ] <>
        If[ BooleanQ @ Unevaluated @ val, "", " (not True/False)" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Rule Reports*)

ruleReport[ call_HoldComplete, rule_, label_String, attrs_, f_HoldComplete, opts_, evalConds_ : True ] := Module[
    { l, r, lit, strip, structQ, hitQ = False, recs = { }, msgs = { }, why, hints, flat },
    { l, r } = splitRule @ rule;
    lit = literalQ @ l;
    strip = stripLHS @ l;
    flat = MemberQ[ attrs, Flat ];
    (* a rule for a Flat head also applies to a subsequence of the arguments: f[1,2,3] -> f[f[1,2] result, 3] *)
    structQ = MatchQ[ call, strip ] || flat && ! FreeQ[ ReplaceAll[ call, mkRule[ strip, HoldComplete @ $hit ] ], $hit ];
    If[ structQ && evalConds, { hitQ, recs, msgs } = runMatch[ call, mkRule[ instrumentLHS @ l, markerRHS @ r ], flat ] ];
    why = Which[
        structQ && ! evalConds, "SHADOWED: the structure matches, but an earlier rule fires first (its tests/conditions were not evaluated)",
        hitQ && flat && ! MatchQ[ call, strip ], "MATCHES a subsequence of the arguments (Flat): the rule rewrites part of the call, then the result is evaluated again",
        hitQ, "MATCHES",
        ! structQ, If[ lit, "literal (exact) rule; ", "" ] <> positionWhy[ call, lhsCore @ strip, attrs ],
        True,
            With[ { bad = Select[ recs, ! MatchQ[ Last @ #, HoldComplete[ True ] ] & ] },
                If[ bad === { },
                    "the structure matches, but the conditions/tests did not all give True",
                    StringRiffle[ recordString /@ DeleteDuplicates @ Take[ bad, UpTo[ 2 ] ], "; " ] <>
                        If[ Length @ bad > 2, " (+" <> ToString[ Length @ bad - 2 ] <> " more)", "" ]
                ]
            ]
    ];
    If[ msgs =!= { }, why = why <> " [messages: " <> StringRiffle[ msgs, ", " ] <> "]" ];
    hints = If[ TrueQ @ opts[ "Hints" ], DeleteDuplicates @ Join[ staticHints[ l, r, f, hitQ ], recordHints[ recs, l ] ], { } ];
    <|
        "Rule"  -> label <> If[ lit, " (literal)", "" ],
        "LHS"   -> fmt @ l,
        "Fires" -> hitQ,
        "Why"   -> why,
        "Hints" -> hints
    |>
];

(* Check every rule (so the verdict is right), stop evaluating tests/conditions once a rule fires,
   and keep at most MaxRules pattern-rule reports (plus the firing one). *)
analyzeRules[ norm_HoldComplete, rules_List, attrs_, f_HoldComplete, opts_ ] := Module[
    { reports = { }, fired = False, nShown = 0, more = 0, rep },
    Do[
        rep = ruleReport[ norm, Last @ rr, First @ rr, attrs, f, opts, ! fired ];
        If[ nShown < opts[ "MaxRules" ] || rep[ "Fires" ],
            AppendTo[ reports, rep ];
            If[ ! StringContainsQ[ rep[ "Rule" ], "(literal)" ], nShown++ ],
            more++
        ];
        If[ rep[ "Fires" ], fired = True ],
        { rr, rules }
    ];
    { reports, more }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Candidate Rules*)

leadSymbol[ HoldComplete[ s_Symbol ] ] := HoldComplete @ s;
leadSymbol[ HoldComplete[ h_[ ___ ] ] ] := leadSymbol @ HoldComplete @ h;
leadSymbol[ _ ] := None;

ruleLead[ rule_ ] := leadSymbol @ lhsCore @ First @ splitRule @ rule;

(* UpValues of the arguments (their symbols or heads) are tried before the DownValues of f *)
upValueCandidates[ call : HoldComplete[ _[ args___ ] ], attrs_ ] := catchReturn @ Module[ { syms, lead = leadSymbol @ call },
    If[ MemberQ[ attrs, HoldAllComplete ], earlyReturn @ { } ];
    syms = DeleteDuplicates @ DeleteCases[ leadSymbol /@ heldList @ HoldComplete @ args, None ];
    Flatten[
        Function[ hs,
            Replace[ hs, HoldComplete[ s_ ] :> With[ { uv = Quiet @ UpValues @ s },
                MapIndexed[
                    If[ ruleLead @ #1 === lead, { "UpValues[" <> SymbolName @ Unevaluated @ s <> "][[" <> ToString @ First @ #2 <> "]]", #1 }, Nothing ] &,
                    uv
                ]
            ] ]
        ] /@ syms,
        1
    ]
];

(* literal (hashed) rules are tried before pattern rules *)
orderedValues[ vals_List, name_String ] := Module[ { idx = Range @ Length @ vals, lit },
    lit = literalQ @ First @ splitRule @ # & /@ vals;
    { name <> "[[" <> ToString @ # <> "]]", vals[[ # ]] } & /@ Join[ Pick[ idx, lit ], Pick[ idx, lit, False ] ]
];

(* contexts of the symbols in the rules (e.g. Pkg`Private`), so that formatted rules stay short *)
ruleContexts[ rules_List ] := Take[
    DeleteCases[
        DeleteDuplicates @ Cases[ rules[[ All, 2 ]], s_Symbol :> Context @ s, Infinity, Heads -> True ],
        "System`" | "Global`"
    ],
    UpTo[ 12 ]
];

(* many literal (memoized) rules: keep the identical one(s) and at most 3 others *)
compactLiterals[ rules_List, call_HoldComplete ] := catchReturn @ Module[ { lit, same, keep },
    lit = Select[ rules, literalQ @ First @ splitRule @ Last @ # & ][[ All, 1 ]];
    If[ Length @ lit <= 4, earlyReturn @ { rules, 0 } ];
    same = Select[ rules, MemberQ[ lit, First @ # ] && MatchQ[ call, First @ splitRule @ Last @ # ] & ][[ All, 1 ]];
    keep = Join[ same, Take[ DeleteCases[ lit, Alternatives @@ same ], UpTo[ Max[ 0, 3 - Length @ same ] ] ] ];
    { Select[ rules, ! MemberQ[ lit, First @ # ] || MemberQ[ keep, First @ # ] & ], Length @ lit - Length @ keep }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Function Heads*)

functionWhy[ fn_Function, args_HoldComplete ] := Module[ { n = Length @ args, need = None, slots, named = { }, body },
    Replace[ HoldComplete @ fn, {
        HoldComplete[ Function[ Null, ___ ] ] :> ( need = None ),
        HoldComplete[ Function[ params_List, __ ] ] :> ( need = Length @ Unevaluated @ params ),
        HoldComplete[ Function[ _Symbol, __ ] ] :> ( need = 1 ),
        HoldComplete[ Function[ b_ ] ] :> (
            body = Replace[ HoldComplete @ b, _Function -> Null, { 1, Infinity } ];
            slots = Cases[ body, Verbatim[ Slot ][ k_Integer ] :> k, Infinity ];
            named = Cases[ body, Verbatim[ Slot ][ k_String ] :> k, Infinity ];
            need = Max[ 0, slots ]
        )
    } ];
    Which[
        named =!= { },
            If[ MatchQ[ args, HoldComplete[ _Association, ___ ] ],
                "pure function with named slots " <> ToString[ named, InputForm ] <> ": a key missing from the Association gives Function::slota and the slot (#key) stays in the result",
                "pure function with named slots " <> ToString[ named, InputForm ] <> " needs an Association as its first argument (Function::slot1 otherwise)" ],
        need === None, "pure function: no pattern matching, it always evaluates",
        n < need && MatchQ[ HoldComplete @ fn, HoldComplete[ Function[ _List | _Symbol, __ ] ] ],
            "the Function needs " <> ToString @ need <> " argument(s), the call has " <> ToString @ n <> ": Function::fpct, the call stays unevaluated",
        n < need,
            "the pure function uses #" <> ToString @ need <> " but the call has " <> ToString @ n <> " argument(s): Function::slotn, #" <> ToString @ need <> " stays in the result",
        True, "pure function with enough arguments: no pattern matching, it always evaluates"
    ]
];

compiledWhy[ cf_CompiledFunction, args_HoldComplete ] := With[ { tmpl = cf[[ 2 ]], n = Length @ args },
    "argument template " <> ToString[ tmpl, InputForm ] <> If[ Length @ tmpl =!= n,
        "; the call has " <> ToString @ n <> " argument(s): CompiledFunction::cfct and the call stays unevaluated",
        "; arguments that do not fit the template give CompiledFunction::cfsa and the uncompiled code runs instead (the result can then be symbolic)"
    ]
];
compiledWhy[ ccf_CompiledCodeFunction, _HoldComplete ] := With[ { sig = Quiet @ Lookup[ First @ ccf, "Signature", "?" ] },
    "signature " <> fmt[ HoldComplete @ sig, 80 ] <> "; a wrong argument count or type gives CompiledCodeFunction::argx/argtype and returns Failure[\"ArgumentCount\"|\"ArgumentType\", ...], not an unevaluated call"
];
compiledWhy[ _, _ ] := "compiled function";

(* the message of a Failure as plain text *)
failureText[ f_Failure ] := Quiet @ Module[ { t = f[ "MessageTemplate" ], p = f[ "MessageParameters" ], s },
    s = If[ StringQ @ t && ListQ @ p,
        ToString[ StringForm[ t, Sequence @@ p ], OutputForm, PageWidth -> Infinity ],
        ToString[ First @ f ]
    ];
    "Failure[" <> ToString[ First @ f, InputForm ] <> "]: " <> If[ StringLength @ s > 150, StringTake[ s, 147 ] <> "...", s ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Analysis*)

(* drop internal keys ("$..."), empty values *)
cleanup[ a_Association ] := DeleteCases[ Map[ cleanup, KeySelect[ a, ! StringStartsQ[ #, "$" ] & ] ], { } | <| |> ];
cleanup[ other_ ] := other;

whyNoMatch[ HoldComplete[ s_Symbol ], _, _ ] := <| "Summary" -> "WhyNoMatch needs a call f[args], not the bare symbol " <> fmt @ HoldComplete @ s |>;

whyNoMatch[ HoldComplete[ e_ ], _, depth_ ] /; depth > 3 := <| "Summary" -> "head evaluation nested too deeply", "Call" -> fmt @ HoldComplete @ e |>;

(* symbol head *)
whyNoMatch[ HoldComplete[ call : h_Symbol[ args___ ] ], opts_, depth_ ] := catchReturn @ Module[
    { info, own, norm, notes, attrs, rules, reports, nPattern = 0, argMsgs = { }, flag, omittedLiterals, rec },
    info = <|
        "Symbol" -> fullSymbolName @ h,
        "Attributes" -> Attributes @ h,
        "Definitions" -> defCounts @ h,
        If[ autoloadStubQ @ h, "Autoload" -> "was an autoload stub (package not loaded); WhyNoMatch loaded it", Nothing ],
        "SameNameElsewhere" -> otherContexts @ h
    |>;
    If[ autoloadStubQ @ h, Quiet @ h; info[ "Definitions" ] = defCounts @ h; info[ "Attributes" ] = Attributes @ h ];
    (* OwnValues: the head evaluates first *)
    own = Quiet @ OwnValues @ h;
    If[ own =!= { },
        With[ { hv = h },
            Which[
                MatchQ[ Unevaluated @ hv, _Function ],
                    earlyReturn @ <|
                        "Summary" -> SymbolName @ Unevaluated @ h <> " has an OwnValue, a pure Function: " <>
                            functionWhy[ hv, If[ TrueQ @ opts[ "EvaluateArguments" ], evalArgs[ HoldComplete @ args, { } ], HoldComplete @ args ] ],
                        "Head" -> info,
                        "HeadValue" -> fmt @ HoldComplete @ hv,
                        "$Fires" -> True
                    |>,
                MatchQ[ Unevaluated @ hv, _Failure ],
                    earlyReturn @ <|
                        "Summary" -> SymbolName @ Unevaluated @ h <> " is a Failure object (e.g. from a FunctionCompile that failed); calling it is a property lookup that gives Missing[\"NotAvailable\", arg]. " <>
                            failureText @ hv,
                        "Head" -> info,
                        "HeadValue" -> fmt[ HoldComplete @ hv, 80 ],
                        "$Fires" -> False
                    |>,
                MatchQ[ Unevaluated @ hv, _CompiledFunction | _CompiledCodeFunction ],
                    earlyReturn @ <|
                        "Summary" -> SymbolName @ Unevaluated @ h <> " is a " <> ToString @ Head @ hv <> ": " <> compiledWhy[ hv, HoldComplete @ args ],
                        "Head" -> info,
                        "$Fires" -> True
                    |>,
                ! MatchQ[ HoldComplete @ hv, HoldComplete @ h ],
                    rec = whyNoMatch[ HoldComplete @ hv[ args ], opts, depth + 1 ];
                    earlyReturn @ Join[
                        rec,
                        <|
                            "Summary" -> SymbolName @ Unevaluated @ h <> " has the value " <> fmt[ HoldComplete @ hv, 50 ] <>
                                " (OwnValue), so the call is really " <> fmt[ HoldComplete @ hv[ args ], 50 ] <> ". " <> Lookup[ rec, "Summary", "" ],
                            "HeadValue" -> fmt @ HoldComplete @ hv
                        |>
                    ]
            ]
        ]
    ];
    (* the arguments as the evaluator sees them *)
    { norm, notes, flag } = Internal`HandlerBlock[
        { "Message", Function[ m, If[ Length @ argMsgs < 4, AppendTo[ argMsgs, messageNameString @ m ] ] ] },
        normalizeCall[ HoldComplete @ call, opts[ "EvaluateArguments" ] ]
    ];
    If[ argMsgs =!= { }, AppendTo[ notes, "messages while evaluating the arguments: " <> StringRiffle[ DeleteDuplicates @ argMsgs, ", " ] ] ];
    attrs = Attributes @ h;
    If[ flag =!= None,
        earlyReturn @ <| "Summary" -> Last @ notes, "Head" -> info, "Call" -> fmt @ norm, "Notes" -> Most @ notes, "$Held" -> norm, "$Fires" -> False |>
    ];
    rules = Join[ upValueCandidates[ norm, attrs ], orderedValues[ Quiet @ DownValues @ h, "DownValues" ] ];
    $extraContexts = ruleContexts @ rules;
    If[ MemberQ[ attrs, HoldAllComplete ] && upValueCandidates[ norm, { } ] =!= { },
        AppendTo[ notes, "HoldAllComplete: UpValues of the arguments are ignored, including " <>
            StringRiffle[ First /@ upValueCandidates[ norm, { } ], ", " ] ]
    ];
    If[ rules === { } && MatchQ[ Context @ h, $systemContexts ] && System`Private`HasDownEvaluationsQ @ h,
        earlyReturn @ Append[ builtinReport[ h, norm, info, notes ], { "$Held" -> norm, "$Fires" -> False } ]
    ];
    If[ rules === { },
        earlyReturn @ <|
            "Summary" -> fullSymbolName @ h <> " has no rules for this call" <>
                If[ defCounts @ h === <| |>, " (no definitions at all: a typo, a missing Needs/Get, or definitions made in another context or MCP session?)", "" ],
            "Head" -> info,
            "Call" -> fmt @ norm,
            "DidYouMean" -> If[ defCounts @ h === <| |> && ! AnyTrue[ info[ "SameNameElsewhere" ], StringContainsQ[ "Values)" ] ], didYouMean @ h, { } ],
            "Notes" -> notes,
            "$Held" -> norm,
            "$Fires" -> False
        |>
    ];
    { rules, omittedLiterals } = compactLiterals[ rules, norm ];
    With[ { unknown = unknownOptions[ h, norm ] },
        If[ unknown =!= { },
            AppendTo[ notes, "option name(s) not in Options[" <> SymbolName @ Unevaluated @ h <> "]: " <> StringRiffle[ unknown, ", " ] <>
                " (OptionsPattern[] still matches them; OptionValue then issues OptionValue::nodef)" ]
        ]
    ];
    { reports, nPattern } = analyzeRules[ norm, rules, attrs, HoldComplete @ h, opts ];
    If[ omittedLiterals > 0, AppendTo[ notes, ToString @ omittedLiterals <> " literal (memoized) rule(s) not identical to the call were skipped" ] ];
    finish[ norm, info, notes, reports, nPattern ]
];

finish[ norm_, info_, notes_, reports_, more_ ] := Module[ { fires, rep = reports },
    fires = SelectFirst[ rep, #Fires &, None ];
    rep = Map[ If[ StringStartsQ[ #Why, "SHADOWED" ], Append[ #, "Why" -> "SHADOWED: the structure matches, but " <> fires[ "Rule" ] <> " is tried first (tests/conditions not evaluated)" ], # ] &, rep ];
    <|
        "Summary" -> Which[
            fires =!= None, fires[ "Rule" ] <> " applies: " <> fires[ "LHS" ],
            MatchQ[ info[ "Symbol" ], _String? ( StringStartsQ[ "System`" ] ) ],
                "no top-level (WL) rule matches " <> fmt[ norm, 60 ] <> "; as a System function it may still be handled by kernel code, " <>
                    "which evaluates it or returns it unevaluated: check the messages it issues (" <> ToString[ Length @ rep + more ] <> " rule(s) checked)",
            True, "no rule matches; " <> fmt[ norm, 60 ] <> " stays unevaluated (" <> ToString[ Length @ rep + more ] <> " rule(s) checked)"
        ],
        "Head" -> info,
        "Call" -> fmt @ norm,
        "Notes" -> notes,
        "Rules" -> ( StringJoin[ #Rule, ": ", #LHS, " -> ", #Why, If[ #Hints =!= { }, " | HINT: " <> StringRiffle[ #Hints, "; " ], "" ] ] & /@ rep ),
        If[ more > 0, "MoreRules" -> ToString @ more <> " further pattern rule(s) not shown (MaxRules)", Nothing ],
        "$Held" -> norm,
        "$Fires" -> fires =!= None
    |>
];

(* option names in the trailing rules of the call that f does not declare *)
unknownOptions // Attributes = { HoldFirst };
unknownOptions[ h_Symbol, norm_HoldComplete ] := catchReturn @ Module[ { known = Keys @ Quiet @ Options @ Unevaluated @ h, args, opts },
    If[ known === { }, earlyReturn @ { } ];
    args = heldList @ Replace[ norm, HoldComplete[ _[ a___ ] ] :> HoldComplete @ a ];
    opts = Reverse @ TakeWhile[ Reverse @ args, optionLikeQ ];
    fmt[ HoldComplete @ #, 30 ] & /@ DeleteCases[
        Flatten @ Replace[ opts, { HoldComplete[ ( Rule | RuleDelayed )[ k_, _ ] ] :> k, HoldComplete[ l_List ] :> Keys @ l }, { 1 } ],
        Alternatives @@ Join[ known, ToString /@ known ]
    ]
];

builtinReport // Attributes = { HoldFirst };
builtinReport[ h_Symbol, norm_HoldComplete, info_, notes_ ] := Module[ { ap, n, args, opts, unknown, ar },
    args = heldList @ Replace[ norm, HoldComplete[ _[ a___ ] ] :> HoldComplete @ a ];
    ap = Quiet @ Lookup[ SyntaxInformation @ Unevaluated @ h, "ArgumentsPattern", Missing[ ] ];
    opts = Select[ args, optionLikeQ ];
    unknown = With[ { known = Keys @ Quiet @ Options @ Unevaluated @ h },
        If[ known === { }, { },
            DeleteCases[
                Flatten @ Replace[ opts, { HoldComplete[ ( Rule | RuleDelayed )[ k_, _ ] ] :> k, HoldComplete[ l_List ] :> Keys @ l }, { 1 } ],
                Alternatives @@ Join[ known, ToString /@ known ]
            ]
        ]
    ];
    ar = If[ ListQ @ ap, Total[ arity /@ ( HoldComplete /@ ap ) ], Missing[ ] ];
    n = Length @ args;
    <|
        "Summary" -> fullSymbolName @ h <> " is implemented in kernel code (no inspectable rules): compare the call with its ArgumentsPattern and look at the messages it issues",
        "Head" -> KeyDrop[ info, "SameNameElsewhere" ],
        "Call" -> fmt @ norm,
        "ArgumentsPattern" -> If[ ListQ @ ap, fmt[ HoldComplete @@ { ap } ], "not available" ],
        "ArgumentCount" -> If[ ListQ @ ar,
            ToString @ n <> If[ First @ ar <= n <= Last @ ar, " (allowed: ", " (NOT allowed: " ] <> arityString @ ar <> " incl. options)",
            ToString @ n ],
        If[ unknown =!= { }, "UnknownOptions" -> ( fmt[ HoldComplete @ #, 30 ] & /@ unknown ), Nothing ],
        "Notes" -> notes
    |>
];

(* compound head f[a][b]: the head is evaluated first; then SubValues *)
whyNoMatch[ HoldComplete[ call : ( hd : _[ ___ ] )[ args___ ] ], opts_, depth_ ] := catchReturn @ Module[
    { inner, lead, norm, rules, reports, hv, outerArgs, more },
    If[ MatchQ[ Unevaluated @ hd, _Function ],
        earlyReturn @ <| "Summary" -> functionWhy[ hd, evalArgs[ HoldComplete @ args, { } ] ], "Call" -> fmt @ HoldComplete @ call, "$Fires" -> True |>
    ];
    inner = whyNoMatch[ HoldComplete @ hd, opts, depth + 1 ];
    If[ TrueQ @ inner[ "$Fires" ],
        hv = hd;  (* the head really evaluates: do what the evaluator does *)
        earlyReturn @ <|
            "Summary" -> "the head " <> fmt[ HoldComplete @ hd, 50 ] <> " itself evaluates (" <> inner[ "Summary" ] <>
                ") to " <> fmt[ HoldComplete @ hv, 50 ] <> ", so SubValues are not used",
            "Inner" -> cleanup @ inner,
            "$Fires" -> True
        |>
    ];
    lead = leadSymbol @ HoldComplete @ hd;
    outerArgs = If[ TrueQ @ opts[ "EvaluateArguments" ], Flatten[ evalArgs[ HoldComplete @ args, { } ], 1, Sequence ], HoldComplete @ args ];
    norm = Replace[ { Lookup[ inner, "$Held", HoldComplete @ hd ], outerArgs }, { HoldComplete[ hh_ ], HoldComplete[ a___ ] } :> HoldComplete @ hh[ a ] ];
    If[ lead === None, earlyReturn @ <| "Summary" -> "the head is not built from a symbol", "Call" -> fmt @ norm |> ];
    rules = Replace[ lead, HoldComplete[ s_ ] :> orderedValues[ Quiet @ SubValues @ s, "SubValues" ] ];
    If[ rules === { },
        earlyReturn @ <|
            "Summary" -> fmt @ lead <> " has no SubValues for " <> fmt[ norm, 60 ] <> If[ KeyExistsQ[ inner, "Rules" ], " (and the head itself did not evaluate: see Inner)", "" ],
            "Call" -> fmt @ norm,
            "Inner" -> cleanup @ inner,
            "$Held" -> norm,
            "$Fires" -> False
        |>
    ];
    { reports, more } = analyzeRules[ norm, rules, { }, lead, opts ];
    finish[ norm, <| "Symbol" -> Replace[ lead, HoldComplete[ s_ ] :> fullSymbolName @ s ], "Definitions" -> Replace[ lead, HoldComplete[ s_ ] :> defCounts @ s ] |>, { }, reports, more ]
];

whyNoMatch[ HoldComplete[ ( fn_Function )[ args___ ] ], _, _ ] :=
    <| "Summary" -> functionWhy[ fn, evalArgs[ HoldComplete @ args, { } ] ], "$Fires" -> True |>;

whyNoMatch[ HoldComplete[ call : h_[ ___ ] ], _, _ ] := <|
    "Summary" -> "the head " <> fmt[ HoldComplete @ h, 40 ] <> " is not a symbol or a function, so " <> fmt[ HoldComplete @ call, 60 ] <> " cannot evaluate",
    "$Fires" -> False
|>;

whyNoMatch[ HoldComplete[ other_ ], _, _ ] := <| "Summary" -> fmt[ HoldComplete @ other, 60 ] <> " is not a call", "$Fires" -> False |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*StuckCalls*)
defineOptions[ StuckCalls, {
    { "MaxHeads" , 8  , positiveIntegerQ, "a positive integer" },
    { "MaxLength", 80 , positiveIntegerQ, "a positive integer" },
    { "Heads"    , { }, ListQ           , "a list of extra (System`) heads to report" }
} ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::ShadowedVariable::Block:: *)
StuckCalls[ result_, opts: OptionsPattern[ ] ] /; validOptionsQ[ StuckCalls, { opts } ] :=
    Block[ { $extraContexts = { } }, stuckCalls[ HoldComplete @ result, optionsAssociation[ StuckCalls, { opts } ] ] ];
(* :!CodeAnalysis::EndBlock:: *)

StuckCalls[ args___ ] := badCall[ StuckCalls, HoldComplete @ args ];

stuckCalls[ HoldComplete[ result_ ], o_Association ] := Module[
    { extra = o[ "Heads" ], calls, groups, n = o[ "MaxLength" ], failures, maxH = o[ "MaxHeads" ] },
    calls = Cases[
        HoldComplete @ result,
        e : ( h_Symbol[ ___ ] | h_Symbol[ ___ ][ ___ ] ) /;
            ( ! MatchQ[ Context @ h, $systemContexts ] && ! StringMatchQ[ Context @ h, $packageContextPattern ] || MemberQ[ extra, h ] ) :>
            { HoldComplete @ h, HoldComplete @ e },
        { 0, Infinity }
    ];
    failures = Cases[ HoldComplete @ result, f : ( _Failure | _Missing | $Failed | $Aborted ) :> failureLabel @ f, { 0, Infinity }, Heads -> True ];
    groups = SortBy[ GatherBy[ calls, First ], -Length @ # & ];
    <|
        "StuckCalls" -> Length @ calls,
        "ByHead" -> Association @ Map[
            Function[ g,
                With[ { hd = g[[ 1, 1 ]], ex = First @ MinimalBy[ g[[ All, 2 ]], LeafCount ] },
                    fmt[ hd, 40 ] -> StringJoin[ ToString @ Length @ g, "x, ", stuckKind[ hd, ex ], ", e.g. ", fmt[ ex, n ] ]
                ]
            ],
            Take[ groups, UpTo[ maxH ] ]
        ],
        If[ Length @ groups > maxH, "MoreHeads" -> Length @ groups - maxH, Nothing ],
        If[ failures =!= { }, "Failures" -> ( First @ # <> " (" <> ToString @ Last @ # <> "x)" & /@ Take[ Tally @ failures, UpTo[ 4 ] ] ), Nothing ]
    |>
];

failureLabel[ f_Failure ] := "Failure[" <> ToString[ First @ f, InputForm ] <> "]";
failureLabel[ m_Missing ] := "Missing[" <> ToString[ First[ m, "" ], InputForm ] <> ", ...]";
failureLabel[ other_ ] := ToString @ other;

stuckKind[ HoldComplete[ h_Symbol ], HoldComplete[ e_ ] ] := Module[ { c = defCounts @ h, others, sim },
    Which[
        autoloadStubQ @ h, "autoload stub (package not loaded)",
        c === <| |> && MatchQ[ Context @ h, $systemContexts ], "built-in left unevaluated (check its messages)",
        c === <| |>,
            others = Select[ otherContexts @ h, ! StringEndsQ[ #, "(no definitions)" ] & ];
            sim = If[ others === { }, didYouMean @ h, { } ];
            "NO definitions" <>
                If[ others =!= { }, " (defined elsewhere: " <> StringRiffle[ others, ", " ] <> ")", "" ] <>
                If[ sim =!= { }, " (similar names: " <> StringRiffle[ sim, ", " ] <> ")", "" ],
        MatchQ[ Unevaluated @ e, _[ ___ ][ ___ ] ], "has " <> ToString @ Lookup[ c, "SubValues", 0 ] <> " SubValues, none matched",
        True, "has " <> StringRiffle[ KeyValueMap[ ToString[ #2 ] <> " " <> #1 &, c ], ", " ] <> ", none matched (use WhyNoMatch)"
    ]
];


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions and Source*)

(* a symbol argument whose value is a string (e.g. a loop variable) is treated as the symbol name; OwnValues does
   not evaluate the symbol, so an autoload stub is not loaded by this check *)
(* an argument that is neither a symbol nor a string (e.g. "Global`" <> name) is evaluated: a string is a name *)
evaluatedName // Attributes = { HoldRest };
evaluatedName[ f_Symbol, HoldComplete[ expr_ ], rest___ ] :=
    With[ { v = expr }, If[ StringQ @ v, f[ v, rest ], badCall[ f, HoldComplete[ expr, rest ] ] ] ];

stringValuedSymbolQ // Attributes = { HoldAllComplete };
stringValuedSymbolQ[ s_Symbol ] := MatchQ[ Quiet @ OwnValues @ s, { _ :> _String } ];
stringValuedSymbolQ[ _ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ShowDefinition*)
ShowDefinition // Attributes = { HoldFirst };

ShowDefinition[ var_Symbol? stringValuedSymbolQ, n___ ] := ShowDefinition[ Evaluate @ var, n ];
ShowDefinition[ expr: Except[ _Symbol | _String ], n___ ] := evaluatedName[ ShowDefinition, HoldComplete @ expr, n ];

ShowDefinition[ name_String ] := ShowDefinition[ name, 3000 ];
ShowDefinition[ name_String, n_? positiveIntegerQ ] :=
    Replace[ nameToHeld @ name, HoldComplete[ s_ ] :> ShowDefinition[ s, n ] ];

ShowDefinition[ s_Symbol ] := ShowDefinition[ s, 3000 ];
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::VariableError::Block:: *)
ShowDefinition[ s_Symbol, n_? positiveIntegerQ ] :=
    Module[ { vals, ctxs },
        If[ lockedQ @ s,
            StringTake[ ToString[ Definition @ s, InputForm ], UpTo[ n ] ],
            Internal`InheritedBlock[ { s },
                ClearAttributes[ s, ReadProtected ];  (* ToString must happen INSIDE the block *)
                vals = Flatten @ { OwnValues @ s, DownValues @ s, UpValues @ s, SubValues @ s };
                ctxs = DeleteDuplicates @ Cases[ vals, x_Symbol :> Context @ Unevaluated @ x, Infinity, Heads -> True ];
                Block[ { $ContextPath = DeleteDuplicates @ Join[ { "System`" }, ctxs ], $Context = "WolframDebuggingShowDefinition`" },
                    truncateString[ ToString[ Definition @ s, InputForm ], n ]
                ]
            ]
        ]
    ];
(* :!CodeAnalysis::EndBlock:: *)

ShowDefinition[ args___ ] := badCall[ ShowDefinition, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*SymbolKind*)
SymbolKind // Attributes = { HoldFirst };

SymbolKind[ var_Symbol? stringValuedSymbolQ ] := SymbolKind[ Evaluate @ var ];
SymbolKind[ expr: Except[ _Symbol | _String ] ] := evaluatedName[ SymbolKind, HoldComplete @ expr ];
SymbolKind[ name_String ] := Replace[ nameToHeld @ name, HoldComplete[ s_ ] :> SymbolKind @ s ];
SymbolKind[ s_Symbol ] := <|
    "Symbol"       -> fullSymbolName @ s,
    "Attributes"   -> Attributes @ Unevaluated @ s,
    "AutoloadStub" -> autoloadStubQ @ s,
    "Autoload"     -> autoloadInfo @ s,
    "KernelCode"   -> TrueQ[ System`Private`HasDownCodeQ @ s ] || TrueQ[ System`Private`HasOwnCodeQ @ Unevaluated @ s ],
    "Counts"       -> Quiet[ Length /@ <| "Own" -> OwnValues @ s, "Down" -> DownValues @ s, "Up" -> UpValues @ s, "Sub" -> SubValues @ s |> ],
    "Usage"        -> Replace[ MessageName[ s, "usage" ], { u_String :> truncateString[ usageText @ u, 150 ], _ :> Missing[ "NoUsage" ] } ]
|>;

SymbolKind[ args___ ] := badCall[ SymbolKind, HoldComplete @ args ];

(* usage messages of System symbols contain linear box syntax (\!\(\*RowBox[...]\)): render it as plain text *)
usageText[ u_String ] := StringReplace[
    StringRiffle[ Quiet @ ToString[ #, OutputForm, PageWidth -> Infinity ] & /@ StringSplit[ u, "\n" ], " " ],
    WhitespaceCharacter .. -> " "
];

(* {mechanism, loader context} of an autoload stub, or None *)
autoloadInfo // Attributes = { HoldAllComplete };
autoloadInfo[ s_Symbol ] := Replace[
    Quiet @ OwnValues @ s,
    {
        { _ :> Package`ActivateLoad[ _, _, ctx_, ___ ] } :> { "Package`ActivateLoad", ctx },
        { _ :> Verbatim[ Condition ][ System`Dump`AutoLoad[ _, _, ctx_ ], _ ] } :> { "System`Dump`AutoLoad", ctx },
        _ -> None
    }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*PacletRoot*)
(* terminates at the file system root (a NestWhile over DirectoryName + PacletObject loops forever on Linux for files
   outside a paclet) and has no trailing separator *)
PacletRoot[ File[ file_String ] ] := PacletRoot @ file;

PacletRoot[ file_String ] :=
    Module[ { dir = If[ DirectoryQ @ file, file, DirectoryName @ file ], prev = None, root = None },
        While[ root === None && StringQ @ dir && dir =!= "" && dir =!= prev,
            If[ AnyTrue[ { "PacletInfo.wl", "PacletInfo.m" }, FileExistsQ @ FileNameJoin @ { dir, # } & ],
                root = StringTrim[ dir, $PathnameSeparator ~~ EndOfString ]
            ];
            prev = dir;
            dir  = DirectoryName @ StringTrim[ dir, $PathnameSeparator ~~ EndOfString ]
        ];
        If[ StringQ @ root, root, Missing[ "NotFound", file ] ]
    ];

PacletRoot[ args___ ] := badCall[ PacletRoot, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FindSymbolSource*)
(* contexts of the definitions -> entry files (FindFile) -> paclet roots -> candidate files (text prefilter) ->
   CodeParser "Definitions" metadata, with line ranges. *)
FindSymbolSource // Attributes = { HoldFirst };

defineOptions[ FindSymbolSource, {
    { "MaxDefinitions", 10 , nonNegativeIntegerQ, "a non-negative integer" },
    { "Kinds"         , All, kindsQ             , "All or a list of kinds such as {\"DownValue\", \"UpValue\", \"OwnValue\", \"Options\", \"Attributes\", \"Message\", \"Format\", \"SubValue\"}" },
    { "MaxLength"     , 400, positiveIntegerQ   , "a positive integer" }
} ];

kindsQ[ All ] := True;
kindsQ[ k_ ] := stringListQ @ Flatten @ { k };

FindSymbolSource[ var_Symbol? stringValuedSymbolQ, opts: OptionsPattern[ ] ] := FindSymbolSource[ Evaluate @ var, opts ];
FindSymbolSource[ expr: Except[ _Symbol | _String ], opts: OptionsPattern[ ] ] := evaluatedName[ FindSymbolSource, HoldComplete @ expr, opts ];

FindSymbolSource[ name_String, opts: OptionsPattern[ ] ] /; validOptionsQ[ FindSymbolSource, { opts } ] :=
    Replace[ nameToHeld @ name, HoldComplete[ s_ ] :> FindSymbolSource[ s, opts ] ];

FindSymbolSource[ sym_Symbol, opts: OptionsPattern[ ] ] /; validOptionsQ[ FindSymbolSource, { opts } ] :=
    findSymbolSource[ HoldComplete @ sym, optionsAssociation[ FindSymbolSource, { opts } ] ];

FindSymbolSource[ args___ ] := badCall[ FindSymbolSource, HoldComplete @ args ];

$maxSourceFiles = 25;  (* maximum number of candidate files to parse *)
$assignmentOps  = "Set" | "SetDelayed" | "TagSet" | "TagSetDelayed" | "UpSet" | "UpSetDelayed";
$ignoredContexts = "System`" | "Global`" | "Internal`" | "Package`" | "System`Private`" | "Language`" | "Developer`" | "Experimental`";

findSymbolSource[ HoldComplete[ sym_ ], o_Association ] :=
    Module[ { full, short, ctxs, entry, roots, files, candidates, defs, loaded, kernelQ, mx, kinds },
        full    = fullSymbolName @ sym;
        short   = SymbolName @ Unevaluated @ sym;
        ctxs    = symbolContexts @ sym;
        entry   = DeleteCases[ AssociationMap[ contextFile, ctxs ], _Missing ];
        roots   = DeleteDuplicates @ Values @ Map[ Replace[ PacletRoot @ #, _Missing :> DirectoryName @ # ] &, entry ];
        files   = Flatten[ FileNames[ { "*.wl", "*.m" }, #, Infinity ] & /@ roots ];
        files   = Select[ files, ! StringContainsQ[ #, "PacletInfo." ] && Quiet @ definitionLikeQ[ ReadString @ #, short ] & ];
        kernelQ = TrueQ[ System`Private`HasDownCodeQ @ sym ] || TrueQ[ System`Private`HasOwnCodeQ @ Unevaluated @ sym ];
        (* code loaded with Get from a loose file (no paclet): loaded source files that mention the name *)
        If[ roots === { } && ! kernelQ && ctxs =!= { },
            files = Select[ $LoadedFiles, StringEndsQ[ #, ".wl" | ".m" ] && Quiet @ definitionLikeQ[ ReadString @ #, short ] & ]
        ];
        candidates = Take[ files, UpTo[ $maxSourceFiles ] ];
        defs    = Flatten[ Replace[ sourceDefinitions[ #, full, o[ "MaxLength" ] ], _Failure -> { } ] & /@ candidates ];
        kinds   = o[ "Kinds" ];
        If[ kinds =!= All, defs = Select[ defs, MemberQ[ Flatten @ { kinds }, #Kind ] & ] ];
        loaded  = Select[ roots, Function[ r, AnyTrue[ $LoadedFiles, StringStartsQ[ r ] ] ] ];
        mx      = Flatten[ FileNames[ "*.mx", #, Infinity ] & /@ roots ];
        <|
            "Symbol"           -> full,
            "Contexts"         -> ctxs,
            "EntryFiles"       -> entry,
            "PacletRoots"      -> roots,
            "LoadedRoots"      -> loaded,
            "CandidateFiles"   -> Length @ files,
            "TotalDefinitions" -> Length @ defs,
            "Definitions"      -> Take[ defs, UpTo[ o[ "MaxDefinitions" ] ] ],
            "KernelCode"       -> kernelQ,
            "MXFiles"          -> Take[ mx, UpTo[ 3 ] ],
            "Notes"            -> sourceNotes[ defs, roots, mx, kernelQ, ctxs ]
        |>
    ];

sourceNotes[ { }, { }, _, True, { } ] := "Implemented in the kernel (C code): no Wolfram Language source exists.";
sourceNotes[ { }, { }, _, True, _ ]   := "Kernel code plus WL definitions loaded from the kernel's own .mx files (SystemFiles/Kernel/SystemResources): no source shipped; use ShowDefinition or the SymbolDefinition tool.";
sourceNotes[ { }, { }, _, _, { } ]    := "No package contexts found: the symbol is undefined, defined interactively, or an unloaded autoload stub.";
sourceNotes[ { }, _, { __ }, _, _ ]   := "No source definitions found; the paclet ships .mx files (compiled): use ShowDefinition or the SymbolDefinition tool.";
sourceNotes[ { }, _, _, _, _ ]        := "No source definitions found in the candidate files (try grep; definitions may be generated at load time).";
sourceNotes[ ___ ]                    := None;

(* values of a symbol without evaluating it and without the ReadProtected restriction *)
heldValues // Attributes = { HoldFirst };
heldValues[ sym_Symbol ] /; lockedQ @ sym := Quiet @ Flatten @ { OwnValues @ sym, DownValues @ sym, UpValues @ sym, SubValues @ sym };
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::VariableError::Block:: *)
(* :!CodeAnalysis::Disable::UnusedParameter:: *)
heldValues[ sym_Symbol ] := Internal`InheritedBlock[ { sym },
    ClearAttributes[ sym, ReadProtected ];
    Flatten @ { OwnValues @ sym, DownValues @ sym, UpValues @ sym, SubValues @ sym }
];
(* :!CodeAnalysis::EndBlock:: *)

(* the non-System contexts referenced by the definitions (or the autoload stub) of a symbol *)
symbolContexts // Attributes = { HoldFirst };
symbolContexts[ sym_Symbol ] :=
    Module[ { vals = heldValues @ sym, ctxs, strs },
        ctxs = Cases[ vals, s_Symbol /; AtomQ @ Unevaluated @ s :> Context @ Unevaluated @ s, { 0, Infinity }, Heads -> True ];
        (* autoload stubs: Package`ActivateLoad[sym, syms, "LoaderContext`", opts] *)
        strs = Cases[ vals, s_String /; StringMatchQ[ s, ( ( WordCharacter | "$" ) .. ~~ "`" ) .. ], Infinity ];
        Select[
            DeleteDuplicates @ Join[ { Context @ Unevaluated @ sym }, ctxs, strs ],
            ! StringMatchQ[ #, $ignoredContexts | ( "Sessions`" ~~ ___ ) | $packageContextPattern ] &
        ]
    ];

(* "A`B`Private`" -> FindFile of "A`B`Private`", "A`B`", "A`" (the first hit wins) *)
contextFile[ ctx_String ] :=
    Module[ { parts = StringSplit[ ctx, "`" ] },
        SelectFirst[
            Table[ Quiet @ FindFile[ StringRiffle[ Take[ parts, n ], "`" ] <> "`" ], { n, Length @ parts, 1, -1 } ],
            StringQ,
            Missing[ "NotFound", ctx ]
        ]
    ];

(* CodeParser is loaded on first use, without leaving it on $ContextPath *)
needsCodeParser[ ] := needsCodeParser[ ] = ( Block[ { $ContextPath }, Needs[ "CodeParser`" ]; Needs[ "CodeParser`Definitions`" ] ]; True );

nameMatchQ[ short_String, full_String ][ s_String ] := s === short || s === full || StringEndsQ[ s, "`" <> short ];

lhsSymbols[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "TagSet" | "TagSetDelayed", _ ], { tag_, lhs_, _ }, _ ] ] :=
    Join[ defSyms @ tag, defSyms @ lhs ];
lhsSymbols[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "UpSet" | "UpSetDelayed", _ ], { CodeParser`CallNode[ h_, args_, _ ], _ }, _ ] ] :=
    Join[ defSyms @ h, Flatten[ defSyms /@ args ] ];
lhsSymbols[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, _, _ ], { lhs_, _ }, _ ] ] := defSyms @ lhs;
lhsSymbols[ _ ] := { };

defSyms[ node_ ] := Cases[ Quiet @ CodeParser`Definitions`DefinitionSymbols @ node, CodeParser`LeafNode[ Symbol, s_String, _ ] :> s ];

(* the definitions of name in file with line ranges; nothing is evaluated *)
sourceDefinitions[ file_String, name_String, maxLength_Integer ] := Enclose @ Module[
    { short, src, lines, ast, nodes, match },
    needsCodeParser[ ];
    short = Last @ StringSplit[ name, "`" ];
    src   = ConfirmBy[ ReadString @ file, StringQ ];
    If[ ! StringContainsQ[ src, short ],
        { },
        lines = StringSplit[ src, "\r\n" | "\n", All ];
        ast   = ConfirmMatch[ CodeParser`CodeParse[ File @ file ], _CodeParser`ContainerNode ];
        match = nameMatchQ[ short, name ];
        nodes = Cases[
            ast,
            node: CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, op: $assignmentOps, _ ], { lhs_, ___ }, data_Association ] /;
                AnyTrue[
                    Join[
                        Cases[ Lookup[ data, { "Definitions", "AdditionalDefinitions" }, { } ], CodeParser`LeafNode[ Symbol, s_, _ ] :> s, Infinity ],
                        lhsSymbols @ node
                    ],
                    match
                ] :> { defKind[ op, lhs ], data[ CodeParser`Source ] },
            Infinity
        ];
        (* several assignment nodes starting on the same line are reported once *)
        nodes = DeleteDuplicatesBy[ SortBy[ nodes, #[[ 2, 1, 1 ]] & ], #[[ 2, 1, 1 ]] & ];
        Map[
            Function[ { kind, pos },
                With[ { l1 = pos[[ 1, 1 ]], l2 = pos[[ 2, 1 ]] },
                    <|
                        "File"  -> file,
                        "Lines" -> { l1, l2 },
                        "Kind"  -> kind,
                        "Text"  -> truncateText[ StringRiffle[ lines[[ l1 ;; l2 ]], "\n" ], maxLength ]
                    |>
                ]
            ] @@ # &,
            nodes
        ]
    ]
];

(* classify a definition by its left-hand side *)
defKind[ "TagSet" | "TagSetDelayed" | "UpSet" | "UpSetDelayed", _ ] := "UpValue";
defKind[ _, lhs_ ] := lhsKind @ stripLHSNode @ lhs;

stripLHSNode[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "Condition" | "HoldPattern" | "PatternTest", _ ], { x_, ___ }, _ ] ] := stripLHSNode @ x;
stripLHSNode[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "Pattern", _ ], { _, x_ }, _ ] ] := stripLHSNode @ x;
stripLHSNode[ x_ ] := x;

lhsKind[ CodeParser`LeafNode[ Symbol, _, _ ] ] := "OwnValue";
lhsKind[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "MessageName", _ ], _, _ ] ] := "Message";
lhsKind[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "Options", _ ], _, _ ] ] := "Options";
lhsKind[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "Attributes", _ ], _, _ ] ] := "Attributes";
lhsKind[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "Format" | "MakeBoxes", _ ], _, _ ] ] := "Format";
lhsKind[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "Default", _ ], _, _ ] ] := "Default";
lhsKind[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "N", _ ], _, _ ] ] := "NValue";
lhsKind[ CodeParser`CallNode[ _CodeParser`CallNode, _, _ ] ] := "SubValue";
lhsKind[ _ ] := "DownValue";

truncateText[ s_String, n_Integer ] /; StringLength @ s > n := StringTake[ s, n ] <> " ... (" <> ToString @ StringLength @ s <> " chars)";
truncateText[ s_String, _ ] := s;

(* cheap text prefilter: a line that starts (after indentation, an optional "pat :" or a wrapper such as HoldPattern[,
   Options[, Attributes[, Format[, SetAttributes[) with the name, or "name /:" anywhere *)
definitionLikeQ[ src_String, short_String ] :=
    With[ { q = "(?:\\w+`)*" <> StringReplace[ short, "$" -> "\\$" ] },
        StringContainsQ[ src, short ] && StringContainsQ[
            src,
            RegularExpression[
                "(?m)^[ \\t]*(?:\\w+\\s*:\\s*)?(?:(?:HoldPattern|Options|Attributes|Format|SetAttributes|SetOptions|Default|N)\\[\\s*)*" <>
                q <> "\\s*(?:\\[|::|:=|=|/:|//)|" <> q <> "\\s*/:"
            ]
        ]
    ];
definitionLikeQ[ _, _ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Loading*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LoadTrace*)
(* Autoloads are seen by condition-only rules prepended to Package`ActivateLoad and System`Dump`AutoLoad (they record
   and then fail, so the real loader still runs); file loads by a "GetFileEvent" handler (HoldComplete[arg, wrapper,
   First|Last], arg = the literal first argument of Get). GetFileEvent does not fire for .mx files, DumpGet, kernel
   autoloads, PacletDirectoryLoad or Needs of a loaded context: "NewFiles" ($LoadedFiles difference) has those. *)
LoadTrace // Attributes = { HoldFirst };

defineOptions[ LoadTrace, {
    { "MaxLoads"  , 30      , nonNegativeIntegerQ, "a non-negative integer" },
    { "MaxDepth"  , Infinity, byteLimitQ         , "a non-negative integer (0: top-level loads only) or Infinity" },
    { "MaxFiles"  , 20      , nonNegativeIntegerQ, "a non-negative integer" },
    { "MaxLength" , 80      , positiveIntegerQ   , "a positive integer" },
    $resultOptionSpec
} ];

LoadTrace[ expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ LoadTrace, { opts } ] :=
    loadTrace[ HoldComplete @ expr, optionsAssociation[ LoadTrace, { opts } ] ];

LoadTrace[ args___ ] := badCall[ LoadTrace, HoldComplete @ args ];

loadTrace[ HoldComplete[ expr_ ], o_Association ] :=
    Module[ { bag, depth, before, result, via, record, loads, newFiles, width },
        bag    = Internal`Bag[ ];
        depth  = 0;
        before = $LoadedFiles;
        width  = o[ "MaxLength" ];
        (* trigger: the last stack frame before the first loader frame (or the file being loaded, when nested) *)
        via[ ] := If[ depth > 0,
            If[ StringQ @ $InputFileName && $InputFileName =!= "", FileNameTake @ $InputFileName, "" ],
            Module[ { frames = Stack[ _ ], pos },
                pos = FirstPosition[
                    frames,
                    ( HoldCompleteForm | HoldForm )[ ( Get | Needs | Package`ActivateLoad | System`Dump`AutoLoad )[ ___ ] ],
                    { 0 },
                    { 1 }
                ][[ 1 ]];
                If[ pos === 0, "", frameString[ frames[[ Max[ pos - 1, 1 ] ]], width, False ] ]
            ]
        ];
        record[ kind_, target_, resolved_ ] := Internal`StuffBag[ bag, { depth, kind, target, resolved, via[ ] } ];
        result = Internal`InheritedBlock[ { Package`ActivateLoad, System`Dump`AutoLoad },
            Unprotect[ Package`ActivateLoad, System`Dump`AutoLoad ];
            PrependTo[
                DownValues @ Package`ActivateLoad,
                HoldPattern[ Package`ActivateLoad[ s_, _, ctx_, ___ ] ] :> Null /; ( record[ "Autoload", fullSymbolName @ s, ctx ]; False )
            ];
            PrependTo[
                DownValues @ System`Dump`AutoLoad,
                HoldPattern[ System`Dump`AutoLoad[ Hold[ s_ ], _, ctx_ ] ] :> Null /; ( record[ "Autoload", fullSymbolName @ s, ctx ]; False )
            ];
            Protect[ Package`ActivateLoad, System`Dump`AutoLoad ];
            Internal`HandlerBlock[
                {
                    "GetFileEvent",
                    Function[ ev,
                        Replace[
                            ev,
                            {
                                HoldComplete[ f_, _, First ] :> (
                                    record[ "Get", f, If[ StringQ @ f, Replace[ Quiet @ FindFile @ f, $Failed -> f ], f ] ];
                                    depth++
                                ),
                                HoldComplete[ _, _, Last ] :> ( depth = Max[ depth - 1, 0 ] )
                            }
                        ]
                    ]
                },
                evaluateContained @ StackBegin @ expr
            ]
        ];
        loads    = Internal`BagPart[ bag, All ];
        newFiles = DeleteCases[ $LoadedFiles, Alternatives @@ before ];
        <|
            "Result"              -> boundedResult[ result, o[ "MaxResultBytes" ] ],
            "LoadCount"           -> Length @ loads,
            "Loads"               -> Take[ Select[ loads, #[[ 1 ]] <= o[ "MaxDepth" ] & ], UpTo[ o[ "MaxLoads" ] ] ],
            "NewFileCount"        -> Length @ newFiles,
            "NewFilesByDirectory" -> Take[ ReverseSort @ Counts[ FileNameTake[ #, { 1, -2 } ] & /@ newFiles ], UpTo[ 10 ] ],
            "NewFiles"            -> Take[ newFiles, UpTo[ o[ "MaxFiles" ] ] ]
        |>
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ContextSourceInfo*)
ContextSourceInfo[ ctx_String /; StringEndsQ[ ctx, "`" ] ] :=
    Module[ { mtime, pacs, active, loc, loaded, mx, src, newestSrc, edited, t0 },
        mtime     = AbsoluteTime @ FileDate[ #, "Modification" ] &;
        pacs      = Quiet @ PacletFind @ <| "Context" -> ctx |>;  (* all candidates; First = the one Get/Needs use *)
        active    = If[ pacs === { }, Missing[ "NoPaclet" ], First @ pacs ];
        loc       = If[ MissingQ @ active, Missing[ "NoPaclet" ], active[ "Location" ] ];
        loaded    = If[ StringQ @ loc,
            Select[ $LoadedFiles, StringStartsQ[ #, loc <> $PathnameSeparator ] & ],
            Select[ $LoadedFiles, # === Quiet @ FindFile @ ctx & ]
        ];
        mx        = Select[ loaded, StringEndsQ[ ".mx" ] ];
        src       = If[ StringQ @ loc, FileNames[ { "*.wl", "*.m" }, loc, Infinity ], { } ];
        newestSrc = If[ src === { }, Missing[ "NoSource" ], First @ MaximalBy[ src, mtime ] ];
        t0        = AbsoluteTime[ ] - SessionTime[ ];
        edited    = Select[ src, mtime[ # ] > t0 & ];
        <|
            "Context"                -> ctx,
            "InPackages"             -> MemberQ[ $Packages, ctx ],     (* True: Needs[ctx] is a no-op; use Get[ctx] to reload *)
            "OnContextPath"          -> MemberQ[ $ContextPath, ctx ],
            "FindFile"               -> Quiet @ FindFile @ ctx,         (* what Get[ctx] would load now *)
            "Candidates"             -> Take[ { #[ "Name" ], #[ "Version" ], #[ "Location" ] } & /@ pacs, UpTo[ 5 ] ],
            "LoadedFileCount"        -> Length @ loaded,
            "LoadedFiles"            -> Take[ loaded, UpTo[ 10 ] ],    (* what was actually loaded from the active paclet *)
            "OtherLoadedCopies"      -> If[ Length @ pacs > 1,
                Take[
                    Select[ $LoadedFiles, Function[ f, AnyTrue[ Rest @ pacs, StringStartsQ[ f, #[ "Location" ] <> $PathnameSeparator ] & ] ] ],
                    UpTo[ 10 ]
                ],
                { }
            ],
            "StaleMX"                -> If[ mx =!= { } && StringQ @ newestSrc, Select[ mx, mtime[ # ] < mtime @ newestSrc & ], { } ],
            "NewestSource"           -> newestSrc,
            (* source files edited after this kernel started: the running code cannot contain these edits *)
            "EditedSinceKernelStart" -> Take[ edited, UpTo[ 10 ] ]
        |>
    ];

ContextSourceInfo[ args___ ] := badCall[ ContextSourceInfo, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AutoloadStubQ*)
AutoloadStubQ // Attributes = { HoldAllComplete };
AutoloadStubQ[ s_Symbol ] := autoloadStubQ @ s;
AutoloadStubQ[ name_String ] := Replace[ nameToHeld @ name, { HoldComplete[ s_ ] :> autoloadStubQ @ s, _ -> False } ];
AutoloadStubQ[ expr: Except[ _Symbol | _String ] ] := evaluatedName[ AutoloadStubQ, HoldComplete @ expr ];
AutoloadStubQ[ args___ ] := badCall[ AutoloadStubQ, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*EnsureLoaded*)
(* evaluating the bare symbol fires its OwnValue stub, which loads the package; nothing else is evaluated *)
EnsureLoaded // Attributes = { HoldAllComplete };
EnsureLoaded[ s_Symbol ] := ( If[ autoloadStubQ @ s, Quiet @ s ]; ! autoloadStubQ @ s );
EnsureLoaded[ name_String ] := Replace[ nameToHeld @ name, { HoldComplete[ s_ ] :> EnsureLoaded @ s, m_Missing :> m } ];
EnsureLoaded[ expr: Except[ _Symbol | _String ] ] := evaluatedName[ EnsureLoaded, HoldComplete @ expr ];
EnsureLoaded[ args___ ] := badCall[ EnsureLoaded, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tests*)

(* heads are compared by name: evaluating TestReportObject or TestObject would load MUnit` *)
headNameQ[ x_, name_String ] := With[ { h = Head @ x }, Head @ h === Symbol && SymbolName @ h === name ];
testReportQ[ x_ ] := headNameQ[ x, "TestReportObject" ];
testObjectQ[ x_ ] := headNameQ[ x, "TestObject" ];

existingFileQ[ file_String ] := FileExistsQ @ file && ! DirectoryQ @ file;
existingFileQ[ _ ] := False;

(* "MyTest" matches "MyTest" and "MyTest@@Tests/File.wlt:12,1-17,2" (the location suffix added by a commit hook) *)
idMatchQ[ id_String, patt_ ] := With[ { base = First[ StringSplit[ id, "@@" ], id ] }, Quiet[ StringMatchQ[ id, patt ] || StringMatchQ[ base, patt ] ] ];
idMatchQ[ _, _ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TestFailureSummary*)
defineOptions[ TestFailureSummary, {
    { "MaxBytes" , 2000         , positiveIntegerQ, "a positive integer" },
    { "MaxLength", 160          , positiveIntegerQ, "a positive integer" },
    { "Format"   , "Association", MatchQ[ "Association" | "Text" ], "\"Association\" or \"Text\"" }
} ];

TestFailureSummary[ report_? testInputsQ, opts: OptionsPattern[ ] ] /; validOptionsQ[ TestFailureSummary, { opts } ] :=
    testFailureSummary[ failedTests @ report, optionsAssociation[ TestFailureSummary, { opts } ] ];

TestFailureSummary[ args___ ] := badCall[ TestFailureSummary, HoldComplete @ args ];

testInputsQ[ x_ ] := testReportQ @ x || testObjectQ @ x || MatchQ[ x, { ___? testInputsQ } | _Association? ( AllTrue[ Values @ #, testObjectQ ] & ) ];

failedTests[ tr_? testReportQ ] := Select[ Replace[ tr[ "Results" ], a_Association :> Values @ a ], #[ "Outcome" ] =!= "Success" & ];
failedTests[ t_? testObjectQ ] := If[ t[ "Outcome" ] =!= "Success", { t }, { } ];
failedTests[ l_List ] := Join @@ ( failedTests /@ l );
failedTests[ a_Association ] := failedTests @ Values @ a;
failedTests[ _ ] := { };

testFailureSummary[ { }, o_Association ] := If[ o[ "Format" ] === "Text", "No failed tests.", { } ];

testFailureSummary[ tests_List, o_Association ] :=
    Module[ { n, budget, recs, all, size, k },
        n      = o[ "MaxLength" ];
        budget = o[ "MaxBytes" ];
        size   = StringLength @ If[ o[ "Format" ] === "Text", StringRiffle[ recordText /@ #, "\n" ], ToString[ #, InputForm ] ] &;
        recs   = testRecord[ #, n ] & /@ tests;
        (* shrink the field length first, then drop trailing records *)
        While[ size @ recs > budget && n > 80, n = Max[ 80, Floor[ 0.75 n ] ]; recs = testRecord[ #, n ] & /@ tests ];
        k   = Length @ recs;
        all = recs;
        While[ size @ recs > budget && k > 1, k--; recs = Append[ Take[ all, k ], <| "Omitted" -> Length @ all - k |> ] ];
        If[ o[ "Format" ] === "Text", StringRiffle[ recordText /@ recs, "\n" ], recs ]
    ];

testRecord[ t_, n_Integer ] :=
    Module[ { em = t[ "ExpectedMessages" ], ft = t[ "FailureType" ], rec },
        rec = <|
            "TestID"   -> Replace[ t[ "TestID" ], id: Except[ _String ] :> heldString[ HoldComplete @ id, n ] ],
            "Outcome"  -> t[ "Outcome" ] <> Replace[ ft, { s_String :> "/" <> s, _ -> "" } ],
            "Input"    -> heldValueString[ t[ "Input" ], n ],
            "Expected" -> heldValueString[ t[ "ExpectedOutput" ], n ],
            "Actual"   -> heldValueString[ t[ "ActualOutput" ], n ],
            "Messages" -> messageSummary[ t[ "ActualMessages" ], n ]
        |>;
        If[ ! MatchQ[ em, HoldForm[ { } ] | { } ], rec[ "ExpectedMessages" ] = heldValueString[ em, n ] ];
        (* IntermediateTest failures: the outer output may even be correct; show the failing steps *)
        If[ StringQ @ ft && StringStartsQ[ ft, "IntermediateTest" ],
            rec[ "FailedSteps" ] = Map[
                StringJoin[
                    Replace[ #[ "TestID" ], id: Except[ _String ] :> heldString[ HoldComplete @ id, 40 ] ],
                    " [", #[ "Outcome" ], "] exp: ", heldValueString[ #[ "ExpectedOutput" ], 60 ],
                    " act: ", heldValueString[ #[ "ActualOutput" ], 60 ],
                    If[ #[ "ActualMessages" ] =!= { }, " msgs: " <> StringRiffle[ messageSummary[ #[ "ActualMessages" ], 80 ], "; " ], "" ]
                ] &,
                Select[ t[ "IntermediateTests" ], #[ "Outcome" ] =!= "Success" & ]
            ]
        ];
        rec
    ];

(* values in TestObjects are HoldForm[...] (Throw/Abort give Hold[...]): strip one level *)
heldValueString[ ( HoldForm | HoldCompleteForm | HoldComplete )[ e_ ], n_Integer ] := heldString[ HoldComplete @ e, n ];
heldValueString[ Hold[ e_ ], n_Integer ] := "Hold[" <> heldString[ HoldComplete @ e, n - 6 ] <> "]";
heldValueString[ e_, n_Integer ] := heldString[ HoldComplete @ e, n ];

(* message texts, repeated messages collapsed: {"(x3) Power::infy: ...", "General::stop: ..."} *)
messageSummary[ msgs_List, n_Integer ] := KeyValueMap[
    If[ #2 > 1, "(x" <> ToString @ #2 <> ") " <> #1, #1 ] &,
    Counts[ messageText[ Replace[ #, ( HoldForm | HoldCompleteForm )[ e_ ] :> Hold @ e ], n ] & /@ msgs ]
];
messageSummary[ _, _ ] := { };

recordText[ r_Association /; KeyExistsQ[ r, "Omitted" ] ] := "... " <> ToString @ r[ "Omitted" ] <> " more failed tests omitted";
recordText[ r_Association ] := StringJoin[
    r[ "TestID" ], " [", r[ "Outcome" ], "]\n  in:  ", r[ "Input" ], "\n  exp: ", r[ "Expected" ], "\n  act: ", r[ "Actual" ],
    If[ r[ "Messages" ] =!= { }, "\n  msgs: " <> StringRiffle[ r[ "Messages" ], " | " ], "" ],
    If[ KeyExistsQ[ r, "ExpectedMessages" ], "\n  expected msgs: " <> r[ "ExpectedMessages" ], "" ],
    If[ KeyExistsQ[ r, "FailedSteps" ], "\n  failed steps: " <> StringRiffle[ r[ "FailedSteps" ], "\n                " ], "" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TestSource*)
(* locate VerificationTests by TestID without evaluating anything (CodeParser) *)
TestSource[ File[ file_String ], patt_ ] := TestSource[ file, patt ];

TestSource[ file_? existingFileQ, patt_ ] :=
    Module[ { ast, nodes, lines },
        Block[ { $ContextPath }, Needs[ "CodeParser`" ] ];  (* do not leave CodeParser` on $ContextPath *)
        ast   = CodeParser`CodeParse @ File @ file;
        lines = StringSplit[ ReadString @ file, { "\r\n", "\n" }, All ];
        nodes = Cases[
            ast[[ 2 ]],
            CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "VerificationTest", _ ], args_, KeyValuePattern[ CodeParser`Source -> { { l1_, _ }, { l2_, _ } } ] ] :>
                With[
                    {
                        ids = Cases[
                            args,
                            CodeParser`CallNode[
                                CodeParser`LeafNode[ Symbol, "Rule" | "RuleDelayed", _ ],
                                { CodeParser`LeafNode[ Symbol, "TestID", _ ], CodeParser`LeafNode[ String, s_, _ ] },
                                _
                            ] :> ToExpression @ s,
                            { 1 }
                        ]
                    },
                    <| "TestID" -> First[ ids, None ], "Lines" -> { l1, l2 }, "Code" -> StringRiffle[ lines[[ l1 ;; l2 ]], "\n" ] |>
                ],
            { 1 }
        ];
        Select[ nodes, idMatchQ[ #TestID, patt ] & ]
    ];

TestSource[ args___ ] := badCall[ TestSource, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*RunTestsByID*)
(* TestReport of the file, but VerificationTests whose TestID does not match evaluate to Null (an InheritedBlock rule
   on VerificationTest). "Context" -> Automatic reads the file in $Context, where typed code lives (Sessions`<id>` in
   the MCP evaluator). *)
defineOptions[ RunTestsByID, {
    { "Setup"         , None     , anyValueQ                         , "None or a TestID pattern of setup tests that must also run" },
    { "Context"       , Automatic, MatchQ[ Automatic | _String ]    , "Automatic or a context name" },
    { "TimeConstraint", Automatic, MatchQ[ Automatic | Infinity | _? positiveNumberQ ], "Automatic, Infinity or a positive number of seconds per test" },
    { "ReturnReport"  , False    , booleanQ                          , "True or False" },
    { "MaxBytes"      , 2000     , positiveIntegerQ                  , "a positive integer" }
} ];

RunTestsByID[ File[ file_String ], patt_, opts: OptionsPattern[ ] ] := RunTestsByID[ file, patt, opts ];

RunTestsByID[ file_? existingFileQ, patt_, opts: OptionsPattern[ ] ] /; validOptionsQ[ RunTestsByID, { opts } ] :=
    runTestsByID[ ExpandFileName @ file, patt, optionsAssociation[ RunTestsByID, { opts } ] ];

RunTestsByID[ args___ ] := badCall[ RunTestsByID, HoldComplete @ args ];

runTestsByID[ file_String, patt_, o_Association ] :=
    Module[ { setup, ctx, path, keepQ, tc, tr, results },
        setup = o[ "Setup" ];
        (* VerificationTest has no DownValues until MUnit` loads; loading it inside the block would wipe the filter *)
        Block[ { $ContextPath }, Needs[ "MUnit`" ] ];
        keepQ[ id_ ] := idMatchQ[ id, patt ] || ( setup =!= None && idMatchQ[ id, setup ] );
        ctx = Replace[ o[ "Context" ], Automatic :> $Context ];
        tc  = Replace[ o[ "TimeConstraint" ], Automatic :> Replace[ autoTimeLimit[ Infinity ], r_? NumericQ :> Ceiling @ r ] ];
        (* another context: take $Context off $ContextPath, where it would shadow ctx symbols of the same name *)
        path = If[ ctx === $Context, $ContextPath, DeleteCases[ $ContextPath, $Context ] ];
        tr = Block[ { $Context = ctx, $ContextPath = path },
            Internal`InheritedBlock[ { VerificationTest },
                Unprotect @ VerificationTest;
                PrependTo[
                    DownValues @ VerificationTest,
                    HoldPattern[ VerificationTest[ ___, TestID -> id_, ___ ] ] /; ! keepQ @ id :> Null
                ];
                Protect @ VerificationTest;
                TestReport[ file, ProgressReporting -> False, TimeConstraint -> tc ]
            ]
        ];
        If[ TrueQ @ o[ "ReturnReport" ] || ! testReportQ @ tr,
            tr,
            results = Replace[ tr[ "Results" ], a_Association :> Values @ a ];
            <|
                "File"      -> file,
                "TestsRun"  -> Length @ results,
                "Succeeded" -> tr[ "TestsSucceededCount" ],
                "Failed"    -> tr[ "TestsFailedCount" ],
                "Outcomes"  -> Take[ ( #[ "TestID" ] -> #[ "Outcome" ] ) & /@ results, UpTo[ 30 ] ],
                "Failures"  -> testFailureSummary[ failedTests @ tr, <| "MaxBytes" -> o[ "MaxBytes" ], "MaxLength" -> 160, "Format" -> "Text" |> ]
            |>
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ReproduceTest*)
(* mirrors the test harness: Block[{$Messages = {}, $MessageList = {}}], messages recorded only when they would really
   print (the "MessageTextFilter" handler), input under StackBegin; record-only, so the evaluation is not stopped *)
defineOptions[ ReproduceTest, {
    { "Frames"        , 12   , nonNegativeIntegerQ, "a non-negative integer" },
    { "MaxLength"     , 120  , positiveIntegerQ   , "a positive integer" },
    { "TimeConstraint", 30   , positiveNumberQ    , "a positive number of seconds" },
    { "PrintMessages" , False, booleanQ           , "True or False" }
} ];

ReproduceTest[ t_? reproducibleTestQ, opts: OptionsPattern[ ] ] /; validOptionsQ[ ReproduceTest, { opts } ] :=
    reproduceTest[ testInput @ t, optionsAssociation[ ReproduceTest, { opts } ] ];

ReproduceTest[ args___ ] := badCall[ ReproduceTest, HoldComplete @ args ];

reproducibleTestQ[ x_ ] := testObjectQ @ x || MatchQ[ x, HoldComplete[ _ ] | KeyValuePattern[ "Code" -> _String ] | { KeyValuePattern[ "Code" -> _String ], ___ } ];

testInput[ h: HoldComplete[ _ ] ] := h;
testInput[ t_? testObjectQ ] := Replace[ t[ "Input" ], ( HoldForm | HoldCompleteForm | Hold )[ e_ ] :> HoldComplete @ e ];
testInput[ src_Association ] := Replace[
    Quiet @ ToExpression[ src[ "Code" ], InputForm, HoldComplete ],
    { HoldComplete[ VerificationTest[ in_, ___ ] ] :> HoldComplete @ in, _ :> HoldComplete @ $Failed }
];
testInput[ { src_Association, ___ } ] := testInput @ src;

reproduceTest[ HoldComplete[ input_ ], o_Association ] :=
    Module[ { r, printed },
        r = collectMessagesCore[
            HoldComplete @ input,
            <|
                "SuppressPrinting" -> ! TrueQ @ o[ "PrintMessages" ],
                "StackFrames"      -> o[ "Frames" ],
                "StringLength"     -> o[ "MaxLength" ],
                "Complete"         -> False,
                "IgnoreOuterQuiet" -> False,
                "TimeConstraint"   -> o[ "TimeConstraint" ]
            |>
        ];
        printed = Select[ r[ "Messages" ], #Printed & ];
        <|
            "Result"              -> Replace[ r[ "Result" ], h_HoldComplete :> heldString[ h, o[ "MaxLength" ] ] ],
            "Messages"            -> KeyValueMap[ If[ #2 > 1, "(x" <> ToString @ #2 <> ") " <> #1, #1 ] &, Counts @ printed[[ All, "Text" ]] ],
            "StackAtFirstMessage" -> If[ printed === { }, None, First[ printed ][ "Stack" ] ]
        |>
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*CheckTestFile*)
(* static checks for problems that TestReport reports badly or not at all *)
CheckTestFile[ File[ file_String ] ] := CheckTestFile @ file;

CheckTestFile[ file_? existingFileQ ] :=
    Module[ { ast, top, issues, tests, ids },
        Block[ { $ContextPath }, Needs[ "CodeParser`" ] ];
        issues = Internal`Bag[ ];
        ast = CodeParser`CodeParse @ File @ file;
        (* 1. syntax errors: TestReport then runs NO test of the file (the TestReport MCP tool even reports success with 0 tests) *)
        Scan[
            Internal`StuffBag[ issues, # ] &,
            Cases[
                ast,
                ( h_? errorNodeHeadQ )[ tag_, _, data_ ] :> <| "Line" -> sourceLine @ data, "Issue" -> "SyntaxError", "Detail" -> errorNodeDetail[ h, tag ] |>,
                Infinity
            ]
        ];
        top = Replace[
            ast[[ 2 ]],
            CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "CompoundExpression", _ ], args_, _ ] :> Sequence @@ args,
            { 1 }
        ];
        (* 2. top-level Abort/Throw/Exit/Quit: TestReport aborts or the Throw escapes *)
        Scan[
            Internal`StuffBag[ issues, # ] &,
            Cases[
                top,
                CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, f: "Abort" | "Throw" | "Exit" | "Quit", _ ], _, data_ ] :>
                    <| "Line" -> sourceLine @ data, "Issue" -> "TopLevel" <> f, "Detail" -> "ends the whole test run" |>,
                { 1 }
            ]
        ];
        (* 3. malformed VerificationTest: more than 3 positional arguments (VerificationTest::nonopt), the test is dropped *)
        tests = Cases[ top, CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "VerificationTest", _ ], args_, data_ ] :> { args, data }, { 1 } ];
        Scan[
            Function[ { args, data },
                With[ { pos = Count[ args, Except[ _? ruleNodeQ ] ] },
                    If[ pos > 3 || pos == 0,
                        Internal`StuffBag[ issues, <|
                            "Line"   -> sourceLine @ data,
                            "Issue"  -> "MalformedVerificationTest",
                            "Detail" -> ToString @ pos <> " positional arguments (the test is dropped from the report)"
                        |> ]
                    ]
                ]
            ] @@ # &,
            tests
        ];
        (* 4. missing / duplicate TestIDs *)
        ids = Map[
            Function[ { args, data },
                {
                    sourceLine @ data,
                    FirstCase[
                        args,
                        CodeParser`CallNode[
                            CodeParser`LeafNode[ Symbol, "Rule" | "RuleDelayed", _ ],
                            { CodeParser`LeafNode[ Symbol, "TestID", _ ], CodeParser`LeafNode[ String, str_, _ ] },
                            _
                        ] :> ToExpression @ str,
                        None
                    ]
                }
            ] @@ # &,
            tests
        ];
        Scan[
            Internal`StuffBag[ issues, <| "Line" -> #[[ 1 ]], "Issue" -> "NoTestID", "Detail" -> "TestID is not a literal string" |> ] &,
            Select[ ids, #[[ 2 ]] === None & ]
        ];
        KeyValueMap[
            If[ Length @ #2 > 1, Internal`StuffBag[ issues, <| "Line" -> #2[[ 2, 1 ]], "Issue" -> "DuplicateTestID", "Detail" -> #1 |> ] ] &,
            GroupBy[ Select[ ids, StringQ @ #[[ 2 ]] & ], ( First[ StringSplit[ #[[ 2 ]], "@@" ], #[[ 2 ]] ] & ) ]
        ];
        SortBy[ Internal`BagPart[ issues, All ], #Line & ]
    ];

CheckTestFile[ args___ ] := badCall[ CheckTestFile, HoldComplete @ args ];

(* the error nodes of CodeParser (by name: they differ between versions, e.g. CallMissingCloserNode for f[1, 2 with
   no closing bracket, UnterminatedGroupNeedsReparseNode, SyntaxErrorNode, ErrorNode, GroupMissingOpenerNode) *)
errorNodeHeadQ[ h_Symbol ] := Context @ h === "CodeParser`" && StringMatchQ[
    SymbolName @ h,
    ( ___ ~~ ( "ErrorNode" | "MissingCloserNode" | "MissingOpenerNode" ) ) | ( "Unterminated" ~~ ___ ~~ "Node" )
];
errorNodeHeadQ[ _ ] := False;

(* the error tag (e.g. SyntaxError`ExpectedOperand) or the node name without "Node" (CallMissingCloser) *)
errorNodeDetail[ _, tag: _Symbol | _String ] := ToString @ tag;
errorNodeDetail[ h_Symbol, _ ] := StringDelete[ SymbolName @ h, "Node" ~~ EndOfString ];

ruleNodeQ[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "Rule" | "RuleDelayed", _ ], _, _ ] ] := True;
ruleNodeQ[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "List", _ ], { __? ruleNodeQ }, _ ] ] := True;
ruleNodeQ[ _ ] := False;

sourceLine[ KeyValuePattern[ CodeParser`Source -> { { l_, _ }, _ } ] ] := l;
sourceLine[ _ ] := Missing[ ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Parallel and Asynchronous*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ParallelCapture*)
(* f is mapped under $CaptureFunction (a pure function: nothing has to be distributed for it). Subkernel messages
   never reach the master's handlers, so they are collected inside the subkernel. "MasterOnlyHeads" lists functions
   that stayed unevaluated in a subkernel result but have definitions in the master: the classic "definition was not
   distributed" symptom. Without subkernels (MCP Local method, cloud) every item runs in the master ("RanInMaster"). *)
defineOptions[ ParallelCapture, {
    { "MaxRows"            , 5        , nonNegativeIntegerQ                 , "a non-negative integer" },
    { "DistributedContexts", Automatic, MatchQ[ Automatic | None | All | _String | { ___String } ], "Automatic ($DistributedContexts), None, All, a context or a list of contexts" }
} ];

ParallelCapture[ f_, list_List, opts: OptionsPattern[ ] ] /; validOptionsQ[ ParallelCapture, { opts } ] :=
    parallelCapture[ f, list, optionsAssociation[ ParallelCapture, { opts } ] ];

ParallelCapture[ args___ ] := badCall[ ParallelCapture, HoldComplete @ args ];

parallelCapture[ f_, list_List, o_Association ] :=
    With[ { cap = $CaptureFunction },
        Module[ { dc, nk, ed, rows, bad, summary, max = o[ "MaxRows" ] },
            dc   = Replace[ o[ "DistributedContexts" ], Automatic :> $DistributedContexts ];
            ed   = EvaluationData @ ParallelMap[ cap[ f[ # ] ] &, list, DistributedContexts -> dc ];
            nk   = Length @ Kernels[ ];  (* after ParallelMap, which launches kernels on first use *)
            rows = Replace[ ed[ "Result" ], Except[ _List ] :> { } ];
            rows = MapThread[
                Function[ { in, row },
                    If[ AssociationQ @ row,
                        Join[
                            <| "Input" -> ShortString[ in, 80 ] |>,
                            KeyDrop[ row, "Result" ],
                            <| "MasterOnlyHeads" -> masterOnlyHeads @ row[ "Result" ] |>
                        ],
                        <| "Input" -> ShortString[ in, 80 ], "Raw" -> ShortString[ row, 200 ] |>
                    ]
                ],
                { Take[ list, UpTo @ Length @ rows ], rows }
            ];
            bad = Select[
                rows,
                Function[ r,
                    Or[
                        Lookup[ r, "Messages", { } ] =!= { },
                        TrueQ @ Lookup[ r, "Aborted", False ],
                        Lookup[ r, "Thrown", None ] =!= None,
                        Lookup[ r, "MasterOnlyHeads", { } ] =!= { },
                        KeyExistsQ[ r, "Raw" ]
                    ]
                ]
            ];
            summary = <|
                "Kernels"        -> nk,
                "Items"          -> Length @ list,
                "ReturnedRows"   -> Length @ rows,
                "KernelIDs"      -> Counts @ Lookup[ rows, "KernelID", Missing[ ] ],
                "RanInMaster"    -> Count[ rows, KeyValuePattern[ "KernelID" -> 0 ] ],
                "MasterMessages" -> Take[ Replace[ ed[ "MessagesText" ], Except[ _List ] -> { } ], UpTo[ 5 ] ],
                "ProblemCount"   -> Length @ bad,
                "Problems"       -> Take[ bad, UpTo[ max ] ],
                "FirstResults"   -> Take[ Lookup[ rows, "ResultString", Missing[ ] ], UpTo[ max ] ]
            |>;
            (* stacks are long: keep the stack only for the first problem *)
            If[ Length @ summary[ "Problems" ] > 1,
                summary[ "Problems" ] = Prepend[ KeyDrop[ #, "Stack" ] & /@ Rest @ summary[ "Problems" ], First @ summary[ "Problems" ] ]
            ];
            dropMasterContext @ summary
        ]
    ];

nonSystemSymbolQ = Function[ s, ! MatchQ[ Context @ Unevaluated @ s, $systemContexts ], HoldAllComplete ];
hasDefsQ = Function[ s, Or[ DownValues @ s =!= { }, SubValues @ s =!= { }, OwnValues @ s =!= { } ], HoldAllComplete ];

masterOnlyHeads[ held_HoldComplete ] := Take[
    DeleteDuplicates @ Cases[
        held,
        ( s_Symbol /; nonSystemSymbolQ @ s && hasDefsQ @ s )[ ___ ] :> fullSymbolName @ s,
        { 1, Infinity },
        Heads -> True
    ],
    UpTo[ 10 ]
];
masterOnlyHeads[ _ ] := { };

(* subkernels do not have the master's session context on $ContextPath, so names print fully qualified;
   RuleCondition: a plain Replace leaves the RHS unevaluated inside associations *)
dropMasterContext[ expr_ ] := With[ { c = $Context }, Replace[ expr, s_String :> RuleCondition @ StringReplace[ s, c -> "" ], { 0, Infinity } ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*KernelReport*)
KernelReport[ ] :=
    Module[ { ks, pids, kids, orphans },
        ks      = Kernels[ ];
        pids    = If[ ks === { }, { }, TimeConstrained[ Quiet @ ParallelEvaluate[ $ProcessID, DistributedContexts -> None ], 5, "TimedOut" ] ];
        kids    = childKernelProcesses[ ];
        orphans = If[ ListQ @ kids && ListQ @ pids,
            Select[ kids, Function[ line, ! MemberQ[ pids, ToExpression @ First @ StringSplit @ line ] ] ],
            Missing[ "Unknown" ]
        ];
        <|
            "MasterPID"             -> $ProcessID,
            "ThisKernelID"          -> If[ MemberQ[ $Packages, "Parallel`" ], $KernelID, 0 ],
            "Kernels"               -> Take[ kernelLabel /@ ks, UpTo[ 20 ] ],
            "SubkernelPIDs"         -> pids,
            "ChildKernels"          -> If[ ListQ @ kids, Take[ StringTake[ #, UpTo[ 120 ] ] & /@ kids, UpTo[ 20 ] ], kids ],
            "UntrackedChildKernels" -> If[ ListQ @ orphans, Take[ orphans, UpTo[ 20 ] ], orphans ],
            "Tasks"                 -> Length @ Tasks[ ]
        |>
    ];

KernelReport[ args__ ] := badCall[ KernelReport, HoldComplete @ args ];

(* the Parallel`Developer` functions are looked up at run time: Parallel` loads on first use *)
kernelLabel[ k_ ] := StringTake[
    ToString[ Symbol[ "Parallel`Developer`KernelName" ] @ k ] <> " id=" <> ToString[ Symbol[ "Parallel`Developer`KernelID" ] @ k ],
    UpTo[ 60 ]
];

(* WolframKernel processes whose parent is this kernel (ps; Missing in protected mode) *)
childKernelProcesses[ ] :=
    Module[ { r },
        r = If[ TrueQ @ Developer`$ProtectedMode, $Failed, Quiet @ RunProcess[ { "ps", "-o", "pid=,etime=,args=", "--ppid", ToString @ $ProcessID } ] ];
        If[ AssociationQ @ r,
            Select[ StringTrim /@ StringSplit[ r[ "StandardOutput" ], "\n" ], StringContainsQ[ "WolframKernel" ] ],
            Missing[ "RunProcessUnavailable" ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TaskReport*)
TaskReport[ ] :=
    With[ { tasks = Tasks[ ] },
        <|
            "Count" -> Length @ tasks,
            "Tasks" -> Map[
                Function[ t,
                    <|
                        "UUID"       -> StringTake[ ToString @ t[ "TaskUUID" ], UpTo[ 8 ] ],
                        "Status"     -> t[ "TaskStatus" ],
                        "Type"       -> t[ "TaskType" ],
                        "Expression" -> ShortString[ t[ "EvaluationExpression" ], 100 ],
                        "Runs"       -> If[ t[ "TaskType" ] === "Scheduled", { t[ "PreviousRunCount" ], t[ "TotalRunCount" ] }, None ]
                    |>
                ],
                Take[ tasks, UpTo[ 25 ] ]
            ]
        |>
    ];

TaskReport[ args__ ] := badCall[ TaskReport, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*SubmitAndWait*)
(* the task body runs under $CaptureFunction (its Abort/Throw would otherwise hit whatever evaluation is in progress) *)
SubmitAndWait // Attributes = { HoldFirst };

SubmitAndWait[ expr_ ] := SubmitAndWait[ expr, 10 ];

SubmitAndWait[ expr_, timeout_? positiveNumberQ ] :=
    With[ { cap = $CaptureFunction },
        Module[ { result = Missing[ "NotFinished" ], task, waited },
            task   = SessionSubmit[ result = cap @ expr ];
            (* WithCleanup: the task is also removed when an outer time limit stops the wait *)
            waited = WithCleanup[
                CheckAbort[ TimeConstrained[ TaskWait @ task; "Finished", timeout, "TimedOut" ], "Aborted" ],
                Quiet @ TaskRemove @ task
            ];
            If[ AssociationQ @ result,
                Append[ KeyDrop[ result, "Result" ], "Wait" -> waited ],
                <| "Wait" -> waited, "Result" -> result |>
            ]
        ]
    ];

SubmitAndWait[ args___ ] := badCall[ SubmitAndWait, HoldComplete @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cloud and HTTP*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*HTTPSummary*)
defineOptions[ HTTPSummary, { { "MaxLength", 300, positiveIntegerQ, "a positive integer" } } ];

HTTPSummary[ resp_? httpResponseQ, opts: OptionsPattern[ ] ] /; validOptionsQ[ HTTPSummary, { opts } ] :=
    With[ { ct = resp[ "ContentType" ] },
        <| "StatusCode" -> resp[ "StatusCode" ], "ContentType" -> ct, "Text" -> bodyText[ resp[ "Body" ], ct, OptionValue[ "MaxLength" ] ] |>
    ];

HTTPSummary[ resp_Association /; KeyExistsQ[ resp, "StatusCode" ], opts: OptionsPattern[ ] ] /; validOptionsQ[ HTTPSummary, { opts } ] :=
    With[ { ct = Lookup[ Association @ Replace[ Lookup[ resp, "Headers", { } ], Except[ { ___Rule } ] -> { } ], "content-type", Lookup[ resp, "ContentType", Missing[ ] ] ] },
        <| "StatusCode" -> resp[ "StatusCode" ], "ContentType" -> ct, "Text" -> bodyText[ Lookup[ resp, "Body", "" ], ct, OptionValue[ "MaxLength" ] ] |>
    ];

HTTPSummary[ f_Failure, opts: OptionsPattern[ ] ] /; validOptionsQ[ HTTPSummary, { opts } ] := <|
    "Failure" -> First @ f,
    "Text"    -> truncateString[ Quiet @ ToString @ f[ "Message" ], OptionValue[ "MaxLength" ] ],
    "URL"     -> Replace[ f, { Failure[ _, a_Association ] :> Lookup[ a, "URL", Missing[ ] ], _ -> Missing[ ] } ]
|>;

HTTPSummary[ args___ ] := badCall[ HTTPSummary, HoldComplete @ args ];

httpResponseQ[ x_ ] := headNameQ[ x, "HTTPResponse" ];

(* visible text of an HTML page: drop scripts, styles, comments and tags *)
pageText[ html_String ] := StringTrim @ StringReplace[
    StringDelete[
        html,
        { Shortest[ "<script" ~~ ___ ~~ "</script>" ], Shortest[ "<style" ~~ ___ ~~ "</style>" ], Shortest[ "<!--" ~~ ___ ~~ "-->" ], "<" ~~ Except[ ">" ] ... ~~ ">" }
    ],
    { Whitespace .. -> " ", "&lt;" -> "<", "&gt;" -> ">", "&quot;" -> "\"", "&amp;" -> "&", "&#39;" -> "'" }
];

bodyText[ body_String, ctype_, n_Integer ] := Which[
    StringQ @ ctype && StringContainsQ[ ctype, "html", IgnoreCase -> True ], truncateString[ pageText @ body, n ],
    StringQ @ ctype && StringContainsQ[ ctype, "json", IgnoreCase -> True ],
        truncateString[
            Replace[
                Quiet @ ExportString[ Quiet @ ImportString[ body, "RawJSON" ], "RawJSON", "Compact" -> True ],
                Except[ _String ] :> StringReplace[ body, Whitespace .. -> " " ]
            ],
            n
        ],
    True, truncateString[ StringReplace[ body, "\n" -> "\\n" ], n ]
];
bodyText[ body_, _, n_Integer ] := heldString[ HoldComplete @ body, n ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DebugHTTPResponse*)
(* GenerateHTTPResponse reproduces the status and body of a deployment locally, where messages and handlers work. It
   runs the body under EvaluationData, which eats every Throw: the collector is record-only. *)
defineOptions[ DebugHTTPResponse, {
    { "Method"          , "GET", StringQ            , "\"GET\" or \"POST\" (for a parameter list)" },
    { "MaxMessages"     , 10   , nonNegativeIntegerQ, "a non-negative integer" },
    { "StackFrames"     , 8    , nonNegativeIntegerQ, "a non-negative integer" },
    { "StringLength"    , 200  , positiveIntegerQ   , "a positive integer" },
    { "MaxLength"       , 300  , positiveIntegerQ   , "a positive integer" },
    { "SuppressPrinting", True , booleanQ           , "True or False" }
} ];

DebugHTTPResponse[ deployable_, request_? httpRequestSpecQ, opts: OptionsPattern[ ] ] /; validOptionsQ[ DebugHTTPResponse, { opts } ] :=
    debugHTTPResponse[ deployable, toRequest[ request, OptionValue[ "Method" ] ], optionsAssociation[ DebugHTTPResponse, { opts } ] ];

DebugHTTPResponse[ args___ ] := badCall[ DebugHTTPResponse, HoldComplete @ args ];

httpRequestSpecQ[ x_ ] := headNameQ[ x, "HTTPRequest" ] || StringQ @ x || headNameQ[ x, "URL" ] || MatchQ[ x, _Association | { ___Rule } ];

toRequest[ url_String, _ ] := url;
toRequest[ params: ( _Association | { ___Rule } ), method_String ] :=
    With[ { rules = Normal @ Map[ Replace[ s: Except[ _String ] :> ToString @ s ], Association @ params ] },
        If[ ToUpperCase @ method === "GET",
            HTTPRequest[ "http://localhost/debug", <| "Query" -> rules |> ],
            HTTPRequest[ "http://localhost/debug", <| Method -> ToUpperCase @ method, "Body" -> rules |> ]
        ]
    ];
toRequest[ req_, _ ] := req;

debugHTTPResponse[ deployable_, req_, o_Association ] :=
    Module[ { t, r, resp, recs, out },
        { t, r } = AbsoluteTiming @ collectMessagesCore[
            HoldComplete @ GenerateHTTPResponse[ deployable, req ],
            <|
                "MaxMessages"      -> o[ "MaxMessages" ],
                "StackFrames"      -> o[ "StackFrames" ],
                "StringLength"     -> o[ "StringLength" ],
                "SuppressPrinting" -> o[ "SuppressPrinting" ],
                "StackStart"       -> "UserCode"  (* skip the ~40 framework frames before the user code *)
            |>
        ];
        resp = Replace[ r[ "Result" ], HoldComplete[ v_ ] :> v ];
        recs = r[ "Messages" ];
        out = If[ httpResponseQ @ resp,
            HTTPSummary[ resp, "MaxLength" -> o[ "MaxLength" ] ],
            <| "Result" -> heldString[ r[ "Result" ], o[ "MaxLength" ] ] |>
        ];
        Join[
            out,
            <|
                "Seconds"           -> Round[ t, 0.001 ],
                "MessageCount"      -> r[ "MessageCount" ],
                "Messages"          -> ( KeyDrop[ #, "Stack" ] & /@ recs ),
                "FirstMessageStack" -> If[ recs === { }, { }, First[ recs ][ "Stack" ] ]
            |>
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*HTTPDiagnostics*)
(* The body wrapper for deployed APIFunction/Delayed/FormFunction code: message handlers, Stack, StackBegin,
   ScheduledTask sampling and TimeConstrained work in deployed kernels (Trace does not). Returns the value of expr
   unchanged, or a JSON diagnostics response on failure, or with "Debug" -> Automatic when the request has debug=1.
   The response goes to whoever made the request, so it is meant for deployments that only the owner can call. *)
HTTPDiagnostics // Attributes = { HoldFirst };

defineOptions[ HTTPDiagnostics, {
    { "Debug"         , False    , MatchQ[ Automatic | True | False ], "False, True or Automatic (on when the request has <DebugParameter>=1, true or yes)" },
    { "DebugParameter", "debug"  , StringQ                           , "a string" },
    { "FailOnMessages", True     , booleanQ                          , "True or False" },
    { "TimeLimit"     , None     , MatchQ[ None | _? positiveNumberQ ], "None or a positive number of seconds (keep it below the deployment limit)" },
    { "StatusCode"    , 500      , positiveIntegerQ                  , "a positive integer" },
    { "StackFrames"   , 8        , nonNegativeIntegerQ               , "a non-negative integer" },
    { "MaxMessages"   , 10       , nonNegativeIntegerQ               , "a non-negative integer" },
    { "StringLength"  , 200      , positiveIntegerQ                  , "a positive integer" },
    { "MaxPrints"     , 10       , nonNegativeIntegerQ               , "a non-negative integer" },
    { "Log"           , None     , anyValueQ                         , "None, a CloudObject or a file name (PutAppend of one association per diagnostics response)" }
} ];

HTTPDiagnostics[ expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ HTTPDiagnostics, { opts } ] :=
    httpDiagnostics[ HoldComplete @ expr, optionsAssociation[ HTTPDiagnostics, { opts } ] ];

HTTPDiagnostics[ args___ ] := badCall[ HTTPDiagnostics, HoldComplete @ args ];

httpDiagnostics[ HoldComplete[ expr_ ], o_Association ] :=
    Module[ { n, k, lim, prints, printHandler, debugQ, sampler, lastSample, t, r, res, recs, reason, diag },
        n          = o[ "StringLength" ];
        k          = o[ "StackFrames" ];
        lim        = o[ "TimeLimit" ];
        prints     = Internal`Bag[ ];
        lastSample = { };
        sampler    = None;
        (* Print output of deployed code is otherwise lost; the "Wolfram.System.Print" handler sees it *)
        printHandler = Function[ h,
            If[ Internal`BagLength @ prints < o[ "MaxPrints" ],
                Internal`StuffBag[ prints, truncateString[ StringJoin[ ToString /@ ( List @@ h ) ], n ] ]
            ]
        ];
        debugQ = Replace[ o[ "Debug" ], Automatic :> debugRequestedQ @ o[ "DebugParameter" ] ];
        If[ positiveNumberQ @ lim,  (* sample the stack, so that a time-out still says where it was *)
            sampler = Quiet @ SessionSubmit @ ScheduledTask[ lastSample = Stack[ _ ], { Max[ lim / 4., 0.2 ], 40 } ]
        ];
        { t, r } = WithCleanup[
            AbsoluteTiming @ Internal`HandlerBlock[
                { "Wolfram.System.Print", printHandler },
                collectMessagesCore[
                    HoldComplete @ expr,
                    <|
                        "MaxMessages"    -> o[ "MaxMessages" ],
                        "StackFrames"    -> k,
                        "StringLength"   -> n,
                        "StackStart"     -> "UserCode",
                        "TimeConstraint" -> lim
                    |>
                ]
            ],
            If[ sampler =!= None, Quiet @ TaskRemove @ sampler ]
        ];
        res    = r[ "Result" ];
        recs   = r[ "Messages" ];
        reason = failureReason[ res, recs, o[ "FailOnMessages" ] ];
        If[ reason === None && ! TrueQ @ debugQ,
            Replace[ res, HoldComplete[ v_ ] :> v ],  (* the normal value, unchanged *)
            diag = <|
                "Success"     -> reason === None,
                "Reason"      -> Replace[ reason, None -> "DebugRequested" ],
                "Result"      -> heldString[ res, n ],
                "Messages"    -> ( KeyDrop[ #, "Stack" ] & /@ recs ),
                "Output"      -> Internal`BagPart[ prints, All ],
                "Stack"       -> Which[
                    recs =!= { } && First[ recs ][ "Stack" ] =!= { }, First[ recs ][ "Stack" ],
                    reason === "TimedOut" && lastSample =!= { },
                        frameStrings[
                            DeleteCases[ TakeWhile[ lastSample, FreeQ[ #, HoldPattern @ lastSample ] & ], _? wrapperFrameQ ],
                            k,
                            n
                        ],
                    True, { }
                ],
                "Seconds"     -> Round[ t, 0.001 ],
                "Environment" -> requestEnvironment[ ],
                "Request"     -> requestInfo @ n
            |>;
            If[ o[ "Log" ] =!= None,
                Quiet @ PutAppend[ Append[ diag, "Time" -> DateString[ "ISODateTime", TimeZone -> 0 ] ], o[ "Log" ] ]
            ];
            HTTPResponse[
                ExportString[ jsonSafe @ diag, "RawJSON", "Compact" -> True ],
                <| "StatusCode" -> If[ reason === None, 200, o[ "StatusCode" ] ], "ContentType" -> "application/json" |>
            ]
        ]
    ];

failureReason[ res_, records_List, failOnMsgs_ ] := Which[
    MatchQ[ res, HoldComplete[ Failure[ "UncaughtThrow", _ ] ] ], "UncaughtThrow",
    res === HoldComplete @ $Aborted                              , "Aborted",
    res === HoldComplete @ $TimedOut                             , "TimedOut",
    MatchQ[ res, HoldComplete[ _Failure | $Failed ] ]            , "FailureResult",
    TrueQ @ failOnMsgs && records =!= { }                        , "Messages",
    True                                                         , None
];

(* the evaluation cache does not see that HTTPRequestData depends on the request: without the Update, results computed
   outside a request (HTTPDiagnostics called locally) were reused by later requests *)
requestData[ prop_String ] := ( Update @ HTTPRequestData; Quiet @ HTTPRequestData @ prop );

requestParams[ ] := Join[
    Replace[ requestData[ "Query" ], Except[ { ___Rule } ] -> { } ],
    Replace[ requestData[ "FormRules" ], Except[ { ___Rule } ] -> { } ]
];

debugRequestedQ[ name_String ] := MemberQ[ { "1", "true", "yes" }, ToLowerCase @ ToString @ Lookup[ requestParams[ ], name, "" ] ];

requestEnvironment[ ] := Quiet @ <|
    "EvaluationEnvironment" -> $EvaluationEnvironment,
    "CloudEvaluation"       -> $CloudEvaluation,
    "Version"               -> First @ StringSplit @ $Version,
    "ProcessID"             -> $ProcessID,
    "TimeRemaining"         -> Replace[ Internal`TimeRemaining[ ], r_? NumericQ :> Round[ r, 0.1 ] ],
    "MemoryInUseMB"         -> Round[ MemoryInUse[ ] / 2.^20 ]
|>;

requestInfo[ n_Integer ] := Quiet @ <|
    "Method"     -> Replace[ requestData[ "Method" ], Except[ _String ] -> Missing[ ] ],
    "Path"       -> Replace[ requestData[ "PathString" ], Except[ _String ] -> Missing[ ] ],
    "Parameters" -> Map[ If[ StringQ @ #, truncateString[ #, n ], heldString[ HoldComplete @ #, n ] ] &, Association @ requestParams[ ] ]
|>;

(* make every leaf JSON-exportable (Infinity, Missing, symbols, rationals, HoldForm ... become strings or null) *)
jsonSafe[ a_Association ] := jsonSafe /@ a;
jsonSafe[ l_List ] := jsonSafe /@ l;
jsonSafe[ x: ( _String | _Integer | True | False | Null ) ] := x;
jsonSafe[ x_Real ] := x;
jsonSafe[ _Missing ] := Null;
jsonSafe[ ( HoldForm | HoldComplete )[ x_ ] ] := heldString[ HoldComplete @ x, 200 ];
jsonSafe[ x_ ] := heldString[ HoldComplete @ x, 200 ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WithHTTPLog*)
(* URLRead, URLExecute, CloudGet/CloudPut go through URLFetch; Import[url] and URLDownload through URLSave *)
WithHTTPLog // Attributes = { HoldFirst };

defineOptions[ WithHTTPLog, {
    { "MaxRequests", 50 , nonNegativeIntegerQ, "a non-negative integer" },
    { "URLLength"  , 120, positiveIntegerQ   , "a positive integer" },
    $resultOptionSpec
} ];

WithHTTPLog[ expr_, opts: OptionsPattern[ ] ] /; validOptionsQ[ WithHTTPLog, { opts } ] :=
    withHTTPLog[ HoldComplete @ expr, optionsAssociation[ WithHTTPLog, { opts } ] ];

WithHTTPLog[ args___ ] := badCall[ WithHTTPLog, HoldComplete @ args ];

withHTTPLog[ HoldComplete[ expr_ ], o_Association ] :=
    Module[ { log, inSpy, res, max, n, count, record },
        log   = Internal`Bag[ ];
        inSpy = False;
        count = 0;
        max   = o[ "MaxRequests" ];
        n     = o[ "URLLength" ];
        ensureLoaded @ { URLFetch, URLSave };  (* autoload stubs must load before the InheritedBlock *)
        record[ fn_, url_, elements_, rest_, r_, t_ ] := If[ ++count <= max,
            Internal`StuffBag[ log, <|
                "Function" -> fn,
                "Method"   -> methodFrom @ rest,
                "URL"      -> urlString[ url, n ],
                "Status"   -> statusFrom[ elements, r ],
                "Seconds"  -> Round[ t, 0.001 ]
            |> ]
        ];
        (* :!CodeAnalysis::BeginBlock:: *)
        (* :!CodeAnalysis::Disable::ShadowedVariable::Block:: *)
        res = Internal`InheritedBlock[ { URLFetch, URLSave },
            Unprotect[ URLFetch, URLSave ];
            PrependTo[
                DownValues @ URLFetch,
                HoldPattern[ URLFetch[ url_, elements_ : "Content", rest___ ] /; ! inSpy ] :>
                    Block[ { inSpy = True },
                        Module[ { t, r },
                            { t, r } = AbsoluteTiming @ URLFetch[ url, elements, rest ];
                            record[ "URLFetch", url, elements, { rest }, r, t ];
                            r
                        ]
                    ]
            ];
            PrependTo[
                DownValues @ URLSave,
                HoldPattern[ URLSave[ url_, file_, elements_ : "File", rest___ ] /; ! inSpy ] :>
                    Block[ { inSpy = True },
                        Module[ { t, r },
                            { t, r } = AbsoluteTiming @ URLSave[ url, file, elements, rest ];
                            record[ "URLSave", url, elements, { rest }, r, t ];
                            r
                        ]
                    ]
            ];
            evaluateContained @ expr
        ];
        (* :!CodeAnalysis::EndBlock:: *)
        <| "Result" -> boundedResult[ res, o[ "MaxResultBytes" ] ], "RequestCount" -> count, "Requests" -> Internal`BagPart[ log, All ] |>
    ];

statusFrom[ elements_, result_ ] := Which[
    elements === "StatusCode", result,
    ListQ @ elements && ListQ @ result && MemberQ[ elements, "StatusCode" ] && Length @ result === Length @ elements,
        result[[ First @ FirstPosition[ elements, "StatusCode" ] ]],
    result === $Failed, $Failed,
    True, Missing[ ]
];

methodFrom[ opts_ ] := FirstCase[ opts, ( ( "Method" | Method ) -> m_String ) :> m, "GET", Infinity ];

urlString[ url_, n_ ] := truncateString[
    Replace[ url, { u_String :> u, ( CloudObject | HTTPRequest )[ u_String, ___ ] :> u, e_ :> heldString[ HoldComplete @ e, n ] } ],
    n
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Headless and Environments*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*EnvironmentFingerprint*)
(* Saved with Put in one environment and compared with FingerprintDiff in another. "CloudConnected" is opt-in: the
   first access of $CloudConnected can take ~3 s. *)
defineOptions[ EnvironmentFingerprint, {
    { "Paclets", { "Wolfram/Chatbook", "Wolfram/AgentTools", "CloudObject", "PacletManager" }, stringListQ, "a list of paclet names" }
} ];

$defaultFingerprintKeys = {
    "Kind", "Version", "SystemID", "EvaluationEnvironment", "CommandLineFlags", "ProtectedMode", "FrontEnd", "InitFiles",
    "Context", "ContextPath", "PathExtras", "PathLength", "Directories", "Encoding", "Locale", "EnvironmentVariableCount",
    "Persistence", "Limits", "Hooks", "Handlers", "OffGeneralMessages", "PlotTheme", "OptionsHash", "TraceWorks", "Paclets",
    "LoadedCounts", "ProcessID", "SessionTime", "MemoryMB"
};

$allFingerprintKeys = Append[ $defaultFingerprintKeys, "CloudConnected" ];

EnvironmentFingerprint[ ] := EnvironmentFingerprint @ $defaultFingerprintKeys;

EnvironmentFingerprint[ All, opts: OptionsPattern[ ] ] /; validOptionsQ[ EnvironmentFingerprint, { opts } ] :=
    EnvironmentFingerprint[ $allFingerprintKeys, opts ];

EnvironmentFingerprint[ key_String, opts: OptionsPattern[ ] ] /; validOptionsQ[ EnvironmentFingerprint, { opts } ] :=
    EnvironmentFingerprint[ { key }, opts ];

EnvironmentFingerprint[ keys: { ___String }, opts: OptionsPattern[ ] ] /;
    SubsetQ[ $allFingerprintKeys, keys ] && validOptionsQ[ EnvironmentFingerprint, { opts } ] :=
        With[ { paclets = OptionValue[ "Paclets" ] },
            Association @ Map[ # -> fingerprintValue[ #, paclets ] &, keys ]
        ];

EnvironmentFingerprint[ args___ ] := badCall[ EnvironmentFingerprint, HoldComplete @ args ];

fingerprintValue[ "Kind", _ ] := environmentKind[ ];
fingerprintValue[ "Version", _ ] := StringRiffle[ ToString /@ { Floor @ $VersionNumber, Round[ 10 * FractionalPart @ $VersionNumber ], $ReleaseNumber }, "." ];
fingerprintValue[ "SystemID", _ ] := $SystemID;
fingerprintValue[ "EvaluationEnvironment", _ ] := $EvaluationEnvironment;
fingerprintValue[ "CommandLineFlags", _ ] := Select[ ToString /@ $CommandLine, StringStartsQ[ #, "-" ] && StringLength @ # < 25 & ];
fingerprintValue[ "ProtectedMode", _ ] := TrueQ @ Developer`$ProtectedMode;
fingerprintValue[ "FrontEnd", _ ] := <|
    "Notebooks"      -> TrueQ @ $Notebooks,
    "FrontEndObject" -> Head @ $FrontEnd === FrontEndObject,
    "HeadlessFELink" -> frontEndLinkQ[ ]
|>;
fingerprintValue[ "InitFiles", _ ] := Select[
    $LoadedFiles,
    Or[
        StringMatchQ[ FileNameTake @ #, "init.m" | "init.wl" ] && ! StringStartsQ[ #, $InstallationDirectory ],
        StringEndsQ[ #, "InitializationValue.mx" ],
        StringContainsQ[ #, { "/Kernel/Persistence/", "KernelInit" } ] && ! StringStartsQ[ #, $InstallationDirectory ]
    ] &
];
fingerprintValue[ "Context", _ ] := $Context;
fingerprintValue[ "ContextPath", _ ] := $ContextPath;
fingerprintValue[ "PathExtras", _ ] := Select[
    $Path,
    ! StringStartsQ[ #, $InstallationDirectory ] && ! MemberQ[
        {
            FileNameJoin @ { $UserBaseDirectory, "Kernel" }, FileNameJoin @ { $UserBaseDirectory, "Autoload" },
            FileNameJoin @ { $UserBaseDirectory, "Applications" }, FileNameJoin @ { $BaseDirectory, "Kernel" },
            FileNameJoin @ { $BaseDirectory, "Autoload" }, FileNameJoin @ { $BaseDirectory, "Applications" },
            ".", $HomeDirectory, $TemporaryDirectory
        },
        #
    ] &
];
fingerprintValue[ "PathLength", _ ] := Length @ $Path;
fingerprintValue[ "Directories", _ ] := <|
    "Directory"          -> Directory[ ],
    "InputFileName"      -> $InputFileName,
    "HomeDirectory"      -> $HomeDirectory,
    "UserBaseDirectory"  -> $UserBaseDirectory,
    "BaseDirectory"      -> $BaseDirectory,
    "TemporaryDirectory" -> $TemporaryDirectory
|>;
fingerprintValue[ "Encoding", _ ] := <| "CharacterEncoding" -> $CharacterEncoding, "SystemCharacterEncoding" -> $SystemCharacterEncoding |>;
fingerprintValue[ "Locale", _ ] := <|
    "TimeZone" -> $TimeZone,
    "Language" -> $Language,
    "LANG"     -> Environment[ "LANG" ],
    "LC_ALL"   -> Environment[ "LC_ALL" ],
    "TZ"       -> Environment[ "TZ" ]
|>;
fingerprintValue[ "EnvironmentVariableCount", _ ] := Length @ GetEnvironment[ ];
fingerprintValue[ "Persistence", _ ] := <|
    "Path"      -> Replace[ $PersistencePath, Verbatim[ PersistenceLocation ][ t_, ___ ] :> t, { 1 } ],
    "Base"      -> Replace[ $PersistenceBase, Verbatim[ PersistenceLocation ][ t_, ___ ] :> t ],
    "LocalBase" -> $LocalBase
|>;
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
fingerprintValue[ "Limits", _ ] := <|
    "RecursionLimit"    -> $RecursionLimit,
    "IterationLimit"    -> $IterationLimit,
    "HistoryLength"     -> $HistoryLength,
    "MaxExtraPrecision" -> $MaxExtraPrecision,
    "TimeRemaining"     -> Internal`TimeRemaining[ ]
|>;
(* :!CodeAnalysis::EndBlock:: *)
fingerprintValue[ "Hooks", _ ] := Select[ { "$Pre", "$Post", "$PrePrint", "$PreRead", "$SyntaxHandler", "$NewSymbol", "$NewMessage" }, valueSetQ ];
fingerprintValue[ "Handlers", _ ] := Association @ Cases[ Internal`Handlers[ ], ( type_ -> l_List ) /; l =!= { } :> ( type -> Length @ l ) ];
fingerprintValue[ "OffGeneralMessages", _ ] := Sort @ Cases[
    Messages @ General,
    Verbatim[ RuleDelayed ][ Verbatim[ HoldPattern ][ HoldPattern @ MessageName[ General, tag_String ] ], _$Off ] :> tag
];
fingerprintValue[ "PlotTheme", _ ] := $PlotTheme;
fingerprintValue[ "OptionsHash", _ ] := Hash[ Options /@ { Plot, ListPlot, ListLinePlot, Plot3D, Graphics, Graphics3D, Style, NIntegrate, NDSolve, Export } ];
fingerprintValue[ "TraceWorks", _ ] := TraceAvailableQ[ ];
fingerprintValue[ "Paclets", paclets_ ] := AssociationMap[
    Function[ p, Replace[ Quiet @ PacletFind @ p, { { po_, ___ } :> po[ "Version" ], _ :> Missing[ "NotFound" ] } ] ],
    paclets
];
fingerprintValue[ "LoadedCounts", _ ] := <| "Packages" -> Length @ $Packages, "LoadedFiles" -> Length @ $LoadedFiles |>;
fingerprintValue[ "CloudConnected", _ ] := TrueQ @ $CloudConnected;
fingerprintValue[ "ProcessID", _ ] := $ProcessID;
fingerprintValue[ "SessionTime", _ ] := Round @ SessionTime[ ];
fingerprintValue[ "MemoryMB", _ ] := Round[ MemoryInUse[ ] / 2.^20 ];

valueSetQ[ name_String ] := ToExpression[ name, InputForm, Function[ s, ValueQ @ s, HoldAllComplete ] ];

frontEndLinkQ[ ] := AnyTrue[ Links[ ], StringContainsQ[ ToString @ First @ #, "WolframNB" ] & ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FingerprintDiff*)
$volatileFingerprintKeys = { "ProcessID", "SessionTime", "MemoryMB", "TimeRemaining", "LoadedCounts", "EnvironmentVariableCount" };

FingerprintDiff[ a_Association, b_Association ] := FingerprintDiff[ a, b, $volatileFingerprintKeys ];

FingerprintDiff[ a_Association, b_Association, ignore: { ___String } ] :=
    Module[ { fa, fb, keys },
        fa   = flattenKeys @ a;
        fb   = flattenKeys @ b;
        keys = Select[
            Union[ Keys @ fa, Keys @ fb ],
            Function[ k, NoneTrue[ ignore, StringMatchQ[ k, # | ( # ~~ "/" ~~ ___ ) | ( ___ ~~ "/" ~~ # ) ] & ] ]
        ];
        Association @ Map[
            Function[ k,
                With[ { va = Lookup[ fa, k, Missing[ "Absent" ] ], vb = Lookup[ fb, k, Missing[ "Absent" ] ] },
                    If[ va === vb,
                        Nothing,
                        k -> If[ ListQ @ va && ListQ @ vb,
                            <| "OnlyInA" -> Take[ Complement[ va, vb ], UpTo[ 10 ] ], "OnlyInB" -> Take[ Complement[ vb, va ], UpTo[ 10 ] ] |>,
                            { va, vb }
                        ]
                    ]
                ]
            ],
            keys
        ]
    ];

FingerprintDiff[ args___ ] := badCall[ FingerprintDiff, HoldComplete @ args ];

flattenKeys[ a_Association ] := flattenKeys[ a, "" ];
flattenKeys[ a_Association, prefix_String ] := Join @@ KeyValueMap[
    Function[ { k, v },
        With[ { key = If[ prefix === "", ToString @ k, prefix <> "/" <> ToString @ k ] },
            If[ AssociationQ @ v, flattenKeys[ v, key ], <| key -> v |> ]
        ]
    ],
    a
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FrontEndCalls*)
(* every front end request goes through MathLink`CallFrontEnd: a recording condition-only rule counts them *)
FrontEndCalls // Attributes = { HoldFirst };

FrontEndCalls[ expr_ ] := frontEndCalls[ HoldComplete @ expr, autoTimeLimit[ 60 ] ];
FrontEndCalls[ expr_, timeout_? positiveNumberQ ] := frontEndCalls[ HoldComplete @ expr, timeout ];
FrontEndCalls[ args___ ] := badCall[ FrontEndCalls, HoldComplete @ args ];

frontEndCalls[ HoldComplete[ expr_ ], timeout_ ] :=
    Module[ { calls, msgs, before, t, r },
        calls  = Internal`Bag[ ];
        msgs   = Internal`Bag[ ];
        before = frontEndLinkQ[ ];
        (* :!CodeAnalysis::BeginBlock:: *)
        (* :!CodeAnalysis::Disable::VariableError::Block:: *)
        { t, r } = AbsoluteTiming @ Internal`InheritedBlock[ { MathLink`CallFrontEnd },
            Unprotect @ MathLink`CallFrontEnd;
            PrependTo[
                DownValues @ MathLink`CallFrontEnd,
                HoldPattern[ MathLink`CallFrontEnd[ a_, ___ ] /; ( Internal`StuffBag[ calls, ToString @ Head @ Unevaluated @ a ]; False ) ] :> Null
            ];
            Internal`HandlerBlock[
                {
                    "Message",
                    Function[ m,
                        If[ MatchQ[ m, Hold[ Message[ MessageName[ FrontEndObject | Rasterize | Developer`UseFrontEnd | NotebookDirectory | NotebookFileName | Export, _ ], ___ ], _ ] ],
                            Internal`StuffBag[ msgs, messageNameString @ m <> If[ TrueQ @ Last @ m, "", " (quiet)" ] ]
                        ]
                    ]
                },
                evaluateContained @ TimeConstrained[ expr, timeout, $TimedOut ]
            ]
        ];
        (* :!CodeAnalysis::EndBlock:: *)
        <|
            "Result"           -> heldString[ r, 120 ],
            "FrontEndCalls"    -> Counts @ Internal`BagPart[ calls, All ],
            "FrontEndMessages" -> DeleteDuplicates @ Internal`BagPart[ msgs, All ],
            "LaunchedFrontEnd" -> ! before && frontEndLinkQ[ ],
            "Seconds"          -> Round[ t, 0.01 ]
        |>
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*RunIsolated*)
(* timeout -s KILL around wolframscript in a private working directory: leftover kernels (and their children, e.g.
   front ends) are found by their working directory and killed. Needs RunProcess, which protected mode blocks. *)
defineOptions[ RunIsolated, {
    { "TimeLimit" , 60       , positiveNumberQ                , "a positive number of seconds" },
    { "MaxOutput" , 2000     , nonNegativeIntegerQ            , "a non-negative integer" },
    { "Executable", Automatic, MatchQ[ Automatic | _String ] , "Automatic or the path of wolframscript" }
} ];

RunIsolated[ code_String, opts: OptionsPattern[ ] ] /; ! protectedModeQ[ ] && validOptionsQ[ RunIsolated, { opts } ] :=
    Module[ { dir, file },
        dir  = CreateDirectory[ ];  (* unique working directory: identifies leftover kernels afterwards *)
        file = FileNameJoin @ { dir, "isolated.wls" };
        WithCleanup[
            WriteString[ file, code ];
            Close @ file;
            runIsolated[ file, dir, optionsAssociation[ RunIsolated, { opts } ] ],
            Quiet @ DeleteDirectory[ dir, DeleteContents -> True ]
        ]
    ];

RunIsolated[ File[ file_? existingFileQ ], opts: OptionsPattern[ ] ] /; ! protectedModeQ[ ] && validOptionsQ[ RunIsolated, { opts } ] :=
    Module[ { dir },
        dir = CreateDirectory[ ];
        WithCleanup[
            runIsolated[ ExpandFileName @ file, dir, optionsAssociation[ RunIsolated, { opts } ] ],
            Quiet @ DeleteDirectory[ dir, DeleteContents -> True ]
        ]
    ];

RunIsolated[ args___ ] := If[ protectedModeQ[ ], protectedModeFailure @ RunIsolated, badCall[ RunIsolated, HoldComplete @ args ] ];

protectedModeQ[ ] := TrueQ @ Developer`$ProtectedMode;

protectedModeFailure[ f_Symbol ] := Failure[ "ProtectedMode", <|
    "MessageTemplate"   -> "`1` needs RunProcess, which protected mode (e.g. the MCP evaluator's Local method) blocks. Run wolframscript from a shell instead.",
    "MessageParameters" -> { "WolframDebugging`" <> SymbolName @ f }
|> ];

runIsolated[ file_String, dir_String, o_Association ] :=
    Module[ { exe, secs, res, code, left },
        exe = Replace[ o[ "Executable" ], Automatic :> findExecutable[ "wolframscript" ] ];
        { secs, res } = AbsoluteTiming @ RunProcess[
            { "timeout", "-s", "KILL", ToString @ Ceiling @ o[ "TimeLimit" ], exe, "-f", file },
            All,
            "",
            ProcessDirectory -> dir
        ];
        Pause[ 2 ];  (* a normally exiting kernel may still be shutting down *)
        left = killLeftovers @ dir;
        code = If[ AssociationQ @ res, res[ "ExitCode" ], $Failed ];
        <|
            "ExitCode"        -> code,
            "Status"          -> Which[
                ! IntegerQ @ code, "Failed",
                code == 0        , "OK",
                code == 124      , "TimedOut",
                code == 137      , "Killed",   (* SIGKILL from the time limit or from outside, e.g. the OOM killer *)
                code > 128       , "Crashed",  (* 139 = SIGSEGV, 134 = SIGABRT *)
                True             , "Failed"
            ],
            "Seconds"         -> Round[ secs, 0.1 ],
            "StdOut"          -> If[ AssociationQ @ res, stringTail[ res[ "StandardOutput" ], o[ "MaxOutput" ] ], "" ],
            "StdErr"          -> If[ AssociationQ @ res, stringTail[ res[ "StandardError" ], o[ "MaxOutput" ] ], "" ],
            "KilledLeftovers" -> left
        |>
    ];

findExecutable[ name_String ] := SelectFirst[
    { FileNameJoin @ { $InstallationDirectory, "Executables", name }, "/usr/local/bin/" <> name, "/usr/bin/" <> name },
    FileExistsQ,
    name
];

stringTail[ s_String, n_Integer ] := StringTake[ s, -Min[ n, StringLength @ s ] ];
stringTail[ _, _ ] := "";

(* kernels still running in the private working directory, plus all their descendants (front ends, converters) *)
killLeftovers[ dir_String ] :=
    Module[ { table, kernels, children, all },
        table   = Partition[ ToExpression /@ StringSplit @ RunProcess[ { "ps", "-eo", "pid=,ppid=" }, "StandardOutput" ], 2 ];
        kernels = Select[
            ToExpression /@ StringSplit @ RunProcess[ { "pgrep", "-x", "WolframKernel" }, "StandardOutput" ],
            StringTrim @ RunProcess[ { "readlink", "/proc/" <> ToString @ # <> "/cwd" }, "StandardOutput" ] === dir &
        ];
        children[ p_ ] := Cases[ table, { c_, p } :> c ];
        all = Union @ Flatten @ FixedPointList[ Union[ #, Flatten[ children /@ # ] ] &, kernels ];
        If[ all =!= { }, RunProcess @ Join[ { "kill", "-9" }, ToString /@ all ] ];
        all
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Static Checks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LintSummary*)
LintSummary[ code_ ] := LintSummary[ code, 0.5 ];

LintSummary[ code: _String | File[ _? existingFileQ ], minConf_? confidenceQ ] :=
    Module[ { lints },
        Block[ { $ContextPath }, Needs[ "CodeInspector`" ] ];
        lints = CodeInspector`CodeInspect[ code, ConfidenceLevel -> minConf ];
        lints = Select[ lints, ! MemberQ[ { "Formatting", "Remark" }, #[[ 3 ]] ] & ];
        If[ lints === { },
            "No issues.",
            StringRiffle[
                Map[
                    Function[ l,
                        With[ { pos = l[[ 4 ]][ CodeParser`Source ] },
                            StringJoin[
                                If[ MatchQ[ pos, { { _Integer, _Integer }, _ } ], "L" <> ToString @ pos[[ 1, 1 ]] <> ":" <> ToString @ pos[[ 1, 2 ]], "?" ],
                                " ", l[[ 1 ]], " (", l[[ 3 ]], " ", ToString @ l[[ 4 ]][ ConfidenceLevel ], ") ",
                                StringReplace[ l[[ 2 ]], "``" -> "`" ]
                            ]
                        ]
                    ],
                    Take[ SortBy[ lints, #[[ 4 ]][ CodeParser`Source ] & ], UpTo[ 50 ] ]
                ],
                "\n"
            ] <> If[ Length @ lints > 50, "\n... (" <> ToString @ Length @ lints <> " issues)", "" ]
        ]
    ];

LintSummary[ args___ ] := badCall[ LintSummary, HoldComplete @ args ];

confidenceQ[ x_ ] := NumericQ @ x && 0 <= x <= 1;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];

Protect[ "WolframDebugging`*" ];

EndPackage[ ];
