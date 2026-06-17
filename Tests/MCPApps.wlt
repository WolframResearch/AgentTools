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
        result = Wolfram`AgentTools`StartMCPServer`Private`initResponse[
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
        result = Wolfram`AgentTools`StartMCPServer`Private`initResponse[
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
        result = Wolfram`AgentTools`StartMCPServer`Private`initResponse[
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
        result = Wolfram`AgentTools`StartMCPServer`Private`initResponse[
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
        result = Wolfram`AgentTools`StartMCPServer`Private`initResponse[
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
        result = Wolfram`AgentTools`StartMCPServer`Private`initResponse[
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
        result = Wolfram`AgentTools`StartMCPServer`Private`initResponse[
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
        result = Wolfram`AgentTools`StartMCPServer`Private`initResponse[
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
    TestID   -> "InitializeUIResources-GracefulFallback@@Tests/MCPApps.wlt:505,1-517,2"
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
    TestID   -> "ListUIResources-ReturnsWhenUISupported@@Tests/MCPApps.wlt:526,1-537,2"
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
    TestID   -> "ListUIResources-ReturnsFourResources@@Tests/MCPApps.wlt:539,1-550,2"
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
    TestID   -> "ListUIResources-EmptyWhenNoUI@@Tests/MCPApps.wlt:555,1-566,2"
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
    TestID   -> "ListUIResources-EmptyWhenUnset@@Tests/MCPApps.wlt:568,1-579,2"
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
    TestID   -> "ListUIResources-CorrectURIs@@Tests/MCPApps.wlt:584,1-595,2"
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
    TestID   -> "ReadUIResource-ValidURI@@Tests/MCPApps.wlt:604,1-623,2"
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
    TestID   -> "ReadUIResource-HTMLContent@@Tests/MCPApps.wlt:625,1-640,2"
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
    TestID   -> "ReadUIResource-UnknownURI@@Tests/MCPApps.wlt:645,1-659,2"
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
    TestID   -> "ReadUIResource-InvalidURIType@@Tests/MCPApps.wlt:661,1-675,2"
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
        Wolfram`AgentTools`StartMCPServer`Private`handleResourceRead[
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
    TestID   -> "HandleResourceRead-ValidURI@@Tests/MCPApps.wlt:684,1-702,2"
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
        Wolfram`AgentTools`StartMCPServer`Private`handleResourceRead[
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
    TestID   -> "HandleResourceRead-UnknownURIError@@Tests/MCPApps.wlt:707,1-728,2"
]

VerificationTest[
    Quiet @ Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        response = Wolfram`AgentTools`StartMCPServer`Private`handleResourceRead[
            <| "params" -> <| "uri" -> "ui://wolfram/nonexistent" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 5 |>
        ];
        response[ "error", "code" ]
    ],
    -32602,
    SameTest -> Equal,
    TestID   -> "HandleResourceRead-ErrorCodeIs32602@@Tests/MCPApps.wlt:730,1-745,2"
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
        response = Wolfram`AgentTools`StartMCPServer`Private`handleResourceRead[
            <| "params" -> <| "uri" -> 999 |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 6 |>
        ];
        { KeyExistsQ[ response, "error" ], response[ "error", "code" ] }
    ],
    { True, -32603 },
    SameTest -> MatchQ,
    TestID   -> "HandleResourceRead-InvalidParamsReturnsInternalError@@Tests/MCPApps.wlt:750,1-765,2"
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
        response = Wolfram`AgentTools`StartMCPServer`Private`handleResourceRead[
            <| "params" -> <| |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 7 |>
        ];
        response[ "error", "code" ]
    ],
    -32603,
    SameTest -> Equal,
    TestID   -> "HandleResourceRead-MissingParamsReturnsInternalError@@Tests/MCPApps.wlt:770,1-785,2"
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
        Wolfram`AgentTools`StartMCPServer`Private`handleMethod[
            "resources/list",
            <| "method" -> "resources/list", "params" -> <| |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ]
    ],
    KeyValuePattern[ {
        "result" -> KeyValuePattern[ "resources" -> { __Association } ]
    } ],
    SameTest -> MatchQ,
    TestID   -> "HandleMethod-ResourcesList-UIClient@@Tests/MCPApps.wlt:791,1-808,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = False,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`StartMCPServer`Private`handleMethod[
            "resources/list",
            <| "method" -> "resources/list", "params" -> <| |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ]
    ],
    KeyValuePattern[ {
        "result" -> KeyValuePattern[ "resources" -> { } ]
    } ],
    SameTest -> MatchQ,
    TestID   -> "HandleMethod-ResourcesList-NonUIClient@@Tests/MCPApps.wlt:810,1-827,2"
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
        Wolfram`AgentTools`StartMCPServer`Private`handleMethod[
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
    TestID   -> "HandleMethod-ResourcesRead-ValidURI@@Tests/MCPApps.wlt:833,1-854,2"
]

VerificationTest[
    Quiet @ Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = True,
        Wolfram`AgentTools`Common`$uiResourceRegistry
    },
        Wolfram`AgentTools`Common`initializeUIResources[ ];
        Wolfram`AgentTools`StartMCPServer`Private`handleMethod[
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
    TestID   -> "HandleMethod-ResourcesRead-UnknownURI@@Tests/MCPApps.wlt:856,1-876,2"
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
    TestID   -> "ToolUIMetadata-KnownToolWithUI@@Tests/MCPApps.wlt:885,1-895,2"
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
    TestID   -> "ToolUIMetadata-CorrectResourceURI@@Tests/MCPApps.wlt:897,1-908,2"
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
    TestID   -> "ToolUIMetadata-CorrectVisibility@@Tests/MCPApps.wlt:910,1-921,2"
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
    TestID   -> "ToolUIMetadata-WolframAlphaNoDeploy@@Tests/MCPApps.wlt:926,1-936,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = True },
        Wolfram`AgentTools`Common`toolUIMetadata[ "WolframLanguageEvaluator" ]
    ],
    { "_meta" -> KeyValuePattern[ "ui" -> KeyValuePattern[ "resourceUri" -> "ui://wolfram/evaluator-viewer" ] ] },
    SameTest -> MatchQ,
    TestID   -> "ToolUIMetadata-EvaluatorTool@@Tests/MCPApps.wlt:938,1-945,2"
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
    TestID   -> "ToolUIMetadata-UnknownTool@@Tests/MCPApps.wlt:950,1-957,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI = False },
        Wolfram`AgentTools`Common`toolUIMetadata[ "WolframAlpha" ]
    ],
    { },
    SameTest -> Equal,
    TestID   -> "ToolUIMetadata-KnownToolNoUI@@Tests/MCPApps.wlt:959,1-966,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$clientSupportsUI },
        Wolfram`AgentTools`Common`toolUIMetadata[ "WolframAlpha" ]
    ],
    { },
    SameTest -> Equal,
    TestID   -> "ToolUIMetadata-KnownToolUIUnset@@Tests/MCPApps.wlt:968,1-975,2"
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
    TestID   -> "WithToolUIMetadata-AddsMetaToKnownTool@@Tests/MCPApps.wlt:984,1-999,2"
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
    TestID   -> "WithToolUIMetadata-NoMetaForUnknownTool@@Tests/MCPApps.wlt:1001,1-1016,2"
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
    TestID   -> "WithToolUIMetadata-CorrectMetaContent@@Tests/MCPApps.wlt:1018,1-1032,2"
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
    TestID   -> "WithToolUIMetadata-NoChangesWhenNoUI@@Tests/MCPApps.wlt:1037,1-1047,2"
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
    TestID   -> "WithToolUIMetadata-PreservesExistingFields@@Tests/MCPApps.wlt:1052,1-1063,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*handleMethod - tools/list Integration*)

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI    = True,
        Wolfram`AgentTools`Common`$deployCloudNotebooks = True,
        Wolfram`AgentTools`StartMCPServer`Private`$toolList = {
            <| "name" -> "WolframAlpha", "description" -> "test", "inputSchema" -> <| |> |>,
            <| "name" -> "OtherTool",    "description" -> "test", "inputSchema" -> <| |> |>
        }
    },
        result = Wolfram`AgentTools`StartMCPServer`Private`handleMethod[
            "tools/list",
            <| "method" -> "tools/list", "params" -> <| |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ];
        waTool = SelectFirst[ result[ "result", "tools" ], #[ "name" ] === "WolframAlpha" & ];
        KeyExistsQ[ waTool, "_meta" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "HandleMethod-ToolsList-UIMetaPresent@@Tests/MCPApps.wlt:1069,1-1089,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI    = True,
        Wolfram`AgentTools`Common`$deployCloudNotebooks = True,
        Wolfram`AgentTools`StartMCPServer`Private`$toolList = {
            <| "name" -> "WolframAlpha", "description" -> "test", "inputSchema" -> <| |> |>,
            <| "name" -> "OtherTool",    "description" -> "test", "inputSchema" -> <| |> |>
        }
    },
        result = Wolfram`AgentTools`StartMCPServer`Private`handleMethod[
            "tools/list",
            <| "method" -> "tools/list", "params" -> <| |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ];
        otherTool = SelectFirst[ result[ "result", "tools" ], #[ "name" ] === "OtherTool" & ];
        KeyExistsQ[ otherTool, "_meta" ]
    ],
    False,
    SameTest -> Equal,
    TestID   -> "HandleMethod-ToolsList-NoMetaForUnlinkedTool@@Tests/MCPApps.wlt:1091,1-1111,2"
]

VerificationTest[
    Block[ {
        Wolfram`AgentTools`Common`$clientSupportsUI = False,
        Wolfram`AgentTools`StartMCPServer`Private`$toolList = {
            <| "name" -> "WolframAlpha", "description" -> "test", "inputSchema" -> <| |> |>
        }
    },
        result = Wolfram`AgentTools`StartMCPServer`Private`handleMethod[
            "tools/list",
            <| "method" -> "tools/list", "params" -> <| |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ];
        waTool = First @ result[ "result", "tools" ];
        KeyExistsQ[ waTool, "_meta" ]
    ],
    False,
    SameTest -> Equal,
    TestID   -> "HandleMethod-ToolsList-NoMetaWhenNoUI@@Tests/MCPApps.wlt:1113,1-1131,2"
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
    TestID   -> "DeployCloudNotebooks-Boolean@@Tests/MCPApps.wlt:1140,1-1145,2"
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
    TestID   -> "DeployCloudNotebooks-BlockTrue@@Tests/MCPApps.wlt:1150,1-1157,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`Common`$deployCloudNotebooks = False },
        Wolfram`AgentTools`Common`$deployCloudNotebooks
    ],
    False,
    SameTest -> Equal,
    TestID   -> "DeployCloudNotebooks-BlockFalse@@Tests/MCPApps.wlt:1159,1-1166,2"
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
    TestID   -> "DeployCloudNotebookForMCPApp-AssertsDeployEnabled@@Tests/MCPApps.wlt:1175,1-1185,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Invalid Arguments*)
VerificationTest[
    Quiet @ Wolfram`AgentTools`Common`deployCloudNotebookForMCPApp[ "not a notebook", "id" ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "DeployCloudNotebookForMCPApp-NotANotebook@@Tests/MCPApps.wlt:1190,1-1195,2"
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
    TestID   -> "DeployCloudNotebookForMCPApp-InlineReturnsString@@Tests/MCPApps.wlt:1200,1-1213,2"
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
    TestID   -> "DeployCloudNotebookForMCPApp-InlineRoundTrips@@Tests/MCPApps.wlt:1215,1-1231,2"
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
    TestID   -> "DeployCloudNotebookForMCPApp-InlineAssertsDeployEnabled@@Tests/MCPApps.wlt:1236,1-1249,2"
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
    TestID   -> "DelayedDisplay-InlineWrapsGraphics@@Tests/MCPApps.wlt:1258,1-1265,2"
]

VerificationTest[
    Block[ { Wolfram`AgentTools`UIResources`Private`$mcpAppsNotebookMethod = "Inline" },
        Wolfram`AgentTools`Common`delayedDisplay @ ToBoxes @ Graphics3D @ { Sphere[ ] }
    ],
    _DynamicModuleBox,
    SameTest -> MatchQ,
    TestID   -> "DelayedDisplay-InlineWrapsGraphics3D@@Tests/MCPApps.wlt:1267,1-1274,2"
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
    TestID   -> "DelayedDisplay-InlineSerializesGraphics@@Tests/MCPApps.wlt:1279,1-1286,2"
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
    TestID   -> "DelayedDisplay-InlineGraphicsFreeUnchanged@@Tests/MCPApps.wlt:1291,1-1298,2"
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
    TestID   -> "DelayedDisplay-NonInlineNoOp@@Tests/MCPApps.wlt:1303,1-1312,2"
]

(* :!CodeAnalysis::EndBlock:: *)
