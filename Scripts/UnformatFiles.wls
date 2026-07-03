#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`MCPServerScripts`" ];

If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

Needs[ "PacletTools`"        -> "pt`"   ];
Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*unformat*)
unformat[ file_ ] :=
    Enclose @ Module[ { nb, exported },
        nb = ConfirmMatch[ Import[ file, "NB" ], _Notebook, "Import" ];
        exported = ConfirmBy[ Export[ file, nb, "NB" ], FileExistsQ, "Export" ];
        ConfirmAssert[ StringContainsQ[ Import[ file, "String" ], "(* Internal cache information *)" ], "CacheCheck" ];
        cicd`ConsoleLog[ "    "<>exported ];
        exported
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run*)
files = cicd`ScriptConfirmMatch[
    DeleteDuplicates @ Flatten @ {
        FileNameJoin @ { $pacletDir, "ResourceDefinition.nb" },
        FileNames[
            "*.nb",
            DeleteDuplicates @ Flatten @ DeleteCases[
                Values @ pt`PacletExtensionDirectory @ File @ $pacletDir,
                StringDelete[ $pacletDir, $PathnameSeparator~~EndOfString ]
            ],
            Infinity
        ]
    },
    { __String }
];

cicd`ConsoleLog[ "Unformatting " <> ToString @ Length @ files <> " files..." ];

result = cicd`ScriptConfirmMatch[ UsingFrontEnd[
    CurrentValue[ $FrontEndSession, { PrivateFrontEndOptions, "ExperimentalNotebookParser" } ] = False; (* ensure the file outline cache is built with the old parser *)
    CurrentValue[ $FrontEndSession, DynamicUpdating ] = False;
    unformat /@ files
], { __String } ];

EndPackage[ ];

Wolfram`MCPServerScripts`result