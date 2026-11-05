import '../core/utils/arabic_name_utils.dart';

class StudentImportItem {
  StudentImportItem({
    required this.name,
    this.nationalId = '',
    this.confidence = 1.0,
    this.selected = true,
    this.source = 'يدوي',
  });

  String name;
  String nationalId;

  /// ثقة القراءة (0-1). أقل من 0.82 يعني أن القراءة نفسها غير مؤكدة.
  double confidence;
  bool selected;
  String source;

  /// يصبح true عندما يعدّل الأستاذ الاسم يدوياً، فلا يبقى تحذير ثقة القراءة.
  bool edited = false;

  /// سبب المراجعة، أو null إذا كان الاسم سليماً.
  String? get reviewReason {
    final n = name.trim();
    if (n.length < 3) return 'الاسم قصير جداً';
    final id = nationalId.replaceAll(RegExp(r'[^0-9]'), '');
    if (nationalId.isNotEmpty && id.length < 6) return 'الرقم الوطني ناقص';
    final nameReason = ArabicNameUtils.reviewReason(n);
    if (nameReason != null) return nameReason;
    if (!edited && confidence < 0.82) return 'القراءة غير مؤكدة — قارن مع الصورة';
    return null;
  }

  bool get needsReview => reviewReason != null;
}
