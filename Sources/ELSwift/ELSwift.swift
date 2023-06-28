//==============================================================================
// SUGIMURA Hiroshi
//==============================================================================
import Foundation
import Network

//==============================================================================
public struct EL_STRUCTURE {
    public var EHD : [UInt8]
    public var TID : [UInt8]
    public var SEOJ : [UInt8]
    public var DEOJ : [UInt8]
    public var EDATA: [UInt8]    // 下記はEDATAの詳細
    public var ESV : UInt8
    public var OPC : UInt8
    public var DETAIL: [UInt8]
    public var DETAILs: Dictionary<String, [UInt8]>
    
    public init() {
        EHD = []
        TID = []
        SEOJ = []
        DEOJ = []
        EDATA = []
        ESV = 0x00
        OPC = 0x00
        DETAIL = []
        DETAILs = [String: [UInt8]]()
    }
}

//==============================================================================
public class ELSwift {
    let networkType = "_networkplayground._udp."
    let networkDomain = "local"
    let PORT:UInt16 = 3610
    let MultiIP:String = "224.0.23.0"
    let EHD:[UInt8] = [0x10, 0x81]
    let EL_SETI:UInt8 = 0x60
    let EL_SETC:UInt8 = 0x61
    let EL_GET:UInt8 = 0x62
    let EL_INFREQ:UInt8 = 0x63
    let EL_SETGET:UInt8 = 0x6E
    var tid:[UInt8] = [0x00, 0x01]
    
    private var listener: NWListener!
    private var group: NWConnectionGroup!
    
    private(set) public var isReady: Bool = false
    public var listening: Bool = true
    var queue = DispatchQueue.global(qos: .userInitiated)
    
    init() {
        print("init()")
        
        //--- Listener
        let params = NWParameters.udp
        params.allowFastOpen = true
        let port = NWEndpoint.Port(rawValue: self.PORT)
        self.listener = try? NWListener(using: params, on: port!)

        self.listener?.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                self.isReady = true
                print("Listener connected to port \(String(describing: port))")
            case .failed, .cancelled:
                // Announce we are no longer able to listen
                self.listening = false
                self.isReady = false
                print("Listener disconnected from port \(String(describing: port))")
            default:
                print("Listener connecting to port \(String(describing: port))...")
            }
        }

        self.listener?.newConnectionHandler = { connection in
            connection.stateUpdateHandler = {newState in
                switch newState {
                case .ready:
                    print("ready")                    
                    self.receive(nWConnection: connection)
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue(label: "newconn"))
            
        }
        self.listener?.start(queue: self.queue)
        
        
        //---- multicast
        guard let multicast = try? NWMulticastGroup(for: [ .hostPort(host: "224.0.23.0", port: 3610)], disableUnicast: false)
        else { fatalError("error in Muticast") }
        
        self.group = NWConnectionGroup(with: multicast, using: .udp)
        
        self.group.setReceiveHandler(maximumMessageSize: 1518, rejectOversizedMessages: true) { (message, content, isComplete) in
            print("Received message from \(String(describing: message.remoteEndpoint))")
            //let message = String(data: content, encoding: .utf8)
            //let message = Data(content, encoding: .utf8)
            print(content as Any)
            //let sendContent = Data("ack".utf8)
            //message.reply(content: sendContent)
        }
        
        self.group.stateUpdateHandler = { (newState) in
            print("Group entered state \(String(describing: newState))")
            switch newState {
            case .ready:
                print("ready")
                var msg:[UInt8] = self.EHD + self.tid + [0x05, 0xff, 0x01] + [0x0e, 0xf0, 0x01 ]
                //msg.append(contentsOf:[ESV_INFREQ, 0x01, EPC_INSLSTNTFPROP, 0x00])
                msg.append(contentsOf:[self.EL_GET, 0x01, 0xD6, 0x00])
                let groupSendContent = Data(msg)  // .data(using: .utf8)
                
                print("send...UDP")
                self.group.send(content: groupSendContent) { (error)  in
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
        self.group.start(queue: queue)
        //group.start(queue: .main)
        
    }
    
    deinit {
        print("deinit")
        group.cancel()
    }

    
    //---------------------------------------
    func receive(nWConnection:NWConnection) {
           nWConnection.receive(minimumIncompleteLength: 1, maximumLength: 5, completion: { (data, context, flag, error) in
               print("receiveMessage")
               if let data = data {
                   let receiveData = [UInt8](data)
                   print(receiveData)
                   print(flag)
                   if(flag == false) {
                       self.receive(nWConnection: nWConnection)
                   }
               }
               else {
                   print("receiveMessage data nil")
               }
           })
       }

    
    
    //---------------------------------------
    public func sendBase(toip:String, data: Data) {
        print("sendBase(Data)")
        let socket = NWConnection(host:NWEndpoint.Host(toip), port:3610, using: .udp)
        
        // 送信完了時の処理のクロージャ
        let completion = NWConnection.SendCompletion.contentProcessed { (error: NWError?) in
            print("送信完了")
        }
        
        // 送信
        socket.send(content: data, completion: completion)
        
    }
    
    public func sendBase(toip:String, array: [UInt8]) {
        print("sendBase(UInt8)")
        // 送信
        sendBase(toip:toip, data:Data( array ) )
    }
    
    public func sendString(toip:String, message: String) {
        print("sendString()")
        // 送信
        if let data = message.data(using: String.Encoding.utf8) {
            sendBase(toip: toip, data: data )
        }
    }
    
    //------------ multi send
    public func sendBaseMulti(data: Data) {
        print("sendBaseMulti(Data)")
        
        // group.sendの使い方がわからん
        // 送信完了時の処理のクロージャ
        //var completion: NWConnection.SendCompletion = .contentProcessed { (error: NWError?) in
        //    print("send error: \(String(describing: error))")
        //}
        
        // let comp : NWConnection.SendCompletion = .contentProcessed { (error) in
        // print("応答送信完了")
        // }
        
        // 送信
        // self.group.send(content: data, completion: comp)
        //self.group.send(content: data, completion: { error in
        //    print("send error: \(String(describing: error))")
        //})
        //self.group.send(content: data, completion: NWConnection.SendCompletion)
        
        // sendでいってみる
        let socket = NWConnection( host:NWEndpoint.Host( self.MultiIP ), port:3610, using: .udp)
        
        // 送信完了時の処理のクロージャ
        let completion = NWConnection.SendCompletion.contentProcessed { (error: NWError?) in
            print("送信完了")
        }
        
        // 送信
        socket.send(content: data, completion: completion)
    }
    
    public func sendBaseMulti(array: [UInt8]) {
        print("sendBaseMulti(UInt8)")
        // 送信
        sendBaseMulti(data:Data( array ) )
    }
    
    public func sendStringMulti( message: String) {
        print("sendStringMulti()")
        // 送信
        if let data = message.data(using: String.Encoding.utf8) {
            sendBaseMulti(data: data )
        }
    }
    
    public func search() {
        print("search()")
        sendString(toip:MultiIP, message: "1081000005ff010ef0016201d600")
    }
    
}
