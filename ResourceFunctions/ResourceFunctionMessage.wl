(* ::Package:: *)

(*
    Local copy of the "ResourceFunctionMessage" resource function (version 2.1.1) from the Wolfram Function Repository.

    Resource: https://resources.wolframcloud.com/FunctionRepository/resources/ResourceFunctionMessage
    Source:   generated from the published definition (ResourceFunction["ResourceFunctionMessage", "DefinitionList"]) and formatted
              with the ReadableForm resource function; the development source of this function is
              https://github.com/rhennigan/ResourceFunctions/tree/main/Definitions/ResourceFunctionMessage

    Kernel/Common.wl (importResourceFunction) loads this file in preference to fetching the resource function from
    the Function Repository, so the paclet can be built and loaded from source without cloud access. This directory
    is not part of the built paclet: the MX build inlines these definitions. The definitions are assigned as a
    definition list, exactly as the Function Repository publishes them (re-evaluating them as ordinary code would
    merge rules such as f[ args___ ] and its e: HoldPattern[ f[ ___ ] ] fallthrough), wrapped in BeginPackage/EndPackage
    so the symbols live in the "Wolfram`AgentTools`ResourceFunctions`ResourceFunctionMessage`" context.
    Do not edit the definitions here; update the upstream resource function and regenerate the file
    (see ResourceFunctions/README.md).
*)

BeginPackage[ "Wolfram`AgentTools`ResourceFunctions`ResourceFunctionMessage`" ];

Language`ExtendedFullDefinition[ ] = 
    Language`DefinitionList[
        HoldForm @ ResourceFunctionMessage -> {
            DownValues -> {
                HoldPattern @ ResourceFunctionMessage[
                    msg: HoldPattern @ MessageName[ symbol_Symbol, tag: Repeated[ _String, { 1, 2 } ] ],
                    args___
                ] :>
                    If[ TrueQ[ ! messageQuietedQ @ msg ],
                        Module[ { label, template, message },
                            checkUserMessage[ ];
                            label = messageLabelBox[ symbol, tag ];
                            
                            template = 
                                messageTemplate[
                                    symbol,
                                    tag,
                                    HoldComplete @ args
                                ];

                            message = padTemplate[ template, args ];
                            Message[
                                ResourceFunction::usermessage,
                                Row @ { label, ": ", message }
                            ]
                        ],
                        Null
                    ]
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ messageQuietedQ -> {
            DownValues -> {
                HoldPattern @ messageQuietedQ[ msg: MessageName[ _Symbol, tag___ ] ] :>
                    Module[ { stack, msgOrGeneral, msgPatt },
                        stack = Lookup[ Internal`QuietStatus[ ], Stack ];
                        msgOrGeneral = generalMessagePattern @ msg;
                        msgPatt = All | { ___, msgOrGeneral, ___ };
                        TrueQ @ And[
                            FreeQ[ stack, { _, _, msgPatt }, 2 ],
                            ! FreeQ[ stack, { _, msgPatt, _ }, 2 ]
                        ]
                    ]
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ generalMessagePattern -> {
            DownValues -> {
                HoldPattern @ generalMessagePattern[ msg: MessageName[ _Symbol, tag___ ] ] :>
                    If[ StringQ @ msg,
                        HoldPattern @ msg,
                        HoldPattern[ msg | MessageName[ General, tag ] ]
                    ]
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ checkUserMessage -> {
            DownValues -> {
                HoldPattern @ checkUserMessage[ ] :>
                    If[ ! StringQ @ ResourceFunction::usermessage,
                        Internal`WithLocalSettings[
                            Unprotect @ ResourceFunction,
                            ResourceFunction::usermessage = "`1`",
                            Protect @ ResourceFunction
                        ]
                    ]
            }
        },
        HoldForm @ messageLabelBox -> {
            DownValues -> {
                HoldPattern @ messageLabelBox[ symbol_Symbol, tag__String ] :>
                    With[ { symName = SymbolName @ Unevaluated @ symbol },
                        RawBoxes @ StyleBox[ RowBox @ { symName, "::", tag }, "MessageName" ]
                    ]
            }
        },
        HoldForm @ messageTemplate -> {
            DownValues -> {
                HoldPattern @ messageTemplate[ symbol_Symbol, tag__String, args_HoldComplete ] :>
                    Replace[
                        MessageName[ symbol, tag ],
                        Except[ _String? StringQ ] :>
                            Replace[
                                MessageName[ General, tag ],
                                Except[ _String? StringQ ] :>
                                    StringJoin[
                                        "-- Message text not found --",
                                        StringJoin @ Table[
                                            { " (`", ToString @ i, "`)" },
                                            { i, Length @ args }
                                        ]
                                    ]
                            ]
                    ]
            }
        },
        HoldForm @ padTemplate -> {
            DownValues -> {
                HoldPattern @ padTemplate[ template_String, args___ ] :>
                    With[
                        {
                            sc = slotCount @ template,
                            ac = Length @ HoldComplete @ args
                        },
                        Row @ TemplateApply[
                            DeleteCases[
                                StringTemplate @ template,
                                InsertionFunction | CombinerFunction -> _
                            ],
                            {
                                args,
                                Sequence @@ ConstantArray[ "", Max[ 0, sc - ac ] ]
                            }
                        ]
                    ]
            }
        },
        HoldForm @ slotCount -> {
            DownValues -> {
                HoldPattern @ slotCount[ template_String ] :>
                    Count[
                        StringTemplate @ template,
                        TemplateSlot[ _Integer ],
                        { 2 }
                    ]
            }
        }
    ];

EndPackage[ ];
