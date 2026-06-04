PacletObject[ <|
    "Name"             -> "Wolfram/AgentTools",
    "Description"      -> "Provides tools and integrations for connecting Wolfram Language to AI agents and LLMs",
    "Creator"          -> "Richard Hennigan (Wolfram Research)",
    "Version"          -> "2.1.21",
    "WolframVersion"   -> "14.3+",
    "PublisherID"      -> "Wolfram",
    "License"          -> "MIT",
    "ReleaseID"        -> "$RELEASE_ID$",
    "ReleaseDate"      -> "$RELEASE_DATE$",
    "ReleaseURL"       -> "$RELEASE_URL$",
    "ActionURL"        -> "$ACTION_URL$",
    "CommitURL"        -> "$COMMIT_URL$",
    "PrimaryContext"   -> "Wolfram`AgentTools`",
    "DocumentationURL" -> "https://paclets.com",
    "Loading"          -> Automatic,
    "Extensions"       -> {
        { "Kernel",
            "HiddenImport" -> None,
            "Root"         -> "Kernel",
            "Context"      -> { "Wolfram`AgentTools`" },
            "Symbols"      -> {
                "System`AgentToolsDeployment",
                "System`DeployAgentTools",
                "System`DeployedAgentTools",
                "Wolfram`AgentTools`$AgentToolsContexts",
                "Wolfram`AgentTools`$AgentToolsProtectedNames",
                "Wolfram`AgentTools`$AgentToolsSymbolNames",
                "Wolfram`AgentTools`$DefaultMCPPrompts",
                "Wolfram`AgentTools`$DefaultMCPServers",
                "Wolfram`AgentTools`$DefaultMCPToolOptions",
                "Wolfram`AgentTools`$DefaultMCPTools",
                "Wolfram`AgentTools`$LastAgentToolsFailure",
                "Wolfram`AgentTools`$LastAgentToolsFailureText",
                "Wolfram`AgentTools`$SupportedMCPClients",
                "Wolfram`AgentTools`AgentTools",
                "Wolfram`AgentTools`CodeInspectorToolFunction",
                "Wolfram`AgentTools`CreateMCPServer",
                "Wolfram`AgentTools`CreatePreferencesContent",
                "Wolfram`AgentTools`DetectedMCPClients",
                "Wolfram`AgentTools`InstallMCPServer",
                "Wolfram`AgentTools`ManageWelcomeScreenData",
                "Wolfram`AgentTools`MCPServerObject",
                "Wolfram`AgentTools`MCPServerObjectQ",
                "Wolfram`AgentTools`MCPServerObjects",
                "Wolfram`AgentTools`StartMCPServer",
                "Wolfram`AgentTools`TestReportToolFunction",
                "Wolfram`AgentTools`UninstallMCPServer",
                "Wolfram`AgentTools`ValidateAgentToolsPacletExtension"
            }
        },
        { "FrontEnd",
            "Root" -> "FrontEnd"
        },
        { "Documentation",
            "Root"     -> "Documentation",
            "Language" -> "English"
        },
        { "Asset",
            "Assets" -> {
                { "Apps"               , "Assets/Apps"                    },
                { "SymbolPageTemplate" , "Assets/Templates/SymbolPage.wl" },
                { "TestReportScript"   , "Assets/TestReport.wls"          },
                { "AGENTS.md"          , "AGENTS.md"                      }
            }
        }
    }
|> ]