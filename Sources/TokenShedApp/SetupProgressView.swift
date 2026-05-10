import SwiftUI

struct SetupProgressView: View {
    let status: SetupStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Readiness")
                    .font(.headline)

                Spacer()

                Text("\(completedCount) of \(items.count)")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(items) { item in
                    SetupProgressRow(item: item)

                    if item.id != items.last?.id {
                        Divider()
                            .padding(.leading, 34)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 1)
            )
        }
    }

    private var completedCount: Int {
        items.filter(\.isReady).count
    }

    private var items: [SetupProgressItem] {
        [
            SetupProgressItem(title: "CLI", detail: "tokenshed command available", systemImage: "terminal", state: status.cli),
            SetupProgressItem(title: "Local model", detail: localModelDetail, systemImage: "cpu", state: localModelState),
            SetupProgressItem(title: "Codex", detail: "MCP server configured", systemImage: "sparkles.square.filled.on.square", state: status.codexIntegration),
            SetupProgressItem(title: "Claude Code", detail: "MCP server configured", systemImage: "chevron.left.forwardslash.chevron.right", state: status.claudeIntegration)
        ]
    }

    private var localModelState: SetupState {
        if status.appleIntelligence.isReady || status.ollamaServer.isReady {
            .ready
        } else {
            .needsAction("Choose Apple Intelligence or Ollama.")
        }
    }

    private var localModelDetail: String {
        if status.appleIntelligence.isReady {
            "Apple Foundation Models ready"
        } else if status.ollamaServer.isReady {
            "Ollama server ready"
        } else if status.ollamaApp.isReady {
            "Open Ollama to start the local server"
        } else {
            "Apple Intelligence or Ollama needed"
        }
    }
}

struct SetupProgressItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String
    let state: SetupState

    var isReady: Bool {
        state.isReady
    }
}

struct SetupProgressRow: View {
    let item: SetupProgressItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isReady ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isReady ? .green : .secondary)
                .frame(width: 22, height: 22)

            Image(systemName: item.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout.weight(.medium))

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

struct SetupCompleteView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 6) {
                Text("TokenShed is ready")
                    .font(.headline)

                Text("Codex and Claude Code can now ask TokenShed to summarize logs, extract failures, redact text, and prepare debug prompts locally.")
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

