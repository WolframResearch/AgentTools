(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/InternalFailureFormatting.wlt:7,1-12,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/InternalFailureFormatting.wlt:14,1-19,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*extractFailureTag*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AgentTools Internal Failures*)
VerificationTest[
    Wolfram`AgentTools`Common`extractFailureTag[
        Failure[ "AgentTools::Internal", <| |> ]
    ],
    "AgentTools::Internal",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-MCPServerBasic@@Tests/InternalFailureFormatting.wlt:28,1-35,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`extractFailureTag[
        Failure[ "AgentTools::Internal", <|
            "Information" -> "TestTag@@Kernel/Common.wl:123,1-456,2"
        |> ]
    ],
    "AgentTools::Internal::Path@@Kernel/Common.wl:123,1-456,2",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-MCPServerWithSource@@Tests/InternalFailureFormatting.wlt:37,1-46,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`extractFailureTag[
        Failure[ "AgentTools::Internal", <|
            "MessageParameters" -> {
                "link",
                <| "Arguments" -> { "UnhandledDownValues", HoldForm[ testSymbol ] } |>
            }
        |> ]
    ],
    "AgentTools::Internal::UnhandledDownValues::testSymbol",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-MCPServerUnhandledDownValues@@Tests/InternalFailureFormatting.wlt:48,1-60,2"
]

VerificationTest[
    (* Test MX-style failure with Source at top level *)
    Wolfram`AgentTools`Common`extractFailureTag[
        Failure[ "AgentTools::Internal", <|
            "Source" -> "Path@@Kernel/Test.wl:10,1-20,2"
        |> ]
    ],
    "AgentTools::Internal::Path@@Kernel/Test.wl:10,1-20,2",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-MCPServerMXSource@@Tests/InternalFailureFormatting.wlt:62,1-72,2"
]

VerificationTest[
    (* Test ConfirmBy failure with function name (no short source) *)
    Wolfram`AgentTools`Common`extractFailureTag[
        Failure[ "AgentTools::Internal", <|
            "MessageParameters" -> {
                "link",
                <| "ConfirmationType" -> "ConfirmBy", "Function" -> testFunction |>
            }
        |> ]
    ],
    "AgentTools::Internal::ConfirmBy::testFunction",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-MCPServerConfirmBy@@Tests/InternalFailureFormatting.wlt:74,1-87,2"
]

VerificationTest[
    (* Test ConfirmBy failure with function name and short source *)
    Wolfram`AgentTools`Common`extractFailureTag[
        Failure[ "AgentTools::Internal", <|
            "Source" -> "Path",
            "MessageParameters" -> {
                "link",
                <| "ConfirmationType" -> "ConfirmBy", "Function" -> testFunction |>
            }
        |> ]
    ],
    "AgentTools::Internal::ConfirmBy::testFunction::Path",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-MCPServerConfirmByWithSource@@Tests/InternalFailureFormatting.wlt:89,1-103,2"
]

VerificationTest[
    (* Test failure with just function name *)
    Wolfram`AgentTools`Common`extractFailureTag[
        Failure[ "AgentTools::Internal", <|
            "MessageParameters" -> {
                "link",
                <| "Function" -> someFunction |>
            }
        |> ]
    ],
    "AgentTools::Internal::Function::someFunction",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-MCPServerFunctionOnly@@Tests/InternalFailureFormatting.wlt:105,1-118,2"
]

VerificationTest[
    (* Test failure with function name and short source *)
    Wolfram`AgentTools`Common`extractFailureTag[
        Failure[ "AgentTools::Internal", <|
            "Source" -> "Tag",
            "MessageParameters" -> {
                "link",
                <| "Function" -> someFunction |>
            }
        |> ]
    ],
    "AgentTools::Internal::Function::someFunction::Tag",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-MCPServerFunctionWithSource@@Tests/InternalFailureFormatting.wlt:120,1-134,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Chatbook Internal Failures*)
VerificationTest[
    Wolfram`AgentTools`Common`extractFailureTag[
        Failure[ "General::ChatbookInternal", <| |> ]
    ],
    "Chatbook::Internal",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-ChatbookBasic@@Tests/InternalFailureFormatting.wlt:139,1-146,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`extractFailureTag[
        Failure[ "General::ChatbookInternal", <|
            "Information" -> "TestTag@@Kernel/Chatbook.wl:100,1-200,2"
        |> ]
    ],
    "Chatbook::Internal::Path@@Kernel/Chatbook.wl:100,1-200,2",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-ChatbookWithSource@@Tests/InternalFailureFormatting.wlt:148,1-157,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other Failures*)
VerificationTest[
    Wolfram`AgentTools`Common`extractFailureTag[
        Failure[ "SomeOther::Tag", <| |> ]
    ],
    "SomeOther::Tag",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-OtherFailure@@Tests/InternalFailureFormatting.wlt:162,1-169,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`extractFailureTag[ "not a failure" ],
    "Unknown",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-NotAFailure@@Tests/InternalFailureFormatting.wlt:171,1-176,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*generateUniqueFailureFileName*)

VerificationTest[
    fileName = Wolfram`AgentTools`Common`generateUniqueFailureFileName[ ];
    StringMatchQ[ fileName, __ ~~ ".mx" ],
    True,
    SameTest -> Equal,
    TestID   -> "GenerateUniqueFailureFileName-EndsWithMX@@Tests/InternalFailureFormatting.wlt:182,1-188,2"
]

VerificationTest[
    fileName = Wolfram`AgentTools`Common`generateUniqueFailureFileName[ ];
    StringMatchQ[ fileName, RegularExpression[ "\\d{4}-\\d{2}-\\d{2}_\\d{2}-\\d{2}-\\d{2}_[a-z0-9]{8}\\.mx" ] ],
    True,
    SameTest -> Equal,
    TestID   -> "GenerateUniqueFailureFileName-Format@@Tests/InternalFailureFormatting.wlt:190,1-196,2"
]

VerificationTest[
    names = Table[ Wolfram`AgentTools`Common`generateUniqueFailureFileName[ ], 10 ];
    Length @ Union @ names,
    10,
    SameTest -> Equal,
    TestID   -> "GenerateUniqueFailureFileName-Uniqueness@@Tests/InternalFailureFormatting.wlt:198,1-204,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*formatInternalFailureForMCP*)

VerificationTest[
    result = Wolfram`AgentTools`Common`formatInternalFailureForMCP[
        Failure[ "AgentTools::Internal", <| |> ]
    ];
    StringQ @ result,
    True,
    SameTest -> Equal,
    TestID   -> "FormatInternalFailureForMCP-ReturnsString@@Tests/InternalFailureFormatting.wlt:210,1-218,2"
]

VerificationTest[
    result = Wolfram`AgentTools`Common`formatInternalFailureForMCP[
        Failure[ "AgentTools::Internal", <| |> ]
    ];
    StringContainsQ[ result, "[Error]" ],
    True,
    SameTest -> Equal,
    TestID   -> "FormatInternalFailureForMCP-ContainsError@@Tests/InternalFailureFormatting.wlt:220,1-228,2"
]

VerificationTest[
    result = Wolfram`AgentTools`Common`formatInternalFailureForMCP[
        Failure[ "AgentTools::Internal", <| |> ]
    ];
    StringContainsQ[ result, "https://github.com/WolframResearch/AgentTools/issues/new" ],
    True,
    SameTest -> Equal,
    TestID   -> "FormatInternalFailureForMCP-ContainsIssueURL@@Tests/InternalFailureFormatting.wlt:230,1-238,2"
]

VerificationTest[
    result = Wolfram`AgentTools`Common`formatInternalFailureForMCP[
        Failure[ "AgentTools::Internal", <|
            "Information" -> "TestTag@@Kernel/Test.wl:10,1-20,2"
        |> ]
    ];
    StringContainsQ[ result, "AgentTools::Internal::Path@@Kernel/Test.wl:10,1-20,2" ],
    True,
    SameTest -> Equal,
    TestID   -> "FormatInternalFailureForMCP-ContainsExtractedTag@@Tests/InternalFailureFormatting.wlt:240,1-250,2"
]

VerificationTest[
    result = Wolfram`AgentTools`Common`formatInternalFailureForMCP[
        Failure[ "General::ChatbookInternal", <| |> ]
    ];
    StringContainsQ[ result, "Chatbook::Internal" ],
    True,
    SameTest -> Equal,
    TestID   -> "FormatInternalFailureForMCP-ChatbookFailure@@Tests/InternalFailureFormatting.wlt:252,1-260,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`formatInternalFailureForMCP[
        Failure[ "SomeOther::Tag", <| |> ]
    ],
    None,
    SameTest -> Equal,
    TestID   -> "FormatInternalFailureForMCP-NonInternalFailure@@Tests/InternalFailureFormatting.wlt:262,1-269,2"
]

VerificationTest[
    result = Wolfram`AgentTools`Common`formatInternalFailureForMCP[
        Failure[ "AgentTools::Internal", <| |> ]
    ];
    And[
        ! StringContainsQ[ result, "TagBox" ],
        ! StringContainsQ[ result, "TemplateBox" ],
        ! StringContainsQ[ result, "RowBox" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "FormatInternalFailureForMCP-NoBoxes@@Tests/InternalFailureFormatting.wlt:271,1-283,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*safeString Integration*)

VerificationTest[
    result = Wolfram`AgentTools`Server`Shared`Private`safeString[
        Failure[ "AgentTools::Internal", <| |> ]
    ];
    StringQ @ result,
    True,
    SameTest -> Equal,
    TestID   -> "SafeString-InternalFailureReturnsString@@Tests/InternalFailureFormatting.wlt:289,1-297,2"
]

VerificationTest[
    result = Wolfram`AgentTools`Server`Shared`Private`safeString[
        Failure[ "AgentTools::Internal", <| |> ]
    ];
    StringContainsQ[ result, "[Error]" ],
    True,
    SameTest -> Equal,
    TestID   -> "SafeString-InternalFailureContainsError@@Tests/InternalFailureFormatting.wlt:299,1-307,2"
]

VerificationTest[
    result = Wolfram`AgentTools`Server`Shared`Private`safeString[
        Failure[ "AgentTools::Internal", <| |> ]
    ];
    And[
        ! StringContainsQ[ result, "TagBox" ],
        ! StringContainsQ[ result, "TemplateBox" ],
        ! StringContainsQ[ result, "RowBox" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "SafeString-InternalFailureNoBoxes@@Tests/InternalFailureFormatting.wlt:309,1-321,2"
]

VerificationTest[
    result = Wolfram`AgentTools`Server`Shared`Private`safeString[
        Failure[ "General::ChatbookInternal", <| |> ]
    ];
    StringContainsQ[ result, "Chatbook::Internal" ],
    True,
    SameTest -> Equal,
    TestID   -> "SafeString-ChatbookInternalFailure@@Tests/InternalFailureFormatting.wlt:323,1-331,2"
]

VerificationTest[
    (* Regular failures use the Failure's formatted Message property, which returns
       "A failure of type 'tag' occurred." for failures without a MessageTemplate *)
    result = Wolfram`AgentTools`Server`Shared`Private`safeString[
        Failure[ "SomeRegularError", <| "Message" -> "Something went wrong" |> ]
    ];
    And[
        StringQ @ result,
        StringContainsQ[ result, "[Error]" ],
        ! StringContainsQ[ result, "TagBox" ],
        ! StringContainsQ[ result, "TemplateBox" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "SafeString-RegularFailureFallback@@Tests/InternalFailureFormatting.wlt:333,1-348,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*cleanupOldFailureLogs*)

VerificationTest[
    (* Just verify the function runs without error *)
    Wolfram`AgentTools`Common`cleanupOldFailureLogs[ ];
    True,
    True,
    SameTest -> Equal,
    TestID   -> "CleanupOldFailureLogs-NoError@@Tests/InternalFailureFormatting.wlt:354,1-361,2"
]

VerificationTest[
    (* Verify that log directory never exceeds 50 files *)
    Length @ FileNames[
        "*.mx",
        FileNameJoin @ { $UserBaseDirectory, "Logs", "AgentTools", "InternalFailures" }
    ] <= 50,
    True,
    SameTest -> Equal,
    TestID   -> "CleanupOldFailureLogs-MaxFiles@@Tests/InternalFailureFormatting.wlt:363,1-372,2"
]

VerificationTest[
    (* Verify that cleanup keeps newest files, not oldest *)
    Module[ { tempDir, oldFile, newFile, files },
        tempDir = CreateDirectory[ ];
        (* Create an "old" file *)
        oldFile = FileNameJoin @ { tempDir, "old_file.mx" };
        Export[ oldFile, <| "test" -> 1 |>, "MX" ];
        Pause[ 1.1 ]; (* Ensure different modification times *)
        (* Create a "new" file *)
        newFile = FileNameJoin @ { tempDir, "new_file.mx" };
        Export[ newFile, <| "test" -> 2 |>, "MX" ];
        (* Run cleanup with maxFiles=1 *)
        Block[
            { Wolfram`AgentTools`Common`Private`$internalFailureLogDirectory = tempDir },
            Wolfram`AgentTools`Common`cleanupOldFailureLogs[ 1 ]
        ];
        files = FileNames[ "*.mx", tempDir ];
        DeleteDirectory[ tempDir, DeleteContents -> True ];
        (* The newer file should be kept *)
        files === { newFile }
    ],
    True,
    SameTest -> Equal,
    TestID   -> "CleanupOldFailureLogs-KeepsNewestFiles@@Tests/InternalFailureFormatting.wlt:374,1-398,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*bugReportBody*)

VerificationTest[
    (* Verify bug report body is generated as a string *)
    bugReportText = Wolfram`AgentTools`Common`Private`bugReportBody[
        <| "Name" -> "Wolfram/AgentTools", "Version" -> "1.0.0" |>
    ];
    StringQ @ bugReportText,
    True,
    SameTest -> Equal,
    TestID   -> "BugReportBody-ReturnsString@@Tests/InternalFailureFormatting.wlt:404,1-413,2"
]

VerificationTest[
    (* Verify bug report does NOT contain Settings section - this paclet has no settings *)
    bugReportText = Wolfram`AgentTools`Common`Private`bugReportBody[
        <| "Name" -> "Wolfram/AgentTools", "Version" -> "1.0.0" |>
    ];
    ! StringContainsQ[ bugReportText, "## Settings" ],
    True,
    SameTest -> Equal,
    TestID   -> "BugReportBody-NoSettingsSection@@Tests/InternalFailureFormatting.wlt:415,1-424,2"
]

VerificationTest[
    (* Verify no template placeholders remain in bug report *)
    bugReportText = Wolfram`AgentTools`Common`Private`bugReportBody[
        <| "Name" -> "Wolfram/AgentTools", "Version" -> "1.0.0" |>
    ];
    ! StringContainsQ[ bugReportText, "%%" ],
    True,
    SameTest -> Equal,
    TestID   -> "BugReportBody-NoTemplatePlaceholders@@Tests/InternalFailureFormatting.wlt:426,1-435,2"
]

VerificationTest[
    (* Verify bug report contains expected sections *)
    bugReportText = Wolfram`AgentTools`Common`Private`bugReportBody[
        <| "Name" -> "Wolfram/AgentTools", "Version" -> "1.0.0" |>
    ];
    And[
        StringContainsQ[ bugReportText, "Debug Data" ],
        StringContainsQ[ bugReportText, "## Failure Data" ],
        StringContainsQ[ bugReportText, "## Stack Data" ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "BugReportBody-ContainsExpectedSections@@Tests/InternalFailureFormatting.wlt:437,1-450,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Secrets*)
(* Failure data and the messages of invalid calls never show secrets (redactSecrets): the values of keys that can hold
   them, Authorization header lines and bearer tokens in strings and byte arrays, and other occurrences of those and of
   the secrets that code registered (withFailureSecrets). *)
VerificationTest[
    Module[ { token = "0123456789abcdef0123456789abcdef", redacted },
        redacted = Wolfram`AgentTools`Common`redactSecrets @ {
            "POST /mcp HTTP/1.1\r\nAuthorization: Bearer " <> token <> "\r\nHost: 127.0.0.1:1234",
            "{\"headers\":{\"Authorization\":\"Bearer " <> token <> "\"}}",
            StringToByteArray[ "GET / HTTP/1.1\r\nproxy-authorization: Basic " <> token <> "\r\n\r\n", "ISO8859-1" ],
            <| "Token" -> token, "Authentication" -> <| "Token" -> token |>, "Count" -> 1 |>
        };
        MapAt[ ByteArrayToString[ #, "ISO8859-1" ] &, redacted, 3 ]
    ],
    {
        "POST /mcp HTTP/1.1\r\nAuthorization: <redacted>\r\nHost: 127.0.0.1:1234",
        "{\"headers\":{\"Authorization\":\"Bearer <redacted>\"}}",
        "GET / HTTP/1.1\r\nproxy-authorization: <redacted>\r\n\r\n",
        <| "Token" -> "<redacted>", "Authentication" -> "<redacted>", "Count" -> 1 |>
    },
    SameTest -> MatchQ,
    TestID   -> "RedactSecrets-TextAndBytes@@Tests/InternalFailureFormatting.wlt:458,1-476,2"
]

(* A secret found as such (here as the value of an Authorization key, and after "Bearer" in JSON text) is redacted
   wherever else it occurs, e.g. passed on its own to a function; so are the secrets that are given or registered
   (withFailureSecrets). *)
VerificationTest[
    With[ { token = "0123456789abcdef0123456789abcdef", other = "fedcba9876543210", third = "0011223344556677" },
        {
            Wolfram`AgentTools`Common`redactSecrets @ {
                HoldForm @ authorize[ token ],
                <| "Headers" -> <| "authorization" -> "Bearer " <> token |> |>
            },
            With[ { json = "{\"headers\":{\"Authorization\":\"Bearer " <> other <> "\"}}" },
                Wolfram`AgentTools`Common`redactSecrets @ { HoldForm @ configure[ json ], HoldForm @ authorize[ other ] }
            ],
            Wolfram`AgentTools`Common`redactSecrets[ HoldForm @ use[ other, "id:" <> other ], { other } ],
            Wolfram`AgentTools`Common`withFailureSecrets[
                { third },
                Wolfram`AgentTools`Common`redactSecrets @ HoldForm @ use[ third ]
            ],
            Wolfram`AgentTools`Common`redactSecrets @ HoldForm @ use[ third ]
        }
    ],
    {
        { HoldForm @ authorize[ "<redacted>" ], <| "Headers" -> <| "authorization" -> "<redacted>" |> |> },
        {
            HoldForm @ configure[ "{\"headers\":{\"Authorization\":\"Bearer <redacted>\"}}" ],
            HoldForm @ authorize[ "<redacted>" ]
        },
        HoldForm @ use[ "<redacted>", "id:" <> "<redacted>" ],
        HoldForm @ use[ "<redacted>" ],
        HoldForm @ use[ "0011223344556677" ]
    },
    SameTest -> MatchQ,
    TestID   -> "RedactSecrets-FoundSecretsEverywhere@@Tests/InternalFailureFormatting.wlt:481,1-511,2"
]

(* Secrets are only redacted whole: a secret that holds another one (here a token and its first half) is replaced as a
   whole, and a short one found in the data (here a one-letter token) only as the value of its key, since replacing its
   other occurrences would garble the data. *)
VerificationTest[
    With[ { token = "0123456789abcdef0123456789abcdef" },
        {
            Wolfram`AgentTools`Common`redactSecrets[
                HoldForm @ use[ token, "id:" <> token ],
                { StringTake[ token, 16 ], token }
            ],
            Wolfram`AgentTools`Common`redactSecrets @ { "Token" -> "e", HoldForm @ f[ "UnhandledDownValues", "e" ] }
        }
    ],
    {
        HoldForm @ use[ "<redacted>", "id:" <> "<redacted>" ],
        { "Token" -> "<redacted>", HoldForm @ f[ "UnhandledDownValues", "e" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "RedactSecrets-WholeSecretsOnly@@Tests/InternalFailureFormatting.wlt:516,1-532,2"
]

(* Secrets that are given or registered are known to be secrets, so they are redacted wherever they occur, whatever
   their length (here a token of 7 characters); only empty and whitespace strings are not. *)
VerificationTest[
    With[ { token = "Zq7#Kp2" },
        {
            Wolfram`AgentTools`Common`withFailureSecrets[
                { token },
                Wolfram`AgentTools`Common`redactSecrets @ HoldForm @ use[ token, "id:Zq7#Kp2" ]
            ],
            Wolfram`AgentTools`Common`redactSecrets[ HoldForm @ use[ token ], { token } ],
            Wolfram`AgentTools`Common`redactSecrets[ HoldForm @ use[ token, " " ], { "", " " } ]
        }
    ],
    {
        HoldForm @ use[ "<redacted>", "id:<redacted>" ],
        HoldForm @ use[ "<redacted>" ],
        HoldForm @ use[ "Zq7#Kp2", " " ]
    },
    SameTest -> MatchQ,
    TestID   -> "RedactSecrets-KnownSecretsAnyLength@@Tests/InternalFailureFormatting.wlt:536,1-554,2"
]

(* Nothing is evaluated: not the code inside held expressions (where Association[...] and ByteArray[...] are not yet
   objects), not delayed values, and not the values that an association holds unevaluated (ReplacePart can make such
   associations), with or without a secret. *)
VerificationTest[
    Module[ { count = 0, unevaluated, text },
        unevaluated = ReplacePart[ <| "Value" -> 1, "Token" -> "x" |>, "Value" :> count++ ];
        text = ToString[
            Wolfram`AgentTools`Common`redactSecrets @ {
                Hold @ f[ <| "Token" -> count++, "Other" -> count++ |>, ByteArray[ count++ ] ],
                <| "Evaluation" :> count++, "Token" :> count++ |>,
                unevaluated,
                KeyDrop[ unevaluated, "Token" ]
            },
            InputForm
        ];
        { count, StringCount[ text, "<redacted>" ], StringCount[ text, "++" ] }
    ],
    { 0, 3, 5 },
    SameTest -> MatchQ,
    TestID   -> "RedactSecrets-NothingEvaluated@@Tests/InternalFailureFormatting.wlt:559,1-576,2"
]

(* Packed arrays, which hold only numbers, are neither searched for secrets nor matched by the rules that redact them
   (here those of a rule and of an association that hold a secret), either of which would unpack them. *)
VerificationTest[
    Module[ { array, redacted },
        array = RandomReal[ 1, 10^6 ];
        WithCleanup[
            On[ "Packing" ],
            redacted = Quiet[
                Check[
                    Wolfram`AgentTools`Common`redactSecrets @ {
                        array,
                        "Token" -> "0123456789abcdef",
                        <| "Token" -> "0123456789abcdef", "Data" -> array |>
                    },
                    "Unpacked",
                    "Packing"
                ],
                "Packing"
            ],
            Off[ "Packing" ]
        ];
        {
            redacted === { array, "Token" -> "<redacted>", <| "Token" -> "<redacted>", "Data" -> array |> },
            Developer`PackedArrayQ @ First @ redacted,
            Developer`PackedArrayQ @ Last[ redacted ][ "Data" ],
            Wolfram`AgentTools`Common`redactSecrets @ { array, 1 } === { array, 1 }
        }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "RedactSecrets-PackedArrays@@Tests/InternalFailureFormatting.wlt:580,1-609,2"
]

(* The data of an internal failure is redacted: here the failing call only holds a token, which the code that handles
   it registered (withFailureSecrets), or which the failure data shows to be one. The evaluation stack is not redacted,
   since only its symbol is in the data. *)
VerificationTest[
    Module[ { token, registered, found },
        token = IntegerString[ 3^160, 16 ];
        registered = With[ { t = token },
            Wolfram`AgentTools`Common`withFailureSecrets[
                { t },
                Wolfram`AgentTools`Common`Private`makeInternalFailureData[ authorize @ t, "UnhandledDownValues" ]
            ]
        ];
        found = With[ { t = token },
            Wolfram`AgentTools`Common`Private`makeInternalFailureData[
                authorize @ t,
                "UnhandledDownValues",
                <| "Headers" -> <| "authorization" -> "Bearer " <> t |> |>
            ]
        ];
        {
            Extract[ registered, { Key[ "Evaluation" ] }, HoldForm ],
            Extract[ found, { Key[ "Evaluation" ] }, HoldForm ],
            found[ "Arguments" ],
            StringFreeQ[ ToString[ { registered, found }, InputForm ], token ],
            Extract[ found, { Key[ "Stack" ] }, HoldForm ]
        }
    ],
    {
        HoldForm @ authorize[ "<redacted>" ],
        HoldForm @ authorize[ "<redacted>" ],
        { "UnhandledDownValues", <| "Headers" -> <| "authorization" -> "<redacted>" |> |> },
        True,
        HoldForm[ _Symbol ]
    },
    SameTest -> MatchQ,
    TestID   -> "InternalFailureData-Redacted@@Tests/InternalFailureFormatting.wlt:614,1-647,2"
]

(* The time that the failure data takes does not grow with data that is only on the evaluation stack (here in the frame
   of a caller, as in the computation that a preemptive evaluation interrupted), and its packed arrays are not
   unpacked. *)
VerificationTest[
    Module[ { outer, inner, array, associations, data, seconds, result },
        outer[ a_, b_ ] := (Null; inner[ a, b ]; Null);
        inner[ _, _ ] := (
            data = Wolfram`AgentTools`Common`Private`makeInternalFailureData[ fail[ 1 ], "UnhandledDownValues" ]
        );
        array        = RandomReal[ 1, 5 * 10^6 ];
        associations = Table[ <| "a" -> i, "b" -> ToString @ i |>, { i, 10^5 } ];
        WithCleanup[
            On[ "Packing" ],
            { seconds, result } = AbsoluteTiming @ Quiet[
                Check[ outer[ array, associations ], "Unpacked", "Packing" ],
                "Packing"
            ],
            Off[ "Packing" ]
        ];
        { result, data[ "Arguments" ], seconds < 1 }
    ],
    { Null, { "UnhandledDownValues" }, True },
    SameTest -> MatchQ,
    TestID   -> "InternalFailureData-StackNotSearched@@Tests/InternalFailureFormatting.wlt:652,1-673,2"
]

(* The log directory is created private to the user, and an existing one is made private (not on Windows, whose
   profile directories are private already). *)
VerificationTest[
    Module[ { root, created, existing, mode },
        root     = CreateDirectory[ ];
        created  = FileNameJoin @ { root, "Logs", "InternalFailures" };
        existing = CreateDirectory @ FileNameJoin @ { root, "Existing" };
        mode     = If[ $OperatingSystem === "Windows",
                       "drwx------" &,
                       StringTake[ RunProcess[ { "ls", "-ld", # }, "StandardOutput" ], 10 ] &
                   ];
        If[ $OperatingSystem =!= "Windows", RunProcess[ { "chmod", "775", existing } ] ];
        WithCleanup[
            {
                Wolfram`AgentTools`Common`Private`ensureInternalFailureLogDirectory @ created,
                mode @ created,
                Wolfram`AgentTools`Common`Private`ensureInternalFailureLogDirectory @ existing,
                mode @ existing
            },
            DeleteDirectory[ root, DeleteContents -> True ]
        ] === { created, "drwx------", existing, "drwx------" }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InternalFailureLogDirectory-Private@@Tests/InternalFailureFormatting.wlt:677,1-700,2"
]

(* :!CodeAnalysis::EndBlock:: *)
