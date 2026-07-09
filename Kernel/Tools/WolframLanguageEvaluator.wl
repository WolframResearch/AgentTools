(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Tools`WolframLanguageEvaluator`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"          ];
Needs[ "Wolfram`AgentTools`Common`"   ];
Needs[ "Wolfram`AgentTools`Graphics`" ];
Needs[ "Wolfram`AgentTools`Tools`"    ];

Needs[ "Wolfram`Chatbook`" -> "cb`" ];

System`HoldCompleteForm;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$cloudImagePath        := CloudObject[ "AgentTools/Images", Permissions -> $cloudImagePermissions ];
$cloudImagePermissions := If[ $imageExportMethod === "CloudPublic", "Public", "Private" ];
$line                   = 1;
$outputSizeLimit        = 100000;

(* Evaluator session state (plain load-time assignments, so they reset on every (re)load; see the Sessions section) *)
$currentSessionID = None;
$sessionStatus    = None;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Option Configuration*)
$evaluatorMethod   := toolOptionValue[ "WolframLanguageEvaluator", "Method" ];
$imageExportMethod := toolOptionValue[ "WolframLanguageEvaluator", "ImageExportMethod" ];
$maxSessionCount   := toolOptionValue[ "WolframLanguageEvaluator", "MaxSessionCount" ];
$maxSessionBytes   := toolOptionValue[ "WolframLanguageEvaluator", "MaxSessionBytes" ];
$maxSessionAge     := toolOptionValue[ "WolframLanguageEvaluator", "MaxSessionAge"   ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompts*)
(* TODO: We need a way to make this description dynamic, e.g. when "Method" is "Session", it also has write access *)
$wolframLanguageEvaluatorToolDescription = "\
Evaluates Wolfram Language code for the user in a Wolfram Language kernel.
Do not ask permission to evaluate code.
You have read access to local files.
Always use the Wolfram context tool before using this tool to make sure you have the most up-to-date information.

Use `\[FreeformPrompt][\"query\"]` to parse natural language into Wolfram Language expressions \
(like ctrl+= in notebooks). Always use this for `Quantity`, `Entity`, `EntityClass`, etc. \
It composes freely: `ColorNegate[\[FreeformPrompt][\"picture of a cat\"]]`.

Examples:
```
\[FreeformPrompt][\"France population\"]  (* Entity property value *)
\[FreeformPrompt][\"123 terawatt hours\"] (* Quantity *)
```

The argument MUST be a string literal \[LongDash] it parses before evaluation, so runtime construction will not work.";

$markdownImageHint = "\
<system-reminder>The user does not see the images in the tool response. \
Use the markdown image in your response to show them.</system-reminder>";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Definition*)
(* Add to $defaultMCPTools Association (initialized in Kernel/Tools/Tools.wl) *)
$defaultMCPTools[ "WolframLanguageEvaluator" ] := LLMTool @ <|
    "Name"        -> "WolframLanguageEvaluator",
    "DisplayName" -> "Wolfram Language Evaluator",
    "Description" -> $wolframLanguageEvaluatorToolDescription,
    "Function"    -> evaluateWolframLanguage,
    "Options"     -> { },
    "Parameters"  -> {
        "code" -> <|
            "Interpreter" -> "String",
            "Help"        -> "The Wolfram Language code to evaluate.",
            "Required"    -> True
        |>,
        "timeConstraint" -> <|
            "Interpreter" -> "Integer",
            "Help"        -> "The time constraint for the evaluation. Uses the server's configured default if not specified.",
            "Required"    -> False
        |>,
        "session" -> <|
            "Interpreter" -> "String",
            "Help"        -> "An opaque session ID returned by a previous call to this tool. Pass it to continue that conversation's isolated session (its definitions, line numbers, and history). Omit it to start a new session; the response returns a new ID that you should reuse on subsequent calls in this conversation.",
            "Required"    -> False
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Default Tool Options*)
$defaultToolOptions[ "WolframLanguageEvaluator" ] = <|
    "Method"            -> "Session",
    "ImageExportMethod" -> None,
    "TimeConstraint"    -> 60,
    "MaxSessionCount"   -> 100,
    "MaxSessionBytes"   -> 1073741824, (* 1 GB *)
    "MaxSessionAge"     -> Quantity[ 1, "Months" ]
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateWolframLanguage*)
evaluateWolframLanguage // beginDefinition;

evaluateWolframLanguage[ args: KeyValuePattern[ "code" -> code_ ] ] :=
    Module[ { timeConstraint, session },
        timeConstraint = Lookup[ args, "timeConstraint", Missing[ "timeConstraint" ] ];
        session        = Lookup[ args, "session", Missing[ "session" ] ];
        withSession[
            session,
            If[ TrueQ @ $clientSupportsUI && TrueQ @ $deployCloudNotebooks,
                evaluateWolframLanguageUI[ code, timeConstraint ],
                evaluateWolframLanguage[ code, timeConstraint ]
            ]
        ]
    ];

evaluateWolframLanguage[ code_String, _Missing ] :=
    evaluateWolframLanguage[ code, toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ] ];

evaluateWolframLanguage[ code_String, timeConstraint_Integer ] := Enclose[
    Module[ { string, exported },
        ConfirmMatch[ chatbookVersionCheck[ ], True, "ChatbookVersionCheck" ];
        string   = ConfirmBy[ evaluateWolframLanguage0[ code, timeConstraint ], StringQ, "Result" ];
        exported = ConfirmBy[ exportImages @ string, AssociationQ, "Exported" ];
        exported  (* Return the structured content *)
    ],
    throwInternalFailure
];

evaluateWolframLanguage // endDefinition;


evaluateWolframLanguage0 // beginDefinition;
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
evaluateWolframLanguage0[ code_String, timeConstraint_Integer ] :=
    Block[ (* FIXME: Expose this as an option in WolframLanguageToolEvaluate *)
        { Wolfram`Chatbook`Sandbox`Private`$includeDefinitions = False },
            catchAlways @ cb`WolframLanguageToolEvaluate[
            code,
            "String",
            "Line"                  -> $line++,
            "MaxCharacterCount"     -> 10000,
            "AppendRetryNotice"     -> False,
            "AppendURIInstructions" -> False,
            "Method"                -> $evaluatorMethod,
            "TimeConstraint"        -> timeConstraint
        ]
    ];
(* :!CodeAnalysis::EndBlock:: *)
evaluateWolframLanguage0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*exportImages*)
exportImages // beginDefinition;

exportImages[ str_String ] := Enclose[
    Module[ { parts, hasImages, contentItems },

        parts = ConfirmMatch[ cb`GetExpressionURIs @ str, { __ }, "Parts" ];

        hasImages = False;
        contentItems = Flatten @ Map[
            Function[ item,
                If[ StringQ @ item,
                    (* Text segment: create text content *)
                    { <| "type" -> "text", "text" -> item |> },
                    (* Graphics: create text content (with cloud URL) + image content (base64) *)
                    hasImages = True;
                    Module[ { cloudURL, imageContent },
                        cloudURL = ConfirmMatch[ exportImage @ item, _String|None, "CloudURL" ];  (* Returns "![Image](url)" *)
                        imageContent = graphicsToImageContent @ item;
                        Flatten @ {
                            If[ StringQ @ cloudURL, <| "type" -> "text", "text" -> cloudURL |>, Nothing ],
                            If[ AssociationQ @ imageContent, imageContent, Nothing ]
                        }
                    ]
                ]
            ],
            parts
        ];

        (* Append the image hint reminder if there were images *)
        If[ TrueQ @ hasImages && $imageExportMethod =!= None,
            AppendTo[ contentItems, <| "type" -> "text", "text" -> "\n\n" <> $markdownImageHint |> ]
        ];

        <| "Content" -> ConfirmMatch[ contentItems, { __Association }, "ContentItems" ] |>
    ],
    throwInternalFailure
];

exportImages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*exportImage*)
exportImage // beginDefinition;

exportImage[ expr_ ] := exportImage[ expr, $imageExportMethod ];

exportImage[ expr_, "Local" ] := Enclose[
    Module[ { hash, file, png, lo, uri },
        hash = ConfirmBy[ Hash[ expr, Automatic, "HexString" ], StringQ, "Hash" ];
        file = ConfirmBy[ fileNameJoin[ $imagePath, StringTake[ hash, 3 ], hash <> ".png" ], fileQ, "File" ];
        png  = ConfirmBy[ Export[ file, expr, "PNG" ], FileExistsQ, "PNG" ];
        lo   = ConfirmMatch[ LocalObject @ png, HoldPattern @ LocalObject[ _String, ___ ], "LocalObject" ];
        uri  = ConfirmBy[ First @ lo, StringQ, "URI" ];
        "![Image]("<>uri<>")"
    ],
    throwInternalFailure
];

exportImage[ expr_, "Cloud"|"CloudPublic" ] := Enclose[
    Module[ { hash, root, file, png, uri },

        hash = ConfirmBy[ Hash[ expr, Automatic, "HexString" ], StringQ, "Hash" ];
        root = ConfirmMatch[ $cloudImagePath, CloudObject[ _String, ___ ], "Root" ];

        file = ConfirmMatch[
            FileNameJoin @ { root, StringTake[ hash, 3 ], hash <> ".png" },
            _CloudObject,
            "File"
        ];

        png = ConfirmBy[ Export[ file, expr, "PNG" ], FileExistsQ, "PNG" ];

        uri = First @ ConfirmMatch[
            CloudObject[ png, CloudObjectNameFormat -> "UUID" ],
            CloudObject[ _String, ___ ],
            "URI"
        ];

        "![Image]("<>uri<>")"
    ],
    throwInternalFailure
];

exportImage[ expr_, _ ] := None;

exportImage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*UI-Enhanced Evaluation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateWolframLanguageUI*)
evaluateWolframLanguageUI // beginDefinition;

evaluateWolframLanguageUI[ code_String, _Missing ] :=
    evaluateWolframLanguageUI[ code, toolOptionValue[ "WolframLanguageEvaluator", "TimeConstraint" ] ];

evaluateWolframLanguageUI[ code_String, timeConstraint_Integer ] :=
    Module[ { savedLine, result, uiResult },
        savedLine = $line;
        result = evaluateWolframLanguageForUI[ code, timeConstraint ];
        uiResult = Quiet @ UsingFrontEnd @ makeEvaluatorUIResult[ code, result ];
        If[ MatchQ[ uiResult, KeyValuePattern[ "Content" -> { __Association } ] ],
            uiResult,
            (* UI result creation failed; reuse already-computed string to avoid re-evaluation *)
            If[ StringQ @ result[ "String" ],
                exportImages @ result[ "String" ],
                (* String result not available; re-evaluate as last resort *)
                $line = savedLine;
                evaluateWolframLanguage[ code, timeConstraint ]
            ]
        ]
    ];

evaluateWolframLanguageUI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateWolframLanguageForUI*)
evaluateWolframLanguageForUI // beginDefinition;
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
evaluateWolframLanguageForUI[ code_String, timeConstraint_Integer ] :=
    Block[ { Wolfram`Chatbook`Sandbox`Private`$includeDefinitions = False },
        catchAlways @ cb`WolframLanguageToolEvaluate[
            code,
            { "String", "Result" },
            "Line"                  -> $line++,
            "MaxCharacterCount"     -> 10000,
            "AppendRetryNotice"     -> False,
            "AppendURIInstructions" -> False,
            "Method"                -> $evaluatorMethod,
            "TimeConstraint"        -> timeConstraint
        ]
    ];
(* :!CodeAnalysis::EndBlock:: *)
evaluateWolframLanguageForUI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeEvaluatorUIResult*)
makeEvaluatorUIResult // beginDefinition;

makeEvaluatorUIResult[
    code0_String,
    KeyValuePattern[ { "Result" -> heldResult_, "String" -> stringResult_String } ]
] := Enclose[
    Catch @ Module[ { code, textContent, outLabel, inLabel, inputCell, outputCell, nb, deployed },

        code = StringTrim @ code0;

        textContent = ConfirmMatch[
            toContentList @ exportImages @ stringResult,
            { __Association },
            "TextContent"
        ];

        (* Extract cell labels from string *)
        outLabel = Last[ StringCases[ stringResult, "Out[" ~~ DigitCharacter.. ~~ "]=" ], "Out[1]=" ];
        inLabel  = StringReplace[ outLabel, "Out[" ~~ n: DigitCharacter.. ~~ "]=" :> "In[" <> n <> "]:=" ];

        (* Create cells *)
        inputCell = Cell[
            BoxData @ makeFancyCharacters @ cb`StringToBoxes[ code, "WL" ],
            "Input",
            CellLabel            -> inLabel,
            LanguageCategory     -> "Input",
            ShowAutoStyles       -> True,
            ShowStringCharacters -> True,
            ShowSyntaxStyles     -> True
        ];

        outputCell = Cell[
            BoxData[ toOutputBoxes @ heldResult ],
            "Output",
            CellLabel -> outLabel,
            FontColor -> Black
        ];

        nb = Notebook[
            { Cell @ CellGroupData[ { inputCell, outputCell }, Open ] },
            CellLabelAutoDelete    -> False,
            ScreenStyleEnvironment -> "Elegant"
        ];

        deployed = ConfirmMatch[
            deployCloudNotebookForMCPApp[ nb, { code, heldResult } ],
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

makeEvaluatorUIResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toOutputBoxes*)
toOutputBoxes // beginDefinition;

toOutputBoxes[ (HoldForm|HoldCompleteForm)[ expr_ ] ] :=
    Block[ { $OutputSizeLimit = $outputSizeLimit },
        delayedDisplay @ cb`CachedBoxes @ OutputSizeLimit`PrePrint @ expr
    ];

toOutputBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toContentList*)
toContentList // beginDefinition;
toContentList[ KeyValuePattern[ "Content" -> items_List ] ] := items;
toContentList[ items_List ] := items;
toContentList[ str_String ] := { <| "type" -> "text", "text" -> str |> };
toContentList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeFancyCharacters*)
makeFancyCharacters // beginDefinition;
makeFancyCharacters[ boxes_ ] := boxes /. $fancyCharRules;
makeFancyCharacters // endDefinition;

$fancyCharRules := $fancyCharRules = Dispatch @ {
    (* Extracted from CurrentValue[{StyleHints, "OperatorRenderings"}] *)
    "|->" -> "\[Function]",
    "->" -> "\[Rule]",
    ":>" -> "\[RuleDelayed]",
    "<=" -> "\[LessEqual]",
    ">=" -> "\[GreaterEqual]",
    "!=" -> "\[NotEqual]",
    "==" -> "\[Equal]",
    "<->" -> "\[TwoWayRule]",
    "[[" -> "\[LeftDoubleBracket]",
    "]]" -> "\[RightDoubleBracket]",
    "<|" -> "\[LeftAssociation]",
    "|>" -> "\[RightAssociation]",
    "**" -> "\:29bb",
    RowBox @ { expr_, "[", RowBox @ { "[", part__, "]" }, "]" } :>
        RowBox @ { expr, "\[LeftDoubleBracket]", part, "\[RightDoubleBracket]" }
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*useEvaluatorKernel*)
useEvaluatorKernel // beginDefinition;
useEvaluatorKernel // Attributes = { HoldAllComplete };

(* Used for evaluations that need to be run in the same kernel as the evaluator tool (e.g. symbol definitions) *)
useEvaluatorKernel[ eval_ ] :=
    If[ $evaluatorMethod === "Local",
        evaluateInLocalKernel @ eval,
        eval
    ];

useEvaluatorKernel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*evaluateInLocalKernel*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

evaluateInLocalKernel // beginDefinition;
evaluateInLocalKernel // Attributes = { HoldAllComplete };

evaluateInLocalKernel[ eval_ ] :=
    Block[ (* FIXME: Expose this as an option in WolframLanguageToolEvaluate *)
        { Wolfram`Chatbook`Sandbox`Private`$includeDefinitions = False },
        evaluateInLocalKernel0 @ eval
    ];

evaluateInLocalKernel // endDefinition;


evaluateInLocalKernel0 // beginDefinition;
evaluateInLocalKernel0 // Attributes = { HoldAllComplete };

evaluateInLocalKernel0[ eval_ ] := Enclose[
    Module[ { heldResult, result },
        ConfirmMatch[ initializePacletInLocalKernel[ ], Null, "InitializePacletInLocalKernel" ];

        heldResult = cb`WolframLanguageToolEvaluate[
            HoldComplete @ WithCleanup[

                Block[ { $catching = True },
                    (* Since this is in another kernel, thrown errors won't propagate back to the top-level,
                        so we need to catch and identify them here to send them to the top if needed. *)
                    Catch[ eval, _, caughtWrapper ]
                ],

                (* Roll back the line number, since this isn't part of a tool evaluation *)
                $Line--
            ],
            "Result",
            "Method" -> "Local"
        ];

        result = Replace[
            heldResult,
            {
                (* Throw failures to the top-level *)
                (HoldForm|HoldCompleteForm)[ caughtWrapper[ failure_Failure, $catchTopTag ] ] :> throwFailure @ failure,
                (* Otherwise, release the hold *)
                (HoldForm|HoldCompleteForm)[ r_ ] :> r
            }
        ];

        result
    ],
    throwInternalFailure
];

evaluateInLocalKernel0 // endDefinition;

caughtWrapper // Attributes = { HoldAllComplete };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*initializePacletInLocalKernel*)
initializePacletInLocalKernel // beginDefinition;

initializePacletInLocalKernel[ ] := Enclose[
    Module[ { pacletDir, result },
        pacletDir = ConfirmMatch[ $thisPaclet[ "Location" ], _? DirectoryQ, "PacletDir" ];

        result = With[ { dir = pacletDir },
            cb`WolframLanguageToolEvaluate[
                HoldComplete @ WithCleanup[
                    PacletDirectoryLoad @ dir;
                    Block[ { $ContextPath }, Get[ "Wolfram`AgentTools`" ] ],
                    $Line--
                ],
                "Result",
                "Method" -> "Local"
            ]
        ];

        initializePacletInLocalKernel[ ] = ConfirmMatch[ ReleaseHold @ result, Null, "Result" ]
    ],
    throwInternalFailure
];

initializePacletInLocalKernel // endDefinition;

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sessions*)
(* Each conversation gets an isolated, resumable evaluation session, keyed by an opaque ID supplied by
   the AI via the "session" parameter. Isolation comes from a per-session $Context: the session functions
   run via useEvaluatorKernel and point the controlling kernel's $Context at "Sessions`<id>`", so the
   user's code parses into that context (and, under the "Local" method, the resulting fully qualified
   symbols then evaluate in that context inside the eval subkernel). State is persisted to disk so sessions
   survive server restarts.

   Line numbering is owned by the file-scoped $line: the authoritative per-session counter, persisted in
   the session payload and passed as the "Line" option. Under the in-process "Session" method that option
   drives the In/Out label directly. Under "Local" the user's code runs in a persistent subkernel whose own
   $Line produces the label and the option does not reach it, so syncEvalKernelLine pushes $line into that
   subkernel's $Line at each session boundary, after which the two advance in lockstep. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Session ID Generation*)
$sessionIDLetters    := $sessionIDLetters    = Join[ CharacterRange[ "a", "z" ], CharacterRange[ "A", "Z" ] ];
$sessionIDCharacters := $sessionIDCharacters = Join[ $sessionIDLetters, CharacterRange[ "0", "9" ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createSessionID*)
createSessionID // beginDefinition;
(* First character is a letter so the ID is a valid context component; 8 chars total. *)
createSessionID[ ] := StringJoin[ RandomChoice[ $sessionIDLetters ], RandomChoice[ $sessionIDCharacters, 7 ] ];
createSessionID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validSessionIDQ*)
(* Guards "Sessions`" <> id <> "`" against backtick / space / path injection: must start with a letter,
   contain only word characters, and be of bounded length. *)
validSessionIDQ // beginDefinition;
validSessionIDQ[ id_String ] := StringLength @ id <= 64 && StringMatchQ[ id, LetterCharacter ~~ WordCharacter... ];
validSessionIDQ[ _ ] := False;
validSessionIDQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Session Paths*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sessionsPath*)
sessionsPath // beginDefinition;
sessionsPath[ ] := fileNameJoin @ { $rootPath, "Sessions" };
sessionsPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sessionFile*)
sessionFile // beginDefinition;
sessionFile[ id_String ] := fileNameJoin @ { sessionsPath[ ], id <> ".mx" };
sessionFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Starting, Saving, and Resuming Sessions*)
(* The *InKernel companions set up the kernel-side session state ($Context, In/Out history, $Line) via
   useEvaluatorKernel and return the line seed; the outer functions update the MCP-side $currentSessionID
   and the file-scoped $line. Note that under the "Local" method useEvaluatorKernel runs these in the
   controlling kernel (which is what points its $Context at the session so the user's code parses into it);
   the user's code itself runs in the eval subkernel, whose $Line is set separately via syncEvalKernelLine. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*startSession*)
startSession // beginDefinition;

startSession[ id_String ] := Enclose[
    Module[ { line },
        line = ConfirmMatch[ useEvaluatorKernel @ startSessionInKernel @ id, _Integer, "Seed" ];
        $currentSessionID = id;
        $line             = line;
        id
    ],
    throwInternalFailure
];

startSession // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*startSessionInKernel*)
startSessionInKernel // beginDefinition;
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
startSessionInKernel[ id_String ] := (
    $Context        = "Sessions`" <> id <> "`";
    $ContextPath    = { $Context, "System`" };
    $ContextAliases = <| |>;
    Unprotect[ In, InString, Out, MessageList ];
    DownValues[ In ]          = { };
    DownValues[ InString ]    = { };
    DownValues[ Out ]         = { };
    DownValues[ MessageList ] = { };
    Protect[ In, InString, Out, MessageList ];
    $Line = 1; (* seed 1 -> first label Out[1]=, matching the original $line origin *)
    $Line
);
(* :!CodeAnalysis::EndBlock:: *)
startSessionInKernel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*enterSessionContext*)
(* Re-point the eval kernel at an already-live session's context (used when continuing the current
   session). Unlike startSession it does NOT reset In/Out/$Line: the continuing session's history and
   the file-scoped $line counter persist between calls. *)
enterSessionContext // beginDefinition;

enterSessionContext[ id_String ] := Enclose[
    ConfirmMatch[ useEvaluatorKernel @ enterSessionContextInKernel @ id, Null, "Entered" ];
    id,
    throwInternalFailure
];

enterSessionContext // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*enterSessionContextInKernel*)
enterSessionContextInKernel // beginDefinition;

enterSessionContextInKernel[ id_String ] := (
    $Context        = "Sessions`" <> id <> "`";
    $ContextPath    = { $Context, "System`" };
    $ContextAliases = <| |>;
    Null
);

enterSessionContextInKernel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*syncEvalKernelLine*)
(* Push the session's line counter into the eval kernel's $Line. Only needed for the "Local" method: there
   the user's code runs in a persistent subkernel whose own $Line produces the In/Out label, and the "Line"
   option does not reach it. (For in-process methods the "Line" option drives the label directly, so this
   is a no-op.) Routed through evaluateInLocalKernel0 so it targets the subkernel; its $Line-- rollback
   cancels the main-loop increment, leaving $Line set to exactly the next user line. Called at session
   boundaries (see withSession); within a session the subkernel's $Line then advances in lockstep with
   $line. *)
syncEvalKernelLine // beginDefinition;
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
syncEvalKernelLine[ line_Integer ] /; $evaluatorMethod === "Local" :=
    Block[ { Wolfram`Chatbook`Sandbox`Private`$includeDefinitions = False },
        With[ { n = line }, evaluateInLocalKernel0[ $Line = n ] ]
    ];
(* :!CodeAnalysis::EndBlock:: *)
syncEvalKernelLine[ _Integer ] := Null;
syncEvalKernelLine // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*syncEvalKernelLineSafe*)
(* Line bookkeeping must never abort the user's evaluation result (mirrors startSessionSafe et al.). *)
syncEvalKernelLineSafe // beginDefinition;
syncEvalKernelLineSafe[ line_Integer ] := Quiet @ catchAlways @ syncEvalKernelLine @ line;
syncEvalKernelLineSafe[ _ ] := Null;
syncEvalKernelLineSafe // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*saveSession*)
saveSession // beginDefinition;

saveSession[ id_String ] := Enclose[
    Module[ { dir, file },
        dir  = ConfirmBy[ ensureDirectory @ sessionsPath[ ], directoryQ, "Directory" ];
        file = ConfirmBy[ sessionFile @ id, fileQ, "File" ];
        ConfirmMatch[ useEvaluatorKernel @ saveSessionInKernel[ id, First @ file ], True, "Saved" ];
        cleanupSessions[ ]; (* cleanup-after-write, mirrors Common.wl failure-log handling *)
        file
    ],
    throwInternalFailure
];

saveSession // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*saveSessionInKernel*)
saveSessionInKernel // beginDefinition;
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
saveSessionInKernel[ id_String, path_String ] :=
    Module[ { tmp },
        $sessionInfo = <|
            "$Context"        -> $Context,
            "$ContextPath"    -> $ContextPath,
            "$ContextAliases" -> $ContextAliases,
            "$Line"           -> $Line, (* eval kernel's $Line, kept for reference / back-compat *)
            "$line"           -> $line, (* authoritative per-session counter that drives resume *)
            "In"              -> DownValues[ In ],
            "InString"        -> DownValues[ InString ],
            "Out"             -> DownValues[ Out ],
            "MessageList"     -> DownValues[ MessageList ]
        |>;
        tmp = path <> ".tmp";
        (* DumpSave the session $Context (all user symbols) plus the held $sessionInfo symbol; the With
           injects the evaluated context string while DumpSave's HoldRest keeps $sessionInfo a symbol. *)
        With[ { ctx = $Context },
            DumpSave[ tmp, { ctx, $sessionInfo }, "SymbolAttributes" -> False ]
        ];
        RenameFile[ tmp, path, OverwriteTarget -> True ]; (* atomic-ish: never leave a half-written .mx *)
        True
    ];
(* :!CodeAnalysis::EndBlock:: *)
saveSessionInKernel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resumeSession*)
resumeSession // beginDefinition;

resumeSession[ id_String ] := Enclose[
    Module[ { file, seed },
        file = ConfirmBy[ sessionFile @ id, fileQ, "File" ];
        seed = If[ FileExistsQ @ First @ file,
                   useEvaluatorKernel @ resumeSessionInKernel @ First @ file,
                   $Failed
               ];
        If[ IntegerQ @ seed,
            $currentSessionID = id; $line = seed; id,
            (* Missing or corrupt session file: signal the caller to start fresh (no bug report). *)
            $Failed
        ]
    ],
    throwInternalFailure
];

resumeSession // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resumeSessionInKernel*)
resumeSessionInKernel // beginDefinition;
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
resumeSessionInKernel[ path_String ] :=
    Module[ { info, line },
        $sessionInfo = $Failed; (* clear stale so a failed Get is detectable *)
        Quiet @ Get @ path;
        info = $sessionInfo;
        If[ AssociationQ @ info,
            (* "$line" is the authoritative per-session counter; fall back to the kernel "$Line" for
               sessions written before it was persisted. *)
            line            = Replace[ info[ "$line" ], Except[ _Integer ] :> info[ "$Line" ] ];
            $Context        = info[ "$Context" ];
            $ContextPath    = info[ "$ContextPath" ];
            $ContextAliases = info[ "$ContextAliases" ];
            $Line           = line;
            Unprotect[ In, InString, Out, MessageList ];
            DownValues[ In ]          = info[ "In" ];
            DownValues[ InString ]    = info[ "InString" ];
            DownValues[ Out ]         = info[ "Out" ];
            DownValues[ MessageList ] = info[ "MessageList" ];
            Protect[ In, InString, Out, MessageList ];
            line,
            (* else: malformed payload *)
            $Failed
        ]
    ];
(* :!CodeAnalysis::EndBlock:: *)
resumeSessionInKernel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Session Cleanup*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cleanupSessions*)
(* Prune oldest-first by age, then count, then total byte budget. The current session's file is always
   retained, so it is excluded from the candidate set (and from the limits). *)
cleanupSessions // beginDefinition;

cleanupSessions[ ] := cleanupSessions[ $maxSessionCount, $maxSessionBytes, $maxSessionAge ];

cleanupSessions[ maxCount_, maxBytes_, maxAge_ ] :=
    Catch @ Module[ { dir, all, files, dated, cutoff, old, keep, byCount, bySize, toDelete },
        dir = First @ sessionsPath[ ];
        If[ ! DirectoryQ @ dir, Throw @ Null ];
        all = FileNames[ "*.mx", dir ];
        files = If[ StringQ @ $currentSessionID,
                    DeleteCases[ all, f_ /; FileBaseName @ f === $currentSessionID ],
                    all
                ];
        If[ files === { }, Throw @ Null ];
        dated   = SortBy[ files, FileDate[ #, "Modification" ] & ]; (* oldest first *)
        cutoff  = toAgeCutoff @ maxAge;
        old     = If[ cutoff === None, { }, Select[ dated, FileDate[ #, "Modification" ] < cutoff & ] ];
        keep    = DeleteCases[ dated, Alternatives @@ old ];
        byCount = If[ IntegerQ @ maxCount && Length @ keep > maxCount, Take[ keep, Length @ keep - maxCount ], { } ];
        keep    = Drop[ keep, Length @ byCount ];
        bySize  = sessionsOverByteBudget[ keep, maxBytes ];
        toDelete = Union[ old, byCount, bySize ];
        If[ toDelete =!= { }, Quiet[ DeleteFile /@ toDelete ] ];
    ];

cleanupSessions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toAgeCutoff*)
toAgeCutoff // beginDefinition;
toAgeCutoff[ q_Quantity ]      := Now - q;
toAgeCutoff[ s_String ]        := With[ { q = Quiet @ Quantity @ s }, If[ QuantityQ @ q, Now - q, None ] ];
toAgeCutoff[ n_? NumericQ ]    := Now - Quantity[ n, "Seconds" ];
toAgeCutoff[ None | Infinity ] := None;
toAgeCutoff[ _ ]               := None;
toAgeCutoff // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sessionsOverByteBudget*)
sessionsOverByteBudget // beginDefinition;

sessionsOverByteBudget[ _List, max_ ] /; ! IntegerQ @ max := { };
sessionsOverByteBudget[ files_List, max_Integer ] :=
    Module[ { sizes, acc, drop },
        sizes = AssociationMap[ FileByteCount, files ]; (* oldest-first order preserved *)
        acc   = Total @ Values @ sizes;
        drop  = { };
        If[ acc <= max, Return[ { }, Module ] ];
        Do[
            If[ acc <= max, Break[ ] ];
            AppendTo[ drop, f ];
            acc -= sizes[ f ],
            { f, files }
        ];
        drop
    ];

sessionsOverByteBudget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Session Orchestration*)
(* The single place that compares the incoming session to $currentSessionID. withSession scopes
   $Context/$ContextPath to the evaluation (Internal`InheritedBlock), so each call must (re-)point the
   eval kernel at the session context: a continuing session re-enters its context (its definitions and
   In/Out/$Line history persist in the kernel between calls); a different existing session is resumed
   from disk; an unknown ID starts a fresh session reusing that ID. The outgoing session is not saved
   here on a switch because every call already saves its session at the end (see withSession). *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applySession*)
applySession // beginDefinition;

applySession[ _Missing | None ] := (
    $sessionStatus = "new";
    startSessionSafe @ createSessionID[ ]
);

applySession[ id_String ] /; ! validSessionIDQ @ id := (
    $sessionStatus = "new";
    startSessionSafe @ createSessionID[ ]
);

applySession[ id_String ] :=
    Which[
        id === $currentSessionID,
            $sessionStatus = "continued";
            enterSessionContextSafe @ id,

        FileExistsQ @ First @ sessionFile @ id,
            $sessionStatus = "resumed";
            resumeSessionSafe @ id,

        True,
            $sessionStatus = "reused";
            startSessionSafe @ id
    ];

applySession // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*startSessionSafe*)
(* Session bookkeeping must never abort the user's evaluation result. catchAlways contains any throw even
   inside the outer catchTop; Quiet suppresses incidental DumpSave/Get messages. *)
startSessionSafe // beginDefinition;

startSessionSafe[ id_String ] :=
    Replace[
        Quiet @ catchAlways @ startSession @ id,
        Except[ _String ] :> ($currentSessionID = id; $line = 1; id)
    ];

startSessionSafe // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resumeSessionSafe*)
resumeSessionSafe // beginDefinition;

resumeSessionSafe[ id_String ] :=
    Replace[
        Quiet @ catchAlways @ resumeSession @ id,
        Except[ _String ] :> ( $sessionStatus = "reused"; startSessionSafe @ id )
    ];

resumeSessionSafe // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*enterSessionContextSafe*)
enterSessionContextSafe // beginDefinition;

enterSessionContextSafe[ id_String ] :=
    Replace[
        Quiet @ catchAlways @ enterSessionContext @ id,
        Except[ _String ] :> startSessionSafe @ id
    ];

enterSessionContextSafe // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*saveSessionSafe*)
saveSessionSafe // beginDefinition;
saveSessionSafe[ id_String ] := Quiet @ catchAlways @ saveSession @ id;
saveSessionSafe // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*withSession*)
(* Single choke point wrapping both eval paths: set up the session, evaluate, save, then append the
   session info. HoldRest defers the evaluation until the session is active. Internal`InheritedBlock
   scopes $Context/$ContextPath/$ContextAliases to this call: the session context is active during the
   evaluation and the save, then restored to the kernel's neutral baseline afterward. Symbols created
   during the block (the user's definitions) persist in their session context, as do the session's
   In/Out/$Line (which are not in the block), so isolation and history survive across calls while the
   kernel is never left in a session context between calls. *)
withSession // beginDefinition;
withSession // Attributes = { HoldRest };

withSession[ session_, eval_ ] :=
    Internal`InheritedBlock[ { $Context, $ContextPath, $ContextAliases },
        Module[ { id, result },
            id = applySession @ session;
            (* applySession has set $line and the session $Context. For the "Local" method also push $line
               into the eval subkernel's $Line at a boundary (a continued session already tracks it in
               lockstep); no-op for in-process methods. *)
            If[ $sessionStatus =!= "continued", syncEvalKernelLineSafe @ $line ];
            result = eval;
            saveSessionSafe @ id;
            appendSessionInfo[ result, id ]
        ]
    ];

withSession // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendSessionInfo*)
appendSessionInfo // beginDefinition;

appendSessionInfo[ as_Association, id_String ] /; KeyExistsQ[ as, "Content" ] :=
    Append[ as, "Content" -> Append[ as[ "Content" ], sessionInfoContentItem @ id ] ];

appendSessionInfo[ str_String, id_String ] :=
    str <> sessionInfoText @ id;

appendSessionInfo[ other_, id_String ] := <|
    "Content" -> {
        <| "type" -> "text", "text" -> ToString @ other |>,
        sessionInfoContentItem @ id
    }
|>;

appendSessionInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sessionInfoContentItem*)
sessionInfoContentItem // beginDefinition;
sessionInfoContentItem[ id_String ] := <| "type" -> "text", "text" -> sessionInfoText @ id |>;
sessionInfoContentItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sessionInfoText*)
sessionInfoText // beginDefinition;

sessionInfoText[ id_String ] := StringJoin[
    "\n\n<system-reminder>Wolfram session ID: ", id, ".",
    If[ $sessionStatus === "reused", " (No saved state was found for this ID, so a new empty session was started.)", "" ],
    " To continue this session (its definitions, line numbers, and history) in your next call to this tool, pass session=\"", id,
    "\". Omit the session parameter only to start a new, empty session.</system-reminder>"
];

sessionInfoText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];