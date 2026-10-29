(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ResourceFunctions.wlt:7,1-12,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ResourceFunctions.wlt:14,1-19,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Local Definitions*)
VerificationTest[
    $resourceFunctionDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "ResourceFunctions" },
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "ResourceFunctionDirectory@@Tests/ResourceFunctions.wlt:24,1-29,2"
]

(* Every resource function the paclet uses has a local definition, except ReplaceContext, which is only needed when
   importing from the Function Repository *)
VerificationTest[
    Select[
        DeleteCases[ Keys @ Wolfram`AgentTools`Common`Private`$resourceVersions, "ReplaceContext" ],
        ! FileExistsQ @ FileNameJoin @ { $resourceFunctionDirectory, #1 <> ".wl" } &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "LocalDefinitionsExist@@Tests/ResourceFunctions.wlt:33,1-41,2"
]

(* Each local definition file lives in its own context *)
VerificationTest[
    Select[
        FileNames[ "*.wl", $resourceFunctionDirectory ],
        ! StringContainsQ[
            ReadString @ #1,
            "BeginPackage[ \"Wolfram`AgentTools`ResourceFunctions`" <> FileBaseName @ #1 <> "`\" ]"
        ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "LocalDefinitionsWrapped@@Tests/ResourceFunctions.wlt:44,1-55,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Imported Functions*)
(* Imports resolve to the local definitions: inlined at build time in an MX build, loaded at first use from source *)
VerificationTest[
    With[ { f = Wolfram`AgentTools`Tools`SymbolDefinition`Private`readableForm }, Context @ f ],
    "Wolfram`AgentTools`ResourceFunctions`ReadableForm`",
    SameTest -> MatchQ,
    TestID   -> "ReadableFormImport@@Tests/ResourceFunctions.wlt:61,1-66,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`resourceFunctionAvailableQ @ Wolfram`AgentTools`Tools`SymbolDefinition`Private`readableForm,
    True,
    SameTest -> MatchQ,
    TestID   -> "ReadableFormAvailable@@Tests/ResourceFunctions.wlt:68,1-73,2"
]

(* Loading a local definition must not leave its context on $ContextPath *)
VerificationTest[
    Select[ $ContextPath, StringStartsQ[ "Wolfram`AgentTools`ResourceFunctions`" ] ],
    { },
    SameTest -> MatchQ,
    TestID   -> "NoContextPathLeak@@Tests/ResourceFunctions.wlt:76,1-81,2"
]

VerificationTest[
    ToString @ Wolfram`AgentTools`Tools`SymbolDefinition`Private`readableForm @ Unevaluated[ f[ x_ ] := x + 1 ],
    "f[ x_ ] := x + 1",
    SameTest -> MatchQ,
    TestID   -> "ReadableFormWorks@@Tests/ResourceFunctions.wlt:83,1-88,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`messageFailure[ "UnknownTool", "TestTool" ],
    Failure[ "AgentTools::UnknownTool", _ ]? (#1[ "MessageParameters" ] === { "TestTool" } &),
    { AgentTools::UnknownTool },
    SameTest -> MatchQ,
    TestID   -> "MessageFailureWorks@@Tests/ResourceFunctions.wlt:90,1-96,2"
]

VerificationTest[
    Wolfram`AgentTools`Tools`importMarkdownString[ "# Title\n\nSome text", "Notebook" ],
    _Notebook,
    SameTest -> MatchQ,
    TestID   -> "ImportMarkdownStringWorks@@Tests/ResourceFunctions.wlt:98,1-103,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportMarkdownString @ Notebook @ { Cell[ "Hello", "Text" ] },
    _String? (StringContainsQ[ "Hello" ]),
    SameTest -> MatchQ,
    TestID   -> "ExportMarkdownStringWorks@@Tests/ResourceFunctions.wlt:105,1-110,2"
]

VerificationTest[
    Wolfram`AgentTools`Tools`CodeInspector`Private`astPattern @ HoldPattern[ f[ _ ] ],
    _CodeParser`CallNode,
    SameTest -> MatchQ,
    TestID   -> "ASTPatternWorks@@Tests/ResourceFunctions.wlt:112,1-117,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Unavailable Resource Functions*)
(* A resource function with no local definition that cannot be fetched gives a placeholder that fails with a message
   when used, and the import is not memoized so it is retried on the next use *)
VerificationTest[
    Wolfram`AgentTools`Common`importResourceFunction[ $testResourceFunction, "NoSuchAgentToolsTestResourceFunction", "1.0.0" ];
    $testResourceFunction,
    _Wolfram`AgentTools`Common`Private`resourceFunctionUnavailable,
    SameTest -> MatchQ,
    TestID   -> "UnavailablePlaceholder@@Tests/ResourceFunctions.wlt:124,1-130,2"
]

VerificationTest[
    $testResourceFunction[ 1, 2 ],
    Failure[ "AgentTools::ResourceFunctionUnavailable", _ ]? (#1[ "MessageParameters" ] === { "NoSuchAgentToolsTestResourceFunction" } &),
    { AgentTools::ResourceFunctionUnavailable },
    SameTest -> MatchQ,
    TestID   -> "UnavailableFailure@@Tests/ResourceFunctions.wlt:132,1-138,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`resourceFunctionAvailableQ @ $testResourceFunction,
    False,
    SameTest -> MatchQ,
    TestID   -> "UnavailableNotAvailable@@Tests/ResourceFunctions.wlt:140,1-145,2"
]

VerificationTest[
    OwnValues @ $testResourceFunction,
    { _ :> _Wolfram`AgentTools`Common`Private`resolveResourceFunction },
    SameTest -> MatchQ,
    TestID   -> "UnavailableNotMemoized@@Tests/ResourceFunctions.wlt:147,1-152,2"
]

(* The SymbolDefinition tool falls back to InputForm when ReadableForm is not available *)
VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Tools`SymbolDefinition`Private`readableForm =
                Wolfram`AgentTools`Common`Private`resourceFunctionUnavailable[ "ReadableForm" ]
        },
        Wolfram`AgentTools`Tools`SymbolDefinition`Private`formatDefinitionReadable[
            { HoldForm[ f[ x_ ] := x + 1 ] },
            { "System`" },
            "Global`"
        ]
    ],
    $Failed,
    SameTest -> MatchQ,
    TestID   -> "SymbolDefinitionReadableFallback@@Tests/ResourceFunctions.wlt:155,1-170,2"
]

VerificationTest[
    Block[
        {
            Wolfram`AgentTools`Tools`SymbolDefinition`Private`readableForm =
                Wolfram`AgentTools`Common`Private`resourceFunctionUnavailable[ "ReadableForm" ]
        },
        $DefaultMCPTools[ "SymbolDefinition" ][ "Function" ][
            <| "symbols" -> "Wolfram`AgentTools`$MCPTransport", "includeContextDetails" -> False, "maxLength" -> 10000 |>
        ]
    ],
    _? (StringContainsQ[ ToString @ #1, "$MCPTransport = None" ] &),
    SameTest -> MatchQ,
    TestID   -> "SymbolDefinitionToolFallback@@Tests/ResourceFunctions.wlt:172,1-185,2"
]

(* :!CodeAnalysis::EndBlock:: *)
