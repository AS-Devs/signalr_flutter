
import 'dart:async';

import 'package:signalr_flutter/signalr_api.dart';

class SignalrFlutter implements SignalRPlatformApi {
  @override
  Future<void> onNewMessage(String hubName, String message) {
    throw UnimplementedError();
  }

  @override
  Future<void> onStatusChange(StatusChangeResult statusChangeResult) {
    throw UnimplementedError();
  }
}
