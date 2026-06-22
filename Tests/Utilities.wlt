(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Utilities.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Utilities.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Regular Expressions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toJSRegex*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Dotall and basic flag stripping*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms).*" ],
    "[\\s\\S]*",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-DotStarWithDotAll@@Tests/Utilities.wlt:32,1-37,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\d+" ],
    "\\d+",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-DigitCharacterPlus@@Tests/Utilities.wlt:39,1-44,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "\\d+" ],
    "\\d+",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-NoLeadingFlags@@Tests/Utilities.wlt:46,1-51,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?i)foo" ],
    "foo",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-IgnoreCaseFlagStripped@@Tests/Utilities.wlt:53,1-58,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "" ],
    "",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-EmptyString@@Tests/Utilities.wlt:60,1-65,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*POSIX character classes*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:alpha:]]" ],
    "[a-zA-Z]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXAlpha@@Tests/Utilities.wlt:70,1-75,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:digit:]]" ],
    "[0-9]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXDigit@@Tests/Utilities.wlt:77,1-82,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:alnum:]]" ],
    "[a-zA-Z0-9]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXAlnum@@Tests/Utilities.wlt:84,1-89,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:upper:]]" ],
    "[A-Z]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXUpper@@Tests/Utilities.wlt:91,1-96,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:lower:]]" ],
    "[a-z]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXLower@@Tests/Utilities.wlt:98,1-103,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:xdigit:]]" ],
    "[0-9a-fA-F]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXXdigit@@Tests/Utilities.wlt:105,1-110,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:space:]]" ],
    "[\\s]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXSpace@@Tests/Utilities.wlt:112,1-117,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:blank:]]" ],
    "[ \\t]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXBlank@@Tests/Utilities.wlt:119,1-124,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:cntrl:]]" ],
    "[\\x00-\\x1F\\x7F]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXCntrl@@Tests/Utilities.wlt:126,1-131,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:print:]]" ],
    "[\\x20-\\x7E]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXPrint@@Tests/Utilities.wlt:133,1-138,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:graph:]]" ],
    "[\\x21-\\x7E]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXGraph@@Tests/Utilities.wlt:140,1-145,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:punct:]]" ],
    "[!-/:-@[-`{-~]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXPunct@@Tests/Utilities.wlt:147,1-152,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:alpha:][:digit:]]" ],
    "[a-zA-Z0-9]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXCombined@@Tests/Utilities.wlt:154,1-159,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[^[:alpha:]]" ],
    "[^a-zA-Z]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXNegated@@Tests/Utilities.wlt:161,1-166,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*PCRE anchors*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\Aprefix.*suffix\\z" ],
    "^prefix[\\s\\S]*suffix$",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-StartOfStringEndOfString@@Tests/Utilities.wlt:171,1-176,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)foo\\Z" ],
    "foo$",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-CapitalZEnd@@Tests/Utilities.wlt:178,1-183,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Unicode escapes*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{A0}" ],
    "\\xA0",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode2Digit@@Tests/Utilities.wlt:188,1-193,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{0}" ],
    "\\x00",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode1DigitPadded@@Tests/Utilities.wlt:195,1-200,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{abc}" ],
    "\\u0ABC",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode3DigitPadded@@Tests/Utilities.wlt:202,1-207,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{ABCD}" ],
    "\\uABCD",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode4Digit@@Tests/Utilities.wlt:209,1-214,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{1F600}" ],
    "\\uD83D\\uDE00",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode5DigitSupplementary@@Tests/Utilities.wlt:216,1-221,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{10000}" ],
    "\\uD800\\uDC00",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeFirstSupplementary@@Tests/Utilities.wlt:223,1-228,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{10FFFF}" ],
    "\\uDBFF\\uDFFF",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeMaxSupplementary@@Tests/Utilities.wlt:230,1-235,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:alpha:]\\x{f6b2}-\\x{f6b5}]" ],
    "[a-zA-Z\\uF6B2-\\uF6B5]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-LetterCharacterWithPUA@@Tests/Utilities.wlt:237,1-242,2"
]

(* Zero-padded escapes must be classified by numeric value, not string length. *)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{0000A0}" ],
    "\\xA0",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeZeroPaddedLatin1@@Tests/Utilities.wlt:245,1-250,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{00ABCD}" ],
    "\\uABCD",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeZeroPaddedBMP@@Tests/Utilities.wlt:252,1-257,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{000010FFFF}" ],
    "\\uDBFF\\uDFFF",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeZeroPaddedSupplementary@@Tests/Utilities.wlt:259,1-264,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Inner (?-m-s) modifier stripping*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)(?:(?-m-s)\\d+)" ],
    "(?:\\d+)",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-StripInnerModifier@@Tests/Utilities.wlt:269,1-274,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)(?:(?-s)abc)" ],
    "(?:abc)",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-StripInnerModifierSOnly@@Tests/Utilities.wlt:276,1-281,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)(?:(?-m-s)a.b)" ],
    "(?:a[\\s\\S]b)",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-InnerDotOverMatches@@Tests/Utilities.wlt:283,1-288,2"
]

(* Mid-pattern modifiers outside the "(?:(?-...)" wrapper form must pass through untouched,
   so user-supplied regexes keep their original semantics. *)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "a(?-s)b" ],
    "a(?-s)b",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-MidPatternModifierPreserved@@Tests/Utilities.wlt:292,1-297,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "foo(?-m-s)bar" ],
    "foo(?-m-s)bar",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-MidPatternCombinedModifierPreserved@@Tests/Utilities.wlt:299,1-304,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Dotall walker preserves escapes and classes*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)a\\.b" ],
    "a\\.b",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-EscapedDotUntouched@@Tests/Utilities.wlt:309,1-314,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[.]" ],
    "[.]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-DotInClassUntouched@@Tests/Utilities.wlt:316,1-321,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[.xyz\\.]" ],
    "[.xyz\\.]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-DotInLargerClassUntouched@@Tests/Utilities.wlt:323,1-328,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\(.+?\\)" ],
    "\\([\\s\\S]+?\\)",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-ShortestGroup@@Tests/Utilities.wlt:330,1-335,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)^# .+$" ],
    "^# [\\s\\S]+$",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-LineAnchorsPreserved@@Tests/Utilities.wlt:337,1-342,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Output is a valid JavaScript regex for common inputs*)

(* These are the actual "pattern" strings LLMTool's JSONSchema emits for the default tools.
   Without the fix, JS validators choke on "(?ms)". *)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms).*" ],
    Except[ _? (StringContainsQ[ "(?" ]) ],
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-NoFlagGroupInOutput@@Tests/Utilities.wlt:350,1-355,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms).*" ],
    Except[ _? (StringStartsQ[ "/" ]) ],
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-NoLiteralDelimiters@@Tests/Utilities.wlt:357,1-362,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*LLMKit Usage Limits*)

(* A representative Failure of the kind RelatedWolframAlphaResults / RelatedDocumentation return when the
   user has exhausted their monthly LLMKit credit allotment (HTTP 429). *)
$usageLimitFailure = Failure[ "APIError", <|
    "MessageTemplate"   -> "The service returned the following error message: `1`.",
    "MessageParameters" -> { "credits-per-month-limit-exceeded - User has exceeded credits limit." },
    "StatusCode"        -> 429,
    "Body"              -> <|
        "success" -> False,
        "error"   -> <|
            "code"    -> "credits-per-month-limit-exceeded",
            "message" -> "credits-per-month-limit-exceeded - User has exceeded credits limit."
        |>
    |>
|> ];

(* The same failure as it appears after ConfirmBy has wrapped it, to confirm detection survives nesting. *)
$wrappedUsageLimitFailure = Enclose[
    ConfirmBy[ $usageLimitFailure, StringQ, "Prompt" ],
    ( # & )
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmKitUsageLimitFailureQ*)
VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitFailureQ[ $usageLimitFailure ],
    True,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitFailureQ-APIError@@Tests/Utilities.wlt:392,1-397,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitFailureQ[ $wrappedUsageLimitFailure ],
    True,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitFailureQ-Wrapped@@Tests/Utilities.wlt:399,1-404,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitFailureQ[ "A normal documentation result." ],
    False,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitFailureQ-PlainString@@Tests/Utilities.wlt:406,1-411,2"
]

(* An unrelated API failure must NOT be treated as a usage-limit failure (it should remain an internal failure). *)
VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitFailureQ[
        Failure[ "APIError", <| "StatusCode" -> 500, "Body" -> "Internal Server Error" |> ]
    ],
    False,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitFailureQ-UnrelatedFailure@@Tests/Utilities.wlt:414,1-421,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitFailureQ[ $Failed ],
    False,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitFailureQ-NonFailure@@Tests/Utilities.wlt:423,1-428,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmKitUsageLimitMessage*)
VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitMessage[ $usageLimitFailure ],
    "credits-per-month-limit-exceeded - User has exceeded credits limit.",
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitMessage-ExtractsServiceMessage@@Tests/Utilities.wlt:433,1-438,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitMessage[ $wrappedUsageLimitFailure ],
    "credits-per-month-limit-exceeded - User has exceeded credits limit.",
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitMessage-ExtractsFromWrapped@@Tests/Utilities.wlt:440,1-445,2"
]

(* Falls back to a generic message when the service response carries no human-readable message. *)
VerificationTest[
    StringQ @ Wolfram`AgentTools`Common`llmKitUsageLimitMessage[
        Failure[ "APIError", <| "StatusCode" -> 429 |> ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitMessage-FallbackString@@Tests/Utilities.wlt:448,1-455,2"
]

(* :!CodeAnalysis::EndBlock:: *)
