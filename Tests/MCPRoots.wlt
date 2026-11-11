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

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Session State*)

VerificationTest[
    BooleanQ @ Wolfram`AgentTools`Common`$clientSupportsRoots,
    True,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-ClientSupportsRootsIsBoolean"
]

VerificationTest[
    Wolfram`AgentTools`Common`$mcpRoot === None || StringQ @ Wolfram`AgentTools`Common`$mcpRoot,
    True,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-McpRootIsNoneOrString"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*rootURIToPath*)

(* file:// URIs are expanded to native paths via ExpandFileName[LocalObject[uri]]. *)
VerificationTest[
    StringQ @ Wolfram`AgentTools`MCPRoots`Private`rootURIToPath[
        "file:///" <> StringReplace[ $TemporaryDirectory, "\\" -> "/" ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-RootURIToPathFileScheme"
]

(* Non-file URIs are rejected. *)
VerificationTest[
    Wolfram`AgentTools`MCPRoots`Private`rootURIToPath[ "https://example.com/path" ],
    None,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-RootURIToPathNonFileScheme"
]

(* Non-strings are rejected. *)
VerificationTest[
    Wolfram`AgentTools`MCPRoots`Private`rootURIToPath[ 42 ],
    None,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-RootURIToPathNonString"
]

(* Malformed Windows URIs (backslashes, missing third slash) emitted by some clients
   like Claude Code are normalized before expansion. *)
VerificationTest[
    If[ $OperatingSystem === "Windows",
        Module[ { tmpDir, uri, result, ok },
            tmpDir = CreateDirectory[ ];
            uri    = "file://" <> tmpDir;
            WithCleanup[
                result = Wolfram`AgentTools`MCPRoots`Private`rootURIToPath @ uri;
                ok     = StringQ @ result && DirectoryQ @ result &&
                    ExpandFileName @ result === ExpandFileName @ tmpDir,
                DeleteDirectory[ tmpDir, DeleteContents -> True ]
            ];
            ok
        ],
        True
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-RootURIToPathWindowsBackslashURI"
]

(* Two-slash URIs with drive letters (file://H:/Documents/...) are also normalized. *)
VerificationTest[
    If[ $OperatingSystem === "Windows",
        Module[ { tmpDir, uri, result, ok },
            tmpDir = CreateDirectory[ ];
            uri    = "file://" <> StringReplace[ tmpDir, "\\" -> "/" ];
            WithCleanup[
                result = Wolfram`AgentTools`MCPRoots`Private`rootURIToPath @ uri;
                ok     = StringQ @ result && DirectoryQ @ result &&
                    ExpandFileName @ result === ExpandFileName @ tmpDir,
                DeleteDirectory[ tmpDir, DeleteContents -> True ]
            ];
            ok
        ],
        True
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-RootURIToPathWindowsTwoSlashURI"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*normalizeFileURI*)

(* Backslashes are converted to forward slashes. *)
VerificationTest[
    Wolfram`AgentTools`MCPRoots`Private`normalizeFileURI[ "file://H:\\Documents\\AgentTools" ],
    "file:///H:/Documents/AgentTools",
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-NormalizeFileURIBackslashes"
]

(* The third slash before a drive letter is added when missing. *)
VerificationTest[
    Wolfram`AgentTools`MCPRoots`Private`normalizeFileURI[ "file://H:/Documents/AgentTools" ],
    "file:///H:/Documents/AgentTools",
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-NormalizeFileURITwoSlashes"
]

(* Lowercase drive letters are also normalized. *)
VerificationTest[
    Wolfram`AgentTools`MCPRoots`Private`normalizeFileURI[ "file://c:\\Users\\me" ],
    "file:///c:/Users/me",
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-NormalizeFileURILowercaseDrive"
]

(* Already-well-formed URIs pass through unchanged. *)
VerificationTest[
    Wolfram`AgentTools`MCPRoots`Private`normalizeFileURI[ "file:///H:/Documents/AgentTools" ],
    "file:///H:/Documents/AgentTools",
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-NormalizeFileURIWellFormed"
]

(* POSIX file URIs (no drive letter) are not given an extra slash. *)
VerificationTest[
    Wolfram`AgentTools`MCPRoots`Private`normalizeFileURI[ "file:///home/user/project" ],
    "file:///home/user/project",
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-NormalizeFileURIPosix"
]

(* UNC-style file URIs (file://server/share) are left intact. *)
VerificationTest[
    Wolfram`AgentTools`MCPRoots`Private`normalizeFileURI[ "file://server/share/path" ],
    "file://server/share/path",
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-NormalizeFileURIUNC"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*pickFirstValidRoot*)

(* A single valid root is returned as-is. *)
VerificationTest[
    Module[ { tmpDir, uri, result, ok },
        tmpDir = CreateDirectory[ ];
        uri = "file:///" <> StringReplace[ tmpDir, "\\" -> "/" ];
        WithCleanup[
            result = Wolfram`AgentTools`MCPRoots`Private`pickFirstValidRoot[
                { <| "uri" -> uri, "name" -> "tmp" |> }
            ];
            ok = StringQ @ result && DirectoryQ @ result,
            DeleteDirectory[ tmpDir, DeleteContents -> True ]
        ];
        ok
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-PickFirstValidRootSingle"
]

(* The first invalid root is skipped, and the second valid root is returned. *)
VerificationTest[
    Module[ { tmpDir, validURI, result, ok },
        tmpDir = CreateDirectory[ ];
        validURI = "file:///" <> StringReplace[ tmpDir, "\\" -> "/" ];
        WithCleanup[
            result = Wolfram`AgentTools`MCPRoots`Private`pickFirstValidRoot[
                {
                    <| "uri" -> "file:///nonexistent/path/that/does/not/exist", "name" -> "stale" |>,
                    <| "uri" -> validURI, "name" -> "good" |>
                }
            ];
            ok = StringQ @ result && DirectoryQ @ result,
            DeleteDirectory[ tmpDir, DeleteContents -> True ]
        ];
        ok
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-PickFirstValidRootMultiFallback"
]

(* An empty list returns None. *)
VerificationTest[
    Wolfram`AgentTools`MCPRoots`Private`pickFirstValidRoot[ { } ],
    None,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-PickFirstValidRootEmpty"
]

(* Entries without "uri" are skipped. *)
VerificationTest[
    Wolfram`AgentTools`MCPRoots`Private`pickFirstValidRoot[
        { <| "name" -> "missing-uri" |> }
    ],
    None,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-PickFirstValidRootNoURIKey"
]

(* Non-file:// schemes are skipped. *)
VerificationTest[
    Wolfram`AgentTools`MCPRoots`Private`pickFirstValidRoot[
        { <| "uri" -> "https://example.com/", "name" -> "web" |> }
    ],
    None,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-PickFirstValidRootNonFileScheme"
]

(* All-invalid lists return None. *)
VerificationTest[
    Wolfram`AgentTools`MCPRoots`Private`pickFirstValidRoot[
        {
            <| "uri" -> "file:///nonexistent/aaaa", "name" -> "a" |>,
            <| "uri" -> "file:///nonexistent/bbbb", "name" -> "b" |>
        }
    ],
    None,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-PickFirstValidRootAllInvalid"
]

(* Non-list inputs return None. *)
VerificationTest[
    Wolfram`AgentTools`MCPRoots`Private`pickFirstValidRoot[ "not a list" ],
    None,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-PickFirstValidRootNonList"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*handleRootsListResponse*)

(* A successful response with a valid root invokes applyMCPRoot. The nested
   "result"."roots" path is read via Part-style chaining (response[ "result", "roots" ])
   rather than Lookup with a list-key, so this also serves as the regression test
   that the nested-association lookup keeps working. *)
VerificationTest[
    Module[ { tmpDir, uri, applied, response, ok },
        tmpDir = CreateDirectory[ ];
        uri = "file:///" <> StringReplace[ tmpDir, "\\" -> "/" ];
        applied = None;
        response = <|
            "jsonrpc" -> "2.0",
            "id"      -> "test-uuid",
            "result"  -> <| "roots" -> { <| "uri" -> uri, "name" -> "tmp" |> } |>
        |>;
        WithCleanup[
            Block[
                {
                    Wolfram`AgentTools`MCPRoots`Private`applyMCPRoot =
                        Function[ root, applied = root ]
                },
                Wolfram`AgentTools`MCPRoots`Private`handleRootsListResponse[
                    <| "method" -> "roots/list" |>,
                    response
                ]
            ];
            ok = StringQ @ applied && DirectoryQ @ applied,
            DeleteDirectory[ tmpDir, DeleteContents -> True ]
        ];
        ok
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-HandleRootsListResponseSuccess"
]

(* An error response logs the error and does not apply a root. *)
VerificationTest[
    Module[ { applied, response },
        applied = None;
        response = <|
            "jsonrpc" -> "2.0",
            "id"      -> "test-uuid",
            "error"   -> <| "code" -> -32601, "message" -> "Method not found" |>
        |>;
        Block[
            {
                Wolfram`AgentTools`MCPRoots`Private`applyMCPRoot =
                    Function[ root, applied = root ]
            },
            Wolfram`AgentTools`MCPRoots`Private`handleRootsListResponse[
                <| "method" -> "roots/list" |>,
                response
            ]
        ];
        applied
    ],
    None,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-HandleRootsListResponseError"
]

(* An empty roots list does not apply a root. *)
VerificationTest[
    Module[ { applied, response },
        applied = None;
        response = <|
            "jsonrpc" -> "2.0",
            "id"      -> "test-uuid",
            "result"  -> <| "roots" -> { } |>
        |>;
        Block[
            {
                Wolfram`AgentTools`MCPRoots`Private`applyMCPRoot =
                    Function[ root, applied = root ]
            },
            Wolfram`AgentTools`MCPRoots`Private`handleRootsListResponse[
                <| "method" -> "roots/list" |>,
                response
            ]
        ];
        applied
    ],
    None,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-HandleRootsListResponseEmpty"
]

(* All roots invalid - no root applied. *)
VerificationTest[
    Module[ { applied, response },
        applied = None;
        response = <|
            "jsonrpc" -> "2.0",
            "id"      -> "test-uuid",
            "result"  -> <| "roots" -> {
                <| "uri" -> "file:///nonexistent/aaaa", "name" -> "a" |>,
                <| "uri" -> "https://example.com",     "name" -> "b" |>
            } |>
        |>;
        Block[
            {
                Wolfram`AgentTools`MCPRoots`Private`applyMCPRoot =
                    Function[ root, applied = root ]
            },
            Wolfram`AgentTools`MCPRoots`Private`handleRootsListResponse[
                <| "method" -> "roots/list" |>,
                response
            ]
        ];
        applied
    ],
    None,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-HandleRootsListResponseAllInvalid"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*onClientInitialized*)

(* When the client did not advertise roots, no request is sent. *)
VerificationTest[
    Module[ { sent, savedFlag },
        savedFlag = Wolfram`AgentTools`Common`$clientSupportsRoots;
        sent = None;
        WithCleanup[
            Wolfram`AgentTools`Common`$clientSupportsRoots = False,
            Block[
                {
                    Wolfram`AgentTools`Common`sendClientRequest =
                        Function[ { method, params, handler }, sent = method ]
                },
                Wolfram`AgentTools`Common`onClientInitialized[ <| |> ]
            ],
            Wolfram`AgentTools`Common`$clientSupportsRoots = savedFlag
        ];
        sent
    ],
    None,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-OnClientInitializedNoCapability"
]

(* When the client advertised roots, a roots/list request is sent. *)
VerificationTest[
    Module[ { sent, savedFlag },
        savedFlag = Wolfram`AgentTools`Common`$clientSupportsRoots;
        sent = None;
        WithCleanup[
            Wolfram`AgentTools`Common`$clientSupportsRoots = True,
            Block[
                {
                    Wolfram`AgentTools`Common`sendClientRequest =
                        Function[ { method, params, handler }, sent = method ]
                },
                Wolfram`AgentTools`Common`onClientInitialized[ <| |> ]
            ],
            Wolfram`AgentTools`Common`$clientSupportsRoots = savedFlag
        ];
        sent
    ],
    "roots/list",
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-OnClientInitializedSendsRequest"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*onRootsListChanged*)

(* When the client did not advertise roots, list_changed does not trigger a request. *)
VerificationTest[
    Module[ { sent, savedFlag },
        savedFlag = Wolfram`AgentTools`Common`$clientSupportsRoots;
        sent = None;
        WithCleanup[
            Wolfram`AgentTools`Common`$clientSupportsRoots = False,
            Block[
                {
                    Wolfram`AgentTools`Common`sendClientRequest =
                        Function[ { method, params, handler }, sent = method ]
                },
                Wolfram`AgentTools`Common`onRootsListChanged[ <| |> ]
            ],
            Wolfram`AgentTools`Common`$clientSupportsRoots = savedFlag
        ];
        sent
    ],
    None,
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-OnRootsListChangedNoCapability"
]

(* When the client advertised roots, list_changed triggers a fresh roots/list request. *)
VerificationTest[
    Module[ { sent, savedFlag },
        savedFlag = Wolfram`AgentTools`Common`$clientSupportsRoots;
        sent = None;
        WithCleanup[
            Wolfram`AgentTools`Common`$clientSupportsRoots = True,
            Block[
                {
                    Wolfram`AgentTools`Common`sendClientRequest =
                        Function[ { method, params, handler }, sent = method ]
                },
                Wolfram`AgentTools`Common`onRootsListChanged[ <| |> ]
            ],
            Wolfram`AgentTools`Common`$clientSupportsRoots = savedFlag
        ];
        sent
    ],
    "roots/list",
    SameTest -> MatchQ,
    TestID   -> "MCPRoots-OnRootsListChangedSendsRequest"
]

(* :!CodeAnalysis::EndBlock:: *)
