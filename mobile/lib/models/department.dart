class Department {
  final String code;
  final String name;
  final String? extension;

  Department({required this.code, required this.name, this.extension});

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      code: json['dept_code'] as String,
      name: json['name'] as String,
      extension: json['extension'] as String?,
    );
  }
}