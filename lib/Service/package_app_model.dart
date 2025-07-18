import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class PackageApp {
  final String appName;
  final String packageName;
  final bool isSystem;
  final Uint8List icon;
  final ValueNotifier<bool> isUninstalled;

  PackageApp({
    required this.appName,
    required this.packageName,
    required this.isSystem,
    required this.icon,
    required this.isUninstalled,
  });

  factory PackageApp.fromMap(Map<String, dynamic> map) {
    return PackageApp(
      appName: map['appName'] ?? '',
      packageName: map['packageName'] ?? '',
      isSystem: map['isSystem'] ?? false,
      icon: map['icon'] is Uint8List ? map['icon'] : Uint8List(0),
      isUninstalled: ValueNotifier(false),
    );
  }
}
