import Foundation
import XCTest
@testable import TokenShedCore

final class MetricsStoreTests: XCTestCase {
    func testMetricsStoreAccumulatesTotals() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "metrics.jsonl")
        let store = MetricsStore(fileURL: url)

        try store.append(sampleMetrics(input: 1_000, prompt: 200, redactions: 2))
        try store.append(sampleMetrics(input: 400, prompt: 100, redactions: 1))

        let totals = try store.totals()

        XCTAssertEqual(totals.runCount, 2)
        XCTAssertEqual(totals.rawTokens, 350)
        XCTAssertEqual(totals.promptTokens, 75)
        XCTAssertEqual(totals.tokensAvoided, 275)
        XCTAssertEqual(totals.redactionCount, 3)
    }

    func testMetricsStoreResetRemovesRecordedTotals() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "metrics.jsonl")
        let store = MetricsStore(fileURL: url)

        try store.append(sampleMetrics(input: 1_000, prompt: 200, redactions: 2))
        try store.reset()

        XCTAssertEqual(try store.totals(), .empty)
    }

    private func sampleMetrics(input: Int, prompt: Int, redactions: Int) -> SummaryMetrics {
        SummaryMetrics(
            sourceName: "sample.log",
            backendName: "parser-only",
            latencyMilliseconds: 1,
            inputLineCount: 10,
            inputCharacterCount: input,
            excerptLineCount: 2,
            excerptCharacterCount: prompt,
            omittedLineCount: 8,
            redactionCount: redactions,
            diagnosisCharacterCount: 10,
            suggestedPromptCharacterCount: prompt
        )
    }
}
