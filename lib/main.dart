import 'package:anton/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import 'Screen/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); ///using shared preference
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ThemeController>(context);
    return ThemeScope(
      mode: controller.mode,
      child: MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: controller.mode,
        home: const HomePage(),
      ),
    );
  }
}






