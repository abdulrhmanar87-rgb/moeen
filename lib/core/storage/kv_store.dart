// مخزن البيانات: IndexedDB في المتصفح (سعة كبيرة)، و SharedPreferences في غيره.
export 'kv_store_prefs.dart' if (dart.library.js_interop) 'kv_store_web.dart';
