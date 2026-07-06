(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Tools`PacletTools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
(* cspell: ignore authenticat *)
$authKeywords = { "authenticat", "CloudConnect", "$PublisherID", "sign in", "log in" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*submitPacletTool*)
submitPacletTool // beginDefinition;

submitPacletTool[ KeyValuePattern[ "path" -> path_String ] ] :=
    submitPacletTool @ path;

submitPacletTool[ path_String ] := Enclose[
    Module[ { file, result },
        ensurePacletCICD[];
        file   = ConfirmBy[ validatePacletPath @ path, MatchQ @ File[ _String ], "ValidatePath" ];
        result = Wolfram`PacletCICD`SubmitPaclet @ file;
        ConfirmBy[ formatSubmitResult @ result, StringQ, "FormatResult" ]
    ],
    throwInternalFailure
];

submitPacletTool // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*formatSubmitResult*)
formatSubmitResult // beginDefinition;

formatSubmitResult[ Success[ "ResourceSubmission", data_Association ] ] :=
    Module[ { rows, warnings },
        rows = {
            "| Name | " <> ToString @ data[ "Name" ] <> " |",
            "| Version | " <> ToString @ data[ "Version" ] <> " |",
            "| Status | " <> ToString @ data[ "Message" ] <> " |"
        };
        If[ KeyExistsQ[ data, "UUID" ],
            AppendTo[ rows, "| UUID | " <> ToString @ data[ "UUID" ] <> " |" ]
        ];
        If[ KeyExistsQ[ data, "SubmissionID" ],
            AppendTo[ rows, "| SubmissionID | " <> ToString @ data[ "SubmissionID" ] <> " |" ]
        ];
        warnings = Lookup[ data, "Warnings", {} ];
        StringJoin[
            "# Paclet Submission Successful\n\n",
            "| Field | Value |\n|-------|-------|\n",
            StringRiffle[ rows, "\n" ],
            "\n\nThe paclet has been submitted to the Wolfram Language Paclet Repository for review.",
            If[ MatchQ[ warnings, { __String } ],
                "\n\n## Warnings\n\n" <> StringRiffle[ ("- " <> # & /@ warnings), "\n" ],
                ""
            ]
        ]
    ];

formatSubmitResult[ Failure[ "SubmitPacletFailure", data_Association ] ] :=
    With[ { innerResult = Lookup[ data, "Result", None ] },
        If[ MatchQ[ innerResult, _Failure ],
            formatSubmitFailure @ innerResult,
            formatSubmitFailure[ "SubmitPacletFailure", data ]
        ]
    ];

formatSubmitResult[ Failure[ tag_, data_Association ] ] :=
    formatSubmitFailure[ tag, data ];

formatSubmitResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatSubmitFailure*)
formatSubmitFailure // beginDefinition;

formatSubmitFailure[ Failure[ tag_, data_Association ] ] :=
    formatSubmitFailure[ tag, data ];

formatSubmitFailure[ tag_, data_Association ] :=
    If[ authenticationFailureQ[ tag, data ],
        StringJoin[
            "# Paclet Submission Failed\n\n",
            "Error: Authentication required.\n\n",
            "To submit paclets, you need to configure authentication:\n",
            "- Set `$PublisherID` to your publisher identifier\n",
            "- Or connect to the Wolfram Cloud via `CloudConnect[]`"
        ],
        StringJoin[
            "# Paclet Submission Failed\n\n",
            "Error: ", extractFailureMessage[ tag, data ]
        ]
    ];

formatSubmitFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*authenticationFailureQ*)
authenticationFailureQ // beginDefinition;

authenticationFailureQ[ tag_, data_Association ] :=
    Module[ { msg },
        msg = StringJoin[
            ToString @ Lookup[ data, "MessageTemplate", "" ],
            ToString @ Lookup[ data, "Message", "" ]
        ];
        StringContainsQ[ msg, $authKeywords, IgnoreCase -> True ]
    ];

authenticationFailureQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
