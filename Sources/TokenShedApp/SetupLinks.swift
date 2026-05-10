import AppKit
import Foundation

enum SetupLinks {
    static let appleIntelligenceHelp = URL(string: "https://support.apple.com/guide/mac-help/intro-to-apple-intelligence-mchl46361784/mac")!
    static let ollamaDownload = URL(string: "https://ollama.com/download/mac")!
    static let ollamaMacDocs = URL(string: "https://docs.ollama.com/macos")!

    static func openAppleIntelligenceSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    static func openAppleIntelligenceHelp() {
        NSWorkspace.shared.open(appleIntelligenceHelp)
    }

    static func openOllamaDownload() {
        NSWorkspace.shared.open(ollamaDownload)
    }

    static func openOllamaApp() {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/Ollama.app"), configuration: NSWorkspace.OpenConfiguration())
    }

    static func openOllamaDocs() {
        NSWorkspace.shared.open(ollamaMacDocs)
    }

    static func openProjectReadme() {
        if let bundledReadme = Bundle.main.url(forResource: "README", withExtension: "md") {
            NSWorkspace.shared.open(bundledReadme)
            return
        }

        NSWorkspace.shared.open(URL(string: "https://github.com/riccardopezzoni/tokenshed")!)
    }
}
