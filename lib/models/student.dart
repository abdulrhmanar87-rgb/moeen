class Student {
  Student({
    required this.id,
    required this.schoolId,
    required this.number,
    required this.name,
    this.nationalId = '',
    this.photoPath = '',
    this.notes = '',
    this.createdAt = '',
    this.adminId = '',
    this.regNo = '',
    this.birthDate = '',
    this.failedYears = '',
  });

  final String id;
  final String schoolId;

  // رقم تسلسلي يديره مُعين تلقائياً حسب الترتيب الأبجدي في الشعبة.
  String number;
  String name;
  String nationalId;
  String photoPath;
  String notes;
  String createdAt;

  /// معرّف الطالب في «نسخة الإدارة» (يربط الطالب نفسه عند كل المدرسين).
  String adminId;

  // بيانات السجل الوسطي (تُدخلها الإدارة).
  String regNo; // رقم القيد
  String birthDate; // المواليد
  String failedYears; // سنوات الرسوب

  // معرف ثابت داخلي لا يتأثر بإعادة ترتيب الطلاب.
  String get globalKey => '$schoolId-$id';

  Map<String, dynamic> toJson() => {
        'id': id,
        'schoolId': schoolId,
        'number': number,
        'name': name,
        'nationalId': nationalId,
        'photoPath': photoPath,
        'notes': notes,
        'createdAt': createdAt,
        if (adminId.isNotEmpty) 'adminId': adminId,
        if (regNo.isNotEmpty) 'regNo': regNo,
        if (birthDate.isNotEmpty) 'birthDate': birthDate,
        if (failedYears.isNotEmpty) 'failedYears': failedYears,
      };

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'] ?? '',
        schoolId: j['schoolId'] ?? '',
        number: j['number'] ?? '',
        name: j['name'] ?? '',
        nationalId: j['nationalId'] ?? '',
        photoPath: j['photoPath'] ?? '',
        notes: j['notes'] ?? '',
        createdAt: j['createdAt'] ?? '',
        adminId: (j['adminId'] ?? '').toString(),
        regNo: (j['regNo'] ?? '').toString(),
        birthDate: (j['birthDate'] ?? '').toString(),
        failedYears: (j['failedYears'] ?? '').toString(),
      );
}
