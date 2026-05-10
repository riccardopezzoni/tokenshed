import Foundation

public enum BackendKind: String, Sendable, CaseIterable {
    case auto
    case apple
    case ollama
    case parserOnly = "parser-only"
}

public struct SummaryRequest: Sendable, Equatable {
    public let document: ContextDocument
    public let chunks: [ContextChunk]
    public let budgetTokens: Int

    public init(document: ContextDocument, chunks: [ContextChunk], budgetTokens: Int) {
        self.document = document
        self.chunks = chunks
        self.budgetTokens = budgetTokens
    }
}

public protocol LocalLanguageModel: Sendable {
    var name: String { get }
    func isAvailable() async -> Bool
    func summarize(request: SummaryRequest) async throws -> String
}

public struct ParserOnlyBackend: LocalLanguageModel {
    public let name = "parser-only"

    public init() {}

    public func isAvailable() async -> Bool {
        true
    }

    public func summarize(request: SummaryRequest) async throws -> String {
        if let first = request.chunks.first {
            return "Relevant output was found around lines \(first.startLine)-\(first.endLine)."
        }

        return "No obvious failure signals were found."
    }
}

