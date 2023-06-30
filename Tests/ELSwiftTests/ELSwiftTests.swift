import XCTest
@testable import ELSwift

final class ELSwiftTests: XCTestCase {
    let objectList:[String] = ["05ff01"]
    override func setUp() {
        super.setUp()
        
        print("#==========")
        print("# setUp")
        let exp = expectation(description: "EL initialize")

        do{
            try ELSwift.initialize(objectList, { rinfo, els, err in
                if let error = err {
                    print (error)
                    return
                }
                
                if let elsv = els {
                    let seoj = elsv.SEOJ.map{ String($0, radix:16) }
                    let esv = String(elsv.ESV, radix:16)
                    let detail = elsv.DETAIL.map{ String($0, radix:16) }
                    let edata = elsv.EDATA
                    if( elsv.SEOJ[0...1] == [0x01, 0x35] ) { // air cleanerからの送信だけ処理する
                        print("air cleaner \(seoj)  \(esv)  \(detail)  \(edata)")
                    }
                }
            }, 4)
            exp.fulfill()
        }catch{
            print("setUp error")
        }

        wait(for: [exp], timeout: 5.0)
    }
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        print("==== ELSwift Test ====")
        // 送信系のテストはどうやるの？パケットがでない
        print("# search")
        try ELSwift.search()
        print("# sendString")
        try ELSwift.sendString( "192.168.2.51", "1081000005ff010ef00162018000")
        print("# sendOPC1")
        try ELSwift.sendOPC1( "192.168.2.52", [0x05, 0xff, 0x01], [0x0e,0xf0,0x01], ELSwift.GET, 0x80, [0x00])
        
        // 変換系テスト
        
        // 終了まち
        
        // 終了
        ELSwift.release()
    }
}
