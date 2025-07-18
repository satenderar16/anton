import 'package:flutter/material.dart';
import 'package:anton/Screen/vpn_page.dart';
import 'package:anton/Screen/app_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;

  void _onNavTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          VpnPage(),
          AppScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: const NavigationBarThemeData(height: 64),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onNavTapped,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.security), label: 'VPN'),
            NavigationDestination(icon: Icon(Icons.apps), label: 'Apps'),
          ],
        ),
      ),
    );
  }
}
