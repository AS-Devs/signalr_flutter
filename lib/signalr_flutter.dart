import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_flutter/signalr_api.dart';
import 'package:signalr_flutter/signalr_platform_interface.dart';

class SignalR extends SignalrPlatformInterface implements SignalRPlatformApi {
  // Private variables
  static final SignalRHostApi _signalrApi = SignalRHostApi();
  final Function(String?)? connectionErrorCallback;
  // Constructor
  SignalR(
    super.baseUrl,
    super.hubName, {
    super.queryString,
    super.headers,
    super.hubMethods,
    Transport transport = Transport.auto,
    super.statusChangeCallback,
    super.hubCallback,
    this.connectionErrorCallback,
  });

  //---- Callback Methods ----//
  // ------------------------//
  @override
  Future<void> onNewMessage(String hubName, String message) async {
    hubCallback?.call(hubName, message);
  }

  @override
  Future<void> onStatusChange(StatusChangeResult statusChangeResult) async {
    connectionId = statusChangeResult.connectionId;

    statusChangeCallback?.call(statusChangeResult.status);

    if (statusChangeResult.errorMessage != null) {
      debugPrint('SignalR Error: ${statusChangeResult.errorMessage}');
      connectionErrorCallback?.call(statusChangeResult.errorMessage);
    }
  }

  //---- Public Methods ----//
  // ------------------------//

  /// Connect to the SignalR Server with given [baseUrl] & [hubName].
  ///
  /// [queryString] is a optional field to send query to server.
  ///
  /// Returns the [connectionId].
  @override
  Future<String?> connect() async {
    try {
      // Construct ConnectionOptions
      ConnectionOptions options = ConnectionOptions(
        baseUrl: baseUrl,
        hubName: hubName,
        queryString: queryString,
        hubMethods: hubMethods,
        headers: headers,
        transport: transport,
      );

      // Register SignalR Callbacks
      SignalRPlatformApi.setup(this);

      connectionId = await _signalrApi.connect(options);

      return connectionId;
    } catch (e) {
      return Future.error(e);
    }
  }

  /// Try to Reconnect SignalR connection if it gets disconnected.
  ///
  /// Returns the [connectionId]
  @override
  Future<String?> reconnect() async {
    try {
      connectionId = await _signalrApi.reconnect();
      return connectionId;
    } catch (e) {
      return Future.error(e);
    }
  }

  /// Stops SignalR connection
  @override
  Future<void> stop() async {
    try {
      await _signalrApi.stop();
    } catch (e) {
      return Future.error(e);
    }
  }

  /// Checks if SignalR connection is still active.
  ///
  /// Returns a boolean value
  @override
  Future<bool> isConnected() async {
    try {
      return await _signalrApi.isConnected();
    } catch (e) {
      return Future.error(e);
    }
  }

  /// Invoke any server method with optional [arguments].
  @override
  Future<String> invokeMethod(String methodName, {List<String>? arguments}) async {
    try {
      return await _signalrApi.invokeMethod(methodName, arguments ?? List.empty());
    } catch (e) {
      return Future.error(e);
    }
  }
}
