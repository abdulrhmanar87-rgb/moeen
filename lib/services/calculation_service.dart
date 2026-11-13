import '../core/constants/semesters.dart';
import '../core/utils/grade_utils.dart';
import '../core/storage/app_store.dart';
import '../models/assessment.dart';

/// تفاصيل سعي الطالب في فصل دراسي واحد (من 100):
///   معدل الامتحانات الشهرية للفصل  → من [monthlyWeight] (افتراضياً 70)
/// + معدل الامتحانات اليومية للفصل  → من [dailyWeight]   (افتراضياً 20)
/// + تقدير السلوك والمشاركة          → من [ratingWeight]  (افتراضياً 10)
///
/// الطالب الغائب أو المؤجل في امتحان يُستبعد ذلك الامتحان من معدله.
class SemesterBreakdown {
  SemesterBreakdown({
    required this.semester,
    required this.monthlyScores,
    required this.dailyScores,
    required this.dailyMax,
    required this.ratingScore,
    required this.monthlyWeight,
    required this.dailyWeight,
    required this.ratingWeight,
    this.monthlyLabel = 'الامتحانات الشهرية',
    this.dailyLabel = 'الامتحانات اليومية',
    this.ratingLabel = 'السلوك والمشاركة',
    this.postponed = const [],
    this.examCount = 1,
  });

  /// عدد امتحانات الفصل (شهري + يومي) في الشعبة. فصل بلا امتحانات ولا تقدير
  /// لم يبدأ بعد، فلا يُحسب صفراً (حتى لا يظهر الفصل الثاني 0 في سجل المدرس).
  final int examCount;
  bool get notStarted => examCount == 0 && ratingScore == null;

  final int semester;

  /// أسماء الامتحانات الشهرية المؤجلة لهذا الطالب: سعيه ناقص حتى تُدخل.
  final List<String> postponed;
  final String monthlyLabel;
  final String dailyLabel;
  final String ratingLabel;

  /// درجات الامتحانات الشهرية (من 100)؛ غير المدخل = 0، والمؤجل لا يدخل هنا.
  final Map<String, double> monthlyScores;

  /// نسب الامتحانات اليومية (من 100)؛ غير المدخل = 0، والغائب مستبعد.
  final List<double> dailyScores;
  final double dailyMax;

  /// تقدير السلوك والمشاركة من 10، أو null إذا لم يُقيَّم.
  final int? ratingScore;

  final double monthlyWeight;
  final double dailyWeight;
  final double ratingWeight;

  // قاعدة الحساب: ما لم يُدخل يُحسب 0، فالسعي يظهر دائماً،
  // إلا إذا كان للطالب امتحان شهري «مؤجل» فيبقى سعيه ناقصاً.
  double? get monthlyAverage => monthlyScores.isEmpty
      ? 0
      : monthlyScores.values.reduce((a, b) => a + b) / monthlyScores.length;

  double? get dailyAverage => dailyScores.isEmpty
      ? 0
      : dailyScores.reduce((a, b) => a + b) / dailyScores.length;

  double? get monthlyPart =>
      monthlyAverage == null ? null : GradeUtils.clamp(monthlyAverage! * monthlyWeight / 100, 0, monthlyWeight);

  double? get dailyPart =>
      dailyAverage == null ? null : GradeUtils.clamp(dailyAverage! * dailyWeight / dailyMax, 0, dailyWeight);

  double? get ratingPart => RatingLevels.fraction(ratingScore ?? 0) * ratingWeight;

  /// ما يجعل السعي ناقصاً: الامتحانات الشهرية المؤجلة فقط.
  List<String> get missing => postponed;

  bool get isComplete => missing.isEmpty;

  /// مجموع ما اكتمل حتى الآن (للمتابعة أثناء الفصل).
  double get partialTotal => (monthlyPart ?? 0) + (dailyPart ?? 0) + (ratingPart ?? 0);

  /// سعي الفصل النهائي (مقرّب)، أو null إذا لم تكتمل عناصره.
  double? get total => !notStarted && isComplete ? GradeUtils.rawRound(GradeUtils.clamp(partialTotal, 0, 100)) : null;
}

/// نتيجة الطالب في السنة كاملة، كما تظهر في سجل المدرس.
class YearResult {
  const YearResult({
    this.first,
    this.midyear,
    this.second,
    this.annual,
    this.finalExam,
    this.finalGrade,
    this.completionExam,
    this.afterCompletion,
  });

  final double? first;
  final double? midyear;
  final double? second;

  /// السعي السنوي = (معدل الفصل الأول + نصف السنة + معدل الفصل الثاني) ÷ 3
  final double? annual;
  final double? finalExam;

  /// الدرجة النهائية = (السعي السنوي + الامتحان النهائي) ÷ 2
  final double? finalGrade;
  final double? completionExam;

  /// الدرجة بعد الإكمال = (السعي السنوي + امتحان الإكمال) ÷ 2
  final double? afterCompletion;

  bool get needsCompletion => finalGrade != null && finalGrade! < Semesters.passMark;

  /// ناجح / مكمل / ناجح بالإكمال / راسب، أو فارغ إذا لم تكتمل الدرجات.
  String get status {
    if (finalGrade == null) return '';
    if (finalGrade! >= Semesters.passMark) return 'ناجح';
    if (afterCompletion == null) return 'مكمل';
    return afterCompletion! >= Semesters.passMark ? 'ناجح بالإكمال' : 'راسب';
  }
}

class CalculationService {
  CalculationService(this.store);

  final AppStore store;

  double get monthlyWeight => store.weight('monthlyExamsWeight', 70).toDouble();
  double get dailyWeight => store.weight('dailyExamsWeight', 20).toDouble();
  double get ratingWeight => store.weight('ratingWeight', 10).toDouble();


  /// نسبة حضور الطالب (معلومة للمتابعة فقط، لا تدخل في السعي).
  double? attendanceRate(String studentId, String sectionId) {
    final days = store.attendanceDays(sectionId);
    if (days.isEmpty) return null;
    final mine = store.attendance.where((a) => a.studentId == studentId && a.sectionId == sectionId);
    final absent = mine.where((r) => r.status == 'غائب').length;
    final excused = mine.where((r) => r.status == 'مجاز').length;
    final required = days.length - excused;
    if (required <= 0) return null;
    return (required - absent).clamp(0, required) / required * 100;
  }

  /// درجة الامتحان الشهري (من 100)، أو null إذا لم تُدخل أو كان الطالب مؤجلاً.
  double? monthlyExam(String studentId, String sectionId, String period) {
    for (final m in store.monthlyScores) {
      if (m.studentId == studentId && m.sectionId == sectionId && m.period == period) {
        if (m.status == 'مؤجل' || m.score == null) return null;
        return m.score!.clamp(0, 100).toDouble();
      }
    }
    return null;
  }

  /// نسب الامتحانات اليومية التي حضرها الطالب في الفصل (من 100)،
  /// كل امتحان حسب درجته الكاملة، فتتوزع درجة اليومي على عدد الامتحانات بالتناسب.
  List<double> dailyScores(String studentId, String sectionId, int semester) {
    final maxOf = {
      for (final e in store.dailyExams)
        if (e.sectionId == sectionId && e.semester == semester) e.id: store.dailyMaxOf(e),
    };
    final mine = {
      for (final s in store.dailyScores)
        if (s.studentId == studentId && maxOf.containsKey(s.examId)) s.examId: s,
    };
    final out = <double>[];
    for (final e in maxOf.entries) {
      final s = mine[e.key];
      if (s != null && s.status == 'غائب') continue; // الغائب مستبعد من معدله
      if (s != null && s.status == 'درجة' && s.score != null) {
        out.add(s.score!.clamp(0, e.value) / e.value * 100);
      } else {
        out.add(0); // لم تُدخل درجته = 0
      }
    }
    return out;
  }

  SemesterBreakdown semester(String studentId, String sectionId, int semester) {
    final monthly = <String, double>{};
    final postponed = <String>[];
    for (final def in store.monthlyExamsOf(sectionId, semester)) {
      MonthlyExamScore? rec;
      for (final m in store.monthlyScores) {
        if (m.studentId == studentId && m.sectionId == sectionId && m.period == def.key) rec = m;
      }
      if (rec?.score != null) {
        monthly[def.key] = rec!.score!.clamp(0, 100).toDouble();
      } else if (rec?.status == 'مؤجل') {
        postponed.add(def.name);
      } else {
        monthly[def.key] = 0; // لم يُدخل
      }
    }
    return SemesterBreakdown(
      semester: semester,
      monthlyScores: monthly,
      dailyScores: dailyScores(studentId, sectionId, semester),
      dailyMax: 100,
      monthlyLabel: store.componentLabel('monthly'),
      dailyLabel: store.componentLabel('daily'),
      ratingLabel: store.componentLabel('rating'),
      ratingScore: store.ratingOf(studentId, sectionId, semester),
      postponed: postponed,
      examCount: store.monthlyExamsOf(sectionId, semester).length +
          store.dailyExams.where((e) => e.sectionId == sectionId && e.semester == semester).length,
      monthlyWeight: monthlyWeight,
      dailyWeight: dailyWeight,
      ratingWeight: ratingWeight,
    );
  }

  /// سعي الفصل (من 100) أو null إذا لم يكتمل.
  double? semesterScore(String studentId, String sectionId, int semester) =>
      this.semester(studentId, sectionId, semester).total;

  /// للتوافق مع التقارير: يحدد الفصل من أسماء الأشهر.
  double? semesterAverage(String studentId, String sectionId, List<String> periods) {
    final s = periods.isEmpty ? 1 : Semesters.ofMonth(periods.first);
    return semesterScore(studentId, sectionId, s == 0 ? 1 : s);
  }

  /// درجة امتحان نصف السنة، أو null.
  double? midyear(String studentId, String sectionId) {
    for (final m in store.midyearScores) {
      if (m.studentId == studentId && m.sectionId == sectionId) {
        if (m.score == null || m.status == 'مؤجل') return null;
        return m.score!.clamp(0, 100).toDouble();
      }
    }
    return null;
  }

  /// نتيجة السنة كاملة للطالب.
  YearResult year(String studentId, String sectionId) {
    final first = semesterScore(studentId, sectionId, 1);
    final mid = midyear(studentId, sectionId);
    final second = semesterScore(studentId, sectionId, 2);
    final annual = annualResult(first: first, midyear: mid, second: second);
    final finalExam = monthlyExam(studentId, sectionId, Semesters.finalExam);
    final finalGrade = (annual == null || finalExam == null)
        ? null
        : GradeUtils.rawRound((annual + finalExam) / 2);
    final failed = finalGrade != null && finalGrade < Semesters.passMark;
    final completion = failed ? monthlyExam(studentId, sectionId, Semesters.completionExam) : null;
    final afterCompletion = (annual == null || completion == null)
        ? null
        : GradeUtils.rawRound((annual + completion) / 2);
    return YearResult(
      first: first,
      midyear: mid,
      second: second,
      annual: annual,
      finalExam: finalExam,
      finalGrade: finalGrade,
      completionExam: completion,
      afterCompletion: afterCompletion,
    );
  }

  double? annualResult({
    required double? first,
    required double? midyear,
    required double? second,
  }) {
    if (first == null || midyear == null || second == null) return null;
    return GradeUtils.rawRound((first + midyear + second) / 3);
  }
}
