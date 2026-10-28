(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`AgentToolsTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/LicenseStatus.wlt:7,1-12,2"
]

VerificationTest[
    Needs[ "Wolfram`AgentTools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/LicenseStatus.wlt:14,1-19,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Fixtures*)
(* The time-limited license of the standalone MCP server (see Specs/StandaloneLicense.md and Kernel/Tools/LicenseStatus.wl).
   licenseStatus[info, now] evaluates the license at a fixed time, so most tests below are deterministic. *)
licenseStatusAt       = Wolfram`AgentTools`Common`licenseStatus;
licenseInstructionsOf = Wolfram`AgentTools`Common`licenseInstructions;
initResponse          = Wolfram`AgentTools`Server`Shared`Private`initResponse;

$now = DateObject[ { 2026, 10, 27, 12, 0, 0 }, TimeZone -> 0 ];
utc[ y_, m_, d_, h_ ] := DateObject[ { y, m, d, h, 0, 0 }, TimeZone -> 0 ];

$url = "https://example.com/renew";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframLicenseStatus Tool Definition*)
(* The standalone application detects license support with KeyExistsQ[$DefaultMCPTools, "WolframLicenseStatus"] *)
VerificationTest[
    KeyExistsQ[ $DefaultMCPTools, "WolframLicenseStatus" ],
    True,
    SameTest -> SameQ,
    TestID   -> "LicenseStatusTool-InDefaultMCPTools@@Tests/LicenseStatus.wlt:39,1-44,2"
]

VerificationTest[
    $licenseTool = $DefaultMCPTools[ "WolframLicenseStatus" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "LicenseStatusTool-IsLLMTool@@Tests/LicenseStatus.wlt:46,1-51,2"
]

VerificationTest[
    { $licenseTool[ "Name" ], $licenseTool[ "Parameters" ], Wolfram`AgentTools`Common`$licenseToolName },
    { "WolframLicenseStatus", { }, "WolframLicenseStatus" },
    SameTest -> SameQ,
    TestID   -> "LicenseStatusTool-NameAndNoParameters@@Tests/LicenseStatus.wlt:53,1-58,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*licenseStatus*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*No License*)
VerificationTest[
    licenseStatusAt[ <| |>, $now ],
    None,
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-NoLicense-Empty@@Tests/LicenseStatus.wlt:67,1-72,2"
]

(* License handling is on only when "Expired" or "ExpirationDate" is present: the other license keys alone don't
   turn it on *)
VerificationTest[
    licenseStatusAt[
        <|
            "Version"         -> "1.0.0",
            "BuildDate"       -> utc[ 2026, 8, 1, 12 ],
            "InstructionsURL" -> $url,
            "ProductName"     -> "Wolfram MCP Server",
            "WarningDays"     -> 7
        |>,
        $now
    ],
    None,
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-NoLicense-UnrelatedKeys@@Tests/LicenseStatus.wlt:76,1-90,2"
]

(* A regular kernel has no license *)
VerificationTest[
    { $StandaloneMCPServerInformation, licenseStatusAt[ ], licenseInstructionsOf[ ] },
    { <| |>, None, None },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-NoLicense-Default@@Tests/LicenseStatus.wlt:93,1-98,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Result*)
VerificationTest[
    licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 11, 1, 12 ] |>, $now ],
    <|
        "ProductName"     -> "MCP server",
        "ExpirationDate"  -> utc[ 2026, 11, 1, 12 ],
        "InstructionsURL" -> None,
        "WarningDays"     -> 14,
        "Expired"         -> False,
        "DaysRemaining"   -> 5,
        "Warning"         -> True,
        "Message"         -> "Your MCP server license expires in 5 days, on 2026-11-01."
    |>,
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Result@@Tests/LicenseStatus.wlt:103,1-117,2"
]

VerificationTest[
    licenseStatusAt[
        <|
            "ExpirationDate"  -> utc[ 2026, 12, 1, 12 ],
            "Expired"         -> False,
            "InstructionsURL" -> $url,
            "ProductName"     -> "Wolfram MCP Server",
            "WarningDays"     -> 7
        |>,
        $now
    ],
    <|
        "ProductName"     -> "Wolfram MCP Server",
        "ExpirationDate"  -> utc[ 2026, 12, 1, 12 ],
        "InstructionsURL" -> $url,
        "WarningDays"     -> 7,
        "Expired"         -> False,
        "DaysRemaining"   -> 35,
        "Warning"         -> False,
        "Message"         -> "Your Wolfram MCP Server license expires in 35 days, on 2026-12-01. Visit https://example.com/renew for instructions on how to continue."
    |>,
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Result-AllKeys@@Tests/LicenseStatus.wlt:119,1-142,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Messages*)
VerificationTest[
    licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 11, 1, 12 ] |>, $now ][ "Message" ],
    "Your MCP server license expires in 5 days, on 2026-11-01.",
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Message-Days@@Tests/LicenseStatus.wlt:147,1-152,2"
]

(* Days are calendar days: 20 hours from now, but tomorrow *)
VerificationTest[
    Lookup[ licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 10, 28, 8 ] |>, $now ], { "DaysRemaining", "Message" } ],
    { 1, "Your MCP server license expires in 1 day, on 2026-10-28." },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Message-OneDay@@Tests/LicenseStatus.wlt:155,1-160,2"
]

(* 37 hours from now, but the day after tomorrow *)
VerificationTest[
    Lookup[ licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 10, 29, 1 ] |>, $now ], { "DaysRemaining", "Message" } ],
    { 2, "Your MCP server license expires in 2 days, on 2026-10-29." },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Message-CalendarDays@@Tests/LicenseStatus.wlt:163,1-168,2"
]

VerificationTest[
    Lookup[
        licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 10, 27, 23 ] |>, $now ],
        { "Expired", "DaysRemaining", "Warning", "Message" }
    ],
    { False, 0, True, "Your MCP server license expires in less than a day, on 2026-10-27." },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Message-LessThanADay@@Tests/LicenseStatus.wlt:170,1-178,2"
]

VerificationTest[
    Lookup[
        licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 10, 20, 23 ] |>, $now ],
        { "Expired", "DaysRemaining", "Warning", "Message" }
    ],
    { True, 0, False, "Your MCP server license has expired." },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Message-Expired@@Tests/LicenseStatus.wlt:180,1-188,2"
]

VerificationTest[
    licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 11, 1, 12 ], "InstructionsURL" -> $url |>, $now ][ "Message" ],
    "Your MCP server license expires in 5 days, on 2026-11-01. Visit https://example.com/renew for instructions on how to continue.",
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Message-InstructionsURL@@Tests/LicenseStatus.wlt:190,1-195,2"
]

VerificationTest[
    licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 10, 20, 23 ], "InstructionsURL" -> $url |>, $now ][ "Message" ],
    "Your MCP server license has expired. Visit https://example.com/renew for instructions on how to continue.",
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Message-ExpiredInstructionsURL@@Tests/LicenseStatus.wlt:197,1-202,2"
]

VerificationTest[
    {
        licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 11, 1, 12 ], "ProductName" -> "Wolfram MCP Server" |>, $now ][ "Message" ],
        licenseStatusAt[ <| "Expired" -> True, "ProductName" -> "Wolfram MCP Server" |>, $now ][ "Message" ]
    },
    {
        "Your Wolfram MCP Server license expires in 5 days, on 2026-11-01.",
        "Your Wolfram MCP Server license has expired."
    },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Message-ProductName@@Tests/LicenseStatus.wlt:204,1-215,2"
]

(* Blank instructions URLs are ignored *)
VerificationTest[
    Lookup[
        licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 11, 1, 12 ], "InstructionsURL" -> # |>, $now ],
        { "InstructionsURL", "Message" }
    ] & /@ { "", "  " },
    {
        { None, "Your MCP server license expires in 5 days, on 2026-11-01." },
        { None, "Your MCP server license expires in 5 days, on 2026-11-01." }
    },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Message-BlankInstructionsURL@@Tests/LicenseStatus.wlt:218,1-229,2"
]

(* Invalid optional values fall back to the defaults *)
VerificationTest[
    Lookup[
        licenseStatusAt[
            <| "ExpirationDate" -> utc[ 2026, 11, 1, 12 ], "ProductName" -> 7, "WarningDays" -> "3", "InstructionsURL" -> None |>,
            $now
        ],
        { "ProductName", "WarningDays", "InstructionsURL", "Warning" }
    ],
    { "MCP server", 14, None, True },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-InvalidOptionalValues@@Tests/LicenseStatus.wlt:232,1-243,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fail Closed*)
(* A missing or invalid "ExpirationDate" counts as expired *)
VerificationTest[
    Lookup[ licenseStatusAt[ <| "ExpirationDate" -> None |>, $now ], { "ExpirationDate", "Expired", "Warning", "Message" } ],
    { None, True, False, "Your MCP server license has expired." },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-FailClosed-NoneDate@@Tests/LicenseStatus.wlt:249,1-254,2"
]

VerificationTest[
    Lookup[ licenseStatusAt[ <| "Expired" -> False |>, $now ], { "ExpirationDate", "Expired", "Warning", "Message" } ],
    { None, True, False, "Your MCP server license has expired." },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-FailClosed-MissingDate@@Tests/LicenseStatus.wlt:256,1-261,2"
]

VerificationTest[
    Lookup[ licenseStatusAt[ <| "ExpirationDate" -> # |>, $now ], { "ExpirationDate", "Expired" } ] & /@ {
        "2027-01-01",
        UnixTime @ utc[ 2027, 1, 1, 0 ],
        { 2027, 1, 1 },
        Missing[ "NotAvailable" ]
    },
    { { None, True }, { None, True }, { None, True }, { None, True } },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-FailClosed-NonDate@@Tests/LicenseStatus.wlt:263,1-273,2"
]

(* "Expired" -> True overrides a future expiration date *)
VerificationTest[
    Lookup[
        licenseStatusAt[ <| "Expired" -> True, "ExpirationDate" -> utc[ 2027, 1, 1, 0 ] |>, $now ],
        { "Expired", "DaysRemaining", "Warning", "Message" }
    ],
    { True, 0, False, "Your MCP server license has expired." },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-ExpiredTrue-FutureDate@@Tests/LicenseStatus.wlt:276,1-284,2"
]

VerificationTest[
    Lookup[ licenseStatusAt[ <| "Expired" -> True |>, $now ], { "Expired", "Message" } ],
    { True, "Your MCP server license has expired." },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-ExpiredTrue-NoDate@@Tests/LicenseStatus.wlt:286,1-291,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Expiration Instant*)
VerificationTest[
    Lookup[ licenseStatusAt[ <| "ExpirationDate" -> $now |>, $now ], { "Expired", "Warning", "Message" } ],
    { True, False, "Your MCP server license has expired." },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-ExpiresExactlyNow@@Tests/LicenseStatus.wlt:296,1-301,2"
]

VerificationTest[
    Lookup[
        licenseStatusAt[ <| "ExpirationDate" -> DateObject[ { 2026, 10, 27, 12, 0, 1 }, TimeZone -> 0 ] |>, $now ],
        { "Expired", "DaysRemaining", "Message" }
    ],
    { False, 0, "Your MCP server license expires in less than a day, on 2026-10-27." },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-OneSecondLeft@@Tests/LicenseStatus.wlt:303,1-311,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Warning Period*)
VerificationTest[
    Lookup[ licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 11, 10, 12 ] |>, $now ], { "WarningDays", "DaysRemaining", "Warning" } ],
    { 14, 14, True },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Warning-DefaultWarningDays-Boundary@@Tests/LicenseStatus.wlt:316,1-321,2"
]

VerificationTest[
    Lookup[ licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 11, 11, 12 ] |>, $now ], { "WarningDays", "DaysRemaining", "Warning" } ],
    { 14, 15, False },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Warning-DefaultWarningDays-Outside@@Tests/LicenseStatus.wlt:323,1-328,2"
]

VerificationTest[
    {
        Lookup[ licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 11, 1, 12 ], "WarningDays" -> 5 |>, $now ], { "DaysRemaining", "Warning" } ],
        Lookup[ licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 11, 2, 12 ], "WarningDays" -> 5 |>, $now ], { "DaysRemaining", "Warning" } ]
    },
    { { 5, True }, { 6, False } },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Warning-CustomWarningDays@@Tests/LicenseStatus.wlt:330,1-338,2"
]

(* With WarningDays 0, reminders appear only on the last day *)
VerificationTest[
    {
        licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 10, 27, 23 ], "WarningDays" -> 0 |>, $now ][ "Warning" ],
        licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 10, 28, 8 ], "WarningDays" -> 0 |>, $now ][ "Warning" ]
    },
    { True, False },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Warning-ZeroWarningDays@@Tests/LicenseStatus.wlt:341,1-349,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Time Zones*)
(* Days and dates use the time zone of the expiration date, not UTC. Now is 2026-10-27 05:00 at UTC-7, and the
   license expires at 2026-10-27 23:00 there, which is 2026-10-28 06:00 UTC. *)
VerificationTest[
    licenseStatusAt[ <| "ExpirationDate" -> DateObject[ { 2026, 10, 27, 23, 0, 0 }, TimeZone -> -7 ] |>, $now ][ "Message" ],
    "Your MCP server license expires in less than a day, on 2026-10-27.",
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-TimeZone-BehindUTC@@Tests/LicenseStatus.wlt:356,1-361,2"
]

(* Now is 2026-10-28 01:00 at UTC+13, and the license expires at 2026-10-29 01:00 there, which is 2026-10-28 12:00 UTC *)
VerificationTest[
    licenseStatusAt[ <| "ExpirationDate" -> DateObject[ { 2026, 10, 29, 1, 0, 0 }, TimeZone -> 13 ] |>, $now ][ "Message" ],
    "Your MCP server license expires in 1 day, on 2026-10-29.",
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-TimeZone-AheadOfUTC@@Tests/LicenseStatus.wlt:364,1-369,2"
]

VerificationTest[
    {
        licenseStatusAt[ <| "ExpirationDate" -> DateObject[ { 2026, 10, 27, 23, 0, 0 }, TimeZone -> "America/Los_Angeles" ] |>, $now ][ "Message" ],
        licenseStatusAt[ <| "ExpirationDate" -> DateObject[ { 2026, 11, 2, 0, 30, 0 }, TimeZone -> "America/Los_Angeles" ] |>, $now ][ "Message" ]
    },
    {
        "Your MCP server license expires in less than a day, on 2026-10-27.",
        "Your MCP server license expires in 6 days, on 2026-11-02."
    },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-TimeZone-Named@@Tests/LicenseStatus.wlt:371,1-382,2"
]

(* The time zone in which "now" is given does not matter *)
VerificationTest[
    With[ { info = <| "ExpirationDate" -> DateObject[ { 2026, 10, 29, 1, 0, 0 }, TimeZone -> 13 ] |> },
        licenseStatusAt[ info, TimeZoneConvert[ $now, -10 ] ] === licenseStatusAt[ info, $now ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-TimeZone-NowZoneIrrelevant@@Tests/LicenseStatus.wlt:385,1-392,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Current License*)
(* licenseStatus[] reads $StandaloneMCPServerInformation and the current time *)
VerificationTest[
    Block[ { $StandaloneMCPServerInformation = <| "ExpirationDate" -> DatePlus[ Now, Quantity[ 3, "Days" ] ] |> },
        Lookup[ licenseStatusAt[ ], { "Expired", "DaysRemaining", "Warning" } ]
    ],
    { False, 3, True },
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Current-Valid@@Tests/LicenseStatus.wlt:398,1-405,2"
]

VerificationTest[
    Block[ { $StandaloneMCPServerInformation = <| "ExpirationDate" -> DatePlus[ Now, Quantity[ -1, "Seconds" ] ] |> },
        licenseStatusAt[ ][ "Expired" ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "LicenseStatus-Current-Expired@@Tests/LicenseStatus.wlt:407,1-414,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*licenseInstructions*)
VerificationTest[
    licenseInstructionsOf[ None ],
    None,
    SameTest -> SameQ,
    TestID   -> "LicenseInstructions-NoLicense@@Tests/LicenseStatus.wlt:419,1-424,2"
]

VerificationTest[
    With[ { status = licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 11, 1, 12 ], "InstructionsURL" -> $url |>, $now ] },
        With[ { instructions = licenseInstructionsOf @ status },
            {
                StringQ @ instructions,
                StringContainsQ[ instructions, "time-limited license" ],
                StringContainsQ[ instructions, status[ "Message" ] ],
                StringContainsQ[ instructions, "Use the WolframLicenseStatus tool" ],
                StringContainsQ[ instructions, "pass it on to the user" ],
                StringContainsQ[ instructions, "fails" ]
            }
        ]
    ],
    { True, True, True, True, True, False },
    SameTest -> SameQ,
    TestID   -> "LicenseInstructions-BeforeExpiration@@Tests/LicenseStatus.wlt:426,1-442,2"
]

VerificationTest[
    licenseInstructionsOf @ licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 11, 1, 12 ] |>, $now ],
    "This MCP server runs under a time-limited license. Your MCP server license expires in 5 days, on 2026-11-01. Use the WolframLicenseStatus tool to check the status of the license. When a tool result ends with a license reminder, pass it on to the user.",
    SameTest -> SameQ,
    TestID   -> "LicenseInstructions-BeforeExpiration-Text@@Tests/LicenseStatus.wlt:444,1-449,2"
]

(* Outside the warning period, the instructions still say when the license expires *)
VerificationTest[
    licenseInstructionsOf @ licenseStatusAt[ <| "ExpirationDate" -> utc[ 2026, 12, 1, 12 ] |>, $now ],
    _String? (StringContainsQ[ "Your MCP server license expires in 35 days, on 2026-12-01." ]),
    SameTest -> MatchQ,
    TestID   -> "LicenseInstructions-OutsideWarningPeriod@@Tests/LicenseStatus.wlt:452,1-457,2"
]

VerificationTest[
    licenseInstructionsOf @ licenseStatusAt[ <| "Expired" -> True, "InstructionsURL" -> $url |>, $now ],
    "This MCP server runs under a time-limited license. Your MCP server license has expired. Visit https://example.com/renew for instructions on how to continue. Every prompt and every tool call other than WolframLicenseStatus fails. Help the user follow those instructions.",
    SameTest -> SameQ,
    TestID   -> "LicenseInstructions-Expired-InstructionsURL@@Tests/LicenseStatus.wlt:459,1-464,2"
]

VerificationTest[
    With[ { instructions = licenseInstructionsOf @ licenseStatusAt[ <| "ExpirationDate" -> None |>, $now ] },
        {
            StringContainsQ[ instructions, "Your MCP server license has expired." ],
            StringContainsQ[ instructions, "Every prompt and every tool call other than WolframLicenseStatus fails." ],
            StringContainsQ[ instructions, "Help the user" ],
            StringContainsQ[ instructions, "pass it on to the user" ]
        }
    ],
    { True, True, False, False },
    SameTest -> SameQ,
    TestID   -> "LicenseInstructions-Expired-NoInstructionsURL@@Tests/LicenseStatus.wlt:466,1-478,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframLicenseStatus Tool Output*)
VerificationTest[
    {
        $licenseTool[ <| |> ],
        Block[ { $StandaloneMCPServerInformation = <| "Version" -> "1.0.0" |> }, $licenseTool[ <| |> ] ]
    },
    { "This MCP server does not have a time-limited license.", "This MCP server does not have a time-limited license." },
    SameTest -> SameQ,
    TestID   -> "LicenseStatusTool-NoLicense@@Tests/LicenseStatus.wlt:483,1-491,2"
]

VerificationTest[
    With[ { date = DatePlus[ Now, Quantity[ 30, "Days" ] ] },
        Block[ { $StandaloneMCPServerInformation = <| "ExpirationDate" -> date, "InstructionsURL" -> $url |> },
            With[ { output = $licenseTool[ <| |> ], status = licenseStatusAt[ ] },
                {
                    StringQ @ output,
                    StringStartsQ[ output, status[ "Message" ] ],
                    StringContainsQ[ output, "Expiration date: " <> DateString[ date, "ISODate" ] ],
                    StringContainsQ[ output, "Days remaining: 30" ],
                    StringContainsQ[ output, "Instructions: https://example.com/renew" ]
                }
            ]
        ]
    ],
    { True, True, True, True, True },
    SameTest -> SameQ,
    TestID   -> "LicenseStatusTool-License@@Tests/LicenseStatus.wlt:493,1-510,2"
]

VerificationTest[
    Block[ { $StandaloneMCPServerInformation = <| "ExpirationDate" -> DatePlus[ Now, Quantity[ 30, "Days" ] ] |> },
        StringContainsQ[ $licenseTool[ <| |> ], "Instructions:" ]
    ],
    False,
    SameTest -> SameQ,
    TestID   -> "LicenseStatusTool-License-NoInstructionsURL@@Tests/LicenseStatus.wlt:512,1-519,2"
]

VerificationTest[
    Block[ { $StandaloneMCPServerInformation = <| "Expired" -> True |> }, $licenseTool[ <| |> ] ],
    "Your MCP server license has expired.\n\nExpiration date: unknown\nDays remaining: 0",
    SameTest -> SameQ,
    TestID   -> "LicenseStatusTool-Expired@@Tests/LicenseStatus.wlt:521,1-526,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Server Integration*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fixtures*)
(* A tool with a visible side effect, to tell whether it ran *)
$licenseEchoCalls = 0;
licenseEcho[ args_Association ] := ( $licenseEchoCalls++; "echo " <> args[ "x" ] );
licenseEchoTool = LLMTool[ "LicenseEcho", { "x" -> "String" }, licenseEcho ];

(* In-memory servers (no disk persistence) *)
licenseServer = MCPServerObject @ <|
    "Name"         -> "LicenseTestServer",
    "Location"     -> "BuiltIn",
    "LLMEvaluator" -> <| "Tools" -> { licenseEchoTool } |>
|>;

(* A server that lists WolframLicenseStatus itself *)
licenseServerWithTool = MCPServerObject @ <|
    "Name"         -> "LicenseTestServerWithTool",
    "Location"     -> "BuiltIn",
    "LLMEvaluator" -> <| "Tools" -> { "WolframLicenseStatus", licenseEchoTool } |>
|>;

(* A server with its own instructions (from its "Prompts") *)
licenseServerWithInstructions = MCPServerObject @ <|
    "Name"         -> "LicenseTestServerWithInstructions",
    "Location"     -> "BuiltIn",
    "LLMEvaluator" -> <| "Tools" -> { licenseEchoTool }, "Prompts" -> { "Server instructions." } |>
|>;

(* Builds the server state the way both transports do at startup *)
licenseServerState[ server_, info_ ] :=
    Block[ { $StandaloneMCPServerInformation = info, Wolfram`AgentTools`Server`$currentMCPServer = server },
        Wolfram`AgentTools`Common`initializeServerState @ server
    ];

(* Handles a request with the given server state, while $StandaloneMCPServerInformation is info *)
licenseRequest[ state_Association, info_, method_String, params_Association ] :=
    Block[
        {
            $StandaloneMCPServerInformation    = info,
            Wolfram`AgentTools`Server`$toolList = state[ "ToolList" ],
            Wolfram`AgentTools`Server`$llmTools = state[ "LLMTools" ]
        },
        Wolfram`AgentTools`Common`handleMethod[
            method,
            <| "jsonrpc" -> "2.0", "id" -> 1, "method" -> method, "params" -> params |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ]
    ];

licenseRequest[ server_MCPServerObject, info_, method_String, params_Association ] :=
    licenseRequest[ licenseServerState[ server, info ], info, method, params ];

licenseToolNames[ server_, info_ ] :=
    licenseRequest[ server, info, "tools/list", <| |> ][[ "result", "tools", All, "name" ]];

licenseToolCall[ server_, info_, name_String, args_Association ] :=
    licenseRequest[ server, info, "tools/call", <| "name" -> name, "arguments" -> args |> ][ "result" ];

licenseInitResponse[ server_, info_ ] :=
    Block[ { $StandaloneMCPServerInformation = info }, initResponse[ server, <| |> ] ];

(* Expiration dates relative to the current time, since tool calls read it *)
$noLicense      = <| |>;
$warningLicense := <| "ExpirationDate" -> DatePlus[ Now, Quantity[ 3, "Days" ] ] |>;
$validLicense   := <| "ExpirationDate" -> DatePlus[ Now, Quantity[ 30, "Days" ] ] |>;
$expiredLicense := <| "ExpirationDate" -> DatePlus[ Now, Quantity[ -1, "Days" ] ], "InstructionsURL" -> $url |>;

$echoResult = <| "content" -> { <| "type" -> "text", "text" -> "echo hi" |> }, "isError" -> False |>;

VerificationTest[
    MCPServerObjectQ /@ { licenseServer, licenseServerWithTool, licenseServerWithInstructions },
    { True, True, True },
    SameTest -> SameQ,
    TestID   -> "LicenseServer-Fixtures@@Tests/LicenseStatus.wlt:602,1-607,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*No License*)
VerificationTest[
    { licenseToolNames[ licenseServer, $noLicense ], licenseToolNames[ licenseServer, <| "Version" -> "1.0.0" |> ] },
    { { "LicenseEcho" }, { "LicenseEcho" } },
    SameTest -> SameQ,
    TestID   -> "LicenseServer-NoLicense-ToolList@@Tests/LicenseStatus.wlt:612,1-617,2"
]

VerificationTest[
    {
        KeyExistsQ[ licenseInitResponse[ licenseServer, $noLicense ], "instructions" ],
        licenseInitResponse[ licenseServerWithInstructions, $noLicense ][ "instructions" ]
    },
    { False, "Server instructions." },
    SameTest -> SameQ,
    TestID   -> "LicenseServer-NoLicense-Instructions@@Tests/LicenseStatus.wlt:619,1-627,2"
]

VerificationTest[
    {
        licenseToolCall[ licenseServer, $noLicense, "LicenseEcho", <| "x" -> "hi" |> ],
        licenseToolCall[ licenseServer, <| "Version" -> "1.0.0" |>, "LicenseEcho", <| "x" -> "hi" |> ]
    },
    { $echoResult, $echoResult },
    SameTest -> SameQ,
    TestID   -> "LicenseServer-NoLicense-ToolResult@@Tests/LicenseStatus.wlt:629,1-637,2"
]

(* WolframLicenseStatus is an ordinary default tool that any server can list *)
VerificationTest[
    {
        licenseToolNames[ licenseServerWithTool, $noLicense ],
        licenseToolCall[ licenseServerWithTool, $noLicense, "WolframLicenseStatus", <| |> ]
    },
    {
        { "WolframLicenseStatus", "LicenseEcho" },
        <|
            "content" -> { <| "type" -> "text", "text" -> "This MCP server does not have a time-limited license." |> },
            "isError" -> False
        |>
    },
    SameTest -> SameQ,
    TestID   -> "LicenseServer-NoLicense-ListedByName@@Tests/LicenseStatus.wlt:640,1-654,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Instructions*)
VerificationTest[
    Block[ { $StandaloneMCPServerInformation = $warningLicense },
        { initResponse[ licenseServer, <| |> ][ "instructions" ], licenseInstructionsOf[ ] }
    ],
    { instructions_String, instructions_String } /; StringStartsQ[ instructions, "This MCP server runs under a time-limited license." ],
    SameTest -> MatchQ,
    TestID   -> "LicenseServer-Instructions-Set@@Tests/LicenseStatus.wlt:659,1-666,2"
]

VerificationTest[
    Block[ { $StandaloneMCPServerInformation = $warningLicense },
        { initResponse[ licenseServerWithInstructions, <| |> ][ "instructions" ], licenseInstructionsOf[ ] }
    ],
    { instructions_String, license_String } /; instructions === "Server instructions.\n\n" <> license,
    SameTest -> MatchQ,
    TestID   -> "LicenseServer-Instructions-Appended@@Tests/LicenseStatus.wlt:668,1-675,2"
]

VerificationTest[
    Block[ { $StandaloneMCPServerInformation = $validLicense },
        { initResponse[ "TestServer", "1.0.0", { }, { "First.", "Second." }, <| |> ][ "instructions" ], licenseInstructionsOf[ ] }
    ],
    { instructions_String, license_String } /; instructions === "First.\n\nSecond.\n\n" <> license,
    SameTest -> MatchQ,
    TestID   -> "LicenseServer-Instructions-AppendedToPrompts@@Tests/LicenseStatus.wlt:677,1-684,2"
]

VerificationTest[
    licenseInitResponse[ licenseServer, $expiredLicense ][ "instructions" ],
    "This MCP server runs under a time-limited license. Your MCP server license has expired. Visit https://example.com/renew for instructions on how to continue. Every prompt and every tool call other than WolframLicenseStatus fails. Help the user follow those instructions.",
    SameTest -> SameQ,
    TestID   -> "LicenseServer-Instructions-Expired@@Tests/LicenseStatus.wlt:686,1-691,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*License Tool*)
VerificationTest[
    {
        licenseToolNames[ licenseServer, $warningLicense ],
        licenseToolNames[ licenseServer, $validLicense ],
        licenseToolNames[ licenseServer, $expiredLicense ],
        licenseToolNames[ licenseServer, <| "Expired" -> True |> ]
    },
    {
        { "LicenseEcho", "WolframLicenseStatus" },
        { "LicenseEcho", "WolframLicenseStatus" },
        { "LicenseEcho", "WolframLicenseStatus" },
        { "LicenseEcho", "WolframLicenseStatus" }
    },
    SameTest -> SameQ,
    TestID   -> "LicenseServer-LicenseTool-Added@@Tests/LicenseStatus.wlt:696,1-711,2"
]

VerificationTest[
    SelectFirst[
        licenseRequest[ licenseServer, $validLicense, "tools/list", <| |> ][ "result", "tools" ],
        #[ "name" ] === "WolframLicenseStatus" &
    ][ "inputSchema" ],
    KeyValuePattern @ { "type" -> "object", "properties" -> <| |> },
    SameTest -> MatchQ,
    TestID   -> "LicenseServer-LicenseTool-NoParameters@@Tests/LicenseStatus.wlt:713,1-721,2"
]

VerificationTest[
    licenseToolNames[ licenseServerWithTool, $warningLicense ],
    { "WolframLicenseStatus", "LicenseEcho" },
    SameTest -> SameQ,
    TestID   -> "LicenseServer-LicenseTool-NotDuplicated@@Tests/LicenseStatus.wlt:723,1-728,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Warning Period*)
VerificationTest[
    Block[ { $StandaloneMCPServerInformation = $warningLicense },
        {
            licenseToolCall[ licenseServer, $StandaloneMCPServerInformation, "LicenseEcho", <| "x" -> "hi" |> ],
            licenseStatusAt[ ][ "Message" ]
        }
    ],
    {
        <|
            "content" -> {
                <| "type" -> "text", "text" -> "echo hi" |>,
                <| "type" -> "text", "text" -> message_String |>
            },
            "isError" -> False
        |>,
        message_String
    } /; StringStartsQ[ message, "Your MCP server license expires in 3 days, on " ],
    SameTest -> MatchQ,
    TestID   -> "LicenseServer-Warning-ReminderAppended@@Tests/LicenseStatus.wlt:733,1-752,2"
]

VerificationTest[
    licenseToolCall[ licenseServer, $validLicense, "LicenseEcho", <| "x" -> "hi" |> ],
    $echoResult,
    SameTest -> SameQ,
    TestID   -> "LicenseServer-Warning-NoReminderOutsideWarningPeriod@@Tests/LicenseStatus.wlt:754,1-759,2"
]

(* The license tool gets no reminder *)
VerificationTest[
    licenseToolCall[ licenseServer, $warningLicense, "WolframLicenseStatus", <| |> ],
    <|
        "content" -> { <| "type" -> "text", "text" -> _String? (StringContainsQ[ "Days remaining: 3" ]) |> },
        "isError" -> False
    |>,
    SameTest -> MatchQ,
    TestID   -> "LicenseServer-Warning-LicenseToolNoReminder@@Tests/LicenseStatus.wlt:762,1-770,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Expiration*)
VerificationTest[
    Module[ { before, result },
        before = $licenseEchoCalls;
        result = licenseToolCall[ licenseServer, $expiredLicense, "LicenseEcho", <| "x" -> "hi" |> ];
        { result, $licenseEchoCalls - before }
    ],
    {
        <|
            "content" -> {
                <|
                    "type" -> "text",
                    "text" -> "Your MCP server license has expired. Visit https://example.com/renew for instructions on how to continue."
                |>
            },
            "isError" -> True
        |>,
        0
    },
    SameTest -> SameQ,
    TestID   -> "LicenseServer-Expired-ToolNotRun@@Tests/LicenseStatus.wlt:775,1-795,2"
]

(* Sanity check for the test above: the same call runs the tool with a valid license *)
VerificationTest[
    Module[ { before, result },
        before = $licenseEchoCalls;
        result = licenseToolCall[ licenseServer, $validLicense, "LicenseEcho", <| "x" -> "hi" |> ];
        { result, $licenseEchoCalls - before }
    ],
    { $echoResult, 1 },
    SameTest -> SameQ,
    TestID   -> "LicenseServer-Valid-ToolRuns@@Tests/LicenseStatus.wlt:798,1-807,2"
]

VerificationTest[
    {
        licenseToolCall[ licenseServer, <| "Expired" -> True, "ExpirationDate" -> DatePlus[ Now, Quantity[ 30, "Days" ] ] |>, "LicenseEcho", <| "x" -> "hi" |> ],
        licenseToolCall[ licenseServer, <| "ExpirationDate" -> None |>, "LicenseEcho", <| "x" -> "hi" |> ]
    },
    {
        <| "content" -> { <| "type" -> "text", "text" -> "Your MCP server license has expired." |> }, "isError" -> True |>,
        <| "content" -> { <| "type" -> "text", "text" -> "Your MCP server license has expired." |> }, "isError" -> True |>
    },
    SameTest -> SameQ,
    TestID   -> "LicenseServer-Expired-ExpiredTrueAndNoneDate@@Tests/LicenseStatus.wlt:809,1-820,2"
]

(* The license tool keeps working after expiration, without an appended reminder *)
VerificationTest[
    licenseToolCall[ licenseServer, $expiredLicense, "WolframLicenseStatus", <| |> ],
    <|
        "content" -> {
            <|
                "type" -> "text",
                "text" -> _String? (StringStartsQ[ "Your MCP server license has expired. Visit https://example.com/renew" ])
            |>
        },
        "isError" -> False
    |>,
    SameTest -> MatchQ,
    TestID   -> "LicenseServer-Expired-LicenseToolRuns@@Tests/LicenseStatus.wlt:823,1-836,2"
]

VerificationTest[
    licenseToolCall[ licenseServerWithTool, $expiredLicense, "WolframLicenseStatus", <| |> ][ "isError" ],
    False,
    SameTest -> SameQ,
    TestID   -> "LicenseServer-Expired-ListedLicenseToolRuns@@Tests/LicenseStatus.wlt:838,1-843,2"
]

(* The license is read again on every request: a server started with a valid license expires on time *)
VerificationTest[
    With[ { state = licenseServerState[ licenseServer, $validLicense ] },
        {
            licenseRequest[ state, $validLicense, "tools/call", <| "name" -> "LicenseEcho", "arguments" -> <| "x" -> "hi" |> |> ][ "result" ],
            licenseRequest[ state, $expiredLicense, "tools/call", <| "name" -> "LicenseEcho", "arguments" -> <| "x" -> "hi" |> |> ][ "result", "isError" ]
        }
    ],
    { $echoResult, True },
    SameTest -> SameQ,
    TestID   -> "LicenseServer-LicenseReadOnEveryRequest@@Tests/LicenseStatus.wlt:846,1-856,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Prompts*)
$licensePromptCalls = 0;

(* A prompt whose function counts its calls, so tests can tell whether it ran *)
$licensePromptLookup = <|
    "LicensePrompt" -> <|
        "Name"    -> "LicensePrompt",
        "Type"    -> "Function",
        "Content" -> Function[ $licensePromptCalls++; "prompt text" ]
    |>
|>;

licensePromptGet[ info_ ] :=
    Block[
        {
            $StandaloneMCPServerInformation        = info,
            Wolfram`AgentTools`Server`$promptLookup = $licensePromptLookup
        },
        Wolfram`AgentTools`Common`handleMethod[
            "prompts/get",
            <| "jsonrpc" -> "2.0", "id" -> 1, "method" -> "prompts/get", "params" -> <| "name" -> "LicensePrompt" |> |>,
            <| "jsonrpc" -> "2.0", "id" -> 1 |>
        ]
    ];

$promptResult = <|
    "jsonrpc" -> "2.0",
    "id"      -> 1,
    "result"  -> <| "messages" -> { <| "role" -> "user", "content" -> <| "type" -> "text", "text" -> "prompt text" |> |> } |>
|>;

VerificationTest[
    Module[ { before, result },
        before = $licensePromptCalls;
        result = licensePromptGet @ $expiredLicense;
        { result, $licensePromptCalls - before }
    ],
    {
        <|
            "jsonrpc" -> "2.0",
            "id"      -> 1,
            "error"   -> <|
                "code"    -> -32603,
                "message" -> "Your MCP server license has expired. Visit https://example.com/renew for instructions on how to continue."
            |>
        |>,
        0
    },
    SameTest -> SameQ,
    TestID   -> "LicenseServer-Expired-PromptNotRun@@Tests/LicenseStatus.wlt:891,1-910,2"
]

VerificationTest[
    Module[ { before, results },
        before = $licensePromptCalls;
        results = licensePromptGet /@ { $noLicense, $warningLicense, $validLicense };
        { results, $licensePromptCalls - before }
    ],
    { { $promptResult, $promptResult, $promptResult }, 3 },
    SameTest -> SameQ,
    TestID   -> "LicenseServer-Valid-PromptRuns@@Tests/LicenseStatus.wlt:912,1-921,2"
]

(* :!CodeAnalysis::EndBlock:: *)
