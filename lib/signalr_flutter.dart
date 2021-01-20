import 'dart:async';
import 'package:flutter/services.dart';

/// Transport method of the signalr connection.
enum Transport { Auto, ServerSentEvents, LongPolling }

/// A .Net SignalR Client for Flutter.
class SignalR {
  final String baseUrl;
  final String queryString;
  final String hubName;

  /// [Transport.Auto] is default.
  final Transport transport;
  final Map<String, String> headers;

  /// List of Hub method names you want to subscribe. Every subsequent message from server gets called on [hubCallback].
  final List<String> hubMethods;

  /// This callback gets called whenever SignalR connection status with server changes.
  final Function(dynamic) statusChangeCallback;

  /// This callback gets called whenever SignalR server sends some message to client.
  final Function(String, dynamic) hubCallback;

  static const MethodChannel _channel = const MethodChannel('signalR');

  static const String CONNECTION_STATUS = "ConnectionStatus";
  static const String NEW_MESSAGE = "NewMessage";

  SignalR(this.baseUrl, this.hubName,
      {this.queryString,
      this.headers,
      this.hubMethods,
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
        'hubMethods': hubMethods ?? [],
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

  @Deprecated(
      "This method no longer works on iOS. For now it may work on Android but this will be removed later. Consider using constructor parameter [hubMethods]")

  /// Subscribe to a Hub method. Every subsequent message from server gets called on [hubCallback].
  void subscribeToHubMethod(String methodName) async {
    try {
      assert(methodName != null, "methodName can not be null.");
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
  ///
  /// [arguments] can have maximum of 10 elements in it.
  Future<T> invokeMethod<T>(String methodName,
      {List<dynamic> arguments}) async {
    try {
      assert(methodName != null, "methodName can not be null.");
      final result = await _channel.invokeMethod<T>(
          "invokeServerMethod", <String, dynamic>{
        'methodName': methodName,
        'arguments': arguments ?? List.empty()
      });
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
          if (call.arguments is List) {
            hubCallback(call.arguments[0], call.arguments[1]);
          } else {
            hubCallback("", call.arguments);
          }
          break;
        default:
      }
      return;
    });
  }
}
