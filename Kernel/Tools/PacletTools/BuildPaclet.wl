(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Tools`PacletTools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*buildPacletTool*)
buildPacletTool // beginDefinition;

buildPacletTool[ KeyValuePattern @ { "path" -> path_String, "check" -> check_ } ] :=
    buildPacletTool[ path, check ];

buildPacletTool[ KeyValuePattern[ "path" -> path_String ] ] :=
    buildPacletTool[ path, False ];

buildPacletTool[ path_String ] :=
    buildPacletTool[ path, False ];

buildPacletTool[ path_String, check_ ] := Enclose[
    Module[ { file, checkValue, result },
        ensurePacletCICD[];
        file       = ConfirmBy[ validatePacletPath @ path, MatchQ @ File[ _String ], "ValidatePath" ];
        checkValue = Replace[ check, Except[ True | False ] -> False ];
        (* The formatted result describes the failure, so the message would only add noise to the output *)
        result     = Quiet[
            Wolfram`PacletCICD`BuildPaclet[ file, "Check" -> checkValue ],
            Wolfram`PacletCICD`BuildPaclet::invfile
        ];
        ConfirmBy[ formatBuildResult @ result, StringQ, "FormatResult" ]
    ],
    throwInternalFailure
];

buildPacletTool // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*formatBuildResult*)
formatBuildResult // beginDefinition;

formatBuildResult[ Success[ "PacletBuild", data_Association ] ] :=
    Module[ { archive, name, version },
        archive = data[ "PacletArchive" ];
        name    = extractPacletName @ data;
        version = extractPacletVersion @ data;
        StringJoin[
            "# Paclet Build Successful\n\n",
            "| Field | Value |\n|-------|-------|\n",
            "| Paclet | ", name, " |\n",
            "| Version | ", version, " |\n",
            "| Archive | ", ToString @ archive, " |"
        ]
    ];

formatBuildResult[ Failure[ "CheckPaclet::errors", data_Association ] ] :=
    Module[ { checkResult },
        checkResult = data[ "CheckResult" ];
        StringJoin[
            "# Paclet Build Aborted\n\n",
            "The pre-build check found errors that must be fixed before building:\n\n",
            formatCheckIssues @ checkResult
        ]
    ];

formatBuildResult[ Failure[ tag_, data_Association ] ] :=
    StringJoin[
        "# Paclet Build Failed\n\n",
        "Error: Failed to build paclet.\n\n",
        "Details: ", extractFailureMessage[ tag, data ]
    ];

formatBuildResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractPacletName*)
extractPacletName // beginDefinition;

extractPacletName[ data_Association ] :=
    Module[ { archive, fileName, parts },
        archive = data[ "PacletArchive" ];
        If[ StringQ @ archive,
            fileName = FileNameTake @ archive;
            (* Archive names follow pattern: Publisher__Name-Version.paclet *)
            parts = StringSplit[ StringReplace[ fileName, ".paclet" -> "" ], "-", 2 ];
            If[ Length @ parts >= 1,
                StringReplace[ First @ parts, "__" -> "/" ],
                "Unknown"
            ],
            "Unknown"
        ]
    ];

extractPacletName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractPacletVersion*)
extractPacletVersion // beginDefinition;

extractPacletVersion[ data_Association ] :=
    Module[ { archive, fileName, parts },
        archive = data[ "PacletArchive" ];
        If[ StringQ @ archive,
            fileName = FileNameTake @ archive;
            parts = StringSplit[ StringReplace[ fileName, ".paclet" -> "" ], "-", 2 ];
            If[ Length @ parts >= 2,
                parts[[ 2 ]],
                "Unknown"
            ],
            "Unknown"
        ]
    ];

extractPacletVersion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatCheckIssues*)
formatCheckIssues // beginDefinition;

formatCheckIssues[ dataset_Dataset ] :=
    formatCheckIssues @ Normal @ dataset;

formatCheckIssues[ json_String ] :=
    formatCheckIssues @ checkHintsFromJSON @ json;

formatCheckIssues[ { } ] :=
    "No issues found.";

formatCheckIssues[ rows: { __Association } ] :=
    StringRiffle[
        Flatten @ {
            formatCheckSummary @ rows,
            formatCheckSections @ rows
        },
        "\n\n"
    ];

formatCheckIssues // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractFailureMessage*)
extractFailureMessage // beginDefinition;

(* PacletCICD's message for a path without a definition notebook shows Missing["NotFound"] instead of the path *)
extractFailureMessage[ tag_String, data_Association ] /; StringEndsQ[ tag, "::invfile" ] :=
    $noDefinitionNotebookMessage;

extractFailureMessage[ tag_, data_Association ] :=
    Module[ { template, params },
        template = Lookup[ data, "MessageTemplate", Lookup[ data, "Message", tag ] ];
        params   = Lookup[ data, "MessageParameters", { } ];
        (* StringForm gives plain text for every parameter, while ToString @ Failure[ ... ][ "Message" ] leaves
           boxes for some (e.g. File[ ... ]) and ignores a "Message" key *)
        If[ StringQ @ template && MatchQ[ params, { __ } ],
            ToString @ StringForm[ template, Sequence @@ params ],
            ToString @ template
        ]
    ];

extractFailureMessage // endDefinition;

$noDefinitionNotebookMessage = "\
No paclet definition notebook was found at the given path. \
Provide the path to the paclet definition notebook (usually ResourceDefinition.nb in the paclet root directory) \
or to the directory that contains it.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
