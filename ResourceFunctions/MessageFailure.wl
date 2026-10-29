(* ::Package:: *)

(*
    Local copy of the "MessageFailure" resource function (version 1.0.1) from the Wolfram Function Repository.

    Source:   https://github.com/rhennigan/ResourceFunctions/blob/main/Definitions/MessageFailure/Definition.wl (commit 08ee812)
    Resource: https://resources.wolframcloud.com/FunctionRepository/resources/MessageFailure

    Kernel/Common.wl (importResourceFunction) loads this file in preference to fetching the resource function from
    the Function Repository, so the paclet can be built and loaded from source without cloud access. This directory
    is not part of the built paclet: the MX build inlines these definitions. The original definition is wrapped in
    BeginPackage/EndPackage so its symbols live in the "Wolfram`AgentTools`ResourceFunctions`MessageFailure`" context.
    Do not edit the definitions here; update the upstream resource function and copy the file again.
*)

BeginPackage[ "Wolfram`AgentTools`ResourceFunctions`MessageFailure`" ];

(* !Excluded
This notebook was automatically generated from [Definitions/MessageFailure](https://github.com/rhennigan/ResourceFunctions/blob/main/Definitions/MessageFailure).
*)

MessageFailure // ClearAll;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Messages for normal evaluation*)
MessageFailure::empty =
"An evaluation failed.";

MessageFailure::tagged =
"A failure of type \"`1`\" occurred.";

MessageFailure::expression =
"An evaluation failed with expression `1`.";

MessageFailure::arguments =
"An evaluation failed with arguments `1`.";

MessageFailure::message =
"`1`";


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Messages for errors*)
MessageFailureInternal // ClearAll;

MessageFailureInternal::invfailargs =
"Internal Error: Could not construct a valid Failure object from arguments: \
`2`. `1`";

MessageFailureInternal::invfail =
"Internal Error: `2` is not a valid Failure object. `1`";

MessageFailureInternal::undefined =
"Internal Error: No definition found for `2`. `1`";

MessageFailureInternal::unknown =
"Internal Error: An unexpected error occurred. `1`";


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attributes*)
MessageFailure // Attributes = { HoldFirst };


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Options*)
MessageFailure // Options = {
    "MessageFunction" -> Automatic,
    "Verbose"         -> False,
    "Stack"           -> False,
    "TestMode"        -> False
};


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definition utilities*)
endDefinition // ClearAll;
endDefinition // Attributes = { HoldFirst };
endDefinition[ s_Symbol? symbolQ ] :=
    expr: s[ ___ ] := throwInternalFailure[ "undefined", HoldForm @ expr ];



catch // ClearAll;
catch // Attributes = { HoldFirst };
catch[ eval_ ] :=
    stacked @ Block[ { $catching = True, catch = # & },
        Catch[ eval, $top ]
    ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
debugPrint // ClearAll;
debugPrint // Attributes = { HoldAllComplete };
debugPrint[ args___ ] /; $debug := Print @ args;
(* :!CodeAnalysis::EndBlock:: *)

stacked // ClearAll;
stacked[ a_, ___ ] := a;


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Flags set by option values*)
$stack   = Automatic;
$verbose = False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument patterns*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PatternTest:: *)
$failureOpts = OptionsPattern @ Failure;
$mfOpts      = OptionsPattern @ MessageFailure;
$opts        = OptionsPattern[ { MessageFailure, Failure } ]? optionsQ;
$symbol      = _Symbol? symbolQ;
$string      = _String? stringQ;
$params      = { ___ } | _Association? AssociationQ;
(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Options handling*)
$optKey // ClearAll;
$optKey := $optKey = Alternatives @@ (
    ToString /@ Keys @ Options @ MessageFailure
);



optNameQ // ClearAll;
optNameQ // Attributes = { HoldFirst };
optNameQ[ s_? stringQ ] := MatchQ[ s, $optKey ];
optNameQ[ s_? symbolQ ] := MatchQ[ SymbolName @ Unevaluated @ s, $optKey ];
optNameQ[ ___         ] := False;



optionQ // ClearAll;
optionQ // Attributes = { HoldFirst };
optionQ[ (Rule|RuleDelayed)[ _? optNameQ, _ ] ] := True;
optionQ[ ___ ] := False;



optionsQ // ClearAll;
optionsQ // Attributes = { HoldFirst };
optionsQ[ ___? optionQ ] := True;
optionsQ[ ___ ] := False;



notOptionQ // ClearAll;
notOptionQ // Attributes = { HoldFirst };
notOptionQ[ arg_ ] := TrueQ[ ! optionQ @ arg ];
notOptionQ[ ___  ] := False;



paramsQ // ClearAll;
paramsQ // Attributes = { HoldFirst };
paramsQ[ arg_ ] := MatchQ[ Unevaluated @ arg, $params ];
paramsQ[ ___  ] := False;



paramsAndOptions // ClearAll;

paramsAndOptions[ params:___? notOptionQ, opts___? optionQ ] :=
    <| "MessageParameters" :> { params }, "Options" :> { opts } |>;

paramsAndOptions[ params___ ] :=
    <| "MessageParameters" :> { params } |>;



(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Main definition*)


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*From MessageName*)
MessageFailure[ msg: MessageName[ sym_, tag_, tags___ ], params___ ] /;
    messageNameQ @ msg :=
        catch @ messageFailure @ Join[
            <|
                "MessageTemplate" :> msg,
                "MessageTag"      -> { tag, tags },
                "MessageSymbol"   :> sym,
                "FailureTag"      -> makeFailureTag @ msg
            |>,
            paramsAndOptions @ params
        ];


makeFailureTag // ClearAll;
makeFailureTag // Attributes = { HoldFirst };

makeFailureTag[ MessageName[ sym_? symbolQ, tag__? stringQ ] ] :=
    StringRiffle[ { SymbolName @ Unevaluated @ sym, tag }, "::" ];

makeFailureTag[ sym_Symbol? symbolQ ] := symbolToFailTag @ sym;

makeFailureTag[ ___ ] := "MessageFailure";


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*From Failure*)
MessageFailure[ Failure[ tag_, assoc_Association? AssociationQ ] ] :=
    catch @ messageFailure @ Append[ assoc, "FailureTag" -> tag ];

MessageFailure[ Failure[ tag_, assoc_Association? AssociationQ ] ] :=
    MessageFailure[ tag, assoc ];


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Failure-like syntax*)
MessageFailure[ tag_? tagQ, assoc_? AssociationQ, opts: $opts ] :=
    catch @ messageFailure @ Join[
        assoc,
        <| "FailureTag" :> tag, "Options" :> { opts } |>
    ];


MessageFailure[ assoc_Association? AssociationQ, opts: $opts ] :=
    catch @ messageFailure @ Join[ <| "Options" :> { opts } |>, assoc ];


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Check value of first argument*)
MessageFailure[ arg: Except[ _MessageName ], rest___ ] :=
    With[ { eval = arg },
        MessageFailure[ eval, rest ] /; ! MatchQ[ eval, HoldPattern @ arg ]
    ];


MessageFailure[ message_? notOptionQ, opts: $opts ] :=
    catch @ messageFailure @ <|
        "FailureTag"      :> "MessageFailure",
        "Options"         :> { opts },
        "MessageTemplate" :> message,
        "MessageSymbol"   :> MessageFailure,
        "MessageTag"      :> { "message" }
    |>;


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic argument forms*)
MessageFailure[ tag_? tagQ, Automatic, opts: $opts ] :=
    catch @ messageFailure @ <|
        "FailureTag"        :> tag,
        "Options"           :> { opts },
        "MessageTemplate"   :> MessageFailure::tagged,
        "MessageTag"        :> { "tagged" },
        "MessageParameters" :> { tag }
    |>;


MessageFailure[ tag_? tagQ, message_, opts: $opts ] :=
    MessageFailure[ tag, <| "Message" :> message, "Options" :> { opts } |> ];


MessageFailure[ Evaluate[ opts: $opts ] ] :=
    MessageFailure[ "MessageFailure", <| "Options" :> { opts } |> ];


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fallback definitions*)
MessageFailure[ other_ ] :=
    catch @ messageFailure @ <|
        "MessageParameters" :> { other },
        "MessageTemplate"   :> MessageFailure::expression,
        "MessageTag"        :> { "expression" }
    |>;

MessageFailure[ other___ ] :=
    catch @ messageFailure @ <|
        "MessageParameters" :> { { other } },
        "MessageTemplate"   :> MessageFailure::arguments,
        "MessageTag"        :> { "arguments" }
    |>;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*messageFailure*)
messageFailure // ClearAll;

messageFailure[ info: KeyValuePattern[ "MessageTemplate" :> msg_ ] ] :=
    Block[ { $msgBlocked = True }, msgBlock[ msg, messageFailure @ info ] ] /;
        ! TrueQ @ $msgBlocked;

messageFailure[ info: KeyValuePattern @ {
    "MessageTemplate"   :> msg_,
    "MessageParameters" :> _? paramsQ,
    "MessageTag"        :> { msgTag__ },
    "MessageSymbol"     :> sym_,
    "FailureTag"        :> tag_,
    "Options"           :> Evaluate @ { opts: $opts }
} ] :=
    withOptions[ makeFailureObject @ issueMessage @ info, opts ];

messageFailure[ info: KeyValuePattern @ { } ] :=
    With[ { new = standardizeInfo @ info },
        messageFailure @ new /; new =!= info
    ];

messageFailure[ args___ ] :=
    messageFailure @ Join[
        $defaultMessageFailureArgs,
        <|
            "MessageParameters" :> { args }
        |>
    ];


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*msgBlock*)
msgBlock // ClearAll;
msgBlock // Attributes = { HoldAll };

msgBlock[ MessageName[ sym_? symbolQ, ___ ], eval_ ] :=
    With[ { $sym := sym },
        WithCleanup[
            debugPrint[ "before: ", Messages @ sym ],
            Internal`InheritedBlock[ { $sym }, eval ],
            debugPrint[ "after: ", Messages @ sym ]
        ]
    ];

msgBlock[ _, eval_ ] := eval;

msgBlock // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*withOptions*)
withOptions // ClearAll;
withOptions // Attributes = { HoldFirst };

withOptions[ eval_, opts___ ] :=
    Block[
        {
            $stack   = OptionValue[ MessageFailure, { opts }, "Stack"   ],
            $verbose = OptionValue[ MessageFailure, { opts }, "Verbose" ]
        },
        If[ TrueQ @ $stack,
            StackComplete @ eval,
            eval
        ]
    ];


withOptions // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*issueMessage*)
issueMessage // ClearAll;
issueMessage[ info_ ] := applyWithTemplateWrapper[ issueMessage0, info ];
issueMessage // endDefinition;


issueMessage0 // ClearAll;

issueMessage0[ info: KeyValuePattern @ {
    "MessageTemplate"   :> str_String,
    "MessageParameters" :> params_List
} ] :=
    Module[ { msg, new },
        msg = TemplateApply[ str, params ];
        new = Join[
            info,
            <|
                "MessageTemplate"   :> MessageFailure::message,
                "MessageParameters" :> Evaluate @ { msg },
                "MessageTag"        :> { "message" }
            |>
        ];
        issueMessage0 @ new
    ];


issueMessage0[ info: KeyValuePattern @ {
    "MessageTemplate"   :> msg_,
    "MessageParameters" :> params_Association,
    "MessageTag"        :> { msgTag__ },
    "MessageSymbol"     :> sym_Symbol? symbolQ,
    "Options"           :> Evaluate @ { opts: $opts }
} ] :=
    Module[ { message, string },
        message = getMessageFunction[ MessageName[ sym, msgTag ], opts ];
        string  = messageString[ msg, params ];

        (* TODO: set up override for list params too *)
        messageOverride[ MessageName[ sym, msgTag ], message, string, params ];

        (* message[ msg, params ]; *)
        info
    ];


issueMessage0[ info: KeyValuePattern @ {
    "MessageTemplate"   :> msg_,
    "MessageParameters" :> { params___ },
    "MessageTag"        :> { msgTag__ },
    "MessageSymbol"     :> sym_,
    "Options"           :> Evaluate @ { opts: $opts }
} ] :=
    Module[ { mName, message, string },
        mName   = MessageName[ sym, msgTag ];
        message = getMessageFunction[ MessageName[ sym, msgTag ], opts ];
        If[ mName =!= msg,
            string = messageString[ msg, params ];
            messageOverride[ MessageName[ sym, msgTag ],
                             message,
                             string,
                             params
            ],
            message[ msg, params ]
        ];
        info
    ];


issueMessage0 // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyWithTemplateWrapper*)
applyWithTemplateWrapper // ClearAll;
applyWithTemplateWrapper // Attributes = { HoldAll };
applyWithTemplateWrapper[ f_, info_ ] :=
    stripTemplateWrapper @ f @ addTemplateWrapper @ info;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addTemplateWrapper*)
addTemplateWrapper // ClearAll;


addTemplateWrapper[ info: KeyValuePattern[ "MessageTemplate" :> template_ ] ] :=
    If[ ! FreeQ[ HoldComplete @ template, $templateSymbols ],
        Join[
            info,
            <|
                "MessageTemplate" :> TemplateExpression @ template,
                "TemplateWrapper" :> TemplateExpression
            |>
        ],
        info
    ];


addTemplateWrapper[ info_ ] := info;


addTemplateWrapper // endDefinition;


$templateSymbols = HoldPattern @ Alternatives[
    TemplateEvaluate,
    TemplateExpression,
    TemplateIf,
    TemplateObject,
    TemplateSequence,
    TemplateSlot,
    TemplateSlotSequence,
    TemplateUnevaluated,
    TemplateVerbatim,
    TemplateWith
];



(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stripTemplateWrapper*)
stripTemplateWrapper // ClearAll;


stripTemplateWrapper[ info: KeyValuePattern @ {
    "MessageTemplate" :> wrapper_[ template_ ],
    "TemplateWrapper" :> wrapper_
} ] :=
    Append[ KeyDrop[ info, "TemplateWrapper" ],
            "MessageTemplate" :> template
    ];


stripTemplateWrapper[ info_ ] := info;


stripTemplateWrapper // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*messageOverride*)
messageOverride // ClearAll;
messageOverride // Attributes = { HoldFirst };


messageOverride[
    msg: MessageName[ sym_, __ ],
    message_,
    string_String,
    params___
] :=
    With[ { $sym := sym },
        Block[ { $sym, Internal`$MessageFormatter = msgFormatter },
            msg = string;
            message[ msg, params ]
        ]
    ];


messageOverride // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*msgFormatter*)
msgFormatter // ClearAll;
msgFormatter // Attributes = { HoldAllComplete };


msgFormatter[ msg_, StringForm[ str_String ] ] :=
    msgFormatter[ msg, StringForm[ "`1`", str ] ];


msgFormatter[ args___ ] :=
    Internal`MessageMenuFormatter @ args;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*templateType*)
templateType // ClearAll;
templateType[ template_String ] := templateType @ StringTemplate @ template;
templateType[ template_ ] :=
    If[ FreeQ[ template, TemplateSlot[ _String ] | _TemplateExpression ],
        "Positional",
        "Named"
    ];


templateType // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getMessageTemplate*)
getMessageTemplate // ClearAll;


getMessageTemplate[ HoldPattern @ MessageName[ sym_, tag__ ], args___ ] :=
    getMessageTemplate[ MessageName[ General, tag ], args ];


getMessageTemplate[ HoldPattern @ MessageName[ General, __ ], args___ ] :=
    StringJoin[
        "-- Message text not found --",
        Table[
            { " (`", ToString @ i, "`)" },
            { i, Length @ HoldComplete @ args }
        ]
    ];


getMessageTemplate[ template_, args___ ] :=
    template;


getMessageTemplate // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*messageString*)
messageString // ClearAll;


messageString[ HoldPattern @ MessageName[ sym_, tag__ ], args___ ] :=
    messageString[ MessageName[ General, tag ], args ];


messageString[ HoldPattern @ MessageName[ General, __ ], args___ ] :=
    StringJoin[
        "-- Message text not found --",
        Table[
            { " (`", ToString @ i, "`)" },
            { i, Length @ HoldComplete @ args }
        ]
    ];


messageString[ string_String, args___ ] :=
    Module[ { template, type },
        template = messageStringTemplate @ string;
        type = templateType @ template;
        messageString0[ type, template, args ]
    ];


messageString[ template_, args_Association ] :=
    toString @ TemplateApply[ template, args ];


messageString[ template_, args___ ] :=
    toString @ TemplateApply[ template, { args } ];


messageString[ ___ ] :=
    "-- Message text not found --";



messageString0 // ClearAll;


messageString0[ "Named", template_, assoc_Association ] :=
    TemplateApply[ template, assoc ];


messageString0[ "Named", template_, ___ ] := TemplateApply @ template;


messageString0[ "Positional", template_, assoc_Association ] :=
    TemplateApply[ template, Values @ assoc ];


messageString0[ "Positional", ___ ] := Missing[ "WrongTemplateType" ];


messageString0 // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*messageStringTemplate*)
messageStringTemplate // ClearAll;


messageStringTemplate[ template_String ] /; $Notebooks :=
    StringTemplate[
        template,
        InsertionFunction -> Function @ ToString[ #, StandardForm ]
    ];


messageStringTemplate[ template_String ] :=
    StringTemplate[ template, InsertionFunction -> toString ];


messageStringTemplate[ ___ ] :=
    "-- Message text not found --";


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toString*)
toString // ClearAll;
toString[ string_String? StringQ ] := string;
toString[ expr_ ] /; $Notebooks := ToString[ expr, StandardForm ];
toString[ expr_ ] := ToString @ expr;
toString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*standardizeInfo*)
standardizeInfo // ClearAll;


standardizeInfo[ info: KeyValuePattern[ _ -> _ ] ] :=
    standardizeInfo @ AssociationMap[
        Apply @ RuleDelayed,
        Association @ info
    ];


standardizeInfo[ info: KeyValuePattern[ "Message" :> msg_ ] ] :=
    standardizeInfo @ Append[
        KeyDrop[ info, "Message" ],
        "MessageTemplate" :> msg
    ];


standardizeInfo[ info: KeyValuePattern @ { } ] :=
    AssociationMap[
        Apply @ RuleDelayed,
        Join[ $defaultMessageFailureArgs,
              $standardizer @ info
        ]
    ];


standardizeInfo // endDefinition;


$standardizer = Composition[
    validateInfo,
    addSymbolAndTag,
    addMessageTemplate,
    checkFailureTag,
    checkTemplateType,
    Association
];


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addSymbolAndTag*)
addSymbolAndTag // ClearAll;


addSymbolAndTag[ info: KeyValuePattern[
    "MessageTemplate" :> MessageName[ sym_Symbol, tag___ ]
] ] :=
    Join[
        <|
            "MessageSymbol" :> sym,
            "MessageTag"    :> { tag }
        |>,
        info
    ];


addSymbolAndTag[ info_ ] := info;


addSymbolAndTag // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkTemplateType*)
checkTemplateType // ClearAll;


checkTemplateType[ info: KeyValuePattern @ {
     "MessageTemplate"   :> template_,
     "MessageParameters" :> { params_Association }
} ] :=
    If[ templateType @ getMessageTemplate @ template === "Named",
        Append[ info, "MessageParameters" :> params ],
        info
    ];

checkTemplateType[ info: KeyValuePattern @ {
     "MessageTemplate"   :> template_,
     "MessageParameters" :> { }
} ] :=
    If[ templateType @ getMessageTemplate @ template === "Named",
        Append[ info, "MessageParameters" :> Evaluate[ <| |> ] ],
        info
    ];

checkTemplateType[ info_ ] := info;


checkTemplateType // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkFailureTag*)
checkFailureTag // ClearAll;


checkFailureTag[ info: KeyValuePattern[ "Tag" :> tag_? tagQ ] ] :=
    Append[ info, "FailureTag" :> tag ];


checkFailureTag[ info_ ] := info;


checkFailureTag // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addMessageTemplate*)
addMessageTemplate // ClearAll;


addMessageTemplate[ info: KeyValuePattern[ "Message" :> msg_ ] ] :=
    Append[ KeyDrop[ info, "Message" ], "MessageTemplate" :> msg ];


addMessageTemplate[ info_ ] := info;


addMessageTemplate // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validateInfo*)
validateInfo // ClearAll;


validateInfo[ info: KeyValuePattern @ { } ] :=
    DeleteMissing @ Association @ AssociationMap[
        validateRule,
        Association @ info
    ];


validateInfo[ ___ ] := <| |>;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validateRule*)
validateRule // ClearAll;
validateRule // Attributes = { HoldRest };


validateRule[ (Rule|RuleDelayed)[ a_, b_ ] ] :=
    validateRule[ a, b ];


validateRule[ "FailureTag", tag_? tagQ ] :=
    "FailureTag" :> tag;


validateRule[ "MessageParameters", p: Except[ _? paramsQ ] ] :=
    "MessageParameters" :> { p };


validateRule[ "MessageSymbol", Except[ _? symbolQ ] ] := Nothing;


validateRule[ "MessageTag", str_String? stringQ ] :=
    "MessageTag" :> { str };


validateRule[
    "MessageTag",
    Except[ { _? stringQ }|{ _? stringQ, _? stringQ } ]
] :=
    Nothing;


validateRule[ "Options", opts: { ___? optionQ } ] :=
    "Options" :> opts;


validateRule[ "Options", opts___ ] :=
    "Options" :> Evaluate @ Lookup[ paramsAndOptions @ opts, "Options", { } ];


validateRule[ key_, value_ ] := key :> value;


validateRule[ ___ ] := Nothing;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$defaultMessageFailureArgs*)
$defaultMessageFailureArgs // ClearAll;


$defaultMessageFailureArgs := $defaultMessageFailureArgs = <|
    "FailureTag"        :> "MessageFailure",
    "MessageParameters" :> { },
    "MessageSymbol"     :> MessageFailure,
    "MessageTag"        :> { "empty" },
    "MessageTemplate"   :> MessageFailure::empty,
    "Options"           :> { }
|>;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*symbolToFailTag*)
symbolToFailTag // ClearAll;
symbolToFailTag // Attributes = { HoldFirst };


symbolToFailTag[ MessageFailure ] := "MessageFailure";


symbolToFailTag[ symbol_Symbol ] :=
    Module[ { code, eval },
        code = TrueQ @ System`Private`HasOwnCodeQ @ Unevaluated @ symbol;
        eval = TrueQ @ System`Private`HasOwnEvaluationsQ @ symbol;
        If[ code || eval,
            ToString @ Unevaluated @ FullForm @ symbol,
            symbol
        ]
    ];


symbolToFailTag // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeFailureObject*)
makeFailureObject // ClearAll;


makeFailureObject[ Failure[ tag_ ], opts: $failureOpts ] :=
    makeFailureObject @ Failure[ tag, <| |>, opts ];


makeFailureObject[ failure_Failure? failureObjectQ, opts: $failureOpts ] :=
    Append[ failure, Unevaluated @ Sequence @ opts ];


makeFailureObject[ info: KeyValuePattern[ "FailureTag" :> tag_ ] ] :=
    Module[ { withStack, cleaned, failure },

        withStack = includeStack @ info;
        cleaned   = If[ TrueQ @ $verbose,
                        withStack,
                        KeyDrop[
                            withStack,
                            {
                                "FailureTag",
                                "MessageSymbol",
                                "MessageTag",
                                "Options"
                            }
                        ]
                    ];

        failure = Failure[ tag, cleaned ];

        If[ tagQ @ tag,
            Failure[ tag, cleaned ]
        ]
    ];


makeFailureObject[ tag_? tagQ, opts: $failureOpts ] :=
    makeFailureObject @ Failure[ tag, <| |>, opts ];


makeFailureObject[ args___ ] :=
    With[ { fail = Failure @ args },
        If[ failureObjectQ @ fail,
            fail,
            internalFailure[ "invfail", fail ]
        ]
    ];


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*internalFailure*)
internalFailure // ClearAll;
internalFailure // Attributes = { HoldFirst };


internalFailure[ tag_String? stringQ, params___ ] :=
    With[ { msg := MessageName[ MessageFailureInternal, tag ] },
        Failure[ makeFailureTag @ msg,
                 <|
                     "MessageTemplate"   :> msg,
                     "MessageParameters" :> { $bugReportLink, params }
                 |>
        ] /; StringQ @ msg
    ];


internalFailure[ args___ ] := defaultInternalFailure @ args;


$bugReportLink := Hyperlink[
    "Report this issue \[RightGuillemet]",
    $bugReportURL
];


$bugReportURL := $bugReportURL =
    URLBuild @ <|
        "Scheme"   -> "https",
        "Domain"   -> "resources.wolframcloud.com",
        "Path"     -> { "FunctionRepository", "feedback-form" },
        "Fragment" -> "MessageFailure"
    |>;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*throwInternalFailure*)
throwInternalFailure // ClearAll;


throwInternalFailure[ args___ ] :=
    With[ { fail = internalFailure @ args },
        Message @ fail;
        If[ TrueQ @ $catching,
            Throw[ fail, $top ],
            fail
        ]
    ];


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*defaultInternalFailure*)
defaultInternalFailure // ClearAll;


defaultInternalFailure[ args___ ] :=
    Failure[ "MessageFailureInternal::unknown",
             <|
                 "MessageTemplate"   :> MessageFailureInternal::unknown,
                 "MessageParameters" :> { $bugReportLink, args }
             |>
    ];


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkFailureObject*)
checkFailureObject // ClearAll;


checkFailureObject[ failure_Failure? failureObjectQ ] := failure;


checkFailureObject[ other___ ] := internalFailure[ "invfail", other ];


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*includeStack*)
includeStack // ClearAll;


includeStack[ info_ ] :=
    includeStack[ info, $verbose, $stack ];


includeStack[ info_, verbose_, Full ] :=
    includeStack[ info, verbose, Full, Stack[ _ ] ];


includeStack[ info_, True, True ] :=
    includeStack[ info, True, True, Stack[ _ ] ];


includeStack[ info_, verbose_, type: True|Automatic ] :=
    includeStack[ info, verbose, type, HoldForm /@ Stack[ ] ];


includeStack[ info_, verbose_, _, stack_ ] :=
    Join[
        info,
        <|
            "IncludeStack" :> True,
            "Stack"        :> Evaluate @ trimStack[ stack, verbose ]
        |>
    ];


includeStack[ info_, ___ ] := info;


includeStack // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*trimStack*)
trimStack // ClearAll;


trimStack[ stack_, True ] := stack;


trimStack[
    {
        a___,
        HoldForm @ MessageFailure,
        ___
    },
    _
] := { a, HoldForm @ MessageFailure };


trimStack[
    {
        a___,
        HoldForm @ stacked,
        ___
    },
    _
] := { a };


trimStack[ { a___, b: _[ _MessageFailure ], ___ }, _ ] := { a, b };


trimStack[ { a___, HoldForm[ _stacked ], ___ }, _ ] := { a };


trimStack[ stack_, _ ] := stack;


trimStack // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*failureObjectQ*)
failureObjectQ // ClearAll;


failureObjectQ[ fail_Failure ] :=
    ! MatchQ[ fail[ "Tag" ], HoldPattern @ fail[ "Tag" ] ];


failureObjectQ[ ___ ] := False;


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Utilities*)


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getMessageFunction*)
getMessageFunction // ClearAll;
getMessageFunction // Attributes = { HoldFirst };


getMessageFunction[ template_, opts: $mfOpts ] :=
    chooseMessageFunction[
        template,
        OptionValue[ MessageFailure, { opts }, "MessageFunction" ],
        OptionValue[ MessageFailure, { opts }, "TestMode"        ]
    ];


getMessageFunction // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chooseMessageFunction*)
chooseMessageFunction // ClearAll;
chooseMessageFunction // Attributes = { HoldFirst };


chooseMessageFunction[ _, None, _ ] :=
    Function[ Null, Null, { HoldAllComplete } ];


chooseMessageFunction[ template_String, Automatic, _ ] :=
    templateMessageFunction[
        template,
        ResourceFunction[ "ResourceFunctionMessage", "Function" ]
    ];


chooseMessageFunction[ template_, rf: HoldPattern[ _ResourceFunction ], testing_ ] :=
    With[ { sym = ResourceFunction[ rf, "Function" ] },
        If[ symbolQ @ sym,
            chooseMessageFunction[ template, sym, testing ]
        ]
    ];


chooseMessageFunction[ template_String, mf_, _ ] :=
    templateMessageFunction[ template, mf ];


chooseMessageFunction[ MessageName[ sym_Symbol, __ ], Automatic, testing_ ] :=
    Block[ { $testMode = testing },
        If[ rfSymbolQ @ sym,
            ResourceFunction[ "ResourceFunctionMessage", "Function" ],
            Message
        ]
    ];


chooseMessageFunction[ _, mf_, _ ] := mf;


chooseMessageFunction // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*messageNameQ*)
messageNameQ // ClearAll;
messageNameQ // Attributes = { HoldAllComplete };

messageNameQ[ msg_MessageName ] :=
    MatchQ[ Unevaluated @ msg,
            Alternatives[
                _[ $symbol, $string ],
                _[ $symbol, $string, $string ]
            ]
    ];

messageNameQ[ ___ ] := False;


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*symbolQ*)
symbolQ // ClearAll;
symbolQ // Attributes = { HoldAllComplete };

symbolQ[ s_Symbol ] :=
    And[ AtomQ @ Unevaluated @ s,
         ! Internal`RemovedSymbolQ @ Unevaluated @ s,
         ! MatchQ[ Unevaluated @ s, Internal`$EFAIL ]
    ];

symbolQ[ ___ ] := False;


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stringQ*)
stringQ // ClearAll;
stringQ // Attributes = { HoldAllComplete };
stringQ[ s_String ] := StringQ @ Unevaluated @ s;
stringQ[ ___      ] := False;


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*tagQ*)
tagQ // ClearAll;
tagQ // Attributes = { HoldAllComplete };
tagQ[ _? stringQ ] := True;
tagQ[ _? symbolQ ] := True;
tagQ[ ___        ] := False;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*rfSymbolQ*)
rfSymbolQ // ClearAll;
rfSymbolQ // Attributes = { HoldAllComplete };
rfSymbolQ[ MessageFailure|MessageFailureInternal ] := ! TrueQ @ $testMode;
rfSymbolQ[ sym_Symbol? symbolQ ] /; $testMode := False;
rfSymbolQ[ sym_Symbol? symbolQ ] := TrueQ @ StringStartsQ[ Context @ sym, "FunctionRepository`" ];
rfSymbolQ[ ___ ] := False;


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*templateMessageFunction*)
templateMessageFunction // ClearAll;


templateMessageFunction[ template_, mf_ ] :=
    Function[ Null,
              mf[ MessageFailure::message, StringForm[ template, ##2 ] ],
              { HoldAllComplete }
    ];


templateMessageFunction // endDefinition;
EndPackage[ ];
