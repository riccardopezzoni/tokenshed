import Foundation

enum SetupState: Equatable {
    case unknown
    case ready
    case needsAction(String)
    case unavailable(String)

    var isReady: Bool {
        if case .ready = self {
            true
        } else {
            false
        }
    }
}

struct SetupStatus: Equatable {
    var cli: SetupState = .unknown
    var appleIntelligence: SetupState = .unknown
    var ollamaApp: SetupState = .unknown
    var ollamaServer: SetupState = .unknown
    var codexIntegration: SetupState = .unknown
    var claudeIntegration: SetupState = .unknown

    var recommendedBackend: String {
        if appleIntelligence.isReady {
            return "Apple Foundation Models"
        }

        if ollamaServer.isReady {
            return "Ollama"
        }

        return "Parser-only fallback"
    }
}
