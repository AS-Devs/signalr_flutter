package dev.asdevs.signalr_flutter

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel.Result
import microsoft.aspnet.signalr.client.*
import microsoft.aspnet.signalr.client.hubs.HubConnection
import microsoft.aspnet.signalr.client.hubs.HubProxy
import microsoft.aspnet.signalr.client.transport.LongPollingTransport
import microsoft.aspnet.signalr.client.transport.ServerSentEventsTransport

enum class CallMethod(val value: String) {
    ConnectToServer("connectToServer"),
    Reconnect("reconnect"),
    Stop("stop"),
    IsConnected("isConnected"),
    ListenToHubMethod("listenToHubMethod"),
    InvokeServerMethod("invokeServerMethod")
}

object SignalR {
    private lateinit var connection: HubConnection
    private lateinit var hub: HubProxy

    fun connectToServer(url: String, hubName: String, queryString: String, headers: Map<String, String>, transport: Int, hubMethods: List<String>, result: Result) {
        try {
            connection = if (queryString.isEmpty()) {
                HubConnection(url)
            } else {
                HubConnection(url, queryString, true, Logger { _: String, _: LogLevel ->
                })
            }

            if (headers.isNotEmpty()) {
                val cred = Credentials() { request ->
                    request.headers = headers
                }
                connection.credentials = cred
            }
            hub = connection.createHubProxy(hubName)

            hubMethods.forEach { methodName ->
                hub.on(methodName, { res ->
                    Handler(Looper.getMainLooper()).post {
                        SignalRFlutterPlugin.channel.invokeMethod("NewMessage", listOf(methodName, res))
                    }
                }, Any::class.java)
            }

            connection.connected {
                Handler(Looper.getMainLooper()).post {
                    SignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", listOf(connection.state.name, connection.connectionId, null))
                }
            }

            connection.reconnected {
                Handler(Looper.getMainLooper()).post {
                    SignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", listOf(connection.state.name, connection.connectionId, null))
                }
            }

            connection.reconnecting {
                Handler(Looper.getMainLooper()).post {
                    SignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", listOf(connection.state.name, connection.connectionId, null))
                }
            }

            connection.closed {
                Handler(Looper.getMainLooper()).post {
                    SignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", listOf(connection.state.name, null, null))
                }
            }

            connection.connectionSlow {
                Handler(Looper.getMainLooper()).post {
                    SignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", listOf("ConnectionSlow", connection.connectionId, null))
                }
            }

            connection.error { handler ->
                Handler(Looper.getMainLooper()).post {
                    SignalRFlutterPlugin.channel.invokeMethod("ConnectionStatus", listOf("ConnectionError", null, handler.localizedMessage))
                }
            }

            when (transport) {
                1 -> connection.start(ServerSentEventsTransport(connection.logger))
                2 -> connection.start(LongPollingTransport(connection.logger))
                else -> {
                    connection.start()
                }
            }

            result.success(connection.connectionId)
        } catch (ex: Exception) {
            result.error("Error", ex.localizedMessage, null)
        }
    }

    fun reconnect(result: Result) {
        try {
            connection.start()
            result.success(connection.connectionId)
        } catch (ex: Exception) {
            result.error(ex.localizedMessage, ex.stackTrace.toString(), null)
        }
    }

    fun stop(result: Result) {
        try {
            connection.stop()
        } catch (ex: Exception) {
            result.error(ex.localizedMessage, ex.stackTrace.toString(), null)
        }
    }

    fun isConnected(result: Result) {
        try {
            if (this::connection.isInitialized) {
                when (connection.state) {
                    ConnectionState.Connected -> result.success(true)
                    else -> result.success(false)
                }
            } else {
                result.success(false)
            }
        } catch (ex: Exception) {
            result.error("Error", ex.localizedMessage, null)
        }
    }

    fun listenToHubMethod(methodName: String, result: Result) {
        try {
            hub.on(methodName, { res ->
                Handler(Looper.getMainLooper()).post {
                    SignalRFlutterPlugin.channel.invokeMethod("NewMessage", listOf(methodName, res))
                }
            }, Any::class.java)
        } catch (ex: Exception) {
            result.error("Error", ex.localizedMessage, null)
        }
    }

    fun invokeServerMethod(methodName: String, args: List<Any>, result: Result) {
        try {
            val res: SignalRFuture<Any> = hub.invoke(Any::class.java, methodName, *args.toTypedArray())

            res.done { msg: Any? ->
                Handler(Looper.getMainLooper()).post {
                    result.success(msg)
                }
            }

            res.onError { throwable ->
                Handler(Looper.getMainLooper()).post {
                    result.error("Error", throwable.localizedMessage, null)
                }
            }
        } catch (ex: Exception) {
            result.error("Error", ex.localizedMessage, null)
        }
    }
}