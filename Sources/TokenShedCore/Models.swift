import Foundation

public enum ContextSource: Sendable, Equatable {
    case file(URL)
    case command(command: String, arguments: [String], exitCode: Int32?)
    case inline
}

public struct ContextDocument: Sendable, Equatable {
    public let source: ContextSource
    public let rawText: String

    public init(source: ContextSource, rawText: String) {
        self.source = source
        self.rawText = rawText
    }
}

public enum ContextSignal: String, Sendable, Equatable, CaseIterable {
    case error
    case failure
    case exception
    case stackTrace
    case compilerDiagnostic
    case testFailure
    case fileReference
    case exitCode
}

public struct ContextChunk: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let text: String
    public let startLine: Int
    public let endLine: Int
    public let signals: [ContextSignal]
    public let score: Double

    public init(
        id: UUID = UUID(),
        text: String,
        startLine: Int,
        endLine: Int,
        signals: [ContextSignal],
        score: Double
    ) {
        self.id = id
        self.text = text
        self.startLine = startLine
        self.endLine = endLine
        self.signals = signals
        self.score = score
    }
}

public struct RelevantExcerpt: Sendable, Equatable {
    public let text: String
    public let startLine: Int
    public let endLine: Int
    public let score: Double

    public init(text: String, startLine: Int, endLine: Int, score: Double) {
        self.text = text
        self.startLine = startLine
        self.endLine = endLine
        self.score = score
    }
}

public struct RedactionReport: Sendable, Equatable {
    public let kind: String
    public let count: Int

    public init(kind: String, count: Int) {
        self.kind = kind
        self.count = count
    }
}

public struct ContextSummary: Sendable, Equatable {
    public let title: String
    public let diagnosis: String
    public let relevantExcerpts: [RelevantExcerpt]
    public let omittedLineCount: Int
    public let suggestedPrompt: String
    public let redactions: [RedactionReport]
    public let backendName: String

    public init(
        title: String,
        diagnosis: String,
        relevantExcerpts: [RelevantExcerpt],
        omittedLineCount: Int,
        suggestedPrompt: String,
        redactions: [RedactionReport],
        backendName: String
    ) {
        self.title = title
        self.diagnosis = diagnosis
        self.relevantExcerpts = relevantExcerpts
        self.omittedLineCount = omittedLineCount
        self.suggestedPrompt = suggestedPrompt
        self.redactions = redactions
        self.backendName = backendName
    }
}
