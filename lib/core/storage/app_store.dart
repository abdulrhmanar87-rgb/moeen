import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/school.dart';
import '../../models/student.dart';
import '../../models/academic.dart';
import '../../models/assessment.dart';
import '../utils/arabic_numbers.dart';
import '../utils/arabic_sort.dart';

class AppStore {
  static const _schoolKey = 'moeen_school';
  static const _yearsKey = 'moeen_years';
  static const _sectionsKey = 'moeen_sections';
  static const _studentsKey = 'moeen_students';
  static const _enrollmentsKey = 'moeen_enrollments';
  static const _attendanceKey = 'moeen_attendance';
  static const _behaviorKey = 'moeen_behavior';
  static const _participationKey = 'moeen_participation';
  static const _dailyExamsKey = 'moeen_daily_exams';
  static const _dailyScoresKey = 'moeen_daily_scores';
  static const _monthlyScoresKey = 'moeen_monthly_scores';
  static const _midyearKey = 'moeen_midyear';
  static const _settingsKey = 'moeen_settings';
  static const _ratingsKey = 'moeen_semester_ratings';

  late SharedPreferences _prefs;
  School? school;
  List<AcademicYear> years = [];
  List<Section> sections = [];
  List<Student> students = [];
  List<Enrollment> enrollments = [];
  List<AttendanceRecord> attendance = [];
  List<BehaviorEvent> behavior = [];
  List<ParticipationEvent> participation = [];
  List<DailyExam> dailyExams = [];
  List<DailyExamScore> dailyScores = [];
  List<MonthlyExamScore> monthlyScores = [];
  List<MidyearScore> midyearScores = [];
  List<SemesterRating> semesterRatings = [];
  Map<String, dynamic> settings = {
    // سعي الفصل من 100.
    'monthlyExamsWeight': 70,
    'dailyExamsWeight': 20,
    'ratingWeight': 10,
  };

  int weight(String key, int fallback) {
    final value = settings[key];
    if (value is num) return value.toInt().clamp(0, 100);
    final parsed = int.tryParse(value?.toString() ?? '');
    return (parsed ?? fallback).clamp(0, 100);
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final schoolRaw = _prefs.getString(_schoolKey);
    if (schoolRaw != null) school = School.fromJson(jsonDecode(schoolRaw));
    years = _decode(_yearsKey, AcademicYear.fromJson);
    sections = _decode(_sectionsKey, Section.fromJson);
    students = _decode(_studentsKey, Student.fromJson);
    enrollments = _decode(_enrollmentsKey, Enrollment.fromJson);
    attendance = _decode(_attendanceKey, AttendanceRecord.fromJson);
    behavior = _decode(_behaviorKey, BehaviorEvent.fromJson);
    participation = _decode(_participationKey, ParticipationEvent.fromJson);
    dailyExams = _decode(_dailyExamsKey, DailyExam.fromJson);
    dailyScores = _decode(_dailyScoresKey, DailyExamScore.fromJson);
    monthlyScores = _decode(_monthlyScoresKey, MonthlyExamScore.fromJson);
    midyearScores = _decode(_midyearKey, MidyearScore.fromJson);
    semesterRatings = _decode(_ratingsKey, SemesterRating.fromJson);
    final rawSettings = _prefs.getString(_settingsKey);
    if (rawSettings != null) settings = jsonDecode(rawSettings);
    // الأرقام أصبحت إنكليزية دائماً داخل التطبيق؛ إزالة الإعداد القديم
    // وتوحيد أي أرقام عربية محفوظة سابقاً.
    settings.remove('arabicNumbers');
    for (final s in students) {
      s.number = ArabicNumbers.toEnglish(s.number);
      s.nationalId = ArabicNumbers.toEnglish(s.nationalId);
    }
  }

  List<T> _decode<T>(String key, T Function(Map<String, dynamic>) parser) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => parser(Map<String, dynamic>.from(e))).toList();
  }

  String id() => '${DateTime.now().microsecondsSinceEpoch}_${students.length + years.length + sections.length}';

  Future<void> _save(String key, List<dynamic> list) =>
      _prefs.setString(key, jsonEncode(list.map((e) => e.toJson()).toList()));

  Future<void> saveAll() async {
    if (school != null) {
      await _prefs.setString(_schoolKey, jsonEncode(school!.toJson()));
    }
    await _save(_yearsKey, years);
    await _save(_sectionsKey, sections);
    await _save(_studentsKey, students);
    await _save(_enrollmentsKey, enrollments);
    await _save(_attendanceKey, attendance);
    await _save(_behaviorKey, behavior);
    await _save(_participationKey, participation);
    await _save(_dailyExamsKey, dailyExams);
    await _save(_dailyScoresKey, dailyScores);
    await _save(_monthlyScoresKey, monthlyScores);
    await _save(_midyearKey, midyearScores);
    await _save(_ratingsKey, semesterRatings);
    await _prefs.setString(_settingsKey, jsonEncode(settings));
  }

  List<Student> studentsOf(String sectionId) {
    final ids = enrollments
        .where((e) => e.sectionId == sectionId && e.endDate == null)
        .map((e) => e.studentId)
        .toSet();

    final list = students.where((s) => ids.contains(s.id)).toList()
      ..sort((a, b) {
        final byName = ArabicSort.compare(a.name, b.name);
        if (byName != 0) return byName;
        return a.id.compareTo(b.id);
      });

    // الرقم هنا تسلسل عرض فقط، ومُعين يعيد ترتيبه تلقائياً.
    for (var i = 0; i < list.length; i++) {
      list[i].number = '${i + 1}';
    }
    return list;
  }

  Future<void> renumberSection(String sectionId) async {
    studentsOf(sectionId);
    await saveAll();
  }

  Future<void> addStudent(Student student, String sectionId, String yearId) async {
    students.add(student);
    enrollments.add(Enrollment(
      id: id(),
      studentId: student.id,
      sectionId: sectionId,
      yearId: yearId,
      startDate: DateTime.now().toIso8601String(),
    ));
    await saveAll();
    await renumberSection(sectionId);
  }

  Future<void> updateStudent(Student student) async {
    final i = students.indexWhere((s) => s.id == student.id);
    if (i < 0) return;
    students[i] = student;
    await saveAll();
  }

  Future<void> moveStudent({
    required String studentId,
    required String fromSectionId,
    required String toSectionId,
    required String yearId,
  }) async {
    if (fromSectionId == toSectionId) return;
    final index = enrollments.indexWhere((e) =>
        e.studentId == studentId &&
        e.sectionId == fromSectionId &&
        e.endDate == null);
    if (index >= 0) {
      enrollments[index]
        ..endDate = DateTime.now().toIso8601String()
        ..status = 'منقول';
    }
    enrollments.add(Enrollment(
      id: id(),
      studentId: studentId,
      sectionId: toSectionId,
      yearId: yearId,
      startDate: DateTime.now().toIso8601String(),
      status: 'مستمر',
    ));
    await saveAll();
  }

  Future<void> archiveStudentFromSection(String studentId, String sectionId) async {
    final index = enrollments.indexWhere((e) =>
        e.studentId == studentId &&
        e.sectionId == sectionId &&
        e.endDate == null);
    if (index < 0) return;
    enrollments[index]
      ..endDate = DateTime.now().toIso8601String()
      ..status = 'مؤرشف';
    await saveAll();
  }

  Future<void> setAttendance({
    required String sectionId,
    required String date,
    required String studentId,
    required String status,
  }) async {
    final i = attendance.indexWhere((a) =>
        a.sectionId == sectionId && a.date == date && a.studentId == studentId);
    if (i >= 0) {
      attendance[i].status = status;
    } else {
      attendance.add(AttendanceRecord(
        id: id(),
        studentId: studentId,
        sectionId: sectionId,
        date: date,
        status: status,
      ));
    }
    await saveAll();
  }

  Future<void> setBehavior(String sectionId, String studentId, int rating) async {
    behavior.add(BehaviorEvent(
      id: id(),
      studentId: studentId,
      sectionId: sectionId,
      date: DateTime.now().toIso8601String(),
      rating: rating,
    ));
    await saveAll();
  }

  Future<void> setParticipation(String sectionId, String studentId, bool participated) async {
    participation.add(ParticipationEvent(
      id: id(),
      studentId: studentId,
      sectionId: sectionId,
      date: DateTime.now().toIso8601String(),
      participated: participated,
    ));
    await saveAll();
  }

  /// السنة الدراسية الحالية (تُنشأ تلقائياً إذا لم تكن موجودة).
  AcademicYear ensureCurrentYear([String name = '2026-2027']) {
    if (years.isNotEmpty) return years.first;
    final year = AcademicYear(id: id(), schoolId: school?.id ?? '', name: name);
    years.add(year);
    return year;
  }

  /// هل توجد شعبة بنفس الصف واسم الشعبة والمادة؟ (لمنع التكرار)
  bool sectionExists(String grade, String name, String subject, {String? exceptId}) {
    String k(String v) => v.trim().replaceAll(RegExp(r'\s+'), ' ');
    return sections.any((s) =>
        s.id != exceptId &&
        k(s.gradeName) == k(grade) &&
        k(s.name) == k(name) &&
        k(s.subjectName) == k(subject));
  }

  Future<Section> addSection({
    required String grade,
    required String name,
    required String subject,
  }) async {
    final year = ensureCurrentYear();
    final section = Section(
      id: id(),
      yearId: year.id,
      gradeName: grade.trim(),
      name: name.trim(),
      subjectName: subject.trim(),
    );
    sections.add(section);
    await saveAll();
    return section;
  }

  Future<void> updateSection(Section section) async {
    final i = sections.indexWhere((s) => s.id == section.id);
    if (i < 0) return;
    sections[i] = section;
    await saveAll();
  }

  /// حذف شعبة مع كل بياناتها (التسجيل، الحضور، السلوك، المشاركة، الدرجات).
  /// الطالب الذي لا ينتمي لأي شعبة أخرى يُحذف أيضاً.
  Future<void> deleteSection(String sectionId) async {
    final studentIds = enrollments
        .where((e) => e.sectionId == sectionId)
        .map((e) => e.studentId)
        .toSet();
    final examIds = dailyExams
        .where((e) => e.sectionId == sectionId)
        .map((e) => e.id)
        .toSet();

    sections.removeWhere((s) => s.id == sectionId);
    enrollments.removeWhere((e) => e.sectionId == sectionId);
    attendance.removeWhere((e) => e.sectionId == sectionId);
    behavior.removeWhere((e) => e.sectionId == sectionId);
    participation.removeWhere((e) => e.sectionId == sectionId);
    dailyExams.removeWhere((e) => e.sectionId == sectionId);
    dailyScores.removeWhere((e) => examIds.contains(e.examId));
    monthlyScores.removeWhere((e) => e.sectionId == sectionId);
    midyearScores.removeWhere((e) => e.sectionId == sectionId);
    semesterRatings.removeWhere((e) => e.sectionId == sectionId);

    final stillEnrolled = enrollments.map((e) => e.studentId).toSet();
    students.removeWhere(
        (s) => studentIds.contains(s.id) && !stillEnrolled.contains(s.id));
    await saveAll();
  }

  /// الشعبة المختارة في التطبيق كله (تُحفظ وتبقى بعد إغلاق التطبيق).
  /// إذا حُذفت الشعبة المحفوظة تُستخدم أول شعبة.
  String? get currentSectionId {
    final saved = settings['currentSectionId'];
    if (saved is String && sections.any((s) => s.id == saved)) return saved;
    return sections.isEmpty ? null : sections.first.id;
  }

  Future<void> setCurrentSection(String? sectionId) async {
    if (sectionId == null || settings['currentSectionId'] == sectionId) return;
    settings['currentSectionId'] = sectionId;
    await _prefs.setString(_settingsKey, jsonEncode(settings));
  }

  /// تقدير السلوك والمشاركة للطالب في الفصل، أو null إذا لم يُقيَّم.
  int? ratingOf(String studentId, String sectionId, int semester) {
    for (final r in semesterRatings) {
      if (r.studentId == studentId && r.sectionId == sectionId && r.semester == semester) {
        return r.score;
      }
    }
    return null;
  }

  Future<void> setRating(String studentId, String sectionId, int semester, int? score) async {
    semesterRatings.removeWhere((r) =>
        r.studentId == studentId && r.sectionId == sectionId && r.semester == semester);
    if (score != null) {
      semesterRatings.add(SemesterRating(
        id: id(),
        sectionId: sectionId,
        studentId: studentId,
        semester: semester,
        score: score.clamp(0, 10),
      ));
    }
    await saveAll();
  }

  // ===========================================================================
  // النسخ الاحتياطي
  // ===========================================================================

  static const backupFormat = 'moeen-backup';
  static const backupVersion = 1;

  /// تاريخ آخر نسخة احتياطية، أو null إذا لم تُعمل نسخة بعد.
  DateTime? get lastBackupAt => DateTime.tryParse((settings['lastBackupAt'] ?? '').toString());

  Future<void> markBackedUp() async {
    settings['lastBackupAt'] = DateTime.now().toIso8601String();
    await _prefs.setString(_settingsKey, jsonEncode(settings));
  }

  /// كل بيانات مُعين في ملف واحد. مفتاح القراءة الذكية لا يُصدَّر حفاظاً على خصوصيته.
  Map<String, dynamic> exportData() {
    List<dynamic> j(List<dynamic> list) => list.map((e) => e.toJson()).toList();
    final cleanSettings = Map<String, dynamic>.from(settings)
      ..remove('geminiApiKey')
      ..remove('lastBackupAt');
    return {
      'format': backupFormat,
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'school': school?.toJson(),
      'years': j(years),
      'sections': j(sections),
      'students': j(students),
      'enrollments': j(enrollments),
      'attendance': j(attendance),
      'behavior': j(behavior),
      'participation': j(participation),
      'dailyExams': j(dailyExams),
      'dailyScores': j(dailyScores),
      'monthlyScores': j(monthlyScores),
      'midyearScores': j(midyearScores),
      'semesterRatings': j(semesterRatings),
      'settings': cleanSettings,
    };
  }

  /// الحجم التقريبي للبيانات بالبايت (المتصفح يسمح بحوالي 5 ميغابايت).
  int get dataSizeBytes => utf8.encode(jsonEncode(exportData())).length;

  /// يتحقق من ملف النسخة ويعيد ملخصاً عنه دون تغيير أي شيء.
  /// يرمي FormatException إذا لم يكن الملف نسخة صالحة من مُعين.
  static BackupSummary inspectBackup(Object? decoded) {
    if (decoded is! Map || decoded['format'] != backupFormat) {
      throw const FormatException('هذا الملف ليس نسخة احتياطية من مُعين.');
    }
    final version = decoded['version'];
    if (version is num && version > backupVersion) {
      throw const FormatException('هذه النسخة صُنعت بإصدار أحدث من مُعين. حدّث التطبيق ثم أعد المحاولة.');
    }
    int count(String key) => decoded[key] is List ? (decoded[key] as List).length : 0;
    final school = decoded['school'];
    return BackupSummary(
      exportedAt: DateTime.tryParse((decoded['exportedAt'] ?? '').toString()),
      schoolName: school is Map ? (school['name'] ?? '').toString() : '',
      sections: count('sections'),
      students: count('students'),
      scores: count('dailyScores') + count('monthlyScores') + count('midyearScores'),
      attendance: count('attendance'),
    );
  }

  /// استبدال كل البيانات بمحتوى النسخة. يُقرأ الملف كاملاً ويُتحقق منه أولاً،
  /// فإذا كان تالفاً لا يتغير أي شيء من البيانات الحالية.
  Future<void> importData(Object? decoded) async {
    inspectBackup(decoded);
    final data = Map<String, dynamic>.from(decoded as Map);

    List<T> parse<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final value = data[key];
      if (value == null) return <T>[];
      if (value is! List) throw FormatException('الملف تالف (القسم $key).');
      return value.map((e) => fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }

    final newSchool = data['school'] is Map
        ? School.fromJson(Map<String, dynamic>.from(data['school'] as Map))
        : null;
    final newYears = parse('years', AcademicYear.fromJson);
    final newSections = parse('sections', Section.fromJson);
    final newStudents = parse('students', Student.fromJson);
    final newEnrollments = parse('enrollments', Enrollment.fromJson);
    final newAttendance = parse('attendance', AttendanceRecord.fromJson);
    final newBehavior = parse('behavior', BehaviorEvent.fromJson);
    final newParticipation = parse('participation', ParticipationEvent.fromJson);
    final newDailyExams = parse('dailyExams', DailyExam.fromJson);
    final newDailyScores = parse('dailyScores', DailyExamScore.fromJson);
    final newMonthlyScores = parse('monthlyScores', MonthlyExamScore.fromJson);
    final newMidyear = parse('midyearScores', MidyearScore.fromJson);
    final newRatings = parse('semesterRatings', SemesterRating.fromJson);
    final newSettings = data['settings'] is Map
        ? Map<String, dynamic>.from(data['settings'] as Map)
        : <String, dynamic>{};

    // نحتفظ بمفتاح القراءة الذكية وتاريخ آخر نسخة من هذا الجهاز.
    for (final key in ['geminiApiKey', 'lastBackupAt']) {
      if (settings[key] != null) newSettings[key] = settings[key];
    }

    school = newSchool;
    years = newYears;
    sections = newSections;
    students = newStudents;
    enrollments = newEnrollments;
    attendance = newAttendance;
    behavior = newBehavior;
    participation = newParticipation;
    dailyExams = newDailyExams;
    dailyScores = newDailyScores;
    monthlyScores = newMonthlyScores;
    midyearScores = newMidyear;
    semesterRatings = newRatings;
    settings = newSettings;
    if (school == null) await _prefs.remove(_schoolKey);
    await saveAll();
  }

  Future<void> clearAllData() async {
    await _prefs.clear();
    school = null;
    years.clear();
    sections.clear();
    students.clear();
    enrollments.clear();
    attendance.clear();
    behavior.clear();
    participation.clear();
    dailyExams.clear();
    dailyScores.clear();
    monthlyScores.clear();
    midyearScores.clear();
    semesterRatings.clear();
  }
}

/// ملخص ملف نسخة احتياطية، يُعرض قبل الاستعادة.
class BackupSummary {
  const BackupSummary({
    required this.exportedAt,
    required this.schoolName,
    required this.sections,
    required this.students,
    required this.scores,
    required this.attendance,
  });

  final DateTime? exportedAt;
  final String schoolName;
  final int sections;
  final int students;
  final int scores;
  final int attendance;
}
