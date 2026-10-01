PacletObject[<|
    "Name" -> "MockMCPPacletSkills",
    "Version" -> "1.0.0",
    "Extensions" -> {
        {"AgentTools",
            "Name" -> "SkillsBundle",
            "Description" -> "Servers and skills for testing",
            "MCPServers" -> {"SkillsServer"},
            "Tools" -> {"SkillsTool"},
            "MCPPrompts" -> {"SkillsPrompt"},
            "AgentSkills" -> {
                "directory-skill",
                {"assoc-skill", "A skill defined by an association"},
                "llmskill-skill",
                "combined-skill",
                <|"Name" -> "located-skill"|>,
                "foreign-skill"
            }
        },
        {"AgentTools",
            "Root" -> "DevTools",
            "Name" -> "DevBundle",
            "MCPServers" -> {"SkillsServer", "DevServer"},
            "Tools" -> {"DevTool"},
            "AgentSkills" -> {"directory-skill", "dev-skill"}
        },
        {"AgentTools",
            "Name" -> "PerSystemBundle",
            "SystemID" -> "MockSystem-A",
            "MCPServers" -> {"OtherSystemServer"}
        },
        {"AgentTools",
            "Name" -> "PerSystemBundle",
            "SystemID" -> {"MockSystem-B", "MockSystem-C"},
            "MCPServers" -> {"OtherSystemServer"}
        }
    }
|>]
