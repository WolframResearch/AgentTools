(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/PacletTools.wlt:7,1-12,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/PacletTools.wlt:14,1-19,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`Tools`PacletTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadPacletToolsContext@@Tests/PacletTools.wlt:21,1-26,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Registration*)
VerificationTest[
    $checkPacletTool = $DefaultMCPTools[ "CheckPaclet" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "GetCheckPacletTool@@Tests/PacletTools.wlt:31,1-36,2"
]

VerificationTest[
    $checkPacletTool[ "Name" ],
    "CheckPaclet",
    SameTest -> SameQ,
    TestID   -> "CheckPacletToolName@@Tests/PacletTools.wlt:38,1-43,2"
]

VerificationTest[
    StringQ @ $checkPacletTool[ "Description" ],
    True,
    SameTest -> SameQ,
    TestID   -> "CheckPacletToolDescription@@Tests/PacletTools.wlt:45,1-50,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*validatePacletPath*)
VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`validatePacletPath @ DirectoryName[ $TestFileName, 2 ],
    File[ _String ],
    SameTest -> MatchQ,
    TestID   -> "ValidatePacletPath-ExistingDirectory@@Tests/PacletTools.wlt:55,1-60,2"
]

VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`validatePacletPath @ $TestFileName,
    File[ _String ],
    SameTest -> MatchQ,
    TestID   -> "ValidatePacletPath-ExistingFile@@Tests/PacletTools.wlt:62,1-67,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Tools`PacletTools`Private`validatePacletPath[ "/nonexistent/path/to/paclet" ],
    _Failure,
    { AgentTools::PacletToolsInvalidPath },
    SameTest -> MatchQ,
    TestID   -> "ValidatePacletPath-MissingPath@@Tests/PacletTools.wlt:69,1-75,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*formatCheckResult*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Empty Dataset*)
VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ Dataset @ { },
    _String? (StringContainsQ[ "No issues found" ]),
    SameTest -> MatchQ,
    TestID   -> "FormatCheckResult-EmptyDataset@@Tests/PacletTools.wlt:84,1-89,2"
]

VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ { },
    _String? (StringContainsQ[ "No issues found" ]),
    SameTest -> MatchQ,
    TestID   -> "FormatCheckResult-EmptyList@@Tests/PacletTools.wlt:91,1-96,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Mixed Severity Dataset*)
VerificationTest[
    $mixedRows = {
        <| "Level" -> "Error",      "Tag" -> "MissingPublisherID", "Message" -> "No publisher ID specified",       "CellID" -> 1 |>,
        <| "Level" -> "Error",      "Tag" -> "InvalidVersion",     "Message" -> "Version string is invalid",       "CellID" -> 2 |>,
        <| "Level" -> "Warning",    "Tag" -> "VersionUnchanged",   "Message" -> "Version has not changed",         "CellID" -> 3 |>,
        <| "Level" -> "Suggestion", "Tag" -> "MissingTests",       "Message" -> "No test files found",             "CellID" -> 4 |>,
        <| "Level" -> "Suggestion", "Tag" -> "MissingReadme",      "Message" -> "No README file found",            "CellID" -> 5 |>,
        <| "Level" -> "Suggestion", "Tag" -> "MissingDocs",        "Message" -> "No documentation pages found",    "CellID" -> 6 |>
    };
    $mixedResult = Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ $mixedRows;
    StringQ @ $mixedResult,
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-IsString@@Tests/PacletTools.wlt:101,1-115,2"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "# Paclet Check Results" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-HasHeader@@Tests/PacletTools.wlt:117,1-122,2"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "## Summary" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-HasSummary@@Tests/PacletTools.wlt:124,1-129,2"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "| Error | 2 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-ErrorCount@@Tests/PacletTools.wlt:131,1-136,2"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "| Warning | 1 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-WarningCount@@Tests/PacletTools.wlt:138,1-143,2"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "| Suggestion | 3 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-SuggestionCount@@Tests/PacletTools.wlt:145,1-150,2"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "## Errors" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-HasErrorsSection@@Tests/PacletTools.wlt:152,1-157,2"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "## Warnings" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-HasWarningsSection@@Tests/PacletTools.wlt:159,1-164,2"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "## Suggestions" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-HasSuggestionsSection@@Tests/PacletTools.wlt:166,1-171,2"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "**MissingPublisherID**: No publisher ID specified" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-ErrorItem@@Tests/PacletTools.wlt:173,1-178,2"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "**VersionUnchanged**: Version has not changed" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-WarningItem@@Tests/PacletTools.wlt:180,1-185,2"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "**MissingTests**: No test files found" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-SuggestionItem@@Tests/PacletTools.wlt:187,1-192,2"
]

(* Verify CellID is not in the output *)
VerificationTest[
    StringFreeQ[ $mixedResult, "CellID" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-NoCellID@@Tests/PacletTools.wlt:195,1-200,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Dataset Input*)
VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ Dataset @ $mixedRows,
    $mixedResult,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-DatasetMatchesList@@Tests/PacletTools.wlt:205,1-210,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Single Level Only*)
VerificationTest[
    With[
        { result = Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ {
            <| "Level" -> "Warning", "Tag" -> "SomeWarning", "Message" -> "A warning", "CellID" -> 1 |>
        } },
        StringContainsQ[ result, "## Warnings" ] && StringFreeQ[ result, "## Errors" ] && StringFreeQ[ result, "## Suggestions" ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-SingleLevelOnly@@Tests/PacletTools.wlt:215,1-225,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*JSON Input*)
(* Without a front end, CheckPaclet gives the hints as a UTF-8 encoded JSON string made with ExportString *)
VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ ExportString[ <| "Hints" -> $mixedRows |>, "JSON" ],
    $mixedResult,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-JSONMatchesList@@Tests/PacletTools.wlt:231,1-236,2"
]

VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ ExportString[ <| "Hints" -> { } |>, "JSON" ],
    _String? (StringContainsQ[ "No issues found" ]),
    SameTest -> MatchQ,
    TestID   -> "FormatCheckResult-EmptyJSON@@Tests/PacletTools.wlt:238,1-243,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult[ "{\"NotHints\":1}" ],
    Failure[ "AgentTools::Internal", _ ],
    { General::AgentToolsInternal },
    SameTest -> MatchQ,
    TestID   -> "FormatCheckResult-JSONWithoutHints@@Tests/PacletTools.wlt:245,1-251,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Private-Use Characters*)
VerificationTest[
    $privateUseResult = Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ ExportString[
        <| "Hints" -> {
            <|
                "CellID"  -> 1,
                "Level"   -> "Warning",
                "Tag"     -> "InternalContextWarning",
                "Message" -> "Symbols in paclets with \"Loading\" \[Rule] Automatic may have issues"
            |>,
            <| "CellID" -> 2, "Level" -> "Warning", "Tag" -> "Delayed", "Message" -> "Use a \[RuleDelayed] b" |>,
            <| "CellID" -> 3, "Level" -> "Warning", "Tag" -> "Other", "Message" -> "Use \[LeftAssociation]\[RightAssociation] in caf\[EAcute]" |>
        } |>,
        "JSON"
    ];
    {
        StringContainsQ[ $privateUseResult, "**InternalContextWarning**: Symbols in paclets with \"Loading\" -> Automatic" ],
        StringContainsQ[ $privateUseResult, "**Delayed**: Use a :> b" ],
        StringContainsQ[ $privateUseResult, "**Other**: Use <||> in caf\[EAcute]" ],
        StringFreeQ[ $privateUseResult, RegularExpression[ "[\\x{E000}-\\x{F8FF}]" ] ]
    },
    { True, True, True, True },
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-PrivateUseCharacters@@Tests/PacletTools.wlt:256,1-279,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Check Failure*)
VerificationTest[
    $checkNoDefNBResult = Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ Failure[
        "CheckPaclet::invfile",
        <|
            "MessageTemplate"   -> "`1` is not a valid definition notebook file or directory.",
            "MessageParameters" -> { Missing[ "NotFound" ] }
        |>
    ];
    {
        StringStartsQ[ $checkNoDefNBResult, "# Paclet Check Failed" ],
        StringContainsQ[ $checkNoDefNBResult, "No paclet definition notebook was found" ],
        StringFreeQ[ $checkNoDefNBResult, "Missing" ]
    },
    { True, True, True },
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-NoDefinitionNotebook@@Tests/PacletTools.wlt:284,1-300,2"
]

VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ Failure[
        "CheckPaclet::other",
        <| "MessageTemplate" -> "Could not check `1`.", "MessageParameters" -> { File[ "/some/paclet" ] } |>
    ],
    "# Paclet Check Failed\n\nError: Could not check File[/some/paclet].",
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-GenericFailure@@Tests/PacletTools.wlt:302,1-310,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*formatBuildResult*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Build Success*)
VerificationTest[
    $buildSuccessResult = Wolfram`AgentTools`Tools`PacletTools`Private`formatBuildResult @
        Success[ "PacletBuild", <|
            "PacletArchive" -> "C:/Users/dev/MyPaclet/build/DevPublisher__MyPaclet-1.0.0.paclet"
        |> ];
    StringQ @ $buildSuccessResult,
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-Success-IsString@@Tests/PacletTools.wlt:319,1-328,2"
]

VerificationTest[
    StringContainsQ[ $buildSuccessResult, "# Paclet Build Successful" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-Success-HasHeader@@Tests/PacletTools.wlt:330,1-335,2"
]

VerificationTest[
    StringContainsQ[ $buildSuccessResult, "| Paclet | DevPublisher/MyPaclet |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-Success-HasPacletName@@Tests/PacletTools.wlt:337,1-342,2"
]

VerificationTest[
    StringContainsQ[ $buildSuccessResult, "| Version | 1.0.0 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-Success-HasVersion@@Tests/PacletTools.wlt:344,1-349,2"
]

VerificationTest[
    StringContainsQ[ $buildSuccessResult, "DevPublisher__MyPaclet-1.0.0.paclet" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-Success-HasArchivePath@@Tests/PacletTools.wlt:351,1-356,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Build Aborted by Check*)
VerificationTest[
    $buildAbortedResult = Wolfram`AgentTools`Tools`PacletTools`Private`formatBuildResult @
        Failure[ "CheckPaclet::errors", <|
            "CheckResult" -> {
                <| "Level" -> "Error", "Tag" -> "MissingPublisherID", "Message" -> "No publisher ID specified", "CellID" -> 1 |>,
                <| "Level" -> "Error", "Tag" -> "InvalidVersion",     "Message" -> "Version string is invalid",  "CellID" -> 2 |>
            }
        |> ];
    StringQ @ $buildAbortedResult,
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAborted-IsString@@Tests/PacletTools.wlt:361,1-373,2"
]

VerificationTest[
    StringContainsQ[ $buildAbortedResult, "# Paclet Build Aborted" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAborted-HasHeader@@Tests/PacletTools.wlt:375,1-380,2"
]

VerificationTest[
    StringContainsQ[ $buildAbortedResult, "pre-build check found errors" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAborted-HasExplanation@@Tests/PacletTools.wlt:382,1-387,2"
]

VerificationTest[
    StringContainsQ[ $buildAbortedResult, "## Summary" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAborted-HasSummary@@Tests/PacletTools.wlt:389,1-394,2"
]

VerificationTest[
    StringContainsQ[ $buildAbortedResult, "| Error | 2 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAborted-ErrorCount@@Tests/PacletTools.wlt:396,1-401,2"
]

VerificationTest[
    StringContainsQ[ $buildAbortedResult, "## Errors" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAborted-HasErrorsSection@@Tests/PacletTools.wlt:403,1-408,2"
]

VerificationTest[
    StringContainsQ[ $buildAbortedResult, "**MissingPublisherID**: No publisher ID specified" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAborted-HasErrorItem@@Tests/PacletTools.wlt:410,1-415,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Build Aborted by Check - Dataset Input*)
VerificationTest[
    $buildAbortedDatasetResult = Wolfram`AgentTools`Tools`PacletTools`Private`formatBuildResult @
        Failure[ "CheckPaclet::errors", <|
            "CheckResult" -> Dataset @ {
                <| "Level" -> "Error", "Tag" -> "MissingPublisherID", "Message" -> "No publisher ID specified", "CellID" -> 1 |>,
                <| "Level" -> "Error", "Tag" -> "InvalidVersion",     "Message" -> "Version string is invalid",  "CellID" -> 2 |>
            }
        |> ];
    StringQ @ $buildAbortedDatasetResult,
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAbortedDataset-IsString@@Tests/PacletTools.wlt:420,1-432,2"
]

VerificationTest[
    StringContainsQ[ $buildAbortedDatasetResult, "# Paclet Build Aborted" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAbortedDataset-HasHeader@@Tests/PacletTools.wlt:434,1-439,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Build Aborted by Check - JSON Input*)
VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatBuildResult @
        Failure[ "CheckPaclet::errors", <|
            "CheckResult" -> ExportString[
                <| "Hints" -> {
                    <| "CellID" -> 1, "Level" -> "Error", "Tag" -> "MissingPublisherID", "Message" -> "No publisher ID specified" |>,
                    <| "CellID" -> 2, "Level" -> "Error", "Tag" -> "InvalidVersion",     "Message" -> "Version string is invalid"  |>
                } |>,
                "JSON"
            ]
        |> ],
    $buildAbortedResult,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAbortedJSON@@Tests/PacletTools.wlt:444,1-458,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Build Failed - Generic Failure*)
VerificationTest[
    $buildFailedResult = Wolfram`AgentTools`Tools`PacletTools`Private`formatBuildResult @
        Failure[ "BuildPacletFailure", <|
            "MessageTemplate" -> "Something went wrong during build"
        |> ];
    StringQ @ $buildFailedResult,
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-GenericFailure-IsString@@Tests/PacletTools.wlt:463,1-472,2"
]

VerificationTest[
    StringContainsQ[ $buildFailedResult, "# Paclet Build Failed" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-GenericFailure-HasHeader@@Tests/PacletTools.wlt:474,1-479,2"
]

VerificationTest[
    StringContainsQ[ $buildFailedResult, "Something went wrong during build" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-GenericFailure-HasMessage@@Tests/PacletTools.wlt:481,1-486,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Build Failed - Message Parameters*)
VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatBuildResult @
        Failure[ "BuildPaclet::other", <|
            "MessageTemplate"   -> "Could not build `1` (`2`).",
            "MessageParameters" -> { File[ "/some/paclet" ], "reason" }
        |> ],
    _String? (StringContainsQ[ "Details: Could not build File[/some/paclet] (reason)." ]),
    SameTest -> MatchQ,
    TestID   -> "FormatBuildResult-MessageParameters@@Tests/PacletTools.wlt:491,1-500,2"
]

VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatBuildResult @
        Failure[ "BuildPaclet::invfile", <|
            "MessageTemplate"   -> "`1` is not a valid definition notebook file or directory.",
            "MessageParameters" -> { Missing[ "NotFound" ] }
        |> ],
    _String? (StringContainsQ[ "Details: No paclet definition notebook was found" ]),
    SameTest -> MatchQ,
    TestID   -> "FormatBuildResult-NoDefinitionNotebook@@Tests/PacletTools.wlt:502,1-511,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*formatSubmitResult*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Submission Success*)
VerificationTest[
    $submitSuccessResult = Wolfram`AgentTools`Tools`PacletTools`Private`formatSubmitResult @
        Success[ "ResourceSubmission", <|
            "Name"    -> "DevPublisher/MyPaclet",
            "Version" -> "1.0.0",
            "Message" -> "Your paclet resource is being published"
        |> ];
    StringQ @ $submitSuccessResult,
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-Success-IsString@@Tests/PacletTools.wlt:520,1-531,2"
]

VerificationTest[
    StringContainsQ[ $submitSuccessResult, "# Paclet Submission Successful" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-Success-HasHeader@@Tests/PacletTools.wlt:533,1-538,2"
]

VerificationTest[
    StringContainsQ[ $submitSuccessResult, "| Name | DevPublisher/MyPaclet |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-Success-HasName@@Tests/PacletTools.wlt:540,1-545,2"
]

VerificationTest[
    StringContainsQ[ $submitSuccessResult, "| Version | 1.0.0 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-Success-HasVersion@@Tests/PacletTools.wlt:547,1-552,2"
]

VerificationTest[
    StringContainsQ[ $submitSuccessResult, "| Status | Your paclet resource is being published |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-Success-HasStatus@@Tests/PacletTools.wlt:554,1-559,2"
]

VerificationTest[
    StringContainsQ[ $submitSuccessResult, "submitted to the Wolfram Language Paclet Repository" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-Success-HasConfirmation@@Tests/PacletTools.wlt:561,1-566,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Submission Success with Optional Fields*)
VerificationTest[
    $submitSuccessExtras = Wolfram`AgentTools`Tools`PacletTools`Private`formatSubmitResult @
        Success[ "ResourceSubmission", <|
            "Name"         -> "DevPublisher/MyPaclet",
            "Version"      -> "1.0.0",
            "Message"      -> "Your paclet resource is being published",
            "UUID"         -> "abc-123-def",
            "SubmissionID" -> "sub-456"
        |> ];
    StringQ @ $submitSuccessExtras,
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-SuccessExtras-IsString@@Tests/PacletTools.wlt:571,1-584,2"
]

VerificationTest[
    StringContainsQ[ $submitSuccessExtras, "| UUID | abc-123-def |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-SuccessExtras-HasUUID@@Tests/PacletTools.wlt:586,1-591,2"
]

VerificationTest[
    StringContainsQ[ $submitSuccessExtras, "| SubmissionID | sub-456 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-SuccessExtras-HasSubmissionID@@Tests/PacletTools.wlt:593,1-598,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Nested Authentication Failure*)
VerificationTest[
    $submitAuthResult = Wolfram`AgentTools`Tools`PacletTools`Private`formatSubmitResult @
        Failure[ "SubmitPacletFailure", <|
            "Result" -> Failure[ "AuthenticationFailure", <|
                "MessageTemplate" -> "You must authenticate before submitting. Use CloudConnect[] or set $PublisherID."
            |> ]
        |> ];
    StringQ @ $submitAuthResult,
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-NestedAuthFailure-IsString@@Tests/PacletTools.wlt:603,1-614,2"
]

VerificationTest[
    StringContainsQ[ $submitAuthResult, "# Paclet Submission Failed" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-NestedAuthFailure-HasHeader@@Tests/PacletTools.wlt:616,1-621,2"
]

VerificationTest[
    StringContainsQ[ $submitAuthResult, "Authentication required" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-NestedAuthFailure-HasAuthMessage@@Tests/PacletTools.wlt:623,1-628,2"
]

VerificationTest[
    StringContainsQ[ $submitAuthResult, "$PublisherID" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-NestedAuthFailure-HasPublisherIDGuidance@@Tests/PacletTools.wlt:630,1-635,2"
]

VerificationTest[
    StringContainsQ[ $submitAuthResult, "CloudConnect[]" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-NestedAuthFailure-HasCloudConnectGuidance@@Tests/PacletTools.wlt:637,1-642,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Generic Nested Failure*)
VerificationTest[
    $submitGenericResult = Wolfram`AgentTools`Tools`PacletTools`Private`formatSubmitResult @
        Failure[ "SubmitPacletFailure", <|
            "Result" -> Failure[ "ServerError", <|
                "MessageTemplate" -> "The server rejected the submission"
            |> ]
        |> ];
    StringQ @ $submitGenericResult,
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-GenericNestedFailure-IsString@@Tests/PacletTools.wlt:647,1-658,2"
]

VerificationTest[
    StringContainsQ[ $submitGenericResult, "# Paclet Submission Failed" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-GenericNestedFailure-HasHeader@@Tests/PacletTools.wlt:660,1-665,2"
]

VerificationTest[
    StringContainsQ[ $submitGenericResult, "The server rejected the submission" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-GenericNestedFailure-HasMessage@@Tests/PacletTools.wlt:667,1-672,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Calls*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*No Definition Notebook*)
(* A paclet directory without a definition notebook gives a formatted failure without issuing messages *)
VerificationTest[
    $noDefNBPacletDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources", "MockMCPPacletTest" };
    $checkPacletTool[ <| "path" -> $noDefNBPacletDirectory |> ],
    _String? (StringStartsQ[ #, "# Paclet Check Failed" ] && StringContainsQ[ #, "No paclet definition notebook was found" ] &),
    SameTest -> MatchQ,
    TestID   -> "CheckPacletTool-NoDefinitionNotebook@@Tests/PacletTools.wlt:682,1-688,2"
]

VerificationTest[
    $DefaultMCPTools[ "BuildPaclet" ][ <| "path" -> $noDefNBPacletDirectory |> ],
    _String? (StringStartsQ[ #, "# Paclet Build Failed" ] && StringContainsQ[ #, "No paclet definition notebook was found" ] &),
    SameTest -> MatchQ,
    TestID   -> "BuildPacletTool-NoDefinitionNotebook@@Tests/PacletTools.wlt:690,1-695,2"
]

(* :!CodeAnalysis::EndBlock:: *)
