import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../Service/package_app_model.dart';

class AppTile extends StatelessWidget {
  final PackageApp app;
  final bool isBlocked;
  final ValueChanged<bool> onChanged;

  const AppTile({
    super.key,
    required this.app,
    required this.isBlocked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: app.icon.isNotEmpty
          ? Image.memory(app.icon, width: 40, height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.apps, size: 40),)
          : const Icon(Icons.apps, size: 40),
      title: Text(app.appName),
      subtitle: Text(app.packageName),
      trailing: Checkbox(
        value: isBlocked,
        onChanged: (selected) => onChanged(selected ?? false),
      ),
    );
  }
}
