import 'package:pigeon/pigeon.dart';

/// Transport method of the signalr connection.
enum Transport { auto, serverSentEvents, longPolling }

/// SignalR connection status
enum ConnectionStatus {
  connecting,
  connected,
  reconnecting,
  disconnected,
  connectionSlow,
  connectionError
}

class ConnectionOptions {
  String? baseUrl;
  String? hubName;
  String? queryString;
  List<String?>? hubMethods;
  Map<String?, String?>? headers;
  Transport? transport;
}

class StatusChangeResult {
  String? connectionId;
  ConnectionStatus? status;
  String? errorMessage;
}

@HostApi()
abstract class SignalRHostApi {
  @async
  String connect(ConnectionOptions connectionOptions);

  @async
  String reconnect();

  @async
  void stop();

  @async
  bool isConnected();

  @async
  String invokeMethod(String methodName, List<String?> arguments);
}

@FlutterApi()
abstract class SignalRPlatformApi {
  @async
  void onStatusChange(StatusChangeResult statusChangeResult);

  @async
  void onNewMessage(String hubName, String message);
}

void configurePigeon(PigeonOptions opts) {
  opts = const PigeonOptions(
    input: 'pigeons/signalr_api.dart',
    dartOut: '../lib/signalr_api.dart',
    objcHeaderOut: 'ios/Classes/signalr_api.h',
    objcSourceOut: 'ios/Classes/signalr_api.m',
    javaOut: 'android/src/main/java/dev/asdevs/signalr_flutter/Signalr_Api.java',
  );
}
