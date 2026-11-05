class AcademicYear {
  AcademicYear({
    required this.id,
    required this.schoolId,
    required this.name,
    this.isActive = true,
  });

  final String id;
  final String schoolId;
  String name;
  bool isActive;

  Map<String, dynamic> toJson() => {
        'id': id,
        'schoolId': schoolId,
        'name': name,
        'isActive': isActive,
      };

  factory AcademicYear.fromJson(Map<String, dynamic> j) => AcademicYear(
        id: j['id'] ?? '',
        schoolId: j['schoolId'] ?? '',
        name: j['name'] ?? '',
        isActive: j['isActive'] ?? true,
      );
}

class Section {
  Section({
    required this.id,
    required this.yearId,
    required this.gradeName,
    required this.name,
    required this.subjectName,
  });

  final String id;
  final String yearId;
  String gradeName;
  String name;
  String subjectName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'yearId': yearId,
        'gradeName': gradeName,
        'name': name,
        'subjectName': subjectName,
      };

  factory Section.fromJson(Map<String, dynamic> j) => Section(
        id: j['id'] ?? '',
        yearId: j['yearId'] ?? '',
        gradeName: j['gradeName'] ?? '',
        name: j['name'] ?? '',
        subjectName: j['subjectName'] ?? '',
      );
}

class Enrollment {
  Enrollment({
    required this.id,
    required this.studentId,
    required this.sectionId,
    required this.yearId,
    required this.startDate,
    this.endDate,
    this.status = 'مستمر',
  });

  final String id;
  final String studentId;
  final String sectionId;
  final String yearId;
  String startDate;
  String? endDate;
  String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentId': studentId,
        'sectionId': sectionId,
        'yearId': yearId,
        'startDate': startDate,
        'endDate': endDate,
        'status': status,
      };

  factory Enrollment.fromJson(Map<String, dynamic> j) => Enrollment(
        id: j['id'] ?? '',
        studentId: j['studentId'] ?? '',
        sectionId: j['sectionId'] ?? '',
        yearId: j['yearId'] ?? '',
        startDate: j['startDate'] ?? '',
        endDate: j['endDate'],
        status: j['status'] ?? 'مستمر',
      );
}
