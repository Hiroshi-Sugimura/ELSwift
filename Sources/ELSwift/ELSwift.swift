//==============================================================================
// SUGIMURA Hiroshi
//==============================================================================
import Foundation
import Network

//==============================================================================
public typealias T_PDCEDT = [UInt8]
public typealias T_DETAILs = Dictionary<UInt8, T_PDCEDT>


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
    public var DETAILs : T_DETAILs
    
    init() {
        EHD = [0x10, 0x81]
        TID = [0x00, 0x00]
        SEOJ = [0x0e, 0xf0, 0x01]
        DEOJ = [0x0e, 0xf0, 0x01]
        EDATA = []
        ESV = 0x00
        OPC = 0x00
        DETAIL = [0x00]
        DETAILs = T_DETAILs()
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
            DETAILs = T_DETAILs()
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
    public static let EL_port:Int = 3610
    public static let EL_Multi:String = "224.0.23.0"
    public static let EL_Multi6:String = "FF02::1"
    public static let MULTI_IP: String = "224.0.23.0"
    public static let MultiIP: String = "224.0.23.0"
    
    public static let NODE_PROFILE: [UInt8] = [0x0e, 0xf0]
    public static let NODE_PROFILE_OBJECT: [UInt8] = [0x0e, 0xf0, 0x01]
    
    public static var facilities: Dictionary<String, Dictionary<String, T_DETAILs>? > = Dictionary<String, Dictionary<String, T_DETAILs>? >()
    
    // user settings
    static var userFunc : ((_ rAddress:String, _ els: EL_STRUCTURE?, _ err: Error?) -> Void)? = {_,_,_ in }
    
    static var EL_obj: [String]!
    static var EL_cls: [String]!
    
    public static var Node_details: Dictionary<UInt8, T_PDCEDT> = [UInt8: T_PDCEDT]()
    
    public static var autoGetProperties: Bool = true
    public static var autoGetDelay : Int = 1000
    public static var autoGetWaitings : Int = 0
    
    public static var tid:[UInt8] = [0x00, 0x01]
    
    // private static var listener: NWListener!
    private static var group: NWConnectionGroup!
    
    static var isReady: Bool = false
    public static var listening: Bool = true
    static var queue = DispatchQueue.global(qos: .userInitiated)
    
    public static func initialize(_ objList: [String], _ callback: ((_ rAddress:String, _ els: EL_STRUCTURE?, _ err: Error?) -> Void)? ) throws -> Void {
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
             break
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
                if let ipa = message.remoteEndpoint {
                    let ip_port = ipa.debugDescription.components(separatedBy: ":")
                    print("-> message from IP:\(ip_port[0]), Port: \(ip_port[1])")
                    ELSwift.returner( ip_port[0], content )
                }else{
                    print("-> message doesn't convert to ipa")
                }
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
            
            Node_details[0x80] = [0x30]
            Node_details[0x82] = [0x01, 0x0a, 0x01, 0x00] // EL version, 1.1
            Node_details[0x83] = [0xfe, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00] // identifier
            Node_details[0x8a] = [0x00, 0x00, 0x77] // maker code
            Node_details[0x9d] = [0x02, 0x80, 0xd5]       // inf map, 1 Byte目は個数
            Node_details[0x9e] = [0x00]                 // set map, 1 Byte目は個数
            Node_details[0x9f] = [0x09, 0x80, 0x82, 0x83, 0x8a, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7] // get map, 1 Byte目は個数
            Node_details[0xd3] = [0x00, 0x00, UInt8(EL_obj.count)]  // 自ノードで保持するインスタンスリストの総数（ノードプロファイル含まない）, user項目
            Node_details[0xd4] = [0x00, UInt8(EL_cls.count + 1)]        // 自ノードクラス数, user項目, D4はノードプロファイルが入る
            
            var v = try EL_obj.map{
                try ELSwift.toHexArray( $0 )
            }
            v.insert( [UInt8(objList.count)], at: 0 )
            Node_details[0xd5] = v.flatMap{ $0 }    // インスタンスリスト通知, user項目
            Node_details[0xd6] = Node_details[0xd5]    // 自ノードインスタンスリストS, user項目
            
            v = try EL_cls.map{
                try ELSwift.toHexArray( $0 )
            }
            v.insert( [UInt8(EL_cls.count)], at: 0 )
            Node_details[0xd7] = v.flatMap{ $0 }  // 自ノードクラスリストS, user項目
            
            // 初期化終わったのでノードのINFをだす
            try ELSwift.sendOPC1( EL_Multi, [0x0e,0xf0,0x01], [0x0e,0xf0,0x01], 0x73, 0xd5, Node_details[0xd5]! )
            
            ELSwift.userFunc = callback
            
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
    
    
    public static func decreaseWaitings() {
        if( ELSwift.autoGetWaitings != 0 ) {
            ELSwift.autoGetWaitings -= 1;
        }
    }
    
    public static func increaseWaitings() {
        ELSwift.autoGetWaitings += 1;
    }
    
    public static func increaseTID() {
        // TIDの調整
        var carry = 0; // 繰り上がり
        if( ELSwift.tid[1] == 0xff ) {
            ELSwift.tid[1] = 0;
            carry = 1;
        } else {
            ELSwift.tid[1] += 1;
        }
        
        if( carry == 1 ) {
            if( ELSwift.tid[0] == 0xff ) {
                ELSwift.tid[0] = 0;
            } else {
                ELSwift.tid[0] += 1;
            }
        }
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
    // 表示系
    public static func printFacilities() throws -> Void {
        print("==== ELSwift.printFacilities() ====")

        for (ip, objs) in ELSwift.facilities {
            print("ip: \(ip)")
            
            if let os = objs {
                for (eoj, obj) in os {
                    print("  eoj: \(eoj)")
                    
                    for (epc, edt) in obj {
                        print("    \(epc) = \(String(describing: edt))")
                    }
                }
            }
        }
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
                print("Ready to send")
                // 送信
                socket.send(content: msg, completion: completion)
            case .waiting(let error):
                print("\(#function), \(error)")
            case .failed(let error):
                print("\(#function), \(error)")
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
        try ELSwift.sendBase(toip, Data( array ) )
    }
    
    public static func sendString(_ toip:String,_ message: String) throws -> Void {
        print("sendString()")
        // 送信
        let data = try ELSwift.toHexArray(message)
        try ELSwift.sendBase( toip, data )
    }
    
    // sendOPC1( targetIP, [0x05,0xff,0x01], [0x01,0x35,0x01], 0x62, 0x80, [0x00])
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
    
    public static func sendDetails(_ ip:String, _ seoj:[UInt8], _ deoj:[UInt8], _ esv:UInt8, _ DETAILs:T_DETAILs ) throws -> Void {
        // TIDの調整
        ELSwift.increaseTID()
        
        var buffer:[UInt8] = [];
        var opc:UInt8 = 0;
        var pdc:UInt8 = 0;
        var detail:[UInt8] = []
        
        // detailsがArrayのときはEPCの出現順序に意味がある場合なので、順番を崩さないようにせよ
        for( epc, pdcedt ) in DETAILs {
            // edtがあればそのまま使う、nilなら[0x00]をいれておく
            if( pdcedt[0] == 0x00 ) {  // [0x00] の時は GetやGet_SNA等で存在する、この時はpdc省略
                detail += [epc] + [0x00];
            }else{
                pdc = pdcedt[0];  // 0番がpdc
                let edt:[UInt8] = Array( pdcedt[1...] )
                detail += [epc] + [pdc] + edt;
            }
            opc += 1;
        }
        
        buffer = ELSwift.EHD + ELSwift.tid + seoj + deoj + [esv] + [opc] + detail
        
        // データができたので送信する
        return try ELSwift.sendBase(ip, buffer);
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
        }catch{
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
    
    public static func getPropertyMaps(_ ip:String,_ eoj:[UInt8] )
    {
        // プロファイルオブジェクトのときはプロパティマップももらうけど，識別番号ももらう
        if( eoj[0] == 0x0e && eoj[1] == 0xf0 ) {
            /*
            setTimeout(() => {
                ELSwift.sendDetails( ip, ELSwift.NODE_PROFILE_OBJECT, eoj, ELSwift.GET, {'83':'', '9d':'', '9e':'', '9f':''});
                ELSwift.decreaseWaitings();
            }, ELSwift.autoGetDelay * (EL.autoGetWaitings+1));
             */
            ELSwift.increaseWaitings();
            
        }else{
            // デバイスオブジェクト
            /*
            setTimeout(() => {
                ELSwift.sendDetails( ip, ELSwift.NODE_PROFILE_OBJECT, eoj, ELSwift.GET, {'9d':'', '9e':'', '9f':''});
                ELSwift.decreaseWaitings();
            }, ELSwift.autoGetDelay * (ELSwift.autoGetWaitings+1));
             */
            ELSwift.increaseWaitings();
        }
        
    }
    
    
    //------------ reply
    public static func replySetDetail( rAddress:String, els:EL_STRUCTURE, dev_details:[UInt8] ) {
    }

    public static func replyGetDetail( rAddress:String, els:EL_STRUCTURE, dev_details:[UInt8] ) {
    }

    //////////////////////////////////////////////////////////////////////
    // 変換系
    //////////////////////////////////////////////////////////////////////
    
    // Detailだけをparseする，内部で主に使う
    public static func parseDetail(_ opc:UInt8,_ detail:[UInt8] ) throws -> T_DETAILs {
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
            
        } catch {
            print( "ELSwift.parseDetail(): detail error. opc: \(opc), str: \(detail)" )
            throw error
        }
        
        return ret
    }
    
    // Detailだけをparseする，内部で主に使う
    public static func parseDetail(_ opc:UInt8,_ str:String ) throws -> T_DETAILs {
        return try parseDetail( opc, ELSwift.toHexArray(str) )
    }
    
    public static func parseDetail(_ opc:String,_ str:String ) throws -> T_DETAILs {
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
    
    // バイトデータをいれるとEL_STRACTURE形式にする ok
    public static func parseData(_ data:Data ) throws -> EL_STRUCTURE {
        try ELSwift.parseBytes( [UInt8](data) )
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
        }catch{
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
    
    
    
    //////////////////////////////////////////////////////////////////////
    // EL受信
    //////////////////////////////////////////////////////////////////////
    // ELの受信データを振り分ける
    public static func returner(_ rAddress: String, _ content: Data? ) {
        // 自IPを無視する設定があればチェックして無視する
        // 無視しないならチェックもしない
        //        if( EL.ignoreMe ? EL.myIPaddress(rinfo) : false ) {
        //            return;
        //        }
        
        // 無視しない
        //        let els;
        do {
            // キチンとパースできた
            var els:EL_STRUCTURE = try ELSwift.parseData( content! )

            // ヘッダ確認
            if (els.EHD != [0x10, 0x81]) {
                return
            }
            
            // Node profileに関してきちんと処理する
            if ( Array(els.DEOJ[0..<2]) == ELSwift.NODE_PROFILE ) {
                els.DEOJ = ELSwift.NODE_PROFILE_OBJECT  // ここで0ef000, 0ef001, 0ef002の表記ゆれを統合する
                
                switch (els.ESV) {
                    ////////////////////////////////////////////////////////////////////////////////////
                    // 0x5x
                    // エラー受け取ったときの処理
                case ELSwift.SETI_SNA:   // "50"
                    break
                case ELSwift.SETC_SNA:   // "51"
                    // SetCに対する返答のSetResは，EDT 0x00でOKの意味を受け取ることとなる．ゆえにその詳細な値をGetする必要がある
                    // OPCが2以上の時、全EPCがうまくいった時だけSET_RESが返却され、一部のEPCが失敗したらSETC_SNAになる
                    // 成功EPCにはPDC=0,EDTなし、失敗EPCにはオウム返しでくる
                    // つまりここではPDC=0のものを読みに行くのだが、一気に取得するとまた失敗するかもしれないのでひとつづつ取得する
                    // autoGetPropertiesがfalseなら自動取得しない
                    // epcひとつづつ取得する方式
                    /*
                     if(  ELSwift.autoGetProperties ) {
                     for( let epc in els.DETAILs ) {
                     setTimeout(() => {
                     ELSwift.sendDetails( rinfo, EL.NODE_PROFILE_OBJECT, els.SEOJ, EL.GET, { [epc]:'' } )
                     ELSwift.decreaseWaitings()
                     }, EL.autoGetDelay * (EL.autoGetWaitings+1))
                     EL.increaseWaitings()
                     }
                     }
                     */
                    break
                    
                case ELSwift.INF_SNA:    // "53"
                    break
                    
                case ELSwift.SETGET_SNA: // "5e"
                    // console.log( "EL.returner: get error" )
                    // console.dir( els )
                    break
                    
                    ////////////////////////////////////////////////////////////////////////////////////
                    // 0x6x
                case ELSwift.SETI: // "60
                    // ELSwift.replySetDetail( rinfo, els, { [ELSwift.NODE_PROFILE_OBJECT]: ELSwift.Node_details} )
                    break;
                    
                case ELSwift.SETC: // "61"
                    // ELSwift.replySetDetail( rinfo, els, { [ELSwift.NODE_PROFILE_OBJECT]: ELSwift.Node_details} )
                    break
                    
                case ELSwift.GET: // 0x62
                    // console.log( "EL.returner: get prop. of Node profile els:", els)
                    // ELSwift.replyGetDetail( rinfo, els, { [ELSwift.NODE_PROFILE_OBJECT]: ELSwift.Node_details} )
                    break
                    
                case ELSwift.INF_REQ: // 0x63
                    if ( els.DETAILs[0xd5] == [0x00] ) {  // EL ver. 1.0以前のコントローラからサーチされた場合のレスポンス
                        // console.log( "EL.returner: Ver1.0 INF_REQ.")
                        // ELSwift.sendOPC1( ELSwift.EL_Multi, ELSwift.NODE_PROFILE_OBJECT, ELSwift.toHexArray(els.SEOJ), 0x73, 0xd5, ELSwift.Node_details[0xd5])
                    }
                    break
                    
                case ELSwift.SETGET: // "6e"
                    break
                    
                    ////////////////////////////////////////////////////////////////////////////////////
                    // 0x7x
                case ELSwift.SET_RES: // 71
                    // SetCに対する返答のSetResは，EDT 0x00でOKの意味を受け取ることとなる．ゆえにその詳細な値をGetする必要がある
                    // OPCが2以上の時、全EPCがうまくいった時だけSET_RESが返却される
                    // 一部のEPCが失敗したらSETC_SNAになる
                    // autoGetPropertiesがfalseなら自動取得しない
                    // epc一気に取得する方法に切り替えた(ver.2.12.0以降)
                    if(  ELSwift.autoGetProperties ) {
                        var details: T_DETAILs = T_DETAILs()
                        for( epc, _ ) in els.DETAILs {
                            details[epc] = [0x00]
                        }
                        // console.log('EL.SET_RES: autoGetProperties')
                        /*
                        setTimeout(() => {
                            ELSwift.sendDetails( rinfo, ELSwift.NODE_PROFILE_OBJECT, els.SEOJ, ELSwift.GET, details )
                            ELSwift.decreaseWaitings()
                        }, ELSwift.autoGetDelay * (ELSwift.autoGetWaitings+1))
                         */
                        ELSwift.increaseWaitings()
                    }
                    break
                    
                case ELSwift.GET_SNA, ELSwift.GET_RES: // 52, 72
                    // 52
                    // GET_SNAは複数EPC取得時に、一つでもエラーしたらSNAになるので、他EPCが取得成功している場合があるため無視してはいけない。
                    // ここでは通常のGET_RESのシーケンスを通すこととする。
                    // 具体的な処理としては、PDCが0の時に設定値を取得できていないこととすればよい。
                    
                    // 72
                    // autoGetPropertiesがfalseなら自動取得しない
                    if( ELSwift.autoGetProperties == false ) { break }
                    
                    // V1.1
                    // d6のEDT表現が特殊，EDT1バイト目がインスタンス数になっている
                    // なお、d6にはNode profileは入っていない
                    if (Array(els.SEOJ[0..<4]) == ELSwift.NODE_PROFILE)  {
                        if let array:T_PDCEDT = els.DETAILs[0xd6] {
                            // console.log( "EL.returner: get object list! PropertyMap req V1.0.")
                            // 自ノードインスタンスリストSに書いてあるオブジェクトのプロパティマップをもらう
                            var instNum:Int = Int( array[0] ) // 0番目はPDC, indexに使うのでIntにする
                            while( 0 < instNum ) {
                                let begin:Int =  ( instNum - 1) * 3 + 1
                                let end:Int = ( instNum - 1) * 3 + 4
                                let obj:[UInt8] = Array( array[  begin ..< end  ] )
                                // ELSwift.getPropertyMaps( rinfo.remoteEndpoint?.Host as String, obj )
                                print("-> ELSwift.GET_SNA, GET_RES", rAddress, obj)
                                instNum -= 1
                            }
                        }
                    }
                    
                    if let array:T_PDCEDT = els.DETAILs[0x9f]  {  // 自動プロパティ取得は初期化フラグ, 9fはGetProps. 基本的に9fは9d, 9eの和集合になる。(そのような決まりはないが)
                        // DETAILsは解析後なので，format 1も2も関係なく処理する
                        // EPC取れるだけ一気にとる方式に切り替えた(ver.2.12.0以降)
                        var details:T_DETAILs = [:]
                        let num:Int = Int( array[0] )
                        for i in 0 ... num - 1 {
                            // d6, 9d, 9e, 9fはサーチの時点で取得しているはず
                            // 特にd6と9fは取り直すと無限ループするので注意
                            if( array[i+1] != 0xd6 && array[i+1] != 0x9d && array[i+1] != 0x9e && array[i+1] != 0x9f ) {
                                details[ array[i+1] ] = []
                            }
                        }
                        
                        /*
                        setTimeout(() => {
                            ELSwift.sendDetails( rinfo, ELSwift.NODE_PROFILE_OBJECT, els.SEOJ, EL.GET, details)
                            ELSwift.decreaseWaitings()
                        }, ELSwift.autoGetDelay * (ELSwift.autoGetWaitings+1))
                        ELSwift.increaseWaitings()
                         */
                    }
                    break
                    
                case ELSwift.INF:  // 0x73
                    // ECHONETネットワークで、新規デバイスが起動したのでプロパティもらいに行く
                    // autoGetPropertiesがfalseならやらない
                    if( els.DETAILs[0xd5] != nil && els.DETAILs[0xd5] != []  && ELSwift.autoGetProperties) {
                        // ノードプロファイルオブジェクトのプロパティマップをもらう
                        // ELSwift.getPropertyMaps( rinfo.remoteEndpoint.IPAddress as String, ELSwift.NODE_PROFILE_OBJECT )
                        print("-> ELSwift.INF", rAddress, ELSwift.NODE_PROFILE_OBJECT)
                    }
                    break
                    
                case ELSwift.INFC: // "74"
                    // ECHONET Lite Ver. 1.0以前の処理で利用していたフロー
                    // オブジェクトリストをもらったらそのオブジェクトのPropertyMapをもらいに行く
                    // autoGetPropertiesがfalseならやらない
                    if(ELSwift.autoGetProperties ) {
                        if let array:T_PDCEDT = els.DETAILs[0xd5] {
                            // ノードプロファイルオブジェクトのプロパティマップをもらう
                            // ELSwift.getPropertyMaps( rinfo.remoteEndpoint, ELSwift.NODE_PROFILE_OBJECT )
                            print("-> ELSwift.INFC", rAddress, ELSwift.NODE_PROFILE_OBJECT)

                            // console.log( "EL.returner: get object list! PropertyMap req.")
                            var instNum:Int = Int( array[0] )
                            while( 0 < instNum ) {
                                let begin:Int = (instNum - 1) * 3 + 1
                                let end:Int = (instNum - 1) * 3 + 4
                                let obj:[UInt8] = Array( array[  begin ..< end  ] )
                                // ELSwift.getPropertyMaps( rinfo.remoteEndpoint.Host.ipv4, obj )
                                print("-> ELSwift.INF", rAddress, obj)

                                instNum -= 1
                            }
                        }
                    }
                    break
                    
                case ELSwift.INFC_RES: // "7a"
                    break;
                case ELSwift.SETGET_RES: // "7e"
                    break
                    
                default:
                    break
                }
            }
            
            // 受信状態から機器情報修正, GETとINFREQ，SET_RESは除く
            if (els.ESV != ELSwift.GET && els.ESV != ELSwift.INF_REQ && els.ESV != ELSwift.SET_RES) {
                print("-> ELSwift.INF", rAddress, els)
                // ELSwift.renewFacilities(rinfo.remoteEndpoint?, els)
            }
            
            // 機器オブジェクトに関してはユーザー関数に任す
            print("-> ELSwift.userFunc", rAddress, els)
            // ELSwift.userFunc(rinfo.remoteEndpoint?.Host, els)
        } catch {
            print("-> ELSwift.userFunc", rAddress, content!, error)
            // ELSwift.userFunc(rinfo.remoteEndpoint?.Host, els, error)
        }
    }
    
    // ネットワーク内のEL機器全体情報を更新する，受信したら勝手に実行される
    public static func renewFacilities( address:String, els:EL_STRUCTURE) throws -> Void {
        do {
            let epcList:T_DETAILs = try ELSwift.parseDetail(els.OPC, els.DETAIL);
            let seoj = try ELSwift.bytesToString( els.SEOJ )

            // 新規IP
            if ( ELSwift.facilities[address] == nil ) { //見つからない
                // ELSwift.facilities[address] = [String: [String: [UInt8: [UInt8]]]]();
                ELSwift.facilities[address] = Dictionary<String, T_DETAILs>()
            }

            // 新規obj
            if (ELSwift.facilities[address]??[seoj] == nil) {
                ELSwift.facilities[address]??[seoj] = T_DETAILs();
                // 新規オブジェクトのとき，プロパティリストもらうと取りきるまでループしちゃうのでやめた
            }

            for ( epc, pdcedt ) in epcList {
                // 新規epc
                if (ELSwift.facilities[address]??[seoj]?[epc] == nil) {
                    ELSwift.facilities[address]??[seoj]?[epc] = [UInt8]();
                }

                // GET_SNAの時のNULL {EDT:''} を入れてしまうのを避ける
                if pdcedt != []  {
                    ELSwift.facilities[address]??[seoj]?[epc] = pdcedt;
                }

                // もしEPC = 0x83の時は識別番号なので，識別番号リストに確保
                /*
                if( epc === 0x83 ) {
                    ELSwift.identificationNumbers.push( {id: epcList[epc], ip: address, OBJ: els.SEOJ } );
                }
                 */
            }
        } catch {
            print("ELSwift.renewFacilities error.");
            // console.dir(e);
            throw error;
        }
    }
    
    
}
