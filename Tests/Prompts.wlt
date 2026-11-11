(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::Section:: *)
(* Initialization *)

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

(* ::Section:: *)
(* $DefaultMCPPrompts *)

VerificationTest[
    $DefaultMCPPrompts,
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DefaultMCPPrompts-IsAssociation"
]

VerificationTest[
    Sort @ Keys @ $DefaultMCPPrompts,
    { "Notebook", "WolframAlphaSearch", "WolframLanguageSearch", "WolframSearch" },
    SameTest -> SameQ,
    TestID   -> "DefaultMCPPrompts-Keys"
]

VerificationTest[
    AllTrue[ Values @ $DefaultMCPPrompts, AssociationQ ],
    True,
    SameTest -> SameQ,
    TestID   -> "DefaultMCPPrompts-AllAssociations"
]

(* ::Section:: *)
(* Prompt Properties *)

VerificationTest[
    AllTrue[ $DefaultMCPPrompts, StringQ @ #[ "Name" ] & ],
    True,
    SameTest -> SameQ,
    TestID   -> "PromptProperties-AllHaveNames"
]

VerificationTest[
    AllTrue[ $DefaultMCPPrompts, StringQ @ #[ "Description" ] & ],
    True,
    SameTest -> SameQ,
    TestID   -> "PromptProperties-AllHaveDescriptions"
]

VerificationTest[
    AllTrue[ $DefaultMCPPrompts, MemberQ[ { "Function", "Text" }, #[ "Type" ] ] & ],
    True,
    SameTest -> SameQ,
    TestID   -> "PromptProperties-AllHaveValidType"
]

VerificationTest[
    AllTrue[ $DefaultMCPPrompts, MatchQ[ #[ "Arguments" ], { ___Association } ] & ],
    True,
    SameTest -> SameQ,
    TestID   -> "PromptProperties-AllHaveArguments"
]

VerificationTest[
    AllTrue[ $DefaultMCPPrompts, MatchQ[ #[ "Content" ], _Symbol | _Function ] & ],
    True,
    SameTest -> MatchQ,
    TestID   -> "PromptProperties-AllHaveContent"
]

(* ::Section:: *)
(* MCP Name Mapping *)

VerificationTest[
    Union @ Map[ #[ "Name" ] &, Values @ $DefaultMCPPrompts ],
    { "Notebook", "Search" },
    SameTest -> SameQ,
    TestID   -> "MCPNameMapping-PromptNames"
]

(* ::Section:: *)
(* Individual Prompt Definitions *)

VerificationTest[
    $DefaultMCPPrompts[ "WolframSearch" ][ "Name" ],
    "Search",
    SameTest -> SameQ,
    TestID   -> "WolframSearch-HasCorrectName"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframSearch" ][ "Type" ],
    "Function",
    SameTest -> SameQ,
    TestID   -> "WolframSearch-HasCorrectType"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframLanguageSearch" ][ "Name" ],
    "Search",
    SameTest -> SameQ,
    TestID   -> "WolframLanguageSearch-HasCorrectName"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframLanguageSearch" ][ "Type" ],
    "Function",
    SameTest -> SameQ,
    TestID   -> "WolframLanguageSearch-HasCorrectType"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframAlphaSearch" ][ "Name" ],
    "Search",
    SameTest -> SameQ,
    TestID   -> "WolframAlphaSearch-HasCorrectName"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframAlphaSearch" ][ "Type" ],
    "Function",
    SameTest -> SameQ,
    TestID   -> "WolframAlphaSearch-HasCorrectType"
]

VerificationTest[
    $DefaultMCPPrompts[ "Notebook" ][ "Name" ],
    "Notebook",
    SameTest -> SameQ,
    TestID   -> "Notebook-HasCorrectName"
]

VerificationTest[
    $DefaultMCPPrompts[ "Notebook" ][ "Type" ],
    "Function",
    SameTest -> SameQ,
    TestID   -> "Notebook-HasCorrectType"
]

VerificationTest[
    $DefaultMCPPrompts[ "Notebook" ][ "Arguments" ],
    { KeyValuePattern @ { "Name" -> "path", "Required" -> True } },
    SameTest -> MatchQ,
    TestID   -> "Notebook-HasPathArgument"
]

(* ::Section:: *)
(* Argument Specifications *)

VerificationTest[
    $DefaultMCPPrompts[ "WolframSearch" ][ "Arguments" ],
    { KeyValuePattern @ { "Name" -> "query", "Required" -> True } },
    SameTest -> MatchQ,
    TestID   -> "WolframSearch-HasQueryArgument"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframLanguageSearch" ][ "Arguments" ],
    { KeyValuePattern @ { "Name" -> "query", "Required" -> True } },
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageSearch-HasQueryArgument"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframAlphaSearch" ][ "Arguments" ],
    { KeyValuePattern @ { "Name" -> "query", "Required" -> True } },
    SameTest -> MatchQ,
    TestID   -> "WolframAlphaSearch-HasQueryArgument"
]

(* ::Section:: *)
(* Validation Functions *)

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompts[ "WolframSearch" ],
    { "WolframSearch" },
    SameTest -> SameQ,
    TestID   -> "ValidateMCPPrompts-SingleString"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompts[ { "WolframSearch", "WolframLanguageSearch" } ],
    { "WolframSearch", "WolframLanguageSearch" },
    SameTest -> SameQ,
    TestID   -> "ValidateMCPPrompts-ListOfStrings"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompts[ { <| "Name" -> "Custom" |> } ],
    { <| "Name" -> "Custom" |> },
    SameTest -> SameQ,
    TestID   -> "ValidateMCPPrompts-InlineAssociation"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompts[ { "WolframSearch", <| "Name" -> "Custom" |> } ],
    { "WolframSearch", <| "Name" -> "Custom" |> },
    SameTest -> SameQ,
    TestID   -> "ValidateMCPPrompts-MixedList"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompts[ "NonExistentPrompt" ],
    _Failure,
    { AgentTools::PromptNameNotFound, AgentTools::InvalidMCPPromptsSpecification },
    SameTest -> MatchQ,
    TestID   -> "ValidateMCPPrompts-InvalidName"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompts[ 123 ],
    _Failure,
    { AgentTools::InvalidMCPPromptsSpecification },
    SameTest -> MatchQ,
    TestID   -> "ValidateMCPPrompts-InvalidType"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompt[ "WolframSearch" ],
    "WolframSearch",
    SameTest -> SameQ,
    TestID   -> "ValidateMCPPrompt-ValidString"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompt[ <| "Name" -> "Custom" |> ],
    <| "Name" -> "Custom" |>,
    SameTest -> SameQ,
    TestID   -> "ValidateMCPPrompt-Association"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompt[ "NonExistent" ],
    _Failure,
    { AgentTools::PromptNameNotFound },
    SameTest -> MatchQ,
    TestID   -> "ValidateMCPPrompt-InvalidName"
]

(* ::Section:: *)
(* normalizePromptData *)

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`normalizePromptData[ "WolframSearch" ],
    $DefaultMCPPrompts[ "WolframSearch" ],
    SameTest -> SameQ,
    TestID   -> "NormalizePromptData-StringLookup"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`normalizePromptData[ <| "Name" -> "Test", "Content" -> "Static text" |> ],
    <| "Name" -> "Test", "Content" -> "Static text", "Type" -> "Text" |>,
    SameTest -> SameQ,
    TestID   -> "NormalizePromptData-TextType"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`normalizePromptData[ <| "Name" -> "Test", "Content" -> Function[ x, x ] |> ],
    KeyValuePattern[ "Type" -> "Function" ],
    SameTest -> MatchQ,
    TestID   -> "NormalizePromptData-FunctionType"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`normalizePromptData[ "NonExistent" ],
    _Failure,
    { AgentTools::PromptNameNotFound },
    SameTest -> MatchQ,
    TestID   -> "NormalizePromptData-InvalidName"
]

(* ::Section:: *)
(* determinePromptType *)

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`determinePromptType[ <| "Type" -> "Function" |> ],
    "Function",
    SameTest -> SameQ,
    TestID   -> "DeterminePromptType-ExplicitFunction"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`determinePromptType[ <| "Type" -> "Text" |> ],
    "Text",
    SameTest -> SameQ,
    TestID   -> "DeterminePromptType-ExplicitText"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`determinePromptType[ <| "Content" -> "Some string" |> ],
    "Text",
    SameTest -> SameQ,
    TestID   -> "DeterminePromptType-StringContent"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`determinePromptType[ <| "Content" -> Identity |> ],
    "Function",
    SameTest -> SameQ,
    TestID   -> "DeterminePromptType-FunctionContent"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`determinePromptType[ <| |> ],
    "Text",
    SameTest -> SameQ,
    TestID   -> "DeterminePromptType-EmptyDefault"
]

(* ::Section:: *)
(* MCPServerObject PromptData Property *)

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`getPromptData[
        <| "LLMEvaluator" -> <| "MCPPrompts" -> { "WolframSearch" } |> |>
    ],
    { $DefaultMCPPrompts[ "WolframSearch" ] },
    SameTest -> SameQ,
    TestID   -> "GetPromptData-WithMCPPrompts"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`getPromptData[
        <| "LLMEvaluator" -> <| |> |>
    ],
    { },
    SameTest -> SameQ,
    TestID   -> "GetPromptData-NoPrompts"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`getPromptData[
        <| "LLMEvaluator" -> <| "MCPPrompts" -> { "WolframSearch", "WolframLanguageSearch" } |> |>
    ],
    { $DefaultMCPPrompts[ "WolframSearch" ], $DefaultMCPPrompts[ "WolframLanguageSearch" ] },
    SameTest -> SameQ,
    TestID   -> "GetPromptData-MultiplePrompts"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`getPromptData[
        <| "LLMEvaluator" -> <| "MCPPrompts" -> { <| "Name" -> "Custom", "Content" -> "Test" |> } |> |>
    ],
    { <| "Name" -> "Custom", "Content" -> "Test", "Type" -> "Text" |> },
    SameTest -> SameQ,
    TestID   -> "GetPromptData-InlinePrompt"
]

(* ::Section:: *)
(* Deprecation Warning *)

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`getPromptData[
        <| "LLMEvaluator" -> <| "PromptData" -> { <| "Name" -> "Test" |> } |> |>
    ],
    _Failure,
    { AgentTools::DeprecatedPromptData },
    SameTest -> MatchQ,
    TestID   -> "GetPromptData-DeprecatedPromptDataFails"
]

(* ::Section:: *)
(* makePromptContent (Phase 3) *)

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        <| "Type" -> "Function", "Content" -> Function[ args, "Result: " <> args[ "query" ] ] |>,
        <| "query" -> "test" |>
    ],
    <| "type" -> "text", "text" -> "Result: test" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-FunctionType"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        <| "Type" -> "Text", "Content" -> "Static content" |>,
        <| |>
    ],
    <| "type" -> "text", "text" -> "Static content" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-TextType"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        <| "Content" -> "No explicit type" |>,
        <| |>
    ],
    <| "type" -> "text", "text" -> "No explicit type" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-NoExplicitType"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        <| "Content" -> StringTemplate[ "Hello, `name`!" ] |>,
        <| "name" -> "World" |>
    ],
    <| "type" -> "text", "text" -> "Hello, World!" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-StringTemplate"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        "Plain string",
        <| |>
    ],
    <| "type" -> "text", "text" -> "Plain string" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-PlainString"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        12345,
        <| |>
    ],
    <| "type" -> "text", "text" -> "12345" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-Fallback"
]

(* ::Section:: *)
(* consolidateTextContent *)

(* Text-only arrays should be consolidated into a single text object *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`consolidateTextContent[
        {
            <| "type" -> "text", "text" -> "Hello " |>,
            <| "type" -> "text", "text" -> "World!" |>
        }
    ],
    <| "type" -> "text", "text" -> "Hello World!" |>,
    SameTest -> SameQ,
    TestID   -> "ConsolidateTextContent-TextOnly"
]

(* Single text item should be consolidated to object *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`consolidateTextContent[
        { <| "type" -> "text", "text" -> "Single" |> }
    ],
    <| "type" -> "text", "text" -> "Single" |>,
    SameTest -> SameQ,
    TestID   -> "ConsolidateTextContent-SingleText"
]

(* Arrays with non-text items (images) should have text extracted, images dropped *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`consolidateTextContent[
        {
            <| "type" -> "text", "text" -> "Description: " |>,
            <| "type" -> "image", "data" -> "base64data", "mimeType" -> "image/png" |>
        }
    ],
    <| "type" -> "text", "text" -> "Description: " |>,
    SameTest -> SameQ,
    TestID   -> "ConsolidateTextContent-WithImage"
]

(* makePromptContent should use consolidateTextContent for arrays *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        {
            <| "type" -> "text", "text" -> "Part 1 " |>,
            <| "type" -> "text", "text" -> "Part 2" |>
        },
        <| |>
    ],
    <| "type" -> "text", "text" -> "Part 1 Part 2" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-ConsolidatesTextArray"
]

(* makePromptContent with Content key containing array *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        <| "Content" -> {
            <| "type" -> "text", "text" -> "A" |>,
            <| "type" -> "text", "text" -> "B" |>
        } |>,
        <| |>
    ],
    <| "type" -> "text", "text" -> "AB" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-ContentKeyConsolidatesText"
]

(* ::Section:: *)
(* makePromptData (Phase 3) *)

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptData[ {
        <| "Name" -> "Test", "Description" -> "A test prompt" |>
    } ],
    { <| "name" -> "Test", "description" -> "A test prompt" |> },
    SameTest -> SameQ,
    TestID   -> "MakePromptData-CapitalizedKeys"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptData[ {
        <| "name" -> "Test", "description" -> "A test prompt" |>
    } ],
    { <| "name" -> "Test", "description" -> "A test prompt" |> },
    SameTest -> SameQ,
    TestID   -> "MakePromptData-LowercaseKeys"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptData[ {
        <|
            "Name" -> "Test",
            "Description" -> "A test prompt",
            "Arguments" -> {
                <| "Name" -> "arg1", "Description" -> "First arg", "Required" -> True |>
            }
        |>
    } ],
    {
        <|
            "name" -> "Test",
            "description" -> "A test prompt",
            "arguments" -> {
                <| "name" -> "arg1", "description" -> "First arg", "required" -> True |>
            }
        |>
    },
    SameTest -> SameQ,
    TestID   -> "MakePromptData-WithArguments"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptData[ {
        <| "Name" -> "NoArgs" |>
    } ],
    { <| "name" -> "NoArgs", "description" -> "" |> },
    SameTest -> SameQ,
    TestID   -> "MakePromptData-NoArguments"
]

(* ::Section:: *)
(* normalizeArguments (Phase 3) *)

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`normalizeArguments[ {
        <| "Name" -> "query", "Description" -> "The search query", "Required" -> True |>
    } ],
    { <| "name" -> "query", "description" -> "The search query", "required" -> True |> },
    SameTest -> SameQ,
    TestID   -> "NormalizeArguments-CapitalizedKeys"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`normalizeArguments[ {
        <| "name" -> "query", "description" -> "The search query", "required" -> True |>
    } ],
    { <| "name" -> "query", "description" -> "The search query", "required" -> True |> },
    SameTest -> SameQ,
    TestID   -> "NormalizeArguments-LowercaseKeys"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`normalizeArguments[ {
        <| "Name" -> "arg1" |>,
        <| "Name" -> "arg2", "Required" -> False |>
    } ],
    {
        <| "name" -> "arg1", "description" -> "", "required" -> False |>,
        <| "name" -> "arg2", "description" -> "", "required" -> False |>
    },
    SameTest -> SameQ,
    TestID   -> "NormalizeArguments-MultipleWithDefaults"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`normalizeArguments[ { } ],
    { },
    SameTest -> SameQ,
    TestID   -> "NormalizeArguments-Empty"
]

(* ::Section:: *)
(* normalizeArgument (Phase 3) *)

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`normalizeArgument[
        <| "Name" -> "query", "Description" -> "The query", "Required" -> True |>
    ],
    <| "name" -> "query", "description" -> "The query", "required" -> True |>,
    SameTest -> SameQ,
    TestID   -> "NormalizeArgument-AllFields"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`normalizeArgument[
        <| "Name" -> "query" |>
    ],
    <| "name" -> "query", "description" -> "", "required" -> False |>,
    SameTest -> SameQ,
    TestID   -> "NormalizeArgument-DefaultValues"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`normalizeArgument[
        <| "name" -> "query", "description" -> "Lowercase keys", "required" -> True |>
    ],
    <| "name" -> "query", "description" -> "Lowercase keys", "required" -> True |>,
    SameTest -> SameQ,
    TestID   -> "NormalizeArgument-LowercaseKeys"
]

(* ::Section:: *)
(* Server Configuration (Phase 4) *)

VerificationTest[
    $DefaultMCPServers[ "Wolfram" ][ "MCPPrompts" ],
    { "WolframSearch" },
    SameTest -> SameQ,
    TestID   -> "ServerConfig-WolframHasMCPPrompts"
]

VerificationTest[
    $DefaultMCPServers[ "WolframAlpha" ][ "MCPPrompts" ],
    { "WolframAlphaSearch" },
    SameTest -> SameQ,
    TestID   -> "ServerConfig-WolframAlphaHasMCPPrompts"
]

VerificationTest[
    $DefaultMCPServers[ "WolframLanguage" ][ "MCPPrompts" ],
    { "WolframLanguageSearch", "Notebook" },
    SameTest -> SameQ,
    TestID   -> "ServerConfig-WolframLanguageHasMCPPrompts"
]

VerificationTest[
    $DefaultMCPServers[ "WolframPacletDevelopment" ][ "MCPPrompts" ],
    { "WolframLanguageSearch", "Notebook" },
    SameTest -> SameQ,
    TestID   -> "ServerConfig-WolframPacletDevelopmentHasMCPPrompts"
]

(* ::Subsection:: *)
(* Server PromptData Property *)

VerificationTest[
    MCPServerObject[ "Wolfram" ][ "PromptData" ],
    { KeyValuePattern[ "Name" -> "Search" ] },
    SameTest -> MatchQ,
    TestID   -> "ServerPromptData-Wolfram"
]

VerificationTest[
    MCPServerObject[ "WolframAlpha" ][ "PromptData" ],
    { KeyValuePattern[ "Name" -> "Search" ] },
    SameTest -> MatchQ,
    TestID   -> "ServerPromptData-WolframAlpha"
]

VerificationTest[
    MCPServerObject[ "WolframLanguage" ][ "PromptData" ],
    { KeyValuePattern[ "Name" -> "Search" ], KeyValuePattern[ "Name" -> "Notebook" ] },
    SameTest -> MatchQ,
    TestID   -> "ServerPromptData-WolframLanguage"
]

VerificationTest[
    MCPServerObject[ "WolframPacletDevelopment" ][ "PromptData" ],
    { KeyValuePattern[ "Name" -> "Search" ], KeyValuePattern[ "Name" -> "Notebook" ] },
    SameTest -> MatchQ,
    TestID   -> "ServerPromptData-WolframPacletDevelopment"
]

(* ::Subsection:: *)
(* All Servers Have Correct Prompt Type *)

VerificationTest[
    AllTrue[
        { "Wolfram", "WolframAlpha", "WolframLanguage", "WolframPacletDevelopment" },
        Function[ name,
            MatchQ[
                MCPServerObject[ name ][ "PromptData" ],
                { KeyValuePattern[ "Type" -> "Function" ]... }
            ]
        ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "ServerPromptData-AllHaveFunctionType"
]

(* ::Subsection:: *)
(* Prompt Names Match Across Servers *)

VerificationTest[
    Union @ Flatten @ Map[
        Function[ name, #[ "Name" ] & /@ MCPServerObject[ name ][ "PromptData" ] ],
        { "Wolfram", "WolframAlpha", "WolframLanguage", "WolframPacletDevelopment" }
    ],
    { "Notebook", "Search" },
    SameTest -> SameQ,
    TestID   -> "ServerPromptData-PromptNames"
]

(* ::Section:: *)
(* Error Handling (Phase 5) *)

(* ::Subsection:: *)
(* catchPromptFunction *)

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`catchPromptFunction[
        Function[ args, "Success: " <> args[ "query" ] ],
        <| "query" -> "test" |>
    ],
    "Success: test",
    SameTest -> SameQ,
    TestID   -> "CatchPromptFunction-Success"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`catchPromptFunction[
        Function[ args, Failure[ "TestError", <| "MessageTemplate" -> "Something went wrong" |> ] ],
        <| "query" -> "test" |>
    ],
    "[Error] Something went wrong",
    SameTest -> SameQ,
    TestID   -> "CatchPromptFunction-ReturnsFailure"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`catchPromptFunction[
        Function[ args, Wolfram`AgentTools`Common`throwFailure[ "InvalidArguments", AgentTools, "test" ] ],
        <| "query" -> "test" |>
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "CatchPromptFunction-ThrowsFailure"
]

(* ::Subsection:: *)
(* formatPromptError *)

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`formatPromptError[
        Failure[ "TestError", <| "MessageTemplate" -> "Test message" |> ]
    ],
    "[Error] Test message",
    SameTest -> SameQ,
    TestID   -> "FormatPromptError-WithMessage"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`formatPromptError[
        Failure[ "TestError", <| "MessageTemplate" -> "Bad value: `1`", "MessageParameters" -> { "x" } |> ]
    ],
    "[Error] Bad value: x",
    SameTest -> SameQ,
    TestID   -> "FormatPromptError-WithParameters-GH#271"
]

VerificationTest[
    StringMatchQ[
        Wolfram`AgentTools`Server`Shared`Private`formatPromptError[
            Failure[ "TestError", <| |> ]
        ],
        "[Error] " ~~ __
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatPromptError-NoMessage"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`formatPromptError[ "not a failure" ],
    "[Error] Failed to generate prompt content.",
    SameTest -> SameQ,
    TestID   -> "FormatPromptError-NonFailure"
]

(* ::Subsection:: *)
(* makePromptContent with Error Handling *)

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        <| "Type" -> "Function", "Content" -> Function[ args, Failure[ "TestError", <| "MessageTemplate" -> "Function failed" |> ] ] |>,
        <| "query" -> "test" |>
    ],
    <| "type" -> "text", "text" -> "[Error] Function failed" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-FunctionReturnsFailure"
]

VerificationTest[
    StringQ @ Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        <| "Type" -> "Function", "Content" -> Function[ args, Wolfram`AgentTools`Common`throwFailure[ "InvalidArguments", AgentTools, "test" ] ] |>,
        <| "query" -> "test" |>
    ][ "text" ],
    True,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-FunctionThrowsFailure"
]

(* ::Section:: *)
(* Prompt Format (Phase 6) *)

(* ::Subsection:: *)
(* formatSearchPrompt *)

VerificationTest[
    Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "test query", "some results" ],
    "<search-query>test query</search-query>\n<search-results>\nsome results\n</search-results>\nUse the above search results to answer the user's query below.\n<user-query>test query</user-query>",
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-BasicOutput"
]

VerificationTest[
    StringQ @ Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "query", "results" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-ReturnsString"
]

VerificationTest[
    StringContainsQ[
        Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "my query", "my results" ],
        "<search-query>my query</search-query>"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-ContainsSearchQueryTag"
]

VerificationTest[
    StringContainsQ[
        Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "my query", "my results" ],
        "<search-results>\nmy results\n</search-results>"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-ContainsSearchResultsTag"
]

VerificationTest[
    StringContainsQ[
        Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "my query", "my results" ],
        "<user-query>my query</user-query>"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-ContainsUserQueryTag"
]

VerificationTest[
    StringCount[
        Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "duplicated", "results" ],
        "duplicated"
    ],
    2,
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-QueryAppearsInBothTags"
]

VerificationTest[
    StringContainsQ[
        Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "test", "test" ],
        "Use the above search results to answer the user's query below."
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-ContainsInstructionalText"
]

(* ::Subsection:: *)
(* Format Used by Search Prompts *)

(* Skip these in GitHub Actions due to an issue with wolframscript hanging when checking the license server during
   tests that potentially spend a long time downloading files. *)
skipIfGitHubActions @ VerificationTest[
    $wolframSearchPromptOutput = $DefaultMCPPrompts[ "WolframSearch" ][ "Content" ][ <| "query" -> "test query" |> ],
    _String | { KeyValuePattern[ "type" -> "text" ], ___ },
    SameTest -> MatchQ,
    TestID   -> "WolframSearch-ReturnsValidOutput"
]

skipIfGitHubActions @ VerificationTest[
    With[ { output = $wolframSearchPromptOutput },
        If[ StringQ @ output,
            StringContainsQ[ output, "<search-query>test query</search-query>" ],
            (* Multimodal: check first text content item *)
            StringContainsQ[ First[ output ][ "text" ], "<search-query>test query</search-query>" ]
        ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframSearch-UsesNewFormat"
]

skipIfGitHubActions @ VerificationTest[
    $wlSearchPromptOutput = $DefaultMCPPrompts[ "WolframLanguageSearch" ][ "Content" ][ <| "query" -> "test query" |> ],
    _String | { KeyValuePattern[ "type" -> "text" ], ___ },
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageSearch-ReturnsValidOutput"
]

skipIfGitHubActions @ VerificationTest[
    With[ { output = $wlSearchPromptOutput },
        If[ StringQ @ output,
            StringContainsQ[ output, "<search-query>test query</search-query>" ],
            (* Multimodal: check first text content item *)
            StringContainsQ[ First[ output ][ "text" ], "<search-query>test query</search-query>" ]
        ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframLanguageSearch-UsesNewFormat"
]

skipIfGitHubActions @ VerificationTest[
    $waSearchPromptOutput = $DefaultMCPPrompts[ "WolframAlphaSearch" ][ "Content" ][ <| "query" -> "test query" |> ],
    _String | { KeyValuePattern[ "type" -> "text" ], ___ },
    SameTest -> MatchQ,
    TestID   -> "WolframAlphaSearch-ReturnsValidOutput"
]

skipIfGitHubActions @ VerificationTest[
    With[ { output = $waSearchPromptOutput },
        If[ StringQ @ output,
            StringContainsQ[ output, "<search-query>test query</search-query>" ],
            (* Multimodal: check first text content item *)
            StringContainsQ[ First[ output ][ "text" ], "<search-query>test query</search-query>" ]
        ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "WolframAlphaSearch-UsesNewFormat"
]

(* ::Subsection:: *)
(* formatNotebookPrompt *)

VerificationTest[
    Wolfram`AgentTools`Prompts`Notebook`Private`formatNotebookPrompt[ "/path/to/file.nb", "# Heading\n\nContent" ],
    "<notebook-path>/path/to/file.nb</notebook-path>\n<notebook-content>\n# Heading\n\nContent\n</notebook-content>",
    SameTest -> SameQ,
    TestID   -> "FormatNotebookPrompt-BasicOutput"
]

VerificationTest[
    StringQ @ Wolfram`AgentTools`Prompts`Notebook`Private`formatNotebookPrompt[ "/path/to/file.nb", "content" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatNotebookPrompt-ReturnsString"
]

VerificationTest[
    StringContainsQ[
        Wolfram`AgentTools`Prompts`Notebook`Private`formatNotebookPrompt[ "/my/path.nb", "my content" ],
        "<notebook-path>/my/path.nb</notebook-path>"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatNotebookPrompt-ContainsPathTag"
]

VerificationTest[
    StringContainsQ[
        Wolfram`AgentTools`Prompts`Notebook`Private`formatNotebookPrompt[ "/my/path.nb", "my content" ],
        "<notebook-content>\nmy content\n</notebook-content>"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatNotebookPrompt-ContainsContentTag"
]

(* ::Subsection:: *)
(* Multimodal Content Support *)

(* Multimodal content arrays are consolidated to single text object, images dropped *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        { <| "type" -> "text", "text" -> "hello" |>, <| "type" -> "image", "data" -> "abc", "mimeType" -> "image/png" |> },
        <| |>
    ],
    <| "type" -> "text", "text" -> "hello" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-ContentArray"
]

(* Structured content with Content key is also consolidated *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        <| "Content" -> { <| "type" -> "text", "text" -> "hello" |> } |>,
        <| |>
    ],
    <| "type" -> "text", "text" -> "hello" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-StructuredContent"
]

VerificationTest[
    Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[
        "test query",
        <| "Content" -> {
            <| "type" -> "text", "text" -> "some results" |>,
            <| "type" -> "image", "data" -> "base64data", "mimeType" -> "image/png" |>
        } |>
    ],
    {
        KeyValuePattern[ { "type" -> "text", "text" -> _? (StringContainsQ[ "test query" ]) } ],
        KeyValuePattern[ { "type" -> "image", "data" -> "base64data" } ]
    },
    SameTest -> MatchQ,
    TestID   -> "FormatSearchPrompt-MultimodalContent"
]

VerificationTest[
    Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[
        "my query",
        <| "Content" -> {
            <| "type" -> "text", "text" -> "text results" |>
        } |>
    ],
    { KeyValuePattern[ { "type" -> "text", "text" -> _? (StringContainsQ[ "my query" ]) } ] },
    SameTest -> MatchQ,
    TestID   -> "FormatSearchPrompt-MultimodalTextOnly"
]

VerificationTest[
    Length @ Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[
        "query",
        <| "Content" -> {
            <| "type" -> "text", "text" -> "results" |>,
            <| "type" -> "image", "data" -> "img1", "mimeType" -> "image/png" |>,
            <| "type" -> "image", "data" -> "img2", "mimeType" -> "image/png" |>
        } |>
    ],
    3,
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-MultimodalMultipleImages"
]

(* ::Subsection:: *)
(* Notebook Prompt Error Handling *)

VerificationTest[
    StringMatchQ[
        $DefaultMCPPrompts[ "Notebook" ][ "Content" ][ <| "path" -> "/nonexistent/path.nb" |> ],
        "[Error] File does not exist: /nonexistent/path.nb"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "NotebookPrompt-NonexistentFile"
]

VerificationTest[
    StringMatchQ[
        $DefaultMCPPrompts[ "Notebook" ][ "Content" ][ <| "path" -> "/path/to/file.txt" |> ],
        "[Error] File is not a notebook (.nb): /path/to/file.txt"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "NotebookPrompt-InvalidExtension"
]

(* :!CodeAnalysis::EndBlock:: *)
