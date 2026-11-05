import '../core/storage/app_store.dart';
import '../core/utils/arabic_name_utils.dart';
import '../models/academic.dart';
import '../models/assessment.dart';
import '../models/student.dart';
import 'calculation_service.dart';

/// ملفات التبادل بين نسخة الإدارة ونسخ المدرسين:
/// - «ملف الشعبة» (إدارة ← مدرس): قائمة الطلاب الموحّدة بمعرّفات ثابتة + مواد الصف.
/// - «ملف درجات المادة» (مدرس ← إدارة): النتائج المحسوبة لكل طالب في مادة واحدة.
class ExchangeService {
  ExchangeService._();

  static const sectionFormat = 'moeen-section';
  static const gradesFormat = 'moeen-grades';
  static const version = 1;

  // ===========================================================================
  // مواد كل صف (نسخة الإدارة)
  // ===========================================================================

  static const _intermediate = [
    'التربية الإسلامية', 'اللغة العربية', 'اللغة الإنكليزية', 'الاجتماعيات', 'الرياضيات',
    'الأحياء', 'الكيمياء', 'الفيزياء', 'التربية الرياضية', 'التربية الفنية',
  ];
  static const _scientific = [
    'التربية الإسلامية', 'اللغة العربية', 'اللغة الإنكليزية', 'الرياضيات',
    'الأحياء', 'الكيمياء', 'الفيزياء', 'الحاسوب',
  ];
  static const _literary = [
    'التربية الإسلامية', 'اللغة العربية', 'اللغة الإنكليزية', 'الرياضيات',
    'التاريخ', 'الجغرافية', 'الاقتصاد', 'علم الاجتماع',
  ];

  /// قائمة مقترحة حسب اسم الصف (تعدّلها الإدارة).
  static List<String> defaultSubjects(String grade) {
    final g = ArabicNameUtils.normalize(grade).replaceAll(RegExp('[أإآ]'), 'ا');
    if (g.contains('علمي')) return List.of(_scientific);
    if (g.contains('ادبي')) return List.of(_literary);
    return List.of(_intermediate);
  }

  static List<String> subjectsOf(AppStore admin, String grade) {
    final map = admin.settings['gradeSubjects'];
    if (map is Map && map[grade] is List) {
      return (map[grade] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return defaultSubjects(grade);
  }

  static Future<void> setSubjects(AppStore admin, String grade, List<String> subjects) async {
    final map = Map<String, dynamic>.from((admin.settings['gradeSubjects'] as Map?) ?? {});
    map[grade] = subjects.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    admin.settings['gradeSubjects'] = map;
    await admin.saveAll();
  }

  // ===========================================================================
  // ملف الشعبة: الإدارة ← المدرس
  // ===========================================================================

  static Map<String, dynamic> buildSectionFile(AppStore admin, Section section) {
    String yearName = '';
    for (final y in admin.years) {
      if (y.id == section.yearId) yearName = y.name;
    }
    return {
      'format': sectionFormat,
      'version': version,
      'exportedAt': DateTime.now().toIso8601String(),
      'school': admin.school?.name ?? '',
      'year': yearName,
      'section': {'id': section.id, 'grade': section.gradeName, 'name': section.name},
      'subjects': subjectsOf(admin, section.gradeName),
      'students': [
        for (final s in admin.studentsOf(section.id))
          {'id': s.id, 'name': s.name, 'nationalId': s.nationalId},
      ],
    };
  }

  static String sectionFileName(Section s) =>
      'moeen-shuba_${_safe(s.gradeName)}_${_safe(s.name)}.json';

  static SectionFileInfo inspectSectionFile(Object? decoded) {
    if (decoded is! Map || decoded['format'] != sectionFormat) {
      if (decoded is Map && decoded['format'] == gradesFormat) {
        throw const FormatException('هذا «ملف درجات مادة» من مدرس، ويُستلم في نسخة الإدارة.');
      }
      throw const FormatException('هذا الملف ليس «ملف شعبة» من إدارة المدرسة.');
    }
    final section = decoded['section'];
    if (section is! Map || decoded['students'] is! List) {
      throw const FormatException('ملف الشعبة ناقص أو تالف.');
    }
    return SectionFileInfo(
      schoolName: (decoded['school'] ?? '').toString(),
      year: (decoded['year'] ?? '').toString(),
      adminSectionId: (section['id'] ?? '').toString(),
      grade: (section['grade'] ?? '').toString(),
      sectionName: (section['name'] ?? '').toString(),
      subjects: [for (final s in (decoded['subjects'] as List? ?? [])) s.toString()],
      studentCount: (decoded['students'] as List).length,
    );
  }

  /// استيراد ملف الشعبة في نسخة المدرس لمادة [subject].
  /// - إن وُجدت الشعبة نفسها (من ملف سابق أو بنفس الصف والاسم والمادة) تُربط ولا تُكرر.
  /// - كل طالب في الملف يُربط بطالب المدرس المطابق (المعرّف ← الرقم الوطني ← الاسم)،
  ///   وإلا يُضاف. طلاب المدرس غير الموجودين في الملف يبقون ويُذكرون في النتيجة.
  static Future<SectionImportResult> importSectionFile(
    AppStore teacher,
    Object? decoded,
    String subject,
  ) async {
    final info = inspectSectionFile(decoded);
    final data = decoded as Map;

    if (teacher.school == null && info.schoolName.isNotEmpty) {
      // نسمح للمدرس بمعرفة اسم المدرسة في السجل دون إعادة كتابته.
      teacher.settings['schoolNameFromAdmin'] = info.schoolName;
    }

    String norm(String v) => ArabicNameUtils.key(v);
    Section? section;
    for (final s in teacher.sections) {
      if (s.adminSectionId == info.adminSectionId &&
          ArabicNameUtils.subjectKey(s.subjectName) == ArabicNameUtils.subjectKey(subject)) {
        section = s;
      }
    }
    section ??= teacher.sections.where((s) =>
        s.adminSectionId.isEmpty &&
        norm(s.gradeName) == norm(info.grade) &&
        norm(s.name) == norm(info.sectionName) &&
        ArabicNameUtils.subjectKey(s.subjectName) == ArabicNameUtils.subjectKey(subject)).firstOrNull;

    final created = section == null;
    section ??= await teacher.addSection(grade: info.grade, name: info.sectionName, subject: subject);
    section.adminSectionId = info.adminSectionId;
    final sectionId = section.id;
    final yearId = section.yearId;

    final existing = teacher.studentsOf(sectionId);
    final usedTeacherIds = <String>{};
    var linked = 0, added = 0;

    for (final raw in data['students'] as List) {
      if (raw is! Map) continue;
      final adminId = (raw['id'] ?? '').toString();
      final name = ArabicNameUtils.cleanName((raw['name'] ?? '').toString());
      final nid = (raw['nationalId'] ?? '').toString().trim();
      if (adminId.isEmpty || name.isEmpty) continue;

      Student? match;
      for (final s in existing) {
        if (!usedTeacherIds.contains(s.id) && s.adminId == adminId) match = s;
      }
      if (match == null && nid.isNotEmpty) {
        for (final s in existing) {
          if (!usedTeacherIds.contains(s.id) && s.adminId.isEmpty && s.nationalId.trim() == nid) match = s;
        }
      }
      if (match == null) {
        for (final s in existing) {
          if (!usedTeacherIds.contains(s.id) && s.adminId.isEmpty && norm(s.name) == norm(name)) match = s;
        }
      }

      if (match != null) {
        match.adminId = adminId;
        if (match.nationalId.trim().isEmpty && nid.isNotEmpty) match.nationalId = nid;
        usedTeacherIds.add(match.id);
        linked++;
      } else {
        await teacher.addStudent(
          Student(
            id: teacher.id(),
            schoolId: teacher.school?.id ?? '',
            number: '0',
            name: name,
            nationalId: nid,
            adminId: adminId,
            createdAt: DateTime.now().toIso8601String(),
          ),
          sectionId,
          yearId,
        );
        added++;
      }
    }

    final unlinked = [
      for (final s in teacher.studentsOf(sectionId))
        if (s.adminId.isEmpty) s.name,
    ];
    await teacher.saveAll();
    return SectionImportResult(
      section: section,
      createdSection: created,
      linked: linked,
      added: added,
      teacherOnly: unlinked,
    );
  }

  // ===========================================================================
  // ملف درجات المادة: المدرس ← الإدارة
  // ===========================================================================

  static Map<String, dynamic> buildGradesFile(AppStore teacher, Section section) {
    final calc = CalculationService(teacher);
    String yearName = '';
    for (final y in teacher.years) {
      if (y.id == section.yearId) yearName = y.name;
    }
    return {
      'format': gradesFormat,
      'version': version,
      'exportedAt': DateTime.now().toIso8601String(),
      'teacher': (teacher.settings['teacherName'] ?? '').toString(),
      'school': teacher.school?.name ?? (teacher.settings['schoolNameFromAdmin'] ?? '').toString(),
      'year': yearName,
      'subject': section.subjectName,
      'section': {
        'adminId': section.adminSectionId,
        'grade': section.gradeName,
        'name': section.name,
      },
      'students': [
        for (final s in teacher.studentsOf(section.id))
          () {
            final y = calc.year(s.id, section.id);
            return {
              'adminId': s.adminId,
              'name': s.name,
              'nationalId': s.nationalId,
              'values': [
                y.first, y.midyear, y.second, y.annual,
                y.finalExam, y.finalGrade, y.completionExam, y.afterCompletion,
              ],
              'note': y.status,
            };
          }(),
      ],
    };
  }

  static String gradesFileName(Section s) =>
      'moeen-darajat_${_safe(s.subjectName)}_${_safe(s.gradeName)}_${_safe(s.name)}.json';

  static GradesFileInfo inspectGradesFile(Object? decoded) {
    if (decoded is! Map || decoded['format'] != gradesFormat) {
      if (decoded is Map && decoded['format'] == sectionFormat) {
        throw const FormatException('هذا «ملف شعبة» من الإدارة، ويُستورد في نسخة المدرس.');
      }
      throw const FormatException('هذا الملف ليس «ملف درجات مادة» من مُعين.');
    }
    final section = decoded['section'];
    if (section is! Map || decoded['students'] is! List) {
      throw const FormatException('ملف الدرجات ناقص أو تالف.');
    }
    return GradesFileInfo(
      subject: (decoded['subject'] ?? '').toString(),
      teacher: (decoded['teacher'] ?? '').toString(),
      grade: (section['grade'] ?? '').toString(),
      sectionName: (section['name'] ?? '').toString(),
      adminSectionId: (section['adminId'] ?? '').toString(),
      studentCount: (decoded['students'] as List).length,
      exportedAt: DateTime.tryParse((decoded['exportedAt'] ?? '').toString()),
    );
  }

  /// استلام ملف درجات مادة في نسخة الإدارة. يحل محل درجات نفس المادة لنفس الشعبة.
  /// [addMissingStudents]: الطلاب الموجودون عند المدرس وغير الموجودين في الإدارة يُضافون
  /// إلى الشعبة بأسمائهم وأرقامهم الوطنية (فلا تحتاج الإدارة لكتابة الأسماء).
  /// [createSection]: إذا لم توجد الشعبة في الإدارة تُنشأ من بيانات الملف.
  static Future<GradesImportResult> importGradesFile(
    AppStore admin,
    Object? decoded, {
    bool addMissingStudents = false,
    bool createSection = false,
  }) async {
    final info = inspectGradesFile(decoded);
    final data = decoded as Map;
    String norm(String v) => ArabicNameUtils.key(v);

    Section? section;
    for (final s in admin.sections) {
      if (info.adminSectionId.isNotEmpty && s.id == info.adminSectionId) section = s;
    }
    section ??= admin.sections
        .where((s) => norm(s.gradeName) == norm(info.grade) && norm(s.name) == norm(info.sectionName))
        .firstOrNull;
    var createdSection = false;
    if (section == null) {
      if (!createSection || info.grade.trim().isEmpty || info.sectionName.trim().isEmpty) {
        throw FormatException('لا توجد في الإدارة شعبة «${info.grade} ${info.sectionName}». أضفها أولاً ثم أعد الاستلام.');
      }
      section = await admin.addSection(grade: info.grade.trim(), name: info.sectionName.trim(), subject: '');
      createdSection = true;
    }
    final target = section;

    // اسم المادة كما في قائمة مواد الصف عند الإدارة.
    final subjects = subjectsOf(admin, target.gradeName);
    final key = ArabicNameUtils.subjectKey(info.subject);
    final subject = subjects.where((s) => ArabicNameUtils.subjectKey(s) == key).firstOrNull ?? info.subject.trim();
    final inList = subjects.contains(subject);

    final students = admin.studentsOf(target.id);
    final byId = {for (final s in students) s.id: s};
    final grades = <SubjectGrade>[];
    final unmatched = <String>[];
    final addedStudents = <String>[];
    final seen = <String>{};

    for (final raw in data['students'] as List) {
      if (raw is! Map) continue;
      final adminId = (raw['adminId'] ?? '').toString();
      final name = (raw['name'] ?? '').toString();
      final nid = (raw['nationalId'] ?? '').toString().trim();
      Student? st = byId[adminId];
      if (st == null && nid.isNotEmpty) {
        st = students.where((s) => s.nationalId.trim() == nid).firstOrNull;
      }
      st ??= students.where((s) => norm(s.name) == norm(name)).firstOrNull;
      final cleanName = ArabicNameUtils.cleanName(name);
      if (st == null && addMissingStudents && cleanName.isNotEmpty) {
        final created = Student(
          id: admin.id(),
          schoolId: admin.school?.id ?? '',
          number: '0',
          name: cleanName,
          nationalId: nid,
          createdAt: DateTime.now().toIso8601String(),
        );
        await admin.addStudent(created, target.id, target.yearId);
        students.add(created);
        st = created;
        addedStudents.add(cleanName);
      }
      if (st == null || !seen.add(st.id)) {
        if (st == null) unmatched.add(name);
        continue;
      }
      final rawValues = raw['values'];
      final values = List<double?>.filled(SubjectGrade.columns, null);
      if (rawValues is List) {
        for (var i = 0; i < SubjectGrade.columns && i < rawValues.length; i++) {
          final v = rawValues[i];
          values[i] = v is num ? v.toDouble() : null;
        }
      }
      grades.add(SubjectGrade(
        id: admin.id() + st.id,
        sectionId: target.id,
        studentId: st.id,
        subject: subject,
        values: values,
        note: (raw['note'] ?? '').toString(),
        teacherName: info.teacher,
        receivedAt: DateTime.now().toIso8601String(),
      ));
    }

    final replaced = admin.subjectGrades.any((g) => g.sectionId == target.id && g.subject == subject);
    admin.subjectGrades.removeWhere((g) => g.sectionId == target.id && g.subject == subject);
    admin.subjectGrades.addAll(grades);
    await admin.saveAll();

    final missingStudents = [
      for (final s in admin.studentsOf(target.id))
        if (!seen.contains(s.id)) s.name,
    ];
    return GradesImportResult(
      section: target,
      createdSection: createdSection,
      addedStudents: addedStudents,
      subject: subject,
      teacher: info.teacher,
      subjectInList: inList,
      received: grades.length,
      replaced: replaced,
      unmatched: unmatched,
      missingStudents: missingStudents,
    );
  }

  static String _safe(String v) =>
      v.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '-').replaceAll(RegExp('-+'), '-');
}

class SectionFileInfo {
  const SectionFileInfo({
    required this.schoolName,
    required this.year,
    required this.adminSectionId,
    required this.grade,
    required this.sectionName,
    required this.subjects,
    required this.studentCount,
  });
  final String schoolName, year, adminSectionId, grade, sectionName;
  final List<String> subjects;
  final int studentCount;
}

class SectionImportResult {
  const SectionImportResult({
    required this.section,
    required this.createdSection,
    required this.linked,
    required this.added,
    required this.teacherOnly,
  });
  final Section section;
  final bool createdSection;
  final int linked, added;

  /// طلاب عند المدرس غير موجودين في قائمة الإدارة (لن تصل درجاتهم).
  final List<String> teacherOnly;
}

class GradesFileInfo {
  const GradesFileInfo({
    required this.subject,
    required this.teacher,
    required this.grade,
    required this.sectionName,
    required this.adminSectionId,
    required this.studentCount,
    required this.exportedAt,
  });
  final String subject, teacher, grade, sectionName, adminSectionId;
  final int studentCount;
  final DateTime? exportedAt;
}

class GradesImportResult {
  const GradesImportResult({
    required this.section,
    this.createdSection = false,
    this.addedStudents = const [],
    required this.subject,
    required this.teacher,
    required this.subjectInList,
    required this.received,
    required this.replaced,
    required this.unmatched,
    required this.missingStudents,
  });
  final Section section;

  /// أُنشئت الشعبة من ملف المدرس لأنها لم تكن موجودة.
  final bool createdSection;

  /// طلاب أُضيفوا إلى الإدارة من ملف المدرس.
  final List<String> addedStudents;
  final String subject, teacher;
  final bool subjectInList, replaced;
  final int received;

  /// أسماء في ملف المدرس لا يوجد لها طالب في الإدارة.
  final List<String> unmatched;

  /// طلاب الشعبة الذين لم تصل درجاتهم في هذا الملف.
  final List<String> missingStudents;
}
