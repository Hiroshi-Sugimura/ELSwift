//==============================================================================
// SUGIMURA Hiroshi
//==============================================================================
import Foundation
import Network
import SystemConfiguration

//==============================================================================
public typealias T_PDCEDT     = [UInt8]
public typealias T_EPCPDCEDT  = [UInt8]
public typealias T_DETAILs = Dictionary<UInt8, T_PDCEDT>
public typealias T_OBJs    = Dictionary<[UInt8], T_DETAILs>   // [eoj]: T_DETAILs
public typealias T_DEVs    = Dictionary<String, T_OBJs>   // "ip": T_OBJs


//==============================================================================
public struct EL_STRUCTURE : Equatable{
    public var EHD : [UInt8]
    public var TID : [UInt8]
    public var SEOJ : [UInt8]
    public var DEOJ : [UInt8]
    public var EDATA: [UInt8]    // 下記はEDATAの詳細
    public var ESV : UInt8
    public var OPC : UInt8
    public var EPCPDCEDT : T_EPCPDCEDT
    public var DETAILs : T_DETAILs
    
    init() {
        EHD = [0x10, 0x81]
        TID = [0x00, 0x00]
        SEOJ = [0x0e, 0xf0, 0x01]
        DEOJ = [0x0e, 0xf0, 0x01]
        EDATA = []
        ESV = 0x00
        OPC = 0x00
        EPCPDCEDT = [0x00]
        DETAILs = T_DETAILs()
    }
    
    init(tid:[UInt8], seoj:[UInt8], deoj:[UInt8], esv:UInt8, opc:UInt8, epcpdcedt:T_EPCPDCEDT) {
        EHD = ELSwift.EHD
        TID = tid
        SEOJ = seoj
        DEOJ = deoj
        ESV = esv
        OPC = opc
        EPCPDCEDT = epcpdcedt
        EDATA = [esv, opc] + epcpdcedt
        do{
            DETAILs = try ELSwift.parseDetail(opc, epcpdcedt)
        }catch{
            print("EL_STRUCTURE.init() error:", error)
            DETAILs = T_DETAILs()
        }
    }
}

//==============================================================================
// timer queue用のOperation class
class CSendTask: Operation {
    let address: String
    let els: EL_STRUCTURE
    
    init(_ _address: String, _ _els: EL_STRUCTURE) {
        self.address = _address
        self.els = _els
        do{
            print("CSendTask.init()")
            try ELSwift.printEL_STRUCTURE(els)
        }catch{
            print("CSendTask.init() error:", error)
        }
    }
    
    override func main () {
        if isCancelled {
            return
        }
        
        // スレッドを2秒止める
        Thread.sleep(forTimeInterval: 2)
        
        do{
            try ELSwift.sendELS(address, els)
        }catch{
            print("CSendTask.main()", els)
        }
    }
}

struct NetworkMonitor {
    static let monitor = NWPathMonitor()
    static var connection = true
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
    
    public static var facilities: Dictionary<String, T_OBJs? > = Dictionary<String, T_OBJs? >()
    
    // user settings
    static var userFunc : ((_ rAddress:String, _ els: EL_STRUCTURE?, _ err: Error?) -> Void)? = {_,_,_ in }
    
    static var EL_obj: [String]!
    static var EL_cls: [String]!
    
    public static var Node_details:T_DETAILs = T_DETAILs()
    
    public static var autoGetProperties: Bool = true
    public static var autoGetDelay : Int = 1000
    public static var autoGetWaitings : Int = 0
    
    public static var tid:[UInt8] = [0x00, 0x01]
    
    // private static var listener: NWListener!
    private static var group: NWConnectionGroup!
    
    static var isReady: Bool = false
    public static var listening: Bool = true
    static var queue = DispatchQueue.global(qos: .userInitiated)
    static var isDebug: Bool = false
    static var ipVer: Int = 0 // 0:no spec, 4:ipVer=4, 6:ipVer=6
    
    static let sendQueue = OperationQueue()

    
    public static func initialize(_ objList: [String], _ callback: @escaping ((_ rAddress:String, _ els: EL_STRUCTURE?, _ error: Error?) -> Void), option: (debug:Bool?, ipVer:Int?)? = nil ) throws -> Void {
        do{
            isDebug = option?.debug ?? false
            ipVer = option?.ipVer ?? 0
            
            
            // send queue
            sendQueue.name = "net.sugimulab.ELSwift.sendQueue"
            sendQueue.maxConcurrentOperationCount = 1
            sendQueue.qualityOfService = .userInitiated
            
            
            if( isDebug ) { print("ELSwift.init()") }

            // 自分のIPを取得したいけど、どうやるんだか謎。
            // 下記でinterfaceリストまでは取れる
            NetworkMonitor.monitor.pathUpdateHandler = { path in
                           if path.status == .satisfied {
                                // print("connection successful")
                                NetworkMonitor.connection = true
                               // print( String(describing: path.availableInterfaces) )
                          } else {
                                // print("no connection")
                                NetworkMonitor.connection = false
                                // respond to lack of connection here
                           }
                      }
            let queue2 = DispatchQueue(label: "Monitor")
            NetworkMonitor.monitor.start(queue: queue2)
            
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
                if( isDebug ) { print("-> message from: \(message.remoteEndpoint!)") }
                if let ipa = message.remoteEndpoint {
                    let ip_port = ipa.debugDescription.components(separatedBy: ":")
                    if( isDebug ) { print("-> message from IP:\(ip_port[0]), Port: \(ip_port[1])") }
                    ELSwift.returner( ip_port[0], content )
                }else{
                    if( isDebug ) { print("-> message doesn't convert to ipa") }
                }
                if( isDebug ) { print("-> content: \([UInt8](content!))" ) }
                //let sendContent = Data("ack".utf8)
                //message.reply(content: sendContent)
            }
            
            ELSwift.group.stateUpdateHandler = { (newState) in
                if( isDebug ) { print("Group entered state \(String(describing: newState))") }
                switch newState {
                case .ready:
                    if( isDebug ) { print("ready") }
                    var msg:[UInt8] = ELSwift.EHD + ELSwift.tid + [0x05, 0xff, 0x01] + [0x0e, 0xf0, 0x01 ]
                    msg.append(contentsOf:[ELSwift.GET, 0x01, 0xD6, 0x00])
                    let groupSendContent = Data(msg)  // .data(using: .utf8)
                    
                    if( isDebug ) { print("send...UDP") }
                    ELSwift.group.send(content: groupSendContent) { (error)  in
                        if( isDebug ) { print("Send complete with error \(String(describing: error))") }
                    }

                case .waiting(let error):
                    if( isDebug ) { print("waiting") }
                    if( isDebug ) { print(error) }
                case .setup:
                    if( isDebug ) { print("setup") }
                case .cancelled:
                    if( isDebug ) { print("cancelled") }
                case .failed:
                    if( isDebug ) { print("failed") }
                    //case .preparing:
                    //    if( isDebug ) { print("preparing") }
                default:
                    if( isDebug ) { print("default") }
                }
            }
            
            let queue = DispatchQueue(label: "ECHONETNetwork")
            //if( isDebug ) { print(group.isUnicastDisabled) }
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
            
        }catch {
            throw error
        }
        
        
    }
    
    public static func release () {
        if( isDebug ) { print("ELSwift.release()") }
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
            if( isDebug ) { print("receiveMessage") }
            if let data = data {
                let receiveData = [UInt8](data)
                if( isDebug ) { print(receiveData) }
                if( isDebug ) { print(flag) }
                if(flag == false) {
                    ELSwift.receive(nWConnection: nWConnection)
                }
            }
            else {
                if( isDebug ) { print("receiveMessage data nil") }
            }
        })
    }
    
    //---------------------------------------
    // 表示系
    // let detail = elsv.DETAIL.map{ String($0, radix:16) }
    public static func printUInt8Array(_ array: [UInt8]) throws -> Void {
        let p = array.map{ String( format: "%02X", $0) }
        if( isDebug ) { print( p ) }
    }
    
    public static func printPDCEDT(_ pdcedt:T_PDCEDT) throws -> Void {
        let pdc = String( format: "%02X", pdcedt[0] )
        let edt = pdcedt[1...].map{ String( format: "%02X", $0) }
        if( isDebug ) { print( "PDC:\(pdc), EDT:\(edt)" ) }
    }
    
    public static func printDetails(_ details:T_DETAILs) throws -> Void {
        for( epc, edt ) in details {
            let pdc = String( format: "%02X", edt.count )
            let edt = edt.map{ String( format: "%02X", $0)}
            let _epc = String( format: "%02X", epc)
            if( isDebug ) { print( "EPC:\(_epc), PDC:\(pdc), EDT:\(edt)" ) }
        }
    }
    
    public static func printEL_STRUCTURE(_ els: EL_STRUCTURE) throws -> Void {
        let seoj = els.SEOJ.map{ String( format: "%02X", $0)}
        let deoj = els.DEOJ.map{ String( format: "%02X", $0)}
        let esv = String( format: "%02X", els.ESV)
        let opc = String( format: "%02X", els.OPC)
        if( isDebug ) { print( "TID:\(els.TID), SEOJ:\(seoj), DEOJ:\(deoj), ESV:\(esv), OPC:\(opc)") }
        for( epc, edt ) in els.DETAILs {
            let pdc = String( format: "%02X", edt.count)
            let edt = edt.map{ String( format: "%02X", $0 )}
            let _epc = String( format: "%02X", epc )
            if( isDebug ) { print("    EPC:\(_epc), PDC:\(pdc), EDT:\(edt)" ) }
        }
    }
    
    public static func printFacilities() throws -> Void {
        if( isDebug ) { print("==== printFacilities() ====") }
        
        for (ip, objs) in ELSwift.facilities {
            if( isDebug ) { print("ip: \(ip)") }
            
            if let os = objs {
                for (eoj, obj) in os {
                    if( isDebug ) { print("  eoj: \(eoj)") }
                    
                    for (epc, edt) in obj {
                        if( isDebug ) { print("    \(epc) = \(String(describing: edt))") }
                    }
                }
            }
        }
    }
    
    //---------------------------------------
    public static func sendBase(_ toip:String, _ array: [UInt8]) throws -> Void {
        if( isDebug ) {
            print("ELSwift.sendBase(Data) data:")
            try ELSwift.printUInt8Array(array)
        }
        
        let queue = DispatchQueue(label:"sendBase")
        let socket = NWConnection( host:NWEndpoint.Host(toip), port:3610, using: .udp)
        
        // 送信完了時の処理のクロージャ
        let completion = NWConnection.SendCompletion.contentProcessed { error in
            if ( error != nil ) {
                print("sendBase() error: \(String(describing: error))")
            }else{
                if( isDebug ) { print("sendBase() 送信完了") }
                socket.cancel()  // 送信したらソケット閉じる
            }
        }
        
        socket.stateUpdateHandler = { (newState) in
            switch newState {
            case .ready:
                if( isDebug ) { print("Ready to send") }
                // 送信
                socket.send(content: array, completion: completion)
            case .waiting(let error):
                if( isDebug ) { print("\(#function), \(error)") }
            case .failed(let error):
                if( isDebug ) { print("\(#function), \(error)") }
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
        if( isDebug ) { print("ELSwift.sendBase(UInt8)") }
        // 送信
        try ELSwift.sendBase(toip, array )
    }
    
    public static func sendString(_ toip:String,_ message: String) throws -> Void {
        if( isDebug ) { print("ELSwift.sendString()") }
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
        }catch{
            throw error
        }
    }
    
    public static func sendDetails(_ ip:String, _ seoj:[UInt8], _ deoj:[UInt8], _ esv:UInt8, _ DETAILs:T_DETAILs ) throws -> Void {
        // TIDの調整
        ELSwift.increaseTID()
        
        var buffer:[UInt8] = [];
        var opc:UInt8 = 0;
        var pdc:UInt8 = 0;
        var epcpdcedt:T_EPCPDCEDT = []
        
        // detailsがArrayのときはEPCの出現順序に意味がある場合なので、順番を崩さないようにせよ
        for( epc, pdcedt ) in DETAILs {
            print("epc:", epc, "pdcedt:", pdcedt)
            // edtがあればそのまま使う、nilなら[0x00]をいれておく
            if( pdcedt == [] ) {  // [0x00] の時は GetやGet_SNA等で存在する、この時はpdc省略
                epcpdcedt += [epc] + [0x00];
            }else{
                pdc = pdcedt[0];  // 0番がpdc
                let edt:[UInt8] = Array( pdcedt[1...] )
                epcpdcedt += [epc] + [pdc] + edt
            }
            opc += 1;
        }
        
        buffer = ELSwift.EHD + ELSwift.tid + seoj + deoj + [esv] + [opc] + epcpdcedt
        
        // データができたので送信する
        try ELSwift.sendBase(ip, buffer);
    }
    
    
    // elsを送る、TIDはAuto
    public static func sendELS(_ ip:String, _ els:EL_STRUCTURE ) throws -> Void {
        // TIDの調整
        ELSwift.increaseTID()

        // データができたので送信する
        try ELSwift.sendDetails(ip, els.SEOJ, els.DEOJ, els.ESV, els.DETAILs);
    }
    
    //------------ multi send
    public static func sendBaseMulti(_ data: Data)  throws -> Void {
        if( isDebug ) { print("ELSwift.sendBaseMulti(Data)") }
        ELSwift.group.send(content: data) { (error)  in
            print("ELSwift.sendBaseMulti(Data) Send complete with error \(String(describing: error))")
        }
    }
    
    public static func sendBaseMulti(_ msg: [UInt8]) throws -> Void {
        if( isDebug ) { print("ELSwift.sendBaseMulti(UInt8)") }
        // 送信
        let groupSendContent = Data(msg)  // .data(using: .utf8)
        ELSwift.group.send(content: groupSendContent) { (error)  in
            print("ELSwift.sendBaseMulti([UInt8]) Send complete with error \(String(describing: error))")
        }
    }
    
    public static func sendStringMulti(_ message: String) throws -> Void {
        if( isDebug ) { print("ELSwift.sendStringMulti()") }
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
        if( isDebug ) { print("ELSwift.search()") }
        var msg:[UInt8] = ELSwift.EHD + ELSwift.tid + [0x05, 0xff, 0x01] + [0x0e, 0xf0, 0x01 ]
        msg.append(contentsOf: [ELSwift.GET, 0x01, 0xD6, 0x00])
        let groupSendContent = Data(msg)  // .data(using: .utf8)
        ELSwift.group.send(content: groupSendContent) { (error)  in
            print("ELSwift.search() Send complete with error \(String(describing: error))")
        }
    }
    
    // プロパティマップをすべて取得する
    // 一度に一気に取得するとデバイス側が対応できないタイミングもあるようで，適当にwaitする。
    public static func getPropertyMaps(_ ip:String,_ eoj:[UInt8] )
    {
        // プロファイルオブジェクトのときはプロパティマップももらうけど，識別番号ももらう
        if( eoj[0] == 0x0e && eoj[1] == 0xf0 ) {
            
            let els:EL_STRUCTURE = EL_STRUCTURE(tid:[0x00,0x00], seoj:ELSwift.NODE_PROFILE_OBJECT, deoj:eoj, esv:ELSwift.GET, opc:0x04, epcpdcedt:[0x83, 0x00, 0x9d, 0x00, 0x9e, 0x00, 0x9f, 0x00])
            
            sendQueue.addOperations( [CSendTask( ip, els)], waitUntilFinished: false)
            // ELSwift.sendDetails( ip, ELSwift.NODE_PROFILE_OBJECT, eoj, ELSwift.GET, {'83':'', '9d':'', '9e':'', '9f':''})
            
        }else{
            // デバイスオブジェクト
            let els:EL_STRUCTURE = EL_STRUCTURE(tid:[0x00,0x00], seoj:ELSwift.NODE_PROFILE_OBJECT, deoj:eoj, esv:ELSwift.GET, opc:0x03, epcpdcedt:[0x9d, 0x00, 0x9e, 0x00, 0x9f, 0x00])
            
            sendQueue.addOperations( [CSendTask( ip, els)], waitUntilFinished: false)
        }
        
    }
    
    
    //------------ reply
    // dev_details の形式で自分のEPC状況を渡すと、その状況を返答する
    // 例えば下記に001101(温度センサ)の例を示す
    /*
    dev_details: {
        [0x00, 0x11, 0x01]: {
            // super
            0x80: [0x30], // 動作状態, on, get, inf
            0x81: [0x0f], // 設置場所, set, get, inf
            0x82: [0x00, 0x00, 0x50, 0x01],  // spec version, P. rev1, get
            0x83: [0xfe, 0x00, 0x00, 0x77, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06], // identifier, get
            0x88: [0x42], // 異常状態, 0x42 = 異常無, get
            0x8a: [0x00, 0x00, 0x77],  // maker code, kait, get
            0x9d: [0x02, 0x80, 0x81],  // inf map, 1 Byte目は個数, get
            0x9e: [0x01, 0x81],  // set map, 1 Byte目は個数, get
            0x9f: [0x0a, 0x80, 0x81, 0x82, 0x83, 0x88, 0x8a, 0x9d, 0x9e, 0x9f, 0xe0], // get map, 1 Byte目は個数, get
            // detail
            0xe0: [0x00, 0xdc]  // 温度計測値, get
        }
    }
    */

    // dev_detailのGetに対して複数OPCにも対応して返答する
    // rAddress, elsは受信データ, dev_detailsは手持ちデータ
    // 受信したelsを見ながら、手持ちデータを参照してrAddressへ適切に返信する
    public static func replyGetDetail(_ rAddress:String, _ els:EL_STRUCTURE, _ dev_details:T_OBJs ) throws {
        var success:Bool = true
        var retDetailsArray:[UInt8] = []
        var ret_opc:UInt8 = 0
        // console.log( 'Recv DETAILs:', els.DETAILs )
        for ( epc, edt ) in els.DETAILs {  // key=epc, value=edt
            if( ELSwift.replyGetDetail_sub( els, dev_details, epc ) ) {
                retDetailsArray.append( epc )
                retDetailsArray.append( UInt8(edt.count) )
                retDetailsArray += edt
                // console.log( 'retDetails:', retDetails )
            }else{
                // console.log( 'failed:', els.DEOJ, epc )
                retDetailsArray.append( epc )  // epcは文字列なので
                retDetailsArray.append( 0x00 )
                success = false
            }
            ret_opc += 1
        }

        let ret_esv:UInt8 = success ? 0x72 : 0x52  // 一つでも失敗したらGET_SNA
        let el_base:[UInt8] = [(UInt8)(0x10), (UInt8)(0x81)] + els.TID + els.DEOJ + els.SEOJ
        let arr:[UInt8] = el_base + [ret_esv] + [ret_opc] + retDetailsArray
        try ELSwift.sendArray( rAddress, arr )
    }
    
    
    // 上記のサブルーチン
    public static func replyGetDetail_sub(_ els:EL_STRUCTURE, _ dev_details:T_OBJs, _ epc:UInt8) -> Bool {
        guard let obj = dev_details[els.DEOJ] else { // EOJそのものがあるか？
            return false
        }
        
        // console.log( dev_details[els.DEOJ], els.DEOJ, epc );
        if (obj[epc] == nil ) { // EOJは存在し、EPCも持っている
            return false
        }
        return false  // EOJはなある、EPCはない
    }

    // dev_detailのSetに対して複数OPCにも対応して返答する
    // ただしEPC毎の設定値に関して基本はノーチェックなので注意すべし
    // EPC毎の設定値チェックや、INF処理に関しては下記の replySetDetail_sub にて実施
    // SET_RESはEDT入ってない
    // dev_detailsはSetされる
    public static func replySetDetail(_ rAddress:String, _ els:EL_STRUCTURE, _ dev_details: inout T_OBJs ) throws {
        
        // DEOJが自分のオブジェクトでない場合は破棄
        if dev_details[els.DEOJ] != nil { // EOJそのものがあるか？
            return
        }

        var success:Bool = true
        var retDetailsArray:[UInt8] = []
        var ret_opc:UInt8 = 0
        // console.log( 'Recv DETAILs:', els.DETAILs )
        // key=epc, value=pdcedt
        for (epc, edt) in els.DETAILs {
            if( try ELSwift.replySetDetail_sub( rAddress, els, &dev_details, epc ) ) {
                retDetailsArray.append( epc )  // epcは文字列
                retDetailsArray.append( 0x00 )  // 処理できた分は0を返す
            }else{
                retDetailsArray.append( epc )  // epcは文字列なので
                retDetailsArray.append( (UInt8)(edt.count) )  // 処理できなかった部分は要求と同じ値を返却
                retDetailsArray += edt
                success = false
            }
            ret_opc += 1
        }

        if( els.ESV == ELSwift.SETI ) { return }  // SetIなら返却なし

        // SetCは SetC_ResかSetC_SNAを返す
        let ret_esv:UInt8 = success ? 0x71 : 0x5  // 一つでも失敗したらSETC_SNA
        let el_base:[UInt8] = [(UInt8)(0x10), (UInt8)(0x81)] + els.TID + els.DEOJ + els.SEOJ
        let arr:[UInt8] = el_base + [ret_esv] + [ret_opc] + retDetailsArray
        try ELSwift.sendArray( rAddress, arr )
    }
    
    
    // 上記のサブルーチン
    // dev_detailsはSetされる
    public static func replySetDetail_sub(_ rAddress:String, _ els:EL_STRUCTURE, _ dev_details: inout T_OBJs, _ epc:UInt8) throws -> Bool{
        guard let edt:[UInt8] = els.DETAILs[epc] else {  // setされるべきedtの有無チェック
            return false
        }
        
        var ret:Bool = false
       
        
        switch( Array(els.DEOJ[0...1]) ) {
        case ELSwift.NODE_PROFILE: // ノードプロファイルはsetするものがbfだけ
            switch( epc ) {
            case 0xbf: // 個体識別番号, 最上位1bitは変化させてはいけない。
                let ea = edt;
                dev_details[els.DEOJ]![epc] = [ ((ea[0] & 0x7F) | (dev_details[els.DEOJ]![epc]![0] & 0x80)), ea[1] ]
                ret = true
                break
                
            default:
                ret = false
                break
            }
            break
            
        case [0x01, 0x30]: // エアコン
            switch (epc) { // 持ってるEPCのとき
                // super
            case 0x80:  // 動作状態, set, get, inf
                if( edt == [0x30] || edt == [0x31] ) {
                    dev_details[els.DEOJ]![epc] = edt
                    try ELSwift.sendOPC1( ELSwift.EL_Multi, els.DEOJ, els.SEOJ, ELSwift.INF, epc, edt );  // INF
                    ret = true
                }else{
                    ret = false
                }
                break
                
            case 0x81:  // 設置場所, set, get, inf
                dev_details[els.DEOJ]![epc] = edt;
                try ELSwift.sendOPC1( ELSwift.EL_Multi, els.DEOJ, els.SEOJ, ELSwift.INF, epc, edt )  // INF
                ret = true
                break
                
                // detail
            case 0x8f: // 節電動作設定, set, get, inf
                if( edt == [0x41] || edt == [0x42] ) {
                    dev_details[els.DEOJ]![epc] = edt
                    try ELSwift.sendOPC1( ELSwift.EL_Multi, els.DEOJ, els.SEOJ, ELSwift.INF, epc, edt )  // INF
                    ret = true
                }else{
                    ret = false
                }
                break
                
            case 0xb0: // 運転モード設定, set, get, inf
                switch( edt ) {
                    // 40その他, 41自動, 42冷房, 43暖房, 44除湿, 45送風
                case [0x40], [0x41], [0x42], [0x43], [0x44], [0x45]: // 送風
                    dev_details[els.DEOJ]![epc] = edt
                    try ELSwift.sendOPC1( ELSwift.EL_Multi, els.DEOJ, els.SEOJ, ELSwift.INF, epc, edt )  // INF
                    ret = true
                    break
                    
                default:
                    ret = false
                }
                break
                
            case 0xb3: // 温度設定, set, get
                if( 0x00 <= edt[0] && edt[0] <= 0x32 ) {  // 0x00=0, 0x32=50
                    dev_details[els.DEOJ]![epc] = [edt[0]]
                    ret = true
                }else{
                    ret = false
                }
                break
                
            case 0xa0: // 風量設定, set, get, inf
                switch( edt ) {
                    // 0x31..0x38の8段階
                    // 0x41 自動
                case [0x31],  [0x32], [0x33], [0x34], [0x35], [0x36], [0x37], [0x38], [0x41]:
                    dev_details[els.DEOJ]![epc] = edt
                    try ELSwift.sendOPC1( ELSwift.EL_Multi, els.DEOJ, els.SEOJ, ELSwift.INF, epc, edt );  // INF
                    ret = true
                    break
                default:
                    // EDTがおかしい
                    ret = false
                }
                break
                
            default: // 持っていないEPCやset不可能のとき
                if (dev_details[els.DEOJ]![epc] == nil) { // EOJは存在し、EPCも持っている
                    ret = false  // EOJはなある、EPCはない
                }else{
                    ret = true
                }
            }
            break
            
            
        default:  // 詳細を作っていないオブジェクトの一律処理
            if (dev_details[els.DEOJ]![epc] == nil) { // EOJは存在し、EPCも持っている
                ret = false  // EOJはなある、EPCはない
            }else{
                ret = true
               
            }
        }

        return ret
    }
    
    
    //////////////////////////////////////////////////////////////////////
    // 変換系
    //////////////////////////////////////////////////////////////////////
    
    // Detailだけをparseする，内部で主に使う
    public static func parseDetail(_ opc:UInt8, _ epcpdcedt:T_EPCPDCEDT ) throws -> T_DETAILs {
        do{
            var ret: T_DETAILs = T_DETAILs() // 戻り値用，連想配列
            
            var now:Int = 0  // 現在のIndex
            var epc:UInt8 = 0
            var pdc:UInt8 = 0
            
            if( isDebug ) {
                print("ELSwift.parseDetail() opc:", opc, "pdcedt:")
                try ELSwift.printUInt8Array(epcpdcedt)
            }
            
            // OPCループ
            for _ in (0 ..< opc ) {
                // EPC（機能）
                epc = epcpdcedt[now]
                now += 1
                
                // PDC（EDTのバイト数）
                pdc = epcpdcedt[now]
                now += 1
                
                var edt:[UInt8] = []  // edtは初期化しておく
                
                // getの時は pdcが0なのでなにもしない，0でなければ値が入っている
                if( pdc == 0 ) {
                    ret[ epc ] = [] // 本当はnilを入れたい
                } else {
                    // PDCループ
                    for _ in ( 0..<pdc ) {
                        // 登録
                        edt += [ epcpdcedt[now] ]
                        now += 1
                    }
                    // if( isDebug ) { print("opc: \(opc), epc:\(epc), pdc:\(pdc), edt:\(edt)") }
                    ret[ epc ] = edt
                }
                
            }  // opcループ
            
            return ret
        }catch{
            print("ELSwift.parseDetail() error:", error)
            throw error
        }
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
                print( "ELSwift.parseBytes() error: bytes is less then 14 bytes. bytes.count is \(bytes.count)" )
                try ELSwift.printUInt8Array( bytes )
                throw ELError.BadReceivedData
            }
            
            // 数値だったら文字列にして
            var str:String = ""
            
            for i in (0..<bytes.count) {
                str += ELSwift.toHexString( bytes[i] )
            }
            
            // 文字列にしたので，parseStringで何とかする
            return ( try ELSwift.parseString(str) )
        } catch {
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
            eldata.EPCPDCEDT = try ELSwift.toHexArray( try ELSwift.substr( str, 24, UInt(str.utf8.count - 24) ) )
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
        //        if( ELSwift.ignoreMe ? ELSwift.myIPaddress(rinfo) : false ) {
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
            
            if( isDebug ) {
                print("ELSwift.returner() els:")
                try ELSwift.printEL_STRUCTURE(els)
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
                     ELSwift.sendDetails( rinfo, ELSwift.NODE_PROFILE_OBJECT, els.SEOJ, ELSwift.GET, { [epc]:'' } )
                     ELSwift.decreaseWaitings()
                     }, ELSwift.autoGetDelay * (ELSwift.autoGetWaitings+1))
                     ELSwift.increaseWaitings()
                     }
                     }
                     */
                    /*
                     if(  ELSwift.autoGetProperties ) {
                     for( let epc in els.DETAILs ) {
                    let els:EL_STRUCTURE = EL_STRUCTURE(tid:[0x00,0x00], seoj:ELSwift.NODE_PROFILE_OBJECT, deoj:els.SEOJ, esv:ELSwift.GET, opc:0x03, detail:details)
                    
                    sendQueue.addOperations( [CSendTask( rAddress, els)], waitUntilFinished: false)
                     }
                     }
                     */
                    break
                    
                case ELSwift.INF_SNA:    // "53"
                    break
                    
                case ELSwift.SETGET_SNA: // "5e"
                    // console.log( "ELSwift.returner: get error" )
                    // console.dir( els )
                    break
                    
                    ////////////////////////////////////////////////////////////////////////////////////
                    // 0x6x
                case ELSwift.SETI: // "60
                    var obj: T_OBJs = T_OBJs()
                    obj[ [0x0e, 0xf0, 0x01] ] = ELSwift.Node_details
                    try ELSwift.replySetDetail( rAddress, els, &obj )
                    break;
                    
                case ELSwift.SETC: // "61"
                    var obj: T_OBJs = T_OBJs()
                    obj[ [0x0e, 0xf0, 0x01]] = ELSwift.Node_details
                    try ELSwift.replySetDetail( rAddress, els, &obj )
                    break
                    
                case ELSwift.GET: // 0x62
                    // console.log( "ELSwift.returner: get prop. of Node profile els:", els)
                    var obj: T_OBJs = T_OBJs()
                    obj[ [0x0e, 0xf0, 0x01] ] = ELSwift.Node_details
                    try ELSwift.replyGetDetail( rAddress, els, obj )
                    break
                    
                case ELSwift.INF_REQ: // 0x63
                    if ( els.DETAILs[0xd5] == [0x00] ) {  // EL ver. 1.0以前のコントローラからサーチされた場合のレスポンス
                        // console.log( "ELSwift.returner: Ver1.0 INF_REQ.")
                        try ELSwift.sendOPC1Multi(ELSwift.NODE_PROFILE_OBJECT, els.SEOJ, ELSwift.INF, 0xd5, ELSwift.Node_details[0xd5]!)
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
                        // console.log('ELSwift.SET_RES: autoGetProperties')
                        /*
                         ELSwift.sendDetails( rinfo, ELSwift.NODE_PROFILE_OBJECT, els.SEOJ, ELSwift.GET, details )
                         */
                        /*
                         let els:EL_STRUCTURE = EL_STRUCTURE(tid:[0x00,0x00], seoj:ELSwift.NODE_PROFILE_OBJECT, deoj:els.SEOJ, esv:ELSwift.GET, opc:0x03, detail:details)
                         
                         sendQueue.addOperations( [CSendTask( rAddress, els)], waitUntilFinished: false)
                         */
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
                    if ( Array(els.SEOJ[0..<2]) == ELSwift.NODE_PROFILE)  {
                        if let array:T_PDCEDT = els.DETAILs[0xd6] {
                            // console.log( "ELSwift.returner: get object list! PropertyMap req V1.0.")
                            // 自ノードインスタンスリストSに書いてあるオブジェクトのプロパティマップをもらう
                            var instNum:Int = Int( array[0] ) // 0番目はPDC, indexに使うのでIntにする
                            while( 0 < instNum ) {
                                let begin:Int =  ( instNum - 1) * 3 + 1
                                let end:Int = ( instNum - 1) * 3 + 4
                                let obj:[UInt8] = Array( array[  begin ..< end  ] )
                                ELSwift.getPropertyMaps( rAddress, obj )
                                if( isDebug ) { print("-> ELSwift.GET_SNA, GET_RES", rAddress, obj) }
                                instNum -= 1
                            }
                        }
                    }
                    
                    // 9f(GetPropertyMap)を受け取ったら、それらを全プロパティを取得する
                    if let array:T_PDCEDT = els.DETAILs[0x9f]  {  // 自動プロパティ取得は初期化フラグ, 9fはGetProps. 基本的に9fは9d, 9eの和集合になる。(そのような決まりはないが)
                        // DETAILsは解析後なので，format 1も2も関係なく処理する
                        // EPC取れるだけ一気にとる方式に切り替えた(ver.2.12.0以降)
                        if( array == [] ) {  // GET_SNAの時など、EDT = []の時がある
                            break
                        }
                        var details:[UInt8] = []
                        let num:Int = Int( array[0] )
                        var i = 0
                        while i < num {
                            // d6, 9d, 9e, 9fはサーチの時点で取得しているはずなので取得しない
                            // 特にd6と9fは取り直すと無限ループするので注意
                            if( array[i+1] != 0xd6 && array[i+1] != 0x9d && array[i+1] != 0x9e && array[i+1] != 0x9f ) {
                                details.append( array[i+1] )
                                details.append( 0x00 )
                            }
                            i += 1
                        }
                        

                        // let els:EL_STRUCTURE = EL_STRUCTURE( tid:nil, seoj:ELSwift.NODE_PROFILE_OBJECT, deoj:els.SEOJ, esv:ELSwift.GET, opc:0x03, detail:details)
                        // sendQueue.addOperations( [CSendTask( rAddress, els)], waitUntilFinished: false)

                        // old try ELSwift.sendDetails( rAddress, ELSwift.NODE_PROFILE_OBJECT, els.SEOJ, ELSwift.GET, details)
                    }
                    break
                    
                case ELSwift.INF:  // 0x73
                    // ECHONETネットワークで、新規デバイスが起動したのでプロパティもらいに行く
                    // autoGetPropertiesがfalseならやらない
                    if( els.DETAILs[0xd5] != nil && els.DETAILs[0xd5] != []  && ELSwift.autoGetProperties) {
                        // ノードプロファイルオブジェクトのプロパティマップをもらう
                        ELSwift.getPropertyMaps( rAddress, ELSwift.NODE_PROFILE_OBJECT )
                        if( isDebug ) { print("-> ELSwift.INF", rAddress, ELSwift.NODE_PROFILE_OBJECT) }
                    }
                    break
                    
                case ELSwift.INFC: // "74"
                    // ECHONET Lite Ver. 1.0以前の処理で利用していたフロー
                    // オブジェクトリストをもらったらそのオブジェクトのPropertyMapをもらいに行く
                    // autoGetPropertiesがfalseならやらない
                    if(ELSwift.autoGetProperties ) {
                        if let array:T_PDCEDT = els.DETAILs[0xd5] {
                            // ノードプロファイルオブジェクトのプロパティマップをもらう
                            ELSwift.getPropertyMaps( rAddress, ELSwift.NODE_PROFILE_OBJECT )
                            if( isDebug ) {
                                print("-> ELSwift.INFC rAddress:", rAddress, " obj:", ELSwift.NODE_PROFILE_OBJECT )
                            }
                            
                            // console.log( "ELSwift.returner: get object list! PropertyMap req.")
                            var instNum:Int = Int( array[0] )
                            while( 0 < instNum ) {
                                let begin:Int = (instNum - 1) * 3 + 1
                                let end:Int = (instNum - 1) * 3 + 4
                                let obj:[UInt8] = Array( array[  begin ..< end  ] )
                                ELSwift.getPropertyMaps( rAddress, obj )
                                if( isDebug ) {
                                    print("-> ELSwift.INF rAddress:", rAddress)
                                    try ELSwift.printUInt8Array(obj)
                                }
                                
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
                if( isDebug ) {
                    print("-> ELSwift.INF rAddress:", rAddress)
                    try ELSwift.printEL_STRUCTURE(els)
                }
                try ELSwift.renewFacilities(rAddress, els)
            }
            
            // 機器オブジェクトに関してはユーザー関数に任す
            if( isDebug ) {
                print("-> ELSwift.userFunc", rAddress)
                try ELSwift.printEL_STRUCTURE(els)
            }
            ELSwift.userFunc!(rAddress, els, nil)
        } catch {
            if( isDebug ) {
                print("-> Error: ELSwift.userFunc", rAddress, content!, error) }
            ELSwift.userFunc!(rAddress, nil, error)
        }
    }
    
    // ネットワーク内のEL機器全体情報を更新する，受信したら勝手に実行される
    public static func renewFacilities(_ address:String, _ els:EL_STRUCTURE) throws -> Void {
        do {
            let epcList:T_DETAILs = try ELSwift.parseDetail(els.OPC, els.EPCPDCEDT);
            let seoj = els.SEOJ
            
            // 新規IP
            if ( ELSwift.facilities[address] == nil ) { //見つからない
                ELSwift.facilities[address] = T_OBJs()
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
            print("ELSwift.renewFacilities() error:", error)
            // console.dir(e);
            throw error;
        }
    }
    
    
}
