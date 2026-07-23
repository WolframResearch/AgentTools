(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::Section:: *)
(* Initialization *)

VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Prompts.wlt:7,1-12,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Prompts.wlt:14,1-19,2"
]

(* ::Section:: *)
(* $DefaultMCPPrompts *)

VerificationTest[
    $DefaultMCPPrompts,
    _Association? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "DefaultMCPPrompts-IsAssociation@@Tests/Prompts.wlt:24,1-29,2"
]

VerificationTest[
    Sort @ Keys @ $DefaultMCPPrompts,
    { "Notebook", "WolframAlphaSearch", "WolframLanguageSearch", "WolframSearch" },
    SameTest -> SameQ,
    TestID   -> "DefaultMCPPrompts-Keys@@Tests/Prompts.wlt:31,1-36,2"
]

VerificationTest[
    AllTrue[ Values @ $DefaultMCPPrompts, AssociationQ ],
    True,
    SameTest -> SameQ,
    TestID   -> "DefaultMCPPrompts-AllAssociations@@Tests/Prompts.wlt:38,1-43,2"
]

(* ::Section:: *)
(* Prompt Properties *)

VerificationTest[
    AllTrue[ $DefaultMCPPrompts, StringQ @ #[ "Name" ] & ],
    True,
    SameTest -> SameQ,
    TestID   -> "PromptProperties-AllHaveNames@@Tests/Prompts.wlt:48,1-53,2"
]

VerificationTest[
    AllTrue[ $DefaultMCPPrompts, StringQ @ #[ "Description" ] & ],
    True,
    SameTest -> SameQ,
    TestID   -> "PromptProperties-AllHaveDescriptions@@Tests/Prompts.wlt:55,1-60,2"
]

VerificationTest[
    AllTrue[ $DefaultMCPPrompts, MemberQ[ { "Function", "Text" }, #[ "Type" ] ] & ],
    True,
    SameTest -> SameQ,
    TestID   -> "PromptProperties-AllHaveValidType@@Tests/Prompts.wlt:62,1-67,2"
]

VerificationTest[
    AllTrue[ $DefaultMCPPrompts, MatchQ[ #[ "Arguments" ], { ___Association } ] & ],
    True,
    SameTest -> SameQ,
    TestID   -> "PromptProperties-AllHaveArguments@@Tests/Prompts.wlt:69,1-74,2"
]

VerificationTest[
    AllTrue[ $DefaultMCPPrompts, MatchQ[ #[ "Content" ], _Symbol | _Function ] & ],
    True,
    SameTest -> MatchQ,
    TestID   -> "PromptProperties-AllHaveContent@@Tests/Prompts.wlt:76,1-81,2"
]

(* ::Section:: *)
(* MCP Name Mapping *)

VerificationTest[
    Union @ Map[ #[ "Name" ] &, Values @ $DefaultMCPPrompts ],
    { "Notebook", "Search" },
    SameTest -> SameQ,
    TestID   -> "MCPNameMapping-PromptNames@@Tests/Prompts.wlt:86,1-91,2"
]

(* ::Section:: *)
(* Individual Prompt Definitions *)

VerificationTest[
    $DefaultMCPPrompts[ "WolframSearch" ][ "Name" ],
    "Search",
    SameTest -> SameQ,
    TestID   -> "WolframSearch-HasCorrectName@@Tests/Prompts.wlt:96,1-101,2"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframSearch" ][ "Type" ],
    "Function",
    SameTest -> SameQ,
    TestID   -> "WolframSearch-HasCorrectType@@Tests/Prompts.wlt:103,1-108,2"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframLanguageSearch" ][ "Name" ],
    "Search",
    SameTest -> SameQ,
    TestID   -> "WolframLanguageSearch-HasCorrectName@@Tests/Prompts.wlt:110,1-115,2"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframLanguageSearch" ][ "Type" ],
    "Function",
    SameTest -> SameQ,
    TestID   -> "WolframLanguageSearch-HasCorrectType@@Tests/Prompts.wlt:117,1-122,2"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframAlphaSearch" ][ "Name" ],
    "Search",
    SameTest -> SameQ,
    TestID   -> "WolframAlphaSearch-HasCorrectName@@Tests/Prompts.wlt:124,1-129,2"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframAlphaSearch" ][ "Type" ],
    "Function",
    SameTest -> SameQ,
    TestID   -> "WolframAlphaSearch-HasCorrectType@@Tests/Prompts.wlt:131,1-136,2"
]

VerificationTest[
    $DefaultMCPPrompts[ "Notebook" ][ "Name" ],
    "Notebook",
    SameTest -> SameQ,
    TestID   -> "Notebook-HasCorrectName@@Tests/Prompts.wlt:138,1-143,2"
]

VerificationTest[
    $DefaultMCPPrompts[ "Notebook" ][ "Type" ],
    "Function",
    SameTest -> SameQ,
    TestID   -> "Notebook-HasCorrectType@@Tests/Prompts.wlt:145,1-150,2"
]

VerificationTest[
    $DefaultMCPPrompts[ "Notebook" ][ "Arguments" ],
    { KeyValuePattern @ { "Name" -> "path", "Required" -> True } },
    SameTest -> MatchQ,
    TestID   -> "Notebook-HasPathArgument@@Tests/Prompts.wlt:152,1-157,2"
]

(* ::Section:: *)
(* Argument Specifications *)

VerificationTest[
    $DefaultMCPPrompts[ "WolframSearch" ][ "Arguments" ],
    { KeyValuePattern @ { "Name" -> "query", "Required" -> True } },
    SameTest -> MatchQ,
    TestID   -> "WolframSearch-HasQueryArgument@@Tests/Prompts.wlt:162,1-167,2"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframLanguageSearch" ][ "Arguments" ],
    { KeyValuePattern @ { "Name" -> "query", "Required" -> True } },
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageSearch-HasQueryArgument@@Tests/Prompts.wlt:169,1-174,2"
]

VerificationTest[
    $DefaultMCPPrompts[ "WolframAlphaSearch" ][ "Arguments" ],
    { KeyValuePattern @ { "Name" -> "query", "Required" -> True } },
    SameTest -> MatchQ,
    TestID   -> "WolframAlphaSearch-HasQueryArgument@@Tests/Prompts.wlt:176,1-181,2"
]

(* ::Section:: *)
(* Validation Functions *)

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompts[ "WolframSearch" ],
    { "WolframSearch" },
    SameTest -> SameQ,
    TestID   -> "ValidateMCPPrompts-SingleString@@Tests/Prompts.wlt:186,1-191,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompts[ { "WolframSearch", "WolframLanguageSearch" } ],
    { "WolframSearch", "WolframLanguageSearch" },
    SameTest -> SameQ,
    TestID   -> "ValidateMCPPrompts-ListOfStrings@@Tests/Prompts.wlt:193,1-198,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompts[ { <| "Name" -> "Custom" |> } ],
    { <| "Name" -> "Custom" |> },
    SameTest -> SameQ,
    TestID   -> "ValidateMCPPrompts-InlineAssociation@@Tests/Prompts.wlt:200,1-205,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompts[ { "WolframSearch", <| "Name" -> "Custom" |> } ],
    { "WolframSearch", <| "Name" -> "Custom" |> },
    SameTest -> SameQ,
    TestID   -> "ValidateMCPPrompts-MixedList@@Tests/Prompts.wlt:207,1-212,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompts[ "NonExistentPrompt" ],
    _Failure,
    { AgentTools::PromptNameNotFound, AgentTools::InvalidMCPPromptsSpecification },
    SameTest -> MatchQ,
    TestID   -> "ValidateMCPPrompts-InvalidName@@Tests/Prompts.wlt:214,1-220,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompts[ 123 ],
    _Failure,
    { AgentTools::InvalidMCPPromptsSpecification },
    SameTest -> MatchQ,
    TestID   -> "ValidateMCPPrompts-InvalidType@@Tests/Prompts.wlt:222,1-228,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompt[ "WolframSearch" ],
    "WolframSearch",
    SameTest -> SameQ,
    TestID   -> "ValidateMCPPrompt-ValidString@@Tests/Prompts.wlt:230,1-235,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompt[ <| "Name" -> "Custom" |> ],
    <| "Name" -> "Custom" |>,
    SameTest -> SameQ,
    TestID   -> "ValidateMCPPrompt-Association@@Tests/Prompts.wlt:237,1-242,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompt[ "NonExistent" ],
    _Failure,
    { AgentTools::PromptNameNotFound },
    SameTest -> MatchQ,
    TestID   -> "ValidateMCPPrompt-InvalidName@@Tests/Prompts.wlt:244,1-250,2"
]

(* ::Section:: *)
(* normalizePromptData *)

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`normalizePromptData[ "WolframSearch" ],
    $DefaultMCPPrompts[ "WolframSearch" ],
    SameTest -> SameQ,
    TestID   -> "NormalizePromptData-StringLookup@@Tests/Prompts.wlt:255,1-260,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`normalizePromptData[ <| "Name" -> "Test", "Content" -> "Static text" |> ],
    <| "Name" -> "Test", "Content" -> "Static text", "Type" -> "Text" |>,
    SameTest -> SameQ,
    TestID   -> "NormalizePromptData-TextType@@Tests/Prompts.wlt:262,1-267,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`normalizePromptData[ <| "Name" -> "Test", "Content" -> Function[ x, x ] |> ],
    KeyValuePattern[ "Type" -> "Function" ],
    SameTest -> MatchQ,
    TestID   -> "NormalizePromptData-FunctionType@@Tests/Prompts.wlt:269,1-274,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`normalizePromptData[ "NonExistent" ],
    _Failure,
    { AgentTools::PromptNameNotFound },
    SameTest -> MatchQ,
    TestID   -> "NormalizePromptData-InvalidName@@Tests/Prompts.wlt:276,1-282,2"
]

(* ::Section:: *)
(* determinePromptType *)

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`determinePromptType[ <| "Type" -> "Function" |> ],
    "Function",
    SameTest -> SameQ,
    TestID   -> "DeterminePromptType-ExplicitFunction@@Tests/Prompts.wlt:287,1-292,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`determinePromptType[ <| "Type" -> "Text" |> ],
    "Text",
    SameTest -> SameQ,
    TestID   -> "DeterminePromptType-ExplicitText@@Tests/Prompts.wlt:294,1-299,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`determinePromptType[ <| "Content" -> "Some string" |> ],
    "Text",
    SameTest -> SameQ,
    TestID   -> "DeterminePromptType-StringContent@@Tests/Prompts.wlt:301,1-306,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`determinePromptType[ <| "Content" -> Identity |> ],
    "Function",
    SameTest -> SameQ,
    TestID   -> "DeterminePromptType-FunctionContent@@Tests/Prompts.wlt:308,1-313,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`determinePromptType[ <| |> ],
    "Text",
    SameTest -> SameQ,
    TestID   -> "DeterminePromptType-EmptyDefault@@Tests/Prompts.wlt:315,1-320,2"
]

(* ::Section:: *)
(* MCPServerObject PromptData Property *)

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`getPromptData[
        <| "LLMEvaluator" -> <| "MCPPrompts" -> { "WolframSearch" } |> |>
    ],
    { $DefaultMCPPrompts[ "WolframSearch" ] },
    SameTest -> SameQ,
    TestID   -> "GetPromptData-WithMCPPrompts@@Tests/Prompts.wlt:325,1-332,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`getPromptData[
        <| "LLMEvaluator" -> <| |> |>
    ],
    { },
    SameTest -> SameQ,
    TestID   -> "GetPromptData-NoPrompts@@Tests/Prompts.wlt:334,1-341,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`getPromptData[
        <| "LLMEvaluator" -> <| "MCPPrompts" -> { "WolframSearch", "WolframLanguageSearch" } |> |>
    ],
    { $DefaultMCPPrompts[ "WolframSearch" ], $DefaultMCPPrompts[ "WolframLanguageSearch" ] },
    SameTest -> SameQ,
    TestID   -> "GetPromptData-MultiplePrompts@@Tests/Prompts.wlt:343,1-350,2"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`getPromptData[
        <| "LLMEvaluator" -> <| "MCPPrompts" -> { <| "Name" -> "Custom", "Content" -> "Test" |> } |> |>
    ],
    { <| "Name" -> "Custom", "Content" -> "Test", "Type" -> "Text" |> },
    SameTest -> SameQ,
    TestID   -> "GetPromptData-InlinePrompt@@Tests/Prompts.wlt:352,1-359,2"
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
    TestID   -> "GetPromptData-DeprecatedPromptDataFails@@Tests/Prompts.wlt:364,1-372,2"
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
    TestID   -> "MakePromptContent-FunctionType@@Tests/Prompts.wlt:377,1-385,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        <| "Type" -> "Text", "Content" -> "Static content" |>,
        <| |>
    ],
    <| "type" -> "text", "text" -> "Static content" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-TextType@@Tests/Prompts.wlt:387,1-395,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        <| "Content" -> "No explicit type" |>,
        <| |>
    ],
    <| "type" -> "text", "text" -> "No explicit type" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-NoExplicitType@@Tests/Prompts.wlt:397,1-405,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        <| "Content" -> StringTemplate[ "Hello, `name`!" ] |>,
        <| "name" -> "World" |>
    ],
    <| "type" -> "text", "text" -> "Hello, World!" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-StringTemplate@@Tests/Prompts.wlt:407,1-415,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        "Plain string",
        <| |>
    ],
    <| "type" -> "text", "text" -> "Plain string" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-PlainString@@Tests/Prompts.wlt:417,1-425,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        12345,
        <| |>
    ],
    <| "type" -> "text", "text" -> "12345" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-Fallback@@Tests/Prompts.wlt:427,1-435,2"
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
    TestID   -> "ConsolidateTextContent-TextOnly@@Tests/Prompts.wlt:441,1-451,2"
]

(* Single text item should be consolidated to object *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`consolidateTextContent[
        { <| "type" -> "text", "text" -> "Single" |> }
    ],
    <| "type" -> "text", "text" -> "Single" |>,
    SameTest -> SameQ,
    TestID   -> "ConsolidateTextContent-SingleText@@Tests/Prompts.wlt:454,1-461,2"
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
    TestID   -> "ConsolidateTextContent-WithImage@@Tests/Prompts.wlt:464,1-474,2"
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
    TestID   -> "MakePromptContent-ConsolidatesTextArray@@Tests/Prompts.wlt:477,1-488,2"
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
    TestID   -> "MakePromptContent-ContentKeyConsolidatesText@@Tests/Prompts.wlt:491,1-502,2"
]

(* ::Section:: *)
(* makePromptData (Phase 3) *)

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptData[ {
        <| "Name" -> "Test", "Description" -> "A test prompt" |>
    } ],
    { <| "name" -> "Test", "description" -> "A test prompt" |> },
    SameTest -> SameQ,
    TestID   -> "MakePromptData-CapitalizedKeys@@Tests/Prompts.wlt:507,1-514,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptData[ {
        <| "name" -> "Test", "description" -> "A test prompt" |>
    } ],
    { <| "name" -> "Test", "description" -> "A test prompt" |> },
    SameTest -> SameQ,
    TestID   -> "MakePromptData-LowercaseKeys@@Tests/Prompts.wlt:516,1-523,2"
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
    TestID   -> "MakePromptData-WithArguments@@Tests/Prompts.wlt:525,1-546,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptData[ {
        <| "Name" -> "NoArgs" |>
    } ],
    { <| "name" -> "NoArgs", "description" -> "" |> },
    SameTest -> SameQ,
    TestID   -> "MakePromptData-NoArguments@@Tests/Prompts.wlt:548,1-555,2"
]

(* ::Section:: *)
(* normalizeArguments (Phase 3) *)

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`normalizeArguments[ {
        <| "Name" -> "query", "Description" -> "The search query", "Required" -> True |>
    } ],
    { <| "name" -> "query", "description" -> "The search query", "required" -> True |> },
    SameTest -> SameQ,
    TestID   -> "NormalizeArguments-CapitalizedKeys@@Tests/Prompts.wlt:560,1-567,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`normalizeArguments[ {
        <| "name" -> "query", "description" -> "The search query", "required" -> True |>
    } ],
    { <| "name" -> "query", "description" -> "The search query", "required" -> True |> },
    SameTest -> SameQ,
    TestID   -> "NormalizeArguments-LowercaseKeys@@Tests/Prompts.wlt:569,1-576,2"
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
    TestID   -> "NormalizeArguments-MultipleWithDefaults@@Tests/Prompts.wlt:578,1-589,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`normalizeArguments[ { } ],
    { },
    SameTest -> SameQ,
    TestID   -> "NormalizeArguments-Empty@@Tests/Prompts.wlt:591,1-596,2"
]

(* ::Section:: *)
(* normalizeArgument (Phase 3) *)

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`normalizeArgument[
        <| "Name" -> "query", "Description" -> "The query", "Required" -> True |>
    ],
    <| "name" -> "query", "description" -> "The query", "required" -> True |>,
    SameTest -> SameQ,
    TestID   -> "NormalizeArgument-AllFields@@Tests/Prompts.wlt:601,1-608,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`normalizeArgument[
        <| "Name" -> "query" |>
    ],
    <| "name" -> "query", "description" -> "", "required" -> False |>,
    SameTest -> SameQ,
    TestID   -> "NormalizeArgument-DefaultValues@@Tests/Prompts.wlt:610,1-617,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`normalizeArgument[
        <| "name" -> "query", "description" -> "Lowercase keys", "required" -> True |>
    ],
    <| "name" -> "query", "description" -> "Lowercase keys", "required" -> True |>,
    SameTest -> SameQ,
    TestID   -> "NormalizeArgument-LowercaseKeys@@Tests/Prompts.wlt:619,1-626,2"
]

(* ::Section:: *)
(* Server Configuration (Phase 4) *)

VerificationTest[
    $DefaultMCPServers[ "Wolfram" ][ "MCPPrompts" ],
    { "WolframSearch" },
    SameTest -> SameQ,
    TestID   -> "ServerConfig-WolframHasMCPPrompts@@Tests/Prompts.wlt:631,1-636,2"
]

VerificationTest[
    $DefaultMCPServers[ "WolframAlpha" ][ "MCPPrompts" ],
    { "WolframAlphaSearch" },
    SameTest -> SameQ,
    TestID   -> "ServerConfig-WolframAlphaHasMCPPrompts@@Tests/Prompts.wlt:638,1-643,2"
]

VerificationTest[
    $DefaultMCPServers[ "WolframLanguage" ][ "MCPPrompts" ],
    { "WolframLanguageSearch", "Notebook" },
    SameTest -> SameQ,
    TestID   -> "ServerConfig-WolframLanguageHasMCPPrompts@@Tests/Prompts.wlt:645,1-650,2"
]

VerificationTest[
    $DefaultMCPServers[ "WolframPacletDevelopment" ][ "MCPPrompts" ],
    { "WolframLanguageSearch", "Notebook" },
    SameTest -> SameQ,
    TestID   -> "ServerConfig-WolframPacletDevelopmentHasMCPPrompts@@Tests/Prompts.wlt:652,1-657,2"
]

(* ::Subsection:: *)
(* Server PromptData Property *)

VerificationTest[
    MCPServerObject[ "Wolfram" ][ "PromptData" ],
    { KeyValuePattern[ "Name" -> "Search" ] },
    SameTest -> MatchQ,
    TestID   -> "ServerPromptData-Wolfram@@Tests/Prompts.wlt:662,1-667,2"
]

VerificationTest[
    MCPServerObject[ "WolframAlpha" ][ "PromptData" ],
    { KeyValuePattern[ "Name" -> "Search" ] },
    SameTest -> MatchQ,
    TestID   -> "ServerPromptData-WolframAlpha@@Tests/Prompts.wlt:669,1-674,2"
]

VerificationTest[
    MCPServerObject[ "WolframLanguage" ][ "PromptData" ],
    { KeyValuePattern[ "Name" -> "Search" ], KeyValuePattern[ "Name" -> "Notebook" ] },
    SameTest -> MatchQ,
    TestID   -> "ServerPromptData-WolframLanguage@@Tests/Prompts.wlt:676,1-681,2"
]

VerificationTest[
    MCPServerObject[ "WolframPacletDevelopment" ][ "PromptData" ],
    { KeyValuePattern[ "Name" -> "Search" ], KeyValuePattern[ "Name" -> "Notebook" ] },
    SameTest -> MatchQ,
    TestID   -> "ServerPromptData-WolframPacletDevelopment@@Tests/Prompts.wlt:683,1-688,2"
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
    TestID   -> "ServerPromptData-AllHaveFunctionType@@Tests/Prompts.wlt:693,1-706,2"
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
    TestID   -> "ServerPromptData-PromptNames@@Tests/Prompts.wlt:711,1-719,2"
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
    TestID   -> "CatchPromptFunction-Success@@Tests/Prompts.wlt:727,1-735,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`catchPromptFunction[
        Function[ args, Failure[ "TestError", <| "MessageTemplate" -> "Something went wrong" |> ] ],
        <| "query" -> "test" |>
    ],
    "[Error] Something went wrong",
    SameTest -> SameQ,
    TestID   -> "CatchPromptFunction-ReturnsFailure@@Tests/Prompts.wlt:737,1-745,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`catchPromptFunction[
        Function[ args, Wolfram`AgentTools`Common`throwFailure[ "InvalidArguments", AgentTools, "test" ] ],
        <| "query" -> "test" |>
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "CatchPromptFunction-ThrowsFailure@@Tests/Prompts.wlt:747,1-755,2"
]

(* ::Subsection:: *)
(* formatPromptError *)

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`formatPromptError[
        Failure[ "TestError", <| "MessageTemplate" -> "Test message" |> ]
    ],
    "[Error] Test message",
    SameTest -> SameQ,
    TestID   -> "FormatPromptError-WithMessage@@Tests/Prompts.wlt:760,1-767,2"
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
    TestID   -> "FormatPromptError-NoMessage@@Tests/Prompts.wlt:769,1-779,2"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`formatPromptError[ "not a failure" ],
    "[Error] Failed to generate prompt content.",
    SameTest -> SameQ,
    TestID   -> "FormatPromptError-NonFailure@@Tests/Prompts.wlt:781,1-786,2"
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
    TestID   -> "MakePromptContent-FunctionReturnsFailure@@Tests/Prompts.wlt:791,1-799,2"
]

VerificationTest[
    StringQ @ Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        <| "Type" -> "Function", "Content" -> Function[ args, Wolfram`AgentTools`Common`throwFailure[ "InvalidArguments", AgentTools, "test" ] ] |>,
        <| "query" -> "test" |>
    ][ "text" ],
    True,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-FunctionThrowsFailure@@Tests/Prompts.wlt:801,1-809,2"
]

(* ::Section:: *)
(* Prompt Format (Phase 6) *)

(* ::Subsection:: *)
(* formatSearchPrompt *)

VerificationTest[
    Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "test query", "some results" ],
    "<search-query>test query</search-query>\n<search-results>\nsome results\n</search-results>\nUse the above search results to answer the user's query below.\n<user-query>test query</user-query>",
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-BasicOutput@@Tests/Prompts.wlt:817,1-822,2"
]

VerificationTest[
    StringQ @ Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "query", "results" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-ReturnsString@@Tests/Prompts.wlt:824,1-829,2"
]

VerificationTest[
    StringContainsQ[
        Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "my query", "my results" ],
        "<search-query>my query</search-query>"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-ContainsSearchQueryTag@@Tests/Prompts.wlt:831,1-839,2"
]

VerificationTest[
    StringContainsQ[
        Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "my query", "my results" ],
        "<search-results>\nmy results\n</search-results>"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-ContainsSearchResultsTag@@Tests/Prompts.wlt:841,1-849,2"
]

VerificationTest[
    StringContainsQ[
        Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "my query", "my results" ],
        "<user-query>my query</user-query>"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-ContainsUserQueryTag@@Tests/Prompts.wlt:851,1-859,2"
]

VerificationTest[
    StringCount[
        Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "duplicated", "results" ],
        "duplicated"
    ],
    2,
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-QueryAppearsInBothTags@@Tests/Prompts.wlt:861,1-869,2"
]

VerificationTest[
    StringContainsQ[
        Wolfram`AgentTools`Prompts`Search`Private`formatSearchPrompt[ "test", "test" ],
        "Use the above search results to answer the user's query below."
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatSearchPrompt-ContainsInstructionalText@@Tests/Prompts.wlt:871,1-879,2"
]

(* ::Subsection:: *)
(* Format Used by Search Prompts *)

(* Skip these in GitHub Actions due to an issue with wolframscript hanging when checking the license server during
   tests that potentially spend a long time downloading files. *)
skipIfGitHubActions @ VerificationTest[
    $wolframSearchPromptOutput = $DefaultMCPPrompts[ "WolframSearch" ][ "Content" ][ <| "query" -> "test query" |> ],
    _String | { KeyValuePattern[ "type" -> "text" ], ___ },
    SameTest -> MatchQ,
    TestID   -> "WolframSearch-ReturnsValidOutput@@Tests/Prompts.wlt:886,23-891,2"
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
    TestID   -> "WolframSearch-UsesNewFormat@@Tests/Prompts.wlt:893,23-904,2"
]

skipIfGitHubActions @ VerificationTest[
    $wlSearchPromptOutput = $DefaultMCPPrompts[ "WolframLanguageSearch" ][ "Content" ][ <| "query" -> "test query" |> ],
    _String | { KeyValuePattern[ "type" -> "text" ], ___ },
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageSearch-ReturnsValidOutput@@Tests/Prompts.wlt:906,23-911,2"
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
    TestID   -> "WolframLanguageSearch-UsesNewFormat@@Tests/Prompts.wlt:913,23-924,2"
]

skipIfGitHubActions @ VerificationTest[
    $waSearchPromptOutput = $DefaultMCPPrompts[ "WolframAlphaSearch" ][ "Content" ][ <| "query" -> "test query" |> ],
    _String | { KeyValuePattern[ "type" -> "text" ], ___ },
    SameTest -> MatchQ,
    TestID   -> "WolframAlphaSearch-ReturnsValidOutput@@Tests/Prompts.wlt:926,23-931,2"
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
    TestID   -> "WolframAlphaSearch-UsesNewFormat@@Tests/Prompts.wlt:933,23-944,2"
]

(* ::Subsection:: *)
(* formatNotebookPrompt *)

VerificationTest[
    Wolfram`AgentTools`Prompts`Notebook`Private`formatNotebookPrompt[ "/path/to/file.nb", "# Heading\n\nContent" ],
    "<notebook-path>/path/to/file.nb</notebook-path>\n<notebook-content>\n# Heading\n\nContent\n</notebook-content>",
    SameTest -> SameQ,
    TestID   -> "FormatNotebookPrompt-BasicOutput@@Tests/Prompts.wlt:949,1-954,2"
]

VerificationTest[
    StringQ @ Wolfram`AgentTools`Prompts`Notebook`Private`formatNotebookPrompt[ "/path/to/file.nb", "content" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatNotebookPrompt-ReturnsString@@Tests/Prompts.wlt:956,1-961,2"
]

VerificationTest[
    StringContainsQ[
        Wolfram`AgentTools`Prompts`Notebook`Private`formatNotebookPrompt[ "/my/path.nb", "my content" ],
        "<notebook-path>/my/path.nb</notebook-path>"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatNotebookPrompt-ContainsPathTag@@Tests/Prompts.wlt:963,1-971,2"
]

VerificationTest[
    StringContainsQ[
        Wolfram`AgentTools`Prompts`Notebook`Private`formatNotebookPrompt[ "/my/path.nb", "my content" ],
        "<notebook-content>\nmy content\n</notebook-content>"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "FormatNotebookPrompt-ContainsContentTag@@Tests/Prompts.wlt:973,1-981,2"
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
    TestID   -> "MakePromptContent-ContentArray@@Tests/Prompts.wlt:987,1-995,2"
]

(* Structured content with Content key is also consolidated *)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`makePromptContent[
        <| "Content" -> { <| "type" -> "text", "text" -> "hello" |> } |>,
        <| |>
    ],
    <| "type" -> "text", "text" -> "hello" |>,
    SameTest -> SameQ,
    TestID   -> "MakePromptContent-StructuredContent@@Tests/Prompts.wlt:998,1-1006,2"
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
    TestID   -> "FormatSearchPrompt-MultimodalContent@@Tests/Prompts.wlt:1008,1-1022,2"
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
    TestID   -> "FormatSearchPrompt-MultimodalTextOnly@@Tests/Prompts.wlt:1024,1-1034,2"
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
    TestID   -> "FormatSearchPrompt-MultimodalMultipleImages@@Tests/Prompts.wlt:1036,1-1048,2"
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
    TestID   -> "NotebookPrompt-NonexistentFile@@Tests/Prompts.wlt:1053,1-1061,2"
]

VerificationTest[
    StringMatchQ[
        $DefaultMCPPrompts[ "Notebook" ][ "Content" ][ <| "path" -> "/path/to/file.txt" |> ],
        "[Error] File is not a notebook (.nb): /path/to/file.txt"
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "NotebookPrompt-InvalidExtension@@Tests/Prompts.wlt:1063,1-1071,2"
]

(* :!CodeAnalysis::EndBlock:: *)
