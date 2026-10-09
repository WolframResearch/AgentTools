#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`MCPServerScripts`" ];
If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
Needs[ "CodeParser`"         -> "cp`"   ];
Needs[ "GeneralUtilities`"   -> "gu`"   ];
Needs[ "PacletTools`"        -> "pt`"   ];
Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

Wolfram`AgentToolsInternal`$BuildingMX = True;
$assertions = getBooleanArgument[ { "a", "assertions" }, True ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paths*)
$mxFile = cStr @ FileNameJoin @ {
    $pacletDir,
    "Kernel",
    ToString @ $SystemWordLength <> "Bit",
    "AgentTools.mx"
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*codeParse*)
codeParse[ file_ ] := codeParse[ file ] =
    cp`CodeParse @ Flatten @ File @ file;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*codeParseIndexed*)
codeParseIndexed[ file_ ] := codeParseIndexed[ file ] =
    cp`CodeParse[ Flatten @ File @ file, "SourceConvention" -> "SourceCharacterIndex" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*copyTemporary*)
copyTemporary[ dir_ ] :=
    Enclose @ Module[ { tmp, extFiles },
        tmp = FileNameJoin @ { $TemporaryDirectory, CreateUUID[ ] };
        extFiles = ConfirmMatch[ pacletFiles @ dir, { _String, __String }, "Files" ];
        ConfirmMatch[ (copyTemporary0[ dir, tmp, #1 ] &) /@ extFiles, { _String, __String }, "Copied" ];
        tmp
    ];

copyTemporary0[ dir_, tmp_, file_ ] :=
    With[ { rel = relativePath[ dir, file ] },
        CopyFile[ file, ensureFilePath @ FileNameJoin @ { tmp, rel } ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*copyResourceFunctions*)
(* The local resource function definitions (see ResourceFunctions/README.md) are not paclet extension files, so
   copyTemporary skips them, but importResourceFunction looks for them next to the copy of the paclet it is loaded from
   when inlining the definitions into the MX file. They are copied after expandTags so their Confirm tags are left alone. *)
copyResourceFunctions[ dir_, tmp_ ] :=
    With[ { source = FileNameJoin @ { dir, "ResourceFunctions" } },
        If[ DirectoryQ @ source,
            CopyDirectory[ source, FileNameJoin @ { tmp, "ResourceFunctions" } ],
            None
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*relativePath*)
relativePath[ dir0_, file0_ ] :=
    Enclose @ Module[ { dir, file, relative },
        dir = ConfirmBy[ ExpandFileName @ dir0, StringQ, "Directory" ];
        file = ConfirmBy[ ExpandFileName @ file0, StringQ, "File" ];
        relative = StringDelete[ file, StartOfString~~dir~~($PathnameSeparator|"") ];
        StringReplace[ relative, "\\" -> "/" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ensureFilePath*)
ensureFilePath[ file_ ] := Enclose[
    ConfirmBy[ GeneralUtilities`EnsureDirectory @ DirectoryName @ file, DirectoryQ, "Directory" ];
    file
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*pacletFiles*)
pacletFiles[ dir_ ] := Flatten @ {
    FileNameJoin @ { dir, "PacletInfo.wl" },
    Values @ pt`PacletExtensionFiles @ File @ dir
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*expandTags*)
expandTags[ root_ ] :=
    Enclose @ Map[
        Confirm[ expandTags[ root, #1 ], "Expand" ] &,
        ConfirmMatch[ FileNames[ "*.wl", root, Infinity ], { __String }, "Files" ]
    ];

expandTags[ root_, file_ ] :=
    Enclose @ Catch @ Module[ { tags, pos, string, newString },
        tags = ConfirmMatch[ getNewTags[ root, file ], { ___String }, "Tags" ];
        If[ tags === { }, Throw @ file ];
        cicd`ConsoleLog[ "\t" <> ToString @ file ];
        pos = ConfirmMatch[ getTagPos @ file, { { _Integer, _Integer }.. }, "Positions" ];
        ConfirmAssert[ Length @ tags == Length @ pos, "LengthCheck" ];
        string = ConfirmBy[ ReadString @ file, StringQ, "FileContent" ];
        newString = ConfirmBy[ StringReplacePart[ string, tags, pos ], StringQ, "NewFileContent" ];
        ConfirmBy[ Export[ file, newString, "String" ], FileExistsQ, "ExportFile" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getNewTags*)
getNewTags[ root_, file_ ] :=
    Module[ { relativeFile },

        relativeFile = relativePath[ root, file ];

        Cases[
            codeParse @ file,
            astPattern[
                HoldPattern @ Alternatives[
                    (Confirm|ConfirmAssert)[ _, $tag1_String ],
                    (ConfirmBy|ConfirmMatch|ConfirmQuiet)[ _, _, $tag2_String ]
                ],
                KeyValuePattern[ cp`Source -> { { $l1_, $c1_ }, { $l2_, $c2_ } } ]
            ] :>
                With[ { tag = First @ { $tag1, $tag2 } },
                    TemplateApply[
                        $tagTemplate,
                        <|
                            "File"    -> relativeFile,
                            "Tag"     -> First @ StringSplit[ ToExpression @ tag[[ 2 ]], "@@" ],
                            "Line1"   -> $l1,
                            "Line2"   -> $l2,
                            "Column1" -> $c1,
                            "Column2" -> $c2
                        |>
                    ]
                ],
            Infinity
        ]
    ];

$tagTemplate = StringTemplate[ "\"`Tag`@@`File`:`Line1`,`Column1`-`Line2`,`Column2`\"" ];

(* Prefer the local copy of the ASTPattern resource function (see ResourceFunctions/README.md), so that the build does not
   need the Function Repository. The Block keeps its BeginPackage/EndPackage from changing this script's context path. *)
$localASTPatternFile = FileNameJoin @ { $pacletDir, "ResourceFunctions", "ASTPattern.wl" };

astPattern := astPattern =
    If[ FileExistsQ @ $localASTPatternFile,
        Block[ { $Context = $Context, $ContextPath = $ContextPath }, Get @ $localASTPatternFile ];
        Symbol[ "Wolfram`AgentTools`ResourceFunctions`ASTPattern`ASTPattern" ],
        ResourceFunction[ "ASTPattern", "Function" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getTagPos*)
getTagPos[ file_ ] := Cases[
    codeParseIndexed @ file,
    astPattern[
        HoldPattern[
            Alternatives[
                (Confirm|ConfirmAssert)[ _, $tag1_String ],
                (ConfirmBy|ConfirmMatch|ConfirmQuiet)[ _, _, $tag2_String ]
            ]
        ],
        KeyValuePattern[ cp`Source -> p_ ]
    ] :> (First @ { $tag1, $tag2 })[[ 3, Key @ cp`Source ]],
    Infinity
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Build MX*)
If[ FileExistsQ @ $mxFile,
    cicd`ConsoleLog[ "Removing existing MX file..." ];
    cicd`ScriptConfirm @ DeleteFile @ $mxFile
];

cicd`ConsoleLog[ "Copying files..." ];
tmp = cicd`ScriptConfirmBy[ copyTemporary @ $pacletDir, DirectoryQ ];
cicd`ScriptConfirmBy[ setPacletReleaseID[ tmp, releaseID @ $pacletDir ], StringQ ];

If[ $assertions,
    cicd`ConsoleLog[ "Inserting confirmation source info..." ];
    cicd`ScriptConfirm @ expandTags @ tmp
];

cicd`ConsoleLog[ "Copying local resource function definitions..." ];
cicd`ScriptConfirmMatch[ copyResourceFunctions[ $pacletDir, tmp ], _String | None ];

cicd`ConsoleLog[ "Loading paclet..." ];
PacletDirectoryUnload @ $pacletDir;
cicd`ScriptConfirmBy[ PacletDirectoryLoad @ tmp, MemberQ @ tmp ];

$systemSymbols = {
    "System`AgentToolsDeployment",
    "System`DeployAgentTools",
    "System`DeployedAgentTools"
};

Quiet[
    Unprotect[ "Wolfram`AgentTools`*" ];
    Remove[ "Wolfram`AgentTools`*" ];
    Remove[ "Wolfram`AgentTools`*`*" ];
    Unprotect @@ $systemSymbols;
    Remove @@ $systemSymbols;
];

cicd`ScriptConfirmAssert[ Names[ "Wolfram`AgentTools`*" ] === Names[ "Wolfram`AgentTools`*`*" ] === { }, "Names" ];
cicd`ScriptConfirmAssert[ ! AnyTrue[ $systemSymbols, NameQ ], "SystemSymbols" ];

Quiet[
    cicd`ScriptConfirm @ CheckAbort[ Get[ "Wolfram`AgentTools`" ], $Failed ],
    {
        (* :!CodeAnalysis::BeginBlock:: *)
        (* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
        LLMServices`Defaults`Private`LLMFunctions::llmrstrt
        (* :!CodeAnalysis::EndBlock:: *)
    }
];

cicd`ScriptConfirmMatch[ DeleteDirectory[ tmp, DeleteContents -> True ], Null ];

$mxDir = cDir @ gu`EnsureDirectory @ DirectoryName @ $mxFile;
cicd`ConsoleLog @ SequenceForm[ "MX target directory: ", $mxDir  ];
cicd`ConsoleLog @ SequenceForm[ "Building MX file: "   , $mxFile ];

DumpSave[ $mxFile, Evaluate @ Flatten @ { "Wolfram`AgentTools`", $systemSymbols }, "SymbolAttributes" -> False ];

PacletDirectoryUnload @ tmp;
PacletDirectoryLoad @ $pacletDir;

result = If[ ! FileExistsQ @ $mxFile,
             cicd`ConsoleError[ "Failed to build MX file!", "Fatal" -> True ],
             $mxFile
         ];

EndPackage[ ];

Wolfram`MCPServerScripts`result