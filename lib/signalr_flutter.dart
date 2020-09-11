import 'dart:async';
import 'package:flutter/services.dart';

enum Transport { Auto, ServerSentEvents, LongPolling }

/// A .Net SignalR Client for Flutter.
class SignalR {
  final String baseUrl;
  final String queryString;
  final String hubName;
  final Transport transport;
  final Map<String, String> headers;

  /// This callback gets called whenever SignalR connection status with server changes.
  final Function(String) statusChangeCallback;

  /// This callback gets called whenever SignalR server sends some message to client.
  final Function(dynamic) hubCallback;

  static const MethodChannel _channel = const MethodChannel('signalR');

  static const String CONNECTION_STATUS = "ConnectionStatus";
  static const String NEW_MESSAGE = "NewMessage";

  SignalR(this.baseUrl, this.hubName,
      {this.queryString,
      this.headers,
      this.transport = Transport.Auto,
      this.statusChangeCallback,
      this.hubCallback})
      : assert(baseUrl != null && baseUrl != ''),
        assert(hubName != null && hubName != '');

  /// Connect to the SignalR Server with given [baseUrl] & [hubName].
  ///
  /// [queryString] is a optional field to send query to server.
  Future<bool> connect() async {
    try {
      final result = await _channel
          .invokeMethod<bool>("connectToServer", <String, dynamic>{
        'baseUrl': baseUrl,
        'hubName': hubName,
        'queryString': queryString ?? "",
        'headers': headers ?? {},
        'transport': transport.index
      });

      _signalRCallbackHandler();

      return result;
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  /// Try to Reconnect SignalR connection if it gets disconnected.
  void reconnect() async {
    try {
      await _channel.invokeMethod("reconnect");
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  /// Stop SignalR connection
  void stop() async {
    try {
      await _channel.invokeMethod("stop");
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  /// Subscribe to a Hub method. Every subsequent message from server gets called on [hubCallback].
  void subscribeToHubMethod(String methodName) async {
    try {
      await _channel.invokeMethod("listenToHubMethod", methodName);
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  /// Invoke any server method with optional [arguments].
  Future invokeMethod(String methodName, {List<String> arguments}) async {
    try {
      final result = await _channel.invokeMethod("invokeServerMethod",
          <String, dynamic>{'methodName': methodName, 'arguments': arguments});
      return result;
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  /// Listen for any message from native side and pass that to proper callbacks.
  void _signalRCallbackHandler() {
    _channel.setMethodCallHandler((call) {
      switch (call.method) {
        case CONNECTION_STATUS:
          statusChangeCallback(call.arguments);
          break;
        case NEW_MESSAGE:
          //print(call.arguments[0]);
          hubCallback(call.arguments);
          break;
        default:
      }
      return;
    });
  }
}
