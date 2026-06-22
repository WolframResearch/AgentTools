# Script Reference

Auto-generated reference for bundled scripts. Pass `--usage` to any
script for the latest argument documentation.

## ReadNotebook.wls

Reads the contents of a Wolfram notebook (.nb) as markdown text.

**Usage:**

```
wolframscript -f scripts/ReadNotebook.wls <notebook>
```

**Arguments:**

| Argument | Required | Description |
| --- | --- | --- |
| `notebook` | Yes | The Wolfram notebook to read, specified as a file path or a NotebookObject[...] |

---

## WriteNotebook.wls

Converts markdown text to a Wolfram notebook and saves it to a file.

**Usage:**

```
wolframscript -f scripts/WriteNotebook.wls <file> <markdown> [--overwrite value]
```

**Arguments:**

| Argument | Required | Description |
| --- | --- | --- |
| `file` | Yes | The file to write the notebook to (must end in .nb). Any missing parent directories are created automatically. |
| `markdown` | Yes | The markdown text to write to a notebook. |
| `--overwrite` | No | Whether to overwrite an existing file (default is False). |

