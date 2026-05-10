import Foundation

public struct MarkdownRenderer: Sendable {
    public init() {}

    public func render(_ summary: ContextSummary) -> String {
        var output: [String] = []
        output.append("# \(summary.title)")
        output.append("")
        output.append("## Diagnosis")
        output.append(summary.diagnosis)
        output.append("")

        if !summary.redactions.isEmpty {
            output.append("## Redactions")
            for report in summary.redactions {
                output.append("- \(report.kind): \(report.count)")
            }
            output.append("")
        }

        output.append("## Relevant Excerpts")
        for excerpt in summary.relevantExcerpts {
            output.append("### Lines \(excerpt.startLine)-\(excerpt.endLine)")
            output.append("")
            output.append("```text")
            output.append(excerpt.text)
            output.append("```")
            output.append("")
        }

        output.append("## Omitted")
        output.append("\(summary.omittedLineCount) lines omitted from the condensed output.")
        output.append("")
        output.append("## Suggested Prompt")
        output.append("")
        output.append("```text")
        output.append(summary.suggestedPrompt)
        output.append("```")

        return output.joined(separator: "\n")
    }
}

