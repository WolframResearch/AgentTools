(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`CreateMCPServer`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* TODO:
    - Support "Remote" type (deploy as cloud API)
    - Add developer mode option to start from script instead
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$serverVersion      = "1.0.0";
$objectVersion      = 1;
$overwriteTarget    = False;
$includeDefinitions = True;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateMCPServer*)
CreateMCPServer // beginDefinition;
CreateMCPServer // Options = {
    OverwriteTarget    -> $overwriteTarget,
    IncludeDefinitions -> $includeDefinitions,
    Initialization     -> None
};

CreateMCPServer[ name_String, opts: OptionsPattern[ ] ] :=
    catchMine @ CreateMCPServer[ name, Symbol[ "System`$LLMEvaluator" ], opts ];

CreateMCPServer[ name_String, evaluator_LLMConfiguration, opts: OptionsPattern[ ] ] :=
    catchMine @ CreateMCPServer[ name, rewriteChatbookTools @ evaluator[ "Data" ], opts ];

CreateMCPServer[ name_String, evaluator_Association, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[
        {
            $overwriteTarget    = TrueQ @ OptionValue @ OverwriteTarget,
            $includeDefinitions = TrueQ @ OptionValue @ IncludeDefinitions,
            $initialization     = OptionValue[ Automatic, Automatic, Initialization, HoldComplete ]
        },
        createMCPServer[ name, evaluator ]
    ];

CreateMCPServer // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createMCPServer*)
createMCPServer // beginDefinition;

createMCPServer[ name_String, evaluator_Association ] := Enclose[
    Module[ { path, data, wxf, exported },

        path = ConfirmBy[ mcpServerFile @ name, fileQ, "Path" ];
        If[ ! $overwriteTarget && FileExistsQ @ path,
            throwFailure[ "MCPServerExists", name, OverwriteTarget -> True ]
        ];

        data = ConfirmBy[ createMCPServerData[ name, evaluator ], AssociationQ, "Data" ];

        wxf = ConfirmBy[
            If[ TrueQ @ $includeDefinitions, binarySerializeWithDefinitions @ data, BinarySerialize @ data ],
            ByteArrayQ,
            "WXF"
        ];

        exported = ConfirmBy[ exportBinary[ path, wxf ], FileExistsQ, "Exported" ];

        ConfirmBy[ Developer`ReadWXFFile @ exported, SameAs @ data, "ExportCheck" ];

        ConfirmBy[ MCPServerObject @ data, MCPServerObjectQ, "MCPServerObject" ]
    ],
    throwInternalFailure
];

createMCPServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*rewriteChatbookTools*)
rewriteChatbookTools // beginDefinition;
rewriteChatbookTools[ as_Association ] := <| as, "Tools" -> rewriteChatbookTools @ as[ "Tools" ] |>;
rewriteChatbookTools[ tools_List ] := rewriteChatbookTools /@ tools;

(*
This reverts tool names that were specified as strings, but LLMConfiguration resolved them to default Chatbook tools
instead of MCPServer tools. The Chatbook tools are *almost* the same as ours, but we have some slight differences
(mostly in parameters and descriptions).

This is done to ensure that the following are equivalent:
```wl
CreateMCPServer[..., LLMConfiguration[<|"Tools" -> {"WolframLanguageEvaluator", "WolframAlpha"}|>]]["Tools"]
CreateMCPServer[..., <|"Tools" -> {"WolframLanguageEvaluator", "WolframAlpha"}|>]["Tools"]
```

The default tool definitions in the Chatbook paclet can be found here:
- https://github.com/WolframResearch/Chatbook/blob/main/Source/Chatbook/Tools/DefaultToolDefinitions/WolframLanguageEvaluator.wl
- https://github.com/WolframResearch/Chatbook/blob/main/Source/Chatbook/Tools/DefaultToolDefinitions/WolframAlpha.wl
*)

rewriteChatbookTools[ HoldPattern @ LLMTool[
    KeyValuePattern @ {
        "CanonicalName" -> "WolframLanguageEvaluator",
        "DisplayName"   -> "Wolfram Language Evaluator",
        "Name"          -> "wolfram_language_evaluator",
        "ShortName"     -> "wl",
        "Origin"        -> "BuiltIn"
    },
    ___
] ] := "WolframLanguageEvaluator";

rewriteChatbookTools[ $$defaultWATool = HoldPattern @ LLMTool[
    KeyValuePattern @ {
        "CanonicalName" -> "WolframAlpha",
        "DisplayName"   -> "Wolfram|Alpha",
        "Name"          -> "wolfram_alpha",
        "ShortName"     -> "wa",
        "Origin"        -> "BuiltIn"
    },
    ___
] ] := "WolframAlpha";

(* Otherwise, return the tool unchanged: *)
rewriteChatbookTools[ tool_ ] := tool;

rewriteChatbookTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*exportBinary*)
exportBinary // beginDefinition;

exportBinary[ File[ file_ ], bytes_ ] :=
    exportBinary[ file, bytes ];

exportBinary[ file_String, bytes_ByteArray ] :=
    WithCleanup[
        Quiet @ Close @ file,
        BinaryWrite[ file, bytes ],
        Quiet @ Close @ file
    ];

exportBinary // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createMCPServerData*)
createMCPServerData // beginDefinition;

createMCPServerData[ name_String, evaluator_Association ] := Enclose[
    Module[ { dir, init, validated },
        dir = ConfirmBy[ ensureDirectory @ mcpServerDirectory @ name, directoryQ, "Directory" ];
        init = ConfirmMatch[ $initialization, HoldComplete[ _ ], "Initialization" ];
        validated = catchAlways @ validateMCPServerObjectData @ <|
            "Name"           -> name,
            "LLMEvaluator"   -> evaluator,
            "Location"       -> dir,
            "Transport"      -> "StandardInputOutput",
            "ServerVersion"  -> $serverVersion,
            "ObjectVersion"  -> $objectVersion,
            "Initialization" -> init
        |>;
        If[ AssociationQ @ validated,
            validated,
            DeleteDirectory[ dir, DeleteContents -> True ];
            throwTop @ validated
        ]
    ],
    throwInternalFailure
];

createMCPServerData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
