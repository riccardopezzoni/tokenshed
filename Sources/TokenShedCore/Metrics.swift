import Foundation

public struct SummaryMetrics: Sendable, Equatable, Codable {
    public let sourceName: String
    public let backendName: String
    public let latencyMilliseconds: Double
    public let inputLineCount: Int
    public let inputCharacterCount: Int
    public let excerptLineCount: Int
    public let excerptCharacterCount: Int
    public let omittedLineCount: Int
    public let redactionCount: Int
    public let diagnosisCharacterCount: Int
    public let suggestedPromptCharacterCount: Int

    public var excerptLineRatio: Double {
        guard inputLineCount > 0 else { return 0 }
        return Double(excerptLineCount) / Double(inputLineCount)
    }

    public var excerptCharacterRatio: Double {
        guard inputCharacterCount > 0 else { return 0 }
        return Double(excerptCharacterCount) / Double(inputCharacterCount)
    }

    public var lineReductionPercent: Double {
        max(0, 1 - excerptLineRatio) * 100
    }

    public var inputEstimatedTokens: Int {
        Self.estimateTokens(characterCount: inputCharacterCount)
    }

    public var excerptEstimatedTokens: Int {
        Self.estimateTokens(characterCount: excerptCharacterCount)
    }

    public var suggestedPromptEstimatedTokens: Int {
        Self.estimateTokens(characterCount: suggestedPromptCharacterCount)
    }

    public var tokensAvoidedVsExcerpts: Int {
        max(0, inputEstimatedTokens - excerptEstimatedTokens)
    }

    public var tokensAvoidedVsSuggestedPrompt: Int {
        max(0, inputEstimatedTokens - suggestedPromptEstimatedTokens)
    }

    public var tokenReductionPercentVsExcerpts: Double {
        guard inputEstimatedTokens > 0 else { return 0 }
        return Double(tokensAvoidedVsExcerpts) / Double(inputEstimatedTokens) * 100
    }

    public var tokenReductionPercentVsSuggestedPrompt: Double {
        guard inputEstimatedTokens > 0 else { return 0 }
        return Double(tokensAvoidedVsSuggestedPrompt) / Double(inputEstimatedTokens) * 100
    }

    public static func estimateTokens(characterCount: Int) -> Int {
        Int((Double(characterCount) / 4.0).rounded(.up))
    }

    public init(
        sourceName: String,
        backendName: String,
        latencyMilliseconds: Double,
        inputLineCount: Int,
        inputCharacterCount: Int,
        excerptLineCount: Int,
        excerptCharacterCount: Int,
        omittedLineCount: Int,
        redactionCount: Int,
        diagnosisCharacterCount: Int,
        suggestedPromptCharacterCount: Int
    ) {
        self.sourceName = sourceName
        self.backendName = backendName
        self.latencyMilliseconds = latencyMilliseconds
        self.inputLineCount = inputLineCount
        self.inputCharacterCount = inputCharacterCount
        self.excerptLineCount = excerptLineCount
        self.excerptCharacterCount = excerptCharacterCount
        self.omittedLineCount = omittedLineCount
        self.redactionCount = redactionCount
        self.diagnosisCharacterCount = diagnosisCharacterCount
        self.suggestedPromptCharacterCount = suggestedPromptCharacterCount
    }
}

public struct MetricsResult: Sendable, Equatable {
    public let summary: ContextSummary
    public let metrics: SummaryMetrics

    public init(summary: ContextSummary, metrics: SummaryMetrics) {
        self.summary = summary
        self.metrics = metrics
    }
}

public struct MetricsRunner: Sendable {
    private let summarizer: ContextSummarizer

    public init(summarizer: ContextSummarizer = ContextSummarizer()) {
        self.summarizer = summarizer
    }

    public func run(document: ContextDocument, options: SummaryOptions = SummaryOptions()) async throws -> MetricsResult {
        let start = ContinuousClock.now
        let summary = try await summarizer.summarize(document, options: options)
        let duration = start.duration(to: ContinuousClock.now)

        let metrics = SummaryMetrics(
            sourceName: sourceName(for: document),
            backendName: summary.backendName,
            latencyMilliseconds: Double(duration.components.seconds * 1000) + Double(duration.components.attoseconds) / 1_000_000_000_000_000,
            inputLineCount: lineCount(document.rawText),
            inputCharacterCount: document.rawText.count,
            excerptLineCount: summary.relevantExcerpts.reduce(0) { $0 + max(0, $1.endLine - $1.startLine + 1) },
            excerptCharacterCount: summary.relevantExcerpts.reduce(0) { $0 + $1.text.count },
            omittedLineCount: summary.omittedLineCount,
            redactionCount: summary.redactions.reduce(0) { $0 + $1.count },
            diagnosisCharacterCount: summary.diagnosis.count,
            suggestedPromptCharacterCount: summary.suggestedPrompt.count
        )

        return MetricsResult(summary: summary, metrics: metrics)
    }

    private func lineCount(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return text.components(separatedBy: .newlines).count
    }

    private func sourceName(for document: ContextDocument) -> String {
        switch document.source {
        case .file(let url):
            return url.lastPathComponent
        case .command(let command, _, _):
            return command
        case .inline:
            return "inline"
        }
    }
}

public struct MetricsRenderer: Sendable {
    public init() {}

    public func renderMarkdown(_ metrics: SummaryMetrics) -> String {
        """
        # TokenShed Metrics

        - Source: \(metrics.sourceName)
        - Backend: \(metrics.backendName)
        - Latency: \(String(format: "%.1f", metrics.latencyMilliseconds)) ms
        - Input: \(metrics.inputLineCount) lines, \(metrics.inputCharacterCount) chars
        - Excerpts: \(metrics.excerptLineCount) lines, \(metrics.excerptCharacterCount) chars
        - Omitted: \(metrics.omittedLineCount) lines
        - Line reduction: \(String(format: "%.1f", metrics.lineReductionPercent))%
        - Raw estimated tokens: \(metrics.inputEstimatedTokens)
        - Excerpt estimated tokens: \(metrics.excerptEstimatedTokens)
        - Suggested prompt estimated tokens: \(metrics.suggestedPromptEstimatedTokens)
        - Tokens avoided vs excerpts: \(metrics.tokensAvoidedVsExcerpts)
        - Tokens avoided vs suggested prompt: \(metrics.tokensAvoidedVsSuggestedPrompt)
        - Redactions: \(metrics.redactionCount)
        - Diagnosis chars: \(metrics.diagnosisCharacterCount)
        - Suggested prompt chars: \(metrics.suggestedPromptCharacterCount)
        """
    }

    public func renderJSON(_ metrics: SummaryMetrics) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(metrics)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

public struct MetricsStoreTotals: Sendable, Equatable, Codable {
    public let runCount: Int
    public let rawTokens: Int
    public let promptTokens: Int
    public let tokensAvoided: Int
    public let redactionCount: Int

    public var reductionPercent: Double {
        guard rawTokens > 0 else { return 0 }
        return Double(tokensAvoided) / Double(rawTokens) * 100
    }

    public static let empty = MetricsStoreTotals(
        runCount: 0,
        rawTokens: 0,
        promptTokens: 0,
        tokensAvoided: 0,
        redactionCount: 0
    )
}

public struct MetricsStore: Sendable {
    private let fileURL: URL

    public init(fileURL: URL = MetricsStore.defaultURL()) {
        self.fileURL = fileURL
    }

    public static func defaultURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library", directoryHint: .isDirectory)
            .appending(path: "Application Support", directoryHint: .isDirectory)
            .appending(path: "TokenShed", directoryHint: .isDirectory)
            .appending(path: "metrics.jsonl")
    }

    public func append(_ metrics: SummaryMetrics) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(metrics)
        guard let line = String(data: data, encoding: .utf8) else {
            return
        }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((line + "\n").utf8))
            try handle.close()
        } else {
            try (line + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    public func totals() throws -> MetricsStoreTotals {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }

        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let metrics = text
            .split(separator: "\n")
            .compactMap { line -> SummaryMetrics? in
                try? JSONDecoder().decode(SummaryMetrics.self, from: Data(line.utf8))
            }

        return MetricsStoreTotals(
            runCount: metrics.count,
            rawTokens: metrics.reduce(0) { $0 + $1.inputEstimatedTokens },
            promptTokens: metrics.reduce(0) { $0 + $1.suggestedPromptEstimatedTokens },
            tokensAvoided: metrics.reduce(0) { $0 + $1.tokensAvoidedVsSuggestedPrompt },
            redactionCount: metrics.reduce(0) { $0 + $1.redactionCount }
        )
    }

    public func reset() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        try FileManager.default.removeItem(at: fileURL)
    }
}
