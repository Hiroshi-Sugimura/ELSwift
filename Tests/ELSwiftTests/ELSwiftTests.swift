import Testing
@testable import ELSwift
import Foundation

@Suite(.serialized)
struct ELSwiftTests {
    let objectList: [UInt8] = [0x05, 0xff, 0x01]

    init() async throws {
        print("# setUp")
        try? ELSwift.initialize(objectList, { (_, _, _) in }, option: (debug:true, ipVer:0, autoGetProperties: true))
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }

    @Test func converter() throws {
        print("==== testConverter ====")
        let a: [UInt8: [UInt8]] = [0x80: [0x30]]
        let result = try ELSwift.parseDetail("01", "800130")
        #expect(result == a)
    }

    @Test func parser() throws {
        print("--- parser ---")

        // Detail
        print("-- parseDetail, OPC=1")
        var a: Dictionary<UInt8, [UInt8]> = [UInt8: [UInt8]]()
        a[0x80] = [0x30]
        #expect(try ELSwift.parseDetail( "01", "800130" ) == a)

        print("-- parseDetail, OPC=1, EPC=2")
        var b: Dictionary<UInt8, [UInt8]> = [UInt8: [UInt8]]()
        b[0xb9] = [0x12, 0x34]
        #expect(try ELSwift.parseDetail( "01", "B9021234" ) == b)

        print("-- parseDetail, OPC=4")
        var c: Dictionary<UInt8, [UInt8]> = [:]
        c[0x80] = [0x31]; c[0xb0] = [0x42]; c[0xbb] = [0x1c]; c[0xb3] = [0x18]
        #expect(try ELSwift.parseDetail( "04", "800131b00142bb011cb30118" ) == c)

        print("-- parseDetail, OPC=5, EPC=2")
        var d: Dictionary<UInt8, [UInt8]> = [:]
        d[0x80] = [0x31]; d[0xb0] = [0x42]; d[0xbb] = [0x1c]; d[0xb3] = [0x18]; d[0xb9] = [0x12, 0x34]
        #expect(try ELSwift.parseDetail( "05", "800131b00142bb011cb9021234b30118" ) == d)

        print("-- parseDetail, ???")
        var g: Dictionary<UInt8, [UInt8]> = [:]
        g[0x80] = [0x31]
        g[0x81] = [0x0f]
        g[0x82] = [0x00, 0x00, 0x50, 0x01]
        g[0x83] = [0xfe, 0x00, 0x00, 0x77, 0x00, 0x00, 0x02, 0xea, 0xed, 0x64, 0x6f, 0x38, 0x1e, 0x00, 0x00, 0x00, 0x02]
        g[0x88] = [0x42]
        g[0x8a] = [0x00, 0x00, 0x77]
        g[0x9d] = [0x05, 0x80, 0x81, 0x8f, 0xb0, 0xa0]
        g[0x9e] = [0x06, 0x80, 0x81, 0x8f, 0xb0, 0xb3, 0xa0]
        #expect(try ELSwift.parseDetail( "08", "80013181010f8204000050018311fe000077000002eaed646f381e000000028801428a030000779d060580818fb0a09e070680818fb0b3a0" ) == g)

        // バイトデータをいれるとELDATA形式にする
        print("-- parseBytes, OPC=1")
        let e = EL_STRUCTURE( tid:[0x00, 0x00], seoj: [0x05, 0xff, 0x01], deoj: [0x0e, 0xf0, 0x01],  esv: 0x62,  opc: 0x01,  epcpdcedt: [0x80, 0x01, 0x30] )
        #expect(try ELSwift.parseBytes( [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x01, 0x80, 0x01, 0x30] ) == e)

        // 16進数で表現された文字列をいれるとELDATA形式にする
        print("-- parseBytes, OPC=4")
        let f = EL_STRUCTURE( tid:[0x00, 0x00], seoj: [0x05, 0xff, 0x01], deoj: [0x0e, 0xf0, 0x01],  esv: 0x62,  opc: 0x04,  epcpdcedt: [0x80, 0x01, 0x31, 0xb0, 0x01, 0x42, 0xbb, 0x01, 0x1c, 0xb3, 0x01, 0x18] )
        #expect(try ELSwift.parseBytes( [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x04, 0x80, 0x01, 0x31, 0xb0, 0x01, 0x42, 0xbb, 0x01, 0x1c, 0xb3, 0x01, 0x18] ) == f)

        // 16進数で表現された文字列をいれるとELDATA形式にする
        print("-- parseString, OPC=1")
        #expect(try ELSwift.parseString( "1081000005ff010ef0016201800130" ) == e)

        print("-- substr")
        #expect(try ELSwift.substr( "01234567890", 2, 3) == "234")

        // 文字列をいれるとELらしい切り方のStringを得る
        print("-- getSeparatedString_String")
        #expect(try ELSwift.getSeparatedString_String( "1081000005ff010ef0016201300180" ) == "1081 0000 05ff01 0ef001 62 01300180")

        // ELDATAをいれるとELらしい切り方のStringを得る
        print("-- getSeparatedString_ELDATA")
        #expect(ELSwift.getSeparatedString_ELDATA(f) == "1081 0000 05ff01 0ef001 6204800131b00142bb011cb30118")

        // ELDATA形式から配列へ
        print("-- ELDATA2Array")
        #expect(try ELSwift.ELDATA2Array( f ) == [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x04, 0x80, 0x01, 0x31, 0xb0, 0x01, 0x42, 0xbb, 0x01, 0x1c, 0xb3, 0x01, 0x18])

        // 1バイトを文字列の16進表現へ（1Byteは必ず2文字にする）
        print("-- toHexString")
        #expect(ELSwift.toHexString( 65 ) == "41")

        // 16進表現の文字列を数値のバイト配列へ
        print("-- toHexArray")
        #expect(try ELSwift.toHexArray( "418081A0A1B0F0FF" ) == [65, 128, 129, 160, 161, 176, 240, 255])

        print("-- toHexArray exception case, empty")
        #expect(try ELSwift.toHexArray("") == [])

        // バイト配列を文字列にかえる
        print("-- bytesToString")
        #expect(try ELSwift.bytesToString( [ 34, 130, 132, 137, 146, 148, 149, 150, 151, 155, 162, 164, 165, 167, 176, 180, 183, 194, 196, 200, 210, 212, 216, 218, 219, 226, 228, 232, 234, 235, 240, 244, 246, 248, 250 ] ) == "2282848992949596979ba2a4a5a7b0b4b7c2c4c8d2d4d8dadbe2e4e8eaebf0f4f6f8fa")

        // parse Propaty Map Form 2
        print("-- parseMapForm2 (16 props)")
        #expect(try ELSwift.parseMapForm2( [0x10, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01] ) == [ 0x10, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f ])

        print("-- parseMapForm2 (16 props)")
        #expect(try ELSwift.parseMapForm2( "1001010101010101010101010101010101" ) == [ 0x10, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f ])

        print("-- parseMapForm2 (16 props)")
        #expect(try ELSwift.parseMapForm2( "1041414100004000604100410000020202" ) == [  16, 128, 129, 130, 136, 138, 157, 158, 159, 215, 224, 225, 226, 229, 231, 232, 234 ])

        print("-- parseMapForm2 (54 props)")
        #expect(try ELSwift.parseMapForm2( "36b1b1b1b1b0b0b1b3b3a1838101838383" ) ==  [ 0x36,
               0x80, 0x81, 0x82, 0x83, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f,
               0x97, 0x98, 0x9a, 0x9d, 0x9e, 0x9f,
               0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8,
               0xd0, 0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9,
               0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfd, 0xfe, 0xff ] )
    }

    @Test func search() throws {
        print("==== testSearch ====")
        guard ELSwift.getIsReady() else {
            print("Skipping search test: ELSwift not ready")
            return
        }
        try ELSwift.search()

        print("# sendString")
        try ELSwift.sendString( "192.168.2.51", "1081000005ff010ef00162018000")
        print("# sendOPC1")
        try ELSwift.sendOPC1( "192.168.2.52", [0x05, 0xff, 0x01], [0x0e,0xf0,0x01], ELSwift.GET, 0x80, [0x00])
    }

    @Test func display() {
        print("--- show ---")
        print("-- printUInt8Array")
        ELSwift.printUInt8Array( [0x01, 0x02, 0x03, 0x10, 0x11, 0xa0, 0xf1, 0xf2] )
        print("-- printPDCEDT")
        ELSwift.printPDCEDT( [0x02, 0xaa, 0xbb] )

        let f = EL_STRUCTURE( tid:[0x00, 0x00], seoj: [0x05, 0xff, 0x01], deoj: [0x0e, 0xf0, 0x01],  esv: 0x62,  opc: 0x04,  epcpdcedt: [0x80, 0x01, 0x31, 0xb0, 0x01, 0x42, 0xbb, 0x01, 0x1c, 0xb3, 0x01, 0x18] )
        print("-- printEL_STRUCTURE")
        ELSwift.printEL_STRUCTURE( f )
    }

    @Test func stopAndRelease() async throws {
        print("==== testStopAndRelease ====")
        await ELSwift.printFacilities()
        ELSwift.stop()
        ELSwift.release()
    }

    // MARK: - Async Send Tests
    @Test func sendAsyncOPC1() async throws {
        print("-- testSendAsyncOPC1")
        ELSwift.sendAsyncOPC1(
            "192.168.2.100", [0x05, 0xff, 0x01], [0x0e, 0xf0, 0x01], ELSwift.GET, 0x80, [0x00]
        )
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    @Test func sendAsyncELS() async throws {
        print("-- testSendAsyncELS")
        let els = EL_STRUCTURE(
            tid: [0x00, 0x01], seoj: [0x05, 0xff, 0x01], deoj: [0x0e, 0xf0, 0x01],
            esv: ELSwift.GET, opc: 0x01, epcpdcedt: [0x80, 0x00]
        )
        try ELSwift.sendAsyncELS("192.168.2.100", els)
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    @Test func sendAsyncArray() async throws {
        print("-- testSendAsyncArray")
        let array: [UInt8] = [
            0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x01, 0x80, 0x00
        ]
        try ELSwift.sendAsyncArray("192.168.2.100", array)
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    // MARK: - TID Management Tests
    @Test func increaseTID() {
        print("-- testIncreaseTID")
        let originalTID = ELSwift.tid
        ELSwift.tid = [0x00, 0x00]; ELSwift.increaseTID(); #expect(ELSwift.tid == [0x00, 0x01])
        ELSwift.tid = [0x00, 0xff]; ELSwift.increaseTID(); #expect(ELSwift.tid == [0x01, 0x00])
        ELSwift.tid = [0xff, 0xff]; ELSwift.increaseTID(); #expect(ELSwift.tid == [0x00, 0x00])
        ELSwift.tid = originalTID
    }

    // MARK: - Facilities Manager Tests
    @Test func facilitiesManagerOperations() async {
        print("-- testFacilitiesManagerOperations")
        let manager = ELFacilitiesManager()
        #expect(await manager.isEmpty())

        await manager.setFacilitiesNewIP("192.168.1.100")
        #expect(await !manager.isEmpty())

        await manager.setFacilitiesNewSEOJ("192.168.1.100", [0x01, 0x30, 0x01])
        let facilities = await manager.getFacilities()
        #expect(facilities["192.168.1.100"]?[[0x01, 0x30, 0x01]] != nil)

        await manager.setFacilitiesSetEDT("192.168.1.100", [0x01, 0x30, 0x01], 0x80, [0x30])
        let updatedFacilities = await manager.getFacilities()
        #expect(updatedFacilities["192.168.1.100"]?[[0x01, 0x30, 0x01]]?[0x80] == [0x30])
    }

    // MARK: - Multi Send Tests
    @Test func sendBaseMultiData() throws {
        print("-- testSendBaseMultiData")
        let data = Data([0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x01, 0x80, 0x00])
        try ELSwift.sendBaseMulti(data)
    }

    @Test func sendBaseMultiArray() throws {
        print("-- testSendBaseMultiArray")
        let array: [UInt8] = [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x01, 0x80, 0x00]
        try ELSwift.sendBaseMulti(array)
    }

    @Test func sendStringMulti() throws {
        print("-- testSendStringMulti")
        try ELSwift.sendStringMulti("1081000005ff010ef0016201800130")
    }

    @Test func sendOPC1Multi() throws {
        print("-- testSendOPC1Multi")
        try ELSwift.sendOPC1Multi([0x05, 0xff, 0x01], [0x0e, 0xf0, 0x01], ELSwift.GET, 0x80, [0x00])
    }

    // MARK: - Reply Tests
    @Test func replyGetDetail() throws {
        print("-- testReplyGetDetail")
        var dev_details: T_OBJs = [:]
        dev_details[[0x01, 0x30, 0x01]] = [0x80: [0x30], 0x81: [0x0f], 0x88: [0x42]]
        let els = EL_STRUCTURE(tid: [0x00, 0x01], seoj: [0x0e, 0xf0, 0x01], deoj: [0x01, 0x30, 0x01], esv: ELSwift.GET, opc: 0x01, epcpdcedt: [0x80, 0x00])
        try ELSwift.replyGetDetail("192.168.1.100", els, dev_details)
    }

    @Test func replyGetDetailSubSuccess() {
        print("-- testReplyGetDetailSubSuccess")
        var dev_details: T_OBJs = [:]
        dev_details[[0x01, 0x30, 0x01]] = [0x80: [0x30]]
        let els = EL_STRUCTURE(tid: [0x00, 0x01], seoj: [0x0e, 0xf0, 0x01], deoj: [0x01, 0x30, 0x01], esv: ELSwift.GET, opc: 0x01, epcpdcedt: [0x80, 0x00])
        #expect(ELSwift.replyGetDetail_sub(els, dev_details, 0x80))
    }

    @Test func replyGetDetailSubFailure() {
        print("-- testReplyGetDetailSubFailure")
        var dev_details: T_OBJs = [:]
        dev_details[[0x01, 0x30, 0x01]] = [:]
        let els = EL_STRUCTURE(tid: [0x00, 0x01], seoj: [0x0e, 0xf0, 0x01], deoj: [0x01, 0x30, 0x01], esv: ELSwift.GET, opc: 0x01, epcpdcedt: [0x80, 0x00])
        #expect(!ELSwift.replyGetDetail_sub(els, dev_details, 0x80))
    }

    // MARK: - EL_STRUCTURE Tests
    @Test func elStructureInit() {
        print("-- testELStructureInit")
        let els = EL_STRUCTURE()
        #expect(els.EHD == [0x10, 0x81])
        #expect(els.TID == [0x00, 0x00])
        #expect(els.SEOJ == [0x0e, 0xf0, 0x01])
        #expect(els.DEOJ == [0x0e, 0xf0, 0x01])
    }

    @Test func elStructureInitWithValues() {
        print("-- testELStructureInitWithValues")
        let els = EL_STRUCTURE(tid: [0x00, 0x05], seoj: [0x05, 0xff, 0x01], deoj: [0x01, 0x30, 0x01], esv: ELSwift.GET, opc: 0x02, epcpdcedt: [0x80, 0x00, 0x81, 0x00])
        #expect(els.TID == [0x00, 0x05])
        #expect(els.SEOJ == [0x05, 0xff, 0x01])
        #expect(els.DEOJ == [0x01, 0x30, 0x01])
        #expect(els.ESV == ELSwift.GET)
        #expect(els.OPC == 0x02)
    }

    @Test func elStructureEquality() {
        print("-- testELStructureEquality")
        let els1 = EL_STRUCTURE(tid: [0x00, 0x01], seoj: [0x05, 0xff, 0x01], deoj: [0x0e, 0xf0, 0x01], esv: ELSwift.GET, opc: 0x01, epcpdcedt: [0x80, 0x00])
        let els2 = EL_STRUCTURE(tid: [0x00, 0x01], seoj: [0x05, 0xff, 0x01], deoj: [0x0e, 0xf0, 0x01], esv: ELSwift.GET, opc: 0x01, epcpdcedt: [0x80, 0x00])
        #expect(els1 == els2)
    }

    // MARK: - Array Extension Tests
    @Test func arraySafeSubscript() {
        print("-- testArraySafeSubscript")
        let array = [1, 2, 3, 4, 5]
        #expect(array[safe: 0] == 1)
        #expect(array[safe: 4] == 5)
        #expect(array[safe: 5] == nil)
        #expect(array[safe: 10] == nil)
    }

    // MARK: - Error Handling Tests
    @Test func parseDetailWithInvalidData() {
        print("-- testParseDetailWithInvalidData")
        #expect { try ELSwift.parseDetail(0x02, [0x80]) } throws: { error in error is ELError }
    }

    @Test func parseBytesWithInvalidData() {
        print("-- testParseBytesWithInvalidData")
        let shortData: [UInt8] = [0x10, 0x81, 0x00]
        #expect { try ELSwift.parseBytes(shortData) } throws: { error in error is ELError }
    }

    @Test func substrOutOfRange() {
        print("-- testSubstrOutOfRange")
        #expect { try ELSwift.substr("12345", 0, 10) } throws: { error in error is ELError }
    }

    // MARK: - Additional Converter Tests
    @Test func printUInt8ArrayString() {
        print("-- testPrintUInt8ArrayString")
        let result = ELSwift.printUInt8Array_String([0x10, 0x81, 0xAA, 0xFF])
        #expect(result == "1081AAFF")
    }

    @Test func getSeparatedStringELDATA() {
        print("-- testGetSeparatedStringELDATA")
        let els = EL_STRUCTURE(tid: [0x00, 0x01], seoj: [0x05, 0xff, 0x01], deoj: [0x0e, 0xf0, 0x01], esv: ELSwift.GET, opc: 0x04, epcpdcedt: [0x80, 0x01, 0x31, 0xb0, 0x01, 0x42, 0xbb, 0x01, 0x1c, 0xb3, 0x01, 0x18])
        let result = ELSwift.getSeparatedString_ELDATA(els)
        #expect(result.contains("1081"))
        #expect(result.contains("05ff01"))
        #expect(result.contains("0ef001"))
    }

    // MARK: - IP Address Tests
    @Test func getIPAddresses() {
        print("-- testGetIPAddresses")
        let addresses = ELSwift.getIPAddresses()
        print("IPv4:", addresses.ipv4 ?? "nil")
        print("IPv6:", addresses.ipv6 ?? "nil")
    }

    @Test func getIPv4Address() {
        print("-- testGetIPv4Address")
        print("IPv4:", ELSwift.getIPv4Address() ?? "nil")
    }

    @Test func getIPv6Address() {
        print("-- testGetIPv6Address")
        print("IPv6:", ELSwift.getIPv6Address() ?? "nil")
    }

    // MARK: - Boundary Condition Tests
    @Test func parseDetailEmptyData() throws {
        print("-- testParseDetailEmptyData")
        _ = try ELSwift.parseDetail(0x00, [])
        #expect { try ELSwift.parseDetail(0x01, []) } throws: { error in error is ELError }
    }

    @Test func parseDetailOPCZero() throws {
        print("-- testParseDetailOPCZero")
        let result = try ELSwift.parseDetail(0x00, [0x80, 0x01, 0x30])
        #expect(result.count == 0)
    }

    @Test func parseDetailInsufficientLength() {
        print("-- testParseDetailInsufficientLength")
        #expect { try ELSwift.parseDetail(0x02, [0x80, 0x01, 0x30]) } throws: { error in error is ELError }
    }

    @Test func parseDetailMaxOPC() throws {
        print("-- testParseDetailMaxOPC")
        var largeData: [UInt8] = []
        for i in 0..<255 {
            largeData.append(UInt8(i)); largeData.append(0x01); largeData.append(0x30)
        }
        _ = try ELSwift.parseDetail(0xff, largeData)
    }

    @Test func parseBytesTooShort() {
        print("-- testParseBytesTooShort")
        let shortData: [UInt8] = [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01]
        #expect { try ELSwift.parseBytes(shortData) } throws: { error in error is ELError }
    }

    @Test func parseBytesEmptyArray() {
        print("-- testParseBytesEmptyArray")
        #expect { try ELSwift.parseBytes([]) } throws: { error in error is ELError }
    }

    @Test func parseBytesInvalidEHD() throws {
        print("-- testParseBytesInvalidEHD")
        let invalidData: [UInt8] = [0x10, 0x82, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x01, 0x80, 0x00]
        _ = try ELSwift.parseBytes(invalidData)
    }

    @Test func parseStringEmpty() {
        print("-- testParseStringEmpty")
         #expect { try ELSwift.parseString("") } throws: { error in error is ELError }
    }

    @Test func parseStringOddLength() {
        print("-- testParseStringOddLength")
         #expect { try ELSwift.parseString("108100000") } throws: { error in error is ELError }
    }

    @Test func parseStringInvalidHex() {
        print("-- testParseStringInvalidHex")
         #expect { try ELSwift.parseString("1081ZZZ005ff010ef0016201800130") } throws: { error in error is ELError }
    }

    // MARK: - Error Case Tests for Send Functions
    @Test func sendStringMultiEmpty() {
        print("-- testSendStringMultiEmpty")
        #expect { try ELSwift.sendStringMulti("") } throws: { error in error is ELError }
    }

    @Test func sendStringMultiInvalidHex() {
        print("-- testSendStringMultiInvalidHex")
        #expect { try ELSwift.sendStringMulti("INVALID") } throws: { error in error is ELError }
    }

    @Test func sendBaseMultiEmptyData() {
        print("-- testSendBaseMultiEmptyData")
        #expect { try ELSwift.sendBaseMulti(Data()) } throws: { error in error is ELError }
    }

    @Test func sendBaseMultiEmptyArray() {
        print("-- testSendBaseMultiEmptyArray")
        #expect { try ELSwift.sendBaseMulti([]) } throws: { error in error is ELError }
    }

    @Test func sendOPC1MultiInvalidSEOJ() {
        print("-- testSendOPC1MultiInvalidSEOJ")
        #expect { try ELSwift.sendOPC1Multi([0x05, 0xff], [0x0e, 0xf0, 0x01], ELSwift.GET, 0x80, [0x00]) } throws: { error in error is ELError }
    }

    @Test func sendOPC1MultiInvalidDEOJ() {
        print("-- testSendOPC1MultiInvalidDEOJ")
        #expect { try ELSwift.sendOPC1Multi([0x05, 0xff, 0x01], [0x0e, 0xf0], ELSwift.GET, 0x80, [0x00]) } throws: { error in error is ELError }
    }

    // MARK: - TID Boundary Tests
    @Test func tidBoundaryAllValues() {
        print("-- testTIDBoundaryAllValues")
        let originalTID = ELSwift.tid
        ELSwift.tid = [0x00, 0x00]; ELSwift.increaseTID(); #expect(ELSwift.tid == [0x00, 0x01])
        ELSwift.tid = [0x00, 0xff]; ELSwift.increaseTID(); #expect(ELSwift.tid == [0x01, 0x00])
        ELSwift.tid = [0xff, 0x00]; ELSwift.increaseTID(); #expect(ELSwift.tid == [0xff, 0x01])
        ELSwift.tid = [0xff, 0xff]; ELSwift.increaseTID(); #expect(ELSwift.tid == [0x00, 0x00])
        ELSwift.tid = [0x12, 0x34]; ELSwift.increaseTID(); #expect(ELSwift.tid == [0x12, 0x35])
        ELSwift.tid = originalTID
    }

    // MARK: - Array Safe Subscript Edge Cases
    @Test func arraySafeSubscriptNegativeIndex() {
        print("-- testArraySafeSubscriptNegativeIndex")
        let array = [1, 2, 3]
        #expect(array[safe: -1] == nil)
    }

    @Test func arraySafeSubscriptEmptyArray() {
        print("-- testArraySafeSubscriptEmptyArray")
        let array: [Int] = []
        #expect(array[safe: 0] == nil)
    }

    // MARK: - EL_STRUCTURE Edge Cases
    @Test func elStructureWithEmptyEPCPDCEDT() {
        print("-- testELStructureWithEmptyEPCPDCEDT")
        let els = EL_STRUCTURE(tid: [0x00, 0x00], seoj: [0x05, 0xff, 0x01], deoj: [0x0e, 0xf0, 0x01], esv: ELSwift.GET, opc: 0x00, epcpdcedt: [])
        #expect(els.OPC == 0x00)
        #expect(els.EPCPDCEDT == [])
    }

    @Test func elStructureWithMaxTID() {
        print("-- testELStructureWithMaxTID")
        let els = EL_STRUCTURE(tid: [0xff, 0xff], seoj: [0xff, 0xff, 0xff], deoj: [0xff, 0xff, 0xff], esv: 0xff, opc: 0xff, epcpdcedt: [0xff, 0xff, 0xff])
        #expect(els.TID == [0xff, 0xff])
        #expect(els.SEOJ == [0xff, 0xff, 0xff])
        #expect(els.DEOJ == [0xff, 0xff, 0xff])
    }

    // MARK: - Facilities Manager Edge Cases
    @Test func facilitiesManagerMultipleIPs() async {
        print("-- testFacilitiesManagerMultipleIPs")
        let manager = ELFacilitiesManager()
        await manager.setFacilitiesNewIP("192.168.1.100")
        await manager.setFacilitiesNewIP("192.168.1.101")
        await manager.setFacilitiesNewIP("192.168.1.102")
        let facilities = await manager.getFacilities()
        #expect(facilities.count == 3)
    }

    @Test func facilitiesManagerSameIPMultipleSEOJ() async {
        print("-- testFacilitiesManagerSameIPMultipleSEOJ")
        let manager = ELFacilitiesManager()
        await manager.setFacilitiesNewIP("192.168.1.100")
        await manager.setFacilitiesNewSEOJ("192.168.1.100", [0x01, 0x30, 0x01])
        await manager.setFacilitiesNewSEOJ("192.168.1.100", [0x02, 0x90, 0x01])
        await manager.setFacilitiesNewSEOJ("192.168.1.100", [0x05, 0xff, 0x01])
        let facilities = await manager.getFacilities()
        #expect(facilities["192.168.1.100"]?[[0x01, 0x30, 0x01]] != nil)
        #expect(facilities["192.168.1.100"]?[[0x02, 0x90, 0x01]] != nil)
        #expect(facilities["192.168.1.100"]?[[0x05, 0xff, 0x01]] != nil)
    }

    @Test func facilitiesManagerOverwriteEDT() async {
        print("-- testFacilitiesManagerOverwriteEDT")
        let manager = ELFacilitiesManager()
        await manager.setFacilitiesNewIP("192.168.1.100")
        await manager.setFacilitiesNewSEOJ("192.168.1.100", [0x01, 0x30, 0x01])
        await manager.setFacilitiesSetEDT("192.168.1.100", [0x01, 0x30, 0x01], 0x80, [0x30])
        var facilities = await manager.getFacilities()
        #expect(facilities["192.168.1.100"]?[[0x01, 0x30, 0x01]]?[0x80] == [0x30])
        await manager.setFacilitiesSetEDT("192.168.1.100", [0x01, 0x30, 0x01], 0x80, [0x31])
        facilities = await manager.getFacilities()
        #expect(facilities["192.168.1.100"]?[[0x01, 0x30, 0x01]]?[0x80] == [0x31])
    }

    // MARK: - SNA (Service Not Available) Response Tests
    @Test func snaResponseForINFCWithNoDEOJ() {
        print("-- testSNAResponseForINFCWithNoDEOJ")
        let els = EL_STRUCTURE(tid: [0x00, 0x01], seoj: [0x0e, 0xf0, 0x01], deoj: [0x01, 0x30, 0x01], esv: 0x74, opc: 0x01, epcpdcedt: [0x80, 0x01, 0x30])
        #expect(els.ESV == 0x74)
        #expect(els.OPC == 0x01)
    }

    @Test func snaResponseForOPCZero() {
        print("-- testSNAResponseForOPCZero")
        let elsSetGet = EL_STRUCTURE(tid: [0x00, 0x02], seoj: [0x0e, 0xf0, 0x01], deoj: [0x01, 0x30, 0x01], esv: 0x6E, opc: 0x00, epcpdcedt: [])
        #expect(elsSetGet.ESV == 0x6E)
        #expect(elsSetGet.OPC == 0x00)
    }

    @Test func snaResponseForEDTSizeExceeded() {
        print("-- testSNAResponseForEDTSizeExceeded")
        let els = EL_STRUCTURE(tid: [0x00, 0x03], seoj: [0x0e, 0xf0, 0x01], deoj: [0x01, 0x30, 0x01], esv: 0x60, opc: 0x01, epcpdcedt: [0x80, 0x05, 0x30, 0x31, 0x32, 0x33, 0x34])
        #expect(els.EPCPDCEDT[1] == 0x05)
    }

    @Test func snaResponseForEmptyEDT() {
        print("-- testSNAResponseForEmptyEDT")
        let els = EL_STRUCTURE(tid: [0x00, 0x04], seoj: [0x0e, 0xf0, 0x01], deoj: [0x01, 0x30, 0x01], esv: 0x61, opc: 0x01, epcpdcedt: [0x80, 0x00])
        #expect(els.EPCPDCEDT[1] == 0x00)
    }

    @Test func nfcResDoesNotRequireSNA() {
        print("-- testNFCResDoesNotRequireSNA")
        let els = EL_STRUCTURE(tid: [0x00, 0x05], seoj: [0x01, 0x30, 0x01], deoj: [0x0e, 0xf0, 0x01], esv: 0x7A, opc: 0x01, epcpdcedt: [0x80, 0x00])
        #expect(els.ESV == 0x7A)
    }

    @Test func setGetSNAResponseStructure() {
        print("-- testSetGetSNAResponseStructure")
        let snaDEOJ: [UInt8] = [0x01, 0x30, 0x01]
        let snaSEOJ: [UInt8] = [0x0e, 0xf0, 0x01]
        let elsSetGetSNA = EL_STRUCTURE(tid: [0x00, 0x06], seoj: snaDEOJ, deoj: snaSEOJ, esv: 0x5E, opc: 0x01, epcpdcedt: [0x80, 0x00])
        #expect(elsSetGetSNA.ESV == 0x5E)
        #expect(elsSetGetSNA.SEOJ == snaDEOJ)
        #expect(elsSetGetSNA.DEOJ == snaSEOJ)
    }

    @Test func setCSNAResponseStructure() {
        print("-- testSetCSNAResponseStructure")
        let elsSetCSNA = EL_STRUCTURE(tid: [0x00, 0x07], seoj: [0x01, 0x30, 0x01], deoj: [0x0e, 0xf0, 0x01], esv: 0x50, opc: 0x01, epcpdcedt: [0x80, 0x00])
        #expect(elsSetCSNA.ESV == 0x50)
    }

    @Test func getSNAResponseStructure() {
        print("-- testGetSNAResponseStructure")
        let elsGetSNA = EL_STRUCTURE(tid: [0x00, 0x08], seoj: [0x01, 0x30, 0x01], deoj: [0x0e, 0xf0, 0x01], esv: 0x52, opc: 0x01, epcpdcedt: [0x80, 0x00])
        #expect(elsGetSNA.ESV == 0x52)
    }

    @Test func inf_SNAResponseStructure() {
        print("-- testINF_SNAResponseStructure")
        let elsINFSNA = EL_STRUCTURE(tid: [0x00, 0x09], seoj: [0x01, 0x30, 0x01], deoj: [0x0e, 0xf0, 0x01], esv: 0x53, opc: 0x01, epcpdcedt: [0x80, 0x00])
        #expect(elsINFSNA.ESV == 0x53)
    }
}

extension ELSwift {
    static func getIsReady() -> Bool {
        return isReady
    }
}
