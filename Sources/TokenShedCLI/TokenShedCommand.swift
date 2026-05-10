import TokenShedCore
import Foundation

@main
struct TokenShedCommand {
    static func main() async {
        do {
            try await run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch let error as CLIError {
            FileHandle.standardError.write(Data(error.message.utf8))
            FileHandle.standardError.write(Data("\n".utf8))
            Foundation.exit(error.exitCode)
        } catch {
            FileHandle.standardError.write(Data("tokenshed: \(error.localizedDescription)\n".utf8))
            Foundation.exit(1)
        }
    }

    private static func run(arguments: [String]) async throws {
        guard let command = arguments.first else {
            printHelp()
            return
        }

        switch command {
        case "summarize":
            try await summarize(Array(arguments.dropFirst()))
        case "run":
            try await runCommand(Array(arguments.dropFirst()))
        case "doctor":
            try await doctor()
        case "mcp":
            try await mcp(Array(arguments.dropFirst()))
        case "metrics":
            try await metrics(Array(arguments.dropFirst()))
        case "-h", "--help", "help":
            printHelp()
        default:
            throw CLIError("Unknown command: \(command)", exitCode: 64)
        }
    }

    private static func summarize(_ arguments: [String]) async throws {
        var parser = OptionParser(arguments: arguments)
        let backend = try parser.backend()
        let budget = try parser.intOption(named: "--budget") ?? 2500

        guard let file = parser.nextPositional() else {
            throw CLIError("Usage: tokenshed summarize <file> [--backend auto|apple|ollama|parser-only] [--budget 2500]", exitCode: 64)
        }

        let url = URL(fileURLWithPath: file)
        let text = try String(contentsOf: url, encoding: .utf8)
        let document = ContextDocument(source: .file(url), rawText: text)
        let result = try await MetricsRunner().run(
            document: document,
            options: SummaryOptions(backend: backend, budgetTokens: budget)
        )
        recordMetrics(result.metrics)

        let summary = result.summary

        print(MarkdownRenderer().render(summary))
    }

    private static func runCommand(_ arguments: [String]) async throws {
        var parser = OptionParser(arguments: arguments)
        let backend = try parser.backend()
        let budget = try parser.intOption(named: "--budget") ?? 2500
        let command = parser.remainingPositionals()

        guard let executable = command.first else {
            throw CLIError("Usage: tokenshed run <command> [args...] [--backend auto|apple|ollama|parser-only] [--budget 2500]", exitCode: 64)
        }

        let process = Process()
        process.executableURL = executableURL(for: executable)
        process.arguments = Array(command.dropFirst())

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let document = ContextDocument(
            source: .command(command: executable, arguments: Array(command.dropFirst()), exitCode: process.terminationStatus),
            rawText: output
        )

        let result = try await MetricsRunner().run(
            document: document,
            options: SummaryOptions(backend: backend, budgetTokens: budget)
        )
        recordMetrics(result.metrics)

        print(MarkdownRenderer().render(result.summary))
    }

    private static func doctor() async throws {
        let apple = AppleFoundationModelBackend()
        let ollama = OllamaBackend()
        let parser = ParserOnlyBackend()

        print("TokenShed doctor")
        print("- Apple Foundation Models: \(await apple.isAvailable() ? "available" : "unavailable")")
        print("- Ollama: \(await ollama.isAvailable() ? "available" : "unavailable")")
        print("- Parser-only: \(await parser.isAvailable() ? "available" : "unavailable")")
    }

    private static func mcp(_ arguments: [String]) async throws {
        guard arguments.first == "serve" else {
            throw CLIError("Usage: tokenshed mcp serve", exitCode: 64)
        }

        try await MCPServer().run()
    }

    private static func metrics(_ arguments: [String]) async throws {
        var parser = OptionParser(arguments: arguments)
        let backend = try parser.backend()
        let budget = try parser.intOption(named: "--budget") ?? 2500
        let format = try parser.stringOption(named: "--format") ?? "markdown"

        guard let file = parser.nextPositional() else {
            throw CLIError("Usage: tokenshed metrics <file> [--backend auto|apple|ollama|parser-only] [--budget 2500] [--format markdown|json]", exitCode: 64)
        }

        let url = URL(fileURLWithPath: file)
        let text = try String(contentsOf: url, encoding: .utf8)
        let result = try await MetricsRunner().run(
            document: ContextDocument(source: .file(url), rawText: text),
            options: SummaryOptions(backend: backend, budgetTokens: budget)
        )
        let renderer = MetricsRenderer()

        switch format {
        case "markdown":
            print(renderer.renderMarkdown(result.metrics))
        case "json":
            print(try renderer.renderJSON(result.metrics))
        default:
            throw CLIError("Invalid metrics format: \(format)", exitCode: 64)
        }
    }

    private static func executableURL(for command: String) -> URL {
        if command.contains("/") {
            return URL(fileURLWithPath: command)
        }

        let searchPaths = (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
            .split(separator: ":")
            .map(String.init)

        for path in searchPaths {
            let candidate = URL(fileURLWithPath: path).appendingPathComponent(command)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return URL(fileURLWithPath: command)
    }

    private static func recordMetrics(_ metrics: SummaryMetrics) {
        do {
            try MetricsStore().append(metrics)
        } catch {
            FileHandle.standardError.write(Data("tokenshed: could not record metrics: \(error.localizedDescription)\n".utf8))
        }
    }

    private static func printHelp() {
        print("""
        tokenshed: local context condensation for coding agents

        Commands:
          tokenshed summarize <file> [--backend auto|apple|ollama|parser-only] [--budget 2500]
          tokenshed run <command> [args...] [--backend auto|apple|ollama|parser-only] [--budget 2500]
          tokenshed mcp serve
          tokenshed metrics <file> [--backend auto|apple|ollama|parser-only] [--format markdown|json]
          tokenshed doctor
        """)
    }
}

struct CLIError: Error {
    let message: String
    let exitCode: Int32

    init(_ message: String, exitCode: Int32 = 1) {
        self.message = message
        self.exitCode = exitCode
    }
}

struct OptionParser {
    private var arguments: [String]

    init(arguments: [String]) {
        self.arguments = arguments
    }

    mutating func backend() throws -> BackendKind {
        guard let value = try stringOption(named: "--backend") else {
            return .auto
        }

        guard let backend = BackendKind(rawValue: value) else {
            throw CLIError("Invalid backend: \(value)", exitCode: 64)
        }

        return backend
    }

    mutating func intOption(named name: String) throws -> Int? {
        guard let value = try stringOption(named: name) else {
            return nil
        }

        guard let int = Int(value) else {
            throw CLIError("Invalid integer for \(name): \(value)", exitCode: 64)
        }

        return int
    }

    mutating func stringOption(named name: String) throws -> String? {
        guard let index = arguments.firstIndex(of: name) else {
            return nil
        }

        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            throw CLIError("Missing value for \(name)", exitCode: 64)
        }

        let value = arguments[valueIndex]
        arguments.remove(at: valueIndex)
        arguments.remove(at: index)
        return value
    }

    mutating func nextPositional() -> String? {
        guard let index = arguments.firstIndex(where: { !$0.hasPrefix("--") }) else {
            return nil
        }

        return arguments.remove(at: index)
    }

    mutating func remainingPositionals() -> [String] {
        let values = arguments.filter { !$0.hasPrefix("--") }
        arguments.removeAll()
        return values
    }
}
