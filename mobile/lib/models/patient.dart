<<<<<<< HEAD
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
=======
enum Sex { m, f, o, u }

extension SexCode on Sex {
  String get code => {Sex.m: 'M', Sex.f: 'F', Sex.o: 'O', Sex.u: 'U'}[this]!;

  static Sex fromCode(String? code) {
    switch (code) {
      case 'M':
        return Sex.m;
      case 'F':
        return Sex.f;
      case 'O':
        return Sex.o;
      default:
        return Sex.u;
    }
  }
}

class Patient {
  final String id;
  final String name;
  final DateTime? birthDate;
  final Sex sex;
  final String? address;
  final String? phone;
  final String? email;
  final String? profileImageUrl;
  final String signupProvider; // 'email' | 'kakao'
  final bool kakaoLinked;

  const Patient({
    required this.id,
    required this.name,
    this.birthDate,
    this.sex = Sex.u,
    this.address,
    this.phone,
    this.email,
    this.profileImageUrl,
    this.signupProvider = 'email',
    this.kakaoLinked = false,
  });

  factory Patient.fromJson(Map<String, dynamic> json, {Patient? previous}) {
    return Patient(
      id: json['id'] as String,
      name: json['name'] as String,
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      sex: SexCode.fromCode(json['sex'] as String?),
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: previous?.email,
      profileImageUrl: previous?.profileImageUrl,
      signupProvider: previous?.signupProvider ?? 'email',
      kakaoLinked: previous?.kakaoLinked ?? false,
    );
  }

  Patient copyWith({
    String? name,
    DateTime? birthDate,
    Sex? sex,
    String? address,
    String? phone,
    String? email,
    String? profileImageUrl,
    String? signupProvider,
    bool? kakaoLinked,
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
  }) {
    return Patient(
      id: id,
      name: name ?? this.name,
<<<<<<< HEAD
      email: email,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl,
=======
      birthDate: birthDate ?? this.birthDate,
      sex: sex ?? this.sex,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      signupProvider: signupProvider ?? this.signupProvider,
      kakaoLinked: kakaoLinked ?? this.kakaoLinked,
>>>>>>> 4bf4cf3c8ad4123992d564a8f598ba516127f66d
    );
  }
}
