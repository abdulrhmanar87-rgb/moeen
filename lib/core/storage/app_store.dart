import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'kv_store.dart';
import '../../models/school.dart';
import '../../models/student.dart';
import '../../models/academic.dart';
import '../../models/assessment.dart';
import '../utils/arabic_numbers.dart';
import '../utils/arabic_sort.dart';

class AppStore {
  /// [namespace] يفصل بيانات «نسخة الإدارة» عن «نسخة المدرس» على نفس الجهاز.
  /// نسخة المدرس تبقى بدون بادئة (نفس مفاتيحها القديمة) فلا تتأثر بياناتها.
  AppStore({this.namespace = ''});

  final String namespace;
  bool get isAdmin => namespace == 'admin';

  String _k(String key) => namespace.isEmpty ? key : '${namespace}__$key';

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
  static const _subjectGradesKey = 'moeen_subject_grades';

  late KvStore _prefs;

  /// رسالة خطأ إذا فشل آخر حفظ (مثل امتلاء المساحة)، وإلا null.
  final saveError = ValueNotifier<String?>(null);

  /// نوع التخزين وحالة حمايته (للإعدادات).
  String get storageBackend => _prefs.backend;
  bool? get storagePersisted => _prefs.persisted;
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

  /// نسخة الإدارة: درجات المواد المستلمة من المدرسين.
  List<SubjectGrade> subjectGrades = [];
  Map<String, dynamic> settings = {
    // سعي الفصل من 100.
    'monthlyExamsWeight': 70,
    'dailyExamsWeight': 20,
    'ratingWeight': 10,
  };

  /// أسماء عناصر سعي الفصل، قابلة للتعديل من الإعدادات (مثل «العملي» بدل «اليومي»).
  static const componentDefaults = {
    'monthly': 'الامتحانات الشهرية',
    'daily': 'الامتحانات اليومية',
    'rating': 'السلوك والمشاركة',
  };

  String componentLabel(String key) {
    final v = settings['label_$key'];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return componentDefaults[key] ?? key;
  }

  /// الدرجة الكاملة للامتحانات اليومية القديمة التي أُنشئت قبل أن يكون لكل امتحان درجته.
  double get legacyDailyMax {
    final raw = settings['dailyExamInputMax'];
    final value = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
    if (value == null || value <= 0) return 10;
    return value.clamp(1, 100).toDouble();
  }

  double dailyMaxOf(DailyExam e) => e.maxScore ?? legacyDailyMax;

  /// الدرجة الكاملة المقترحة لامتحان يومي جديد: نفس آخر امتحان أُنشئ.
  double get lastDailyMax => dailyExams.isEmpty ? legacyDailyMax : dailyMaxOf(dailyExams.last);

  int weight(String key, int fallback) {
    final value = settings[key];
    if (value is num) return value.toInt().clamp(0, 100);
    final parsed = int.tryParse(value?.toString() ?? '');
    return (parsed ?? fallback).clamp(0, 100);
  }

  Future<void> init() async {
    _prefs = await KvStore.open();
    final schoolRaw = _prefs.getString(_k(_schoolKey));
    if (schoolRaw != null) school = School.fromJson(jsonDecode(schoolRaw));
    years = _decode(_k(_yearsKey), AcademicYear.fromJson);
    sections = _decode(_k(_sectionsKey), Section.fromJson);
    students = _decode(_k(_studentsKey), Student.fromJson);
    enrollments = _decode(_k(_enrollmentsKey), Enrollment.fromJson);
    attendance = _decode(_k(_attendanceKey), AttendanceRecord.fromJson);
    _compactAttendance();
    behavior = _decode(_k(_behaviorKey), BehaviorEvent.fromJson);
    participation = _decode(_k(_participationKey), ParticipationEvent.fromJson);
    dailyExams = _decode(_k(_dailyExamsKey), DailyExam.fromJson);
    dailyScores = _decode(_k(_dailyScoresKey), DailyExamScore.fromJson);
    monthlyScores = _decode(_k(_monthlyScoresKey), MonthlyExamScore.fromJson);
    midyearScores = _decode(_k(_midyearKey), MidyearScore.fromJson);
    semesterRatings = _decode(_k(_ratingsKey), SemesterRating.fromJson);
    subjectGrades = _decode(_k(_subjectGradesKey), SubjectGrade.fromJson);
    final rawSettings = _prefs.getString(_k(_settingsKey));
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

  String _enc(List<dynamic> list) => jsonEncode(list.map((e) => e.toJson()).toList());

  /// يحفظ كل شيء في معاملة واحدة، ولا يكتب إلا ما تغيّر.
  Future<void> saveAll() async {
    final values = <String, String>{
      if (school != null) _k(_schoolKey): jsonEncode(school!.toJson()),
      _k(_yearsKey): _enc(years),
      _k(_sectionsKey): _enc(sections),
      _k(_studentsKey): _enc(students),
      _k(_enrollmentsKey): _enc(enrollments),
      _k(_attendanceKey): _enc(attendance),
      _k(_behaviorKey): _enc(behavior),
      _k(_participationKey): _enc(participation),
      _k(_dailyExamsKey): _enc(dailyExams),
      _k(_dailyScoresKey): _enc(dailyScores),
      _k(_monthlyScoresKey): _enc(monthlyScores),
      _k(_midyearKey): _enc(midyearScores),
      _k(_ratingsKey): _enc(semesterRatings),
      _k(_subjectGradesKey): _enc(subjectGrades),
      _k(_settingsKey): jsonEncode(settings),
    };
    try {
      await _prefs.setMany(values);
      if (saveError.value != null) saveError.value = null;
    } catch (_) {
      saveError.value = 'تعذر حفظ آخر التغييرات على هذا الجهاز. احفظ نسخة احتياطية الآن من الإعدادات، '
          'وتأكد من وجود مساحة فارغة.';
    }
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
    final ids = studentsOf(sectionId).map((s) => s.id).toList();
    final map = {for (final id in ids) id: attendanceOf(sectionId, date, id) ?? 'حاضر'}..[studentId] = status;
    await saveAttendanceDay(sectionId: sectionId, date: date, studentIds: ids, statuses: map);
  }

  /// علامة «سُجّل حضور هذا اليوم»: سجل بلا طالب. الحاضرون لا يُخزَّنون،
  /// فقط الغائب والمجاز، فيبقى حجم البيانات صغيراً طوال السنة.
  static const attendanceDayMarker = 'يوم';

  /// حالة الطالب في يوم، أو null إذا لم يُسجَّل حضور ذلك اليوم.
  String? attendanceOf(String sectionId, String date, String studentId) {
    var taken = false;
    for (final a in attendance) {
      if (a.sectionId != sectionId || a.date != date) continue;
      if (a.studentId == studentId) return a.status;
      taken = true;
    }
    return taken ? 'حاضر' : null;
  }

  /// هل سُجّل حضور هذه الشعبة في هذا اليوم؟
  bool attendanceTaken(String sectionId, String date) =>
      attendance.any((a) => a.sectionId == sectionId && a.date == date);

  /// الأيام التي سُجّل فيها حضور الشعبة.
  Set<String> attendanceDays(String sectionId) =>
      {for (final a in attendance) if (a.sectionId == sectionId) a.date};

  /// تسجيل حضور يوم كامل بحفظ واحد: من لم تُحدد حالته يُعد «حاضر».
  Future<void> saveAttendanceDay({
    required String sectionId,
    required String date,
    required List<String> studentIds,
    required Map<String, String> statuses,
  }) async {
    attendance.removeWhere((a) => a.sectionId == sectionId && a.date == date);
    attendance.add(AttendanceRecord(
      id: 'd_${sectionId}_$date',
      studentId: '',
      sectionId: sectionId,
      date: date,
      status: attendanceDayMarker,
    ));
    for (final sid in studentIds) {
      final status = statuses[sid] ?? 'حاضر';
      if (status == 'حاضر') continue;
      attendance.add(AttendanceRecord(id: 'a_${date}_$sid', studentId: sid, sectionId: sectionId, date: date, status: status));
    }
    await saveAll();
  }

  /// يحوّل سجلات الحضور القديمة (سجل لكل حاضر) إلى الشكل المختصر.
  void _compactAttendance() {
    if (!attendance.any((a) => a.status == 'حاضر')) return;
    final days = <String>{};
    final kept = <AttendanceRecord>[];
    for (final a in attendance) {
      final key = '${a.sectionId}|${a.date}';
      if (days.add(key)) {
        kept.add(AttendanceRecord(
          id: 'd_${a.sectionId}_${a.date}',
          studentId: '',
          sectionId: a.sectionId,
          date: a.date,
          status: attendanceDayMarker,
        ));
      }
      if (a.studentId.isNotEmpty && a.status != 'حاضر' && a.status != attendanceDayMarker) kept.add(a);
    }
    attendance = kept;
  }

  /// حذف تسجيل حضور يوم كامل لشعبة.
  Future<void> clearAttendanceDay(String sectionId, String date) async {
    attendance.removeWhere((a) => a.sectionId == sectionId && a.date == date);
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
    subjectGrades.removeWhere((e) => e.sectionId == sectionId);

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
    await _prefs.setString(_k(_settingsKey), jsonEncode(settings));
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
    await saveAll();
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
      'subjectGrades': j(subjectGrades),
      'edition': isAdmin ? 'admin' : 'teacher',
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

  /// رسالة إذا كان الملف نسخة احتياطية للنسخة الأخرى (مدرس/إدارة)، وإلا null.
  /// النسخ القديمة بلا حقل edition هي نسخ مدرس.
  String? editionMismatch(Object? decoded) {
    final fileIsAdmin = decoded is Map && decoded['edition'] == 'admin';
    if (fileIsAdmin == isAdmin) return null;
    return fileIsAdmin
        ? 'هذا الملف نسخة احتياطية لـ«نسخة الإدارة». غيّر نوع النسخة من الإعدادات ثم استعده.'
        : 'هذا الملف نسخة احتياطية لـ«نسخة المدرس». غيّر نوع النسخة من الإعدادات ثم استعده.';
  }

  /// استبدال كل البيانات بمحتوى النسخة. يُقرأ الملف كاملاً ويُتحقق منه أولاً،
  /// فإذا كان تالفاً لا يتغير أي شيء من البيانات الحالية.
  Future<void> importData(Object? decoded) async {
    inspectBackup(decoded);
    final mismatch = editionMismatch(decoded);
    if (mismatch != null) throw FormatException(mismatch);
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
    final newSubjectGrades = parse('subjectGrades', SubjectGrade.fromJson);
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
    _compactAttendance();
    behavior = newBehavior;
    participation = newParticipation;
    dailyExams = newDailyExams;
    dailyScores = newDailyScores;
    monthlyScores = newMonthlyScores;
    midyearScores = newMidyear;
    semesterRatings = newRatings;
    subjectGrades = newSubjectGrades;
    settings = newSettings;
    if (school == null) await _prefs.remove(_k(_schoolKey));
    await saveAll();
  }

  /// يمسح بيانات هذه النسخة فقط (المدرس أو الإدارة)، ولا يلمس النسخة الأخرى.
  Future<void> clearAllData() async {
    for (final key in const [
      _schoolKey, _yearsKey, _sectionsKey, _studentsKey, _enrollmentsKey,
      _attendanceKey, _behaviorKey, _participationKey, _dailyExamsKey,
      _dailyScoresKey, _monthlyScoresKey, _midyearKey, _settingsKey,
      _ratingsKey, _subjectGradesKey,
    ]) {
      await _prefs.remove(_k(key));
    }
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
    subjectGrades.clear();
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
