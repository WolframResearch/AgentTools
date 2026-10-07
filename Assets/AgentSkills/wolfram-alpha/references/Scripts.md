# Script Reference

Auto-generated reference for bundled scripts. Pass `--usage` to any
script for the latest argument documentation.

## WolframAlphaContext.wls

Uses semantic search to retrieve any relevant information from Wolfram Alpha. Always use this tool at the start of new conversations or if the topic changes to ensure you have up-to-date relevant information. This uses semantic search, so the context argument should be written in natural language (not a search query) and contain as much detail as possible (up to 250 words).

**Usage:**

```
wolframscript -f scripts/WolframAlphaContext.wls <context>
```

**Arguments:**

| Argument | Required | Description |
| --- | --- | --- |
| `context` | Yes | A detailed summary of what the user is trying to achieve or learn about. |

---

## WolframAlpha.wls

Use natural language queries with Wolfram|Alpha to get up-to-date computational results about entities in chemistry, physics, geography, history, art, astronomy, and more.
Always use the Wolfram context tool before using this tool to make sure you have the most up-to-date information.

**Usage:**

```
wolframscript -f scripts/WolframAlpha.wls <query>
```

**Arguments:**

| Argument | Required | Description |
| --- | --- | --- |
| `query` | Yes | The query to send to Wolfram\|Alpha. |

