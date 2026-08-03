class Patient {
  final String id; // uuid — 나중에 서버 붙이면 DB의 User/환자 PK
  final String name;
  final String email;
  final String? profileImageUrl;

  Patient({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
  });

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    profileImageUrl: json['profileImageUrl'] as String?,
  );
}
