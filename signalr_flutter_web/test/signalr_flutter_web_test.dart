import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_flutter_web/signalr_flutter_web.dart';

void main() {
  const MethodChannel channel = MethodChannel('signalr_flutter_web');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await SignalrFlutterWeb.platformVersion, '42');
  });
}
