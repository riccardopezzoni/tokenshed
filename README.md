# TokenShed

Shed noisy tokens before they reach your coding agent.

TokenShed is a local macOS context condenser for developers using Codex, Claude Code, or other coding agents. It summarizes logs, test output, compiler errors, and terminal output on your machine so agents receive the relevant failure context instead of an entire wall of output.

## Why

Long logs are expensive and distracting. TokenShed sits before your coding agent and turns noisy local output into:

- relevant failure excerpts
- redacted secrets
- compact debug prompts
- estimated token savings

TokenShed is local-first. It has no hosted backend and no telemetry.

## Install

### CLI

Install the CLI with Homebrew:

```bash
brew install riccardopezzoni/tap/tokenshed
```

Upgrade or uninstall with:

```bash
brew upgrade tokenshed
brew uninstall tokenshed
```

Or build from source:

```bash
swift build -c release --product tokenshed
```

### macOS App

`TokenShed.app` is the optional guided setup and statistics surface. It checks local backends, installs the bundled CLI, configures agent integrations, installs lightweight agent guidance for noisy coding logs, and shows estimated tokens avoided.

The app will be distributed as a DMG from the TokenShed website.

TokenShed does not auto-update yet. CLI updates come through Homebrew; app updates are manual downloads.

## CLI Usage

Summarize an existing log:

```bash
tokenshed summarize build.log
```

Run a command and summarize its output:

```bash
tokenshed run swift test
tokenshed run npm test
```

Inspect local backend availability:

```bash
tokenshed doctor
```

Show estimated savings for a file:

```bash
tokenshed metrics build.log
tokenshed metrics build.log --format json
```

Choose a backend:

```bash
tokenshed summarize build.log --backend auto
tokenshed summarize build.log --backend apple
tokenshed summarize build.log --backend ollama
tokenshed summarize build.log --backend parser-only
```

## Agent Integration

TokenShed exposes local MCP tools through:

```bash
tokenshed mcp serve
```

Available tools:

- `summarize_log`
- `extract_failures`
- `redact_text`
- `prepare_debug_prompt`

Codex can use TokenShed via `~/.codex/config.toml`:

```toml
[mcp_servers.tokenshed]
command = "/opt/homebrew/bin/tokenshed"
args = ["mcp", "serve"]
startup_timeout_sec = 20
tool_timeout_sec = 120
enabled = true
```

Claude Code can use TokenShed with:

```bash
claude mcp add --transport stdio --scope user tokenshed -- /opt/homebrew/bin/tokenshed mcp serve
```

The macOS app automates both setup paths. It also installs lightweight guidance so Codex and Claude Code prefer TokenShed when a coding task involves long build, test, CI, compiler, server, or runtime logs.

Guidance is installed locally:

- Codex skill: `~/.codex/skills/tokenshed/SKILL.md`
- Claude Code memory block: `~/.claude/CLAUDE.md`

## Backends

TokenShed chooses the best available local backend:

- Apple Foundation Models on supported macOS systems
- Ollama through the local server at `127.0.0.1:11434`
- parser-only deterministic extraction as the fallback

## Privacy

By default:

- no telemetry
- no TokenShed cloud service
- no hosted backend
- local statistics stored at `~/Library/Application Support/TokenShed/metrics.jsonl`

See [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md).

## Development

Build and test:

```bash
swift build
swift test
swift run tokenshed doctor
```

Run the app during development:

```bash
scripts/build-app.sh
open Build/TokenShed.app
```

Build release artifacts:

```bash
scripts/build-cli-release.sh
scripts/build-release.sh
scripts/build-dmg.sh
```

Maintainer release build:

```bash
export TOKSHED_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export TOKSHED_NOTARY_PROFILE="tokenshed-notary"
scripts/build-signed-release.sh
```

See [docs/SIGNING.md](docs/SIGNING.md) for setup.

## Notices

- [Third-party notices](THIRD_PARTY_NOTICES.md)

## License

MIT. See [LICENSE](LICENSE).
