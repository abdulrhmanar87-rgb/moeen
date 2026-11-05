import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'ocr_line.dart';

@JS('moeenOcr')
external JSPromise<JSString> _moeenOcr(JSUint8Array bytes, JSNumber quarterTurns);

/// نسخة الويب: الدالة moeenOcr في web/index.html تحسّن الصورة (الإضاءة،
/// التباين، التدوير، الحجم) ثم تقرأها بـ Tesseract وتعيد الأسطر مع الثقة.
Future<List<OcrLine>> runOcr(
  Uint8List bytes, {
  String? path,
  int quarterTurns = 0,
}) async {
  final raw = (await _moeenOcr(bytes.toJS, quarterTurns.toJS).toDart).toDart;
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final lines = decoded['lines'];
  if (lines is List && lines.isNotEmpty) {
    return lines
        .whereType<Map>()
        .map((l) => OcrLine(
              l['text']?.toString() ?? '',
              (l['confidence'] as num?)?.toDouble() ?? -1,
            ))
        .where((l) => l.text.trim().isNotEmpty)
        .toList();
  }
  final text = decoded['text']?.toString() ?? '';
  return text
      .split(RegExp(r'[\r\n]+'))
      .where((l) => l.trim().isNotEmpty)
      .map((l) => OcrLine(l))
      .toList();
}
