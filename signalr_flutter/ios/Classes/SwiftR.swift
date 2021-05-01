//
//  SwiftR.swift
//  signalR
//
//  Created by Adam Hartford on 4/13/15.
//  Modified by Ayon Das on 23/07/20.
//
//  Copyright (c) 2020 Ayon Das. All rights reserved.
//

import Foundation
import WebKit

@objc public enum ConnectionType: Int {
  case hub
  case persistent
}

@objc public enum State: Int {
  case connecting
  case connected
  case disconnected

  var stringValue: String {
    switch self {
    case .connected:
      return "Connected"
    case .connecting:
      return "Connecting"
    case .disconnected:
      return "Disconnected"
    }
  }
}

public enum Transport: Int {
  case auto
  case webSockets
  case foreverFrame
  case serverSentEvents
  case longPolling

  var stringValue: String {
    switch self {
    case .webSockets:
      return "webSockets"
    case .foreverFrame:
      return "foreverFrame"
    case .serverSentEvents:
      return "serverSentEvents"
    case .longPolling:
      return "longPolling"
    default:
      return "auto"
    }
  }
}

public enum SwiftRError: Error {
  case notConnected

  public var message: String {
    switch self {
    case .notConnected:
      return "Operation requires connection, but none available."
    }
  }
}

class SwiftR {
  static var connections = [SignalR]()

  #if os(iOS)
  public class func cleanup() {
    let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SwiftR", isDirectory: true)
    let fileManager = FileManager.default

    do {
      if fileManager.fileExists(atPath: temp.path) {
        try fileManager.removeItem(at: temp)
      }
    } catch {
      print("Failed to remove temp JavaScript: \(error)")
    }
  }
  #endif
}

open class SignalR: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
  static var connections = [SignalR]()

  var internalID: String!
  var ready = false

  public var signalRVersion: SignalRVersion = .v2_4_1
  public var useWKWebView = true
  public var transport: Transport = .auto

  var wkWebView: WKWebView!

  var baseUrl: String
  var connectionType: ConnectionType

  var readyHandler: ((SignalR) -> ())!
  var hubs = [String: Hub]()

  open var state: State = .disconnected
  open var connectionID: String?
  open var received: ((Any?) -> ())?
  open var starting: (() -> ())?
  open var connected: (() -> ())?
  open var disconnected: (() -> ())?
  open var connectionSlow: (() -> ())?
  open var connectionFailed: (() -> ())?
  open var reconnecting: (() -> ())?
  open var reconnected: (() -> ())?
  open var error: (([String: Any]?) -> ())?

  var jsQueue: [(String, ((Any?) -> ())?)] = []

  open var customUserAgent: String?

  open var queryString: Any? {
    didSet {
      if let qs: Any = queryString {
        if let jsonData = try? JSONSerialization.data(withJSONObject: qs, options: JSONSerialization.WritingOptions()) {
          let json = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)! as String
          runJavaScript("swiftR.connection.qs = \(json)")
        }
      } else {
        runJavaScript("swiftR.connection.qs = {}")
      }
    }
  }

  open var headers: [String: String]? {
    didSet {
      if let h = headers {
        if let jsonData = try? JSONSerialization.data(withJSONObject: h, options: JSONSerialization.WritingOptions()) {
          let json = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)! as String
          runJavaScript("swiftR.headers = \(json)")
        }
      } else {
        runJavaScript("swiftR.headers = {}")
      }
    }
  }

  public init(_ baseUrl: String, connectionType: ConnectionType = .hub) {
    internalID = NSUUID().uuidString
    self.baseUrl = baseUrl
    self.connectionType = connectionType
    super.init()
  }

  public func connect(_ callback: (() -> ())? = nil) {
    readyHandler = { [weak self] _ in
      self?.jsQueue.forEach { self?.runJavaScript($0.0, callback: $0.1) }
      self?.jsQueue.removeAll()

      if let hubs = self?.hubs {
        hubs.forEach { $0.value.initialize() }
      }

      self?.ready = true
      callback?()
    }

    initialize()
  }


  private func initialize() {

    let bundle = Bundle(for: SignalrFlutterPlugin.self)
    let jqueryURL = bundle.url(forResource: "jquery-2.1.3.min", withExtension: "js")!
    let signalRURL = bundle.url(forResource: "jquery.signalr-\(signalRVersion).min", withExtension: "js")!
    let jsURL = bundle.url(forResource: "SwiftR", withExtension: "js")!

    if useWKWebView {
      var jqueryInclude = "<script src='\(jqueryURL.absoluteString)'></script>"
      var signalRInclude = "<script src='\(signalRURL.absoluteString)'></script>"
      var jsInclude = "<script src='\(jsURL.absoluteString)'></script>"

      // Loading file:// URLs from NSTemporaryDirectory() works on iOS, not OS X.
      // Workaround on OS X is to include the script directly.
      #if os(iOS)
      if #available(iOS 9.0, *) {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SwiftR", isDirectory: true)
        let jqueryTempURL = temp.appendingPathComponent("jquery-2.1.3.min.js")
        let signalRTempURL = temp.appendingPathComponent("jquery.signalr-\(signalRVersion).min")
        let jsTempURL = temp.appendingPathComponent("SwiftR.js")

        let fileManager = FileManager.default

        do {
          if SwiftR.connections.isEmpty {
            SwiftR.cleanup()
            try fileManager.createDirectory(at: temp, withIntermediateDirectories: false)
          }

          if !fileManager.fileExists(atPath: jqueryTempURL.path) {
            try fileManager.copyItem(at: jqueryURL, to: jqueryTempURL)
          }
          if !fileManager.fileExists(atPath: signalRTempURL.path) {
            try fileManager.copyItem(at: signalRURL, to: signalRTempURL)
          }
          if !fileManager.fileExists(atPath: jsTempURL.path) {
            try fileManager.copyItem(at: jsURL, to: jsTempURL)
          }
        } catch {
          print("Failed to copy JavaScript to temp dir: \(error)")
        }

        jqueryInclude = "<script src='\(jqueryTempURL.absoluteString)'></script>"
        signalRInclude = "<script src='\(signalRTempURL.absoluteString)'></script>"
        jsInclude = "<script src='\(jsTempURL.absoluteString)'></script>"
      }
      #else
      let jqueryString = try! NSString(contentsOf: jqueryURL, encoding: String.Encoding.utf8.rawValue)
      let signalRString = try! NSString(contentsOf: signalRURL, encoding: String.Encoding.utf8.rawValue)
      let jsString = try! NSString(contentsOf: jsURL, encoding: String.Encoding.utf8.rawValue)

      jqueryInclude = "<script>\(jqueryString)</script>"
      signalRInclude = "<script>\(signalRString)</script>"
      jsInclude = "<script>\(jsString)</script>"
      #endif

      let config = WKWebViewConfiguration()
      config.userContentController.add(self, name: "interOp")
      config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

      wkWebView = WKWebView(frame: CGRect.zero, configuration: config)
      wkWebView.navigationDelegate = self

      let html = "<!doctype html><html><head></head><body>"
        + "\(jqueryInclude)\(signalRInclude)\(jsInclude)"
        + "</body></html>"

      wkWebView.loadHTMLString(html, baseURL: bundle.bundleURL)
    }

    if let ua = customUserAgent {
      applyUserAgent(ua)
    }

    SwiftR.connections.append(self)
  }

  deinit {
    if let view = wkWebView {
      view.removeFromSuperview()
    }
  }

  open func createHubProxy(_ name: String) -> Hub {
    let hub = Hub(name: name, connection: self)
    hubs[name.lowercased()] = hub
    return hub
  }

  open func addHub(_ hub: Hub) {
    hub.connection = self
    hubs[hub.name.lowercased()] = hub
  }

  open func send(_ data: Any?) {
    var json = "null"
    if let d = data {
      if let val = SignalR.stringify(d) {
        json = val
      }
    }
    runJavaScript("swiftR.connection.send(\(json))")
  }

  open func start() {
    if ready {
      runJavaScript("start()")
    } else {
      connect()
    }
  }

  open func stop() {
    runJavaScript("swiftR.connection.stop()")
  }

  func processMessage(_ json: [String: Any]) {
    if let message = json["message"] as? String {
      switch message {
      case "ready":
        let isHub = connectionType == .hub ? "true" : "false"
        runJavaScript("swiftR.transport = '\(transport.stringValue)'")
        runJavaScript("initialize('\(baseUrl)', \(isHub))")
        readyHandler(self)
        runJavaScript("start()")
      case "starting":
        state = .connecting
        starting?()
      case "connected":
        state = .connected
        connectionID = json["connectionId"] as? String
        connected?()
      case "disconnected":
        state = .disconnected
        disconnected?()
      case "connectionSlow":
        connectionSlow?()
      case "connectionFailed":
        connectionFailed?()
      case "reconnecting":
        state = .connecting
        reconnecting?()
      case "reconnected":
        state = .connected
        reconnected?()
      case "invokeHandler":
        let hubName = json["hub"] as! String
        if let hub = hubs[hubName] {
          let uuid = json["id"] as! String
          let result = json["result"]
          let error = json["error"] as AnyObject?
          if let callback = hub.invokeHandlers[uuid] {
            callback(result as AnyObject?, error)
            hub.invokeHandlers.removeValue(forKey: uuid)
          } else if let e = error {
            print("SwiftR invoke error: \(e)")
          }
        }
      case "error":
        if let err = json["error"] as? [String: Any] {
          error?(err)
        } else {
          error?(nil)
        }
      default:
        break
      }
    } else if let data: Any = json["data"] {
      received?(data)
    } else if let hubName = json["hub"] as? String {
      let callbackID = json["id"] as? String
      let method = json["method"] as? String
      let arguments = json["arguments"] as? [AnyObject]
      let hub = hubs[hubName]

      if let method = method, let callbackID = callbackID, let handlers = hub?.handlers[method], let handler = handlers[callbackID] {
        handler(arguments)
      }
    }
  }

  func runJavaScript(_ script: String, callback: ((Any?) -> ())? = nil) {
    guard wkWebView != nil else {
      jsQueue.append((script, callback))
      return
    }

    if useWKWebView {
      wkWebView.evaluateJavaScript(script, completionHandler: { (result, _)  in
        callback?(result)
      })
    }
  }

  func applyUserAgent(_ userAgent: String) {
    #if os(iOS)
    if useWKWebView {
      if #available(iOS 9.0, *) {
        wkWebView.customUserAgent = userAgent
      } else {
        print("Unable to set user agent for WKWebView on iOS <= 8. Please register defaults via NSUserDefaults instead.")
      }
    } else {
      print("Unable to set user agent for UIWebView. Please register defaults via NSUserDefaults instead.")
    }
    #else
    if useWKWebView {
      if #available(OSX 10.11, *) {
        wkWebView.customUserAgent = userAgent
      } else {
        print("Unable to set user agent for WKWebView on OS X <= 10.10.")
      }
    } else {
      webView.customUserAgent = userAgent
    }
    #endif
  }

  // MARK: - WKNavigationDelegate

  // http://stackoverflow.com/questions/26514090/wkwebview-does-not-run-javascriptxml-http-request-with-out-adding-a-parent-vie#answer-26575892
  open func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    #if os(iOS)
    UIApplication.shared.keyWindow?.addSubview(wkWebView)
    #endif
  }

  // MARK: - WKScriptMessageHandler

  open func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    if let id = message.body as? String {
      wkWebView.evaluateJavaScript("readMessage('\(id)')", completionHandler: { [weak self] (msg, err) in
        if let m = msg as? [String: Any] {
          self?.processMessage(m)
        } else if let e = err {
          print("SwiftR unable to process message \(id): \(e)")
        } else {
          print("SwiftR unable to process message \(id)")
        }
      })
    }
  }

  // MARK: - Web delegate methods

  #if os(iOS)

  #else
  public func webView(_ webView: WebView!, decidePolicyForNavigationAction actionInformation: [AnyHashable : Any]!, request: URLRequest!, frame: WebFrame!, decisionListener listener: WebPolicyDecisionListener!) {

    if shouldHandleRequest(request as URLRequest) {
      listener.use()
    }
  }
  #endif

  class func stringify(_ obj: Any) -> String? {
    // Using an array to start with a valid top level type for NSJSONSerialization
    let arr = [obj]
    if let data = try? JSONSerialization.data(withJSONObject: arr, options: JSONSerialization.WritingOptions()) {
      if let str = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String? {
        // Strip the array brackets to be left with the desired value
        let range = str.index(str.startIndex, offsetBy: 1) ..< str.index(str.endIndex, offsetBy: -1)
        //return str.substring(with: range)
        return String(str[range])
      }
    }
    return nil
  }
}

// MARK: - Hub

open class Hub: NSObject {
  let name: String
  var handlers: [String: [String: ([Any]?) -> ()]] = [:]
  var invokeHandlers: [String: (_ result: Any?, _ error: AnyObject?) -> ()] = [:]
  var connection: SignalR!

  public init(_ name: String) {
    self.name = name
    self.connection = nil
  }

  init(name: String, connection: SignalR) {
    self.name = name
    self.connection = connection
  }

  open func on(_ method: String, callback: @escaping ([Any]?) -> ()) {
    let callbackID = UUID().uuidString

    if handlers[method] == nil {
      handlers[method] = [:]
    }

    handlers[method]?[callbackID] = callback
  }

  func initialize() {
    for (method, callbacks) in handlers {
      callbacks.forEach { connection.runJavaScript("addHandler('\($0.key)', '\(name)', '\(method)')") }
    }
  }

  open func invoke(_ method: String, arguments: [Any]? = nil, callback: ((_ result: Any?, _ error: Any?) -> ())? = nil) throws {
    guard connection != nil else {
      throw SwiftRError.notConnected
    }

    var jsonArguments = [String]()

    if let args = arguments {
      for arg in args {
        if let val = SignalR.stringify(arg) {
          jsonArguments.append(val)
        } else {
          jsonArguments.append("null")
        }
      }
    }

    let args = jsonArguments.joined(separator: ", ")

    let uuid = UUID().uuidString
    if let handler = callback {
      invokeHandlers[uuid] = handler
    }

    let doneJS = "function() { postMessage({ message: 'invokeHandler', hub: '\(name.lowercased())', id: '\(uuid)', result: arguments[0] }); }"
    let failJS = "function() { postMessage({ message: 'invokeHandler', hub: '\(name.lowercased())', id: '\(uuid)', error: processError(arguments[0]) }); }"
    let js = args.isEmpty
      ? "ensureHub('\(name)').invoke('\(method)').done(\(doneJS)).fail(\(failJS))"
      : "ensureHub('\(name)').invoke('\(method)', \(args)).done(\(doneJS)).fail(\(failJS))"

    connection.runJavaScript(js)
  }

}

public enum SignalRVersion : CustomStringConvertible {
  case v2_4_1
  case v2_2_1
  case v2_2_0

  public var description: String {
    switch self {
    case .v2_4_1: return "2.4.1"
    case .v2_2_1: return "2.2.1"
    case .v2_2_0: return "2.2.0"
    }
  }
}

#if os(iOS)
//typealias SwiftRWebView = UIWebView
//public protocol SwiftRWebDelegate: WKNavigationDelegate, WKScriptMessageHandler, UIWebViewDelegate {}
#else
typealias SwiftRWebView = WebView
public protocol SwiftRWebDelegate: WKNavigationDelegate, WKScriptMessageHandler, WebPolicyDelegate {}
#endif


