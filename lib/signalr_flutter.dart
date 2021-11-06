import 'dart:async';

import 'package:flutter/services.dart';
import 'package:signalr_flutter/signalr_api.dart';
import 'package:signalr_flutter/signalr_platform_interface.dart';

class SignalR implements SignalRPlatformApi, SignalrPlatformInterface {
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
  final Function(ConnectionStatus?)? statusChangeCallback;

  /// This callback gets called whenever SignalR server sends some message to client.
  final Function(String, String)? hubCallback;

  // Private variables
  static late final SignalRHostApi _signalrApi = SignalRHostApi();

  SignalR(this.baseUrl, this.hubName,
      {this.queryString,
      this.headers,
      this.hubMethods,
      this.transport = Transport.auto,
      this.statusChangeCallback,
      this.hubCallback})
      : assert(baseUrl != ''),
        assert(hubName != '');

  //---- Callback Methods ----//
  // ------------------------//
  @override
  Future<void> onNewMessage(String hubName, String message) async {
    if (hubCallback != null) {
      hubCallback!(hubName, message);
    }
  }

  @override
  Future<void> onStatusChange(StatusChangeResult statusChangeResult) async {
    connectionId = statusChangeResult.connectionId;

    if (statusChangeCallback != null) {
      statusChangeCallback!(statusChangeResult.status);
    }

    if (statusChangeResult.errorMessage != null) {
      throw PlatformException(code: 'channel-error', message: statusChangeResult.errorMessage);
    }
  }

  //---- Public Methods ----//
  // ------------------------//
  @override
  Future<String?> connect() async {
    try {
      // Construct ConnectionOptions
      ConnectionOptions options = ConnectionOptions();
      options.baseUrl = baseUrl;
      options.hubName = hubName;
      options.queryString = queryString;
      options.hubMethods = hubMethods;
      options.headers = headers;
      options.transport = transport;

      connectionId = await _signalrApi.connect(options);

      return connectionId;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String?> reconnect() async {
    try {
      connectionId = await _signalrApi.reconnect();
      return connectionId;
    } catch (e) {
      rethrow;
    }
  }

  @override
  void stop() async {
    try {
      await _signalrApi.stop();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> isConnected() async {
    try {
      return await _signalrApi.isConnected();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String> invokeMethod(String methodName, {List<String>? arguments}) async {
    try {
      return await _signalrApi.invokeMethod(methodName, arguments ?? List.empty());
    } catch (e) {
      rethrow;
    }
  }
}
