// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:signalr_flutter/signalr_api.dart';
import 'package:signalr_flutter/signalr_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String signalRStatus = "disconnected";
  late SignalR signalR;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    signalR = SignalR(
      "<Your server url here>",
      "<Your hub name here>",
      hubMethods: ["<Your Hub Method Names>"],
      statusChangeCallback: _onStatusChange,
      hubCallback: _onNewMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("SignalR Plugin Example App"),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text("Connection Status: $signalRStatus\n",
                  style: Theme.of(context).textTheme.headline6),
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: ElevatedButton(onPressed: _buttonTapped, child: const Text("Invoke Method")),
              )
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.cast_connected),
          onPressed: () async {
            final isConnected = await signalR.isConnected();
            if (!isConnected) {
              final connId = await signalR.connect();
              print("Connection ID: $connId");
            } else {
              signalR.stop();
            }
          },
        ),
      ),
    );
  }

  void _onStatusChange(ConnectionStatus? status) {
    if (mounted) {
      setState(() {
        signalRStatus = describeEnum(status ?? ConnectionStatus.disconnected);
      });
    }
  }

  void _onNewMessage(String methodName, String message) {
    print("MethodName = $methodName, Message = $message");
  }

  void _buttonTapped() async {
    try {
      final result =
          await signalR.invokeMethod("<Your Method Name>", arguments: ["<Your Method Arguments>"]);
      print(result);
    } catch (e) {
      print(e);
    }
  }
}
