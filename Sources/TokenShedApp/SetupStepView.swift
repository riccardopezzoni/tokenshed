import SwiftUI

struct SetupStepView: View {
    let title: String
    let subtitle: String
    let state: SetupState
    let systemImage: String
    let primaryActionTitle: String
    let primaryAction: () -> Void
    var secondaryActionTitle: String?
    var secondaryAction: (() -> Void)?

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

                    Label(stateLabel, systemImage: stateIcon)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(iconColor)
                }

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                stateMessage

                HStack {
                    Button(primaryActionTitle, action: primaryAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(state.isReady)

                    if let secondaryActionTitle, let secondaryAction {
                        Button(secondaryActionTitle, action: secondaryAction)
                            .buttonStyle(.bordered)
                    }
                }
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

    @ViewBuilder
    private var stateMessage: some View {
        switch state {
        case .needsAction(let message), .unavailable(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        case .unknown, .ready:
            EmptyView()
        }
    }

    private var stateLabel: String {
        switch state {
        case .unknown:
            return "Unknown"
        case .ready:
            return "Ready"
        case .needsAction:
            return "Action needed"
        case .unavailable:
            return "Unavailable"
        }
    }

    private var stateIcon: String {
        switch state {
        case .ready:
            return "checkmark.circle.fill"
        case .needsAction:
            return "exclamationmark.circle.fill"
        case .unavailable:
            return "xmark.circle.fill"
        case .unknown:
            return "circle"
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

