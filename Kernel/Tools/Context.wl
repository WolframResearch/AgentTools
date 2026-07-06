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
Uses semantic search to retrieve any relevant information from Wolfram. Always use this tool at the start of \
new conversations or if the topic changes to ensure you have up-to-date relevant information. This uses semantic \
search, so the context argument should be written in natural language (not a search query) and contain as much detail \
as possible (up to 250 words).";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WolframAlphaContext*)
$waContextToolDescription = "\
Uses semantic search to retrieve any relevant information from Wolfram Alpha. Always use this tool at the start of \
new conversations or if the topic changes to ensure you have up-to-date relevant information. This uses semantic \
search, so the context argument should be written in natural language (not a search query) and contain as much detail \
as possible (up to 250 words).";

$wolframAlphaMissingLLMKitTemplate = StringTemplate[ "\
`Level`: Unable to generate Wolfram|Alpha context due to missing LLMKit subscription. \
Inform the user that they can subscribe at the following URL in order to improve the quality of the results: `URL`" ];

$wolframAlphaNoCloudTemplate = StringTemplate[ "\
`Level`: Unable to generate Wolfram|Alpha context due to missing cloud connection." ];

$wolframAlphaUsageLimitTemplate = StringTemplate[ "\
`Level`: Unable to generate Wolfram|Alpha context because the LLMKit usage limit has been exceeded. \
Inform the user that they have exceeded their LLMKit usage limit. \
The service returned the following message: `Message`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WolframLanguageContext*)
$wlContextToolDescription = "\
Uses semantic search to retrieve information from various sources that can be used to help write Wolfram Language \
code. Always use this tool at the start of new conversations or if the topic changes to ensure you have up-to-date \
relevant information. This uses semantic search, so the context argument should be written in natural language \
(not a search query) and contain as much detail as possible.";

$documentationPromptHeader = "\
IMPORTANT: Here are some Wolfram documentation snippets that you should use to respond:\n\n";

$snippetTemplate = StringTemplate[ "<result url='`URI`'>\n\n`Text`\n\n</result>" ];

$documentationUsageLimitTemplate = StringTemplate[ "\
Unable to retrieve relevant Wolfram Language documentation because the LLMKit usage limit has been exceeded. \
Inform the user that they have exceeded their LLMKit usage limit. \
The service returned the following message: `Message`" ];

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
    extractWolframAlphaImages @ relatedWolframAlphaResults[ context, "Error" ];

(* When called internally (e.g., from relatedWolframContext), return plain string *)
relatedWolframAlphaPrompt[ context_, level_, True ] :=
    relatedWolframAlphaResults[ context, level ];

(* LLMKit disabled via "EnableLLMKit" -> False: behave as unsubscribed, but suppress the
   "subscribe to LLMKit" warning entirely -- return an empty string so the combined WolframContext
   tool simply omits the Wolfram|Alpha section instead of nagging about a subscription. *)
relatedWolframAlphaPrompt[ context_, level_, False ] /; ! llmKitEnabledQ[ ] :=
    "";

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

relatedWolframAlphaResults[ context_String ] :=
    relatedWolframAlphaResults[ context, "Error" ];

relatedWolframAlphaResults[ context_String, level_String ] := Enclose[
    Module[ { maxItems, includeWLResults, result },

        ConfirmMatch[ chatbookVersionCheck[ ], True, "ChatbookVersionCheck" ];

        maxItems = ConfirmMatch[ toMaxItems @ $waMaxItems, $$maxItemsSpec, "WolframAlphaMaxItems" ];
        includeWLResults = Replace[ $waIncludeWLResults, Except[ True|False ] :> Automatic ];

        result = Quiet[
            cb`RelatedWolframAlphaResults[
                context,
                "Prompt",
                "MaxItems"         -> maxItems,
                "IncludeWLResults" -> includeWLResults
            ],
            { WolframAlpha::kbserr }
        ];

        (* A user who has exceeded their LLMKit usage limit gets a Failure here; turn it into a useful
           message instead of letting it become an opaque internal failure. *)
        If[ llmKitUsageLimitFailureQ @ result,
            ConfirmBy[
                TemplateApply[
                    $wolframAlphaUsageLimitTemplate,
                    <| "Level" -> level, "Message" -> llmKitUsageLimitMessage @ result |>
                ],
                StringQ,
                "UsageLimitMessage"
            ],
            (* else *)
            StringTrim @ ConfirmBy[ result, StringQ, "Prompt" ]
        ]
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
    Module[ { result, prompt, formatted },

        ConfirmMatch[ chatbookVersionCheck[ ], True, "ChatbookVersionCheck" ];

        result = relatedDocumentation0 @ context;

        (* A user who has exceeded their LLMKit usage limit gets a Failure here; turn it into a useful
           message instead of letting it become an opaque internal failure. *)
        If[ llmKitUsageLimitFailureQ @ result,
            ConfirmBy[
                TemplateApply[
                    $documentationUsageLimitTemplate,
                    <| "Message" -> llmKitUsageLimitMessage @ result |>
                ],
                StringQ,
                "UsageLimitMessage"
            ],
            (* else *)
            prompt = ConfirmBy[ result, StringQ, "Prompt" ];

            formatted = If[ StringTrim @ prompt === "",
                            "",
                            $documentationPromptHeader <> formatDocumentationSnippets @ prompt
                        ];

            ConfirmBy[ formatted, StringQ, "Result" ]
        ]
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