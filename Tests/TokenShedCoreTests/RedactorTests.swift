import XCTest
@testable import TokenShedCore

final class RedactorTests: XCTestCase {
    func testRedactsBearerToken() {
        let token = ["abcdef", "ghijkl", "mnopqr", "stuvwx", "yz123456"].joined()
        let result = SecretRedactor().redact("Authorization: Bearer \(token)")

        XCTAssertTrue(result.text.contains("Bearer [REDACTED_TOKEN]"))
        XCTAssertEqual(result.reports.first?.kind, "bearer_token")
    }

    func testRedactsAssignmentSecret() {
        let key = "sk-" + ["abcdef", "ghijkl", "mnop123456"].joined()
        let result = SecretRedactor().redact("OPENAI_API_KEY=\(key)")

        XCTAssertTrue(result.text.contains("OPENAI_API_KEY=[REDACTED]"))
    }
}
