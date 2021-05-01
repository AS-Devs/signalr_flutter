import Flutter
import UIKit

public class SwiftSignalRFlutterPlugin: NSObject, FlutterPlugin {

  static var channel: FlutterMethodChannel!

  public static func register(with registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(name: "signalR", binaryMessenger: registrar.messenger())
    let instance = SwiftSignalRFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {

    case CallMethod.connectToServer.rawValue:
      let arguments = call.arguments as! Dictionary<String, Any>
      SignalRWrapper.instance.connectToServer(baseUrl: arguments["baseUrl"] as! String,
                                              hubName: arguments["hubName"] as! String,
                                              transport: arguments["transport"] as? Int ?? 0,
                                              queryString: arguments["queryString"] as? String ?? "",
                                              headers: arguments["headers"] as? [String:String] ?? [String: String](),
                                              hubMethods: arguments["hubMethods"] as? [String] ?? [],
                                              result: result)
      break

    case CallMethod.reconnect.rawValue:
      SignalRWrapper.instance.reconnect(result: result)
      break

    case CallMethod.stop.rawValue:
      SignalRWrapper.instance.stop(result: result)
      break

    case CallMethod.listenToHubMethod.rawValue:
      let methodName = call.arguments as! String
      SignalRWrapper.instance.listenToHubMethod(methodName: methodName, result: result)
      break

    case CallMethod.invokeServerMethod.rawValue:
      let arguments = call.arguments as! Dictionary<String, Any>
      SignalRWrapper.instance.invokeServerMethod(methodName: arguments["methodName"] as! String, arguments: arguments["arguments"] as? [Any], result: result)
      break

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
