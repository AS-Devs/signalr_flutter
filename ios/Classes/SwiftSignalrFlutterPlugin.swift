import Flutter
import UIKit

public class SwiftSignalrFlutterPlugin: NSObject, FlutterPlugin, FLTSignalRHostApi {
  private static var signalrApi : FLTSignalRPlatformApi?

  private var hub: Hub!
  private var connection: SignalR!

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger : FlutterBinaryMessenger = registrar.messenger()
    let api : FLTSignalRHostApi & NSObjectProtocol = SwiftSignalrFlutterPlugin.init()
    FLTSignalRHostApiSetup(messenger, api)
    signalrApi = FLTSignalRPlatformApi.init(binaryMessenger: messenger)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    let messenger : FlutterBinaryMessenger = registrar.messenger()
    FLTSignalRHostApiSetup(messenger, nil)
    SwiftSignalrFlutterPlugin.signalrApi = nil
  }

  public func connect(_ connectionOptions: FLTConnectionOptions?, completion: @escaping (String?, FlutterError?) -> Void) {
    guard let options = connectionOptions else {
      completion(nil, FlutterError(code: "platform-error", message: "Connection options have null value", details: nil))
      return
    }

    connection = SignalR(options.baseUrl ?? "")

    if let queryString = options.queryString, !queryString.isEmpty {
      let qs = queryString.components(separatedBy: "=")
      connection.queryString = [qs[0]:qs[1]]
    }

    switch options.transport {
    case .longPolling:
      connection.transport = Transport.longPolling
    case .serverSentEvents:
      connection.transport = Transport.serverSentEvents
    case .auto:
      connection.transport = Transport.auto
    @unknown default:
      break
    }

    if let headers = options.headers, !headers.isEmpty {
      connection.headers = headers
    }

    if let hubName = options.hubName {
      hub = connection.createHubProxy(hubName)
    }

    if let hubMethods = options.hubMethods, !hubMethods.isEmpty {
      hubMethods.forEach { (methodName) in
        hub.on(methodName) { (args) in
          SwiftSignalrFlutterPlugin.signalrApi?.onNewMessageHubName(methodName, message: args?[0] as? String, completion: { error in })
        }
      }
    }

    connection.starting = {
      let statusChangeResult : FLTStatusChangeResult = FLTStatusChangeResult.init()
      statusChangeResult.connectionId = nil
      statusChangeResult.status = FLTConnectionStatus.connecting
      SwiftSignalrFlutterPlugin.signalrApi?.onStatusChange(statusChangeResult, completion: { error in })
    }

    connection.reconnecting = {
      let statusChangeResult : FLTStatusChangeResult = FLTStatusChangeResult.init()
      statusChangeResult.connectionId = nil
      statusChangeResult.status = FLTConnectionStatus.reconnecting
      SwiftSignalrFlutterPlugin.signalrApi?.onStatusChange(statusChangeResult, completion: { error in })
    }

    connection.connected = { [weak self] in
      let statusChangeResult : FLTStatusChangeResult = FLTStatusChangeResult.init()
      statusChangeResult.connectionId = self?.connection.connectionID
      statusChangeResult.status = FLTConnectionStatus.connected
      SwiftSignalrFlutterPlugin.signalrApi?.onStatusChange(statusChangeResult, completion: { error in })
    }

    connection.reconnected = { [weak self] in
      let statusChangeResult : FLTStatusChangeResult = FLTStatusChangeResult.init()
      statusChangeResult.connectionId = self?.connection.connectionID
      statusChangeResult.status = FLTConnectionStatus.connected
      SwiftSignalrFlutterPlugin.signalrApi?.onStatusChange(statusChangeResult, completion: { error in })
    }

    connection.disconnected = { [weak self] in
      let statusChangeResult : FLTStatusChangeResult = FLTStatusChangeResult.init()
      statusChangeResult.connectionId = self?.connection.connectionID
      statusChangeResult.status = FLTConnectionStatus.disconnected
      SwiftSignalrFlutterPlugin.signalrApi?.onStatusChange(statusChangeResult, completion: { error in })
    }

    connection.connectionSlow = { [weak self] in
      print("Connection slow...")
      let statusChangeResult : FLTStatusChangeResult = FLTStatusChangeResult.init()
      statusChangeResult.connectionId = self?.connection.connectionID
      statusChangeResult.status = FLTConnectionStatus.connectionSlow
      SwiftSignalrFlutterPlugin.signalrApi?.onStatusChange(statusChangeResult, completion: { error in })
    }

    connection.error = { error in
      print("SignalR Error: \(error ?? [:])")
      let statusChangeResult : FLTStatusChangeResult = FLTStatusChangeResult.init()
      statusChangeResult.connectionId = nil
      statusChangeResult.status = FLTConnectionStatus.connectionError
      statusChangeResult.errorMessage = error?.description
      SwiftSignalrFlutterPlugin.signalrApi?.onStatusChange(statusChangeResult, completion: { error in })
    }

    connection.start()
    completion(self.connection.connectionID ?? "", nil)
  }

  public func reconnect(completion: @escaping (String?, FlutterError?) -> Void) {
    if let connection = self.connection {
      connection.start()
      completion(self.connection.connectionID ?? "", nil)
    } else {
      completion(nil, FlutterError(code: "platform-error", message: "SignalR Connection not found or null", details: "Start SignalR connection first"))
    }
  }

  public func stop(completion: @escaping (FlutterError?) -> Void) {
    if let connection = self.connection {
      connection.stop()
    } else {
      completion(FlutterError(code: "platform-error", message: "SignalR Connection not found or null", details: "Start SignalR connection first"))
    }
  }

  public func isConnected(completion: @escaping (NSNumber?, FlutterError?) -> Void) {
    if let connection = self.connection {
      switch connection.state {
      case .connected:
        completion(true, nil)
      default:
        completion(false, nil)
      }
    } else {
      completion(false, nil)
    }
  }

  public func invokeMethodMethodName(_ methodName: String?, arguments: [String]?, completion: @escaping (String?, FlutterError?) -> Void) {
    do {
      if let hub = self.hub {
        try hub.invoke(methodName!, arguments: arguments, callback: { (res, error) in
          if let error = error {
            completion(nil, FlutterError(code: "platform-error", message: String(describing: error), details: nil))
          } else {
            completion(res as? String ?? "", nil)
          }
        })
      } else {
        throw NSError.init(domain: "NullPointerException", code: 0, userInfo: [NSLocalizedDescriptionKey : "Hub is null. Initiate a connection first."])
      }
    } catch {
      completion(nil ,FlutterError.init(code: "platform-error", message: error.localizedDescription, details: nil))
    }
  }
}
