# Cloud deployments and HTTP requests

Debugging code deployed with `CloudDeploy` (`APIFunction`, `Delayed`, `FormFunction`, scheduled tasks), code run with
`CloudEvaluate` or `CloudSubmit`, and HTTP requests made with `URLRead`, `URLExecute` and friends: what a caller sees for
each kind of failure, how to reproduce a request locally where messages and stacks work, how to get diagnostics out
of a deployment, and how to see the raw HTTP traffic. Behavior was checked with Wolfram 15.0 (local and cloud kernels).

The examples deploy to a scratch directory (`/debug-scratch/...`); delete what you deploy (`DeleteObject`).

## What the caller of a deployed API sees

A demo API with one failure mode per `mode` value:

```wl
demoBody[mode_, x_] := Switch[mode,
  "ok", x^2, "msg", {1/0, x}, "throw", Throw[x, "demo"], "abort", Abort[], "print", Print["printed"]; x,
  "failure", Failure["DemoFailure", <|"MessageTemplate" -> "Bad value `1`.", "MessageParameters" -> {x}|>],
  "slow", Pause[x]; "done"];
api = CloudDeploy[APIFunction[{"mode" -> "String", "x" -> "Integer" -> 1}, demoBody[#mode, #x] &,
    AllowedCloudExtraParameters -> {"_responseform", "_timeout"}], "/debug-scratch/dbg-demo-api", Permissions -> "Public"];
```

Call it like an anonymous client (`First[api]` is the URL string) and reduce HTML pages to their visible text:

```wl
pageText[s_String] := StringTrim @ StringReplace[StringDelete[s, {Shortest["<script" ~~ ___ ~~ "</script>"],
    Shortest["<style" ~~ ___ ~~ "</style>"], "<" ~~ Except[">"] ... ~~ ">"}], Whitespace .. -> " "];
Table[With[{r = URLRead[HTTPRequest[First[api], <|"Query" -> {"mode" -> m, "x" -> "3"}|>], {"StatusCode", "Headers", "Body"}]},
   {m, r["StatusCode"], Lookup[Association[r["Headers"]], "content-type"], StringTake[pageText[r["Body"]], UpTo[50]]}],
  {m, {"ok", "msg", "print", "failure", "throw", "abort"}}]
(* {{"ok", 200, "text/plain;charset=utf-8", "9"},
    {"msg", 200, "text/plain;charset=utf-8", "{ComplexInfinity, 3}"},
    {"print", 200, "text/plain;charset=utf-8", "3"},
    {"failure", 400, "application/json", "{ \"Success\":false, \"Failure\":\"Bad value 3.\" }"},
    {"throw", 500, "text/html;charset=UTF-8", "Wolfram 500 Internal Server Error"},
    {"abort", 500, "text/html", ""}}      (same from wolframscript and MCP Local) *)
```

| in the deployed code | the caller gets |
|---|---|
| messages | nothing: 200 and the normal result |
| `Print`, `Echo` | nothing (output is lost) |
| uncaught `Throw` | 500 generic HTML page, the **same** page as `HTTPErrorResponse[500]` (only a request id differs) |
| `Abort[]` | 500 with an empty body |
| running past the 300 s limit | **502** "Server Error" page after 300 s |
| returned `Failure` (APIFunction) | 400 JSON with the failure's message text |
| parameter that fails to interpret or is missing | 400 JSON naming the field |

Only a returned `Failure` and parameter failures carry a reason, so return `Failure` objects from API code instead of
throwing. `Delayed` renders a returned `Failure` as a 200 HTML page with its text; a `FormFunction` answers 400 with an
"API Web Report" page that does **not** contain the failure text, and a GET with query parameters only shows the form
(test it with a POST). Wrap the body to get more out of a failing deployment ("Diagnostics inside the deployment" below).

## Use URLRead, never URLExecute, to debug

`URLExecute` hides every HTTP error: no `Failure`, no message, just whatever the error body imports as:

```wl
StringTake[ToString[URLExecute[First[api], {"mode" -> #, "x" -> "3"}], InputForm], UpTo[60]] & /@ {"throw", "failure", "abort"}
(* {"\"{t.onerror=t.onload=null,clearTimeout(u);var f=c[e];if(dele", "{\"Success\" -> False, \"Failure\" -> \"Bad value 3.\"}", "\"\""} *)
```

A 500 page becomes JavaScript text, the 400 JSON a rule list, the empty 500 an empty string. Use
`URLRead[req, {"StatusCode", "Headers", "Body"}]` and look at the status first. Helper:
``WolframDebugging`HTTPSummary[response]`` (status, content type, visible text); see `HelperFunctions.md`.

- A URL string calls anonymously; `URLRead[CloudObject[...]]`, `HTTPRequest[CloudObject[...], ...]` and
  `URLExecute[CloudObject[...]]` are authenticated as the kernel's cloud user (the owner).
- In wolframscript, requests that take longer than 1 s print `Connecting… | Elapsed time 1s` progress lines to stdout;
  `ProgressReporting -> False` turns them off.

## Authentication failures look like missing objects

```wl
privApi = CloudDeploy[APIFunction[{"x" -> "Integer"}, #x + 1 &], "/debug-scratch/dbg-demo-private"];   (* default: private *)
missing = First[CloudObject["/debug-scratch/dbg-does-not-exist"]];
{URLRead[First[privApi] <> "?x=1", "StatusCode"], URLRead[missing, "StatusCode"],
 URLRead[HTTPRequest[privApi, <|"Query" -> {"x" -> "1"}|>], {"StatusCode", "Body"}], FileExistsQ[CloudObject[missing]]}
(* {401, 401, <|"StatusCode" -> 200, "Body" -> "2"|>, False}   (wolframscript) *)
```

- An anonymous request to a private **or non-existent** object is redirected to the sign-in page and ends as 401 (with
  `FollowRedirects -> False`: 302 to `.../j_spring_oauth_security_check?statusCode=401`). Check existence and
  permissions as the owner: `FileExistsQ[CloudObject[...]]`, `Options[CloudObject[...], Permissions]`.
- With a `PermissionsKey`, a missing or wrong `_key` parameter gives 401 "Object Unavailable".
- `SetPermissions` adds to the existing permissions; give the complete list (or redeploy with `Permissions -> ...`) to
  replace them. `CloudGet` of a missing object: `CloudObject::cloudnf` and `$Failed`.

## Built-in debug view: _responseform and _timeout

An `APIFunction` deployed with `AllowedCloudExtraParameters -> {"_responseform", "_timeout"}` (as above) accepts two
extra parameters. `_responseform=JSON` (or `WL`, the same as Wolfram Language text) returns the evaluation data of the
request instead of the result:

```wl
KeyTake[URLExecute[api, {"mode" -> #, "x" -> "3", "_responseform" -> "JSON"}, "RawJSON"],
   {"StatusCode", "FailureType", "MessagesExpressions", "OutputLog", "Result"}] & /@ {"msg", "print"}
(* {<|"StatusCode" -> 200, "FailureType" -> "MessageFailure", "MessagesExpressions" -> {"Hold[Message[Power::infy, HoldCompleteForm[0^(-1)]]]"},
      "OutputLog" -> {}, "Result" -> "{ComplexInfinity, 3}"|>,
    <|"StatusCode" -> 200, "FailureType" -> Null, "MessagesExpressions" -> {}, "OutputLog" -> {"printed"}, "Result" -> "3"|>}
   (wolframscript, MCP Local) *)
```

Other keys: `"Success"`, `"Messages"`, `"MessagesText"`, `"Timing"`, `"AbsoluteTiming"`, `"InputString"` (the full
request, with headers and the client's address), `"ResultMeta"`. `Echo` output is not in `"OutputLog"` (`$Notebooks` is
True in the cloud). For an uncaught `Throw` the answer is a 500 text/plain "Failed to export to JSON" body that still
contains the `Throw::nocatch` text. `_timeout` makes a slow request return early:

```wl
AbsoluteTiming[URLRead[HTTPRequest[First[api], <|"Query" -> {"mode" -> "slow", "x" -> "60", "_timeout" -> "1"}|>],
  {"StatusCode", "Body"}]]
(* {1.56, <|"StatusCode" -> 200, "Body" -> "$Aborted"|>} *)
```

Both parameters are ignored unless listed in `AllowedCloudExtraParameters`, and they exist only for `APIFunction`
(a `Delayed` deployment ignores them). Remove them before production: `_responseform` exposes message texts and
request details.

## Reproduce a request locally

`GenerateHTTPResponse` runs a deployable locally and returns the `HTTPResponse` the cloud would send, while messages
print, handlers fire and stacks can be captured (works in MCP Local, MCP Session and wolframscript):

```wl
otherFn[x_] := 1/x; myFn[a_, b_] := Table[otherFn[i], {i, a, b}];
api = APIFunction[{"a" -> "Integer", "b" -> "Integer"}, myFn[#a, #b] &];
resp = GenerateHTTPResponse[api, HTTPRequest["http://localhost/api", <|"Query" -> {"a" -> "-1", "b" -> "1"}|>]];
{resp["StatusCode"], resp["Body"]}
(* Power::infy is printed, then: {200, "{-1, ComplexInfinity, 1}"}   (wolframscript, MCP Local, MCP Session) *)
```

Status and body match the cloud for `APIFunction` (`FormFunction`: the status). Differences: `Delayed` + `Failure`
gives a local 500 text/plain instead of the cloud's 200 HTML page, and an `Abort[]` escapes `GenerateHTTPResponse`
locally (in wolframscript it ends the script): wrap it in `CheckAbort[..., $Aborted]`.

The request must have the right shape:

```wl
Quiet @ {HTTPRequest["http://localhost/api?a=1", <|"Query" -> {"b" -> "2"}|>]["URL"],
  GenerateHTTPResponse[api, <|"Query" -> {"a" -> "1", "b" -> "2"}|>]["Body"],
  StringTake[GenerateHTTPResponse[api, <|"Query" -> <|"a" -> "1", "b" -> "2"|>|>]["Body"], UpTo[40]],
  GenerateHTTPResponse[api, {"a" -> "1", "b" -> "2"}]["StatusCode"],
  GenerateHTTPResponse[api, HTTPRequest["http://localhost/api", <|Method -> "POST", "Body" -> {"a" -> "1", "b" -> "2"}|>]]["Body"]}
(* {"http://localhost/api?b=2", "{1, 1/2}", "APIFunction[{\"a\" -> \"Integer\", \"b\" -> \"I", 400, "{1, 1/2}"} *)
```

The `"Query"` key replaces the query of the URL; `"Query"` must be a list of rules (an association gives a 200 whose
body is the unevaluated `APIFunction`); bare rules are not parameters (400 "no input for fields"); POST parameters go in
`"Body"`. Inside `CloudEvaluate`, `GenerateHTTPResponse` ignores the request (always 400); apply the function directly:

```wl
{CloudEvaluate[GenerateHTTPResponse[api, <|"Query" -> {"a" -> "1", "b" -> "2"}|>]["StatusCode"]],
 CloudEvaluate[api[<|"a" -> "1", "b" -> "2"|>]]}
(* {400, {1, 1/2}} *)
```

### Stack at the first message of a request

`GenerateHTTPResponse` evaluates the body under `EvaluationData`, which catches **every** `Throw`: a probe that throws
the stack out of a message handler misfires (huge `Throw::nocatch` output, wrong stack). Record and continue instead:

```wl
Module[{msgs = Internal`Bag[], st = None, resp},
  resp = Internal`HandlerBlock[{"Message", Function[h, If[Last[h],
      Internal`StuffBag[msgs, Replace[h, Hold[Message[mn_, ___], _] :> ToString[Unevaluated[mn], InputForm]]];
      If[st === None, st = Stack[_]]]]},                                   (* record only: never Throw here *)
    Block[{$Messages = {}}, StackBegin @ StackComplete @
      GenerateHTTPResponse[api, HTTPRequest["http://localhost/api", <|"Query" -> {"a" -> "-1", "b" -> "1"}|>]]]];
  <|"Status" -> resp["StatusCode"], "Messages" -> Internal`BagPart[msgs, All], "StackLength" -> Length[st],
    "UserFrames" -> Block[{$ContextPath = Join[{"Global`", $Context}, $ContextPath]},
      Cases[st, _[e : (_myFn | _otherFn | _Table)] :> ToString[Unevaluated[e], InputForm]]]|>]
(* <|"Status" -> 200, "Messages" -> {"Power::infy"}, "StackLength" -> 52,
     "UserFrames" -> {"myFn[-1, 1]", "Table[otherFn[i], {i, -1, 1}]", "otherFn[i]"}|>
   (wolframscript, MCP Local; MCP Session: 53 frames, and the message is printed despite $Messages = {}) *)
```

About 40 framework frames sit between `GenerateHTTPResponse` and the user code, hence the filter. For an uncaught
`Throw`, the frames of the thrower are gone by the time `Throw::nocatch` is issued: find the thrower with Trace on the
direct application (below). Helper: ``WolframDebugging`DebugHTTPResponse[api, <|"a" -> "-1", "b" -> "1"|>]`` (status,
text, messages, stack from the first user frame on).

### Trace the deployed code

`Trace` sees none of the user code inside `GenerateHTTPResponse`; apply the `APIFunction` to the parameters directly
(MCP Local and wolframscript; Trace is disabled in MCP Session and in the cloud):

```wl
{Trace[GenerateHTTPResponse[api, HTTPRequest["http://localhost/api", <|"Query" -> {"a" -> "-1", "b" -> "1"}|>]], _otherFn],
 Trace[api[<|"a" -> "-1", "b" -> "1"|>], _otherFn]} // Quiet
(* {{}, {{{{HoldCompleteForm[otherFn[-1]]}, {HoldCompleteForm[otherFn[0]]}, {HoldCompleteForm[otherFn[1]]}}}}}
   MCP Session: {{}, {}} *)
```

Who throws: `Trace[Catch[api[<|...|>], _, List], _Throw]` (it also lists the internal `Throw` calls of the parameter
interpreters).

## Diagnostics inside the deployment

Message handlers, `Stack`, `StackBegin`, `TimeConstrained` and `ScheduledTask` stack sampling all work in deployed
kernels; Trace does not. What deployed code runs with:

```wl
owner = If[$CloudConnected, $CloudUserID];       (* $CloudUserID stays None until the kernel has connected *)
envApi = With[{owner = owner}, CloudDeploy[APIFunction[{}, <|
     "EvaluationEnvironment" -> $EvaluationEnvironment, "RequesterWolframID" -> $RequesterWolframID,
     "RunsAsOwner" -> ($CloudUserID === owner), "Notebooks" -> $Notebooks, "TraceWorks" -> (Trace[1 + 1] =!= {}),
     "ProtectedMode" -> Developer`$ProtectedMode, "UserFilesDirectory" -> StringStartsQ[Directory[], "/wolframcloud/userfiles"],
     "TimeRemaining" -> Internal`TimeRemaining[], "PID" -> $ProcessID|> &], "/debug-scratch/dbg-demo-env", Permissions -> "Public"]];
URLRead[First[envApi], "Body"] & /@ {1, 2}
(* {"<|\"EvaluationEnvironment\" -> \"WebAPI\", \"RequesterWolframID\" -> None, \"RunsAsOwner\" -> True, \"Notebooks\" -> True,
      \"TraceWorks\" -> False, \"ProtectedMode\" -> True, \"UserFilesDirectory\" -> True, \"TimeRemaining\" -> 299.99, \"PID\" -> <pid1>|>",
    "<|... \"PID\" -> <pid2>|>"}       -- a fresh process for every request *)
```

- Deployed code runs **as the owner** even for anonymous callers (`$CloudUserID` is the owner, `$RequesterWolframID` is
  `None`), in protected mode, with a 300 s time limit, a fresh kernel per request, `$Notebooks` True (so `Echo` output
  goes nowhere) and the owner's **persistent** user-files directory as the working directory (relative file writes
  persist).
- `CloudDeploy` bundles the definitions of the non-System symbols the deployed expression uses (`demoBody` above, or the
  helper package if it was loaded before deploying).
- `$CloudUserID` is `None` in a fresh kernel until the first cloud operation; force the connection with
  `$CloudConnected` before capturing it.

A wrapper that returns the normal result, or a JSON report (messages, stack at the first message, uncaught throw) with
status 500:

```wl
diagApi = APIFunction[{"mode" -> "String", "x" -> "Integer" -> 1}, Module[{msgs = Internal`Bag[], st = {}, res},
   res = Internal`HandlerBlock[{"Message", If[Last[#],
        Internal`StuffBag[msgs, Replace[#, Hold[Message[mn_, ___], _] :> ToString[Unevaluated[mn], InputForm]]];
        If[st === {}, st = Stack[_]]] &},
      Catch[StackBegin[StackComplete[demoBody[#mode, #x]]], _, {"UncaughtThrow", ##} &]];
   If[Internal`BagLength[msgs] == 0 && FreeQ[res, _Failure | "UncaughtThrow"], res,
     HTTPResponse[ExportString[<|"Result" -> ToString[res, InputForm, TotalWidth -> 300],
         "Messages" -> Internal`BagPart[msgs, All],
         "Stack" -> With[{fr = Take[st, FirstPosition[st, _[_Message], {Length[st] + 1}, {1}][[1]] - 1]},
            Replace[Take[fr, -Min[8, Length[fr]]], _[e_] :> ToString[Unevaluated[e], InputForm, TotalWidth -> 150], {1}]]|>,
         "RawJSON", "Compact" -> True],
       <|"StatusCode" -> 500, "ContentType" -> "application/json"|>]]] &];
```

```wl
diag = CloudDeploy[diagApi, "/debug-scratch/dbg-demo-diag", Permissions -> "Public"];
URLRead[HTTPRequest[First[diag], <|"Query" -> {"mode" -> #, "x" -> "3"}|>], {"StatusCode", "Body"}] & /@ {"ok", "msg", "throw"}
(* {<|"StatusCode" -> 200, "Body" -> "9"|>,
    <|"StatusCode" -> 500, "Body" -> "{\"Result\":\"{ComplexInfinity, 3}\",\"Messages\":[\"Power::infy\"],\"Stack\":[
       \"StackComplete[demoBody[\\\"msg\\\", 3]]\",\"demoBody[\\\"msg\\\", 3]\",\"Switch[\\\"msg\\\", \\\"ok\\\", 3^2, ...]\",
       \"{1\\/0, 3}\",\"1\\/0\",\"0^(-1)\"]}"|>,
    <|"StatusCode" -> 500, "Body" -> "{\"Result\":\"{\\\"UncaughtThrow\\\", 3, \\\"demo\\\"}\",\"Messages\":[],\"Stack\":[]}"|>}
   GenerateHTTPResponse[diagApi, ...] gives the same responses locally (MCP Local with bug #249 prints Global`demoBody in the stack) *)
```

It does not catch an untagged `Throw[v]`, `Abort[]` or time-outs. The helper does all of these, captures `Print` output,
can stop at a time limit below 300 s with the sampled stack, answers `debug=1` requests with the report, and can log
each report: ``APIFunction[{...}, WolframDebugging`HTTPDiagnostics[myBody[#x]] &]``; load the package before
`CloudDeploy` (options in `HelperFunctions.md`).

### Logging from deployed code

The cloud keeps no messages, `Print` output or errors of deployed code (`CloudLoggingData[obj]` has call counts and
credits only). Log to a cloud object yourself; `PutAppend` takes 20 to 35 ms there:

```wl
log = CloudObject["/debug-scratch/dbg-demo-log"];
logApi = CloudDeploy[APIFunction[{"x" -> "Integer"},
    (PutAppend[<|"x" -> #x, "time" -> DateString["ISODateTime", TimeZone -> 0]|>, log]; #x^2) &],
  "/debug-scratch/dbg-demo-logapi", Permissions -> "Public"];
URLRead[HTTPRequest[First[logApi], <|"Query" -> {"x" -> ToString[#]}|>], "Body"] & /@ {1, 2}
{CloudGet[log], ReadList[log]}
(* {"1", "4"}
   {<|"x" -> 2, "time" -> "2026-10-07T23:57:18"|>, {<|"x" -> 1, "time" -> "2026-10-07T23:57:17"|>, <|"x" -> 2, "time" -> "2026-10-07T23:57:18"|>}} *)
```

`CloudGet` returns only the last entry; read the log with `ReadList`. Pass `TimeZone -> 0`: cloud kernels do not run
in UTC. Log the same way from inside a deployed `ScheduledTask` (it runs with `$EvaluationEnvironment` "Scheduled").

## CloudEvaluate

```wl
ceF[x_] := (Print["printed in the cloud"]; 1/x);
{CloudEvaluate[ceF[0]], CloudEvaluate[Trace[1 + 1]],
 CloudEvaluate[Lookup[EvaluationData[ceF[0]], {"OutputLog", "MessagesExpressions"}]],
 CloudEvaluate[{Length[Stack[_]], StackBegin[Length[Stack[_]]]}]}
(* Power::infy relayed and printed locally (twice: the first and the third call)
   {ComplexInfinity, {}, {{"printed in the cloud"}, {Hold[Message[Power::infy, HoldCompleteForm[0^(-1)]]]}}, {66, 1}}
   (wolframscript, MCP Local) *)
```

- Local definitions (`ceF`) are sent along automatically; messages are relayed and printed locally; `Print` output is
  dropped (capture it with `EvaluationData` inside the `CloudEvaluate`); Trace returns `{}`; about 65 wrapper frames
  sit on the stack (use `StackBegin`). `Abort[]` gives `CloudEvaluate::srverr` and `$Failed`. More in `Environments.md`.

## Inspecting HTTP traffic

`URLRead`, `URLExecute`, `CloudGet` and `CloudPut` send their requests through `URLFetch`; `Import` of a URL and
`URLDownload` through `URLSave`. A guarded spy on `URLFetch` shows every request with its status, including errors that
`URLExecute` hides (works in MCP Local, MCP Session and wolframscript; see `OverridesAndWatchpoints.md` for the pattern):

```wl
Module[{log = Internal`Bag[], in = False, res},
  URLFetch;                                                    (* load the autoload stub before the block *)
  res = Internal`InheritedBlock[{URLFetch},
    Unprotect[URLFetch];
    PrependTo[DownValues[URLFetch], HoldPattern[URLFetch[url_, el_ : "Content", rest___] /; !in] :>
      Block[{in = True}, With[{r = URLFetch[url, el, rest]},
        Internal`StuffBag[log, {url, If[ListQ[el] && ListQ[r] && MemberQ[el, "StatusCode"],
          r[[First[FirstPosition[el, "StatusCode"]]]], Head[r]]}]; r]]];
    URLExecute["http://127.0.0.1:18765/missing.txt"]];
  {StringTake[res, UpTo[50]], Internal`BagPart[log, All]}]
(* {"<!DOCTYPE HTML>\n<html lang=\"en\">\n    <head>\n      ", {{"http://127.0.0.1:18765/missing.txt", 404}}} *)
```

Helper: ``WolframDebugging`WithHTTPLog[expr]`` (function, method, URL, status and time of every request).

Where Trace works (MCP Local, wolframscript), `TraceInternal -> True` also lists the requests, with the final URL:

```wl
DeleteDuplicates @ Cases[Flatten[Trace[Quiet[URLExecute["http://127.0.0.1:1/x", {"a" -> "1"}]], _URLFetch, TraceInternal -> True]],
  _[HoldPattern[URLFetch[u_String, ___]]] :> u]
(* {"http://127.0.0.1:1/x?a=1"} *)
```

Without `HoldPattern` the rule's left side `URLFetch[u_String, ___]` is evaluated and calls `URLFetch`
(`URLFetch::invurl: u_String is not a valid URL`).

The raw exchange of one request, in any local environment including MCP Local:

```wl
{status, debug} = URLFetch["http://127.0.0.1:18765/missing.txt", {"StatusCode", "DebugContent"}, "Debug" -> True];
{status, StringTake[debug, UpTo[400]]}
(* {404, "  Trying 127.0.0.1:18765...\nEstablished connection to 127.0.0.1 (127.0.0.1 port 18765) from 127.0.0.1 port 54720 \n
    using HTTP/1.x\nGET /missing.txt HTTP/1.1\r\nHost: 127.0.0.1:18765\r\nUser-Agent: Wolfram HTTPClient in Wolfram Language 15.\r\n
    Accept: */*\r\nAccept-Encoding: deflate, gzip\r\nConnection: keep-alive\r\n\r\nRequest completely sent off\n
    HTTP 1.0, assume close after body\nHTTP/1.0 404 File not found\r\nSer"} *)
```

Every request of a piece of code, with headers and bodies (libcurl trace to a file; global until stopped):

```wl
logFile = FileNameJoin[{$TemporaryDirectory, "curl-debug.log"}];
WithCleanup[CURLLink`StartDebugLog[logFile],
  URLRead[HTTPRequest["http://127.0.0.1:18765/hello.txt", <|Method -> "POST", "Body" -> "a=1"|>]]["StatusCode"],
  CURLLink`StopDebugLog[]];
{FileExistsQ[logFile], StringTake[Quiet[ReadString[logFile]], UpTo[300]]}
(* wolframscript, MCP Session:
     {True, "23:54:47.000000 => Send header, 215 bytes (0xd7)\n0000: POST /hello.txt HTTP/1.1\n001a: Host: 127.0.0.1:18765\n
             0031: Accept: */*\n003e: Accept-Encoding: deflate, gzip\n005e: Content-Type: text/plain;charset=utf-8\n..."}
   MCP Local: {False, StringTake[$Failed, UpTo[300]]} *)
```

Do not use ``CURLLink`StartDebugLog`` in MCP Local; use the `"Debug"` option of `URLFetch` (above) there. `logFile`
is never written. Usually no trace is written at all, but in one run the trace went to a file with a garbled binary
name in the kernel's working directory (the project directory), so check `ls -lt | head` afterwards and delete it.

The `== Info:` lines (connecting, connection reuse) go to the kernel's stderr, not to the file (in MCP Session: the
server's stderr). The log contains `Authorization` headers and cookies of cloud requests: do not share it.

Request and response objects: `req["URL"]`, `req["Headers"]`, `req["FormRules"]` (for a rule-list body `req["Body"]`
stays unevaluated with `HTTPResponse::encfailed`), `resp["StatusCode"]`, `resp["Headers"]`, `resp["ContentType"]`. An
`HTTPResponse` carries no timing: wrap the call in `AbsoluteTiming`.

## Network failures: the reason is only in the message

```wl
With[{ed = EvaluationData[URLRead[#, TimeConstraint -> 5]]},
   {ed["Result"][[1]], ed["MessagesText"]}] & /@ {"http://127.0.0.1:1/x", "http://nonexistent-host.invalid/x"}
(* {{"ConnectionFailure", {"URLRead::invhttp : Failed to connect to 127.0.0.1 port 1 after 0 ms: Could not connect to server."}},
    {"ConnectionFailure", {"URLRead::invhttp : Could not resolve host: nonexistent-host.invalid."}}}
   (wolframscript, MCP Local) *)
```

- The `Failure["ConnectionFailure", ...]` names only the URL; the cause (refused, DNS, time-out, TLS) is only in the
  `::invhttp` or `::ssl` message, which `General::stop` suppresses after three per evaluation. Capture messages (as here,
  or with a message handler) when debugging network code.
- `URLRead` and `URLFetch` have no default time-out: use `URLRead[url, TimeConstraint -> 10]` (connect plus transfer;
  `URLRead::invhttp: Operation timed out after 1000 milliseconds with 0 bytes received.`) or
  `URLFetch[url, ..., "ConnectTimeout" -> 5, "ReadTimeout" -> 10]`. See `TracingAndPerformance.md` for `TimeConstrained`.
- TLS problems: `URLRead::ssl: ... libcurl error (60): ...`; `VerifySecurityCertificates -> False` confirms the cause.
- Proxy settings: ``PacletManager`$InternetProxyRules`` (typing `$InternetProxyRules` unqualified creates a new symbol).

## CloudSubmit and cloud tasks

```wl
csLog = Internal`Bag[]; csDone = False;
csTask = CloudSubmit[Print["cs-print"]; 1/0; 42,
   HandlerFunctions -> <|"MessageGenerated" -> (Internal`StuffBag[csLog, First[#MessageOutput]["MessageTag"]] &),
     "PrintOutputGenerated" -> (Internal`StuffBag[csLog, #PrintOutput] &),
     "TaskFinished" -> ((csDone = True; Internal`StuffBag[csLog, #EvaluationResult]) &)|>,
   HandlerFunctionsKeys -> {"MessageOutput", "PrintOutput", "EvaluationResult"}];
TimeConstrained[While[!csDone, Pause[0.5]], 60]; Quiet[TaskRemove[csTask]];
{csDone, Internal`BagPart[csLog, All]}
(* {True, {"infy", HoldComplete["cs-print"], 42}}   (wolframscript, about 10 s) *)
```

For `CloudSubmit`, `"MessageGenerated"` does fire (`#MessageOutput` is a `MessageObject`). An uncaught `Throw` never
finishes the task:

```wl
csDone = False;
csTask = CloudSubmit[Throw[7, "cstag"], HandlerFunctions -> <|"TaskFinished" -> ((csDone = True) &)|>];
TimeConstrained[While[!csDone, Pause[0.5]], 30]; {csDone, csTask["TaskStatus"], Quiet[TaskRemove[csTask]]; csTask["TaskStatus"]}
(* {False, "Running", "Removed"} *)
```

- Always time-limit the wait and `TaskRemove` the task: the local kernel cleans up the task's cloud objects when it sees
  the task finish, so a stuck task, or a submitting kernel that is killed, leaves two unnamed cloud objects behind.
- `Tasks["Cloud"]` and `Tasks[All]` query the account's task objects and hung for more than 40 s on an account with many
  cloud objects: use `Tasks[]` (local tasks) or keep the `TaskObject`.
