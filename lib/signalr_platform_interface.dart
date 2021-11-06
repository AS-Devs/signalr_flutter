abstract class SignalrPlatformInterface {
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
