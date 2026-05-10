import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public enum AppleFoundationModelAvailability: Sendable, Equatable {
    case available
    case unsupportedOS
    case frameworkUnavailable
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady

    public var setupMessage: String {
        switch self {
        case .available:
            return "Apple Foundation Models are ready."
        case .unsupportedOS:
            return "Foundation Models requires macOS 26 or newer."
        case .frameworkUnavailable:
            return "Foundation Models is not available in this SDK."
        case .deviceNotEligible:
            return "This Mac is not eligible for Apple Intelligence on-device models."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in System Settings."
        case .modelNotReady:
            return "Apple Intelligence is enabled, but the local model is still downloading or preparing."
        }
    }
}

public struct AppleFoundationModelBackend: LocalLanguageModel {
    public let name = "apple-foundation-models"

    public init() {}

    public func isAvailable() async -> Bool {
        await availability() == .available
    }

    public func availability() async -> AppleFoundationModelAvailability {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled):
                return .appleIntelligenceNotEnabled
            case .unavailable(.modelNotReady):
                return .modelNotReady
            @unknown default:
                return .modelNotReady
            }
        } else {
            return .unsupportedOS
        }
        #else
        return .frameworkUnavailable
        #endif
    }

    public func summarize(request: SummaryRequest) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            guard await isAvailable() else {
                throw TokenShedError.backendUnavailable((await availability()).setupMessage)
            }

            let excerpts = request.chunks.prefix(8).map {
                "Lines \($0.startLine)-\($0.endLine):\n\($0.text)"
            }.joined(separator: "\n\n---\n\n")

            let session = LanguageModelSession(
                model: .default,
                instructions: """
                You are a local coding-log condenser. Summarize developer logs for a coding agent.
                Preserve exact file names, line numbers, exception names, command names, and exit codes.
                Do not invent details.
                """
            )

            let response = try await session.respond(
                to: """
                Summarize the relevant failure from these excerpts.

                Output:
                1. Primary failure
                2. Likely cause, if clear
                3. Relevant excerpts to send to a coding agent
                4. Suggested prompt for Codex or Claude Code

                Use plain text. Do not use Markdown code fences.

                Excerpts:
                \(excerpts)
                """,
                options: GenerationOptions(maximumResponseTokens: request.budgetTokens)
            )

            return response.content
        }

        throw TokenShedError.backendUnavailable("Foundation Models requires macOS 26 or newer.")
        #else
        throw TokenShedError.backendUnavailable("Foundation Models framework is not available in this SDK.")
        #endif
    }
}
