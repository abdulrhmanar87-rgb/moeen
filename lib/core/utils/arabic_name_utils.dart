import 'arabic_numbers.dart';

/// أدوات تنظيف وفحص الأسماء العربية (الثلاثية والرباعية) المستوردة
/// من Word أو الصور أو اللصق.
class ArabicNameUtils {
  ArabicNameUtils._();

  // حروف عربية (مع الحروف الموسعة مثل گ و چ و پ).
  static final _letter =
      RegExp(r'[ء-غف-يٱ-ۓۺ-ۿ]');
  static final _notLetterOrSpace = RegExp(
      r'[^ء-غف-يٱ-ۓۺ-ۿ\s]');

  /// إزالة علامات الاتجاه الخفية والتطويل والتشكيل وتوحيد الياء والكاف
  /// الفارسيتين والمسافات.
  static String normalize(String value) {
    var text = value
        .replaceAll(RegExp('[\\u200B-\\u200F\\u202A-\\u202E\\u2066-\\u2069\\uFEFF]'), '')
        .replaceAll(' ', ' ')
        .replaceAll('ـ', '') // ـ
        .replaceAll(RegExp(r'[ً-ٰٟ]'), '') // التشكيل
        .replaceAll('ی', 'ي') // ی
        .replaceAll('ک', 'ك'); // ک
    text = ArabicNumbers.toEnglish(text);
    return text.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  /// مفتاح للمقارنة وكشف التكرار (يوحّد الهمزات والتاء المربوطة والياء).
  static String key(String value) => cleanName(value)
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(' ', '');

  /// يبقي حروف الاسم فقط: يحذف التسلسل والأرقام والرموز وخطوط الجداول.
  static String cleanName(String value) {
    var text = normalize(value);
    text = text.replaceAll(_notLetterOrSpace, ' ');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int arabicLetterCount(String value) =>
      _letter.allMatches(value).length;

  /// أطول سلسلة أرقام (6 أرقام فأكثر) تعتبر رقماً وطنياً محتملاً.
  static String extractNationalId(String value) {
    final text = normalize(value);
    final matches = RegExp(r'\d{6,}').allMatches(text).map((m) => m.group(0)!);
    if (matches.isEmpty) return '';
    return matches.reduce((a, b) => a.length >= b.length ? a : b);
  }

  static List<String> words(String name) =>
      cleanName(name).split(' ').where((w) => w.isNotEmpty).toList();

  /// أجزاء الاسم مع إبقاء المركبات جزءاً واحداً:
  /// عبد الله، عبد الحسين، أبو بكر، نور الدين، زين العابدين، آل حمود.
  static List<String> nameParts(String name) {
    final w = words(name);
    final parts = <String>[];
    var i = 0;
    while (i < w.length) {
      final current = w[i];
      if (_joinWithNext.contains(current) && i + 1 < w.length) {
        parts.add('$current ${w[i + 1]}');
        i += 2;
      } else if (_joinWithPrevious.contains(current) && parts.isNotEmpty) {
        parts[parts.length - 1] = '${parts.last} $current'; // يلتصق بالجزء السابق
        i += 1;
      } else {
        parts.add(current);
        i += 1;
      }
    }
    return parts;
  }

  static int partCount(String name) => nameParts(name).length;

  /// تقسيم الاسم لأعمدة السجل الوسطي: [الطالب، الأب، الجد، أب الجد واللقب].
  /// ما زاد عن ثلاثة أجزاء يوضع كله في العمود الرابع.
  static List<String> recordNameColumns(String name) {
    final p = nameParts(name);
    return [
      p.isNotEmpty ? p[0] : '',
      p.length > 1 ? p[1] : '',
      p.length > 2 ? p[2] : '',
      p.length > 3 ? p.sublist(3).join(' ') : '',
    ];
  }

  /// مفتاح مطابقة أسماء المواد بين المدرس والإدارة:
  /// «الرياضيات» = «رياضيات»، «اللغة الانكليزية» = «الإنجليزية»، «التربية الإسلامية» = «الاسلامية».
  static String subjectKey(String value) {
    final text = normalize(value)
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('انجليزي', 'انكليزي')
        .replaceAll(RegExp(r'[^\u0621-\u064Aa-zA-Z\s]'), ' ');
    const filler = {'لغه', 'ماده', 'تربيه'};
    final words = <String>[];
    for (var w in text.split(RegExp(r'\s+'))) {
      if (w.isEmpty) continue;
      if (w.startsWith('ال') && w.length > 3) w = w.substring(2);
      if (filler.contains(w)) continue;
      words.add(w);
    }
    return words.join(' ');
  }

  /// هل الخلية/السطر عنوان عمود (وليس اسماً)؟ مطابقة كاملة وليست جزئية،
  /// حتى لا تُحذف أسماء مثل جاسم وقاسم وباسم وإسماعيل.
  static bool isHeader(String value) {
    final h = _headerKey(value);
    if (h.isEmpty) return false;
    if (_headers.contains(h)) return true;
    if (h.startsWith('اسم الطالب') || h.startsWith('اسماء الطلاب')) return true;
    if (h.startsWith('الاسم ') && h.split(' ').length <= 3) return true;
    return false;
  }

  static bool isNameHeader(String value) {
    final h = _headerKey(value);
    return _nameHeaders.contains(h) ||
        h.startsWith('اسم الطالب') ||
        (h.startsWith('الاسم ') && h.split(' ').length <= 3);
  }

  static bool isNationalIdHeader(String value) =>
      _idHeaders.contains(_headerKey(value));

  /// دور عمود من أعمدة الاسم المجزأ: 1 الأب، 2 الجد، 3 أبو الجد، 4 اللقب.
  static int namePartRole(String value) {
    final h = _headerKey(value);
    if (h == 'اسم الاب' || h == 'الاب') return 1;
    if (h == 'اسم الجد' || h == 'الجد') return 2;
    if (h == 'اسم ابي الجد' || h == 'اسم جد الاب' || h == 'ابو الجد') return 3;
    if (h == 'اللقب' || h == 'لقب' || h == 'العشيره' || h == 'القبيله') return 4;
    return 0;
  }

  /// هل النص يبدو اسم طالب؟
  static bool looksLikeName(String raw) {
    final text = normalize(raw);
    if (text.isEmpty || isHeader(text)) return false;
    final compact = text.replaceAll(RegExp(r'\s'), '');
    if (compact.isEmpty) return false;
    final letters = arabicLetterCount(compact);
    if (letters < 4) return false;
    // الأرقام والرموز مقبولة بقدر محدود (تسلسل/رقم وطني في نفس السطر).
    final nonDigit = compact.replaceAll(RegExp(r'\d'), '');
    if (nonDigit.isEmpty || letters / nonDigit.length < .8) return false;
    // "عنوان: قيمة" مثل الصف: الخامس أو ملاحظة: ...
    if (RegExp(r'[\u0621-\u064A][^:]*:').hasMatch(text)) return false;
    final w = words(text);
    if (w.length < 2 || w.length > 8) return false;
    if (w.any((word) => _stopWords.contains(_headerKey(word)))) return false;
    return true;
  }

  /// سبب المراجعة لاسم معيّن، أو null إذا كان سليماً.
  static String? reviewReason(String name) {
    final w = words(name);
    if (w.isEmpty) return 'الاسم فارغ';
    if (w.any((word) => word.length == 1)) {
      return 'يحتوي على حرف منفصل — قد يكون خطأ قراءة';
    }
    final parts = partCount(name);
    if (parts < 3) return 'الاسم ثنائي — تأكد من الاسم الثلاثي';
    if (parts > 5) return 'الاسم طويل — قد يكون اسمين مدمجين';
    return null;
  }

  static String _headerKey(String value) => normalize(value)
      .replaceAll(RegExp(r'[:：/\\\-_.()]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');

  /// قيم أعمدة غير الاسم (الجنس، النتيجة، الحالة).
  static bool isStatusWord(String value) =>
      _statusWords.contains(_headerKey(value));

  static const _statusWords = {
    'ذكر', 'انثي', 'ذكور', 'اناث', 'ناجح', 'ناجحه', 'راسب', 'راسبه', 'مكمل',
    'مكمله', 'مؤجل', 'مستمر', 'مستمره', 'منقول', 'منقوله', 'مفصول', 'غائب',
  };

  static const _joinWithNext = {'عبد', 'ابو', 'أبو', 'ابي', 'أبي', 'آل', 'ال'};
  static const _joinWithPrevious = {'الله', 'الدين', 'العابدين'};

  static const _nameHeaders = {
    'الاسم',
    'اسم',
    'اسم الطالب',
    'اسم الطالبه',
    'الاسم الثلاثي',
    'الاسم الرباعي',
    'الاسم الكامل',
    'الاسم الثلاثي واللقب',
    'الاسم الرباعي واللقب',
    'اسماء الطلاب',
    'اسم التلميذ',
    'الطالب',
    'الطالبه',
  };
  static const _idHeaders = {
    'الرقم الوطني',
    'رقم وطني',
    'الرقم القومي',
    'رقم البطاقه',
    'البطاقه الوطنيه',
    'رقم البطاقه الوطنيه',
    'national id',
    'nationalid',
  };
  static const _headers = {
    ..._nameHeaders,
    ..._idHeaders,
    'ت',
    'م',
    'التسلسل',
    'تسلسل',
    'الرقم',
    'رقم',
    'الملاحظات',
    'ملاحظات',
    'اسم الاب',
    'اسم الجد',
    'اللقب',
    'اسم الام',
    'المواليد',
    'التولد',
  };

  /// كلمات لا تظهر في أسماء الطلاب، فإذا وُجدت فالسطر عنوان أو بيانات أخرى.
  static const _stopWords = {
    'مدرسه',
    'المدرسه',
    'ثانويه',
    'متوسطه',
    'اعداديه',
    'ابتدائيه',
    'الصف',
    'صف',
    'الشعبه',
    'شعبه',
    'الماده',
    'ماده',
    'المدرس',
    'مدرس',
    'المدرسين',
    'المدير',
    'مدير',
    'الدراسي',
    'الدراسيه',
    'قائمه',
    'اسماء',
    'الطلاب',
    'الطالبات',
    'الطالب',
    'الطالبه',
    'طلاب',
    'ملاحظات',
    'الملاحظات',
    'المجموع',
    'توقيع',
    'وزاره',
    'مديريه',
    'التربيه',
    'العدد',
    'الدرجات',
    'درجات',
    'سجل',
    'جمهوريه',
    'المرحله',
    'الامتحان',
    'الامتحانات',
    'الاسم',
    'الرقم',
    'الوطني',
    'التسلسل',
    'المواليد',
    'الاول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الخامس',
    'السادس',
    'المتوسط',
    'الاعدادي',
    'الابتدائي',
    'العلمي',
    'الادبي',
    'للبنين',
    'للبنات',
    'المختلطه',
    'ملاحظه',
    'يرجي',
    'المراجعه',
    'ذكر',
    'انثي',
  };
}
