import SwiftUI

struct PrivacyDetailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Privacy")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))

                Text("The current prototype redacts secrets before model processing and never sends logs to a remote service.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                PrivacyRow(title: "Local-only processing", detail: "Apple Foundation Models and Ollama run on this Mac.")
                PrivacyRow(title: "Secret redaction", detail: "API keys, bearer tokens, JWTs, and env-style secrets are redacted before summarization.")
                PrivacyRow(title: "Parser fallback", detail: "If no local model is ready, TokenShed can still extract likely relevant failure chunks deterministically.")
            }
        }
    }
}

struct PrivacyRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.blue)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
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

