# WL Evaluator Tool Sessions

## Motivation

Currently, many MCP clients will start a single MCP server process and share it across individual chat sessions. This is good for reducing memory consumption, start-up times, etc, but it can lead to issues when an AI is calling the WolframLanguageEvaluator tool in a new chat conversation if it's already been used in another one:

* Definitions made in previous conversations are still present, so something like `Solve[..., x]` could fail if `x` was previously defined. The AI in the current conversation wouldn't be aware of this.

* Line numbers in outputs would appear to start at a higher value, which could be confusing.

* Switching back and forth between conversation threads often result in definitions that overwrite each other.

## Goals

* We should have a ``"session"`` parameter added to the WolframLanguageEvaluator tool

* This would be an optional parameter, that when not provided indicates that it's the start of a new session

* We would simulate a unique kernel session by using a ``$Context`` based on the session ID

* Sessions would be saved to disk, so they could also be resumed after the MCP server restarts

* When returning a result from the WolframLanguageEvaluator tool, we would append the unique session ID along with instructions to use this ID in future calls to resume the session

## Implementation notes

```wl
In[1]:= Needs["Wolfram`AgentTools`"];
```

### Generating session IDs

Something like this can be used to generate a session ID that's also usable as a context:

```wl
In[1]:=
$letters = Join[CharacterRange["a", "z"], CharacterRange["A", "Z"]];
$characters = Join[$letters, CharacterRange["0", "9"]];
SessionTesting`createSessionID[] := RandomChoice[$letters] <> RandomSample[$characters, 5];

In[4]:= SessionTesting`sessionID = SessionTesting`createSessionID[]

Out[4]= "Y3mK4u"
```

**Note:** The `SessionTesting` namespace is just used in this notebook for demonstration purposes since we're switching contexts. This would not be relevant in actual production code.

### Starting a new session

First we would save the current session (if one has been started already).

Then start a new session via something like the following:

```wl
In[5]:=
SessionTesting`startSession[sessionID_String] := (
	$Context = "Sessions`" <> sessionID <> "`";
	$ContextPath = {$Context, "System`"};
	$ContextAliases = <||>;
	Unprotect[In, InString, Out, MessageList];
	DownValues[In] = {};
	DownValues[InString] = {};
	DownValues[Out] = {};
	DownValues[MessageList] = {};
	Protect[In, InString, Out, MessageList];
	$Line = 0;
);

In[6]:= SessionTesting`startSession[SessionTesting`sessionID]
```

Create test definitions in the new session:

```wl
In[1]:= MyFunction[x_] := x + 1;

In[2]:= MyFunction[5]

Out[2]= 6
```

### Saving sessions

We should use something like this as the storage location (see Files.wl):

```wl
In[3]:= SessionTesting`$sessionsPath := FileNameJoin @ {Wolfram`AgentTools`Common`$rootPath, "Sessions"}
```

Save with something like this:

```wl
In[4]:=
SessionTesting`saveSession[sessionID_String] :=
	Module[{file},
	file = FileNameJoin @ {GeneralUtilities`EnsureDirectory @ SessionTesting`$sessionsPath, sessionID <> ".mx" };
	SessionTesting`$sessionInfo = <|
		"$Context"        -> $Context,
		"$ContextPath"    -> $ContextPath,
		"$ContextAliases" -> $ContextAliases,
		"$Line"           -> $Line,
		"In"              -> DownValues[In],
		"InString"        -> DownValues[InString],
		"Out"             -> DownValues[Out],
		"MessageList"     -> DownValues[MessageList]
	|>;
	DumpSave[file, Evaluate @ {$Context, "SessionTesting`$sessionInfo"}, "SymbolAttributes" -> False];
	file
];
```

Save our current session:

```wl
In[5]:= SessionTesting`saveSession[SessionTesting`sessionID]

Out[5]= "C:\\Users\\rhennigan\\AppData\\Roaming\\Wolfram\\ApplicationData\\Wolfram\\AgentTools\\Sessions\\Y3mK4u.mx"
```

#### Resuming sessions

First start another session:

```wl
In[6]:= SessionTesting`newSessionID = SessionTesting`createSessionID[]

Out[6]= "Go98MP"

In[7]:= SessionTesting`startSession[SessionTesting`newSessionID]

In[1]:= MyFunction[x_] := 2x

In[2]:= MyFunction[5]

Out[2]= 10
```

We can resume another session with something like this:

```wl
In[3]:=
SessionTesting`resumeSession[sessionID_String] :=
	Module[{file, info},
		file = FileNameJoin @ {SessionTesting`$sessionsPath, sessionID <> ".mx"};
		Get@file;
		info = SessionTesting`$sessionInfo;
		$Context = info["$Context"];
		$ContextPath = info["$ContextPath"];
		$ContextAliases = info["$ContextAliases"];
		$Line = info["$Line"];
		Unprotect[In, InString, Out, MessageList];
		DownValues[In] = info["In"];
		DownValues[InString] = info["InString"];
		DownValues[Out] = info["Out"];
		DownValues[MessageList] = info["MessageList"];
		Protect[In, InString, Out, MessageList];
	];
```

Resume our original session:

```wl
In[4]:= SessionTesting`resumeSession[SessionTesting`sessionID]

In[6]:= MyFunction[5]

Out[6]= 6
```

### Additional notes

We should store the current session ID in a persistent ``$currentSessionID``, which should start out as ``None``. That way, we can compare the "session" parameter of an incoming WL evaluator tool call to ``$currentSessionID``. If they are the same, we don't need to resume.

We should save the current session after every WL evaluator tool call. This way, sessions can be resumed even if the MCP server is restarted during a conversation.

There should be some limits for sessions stored on disk:

* A maximum number of session files (e.g. 100)

* A maximum total byte count of session files (e.g. 1 GB)

* A maximum time to persist session files (e.g. 1 month)

Starting, saving, and resuming sessions must be done with the ``useEvaluatorKernel`` wrapper function.