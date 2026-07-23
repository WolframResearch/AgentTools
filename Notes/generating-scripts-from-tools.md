```wl
In[1]:= PacletDirectoryLoad["AgentTools"]; Get["Wolfram`AgentTools`"];

In[2]:= toolName = "TestReport";

In[3]:= tool = $DefaultMCPTools[toolName]

Out[3]= LLMTool[...]

In[4]:= data = tool["Data"]

Out[4]= <|"Name" -> "TestReport", "DisplayName" -> "Test Report", "Description" -> "Runs Wolfram Language test files (.wlt) and returns a report of the results", "Function" -> Wolfram`AgentTools`Tools`TestReport`Private`testReport, "Options" -> {}, "Parameters ...  constraint (in bytes) for each test file", "Required" -> False|>, "newKernel" -> <|"Interpreter" -> "Boolean", "Help" -> "Whether to use a fresh kernel for running tests (default is true)", "Required" -> False|>}, "LLMPacletVersion" -> "2.2.10"|>
```

Script name:

```wl
In[5]:= scriptName = data["Name"] <> ".wls"

Out[5]= "TestReport.wls"
```

Get script arguments and options:

```wl
In[6]:= params = Association@data["Parameters"];

In[7]:= arguments = Select[params, #["Required"]&]

Out[7]= <|"paths" -> <|"Interpreter" -> "String", "Help" -> "Comma separated list of paths to Wolfram Language test files (.wlt) or directories of test files", "Required" -> True|>|>

In[8]:= options = Select[params, !#["Required"]&]

Out[8]= <|"timeConstraint" -> <|"Interpreter" -> "Integer", "Help" -> "An optional time constraint (in seconds) for each test file", "Required" -> False|>, "memoryConstraint" -> <|"Interpreter" -> "Integer", "Help" -> "An optional memory constraint (in bytes) for each test file", "Required" -> False|>, "newKernel" -> <|"Interpreter" -> "Boolean", "Help" -> "Whether to use a fresh kernel for running tests (default is true)", "Required" -> False|>|>
```

There is no need to parse script argument strings, since the tool does it automatically:

```wl
In[9]:= tool[<|"paths" -> "AgentTools/Tests/Files.wlt", "timeConstraint" -> "10", "newKernel" -> "true"|>]

Out[9]=
"# Test Results Summary

| Metric | Value |
| --- | --- |
| **Overall Result** | Success |
| **Total Files** | 1 |
| **Total Tests** | 6 |
| **Passed** | 6 (100%) |
| **Failed** | 0 (0%) |
| **Total Time** | 4. s |

## Files.wlt

| Metric | Value |
| --- | --- |
| **Tests** | 6 |
| **Passed** | 6 (100%) |
| **Failed** | 0 (0%) |
| **Time** | 4. s |"
```