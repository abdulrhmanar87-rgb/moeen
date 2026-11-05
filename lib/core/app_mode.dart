import 'package:shared_preferences/shared_preferences.dart';

/// نوع النسخة: المدرس (مُعين كما هو) أو الإدارة (جمع درجات كل المواد).
class AppMode {
  AppMode._();

  static const teacher = 'teacher';
  static const admin = 'admin';
  static const _key = 'moeen_app_mode';

  /// النوع المحفوظ، أو null عند أول تشغيل.
  /// من يستخدم مُعين سابقاً (لديه بيانات) يبقى «مدرساً» تلقائياً دون أن يُسأل.
  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == teacher || saved == admin) return saved;
    final hasTeacherData = prefs.getString('moeen_students') != null ||
        prefs.getString('moeen_sections') != null;
    if (hasTeacherData) {
      await prefs.setString(_key, teacher);
      return teacher;
    }
    return null;
  }

  static Future<void> save(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode);
  }
}
