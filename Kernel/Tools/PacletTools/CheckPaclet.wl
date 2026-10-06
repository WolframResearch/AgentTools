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
$checkLevels = { "Error", "Warning", "Suggestion" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*checkPacletTool*)
checkPacletTool // beginDefinition;

checkPacletTool[ KeyValuePattern[ "path" -> path_String ] ] :=
    checkPacletTool @ path;

checkPacletTool[ path_String ] := Enclose[
    Module[ { file, result },
        ensurePacletCICD[];
        file   = ConfirmBy[ validatePacletPath @ path, MatchQ @ File[ _String ], "ValidatePath" ];
        (* The formatted result describes the failure, so the message would only add noise to the output *)
        result = Quiet[
            Wolfram`PacletCICD`CheckPaclet[ file, "FailureCondition" -> None ],
            Wolfram`PacletCICD`CheckPaclet::invfile
        ];
        ConfirmBy[ formatCheckResult @ result, StringQ, "FormatResult" ]
    ],
    throwInternalFailure
];

checkPacletTool // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*formatCheckResult*)
formatCheckResult // beginDefinition;

formatCheckResult[ dataset_Dataset ] :=
    formatCheckResult @ Normal @ dataset;

(* Without a front end (e.g. in scripts and MCP servers), CheckPaclet gives the hints as a JSON string *)
formatCheckResult[ json_String ] :=
    formatCheckResult @ checkHintsFromJSON @ json;

formatCheckResult[ { } ] :=
    "# Paclet Check Results\n\nNo issues found. The paclet is ready to build.";

formatCheckResult[ rows: { __Association } ] :=
    StringRiffle[
        Flatten @ {
            "# Paclet Check Results",
            formatCheckSummary @ rows,
            formatCheckSections @ rows
        },
        "\n\n"
    ];

formatCheckResult[ Failure[ tag_, data_Association ] ] :=
    StringJoin[
        "# Paclet Check Failed\n\n",
        "Error: ", extractFailureMessage[ tag, data ]
    ];

formatCheckResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkHintsFromJSON*)
checkHintsFromJSON // beginDefinition;

(* The JSON is UTF-8 encoded, so it's decoded with ImportString rather than read with ReadRawJSONString *)
checkHintsFromJSON[ json_String ] := Enclose[
    Module[ { data },
        data = ConfirmBy[ ImportString[ json, "RawJSON" ], AssociationQ, "Import" ];
        ConfirmMatch[ Lookup[ data, "Hints" ], { ___Association }, "Hints" ]
    ],
    throwInternalFailure
];

checkHintsFromJSON // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatCheckSummary*)
formatCheckSummary // beginDefinition;

formatCheckSummary[ rows_List ] :=
    Module[ { counts, tableRows },
        counts = AssociationMap[
            Count[ rows, KeyValuePattern[ "Level" -> # ] ] &,
            $checkLevels
        ];
        tableRows = Select[ counts, # > 0 & ];
        StringJoin[
            "## Summary\n\n| Level | Count |\n|-------|-------|",
            StringJoin @ KeyValueMap[
                "\n| " <> #1 <> " | " <> ToString[ #2 ] <> " |" &,
                tableRows
            ]
        ]
    ];

formatCheckSummary // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatCheckSections*)
formatCheckSections // beginDefinition;

formatCheckSections[ rows_List ] :=
    formatCheckSection[ rows, # ] & /@ $checkLevels;

formatCheckSections // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatCheckSection*)
formatCheckSection // beginDefinition;

formatCheckSection[ rows_List, level_String ] :=
    Module[ { matching, items },
        matching = Select[ rows, #[ "Level" ] === level & ];
        If[ matching === { },
            Nothing,
            (* Hint messages can contain private-use characters (e.g. \[Rule]) that only display correctly in notebooks *)
            items = MapIndexed[
                ToString @ First[ #2 ] <> ". **" <> #1[ "Tag" ] <> "**: " <> convertPUACharacters @ #1[ "Message" ] &,
                matching
            ];
            StringJoin[ "## ", level, "s\n\n", StringRiffle[ items, "\n" ] ]
        ]
    ];

formatCheckSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
