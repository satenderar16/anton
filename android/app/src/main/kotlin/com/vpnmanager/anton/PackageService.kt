package com.vpnmanager.anton

import android.content.*
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class PackageService(private val context: Context) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null

    private val packageReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val packageName = intent?.data?.schemeSpecificPart ?: return
            when (intent.action) {
                Intent.ACTION_PACKAGE_REMOVED -> {
                    eventSink?.success(mapOf("type" to "removed", "packageName" to packageName))
                }
                Intent.ACTION_PACKAGE_ADDED,
                Intent.ACTION_PACKAGE_REPLACED -> {
                    eventSink?.success(mapOf("type" to "updated", "apps" to getInstalledApps()))
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> result.success(getInstalledApps())
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addDataScheme("package")
        }
        context.registerReceiver(packageReceiver, filter)
    }

    override fun onCancel(arguments: Any?) {
        context.unregisterReceiver(packageReceiver)
        eventSink = null
    }

    private fun getInstalledApps(): List<Map<String, Any?>> {
        val pm = context.packageManager
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val apps = mutableListOf<Map<String, Any?>>()

        for (app in packages) {
            val hasLaunchIntent = pm.getLaunchIntentForPackage(app.packageName) != null

            val hasInternetPermission = try {
                pm.getPackageInfo(app.packageName, PackageManager.GET_PERMISSIONS)
                    .requestedPermissions?.contains("android.permission.INTERNET") == true
            } catch (_: Exception) {
                false
            }

            if (!hasLaunchIntent || !hasInternetPermission) continue

            val appName = pm.getApplicationLabel(app).toString()
            val iconDrawable = try {
                pm.getApplicationIcon(app)
            } catch (_: Exception) {
                null
            }

            val iconBytes = iconDrawable?.let { getIconBytes(it) }

            apps.add(
                mapOf(
                    "appName" to appName,
                    "packageName" to app.packageName,
                    "isSystem" to ((app.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                    "icon" to iconBytes
                )
            )
        }

        return apps
    }

    private fun getIconBytes(drawable: Drawable): ByteArray {
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            val bmp = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }

        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
        return outputStream.toByteArray()
    }
}
