import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:shared_preferences/shared_preferences.dart';

/// مخزن مُعين في المتصفح على IndexedDB.
///
/// - السعة مئات الميغابايتات بدل 5 ميغابايت في localStorage.
/// - كل البيانات تُقرأ مرة واحدة عند الفتح إلى الذاكرة، والكتابة لا تتم
///   إلا للمفاتيح التي تغيّرت، وفي معاملة واحدة (إما تُحفظ كلها أو لا شيء).
/// - أول تشغيل ينقل البيانات القديمة من localStorage دون حذفها.
/// - يطلب من المتصفح حماية البيانات من المسح التلقائي (persist).
/// - إذا تعذر IndexedDB يعود إلى localStorage كما كان.
class KvStore {
  KvStore._(this._db, this._prefs);

  static const _dbName = 'moeen';
  static const _storeName = 'kv';
  static const _migratedFlag = 'moeen_idb_migrated';

  final JSObject? _db;
  final SharedPreferences _prefs;
  final Map<String, String> _mem = {};
  bool? _persisted;

  static Future<KvStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    JSObject? db;
    try {
      db = await _openDb();
    } catch (_) {
      db = null;
    }
    final kv = KvStore._(db, prefs);
    if (db != null) {
      try {
        await kv._loadAll();
        await kv._migrateFromLocalStorage();
      } catch (_) {
        // لا نخاطر: نعود إلى localStorage.
        return KvStore._(null, prefs);
      }
    }
    unawaited(kv._requestPersist());
    return kv;
  }

  String get backend => _db == null ? 'ذاكرة المتصفح المحدودة (localStorage)' : 'قاعدة بيانات المتصفح (IndexedDB)';

  /// true: المتصفح لن يمسح البيانات تلقائياً عند امتلاء القرص.
  bool? get persisted => _persisted;

  String? getString(String key) => _db == null ? _prefs.getString(key) : _mem[key];

  Future<void> setString(String key, String value) => setMany({key: value});

  Future<void> setMany(Map<String, String> values) async {
    final db = _db;
    if (db == null) {
      for (final e in values.entries) {
        if (_prefs.getString(e.key) == e.value) continue;
        final ok = await _prefs.setString(e.key, e.value);
        if (!ok) throw StateError('write failed');
      }
      return;
    }
    final changed = {
      for (final e in values.entries)
        if (_mem[e.key] != e.value) e.key: e.value,
    };
    if (changed.isEmpty) return;
    final tx = db.callMethod<JSObject>('transaction'.toJS, _storeName.toJS, 'readwrite'.toJS);
    final done = _txDone(tx);
    final os = tx.callMethod<JSObject>('objectStore'.toJS, _storeName.toJS);
    for (final e in changed.entries) {
      os.callMethod<JSAny?>('put'.toJS, e.value.toJS, e.key.toJS);
    }
    await done;
    _mem.addAll(changed);
  }

  Future<void> remove(String key) async {
    final db = _db;
    if (db == null) {
      await _prefs.remove(key);
      return;
    }
    if (!_mem.containsKey(key)) return;
    final tx = db.callMethod<JSObject>('transaction'.toJS, _storeName.toJS, 'readwrite'.toJS);
    final done = _txDone(tx);
    tx.callMethod<JSObject>('objectStore'.toJS, _storeName.toJS).callMethod<JSAny?>('delete'.toJS, key.toJS);
    await done;
    _mem.remove(key);
  }

  // ---------------------------------------------------------------------------

  static Future<JSObject> _openDb() {
    final idb = globalContext.getProperty<JSObject?>('indexedDB'.toJS);
    if (idb == null) throw StateError('IndexedDB unavailable');
    final c = Completer<JSObject>();
    final req = idb.callMethod<JSObject>('open'.toJS, _dbName.toJS, 1.toJS);
    req.setProperty(
      'onupgradeneeded'.toJS,
      ((JSObject _) {
        final db = req.getProperty<JSObject>('result'.toJS);
        final names = db.getProperty<JSObject>('objectStoreNames'.toJS);
        final has = names.callMethod<JSBoolean>('contains'.toJS, _storeName.toJS).toDart;
        if (!has) db.callMethod<JSAny?>('createObjectStore'.toJS, _storeName.toJS);
      }).toJS,
    );
    req.setProperty(
      'onsuccess'.toJS,
      ((JSObject _) {
        if (!c.isCompleted) c.complete(req.getProperty<JSObject>('result'.toJS));
      }).toJS,
    );
    req.setProperty(
      'onerror'.toJS,
      ((JSObject _) {
        if (!c.isCompleted) c.completeError(StateError('IndexedDB open failed'));
      }).toJS,
    );
    return c.future.timeout(const Duration(seconds: 6));
  }

  static Future<JSAny?> _request(JSObject req) {
    final c = Completer<JSAny?>();
    req.setProperty('onsuccess'.toJS, ((JSObject _) => c.complete(req.getProperty<JSAny?>('result'.toJS))).toJS);
    req.setProperty(
      'onerror'.toJS,
      ((JSObject _) {
        if (!c.isCompleted) c.completeError(StateError('IndexedDB request failed'));
      }).toJS,
    );
    return c.future;
  }

  /// تكتمل عند حفظ المعاملة فعلياً، وتفشل إذا رُفضت (مثل امتلاء المساحة).
  static Future<void> _txDone(JSObject tx) {
    final c = Completer<void>();
    tx.setProperty('oncomplete'.toJS, ((JSObject _) => c.complete()).toJS);
    void fail(JSObject _) {
      if (!c.isCompleted) c.completeError(StateError('IndexedDB write failed'));
    }

    tx.setProperty('onerror'.toJS, fail.toJS);
    tx.setProperty('onabort'.toJS, fail.toJS);
    return c.future;
  }

  Future<void> _loadAll() async {
    final tx = _db!.callMethod<JSObject>('transaction'.toJS, _storeName.toJS, 'readonly'.toJS);
    final os = tx.callMethod<JSObject>('objectStore'.toJS, _storeName.toJS);
    // الطلبان معاً قبل الانتظار حتى لا تنتهي المعاملة بينهما.
    final keysF = _request(os.callMethod<JSObject>('getAllKeys'.toJS));
    final valsF = _request(os.callMethod<JSObject>('getAll'.toJS));
    final keys = (await keysF as JSArray<JSAny?>).toDart;
    final vals = (await valsF as JSArray<JSAny?>).toDart;
    for (var i = 0; i < keys.length && i < vals.length; i++) {
      final k = keys[i], v = vals[i];
      if (k.isA<JSString>() && v.isA<JSString>()) {
        _mem[(k as JSString).toDart] = (v as JSString).toDart;
      }
    }
  }

  Future<void> _migrateFromLocalStorage() async {
    if (_prefs.getBool(_migratedFlag) == true) return;
    final copy = <String, String>{};
    for (final key in _prefs.getKeys()) {
      if (key == _migratedFlag || key == 'moeen_app_mode') continue;
      if (!key.startsWith('moeen_') && !key.startsWith('admin__')) continue;
      final v = _prefs.get(key);
      if (v is String && !_mem.containsKey(key)) copy[key] = v;
    }
    if (copy.isNotEmpty) await setMany(copy);
    // النسخة القديمة تبقى في localStorage كاحتياط، لكن لا يُكتب عليها بعد الآن.
    await _prefs.setBool(_migratedFlag, true);
  }

  Future<void> _requestPersist() async {
    try {
      final nav = globalContext.getProperty<JSObject?>('navigator'.toJS);
      final storage = nav?.getProperty<JSObject?>('storage'.toJS);
      if (storage == null || !storage.has('persist')) return;
      final already = await storage.callMethod<JSPromise<JSBoolean>>('persisted'.toJS).toDart;
      if (already.toDart) {
        _persisted = true;
        return;
      }
      final granted = await storage.callMethod<JSPromise<JSBoolean>>('persist'.toJS).toDart;
      _persisted = granted.toDart;
    } catch (_) {
      _persisted = null;
    }
  }
}
