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
(*Helper Functions*)

(* Setup a temporary file to use for testing YAML I/O *)
testYAMLFile = Function[
    File @ FileNameJoin @ { $TemporaryDirectory, StringJoin[ "yaml_test_", CreateUUID[ ], ".yaml" ] }
];

(* Clean up any test files that might be created *)
cleanupTestFiles = Function[ files,
    DeleteFile /@ Select[ Flatten[ { files } ], FileExistsQ ]
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*exportYAMLString -- Scalars*)
VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ "hello" ],
    "hello",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-PlainString"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ "a: b" ],
    "\"a: b\"",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-StringWithColon"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ "true" ],
    "\"true\"",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-LiteralLikeString"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ "42" ],
    "\"42\"",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-NumericLikeString"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ 42 ],
    "42",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-Integer"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ True ],
    "true",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-True"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ False ],
    "false",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-False"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ Null ],
    "null",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-Null"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ 3.14 ],
    "3.14",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-RealSimple"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ 1.5*^20 ],
    "1.5e20",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-RealLargeExponent"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ 1.0*^-10 ],
    "1.0e-10",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-RealSmallExponent"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ 100. ],
    "1.0e2",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-RealWholeNumber"
]

VerificationTest[
    Module[ { yaml, parsed },
        yaml = Wolfram`AgentTools`Common`exportYAMLString[ 1.5*^20 ];
        parsed = Wolfram`AgentTools`Common`importYAMLString[ "x: " <> yaml ];
        parsed[ "x" ] == 1.5*^20
    ],
    True,
    SameTest -> Equal,
    TestID   -> "RoundTrip-RealLargeExponent"
]

VerificationTest[
    Module[ { yaml, parsed },
        yaml = Wolfram`AgentTools`Common`exportYAMLString[ <| "a" -> 1.5*^20, "b" -> 1.0*^-10, "c" -> 100., "d" -> 3.14 |> ];
        parsed = Wolfram`AgentTools`Common`importYAMLString @ yaml;
        parsed[ "a" ] == 1.5*^20 && parsed[ "b" ] == 1.0*^-10 && parsed[ "c" ] == 100. && parsed[ "d" ] == 3.14
    ],
    True,
    SameTest -> Equal,
    TestID   -> "RoundTrip-RealsInMapping"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*exportYAMLString -- Block Mappings*)
VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ <| "a" -> 1 |> ],
    "a: 1",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-SingleKeyMapping"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ <| "a" -> 1, "b" -> "hello" |> ],
    "a: 1\nb: hello",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-TwoKeyMapping"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ <| "a" -> <| "b" -> 1 |> |> ],
    "a:\n  b: 1",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-NestedMapping"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ <| "a" -> <| "b" -> <| "c" -> "deep" |> |> |> ],
    "a:\n  b:\n    c: deep",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-DeeplyNestedMapping"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ <| |> ],
    "{}",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-EmptyMapping"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*exportYAMLString -- Sequences*)
VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ { "a", "b", "c" } ],
    "- a\n- b\n- c",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-BlockSequenceOfStrings"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ {  } ],
    "[]",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-EmptySequence"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ <| "args" -> { "a", "b", "c" } |> ],
    "args: [a, b, c]",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-FlowSequenceUnderKey"
]

VerificationTest[
    Wolfram`AgentTools`Common`exportYAMLString[ <| "args" -> {  } |> ],
    "args: []",
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-EmptyFlowSequenceUnderKey"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*exportYAMLString -- Goose-Shaped Sample*)
VerificationTest[
    Module[ { yaml },
        yaml = Wolfram`AgentTools`Common`exportYAMLString[ <|
            "extensions" -> <|
                "Wolfram" -> <|
                    "name"    -> "Wolfram",
                    "cmd"     -> "/path/to/wolfram",
                    "args"    -> { "-run", "test" },
                    "enabled" -> True,
                    "envs"    -> <| "K" -> "V" |>,
                    "type"    -> "stdio",
                    "timeout" -> 300
                |>
            |>
        |> ];
        AllTrue[
            { "extensions:", "cmd:", "enabled: true", "type: stdio", "timeout: 300" },
            StringContainsQ[ yaml, # ] &
        ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "ExportYAMLString-GooseShapedSample"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*importYAMLString -- Scalars*)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: hello" ],
    <| "a" -> "hello" |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-PlainString"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: 42" ],
    <| "a" -> 42 |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-Integer"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: 3.14" ],
    <| "a" -> 3.14 |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-Real"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: -2.5e3" ],
    <| "a" -> -2500.0 |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-RealWithExponent"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: 1e3" ],
    <| "a" -> 1000.0 |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-RealExponentOnly"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: -2E10" ],
    <| "a" -> -2.0*^10 |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-RealExponentOnlyCapitalE"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: 5e-2" ],
    <| "a" -> 0.05 |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-RealExponentOnlyNegativeExp"
]

VerificationTest[
    Head @ Lookup[ Wolfram`AgentTools`Common`importYAMLString[ "a: 1e3" ], "a" ],
    Real,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-RealExponentOnlyHead"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: true\nb: false" ],
    <| "a" -> True, "b" -> False |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-Booleans"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: null\nb: ~" ],
    <| "a" -> Null, "b" -> Null |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-Null"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: \"hello world\"" ],
    <| "a" -> "hello world" |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-DoubleQuotedString"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: \"line1\\nline2\\ttab\"" ],
    <| "a" -> "line1\nline2\ttab" |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-DoubleQuotedEscapes"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: 'it''s'" ],
    <| "a" -> "it's" |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-SingleQuotedEscape"
]

VerificationTest[
    (* "#" inside a single-quoted scalar containing "''" must not be stripped as a
       comment.  Previously stripCommentOutsideQuotes toggled inSingle off on any
       "'" character, losing track of the quoted span across the "''" escape. *)
    Wolfram`AgentTools`Common`importYAMLString[ "a: 'it''s # not a comment'" ],
    <| "a" -> "it's # not a comment" |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-SingleQuotedEscapeWithHash"
]

VerificationTest[
    (* Quoted "true" stays a string, not a boolean *)
    Wolfram`AgentTools`Common`importYAMLString[ "a: \"true\"" ],
    <| "a" -> "true" |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-QuotedLiteralLooksLikeBoolean"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*importYAMLString -- Block Mappings*)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: 1\nb: 2" ],
    <| "a" -> 1, "b" -> 2 |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-TwoKeyMapping"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a:\n  b: deep" ],
    <| "a" -> <| "b" -> "deep" |> |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-NestedMapping"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a:\n    b:\n        c: very-deep\n    d: shallow" ],
    <| "a" -> <| "b" -> <| "c" -> "very-deep" |>, "d" -> "shallow" |> |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-FourSpaceIndent"
]

VerificationTest[
    (* Quoted key with a colon-bearing value *)
    Wolfram`AgentTools`Common`importYAMLString[ "\"MCP_SERVER_NAME\": \"foo:bar\"" ],
    <| "MCP_SERVER_NAME" -> "foo:bar" |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-QuotedKeyColonValue"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*importYAMLString -- Block Sequences*)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "args:\n  - one\n  - two\n  - three" ],
    <| "args" -> { "one", "two", "three" } |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-BlockSequence"
]

(* Inline mapping items: "- key: value" *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "items:\n  - name: Alice\n    age: 30\n  - name: Bob\n    age: 25" ],
    <| "items" -> { <| "name" -> "Alice", "age" -> 30 |>, <| "name" -> "Bob", "age" -> 25 |> } |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-InlineSequenceMapping"
]

(* Quoted scalars containing colons must NOT be parsed as inline mappings *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "- \"a: b\"\n- \"c: d\"" ],
    { "a: b", "c: d" },
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-QuotedScalarsWithColons"
]

(* Compact block sequence: YAML 1.2 allows sequence items at the same indent
   as their parent mapping key (the dominant style in GitHub Actions workflows). *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "args:\n- one\n- two\n- three" ],
    <| "args" -> { "one", "two", "three" } |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-CompactBlockSequence"
]

(* Compact sequence with inline mapping items (GitHub Actions `steps:` layout). *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "steps:\n- name: Checkout\n  uses: actions/checkout@v4\n- name: Build\n  run: wolframscript -f foo.wls" ],
    <| "steps" -> {
        <| "name" -> "Checkout", "uses" -> "actions/checkout@v4" |>,
        <| "name" -> "Build", "run" -> "wolframscript -f foo.wls" |>
    } |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-CompactSequenceWithInlineMapping"
]

(* A compact sequence must not swallow the sibling mapping key that follows. *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a:\n- x\n- y\nb: 1" ],
    <| "a" -> { "x", "y" }, "b" -> 1 |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-CompactSequenceThenSiblingKey"
]

(* Compact sequence nested inside an indented mapping. *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "outer:\n  a:\n  - x\n  - y\n  b: 1" ],
    <| "outer" -> <| "a" -> { "x", "y" }, "b" -> 1 |> |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-NestedCompactSequence"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*importYAMLString -- Flow Sequences*)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "args: [1, 2, 3]" ],
    <| "args" -> { 1, 2, 3 } |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-NumericFlowSequence"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "args: [a, 'b, c', d]" ],
    <| "args" -> { "a", "b, c", "d" } |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-FlowSequenceQuotedComma"
]

VerificationTest[
    (* "," inside a single-quoted flow element containing "''" must not trigger a
       split.  Previously splitFlowElements toggled inSingle off on any "'"
       character, losing track of the quoted span across the "''" escape. *)
    Wolfram`AgentTools`Common`importYAMLString[ "args: [a, 'it''s, crazy', b]" ],
    <| "args" -> { "a", "it's, crazy", "b" } |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-FlowSequenceSingleQuotedEscapeWithComma"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "args: []" ],
    <| "args" -> {  } |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-EmptyFlowSequence"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*importYAMLString -- Block Scalars*)
(* Literal block scalar with default ("clip") chomping. *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "run: |\n  echo one\n  echo two" ],
    <| "run" -> "echo one\necho two\n" |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-LiteralBlockScalarClip"
]

(* Literal block scalar with strip chomping ("|-"): no trailing newline. *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "run: |-\n  echo one\n  echo two" ],
    <| "run" -> "echo one\necho two" |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-LiteralBlockScalarStrip"
]

(* Literal block scalar with keep chomping ("|+"): preserve trailing blank
   lines between the body and the next sibling. *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: |+\n  foo\n\nb: 1" ],
    <| "a" -> "foo\n\n", "b" -> 1 |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-LiteralBlockScalarKeep"
]

(* Block scalar content containing "#" must not be mistaken for a comment. *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "run: |\n  echo hello\n  # a shell comment\n  ls" ],
    <| "run" -> "echo hello\n# a shell comment\nls\n" |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-BlockScalarPreservesHash"
]

(* Block scalar under a sequence item (GitHub Actions `steps:` layout). *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "steps:\n- name: Build\n  run: |\n    echo one\n    echo two\n- name: Next\n  run: echo three" ],
    <| "steps" -> {
        <| "name" -> "Build", "run" -> "echo one\necho two\n" |>,
        <| "name" -> "Next",  "run" -> "echo three" |>
    } |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-BlockScalarInStepsSequence"
]

(* Block scalar immediately followed by a sibling key at the parent indent. *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: |\n  foo\n  bar\nb: 1" ],
    <| "a" -> "foo\nbar\n", "b" -> 1 |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-BlockScalarThenSibling"
]

(* Folded block scalar: non-empty lines joined with spaces. *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "description: >\n  one\n  two\n  three" ],
    <| "description" -> "one two three\n" |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-FoldedBlockScalarBasic"
]

(* Blank line inside a folded scalar becomes a literal newline. *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "description: >\n  one\n  two\n\n  three" ],
    <| "description" -> "one two\nthree\n" |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-FoldedBlockScalarBlankLine"
]

(* Regression: every workflow file under .github/workflows must round-trip
   through importYAML without failure.  These files exercise the combined
   "compact block sequence" + "literal block scalar" behaviors that a real
   GitHub Actions workflow depends on. *)
VerificationTest[
    Module[ { dir, files, results },
        dir = FileNameJoin @ {
            DirectoryName[ DirectoryName @ $TestFileName ],
            ".github", "workflows"
        };
        files = FileNames[ "*.yml", dir ];
        results = Wolfram`AgentTools`Common`catchAlways @
            Wolfram`AgentTools`Common`importYAML @ # & /@ files;
        AllTrue[ results, AssociationQ ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "ImportYAML-WorkflowFilesRoundTrip"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*importYAMLString -- Comments and Blank Lines*)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "# header comment\na: 1\nb: 2" ],
    <| "a" -> 1, "b" -> 2 |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-LeadingComment"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: 1 # trailing comment\nb: 2" ],
    <| "a" -> 1, "b" -> 2 |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-TrailingComment"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "a: 1\n\n\nb: 2" ],
    <| "a" -> 1, "b" -> 2 |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-BlankLines"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "" ],
    <| |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-Empty"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Round-Trip Tests*)
VerificationTest[
    Module[ { data, yaml, parsed },
        data = <| "a" -> 1, "b" -> "hello", "c" -> True, "d" -> Null |>;
        yaml = Wolfram`AgentTools`Common`exportYAMLString @ data;
        parsed = Wolfram`AgentTools`Common`importYAMLString @ yaml;
        parsed === data
    ],
    True,
    SameTest -> Equal,
    TestID   -> "RoundTrip-FlatMapping"
]

VerificationTest[
    Module[ { data, yaml, parsed },
        data = <|
            "extensions" -> <|
                "Wolfram" -> <|
                    "name"    -> "Wolfram",
                    "cmd"     -> "/path/to/wolfram",
                    "args"    -> { "-run", "test", "-noinit" },
                    "enabled" -> True,
                    "envs"    -> <|
                        "MCP_SERVER_NAME" -> "WolframLanguage",
                        "WOLFRAM_BASE"    -> "/path/to/base"
                    |>,
                    "type"    -> "stdio",
                    "timeout" -> 300
                |>
            |>
        |>;
        yaml = Wolfram`AgentTools`Common`exportYAMLString @ data;
        parsed = Wolfram`AgentTools`Common`importYAMLString @ yaml;
        parsed === data
    ],
    True,
    SameTest -> Equal,
    TestID   -> "RoundTrip-GooseShaped"
]

(* Sequence of multi-key associations must round-trip cleanly. *)
VerificationTest[
    Module[ { data, yaml, parsed },
        data = <|
            "items" -> {
                <| "name" -> "Alice", "age" -> 30 |>,
                <| "name" -> "Bob",   "age" -> 25 |>
            }
        |>;
        yaml = Wolfram`AgentTools`Common`exportYAMLString @ data;
        parsed = Wolfram`AgentTools`Common`importYAMLString @ yaml;
        parsed === data
    ],
    True,
    SameTest -> Equal,
    TestID   -> "RoundTrip-SequenceOfMultiKeyAssociations"
]

(* Sequence item whose value is itself a nested mapping. *)
VerificationTest[
    Module[ { data, yaml, parsed },
        data = <|
            "items" -> {
                <| "name" -> "Alice", "config" -> <| "key" -> "value" |> |>
            }
        |>;
        yaml = Wolfram`AgentTools`Common`exportYAMLString @ data;
        parsed = Wolfram`AgentTools`Common`importYAMLString @ yaml;
        parsed === data
    ],
    True,
    SameTest -> Equal,
    TestID   -> "RoundTrip-SequenceItemWithNestedMapping"
]

(* Top-level sequence of associations. *)
VerificationTest[
    Module[ { data, yaml, parsed },
        data = {
            <| "name" -> "Alice", "age" -> 30 |>,
            <| "name" -> "Bob",   "age" -> 25 |>
        };
        yaml = Wolfram`AgentTools`Common`exportYAMLString @ data;
        parsed = Wolfram`AgentTools`Common`importYAMLString @ yaml;
        parsed === data
    ],
    True,
    SameTest -> Equal,
    TestID   -> "RoundTrip-TopLevelSequenceOfAssociations"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*importYAML / exportYAML (File Variants)*)
VerificationTest[
    Module[ { file, data },
        file = testYAMLFile[ ];
        data = <| "extensions" -> <| "Foo" -> <| "cmd" -> "x", "enabled" -> True |> |> |>;
        Wolfram`AgentTools`Common`exportYAML[ file, data ];
        FileExistsQ[ file ]
    ],
    True,
    SameTest -> Equal,
    TestID   -> "ExportYAML-CreatesFile"
]

VerificationTest[
    Module[ { file, data, parsed },
        file = testYAMLFile[ ];
        data = <| "extensions" -> <| "Foo" -> <| "cmd" -> "x", "enabled" -> True |> |> |>;
        Wolfram`AgentTools`Common`exportYAML[ file, data ];
        parsed = Wolfram`AgentTools`Common`importYAML[ file ];
        cleanupTestFiles[ file ];
        parsed === data
    ],
    True,
    SameTest -> Equal,
    TestID   -> "ExportYAML-ImportYAML-RoundTrip"
]

VerificationTest[
    Wolfram`AgentTools`Common`importYAML[
        File @ FileNameJoin @ { $TemporaryDirectory, "yaml_nonexistent_" <> CreateUUID[ ] <> ".yaml" }
    ],
    <| |>,
    SameTest -> Equal,
    TestID   -> "ImportYAML-MissingFile"
]

VerificationTest[
    Module[ { file },
        file = testYAMLFile[ ];
        Module[ { stream },
            stream = OpenWrite @ First @ file;
            Close @ stream
        ];
        With[ { result = Wolfram`AgentTools`Common`importYAML @ file },
            cleanupTestFiles[ file ];
            result
        ]
    ],
    <| |>,
    SameTest -> Equal,
    TestID   -> "ImportYAML-EmptyFile"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Parse Error File Reporting*)
VerificationTest[
    Module[ { file, result, params, expandedPath },
        file = testYAMLFile[ ];
        Module[ { stream },
            stream = OpenWrite @ First @ file;
            WriteString[ stream, "a:\n  b: 1\n   c: 2\n" ]; (* malformed indentation *)
            Close @ stream
        ];
        expandedPath = ExpandFileName @ First @ file;
        result = Wolfram`AgentTools`Common`catchAlways @
            Wolfram`AgentTools`Common`importYAML @ file;
        params = If[ MatchQ[ result, _Failure ], result[ "MessageParameters" ], { } ];
        cleanupTestFiles[ file ];
        MatchQ[ result, _Failure ] && First[ params, "" ] === expandedPath
    ],
    True,
    { AgentTools::InvalidYAMLFormat },
    SameTest -> Equal,
    TestID   -> "ImportYAML-ParseErrorReportsFilePath"
]

VerificationTest[
    Module[ { result, params },
        result = Wolfram`AgentTools`Common`catchAlways @
            Wolfram`AgentTools`Common`importYAMLString[ "a:\n  b: 1\n   c: 2\n" ];
        params = If[ MatchQ[ result, _Failure ], result[ "MessageParameters" ], { } ];
        MatchQ[ result, _Failure ] && First[ params, "" ] === "<input>"
    ],
    True,
    { AgentTools::InvalidYAMLFormat },
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-ParseErrorReportsInputLabel"
]

(* Errors from within parseFlowMapping must report the line the flow mapping
   appeared on, not a hard-coded 0. *)
VerificationTest[
    Module[ { result, params },
        result = Wolfram`AgentTools`Common`catchAlways @
            Wolfram`AgentTools`Common`importYAMLString[ "foo: 1\nbar: {no_colon}" ];
        params = If[ MatchQ[ result, _Failure ], result[ "MessageParameters" ], { } ];
        MatchQ[ result, _Failure ] && Length[ params ] >= 2 && params[[ 2 ]] === 2
    ],
    True,
    { AgentTools::InvalidYAMLFormat },
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-FlowMappingErrorReportsLine"
]

(* Trailing content (e.g. a top-level sequence after a mapping) must surface
   as an error rather than being silently dropped. *)
VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @
        Wolfram`AgentTools`Common`importYAMLString[ "a: 1\nb: 2\n- one\n- two" ],
    _Failure,
    { AgentTools::InvalidYAMLFormat },
    SameTest -> MatchQ,
    TestID   -> "ImportYAMLString-TrailingSequenceAfterMapping"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Malformed Scalars*)
(* Inputs that begin with a quote or flow-construct opener but are missing the
   matching close must surface as InvalidYAMLFormat rather than being silently
   accepted as plain strings -- otherwise InstallMCPServer would later overwrite
   a hand-edited config that we never actually parsed. *)

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @
        Wolfram`AgentTools`Common`importYAMLString[ "key: \"unterminated" ],
    _Failure,
    { AgentTools::InvalidYAMLFormat },
    SameTest -> MatchQ,
    TestID   -> "ImportYAMLString-UnterminatedDoubleQuotedScalar"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @
        Wolfram`AgentTools`Common`importYAMLString[ "key: 'unterminated" ],
    _Failure,
    { AgentTools::InvalidYAMLFormat },
    SameTest -> MatchQ,
    TestID   -> "ImportYAMLString-UnterminatedSingleQuotedScalar"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @
        Wolfram`AgentTools`Common`importYAMLString[ "key: [1, 2, 3" ],
    _Failure,
    { AgentTools::InvalidYAMLFormat },
    SameTest -> MatchQ,
    TestID   -> "ImportYAMLString-UnterminatedFlowSequence"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @
        Wolfram`AgentTools`Common`importYAMLString[ "key: {a: 1, b: 2" ],
    _Failure,
    { AgentTools::InvalidYAMLFormat },
    SameTest -> MatchQ,
    TestID   -> "ImportYAMLString-UnterminatedFlowMapping"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @
        Wolfram`AgentTools`Common`importYAMLString[ "key: \"abc\" trailing" ],
    _Failure,
    { AgentTools::InvalidYAMLFormat },
    SameTest -> MatchQ,
    TestID   -> "ImportYAMLString-TrailingAfterDoubleQuotedScalar"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @
        Wolfram`AgentTools`Common`importYAMLString[ "key: [1, [2, 3]" ],
    _Failure,
    { AgentTools::InvalidYAMLFormat },
    SameTest -> MatchQ,
    TestID   -> "ImportYAMLString-UnbalancedNestedFlowSequence"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @
        Wolfram`AgentTools`Common`importYAMLString[ "items:\n  - [1, 2" ],
    _Failure,
    { AgentTools::InvalidYAMLFormat },
    SameTest -> MatchQ,
    TestID   -> "ImportYAMLString-UnterminatedFlowSequenceInBlockSequence"
]

(* Quoted strings inside a flow construct should still be respected -- a quoted
   "]" must not be treated as the closing bracket. *)
VerificationTest[
    Wolfram`AgentTools`Common`importYAMLString[ "key: [\"]\", \"x\"]" ],
    <| "key" -> { "]", "x" } |>,
    SameTest -> Equal,
    TestID   -> "ImportYAMLString-FlowSequenceWithQuotedBracket"
]

(* :!CodeAnalysis::EndBlock:: *)
