# signalr_flutter

A flutter plugin for .net SignalR client.

## Usage

First of all, Initialize SignalR and connect to your server.

```
SignalR signalR = SignalR(
        '<Your server url here>',
        "<Your hub name here>",
        statusChangeCallback: (status) => print(status),
        hubCallback: (message) => print(message));
signalR.connect();
```

Here `statusChangeCallback` will get called whenever connection status with server changes.

`hubCallback` will receive calls from the server if you subscribe to any hub method. You can do that with,

`signalR.subscribeToHubMethod("methodName")`

You can also invoke any server method.

`signalR.invokeMethod("<Your method name here>", arguments: ["argument"])`

For more info check example.

Any issue or PR is always welcome.