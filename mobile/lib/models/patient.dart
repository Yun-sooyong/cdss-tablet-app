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

extension SexLabel on Sex {
  String get label {
    switch (this) {
      case Sex.m:
        return '남성';
      case Sex.f:
        return '여성';
      case Sex.o:
        return '기타';
      case Sex.u:
        return '선택 안함';
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
  }) {
    return Patient(
      id: id,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      sex: sex ?? this.sex,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      signupProvider: signupProvider ?? this.signupProvider,
      kakaoLinked: kakaoLinked ?? this.kakaoLinked,
    );
  }
}
