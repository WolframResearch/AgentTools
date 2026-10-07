# Getting the Wolfram Engine

The bundled scripts in this skill require `wolframscript`, the command-line interface to the Wolfram Language. This guide covers installation on each platform.

---

## Check If Already Installed

Run the following in your terminal:

```
wolframscript -code '1+1'
```

If it prints `2`, you're ready to go — no further setup needed.

---

## macOS

### Via Homebrew (recommended)

```bash
brew install --cask wolfram-engine
```

After installation, `wolframscript` should be available on your PATH automatically.

### Manual Download

1. Download the Wolfram Engine from <https://www.wolfram.com/engine/>.
2. Open the `.dmg` and drag **Wolfram Engine** to Applications.
3. Run the app once to complete activation.
4. `wolframscript` is installed at `/usr/local/bin/wolframscript`.

---

## Linux

1. Download the `.sh` installer from <https://www.wolfram.com/engine/>.
2. Run:
   ```bash
   sudo bash WolframEngine_*_Linux.sh
   ```
3. Follow the prompts and activate when complete.

After installation, `wolframscript` is typically at `/usr/bin/wolframscript`.

---

## Windows

1. Download the installer from <https://www.wolfram.com/engine/>.
2. Run the `.exe` installer and follow the prompts.
3. Activate when prompted.
4. `wolframscript.exe` is added to your PATH automatically. If not, the default location is:
   ```
   C:\Program Files\Wolfram Research\WolframScript\wolframscript.exe
   ```

---

## Activation

The Wolfram Engine is free for development use but requires activation with a Wolfram Account. If you don't have one, create an account at <https://account.wolfram.com>.

When you first run `wolframscript`, it will prompt for activation. You can also activate manually:

```
wolframscript -activate
```

---

## Troubleshooting

- **`wolframscript` not found** — Ensure the install directory is on your PATH. You can check the location with `which wolframscript` (macOS/Linux) or `where wolframscript` (Windows).
- **Activation fails** — Check your internet connection and verify your Wolfram Account credentials at <https://account.wolfram.com>.
- **License issues** — The free Wolfram Engine license covers non-production development use. For production or commercial use, see <https://www.wolfram.com/engine/commercial-options/>.

---

## More Information

- Wolfram Engine: <https://www.wolfram.com/engine/>
- Wolfram Account: <https://account.wolfram.com>
