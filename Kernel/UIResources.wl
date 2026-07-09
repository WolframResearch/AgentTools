(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`UIResources`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

(* Mapping of tool names to their associated UI resource URIs *)
$toolUIAssociations = <|
    "NotebookViewer"           -> "ui://wolfram/notebook-viewer",
    "MCPAppsTest"              -> "ui://wolfram/mcp-apps-test",
    "WolframLanguageEvaluator" -> "ui://wolfram/evaluator-viewer",
    (* The WolframAlpha tool does not have a text-only fallback app view, so we make it conditional *)
    "WolframAlpha" :> If[ $deployCloudNotebooks, "ui://wolfram/wolframalpha-viewer", None ]
|>;

$includeAppearanceElements = False;
$deployedNotebookRoot      = "AgentTools/Notebooks";
$deployCloudNotebooks     := $deployCloudNotebooks = $CloudConnected; (* must be connected to deploy notebooks *)

(* Inline notebooks are not yet the default since there are still some issues to work out.
   These can be enabled via the following environment variable: *)
$mcpAppsNotebookMethod := $mcpAppsNotebookMethod = Environment[ "MCP_APPS_NOTEBOOK_METHOD" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cloud Notebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deployCloudNotebookForMCPApp*)
deployCloudNotebookForMCPApp // beginDefinition;

deployCloudNotebookForMCPApp[ nb_Notebook, _ ] /; $mcpAppsNotebookMethod === "Inline" := Enclose[
    (* This should be true if this function is being called: *)
    ConfirmAssert[ $deployCloudNotebooks, "DeployCloudNotebooksAssert" ];

    ConfirmBy[ ExportString[ nb, "NB" ], StringQ, "Exported" ],
    throwInternalFailure
];

deployCloudNotebookForMCPApp[ nb_Notebook, identifier_ ] := Enclose[
    Module[ { hash, target, deployed },

        (* This should be true if this function is being called: *)
        ConfirmAssert[ $deployCloudNotebooks, "DeployCloudNotebooksAssert" ];

        hash = ConfirmBy[ Hash[ Unevaluated @ identifier, Automatic, "HexString" ], StringQ, "Hash" ];

        target = ConfirmMatch[
            FileNameJoin @ {
                CloudObject[ $deployedNotebookRoot, Permissions -> { "All" -> { "Read", "Interact" } } ],
                hash <> ".nb"
            },
            _CloudObject,
            "Target"
        ];

        deployed = ConfirmMatch[
            cloudDeployTryAppearanceElements[ nb, target ],
            _CloudObject | _? FailureQ,
            "Deployed"
        ];

        If[ MatchQ[ deployed, _CloudObject ],
            ConfirmBy[ First @ deployed, StringQ, "Result" ],
            (* If deploying failed, disable cloud notebook deployment for the remainder of the session: *)
            $deployCloudNotebooks = False;
            $Failed
        ]
    ],
    throwInternalFailure
];

deployCloudNotebookForMCPApp // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeNotebookUIResult*)
(* Builds the UI-enhanced tool result for a deployed notebook. The notebookUrl is carried in
   _meta so it reaches the app without entering model context. We deliberately do not include
   structuredContent (the MCP Apps spec's other UI-only channel): some clients discard the tool
   result's content (text/images) entirely when structuredContent is present, which we do not
   want. Because some hosts also drop _meta (ext-apps#696) and do not forward app-initiated
   resources/read, we additionally append the URL to the (non-dropped) text content inside an
   <internal>...<url>...</url></internal> marker. The wrapper text tells the model the notebook
   is already shown and the URL is not for it to use; each viewer extracts the URL and strips
   the whole marker before rendering. *)
makeNotebookUIResult // beginDefinition;

makeNotebookUIResult[ textContent_List, deployed_String ] := <|
    "Content" -> appendNotebookURLMarker[ textContent, deployed ],
    "_meta"   -> <| "notebookUrl" -> deployed |>
|>;

(* Deployment failed (deployCloudNotebookForMCPApp returned $Failed): no UI result. *)
makeNotebookUIResult[ _List, _ ] := $Failed;

makeNotebookUIResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendNotebookURLMarker*)
appendNotebookURLMarker // beginDefinition;

(* Only cloud URLs are embedded this way. Inline notebooks (MCP_APPS_NOTEBOOK_METHOD="Inline")
   carry the whole serialized notebook as the value and are delivered via _meta only, never
   embedded in the content. *)
appendNotebookURLMarker[ textContent_List, url_String ] /; StringStartsQ[ url, "http" ] :=
    Append[ textContent, <| "type" -> "text", "text" -> notebookURLMarkerText[ url ] |> ];

appendNotebookURLMarker[ textContent_List, _ ] := textContent;

appendNotebookURLMarker // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookURLMarkerText*)
(* Wraps the URL in an instruction the model can read (so it ignores the URL) and in <url> tags
   the viewer matches. The format lives here on the WL side; the viewers' extraction and strip
   regexes must stay in sync with these tags. *)
notebookURLMarkerText // beginDefinition;

notebookURLMarkerText[ url_String ] := StringJoin[
    "<internal>",
    "This tool call was displayed to the user as an interactive notebook, which they can already see. ",
    "The URL below only renders that notebook; you do not need to read, repeat, visit, or otherwise use it. ",
    "<url>", url, "</url>",
    "</internal>"
];

notebookURLMarkerText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*delayedDisplay*)
(* This is a workaround for plots showing up empty when embedding an inline notebook expression instead of a URL *)
delayedDisplay // beginDefinition;

delayedDisplay[ boxes_ ] /; $mcpAppsNotebookMethod =!= "Inline" := boxes;

delayedDisplay[ boxes_ ] /; FreeQ[ boxes, GraphicsBox|Graphics3DBox ] := boxes;

delayedDisplay[ boxes_ ] :=
    With[ { b64 = BaseEncode @ BinarySerialize[ Unevaluated @ RawBoxes @ boxes, PerformanceGoal -> "Size" ] },
        ToBoxes @ DynamicModule[
            { display },
            Dynamic[ Replace[ display, _Symbol :> ProgressIndicator[ Appearance -> "Percolate" ] ] ],
            Initialization            :> (display = BinaryDeserialize @ BaseDecode @ b64),
            SynchronousInitialization -> False,
            UnsavedVariables          :> { display }
        ]
    ];

delayedDisplay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudDeployTryAppearanceElements*)
cloudDeployTryAppearanceElements // beginDefinition;

cloudDeployTryAppearanceElements[ expr_, target_ ] /; $includeAppearanceElements :=
    cloudDeployWithAppearanceElements[ expr, target ];

(* This tries to CloudDeploy with AppearanceElements -> None, since the footer links will not be clickable in the app.
   However, some cloud accounts do not support this option, which causes CloudDeploy to fail with a message.
   In that case, we retry without the AppearanceElements option. *)
cloudDeployTryAppearanceElements[ expr_, target_ ] := Quiet[
    Check[
        CloudDeploy[
            expr,
            target,
            AppearanceElements -> None,
            AutoRemove         -> True,
            IconRules          -> { },
            Permissions        -> { "All" -> { "Read", "Interact" } }
        ],
        (* Disable this check for the remainder of the session: *)
        $includeAppearanceElements = True;
        cloudDeployWithAppearanceElements[ expr, target ],
        { CloudDeploy::appearancenotsup }
    ],
    { CloudDeploy::appearancenotsup }
];

cloudDeployTryAppearanceElements // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudDeployWithAppearanceElements*)
cloudDeployWithAppearanceElements // beginDefinition;

cloudDeployWithAppearanceElements[ expr_, target_ ] := CloudDeploy[
    expr,
    target,
    AutoRemove  -> True,
    IconRules   -> { },
    Permissions -> { "All" -> { "Read", "Interact" } }
];

cloudDeployWithAppearanceElements // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*MCP Integration Helpers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*clientSupportsUIQ*)
clientSupportsUIQ // beginDefinition;

clientSupportsUIQ[ msg_Association ] :=
    ! MissingQ @ msg[ "params", "capabilities", "extensions", "io.modelcontextprotocol/ui" ];

clientSupportsUIQ[ _ ] := False;

clientSupportsUIQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mcpAppsEnabledQ*)
mcpAppsEnabledQ // beginDefinition;

mcpAppsEnabledQ[ ] :=
    With[ { val = Environment[ "MCP_APPS_ENABLED" ] },
        ! StringQ[ val ] || ! StringMatchQ[ val, "false", IgnoreCase -> True ]
    ];

mcpAppsEnabledQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initializeUIResources*)
initializeUIResources // beginDefinition;

initializeUIResources[ ] := Enclose[
    Module[ { assetsDir, htmlFiles },
        assetsDir = ConfirmBy[
            PacletObject[ "Wolfram/AgentTools" ][ "AssetLocation", "Apps" ],
            DirectoryQ,
            "AssetsDir"
        ];
        htmlFiles = FileNames[ "*.html", assetsDir ];
        $uiResourceRegistry = Association[
            loadUIResource /@ htmlFiles
        ];
        debugPrint[ "Loaded " <> ToString[ Length @ htmlFiles ] <> " UI resources" ];
    ],
    (
        (* Graceful fallback: no UI resources. Log the error but do not fail startup. *)
        writeError[ "Failed to load UI app assets. MCP Apps will be disabled." ];
        $uiResourceRegistry = <| |>
    ) &
];

initializeUIResources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadUIResource*)
loadUIResource // beginDefinition;

loadUIResource[ htmlFile_String ] := Enclose[
    Module[ { baseName, uri, html, metaFile, meta },
        baseName = FileBaseName @ htmlFile;
        uri = "ui://wolfram/" <> baseName;
        html = ConfirmBy[ ByteArrayToString @ ReadByteArray @ htmlFile, StringQ, "HTML" ];
        metaFile = FileNameJoin[ { DirectoryName @ htmlFile, baseName <> ".json" } ];
        meta = If[ FileExistsQ @ metaFile,
            Quiet @ Developer`ReadRawJSONString @ ByteArrayToString @ ReadByteArray @ metaFile,
            <| |>
        ];
        uri -> <|
            "uri"      -> uri,
            "name"     -> baseName,
            "mimeType" -> "text/html;profile=mcp-app",
            "html"     -> html,
            "meta"     -> Replace[ meta, Except[ _Association ] :> <| |> ]
        |>
    ],
    throwInternalFailure
];

loadUIResource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*listUIResources*)
listUIResources // beginDefinition;

listUIResources[ ] :=
    If[ TrueQ @ $clientSupportsUI,
        KeyValueMap[
            Function[ { uri, data },
                <|
                    "uri"         -> uri,
                    "name"        -> data[ "name" ],
                    "description" -> Lookup[ data, "description", "" ],
                    "mimeType"    -> data[ "mimeType" ]
                |>
            ],
            $uiResourceRegistry
        ],
        { }
    ];

listUIResources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readUIResource*)
readUIResource // beginDefinition;

readUIResource[ msg_Association, req_ ] := Enclose[
    Module[ { uri, resource },
        uri = ConfirmBy[ msg[[ "params", "uri" ]], StringQ, "URI" ];
        resource = Lookup[ $uiResourceRegistry, uri, Missing[ "NotFound" ] ];
        If[ MissingQ @ resource,
            throwFailure[ "UIResourceNotFound", uri ],
            <| "contents" -> {
                <|
                    "uri"      -> resource[ "uri" ],
                    "mimeType" -> resource[ "mimeType" ],
                    "text"     -> resource[ "html" ],
                    "_meta"    -> resource[ "meta" ]
                |>
            } |>
        ]
    ],
    throwInternalFailure
];

readUIResource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolUIMetadata*)
toolUIMetadata // beginDefinition;

toolUIMetadata[ toolName_String ] :=
    If[ TrueQ @ $clientSupportsUI,
        toolUIMetadata[ toolName, Lookup[ $toolUIAssociations, toolName, None ] ],
        { }
    ];

toolUIMetadata[ toolName_String, uri_String ] :=
    { "_meta" -> <| "ui" -> <| "resourceUri" -> uri, "visibility" -> { "model", "app" } |> |> };

toolUIMetadata[ toolName_String, None ] := { };

toolUIMetadata // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withToolUIMetadata*)
withToolUIMetadata // beginDefinition;

withToolUIMetadata[ tools_List ] :=
    Map[
        Function[ tool, Join[ tool, Association @ toolUIMetadata[ tool[ "name" ] ] ] ],
        tools
    ];

withToolUIMetadata // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
