package dev.asdevs.signalr_flutter

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** SignalRFlutterPlugin */
class SignalRFlutterPlugin : FlutterPlugin, MethodCallHandler {

    companion object {
        lateinit var channel: MethodChannel
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "signalR")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "connectToServer" -> {
                val arguments = call.arguments as Map<*, *>
                SignalR.connectToServer(
                    arguments["baseUrl"] as String,
                    arguments["hubName"] as String,
                    arguments["queryString"] as String,
                    arguments["headers"] as? Map<String, String> ?: emptyMap(),
                    arguments["transport"] as Int,
                    arguments["hubMethods"] as? List<String> ?: emptyList(),
                    result
                )
            }

            "reconnect" -> SignalR.reconnect(result)
            "stop" -> SignalR.stop(result)
            "isConnected" -> SignalR.isConnected(result)
            "listenToHubMethod" -> {
                val methodName = call.arguments as? String
                if (methodName != null) {
                    SignalR.listenToHubMethod(methodName, result)
                } else {
                    result.error("Error", "Invalid method name", null)
                }
            }

            "invokeServerMethod" -> {
                val arguments = call.arguments as Map<*, *>
                SignalR.invokeServerMethod(
                    arguments["methodName"] as String,
                    arguments["arguments"] as? List<Any> ?: emptyList(),
                    result
                )
            }

            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
