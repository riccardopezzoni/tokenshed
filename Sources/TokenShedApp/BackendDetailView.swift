import SwiftUI

struct BackendDetailView: View {
    let status: SetupStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Backends")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))

                Text("TokenShed prefers Apple Foundation Models, then falls back to Ollama, then parser-only extraction.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            StatusOverview(status: status)

            VStack(alignment: .leading, spacing: 12) {
                BackendRow(
                    title: "Apple Foundation Models",
                    state: status.appleIntelligence,
                    description: "Native on-device model for summarization and extraction when Apple Intelligence is available."
                )

                BackendRow(
                    title: "Ollama",
                    state: status.ollamaServer,
                    description: "Local open-model runtime using the API at 127.0.0.1:11434."
                )

                BackendRow(
                    title: "Parser-only",
                    state: .ready,
                    description: "Deterministic extraction for stack traces, compiler diagnostics, test failures, and secret redaction."
                )

                BackendRow(
                    title: "MCP",
                    state: status.codexIntegration.isReady || status.claudeIntegration.isReady ? .ready : .needsAction("Configure Codex or Claude Code."),
                    description: "Local stdio server exposed by `tokenshed mcp serve` so coding agents can request condensed context."
                )
            }
        }
    }
}

struct BackendRow: View {
    let title: String
    let state: SetupState
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: state.isReady ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(state.isReady ? .green : .secondary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1)
        )
    }
}
