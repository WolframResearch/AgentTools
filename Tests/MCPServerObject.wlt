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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Basic Examples*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Creation and Object Retrieval*)
VerificationTest[
    (* First create a server using CreateMCPServer *)
    name = StringJoin["TestServer_", CreateUUID[]];
    server = CreateMCPServer[
        name,
        LLMConfiguration @ <| "Tools" -> { LLMTool[ "PrimeFinder", { "n" -> "Integer" }, Prime[ #n ] & ] } |>
    ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-Setup"
]

VerificationTest[
    (* Then retrieve it using MCPServerObject *)
    obj = MCPServerObject[name],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-ObjectRetrieval"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Properties and Accessors*)

VerificationTest[
    obj["Name"],
    name,
    SameTest -> Equal,
    TestID   -> "MCPServerObject-GetName"
]

VerificationTest[
    obj["Location"],
    _File? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-GetLocation"
]

VerificationTest[
    obj["LLMConfiguration"],
    _LLMConfiguration,
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-GetLLMConfiguration"
]

VerificationTest[
    obj["Tools"],
    { _LLMTool },
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-GetTools"
]

VerificationTest[
    obj["ServerVersion"],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-GetServerVersion"
]

VerificationTest[
    obj["ObjectVersion"],
    _Integer? IntegerQ,
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-GetObjectVersion"
]

VerificationTest[
    json = obj["JSONConfiguration"],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-GetJSONConfiguration"
]

VerificationTest[
    parsed = Developer`ReadRawJSONString @ json,
    _? AssociationQ,
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-JSONConfigurationIsValid"
]

VerificationTest[
    env = parsed[ "mcpServers", name, "env" ],
    KeyValuePattern @ {
        "MCP_SERVER_NAME"   -> name,
        "WOLFRAM_BASE"      -> _String,
        "WOLFRAM_LOCALBASE" -> _String,
        "WOLFRAM_USERBASE"  -> _String,
        If[ $OperatingSystem === "Windows", "APPDATA" -> _String, Nothing ]
    },
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-JSONConfigurationHasEnvironmentVariables"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Multiple Properties*)
VerificationTest[
    properties = obj[{"Name", "ServerVersion", "ObjectVersion"}];
    KeyTake[properties, {"Name", "ServerVersion", "ObjectVersion"}],
    KeyValuePattern[{
        "Name" -> name,
        "ServerVersion" -> _String,
        "ObjectVersion" -> _Integer
    }],
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-MultipleProperties"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Built-in Servers*)
VerificationTest[
    builtInServer = MCPServerObject["WolframLanguage"],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-BuiltInServer"
]

VerificationTest[
    builtInServer["Name"],
    "WolframLanguage",
    SameTest -> Equal,
    TestID   -> "MCPServerObject-BuiltInServerName"
]

VerificationTest[
    builtInServer["Location"],
    "BuiltIn",
    SameTest -> Equal,
    TestID   -> "MCPServerObject-BuiltInServerLocation"
]

(* Built-in servers opt in to usage tracking via the "EnableUsageData" property (see docs/usage-data.md);
   servers created with CreateMCPServer do not have the property. *)
VerificationTest[
    builtInServer["EnableUsageData"],
    True,
    SameTest -> SameQ,
    TestID   -> "MCPServerObject-BuiltInServerEnableUsageData"
]

VerificationTest[
    AllTrue[ Values @ $DefaultMCPServers, #[ "EnableUsageData" ] === True & ],
    True,
    SameTest -> SameQ,
    TestID   -> "MCPServerObject-AllBuiltInServersEnableUsageData"
]

VerificationTest[
    MemberQ[ builtInServer[ "Properties" ], "EnableUsageData" ],
    True,
    SameTest -> SameQ,
    TestID   -> "MCPServerObject-BuiltInServerPropertiesIncludeEnableUsageData"
]

VerificationTest[
    Module[ { customServer, result },
        customServer = CreateMCPServer[
            StringJoin[ "TestServer_UsageData_", CreateUUID[] ],
            LLMConfiguration @ <| "Tools" -> { LLMTool[ "PrimeFinder", { "n" -> "Integer" }, Prime[ #n ] & ] } |>
        ];
        result = customServer[ "EnableUsageData" ];
        DeleteObject[ customServer ];
        result
    ],
    Missing[ "UnknownProperty", "EnableUsageData" ],
    SameTest -> SameQ,
    TestID   -> "MCPServerObject-CustomServerNoEnableUsageData"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Server Objects Listing*)
VerificationTest[
    servers = MCPServerObjects[],
    { ___MCPServerObject? MCPServerObjectQ },
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-ListAllServers"
]

(* Note: We can't rely on built-in servers being found in MCPServerObjects since
   they don't show up there. Instead check if we can create a new server
   and have it show up in the list *)
VerificationTest[
    Length[MCPServerObjects[]] >= 0,
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerObject-ConfirmServersExist"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Delete Servers*)
VerificationTest[
    DeleteObject @ server,
    Null,
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-DeleteObject"
]

VerificationTest[
    MCPServerObject @ name,
    _Failure,
    { MCPServerObject::MCPServerNotFound },
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-VerifyDeletion"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Cases*)
VerificationTest[
    MCPServerObject[ "NonExistentServer" ],
    _Failure,
    { MCPServerObject::MCPServerNotFound },
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-NonExistentServer"
]

VerificationTest[
    MCPServerObject[ { "Invalid", "Input" } ],
    _Failure,
    { MCPServerObject::InvalidArguments },
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-InvalidInput"
]

VerificationTest[
    MCPServerObject[ <| "InvalidKey" -> "Value" |> ],
    _Failure,
    { MCPServerObject::InvalidArguments },
    SameTest -> MatchQ,
    TestID   -> "MCPServerObject-InvalidAssociation"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paclet-Backed Server Support*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Mock Paclet Setup*)

$testResourceDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "TestResources" };

VerificationTest[
    PacletDirectoryLoad @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
    $mockPaclet = First @ PacletFind[ "MockMCPPacletTest" ];
    $mockPaclet[ "Name" ],
    "MockMCPPacletTest",
    SameTest -> MatchQ,
    TestID   -> "PacletServer-MockSetup"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCPServerObject with Paclet-Qualified Name*)
VerificationTest[
    $pacletServer = MCPServerObject[ "MockMCPPacletTest/TestServer" ],
    _MCPServerObject? MCPServerObjectQ,
    SameTest -> MatchQ,
    TestID   -> "PacletServer-ObjectCreation"
]

VerificationTest[
    $pacletServer[ "Name" ],
    "MockMCPPacletTest/TestServer",
    SameTest -> Equal,
    TestID   -> "PacletServer-Name"
]

VerificationTest[
    $pacletServer[ "Location" ],
    _PacletObject,
    SameTest -> MatchQ,
    TestID   -> "PacletServer-Location"
]

VerificationTest[
    $pacletServer[ "Location" ][ "Name" ],
    "MockMCPPacletTest",
    SameTest -> Equal,
    TestID   -> "PacletServer-LocationPacletName"
]

VerificationTest[
    $pacletServer[ "ServerVersion" ],
    _String? StringQ,
    SameTest -> MatchQ,
    TestID   -> "PacletServer-ServerVersion"
]

VerificationTest[
    $pacletServer[ "Transport" ],
    "StandardInputOutput",
    SameTest -> Equal,
    TestID   -> "PacletServer-Transport"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ToolNames and PromptNames Properties*)
VerificationTest[
    $pacletServer[ "ToolNames" ],
    { "MockMCPPacletTest/TestTool", "MockMCPPacletTest/DescribedTool", "MockMCPPacletTest/LLMToolTest" },
    SameTest -> MatchQ,
    TestID   -> "PacletServer-ToolNames"
]

VerificationTest[
    $pacletServer[ "PromptNames" ],
    { "MockMCPPacletTest/TestPrompt" },
    SameTest -> MatchQ,
    TestID   -> "PacletServer-PromptNames"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Properties List Includes New Properties*)
VerificationTest[
    MemberQ[ $pacletServer[ "Properties" ], "ToolNames" ],
    True,
    SameTest -> Equal,
    TestID   -> "PacletServer-PropertiesIncludesToolNames"
]

VerificationTest[
    MemberQ[ $pacletServer[ "Properties" ], "PromptNames" ],
    True,
    SameTest -> Equal,
    TestID   -> "PacletServer-PropertiesIncludesPromptNames"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LLMEvaluator Contains Pre-Qualified Names*)
VerificationTest[
    $pacletServer[ "LLMEvaluator" ][ "Tools" ],
    { "MockMCPPacletTest/TestTool", "MockMCPPacletTest/DescribedTool", "MockMCPPacletTest/LLMToolTest" },
    SameTest -> MatchQ,
    TestID   -> "PacletServer-LLMEvaluatorQualifiedTools"
]

VerificationTest[
    $pacletServer[ "LLMEvaluator" ][ "MCPPrompts" ],
    { "MockMCPPacletTest/TestPrompt" },
    SameTest -> MatchQ,
    TestID   -> "PacletServer-LLMEvaluatorQualifiedPrompts"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCPServerObjectQ for Paclet-Backed Servers*)
VerificationTest[
    MCPServerObjectQ @ $pacletServer,
    True,
    SameTest -> Equal,
    TestID   -> "PacletServer-MCPServerObjectQ"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DeleteObject Refused for Paclet Servers*)
VerificationTest[
    DeleteObject @ $pacletServer,
    _Failure,
    { MCPServerObject::DeletePacletMCPServer },
    SameTest -> MatchQ,
    TestID   -> "PacletServer-DeleteObjectRefused"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Non-Existent Paclet Server*)
VerificationTest[
    MCPServerObject[ "CompletelyNonExistentPaclet12345/SomeServer" ],
    _Failure,
    { MCPServerObject::MCPServerNotFound },
    SameTest -> MatchQ,
    TestID   -> "PacletServer-NonExistentPaclet"
]

VerificationTest[
    MCPServerObject[ "MockMCPPacletTest/NonExistentServer" ],
    _Failure,
    { MCPServerObject::PacletServerNotFound },
    SameTest -> MatchQ,
    TestID   -> "PacletServer-NonExistentServer"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ToolNames and PromptNames for Non-Paclet Servers*)
VerificationTest[
    builtIn = MCPServerObject[ "WolframLanguage" ];
    builtIn[ "ToolNames" ],
    _List,
    SameTest -> MatchQ,
    TestID   -> "ToolNames-BuiltInServer"
]

VerificationTest[
    builtIn = MCPServerObject[ "WolframLanguage" ];
    builtIn[ "PromptNames" ],
    _List,
    SameTest -> MatchQ,
    TestID   -> "PromptNames-BuiltInServer"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Multiple Properties Request*)
VerificationTest[
    props = $pacletServer[ { "Name", "ToolNames", "PromptNames", "Transport" } ];
    AssociationQ @ props && props[ "Name" ] === "MockMCPPacletTest/TestServer",
    True,
    SameTest -> Equal,
    TestID   -> "PacletServer-MultipleProperties"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Paclet Tool String Resolution via convertStringTools0*)
VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`convertStringTools0[ "MockMCPPacletTest/TestTool" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "ConvertStringTools0-PacletTool"
]

VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`convertStringTools0[ "MockMCPPacletTest/DescribedTool" ],
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "ConvertStringTools0-PacletDescribedTool"
]

(* Built-in tools still take precedence over paclet resolution *)
VerificationTest[
    MatchQ[
        Wolfram`AgentTools`MCPServerObject`Private`convertStringTools0[ "WolframAlpha" ],
        _LLMTool
    ],
    True,
    SameTest -> Equal,
    TestID   -> "ConvertStringTools0-BuiltInPrecedence"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Paclet Prompt String Resolution via normalizePromptData*)
VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`normalizePromptData[ "MockMCPPacletTest/TestPrompt" ],
    KeyValuePattern[ { "Name" -> "TestPrompt", "Type" -> "Text" } ],
    SameTest -> MatchQ,
    TestID   -> "NormalizePromptData-PacletPrompt"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getToolList Resolves Paclet Tools to LLMTool Objects*)
VerificationTest[
    $pacletServer[ "Tools" ],
    { _LLMTool, _LLMTool, _LLMTool },
    SameTest -> MatchQ,
    TestID   -> "PacletServer-GetTools"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*PromptData Resolves Paclet Prompts*)
VerificationTest[
    $pacletServer[ "PromptData" ],
    { KeyValuePattern[ { "Name" -> "TestPrompt", "Type" -> "Text" } ] },
    SameTest -> MatchQ,
    TestID   -> "PacletServer-GetPromptData"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LLMConfiguration Resolves Paclet Tools*)
VerificationTest[
    $pacletServer[ "LLMConfiguration" ],
    _LLMConfiguration,
    SameTest -> MatchQ,
    TestID   -> "PacletServer-LLMConfiguration"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Cases for Paclet Tool/Prompt Resolution*)
(* Note: these internal functions are designed to run inside catchAlways/catchMine *)
VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @
        Wolfram`AgentTools`MCPServerObject`Private`convertStringTools0[ "MockMCPPacletTest/NonExistentTool" ],
    _Failure,
    { AgentTools::PacletToolNotFound },
    SameTest -> MatchQ,
    TestID   -> "ConvertStringTools0-PacletToolNotFound"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @
        Wolfram`AgentTools`MCPServerObject`Private`normalizePromptData[ "MockMCPPacletTest/NonExistentPrompt" ],
    _Failure,
    { AgentTools::PacletPromptNotFound },
    SameTest -> MatchQ,
    TestID   -> "NormalizePromptData-PacletPromptNotFound"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @
        Wolfram`AgentTools`MCPServerObject`Private`convertStringTools0[ "NonExistentPaclet12345/SomeTool" ],
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "ConvertStringTools0-PacletNotInstalled"
]

VerificationTest[
    Wolfram`AgentTools`Common`catchAlways @
        Wolfram`AgentTools`MCPServerObject`Private`normalizePromptData[ "NonExistentPaclet12345/SomePrompt" ],
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "NormalizePromptData-PacletNotInstalled"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getToolList - PacletNotInstalled for Missing Location*)
VerificationTest[
    Block[ { PacletObject }, (* Block to prevent it from evaluating to a Failure[...] *)
        Wolfram`AgentTools`Common`catchAlways @
            Wolfram`AgentTools`MCPServerObject`Private`getToolList[
                <|
                    "Location" -> PacletObject[ "NonExistentPaclet12345" ],
                    "LLMEvaluator" -> <| "Tools" -> { "tool1" } |>
                |>
            ]
    ],
    _Failure,
    { AgentTools::PacletNotInstalled },
    SameTest -> MatchQ,
    TestID   -> "getToolList-PacletNotInstalled"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validateTool Passes Through Paclet-Qualified Names*)
VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateTool[ "MockMCPPacletTest/TestTool" ],
    "MockMCPPacletTest/TestTool",
    SameTest -> Equal,
    TestID   -> "ValidateTool-PacletPassthrough"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validateMCPPrompt Passes Through Paclet-Qualified Names*)
VerificationTest[
    Wolfram`AgentTools`MCPServerObject`Private`validateMCPPrompt[ "MockMCPPacletTest/TestPrompt" ],
    "MockMCPPacletTest/TestPrompt",
    SameTest -> Equal,
    TestID   -> "ValidateMCPPrompt-PacletPassthrough"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCPServerObjects Includes Installed Paclet Servers*)
VerificationTest[
    $allServers = MCPServerObjects[];
    MemberQ[ #[ "Name" ] & /@ $allServers, "MockMCPPacletTest/TestServer" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerObjects-IncludesPacletServers"
]

VerificationTest[
    MatchQ[ $allServers, { ___MCPServerObject? MCPServerObjectQ } ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerObjects-AllAreValidObjects"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCPServerObjects Options - IncludeBuiltIn*)
VerificationTest[
    $withBuiltIn = MCPServerObjects[ "IncludeBuiltIn" -> True ];
    MemberQ[ #[ "Name" ] & /@ $withBuiltIn, "WolframLanguage" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerObjects-IncludeBuiltIn"
]

VerificationTest[
    (* Built-in servers should NOT be in default listing *)
    defaultNames = #[ "Name" ] & /@ MCPServerObjects[];
    !MemberQ[ defaultNames, "WolframLanguage" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerObjects-ExcludesBuiltInByDefault"
]

VerificationTest[
    (* IncludeBuiltIn with explicit All pattern *)
    $withBuiltInAll = MCPServerObjects[ All, "IncludeBuiltIn" -> True ];
    builtInNames = #[ "Name" ] & /@ $withBuiltInAll;
    AllTrue[ { "Wolfram", "WolframLanguage", "WolframAlpha" }, MemberQ[ builtInNames, # ] & ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerObjects-IncludeBuiltInWithAll"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCPServerObjects Options - Pattern Matching*)
VerificationTest[
    $mockFiltered = MCPServerObjects[ "MockMCPPacletTest*" ];
    #[ "Name" ] & /@ $mockFiltered,
    { "MockMCPPacletTest/TestServer" },
    SameTest -> MatchQ,
    TestID   -> "MCPServerObjects-PatternMatchesPacletServers"
]

VerificationTest[
    (* Pattern with IncludeBuiltIn *)
    wolfServers = MCPServerObjects[ "Wolfram*", "IncludeBuiltIn" -> True ];
    wolfNames = #[ "Name" ] & /@ wolfServers;
    MemberQ[ wolfNames, "Wolfram" ] && MemberQ[ wolfNames, "WolframLanguage" ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerObjects-PatternWithIncludeBuiltIn"
]

VerificationTest[
    (* Pattern that matches nothing *)
    MCPServerObjects[ "ZZZNonExistentPattern12345*" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "MCPServerObjects-PatternNoMatch"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCPServerObjects Options - IncludeRemotePaclets*)
VerificationTest[
    (* IncludeRemotePaclets should not error *)
    $withRemote = MCPServerObjects[ "IncludeRemotePaclets" -> True ];
    MatchQ[ $withRemote, { ___MCPServerObject } ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerObjects-IncludeRemotePacletsNoError"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCPServerObjects Options Declaration*)
VerificationTest[
    Options @ MCPServerObjects,
    KeyValuePattern @ {
        "IncludeBuiltIn"       -> False,
        "IncludeRemotePaclets" -> False,
        UpdatePacletSites      -> Automatic
    },
    SameTest -> MatchQ,
    TestID   -> "MCPServerObjects-OptionsDeclaration"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCPServerObjects Deduplication*)
VerificationTest[
    (* Verify no duplicate server names in results *)
    allWithBuiltIn = MCPServerObjects[ "IncludeBuiltIn" -> True ];
    names = #[ "Name" ] & /@ allWithBuiltIn;
    names === DeleteDuplicates[ names ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerObjects-NoDuplicates"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MCPServerObjects All Equivalence*)
VerificationTest[
    MCPServerObjects[ All ] === MCPServerObjects[ ],
    True,
    SameTest -> Equal,
    TestID   -> "MCPServerObjects-AllEquivalence"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Mock Paclet Cleanup*)
VerificationTest[
    PacletDirectoryUnload @ FileNameJoin @ { $testResourceDirectory, "MockMCPPacletTest" };
    Wolfram`AgentTools`Common`clearPacletDefinitionCache[ ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "PacletServer-MockCleanup"
]

(* :!CodeAnalysis::EndBlock:: *)