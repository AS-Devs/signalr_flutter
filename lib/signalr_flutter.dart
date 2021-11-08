import 'dart:async';

import 'package:flutter/services.dart';
import 'package:signalr_flutter/signalr_api.dart';
import 'package:signalr_flutter/signalr_platform_interface.dart';

class SignalR extends SignalrPlatformInterface implements SignalRPlatformApi {
  // Private variables
  static late final SignalRHostApi _signalrApi = SignalRHostApi();

  // Constructor
  SignalR(
    String baseUrl,
    String hubName, {
    String? queryString,
    Map<String, String>? headers,
    List<String>? hubMethods,
    Transport transport = Transport.auto,
    void Function(ConnectionStatus?)? statusChangeCallback,
    void Function(String, String)? hubCallback,
  }) : super(baseUrl, hubName,
            queryString: queryString,
            headers: headers,
            hubMethods: hubMethods,
            statusChangeCallback: statusChangeCallback,
            hubCallback: hubCallback);

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

      // Register SignalR Callbacks
      SignalRPlatformApi.setup(this);

      connectionId = await _signalrApi.connect(options);

      return connectionId;
    } catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<String?> reconnect() async {
    try {
      connectionId = await _signalrApi.reconnect();
      return connectionId;
    } catch (e) {
      return Future.error(e);
    }
  }

  @override
  void stop() async {
    try {
      await _signalrApi.stop();
    } catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<bool> isConnected() async {
    try {
      return await _signalrApi.isConnected();
    } catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future<String> invokeMethod(String methodName, {List<String>? arguments}) async {
    try {
      return await _signalrApi.invokeMethod(methodName, arguments ?? List.empty());
    } catch (e) {
      return Future.error(e);
    }
  }
}
