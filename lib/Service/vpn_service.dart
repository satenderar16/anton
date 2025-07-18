
import 'package:flutter/services.dart';

class VpnService {
  static const _method = MethodChannel('com.vpnmanager.anton/vpn_method');
  static const _event = EventChannel('com.vpnmanager.anton/vpn_events');

  static Future<void> startVpn({List<String> disallowedPackages = const []}) async {
    await _method.invokeMethod('startVpn', {
      'disallowedPackages': disallowedPackages,
    });
  }

  static Future<void> stopVpn() async {
    await _method.invokeMethod('stopVpn');
  }

  static Future<bool> getStatus() async {
    return await _method.invokeMethod('getStatus');
  }

  static Future<void> sendCustomNotification({
    required String title,
    required String content,
    bool silent = false,
  }) async {
    await _method.invokeMethod('customNotification', {
      'title': title,
      'content': content,
      'silent': silent,
    });
  }

  static Future<void> setDisallowedPackages(List<String> packageList) async {
    try {
      await _method.invokeMethod('setDisallowedPackages', {
        'packages': packageList,
      });
    } catch (e) {
      print("Failed to send disallowed packages: $e");
    }
  }

  static Stream<bool> get onVpnStatusChanged {
    return _event.receiveBroadcastStream().map((event) => event as bool);
  }
}
