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

@HostApi()
abstract class SignalRHostApi {
  @async
  String connect(
    String baseUrl,
    String hubName, {
    String queryString = "",
    List<String>? hubMethods,
    Map<String, String>? headers,
    Transport transport = Transport.auto,
  });

  @async
  String reconnect();

  @async
  void stop();

  @async
  bool isConnected();

  @async
  T invokeMethod<T>(String methodName, {List<dynamic>? arguments});
}

@FlutterApi()
abstract class SignalRPlatformApi {
  @async
  void onStatusChange(ConnectionStatus connectionStatus, String connectionId, String? errorMessage);

  @async
  void onNewMessage(String hubName, dynamic message);
}

// void configurePigeon(PigeonOptions opts) {
//   opts = const PigeonOptions(
//     dartOut: '../lib/signalr_messages.dart',
//     objcHeaderOut: 'ios/Classes/signalr_messages.h',
//     objcSourceOut: 'ios/Classes/signalr_messages.m',
//     javaOut: 'android/src/main/java/dev/asdevs/signalr_flutter/Signalr_Messages.java',
//   );
// }
