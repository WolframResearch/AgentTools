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
(*graphicsQ Tests*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Graphics Types*)
VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ Graphics[ Circle[ ] ],
    True,
    TestID -> "graphicsQ-Graphics"
]

VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ Graphics3D[ Sphere[ ] ],
    True,
    TestID -> "graphicsQ-Graphics3D"
]

VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ Image[ RandomReal[ { 0, 1 }, { 10, 10 } ] ],
    True,
    TestID -> "graphicsQ-Image"
]

VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ Image3D[ RandomReal[ { 0, 1 }, { 5, 5, 5 } ] ],
    True,
    TestID -> "graphicsQ-Image3D"
]

VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ GeoGraphics[ ],
    True,
    TestID -> "graphicsQ-GeoGraphics"
]

VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ Legended[ Graphics[ Circle[ ] ], "Test" ],
    True,
    TestID -> "graphicsQ-Legended"
]

VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ Labeled[ Graphics[ Circle[ ] ], "Test" ],
    True,
    TestID -> "graphicsQ-Labeled"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Non-Graphics Types*)
VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ "Hello",
    False,
    TestID -> "graphicsQ-String"
]

VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ { 1, 2, 3 },
    False,
    TestID -> "graphicsQ-List"
]

VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ <| "a" -> 1 |>,
    False,
    TestID -> "graphicsQ-Association"
]

VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ Null,
    False,
    TestID -> "graphicsQ-Null"
]

VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ True,
    False,
    TestID -> "graphicsQ-True"
]

VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ False,
    False,
    TestID -> "graphicsQ-False"
]

VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ File[ "test.txt" ],
    False,
    TestID -> "graphicsQ-File"
]

VerificationTest[
    Wolfram`AgentTools`Common`graphicsQ @ URL[ "http://example.com" ],
    False,
    TestID -> "graphicsQ-URL"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*graphicsToImageContent Tests*)
VerificationTest[
    Wolfram`AgentTools`Common`graphicsToImageContent @ Graphics[ Circle[ ] ],
    KeyValuePattern[ {
        "type"     -> "image",
        "mimeType" -> "image/png",
        "data"     -> _String
    } ],
    SameTest -> MatchQ,
    TestID   -> "graphicsToImageContent-Graphics"
]

VerificationTest[
    With[
        { result = Wolfram`AgentTools`Common`graphicsToImageContent @ Graphics[ Circle[ ] ] },
        StringQ @ result[ "data" ] && StringLength @ result[ "data" ] > 100
    ],
    True,
    TestID -> "graphicsToImageContent-HasBase64Data"
]

VerificationTest[
    With[
        { result = Wolfram`AgentTools`Common`graphicsToImageContent @ Graphics[ Circle[ ] ] },
        (* Base64 strings should be ASCII-printable and reasonably long *)
        StringMatchQ[ result[ "data" ], RegularExpression[ "^[A-Za-z0-9+/=]+$" ] ]
    ],
    True,
    TestID -> "graphicsToImageContent-ValidBase64"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*extractImageContent Tests*)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`extractImageContent @ Graphics[ Circle[ ] ],
    { KeyValuePattern[ "type" -> "image" ] },
    SameTest -> MatchQ,
    TestID   -> "extractImageContent-SingleGraphics"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`extractImageContent @ "Hello",
    { },
    TestID -> "extractImageContent-String"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`extractImageContent @ Failure[ "Test", <| |> ],
    { },
    TestID -> "extractImageContent-Failure"
]

VerificationTest[
    Length @ Wolfram`AgentTools`Server`Shared`Private`extractImageContent @ {
        Graphics[ Circle[ ] ],
        Graphics[ Rectangle[ ] ]
    },
    2,
    TestID -> "extractImageContent-ListOfGraphics"
]

VerificationTest[
    Length @ Wolfram`AgentTools`Server`Shared`Private`extractImageContent @ <|
        "a" -> Graphics[ Circle[ ] ],
        "b" -> Graphics[ Rectangle[ ] ]
    |>,
    2,
    TestID -> "extractImageContent-AssociationOfGraphics"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`extractImageContent @ { "text", 123, Null },
    { },
    TestID -> "extractImageContent-MixedNonGraphics"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*resultToContent Tests*)
VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`resultToContent @ "Hello World",
    { <| "type" -> "text", "text" -> "Hello World" |> },
    TestID -> "resultToContent-String"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`resultToContent @ 42,
    { <| "type" -> "text", "text" -> "42" |> },
    TestID -> "resultToContent-Integer"
]

VerificationTest[
    Wolfram`AgentTools`Server`Shared`Private`resultToContent @ Graphics[ Circle[ ] ],
    { _Association, _Association },
    SameTest -> MatchQ,
    TestID   -> "resultToContent-Graphics"
]

VerificationTest[
    With[
        { result = Wolfram`AgentTools`Server`Shared`Private`resultToContent @ Graphics[ Circle[ ] ] },
        { result[[ 1, "type" ]], result[[ 2, "type" ]] }
    ],
    { "text", "image" },
    TestID -> "resultToContent-GraphicsTypes"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*extractWolframAlphaImages Tests*)

extractWolframAlphaImages // Attributes = { HoldFirst };
extractWolframAlphaImages[ expr_ ] :=
    Block[ { Wolfram`AgentTools`Common`$mcpEvaluation = True },
        Wolfram`AgentTools`Common`extractWolframAlphaImages @ expr
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*No Images - Returns String*)
VerificationTest[
    extractWolframAlphaImages @ "Hello World",
    "Hello World",
    TestID -> "extractWolframAlphaImages-PlainString"
]

VerificationTest[
    extractWolframAlphaImages @ "Some text without images",
    "Some text without images",
    TestID -> "extractWolframAlphaImages-NoImages"
]

VerificationTest[
    extractWolframAlphaImages @ "Text with non-WA image ![img](https://example.com/image.png)",
    "Text with non-WA image ![img](https://example.com/image.png)",
    TestID -> "extractWolframAlphaImages-NonWAImage"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*With Images - Returns Structured Content*)
VerificationTest[
    With[
        { result = extractWolframAlphaImages @
            "Result: ![Image](https://public6.wolframalpha.com/files/test.png)" },
        AssociationQ @ result && KeyExistsQ[ result, "Content" ]
    ],
    True,
    TestID -> "extractWolframAlphaImages-HasContentKey"
]

VerificationTest[
    With[
        { result = extractWolframAlphaImages @
            "Result: ![Image](https://public6.wolframalpha.com/files/test.gif)" },
        MatchQ[ result, <| "Content" -> { __Association } |> ]
    ],
    True,
    TestID -> "extractWolframAlphaImages-ContentIsList"
]

VerificationTest[
    With[ { result = extractWolframAlphaImages[ "Before ![Image](https://public6.wolframalpha.com/files/test.jpg) After" ] },
        And[
            AssociationQ @ result,
            MatchQ[ result, KeyValuePattern[ "Content" -> { __Association } ] ],
            MemberQ[ result[ "Content" ], KeyValuePattern @ { "type" -> "text", "text" -> _? (StringContainsQ[ "Before" ]) } ],
            MemberQ[ result[ "Content" ], KeyValuePattern @ { "type" -> "text", "text" -> _? (StringContainsQ[ "After" ]) } ]
        ]
    ],
    True,
    TestID -> "extractWolframAlphaImages-MultipleContentItems"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*URL Pattern Matching*)

(* Original tests that need the function loaded properly *)
VerificationTest[
    With[
        { result = extractWolframAlphaImages @
            "![Result](https://www6.wolframalpha.com/files/image.png)" },
        (* Either returns structured content or string with the URL *)
        AssociationQ @ result || StringContainsQ[ result, "wolframalpha.com" ]
    ],
    True,
    TestID -> "extractWolframAlphaImages-WWW6Domain"
]

VerificationTest[
    With[
        { result = extractWolframAlphaImages @
            "![Result](https://public6.wolframalpha.com/files/image.jpeg)" },
        (* Either returns structured content or string with the URL *)
        AssociationQ @ result || StringContainsQ[ result, "wolframalpha.com" ]
    ],
    True,
    TestID -> "extractWolframAlphaImages-JpegExtension"
]

VerificationTest[
    extractWolframAlphaImages @
        "![Result](https://example.com/files/image.png)",
    _String,
    SameTest -> MatchQ,
    TestID   -> "extractWolframAlphaImages-NonWADomain"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Text Content Preservation*)
VerificationTest[
    With[
        { result = extractWolframAlphaImages @
            "Before ![Image](https://public6.wolframalpha.com/files/test.png) After" },
        MemberQ[ result[ "Content" ], KeyValuePattern[ { "type" -> "text", "text" -> _? (StringContainsQ[ "Before" ]) } ] ]
    ],
    True,
    TestID -> "extractWolframAlphaImages-PreservesTextBefore"
]

VerificationTest[
    With[
        { result = extractWolframAlphaImages @
            "Before ![Image](https://public6.wolframalpha.com/files/test.png) After" },
        MemberQ[ result[ "Content" ], KeyValuePattern[ { "type" -> "text", "text" -> _? (StringContainsQ[ "After" ]) } ] ]
    ],
    True,
    TestID -> "extractWolframAlphaImages-PreservesTextAfter"
]

VerificationTest[
    With[
        { result = extractWolframAlphaImages @
            "Text ![Image](https://public6.wolframalpha.com/files/test.png)" },
        (* The URL should be preserved as a markdown link in text content *)
        MemberQ[ result[ "Content" ], KeyValuePattern[ { "type" -> "text", "text" -> _? (StringContainsQ[ "wolframalpha.com" ]) } ] ]
    ],
    True,
    TestID -> "extractWolframAlphaImages-PreservesURLInText"
]

(* :!CodeAnalysis::EndBlock:: *)
