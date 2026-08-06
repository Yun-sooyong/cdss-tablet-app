import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/models/models.dart';
import 'package:tablet/providers/batch_provider.dart';
import 'package:tablet/router/routes.dart';
import 'package:tablet/widgets/overlay_viewer.dart';
import 'package:tablet/widgets/review_dialog.dart';
import 'package:tablet/widgets/section.dart';
import 'package:tablet/widgets/share_dialogs.dart';

/// 분석 진행 중 다시 받아오는 간격. 푸시가 없어 폴링뿐이다.
const _kPollInterval = Duration(seconds: 3);

/// 대시보드 우측 패널 — 배치 상세.
class BatchDetailPane extends HookConsumerWidget {
  const BatchDetailPane({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchId));
    final selectedJob = useState(0);

    // 아직 끝나지 않은 job이 있으면 폴링한다.
    // ⚠️ stil_done은 종료가 아니다 — 리포트가 남은 중간 상태다.
    final jobs = detail.value?.jobs ?? const <Job>[];
    final pending =
        jobs.isEmpty || jobs.any((j) => !j.status.isTerminal);

    useEffect(() {
      if (!pending) return null;
      final t = Timer.periodic(_kPollInterval, (_) {
        ref.invalidate(batchDetailProvider(batchId));
        ref.invalidate(batchesProvider);
      });
      return t.cancel; // 화면을 벗어나면 반드시 정리한다
    }, [batchId, pending]);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.gapXl),
      child: detail.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text('상세를 불러오지 못했습니다\n$e'),
        data: (batch) {
          final i = selectedJob.value.clamp(0, batch.jobs.length - 1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(batch: batch, polling: pending),
              const SizedBox(height: AppDimens.gapXl),
              if (batch.jobs.isEmpty)
                const Text('분석 작업이 아직 없습니다')
              else ...[
                // 이미지가 여러 장이면 탭으로 고른다
                if (batch.jobs.length > 1) ...[
                  Wrap(
                    spacing: AppDimens.gapSm,
                    children: [
                      for (var k = 0; k < batch.jobs.length; k++)
                        ChoiceChip(
                          label: Text(
                            batch.jobs[k].image?.originalFilename ??
                                '이미지 ${k + 1}',
                          ),
                          selected: k == i,
                          onSelected: (_) => selectedJob.value = k,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.gapLg),
                ],
                _JobView(batchId: batchId, job: batch.jobs[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.batch, this.polling = false});
  final Batch batch;
  final bool polling;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 공유·삭제는 소유자만 가능하다 (공유받은 배치는 목록에도 섞여 온다)
    final me = ref.watch(staffMeProvider).value;
    final isOwner = me != null && me.id == batch.createdBy;
    // 판정이 유보된 채로는 공유하지 않는다 — 확정되지 않은 결과다
    final pending = batch.hasPendingReview;
    final canShare = isOwner && !pending;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '배치 ${batch.shortId} · ${batch.patientLabel}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (polling) ...[
                const SizedBox(width: AppDimens.gapMd),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
        Tooltip(
          message: !isOwner
              ? '소유자만 공유할 수 있습니다'
              : pending
              ? '판정이 유보된 분석은 확정 후에 공유할 수 있습니다'
              : '다른 의료진에게 공유',
          child: OutlinedButton(
            onPressed: canShare
                ? () => showShareDialog(context, ref, batch.id)
                : null,
            child: const Text('공유'),
          ),
        ),
        const SizedBox(width: AppDimens.gapSm),
        Tooltip(
          message: isOwner ? '목록에서 삭제' : '소유자만 삭제할 수 있습니다',
          child: OutlinedButton(
            onPressed: isOwner ? () => _delete(context, ref) : null,
            child: const Text('삭제'),
          ),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    if (!await confirmDeleteBatch(context, batch.shortId)) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(analysisRepositoryProvider).deleteBatch(batch.id);
      ref.invalidate(batchesProvider);
      messenger.showSnackBar(const SnackBar(content: Text('삭제했습니다')));
      // 방금 지운 배치를 계속 열어둘 수 없다
      router.go(Routes.dashboard);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }
}

class _JobView extends StatelessWidget {
  const _JobView({required this.batchId, required this.job});

  final String batchId;
  final Job job;

  @override
  Widget build(BuildContext context) {
    final r = job.result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          job.image?.originalFilename ?? '(파일명 없음)',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimens.gapMd),

        Section(
          title: '이미지',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _RemoteImage(
                  url: job.originalUrl,
                  label: '원본 이미지',
                  sub: job.image?.originalFilename,
                ),
              ),
              const SizedBox(width: AppDimens.gapLg),
              Expanded(
                child: _RemoteImage(
                  url: job.maskUrl,
                  label: '세그멘테이션 오버레이',
                  dashed: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.gapXxl),

        _SummaryCard(job: job, result: r),
        if (job.needsReview) ...[
          const SizedBox(height: AppDimens.gapLg),
          _AbstainBanner(batchId: batchId, job: job),
        ],
        const SizedBox(height: AppDimens.gapXxl),

        Row(
          children: [
            FilledButton(
              onPressed: r?.report == null
                  ? null
                  : () => context.push(Routes.batchReport(batchId)),
              child: const Text('상세 리포트 열기'),
            ),
            const SizedBox(width: AppDimens.gapMd),
            _SharesButton(batchId: batchId),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.job, required this.result});

  final Job job;
  final JobResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final r = result;

    return Section(
      title: 'sTIL · Conformal 요약',
      trailing: StatusTag(job.status.label, tone: _toneOf(job.status)),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          if (r == null)
            Text('결과 대기 중', style: TextStyle(color: cs.onSurfaceVariant))
          else ...[
            Text(
              'sTIL  ${r.stilValue?.toStringAsFixed(2) ?? '-'} %',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppDimens.gapSm),
            Text(
              'Conformal 구간  '
              '${r.lower?.toStringAsFixed(2) ?? '-'} ~ '
              '${r.upper?.toStringAsFixed(2) ?? '-'} %',
            ),
            Text('판정  ${r.decision ?? '-'}${r.isAbstain ? '  (판단 보류)' : ''}'),
            // 확정 기록은 원본 추론값을 덮지 않고 따로 남는다
            if (job.review != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '확정  ${job.review!.decision}'
                  '${job.review!.reason.isEmpty ? '' : ' — ${job.review!.reason}'}',
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (r.sigma != null) Text('σ  ${r.sigma!.toStringAsFixed(3)}'),
            if (r.classComposition.isNotEmpty) ...[
              const SizedBox(height: AppDimens.gapMd),
              const Text('조직 구성'),
              const SizedBox(height: AppDimens.gapSm),
              for (final e in r.classComposition.entries)
                _CompositionBar(
                  label: _ko(e.key),
                  percent: e.value,
                  color: _tissueColor(context, e.key),
                ),
            ],
          ],
          if (job.errorMessage.isNotEmpty) ...[
            const SizedBox(height: AppDimens.gapMd),
            Text(job.errorMessage, style: TextStyle(color: cs.error)),
          ],
          ],
        ),
      ),
    );
  }

  static StatusTone _toneOf(JobStatus s) => switch (s) {
    JobStatus.succeeded => StatusTone.positive,
    JobStatus.running || JobStatus.stilDone => StatusTone.warning,
    JobStatus.failed => StatusTone.danger,
    JobStatus.queued => StatusTone.neutral,
  };
}

/// 판정 유보 안내 + 확정 버튼. 확정은 **의사만** 할 수 있다.
class _AbstainBanner extends ConsumerWidget {
  const _AbstainBanner({required this.batchId, required this.job});

  final String batchId;
  final Job job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final me = ref.watch(staffMeProvider).value;
    final canReview = me?.canReview ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.warning),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.help_outline, color: AppColors.warning),
          const SizedBox(width: AppDimens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('판정 유보', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  canReview
                      ? '모델이 판정을 유보했습니다. 확정 전까지 이 분석은 공유할 수 없습니다.'
                      : '모델이 판정을 유보했습니다. 확정은 의사만 할 수 있습니다.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.gapMd),
          FilledButton(
            onPressed: canReview
                ? () => showReviewDialog(
                    context,
                    ref,
                    batchId: batchId,
                    jobId: job.id,
                  )
                : null,
            child: const Text('판정 확정'),
          ),
        ],
      ),
    );
  }
}

/// 조직 구성 막대 색. 브랜드 팔레트의 명도 램프를 쓴다 —
/// 임의 색을 만들지 않고, 임상적으로 중요한 종양을 가장 진하게 둔다.
///
/// ⚠️ 다크 모드에서는 램프를 뒤집는다. `g900`(#01403A)은 어두운 배경에서 안 보인다.
Color _tissueColor(BuildContext context, String key) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final ramp = dark
      ? const [
          AppColors.n100,
          AppColors.n300,
          AppColors.n400,
          AppColors.g500,
          AppColors.g700,
        ]
      : const [
          AppColors.g900,
          AppColors.g700,
          AppColors.g500,
          AppColors.n400,
          AppColors.n300,
        ];
  final i = switch (key) {
    'tumor' => 0,
    'stroma' => 1,
    'immune' => 2,
    'necrosis' => 3,
    'other' => 4,
    _ => 4,
  };
  return ramp[i];
}

class _CompositionBar extends StatelessWidget {
  const _CompositionBar({
    required this.label,
    required this.percent,
    required this.color,
  });

  final String label;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          // 색 범례를 겸하는 점
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: AppDimens.gapSm),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 64, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 8,
                color: color,
                backgroundColor: Theme.of(context).dividerColor,
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '${percent.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// 공유 현황. 소유자만 조회할 수 있어서 개수 배지도 소유자에게만 뜬다.
class _SharesButton extends ConsumerWidget {
  const _SharesButton({required this.batchId});
  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚠️ 공유 현황은 소유자만 볼 수 있다. 공유받은 배치에 요청하면
    // 404 "본인이 만든 배치만 공유할 수 있습니다" 가 온다.
    // 소유자가 아니면 조회 자체를 하지 않는다 — 배지용 요청도 마찬가지다.
    final me = ref.watch(staffMeProvider).value;
    final owner = ref.watch(batchDetailProvider(batchId)).value?.createdBy;
    final isOwner = me != null && owner != null && me.id == owner;

    if (!isOwner) {
      return const Tooltip(
        message: '공유 현황은 소유자만 볼 수 있습니다',
        child: OutlinedButton(onPressed: null, child: Text('공유 현황')),
      );
    }

    final live = ref
        .watch(sharesProvider(batchId))
        .value
        ?.where((s) => s.isLive)
        .length;

    return OutlinedButton(
      onPressed: () => showSharesDialog(context, ref, batchId),
      child: Text(live == null || live == 0 ? '공유 현황' : '공유 현황 ($live)'),
    );
  }
}

/// GCS 서명 URL 이미지. 없거나 실패하면 자리표시자를 보여준다.
class _RemoteImage extends StatelessWidget {
  const _RemoteImage({
    required this.url,
    required this.label,
    this.sub,
    this.dashed = false,
  });

  final String? url;
  final String label;
  final String? sub;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    // URL이 없으면 자리표시자다. 탭해도 열 게 없으니 눌리지 않게 둔다.
    if (url == null) {
      return _ImageSlot(label: label, sub: sub, dashed: dashed);
    }
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Tooltip(
        message: '탭하면 크게 봅니다',
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radius),
          onTap: () => showImageDialog(context, url: url!, title: label),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimens.radius),
            child: Image.network(
              url!,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              // 서명 URL은 15분이면 만료된다. 객체 자체가 없는 경우도 있다.
              errorBuilder: (context, error, stack) => _ImageSlot(
                label: label,
                sub: sub,
                note: '불러오지 못했습니다',
                dashed: dashed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  const _ImageSlot({
    required this.label,
    this.sub,
    this.note,
    this.dashed = false,
  });

  final String label;
  final String? sub;
  final String? note;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(AppDimens.radius),
          color: dashed ? cs.surfaceContainer : null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: theme.disabledColor)),
              if (sub != null) ...[
                const SizedBox(height: 4),
                // 파일명이 50자를 넘어 좁은 상자를 넘칠 수 있다
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.gapMd,
                  ),
                  child: Text(
                    sub!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
              if (note != null) ...[
                const SizedBox(height: 4),
                Text(
                  note!,
                  style: TextStyle(color: theme.disabledColor, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _ko(String key) => switch (key) {
  'tumor' => '종양',
  'stroma' => '기질',
  'immune' => '면역',
  'necrosis' => '괴사',
  'other' => '기타',
  _ => key,
};
