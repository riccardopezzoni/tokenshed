import XCTest
@testable import TokenShedCore

final class ChunkerTests: XCTestCase {
    func testExtractsErrorChunk() {
        let log = """
        line one
        line two
        Fatal error: something broke
        Caused by: ExampleException
        line five
        """

        let chunks = LogChunker(contextRadius: 1).chunks(from: log)

        XCTAssertFalse(chunks.isEmpty)
        XCTAssertTrue(chunks[0].signals.contains(.error))
        XCTAssertTrue(chunks[0].signals.contains(.exception))
    }
}

