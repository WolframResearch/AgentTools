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

VerificationTest[
    Needs[ "Wolfram`AgentTools`Tools`SymbolDefinition`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadPrivateContext"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Registration*)
VerificationTest[
    $symbolDefinitionTool = $DefaultMCPTools[ "SymbolDefinition" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "GetTool"
]

VerificationTest[
    $symbolDefinitionTool[ "Name" ],
    "SymbolDefinition",
    SameTest -> SameQ,
    TestID   -> "ToolName"
]

VerificationTest[
    StringQ @ $symbolDefinitionTool[ "Description" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ToolDescription"
]

VerificationTest[
    ListQ @ $symbolDefinitionTool[ "Parameters" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ToolParameters"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Input Parsing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parseSymbolNames*)
VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`parseSymbolNames[ "System`Plus" ],
    { "System`Plus" },
    SameTest -> MatchQ,
    TestID   -> "ParseSingleSymbol"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`parseSymbolNames[ "System`Plus, System`Times, System`Map" ],
    { "System`Plus", "System`Times", "System`Map" },
    SameTest -> MatchQ,
    TestID   -> "ParseMultipleSymbols"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`parseSymbolNames[ "  System`Plus  ,  System`Times  " ],
    { "System`Plus", "System`Times" },
    SameTest -> MatchQ,
    TestID   -> "ParseWhitespaceHandling"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`parseSymbolNames[ "" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ParseEmptyInput"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Symbol Validation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validateSymbolName*)
VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`validateSymbolName[ "MySymbol" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ValidateSimpleName"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`validateSymbolName[ "System`Plus" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ValidateQualifiedName"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`validateSymbolName[ "My`Context`Symbol" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ValidateDeepContext"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`validateSymbolName[ "Invalid!Symbol" ],
    False,
    SameTest -> SameQ,
    TestID   -> "ValidateInvalidChars"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`validateSymbolName[ "123Invalid" ],
    False,
    SameTest -> SameQ,
    TestID   -> "ValidateStartsWithNumber"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*symbolExistsQ*)
VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`symbolExistsQ[ "System`Plus" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ExistsSystemSymbol"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`symbolExistsQ[ "NonExistentContext12345`NonExistentSymbol67890" ],
    False,
    SameTest -> SameQ,
    TestID   -> "ExistsNonexistent"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*splitSymbolName*)
VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`splitSymbolName[ "System`Plus" ],
    { "System`", "Plus" },
    SameTest -> MatchQ,
    TestID   -> "SplitName-Simple"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`splitSymbolName[ "My`Deep`Context`Symbol" ],
    { "My`Deep`Context`", "Symbol" },
    SameTest -> MatchQ,
    TestID   -> "SplitName-Deep"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`splitSymbolName[ "UnqualifiedSymbol" ],
    { "Global`", "UnqualifiedSymbol" },
    SameTest -> MatchQ,
    TestID   -> "SplitName-Unqualified"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attribute Checking*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*isReadProtectedQ*)
VerificationTest[
    (* AASTriangle is ReadProtected *)
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`isReadProtectedQ[ "System`AASTriangle" ],
    True,
    SameTest -> SameQ,
    TestID   -> "IsReadProtected-AASTriangle"
]

VerificationTest[
    (* List is not ReadProtected *)
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`isReadProtectedQ[ "System`List" ],
    False,
    SameTest -> SameQ,
    TestID   -> "IsReadProtected-List"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*isLockedQ*)
VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`isLockedQ[ "System`Plus" ],
    False,
    SameTest -> SameQ,
    TestID   -> "IsLocked-Plus"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definition Extraction*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractDefinition*)
VerificationTest[
    $subtractDef = Wolfram`AgentTools`Tools`SymbolDefinition`Private`extractDefinition[ "System`Subtract" ],
    { ___ },
    SameTest -> MatchQ,
    TestID   -> "ExtractSubtract"
]

VerificationTest[
    Length[ $subtractDef ] > 0,
    True,
    SameTest -> SameQ,
    TestID   -> "ExtractSubtractNonEmpty"
]

VerificationTest[
    MatchQ[
        Quiet @ Wolfram`AgentTools`Tools`SymbolDefinition`Private`extractDefinition[ "System`Map" ],
        { ___ }
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "ExtractMap"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`extractDefinition[ "NonExistent12345`Symbol" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ExtractNonexistent"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Kernel Code Detection*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getKernelCodeDefinitions*)
VerificationTest[
    $plusKernelDefs = Wolfram`AgentTools`Tools`SymbolDefinition`Private`getKernelCodeDefinitions[ "System`Plus" ],
    { __HoldForm },
    SameTest -> MatchQ,
    TestID   -> "KernelCode-Plus"
]

VerificationTest[
    MemberQ[
        $plusKernelDefs,
        HoldForm[ Plus[___] := _ ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "KernelCode-PlusHasDownCode"
]

VerificationTest[
    $timesKernelDefs = Wolfram`AgentTools`Tools`SymbolDefinition`Private`getKernelCodeDefinitions[ "System`Times" ],
    { __HoldForm },
    SameTest -> MatchQ,
    TestID   -> "KernelCode-Times"
]

VerificationTest[
    (* Paclet symbols have no kernel code *)
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`getKernelCodeDefinitions[ "Wolfram`AgentTools`CreateMCPServer" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "KernelCode-PacletSymbolEmpty"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Context Analysis*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractSymbolsFromDefinition*)
VerificationTest[
    (* Note: List is also extracted as it's the head of the expression *)
    $testSymbols = Wolfram`AgentTools`Tools`SymbolDefinition`Private`extractSymbolsFromDefinition[
        { Plus, Times, Map }
    ],
    { HoldForm[ List ], HoldForm[ Plus ], HoldForm[ Times ], HoldForm[ Map ] },
    SameTest -> MatchQ,
    TestID   -> "ExtractSymbols"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getContextsFromSymbols*)
VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`getContextsFromSymbols[
        { HoldForm[ Plus ], HoldForm[ Times ], HoldForm[ Map ] }
    ],
    { "System`" },
    SameTest -> MatchQ,
    TestID   -> "GetContexts"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*buildOptimalContextPath*)
VerificationTest[
    $optimalPath = Wolfram`AgentTools`Tools`SymbolDefinition`Private`buildOptimalContextPath[
        { "MyContext`", "AnotherContext`" }
    ],
    _List? (MemberQ[ #, "System`" ] && MemberQ[ #, "Global`" ] &),
    SameTest -> MatchQ,
    TestID   -> "BuildContextPath"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateContextMap*)
VerificationTest[
    $contextMap = Wolfram`AgentTools`Tools`SymbolDefinition`Private`generateContextMap[
        { HoldForm[ Plus ], HoldForm[ Times ] }
    ],
    _String? (StringContainsQ[ #, "System`" ] &),
    SameTest -> MatchQ,
    TestID   -> "GenerateContextMap"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`generateContextMap[ { } ],
    "",
    SameTest -> SameQ,
    TestID   -> "GenerateContextMapEmpty"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Truncation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*truncateIfNeeded*)
VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`truncateIfNeeded[ "Short string", 1000 ],
    "Short string",
    SameTest -> SameQ,
    TestID   -> "Truncate-NoTruncation"
]

VerificationTest[
    $truncated = Wolfram`AgentTools`Tools`SymbolDefinition`Private`truncateIfNeeded[
        StringJoin @ Table[ "x", 500 ],
        100
    ],
    _String? (StringContainsQ[ #, "truncated" ] &),
    SameTest -> MatchQ,
    TestID   -> "Truncate-Applied"
]

VerificationTest[
    StringContainsQ[ $truncated, "100/500" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Truncate-ShowsCharCount"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Error Formatting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatError*)
VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`formatError[ "System`Plus", "Test error message" ],
    "# Plus\n\nError: Test error message",
    SameTest -> SameQ,
    TestID   -> "FormatError-Simple"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`formatError[ "My`Context`Symbol", "Another error" ],
    "# Symbol\n\nError: Another error",
    SameTest -> SameQ,
    TestID   -> "FormatError-Qualified"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Basic Examples*)
VerificationTest[
    (* Quiet suppresses harmless messages about protected symbols during readableForm *)
    $symbolDefResult1 = Quiet @ $symbolDefinitionTool[ <| "symbols" -> "System`Plus" |> ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "BasicSystemSymbol"
]

VerificationTest[
    StringContainsQ[ $symbolDefResult1, "# Plus" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ContainsHeader"
]

VerificationTest[
    StringContainsQ[ $symbolDefResult1, "## Definition" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ContainsDefinitionSection"
]

VerificationTest[
    StringContainsQ[ $symbolDefResult1, "```wl" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ContainsCodeBlock"
]

VerificationTest[
    StringContainsQ[ $symbolDefResult1, "<kernel function>" ],
    True,
    SameTest -> SameQ,
    TestID   -> "KernelCodeDetected"
]

VerificationTest[
    (* Attributes are shown as a list like {Flat, Listable, ...} *)
    StringContainsQ[ $symbolDefResult1, "Flat" ] && StringContainsQ[ $symbolDefResult1, "Protected" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ContainsAttributes"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Unqualified Symbol Names*)

(* Test that unqualified symbol names work through the full tool *)
VerificationTest[
    $unqualifiedResult = Quiet @ $symbolDefinitionTool[ <| "symbols" -> "Plus" |> ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "UnqualifiedSymbol-Plus"
]

VerificationTest[
    StringContainsQ[ $unqualifiedResult, "# Plus" ],
    True,
    SameTest -> SameQ,
    TestID   -> "UnqualifiedSymbol-ContainsHeader"
]

VerificationTest[
    StringContainsQ[ $unqualifiedResult, "## Definition" ],
    True,
    SameTest -> SameQ,
    TestID   -> "UnqualifiedSymbol-ContainsDefinition"
]

(* Test that unqualified symbol name resolves to the correct symbol *)
VerificationTest[
    StringContainsQ[ $unqualifiedResult, "<kernel function>" ],
    True,
    SameTest -> SameQ,
    TestID   -> "UnqualifiedSymbol-KernelFunction"
]

(* Test mixed qualified and unqualified symbol names *)
VerificationTest[
    $mixedQualifiedResult = Quiet @ $symbolDefinitionTool[ <| "symbols" -> "Plus, System`Times" |> ],
    _String? (StringContainsQ[ #, "# Plus" ] && StringContainsQ[ #, "# Times" ] &),
    SameTest -> MatchQ,
    TestID   -> "UnqualifiedSymbol-MixedWithQualified"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Multiple Symbols*)
VerificationTest[
    $symbolDefResult2 = Quiet @ $symbolDefinitionTool[ <| "symbols" -> "System`Plus, System`Times" |> ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "MultipleSymbols"
]

VerificationTest[
    StringContainsQ[ $symbolDefResult2, "# Plus" ] && StringContainsQ[ $symbolDefResult2, "# Times" ],
    True,
    SameTest -> SameQ,
    TestID   -> "MultipleSymbolsHeaders"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Context Details*)
VerificationTest[
    $symbolDefResult3 = Quiet @ $symbolDefinitionTool[ <|
        "symbols" -> "System`Map",
        "includeContextDetails" -> True
    |> ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "WithContextDetails"
]

VerificationTest[
    StringContainsQ[ $symbolDefResult3, "## Contexts" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ContextsSection"
]

VerificationTest[
    $noContextResult = Quiet @ $symbolDefinitionTool[ <|
        "symbols" -> "System`Plus",
        "includeContextDetails" -> False
    |> ],
    _String? (! StringContainsQ[ #, "## Contexts" ] &),
    SameTest -> MatchQ,
    TestID   -> "NoContextDetails"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Error Cases*)
VerificationTest[
    $symbolDefResult4 = Quiet @ $symbolDefinitionTool[ <| "symbols" -> "NonExistent`Symbol12345" |> ],
    _String? (StringContainsQ[ #, "does not exist" ] &),
    SameTest -> MatchQ,
    TestID   -> "NonexistentSymbol"
]

VerificationTest[
    $symbolDefResult5 = Quiet @ $symbolDefinitionTool[ <| "symbols" -> "Invalid!Symbol@Name" |> ],
    _String? (StringContainsQ[ #, "Invalid symbol name" ] &),
    SameTest -> MatchQ,
    TestID   -> "InvalidSymbolName"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Did You Mean Suggestions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*findSuggestions*)
VerificationTest[
    MemberQ[
        Wolfram`AgentTools`Tools`SymbolDefinition`Private`findSuggestions[ "BadContext`Plus" ],
        "System`Plus"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FindSuggestions-Plus"
]

VerificationTest[
    Wolfram`AgentTools`Tools`SymbolDefinition`Private`findSuggestions[ "Nonexistent`NonexistentSymbol98765" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "FindSuggestions-NoMatch"
]

VerificationTest[
    (* Should return fully qualified names *)
    AllTrue[
        Wolfram`AgentTools`Tools`SymbolDefinition`Private`findSuggestions[ "Bad`Map" ],
        StringContainsQ[ #, "`" ] &
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FindSuggestions-FullyQualified"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Integration*)
VerificationTest[
    $didYouMeanResult = Quiet @ $symbolDefinitionTool[ <| "symbols" -> "BadContext`Plus" |> ],
    _String? (
        StringContainsQ[ #, "Did you mean one of the following symbols?" ] &&
        StringContainsQ[ #, "```wl" ] &&
        StringContainsQ[ #, "System`Plus" ] &
    ),
    SameTest -> MatchQ,
    TestID   -> "DidYouMean-ShowsSuggestion"
]

VerificationTest[
    $noSuggestionResult = Quiet @ $symbolDefinitionTool[ <| "symbols" -> "Nonexistent`NoSuchSymbol98765" |> ],
    _String? (StringContainsQ[ #, "does not exist" ] && ! StringContainsQ[ #, "Did you mean" ] &),
    SameTest -> MatchQ,
    TestID   -> "DidYouMean-NoSuggestionWhenNoMatch"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Truncation*)
VerificationTest[
    (* Use a very small maxLength to ensure truncation *)
    $symbolDefResult6 = Quiet @ $symbolDefinitionTool[ <|
        "symbols" -> "System`Table",
        "maxLength" -> 20
    |> ],
    _String? (StringContainsQ[ #, "truncated" ] &),
    SameTest -> MatchQ,
    TestID   -> "Truncation"
]

VerificationTest[
    $customLengthResult = Quiet @ $symbolDefinitionTool[ <|
        "symbols" -> "System`Table",
        "maxLength" -> 50
    |> ],
    _String? (StringContainsQ[ #, "truncated" ] &),
    SameTest -> MatchQ,
    TestID   -> "CustomMaxLength"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Evaluation Leak Prevention*)

(* Test that extractDefinition does not evaluate the RHS of definitions *)
VerificationTest[
    Module[ { counter },
        counter = 0;
        Wolfram`AgentToolsTests`$evalLeakTestSymbol1 := (counter++; "result");
        Wolfram`AgentTools`Tools`SymbolDefinition`Private`extractDefinition[
            "Wolfram`AgentToolsTests`$evalLeakTestSymbol1"
        ];
        (* counter should still be 0 if no evaluation leak occurred *)
        counter
    ],
    0,
    SameTest -> SameQ,
    TestID   -> "EvaluationLeak-ExtractDefinition"
]

(* Test that the full tool does not cause evaluation leaks *)
VerificationTest[
    Module[ { counter },
        counter = 0;
        Wolfram`AgentToolsTests`$evalLeakTestSymbol2 := (counter++; "result");
        Quiet @ $symbolDefinitionTool[ <| "symbols" -> "Wolfram`AgentToolsTests`$evalLeakTestSymbol2" |> ];
        (* counter should still be 0 if no evaluation leak occurred *)
        counter
    ],
    0,
    SameTest -> SameQ,
    TestID   -> "EvaluationLeak-FullTool"
]

(* Test that definitions with side effects are captured correctly without executing them *)
VerificationTest[
    Module[ { result },
        Wolfram`AgentToolsTests`$evalLeakTestSymbol3 := Echo["This should NOT print!"];
        result = Quiet @ $symbolDefinitionTool[ <| "symbols" -> "Wolfram`AgentToolsTests`$evalLeakTestSymbol3" |> ];
        StringContainsQ[ result, "Echo" ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "EvaluationLeak-CapturesDefinition"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attributes Display*)

(* Test that attributes are displayed properly with Attributes[symbol] = ... format *)
VerificationTest[
    $tableResult = Quiet @ $symbolDefinitionTool[ <| "symbols" -> "System`Table" |> ],
    _String? (StringContainsQ[ #, "Attributes" ] &),
    SameTest -> MatchQ,
    TestID   -> "AttributesDisplay-ContainsAttributes"
]

VerificationTest[
    (* The output should show attributes in a proper assignment form, not just a bare list *)
    (* ReadableForm uses // notation: Table // Attributes = {...} *)
    StringContainsQ[ $tableResult, "Attributes" ] && StringContainsQ[ $tableResult, "HoldAll" ],
    True,
    SameTest -> SameQ,
    TestID   -> "AttributesDisplay-ProperFormat"
]

VerificationTest[
    (* Verify that Protected attribute is shown *)
    StringContainsQ[ $tableResult, "Protected" ],
    True,
    SameTest -> SameQ,
    TestID   -> "AttributesDisplay-ShowsProtected"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Integration Tests*)
VerificationTest[
    $subtractResult = Quiet @ $symbolDefinitionTool[ <| "symbols" -> "System`Subtract" |> ],
    _String? (StringContainsQ[ #, "# Subtract" ] && StringContainsQ[ #, "## Definition" ] &),
    SameTest -> MatchQ,
    TestID   -> "Integration-Subtract"
]

VerificationTest[
    (* Subtract should show either WL patterns or kernel function indicator *)
    StringContainsQ[ $subtractResult, "x_" ] ||
    StringContainsQ[ $subtractResult, "y_" ] ||
    StringContainsQ[ $subtractResult, "<kernel function>" ],
    True,
    SameTest -> SameQ,
    TestID   -> "Integration-SubtractHasDefinition"
]

VerificationTest[
    $pacletResult = Quiet @ $symbolDefinitionTool[ <| "symbols" -> "Wolfram`AgentTools`CreateMCPServer" |> ],
    _String? (StringContainsQ[ #, "# CreateMCPServer" ] &),
    SameTest -> MatchQ,
    TestID   -> "Integration-PacletSymbol"
]

VerificationTest[
    (* Use addEnclosureTags which is actually in the Private` context *)
    $privateResult = Quiet @ $symbolDefinitionTool[ <| "symbols" -> "Wolfram`AgentTools`Common`Private`addEnclosureTags" |> ],
    _String? (StringContainsQ[ #, "# addEnclosureTags" ] &),
    SameTest -> MatchQ,
    TestID   -> "Integration-PrivateSymbol"
]

VerificationTest[
    $mixedResult = Quiet @ $symbolDefinitionTool[ <|
        "symbols" -> "System`Plus, NonExistent12345`BadSymbol, Invalid!Name"
    |> ],
    _String? (
        StringContainsQ[ #, "# Plus" ] &&
        StringContainsQ[ #, "does not exist" ] &&
        StringContainsQ[ #, "Invalid symbol name" ] &
    ),
    SameTest -> MatchQ,
    TestID   -> "Integration-MixedSymbols"
]

VerificationTest[
    $contextResult = Quiet @ $symbolDefinitionTool[ <|
        "symbols" -> "System`Plus, System`Map",
        "includeContextDetails" -> True
    |> ],
    _String? (StringContainsQ[ #, "## Contexts" ] && StringContainsQ[ #, "System`" ] &),
    SameTest -> MatchQ,
    TestID   -> "Integration-ContextDetails"
]

(* :!CodeAnalysis::EndBlock:: *)