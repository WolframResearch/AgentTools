(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

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
(*Tool Registration*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Registered in $DefaultMCPTools*)
VerificationTest[
    KeyExistsQ[ $DefaultMCPTools, "NotebookViewer" ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewer-RegisteredInDefaultTools"
]

VerificationTest[
    Head @ $DefaultMCPTools[ "NotebookViewer" ],
    LLMTool,
    SameTest -> Equal,
    TestID   -> "NotebookViewer-IsLLMTool"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Returns Correct Structure*)
VerificationTest[
    result = Wolfram`AgentTools`Tools`NotebookViewer`Private`notebookViewerEvaluate[
        <| "url" -> "https://www.wolframcloud.com/obj/test/notebook" |>
    ];
    MatchQ[ result, <| "Content" -> { _Association } |> ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewer-ReturnsContentStructure"
]

VerificationTest[
    result = Wolfram`AgentTools`Tools`NotebookViewer`Private`notebookViewerEvaluate[
        <| "url" -> "https://www.wolframcloud.com/obj/test/notebook" |>
    ];
    result[[ "Content", 1, "type" ]],
    "text",
    SameTest -> Equal,
    TestID   -> "NotebookViewer-ContentTypeIsText"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Response JSON Contains URL*)
VerificationTest[
    result = Wolfram`AgentTools`Tools`NotebookViewer`Private`notebookViewerEvaluate[
        <| "url" -> "https://www.wolframcloud.com/obj/test/notebook" |>
    ];
    json = Developer`ReadRawJSONString @ result[[ "Content", 1, "text" ]];
    json[ "url" ],
    "https://www.wolframcloud.com/obj/test/notebook",
    SameTest -> Equal,
    TestID   -> "NotebookViewer-ResponseContainsURL"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Response JSON Contains allowInteract*)
VerificationTest[
    result = Wolfram`AgentTools`Tools`NotebookViewer`Private`notebookViewerEvaluate[
        <| "url" -> "https://www.wolframcloud.com/obj/test/notebook" |>
    ];
    json = Developer`ReadRawJSONString @ result[[ "Content", 1, "text" ]];
    json[ "allowInteract" ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewer-DefaultAllowInteract"
]

VerificationTest[
    result = Wolfram`AgentTools`Tools`NotebookViewer`Private`notebookViewerEvaluate[
        <| "url" -> "https://www.wolframcloud.com/obj/test/notebook", "allowInteract" -> False |>
    ];
    json = Developer`ReadRawJSONString @ result[[ "Content", 1, "text" ]];
    json[ "allowInteract" ],
    False,
    SameTest -> Equal,
    TestID   -> "NotebookViewer-ExplicitAllowInteractFalse"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Response JSON Contains maxHeight*)
VerificationTest[
    result = Wolfram`AgentTools`Tools`NotebookViewer`Private`notebookViewerEvaluate[
        <| "url" -> "https://www.wolframcloud.com/obj/test/notebook" |>
    ];
    json = Developer`ReadRawJSONString @ result[[ "Content", 1, "text" ]];
    MissingQ @ json[ "maxHeight" ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewer-DefaultOmitsMaxHeight"
]

VerificationTest[
    result = Wolfram`AgentTools`Tools`NotebookViewer`Private`notebookViewerEvaluate[
        <| "url" -> "https://www.wolframcloud.com/obj/test/notebook", "maxHeight" -> 1200 |>
    ];
    json = Developer`ReadRawJSONString @ result[[ "Content", 1, "text" ]];
    json[ "maxHeight" ],
    1200,
    SameTest -> Equal,
    TestID   -> "NotebookViewer-ExplicitMaxHeight"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Optional Parameters Handled*)
VerificationTest[
    result = Wolfram`AgentTools`Tools`NotebookViewer`Private`notebookViewerEvaluate[
        <| "url" -> "https://www.wolframcloud.com/obj/test/notebook", "allowInteract" -> Missing[ "NoInput" ] |>
    ];
    json = Developer`ReadRawJSONString @ result[[ "Content", 1, "text" ]];
    json[ "allowInteract" ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewer-MissingAllowInteractDefaultsToTrue"
]

VerificationTest[
    result = Wolfram`AgentTools`Tools`NotebookViewer`Private`notebookViewerEvaluate[
        <| "url" -> "https://www.wolframcloud.com/obj/test/notebook", "maxHeight" -> Missing[ "NoInput" ] |>
    ];
    json = Developer`ReadRawJSONString @ result[[ "Content", 1, "text" ]];
    MissingQ @ json[ "maxHeight" ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewer-MissingMaxHeightOmitsKey"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*UI Resource Integration*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool UI Associations*)
VerificationTest[
    KeyExistsQ[ Wolfram`AgentTools`Common`$toolUIAssociations, "NotebookViewer" ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewer-InToolUIAssociations"
]

VerificationTest[
    Wolfram`AgentTools`Common`$toolUIAssociations[ "NotebookViewer" ],
    "ui://wolfram/notebook-viewer",
    SameTest -> Equal,
    TestID   -> "NotebookViewer-CorrectResourceURI"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolUIMetadata*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = True },
        meta = Wolfram`AgentTools`Common`toolUIMetadata[ "NotebookViewer" ];
        ("_meta" /. meta)[ "ui", "resourceUri" ]
    ],
    "ui://wolfram/notebook-viewer",
    SameTest -> Equal,
    TestID   -> "NotebookViewer-ToolUIMetadataResourceURI"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = True },
        meta = Wolfram`AgentTools`Common`toolUIMetadata[ "NotebookViewer" ];
        ("_meta" /. meta)[ "ui", "visibility" ]
    ],
    { "model", "app" },
    SameTest -> Equal,
    TestID   -> "NotebookViewer-ToolUIMetadataVisibility"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Resource Registry*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        KeyExistsQ[ Wolfram`AgentTools`Common`$uiResourceRegistry, "ui://wolfram/notebook-viewer" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewer-InResourceRegistry"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`$uiResourceRegistry[ "ui://wolfram/notebook-viewer", "mimeType" ]
    ],
    "text/html;profile=mcp-app",
    SameTest -> Equal,
    TestID   -> "NotebookViewer-ResourceMimeType"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readUIResource*)
VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        result = Wolfram`AgentTools`Common`readUIResource[
            <| "params" -> <| "uri" -> "ui://wolfram/notebook-viewer" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ];
        StringContainsQ[ result[[ "contents", 1, "text" ]], "WolframNotebookEmbedder" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewer-ReadUIResourceContainsEmbedder"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        result = Wolfram`AgentTools`Common`readUIResource[
            <| "params" -> <| "uri" -> "ui://wolfram/notebook-viewer" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ];
        result[[ "contents", 1, "mimeType" ]]
    ],
    "text/html;profile=mcp-app",
    SameTest -> Equal,
    TestID   -> "NotebookViewer-ReadUIResourceMimeType"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*JSON Metadata*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`$uiResourceRegistry[ "ui://wolfram/notebook-viewer", "meta" ]
    ],
    KeyValuePattern[ "ui" -> KeyValuePattern[ "prefersBorder" -> True ] ],
    SameTest -> MatchQ,
    TestID   -> "NotebookViewer-JSONMetadataLoaded"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`$uiResourceRegistry[
            "ui://wolfram/notebook-viewer", "meta", "ui", "csp", "frameDomains"
        ]
    ],
    { "https://www.wolframcloud.com", "https://wolfr.am" },
    SameTest -> Equal,
    TestID   -> "NotebookViewer-CSPFrameDomains"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`$uiResourceRegistry[
            "ui://wolfram/notebook-viewer", "meta", "ui", "csp", "resourceDomains"
        ]
    ],
    { "https://unpkg.com", "https://www.wolframcloud.com" },
    SameTest -> Equal,
    TestID   -> "NotebookViewer-CSPResourceDomains"
]

(* :!CodeAnalysis::EndBlock:: *)
