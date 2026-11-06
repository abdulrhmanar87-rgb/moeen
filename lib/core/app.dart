import 'package:flutter/material.dart';
import 'app_mode.dart';
import 'app_theme.dart';
import '../features/admin/admin_home_page.dart';
import '../features/home/home_page.dart';
import '../features/home/mode_choice_page.dart';
import 'storage/app_store.dart';

class MoeenApp extends StatefulWidget {
  const MoeenApp({super.key, required this.initialMode});

  /// null عند أول تشغيل: يُعرض اختيار نوع النسخة.
  final String? initialMode;

  /// التبديل بين نسخة المدرس ونسخة الإدارة (لكل منهما بياناتها المنفصلة).
  static Future<void> switchMode(BuildContext context, String mode) async {
    final state = context.findAncestorStateOfType<_MoeenAppState>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await state?._open(mode);
  }

  @override
  State<MoeenApp> createState() => _MoeenAppState();
}

class _MoeenAppState extends State<MoeenApp> {
  AppStore? _store;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final mode = widget.initialMode;
    if (mode != null) _open(mode);
  }

  Future<void> _open(String mode) async {
    setState(() => _loading = true);
    final store = AppStore(namespace: mode == AppMode.admin ? 'admin' : '');
    await store.init();
    await AppMode.save(mode);
    if (!mounted) return;
    setState(() {
      _store = store;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final Widget home;
    if (store == null) {
      home = _loading || widget.initialMode != null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : ModeChoicePage(onChoose: _open);
    } else if (store.isAdmin) {
      home = AdminHomePage(key: const ValueKey('admin'), store: store);
    } else {
      home = HomePage(key: const ValueKey('teacher'), store: store);
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مُعين — مساعد الأستاذ',
      theme: store?.isAdmin == true ? AppTheme.adminLight : AppTheme.light,
      darkTheme: store?.isAdmin == true ? AppTheme.adminDark : AppTheme.dark,
      themeMode: ThemeMode.system,
      home: home,
    );
  }
}
