import '../core/constants/semesters.dart';
import '../core/storage/app_store.dart';
import '../models/academic.dart';
import '../models/assessment.dart';
import 'exchange_service.dart';

/// النتيجة العامة لطالب في كل المواد (نسخة الإدارة).
class StudentOverallResult {
  StudentOverallResult({
    required this.subjects,
    required this.grades,
    required this.maxCompletion,
  });

  /// مواد الصف بالترتيب.
  final List<String> subjects;

  /// درجات كل مادة، أو null إذا لم تصل من المدرس.
  final Map<String, SubjectGrade?> grades;
  final int maxCompletion;

  /// مواد لم تصل درجاتها، أو وصلت بلا درجة نهائية.
  List<String> get missing => [
        for (final s in subjects)
          if (grades[s]?.finalGrade == null) s,
      ];

  /// مواد درجتها النهائية أقل من 50 (تحتاج إكمالاً).
  List<String> get failed => [
        for (final s in subjects)
          if (grades[s]?.finalGrade != null && grades[s]!.finalGrade! < Semesters.passMark) s,
      ];

  /// مواد ما زالت دون 50 بعد امتحان الإكمال.
  List<String> get failedAfterCompletion => [
        for (final s in failed)
          if (grades[s]?.afterCompletion != null && grades[s]!.afterCompletion! < Semesters.passMark) s,
      ];

  bool get completionPending => failed.any((s) => grades[s]?.afterCompletion == null);

  /// النتيجة كما تُكتب في السجل الوسطي.
  String get status {
    if (missing.isNotEmpty) return '';
    final f = failed;
    if (f.isEmpty) return 'ناجح';
    if (f.length > maxCompletion) return 'راسب';
    if (completionPending) return 'مكمل';
    return failedAfterCompletion.isEmpty ? 'ناجح بالإكمال' : 'راسب';
  }

  /// النتيجة مع التفاصيل (للشاشة والطباعة).
  String get statusDetail {
    final m = missing;
    if (m.isNotEmpty) return 'ناقص: ${m.join('، ')}';
    final st = status;
    if (st == 'مكمل') return 'مكمل في ${failed.join('، ')}';
    if (st == 'راسب' && failed.length > maxCompletion) return 'راسب (${failed.length} مواد دون ${Semesters.passMark})';
    if (st == 'راسب') return 'راسب في ${failedAfterCompletion.join('، ')}';
    return st;
  }

  /// مجموع كل عمود للمواد التي وصلت فيها القيمة.
  List<double?> get totals {
    final out = List<double?>.filled(SubjectGrade.columns, null);
    for (var c = 0; c < SubjectGrade.columns; c++) {
      double sum = 0;
      var any = false;
      for (final s in subjects) {
        final v = grades[s]?.values[c];
        if (v != null) {
          sum += v;
          any = true;
        }
      }
      out[c] = any ? double.parse(sum.toStringAsFixed(2)) : null;
    }
    return out;
  }
}

/// حالة استلام مادة لشعبة: كم طالباً وصلت درجته ومن المدرس.
class SubjectReceipt {
  const SubjectReceipt({
    required this.subject,
    required this.received,
    required this.total,
    required this.teacher,
    required this.receivedAt,
  });
  final String subject;
  final int received, total;
  final String teacher;
  final DateTime? receivedAt;
  bool get isComplete => total > 0 && received >= total;
  bool get isMissing => received == 0;
}

class AdminResultsService {
  AdminResultsService(this.store);
  final AppStore store;

  int get maxCompletion {
    final v = store.settings['maxCompletionSubjects'];
    return v is num ? v.toInt().clamp(0, 20) : 3;
  }

  StudentOverallResult studentResult(String studentId, Section section) {
    final subjects = ExchangeService.subjectsOf(store, section.gradeName);
    final grades = <String, SubjectGrade?>{for (final s in subjects) s: null};
    for (final g in store.subjectGrades) {
      if (g.sectionId == section.id && g.studentId == studentId && grades.containsKey(g.subject)) {
        grades[g.subject] = g;
      }
    }
    return StudentOverallResult(subjects: subjects, grades: grades, maxCompletion: maxCompletion);
  }

  List<SubjectReceipt> receipts(Section section) {
    final subjects = ExchangeService.subjectsOf(store, section.gradeName);
    final total = store.studentsOf(section.id).length;
    return [
      for (final subject in subjects)
        () {
          final rows = store.subjectGrades.where((g) => g.sectionId == section.id && g.subject == subject).toList();
          return SubjectReceipt(
            subject: subject,
            received: rows.length,
            total: total,
            teacher: rows.isEmpty ? '' : rows.first.teacherName,
            receivedAt: rows.isEmpty ? null : DateTime.tryParse(rows.first.receivedAt),
          );
        }(),
    ];
  }

  /// ملخص الشعبة: عدد الناجحين والمكملين والراسبين والناقصين.
  Map<String, int> summary(Section section) {
    final out = {'ناجح': 0, 'ناجح بالإكمال': 0, 'مكمل': 0, 'راسب': 0, 'ناقص': 0};
    for (final st in store.studentsOf(section.id)) {
      final status = studentResult(st.id, section).status;
      final key = status.isEmpty ? 'ناقص' : status;
      out[key] = (out[key] ?? 0) + 1;
    }
    return out;
  }
}
