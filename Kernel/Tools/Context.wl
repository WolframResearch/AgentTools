(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Tools`Context`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];
Needs[ "Wolfram`AgentTools`Tools`"  ];

Needs[ "Wolfram`Chatbook`" -> "cb`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Option Values*)
$waMaxItems         := toolOptionValue[ "WolframAlphaContext", "MaxItems" ];
$waIncludeWLResults := toolOptionValue[ "WolframAlphaContext", "IncludeWolframLanguageResults" ];
$wlMaxItems         := toolOptionValue[ "WolframLanguageContext", "MaxItems" ];
$wcMaxItemsWL       := toolOptionValue[ "WolframContext", "WolframLanguageMaxItems" ];
$wcMaxItemsWA       := toolOptionValue[ "WolframContext", "WolframAlphaMaxItems" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$maxItemsSpec = Automatic | _Integer? Positive;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompts*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WolframContext*)
$wolframContextToolDescription = "\
Combined lookup spanning both Wolfram Language documentation and Wolfram|Alpha knowledge. \
Use this tool to:
- Approach a topic that spans both real-world knowledge and Wolfram Language programming \
(e.g., chemistry, physics, finance, geography).
- Cast a wider net early in exploration to surface relevant context from both sources at once.
- Survey a domain before deciding whether you need data lookup, code reference, or both.

When the question is clearly programming-focused or clearly factual, prefer the more specific \
`WolframLanguageContext` or `WolframAlphaContext` instead.

Argument is a natural-language description, not a search query.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WolframAlphaContext*)
$waContextToolDescription = "\
Computational knowledge lookup powered by Wolfram|Alpha \[LongDash] the authoritative source for \
real-world data, scientific constants, entity properties, and curated factual knowledge. \
Use this tool to:
- Look up real-world data and current facts (populations, prices, dates, geographic info, scientific constants).
- Resolve natural-language quantities and entities to structured form (`Quantity`, `Entity`, `DateObject`, etc.).
- Cross-reference factual knowledge alongside symbolic computation.

Argument is a natural-language description, not a search query.";

$wolframAlphaMissingLLMKitTemplate = StringTemplate[ "\
`Level`: Unable to generate Wolfram|Alpha context due to missing LLMKit subscription. \
Inform the user that they can subscribe at the following URL in order to improve the quality of the results: `URL`" ];

$wolframAlphaNoCloudTemplate = StringTemplate[ "\
`Level`: Unable to generate Wolfram|Alpha context due to missing cloud connection." ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WolframLanguageContext*)
$wlContextToolDescription = "\
Documentation lookup for Wolfram Language. WL has 6000+ functions with non-obvious naming \[LongDash] \
its API surface is wide and often surprising. Use this tool to:
- Find full documentation, options, and calling forms for a function you're about to use.
- Verify a function's documented behavior when code isn't behaving as expected.
- Discover what built-in functions exist for a given goal, or look up the right symbol when you don't know its name.

Argument is a natural-language description, not a search query.";

$documentationPromptHeader = "\
IMPORTANT: Here are some Wolfram documentation snippets that you should use to respond:\n\n";

$snippetTemplate = StringTemplate[ "<result url='`URI`'>\n\n`Text`\n\n</result>" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Definitions*)

(* Add to $defaultMCPTools Association (initialized in Kernel/Tools/Tools.wl) *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WolframContext*)
$defaultMCPTools[ "WolframContext" ] := LLMTool @ <|
    "Name"           -> "WolframContext",
    "DisplayName"    -> "Wolfram Context",
    "Description"    -> $wolframContextToolDescription,
    "Function"       -> relatedWolframContext,
    "LLMKit"         -> "Suggested",
    "Initialization" :> initializeVectorDatabases[ ],
    "Options"        -> { },
    "Parameters"     -> {
        "context" -> <|
            "Interpreter" -> "String",
            "Help"        -> "A detailed summary of what the user is trying to achieve or learn about.",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Default Tool Options*)
$defaultToolOptions[ "WolframContext" ] = <|
    "WolframLanguageMaxItems" -> 10,
    "WolframAlphaMaxItems"    -> Automatic
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WolframAlphaContext*)
$defaultMCPTools[ "WolframAlphaContext" ] := LLMTool @ <|
    "Name"           -> "WolframAlphaContext",
    "DisplayName"    -> "Wolfram|Alpha Context",
    "Description"    -> $waContextToolDescription,
    "Function"       -> relatedWolframAlphaPrompt,
    "LLMKit"         -> "Required",
    "Initialization" :> initializeVectorDatabases[ ],
    "Options"        -> { },
    "Parameters"     -> {
        "context" -> <|
            "Interpreter" -> "String",
            "Help"        -> "A detailed summary of what the user is trying to achieve or learn about.",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Default Tool Options*)
$defaultToolOptions[ "WolframAlphaContext" ] = <|
    "MaxItems"                      -> Automatic,
    "IncludeWolframLanguageResults" -> Automatic
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WolframLanguageContext*)
$defaultMCPTools[ "WolframLanguageContext" ] := LLMTool @ <|
    "Name"           -> "WolframLanguageContext",
    "DisplayName"    -> "Wolfram Language Context",
    "Description"    -> $wlContextToolDescription,
    "Function"       -> relatedDocumentation,
    "LLMKit"         -> "Suggested",
    "Initialization" :> initializeVectorDatabases[ ],
    "Options"        -> { },
    "Parameters"     -> {
        "context" -> <|
            "Interpreter" -> "String",
            "Help"        -> "A detailed summary of what the user is trying to achieve or learn about.",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Default Tool Options*)
$defaultToolOptions[ "WolframLanguageContext" ] = <|
    "MaxItems" -> 10
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toMaxItems*)
toMaxItems // beginDefinition;
toMaxItems[ max_Integer? Positive ] := max;
toMaxItems[ other_ ] := Automatic;
toMaxItems // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedWolframContext*)
relatedWolframContext // beginDefinition;

relatedWolframContext[ KeyValuePattern[ "context" -> context_ ] ] :=
    relatedWolframContext @ context;

relatedWolframContext[ context_String ] := Enclose[
    Module[ { wlMaxItems, waMaxItems, waPrompt, wlPrompt, combined },

        wlMaxItems = ConfirmMatch[ toMaxItems @ $wcMaxItemsWL, $$maxItemsSpec, "WolframLanguageMaxItems" ];
        waMaxItems = ConfirmMatch[ toMaxItems @ $wcMaxItemsWA, $$maxItemsSpec, "WolframAlphaMaxItems" ];

        waPrompt = ConfirmBy[
            Block[ { $waMaxItems = waMaxItems, $waIncludeWLResults = True },
                relatedWolframAlphaPrompt[ context, "Warning", llmKitSubscribedQ[ ] ]
            ],
            StringQ,
            "WolframAlphaPrompt"
        ];

        wlPrompt = ConfirmBy[
            Block[ { $wlMaxItems = wlMaxItems }, relatedDocumentation @ context ],
            StringQ,
            "WolframLanguagePrompt"
        ];

        combined = ConfirmBy[
            StringRiffle[ DeleteCases[ StringTrim @ { waPrompt, wlPrompt }, "" ], "\n\n======\n\n" ],
            StringQ,
            "Combined"
        ];

        (* Extract any WolframAlpha images from the combined result *)
        extractWolframAlphaImages @ combined
    ],
    throwInternalFailure
];

relatedWolframContext // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedWolframAlphaPrompt*)
relatedWolframAlphaPrompt // beginDefinition;

relatedWolframAlphaPrompt[ KeyValuePattern[ "context" -> context_ ] ] :=
    relatedWolframAlphaPrompt @ context;

relatedWolframAlphaPrompt[ context_ ] :=
    relatedWolframAlphaPrompt[ context, "Error" ];

relatedWolframAlphaPrompt[ context_, level_ ] :=
    relatedWolframAlphaPrompt[ context, level, llmKitSubscribedQ[ ] ];

(* When subscribed and called as a tool (not internally), extract images *)
relatedWolframAlphaPrompt[ context_, "Error", True ] :=
    extractWolframAlphaImages @ relatedWolframAlphaResults @ context;

(* When called internally (e.g., from relatedWolframContext), return plain string *)
relatedWolframAlphaPrompt[ context_, level_, True ] :=
    relatedWolframAlphaResults @ context;

relatedWolframAlphaPrompt[ context_, level_, False ] := Enclose[
    Module[ { info, url, connected, template },
        info      = ConfirmBy[ getLLMKitInfo[ ], AssociationQ, "LLMKitInfo" ];
        url       = ConfirmBy[ info[ "buyNowUrl" ], StringQ, "BuyNowURL" ];
        connected = ConfirmBy[ info[ "connected" ], BooleanQ, "Connected" ];
        template  = If[ connected, $wolframAlphaMissingLLMKitTemplate, $wolframAlphaNoCloudTemplate ];
        ConfirmBy[ TemplateApply[ template, <| "URL" -> url, "Level" -> level |> ], StringQ, "Result" ]
    ],
    throwInternalFailure
];

relatedWolframAlphaPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*relatedWolframAlphaResults*)
relatedWolframAlphaResults // beginDefinition;

relatedWolframAlphaResults[ KeyValuePattern[ "context" -> context_ ] ] :=
    relatedWolframAlphaResults @ context;

relatedWolframAlphaResults[ context_String ] := Enclose[
    Module[ { maxItems, includeWLResults, prompt },

        ConfirmMatch[ chatbookVersionCheck[ ], True, "ChatbookVersionCheck" ];

        maxItems = ConfirmMatch[ toMaxItems @ $waMaxItems, $$maxItemsSpec, "WolframAlphaMaxItems" ];
        includeWLResults = Replace[ $waIncludeWLResults, Except[ True|False ] :> Automatic ];

        prompt = ConfirmBy[
            Quiet[
                cb`RelatedWolframAlphaResults[
                    context,
                    "Prompt",
                    "MaxItems"         -> maxItems,
                    "IncludeWLResults" -> includeWLResults
                ],
                { WolframAlpha::kbserr }
            ],
            StringQ,
            "Prompt"
        ];

        StringTrim @ prompt
    ],
    throwInternalFailure
];

relatedWolframAlphaResults // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedDocumentation*)
relatedDocumentation // beginDefinition;

relatedDocumentation[ KeyValuePattern[ "context" -> context_ ] ] :=
    relatedDocumentation @ context;

relatedDocumentation[ context_String ] := Enclose[
    Module[ { prompt, formatted },

        ConfirmMatch[ chatbookVersionCheck[ ], True, "ChatbookVersionCheck" ];

        prompt = ConfirmBy[ relatedDocumentation0 @ context, StringQ, "Prompt" ];

        formatted = If[ StringTrim @ prompt === "",
                        "",
                        $documentationPromptHeader <> formatDocumentationSnippets @ prompt
                    ];

        ConfirmBy[ formatted, StringQ, "Result" ]
    ],
    throwInternalFailure
];

relatedDocumentation // endDefinition;


relatedDocumentation0 // beginDefinition;

relatedDocumentation0[ context_ ] :=
    relatedDocumentation0[ context, toMaxItems @ $wlMaxItems ];

relatedDocumentation0[ context_, max: $$maxItemsSpec ] :=
    relatedDocumentation0[ context, max, llmKitSubscribedQ[ ] ];

relatedDocumentation0[ context_, max: $$maxItemsSpec, subscribed: True|False ] :=
    Block[ { $EvaluationEnvironment = "Script" },
        cb`RelatedDocumentation[
            context,
            "Prompt",
            "PromptHeader"  -> False,
            "FilterResults" -> subscribed,
            "FilteredCount" -> max, (* Ignored when "FilterResults" is False *)
            MaxItems        -> If[ subscribed && IntegerQ @ max, max * 5, max ]
        ]
    ];

relatedDocumentation0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatDocumentationSnippets*)
formatDocumentationSnippets // beginDefinition;

formatDocumentationSnippets[ s_String ] := Enclose[
    Module[ { string },
        string = ConfirmBy[
            If[ StringContainsQ[ s, "\n\n======\n\n" ],
                formatDocumentationSnippets @ StringSplit[ s, "\n======\n" ],
                s
            ],
            StringQ,
            "String"
        ];

        StringReplace[
            string,
            {
                Shortest[ "\\!\\(\\*MarkdownImageBox[\"![" ~~ label: Except[ "]" ]... ~~ "](" ~~ __ ~~ ")\"]\\)" ] :>
                    "Image[...]",

                Shortest[ "[" ~~ label: Except[ "]" ]... ~~ "](paclet:" ~~ uri: Except[ ")" ].. ~~ ")" ] :>
                    "["<>label<>"](https://reference.wolfram.com/language/"<>uri<>")"
            }
        ]
    ],
    throwInternalFailure
];

formatDocumentationSnippets[ snippets: { __String } ] := Enclose[
	StringRiffle[
        ConfirmMatch[ toSnippetString /@ snippets, { __String }, "SnippetStrings" ],
        "\n\n"
    ],
    throwInternalFailure
];

formatDocumentationSnippets // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toSnippetString*)
toSnippetString // beginDefinition;

toSnippetString[ snippet_String ] :=
    toSnippetString @ StringSplit[ StringTrim @ snippet, s: "\n".. :> s ];

toSnippetString[ { header_, "\n", uri0_String, rest___String } ] /; StringContainsQ[ uri0, ":" ] := Enclose[
    Module[ { uri, text },
        uri  = ConfirmBy[ toDocumentationURL @ uri0, StringQ, "URI" ];
        text = ConfirmBy[ header <> "\n\n" <> StringTrim @ StringJoin @ rest, StringQ, "Text" ];
        ConfirmBy[ TemplateApply[ $snippetTemplate, <| "URI" -> uri, "Text" -> text |> ], StringQ, "Result" ]
    ],
    throwInternalFailure
];

toSnippetString[ { other__String } ] :=
    StringTrim @ StringJoin @ other;

toSnippetString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toDocumentationURL*)
toDocumentationURL // beginDefinition;

toDocumentationURL[ uri_String ] := StringReplace[
    uri,
    StartOfString~~"paclet:" -> "https://reference.wolfram.com/language/"
];

toDocumentationURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];