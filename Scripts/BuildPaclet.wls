#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`MCPServerScripts`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];
If[ ! $inCICD, System`$PublisherID = "Wolfram" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Arguments*)
$check    = getBooleanArgument[ { "c", "check"    }, True  ];
$install  = getBooleanArgument[ { "i", "install"  }, False ];
$mx       = getBooleanArgument[ { "m", "mx"       }, True  ];
$unformat = getBooleanArgument[ { "u", "unformat" }, $inCICD ];
$keepMX   = getBooleanArgument[ { "k", "keep-mx"  }, $inCICD ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Optional Dependencies*)
If[ $unformat, Get @ cFile @ FileNameJoin @ { $scriptDir, "UnformatFiles.wls" } ];
If[ $mx      , Get @ cFile @ FileNameJoin @ { $scriptDir, "BuildMX.wls" } ];
If[ $check   , Get @ cFile @ FileNameJoin @ { $scriptDir, "Resources", "CodeInspectorRules.wl" } ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other*)
Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Build*)
result = Quiet[
    checkResult @ cicd`BuildPaclet[
        $defNB,
        "Check"      -> $check,
        "ExitOnFail" -> True,
        "Target"     -> "Submit"
    ],
    {
        (* :!CodeAnalysis::BeginBlock:: *)
        (* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
        CloudObject`Private`webLoginDialogInput::ninit,
        DocumentationSearch`Skeletonizer`Private`convertToString::unke,
        DocumentationSearch`Skeletonizer`Private`skeletonizeFiles::msgs,
        WaitAll::nopar
        (* :!CodeAnalysis::EndBlock:: *)
    }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install*)
If[ $install,
    archive = cFile @ result[ "PacletArchive" ];
    cicd`ConsoleNotice @ SequenceForm[ "Installing paclet file: ", archive ];
    installed = cicd`ScriptConfirmBy[ PacletInstall[ archive, ForceVersionInstall -> True ], PacletObjectQ ];
    cicd`ConsoleNotice @ SequenceForm[ "Installed paclet: ", cDir @ installed[ "Location" ] ];
];

(* Remove the built MX file if running locally: *)
If[ $mx && ! $keepMX,
    mxDir = FileNameJoin @ { $pacletDir, "Kernel", ToString @ $SystemWordLength <> "Bit" };
    cicd`ConsoleNotice @ SequenceForm[ "Removing MX directory: ", mxDir ];
    DeleteDirectory[ mxDir, DeleteContents -> True ]
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
EndPackage[ ];

Wolfram`MCPServerScripts`result