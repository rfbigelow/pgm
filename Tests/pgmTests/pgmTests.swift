import XCTest
@testable import pgm

final class pgmTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(pgm().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
