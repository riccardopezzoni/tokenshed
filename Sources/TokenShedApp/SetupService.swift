import TokenShedCore
import Foundation

struct SetupService: Sendable {
    func checkStatus() async -> SetupStatus {
        async let cli = checkCLI()
        async let apple = checkAppleIntelligence()
        async let ollamaApp = checkOllamaApp()
        async let ollamaServer = checkOllamaServer()
        async let codex = checkCodexIntegration()
        async let claude = checkClaudeIntegration()

        return await SetupStatus(
            cli: cli,
            appleIntelligence: apple,
            ollamaApp: ollamaApp,
            ollamaServer: ollamaServer,
            codexIntegration: codex,
            claudeIntegration: claude
        )
    }

    func installCLI() throws {
        guard let source = bundledCLIURL() else {
            throw SetupError("Open TokenShed from the packaged app so the bundled tokenshed command can be installed.")
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let binDirectory = home.appending(path: ".local/bin", directoryHint: .isDirectory)
        let destination = binDirectory.appending(path: "tokenshed")

        try FileManager.default.createDirectory(at: binDirectory, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.copyItem(at: source, to: destination)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
    }

    func configureCodexIntegration() throws {
        try ensureInstalledCLI()

        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".codex", directoryHint: .isDirectory)
            .appending(path: "config.toml")
        let ctxPath = installedCLIPath()

        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let existing = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let updated = upsertTOMLTable(
            table: "mcp_servers.tokenshed",
            content: """
            command = "\(ctxPath)"
            args = ["mcp", "serve"]
            startup_timeout_sec = 20
            tool_timeout_sec = 120
            enabled = true
            """,
            in: existing
        )

        try updated.write(to: configURL, atomically: true, encoding: .utf8)
        try installCodexSkill()
    }

    func configureClaudeIntegration() throws {
        try ensureInstalledCLI()

        guard let claudeURL = findExecutable(named: "claude") else {
            throw SetupError("Claude Code CLI was not found. Install Claude Code, then retry.")
        }

        let process = Process()
        process.executableURL = claudeURL
        process.arguments = [
            "mcp",
            "add",
            "--transport",
            "stdio",
            "--scope",
            "user",
            "tokenshed",
            "--",
            installedCLIPath(),
            "mcp",
            "serve"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown Claude Code setup error."
            throw SetupError(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        try installClaudeInstructions()
    }

    private func bundledCLIURL() -> URL? {
        guard let url = Bundle.main.resourceURL?.appending(path: "tokenshed"),
              FileManager.default.isExecutableFile(atPath: url.path) else {
            return nil
        }

        return url
    }

    private func ensureInstalledCLI() throws {
        if let bundled = bundledCLIURL() {
            let destination = URL(fileURLWithPath: installedCLIPath())
            let shouldInstall: Bool

            if FileManager.default.fileExists(atPath: destination.path) {
                shouldInstall = !contentsAreEqual(bundled, destination)
            } else {
                shouldInstall = true
            }

            if shouldInstall {
                try installCLI()
            }

            return
        }

        if FileManager.default.isExecutableFile(atPath: installedCLIPath()) {
            return
        }

        try installCLI()
    }

    private func installedCLIPath() -> String {
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/tokenshed"
    }

    private func contentsAreEqual(_ lhs: URL, _ rhs: URL) -> Bool {
        guard let lhsData = try? Data(contentsOf: lhs),
              let rhsData = try? Data(contentsOf: rhs) else {
            return false
        }

        return lhsData == rhsData
    }

    private func checkCLI() -> SetupState {
        let candidates = [
            "/opt/homebrew/bin/tokenshed",
            "/usr/local/bin/tokenshed",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/tokenshed"
        ]

        if candidates.contains(where: FileManager.default.isExecutableFile) {
            return .ready
        }

        return .needsAction("Install the tokenshed command so agents and terminals can call TokenShed.")
    }

    private func checkAppleIntelligence() async -> SetupState {
        let backend = AppleFoundationModelBackend()

        let availability = await backend.availability()
        if availability == .available {
            return .ready
        }

        return .needsAction("\(availability.setupMessage) Ollama can be used as a fallback.")
    }

    private func checkOllamaApp() -> SetupState {
        if FileManager.default.fileExists(atPath: "/Applications/Ollama.app") {
            return .ready
        }

        if FileManager.default.isExecutableFile(atPath: "/usr/local/bin/ollama") ||
            FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/ollama") {
            return .ready
        }

        return .needsAction("Install Ollama for macOS to use local open models.")
    }

    private func checkOllamaServer() async -> SetupState {
        let backend = OllamaBackend()

        if await backend.isAvailable() {
            return .ready
        }

        return .needsAction("Open Ollama once so its local server starts on 127.0.0.1:11434.")
    }

    private func checkCodexIntegration() -> SetupState {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".codex", directoryHint: .isDirectory)
            .appending(path: "config.toml")

        guard let config = try? String(contentsOf: configURL, encoding: .utf8),
              config.contains("[mcp_servers.tokenshed]") else {
            return .needsAction("Configure Codex to call `tokenshed mcp serve` as a local MCP server.")
        }

        guard FileManager.default.fileExists(atPath: codexSkillURL().path) else {
            return .needsAction("Install TokenShed Codex guidance so noisy logs are condensed automatically.")
        }

        return .ready
    }

    private func checkClaudeIntegration() -> SetupState {
        guard let claudeURL = findExecutable(named: "claude") else {
            return .needsAction("Claude Code CLI was not found.")
        }

        do {
            let output = try runAndCapture(executable: claudeURL, arguments: ["mcp", "list"])
            guard output.contains("tokenshed") else {
                return .needsAction("Configure Claude Code to call `tokenshed mcp serve` as a user-scoped MCP server.")
            }

            guard claudeInstructionsAreInstalled() else {
                return .needsAction("Install TokenShed Claude Code guidance so noisy logs are condensed automatically.")
            }

            return .ready
        } catch {
            return .needsAction("Claude Code MCP status could not be checked.")
        }
    }

    private func installCodexSkill() throws {
        let skillURL = codexSkillURL()

        try FileManager.default.createDirectory(
            at: skillURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try codexSkillContent.write(to: skillURL, atomically: true, encoding: .utf8)
    }

    private func codexSkillURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".codex", directoryHint: .isDirectory)
            .appending(path: "skills", directoryHint: .isDirectory)
            .appending(path: "tokenshed", directoryHint: .isDirectory)
            .appending(path: "SKILL.md")
    }

    private var codexSkillContent: String {
        """
        ---
        name: tokenshed
        description: Use when handling long or noisy build, test, CI, compiler, server, or runtime logs in coding tasks. Condense local logs with TokenShed before reasoning over them or showing them to the user.
        ---

        # TokenShed

        When a coding task includes long command output, failing test output, CI logs, compiler errors, stack traces, server logs, or other noisy local text, use the configured TokenShed MCP tools before reasoning over the full log.

        Prefer:

        - `summarize_log` for noisy logs where diagnosis and relevant excerpts are useful.
        - `prepare_debug_prompt` when you need a compact debugging prompt from a large log.
        - `extract_failures` when deterministic failure extraction is enough.
        - `redact_text` before sharing suspicious secrets or tokens.

        Use TokenShed especially before asking the user to paste long logs or before carrying large command output further into the conversation. Keep the original command output local when the condensed result is enough.
        """
    }

    private func installClaudeInstructions() throws {
        let instructionsURL = claudeInstructionsURL()

        try FileManager.default.createDirectory(
            at: instructionsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let existing = (try? String(contentsOf: instructionsURL, encoding: .utf8)) ?? ""
        let updated = upsertManagedBlock(
            identifier: "tokenshed",
            title: "TokenShed",
            content: """
            When a coding task includes long command output, failing test output, CI logs, compiler errors, stack traces, server logs, or other noisy local text, use the configured TokenShed MCP tools before reasoning over the full log.

            Prefer `summarize_log` for noisy logs, `prepare_debug_prompt` for compact debugging prompts, `extract_failures` for deterministic failure extraction, and `redact_text` before sharing suspicious secrets or tokens.

            Use TokenShed especially before asking the user to paste long logs or before carrying large command output further into the conversation. Keep the original command output local when the condensed result is enough.
            """,
            in: existing
        )

        try updated.write(to: instructionsURL, atomically: true, encoding: .utf8)
    }

    private func claudeInstructionsAreInstalled() -> Bool {
        guard let text = try? String(contentsOf: claudeInstructionsURL(), encoding: .utf8) else {
            return false
        }

        return text.contains("TokenShed managed block start")
    }

    private func claudeInstructionsURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".claude", directoryHint: .isDirectory)
            .appending(path: "CLAUDE.md")
    }

    private func upsertTOMLTable(table: String, content: String, in text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let header = "[\(table)]"
        var output: [String] = []
        var index = 0
        var replaced = false

        while index < lines.count {
            if lines[index].trimmingCharacters(in: .whitespaces) == header {
                output.append(header)
                output.append(contentsOf: content.components(separatedBy: .newlines))
                replaced = true
                index += 1

                while index < lines.count {
                    let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                        break
                    }
                    index += 1
                }
            } else {
                output.append(lines[index])
                index += 1
            }
        }

        if !replaced {
            if !output.isEmpty, output.last != "" {
                output.append("")
            }
            output.append(header)
            output.append(contentsOf: content.components(separatedBy: .newlines))
        }

        return output.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private func upsertManagedBlock(identifier: String, title: String, content: String, in text: String) -> String {
        let start = "<!-- \(title) managed block start: \(identifier) -->"
        let end = "<!-- \(title) managed block end: \(identifier) -->"
        let block = """
        \(start)
        ## \(title)

        \(content)
        \(end)
        """

        guard let startRange = text.range(of: start),
              let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) else {
            let separator = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n\n"
            return text.trimmingCharacters(in: .whitespacesAndNewlines) + separator + block + "\n"
        }

        var updated = text
        updated.replaceSubrange(startRange.lowerBound..<endRange.upperBound, with: block)
        return updated.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private func runAndCapture(executable: URL, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func findExecutable(named name: String) -> URL? {
        let paths = [
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        for path in paths {
            let candidate = URL(fileURLWithPath: path).appending(path: name)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }
}

struct SetupError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
