import 'package:flutter/material.dart';
import 'core/app.dart';
import 'core/app_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final mode = await AppMode.load();
  runApp(MoeenApp(initialMode: mode));
}
