import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/utils/arabic_name_utils.dart';
import '../models/student_import.dart';
import 'student_ocr_service.dart';

/// القراءة الذكية (اختيارية) عبر Gemini من Google: أدق بكثير مع خط اليد
/// والصور المائلة والجداول، لكنها تحتاج إنترنت ومفتاح API، وترسل الصورة إلى Google.
class SmartStudentOcrService implements StudentOcrService {
  SmartStudentOcrService({required this.apiKey});

  final String apiKey;

  /// يجرَّب النموذج الأول، وإذا لم يكن متاحاً للمفتاح يُستخدم التالي.
  static const models = ['gemini-3.8-flash', 'gemini-2.5-flash'];

  static const _prompt = '''
أنت محرك استخراج أسماء طلاب من صورة ورقة مدرسية عراقية (مطبوعة أو بخط اليد، وقد تكون جدولاً).
المطلوب: كل طالب يظهر في الورقة، بالترتيب من أعلى الورقة إلى أسفلها.
قواعد مهمة:
- الاسم ثلاثي أو رباعي غالباً، وقد يتبعه لقب. انقله كاملاً كما هو مكتوب.
- إذا كان الاسم مجزأً على أعمدة (الاسم، اسم الأب، اسم الجد، اللقب) فاجمعها في اسم واحد بهذا الترتيب.
- الأسماء المركبة جزء واحد: عبد الله، عبد الحسين، نور الدين، زين العابدين.
- لا تقسّم الاسم الواحد إلى اسمين، ولا تدمج سطرين مختلفين.
- تجاهل رقم التسلسل، وعناوين الأعمدة، واسم المدرسة والصف والشعبة والمادة والتواقيع والملاحظات.
- إذا وُجد رقم وطني (6 أرقام فأكثر) بجانب الاسم فضعه في nationalId بأرقام إنكليزية، وإلا اتركه فارغاً.
- لا تخترع ولا تكمل حرفاً غير واضح. إذا كان جزء من الاسم غير مقروء بثقة فاكتب أفضل قراءة وضع needsReview = true.
أعد JSON فقط بهذا الشكل دون أي شرح:
{"names":[{"name":"اسم الطالب","nationalId":"","needsReview":false}]}
''';

  @override
  Future<List<StudentImportItem>> recognize(
    Uint8List bytes, {
    String? path,
    int quarterTurns = 0,
    String mimeType = 'image/jpeg',
  }) async {
    if (bytes.isEmpty) return [];
    if (apiKey.trim().isEmpty) throw StateError('GEMINI_API_KEY_MISSING');

    final rotationHint = quarterTurns % 4 == 0
        ? ''
        : '\nملاحظة: الصورة مدارة؛ اقرأها بعد تدويرها ${(quarterTurns % 4) * 90} درجة مع عقارب الساعة.';

    Object? lastError;
    for (final model in models) {
      try {
        final raw = await _call(model, bytes, mimeType, _prompt + rotationHint);
        return _parse(raw);
      } on _ModelUnavailable catch (e) {
        lastError = e;
        continue;
      }
    }
    throw StateError('GEMINI_MODEL_UNAVAILABLE: $lastError');
  }

  Future<String> _call(
    String model,
    Uint8List bytes,
    String mimeType,
    String prompt,
  ) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );
    final body = {
      'contents': [
        {
          'parts': [
            {
              'inline_data': {'mime_type': mimeType, 'data': base64Encode(bytes)},
            },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
      },
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey.trim(),
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 404) throw _ModelUnavailable(model);
    if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('GEMINI_KEY_INVALID_${response.statusCode}');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('GEMINI_HTTP_${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final content = candidates.first['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return '';
    return parts
        .whereType<Map>()
        .where((p) => p['thought'] != true)
        .map((p) => p['text']?.toString() ?? '')
        .join();
  }

  List<StudentImportItem> _parse(String raw) {
    if (raw.trim().isEmpty) return [];
    final parsed = jsonDecode(_extractJson(raw));
    final names = parsed is Map ? parsed['names'] : null;
    if (names is! List) return [];

    final result = <StudentImportItem>[];
    final seen = <String>{};
    for (final entry in names) {
      if (entry is! Map) continue;
      final name = ArabicNameUtils.cleanName(entry['name']?.toString() ?? '');
      if (name.isEmpty || !seen.add(ArabicNameUtils.key(name))) continue;
      final id = ArabicNameUtils.extractNationalId(entry['nationalId']?.toString() ?? '');
      final doubtful = entry['needsReview'] == true || !ArabicNameUtils.looksLikeName(name);
      result.add(StudentImportItem(
        name: name,
        nationalId: id,
        confidence: doubtful ? 0.6 : 0.98,
        source: 'قراءة ذكية',
      ));
    }
    return result;
  }

  String _extractJson(String value) {
    final trimmed = value.trim();
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) return trimmed.substring(start, end + 1);
    throw const FormatException('Gemini returned invalid JSON');
  }
}

class _ModelUnavailable implements Exception {
  _ModelUnavailable(this.model);
  final String model;
  @override
  String toString() => 'model $model unavailable';
}
