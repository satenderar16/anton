package com.vpnmanager.anton

import android.app.*
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.VpnService
import android.net.NetworkCapabilities
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import java.io.FileInputStream
import java.nio.ByteBuffer

class VpnForegroundService : VpnService() {

    var vpnTunnel: ParcelFileDescriptor? = null
        private set
    private var readJob: Job? = null
    lateinit var statusReceiver: VpnStatusReceiver

    companion object {
        var isRunning = false
        var lastVpnStatus: Boolean? = null
        var eventSink: EventChannel.EventSink? = null
        var vpnInstance: VpnForegroundService? = null
        var disallowedPackages: List<String> = emptyList()

        fun sendStatus(status: Boolean) {
            eventSink?.success(status)
        }
    }

    override fun onCreate() {
        super.onCreate()
        vpnInstance = this
        statusReceiver = VpnStatusReceiver()
        val filter = IntentFilter().apply {
            addAction(ConnectivityManager.CONNECTIVITY_ACTION)
            addAction("android.intent.action.AIRPLANE_MODE")
        }
        registerReceiver(statusReceiver, filter)
    }

    override fun onDestroy() {
        stopVpn()
        unregisterReceiver(statusReceiver)
        vpnInstance = null
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> {
                vpnActiveNotification()
                startVpn()
            }
            "STOP" -> {
                stopVpn()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onRevoke() {
        stopVpn()
        sendStatus(false)
        CoroutineScope(Dispatchers.Main).launch {
            vpnNotActiveNotification()
            stopForeground(true)
            stopSelf()
        }
    }

    private fun startVpn() {
        if (isRunning) return

        val builder = Builder()
            .addAddress("10.1.1.1", 32)
            .addRoute("0.0.0.0", 0)

        for (pkg in disallowedPackages) {
            try {
                packageManager.getPackageInfo(pkg, 0)
                builder.addDisallowedApplication(pkg)
            } catch (e: Exception) {
                Log.w("VPN", "Could not disallow $pkg: ${e.message}")
            }
        }

        vpnTunnel = builder.establish()
        isRunning = true
        sendStatus(true)
        vpnActiveNotification()

        readJob = CoroutineScope(Dispatchers.IO).launch {
            val channel = FileInputStream(vpnTunnel!!.fileDescriptor).channel
            val buf = ByteBuffer.allocate(1024)

            try {
                while (isActive) {
                    val bytes = channel.read(buf)
                    if (bytes <= 0) {
                        triggerVpnStatusCheck()
                        break
                    }
                    buf.clear()
                    delay(500)
                }
            } catch (e: Exception) {
                triggerVpnStatusCheck()
            }
        }
    }

    private fun stopVpn() {
        readJob?.cancel()
        vpnTunnel?.close()
        vpnTunnel = null
        isRunning = false
        sendStatus(false)
        vpnNotActiveNotification()
        stopForeground(true)
        stopSelf()
    }
    fun stopFromExternal() {
        stopVpn()
        stopSelf()
    }

    private suspend fun triggerVpnStatusCheck() {
        withContext(Dispatchers.Main) {
            statusReceiver.onReceive(this@VpnForegroundService, Intent(ConnectivityManager.CONNECTIVITY_ACTION))
        }
    }

    fun isThisVpnStillAlive(): Boolean {
        val isStillPrepared = VpnService.prepare(this) == null
        val tunnelAlive = vpnTunnel?.fileDescriptor?.valid() == true
        val cm = getSystemService(CONNECTIVITY_SERVICE) as? ConnectivityManager
        val active = cm?.allNetworks?.any {
            cm.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
        } == true

        return isRunning && tunnelAlive && isStillPrepared && active
    }

    fun vpnActiveNotification() {
        val channelId = "vpn_active_channel"
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(2)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "VPN Status", NotificationManager.IMPORTANCE_LOW).apply {
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("VPN Active")
            .setContentText("Your VPN is running in the background.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        startForeground(1, notification)
    }

    fun vpnNotActiveNotification(
        title: String = "VPN disconnected",
        contentText: String = "Your VPN connection has been stopped."
    ) {
        val channelId = "vpn_inactive_channel"
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(1)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Foreground Inactive", NotificationManager.IMPORTANCE_DEFAULT)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(contentText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setAutoCancel(false)
            .setOngoing(false)
            .build()

        manager.notify(2, notification)
    }

    fun customNotification(title: String, content: String, silent: Boolean = false) {
        val channelId = "vpn_custom_channel"
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Notifications",
                if (silent) NotificationManager.IMPORTANCE_LOW else NotificationManager.IMPORTANCE_DEFAULT).apply {
                if (silent) {
                    setSound(null, null)
                    enableVibration(false)
                }
            }
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setAutoCancel(true)
            .setSilent(silent)
            .build()

        manager.notify(3, notification)
    }
}
