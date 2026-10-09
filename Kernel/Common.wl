(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Symbols defined elsewhere in the paclet*)
Get[ "Wolfram`AgentTools`CommonSymbols`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Messages*)
Get[ "Wolfram`AgentTools`Messages`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Begin Private Context*)
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$cloudNotebooks         := TrueQ @ CloudSystem`$CloudNotebooks;
$mxFlag                 := Wolfram`AgentToolsInternal`$BuildingMX;
$resourceFunctionContext = "Wolfram`AgentTools`ResourceFunctions`";

$internalFailureLogDirectory := FileNameJoin @ { $UserBaseDirectory, "Logs", "AgentTools", "InternalFailures" };

$resourceVersions = <|
    "ASTPattern"              -> "1.0.0",
    "ExportMarkdownString"    -> "1.0.0",
    "ImportMarkdownString"    -> "1.0.0",
    "MessageFailure"          -> "1.0.1",
    "ReadableForm"            -> "2.1.1",
    "ReplaceContext"          -> "1.0.0",
    "ResourceFunctionMessage" -> "2.1.1"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
$debug           = True;
$failed          = False;
$inDef           = False;
$internalFailure = None;
$messageSymbol   = AgentTools;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*optimizeEnclosures*)
optimizeEnclosures // ClearAll;
optimizeEnclosures // Attributes = { HoldFirst };
optimizeEnclosures[ s_Symbol ] := DownValues[ s ] = expandThrowInternalFailures @ optimizeEnclosures0 @ DownValues @ s;

optimizeEnclosures0 // ClearAll;
optimizeEnclosures0[ expr_ ] :=
    ReplaceAll[
        expr,
        HoldPattern[ e: Enclose[ _ ] | Enclose[ _, _ ] ] :>
            With[ { new = addEnclosureTags[ e, $ConditionHold ] },
                RuleCondition[ new, True ]
            ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expandThrowInternalFailures*)
expandThrowInternalFailures // ClearAll;

expandThrowInternalFailures[ expr_ ] :=
    ReplaceAll[
        expr,
        HoldPattern[ Verbatim[ HoldPattern ][ lhs_ ] :> rhs_ ] /;
            ! FreeQ[ HoldComplete @ rhs, HoldPattern @ Enclose[ _, throwInternalFailure, $enclosure ] ] :>
                ReplaceAll[
                    HoldPattern[ e$: lhs ] :> rhs,
                    HoldPattern @ Enclose[ eval_, throwInternalFailure, $enclosure ] :>
                        Module[ { eh = HoldComplete @ e$ }, Enclose[ eval, internalFailureFunction @ eh, $enclosure ] ]
                ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*internalFailureFunction*)
internalFailureFunction // ClearAll;
internalFailureFunction // Attributes = { HoldAllComplete };
internalFailureFunction[ held_ ][ args___ ] := Replace[ held, HoldComplete[ e_ ] :> throwInternalFailure[ e, args ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addEnclosureTags*)
addEnclosureTags // ClearAll;
addEnclosureTags // Attributes = { HoldFirst };

addEnclosureTags[ Enclose[ expr_ ], wrapper_ ] :=
    addEnclosureTags[ Enclose[ expr, #1 & ], wrapper ];

addEnclosureTags[ Enclose[ expr_, func_ ], wrapper_ ] :=
    Module[ { held, replaced },
        held = HoldComplete @ expr;
        replaced = held /. $enclosureTagRules;
        Replace[ replaced, HoldComplete[ e_ ] :> wrapper @ Enclose[ e, func, $enclosure ] ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$enclosureTagRules*)
$enclosureTagRules // ClearAll;
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::NoSurroundingEnclose:: *)
$enclosureTagRules := $enclosureTagRules = Dispatch @ {
    expr_Enclose                                      :> expr,

    HoldPattern @ Confirm[ expr_ ]                    :> Confirm[ expr, Null, $enclosure ],
    HoldPattern @ Confirm[ expr_, info_ ]             :> Confirm[ expr, info, $enclosure ],

    HoldPattern @ ConfirmBy[ expr_, f_ ]              :> ConfirmBy[ expr, f, Null, $enclosure ],
    HoldPattern @ ConfirmBy[ expr_, f_, info_ ]       :> ConfirmBy[ expr, f, info, $enclosure ],

    HoldPattern @ ConfirmMatch[ expr_, patt_ ]        :> ConfirmMatch[ expr, patt, Null, $enclosure ],
    HoldPattern @ ConfirmMatch[ expr_, patt_, info_ ] :> ConfirmMatch[ expr, patt, info, $enclosure ],

    HoldPattern @ ConfirmQuiet[ expr_ ]               :> ConfirmQuiet[ expr, All, Null, $enclosure ],
    HoldPattern @ ConfirmQuiet[ expr_, patt_ ]        :> ConfirmQuiet[ expr, patt, Null, $enclosure ],
    HoldPattern @ ConfirmQuiet[ expr_, patt_, info_ ] :> ConfirmQuiet[ expr, patt, info, $enclosure ],

    HoldPattern @ ConfirmAssert[ expr_ ]              :> ConfirmAssert[ expr, Null, $enclosure ],
    HoldPattern @ ConfirmAssert[ expr_, info_ ]       :> ConfirmAssert[ expr, info, $enclosure ]
};
(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*beginDefinition*)
beginDefinition // ClearAll;
beginDefinition // Attributes = { HoldFirst };
beginDefinition::Unfinished =
"Starting definition for `1` without ending the current one.";

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
beginDefinition[ s_Symbol ] /; $debug && $inDef :=
    WithCleanup[
        $inDef = False
        ,
        Print @ TemplateApply[ beginDefinition::Unfinished, HoldForm @ s ];
        beginDefinition @ s
        ,
        $inDef = True
    ];
(* :!CodeAnalysis::EndBlock:: *)

beginDefinition[ s_Symbol ] := WithCleanup[ Unprotect @ s; ClearAll @ s, $inDef = True ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendFallthroughError*)
appendFallthroughError // ClearAll;
appendFallthroughError // Attributes = { HoldFirst };

appendFallthroughError[ s_Symbol, values: DownValues|UpValues ] :=
    Module[ { block = Internal`InheritedBlock, before, after },
        block[ { s },
            before = values @ s;
            appendFallthroughError0[ s, values ];
            after = values @ s;
        ];

        If[ TrueQ[ Length @ after > Length @ before ],
            values[ s ] = after,
            values[ s ]
        ]
    ];

appendFallthroughError0 // ClearAll;

appendFallthroughError0[ s_Symbol, OwnValues ] :=
    e: HoldPattern @ s :=
        throwInternalFailure[ e, "UnhandledOwnValues", HoldForm @ s ];

appendFallthroughError0[ s_Symbol, DownValues ] :=
    e: HoldPattern @ s[ ___ ] :=
        throwInternalFailure[ e, "UnhandledDownValues", HoldForm @ s ];

appendFallthroughError0[ s_Symbol, UpValues ] :=
    e: HoldPattern @ s[ ___ ][ ___ ] :=
        throwInternalFailure[ e, "UnhandledUpValues", HoldForm @ s ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendExportedFallthroughError*)
appendExportedFallthroughError // ClearAll;
appendExportedFallthroughError // Attributes = { HoldFirst };

appendExportedFallthroughError[ s_Symbol ] :=
    Module[ { block = Internal`InheritedBlock, before, after },
        block[ { s },
            before = DownValues @ s;
            appendExportedFallthroughError0 @ s;
            after = DownValues @ s;
        ];

        If[ TrueQ[ Length @ after > Length @ before ],
            DownValues[ s ] = after,
            DownValues[ s ]
        ]
    ];

appendExportedFallthroughError0 // ClearAll;
appendExportedFallthroughError0[ f_Symbol ] := f[ a___ ] :=
    catchTop[ throwFailure[ "InvalidArguments", f, HoldForm @ f @ a ], f ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*endDefinition*)
endDefinition // beginDefinition;
endDefinition // Attributes = { HoldFirst };

endDefinition[ s_Symbol ] := endDefinition[ s, DownValues ];

endDefinition[ s_Symbol, None ] := $inDef = False;

endDefinition[ s_Symbol, values: DownValues|UpValues ] :=
    WithCleanup[
        optimizeEnclosures @ s;
        appendFallthroughError[ s, values ],
        $inDef = False
    ];

endDefinition[ s_Symbol, list_List ] := (endDefinition[ s, #1 ] &) /@ list;

endDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*endExportedDefinition*)
endExportedDefinition // beginDefinition;
endExportedDefinition // Attributes = { HoldFirst };

endExportedDefinition[ s_Symbol ] :=
    WithCleanup[
        optimizeEnclosures @ s;
        appendExportedFallthroughError @ s,
        $inDef = False
    ];

endExportedDefinition // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Resource Functions*)
(* The paclet uses a few functions from the Wolfram Function Repository, pinned to the versions in $resourceVersions.
   Each is imported with importResourceFunction, which takes the definition from a local copy in the paclet's
   ResourceFunctions directory when there is one (see ResourceFunctions/README.md) and only otherwise fetches the
   resource function, so neither building the paclet nor loading it from source requires cloud access.

   When building the MX file, the definitions are inlined into the paclet in the context
   $resourceFunctionContext<>name<>"`", so the built paclet never touches the Function Repository. When loading from
   source, the import is resolved at the first use of the imported symbol and memoized only on success: a resource
   function that is not available (no local copy and no cloud access) yields a resourceFunctionUnavailable placeholder
   whose use fails with AgentTools::ResourceFunctionUnavailable, and the next use tries again. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$localResourceFunctionDirectory*)
(* Determined from this file's location at load time, like $thisPaclet, since the directory is not part of the built
   paclet. During an MX build this is the temporary copy of the paclet, which BuildMX.wls copies the directory into. *)
$localResourceFunctionDirectory = FileNameJoin @ { DirectoryName[ $InputFileName, 2 ], "ResourceFunctions" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*localResourceFunctionFile*)
localResourceFunctionFile // beginDefinition;

localResourceFunctionFile[ name_String ] :=
    localResourceFunctionFile[ name, $localResourceFunctionDirectory ];

localResourceFunctionFile[ name_String, dir_String ] :=
    With[ { file = FileNameJoin @ { dir, name<>".wl" } },
        If[ FileExistsQ @ file, file, Missing[ "NotFound", name ] ]
    ];

localResourceFunctionFile[ name_String, _ ] :=
    Missing[ "NotFound", name ];

localResourceFunctionFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*importResourceFunction*)
importResourceFunction // beginDefinition;
importResourceFunction::failure = "[ERROR] Failed to import resource function `1`. Aborting MX build.";
importResourceFunction // Attributes = { HoldFirst };

importResourceFunction[ name_String ] :=
    importResourceFunction[ None, name ];

importResourceFunction[ symbol_Symbol, name_String ] :=
    importResourceFunction[ symbol, name, Lookup[ $resourceVersions, name ] ];

(* MX build: inline the definitions into the paclet *)
importResourceFunction[ symbol_Symbol, name_String, version_ ] /; $mxFlag := Enclose[
    Block[ { PrintTemporary },
        Module[ { targetContext, replaced, inlined, newSymbol },

            ConfirmAssert[ StringQ @ version, "Version" ];
            targetContext = $resourceFunctionContext<>name<>"`";

            (* The definitions, in the target context: *)
            replaced = ConfirmMatch[
                resourceFunctionDefinitionList[ name, version, targetContext ],
                _Language`DefinitionList,
                "DefinitionList"
            ];

            inlined = ConfirmMatch[ inlineDependentResourceFunctions @ replaced, _Language`DefinitionList, "Inlined" ];

            $importedResourceFunctions[ name ] = version;
            KeyDropFrom[ $dependentResourceFunctions, Keys @ $importedResourceFunctions ];

            ConfirmMatch[ Language`ExtendedFullDefinition[ ] = inlined, _Language`DefinitionList, "SetDefinition" ];

            newSymbol = ConfirmMatch[ Symbol[ targetContext<>name ], _Symbol? AtomQ, "Symbol" ];

            importResourceFunction[ symbol, name, version ] =
                If[ Unevaluated @ symbol === None,
                    newSymbol,
                    ConfirmMatch[ symbol = newSymbol, newSymbol ]
                ]
        ]
    ],
    (Message[ importResourceFunction::failure, name ]; Abort[ ]) &
];

(* Loading from source: resolve the import at the first use of the symbol, memoizing only on success *)
importResourceFunction[ symbol: Except[ None, _Symbol ], name_String, version_String ] :=
    symbol := resolveResourceFunction[ symbol, name, version ];

(* Loading from source: a resource function that a local definition depends on (see inlineDependentResourceFunctions),
   which then has a local definition itself *)
importResourceFunction[ None, name_String, version_String ] :=
    With[ { file = localResourceFunctionFile @ name },
        loadLocalResourceFunction[ name, file ] /; StringQ @ file
    ];

importResourceFunction // endDefinition;

$importedResourceFunctions = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveResourceFunction*)
resolveResourceFunction // beginDefinition;
resolveResourceFunction // Attributes = { HoldFirst };

resolveResourceFunction[ symbol_Symbol, name_String, version_String ] :=
    Module[ { function },
        function = Block[ { PrintTemporary }, getResourceFunction[ name, version ] ];
        If[ resourceFunctionSymbolQ @ function,
            symbol = function,
            resourceFunctionUnavailable @ name
        ]
    ];

resolveResourceFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceFunctionSymbolQ*)
(* A resolved resource function is a symbol outside System`, since ResourceFunction gives $Failed on failure *)
resourceFunctionSymbolQ // beginDefinition;
resourceFunctionSymbolQ[ s_Symbol ] := Context @ s =!= "System`";
resourceFunctionSymbolQ[ _ ] := False;
resourceFunctionSymbolQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resourceFunctionUnavailable*)
(* Placeholder for an imported resource function that could not be resolved: applying it to arguments fails with a
   message instead of producing a garbled expression. It is never memoized (see resolveResourceFunction). *)
resourceFunctionUnavailable // ClearAll;
resourceFunctionUnavailable[ name_String ][ ___ ] := throwFailure[ "ResourceFunctionUnavailable", name ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resourceFunctionAvailableQ*)
(* Whether an imported resource function symbol (e.g. readableForm) resolved to a usable function *)
resourceFunctionAvailableQ // beginDefinition;
resourceFunctionAvailableQ[ _resourceFunctionUnavailable ] := False;
resourceFunctionAvailableQ[ s_Symbol ] := resourceFunctionSymbolQ @ s;
resourceFunctionAvailableQ[ _ ] := False;
resourceFunctionAvailableQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getResourceFunction*)
(* The function symbol of a resource function: from a local definition if there is one, otherwise from the Function
   Repository (which gives $Failed or Missing when it cannot be reached) *)
getResourceFunction // beginDefinition;

getResourceFunction[ name_String, version_String ] :=
    getResourceFunction[ name, version, localResourceFunctionFile @ name ];

(* A local definition that was already loaded as a dependency of another one is not loaded again *)
getResourceFunction[ name_String, version_String, file_String ] :=
    If[ KeyExistsQ[ $importedResourceFunctions, name ],
        Symbol[ $resourceFunctionContext<>name<>"`"<>name ],
        loadLocalResourceFunction[ name, file ]
    ];

getResourceFunction[ name_String, version_String, _Missing ] :=
    Quiet @ ResourceFunction[ name, "Function", ResourceVersion -> version ];

getResourceFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadLocalResourceFunction*)
(* Loads a local definition into its target context, rewrites its references to other resource functions to their
   local symbols (loading those as well) and returns the function's symbol *)
loadLocalResourceFunction // beginDefinition;

loadLocalResourceFunction[ name_String, file_String ] := Enclose[
    Module[ { targetContext, definition, inlined },
        targetContext = $resourceFunctionContext<>name<>"`";

        definition = ConfirmMatch[
            localResourceFunctionDefinitionList[ name, file, targetContext ],
            _Language`DefinitionList,
            "DefinitionList"
        ];

        inlined = ConfirmMatch[ inlineDependentResourceFunctions @ definition, _Language`DefinitionList, "Inlined" ];

        $importedResourceFunctions[ name ] = Lookup[ $resourceVersions, name, None ];
        KeyDropFrom[ $dependentResourceFunctions, Keys @ $importedResourceFunctions ];

        ConfirmMatch[ Language`ExtendedFullDefinition[ ] = inlined, _Language`DefinitionList, "SetDefinition" ];
        importDependentResourceFunctions[ ];

        ConfirmMatch[ Symbol[ targetContext<>name ], _Symbol? AtomQ, "Symbol" ]
    ],
    throwInternalFailure
];

loadLocalResourceFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resourceFunctionDefinitionList*)
(* The definitions of a resource function as a DefinitionList in the given context: from the local definition if there
   is one, otherwise fetched from the Function Repository *)
resourceFunctionDefinitionList // beginDefinition;

resourceFunctionDefinitionList[ name_String, version_String, targetContext_String ] :=
    resourceFunctionDefinitionList[ name, version, targetContext, localResourceFunctionFile @ name ];

resourceFunctionDefinitionList[ name_String, version_String, targetContext_String, file_String ] :=
    localResourceFunctionDefinitionList[ name, file, targetContext ];

resourceFunctionDefinitionList[ name_String, version_String, targetContext_String, _Missing ] := Enclose[
    Module[ { sourceContext, definition },

        sourceContext = ConfirmBy[ ResourceFunction[ name, "Context", ResourceVersion -> version ], StringQ, "Context" ];
        definition    = ConfirmMatch[ ResourceFunction[ name, "DefinitionList" ], _Language`DefinitionList, "DefinitionList" ];

        ConfirmMatch[
            ResourceFunction[ "ReplaceContext", ResourceVersion -> $resourceVersions[ "ReplaceContext" ] ][
                definition,
                sourceContext -> targetContext
            ],
            _Language`DefinitionList,
            "Replaced"
        ]
    ],
    throwInternalFailure
];

resourceFunctionDefinitionList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*localResourceFunctionDefinitionList*)
(* Loads a local definition file (which wraps the definition in BeginPackage/EndPackage for the target context, so its
   symbols are created there) and collects the definitions of the symbols in that context. The Block keeps the file's
   BeginPackage/EndPackage from leaving the context on the caller's $ContextPath. *)
localResourceFunctionDefinitionList // beginDefinition;

localResourceFunctionDefinitionList[ name_String, file_String, targetContext_String ] := Enclose[
    Module[ { names },

        Block[ { $Context = $Context, $ContextPath = $ContextPath, PrintTemporary },
            ConfirmMatch[ Get @ file, Null, "Get" ]
        ];

        ConfirmAssert[ NameQ[ targetContext<>name ], "Defined" ];
        names = ConfirmMatch[ Join[ Names[ targetContext<>"*" ], Names[ targetContext<>"*`*" ] ], { __String }, "Names" ];

        Language`DefinitionList @@ Select[ symbolDefinitionRule /@ names, definedSymbolRuleQ ]
    ],
    throwInternalFailure
];

localResourceFunctionDefinitionList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*symbolDefinitionRule*)
(* The definition of a symbol in the format of a DefinitionList element *)
symbolDefinitionRule // beginDefinition;
symbolDefinitionRule // Attributes = { HoldAllComplete };

symbolDefinitionRule[ name_String ] :=
    ToExpression[ name, InputForm, symbolDefinitionRule ];

symbolDefinitionRule[ s_Symbol ] := HoldForm[ s ] -> DeleteCases[
    {
        OwnValues     -> OwnValues @ s,
        DownValues    -> DownValues @ s,
        UpValues      -> UpValues @ s,
        SubValues     -> SubValues @ s,
        NValues       -> NValues @ s,
        FormatValues  -> FormatValues @ s,
        DefaultValues -> DefaultValues @ s,
        Messages      -> Messages @ s,
        Attributes    -> Attributes @ s
    },
    _ -> { }
];

symbolDefinitionRule // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*definedSymbolRuleQ*)
(* Symbols without definitions and the Module temporaries that loading leaves behind are not part of the definition *)
definedSymbolRuleQ // beginDefinition;
definedSymbolRuleQ[ HoldForm[ _ ] -> { } ] := False;
definedSymbolRuleQ[ HoldForm[ _ ] -> { ___, Attributes -> { ___, Temporary, ___ }, ___ } ] := False;
definedSymbolRuleQ[ HoldForm[ _ ] -> { __ } ] := True;
definedSymbolRuleQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*importDependentResourceFunctions*)
importDependentResourceFunctions // beginDefinition;

importDependentResourceFunctions[ ] :=
    importDependentResourceFunctions @ Keys @ $dependentResourceFunctions;

importDependentResourceFunctions[ { } ] :=
    Null;

importDependentResourceFunctions[ names: { __String } ] := (
    importResourceFunction /@ names;
    KeyDropFrom[ $dependentResourceFunctions, names ];
    importDependentResourceFunctions @ Keys @ $dependentResourceFunctions
);

importDependentResourceFunctions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inlineDependentResourceFunctions*)
(* Rewrites references to other resource functions in a definition to their local symbols, recording them as
   dependencies to import (see importDependentResourceFunctions) *)
inlineDependentResourceFunctions // beginDefinition;

inlineDependentResourceFunctions[ definition_ ] := ReplaceAll[
    definition,
    {
        HoldPattern @ ResourceFunction[ name_String? inlinableResourceFunctionQ, OptionsPattern[ ] ] :> RuleCondition[
            $dependentResourceFunctions[ name ] = True;
            Symbol[ $resourceFunctionContext<>name<>"`"<>name ]
        ],
        HoldPattern @ ResourceFunction[ name_String? inlinableResourceFunctionQ, "Function", OptionsPattern[ ] ] :> RuleCondition[
            $dependentResourceFunctions[ name ] = True;
            Symbol[ $resourceFunctionContext<>name<>"`"<>name ]
        ]
    }
];

inlineDependentResourceFunctions // endDefinition;

$dependentResourceFunctions = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlinableResourceFunctionQ*)
(* In an MX build every reference is inlined (fetching the dependency if it has no local definition); when loading from
   source only those with a local definition are, leaving the others to the Function Repository at call time *)
inlinableResourceFunctionQ // beginDefinition;
inlinableResourceFunctionQ[ name_String ] := TrueQ @ $mxFlag || StringQ @ localResourceFunctionFile @ name;
inlinableResourceFunctionQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Error Handling*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*catchTopAs*)
catchTopAs // beginDefinition;
catchTopAs[ sym_Symbol ] := Function[ eval, catchTop[ eval, sym ], { HoldAllComplete } ];
catchTopAs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*catchTop*)
catchTop // beginDefinition;
catchTop // Attributes = { HoldFirst };

catchTop[ eval_ ] := catchTop[ eval, AgentTools ];

catchTop[ eval_, sym_Symbol ] :=
    Block[
        {
            $messageSymbol          = Replace[ $messageSymbol, AgentTools -> sym ],
            $catching               = True,
            $failed                 = False,
            catchTop                = # &,
            catchTopAs              = (#1 &) &,
            $internalFailureLogPath = None
        },
        Catch[ eval, $catchTopTag ]
    ];

catchTop // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*catchAlways*)
catchAlways // beginDefinition;
catchAlways // Attributes = { HoldFirst };
catchAlways[ eval_ ] := catchAlways[ eval, AgentTools ];
catchAlways[ eval_, sym_Symbol ] := Catch[ catchTop[ eval, sym ], $catchTopTag ];
catchAlways // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*catchMine*)
catchMine // beginDefinition;
catchMine // Attributes = { HoldFirst };
catchMine /: HoldPattern[ f_Symbol[ args___ ] := catchMine[ rhs_ ] ] := f[ args ] := catchTop[ rhs, f ];
catchMine[ eval_ ] := catchTop @ eval;
catchMine // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*throwTop*)
throwTop // beginDefinition;
throwTop[ expr_ ] := If[ TrueQ @ $catching, Throw[ Unevaluated @ expr, $catchTopTag ], expr ];
throwTop // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*throwFailure*)
throwFailure // beginDefinition;
throwFailure // Attributes = { HoldFirst };

throwFailure[ msg_, args___ ] :=
    With[ { failure = messageFailure[ msg, args ] },
        If[ TrueQ @ $catching,
            Throw[ failure, $catchTopTag ],
            failure
        ]
    ];

throwFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*messageFailure*)
messageFailure // Attributes = { HoldFirst };

messageFailure[ "Internal"|AgentTools::Internal, args___ ] := (
    General::AgentToolsInternal = AgentTools::Internal;
    messageFailure[ General::AgentToolsInternal, args ]
);

messageFailure[ t_String, args___ ] :=
    With[ { s = $messageSymbol },
        If[ StringQ @ MessageName[ s, t ],
            messageFailure[ MessageName[ s, t ], args ],
            If[ StringQ @ MessageName[ AgentTools, t ],
                blockProtected[ { s }, MessageName[ s, t ] = MessageName[ AgentTools, t ] ];
                messageFailure[ MessageName[ s, t ], args ],
                throwInternalFailure @ messageFailure[ t, args ]
            ]
        ]
    ];

messageFailure[ args___ ] :=
    Module[ { quiet, message },
        quiet   = If[ TrueQ @ $failed, Quiet, Identity ];
        message = messageFailure0;
        WithCleanup[
            StackInhibit @ convertCloudFailure @ promoteSourceInfo @ quiet @ message @ args,
            If[ TrueQ @ $catching && ! MatchQ[ Internal`QuietStatus[ ], KeyValuePattern[ "Global" -> "Quiet" ] ],
                $failed = True
            ]
        ]
    ];

(* https://resources.wolframcloud.com/FunctionRepository/resources/MessageFailure *)
importResourceFunction[ messageFailure0, "MessageFailure" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertCloudFailure*)
convertCloudFailure // beginDefinition;

convertCloudFailure[ Failure[
    "AgentTools::Internal",
    as: KeyValuePattern @ { "MessageParameters" :> { Hyperlink[ _, url_ ], params___ } }
] ] /; $CloudEvaluation :=
    Failure[
        "AgentTools::Internal",
        Association[
            as,
            "MessageParameters" -> { "", params },
            "Link"              -> Hyperlink[ "Report this issue \[RightGuillemet]", url ]
        ]
    ];

convertCloudFailure[ failure_ ] :=
    failure;

convertCloudFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*promoteSourceInfo*)
promoteSourceInfo // beginDefinition;

promoteSourceInfo[ Failure[ "General::AgentToolsInternal", as_ ] ] :=
    promoteSourceInfo @ Failure[ "AgentTools::Internal", as ];

promoteSourceInfo[ Failure[
    "AgentTools::Internal",
    as: KeyValuePattern[ "MessageParameters" :> { _, KeyValuePattern[ "Information" -> info_String ] } ]
] ] := Failure[ "AgentTools::Internal", <| as, "Source" -> info |> ];

promoteSourceInfo[ failure_ ] := failure;

promoteSourceInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*messagePrint*)
messagePrint // Attributes = { HoldFirst };
messagePrint[ args___ ] := WithCleanup[ $failed = False, messageFailure @ args, $failed = False ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*blockProtected*)
blockProtected // beginDefinition;
blockProtected // Attributes = { HoldAll };
blockProtected[ { s___Symbol }, eval_ ] := Module[ { p }, WithCleanup[ p = Unprotect @ s, eval, Protect @@ p ] ];
blockProtected[ s_Symbol, eval_ ] := blockProtected[ { s }, eval ];
blockProtected // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*throwInternalFailure*)
throwInternalFailure // beginDefinition;
throwInternalFailure // Attributes = { HoldFirst };

throwInternalFailure[ HoldForm[ eval_ ], a___ ] := throwInternalFailure[ eval, a ];

throwInternalFailure[ eval_, a___ ] :=
    Block[ { $internalFailure = $lastInternalFailure = makeInternalFailureData[ eval, a ] },
        throwFailure[ AgentTools::Internal, $bugReportLink, $internalFailure ]
    ];

throwInternalFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeInternalFailureData*)
makeInternalFailureData // Attributes = { HoldFirst };

makeInternalFailureData[ eval_, Failure[ tag_, as_Association ], args___ ] :=
    StackInhibit @ Module[ { $stack = Stack[ _ ] },
        DeleteMissing @ <|
            "Evaluation"  :> eval,
            KeyTake[ as, $priorityFailureKeys ],
            "Stack"       :> $stack,
            "Failure"     -> Failure[ tag, Association[ KeyDrop[ as, $priorityFailureKeys ], as ] ],
            "Arguments"   -> { args }
        |>
    ];

makeInternalFailureData[ eval_, args___ ] :=
    StackInhibit @ Module[ { $stack = Stack[ _ ] },
        <|
            "Evaluation" :> eval,
            "Stack"      :> $stack,
            "Arguments"  -> { args }
        |>
    ];

$priorityFailureKeys = { "Information", "ConfirmationType", "Expression", "Function", "Pattern", "Test" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Bug Report Link Generation*)

$issuesURL = "https://github.com/WolframResearch/AgentTools/issues/new";

$maxBugReportURLSize = 7000;
(*
    RFC 7230 recommends clients support 8000: https://www.rfc-editor.org/rfc/rfc7230#section-3.1.1
    Long bug report links might not work in old versions of IE,
    but using IE these days should probably be considered user error.
*)

$maxPartLength = 500;

(* This is a temporary setting that's dynamically overwritten at load time in AgentToolsLoader.wl *)
$thisPaclet = PacletObject @ File @ DirectoryName[ $InputFileName, 2 ];

$pacletVersion := $thisPaclet[ "Version" ];
$debugData     := debugData @ $thisPaclet[ "PacletInfo" ];
$releaseID     := $releaseID = getReleaseID @ $thisPaclet;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getReleaseID*)
getReleaseID[ paclet_PacletObject ] :=
    getReleaseID[ paclet, paclet[ "ReleaseID" ] ];

getReleaseID[ paclet_PacletObject, "$RELEASE_ID$" | "None" | Except[ _String ] ] :=
    getReleaseID0 @ paclet[ "Location" ];

getReleaseID[ paclet_, id_String ] := id;


getReleaseID0[ dir_? DirectoryQ ] := FirstCase[
    Unevaluated @ {
        Environment[ "BUILD_VCS_NUMBER_WolframLanguage_Paclets_AgentTools_AgentTools" ],
        Environment[ "GITHUB_SHA" ],
        Quiet @ RunProcess[ { "git", "rev-parse", "HEAD" }, "StandardOutput", ProcessDirectory -> dir ]
    },
    res_ :> With[
        { str1 = res },
        { str2 = If[ StringQ @ str1, StringTrim @ str1, "None" ] },
        str2 /; StringMatchQ[ str2, Repeated[ HexadecimalCharacter, { 40 } ] ]
    ],
    "None"
];

getReleaseID0[ ___ ] := "None";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*debugData*)
debugData // beginDefinition;

debugData[ as_Association? AssociationQ ] := <|
    KeyTake[ as, { "Name", "Version" } ],
    "ReleaseID"             -> $releaseID,
    "EvaluationEnvironment" -> $EvaluationEnvironment,
    "FrontEndVersion"       -> If[ TrueQ @ $Notebooks, $frontEndVersion, "None" ],
    "KernelVersion"         -> SystemInformation[ "Kernel", "Version" ],
    "SystemID"              -> $SystemID,
    "Notebooks"             -> $Notebooks,
    "DynamicEvaluation"     -> $DynamicEvaluation,
    "SynchronousEvaluation" -> $SynchronousEvaluation,
    "TaskEvaluation"        -> MatchQ[ $CurrentTask, _TaskObject ]
|>;

debugData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$bugReportLink*)
$bugReportLink := Hyperlink[
    "Report this issue \[RightGuillemet]",
    trimURL @ URLBuild[ $issuesURL, { "title" -> "Insert Title Here", "labels" -> "bug", "body" -> bugReportBody[ ] } ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*bugReportBody*)
bugReportBody[ ] := bugReportBody @ $thisPaclet[ "PacletInfo" ];

bugReportBody[ as_Association? AssociationQ ] :=
    Module[ { debugData, stack, internalFailure, bugReportText, dir, fileName, filePath, file, data },

        debugData        = $debugData;
        stack            = $bugReportStack;
        internalFailure  = $internalFailure;

        bugReportText = TemplateApply[
            $bugReportBodyTemplate,
            TemplateVerbatim /@ <|
                (* FIXME: This should include information about the current MCP server (if applicable) *)
                "DebugData"       -> associationMarkdown @ debugData,
                "Stack"           -> stack,
                "InternalFailure" -> markdownCodeBlock @ internalFailure,
                "SourceLink"      -> sourceLink @ internalFailure
            |>
        ];

        data = <|
            "ReportText"      -> bugReportText,
            "PacletInfo"      -> as,
            "DebugData"       -> debugData,
            "Stack"           -> stack,
            "InternalFailure" -> internalFailure
        |>;

        (* Log to unique file in InternalFailures subdirectory *)
        dir = $internalFailureLogDirectory;
        If[ ! DirectoryQ @ dir, Quiet @ CreateDirectory[ dir, CreateIntermediateDirectories -> True ] ];
        fileName = generateUniqueFailureFileName[ ];
        filePath = FileNameJoin @ { dir, fileName };

        file = File @ Export[ filePath, data, "MX" ];
        $internalFailureLogPath = If[ FileExistsQ @ filePath, filePath, None ];

        (* Cleanup old logs, keeping only 50 most recent *)
        cleanupOldFailureLogs[ ];

        WithCleanup[
            Unprotect[ $LastAgentToolsFailure, $LastAgentToolsFailureText ]
            ,
            $LastAgentToolsFailure     = file;
            $LastAgentToolsFailureText = bugReportText;
            ,
            Protect[ $LastAgentToolsFailure, $LastAgentToolsFailureText ]
        ];

        bugReportText
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sourceLink*)
sourceLink[ KeyValuePattern[ "Information" -> info_String ] ] := sourceLink @ info;
sourceLink[ info_String ] := sourceLink @ StringSplit[ info, "@@" ];
sourceLink[ { tag_String, source_String } ] := sourceLink @ { tag, StringSplit[ source, ":" ] };
sourceLink[ { tag_String, { file_String, pos_String } } ] := sourceLink @ { tag, file, StringSplit[ pos, "-" ] };

sourceLink[ { tag_String, file_String, { lc1_String, lc2_String } } ] :=
    sourceLink @ { tag, file, StringSplit[ lc1, "," ], StringSplit[ lc2, "," ] };

sourceLink[ { tag_String, file_String, { l1_String, c1_String }, { l2_String, c2_String } } ] :=
    Module[ { id },
        id = Replace[ $releaseID, { "$RELEASE_ID$" | "None" | Except[ _String ] -> "main" } ];
        "\n\nhttps://github.com/WolframResearch/AgentTools/blob/"<>id<>"/"<>file<>"#L"<>l1<>"-L"<>l2
    ];

sourceLink[ ___ ] := "";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractFailureTag*)
extractFailureTag // beginDefinition;

(* Handle AgentTools internal failures *)
extractFailureTag[ Failure[ "AgentTools::Internal", as_Association ] ] :=
    extractFailureTag0[ "AgentTools", as ];

(* Handle Chatbook internal failures *)
extractFailureTag[ Failure[ "General::ChatbookInternal", as_Association ] ] :=
    extractFailureTag0[ "Chatbook", as ];

(* Fallback *)
extractFailureTag[ Failure[ tag_String, _ ] ] := tag;
extractFailureTag[ _ ] := "Unknown";

extractFailureTag // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractFailureTag0*)
extractFailureTag0 // beginDefinition;

extractFailureTag0[ prefix_String, as_Association ] :=
    Module[ { msgParams, innerAs, source, topInfo, info, shortSource, args, symbolName, funcName, confirmType },

        (* Extract nested association from MessageParameters *)
        msgParams = Lookup[ as, "MessageParameters", { } ];
        innerAs = Replace[ msgParams, { { _, inner_Association } :> inner, _ :> <| |> } ];

        (* Get source info - check multiple locations *)
        source = Lookup[ as, "Source", None ];
        topInfo = Lookup[ as, "Information", None ];
        info = Which[
            (* MX failures have Source at top level with full path *)
            StringQ @ source && StringContainsQ[ source, "@@" ],
                source,
            (* Non-MX failures may have Information at top level *)
            StringQ @ topInfo && StringContainsQ[ topInfo, "@@" ],
                topInfo,
            (* Or Information in nested association *)
            True,
                Lookup[ innerAs, "Information", None ]
        ];

        (* Get short source tag (e.g., "Path") for non-MX builds *)
        shortSource = Which[
            StringQ @ source && ! StringContainsQ[ source, "@@" ],
                source,
            StringQ @ topInfo && ! StringContainsQ[ topInfo, "@@" ],
                topInfo,
            StringQ @ info && ! StringContainsQ[ info, "@@" ],
                info,
            True,
                None
        ];

        (* Extract arguments for unhandled down values check *)
        args = Lookup[ innerAs, "Arguments", Lookup[ as, "Arguments", { } ] ];

        (* Check for unhandled down values with symbol name *)
        symbolName = Cases[
            { args },
            { "UnhandledDownValues", HoldForm[ sym_Symbol ] } :>
                SymbolName @ Unevaluated @ sym,
            { 0, Infinity },
            1
        ];

        (* Get function name and confirmation type for additional context *)
        funcName = Replace[
            Lookup[ innerAs, "Function", None ],
            s_Symbol :> SymbolName @ Unevaluated @ s
        ];
        confirmType = Lookup[ innerAs, "ConfirmationType", None ];

        Which[
            (* Unhandled down values case *)
            Length @ symbolName > 0,
                prefix <> "::Internal::UnhandledDownValues::" <> First @ symbolName,

            (* Source location available with full path *)
            StringQ @ info && StringContainsQ[ info, "@@" ],
                prefix <> "::Internal::Path@@" <> Last @ StringSplit[ info, "@@" ],

            (* Confirmation failure with function name and short source *)
            StringQ @ confirmType && StringQ @ funcName && StringQ @ shortSource,
                prefix <> "::Internal::" <> confirmType <> "::" <> funcName <> "::" <> shortSource,

            (* Confirmation failure with function name *)
            StringQ @ confirmType && StringQ @ funcName,
                prefix <> "::Internal::" <> confirmType <> "::" <> funcName,

            (* Just function name available (but not None) with short source *)
            StringQ @ funcName && funcName =!= "None" && StringQ @ shortSource,
                prefix <> "::Internal::Function::" <> funcName <> "::" <> shortSource,

            (* Just function name available (but not None) *)
            StringQ @ funcName && funcName =!= "None",
                prefix <> "::Internal::Function::" <> funcName,

            (* Default *)
            True,
                prefix <> "::Internal"
        ]
    ];

extractFailureTag0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateUniqueFailureFileName*)
generateUniqueFailureFileName // beginDefinition;

generateUniqueFailureFileName[ ] :=
    Module[ { timestamp, uniqueID },
        timestamp = DateString[ { "Year", "-", "Month", "-", "Day", "_", "Hour", "-", "Minute", "-", "Second" } ];
        uniqueID = IntegerString[ Hash[ CreateUUID[ ], "MD5" ], 36, 8 ];
        timestamp <> "_" <> uniqueID <> ".mx"
    ];

generateUniqueFailureFileName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cleanupOldFailureLogs*)
cleanupOldFailureLogs // beginDefinition;

cleanupOldFailureLogs[ ] := cleanupOldFailureLogs[ 50 ];

cleanupOldFailureLogs[ maxFiles_Integer ] :=
    Catch @ Module[ { dir, files, toDelete },
        dir = $internalFailureLogDirectory;
        If[ ! DirectoryQ @ dir, Throw @ Null ];
        files = FileNames[ "*.mx", dir ];
        If[ Length @ files <= maxFiles, Throw @ Null ];
        (* Sort by modification time, newest first *)
        files = ReverseSortBy[ files, FileDate[ #, "Modification" ] & ];
        toDelete = Drop[ files, maxFiles ];
        Quiet @ DeleteFile /@ toDelete;
    ];

cleanupOldFailureLogs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cleanupOldOutputLogs*)
cleanupOldOutputLogs // beginDefinition;

cleanupOldOutputLogs[ ] := cleanupOldOutputLogs[ 50 ];

cleanupOldOutputLogs[ maxFiles_Integer ] :=
    Catch @ Module[ { dir, files, dates, empty, toDelete },
        dir = $outputLogDirectory;
        If[ ! DirectoryQ @ dir, Throw @ Null ];
        files = FileNames[ "*.log", dir ];
        (* Sort by modification time, newest first *)
        dates = ReverseSort @ AssociationMap[ FileDate[ #, "Modification" ] &, files ];
        (* Empty log files older than 7 days *)
        empty = Keys @ Select[ KeySelect[ dates, FileByteCount[ # ] === 0 & ], # < Now - Quantity[ 7, "Days" ] & ];
        (* Oldest files beyond maxFiles limit *)
        toDelete = If[ Length @ files > maxFiles,
            Union[ Keys @ Drop[ dates, maxFiles ], empty ],
            empty
        ];
        If[ toDelete =!= { }, Quiet[ DeleteFile /@ toDelete ] ];
    ];

cleanupOldOutputLogs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatInternalFailureForMCP*)
formatInternalFailureForMCP // beginDefinition;

formatInternalFailureForMCP[ failure: Failure[ "AgentTools::Internal" | "General::ChatbookInternal", _ ] ] :=
    Module[ { tag, logPath },
        tag = extractFailureTag @ failure;
        logPath = $internalFailureLogPath;
        StringJoin[
            "[Error] An unexpected error occurred: ", tag, ".\n",
            If[ StringQ @ logPath,
                "Full details of the error have been logged to: " <> logPath <> "\n",
                ""
            ],
            "Report this issue at " <> $issuesURL
        ]
    ];

formatInternalFailureForMCP[ _ ] := None;

formatInternalFailureForMCP // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$bugReportBodyTemplate*)
$bugReportBodyTemplate = StringTemplate[ "\
Describe the issue in detail here. Attach any relevant screenshots or files. \
The section below was automatically generated. \
Remove any information that you do not wish to include in the report.\
\
%%SourceLink%%

<details>
<summary>Debug Data</summary>

%%DebugData%%

## Failure Data

%%InternalFailure%%

## Stack Data
```
%%Stack%%
```

</details>",
Delimiters -> "%%"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$frontEndVersion*)
$frontEndVersion :=
    If[ TrueQ @ $cloudNotebooks,
        StringJoin[ "Cloud: ", ToString @ $CloudVersion ],
        StringJoin[ "Desktop: ", ToString @ UsingFrontEnd @ SystemInformation[ "FrontEnd", "Version" ] ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$bugReportStack*)
$bugReportStack := StringRiffle[
    Reverse @ Replace[
        DeleteAdjacentDuplicates @ Cases[
            Stack[ _ ],
            HoldForm[ (s_Symbol) | (s_Symbol)[ ___ ] | (s_Symbol)[ ___ ][ ___ ] ] /;
                AtomQ @ Unevaluated @ s && StringStartsQ[ Context @ s, "Wolfram`AgentTools`" ] :>
                    SymbolName @ Unevaluated @ s
        ],
        { a___, "throwInternalFailure", ___ } :> { a, "throwInternalFailure" }
    ],
    "\n"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*trimURL*)
trimURL[ url_String ] := trimURL[ url, $maxBugReportURLSize ];

trimURL[ url_String, limit_Integer ] /; StringLength @ url <= limit := url;

trimURL[ url_String, limit_Integer ] :=
    Module[ { sp, bt, nl, before, after, base, take },
        sp     = ("+"|"%20")...;
        bt     = URLEncode[ "```" ];
        nl     = (URLEncode[ "\r\n" ] | URLEncode[ "\n" ])...;
        before = Longest[ "%23%23"~~sp~~"Failure"~~sp~~"Data"~~nl~~bt~~nl ];
        after  = Longest[ nl~~bt~~nl~~"%3C%2Fdetails%3E" ];
        base   = StringLength @ StringReplace[ url, a: before ~~ ___ ~~ b: after :> a <> "\n" <> b ];
        take   = UpTo @ Max[ limit - base, 80 ];

        With[ { t = take },
            StringReplace[
                StringReplace[ url, a: before ~~ b__ ~~ c: after :> a <> StringTake[ b, t ] <> "\n" <> c ],
                "%%0A" | ("%"~~HexadecimalCharacter~~"%0A") :> "%0A"
            ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*associationMarkdown*)
associationMarkdown[ data_Association? AssociationQ ] := StringJoin[
    "| Property | Value |\n| --- | --- |\n",
    StringRiffle[
        KeyValueMap[
            Function[
                { k, v },
                StringJoin @ StringJoin[
                    "| ",
                    ToString @ ToString[ Unevaluated @ k, CharacterEncoding -> "UTF-8" ],
                    " | ``",
                    escapePipes @ truncatePartString @ ToString[
                        Unevaluated @ v,
                        InputForm,
                        CharacterEncoding -> "UTF-8"
                    ],
                    "`` |"
                ],
                HoldAllComplete
            ],
            data
        ],
        "\n"
    ]
];

associationMarkdown[ rules___ ] := With[ { as = Association @ rules }, associationMarkdown @ as /; AssociationQ @ as ];
associationMarkdown[ other_   ] := markdownCodeBlock @ other;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*markdownCodeBlock*)
markdownCodeBlock[ as_Association? AssociationQ ] :=
    "```\n<|\n" <> StringRiffle[ ruleToString /@ Normal[ as, Association ], ",\n" ] <> "\n|>\n```\n";

markdownCodeBlock[ expr_ ] := StringJoin[
    "```\n",
    StringTake[ ToString[ expr, InputForm, PageWidth -> $maxPartLength ], UpTo @ $maxBugReportURLSize ],
    "\n```\n"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ruleToString*)
ruleToString[ a_ -> b_ ] := StringJoin[
    "  ",
    ToString[ Unevaluated @ a, InputForm ],
    " -> ",
    truncatePartString @ ToString[ Unevaluated @ b, InputForm ]
];

ruleToString[ a_ :> b_ ] := StringJoin[
    "  ",
    ToString[ Unevaluated @ a, InputForm ],
    " :> ",
    truncatePartString @ ToString[ Unevaluated @ b, InputForm ]
];

ruleToString[ other_ ] := truncatePartString @ ToString[ Unevaluated @ other, InputForm ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*truncatePartString*)
truncatePartString[ string_ ] := truncatePartString[ string, $maxPartLength ];

truncatePartString[ string_String, max_Integer ] :=
    If[ StringLength @ string > max, StringTake[ string, UpTo @ max ] <> "...", string ];

truncatePartString[ other_, max_Integer ] := truncatePartString[ ToString[ Unevaluated @ other, InputForm ], max ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*escapePipes*)
escapePipes[ string_String ] := StringReplace[ string, "|" -> "\\|" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*MX Build Utilities*)
$mxInitializations := $mxInitializations = Internal`Bag[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addToMXInitialization*)
addToMXInitialization // beginDefinition;
addToMXInitialization // Attributes = { HoldAllComplete };
addToMXInitialization[ ] := Null;
addToMXInitialization[ Null ] := Null;
addToMXInitialization[ eval___ ] /; $mxFlag := Internal`StuffBag[ $mxInitializations, HoldComplete @ eval ];
addToMXInitialization[ ___ ] := Null;
addToMXInitialization // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mxInitialize*)
mxInitialize // beginDefinition;
mxInitialize // Attributes = { HoldAllComplete };

mxInitialize[ eval___ ] :=
    If[ TrueQ @ $mxFlag,
        addToMXInitialization @ eval;
        ReleaseHold @ Internal`BagPart[ $mxInitializations, All ];
    ];

mxInitialize // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $debug = False;
    $releaseID;
    importDependentResourceFunctions[ ];
];

End[ ];
EndPackage[ ];
