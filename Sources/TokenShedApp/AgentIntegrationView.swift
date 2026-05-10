import SwiftUI

struct AgentIntegrationView: View {
    @Bindable var model: SetupViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Agents")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))

                Text("Connect Codex and Claude Code to TokenShed through local MCP tools.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                IntegrationStepView(
                    title: "Codex",
                    subtitle: "Adds the local MCP server and a Codex skill that nudges noisy logs through TokenShed.",
                    state: model.status.codexIntegration,
                    systemImage: "sparkles.square.filled.on.square",
                    actionTitle: "Configure Codex",
                    action: {
                        Task { await model.configureCodex() }
                    }
                )

                IntegrationStepView(
                    title: "Claude Code",
                    subtitle: "Adds the local MCP server and a managed CLAUDE.md block for noisy log condensation.",
                    state: model.status.claudeIntegration,
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    actionTitle: "Configure Claude",
                    action: {
                        Task { await model.configureClaude() }
                    }
                )
            }

            if let message = model.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct IntegrationStepView: View {
    let title: String
    let subtitle: String
    let state: SetupState
    let systemImage: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)

                    Spacer()

                    Label(state.isReady ? "Ready" : "Action needed", systemImage: state.isReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(iconColor)
                }

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if case .needsAction(let message) = state {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .disabled(state.isReady)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1)
        )
    }

    private var iconColor: Color {
        state.isReady ? .green : .orange
    }
}
