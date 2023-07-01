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
        // Detail
        print("parseDetail, OPC=1")
        var a: Dictionary<UInt8, [UInt8]> = [UInt8: [UInt8]]() // 戻り値用，連想配列
        a[0x80] = [0x30]
        XCTAssertEqual(
            try ELSwift.parseDetail( "01", "800130" ),
            a)
        
        print("parseDetail, OPC=1, EPC=2")
        var b: Dictionary<UInt8, [UInt8]> = [UInt8: [UInt8]]() // 戻り値用，連想配列
        b[0xb9] = [0x12, 0x34]
        XCTAssertEqual(
            try ELSwift.parseDetail( "01", "B9021234" ),
            b)
        
        print("parseDetail, OPC=4")
        var c: Dictionary<UInt8, [UInt8]> = [UInt8: [UInt8]]() // 戻り値用，連想配列
        c[0x80] = [0x31]
        c[0xb0] = [0x42]
        c[0xbb] = [0x1c]
        c[0xb3] = [0x18]
        XCTAssertEqual(
            try ELSwift.parseDetail( "04", "800131b00142bb011cb30118" ),
            c)
        
        print("parseDetail, OPC=5, EPC=2")
        var d: Dictionary<UInt8, [UInt8]> = [UInt8: [UInt8]]() // 戻り値用，連想配列
        d[0x80] = [0x31]
        d[0xb0] = [0x42]
        d[0xbb] = [0x1c]
        d[0xb3] = [0x18]
        d[0xb9] = [0x12, 0x34]
        XCTAssertEqual(
            try ELSwift.parseDetail( "05", "800131b00142bb011cb9021234b30118" ),
            d )
        
        /*
         print("parseDetail, ???")
         XCTAssertEqual(
         try ELSwift.parseDetail( "08", "80013181010f8204000050018311fe000077000002eaed646f381e000000028801428a030000779d060580818fb0a09e070680818fb0b3a0" ),
         {   "80": "31", "81": "0f", "82": "00005001", "83": "fe000077000002eaed646f381e00000002", "88": "42",
         "8a": "000077", "9d": "0580818fb0a0", "9e": "0680818fb0b3a0" });
         */
        
        /*
         print("parseDetail, BAD EDATA")
         XCTAssertThrows(
         // large opc     __
         try ELSwift.parseDetail( "06", "D30400000001D70106E00400" )
         )
         */
        
        /*
         print("parseDetail exception case, large opc")
         expect(function() {
         // large opc     __
         try ELSwift.parseDetail( "03", "300180310288FF" )
         }).to.throw(Error);
         
         print("parseDetail exception case, smart meter")
         XCTAssertEqual(
         try ELSwift.parseDetail( "06", "D30400000001D70106E004000C6C96E30400000006E7040000036" ),
         {   "80": "31", "81": "0f", "82": "00005001", "83": "fe000077000002eaed646f381e00000002", "88": "42",
         "8a": "000077", "9d": "0580818fb0a0", "9e": "0680818fb0b3a0" });
         */
        
        /*
        // バイトデータをいれるとELDATA形式にする
        print("parseBytes, OPC=1")
        var e:EL_STRUCTURE = EL_STRUCTURE( tid:"0000", seoj: "05ff01", deoj: "0ef001",  esv: "62",  opc: "01",  detail: "800130" )
        XCTAssertEqual(
            try ELSwift.parseBytes( [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x01, 0x80, 0x01, 0x30] ),
            e)
         */
        
        /*
         // 16進数で表現された文字列をいれるとELDATA形式にする
         print("parseBytes, OPC=4")
         XCTAssertEqual(
         try ELSwift.parseBytes( [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x04, 0x80, 0x01, 0x31, 0xb0, 0x01, 0x42, 0xbb, 0x01, 0x1c, 0xb3, 0x01, 0x18] ),
         { EHD: "1081",
         TID: "0000",
         SEOJ: "05ff01",
         DEOJ: "0ef001",
         EDATA: "6204800131b00142bb011cb30118",
         ESV: "62",
         OPC: "04",
         DETAIL: "800131b00142bb011cb30118",
         DETAILs: { "80": "31", "b0": "42", "bb": "1c", "b3": "18" } });
         
         
         print("parseBytes exception case, large opc")
         expect(function() {
         // large opc                                                                        __
         try ELSwift.parseBytes( [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x02, 0x30, 0x01, 0x80] )
         }).to.throw(Error);
         */
        
        // 16進数で表現された文字列をいれるとELDATA形式にする
        print("parseString, OPC=1")
        var e:EL_STRUCTURE = EL_STRUCTURE( tid:[0x00, 0x00], seoj: [0x05, 0xff, 0x01], deoj: [0x0e, 0xf0, 0x01],  esv: 0x62,  opc: 0x01,  detail: [0x80, 0x01, 0x30] )
        XCTAssertEqual(
            try ELSwift.parseString( "1081000005ff010ef0016201800130" ),
            e )
         
        /*
         // 16�i���ŕ\�����ꂽ�������������ELDATA�`���ɂ���, ����OPC
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
         
         
         print("parseString exception case, large opc")
         expect(function() {
         // large opc
         try ELSwift.parseString( "1081000005ff010ef0016202300180" )
         }).to.throw(Error);
         
         // format 2
         print("parseString, format 2 (Mitsubishi TV)")
         XCTAssertEqual(
         try ELSwift.parseString( "10820003000e000106020105ff0162010100" ),
         { EHD: "1082",
         AMF: "0003000e000106020105ff0162010100" });
         */
        
        /*
         // �������������EL�炵���؂����String�𓾂�
         print("getSeparatedString_String")
         XCTAssertEqual(
         // input
         try ELSwift.getSeparatedString_String( "1081000005ff010ef0016201300180" ),
         // output
         "1081 0000 05ff01 0ef001 62 01300180");
         
         print("getSeparatedString_String exception case")
         expect(function() {
         // large opc
         try ELSwift.getSeparatedString_String( )
         }).to.throw(Error);
         
         // ELDATA��������EL�炵���؂����String�𓾂�
         print("getSeparatedString_ELDATA")
         XCTAssertEqual(
         try ELSwift.getSeparatedString_ELDATA(
         { EHD: "1081",  // input
         TID: "0000",
         SEOJ: "05ff01",
         DEOJ: "0ef001",
         EDATA: "6201300180",
         ESV: "62",
         OPC: "01",
         DETAIL: "300180",
         DETAILs: { "30": "80" } }),
         //output
         "1081 0000 05ff01 0ef001 6201300180"
         );
         
         print("getSeparatedString_ELDATA exception case, null")
         expect(function() {
         // null case
         try ELSwift.getSeparatedString_ELDATA( );
         }).to.throw(Error);
         */
        
        /*
         // ELDATA�`������z���
         print("ELDATA2Array")
         XCTAssertEqual(
         try ELSwift.ELDATA2Array(
         { EHD: "1081",  // input
         TID: "0000",
         SEOJ: "05ff01",
         DEOJ: "0ef001",
         EDATA: "6201300180",
         ESV: "62",
         OPC: "01",
         DETAIL: "300180",
         DETAILs: { "30": "80" } } ),
         // output
         [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x62, 0x01, 0x30, 0x01, 0x80]);
         
         */
        
        // 1バイトを文字列の16進表現へ（1Byteは必ず2文字にする）
        print("toHexString")
        XCTAssertEqual(
            ELSwift.toHexString( 65 ),
            "41")
        
        // 16進表現の文字列を数値のバイト配列へ
        print("toHexArray")
        XCTAssertEqual(
            ELSwift.toHexArray( "418081A0A1B0F0FF" ),
            [65, 128, 129, 160, 161, 176, 240, 255])
        
        print("toHexArray exception case, empty")            // empty case
        XCTAssertEqual(
            ELSwift.toHexArray(""),
            []);
        
        // バイト配列を文字列にかえる
        print("bytesToString")
        XCTAssertEqual(
            try ELSwift.bytesToString( [ 34, 130, 132, 137, 146, 148, 149, 150, 151, 155, 162, 164, 165, 167, 176, 180, 183, 194, 196, 200, 210, 212, 216, 218, 219, 226, 228, 232, 234, 235, 240, 244, 246, 248, 250 ] ),
            "2282848992949596979ba2a4a5a7b0b4b7c2c4c8d2d4d8dadbe2e4e8eaebf0f4f6f8fa");
        
        
        
        //////////////////////////////////////////////////////////////////////
        // send
        //////////////////////////////////////////////////////////////////////
        /*
         // EL���M�̃x�[�X
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
         
         // �z��̎�
         print("sendArray")
         if(ipversion == 4) {
         let tid = try ELSwift.sendArray("127.0.0.1", [0x10, 0x81, 0x02, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, try ELSwift.GET, 0x01, 0x80, 0x00]);
         console.log( "TID:", tid );
         }else if(ipversion == 6) {
         let tid = try ELSwift.sendArray("::1", [0x10, 0x81, 0x02, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, try ELSwift.GET, 0x01, 0x80, 0x00]);
         console.log( "TID:", tid );
         }
         
         
         // EL�̔��ɓT�^�I��OPC��ł��
         print("sendOPC1")
         if(ipversion == 4) {
         let tid = try ELSwift.sendOPC1("127.0.0.1", [0x05, 0xff, 0x01], [0x0e, 0xf0, 0x01], try ELSwift.GET, 0x01, 0x80, [0x00]);
         console.log( "TID:", tid );
         }else if(ipversion) {
         let tid = try ELSwift.sendOPC1("::1", [0x05, 0xff, 0x01], [0x0e, 0xf0, 0x01], try ELSwift.GET, 0x01, 0x80, [0x00]);
         console.log( "TID:", tid );
         }
         
         // EL�̔��ɓT�^�I�ȑ��M3 ������^�C�v
         print("sendString")
         if(ipversion == 4) {
         let tid = try ELSwift.sendString ("127.0.0.1", "1081030005ff010ef00163018000");
         console.log( "TID:", tid );
         }else if(ipversion == 6) {
         let tid = try ELSwift.sendString ("::1", "1081030005ff010ef00163018000");
         console.log( "TID:", tid );
         }
         
         // �@�팟��
         print("search")
         try ELSwift.search ();
         
         // parse Propaty Map Form 2
         // 16�ȏ�̃v���p�e�B���̎��C�L�q�`��2�C�o�͂�Form1�ɂ��邱��
         print("parseMapForm2 (16 props)")
         XCTAssertEqual(
         try ELSwift.parseMapForm2( "1001010101010101010101010101010101" ),  // 16 properties
         [ 0x10, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f ] );
         
         print("parseMapForm2 (16 props)")
         XCTAssertEqual(
         // input
         try ELSwift.parseMapForm2( "1041414100004000604100410000020202" ),  // equal and more than 16 properties
         // output
         [  16, 128, 129, 130, 136, 138, 157, 158, 159, 215, 224, 225, 226, 229, 231, 232, 234 ] ); // 16
         
         print("parseMapForm2 (54 props)")
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
         
         print("parseMapForm2 exception case, null")
         expect(function() {
         // empty case
         try ELSwift.parseMapForm2(  )
         }).to.throw(Error);
         
         // �v���p�e�B�}�b�v�̃p�[�X�`�F�b�N
         // �v���p�e�B16��菭�Ȃ��i�L�q�`��1�C0x0f�j
         print("PropertyMap 15 bytes", function (done) {
         let rinfo = {address: "127.0.0.1"};
         try ELSwift.returner( [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x72, 0x01, 0x9f, 0x0f, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x8b, 0x8c, 0x8d, 0x8e, 0x8f],
         rinfo,
         (rinfo, els) => {
         XCTAssertEqual(
         els,
         { EHD: "1081",
         TID: "0000",
         SEOJ: "05ff01",
         DEOJ: "0ef001",
         EDATA: "72019f0f8182838485868788898a8b8c8d8e8f",
         ESV: "72",
         OPC: "01",
         DETAIL: "9f0f8182838485868788898a8b8c8d8e8f",
         DETAILs: { "9f": "8182838485868788898a8b8c8d8e8f" }
         } );
         done();
         } );
         } );
         
         // �v���p�e�B16�ȏ�i�L�q�`��2,0x10�j
         print("PropertyMap 16 bytes", function (done) {
         let rinfo = {address: "127.0.0.1"};
         try ELSwift.returner( [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x72, 0x01, 0x9f, 0x11, 0x10, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01],
         rinfo,
         (rinfo, els) => {
         XCTAssertEqual(
         els,
         { EHD: "1081",
         TID: "0000",
         SEOJ: "05ff01",
         DEOJ: "0ef001",
         EDATA: "72019f111001010101010101010101010101010101",
         ESV: "72",
         OPC: "01",
         DETAIL: "9f111001010101010101010101010101010101",
         DETAILs: { "9f": "10808182838485868788898a8b8c8d8e8f" }
         } );
         done();
         } );
         } );
         
         print("PropertyMap 16 bytes", function (done) {
         let rinfo = {address: "127.0.0.1"};
         try ELSwift.returner( [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x72, 0x01, 0x9f, 0x11, 0x10, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80],
         rinfo,
         (rinfo, els) => {
         XCTAssertEqual(
         els,
         { EHD: "1081",
         TID: "0000",
         SEOJ: "05ff01",
         DEOJ: "0ef001",
         EDATA: "72019f111001020408102040800102040810204080",
         ESV: "72",
         OPC: "01",
         DETAIL: "9f111001020408102040800102040810204080",
         DETAILs: { "9f": "1080889199a2aab3bbc4ccd5dde6eef7ff" }
         } );
         done();
         } );
         } );
         
         //
         print("PropertyMap many properties", function (done) {
         let rinfo = {address: "127.0.0.1"};
         try ELSwift.returner( [0x10, 0x81, 0x00, 0x00, 0x05, 0xff, 0x01, 0x0e, 0xf0, 0x01, 0x72, 0x01, 0x9f, 0x11, 0x36, 0xB1, 0xB1, 0xB1, 0xB1, 0xB0, 0xB0, 0xB1, 0xB3, 0xB3, 0xA1, 0x83, 0x81, 0x01, 0x83, 0x83, 0x83],
         rinfo,
         (rinfo, els) => {
         XCTAssertEqual(
         els,
         { EHD: "1081",
         TID: "0000",
         SEOJ: "05ff01",
         DEOJ: "0ef001",
         EDATA: "72019f1136b1b1b1b1b0b0b1b3b3a1838101838383",
         ESV: "72",
         OPC: "01",
         DETAIL: "9f1136b1b1b1b1b0b0b1b3b3a1838101838383",
         DETAILs: { "9f": "3680818283868788898a8b8c8d8e8f97989a9d9e9fc0c1c2c3c4c5c6c7c8d0d1d2d3d4d5d6d7d8d9f0f1f2f3f4f5f6f7f8f9fafbfdfeff" }
         } );
         done();
         } );
         } );
         */
        
        // 終了
        ELSwift.release()
    }
}
