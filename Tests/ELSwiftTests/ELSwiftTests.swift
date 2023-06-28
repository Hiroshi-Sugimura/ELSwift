import XCTest
@testable import ELSwift

final class ELSwiftTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        print("==== ELSwift Test ====")
        let el = ELSwift()
        el.sendString(toip: "192.168.2.51", message: "10810000")
        el.search()
    }
}
