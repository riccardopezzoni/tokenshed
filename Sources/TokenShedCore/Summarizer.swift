import Foundation

public enum TokenShedError: Error, LocalizedError {
    case backendUnavailable(String)
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .backendUnavailable(let message), .notImplemented(let message):
            return message
        }
    }
}

public struct SummaryOptions: Sendable, Equatable {
    public let backend: BackendKind
    public let budgetTokens: Int

    public init(backend: BackendKind = .auto, budgetTokens: Int = 2500) {
        self.backend = backend
        self.budgetTokens = budgetTokens
    }
}

public struct ContextSummarizer: Sendable {
    private let redactor: SecretRedactor
    private let chunker: LogChunker

    public init(redactor: SecretRedactor = SecretRedactor(), chunker: LogChunker = LogChunker()) {
        self.redactor = redactor
        self.chunker = chunker
    }

    public func summarize(_ document: ContextDocument, options: SummaryOptions = SummaryOptions()) async throws -> ContextSummary {
        let redaction = redactor.redact(document.rawText)
        let redactedDocument = ContextDocument(source: document.source, rawText: redaction.text)
        let chunks = Array(chunker.chunks(from: redaction.text).prefix(12))
        let backend = await selectBackend(options.backend)
        let diagnosis = try await backend.summarize(request: SummaryRequest(
            document: redactedDocument,
            chunks: chunks,
            budgetTokens: options.budgetTokens
        ))

        let excerpts = chunks.prefix(5).map {
            RelevantExcerpt(text: $0.text, startLine: $0.startLine, endLine: $0.endLine, score: $0.score)
        }

        let totalLines = redaction.text.components(separatedBy: .newlines).count
        let includedLines = excerpts.reduce(0) { $0 + max(0, $1.endLine - $1.startLine + 1) }
        let omitted = max(0, totalLines - includedLines)

        return ContextSummary(
            title: title(for: document),
            diagnosis: diagnosis,
            relevantExcerpts: excerpts,
            omittedLineCount: omitted,
            suggestedPrompt: suggestedPrompt(diagnosis: diagnosis, excerpts: excerpts),
            redactions: redaction.reports,
            backendName: backend.name
        )
    }

    private func selectBackend(_ requested: BackendKind) async -> LocalLanguageModel {
        switch requested {
        case .parserOnly:
            return ParserOnlyBackend()
        case .ollama:
            let backend = OllamaBackend()
            return await backend.isAvailable() ? backend : ParserOnlyBackend()
        case .apple:
            let backend = AppleFoundationModelBackend()
            return await backend.isAvailable() ? backend : ParserOnlyBackend()
        case .auto:
            let apple = AppleFoundationModelBackend()
            if await apple.isAvailable() {
                return apple
            }

            let ollama = OllamaBackend()
            if await ollama.isAvailable() {
                return ollama
            }

            return ParserOnlyBackend()
        }
    }

    private func title(for document: ContextDocument) -> String {
        switch document.source {
        case .file(let url):
            return "Summary for \(url.lastPathComponent)"
        case .command(let command, _, let exitCode):
            if let exitCode {
                return "Summary for \(command), exit code \(exitCode)"
            }
            return "Summary for \(command)"
        case .inline:
            return "Context summary"
        }
    }

    private func suggestedPrompt(diagnosis: String, excerpts: [RelevantExcerpt]) -> String {
        let excerptText = excerpts.map {
            "Lines \($0.startLine)-\($0.endLine):\n\($0.text)"
        }.joined(separator: "\n\n")

        return """
        Please debug this failure. Local TokenShed condensed the original output.

        Diagnosis:
        \(diagnosis)

        Relevant excerpts:
        \(excerptText)
        """
    }
}
