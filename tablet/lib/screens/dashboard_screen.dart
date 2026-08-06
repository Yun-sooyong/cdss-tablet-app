import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/models/models.dart';
import 'package:tablet/providers/batch_provider.dart';
import 'package:tablet/router/routes.dart';
import 'package:tablet/widgets/batch_detail_pane.dart';
import 'package:tablet/widgets/section.dart';

class DashboardScreen extends HookConsumerWidget {
  const DashboardScreen({super.key, this.selectedBatchId});

  /// URL의 :batchId. 없으면 선택 안 된 상태
  final String? selectedBatchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 페이지 키를 공유하므로 배치를 골라도 이 컨트롤러는 유지된다
    final searchController = useTextEditingController();

    return Column(
      children: [
        _Header(controller: searchController),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    const _FilterBar(),
                    Expanded(
                      child: _BatchList(selectedBatchId: selectedBatchId),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 6,
                child: selectedBatchId == null
                    ? const Center(child: Text('목록에서 분석을 선택하세요'))
                    : BatchDetailPane(batchId: selectedBatchId!),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.gapXl,
        AppDimens.gapXl,
        AppDimens.gapXl,
        AppDimens.gapLg,
      ),
      child: Row(
        children: [
          Text('분석 목록', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: AppDimens.gapXl),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (v) =>
                  ref.read(batchQueryProvider.notifier).setKeyword(v),
              decoration: const InputDecoration(
                hintText: '환자명 · 차트번호 · 배치번호 검색',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.gapLg),
          FilledButton.icon(
            onPressed: () => context.go(Routes.upload),
            icon: const Icon(Icons.add),
            label: const Text('새 분석'),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(batchQueryProvider);
    final notifier = ref.read(batchQueryProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.gapXl,
        AppDimens.gapLg,
        AppDimens.gapXl,
        AppDimens.gapSm,
      ),
      child: Wrap(
        spacing: AppDimens.gapSm,
        runSpacing: AppDimens.gapSm,
        children: [
          for (final f in BatchFilter.values)
            ChoiceChip(
              label: Text(f.label),
              avatar: f.isSharedOnly
                  ? const Icon(Icons.share_outlined, size: 16)
                  : null,
              selected: query.filter == f,
              onSelected: (_) => notifier.setFilter(f),
            ),
        ],
      ),
    );
  }
}

class _BatchList extends ConsumerWidget {
  const _BatchList({required this.selectedBatchId});
  final String? selectedBatchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(filteredBatchesProvider);
    final me = ref.watch(staffMeProvider).value;

    return batches.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('목록을 불러오지 못했습니다\n$e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('조건에 맞는 분석이 없습니다'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.gapXl,
            AppDimens.gapSm,
            AppDimens.gapXl,
            AppDimens.gapXl,
          ),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppDimens.gapMd),
          itemBuilder: (context, i) {
            final b = list[i];
            return _BatchCard(
              batch: b,
              selected: b.id == selectedBatchId,
              isShared: isSharedWithMe(b, me) ?? false,
              // go = 스택을 쌓지 않는다. 선택은 화면 전환이 아니다
              onTap: () => context.go(Routes.batch(b.id)),
            );
          },
        );
      },
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.batch,
    required this.selected,
    required this.isShared,
    required this.onTap,
  });

  final Batch batch;
  final bool selected;

  /// 남이 나에게 공유한 배치. 공유·삭제가 막혀 있으므로 목록에서 구분해준다
  final bool isShared;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = batch.status == BatchStatus.failed;

    return Card(
      color: selected ? cs.primary.withValues(alpha: 0.10) : theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        side: BorderSide(
          color: selected ? cs.primary : theme.dividerColor,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isShared) ...[
                    Tooltip(
                      message: '공유받은 분석',
                      child: Icon(
                        Icons.share_outlined,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      '환자 · ${batch.patientLabel}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  StatusTag(batch.status.label, tone: _toneOf(batch.status)),
                ],
              ),
              const SizedBox(height: AppDimens.gapMd),
              Text(
                [
                  if (batch.patient != null) '차트 ${batch.patient!.chartNumber}',
                  '배치 ${batch.shortId}',
                  '이미지 ${batch.imageCount}장',
                  if (batch.needsReviewCount > 0) '검토 ${batch.needsReviewCount}',
                  if (isShared) '공유받음',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted ? theme.disabledColor : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static StatusTone _toneOf(BatchStatus s) => switch (s) {
    BatchStatus.done => StatusTone.positive,
    BatchStatus.processing => StatusTone.warning,
    BatchStatus.failed => StatusTone.danger,
    BatchStatus.pending => StatusTone.neutral,
  };
}
