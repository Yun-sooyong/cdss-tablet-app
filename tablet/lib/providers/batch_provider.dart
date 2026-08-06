import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tablet/api/api.dart';
import 'package:tablet/data/analysis_repository.dart';
import 'package:tablet/data/patient_repository.dart';
import 'package:tablet/models/models.dart';

/// 목록 필터. `공유` 만 상태가 아니라 소유권 축이라 [status] 가 null이다
/// (`전체` 와 구분해야 해서 [isSharedOnly] 로 판별한다).
enum BatchFilter {
  all('전체', null),
  processing('진행중', BatchStatus.processing),
  done('완료', BatchStatus.done),
  failed('에러', BatchStatus.failed),
  shared('공유', null);

  const BatchFilter(this.label, this.status);
  final String label;
  final BatchStatus? status;

  bool get isSharedOnly => this == BatchFilter.shared;
}

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  return HttpAnalysisRepository(ref.watch(dioProvider));
});

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return HttpPatientRepository(ref.watch(dioProvider));
});

final batchesProvider = FutureProvider<List<Batch>>((ref) {
  ref.keepAlive();
  return ref.watch(analysisRepositoryProvider).fetchBatches();
});

final modelVersionsProvider = FutureProvider<List<ModelVersion>>((ref) {
  ref.keepAlive();
  return ref.watch(analysisRepositoryProvider).fetchModelVersions();
});

/// 검색어와 필터는 항상 같이 목록을 거르므로 한 상태로 묶는다.
class BatchQuery {
  const BatchQuery({this.keyword = '', this.filter = BatchFilter.all});

  final String keyword;
  final BatchFilter filter;

  BatchQuery copyWith({String? keyword, BatchFilter? filter}) => BatchQuery(
    keyword: keyword ?? this.keyword,
    filter: filter ?? this.filter,
  );
}

class BatchQueryNotifier extends Notifier<BatchQuery> {
  @override
  BatchQuery build() => const BatchQuery();

  void setKeyword(String v) => state = state.copyWith(keyword: v);
  void setFilter(BatchFilter v) => state = state.copyWith(filter: v);
}

final batchQueryProvider = NotifierProvider<BatchQueryNotifier, BatchQuery>(
  BatchQueryNotifier.new,
);

/// 이 배치가 공유받은 것인지. `created_by` 가 나와 다르면 남의 배치다.
/// 내 staff 정보를 아직 못 받았으면 판정하지 않는다(null).
bool? isSharedWithMe(Batch b, Staff? me) {
  if (me == null || b.createdBy == null) return null;
  return b.createdBy != me.id;
}

/// ⚠️ GET /analysis/batches/ 에는 검색·필터 파라미터가 없다. 클라이언트에서 거른다.
final filteredBatchesProvider = Provider<AsyncValue<List<Batch>>>((ref) {
  final all = ref.watch(batchesProvider);
  final query = ref.watch(batchQueryProvider);
  final me = ref.watch(staffMeProvider).value;
  final q = query.keyword.trim();

  return all.whenData(
    (list) => list.where((b) {
      if (query.filter.isSharedOnly) {
        // 내 staff 정보를 못 받았으면(null) 판정할 수 없으므로 제외한다
        if (isSharedWithMe(b, me) != true) return false;
      } else if (query.filter.status != null &&
          b.status != query.filter.status) {
        return false;
      }
      if (q.isEmpty) return true;
      final p = b.patient;
      return (p?.name.contains(q) ?? false) ||
          (p?.chartNumber.contains(q) ?? false) ||
          b.shortId.contains(q);
    }).toList(),
  );
});

/// 내 staff 정보. 배치 소유자인지 판정해 공유·삭제 버튼을 켠다.
final staffMeProvider = FutureProvider<Staff>((ref) {
  ref.keepAlive();
  return ref.watch(analysisRepositoryProvider).fetchMe();
});

/// 공유 대상 후보. 재직 중인 직원만, 나는 뺀다.
final staffListProvider = FutureProvider<List<Staff>>((ref) async {
  final all = await ref.watch(analysisRepositoryProvider).fetchStaff();
  final me = ref.watch(staffMeProvider).value;
  return all.where((s) => s.isActive && s.id != me?.id).toList();
});

/// 배치별 공유 현황
final sharesProvider = FutureProvider.family<List<AnalysisShare>, String>(
  (ref, batchId) =>
      ref.watch(analysisRepositoryProvider).fetchShares(batchId),
);

/// 배치 상세 (jobs 포함).
/// mask_url·original_url이 15분 만료라 keepAlive 하지 않는다 —
/// 화면을 다시 들어오면 새 URL로 다시 받는다.
final batchDetailProvider = FutureProvider.family<Batch, String>((ref, id) {
  return ref.watch(analysisRepositoryProvider).fetchBatch(id);
});
