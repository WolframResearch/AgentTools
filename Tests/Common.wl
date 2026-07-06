(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentToolsTests`" ];

(* :!CodeAnalysis::BeginBlock:: *)
`$BuiltPaclet;
`$TestDefinitionsLoaded = True;
`conditionalTest;
`environmentBlock;
`skipIfGitHubActions;
`skipIfScript;

Begin[ "`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
Wolfram`PacletCICD`$Debug = True;
LLMConfiguration; (* Trigger autoload for LLMFunctions paclet *)

Off[ General::shdw           ];
Off[ PacletInstall::samevers ];

If[ ! PacletObjectQ @ PacletObject[ "Wolfram/PacletCICD" ],
    PacletInstall[ "https://github.com/WolframResearch/PacletCICD/releases/download/v0.36.2/Wolfram__PacletCICD-0.36.2.paclet" ]
];

Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*conditionalTest*)
conditionalTest // Attributes = { HoldAllComplete };

conditionalTest[ condition0_ ] :=
    With[ { condition = condition0 }, (* Insert the evaluated condition so we don't repeat it every time *)
        Function[ test, conditionalTest[ condition, test ], HoldAllComplete ]
    ];

conditionalTest[ condition_, test: VerificationTest[ ___, TestID -> id_String, ___ ] ] :=
    If[ condition,
        test,
        cicd`ConsoleLog @ SequenceForm[ "\tSkipping test: ", id ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skipIfGitHubActions*)
skipIfGitHubActions = conditionalTest @ Not @ StringQ @ Environment[ "GITHUB_ACTIONS" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skipIfScript*)
(* Skip tests when running as a wolframscript (subprocess I/O doesn't work reliably in that context) *)
skipIfScript = conditionalTest @ Not @ MatchQ[ $ScriptCommandLine, { __String } ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*environmentBlock*)
(* Temporarily set (or, with value None, unset) a process environment variable for the duration of
   eval, restoring the previous value afterward -- including on abort/failure via WithCleanup.
   Unlike Block[{Environment}, ...], this sets the real variable so every Environment[...] call under
   eval behaves naturally. Usage: environmentBlock["LLMKIT_ENABLED" -> "false", someExpr]. *)
environmentBlock // Attributes = { HoldRest };

environmentBlock[ name_ -> value_, eval_ ] :=
    With[ { previous = Replace[ Environment @ name, $Failed -> None ] },
        SetEnvironment[ name -> value ];
        WithCleanup[ eval, SetEnvironment[ name -> previous ] ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*abort*)
abort[ ] := (
    If[ $Context === "Wolfram`AgentToolsTests`Private`", End[ ] ];
    If[ $Context === "Wolfram`AgentToolsTests`", EndPackage[ ] ];
    cicd`ScriptConfirm[ $Failed ]
);

abort[ message__ ] := (
    cicd`ConsoleError @ SequenceForm @ message;
    abort[ ]
);

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*endDefinition*)
endDefinition[ sym_Symbol ] := sym[ args___ ] := abort[ "Invalid arguments in ", HoldForm @ sym @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$sourceDirectory = DirectoryName[ $InputFileName, 2 ];
$buildDirectory  = FileNameJoin @ { $sourceDirectory, "build", "Wolfram__AgentTools" };
$pacletDirectory = Quiet @ SelectFirst[ { $buildDirectory, $sourceDirectory }, PacletObjectQ @* PacletObject @* File ];

$BuiltPaclet = $pacletDirectory === $buildDirectory;

If[ ! $BuiltPaclet,
    cicd`ConsoleWarning[ "Running tests on source directory instead of built paclet" ]
];

$$rules = (Rule|RuleDelayed)[ _, _ ]..;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Paclet*)
If[ ! DirectoryQ @ $pacletDirectory, abort[ "Paclet directory ", $pacletDirectory, " does not exist!" ] ];
Quiet @ PacletDirectoryUnload @ $sourceDirectory;
PacletDataRebuild[ ];
PacletDirectoryLoad @ $pacletDirectory;
Quiet[ Get[ "Wolfram`AgentTools`" ], ClearAll::clloc ];
If[ ! MemberQ[ $LoadedFiles, FileNameJoin @ { $pacletDirectory, "Kernel", "64Bit", "AgentTools.mx" } ],
    cicd`ConsoleWarning[ "Paclet MX file was not loaded" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
