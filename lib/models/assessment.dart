class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.sectionId,
    required this.date,
    required this.status,
  });

  final String id;
  final String studentId;
  final String sectionId;
  final String date;
  String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'sectionId': sectionId,
        'date': date,
        'status': status,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) =>
      AttendanceRecord(
        id: j['id'] ?? '',
        studentId: j['studentId'] ?? '',
        sectionId: j['sectionId'] ?? '',
        date: j['date'] ?? '',
        status: j['status'] ?? 'حاضر',
      );
}

class BehaviorEvent {
  BehaviorEvent({
    required this.id,
    required this.studentId,
    required this.sectionId,
    required this.date,
    required this.rating,
  });

  final String id;
  final String studentId;
  final String sectionId;
  final String date;
  final int rating;

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'sectionId': sectionId,
        'date': date,
        'rating': rating,
      };

  factory BehaviorEvent.fromJson(Map<String, dynamic> j) => BehaviorEvent(
        id: j['id'] ?? '',
        studentId: j['studentId'] ?? '',
        sectionId: j['sectionId'] ?? '',
        date: j['date'] ?? '',
        rating: j['rating'] ?? 0,
      );
}

class ParticipationEvent {
  ParticipationEvent({
    required this.id,
    required this.studentId,
    required this.sectionId,
    required this.date,
    required this.participated,
  });

  final String id;
  final String studentId;
  final String sectionId;
  final String date;
  final bool participated;

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'sectionId': sectionId,
        'date': date,
        'participated': participated,
      };

  factory ParticipationEvent.fromJson(Map<String, dynamic> j) =>
      ParticipationEvent(
        id: j['id'] ?? '',
        studentId: j['studentId'] ?? '',
        sectionId: j['sectionId'] ?? '',
        date: j['date'] ?? '',
        participated: j['participated'] ?? false,
      );
}

class DailyExam {
  DailyExam({
    required this.id,
    required this.sectionId,
    required this.date,
    required this.title,
    this.semester = 1,
  });

  final String id;
  final String sectionId;
  final String date;
  final String title;

  /// الفصل الدراسي (1 أو 2) الذي يدخل فيه الامتحان.
  int semester;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sectionId': sectionId,
        'date': date,
        'title': title,
        'semester': semester,
      };

  factory DailyExam.fromJson(Map<String, dynamic> j) {
    final date = (j['date'] ?? '') as String;
    final raw = j['semester'];
    // الامتحانات القديمة بلا فصل: يُستنتج الفصل من تاريخها.
    final inferred = (DateTime.tryParse(date)?.month ?? 10);
    final semester = raw is num
        ? raw.toInt()
        : ((inferred >= 2 && inferred <= 8) ? 2 : 1);
    return DailyExam(
      id: j['id'] ?? '',
      sectionId: j['sectionId'] ?? '',
      date: date,
      title: j['title'] ?? '',
      semester: semester == 2 ? 2 : 1,
    );
  }
}

/// تقدير السلوك والمشاركة للطالب في فصل دراسي (درجة من 0 إلى 10).
class SemesterRating {
  SemesterRating({
    required this.id,
    required this.sectionId,
    required this.studentId,
    required this.semester,
    required this.score,
  });

  final String id;
  final String sectionId;
  final String studentId;
  final int semester;

  /// درجة التقدير من 0 إلى 10.
  int score;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sectionId': sectionId,
        'studentId': studentId,
        'semester': semester,
        'score': score,
      };

  factory SemesterRating.fromJson(Map<String, dynamic> j) => SemesterRating(
        id: j['id'] ?? '',
        sectionId: j['sectionId'] ?? '',
        studentId: j['studentId'] ?? '',
        semester: (j['semester'] as num?)?.toInt() ?? 1,
        score: j['score'] is num
            ? (j['score'] as num).round().clamp(0, 10)
            // نسخة سابقة كانت تحفظ مستوى من 0 إلى 4.
            : const [4, 5, 7, 8, 10][((j['level'] as num?)?.toInt() ?? 2).clamp(0, 4)],
      );
}

class DailyExamScore {
  DailyExamScore({
    required this.id,
    required this.examId,
    required this.studentId,
    this.score,
    this.status = 'درجة',
  });

  final String id;
  final String examId;
  final String studentId;
  double? score;
  String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'examId': examId,
        'studentId': studentId,
        'score': score,
        'status': status,
      };

  factory DailyExamScore.fromJson(Map<String, dynamic> j) =>
      DailyExamScore(
        id: j['id'] ?? '',
        examId: j['examId'] ?? '',
        studentId: j['studentId'] ?? '',
        score: j['score'] == null ? null : (j['score'] as num).toDouble(),
        status: j['status'] ?? 'درجة',
      );
}

class MonthlyExamScore {
  MonthlyExamScore({
    required this.id,
    required this.sectionId,
    required this.studentId,
    required this.period,
    this.score,
    this.status = 'مكتمل',
  });

  final String id;
  final String sectionId;
  final String studentId;
  final String period;
  double? score;
  String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sectionId': sectionId,
        'studentId': studentId,
        'period': period,
        'score': score,
        'status': status,
      };

  factory MonthlyExamScore.fromJson(Map<String, dynamic> j) =>
      MonthlyExamScore(
        id: j['id'] ?? '',
        sectionId: j['sectionId'] ?? '',
        studentId: j['studentId'] ?? '',
        period: j['period'] ?? '',
        score: j['score'] == null ? null : (j['score'] as num).toDouble(),
        status: j['status'] ?? 'مكتمل',
      );
}

class MidyearScore {
  MidyearScore({
    required this.id,
    required this.sectionId,
    required this.studentId,
    this.score,
    this.status = 'مكتمل',
  });

  final String id;
  final String sectionId;
  final String studentId;
  double? score;
  String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sectionId': sectionId,
        'studentId': studentId,
        'score': score,
        'status': status,
      };

  factory MidyearScore.fromJson(Map<String, dynamic> j) => MidyearScore(
        id: j['id'] ?? '',
        sectionId: j['sectionId'] ?? '',
        studentId: j['studentId'] ?? '',
        score: j['score'] == null ? null : (j['score'] as num).toDouble(),
        status: j['status'] ?? 'مكتمل',
      );
}
