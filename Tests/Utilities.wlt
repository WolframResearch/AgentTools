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
(*Definition Utilities*)

(* Shared fixtures. `primeFinder` is a user-defined function that is referenced only indirectly, through
   the NOENTRY-flagged LLMTool inside `expr`. That flag hides `primeFinder` from the pattern matcher, so
   the stock Language`ExtendedFullDefinition cannot discover it, but `extendedFullDefinition` can. *)
primeFinder // ClearAll;
primeFinder[ KeyValuePattern[ "n" -> n_ ] ] := primeFinder[ n ];
primeFinder[ n_Integer ]                    := Prime[ n ];

expr = <|
    "Configuration" -> LLMConfiguration[ <| "Tools" -> { LLMTool[ "PrimeFinder", <| "n" -> "Integer" |>, primeFinder ] } |> ]
|>;

(* Sorted short names of the symbols captured in a DefinitionList's [[All, 1]] column. *)
definitionNames[ dl_ ] := Sort @ Cases[ dl, HoldForm[ s_ ] :> SymbolName[ Unevaluated @ s ], { 1 } ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extendedFullDefinition*)

(* Baseline (documents the problem): stock Language`ExtendedFullDefinition finds only `expr` itself and
   cannot see `primeFinder` hidden inside the NOENTRY-flagged LLMTool. *)
VerificationTest[
    definitionNames @ Language`ExtendedFullDefinition[ expr ][[ All, 1 ]],
    { "expr" },
    SameTest -> MatchQ,
    TestID   -> "ExtendedFullDefinition-BaselineMissesNoEntryDependencies@@Tests/Utilities.wlt:45,1-50,2"
]

(* The fix: `extendedFullDefinition` unpacks the NOENTRY flag first, so it also discovers `primeFinder`
   and the pattern symbol `n` referenced in its definition. *)
VerificationTest[
    definitionNames @ Wolfram`AgentTools`Common`extendedFullDefinition[ expr ][[ All, 1 ]],
    { "expr", "n", "primeFinder" },
    SameTest -> MatchQ,
    TestID   -> "ExtendedFullDefinition-FindsNoEntryDependencies@@Tests/Utilities.wlt:54,1-59,2"
]

(* An expression with no dependent definitions yields an empty DefinitionList. *)
VerificationTest[
    Wolfram`AgentTools`Common`extendedFullDefinition[ 123 ],
    Language`DefinitionList[ ],
    SameTest -> MatchQ,
    TestID   -> "ExtendedFullDefinition-NoDependencies@@Tests/Utilities.wlt:62,1-67,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*binarySerializeWithDefinitions*)

(* The result is a ByteArray. *)
VerificationTest[
    ByteArrayQ @ Wolfram`AgentTools`Common`binarySerializeWithDefinitions[ Unevaluated[ expr ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BinarySerializeWithDefinitions-ReturnsByteArray@@Tests/Utilities.wlt:74,1-79,2"
]

(* Round trip: after serialization the dependent definition is truly gone (before -> False), and
   BinaryDeserialize restores it so the recovered `primeFinder` computes Prime[123] = 677 (after -> 677).
   A Module keeps the fixture symbols local so the test does not depend on or pollute global state. *)
VerificationTest[
    Module[ { pf, e, wxf, before, after },
        pf[ KeyValuePattern[ "n" -> k_ ] ] := pf[ k ];
        pf[ k_Integer ]                    := Prime[ k ];
        e = <|
            "Configuration" -> LLMConfiguration[ <| "Tools" -> { LLMTool[ "PrimeFinder", <| "n" -> "Integer" |>, pf ] } |> ]
        |>;
        wxf = Wolfram`AgentTools`Common`binarySerializeWithDefinitions[ Unevaluated[ e ] ];
        ClearAll[ pf, e ];
        before = IntegerQ @ pf[ 123 ];
        BinaryDeserialize[ wxf ];
        after = pf[ 123 ];
        { before, after }
    ],
    { False, 677 },
    SameTest -> MatchQ,
    TestID   -> "BinarySerializeWithDefinitions-RestoresDefinitions@@Tests/Utilities.wlt:84,1-101,2"
]

(* With no dependent definitions, the output is identical to a plain BinarySerialize. *)
VerificationTest[
    Wolfram`AgentTools`Common`binarySerializeWithDefinitions[ 123 ] === BinarySerialize[ 123 ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BinarySerializeWithDefinitions-EquivalentWhenNoDependencies@@Tests/Utilities.wlt:104,1-109,2"
]

(* BinarySerialize options are threaded through: PerformanceGoal -> "Size" yields a smaller result.
   The size relationship (rather than an exact byte count) is asserted so the test is robust across
   serialization-format changes. *)
VerificationTest[
    Length @ Wolfram`AgentTools`Common`binarySerializeWithDefinitions[ expr, PerformanceGoal -> "Size" ] <
        Length @ Wolfram`AgentTools`Common`binarySerializeWithDefinitions[ expr ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BinarySerializeWithDefinitions-PerformanceGoalOption@@Tests/Utilities.wlt:114,1-120,2"
]

(* Options are split between the two targets: an Language`ExtendedFullDefinition option (ExcludedContexts)
   and a BinarySerialize option (PerformanceGoal) can be supplied together without either leaking to the
   wrong function, so the call succeeds with no messages. *)
VerificationTest[
    ByteArrayQ @ Wolfram`AgentTools`Common`binarySerializeWithDefinitions[
        expr,
        ExcludedContexts -> Automatic,
        PerformanceGoal  -> "Size"
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BinarySerializeWithDefinitions-SplitsOptions@@Tests/Utilities.wlt:125,1-134,2"
]

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
    TestID   -> "ToJSRegex-DotStarWithDotAll@@Tests/Utilities.wlt:147,1-152,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\d+" ],
    "\\d+",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-DigitCharacterPlus@@Tests/Utilities.wlt:154,1-159,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "\\d+" ],
    "\\d+",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-NoLeadingFlags@@Tests/Utilities.wlt:161,1-166,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?i)foo" ],
    "foo",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-IgnoreCaseFlagStripped@@Tests/Utilities.wlt:168,1-173,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "" ],
    "",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-EmptyString@@Tests/Utilities.wlt:175,1-180,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*POSIX character classes*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:alpha:]]" ],
    "[a-zA-Z]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXAlpha@@Tests/Utilities.wlt:185,1-190,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:digit:]]" ],
    "[0-9]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXDigit@@Tests/Utilities.wlt:192,1-197,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:alnum:]]" ],
    "[a-zA-Z0-9]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXAlnum@@Tests/Utilities.wlt:199,1-204,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:upper:]]" ],
    "[A-Z]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXUpper@@Tests/Utilities.wlt:206,1-211,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:lower:]]" ],
    "[a-z]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXLower@@Tests/Utilities.wlt:213,1-218,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:xdigit:]]" ],
    "[0-9a-fA-F]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXXdigit@@Tests/Utilities.wlt:220,1-225,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:space:]]" ],
    "[\\s]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXSpace@@Tests/Utilities.wlt:227,1-232,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:blank:]]" ],
    "[ \\t]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXBlank@@Tests/Utilities.wlt:234,1-239,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:cntrl:]]" ],
    "[\\x00-\\x1F\\x7F]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXCntrl@@Tests/Utilities.wlt:241,1-246,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:print:]]" ],
    "[\\x20-\\x7E]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXPrint@@Tests/Utilities.wlt:248,1-253,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:graph:]]" ],
    "[\\x21-\\x7E]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXGraph@@Tests/Utilities.wlt:255,1-260,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:punct:]]" ],
    "[!-/:-@[-`{-~]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXPunct@@Tests/Utilities.wlt:262,1-267,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:alpha:][:digit:]]" ],
    "[a-zA-Z0-9]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXCombined@@Tests/Utilities.wlt:269,1-274,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[^[:alpha:]]" ],
    "[^a-zA-Z]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXNegated@@Tests/Utilities.wlt:276,1-281,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*PCRE anchors*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\Aprefix.*suffix\\z" ],
    "^prefix[\\s\\S]*suffix$",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-StartOfStringEndOfString@@Tests/Utilities.wlt:286,1-291,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)foo\\Z" ],
    "foo$",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-CapitalZEnd@@Tests/Utilities.wlt:293,1-298,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Unicode escapes*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{A0}" ],
    "\\xA0",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode2Digit@@Tests/Utilities.wlt:303,1-308,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{0}" ],
    "\\x00",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode1DigitPadded@@Tests/Utilities.wlt:310,1-315,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{abc}" ],
    "\\u0ABC",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode3DigitPadded@@Tests/Utilities.wlt:317,1-322,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{ABCD}" ],
    "\\uABCD",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode4Digit@@Tests/Utilities.wlt:324,1-329,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{1F600}" ],
    "\\uD83D\\uDE00",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode5DigitSupplementary@@Tests/Utilities.wlt:331,1-336,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{10000}" ],
    "\\uD800\\uDC00",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeFirstSupplementary@@Tests/Utilities.wlt:338,1-343,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{10FFFF}" ],
    "\\uDBFF\\uDFFF",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeMaxSupplementary@@Tests/Utilities.wlt:345,1-350,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:alpha:]\\x{f6b2}-\\x{f6b5}]" ],
    "[a-zA-Z\\uF6B2-\\uF6B5]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-LetterCharacterWithPUA@@Tests/Utilities.wlt:352,1-357,2"
]

(* Zero-padded escapes must be classified by numeric value, not string length. *)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{0000A0}" ],
    "\\xA0",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeZeroPaddedLatin1@@Tests/Utilities.wlt:360,1-365,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{00ABCD}" ],
    "\\uABCD",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeZeroPaddedBMP@@Tests/Utilities.wlt:367,1-372,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{000010FFFF}" ],
    "\\uDBFF\\uDFFF",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeZeroPaddedSupplementary@@Tests/Utilities.wlt:374,1-379,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Inner (?-m-s) modifier stripping*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)(?:(?-m-s)\\d+)" ],
    "(?:\\d+)",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-StripInnerModifier@@Tests/Utilities.wlt:384,1-389,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)(?:(?-s)abc)" ],
    "(?:abc)",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-StripInnerModifierSOnly@@Tests/Utilities.wlt:391,1-396,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)(?:(?-m-s)a.b)" ],
    "(?:a[\\s\\S]b)",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-InnerDotOverMatches@@Tests/Utilities.wlt:398,1-403,2"
]

(* Mid-pattern modifiers outside the "(?:(?-...)" wrapper form must pass through untouched,
   so user-supplied regexes keep their original semantics. *)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "a(?-s)b" ],
    "a(?-s)b",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-MidPatternModifierPreserved@@Tests/Utilities.wlt:407,1-412,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "foo(?-m-s)bar" ],
    "foo(?-m-s)bar",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-MidPatternCombinedModifierPreserved@@Tests/Utilities.wlt:414,1-419,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Dotall walker preserves escapes and classes*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)a\\.b" ],
    "a\\.b",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-EscapedDotUntouched@@Tests/Utilities.wlt:424,1-429,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[.]" ],
    "[.]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-DotInClassUntouched@@Tests/Utilities.wlt:431,1-436,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[.xyz\\.]" ],
    "[.xyz\\.]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-DotInLargerClassUntouched@@Tests/Utilities.wlt:438,1-443,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\(.+?\\)" ],
    "\\([\\s\\S]+?\\)",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-ShortestGroup@@Tests/Utilities.wlt:445,1-450,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)^# .+$" ],
    "^# [\\s\\S]+$",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-LineAnchorsPreserved@@Tests/Utilities.wlt:452,1-457,2"
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
    TestID   -> "ToJSRegex-NoFlagGroupInOutput@@Tests/Utilities.wlt:465,1-470,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms).*" ],
    Except[ _? (StringStartsQ[ "/" ]) ],
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-NoLiteralDelimiters@@Tests/Utilities.wlt:472,1-477,2"
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
    TestID   -> "LLMKitUsageLimitFailureQ-APIError@@Tests/Utilities.wlt:507,1-512,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitFailureQ[ $wrappedUsageLimitFailure ],
    True,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitFailureQ-Wrapped@@Tests/Utilities.wlt:514,1-519,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitFailureQ[ "A normal documentation result." ],
    False,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitFailureQ-PlainString@@Tests/Utilities.wlt:521,1-526,2"
]

(* An unrelated API failure must NOT be treated as a usage-limit failure (it should remain an internal failure). *)
VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitFailureQ[
        Failure[ "APIError", <| "StatusCode" -> 500, "Body" -> "Internal Server Error" |> ]
    ],
    False,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitFailureQ-UnrelatedFailure@@Tests/Utilities.wlt:529,1-536,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitFailureQ[ $Failed ],
    False,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitFailureQ-NonFailure@@Tests/Utilities.wlt:538,1-543,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmKitUsageLimitMessage*)
VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitMessage[ $usageLimitFailure ],
    "credits-per-month-limit-exceeded - User has exceeded credits limit.",
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitMessage-ExtractsServiceMessage@@Tests/Utilities.wlt:548,1-553,2"
]

VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitMessage[ $wrappedUsageLimitFailure ],
    "credits-per-month-limit-exceeded - User has exceeded credits limit.",
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitMessage-ExtractsFromWrapped@@Tests/Utilities.wlt:555,1-560,2"
]

(* Falls back to a generic message when the service response carries no human-readable message. *)
VerificationTest[
    StringQ @ Wolfram`AgentTools`Common`llmKitUsageLimitMessage[
        Failure[ "APIError", <| "StatusCode" -> 429 |> ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitMessage-FallbackString@@Tests/Utilities.wlt:563,1-570,2"
]

(* :!CodeAnalysis::EndBlock:: *)
