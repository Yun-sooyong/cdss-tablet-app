import 'package:dio/dio.dart';
import 'package:tablet/api/api.dart';
import 'package:tablet/data/analysis_repository.dart';
import 'package:tablet/models/models.dart';

/// ⚠️ 이름·생년월일·전화번호는 암호화 컬럼이라 서버가 DB 레벨에서 LIKE 검색을
/// 하지 못한다. 그래서 검색 키가 셋으로 한정된다.
///
/// - `chartNumber` — 평문 인덱스. **부분일치 가능**
/// - `phone` — `phone_hash(SHA-256)` 비교. 정확일치만
/// - `name` + `birthDate` — `name_dob_hash(SHA-256)` 비교. 정확일치만.
///   **둘 중 하나만 주면 서버가 400을 준다**
abstract interface class PatientRepository {
  Future<List<PatientSummary>> search({
    String? chartNumber,
    String? name,
    DateTime? birthDate,
    String? phone,
  });

  /// 의료진용 워크인 등록. 계정 없이 Patient만 만든다. 반환값은 patient id.
  Future<String> create({
    required String name,
    required DateTime birthDate,
    required String phone,
    String sex = 'U',
  });

  /// 환자 앱이 만든 일회성 QR 토큰(5분 만료)을 검증한다.
  ///
  /// ⚠️ OpenAPI에 성공 응답 스키마가 없다(`200: nobody`). 실제로는 환자 정보를
  /// 주는 것으로 보여 방어적으로 파싱한다 — 못 알아보면 null을 돌려준다.
  Future<PatientSummary?> verifyQr(String token);
}

class HttpPatientRepository implements PatientRepository {
  HttpPatientRepository(this._dio);
  final Dio _dio;

  @override
  Future<List<PatientSummary>> search({
    String? chartNumber,
    String? name,
    DateTime? birthDate,
    String? phone,
  }) async {
    final q = <String, dynamic>{};
    if (chartNumber != null && chartNumber.isNotEmpty) {
      q['chart_number'] = chartNumber;
    }
    if (phone != null && phone.isNotEmpty) q['phone'] = phone;
    // 이름은 생년월일과 짝이어야 한다. 하나만 있으면 서버가 400이므로
    // 호출하지 않고 빈 목록을 돌려준다.
    if (name != null && name.isNotEmpty && birthDate != null) {
      q['name'] = name;
      q['birth_date'] = _isoDate(birthDate);
    }
    if (q.isEmpty) return const [];

    final res = await _dio.get(Endpoints.patientSearch, queryParameters: q);
    return HttpAnalysisRepository.itemsOf(res.data)
        .map((e) => PatientSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<String> create({
    required String name,
    required DateTime birthDate,
    required String phone,
    String sex = 'U',
  }) async {
    final res = await _dio.post(
      Endpoints.patients,
      data: {
        'name': name,
        'birth_date': _isoDate(birthDate),
        'phone': phone,
        'sex': sex,
      },
    );
    // 응답 구성이 확정되지 않아 id만 쓴다
    return (res.data as Map<String, dynamic>)['id'] as String;
  }

  @override
  Future<PatientSummary?> verifyQr(String token) async {
    final res = await _dio.post(Endpoints.qrVerify, data: {'token': token});
    final data = res.data;
    if (data is! Map<String, dynamic>) return null;

    // 응답 스키마가 확정되지 않아 환자 정보가 어디 실려 오든 찾아본다.
    // 확정되면 이 분기를 지우고 한 줄로 줄인다.
    final body = switch (data) {
      {'patient_summary': final Map<String, dynamic> p} => p,
      {'patient': final Map<String, dynamic> p} => p,
      _ when data.containsKey('chart_number') || data.containsKey('name') =>
        data,
      _ => null,
    };
    return body == null ? null : PatientSummary.fromJson(body);
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
