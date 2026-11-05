class School {
  School({
    required this.id,
    required this.name,
    required this.code,
    this.directorName = '',
    this.district = '',
    this.address = '',
  });

  final String id;
  String name;
  String code;
  String directorName;
  String district;
  String address;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'directorName': directorName,
        'district': district,
        'address': address,
      };

  factory School.fromJson(Map<String, dynamic> j) => School(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        code: j['code'] ?? '',
        directorName: j['directorName'] ?? '',
        district: j['district'] ?? '',
        address: j['address'] ?? '',
      );
}
