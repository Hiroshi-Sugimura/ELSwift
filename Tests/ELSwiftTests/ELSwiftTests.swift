import XCTest
@testable import ELSwift

final class ELSwiftTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        print("==== ELSwift Test ====")
        print("# init")
        try ELSwift.initialize()
        // 送信系のテストはどうやるの？パケットがでない
        print("# search")
        try ELSwift.search()
        print("# sendString")
        try ELSwift.sendString( "192.168.2.51", "1081000005ff010ef00162018000")
        print("# sendOPC1")
        try ELSwift.sendOPC1( "192.168.2.51", [0x05, 0xff, 0x01], [0x0e,0xf0,0x01], ELSwift.GET, 0x80, [0x00])
        
        // 変換系テスト
        
                
    }
}
