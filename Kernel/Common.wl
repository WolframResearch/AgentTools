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

(* Keys and option names whose values can be secrets (bearer tokens), which messages and failure data never show (see
   redactSecrets). *)
$secretKeys = { "Authentication", Authentication, "Token", "authorization", "Authorization" };
$$secretKey = Alternatives @@ $secretKeys;
$redacted   = "<redacted>";

(* Shorter secrets that are found in an expression are redacted only where they are found (as the values of the keys
   above, of Authorization header lines and after "Bearer"), not wherever else they occur: such short strings occur by
   chance, and replacing them would garble the failure data. Secrets that code gives or registers are known to be
   secrets, so they are redacted wherever they occur, whatever their length (see secretStrings). *)
$minSecretLength = 8;

(* At most this many of the secrets found in an expression are redacted wherever they occur: each one is searched for
   in every string. *)
$maxSecrets = 32;

(* The secrets that redactSecrets replaces wherever they occur, besides the ones it finds (see withFailureSecrets). *)
$failureSecrets = { };

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
importResourceFunction // beginDefinition;
importResourceFunction::failure = "[ERROR] Failed to import resource function `1`. Aborting MX build.";
importResourceFunction // Attributes = { HoldFirst };

importResourceFunction[ name_String ] :=
    importResourceFunction[ None, name ];

importResourceFunction[ symbol_Symbol, name_String ] :=
    importResourceFunction[ symbol, name, Lookup[ $resourceVersions, name ] ];

importResourceFunction[ symbol_Symbol, name_String, version_ ] /; $mxFlag := Enclose[
    Block[ { PrintTemporary },
        Module[ { sourceContext, targetContext, definition, replaced, inlined, newSymbol },

            ConfirmAssert @ StringQ @ version;
            sourceContext = ConfirmBy[ ResourceFunction[ name, "Context", ResourceVersion -> version ], StringQ ];
            targetContext = $resourceFunctionContext<>name<>"`";
            definition    = ConfirmMatch[ ResourceFunction[ name, "DefinitionList" ], _Language`DefinitionList ];

            replaced = ConfirmMatch[
                ResourceFunction[ "ReplaceContext", ResourceVersion -> $resourceVersions[ "ReplaceContext" ] ][
                    definition,
                    sourceContext -> targetContext
                ],
                _Language`DefinitionList
            ];

            inlined = ConfirmMatch[ inlineDependentResourceFunctions @ replaced, _Language`DefinitionList ];

            $importedResourceFunctions[ name ] = version;
            KeyDropFrom[ $dependentResourceFunctions, Keys @ $importedResourceFunctions ];

            ConfirmMatch[ Language`ExtendedFullDefinition[ ] = inlined, _Language`DefinitionList ];

            newSymbol = ConfirmMatch[ Symbol[ targetContext<>name ], _Symbol? AtomQ ];

            importResourceFunction[ symbol, name, version ] =
                If[ Unevaluated @ symbol === None,
                    newSymbol,
                    ConfirmMatch[ symbol = newSymbol, newSymbol ]
                ]
        ]
    ],
    (Message[ importResourceFunction::failure, name ]; Abort[ ]) &
];

importResourceFunction[ symbol: Except[ None, _Symbol ], name_String, version_String ] :=
    symbol := symbol = Block[ { PrintTemporary }, ResourceFunction[ name, "Function", ResourceVersion -> version ] ];

importResourceFunction // endDefinition;

$importedResourceFunctions = <| |>;

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
inlineDependentResourceFunctions // beginDefinition;

inlineDependentResourceFunctions[ definition_ ] := ReplaceAll[
    definition,
    {
        HoldPattern @ ResourceFunction[ name_String, OptionsPattern[ ] ] :> RuleCondition[
            $dependentResourceFunctions[ name ] = True;
            Symbol[ $resourceFunctionContext<>name<>"`"<>name ]
        ],
        HoldPattern @ ResourceFunction[ name_String, "Function", OptionsPattern[ ] ] :> RuleCondition[
            $dependentResourceFunctions[ name ] = True;
            Symbol[ $resourceFunctionContext<>name<>"`"<>name ]
        ]
    }
];

inlineDependentResourceFunctions // endDefinition;


$dependentResourceFunctions = <| |>;

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
(*catchTopIsolated*)
(* catchTop for code that can run as a preemptive evaluation (a SocketListen handler or a scheduled task), and for code
   that such evaluations call. A preemptive evaluation sees the Blocks of the evaluation that it interrupted: inside a
   catchTop there, catchTop is # &, and $catching, $failed and $messageSymbol belong to that evaluation, so a nested
   catchTop would share its failure state and Throw its failures into it. This always starts a scope of its own, with
   the bindings of an outermost catchTop. *)
catchTopIsolated // beginDefinition;
catchTopIsolated // Attributes = { HoldFirst };

catchTopIsolated[ eval_ ] := catchTopIsolated[ eval, AgentTools ];

catchTopIsolated[ eval_, sym_Symbol ] :=
    Block[
        {
            $messageSymbol          = sym,
            $catching               = True,
            $failed                 = False,
            catchTop                = # &,
            catchTopAs              = (#1 &) &,
            $internalFailureLogPath = None
        },
        Catch[ eval, $catchTopTag ]
    ];

catchTopIsolated // endDefinition;

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
(* Failure data is shown in messages, put into bug reports and written to the log directory, so its secrets are
   redacted (redactSecrets). The evaluation stack is not searched: the data holds only its symbol (the delayed value of
   "Stack"), which messages, bug reports and log files show without evaluating it, so the stack stays in memory. In a
   preemptive evaluation (such as a SocketListen handler), it also holds the frames of the evaluation that was
   interrupted, with any amount of the user's data. *)
makeInternalFailureData // Attributes = { HoldFirst };

makeInternalFailureData[ eval_, Failure[ tag_, as_Association ], args___ ] :=
    StackInhibit @ Module[ { $stack = Stack[ _ ] },
        redactSecrets @ DeleteMissing @ <|
            "Evaluation"  :> eval,
            KeyTake[ as, $priorityFailureKeys ],
            "Stack"       :> $stack,
            "Failure"     -> Failure[ tag, Association[ KeyDrop[ as, $priorityFailureKeys ], as ] ],
            "Arguments"   -> { args }
        |>
    ];

makeInternalFailureData[ eval_, args___ ] :=
    StackInhibit @ Module[ { $stack = Stack[ _ ] },
        redactSecrets @ <|
            "Evaluation" :> eval,
            "Stack"      :> $stack,
            "Arguments"  -> { args }
        |>
    ];

$priorityFailureKeys = { "Information", "ConfirmationType", "Expression", "Function", "Pattern", "Test" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withFailureSecrets*)
(* Evaluates an expression with secrets that redactSecrets replaces wherever they occur, so that the data of an internal
   failure in it never shows them. Code that handles a secret registers it here, since a failing call can hold a secret
   on its own (e.g. a bearer token passed to an authentication check), which nothing then shows to be one. *)
withFailureSecrets // beginDefinition;
withFailureSecrets // Attributes = { HoldRest };

withFailureSecrets[ secrets_List, eval_ ] :=
    Block[ { $failureSecrets = Join[ $failureSecrets, Select[ secrets, StringQ ] ] }, eval ];

withFailureSecrets // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*redactSecrets*)
(* Replaces secrets with "<redacted>" in expressions that messages show or that failure data keeps, also inside held
   expressions, without evaluating any of their parts:
     * the values of the keys that can hold secrets ($$secretKey: an "Authentication" option, a "Token" key, an
       Authorization header), in rules and associations
     * the values of "Authorization:" header lines and the tokens after "Bearer", in strings and in byte arrays (such
       as the raw bytes of an HTTP request)
     * every other occurrence, in strings and byte arrays, of the secrets (see secretStrings): those given, those
       registered with withFailureSecrets, and the string values of the keys, header lines and bearer tokens above
   The time it takes grows only with the size of the expression and the number of secrets given and registered: packed
   arrays hold only numbers and are not searched (which would unpack them), every word is searched for in all strings
   at once, and the expression is rebuilt only if it holds a secret. Like makeInternalFailureData, these functions do
   not use beginDefinition: they redact the data of internal failures, so they must not throw internal failures of
   their own. *)
redactSecrets[ expr_ ] := redactSecrets[ expr, { } ];

redactSecrets[ expr_, secrets_List ] :=
    With[ { parts = secretParts @ expr },
        redactParts[ expr, parts, secretStrings[ Join[ secrets, $failureSecrets ], parts[ "Secrets" ] ] ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*secretParts*)
(* The parts of an expression that can hold secrets, found without evaluating any of them:
     "KeyRules"       whether a rule of a key that can hold secrets has a value that is not redacted yet
     "Associations"   whether an association has such an entry (ReplaceAll cannot match the entries of associations)
     "Originals"      the strings and byte arrays, and "Texts" the same as strings
     "Authorization"  1 for the texts that contain "authorization" (in any case), 0 for the others
     "Bearer"         1 for the texts that contain "bearer" (in any case), 0 for the others
     "Secrets"        the string values of the keys that can hold secrets and of Authorization header lines, and the
                      tokens after "Bearer" in the texts *)
secretParts[ expr_ ] :=
    Module[ { searched, ruleValues, keyValues, strings, bytes, texts, authorization, headers, bearer, tokens },
        searched = expr /. _List? packedArrayQ :> Null;

        ruleValues = Cases[
            searched,
            (Rule|RuleDelayed)[ $$secretKey, value: Except[ $redacted ] ] :> HoldComplete @ value,
            { 0, Infinity },
            Heads -> True
        ];

        keyValues = Cases[
            DeleteCases[
                KeyTake[ Cases[ searched, _Association? holdAtomQ, { 0, Infinity }, Heads -> True ], $secretKeys ],
                $redacted,
                { 2 }
            ],
            value_ :> HoldComplete @ value,
            { 2 }
        ];

        strings       = Cases[ searched, _String, { 0, Infinity }, Heads -> True ];
        bytes         = Cases[ searched, _ByteArray? holdAtomQ, { 0, Infinity }, Heads -> True ];
        texts         = Join[ strings, byteArrayText /@ bytes ];
        authorization = Boole @ StringContainsQ[ texts, "authorization", IgnoreCase -> True ];
        headers       = StringCases[ Pick[ texts, authorization, 1 ], $authorizationHeaderLine :> "$2" ];
        bearer        = Boole @ StringContainsQ[ texts, "bearer", IgnoreCase -> True ];
        tokens        = StringCases[ Pick[ texts, bearer, 1 ], $bearerCredentials :> "$2" ];

        <|
            "KeyRules"      -> ruleValues =!= { },
            "Associations"  -> keyValues =!= { },
            "Originals"     -> Join[ strings, bytes ],
            "Texts"         -> texts,
            "Authorization" -> authorization,
            "Bearer"        -> bearer,
            "Secrets"       -> Join[
                Cases[ Join[ ruleValues, keyValues ], HoldComplete[ value_String ] :> value ],
                Flatten @ headers,
                Flatten @ tokens
            ]
        |>
    ];

(* ISO8859-1 decodes every byte to one character, so the bytes that are not redacted stay the same. *)
byteArrayText[ bytes_ByteArray ] := ByteArrayToString[ bytes, "ISO8859-1" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*secretStrings*)
(* The secrets that are redacted wherever they occur: all of those given and registered (known), which code knows to be
   secrets and of which there are few (one per socket server and one per request), and at most $maxSecrets of those
   found, with at least $minSecretLength characters. They are sorted longest first, the order in which StringReplace
   tries them, so that a secret that holds another one (e.g. a token and a part of it) is replaced as a whole. *)
secretStrings[ known_List, found_List ] :=
    ReverseSortBy[
        DeleteDuplicates @ Join[
            Select[ known, secretStringQ ],
            Take[ Select[ DeleteDuplicates @ found, foundSecretQ ], UpTo[ $maxSecrets ] ]
        ],
        StringLength
    ];


(* Whether a string can be replaced wherever it occurs: not if it is only whitespace (or empty), or if it holds the
   replacement, as an Authorization value that is already redacted does. *)
secretStringQ[ secret_String ] := StringFreeQ[ secret, $redacted ] && ! StringMatchQ[ secret, WhitespaceCharacter... ];
secretStringQ[ _ ] := False;


foundSecretQ[ secret_ ] := secretStringQ @ secret && StringLength @ secret >= $minSecretLength;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*redactParts*)
(* Replaces the parts of an expression (see secretParts) that hold secrets, and gives the expression itself if none do.
   ReplaceAll does not search the parts that it replaces, so packed arrays are replaced with themselves. Only the
   redacted entries of an association are replaced (ReplacePart), since making a new association from its rules would
   evaluate its values; the same rules then redact its other values. *)
redactParts[ expr_, parts_Association, secrets_List ] :=
    Module[ { rules },
        rules = With[ { redacted = $redacted },
            Join[
                If[ parts[ "KeyRules" ],
                    { (rule: Rule|RuleDelayed)[ key: $$secretKey, Except[ redacted ] ] :> rule[ key, redacted ] },
                    { }
                ],
                If[ parts[ "Associations" ],
                    {
                        as_Association? secretKeysQ :>
                            RuleCondition[ ReplaceAll[ redactSecretKeys @ as, rules ], True ]
                    },
                    { }
                ],
                textRules[ parts, secrets ]
            ]
        ];
        If[ rules === { },
            expr,
            rules = Dispatch @ Prepend[ rules, packed_List? packedArrayQ :> packed ];
            ReplaceAll[ expr, rules ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*redactSecretKeys*)
(* Replaces the values of an association's keys that can hold secrets. *)
redactSecretKeys[ as_Association ] :=
    ReplacePart[ as, Thread[ Key /@ Select[ Keys @ as, MatchQ @ $$secretKey ] -> $redacted ] ];


(* Whether an expression is an association with a key that can hold secrets and that is not redacted yet. *)
secretKeysQ // Attributes = { HoldAllComplete };
secretKeysQ[ as_ ] := holdAtomQ @ as && DeleteCases[ KeyTake[ as, $secretKeys ], $redacted ] =!= <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*textRules*)
(* Rules that replace the strings and byte arrays that hold secrets with their redacted versions. Each word is searched
   for on its own, which is much faster than searching for alternatives, and the results are combined. *)
textRules[ parts_Association, secrets_List ] :=
    Module[ { texts, mask },
        texts = parts[ "Texts" ];
        mask  = BitOr[ parts[ "Authorization" ], parts[ "Bearer" ] ];
        mask  = Fold[ BitOr[ #1, Boole @ StringContainsQ[ texts, #2 ] ] &, mask, secrets ];
        DeleteDuplicatesBy[
            MapThread[
                textRule[ #1, #2, secrets ] &,
                { Pick[ parts[ "Originals" ], mask, 1 ], Pick[ texts, mask, 1 ] }
            ],
            First
        ]
    ];


textRule[ original_, text_String, secrets_List ] :=
    With[ { new = redactText[ text, secrets ] },
        Which[
            new === text      , Nothing,
            StringQ @ original, original -> new,
            True              , original -> StringToByteArray[ new, "ISO8859-1" ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*redactText*)
(* Redacts the values of "Authorization:" header lines (also "Proxy-Authorization:"), the tokens after "Bearer", and
   the secrets in a string. *)
redactText[ text_String, secrets_List ] :=
    StringReplace[
        text,
        Join[
            {
                $authorizationHeaderLine :> "$1" <> $redacted,
                $bearerCredentials       :> "$1" <> $redacted
            },
            Thread[ secrets -> $redacted ]
        ]
    ];

$authorizationHeaderLine = RegularExpression[ "(?i)(\\bauthorization[ \\t]*:[ \\t]*)([^\\r\\n]+)" ];

(* A token ends at a quote, so that one in JSON text ends with its string. *)
$bearerCredentials = RegularExpression[ "(?i)(\\bbearer\\s+)([^\\s\"]+)" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*holdAtomQ*)
(* Whether an expression is atomic, without evaluating it: true for a valid Association or ByteArray, but not for an
   Association[...] or ByteArray[...] expression in held code, which a test like AssociationQ would evaluate. *)
holdAtomQ // Attributes = { HoldAllComplete };
holdAtomQ[ expr_ ] := AtomQ @ Unevaluated @ expr;


(* Whether an expression is a packed array, without evaluating it. *)
packedArrayQ // Attributes = { HoldAllComplete };
packedArrayQ[ expr_ ] := Developer`PackedArrayQ @ Unevaluated @ expr;

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
        dir = ensureInternalFailureLogDirectory @ $internalFailureLogDirectory;
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
(*ensureInternalFailureLogDirectory*)
(* Creates the directory of the internal failure logs if needed, and makes it private to the user (mode 0700) on
   Unix-like systems, also when it already exists: failure data shows what the failing code was working on, which can be
   private even with its secrets redacted. On Windows, the user's profile directory, which holds $UserBaseDirectory, is
   private already. The mode is set once per directory and session, since it takes a process. *)
ensureInternalFailureLogDirectory // beginDefinition;

ensureInternalFailureLogDirectory[ dir_String ] := (
    If[ ! DirectoryQ @ dir, Quiet @ CreateDirectory[ dir, CreateIntermediateDirectories -> True ] ];
    makeDirectoryPrivate @ dir;
    dir
);

ensureInternalFailureLogDirectory // endDefinition;


makeDirectoryPrivate // beginDefinition;

makeDirectoryPrivate[ dir_String? DirectoryQ ] /; $OperatingSystem =!= "Windows" && ! TrueQ @ $CloudEvaluation :=
    (* remembered, so the process runs once *)
    makeDirectoryPrivate[ dir ] = (Quiet @ RunProcess[ { "chmod", "700", dir } ]; Null);

makeDirectoryPrivate[ _String ] := Null;

makeDirectoryPrivate // endDefinition;

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
        Quiet[ DeleteFile /@ toDelete ];
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
