(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/WolframDebuggingSkill.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/WolframDebuggingSkill.wlt:11,1-16,2"
]

(* The tests deliberately use uncaught Throw and Print inside the helpers that contain or capture them *)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::NoSurroundingCatch:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* The helper package of the wolfram-debugging agent skill is loaded from the checkout (it is not part of the paclet
   code). Test functions are prefixed with wdt; helpers are always called fully qualified, as the skill instructs. *)
$wdtPackageFile = FileNameJoin @ {
    DirectoryName[ $TestFileName, 2 ],
    "AgentSkills",
    "Skills",
    "wolfram-debugging",
    "scripts",
    "WolframDebugging.wl"
};

(* handler counts of the types the package uses (the test harness adds its own handlers inside each test) *)
wdtHandlerCounts[ ] := Association @ Cases[
    Internal`Handlers[ ],
    ( type: "Message" | "MessageTextFilter" | "ValueChange" | "NewSymbol" | "GetFileEvent" | "Assertions" |
        "Wolfram.File.OpenWrite" | "Wolfram.System.Print" -> l_List ) :> ( type -> Length @ l )
];
$wdtTaskCount = Length @ Tasks[ ];
$wdtSystemDefinitions := DownValues /@ Unevaluated @ { Package`ActivateLoad, System`Dump`AutoLoad, MathLink`CallFrontEnd, VerificationTest };
$wdtSystemDefinitionsBefore = $wdtSystemDefinitions;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Loading*)
(* messages are recorded with a handler, so that messages turned off by Common.wl (General::shdw) are seen too *)
VerificationTest[
    With[ { before = Names[ "Global`*" ], handlers = wdtHandlerCounts[ ], messages = Internal`Bag[ ] },
        $wdtHandlers = handlers;
        {
            Internal`HandlerBlock[
                { "Message", If[ ! MatchQ[ #, Hold[ Message[ General::newsym, ___ ], _ ] ], Internal`StuffBag[ messages, # ] ] & },
                Get @ $wdtPackageFile
            ],
            Complement[ Names[ "Global`*" ], before ],
            wdtHandlerCounts[ ] === handlers,
            Internal`BagPart[ messages, All ]
        }
    ],
    { Null, { }, True, { } },
    SameTest -> MatchQ,
    TestID   -> "Load-NoMessagesNoGlobalSymbols@@Tests/WolframDebuggingSkill.wlt:48,1-64,2"
]

VerificationTest[
    Sort @ Names[ "WolframDebugging`*" ],
    Sort @ {
        "$CaptureFunction", "AutoloadStubQ", "CallLogSummary", "CaptureEvaluation", "CapturePrints", "CheckTestFile",
        "CollectMessages", "ContextSourceInfo", "CountCalls", "DebugHTTPResponse", "EnsureLoaded", "EnvironmentFingerprint",
        "EnvironmentInfo", "FailedAssertions", "FileWritesDuring", "FindHang", "FindSymbolSource", "FingerprintDiff",
        "FormatStack", "FrontEndCalls", "HTTPDiagnostics", "HTTPSummary", "KernelReport", "LeakCheck", "LintSummary",
        "LoadTrace", "LogCalls", "NewSymbolsDuring", "PacletRoot", "ParallelCapture", "ReproduceTest", "RestoreDefinitions",
        "RunIsolated", "RunTestsByID", "SampleStacks", "ShortString", "ShowDefinition", "SnapshotDefinitions", "StackAtCall",
        "StackAtMessage", "StackSummary", "StopWhen", "StuckCalls", "SubmitAndWait", "SymbolKind", "TaskReport",
        "TestFailureSummary", "TestSource", "TimeCalls", "TraceAvailableQ", "TraceCalls", "WatchChanges", "WhyNoMatch",
        "WithHTTPLog", "WithOverrides"
    },
    SameTest -> SameQ,
    TestID   -> "Load-PublicSymbols@@Tests/WolframDebuggingSkill.wlt:66,1-81,2"
]

VerificationTest[
    Select[
        Names[ "WolframDebugging`*" ],
        ToExpression[
            "WolframDebugging`" <> #,
            InputForm,
            Function[ s, ! StringQ @ MessageName[ s, "usage" ] || ! MemberQ[ Attributes @ s, Protected ], HoldAllComplete ]
        ] &
    ],
    { },
    SameTest -> SameQ,
    TestID   -> "Load-UsageAndProtected@@Tests/WolframDebuggingSkill.wlt:83,1-95,2"
]

(* loading must not evaluate autoload stubs (a load-time list containing EvaluationData loaded Evaluation.mx): the
   symbols that are stubs in a fresh kernel get a recording stub inside InheritedBlock while the package is loaded *)
VerificationTest[
    Module[ { evaluated = { } },
        Internal`InheritedBlock[
            { EvaluationData, Kernels, ParallelMap, HTTPResponse, APIFunction, GenerateHTTPResponse, CloudObject, URLFetch, URLSave },
            Scan[
                Function[
                    s,
                    Unprotect @ s;
                    s := ( AppendTo[ evaluated, SymbolName @ Unevaluated @ s ]; s =.; s ),
                    HoldAllComplete
                ],
                Hold[ EvaluationData, Kernels, ParallelMap, HTTPResponse, APIFunction, GenerateHTTPResponse, CloudObject, URLFetch, URLSave ]
            ];
            Get @ $wdtPackageFile
        ];
        evaluated
    ],
    { },
    SameTest -> SameQ,
    TestID   -> "Load-NoAutoloadTriggers@@Tests/WolframDebuggingSkill.wlt:99,1-119,2"
]

VerificationTest[
    { MemberQ[ $ContextPath, "WolframDebugging`" ], MemberQ[ $ContextPath, "WolframDebugging`Private`" ], wdtHandlerCounts[ ] === $wdtHandlers },
    { True, False, True },
    SameTest -> SameQ,
    TestID   -> "Load-NoSideEffects@@Tests/WolframDebuggingSkill.wlt:121,1-126,2"
]

VerificationTest[
    Module[ { n = Length @ DownValues @ WolframDebugging`CollectMessages, t },
        t = First @ AbsoluteTiming @ Get @ $wdtPackageFile;
        { t < 3, Length @ DownValues @ WolframDebugging`CollectMessages === n, WolframDebugging`ShortString[ Range[ 100 ], 40 ] }
    ],
    { True, True, "{1, 2, 3, 4, 5, <<92>>, 98, 99, 100}" },
    SameTest -> SameQ,
    TestID   -> "Load-Reload@@Tests/WolframDebuggingSkill.wlt:128,1-136,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Code Under Test*)
wdtOtherFn[ x_ ] := 1 / x;
wdtMyFn[ a_, b_ ] := Table[ wdtOtherFn[ i ], { i, a, b } ];
wdtArea[ r_? NumericQ ] := Pi * r^2;
wdtAdd[ x_Integer, y_Integer ] := x + y;
wdtHlp[ x_ ] := x^2;
wdtFib[ 0 ] = 0;
wdtFib[ 1 ] = 1;
wdtFib[ n_ ] := wdtFib[ n - 1 ] + wdtHlp @ wdtFib[ n - 2 ];
wdtCollatz[ n_ ] := Module[ { k = 0, m = n }, While[ m != 1, m = If[ EvenQ @ m, m / 2, 3 m - 1 ]; k++ ]; k ];
wdtLoop[ ] := Module[ { k = 0 }, While[ True, k++ ] ];
wdtFact[ 0 ] = 1;
wdtFact[ n_ ] := n * wdtFact[ n - 1 ];
wdtCounter = 0;
wdtBump[ ] := wdtCounter++;
wdtState = 0;
wdtAssert[ x_ ] := ( Assert[ x > 0 ]; x );
wdtLeakCache = { };
wdtLeaky[ ] := Module[ { t }, t[ 1 ] = 1; AppendTo[ wdtLeakCache, t ] ];
wdtRP[ x_ ] := x + 1;
SetAttributes[ wdtRP, ReadProtected ];
wdtConst = 3;
wdtUseConst[ ] := wdtConst + 1;
wdtSquare[ x_ ] := x^2;
wdtPkg`wdtCube[ x_ ] := x^3;
wdtRep[ x: { __Integer } ] := x;
wdtTask::boom = "Boom.";
(* Scripts/TestPaclet.wls reports every failing test except those of files in a "TestResources" directory, and the
   test files below fail on purpose when the helpers run them *)
$wdtTempDir = CreateDirectory @ FileNameJoin @ { $TemporaryDirectory, "wdt-" <> CreateUUID[ ], "TestResources" };
wdtTempFile[ ext_String ] := FileNameJoin @ { $wdtTempDir, "wdt-" <> CreateUUID[ ] <> "." <> ext };

(* a small test file for the test helpers *)
$wdtTestFile = wdtTempFile[ "wlt" ];
Export[
    $wdtTestFile,
    StringRiffle[
        {
            "VerificationTest[1 + 1, 2, TestID -> \"Pass\"]",
            "VerificationTest[StringJoin[\"a\", \"b\"], \"ba\", TestID -> \"Wrong\"]",
            "VerificationTest[1/0; 1, 1, TestID -> \"Msg\"]"
        },
        "\n\n"
    ],
    "Text"
];

(* an unclosed call: TestReport then runs no test of the file *)
$wdtSyntaxTestFile = wdtTempFile[ "wlt" ];
Export[ $wdtSyntaxTestFile, "VerificationTest[1, 1, TestID -> \"A\"]\n\nVerificationTest[f[1, 1, TestID -> \"B\"]", "Text" ];

$wdtBadTestFile = wdtTempFile[ "wlt" ];
Export[
    $wdtBadTestFile,
    StringRiffle[
        {
            "VerificationTest[1, 1, TestID -> \"Same\"]",
            "VerificationTest[2, 2, TestID -> \"Same\"]",
            "VerificationTest[3, 3]",
            "VerificationTest[1, 1, 2, 3, TestID -> \"FourArgs\"]",
            "Abort[]"
        },
        "\n\n"
    ],
    "Text"
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Core*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ShortString*)
VerificationTest[
    {
        WolframDebugging`ShortString[ Range[ 1000 ], 60 ],
        WolframDebugging`ShortString[ HoldCompleteForm[ 1 / 0 ] ],
        WolframDebugging`ShortString[ HoldForm[ 1 + 1 ] ],
        WolframDebugging`ShortString[ StringRepeat[ "a", 500 ], 30 ],
        WolframDebugging`ShortString[ HoldComplete @ wdtMyFn[ 1, 2 ] ],
        WolframDebugging`ShortString[ "a\nb" ]
    },
    {
        "{1, 2, 3, 4, 5, 6, 7, 8, 9, <<987>>, 997, 998, 999, 1000}",
        "1/0",
        "1 + 1",
        "\"aaaaaaaaaaaaaaaaaaaaaaaaaa...",
        "wdtMyFn[1, 2]",
        "\"a\\nb\""
    },
    SameTest -> SameQ,
    TestID   -> "ShortString@@Tests/WolframDebuggingSkill.wlt:214,1-233,2"
]

VerificationTest[
    WolframDebugging`ShortString[ 1, -2 ],
    Failure[ "WolframDebugging", KeyValuePattern @ {
        "MessageParameters" -> { "WolframDebugging`ShortString", "ShortString[1, -2]", _String },
        "Expected"          -> _String
    } ],
    SameTest -> MatchQ,
    TestID   -> "ShortString-InvalidCall@@Tests/WolframDebuggingSkill.wlt:235,1-243,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*EnvironmentInfo*)
VerificationTest[
    WolframDebugging`EnvironmentInfo[ ],
    KeyValuePattern @ {
        "Environment"   -> _String,
        "TraceWorks"    -> WolframDebugging`TraceAvailableQ[ ],
        "ProtectedMode" -> TrueQ @ Developer`$ProtectedMode,
        "Context"       -> $Context,
        "UserContexts"  -> { "Global`", ___ },
        "Notes"         -> { ___String }
    },
    SameTest -> MatchQ,
    TestID   -> "EnvironmentInfo@@Tests/WolframDebuggingSkill.wlt:248,1-260,2"
]

VerificationTest[
    WolframDebugging`EnvironmentInfo[ 1 ],
    Failure[ "WolframDebugging", KeyValuePattern[ "Expected" -> "EnvironmentInfo[]" ] ],
    SameTest -> MatchQ,
    TestID   -> "EnvironmentInfo-InvalidCall@@Tests/WolframDebuggingSkill.wlt:262,1-267,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages and Stacks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*CollectMessages*)
VerificationTest[
    WolframDebugging`CollectMessages @ wdtMyFn[ -1, 1 ],
    <|
        "Result"       -> { -1, ComplexInfinity, 1 },
        "MessageCount" -> 1,
        "Messages"     -> {
            <|
                "Message" -> HoldForm[ Power::infy ],
                "Text"    -> "Power::infy: Infinite expression 0^(-1) encountered.",
                "Printed" -> True,
                "Quieted" -> False,
                "Stack"   -> { "wdtMyFn[-1, 1]", "Table[wdtOtherFn[i], {i, -1, 1}]", "wdtOtherFn[i]", "1/0", "0^(-1)" }
            |>
        }
    |>,
    { Power::infy },
    SameTest -> SameQ,
    TestID   -> "CollectMessages@@Tests/WolframDebuggingSkill.wlt:276,1-294,2"
]

VerificationTest[
    Lookup[ WolframDebugging`CollectMessages[ Table[ 1 / 0, 5 ], "StackFrames" -> 0 ], "Messages" ][[ All, "Printed" ]],
    { True, True, True, True, False, False },
    { Power::infy, Power::infy, Power::infy, General::stop },
    SameTest -> SameQ,
    TestID   -> "CollectMessages-PrintedFlags@@Tests/WolframDebuggingSkill.wlt:296,1-302,2"
]

VerificationTest[
    KeyTake[
        WolframDebugging`CollectMessages[ { First @ { }, Last @ { }, Rest @ { } }, "StopAt" -> "Last::*", "StackFrames" -> 0 ],
        { "Result", "MessageCount" }
    ],
    <| "Result" -> Missing[ "Stopped" ], "MessageCount" -> 2 |>,
    { First::nofirst, Last::nolast },
    SameTest -> SameQ,
    TestID   -> "CollectMessages-StopAt@@Tests/WolframDebuggingSkill.wlt:304,1-313,2"
]

VerificationTest[
    WolframDebugging`CollectMessages[ Quiet[ 1 / 0 ], "IncludeQuieted" -> True, "StackFrames" -> 0 ][ "Messages" ],
    { KeyValuePattern @ { "Message" -> HoldForm[ Power::infy ], "Printed" -> False, "Quieted" -> True } },
    SameTest -> MatchQ,
    TestID   -> "CollectMessages-IncludeQuieted@@Tests/WolframDebuggingSkill.wlt:315,1-320,2"
]

VerificationTest[
    {
        WolframDebugging`CollectMessages[ Throw[ 1 ] ][ "Result" ],
        WolframDebugging`CollectMessages[ Throw[ 1, "tag" ] ][ "Result" ],
        WolframDebugging`CollectMessages[ Abort[ ] ][ "Result" ]
    },
    {
        Failure[ "UncaughtThrow", KeyValuePattern[ "MessageParameters" -> { "1" } ] ],
        Failure[ "UncaughtThrow", KeyValuePattern[ "MessageParameters" -> { "1", "\"tag\"" } ] ],
        $Aborted
    },
    SameTest -> MatchQ,
    TestID   -> "CollectMessages-ThrowAndAbortContained@@Tests/WolframDebuggingSkill.wlt:322,1-335,2"
]

VerificationTest[
    {
        WolframDebugging`CollectMessages[ Range[ 10^4 ] ][ "Result" ],
        Length @ WolframDebugging`CollectMessages[ Range[ 10^4 ], "MaxResultBytes" -> Infinity ][ "Result" ]
    },
    { Missing[ "TooLarge", KeyValuePattern @ { "ByteCount" -> _Integer, "Preview" -> _String } ], 10000 },
    SameTest -> MatchQ,
    TestID   -> "CollectMessages-MaxResultBytes@@Tests/WolframDebuggingSkill.wlt:337,1-345,2"
]

VerificationTest[
    {
        WolframDebugging`CollectMessages[ 1, "Bogus" -> 2 ],
        WolframDebugging`CollectMessages[ 1, "StackFrames" -> -1 ],
        WolframDebugging`CollectMessages[ ]
    },
    {
        Failure[ "WolframDebugging", KeyValuePattern[ "MessageTemplate" -> _String? ( StringStartsQ[ "Unknown option" ] ) ] ],
        Failure[ "WolframDebugging", KeyValuePattern[ "MessageParameters" -> { "WolframDebugging`CollectMessages", "StackFrames", "-1", _ } ] ],
        Failure[ "WolframDebugging", KeyValuePattern[ "Expected" -> "CollectMessages[expr, opts]" ] ]
    },
    SameTest -> MatchQ,
    TestID   -> "CollectMessages-InvalidCall@@Tests/WolframDebuggingSkill.wlt:347,1-360,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*StackAtMessage*)
VerificationTest[
    WolframDebugging`StackAtMessage[ wdtMyFn[ -1, 1 ], Power::infy ],
    <|
        "Result"      -> Missing[ "Stopped" ],
        "Message"     -> "Power::infy: Infinite expression 0^(-1) encountered.",
        "Stack"       -> "(6 frames)\n1| wdtMyFn[-1, 1]\n2| Table[wdtOtherFn[i], {i, -1, 1}]\n3| wdtOtherFn[i]\n4| 1/0\n5| 0^(-1)\n6| Message[Power::infy, HoldCompleteForm[0^(-1)]]",
        "StackLength" -> 6
    |>,
    { Power::infy },
    SameTest -> SameQ,
    TestID   -> "StackAtMessage@@Tests/WolframDebuggingSkill.wlt:365,1-376,2"
]

VerificationTest[
    {
        WolframDebugging`StackAtMessage[ 1 + 1 ],
        WolframDebugging`StackAtMessage[ wdtMyFn[ -1, 1 ], "First::*" ][ "Message" ],
        KeyTake[ WolframDebugging`StackAtMessage[ Table[ 1 / 0, 2 ], "MaxCount" -> 2, "Stop" -> False ], { "Result", "Count" } ]
    },
    {
        <| "Result" -> 2, "Message" -> None, "Stack" -> None |>,
        None,
        <| "Result" -> { ComplexInfinity, ComplexInfinity }, "Count" -> 2 |>
    },
    { Power::infy, Power::infy, Power::infy },
    SameTest -> SameQ,
    TestID   -> "StackAtMessage-Selection@@Tests/WolframDebuggingSkill.wlt:378,1-392,2"
]

VerificationTest[
    With[ { r = WolframDebugging`StackAtMessage[ wdtMyFn[ -1, 1 ], "RawStack" -> True ] },
        {
            Length @ r[ "RawStack" ],
            MatchQ[ r[ "RawStack" ], { ( HoldCompleteForm | HoldForm )[ _ ] .. } ],
            WolframDebugging`FormatStack[ r, "Filter" -> "User" ],
            WolframDebugging`FormatStack[ r[ "RawStack" ], "Filter" -> "Calls", "MaxFrameLength" -> 12 ],
            KeyDrop[ WolframDebugging`StackSummary @ r, "ByteCount" ]
        }
    ],
    {
        6,
        True,
        "(6 frames, 2 after Filter)\n1| wdtMyFn[-1, 1]\n3| wdtOtherFn[i]",
        "(6 frames, 2 after Filter)\n1| wdtMyFn[-...\n3| wdtOtherF...",
        <|
            "Length"   -> 6,
            "TopHeads" -> { { "wdtMyFn", 1 }, { "Table", 1 }, { "wdtOtherFn", 1 }, { "Times", 1 }, { "Power", 1 }, { "Message", 1 } },
            "Contexts" -> { { "System`", 4 }, { $Context, 2 } }
        |>
    },
    { Power::infy },
    SameTest -> SameQ,
    TestID   -> "StackAtMessage-RawStack@@Tests/WolframDebuggingSkill.wlt:394,1-418,2"
]

VerificationTest[
    {
        WolframDebugging`StackAtMessage[ 1, 2, 3 ],
        WolframDebugging`StackAtMessage[ 1, "MaxCount" -> 0 ],
        WolframDebugging`StackAtMessage[ 1, "Further output of `1` will be suppressed during this calculation." ]
    },
    { _Failure, _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "StackAtMessage-InvalidCall@@Tests/WolframDebuggingSkill.wlt:420,1-429,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*StackAtCall*)
VerificationTest[
    {
        WolframDebugging`StackAtCall[ wdtMyFn[ -1, 1 ], wdtOtherFn[ 0 ] ],
        DownValues @ wdtOtherFn
    },
    {
        <| "Result" -> Missing[ "Stopped" ], "Count" -> 1, "Stacks" -> { "(2 frames)\n1| Table[wdtOtherFn[i], {i, -1, 1}]\n2| wdtOtherFn[0]" } |>,
        { HoldPattern[ wdtOtherFn[ x_ ] ] :> 1 / x }
    },
    SameTest -> SameQ,
    TestID   -> "StackAtCall@@Tests/WolframDebuggingSkill.wlt:434,1-445,2"
]

VerificationTest[
    KeyTake[ WolframDebugging`StackAtCall[ wdtMyFn[ 1, 4 ], _wdtOtherFn, "MaxCount" -> 2, "Stop" -> False, "RawStack" -> True ], { "Result", "Count", "RawStacks" } ],
    <| "Result" -> { 1, 1 / 2, 1 / 3, 1 / 4 }, "Count" -> 2, "RawStacks" -> { { __ }, { __ } } |>,
    SameTest -> MatchQ,
    TestID   -> "StackAtCall-RecordAndContinue@@Tests/WolframDebuggingSkill.wlt:447,1-452,2"
]

VerificationTest[
    {
        WolframDebugging`StackAtCall[ 1, 5 ],
        WolframDebugging`StackAtCall[ 1, List[ 1 ] ],
        WolframDebugging`StackAtCall[ 1 ]
    },
    {
        Failure[ "WolframDebugging", KeyValuePattern[ "MessageTemplate" -> _String? ( StringStartsQ[ "Cannot find the head symbol" ] ) ] ],
        Failure[ "WolframDebugging", _ ],
        Failure[ "WolframDebugging", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "StackAtCall-InvalidCall@@Tests/WolframDebuggingSkill.wlt:454,1-467,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FormatStack*)
VerificationTest[
    {
        WolframDebugging`FormatStack @ { HoldCompleteForm[ wdtF[ 1 ] ], HoldForm[ 1 + 2 ], Plus },
        WolframDebugging`FormatStack[ Table[ HoldCompleteForm @@ { wdtF @ k }, { k, 10 } ], "MaxFrames" -> 3, "Collapse" -> False ],
        WolframDebugging`FormatStack @ Join[
            { HoldCompleteForm[ wdtStart[ ] ] },
            Flatten @ Table[ { HoldCompleteForm @@ { wdtRec @ k }, HoldCompleteForm @@ { wdtStep @ k } }, { k, 5 } ]
        ],
        WolframDebugging`FormatStack[ "(1 frames)\n1| f[]" ]
    },
    {
        "(3 frames)\n1| wdtF[1]\n2| 1 + 2\n3| Plus",
        "(10 frames, 7 earlier entries omitted)\n8| wdtF[8]\n9| wdtF[9]\n10| wdtF[10]",
        "(11 frames)\n1| wdtStart[]\n-- frames 2-11: a 2-frame cycle repeated 5 times (first and last shown) --\n2| wdtRec[1]\n3| wdtStep[1]\n   ...\n10| wdtRec[5]\n11| wdtStep[5]",
        "(1 frames)\n1| f[]"
    },
    SameTest -> SameQ,
    TestID   -> "FormatStack@@Tests/WolframDebuggingSkill.wlt:472,1-490,2"
]

(* frames of curried calls: the heads (wdtCurried[1][2]) must not be evaluated while formatting *)
VerificationTest[
    Module[ { calls = 0 },
        wdtCurried[ 1 ] := ( calls++; wdtCurriedValue );
        {
            WolframDebugging`FormatStack @ { HoldCompleteForm[ wdtCurried[ 1 ][ 2 ][ 3 ] ] },
            WolframDebugging`StackSummary[ { HoldCompleteForm[ wdtCurried[ 1 ][ 2 ][ 3 ] ], HoldForm[ "s"[ 1 ] ], HoldForm[ 5 ] } ][ "TopHeads" ],
            WolframDebugging`FormatStack[ { HoldCompleteForm[ wdtCurried[ 1 ][ 2 ][ 3 ] ], HoldForm[ 5 ] }, "Filter" -> "Calls" ],
            calls
        }
    ],
    {
        "(1 frames)\n1| wdtCurried[1][2][3]",
        { { "wdtCurried", 1 }, { "String", 1 }, { "None", 1 } },
        "(2 frames, 1 after Filter)\n1| wdtCurried[1][2][3]",
        0
    },
    SameTest -> SameQ,
    TestID   -> "FormatStack-CompoundHeadsNotEvaluated@@Tests/WolframDebuggingSkill.wlt:493,1-511,2"
]

VerificationTest[
    {
        WolframDebugging`FormatStack[ 1 ],
        WolframDebugging`FormatStack[ { }, "MaxFrames" -> 0 ],
        WolframDebugging`FormatStack[ "text", "MaxFrames" -> 3 ]
    },
    { _Failure, _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "FormatStack-InvalidCall@@Tests/WolframDebuggingSkill.wlt:513,1-522,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*StackSummary*)
VerificationTest[
    {
        WolframDebugging`StackSummary[ { HoldCompleteForm[ wdtF[ 1 ] ], HoldForm[ 1 + 2 ], HoldCompleteForm[ wdtF[ 2 ] ] } ][ "TopHeads" ],
        WolframDebugging`StackSummary[ 1 ]
    },
    { { { "wdtF", 2 }, { "Plus", 1 } }, _Failure },
    SameTest -> MatchQ,
    TestID   -> "StackSummary@@Tests/WolframDebuggingSkill.wlt:527,1-535,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*CaptureEvaluation*)
VerificationTest[
    KeyDrop[ WolframDebugging`CaptureEvaluation[ Print[ "p" ]; 1 / 0; 5 ], { "PID", "Seconds" } ],
    <|
        "KernelID"     -> 0,
        "Result"       -> HoldComplete[ 5 ],
        "ResultString" -> "5",
        "MessageCount" -> 1,
        "Messages"     -> { "Power::infy: Infinite expression 0^(-1) encountered." },
        "PrintCount"   -> 1,
        "Prints"       -> { "p" },
        "Stack"        -> { "Print[\"p\"]; 1/0; 5", "1/0", "0^(-1)", "Message[Power::infy, HoldCompleteForm[0^(-1)]]" },
        "Aborted"      -> False,
        "Thrown"       -> None
    |>,
    { Power::infy },
    SameTest -> SameQ,
    TestID   -> "CaptureEvaluation@@Tests/WolframDebuggingSkill.wlt:540,1-557,2"
]

VerificationTest[
    {
        WolframDebugging`CaptureEvaluation[ Throw[ 1, "t" ] ][ "Thrown" ],
        WolframDebugging`CaptureEvaluation[ Throw[ 2 ] ][ "Thrown" ],
        WolframDebugging`CaptureEvaluation[ Abort[ ] ][ "Aborted" ],
        WolframDebugging`CaptureEvaluation[ ]
    },
    { "Throw[1, \"t\"]", "Throw[2]", True, _Failure },
    SameTest -> MatchQ,
    TestID   -> "CaptureEvaluation-ThrowAbortInvalid@@Tests/WolframDebuggingSkill.wlt:559,1-569,2"
]

VerificationTest[
    {
        With[ { cap = WolframDebugging`$CaptureFunction }, cap[ 1 + 1 ][ "ResultString" ] ],
        Complement[
            DeleteDuplicates @ Cases[ WolframDebugging`$CaptureFunction, s_Symbol :> Context @ Unevaluated @ s, Infinity, Heads -> True ],
            { "System`", "Internal`", "WolframDebugging`Private`" }
        ]
    },
    { "2", { } },
    SameTest -> SameQ,
    TestID   -> "CaptureFunction-SelfContained@@Tests/WolframDebuggingSkill.wlt:571,1-582,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Performance and Trace*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*SampleStacks*)
VerificationTest[
    KeyTake[ WolframDebugging`SampleStacks[ wdtLoop[ ], 1, "Interval" -> 0.05 ], { "TimedOut", "Functions%", "LastFrames", "Result" } ],
    KeyValuePattern @ {
        "TimedOut"   -> True,
        "Functions%" -> KeyValuePattern[ "wdtLoop" -> _? Positive ],
        "LastFrames" -> { "wdtLoop[]", __String },
        "Result"     -> $TimedOut
    },
    SameTest -> MatchQ,
    TestID   -> "SampleStacks-TimedOut@@Tests/WolframDebuggingSkill.wlt:591,1-601,2"
]

VerificationTest[
    KeyTake[ WolframDebugging`SampleStacks[ wdtCollatz[ 4 ], 5 ], { "TimedOut", "Result", "TimeLimit" } ],
    <| "TimedOut" -> False, "Result" -> 2, "TimeLimit" -> 5. |>,
    SameTest -> SameQ,
    TestID   -> "SampleStacks-Finished@@Tests/WolframDebuggingSkill.wlt:603,1-608,2"
]

VerificationTest[
    { WolframDebugging`SampleStacks[ 1, -1 ], WolframDebugging`SampleStacks[ 1, "Interval" -> 0 ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "SampleStacks-InvalidCall@@Tests/WolframDebuggingSkill.wlt:610,1-615,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TimeCalls*)
VerificationTest[
    KeyDrop[ WolframDebugging`TimeCalls[ wdtMyFn[ -3, 3 ], { wdtMyFn, wdtOtherFn } ], { "TotalSeconds", "Seconds" } ],
    <| "Calls" -> <| "wdtMyFn" -> 1, "wdtOtherFn" -> 7 |>, "Result" -> { -1 / 3, -1 / 2, -1, ComplexInfinity, 1, 1 / 2, 1 / 3 } |>,
    { Power::infy },
    SameTest -> SameQ,
    TestID   -> "TimeCalls@@Tests/WolframDebuggingSkill.wlt:620,1-626,2"
]

VerificationTest[
    {
        WolframDebugging`TimeCalls[ 1, { wdtConst } ],
        WolframDebugging`TimeCalls[ 1, wdtMyFn ],
        DownValues @ wdtMyFn === { HoldPattern[ wdtMyFn[ a_, b_ ] ] :> Table[ wdtOtherFn[ i ], { i, a, b } ] }
    },
    {
        Failure[ "WolframDebugging", KeyValuePattern[ "MessageTemplate" -> _String? ( StringContainsQ[ "OwnValues" ] ) ] ],
        _Failure,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "TimeCalls-InvalidCall@@Tests/WolframDebuggingSkill.wlt:628,1-641,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TraceAvailableQ*)
VerificationTest[
    { WolframDebugging`TraceAvailableQ[ ], WolframDebugging`TraceAvailableQ[ 1 ] },
    { Trace[ 1 + 1 ] =!= { }, _Failure },
    SameTest -> MatchQ,
    TestID   -> "TraceAvailableQ@@Tests/WolframDebuggingSkill.wlt:646,1-651,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TraceCalls*)
(* Trace records nothing in some kernels (e.g. wolfram -script): the helpers then return Failure["TraceUnavailable", ...] *)
VerificationTest[
    WolframDebugging`TraceCalls[ wdtFib[ 8 ], _wdtHlp, 3 ],
    If[ WolframDebugging`TraceAvailableQ[ ],
        <| "Calls" -> { "wdtHlp[0]", "wdtHlp[1]", "wdtHlp[0]" }, "EvaluationFinished" -> False |>,
        Failure[ "TraceUnavailable", _ ]
    ],
    SameTest -> MatchQ,
    TestID   -> "TraceCalls@@Tests/WolframDebuggingSkill.wlt:657,1-665,2"
]

VerificationTest[
    { WolframDebugging`TraceCalls[ 1, _f, 0 ], WolframDebugging`TraceCalls[ 1 ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "TraceCalls-InvalidCall@@Tests/WolframDebuggingSkill.wlt:667,1-672,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*CountCalls*)
VerificationTest[
    WolframDebugging`CountCalls[ wdtFib[ 8 ], _wdtFib | _wdtHlp ],
    If[ WolframDebugging`TraceAvailableQ[ ], <| "wdtFib" -> 67, "wdtHlp" -> 33 |>, Failure[ "TraceUnavailable", _ ] ],
    SameTest -> MatchQ,
    TestID   -> "CountCalls@@Tests/WolframDebuggingSkill.wlt:677,1-682,2"
]

VerificationTest[
    WolframDebugging`CountCalls[ 1, _f, "MaxEntries" -> 0 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "CountCalls-InvalidCall@@Tests/WolframDebuggingSkill.wlt:684,1-689,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FindHang*)
VerificationTest[
    { WolframDebugging`FindHang[ wdtCollatz[ 5 ], 2000, "LastSteps" -> 4 ], WolframDebugging`FindHang @ wdtCollatz[ 4 ] },
    If[ WolframDebugging`TraceAvailableQ[ ],
        {
            KeyValuePattern @ {
                "Finished"   -> False,
                "Steps"      -> 2000,
                "StackHeads" -> { "wdtCollatz", "Module", __String },
                "LastSteps"  -> { _String, _String, _String, _String }
            },
            <| "Finished" -> True, "Steps" -> _Integer, "Result" -> 2 |>
        },
        { Failure[ "TraceUnavailable", _ ], Failure[ "TraceUnavailable", _ ] }
    ],
    SameTest -> MatchQ,
    TestID   -> "FindHang@@Tests/WolframDebuggingSkill.wlt:694,1-710,2"
]

VerificationTest[
    WolframDebugging`FindHang[ 1, -5 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "FindHang-InvalidCall@@Tests/WolframDebuggingSkill.wlt:712,1-717,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Overrides*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LogCalls*)
VerificationTest[
    With[ { log = WolframDebugging`LogCalls[ { wdtFact }, wdtFact[ 3 ] ] },
        {
            log[ "Result" ],
            log[ "TotalCalls" ],
            log[ "Calls" ][[ 1, "Call" ]],
            StringReplace[ WolframDebugging`CallLogSummary[ log, 10, "MaxLength" -> 80 ], " (" ~~ Shortest[ __ ] ~~ " ms)" -> "" ],
            DownValues @ wdtFact
        }
    ],
    {
        6,
        4,
        HoldComplete @ wdtFact[ 3 ],
        "wdtFact[3] -> 6\n  wdtFact[2] -> 2\n    wdtFact[1] -> 1\n      wdtFact[0] -> 1",
        { HoldPattern[ wdtFact[ 0 ] ] :> 1, HoldPattern[ wdtFact[ n_ ] ] :> n * wdtFact[ n - 1 ] }
    },
    SameTest -> SameQ,
    TestID   -> "LogCalls@@Tests/WolframDebuggingSkill.wlt:726,1-745,2"
]

VerificationTest[
    {
        WolframDebugging`LogCalls[ { List }, { 1 } ],
        WolframDebugging`LogCalls[ { wdtConst }, 1 ],
        WolframDebugging`LogCalls[ { 1 }, 1 ],
        WolframDebugging`CallLogSummary[ <| |> ],
        WolframDebugging`CallLogSummary[ <| "Calls" -> { }, "TotalCalls" -> 0 |>, 0 ]
    },
    {
        Failure[ "WolframDebugging", KeyValuePattern[ "MessageTemplate" -> _String? ( StringContainsQ[ "Locked" ] ) ] ],
        Failure[ "WolframDebugging", KeyValuePattern[ "MessageTemplate" -> _String? ( StringContainsQ[ "OwnValues" ] ) ] ],
        _Failure,
        _Failure,
        _Failure
    },
    SameTest -> MatchQ,
    TestID   -> "LogCalls-InvalidCall@@Tests/WolframDebuggingSkill.wlt:747,1-764,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WithOverrides*)
VerificationTest[
    {
        WolframDebugging`WithOverrides[ { wdtOtherFn[ 0 ] :> "MOCK" }, wdtMyFn[ -1, 1 ] ],
        WolframDebugging`WithOverrides[ { wdtConst :> 5 }, wdtUseConst[ ] ],
        WolframDebugging`WithOverrides[ { HoldPattern[ wdtOtherFn[ x_ ] ] /; x > 5 :> "BIG", wdtOtherFn[ 7 ] :> "SEVEN" }, wdtMyFn[ 5, 7 ] ],
        DownValues @ wdtOtherFn,
        { wdtConst, wdtUseConst[ ] }
    },
    {
        HoldComplete[ { -1, "MOCK", 1 } ],
        HoldComplete[ 6 ],
        HoldComplete[ { Rational[ 1, 5 ], "BIG", "SEVEN" } ],  (* literal rules are tried before pattern rules *)
        { HoldPattern[ wdtOtherFn[ x_ ] ] :> 1 / x },
        { 3, 4 }
    },
    SameTest -> SameQ,
    TestID   -> "WithOverrides@@Tests/WolframDebuggingSkill.wlt:769,1-786,2"
]

VerificationTest[
    {
        WolframDebugging`WithOverrides[ { 1 :> 2 }, 1 ],
        WolframDebugging`WithOverrides[ { List[ _ ] :> 2 }, 1 ],
        WolframDebugging`WithOverrides[ wdtOtherFn[ 0 ] :> 1, 1 ]
    },
    {
        Failure[ "WolframDebugging", KeyValuePattern[ "MessageTemplate" -> _String? ( StringStartsQ[ "Cannot determine the symbol" ] ) ] ],
        Failure[ "WolframDebugging", KeyValuePattern[ "MessageTemplate" -> _String? ( StringContainsQ[ "Locked" ] ) ] ],
        Failure[ "WolframDebugging", KeyValuePattern[ "Function" -> "WolframDebugging`WithOverrides" ] ]
    },
    SameTest -> MatchQ,
    TestID   -> "WithOverrides-InvalidCall@@Tests/WolframDebuggingSkill.wlt:788,1-801,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*SnapshotDefinitions and RestoreDefinitions*)
VerificationTest[
    Module[ { snap = WolframDebugging`SnapshotDefinitions @ wdtOtherFn, r },
        wdtOtherFn[ _ ] := "CHANGED";
        SetAttributes[ wdtOtherFn, Listable ];
        r = { wdtOtherFn[ 2 ], WolframDebugging`RestoreDefinitions[ wdtOtherFn, snap ], wdtOtherFn[ 2 ], Attributes @ wdtOtherFn };
        Append[ r, snap[ "Symbol" ] ]
    ],
    { "CHANGED", True, 1 / 2, { }, _String? ( StringEndsQ[ "`wdtOtherFn" ] ) },
    SameTest -> MatchQ,
    TestID   -> "SnapshotRestoreDefinitions@@Tests/WolframDebuggingSkill.wlt:806,1-816,2"
]

VerificationTest[
    {
        WolframDebugging`SnapshotDefinitions[ List ],
        WolframDebugging`RestoreDefinitions[ wdtAdd, WolframDebugging`SnapshotDefinitions @ wdtOtherFn ],
        WolframDebugging`RestoreDefinitions[ wdtAdd, <| |> ],
        DownValues @ wdtAdd === { HoldPattern[ wdtAdd[ x_Integer, y_Integer ] ] :> x + y }
    },
    { _Failure, _Failure, _Failure, True },
    SameTest -> MatchQ,
    TestID   -> "SnapshotRestoreDefinitions-InvalidCall@@Tests/WolframDebuggingSkill.wlt:818,1-828,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Watchpoints and Probes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WatchChanges*)
VerificationTest[
    WolframDebugging`WatchChanges[ { wdtCounter }, wdtBump[ ]; wdtBump[ ] ],
    <|
        "Result"  -> 1,
        "Count"   -> 2,
        "Changes" -> {
            <| "Event" -> "HoldComplete[wdtCounter, 0, 1, OwnValues]", "Callers" -> { "wdtBump" } |>,
            <| "Event" -> "HoldComplete[wdtCounter, 1, 2, OwnValues]", "Callers" -> { "wdtBump" } |>
        }
    |>,
    SameTest -> SameQ,
    TestID   -> "WatchChanges@@Tests/WolframDebuggingSkill.wlt:837,1-849,2"
]

VerificationTest[
    { WolframDebugging`WatchChanges[ { 1 }, 1 ], WolframDebugging`WatchChanges[ { wdtCounter }, 1, "MaxEvents" -> -1 ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "WatchChanges-InvalidCall@@Tests/WolframDebuggingSkill.wlt:851,1-856,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*StopWhen*)
VerificationTest[
    {
        WolframDebugging`StopWhen[ wdtState, # > 2 &, Do[ wdtState = k, { k, 5 } ] ],
        WolframDebugging`StopWhen[ wdtState, # > 100 &, Do[ wdtState = k, { k, 5 } ]; wdtState ]
    },
    {
        <| "Stopped" -> True, "Event" -> "HoldComplete[wdtState, 2, 3, OwnValues]", "Stack" -> { "Do[wdtState = k, {k, 5}]", "wdtState = k" } |>,
        <| "Stopped" -> False, "Result" -> 5 |>
    },
    SameTest -> SameQ,
    TestID   -> "StopWhen@@Tests/WolframDebuggingSkill.wlt:861,1-872,2"
]

VerificationTest[
    WolframDebugging`StopWhen[ 1, # > 2 &, 1 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "StopWhen-InvalidCall@@Tests/WolframDebuggingSkill.wlt:874,1-879,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*NewSymbolsDuring*)
VerificationTest[
    WolframDebugging`NewSymbolsDuring @ ToExpression[ "wdtNewSymbol" <> ToString @ $SessionID <> " + 1" ],
    KeyValuePattern @ { "Count" -> 1, "NewSymbols" -> { _String? ( StringContainsQ[ "wdtNewSymbol" ] ) } },
    SameTest -> MatchQ,
    TestID   -> "NewSymbolsDuring@@Tests/WolframDebuggingSkill.wlt:884,1-889,2"
]

VerificationTest[
    WolframDebugging`NewSymbolsDuring[ 1, 2 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "NewSymbolsDuring-InvalidCall@@Tests/WolframDebuggingSkill.wlt:891,1-896,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FileWritesDuring*)
VerificationTest[
    With[ { file = wdtTempFile[ "txt" ] },
        WithCleanup[
            WolframDebugging`FileWritesDuring[ Export[ file, "x", "Text" ]; 1 ],
            Quiet @ DeleteFile @ file
        ] === <| "Result" -> 1, "Count" -> 1, "Writes" -> { { "OpenWrite", file } } |>
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FileWritesDuring@@Tests/WolframDebuggingSkill.wlt:901,1-911,2"
]

VerificationTest[
    WolframDebugging`FileWritesDuring[ 1, "MaxFiles" -> 0 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "FileWritesDuring-InvalidCall@@Tests/WolframDebuggingSkill.wlt:913,1-918,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*CapturePrints*)
VerificationTest[
    {
        WolframDebugging`CapturePrints[ Print[ "a" ]; Echo[ 2, "lbl" ]; 3 ],
        WolframDebugging`CapturePrints[ Do[ Print[ k ], { k, 5 } ], 2 ]
    },
    {
        <| "Result" -> 3, "PrintCount" -> 2, "Prints" -> { "a", ">> lbl 2" } |>,
        <| "Result" -> Null, "PrintCount" -> 5, "Prints" -> { "1", "2" } |>
    },
    SameTest -> SameQ,
    TestID   -> "CapturePrints@@Tests/WolframDebuggingSkill.wlt:923,1-934,2"
]

VerificationTest[
    WolframDebugging`CapturePrints[ 1, 0 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "CapturePrints-InvalidCall@@Tests/WolframDebuggingSkill.wlt:936,1-941,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FailedAssertions*)
VerificationTest[
    WolframDebugging`FailedAssertions[ wdtAssert[ -1 ] + wdtAssert[ 2 ] ],
    KeyValuePattern @ { "Result" -> 1, "Count" -> 1, "Failed" -> { KeyValuePattern @ { "Assert" -> "-1 > 0", "Callers" -> { "wdtAssert" } } } },
    SameTest -> MatchQ,
    TestID   -> "FailedAssertions@@Tests/WolframDebuggingSkill.wlt:946,1-951,2"
]

VerificationTest[
    WolframDebugging`FailedAssertions[ ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "FailedAssertions-InvalidCall@@Tests/WolframDebuggingSkill.wlt:953,1-958,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LeakCheck*)
VerificationTest[
    KeyDrop[ WolframDebugging`LeakCheck[ Do[ wdtLeaky[ ], 5 ], 2 ], { "MemoryDelta", "Result" } ],
    KeyValuePattern @ {
        "NewSymbols"         -> 5,
        "NewTemporaries"     -> 5,
        "TemporariesByName"  -> <| "t$*" -> 5 |>,
        "LargestTemporaries" -> { { _String, _Integer }, { _String, _Integer } },
        "OtherNewSymbols"    -> { }
    },
    SameTest -> MatchQ,
    TestID   -> "LeakCheck@@Tests/WolframDebuggingSkill.wlt:963,1-974,2"
]

VerificationTest[
    WolframDebugging`LeakCheck[ 1, -1 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "LeakCheck-InvalidCall@@Tests/WolframDebuggingSkill.wlt:976,1-981,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Unevaluated Calls*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WhyNoMatch*)
VerificationTest[
    WolframDebugging`WhyNoMatch @ wdtArea[ "4" ],
    KeyValuePattern @ {
        "Summary" -> "no rule matches; wdtArea[\"4\"] stays unevaluated (1 rule(s) checked)",
        "Call"    -> "wdtArea[\"4\"]",
        "Rules"   -> { "DownValues[[1]]: wdtArea[(r_)?NumericQ] -> test NumericQ[\"4\"] gave False" }
    },
    SameTest -> MatchQ,
    TestID   -> "WhyNoMatch-PatternTest@@Tests/WolframDebuggingSkill.wlt:990,1-999,2"
]

VerificationTest[
    {
        WolframDebugging`WhyNoMatch[ wdtMyFn[ 1 ] ][ "Rules" ],
        WolframDebugging`WhyNoMatch[ wdtAdd[ 1, 2.5 ] ][ "Rules" ],
        WolframDebugging`WhyNoMatch[ wdtArea[ 2 ] ][ "Summary" ]
    },
    {
        { "DownValues[[1]]: wdtMyFn[a_, b_] -> the call has 1 argument(s), the pattern takes 2" },
        { "DownValues[[1]]: wdtAdd[x_Integer, y_Integer] -> argument #2: 2.5 does not match y_Integer (head Real, pattern needs Integer)" },
        "DownValues[[1]] applies: wdtArea[(r_)?NumericQ]"
    },
    SameTest -> SameQ,
    TestID   -> "WhyNoMatch-Reasons@@Tests/WolframDebuggingSkill.wlt:1001,1-1014,2"
]

VerificationTest[
    WolframDebugging`WhyNoMatch[ wdtRep[ { 1, 2, 3. } ] ][ "Rules" ],
    {
        "DownValues[[1]]: wdtRep[x:{__Integer}] -> argument #1: {1, 2, 3.} -> element 3: 3. does not match _Integer (from __Integer) (head Real, pattern needs Integer)"
    },
    SameTest -> SameQ,
    TestID   -> "WhyNoMatch-NamedListPattern@@Tests/WolframDebuggingSkill.wlt:1016,1-1023,2"
]

VerificationTest[
    {
        WolframDebugging`WhyNoMatch[ wdtUndefinedFunction[ 1 ] ][ "Summary" ],
        WolframDebugging`WhyNoMatch[ Sin[ 1, 2 ] ][ "ArgumentCount" ],
        WolframDebugging`WhyNoMatch[ wdtMyFn[ Throw[ 1 ], 2 ] ][ "Summary" ]
    },
    {
        _String? ( StringContainsQ[ "no definitions at all" ] ),
        "2 (NOT allowed: 1 incl. options)",
        _String? ( StringStartsQ[ "the analysis was interrupted" ] )
    },
    SameTest -> MatchQ,
    TestID   -> "WhyNoMatch-NoDefinitionsBuiltinThrow@@Tests/WolframDebuggingSkill.wlt:1025,1-1038,2"
]

VerificationTest[
    { WolframDebugging`WhyNoMatch[ wdtArea[ 1 ], "MaxRules" -> -1 ], WolframDebugging`WhyNoMatch[ ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "WhyNoMatch-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1040,1-1045,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*StuckCalls*)
VerificationTest[
    WolframDebugging`StuckCalls @ { wdtArea[ "4" ], wdtHelprZZ[ 5 ], wdtArea[ 2 ] },
    <|
        "StuckCalls" -> 2,
        "ByHead"     -> <|
            "wdtArea"     -> "1x, has 1 DownValues, none matched (use WhyNoMatch), e.g. wdtArea[\"4\"]",
            "wdtHelprZZ"  -> "1x, NO definitions, e.g. wdtHelprZZ[5]"
        |>
    |>,
    SameTest -> SameQ,
    TestID   -> "StuckCalls@@Tests/WolframDebuggingSkill.wlt:1050,1-1061,2"
]

VerificationTest[
    WolframDebugging`StuckCalls[ 1, "MaxHeads" -> 0 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "StuckCalls-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1063,1-1068,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions and Source*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ShowDefinition*)
VerificationTest[
    {
        WolframDebugging`ShowDefinition @ wdtRP,
        WolframDebugging`ShowDefinition[ "wdtRP" ],
        WolframDebugging`ShowDefinition[ wdtRP, 5 ],
        WolframDebugging`ShowDefinition[ "wdtNoSuchSymbol" <> ToString @ $SessionID ],
        Attributes @ wdtRP
    },
    { "wdtRP[x_] := x + 1", "wdtRP[x_] := x + 1", "wd...", Missing[ "UnknownSymbol", _ ], { ReadProtected } },
    SameTest -> MatchQ,
    TestID   -> "ShowDefinition@@Tests/WolframDebuggingSkill.wlt:1077,1-1088,2"
]

VerificationTest[
    { WolframDebugging`ShowDefinition[ wdtRP, 0 ], WolframDebugging`ShowDefinition[ 1 ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "ShowDefinition-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1090,1-1095,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*SymbolKind*)
VerificationTest[
    {
        WolframDebugging`SymbolKind[ Plus ][ "KernelCode" ],
        WolframDebugging`SymbolKind @ wdtMyFn,
        WolframDebugging`SymbolKind[ "wdtNoSuchSymbol" <> ToString @ $SessionID ]
    },
    {
        True,
        <|
            "Symbol"       -> _String? ( StringEndsQ[ "`wdtMyFn" ] ),
            "Attributes"   -> { },
            "AutoloadStub" -> False,
            "Autoload"     -> None,
            "KernelCode"   -> False,
            "Counts"       -> <| "Own" -> 0, "Down" -> 1, "Up" -> 0, "Sub" -> 0 |>,
            "Usage"        -> Missing[ "NoUsage" ]
        |>,
        Missing[ "UnknownSymbol", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "SymbolKind@@Tests/WolframDebuggingSkill.wlt:1100,1-1121,2"
]

VerificationTest[
    WolframDebugging`SymbolKind[ Plus, 1 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "SymbolKind-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1123,1-1128,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FindSymbolSource*)
VerificationTest[
    WolframDebugging`FindSymbolSource[ "CodeParser`CodeParse", "Kinds" -> { "DownValue" }, "MaxDefinitions" -> 1 ],
    KeyValuePattern @ {
        "Symbol"           -> "CodeParser`CodeParse",
        "PacletRoots"      -> { _String? ( StringEndsQ[ "CodeParser" ] ) },
        "TotalDefinitions" -> _Integer? Positive,
        "Definitions"      -> {
            KeyValuePattern @ {
                "File"  -> _String? ( StringEndsQ[ ".wl" | ".m" ] ),
                "Lines" -> { _Integer, _Integer },
                "Kind"  -> "DownValue",
                "Text"  -> _String? ( StringContainsQ[ "CodeParse[" ] )
            }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "FindSymbolSource@@Tests/WolframDebuggingSkill.wlt:1133,1-1150,2"
]

VerificationTest[
    {
        WolframDebugging`FindSymbolSource[ "wdtNoSuchSymbol" <> ToString @ $SessionID ],
        WolframDebugging`FindSymbolSource[ "CodeParser`CodeParse", "Kinds" -> 5 ],
        WolframDebugging`FindSymbolSource[ 1 ]
    },
    { Missing[ "UnknownSymbol", _ ], _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "FindSymbolSource-UnknownAndInvalid@@Tests/WolframDebuggingSkill.wlt:1152,1-1161,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*PacletRoot*)
VerificationTest[
    {
        WolframDebugging`PacletRoot @ FindFile[ "CodeParser`" ],
        WolframDebugging`PacletRoot @ File @ $wdtPackageFile,
        WolframDebugging`PacletRoot[ "/nonexistent-wdt/x.m" ],
        WolframDebugging`PacletRoot[ 1 ]
    },
    {
        _String? ( StringEndsQ[ "CodeParser" ] ),
        Missing[ "NotFound", _ ] | _String,
        Missing[ "NotFound", "/nonexistent-wdt/x.m" ],
        _Failure
    },
    SameTest -> MatchQ,
    TestID   -> "PacletRoot@@Tests/WolframDebuggingSkill.wlt:1166,1-1181,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Loading*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LoadTrace*)
VerificationTest[
    With[ { file = wdtTempFile[ "wl" ] },
        WithCleanup[
            Export[ file, "wdtLoadedValue = 42", "Text" ];
            WolframDebugging`LoadTrace @ Get @ file,
            Quiet @ DeleteFile @ file
        ]
    ],
    KeyValuePattern @ {
        "Result"    -> 42,
        "LoadCount" -> 1,
        "Loads"     -> { { 0, "Get", _String, _String, _String } },
        "NewFiles"  -> { _String? ( StringStartsQ[ "wdt-" ] @* FileNameTake ) }
    },
    SameTest -> MatchQ,
    TestID   -> "LoadTrace@@Tests/WolframDebuggingSkill.wlt:1190,1-1206,2"
]

VerificationTest[
    WolframDebugging`LoadTrace[ 1, "MaxLoads" -> -1 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "LoadTrace-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1208,1-1213,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ContextSourceInfo*)
VerificationTest[
    WolframDebugging`ContextSourceInfo[ "CodeParser`" ],
    KeyValuePattern @ {
        "Context"    -> "CodeParser`",
        "FindFile"   -> _String,
        "Candidates" -> { { "CodeParser", _String, _String }, ___ },
        "StaleMX"    -> { }
    },
    SameTest -> MatchQ,
    TestID   -> "ContextSourceInfo@@Tests/WolframDebuggingSkill.wlt:1218,1-1228,2"
]

VerificationTest[
    { WolframDebugging`ContextSourceInfo[ "CodeParser" ], WolframDebugging`ContextSourceInfo[ ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "ContextSourceInfo-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1230,1-1235,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AutoloadStubQ and EnsureLoaded*)
VerificationTest[
    {
        WolframDebugging`AutoloadStubQ[ Plus ],
        WolframDebugging`AutoloadStubQ[ "Plus" ],
        WolframDebugging`AutoloadStubQ[ "wdtNoSuchSymbol" <> ToString @ $SessionID ],
        WolframDebugging`EnsureLoaded[ Plus ],
        WolframDebugging`EnsureLoaded[ "wdtNoSuchSymbol" <> ToString @ $SessionID ]
    },
    { False, False, False, True, Missing[ "UnknownSymbol", _ ] },
    SameTest -> MatchQ,
    TestID   -> "AutoloadStubQ-EnsureLoaded@@Tests/WolframDebuggingSkill.wlt:1240,1-1251,2"
]

VerificationTest[
    { WolframDebugging`AutoloadStubQ[ 1 ], WolframDebugging`EnsureLoaded[ Plus, Times ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "AutoloadStubQ-EnsureLoaded-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1253,1-1258,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tests*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TestFailureSummary*)
VerificationTest[
    With[ { tr = TestReport[ $wdtTestFile, ProgressReporting -> False, TimeConstraint -> 20 ] },
        {
            WolframDebugging`TestFailureSummary[ tr, "Format" -> "Text" ],
            Lookup[ WolframDebugging`TestFailureSummary @ tr, "TestID" ]
        }
    ],
    {
        "Wrong [Failure/SameTestFailure]\n  in:  StringJoin[\"a\", \"b\"]\n  exp: \"ba\"\n  act: \"ab\"\nMsg [MessagesFailure/SameMessagesFailure]\n  in:  1/0; 1\n  exp: 1\n  act: 1\n  msgs: Power::infy: Infinite expression 0^(-1) encountered.",
        { "Wrong", "Msg" }
    },
    SameTest -> SameQ,
    TestID   -> "TestFailureSummary@@Tests/WolframDebuggingSkill.wlt:1267,1-1280,2"
]

VerificationTest[
    { WolframDebugging`TestFailureSummary[ { } ], WolframDebugging`TestFailureSummary[ 1 ], WolframDebugging`TestFailureSummary[ { }, "Format" -> "XML" ] },
    { { }, _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "TestFailureSummary-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1282,1-1287,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TestSource*)
VerificationTest[
    {
        WolframDebugging`TestSource[ $wdtTestFile, "Wrong" ],
        Length @ WolframDebugging`TestSource[ $wdtTestFile, "*" ]
    },
    {
        { <| "TestID" -> "Wrong", "Lines" -> { 3, 3 }, "Code" -> "VerificationTest[StringJoin[\"a\", \"b\"], \"ba\", TestID -> \"Wrong\"]" |> },
        3
    },
    SameTest -> SameQ,
    TestID   -> "TestSource@@Tests/WolframDebuggingSkill.wlt:1292,1-1303,2"
]

VerificationTest[
    WolframDebugging`TestSource[ "/nonexistent-wdt/x.wlt", "Wrong" ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "TestSource-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1305,1-1310,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ReproduceTest*)
VerificationTest[
    {
        WolframDebugging`ReproduceTest @ WolframDebugging`TestSource[ $wdtTestFile, "Msg" ],
        WolframDebugging`ReproduceTest @ HoldComplete[ wdtMyFn[ -1, 1 ] ]
    },
    {
        <| "Result" -> "1", "Messages" -> { "Power::infy: Infinite expression 0^(-1) encountered." }, "StackAtFirstMessage" -> { "1/0; 1", "1/0", "0^(-1)" } |>,
        KeyValuePattern @ { "Result" -> "{-1, ComplexInfinity, 1}", "StackAtFirstMessage" -> { "Table[wdtOtherFn[i], {i, -1, 1}]", __ } }
    },
    { Power::infy, Power::infy },
    SameTest -> MatchQ,
    TestID   -> "ReproduceTest@@Tests/WolframDebuggingSkill.wlt:1315,1-1327,2"
]

VerificationTest[
    { WolframDebugging`ReproduceTest[ 1 ], WolframDebugging`ReproduceTest[ HoldComplete[ 1 ], "Frames" -> -1 ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "ReproduceTest-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1329,1-1334,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*RunTestsByID*)
VerificationTest[
    WolframDebugging`RunTestsByID[ $wdtTestFile, "Wrong" ],
    KeyValuePattern @ {
        "TestsRun"  -> 1,
        "Succeeded" -> 0,
        "Failed"    -> 1,
        "Outcomes"  -> { "Wrong" -> "Failure" },
        "Failures"  -> _String? ( StringStartsQ[ "Wrong [Failure/SameTestFailure]" ] )
    },
    SameTest -> MatchQ,
    TestID   -> "RunTestsByID@@Tests/WolframDebuggingSkill.wlt:1339,1-1350,2"
]

(* as in MCP Local: the session context is on $ContextPath and must not capture the test file's symbols *)
VerificationTest[
    Module[ { file = wdtTempFile[ "wlt" ], result },
        Export[ file, "VerificationTest[Context[wdtCtxSym], \"Global`\", TestID -> \"Ctx\"]", "Text" ];
        result = Block[ { $Context = "wdtSess`", $ContextPath = { "wdtSess`", "System`" } },
            wdtSess`wdtCtxSym = "session";
            WolframDebugging`RunTestsByID[ file, "Ctx", "Context" -> "Global`" ]
        ];
        DeleteFile @ file;
        Quiet @ Remove[ "wdtSess`wdtCtxSym", "Global`wdtCtxSym" ];
        Lookup[ result, { "TestsRun", "Succeeded" } ]
    ],
    { 1, 1 },
    SameTest -> SameQ,
    TestID   -> "RunTestsByID-SessionContextOnPath@@Tests/WolframDebuggingSkill.wlt:1353,1-1367,2"
]

(* the default context: the file is read in $Context (Sessions`<id>` in the MCP evaluator) and sees its definitions;
   new symbols of the tests go there too *)
VerificationTest[
    Module[ { file = wdtTempFile[ "wlt" ], result },
        Export[ file, "VerificationTest[{wdtTypedS[1], Context[wdtNewSym]}, {3, \"wdtSess`\"}, TestID -> \"Auto\"]", "Text" ];
        result = Block[ { $Context = "wdtSess`", $ContextPath = { "wdtSess`", "System`" } },
            wdtSess`wdtTypedS[ y_ ] := y + 2;
            WolframDebugging`RunTestsByID[ file, "Auto" ]
        ];
        DeleteFile @ file;
        Quiet @ Remove[ "wdtSess`wdtTypedS", "wdtSess`wdtNewSym" ];
        Lookup[ result, { "TestsRun", "Succeeded" } ]
    ],
    { 1, 1 },
    SameTest -> SameQ,
    TestID   -> "RunTestsByID-AutomaticContext@@Tests/WolframDebuggingSkill.wlt:1371,1-1385,2"
]

VerificationTest[
    { WolframDebugging`RunTestsByID[ "/nonexistent-wdt/x.wlt", "Wrong" ], WolframDebugging`RunTestsByID[ $wdtTestFile, "Wrong", "ReturnReport" -> 1 ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "RunTestsByID-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1387,1-1392,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*CheckTestFile*)
VerificationTest[
    { WolframDebugging`CheckTestFile @ $wdtTestFile, WolframDebugging`CheckTestFile[ $wdtBadTestFile ][[ All, "Issue" ]] },
    { { }, { "DuplicateTestID", "NoTestID", "MalformedVerificationTest", "TopLevelAbort" } },
    SameTest -> SameQ,
    TestID   -> "CheckTestFile@@Tests/WolframDebuggingSkill.wlt:1397,1-1402,2"
]

VerificationTest[
    WolframDebugging`CheckTestFile @ $wdtSyntaxTestFile,
    { KeyValuePattern @ { "Line" -> 3, "Issue" -> "SyntaxError", "Detail" -> _String } },
    SameTest -> MatchQ,
    TestID   -> "CheckTestFile-UnclosedCall@@Tests/WolframDebuggingSkill.wlt:1404,1-1409,2"
]

VerificationTest[
    WolframDebugging`CheckTestFile[ "/nonexistent-wdt/x.wlt" ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "CheckTestFile-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1411,1-1416,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Parallel and Asynchronous*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TaskReport and SubmitAndWait*)
VerificationTest[
    {
        WolframDebugging`TaskReport[ ][ "Count" ] === Length @ Tasks[ ],
        KeyDrop[ WolframDebugging`SubmitAndWait[ Print[ "tp" ]; Message[ wdtTask::boom ]; 5, 5 ], { "PID", "Seconds" } ],
        WolframDebugging`SubmitAndWait[ Pause[ 3 ]; 7, 0.5 ],
        Length @ Tasks[ ] === $wdtTaskCount
    },
    {
        True,
        KeyValuePattern @ { "ResultString" -> "5", "Prints" -> { "tp" }, "Wait" -> "Finished", "Messages" -> { "wdtTask::boom: Boom." } },
        <| "Wait" -> "TimedOut", "Result" -> Missing[ "NotFinished" ] |>,
        True
    },
    { wdtTask::boom },
    SameTest -> MatchQ,
    TestID   -> "TaskReport-SubmitAndWait@@Tests/WolframDebuggingSkill.wlt:1425,1-1441,2"
]

(* an outer time limit stops the wait: the task must still be removed *)
VerificationTest[
    {
        TimeConstrained[ WolframDebugging`SubmitAndWait[ Pause[ 3 ]; 1, 10 ], 1, "OuterTimeOut" ],
        Length @ Tasks[ ] === $wdtTaskCount
    },
    { "OuterTimeOut", True },
    SameTest -> SameQ,
    TestID   -> "SubmitAndWait-OuterTimeLimit@@Tests/WolframDebuggingSkill.wlt:1444,1-1452,2"
]

VerificationTest[
    { WolframDebugging`TaskReport[ 1 ], WolframDebugging`SubmitAndWait[ 1, -1 ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "TaskReport-SubmitAndWait-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1454,1-1459,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ParallelCapture and KernelReport*)
(* at most one subkernel; skipped where kernels cannot be launched (protected mode) *)
$wdtKernels = If[ TrueQ @ Developer`$ProtectedMode, { }, Quiet @ LaunchKernels[ 1 ] ];
$wdtParallelQ = MatchQ[ $wdtKernels, { _ } ];

VerificationTest[
    If[ $wdtParallelQ,
        {
            KeyTake[ WolframDebugging`ParallelCapture[ wdtSquare, { 1, 2, 3 } ], { "Kernels", "Items", "RanInMaster", "ProblemCount", "FirstResults" } ],
            KeyTake[ WolframDebugging`ParallelCapture[ wdtPkg`wdtCube, { 2 }, "DistributedContexts" -> None ], { "ProblemCount", "Problems" } ],
            KeyTake[ WolframDebugging`KernelReport[ ], { "Kernels", "SubkernelPIDs" } ]
        },
        "skipped"
    ],
    If[ $wdtParallelQ,
        {
            <| "Kernels" -> 1, "Items" -> 3, "RanInMaster" -> 0, "ProblemCount" -> 0, "FirstResults" -> { "1", "4", "9" } |>,
            <| "ProblemCount" -> 1, "Problems" -> { KeyValuePattern[ "MasterOnlyHeads" -> { "wdtPkg`wdtCube" } ] } |>,
            <| "Kernels" -> { _String }, "SubkernelPIDs" -> { _Integer } |>
        },
        "skipped"
    ],
    SameTest -> MatchQ,
    TestID   -> "ParallelCapture-KernelReport@@Tests/WolframDebuggingSkill.wlt:1468,1-1487,2"
]

VerificationTest[
    CloseKernels[ ];
    Kernels[ ],
    { },
    SameTest -> SameQ,
    TestID   -> "ParallelCapture-CloseKernels@@Tests/WolframDebuggingSkill.wlt:1489,1-1495,2"
]

VerificationTest[
    {
        KeyTake[ WolframDebugging`KernelReport[ ], { "Kernels", "SubkernelPIDs" } ],
        WolframDebugging`KernelReport[ 1 ],
        WolframDebugging`ParallelCapture[ wdtSquare, 1 ],
        WolframDebugging`ParallelCapture[ wdtSquare, { 1 }, "MaxRows" -> -1 ]
    },
    { <| "Kernels" -> { }, "SubkernelPIDs" -> { } |>, _Failure, _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "ParallelCapture-KernelReport-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1497,1-1507,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cloud and HTTP*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*HTTPSummary*)
VerificationTest[
    {
        WolframDebugging`HTTPSummary @ HTTPResponse[
            "<html><script>x=1</script><body>Hi <b>there</b></body></html>",
            <| "StatusCode" -> 500, "ContentType" -> "text/html" |>
        ],
        WolframDebugging`HTTPSummary @ <| "StatusCode" -> 404, "Headers" -> { "content-type" -> "application/json" }, "Body" -> "{ \"a\" : 1 }" |>,
        WolframDebugging`HTTPSummary @ Failure[ "ConnectionFailure", <| "URL" -> "http://localhost:1" |> ]
    },
    {
        <| "StatusCode" -> 500, "ContentType" -> _String? ( StringStartsQ[ "text/html" ] ), "Text" -> "Hi there" |>,
        <| "StatusCode" -> 404, "ContentType" -> "application/json", "Text" -> "{\"a\":1}" |>,
        <| "Failure" -> "ConnectionFailure", "Text" -> _String, "URL" -> "http://localhost:1" |>
    },
    SameTest -> MatchQ,
    TestID   -> "HTTPSummary@@Tests/WolframDebuggingSkill.wlt:1516,1-1532,2"
]

VerificationTest[
    { WolframDebugging`HTTPSummary[ 1 ], WolframDebugging`HTTPSummary[ <| "StatusCode" -> 200 |>, "MaxLength" -> 0 ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "HTTPSummary-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1534,1-1539,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DebugHTTPResponse*)
VerificationTest[
    WolframDebugging`DebugHTTPResponse[
        APIFunction[ { "a" -> "Integer", "b" -> "Integer" }, wdtMyFn[ #a, #b ] & ],
        <| "a" -> "-1", "b" -> "1" |>
    ],
    KeyValuePattern @ {
        "StatusCode"        -> 200,
        "Text"              -> "{-1, ComplexInfinity, 1}",
        "MessageCount"      -> 1,
        "Messages"          -> { KeyValuePattern[ "Message" -> HoldForm[ Power::infy ] ] },
        "FirstMessageStack" -> { "wdtMyFn[-1, 1]", "Table[wdtOtherFn[i], {i, -1, 1}]", "wdtOtherFn[i]", "1/0", "0^(-1)" }
    },
    { Power::infy },
    SameTest -> MatchQ,
    TestID   -> "DebugHTTPResponse@@Tests/WolframDebuggingSkill.wlt:1544,1-1559,2"
]

VerificationTest[
    WolframDebugging`DebugHTTPResponse[ APIFunction[ { }, 1 & ], 1 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "DebugHTTPResponse-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1561,1-1566,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*HTTPDiagnostics*)
VerificationTest[
    {
        WolframDebugging`HTTPDiagnostics[ 1 + 1 ],
        WolframDebugging`HTTPSummary[ WolframDebugging`HTTPDiagnostics[ 1 + 1, "Debug" -> True ], "MaxLength" -> 60 ][ "StatusCode" ],
        With[ { r = WolframDebugging`HTTPDiagnostics @ Throw[ 1, "x" ] },
            { r[ "StatusCode" ], Developer`ReadRawJSONString[ r[ "Body" ] ][ "Reason" ] }
        ],
        With[ { r = WolframDebugging`HTTPDiagnostics[ wdtMyFn[ -1, 1 ] ] },
            Developer`ReadRawJSONString[ r[ "Body" ] ][[ { "Reason", "Stack" } ]]
        ]
    },
    {
        2,
        200,
        { 500, "UncaughtThrow" },
        <| "Reason" -> "Messages", "Stack" -> { "wdtMyFn[-1, 1]", "Table[wdtOtherFn[i], {i, -1, 1}]", "wdtOtherFn[i]", "1/0", "0^(-1)" } |>
    },
    { Power::infy },
    SameTest -> SameQ,
    TestID   -> "HTTPDiagnostics@@Tests/WolframDebuggingSkill.wlt:1571,1-1591,2"
]

VerificationTest[
    WolframDebugging`HTTPDiagnostics[ 1, "TimeLimit" -> -1 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "HTTPDiagnostics-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1593,1-1598,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WithHTTPLog*)
(* a refused local connection: no network access *)
VerificationTest[
    Module[ { before },
        URLFetch;  (* load the autoload stub first *)
        before = DownValues @ URLFetch;
        {
            WolframDebugging`WithHTTPLog[ Quiet @ URLRead[ "http://127.0.0.1:1/wdt", TimeConstraint -> 5 ] ][ "Requests" ],
            DownValues @ URLFetch === before
        }
    ],
    { { KeyValuePattern @ { "Function" -> "URLFetch", "Method" -> "GET", "URL" -> "http://127.0.0.1:1/wdt", "Status" -> $Failed } }, True },
    SameTest -> MatchQ,
    TestID   -> "WithHTTPLog@@Tests/WolframDebuggingSkill.wlt:1604,1-1616,2"
]

VerificationTest[
    WolframDebugging`WithHTTPLog[ 1, "URLLength" -> 0 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "WithHTTPLog-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1618,1-1623,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Headless and Environments*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*EnvironmentFingerprint and FingerprintDiff*)
VerificationTest[
    With[ { fp = WolframDebugging`EnvironmentFingerprint[ ] },
        {
            Keys @ WolframDebugging`EnvironmentFingerprint[ { "Kind", "TraceWorks" } ],
            fp[ "TraceWorks" ] === WolframDebugging`TraceAvailableQ[ ],
            WolframDebugging`FingerprintDiff[ fp, fp ],
            WolframDebugging`FingerprintDiff[ fp, Append[ fp, "Limits" -> Append[ fp[ "Limits" ], "RecursionLimit" -> 77 ] ] ]
        }
    ],
    { { "Kind", "TraceWorks" }, True, <| |>, <| "Limits/RecursionLimit" -> { _, 77 } |> },
    SameTest -> MatchQ,
    TestID   -> "EnvironmentFingerprint-FingerprintDiff@@Tests/WolframDebuggingSkill.wlt:1632,1-1644,2"
]

VerificationTest[
    { WolframDebugging`EnvironmentFingerprint[ { "NoSuchKey" } ], WolframDebugging`FingerprintDiff[ 1, 2 ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "EnvironmentFingerprint-FingerprintDiff-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1646,1-1651,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FrontEndCalls*)
VerificationTest[
    Quiet @ WolframDebugging`FrontEndCalls[ NotebookDirectory[ ], 30 ],
    KeyValuePattern @ { "FrontEndCalls" -> _Association, "FrontEndMessages" -> { ___String }, "LaunchedFrontEnd" -> False },
    SameTest -> MatchQ,
    TestID   -> "FrontEndCalls@@Tests/WolframDebuggingSkill.wlt:1656,1-1661,2"
]

VerificationTest[
    WolframDebugging`FrontEndCalls[ 1, 0 ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "FrontEndCalls-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1663,1-1668,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*RunIsolated*)
VerificationTest[
    If[ TrueQ @ Developer`$ProtectedMode,
        WolframDebugging`RunIsolated[ "1" ],
        {
            KeyTake[ WolframDebugging`RunIsolated[ "Print[1 + 1]", "TimeLimit" -> 60 ], { "ExitCode", "Status", "StdOut", "KilledLeftovers" } ],
            KeyTake[ WolframDebugging`RunIsolated[ "Pause[60]", "TimeLimit" -> 3 ], { "Status" } ]
        }
    ],
    If[ TrueQ @ Developer`$ProtectedMode,
        Failure[ "ProtectedMode", _ ],
        { <| "ExitCode" -> 0, "Status" -> "OK", "StdOut" -> "2\n", "KilledLeftovers" -> { } |>, <| "Status" -> "TimedOut" |> }
    ],
    SameTest -> MatchQ,
    TestID   -> "RunIsolated@@Tests/WolframDebuggingSkill.wlt:1673,1-1687,2"
]

VerificationTest[
    { WolframDebugging`RunIsolated[ File[ "/nonexistent-wdt/x.wls" ] ], WolframDebugging`RunIsolated[ "1", "TimeLimit" -> 0 ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "RunIsolated-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1689,1-1694,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Static Checks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LintSummary*)
VerificationTest[
    { WolframDebugging`LintSummary[ "f[x_] := If[x = 1, {1,2,}, x]" ], WolframDebugging`LintSummary[ "f[x_] := x + 1" ] },
    { "L1:13 IfSet (Warning 0.85) `If` has `Set` as first argument.\nL1:25 Comma (Error 1.) Extra `,`.", "No issues." },
    SameTest -> SameQ,
    TestID   -> "LintSummary@@Tests/WolframDebuggingSkill.wlt:1703,1-1708,2"
]

VerificationTest[
    { WolframDebugging`LintSummary[ "f[x_] := x", 2 ], WolframDebugging`LintSummary[ 1 ] },
    { _Failure, _Failure },
    SameTest -> MatchQ,
    TestID   -> "LintSummary-InvalidCall@@Tests/WolframDebuggingSkill.wlt:1710,1-1715,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    Quiet @ DeleteDirectory[ DirectoryName @ $wdtTempDir, DeleteContents -> True ];
    {
        FileExistsQ @ $wdtTestFile,
        Kernels[ ],
        Length @ Tasks[ ] === $wdtTaskCount,
        wdtHandlerCounts[ ] === $wdtHandlers,
        $wdtSystemDefinitions === $wdtSystemDefinitionsBefore
    },
    { False, { }, True, True, True },
    SameTest -> SameQ,
    TestID   -> "Cleanup-NoStateLeft@@Tests/WolframDebuggingSkill.wlt:1720,1-1732,2"
]

(* :!CodeAnalysis::EndBlock:: *)
