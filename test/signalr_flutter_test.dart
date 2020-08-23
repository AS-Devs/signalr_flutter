import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalr_flutter/signalr_flutter.dart';

void main() async {
  const MethodChannel channel = MethodChannel('signalR');
  final SignalR signalR = SignalR('Url', "hubName");

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      switch (methodCall.method) {
        case "connectToServer":
          return true;
          break;
        case "invokeServerMethod":
          return <String, dynamic>{
            'baseUrl': "123",
            "hubName": "456",
          };
        default:
          return PlatformException(
              code: "Error",
              message:
                  "No implementation found for method ${methodCall.method}");
      }
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  group('SignalR Test', () {
    test('Connect SignalR', () async {
      final result = await signalR.connect();
      expect(result, true);
    });

    test('Invoke Server Method', () async {
      final result = await signalR.invokeMethod("methodName", arguments: null);
      expect(result, <String, dynamic>{
        'baseUrl': "123",
        "hubName": "456",
      });
    });
  });
}

