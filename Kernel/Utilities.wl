(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Utilities`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definition Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*binarySerializeWithDefinitions*)
binarySerializeWithDefinitions // beginDefinition;

binarySerializeWithDefinitions[ expr_, opts: OptionsPattern[ { BinarySerialize, Language`ExtendedFullDefinition } ] ] :=
    Enclose[
        Module[ { efdOpts, bsOpts, defList },

            (* Separate options for ExtendedFullDefinition and BinarySerialize: *)
            efdOpts = Sequence @@ FilterRules[ { opts }, Options @ Language`ExtendedFullDefinition ];
            bsOpts  = Sequence @@ FilterRules[ { opts }, Options @ BinarySerialize                 ];

            (* Generate the definition list: *)
            defList = ConfirmMatch[ extendedFullDefinition[ expr, efdOpts ], _Language`DefinitionList, "Definitions" ];

            (* Serialize the expression along with the definition list (if not empty): *)
            ConfirmBy[
                With[ { d = defList },
                    If[ MatchQ[ d, Language`DefinitionList[ ] ],
                        (* No dependent definitions, so just serialize normally: *)
                        BinarySerialize[ Unevaluated[ expr ], bsOpts ],
                        (* Otherwise, inject code to set the definitions upon deserialization: *)
                        BinarySerialize[ Unevaluated[ Language`ExtendedFullDefinition[ ] = d; expr ], bsOpts ]
                    ]
                ],
                ByteArrayQ,
                "Result"
            ]
        ],
        throwInternalFailure
    ];

binarySerializeWithDefinitions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extendedFullDefinition*)
(* Expressions like `LLMTool` and `LLMConfiguration` have the `NOENTRY` flag. This blocks the pattern matcher from
   discovering symbols that are contained within them. Since `LLMTool` in particular typically contains user-defined
   symbols, we need to remove this flag so that `ExtendedFullDefinition` finds them. This is an alternate version
   of `ExtendedFullDefinition` that does this automatically by recursively unpacking NOENTRY subexpressions and
   generating the definition list. *)
extendedFullDefinition // beginDefinition;
extendedFullDefinition // Attributes = { HoldFirst };

extendedFullDefinition[ expression_, opts: OptionsPattern[ Language`ExtendedFullDefinition ] ] := Enclose[
    ConfirmMatch[
        FixedPoint[
            Function[ expr, extendedFullDefinition0[ expr, opts ], HoldAllComplete ],
            HoldComplete @ expression,
            (* Set a maximum recursion depth as a safety measure: *)
            Replace[ Quiet @ Ceiling[ $RecursionLimit / 4 ], Except[ _Integer? Positive ] -> 100 ]
        ],
        _Language`DefinitionList,
        "DefinitionList"
    ],
    throwInternalFailure
];

extendedFullDefinition // endDefinition;


extendedFullDefinition0 // beginDefinition;
extendedFullDefinition0 // Attributes = { HoldAllComplete };

extendedFullDefinition0[ expression_, opts: OptionsPattern[ Language`ExtendedFullDefinition ] ] :=
    With[ { unpacked = unpackNoEntry @ expression },
        Language`ExtendedFullDefinition[ unpacked, opts ]
    ];

extendedFullDefinition0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unpackNoEntry*)
(* This utility finds subexpressions with the `NOENTRY` flag and reconstructs them without evaluation so that the flag
   does not get set. Note: The `expression` argument should usually be held to prevent re-evaluation. *)
unpackNoEntry // beginDefinition;

unpackNoEntry[ expression_ ] :=
    Module[ { wrapper, unpacked },
        (* A temporary wrapper is used to prevent re-evaluation of the subexpression: *)
        SetAttributes[ wrapper, HoldAllComplete ];
        (* Deconstruct the NOENTRY subexpressions and wrap the heads to prevent re-evaluation: *)
        unpacked = expression //. e: f_[ a___ ] /; System`Private`HoldNoEntryQ @ e :> wrapper[ f ][ a ];
        (* Remove the temporary wrapper and return the unpacked expression: *)
        unpacked //. wrapper[ f_ ] :> f
    ];

unpackNoEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*LLMKit Information*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmKitSubscribedQ*)
llmKitSubscribedQ // beginDefinition;
llmKitSubscribedQ[ ] := llmKitSubscribedQ @ getLLMKitInfo[ ];
llmKitSubscribedQ[ KeyValuePattern[ "userHasSubscription" -> bool: True|False ] ] := bool;
llmKitSubscribedQ[ _ ] := False;
llmKitSubscribedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getLLMKitInfo*)
getLLMKitInfo // beginDefinition;

getLLMKitInfo[ ] :=
    getLLMKitInfo[ $CloudConnected, $CloudUserID, $CloudBase ];

getLLMKitInfo[ False, _, _ ] :=
    $fallBackLLMKitInfo;

getLLMKitInfo[ connected_, user_, cloudBase_ ] := Enclose[
    Module[ { info },
        LLMSynthesize;
        ConfirmQuiet[ Wolfram`LLMFunctions`Common`UpdateLLMKitInfo[ ], All, "UpdateLLMKitInfo" ];
        chatbookVersionCheck[ ];

        info = ConfirmMatch[
            <| "connected" -> connected, Wolfram`LLMFunctions`Common`$LLMKitInfo |>,
            KeyValuePattern @ { "userHasSubscription" -> True|False, "buyNowUrl" -> _String },
            "LLMKitInfo"
        ];

        If[ TrueQ @ info[ "userHasSubscription" ],
            Wolfram`LLMFunctions`Common`$LLMKitSubscribed = True;
            getLLMKitInfo[ connected, user, cloudBase ] = info,
            info
        ]
    ],

    $fallBackLLMKitInfo &
];

getLLMKitInfo // endDefinition;


$fallBackLLMKitInfo := <|
    "connected"           -> $CloudConnected,
    "service"             -> "llmkit",
    "currentProvider"     -> "AzureOpenAI",
    "userHasSubscription" -> False,
    "learnMoreUrl"        -> "https://www.wolfram.com/notebook-assistant-llm-kit",
    "buyNowUrl"           -> "https://www.wolfram.com/notebook-assistant-llm-kit#pricing"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmKitUsageLimitFailureQ*)

(* Detects the Failure that LLMKit-backed services (e.g. RelatedWolframAlphaResults, RelatedDocumentation)
   return when the user has exhausted their LLMKit usage/credit allotment. The service responds with HTTP 429
   and an error code such as "credits-per-month-limit-exceeded". The markers can be buried inside nested
   Failure objects, so we search the whole expression rather than matching a fixed shape. *)
llmKitUsageLimitFailureQ // beginDefinition;

llmKitUsageLimitFailureQ[ failure_Failure ] := Or[
    ! FreeQ[ failure, KeyValuePattern[ "StatusCode" -> 429 ] ],
    ! FreeQ[ failure, _String? usageLimitCodeQ ]
];

llmKitUsageLimitFailureQ[ _ ] := False;

llmKitUsageLimitFailureQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*usageLimitCodeQ*)
usageLimitCodeQ // beginDefinition;
usageLimitCodeQ[ s_String ] := StringContainsQ[ s, "credits" | "limit-exceeded" | "quota" | "usage-limit", IgnoreCase -> True ];
usageLimitCodeQ[ _ ] := False;
usageLimitCodeQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmKitUsageLimitMessage*)

$defaultUsageLimitMessage = "The LLMKit usage limit has been exceeded.";

(* Extracts the human-readable error message from an LLMKit usage-limit Failure, falling back to a generic
   message when the service response does not include one. *)
llmKitUsageLimitMessage // beginDefinition;

llmKitUsageLimitMessage[ failure_Failure ] := Replace[
    FirstCase[
        failure,
        KeyValuePattern[ "error" -> KeyValuePattern[ "message" -> message_String ] ] :> message,
        Missing[ "NotFound" ],
        Infinity
    ],
    Except[ _String ] :> $defaultUsageLimitMessage
];

llmKitUsageLimitMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Dependencies*)
$minimumChatbookVersion = "2.3.0";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatbookVersionCheck*)
chatbookVersionCheck // beginDefinition;
chatbookVersionCheck[ ] := chatbookVersionCheck[ ] = chatbookVersionCheck0 @ PacletObject[ "Wolfram/Chatbook" ];
chatbookVersionCheck // endDefinition;


chatbookVersionCheck0 // beginDefinition;

chatbookVersionCheck0[ paclet_PacletObject ] :=
    chatbookVersionCheck0 @ paclet[ "Version" ];

chatbookVersionCheck0[ $minimumChatbookVersion ] :=
    True;

chatbookVersionCheck0[ version_String ] /; PacletNewerQ[ version, $minimumChatbookVersion ] :=
    True;

chatbookVersionCheck0[ other_ ] := Enclose[
    Module[ { installed, version },

        installed = ConfirmBy[
            PacletInstall[ "Wolfram/Chatbook", UpdatePacletSites -> True ],
            PacletObjectQ,
            "PacletInstall"
        ];

        version = ConfirmBy[ installed[ "Version" ], StringQ, "Version" ];

        ConfirmAssert[
            version === $minimumChatbookVersion || PacletNewerQ[ version, $minimumChatbookVersion ],
            "PacletNewerQ"
        ];

        Block[ { $ContextPath }, Get[ "Wolfram`Chatbook`" ] ];

        True
    ],
    throwInternalFailure
];

chatbookVersionCheck0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Regular Expressions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toJSRegex*)

(* Convert an ICU/PCRE-flavored regex (as produced by StringPattern`PatternConvert) into a
   best-effort ECMA 262 pattern suitable for JSON Schema "pattern" fields consumed by
   JavaScript-based validators.

   Intentional non-goals and accepted limitations:

   - No attempt to simulate multiline `^`/`$`: if the original had `m` and contained raw `^`/`$`
     (from `StartOfLine`/`EndOfLine`), the converted pattern treats them as start/end-of-string in JS.
     Schema patterns rarely use line anchors, and any workaround (`(?:^|(?<=\n))`) bloats output and risks
     validator compatibility issues.

   - PCRE-only constructs that pass through untouched from user-supplied `RegularExpression[...]` bodies
     (atomic groups `(?>...)`, possessive quantifiers `*+`, named groups `(?P<x>...)`) are left alone.
     Those are user escape hatches; if a user puts PCRE-only syntax in a schema pattern, they own the compatibility.

   - `u`-flag is not available to us - we are producing bare pattern strings for JSON Schema consumers who may or may
     not set it.
*)

toJSRegex // beginDefinition;

toJSRegex[ regex_String ] := Enclose[
    Module[ { body, hadDotAll },
        { body, hadDotAll } = ConfirmMatch[ extractLeadingRegexFlags @ regex, { _String, True|False }, "Extract" ];

        body = ConfirmBy[ stripInnerRegexModifiers @ body, StringQ, "StripInnerRegexModifiers" ];
        body = ConfirmBy[ convertPOSIXClasses @ body     , StringQ, "ConvertPOSIXClasses"      ];
        body = ConfirmBy[ convertPCREAnchors @ body      , StringQ, "ConvertPCREAnchors"       ];
        body = ConfirmBy[ convertUnicodeEscapes @ body   , StringQ, "ConvertUnicodeEscapes"    ];

        If[ hadDotAll,
            ConfirmBy[ convertDotAllDots @ body, StringQ, "ConvertDotAllDots" ],
            body
        ]
    ],
    throwInternalFailure
];

toJSRegex // endDefinition;

(* TODO: When creating an MCP server, we could attempt this conversion and issue a warning message if there are any
   unhandled patterns. This would only be a warning since many schema validators will still accept the pattern as-is. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractLeadingRegexFlags*)
(* Strip a leading "(?flags)" group and return { body, hadDotAll }. *)
extractLeadingRegexFlags // beginDefinition;

extractLeadingRegexFlags[ s_String ] :=
    Module[ { match },
        match = StringCases[
            s,
            StartOfString ~~ "(?" ~~ flags: (LetterCharacter..) ~~ ")" ~~ rest___ :>
                { flags, rest },
            1
        ];
        If[ match === { },
            { s, False },
            { match[[ 1, 2 ]], StringContainsQ[ match[[ 1, 1 ]], "s" ] }
        ]
    ];

extractLeadingRegexFlags // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stripInnerRegexModifiers*)
(* Strip the scope-less inline modifier prefixes that PatternConvert inserts at the start of a
   "(?:...)" wrapper around RegularExpression[] contents. Matching only the "(?:(?-...)" wrapper
   form avoids silently altering mid-pattern modifiers in user-supplied regexes. *)
stripInnerRegexModifiers // beginDefinition;

stripInnerRegexModifiers[ s_String ] := StringReplace[
    s,
    {
        "(?:(?-m-s)" -> "(?:",
        "(?:(?-s-m)" -> "(?:",
        "(?:(?-ms)"  -> "(?:",
        "(?:(?-sm)"  -> "(?:",
        "(?:(?-s)"   -> "(?:",
        "(?:(?-m)"   -> "(?:"
    }
];

stripInnerRegexModifiers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertPOSIXClasses*)
(* Map POSIX character class tokens like "[:alpha:]" to JS-compatible bodies. By replacing only
   the inner token (not the outer brackets), "[[:alpha:]]" becomes "[a-zA-Z]" and nested forms
   like "[[:alpha:][:digit:]]" become "[a-zA-Z0-9]". *)
convertPOSIXClasses // beginDefinition;

convertPOSIXClasses[ s_String ] := StringReplace[
    s,
    {
        "[:alpha:]"  -> "a-zA-Z",
        "[:digit:]"  -> "0-9",
        "[:alnum:]"  -> "a-zA-Z0-9",
        "[:upper:]"  -> "A-Z",
        "[:lower:]"  -> "a-z",
        "[:xdigit:]" -> "0-9a-fA-F",
        "[:space:]"  -> "\\s",
        "[:blank:]"  -> " \\t",
        "[:cntrl:]"  -> "\\x00-\\x1F\\x7F",
        "[:print:]"  -> "\\x20-\\x7E",
        "[:graph:]"  -> "\\x21-\\x7E",
        "[:punct:]"  -> "!-/:-@[-`{-~"
    }
];

convertPOSIXClasses // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertPCREAnchors*)
(* "\A" and "\z"/"\Z" are PCRE start/end-of-string anchors with no JS equivalent. JS "^"/"$"
   mean start/end-of-string when the regex has no "m" flag - which is our target since we
   strip all flags for JSON Schema output. *)
convertPCREAnchors // beginDefinition;

convertPCREAnchors[ s_String ] := StringReplace[
    s,
    { "\\A" -> "^", "\\z" -> "$", "\\Z" -> "$" }
];

convertPCREAnchors // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertUnicodeEscapes*)
(* Convert "\x{HEX}" to the narrowest JS-valid form. "\xNN" and "\uNNNN" work without the u
   flag; supplementary code points (> U+FFFF) are emitted as UTF-16 surrogate pairs so the
   output stays valid without requiring the JS "u" flag. *)
convertUnicodeEscapes // beginDefinition;

convertUnicodeEscapes[ s_String ] := StringReplace[
    s,
    "\\x{" ~~ hex: (HexadecimalCharacter..) ~~ "}" :> convertHexEscape @ hex
];

convertUnicodeEscapes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertHexEscape*)
convertHexEscape // beginDefinition;

(* Branch on the parsed code point, not the hex payload length. Leading zeros are valid in
   \x{...} (e.g. "\x{0000A0}" is U+00A0), so classifying by string length would mis-route
   zero-padded BMP escapes into the surrogate-pair path and fail the supplementary-range
   assert. *)
convertHexEscape[ hex_String ] := With[ { cp = FromDigits[ hex, 16 ] },
    Which[
        cp <= 16^^FF  , "\\x" <> ToUpperCase @ IntegerString[ cp, 16, 2 ],
        cp <= 16^^FFFF, "\\u" <> ToUpperCase @ IntegerString[ cp, 16, 4 ],
        True          , supplementaryToSurrogatePair @ hex
    ]
];

convertHexEscape // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*supplementaryToSurrogatePair*)
(* Encode a supplementary-plane code point (U+10000..U+10FFFF) as a UTF-16 surrogate pair of
   "\uXXXX" escapes. JS regexes match a supplementary character via its surrogate pair even
   without the "u" flag, so this keeps output valid for JSON Schema validators that do not set
   it. *)
supplementaryToSurrogatePair // beginDefinition;

supplementaryToSurrogatePair[ hex_String ] := Enclose[
    Module[ { cp, offset, hi, lo },
        cp = FromDigits[ hex, 16 ];
        ConfirmAssert[ 16^^10000 <= cp <= 16^^10FFFF, "SupplementaryRange" ];
        offset = cp - 16^^10000;
        hi = 16^^D800 + BitShiftRight[ offset, 10 ];
        lo = 16^^DC00 + BitAnd[ offset, 16^^3FF ];
        "\\u" <> ToUpperCase @ IntegerString[ hi, 16, 4 ] <>
            "\\u" <> ToUpperCase @ IntegerString[ lo, 16, 4 ]
    ],
    throwInternalFailure
];

supplementaryToSurrogatePair // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertDotAllDots*)
(* Replace unescaped "." outside character classes with "[\s\S]" to preserve dotall semantics
   of the stripped outer "(?s)" flag. Walks the string once tracking escape and class state;
   leaves "\.", "[.]", and dots inside "[...]" untouched. *)
convertDotAllDots // beginDefinition;

convertDotAllDots[ s_String ] :=
    Module[ { inClass = False, escaped = False },
        StringJoin @ Map[
            Function[ c,
                Which[
                    escaped     , escaped = False; c,
                    c === "\\"  , escaped = True; c,
                    inClass     , If[ c === "]", inClass = False ]; c,
                    c === "["   , inClass = True; c,
                    c === "."   , "[\\s\\S]",
                    True        , c
                ]
            ],
            Characters @ s
        ]
    ];

convertDotAllDots // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
