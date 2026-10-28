(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Tools`LicenseStatus`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];
Needs[ "Wolfram`AgentTools`Tools`"  ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Overview*)
(*
    The time-limited license of the standalone MCP server product (see Specs/StandaloneLicense.md).

    The standalone application describes the license with keys of $StandaloneMCPServerInformation ("ExpirationDate",
    "Expired", "InstructionsURL", "ProductName", "WarningDays"); everywhere else none of them are present, so there is
    no license and nothing changes. The server (Server/Shared.wl) reports the license in the instructions of the
    initialize response, adds the WolframLicenseStatus tool defined here, fails every prompt and every other tool call
    once the license has expired, and appends a reminder to tool results in the warning period. The license is read again on every
    request (licenseStatus), so a long-running server expires on time.

    The standalone application detects license support with KeyExistsQ[$DefaultMCPTools, "WolframLicenseStatus"], so
    the tool must keep this name and stay in $DefaultMCPTools.
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$licenseToolName            = "WolframLicenseStatus";
$defaultLicenseProductName  = "MCP server";
$defaultLicenseWarningDays  = 14;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompts*)
$licenseStatusDescription = "\
Reports the status of this MCP server's time-limited license, if it has one: when it expires, the days remaining, \
and where to find instructions on how to continue. It keeps working after the license has expired.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Messages*)
$licenseExpiresTemplate = StringTemplate[ "Your `ProductName` license expires in `Days`, on `Date`.`Instructions`" ];
$licenseExpiredTemplate = StringTemplate[ "Your `ProductName` license has expired.`Instructions`" ];
$instructionsURLTemplate = StringTemplate[ " Visit `URL` for instructions on how to continue." ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Instructions*)
$licenseInstructionsTemplate = StringTemplate[ "\
This MCP server runs under a time-limited license. `Message` Use the `ToolName` tool to check the status of the \
license. When a tool result ends with a license reminder, pass it on to the user." ];

$expiredLicenseInstructionsTemplate = StringTemplate[ "\
This MCP server runs under a time-limited license. `Message` Every prompt and every tool call other than `ToolName` \
fails.`Help`" ];

$expiredLicenseHelp = " Help the user follow those instructions.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Output*)
$licenseStatusTemplate = StringTemplate[ "\
`Message`

Expiration date: `Date`
Days remaining: `Days``Instructions`" ];

$noLicenseStatus = "This MCP server does not have a time-limited license.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Definition*)
(* Add to $defaultMCPTools Association (initialized in Kernel/Tools/Tools.wl) *)
$defaultMCPTools[ "WolframLicenseStatus" ] := LLMTool @ <|
    "Name"        -> $licenseToolName,
    "DisplayName" -> "Wolfram License Status",
    "Description" -> $licenseStatusDescription,
    "Function"    -> licenseStatusToolEvaluate,
    "Options"     -> { },
    "Parameters"  -> { }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*licenseStatusToolEvaluate*)
licenseStatusToolEvaluate // beginDefinition;
licenseStatusToolEvaluate[ _ ] := licenseStatusText @ licenseStatus[ ];
licenseStatusToolEvaluate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*licenseStatusText*)
licenseStatusText // beginDefinition;

licenseStatusText[ None ] := $noLicenseStatus;

licenseStatusText[ license_Association ] :=
    TemplateApply[
        $licenseStatusTemplate,
        <|
            "Message"      -> license[ "Message" ],
            "Date"         -> Replace[ license[ "ExpirationDate" ], { d_DateObject :> isoDate @ d, _ -> "unknown" } ],
            "Days"         -> license[ "DaysRemaining" ],
            "Instructions" -> Replace[ license[ "InstructionsURL" ], { url_String :> "\nInstructions: " <> url, _ -> "" } ]
        |>
    ];

licenseStatusText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*licenseStatus*)
(* The license as described by $StandaloneMCPServerInformation, evaluated at the given time: None when there is no
   license (neither "Expired" nor "ExpirationDate" is present), otherwise an association with the normalized keys and:

     "Expired"        True when "Expired" is True, the expiration date is missing or invalid (fail closed), or the
                      expiration date has passed
     "DaysRemaining"  calendar days from today to the expiration date, in the time zone of the expiration date
                      (0 when expired, and also when the license expires later today)
     "Warning"        True when the license has not expired and "DaysRemaining" is at most "WarningDays"
     "Message"        the license status for the user, e.g. "Your MCP server license expires in 5 days, on 2026-11-01."
*)
licenseStatus // beginDefinition;

licenseStatus[ ] := licenseStatus[ $StandaloneMCPServerInformation, Now ];

licenseStatus[ info_Association, now_DateObject ] /; KeyExistsQ[ info, "Expired" ] || KeyExistsQ[ info, "ExpirationDate" ] :=
    Module[ { date, url, name, warningDays, expired, days },
        date        = Replace[ Lookup[ info, "ExpirationDate" ], Except[ _DateObject? DateObjectQ ] -> None ];
        url         = Replace[ Lookup[ info, "InstructionsURL" ], Except[ _String? (StringTrim[ # ] =!= "" &) ] -> None ];
        name        = Replace[ Lookup[ info, "ProductName" ], Except[ _String ] -> $defaultLicenseProductName ];
        warningDays = Replace[ Lookup[ info, "WarningDays" ], Except[ _Integer ] -> $defaultLicenseWarningDays ];
        expired     = TrueQ @ Lookup[ info, "Expired" ] || date === None || UnixTime @ date <= UnixTime @ now;
        days        = If[ expired, 0, calendarDaysUntil[ now, date ] ];
        <|
            "ProductName"     -> name,
            "ExpirationDate"  -> date,
            "InstructionsURL" -> url,
            "WarningDays"     -> warningDays,
            "Expired"         -> expired,
            "DaysRemaining"   -> days,
            "Warning"         -> ! expired && days <= warningDays,
            "Message"         -> licenseMessage[ name, expired, days, date, url ]
        |>
    ];

licenseStatus[ _, _DateObject ] := None;

licenseStatus // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*calendarDaysUntil*)
(* Calendar days from the day of `now` to the day of `date`, both taken in the time zone of `date` *)
calendarDaysUntil // beginDefinition;

calendarDaysUntil[ now_DateObject, date_DateObject ] :=
    DayCount[
        DateValue[ TimeZoneConvert[ now, Replace[ date[ "TimeZone" ], None :> $TimeZone ] ], { "Year", "Month", "Day" } ],
        DateValue[ date, { "Year", "Month", "Day" } ]
    ];

calendarDaysUntil // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*licenseMessage*)
licenseMessage // beginDefinition;

licenseMessage[ name_String, True, _, _, url_ ] :=
    TemplateApply[ $licenseExpiredTemplate, <| "ProductName" -> name, "Instructions" -> instructionsSentence @ url |> ];

licenseMessage[ name_String, False, days_Integer, date_DateObject, url_ ] :=
    TemplateApply[
        $licenseExpiresTemplate,
        <|
            "ProductName"  -> name,
            "Days"         -> daysString @ days,
            "Date"         -> isoDate @ date,
            "Instructions" -> instructionsSentence @ url
        |>
    ];

licenseMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*daysString*)
daysString // beginDefinition;
daysString[ 0 ] := "less than a day";
daysString[ 1 ] := "1 day";
daysString[ n_Integer ] := ToString @ n <> " days";
daysString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*instructionsSentence*)
instructionsSentence // beginDefinition;
instructionsSentence[ url_String ] := TemplateApply[ $instructionsURLTemplate, <| "URL" -> url |> ];
instructionsSentence[ None ] := "";
instructionsSentence // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*isoDate*)
(* YYYY-MM-DD in the time zone of the date itself *)
isoDate // beginDefinition;
isoDate[ date_DateObject ] := DateString[ date, "ISODate" ];
isoDate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*licenseInstructions*)
(* The license status for the instructions of the initialize response, or None when there is no license *)
licenseInstructions // beginDefinition;

licenseInstructions[ ] := licenseInstructions @ licenseStatus[ ];

licenseInstructions[ None ] := None;

licenseInstructions[ license: KeyValuePattern @ { "Expired" -> True, "InstructionsURL" -> url_ } ] :=
    TemplateApply[
        $expiredLicenseInstructionsTemplate,
        <|
            "Message"  -> license[ "Message" ],
            "ToolName" -> $licenseToolName,
            "Help"     -> If[ StringQ @ url, $expiredLicenseHelp, "" ]
        |>
    ];

licenseInstructions[ license: KeyValuePattern[ "Expired" -> False ] ] :=
    TemplateApply[
        $licenseInstructionsTemplate,
        <| "Message" -> license[ "Message" ], "ToolName" -> $licenseToolName |>
    ];

licenseInstructions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
