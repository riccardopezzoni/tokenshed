import Foundation

public struct RedactionResult: Sendable, Equatable {
    public let text: String
    public let reports: [RedactionReport]
}

public struct SecretRedactor: Sendable {
    public init() {}

    public func redact(_ text: String) -> RedactionResult {
        var output = text
        var reports: [RedactionReport] = []

        for rule in Self.rules {
            let regex = try! NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive])
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            let count = regex.numberOfMatches(in: output, range: range)

            if count > 0 {
                output = regex.stringByReplacingMatches(
                    in: output,
                    range: range,
                    withTemplate: rule.replacement
                )
                reports.append(RedactionReport(kind: rule.name, count: count))
            }
        }

        return RedactionResult(text: output, reports: reports)
    }

    private struct Rule {
        let name: String
        let pattern: String
        let replacement: String
    }

    private static let rules: [Rule] = [
        Rule(
            name: "assignment_secret",
            pattern: #"\b([A-Z0-9_]*(?:TOKEN|SECRET|PASSWORD|API_KEY|ACCESS_KEY)[A-Z0-9_]*)=([^\s]+)"#,
            replacement: "$1=[REDACTED]"
        ),
        Rule(
            name: "api_key",
            pattern: #"(?<![A-Za-z0-9])(?:sk|pk|rk|ak)-[A-Za-z0-9_\-]{16,}"#,
            replacement: "[REDACTED_API_KEY]"
        ),
        Rule(
            name: "bearer_token",
            pattern: #"Bearer\s+[A-Za-z0-9_\-\.=]{20,}"#,
            replacement: "Bearer [REDACTED_TOKEN]"
        ),
        Rule(
            name: "jwt",
            pattern: #"\beyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\b"#,
            replacement: "[REDACTED_JWT]"
        ),
        Rule(
            name: "email",
            pattern: #"\b[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}\b"#,
            replacement: "[REDACTED_EMAIL]"
        )
    ]
}
