package com.vpnmanager.anton

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.os.Build
//import android.util.Log
import kotlinx.coroutines.*


class VpnStatusReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == ConnectivityManager.CONNECTIVITY_ACTION ||
            intent?.action == "android.intent.action.AIRPLANE_MODE") {



            CoroutineScope(Dispatchers.Main).launch {
                delay(1500) // Debounce to allow the stack to settle
                checkVpnStatus(context)
            }
        }
    }
    private fun checkVpnStatus(context: Context) {
        val service = VpnForegroundService.vpnInstance ?: return
        val isAlive = service.isThisVpnStillAlive()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
// id  1 is for vpn active status
        if (isAlive && !isNotificationVisible(manager, 1)) {
            service.vpnActiveNotification()
        }

        if (VpnForegroundService.lastVpnStatus == isAlive) return

        VpnForegroundService.lastVpnStatus = isAlive
        VpnForegroundService.sendStatus(isAlive)

//        Log.d("VpnStatusReceiver", "VPN alive -> $isAlive")

        if (!isAlive) {
            onVpnStoppedExternally(service)
        }
    }


// just re-appear the swipe or remove notification
    private fun isNotificationVisible(manager: NotificationManager, id: Int): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.activeNotifications.any { it.id == id }
        } else {
            true
        }
    }

    companion object {
        fun onVpnStoppedExternally(
            service: VpnForegroundService,

        ) {
            service.vpnNotActiveNotification()
            service.stopFromExternal()
        }
    }
}
