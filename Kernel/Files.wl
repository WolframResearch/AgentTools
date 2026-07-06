(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AgentTools`Files`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`AgentTools`"        ];
Needs[ "Wolfram`AgentTools`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$rootPath           := migrateRoot @ FileNameJoin @ { $UserBaseDirectory, "ApplicationData", "Wolfram", "AgentTools" };
$storagePath        := FileNameJoin @ { $rootPath, "Servers" };
$deploymentsPath    := FileNameJoin @ { $rootPath, "Deployments" };
$imagePath          := FileNameJoin @ { $rootPath, "Images"  };
$outputLogDirectory := FileNameJoin @ { $UserBaseDirectory, "Logs", "AgentTools", "Output" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Legacy File Migration*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*migrateRoot*)
migrateRoot // beginDefinition;

migrateRoot[ newRoot_ ] := migrateRoot[ newRoot ] =
    Module[ { oldRoot },
        oldRoot = FileNameJoin @ { $UserBaseDirectory, "ApplicationData", "Wolfram", "MCPServer" };
        If[ ! DirectoryQ @ newRoot && DirectoryQ @ oldRoot, CopyDirectory[ oldRoot, newRoot ] ];
        newRoot
    ];

migrateRoot // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Server Files*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mcpServerFile*)
mcpServerFile // beginDefinition;

mcpServerFile[ obj_ ] :=
    mcpServerFile[ obj, "Metadata.wxf" ];

mcpServerFile[ obj_, name_String ] := Enclose[
    Module[ { dir, file },
        dir  = ConfirmMatch[ mcpServerDirectory @ obj, File[ _String ], "Directory" ];
        file = If[ StringContainsQ[ name, "." ], name, URLEncode @ name <> ".wxf" ];
        ConfirmBy[ fileNameJoin[ dir, file ], fileQ, "Result" ]
    ],
    throwInternalFailure
];

mcpServerFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mcpServerDirectory*)
mcpServerDirectory // beginDefinition;

mcpServerDirectory[ name_String ] :=
    fileNameJoin[ $storagePath, URLEncode @ name ];

mcpServerDirectory[ obj_MCPServerObject? MCPServerObjectQ ] :=
    With[ { location = obj[ "Location" ] },
        If[ location === "BuiltIn" || MatchQ[ location, _PacletObject ],
            mcpServerDirectory @ obj[ "Name" ],
            location
        ]
    ];

mcpServerDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mcpServerLogFile*)
mcpServerLogFile // beginDefinition;

mcpServerLogFile[ name_String ] :=
    fileNameJoin[ mcpServerDirectory @ name, "Log.wl" ];

mcpServerLogFile[ obj_MCPServerObject? MCPServerObjectQ ] :=
    Replace[
        obj[ "Location" ],
        {
            "BuiltIn"     :> mcpServerLogFile @ obj[ "Name" ],
            _PacletObject :> mcpServerLogFile @ obj[ "Name" ],
            location_     :> fileNameJoin[ location, "Log.wl" ]
        }
    ];

mcpServerLogFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*outputLogFile*)
outputLogFile // beginDefinition;

outputLogFile[ obj_MCPServerObject? MCPServerObjectQ ] := Enclose[
    Module[ { serverName, timestamp, uniqueID, fileName },
        serverName = ConfirmBy[ obj[ "Name" ], StringQ, "ServerName" ];
        timestamp = DateString[ { "Year", "-", "Month", "-", "Day", "_", "Hour", "-", "Minute", "-", "Second" } ];
        uniqueID = IntegerString[ Hash[ CreateUUID[ ], "MD5" ], 36, 8 ];
        fileName = StringJoin[ URLEncode @ serverName, "_", timestamp, "_", uniqueID, ".log" ];
        ConfirmBy[ ensureFilePath @ fileNameJoin[ $outputLogDirectory, fileName ], fileQ, "Result" ]
    ],
    throwInternalFailure
];

outputLogFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fileQ*)
fileQ // beginDefinition;
fileQ[ File[ file_String ] ] := StringQ @ file;
fileQ[ _ ] := False;
fileQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*directoryQ*)
directoryQ // beginDefinition;
directoryQ[ dir_File ] := DirectoryQ @ dir;
directoryQ[ _ ] := False;
directoryQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fileNameJoin*)
fileNameJoin // beginDefinition;

fileNameJoin[ args___ ] := Enclose[
    Module[ { flat, parts, string },
        flat   = Flatten @ { args };
        parts  = ConfirmMatch[ Replace[ flat, File[ x_String ] :> x, { 1 } ], { __String }, "Parts" ];
        string = ConfirmBy[ FileNameJoin @ parts, StringQ, "String" ];
        ConfirmBy[ toFile @ StringReplace[ string, "\\" -> "/" ], fileQ, "Result" ]
    ],
    throwInternalFailure
];

fileNameJoin // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureDirectory*)
ensureDirectory // beginDefinition;

ensureDirectory[ File[ dir_String ] ] :=
    ensureDirectory @ dir;

ensureDirectory[ dir0_ ] := Enclose[
    Module[ { dir },
        dir = ConfirmBy[ GeneralUtilities`EnsureDirectory @ dir0, DirectoryQ, "Directory" ];
        ConfirmBy[ toFile @ dir, fileQ, "Result" ]
    ],
    throwInternalFailure
];

ensureDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureFilePath*)
ensureFilePath // beginDefinition;

ensureFilePath[ File[ file_String ] ] :=
    ensureFilePath @ file;

ensureFilePath[ file0_String ] := Enclose[
    Module[ { file, dir },
        file = ExpandFileName @ file0;
        dir = ConfirmBy[ ensureDirectory @ DirectoryName @ file, DirectoryQ, "Directory" ];
        ConfirmBy[ toFile @ file, fileQ, "Result" ]
    ],
    throwInternalFailure
];

ensureFilePath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toFile*)
toFile // beginDefinition;
toFile[ file: File[ _String ] ] := file;
toFile[ file_String ] := File @ file;
toFile[ parts_List ] := fileNameJoin @ parts;
toFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Developer Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readWXFFile*)
readWXFFile // beginDefinition;
readWXFFile[ file_ ] := Developer`ReadWXFFile @ ExpandFileName @ file;
readWXFFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeWXFFile*)
writeWXFFile // beginDefinition;

writeWXFFile[ file_, data_, opts: OptionsPattern[ ] ] :=
    Developer`WriteWXFFile[
        ExpandFileName @ ensureFilePath @ file,
        data,
        opts
    ];

writeWXFFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readRawJSONFile*)
(* Effectively equivalent to Developer`ReadRawJSONFile, but it returns Missing[ "EmptyFile" ] if the file is empty. *)
readRawJSONFile // beginDefinition;

readRawJSONFile[ file0_, opts: OptionsPattern[ ] ] := Enclose[
    Catch @ Module[ { file, bytes, string },
        file = ConfirmBy[ ExpandFileName @ file0, StringQ, "File" ];

        (* Let ReadByteArray issue the appropriate messages *)
        bytes = ReadByteArray @ file;
        If[ bytes === EndOfFile, Throw @ Missing[ "EmptyFile" ] ];
        If[ ! ByteArrayQ @ bytes, Throw @ $Failed ];

        (* Return Missing[ "EmptyFile" ] if the file is empty *)
        string = ConfirmBy[ ByteArrayToString[ bytes, "UTF8" ], StringQ, "String" ];
        If[ StringMatchQ[ string, WhitespaceCharacter... ], Throw @ Missing[ "EmptyFile" ] ];

        (* Otherwise, parse the string as JSON *)
        Developer`ReadRawJSONString[ string, opts ]
    ],
    throwInternalFailure
];

readRawJSONFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeRawJSONFile*)
writeRawJSONFile // beginDefinition;

writeRawJSONFile[ file_, data_, opts: OptionsPattern[ ] ] :=
    Developer`WriteRawJSONFile[
        ExpandFileName @ ensureFilePath @ file,
        data,
        opts
    ];

writeRawJSONFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cloud Object Files*)
(* WXF read/write for a CloudObject, used by the cloud-deployment admin API's optional key-label store.
   These are the cloud analogs of readWXFFile / writeWXFFile above. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readCloudWXF*)
(* Read a WXF-encoded association/list from a CloudObject, degrading to Missing[ "NotAvailable" ] when the
   object does not exist or does not hold valid data (a missing object makes CloudImport issue a message
   and return $Failed, which is quieted here). Never throws, so a best-effort label read is safe. *)
readCloudWXF // beginDefinition;

readCloudWXF[ obj_ ] :=
    Replace[
        Quiet @ CloudImport[ obj, "WXF" ],
        Except[ _Association | _List ] -> Missing[ "NotAvailable" ]
    ];

readCloudWXF // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeCloudWXF*)
(* Write data as WXF to a CloudObject. Defaults to Private permissions (the label store is owner-only);
   returns the CloudObject on success or $Failed on failure. *)
writeCloudWXF // beginDefinition;
writeCloudWXF // Options = { Permissions -> "Private" };

writeCloudWXF[ obj_, data_, opts: OptionsPattern[ ] ] :=
    CloudExport[ data, "WXF", obj, Permissions -> OptionValue[ Permissions ] ];

writeCloudWXF // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
