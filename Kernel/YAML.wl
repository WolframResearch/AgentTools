(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`YAML`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Reading YAML*)
importYAML // beginDefinition;

importYAML[ file_ ] := Enclose[
    Catch @ Module[ { path, data },
        path = ConfirmBy[ ExpandFileName @ file, StringQ, "Path" ];
        If[ ! FileExistsQ @ path || FileByteCount @ path === 0, Throw @ <| |> ];
        data = Quiet[ Import[ path, "YAML" ], Import::fmterr ];
        If[ data === $Failed, throwFailure[ "InvalidYAMLFormat", path ] ];
        ConfirmMatch[ Replace[ data, Null -> <| |> ], _Association | _List, "Parsed" ]
    ],
    throwInternalFailure
];

importYAML // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*importYAMLString*)
importYAMLString // beginDefinition;

importYAMLString[ s_String ] :=
    Module[ { data },
        (* Explicit UTF-8 bytes avoid ImportString's encoding failure for U+0080-U+00FF in 15.0.1. *)
        data = Quiet[ ImportByteArray[ ByteArray @ ToCharacterCode[ s, "UTF8" ], "YAML" ], Import::fmterr ];
        If[ data === $Failed, throwFailure[ "InvalidYAMLFormat", "<input>" ] ];
        Replace[ data, Null -> <| |> ]
    ];

importYAMLString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Writing YAML*)
exportYAML // beginDefinition;

exportYAML[ file_, data_ ] := Enclose[
    Module[ { path },
        path = ConfirmBy[ ExpandFileName @ ensureFilePath @ file, StringQ, "Path" ];
        ConfirmBy[ Export[ path, data, "YAML" ], FileExistsQ, "Export" ];
        File @ path
    ],
    throwInternalFailure
];

exportYAML // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exportYAMLString*)
exportYAMLString // beginDefinition;

exportYAMLString[ data_ ] := Enclose[
    (* Decode UTF-8 explicitly; ExportString returns UTF-8 bytes as characters in 15.0.1. *)
    FromCharacterCode[ Normal @ ConfirmMatch[ ExportByteArray[ data, "YAML" ], _ByteArray, "Export" ], "UTF8" ],
    throwInternalFailure
];

exportYAMLString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
