import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case setup = "Setup"
    case backends = "Backends"
    case agents = "Agents"
    case statistics = "Statistics"
    case privacy = "Privacy"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .setup:
            return "checklist"
        case .backends:
            return "cpu"
        case .agents:
            return "point.3.connected.trianglepath.dotted"
        case .statistics:
            return "chart.bar.xaxis"
        case .privacy:
            return "lock.shield"
        }
    }
}

struct OnboardingView: View {
    @Bindable var model: SetupViewModel
    @State private var selection: AppSection? = .setup

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach(AppSection.allCases) { section in
                        Label(section.rawValue, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
            }
            .navigationSplitViewColumnWidth(180)
        } detail: {
            ScrollView {
                detailView
                    .padding(28)
                    .frame(maxWidth: 860, alignment: .leading)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .setup {
        case .setup:
            VStack(alignment: .leading, spacing: 24) {
                header
                SetupProgressView(status: model.status)
                primarySetupAction
                messageView
            }
        case .backends:
            BackendDetailView(status: model.status)
        case .agents:
            AgentIntegrationView(model: model)
        case .statistics:
            StatisticsView()
        case .privacy:
            PrivacyDetailView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TokenShed")
                .font(.system(size: 34, weight: .semibold, design: .rounded))

            Text("Set up local context condensation for Codex, Claude Code, and terminal workflows.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var primarySetupAction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Step")
                .font(.headline)

            nextSetupStep
        }
    }

    @ViewBuilder
    private var nextSetupStep: some View {
        if !model.status.cli.isReady {
            SetupStepView(
                title: "Install tokenshed",
                subtitle: "Adds the command line tool used by terminals and coding agents.",
                state: model.status.cli,
                systemImage: "terminal",
                primaryActionTitle: "Install CLI",
                primaryAction: {
                    Task { await model.installCLI() }
                }
            )
        } else if !model.status.appleIntelligence.isReady && !combinedOllamaState.isReady {
            SetupStepView(
                title: "Choose a local model backend",
                subtitle: "Use Apple Intelligence when available, or install Ollama as a fallback.",
                state: .needsAction("Open Apple Intelligence settings or download Ollama."),
                systemImage: "cpu",
                primaryActionTitle: "Open Settings",
                primaryAction: SetupLinks.openAppleIntelligenceSettings,
                secondaryActionTitle: "Download Ollama",
                secondaryAction: SetupLinks.openOllamaDownload
            )
        } else if !model.status.codexIntegration.isReady || !model.status.claudeIntegration.isReady {
            SetupStepView(
                title: "Connect coding agents",
                subtitle: "Let Codex and Claude Code call TokenShed and prefer it for noisy coding logs.",
                state: combinedAgentState,
                systemImage: "point.3.connected.trianglepath.dotted",
                primaryActionTitle: "Configure Codex",
                primaryAction: {
                    Task { await model.configureCodex() }
                },
                secondaryActionTitle: "Configure Claude",
                secondaryAction: {
                    Task { await model.configureClaude() }
                }
            )
        } else {
            SetupCompleteView()
        }
    }

    @ViewBuilder
    private var messageView: some View {
        if let message = model.message {
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var combinedOllamaState: SetupState {
        if model.status.ollamaApp.isReady && model.status.ollamaServer.isReady {
            return .ready
        }

        if !model.status.ollamaApp.isReady {
            return model.status.ollamaApp
        }

        return model.status.ollamaServer
    }

    private var combinedAgentState: SetupState {
        if model.status.codexIntegration.isReady && model.status.claudeIntegration.isReady {
            return .ready
        }

        return .needsAction("Configure the agents you use so they can call TokenShed locally and prefer it for long logs.")
    }
}
