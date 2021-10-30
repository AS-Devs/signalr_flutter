import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Transport method of the signalr connection.
enum Transport { Auto, ServerSentEvents, LongPolling }

/// SignalR connection status
enum ConnectionStatus {
  Connecting,
  Connected,
  Reconnecting,
  Disconnected,
  ConnectionSlow,
  ConnectionError
}

extension ConnectionStatusExtension on ConnectionStatus {
  static ConnectionStatus getEnumFromString(String name) {
    return ConnectionStatus.values
        .firstWhere((e) => e.toString() == 'ConnectionStatus.$name');
  }

  /// Get string value of the enum
  String get name => describeEnum(this);
}

/// A .Net SignalR Client for Flutter.
class SignalR {
  final String baseUrl;
  final String? queryString;
  final String hubName;

  /// [Transport.Auto] is default.
  final Transport transport;
  final Map<String, String>? headers;

  String? connectionId;

  /// List of Hub method names you want to subscribe. Every subsequent message from server gets called on [hubCallback].
  final List<String>? hubMethods;

  /// This callback gets called whenever SignalR connection status with server changes.
  final Function(ConnectionStatus)? statusChangeCallback;

  /// This callback gets called whenever SignalR server sends some message to client.
  final Function(String?, dynamic)? hubCallback;

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
      : assert(baseUrl != ''),
        assert(hubName != '');

  /// Connect to the SignalR Server with given [baseUrl] & [hubName].
  ///
  /// [queryString] is a optional field to send query to server.
  ///
  /// Returns the [connectionId].
  Future<String?> connect() async {
    try {
      connectionId = await _channel
          .invokeMethod<String?>("connectToServer", <String, dynamic>{
        'baseUrl': baseUrl,
        'hubName': hubName,
        'queryString': queryString ?? "",
        'headers': headers ?? {},
        'hubMethods': hubMethods ?? [],
        'transport': transport.index
      });

      _signalRCallbackHandler();

      return connectionId;
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message!);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  /// Try to Reconnect SignalR connection if it gets disconnected.
  void reconnect() async {
    try {
      connectionId = await _channel.invokeMethod<String?>("reconnect");
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message!);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  /// Stop SignalR connection
  void stop() async {
    try {
      await _channel.invokeMethod("stop");
      connectionId = null;
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message!);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  Future<bool?> get isConnected async {
    try {
      return await _channel.invokeMethod<bool>("isConnected");
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message!);
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
      await _channel.invokeMethod("listenToHubMethod", methodName);
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message!);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  /// Invoke any server method with optional [arguments].
  Future<T?> invokeMethod<T>(String methodName,
      {List<dynamic>? arguments}) async {
    try {
      final result = await _channel.invokeMethod<T>(
          "invokeServerMethod", <String, dynamic>{
        'methodName': methodName,
        'arguments': arguments ?? List.empty()
      });
      return result;
    } on PlatformException catch (ex) {
      print("Platform Error: ${ex.message}");
      return Future.error(ex.message!);
    } on Exception catch (ex) {
      print("Error: ${ex.toString()}");
      return Future.error(ex.toString());
    }
  }

  /// Listen for any message from native side and pass that to proper callbacks.
  void _signalRCallbackHandler() {
    _channel.setMethodCallHandler((call) {
      try {
        switch (call.method) {
          case CONNECTION_STATUS:
            final connectionStatus =
                ConnectionStatusExtension.getEnumFromString(
                    call.arguments[0] as String);

            // Notify Listeners
            statusChangeCallback!(connectionStatus);

            // Update ConnectionId
            connectionId = call.arguments[1];

            // Print error message if any
            if (call.arguments[2] != null)
              print("SignalR Connection Error: ${call.arguments[2]}");
            break;

          case NEW_MESSAGE:
            if (call.arguments is List) {
              hubCallback!(call.arguments[0], call.arguments[1]);
            } else {
              hubCallback!("", call.arguments);
            }
            break;

          default:
        }
        return Future.value();
      } on Exception catch (ex) {
        print("SignalR Error: ${ex.toString()}");
        return Future.error(ex);
      }
    });
  }
}
