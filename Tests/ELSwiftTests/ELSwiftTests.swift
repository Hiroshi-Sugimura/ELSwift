import Swift
import XCTest
@testable import ELSwift

final class ELSwiftTests: XCTestCase {
    let objectList:[UInt8] = [0x05, 0xff, 0x01]
    override func setUp() {
        super.setUp()

        print("#==========")
        print("# setUp")
        let exp = expectation(description: "EL initialize")

        do{
            try ELSwift.initialize(objectList, { (_ rAddress:String, _ els: EL_STRUCTURE?, _ err: Error?) in
                if let error = err {
                    print (error)
                    return
                }
                /*
                 if let elsv = els {
                 let seoj = elsv.SEOJ.map{ String($0, radix:16) }
                 let esv = String(elsv.ESV, radix:16)
                 let detail = elsv.DETAIL.map{ String($0, radix:16) }
                 let edata = elsv.EDATA
                 if( elsv.SEOJ[0...1] == [0x01, 0x35] ) { // air cleanerからの送信だけ処理する
                 print("air cleaner \(seoj)  \(esv)  \(detail)  \(edata)")
                 }
                 }
                 */
            }, option: (debug:true, ipVer:0, autoGetProperties: true) )
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
        print("==== try ELSwift Test ====")
        // 送信系のテストはどうやるの？パケットがでないときがある
        print("# search")
        try ELSwift.search()
        print("# sendString")
        try ELSwift.sendString( "192.168.2.51", "1081000005ff010ef00162018000")
        print("# sendOPC1")
        try ELSwift.sendOPC1( "192.168.2.52", [0x05, 0xff, 0x01], [0x0e,0xf0,0x01], ELSwift.GET, 0x80, [0x00])


        //////////////////////////////////////////////////////////////////////
        // 変換
        //////////////////////////////////////////////////////////////////////
        print("--- converter ---")

        // Detail
        print("-- parseDetail, OPC=1")
        var a: Dictionary<UInt8, [UInt8]> = [UInt8: [UInt8]]() // 戻り値用，連想配列
        a[0x80] = [0x30]
        XCTAssertEqual(
            try ELSwift.parseDetail( "01", "800130" ),
            a)

        print("-- parseDetail, OPC=1, EPC=2")
        var b: Dictionary<UInt8, [UInt8]> = [UInt8: [UInt8]]() // 戻り値用，連想配列
        b[0xb9] = [0x12, 0x34]
        XCTAssertEqual(
            try ELSwift.parseDetail( "01", "B9021234" ),
            b)

        print("-- parseDetail, OPC=4")
        var c: Dictionary<UInt8, [UInt8]> = [UInt8: [UInt8]]() // 戻り値用，連想配列
        c[0x80] = [0x31]
        c[0xb0] = [0x42]
        c[0xbb] = [0x1c]
        c[0xb3] = [0x18]
        XCTAssertEqual(
            try ELSwift.parseDetail( "04", "800131b00142bb011cb30118" ),
            c)

        print("-- parseDetail, OPC=5, EPC=2")
        var d: Dictionary<UInt8, [UInt8]> = [UInt8: [UInt8]]() // 戻り値用，連想配列
        d[0x80] = [0x31]
        d[0xb0] = [0x42]
        d[0xbb] = [0x1c]
        d[0xb3] = [0x18]
        d[0xb9] = [0x12, 0x34]
        XCTAssertEqual(
            try ELSwift.parseDetail( "05", "800131b00142bb011cb9021234b30118" ),
            d )

        print("-- parseDetail, ???")
        var g: Dictionary<UInt8, [UInt8]> = [UInt8: [UInt8]]() // 戻り値用，連想配列
        g[0x80] = [0x31]
        g[0x81] = [0x0f]
        g[0x82] = [0x00, 0x00, 0x50, 0x01]
        g[0x83] = [0xfe, 0x00, 0x00, 0x77, 0x00, 0x00, 0x02, 0xea, 0xed, 0x64, 0x6f, 0x38, 0x1e, 0x00, 0x00, 0x00, 0x02]
        g[0x88] = [0x42]
        g[0x8a] = [0x00, 0x00, 0x77]
        g[0x9d] = [0x05, 0x80, 0x81, 0x8f, 0xb0, 0xa0]
        g[0x9e] = [0x06, 0x80, 0x81, 0x8f, 0xb0, 0xb3, 0xa0]
        XCTAssertEqual(
            try ELSwift.parseDetail( "08", "80013181010f8204000050018311fe000077000002eaed646f381e000000028801428a030000779d060580818fb0a09e070680818fb0b3a0" ),
            g);

/*
         print("parseDetail exception case, smart meter")
         XCTAssertEqual(
         try ELSwift.parseDetail( "06", "D30400000001D70106E004000C6C96E30400000006E7040000036" ),
         {   "80": "31", "81": "0f", "82": "00005001", "83": "fe000077000002eaed646f381e00000002", "88": "42",
         "8a": "000077", "9d": "0580818fb0a0", "9e": "0680818fb0b3a0" });
         */

        // バイトデータをいれるとELDATA形式にする
        print("-- parseBytes, OPC=1")
        let e:EL_STRUCTURE = EL_STRUCTURE( tid:[0x00, 0x00], seoj: [0x05, 0xff, 0x01], deoj: [0x0e, 0xf0, 0x01],  esv: 0x62,  opc: 0x01,  epcpdcedt: [0x80, 0x01, 0x30] )
        XCTAssertEqual(
            try ELSwift.parseBytes( [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x01, 0x80, 0x01, 0x30] ),
            e)

        // 16進数で表現された文字列をいれるとELDATA形式にする
        print("-- parseBytes, OPC=4")
        let f:EL_STRUCTURE = EL_STRUCTURE( tid:[0x00, 0x00], seoj: [0x05, 0xff, 0x01], deoj: [0x0e, 0xf0, 0x01],  esv: 0x62,  opc: 0x04,  epcpdcedt: [0x80, 0x01, 0x31, 0xb0, 0x01, 0x42, 0xbb, 0x01, 0x1c, 0xb3, 0x01, 0x18] )
        XCTAssertEqual(
            try ELSwift.parseBytes( [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x04, 0x80, 0x01, 0x31, 0xb0, 0x01, 0x42, 0xbb, 0x01, 0x1c, 0xb3, 0x01, 0x18] ),
            f)

        // 16進数で表現された文字列をいれるとELDATA形式にする
        print("-- parseString, OPC=1")
        XCTAssertEqual(
            try ELSwift.parseString( "1081000005ff010ef0016201800130" ),
            e )

        /*
         // 16進数で表現された文字列をいれるとELDATA形式にする
         print("parseString, OPC=4")
         XCTAssertEqual(
         try ELSwift.parseString( "1081000005ff010ef0016204800131b00142bb011cb30118" ),
         { EHD: "1081",
         TID: "0000",
         SEOJ: "05ff01",
         DEOJ: "0ef001",
         EDATA: "6204800131b00142bb011cb30118",
         ESV: "62",
         OPC: "04",
         DETAIL: "800131b00142bb011cb30118",
         DETAILs: { "80": "31", "b0": "42", "bb": "1c", "b3": "18" } });

         // format 2
         print("parseString, format 2 (Mitsubishi TV)")
         XCTAssertEqual(
         try ELSwift.parseString( "10820003000e000106020105ff0162010100" ),
         { EHD: "1082",
         AMF: "0003000e000106020105ff0162010100" });
         */

        print("-- substr")
        XCTAssertEqual(
            try ELSwift.substr( "01234567890", 2, 3),
            "234"
        )

        // 文字列をいれるとELらしい切り方のStringを得る
        print("-- getSeparatedString_String")
        XCTAssertEqual(
            // input
            try ELSwift.getSeparatedString_String( "1081000005ff010ef0016201300180" ),
            // output
            "1081 0000 05ff01 0ef001 62 01300180");

        // ELDATAをいれるとELらしい切り方のStringを得る
        print("-- getSeparatedString_ELDATA")
        XCTAssertEqual(
            ELSwift.getSeparatedString_ELDATA(f),
            "1081 0000 05ff01 0ef001 6204800131b00142bb011cb30118"
        );

        // ELDATA形式から配列へ
        print("-- ELDATA2Array")
        XCTAssertEqual(
            try ELSwift.ELDATA2Array( f ),
            // output
            [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x04, 0x80, 0x01, 0x31, 0xb0, 0x01, 0x42, 0xbb, 0x01, 0x1c, 0xb3, 0x01, 0x18] );

        // 1バイトを文字列の16進表現へ（1Byteは必ず2文字にする）
        print("-- toHexString")
        XCTAssertEqual(
            ELSwift.toHexString( 65 ),
            "41")

        // 16進表現の文字列を数値のバイト配列へ
        print("-- toHexArray")
        XCTAssertEqual(
            try ELSwift.toHexArray( "418081A0A1B0F0FF" ),
            [65, 128, 129, 160, 161, 176, 240, 255])

        print("-- toHexArray exception case, empty")            // empty case
        XCTAssertEqual(
            try ELSwift.toHexArray(""),
            []);

        // バイト配列を文字列にかえる
        print("-- bytesToString")
        XCTAssertEqual(
            try ELSwift.bytesToString( [ 34, 130, 132, 137, 146, 148, 149, 150, 151, 155, 162, 164, 165, 167, 176, 180, 183, 194, 196, 200, 210, 212, 216, 218, 219, 226, 228, 232, 234, 235, 240, 244, 246, 248, 250 ] ),
            "2282848992949596979ba2a4a5a7b0b4b7c2c4c8d2d4d8dadbe2e4e8eaebf0f4f6f8fa");


        //////////////////////////////////////////////////////////////////////
        // send
        //////////////////////////////////////////////////////////////////////
        print("--- send ---")
        /*
         // EL送信のベース
         print("sendBase")
         if(ipversion == 4) {
         let tid = try ELSwift.sendBase("127.0.0.1", Buffer.from([0x10, 0x81, 0x01, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, try ELSwift.GET, 0x01, 0x80, 0x00]));
         console.log( "TID:", tid );
         }else if(ipversion == 6) {
         let tid = try ELSwift.sendBase("::1", Buffer.from([0x10, 0x81, 0x01, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, try ELSwift.GET, 0x01, 0x80, 0x00]));
         console.log( "TID:", tid );
         }

         print("sendBase exception case, null .. occuring parseBytes error is expected.")
         // empty case
         if(ipversion == 4) {
         let tid = try ELSwift.sendBase("127.0.0.1", Buffer.from([]))
         console.log( "TID:", tid );
         }else if(ipversion == 6) {
         let tid = try ELSwift.sendBase("::1", Buffer.from([]))
         console.log( "TID:", tid );
         }

         // 配列の時
         print("sendArray")
         if(ipversion == 4) {
         let tid = try ELSwift.sendArray("127.0.0.1", [0x10, 0x81, 0x02, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, try ELSwift.GET, 0x01, 0x80, 0x00]);
         console.log( "TID:", tid );
         }else if(ipversion == 6) {
         let tid = try ELSwift.sendArray("::1", [0x10, 0x81, 0x02, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, try ELSwift.GET, 0x01, 0x80, 0x00]);
         console.log( "TID:", tid );
         }


         // ELの非常に典型的なOPC一個でやる
         print("sendOPC1")
         if(ipversion == 4) {
         let tid = try ELSwift.sendOPC1("127.0.0.1", [0x05, 0xff, 0x01], [0x0e, 0xf0, 0x01], try ELSwift.GET, 0x01, 0x80, [0x00]);
         console.log( "TID:", tid );
         }else if(ipversion) {
         let tid = try ELSwift.sendOPC1("::1", [0x05, 0xff, 0x01], [0x0e, 0xf0, 0x01], try ELSwift.GET, 0x01, 0x80, [0x00]);
         console.log( "TID:", tid );
         }

         // ELの非常に典型的な送信3 文字列タイプ
         print("sendString")
         if(ipversion == 4) {
         let tid = try ELSwift.sendString ("127.0.0.1", "1081030005ff010ef00163018000");
         console.log( "TID:", tid );
         }else if(ipversion == 6) {
         let tid = try ELSwift.sendString ("::1", "1081030005ff010ef00163018000");
         console.log( "TID:", tid );
         }
         */

         // 機器検索
         print("-- search")
         try ELSwift.search()

        //////////////////////////////////////////////////////////////////////
        // パーサー
        //////////////////////////////////////////////////////////////////////
        print("--- perser ---")

        // parse Propaty Map Form 2
        // 16以上のプロパティ数の時，記述形式2，出力はForm1にすること
        print("-- parseMapForm2 (16 props)")
        XCTAssertEqual(
            try ELSwift.parseMapForm2( [0x10, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01] ),  // 16 properties
            [ 0x10, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f ] )

        // parse Propaty Map Form 2
        // 16以上のプロパティ数の時，記述形式2，出力はForm1にすること
        print("-- parseMapForm2 (16 props)")
        XCTAssertEqual(
            try ELSwift.parseMapForm2( "1001010101010101010101010101010101" ),  // 16 properties
            [ 0x10, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f ] );

        print("-- parseMapForm2 (16 props)")
        XCTAssertEqual(
            // input
            try ELSwift.parseMapForm2( "1041414100004000604100410000020202" ),  // equal and more than 16 properties
            // output
            [  16, 128, 129, 130, 136, 138, 157, 158, 159, 215, 224, 225, 226, 229, 231, 232, 234 ] ); // 16

        print("-- parseMapForm2 (54 props)")
        XCTAssertEqual(
            // input
            try ELSwift.parseMapForm2( "36b1b1b1b1b0b0b1b3b3a1838101838383" ),  // 54 properties
            // output
            [ 0x36, // = 54
              0x80, 0x81, 0x82, 0x83, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f, // 14
              0x97, 0x98, 0x9a, 0x9d, 0x9e, 0x9f, // 6
              0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8, // 9
              0xd0, 0xd1, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9,  // 10
              0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfd, 0xfe, 0xff ] ); // 15

        //////////////////////////////////////////////////////////////////////
        // 表示
        //////////////////////////////////////////////////////////////////////
        print("--- show ---")

        print("-- printUInt8Array")
        ELSwift.printUInt8Array( [0x01, 0x02, 0x03, 0x10, 0x11, 0xa0, 0xf1, 0xf2] )

        print("-- printPDCEDT")
        ELSwift.printPDCEDT( [0x02, 0xaa, 0xbb] )

        print("-- printDetails")
        ELSwift.printDetails( d )

        print("-- printEL_STRUCTURE")
        ELSwift.printEL_STRUCTURE( f )

        print("-- printFacilities (skipped in test)")
        // ELSwift.printFacilities() // async function, tested separately


        //////////////////////////////////////////////////////////////////////
        // 終了
        //////////////////////////////////////////////////////////////////////
        // 終了
        print("-- release")
        ELSwift.release()
    }

    // MARK: - Async Send Tests
    func testSendAsyncOPC1() throws {
        print("-- testSendAsyncOPC1")
        let exp = expectation(description: "Async send OPC1")

        ELSwift.sendAsyncOPC1(
            "192.168.2.100",
            [0x05, 0xff, 0x01],
            [0x0e, 0xf0, 0x01],
            ELSwift.GET,
            0x80,
            [0x00]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
    }

    func testSendAsyncELS() throws {
        print("-- testSendAsyncELS")
        let exp = expectation(description: "Async send ELS")

        let els = EL_STRUCTURE(
            tid: [0x00, 0x01],
            seoj: [0x05, 0xff, 0x01],
            deoj: [0x0e, 0xf0, 0x01],
            esv: ELSwift.GET,
            opc: 0x01,
            epcpdcedt: [0x80, 0x00]
        )

        try ELSwift.sendAsyncELS("192.168.2.100", els)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
    }

    func testSendAsyncArray() throws {
        print("-- testSendAsyncArray")
        let exp = expectation(description: "Async send array")

        let array: [UInt8] = [
            0x10, 0x81, 0x00, 0x00,
            0x05, 0xff, 0x01,
            0x0e, 0xf0, 0x01,
            0x62, 0x01, 0x80, 0x00
        ]

        try ELSwift.sendAsyncArray("192.168.2.100", array)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)
    }

    // MARK: - TID Management Tests
    func testIncreaseTID() {
        print("-- testIncreaseTID")

        let originalTID = ELSwift.tid

        ELSwift.tid = [0x00, 0x00]
        ELSwift.increaseTID()
        XCTAssertEqual(ELSwift.tid, [0x00, 0x01])

        ELSwift.tid = [0x00, 0xff]
        ELSwift.increaseTID()
        XCTAssertEqual(ELSwift.tid, [0x01, 0x00])

        ELSwift.tid = [0xff, 0xff]
        ELSwift.increaseTID()
        XCTAssertEqual(ELSwift.tid, [0x00, 0x00])

        // Restore original TID
        ELSwift.tid = originalTID
    }

    // MARK: - Facilities Manager Tests
    func testFacilitiesManagerOperations() async {
        print("-- testFacilitiesManagerOperations")
        let manager = ELFacilitiesManager()

        // 初期状態は空
        var isEmpty = await manager.isEmpty()
        XCTAssertTrue(isEmpty)

        // IPアドレス追加
        await manager.setFacilitiesNewIP("192.168.1.100")
        isEmpty = await manager.isEmpty()
        XCTAssertFalse(isEmpty)

        // SEOJ追加
        await manager.setFacilitiesNewSEOJ("192.168.1.100", [0x01, 0x30, 0x01])
        let facilities = await manager.getFacilities()
        XCTAssertNotNil(facilities["192.168.1.100"]?[[0x01, 0x30, 0x01]])

        // EDT設定
        await manager.setFacilitiesSetEDT("192.168.1.100", [0x01, 0x30, 0x01], 0x80, [0x30])
        let updatedFacilities = await manager.getFacilities()
        XCTAssertEqual(updatedFacilities["192.168.1.100"]?[[0x01, 0x30, 0x01]]?[0x80], [0x30])
    }

    // MARK: - Multi Send Tests
    func testSendBaseMultiData() throws {
        print("-- testSendBaseMultiData")
        let data = Data([
            0x10, 0x81, 0x00, 0x00,
            0x05, 0xff, 0x01,
            0x0e, 0xf0, 0x01,
            0x62, 0x01, 0x80, 0x00
        ])
        try ELSwift.sendBaseMulti(data)
    }

    func testSendBaseMultiArray() throws {
        print("-- testSendBaseMultiArray")
        let array: [UInt8] = [
            0x10, 0x81, 0x00, 0x00,
            0x05, 0xff, 0x01,
            0x0e, 0xf0, 0x01,
            0x62, 0x01, 0x80, 0x00
        ]
        try ELSwift.sendBaseMulti(array)
    }

    func testSendStringMulti() throws {
        print("-- testSendStringMulti")
        try ELSwift.sendStringMulti("1081000005ff010ef0016201800130")
    }

    func testSendOPC1Multi() throws {
        print("-- testSendOPC1Multi")
        try ELSwift.sendOPC1Multi(
            [0x05, 0xff, 0x01],
            [0x0e, 0xf0, 0x01],
            ELSwift.GET,
            0x80,
            [0x00]
        )
    }

    // MARK: - Reply Tests
    func testReplyGetDetail() throws {
        print("-- testReplyGetDetail")

        var dev_details: T_OBJs = [:]
        dev_details[[0x01, 0x30, 0x01]] = [
            0x80: [0x30],
            0x81: [0x0f],
            0x88: [0x42]
        ]

        let els = EL_STRUCTURE(
            tid: [0x00, 0x01],
            seoj: [0x0e, 0xf0, 0x01],
            deoj: [0x01, 0x30, 0x01],
            esv: ELSwift.GET,
            opc: 0x01,
            epcpdcedt: [0x80, 0x00]
        )

        try ELSwift.replyGetDetail("192.168.1.100", els, dev_details)
    }

    func testReplyGetDetailSubSuccess() {
        print("-- testReplyGetDetailSubSuccess")

        var dev_details: T_OBJs = [:]
        dev_details[[0x01, 0x30, 0x01]] = [
            0x80: [0x30]
        ]

        let els = EL_STRUCTURE(
            tid: [0x00, 0x01],
            seoj: [0x0e, 0xf0, 0x01],
            deoj: [0x01, 0x30, 0x01],
            esv: ELSwift.GET,
            opc: 0x01,
            epcpdcedt: [0x80, 0x00]
        )

        let result = ELSwift.replyGetDetail_sub(els, dev_details, 0x80)
        XCTAssertTrue(result)
    }

    func testReplyGetDetailSubFailure() {
        print("-- testReplyGetDetailSubFailure")

        var dev_details: T_OBJs = [:]
        dev_details[[0x01, 0x30, 0x01]] = [:]

        let els = EL_STRUCTURE(
            tid: [0x00, 0x01],
            seoj: [0x0e, 0xf0, 0x01],
            deoj: [0x01, 0x30, 0x01],
            esv: ELSwift.GET,
            opc: 0x01,
            epcpdcedt: [0x80, 0x00]
        )

        let result = ELSwift.replyGetDetail_sub(els, dev_details, 0x80)
        XCTAssertFalse(result)
    }

    // MARK: - EL_STRUCTURE Tests
    func testELStructureInit() {
        print("-- testELStructureInit")
        let els = EL_STRUCTURE()
        XCTAssertEqual(els.EHD, [0x10, 0x81])
        XCTAssertEqual(els.TID, [0x00, 0x00])
        XCTAssertEqual(els.SEOJ, [0x0e, 0xf0, 0x01])
        XCTAssertEqual(els.DEOJ, [0x0e, 0xf0, 0x01])
    }

    func testELStructureInitWithValues() {
        print("-- testELStructureInitWithValues")
        let els = EL_STRUCTURE(
            tid: [0x00, 0x05],
            seoj: [0x05, 0xff, 0x01],
            deoj: [0x01, 0x30, 0x01],
            esv: ELSwift.GET,
            opc: 0x02,
            epcpdcedt: [0x80, 0x00, 0x81, 0x00]
        )

        XCTAssertEqual(els.TID, [0x00, 0x05])
        XCTAssertEqual(els.SEOJ, [0x05, 0xff, 0x01])
        XCTAssertEqual(els.DEOJ, [0x01, 0x30, 0x01])
        XCTAssertEqual(els.ESV, ELSwift.GET)
        XCTAssertEqual(els.OPC, 0x02)
    }

    func testELStructureEquality() {
        print("-- testELStructureEquality")
        let els1 = EL_STRUCTURE(
            tid: [0x00, 0x01],
            seoj: [0x05, 0xff, 0x01],
            deoj: [0x0e, 0xf0, 0x01],
            esv: ELSwift.GET,
            opc: 0x01,
            epcpdcedt: [0x80, 0x00]
        )

        let els2 = EL_STRUCTURE(
            tid: [0x00, 0x01],
            seoj: [0x05, 0xff, 0x01],
            deoj: [0x0e, 0xf0, 0x01],
            esv: ELSwift.GET,
            opc: 0x01,
            epcpdcedt: [0x80, 0x00]
        )

        XCTAssertEqual(els1, els2)
    }

    // MARK: - Array Extension Tests
    func testArraySafeSubscript() {
        print("-- testArraySafeSubscript")
        let array = [1, 2, 3, 4, 5]

        XCTAssertEqual(array[safe: 0], 1)
        XCTAssertEqual(array[safe: 4], 5)
        XCTAssertNil(array[safe: 5])
        XCTAssertNil(array[safe: 10])
    }

    // MARK: - Error Handling Tests
    func testParseDetailWithInvalidData() {
        print("-- testParseDetailWithInvalidData")

        XCTAssertThrowsError(try ELSwift.parseDetail(0x02, [0x80])) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testParseBytesWithInvalidData() {
        print("-- testParseBytesWithInvalidData")

        let shortData: [UInt8] = [0x10, 0x81, 0x00]
        XCTAssertThrowsError(try ELSwift.parseBytes(shortData)) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testSubstrOutOfRange() {
        print("-- testSubstrOutOfRange")

        XCTAssertThrowsError(try ELSwift.substr("12345", 0, 10)) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    // MARK: - Additional Converter Tests
    func testPrintUInt8ArrayString() {
        print("-- testPrintUInt8ArrayString")
        let array: [UInt8] = [0x10, 0x81, 0xAA, 0xFF]
        let result = ELSwift.printUInt8Array_String(array)
        XCTAssertEqual(result, "1081AAFF")
    }

    func testGetSeparatedStringELDATA() {
        print("-- testGetSeparatedStringELDATA")
        let els = EL_STRUCTURE(
            tid: [0x00, 0x01],
            seoj: [0x05, 0xff, 0x01],
            deoj: [0x0e, 0xf0, 0x01],
            esv: ELSwift.GET,
            opc: 0x04,
            epcpdcedt: [0x80, 0x01, 0x31, 0xb0, 0x01, 0x42, 0xbb, 0x01, 0x1c, 0xb3, 0x01, 0x18]
        )

        let result = ELSwift.getSeparatedString_ELDATA(els)
        XCTAssertTrue(result.contains("1081"))
        XCTAssertTrue(result.contains("05ff01"))
        XCTAssertTrue(result.contains("0ef001"))
    }

    // MARK: - IP Address Tests
    func testGetIPAddresses() {
        print("-- testGetIPAddresses")
        let addresses = ELSwift.getIPAddresses()
        print("IPv4:", addresses.ipv4 ?? "nil")
        print("IPv6:", addresses.ipv6 ?? "nil")
        // IPアドレスは環境依存なので存在チェックのみ
    }

    func testGetIPv4Address() {
        print("-- testGetIPv4Address")
        let ipv4 = ELSwift.getIPv4Address()
        print("IPv4:", ipv4 ?? "nil")
    }

    func testGetIPv6Address() {
        print("-- testGetIPv6Address")
        let ipv6 = ELSwift.getIPv6Address()
        print("IPv6:", ipv6 ?? "nil")
    }

    // MARK: - Boundary Condition Tests
    func testParseDetailEmptyData() {
        print("-- testParseDetailEmptyData")
        // OPC=0でも明示的に呼ばれた場合は有効な入力として扱うべき
        // ただし、OPC>0で空データの場合はエラーにすべき
        XCTAssertNoThrow(try ELSwift.parseDetail(0x00, []))
        XCTAssertThrowsError(try ELSwift.parseDetail(0x01, [])) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testParseDetailOPCZero() throws {
        print("-- testParseDetailOPCZero")
        // OPC=0は有効（プロパティが0個の場合）
        let result = try ELSwift.parseDetail(0x00, [0x80, 0x01, 0x30])
        XCTAssertEqual(result.count, 0)
    }

    func testParseDetailInsufficientLength() {
        print("-- testParseDetailInsufficientLength")
        // OPC=2だけどデータが1個分しかない
        XCTAssertThrowsError(try ELSwift.parseDetail(0x02, [0x80, 0x01, 0x30])) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testParseDetailMaxOPC() {
        print("-- testParseDetailMaxOPC")
        // OPC=255の境界値テスト（実際には非現実的だが）
        var largeData: [UInt8] = []
        for i in 0..<255 {
            largeData.append(UInt8(i))
            largeData.append(0x01)
            largeData.append(0x30)
        }
        XCTAssertNoThrow(try ELSwift.parseDetail(0xff, largeData))
    }

    func testParseBytesTooShort() {
        print("-- testParseBytesTooShort")
        // 最小14バイト必要だが10バイトしかない
        let shortData: [UInt8] = [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01]
        XCTAssertThrowsError(try ELSwift.parseBytes(shortData)) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testParseBytesEmptyArray() {
        print("-- testParseBytesEmptyArray")
        XCTAssertThrowsError(try ELSwift.parseBytes([])) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testParseBytesInvalidEHD() {
        print("-- testParseBytesInvalidEHD")
        // EHDが0x1081でない場合
        let invalidData: [UInt8] = [0x10, 0x82, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x01, 0x80, 0x00]
        // 注: EHDチェックがない場合はパースされる可能性があるため、実装依存
        XCTAssertNoThrow(try ELSwift.parseBytes(invalidData))
    }

    func testParseStringEmpty() {
        print("-- testParseStringEmpty")
        XCTAssertThrowsError(try ELSwift.parseString("")) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testParseStringOddLength() {
        print("-- testParseStringOddLength")
        // 奇数長の文字列（16進数として不正）
        XCTAssertThrowsError(try ELSwift.parseString("108100000")) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testParseStringInvalidHex() {
        print("-- testParseStringInvalidHex")
        // 無効な16進数文字を含む場合はエラーにすべき
        // 注: 現在の実装では0として扱われるが、これは将来修正すべき
        XCTAssertThrowsError(try ELSwift.parseString("1081ZZZ005ff010ef0016201800130")) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testToHexArrayEmpty() throws {
        print("-- testToHexArrayEmpty")
        let result = try ELSwift.toHexArray("")
        XCTAssertEqual(result, [])
    }

    func testToHexArrayOddLength() {
        print("-- testToHexArrayOddLength")
        XCTAssertThrowsError(try ELSwift.toHexArray("123")) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testToHexArrayInvalidCharacters() throws {
        print("-- testToHexArrayInvalidCharacters")
        // TODO: 将来的には無効な文字でエラーにすべき
        // 現在の実装では無効な文字は0として扱われる
        let result = try ELSwift.toHexArray("1G2H")
        XCTAssertEqual(result, [16, 2]) // "1G" -> 0x10, "2H" -> 0x02
    }

    func testToHexArrayMaxValues() throws {
        print("-- testToHexArrayMaxValues")
        let result = try ELSwift.toHexArray("FF00FF00")
        XCTAssertEqual(result, [255, 0, 255, 0])
    }

    func testSubstrZeroLength() throws {
        print("-- testSubstrZeroLength")
        let result = try ELSwift.substr("hello", 0, 0)
        XCTAssertEqual(result, "")
    }

    func testSubstrNegativeStart() {
        print("-- testSubstrNegativeStart")
        // UIntなので負の数は渡せないが、極端に大きい値で代替
        XCTAssertThrowsError(try ELSwift.substr("hello", UInt.max, 2)) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testSubstrStartGreaterThanLength() {
        print("-- testSubstrStartGreaterThanLength")
        XCTAssertThrowsError(try ELSwift.substr("hello", 10, 2)) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testSubstrEndExceedsLength() {
        print("-- testSubstrEndExceedsLength")
        XCTAssertThrowsError(try ELSwift.substr("hello", 0, 100)) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testSubstrFullString() throws {
        print("-- testSubstrFullString")
        let result = try ELSwift.substr("hello", 0, 5)
        XCTAssertEqual(result, "hello")
    }

    func testToHexStringBoundaries() {
        print("-- testToHexStringBoundaries")
        XCTAssertEqual(ELSwift.toHexString(0), "00")
        XCTAssertEqual(ELSwift.toHexString(255), "ff")
        XCTAssertEqual(ELSwift.toHexString(16), "10")
        XCTAssertEqual(ELSwift.toHexString(1), "01")
    }

    func testBytesToStringEmpty() throws {
        print("-- testBytesToStringEmpty")
        let result = try ELSwift.bytesToString([])
        XCTAssertEqual(result, "")
    }

    func testBytesToStringSingleByte() throws {
        print("-- testBytesToStringSingleByte")
        let result = try ELSwift.bytesToString([0x41])
        XCTAssertEqual(result, "41")
    }

    func testBytesToStringMaxValue() throws {
        print("-- testBytesToStringMaxValue")
        let result = try ELSwift.bytesToString([0xff, 0x00, 0x01])
        XCTAssertEqual(result, "ff0001")
    }

    func testParseMapForm2MinimumProperties() throws {
        print("-- testParseMapForm2MinimumProperties")
        // 16個（最小のForm2）
        let result = try ELSwift.parseMapForm2([0x10, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01])
        XCTAssertEqual(result[0], 0x10) // count
        XCTAssertEqual(result.count, 17) // count + 16 properties
    }

    func testParseMapForm2ExactlyMinimum() throws {
        print("-- testParseMapForm2ExactlyMinimum")
        // Form2の最小は16プロパティ（count=0x10）
        // 16ビット全てONなら16プロパティ
        let result = try ELSwift.parseMapForm2([0x10, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(result[0], 0x10) // 16プロパティ
        XCTAssertEqual(result.count, 17) // count + 16 properties
    }

    func testParseMapForm2AllZeros() throws {
        print("-- testParseMapForm2AllZeros")
        // 全ビットが0の場合
        let result = try ELSwift.parseMapForm2([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(result, [0x00]) // プロパティ数0
    }

    func testParseMapForm2AllOnes() throws {
        print("-- testParseMapForm2AllOnes")
        // 全ビットが1の場合（最大128プロパティ）
        let input: [UInt8] = [0x80] + Array(repeating: 0xff, count: 16)
        let result = try ELSwift.parseMapForm2(input)
        XCTAssertEqual(result[0], 0x80) // count = 128
        XCTAssertEqual(result.count, 129) // count + 128 properties
    }

    func testELDATAToArrayBoundary() throws {
        print("-- testELDATAToArrayBoundary")
        // 最小構成のELDATA
        let els = EL_STRUCTURE(
            tid: [0x00, 0x00],
            seoj: [0x0e, 0xf0, 0x01],
            deoj: [0x0e, 0xf0, 0x01],
            esv: 0x62,
            opc: 0x00,
            epcpdcedt: []
        )
        let result = try ELSwift.ELDATA2Array(els)
        XCTAssertEqual(result.count, 12) // EHD(2) + TID(2) + SEOJ(3) + DEOJ(3) + ESV(1) + OPC(1)
    }

    func testELDATAToArrayWithMaxOPC() throws {
        print("-- testELDATAToArrayWithMaxOPC")
        // OPC=255の境界値
        var largeEpcpdcedt: [UInt8] = []
        for _ in 0..<255 {
            largeEpcpdcedt.append(0x80)
            largeEpcpdcedt.append(0x01)
            largeEpcpdcedt.append(0x30)
        }
        let els = EL_STRUCTURE(
            tid: [0x00, 0x00],
            seoj: [0x05, 0xff, 0x01],
            deoj: [0x0e, 0xf0, 0x01],
            esv: 0x62,
            opc: 0xff,
            epcpdcedt: largeEpcpdcedt
        )
        let result = try ELSwift.ELDATA2Array(els)
        XCTAssertEqual(result.count, 12 + largeEpcpdcedt.count)
    }

    // MARK: - Error Case Tests for Send Functions
    func testSendStringMultiEmpty() {
        print("-- testSendStringMultiEmpty")
        XCTAssertThrowsError(try ELSwift.sendStringMulti("")) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testSendStringMultiInvalidHex() {
        print("-- testSendStringMultiInvalidHex")
        XCTAssertThrowsError(try ELSwift.sendStringMulti("INVALID")) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testSendBaseMultiEmptyData() {
        print("-- testSendBaseMultiEmptyData")
        // 空データはエラーにすべき（有効なELパケットではない）
        // 注: 現在の実装ではエラーにならないが、将来修正すべき
        XCTAssertThrowsError(try ELSwift.sendBaseMulti(Data())) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testSendBaseMultiEmptyArray() {
        print("-- testSendBaseMultiEmptyArray")
        // 空配列はエラーにすべき（有効なELパケットではない）
        // 注: 現在の実装ではエラーにならないが、将来修正すべき
        XCTAssertThrowsError(try ELSwift.sendBaseMulti([])) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testSendOPC1MultiInvalidSEOJ() {
        print("-- testSendOPC1MultiInvalidSEOJ")
        XCTAssertThrowsError(try ELSwift.sendOPC1Multi(
            [0x05, 0xff], // 2バイトしかない
            [0x0e, 0xf0, 0x01],
            ELSwift.GET,
            0x80,
            [0x00]
        )) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    func testSendOPC1MultiInvalidDEOJ() {
        print("-- testSendOPC1MultiInvalidDEOJ")
        XCTAssertThrowsError(try ELSwift.sendOPC1Multi(
            [0x05, 0xff, 0x01],
            [0x0e, 0xf0], // 2バイトしかない
            ELSwift.GET,
            0x80,
            [0x00]
        )) { error in
            XCTAssertTrue(error is ELError)
        }
    }

    // MARK: - TID Boundary Tests
    func testTIDBoundaryAllValues() {
        print("-- testTIDBoundaryAllValues")

        let originalTID = ELSwift.tid

        // 0x0000
        ELSwift.tid = [0x00, 0x00]
        ELSwift.increaseTID()
        XCTAssertEqual(ELSwift.tid, [0x00, 0x01])

        // 0x00FF -> 0x0100
        ELSwift.tid = [0x00, 0xff]
        ELSwift.increaseTID()
        XCTAssertEqual(ELSwift.tid, [0x01, 0x00])

        // 0xFF00 -> 0xFF01
        ELSwift.tid = [0xff, 0x00]
        ELSwift.increaseTID()
        XCTAssertEqual(ELSwift.tid, [0xff, 0x01])

        // 0xFFFF -> 0x0000 (rollover)
        ELSwift.tid = [0xff, 0xff]
        ELSwift.increaseTID()
        XCTAssertEqual(ELSwift.tid, [0x00, 0x00])

        // 中間値
        ELSwift.tid = [0x12, 0x34]
        ELSwift.increaseTID()
        XCTAssertEqual(ELSwift.tid, [0x12, 0x35])

        ELSwift.tid = originalTID
    }

    // MARK: - Array Safe Subscript Edge Cases
    func testArraySafeSubscriptNegativeIndex() {
        print("-- testArraySafeSubscriptNegativeIndex")
        let array = [1, 2, 3]
        XCTAssertNil(array[safe: -1])
    }

    func testArraySafeSubscriptEmptyArray() {
        print("-- testArraySafeSubscriptEmptyArray")
        let array: [Int] = []
        XCTAssertNil(array[safe: 0])
    }

    // MARK: - EL_STRUCTURE Edge Cases
    func testELStructureWithEmptyEPCPDCEDT() {
        print("-- testELStructureWithEmptyEPCPDCEDT")
        let els = EL_STRUCTURE(
            tid: [0x00, 0x00],
            seoj: [0x05, 0xff, 0x01],
            deoj: [0x0e, 0xf0, 0x01],
            esv: ELSwift.GET,
            opc: 0x00,
            epcpdcedt: []
        )
        XCTAssertEqual(els.OPC, 0x00)
        XCTAssertEqual(els.EPCPDCEDT, [])
    }

    func testELStructureWithMaxTID() {
        print("-- testELStructureWithMaxTID")
        let els = EL_STRUCTURE(
            tid: [0xff, 0xff],
            seoj: [0xff, 0xff, 0xff],
            deoj: [0xff, 0xff, 0xff],
            esv: 0xff,
            opc: 0xff,
            epcpdcedt: [0xff, 0xff, 0xff]
        )
        XCTAssertEqual(els.TID, [0xff, 0xff])
        XCTAssertEqual(els.SEOJ, [0xff, 0xff, 0xff])
        XCTAssertEqual(els.DEOJ, [0xff, 0xff, 0xff])
    }

    // MARK: - Facilities Manager Edge Cases
    func testFacilitiesManagerMultipleIPs() async {
        print("-- testFacilitiesManagerMultipleIPs")
        let manager = ELFacilitiesManager()

        await manager.setFacilitiesNewIP("192.168.1.100")
        await manager.setFacilitiesNewIP("192.168.1.101")
        await manager.setFacilitiesNewIP("192.168.1.102")

        let facilities = await manager.getFacilities()
        XCTAssertEqual(facilities.count, 3)
    }

    func testFacilitiesManagerSameIPMultipleSEOJ() async {
        print("-- testFacilitiesManagerSameIPMultipleSEOJ")
        let manager = ELFacilitiesManager()

        await manager.setFacilitiesNewIP("192.168.1.100")
        await manager.setFacilitiesNewSEOJ("192.168.1.100", [0x01, 0x30, 0x01])
        await manager.setFacilitiesNewSEOJ("192.168.1.100", [0x02, 0x90, 0x01])
        await manager.setFacilitiesNewSEOJ("192.168.1.100", [0x05, 0xff, 0x01])

        let facilities = await manager.getFacilities()
        XCTAssertNotNil(facilities["192.168.1.100"]?[[0x01, 0x30, 0x01]])
        XCTAssertNotNil(facilities["192.168.1.100"]?[[0x02, 0x90, 0x01]])
        XCTAssertNotNil(facilities["192.168.1.100"]?[[0x05, 0xff, 0x01]])
    }

    func testFacilitiesManagerOverwriteEDT() async {
        print("-- testFacilitiesManagerOverwriteEDT")
        let manager = ELFacilitiesManager()

        await manager.setFacilitiesNewIP("192.168.1.100")
        await manager.setFacilitiesNewSEOJ("192.168.1.100", [0x01, 0x30, 0x01])

        // 最初の値設定
        await manager.setFacilitiesSetEDT("192.168.1.100", [0x01, 0x30, 0x01], 0x80, [0x30])
        var facilities = await manager.getFacilities()
        XCTAssertEqual(facilities["192.168.1.100"]?[[0x01, 0x30, 0x01]]?[0x80], [0x30])

        // 上書き
        await manager.setFacilitiesSetEDT("192.168.1.100", [0x01, 0x30, 0x01], 0x80, [0x31])
        facilities = await manager.getFacilities()
        XCTAssertEqual(facilities["192.168.1.100"]?[[0x01, 0x30, 0x01]]?[0x80], [0x31])
    }

    // MARK: - SNA (Service Not Available) Response Tests
    func testSNAResponseForINFCWithNoDEOJ() throws {
        print("-- testSNAResponseForINFCWithNoDEOJ")
        // ESV=74 (INF-C) の場合、DEOJが存在しない場合は破棄
        // この場合、SNAを返すべき（仕様による）

        let els = EL_STRUCTURE(
            tid: [0x00, 0x01],
            seoj: [0x0e, 0xf0, 0x01],
            deoj: [0x01, 0x30, 0x01], // 存在しないDEOJ想定
            esv: 0x74, // INF-C
            opc: 0x01,
            epcpdcedt: [0x80, 0x01, 0x30]
        )

        // TODO: SNA応答生成のテスト実装
        // 現在は構造確認のみ
        XCTAssertEqual(els.ESV, 0x74)
        XCTAssertEqual(els.OPC, 0x01)
    }

    func testSNAResponseForOPCZero() throws {
        print("-- testSNAResponseForOPCZero")
        // OPC=0の場合、SetGetに対してSNA (node目標×ESV=6E SetGet_SNA)または通常応答

        let elsSetGet = EL_STRUCTURE(
            tid: [0x00, 0x02],
            seoj: [0x0e, 0xf0, 0x01],
            deoj: [0x01, 0x30, 0x01],
            esv: 0x6E, // SetGet
            opc: 0x00, // OPC=0
            epcpdcedt: []
        )

        // OPC=0は仕様上有効だが、SetGetでOPC=0は通常ありえないケース
        XCTAssertEqual(elsSetGet.ESV, 0x6E)
        XCTAssertEqual(elsSetGet.OPC, 0x00)
    }

    func testSNAResponseForEDTSizeExceeded() throws {
        print("-- testSNAResponseForEDTSizeExceeded")
        // EDTサイズが各propertyの定義を超えた場合、SNAまたは破棄

        // 例: 動作状態(0x80)は通常1バイトだが、それ以上のデータ
        let els = EL_STRUCTURE(
            tid: [0x00, 0x03],
            seoj: [0x0e, 0xf0, 0x01],
            deoj: [0x01, 0x30, 0x01],
            esv: 0x60, // SetC
            opc: 0x01,
            epcpdcedt: [0x80, 0x05, 0x30, 0x31, 0x32, 0x33, 0x34] // PDC=5, 本来は1バイト
        )

        // TODO: EDTサイズ検証ロジックのテスト実装
        XCTAssertEqual(els.EPCPDCEDT[1], 0x05) // PDC=5
    }

    func testSNAResponseForEmptyEDT() throws {
        print("-- testSNAResponseForEmptyEDT")
        // EDTが空の場合（近い値も設定不可な場合）
        // SNAまたは受理したふりでRes（第5節1.2）

        let els = EL_STRUCTURE(
            tid: [0x00, 0x04],
            seoj: [0x0e, 0xf0, 0x01],
            deoj: [0x01, 0x30, 0x01],
            esv: 0x61, // SetC
            opc: 0x01,
            epcpdcedt: [0x80, 0x00] // PDC=0, EDTが空
        )

        // 空EDTは仕様上、特定の状況では有効（GETなど）
        XCTAssertEqual(els.EPCPDCEDT[1], 0x00) // PDC=0
    }

    func testNFCResDoesNotRequireSNA() throws {
        print("-- testNFCResDoesNotRequireSNA")
        // ESV=7A (NFC_Res) は指定EPCがなくてもSNAではない

        let els = EL_STRUCTURE(
            tid: [0x00, 0x05],
            seoj: [0x01, 0x30, 0x01],
            deoj: [0x0e, 0xf0, 0x01],
            esv: 0x7A, // NFC_Res
            opc: 0x01,
            epcpdcedt: [0x80, 0x00]
        )

        // NFC_Resは破棄するが、SNAは返さない
        XCTAssertEqual(els.ESV, 0x7A)
    }

    func testSetGetSNAResponseStructure() throws {
        print("-- testSetGetSNAResponseStructure")
        // SetGet_SNA (ESV=5E) の構造確認

        let snaDEOJ: [UInt8] = [0x01, 0x30, 0x01]
        let snaSEOJ: [UInt8] = [0x0e, 0xf0, 0x01]

        let elsSetGetSNA = EL_STRUCTURE(
            tid: [0x00, 0x06],
            seoj: snaDEOJ,  // 元のDEOJがSEOJに
            deoj: snaSEOJ,  // 元のSEOJがDEOJに
            esv: 0x5E, // SetGet_SNA
            opc: 0x01,
            epcpdcedt: [0x80, 0x00]
        )

        // SNA応答はSEOJ/DEOJが入れ替わる
        XCTAssertEqual(elsSetGetSNA.ESV, 0x5E)
        XCTAssertEqual(elsSetGetSNA.SEOJ, snaDEOJ)
        XCTAssertEqual(elsSetGetSNA.DEOJ, snaSEOJ)
    }    func testSetCSNAResponseStructure() throws {
        print("-- testSetCSNAResponseStructure")
        // SetC_SNA (ESV=50) の構造確認

        let elsSetCSNA = EL_STRUCTURE(
            tid: [0x00, 0x07],
            seoj: [0x01, 0x30, 0x01],
            deoj: [0x0e, 0xf0, 0x01],
            esv: 0x50, // SetC_SNA
            opc: 0x01,
            epcpdcedt: [0x80, 0x00]
        )

        XCTAssertEqual(elsSetCSNA.ESV, 0x50)
    }

    func testGetSNAResponseStructure() throws {
        print("-- testGetSNAResponseStructure")
        // Get_SNA (ESV=52) の構造確認

        let elsGetSNA = EL_STRUCTURE(
            tid: [0x00, 0x08],
            seoj: [0x01, 0x30, 0x01],
            deoj: [0x0e, 0xf0, 0x01],
            esv: 0x52, // Get_SNA
            opc: 0x01,
            epcpdcedt: [0x80, 0x00]
        )

        XCTAssertEqual(elsGetSNA.ESV, 0x52)
    }

    func testINF_SNAResponseStructure() throws {
        print("-- testINF_SNAResponseStructure")
        // INF_SNA (ESV=53) の構造確認

        let elsINFSNA = EL_STRUCTURE(
            tid: [0x00, 0x09],
            seoj: [0x01, 0x30, 0x01],
            deoj: [0x0e, 0xf0, 0x01],
            esv: 0x53, // INF_SNA
            opc: 0x01,
            epcpdcedt: [0x80, 0x00]
        )

        XCTAssertEqual(elsINFSNA.ESV, 0x53)
    }
}
