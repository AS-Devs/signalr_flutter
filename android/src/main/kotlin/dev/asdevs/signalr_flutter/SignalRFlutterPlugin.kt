package dev.asdevs.signalr_flutter

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar

/** SignalRFlutterPlugin */
public class SignalRFlutterPlugin : FlutterPlugin, MethodCallHandler {
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "signalR")
        channel.setMethodCallHandler(this);
    }

    // This static function is optional and equivalent to onAttachedToEngine. It supports the old
    // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
    // plugin registration via this function while apps migrate to use the new Android APIs
    // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
    //
    // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
    // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
    // depending on the user's project. onAttachedToEngine or registerWith must both be defined
    // in the same class.
    companion object {
        lateinit var channel: MethodChannel

        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "signalR")
            channel.setMethodCallHandler(SignalRFlutterPlugin())
        }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
          CallMethod.ConnectToServer.value -> {
            val arguments = call.arguments as Map<*, *>
            SignalR.connectToServer(arguments["baseUrl"] as String, arguments["hubName"] as String, arguments["queryString"] as String, result)
          }
          CallMethod.Reconnect.value -> {
            SignalR.reconnect(result)
          }
          CallMethod.Stop.value -> {
            SignalR.stop(result)
          }
          CallMethod.ListenToHubMethod.value -> {
            if (call.arguments is String) {
              val methodName = call.arguments as String
              SignalR.listenToHubMethod(methodName, result)
            } else {
              result.error("Error", "Cast to String Failed", "")
            }
          }
          CallMethod.InvokeServerMethod.value -> {
            val arguments = call.arguments as Map<*, *>
            SignalR.invokeServerMethod(arguments["methodName"] as String, arguments["arguments"], result)
          }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
