(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Tools`SymbolDefinition`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];
Needs[ "Wolfram`AgentTools`Tools`"  ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$defaultMaxLength         = 10000;
$readableFormTimeout      = 5;
$kernelFunctionString     = "<kernel function>";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Resource Functions*)
importResourceFunction[ readableForm, "ReadableForm" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompts*)
$symbolDefinitionToolDescription = "\
Retrieves the definitions of one or more Wolfram Language symbols and returns them in a readable markdown format.
The tool generates clean, formatted definition strings by intelligently managing the context path to minimize \
fully qualified symbol names.

Use fully qualified symbol names (e.g., System`Plus, Wolfram`AgentTools`CreateMCPServer) if the context is known.
Multiple symbols can be requested by separating them with commas.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Definition*)
(* Add to $defaultMCPTools Association (initialized in Kernel/Tools/Tools.wl) *)
$defaultMCPTools[ "SymbolDefinition" ] := LLMTool @ <|
    "Name"        -> "SymbolDefinition",
    "DisplayName" -> "Symbol Definition",
    "Description" -> $symbolDefinitionToolDescription,
    "Function"    -> getSymbolDefinition,
    "Options"     -> { },
    "Parameters"  -> {
        "symbols" -> <|
            "Interpreter" -> "String",
            "Help"        -> "The symbol name (or multiple names, comma separated).",
            "Required"    -> True
        |>,
        "includeContextDetails" -> <|
            "Interpreter" -> "Boolean",
            "Help"        -> "Whether to include a JSON map showing which symbols belong to which contexts (default: false).",
            "Required"    -> False
        |>,
        "maxLength" -> <|
            "Interpreter" -> "Integer",
            "Help"        -> "Maximum character length for output before truncation (default: 10000).",
            "Required"    -> False
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Main Entry Point*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getSymbolDefinition*)
getSymbolDefinition // beginDefinition;
getSymbolDefinition[ args_ ] := useEvaluatorKernel @ getSymbolDefinition0 @ args;
getSymbolDefinition // endDefinition;


getSymbolDefinition0 // beginDefinition;

getSymbolDefinition0[ KeyValuePattern @ {
    "symbols"               -> symbols_String,
    "includeContextDetails" -> includeContextDetails0_,
    "maxLength"             -> maxLength0_
} ] := Enclose[
    Module[ { includeContextDetails, maxLength, symbolNames, results, contextMap, contextSection, output },
        (* Handle Missing["NoInput"] for optional parameters *)
        includeContextDetails = Replace[ includeContextDetails0, Except[ True | False ] -> False ];
        maxLength             = Replace[ maxLength0, Except[ _Integer ] -> $defaultMaxLength ];

        symbolNames = ConfirmMatch[ parseSymbolNames @ symbols, { __String }, "ParseSymbolNames" ];
        results     = processSymbol[ #, maxLength ] & /@ symbolNames;

        contextMap = If[ TrueQ @ includeContextDetails,
            generateContextMap @ Flatten[ #contextSymbols & /@ Select[ results, AssociationQ ] ],
            None
        ];

        contextSection = If[ contextMap =!= None && contextMap =!= "",
            "\n## Contexts\n\n```json\n" <> contextMap <> "\n```\n",
            ""
        ];

        output = StringRiffle[ #output & /@ results, "\n\n" ] <> contextSection;
        StringTrim @ output
    ],
    throwInternalFailure
];

getSymbolDefinition0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Input Parsing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parseSymbolNames*)
parseSymbolNames // beginDefinition;
parseSymbolNames[ input_String ] := StringTrim /@ StringSplit[ input, "," ];
parseSymbolNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Symbol Processing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*processSymbol*)
processSymbol // beginDefinition;

processSymbol[ name_String, maxLength_Integer ] := Enclose[
    Catch @ Module[ { valid, exists, shortName, locked, readProtected, definition, kernelDefs, allDefs, formatted, contextSymbols },

        (* Validate symbol name *)
        valid = validateSymbolName @ name;
        If[ ! valid,
            Throw @ <|
                "output" -> formatError[ name, "Invalid symbol name \"" <> name <> "\"" ],
                "contextSymbols" -> { }
            |>
        ];

        (* Check if symbol exists *)
        exists = symbolExistsQ @ name;
        If[ ! exists,
            Throw @ <|
                "output" -> formatError[ name, formatNotFoundMessage[ name ] ],
                "contextSymbols" -> { }
            |>
        ];

        shortName = Last @ StringSplit[ name, "`" ];

        (* Check for Locked + ReadProtected *)
        locked = isLockedQ @ name;
        readProtected = isReadProtectedQ @ name;

        If[ locked && readProtected,
            Throw @ <|
                "output" -> formatError[ name, shortName <> " is `Locked` and `ReadProtected`" ],
                "contextSymbols" -> { }
            |>
        ];

        (* Extract definition *)
        definition = extractDefinition @ name;
        kernelDefs = getKernelCodeDefinitions @ name;
        allDefs    = Join[ definition, kernelDefs ];

        If[ allDefs === { } || allDefs === { Null },
            Throw @ <|
                "output" -> "# " <> shortName <> "\n\nNo definitions found",
                "contextSymbols" -> { }
            |>
        ];

        (* Format the definition *)
        { formatted, contextSymbols } = formatDefinition[ name, allDefs, maxLength ];

        <|
            "output" -> "# " <> shortName <> "\n\n## Definition\n\n```wl\n" <> formatted <> "\n```",
            "contextSymbols" -> contextSymbols
        |>
    ],
    throwInternalFailure
];

processSymbol // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Symbol Validation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validateSymbolName*)
validateSymbolName // beginDefinition;
validateSymbolName[ name_String ] := Internal`SymbolNameQ[ name, True ];
validateSymbolName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*symbolExistsQ*)
symbolExistsQ // beginDefinition;

(* Names works for both qualified and unqualified symbol names,
   using $ContextPath for unqualified names *)
symbolExistsQ[ name_String ] := Names[ name ] =!= { };

symbolExistsQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*findSuggestions*)
findSuggestions // beginDefinition;

findSuggestions[ name_String ] := Module[ { baseName, matches, qualified },
    baseName  = Last @ StringSplit[ name, "`" ];
    matches   = Names[ "*`" <> baseName ];
    (* Names may return short names for symbols on $ContextPath, so qualify them *)
    qualified = qualifyName /@ matches;
    (* Limit to 5 suggestions *)
    Take[ DeleteDuplicates @ qualified, UpTo[ 5 ] ]
];

(* Helper to ensure names are fully qualified *)
qualifyName[ name_String ] /; StringContainsQ[ name, "`" ] := name;
qualifyName[ name_String ] := Context[ name ] <> name;

findSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*splitSymbolName*)
splitSymbolName // beginDefinition;

splitSymbolName[ name_String ] := Module[ { parts },
    parts = StringSplit[ name, "`" ];
    If[ Length @ parts === 1,
        { "Global`", First @ parts },
        { StringRiffle[ Most @ parts, "`" ] <> "`", Last @ parts }
    ]
];

splitSymbolName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attribute Checking*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*isLockedQ*)
isLockedQ // beginDefinition;
isLockedQ[ name_String ] := MemberQ[ Attributes @ name, Locked ];
isLockedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*isReadProtectedQ*)
isReadProtectedQ // beginDefinition;
isReadProtectedQ[ name_String ] := MemberQ[ Attributes @ name, ReadProtected ];
isReadProtectedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definition Extraction*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractDefinition*)
extractDefinition // beginDefinition;

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::VariableError::Block:: *)
extractDefinition[ name_String ] := Catch @ Module[ { sym, defString, held },
    sym = ToExpression[ name, InputForm, HoldComplete ];
    If[ ! MatchQ[ sym, HoldComplete[ _Symbol ] ],
        Throw @ { }
    ];

    defString = Replace[
        sym,
        HoldComplete[ s_Symbol ] :>
            Internal`InheritedBlock[ { s },
                ClearAttributes[ s, ReadProtected ];
                ToString[ Definition @ s, InputForm ]
            ]
    ];

    If[ defString === "Null" || defString === "",
        { },
        held = Quiet @ ToExpression[ defString, InputForm, HoldComplete ];
        If[ MatchQ[ held, HoldComplete[ ___ ] ],
            (* Extract elements without evaluation by wrapping each in HoldForm *)
            DeleteCases[
                Replace[ held, HoldComplete[ args___ ] :> (HoldForm /@ Unevaluated @ { args }) ],
                HoldForm[ Null ]
            ],
            { }
        ]
    ]
];
(* :!CodeAnalysis::EndBlock:: *)

extractDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Kernel Code Detection*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getKernelCodeDefinitions*)
getKernelCodeDefinitions // beginDefinition;

getKernelCodeDefinitions[ name_String ] := Catch @ Module[ { sym, defs },
    sym = ToExpression[ name, InputForm, HoldComplete ];
    If[ ! MatchQ[ sym, HoldComplete[ _Symbol ] ],
        Throw @ { }
    ];

    defs = { };

    Replace[
        sym,
        HoldComplete[ s_Symbol ] :> With[ { kf = $kernelFunctionString },
            If[ TrueQ @ System`Private`HasDownCodeQ @ s,
                AppendTo[ defs, HoldForm[ s[___] := kf ] ]
            ];
            (* HasOwnCodeQ lacks HoldAllComplete, so use Unevaluated to prevent evaluation *)
            If[ TrueQ @ System`Private`HasOwnCodeQ @ Unevaluated @ s,
                AppendTo[ defs, HoldForm[ s := kf ] ]
            ];
            If[ TrueQ @ System`Private`HasSubCodeQ @ s,
                AppendTo[ defs, HoldForm[ s[___][___] := kf ] ]
            ];
            If[ TrueQ @ System`Private`HasUpCodeQ @ s,
                AppendTo[ defs, HoldForm[ _[___, s, ___] := kf ] ]
            ];
            If[ TrueQ @ System`Private`HasPrintCodeQ @ s,
                AppendTo[ defs, HoldForm[ Format[s, _] := kf ] ]
            ];
        ]
    ];

    defs
];

getKernelCodeDefinitions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Context Analysis*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractSymbolsFromDefinition*)
extractSymbolsFromDefinition // beginDefinition;

extractSymbolsFromDefinition[ defs_List ] := Module[ { symbols },
    symbols = Cases[
        defs,
        s_Symbol /; AtomQ @ Unevaluated @ s :> HoldForm @ s,
        { 0, Infinity },
        Heads -> True
    ];
    DeleteDuplicates @ symbols
];

extractSymbolsFromDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getContextsFromSymbols*)
getContextsFromSymbols // beginDefinition;

getContextsFromSymbols[ symbols: { ___HoldForm } ] :=
    DeleteDuplicates @ Cases[
        symbols,
        HoldForm[ s_Symbol ] :> Context @ Unevaluated @ s
    ];

getContextsFromSymbols // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*buildOptimalContextPath*)
buildOptimalContextPath // beginDefinition;

buildOptimalContextPath[ contexts_List ] :=
    Reverse @ DeleteDuplicates @ Join[ { "Global`", "System`" }, contexts ];

buildOptimalContextPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateContextMap*)
generateContextMap // beginDefinition;

generateContextMap[ symbols: { ___HoldForm } ] := Catch @ Module[ { grouped, jsonParts },
    If[ symbols === { }, Throw @ "" ];

    grouped = GroupBy[
        symbols,
        (Replace[ #, HoldForm[ s_Symbol ] :> Context @ Unevaluated @ s ] &),
        (Replace[ #, HoldForm[ s_Symbol ] :> SymbolName @ Unevaluated @ s, { 1 } ] &)
    ];

    jsonParts = KeyValueMap[
        Function[ { ctx, names },
            "  \"" <> ctx <> "\": [" <> StringRiffle[ ("\"" <> # <> "\"") & /@ Sort @ DeleteDuplicates @ names, ", " ] <> "]"
        ],
        grouped
    ];

    "{\n" <> StringRiffle[ jsonParts, ",\n" ] <> "\n}"
];

generateContextMap // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatDefinition*)
formatDefinition // beginDefinition;

formatDefinition[ name_String, defs_List, maxLength_Integer ] := Module[
    { symbols, contexts, cPath, symbolContext, formatted, truncated },

    symbols       = extractSymbolsFromDefinition @ defs;
    contexts      = getContextsFromSymbols @ symbols;
    cPath         = buildOptimalContextPath @ contexts;
    symbolContext = First @ splitSymbolName @ name;

    formatted = formatDefinitionReadable[ defs, cPath, symbolContext ];

    If[ formatted === $TimedOut || ! StringQ @ formatted,
        formatted = formatDefinitionFallback[ defs, cPath, symbolContext ]
    ];

    truncated = truncateIfNeeded[ formatted, maxLength ];
    { truncated, symbols }
];

formatDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatDefinitionReadable*)
formatDefinitionReadable // beginDefinition;

formatDefinitionReadable[ defs_List, cPath_List, symbolContext_String ] :=
    If[ resourceFunctionAvailableQ @ readableForm,
        TimeConstrained[
            Block[ { $ContextPath = cPath, $Context = symbolContext },
                StringRiffle[
                    formatSingleDefinition /@ defs,
                    "\n\n"
                ]
            ],
            $readableFormTimeout
        ],
        (* The ReadableForm resource function could not be imported (see importResourceFunction), so formatDefinition
           falls back to InputForm *)
        $Failed
    ];

formatDefinitionReadable // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatSingleDefinition*)
formatSingleDefinition // beginDefinition;

formatSingleDefinition[ HoldForm[ expr_ ] ] :=
    ToString[ readableForm @ Unevaluated @ expr, CharacterEncoding -> "UTF-8" ];

formatSingleDefinition[ expr_ ] :=
    ToString[ readableForm @ Unevaluated @ expr, CharacterEncoding -> "UTF-8" ];

formatSingleDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatDefinitionFallback*)
formatDefinitionFallback // beginDefinition;

formatDefinitionFallback[ defs_List, cPath_List, symbolContext_String ] :=
    Block[ { $ContextPath = cPath, $Context = symbolContext },
        StringRiffle[
            (ToString[ #, InputForm ] &) /@ defs,
            "\n\n"
        ]
    ];

formatDefinitionFallback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Truncation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*truncateIfNeeded*)
truncateIfNeeded // beginDefinition;

truncateIfNeeded[ str_String, maxLength_Integer ] /; StringLength @ str <= maxLength := str;

truncateIfNeeded[ str_String, maxLength_Integer ] := Module[ { total },
    total = StringLength @ str;
    StringTake[ str, maxLength ] <> "\n... [truncated, showing " <> ToString @ maxLength <> "/" <> ToString @ total <> " characters]"
];

truncateIfNeeded // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Error Formatting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatError*)
formatError // beginDefinition;

formatError[ name_String, message_String ] := Module[ { shortName },
    shortName = Last @ StringSplit[ name, "`" ];
    "# " <> shortName <> "\n\nError: " <> message
];

formatError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatNotFoundMessage*)
formatNotFoundMessage // beginDefinition;

formatNotFoundMessage[ name_String ] := Module[ { baseMessage, suggestions, suggestionBlock },
    baseMessage = "Symbol \"" <> name <> "\" does not exist";
    suggestions = findSuggestions @ name;
    If[ suggestions === { },
        baseMessage,
        suggestionBlock = "```wl\n" <> StringRiffle[ suggestions, "\n" ] <> "\n```";
        baseMessage <> "\n\nDid you mean one of the following symbols?\n" <> suggestionBlock
    ]
];

formatNotFoundMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
