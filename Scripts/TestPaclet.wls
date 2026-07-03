#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`MCPServerScripts`" ];

If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

Needs[ "Wolfram`AgentTools`"  -> "mcp`"  ];
Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configure TestReport Output*)

(* Improve readability of GitHub Actions output by writing some test events to stdout: *)
$stdOut = First @ Streams[ "stdout" ];
SetOptions[ $stdOut, PageWidth -> Infinity ];
writeLine[ text___ ] := WriteString[ $stdOut, text, "\n" ];

SetOptions[
    TestReport,
    HandlerFunctions -> <|
        "FileStarted"   -> Function @ writeLine[ "Starting test file: ", #[ "TestFileName" ] ],
        "FileFinished"  -> Function @ writeLine[ "Finished test file: ", #[ "TestFileName" ] ],
        "TestCreated"   -> Function @ writeLine[ "\tCurrent test: " , #[ "TestObject" ][ "TestID" ] ],
        "TestEvaluated" -> checkTestResult
    |>,
    HandlerFunctionsKeys -> { "Outcome", "TestFileName", "TestObject" },
    ProgressReporting    -> False
];


checkTestResult[ as_Association ] :=
    Catch @ Module[ { outcome, testObject, testID, string },
        outcome = as[ "Outcome" ];
        If[ outcome =!= "Success",
            testObject = as[ "TestObject" ];
            If[ MemberQ[ FileNameSplit @ testObject[ "TestFileName" ], "TestResources" ], Throw @ Null ];
            testID = testObject[ "TestID" ];
            cicd`ConsoleError[ SequenceForm[ "\tTest failed: (", outcome, ") ", testID ], "Fatal" -> False ];
            If[ StringQ @ Environment[ "GITHUB_ACTIONS" ],
                string = ToString[
                    ReplaceAll[
                        testObject,
                        Hyperlink[ label_String, url_String ] /; And[
                            StringStartsQ[ label, "Report this issue" ],
                            StringStartsQ[ url, "https://github.com/" ~~ __ ~~ "/issues/new?" ]
                        ] :> RuleCondition @ Hyperlink[ label, First @ StringSplit[ url, "?" ] ]
                    ],
                    InputForm,
                    PageWidth -> Infinity
                ];
                If[ StringLength @ string > 5000, string = StringTake[ string, 5000 ] <> " ..." ];
                cicd`ConsoleLog @ string
            ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Get Test Paths*)
(* Get positional arguments (test paths) from command line *)
$testPaths = Select[
    Rest @ $scriptCommandLine, (* Skip script name *)
    StringQ[ # ] && ! StringStartsQ[ #, "-" ] & (* Exclude flags *)
];

(* Resolve test paths: use absolute paths if they exist, otherwise relative to paclet dir *)
$testTargets =
    If[ Length @ $testPaths > 0,
        Map[
            Which[
                FileExistsQ @ #                               , #,
                FileExistsQ @ FileNameJoin @ { $pacletDir, # }, FileNameJoin @ { $pacletDir, # },
                True                                          , # (* Let the test framework handle invalid paths *)
            ] &,
            $testPaths
        ],
        { FileNameJoin @ { $pacletDir, "Tests" } }
    ];

(* Collect test files from targets (files or directories) *)
$testFiles = Flatten[ If[ DirectoryQ[ # ], FileNames[ "*.wlt", # ], { # } ] & /@ $testTargets ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run Tests*)
(* When running tests in a GitHub Actions workflow, use the `TestPaclet` tool to generate proper GitHub annotations *)
runTests[ ___ ] /; StringQ @ Environment[ "GITHUB_ACTIONS" ] :=
    checkResult @ cicd`TestPaclet @ FileNameJoin @ { $pacletDir, "Tests" };

(* Use the `TestReportToolFunction` to generate nice readable markdown when running tests locally *)
runTests[ testFiles_List ] :=
    Module[ { args, markdown, outcome },
        args = <| "paths" -> StringRiffle[ testFiles, "," ] |>;
        markdown = cStr @ mcp`TestReportToolFunction[ args, "External" -> False ];
        writeLine[ "\n<test-results>\n" <> markdown <> "\n</test-results>\n" ];
        outcome = cStr @ First @ StringCases[ markdown, "| **Overall Result** | " ~~ o: Except[ "|" ].. ~~ " |" :> o ];
        (* :!CodeAnalysis::BeginBlock:: *)
        (* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
        If[ outcome =!= "Success", Exit[ 1 ] ];
        (* :!CodeAnalysis::EndBlock:: *)
        markdown
    ];

result = Quiet[
    Block[ { messageHandler }, runTests @ $testFiles ],
    {
        (* :!CodeAnalysis::BeginBlock:: *)
        (* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
        LLMServices`Defaults`Private`LLMFunctions::llmrstrt
        (* :!CodeAnalysis::EndBlock:: *)
    }
];

EndPackage[ ];

Wolfram`MCPServerScripts`result