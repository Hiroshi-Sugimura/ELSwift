//==============================================================================
// SUGIMURA Hiroshi
//==============================================================================
import Foundation
import Network



//==============================================================================
public struct EL_STRUCTURE : Equatable{
    public var EHD : [UInt8]
    public var TID : [UInt8]
    public var SEOJ : [UInt8]
    public var DEOJ : [UInt8]
    public var EDATA: [UInt8]    // 下記はEDATAの詳細
    public var ESV : UInt8
    public var OPC : UInt8
    public var DETAIL: [UInt8]
    public var DETAILs : Dictionary<UInt8, [UInt8]>?
    
    init() {
        EHD = [0x10, 0x81]
        TID = [0x00, 0x00]
        SEOJ = [0x0e, 0xf0, 0x01]
        DEOJ = [0x0e, 0xf0, 0x01]
        EDATA = []
        ESV = 0x00
        OPC = 0x00
        DETAIL = [0x00]
    }
    
    init(tid:[UInt8], seoj:[UInt8], deoj:[UInt8], esv:UInt8, opc:UInt8, detail:[UInt8]) {
        EHD = [0x10, 0x81]
        TID = tid
        SEOJ = seoj
        DEOJ = deoj
        ESV = esv
        OPC = opc
        DETAIL = detail
        EDATA = [esv, opc] + detail
        do{
            DETAILs = try ELSwift.parseDetail(opc, detail)
        }catch{
            print("error")
        }
    }
}


//==============================================================================
enum ELError: Error {
    case BadNetwork
    case BadString(String)
    case BadReceivedData
    case other(String)
}


//==============================================================================
public class ELSwift {
    public static let networkType = "_networkplayground._udp."
    public static let networkDomain = "local"
    public static let PORT:UInt16 = 3610
    public static let EHD:[UInt8] = [0x10, 0x81]
    
    // define
    public static let SETI_SNA:UInt8 = 0x50
    public static let SETC_SNA:UInt8 = 0x51
    public static let GET_SNA:UInt8 = 0x52
    public static let INF_SNA:UInt8 = 0x53
    public static let SETGET_SNA:UInt8 = 0x5e
    public static let SETI:UInt8 = 0x60
    public static let SETC:UInt8 = 0x61
    public static let GET:UInt8 = 0x62
    public static let INF_REQ:UInt8 = 0x63
    public static let SETGET:UInt8 = 0x6e
    public static let SET_RES:UInt8 = 0x71
    public static let GET_RES:UInt8 = 0x72
    public static let INF:UInt8 = 0x73
    public static let INFC:UInt8 = 0x74
    public static let INFC_RES:UInt8 = 0x7a
    public static let SETGET_RES:UInt8 = 0x7e
    public static let EL_port = 3610
    public static let EL_Multi = "224.0.23.0"
    public static let EL_Multi6 = "FF02::1"
    public static let MULTI_IP: String = "224.0.23.0"
    public static let MultiIP:String = "224.0.23.0"
    
    public var facilities:Dictionary<String, Dictionary<String, Dictionary<String,String?>? >? > = Dictionary<String, Dictionary<String, Dictionary<String, String?>? >? >()
    
    
    // user settings
    static var callbackFunc : ((_ rinfo: (address:String, port:UInt16), _ els: EL_STRUCTURE?, _ err: Error?) -> Void)? = {_,_,_ in }
    
    static var EL_obj: [String]!
    static var EL_cls: [String]!
    
    public static var Node_details: Dictionary<String, [UInt8]>!  = [String: [UInt8]]()
    
    public static var tid:[UInt8] = [0x00, 0x01]
    
    // private static var listener: NWListener!
    private static var group: NWConnectionGroup!
    
    static var isReady: Bool = false
    public static var listening: Bool = true
    static var queue = DispatchQueue.global(qos: .userInitiated)
    
    public static func initialize(_ objList: [String], _ callback: ((_ rinfo:(address:String, port:UInt16), _ els: EL_STRUCTURE?, _ err: Error?) -> Void)?, _ ipVer: UInt8? ) throws -> Void {
        do{
            print("init()")
            
            //--- Listener
            /*
             let params = NWParameters.udp
             params.allowFastOpen = true
             let port = NWEndpoint.Port(rawValue: ELSwift.PORT)
             ELSwift.listener = try? NWListener(using: params, on: port!)
             
             ELSwift.listener?.stateUpdateHandler = { newState in
             switch newState {
             case .ready:
             ELSwift.isReady = true
             print("Listener connected to port \(String(describing: port))")
             break
             case .failed, .cancelled:
             // Announce we are no longer able to listen
             ELSwift.listening = false
             ELSwift.isReady = false
             print("Listener disconnected from port \(String(describing: port))")
             break
             default:
             print("Listener connecting to port \(String(describing: port))...")
             break
             }
             }
             
             ELSwift.listener?.newConnectionHandler = { connection in
             connection.stateUpdateHandler = { (newState) in
             switch newState {
             case .ready:
             print("ready")
             ELSwift.receive(nWConnection: connection)
             break;
             default:
             break
             }
             }
             connection.start(queue: DispatchQueue(label: "newconn"))
             
             }
             ELSwift.listener?.start(queue: ELSwift.queue)
             */
            
            //---- multicast
            guard let multicast = try? NWMulticastGroup(for: [ .hostPort(host: "224.0.23.0", port: 3610)], disableUnicast: false)
            else { fatalError("error in Muticast") }
            
            ELSwift.group = NWConnectionGroup(with: multicast, using: .udp)
            
            ELSwift.group.setReceiveHandler(maximumMessageSize: 1518, rejectOversizedMessages: true) { (message, content, isComplete) in
                //let message = String(data: content, encoding: .utf8)
                //let message = Data(content, encoding: .utf8)
                print("-> message from: \(message.remoteEndpoint!)")
                print("-> content: \([UInt8](content!))" )
                //let sendContent = Data("ack".utf8)
                //message.reply(content: sendContent)
            }
            
            ELSwift.group.stateUpdateHandler = { (newState) in
                print("Group entered state \(String(describing: newState))")
                switch newState {
                case .ready:
                    print("ready")
                    var msg:[UInt8] = ELSwift.EHD + ELSwift.tid + [0x05, 0xff, 0x01] + [0x0e, 0xf0, 0x01 ]
                    msg.append(contentsOf:[ELSwift.GET, 0x01, 0xD6, 0x00])
                    let groupSendContent = Data(msg)  // .data(using: .utf8)
                    
                    print("send...UDP")
                    ELSwift.group.send(content: groupSendContent) { (error)  in
                        print("Send complete with error \(String(describing: error))")
                    }
                case .waiting(let error):
                    print("waiting")
                    print(error)
                case .setup:
                    print("setup")
                case .cancelled:
                    print("cancelled")
                case .failed:
                    print("failed")
                    //case .preparing:
                    //    print("preparing")
                default:
                    print("default")
                }
            }
            
            let queue = DispatchQueue(label: "ECHONETNetwork")
            //print(group.isUnicastDisabled)
            ELSwift.group.start(queue: queue)
            //group.start(queue: .main)
            
            
            // 送信用ソケットの準備
            EL_obj = objList
            
            let classes = try objList.map{
                try ELSwift.substr( $0, 0, 4)
            }
            EL_cls = classes
            
            Node_details["80"] = [0x30]
            Node_details["82"] = [0x01, 0x0a, 0x01, 0x00] // EL version, 1.1
            Node_details["83"] = [0xfe, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] // identifier
            Node_details["8a"] = [0x00, 0x00, 0x77] // maker code
            Node_details["9d"] = [0x02, 0x80, 0xd5]       // inf map, 1 Byte目は個数
            Node_details["9e"] = [0x00]                 // set map, 1 Byte目は個数
            Node_details["9f"] = [0x09, 0x80, 0x82, 0x83, 0x8a, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7] // get map, 1 Byte目は個数
            Node_details["d3"] = [0x00, 0x00, UInt8(EL_obj.count)]  // 自ノードで保持するインスタンスリストの総数（ノードプロファイル含まない）, user項目
            Node_details["d4"] = [0x00, UInt8(EL_cls.count + 1)]        // 自ノードクラス数, user項目, D4はノードプロファイルが入る
            
            var v = try EL_obj.map{
                try ELSwift.toHexArray( $0 )
            }
            v.insert( [UInt8(objList.count)], at: 0 )
            Node_details["d5"] = v.flatMap{ $0 }    // インスタンスリスト通知, user項目
            Node_details["d6"] = Node_details["d5"]    // 自ノードインスタンスリストS, user項目
            
            v = try EL_cls.map{
                try ELSwift.toHexArray( $0 )
            }
            v.insert( [UInt8(EL_cls.count)], at: 0 )
            Node_details["d7"] = v.flatMap{ $0 }  // 自ノードクラスリストS, user項目
            
            // 初期化終わったのでノードのINFをだす
            try ELSwift.sendOPC1( EL_Multi, [0x0e,0xf0,0x01], [0x0e,0xf0,0x01], 0x73, 0xd5, Node_details["d5"]! );
            
            ELSwift.callbackFunc = callback
            
        }catch let error {
            throw error
        }
        
        
    }
    
    public static func release () {
        print("release")
        group.cancel()
    }
    
    public static func IsReady() -> Bool {
        return ELSwift.isReady
    }
    
    //---------------------------------------
    public static func receive(nWConnection:NWConnection) -> Void {
        nWConnection.receive(minimumIncompleteLength: 1, maximumLength: 5, completion: { (data, context, flag, error) in
            print("receiveMessage")
            if let data = data {
                let receiveData = [UInt8](data)
                print(receiveData)
                print(flag)
                if(flag == false) {
                    ELSwift.receive(nWConnection: nWConnection)
                }
            }
            else {
                print("receiveMessage data nil")
            }
        })
    }
    
    
    //---------------------------------------
    public static func sendBase(_ toip:String,_ msg: [UInt8]) throws -> Void {
        print("sendBase(Data) data:\(msg)")
        
        let queue = DispatchQueue(label:"sendBase")
        let socket = NWConnection( host:NWEndpoint.Host(toip), port:3610, using: .udp)
        
        // 送信完了時の処理のクロージャ
        let completion = NWConnection.SendCompletion.contentProcessed { error in
            if let error = error {
                print("sendBase() error: \(error)")
            }else{
                print("sendBase() 送信完了")
                socket.cancel()  // 送信したらソケット閉じる
            }
        }
        
        socket.stateUpdateHandler = { (newState) in
            switch newState {
            case .ready:
                NSLog("Ready to send")
                // 送信
                socket.send(content: msg, completion: completion)
            case .waiting(let error):
                NSLog("\(#function), \(error)")
            case .failed(let error):
                NSLog("\(#function), \(error)")
            case .setup: break
            case .cancelled: break
            case .preparing: break
            @unknown default:
                fatalError("Illegal state")
            }
        }
        
        socket.start(queue:queue)
    }
    
    
    public static func sendBase(_ toip:String,_ data: Data) throws -> Void {
        let msg:[UInt8] = [UInt8](data)
        try ELSwift.sendBase(toip, msg)
    }
    
    public static func sendArray(_ toip:String,_ array: [UInt8]) throws -> Void {
        print("sendBase(UInt8)")
        // 送信
        try sendBase(toip, Data( array ) )
    }
    
    public static func sendString(_ toip:String,_ message: String) throws -> Void {
        print("sendString()")
        // 送信
        let data = try ELSwift.toHexArray(message)
        try ELSwift.sendBase( toip, data )
    }
    
    // sendOPC1( targetIP, [0x05,0xff,0x01], [0x01,0x35,0x01], 0x62, 0x80, [0x00]);
    public static func sendOPC1(_ ip:String, _ seoj:[UInt8], _ deoj:[UInt8], _ esv: UInt8, _ epc: UInt8, _ edt:[UInt8]) throws -> Void{
        do{
            var binArray:[UInt8]
            
            if( esv == 0x62 ) { // get
                binArray = [
                    0x10, 0x81,
                    0x00, 0x00,
                    seoj[0], seoj[1], seoj[2],
                    deoj[0], deoj[1], deoj[2],
                    esv,
                    0x01,
                    epc,
                    0x00]
                
            }else{
                
                binArray = [
                    0x10, 0x81,
                    0x00, 0x00,
                    seoj[0], seoj[1], seoj[2],
                    deoj[0], deoj[1], deoj[2],
                    esv,
                    0x01,
                    epc,
                    UInt8(edt.count)] + edt
                
            }
            
            // データができたので送信する
            try ELSwift.sendArray( ip, binArray )
        }catch let error{
            throw error
        }
    }
    
    
    //------------ multi send
    public static func sendBaseMulti(_ data: Data)  throws -> Void {
        print("sendBaseMulti(Data)")
        ELSwift.group.send(content: data) { (error)  in
            print("Send complete with error \(String(describing: error))")
        }
    }
    
    public static func sendBaseMulti(_ msg: [UInt8]) throws -> Void {
        print("sendBaseMulti(UInt8)")
        // 送信
        let groupSendContent = Data(msg)  // .data(using: .utf8)
        ELSwift.group.send(content: groupSendContent) { (error)  in
            print("Send complete with error \(String(describing: error))")
        }
    }
    
    public static func sendStringMulti(_ message: String) throws -> Void {
        print("sendStringMulti()")
        // 送信
        let data = try ELSwift.toHexArray(message)
        try ELSwift.sendBaseMulti( data )
    }
    
    public static func sendOPC1Multi(_ seoj:[UInt8], _ deoj:[UInt8], _ esv: UInt8, _ epc: UInt8, _ edt:[UInt8]) throws -> Void{
        do{
            var binArray:[UInt8]
            
            if( esv == ELSwift.GET ) { // get
                binArray = [
                    0x10, 0x81,
                    0x00, 0x00,
                    seoj[0], seoj[1], seoj[2],
                    deoj[0], deoj[1], deoj[2],
                    esv,
                    0x01,
                    epc,
                    0x00]
                
            }else{
                binArray = [
                    0x10, 0x81,
                    0x00, 0x00,
                    seoj[0], seoj[1], seoj[2],
                    deoj[0], deoj[1], deoj[2],
                    esv,
                    0x01,
                    epc,
                    UInt8(edt.count)] + edt
                
            }
            
            // データができたので送信する
            try ELSwift.sendBaseMulti( binArray )
        }catch let error{
            throw error
        }
    }
    
    public static func search() throws -> Void {
        print("search()")
        var msg:[UInt8] = ELSwift.EHD + ELSwift.tid + [0x05, 0xff, 0x01] + [0x0e, 0xf0, 0x01 ]
        msg.append(contentsOf: [ELSwift.GET, 0x01, 0xD6, 0x00])
        let groupSendContent = Data(msg)  // .data(using: .utf8)
        ELSwift.group.send(content: groupSendContent) { (error)  in
            print("Send complete with error \(String(describing: error))")
        }
    }
    
    
    //////////////////////////////////////////////////////////////////////
    // 変換系
    //////////////////////////////////////////////////////////////////////
    
    // Detailだけをparseする，内部で主に使う
    public static func parseDetail(_ opc:UInt8,_ detail:[UInt8] ) throws -> Dictionary<UInt8, [UInt8]> {
        // print("parseDetail()")
        var ret: Dictionary<UInt8, [UInt8]> = [UInt8: [UInt8]]() // 戻り値用，連想配列
        
        do {
            var now:Int = 0  // 現在のIndex
            var epc:UInt8 = 0
            var pdc:UInt8 = 0
            let array:[UInt8] = detail  // edts
            
            print(array)
            
            // OPCループ
            for _ in (0 ..< opc ) {
                // EPC（機能）
                epc = array[now]
                now += 1
                
                // PDC（EDTのバイト数）
                pdc = array[now]
                now += 1
                
                var edt:[UInt8] = []  // edtは初期化しておく
                
                // getの時は pdcが0なのでなにもしない，0でなければ値が入っている
                if( pdc == 0 ) {
                    ret[ epc ] = [0x00] // 本当はnilを入れたい
                } else {
                    // PDCループ
                    for _ in (0..<pdc) {
                        // 登録
                        edt += [ array[now] ]
                        now += 1
                    }
                    // print("opc: \(opc), epc:\(epc), pdc:\(pdc), edt:\(edt)")
                    ret[ epc ] = try ELSwift.toHexArray( ELSwift.bytesToString( edt ) )
                }
                
            }  // opcループ
            
        } catch let error {
            print( "ELSwift.parseDetail(): detail error. opc: \(opc), str: \(detail)" )
            throw error
        }
        
        return ret
    }
    
    // Detailだけをparseする，内部で主に使う
    public static func parseDetail(_ opc:UInt8,_ str:String ) throws -> Dictionary<UInt8, [UInt8]> {
        return try parseDetail( opc, ELSwift.toHexArray(str) )
    }
    
    public static func parseDetail(_ opc:String,_ str:String ) throws -> Dictionary<UInt8, [UInt8]>  {
        return try parseDetail( ELSwift.toHexArray(opc)[0], ELSwift.toHexArray(str) )
    }
    
    // バイトデータをいれるとEL_STRACTURE形式にする ok
    public static func parseBytes(_ bytes:[UInt8] ) throws -> EL_STRUCTURE {
        do{
            // 最低限のELパケットになってない
            if( bytes.count < 14 ) {
                print( "ELSwift.parseBytes error. bytes is less then 14 bytes. bytes.count is \(bytes.count)" )
                print( bytes )
                throw ELError.BadReceivedData
            }
            
            // 数値だったら文字列にして
            var str:String = ""
            
            for i in (0..<bytes.count) {
                str += ELSwift.toHexString( bytes[i] )
            }
            
            // 文字列にしたので，parseStringで何とかする
            return ( try ELSwift.parseString(str) )
        }catch let error {
            throw error
        }
        
    }
    
    // 16進数で表現された文字列をいれるとEL_STRUCTURE形式にする ok
    public static func parseString(_ str: String ) throws -> EL_STRUCTURE {
        var eldata: EL_STRUCTURE = EL_STRUCTURE()
        do{
            eldata.EHD = try ELSwift.toHexArray( try ELSwift.substr( str, 0, 4 ) )
            eldata.TID = try ELSwift.toHexArray( try ELSwift.substr( str, 4, 4 ) )
            eldata.SEOJ = try ELSwift.toHexArray( try ELSwift.substr( str, 8, 6 ) )
            eldata.DEOJ = try ELSwift.toHexArray( try ELSwift.substr( str, 14, 6 ) )
            eldata.EDATA = try ELSwift.toHexArray( try ELSwift.substr( str, 20, UInt(str.utf8.count - 20) ) )
            eldata.ESV = try ELSwift.toHexArray( try ELSwift.substr( str, 20, 2 ) )[0]
            eldata.OPC = try ELSwift.toHexArray( try ELSwift.substr( str, 22, 2 ) )[0]
            eldata.DETAIL = try ELSwift.toHexArray( try ELSwift.substr( str, 24, UInt(str.utf8.count - 24) ) )
            eldata.DETAILs = try ELSwift.parseDetail( eldata.OPC, try ELSwift.substr( str, 24, UInt(str.utf8.count - 24) ) )
        }catch let error{
            throw error
        }
        
        return ( eldata )
    }
    
    
    // 文字列をいれるとELらしい切り方のStringを得る  ok
    public static func getSeparatedString_String(_ str: String ) throws -> String {
        var ret:String = ""
        let a = try ELSwift.substr( str, 0, 4 )
        let b = try ELSwift.substr( str, 4, 4 )
        let c = try ELSwift.substr( str, 8, 6 )
        let d = try ELSwift.substr( str, 14, 6 )
        let e = try ELSwift.substr( str, 20, 2 )
        let f = try ELSwift.substr( str, 22, UInt(str.utf8.count - 22) )
        ret = "\(a) \(b) \(c) \(d) \(e) \(f)"
        
        return ret
    }
    
    
    // 文字列操作が我慢できないので作る（1Byte文字固定）
    public class func substr(_ str:String, _ begginingIndex:UInt, _ count:UInt) throws -> String {
        // pre-condition
        let len = str.count
        if( len < begginingIndex + count ) { throw ELError.other("BadRange str:\(str), begin:\(begginingIndex), count:\(count)") }
        
        // チェック後
        let begin = str.index( str.startIndex, offsetBy: Int(begginingIndex))
        let end   = str.index( begin, offsetBy: Int(count))
        let ret   = String(str[begin..<end])
        return ret
    }
    
    
    // ELDATAをいれるとELらしい切り方のStringを得る
    public static func getSeparatedString_ELDATA(_ eldata : EL_STRUCTURE ) -> String {
        let ehd = eldata.EHD.map{ ELSwift.toHexString($0)}.joined()
        let tid = eldata.TID.map{ ELSwift.toHexString($0)}.joined()
        let seoj = eldata.SEOJ.map{ ELSwift.toHexString($0)}.joined()
        let deoj = eldata.DEOJ.map{ ELSwift.toHexString($0)}.joined()
        let edata = eldata.EDATA.map{ ELSwift.toHexString($0)}.joined()
        return ( "\(ehd) \(tid) \(seoj) \(deoj) \(edata)" )
    }
    
    
    // EL_STRACTURE形式から配列へ
    public static func ELDATA2Array(_ eldata: EL_STRUCTURE ) throws -> [UInt8] {
        let ret = eldata.EHD + eldata.TID + eldata.SEOJ + eldata.DEOJ + eldata.EDATA
        return ret
    }
    
    // 1バイトを文字列の16進表現へ（1Byteは必ず2文字にする） ok
    public static func toHexString(_ byte:UInt8 ) -> String {
        return ( String(format: "%02hhx", byte) )
    }
    
    
    // 16進表現の文字列を数値のバイト配列へ ok
    public static func toHexArray(_ str: String ) throws -> [UInt8] {
        var ret: [UInt8] = []
        
        //for i in (0..<str.utf8.count); i += 2 ) {
        // Swift 3.0 ready
        try stride(from:0, to: str.utf8.count, by: 2).forEach {
            let i = $0
            
            // var l = ELSwift.substr( str, i, 1 )
            // var r = ELSwift.substr( str, i+1, 1 )
            
            let hexString = try ELSwift.substr( str, UInt(i), 2 )
            let hex = Int(hexString, radix: 16) ?? 0
            
            ret += [ UInt8(hex) ]
        }
        
        return ret
    }
    
    
    // バイト配列を文字列にかえる ok
    public static func bytesToString(_ bytes: [UInt8] ) throws -> String{
        var ret:String = ""
        
        for i in (0..<bytes.count) {
            ret += ELSwift.toHexString( bytes[i] )
        }
        return ret
    }
    
    
    // parse Propaty Map Form 2
    // 16以上のプロパティ数の時，記述形式2，出力はForm1にすること, bitstr = EDT
    // bitstrは 数値配列[0x01, 0x30]のようなやつ、か文字列"0130"のようなやつを受け付ける
    public static func parseMapForm2(_ bitArray:[UInt8]) throws -> [UInt8] {
        var ret:[UInt8] = [0]
        var val:UInt8   = 0x7f  // 計算上 +1が溢れないように7fから始める
        
        // bit loop
        for bit in 0 ... 7 {
            // byte loop
            for byt in 1 ... 16 {
                val += 1
                if ( ((bitArray[byt] >> bit) & 0x01) != 0 ) {
                    ret.append( UInt8(val) )
                }
            }
        }
        
        ret[0] = UInt8(ret.count - 1);
        return ret
    }
    
    // 文字列入力もできる
    public static func parseMapForm2(_ bitString:String ) throws -> [UInt8] {
        return try ELSwift.parseMapForm2( ELSwift.toHexArray(bitString) )
    }
    
}
