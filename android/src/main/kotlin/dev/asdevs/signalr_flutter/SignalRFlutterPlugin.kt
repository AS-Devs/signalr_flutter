package dev.asdevs.signalr_flutter

import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import microsoft.aspnet.signalr.client.ConnectionState
import microsoft.aspnet.signalr.client.Credentials
import microsoft.aspnet.signalr.client.LogLevel
import microsoft.aspnet.signalr.client.SignalRFuture
import microsoft.aspnet.signalr.client.hubs.HubConnection
import microsoft.aspnet.signalr.client.hubs.HubProxy
import microsoft.aspnet.signalr.client.transport.LongPollingTransport
import microsoft.aspnet.signalr.client.transport.ServerSentEventsTransport
import java.lang.Exception

/** SignalrFlutterPlugin */
class SignalrFlutterPlugin : FlutterPlugin, SignalrApi.SignalRHostApi {
    private lateinit var connection: HubConnection
    private lateinit var hub: HubProxy

    private lateinit var signalrApi: SignalrApi.SignalRPlatformApi

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        SignalrApi.SignalRHostApi.setup(flutterPluginBinding.binaryMessenger, this);
        signalrApi = SignalrApi.SignalRPlatformApi(flutterPluginBinding.binaryMessenger)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        SignalrApi.SignalRHostApi.setup(binding.binaryMessenger, null);
    }

    override fun connect(
        connectionOptions: SignalrApi.ConnectionOptions?,
        result: SignalrApi.Result<String>?
    ) {
        try {
            connectionOptions ?: throw NullPointerException()

            connection =
                if (connectionOptions.queryString != null && connectionOptions.queryString.isNotEmpty()) {
                    HubConnection(
                        connectionOptions.baseUrl,
                        connectionOptions.queryString,
                        true
                    ) { _: String, _: LogLevel ->
                    }
                } else {
                    HubConnection(connectionOptions.baseUrl)
                }

            if (connectionOptions.headers != null && connectionOptions.headers.isNotEmpty()) {
                val cred = Credentials { request ->
                    request.headers = connectionOptions.headers
                }
                connection.credentials = cred
            }

            hub = connection.createHubProxy(connectionOptions.hubName)

            connectionOptions.hubMethods.forEach { methodName ->
                hub.on(methodName, { res ->
                    Handler(Looper.getMainLooper()).post {
                        signalrApi.onNewMessage(methodName, res) { }
                    }
                }, String::class.java)
            }

            connection.connected {
                Handler(Looper.getMainLooper()).post {
                    val statusChangeResult = SignalrApi.StatusChangeResult()
                    statusChangeResult.connectionId = connection.connectionId
                    statusChangeResult.status = SignalrApi.ConnectionStatus.connected
                    signalrApi.onStatusChange(statusChangeResult) { }
                }
            }

            connection.reconnected {
                Handler(Looper.getMainLooper()).post {
                    val statusChangeResult = SignalrApi.StatusChangeResult()
                    statusChangeResult.connectionId = connection.connectionId
                    statusChangeResult.status = SignalrApi.ConnectionStatus.connected
                    signalrApi.onStatusChange(statusChangeResult) { }
                }
            }

            connection.reconnecting {
                Handler(Looper.getMainLooper()).post {
                    val statusChangeResult = SignalrApi.StatusChangeResult()
                    statusChangeResult.connectionId = connection.connectionId
                    statusChangeResult.status = SignalrApi.ConnectionStatus.reconnecting
                    signalrApi.onStatusChange(statusChangeResult) { }
                }
            }

            connection.closed {
                Handler(Looper.getMainLooper()).post {
                    val statusChangeResult = SignalrApi.StatusChangeResult()
                    statusChangeResult.connectionId = connection.connectionId
                    statusChangeResult.status = SignalrApi.ConnectionStatus.disconnected
                    signalrApi.onStatusChange(statusChangeResult) { }
                }
            }

            connection.connectionSlow {
                Handler(Looper.getMainLooper()).post {
                    val statusChangeResult = SignalrApi.StatusChangeResult()
                    statusChangeResult.connectionId = connection.connectionId
                    statusChangeResult.status = SignalrApi.ConnectionStatus.connectionSlow
                    signalrApi.onStatusChange(statusChangeResult) { }
                }
            }

            connection.error { handler ->
                Handler(Looper.getMainLooper()).post {
                    val statusChangeResult = SignalrApi.StatusChangeResult()
                    statusChangeResult.status = SignalrApi.ConnectionStatus.connectionError
                    statusChangeResult.errorMessage = handler.localizedMessage
                    signalrApi.onStatusChange(statusChangeResult) { }
                }
            }

            when (connectionOptions.transport) {
                SignalrApi.Transport.serverSentEvents -> connection.start(
                    ServerSentEventsTransport(
                        connection.logger
                    )
                )
                SignalrApi.Transport.longPolling -> connection.start(LongPollingTransport(connection.logger))
                else -> {
                    connection.start()
                }
            }

            result?.success(connection.connectionId ?: "")
        } catch (ex: Exception) {
            result?.error(ex)
        }
    }

    override fun reconnect(result: SignalrApi.Result<String>?) {
        try {
            connection.start()
            result?.success(connection.connectionId ?: "")
        } catch (ex: Exception) {
            result?.error(ex)
        }
    }

    override fun stop(result: SignalrApi.Result<Void>?) {
        try {
            connection.stop()
        } catch (ex: Exception) {
            result?.error(ex)
        }
    }

    override fun isConnected(result: SignalrApi.Result<Boolean>?) {
        try {
            if (this::connection.isInitialized) {
                when (connection.state) {
                    ConnectionState.Connected -> result?.success(true)
                    else -> result?.success(false)
                }
            } else {
                result?.success(false)
            }
        } catch (ex: Exception) {
            result?.error(ex)
        }
    }

    override fun invokeMethod(
        methodName: String?,
        arguments: MutableList<String>?,
        result: SignalrApi.Result<String>?
    ) {
        try {
            arguments ?: throw NullPointerException()
            val res: SignalRFuture<String> =
                hub.invoke(String::class.java, methodName, *arguments.toTypedArray())

            res.done { msg: String? ->
                Handler(Looper.getMainLooper()).post {
                    result?.success(msg ?: "")
                }
            }

            res.onError { throwable ->
                throw throwable
            }
        } catch (ex: Exception) {
            result?.error(ex)
        }
    }
}
