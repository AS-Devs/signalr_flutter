//
//  SignalR.swift
//  signalR
//
//  Created by Ayon Das on 23/07/20.
//

import Foundation

enum CallMethod : String {
  case connectToServer, reconnect, stop, invokeServerMethod, listenToHubMethod
}

class SignalRWrapper {

  static let instance = SignalRWrapper()
  private var hub: Hub!
  private var connection: SignalR!

  func connectToServer(baseUrl: String, hubName: String, transport: Int, queryString : String, headers: [String: String], hubMethods: [String], result: @escaping FlutterResult) {
    connection = SignalR(baseUrl)

    if !queryString.isEmpty {
      let qs = queryString.components(separatedBy: "=")
      connection.queryString = [qs[0]:qs[1]]
    }

    if transport == 1 {
      connection.transport = Transport.serverSentEvents
    } else if transport == 2 {
      connection.transport = Transport.longPolling
    }

    if headers.count > 0 {
      connection.headers = headers
    }

    hub = connection.createHubProxy(hubName)

    hubMethods.forEach { (methodName) in
      hub.on(methodName) { (args) in
        SwiftSignalRFlutterPlugin.channel.invokeMethod("NewMessage", arguments: [methodName, args?[0]])
      }
    }

    connection.starting = { [weak self] in
      print("SignalR Connecting. Current Status: \(String(describing: self?.connection.state.stringValue))")
      SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: self?.connection.state.stringValue)
    }

    connection.reconnecting = { [weak self] in
      print("SignalR Reconnecting. Current Status: \(String(describing: self?.connection.state.stringValue))")
      SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: self?.connection.state.stringValue)
    }

    connection.connected = { [weak self] in
      print("SignalR Connected. Connection ID: \(String(describing: self?.connection.connectionID))")
      SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: self?.connection.state.stringValue)
    }

    connection.reconnected = { [weak self] in
      print("SignalR Reconnected...")
      print("Connection ID: \(String(describing: self?.connection.connectionID))")
      SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: self?.connection.state.stringValue)
    }

    connection.disconnected = { [weak self] in
      print("SignalR Disconnected...")
      SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: self?.connection.state.stringValue)
    }

    connection.connectionSlow = {
      print("Connection slow...")
      SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: "Slow")
    }

    connection.error = { [weak self] error in
      print("Error: \(String(describing: error))")
      SwiftSignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", arguments: self?.connection.state.stringValue)

      if let source = error?["source"] as? String, source == "TimeoutException" {
        print("Connection timed out. Restarting...")
        self?.connection.start()
      }
    }

    connection.start()
    result(true)
  }

  func reconnect(result: @escaping FlutterResult) {
    if let connection = self.connection {
      connection.connect()
    } else {
      result(FlutterError(code: "Error", message: "SignalR Connection not found or null", details: "Start SignalR connection first"))
    }
  }

  func stop(result: @escaping FlutterResult) {
    if let connection = self.connection {
      connection.stop()
    } else {
      result(FlutterError(code: "Error", message: "SignalR Connection not found or null", details: "Start SignalR connection first"))
    }
  }

  func listenToHubMethod(methodName : String, result: @escaping FlutterResult) {
    if let hub = self.hub {
      hub.on(methodName) { (args) in
        SwiftSignalRFlutterPlugin.channel.invokeMethod("NewMessage", arguments: [methodName, args?[0]])
      }
    } else {
      result(FlutterError(code: "Error", message: "SignalR Connection not found or null", details: "Connect SignalR before listening a Hub method"))
    }
  }

  func invokeServerMethod(methodName: String, arguments: [Any]? = nil, result: @escaping FlutterResult) {
    do {
      if let hub = self.hub {
        try hub.invoke(methodName, arguments: arguments, callback: { (res, error) in
          if let error = error {
            result(FlutterError(code: "Error", message: String(describing: error), details: nil))
          } else {
            result(res)
          }
        })
      } else {
        throw NSError.init(domain: "NullPointerException", code: 0, userInfo: [NSLocalizedDescriptionKey : "Hub is null. Initiate a connection first."])
      }
    } catch {
      result(FlutterError.init(code: "Error", message: error.localizedDescription, details: nil))
    }
  }
}

