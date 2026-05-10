import XCTest
@testable import TokenShedCore

final class MetricsTests: XCTestCase {
    func testMetricsTrackReductionAndRedactions() async throws {
        let key = "sk-" + ["abcdef", "ghijkl", "mnop123456"].joined()
        let log = """
        line one
        line two
        TaskRepositoryTest FAILED
        Fatal error: something broke
        Caused by: ExampleException
        OPENAI_API_KEY=\(key)
        line seven
        line eight
        """

        let result = try await MetricsRunner().run(
            document: ContextDocument(source: .inline, rawText: log),
            options: SummaryOptions(backend: .parserOnly, budgetTokens: 500)
        )

        XCTAssertEqual(result.metrics.backendName, "parser-only")
        XCTAssertEqual(result.metrics.inputLineCount, 8)
        XCTAssertGreaterThan(result.metrics.excerptLineCount, 0)
        XCTAssertLessThanOrEqual(result.metrics.excerptLineCount, result.metrics.inputLineCount)
        XCTAssertGreaterThan(result.metrics.redactionCount, 0)
        XCTAssertGreaterThanOrEqual(result.metrics.lineReductionPercent, 0)
        XCTAssertGreaterThan(result.metrics.latencyMilliseconds, 0)
        XCTAssertGreaterThan(result.metrics.inputEstimatedTokens, 0)
        XCTAssertGreaterThanOrEqual(result.metrics.tokensAvoidedVsExcerpts, 0)
    }

    func testEstimatedTokenMetricsUseFourCharactersPerToken() {
        let metrics = SummaryMetrics(
            sourceName: "sample.log",
            backendName: "parser-only",
            latencyMilliseconds: 12.5,
            inputLineCount: 100,
            inputCharacterCount: 1_000,
            excerptLineCount: 10,
            excerptCharacterCount: 100,
            omittedLineCount: 90,
            redactionCount: 2,
            diagnosisCharacterCount: 50,
            suggestedPromptCharacterCount: 200
        )

        XCTAssertEqual(metrics.inputEstimatedTokens, 250)
        XCTAssertEqual(metrics.excerptEstimatedTokens, 25)
        XCTAssertEqual(metrics.suggestedPromptEstimatedTokens, 50)
        XCTAssertEqual(metrics.tokensAvoidedVsExcerpts, 225)
        XCTAssertEqual(metrics.tokensAvoidedVsSuggestedPrompt, 200)
    }

    func testMetricsJSONRendererContainsCoreFields() throws {
        let metrics = SummaryMetrics(
            sourceName: "sample.log",
            backendName: "parser-only",
            latencyMilliseconds: 12.5,
            inputLineCount: 100,
            inputCharacterCount: 1_000,
            excerptLineCount: 10,
            excerptCharacterCount: 100,
            omittedLineCount: 90,
            redactionCount: 2,
            diagnosisCharacterCount: 50,
            suggestedPromptCharacterCount: 200
        )

        let json = try MetricsRenderer().renderJSON(metrics)

        XCTAssertTrue(json.contains(#""backendName" : "parser-only""#))
        XCTAssertTrue(json.contains(#""redactionCount" : 2"#))
    }
}
