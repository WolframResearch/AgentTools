(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreatePreferencesContent*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Smoke test*)
VerificationTest[
    CreatePreferencesContent[ ],
    Deploy[ _Pane ],
    SameTest -> MatchQ,
    TestID   -> "CreatePreferencesContent-SmokeTest"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Invalid Arguments*)
VerificationTest[
    CreatePreferencesContent[ "bogus" ],
    _Failure,
    { CreatePreferencesContent::InvalidArguments },
    SameTest -> MatchQ,
    TestID   -> "CreatePreferencesContent-InvalidArguments"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Usage Data Checkbox*)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* The checkbox is a DynamicModule that reads the global setting when it is displayed and writes it when toggled;
   nothing is re-deployed and no InstallMCPServer option is involved. *)
VerificationTest[
    Wolfram`AgentTools`PreferencesContent`Private`usageDataCheckbox[ ],
    Grid[
        { {
            (* Verbatim heads keep the pattern from being evaluated (or linted) as an actual DynamicModule *)
            Verbatim[ DynamicModule ][
                { Verbatim[ Set ][ _Symbol, True ] },
                Checkbox @ Dynamic[ _Symbol, _Function ],
                Initialization :> Verbatim[ Set ][ _Symbol, Wolfram`AgentTools`Common`getGlobalUsageDataSetting[ ] ],
                ___ (* the kernel appends DynamicModuleValues :> { } when it evaluates a DynamicModule *)
            ],
            _Tooltip
        } },
        ___
    ],
    SameTest -> MatchQ,
    TestID   -> "PreferencesContent-UsageDataCheckbox-Structure"
]

(* Toggling the checkbox writes the global setting (the Dynamic's setter is applied by hand, since there is no
   front end to display the DynamicModule) *)
VerificationTest[
    withTemporaryRoot @ Module[ { setter },
        setter = First @ Cases[
            Wolfram`AgentTools`PreferencesContent`Private`usageDataCheckbox[ ],
            Checkbox[ Dynamic[ _, f_ ] ] :> f,
            Infinity
        ];
        Block[ { Wolfram`AgentTools`PreferencesContent`Private`submit },
            {
                Wolfram`AgentTools`Common`getGlobalUsageDataSetting[ ],
                setter[ False ],
                Wolfram`AgentTools`PreferencesContent`Private`submit,
                Wolfram`AgentTools`Common`getGlobalUsageDataSetting[ ],
                Developer`ReadWXFFile @ Wolfram`AgentTools`Common`$globalSettingsFile,
                setter[ True ],
                Wolfram`AgentTools`Common`getGlobalUsageDataSetting[ ]
            }
        ]
    ],
    { True, False, False, False, <| "SubmitUsageData" -> False |>, True, True },
    SameTest -> SameQ,
    TestID   -> "PreferencesContent-UsageDataCheckbox-Setter"
]

(* Toggling the checkbox only writes the setting: no deployment is touched, and nothing is queued *)
VerificationTest[
    FreeQ[
        Wolfram`AgentTools`PreferencesContent`Private`usageDataCheckbox[ ],
        DeployAgentTools | InstallMCPServer | DeployedAgentTools | SessionSubmit | "SubmitUsageData"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "PreferencesContent-UsageDataCheckbox-NoRedeploy"
]

(* :!CodeAnalysis::EndBlock:: *)
