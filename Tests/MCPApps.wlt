(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/MCPApps.wlt:7,1-12,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/MCPApps.wlt:14,1-19,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Unit Tests*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*clientSupportsUIQ*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*UI-Capable Clients*)
VerificationTest[
    Wolfram`AgentTools`Common`clientSupportsUIQ @ <|
        "method" -> "initialize",
        "params" -> <|
            "protocolVersion" -> "2024-11-05",
            "capabilities" -> <|
                "extensions" -> <|
                    "io.modelcontextprotocol/ui" -> <|
                        "mimeTypes" -> { "text/html;profile=mcp-app" }
                    |>
                |>
            |>,
            "clientInfo" -> <| "name" -> "claude-desktop", "version" -> "1.0.0" |>
        |>
    |>,
    True,
    SameTest -> Equal,
    TestID   -> "ClientSupportsUIQ-UIClient@@Tests/MCPApps.wlt:32,1-50,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Non-UI Clients*)
VerificationTest[
    Wolfram`AgentTools`Common`clientSupportsUIQ @ <|
        "method" -> "initialize",
        "params" -> <|
            "protocolVersion" -> "2024-11-05",
            "capabilities" -> <| |>,
            "clientInfo" -> <| "name" -> "test-client" |>
        |>
    |>,
    False,
    SameTest -> Equal,
    TestID   -> "ClientSupportsUIQ-NoExtensions@@Tests/MCPApps.wlt:55,1-67,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`clientSupportsUIQ @ <|
        "method" -> "initialize",
        "params" -> <|
            "protocolVersion" -> "2024-11-05",
            "capabilities" -> <|
                "extensions" -> <| "other/extension" -> <| |> |>
            |>,
            "clientInfo" -> <| "name" -> "test-client" |>
        |>
    |>,
    False,
    SameTest -> Equal,
    TestID   -> "ClientSupportsUIQ-OtherExtension@@Tests/MCPApps.wlt:69,1-83,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`clientSupportsUIQ @ <|
        "method" -> "initialize",
        "params" -> <|
            "protocolVersion" -> "2024-11-05",
            "clientInfo" -> <| "name" -> "test-client" |>
        |>
    |>,
    False,
    SameTest -> Equal,
    TestID   -> "ClientSupportsUIQ-NoCapabilities@@Tests/MCPApps.wlt:85,1-96,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`clientSupportsUIQ @ <| "method" -> "initialize" |>,
    False,
    SameTest -> Equal,
    TestID   -> "ClientSupportsUIQ-NoParams@@Tests/MCPApps.wlt:98,1-103,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Invalid Inputs*)
VerificationTest[
    Wolfram`AgentTools`Common`clientSupportsUIQ @ "not an association",
    False,
    SameTest -> Equal,
    TestID   -> "ClientSupportsUIQ-NonAssociation@@Tests/MCPApps.wlt:108,1-113,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`clientSupportsUIQ @ Null,
    False,
    SameTest -> Equal,
    TestID   -> "ClientSupportsUIQ-Null@@Tests/MCPApps.wlt:115,1-120,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mcpAppsEnabledQ*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Enabled When Env Var Not Set*)
VerificationTest[
    Block[ { $Environment },
        Unset[ $Environment ];
        Wolfram`AgentTools`Common`mcpAppsEnabledQ[ ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPAppsEnabled-NotSet@@Tests/MCPApps.wlt:129,1-137,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Disabled When Env Var Is "false"*)
VerificationTest[
    Block[ { Environment },
        Environment[ "MCP_APPS_ENABLED" ] = "false";
        Wolfram`AgentTools`Common`mcpAppsEnabledQ[ ]
    ],
    False,
    SameTest -> Equal,
    TestID   -> "MCPAppsEnabled-FalseLowercase@@Tests/MCPApps.wlt:142,1-150,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Case Insensitive Check*)
VerificationTest[
    Block[ { Environment },
        Environment[ "MCP_APPS_ENABLED" ] = "False";
        Wolfram`AgentTools`Common`mcpAppsEnabledQ[ ]
    ],
    False,
    SameTest -> Equal,
    TestID   -> "MCPAppsEnabled-FalseMixedCase@@Tests/MCPApps.wlt:155,1-163,2"
]

VerificationTest[
    Block[ { Environment },
        Environment[ "MCP_APPS_ENABLED" ] = "FALSE";
        Wolfram`AgentTools`Common`mcpAppsEnabledQ[ ]
    ],
    False,
    SameTest -> Equal,
    TestID   -> "MCPAppsEnabled-FalseUppercase@@Tests/MCPApps.wlt:165,1-173,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Enabled For Other Values*)
VerificationTest[
    Block[ { Environment },
        Environment[ "MCP_APPS_ENABLED" ] = "true";
        Wolfram`AgentTools`Common`mcpAppsEnabledQ[ ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPAppsEnabled-TrueString@@Tests/MCPApps.wlt:178,1-186,2"
]

VerificationTest[
    Block[ { Environment },
        Environment[ "MCP_APPS_ENABLED" ] = "1";
        Wolfram`AgentTools`Common`mcpAppsEnabledQ[ ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPAppsEnabled-OneString@@Tests/MCPApps.wlt:188,1-196,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Integration: Disables $clientSupportsUI*)
VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI,
        Environment
    },
        Environment[ "MCP_APPS_ENABLED" ] = "false";
        Wolfram`AgentTools`Common`$clientSupportsUI =
            Wolfram`AgentTools`Common`mcpAppsEnabledQ[ ] &&
            Wolfram`AgentTools`Common`clientSupportsUIQ @ <|
                "params" -> <|
                    "capabilities" -> <|
                        "extensions" -> <|
                            "io.modelcontextprotocol/ui" -> <|
                                "mimeTypes" -> { "text/html;profile=mcp-app" }
                            |>
                        |>
                    |>
                |>
            |>;
        Wolfram`AgentTools`Common`$clientSupportsUI
    ],
    False,
    SameTest -> Equal,
    TestID   -> "MCPAppsEnabled-Integration-DisablesUI@@Tests/MCPApps.wlt:201,1-225,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initResponse*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Extensions Included for UI Clients*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = True },
        result = Wolfram`AgentTools`Server`Shared`Private`initResponse[
            "TestServer", "1.0.0", { }, { }, <| |>
        ];
        ! MissingQ @ result[ "capabilities", "extensions", "io.modelcontextprotocol/ui" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InitResponse-IncludesExtensions@@Tests/MCPApps.wlt:234,1-244,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = True },
        result = Wolfram`AgentTools`Server`Shared`Private`initResponse[
            "TestServer", "1.0.0", { }, { }, <| |>
        ];
        result[ "capabilities", "extensions", "io.modelcontextprotocol/ui" ]
    ],
    <| "mimeTypes" -> { "text/html;profile=mcp-app" } |>,
    SameTest -> MatchQ,
    TestID   -> "InitResponse-ExtensionsStructure@@Tests/MCPApps.wlt:246,1-256,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = True },
        result = Wolfram`AgentTools`Server`Shared`Private`initResponse[
            "TestServer", "1.0.0", { }, { }, <| |>
        ];
        result[ "capabilities", "extensions", "io.modelcontextprotocol/ui", "mimeTypes" ]
    ],
    { "text/html;profile=mcp-app" },
    SameTest -> MatchQ,
    TestID   -> "InitResponse-ExtensionsMimeType@@Tests/MCPApps.wlt:258,1-268,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Extensions Omitted for Non-UI Clients*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = False },
        result = Wolfram`AgentTools`Server`Shared`Private`initResponse[
            "TestServer", "1.0.0", { }, { }, <| |>
        ];
        MissingQ @ result[ "capabilities", "extensions" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InitResponse-OmitsExtensionsWhenFalse@@Tests/MCPApps.wlt:273,1-283,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI },
        result = Wolfram`AgentTools`Server`Shared`Private`initResponse[
            "TestServer", "1.0.0", { }, { }, <| |>
        ];
        MissingQ @ result[ "capabilities", "extensions" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InitResponse-OmitsExtensionsWhenUnset@@Tests/MCPApps.wlt:285,1-295,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Standard Response Fields*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = True },
        result = Wolfram`AgentTools`Server`Shared`Private`initResponse[
            "TestServer", "1.0.0", { }, { }, <| |>
        ];
        { KeyExistsQ[ result, "protocolVersion" ], KeyExistsQ[ result, "capabilities" ], KeyExistsQ[ result, "serverInfo" ] }
    ],
    { True, True, True },
    SameTest -> Equal,
    TestID   -> "InitResponse-StandardFieldsPresent@@Tests/MCPApps.wlt:300,1-310,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = False },
        result = Wolfram`AgentTools`Server`Shared`Private`initResponse[
            "TestServer", "1.0.0", { }, { }, <| |>
        ];
        result[ "serverInfo" ]
    ],
    <| "name" -> "TestServer", "version" -> "1.0.0" |>,
    SameTest -> MatchQ,
    TestID   -> "InitResponse-ServerInfo@@Tests/MCPApps.wlt:312,1-322,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Backward Compatibility*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = False },
        result = Wolfram`AgentTools`Server`Shared`Private`initResponse[
            "TestServer", "1.0.0", { }, { }
        ];
        AssociationQ @ result && KeyExistsQ[ result, "protocolVersion" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InitResponse-BackwardCompat4Arg@@Tests/MCPApps.wlt:327,1-337,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadUIResource*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*HTML File Without JSON Metadata*)
VerificationTest[
    Module[ { dir, htmlFile, result },
        dir = CreateDirectory[ ];
        htmlFile = FileNameJoin[ { dir, "test-app.html" } ];
        WriteString[ htmlFile, "<!DOCTYPE html><html><body>Test</body></html>" ];
        Close @ htmlFile;
        result = Wolfram`AgentTools`Common`loadUIResource @ htmlFile;
        DeleteDirectory[ dir, DeleteContents -> True ];
        result
    ],
    "ui://wolfram/test-app" -> KeyValuePattern[ {
        "uri"      -> "ui://wolfram/test-app",
        "name"     -> "test-app",
        "mimeType" -> "text/html;profile=mcp-app",
        "html"     -> "<!DOCTYPE html><html><body>Test</body></html>",
        "meta"     -> _Association
    } ],
    SameTest -> MatchQ,
    TestID   -> "LoadUIResource-HTMLOnly@@Tests/MCPApps.wlt:346,1-365,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*HTML File With JSON Metadata*)
VerificationTest[
    Module[ { dir, htmlFile, jsonFile, result },
        dir = CreateDirectory[ ];
        htmlFile = FileNameJoin[ { dir, "test-app.html" } ];
        jsonFile = FileNameJoin[ { dir, "test-app.json" } ];
        WriteString[ htmlFile, "<html><body>Hello</body></html>" ];
        Close @ htmlFile;
        WriteString[ jsonFile, "{\"ui\":{\"prefersBorder\":true,\"csp\":{\"connectDomains\":[]}}}" ];
        Close @ jsonFile;
        result = Wolfram`AgentTools`Common`loadUIResource @ htmlFile;
        DeleteDirectory[ dir, DeleteContents -> True ];
        result
    ],
    "ui://wolfram/test-app" -> KeyValuePattern[ {
        "uri"      -> "ui://wolfram/test-app",
        "name"     -> "test-app",
        "mimeType" -> "text/html;profile=mcp-app",
        "html"     -> "<html><body>Hello</body></html>",
        "meta"     -> KeyValuePattern[ "ui" -> _Association ]
    } ],
    SameTest -> MatchQ,
    TestID   -> "LoadUIResource-WithJSON@@Tests/MCPApps.wlt:370,1-392,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*URI Derivation From File Name*)
VerificationTest[
    Module[ { dir, htmlFile, result },
        dir = CreateDirectory[ ];
        htmlFile = FileNameJoin[ { dir, "wolframalpha-viewer.html" } ];
        WriteString[ htmlFile, "<html></html>" ];
        Close @ htmlFile;
        result = Wolfram`AgentTools`Common`loadUIResource @ htmlFile;
        DeleteDirectory[ dir, DeleteContents -> True ];
        First @ result
    ],
    "ui://wolfram/wolframalpha-viewer",
    SameTest -> Equal,
    TestID   -> "LoadUIResource-URIFromFileName@@Tests/MCPApps.wlt:397,1-410,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Meta Is Empty Association When No JSON*)
VerificationTest[
    Module[ { dir, htmlFile, result },
        dir = CreateDirectory[ ];
        htmlFile = FileNameJoin[ { dir, "no-meta.html" } ];
        WriteString[ htmlFile, "<html></html>" ];
        Close @ htmlFile;
        result = Wolfram`AgentTools`Common`loadUIResource @ htmlFile;
        DeleteDirectory[ dir, DeleteContents -> True ];
        Last[ result ][ "meta" ]
    ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "LoadUIResource-EmptyMeta@@Tests/MCPApps.wlt:415,1-428,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initializeUIResources*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Loads From Paclet Assets*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        AssociationQ @ Wolfram`AgentTools`Common`$uiResourceRegistry
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InitializeUIResources-ReturnsAssociation@@Tests/MCPApps.wlt:437,1-445,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Sort @ Keys @ Wolfram`AgentTools`Common`$uiResourceRegistry
    ],
    { "ui://wolfram/evaluator-viewer", "ui://wolfram/mcp-apps-test", "ui://wolfram/notebook-viewer", "ui://wolfram/wolframalpha-viewer" },
    SameTest -> Equal,
    TestID   -> "InitializeUIResources-LoadsAllApps@@Tests/MCPApps.wlt:447,1-455,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        StringQ @ Wolfram`AgentTools`Common`$uiResourceRegistry[ "ui://wolfram/wolframalpha-viewer", "html" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "InitializeUIResources-HTMLIsString@@Tests/MCPApps.wlt:457,1-465,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`$uiResourceRegistry[ "ui://wolfram/wolframalpha-viewer", "mimeType" ]
    ],
    "text/html;profile=mcp-app",
    SameTest -> Equal,
    TestID   -> "InitializeUIResources-MimeType@@Tests/MCPApps.wlt:467,1-475,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*JSON Metadata Loaded*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`$uiResourceRegistry[ "ui://wolfram/evaluator-viewer", "meta" ]
    ],
    KeyValuePattern[ "ui" -> KeyValuePattern[ "csp" -> _Association ] ],
    SameTest -> MatchQ,
    TestID   -> "InitializeUIResources-MetadataLoaded@@Tests/MCPApps.wlt:480,1-488,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`$uiResourceRegistry[
            "ui://wolfram/evaluator-viewer", "meta", "ui", "csp", "frameDomains"
        ]
    ],
    { "https://www.wolframcloud.com", "https://wolfr.am" },
    SameTest -> Equal,
    TestID   -> "InitializeUIResources-EvaluatorFrameDomains@@Tests/MCPApps.wlt:490,1-500,2"
]

(* connect-src must allow data: URIs so the notebook embedder can instantiate
   its inline (data: URI) WebAssembly module (WXFWeb). *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`$uiResourceRegistry[
            "ui://wolfram/evaluator-viewer", "meta", "ui", "csp", "connectDomains"
        ]
    ],
    { "https://www.wolframcloud.com", "data:" },
    SameTest -> Equal,
    TestID   -> "InitializeUIResources-EvaluatorConnectDomains@@Tests/MCPApps.wlt:504,1-514,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Graceful Fallback*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        (* Use Block to temporarily override the paclet lookup to simulate missing assets *)
        Block[ { PacletObject },
            PacletObject[ "Wolfram/AgentTools" ][ "AssetLocation", "Apps" ] := $Failed;
            Wolfram`AgentTools`Common`initializeUIResources[ ]
        ];
        Wolfram`AgentTools`Common`$uiResourceRegistry
    ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "InitializeUIResources-GracefulFallback@@Tests/MCPApps.wlt:519,1-531,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*listUIResources*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Returns Resources When UI Supported*)
VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`listUIResources[ ]
    ],
    { KeyValuePattern[ { "uri" -> _String, "name" -> _String, "mimeType" -> _String } ].. },
    SameTest -> MatchQ,
    TestID   -> "ListUIResources-ReturnsWhenUISupported@@Tests/MCPApps.wlt:540,1-551,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Length @ Wolfram`AgentTools`Common`listUIResources[ ]
    ],
    4,
    SameTest -> Equal,
    TestID   -> "ListUIResources-ReturnsFourResources@@Tests/MCPApps.wlt:553,1-564,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Returns Empty When UI Not Supported*)
VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = False,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`listUIResources[ ]
    ],
    { },
    SameTest -> Equal,
    TestID   -> "ListUIResources-EmptyWhenNoUI@@Tests/MCPApps.wlt:569,1-580,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`listUIResources[ ]
    ],
    { },
    SameTest -> Equal,
    TestID   -> "ListUIResources-EmptyWhenUnset@@Tests/MCPApps.wlt:582,1-593,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Resource Structure*)
VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Sort @ Map[ #[ "uri" ] &, Wolfram`AgentTools`Common`listUIResources[ ] ]
    ],
    { "ui://wolfram/evaluator-viewer", "ui://wolfram/mcp-apps-test", "ui://wolfram/notebook-viewer", "ui://wolfram/wolframalpha-viewer" },
    SameTest -> Equal,
    TestID   -> "ListUIResources-CorrectURIs@@Tests/MCPApps.wlt:598,1-609,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readUIResource*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Valid URI Returns Content*)
VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`readUIResource[
            <| "params" -> <| "uri" -> "ui://wolfram/wolframalpha-viewer" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ]
    ],
    KeyValuePattern[ "contents" -> { KeyValuePattern[ {
        "uri"      -> "ui://wolfram/wolframalpha-viewer",
        "mimeType" -> "text/html;profile=mcp-app",
        "text"     -> _String,
        "_meta"    -> _Association
    } ] } ],
    SameTest -> MatchQ,
    TestID   -> "ReadUIResource-ValidURI@@Tests/MCPApps.wlt:618,1-637,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        result = Wolfram`AgentTools`Common`readUIResource[
            <| "params" -> <| "uri" -> "ui://wolfram/evaluator-viewer" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 2 |>
        ];
        result[[ "contents", 1, "text" ]]
    ],
    _String? (StringContainsQ[ "<!DOCTYPE html>" | "<html" ]),
    SameTest -> MatchQ,
    TestID   -> "ReadUIResource-HTMLContent@@Tests/MCPApps.wlt:639,1-654,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Unknown URI Returns Failure*)
VerificationTest[
    Quiet @ Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`readUIResource[
            <| "params" -> <| "uri" -> "ui://wolfram/nonexistent" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 3 |>
        ]
    ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "ReadUIResource-UnknownURI@@Tests/MCPApps.wlt:659,1-673,2"
]

VerificationTest[
    Quiet @ Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`readUIResource[
            <| "params" -> <| "uri" -> 123 |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 4 |>
        ]
    ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "ReadUIResource-InvalidURIType@@Tests/MCPApps.wlt:675,1-689,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*handleResourceRead*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Valid URI Returns Result*)
VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Server`Shared`Private`handleResourceRead[
            <| "params" -> <| "uri" -> "ui://wolfram/wolframalpha-viewer" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ]
    ],
    KeyValuePattern[ {
        "jsonrpc" -> "2.0",
        "id"      -> 1,
        "result"  -> KeyValuePattern[ "contents" -> { _Association.. } ]
    } ],
    SameTest -> MatchQ,
    TestID   -> "HandleResourceRead-ValidURI@@Tests/MCPApps.wlt:698,1-716,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Unknown URI Returns Error With Code -32602*)
VerificationTest[
    Quiet @ Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Server`Shared`Private`handleResourceRead[
            <| "params" -> <| "uri" -> "ui://wolfram/nonexistent" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 2 |>
        ]
    ],
    KeyValuePattern[ {
        "jsonrpc" -> "2.0",
        "id"      -> 2,
        "error"   -> KeyValuePattern[ {
            "code"    -> -32602,
            "message" -> _String? (StringContainsQ[ "ui://wolfram/nonexistent" ])
        } ]
    } ],
    SameTest -> MatchQ,
    TestID   -> "HandleResourceRead-UnknownURIError@@Tests/MCPApps.wlt:721,1-742,2"
]

VerificationTest[
    Quiet @ Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        response = Wolfram`AgentTools`Server`Shared`Private`handleResourceRead[
            <| "params" -> <| "uri" -> "ui://wolfram/nonexistent" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 5 |>
        ];
        response[ "error", "code" ]
    ],
    -32602,
    SameTest -> Equal,
    TestID   -> "HandleResourceRead-ErrorCodeIs32602@@Tests/MCPApps.wlt:744,1-759,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Invalid Params Returns Internal Error -32603*)
VerificationTest[
    Quiet @ Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        response = Wolfram`AgentTools`Server`Shared`Private`handleResourceRead[
            <| "params" -> <| "uri" -> 999 |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 6 |>
        ];
        { KeyExistsQ[ response, "error" ], response[ "error", "code" ] }
    ],
    { True, -32603 },
    SameTest -> MatchQ,
    TestID   -> "HandleResourceRead-InvalidParamsReturnsInternalError@@Tests/MCPApps.wlt:764,1-779,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Missing Params Returns Internal Error -32603*)
VerificationTest[
    Quiet @ Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        response = Wolfram`AgentTools`Server`Shared`Private`handleResourceRead[
            <| "params" -> <| |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 7 |>
        ];
        response[ "error", "code" ]
    ],
    -32603,
    SameTest -> Equal,
    TestID   -> "HandleResourceRead-MissingParamsReturnsInternalError@@Tests/MCPApps.wlt:784,1-799,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*handleMethod - resources/list Integration*)

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`handleMethod[
            "resources/list",
            <| "method" -> "resources/list", "params" -> <| |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ]
    ],
    KeyValuePattern[ {
        "result" -> KeyValuePattern[ "resources" -> { __Association } ]
    } ],
    SameTest -> MatchQ,
    TestID   -> "HandleMethod-ResourcesList-UIClient@@Tests/MCPApps.wlt:805,1-822,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = False,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`handleMethod[
            "resources/list",
            <| "method" -> "resources/list", "params" -> <| |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ]
    ],
    KeyValuePattern[ {
        "result" -> KeyValuePattern[ "resources" -> { } ]
    } ],
    SameTest -> MatchQ,
    TestID   -> "HandleMethod-ResourcesList-NonUIClient@@Tests/MCPApps.wlt:824,1-841,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*handleMethod - resources/read Integration*)

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`handleMethod[
            "resources/read",
            <| "method" -> "resources/read", "params" -> <| "uri" -> "ui://wolfram/wolframalpha-viewer" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 2 |>
        ]
    ],
    KeyValuePattern[ {
        "result" -> KeyValuePattern[ "contents" -> { KeyValuePattern[ {
            "uri"      -> "ui://wolfram/wolframalpha-viewer",
            "mimeType" -> "text/html;profile=mcp-app",
            "text"     -> _String
        } ] } ]
    } ],
    SameTest -> MatchQ,
    TestID   -> "HandleMethod-ResourcesRead-ValidURI@@Tests/MCPApps.wlt:847,1-868,2"
]

VerificationTest[
    Quiet @ Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`Common`handleMethod[
            "resources/read",
            <| "method" -> "resources/read", "params" -> <| "uri" -> "ui://wolfram/unknown" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 3 |>
        ]
    ],
    KeyValuePattern[ {
        "error" -> KeyValuePattern[ {
            "code"    -> -32602,
            "message" -> _String? (StringContainsQ[ "ui://wolfram/unknown" ])
        } ]
    } ],
    SameTest -> MatchQ,
    TestID   -> "HandleMethod-ResourcesRead-UnknownURI@@Tests/MCPApps.wlt:870,1-890,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolUIMetadata*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Returns _meta for Known Tool When UI Supported*)
VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI    = True,
        Wolfram`AgentTools`Common`$deployCloudNotebooks = True
    },
        Wolfram`AgentTools`Common`toolUIMetadata[ "WolframAlpha" ]
    ],
    { "_meta" -> _Association },
    SameTest -> MatchQ,
    TestID   -> "ToolUIMetadata-KnownToolWithUI@@Tests/MCPApps.wlt:899,1-909,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI    = True,
        Wolfram`AgentTools`Common`$deployCloudNotebooks = True
    },
        meta = Wolfram`AgentTools`Common`toolUIMetadata[ "WolframAlpha" ];
        ("_meta" /. meta)[ "ui", "resourceUri" ]
    ],
    "ui://wolfram/wolframalpha-viewer",
    SameTest -> Equal,
    TestID   -> "ToolUIMetadata-CorrectResourceURI@@Tests/MCPApps.wlt:911,1-922,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI    = True,
        Wolfram`AgentTools`Common`$deployCloudNotebooks = True
    },
        meta = Wolfram`AgentTools`Common`toolUIMetadata[ "WolframAlpha" ];
        ("_meta" /. meta)[ "ui", "visibility" ]
    ],
    { "model", "app" },
    SameTest -> Equal,
    TestID   -> "ToolUIMetadata-CorrectVisibility@@Tests/MCPApps.wlt:924,1-935,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*WolframAlpha _meta Conditional On $deployCloudNotebooks*)
VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI    = True,
        Wolfram`AgentTools`Common`$deployCloudNotebooks = False
    },
        Wolfram`AgentTools`Common`toolUIMetadata[ "WolframAlpha" ]
    ],
    { },
    SameTest -> Equal,
    TestID   -> "ToolUIMetadata-WolframAlphaNoDeploy@@Tests/MCPApps.wlt:940,1-950,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = True },
        Wolfram`AgentTools`Common`toolUIMetadata[ "WolframLanguageEvaluator" ]
    ],
    { "_meta" -> KeyValuePattern[ "ui" -> KeyValuePattern[ "resourceUri" -> "ui://wolfram/evaluator-viewer" ] ] },
    SameTest -> MatchQ,
    TestID   -> "ToolUIMetadata-EvaluatorTool@@Tests/MCPApps.wlt:952,1-959,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Returns Empty for Unknown or Unsupported Tools*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = True },
        Wolfram`AgentTools`Common`toolUIMetadata[ "UnknownTool" ]
    ],
    { },
    SameTest -> Equal,
    TestID   -> "ToolUIMetadata-UnknownTool@@Tests/MCPApps.wlt:964,1-971,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = False },
        Wolfram`AgentTools`Common`toolUIMetadata[ "WolframAlpha" ]
    ],
    { },
    SameTest -> Equal,
    TestID   -> "ToolUIMetadata-KnownToolNoUI@@Tests/MCPApps.wlt:973,1-980,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI },
        Wolfram`AgentTools`Common`toolUIMetadata[ "WolframAlpha" ]
    ],
    { },
    SameTest -> Equal,
    TestID   -> "ToolUIMetadata-KnownToolUIUnset@@Tests/MCPApps.wlt:982,1-989,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withToolUIMetadata*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Adds _meta When UI Supported*)
VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI    = True,
        Wolfram`AgentTools`Common`$deployCloudNotebooks = True
    },
        tools = {
            <| "name" -> "WolframAlpha", "description" -> "test", "inputSchema" -> <| |> |>,
            <| "name" -> "OtherTool",    "description" -> "test", "inputSchema" -> <| |> |>
        };
        result = Wolfram`AgentTools`Common`withToolUIMetadata @ tools;
        KeyExistsQ[ result[[ 1 ]], "_meta" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "WithToolUIMetadata-AddsMetaToKnownTool@@Tests/MCPApps.wlt:998,1-1013,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI    = True,
        Wolfram`AgentTools`Common`$deployCloudNotebooks = True
    },
        tools = {
            <| "name" -> "WolframAlpha", "description" -> "test", "inputSchema" -> <| |> |>,
            <| "name" -> "OtherTool",    "description" -> "test", "inputSchema" -> <| |> |>
        };
        result = Wolfram`AgentTools`Common`withToolUIMetadata @ tools;
        KeyExistsQ[ result[[ 2 ]], "_meta" ]
    ],
    False,
    SameTest -> Equal,
    TestID   -> "WithToolUIMetadata-NoMetaForUnknownTool@@Tests/MCPApps.wlt:1015,1-1030,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI    = True,
        Wolfram`AgentTools`Common`$deployCloudNotebooks = True
    },
        tools = {
            <| "name" -> "WolframAlpha", "description" -> "test", "inputSchema" -> <| |> |>
        };
        result = Wolfram`AgentTools`Common`withToolUIMetadata @ tools;
        result[[ 1, "_meta", "ui", "resourceUri" ]]
    ],
    "ui://wolfram/wolframalpha-viewer",
    SameTest -> Equal,
    TestID   -> "WithToolUIMetadata-CorrectMetaContent@@Tests/MCPApps.wlt:1032,1-1046,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*No Changes When UI Not Supported*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = False },
        tools = {
            <| "name" -> "WolframAlpha", "description" -> "test", "inputSchema" -> <| |> |>
        };
        Wolfram`AgentTools`Common`withToolUIMetadata @ tools
    ],
    { <| "name" -> "WolframAlpha", "description" -> "test", "inputSchema" -> <| |> |> },
    SameTest -> Equal,
    TestID   -> "WithToolUIMetadata-NoChangesWhenNoUI@@Tests/MCPApps.wlt:1051,1-1061,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Preserves Existing Fields*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = True },
        tools = {
            <| "name" -> "WolframAlpha", "description" -> "WA tool", "inputSchema" -> <| "type" -> "object" |> |>
        };
        result = Wolfram`AgentTools`Common`withToolUIMetadata @ tools;
        { result[[ 1, "name" ]], result[[ 1, "description" ]], result[[ 1, "inputSchema" ]] }
    ],
    { "WolframAlpha", "WA tool", <| "type" -> "object" |> },
    SameTest -> Equal,
    TestID   -> "WithToolUIMetadata-PreservesExistingFields@@Tests/MCPApps.wlt:1066,1-1077,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*handleMethod - tools/list Integration*)

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI    = True,
        Wolfram`AgentTools`Common`$deployCloudNotebooks = True,
        Wolfram`AgentTools`Server`$toolList = {
            <| "name" -> "WolframAlpha", "description" -> "test", "inputSchema" -> <| |> |>,
            <| "name" -> "OtherTool",    "description" -> "test", "inputSchema" -> <| |> |>
        }
    },
        result = Wolfram`AgentTools`Common`handleMethod[
            "tools/list",
            <| "method" -> "tools/list", "params" -> <| |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ];
        waTool = SelectFirst[ result[ "result", "tools" ], #[ "name" ] === "WolframAlpha" & ];
        KeyExistsQ[ waTool, "_meta" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "HandleMethod-ToolsList-UIMetaPresent@@Tests/MCPApps.wlt:1083,1-1103,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI    = True,
        Wolfram`AgentTools`Common`$deployCloudNotebooks = True,
        Wolfram`AgentTools`Server`$toolList = {
            <| "name" -> "WolframAlpha", "description" -> "test", "inputSchema" -> <| |> |>,
            <| "name" -> "OtherTool",    "description" -> "test", "inputSchema" -> <| |> |>
        }
    },
        result = Wolfram`AgentTools`Common`handleMethod[
            "tools/list",
            <| "method" -> "tools/list", "params" -> <| |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ];
        otherTool = SelectFirst[ result[ "result", "tools" ], #[ "name" ] === "OtherTool" & ];
        KeyExistsQ[ otherTool, "_meta" ]
    ],
    False,
    SameTest -> Equal,
    TestID   -> "HandleMethod-ToolsList-NoMetaForUnlinkedTool@@Tests/MCPApps.wlt:1105,1-1125,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = False,
        Wolfram`AgentTools`Server`$toolList = {
            <| "name" -> "WolframAlpha", "description" -> "test", "inputSchema" -> <| |> |>
        }
    },
        result = Wolfram`AgentTools`Common`handleMethod[
            "tools/list",
            <| "method" -> "tools/list", "params" -> <| |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ];
        waTool = First @ result[ "result", "tools" ];
        KeyExistsQ[ waTool, "_meta" ]
    ],
    False,
    SameTest -> Equal,
    TestID   -> "HandleMethod-ToolsList-NoMetaWhenNoUI@@Tests/MCPApps.wlt:1127,1-1145,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$deployCloudNotebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Is a Boolean*)
VerificationTest[
    BooleanQ @ Wolfram`AgentTools`Common`$deployCloudNotebooks,
    True,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebooks-Boolean@@Tests/MCPApps.wlt:1154,1-1159,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Blocking Overrides Cached Value*)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$deployCloudNotebooks = True },
        Wolfram`AgentTools`Common`$deployCloudNotebooks
    ],
    True,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebooks-BlockTrue@@Tests/MCPApps.wlt:1164,1-1171,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$deployCloudNotebooks = False },
        Wolfram`AgentTools`Common`$deployCloudNotebooks
    ],
    False,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebooks-BlockFalse@@Tests/MCPApps.wlt:1173,1-1180,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deployCloudNotebookForMCPApp*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Asserts Deploy Enabled*)
VerificationTest[
    Quiet @ Block[ { Wolfram`AgentTools`Common`$deployCloudNotebooks = False },
        Wolfram`AgentTools`Common`deployCloudNotebookForMCPApp[
            Notebook @ { Cell[ "test", "Input" ] },
            "some-id"
        ]
    ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "DeployCloudNotebookForMCPApp-AssertsDeployEnabled@@Tests/MCPApps.wlt:1189,1-1199,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Invalid Arguments*)
VerificationTest[
    Quiet @ Wolfram`AgentTools`Common`deployCloudNotebookForMCPApp[ "not a notebook", "id" ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "DeployCloudNotebookForMCPApp-NotANotebook@@Tests/MCPApps.wlt:1204,1-1209,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Inline Method Returns Serialized Notebook String*)
VerificationTest[
    Block[ {
        Wolfram`AgentTools`UIResources`Private`$mcpAppsNotebookMethod = "Inline",
        Wolfram`AgentTools`Common`$deployCloudNotebooks = True
    },
        StringQ @ Wolfram`AgentTools`Common`deployCloudNotebookForMCPApp[
            Notebook @ { Cell[ "1 + 1", "Input" ] },
            "some-id"
        ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebookForMCPApp-InlineReturnsString@@Tests/MCPApps.wlt:1214,1-1227,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`UIResources`Private`$mcpAppsNotebookMethod = "Inline",
        Wolfram`AgentTools`Common`$deployCloudNotebooks = True
    },
        ImportString[
            Wolfram`AgentTools`Common`deployCloudNotebookForMCPApp[
                Notebook @ { Cell[ "1 + 1", "Input" ] },
                "some-id"
            ],
            "NB"
        ]
    ],
    _Notebook,
    SameTest -> MatchQ,
    TestID   -> "DeployCloudNotebookForMCPApp-InlineRoundTrips@@Tests/MCPApps.wlt:1229,1-1245,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Inline Method Still Asserts Deploy Enabled*)
VerificationTest[
    Quiet @ Block[ {
        Wolfram`AgentTools`UIResources`Private`$mcpAppsNotebookMethod = "Inline",
        Wolfram`AgentTools`Common`$deployCloudNotebooks = False
    },
        Wolfram`AgentTools`Common`deployCloudNotebookForMCPApp[
            Notebook @ { Cell[ "test", "Input" ] },
            "some-id"
        ]
    ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "DeployCloudNotebookForMCPApp-InlineAssertsDeployEnabled@@Tests/MCPApps.wlt:1250,1-1263,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Delivery Methods*)
(* The notebook is deployed with CloudDeploy when connected to the cloud, and uploaded to the public notebook
   hosting API otherwise or if CloudDeploy fails. Both round trips are replaced by mocks here: cloudDeployNotebook
   (or, one level down, cloudDeployTryAppearanceElements) stands in for CloudDeploy, and notebookUploadResponse
   for the HTTP request to the hosting API. *)
$deliveryTestNotebook = Notebook @ { Cell[ "1 + 1", "Input" ] };
$deliveryTestUUID     = "7df88e25-37dc-4a7e-915d-4df1848a40e1";
$deliveryTestURL      = "https://www.wolframcloud.com/obj/" <> $deliveryTestUUID;
$cloudDeployTestURL   = "https://www.wolframcloud.com/obj/4a3711c2-43a3-4039-9423-f0cf055617a8";

(* A canned answer of the hosting API *)
hostingAPIResponse[ json_Association, code_Integer ] := HTTPResponse[
    Developer`WriteRawJSONString @ json,
    <| "StatusCode" -> code, "ContentType" -> "application/json" |>
];

$hostingAPISuccess = hostingAPIResponse[
    <| "success" -> True, "code" -> 200, "uuid" -> "3dd142c8-cf4e-43fb-8b48-e22d742e3884", "result" -> $deliveryTestURL |>,
    200
];

(* Runs deployCloudNotebookForMCPApp with mocked delivery methods (cloudDeployNotebook returns cloudDeployResult;
   the hosting API answers with uploadResponse) and returns the result together with how many times each delivery
   method was invoked and the state of $deployCloudNotebooks afterward. The session flags default to a
   not-connected session with delivery enabled; individual tests override them through the options. *)
Options[ deliveryTest ] = {
    "CloudConnected"       -> False,
    "DeployCloudNotebooks" -> True,
    "UseCloudDeploy"       -> True,
    "SizeLimit"            -> Automatic
};

deliveryTest[ cloudDeployResult_, uploadResponse_, opts: OptionsPattern[ ] ] :=
    Module[ { settings, sizeLimit, deploys = 0, uploads = 0, result },
        settings  = Association @ { opts };
        sizeLimit = Replace[
            Lookup[ settings, "SizeLimit", Automatic ],
            Automatic :> Wolfram`AgentTools`UIResources`Private`$notebookUploadSizeLimit
        ];
        Block[
            {
                $CloudConnected = Lookup[ settings, "CloudConnected", False ],
                Wolfram`AgentTools`Common`$deployCloudNotebooks         = Lookup[ settings, "DeployCloudNotebooks", True ],
                Wolfram`AgentTools`UIResources`Private`$useCloudDeploy   = Lookup[ settings, "UseCloudDeploy", True ],
                Wolfram`AgentTools`UIResources`Private`$notebookUploadSizeLimit = sizeLimit,
                Wolfram`AgentTools`UIResources`Private`cloudDeployNotebook    = Function[ deploys++; cloudDeployResult ],
                Wolfram`AgentTools`UIResources`Private`notebookUploadResponse = Function[ uploads++; uploadResponse ]
            },
            result = Wolfram`AgentTools`Common`deployCloudNotebookForMCPApp[ $deliveryTestNotebook, "some-id" ];
            <|
                "Result"               -> result,
                "CloudDeploys"         -> deploys,
                "Uploads"              -> uploads,
                "DeployCloudNotebooks" -> Wolfram`AgentTools`Common`$deployCloudNotebooks
            |>
        ]
    ];

(* Not cloud connected: the hosting API is used *)
VerificationTest[
    deliveryTest[ $Failed, $hostingAPISuccess, "CloudConnected" -> False ],
    <| "Result" -> $deliveryTestURL, "CloudDeploys" -> 1, "Uploads" -> 1, "DeployCloudNotebooks" -> True |>,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebookForMCPApp-NotConnected-UsesHostingAPI@@Tests/MCPApps.wlt:1326,1-1331,2"
]

(* CloudDeploy succeeded: its URL is used and nothing is uploaded *)
VerificationTest[
    deliveryTest[ $cloudDeployTestURL, $hostingAPISuccess ],
    <| "Result" -> $cloudDeployTestURL, "CloudDeploys" -> 1, "Uploads" -> 0, "DeployCloudNotebooks" -> True |>,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebookForMCPApp-CloudDeploy-NoUpload@@Tests/MCPApps.wlt:1334,1-1339,2"
]

(* CloudDeploy failed: the hosting API is the fallback and delivery stays enabled *)
VerificationTest[
    deliveryTest[ $Failed, $hostingAPISuccess, "CloudConnected" -> True ],
    <| "Result" -> $deliveryTestURL, "CloudDeploys" -> 1, "Uploads" -> 1, "DeployCloudNotebooks" -> True |>,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebookForMCPApp-CloudDeployFailed-UsesHostingAPI@@Tests/MCPApps.wlt:1342,1-1347,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Hosting API Failures*)

(* The request itself failed (no network, timeout): delivery is disabled for the rest of the session *)
VerificationTest[
    deliveryTest[ $Failed, Failure[ "ConnectionFailure", <| "MessageTemplate" -> "Unable to perform the request." |> ] ],
    <| "Result" -> $Failed, "CloudDeploys" -> 1, "Uploads" -> 1, "DeployCloudNotebooks" -> False |>,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebookForMCPApp-HostingAPI-ConnectionFailure-Disables@@Tests/MCPApps.wlt:1354,1-1359,2"
]

(* An endpoint that is not deployed redirects to a login page (no JSON): delivery is disabled *)
VerificationTest[
    deliveryTest[ $Failed, HTTPResponse[ "", <| "StatusCode" -> 302, "ContentType" -> "text/plain" |> ] ],
    <| "Result" -> $Failed, "CloudDeploys" -> 1, "Uploads" -> 1, "DeployCloudNotebooks" -> False |>,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebookForMCPApp-HostingAPI-Redirect-Disables@@Tests/MCPApps.wlt:1362,1-1367,2"
]

(* A server error: delivery is disabled *)
VerificationTest[
    deliveryTest[
        $Failed,
        hostingAPIResponse[ <| "success" -> False, "code" -> 500, "tag" -> "InternalError", "result" -> Null |>, 500 ]
    ],
    <| "Result" -> $Failed, "CloudDeploys" -> 1, "Uploads" -> 1, "DeployCloudNotebooks" -> False |>,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebookForMCPApp-HostingAPI-ServerError-Disables@@Tests/MCPApps.wlt:1370,1-1378,2"
]

(* A successful answer without a result URL is not usable either *)
VerificationTest[
    deliveryTest[
        $Failed,
        hostingAPIResponse[ <| "success" -> True, "code" -> 200, "result" -> Null |>, 200 ]
    ],
    <| "Result" -> $Failed, "CloudDeploys" -> 1, "Uploads" -> 1, "DeployCloudNotebooks" -> False |>,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebookForMCPApp-HostingAPI-NoResultURL-Disables@@Tests/MCPApps.wlt:1381,1-1389,2"
]

(* A client error concerns only this notebook: delivery stays enabled for later notebooks *)
VerificationTest[
    deliveryTest[
        $Failed,
        hostingAPIResponse[
            <|
                "success" -> False,
                "code"    -> 400,
                "tag"     -> "NotebookTooLarge",
                "message" -> "The specified notebook exceeds the maximum allowed size.",
                "result"  -> Null
            |>,
            400
        ]
    ],
    <| "Result" -> $Failed, "CloudDeploys" -> 1, "Uploads" -> 1, "DeployCloudNotebooks" -> True |>,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebookForMCPApp-HostingAPI-ClientError-StaysEnabled@@Tests/MCPApps.wlt:1392,1-1409,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Oversized Notebooks Are Not Uploaded*)
VerificationTest[
    deliveryTest[ $Failed, $hostingAPISuccess, "SizeLimit" -> 100 ],
    <| "Result" -> $Failed, "CloudDeploys" -> 1, "Uploads" -> 0, "DeployCloudNotebooks" -> True |>,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebookForMCPApp-HostingAPI-TooLarge-NotUploaded@@Tests/MCPApps.wlt:1414,1-1419,2"
]

(* The size limit is the API's 10 MB *)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`$notebookUploadSizeLimit,
    10^7,
    SameTest -> Equal,
    TestID   -> "NotebookUploadSizeLimit-10MB@@Tests/MCPApps.wlt:1422,1-1427,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Temporary Notebook File*)
(* The notebook is uploaded from a temporary .nb file that exists only for the duration of the request and round
   trips back to the original notebook (up to the front end's added metadata). *)
VerificationTest[
    Module[ { file, existed, notebook },
        Block[
            {
                $CloudConnected = False,
                Wolfram`AgentTools`Common`$deployCloudNotebooks = True,
                Wolfram`AgentTools`UIResources`Private`notebookUploadResponse = Function[
                    file     = #;
                    existed  = FileExistsQ @ #;
                    notebook = Import[ #, "NB" ];
                    $hostingAPISuccess
                ]
            },
            Wolfram`AgentTools`Common`deployCloudNotebookForMCPApp[ $deliveryTestNotebook, "some-id" ]
        ];
        {
            existed,
            FileExtension @ file,
            MatchQ[ notebook, _Notebook ],
            ! FreeQ[ notebook, Cell[ "1 + 1", "Input", ___ ] ],
            FileExistsQ @ file
        }
    ],
    { True, "nb", True, True, False },
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebookForMCPApp-HostingAPI-TemporaryFile@@Tests/MCPApps.wlt:1434,1-1460,2"
]

(* The temporary file is removed even when the upload fails *)
VerificationTest[
    Module[ { file },
        Block[
            {
                $CloudConnected = False,
                Wolfram`AgentTools`Common`$deployCloudNotebooks = True,
                Wolfram`AgentTools`UIResources`Private`notebookUploadResponse = Function[
                    file = #;
                    Failure[ "ConnectionFailure", <| "MessageTemplate" -> "Unable to perform the request." |> ]
                ]
            },
            Wolfram`AgentTools`Common`deployCloudNotebookForMCPApp[ $deliveryTestNotebook, "some-id" ]
        ];
        { StringQ @ file, FileExistsQ @ file }
    ],
    { True, False },
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebookForMCPApp-HostingAPI-TemporaryFileRemovedOnFailure@@Tests/MCPApps.wlt:1463,1-1481,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookUploadResult*)
(* A well-formed success answer yields the hosted URL and leaves delivery enabled *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$deployCloudNotebooks = True },
        {
            Wolfram`AgentTools`UIResources`Private`notebookUploadResult @ $hostingAPISuccess,
            Wolfram`AgentTools`Common`$deployCloudNotebooks
        }
    ],
    { $deliveryTestURL, True },
    SameTest -> Equal,
    TestID   -> "NotebookUploadResult-Success@@Tests/MCPApps.wlt:1487,1-1497,2"
]

(* A 4xx client error disables nothing *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$deployCloudNotebooks = True },
        {
            Wolfram`AgentTools`UIResources`Private`notebookUploadResult @ hostingAPIResponse[
                <| "success" -> False, "code" -> 400, "tag" -> "InvalidNotebookFormat", "result" -> Null |>,
                400
            ],
            Wolfram`AgentTools`Common`$deployCloudNotebooks
        }
    ],
    { $Failed, True },
    SameTest -> Equal,
    TestID   -> "NotebookUploadResult-ClientError-StaysEnabled@@Tests/MCPApps.wlt:1500,1-1513,2"
]

(* A non-HTTPResponse (a Failure from URLRead) disables delivery *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$deployCloudNotebooks = True },
        {
            Wolfram`AgentTools`UIResources`Private`notebookUploadResult @ Failure[ "ConnectionFailure", <| |> ],
            Wolfram`AgentTools`Common`$deployCloudNotebooks
        }
    ],
    { $Failed, False },
    SameTest -> Equal,
    TestID   -> "NotebookUploadResult-NonResponse-Disables@@Tests/MCPApps.wlt:1516,1-1526,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudDeployNotebook Gating*)
(* CloudDeploy is only tried when connected to the cloud and not after an earlier failure *)
VerificationTest[
    Module[ { deploys = 0, result },
        Block[
            {
                $CloudConnected = False,
                Wolfram`AgentTools`UIResources`Private`$useCloudDeploy = True,
                Wolfram`AgentTools`UIResources`Private`cloudDeployTryAppearanceElements = Function[ deploys++; $Failed ]
            },
            result = Wolfram`AgentTools`UIResources`Private`cloudDeployNotebook[ $deliveryTestNotebook, "some-id" ];
            { result, deploys, Wolfram`AgentTools`UIResources`Private`$useCloudDeploy }
        ]
    ],
    { $Failed, 0, True },
    SameTest -> Equal,
    TestID   -> "CloudDeployNotebook-NotConnected-NotTried@@Tests/MCPApps.wlt:1532,1-1547,2"
]

VerificationTest[
    Module[ { deploys = 0, result },
        Block[
            {
                $CloudConnected = True,
                Wolfram`AgentTools`UIResources`Private`$useCloudDeploy = False,
                Wolfram`AgentTools`UIResources`Private`cloudDeployTryAppearanceElements = Function[ deploys++; $Failed ]
            },
            result = Wolfram`AgentTools`UIResources`Private`cloudDeployNotebook[ $deliveryTestNotebook, "some-id" ];
            { result, deploys }
        ]
    ],
    { $Failed, 0 },
    SameTest -> Equal,
    TestID   -> "CloudDeployNotebook-AfterFailure-NotTried@@Tests/MCPApps.wlt:1549,1-1564,2"
]

(* Constructing the cloud target needs a real cloud session, so the deploying branch is exercised only when
   connected (with CloudDeploy itself mocked); skipped otherwise. *)
$cloudDeployNotebookTest = conditionalTest @ TrueQ @ $CloudConnected;

$cloudDeployNotebookTest @ VerificationTest[
    Module[ { targets = { }, result },
        Block[
            {
                Wolfram`AgentTools`UIResources`Private`$useCloudDeploy = True,
                Wolfram`AgentTools`UIResources`Private`cloudDeployTryAppearanceElements = Function[
                    AppendTo[ targets, #2 ];
                    CloudObject @ $cloudDeployTestURL
                ]
            },
            result = Wolfram`AgentTools`UIResources`Private`cloudDeployNotebook[ $deliveryTestNotebook, "some-id" ];
            {
                result,
                MatchQ[ targets, { CloudObject[ _String? (StringEndsQ[ "/AgentTools/Notebooks/" ~~ HexadecimalCharacter.. ~~ ".nb" ]), ___ ] } ],
                Wolfram`AgentTools`UIResources`Private`$useCloudDeploy
            }
        ]
    ],
    { $cloudDeployTestURL, True, True },
    SameTest -> Equal,
    TestID   -> "CloudDeployNotebook-Connected-DeploysToHashedTarget@@Tests/MCPApps.wlt:1570,28-1591,2"
]

(* A CloudDeploy failure rules CloudDeploy out for the rest of the session *)
$cloudDeployNotebookTest @ VerificationTest[
    Module[ { result },
        Block[
            {
                Wolfram`AgentTools`UIResources`Private`$useCloudDeploy = True,
                Wolfram`AgentTools`UIResources`Private`cloudDeployTryAppearanceElements = Function[ $Failed ]
            },
            result = Wolfram`AgentTools`UIResources`Private`cloudDeployNotebook[ $deliveryTestNotebook, "some-id" ];
            { result, Wolfram`AgentTools`UIResources`Private`$useCloudDeploy }
        ]
    ],
    { $Failed, False },
    SameTest -> Equal,
    TestID   -> "CloudDeployNotebook-Failure-ClearsUseCloudDeploy@@Tests/MCPApps.wlt:1594,28-1608,2"
]

(* A real deployment: the URL is in UUID form, as cloudNotebookUUID expects *)
$cloudDeployNotebookTest @ VerificationTest[
    Module[ { url },
        Block[
            {
                Wolfram`AgentTools`Common`$deployCloudNotebooks = True,
                Wolfram`AgentTools`UIResources`Private`$useCloudDeploy = True
            },
            url = Wolfram`AgentTools`Common`deployCloudNotebookForMCPApp[ $deliveryTestNotebook, "some-id" ];
            {
                StringQ @ url && StringStartsQ[ url, "https://www.wolframcloud.com/obj/" ],
                StringMatchQ[ Wolfram`AgentTools`UIResources`Private`cloudNotebookUUID @ url, Wolfram`AgentTools`UIResources`Private`$$notebookUUID ],
                Wolfram`AgentTools`UIResources`Private`$useCloudDeploy
            }
        ]
    ],
    { True, True, True },
    SameTest -> Equal,
    TestID   -> "CloudDeployNotebook-Connected-RealDeploy@@Tests/MCPApps.wlt:1611,28-1629,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Hosting API (network-gated)*)
(* A real upload to the hosting API. The API answers a notebook-less request with a JSON error, so anything else
   (the login redirect of an endpoint that is not deployed yet, or no network at all) means it is unavailable and
   the test is skipped. *)
notebookHostingAPIAvailableQ[ ] :=
    Module[ { response },
        response = Quiet @ URLRead[
            HTTPRequest[ Wolfram`AgentTools`UIResources`Private`$notebookUploadEndpoint, <| "Method" -> "POST" |> ],
            TimeConstraint -> 10
        ];
        MatchQ[ response, _HTTPResponse ] &&
            MatchQ[ Quiet @ Developer`ReadRawJSONString @ response[ "Body" ], KeyValuePattern[ "success" -> False ] ]
    ];

$notebookHostingAPITest = conditionalTest @ TrueQ @ notebookHostingAPIAvailableQ[ ];

$notebookHostingAPITest @ VerificationTest[
    Module[ { url },
        Block[
            {
                $CloudConnected = False,
                Wolfram`AgentTools`Common`$deployCloudNotebooks = True
            },
            url = Wolfram`AgentTools`Common`deployCloudNotebookForMCPApp[ $deliveryTestNotebook, "some-id" ];
            {
                StringQ @ url && StringStartsQ[ url, "https://www.wolframcloud.com/obj/" ],
                StringMatchQ[ Wolfram`AgentTools`UIResources`Private`cloudNotebookUUID @ url, Wolfram`AgentTools`UIResources`Private`$$notebookUUID ],
                Wolfram`AgentTools`Common`$deployCloudNotebooks
            }
        ]
    ],
    { True, True, True },
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebookForMCPApp-HostingAPI-RealUpload@@Tests/MCPApps.wlt:1649,27-1667,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeNotebookUIResult*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Cloud URL Wraps Result In Marker*)
VerificationTest[
    Module[ { uuid, url, result, content, joined },
        uuid    = "e0f29bea-667b-4780-b36b-59de225e660e";
        url     = "https://www.wolframcloud.com/obj/" <> uuid;
        result  = Wolfram`AgentTools`Common`makeNotebookUIResult[
            { <| "type" -> "text", "text" -> "1 + 1 = 2" |> },
            url
        ];
        content = result[ "Content" ];
        joined  = StringJoin[ #[ "text" ] & /@ content ];
        {
            (* The single text item is wrapped by an opening and a closing tag item *)
            Length @ content,
            StringContainsQ[ joined, "<result uuid=\"" <> uuid <> "\">" ],
            StringContainsQ[ joined, "</result>" ],
            (* The original result text is preserved between the tags *)
            StringContainsQ[ joined, "1 + 1 = 2" ],
            result[ "_meta", "notebookUrl" ],
            (* structuredContent must not be produced: some clients drop content when it is present *)
            KeyExistsQ[ result, "StructuredContent" ]
        }
    ],
    {
        3,
        True,
        True,
        True,
        "https://www.wolframcloud.com/obj/e0f29bea-667b-4780-b36b-59de225e660e?syntaxMethod=editor",
        False
    },
    SameTest -> MatchQ,
    TestID   -> "MakeNotebookUIResult-CloudURLWrapsResult@@Tests/MCPApps.wlt:1676,1-1708,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Marker UUID Is Recoverable*)
(* Mirrors the viewers' extraction: the uuid must sit inside <result uuid="..."> in the wrapped
   content so the client regex <result uuid="(...)"> can recover it and rebuild the cloud URL as
   https://www.wolframcloud.com/obj/<uuid>. *)
VerificationTest[
    Module[ { uuid, url, result, joined, recovered },
        uuid      = "e0f29bea-667b-4780-b36b-59de225e660e";
        url       = "https://www.wolframcloud.com/obj/" <> uuid;
        result    = Wolfram`AgentTools`Common`makeNotebookUIResult[
            { <| "type" -> "text", "text" -> "x" |> },
            url
        ];
        joined    = StringJoin[ #[ "text" ] & /@ result[ "Content" ] ];
        recovered = First[
            StringCases[ joined, "<result uuid=\"" ~~ u: Except[ "\"" ].. ~~ "\">" :> u ],
            None
        ];
        { recovered, "https://www.wolframcloud.com/obj/" <> recovered }
    ],
    {
        "e0f29bea-667b-4780-b36b-59de225e660e",
        "https://www.wolframcloud.com/obj/e0f29bea-667b-4780-b36b-59de225e660e"
    },
    SameTest -> MatchQ,
    TestID   -> "MakeNotebookUIResult-MarkerUUIDRecoverable@@Tests/MCPApps.wlt:1716,1-1737,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookEmbedURL Appends the Syntax Method Parameter*)
(* The parameter must match the one the viewers append when reconstructing a URL from the
   <result uuid="..."> marker, so both delivery paths open the notebook the same way. *)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`notebookEmbedURL[
        "https://www.wolframcloud.com/obj/e0f29bea-667b-4780-b36b-59de225e660e"
    ],
    "https://www.wolframcloud.com/obj/e0f29bea-667b-4780-b36b-59de225e660e?syntaxMethod=editor",
    SameTest -> Equal,
    TestID   -> "NotebookEmbedURL-AppendsParameter@@Tests/MCPApps.wlt:1744,1-1751,2"
]

(* A URL that already has a query string gets the parameter appended with & *)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`notebookEmbedURL[ "https://www.wolframcloud.com/obj/x?a=1" ],
    "https://www.wolframcloud.com/obj/x?a=1&syntaxMethod=editor",
    SameTest -> Equal,
    TestID   -> "NotebookEmbedURL-AppendsToExistingQuery@@Tests/MCPApps.wlt:1754,1-1759,2"
]

(* Inline serialized notebooks are not URLs and pass through unchanged *)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`notebookEmbedURL[ "Notebook[{Cell[\"1 + 1\", \"Input\"]}]" ],
    "Notebook[{Cell[\"1 + 1\", \"Input\"]}]",
    SameTest -> Equal,
    TestID   -> "NotebookEmbedURL-InlinePassthrough@@Tests/MCPApps.wlt:1762,1-1767,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudNotebookUUID Extracts UUID From Deployed URL*)
VerificationTest[
    Wolfram`AgentTools`UIResources`Private`cloudNotebookUUID[
        "https://www.wolframcloud.com/obj/e0f29bea-667b-4780-b36b-59de225e660e"
    ],
    "e0f29bea-667b-4780-b36b-59de225e660e",
    SameTest -> MatchQ,
    TestID   -> "CloudNotebookUUID-ExtractsUUID@@Tests/MCPApps.wlt:1772,1-1779,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Deployment Failure Returns $Failed*)
VerificationTest[
    Wolfram`AgentTools`Common`makeNotebookUIResult[
        { <| "type" -> "text", "text" -> "x" |> },
        $Failed
    ],
    $Failed,
    SameTest -> MatchQ,
    TestID   -> "MakeNotebookUIResult-DeployFailed@@Tests/MCPApps.wlt:1784,1-1792,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Inline (Non-http) Value Omits Marker*)
(* Inline notebooks carry the whole serialized notebook, so no <result uuid="..."> wrapper is
   added; the value is still carried in _meta. *)
VerificationTest[
    Module[ { serialized, result },
        serialized = "Notebook[{Cell[\"1 + 1\", \"Input\"]}]";
        result     = Wolfram`AgentTools`Common`makeNotebookUIResult[
            { <| "type" -> "text", "text" -> "x" |> },
            serialized
        ];
        { result[ "Content" ], result[ "_meta", "notebookUrl" ] }
    ],
    {
        { <| "type" -> "text", "text" -> "x" |> },
        "Notebook[{Cell[\"1 + 1\", \"Input\"]}]"
    },
    SameTest -> MatchQ,
    TestID   -> "MakeNotebookUIResult-InlineNoMarker@@Tests/MCPApps.wlt:1799,1-1814,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*delayedDisplay*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Inline Mode Wraps Graphics Output Asynchronously*)
VerificationTest[
    Block[ { Wolfram`AgentTools`UIResources`Private`$mcpAppsNotebookMethod = "Inline" },
        Wolfram`AgentTools`Common`delayedDisplay @ ToBoxes @ Graphics @ { Disk[ ] }
    ],
    _DynamicModuleBox,
    SameTest -> MatchQ,
    TestID   -> "DelayedDisplay-InlineWrapsGraphics@@Tests/MCPApps.wlt:1823,1-1830,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`UIResources`Private`$mcpAppsNotebookMethod = "Inline" },
        Wolfram`AgentTools`Common`delayedDisplay @ ToBoxes @ Graphics3D @ { Sphere[ ] }
    ],
    _DynamicModuleBox,
    SameTest -> MatchQ,
    TestID   -> "DelayedDisplay-InlineWrapsGraphics3D@@Tests/MCPApps.wlt:1832,1-1839,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Inline Mode Serializes the Original Graphics Box Away*)
VerificationTest[
    Block[ { Wolfram`AgentTools`UIResources`Private`$mcpAppsNotebookMethod = "Inline" },
        FreeQ[ Wolfram`AgentTools`Common`delayedDisplay @ ToBoxes @ Graphics @ { Disk[ ] }, GraphicsBox ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "DelayedDisplay-InlineSerializesGraphics@@Tests/MCPApps.wlt:1844,1-1851,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Inline Mode Leaves Graphics-Free Output Unchanged*)
VerificationTest[
    Block[ { Wolfram`AgentTools`UIResources`Private`$mcpAppsNotebookMethod = "Inline" },
        Wolfram`AgentTools`Common`delayedDisplay @ RowBox @ { "1", "+", "1" }
    ],
    RowBox @ { "1", "+", "1" },
    SameTest -> MatchQ,
    TestID   -> "DelayedDisplay-InlineGraphicsFreeUnchanged@@Tests/MCPApps.wlt:1856,1-1863,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*No-Op Outside Inline Mode*)
VerificationTest[
    With[ { boxes = ToBoxes @ Graphics @ { Disk[ ] } },
        Block[ { Wolfram`AgentTools`UIResources`Private`$mcpAppsNotebookMethod = Null },
            Wolfram`AgentTools`Common`delayedDisplay @ boxes === boxes
        ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "DelayedDisplay-NonInlineNoOp@@Tests/MCPApps.wlt:1868,1-1877,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cross-Origin Iframe Fallback (Strict-CSP Hosts)*)

(* Each notebook-embedding viewer must ship the eval-capability probe (cspAllowsEval) and the
   cross-origin iframe fallback (embedNotebookViaIframe). WolframNotebookEmbedder injects the
   cloud notebook engine (which needs eval/WebAssembly) into the app document; strict MCP hosts
   such as Goose build a sandbox CSP with no 'unsafe-eval' and reject any attempt to add it, so
   the engine can't run and the notebook never renders. When eval is blocked the viewer instead
   points an iframe at the cloud URL, where the notebook renders under wolframcloud.com's own
   eval-permitting CSP. These tests guard against silently dropping that fallback. *)

VerificationTest[
    Module[ { html }, Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        html = Wolfram`AgentTools`Common`$uiResourceRegistry[ "ui://wolfram/evaluator-viewer", "html" ];
        StringContainsQ[ html, "cspAllowsEval" ] && StringContainsQ[ html, "embedNotebookViaIframe" ]
    ] ],
    True,
    SameTest -> Equal,
    TestID   -> "EvaluatorViewer-EvalCSPFallbackPresent@@Tests/MCPApps.wlt:1891,1-1900,2"
]

VerificationTest[
    Module[ { html }, Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        html = Wolfram`AgentTools`Common`$uiResourceRegistry[ "ui://wolfram/wolframalpha-viewer", "html" ];
        StringContainsQ[ html, "cspAllowsEval" ] && StringContainsQ[ html, "embedNotebookViaIframe" ]
    ] ],
    True,
    SameTest -> Equal,
    TestID   -> "WolframAlphaViewer-EvalCSPFallbackPresent@@Tests/MCPApps.wlt:1902,1-1911,2"
]

VerificationTest[
    Module[ { html }, Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        html = Wolfram`AgentTools`Common`$uiResourceRegistry[ "ui://wolfram/notebook-viewer", "html" ];
        StringContainsQ[ html, "cspAllowsEval" ] && StringContainsQ[ html, "embedNotebookViaIframe" ]
    ] ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewer-EvalCSPFallbackPresent@@Tests/MCPApps.wlt:1913,1-1922,2"
]

(* The eval-blocked iframe fallback can't be auto-sized, so each viewer must let the user
   resize it via a drag handle rather than pin it to a single fixed height. A native corner
   `resize` grip is unusable here because the framed notebook's own scrollbar covers it. *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        AllTrue[
            { "ui://wolfram/evaluator-viewer", "ui://wolfram/wolframalpha-viewer", "ui://wolfram/notebook-viewer" },
            StringContainsQ[
                Wolfram`AgentTools`Common`$uiResourceRegistry[ #, "html" ],
                "notebook-resize-handle"
            ] &
        ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewers-IframeFallbackResizable@@Tests/MCPApps.wlt:1927,1-1941,2"
]

(* The resize drag's move/end listeners live on window, so each viewer must scope them to the
   initiating pointer; otherwise a second finger on a multi-pointer device could resize the
   frame or end the drag out from under the pointer that started it. *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        AllTrue[
            { "ui://wolfram/evaluator-viewer", "ui://wolfram/wolframalpha-viewer", "ui://wolfram/notebook-viewer" },
            StringContainsQ[
                Wolfram`AgentTools`Common`$uiResourceRegistry[ #, "html" ],
                "ev.pointerId !== activePointerId"
            ] &
        ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewers-ResizeDragScopedToPointer@@Tests/MCPApps.wlt:1946,1-1960,2"
]

(* The embedder path must remain for hosts whose CSP does permit eval (fit-to-content sizing),
   so the fallback is additive, not a replacement. *)
VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        AllTrue[
            { "ui://wolfram/evaluator-viewer", "ui://wolfram/wolframalpha-viewer", "ui://wolfram/notebook-viewer" },
            StringContainsQ[
                Wolfram`AgentTools`Common`$uiResourceRegistry[ #, "html" ],
                "WolframNotebookEmbedder"
            ] &
        ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewers-EmbedderPathRetained@@Tests/MCPApps.wlt:1964,1-1978,2"
]

(* Under strict CSP the fallback frames the notebook URL directly, so each viewer must
   restrict that iframe to Wolfram Cloud hosts (parsed with new URL) instead of embedding
   any http(s) URL; otherwise a tampered result could frame an arbitrary third-party page. *)
VerificationTest[
    Module[ { html },
        Block[ { Wolfram`AgentTools`Common`$uiResourceRegistry },
            Wolfram`AgentTools`Common`initializeUIResources[ ];
            AllTrue[
                { "ui://wolfram/evaluator-viewer", "ui://wolfram/wolframalpha-viewer", "ui://wolfram/notebook-viewer" },
                ( html = Wolfram`AgentTools`Common`$uiResourceRegistry[ #, "html" ];
                  StringContainsQ[ html, "!cspAllowsEval && isWolframCloudUrl" ] &&
                  StringContainsQ[ html, ".wolframcloud.com" ] ) &
            ]
        ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "NotebookViewers-IframeFallbackCloudAllowlist@@Tests/MCPApps.wlt:1983,1-1998,2"
]

(* :!CodeAnalysis::EndBlock:: *)
