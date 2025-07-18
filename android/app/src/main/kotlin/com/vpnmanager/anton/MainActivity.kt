package com.vpnmanager.anton
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
//using it for lastest support and handling the error:
import androidx.activity.result.contract.ActivityResultContracts

class MainActivity : FlutterFragmentActivity() {

    //method and event channels

    private val vpnMethodChannel = "com.vpnmanager.anton/vpn_method"
    private val vpnEventChannel = "com.vpnmanager.anton/vpn_events"
    private val packageMethodChannel = "com.vpnmanager.anton/package_method"
    private val packageEventChannel = "com.vpnmanager.anton/package_events"

    private lateinit var vpnBridge: VpnBridge

    private val vpnPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val isGranted = result.resultCode == RESULT_OK
            vpnBridge.onVpnActivityResult(isGranted)
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        vpnBridge = VpnBridge(this, vpnPermissionLauncher)

        // VPN method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, vpnMethodChannel)
            .setMethodCallHandler { call, result ->
                vpnBridge.handleMethodCall(call, result)
            }

        // VPN event channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, vpnEventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    VpnForegroundService.eventSink = events
                    VpnForegroundService.lastVpnStatus?.let { events?.success(it) }
                }

                override fun onCancel(arguments: Any?) {
                    VpnForegroundService.eventSink = null
                }
            })



        // Package service setup
        val packageService = PackageService(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, packageMethodChannel)
            .setMethodCallHandler(packageService)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, packageEventChannel)
            .setStreamHandler(packageService)
    }
}
