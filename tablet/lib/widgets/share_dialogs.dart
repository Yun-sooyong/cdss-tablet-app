import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/models/models.dart';
import 'package:tablet/providers/batch_provider.dart';

/// 공유 대상을 고르고 소견을 적는다. 소유자만 호출된다.
/// 분석 결과와 소견이 함께 상대에게 전달된다.
Future<void> showShareDialog(
  BuildContext context,
  WidgetRef ref,
  String batchId,
) async {
  final messenger = ScaffoldMessenger.of(context);

  final picked = await showDialog<(String, String)>(
    context: context,
    builder: (context) => _ShareDialog(batchId: batchId),
  );
  if (picked == null) return;

  try {
    await ref
        .read(analysisRepositoryProvider)
        .createShare(batchId, staffId: picked.$1, opinion: picked.$2);
    ref.invalidate(sharesProvider(batchId));
    messenger.showSnackBar(const SnackBar(content: Text('공유했습니다')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('공유 실패: $e')));
  }
}

class _ShareDialog extends HookConsumerWidget {
  const _ShareDialog({required this.batchId});
  final String batchId;

  /// 서버 `AnalysisShareCreate.opinion` 의 maxLength
  static const _opinionMaxLength = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(staffListProvider);
    final selected = useState<String?>(null);
    final opinionCtrl = useTextEditingController();

    return AlertDialog(
      title: const Text('분석 공유'),
      content: SizedBox(
        width: 420,
        child: staff.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppDimens.gapXl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('직원 목록을 불러오지 못했습니다\n$e'),
          data: (list) {
            if (list.isEmpty) {
              return const Text('공유할 수 있는 직원이 없습니다');
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('공유 대상'),
                const SizedBox(height: AppDimens.gapSm),
                DropdownButtonFormField<String>(
                  initialValue: selected.value,
                  hint: const Text('직원 선택'),
                  items: [
                    for (final s in list)
                      DropdownMenuItem(value: s.id, child: Text(s.label)),
                  ],
                  onChanged: (v) => selected.value = v,
                ),
                const SizedBox(height: AppDimens.gapLg),
                const Text('소견'),
                const SizedBox(height: AppDimens.gapSm),
                TextField(
                  controller: opinionCtrl,
                  maxLines: 4,
                  maxLength: _opinionMaxLength,
                  decoration: const InputDecoration(
                    hintText: '분석 결과와 함께 전달할 소견을 적습니다 (선택)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: selected.value == null
              ? null
              : () => Navigator.of(
                  context,
                ).pop((selected.value!, opinionCtrl.text.trim())),
          child: const Text('공유'),
        ),
      ],
    );
  }
}

/// 공유 현황 + 회수.
Future<void> showSharesDialog(
  BuildContext context,
  WidgetRef ref,
  String batchId,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SharesDialog(batchId: batchId),
  );
}

class _SharesDialog extends ConsumerWidget {
  const _SharesDialog({required this.batchId});
  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shares = ref.watch(sharesProvider(batchId));
    final staff = ref.watch(staffListProvider).value ?? const <Staff>[];
    final theme = Theme.of(context);

    String nameOf(String id) {
      for (final s in staff) {
        if (s.id == id) return s.label;
      }
      return id.length >= 8 ? id.substring(0, 8) : id;
    }

    return AlertDialog(
      title: const Text('공유 현황'),
      content: SizedBox(
        width: 460,
        child: shares.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppDimens.gapXl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppDimens.gapLg),
            child: Text(
              _shareErrorMessage(e),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppDimens.gapLg),
                child: Text(
                  '아직 공유하지 않았습니다',
                  style: TextStyle(color: theme.disabledColor),
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      nameOf(s.sharedTo),
                      style: s.isLive
                          ? null
                          : TextStyle(
                              color: theme.disabledColor,
                              decoration: TextDecoration.lineThrough,
                            ),
                    ),
                    subtitle: Text(
                      [
                        if (s.opinion.isNotEmpty) s.opinion,
                        if (!s.isLive) s.revokedAt != null ? '회수됨' : '만료됨',
                      ].join(' · '),
                    ),
                    isThreeLine: s.opinion.length > 40,
                    trailing: s.isLive
                        ? TextButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await ref
                                    .read(analysisRepositoryProvider)
                                    .revokeShare(s.id);
                                ref.invalidate(sharesProvider(batchId));
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('회수 실패: $e')),
                                );
                              }
                            },
                            child: const Text('회수'),
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

/// 서버 오류를 그대로 노출하지 않는다. DioException을 통째로 찍으면
/// 사용자가 읽을 수 없는 스택이 다이얼로그에 박힌다.
String _shareErrorMessage(Object e) {
  if (e is DioException) {
    // 공유받은 배치에 조회하면 404가 온다 ("본인이 만든 배치만 공유할 수 있습니다")
    final code = e.response?.statusCode;
    if (code == 404 || code == 403) return '공유 현황은 소유자만 볼 수 있습니다.';
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    return '공유 현황을 불러오지 못했습니다.';
  }
  return '공유 현황을 불러오지 못했습니다.';
}

/// 삭제 확인. 되돌릴 수 없는 동작이므로 반드시 한 번 묻는다.
Future<bool> confirmDeleteBatch(BuildContext context, String shortId) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('분석 삭제'),
      content: Text(
        '배치 $shortId 을(를) 목록에서 삭제합니다.\n'
        '서버에서 완전히 지워지지는 않지만 앱에서는 더 이상 보이지 않습니다.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
