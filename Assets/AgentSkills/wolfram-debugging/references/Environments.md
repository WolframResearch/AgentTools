# Evaluation environments

How the places where Wolfram Language code can run differ when you debug: the MCP evaluator (Local and Session
methods), wolframscript, `wolfram -script`, CloudEvaluate, deployed APIs and the remote MCP server. Covers how to tell
where you are, the full behavior matrix, how to run code and load the helper package in each environment, what never to
do in a shared kernel, and how to keep output small. Read it first when something works in one place but not in another.
Behavior was checked with Wolfram 15.0 on Linux.

## The environments

| name | what runs your code | state between calls |
|---|---|---|
| MCP Local | WolframLanguageEvaluator with Method "Local": a protected-mode sandbox subkernel (`-noinit -pacletreadonly`) started by the MCP server and **shared by every session and agent of that server** | persists until the subkernel restarts (time-out of a non-abortable call, crash, `Quit[]`) |
| MCP Session | Method "Session", the default for installed local servers: **the MCP server's own kernel** | persists; definitions are restored from a session file after a server restart (loaded packages, handlers and `Off` settings are not) |
| wolframscript | `wolframscript -f file.wls` or `wolframscript -code '...'`: a fresh kernel per run, init files loaded | none |
| `wolfram -script` | a plain kernel running a file; the TestReport MCP tool runs tests this way (`-script .../TestReport.wls -noinit`) | none |
| CloudEvaluate | `CloudEvaluate[expr]` from any local kernel (also from MCP Local): a cloud kernel | none |
| deployed API | `APIFunction`/`Delayed`/`FormFunction` deployed with `CloudDeploy`: a fresh cloud kernel per request | none (see `CloudAndHTTP.md`) |
| remote MCP server | Method "Cloud" server such as `https://agenttools.wolfram.com/mcp`: a fresh cloud kernel per call, no `session` parameter | none |
| notebook | the desktop front end | persists (not covered by the checks in this skill) |

The wolfram-language skill's bundled `scripts/WolframLanguageEvaluator.wls` runs the evaluator tool inside a fresh
wolframscript kernel: Trace works, `$Context` is ``Sessions`<id>` ``, the time limit is 60 s, and passing
`--session <id>` from the previous run restores that run's definitions (not its loaded packages).

You cannot change the evaluator method from inside a call; it is part of the server configuration.

## Where am I? (run this first)

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
    "TraceWorks" -> (Trace[1 + 1] =!= {}),
    "ProtectedMode" -> TrueQ[Developer`$ProtectedMode],
    "Context" -> $Context,
    "PID" -> $ProcessID,
    "TimeRemaining" -> Round[Internal`TimeRemaining[], 0.1]|>]
```
```
MCP Local:         <|"Env" -> "MCP Local", "TraceWorks" -> True, "ProtectedMode" -> True, "Context" -> "Sessions`<id>`", "PID" -> ..., "TimeRemaining" -> 60.|>
MCP Session:       <|"Env" -> "MCP Session", "TraceWorks" -> False, "ProtectedMode" -> False, "Context" -> "Sessions`<id>`", "PID" -> ..., "TimeRemaining" -> 60.|>
wolframscript:     <|"Env" -> "wolframscript", "TraceWorks" -> True, "ProtectedMode" -> False, "Context" -> "Global`", "PID" -> ..., "TimeRemaining" -> Infinity|>
wolfram -script:   <|"Env" -> "wolfram -script", "TraceWorks" -> False, "ProtectedMode" -> False, "Context" -> "Global`", "PID" -> ..., "TimeRemaining" -> Infinity|>
CloudEvaluate:     <|"Env" -> "CloudEvaluate", "TraceWorks" -> False, "ProtectedMode" -> True, "Context" -> "Global`", "PID" -> ..., "TimeRemaining" -> 300.|>
remote MCP server: <|"Env" -> "deployed API or remote MCP server", "TraceWorks" -> False, "ProtectedMode" -> True, "Context" -> "Global`", "PID" -> ..., "TimeRemaining" -> 60.|>
```

The bundled skill script reports `"wolframscript"` with ``"Context" -> "Sessions`<id>`"`` and `"TimeRemaining" -> 60.`; the
TestReport MCP tool's kernel reports `"wolfram -script"`. A notebook falls through to `"Session"` (untested). Helper:
``WolframDebugging`EnvironmentInfo[]`` (adds the user contexts, whether the input runs under `Quiet`, and notes on what
that means); see `HelperFunctions.md`.

Gotchas:
- `$Notebooks` and `$FrontEnd` do not tell you whether a notebook exists: they are `True`/a `FrontEndObject` in the cloud
  and `False`/`Null` in MCP Local although a headless front end is attached there (see `HeadlessAndCrashes.md`).
- Detecting MCP Session by `$Context` alone fails inside `Begin[...]` or package code; check `$CommandLine` as above.
- ``Wolfram`AgentTools`$MCPEvaluationEnvironment`` is not a detector: it describes the server, is `None` in the Local
  subkernel, and mentioning it elsewhere creates the context.
- The first access of `$CloudConnected` takes about 3 s; keep it out of quick probes.
- On the remote MCP server every input runs inside `Quiet`: ``Lookup[Internal`QuietStatus[], "Global"]`` gives `"Quiet"`
  there. Do not wrap that call in `Quiet` (it then always says `"Quiet"`).

## The environment matrix

| behavior | MCP Local | MCP Session | wolframscript | `wolfram -script` | CloudEvaluate | deployed API | remote MCP server |
|---|---|---|---|---|---|---|---|
| `Trace`, `TraceScan`, `TracePrint`, `On[sym]` | work | **`{}`** | work | **`{}`** | **`{}`** | **`{}`** | **`{}`** |
| `$Context` | ``Sessions`<id>` `` | ``Sessions`<id>` `` | ``Global` `` | ``Global` `` | ``Global` `` | ``Global` `` | ``Global` `` |
| context of symbols typed in the code | ``Sessions`<id>` `` | ``Sessions`<id>` `` | ``Global` `` | ``Global` `` | ``Global` `` | ``Global` `` | ``Global` `` |
| symbols created at run time (`ToExpression`, `Get` of a plain file) | ``Sessions`<id>` `` | ``Sessions`<id>` `` | ``Global` `` | ``Global` `` | ``Global` `` | ``Global` `` | ``Global` `` |
| unqualified package symbol after `Get`/`Needs` | resolves from the next input (next line) | resolves from the next input (next line) | resolves from the next line of `-f` | next line | n/a | n/a | n/a |
| `Symbol::undefined` warning before evaluation | undefined upper-case names (not ones defined or localized in the same input) | same as MCP Local | no | no | no | no | upper-case ``Global` `` symbols |
| definitions persist across calls | yes (until a restart) | yes (restored after a restart) | no | no | no | no | no |
| `%`, `Out[n]` | work (one line number per input) | work (one line number per input) | no history | no history | no history | no history | no history |
| `Length[Stack[]]` as the whole input (1 = no wrapper frames) | 1 | 1 | 16 (about 90 KB of frames) | 2 | 65 | about 50 | 1 |
| `willPrint` flag of message handlers | normal | normal | normal | normal | normal | normal | **always `False`** |
| `$MessageList` reset | every input | **never** (server lifetime, all sessions; `General::stop` counts across calls) | once per script | once per script | every call | every request | every call |
| message after more than 10 prints + messages in one call | shown | **dropped** | shown | shown | relayed | lost | **dropped** |
| `Print` / `Echo` | shown with a `During evaluation of In[n]:=` prefix | same as MCP Local | stdout | stdout | **dropped** | lost | Print shown, **Echo dropped** |
| `Abort[]` in user code | `$Aborted`, Print kept, later inputs of the call skipped | same as MCP Local | **ends the whole script** (exit code 0) | **ends the whole script** (exit code 0) | `$Failed` + `CloudEvaluate::srverr` | HTTP 500, empty body | `$Aborted`, Print kept |
| tool time limit reached (it covers the whole call) | `Failure["EvaluationTimeExceeded", ...]` with `Out[n]=`, Print kept, later inputs skipped, state kept | same as MCP Local | no limit unless you add one | no limit | 300 s | 300 s (then HTTP 502) | only the Failure (Print lost) |
| time limit hit by a non-abortable call (`Run`, `AbortProtect`, long primitives) | subkernel killed about 20 s after the limit and restarted (22 s for a 3 s limit, 28 s for a 10 s limit); the Failure comes **without** `Out[n]=` and the Print output of the input that timed out without its label (earlier inputs of the call keep theirs); all state lost | the response arrives only when the call finishes: the Failure (`AbortProtect`), or for a blocking `Run` its normal result with the later inputs run; state kept | n/a | n/a | n/a | n/a | n/a |
| `$RecursionLimit` overflow | enclosing expression becomes `TerminatedEvaluation["RecursionLimit"]` | same | **ends the whole script** | a statement ending in `;` is dropped, otherwise like MCP Local; later lines run | uncaught `Throw` | not checked | like MCP Local |
| `Quit[]`, `Exit[]` | **kills the shared subkernel**: only a `General::quit` message comes back, new PID, everyone's state lost | intercepted (`General::quit`), later inputs skipped, state kept | exits | exits | no-op | not checked | `General::quit`, rest of the input skipped |
| `Input`, `InputString`, `Dialog`, `ChoiceDialog` | `InputString`: **no response at all**, whatever the time limit (none within 240 s with a 10 s limit) | `InputString`: **server hangs** (no response, limit ignored) | `InputString`: `EndOfFile` with stdin `/dev/null`, blocks forever on an open silent stdin; `ChoiceDialog` prints its prompt in a loop | EOF | not checked | not checked | not checked |
| `WriteString["stdout", ...]`, `Run[...]` | shown / `$Failed` | **corrupt the JSON-RPC stream** | stdout | stdout | n/a | n/a | n/a |
| protected mode: `Run`, `RunProcess`, `StartProcess`, `LaunchKernels`, `LocalSubmit` blocked | yes | no | no | no | yes | yes | yes |
| file writes | only below `$TemporaryDirectory`, others give a silent `$Failed` | anywhere | anywhere | anywhere | persistent cloud user files | persistent cloud user files | a throwaway directory |
| global settings, handlers, `Off[...]` | leak to every session and agent | leak to every session and the server itself; can kill it | this run | this run | this call | this request | this call |
| first-time effects (autoloads, first package load) | rarely (many packages preloaded) | rarely | yes | yes | rarely | rarely | rarely |
| `init.m`, `InitializationValue` | not loaded (`-noinit`) | not loaded (`-noinit`) | loaded ("Script" values) | loaded ("Session" values) | not loaded | not loaded | not loaded |
| front end for `Rasterize`/`Export` | pre-launched with the subkernel | launched on first use (5-10 s) | launched on first use | launched on first use | built in (default 144 dpi) | built in | built in |
| SymbolDefinition MCP tool | same kernel; name ``Sessions`<id>`f`` | same kernel; name ``Sessions`<id>`f`` | n/a | n/a | n/a | n/a | not offered |
| ``Internal`TimeRemaining[]`` | about 60 | about 60 | `Infinity` | `Infinity` | 300 | 300 | about 60 |

How to use the matrix:
- Trace: check `Trace[1 + 1] =!= {}` first. Where it is `{}`, use message handlers with `Stack`, ``Internal`InheritedBlock``
  spies or stack sampling (`MessagesAndStacks.md`, `OverridesAndWatchpoints.md`, `TracingAndPerformance.md`), or run the
  Trace in wolframscript.
- `$MessageList`: use `Block[{$MessageList = {}}, expr]` when you count messages (it is Protected; assigning fails).
- Out history: `%` and `Out[n]` work in the MCP evaluator, but every input of a call gets its own line number, so
  assign results to variables instead of counting lines.
- MCP Local prints your unevaluated symbols in the `Out[n]=` text with their full context
  (``Out[1]= Sessions`<id>`f[Sessions`<id>`x]``, while `ToString[f[x]]` gives `"f[x]"`); MCP Session prints `f[x]`.
- Fresh kernel: where you would `Quit[]` in a notebook to start over, never do that in MCP; run the code in wolframscript
  instead. First-time effects (autoloading, package loading events, ``GeneralUtilities`TraceLoading`` output) only show
  there, because MCP kernels have already loaded many packages.
- Time limits and aborts: return diagnostics as the value of the call, not as `Print` output (see "Output budget").
- After a time-out or a crash in MCP Local, check `{$ProcessID, SessionTime[]}`: a new PID (or a small `SessionTime[]`)
  means the subkernel was restarted and all definitions are gone. `Out[n]` keeps counting, so the line number does not
  show it.
- The remote MCP server quiets everything: wrap the code under test in `Quiet[expr, None, All]` to see real `willPrint`
  flags and to make `EvaluationData` and `VerificationTest` record messages (`Check` catches them even without it):
  `EvaluationData[1/0; 2]["MessagesExpressions"]` gives `{}` there, `Quiet[EvaluationData[1/0; 2], None, All]["MessagesExpressions"]`
  gives `{Hold[Message[Power::infy, HoldCompleteForm[0^(-1)]]]}`.

Contain a `$RecursionLimit` overflow with `Catch` (this gave the same result in MCP Local, MCP Session, wolframscript,
`wolfram -script`, CloudEvaluate and the remote MCP server):

```wl
ClearAll[rec]; rec[n_] := rec[n + 1] + 1;
{Catch[Block[{$RecursionLimit = 50}, rec[0]], _TerminatedEvaluation, Function[{v, tag}, Failure["RecursionLimit", <|"Tag" -> tag|>]]], "after"}
(* $RecursionLimit::reclim: Recursion depth of 50 exceeded.
   {Failure["RecursionLimit", <|"Tag" -> TerminatedEvaluation["RecursionLimit", 50]|>], "after"} *)
```

In the MCP evaluators the `Catch` does not see the overflow when it is the whole input or sits directly inside `If`,
`With` or the right-hand side of a function you call: it returns `TerminatedEvaluation["RecursionLimit"]` without
calling its handler. Inside a list, `res = Catch[...]; ...`, `Module`, `Block`, `Table`, another `Catch` or as a
function argument it works (checked in both methods), so also test the value (`MessagesAndStacks.md`). In
CloudEvaluate the 64 wrapper frames count toward the limit: `Block[{$RecursionLimit = 50}, 1 + 1]` already overflows
there.

**MCP Local: never let the first message of a fresh subkernel happen under a low `$RecursionLimit`.** The first message
the subkernel prints makes the evaluator load packages inside your evaluation. Under a limit of 30 or 50 that load fails:
`Block[{$RecursionLimit = 30}, Message[General::argx, f, 2]; 1]` returned `TerminatedEvaluation["RecursionLimit"]`
instead of `1`, and `$Context` stayed ``EntityFramework`Private` `` (``WolframAlphaClient`Private` `` in another run)
for every later call of every session, so new symbols went there. A quieted overflow did no harm, and after one ordinary
message (`1/0;` in an earlier call) the same code was safe. MCP Session was not affected.

## Where your symbols live

```wl
ClearAll[demoFn];
demoFn[x_] := x;
{$Context, Context[demoFn], MemberQ[{"Global`", $Context}, Context[demoFn]]}
(* MCP Local, MCP Session: {"Sessions`<id>`", "Sessions`<id>`", True}
   wolframscript, CloudEvaluate, remote MCP server: {"Global`", "Global`", True} *)
```

- Each MCP evaluator session has its own context ``Sessions`<id>` ``, its `$Context`, and does not see the definitions
  of other sessions. Code meant for several environments should accept both user contexts: filter user symbols with
  ``MemberQ[{"Global`", $Context}, Context[s]]`` (``Context[s] === "Global`"`` misses them in the MCP evaluator), and
  put both on the context path when you format expressions (below).
- In MCP Local one subkernel runs every session: definitions stay separate, but global settings, handlers, loaded
  packages and symbols with an explicit context (``Global`x``, ``dbg`f``) are shared.
- When a Chatbook update is installed in the user paclet directory (checked with Chatbook 2.7, whose installer paclet
  loads it at every kernel start, also with `-noinit`), wolframscript and `wolfram -script` start with
  ``Wolfram`Chatbook` `` on `$ContextPath` (with an empty user base directory `wolfram -script` had only
  ``{"System`", "Global`"}``). Defining a function whose name is one of the roughly 100 exported Chatbook symbols then
  fails; check with ``MemberQ[$ContextPath, "Wolfram`Chatbook`"]``:
  ```wl
  CellToString[x_] := x + 1; {CellToString[1], Context[CellToString]}
  (* wolframscript, wolfram -script:
       SetDelayed::write: Tag CellToString in CellToString[x_] is Protected.
       {"1", "Wolfram`Chatbook`"}
     MCP Local, MCP Session: {2, "Sessions`<id>`"}       remote MCP server: {2, "Global`"} *)
  ```
- When strings are made from expressions, symbols of a context that is not on `$ContextPath` print with their context.
  Put both user contexts on the context path while formatting:
  ```wl
  Block[{$ContextPath = Join[{"Global`", $Context}, $ContextPath]}, ToString[Hold[demoX[1]], InputForm]]
  (* "Hold[demoX[1]]" *)
  ```
- SymbolDefinition MCP tool: give the full name, ``Sessions`<id>`demoFn``. A bare name returns "does not exist" plus a
  "Did you mean" list that contains the right full name.

## Each input is parsed just before it runs

The MCP evaluator splits the code of a tool call into top-level inputs (a line, or an expression that spans several
lines) and parses each one right before it is evaluated, after the inputs before it have run. A `-f` file works the
same way; a `-code` string is one input. Each input gets its own `In[n]`; an `Out[n]=` is shown only for an input that
does not end in `;` and whose result is not `Null` (when no output would be shown at all, the last one is).

So a `Get` or `Needs` on its own line makes short names work from the next line on, but a name in the same input as
the `Get` is created in the current context first. With a small package `EnvDemo.wl` (``BeginPackage["EnvDemo`"]``,
exported `square[x_] := x^2`), one tool call:

```wl
Get["/tmp/EnvDemo.wl"]
{EnvDemo`square[3], square[3], Context[square]}
(* MCP Local, MCP Session, two lines of a -f script: {9, 9, "EnvDemo`"} *)
```

`Get[...]; square[3]` as one input leaves ``Sessions`<id>`square[3]`` unevaluated in the MCP evaluator (in a `-f`
script: `square::shdw` and ``Global`square[3]``). A fully qualified name works everywhere, even in the same input as the
`Get`. So: load on its own line (or in its own call), and call package functions by their full names.

The inputs of a call run one after the other. `Abort[]`, the time limit (which covers the whole call) and `Quit[]` stop
the remaining inputs; an uncaught `Throw` only ends its own input:

```wl
Print["a"]
Throw[1]
"after"
(* MCP Local, MCP Session:
   During evaluation of In[1]:= a
   Throw::nocatch: Uncaught Throw[1] returned to top level.
   Out[2]= Hold[Throw[1]]
   Out[3]= "after" *)
```

The MCP evaluator also repairs incomplete input without a warning: a missing `]`, `}` or `)` is added at the end of the
line where appending it at the very end would join two lines into an implicit multiplication. Usually that is what you
meant; wolframscript reports the syntax error instead.

```wl
envF[x_] := Module[{y},
  y = x + 1
envF[2]
(* MCP Local, MCP Session: Out[n]= 3, and the definition is envF[x_] := Module[{y}, y = x + 1] *)
```

`{1, 2` gives `{1, 2}` the same way. Check pasted code with the CodeInspector MCP tool when results look impossible (see
`HeadlessAndCrashes.md`).

## Running code in each environment

**MCP evaluator tool.** Omit `session` on the first call and pass the returned id afterwards (this keeps your
definitions, `$Context` and `In`/`Out` history). Give long probes an inner limit below the tool limit so that you get
partial results back:

```wl
TimeConstrained[Pause[3]; "finished", Min[1, Internal`TimeRemaining[] - 10], $TimedOut]
(* $TimedOut *)
```

**wolframscript.**
- `-code '...'` runs one input and prints the result in OutputForm (strings lose their quotes):
  `wolframscript -code '{2, "s", 1/2}'` prints `{2, s, 1/2}`; add `-format InputForm` to get `{2, "s", 1/2}`.
- `-f file.wls` prints only explicit `Print` output (`-print` prints the last result, `-print all` every non-Null one).
  Each top-level expression is parsed after the previous one ran, but the file is one evaluation: `$Line` stays 1,
  `$MessageList` and `General::stop` accumulate over the file, and `Abort[]`, an uncaught `Throw` (after
  `Throw::nocatch`) or a `$RecursionLimit` overflow end the rest of the script, with exit code 0:
  ```wl
  Print[{$Line, Length[$MessageList]}];
  1/0;
  Print[{$Line, Length[$MessageList]}];
  Abort[];
  Print["never printed"];
  ```
  ```
  {1, 0}
  $Aborted
                                   1
  Power::infy: Infinite expression - encountered.
                                   0
  {1, 1}
  ```
  The order of `Print` output and messages in the captured stdout is not reliable (`$Aborted` came before the message).
  Under `wolfram -script` the same file prints `{0, 0}` and `{0, 1}` and nothing after the abort.
- Messages go to stdout and never change the exit code; `Exit[n]` does.
- Always bound runs and redirect output to files (a lingering kernel or front end keeps a pipe open):
  ```bash
  timeout -s KILL 300 wolframscript -f test.wls < /dev/null > out.txt 2> err.txt; echo "exit=$?"
  # 0 = finished, 124 = time limit, 137 = killed from outside (e.g. out of memory), 139 = kernel crash (segfault)
  ```
  Plain `timeout 300` sends SIGTERM, which a busy wolframscript ignores: `timeout 5 wolframscript -code 'Pause[25]; 1'`
  ran for 30 s, printed `1` and "The product exited for an unknown reason.". After a kill, look for kernels you started
  that were left behind (`ps -o pid,ppid,etime,args -C WolframKernel`, parent PID 1) and kill only those.
- `-timeout N` prints `$TimedOut` and exits with code 0.

**`wolfram -script file`.** Trace records nothing, `$Line` is 0, init files are loaded unless you add `-noinit`, an
uncaught `Throw` ends the script without a message, and `Abort[]` ends it too. `wolfram -noinit -script file` starts the
way MCP servers do; `wolfram -sandbox -noinit -script /abs/path/file` adds protected mode (use an absolute path:
a relative one gave `Get::noopen`). See `HeadlessAndCrashes.md`.

**CloudEvaluate** works from any local kernel, including MCP Local (about 1 s per call); definitions of the non-System
symbols in the expression are sent along:

```wl
CloudEvaluate[{$EvaluationEnvironment, Trace[1 + 1], Print["dropped"]; Length[Stack[]]}]
(* {"WebEvaluation", {}, 67}   -- no Trace, Print dropped, 64 wrapper frames above the 3 of this input *)
```

`Abort[]` there gives `CloudEvaluate::srverr` and `$Failed`; `General::stop` can appear twice (relayed and local);
relative file writes land in the persistent cloud user-files directory.

**Remote MCP server.** Stateless JSON-RPC over HTTP; no `initialize` is needed for a single call. The response is JSON or
Server-Sent Events (`data: {...}` lines):

```bash
curl -s https://agenttools.wolfram.com/mcp -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"WolframLanguageEvaluator","arguments":{"code":"{$EvaluationEnvironment, Trace[1 + 1], Internal`TimeRemaining[]}"}}}'
# ... "text":"Out[1]= {\"WebAPI\", {}, 59.999908}" ...
```

Each call starts a new kernel (`Out[1]=` every time), so put everything into one input. Deployed APIs: see
`CloudAndHTTP.md`.

## Loading the helper package in each environment

The helper package is `scripts/WolframDebugging.wl` in this skill directory (functions in `HelperFunctions.md`):

```wl
Get["/absolute/path/to/wolfram-debugging/scripts/WolframDebugging.wl"]   (* on its own line or in its own call *)
WolframDebugging`CollectMessages[myFunction[1, 2]]                      (* fully qualified, on a later line *)
```

| environment | how |
|---|---|
| MCP Local, MCP Session | `Get` on its own line (or alone in a call); then ``WolframDebugging`Name[...]`` on later lines or in later calls |
| wolframscript `-f`, `wolfram -script` | `Get[...]` on its own line; ``Print[ToString[WolframDebugging`Name[...], InputForm]]`` |
| wolframscript `-code` | ``wolframscript -code 'Get["..."]; WolframDebugging`Name[...]' -format InputForm`` (full names work in the same input) |
| CloudEvaluate | load locally, then ``CloudEvaluate[WolframDebugging`Name[...]]``; the definitions are sent along (`ShowDefinition` gives `"Null"` there) |
| deployed API | load locally before `CloudDeploy`; non-System definitions are bundled (see `CloudAndHTTP.md`) |
| remote MCP server | no local files: use the helper-free recipes of the references; `Get` of a public URL works, but publishing a copy needs the user's consent |

## Safety rules for shared and server kernels

MCP Local is one kernel shared by every session and agent of the server; in MCP Session your code runs inside the server
process. Whatever you leave behind affects everyone, and some actions take the server down.

Never do this in an MCP evaluator:
- `Quit[]`, `Exit[]` (MCP Local: all state of all agents is lost).
- `Input`, `InputString`, `Dialog`, `ChoiceDialog`, `TraceDialog` or anything else that reads stdin (`InputString` gives
  no response at all, whatever the time limit; in MCP Session the whole server hangs). `DialogInput` just returns `$Failed`.
- `Run[...]` (never abortable; in MCP Session its output goes into the JSON-RPC stream) and `WriteString["stdout", ...]`
  or any handler that writes to `"stdout"` in MCP Session.
- Top-level settings: `$RecursionLimit = ...` (a value of 77 closed an MCP Session server), `$IterationLimit`, `Off[...]`,
  `SetOptions[...]`, `SetSystemOptions[...]`. `$Pre` and `$Post` have no effect in either method.
- In MCP Local, a low `$RecursionLimit` (even in a `Block`) before the subkernel has printed its first message: the
  failed package load leaves `$Context` set to a package's private context for every session (see above).
- ``Internal`AddHandler`` without removing the handler in the same call: it fires in every session and, in MCP Session, also
  for the server's own quieted messages.
- Unscoped redefinitions of System or package functions; overriding `ToString`, `Print`, `Message` or `WriteLine` even
  briefly in MCP Session (the server formats its responses with them).
- `SetAttributes[..., Locked]`, `ClearAll`/`Remove` of System symbols; `Locked` and `Temporary` set inside `Block` or
  ``Internal`InheritedBlock`` are not undone.
- Probing unknown internals: ``Package`PackageInformation[]`` and
  ``RuntimeTools`SetExecutionState[{"RuntimeAnalysisTools" -> True}]`` crash the kernel. Use a throwaway wolframscript.
- `TaskRemove[Tasks[]]` (removes other agents' tasks); remove only the tasks you created.
- Returning huge results: they are kept in the session and formatting them can take a minute.

Scoped equivalents:

| instead of | use |
|---|---|
| `$RecursionLimit = n` | `Block[{$RecursionLimit = n}, expr]` |
| `Off[f::tag]` | `Quiet[expr, f::tag]` |
| ``Internal`AddHandler["Message", h]`` | ``Internal`HandlerBlock[{"Message", h}, expr]`` (one handler pair per block; nest for more) |
| redefining `f` (System or package) | ``Internal`InheritedBlock[{f}, Unprotect[f]; PrependTo[DownValues[f], HoldPattern[lhs] :> rhs]; expr]`` (see `OverridesAndWatchpoints.md`) |
| `SetOptions[f, opt -> v]` | pass the option, or ``Internal`InheritedBlock[{f}, SetOptions[f, opt -> v]; expr]`` |
| `SetSystemOptions[...]` | `WithCleanup` that restores the old value (below) |

```wl
{Internal`InheritedBlock[{Plot}, SetOptions[Plot, PlotTheme -> "Scientific"]; Options[Plot, PlotTheme]], Options[Plot, PlotTheme]}
(* {{PlotTheme -> "Scientific"}, {PlotTheme :> $PlotTheme}} *)
```
```wl
With[{old = SystemOptions["CompileOptions" -> "TableCompileLength"]},
  {WithCleanup[SetSystemOptions["CompileOptions" -> {"TableCompileLength" -> Infinity}],
     SystemOptions["CompileOptions" -> "TableCompileLength"],
     SetSystemOptions[old]],
   SystemOptions["CompileOptions" -> "TableCompileLength"]}]
(* {{"CompileOptions" -> {"TableCompileLength" -> Infinity}}, {"CompileOptions" -> {"TableCompileLength" -> 250}}} *)
```

If a global handler is unavoidable, add and remove it in one call; `WithCleanup` also runs the cleanup on aborts, throws
and time-outs:

```wl
Module[{h, seen = Internal`Bag[], n0 = Length[Last[Internal`Handlers["Message"]]]},
  h = Function[m, Internal`StuffBag[seen, Last[m]]];
  WithCleanup[Internal`AddHandler["Message", h], Quiet[1/0], Internal`RemoveHandler["Message", h]];
  {Internal`BagPart[seen, All], Length[Last[Internal`Handlers["Message"]]] - n0}]
(* {{False}, 0}   -- the handler saw the quieted message; no handler is left behind *)
```

## Output budget

Large output wastes context and time: MCP responses are cut to about 10 KB, formatting a multi-megabyte result can take
over a minute, and a single raw stack can be hundreds of KB. Rules:
- Never return raw stacks, traces, `TestReportObject` or `PacletObject` expressions, ASTs or long lists. End big intermediate results
  with `;` and return counts, `Dimensions`, `Take[..., UpTo[n]]` or truncated strings.
- `Short` does nothing here (the page width is infinite). Truncate with `TotalWidth`; it does not shorten long strings,
  so add `StringTake`. Very small widths can fail with `Format::toobig`; stay above about 40.

```wl
Module[{big = Range[10^5], long = StringRepeat["abc", 200]},
  {StringLength[ToString[big, InputForm]],
   StringLength[ToString[Short[big], InputForm]],
   ToString[big, InputForm, TotalWidth -> 60],
   ToString[big, InputForm, TotalWidth -> 20],
   StringLength[ToString[long, InputForm, TotalWidth -> 60]],
   StringTake[ToString[long, InputForm, TotalWidth -> 60], UpTo[40]]}]
(* {688895, 688902, "{1, 2, 3, 4, 5, 6, 7, <<99990>>, 99998, 99999, 100000}", "{1, <<99999>>}", 602,
    "\"abcabcabcabcabcabcabcabcabcabcabcabcabc"} *)
```

- For held stack frames or trace items use `ToString[Unevaluated[e], InputForm, TotalWidth -> n]` inside a
  `Replace[..., (HoldCompleteForm | HoldForm)[e_] :> ..., {1}]` (15.0 wraps frames in `HoldCompleteForm`, older versions
  in `HoldForm`), never `First`/`ReleaseHold` (that evaluates the frame again). The helper
  ``WolframDebugging`ShortString[expr, n]`` does this, including the ``Global` `` context fix.
- Return diagnostics as the value of the call (an association or a short string), collected in an ``Internal`Bag``.
  `Print` and `Echo` are dropped by CloudEvaluate, `Echo` by the remote MCP server (`Block[{$Notebooks = False}, Echo[...]]`
  makes it visible there), `Print` is lost on time-outs on the remote MCP server (after an MCP Local subkernel
  restart it arrives without its label), and MCP Session and the remote MCP server drop messages after 10 prints and
  messages in one call.
