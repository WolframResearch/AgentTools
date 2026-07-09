(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Tools`WolframAlpha`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];
Needs[ "Wolfram`AgentTools`Tools`"  ];

Needs[ "Wolfram`Chatbook`" -> "cb`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompts*)
(* TODO: multiple queries aren't supported until the next Chatbook paclet update *)
(* $wolframAlphaToolDescription = "\
Use natural language queries with Wolfram|Alpha to get up-to-date computational results about entities in \
chemistry, physics, geography, history, art, astronomy, and more.
Always use the Wolfram context tool before using this tool to make sure you have the most up-to-date information.
IMPORTANT: If you need the results of multiple queries, it's important that you combine them into a single tool call \
whenever possible to save on token usage and time.";

$wolframAlphaToolQueryHelp = "\
The query (or queries) to send to Wolfram|Alpha. Separate multiple queries with tab characters (\\t)."; *)

$wolframAlphaToolDescription = "\
Use natural language queries with Wolfram|Alpha to get up-to-date computational results about entities in \
chemistry, physics, geography, history, art, astronomy, and more.
Always use the Wolfram context tool before using this tool to make sure you have the most up-to-date information.";

$wolframAlphaToolQueryHelp = "The query to send to Wolfram|Alpha.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Definition*)
(* Add to $defaultMCPTools Association (initialized in Kernel/Tools/Tools.wl) *)
$defaultMCPTools[ "WolframAlpha" ] := LLMTool @ <|
    "Name"        -> "WolframAlpha",
    "DisplayName" -> "Wolfram|Alpha",
    "Description" -> $wolframAlphaToolDescription,
    "Function"    -> wolframAlphaToolEvaluate,
    "Options"     -> { },
    "Parameters"  -> {
        "query" -> <|
            "Interpreter" -> "String",
            "Help"        -> $wolframAlphaToolQueryHelp,
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*wolframAlphaToolEvaluate*)
wolframAlphaToolEvaluate // beginDefinition;

wolframAlphaToolEvaluate[ as_ ] := Quiet[
    If[ TrueQ @ $clientSupportsUI && TrueQ @ $deployCloudNotebooks,
        wolframAlphaToolEvaluateUI @ as,
        wolframAlphaToolEvaluate[ as, cb`$DefaultTools[ "WolframAlpha" ][ as ] ]
    ],
    { WolframAlpha::kbserr }
];

wolframAlphaToolEvaluate[ as_, result_String ] := extractWolframAlphaImages @ result;
wolframAlphaToolEvaluate[ as_, KeyValuePattern[ "String" -> result_String ] ] := extractWolframAlphaImages @ result;
wolframAlphaToolEvaluate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*wolframAlphaToolEvaluateUI*)
wolframAlphaToolEvaluateUI // beginDefinition;

wolframAlphaToolEvaluateUI[ as_ ] :=
    Module[ { result, uiResult },

        result = Block[
            {
                (* Call Chatbook with $ChatNotebookEvaluation = True to get rich result *)
                cb`$ChatNotebookEvaluation = True,
                (* Set $CloudEvaluation to True since we're creating a notebook for the cloud *)
                $CloudEvaluation = True
            },
            cb`$DefaultTools[ "WolframAlpha" ][ as ]
        ];

        (* Try to create UI-enhanced result with cloud notebook *)
        uiResult = Quiet @ makeUIResult[ as, result ];

        (* If UI result succeeded, return it; otherwise fall back to standard behavior *)
        If[ MatchQ[ uiResult, KeyValuePattern[ "Content" -> { __Association } ] ],
            uiResult,
            wolframAlphaToolEvaluate[ as, result ]
        ]
    ];

wolframAlphaToolEvaluateUI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeUIResult*)
makeUIResult // beginDefinition;

makeUIResult[ as_, KeyValuePattern[ { "Result" -> waResult_, "String" -> stringResult_String } ] ] := Enclose[
    Catch @ Module[ { textContent, formatted, nb, query, deployed },

        textContent = ConfirmMatch[
            toContentList @ extractWolframAlphaImages @ stringResult,
            { __Association },
            "TextContent"
        ];

        formatted = Block[
            {
                (* Format WA pods into notebook cells with FoldPods=True for compact display *)
                cb`$DefaultToolOptions = <| cb`$DefaultToolOptions, "WolframAlpha" -> <| "FoldPods" -> True |> |>,
                (* Set $CloudEvaluation to True since we're creating a notebook for the cloud *)
                $CloudEvaluation = True
            },
            Confirm[ cb`FormatWolframAlphaPods @ waResult, "Formatted" ]
        ];

        nb = Notebook @ {
            Cell[
                BoxData @ ToBoxes @ formatted,
                "Output",
                CellMargins     -> { { 20, 20 }, { 20, 20 } },
                FontColor       -> Black,
                ShowCellBracket -> False
            ]
        };

        query = ConfirmBy[ as[ "query" ], StringQ, "Query" ];

        deployed = ConfirmMatch[
            deployCloudNotebookForMCPApp[ nb, query ],
            _String|$Failed,
            "Deployed"
        ];

        (* Build the UI result: notebookUrl in _meta (the UI-only channel), plus the URL inside an
           <internal>...<url>...</url></internal> marker in the content as a fallback for hosts that
           drop _meta (ext-apps#696). See makeNotebookUIResult. Returns $Failed if deployment failed. *)
        makeNotebookUIResult[ textContent, deployed ]
    ],
    throwInternalFailure
];

makeUIResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toContentList*)
toContentList // beginDefinition;
toContentList[ KeyValuePattern[ "Content" -> items_List ] ] := items;
toContentList[ items_List ] := items;
toContentList[ str_String ] := { <| "type" -> "text", "text" -> str |> };
toContentList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
