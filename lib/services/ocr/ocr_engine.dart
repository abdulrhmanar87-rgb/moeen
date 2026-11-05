// محرك قراءة الصور: على الويب يستخدم Tesseract.js مع معالجة مسبقة للصورة
// (index.html)، وعلى الأجهزة الأخرى يستخدم إضافة flutter_tesseract_ocr.
export 'ocr_line.dart';
export 'ocr_engine_stub.dart' if (dart.library.js_interop) 'ocr_engine_web.dart';
