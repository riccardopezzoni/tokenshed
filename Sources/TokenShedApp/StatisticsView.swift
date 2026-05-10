import TokenShedCore
import SwiftUI

struct StatisticsView: View {
    @State private var model = StatisticsViewModel()
    @State private var isShowingResetConfirmation = false
    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Statistics")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))

                Text("Estimated savings from real local TokenShed runs. Token counts use a rough 4 characters per token approximation.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if model.isLoading {
                ProgressView("Loading recorded savings")
            } else if let total = model.total {
                StatisticsSummaryView(
                    total: total,
                    resetAction: {
                        isShowingResetConfirmation = true
                    }
                )
            } else if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await model.load()
        }
        .onReceive(refreshTimer) { _ in
            Task { await model.load(showLoading: false) }
        }
        .confirmationDialog(
            "Reset Statistics?",
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Statistics", role: .destructive) {
                Task { await model.reset() }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes local TokenShed savings history from this Mac.")
        }
    }
}

struct StatisticsSummaryView: View {
    let total: StatisticsTotal
    let resetAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                GridRow {
                    StatTile(title: "Estimated Saved", value: "\(total.tokensAvoided)", detail: "tokens avoided")
                    StatTile(title: "Reduction", value: "\(formatted(total.reductionPercent))%", detail: "vs raw logs")
                }

                GridRow {
                    StatTile(title: "Raw Logs", value: "\(total.rawTokens)", detail: "estimated tokens")
                    StatTile(title: "Sent Context", value: "\(total.promptTokens)", detail: "estimated tokens")
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)

                Text(total.runCount == 0 ? "No recorded runs yet. Summarize logs through tokenshed or MCP to grow this count." : "Totals are estimated locally from recorded TokenShed runs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)

            if total.runCount > 0 {
                Button("Reset Statistics", systemImage: "trash", role: .destructive, action: resetAction)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

struct StatisticsTotal {
    let runCount: Int
    let rawTokens: Int
    let promptTokens: Int
    let tokensAvoided: Int
    let redactionCount: Int
    let reductionPercent: Double

    init(totals: MetricsStoreTotals) {
        runCount = totals.runCount
        rawTokens = totals.rawTokens
        promptTokens = totals.promptTokens
        tokensAvoided = totals.tokensAvoided
        redactionCount = totals.redactionCount
        reductionPercent = totals.reductionPercent
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 30, weight: .semibold, design: .rounded))

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

@Observable
@MainActor
final class StatisticsViewModel {
    var total: StatisticsTotal?
    var isLoading = false
    var errorMessage: String?

    func load(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil

        do {
            total = try StatisticsLoader().loadTotals()
        } catch {
            errorMessage = error.localizedDescription
        }

        if showLoading {
            isLoading = false
        }
    }

    func reset() async {
        do {
            try StatisticsLoader().resetTotals()
            total = try StatisticsLoader().loadTotals()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct StatisticsLoader: Sendable {
    func loadTotals() throws -> StatisticsTotal {
        StatisticsTotal(totals: try MetricsStore().totals())
    }

    func resetTotals() throws {
        try MetricsStore().reset()
    }
}
