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
    TestID   -> "ExtendedFullDefinition-BaselineMissesNoEntryDependencies"
]

(* The fix: `extendedFullDefinition` unpacks the NOENTRY flag first, so it also discovers `primeFinder`
   and the pattern symbol `n` referenced in its definition. *)
VerificationTest[
    definitionNames @ Wolfram`AgentTools`Common`extendedFullDefinition[ expr ][[ All, 1 ]],
    { "expr", "n", "primeFinder" },
    SameTest -> MatchQ,
    TestID   -> "ExtendedFullDefinition-FindsNoEntryDependencies"
]

(* An expression with no dependent definitions yields an empty DefinitionList. *)
VerificationTest[
    Wolfram`AgentTools`Common`extendedFullDefinition[ 123 ],
    Language`DefinitionList[ ],
    SameTest -> MatchQ,
    TestID   -> "ExtendedFullDefinition-NoDependencies"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*binarySerializeWithDefinitions*)

(* The result is a ByteArray. *)
VerificationTest[
    ByteArrayQ @ Wolfram`AgentTools`Common`binarySerializeWithDefinitions[ Unevaluated[ expr ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BinarySerializeWithDefinitions-ReturnsByteArray"
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
    TestID   -> "BinarySerializeWithDefinitions-RestoresDefinitions"
]

(* With no dependent definitions, the output is identical to a plain BinarySerialize. *)
VerificationTest[
    Wolfram`AgentTools`Common`binarySerializeWithDefinitions[ 123 ] === BinarySerialize[ 123 ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BinarySerializeWithDefinitions-EquivalentWhenNoDependencies"
]

(* BinarySerialize options are threaded through: PerformanceGoal -> "Size" yields a smaller result.
   The size relationship (rather than an exact byte count) is asserted so the test is robust across
   serialization-format changes. *)
VerificationTest[
    Length @ Wolfram`AgentTools`Common`binarySerializeWithDefinitions[ expr, PerformanceGoal -> "Size" ] <
        Length @ Wolfram`AgentTools`Common`binarySerializeWithDefinitions[ expr ],
    True,
    SameTest -> MatchQ,
    TestID   -> "BinarySerializeWithDefinitions-PerformanceGoalOption"
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
    TestID   -> "BinarySerializeWithDefinitions-SplitsOptions"
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
    TestID   -> "ToJSRegex-DotStarWithDotAll"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\d+" ],
    "\\d+",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-DigitCharacterPlus"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "\\d+" ],
    "\\d+",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-NoLeadingFlags"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?i)foo" ],
    "foo",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-IgnoreCaseFlagStripped"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "" ],
    "",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-EmptyString"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*POSIX character classes*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:alpha:]]" ],
    "[a-zA-Z]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXAlpha"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:digit:]]" ],
    "[0-9]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXDigit"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:alnum:]]" ],
    "[a-zA-Z0-9]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXAlnum"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:upper:]]" ],
    "[A-Z]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXUpper"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:lower:]]" ],
    "[a-z]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXLower"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:xdigit:]]" ],
    "[0-9a-fA-F]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXXdigit"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:space:]]" ],
    "[\\s]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXSpace"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:blank:]]" ],
    "[ \\t]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXBlank"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:cntrl:]]" ],
    "[\\x00-\\x1F\\x7F]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXCntrl"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:print:]]" ],
    "[\\x20-\\x7E]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXPrint"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:graph:]]" ],
    "[\\x21-\\x7E]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXGraph"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:punct:]]" ],
    "[!-/:-@[-`{-~]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXPunct"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:alpha:][:digit:]]" ],
    "[a-zA-Z0-9]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXCombined"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[^[:alpha:]]" ],
    "[^a-zA-Z]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-POSIXNegated"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*PCRE anchors*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\Aprefix.*suffix\\z" ],
    "^prefix[\\s\\S]*suffix$",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-StartOfStringEndOfString"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)foo\\Z" ],
    "foo$",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-CapitalZEnd"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Unicode escapes*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{A0}" ],
    "\\xA0",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode2Digit"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{0}" ],
    "\\x00",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode1DigitPadded"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{abc}" ],
    "\\u0ABC",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode3DigitPadded"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{ABCD}" ],
    "\\uABCD",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode4Digit"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{1F600}" ],
    "\\uD83D\\uDE00",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-Unicode5DigitSupplementary"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{10000}" ],
    "\\uD800\\uDC00",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeFirstSupplementary"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{10FFFF}" ],
    "\\uDBFF\\uDFFF",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeMaxSupplementary"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[[:alpha:]\\x{f6b2}-\\x{f6b5}]" ],
    "[a-zA-Z\\uF6B2-\\uF6B5]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-LetterCharacterWithPUA"
]

(* Zero-padded escapes must be classified by numeric value, not string length. *)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{0000A0}" ],
    "\\xA0",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeZeroPaddedLatin1"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{00ABCD}" ],
    "\\uABCD",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeZeroPaddedBMP"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\x{000010FFFF}" ],
    "\\uDBFF\\uDFFF",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-UnicodeZeroPaddedSupplementary"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Inner (?-m-s) modifier stripping*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)(?:(?-m-s)\\d+)" ],
    "(?:\\d+)",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-StripInnerModifier"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)(?:(?-s)abc)" ],
    "(?:abc)",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-StripInnerModifierSOnly"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)(?:(?-m-s)a.b)" ],
    "(?:a[\\s\\S]b)",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-InnerDotOverMatches"
]

(* Mid-pattern modifiers outside the "(?:(?-...)" wrapper form must pass through untouched,
   so user-supplied regexes keep their original semantics. *)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "a(?-s)b" ],
    "a(?-s)b",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-MidPatternModifierPreserved"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "foo(?-m-s)bar" ],
    "foo(?-m-s)bar",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-MidPatternCombinedModifierPreserved"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Dotall walker preserves escapes and classes*)
VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)a\\.b" ],
    "a\\.b",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-EscapedDotUntouched"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[.]" ],
    "[.]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-DotInClassUntouched"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)[.xyz\\.]" ],
    "[.xyz\\.]",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-DotInLargerClassUntouched"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)\\(.+?\\)" ],
    "\\([\\s\\S]+?\\)",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-ShortestGroup"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms)^# .+$" ],
    "^# [\\s\\S]+$",
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-LineAnchorsPreserved"
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
    TestID   -> "ToJSRegex-NoFlagGroupInOutput"
]

VerificationTest[
    Wolfram`AgentTools`Common`toJSRegex[ "(?ms).*" ],
    Except[ _? (StringStartsQ[ "/" ]) ],
    SameTest -> MatchQ,
    TestID   -> "ToJSRegex-NoLiteralDelimiters"
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
    TestID   -> "LLMKitUsageLimitFailureQ-APIError"
]

VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitFailureQ[ $wrappedUsageLimitFailure ],
    True,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitFailureQ-Wrapped"
]

VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitFailureQ[ "A normal documentation result." ],
    False,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitFailureQ-PlainString"
]

(* An unrelated API failure must NOT be treated as a usage-limit failure (it should remain an internal failure). *)
VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitFailureQ[
        Failure[ "APIError", <| "StatusCode" -> 500, "Body" -> "Internal Server Error" |> ]
    ],
    False,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitFailureQ-UnrelatedFailure"
]

VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitFailureQ[ $Failed ],
    False,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitFailureQ-NonFailure"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmKitUsageLimitMessage*)
VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitMessage[ $usageLimitFailure ],
    "credits-per-month-limit-exceeded - User has exceeded credits limit.",
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitMessage-ExtractsServiceMessage"
]

VerificationTest[
    Wolfram`AgentTools`Common`llmKitUsageLimitMessage[ $wrappedUsageLimitFailure ],
    "credits-per-month-limit-exceeded - User has exceeded credits limit.",
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitMessage-ExtractsFromWrapped"
]

(* Falls back to a generic message when the service response carries no human-readable message. *)
VerificationTest[
    StringQ @ Wolfram`AgentTools`Common`llmKitUsageLimitMessage[
        Failure[ "APIError", <| "StatusCode" -> 429 |> ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "LLMKitUsageLimitMessage-FallbackString"
]

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*LLMKit Enablement*)

(* llmKitEnabledQ reads the LLMKIT_ENABLED environment variable, which "EnableLLMKit" -> False sets
   to "false" in the MCP config's env block. The value is interpreted as a Boolean: only a value that
   reads as False (e.g. "false"/"no"/"0", case-insensitive) disables LLMKit; an unset variable, or any
   value that does not interpret as False (including non-boolean strings), leaves it enabled. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*environmentBlock (helper sanity check)*)

(* Confirm the shared helper actually sets and restores the real process environment in this kernel,
   so the LLMKit tests below exercise genuine Environment[...] reads. *)
VerificationTest[
    {
        environmentBlock[ "AGENTTOOLS_ENV_PROBE" -> "set", Environment[ "AGENTTOOLS_ENV_PROBE" ] ],
        Environment[ "AGENTTOOLS_ENV_PROBE" ]
    },
    { "set", $Failed },
    SameTest -> SameQ,
    TestID   -> "EnvironmentBlock-SetsAndRestores"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmKitEnabledQ*)

(* Enabled when the variable is not set *)
VerificationTest[
    environmentBlock[ "LLMKIT_ENABLED" -> None, Wolfram`AgentTools`Common`llmKitEnabledQ[ ] ],
    True,
    SameTest -> Equal,
    TestID   -> "LLMKitEnabledQ-NotSet"
]

(* Disabled when the variable is "false" *)
VerificationTest[
    environmentBlock[ "LLMKIT_ENABLED" -> "false", Wolfram`AgentTools`Common`llmKitEnabledQ[ ] ],
    False,
    SameTest -> Equal,
    TestID   -> "LLMKitEnabledQ-FalseLowercase"
]

(* The check is case-insensitive *)
VerificationTest[
    environmentBlock[ "LLMKIT_ENABLED" -> "False", Wolfram`AgentTools`Common`llmKitEnabledQ[ ] ],
    False,
    SameTest -> Equal,
    TestID   -> "LLMKitEnabledQ-FalseMixedCase"
]

VerificationTest[
    environmentBlock[ "LLMKIT_ENABLED" -> "FALSE", Wolfram`AgentTools`Common`llmKitEnabledQ[ ] ],
    False,
    SameTest -> Equal,
    TestID   -> "LLMKitEnabledQ-FalseUppercase"
]

(* Any other value leaves LLMKit enabled *)
VerificationTest[
    environmentBlock[ "LLMKIT_ENABLED" -> "true", Wolfram`AgentTools`Common`llmKitEnabledQ[ ] ],
    True,
    SameTest -> Equal,
    TestID   -> "LLMKitEnabledQ-TrueString"
]

VerificationTest[
    environmentBlock[ "LLMKIT_ENABLED" -> "1", Wolfram`AgentTools`Common`llmKitEnabledQ[ ] ],
    True,
    SameTest -> Equal,
    TestID   -> "LLMKitEnabledQ-OneString"
]

(* A value that reads as boolean False also disables LLMKit *)
VerificationTest[
    environmentBlock[ "LLMKIT_ENABLED" -> "0", Wolfram`AgentTools`Common`llmKitEnabledQ[ ] ],
    False,
    SameTest -> Equal,
    TestID   -> "LLMKitEnabledQ-ZeroDisables"
]

VerificationTest[
    environmentBlock[ "LLMKIT_ENABLED" -> "no", Wolfram`AgentTools`Common`llmKitEnabledQ[ ] ],
    False,
    SameTest -> Equal,
    TestID   -> "LLMKitEnabledQ-NoDisables"
]

(* A value that does not interpret as a Boolean leaves LLMKit enabled *)
VerificationTest[
    environmentBlock[ "LLMKIT_ENABLED" -> "maybe", Wolfram`AgentTools`Common`llmKitEnabledQ[ ] ],
    True,
    SameTest -> Equal,
    TestID   -> "LLMKitEnabledQ-NonBooleanEnabled"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmKitSubscribedQ Gating*)

(* When LLMKit is disabled, llmKitSubscribedQ[] is False AND short-circuits before getLLMKitInfo[],
   so the context tools behave as unsubscribed without any cloud lookup. The mocked getLLMKitInfo
   would report a subscription if consulted -- proving both the forced-False result and that it is
   never called. *)
VerificationTest[
    Module[ { called = False, result },
        result = environmentBlock[ "LLMKIT_ENABLED" -> "false",
            Block[
                {
                    Wolfram`AgentTools`Common`getLLMKitInfo =
                        Function[ called = True; <| "userHasSubscription" -> True, "buyNowUrl" -> "x" |> ]
                },
                Wolfram`AgentTools`Common`llmKitSubscribedQ[ ]
            ]
        ];
        { result, called }
    ],
    { False, False },
    SameTest -> SameQ,
    TestID   -> "LLMKitSubscribedQ-DisabledShortCircuits"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Dependencies*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatbookVersionCheck*)

(* Ensures the available Chatbook satisfies $minimumChatbookVersion (installing or updating if necessary): *)
VerificationTest[
    Wolfram`AgentTools`Common`chatbookVersionCheck[ ],
    True,
    SameTest -> SameQ,
    TestID   -> "ChatbookVersionCheck"
]

(* The minimum Chatbook version must support the "PropagateMessages" option that the
   WolframLanguageEvaluator tool passes to WolframLanguageToolEvaluate (added in Chatbook 2.7.0): *)
VerificationTest[
    Quiet @ Options[ Wolfram`Chatbook`WolframLanguageToolEvaluate, "PropagateMessages" ],
    { _Rule | _RuleDelayed },
    SameTest -> MatchQ,
    TestID   -> "ChatbookVersionCheck-PropagateMessagesSupported"
]
