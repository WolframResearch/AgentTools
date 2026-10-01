PacletObject[<|
    "Name" -> "MockMCPPacletBadBundles",
    "Version" -> "1.0.0",
    "Extensions" -> {
        {"AgentTools",
            "Name" -> "Main",
            "Description" -> {"Not", "a", "string"},
            "MCPServers" -> {"ServerA", "ServerB"},
            "Tools" -> {"GoodTool", "Other/Tool"}
        },
        {"AgentTools",
            "Name" -> "Main",
            "MCPServers" -> {"ServerA"}
        },
        {"AgentTools",
            "Name" -> "ServerA",
            "MCPServers" -> {"ServerB"},
            "MCPPrompts" -> "NotAList"
        },
        {"AgentTools",
            "Name" -> "Bad/Name",
            "MCPServers" -> {"ServerA"}
        },
        {"AgentTools",
            "MCPServers" -> {"ServerA"}
        },
        {"AgentTools",
            "MCPServers" -> {"ServerB"}
        },
        {"AgentTools",
            "Root" -> "MissingRoot",
            "Tools" -> {"GoodTool"}
        }
    }
|>]
