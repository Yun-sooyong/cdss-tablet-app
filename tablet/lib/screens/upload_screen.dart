import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/models/models.dart';
import 'package:tablet/providers/batch_provider.dart';
import 'package:tablet/providers/upload_provider.dart';
import 'package:tablet/router/routes.dart';

/// 새 분석. 위저드로 나누지 않고 한 화면 3단으로 둔다 — 태블릿 가로 화면이라
/// 환자·이미지·모델이 한눈에 들어온다.
class UploadScreen extends HookConsumerWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadProvider);
    final ctrl = ref.read(uploadProvider.notifier);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppDimens.gapXl),
      children: [
        Text('새 분석', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppDimens.gapXl),

        const _StepTitle(1, '환자'),
        _PatientStep(selected: state.patient, onSelect: ctrl.selectPatient),
        const SizedBox(height: AppDimens.gapXl),

        const _StepTitle(2, '이미지'),
        _FileStep(
          files: state.files,
          onAdd: ctrl.addFiles,
          onRemove: ctrl.removeFile,
        ),
        const SizedBox(height: AppDimens.gapXl),

        const _StepTitle(3, '모델'),
        _ModelStep(
          selectedId: state.modelVersionId,
          onSelect: ctrl.selectModel,
        ),
        const SizedBox(height: AppDimens.gapXl),
        const Divider(),
        const SizedBox(height: AppDimens.gapLg),

        Row(
          children: [
            FilledButton.icon(
              onPressed: state.canStart
                  ? () async {
                      final id = await ctrl.start();
                      if (id != null && context.mounted) {
                        ctrl.reset();
                        context.go(Routes.batch(id));
                      }
                    }
                  : null,
              icon: state.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: const Text('분석 시작'),
            ),
            const SizedBox(width: AppDimens.gapMd),
            if (state.patient == null || state.files.isEmpty)
              Text(
                '환자와 이미지를 선택해야 시작할 수 있습니다',
                style: TextStyle(color: theme.disabledColor),
              ),
          ],
        ),

        if (state.log.isNotEmpty) ...[
          const SizedBox(height: AppDimens.gapLg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimens.gapLg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimens.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in state.log)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (state.error != null) ...[
          const SizedBox(height: AppDimens.gapMd),
          Text(state.error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.n, this.title);
  final int n;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.gapMd),
      child: Text(
        '$n. $title',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

// ------------------------------------------------------------------ 1. 환자

class _PatientStep extends HookConsumerWidget {
  const _PatientStep({required this.selected, required this.onSelect});

  final PatientSummary? selected;
  final ValueChanged<PatientSummary> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byChart = useState(true); // false면 이름+생년월일
    final chartCtrl = useTextEditingController();
    final nameCtrl = useTextEditingController();
    final birthCtrl = useTextEditingController();
    final query = useState(const PatientQuery.chart(''));
    final results = ref.watch(patientSearchProvider(query.value));
    final theme = Theme.of(context);

    // 검색 조건이 바뀔 때마다 조립한다. 이름은 생년월일과 짝이어야 서버를 부른다.
    void rebuild() {
      query.value = byChart.value
          ? PatientQuery.chart(chartCtrl.text)
          : PatientQuery.nameAndBirth(
              nameCtrl.text,
              DateTime.tryParse(birthCtrl.text.trim()),
            );
    }

    // 환자를 고르면 검색어와 결과를 지운다.
    // 안 지우면 선택 카드 아래에 결과 목록이 계속 남아 헷갈린다.
    void pick(PatientSummary p) {
      chartCtrl.clear();
      nameCtrl.clear();
      birthCtrl.clear();
      query.value = const PatientQuery.chart('');
      onSelect(p);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('차트번호')),
                ButtonSegment(value: false, label: Text('이름+생년월일')),
              ],
              selected: {byChart.value},
              onSelectionChanged: (s) {
                byChart.value = s.first;
                rebuild();
              },
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _showCreateDialog(context, ref, pick),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('신규 등록'),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.gapMd),

        if (byChart.value)
          TextField(
            controller: chartCtrl,
            onChanged: (_) => rebuild(),
            decoration: const InputDecoration(
              hintText: '차트번호 (일부만 입력해도 됩니다)',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  onChanged: (_) => rebuild(),
                  decoration: const InputDecoration(
                    labelText: '이름',
                    prefixIcon: Icon(Icons.person_outline),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.gapMd),
              Expanded(
                child: TextField(
                  controller: birthCtrl,
                  onChanged: (_) => rebuild(),
                  decoration: const InputDecoration(
                    labelText: '생년월일',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icon(Icons.cake_outlined),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.gapSm),
          Text(
            // 암호화 컬럼이라 해시 비교만 가능하다. 부분일치가 안 된다는 걸 알려야 한다.
            '이름과 생년월일이 모두 정확히 일치해야 찾을 수 있습니다.',
            style: TextStyle(color: theme.disabledColor, fontSize: 12),
          ),
        ],
        const SizedBox(height: AppDimens.gapMd),

        if (selected != null)
          Card(
            child: ListTile(
              leading: Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              ),
              title: Text(selected!.name),
              subtitle: Text('차트 ${selected!.chartNumber}'),
            ),
          ),

        if (query.value.isReady)
          results.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppDimens.gapMd),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Text(
              '검색 실패: $e',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppDimens.gapMd),
                    child: Text(
                      '결과가 없습니다',
                      style: TextStyle(color: theme.disabledColor),
                    ),
                  )
                : Column(
                    children: [
                      for (final p in list)
                        Card(
                          child: ListTile(
                            title: Text(p.name),
                            subtitle: Text('차트 ${p.chartNumber}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => pick(p),
                          ),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }

  static Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
    ValueChanged<PatientSummary> onSelect,
  ) async {
    final name = TextEditingController();
    final birth = TextEditingController(text: '1990-01-01');
    final phone = TextEditingController();
    // 다이얼로그가 닫힌 뒤 context를 쓰지 않도록 미리 잡아둔다
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('신규 환자 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            const SizedBox(height: AppDimens.gapMd),
            TextField(
              controller: birth,
              decoration: const InputDecoration(
                labelText: '생년월일',
                hintText: 'YYYY-MM-DD',
              ),
            ),
            const SizedBox(height: AppDimens.gapMd),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: '전화번호'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('등록'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final id = await ref.read(patientRepositoryProvider).create(
        name: name.text.trim(),
        birthDate: DateTime.parse(birth.text.trim()),
        phone: phone.text.trim(),
      );
      // 등록 응답은 id만 신뢰한다. 나머지는 입력값으로 채운다.
      onSelect(
        PatientSummary(
          id: id,
          chartNumber: '(신규)',
          name: name.text.trim(),
          birthDate: DateTime.tryParse(birth.text.trim()),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('등록 실패: $e')));
    }
  }
}

// ---------------------------------------------------------------- 2. 이미지

class _FileStep extends StatelessWidget {
  const _FileStep({
    required this.files,
    required this.onAdd,
    required this.onRemove,
  });

  final List<PickedFile> files;
  final ValueChanged<List<PickedFile>> onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final res = await FilePicker.pickFiles(
                  allowMultiple: true,
                  withData: true, // 바이트를 바로 받는다
                );
                if (res == null) return;
                onAdd([
                  for (final f in res.files)
                    if (f.bytes != null)
                      PickedFile(name: f.name, bytes: f.bytes!),
                ]);
              },
              icon: const Icon(Icons.attach_file),
              label: const Text('파일 선택'),
            ),
            const SizedBox(width: AppDimens.gapMd),
            OutlinedButton.icon(
              onPressed: () async {
                // 에뮬레이터에 파일이 없을 때를 위한 개발용 경로.
                // 실제 슬라이드가 아니라 앱 로고 이미지다.
                final data = await rootBundle.load('assets/icons1.png');
                onAdd([
                  PickedFile(
                    name: 'sample_${DateTime.now().millisecondsSinceEpoch}.png',
                    bytes: data.buffer.asUint8List(),
                  ),
                ]);
              },
              icon: const Icon(Icons.image_outlined),
              label: const Text('샘플 이미지로 테스트'),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.gapMd),
        if (files.isEmpty)
          Text('선택된 파일이 없습니다',
              style: TextStyle(color: theme.disabledColor))
        else
          for (var i = 0; i < files.length; i++)
            Card(
              child: ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(files[i].name),
                subtitle: Text('${files[i].sizeKb} KB'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => onRemove(i),
                ),
              ),
            ),
      ],
    );
  }
}

// ------------------------------------------------------------------ 3. 모델

class _ModelStep extends ConsumerWidget {
  const _ModelStep({required this.selectedId, required this.onSelect});

  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(modelVersionsProvider);

    return models.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(
        '모델 목록을 불러오지 못했습니다: $e',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Text('활성 모델이 없습니다',
              style: TextStyle(color: Theme.of(context).disabledColor));
        }
        final current = selectedId ?? list.first.id;
        return DropdownButtonFormField<String>(
          initialValue: current,
          items: [
            for (final m in list)
              DropdownMenuItem(value: m.id, child: Text(m.label)),
          ],
          onChanged: (v) {
            if (v != null) onSelect(v);
          },
        );
      },
    );
  }
}
