(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Tools.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Tools.wlt:11,1-16,2"
]

(* Helper function to extract text from tool results (handles both string and structured content) *)
extractToolText[ str_String ] := str;
extractToolText[ as_Association ] /; KeyExistsQ[ as, "Content" ] :=
    StringJoin @ Cases[ as[ "Content" ], KeyValuePattern[ { "type" -> "text", "text" -> t_String } ] :> t ];
extractToolText[ _ ] := "";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$DefaultMCPTools*)
VerificationTest[
    $DefaultMCPTools,
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DefaultMCPTools-IsAssociation@@Tests/Tools.wlt:27,1-32,2"
]

VerificationTest[
    Keys @ $DefaultMCPTools,
    {
        OrderlessPatternSequence[
            "BuildPaclet",
            "CheckPaclet",
            "CodeInspector",
            "CreateSymbolDoc",
            "EditSymbolDoc",
            "EditSymbolDocExamples",
            "MCPAppsTest",
            "NotebookViewer",
            "ReadNotebook",
            "SubmitPaclet",
            "SymbolDefinition",
            "TestReport",
            "WolframAlpha",
            "WolframAlphaContext",
            "WolframContext",
            "WolframLanguageContext",
            "WolframLanguageEvaluator",
            "WriteNotebook"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "DefaultMCPTools-Keys@@Tests/Tools.wlt:34,1-60,2"
]

VerificationTest[
    AllTrue[ Values @ $DefaultMCPTools, MatchQ[ _LLMTool ] ],
    True,
    SameTest -> SameQ,
    TestID   -> "DefaultMCPTools-AllLLMTools@@Tests/Tools.wlt:62,1-67,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ReadNotebook*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $readNotebookTool = $DefaultMCPTools[ "ReadNotebook" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-GetTool@@Tests/Tools.wlt:76,1-81,2"
]

VerificationTest[
    $exampleNotebook = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources", "document.nb" },
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-FindExampleFile@@Tests/Tools.wlt:83,1-88,2"
]

VerificationTest[
    $readNotebookResult = $readNotebookTool[ <| "notebook" -> $exampleNotebook |> ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-BasicRead@@Tests/Tools.wlt:90,1-95,2"
]

VerificationTest[
    (* Check for the presence of a Wolfram Language code block *)
    StringContainsQ[ $readNotebookResult, "\n```wl\n" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ReadNotebook-ContainsExpectedContent@@Tests/Tools.wlt:97,1-103,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Cases*)
VerificationTest[
    $readNotebookTool[ <| "notebook" -> "nonexistent_file_12345.nb" |> ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "ReadNotebook-NonexistentFile@@Tests/Tools.wlt:108,1-113,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WriteNotebook*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $writeNotebookTool = $DefaultMCPTools[ "WriteNotebook" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-GetTool@@Tests/Tools.wlt:122,1-127,2"
]

VerificationTest[
    $tempNotebookFile = FileNameJoin[ { $TemporaryDirectory, "AgentToolsTest_" <> CreateUUID[ ] <> ".nb" } ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-CreateTempPath@@Tests/Tools.wlt:129,1-134,2"
]

VerificationTest[
    $writeNotebookResult = $writeNotebookTool[ <|
        "markdown" -> "# Test Notebook\n\nThis is a test paragraph.\n\n```wl\n1 + 1\n```",
        "file" -> $tempNotebookFile,
        "overwrite" -> False
    |> ],
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-BasicWrite@@Tests/Tools.wlt:136,1-145,2"
]

VerificationTest[
    FileExistsQ @ $tempNotebookFile,
    True,
    SameTest -> SameQ,
    TestID   -> "WriteNotebook-FileExists@@Tests/Tools.wlt:147,1-152,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Overwrite Behavior*)
VerificationTest[
    $writeNotebookTool[ <|
        "markdown" -> "# Another Test",
        "file" -> $tempNotebookFile,
        "overwrite" -> False
    |> ],
    _String? (StringStartsQ[ "File already exists" ]),
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-NoOverwriteExisting@@Tests/Tools.wlt:157,1-166,2"
]

VerificationTest[
    $writeNotebookTool[ <|
        "markdown" -> "# Overwritten Notebook",
        "file" -> $tempNotebookFile,
        "overwrite" -> True
    |> ],
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-OverwriteExisting@@Tests/Tools.wlt:168,1-177,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Missing Directories*)

(* Writing to a path whose parent directories do not exist should create the
   intermediate directories rather than failing with an internal error (GH#200). *)
VerificationTest[
    $missingDirRoot         = FileNameJoin @ { $TemporaryDirectory, "AgentToolsMissingDir_" <> CreateUUID[ ] };
    $missingDirNotebookFile = FileNameJoin @ { $missingDirRoot, "nested", "test.nb" };
    { DirectoryQ @ $missingDirRoot, StringQ @ $missingDirNotebookFile },
    { False, True },
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-MissingDirectory-Setup-GH#200"
]

VerificationTest[
    $writeNotebookTool[ <|
        "markdown"  -> "# Created In New Directory",
        "file"      -> $missingDirNotebookFile,
        "overwrite" -> False
    |> ],
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "WriteNotebook-MissingDirectory-CreatesPath-GH#200"
]

VerificationTest[
    FileExistsQ @ $missingDirNotebookFile,
    True,
    SameTest -> SameQ,
    TestID   -> "WriteNotebook-MissingDirectory-FileExists-GH#200"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup*)
VerificationTest[
    If[ FileExistsQ @ $tempNotebookFile, DeleteFile @ $tempNotebookFile ];
    If[ DirectoryQ @ $missingDirRoot, DeleteDirectory[ $missingDirRoot, DeleteContents -> True ] ];
    { FileExistsQ @ $tempNotebookFile, DirectoryQ @ $missingDirRoot },
    { False, False },
    SameTest -> SameQ,
    TestID   -> "WriteNotebook-Cleanup@@Tests/Tools.wlt:182,1-188,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframLanguageEvaluator*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $evaluatorTool = $DefaultMCPTools[ "WolframLanguageEvaluator" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-GetTool@@Tests/Tools.wlt:197,1-202,2"
]

VerificationTest[
    $evalResult1 = $evaluatorTool[ <| "code" -> "1 + 1" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-BasicEval@@Tests/Tools.wlt:204,1-209,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult1, "2" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-CorrectResult@@Tests/Tools.wlt:211,1-216,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult1, "Out[" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-HasOutLabel@@Tests/Tools.wlt:218,1-223,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Time Constraint*)
VerificationTest[
    $evalResult2 = $evaluatorTool[ <| "code" -> "Range[5]", "timeConstraint" -> 30 |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-WithTimeConstraint@@Tests/Tools.wlt:228,1-233,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult2, "{1, 2, 3, 4, 5}" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-RangeResult@@Tests/Tools.wlt:235,1-240,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Complex Expressions*)
VerificationTest[
    $evalResult3 = $evaluatorTool[ <| "code" -> "Table[n^2, {n, 1, 4}]" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-TableExpression@@Tests/Tools.wlt:245,1-250,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult3, "{1, 4, 9, 16}" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-TableResult@@Tests/Tools.wlt:252,1-257,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*String Output*)
VerificationTest[
    $evalResult4 = $evaluatorTool[ <| "code" -> "StringJoin[\"Hello\", \" \", \"World\"]" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-StringExpression@@Tests/Tools.wlt:262,1-267,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResult4, "Hello World" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-StringResult@@Tests/Tools.wlt:269,1-274,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Print Output*)
VerificationTest[
    $evalResultPrint1 = $evaluatorTool[ <| "code" -> "Print[\"Hello from Print\"]; 42" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-PrintBasic@@Tests/Tools.wlt:279,1-284,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResultPrint1, "Hello from Print" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-PrintOutputCaptured@@Tests/Tools.wlt:286,1-291,2"
]

VerificationTest[
    StringContainsQ[ extractToolText @ $evalResultPrint1, "42" ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-PrintResultIncluded@@Tests/Tools.wlt:293,1-298,2"
]

VerificationTest[
    $evalResultPrint2 = $evaluatorTool[ <| "code" -> "Print[\"First\"]; Print[\"Second\"]; Print[\"Third\"]; \"Done\"" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-MultiplePrints@@Tests/Tools.wlt:300,1-305,2"
]

VerificationTest[
    With[ { text = extractToolText @ $evalResultPrint2 },
        StringContainsQ[ text, "First" ] && StringContainsQ[ text, "Second" ] && StringContainsQ[ text, "Third" ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-MultiplePrintsCaptured@@Tests/Tools.wlt:307,1-314,2"
]

VerificationTest[
    $evalResultPrint3 = $evaluatorTool[ <| "code" -> "Do[Print[i], {i, 3}]; \"Complete\"" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageEvaluator-PrintInLoop@@Tests/Tools.wlt:316,1-321,2"
]

VerificationTest[
    With[ { text = extractToolText @ $evalResultPrint3 },
        StringContainsQ[ text, "1" ] && StringContainsQ[ text, "2" ] && StringContainsQ[ text, "3" ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageEvaluator-PrintInLoopCaptured@@Tests/Tools.wlt:323,1-330,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframAlpha*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $wolframAlphaTool = $DefaultMCPTools[ "WolframAlpha" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "WolframAlpha-GetTool@@Tests/Tools.wlt:339,1-344,2"
]

VerificationTest[
    $waResult = $wolframAlphaTool[ <| "query" -> "population of France" |> ],
    _String? StringQ | KeyValuePattern[ "Content" -> { __Association } ],
    SameTest -> MatchQ,
    TestID   -> "WolframAlpha-BasicQuery@@Tests/Tools.wlt:346,1-351,2"
]

VerificationTest[
    $waResultString =
        If[ StringQ @ $waResult,
            $waResult,
            StringJoin @ Select[ $waResult[[ "Content", All, "text" ]], StringQ ]
        ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "WolframAlpha-ResultString@@Tests/Tools.wlt:353,1-362,2"
]

VerificationTest[
    StringLength @ $waResultString > 0,
    True,
    SameTest -> SameQ,
    TestID   -> "WolframAlpha-NonEmptyResult@@Tests/Tools.wlt:364,1-369,2"
]

(* TODO: multiple queries aren't supported until the next Chatbook paclet update *)
(* VerificationTest[
    $waResult = $wolframAlphaTool[ <| "query" -> "population of France\tpopulation of Germany" |> ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "WolframAlpha-MultipleQueries@@Tests/Tools.wlt:279,1-284,2"
]

VerificationTest[
    StringCount[ $waResult, "<result query=" ],
    2,
    SameTest -> SameQ,
    TestID   -> "WolframAlpha-MultipleQueriesResultCount@@Tests/Tools.wlt:286,1-291,2"
] *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframLanguageContext*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $wlContextTool = $DefaultMCPTools[ "WolframLanguageContext" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageContext-GetTool@@Tests/Tools.wlt:393,1-398,2"
]

skipIfGitHubActions @ VerificationTest[
    $wlContextResult = $wlContextTool[ <| "context" -> "How to create a list of prime numbers in Wolfram Language" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageContext-BasicQuery@@Tests/Tools.wlt:400,23-405,2"
]

skipIfGitHubActions @ VerificationTest[
    StringLength[ extractToolText @ $wlContextResult ] > 0,
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageContext-NonEmptyResult@@Tests/Tools.wlt:407,23-412,2"
]

skipIfGitHubActions @ VerificationTest[
    StringContainsQ[ extractToolText @ $wlContextResult, "Prime" | "prime" | "Table" | "Range", IgnoreCase -> True ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageContext-RelevantContent@@Tests/Tools.wlt:414,23-419,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframAlphaContext*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $waContextTool = $DefaultMCPTools[ "WolframAlphaContext" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "WolframAlphaContext-GetTool@@Tests/Tools.wlt:428,1-433,2"
]

skipIfGitHubActions @ VerificationTest[
    $waContextResult = $waContextTool[ <| "context" -> "What is the distance from Earth to Mars" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframAlphaContext-BasicQuery@@Tests/Tools.wlt:435,23-440,2"
]

skipIfGitHubActions @ VerificationTest[
    StringLength[ extractToolText @ $waContextResult ] > 0,
    True,
    SameTest -> SameQ,
    TestID   -> "WolframAlphaContext-NonEmptyResult@@Tests/Tools.wlt:442,23-447,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframContext*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $wolframContextTool = $DefaultMCPTools[ "WolframContext" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "WolframContext-GetTool@@Tests/Tools.wlt:456,1-461,2"
]

skipIfGitHubActions @ VerificationTest[
    $wolframContextResult = $wolframContextTool[ <| "context" -> "How to compute derivatives symbolically" |> ],
    _String | _Association,
    SameTest -> MatchQ,
    TestID   -> "WolframContext-BasicQuery@@Tests/Tools.wlt:463,23-468,2"
]

skipIfGitHubActions @ VerificationTest[
    StringLength[ extractToolText @ $wolframContextResult ] > 0,
    True,
    SameTest -> SameQ,
    TestID   -> "WolframContext-NonEmptyResult@@Tests/Tools.wlt:470,23-475,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*TestReport*)

$allowExternal = ! StringQ @ Environment[ "GITHUB_ACTIONS" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Examples*)
VerificationTest[
    $testReportTool = $DefaultMCPTools[ "TestReport" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "TestReport-GetTool@@Tests/Tools.wlt:486,1-491,2"
]

VerificationTest[
    $testResourceDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources" },
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "TestReport-TestResourceDirectory@@Tests/Tools.wlt:493,1-498,2"
]

VerificationTest[
    $testReportResult = $testReportTool @ <|
        "paths" -> FileNameJoin @ { $testResourceDirectory, "TestFile1.wlt" },
        "newKernel" -> $allowExternal
    |>,
    _String? (StringContainsQ[ "# Test Results Summary"~~__~~"TestFile1.wlt" ]),
    SameTest -> MatchQ,
    TestID   -> "TestReport-SingleFile@@Tests/Tools.wlt:500,1-508,2"
]

VerificationTest[
    $testReportResult = $testReportTool @ <|
        "paths" -> StringJoin[
            FileNameJoin @ { $testResourceDirectory, "TestFile1.wlt" },
            ", ",
            FileNameJoin @ { $testResourceDirectory, "TestFile2.wlt" }
        ],
        "newKernel" -> $allowExternal
    |>,
    _String? (StringContainsQ[ "# Test Results Summary"~~__~~"TestFile1.wlt"~~__~~"TestFile2.wlt" ]),
    SameTest -> MatchQ,
    TestID   -> "TestReport-MultipleFiles@@Tests/Tools.wlt:510,1-522,2"
]

VerificationTest[
    $testReportResult = $testReportTool @ <|
        "paths" -> $testResourceDirectory,
        "newKernel" -> $allowExternal
    |>,
    _String? (StringContainsQ[ "# Test Results Summary"~~__~~"TestFile1.wlt"~~__~~"TestFile2.wlt" ]),
    SameTest -> MatchQ,
    TestID   -> "TestReport-Directory@@Tests/Tools.wlt:524,1-532,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$mcpRoot*)

(* The subprocess started by the external RunProcess path runs in $mcpRoot. The .wlt
   file uses a relative path (FileExistsQ["marker.txt"]) that only resolves when the
   subprocess's CWD is the temporary root, which exercises the ProcessDirectory plumbing. *)
skipIfGitHubActions @ VerificationTest[
    Module[ { tmpDir, savedRoot, testFile, result, ok },
        tmpDir    = CreateDirectory[ ];
        savedRoot = Wolfram`AgentTools`Common`$mcpRoot;
        testFile  = FileNameJoin @ { tmpDir, "MarkerTest.wlt" };
        WithCleanup[
            Export[ FileNameJoin @ { tmpDir, "marker.txt" }, "ok", "Text" ];
            Export[
                testFile,
                "VerificationTest[ FileExistsQ[ \"marker.txt\" ], True, TestID -> \"MarkerFound\" ]",
                "Text"
            ];
            Wolfram`AgentTools`Common`$mcpRoot = tmpDir;
            result = $testReportTool @ <|
                "paths"     -> testFile,
                "newKernel" -> True
            |>;
            ok = StringQ @ result &&
                 StringContainsQ[ result, "**Overall Result** | Success" ],
            Wolfram`AgentTools`Common`$mcpRoot = savedRoot;
            DeleteDirectory[ tmpDir, DeleteContents -> True ]
        ];
        ok
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "TestReport-McpRootRelativePath@@Tests/Tools.wlt:541,23-568,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Cases*)

(* GH#65: Nonexistent path should produce TestFileNotFound, not an internal failure *)
VerificationTest[
    $testReportTool[ <| "paths" -> CreateUUID[] <> "/does/not/exist.wlt" |> ],
    Failure[ "AgentTools::TestFileNotFound", _Association ],
    { AgentTools::TestFileNotFound },
    SameTest -> MatchQ,
    TestID   -> "TestReport-NonexistentFile-GH#65@@Tests/Tools.wlt:575,1-581,2"
]

VerificationTest[
    $testReportTool[ <| "paths" -> CreateUUID[] <> "/does/not/exist.wlt" |> ],
    _? (FreeQ[ "AgentTools::Internal" ]),
    { AgentTools::TestFileNotFound },
    SameTest -> MatchQ,
    TestID   -> "TestReport-NoInternalFailure-GH#65@@Tests/Tools.wlt:583,1-589,2"
]

VerificationTest[
    $testReportTool @ <|
        "paths" -> StringJoin[
            FileNameJoin @ { $testResourceDirectory, "TestFile1.wlt" },
            ", " <> CreateUUID[] <> "/does/not/exist.wlt"
        ]
    |>,
    _? (FreeQ[ "AgentTools::Internal" ]),
    { AgentTools::TestFileNotFound },
    SameTest -> MatchQ,
    TestID   -> "TestReport-MixedValidInvalidPaths-GH#65@@Tests/Tools.wlt:591,1-602,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Properties*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Names*)
VerificationTest[
    AllTrue[
        $DefaultMCPTools,
        Function[ tool, StringQ @ tool[ "Name" ] ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "ToolProperties-AllHaveNames@@Tests/Tools.wlt:611,1-619,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Descriptions*)
VerificationTest[
    AllTrue[
        $DefaultMCPTools,
        Function[ tool, StringQ @ tool[ "Description" ] ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "ToolProperties-AllHaveDescriptions@@Tests/Tools.wlt:624,1-632,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Parameters*)
VerificationTest[
    AllTrue[
        $DefaultMCPTools,
        Function[ tool, ListQ @ tool[ "Parameters" ] ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "ToolProperties-AllHaveParameters@@Tests/Tools.wlt:637,1-645,2"
]
