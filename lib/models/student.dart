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
      );
}
