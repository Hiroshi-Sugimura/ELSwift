import Testing
@testable import ELSwift
import Foundation

@Suite(.serialized)
struct ELSwiftTests {
    let objectList: [UInt8] = [0x05, 0xff, 0x01]

    init() async throws {
        print("# setUp")
        // 初期化。失敗してもクラッシュしないようにする
        try? ELSwift.initialize(objectList, { (_, _, _) in }, option: (debug:true, ipVer:0, autoGetProperties: true))
        // ネットワークの準備を待つ
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }

    @Test func converter() throws {
        print("==== testConverter ====")
        let a: [UInt8: [UInt8]] = [0x80: [0x30]]
        let result = try ELSwift.parseDetail("01", "800130")
        #expect(result == a)
    }

    @Test func search() throws {
        print("==== testSearch ====")
        // 初期化に失敗（ポート競合など）している場合はスキップ
        guard ELSwift.getIsReady() else {
            print("Skipping search test: ELSwift not ready")
            return
        }
        try ELSwift.search()
    }

    @Test func stopAndRelease() async throws {
        print("==== testStopAndRelease ====")
        await ELSwift.printFacilities()
        ELSwift.stop()
        ELSwift.release()
    }
}

extension ELSwift {
    static func getIsReady() -> Bool {
        return isReady
    }
}
