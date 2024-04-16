//
//  SocketManager.swift
//  TestVaporWSServer
//
//  Created by Admin on 13/04/2024.
//

import Foundation
import Vapor
import UIKit
import Network

enum ItemType {
    case text(String)
    case data(Data)
}

enum SenderType {
    case sender
    case receiver
    case system
}

struct Message: Identifiable {
    let id: UUID = UUID()
    let type: ItemType
    var sender: SenderType
}

class SocketServer: ObservableObject {
    @Published var serverIP: String = ""
    @Published var messageList: [Message] = []
    
    private var app: Application
    private var hostname: String?// = "10.1.140.201"//= "172.20.10.1"
    private let port: Int = 4000
    
    private var connectedWS = [String: WebSocket]()
    private let recorder = SuspendStatusRecorder()
    init() {
        app = Application(.development)
        configure(app)
        setup()
        recorder.start()
    }
    
    private func setup() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillSuspend), name: .applicationWillSuspend, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidSuspend), name: .applicationDidSuspend, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidUnsuspend), name: .applicationDidUnsuspend, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(suspendStatusRecorderFailed), name: .suspendStatusRecorderFailed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActiveNotification), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForegroundNotification), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActiveNotification), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc func applicationWillSuspend(notification: Notification) {
        print("applicationWillSuspend \(Date())")
        print("applicationWillSuspend 12 \(Date())")
        print("applicationWillSuspend 23 \(Date())")
    }
    
    @objc func applicationDidSuspend(notification: Notification) {
        print("applicationDidSuspend \(Date())")
    }
    
    @objc func applicationDidUnsuspend(notification: Notification) {
        print("applicationDidUnsuspend \(Date())")
    }
    
    @objc func suspendStatusRecorderFailed(notification: Notification) {
        print("suspendStatusRecorderFailed \(Date())")
    }
    
    @objc func didBecomeActiveNotification(notification: Notification) {
        print("\(#function) \(Date())")
    }
    
    @objc func didEnterBackground(notification: Notification) {
        print("\(#function) \(Date())")
    }
    
    @objc func willEnterForegroundNotification(notification: Notification) {
        print("\(#function) \(Date())")
    }
    
    @objc func willResignActiveNotification(notification: Notification) {
        print("\(#function) \(Date())")
    }
    
    private func configure(_ app: Application) {
//        if let hostname {
            app.http.server.configuration.hostname = NWInterface.InterfaceType.wifi.ipv4 ?? ""
//        }
        app.http.server.configuration.port = port
        
        serverIP = "ws://\(app.http.server.configuration.hostname):\(port)/echo"

        app.webSocket("echo", maxFrameSize: 30_000_000) { [weak self] req, ws in
            guard let self else { return }
            let key = "\(req.remoteAddress?.hostname ?? ""):\(req.remoteAddress?.port ?? 0)"
            connectedWS[key] = ws
            let fromAddress = "\(req.peerAddress?.ipAddress ?? ""):\(req.peerAddress?.port ?? 0)"
            self.printLog("Client connected from \(fromAddress)", senderInfo: .system)
            ws.onText { ws, text in
                if text.lowercased() != "image" {
                    self.printLog("\(text)", senderInfo: .receiver)
                    ws.send("\(text.uppercased())")
                    self.printLog("\(text.uppercased())", senderInfo: .sender)
                } else {
                    let images = ["chuttersnap-piQY2YNDJ8k-unsplash", "leonard-von-bibra-hep72i867oI-unsplash"]
                    if let randomImageName = images.randomElement(),
                       let originalFileURL = Bundle.main.url(forResource: randomImageName, withExtension: ".jpg"),
                       let originalContents = try? Data(contentsOf: originalFileURL) {
                        ws.send(raw: originalContents, opcode: .binary)
                        self.printSendData(originalContents, to: ws, senderInfo: .sender)
                    } else {
                        self.printLog("Send image failed", senderInfo: .sender)
                    }
                }
            }
            ws.onBinary { ws, buffer in
                var data: Data = Data()
                data.append(contentsOf: buffer.readableBytesView)
                //                let image = UIImage(data: data)
                //                self.printLog("Received from \(fromAddress): \(data)")
                self.printReceivedData(data, fromAddress: fromAddress, senderInfo: .receiver)
            }
            ws.onPing { ws, data in
                //                self.printLog("onPing from \(fromAddress): \(data)", senderInfo: .system)
                Swift.print("onPing from \(fromAddress): \(data)")
            }
            ws.onPong { ws, data in
                //                self.printLog("onPong from \(fromAddress): \(data)", senderInfo: .system)
                Swift.print("onPong from \(fromAddress): \(data)")
            }
            ws.onClose
                .whenComplete({ result in
                    self.printLog("Client disconnected \(fromAddress)", senderInfo: .system)
                })
        }
    }
    
    func sendToClients(imageData: Data) {
//        connectedWS.forEach({ (host, ws) in
//            if !ws.isClosed {
//                ws.send(raw: imageData, opcode: .binary)
//                //                self.printLog("Received from \(ws): \(imageData)")
//                printSendData(imageData, to: ws, senderInfo: .sender)
//            } else {
//                connectedWS[host] = nil
//            }
//        })
//        connectedWS.forEach({ (host, ws) in
//            if !ws.isClosed {
//                ws.send(raw: imageData, opcode: .binary)
//                //                self.printLog("Received from \(ws): \(imageData)")
//                printSendData(imageData, to: ws, senderInfo: .sender)
//            }
//        })
//        connectedWS = connectedWS.filter({ (host, ws) in
//            !ws.isClosed
//        })
    }
    
    
    func start() {
        Task(priority: .background) {
            do {
                try await app.startup()
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
    
    private func printLog(_ text: String, senderInfo: SenderType) {
        DispatchQueue.main.async {
            print("text \(text)")
            self.messageList.append(Message(type: .text(text), sender: senderInfo))
        }
    }
    
    private func printReceivedData(_ data: Data, fromAddress: String, senderInfo: SenderType) {
        DispatchQueue.main.async {
            print("receive data \(data) fromAddress \(fromAddress)")
            self.messageList.append(Message(type: .data(data), sender: senderInfo))
        }
    }
    
    private func printSendData(_ data: Data, to webSocket: WebSocket?, senderInfo: SenderType) {
        DispatchQueue.main.async {
            print("send data \(data) to ws \(String(describing: webSocket))")
            self.messageList.append(Message(type: .data(data), sender: senderInfo))
        }
    }
    
}

extension SocketServer {
    // Return IP address of WiFi interface (en0) as a String, or `nil`
    func getWiFiAddress() -> String? {
        var address : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) /*|| addrFamily == UInt8(AF_INET6)*/ {
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" || name.hasPrefix("bridge") {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    print("--- name \(name) --- \(String(cString: hostname))")
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }
    
    func getIPAddress() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { return "" }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    
                    // wifi = ["en0"]
                    // wired = ["en2", "en3", "en4"]
                    // cellular = ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]
                    
                    let name: String = String(cString: (interface.ifa_name))
                    if  name == "en0" || name == "en2" || name == "en3" || name == "en4" || name == "pdp_ip0" || name == "pdp_ip1" || name == "pdp_ip2" || name == "pdp_ip3" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t((interface.ifa_addr.pointee.sa_len)), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        print("name \(name) -- \(String(describing: address))")
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address ?? ""
    }
}

import Network

extension NWInterface.InterfaceType {
    var names : [String]? {
        switch self {
        case .wifi: return ["en0"/*, "bridge100"*/]
        case .wiredEthernet: return ["en2", "en3", "en4"]
        case .cellular: return ["pdp_ip0","pdp_ip1","pdp_ip2","pdp_ip3"]
        default: return nil
        }
    }
    
    func address(family: Int32) -> String?
    {
        guard let names = names else { return nil }
        var address : String?
        for name in names {
            guard let nameAddress = self.address(family: family, name: name) else { continue }
            address = nameAddress
            break
        }
        return address
    }
    
    func address(family: Int32, name: String) -> String? {
        var address: String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(family)
            {
                // Check interface name:
                if name == String(cString: interface.ifa_name) {
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }
    
    var ipv4 : String? { self.address(family: AF_INET) }
    var ipv6 : String? { self.address(family: AF_INET6) }
}
