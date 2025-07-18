package com.vpnmanager.anton

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import androidx.activity.result.ActivityResultLauncher
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class VpnBridge(
    private val activity: Activity,
    private val vpnPermissionLauncher: ActivityResultLauncher<Intent>
) {
    private var vpnResult: MethodChannel.Result? = null

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startVpn" -> {
                vpnResult = result
                val disallowed = call.argument<List<String>>("disallowedPackages") ?: emptyList()
                VpnForegroundService.disallowedPackages = disallowed

                val intent = VpnService.prepare(activity)
                if (intent != null) {
                    vpnPermissionLauncher.launch(intent)
                } else {
                    startVpnService("START")
                    result.success(true)
                }
            }

            "stopVpn" -> {
                startVpnService("STOP")
                result.success(true)
            }

            "getStatus" -> {
                val alive = VpnForegroundService.vpnInstance?.isThisVpnStillAlive() ?: false
                result.success(alive)
            }

            "customNotification" -> {
                val title = call.argument<String>("title") ?: "Notice"
                val content = call.argument<String>("content") ?: "Message"
                val silent = call.argument<Boolean>("silent") ?: false
                VpnForegroundService.vpnInstance?.customNotification(title, content, silent)
                result.success(true)
            }

            "setDisallowedPackages" -> {
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                VpnForegroundService.disallowedPackages = packages
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    fun onVpnActivityResult(success: Boolean) {
        if (success) {
            startVpnService("START")
            vpnResult?.success(true)
        } else {
            vpnResult?.success(false)
        }
    }

    private fun startVpnService(action: String) {
        val intent = Intent(activity, VpnForegroundService::class.java).apply {
            this.action = action
        }

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(activity, intent)
        } else {
            activity.startService(intent)
        }
    }
}
