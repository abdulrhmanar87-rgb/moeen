import 'package:flutter/material.dart';
import 'core/app.dart';
import 'core/storage/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.init();
  runApp(MoeenApp(store: store));
}
