import 'dart:async';

import 'package:anton/Service/vpn_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../Widgets/app_tile.dart';
import '../Service/package_app_model.dart';
import '../Service/package_service.dart';
import '../data_utili.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key});

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> with SingleTickerProviderStateMixin {
  final PackageService _packageService = PackageService();
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<Set<String>> _disallowedNotifier = ValueNotifier({});

  String _searchQuery = '';
  bool _isSearching = false;
  bool _loading = true;
  bool? _sortAscending;
  bool _filterOnline = false;
  bool _filterOffline = false;

  List<PackageApp> _allApps = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    final storedDisallowed = await AppPreferences.loadDisallowedPackages();
    _disallowedNotifier.value = {...storedDisallowed};

    _packageService.onAppsUpdated.listen((apps) {
      setState(() {
        _allApps = List.of(apps); //  Make a mutable copy
        _loading = false;
      });

      for (final app in apps) {
        app.isUninstalled.removeListener(() => _onAppUninstalled(app));
        app.isUninstalled.addListener(() => _onAppUninstalled(app));
      }
    });

    _packageService.onAppUninstalled.listen((packageName) {
      setState(() {
        _allApps = List.of(_allApps)..removeWhere((a) => a.packageName == packageName);
      });
    });

    await _packageService.fetchInstalledApps();
  }

  void _onAppUninstalled(PackageApp app) {
    if (app.isUninstalled.value) {
      setState(() {
        _allApps.removeWhere((a) => a.packageName == app.packageName);
      });
    }
  }

  List<PackageApp> _filteredApps(bool Function(PackageApp) predicate) {
    final disallowed = _disallowedNotifier.value;
    var apps = _allApps.where(predicate).toList();

    if (_filterOnline) {
      apps = apps.where((a) => disallowed.contains(a.packageName)).toList();
    } else if (_filterOffline) {
      apps = apps.where((a) => !disallowed.contains(a.packageName)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      apps = apps.where((app) => app.appName.toLowerCase().contains(query)).toList();
    }

    if (_sortAscending != null) {
      apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
      if (_sortAscending == false) apps = apps.reversed.toList();
    }

    return apps;
  }

  void _updateDisallowed(Set<String> updated) {
    _disallowedNotifier.value = Set.from(updated);
    AppPreferences.saveDisallowedPackages(updated);
  }

  void _toggleSelectAll(bool select, List<PackageApp> apps) {
    final updated = Set<String>.from(_disallowedNotifier.value);
    for (var app in apps) {
      if (select) {
        updated.add(app.packageName);
      } else {
        updated.remove(app.packageName);
      }
    }
    _updateDisallowed(updated);
  }

  void _applyFilter({required bool online}) {
    setState(() {
      _filterOnline = online;
      _filterOffline = !online;
    });
  }

  void _clearFilter() => setState(() {
    _filterOnline = false;
    _filterOffline = false;
  });

  void _applySort(bool? ascending) => setState(() => _sortAscending = ascending);

  Future<void> _onUpdateDisallowedListToVpn() async {
    final updated = _disallowedNotifier.value;
    final saved = await AppPreferences.loadDisallowedPackages();
    if (!setEquals(saved, updated)) {
      await AppPreferences.saveDisallowedPackages(updated);
    }

    await VpnService.setDisallowedPackages(updated.toList());
    final isVpnActive = await VpnService.getStatus();

    if (!mounted) return;

    if (isVpnActive) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Restart VPN?"),
          content: const Text("Restart VPN to apply changes?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Later")),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await VpnService.stopVpn();
                await Future.delayed(const Duration(milliseconds: 1200));
                await VpnService.startVpn(disallowedPackages: updated.toList());
              },
              child: const Text("Restart"),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("VPN list updated. Start VPN to apply.")),
      );
    }
  }

  List<Widget>? _buildAppbarAction() {
    if (_isSearching) {
      return [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                keyboardAppearance: Theme.of(context).brightness,
                decoration: const InputDecoration(
                  hintText: "Search apps...",
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchQuery = '';
              _searchController.clear();
            });
          },
        ),
      ];
    }

    return [
      IconButton(
        icon: const Icon(Icons.search),
        onPressed: () => setState(() => _isSearching = true),
      ),
      IconButton(icon: const Icon(Icons.filter_alt_outlined), onPressed: _showFilterBottomSheet),
      IconButton(icon: const Icon(Icons.sort), onPressed: _showSortBottomSheet),
      PopupMenuButton<String>(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        offset: const Offset(0, kToolbarHeight),
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          final apps = _filteredApps(
            _tabController.index == 0
                ? (_) => true
                : _tabController.index == 1
                ? (a) => !a.isSystem
                : (a) => a.isSystem,
          );
          if (value == 'select_all') _toggleSelectAll(true, apps);
          if (value == 'remove_all') _toggleSelectAll(false, apps);
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'select_all',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.select_all, color: Theme.of(context).colorScheme.primary),
              title: const Text('Select All'),
            ),
          ),
          PopupMenuItem(
            value: 'remove_all',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.primary),
              title: const Text('Remove All'),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _onUpdateDisallowedListToVpn,
          icon: const Icon(Icons.sync),
          label: const Text("Update"),
        ),
        appBar: AppBar(
          title: const Text("Manage Apps"),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'All Apps'),
              Tab(text: 'User Apps'),
              Tab(text: 'System Apps'),
            ],
          ),
          actions: _buildAppbarAction(),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          controller: _tabController,
          children: [
            _buildTabContent((_) => true),
            _buildTabContent((a) => !a.isSystem),
            _buildTabContent((a) => a.isSystem),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(bool Function(PackageApp) predicate) {
    final apps = _filteredApps(predicate);
    return Column(
      children: [
        _buildFiltersBar(),
        const Divider(height: 0),
        Expanded(child: _buildTabAppList(apps)),
      ],
    );
  }

  Widget _buildTabAppList(List<PackageApp> apps) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: _disallowedNotifier,
      builder: (_, disallowed, __) {
        final visibleApps = apps.where((app) {
          final isBlocked = disallowed.contains(app.packageName);
          if (_filterOnline && !isBlocked) return false;
          if (_filterOffline && isBlocked) return false;
          return true;
        }).toList();

        if (visibleApps.isEmpty) {
          String message = "No apps available";
          if (_filterOnline) message = "No apps found for Internet On";
          else if (_filterOffline) message = "No apps found for Internet Off";

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/empty_new.png", width: 150, height: 150),
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: apps.length + 1,
          itemBuilder: (context, index) {
            if (index == apps.length) return const SizedBox(height: 100);
            final app = apps[index];
            final isBlocked = disallowed.contains(app.packageName);
            final shouldHide = (_filterOnline && !isBlocked) || (_filterOffline && isBlocked);

            return ValueListenableBuilder<bool>(
              valueListenable: app.isUninstalled,
              builder: (context, isUninstalled, _) {
                if (isUninstalled) return const SizedBox.shrink();

                return AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: shouldHide
                      ? const SizedBox.shrink()
                      : AppTile(
                    key: ValueKey(app.packageName),
                    app: app,
                    isBlocked: isBlocked,
                    onChanged: (selected) {
                      final updated = Set<String>.from(disallowed);
                      if (selected) {
                        updated.add(app.packageName);
                      } else {
                        updated.remove(app.packageName);
                      }
                      _updateDisallowed(updated);
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFiltersBar() {
    final List<Widget> chips = [];

    if (_filterOnline) chips.add(_buildCustomActionChip("Internet On", _clearFilter));
    if (_filterOffline) chips.add(_buildCustomActionChip("Internet Off", _clearFilter));
    if (_sortAscending != null) {
      chips.add(_buildCustomActionChip(
        _sortAscending! ? "Sorted A-Z" : "Sorted Z-A",
            () => _applySort(null),
      ));
    }

    return chips.isEmpty
        ? const SizedBox.shrink()
        : Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        children: chips,
      ),
    );
  }

  Widget _buildCustomActionChip(String label, VoidCallback onPressed) {
    return ActionChip(label: Text(label), avatar: const Icon(Icons.close), onPressed: onPressed);
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Filter Apps", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildSheetListTile("Internet On", Icons.wifi, _filterOnline, () => _applyFilter(online: true)),
            _buildSheetListTile("Internet Off", Icons.wifi_off, _filterOffline, () => _applyFilter(online: false)),
            _buildSheetListTile("Clear Filter", Icons.clear, !_filterOnline && !_filterOffline, _clearFilter),
          ],
        ),
      ),
    );
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Sort Apps", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildSheetListTile("Ascending", Icons.arrow_upward, _sortAscending == true, () => _applySort(true)),
            _buildSheetListTile("Descending", Icons.arrow_downward, _sortAscending == false, () => _applySort(false)),
            _buildSheetListTile("None", Icons.clear, _sortAscending == null, () => _applySort(null)),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetListTile(String label, IconData icon, bool selected, VoidCallback onTap) {
    final color = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Icon(icon, color: selected ? color : null),
      title: Text(
        label,
        style: TextStyle(color: selected ? color : null, fontWeight: selected ? FontWeight.bold : null),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}
