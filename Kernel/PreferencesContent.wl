(* ::Package:: *)

(* ::Section::Closed:: *)
(*Package Header*)


BeginPackage[ "Wolfram`AgentTools`PreferencesContent`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];



(* ::**************************************************************************************************************:: *)
(**)


(* ::Section::Closed:: *)
(*resources*)


tr[id_] := Dynamic[FEPrivate`FrontEndResource["AgentToolsStrings", id]];


icon[id_] := Dynamic[RawBoxes @ FEPrivate`FrontEndResource["AgentToolsExpressions", id]];
icon[id_, args__] := Dynamic[RawBoxes @ FEPrivate`FrontEndResource["AgentToolsExpressions", id][args]];


ldsGray[n_] := LightDarkSwitched[GrayLevel[n]]


$allowDirectoryOperations = False;


clientControlFrameOptions[opts___] := Sequence @@ {
	opts,
	BaselinePosition -> Baseline,
	RoundingRadius -> 3,
	FrameMargins -> {{7,7},{2,2}},
	FrameStyle -> Dynamic[If[CurrentValue["MouseOver"], ldsGray[0.7], ldsGray[0.85]]],
	Background -> Dynamic[If[CurrentValue["MouseOver"], ldsGray[0.94], ldsGray[0.97]]]
}


(* ::Section::Closed:: *)
(*docsLink*)


docsLink[] :=
	MouseAppearance[
		Button[
			Framed[
				Row[{tr["prefsDocsLinkText"], " \[UpperRightArrow]"}, BaseStyle -> {FontSize -> Inherited - 2}],
				RoundingRadius -> 2,
				FrameMargins -> {{5,5},{1,1}},
				FrameStyle -> Dynamic[If[CurrentValue["MouseOver"], ldsGray[0.7], ldsGray[0.85]]],
				Background -> Dynamic[If[CurrentValue["MouseOver"], ldsGray[0.94], ldsGray[0.97]]]],
			If[
				TrueQ @ CurrentValue["OptionKey"],
				CreateDocument[{
					ExpressionCell[Defer[DeployedAgentTools[]], "Input"],
					ExpressionCell[DeployedAgentTools[], "Output"]
				}],
				SystemOpen["paclet:Wolfram/AgentTools/tutorial/QuickStartforAICodingApplications"]
			],
			Appearance -> None,
			BaseStyle -> {},
			DefaultBaseStyle -> {}
		],
		"LinkHand"
	]


(* ::Section::Closed:: *)
(*clientInterfaces*)


clientInterfaces[] :=
	DynamicModule[{update, clients, servers, globallyConfiguredClients, locallyConfiguredClients, detectedClients, otherClients, clientNameSpacer, initDone, refresh},

		Dynamic[
			Which[
				update;
				initDone =!= True,
					Pane[
						ProgressIndicator[Appearance -> "Necklace"],
						Alignment -> Left,
						ImageMargins -> {{15,0},{0,0}}
					],

				MatchQ[clients, Except[{__String}]],
					Style[tr["prefsNoMCPClients"], Italic, FontColor -> ldsGray[0.5]],
				MatchQ[servers, Except[{__String}]],
					Style[tr["prefsNoMCPServers"], Italic, FontColor -> ldsGray[0.5]],
				
				True,
					Column[
						{
							If[
								globallyConfiguredClients === {}, Nothing, 
								Framed[
									Column[
										Prepend[
											clientRow["Configured", #, clientNameSpacer, Dynamic[refresh]]& /@ globallyConfiguredClients,
											Grid[{{
												Pane[
													icon["prefsConfiguredIcon"],
													BaselinePosition -> Scaled[0.15]
												],
												Style[tr["prefsHarnessesConfigured"],
													FontSize -> Inherited,
													FontColor -> LightDarkSwitched[RGBColor["#408021"]],
													FontWeight -> "DemiBold"
												]
											}}]
										],
										ItemSize -> Scaled[1],
										Spacings -> {Automatic, {2 -> 1.5}}
									],
									FrameStyle -> LightDarkSwitched[ RGBColor["#B5CCAD"] ],
									FrameMargins -> 15,
									RoundingRadius -> 6
								]
							],
							
							If[
								detectedClients === {}, Nothing,
								Framed[
									Column[
										Join[
											{
												Style[tr["prefsHarnessesDetected"],
														FontSize -> Inherited,
														FontColor -> LightDarkSwitched[RGBColor["#d45d1c"], RGBColor["#ed8549"]],
														FontWeight -> "DemiBold"
													],
												configureAllButton[detectedClients, Dynamic[refresh]]
											},
											clientRow["Detected", #, clientNameSpacer, Dynamic[refresh]]& /@ detectedClients
										],
										ItemSize -> Scaled[1],
										Spacings -> {Automatic, {2 -> 1, 3 -> 1}}
									],
									FrameStyle -> LightDarkSwitched[RGBColor["#f6cfb6"], RGBColor["#77401a"]],
									FrameMargins -> 15,
									RoundingRadius -> 6
								]
							],
							If[
								otherClients === {}, Nothing,
								Framed[
									Column[
										Prepend[
											clientRow["Other", #, clientNameSpacer, Dynamic[refresh]]& /@ otherClients,
											Style[
												If[globallyConfiguredClients === detectedClients === {}, 
													tr["prefsHarnessesAll"],
													tr["prefsHarnessesMore"]
												],
												FontSize -> Inherited,
												FontColor -> ldsGray[0.4],
												FontWeight -> "DemiBold"
											]
										],
										ItemSize -> Scaled[1],
										Spacings -> {Automatic, {2 -> 1.5}}
									],
									FrameStyle -> LightDarkSwitched[GrayLevel[0.8980], GrayLevel[0.2862]],
									FrameMargins -> 15,
									RoundingRadius -> 6
								]
							]
						},
						Spacings -> 1
					]
			],
			TrackedSymbols :> {initDone, update}
		],

		Initialization :> (
			initDone = False;
			update = 0;
			clients = Keys @ Wolfram`AgentTools`$SupportedMCPClients;
			servers = Keys @ Wolfram`AgentTools`$DefaultMCPServers;
			clientNameSpacer = PaneSelector[KeyValueMap[#1 -> #2["DisplayName"]&, Wolfram`AgentTools`$SupportedMCPClients], True];
			(* If there are no stored settings for a client's selected toolset, initialize it to its default *)
			Do[
				CurrentValue[
					$FrontEnd,
					{PrivateFrontEndOptions, "InterfaceSettings", "ServicesForAIs", "SelectedToolset", client},
					Wolfram`AgentTools`$SupportedMCPClients[client]["DefaultToolset"]
				],
				{client, clients}
			];
			SetAttributes[refresh, HoldAll];
			refresh[evals___] := WithCleanup[
				CompoundExpression[update, evals],
				(*
					globallyConfiguredClients is the list of clients with a relevant, global configuration.
					If there are clients with relevant, per-directory configs but without a global config, 
					those will be in locallyConfiguredClients -- and thus in detectedClients -- instead.
				*)
				With[{ configured = {#["ClientName"], #["Toolset"], #["Scope"]}& /@  DeployedAgentTools[ ] },
					globallyConfiguredClients = Cases[configured, {name_, "Wolfram" | "WolframLanguage", "Global"} :> name];
					locallyConfiguredClients = Cases[configured, {name_, "Wolfram" | "WolframLanguage", _File} :> name];
				];
				detectedClients = Complement[
					Union[locallyConfiguredClients, Keys @ Wolfram`AgentTools`DetectedMCPClients[]],
					globallyConfiguredClients
				];
				otherClients = Complement[clients, globallyConfiguredClients, detectedClients];
				++update;
			];
			
			refresh[ ];
			initDone = True;
		),
		SynchronousInitialization -> False,
		UnsavedVariables :> {update, clients, servers, globallyConfiguredClients, locallyConfiguredClients, detectedClients, otherClients, clientNameSpacer, initDone, refresh}
	]


(* ::Section::Closed:: *)
(*configureAllButton*)


configureAllButton[detectedClients_, Dynamic[refresh_]] := 
	DynamicModule[{clicked = False},
		MouseAppearance[
			Button[
				Framed[
					Grid[{{
						Pane[
							icon["prefsConfigureAllIcon"],
							BaselinePosition -> Scaled[0.15]
						],
						PaneSelector[
							{
								False ->  tr["prefsConfigureAllButton"],
								True -> ProgressIndicator[Appearance -> "Percolate"]
							},
							Dynamic[Now; clicked],
							BaselinePosition -> Baseline
						]
					}}],
					clientControlFrameOptions[
						FrameMargins -> {{15,15},{10,10}}
					]
				],
				clicked = True;
				refresh @ Do[
					DeployAgentTools[
						client,
						CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "ServicesForAIs", "SelectedToolset", client}],
						OverwriteTarget -> True
					],
					{client, detectedClients}
				],
				ImageSize -> Automatic,
				BaseStyle -> {},
				DefaultBaseStyle -> {},
				Enabled -> Dynamic[!clicked],
				Appearance -> None,
				BaselinePosition -> Baseline,
				Method -> "Queued"
			]
			,
			"LinkHand"
		]
	]


(* ::Section::Closed:: *)
(*clientRow*)


ClearAll[clientRow];
clientRow[category_, client_, spacer_, Dynamic[refresh_]] :=
	Grid[
		{{
			clientName[client, spacer],
			clientControls[category, client, Dynamic[refresh]]
		}},
		Dividers -> {{False, True, False}, None},
		FrameStyle -> ldsGray[0.85],
		Spacings -> {2,2}
	]


(* ::Section::Closed:: *)
(*clientName*)


clientName[client_, spacer_] :=
	With[{
			displayName = Wolfram`AgentTools`$SupportedMCPClients[client]["DisplayName"],
			url = Wolfram`AgentTools`$SupportedMCPClients[client]["URL"]
		},

		If[
			StringQ[url],
			PaneSelector[
				{
					True -> Hyperlink[
							displayName,
							url,
							Tooltip -> ToBoxes[url],
							BaseStyle -> {FontColor -> ldsGray[0]},
							ActiveStyle -> {FontColor -> StandardBlue}
						],
					False -> spacer
				},
				True,
				Alignment -> Left,
				ImageMargins -> {{15,20},{0,0}}
			],
			client
		]
	]


(* ::Section::Closed:: *)
(*clientControls*)


(*
Note: The UX calls for this interface to list two MCP servers: "ComputationTools", and "DevelopmentTools".
However, $DefaultMCPServers currently returns a list of 4 servers, none of which have those names.

So for now, the code below lists only the two names from the UX, and maps them to current names thusly:

"Wolfram" === "ComputationTools"
"WolframLanguage" === "DevelopmentTools"

If the naming of MCP servers in $DefaultMCPServers ever changes in an incompatible way, this code will need
to be adjusted to stay in sync.
*)


clientControls[category_, client_, Dynamic[refresh_]] :=
	DynamicModule[{dirSettings},
		Grid[
			{
				{
					clientMenu[category, client, Dynamic[refresh]],
					clientButton[category, client, Dynamic[refresh]],
					clientInfoButton[category, client]
				},
				(*
					We cache per-directory settings when each instance of the interface is
					created. This allows us to continue displaying the info for any such
					objects, suitably restyled, after they have been removed by clicking
					the 'x' button.
				*)
				dirSettings = Cases[
					{#, #["Toolset"], #["Scope"], True}& /@ DeployedAgentTools[client],
					{_, "Wolfram" | "WolframLanguage", _File, _}
				];
				If[dirSettings === {},
					Nothing,
					{
						clientDirectorySettings[category, dirSettings],
						"", (* action button column *)
						"" (* info button column *)
					}
				]
			},
			Alignment -> Left,
			BaselinePosition -> 1,
			ItemSize -> Full
		]
	]


(* ::Section::Closed:: *)
(*clientMenu*)


clientMenu[category_, client_, Dynamic[refresh_]] := 
	PopupMenu[
		Dynamic[
			CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "ServicesForAIs", "SelectedToolset", client}],
			(
				CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "ServicesForAIs", "SelectedToolset", client}] = #;
				If[category === "Configured", refresh @ DeployAgentTools[client, #, OverwriteTarget -> True]]
			)&
		]
		,
		{
			"Wolfram" -> tr["prefsComputationTools"],
			"WolframLanguage" -> tr["prefsDevelopmentTools"]
		},
		None,
		Framed[
			Grid[
				{{
					Item[
						Dynamic[
							Replace[
								CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "ServicesForAIs", "SelectedToolset", client}],
								{
									"Wolfram" -> tr["prefsComputationTools"],
									"WolframLanguage" -> tr["prefsDevelopmentTools"]
								}
							]
						],
						ItemSize -> Fit
					],
					icon["prefsDownPointer", ldsGray[0.2], 10]
				}},
				Alignment -> Left,
				BaselinePosition -> {1,1}
			],
			Sequence @@ DeleteCases[
				{clientControlFrameOptions[ImageSize -> 320]},
				_[Background | FrameStyle, _]
			]
		],
		ImageSize -> 320,
		Appearance -> "ActionMenu",
		BaseStyle -> {}, (* needed in part to avoid very strange notebook-level settings in the Preferences Dialog *)
		DefaultBaseStyle -> {FrameBoxOptions -> {clientControlFrameOptions[]}},
		DefaultMenuStyle -> {}
	] // dimUnconfigured[category]


dimUnconfigured[category_][expr_] := 
If[
	category === "Configured",
	expr,
	RawBoxes @ Cell[
		BoxData @ FormBox[ToBoxes @ expr, "NoForm"],
		PrivateCellOptions -> {"ContentsOpacity" -> 0.3}
	]
]


(* ::Section::Closed:: *)
(*clientButton*)


SetAttributes[clientButtonTemplate, HoldRest]
clientButtonTemplate[label_, action_] :=
	DynamicModule[{clicked = False},
		MouseAppearance[
			Button[
				Framed[
					PaneSelector[
						{
							False -> label,
							True -> ProgressIndicator[Appearance -> "Percolate"]
						},
						Dynamic[Now; clicked],
						Alignment -> {Center, Center},
						BaselinePosition -> Baseline
					],
					clientControlFrameOptions[]
				],
				clicked = True; action,
				Method -> "Queued",
				BaseStyle -> {},
				DefaultBaseStyle -> {},
				Enabled -> Dynamic[!clicked],
				BaselinePosition -> Baseline,
				Appearance -> None
			],
			"LinkHand"
		]
	]


clientButton[category: "Configured", client_, Dynamic[refresh_]] := 
	clientButtonTemplate[ (* Disable button *)
		PaneSelector[{0 -> tr["prefsDisableButton"], 1 -> tr["prefsConfigureButton"]}, 0, Alignment -> Center],
		refresh @ DeleteObject @ Select[
			DeployedAgentTools @ client,
			#["Scope"] === "Global" && MatchQ[#["Toolset"], "Wolfram"|"WolframLanguage"]&
		]
	]


clientButton[category_, client_, Dynamic[refresh_]] := 
	clientButtonTemplate[ (* Configure button *)
		PaneSelector[{0 -> tr["prefsDisableButton"], 1 -> tr["prefsConfigureButton"]}, 1, Alignment -> Center],
		refresh @ DeployAgentTools[
			client,
			CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "ServicesForAIs", "SelectedToolset", client}],
			OverwriteTarget -> True
		]
	]


(* ::Section::Closed:: *)
(*clientInfoButton*)


(* Styling of this link/tooltip matches the standard Preferences dialog styling for such. *)


clientInfoButton[category_, client_] := 
	Module[{objects, info, locations},
		Switch[category,
			"Configured",
				(* link to the global prefs file we know exists *)
				objects = DeployedAgentTools[client];
				info = {#["Scope"], #["MCP"]["Server"], #["MCP"]["ConfigFile"]}& /@ objects;
				locations = Cases[info, {"Global", "Wolfram" | "WolframLanguage", File[loc_]} :> loc],
			"Detected",
				(* link to where the global prefs file should be *)
				locations = {FileNameJoin @ Replace[
					Wolfram`AgentTools`$SupportedMCPClients[client]["InstallLocation"],
					{
						a_Association :> Lookup[a, $OperatingSystem, {}],
						Except[_List] :> {}
					}
				]},
			_,
				locations = {}
		];

		If[
			MatchQ[locations, {__String}],
			With[{locations = locations},
				Button[
					Tooltip[
						NotebookTools`Mousedown[
							icon["prefsInfoIcon", LightDarkSwitched @ RGBColor["#898989"], 14],
							icon["prefsInfoIcon", LightDarkSwitched @ RGBColor[0.692, 0.692, 0.692], 14],
							icon["prefsInfoIcon", LightDarkSwitched @ RGBColor[0.358, 0.358, 0.358], 14]],
						Pane[
							Column[
								{
									Style[tr["prefsInstallLocation"], FontColor -> ldsGray[0.4]],
									Row[{#, "\[UpperRightArrow]"}, "\[NonBreakingSpace]"]& /@ locations
								} // Flatten
							],
							ImageMargins -> 3,
							ImageSize -> UpTo[274]
						],
						TooltipStyle -> {
							Background -> LightDarkSwitched @ RGBColor["#EDEDED"],
							CellFrameColor -> LightDarkSwitched @ RGBColor["#D1D1D1"],
							CellFrameMargins -> 5,
							FontColor -> LightDarkSwitched @ RGBColor["#333333"],
							FontFamily -> "Roboto",
							FontSize -> 11
						}
					],
					SystemOpen @ First @ locations,
					Appearance -> None
				]
			],
			""
		]
	]


(* ::Section::Closed:: *)
(*clientDirectorySettings*)


clientDirectorySettings[category_, dirSettings_] := 
	Pane[
		Dynamic[
			Grid[
				{
					{
						Style[tr["prefsSpecificDirectories"], 
							FontSize -> Inherited - 2,
							FontColor -> ldsGray[0.537]
						],
						SpanFromLeft,
						SpanFromLeft
					},
					Splice @ Table[
						dirSettingsRow[Dynamic[dirSettings], i, dirSettings[[i]]],
						{i, Length[dirSettings]}
					]
				},
				Alignment -> {{Left, Right, Right}},
				ItemSize -> {{Fit, Automatic, Automatic}},
				Spacings -> {1, Automatic},
				BaseStyle -> {PrivateFontOptions -> {"OperatorSubstitution" -> False}}
			],
			TrackedSymbols :> {dirSettings}
		],
		ImageSize -> 310,
		Alignment -> Left,
		ImageMargins -> 5
	] // dimUnconfigured[category]


(* ::Section::Closed:: *)
(*dirSettingsRow*)


dirSettingsRow[Dynamic[dirSettings_], i_, {obj_, server_, scope_, active_}] :=
	{
		(* directory display *)
		MouseAppearance[
			Button[
				Row[{
					Replace[scope,
						File[path_String] :>
							FE`Evaluate[FEPrivate`TruncateStringToWidth[path, "ControlStyle", 200, Left]]
					],
					If[active, " \[UpperRightArrow]", Nothing]
				}]
				,
				SystemOpen[scope],
				Appearance -> None,
				DefaultBaseStyle -> {},
				Enabled -> active,
				BaseStyle -> {
					FontColor -> Dynamic[If[active && CurrentValue["MouseOver"], StandardBlue, ldsGray[0.2]]],
					FontVariations -> If[active, {}, {"StrikeThrough" -> True}],
					FontSize -> Inherited - 2
				},
				BaselinePosition -> Baseline,
				ImageMargins -> {{5,0},{0,0}},
				Tooltip -> ToBoxes @ First @ obj["Scope"]
			],
			If[active, "LinkHand", Automatic]
		],
		(* toolset name *)
		Style[
			Replace[server, {
				"Wolfram" :> tr["prefsComputationTools"],
				"WolframLanguage" :> tr["prefsDevelopmentTools"]
			}],
			FontColor -> If[active, Inherited, ldsGray[0.392], Inherited],
			FontVariations -> If[active, {}, {"StrikeThrough" -> True}],
			FontSize -> Inherited - 2
		],
		(* directory operation buttons, if any *)
		If[$allowDirectoryOperations,
			Button[
				Mouseover[
					icon["prefsRemoveIcon", ldsGray[0.2], 10],
					icon["prefsRemoveIcon", StandardRed, 10]
				],
				DeleteObject[obj];
				dirSettings[[i, 4]] = False,
				Appearance -> None,
				DefaultBaseStyle -> {},
				BaseStyle -> {
					FontColor -> Dynamic[If[CurrentValue["MouseOver"], StandardBlue, ldsGray[0.5]]],
					ShowContents -> active
				},
				Tooltip -> ToBoxes @ tr["prefsUninstallTool"]
			],
			SpanFromLeft
		]
	}


(* ::Section::Closed:: *)
(*CreatePreferencesContent*)


CreatePreferencesContent // beginDefinition;


CreatePreferencesContent[] :=
Deploy[
	Pane[
		Column[
			{
				Grid[
					{{
						Item[
							Pane[
								StringTemplate[
										FrontEndResource["AgentToolsStrings", "prefsSubtitle"],
										CombinerFunction -> Row, 
										InsertionFunction -> Identity] @@
									Table[
										Tooltip[
											Mouseover[
												Row[{
													Style[tr[id], FontColor -> LightDarkSwitched @ Black],
													" ",
													icon["prefsInfoIcon", LightDarkSwitched @ RGBColor["#898989"], 14]
												}],
												Row[{
													Style[tr[id], FontColor -> LightDarkSwitched @ Gray],
													" ",
													icon["prefsInfoIcon", LightDarkSwitched @ RGBColor[0.692, 0.692, 0.692], 14]
												}]
											],
											tr[id <> "Description"]
										],
										{id, {"prefsComputationTools", "prefsDevelopmentTools"}}
									],
								Alignment -> Left,
								ImageMargins -> {{25,25},{0,15}}
							],	
							ItemSize -> Fit
						],
						Pane[
							Item[docsLink[], Alignment -> Right],
							Alignment -> Left,
							ImageMargins -> {{0,20},{0,0}}
						]
							
					}},
					Alignment -> {Left, Center},
					BaseStyle -> {LinebreakAdjustments -> {1, 10, 1, 0, 1}},
					Spacings -> {2,0}
				],

				Pane[
					clientInterfaces[],
					Alignment -> Left,
					ImageMargins -> {{15,5},{0,0}}
				]
			},
			ItemSize -> Scaled[1],
			Spacings -> {Automatic, {0,1}}
		],
		Alignment -> Left,
		ImageMargins -> {0,{11,11}}
	]
]



CreatePreferencesContent // endExportedDefinition;


(* ::Section::Closed:: *)
(*Package Footer*)


addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
