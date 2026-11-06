import 'package:shared_preferences/shared_preferences.dart';

/// مخزن مفتاح/قيمة على الهاتف والحاسوب (خارج المتصفح).
class KvStore {
  KvStore._(this._prefs);
  final SharedPreferences _prefs;

  static Future<KvStore> open() async => KvStore._(await SharedPreferences.getInstance());

  /// نوع التخزين (للعرض في الإعدادات).
  String get backend => 'ذاكرة الجهاز';

  /// هل المتصفح يحمي البيانات من المسح التلقائي؟ (غير منطبق هنا)
  bool? get persisted => null;

  String? getString(String key) => _prefs.getString(key);

  Future<void> setMany(Map<String, String> values) async {
    for (final e in values.entries) {
      if (_prefs.getString(e.key) == e.value) continue;
      final ok = await _prefs.setString(e.key, e.value);
      if (!ok) throw StateError('write failed');
    }
  }

  Future<void> setString(String key, String value) => setMany({key: value});

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
