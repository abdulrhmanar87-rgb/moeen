import 'package:flutter/services.dart';

/// سياسة الأرقام في مُعين:
/// - داخل التطبيق والحسابات والتخزين: الأرقام إنكليزية دائماً (0123456789).
/// - في عرض التقارير وسجل المدرس فقط: الأرقام بالسياق العربي (٠١٢٣٤٥٦٧٨٩).
class ArabicNumbers {
  static const _toArabicMap = {
    '0': '٠',
    '1': '١',
    '2': '٢',
    '3': '٣',
    '4': '٤',
    '5': '٥',
    '6': '٦',
    '7': '٧',
    '8': '٨',
    '9': '٩',
  };

  /// للعرض داخل التقارير وسجل المدرس فقط.
  static String toArabic(Object? value) {
    final text = value?.toString() ?? '';
    return text.split('').map((c) => _toArabicMap[c] ?? c).join();
  }

  /// يحوّل أي أرقام عربية-هندية (٠-٩) أو فارسية (۰-۹) إلى أرقام إنكليزية،
  /// ويحوّل الفاصلة العشرية العربية (٫) إلى نقطة.
  static String toEnglish(String text) {
    final buffer = StringBuffer();
    for (final unit in text.runes) {
      if (unit >= 0x0660 && unit <= 0x0669) {
        buffer.writeCharCode(unit - 0x0660 + 0x30);
      } else if (unit >= 0x06F0 && unit <= 0x06F9) {
        buffer.writeCharCode(unit - 0x06F0 + 0x30);
      } else if (unit == 0x066B) {
        buffer.write('.');
      } else {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }

  static double? parseDouble(String text) =>
      double.tryParse(toEnglish(text).trim());

  static int? parseInt(String text) => int.tryParse(toEnglish(text).trim());
}

/// يُستخدم في حقول الإدخال الرقمية: إذا كتب المستخدم بلوحة مفاتيح عربية
/// تتحول الأرقام فوراً إلى إنكليزية.
class EnglishDigitsFormatter extends TextInputFormatter {
  const EnglishDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final converted = ArabicNumbers.toEnglish(newValue.text);
    if (converted == newValue.text) return newValue;
    return newValue.copyWith(text: converted);
  }
}
