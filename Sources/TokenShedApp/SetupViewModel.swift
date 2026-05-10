import Foundation
import Observation

@Observable
@MainActor
final class SetupViewModel {
    var status = SetupStatus()
    var isRefreshing = false
    var message: String?

    private let service = SetupService()

    func refresh() async {
        isRefreshing = true
        status = await service.checkStatus()
        isRefreshing = false
    }

    func installCLI() async {
        do {
            try service.installCLI()
            message = "Installed tokenshed to ~/.local/bin/tokenshed."
            await refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    func configureCodex() async {
        do {
            try service.configureCodexIntegration()
            message = "Configured Codex to use TokenShed MCP and log-condensing guidance."
            await refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    func configureClaude() async {
        do {
            try service.configureClaudeIntegration()
            message = "Configured Claude Code to use TokenShed MCP and log-condensing guidance."
            await refresh()
        } catch {
            message = error.localizedDescription
        }
    }
}
