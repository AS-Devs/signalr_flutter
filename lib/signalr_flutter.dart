
import 'dart:async';

import 'package:flutter/services.dart';

class SignalrFlutter {
  static const MethodChannel _channel = MethodChannel('signalr_flutter');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
