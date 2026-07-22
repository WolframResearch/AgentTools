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

(* A cloud object UUID (8-4-4-4-12 hexadecimal characters). Notebooks are deployed with
   CloudObjectNameFormat -> "UUID", so the deployed URL is https://www.wolframcloud.com/obj/<uuid>;
   cloudNotebookUUID pulls the uuid back out for the <result uuid="..."> marker. *)
$$notebookUUID =
    Repeated[ HexadecimalCharacter, { 8 } ] ~~ "-" ~~ Repeated[ HexadecimalCharacter, { 4 } ] ~~ "-" ~~
    Repeated[ HexadecimalCharacter, { 4 } ] ~~ "-" ~~ Repeated[ HexadecimalCharacter, { 4 } ] ~~ "-" ~~
    Repeated[ HexadecimalCharacter, { 12 } ];

(* Inline notebooks are not yet the default since there are still some issues to work out.
   These can be enabled via the following environment variable: *)
$mcpAppsNotebookMethod := $mcpAppsNotebookMethod = Environment[ "MCP_APPS_NOTEBOOK_METHOD" ];

(* The production cloud base assumed by the static app assets in Assets/Apps. When $CloudBase
   differs (e.g. set from the WOLFRAM_CLOUDBASE environment variable at server startup), the
   assets are rewritten as they are loaded (see applyCloudBaseToHTML and applyCloudBaseToMeta). *)
$defaultCloudBase = "https://www.wolframcloud.com";

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
   resources/read, we additionally wrap the (non-dropped) text content in a <result uuid="...">
   marker whose uuid identifies the deployed cloud notebook. A viewer reconstructs the notebook
   URL from the uuid (https://www.wolframcloud.com/obj/<uuid>) and strips the surrounding <result>
   tags before rendering, so they never reach the user. *)
makeNotebookUIResult // beginDefinition;

makeNotebookUIResult[ textContent_List, deployed_String ] := <|
    "Content" -> wrapResultTags[ textContent, deployed ],
    "_meta"   -> <| "notebookUrl" -> notebookEmbedURL @ deployed |>
|>;

(* Deployment failed (deployCloudNotebookForMCPApp returned $Failed): no UI result. *)
makeNotebookUIResult[ _List, _ ] := $Failed;

makeNotebookUIResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookEmbedURL*)
(* The notebookUrl delivered to viewers via _meta: the deployed cloud URL with a
   syntaxMethod=editor query parameter appended. The viewers append the same parameter when
   reconstructing a URL from a <result uuid="..."> marker (extractNotebookUrlMarker), so the
   two delivery paths must stay in sync. Non-URL values (inline serialized notebooks) pass
   through unchanged. *)
notebookEmbedURL // beginDefinition;

notebookEmbedURL[ url_String ] /; StringStartsQ[ url, "http" ] :=
    url <> If[ StringFreeQ[ url, "?" ], "?", "&" ] <> "syntaxMethod=editor";

notebookEmbedURL[ other_ ] := other;

notebookEmbedURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*wrapResultTags*)
(* Wraps the result content in a <result uuid="..."> ... </result> marker. The uuid identifies the
   deployed cloud notebook; a viewer that lost _meta reconstructs the URL from it and strips the tags
   before rendering. The format lives here on the WL side; the viewers' extraction and strip regexes
   must stay in sync with these tags. *)
wrapResultTags // beginDefinition;

(* Only cloud URLs are wrapped this way. Inline notebooks (MCP_APPS_NOTEBOOK_METHOD="Inline")
   carry the whole serialized notebook as the value and are delivered via _meta only, never
   embedded in the content. *)
wrapResultTags[ textContent_List, url_String ] /; StringStartsQ[ url, "http" ] :=
    Join[
        { <| "type" -> "text", "text" -> "<result uuid=\"" <> cloudNotebookUUID @ url <> "\">\n" |> },
        textContent,
        { <| "type" -> "text", "text" -> "\n</result>" |> }
    ];

wrapResultTags[ textContent_List, _ ] := textContent;

wrapResultTags // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudNotebookUUID*)
(* Notebooks are deployed with CloudObjectNameFormat -> "UUID", so the deployed URL has the form
   https://www.wolframcloud.com/obj/<uuid>. Pull the uuid back out for the <result uuid="..."> marker;
   a viewer reconstructs the same URL as https://www.wolframcloud.com/obj/<uuid>. Falls back to the
   last path segment if the URL is not in UUID form. *)
cloudNotebookUUID // beginDefinition;
cloudNotebookUUID[ url_String ] := First[ StringCases[ url, $$notebookUUID ], Last @ StringSplit[ url, "/" ] ];
cloudNotebookUUID // endDefinition;

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
            AppearanceElements    -> None,
            AutoRemove            -> True,
            (* Deploy to the hashed path (so identical evaluations reuse one object) but return the
               URL in UUID form (https://www.wolframcloud.com/obj/<uuid>), which cloudNotebookUUID
               reads for the <result uuid="..."> marker. *)
            CloudObjectNameFormat -> "UUID",
            IconRules             -> { },
            Permissions           -> { "All" -> { "Read", "Interact" } }
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
    AutoRemove            -> True,
    CloudObjectNameFormat -> "UUID",
    IconRules             -> { },
    Permissions           -> { "All" -> { "Read", "Interact" } }
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
        html = ConfirmBy[ applyCloudBaseToHTML @ ByteArrayToString @ ReadByteArray @ htmlFile, StringQ, "HTML" ];
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
            "meta"     -> applyCloudBaseToMeta @ Replace[ meta, Except[ _Association ] :> <| |> ]
        |>
    ],
    throwInternalFailure
];

loadUIResource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*currentCloudBase*)
(* The cloud base currently in effect, normalized for use in URLs and CSP origins: no trailing
   slash and an explicit scheme (https:// is assumed when missing, matching the cloud object
   framework's normalization). Falls back to $defaultCloudBase when $CloudBase is unusable. *)
currentCloudBase // beginDefinition;

currentCloudBase[ ] := (CloudObject; currentCloudBase @ $CloudBase);
currentCloudBase[ URL[ base_String ] ] := currentCloudBase @ base;

currentCloudBase[ base0_String ] :=
    With[ { base = StringDelete[ StringTrim @ base0, "/".. ~~ EndOfString ] },
        Which[
            StringMatchQ[ base, ("http"|"https") ~~ "://" ~~ __, IgnoreCase -> True ], base,
            StringFreeQ[ base, "://" ] && base =!= "", "https://" <> base,
            True, $defaultCloudBase
        ]
    ];

currentCloudBase[ _ ] := $defaultCloudBase;

currentCloudBase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyCloudBaseToHTML*)
(* The viewers cannot read environment variables from their sandboxed JavaScript, so each one
   declares the cloud base in a `var WOLFRAM_CLOUDBASE = "..."` assignment (used e.g. to
   reconstruct notebook URLs from <result uuid="..."> markers). When a custom cloud base is in
   effect, rewrite that assignment as the HTML is read from disk. *)
applyCloudBaseToHTML // beginDefinition;

applyCloudBaseToHTML[ html_String ] := applyCloudBaseToHTML[ html, currentCloudBase[ ] ];

applyCloudBaseToHTML[ html_String, base_String ] /; base === $defaultCloudBase := html;

applyCloudBaseToHTML[ html_String, base_String ] := StringReplace[
    html,
    "var WOLFRAM_CLOUDBASE = \"" <> $defaultCloudBase <> "\";" ->
        "var WOLFRAM_CLOUDBASE = \"" <> base <> "\";"
];

applyCloudBaseToHTML // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyCloudBaseToMeta*)
(* The JSON metadata declares CSP domain lists (connectDomains, resourceDomains, frameDomains)
   that allow the default cloud base. A custom cloud base must also be allowed by the host's
   sandbox CSP, so prepend it to every list that already allows the default base. The default
   entries are intentionally kept: production URLs remain reachable (e.g. wolfr.am frames can
   redirect to production wolframcloud.com). *)
applyCloudBaseToMeta // beginDefinition;

applyCloudBaseToMeta[ meta_Association ] := applyCloudBaseToMeta[ meta, currentCloudBase[ ] ];

applyCloudBaseToMeta[ meta_Association, base_String ] /; base === $defaultCloudBase := meta;

applyCloudBaseToMeta[ meta_Association, base_String ] :=
    applyCloudBaseToMeta[ meta, base, meta[ "ui", "csp" ] ];

applyCloudBaseToMeta[ meta_Association, base_String, csp_Association ] :=
    Module[ { updated = meta },
        updated[ "ui", "csp" ] = Map[
            Function[ domains,
                If[ MatchQ[ domains, { ___String } ] && MemberQ[ domains, $defaultCloudBase ] && ! MemberQ[ domains, base ],
                    Prepend[ domains, base ],
                    domains
                ]
            ],
            csp
        ];
        updated
    ];

applyCloudBaseToMeta[ meta_Association, _String, _ ] := meta;

applyCloudBaseToMeta // endDefinition;

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
