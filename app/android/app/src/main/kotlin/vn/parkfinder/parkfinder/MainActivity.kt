package vn.parkfinder.parkfinder

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CONNECTIVITY_CHANNEL)
            .setStreamHandler(ConnectivityStreamHandler(applicationContext))
    }

    companion object {
        /** Shared with lib/features/lots/connectivity_monitor_io.dart. */
        const val CONNECTIVITY_CHANNEL = "vn.parkfinder/connectivity"
    }
}

/**
 * SPEC-001 US-1.2 AC5: emits one event when a network becomes available
 * after there was none (offline -> online). Carries no data at all.
 */
private class ConnectivityStreamHandler(context: Context) : EventChannel.StreamHandler {
    private val connectivity =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val main = Handler(Looper.getMainLooper())
    private var callback: ConnectivityManager.NetworkCallback? = null

    @Volatile
    private var offline = false

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        offline = !isOnline()
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                if (offline) {
                    offline = false
                    main.post { events.success(null) }
                }
            }

            override fun onLost(network: Network) {
                // Another network may still be up (e.g. Wi-Fi -> mobile).
                main.postDelayed({ if (!isOnline()) offline = true }, 500)
            }
        }
        callback = cb
        try {
            // API 24+, matching flutter.minSdkVersion (24).
            connectivity.registerDefaultNetworkCallback(cb)
        } catch (e: RuntimeException) {
            // No auto retry possible; manual Retry still works.
            callback = null
        }
    }

    override fun onCancel(arguments: Any?) {
        callback?.let {
            try {
                connectivity.unregisterNetworkCallback(it)
            } catch (_: RuntimeException) {
            }
        }
        callback = null
    }

    private fun isOnline(): Boolean {
        val network = connectivity.activeNetwork ?: return false
        val caps = connectivity.getNetworkCapabilities(network) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }
}
