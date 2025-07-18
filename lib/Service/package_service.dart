import 'dart:async';
import 'package:anton/Service/package_app_model.dart';
import 'package:flutter/services.dart';

class PackageService {
  static const MethodChannel _methodChannel =
  MethodChannel('com.vpnmanager.anton/package_method');
  static const EventChannel _eventChannel =
  EventChannel('com.vpnmanager.anton/package_events');

  final List<PackageApp> _apps = [];
  final StreamController<String> _uninstallStream = StreamController.broadcast();
  final StreamController<List<PackageApp>> _appsUpdateStream = StreamController.broadcast();

  Stream<String> get onAppUninstalled => _uninstallStream.stream;
  Stream<List<PackageApp>> get onAppsUpdated => _appsUpdateStream.stream;

  List<PackageApp> get installedApps => List.unmodifiable(_apps);

  PackageService() {
    _listenForPackageEvents();
  }

  /// Fetch all installed apps and store them in [_apps]
  Future<void> fetchInstalledApps() async {
    try {
      final result = await _methodChannel.invokeMethod('getInstalledApps');
      if (result is List) {
        _apps.clear();
        for (var item in result) {
          if (item is Map) {
            final app = PackageApp.fromMap(Map<String, dynamic>.from(item));
            _apps.add(app);
          }
        }
        _appsUpdateStream.add(List.unmodifiable(_apps));
      }
    } catch (e) {
      print('Error fetching apps: $e');
    }
  }

  /// Listens to install/update/uninstall event channel
  void _listenForPackageEvents() {
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final type = event['type'];
        if (type == 'removed') {
          final String packageName = event['packageName'];
          _uninstallStream.add(packageName);

          for (final app in _apps) {
            if (app.packageName == packageName) {
              app.isUninstalled.value = true;
              break;
            }
          }
        } else if (type == 'updated') {
          final List updatedList = event['apps'];
          _apps.clear();
          for (var item in updatedList) {
            if (item is Map) {
              final app = PackageApp.fromMap(Map<String, dynamic>.from(item));
              _apps.add(app);
            }
          }
          _appsUpdateStream.add(List.unmodifiable(_apps));
        }
      }
    }, onError: (e) {
      print('Package event listener error: $e');
    });
  }
}