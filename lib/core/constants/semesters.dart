/// الفصلان الدراسيان وأشهرهما، ومستويات تقدير السلوك والمشاركة.
class Semesters {
  Semesters._();

  static const firstMonths = ['الشهر الأول', 'الشهر الثاني', 'الشهر الثالث'];
  static const secondMonths = ['الشهر الرابع', 'الشهر الخامس', 'الشهر السادس'];
  static const midyear = 'نصف السنة';

  // امتحانا نهاية السنة (يُحفظان مع الدرجات الشهرية بهذين الاسمين).
  static const finalExam = 'الامتحان النهائي';
  static const completionExam = 'امتحان الإكمال';

  /// درجة النجاح.
  static const passMark = 50;

  static List<String> months(int semester) => semester == 2 ? secondMonths : firstMonths;

  static String name(int semester) => semester == 2 ? 'الفصل الثاني' : 'الفصل الأول';

  /// الفصل الذي ينتمي إليه الشهر، أو 0 إذا لم يكن شهراً معروفاً.
  static int ofMonth(String period) {
    if (firstMonths.contains(period)) return 1;
    if (secondMonths.contains(period)) return 2;
    return 0;
  }

  /// الفصل الأول: أيلول إلى كانون الثاني، والثاني: شباط إلى آب.
  static int fromDate(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return 1;
    return (d.month >= 2 && d.month <= 8) ? 2 : 1;
  }

  static int current() => fromDate(DateTime.now().toIso8601String());
}

/// تقدير السلوك والمشاركة: درجة صحيحة من 0 إلى 10 تُختار بشريط متحرك،
/// ويُعرض معها الوصف اللفظي حسب سلّم التقديرات المعتمد.
class RatingLevels {
  RatingLevels._();

  static const maxScore = 10;

  static String label(int score) {
    if (score >= 9) return 'ممتاز';
    if (score == 8) return 'جيد جداً';
    if (score == 7) return 'جيد';
    if (score == 6) return 'متوسط';
    if (score == 5) return 'مقبول';
    return 'ضعيف';
  }

  /// نسبة ما يأخذه الطالب من درجة التقدير.
  static double fraction(int score) => score.clamp(0, maxScore) / maxScore;

  /// تحويل التقديرات القديمة (5 مستويات) إلى درجة من 10.
  static const legacyLevelScores = [4, 5, 7, 8, 10];
}
