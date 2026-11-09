(* ::Package:: *)

(*
    Local copy of the "ExportMarkdownString" resource function (version 1.0.0) from the Wolfram Function Repository.

    Resource: https://resources.wolframcloud.com/FunctionRepository/resources/ExportMarkdownString
    Source:   generated from the published definition (ResourceFunction["ExportMarkdownString", "DefinitionList"]) and formatted
              with the ReadableForm resource function; the development source of this function is
              https://github.com/rhennigan/ResourceFunctions/tree/main/Definitions/ExportMarkdownString

    Kernel/Common.wl (importResourceFunction) loads this file in preference to fetching the resource function from
    the Function Repository, so the paclet can be built and loaded from source without cloud access. This directory
    is not part of the built paclet: the MX build inlines these definitions. The definitions are assigned as a
    definition list, exactly as the Function Repository publishes them (re-evaluating them as ordinary code would
    merge rules such as f[ args___ ] and its e: HoldPattern[ f[ ___ ] ] fallthrough), wrapped in BeginPackage/EndPackage
    so the symbols live in the "Wolfram`AgentTools`ResourceFunctions`ExportMarkdownString`" context.
    Do not edit the definitions here; update the upstream resource function and regenerate the file
    (see ResourceFunctions/README.md).
*)

BeginPackage[ "Wolfram`AgentTools`ResourceFunctions`ExportMarkdownString`" ];

Language`ExtendedFullDefinition[ ] = 
    Language`DefinitionList[
        HoldForm @ ExportMarkdownString -> {
            DownValues -> {
                HoldPattern @ ExportMarkdownString[ ] :>
                    catchTop @ throwFailure[ "ArgumentCount", 0, 2 ],
                HoldPattern @ ExportMarkdownString[ expr_, opts0: OptionsPattern[ ] ] :>
                    catchTop @ Enclose[
                        Module[
                            {
                                converted,
                                boxes,
                                opts,
                                imageExportMethod,
                                contentTypes,
                                string
                            },
                            Needs[ "Wolfram`Chatbook`" -> None ];
                            
                            converted = 
                                ConfirmMatch[
                                    convertInput @ expr,
                                    $$supported,
                                    "ConvertInput"
                                ];

                            
                            boxes = 
                                Replace[
                                    converted,
                                    RawBoxes[ b_ ] :> b,
                                    If[ ListQ @ converted, { 1 }, { 0 } ]
                                ];

                            opts = FilterRules[ { opts0 }, Options @ cellToString ];
                            
                            imageExportMethod = 
                                OptionValue[ "ImageExportMethod" ];

                            
                            contentTypes = 
                                ConfirmMatch[
                                    determineContentTypes @ imageExportMethod,
                                    { __String },
                                    "ContentTypes"
                                ];

                            
                            string = 
                                ConfirmBy[
                                    cellToString[
                                        boxes,
                                        opts,
                                        "ContentTypes" -> contentTypes
                                    ],
                                    StringQ,
                                    "Result"
                                ];

                            ConfirmBy[
                                exportImages[ string, imageExportMethod ],
                                StringQ,
                                "ExportImages"
                            ]
                        ],
                        throwInternalFailure
                    ],
                HoldPattern[
                    e: ExportMarkdownString[
                        _,
                        invalid: Except[ OptionsPattern[ ] ],
                        ___
                    ]
                ] :>
                    catchTop @ throwFailure[ "OptionsExpected", invalid, 2, HoldForm @ e ],
                HoldPattern[ e: ExportMarkdownString[ ___ ] ] :>
                    catchTop @ throwInternalFailure @ e
            },
            DefaultValues -> {
                HoldPattern @ Options @ ExportMarkdownString -> {
                    "ImageExportMethod" -> None,
                    ConversionRules -> { },
                    PageWidth -> 100,
                    WindowWidth -> Automatic
                }
            },
            Messages -> {
                HoldPattern @ ExportMarkdownString::ArgumentCount -> "ExportMarkdownString called with `1` arguments; 1 argument is expected.",
                HoldPattern @ ExportMarkdownString::ExportNotString -> "Expected a string when applying image export function `1` to `2` instead of `3`.",
                HoldPattern @ ExportMarkdownString::Internal -> "An unexpected error occurred. `1`",
                HoldPattern @ ExportMarkdownString::NamedExportNotString -> "Failed to produce valid output for `2` using export method `1`.",
                HoldPattern @ ExportMarkdownString::NotDirectory -> "`1` is not a valid directory.",
                HoldPattern @ ExportMarkdownString::OptionsExpected -> "Options expected (instead of `1`) beyond position `2` in `3`. An option must be a rule or a list of rules."
            }
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
                        ExportMarkdownString::Internal,
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
                    throwFailure[
                        MessageName[ ExportMarkdownString, tag ],
                        params
                    ],
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
                                "Fragment" -> "ExportMarkdownString"
                            |>
                        ])
            }
        },
        HoldForm @ convertInput -> {
            DownValues -> {
                HoldPattern @ convertInput[ expr_ ] :> convertInput0 @ expr,
                HoldPattern[ e: HoldPattern @ convertInput[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ convertInput0 -> {
            DownValues -> {
                HoldPattern @ convertInput0[ cell: _TextCell | _ExpressionCell ] :>
                    convertCell @ cell,
                HoldPattern @ convertInput0[ group_CellGroup ] :>
                    convertCellGroup @ group,
                HoldPattern @ convertInput0[
                    notebook: _DialogNotebook | _DocumentNotebook | _PaletteNotebook
                ] :>
                    convertNotebook @ notebook,
                HoldPattern @ convertInput0[ cells: { ___Cell } ] :> Notebook @ cells,
                HoldPattern @ convertInput0[
                    expr: Alternatives[
                        Alternatives[
                            _Cell | _CellObject,
                            _Notebook | _NotebookObject,
                            _TextData | _BoxData | _RawData,
                            _String? StringQ,
                            _RawBoxes
                        ],
                        {
                            (Alternatives[
                                _Cell | _CellObject,
                                _Notebook | _NotebookObject,
                                _TextData | _BoxData | _RawData,
                                _String? StringQ,
                                _RawBoxes
                            ])..
                        }
                    ]
                ] :> expr,
                HoldPattern @ convertInput0[ expr_ ] :>
                    RawBoxes @ StyleBox[ MakeBoxes @ expr, ShowStringCharacters -> False ],
                HoldPattern[ e: HoldPattern @ convertInput0[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ convertCell -> {
            DownValues -> {
                HoldPattern @ convertCell[ cell: _TextCell | _ExpressionCell ] :>
                    convertCell @ ToBoxes @ cell,
                HoldPattern @ convertCell @ InterpretationBox[ cell_Cell, ___ ] :>
                    convertCell @ cell,
                HoldPattern @ convertCell[ cell_Cell ] :> cell,
                HoldPattern[ e: HoldPattern @ convertCell[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ convertCellGroup -> {
            DownValues -> {
                HoldPattern @ convertCellGroup @ CellGroup[ group_List ] :>
                    Cell @ CellGroupData[ convertInput /@ group, Open ],
                HoldPattern @ convertCellGroup @ CellGroup[ group_List, n: _Integer? Positive ] :>
                    cellGroupData[ group, { n } ],
                HoldPattern @ convertCellGroup @ CellGroup[ group_List, n: { _Integer? Positive... } ] :>
                    cellGroupData[ group, n ],
                HoldPattern @ convertCellGroup[ group_CellGroup ] :>
                    feParseCellGroup @ group,
                HoldPattern[ e: HoldPattern @ convertCellGroup[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ cellGroupData -> {
            DownValues -> {
                HoldPattern @ cellGroupData[ group_List, spec_ ] :>
                    Cell @ CellGroupData[ convertInput /@ group, spec ],
                HoldPattern[ e: HoldPattern @ cellGroupData[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ feParseCellGroup -> {
            DownValues -> {
                HoldPattern @ feParseCellGroup[ group_CellGroup ] :>
                    Enclose[
                        Module[ { nbo, nb, cells },
                            
                            WithCleanup[
                                nbo = 
                                    ConfirmMatch[
                                        CreateDocument[
                                            group,
                                            CellGrouping -> Manual,
                                            Visible -> False
                                        ],
                                        _NotebookObject,
                                        "NotebookObject"
                                    ],
                                nb = 
                                    ConfirmMatch[
                                        NotebookGet @ nbo,
                                        _Notebook,
                                        "Notebook"
                                    ],
                                NotebookClose @ nbo
                            ];

                            
                            cells = 
                                ConfirmMatch[
                                    Flatten @ { First[ nb, $Failed ] },
                                    { Cell[ _CellGroupData, ___ ] },
                                    "Cells"
                                ];

                            First @ cells
                        ],
                        throwInternalFailure
                    ],
                HoldPattern[ e: HoldPattern @ feParseCellGroup[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ convertNotebook -> {
            DownValues -> {
                HoldPattern @ convertNotebook[ notebook_ ] :>
                    Enclose[
                        Module[ { nbo, nb },
                            
                            WithCleanup[
                                nbo = 
                                    ConfirmMatch[
                                        CreateWindow[
                                            notebook,
                                            Visible -> False
                                        ],
                                        _NotebookObject,
                                        "NotebookObject"
                                    ],
                                nb = 
                                    ConfirmMatch[
                                        NotebookGet @ nbo,
                                        _Notebook,
                                        "Notebook"
                                    ],
                                NotebookClose @ nbo
                            ];

                            nb
                        ],
                        throwInternalFailure
                    ],
                HoldPattern[ e: HoldPattern @ convertNotebook[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ $$supported -> {
            OwnValues ->
                (HoldPattern @ $$supported :>
                    Alternatives[
                        Alternatives[
                            _Cell | _CellObject,
                            _Notebook | _NotebookObject,
                            _TextData | _BoxData | _RawData,
                            _String? StringQ,
                            _RawBoxes
                        ],
                        {
                            (Alternatives[
                                _Cell | _CellObject,
                                _Notebook | _NotebookObject,
                                _TextData | _BoxData | _RawData,
                                _String? StringQ,
                                _RawBoxes
                            ])..
                        }
                    ]
)
        },
        HoldForm @ cellToString -> {
            OwnValues -> {
                HoldPattern @ cellToString :>
                    Symbol[ "Wolfram`Chatbook`Serialization`CellToString" ]
            }
        },
        HoldForm @ determineContentTypes -> {
            DownValues -> {
                HoldPattern @ determineContentTypes @ None :> { "Text" },
                HoldPattern @ determineContentTypes[ Automatic | "Chatbook" ] :> { "Text", "Image" },
                HoldPattern @ determineContentTypes[ f_ ] :> { "Text", "Image" },
                HoldPattern[ e: HoldPattern @ determineContentTypes[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ exportImages -> {
            DownValues -> {
                HoldPattern @ exportImages[ markdown_String, None | Automatic ] :> markdown,
                HoldPattern @ exportImages[ markdown_String, f_ ] :>
                    Enclose[
                        Module[ { expanded, exported },
                            Needs[ "Wolfram`Chatbook`" -> None ];
                            
                            expanded = 
                                StringSplit[
                                    markdown,
                                    StringExpression[
                                        link: "\\!\\(\\*MarkdownImageBox[\"![",
                                        Except[ "]" ]..,
                                        "](",
                                        uri: Except[ "\"" ]..,
                                        ")\"]\\)"
                                    ] :>
                                        markdownImage[
                                            Symbol[
                                                "Wolfram`Chatbook`GetExpressionURI"
                                            ][ uri ],
                                            link
                                        ]
                                ];

                            
                            exported = 
                                ConfirmMatch[
                                    Replace[
                                        expanded,
                                        markdownImage[ expr_, s_ ] :>
                                            With[ { e = applyImageExport[ f, expr ] },
                                                If[ StringQ @ e, e, s ]
                                            ],
                                        { 1 }
                                    ],
                                    { ___String },
                                    "Exported"
                                ];

                            StringJoin @ exported
                        ],
                        throwInternalFailure
                    ],
                HoldPattern[ e: HoldPattern @ exportImages[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ applyImageExport -> {
            DownValues -> {
                HoldPattern @ applyImageExport[ "CloudObject", expr_ ] :>
                    checkExported[
                        "CloudObject",
                        expr,
                        defaultCloudObjectExport @ expr
                    ],
                HoldPattern @ applyImageExport[ dir: _File | _CloudObject, expr_ ] :>
                    directoryExport[ dir, expr ],
                HoldPattern @ applyImageExport[ f_, expr_ ] :>
                    checkExported[ f, expr, f @ expr ],
                HoldPattern[ e: HoldPattern @ applyImageExport[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ checkExported -> {
            DownValues -> {
                HoldPattern @ checkExported[ f_, expr_, exported_String? FileExistsQ ] :>
                    toMarkdownLink @ exported,
                HoldPattern @ checkExported[ f_, expr_, exported_String ] :> exported,
                HoldPattern @ checkExported[ f_, expr_, (CloudObject | URL)[ url_String, ___ ] ] :>
                    toMarkdownLink @ url,
                HoldPattern @ checkExported[ f_, expr_, File[ file_String ] ] :>
                    toMarkdownLink @ file,
                HoldPattern @ checkExported[ name_String, expr_, other_ ] :>
                    messageFailure[ "NamedExportNotString", name, expr, other ],
                HoldPattern @ checkExported[ f_, expr_, other_ ] :>
                    messageFailure[ "ExportNotString", f, expr, other ],
                HoldPattern[ e: HoldPattern @ checkExported[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ toMarkdownLink -> {
            DownValues -> {
                HoldPattern @ toMarkdownLink[ uri_String ] :>
                    "![image](" <> uri <> ")",
                HoldPattern[ e: HoldPattern @ toMarkdownLink[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ defaultCloudObjectExport -> {
            DownValues -> {
                HoldPattern @ defaultCloudObjectExport[ e_ ] :>
                    CloudExport[ e, "PNG", Permissions -> "Public" ],
                HoldPattern[ e: HoldPattern @ defaultCloudObjectExport[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        },
        HoldForm @ directoryExport -> {
            DownValues -> {
                HoldPattern @ directoryExport[ File[ dir_ ], expr_ ] :>
                    directoryExport[ dir, expr ],
                HoldPattern @ directoryExport[ dir_? DirectoryQ, expr_ ] :>
                    Enclose[
                        Module[ { hash, name, target, exported },
                            
                            hash = 
                                ConfirmBy[
                                    Hash @ Unevaluated @ expr,
                                    IntegerQ,
                                    "Hash"
                                ];

                            
                            name = 
                                StringJoin[
                                    ConfirmBy[
                                        IntegerString[ hash, 36 ],
                                        StringQ,
                                        "Name"
                                    ],
                                    ".png"
                                ];

                            target = FileNameJoin @ { dir, name };
                            
                            exported = 
                                ConfirmBy[
                                    Export[ target, expr, "PNG" ],
                                    FileExistsQ,
                                    "Export"
                                ];

                            checkExported[ "Directory", expr, exported ]
                        ],
                        throwInternalFailure
                    ],
                HoldPattern @ directoryExport[ target_? FileExistsQ, expr_ ] :>
                    throwFailure[ "NotDirectory", target ],
                HoldPattern @ directoryExport[ target_, expr_ ] :>
                    With[ { dir = CreateDirectory @ target },
                        If[ ! DirectoryQ @ dir,
                            throwFailure[ "NotDirectory", dir ],
                            directoryExport[ dir, expr ]
                        ]
                    ],
                HoldPattern[ e: HoldPattern @ directoryExport[ ___ ] ] :>
                    throwInternalFailure @ HoldForm @ e
            }
        }
    ];

EndPackage[ ];
