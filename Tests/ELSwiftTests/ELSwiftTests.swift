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
            }, option: (debug:true, ipVer:0) )
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

        print("parseDetail, ???")
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
        print("getSeparatedString_ELDATA")
        XCTAssertEqual(
            ELSwift.getSeparatedString_ELDATA(f),
            "1081 0000 05ff01 0ef001 6204800131b00142bb011cb30118"
        );
                
        // ELDATA形式から配列へ
        print("ELDATA2Array")
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

        print("-- printFacilities")
        ELSwift.printFacilities()

        
        //////////////////////////////////////////////////////////////////////
        // 終了
        //////////////////////////////////////////////////////////////////////
        // 終了
        print("-- release")
        ELSwift.release()
    }
}
