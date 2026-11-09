(* ::Package:: *)

(*
    Local copy of the "ASTPattern" resource function (version 1.0.0) from the Wolfram Function Repository.

    Resource: https://resources.wolframcloud.com/FunctionRepository/resources/ASTPattern
    Source:   generated from the published definition (ResourceFunction["ASTPattern", "DefinitionList"]) and formatted
              with the ReadableForm resource function; the development source of this function is
              https://github.com/rhennigan/ResourceFunctions/tree/main/Definitions/ASTPattern

    Kernel/Common.wl (importResourceFunction) loads this file in preference to fetching the resource function from
    the Function Repository, so the paclet can be built and loaded from source without cloud access. This directory
    is not part of the built paclet: the MX build inlines these definitions. The definitions are assigned as a
    definition list, exactly as the Function Repository publishes them (re-evaluating them as ordinary code would
    merge rules such as f[ args___ ] and its e: HoldPattern[ f[ ___ ] ] fallthrough), wrapped in BeginPackage/EndPackage
    so the symbols live in the "Wolfram`AgentTools`ResourceFunctions`ASTPattern`" context.
    Do not edit the definitions here; update the upstream resource function and regenerate the file
    (see ResourceFunctions/README.md).
*)

BeginPackage[ "Wolfram`AgentTools`ResourceFunctions`ASTPattern`" ];

Language`ExtendedFullDefinition[ ] = 
    Language`DefinitionList[
        HoldForm @ ASTPattern -> {
            DownValues -> {
                HoldPattern @ ASTPattern[ patt_ ] :>
                    catchTop @ Block[ { $ContextPath },
                        Needs[ "CodeParser`" ];
                        With[ { p = astBlockPattern @ patt },
                            checkDuplicatePatterns @ astPattern @ p
                        ]
                    ],
                HoldPattern @ ASTPattern[ patt_, meta_ ] :>
                    catchTop @ Block[ { $ContextPath },
                        Needs[ "CodeParser`" ];
                        With[ { p = astBlockPattern @ patt },
                            astPattern[ p, meta ]
                        ]
                    ]
            },
            DefaultValues -> { HoldPattern @ Options @ ASTPattern -> { } },
            Messages -> {
                HoldPattern @ ASTPattern::internal -> "An unexpected error occurred. `1`"
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ catchTop -> {
            DownValues -> {
                HoldPattern @ catchTop[ eval_ ] :>
                    Block[ { $catching = True, $failed = False, catchTop = #1 & },
                        Catch[ eval, $top ]
                    ],
                HoldPattern[ e: HoldPattern @ catchTop[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ throwInternalFailure -> {
            DownValues -> {
                HoldPattern @ throwInternalFailure[ eval_, a___ ] :>
                    throwFailure[
                        ASTPattern::internal,
                        $bugReportLink,
                        HoldForm @ eval,
                        a
                    ],
                HoldPattern[ e: HoldPattern @ throwInternalFailure[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ throwFailure -> {
            DownValues -> {
                HoldPattern @ throwFailure[ tag_String, params___ ] :>
                    throwFailure[ MessageName[ ASTPattern, tag ], params ],
                HoldPattern @ throwFailure[ msg_, args___ ] :>
                    Module[ { failure },
                        
                        failure = 
                            messageFailure[ msg, Sequence @@ (HoldForm /@ { args }) ];

                        If[ TrueQ @ $catching, Throw[ failure, $top ], failure ]
                    ],
                HoldPattern[ e: HoldPattern @ throwFailure[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ messageFailure -> {
            DownValues -> {
                HoldPattern @ messageFailure[ args___ ] :>
                    Module[ { quiet },
                        quiet = If[ TrueQ @ $failed, Quiet, Identity ];
                        WithCleanup[
                            quiet @ ResourceFunction[
                                "MessageFailure"
                            ][ args ],
                            $failed = True
                        ]
                    ],
                HoldPattern[ e: HoldPattern @ messageFailure[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ $bugReportLink -> {
            OwnValues -> {
                HoldPattern @ $bugReportLink :>
                    ($bugReportLink = 
                        Hyperlink[
                            "Report this issue »",
                            URLBuild @ <|
                                "Scheme" -> "https",
                                "Domain" -> "resources.wolframcloud.com",
                                "Path" -> { "FunctionRepository", "feedback-form" },
                                "Fragment" -> SymbolName @ ASTPattern
                            |>
                        ])
            }
        },
        HoldForm @ astBlockPattern -> {
            DownValues -> {
                HoldPattern @ astBlockPattern[ patt: Verbatim[
                    HoldPattern
                ][ ___ ] ] :> patt,
                HoldPattern @ astBlockPattern[ patt_ ] :>
                    Block[ { ASTPattern },
                        SetAttributes[ ASTPattern, HoldFirst ];
                        HoldPattern @ Evaluate @ patt
                    ],
                HoldPattern[ e: HoldPattern @ astBlockPattern[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ checkDuplicatePatterns -> {
            DownValues -> {
                HoldPattern @ checkDuplicatePatterns[ p_ ] :>
                    Module[ { names, realDups, possibleDups, dups },
                        
                        names = 
                            Cases[
                                p,
                                Verbatim[ Pattern ][ s_, _ ] :> HoldPattern @ s,
                                Infinity
                            ];

                        realDups = Select[ Counts @ names, GreaterThan[ 1 ] ];
                        
                        possibleDups = Association @ Cases[
                            p,
                            (Repeated | RepeatedNull)[ a_, ___ ] :>
                                Cases[
                                    HoldComplete @ a,
                                    Verbatim[ Pattern ][ s_, _ ] :>
                                        (HoldPattern @ s -> Infinity),
                                    Infinity
                                ],
                            Infinity
                        ];

                        
                        dups = 
                            KeyDrop[
                                Join[ realDups, possibleDups ],
                                HoldPattern @ e
                            ];

                        If[ TrueQ[ Length @ dups > 0 ],
                            rebindConditionPattern[ p, dups ],
                            p
                        ]
                    ],
                HoldPattern[ e: HoldPattern @ checkDuplicatePatterns[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ rebindConditionPattern -> {
            DownValues -> {
                HoldPattern @ rebindConditionPattern[ p_, dups_ ] :>
                    Module[
                        {
                            $replacements,
                            unseen,
                            patt,
                            replaced,
                            conditions,
                            flat,
                            rhsHeld,
                            lhsHeld
                        },
                        $replacements = <| |>;
                        
                        unseen = 
                            AssociationMap[
                                True &,
                                Apply[ HoldComplete, Keys @ dups, { 1 } ]
                            ];

                        patt = Alternatives @@ Keys @ dups;
                        
                        replaced = 
                            ReplaceAll[
                                p,
                                {
                                    s: patt /; unseen @ HoldComplete @ s :>
                                        With[ { e = Null },
                                            unseen[ HoldComplete @ s ] = False;
                                            
                                            $replacements[ HoldComplete @ s ] = 
                                                HoldComplete @ s;

                                            s /; True
                                        ],
                                    s: patt /; ! unseen @ HoldComplete @ s :>
                                        With[ { a = newPattSym @ s },
                                            
                                            $replacements[ HoldComplete @ a ] = 
                                                HoldComplete @ s;

                                            a /; True
                                        ]
                                }
                            ];

                        
                        conditions = 
                            Cases[
                                GroupBy[ Normal @ $replacements, Last -> First ],
                                { syms__ } :>
                                    Replace[
                                        Flatten @ HoldComplete @ syms,
                                        HoldComplete[ a___ ] :>
                                            HoldComplete @ EquivalentNodeQ @ a
                                    ]
                            ];

                        flat = Flatten[ HoldComplete @@ conditions ];
                        
                        rhsHeld = 
                            Replace[
                                flat,
                                HoldComplete[ a_, b__ ] :> HoldComplete[ a && b ]
                            ];

                        lhsHeld = HoldComplete @@ { replaced };
                        Apply[
                            Condition,
                            Flatten[ HoldComplete @@ { lhsHeld, rhsHeld } ]
                        ]
                    ],
                HoldPattern[ e: HoldPattern @ rebindConditionPattern[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ newPattSym -> {
            DownValues -> {
                HoldPattern @ newPattSym[ s_? symbolQ ] :>
                    Module @@ HoldComplete[ { s }, s ],
                HoldPattern[ e: HoldPattern @ newPattSym[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldAllComplete }
        },
        HoldForm @ symbolQ -> {
            DownValues -> {
                HoldPattern @ symbolQ[ s_Symbol ] :>
                    TrueQ @ And[
                        AtomQ @ Unevaluated @ s,
                        ! Internal`RemovedSymbolQ @ Unevaluated @ s,
                        Unevaluated @ s =!= Internal`$EFAIL
                    ],
                HoldPattern @ symbolQ[ ___ ] :> False
            },
            Attributes -> { HoldAllComplete }
        },
        HoldForm @ EquivalentNodeQ -> {
            DownValues -> {
                HoldPattern @ EquivalentNodeQ[ nodes___ ] :>
                    Apply[
                        SameQ,
                        DeleteCases[
                            { nodes },
                            KeyValuePattern[ CodeParser`Source -> _ ],
                            Infinity
                        ]
                    ],
                HoldPattern[ e: HoldPattern @ EquivalentNodeQ[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            FormatValues -> {
                HoldPattern @ MakeBoxes[ EquivalentNodeQ[ a___ ], StandardForm ] :>
                    With[
                        {
                            row = 
                                RowBox @ Riffle[
                                    Cases[
                                        HoldComplete @ a,
                                        e_ :> MakeBoxes[ e, StandardForm ]
                                    ],
                                    StyleBox[
                                        "≃",
                                        FontColor -> Orange,
                                        FontWeight -> "Heavy"
                                    ]
                                ],
                            tt = 
                                ToBoxes @ HoldForm @ HoldForm[
                                    EquivalentNodeQ
                                ][ a ],
                            col = ColorData[ 97 ][ 3 ]
                        },
                        InterpretationBox[
                            FrameBox[
                                TooltipBox[ row, tt ],
                                RoundingRadius -> 3,
                                FrameStyle -> col,
                                FrameMargins -> { { 4, 4 }, { 1, 1 } }
                            ],
                            EquivalentNodeQ @ a
                        ]
                    ]
            }
        },
        HoldForm @ astPattern -> {
            DownValues -> {
                HoldPattern[
                    astPattern[ patt_ ] /;
                        ! FreeQ[ Unevaluated @ patt, _ASTPattern ]
                ] :>
                    Module[ { held, expanded, new },
                        held = HoldComplete @ patt;
                        expanded = expandNestedASTPatterns @ held;
                        new = astPattern @@ expanded;
                        new /. $astPattern[ a_ ] :> a
                    ],
                HoldPattern @ astPattern @ Verbatim[ Pattern ][ sym_Symbol? symbolQ, patt_ ] :>
                    Pattern @@ Hold[ sym, astPattern @ patt ],
                HoldPattern @ astPattern[ patt_ASTPattern ] :> patt,
                HoldPattern @ astPattern[ patt_$astPattern ] :> patt,
                HoldPattern @ astPattern @ Verbatim[
                    Verbatim
                ][ a_ ] :>
                    verbatimAST @ a,
                HoldPattern @ astPattern @ Verbatim[
                    HoldPattern
                ][ a_ ] :>
                    astPattern @ a,
                HoldPattern @ astPattern @ Verbatim[
                    Alternatives
                ][ a___ ] :>
                    Alternatives @@ (astPattern /@ HoldComplete @ a),
                HoldPattern @ astPattern @ Verbatim[ _ ] :> callOrLeafNode[ ],
                HoldPattern @ astPattern @ Verbatim[ __ ] :> callOrLeafNode[ ]..,
                HoldPattern @ astPattern @ Verbatim[ ___ ] :> callOrLeafNode[ ]...,
                HoldPattern @ astPattern @ Verbatim[
                    Blank
                ][ sym_? symbolQ ] :>
                    blank @ sym,
                HoldPattern @ astPattern @ Verbatim[
                    BlankSequence
                ][ sym_? symbolQ ] :>
                    blank @ sym..,
                HoldPattern @ astPattern @ Verbatim[
                    BlankNullSequence
                ][ sym_? symbolQ ] :>
                    blank @ sym...,
                HoldPattern @ astPattern @ Verbatim[ Repeated ][ x_, a___ ] :>
                    Repeated[ astPattern @ x, a ],
                HoldPattern @ astPattern @ Verbatim[ RepeatedNull ][ x_, a___ ] :>
                    RepeatedNull[ astPattern @ x, a ],
                HoldPattern @ astPattern @ Verbatim[
                    Except
                ][ c_ ] :>
                    Except[ astPattern @ c ],
                HoldPattern @ astPattern @ Verbatim[ Except ][ c_, p_ ] :>
                    Except[ astPattern @ c, astPattern @ p ],
                HoldPattern @ astPattern @ Verbatim[
                    PatternSequence
                ][ a___ ] :>
                    PatternSequence @@ (astPattern /@ HoldComplete @ a),
                HoldPattern @ astPattern @ Verbatim[ PatternTest ][
                    Verbatim[ Pattern ][ s_Symbol? symbolQ, patt_ ],
                    test_
                ] :>
                    With[ { p = astPattern[ patt? test ] },
                        Pattern @@ HoldComplete[ s, p ]
                    ],
                HoldPattern[
                    astPattern @ Verbatim[ PatternTest ][
                        Verbatim[
                            Blank
                        ][ head_? symbolQ ],
                        test_
                    ] /;
                        leafTestQ[ head, test ]
                ] :>
                    leafNode @ head,
                HoldPattern[
                    astPattern @ Verbatim[ PatternTest ][
                        Verbatim[
                            BlankSequence
                        ][ head_? symbolQ ],
                        test_
                    ] /;
                        leafTestQ[ head, test ]
                ] :>
                    leafNode @ head..,
                HoldPattern[
                    astPattern @ Verbatim[ PatternTest ][
                        Verbatim[
                            BlankNullSequence
                        ][ head_? symbolQ ],
                        test_
                    ] /;
                        leafTestQ[ head, test ]
                ] :>
                    leafNode @ head...,
                HoldPattern @ astPattern @ Verbatim[ PatternTest ][ patt_, test_ ] :>
                    With[ { p = astPattern @ patt },
                        PatternTest @@ HoldComplete[ p, ASTPatternTest @ test ]
                    ],
                HoldPattern @ astPattern[ sym_Symbol? symbolQ ] :>
                    symNamePatt @ sym,
                HoldPattern[ astPattern[ r_Rational ] /; AtomQ @ Unevaluated @ r ] :>
                    rationalPattern @ r,
                HoldPattern[ astPattern[ c_Complex ] /; AtomQ @ Unevaluated @ c ] :>
                    complexPattern @ c,
                HoldPattern[
                    astPattern[ expr: _Integer | _Real | _String ] /;
                        AtomQ @ Unevaluated @ expr
                ] :>
                    leafNode[ Head @ expr, ToString[ expr, InputForm ] ],
                HoldPattern @ astPattern @ Verbatim[ Condition ][ patt_, test_ ] :>
                    (ReplaceAll[
                        ReplaceAll[
                            makeASTCondition[ patt, test ],
                            $ASTCondition[ { }, cond_ ] :> cond
                        ],
                        $ASTCondition -> ASTCondition
                    ]),
                HoldPattern @ astPattern[ (head_)[ args___ ] ] :>
                    CodeParser`CallNode[
                        astPattern @ head,
                        astPattern /@ Unevaluated @ { args },
                        _
                    ],
                HoldPattern @ astPattern[ patt_, meta_ ] :>
                    insertMetaPatt[
                        checkDuplicatePatterns @ astPattern @ patt,
                        meta
                    ],
                HoldPattern @ astPattern[ a___ ] :>
                    throwInternalFailure @ astPattern @ a
            },
            Attributes -> { HoldAllComplete }
        },
        HoldForm @ expandNestedASTPatterns -> {
            DownValues -> {
                HoldPattern @ expandNestedASTPatterns[ expr_ ] :>
                    (ReplaceAll[
                        expandNestedResourceFunctions @ expr,
                        {
                            Verbatim[
                                Verbatim
                            ][ a___ ] :> Verbatim[a],
                            HoldPattern @ ASTPattern[ a___ ] :>
                                With[ { p = astPattern @ a },
                                    $astPattern @ p /; True
                                ]
                        }
                    ]),
                HoldPattern[ e: HoldPattern @ expandNestedASTPatterns[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ expandNestedResourceFunctions -> {
            DownValues -> {
                HoldPattern[ expandNestedResourceFunctions[ expr_ ] /; $rfTest ] :>
                    (ReplaceAll[
                        expr,
                        rf: $rfPatt :>
                            With[ { sym = rfSymExpand @ rf },
                                sym /; sym === ASTPattern
                            ]
                    ]),
                HoldPattern @ expandNestedResourceFunctions[ expr_ ] :> expr,
                HoldPattern[ e: HoldPattern @ expandNestedResourceFunctions[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ $rfTest -> {
            OwnValues -> {
                HoldPattern @ $rfTest :>
                    ($rfTest = 
                        StringStartsQ[
                            Context @ ASTPattern,
                            "FunctionRepository`"
                        ])
            }
        },
        HoldForm @ $rfPatt -> {
            OwnValues ->
                (HoldPattern @ $rfPatt :>
                    HoldPattern[ ResourceFunction ][
                        Alternatives[
                            Alternatives[
                                "ASTPattern",
                                Association[ ___, "Name" -> "ASTPattern", ___ ]
                            ],
                            HoldPattern[ ResourceObject ][
                                Alternatives[
                                    "ASTPattern",
                                    Association[
                                        ___,
                                        "Name" -> "ASTPattern",
                                        ___
                                    ]
                                ],
                                OptionsPattern[ ]
                            ]
                        ],
                        OptionsPattern[ ]
                    ]
)
        },
        HoldForm @ rfSymExpand -> {
            DownValues -> {
                HoldPattern @ rfSymExpand[ rf_ ] :>
                    (rfSymExpand[ rf ] = Quiet @ ResourceFunction[ rf, "Function" ])
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ $astPattern -> { Attributes -> { HoldAllComplete } },
        HoldForm @ verbatimAST -> {
            DownValues -> {
                HoldPattern @ verbatimAST[ sym_Symbol? symbolQ ] :>
                    symNamePatt @ sym,
                HoldPattern[ verbatimAST[ r_Rational ] /; AtomQ @ Unevaluated @ r ] :>
                    rationalPattern @ r,
                HoldPattern[ verbatimAST[ c_Complex ] /; AtomQ @ Unevaluated @ c ] :>
                    complexPattern @ c,
                HoldPattern[
                    verbatimAST[ expr: _Integer | _Real | _String ] /;
                        AtomQ @ Unevaluated @ expr
                ] :>
                    leafNode[ Head @ expr, ToString[ expr, InputForm ] ],
                HoldPattern @ verbatimAST[ (head_)[ args___ ] ] :>
                    CodeParser`CallNode[
                        astPattern @ head,
                        astPattern /@ Unevaluated @ { args },
                        _
                    ],
                HoldPattern[ e: HoldPattern @ verbatimAST[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldAllComplete }
        },
        HoldForm @ symNamePatt -> {
            DownValues -> {
                HoldPattern @ symNamePatt[ sym_Symbol? symbolQ ] :>
                    With[
                        {
                            name = SymbolName @ Unevaluated @ sym,
                            ctx = Context @ Unevaluated @ sym
                        },
                        CodeParser`LeafNode[
                            Symbol,
                            name | ctx <> name,
                            _
                        ]
                    ],
                HoldPattern[ e: HoldPattern @ symNamePatt[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldAllComplete }
        },
        HoldForm @ rationalPattern -> {
            DownValues -> {
                HoldPattern @ rationalPattern[ r_ ] :>
                    rationalPattern[ Numerator @ r, Denominator @ r ],
                HoldPattern @ rationalPattern[ n_, d_ ] :>
                    Module[ { na, da, mo, pw },
                        na = astPattern @ n;
                        da = astPattern @ d;
                        mo = leafNode[ Integer, "-1" ];
                        pw = callNode[ symbolNode[ "Power" ], { da, mo } ];
                        callNode[ symbolNode[ "Times" ], { na, pw } ]
                    ],
                HoldPattern[ e: HoldPattern @ rationalPattern[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ leafNode -> {
            DownValues -> {
                HoldPattern @ leafNode[ ] :> CodeParser`LeafNode[ _, _, _ ],
                HoldPattern @ leafNode[ a_ ] :> CodeParser`LeafNode[ a, _, _ ],
                HoldPattern @ leafNode[ a_, b_ ] :> CodeParser`LeafNode[ a, b, _ ],
                HoldPattern @ leafNode[ a_, b_, c_ ] :>
                    CodeParser`LeafNode[ a, b, c ],
                HoldPattern[ e: HoldPattern @ leafNode[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ callNode -> {
            DownValues -> {
                HoldPattern @ callNode[ ] :> CodeParser`CallNode[ _, _, _ ],
                HoldPattern @ callNode[ a_ ] :> CodeParser`CallNode[ a, _, _ ],
                HoldPattern @ callNode[ a_, b_ ] :> CodeParser`CallNode[ a, b, _ ],
                HoldPattern @ callNode[ a_, b_, c_ ] :>
                    CodeParser`CallNode[ a, b, c ],
                HoldPattern[ e: HoldPattern @ callNode[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ symbolNode -> {
            DownValues -> {
                HoldPattern @ symbolNode[ name_String ] :>
                    CodeParser`LeafNode[ Symbol, name, _ ],
                HoldPattern @ symbolNode[ sym_? symbolQ ] :> symNamePatt @ sym,
                HoldPattern[ e: HoldPattern @ symbolNode[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ complexPattern -> {
            DownValues -> {
                HoldPattern @ complexPattern[ c_ ] :> complexPattern[ Re @ c, Im @ c ],
                HoldPattern @ complexPattern[ r_, i_ ] :>
                    Module[ { ra, ia, im },
                        ra = astPattern @ r;
                        ia = astPattern @ i;
                        
                        im = 
                            callNode[
                                symbolNode[ "Times" ],
                                { ia, symbolNode[ "I" ] }
                            ];

                        callNode[ symbolNode[ "Plus" ], { ra, im } ]
                    ],
                HoldPattern[ e: HoldPattern @ complexPattern[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ callOrLeafNode -> {
            DownValues -> {
                HoldPattern @ callOrLeafNode[ ] :>
                    (CodeParser`CallNode | CodeParser`LeafNode)[ _, _, _ ],
                HoldPattern @ callOrLeafNode[ a_ ] :>
                    (CodeParser`CallNode | CodeParser`LeafNode)[ a, _, _ ],
                HoldPattern @ callOrLeafNode[ a_, b_ ] :>
                    (CodeParser`CallNode | CodeParser`LeafNode)[ a, b, _ ],
                HoldPattern @ callOrLeafNode[ a_, b_, c_ ] :>
                    (CodeParser`CallNode | CodeParser`LeafNode)[ a, b, c ],
                HoldPattern[ e: HoldPattern @ callOrLeafNode[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ blank -> {
            DownValues -> {
                HoldPattern @ blank[ sym_? leafHeadQ ] :>
                    callOrLeafNode[ sym | symNamePatt @ sym, _, _ ],
                HoldPattern @ blank[ sym_ ] :> callNode @ symNamePatt @ sym,
                HoldPattern[ e: HoldPattern @ blank[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldAllComplete }
        },
        HoldForm @ leafHeadQ -> {
            DownValues -> {
                HoldPattern @ leafHeadQ[
                    Complex | Integer | Rational | Real | String | Symbol
                ] :> True,
                HoldPattern @ leafHeadQ[ ___ ] :> False
            },
            Attributes -> { HoldAllComplete }
        },
        HoldForm @ leafTestQ -> {
            DownValues -> {
                HoldPattern @ leafTestQ[ Integer, IntegerQ ] :> True,
                HoldPattern @ leafTestQ[ Real, Developer`RealQ ] :> True,
                HoldPattern @ leafTestQ[ String, StringQ ] :> True,
                HoldPattern @ leafTestQ[ _? leafHeadQ, AtomQ ] :> True,
                HoldPattern @ leafTestQ[ ___ ] :> False
            },
            Attributes -> { HoldAllComplete }
        },
        HoldForm @ ASTPatternTest -> {
            SubValues -> { HoldPattern @ ASTPatternTest[ (func_) ][ node_ ] :> FromAST[ node, func ] },
            FormatValues -> {
                HoldPattern @ MakeBoxes[ ASTPatternTest[ f_ ], StandardForm ] :>
                    With[
                        {
                            row = MakeBoxes[ f, StandardForm ],
                            tt = 
                                MakeBoxes[
                                    HoldForm[
                                        ASTPatternTest
                                    ][ f ],
                                    StandardForm
                                ],
                            col = ColorData[ 97 ][ 1 ]
                        },
                        InterpretationBox[
                            FrameBox[
                                TooltipBox[ row, tt ],
                                RoundingRadius -> 3,
                                FrameStyle -> col,
                                FrameMargins -> { { 4, 4 }, { 1, 1 } }
                            ],
                            ASTPatternTest @ f
                        ]
                    ]
            }
        },
        HoldForm @ FromAST -> {
            DownValues -> {
                HoldPattern @ FromAST[ ast_ ] :> FromAST[ ast, ##1 & ],
                HoldPattern @ FromAST[
                    ast: _CodeParser`LeafNode | _CodeParser`CallNode,
                    wrapper_
                ] :>
                    ToExpression[
                        CodeParser`ToFullFormString @ ast,
                        InputForm,
                        wrapper
                    ],
                HoldPattern @ FromAST[ CodeParser`ContainerNode[ _, ast_List, _ ], wrapper_ ] :>
                    FromAST[ ast, wrapper ],
                HoldPattern @ FromAST[ ast_List, wrapper_ ] :>
                    (FromAST[ #1, wrapper ] &) /@ ast,
                HoldPattern[ e: HoldPattern @ FromAST[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ makeASTCondition -> {
            DownValues -> {
                HoldPattern @ makeASTCondition[ lhs_, rhs_ ] :>
                    Module[ { syms, bound, vals, hs, cvRules, cv },
                        syms = DeleteDuplicates @ patternSymbols @ lhs;
                        bound = Select[ syms, appearsIn @ rhs ];
                        vals = Array[ ASTConditionValue, Length @ bound ];
                        hs = Cases[ bound, e_ :> HoldPattern @ e ];
                        cvRules = Thread[ hs -> vals ];
                        cv = HoldComplete @ rhs /. cvRules;
                        Apply[
                            Condition,
                            Replace[
                                { bound, cv },
                                { HoldComplete[ s___ ], HoldComplete[ c_ ] } :> {
                                    checkDuplicatePatterns @ astPattern @ lhs,
                                    $ASTCondition[ { s }, c ]
                                }
                            ]
                        ]
                    ],
                HoldPattern[ e: HoldPattern @ makeASTCondition[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldAll }
        },
        HoldForm @ patternSymbols -> {
            DownValues -> {
                HoldPattern @ patternSymbols[ patt_ ] :>
                    Flatten[ HoldComplete @@ patternSymbols0 @ patt ],
                HoldPattern[ e: HoldPattern @ patternSymbols[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ patternSymbols0 -> {
            DownValues -> {
                HoldPattern @ patternSymbols0[ patt_ ] :>
                    Cases[
                        HoldComplete @ patt,
                        Verbatim[ Pattern ][ s_Symbol? symbolQ, _ ] :>
                            HoldComplete @ s,
                        Infinity,
                        Heads -> True
                    ],
                HoldPattern[ e: HoldPattern @ patternSymbols0[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ appearsIn -> {
            DownValues -> {
                HoldPattern @ appearsIn[ rhs_ ] :>
                    (Function[
                        s,
                        ! FreeQ[ Unevaluated @ rhs, HoldPattern @ s ],
                        HoldFirst
                    ]),
                HoldPattern[ e: HoldPattern @ appearsIn[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ $ASTCondition -> { Attributes -> { HoldAllComplete } },
        HoldForm @ ASTCondition -> {
            DownValues -> {
                HoldPattern @ ASTCondition[ vals_List, cond_ ] :>
                    Module[ { rules, replaced },
                        rules = MapIndexed[ astCVRule, vals ];
                        replaced = HoldComplete @ cond /. rules;
                        ReleaseHold[ replaced /. $conditionHold[ e_ ] :> e ]
                    ],
                HoldPattern[ e: HoldPattern @ ASTCondition[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            FormatValues -> {
                HoldPattern @ MakeBoxes[ ASTCondition[ vals_List, cond_ ], StandardForm ] :>
                    Module[ { rules, replaced },
                        rules = MapIndexed[ astCVBoxRule, vals ];
                        replaced = HoldComplete @ cond /. rules;
                        Replace[
                            replaced /. $conditionHold[ e_ ] :> e,
                            HoldComplete[ e_ ] :>
                                With[
                                    {
                                        box = 
                                            MakeBoxes[
                                                Tooltip[
                                                    e,
                                                    HoldForm[ ASTCondition ][
                                                        vals,
                                                        cond
                                                    ]
                                                ],
                                                StandardForm
                                            ],
                                        col = ColorData[ 97 ][ 2 ]
                                    },
                                    InterpretationBox[
                                        FrameBox[
                                            box,
                                            RoundingRadius -> 3,
                                            FrameStyle -> col,
                                            FrameMargins -> { { 4, 4 }, { 1, 1 } }
                                        ],
                                        ASTCondition[ vals, cond ]
                                    ]
                                ]
                        ]
                    ]
            },
            Attributes -> { HoldRest }
        },
        HoldForm @ astCVRule -> {
            DownValues -> {
                HoldPattern @ astCVRule[ node_, { pos_ } ] :>
                    (ASTConditionValue @ pos -> FromAST[ node, $conditionHold ]),
                HoldPattern[ e: HoldPattern @ astCVRule[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ $conditionHold -> { Attributes -> { HoldAllComplete } },
        HoldForm @ astCVBoxRule -> {
            DownValues -> {
                HoldPattern @ astCVBoxRule[ node_, { pos_ } ] :>
                    (ASTConditionValue @ pos -> node),
                HoldPattern[ e: HoldPattern @ astCVBoxRule[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            },
            Attributes -> { HoldFirst }
        },
        HoldForm @ insertMetaPatt -> {
            DownValues -> {
                HoldPattern @ insertMetaPatt[
                    (h: CodeParser`CallNode | CodeParser`LeafNode)[ a_, b_, _ ],
                    meta_
                ] :>
                    h[ a, b, meta ],
                HoldPattern @ insertMetaPatt[
                    (h: Verbatim[ CodeParser`CallNode | CodeParser`LeafNode ])[
                        a_,
                        b_,
                        _
                    ],
                    meta_
                ] :>
                    h[ a, b, meta ],
                HoldPattern @ insertMetaPatt[ Verbatim[ Pattern ][ s_, p_ ], meta_ ] :>
                    With[ { ins = insertMetaPatt[ p, meta ] },
                        Pattern @@ Hold[ s, ins ]
                    ],
                HoldPattern @ insertMetaPatt[ patt_Alternatives, meta_ ] :>
                    (insertMetaPatt[ #1, meta ] &) /@ patt,
                HoldPattern @ insertMetaPatt[ Verbatim[ Condition ][ lhs_, rhs_ ], meta_ ] :>
                    With[ { ins = insertMetaPatt[ lhs, meta ] },
                        Condition @@ Hold[ ins, rhs ]
                    ],
                HoldPattern[ e: HoldPattern @ insertMetaPatt[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        }
    ];

EndPackage[ ];
