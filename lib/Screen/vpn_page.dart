import 'dart:async';

import 'package:anton/Service/vpn_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:anton/theme_provider.dart';
import '../data_utili.dart';

class VpnPage extends StatefulWidget {
  const VpnPage({super.key});

  @override
  State<VpnPage> createState() => _VpnPageState();
}

class _VpnPageState extends State<VpnPage> with WidgetsBindingObserver {
  bool _vpnActive = false;
  Set<String> _disallowedPackages = {};
  late final StreamSubscription<bool> _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getInitialVpnStatus();
    // _loadDisallowedPackages();
    _subscription = VpnService.onVpnStatusChanged.listen((status) {
      if (mounted) setState(() => _vpnActive = status);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _getInitialVpnStatus() async {
    try {
      final status = await VpnService.getStatus();
      if (mounted) setState(() => _vpnActive = status);
    } catch (_) {}
  }

  Future<void> _loadDisallowedPackages() async {
    final saved = await AppPreferences.loadDisallowedPackages();
    if (mounted) setState(() => _disallowedPackages = saved);
  }

  Future<void> _toggleVpn() async {
    if (_vpnActive) {
      await VpnService.stopVpn();
    } else {
      final granted = await _checkAndRequestPermissions();
      if (granted) {

        try {
          _disallowedPackages = await AppPreferences.loadDisallowedPackages();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load disallowed apps: $e')),
          );
          return;
        }

        await VpnService.startVpn(disallowedPackages: _disallowedPackages.toList());
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Required permissions not granted')),
        );
      }
    }
  }
  Future<bool> _checkAndRequestPermissions() async {
    final toRequest = <Permission>[];

    if (await Permission.notification.isDenied || await Permission.notification.isPermanentlyDenied) {
      toRequest.add(Permission.notification);
    }

    if (toRequest.isEmpty) return true;

    final result = await toRequest.request();

    final allGranted = result.values.every((status) => status.isGranted);
    final anyPermanentlyDenied = result.values.any((status) => status.isPermanentlyDenied);

    if (!allGranted) {
      if (anyPermanentlyDenied) {
        _showOpenSettingsDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission is required to continue.'),
          ),
        );
      }
    }

    return allGranted;
  }

  void _showOpenSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permission Needed'),
        content: const Text(
          'To continue using all features, please enable notifications for this app.\n\n'
              'Go to:\n'
              '  App Info → Notifications → Enable\n\n'
              'This ensures you receive important alerts and updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelectorCard(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final currentMode = themeController.mode;

    Widget _buildOption({
      required String label,
      required ThemeMode mode,
      required IconData icon,
    }) {
      final isSelected = currentMode == mode;
      final colorScheme = Theme.of(context).colorScheme;

      return GestureDetector(
        onTap: () => themeController.setTheme(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 100,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary.withAlpha(30) : colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
              width: isSelected ? 1 : 0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? colorScheme.primary : null),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? colorScheme.primary : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("App Theme", style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                _buildOption(label: "System", mode: ThemeMode.system, icon: Icons.settings),
                _buildOption(label: "Light", mode: ThemeMode.light, icon: Icons.light_mode),
                _buildOption(label: "Dark", mode: ThemeMode.dark, icon: Icons.dark_mode),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVpnStatus() {
    final isActive = _vpnActive;
    final icon = isActive ? Icons.vpn_lock_rounded : Icons.vpn_key_off_outlined;
    final label = isActive ? "ON" : "OFF";
    final color = isActive ? Colors.green : Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 80, color: color),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isActive ? color : null,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Instructions",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              const SizedBox(height: 8),
              _buildBullet("All selected apps have internet access."),
              const SizedBox(height: 4),
              _buildBullet("Select one or more app, then refresh the list to apply any updates.")
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("•  ", style: TextStyle(color: Theme.of(context).colorScheme.outlineVariant)),
        Flexible(
          child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.outlineVariant)),
        ),
      ],
    );
  }

  Widget _buildVpnToggleButton() {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = _vpnActive;
    final icon = isActive ? Icons.stop : Icons.play_arrow;
    final label = isActive ? "Stop VPN" : "Start VPN";
    final color = isActive ? colorScheme.error :null;
    final fgColor = isActive ? colorScheme.onError : null;

    return FloatingActionButton.extended(
      onPressed: _toggleVpn,
      icon: Icon(icon),
      label: Text(label),
      backgroundColor: color,
      foregroundColor: fgColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Anton"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 8),
            child: Image.asset("assets/ant1024.png"),
          ),
        ],
      ),
      floatingActionButton: _buildVpnToggleButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            _buildVpnStatus(),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildThemeSelectorCard(context),
            ),
          ],
        ),
      ),
    );
  }
}
