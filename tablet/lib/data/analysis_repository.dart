import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:tablet/api/api.dart';
import 'package:tablet/models/models.dart';

/// 화면이 API를 직접 부르지 않게 사이에 두는 한 겹.
abstract interface class AnalysisRepository {
  Future<List<Batch>> fetchBatches();
  Future<Batch> fetchBatch(String id);
  Future<List<ModelVersion>> fetchModelVersions();

  /// POST /batches/ — patient_id 가 필수다
  Future<Batch> createBatch(String patientId);

  /// POST /batches/{id}/images/ — 서명된 업로드 URL을 받아온다
  Future<ImageUpload> registerImage(String batchId, String filename);

  /// 서명 URL로 GCS에 직접 PUT.
  /// [filename] 은 Content-Type 계산에 쓴다 — 서명과 반드시 일치해야 한다.
  Future<void> putBytes(String uploadUrl, Uint8List bytes, String filename);

  /// POST /batches/{id}/start/ — job이 없는 이미지들을 한 번에 큐에 넣는다
  Future<void> startBatch(String batchId, {String? modelVersionId});

  /// DELETE /batches/{id}/ — soft delete(목록에서 감춤). **소유자만** 가능하다
  Future<void> deleteBatch(String batchId);

  /// POST /jobs/{id}/review/ — 판정 유보(ABSTAIN)를 LOW/HIGH로 확정한다.
  ///
  /// **role=doctor 만 가능하다** (admin·nurse는 403).
  /// 서버는 `Job.result`/`status` 를 건드리지 않고 리뷰를 append-only 로 쌓는다.
  Future<JobReview> reviewJob(
    String jobId, {
    required JobDecision decision,
    required String reason,
  });

  // --- 공유. 소유자만 만들거나 현황을 볼 수 있다 ---
  Future<List<AnalysisShare>> fetchShares(String batchId);
  Future<AnalysisShare> createShare(
    String batchId, {
    required String staffId,
    String opinion = '',
    DateTime? expiresAt,
  });

  /// DELETE /shares/{id}/ — 회수. 물리 삭제가 아니라 revoked_at 기록이다
  Future<void> revokeShare(String shareId);

  /// GET /staff/ — 공유 대상 선택용.
  /// 직원 API지만 지금은 분석 화면에서만 쓰여서 여기 둔다.
  Future<List<Staff>> fetchStaff();

  /// GET /staff/me/ — 내 staff id. 배치 소유자 판정에 쓴다
  Future<Staff> fetchMe();

  /// POST /devices/tokens/ — FCM 토큰 등록. 로그인 뒤에 부른다
  Future<void> registerDeviceToken(String fcmToken, String platform);

  /// GET /notifications/ — 본인 알림만 내려온다
  Future<List<AppNotification>> fetchNotifications();

  /// PATCH /notifications/{id}/ — 개별 읽음 처리
  Future<void> markNotificationRead(String id);

  /// POST /notifications/read-all/ — 안 읽은 알림 전체 읽음 처리
  Future<void> markAllNotificationsRead();
}

class HttpAnalysisRepository implements AnalysisRepository {
  HttpAnalysisRepository(this._dio);
  final Dio _dio;

  /// 한 번에 받아올 페이지 크기와, 폭주를 막는 상한.
  static const _pageSize = 100;
  static const _maxPages = 20;

  /// 목록 응답에서 항목 배열을 꺼낸다.
  ///
  /// ⚠️ 서버가 엔드포인트를 하나씩 페이지네이션으로 옮기고 있다.
  /// `/analysis/batches/` 는 `{count, limit, offset, results}` 로 바뀌었고
  /// 나머지(`model-versions`·`notifications`·`staff`·`shares`)는 아직 배열이다.
  /// 어느 쪽이 와도 받아들인다.
  static List<dynamic> itemsOf(Object? data) {
    if (data is List) return data;
    if (data is Map && data['results'] is List) return data['results'] as List;
    throw FormatException('목록 응답 형식을 알 수 없습니다: ${data.runtimeType}');
  }

  /// 전체 개수. 페이지네이션이 아니면 null.
  static int? totalOf(Object? data) =>
      data is Map && data['count'] is int ? data['count'] as int : null;

  @override
  Future<List<Batch>> fetchBatches() async {
    // 본인 batch + 공유받은 batch. 페이지네이션이 붙어 있어 다 받아온다 —
    // 첫 페이지만 쓰면 배치가 50건을 넘는 순간 조용히 잘린다.
    final all = <Batch>[];
    for (var page = 0; page < _maxPages; page++) {
      final res = await _dio.get(
        Endpoints.batches,
        queryParameters: {'limit': _pageSize, 'offset': page * _pageSize},
      );
      final items = itemsOf(res.data);
      all.addAll(
        items.map((e) => Batch.fromJson(e as Map<String, dynamic>)),
      );

      final total = totalOf(res.data);
      // 배열로 오면(페이지네이션 없음) 한 번에 끝이다
      if (total == null || all.length >= total || items.isEmpty) break;
    }
    return all;
  }

  @override
  Future<Batch> fetchBatch(String id) async {
    final res = await _dio.get(Endpoints.batch(id));
    return Batch.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<List<ModelVersion>> fetchModelVersions() async {
    final res = await _dio.get(Endpoints.modelVersions);
    return itemsOf(res.data)
        .map((e) => ModelVersion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Batch> createBatch(String patientId) async {
    final res = await _dio.post(
      Endpoints.batches,
      data: {'patient_id': patientId},
    );
    return Batch.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<ImageUpload> registerImage(String batchId, String filename) async {
    final res = await _dio.post(
      Endpoints.batchImages(batchId),
      data: {'original_filename': filename},
    );
    return ImageUpload.fromJson(res.data as Map<String, dynamic>);
  }

  /// 서명 URL은 `X-Goog-SignedHeaders: content-type;host` 로 서명돼 있어서
  /// **Content-Type이 서버가 서명할 때 쓴 값과 정확히 같아야 한다.**
  /// 서버는 파일명 확장자의 표준 MIME을 쓰고, 모르는 확장자면 octet-stream이다
  /// (Python `mimetypes.guess_type`). 실측 결과:
  ///
  ///   a.png -> image/png     a.jpg -> image/jpeg    a.tif -> image/tiff
  ///   a.svs -> application/octet-stream    (확장자 미상도 동일)
  ///
  /// 어긋나면 403 SignatureDoesNotMatch 가 난다.
  static String contentTypeFor(String filename) =>
      lookupMimeType(filename) ?? 'application/octet-stream';

  @override
  Future<void> putBytes(
    String uploadUrl,
    Uint8List bytes,
    String filename,
  ) async {
    // ⚠️ 인증된 _dio 를 쓰면 안 된다. GCS에 Authorization 헤더가 붙으면
    // 서명 검증이 깨진다.
    final bare = Dio(
      BaseOptions(
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    // 서버의 MIME 추론이 바뀌어도 업로드가 죽지 않도록 후보를 순서대로 시도한다.
    // 403은 서명 불일치이므로 다른 값으로 다시 걸어볼 가치가 있다.
    final candidates = <String>{
      contentTypeFor(filename),
      'application/octet-stream',
    }.toList();

    DioException? last;
    for (final ct in candidates) {
      try {
        await bare.put(
          uploadUrl,
          data: Stream.fromIterable([bytes]),
          options: Options(
            headers: {Headers.contentLengthHeader: bytes.length},
            contentType: ct,
          ),
        );
        return;
      } on DioException catch (e) {
        last = e;
        if (e.response?.statusCode != 403) rethrow; // 서명 문제가 아니면 즉시 중단
      }
    }
    throw StateError(
      '업로드 서명 불일치: ${candidates.join(", ")} 모두 403. '
      '서버가 서명에 쓴 Content-Type이 바뀌었을 수 있습니다. '
      '(${last?.message ?? ""})',
    );
  }

  @override
  Future<void> startBatch(String batchId, {String? modelVersionId}) async {
    await _dio.post(
      Endpoints.batchStart(batchId),
      data: modelVersionId == null ? {} : {'model_version_id': modelVersionId},
    );
  }

  @override
  Future<void> deleteBatch(String batchId) async {
    await _dio.delete(Endpoints.batch(batchId));
  }

  @override
  Future<JobReview> reviewJob(
    String jobId, {
    required JobDecision decision,
    required String reason,
  }) async {
    final res = await _dio.post(
      Endpoints.jobReview(jobId),
      data: {'decision': decision.raw, 'reason': reason},
    );
    return JobReview.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<List<AnalysisShare>> fetchShares(String batchId) async {
    final res = await _dio.get(Endpoints.batchShares(batchId));
    return itemsOf(res.data)
        .map((e) => AnalysisShare.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AnalysisShare> createShare(
    String batchId, {
    required String staffId,
    String opinion = '',
    DateTime? expiresAt,
  }) async {
    final res = await _dio.post(
      Endpoints.batchShares(batchId),
      data: {
        'shared_to': staffId,
        'opinion': opinion,
        if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String(),
      },
    );
    return AnalysisShare.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<void> revokeShare(String shareId) async {
    await _dio.delete(Endpoints.share(shareId));
  }

  @override
  Future<List<Staff>> fetchStaff() async {
    final res = await _dio.get(Endpoints.staff);
    return itemsOf(res.data)
        .map((e) => Staff.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Staff> fetchMe() async {
    final res = await _dio.get(Endpoints.staffMe);
    return Staff.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<void> registerDeviceToken(String fcmToken, String platform) async {
    await _dio.post(
      Endpoints.deviceTokens,
      data: {'fcm_token': fcmToken, 'platform': platform},
    );
  }

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    final res = await _dio.get(Endpoints.notifications);
    return itemsOf(res.data)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _dio.patch(Endpoints.notification(id));
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _dio.post(Endpoints.notificationsReadAll);
  }
}
