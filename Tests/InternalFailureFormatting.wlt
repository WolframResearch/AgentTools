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
    TestID   -> "ExtractFailureTag-MCPServerBasic"
]

VerificationTest[
    Wolfram`AgentTools`Common`extractFailureTag[
        Failure[ "AgentTools::Internal", <|
            "Information" -> "TestTag@@Kernel/Common.wl:123,1-456,2"
        |> ]
    ],
    "AgentTools::Internal::Path@@Kernel/Common.wl:123,1-456,2",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-MCPServerWithSource"
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
    TestID   -> "ExtractFailureTag-MCPServerUnhandledDownValues"
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
    TestID   -> "ExtractFailureTag-MCPServerMXSource"
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
    TestID   -> "ExtractFailureTag-MCPServerConfirmBy"
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
    TestID   -> "ExtractFailureTag-MCPServerConfirmByWithSource"
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
    TestID   -> "ExtractFailureTag-MCPServerFunctionOnly"
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
    TestID   -> "ExtractFailureTag-MCPServerFunctionWithSource"
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
    TestID   -> "ExtractFailureTag-ChatbookBasic"
]

VerificationTest[
    Wolfram`AgentTools`Common`extractFailureTag[
        Failure[ "General::ChatbookInternal", <|
            "Information" -> "TestTag@@Kernel/Chatbook.wl:100,1-200,2"
        |> ]
    ],
    "Chatbook::Internal::Path@@Kernel/Chatbook.wl:100,1-200,2",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-ChatbookWithSource"
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
    TestID   -> "ExtractFailureTag-OtherFailure"
]

VerificationTest[
    Wolfram`AgentTools`Common`extractFailureTag[ "not a failure" ],
    "Unknown",
    SameTest -> Equal,
    TestID   -> "ExtractFailureTag-NotAFailure"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*generateUniqueFailureFileName*)

VerificationTest[
    fileName = Wolfram`AgentTools`Common`generateUniqueFailureFileName[ ];
    StringMatchQ[ fileName, __ ~~ ".mx" ],
    True,
    SameTest -> Equal,
    TestID   -> "GenerateUniqueFailureFileName-EndsWithMX"
]

VerificationTest[
    fileName = Wolfram`AgentTools`Common`generateUniqueFailureFileName[ ];
    StringMatchQ[ fileName, RegularExpression[ "\\d{4}-\\d{2}-\\d{2}_\\d{2}-\\d{2}-\\d{2}_[a-z0-9]{8}\\.mx" ] ],
    True,
    SameTest -> Equal,
    TestID   -> "GenerateUniqueFailureFileName-Format"
]

VerificationTest[
    names = Table[ Wolfram`AgentTools`Common`generateUniqueFailureFileName[ ], 10 ];
    Length @ Union @ names,
    10,
    SameTest -> Equal,
    TestID   -> "GenerateUniqueFailureFileName-Uniqueness"
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
    TestID   -> "FormatInternalFailureForMCP-ReturnsString"
]

VerificationTest[
    result = Wolfram`AgentTools`Common`formatInternalFailureForMCP[
        Failure[ "AgentTools::Internal", <| |> ]
    ];
    StringContainsQ[ result, "[Error]" ],
    True,
    SameTest -> Equal,
    TestID   -> "FormatInternalFailureForMCP-ContainsError"
]

VerificationTest[
    result = Wolfram`AgentTools`Common`formatInternalFailureForMCP[
        Failure[ "AgentTools::Internal", <| |> ]
    ];
    StringContainsQ[ result, "https://github.com/WolframResearch/AgentTools/issues/new" ],
    True,
    SameTest -> Equal,
    TestID   -> "FormatInternalFailureForMCP-ContainsIssueURL"
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
    TestID   -> "FormatInternalFailureForMCP-ContainsExtractedTag"
]

VerificationTest[
    result = Wolfram`AgentTools`Common`formatInternalFailureForMCP[
        Failure[ "General::ChatbookInternal", <| |> ]
    ];
    StringContainsQ[ result, "Chatbook::Internal" ],
    True,
    SameTest -> Equal,
    TestID   -> "FormatInternalFailureForMCP-ChatbookFailure"
]

VerificationTest[
    Wolfram`AgentTools`Common`formatInternalFailureForMCP[
        Failure[ "SomeOther::Tag", <| |> ]
    ],
    None,
    SameTest -> Equal,
    TestID   -> "FormatInternalFailureForMCP-NonInternalFailure"
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
    TestID   -> "FormatInternalFailureForMCP-NoBoxes"
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
    TestID   -> "SafeString-InternalFailureReturnsString"
]

VerificationTest[
    result = Wolfram`AgentTools`Server`Shared`Private`safeString[
        Failure[ "AgentTools::Internal", <| |> ]
    ];
    StringContainsQ[ result, "[Error]" ],
    True,
    SameTest -> Equal,
    TestID   -> "SafeString-InternalFailureContainsError"
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
    TestID   -> "SafeString-InternalFailureNoBoxes"
]

VerificationTest[
    result = Wolfram`AgentTools`Server`Shared`Private`safeString[
        Failure[ "General::ChatbookInternal", <| |> ]
    ];
    StringContainsQ[ result, "Chatbook::Internal" ],
    True,
    SameTest -> Equal,
    TestID   -> "SafeString-ChatbookInternalFailure"
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
    TestID   -> "SafeString-RegularFailureFallback"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`safeString[
        Failure[ "BadThing", <| "MessageTemplate" -> "Something went wrong: `1`", "MessageParameters" -> { "x" } |> ]
    ],
    "[Error] Something went wrong: x",
    SameTest -> Equal,
    TestID   -> "SafeString-FailureWithParameters-GH#271"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`safeString[
        Failure[
            "BadThing",
            <| "MessageTemplate" -> "Cannot read `1` (confidence `2`).", "MessageParameters" -> { File[ "data.txt" ], 1.5 } |>
        ]
    ],
    "[Error] Cannot read File[data.txt] (confidence 1.5).",
    SameTest -> Equal,
    TestID   -> "SafeString-FailureWithExpressionParameters-GH#271"
]

(* LLMTool returns Failure[ "ConfirmationFailed", ... ] for bad arguments, whose template already contains box markup *)
VerificationTest[
    tool = LLMTool[ <|
        "Name"        -> "CharacterCount",
        "Description" -> "Counts characters",
        "Function"    -> (StringLength[ #text ] &),
        "Parameters"  -> {
            "text" -> <| "Interpreter" -> "String", "Help" -> "Input text", "Required" -> True |>,
            "n"    -> <| "Interpreter" -> Restricted[ "Integer", { 1, 10 } ], "Help" -> "A number", "Required" -> False |>
        }
    |> ];
    {
        Wolfram`AgentTools`Server`Shared`Private`safeString @ tool @ <| |>,
        Wolfram`AgentTools`Server`Shared`Private`safeString @ tool @ <| "text" -> "hi", "n" -> "abc" |>
    },
    {
        s1_String /; StringStartsQ[ s1, "[Error] Missing required parameter \"text\"" ] && StringFreeQ[ s1, "Box" ],
        s2_String /; StringContainsQ[ s2, "could not interpret value \"abc\"" ] && StringFreeQ[ s2, "Box" ]
    },
    SameTest -> MatchQ,
    TestID   -> "SafeString-LLMToolParameterFailures-GH#271"
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
    TestID   -> "CleanupOldFailureLogs-NoError"
]

VerificationTest[
    (* Verify that log directory never exceeds 50 files *)
    Length @ FileNames[
        "*.mx",
        FileNameJoin @ { $UserBaseDirectory, "Logs", "AgentTools", "InternalFailures" }
    ] <= 50,
    True,
    SameTest -> Equal,
    TestID   -> "CleanupOldFailureLogs-MaxFiles"
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
    TestID   -> "CleanupOldFailureLogs-KeepsNewestFiles"
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
    TestID   -> "BugReportBody-ReturnsString"
]

VerificationTest[
    (* Verify bug report does NOT contain Settings section - this paclet has no settings *)
    bugReportText = Wolfram`AgentTools`Common`Private`bugReportBody[
        <| "Name" -> "Wolfram/AgentTools", "Version" -> "1.0.0" |>
    ];
    ! StringContainsQ[ bugReportText, "## Settings" ],
    True,
    SameTest -> Equal,
    TestID   -> "BugReportBody-NoSettingsSection"
]

VerificationTest[
    (* Verify no template placeholders remain in bug report *)
    bugReportText = Wolfram`AgentTools`Common`Private`bugReportBody[
        <| "Name" -> "Wolfram/AgentTools", "Version" -> "1.0.0" |>
    ];
    ! StringContainsQ[ bugReportText, "%%" ],
    True,
    SameTest -> Equal,
    TestID   -> "BugReportBody-NoTemplatePlaceholders"
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
    TestID   -> "BugReportBody-ContainsExpectedSections"
]

(* :!CodeAnalysis::EndBlock:: *)
