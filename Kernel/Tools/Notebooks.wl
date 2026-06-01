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
$writeNotebookDescription = "\
Converts markdown text to a Wolfram notebook and saves it to a file.

Markdown rules:

* When writing code blocks, include the language (whenever applicable):
```language
code
```
* ALWAYS surround inline WL code with double backticks to avoid ambiguity with contexts: ``MyContext`MyFunction[x]``.
* Write math expressions using LaTeX and surround them with dollar signs: $$x^2 + y^2$$.
* Link directly to Wolfram Language documentation by using the following syntax: [label](paclet:uri). For example:
	* [Table](paclet:ref/Table)
	* [Language Overview](paclet:guide/LanguageOverview)
	* [Input Syntax](paclet:tutorial/InputSyntax)";

(* TODO: Append the following text once the "AppendURIInstructions" option is handled properly:

* If the WolframLanguageEvaluator tool provides expression URIs in the output (e.g. `scheme://content-id`), \
you can inline them fully formatted in the notebook as if they are images: ![label](scheme://content-id). \
To inline them into code blocks, use the special syntax <!scheme://content-id!>.

*)

$defaultMCPTools[ "WriteNotebook" ] := LLMTool @ <|
    "Name"        -> "WriteNotebook",
    "DisplayName" -> "Write Notebook",
    "Description" -> $writeNotebookDescription,
    "Function"    -> writeNotebook,
    "Options"     -> { },
    "Parameters"  -> {
        "file" -> <|
            "Interpreter" -> "String",
            "Help"        -> "The file to write the notebook to (must end in .nb).",
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

For the ReadNotebook tool, we should allow specifying a cell offset or cell range for reading large notebooks:

- We should automatically truncate and prepend a message like: "Showing cells 1-10 of 50 total cells."
- Automatic truncation should be based on accumulated character count, not cell count
- Introduce mutually exclusive "offset" and "range" parameters:
    - offset specified as a single integer:
        - 11 -> show cells starting from the 11th cell until automatic truncation
        - -10 -> start from the 10th cell from the end
    - range specified as a pair of integers:
        - [11, 20] -> show cells 11-20
        - [-10, -5] -> show cells from the 10th cell from the end to the 5th cell from the end
        - effectively equivalent to `Part` syntax: `cells[[a, b]]`
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
    Catch @ Module[ { nb },
        If[ FileExistsQ @ file && ! overwrite, Throw[ "File already exists: " <> file ] ];
        ConfirmMatch[ chatbookVersionCheck[ ], True, "ChatbookVersionCheck" ];
        nb = ConfirmMatch[ importMarkdownString[ markdown, "Notebook" ], _Notebook, "Notebook" ];
        ConfirmBy[ Export[ file, nb, "NB" ], FileExistsQ, "File" ]
    ],
    throwInternalFailure
];

writeNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];