import XCTest
@testable import KSSDiff

final class KSSDiffTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(KSSDiff().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
