import 'dart:js_interop';

// ربط مباشر بواجهات المتصفح من Dart، دون الاعتماد على أي كود في index.html.
@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external _Blob(JSArray<JSAny> parts, _BlobOptions options);
}

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}

@JS('URL.createObjectURL')
external String _createObjectURL(_Blob blob);

@JS('window.open')
external JSObject? _openWindow(String url, String target);

bool get canPrintHtml => true;

/// يفتح المستند في تبويب جديد كصفحة A4 مستقلة، وتظهر نافذة الطباعة تلقائياً.
/// يعيد false إذا منع المتصفح فتح التبويب (حاجب النوافذ المنبثقة).
Future<bool> printHtml(String html) async {
  final blob = _Blob(
    [html.toJS].toJS,
    _BlobOptions(type: 'text/html;charset=utf-8'),
  );
  final url = _createObjectURL(blob);
  return _openWindow(url, '_blank') != null;
}
