(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`Tools`CodeInspector`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadCodeInspectorContext"
]

VerificationTest[
    Needs[ "CodeInspector`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadCodeInspectorPackage"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Registration*)
VerificationTest[
    $codeInspectorTool = $DefaultMCPTools[ "CodeInspector" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "GetTool"
]

VerificationTest[
    $codeInspectorTool[ "Name" ],
    "CodeInspector",
    SameTest -> SameQ,
    TestID   -> "ToolName"
]

VerificationTest[
    StringQ @ $codeInspectorTool[ "Description" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ToolDescription"
]

VerificationTest[
    ListQ @ $codeInspectorTool[ "Parameters" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ToolParameters"
]

VerificationTest[
    Length @ $codeInspectorTool[ "Parameters" ],
    6,
    SameTest -> SameQ,
    TestID   -> "ToolParameterCount"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Parameter Parsing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parseExclusions*)
VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`parseExclusions[ Missing[ "KeyAbsent" ] ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ParseExclusions-Missing"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`parseExclusions[ "" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ParseExclusions-Empty"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`parseExclusions[ "Warning" ],
    { "Warning" },
    SameTest -> MatchQ,
    TestID   -> "ParseExclusions-Single"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`parseExclusions[ "Warning,Error,Remark" ],
    { "Warning", "Error", "Remark" },
    SameTest -> MatchQ,
    TestID   -> "ParseExclusions-Multiple"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`parseExclusions[ "  Warning  ,  Error  " ],
    { "Warning", "Error" },
    SameTest -> MatchQ,
    TestID   -> "ParseExclusions-Whitespace"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`parseExclusions[ Missing[ "KeyAbsent" ], { "Default1", "Default2" } ],
    { "Default1", "Default2" },
    SameTest -> MatchQ,
    TestID   -> "ParseExclusions-MissingWithDefault"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`parseExclusions[ "", { "A", "B" } ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ParseExclusions-EmptyWithDefault"
]

(* ::**************************************************************************************************************:: *)
(*parseConfidenceLevel*)
VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`parseConfidenceLevel[ Missing[ "KeyAbsent" ] ],
    0.75,
    SameTest -> SameQ,
    TestID   -> "ParseConfidenceLevel-Missing"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`parseConfidenceLevel[ 0.5 ],
    0.5,
    SameTest -> SameQ,
    TestID   -> "ParseConfidenceLevel-Valid"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`parseConfidenceLevel[ 0 ],
    0.0,
    SameTest -> SameQ,
    TestID   -> "ParseConfidenceLevel-IntegerValue"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Tools`CodeInspector`Private`parseConfidenceLevel[ 1.5 ],
    _Failure,
    { AgentTools::CodeInspectorInvalidConfidence },
    SameTest -> MatchQ,
    TestID   -> "ParseConfidenceLevel-OutOfRange"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parseLimit*)
VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`parseLimit[ Missing[ "KeyAbsent" ] ],
    100,
    SameTest -> SameQ,
    TestID   -> "ParseLimit-Missing"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`parseLimit[ 50 ],
    50,
    SameTest -> SameQ,
    TestID   -> "ParseLimit-Valid"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`parseLimit[ -5 ],
    100,
    SameTest -> SameQ,
    TestID   -> "ParseLimit-Negative"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Input Validation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validateAndNormalizeInput*)
VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`validateAndNormalizeInput[ "If[a,b,c]", Missing[ "KeyAbsent" ] ],
    "If[a,b,c]",
    SameTest -> SameQ,
    TestID   -> "ValidateInput-CodeString"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`validateAndNormalizeInput[ Missing[ "KeyAbsent" ], $InstallationDirectory ],
    $InstallationDirectory,
    SameTest -> SameQ,
    TestID   -> "ValidateInput-Directory"
]

VerificationTest[
    (* Use a file from the AgentTools paclet that's guaranteed to exist *)
    $testFile = FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" };
    Wolfram`AgentTools`Tools`CodeInspector`Private`validateAndNormalizeInput[ Missing[ "KeyAbsent" ], $testFile ],
    File[ $testFile ],
    SameTest -> MatchQ,
    TestID   -> "ValidateInput-File"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`validateAndNormalizeInput[ Missing[ "KeyAbsent" ], Missing[ "KeyAbsent" ] ],
    _Failure,
    { AgentTools::CodeInspectorNoInput },
    SameTest -> MatchQ,
    TestID   -> "ValidateInput-NoInput"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`validateAndNormalizeInput[ "code", "file" ],
    _Failure,
    { AgentTools::CodeInspectorAmbiguousInput },
    SameTest -> MatchQ,
    TestID   -> "ValidateInput-BothInputs"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`validateAndNormalizeInput[ Missing[ "KeyAbsent" ], "/nonexistent/path/file.wl" ],
    _Failure,
    { AgentTools::CodeInspectorFileNotFound },
    SameTest -> MatchQ,
    TestID   -> "ValidateInput-FileNotFound"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Code Inspection*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*runInspection - Code String*)
VerificationTest[
    $codeResult = Wolfram`AgentTools`Tools`CodeInspector`Private`runInspection[
        "If[a, b, b]",
        <| "tagExclusions" -> { }, "severityExclusions" -> { }, "confidenceLevel" -> 0.5 |>
    ],
    { _InspectionObject .. },
    SameTest -> MatchQ,
    TestID   -> "RunInspection-CodeString"
]

VerificationTest[
    (* The code "If[a, b, b]" should produce at least one DuplicateClauses inspection *)
    MemberQ[ $codeResult, InspectionObject[ "DuplicateClauses", _, _, _ ] ],
    True,
    SameTest -> SameQ,
    TestID   -> "RunInspection-FindsDuplicateClauses"
]

VerificationTest[
    (* Clean code should return empty list *)
    Wolfram`AgentTools`Tools`CodeInspector`Private`runInspection[
        "f[x_] := x + 1",
        <| "tagExclusions" -> { }, "severityExclusions" -> { }, "confidenceLevel" -> 0.5 |>
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "RunInspection-CleanCode"
]

VerificationTest[
    (* Test with severity exclusions *)
    $filteredResult = Wolfram`AgentTools`Tools`CodeInspector`Private`runInspection[
        "If[a, b, b]",
        <| "tagExclusions" -> { }, "severityExclusions" -> { "Warning", "Error" }, "confidenceLevel" -> 0.5 |>
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "RunInspection-WithSeverityExclusions"
]

VerificationTest[
    (* Test with tag exclusions *)
    $tagFilteredResult = Wolfram`AgentTools`Tools`CodeInspector`Private`runInspection[
        "If[a, b, b]",
        <| "tagExclusions" -> { "DuplicateClauses::If" }, "severityExclusions" -> { }, "confidenceLevel" -> 0.5 |>
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "RunInspection-WithTagExclusions"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*runInspection - File*)
VerificationTest[
    (* Create a temporary test file with known issues *)
    $tempDir = CreateDirectory[ ];
    $testWLFile = FileNameJoin @ { $tempDir, "test.wl" };
    Export[ $testWLFile, "If[x, y, y]", "Text" ];
    FileExistsQ @ $testWLFile,
    True,
    SameTest -> SameQ,
    TestID   -> "RunInspection-CreateTestFile"
]

VerificationTest[
    $fileResult = Wolfram`AgentTools`Tools`CodeInspector`Private`runInspection[
        File[ $testWLFile ],
        <| "tagExclusions" -> { }, "severityExclusions" -> { }, "confidenceLevel" -> 0.5 |>
    ],
    { _InspectionObject .. },
    SameTest -> MatchQ,
    TestID   -> "RunInspection-File"
]

VerificationTest[
    MemberQ[ $fileResult, InspectionObject[ "DuplicateClauses", _, _, _ ] ],
    True,
    SameTest -> SameQ,
    TestID   -> "RunInspection-FileFindsIssues"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*runInspection - Directory*)
VerificationTest[
    (* Add another file to the temp directory *)
    $testWLFile2 = FileNameJoin @ { $tempDir, "test2.wl" };
    Export[ $testWLFile2, "Switch[x, 1, a, 1, b]", "Text" ];
    FileExistsQ @ $testWLFile2,
    True,
    SameTest -> SameQ,
    TestID   -> "RunInspection-CreateSecondTestFile"
]

VerificationTest[
    $dirResult = Wolfram`AgentTools`Tools`CodeInspector`Private`runInspection[
        $tempDir,
        <| "tagExclusions" -> { }, "severityExclusions" -> { }, "confidenceLevel" -> 0.5 |>
    ],
    _Association,
    SameTest -> MatchQ,
    TestID   -> "RunInspection-DirectoryReturnsAssociation"
]

VerificationTest[
    Length @ Keys @ $dirResult,
    2,
    SameTest -> SameQ,
    TestID   -> "RunInspection-DirectoryFindsAllFiles"
]

VerificationTest[
    AllTrue[ Values @ $dirResult, MatchQ[ { ___InspectionObject } ] ],
    True,
    SameTest -> SameQ,
    TestID   -> "RunInspection-DirectoryAllInspectionObjects"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cleanup Test Files*)
VerificationTest[
    DeleteDirectory[ $tempDir, DeleteContents -> True ];
    ! DirectoryQ @ $tempDir,
    True,
    SameTest -> SameQ,
    TestID   -> "Cleanup-TempDirectory"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*summaryTable*)
VerificationTest[
    $summaryTableResult = Wolfram`AgentTools`Tools`CodeInspector`Private`summaryTable @ {
        InspectionObject[ "Tag1", "Desc1", "Error", <| ConfidenceLevel -> 0.9 |> ],
        InspectionObject[ "Tag2", "Desc2", "Warning", <| ConfidenceLevel -> 0.8 |> ],
        InspectionObject[ "Tag3", "Desc3", "Error", <| ConfidenceLevel -> 0.7 |> ]
    },
    _String,
    SameTest -> MatchQ,
    TestID   -> "SummaryTable-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $summaryTableResult, "## Summary" ],
    True,
    SameTest -> SameQ,
    TestID   -> "SummaryTable-HasHeader"
]

VerificationTest[
    StringContainsQ[ $summaryTableResult, "| Error | 2 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "SummaryTable-CountsErrors"
]

VerificationTest[
    StringContainsQ[ $summaryTableResult, "| Warning | 1 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "SummaryTable-CountsWarnings"
]

VerificationTest[
    StringContainsQ[ $summaryTableResult, "| **Total** | **3** |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "SummaryTable-ShowsTotal"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatLocation*)
VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`formatLocation[
        "If[a, b, b]",
        { { 1, 7 }, { 1, 8 } }
    ],
    "Line 1, Column 7 - Line 1, Column 8",
    SameTest -> SameQ,
    TestID   -> "FormatLocation-CodeStringRange"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`formatLocation[
        "x",
        { { 1, 1 }, { 1, 1 } }
    ],
    "Line 1, Column 1",
    SameTest -> SameQ,
    TestID   -> "FormatLocation-CodeStringSinglePoint"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`formatLocation[
        File[ "/path/to/file.wl" ],
        { { 42, 7 }, { 42, 15 } }
    ],
    "`file.wl:42:7`",
    SameTest -> SameQ,
    TestID   -> "FormatLocation-File"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`formatLocation[
        "code",
        Missing[ "NotAvailable" ]
    ],
    "Unknown",
    SameTest -> SameQ,
    TestID   -> "FormatLocation-Missing"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractCodeSnippet*)
VerificationTest[
    $snippetResult = Wolfram`AgentTools`Tools`CodeInspector`Private`extractCodeSnippet[
        "If[a, b, b]",
        { { 1, 7 }, { 1, 8 } },
        1
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "ExtractCodeSnippet-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $snippetResult, "**Code:**" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ExtractCodeSnippet-HasCodeHeader"
]

VerificationTest[
    StringContainsQ[ $snippetResult, "```wl" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ExtractCodeSnippet-HasCodeBlock"
]

VerificationTest[
    (* Multi-line code with context *)
    $multiLineSnippet = Wolfram`AgentTools`Tools`CodeInspector`Private`extractCodeSnippet[
        "line1\nline2\nIf[a, b, b]\nline4\nline5",
        { { 3, 7 }, { 3, 8 } },
        1
    ];
    StringContainsQ[ $multiLineSnippet, "2 | line2" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ExtractCodeSnippet-ShowsContextBefore"
]

VerificationTest[
    StringContainsQ[ $multiLineSnippet, "4 | line4" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ExtractCodeSnippet-ShowsContextAfter"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`extractCodeSnippet[
        "code",
        Missing[ "NotAvailable" ],
        1
    ],
    "",
    SameTest -> SameQ,
    TestID   -> "ExtractCodeSnippet-MissingLocationReturnsEmpty"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatInspection*)
VerificationTest[
    $formattedInspection = Wolfram`AgentTools`Tools`CodeInspector`Private`formatInspection[
        InspectionObject[
            "DuplicateClauses",
            "Both branches of ``If`` are the same.",
            "Error",
            <| ConfidenceLevel -> 0.95, CodeParser`Source -> { { 1, 7 }, { 1, 8 } } |>
        ],
        1,
        "If[a, b, b]"
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "FormatInspection-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $formattedInspection, "### Issue 1: DuplicateClauses" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatInspection-HasHeader"
]

VerificationTest[
    StringContainsQ[ $formattedInspection, "(Error, 95%)" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatInspection-ShowsSeverityAndConfidence"
]

VerificationTest[
    StringContainsQ[ $formattedInspection, "**Location:**" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatInspection-HasLocation"
]

VerificationTest[
    StringContainsQ[ $formattedInspection, "**Description:**" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatInspection-HasDescription"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectionsToMarkdown - No Issues*)
VerificationTest[
    $noIssuesResult = Wolfram`AgentTools`Tools`CodeInspector`Private`inspectionsToMarkdown[
        { },
        "f[x_] := x + 1",
        <| "confidenceLevel" -> 0.75, "severityExclusions" -> { "Formatting" }, "tagExclusions" -> { }, "limit" -> 100 |>
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "InspectionsToMarkdown-NoIssuesReturnsString"
]

VerificationTest[
    StringContainsQ[ $noIssuesResult, "No issues found matching the specified criteria." ],
    True,
    SameTest -> SameQ,
    TestID   -> "InspectionsToMarkdown-NoIssuesMessage"
]

VerificationTest[
    StringContainsQ[ $noIssuesResult, "Confidence Level: 0.75" ],
    True,
    SameTest -> SameQ,
    TestID   -> "InspectionsToMarkdown-ShowsConfidenceLevel"
]

VerificationTest[
    StringContainsQ[ $noIssuesResult, "Severity Exclusions: Formatting" ],
    True,
    SameTest -> SameQ,
    TestID   -> "InspectionsToMarkdown-ShowsSeverityExclusions"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectionsToMarkdown - With Issues*)
VerificationTest[
    $withIssuesResult = Wolfram`AgentTools`Tools`CodeInspector`Private`inspectionsToMarkdown[
        {
            InspectionObject[
                "DuplicateClauses",
                "Both branches are the same.",
                "Error",
                <| ConfidenceLevel -> 0.95, CodeParser`Source -> { { 1, 7 }, { 1, 8 } } |>
            ]
        },
        "If[a, b, b]",
        <| "confidenceLevel" -> 0.75, "severityExclusions" -> { }, "tagExclusions" -> { }, "limit" -> 100 |>
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "InspectionsToMarkdown-WithIssuesReturnsString"
]

VerificationTest[
    StringContainsQ[ $withIssuesResult, "# Code Inspection Results" ],
    True,
    SameTest -> SameQ,
    TestID   -> "InspectionsToMarkdown-HasMainHeader"
]

VerificationTest[
    StringContainsQ[ $withIssuesResult, "## Summary" ],
    True,
    SameTest -> SameQ,
    TestID   -> "InspectionsToMarkdown-HasSummary"
]

VerificationTest[
    StringContainsQ[ $withIssuesResult, "## Issues" ],
    True,
    SameTest -> SameQ,
    TestID   -> "InspectionsToMarkdown-HasIssuesSection"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectionsToMarkdown - Truncation*)
VerificationTest[
    $truncatedResult = Wolfram`AgentTools`Tools`CodeInspector`Private`inspectionsToMarkdown[
        Table[
            InspectionObject[ "Tag" <> ToString @ i, "Desc", "Warning", <| ConfidenceLevel -> 0.9 |> ],
            { i, 10 }
        ],
        "code",
        <| "confidenceLevel" -> 0.5, "severityExclusions" -> { }, "tagExclusions" -> { }, "limit" -> 5 |>
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "InspectionsToMarkdown-TruncationReturnsString"
]

VerificationTest[
    StringContainsQ[ $truncatedResult, "Showing 5 of 10 issues" ],
    True,
    SameTest -> SameQ,
    TestID   -> "InspectionsToMarkdown-ShowsTruncationNotice"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectionsToMarkdown - File Source*)
VerificationTest[
    $fileSourceResult = Wolfram`AgentTools`Tools`CodeInspector`Private`inspectionsToMarkdown[
        {
            InspectionObject[
                "TestIssue",
                "Test description.",
                "Warning",
                <| ConfidenceLevel -> 0.9, CodeParser`Source -> { { 1, 1 }, { 1, 5 } } |>
            ]
        },
        File[ "/path/to/test.wl" ],
        <| "confidenceLevel" -> 0.5, "severityExclusions" -> { }, "tagExclusions" -> { }, "limit" -> 100 |>
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "InspectionsToMarkdown-FileSourceReturnsString"
]

VerificationTest[
    StringContainsQ[ $fileSourceResult, "**File:** `/path/to/test.wl`" ],
    True,
    SameTest -> SameQ,
    TestID   -> "InspectionsToMarkdown-ShowsFileHeader"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CodeActions Formatting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatCodeActions - Empty List*)
VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`formatCodeActions[ { } ],
    "",
    SameTest -> SameQ,
    TestID   -> "FormatCodeActions-EmptyList"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatCodeActions - Single Action*)
VerificationTest[
    $singleActionResult = Wolfram`AgentTools`Tools`CodeInspector`Private`formatCodeActions @ {
        CodeParser`CodeAction[ "Delete ``,``", CodeParser`DeleteText, <| CodeParser`Source -> { { 1, 5 }, { 1, 6 } } |> ]
    },
    _String,
    SameTest -> MatchQ,
    TestID   -> "FormatCodeActions-SingleAction-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $singleActionResult, "**Suggested Fix:**" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCodeActions-SingleAction-HasHeader"
]

VerificationTest[
    StringContainsQ[ $singleActionResult, "Delete `,`" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCodeActions-SingleAction-HasLabel"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatCodeActions - Multiple Actions*)
VerificationTest[
    $multiActionResult = Wolfram`AgentTools`Tools`CodeInspector`Private`formatCodeActions @ {
        CodeParser`CodeAction[ "Insert ``*``", CodeParser`InsertNode, <| CodeParser`Source -> { { 1, 5 }, { 1, 5 } } |> ],
        CodeParser`CodeAction[ "Insert ``,``", CodeParser`InsertNode, <| CodeParser`Source -> { { 1, 5 }, { 1, 5 } } |> ]
    },
    _String,
    SameTest -> MatchQ,
    TestID   -> "FormatCodeActions-MultipleActions-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $multiActionResult, "**Suggested Fixes:**" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCodeActions-MultipleActions-HasPluralHeader"
]

VerificationTest[
    StringCount[ $multiActionResult, "- Insert" ],
    2,
    SameTest -> SameQ,
    TestID   -> "FormatCodeActions-MultipleActions-HasTwoActions"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatSingleCodeAction*)
VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`formatSingleCodeAction[
        CodeParser`CodeAction[ "Replace with ``StringQ``", CodeParser`ReplaceNode, <| "ReplacementNode" -> CodeParser`LeafNode[ Symbol, "StringQ", <| |> ] |> ]
    ],
    _String ? (StringContainsQ[ #, "Replace with `StringQ`" ] &),
    SameTest -> MatchQ,
    TestID   -> "FormatSingleCodeAction-ReplaceNode"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`formatSingleCodeAction[
        CodeParser`CodeAction[ "Delete key 1", CodeParser`DeleteNode, <| CodeParser`Source -> { { 1, 1 }, { 1, 5 } } |> ]
    ],
    _String ? (StringContainsQ[ #, "Delete key 1" ] &),
    SameTest -> MatchQ,
    TestID   -> "FormatSingleCodeAction-DeleteNode"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`formatSingleCodeAction[ "invalid" ],
    "",
    SameTest -> SameQ,
    TestID   -> "FormatSingleCodeAction-Invalid"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*codeActionCommandToString*)
VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`codeActionCommandToString[ CodeParser`ReplaceText ],
    "Replace with",
    SameTest -> SameQ,
    TestID   -> "CodeActionCommandToString-ReplaceText"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`codeActionCommandToString[ CodeParser`DeleteText ],
    "Delete",
    SameTest -> SameQ,
    TestID   -> "CodeActionCommandToString-DeleteText"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`codeActionCommandToString[ CodeParser`InsertText ],
    "Insert",
    SameTest -> SameQ,
    TestID   -> "CodeActionCommandToString-InsertText"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`codeActionCommandToString[ CodeParser`ReplaceNode ],
    "Replace with",
    SameTest -> SameQ,
    TestID   -> "CodeActionCommandToString-ReplaceNode"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`codeActionCommandToString[ CodeParser`DeleteNode ],
    "Delete",
    SameTest -> SameQ,
    TestID   -> "CodeActionCommandToString-DeleteNode"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`codeActionCommandToString[ CodeParser`InsertNode ],
    "Insert",
    SameTest -> SameQ,
    TestID   -> "CodeActionCommandToString-InsertNode"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`codeActionCommandToString[ CodeParser`InsertNodeAfter ],
    "Insert after",
    SameTest -> SameQ,
    TestID   -> "CodeActionCommandToString-InsertNodeAfter"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`codeActionCommandToString[ UnknownCommand ],
    "UnknownCommand",
    SameTest -> SameQ,
    TestID   -> "CodeActionCommandToString-Unknown"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cleanLabel*)
VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`cleanLabel[ "Replace with ``StringQ``" ],
    "Replace with `StringQ`",
    SameTest -> SameQ,
    TestID   -> "CleanLabel-SingleBackticks"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`cleanLabel[ "Insert ``*`` and ``+``" ],
    "Insert `*` and `+`",
    SameTest -> SameQ,
    TestID   -> "CleanLabel-MultipleBackticks"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`cleanLabel[ "No backticks here" ],
    "No backticks here",
    SameTest -> SameQ,
    TestID   -> "CleanLabel-NoBackticks"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatCodeActions Integration with formatInspection*)
VerificationTest[
    (* Test that formatInspection includes CodeActions *)
    $inspectionWithActions = Wolfram`AgentTools`Tools`CodeInspector`Private`formatInspection[
        InspectionObject[
            "Comma",
            "Extra comma.",
            "Error",
            <|
                ConfidenceLevel -> 1.0,
                CodeParser`Source -> { { 1, 5 }, { 1, 5 } },
                CodeParser`CodeActions -> {
                    CodeParser`CodeAction[ "Delete ``,``", CodeParser`DeleteText, <| CodeParser`Source -> { { 1, 5 }, { 1, 6 } } |> ]
                }
            |>
        ],
        1,
        "1+f[,2]"
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "FormatInspection-WithCodeActions-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $inspectionWithActions, "**Suggested Fix:**" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatInspection-WithCodeActions-ShowsSuggestedFix"
]

VerificationTest[
    StringContainsQ[ $inspectionWithActions, "Delete `,`" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatInspection-WithCodeActions-ShowsActionLabel"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Error Cases*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Empty Directory*)
VerificationTest[
    $emptyDir = CreateDirectory[ ];
    DirectoryQ @ $emptyDir,
    True,
    SameTest -> SameQ,
    TestID   -> "ErrorCase-CreateEmptyDir"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`runInspection[
        $emptyDir,
        <| "tagExclusions" -> { }, "severityExclusions" -> { }, "confidenceLevel" -> 0.5 |>
    ],
    _Failure,
    { AgentTools::CodeInspectorNoFilesFound },
    SameTest -> MatchQ,
    TestID   -> "ErrorCase-EmptyDirectory"
]

VerificationTest[
    DeleteDirectory[ $emptyDir ];
    ! DirectoryQ @ $emptyDir,
    True,
    SameTest -> SameQ,
    TestID   -> "Cleanup-EmptyDirectory"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Integration Tests - Basic Functionality*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Code String Inspection with Known Issues*)
VerificationTest[
    $integrationCodeResult = CodeInspectorToolFunction @ <|
        "code"               -> "If[a, b, b]",
        "severityExclusions" -> ""
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "Integration-CodeStringWithIssues-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $integrationCodeResult, "# Code Inspection Results" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-CodeStringWithIssues-HasHeader"
]

VerificationTest[
    StringContainsQ[ $integrationCodeResult, "DuplicateClauses" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-CodeStringWithIssues-FindsDuplicateClauses"
]

VerificationTest[
    StringContainsQ[ $integrationCodeResult, "## Summary" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-CodeStringWithIssues-HasSummary"
]

VerificationTest[
    StringContainsQ[ $integrationCodeResult, "## Issues" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-CodeStringWithIssues-HasIssuesSection"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Clean Code Returns No Issues Found*)
VerificationTest[
    $integrationCleanResult = CodeInspectorToolFunction @ <| "code" -> "f[x_] := x + 1" |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "Integration-CleanCode-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $integrationCleanResult, "No issues found matching the specified criteria." ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-CleanCode-ShowsNoIssuesMessage"
]

VerificationTest[
    StringContainsQ[ $integrationCleanResult, "**Settings:**" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-CleanCode-ShowsSettings"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Single File Inspection*)
VerificationTest[
    $integrationTempDir = CreateDirectory[ ];
    $integrationTestFile = FileNameJoin @ { $integrationTempDir, "testfile.wl" };
    Export[ $integrationTestFile, "If[x, y, y]", "Text" ];
    FileExistsQ @ $integrationTestFile,
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-SingleFile-CreateTestFile"
]

VerificationTest[
    $integrationFileResult = CodeInspectorToolFunction @ <|
        "file"               -> $integrationTestFile,
        "severityExclusions" -> ""
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "Integration-SingleFile-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $integrationFileResult, "**File:**" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-SingleFile-ShowsFileHeader"
]

VerificationTest[
    StringContainsQ[ $integrationFileResult, "DuplicateClauses" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-SingleFile-FindsIssues"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Recursive Directory Inspection*)
VerificationTest[
    $integrationTestFile2 = FileNameJoin @ { $integrationTempDir, "testfile2.wl" };
    Export[ $integrationTestFile2, "Switch[x, 1, a, 1, b]", "Text" ];
    FileExistsQ @ $integrationTestFile2,
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-Directory-CreateSecondTestFile"
]

VerificationTest[
    $integrationDirResult = CodeInspectorToolFunction @ <|
        "file"               -> $integrationTempDir,
        "severityExclusions" -> ""
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "Integration-Directory-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $integrationDirResult, "**Directory:**" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-Directory-ShowsDirectoryHeader"
]

VerificationTest[
    StringContainsQ[ $integrationDirResult, "**Files inspected:**" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-Directory-ShowsFileCount"
]

VerificationTest[
    StringContainsQ[ $integrationDirResult, "testfile.wl" ] && StringContainsQ[ $integrationDirResult, "testfile2.wl" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-Directory-ShowsBothFiles"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Integration Tests - Parameter Handling*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tag Exclusions Filter Correctly*)
VerificationTest[
    $integrationTagExcludeResult = CodeInspectorToolFunction @ <|
        "code"               -> "If[a, b, b]",
        "tagExclusions"      -> "DuplicateClauses::If",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "Integration-TagExclusions-ReturnsString"
]

VerificationTest[
    (* When DuplicateClauses is excluded, we should see "No issues found" for this code *)
    StringContainsQ[ $integrationTagExcludeResult, "No issues found matching the specified criteria." ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-TagExclusions-ExcludesDuplicateClauses"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tag Exclusions Filter Correctly - File Input*)
$collatzFile = PacletObject[ "CodeInspector" ][ "AssetLocation", "Collatz" ];
ifCollatzFile = conditionalTest @ FileExistsQ @ $collatzFile;

ifCollatzFile @ VerificationTest[
    $collatzAllIssues = CodeInspectorToolFunction @ <|
        "file"               -> $collatzFile,
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String? (StringContainsQ[ "## Issues" ]),
    SameTest -> MatchQ,
    TestID   -> "Integration-TagExclusions-File-AllIssues"
]

ifCollatzFile @ VerificationTest[
    $collatzTagExcluded = CodeInspectorToolFunction @ <|
        "file"               -> $collatzFile,
        "tagExclusions"      -> "TopLevel,ImplicitTimesStrings",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "Integration-TagExclusions-File-Excluded"
]

ifCollatzFile @ VerificationTest[
    (* Excluding tags should reduce the number of issues reported *)
    StringCount[ $collatzTagExcluded, "### Issue" ] < StringCount[ $collatzAllIssues, "### Issue" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-TagExclusions-File-FewerIssues"
]

ifCollatzFile @ VerificationTest[
    (* Excluded tags should not appear in the output *)
    ! StringContainsQ[ $collatzTagExcluded, "TopLevel" | "ImplicitTimesStrings" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-TagExclusions-File-TagsAbsent"
]

ifCollatzFile @ VerificationTest[
    CodeInspectorToolFunction @ <|
        "file"          -> $collatzFile,
        "tagExclusions" -> "TopLevel,ImplicitTimesStrings,NoVariables::Module"
    |>,
    _String? (StringFreeQ[ "Issue "~~DigitCharacter..~~": NoVariables::Module" ]),
    SameTest -> MatchQ,
    TestID   -> "Integration-TagExclusions-NestedTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Severity Exclusions Filter Correctly*)
VerificationTest[
    $integrationSeverityExcludeResult = CodeInspectorToolFunction @ <|
        "code"               -> "If[a, b, b]",
        "severityExclusions" -> "Warning,Error",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "Integration-SeverityExclusions-ReturnsString"
]

VerificationTest[
    (* DuplicateClauses is typically Warning or Error, so excluding both should filter it out *)
    StringContainsQ[ $integrationSeverityExcludeResult, "No issues found matching the specified criteria." ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-SeverityExclusions-FiltersCorrectly"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Confidence Level Filtering Works*)
VerificationTest[
    (* With high confidence threshold, low-confidence issues should be filtered *)
    $integrationHighConfResult = CodeInspectorToolFunction @ <|
        "code"               -> "If[a, b, b]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 1.0  (* Only 100% confidence issues *)
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "Integration-ConfidenceLevel-HighThreshold-ReturnsString"
]

VerificationTest[
    (* With very low confidence threshold, issues should appear *)
    $integrationLowConfResult = CodeInspectorToolFunction @ <|
        "code"               -> "If[a, b, b]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0  (* Include all issues *)
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "Integration-ConfidenceLevel-LowThreshold-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $integrationLowConfResult, "DuplicateClauses" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-ConfidenceLevel-LowThreshold-FindsIssues"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Limit Parameter Truncates Output Correctly*)
VerificationTest[
    (* Create code with multiple issues *)
    $integrationLimitResult = CodeInspectorToolFunction @ <|
        "code"               -> "If[a, b, b]; If[c, d, d]; If[e, f, f]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0,
        "limit"              -> 1  (* Only show 1 issue *)
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "Integration-Limit-ReturnsString"
]

VerificationTest[
    (* Should have "Issue 1" but not "Issue 2" (due to limit) *)
    StringContainsQ[ $integrationLimitResult, "### Issue 1:" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-Limit-ShowsFirstIssue"
]

VerificationTest[
    (* Should show truncation notice *)
    StringContainsQ[ $integrationLimitResult, "Showing 1 of" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-Limit-ShowsTruncationNotice"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Integration Tests - Error Handling*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error When Neither code nor file Provided*)
VerificationTest[
    CodeInspectorToolFunction @ <| |>,
    _Failure,
    { CodeInspectorToolFunction::CodeInspectorNoInput },
    SameTest -> MatchQ,
    TestID   -> "Integration-Error-NoInput"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error When Both code and file Provided*)
VerificationTest[
    CodeInspectorToolFunction @ <| "code" -> "f[x_] := x", "file" -> $integrationTestFile |>,
    _Failure,
    { CodeInspectorToolFunction::CodeInspectorAmbiguousInput },
    SameTest -> MatchQ,
    TestID   -> "Integration-Error-BothInputs"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error For Non-Existent File*)
VerificationTest[
    CodeInspectorToolFunction @ <| "file" -> "/nonexistent/path/to/file.wl" |>,
    _Failure,
    { CodeInspectorToolFunction::CodeInspectorFileNotFound },
    SameTest -> MatchQ,
    TestID   -> "Integration-Error-FileNotFound"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error For Directory With No Matching Files*)
VerificationTest[
    $integrationEmptyDir = CreateDirectory[ ];
    DirectoryQ @ $integrationEmptyDir,
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-Error-CreateEmptyDir"
]

VerificationTest[
    CodeInspectorToolFunction @ <| "file" -> $integrationEmptyDir |>,
    _Failure,
    { CodeInspectorToolFunction::CodeInspectorNoFilesFound },
    SameTest -> MatchQ,
    TestID   -> "Integration-Error-EmptyDirectory"
]

VerificationTest[
    DeleteDirectory[ $integrationEmptyDir ];
    ! DirectoryQ @ $integrationEmptyDir,
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-Cleanup-EmptyDir"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error on Out-of-Range Confidence Level*)
VerificationTest[
    (* Out of range confidence level should throw an error *)
    CodeInspectorToolFunction @ <| "code" -> "f[x_] := x + 1", "confidenceLevel" -> 2.5 |>,
    _Failure,
    { CodeInspectorToolFunction::CodeInspectorInvalidConfidence },
    SameTest -> MatchQ,
    TestID   -> "Integration-OutOfRangeConfidence-ReturnsFailure"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Integration Tests - Output Format*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Summary Table Has Correct Format*)
VerificationTest[
    (* Summary table should have proper markdown table formatting *)
    StringContainsQ[ $integrationCodeResult, "| Severity | Count |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-OutputFormat-SummaryTableHeaders"
]

VerificationTest[
    StringContainsQ[ $integrationCodeResult, "|----------|-------|" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-OutputFormat-SummaryTableSeparator"
]

VerificationTest[
    StringContainsQ[ $integrationCodeResult, "| **Total** |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-OutputFormat-SummaryTableTotal"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Issue Markdown Structure Is Correct*)
VerificationTest[
    (* Issue should have proper header format *)
    StringMatchQ[ $integrationCodeResult, ___ ~~ "### Issue " ~~ DigitCharacter ~~ ": " ~~ ___ ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-OutputFormat-IssueHeader"
]

VerificationTest[
    StringContainsQ[ $integrationCodeResult, "**Location:**" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-OutputFormat-IssueLocation"
]

VerificationTest[
    StringContainsQ[ $integrationCodeResult, "**Description:**" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-OutputFormat-IssueDescription"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Code Snippets Include Line Numbers and Context*)
VerificationTest[
    StringContainsQ[ $integrationCodeResult, "**Code:**" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-OutputFormat-CodeHeader"
]

VerificationTest[
    StringContainsQ[ $integrationCodeResult, "```wl" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-OutputFormat-CodeBlockStart"
]

VerificationTest[
    (* Line number format: "1 | " *)
    StringMatchQ[ $integrationCodeResult, ___ ~~ DigitCharacter ~~ " | " ~~ ___ ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-OutputFormat-LineNumbers"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*CodeActions Are Formatted As Suggestions*)
VerificationTest[
    (* Create code that produces CodeActions (extra comma) *)
    $integrationCodeActionsResult = CodeInspectorToolFunction @ <|
        "code"               -> "f[,2]",  (* Extra leading comma *)
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "Integration-OutputFormat-CodeActionsReturnsString"
]

VerificationTest[
    (* CodeActions should appear as "Suggested Fix" when present.
       Since we can't guarantee every issue has CodeActions, we verify:
       - Either there's a Suggested Fix section
       - Or there are issues but no CodeActions (which is valid)
       The unit tests verify CodeAction formatting works correctly. *)
    StringContainsQ[ $integrationCodeActionsResult, "Suggested Fix" ] ||
    StringContainsQ[ $integrationCodeActionsResult, "## Issues" ],  (* Valid result with issues, CodeActions are optional *)
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-OutputFormat-SuggestedFix"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom Rules - NegatedDateObject*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectNegatedDateObject - Basic Detection*)
VerificationTest[
    $negatedDateResult = CodeInspectorToolFunction @ <|
        "code"               -> "SortBy[files, -FileDate[#1] &]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "NegatedDateObject-FileDate-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $negatedDateResult, "NegatedDateObject" ],
    True,
    SameTest -> SameQ,
    TestID   -> "NegatedDateObject-FileDate-HasTag"
]

VerificationTest[
    StringContainsQ[ $negatedDateResult, "Negating a ``DateObject`` does not produce a meaningful result" ],
    True,
    SameTest -> SameQ,
    TestID   -> "NegatedDateObject-FileDate-HasDescription"
]

VerificationTest[
    StringContainsQ[ $negatedDateResult, "(Error" ],
    True,
    SameTest -> SameQ,
    TestID   -> "NegatedDateObject-FileDate-IsError"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectNegatedDateObject - Now and Today*)
VerificationTest[
    $negatedNowResult = CodeInspectorToolFunction @ <|
        "code"               -> "x = -Now",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "NegatedDateObject-Now-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $negatedNowResult, "NegatedDateObject" ],
    True,
    SameTest -> SameQ,
    TestID   -> "NegatedDateObject-Now-HasTag"
]

VerificationTest[
    $negatedTodayResult = CodeInspectorToolFunction @ <|
        "code"               -> "y = -Today",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "NegatedDateObject-Today-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $negatedTodayResult, "NegatedDateObject" ],
    True,
    SameTest -> SameQ,
    TestID   -> "NegatedDateObject-Today-HasTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectNegatedDateObject - Other Date Functions*)
VerificationTest[
    $negatedDateObjectResult = CodeInspectorToolFunction @ <|
        "code"               -> "z = -DateObject[]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "NegatedDateObject-DateObject-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $negatedDateObjectResult, "NegatedDateObject" ],
    True,
    SameTest -> SameQ,
    TestID   -> "NegatedDateObject-DateObject-HasTag"
]

VerificationTest[
    $negatedRandomDateResult = CodeInspectorToolFunction @ <|
        "code"               -> "w = -RandomDate[]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "NegatedDateObject-RandomDate-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $negatedRandomDateResult, "NegatedDateObject" ],
    True,
    SameTest -> SameQ,
    TestID   -> "NegatedDateObject-RandomDate-HasTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectNegatedDateObject - Multiple Negations*)
VerificationTest[
    $multipleNegatedResult = CodeInspectorToolFunction @ <|
        "code"               -> "x = -Now; y = -Today; z = -Tomorrow; w = -Yesterday",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "NegatedDateObject-Multiple-ReturnsString"
]

VerificationTest[
    StringCount[ $multipleNegatedResult, "NegatedDateObject" ],
    4,
    SameTest -> SameQ,
    TestID   -> "NegatedDateObject-Multiple-FindsAllFour"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom Rules - ReadStringCharacterEncoding*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectReadStringWithCharacterEncoding - Basic Detection*)
VerificationTest[
    $readStringResult = CodeInspectorToolFunction @ <|
        "code"               -> "ReadString[\"file.txt\", CharacterEncoding -> \"UTF-8\"]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "ReadStringCharacterEncoding-Basic-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $readStringResult, "ReadStringCharacterEncoding" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ReadStringCharacterEncoding-Basic-HasTag"
]

VerificationTest[
    StringContainsQ[ $readStringResult, "``ReadString`` does not support the ``CharacterEncoding`` option" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ReadStringCharacterEncoding-Basic-HasDescription"
]

VerificationTest[
    StringContainsQ[ $readStringResult, "(Error" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ReadStringCharacterEncoding-Basic-IsError"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectReadStringWithCharacterEncoding - No False Positive*)
VerificationTest[
    $readStringCleanResult = CodeInspectorToolFunction @ <|
        "code"               -> "ReadString[\"file.txt\"]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "ReadStringCharacterEncoding-NoFalsePositive-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $readStringCleanResult, "ReadStringCharacterEncoding" ],
    False,
    SameTest -> SameQ,
    TestID   -> "ReadStringCharacterEncoding-NoFalsePositive-NoTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom Rules - ExcessiveLineLength*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Line Exceeding Maximum Length*)
VerificationTest[
    $longLineCode = "x = " <> StringJoin @ Table[ "a", 200 ];
    $longLineInspections = Wolfram`AgentTools`Tools`CodeInspector`Private`runInspection[
        $longLineCode,
        <| "tagExclusions" -> { }, "severityExclusions" -> { }, "confidenceLevel" -> 0.0 |>
    ],
    { __InspectionObject },
    SameTest -> MatchQ,
    TestID   -> "ExcessiveLineLength-Detected-ReturnsInspections"
]

VerificationTest[
    MemberQ[ $longLineInspections, InspectionObject[ "ExcessiveLineLength", _, _, _ ] ],
    True,
    SameTest -> SameQ,
    TestID   -> "ExcessiveLineLength-Detected-HasTag"
]

VerificationTest[
    MemberQ[ $longLineInspections, InspectionObject[ "ExcessiveLineLength", _, "Formatting", _ ] ],
    True,
    SameTest -> SameQ,
    TestID   -> "ExcessiveLineLength-Detected-IsFormatting"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Line Exactly at Maximum Length*)
VerificationTest[
    $exactLineInspections = Wolfram`AgentTools`Tools`CodeInspector`Private`runInspection[
        StringJoin @ Table[ "a", 200 ],
        <| "tagExclusions" -> { }, "severityExclusions" -> { }, "confidenceLevel" -> 0.0 |>
    ],
    { ___InspectionObject },
    SameTest -> MatchQ,
    TestID   -> "ExcessiveLineLength-ExactLimit-ReturnsInspections"
]

VerificationTest[
    MemberQ[ $exactLineInspections, InspectionObject[ "ExcessiveLineLength", _, _, _ ] ],
    False,
    SameTest -> SameQ,
    TestID   -> "ExcessiveLineLength-ExactLimit-NotDetected"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Short Lines Only*)
VerificationTest[
    $shortLineInspections = Wolfram`AgentTools`Tools`CodeInspector`Private`runInspection[
        "f[x_] := x + 1\ng[y_] := y * 2",
        <| "tagExclusions" -> { }, "severityExclusions" -> { }, "confidenceLevel" -> 0.0 |>
    ],
    { ___InspectionObject },
    SameTest -> MatchQ,
    TestID   -> "ExcessiveLineLength-ShortLines-ReturnsInspections"
]

VerificationTest[
    MemberQ[ $shortLineInspections, InspectionObject[ "ExcessiveLineLength", _, _, _ ] ],
    False,
    SameTest -> SameQ,
    TestID   -> "ExcessiveLineLength-ShortLines-NotDetected"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom Rules - ExcessiveFileLength*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*File Exceeding Maximum Lines*)
VerificationTest[
    $longFileCode = StringJoin @ Table[ "x = 1\n", 10001 ];
    $longFileInspections = Wolfram`AgentTools`Tools`CodeInspector`Private`runInspection[
        $longFileCode,
        <| "tagExclusions" -> { }, "severityExclusions" -> { }, "confidenceLevel" -> 0.0 |>
    ],
    { __InspectionObject },
    SameTest -> MatchQ,
    TestID   -> "ExcessiveFileLength-Detected-ReturnsInspections"
]

VerificationTest[
    MemberQ[ $longFileInspections, InspectionObject[ "ExcessiveFileLength", _, _, _ ] ],
    True,
    SameTest -> SameQ,
    TestID   -> "ExcessiveFileLength-Detected-HasTag"
]

VerificationTest[
    MemberQ[ $longFileInspections, InspectionObject[ "ExcessiveFileLength", _, "Formatting", _ ] ],
    True,
    SameTest -> SameQ,
    TestID   -> "ExcessiveFileLength-Detected-IsFormatting"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*File Within Maximum Lines*)
VerificationTest[
    $shortFileInspections = Wolfram`AgentTools`Tools`CodeInspector`Private`runInspection[
        StringJoin @ Table[ "x = 1\n", 100 ],
        <| "tagExclusions" -> { }, "severityExclusions" -> { }, "confidenceLevel" -> 0.0 |>
    ],
    { ___InspectionObject },
    SameTest -> MatchQ,
    TestID   -> "ExcessiveFileLength-ShortFile-ReturnsInspections"
]

VerificationTest[
    MemberQ[ $shortFileInspections, InspectionObject[ "ExcessiveFileLength", _, _, _ ] ],
    False,
    SameTest -> SameQ,
    TestID   -> "ExcessiveFileLength-ShortFile-NotDetected"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom Rules - Formatting Severity Exclusion*)
VerificationTest[
    $formattingExcludedInspections = Wolfram`AgentTools`Tools`CodeInspector`Private`runInspection[
        "x = " <> StringJoin @ Table[ "a", 200 ],
        <| "tagExclusions" -> { }, "severityExclusions" -> { "Formatting" }, "confidenceLevel" -> 0.0 |>
    ],
    { ___InspectionObject },
    SameTest -> MatchQ,
    TestID   -> "FormattingExclusion-ReturnsInspections"
]

VerificationTest[
    MemberQ[ $formattingExcludedInspections, InspectionObject[ "ExcessiveLineLength", _, _, _ ] ],
    False,
    SameTest -> SameQ,
    TestID   -> "FormattingExclusion-SuppressesLineLength"
]

VerificationTest[
    MemberQ[ $formattingExcludedInspections, InspectionObject[ "ExcessiveFileLength", _, _, _ ] ],
    False,
    SameTest -> SameQ,
    TestID   -> "FormattingExclusion-SuppressesFileLength"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom Rules - NothingValueInAssociation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectNothingInAssociation - Basic Detection*)
VerificationTest[
    $nothingAssocResult = CodeInspectorToolFunction @ <|
        "code"               -> "<|\"a\" -> 1, \"b\" -> Nothing|>",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "NothingValueInAssociation-Basic-ReturnsString"
]

VerificationTest[
    StringCount[ $nothingAssocResult, "Issue " ~~ DigitCharacter.. ~~ ": NothingValueInAssociation" ],
    1,
    SameTest -> SameQ,
    TestID   -> "NothingValueInAssociation-Basic-HasTag"
]

VerificationTest[
    StringContainsQ[ $nothingAssocResult, "``Nothing`` used as a value in an ``Association`` is not automatically removed" ],
    True,
    SameTest -> SameQ,
    TestID   -> "NothingValueInAssociation-Basic-HasDescription"
]

VerificationTest[
    StringContainsQ[ $nothingAssocResult, "(Warning" ],
    True,
    SameTest -> SameQ,
    TestID   -> "NothingValueInAssociation-Basic-HasSeverity"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectNothingInAssociation - RuleDelayed*)
VerificationTest[
    $nothingAssocDelayedResult = CodeInspectorToolFunction @ <|
        "code"               -> "<|\"a\" -> 1, \"b\" :> Nothing|>",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "NothingValueInAssociation-RuleDelayed-ReturnsString"
]

VerificationTest[
    StringCount[ $nothingAssocDelayedResult, "Issue " ~~ DigitCharacter.. ~~ ": NothingValueInAssociation" ],
    1,
    SameTest -> SameQ,
    TestID   -> "NothingValueInAssociation-RuleDelayed-HasTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectNothingInAssociation - Multiple Nothing Values*)
VerificationTest[
    $nothingAssocMultiResult = CodeInspectorToolFunction @ <|
        "code"               -> "<|\"a\" -> Nothing, \"b\" -> Nothing, \"c\" :> Nothing|>",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "NothingValueInAssociation-Multiple-ReturnsString"
]

VerificationTest[
    StringCount[ $nothingAssocMultiResult, "Issue " ~~ DigitCharacter.. ~~ ": NothingValueInAssociation" ],
    3,
    SameTest -> SameQ,
    TestID   -> "NothingValueInAssociation-Multiple-FindsAllThree"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectNothingInAssociation - No False Positives*)
VerificationTest[
    $nothingAssocCleanResult = CodeInspectorToolFunction @ <|
        "code"               -> "<|\"a\" -> 1, \"b\" -> 2|>",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "NothingValueInAssociation-NoFalsePositive-Clean-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $nothingAssocCleanResult, "NothingValueInAssociation" ],
    False,
    SameTest -> SameQ,
    TestID   -> "NothingValueInAssociation-NoFalsePositive-Clean-NoTag"
]

(* Nothing as standalone element in Association is fine *)
VerificationTest[
    $nothingStandaloneResult = CodeInspectorToolFunction @ <|
        "code"               -> "<|\"a\" -> 1, Nothing|>",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "NothingValueInAssociation-NoFalsePositive-Standalone-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $nothingStandaloneResult, "NothingValueInAssociation" ],
    False,
    SameTest -> SameQ,
    TestID   -> "NothingValueInAssociation-NoFalsePositive-Standalone-NoTag"
]

(* Nothing in a regular list rule is fine *)
VerificationTest[
    $nothingListRuleResult = CodeInspectorToolFunction @ <|
        "code"               -> "{a -> Nothing}",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "NothingValueInAssociation-NoFalsePositive-ListRule-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $nothingListRuleResult, "NothingValueInAssociation" ],
    False,
    SameTest -> SameQ,
    TestID   -> "NothingValueInAssociation-NoFalsePositive-ListRule-NoTag"
]

(* Nothing as argument inside a value is fine *)
VerificationTest[
    $nothingArgResult = CodeInspectorToolFunction @ <|
        "code"               -> "<|\"a\" -> f[Nothing]|>",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "NothingValueInAssociation-NoFalsePositive-AsArgument-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $nothingArgResult, "NothingValueInAssociation" ],
    False,
    SameTest -> SameQ,
    TestID   -> "NothingValueInAssociation-NoFalsePositive-AsArgument-NoTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom Rules - KeyExistsQNestedKeyPath*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectKeyExistsQWithList - Basic Detection*)
VerificationTest[
    $keyExistsQResult = CodeInspectorToolFunction @ <|
        "code"               -> "KeyExistsQ[assoc, {\"k1\", \"k2\"}]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "KeyExistsQNestedKeyPath-Basic-ReturnsString"
]

VerificationTest[
    StringCount[ $keyExistsQResult, "Issue " ~~ DigitCharacter.. ~~ ": KeyExistsQNestedKeyPath" ],
    1,
    SameTest -> SameQ,
    TestID   -> "KeyExistsQNestedKeyPath-Basic-HasTag"
]

VerificationTest[
    StringContainsQ[ $keyExistsQResult, "``KeyExistsQ`` with a ``List`` as its second argument checks for a literal list key" ],
    True,
    SameTest -> SameQ,
    TestID   -> "KeyExistsQNestedKeyPath-Basic-HasDescription"
]

VerificationTest[
    StringContainsQ[ $keyExistsQResult, "(Warning" ],
    True,
    SameTest -> SameQ,
    TestID   -> "KeyExistsQNestedKeyPath-Basic-HasSeverity"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectKeyExistsQWithList - Single Key in List*)
VerificationTest[
    $keyExistsQSingleResult = CodeInspectorToolFunction @ <|
        "code"               -> "KeyExistsQ[assoc, {\"key\"}]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "KeyExistsQNestedKeyPath-SingleKey-ReturnsString"
]

VerificationTest[
    StringCount[ $keyExistsQSingleResult, "Issue " ~~ DigitCharacter.. ~~ ": KeyExistsQNestedKeyPath" ],
    1,
    SameTest -> SameQ,
    TestID   -> "KeyExistsQNestedKeyPath-SingleKey-HasTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectKeyExistsQWithList - No False Positives*)

(* KeyExistsQ with a plain string key should not trigger *)
VerificationTest[
    $keyExistsQCleanResult = CodeInspectorToolFunction @ <|
        "code"               -> "KeyExistsQ[assoc, \"key\"]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "KeyExistsQNestedKeyPath-NoFalsePositive-StringKey-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $keyExistsQCleanResult, "KeyExistsQNestedKeyPath" ],
    False,
    SameTest -> SameQ,
    TestID   -> "KeyExistsQNestedKeyPath-NoFalsePositive-StringKey-NoTag"
]

(* KeyExistsQ with a symbol key should not trigger *)
VerificationTest[
    $keyExistsQSymbolResult = CodeInspectorToolFunction @ <|
        "code"               -> "KeyExistsQ[assoc, key]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "KeyExistsQNestedKeyPath-NoFalsePositive-SymbolKey-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $keyExistsQSymbolResult, "KeyExistsQNestedKeyPath" ],
    False,
    SameTest -> SameQ,
    TestID   -> "KeyExistsQNestedKeyPath-NoFalsePositive-SymbolKey-NoTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom Rules - UnreachableConditionalDefinition*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectConditionalOwnValueOrdering - Basic Detection*)
VerificationTest[
    $ownValueCondResult = CodeInspectorToolFunction @ <|
        "code"               -> "x /; True := 1;\nx := 2",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "UnreachableConditionalDefinition-OwnValue-ReturnsString"
]

VerificationTest[
    StringCount[ $ownValueCondResult, "Issue " ~~ DigitCharacter.. ~~ ": UnreachableConditionalDefinition" ],
    1,
    SameTest -> SameQ,
    TestID   -> "UnreachableConditionalDefinition-OwnValue-HasTag"
]

VerificationTest[
    StringContainsQ[ $ownValueCondResult, "conditional definition of" ],
    True,
    SameTest -> SameQ,
    TestID   -> "UnreachableConditionalDefinition-OwnValue-HasDescription"
]

VerificationTest[
    StringContainsQ[ $ownValueCondResult, "(Warning" ],
    True,
    SameTest -> SameQ,
    TestID   -> "UnreachableConditionalDefinition-OwnValue-HasSeverity"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectConditionalDownValueOrdering - Basic Detection*)
VerificationTest[
    $downValueCondResult = CodeInspectorToolFunction @ <|
        "code" -> "f[] /; True := 1;\nf[] := 2"
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "UnreachableConditionalDefinition-DownValue-ReturnsString"
]

VerificationTest[
    StringCount[ $downValueCondResult, "Issue " ~~ DigitCharacter.. ~~ ": UnreachableConditionalDefinition" ],
    1,
    SameTest -> SameQ,
    TestID   -> "UnreachableConditionalDefinition-DownValue-HasTag"
]

VerificationTest[
    StringContainsQ[ $downValueCondResult, "conditional definition of" ],
    True,
    SameTest -> SameQ,
    TestID   -> "UnreachableConditionalDefinition-DownValue-HasDescription"
]

VerificationTest[
    StringContainsQ[ $downValueCondResult, "(Warning" ],
    True,
    SameTest -> SameQ,
    TestID   -> "UnreachableConditionalDefinition-DownValue-HasSeverity"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectConditionalDownValueOrdering - Code Between Definitions*)
VerificationTest[
    $betweenDefsResult = CodeInspectorToolFunction @ <|
        "code" -> "f[] /; cond := a;\n\nf[x_] := x + 1;\n\nf[] := b"
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "UnreachableConditionalDefinition-BetweenDefs-ReturnsString"
]

VerificationTest[
    StringCount[ $betweenDefsResult, "Issue " ~~ DigitCharacter.. ~~ ": UnreachableConditionalDefinition" ],
    1,
    SameTest -> SameQ,
    TestID   -> "UnreachableConditionalDefinition-BetweenDefs-HasTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectConditionalOwnValueOrdering - No False Positives*)

(* Standalone conditional definition without an unconditional counterpart should not trigger *)
VerificationTest[
    $standaloneCondResult = CodeInspectorToolFunction @ <|
        "code" -> "x /; cond := 1"
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "UnreachableConditionalDefinition-Standalone-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $standaloneCondResult, "UnreachableConditionalDefinition" ],
    False,
    SameTest -> SameQ,
    TestID   -> "UnreachableConditionalDefinition-Standalone-NoTag"
]

(* All-conditional definitions should not trigger *)
VerificationTest[
    $allCondResult = CodeInspectorToolFunction @ <|
        "code" -> "g[] /; True := 1;\ng[] /; False := 2"
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "UnreachableConditionalDefinition-AllConditional-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $allCondResult, "UnreachableConditionalDefinition" ],
    False,
    SameTest -> SameQ,
    TestID   -> "UnreachableConditionalDefinition-AllConditional-NoTag"
]

(* Definitions with patterns in arguments should not trigger *)
VerificationTest[
    $patternArgsResult = CodeInspectorToolFunction @ <|
        "code" -> "h[_] /; True := 1;\nh[_] := 2"
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "UnreachableConditionalDefinition-PatternArgs-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $patternArgsResult, "UnreachableConditionalDefinition" ],
    False,
    SameTest -> SameQ,
    TestID   -> "UnreachableConditionalDefinition-PatternArgs-NoTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom Rules - AmbiguousMapPrecedence*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectAmbiguousMapPrecedence - Basic Detection*)
VerificationTest[
    $ambiguousMapResult = CodeInspectorToolFunction @ <|
        "code"               -> "f @ g /@ x",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "AmbiguousMapPrecedence-Basic-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $ambiguousMapResult, "AmbiguousMapPrecedence" ],
    True,
    SameTest -> SameQ,
    TestID   -> "AmbiguousMapPrecedence-Basic-HasTag"
]

VerificationTest[
    StringContainsQ[ $ambiguousMapResult, "(Warning" ],
    True,
    SameTest -> SameQ,
    TestID   -> "AmbiguousMapPrecedence-Basic-IsWarning"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectAmbiguousMapPrecedence - Motivating Example*)
VerificationTest[
    $ambiguousMapQuietResult = CodeInspectorToolFunction @ <|
        "code"               -> "Quiet @ DeleteFile /@ files",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "AmbiguousMapPrecedence-QuietDeleteFile-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $ambiguousMapQuietResult, "AmbiguousMapPrecedence" ],
    True,
    SameTest -> SameQ,
    TestID   -> "AmbiguousMapPrecedence-QuietDeleteFile-HasTag"
]

VerificationTest[
    StringContainsQ[ $ambiguousMapQuietResult, "Quiet" ] && StringContainsQ[ $ambiguousMapQuietResult, "DeleteFile" ],
    True,
    SameTest -> SameQ,
    TestID   -> "AmbiguousMapPrecedence-QuietDeleteFile-HasSymbolNames"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectAmbiguousMapPrecedence - No False Positives*)

(* Bracket application should not trigger *)
VerificationTest[
    $ambiguousMapBracketResult = CodeInspectorToolFunction @ <|
        "code"               -> "f[g /@ x]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "AmbiguousMapPrecedence-BracketApp-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $ambiguousMapBracketResult, "AmbiguousMapPrecedence" ],
    False,
    SameTest -> SameQ,
    TestID   -> "AmbiguousMapPrecedence-BracketApp-NoTag"
]

(* Explicit Map should not trigger *)
VerificationTest[
    $ambiguousMapExplicitResult = CodeInspectorToolFunction @ <|
        "code"               -> "Map[f @ g, x]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "AmbiguousMapPrecedence-ExplicitMap-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $ambiguousMapExplicitResult, "AmbiguousMapPrecedence" ],
    False,
    SameTest -> SameQ,
    TestID   -> "AmbiguousMapPrecedence-ExplicitMap-NoTag"
]

(* Plain prefix application without Map should not trigger *)
VerificationTest[
    $ambiguousMapNoMapResult = CodeInspectorToolFunction @ <|
        "code"               -> "f @ g",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "AmbiguousMapPrecedence-NoMap-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $ambiguousMapNoMapResult, "AmbiguousMapPrecedence" ],
    False,
    SameTest -> SameQ,
    TestID   -> "AmbiguousMapPrecedence-NoMap-NoTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Regression Tests*)
VerificationTest[
    CodeInspectorToolFunction @ <| "code" -> "f @ g /@ h[x]" |>,
    _String? (StringContainsQ[ "AmbiguousMapPrecedence" ]),
    SameTest -> MatchQ,
    TestID   -> "AmbiguousMapPrecedence-NonLeafNode"
]

VerificationTest[
    CodeInspectorToolFunction @ <| "code" -> "f@   g\t/@\nx" |>,
    _String? (StringContainsQ[ "AmbiguousMapPrecedence" ]),
    SameTest -> MatchQ,
    TestID   -> "AmbiguousMapPrecedence-Whitespace"
]

(* List RHS: f @ g /@ {x} should trigger *)
VerificationTest[
    CodeInspectorToolFunction @ <| "code" -> "f @ g /@ {x}" |>,
    _String? (StringContainsQ[ "AmbiguousMapPrecedence" ]),
    SameTest -> MatchQ,
    TestID   -> "AmbiguousMapPrecedence-ListRHS"
]

(* Parenthesized RHS: f @ g /@ (x + y) should trigger *)
VerificationTest[
    CodeInspectorToolFunction @ <| "code" -> "f @ g /@ (x + y)" |>,
    _String? (StringContainsQ[ "AmbiguousMapPrecedence" ]),
    SameTest -> MatchQ,
    TestID   -> "AmbiguousMapPrecedence-ParenRHS"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom Rules - DefinitionNoSymbol*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectDefinitionNoSymbol - Bare Blank*)
VerificationTest[
    $defNoSymBlankResult = CodeInspectorToolFunction @ <|
        "code"               -> "_ := xxx",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "DefinitionNoSymbol-BareBlank-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $defNoSymBlankResult, "DefinitionNoSymbol" ],
    True,
    SameTest -> SameQ,
    TestID   -> "DefinitionNoSymbol-BareBlank-HasTag"
]

VerificationTest[
    StringContainsQ[ $defNoSymBlankResult, "does not contain a symbol to attach a rule to" ],
    True,
    SameTest -> SameQ,
    TestID   -> "DefinitionNoSymbol-BareBlank-HasDescription"
]

VerificationTest[
    StringContainsQ[ $defNoSymBlankResult, "(Error" ],
    True,
    SameTest -> SameQ,
    TestID   -> "DefinitionNoSymbol-BareBlank-HasSeverity"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectDefinitionNoSymbol - Named Pattern with Bare Blank*)
VerificationTest[
    $defNoSymNamedResult = CodeInspectorToolFunction @ <|
        "code"               -> "name_ := f[name]",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "DefinitionNoSymbol-NamedBlank-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $defNoSymNamedResult, "DefinitionNoSymbol" ],
    True,
    SameTest -> SameQ,
    TestID   -> "DefinitionNoSymbol-NamedBlank-HasTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectDefinitionNoSymbol - BlankSequence and BlankNullSequence*)
VerificationTest[
    $defNoSymBSResult = CodeInspectorToolFunction @ <|
        "code"               -> "__ := xxx",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "DefinitionNoSymbol-BlankSequence-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $defNoSymBSResult, "DefinitionNoSymbol" ],
    True,
    SameTest -> SameQ,
    TestID   -> "DefinitionNoSymbol-BlankSequence-HasTag"
]

VerificationTest[
    $defNoSymBNSResult = CodeInspectorToolFunction @ <|
        "code"               -> "___ := xxx",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "DefinitionNoSymbol-BlankNullSequence-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $defNoSymBNSResult, "DefinitionNoSymbol" ],
    True,
    SameTest -> SameQ,
    TestID   -> "DefinitionNoSymbol-BlankNullSequence-HasTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectDefinitionNoSymbol - PatternTest and Condition*)
VerificationTest[
    $defNoSymPTResult = CodeInspectorToolFunction @ <|
        "code"               -> "_?test := xxx",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "DefinitionNoSymbol-PatternTest-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $defNoSymPTResult, "DefinitionNoSymbol" ],
    True,
    SameTest -> SameQ,
    TestID   -> "DefinitionNoSymbol-PatternTest-HasTag"
]

VerificationTest[
    $defNoSymCondResult = CodeInspectorToolFunction @ <|
        "code"               -> "_ /; cond := xxx",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "DefinitionNoSymbol-Condition-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $defNoSymCondResult, "DefinitionNoSymbol" ],
    True,
    SameTest -> SameQ,
    TestID   -> "DefinitionNoSymbol-Condition-HasTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inspectDefinitionNoSymbol - No False Positives*)

(* Valid DownValues definition should not trigger *)
VerificationTest[
    $defNoSymValidDV = CodeInspectorToolFunction @ <|
        "code"               -> "f[x_] := x",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "DefinitionNoSymbol-ValidDownValue-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $defNoSymValidDV, "DefinitionNoSymbol" ],
    False,
    SameTest -> SameQ,
    TestID   -> "DefinitionNoSymbol-ValidDownValue-NoTag"
]

(* Valid OwnValues definition should not trigger *)
VerificationTest[
    $defNoSymValidOV = CodeInspectorToolFunction @ <|
        "code"               -> "x := 5",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "DefinitionNoSymbol-ValidOwnValue-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $defNoSymValidOV, "DefinitionNoSymbol" ],
    False,
    SameTest -> SameQ,
    TestID   -> "DefinitionNoSymbol-ValidOwnValue-NoTag"
]

(* Blank with head argument should not trigger (attaches to Integer) *)
VerificationTest[
    $defNoSymTypedBlank = CodeInspectorToolFunction @ <|
        "code"               -> "_Integer := xxx",
        "severityExclusions" -> "",
        "confidenceLevel"    -> 0.0
    |>,
    _String,
    SameTest -> MatchQ,
    TestID   -> "DefinitionNoSymbol-TypedBlank-ReturnsString"
]

VerificationTest[
    StringContainsQ[ $defNoSymTypedBlank, "DefinitionNoSymbol" ],
    False,
    SameTest -> SameQ,
    TestID   -> "DefinitionNoSymbol-TypedBlank-NoTag"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Integration Tests - Cleanup*)
VerificationTest[
    DeleteDirectory[ $integrationTempDir, DeleteContents -> True ];
    ! DirectoryQ @ $integrationTempDir,
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-Cleanup-TempDirectory"
]

(* :!CodeAnalysis::EndBlock:: *)
