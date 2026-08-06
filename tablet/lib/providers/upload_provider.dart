import 'dart:typed_data';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tablet/models/models.dart';
import 'package:tablet/providers/batch_provider.dart';

/// 업로드할 파일 하나. 로컬 경로 대신 바이트를 들고 있는다 —
/// file_picker의 `withData: true` 와 에셋 샘플을 같은 방식으로 다루기 위해서.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;

  int get sizeKb => (bytes.length / 1024).ceil();
}

class UploadState {
  const UploadState({
    this.patient,
    this.files = const [],
    this.modelVersionId,
    this.busy = false,
    this.log = const [],
    this.error,
  });

  final PatientSummary? patient;
  final List<PickedFile> files;
  final String? modelVersionId;
  final bool busy;
  final List<String> log;
  final String? error;

  bool get canStart => patient != null && files.isNotEmpty && !busy;

  UploadState copyWith({
    PatientSummary? patient,
    List<PickedFile>? files,
    String? modelVersionId,
    bool? busy,
    List<String>? log,
    String? error,
    bool clearError = false,
  }) => UploadState(
    patient: patient ?? this.patient,
    files: files ?? this.files,
    modelVersionId: modelVersionId ?? this.modelVersionId,
    busy: busy ?? this.busy,
    log: log ?? this.log,
    error: clearError ? null : (error ?? this.error),
  );
}

class UploadController extends Notifier<UploadState> {
  @override
  UploadState build() => const UploadState();

  void selectPatient(PatientSummary p) =>
      state = state.copyWith(patient: p, clearError: true);

  void addFiles(List<PickedFile> f) =>
      state = state.copyWith(files: [...state.files, ...f], clearError: true);

  void removeFile(int i) => state = state.copyWith(
    files: [...state.files]..removeAt(i),
  );

  void selectModel(String id) => state = state.copyWith(modelVersionId: id);

  void reset() => state = const UploadState();

  void _say(String line) =>
      state = state.copyWith(log: [...state.log, line]);

  /// 배치 생성 → 이미지 등록 + PUT → start.
  /// 성공하면 batchId를 돌려준다. 실패하면 null.
  Future<String?> start() async {
    final patient = state.patient;
    if (patient == null || state.files.isEmpty) return null;

    state = state.copyWith(busy: true, log: const [], clearError: true);
    final repo = ref.read(analysisRepositoryProvider);

    try {
      _say('배치 생성 중…');
      final batch = await repo.createBatch(patient.id);
      _say('배치 ${batch.shortId} 생성됨');

      var i = 0;
      var failed = 0;
      for (final f in state.files) {
        i++;
        _say('[$i/${state.files.length}] ${f.name} 등록 중…');
        final up = await repo.registerImage(batch.id, f.name);
        try {
          await repo.putBytes(up.uploadUrl, f.bytes, f.name);
          _say('[$i/${state.files.length}] ${f.name} 업로드 완료 (${f.sizeKb}KB)');
        } catch (e) {
          // 업로드가 실패해도 분석은 시작한다. 다만 파일이 없으면 분석도 실패하므로
          // 그냥 넘기지 말고 이유를 드러낸다.
          failed++;
          _say('[$i/${state.files.length}] ⚠️ ${f.name} 업로드 실패 — 이 이미지는 '
              '분석도 실패합니다\n    $e');
        }
      }

      if (failed > 0) {
        _say('⚠️ ${state.files.length}개 중 $failed개가 업로드되지 않았습니다');
      }

      _say('분석 시작 중…');
      try {
        await repo.startBatch(batch.id, modelVersionId: state.modelVersionId);
        _say('시작됨');
      } catch (e) {
        // ⚠️ 서버가 500을 주더라도 job은 이미 만들어진다(작업 큐 등록에서만 실패).
        // 실패로 처리해 화면에 묶어두면 오히려 상태를 못 본다.
        _say('⚠️ 시작 응답이 실패했지만 작업은 생성됐을 수 있습니다: $e');
      }

      ref.invalidate(batchesProvider);
      state = state.copyWith(busy: false);
      return batch.id;
    } catch (e) {
      state = state.copyWith(busy: false, error: '$e');
      _say('실패: $e');
      return null;
    }
  }
}

final uploadProvider = NotifierProvider<UploadController, UploadState>(
  UploadController.new,
);

/// 환자 검색 조건. `family` 키로 쓰므로 값 동등성이 필요하다.
class PatientQuery {
  const PatientQuery.chart(this.chartNumber)
    : name = null,
      birthDate = null;
  const PatientQuery.nameAndBirth(this.name, this.birthDate)
    : chartNumber = null;

  final String? chartNumber;
  final String? name;
  final DateTime? birthDate;

  /// 서버를 부를 만한 조건이 갖춰졌는가.
  /// 이름은 생년월일과 짝이어야 한다 (아니면 서버가 400).
  bool get isReady =>
      (chartNumber != null && chartNumber!.trim().isNotEmpty) ||
      (name != null && name!.trim().isNotEmpty && birthDate != null);

  @override
  bool operator ==(Object other) =>
      other is PatientQuery &&
      other.chartNumber == chartNumber &&
      other.name == name &&
      other.birthDate == birthDate;

  @override
  int get hashCode => Object.hash(chartNumber, name, birthDate);
}

/// 환자 검색 결과. 조건이 덜 갖춰지면 서버를 부르지 않는다.
final patientSearchProvider =
    FutureProvider.family<List<PatientSummary>, PatientQuery>((ref, q) async {
      if (!q.isReady) return const [];
      return ref
          .read(patientRepositoryProvider)
          .search(
            chartNumber: q.chartNumber?.trim(),
            name: q.name?.trim(),
            birthDate: q.birthDate,
          );
    });
