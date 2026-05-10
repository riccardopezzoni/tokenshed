import SwiftUI

struct StatusOverview: View {
    let status: SetupStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                GridRow {
                    StatusTile(title: "CLI", state: status.cli, systemImage: "terminal")
                    StatusTile(title: "Apple", state: status.appleIntelligence, systemImage: "apple.logo")
                }

            GridRow {
                StatusTile(title: "Ollama App", state: status.ollamaApp, systemImage: "app.badge")
                StatusTile(title: "Ollama Server", state: status.ollamaServer, systemImage: "network")
            }

            GridRow {
                StatusTile(title: "Codex MCP", state: status.codexIntegration, systemImage: "sparkles.square.filled.on.square")
                StatusTile(title: "Claude MCP", state: status.claudeIntegration, systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }

            Text("Recommended backend: \(status.recommendedBackend)")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct StatusTile: View {
    let title: String
    let state: SetupState
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 28, height: 28)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var label: String {
        switch state {
        case .unknown:
            return "Unknown"
        case .ready:
            return "Ready"
        case .needsAction:
            return "Needs setup"
        case .unavailable:
            return "Unavailable"
        }
    }

    private var iconColor: Color {
        switch state {
        case .ready:
            return .green
        case .needsAction:
            return .orange
        case .unavailable:
            return .red
        case .unknown:
            return .secondary
        }
    }
}
