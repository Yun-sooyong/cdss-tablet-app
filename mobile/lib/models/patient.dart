class Patient {
  final String id; // uuid — 나중에 서버 붙이면 DB의 User/환자 PK
  final String name;
  final String email;
  final DateTime? birthDate;
  final String? address;
  final String? phone;
  final String? profileImageUrl;

  Patient({
    required this.id,
    required this.name,
    required this.email,
    this.birthDate,
    this.address,
    this.phone,
    this.profileImageUrl,
  });

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        birthDate: json['birthDate'] != null
            ? DateTime.parse(json['birthDate'] as String)
            : null,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        profileImageUrl: json['profileImageUrl'] as String?,
      );

  // 개인정보 수정 화면에서 일부 필드만 바꿔서 새 Patient 객체를 만들 때 쓴다.
  Patient copyWith({
    String? name,
    DateTime? birthDate,
    String? address,
    String? phone,
  }) {
    return Patient(
      id: id,
      name: name ?? this.name,
      email: email,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl,
    );
  }
}
