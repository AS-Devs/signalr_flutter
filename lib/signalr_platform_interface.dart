import 'package:signalr_flutter/signalr_api.dart';

abstract class SignalrPlatformInterface {
  SignalrPlatformInterface(this.baseUrl, this.hubName,
      {this.queryString,
      this.headers,
      this.hubMethods,
      this.transport = Transport.auto,
      this.statusChangeCallback,
      this.hubCallback})
      : assert(baseUrl != ''),
        assert(hubName != '');

  final String baseUrl;
  final String hubName;
  final String? queryString;

  /// [Transport.Auto] is default.
  final Transport transport;
  final Map<String, String>? headers;

  String? connectionId;

  /// List of Hub method names you want to subscribe. Every subsequent message from server gets called on [hubCallback].
  final List<String>? hubMethods;

  /// This callback gets called whenever SignalR connection status with server changes.
  final void Function(ConnectionStatus?)? statusChangeCallback;

  /// This callback gets called whenever SignalR server sends some message to client.
  final void Function(String, String)? hubCallback;

  /// Connect to the SignalR Server with given [baseUrl] & [hubName].
  ///
  /// [queryString] is a optional field to send query to server.
  ///
  /// Returns the [connectionId].
  Future<String?> connect();

  /// Try to Reconnect SignalR connection if it gets disconnected.
  ///
  /// Returns the [connectionId]
  Future<String?> reconnect();

  /// Stops SignalR connection
  void stop();

  /// Checks if SignalR connection is still active.
  ///
  /// Returns a boolean value
  Future<bool> isConnected();

  /// Invoke any server method with optional [arguments].
  Future<String> invokeMethod(String methodName, {List<String>? arguments});
}
