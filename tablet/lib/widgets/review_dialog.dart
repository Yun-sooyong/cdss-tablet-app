import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/models/models.dart';
import 'package:tablet/providers/batch_provider.dart';

/// 판정 유보(ABSTAIN)를 LOW/HIGH로 확정한다.
///
/// 서버는 원본 추론값을 그대로 두고 확정 기록만 따로 쌓는다.
/// **role=doctor 만 호출할 수 있다.**
Future<void> showReviewDialog(
  BuildContext context,
  WidgetRef ref, {
  required String batchId,
  required String jobId,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  final picked = await showDialog<(JobDecision, String)>(
    context: context,
    builder: (context) => const _ReviewDialog(),
  );
  if (picked == null) return;

  try {
    await ref
        .read(analysisRepositoryProvider)
        .reviewJob(jobId, decision: picked.$1, reason: picked.$2);
    ref.invalidate(batchDetailProvider(batchId));
    ref.invalidate(batchesProvider);
    messenger.showSnackBar(
      SnackBar(content: Text('${picked.$1.label} 으로 확정했습니다')),
    );
  } on DioException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (e.response?.statusCode) {
          403 => '판정 확정은 의사만 할 수 있습니다.',
          400 => '입력값을 확인해 주세요.',
          _ => '확정에 실패했습니다: ${e.message}',
        }),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('확정에 실패했습니다: $e')));
  }
}

class _ReviewDialog extends HookWidget {
  const _ReviewDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decision = useState<JobDecision?>(null);
    final reasonCtrl = useTextEditingController();
    // 사유는 서버 필수값이다. 비어 있으면 버튼을 막는다.
    final reason = useValueListenable(reasonCtrl).text.trim();
    final ready = decision.value != null && reason.isNotEmpty;

    return AlertDialog(
      title: const Text('판정 확정'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '모델이 판정을 유보(ABSTAIN)한 건입니다.\n'
              '확정해도 원본 추론값은 그대로 남고, 확정 기록이 따로 저장됩니다.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppDimens.gapXl),
            const Text('판정'),
            const SizedBox(height: AppDimens.gapSm),
            SegmentedButton<JobDecision>(
              segments: [
                for (final d in JobDecision.values)
                  ButtonSegment(value: d, label: Text(d.label)),
              ],
              selected: decision.value == null ? const {} : {decision.value!},
              emptySelectionAllowed: true,
              onSelectionChanged: (s) =>
                  decision.value = s.isEmpty ? null : s.first,
            ),
            const SizedBox(height: AppDimens.gapLg),
            const Text('확정 사유 *'),
            const SizedBox(height: AppDimens.gapSm),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '판독 근거를 남깁니다',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: ready
              ? () => Navigator.of(context).pop((decision.value!, reason))
              : null,
          child: const Text('확정'),
        ),
      ],
    );
  }
}
