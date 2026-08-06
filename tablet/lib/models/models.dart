/// 서버 응답을 그대로 옮긴 모델들.
///
/// ⚠️ OpenAPI 스키마보다 실제 응답이 앞서 있다. `image_count`·`needs_review_count`·
/// `jobs`·`mask_url` 은 스키마에 없지만 실제로는 내려온다. 스키마가 아니라
/// 실제 응답을 기준으로 맞춘다.
library;

double? _d(Object? v) => v == null ? null : (v as num).toDouble();

// ------------------------------------------------------------------------ 환자

/// batch·job 응답에 끼워 들어오는 판독용 최소 정보.
/// 주소·전화번호처럼 민감한 필드는 서버가 의도적으로 뺐다.
class PatientSummary {
  const PatientSummary({
    required this.id,
    required this.chartNumber,
    required this.name,
    this.birthDate,
    this.sex,
  });

  final String id;
  final String chartNumber;
  final String name;
  final DateTime? birthDate;
  final String? sex; // M | F | O | U

  factory PatientSummary.fromJson(Map<String, dynamic> j) => PatientSummary(
    id: j['id'] as String,
    chartNumber: j['chart_number'] as String? ?? '',
    name: j['name'] as String? ?? '',
    birthDate: j['birth_date'] == null
        ? null
        : DateTime.parse(j['birth_date'] as String),
    sex: j['sex'] as String?,
  );
}

// ------------------------------------------------------------------- 이미지·잡

class ImageSummary {
  const ImageSummary({required this.id, required this.originalFilename});

  final String id;
  final String originalFilename;

  factory ImageSummary.fromJson(Map<String, dynamic> j) => ImageSummary(
    id: j['id'] as String,
    originalFilename: j['original_filename'] as String? ?? '',
  );
}

enum JobStatus {
  queued('queued', '대기'),
  running('running', '실행중'),
  stilDone('stil_done', 'sTIL 완료'), // ⚠️ 서버 철자가 stil_done
  succeeded('succeeded', '완료'),
  failed('failed', '실패');

  const JobStatus(this.raw, this.label);
  final String raw;
  final String label;

  static JobStatus parse(String v) =>
      values.firstWhere((e) => e.raw == v, orElse: () => JobStatus.queued);

  /// stil_done은 끝이 아니다 — sTIL은 나왔지만 리포트가 남은 중간 상태
  bool get isTerminal => this == succeeded || this == failed;
}

class MedgemmaReport {
  const MedgemmaReport({
    this.findings,
    this.aiOpinion,
    this.segmentationSummary,
    this.disclaimer,
    this.opinionNote,
    this.generationFailed = false,
  });

  final String? findings;
  final String? aiOpinion;
  final String? segmentationSummary;
  final String? disclaimer;
  final String? opinionNote;
  final bool generationFailed;

  factory MedgemmaReport.fromJson(Map<String, dynamic> j) => MedgemmaReport(
    findings: j['findings'] as String?,
    aiOpinion: j['ai_opinion'] as String?,
    segmentationSummary: j['segmentation_summary'] as String?,
    disclaimer: j['disclaimer'] as String?,
    opinionNote: j['opinion_note'] as String?,
    generationFailed: j['generation_failed'] as bool? ?? false,
  );
}

/// 판독 확정 값. 서버 `DecisionEnum` 은 LOW/HIGH 둘뿐이다
/// (ABSTAIN은 확정 대상이지 확정 결과가 아니다).
enum JobDecision {
  low('LOW', 'LOW'),
  high('HIGH', 'HIGH');

  const JobDecision(this.raw, this.label);
  final String raw;
  final String label;
}

/// 판정 유보(ABSTAIN)를 의료진이 확정한 기록.
///
/// 서버는 `Job.result`/`status` 를 건드리지 않고 이걸 append-only 로 쌓는다.
/// 즉 **원본 추론값은 그대로 남고** 확정은 별도 사실로 기록된다.
class JobReview {
  const JobReview({
    required this.id,
    required this.decision,
    required this.reason,
    this.reviewedBy,
    this.createdAt,
  });

  final String id;
  final String decision; // LOW | HIGH
  final String reason;
  final String? reviewedBy;
  final DateTime? createdAt;

  factory JobReview.fromJson(Map<String, dynamic> j) => JobReview(
    id: j['id'] as String,
    decision: j['decision'] as String? ?? '',
    reason: j['reason'] as String? ?? '',
    reviewedBy: j['reviewed_by'] as String?,
    createdAt: j['created_at'] == null
        ? null
        : DateTime.parse(j['created_at'] as String),
  );
}

class JobResult {
  const JobResult({
    this.stilValue,
    this.lower,
    this.upper,
    this.sigma,
    this.cpValue,
    this.nValid,
    this.abstain = false,
    this.decision,
    this.classComposition = const {},
    this.report,
  });

  final double? stilValue;
  final double? lower; // Conformal 하한
  final double? upper; // Conformal 상한
  final double? sigma;
  final double? cpValue;
  final int? nValid;
  final bool abstain;
  final String? decision; // LOW | HIGH | ABSTAIN
  final Map<String, double> classComposition;
  final MedgemmaReport? report;

  /// 모델이 판정을 유보했는가. 서버가 두 방식으로 표현해서 둘 다 본다.
  bool get isAbstain => abstain || decision == 'ABSTAIN';

  factory JobResult.fromJson(Map<String, dynamic> j) {
    final cc = (j['class_composition'] as Map?)?.cast<String, dynamic>() ?? {};
    final rep = j['medgemma_report'] as Map<String, dynamic>?;
    return JobResult(
      stilValue: _d(j['stil_value']),
      lower: _d(j['lower']),
      upper: _d(j['upper']),
      sigma: _d(j['sigma']),
      cpValue: _d(j['cp_value']),
      nValid: (j['n_valid'] as num?)?.toInt(),
      abstain: j['abstain'] as bool? ?? false,
      decision: j['decision'] as String?,
      classComposition: {for (final e in cc.entries) e.key: _d(e.value) ?? 0},
      report: rep == null ? null : MedgemmaReport.fromJson(rep),
    );
  }
}

class Job {
  const Job({
    required this.id,
    required this.status,
    required this.createdAt,
    this.image,
    this.result,
    this.maskUrl,
    this.originalUrl,
    this.review,
    this.errorMessage = '',
    this.startedAt,
    this.finishedAt,
  });

  final String id;
  final JobStatus status;
  final DateTime createdAt;
  final ImageSummary? image;
  final JobResult? result;

  /// ⚠️ GCS 서명 URL — 15분(900초) 만료. 오래 캐시하면 깨진다
  final String? maskUrl;

  /// 원본 이미지 읽기용 서명 URL.
  /// ⚠️ 서버가 아직 안 내려준다 — 항상 null이다. 버킷이 비공개라 앱이 직접
  /// 서명할 수도 없다. `image_summary.original_url` 이 추가되면 자동으로 채워진다.
  final String? originalUrl;

  /// 판정 유보를 의료진이 확정한 기록. 없으면 아직 확정 전이다.
  final JobReview? review;

  final String errorMessage;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// 유보 상태인데 아직 확정되지 않았다.
  /// 이 상태의 배치는 공유하지 않는다 — 판정이 정해지지 않은 결과다.
  bool get needsReview => (result?.isAbstain ?? false) && review == null;

  factory Job.fromJson(Map<String, dynamic> j) {
    final img = j['image_summary'] as Map<String, dynamic>?;
    final res = j['result'] as Map<String, dynamic>?;
    final rev = j['review'] as Map<String, dynamic>?;
    return Job(
      id: j['id'] as String,
      status: JobStatus.parse(j['status'] as String),
      createdAt: DateTime.parse(j['created_at'] as String),
      image: img == null ? null : ImageSummary.fromJson(img),
      result: res == null ? null : JobResult.fromJson(res),
      maskUrl: j['mask_url'] as String?,
      originalUrl: (img?['original_url'] ?? j['original_url']) as String?,
      review: rev == null ? null : JobReview.fromJson(rev),
      errorMessage: j['error_message'] as String? ?? '',
      startedAt: j['started_at'] == null
          ? null
          : DateTime.parse(j['started_at'] as String),
      finishedAt: j['finished_at'] == null
          ? null
          : DateTime.parse(j['finished_at'] as String),
    );
  }
}

// --------------------------------------------------------------------- 알림

/// `GET /notifications/`. 서버가 전부 readOnly로 내려주고
/// **읽음 처리 엔드포인트는 아직 없다** — is_read는 표시만 한다.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.body,
    required this.type,
    this.targetType = '',
    this.targetId = '',
    this.isRead = false,
    this.createdAt,
  });

  final String id;
  final String body;
  final String type;
  final String targetType; // 'batch' 등
  final String targetId;
  final bool isRead;
  final DateTime? createdAt;

  /// 알림이 배치를 가리키면 그 배치로 이동할 수 있다
  String? get batchId => targetType == 'batch' && targetId.isNotEmpty
      ? targetId
      : null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    body: j['body'] as String? ?? '',
    type: j['type'] as String? ?? '',
    targetType: j['target_type'] as String? ?? '',
    targetId: j['target_id'] as String? ?? '',
    isRead: j['is_read'] as bool? ?? false,
    createdAt: j['created_at'] == null
        ? null
        : DateTime.parse(j['created_at'] as String),
  );
}

/// 계정 발급 신청 시 고르는 직군.
enum StaffRole {
  doctor('doctor', '의사'),
  nurse('nurse', '간호사'),
  admin('admin', '관리자');

  const StaffRole(this.raw, this.label);
  final String raw;
  final String label;
}

// ------------------------------------------------------------- 직원 · 공유

class Staff {
  const Staff({
    required this.id,
    required this.username,
    this.email = '',
    this.role = '',
    this.department = '',
    this.employmentStatus = '',
  });

  final String id;
  final String username;
  final String email;
  final String role; // admin | doctor | nurse
  final String department;
  final String employmentStatus; // active | ...

  bool get isActive => employmentStatus == 'active';

  /// 판정 유보 확정은 의사만 할 수 있다 (서버가 role=doctor로 막는다)
  bool get canReview => role == 'doctor';

  String get label =>
      department.isEmpty ? '$username ($role)' : '$username · $department';

  factory Staff.fromJson(Map<String, dynamic> j) => Staff(
    id: j['id'] as String,
    username: j['username'] as String? ?? '',
    email: j['email'] as String? ?? '',
    role: j['role'] as String? ?? '',
    department: j['department'] as String? ?? '',
    employmentStatus: j['employment_status'] as String? ?? '',
  );
}

class AnalysisShare {
  const AnalysisShare({
    required this.id,
    required this.batchId,
    required this.sharedTo,
    this.opinion = '',
    this.sharedBy,
    this.expiresAt,
    this.revokedAt,
    this.createdAt,
  });

  final String id;
  final String batchId;
  final String sharedTo; // staff id

  /// 공유하면서 함께 보내는 소견. 최대 200자.
  /// (예전의 read/comment 권한 필드를 서버가 이걸로 대체했다)
  final String opinion;

  final String? sharedBy;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final DateTime? createdAt;

  /// 회수됐거나 만료된 공유는 목록에서 흐리게 표시한다
  bool get isLive =>
      revokedAt == null &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory AnalysisShare.fromJson(Map<String, dynamic> j) => AnalysisShare(
    id: j['id'] as String,
    batchId: j['batch'] as String? ?? '',
    sharedTo: j['shared_to'] as String? ?? '',
    sharedBy: j['shared_by'] as String?,
    opinion: j['opinion'] as String? ?? '',
    expiresAt: j['expires_at'] == null
        ? null
        : DateTime.parse(j['expires_at'] as String),
    revokedAt: j['revoked_at'] == null
        ? null
        : DateTime.parse(j['revoked_at'] as String),
    createdAt: j['created_at'] == null
        ? null
        : DateTime.parse(j['created_at'] as String),
  );
}

// ------------------------------------------------------------- 모델 · 업로드

class ModelVersion {
  const ModelVersion({
    required this.id,
    required this.name,
    required this.version,
    this.conformalQ,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String version;
  final double? conformalQ;
  final bool isActive;

  String get label => '$name ($version)';

  factory ModelVersion.fromJson(Map<String, dynamic> j) => ModelVersion(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    version: j['version'] as String? ?? '',
    conformalQ: _d(j['conformal_q']),
    isActive: j['is_active'] as bool? ?? true,
  );
}

/// `POST /batches/{id}/images/` 응답. `upload_url` 로 GCS에 직접 PUT 한다.
class ImageUpload {
  const ImageUpload({
    required this.id,
    required this.uploadUrl,
    this.storageKey = '',
    this.originalFilename = '',
    this.imageUrl,
  });

  final String id;
  final String uploadUrl;
  final String storageKey;
  final String originalFilename;
  final String? imageUrl;

  factory ImageUpload.fromJson(Map<String, dynamic> j) => ImageUpload(
    id: j['id'] as String,
    uploadUrl: j['upload_url'] as String,
    storageKey: j['storage_key'] as String? ?? '',
    originalFilename: j['original_filename'] as String? ?? '',
    imageUrl: j['image_url'] as String?,
  );
}

// ------------------------------------------------------------------------ 배치

enum BatchStatus {
  pending('대기'),
  processing('진행중'),
  done('완료'),
  failed('에러');

  const BatchStatus(this.label);
  final String label;

  static BatchStatus parse(String raw) =>
      values.firstWhere((e) => e.name == raw, orElse: () => BatchStatus.pending);
}

class Batch {
  const Batch({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.patientId,
    this.patient,
    this.createdBy,
    this.imageCount = 0,
    this.needsReviewCount = 0,
    this.jobs = const [],
  });

  final String id;
  final BatchStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? patientId;
  final PatientSummary? patient;

  /// 만든 사람의 staff id. 공유·삭제는 소유자만 가능해서 권한 판정에 쓴다.
  /// 목록에는 공유받은 배치도 섞여 온다.
  final String? createdBy;

  final int imageCount;
  final int needsReviewCount;

  /// 상세 응답에만 온다. 목록에서는 빈 리스트
  final List<Job> jobs;

  /// 확정되지 않은 유보 판정이 하나라도 있으면 공유하지 않는다.
  /// ⚠️ 목록 응답에는 `jobs` 가 없어 항상 false다 — 상세에서만 유효하다.
  bool get hasPendingReview => jobs.any((j) => j.needsReview);

  /// 배치 식별자. 서버가 UUID만 주므로 앞 8자리
  String get shortId => id.length >= 8 ? id.substring(0, 8) : id;

  String get patientLabel => patient?.name ?? '환자 미지정';

  factory Batch.fromJson(Map<String, dynamic> json) {
    final ps = json['patient_summary'] as Map<String, dynamic>?;
    final jl = json['jobs'] as List?;
    return Batch(
      id: json['id'] as String,
      status: BatchStatus.parse(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      patientId: json['patient'] as String?,
      patient: ps == null ? null : PatientSummary.fromJson(ps),
      createdBy: json['created_by'] as String?,
      imageCount: (json['image_count'] as num?)?.toInt() ?? 0,
      needsReviewCount: (json['needs_review_count'] as num?)?.toInt() ?? 0,
      jobs: jl == null
          ? const []
          : jl.map((e) => Job.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
