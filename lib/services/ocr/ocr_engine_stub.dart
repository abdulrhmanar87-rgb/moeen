import 'dart:typed_data';

import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

import 'ocr_line.dart';

/// النسخة غير الويب: تقرأ الملف من مساره عبر flutter_tesseract_ocr.
Future<List<OcrLine>> runOcr(
  Uint8List bytes, {
  String? path,
  int quarterTurns = 0,
}) async {
  if (path == null || path.trim().isEmpty) return [];
  final text = await FlutterTesseractOcr.extractText(
    path,
    language: 'ara',
    args: {
      'psm': '6',
      'preserve_interword_spaces': '1',
    },
  );
  return text
      .split(RegExp(r'[\r\n]+'))
      .where((l) => l.trim().isNotEmpty)
      .map((l) => OcrLine(l))
      .toList();
}
