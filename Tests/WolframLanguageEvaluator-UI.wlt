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

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*toContentList*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*String Input*)
VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`toContentList[ "hello" ],
    { <| "type" -> "text", "text" -> "hello" |> },
    SameTest -> MatchQ,
    TestID   -> "toContentList-String"
]

VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`toContentList[ "" ],
    { <| "type" -> "text", "text" -> "" |> },
    SameTest -> MatchQ,
    TestID   -> "toContentList-EmptyString"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*List Input*)
VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`toContentList[ { <| "type" -> "text", "text" -> "a" |> } ],
    { <| "type" -> "text", "text" -> "a" |> },
    SameTest -> MatchQ,
    TestID   -> "toContentList-List"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Association with Content Key*)
VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`toContentList[
        <| "Content" -> { <| "type" -> "text", "text" -> "x" |>, <| "type" -> "image", "data" -> "abc" |> } |>
    ],
    { <| "type" -> "text", "text" -> "x" |>, <| "type" -> "image", "data" -> "abc" |> },
    SameTest -> MatchQ,
    TestID   -> "toContentList-AssociationContent"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*toOutputBoxes*)
VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`toOutputBoxes[ HoldForm[ 1 + 1 ] ],
    _,
    SameTest -> MatchQ,
    TestID   -> "toOutputBoxes-HoldForm"
]

VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`toOutputBoxes[ HoldCompleteForm[ {1, 2, 3} ] ],
    _,
    SameTest -> MatchQ,
    TestID   -> "toOutputBoxes-HoldCompleteForm"
]

VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`toOutputBoxes[ Failure[ "KernelQuit", <| "ExitCode" -> 0 |> ] ],
    _InterpretationBox,
    SameTest -> MatchQ,
    TestID   -> "toOutputBoxes-Failure-Bug478002"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config Constants*)
VerificationTest[
    Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`$outputSizeLimit,
    _Integer?Positive,
    SameTest -> MatchQ,
    TestID   -> "outputSizeLimit-IsPositiveInteger"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*evaluateWolframLanguage Branching*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Without UI Support*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = False },
        $DefaultMCPTools[ "WolframLanguageEvaluator" ][ <| "code" -> "1+1", "timeConstraint" -> 30 |> ]
    ],
    _String | KeyValuePattern[ "Content" -> { __Association } ],
    SameTest -> MatchQ,
    TestID   -> "evaluateWolframLanguage-NoUI"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*With UI Support - Returns Content*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = True },
        $evalUIResult = $DefaultMCPTools[ "WolframLanguageEvaluator" ][ <| "code" -> "1+1", "timeConstraint" -> 30 |> ]
    ],
    _String | KeyValuePattern[ "Content" -> { __Association } ],
    SameTest -> MatchQ,
    TestID   -> "evaluateWolframLanguage-WithUI"
]

VerificationTest[
    If[ AssociationQ @ $evalUIResult && KeyExistsQ[ $evalUIResult, "Content" ],
        Length @ $evalUIResult[ "Content" ] > 0,
        (* Plain string result is also acceptable (fallback path) *)
        StringQ @ $evalUIResult
    ],
    True,
    TestID -> "evaluateWolframLanguage-WithUI-HasContent"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UI Support But Cloud Deployment Disabled - Falls Back*)
VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI    = True,
        Wolfram`AgentTools`Common`$deployCloudNotebooks = False
    },
        $DefaultMCPTools[ "WolframLanguageEvaluator" ][ <| "code" -> "1+1", "timeConstraint" -> 30 |> ]
    ],
    _String | KeyValuePattern[ "Content" -> { __Association } ],
    SameTest -> MatchQ,
    TestID   -> "evaluateWolframLanguage-NoDeploy"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*makeEvaluatorUIResult*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Returns $Failed for Non-Matching Input*)
VerificationTest[
    Quiet @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`makeEvaluatorUIResult[ "1+1", "plain string", 1 ],
    $Failed | _Failure,
    SameTest -> MatchQ,
    TestID   -> "makeEvaluatorUIResult-PlainStringFails"
]

VerificationTest[
    Quiet @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`makeEvaluatorUIResult[ "1+1", $Failed, 1 ],
    $Failed | _Failure,
    SameTest -> MatchQ,
    TestID   -> "makeEvaluatorUIResult-FailedInput"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Returns $Failed When Missing Keys*)
VerificationTest[
    Quiet @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`makeEvaluatorUIResult[
        "1+1",
        <| "String" -> "text only" |>,
        1
    ],
    $Failed | _Failure,
    SameTest -> MatchQ,
    TestID   -> "makeEvaluatorUIResult-MissingResultKey"
]

VerificationTest[
    Quiet @ Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`makeEvaluatorUIResult[
        "1+1",
        <| "Result" -> HoldForm[ 2 ] |>,
        1
    ],
    $Failed | _Failure,
    SameTest -> MatchQ,
    TestID   -> "makeEvaluatorUIResult-MissingStringKey"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cell Labels*)
(* The code can contain several inputs, each with its own line number. Like a notebook input cell, the input cell
   is labeled with the line number of the first input, and the output cell with the label of the last output.
   Deployment is mocked, so no cloud is involved. *)
VerificationTest[
    Module[ { nb = None, result },
        result = Block[
            {
                Wolfram`AgentTools`Common`deployCloudNotebookForMCPApp =
                    Function[ nb = #1; "https://www.wolframcloud.com/obj/test-notebook" ]
            },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`makeEvaluatorUIResult[
                "1 + 1\n2 + 2",
                <| "String" -> "Out[3]= 2\n\nOut[4]= 4", "Result" -> HoldCompleteForm[ 4 ] |>,
                3
            ]
        ];
        { result, Cases[ nb, (CellLabel -> label_) :> label, Infinity ] }
    ],
    { KeyValuePattern[ "Content" -> { __Association } ], { "In[3]:=", "Out[4]=" } },
    SameTest -> MatchQ,
    TestID   -> "makeEvaluatorUIResult-MultipleInputLabels"
]

(* Without an output label in the result string, the output cell gets the line number of the input. *)
VerificationTest[
    Module[ { nb = None },
        Block[
            {
                Wolfram`AgentTools`Common`deployCloudNotebookForMCPApp =
                    Function[ nb = #1; "https://www.wolframcloud.com/obj/test-notebook" ]
            },
            Wolfram`AgentTools`Tools`WolframLanguageEvaluator`Private`makeEvaluatorUIResult[
                "Print[1]",
                <| "String" -> "1", "Result" -> HoldCompleteForm[ Null ] |>,
                5
            ]
        ];
        Cases[ nb, (CellLabel -> label_) :> label, Infinity ]
    ],
    { "In[5]:=", "Out[5]=" },
    SameTest -> MatchQ,
    TestID   -> "makeEvaluatorUIResult-DefaultOutputLabel"
]

(* :!CodeAnalysis::EndBlock:: *)
