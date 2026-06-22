(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Tools`Notebooks`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];
Needs[ "Wolfram`AgentTools`Tools`"  ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Definitions*)

(* Add to $defaultMCPTools Association (initialized in Kernel/Tools/Tools.wl) *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ReadNotebook*)
$defaultMCPTools[ "ReadNotebook" ] := LLMTool @ <|
    "Name"        -> "ReadNotebook",
    "DisplayName" -> "Read Notebook",
    "Description" -> "Reads the contents of a Wolfram notebook (.nb) as markdown text.",
    "Function"    -> readNotebook,
    "Options"     -> { },
    "Parameters"  -> {
        "notebook" -> <|
            "Interpreter" -> "String",
            "Help"        -> "The Wolfram notebook to read, specified as a file path or a NotebookObject[...]",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WriteNotebook*)
$defaultMCPTools[ "WriteNotebook" ] := LLMTool @ <|
    "Name"        -> "WriteNotebook",
    "DisplayName" -> "Write Notebook",
    "Description" -> "Converts markdown text to a Wolfram notebook and saves it to a file.",
    "Function"    -> writeNotebook,
    "Options"     -> { },
    "Parameters"  -> {
        "file" -> <|
            "Interpreter" -> "String",
            "Help"        -> "The file to write the notebook to (must end in .nb). Any missing parent directories are created automatically.",
            "Required"    -> True
        |>,
        "overwrite" -> <|
            "Interpreter" -> "Boolean",
            "Help"        -> "Whether to overwrite an existing file (default is False).",
            "Required"    -> False
        |>,
        "markdown" -> <|
            "Interpreter" -> "String",
            "Help"        -> "The markdown text to write to a notebook.",
            "Required"    -> True
        |>
    }
|>;

(* TODO: We should make the following changes to the WriteNotebook tool:

- For files that already exist, there should be the following options for writing content:
  - Overwrite (all we currently do)
  - Append
  - Prepend
  - Insert

- We should also have an option to evaluate new input cells to generate outputs when writing

- Alternatively, we could make an EditNotebook tool that does these things.
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readNotebook*)
readNotebook // beginDefinition;

readNotebook[ KeyValuePattern[ "notebook" -> notebook_ ] ] :=
    readNotebook @ notebook;

readNotebook[ file_String ] /; FileExistsQ @ file := Enclose[
    Catch @ Module[ { nb },
        nb = Import[ file, "NB" ];
        If[ ! MatchQ[ nb, _Notebook ], Throw[ "File is not a valid Wolfram notebook: " <> file ] ];
        ConfirmMatch[ chatbookVersionCheck[ ], True, "ChatbookVersionCheck" ];
        ConfirmBy[ exportMarkdownString @ nb, StringQ, "Result" ]
    ],
    throwInternalFailure
];

readNotebook[ nbo0_String ] := Enclose[
    Catch @ Module[ { held, nbo },
        held = Quiet @ ToExpression[ nbo0, InputForm, HoldComplete ];
        If[ ! MatchQ[ held, HoldComplete[ NotebookObject[ __String ] ] ],
            Throw[ "Invalid notebook specification: " <> nbo0 ]
        ];
        nbo = ConfirmMatch[ ReleaseHold @ held, NotebookObject[ __String ], "NotebookObject" ];
        ConfirmMatch[ chatbookVersionCheck[ ], True, "ChatbookVersionCheck" ];
        ConfirmBy[ exportMarkdownString @ nbo, StringQ, "Result" ]
    ],
    throwInternalFailure
];

readNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeNotebook*)
writeNotebook // beginDefinition;

writeNotebook[ KeyValuePattern @ { "markdown" -> markdown_, "file" -> file_, "overwrite" -> overwrite_ } ] :=
    writeNotebook[ markdown, file, TrueQ @ overwrite ];

writeNotebook[ markdown_String, file_String, overwrite: True|False ] := Enclose[
    Catch @ Module[ { dir, nb, exported },
        If[ FileExistsQ @ file && ! overwrite, Throw[ "File already exists: " <> file ] ];
        dir = DirectoryName @ file;
        If[ dir =!= "" && ! DirectoryQ @ dir,
            Quiet @ CreateDirectory[ dir, CreateIntermediateDirectories -> True ];
            If[ ! DirectoryQ @ dir,
                Throw[ "Cannot write the notebook because the directory does not exist and could not be created: " <> dir ]
            ]
        ];
        ConfirmMatch[ chatbookVersionCheck[ ], True, "ChatbookVersionCheck" ];
        nb = ConfirmMatch[ importMarkdownString[ markdown, "Notebook" ], _Notebook, "Notebook" ];
        exported = Quiet @ Export[ file, nb, "NB" ];
        If[ ! StringQ @ exported || ! FileExistsQ @ exported,
            Throw[ "Unable to write the notebook to the file: " <> file <>
                   ". The path may be invalid or the location may not be writable." ]
        ];
        exported
    ],
    throwInternalFailure
];

writeNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];