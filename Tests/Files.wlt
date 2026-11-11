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
(*ensureFilePath*)

VerificationTest[
    Wolfram`AgentTools`Common`catchTop[
        Wolfram`AgentTools`Common`ensureFilePath[ FileNameJoin @ { $TemporaryDirectory, "ensureFilePath_test.txt" } ]
    ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "EnsureFilePath-AbsolutePath-GH#108"
]

VerificationTest[
    WithCleanup[
        SetDirectory[ $TemporaryDirectory ],
        Wolfram`AgentTools`Common`catchTop[
            Wolfram`AgentTools`Common`ensureFilePath[ "ensureFilePath_relative_test.txt" ]
        ],
        ResetDirectory[]
    ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "EnsureFilePath-RelativePath-GH#108"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchTop[
        Wolfram`AgentTools`Common`ensureFilePath[ File[ FileNameJoin @ { $TemporaryDirectory, "ensureFilePath_wrapped_test.txt" } ] ]
    ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "EnsureFilePath-FileWrapper-GH#108"
]

VerificationTest[
    WithCleanup[
        SetDirectory[ $TemporaryDirectory ],
        Wolfram`AgentTools`Common`catchTop[
            Wolfram`AgentTools`Common`ensureFilePath[ File[ "ensureFilePath_relative_wrapped_test.txt" ] ]
        ],
        ResetDirectory[]
    ],
    _File,
    SameTest -> MatchQ,
    TestID   -> "EnsureFilePath-FileWrapper-RelativePath-GH#108"
]

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*JSON Files*)
(* writeRawJSONFile and writeRawJSONString wrap the Developer` JSON writers with jsonConvert as the default
   "ConversionFunction", so values that JSON cannot represent become strings instead of failing the export *)

(* JSON-representable values are written as usual *)
VerificationTest[
    Wolfram`AgentTools`Common`writeRawJSONString[
        <| "int" -> 1, "real" -> 2.5, "string" -> "x", "true" -> True, "false" -> False, "null" -> Null, "list" -> { 1, "a" }, "object" -> <| "k" -> 1 |> |>,
        "Compact" -> True
    ],
    "{\"int\":1,\"real\":2.5,\"string\":\"x\",\"true\":true,\"false\":false,\"null\":null,\"list\":[1,\"a\"],\"object\":{\"k\":1}}",
    SameTest -> SameQ,
    TestID   -> "WriteRawJSONString-JSONValues"
]

(* Anything else becomes its InputForm string, wherever it appears *)
VerificationTest[
    Developer`ReadRawJSONString @ Wolfram`AgentTools`Common`writeRawJSONString @ <|
        "none"    -> None,
        "inf"     -> Infinity,
        "missing" -> Missing[ "NotAvailable" ],
        "list"    -> { $Failed, Automatic },
        "nested"  -> <| "q" -> Quantity[ 1, "Hours" ] |>
    |>,
    <|
        "none"    -> "None",
        "inf"     -> "Infinity",
        "missing" -> "Missing[\"NotAvailable\"]",
        "list"    -> { "$Failed", "Automatic" },
        "nested"  -> <| "q" -> "Quantity[1, \"Hours\"]" |>
    |>,
    SameTest -> SameQ,
    TestID   -> "WriteRawJSONString-NonJSONValuesAsStrings"
]

(* Dates become ISO 8601 strings in UTC with millisecond precision *)
VerificationTest[
    Developer`ReadRawJSONString @ Wolfram`AgentTools`Common`writeRawJSONString @ <|
        "utc"   -> DateObject[ { 2026, 8, 1, 12, 0, 0 }, TimeZone -> 0 ],
        "local" -> DateObject[ { 2026, 8, 1, 12, 0, 0 }, TimeZone -> -5 ],
        "ms"    -> DateObject[ { 2026, 8, 1, 12, 0, 0.25 }, TimeZone -> 0 ],
        "day"   -> DateObject[ { 2026, 8, 1 }, TimeZone -> 0 ]
    |>,
    <|
        "utc"   -> "2026-08-01T12:00:00.000Z",
        "local" -> "2026-08-01T17:00:00.000Z",
        "ms"    -> "2026-08-01T12:00:00.250Z",
        "day"   -> "2026-08-01T00:00:00.000Z"
    |>,
    SameTest -> SameQ,
    TestID   -> "WriteRawJSONString-Dates"
]

(* A "ConversionFunction" given by the caller takes precedence over jsonConvert *)
VerificationTest[
    Wolfram`AgentTools`Common`writeRawJSONString[ <| "none" -> None |>, "ConversionFunction" -> ("custom" &), "Compact" -> True ],
    "{\"none\":\"custom\"}",
    SameTest -> SameQ,
    TestID   -> "WriteRawJSONString-ConversionFunctionOverride"
]

(* jsonConvert holds its argument, so an expression is converted as it is rather than evaluated again *)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
VerificationTest[
    Wolfram`AgentTools`Files`Private`jsonConvert /@ Unevaluated @ {
        None, Infinity, 1 + 1, Hold[ 1 + 1 ], DateObject[ { 2026, 8, 1, 12, 0, 0 }, TimeZone -> 0 ]
    },
    { "None", "Infinity", "1 + 1", "Hold[1 + 1]", "2026-08-01T12:00:00.000Z" },
    SameTest -> SameQ,
    TestID   -> "JSONConvert-HoldsArgument"
]
(* :!CodeAnalysis::EndBlock:: *)

(* writeRawJSONFile creates the file's directory, applies the same conversions, and readRawJSONFile reads the result
   back *)
VerificationTest[
    Module[ { file, written },
        file = FileNameJoin @ { $TemporaryDirectory, "AgentToolsFilesTest_" <> CreateUUID[ ], "data.json" };
        written = Wolfram`AgentTools`Common`writeRawJSONFile[
            file,
            <| "int" -> 1, "none" -> None, "date" -> DateObject[ { 2026, 8, 1, 12, 0, 0 }, TimeZone -> 0 ] |>
        ];
        WithCleanup[
            { FileExistsQ @ written, Wolfram`AgentTools`Common`readRawJSONFile @ file },
            DeleteDirectory[ DirectoryName @ file, DeleteContents -> True ]
        ]
    ],
    { True, <| "int" -> 1, "none" -> "None", "date" -> "2026-08-01T12:00:00.000Z" |> },
    SameTest -> SameQ,
    TestID   -> "WriteRawJSONFile-NonJSONValuesAsStrings"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Global Settings*)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* Machine-wide settings live in a single WXF association directly under $rootPath (see docs/usage-data.md) *)
VerificationTest[
    withTemporaryRoot[
        Wolfram`AgentTools`Common`$globalSettingsFile ===
            FileNameJoin @ { Wolfram`AgentTools`Common`$rootPath, "GlobalSettings.wxf" }
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "GlobalSettings-FileLocation"
]

(* Nothing has been set yet: reading gives no settings and creates nothing *)
VerificationTest[
    withTemporaryRoot @ {
        Wolfram`AgentTools`Common`readGlobalSettings[ ],
        Wolfram`AgentTools`Common`getGlobalSetting[ "Anything" ],
        Wolfram`AgentTools`Common`getGlobalSetting[ "Anything", "default" ],
        FileExistsQ @ Wolfram`AgentTools`Common`$globalSettingsFile,
        DirectoryQ @ Wolfram`AgentTools`Common`$rootPath
    },
    { <| |>, Missing[ "KeyAbsent", "Anything" ], "default", False, False },
    SameTest -> SameQ,
    TestID   -> "GlobalSettings-Unset"
]

(* Setting a value creates the file (and its directory) and returns the value *)
VerificationTest[
    withTemporaryRoot @ {
        Wolfram`AgentTools`Common`setGlobalSetting[ "A", 1 ],
        FileExistsQ @ Wolfram`AgentTools`Common`$globalSettingsFile,
        Developer`ReadWXFFile @ Wolfram`AgentTools`Common`$globalSettingsFile,
        Wolfram`AgentTools`Common`getGlobalSetting[ "A" ],
        Wolfram`AgentTools`Common`getGlobalSetting[ "A", "default" ],
        Wolfram`AgentTools`Common`readGlobalSettings[ ]
    },
    { 1, True, <| "A" -> 1 |>, 1, 1, <| "A" -> 1 |> },
    SameTest -> SameQ,
    TestID   -> "GlobalSettings-SetAndGet"
]

(* New values are merged into the existing settings, so setting one never loses another *)
VerificationTest[
    withTemporaryRoot @ (
        Wolfram`AgentTools`Common`setGlobalSetting[ "A", 1 ];
        Wolfram`AgentTools`Common`setGlobalSetting[ "B", { "x", "y" } ];
        Wolfram`AgentTools`Common`setGlobalSetting[ "A", False ];
        Wolfram`AgentTools`Common`readGlobalSettings[ ]
    ),
    <| "A" -> False, "B" -> { "x", "y" } |>,
    SameTest -> SameQ,
    TestID   -> "GlobalSettings-Merge"
]

(* A file that cannot be read, or that does not hold an association, counts as no settings and is replaced by the
   next write *)
VerificationTest[
    withTemporaryRoot @ Module[ { file, text, list, written },
        file = Wolfram`AgentTools`Common`$globalSettingsFile;
        CreateDirectory @ Wolfram`AgentTools`Common`$rootPath;
        Export[ file, "not a WXF file", "Text" ];
        text = Wolfram`AgentTools`Common`readGlobalSettings[ ];
        Developer`WriteWXFFile[ file, { 1, 2, 3 } ];
        list = Wolfram`AgentTools`Common`readGlobalSettings[ ];
        Wolfram`AgentTools`Common`setGlobalSetting[ "A", 1 ];
        written = Wolfram`AgentTools`Common`readGlobalSettings[ ];
        { text, list, written }
    ],
    { <| |>, <| |>, <| "A" -> 1 |> },
    SameTest -> SameQ,
    TestID   -> "GlobalSettings-Unreadable"
]

(* :!CodeAnalysis::EndBlock:: *)
