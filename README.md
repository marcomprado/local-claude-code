# Local Claude Code

Use the full power of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with **any LLM** — local models, third-party APIs, or self-hosted servers.

Claude Code is an excellent coding assistant with a polished CLI, smart context management, and deep editor integration. But it only works with the Anthropic API. **Local Claude Code** removes that limitation with a single script: it generates the right config file, places it where Claude Code expects it, and sets up a quick-launch command so you can start coding immediately.

## Why use this instead of manually copying the JSON?

- **No guesswork** — the installer asks only what matters (server URL, API key, model name) and fills in every required field correctly, including the five separate model slots Claude Code expects.
- **Quick-launch command** — creates a `local-claude` alias or launcher script so you never have to remember `claude --settings ~/.claude/localllm.json`.
- **Clean uninstall** — one flag removes the config, the alias, and the launcher. No leftover files.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (the installer can set it up for you)
- An LLM server exposing an OpenAI-compatible API (e.g., [LM Studio](https://lmstudio.ai/), [Ollama](https://ollama.com/), [vLLM](https://github.com/vllm-project/vllm), or any remote API)

## Installation

### Mac / Linux / WSL

```bash
git clone https://github.com/YOUR_USER/local-claude-code.git
cd local-claude-code
bash install.sh
```

### Windows (PowerShell)

```powershell
git clone https://github.com/YOUR_USER/local-claude-code.git
cd local-claude-code
.\installps.ps1
```

### What the installer does

The script walks you through three quick steps:

```
============================================
   local-claude installer
   Use Claude Code with any LLM server
============================================

Checking prerequisites...
  [ok] ~/.claude/ directory found

[1/3] LLM Server URL
> Server URL [http://localhost:1234]: http://192.168.1.100:8080

[2/3] API Key (optional)
> API Key:

[3/3] Model Name
> Model name [default_model]: llama3

Generating config...
  [ok] Written to ~/.claude/localllm.json

How would you like to launch local-claude?
  [1] Shell alias (adds 'local-claude' to your shell config)
  [2] Launcher script (~/.local/bin/local-claude)
  [3] Skip (I'll run it manually)
> Choice [1]: 1

  [ok] Alias added to ~/.zshrc

============================================
  Installation complete!
  Run 'local-claude' to start.
============================================
```

After installation, start a session with:

```bash
local-claude
```

Or, if you skipped the launcher setup:

```bash
claude --settings ~/.claude/localllm.json
```

## Uninstall

Remove the config file, shell alias, and launcher script in one command:

```bash
bash install.sh --uninstall
```

PowerShell:

```powershell
.\installps.ps1 -Uninstall
```

## How it works

The installer generates a `localllm.json` settings file at `~/.claude/` that redirects all Claude Code API calls to your server.

Claude Code is then launched with `--settings` pointing to this file, and it uses your LLM server transparently.

> **A note on results:** Different models produce different results. Most local or third-party models will be inconsistent and generally worse than the original Claude models — Claude Code was designed and optimized for Claude, after all. That said, it's a great way to experiment with other models using Claude Code's excellent interface, and the results can still be surprisingly useful depending on the model and task.

## Compatible servers

Any server that exposes an OpenAI-compatible `/v1/chat/completions` endpoint should work. Tested with:

| Server | Example URL |
|--------|-------------|
| LM Studio | `http://localhost:1234` for example ! |
| Any remote API | `https://your-server.com:443` |

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

This project was made by Marco Martinelli, it is open source and available under the [MIT License](LICENSE).
