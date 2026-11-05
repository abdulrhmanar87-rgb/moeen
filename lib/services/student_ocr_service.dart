import 'dart:typed_data';

import '../core/utils/arabic_name_utils.dart';
import '../models/student_import.dart';
import 'ocr/ocr_engine.dart';

abstract class StudentOcrService {
  /// [quarterTurns]: عدد أرباع الدورات (مع عقارب الساعة) التي أدارها الأستاذ
  /// للصورة في المعاينة، فتُقرأ الصورة بالاتجاه الصحيح.
  Future<List<StudentImportItem>> recognize(
    Uint8List bytes, {
    String? path,
    int quarterTurns = 0,
    String mimeType = 'image/jpeg',
  });
}

/// القراءة المحلية المجانية عبر Tesseract (تعمل بدون إنترنت بعد أول تحميل
/// لملف اللغة العربية). ممتازة للأوراق المطبوعة، ومحدودة مع خط اليد.
class ArabicTesseractOcrService implements StudentOcrService {
  @override
  Future<List<StudentImportItem>> recognize(
    Uint8List bytes, {
    String? path,
    int quarterTurns = 0,
    String mimeType = 'image/jpeg',
  }) async {
    if (bytes.isEmpty && (path == null || path.isEmpty)) return [];
    final lines = await runOcr(bytes, path: path, quarterTurns: quarterTurns);
    return namesFromOcrLines(lines, source: 'صورة');
  }
}

/// يحوّل أسطر القراءة إلى أسماء: يحذف التسلسل والرقم الوطني (ويحتفظ به)،
/// وخطوط الجداول والرموز، ويتجاهل العناوين واسم المدرسة والصف.
List<StudentImportItem> namesFromOcrLines(
  List<OcrLine> lines, {
  required String source,
}) {
  final result = <StudentImportItem>[];
  final seen = <String>{};

  for (final line in lines) {
    final raw = line.text;
    final nationalId = ArabicNameUtils.extractNationalId(raw);
    var words = ArabicNameUtils.words(raw);

    // حرف منفرد على أطراف السطر غالباً بقايا خط جدول أو تسلسل.
    var trimmedNoise = false;
    while (words.length > 2 && words.first.length == 1) {
      words = words.sublist(1);
      trimmedNoise = true;
    }
    while (words.length > 2 && words.last.length == 1) {
      words = words.sublist(0, words.length - 1);
      trimmedNoise = true;
    }
    final name = words.join(' ');
    if (!ArabicNameUtils.looksLikeName(name)) continue;
    if (!seen.add(ArabicNameUtils.key(name))) continue;

    // ثقة السطر من محرك القراءة: أقل من 75 تحتاج مقارنة مع الصورة.
    var confidence = line.confidence < 0
        ? 0.9
        : (line.confidence >= 75 ? 0.95 : 0.6);
    if (trimmedNoise && confidence > 0.8) confidence = 0.8;

    result.add(StudentImportItem(
      name: name,
      nationalId: nationalId,
      confidence: confidence,
      source: source,
    ));
  }

  // الأرقام الوطنية في الورقة الواحدة بطول واحد عادةً؛ المختلف غالباً قراءة خاطئة.
  final lengths = <int, int>{};
  for (final item in result) {
    if (item.nationalId.isNotEmpty) {
      lengths[item.nationalId.length] = (lengths[item.nationalId.length] ?? 0) + 1;
    }
  }
  if (lengths.length > 1) {
    final common = lengths.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    for (final item in result) {
      if (item.nationalId.isNotEmpty && item.nationalId.length != common) {
        item.confidence = 0.6;
      }
    }
  }
  return result;
}
