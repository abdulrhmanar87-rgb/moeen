import 'package:flutter/material.dart';
import 'app_theme.dart';
import '../features/home/home_page.dart';
import 'storage/app_store.dart';

class MoeenApp extends StatelessWidget {
  const MoeenApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مُعين — مساعد الأستاذ',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: HomePage(store: store),
    );
  }
}
