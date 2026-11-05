import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external _Blob(JSArray<JSAny> parts, _BlobOptions options);
}

@JS('File')
extension type _File._(JSObject _) implements JSObject {
  external _File(JSArray<JSAny> parts, String name, _BlobOptions options);
}

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}

extension type _ShareData._(JSObject _) implements JSObject {
  external factory _ShareData({JSArray<_File> files, String title});
}

extension type _Navigator._(JSObject _) implements JSObject {
  external bool canShare(_ShareData data);
  external JSPromise<JSAny?> share(_ShareData data);
}

extension type _MediaQueryList._(JSObject _) implements JSObject {
  external bool get matches;
}

extension type _Anchor._(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
  external void remove();
}

@JS('navigator')
external _Navigator get _navigator;

@JS('matchMedia')
external _MediaQueryList _matchMedia(String query);

@JS('URL.createObjectURL')
external String _createObjectURL(_Blob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectURL(String url);

@JS('document.createElement')
external _Anchor _createElement(String tag);

@JS('document.body.appendChild')
external void _appendToBody(JSObject element);

/// هاتف أو جهاز لوحي (شاشة لمس هي وسيلة الإدخال الأساسية).
bool _isTouchDevice() {
  try {
    return _matchMedia('(pointer: coarse)').matches;
  } catch (_) {
    return false;
  }
}

/// على الهاتف: قائمة المشاركة (حفظ في الملفات، iCloud، واتساب، Drive...).
/// يعيد true عند المشاركة، false إذا ألغى المستخدم، وnull إذا لم تكن متاحة.
Future<bool?> _tryShare(String fileName, String content, String mimeType) async {
  try {
    if (!(_navigator as JSObject).has('canShare')) return null;
    final file = _File([content.toJS].toJS, fileName, _BlobOptions(type: mimeType));
    final data = _ShareData(files: [file].toJS, title: fileName);
    if (!_navigator.canShare(data)) return null;
    await _navigator.share(data).toDart;
    return true;
  } catch (e) {
    // إلغاء المستخدم لقائمة المشاركة ليس خطأ.
    if (e.toString().contains('AbortError')) return false;
    return null;
  }
}

void _download(String fileName, String content, String mimeType) {
  final blob = _Blob([content.toJS].toJS, _BlobOptions(type: '$mimeType;charset=utf-8'));
  final url = _createObjectURL(blob);
  final a = _createElement('a')
    ..href = url
    ..download = fileName;
  _appendToBody(a);
  a.click();
  a.remove();
  Future.delayed(const Duration(seconds: 30), () => _revokeObjectURL(url));
}

/// يحفظ الملف: قائمة المشاركة على الهاتف، أو تنزيل مباشر على الحاسوب.
/// يعيد false إذا ألغى المستخدم.
Future<bool> saveTextFile(String fileName, String content, {String mimeType = 'application/json'}) async {
  if (_isTouchDevice()) {
    final shared = await _tryShare(fileName, content, mimeType);
    if (shared != null) return shared;
  }
  _download(fileName, content, mimeType);
  return true;
}
