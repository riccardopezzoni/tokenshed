# TokenShed Privacy

TokenShed is designed to reduce the amount of context sent to coding agents by processing logs locally first.

## Default Behavior

- TokenShed does not include telemetry.
- TokenShed does not send logs, prompts, summaries, statistics, or configuration to TokenShed servers.
- TokenShed does not have a hosted backend.
- Parser-only summarization runs fully on device.

## Local Models

TokenShed can use local model backends when available:

- Apple Foundation Models on supported macOS systems.
- Ollama through the local server at `127.0.0.1:11434`.

Ollama model behavior depends on the user's local Ollama installation and model configuration.

## Agent Integrations

TokenShed can configure Codex and Claude Code to call:

```bash
tokenshed mcp serve
```

Those agents may send TokenShed's condensed output to their own providers according to their own configuration. TokenShed's goal is to reduce that outgoing context before it reaches the agent.

## Local Data

TokenShed stores local usage statistics at:

```text
~/Library/Application Support/TokenShed/metrics.jsonl
```

This file stores estimated token counts and summary metrics. It is used by the app's Statistics tab.

TokenShed may also update local agent configuration files when the user asks the app to configure integrations:

```text
~/.codex/config.toml
Claude Code user MCP configuration
```

## Network Access

Expected network paths:

- Opening Apple help pages in the user's browser.
- Opening Ollama download/docs pages in the user's browser.
- Calling a local Ollama server at `127.0.0.1:11434` when selected or available.

TokenShed does not intentionally call remote TokenShed services.

## Deleting Data

Delete local statistics from the app's Statistics tab, or remove the file manually:

```bash
rm "$HOME/Library/Application Support/TokenShed/metrics.jsonl"
```
