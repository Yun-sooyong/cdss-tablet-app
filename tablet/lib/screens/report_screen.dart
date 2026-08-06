import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/models/models.dart';
import 'package:tablet/providers/batch_provider.dart';
import 'package:tablet/router/routes.dart';
import 'package:tablet/widgets/overlay_viewer.dart';

/// 좌우 분할이 답답해지는 폭. 이 아래로는 상하로 떨어뜨린다.
const _kTwoPaneMinWidth = 1000.0;

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key, required this.batchId});
  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(batchDetailProvider(batchId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimens.gapLg),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                // 딥링크로 바로 들어왔으면 pop할 스택이 없다
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(Routes.batch(batchId)),
              ),
              const SizedBox(width: AppDimens.gapSm),
              Text('상세 리포트', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: detail.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('불러오지 못했습니다\n$e')),
            data: (batch) {
              // 결과가 있는 첫 job을 기준으로 삼는다
              Job? job;
              for (final j in batch.jobs) {
                if (j.result != null) {
                  job = j;
                  break;
                }
              }
              job ??= batch.jobs.isEmpty ? null : batch.jobs.first;

              if (job == null) {
                return const Center(child: Text('분석 작업이 없습니다'));
              }

              final viewer = Padding(
                padding: const EdgeInsets.all(AppDimens.gapXl),
                child: OverlayViewer(job: job),
              );
              final report = _ReportBody(report: job.result?.report);

              return LayoutBuilder(
                builder: (context, constraints) {
                  // 좁으면 상하로. 바깥 스크롤 하나만 두고 report는 그냥 얹는다
                  if (constraints.maxWidth < _kTwoPaneMinWidth) {
                    return ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        SizedBox(height: 420, child: viewer),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(AppDimens.gapXl),
                          child: report,
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: viewer),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppDimens.gapXl),
                          child: report,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});
  final MedgemmaReport? report;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = report;

    if (r == null) {
      return const Center(child: Text('리포트가 아직 생성되지 않았습니다'));
    }
    if (r.generationFailed) {
      return const Center(child: Text('리포트 생성에 실패했습니다'));
    }

    // 스크롤은 바깥에서 담당한다 (좌우 분할이냐 상하냐에 따라 달라서)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section('판독 소견', r.findings),
        _Section('AI 의견', r.aiOpinion),
        _Section('구성비 요약', r.segmentationSummary),
        const SizedBox(height: AppDimens.gapXl),
        if (r.opinionNote != null)
          Text(
            r.opinionNote!,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        // AI 판독 보조 도구라는 고지는 반드시 노출한다
        if (r.disclaimer != null) ...[
          const SizedBox(height: AppDimens.gapMd),
          Text(
            r.disclaimer!,
            style: const TextStyle(color: AppColors.warning, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.body);
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    if (body == null || body!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppDimens.gapSm),
          Text(body!, style: const TextStyle(height: 1.6)),
        ],
      ),
    );
  }
}
