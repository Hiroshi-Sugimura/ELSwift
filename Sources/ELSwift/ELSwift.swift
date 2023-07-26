/// ECHONET Lite protocol for Swift
///
/// ECHONET Lite is a open protocol for IoT and Smart home.
///
/// Copyright (c) 2023.07.11 SUGIMURA Hiroshi


//==============================================================================
import Foundation
import Network
import SystemConfiguration

//==============================================================================
/// PDCのあとEDTがくる
/// PDCは必ず1Byteなので PDC = T_PDCEDT[0]
/// [EDT]は1Byteだけのプロパティでも配列でアクセス
public typealias T_PDCEDT     = [UInt8]

///EPC, PDC, EDT の順序
///EPC, PDCは必ず1Byteなので EPC = T_EPCPDCEDT[0], PDC = T_EPCPDCEDT[1]
public typealias T_EPCPDCEDT  = [UInt8]

/// プロパティ郡を辞書として管理する
/// キーはUInt8なので、規格書のEPCの値をそのまま使える
/// T_DETAILs[0x80] = T_PDCEDT のようになる
public typealias T_DETAILs = Dictionary<UInt8, T_PDCEDT>

/// 複数オブジェクト郡を辞書として管理する
/// キーは[UInt8]で、3Byteとし、EOJをそのまま利用する。Arrayのままキーとする。
/// T_OBJs[ [0x05, 0xff, 0x01] ] = T_DETAILs のようになる
public typealias T_OBJs    = Dictionary<[UInt8], T_DETAILs>   // [eoj]: T_DETAILs

/// 複数デバイス郡を辞書として管理する
/// キーはStringで、IPアドレスで管理する。
/// T_DEVs[ "192.168.xx.xx" ] = T_OBJs のようになる
/// 注意点として、同じデバイスでも複数IPを持つ場合があり、その場合この辞書からは複数デバイスに見える。
/// きちんと管理するなら機器IDを取得して名寄せする必要がある。
public typealias T_DEVs    = Dictionary<String, T_OBJs>   // "ip": T_OBJs


//==============================================================================
/// ECHONET Lite 解析構造体
public struct EL_STRUCTURE : Equatable{
    /// EHD = [EHD1:UInt8,  EHD2:UInt8]
    public var EHD : [UInt8]
    /// TID = [UInt8, UInt8, UInt8]
    public var TID : [UInt8]
    /// SEOJ = [ClassGroup:UInt8, ClassCode:UInt8, InstanceNo.:UInt8]
    public var SEOJ : [UInt8]
    /// SEOJ = [ClassGroup:UInt8, ClassCode:UInt8, InstanceNo.:UInt8]
    public var DEOJ : [UInt8]
    /// EDATA = [ESV:UInt8, OPC:UInt8] + EPCPDCEDT
    /// EDATAの詳細としてESV、OPC、EPCPDCEDTと分割したデータがある
    public var EDATA: [UInt8]
    /// ESV = ECHONET Service
    public var ESV : UInt8
    /// OPC = [UInt8]
    public var OPC : UInt8
    /// EPCPDCEDT = [EPC:UInt8, PDC:UInt8] + EDT:[UInt8]
    public var EPCPDCEDT : T_EPCPDCEDT
    /// DETAILs = Dictionary型、 key = EPC:UInt8, value = [EDT:UInt8]
    public var DETAILs : T_DETAILs
    
    /// 初期化
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
    
    /// 初期値付き初期化
    /// - Parameters:
    ///   - tid: Transaction ID
    ///   - seoj: Send ECHONET Object
    ///   - deoj: Dest ECHONET Object
    ///   - esv: ECHONET Service
    ///   - opc: parameter counter
    ///   - epcpdcedt: EPC, PDC, EDT
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
            print("Error!! ELSwift - EL_STRUCTURE.init() error:", error)
            DETAILs = T_DETAILs()
        }
    }
}

//==============================================================================
/// timer queue用のOperation class
/// 内部クラス
class CSendTask: Operation {
    /// 送信先IPアドレス
    let address: String
    /// 送信するEL_STRUCTUREデータ
    let els: EL_STRUCTURE
    
    /// 初期化
    /// - Parameters:
    ///   - _address: 送信先アドレス
    ///   - _els: 送信データ
    init(_ _address: String, _ _els: EL_STRUCTURE) {
        self.address = _address
        self.els = _els
        // print("CSendTask.init()")
        // ELSwift.printEL_STRUCTURE(els)
    }
    
    /// Queueで実行するタスク
    override func main () {
        if isCancelled {
            return
        }
        
        // スレッドを2秒止める
        Thread.sleep(forTimeInterval: 2)
        
        do{
            try ELSwift.sendELS(address, els)
        }catch{
            print("Error!! ELSwift - CSendTask.main()", els)
        }
    }
}


//==============================================================================
// Network Object

/// Networkをモニタする。
/// 内部オブジェクト、WiFiの切り替えとか検知できる？
struct NetworkMonitor {
    static let monitor = NWPathMonitor()
    static var connection = true
}


/// ELSwiftでの例外
enum ELError: Error {
    case BadNetwork
    case BadString(String)
    case BadReceivedData
    case other(String)
}


//==============================================================================
/// the main class for ELSwift, ECHONET Lite protocol
/// ELSwift is available for only one object for an app. Multi object cannot exist.
public class ELSwift {
    /// ネットワークタイプ
    /// 内部プロパティ
    public static let networkType = "_networkplayground._udp."
    /// ネットワークドメイン
    /// 内部プロパティ
    public static let networkDomain = "local"
    /// ECHONET用の受信ポート、3610で固定
    /// 内部プロパティ
    public static let PORT:UInt16 = 3610
    /// ECHONET用の受信ポート、3610で固定
    /// 内部プロパティ
    public static let EL_port:Int = 3610
    /// ECHONET Liteのデータヘッダ、[0x10, 0x81]で固定
    /// 内部プロパティ
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

    /// ECHONET用のマルチキャストIPv4アドレス、224.0.23.0で固定
    public static let EL_Multi:String = "224.0.23.0"
    /// ECHONET用のマルチキャストIPv4アドレス、224.0.23.0で固定
    public static let MULTI_IP: String = "224.0.23.0"
    /// ECHONET用のマルチキャストIPv4アドレス、224.0.23.0で固定
    public static let MultiIP: String = "224.0.23.0"
    /// ECHONET用のマルチキャストIPv6アドレス、FF02::1で固定
    public static let EL_Multi6:String = "FF02::1"

    /// Class
    public static let NODE_PROFILE_CLASS: [UInt8] = [0x0e, 0xf0]
    /// Object
    public static let NODE_PROFILE_OBJECT: [UInt8] = [0x0e, 0xf0, 0x01]
    /// ECHONETネットワークで通信済みのデータを保持
    public static var facilities: Dictionary<String, T_OBJs> = Dictionary<String, T_OBJs>()
    
    /// 受信データの処理、ユーザが指定するコールバック関数
    /// 内部プロパティ
    static var userFunc : ((_ rAddress:String, _ els: EL_STRUCTURE?, _ err: Error?) -> Void)? = {_,_,_ in }
    
    static var EL_obj: [UInt8]!
    static var EL_cls: [UInt8]!
    
    /// 自身のプロパティ
    public static var Node_details:T_DETAILs = T_DETAILs()
    

    ///送信時のTID自動設定用
    ///内部プロパティ
    public static var tid:[UInt8] = [0x00, 0x01]

    /// Listener
    /// 内部プロパティ
    private static var group: NWConnectionGroup!
    
    /// 初期化し、送受信開始済み
    /// ソフトウェアライフサイクルで利用するつもりだが未実装
    static var isReady: Bool = false
    public static var listening: Bool = true
    /// 受信データ処理をマルチスレッドで実施するためのディスパッチキュー
    static var queue = DispatchQueue.global(qos: .userInitiated)

    /// initialize option: デバッグログ出力設定
    static var isDebug: Bool = false
    /// initialize option: 通信IPバージョン設定（ただし切り替え機能は未実装）
    /// 0 = IPv4 and IPv6, 4= IPv4, 6: IPv6
    static var ipVer: Int = 0
    /// initialize option: 自動プロパティ取得設定
    public static var autoGetProperties: Bool = true
    /// initialize option: 自動プロパティ取得設定ONのときの、プロパティ取得ディレイ（未実装）
    public static var autoGetDelay : Int = 1000

    /// 短期連続送信しないための送信キュー
    static let sendQueue = OperationQueue()
    
    /// ELSwift initializer
    /// - Parameters:
    ///   - objList: e.g.: [0x05, 0xff, 0x01]
    ///   - callback:use's callback function, For receiving message, the callback is called.
    ///   - option:options, nil or fill all.
    /// - Returns: Void
    public static func initialize(_ objList: [UInt8], _ callback: @escaping ((_ rAddress:String, _ els: EL_STRUCTURE?, _ error: Error?) -> Void), option: (debug:Bool, ipVer:Int, autoGetProperties:Bool)? = nil ) throws -> Void {
        do{
            Self.isDebug = option?.debug ?? false
            // 正しいオブジェクトリストのチェック
            if( 1 < objList.count && objList.count % 3 != 0 ) {
                print("ELSwift.initialize objList is invalid.")
                return
            }
            
            // 初期設定値
            ipVer = option?.ipVer ?? 0
            autoGetProperties = option?.autoGetProperties ?? true
            
            if( Self.isDebug ) {
                print("===== ELSwift.init() =====")
                print("| ipVer:", ELSwift.ipVer)
                print("| autoGetProperties:", ELSwift.autoGetProperties)
                print("| debug:", Self.isDebug)
            }
            
            // send queue
            sendQueue.name = "net.sugimulab.ELSwift.sendQueue"
            sendQueue.maxConcurrentOperationCount = 1
            sendQueue.qualityOfService = .userInitiated
            
            // 自分のIPを取得したいけど、どうやるんだか謎。
            // 下記でinterfaceリストまでは取れる
            NetworkMonitor.monitor.pathUpdateHandler = { (path : NWPath) in
                if( Self.isDebug ) {
                    print("ELSwift.initialize() NetworkMonitor path:", String(describing: path) )
                }
                
                if path.status == .satisfied {
                    NetworkMonitor.connection = true
                } else {
                    NetworkMonitor.connection = false
                }
            }
            let queue2 = DispatchQueue(label: "Monitor")
            NetworkMonitor.monitor.start(queue: queue2)

            //---- multicast
            guard let multicast = try? NWMulticastGroup(for: [ .hostPort(host: "224.0.23.0", port: 3610)], disableUnicast: false)
            else { fatalError("Error!! ELSwift.initialize() error in Muticast") }

            ELSwift.group = NWConnectionGroup(with: multicast, using: .udp)

            ELSwift.group.setReceiveHandler(maximumMessageSize: 1518, rejectOversizedMessages: true) { (message, content, isComplete) in
                if( Self.isDebug ) {
                    print("ELSwift.initialize() group.setReceiveHandler message:")
                    print("|", String(describing: message))
                    print("ELSwift.initialize() NetworkMonitor:", String(describing: NetworkMonitor.monitor.currentPath.localEndpoint))
                }

                if let ipa = message.remoteEndpoint {
                    let ip_port = ipa.debugDescription.components(separatedBy: ":")
                    ELSwift.returner( ip_port[0], content )
                }else{
                    print("Error!! ELSwift.initiallize() group.setReceiveHandler")
                    print("Error!! | Message doesn't convert to ipa")
                }
                /*
                 do{
                 if( Self.isDebug ) {
                 print("-> content:")
                 try ELSwift.printUInt8Array( [UInt8](content!) )
                 }
                 }catch{
                 print("ELSwift.group.setReceiveHandler() error:", error)
                 }
                 */
            }
            
            ELSwift.group.stateUpdateHandler = { (newState:NWConnectionGroup.State) in
                if( Self.isDebug ) {
                    print("ELSwift.initialize() group.startUpdateHandler newState: \(String(describing: newState))")
                    print("|", String(describing: ELSwift.group))
                    print("ELSwift.initialize() NetworkMonitor:", String(describing: NetworkMonitor.monitor.currentPath))
                }

                switch newState {
                case .ready:
                    // 初期サーチ
                    var msg:[UInt8] = ELSwift.EHD + ELSwift.tid + [0x0e, 0xf0, 0x01] + [0x0e, 0xf0, 0x01 ]
                    msg.append(contentsOf:[ELSwift.GET, 0x01, 0xD6, 0x00])
                    let groupSendContent = Data(msg)  // .data(using: .utf8)
                    
                    // if( Self.isDebug ) { print("send...UDP") }
                    ELSwift.group.send(content: groupSendContent) { (error)  in
                        if( Self.isDebug ) {
                            print("ELSwift.initialize() group.startUpdateHandler Send complete with error \(String(describing: error))") }
                    }
                    
                case .waiting(let error):
                    if( Self.isDebug ) { print("ELSwift.initialize() group.startUpdateHandler waiting") }
                    if( Self.isDebug ) { print("|", error) }
                case .setup:
                    if( Self.isDebug ) { print("ELSwift.initialize() group.startUpdateHandler setup") }
                case .cancelled:
                    if( Self.isDebug ) { print("ELSwift.initialize() group.startUpdateHandler cancelled") }
                case .failed:
                    if( Self.isDebug ) { print("ELSwift.initialize() group.startUpdateHandler failed") }
                    //case .preparing:
                    //    if( Self.isDebug ) { print("preparing") }
                default:
                    if( Self.isDebug ) { print("ELSwift.initialize() group.startUpdateHandler default") }
                }
            }
            
            let queue = DispatchQueue(label: "ECHONETNetwork")
            ELSwift.group.start(queue: queue)
            
            // 送信用ソケットの準備
            EL_obj = objList
            
            var classes:[UInt8] = [UInt8]()
            
            for i in 0 ..< objList.count / 3 {
                let begin = i * 3
                let end = i * 3 + 1
                classes += Array( objList[ begin ... end ] )
            }
            
            EL_cls = classes
            
            // 自分のプロパティリスト（初期値はコントローラとして設定している）
            // super
            Node_details[0x88] = [0x42] // Fault status, get
            Node_details[0x8a] = [0x00, 0x00, 0x77] // maker code, manufacturer code, kait = 00 00 77, get
            Node_details[0x8b] = [0x00, 0x00, 0x02] // business facility code, homeele = 00 00 02, get
            Node_details[0x9d] = [0x02, 0x80, 0xd5] // inf map, 1 Byte目は個数, get
            Node_details[0x9e] = [0x01, 0xbf]       // set map, 1 Byte目は個数, get
            Node_details[0x9f] = [0x0f, 0x80, 0x82, 0x83, 0x88, 0x8a, 0x8b, 0x9d, 0x9e, 0x9f, 0xbf, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7] // get map, 1 Byte目は個数, get
            // detail
            Node_details[0x80] = [0x30] // 動作状態, get, inf
            Node_details[0x82] = [0x01, 0x0d, 0x01, 0x00] // EL version, 1.13, get
            Node_details[0x83] = [0xfe, 0x00, 0x00, 0x77, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01] // identifier, initialize時に、mac addressできちんとユニークの値にセットとよい, get
            Node_details[0xbf] = [0x80, 0x00] // 個体識別情報, Unique identifier data
            Node_details[0xd3] = [0x00, 0x00, UInt8(EL_obj.count/3)]  // 自ノードで保持するインスタンスリストの総数（ノードプロファイル含まない）, initialize時にuser項目から自動計算, get
            Node_details[0xd4] = [0x00, UInt8(EL_cls.count/2 + 1)]        // 自ノードクラス数（ノードプロファイル含む）, initialize時にuser項目から自動計算, D4はノードプロファイルをカウントする(+1), get
            Node_details[0xd5] = [UInt8(EL_obj.count/3)] + EL_obj    // インスタンスリスト通知, 1Byte目はインスタンス数, initialize時にuser項目から自動計算 anno (3 Byteで1 objectなので3で割り算)
            Node_details[0xd6] = Node_details[0xd5]   // 自ノードインスタンスリストS, initialize時にuser項目から自動計算, get
            Node_details[0xd7] = [ UInt8(EL_cls.count/2)] + EL_cls     // 自ノードクラスリストS, initialize時にuser項目から自動計算, get (2 Byteで1 classなので２で割り算)
            
            // 初期化終わったのでノードのINFをだす
            try ELSwift.sendOPC1( EL_Multi, [0x0e,0xf0,0x01], [0x0e,0xf0,0x01], 0x73, 0xd5, Node_details[0xd5]! )
            
            ELSwift.userFunc = callback
            
        }catch {
            throw error
        }
        
    }
    
    
    /// ELSwiftの通信終了
    public static func release () {
        if( Self.isDebug ) { print("ELSwift.release()") }
        group.cancel()
    }
    
    /// ELSwiftの通信しているか？初期化動作済みか？をチェックする
    public static func IsReady() -> Bool {
        if( Self.isDebug ) { print("ELSwift.isReady()") }
        return ELSwift.isReady
    }
    
    /// 内部関数
    /// 自動送信のTIDを１進める
    /// 基本的には内部関数として動作することを念頭に設計
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
    /// 内部関数
    /// 受信データ処理
    public static func receive(nWConnection:NWConnection) -> Void {
        nWConnection.receive(minimumIncompleteLength: 1, maximumLength: 5, completion: { (data, context, flag, error) in
            if( Self.isDebug ) { print("ELSwift.receive() receiveMessage") }
            //if let data = data {
            // let receiveData = [UInt8](data)
            // if( Self.isDebug ) { print(receiveData) }
            // if( Self.isDebug ) { print(flag) }
            if(flag == false) {
                ELSwift.receive(nWConnection: nWConnection)
            }
            //}
            //else {
            //    if( Self.isDebug ) { print("ELSwift.receive() error: receiveMessage data nil") }
            //}
        })
    }
    
    //--------------------------------------- 表示系
    /// 表示系
    /// [UInt8]を１６進数表示する
    /// - Parameter array: 表示する[UInt8]
    public static func printUInt8Array(_ array: [UInt8]) -> Void {
        let p = array.map{ String( format: "%02X", $0) }
        print( p )
    }
    
    /// 変換系
    /// [UInt8]を１６進数表示するための文字列を取得する
    /// - Parameter array: 文字列変換する[UInt8]
    /// - Returns: 変換後の文字列
    public static func printUInt8Array_String(_ array: [UInt8]) -> String {
        let p = array.map{ String( format: "%02X", $0) }
        return  p.joined()
    }
    
    /// 表示系
    /// T_PDCEDT を１６進数でPDCとEDTで分けて表示する
    /// - Parameter pdcedt: 表示するT_PDCEDT
    public static func printPDCEDT(_ pdcedt:T_PDCEDT) -> Void {
        // print("== ELSwift.printPDCEDT()")
        let pdc = String( format: "%02X", pdcedt[0] )
        let edt = pdcedt[1...].map{ String( format: "%02X", $0) }
        print( "PDC:\(pdc), EDT:\(edt)" )
    }
    
    /// 表示系
    /// T_DETAILsを16進数でEPC, PDC, EDTで分けて表示する
    /// - Parameter details: 表示するT_DETAILs
    public static func printDetails(_ details:T_DETAILs) -> Void {
        // print("== ELSwift.printDetails()")
        for( epc, edt ) in details {
            let pdc = String( format: "%02X", edt.count )
            let edt = edt.map{ String( format: "%02X", $0)}
            let _epc = String( format: "%02X", epc)
            print( "EPC:\(_epc), PDC:\(pdc), EDT:\(edt)" )
        }
    }
    
    /// 表示系
    /// EL_STRUCTUREを表示する
    /// - Parameter els: 表示するEL_STRUCTURE
    public static func printEL_STRUCTURE(_ els: EL_STRUCTURE) -> Void {
        // print("== ELSwift.pringEL_STRUCTURE()")
        let seoj = els.SEOJ.map{ String( format: "%02X", $0)}
        let deoj = els.DEOJ.map{ String( format: "%02X", $0)}
        let esv = String( format: "%02X", els.ESV)
        let opc = String( format: "%02X", els.OPC)
        print( "TID:\(els.TID), SEOJ:\(seoj), DEOJ:\(deoj), ESV:\(esv), OPC:\(opc)")
        for( epc, edt ) in els.DETAILs {
            let pdc = String( format: "%02X", edt.count)
            let edt = edt.map{ String( format: "%02X", $0 )}
            let _epc = String( format: "%02X", epc )
            print("    EPC:\(_epc), PDC:\(pdc), EDT:\(edt)" )
        }
    }
    
    /// 表示系
    /// コントローラとして、認識しているデバイス情報（facilities）を表示する
    public static func printFacilities() -> Void {
        print("-- ELSwift.printFacilities() --")
        
        for (ip, objs) in ELSwift.facilities {
            print("- ip: \(ip)")
            
            for (eoj, obj) in objs {
                print("  - eoj: " + ELSwift.printUInt8Array_String(eoj) )
                
                for (epc, edt) in obj {
                    print("    - " + ELSwift.toHexString(epc) + ": " + ELSwift.printUInt8Array_String(edt) )
                }
            }
        }
    }
    
    //---------------------------------------
    /// 送信系
    /// 送信基礎(ほぼ内部関数的に利用)
    /// - Parameter toip: String = 送信先IPアドレス
    /// - Parameter array: [UInt8] = 送信データ
    /// - Throws:Portが確保できないなどの例外
    public static func sendBase(_ toip:String, _ array: [UInt8]) throws -> Void {
        if( Self.isDebug ) {
            print("<- ELSwift.sendBase(Data) data:")
            ELSwift.printUInt8Array(array)
        }
        
        let queue = DispatchQueue(label:"sendBase")
        let socket = NWConnection( host:NWEndpoint.Host(toip), port:3610, using: .udp)
        
        // 送信完了時の処理のクロージャ
        let completion = NWConnection.SendCompletion.contentProcessed { error in
            if ( error != nil ) {
                print("Error!! ELSwift.sendBase() error: \(String(describing: error))")
            }else{
                // if( Self.isDebug ) { print("sendBase() 送信完了") }
                socket.cancel()  // 送信したらソケット閉じる
            }
        }
        
        socket.stateUpdateHandler = { (newState) in
            switch newState {
            case .ready:
                // if( Self.isDebug ) { print("Ready to send") }
                // 送信
                socket.send(content: array, completion: completion)
            case .waiting(let error):
                if( Self.isDebug ) { print("\(#function), \(error)") }
            case .failed(let error):
                if( Self.isDebug ) { print("\(#function), \(error)") }
            case .setup: break
            case .cancelled: break
            case .preparing: break
            @unknown default:
                fatalError("ELSwift.sendBase() Illegal state")
            }
        }
        
        socket.start(queue:queue)
    }
    
    /// 送信系
    public static func sendBase(_ toip:String,_ data: Data) throws -> Void {
        if( Self.isDebug ) { print("<- ELSwift.sendBase(Data)") }
        let msg:[UInt8] = [UInt8](data)
        try ELSwift.sendBase(toip, msg)
    }
    
    /// 送信系
    public static func sendArray(_ toip:String,_ array: [UInt8]) throws -> Void {
        if( Self.isDebug ) { print("<- ELSwift.sendBase(UInt8)") }
        // 送信
        try ELSwift.sendBase(toip, array )
    }
    
    /// 送信系
    public static func sendString(_ toip:String,_ message: String) throws -> Void {
        if( Self.isDebug ) { print("<- ELSwift.sendString()") }
        // 送信
        let data = try ELSwift.toHexArray(message)
        try ELSwift.sendBase( toip, data )
    }
    
    /// 送信系
    /// - Parameters:
    ///   - ip:
    ///   - seoj
    ///   - deoj:
    ///   - esv:
    ///   - epc:
    ///   - edt:
    /// - Throws:
    /// note: sendOPC1(  destIP, [0x05,0xff,0x01], [0x01,0x35,0x01], 0x62, 0x80, [0x00])
    public static func sendOPC1(_ ip:String, _ seoj:[UInt8], _ deoj:[UInt8], _ esv: UInt8, _ epc: UInt8, _ edt:[UInt8]) throws -> Void{
        if( Self.isDebug ) { print("<- ELSwift.sendOPC1(...)") }
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
    
    /// 送信系
    public static func sendDetails(_ ip:String, _ seoj:[UInt8], _ deoj:[UInt8], _ esv:UInt8, _ DETAILs:T_DETAILs ) throws -> Void {
        if( Self.isDebug ) { print("<- ELSwift.sendDetails(...)") }
        // TIDの調整
        ELSwift.increaseTID()
        
        var buffer:[UInt8] = [];
        var opc:UInt8 = 0;
        var pdc:UInt8 = 0;
        var epcpdcedt:T_EPCPDCEDT = []
        
        // detailsがArrayのときはEPCの出現順序に意味がある場合なので、順番を崩さないようにせよ
        for( epc, pdcedt ) in DETAILs {
            // print("epc:", epc, "pdcedt:", pdcedt)
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
    
    /// 送信系
    /// elsを送る、TIDはAuto
    /// 内部的にCSendTaskで使っているので、修正時には注意
    public static func sendELS(_ ip:String, _ els:EL_STRUCTURE ) throws -> Void {
        if( Self.isDebug ) { print("<- ELSwift.sendELS(els)") }
        
        ELSwift.increaseTID()
        
        // データができたので送信する
        try ELSwift.sendDetails(ip, els.SEOJ, els.DEOJ, els.ESV, els.DETAILs);
    }

    /// 非同期 送信系
    /// elsを送る、TIDはAuto
    /// CSendTaskに登録する
    public static func sendAsyncELS(_ ip:String, _ els:EL_STRUCTURE ) throws -> Void {
        if( Self.isDebug ) { print("<- ELSwift.sendAsyncELS(els)") }

        sendQueue.addOperations( [CSendTask( ip, els)], waitUntilFinished: false)
    }
    
    /// 非同期 送信系
    ///  OPCが１のタイプ
    public static func sendAsyncOPC1(_ toip:String, _ seoj:[UInt8], _ deoj:[UInt8], _ esv: UInt8, _ epc: UInt8, _ edt:[UInt8]) -> Void {
        if( Self.isDebug ) { print("<- ELSwift.sendAsyncOPC1(...)") }
        var epcpdcedt : [UInt8] = [UInt8]()
        
        if( esv == ELSwift.GET ) { // getはpdc:0、edt無し
            epcpdcedt = [epc, 0x00]
        }else{
            epcpdcedt = [epc] + [UInt8(edt.count)] + edt
        }
        
        let els : EL_STRUCTURE = EL_STRUCTURE( tid:[0x00,0x00], seoj:seoj, deoj:deoj, esv:esv, opc:0x01, epcpdcedt: epcpdcedt )

        // データができたので送信する
        sendQueue.addOperations( [CSendTask( toip, els)], waitUntilFinished: false)
    }

    /// 非同期 送信系
    ///  OPCが１以外で柔軟に送信データ作りたいタイプ
    public static func sendAsyncArray(_ toip:String, _ array:[UInt8]) throws -> Void {
        if( Self.isDebug ) { print("<- ELSwift.sendAsyncArray(...)") }
        
        let els:EL_STRUCTURE = try ELSwift.parseBytes(array)

        // データができたので送信する
        sendQueue.addOperations( [CSendTask( toip, els)], waitUntilFinished: false)
    }

    
    //------------ multi send
    /// 送信系
    public static func sendBaseMulti(_ data: Data)  throws -> Void {
        if( Self.isDebug ) { print("<= ELSwift.sendBaseMulti(Data)") }
        ELSwift.group.send(content: data) { (error)  in
            if( error != nil ) {
                print("Error!! ELSwift.sendBaseMulti(Data) Send complete with error: \(String(describing: error))")
            }
        }
    }
    
    /// 送信系
    public static func sendBaseMulti(_ msg: [UInt8]) throws -> Void {
        if( Self.isDebug ) { print("<= ELSwift.sendBaseMulti(UInt8)") }
        // 送信
        let groupSendContent = Data(msg)  // .data(using: .utf8)
        ELSwift.group.send(content: groupSendContent) { (error)  in
            if( error != nil ) {
                print("Error!! ELSwift.sendBaseMulti([UInt8]) Send complete with error: \(String(describing: error))")
            }
        }
    }
    
    /// 送信系
    public static func sendStringMulti(_ message: String) throws -> Void {
        if( Self.isDebug ) { print("<= ELSwift.sendStringMulti()") }
        // 送信
        let data = try ELSwift.toHexArray(message)
        try ELSwift.sendBaseMulti( data )
    }
    
    /// 送信系
    public static func sendOPC1Multi(_ seoj:[UInt8], _ deoj:[UInt8], _ esv: UInt8, _ epc: UInt8, _ edt:[UInt8]) throws -> Void{
        if( Self.isDebug ) { print("<= ELSwift.sendOPC1Multi()") }
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
    
    /// 送信系
    public static func search() throws -> Void {
        if( Self.isDebug ) { print("<= ELSwift.search()") }
        var msg:[UInt8] = ELSwift.EHD + ELSwift.tid + [0x0e, 0xf0, 0x01] + [0x0e, 0xf0, 0x01 ]
        msg.append(contentsOf: [ELSwift.GET, 0x01, 0xD6, 0x00])
        let groupSendContent = Data(msg)  // .data(using: .utf8)
        ELSwift.group.send(content: groupSendContent) { (error)  in
            if( error != nil ) {
                print("Error!! ELSwift.search() Send complete with error: \(String(describing: error))")
            }
        }
    }
    
    /// 送信系
    // プロパティマップをすべて取得する
    // 一度に一気に取得するとデバイス側が対応できないタイミングもあるようで，適当にwaitする。
    public static func getPropertyMaps(_ ip:String,_ eoj:[UInt8] )
    {
        if( Self.isDebug ) {
            print("<- ELSwift.getPropertyMaps() rAddress:", ip, "obj:", ELSwift.printUInt8Array_String(eoj) )
        }
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
    
    /// 送信系
    // dev_detailのGetに対して複数OPCにも対応して返答する
    // rAddress, elsは受信データ, dev_detailsは手持ちデータ
    // 受信したelsを見ながら、手持ちデータを参照してrAddressへ適切に返信する
    public static func replyGetDetail(_ rAddress:String, _ els:EL_STRUCTURE, _ dev_details:T_OBJs ) throws {
        var success:Bool = true
        var retDetailsArray:[UInt8] = []
        var ret_opc:UInt8 = 0
        // print( "Recv DETAILs:" )
        // ELSwift.printDetails(els.DETAILs)
        for ( epc, _ ) in els.DETAILs {  // key=epc, value=edt
            if( ELSwift.replyGetDetail_sub( els, dev_details, epc ) ) {
                retDetailsArray.append( epc )
                retDetailsArray.append( UInt8(dev_details[els.DEOJ]![epc]!.count) )
                retDetailsArray += dev_details[els.DEOJ]![epc]!
                // print( "retDetails:", retDetailsArray )
            }else{
                // print( "failed:", ELSwift.printUInt8Array_String(els.DEOJ), ELSwift.toHexString(epc) )
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
    
    /// 内部関数
    // 上記のサブルーチン
    public static func replyGetDetail_sub(_ els:EL_STRUCTURE, _ dev_details:T_OBJs, _ epc:UInt8) -> Bool {
        guard let obj = dev_details[els.DEOJ] else { // EOJそのものがあるか？
            print( "Warning! ELSwift.replyGetDetail() error: EOJ is not found.", ELSwift.printUInt8Array_String(els.DEOJ) )
            return false
        }
        
        // console.log( dev_details[els.DEOJ], els.DEOJ, epc );
        if ( obj[epc] == nil || obj[epc] == [] ) { // EOJはあるが、EPCが無い、または空
            print( "Warning! ELSwift.replyGetDetail() error: EPC is not found or empty.", ELSwift.toHexString(epc) )
            return false
        }
        return true  // OK
    }
    
    /// 送信系
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
        
        if( els.ESV == ELSwift.SETI ) { return }  // SetIなら返却なし、sub関数でSet処理をやっているのでここで判定
        
        // SetCは SetC_ResかSetC_SNAを返す
        let ret_esv:UInt8 = success ? 0x71 : 0x5  // 一つでも失敗したらSETC_SNA
        let el_base:[UInt8] = [(UInt8)(0x10), (UInt8)(0x81)] + els.TID + els.DEOJ + els.SEOJ
        let arr:[UInt8] = el_base + [ret_esv] + [ret_opc] + retDetailsArray
        try ELSwift.sendArray( rAddress, arr )
    }
    
    /// 内部関数
    // 上記のサブルーチン
    // dev_detailsはSetされる
    public static func replySetDetail_sub(_ rAddress:String, _ els:EL_STRUCTURE, _ dev_details: inout T_OBJs, _ epc:UInt8) throws -> Bool{
        guard let edt:[UInt8] = els.DETAILs[epc] else {  // setされるべきedtの有無チェック
            return false
        }
        
        var ret:Bool = false
        
        
        switch( Array(els.DEOJ[0...1]) ) {
        case ELSwift.NODE_PROFILE_CLASS: // ノードプロファイルはsetするものがbfだけ
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
    
    
    //-------------------------------------------------------------------------------
    // 変換系
    //-------------------------------------------------------------------------------
    
    /// 変換系
    /// Detailだけをparseする，内部で主に使う
    /// - Parameters:
    ///   - opc:
    ///   - epcpdcedt:
    /// - Returns: T_DETAILs
    /// - Throws:
    public static func parseDetail(_ opc:UInt8, _ epcpdcedt:T_EPCPDCEDT ) throws -> T_DETAILs {
        var ret: T_DETAILs = T_DETAILs() // 戻り値用，連想配列
        
        var now:Int = 0  // 現在のIndex
        var epc:UInt8 = 0
        var pdc:UInt8 = 0
        
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
                // property mapだけEDT[0] != バイト数なので別処理
                if( epc == 0x9d || epc == 0x9e || epc == 0x9f ) {
                    if( pdc >= 17) { // プロパティの数が16以上の場合（プロパティカウンタ含めてPDC17以上）は format 2
                        // 0byte=epc, 2byte=pdc, 4byte=edt
                        for _ in 0 ..< pdc {
                            // 登録
                            edt.append( epcpdcedt[now] )
                            now += 1
                        }
                        ret[ epc ] = try ELSwift.parseMapForm2(edt)
                        // return ret;
                    }else{
                        // format 2でなければ以下と同じ形式で解析可能
                        for _ in 0 ..< pdc {
                            // 登録
                            edt.append( epcpdcedt[now] )
                            now += 1
                        }
                        // console.log('epc:', EL.toHexString(epc), 'edt:', EL.bytesToString(edt) );
                        ret[ epc ] = edt
                    }
                }else{
                    // PDCループ
                    for _ in ( 0..<pdc ) {
                        // 登録
                        edt += [ epcpdcedt[now] ]
                        now += 1
                    }
                    // if( Self.isDebug ) { print("opc: \(opc), epc:\(epc), pdc:\(pdc), edt:\(edt)") }
                    ret[ epc ] = edt
                }
            }
            
        }  // opcループ
        
        return ret
    }
    
    /// 変換系
    // Detailだけをparseする，内部で主に使う
    public static func parseDetail(_ opc:UInt8,_ str:String ) throws -> T_DETAILs {
        return try parseDetail( opc, ELSwift.toHexArray(str) )
    }
    
    /// 変換系
    public static func parseDetail(_ opc:String,_ str:String ) throws -> T_DETAILs {
        return try parseDetail( ELSwift.toHexArray(opc)[0], ELSwift.toHexArray(str) )
    }
    
    /// 変換系
    // バイトデータをいれるとEL_STRACTURE形式にする ok
    public static func parseBytes(_ bytes:[UInt8] ) throws -> EL_STRUCTURE {
        do{
            // 最低限のELパケットになってない
            if( bytes.count < 14 ) {
                print( "Error!! ELSwift.parseBytes() error: bytes is less then 14 bytes. bytes.count is \(bytes.count)" )
                ELSwift.printUInt8Array( bytes )
                throw ELError.BadReceivedData
            }
            
            var eldata: EL_STRUCTURE = EL_STRUCTURE()
            do{
                eldata.EHD = Array(bytes[0...1])
                eldata.TID = Array(bytes[2...3])
                eldata.SEOJ = Array(bytes[4...6])
                eldata.DEOJ = Array(bytes[7...9])
                eldata.EDATA = Array(bytes[10...])
                eldata.ESV = bytes[10]
                eldata.OPC = bytes[11]
                eldata.EPCPDCEDT = Array(bytes[12...])
                eldata.DETAILs = try ELSwift.parseDetail( eldata.OPC, eldata.EPCPDCEDT )
            }catch{
                throw error
            }
            
            return ( eldata )
        } catch {
            throw error
        }
        
    }
    
    /// 変換系
    // バイトデータをいれるとEL_STRACTURE形式にする ok
    public static func parseData(_ data:Data ) throws -> EL_STRUCTURE {
        try ELSwift.parseBytes( [UInt8](data) )
    }
    
    /// 変換系
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
    
    /// 変換系
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
    
    /// 変換系
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
    
    /// 変換系
    // ELDATAをいれるとELらしい切り方のStringを得る
    public static func getSeparatedString_ELDATA(_ eldata : EL_STRUCTURE ) -> String {
        let ehd = eldata.EHD.map{ ELSwift.toHexString($0)}.joined()
        let tid = eldata.TID.map{ ELSwift.toHexString($0)}.joined()
        let seoj = eldata.SEOJ.map{ ELSwift.toHexString($0)}.joined()
        let deoj = eldata.DEOJ.map{ ELSwift.toHexString($0)}.joined()
        let edata = eldata.EDATA.map{ ELSwift.toHexString($0)}.joined()
        return ( "\(ehd) \(tid) \(seoj) \(deoj) \(edata)" )
    }
    
    /// 変換系
    // EL_STRACTURE形式から配列へ
    public static func ELDATA2Array(_ eldata: EL_STRUCTURE ) throws -> [UInt8] {
        let ret = eldata.EHD + eldata.TID + eldata.SEOJ + eldata.DEOJ + eldata.EDATA
        return ret
    }
    
    /// 変換系
    // 1バイトを文字列の16進表現へ（1Byteは必ず2文字にする） ok
    public static func toHexString(_ byte:UInt8 ) -> String {
        return ( String(format: "%02hhx", byte) )
    }
    
    /// 変換系
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
    
    /// 変換系
    // バイト配列を文字列にかえる ok
    public static func bytesToString(_ bytes: [UInt8] ) throws -> String{
        var ret:String = ""
        
        for i in (0..<bytes.count) {
            ret += ELSwift.toHexString( bytes[i] )
        }
        return ret
    }
    
    /// 変換系
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
    
    /// 変換系
    // 文字列入力もできる
    public static func parseMapForm2(_ bitString:String ) throws -> [UInt8] {
        return try ELSwift.parseMapForm2( ELSwift.toHexArray(bitString) )
    }
    
    
    
    //----------------------------------------------------
    // EL受信
    //-----------------------------------------------------

    /// 受信処理
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
            
            if( Self.isDebug ) {
                print("===== ELSwift.returner() =====")
                ELSwift.printEL_STRUCTURE(els)
            }
            
            // Node profileに関してきちんと処理する
            if ( Array(els.DEOJ[0..<2]) == ELSwift.NODE_PROFILE_CLASS ) {
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
                    if(  ELSwift.autoGetProperties ) {
                        for (epc, _) in els.DETAILs {
                            let els:EL_STRUCTURE = EL_STRUCTURE(tid:[0x00,0x00], seoj:ELSwift.NODE_PROFILE_OBJECT, deoj:els.SEOJ, esv:ELSwift.GET, opc:0x01, epcpdcedt: [epc, 0x00] )
                            sendQueue.addOperations( [CSendTask( rAddress, els)], waitUntilFinished: false)
                        }
                    }
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
                        for (epc, _) in els.DETAILs {
                            let els:EL_STRUCTURE = EL_STRUCTURE(tid:[0x00,0x00], seoj:ELSwift.NODE_PROFILE_OBJECT, deoj:els.SEOJ, esv:ELSwift.GET, opc:0x01, epcpdcedt: [epc, 0x00] )
                            
                            sendQueue.addOperations( [CSendTask( rAddress, els)], waitUntilFinished: false)
                        }
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
                    if ( Array(els.SEOJ[0..<2]) == ELSwift.NODE_PROFILE_CLASS)  {
                        // print("Get[0ef0xx] : ")
                        if let array:T_PDCEDT = els.DETAILs[0xd6] {
                            // print("Get[D6] : ")
                            // ELSwift.printUInt8Array(array)
                            // console.log( "ELSwift.returner: get object list! PropertyMap req V1.0.")
                            // 自ノードインスタンスリストSに書いてあるオブジェクトのプロパティマップをもらう
                            if( array != [] ) {  // GET_SNAだと[]の時があるので排除
                                let instNum:Int = Int( array[0] ) // 0番目はオブジェクト数, indexに使うのでIntにする
                                for i in 0 ..< instNum {
                                    let begin:Int = i * 3 + 1
                                    let end:Int = i * 3 + 4
                                    let obj:[UInt8] = Array( array[  begin ..< end  ] )
                                    ELSwift.getPropertyMaps( rAddress, obj )
                                }
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
                        ELSwift.printUInt8Array(array)
                        var epcpdcedt:T_EPCPDCEDT = []
                        let num:Int = Int( array[0] )
                        var i = 0
                        while i < num {
                            // d6, 9d, 9e, 9fはサーチの時点で取得しているはずなので取得しない
                            // 特にd6と9fは取り直すと無限ループするので注意
                            if( array[i+1] != 0xd6 && array[i+1] != 0x9d && array[i+1] != 0x9e && array[i+1] != 0x9f ) {
                                epcpdcedt.append( array[i+1] )
                                epcpdcedt.append( 0x00 )
                            }
                            i += 1
                        }
                        
                        
                        let els:EL_STRUCTURE = EL_STRUCTURE( tid:[0x00, 0x00], seoj:ELSwift.NODE_PROFILE_OBJECT, deoj:els.SEOJ, esv:ELSwift.GET, opc:0x03, epcpdcedt:epcpdcedt)
                        sendQueue.addOperations( [CSendTask( rAddress, els)], waitUntilFinished: false)
                        
                        // old try ELSwift.sendDetails( rAddress, ELSwift.NODE_PROFILE_OBJECT, els.SEOJ, ELSwift.GET, details)
                    }
                    break
                    
                case ELSwift.INF:  // 0x73
                    if( Self.isDebug ) { print("-> ELSwift.INF rAddress:", rAddress, " obj: NodeProfileObject") }
                    // ECHONETネットワークで、新規デバイスが起動したのでプロパティもらいに行く
                    // autoGetPropertiesがfalseならやらない
                    if( els.DETAILs[0xd5] != nil && els.DETAILs[0xd5] != []  && ELSwift.autoGetProperties) {
                        // ノードプロファイルオブジェクトのプロパティマップをもらう
                        ELSwift.getPropertyMaps( rAddress, ELSwift.NODE_PROFILE_OBJECT )
                    }
                    break
                    
                case ELSwift.INFC: // "74"
                    if( Self.isDebug ) {
                        print("-> ELSwift.INFC rAddress:", rAddress, " obj: NodeProfileObject" )
                    }
                    // ECHONET Lite Ver. 1.0以前の処理で利用していたフロー
                    // オブジェクトリストをもらったらそのオブジェクトのPropertyMapをもらいに行く
                    // autoGetPropertiesがfalseならやらない
                    if(ELSwift.autoGetProperties ) {
                        if let array:T_PDCEDT = els.DETAILs[0xd5] {
                            // ノードプロファイルオブジェクトのプロパティマップをもらう
                            ELSwift.getPropertyMaps( rAddress, ELSwift.NODE_PROFILE_OBJECT )
                            
                            // console.log( "ELSwift.returner: get object list! PropertyMap req.")
                            var instNum:Int = Int( array[0] )
                            while( 0 < instNum ) {
                                let begin:Int = (instNum - 1) * 3 + 1
                                let end:Int = (instNum - 1) * 3 + 4
                                let obj:[UInt8] = Array( array[  begin ..< end  ] )
                                ELSwift.getPropertyMaps( rAddress, obj )
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
            
            // 受信状態から機器情報修正,下記の時のみ
            // Get_Res, INF, INFC, INFC_Res, SetGet_Res
            if (els.ESV == ELSwift.GET_RES || els.ESV == ELSwift.GET_SNA || els.ESV == ELSwift.INF || els.ESV == ELSwift.INFC || els.ESV == ELSwift.INFC_RES || els.ESV == ELSwift.SETGET_RES) {
                if( Self.isDebug ) {
                    print("-> renewFacilities:", rAddress)
                    ELSwift.printEL_STRUCTURE(els)
                }
                try ELSwift.renewFacilities(rAddress, els)
            }
            
            // 機器オブジェクトに関してはユーザー関数に任す
            if( Self.isDebug ) {
                print("----- ELSwift.userFunc rAddress:", rAddress, "-----")
                // ELSwift.printEL_STRUCTURE(els)
            }
            ELSwift.userFunc!(rAddress, els, nil)
        } catch {
            if( Self.isDebug ) {
                print("Error!! ELSwift.userFunc rAddress:", rAddress, content!, error)
            }
            ELSwift.userFunc!(rAddress, nil, error)
        }
    }
    
    /// 内部関数
    // ネットワーク内のEL機器全体情報を更新する，受信したら勝手に実行される
    public static func renewFacilities(_ address:String, _ els:EL_STRUCTURE) throws -> Void {
        do {
            let epcList:T_DETAILs = try ELSwift.parseDetail(els.OPC, els.EPCPDCEDT);
            let seoj = els.SEOJ
            
            // 新規IP
            if ELSwift.facilities[address] == nil { //見つからない
                if( Self.isDebug ) {
                    print("New address:", address)
                }
                
                ELSwift.facilities[address] = T_OBJs()
            }
            
            if let objs = ELSwift.facilities[address] {
                // 新規obj
                if ( objs[seoj] == nil ) {
                    if( Self.isDebug ) {
                        print("New OBJ:", seoj)
                    }
                    ELSwift.facilities[address]?[seoj] = T_DETAILs()
                }
                
                for ( epc, edt ) in epcList {
                    // GET_SNAの時のNULL {EDT:''} を入れてしまうのを避けるため、
                    // PDC 1byte, edt 1Byte以上の時に格納する
                    if edt.count >= 1 {
                        ELSwift.facilities[address]?[seoj]?[epc] = edt
                    }
                    
                    // もしEPC = 0x83の時は識別番号なので，識別番号リストに確保
                    /*
                     if( epc === 0x83 ) {
                     ELSwift.identificationNumbers.push( {id: epcList[epc], ip: address, OBJ: els.SEOJ } );
                     }
                     */
                }
            }
        } catch {
            print("Error!! ELSwift.renewFacilities() error:", error)
            // console.dir(e);
            throw error;
        }
    }
    
    
}
