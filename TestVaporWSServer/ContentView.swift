//
//  ContentView.swift
//  TestVaporWSServer
//
//  Created by Admin on 13/04/2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject var socketServer = SocketServer()
    @State var showImagePicker: Bool = false
    @State var image: UIImage? = nil
    @State private var showingAlert = false
    
    var body: some View {
        VStack {
            Text("Server address: \(socketServer.serverIP)")
            Button(action: {
                socketServer.messageList = []
            }, label: {
                Text("Clear logs")
            })
//            Button(action: {
//                self.showImagePicker.toggle()
//            }) {
//                Text("Show image picker")
//            }
            ScrollView {
                VStack { // <---
                    ForEach(socketServer.messageList, id: \.id) { item in
                        VStack {
                            switch item.type {
                            case .text(let msg):
                                Text(msg)
                                    .multilineTextAlignment(getHorizontalTextAlignment(with: item.sender))
                                    .padding(6)
                                    .background(getBackgroundColor(with: item.sender))
                                    .cornerRadius(10)
                            case .data(let data):
                                if let data = UIImage(data: data) {
                                    Image(uiImage: data)
                                        .resizable()
                                        .border(.blue)
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(10)
                                }
                            }
                        }  
                        .frame(maxWidth: .infinity,
                                  alignment: getHorizontalItemAlignment(with: item.sender))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .alert("Are you want to send the image to the clients", isPresented: $showingAlert, actions: {
            Button("Yes", action: {
                if let imageData = image?.pngData() {
                    stackOverflowAnswer(data: imageData)
                    socketServer.sendToClients(imageData: imageData)
                    image = nil
                }
            })
            Button("Cancel", role: .cancel, action: {
                image = nil
            })
        })
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                self.image = image //Image(uiImage: image)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                    self.showingAlert.toggle()
                })
            }
        }
        .onAppear(perform: {
            socketServer.start()
        })
    }
    
    func stackOverflowAnswer(data: Data?) {
       if let data {
           print("There were \(data.count) bytes")
           let bcf = ByteCountFormatter()
           bcf.allowedUnits = [.useMB] // optional: restricts the units to MB only
           bcf.countStyle = .file
           let string = bcf.string(fromByteCount: Int64(data.count))
           print("formatted result: \(string)")
       }
    }
 
    private func getHorizontalAlignment(with sender: SenderType) -> HorizontalAlignment {
        switch sender {
        case .sender:
            return .trailing
        case .receiver:
            return .leading
        case .system:
            return .center
        }
    } 
    
    private func getHorizontalItemAlignment(with sender: SenderType) -> Alignment {
        switch sender {
        case .sender:
            return .trailing
        case .receiver:
            return .leading
        case .system:
            return .center
        }
    }
    
    private func getHorizontalTextAlignment(with sender: SenderType) -> TextAlignment {
        switch sender {
        case .sender:
            return .trailing
        case .receiver:
            return .leading
        case .system:
            return .center
        }
    }
    
    private func getBackgroundColor(with sender: SenderType) -> Color {
        switch sender {
        case .sender:
            return .blue
        case .receiver:
            return .gray
        case .system:
            return .clear
        }
    }
}

#Preview {
    ContentView()
}
