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
    Needs[ "Wolfram`AgentTools`Tools`PacletTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadPacletToolsContext"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Registration*)
VerificationTest[
    $checkPacletTool = $DefaultMCPTools[ "CheckPaclet" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "GetCheckPacletTool"
]

VerificationTest[
    $checkPacletTool[ "Name" ],
    "CheckPaclet",
    SameTest -> SameQ,
    TestID   -> "CheckPacletToolName"
]

VerificationTest[
    StringQ @ $checkPacletTool[ "Description" ],
    True,
    SameTest -> SameQ,
    TestID   -> "CheckPacletToolDescription"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*validatePacletPath*)
VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`validatePacletPath @ DirectoryName[ $TestFileName, 2 ],
    File[ _String ],
    SameTest -> MatchQ,
    TestID   -> "ValidatePacletPath-ExistingDirectory"
]

VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`validatePacletPath @ $TestFileName,
    File[ _String ],
    SameTest -> MatchQ,
    TestID   -> "ValidatePacletPath-ExistingFile"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Tools`PacletTools`Private`validatePacletPath[ "/nonexistent/path/to/paclet" ],
    _Failure,
    { AgentTools::PacletToolsInvalidPath },
    SameTest -> MatchQ,
    TestID   -> "ValidatePacletPath-MissingPath"
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
    TestID   -> "FormatCheckResult-EmptyDataset"
]

VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ { },
    _String? (StringContainsQ[ "No issues found" ]),
    SameTest -> MatchQ,
    TestID   -> "FormatCheckResult-EmptyList"
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
    TestID   -> "FormatCheckResult-MixedSeverity-IsString"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "# Paclet Check Results" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-HasHeader"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "## Summary" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-HasSummary"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "| Error | 2 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-ErrorCount"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "| Warning | 1 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-WarningCount"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "| Suggestion | 3 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-SuggestionCount"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "## Errors" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-HasErrorsSection"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "## Warnings" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-HasWarningsSection"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "## Suggestions" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-HasSuggestionsSection"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "**MissingPublisherID**: No publisher ID specified" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-ErrorItem"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "**VersionUnchanged**: Version has not changed" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-WarningItem"
]

VerificationTest[
    StringContainsQ[ $mixedResult, "**MissingTests**: No test files found" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-SuggestionItem"
]

(* Verify CellID is not in the output *)
VerificationTest[
    StringFreeQ[ $mixedResult, "CellID" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-MixedSeverity-NoCellID"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Dataset Input*)
VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ Dataset @ $mixedRows,
    $mixedResult,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-DatasetMatchesList"
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
    TestID   -> "FormatCheckResult-SingleLevelOnly"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*JSON Input*)
(* Without a front end, CheckPaclet gives the hints as a UTF-8 encoded JSON string made with ExportString *)
VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ ExportString[ <| "Hints" -> $mixedRows |>, "JSON" ],
    $mixedResult,
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-JSONMatchesList"
]

VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ ExportString[ <| "Hints" -> { } |>, "JSON" ],
    _String? (StringContainsQ[ "No issues found" ]),
    SameTest -> MatchQ,
    TestID   -> "FormatCheckResult-EmptyJSON"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop @ Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult[ "{\"NotHints\":1}" ],
    Failure[ "AgentTools::Internal", _ ],
    { General::AgentToolsInternal },
    SameTest -> MatchQ,
    TestID   -> "FormatCheckResult-JSONWithoutHints"
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
    TestID   -> "FormatCheckResult-PrivateUseCharacters"
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
    TestID   -> "FormatCheckResult-NoDefinitionNotebook"
]

VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatCheckResult @ Failure[
        "CheckPaclet::other",
        <| "MessageTemplate" -> "Could not check `1`.", "MessageParameters" -> { File[ "/some/paclet" ] } |>
    ],
    "# Paclet Check Failed\n\nError: Could not check File[/some/paclet].",
    SameTest -> SameQ,
    TestID   -> "FormatCheckResult-GenericFailure"
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
    TestID   -> "FormatBuildResult-Success-IsString"
]

VerificationTest[
    StringContainsQ[ $buildSuccessResult, "# Paclet Build Successful" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-Success-HasHeader"
]

VerificationTest[
    StringContainsQ[ $buildSuccessResult, "| Paclet | DevPublisher/MyPaclet |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-Success-HasPacletName"
]

VerificationTest[
    StringContainsQ[ $buildSuccessResult, "| Version | 1.0.0 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-Success-HasVersion"
]

VerificationTest[
    StringContainsQ[ $buildSuccessResult, "DevPublisher__MyPaclet-1.0.0.paclet" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-Success-HasArchivePath"
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
    TestID   -> "FormatBuildResult-CheckAborted-IsString"
]

VerificationTest[
    StringContainsQ[ $buildAbortedResult, "# Paclet Build Aborted" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAborted-HasHeader"
]

VerificationTest[
    StringContainsQ[ $buildAbortedResult, "pre-build check found errors" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAborted-HasExplanation"
]

VerificationTest[
    StringContainsQ[ $buildAbortedResult, "## Summary" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAborted-HasSummary"
]

VerificationTest[
    StringContainsQ[ $buildAbortedResult, "| Error | 2 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAborted-ErrorCount"
]

VerificationTest[
    StringContainsQ[ $buildAbortedResult, "## Errors" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAborted-HasErrorsSection"
]

VerificationTest[
    StringContainsQ[ $buildAbortedResult, "**MissingPublisherID**: No publisher ID specified" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAborted-HasErrorItem"
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
    TestID   -> "FormatBuildResult-CheckAbortedDataset-IsString"
]

VerificationTest[
    StringContainsQ[ $buildAbortedDatasetResult, "# Paclet Build Aborted" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-CheckAbortedDataset-HasHeader"
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
    TestID   -> "FormatBuildResult-CheckAbortedJSON"
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
    TestID   -> "FormatBuildResult-GenericFailure-IsString"
]

VerificationTest[
    StringContainsQ[ $buildFailedResult, "# Paclet Build Failed" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-GenericFailure-HasHeader"
]

VerificationTest[
    StringContainsQ[ $buildFailedResult, "Something went wrong during build" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatBuildResult-GenericFailure-HasMessage"
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
    TestID   -> "FormatBuildResult-MessageParameters"
]

VerificationTest[
    Wolfram`AgentTools`Tools`PacletTools`Private`formatBuildResult @
        Failure[ "BuildPaclet::invfile", <|
            "MessageTemplate"   -> "`1` is not a valid definition notebook file or directory.",
            "MessageParameters" -> { Missing[ "NotFound" ] }
        |> ],
    _String? (StringContainsQ[ "Details: No paclet definition notebook was found" ]),
    SameTest -> MatchQ,
    TestID   -> "FormatBuildResult-NoDefinitionNotebook"
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
    TestID   -> "FormatSubmitResult-Success-IsString"
]

VerificationTest[
    StringContainsQ[ $submitSuccessResult, "# Paclet Submission Successful" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-Success-HasHeader"
]

VerificationTest[
    StringContainsQ[ $submitSuccessResult, "| Name | DevPublisher/MyPaclet |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-Success-HasName"
]

VerificationTest[
    StringContainsQ[ $submitSuccessResult, "| Version | 1.0.0 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-Success-HasVersion"
]

VerificationTest[
    StringContainsQ[ $submitSuccessResult, "| Status | Your paclet resource is being published |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-Success-HasStatus"
]

VerificationTest[
    StringContainsQ[ $submitSuccessResult, "submitted to the Wolfram Language Paclet Repository" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-Success-HasConfirmation"
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
    TestID   -> "FormatSubmitResult-SuccessExtras-IsString"
]

VerificationTest[
    StringContainsQ[ $submitSuccessExtras, "| UUID | abc-123-def |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-SuccessExtras-HasUUID"
]

VerificationTest[
    StringContainsQ[ $submitSuccessExtras, "| SubmissionID | sub-456 |" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-SuccessExtras-HasSubmissionID"
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
    TestID   -> "FormatSubmitResult-NestedAuthFailure-IsString"
]

VerificationTest[
    StringContainsQ[ $submitAuthResult, "# Paclet Submission Failed" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-NestedAuthFailure-HasHeader"
]

VerificationTest[
    StringContainsQ[ $submitAuthResult, "Authentication required" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-NestedAuthFailure-HasAuthMessage"
]

VerificationTest[
    StringContainsQ[ $submitAuthResult, "$PublisherID" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-NestedAuthFailure-HasPublisherIDGuidance"
]

VerificationTest[
    StringContainsQ[ $submitAuthResult, "CloudConnect[]" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-NestedAuthFailure-HasCloudConnectGuidance"
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
    TestID   -> "FormatSubmitResult-GenericNestedFailure-IsString"
]

VerificationTest[
    StringContainsQ[ $submitGenericResult, "# Paclet Submission Failed" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-GenericNestedFailure-HasHeader"
]

VerificationTest[
    StringContainsQ[ $submitGenericResult, "The server rejected the submission" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSubmitResult-GenericNestedFailure-HasMessage"
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
    TestID   -> "CheckPacletTool-NoDefinitionNotebook"
]

VerificationTest[
    $DefaultMCPTools[ "BuildPaclet" ][ <| "path" -> $noDefNBPacletDirectory |> ],
    _String? (StringStartsQ[ #, "# Paclet Build Failed" ] && StringContainsQ[ #, "No paclet definition notebook was found" ] &),
    SameTest -> MatchQ,
    TestID   -> "BuildPacletTool-NoDefinitionNotebook"
]

(* :!CodeAnalysis::EndBlock:: *)
